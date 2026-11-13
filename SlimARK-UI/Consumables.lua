local _, ns = ...
local C = ns.C
local cfg = C.consumables

local IMBUE_SUBCLASS = 6
-- Weapon oils and stones by item ID, every quality: their names and descriptions differ in every
-- language. These count regardless of their item class.
local KNOWN_IMBUES = {}
for _, id in ipairs({
	-- Midnight: Thalassian Phoenix Oil, Oil of Dawn, Smuggler's Enchanted Edge.
	243733, 243734, 243735, 243736, 243737, 243738,
	-- Refulgent Whetstone and Weightstone.
	237370, 237371, 237367, 237369,
	-- The War Within: Algari Mana Oil, Oil of Beledar's Grace, Oil of Deep Toxins.
	224105, 224106, 224107, 224108, 224109, 224110, 224111, 224112, 224113,
	-- Ironclaw Whetstone and Weightstone.
	222502, 222503, 222504, 222508, 222509, 222510,
}) do KNOWN_IMBUES[id] = true end
local ENGLISH = { enUS = true, enGB = true }

local buttons = {}
local bar
local pending = false

local function TotalSlots()
	local n = 0
	for _, g in ipairs(cfg.groups) do n = n + g.count end
	return n + 1
end

local imbues = {}

-- The class of weapon oils differs per expansion. The known ones go by item ID; an older one is
-- recognized from its English description (on English clients only): the use line is about a
-- weapon, lasts minutes or hours, and is not a healing oil.
local function IsWeaponImbue(bag, slot, id)
	if KNOWN_IMBUES[id] then return true end
	if not (GetLocale and ENGLISH[GetLocale()]) then return false end
	if imbues[id] ~= nil then return imbues[id] end
	local data = C_TooltipInfo.GetBagItem(bag, slot)
	if not data or not data.lines or #data.lines == 0 then return false end
	local found = false
	for _, line in ipairs(data.lines) do
		local text = line.leftText
		if text and not issecretvalue(text) and text:find(ITEM_SPELL_TRIGGER_ONUSE, 1, true) then
			local lower = text:lower()
			local timed = lower:find('%d min') or lower:find('%d hour')
			if timed and lower:find('weapon', 1, true) and not lower:find('permanent', 1, true)
				and not lower:find('healing', 1, true) then
				found = true
			end
		end
	end
	imbues[id] = found
	return found
end

ns.IsWeaponImbue = IsWeaponImbue

-- The consumables in the bags by their subclass, each item once with its count.
local function Collect()
	local bySubclass = {}
	local seen = {}
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and not seen[info.itemID] then
				seen[info.itemID] = true
				local _, _, _, _, _, classID, subclass = C_Item.GetItemInfoInstant(info.itemID)
				local isConsumable = classID == Enum.ItemClass.Consumable
				local mayBeImbue = isConsumable or classID == Enum.ItemClass.ItemEnhancement
					or KNOWN_IMBUES[info.itemID]
				if mayBeImbue and IsWeaponImbue(bag, slot, info.itemID) then
					subclass = IMBUE_SUBCLASS
					isConsumable = true
				elseif subclass == IMBUE_SUBCLASS then
					-- Other items fall into this class too, for example spark, so only recognized oils go here.
					isConsumable = false
				end
				if isConsumable then
					bySubclass[subclass] = bySubclass[subclass] or {}
					local expansion = select(15, C_Item.GetItemInfo(info.itemID)) or 0
					table.insert(bySubclass[subclass], {
						id = info.itemID,
						icon = info.iconFileID,
						expansion = expansion,
						count = C_Item.GetItemCount(info.itemID),
					})
				end
			end
		end
	end
	return bySubclass
end

