local _, ns = ...
local C = ns.C

local LEFT = { Head = 1, Neck = 2, Shoulder = 3, Back = 15, Chest = 5, Shirt = 4, Tabard = 19, Wrist = 9 }
local RIGHT = { Hands = 10, Waist = 6, Legs = 7, Feet = 8, Finger0 = 11, Finger1 = 12, Trinket0 = 13, Trinket1 = 14 }
local BOTTOM = { MainHand = 16, SecondaryHand = 17 }

local overlays = {}

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

------------------------------------------------------------------------
-- 3.0 (33): the upgrade track of an item, shared with the item tooltip (Tooltip.lua). The crest a
-- track costs is found by its name in this season's crest list (Config.lua upgrade.crests): the
-- game names the crest after the track in every language ("Hero" -> "Hero ...crest").
------------------------------------------------------------------------
local crestOf = {}

local function CrestFor(track)
	if crestOf[track] then return crestOf[track] end
	if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return end
	for _, id in ipairs(C.upgrade.crests) do
		local info = C_CurrencyInfo.GetCurrencyInfo(id)
		local name = info and info.name
		if Readable(name) and name ~= '' and name:find(track, 1, true) then
			crestOf[track] = name
			return name
		end
	end
end

-- { track = 'Hero', rank = 4, max = 6, left = 2, crest = 'Hero ...crest', crests = 40 }, or nil for an
-- item without a track. crest and crests are missing when the season table has no crest for it.
function ns.UpgradeTrack(link)
	if ns.isForever or not (C_Item and C_Item.GetItemUpgradeInfo) or not Readable(link) or not link then return end
	local info = C_Item.GetItemUpgradeInfo(link)
	if not info then return end
	local track, rank, max = info.trackString, info.currentLevel, info.maxLevel
	if not (Readable(track) and Readable(rank) and Readable(max)) then return end
	if not track or track == '' or not rank or not max or max <= 0 then return end
	local result = { track = track, rank = rank, max = max, left = math.max(0, max - rank) }
	if result.left > 0 then
		local crest = CrestFor(track)
		if crest then result.crest, result.crests = crest, result.left * C.upgrade.crestsPerStep end
	end
	return result
end

-- The first letter of the track and the rank, for the small room on a slot: "H 4/6".
local function ShortTrack(up)
	local first = up.track:match('^[%z\1-\127\194-\244][\128-\191]*') or ''
	return first .. ' ' .. up.rank .. '/' .. up.max
end

local function Overlay(button, side)
	local o = overlays[button]
	if o then return o end
	o = { gems = {} }

	o.Level = ns.Text(button, 15, 'CENTER')
	o.Level:SetFont(ns.FONT, 15, 'OUTLINE')
	o.Level:SetPoint('BOTTOM', 0, 2)

	-- 3.0 (33): the upgrade track at the top of the slot, only with its switch on.
	if C.charsheet.upgrade then
		o.Track = ns.Text(button, 12, 'CENTER')
		o.Track:SetPoint('TOP', 0, -2)
	end

	local info = CreateFrame('Frame', nil, button)
	info:SetSize(150, 36)
	if side == 'left' then
		info:SetPoint('LEFT', button, 'RIGHT', 6, 0)
	elseif side == 'right' then
		info:SetPoint('RIGHT', button, 'LEFT', -6, 0)
	else
		info:SetPoint('BOTTOM', button, 'TOP', 0, 4)
	end
	local justify = side == 'right' and 'RIGHT' or (side == 'left' and 'LEFT' or 'CENTER')
	o.Enchant = ns.Text(info, 12, justify)
	o.Enchant:SetPoint('TOPLEFT')
	o.Enchant:SetPoint('TOPRIGHT')

	for i = 1, 3 do
		local gem = info:CreateTexture(nil, 'OVERLAY')
		gem:SetSize(15, 15)
		local step = (i - 1) * 17
		if side == 'right' then
			gem:SetPoint('BOTTOMRIGHT', -step, 2)
		elseif side == 'left' then
			gem:SetPoint('BOTTOMLEFT', step, 2)
		else
			gem:SetPoint('BOTTOM', (i - 2) * 17, 2)
		end
		o.gems[i] = gem
	end
	o.Info = info
	overlays[button] = o
	return o
end

local function ReadItem(slot, unit)
	local result = { gems = {}, empty = 0 }
	local data = C_TooltipInfo.GetInventoryItem(unit, slot)
	if not data or not data.lines then return result end
	local types = Enum.TooltipDataLineType
	for _, line in ipairs(data.lines) do
		if line.type == types.ItemEnchantmentPermanent then
			-- 'Enchanted: Enchant Helm - Empowered ...' shows as 'Empowered ...': the slot is clear
			-- from the button, the room beside it is short. The label before the colon and the
			-- enchant's slot before ' - ' are cut in any language, not by their English words.
			local text = (line.leftText or ''):gsub('^[^:]+:%s*', '')
			local name = text:match('^.- %- (.+)$')
			result.enchant = name or text
		elseif line.type == types.GemSocket then
			if line.gemIcon then
				table.insert(result.gems, line.gemIcon)
			else
				result.empty = result.empty + 1
			end
		end
	end
	return result
end

