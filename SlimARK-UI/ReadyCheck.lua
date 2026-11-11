local _, ns = ...
local C = ns.C
local cfg = C.readycheck

-- A flat ready check window in place of Blizzard's: the question, and under it what is on you and
-- what is missing (flask, food, augment rune, weapon oil, the group's class buffs, durability),
-- with a button that uses the missing item from your bags. It exists only during a ready check
-- and refreshes only when your buffs, gear or bags change. In combat Blizzard's window stays.

local W, ROW, HEAD = 330, 40, 34
local BG = { 0.055, 0.059, 0.075, 0.95 }
local GOLD = { 0.95, 0.72, 0.29 }
local OK = { 0.5, 0.82, 0.5 }
local BAD = { 0.88, 0.34, 0.29 }
local MISS_BG = { 0.88, 0.34, 0.29, 0.08 }
local FOOD_ICON = 136000

-- Augment runes by item ID, newest first: their names differ in every language.
local AUGMENT_RUNES = {
	259085, -- Void-Touched Augment Rune
	243191, -- Ethereal Augment Rune
	224572, -- Crystallized Augment Rune
	211495, -- Dreambound Augment Rune
	201325, -- Draconic Augment Rune
	190384, -- Eternal Augment Rune
	181468, -- Veiled Augment Rune
	174906, -- Lightning-Forged Augment Rune
	160053, -- Battle-Scarred Augment Rune
	153023, -- Lightforged Augment Rune
	140587, -- Defiled Augment Rune
	128482, 128475, -- Empowered Augment Rune
	118630, 118631, 118632, -- Hyper, Stout and Focus Augment Rune
}
local IS_RUNE = {}
for _, id in ipairs(AUGMENT_RUNES) do IS_RUNE[id] = true end

-- The buffs of the current flasks and runes by spell ID (the Fleeting cauldron flasks give the
-- same buff), so they are recognized even when no such item was ever in the bags.
local FLASK_BUFFS = {}
for _, id in ipairs({
	-- Midnight: Thalassian Resistance, the Magisters, the Blood Knights, the Shattered Sun, Vicious Flask of Honor.
	1235057, 1235108, 1235110, 1235111, 1239355,
	-- The War Within: Tempered Aggression, Swiftness, Versatility, Mastery; Alchemical Chaos; Saving Graces.
	431971, 431972, 431973, 431974, 432021, 432473,
}) do FLASK_BUFFS[id] = true end
local RUNE_BUFFS = {}
for _, id in ipairs({
	1264426, -- Void-Touched (Void-Touched Augment Rune)
	1234969, -- Ethereal Augmentation
	453250, -- Crystallization (Crystallized Augment Rune)
	393438, -- Draconic Augmentation (Draconic and Dreambound Augment Rune)
}) do RUNE_BUFFS[id] = true end

-- Buff and item names are only matched on English clients, as a last resort.
local ENGLISH = { enUS = true, enGB = true }
local function English()
	return GetLocale ~= nil and ENGLISH[GetLocale()] == true
end

-- The group's class buffs, by the class that gives them.
local CLASS_BUFFS = {
	MAGE = { 1459 }, PRIEST = { 21562 }, WARRIOR = { 6673 }, DRUID = { 1126 }, SHAMAN = { 462854 },
	EVOKER = { 381748, 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758 },
}
local CLASS_ORDER = { 'MAGE', 'PRIEST', 'WARRIOR', 'DRUID', 'SHAMAN', 'EVOKER' }

local window, rows, useButtons, events
local initiator, endTime, ticker, answered

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

local function Minutes(expiration)
	if not Readable(expiration) or expiration == 0 then return nil end
	return math.max(0, math.floor((expiration - GetTime()) / 60))
end

------------------------------------------------------------------------
-- What you carry and what is on you.
------------------------------------------------------------------------
-- The buff of a flask or a rune is the item's own use spell. A spell seen in the bags once is kept,
-- so the buff is recognized in every language after the last item was used up.
local function KnownSpells(kind)
	if not ns.DB then return {} end
	ns.DB.consumableSpells = ns.DB.consumableSpells or {}
	ns.DB.consumableSpells[kind] = ns.DB.consumableSpells[kind] or {}
	return ns.DB.consumableSpells[kind]
end

local function LearnSpell(kind, itemID)
	local _, spellID = C_Item.GetItemSpell(itemID)
	if spellID then KnownSpells(kind)[spellID] = true end
end

-- The flasks and runes in the bags are learned whenever the bags change, not only during a ready
-- check: the last one may be used up before the next check.
local function LearnFromBags()
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and info.itemID
			if id then
				local _, _, _, _, _, classID, subclass = C_Item.GetItemInfoInstant(id)
				if classID == Enum.ItemClass.Consumable and subclass == 3 then
					LearnSpell('flask', id)
				elseif IS_RUNE[id] then
					LearnSpell('rune', id)
				end
			end
		end
	end
end

local function ScanBags()
	local found = {}
	local function keep(kind, id, icon, expansion)
		local old = found[kind]
		if not old or expansion > old.expansion then found[kind] = { id = id, icon = icon, expansion = expansion } end
	end
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local id = info.itemID
				local _, _, _, _, _, classID, subclass = C_Item.GetItemInfoInstant(id)
				local expansion = select(15, C_Item.GetItemInfo(id)) or 0
				local name = C_Item.GetItemNameByID(id)
				if classID == Enum.ItemClass.Consumable and subclass == 3 then
					keep('flask', id, info.iconFileID, expansion)
					LearnSpell('flask', id)
				elseif classID == Enum.ItemClass.Consumable and subclass == 5 then
					keep('food', id, info.iconFileID, expansion)
				elseif IS_RUNE[id] or (English() and Readable(name) and name:find('Augment Rune', 1, true)) then
					keep('rune', id, info.iconFileID, expansion)
					LearnSpell('rune', id)
				elseif ns.IsWeaponImbue and (classID == Enum.ItemClass.Consumable or classID == Enum.ItemClass.ItemEnhancement)
					and ns.IsWeaponImbue(bag, slot, id) then
					keep('oil', id, info.iconFileID, expansion)
				end
			end
		end
	end
	return found
end

-- The first buff on you that passes the test.
local function FindAura(test)
	for i = 1, 60 do
		local aura = C_UnitAuras.GetAuraDataByIndex('player', i, 'HELPFUL')
		if not aura then return nil end
		if Readable(aura.name) and test(aura) then return aura end
	end
end

local function AuraBySpells(ids)
	for _, id in ipairs(ids) do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
		if aura then return aura end
	end
end

local function ItemAura(item)
	if not item then return nil end
	local _, spellID = C_Item.GetItemSpell(item.id)
	return spellID and C_UnitAuras.GetPlayerAuraBySpellID(spellID) or nil
end

-- A buff on you from one of the spells in the set.
local function AuraFromSet(spells)
	for id in pairs(spells) do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
		if aura then return aura end
	end
end

-- The runes' spells: the known rune items' own, and the ones seen in the bags.
local function RuneSpells()
	local spells = {}
	for id in pairs(KnownSpells('rune')) do spells[id] = true end
	for _, item in ipairs(AUGMENT_RUNES) do
		local _, spellID = C_Item.GetItemSpell(item)
		if spellID then spells[spellID] = true end
	end
	return spells
end

local function ByName(...)
	if not English() then return nil end
	local words = { ... }
	return FindAura(function(a)
		for _, word in ipairs(words) do
			if a.name:find(word, 1, true) then return true end
		end
		return false
	end)
end

local function GroupClasses()
	local classes = {}
	local function add(unit)
		local _, class = UnitClass(unit)
		if Readable(class) then classes[class] = true end
	end
	add('player')
	local prefix = IsInRaid() and 'raid' or 'party'
	for i = 1, GetNumGroupMembers() do
		local unit = prefix .. i
		if UnitExists(unit) then add(unit) end
	end
	return classes
end

local function Durability()
	local low
	for slot = 1, 18 do
		local current, max = GetInventoryItemDurability(slot)
		if current and max and max > 0 then
			local pct = current / max * 100
			if not low or pct < low then low = pct end
		end
	end
	return low
end

-- The rows: { icon, label, status, ok, item, verb }.
local function Collect()
	local bags = ScanBags()
	local list = {}
	local function add(icon, label, aura, item, verb, status)
		local ok = aura ~= nil
		local text = status
		if not text then
			local m = aura and Minutes(aura.expirationTime)
			text = ok and (m and (m .. ' min') or 'on you') or 'missing'
		end
		table.insert(list, { icon = (aura and aura.icon) or (item and item.icon) or icon, label = label,
			status = text, ok = ok, item = (not ok) and item or nil, verb = verb })
	end

	local flask = ItemAura(bags.flask) or AuraFromSet(FLASK_BUFFS) or AuraFromSet(KnownSpells('flask'))
		or ByName('Flask', 'Phial')
	add([[Interface\Icons\INV_Potion_1]], 'Flask', flask, bags.flask, 'Drink')
	-- Well Fed has the same icon in every language; its spell is not the food's own.
	local food = FindAura(function(a) return a.icon == FOOD_ICON end) or ByName('Well Fed')
	add(FOOD_ICON, 'Food', food, bags.food, 'Eat')
	local rune = ItemAura(bags.rune) or AuraFromSet(RUNE_BUFFS) or AuraFromSet(RuneSpells()) or ByName('Augment')
	add([[Interface\Icons\INV_Misc_Rune_01]], 'Augment rune', rune, bags.rune, 'Use')

	-- The temporary enchant of the main hand (C_PaperDollInfo is there in every client; the old
	-- GetWeaponEnchantInfo is a deprecated fallback that can be missing).
	local enchant = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND or 16)
	if enchant then
		local left = enchant.remainingTimeMs
		local m = Readable(left) and left > 0 and math.floor(left / 60000) or nil
		add([[Interface\Icons\INV_Sword_04]], 'Weapon oil', { icon = bags.oil and bags.oil.icon }, nil, nil, m and (m .. ' min') or 'on you')
	else
		add([[Interface\Icons\INV_Sword_04]], 'Weapon oil', nil, bags.oil, 'Apply')
	end

	local classes = GroupClasses()
	for _, class in ipairs(CLASS_ORDER) do
		if classes[class] then
			local ids = CLASS_BUFFS[class]
			local name = C_Spell.GetSpellName(ids[1]) or class
			add(C_Spell.GetSpellTexture(ids[1]), name, AuraBySpells(ids), nil, nil, nil)
			list[#list].status = list[#list].ok and 'on you' or 'missing'
		end
	end

	local low = Durability()
	if low then
		table.insert(list, { icon = [[Interface\Icons\Trade_BlackSmithing]], label = 'Durability', status = math.floor(low) .. '%', ok = low >= 50 })
	end
	return list
end
ns.ReadyCheckRows = Collect

------------------------------------------------------------------------
-- The window.
------------------------------------------------------------------------
local function Fill(frame, color, layer)
	local t = frame:CreateTexture(nil, layer or 'BACKGROUND')
	t:SetAllPoints()
	t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return t
end

local function FlatButton(parent, label, color)
	local b = CreateFrame('Button', nil, parent)
	b:SetHeight(28)
	Fill(b, { 0.137, 0.145, 0.169 })
	ns.Outline(b)
	local hl = b:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.1)
	b.text = ns.Text(b, 16, 'CENTER')
	b.text:SetPoint('CENTER')
	b.text:SetText(label)
	b.text:SetTextColor(color[1], color[2], color[3])
	return b