local function Scan()
	local bySubclass = Collect()
	local picked = {}
	for _, g in ipairs(cfg.groups) do
		local list = bySubclass[g.subclass]
		if list then
			table.sort(list, function(a, b)
				if a.expansion ~= b.expansion then return a.expansion > b.expansion end
				return a.count > b.count
			end)
			for i = 1, math.min(g.count, #list) do
				table.insert(picked, list[i])
			end
		end
	end
	for _, id in ipairs(cfg.extraItems) do
		if C_Item.GetItemCount(id) > 0 then
			table.insert(picked, { id = id, icon = C_Item.GetItemIconByID(id) })
			break
		end
	end
	return picked
end

local function UpdateCounts()
	for _, b in ipairs(buttons) do
		if b.itemID then
			b.Count:SetText(C_Item.GetItemCount(b.itemID, false, true))
			local start, duration = C_Item.GetItemCooldown(b.itemID)
			if start and duration then b.Cooldown:SetCooldown(start, duration) end
		end
	end
end

local function Refresh()
	if InCombatLockdown() then
		pending = true
		UpdateCounts()
		return
	end
	local picked = Scan()
	for i, b in ipairs(buttons) do
		local item = picked[i]
		b.itemID = item and item.id or nil
		if item then
			b:SetAttribute('type', 'item')
			b:SetAttribute('item', 'item:' .. item.id)
			b.Icon:SetTexture(item.icon)
			b:Show()
		else
			b:SetAttribute('type', nil)
			b:SetAttribute('item', nil)
			b:Hide()
		end
	end
	UpdateCounts()
end

local function CreateButton(i)
	local b = CreateFrame('Button', 'SlimARK_Consumable' .. i, bar, 'SecureActionButtonTemplate')
	b:SetSize(cfg.size, cfg.size)
	b:SetPoint('LEFT', (i - 1) * (cfg.size + cfg.gap), 0)
	b:RegisterForClicks('AnyUp', 'AnyDown')
	ns.Outline(b)
	local icon = b:CreateTexture(nil, 'ARTWORK')
	icon:SetAllPoints()
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.Icon = icon
	local cd = CreateFrame('Cooldown', nil, b, 'CooldownFrameTemplate')
	cd:SetAllPoints()
	cd:SetDrawEdge(false)
	b.Cooldown = cd
	local top = CreateFrame('Frame', nil, b)
	top:SetAllPoints()
	top:SetFrameLevel(cd:GetFrameLevel() + 2)
	b.Count = ns.Text(top, 15, 'RIGHT')
	b.Count:SetPoint('BOTTOMRIGHT', -2, 2)
	b:SetScript('OnEnter', function(self)
		if self.itemID then
			GameTooltip:SetOwner(self, 'ANCHOR_TOP')
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:Show()
		end
	end)
	b:SetScript('OnLeave', function() GameTooltip:Hide() end)
	b:Hide()
	return b
end

ns.On('PLAYER_LOGIN', function()
	if not C.modules.consumables then return end
	local count = TotalSlots()
	bar = CreateFrame('Frame', 'SlimARK_Consumables', UIParent)
	bar:SetSize(count * (cfg.size + cfg.gap), cfg.size)
	ns.Register(bar, cfg.x, cfg.y, { key = 'consumables', side = 'RIGHT' })
	for i = 1, count do
		buttons[i] = CreateButton(i)
	end
	Refresh()
	-- Looting fires many bag updates in a row: the bags are scanned once they settle.
	local queued = false
	ns.On('BAG_UPDATE_DELAYED', function()
		if queued then return end
		queued = true
		C_Timer.After(0.3, function()
			queued = false
			Refresh()
		end)
	end)
	ns.On('BAG_UPDATE_COOLDOWN', UpdateCounts)
	ns.On('PLAYER_REGEN_ENABLED', function()
		if pending then
			pending = false
			Refresh()
		end
	end)
end)

-- 3.0 (40): entering a dungeon, one chat line when fewer than 5 potions or food are in the bags.
-- The same lists as the bar: of each kind the newest expansion's items count, the ones the bar
-- shows first. Its own switch, apart from the bar.
local LOW = 5
local POTION, FOOD = 1, 5 -- Enum.ItemConsumableSubclass: Potion, FoodAndDrink

local function Newest(list)
	if not list then return 0 end
	local newest, count = -1, 0
	for _, item in ipairs(list) do
		if item.expansion > newest then newest, count = item.expansion, 0 end
		if item.expansion == newest then count = count + (item.count or 0) end
	end
	return count
end

local function CheckSupplies()
	local bySubclass = Collect()
	local potions, food = Newest(bySubclass[POTION]), Newest(bySubclass[FOOD])
	local low = {}
	if potions < LOW then low[#low + 1] = potions .. (potions == 1 and ' potion' or ' potions') end
	if food < LOW then low[#low + 1] = food .. ' food' end
	if #low > 0 then ns.Print('Low on supplies: ' .. table.concat(low, ', ') .. '.') end
end
ns.CheckSupplies = CheckSupplies

local lastDungeon
ns.On('PLAYER_LOGIN', function()
	if not C.features.lowSupplies then return end
	ns.On('PLAYER_ENTERING_WORLD', function(_, _, reload)
		local _, kind, _, _, _, _, _, instanceID = GetInstanceInfo()
		if kind ~= 'party' then
			lastDungeon = nil
			return
		end
		-- A reload or a new loading screen in the same dungeon is not a new entry.
		local again = reload or instanceID == lastDungeon
		lastDungeon = instanceID
		if again then return end
		-- The bags are read a moment after the loading screen.
		C_Timer.After(2, CheckSupplies)
	end)
end)