-- The text beside a slot gets half of the room between the left and the right slot column, so
-- the two sides never run into each other at any UI scale.
local function InfoWidth(prefix)
	local left, right = _G[prefix .. 'HeadSlot'], _G[prefix .. 'HandsSlot']
	local l, r = left and left:GetRight(), right and right:GetLeft()
	if not (l and r) or r <= l then return 150 end
	return math.max(60, math.min(150, (r - l) / 2 - 10))
end

-- unit and prefix: 'player' and 'Character' for the character sheet, the inspected unit and
-- 'Inspect' for the inspect window (3.0, 34). Both go through this same code.
local function Update(button, side, slot, unit, prefix)
	unit, prefix = unit or 'player', prefix or 'Character'
	local o = Overlay(button, side)
	if side ~= 'bottom' then o.Info:SetWidth(InfoWidth(prefix)) end
	local link = GetInventoryItemLink(unit, slot)

	o.Level:SetText('')
	o.Enchant:SetText('')
	if o.Track then o.Track:SetText('') end
	for _, gem in ipairs(o.gems) do gem:Hide() end
	if not Readable(link) or not link then return end

	local level = C_Item.GetDetailedItemLevelInfo(link)
	if level then
		o.Level:SetText(level)
		local quality = C_Item.GetItemQualityByID(link)
		local color = quality and ITEM_QUALITY_COLORS[quality]
		if color then o.Level:SetTextColor(color.r, color.g, color.b) end
	end

	if o.Track then
		local up = ns.UpgradeTrack(link)
		if up then
			o.Track:SetText(ShortTrack(up))
			if up.left == 0 then o.Track:SetTextColor(0.3, 1, 0.3) else o.Track:SetTextColor(0.95, 0.72, 0.29) end
		end
	end

	local item = ReadItem(slot, unit)

	if item.enchant then
		o.Enchant:SetText(item.enchant)
		o.Enchant:SetTextColor(0.3, 1, 0.3)
	elseif C.enchantSlots[slot] then
		local isWeaponSlot = slot == 16 or slot == 17
		local classID = select(6, C_Item.GetItemInfoInstant(link))
		if not isWeaponSlot or classID == Enum.ItemClass.Weapon then
			o.Enchant:SetText('No enchant')
			o.Enchant:SetTextColor(1, 0.25, 0.25)
		end
	end

	local i = 0
	for _, icon in ipairs(item.gems) do
		i = i + 1
		if o.gems[i] then
			o.gems[i]:SetTexture(icon)
			o.gems[i]:SetVertexColor(1, 1, 1)
			o.gems[i]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			o.gems[i]:Show()
		end
	end
	for _ = 1, item.empty do
		i = i + 1
		if o.gems[i] then
			o.gems[i]:SetColorTexture(1, 0.15, 0.15, 1)
			o.gems[i]:Show()
		end
	end
end

local slots = {}

ns.On('PLAYER_LOGIN', function()
	if not C.modules.character then return end
	local function collect(list, side)
		for name, id in pairs(list) do
			local button = _G['Character' .. name .. 'Slot']
			if button then slots[button] = { side = side, id = id } end
		end
	end
	collect(LEFT, 'left')
	collect(RIGHT, 'right')
	collect(BOTTOM, 'bottom')

	hooksecurefunc('PaperDollItemSlotButton_Update', function(button)
		-- Only while the character sheet is open: it updates every slot again when shown.
		local s = slots[button]
		if s and CharacterFrame and CharacterFrame:IsShown() then Update(button, s.side, s.id) end
	end)
end)

------------------------------------------------------------------------
-- 3.0 (34): the same marks on the inspect window, out of a running key. Blizzard updates every
-- slot when the inspected player's items arrive (INSPECT_READY), the hook follows that.
------------------------------------------------------------------------
local inspectSlots

local function InRunningKey()
	return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() or false
end

local function OnInspectSlot(button)
	local s = inspectSlots[button]
	if not s or not (InspectFrame and InspectFrame:IsShown()) then return end
	local unit = InspectFrame.unit
	if InRunningKey() or not Readable(unit) or not unit then
		-- Nothing is asked in a running key; marks of an earlier inspect must not stay.
		local o = overlays[button]
		if o then
			o.Level:SetText('')
			o.Enchant:SetText('')
			if o.Track then o.Track:SetText('') end
			for _, gem in ipairs(o.gems) do gem:Hide() end
		end
		return
	end
	Update(button, s.side, s.id, unit, 'Inspect')
end

local function HookInspect()
	if inspectSlots or not InspectPaperDollItemSlotButton_Update then return end
	inspectSlots = {}
	for list, side in pairs({ [LEFT] = 'left', [RIGHT] = 'right', [BOTTOM] = 'bottom' }) do
		for name, id in pairs(list) do
			local button = _G['Inspect' .. name .. 'Slot']
			if button then inspectSlots[button] = { side = side, id = id } end
		end
	end
	hooksecurefunc('InspectPaperDollItemSlotButton_Update', OnInspectSlot)
end

ns.On('PLAYER_LOGIN', function()
	if not (C.modules.character and C.charsheet.inspect) then return end
	if InspectPaperDollItemSlotButton_Update then
		HookInspect()
	else
		ns.On('ADDON_LOADED', function(_, name)
			if name == 'Blizzard_InspectUI' then HookInspect() end
		end)
	end
end)