end

local function UseButton(i)
	local b = CreateFrame('Button', 'SlimARK_ReadyCheckUse' .. i, UIParent, 'SecureActionButtonTemplate')
	b:SetFrameStrata('DIALOG')
	b:SetScale(ns.Scale())
	b:SetSize(84, 26)
	b:RegisterForClicks('AnyUp')
	b:SetAttribute('useOnKeyDown', false) -- acts on the release it is registered for
	Fill(b, { 0.137, 0.145, 0.169 })
	ns.Outline(b)
	local hl = b:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.1)
	b.text = ns.Text(b, 14, 'CENTER')
	b.text:SetPoint('CENTER')
	b.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	b:Hide()
	return b
end

local function Build()
	window = CreateFrame('Frame', 'SlimARK_ReadyCheck', UIParent)
	window:SetFrameStrata('DIALOG')
	window:SetSize(W, HEAD + 6 * ROW + 48)
	Fill(window, BG)
	ns.Outline(window)
	window:Hide()
	ns.Register(window, cfg.x, cfg.y, { key = 'readycheck', w = W, h = HEAD + 6 * ROW + 48 })

	window.title = ns.Text(window, 17)
	window.title:SetPoint('TOPLEFT', 10, -9)
	window.title:SetPoint('RIGHT', -60, 0)
	window.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	window.time = ns.Text(window, 15, 'RIGHT')
	window.time:SetPoint('TOPRIGHT', -10, -10)
	window.time:SetTextColor(0.7, 0.68, 0.64)
	local line = window:CreateTexture(nil, 'ARTWORK')
	line:SetColorTexture(0, 0, 0, 1)
	line:SetHeight(1)
	line:SetPoint('TOPLEFT', 0, -HEAD)
	line:SetPoint('TOPRIGHT', 0, -HEAD)

	rows = {}

	window.yes = FlatButton(window, READY or 'Ready', OK)
	window.no = FlatButton(window, NOT_READY or 'Not ready', BAD)
	window.yes:SetScript('OnClick', function() ns.AnswerReadyCheck(true) end)
	window.no:SetScript('OnClick', function() ns.AnswerReadyCheck(false) end)
	window.answer = ns.Text(window, 15, 'CENTER')

	useButtons = {}
	for i = 1, 4 do useButtons[i] = UseButton(i) end

	events = CreateFrame('Frame')
	events:SetScript('OnEvent', function() ns.RefreshReadyCheck() end)
end

-- A row per line of the list, made when the list first needs it: a full raid has every class buff
-- and the durability, more rows than a party.
local function Row(i)
	if rows[i] then return rows[i] end
	local r = CreateFrame('Frame', nil, window)
	r:SetHeight(ROW)
	r:SetPoint('TOPLEFT', 0, -HEAD - (i - 1) * ROW)
	r:SetPoint('RIGHT')
	r.miss = Fill(r, MISS_BG)
	r.icon = r:CreateTexture(nil, 'ARTWORK')
	r.icon:SetSize(30, 30)
	r.icon:SetPoint('LEFT', 10, 0)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local edge = r:CreateTexture(nil, 'BORDER')
	edge:SetColorTexture(0, 0, 0, 1)
	edge:SetPoint('TOPLEFT', r.icon, -1, 1)
	edge:SetPoint('BOTTOMRIGHT', r.icon, 1, -1)
	r.label = ns.Text(r, 16)
	r.label:SetPoint('LEFT', r.icon, 'RIGHT', 9, 0)
	r.status = ns.Text(r, 16, 'RIGHT')
	r.status:SetPoint('RIGHT', -10, 0)
	rows[i] = r
	return r
end

local function HideUse()
	for _, b in ipairs(useButtons) do
		if InCombatLockdown() then b:SetAlpha(0) else b:Hide() b:SetAlpha(1) end
	end
end

local function Refresh()
	if not window or not window:IsShown() or InCombatLockdown() then return end
	local list = Collect()
	local shown = #list
	local used = 0
	HideUse()
	for i = 1, math.max(shown, #rows) do
		local data = list[i]
		local r = data and Row(i) or rows[i]
		if data then
			r.icon:SetTexture(data.icon)
			r.label:SetText(data.label)
			r.status:SetText(data.status)
			local color = data.ok and OK or BAD
			r.status:SetTextColor(color[1], color[2], color[3])
			r.miss:SetShown(not data.ok)
			r.status:Show()
			if data.item and cfg.useButtons and used < #useButtons then
				used = used + 1
				local b = useButtons[used]
				b:SetAttribute('type', 'item')
				b:SetAttribute('item', 'item:' .. data.item.id)
				b.text:SetText(data.verb or 'Use')
				b:ClearAllPoints()
				b:SetPoint('RIGHT', r, 'RIGHT', -10, 0)
				b:Show()
				r.status:Hide()
			end
			r:Show()
		else
			r:Hide()
		end
	end
	local bottom = HEAD + shown * ROW
	local mine = initiator and UnitIsUnit('player', initiator)
	window.yes:SetShown(not mine and not answered)
	window.no:SetShown(not mine and not answered)
	window.answer:SetShown(answered ~= nil)
	window.yes:ClearAllPoints()
	window.yes:SetPoint('TOPLEFT', 10, -bottom - 8)
	window.yes:SetPoint('RIGHT', window, 'CENTER', -2, 0)
	window.no:ClearAllPoints()
	window.no:SetPoint('TOPLEFT', window, 'TOP', 2, -bottom - 8)
	window.no:SetPoint('RIGHT', -10, 0)
	window.answer:ClearAllPoints()
	window.answer:SetPoint('TOP', 0, -bottom - 14)
	local foot = (mine and not answered) and 8 or 44
	window:SetHeight(bottom + foot)
end
ns.RefreshReadyCheck = Refresh

local function Tick()
	if not endTime then return end
	local left = math.max(0, math.ceil(endTime - GetTime()))
	window.time:SetText(('%d:%02d'):format(math.floor(left / 60), left % 60))
end

local function Close()
	if ticker then ticker:Cancel() ticker = nil end
	if events then events:UnregisterAllEvents() end
	if window then window:Hide() end
	if useButtons then HideUse() end
	initiator, endTime, answered = nil, nil, nil
end
ns.CloseReadyCheck = Close

function ns.AnswerReadyCheck(ready)
	if answered ~= nil then return end
	answered = ready
	if C_PartyInfo and C_PartyInfo.ConfirmReadyCheck then
		C_PartyInfo.ConfirmReadyCheck(ready)
	else
		ConfirmReadyCheck(ready and 1 or nil)
	end
	if ReadyCheckFrame then ReadyCheckFrame:Hide() end
	window.answer:SetText(ready and 'You are ready' or 'You are not ready')
	local color = ready and OK or BAD
	window.answer:SetTextColor(color[1], color[2], color[3])
	Refresh()
end

local function Open(_, who, timeLeft)
	-- In combat the secure use buttons cannot appear: Blizzard's window does the job then.
	if InCombatLockdown() then return end
	initiator = who
	answered = nil
	endTime = GetTime() + (timeLeft or 30)
	local name = Readable(who) and Ambiguate(who, 'short') or ''
	window.title:SetText('Ready check · ' .. name)
	window:Show()
	-- Blizzard's window is put aside only when ours is built: if building fails, ours closes again
	-- and Blizzard's answers the check.
	if not xpcall(Refresh, geterrorhandler()) then
		Close()
		return
	end
	if ReadyCheckListenerFrame then ReadyCheckListenerFrame:Hide() end
	events:RegisterUnitEvent('UNIT_AURA', 'player')
	events:RegisterUnitEvent('UNIT_INVENTORY_CHANGED', 'player')
	events:RegisterEvent('BAG_UPDATE_DELAYED')
	Tick()
	if not ticker then ticker = C_Timer.NewTicker(1, Tick) end
end
ns.OpenReadyCheck = Open

ns.On('PLAYER_LOGIN', function()
	if not C.modules.readycheck then return end
	Build()
	-- Blizzard shows its own window after the event; ours keeps it hidden while it is open.
	if ReadyCheckListenerFrame then
		ReadyCheckListenerFrame:HookScript('OnShow', function(self)
			if window:IsShown() then self:Hide() end
		end)
	end
	ns.On('READY_CHECK', Open)
	ns.On('READY_CHECK_FINISHED', Close)
	-- A burst of bag updates (looting) is learned from once, a second later.
	local learnQueued = false
	ns.On('BAG_UPDATE_DELAYED', function()
		if learnQueued then return end
		learnQueued = true
		C_Timer.After(1, function()
			learnQueued = false
			LearnFromBags()
		end)
	end)
	LearnFromBags()
	ns.On('GROUP_LEFT', Close)
	-- Entering combat: the secure Use buttons go while that is still allowed (this event comes
	-- before the lockdown), so no hidden button catches a click or uses an item in the fight.
	-- Their rows show the status again; after the fight an open window gets its buttons back.
	ns.On('PLAYER_REGEN_DISABLED', function()
		HideUse()
		for _, r in ipairs(rows) do r.status:Show() end
	end)
	ns.On('PLAYER_REGEN_ENABLED', function()
		if window:IsShown() then Refresh() else HideUse() end
	end)
end)
