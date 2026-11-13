-- 3.0 part C: the upgrade track in item tooltips and on the character sheet slots (33), the
-- character sheet marks on the inspect window (34) and the tooltip extras (42). Run from the
-- repository root:
--   lua5.1 tests/claude/ui-items-3-0.lua
local H = dofile('tests/claude/lib/helpers.lua')

local W
local calls -- TooltipDataProcessor registrations: { kind = 'post'|'pre', key, fn }

local function Secret(label)
	local function boom() error('secret value used: ' .. label, 2) end
	local t = setmetatable({}, { __lt = boom, __le = boom, __concat = boom, __add = boom, __sub = boom, __mul = boom,
		__div = boom, __unm = boom, __len = boom, __index = function() boom() end })
	H.secret = H.secret or {}
	H.secret[t] = true
	return t
end

local function NoErrors(what)
	local errors = {}
	for _, line in ipairs(H.prints) do
		if line:find('ERROR ', 1, true) then table.insert(errors, line) end
	end
	H.check(#errors == 0, what .. ' runs without errors' .. (#errors > 0 and (': ' .. errors[1]) or ''))
end

local function Find(kind, key)
	for _, c in ipairs(calls) do
		if c.kind == kind and c.key == key then return c.fn end
	end
end

local function Lines(tip, label)
	for _, line in ipairs(tip.lines) do
		if line[1] == label then return line[2] ~= nil and line[2] or true end
	end
end

local function FakeTip(name)
	local tip = H.NewFrame('GameTooltip', name, UIParent)
	tip.lines = {}
	function tip:AddLine(text) table.insert(self.lines, { text }) end
	function tip:AddDoubleLine(a, b) table.insert(self.lines, { a, b }) end
	function tip:GetUnit() return 'Name', W.unit end
	function tip:GetProcessingTooltipInfo() return W.processing end
	return tip
end

local function ItemWorld()
	W = { upgrade = {}, links = {}, counts = {}, mounts = {}, auras = {}, auraReads = 0, unit = 'mouseover' }
	rawset(Enum, 'TooltipDataType', { Item = 0, Spell = 1, Unit = 2, UnitAura = 7 })
	rawset(Enum, 'TooltipDataLineType', { ItemUpgradeLevel = 32, ItemEnchantmentPermanent = 15, GemSocket = 16 })
	calls = {}
	_G.TooltipDataProcessor = {
		AddTooltipPostCall = function(key, fn) table.insert(calls, { kind = 'post', key = key, fn = fn }) end,
		AddLinePreCall = function(key, fn) table.insert(calls, { kind = 'pre', key = key, fn = fn }) end,
	}
	_G.C_Item = {
		GetItemUpgradeInfo = function(link) return W.upgrade[link] end,
		GetItemLinkByGUID = function(guid) return W.links[guid] end,
		GetItemSpell = function(id) if id == 5512 then return 'Healthstone', 6262 end end,
		GetItemCount = function(id) return W.counts[id] or 0 end,
		GetDetailedItemLevelInfo = function() return 700 end,
		GetItemQualityByID = function() return 4 end,
		GetItemInfoInstant = function() return 1, nil, nil, nil, nil, 4 end,
	}
	_G.C_CurrencyInfo = { GetCurrencyInfo = function(id)
		local names = { [3442] = 'Adventurer Mistcrest', [3443] = 'Veteran Mistcrest', [3444] = 'Champion Mistcrest',
			[3445] = 'Hero Mistcrest', [3446] = 'Myth Mistcrest' }
		return names[id] and { name = names[id] }
	end }
	_G.ITEM_SPELL_KNOWN = 'Already known'
	_G.C_MountJournal = {
		GetMountFromItem = function(id) return W.mounts[id] and W.mounts[id].mount or nil end,
		GetMountFromSpell = function(spell) return spell == 32345 and 77 or nil end,
		GetMountInfoByID = function(id)
			if id == 77 then return 'Swift Razorwing', 32345, 1, false, true, 0, false, false, nil, false, true end
			for _, m in pairs(W.mounts) do
				if m.mount == id then return 'Mount ' .. id, 1, 1, false, true, 0, false, false, nil, false, m.collected end
			end
		end,
	}
	_G.C_ToyBox = { GetToyInfo = function(id) if id == 1001 then return 1001, 'Toy' end end }
	_G.PlayerHasToy = function(id) return id == 1001 end
	_G.C_PetJournal = {
		GetPetInfoByItemID = function(id) if id == 2002 then return 'Pet', 1, 1, 1, '', '', false, false, false, false, false, 1, 88 end end,
		GetNumCollectedInfo = function(species) if species == 88 then return 1, 3 end end,
	}
	_G.C_UnitAuras = { GetAuraDataByIndex = function(_, i)
		W.auraReads = W.auraReads + 1
		return W.auras[i]
	end }
	_G.C_Secrets = { ShouldAurasBeSecret = function() return W.aurasSecret or false end }
	_G.UnitIsPlayer = function() return true end
end

local function BootTooltip(setup, flavor)
	local ns = H.setup()
	ItemWorld()
	if flavor then
		C_AddOns.GetAddOnMetadata = function(_, field) if field == 'X-SlimARK-Flavor' then return flavor end return '3.0.0' end
	end
	H.load('Config.lua')
	ns.C.modules.tooltip = false -- the extras work without the flat skin
	ns.C.modules.character = false
	if setup then setup(ns.C.tooltipExtras, ns.C) end
	local tip = FakeTip('GameTooltip')
	_G.ItemRefTooltip = FakeTip('ItemRefTooltip')
	H.load('Core.lua')
	H.load('Character.lua')
	H.load('Tooltip.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns, tip
end

------------------------------------------------------------------------
-- Off by default: nothing is hooked.
------------------------------------------------------------------------
do
	local _, tip = BootTooltip()
	H.equal(#calls, 0, '42 all extras off: no tooltip hook is registered')
	H.check(tip:GetScript('OnShow') == nil and not tip._events.PLAYER_REGEN_DISABLED, '42 hide in combat off: GameTooltip is not hooked')
end

------------------------------------------------------------------------
-- 33: the upgrade track replaces Blizzard's line, with the crests to max.
------------------------------------------------------------------------
do
	local _, tip = BootTooltip(function(x) x.upgrade = true end)
	local pre = Find('pre', Enum.TooltipDataLineType.ItemUpgradeLevel)
	H.check(pre ~= nil and #calls == 1, '33 only the upgrade line is hooked')
	W.links.G1 = 'item:hero4'
	W.upgrade['item:hero4'] = { trackString = 'Hero', currentLevel = 4, maxLevel = 6 }
	W.processing = { tooltipData = { guid = 'G1' } }
	H.equal(pre(tip), true, '33 Blizzard\'s upgrade line is replaced')
	H.equal(Lines(tip, 'Upgrade: Hero 4/6'), '2 left · 40 Hero Mistcrest', '33 the track, the steps left and the crests to max')

	tip.lines = {}
	W.upgrade['item:myth6'] = { trackString = 'Myth', currentLevel = 6, maxLevel = 6 }
	W.processing = { tooltipData = { hyperlink = 'item:myth6' } }
	pre(tip)
	H.equal(Lines(tip, 'Upgrade: Myth 6/6'), 'max', '33 a fully upgraded item says max')

	tip.lines = {}
	W.upgrade['item:explorer'] = { trackString = 'Explorer', currentLevel = 1, maxLevel = 8 }
	W.processing = { tooltipData = { hyperlink = 'item:explorer' } }
	pre(tip)
	H.equal(Lines(tip, 'Upgrade: Explorer 1/8'), '7 left', '33 a track without a crest in the season table shows the steps only')

	tip.lines = {}
	W.processing = { tooltipData = { hyperlink = Secret('link') } }
	local ok, result = pcall(pre, tip)
	H.check(ok and result == nil and #tip.lines == 0, '33 a secret link keeps Blizzard\'s line and is not compared')

	tip.lines = {}
	W.upgrade['item:secret'] = { trackString = 'Hero', currentLevel = Secret('rank'), maxLevel = 6 }
	W.processing = { tooltipData = { hyperlink = 'item:secret' } }
	ok, result = pcall(pre, tip)
	H.check(ok and result == nil and #tip.lines == 0, '33 a secret rank keeps Blizzard\'s line')
	NoErrors('33 the upgrade line')
end

do
	BootTooltip(function(x) x.upgrade = true end, 'forever')
	H.equal(#calls, 0, '33 Forever has no item upgrades: nothing is hooked')
end

------------------------------------------------------------------------
-- 42: IDs, count in bags, already known.
------------------------------------------------------------------------
do
	local _, tip = BootTooltip(function(x) x.ids = true x.bagCount = true x.known = true end)
	local item = Find('post', Enum.TooltipDataType.Item)
	local spell = Find('post', Enum.TooltipDataType.Spell)
	local aura = Find('post', Enum.TooltipDataType.UnitAura)
	H.check(item and spell and aura and not Find('post', Enum.TooltipDataType.Unit), '42 items, spells and auras are hooked, units not')

	W.counts[241983] = 1
	item(tip, { id = 241983, lines = {} })
	H.equal(Lines(tip, 'Spell ID / Item ID'), '- / 241983', '42 the item ID, no spell')
	H.equal(Lines(tip, 'In bags'), '1', '42 the count in bags')

	tip.lines = {}
	item(tip, { id = 5512, lines = {} })
	H.equal(Lines(tip, 'Spell ID / Item ID'), '6262 / 5512', '42 an item with a use spell shows both IDs')
	H.check(not Lines(tip, 'In bags'), '42 nothing in bags: no count line')

	tip.lines = {}
	spell(tip, { id = 12345 })
	H.equal(Lines(tip, 'Spell ID'), '12345', '42 the spell ID')
	tip.lines = {}
	local ok = pcall(aura, tip, { id = Secret('aura id') })
	H.check(ok and #tip.lines == 0, '42 a secret aura ID shows no line and is not compared')

	-- Already known: a collected mount, a toy you have, a pet you own; not twice.
	W.mounts[3001] = { mount = 501, collected = true }
	W.mounts[3002] = { mount = 502, collected = false }
	for _, case in ipairs({ { 3001, true, 'a collected mount' }, { 3002, false, 'a mount not collected' }, { 1001, true, 'a toy you have' },
		{ 2002, true, 'a pet you own' }, { 4004, false, 'a plain item' } }) do
		tip.lines = {}
		item(tip, { id = case[1], lines = {} })
		H.equal(Lines(tip, 'Already known') == true, case[2], '42 already known: ' .. case[3])
	end
	tip.lines = {}
	item(tip, { id = 3001, lines = { { leftText = 'Already known' } } })
	H.check(not Lines(tip, 'Already known'), '42 already known is not said twice')

	-- Other tooltips (comparison) get nothing.
	local shopping = FakeTip('ShoppingTooltip1')
	item(shopping, { id = 241983, lines = {} })
	H.equal(#shopping.lines, 0, '42 comparison tooltips get no extras')
	NoErrors('42 IDs, count and already known')
end

------------------------------------------------------------------------
-- 42: the mount a player rides; never from secret auras or in combat.
------------------------------------------------------------------------
do
	local _, tip = BootTooltip(function(x) x.mount = true end)
	local unit = Find('post', Enum.TooltipDataType.Unit)
	H.check(unit ~= nil, '42 the mount switch hooks unit tooltips')
	W.auras = { { spellId = Secret('aura spell') }, { spellId = 1459 }, { spellId = 32345 } }
	unit(tip)
	H.equal(Lines(tip, 'Mount'), 'Swift Razorwing', '42 the mount name from the mount aura, a secret aura skipped')

	tip.lines, W.auraReads = {}, 0
	H.combat = true
	unit(tip)
	H.check(#tip.lines == 0 and W.auraReads == 0, '42 no aura is read in combat')
	H.combat = false
	W.aurasSecret = true
	unit(tip)
	H.check(#tip.lines == 0 and W.auraReads == 0, '42 no aura is read while auras are secret')
	W.aurasSecret = false
	NoErrors('42 the mount line')
end

------------------------------------------------------------------------
-- 42: no tooltip in combat.
------------------------------------------------------------------------
do
	local _, tip = BootTooltip(function(x) x.hideCombat = true end)
	local onShow = tip:GetScript('OnShow')
	H.check(onShow ~= nil, '42 hide in combat hooks GameTooltip')
	tip:Show()
	onShow(tip)
	H.check(tip:IsShown(), '42 out of combat the tooltip shows')
	H.combat = true
	onShow(tip)
	H.check(not tip:IsShown(), '42 in combat the tooltip is hidden')
	tip:Show()
	H.fire('PLAYER_REGEN_DISABLED')
	H.check(not tip:IsShown(), '42 an open tooltip goes when the fight starts')
	H.combat = false
end

------------------------------------------------------------------------
-- 33 on the character sheet, 34 on the inspect window.
------------------------------------------------------------------------
local function BootSheet(setup)
	local ns = H.setup()
	ItemWorld()
	W.inv = { player = 'item:hero4', target = 'item:theirs' }
	W.upgrade['item:hero4'] = { trackString = 'Hero', currentLevel = 4, maxLevel = 6 }
	W.upgrade['item:theirs'] = { trackString = 'Myth', currentLevel = 6, maxLevel = 6 }
	W.asked = {}
	_G.CharacterFrame = H.NewFrame('Frame', 'CharacterFrame', UIParent)
	local head = H.NewFrame('Button', 'CharacterHeadSlot', CharacterFrame)
	H.NewFrame('Button', 'CharacterHandsSlot', CharacterFrame)
	_G.PaperDollItemSlotButton_Update = function() end
	_G.InspectPaperDollItemSlotButton_Update = nil
	_G.GetInventoryItemLink = function(unit, slot)
		table.insert(W.asked, unit)
		return slot == 1 and W.inv[unit] or nil
	end
	_G.ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } }
	_G.C_TooltipInfo = { GetInventoryItem = function(unit)
		return { lines = { { type = Enum.TooltipDataLineType.ItemEnchantmentPermanent, leftText = 'Enchanted: ' .. unit .. ' enchant' } } }
	end }
	_G.C_ChallengeMode = { IsChallengeModeActive = function() return W.running or false end }
	H.load('Config.lua')
	if setup then setup(ns.C) end
	H.load('Core.lua')
	H.load('Character.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns, head
end

local function TextsOf(button)
	local out = {}
	for _, f in ipairs(H.frames) do
		if f._kind == 'FontString' and f._text and f._text ~= '' and (f._parent == button or (f._parent and f._parent._parent == button)) then
			out[tostring(f._text)] = true
		end
	end
	return out
end

do
	local _, head = BootSheet(function(C) C.charsheet.upgrade = true end)
	PaperDollItemSlotButton_Update(head)
	local texts = TextsOf(head)
	H.check(texts['H 4/6'] and texts['700'], '33 the slot shows the track and rank beside the item level')
	NoErrors('33 the character sheet track')
end

do
	local _, head = BootSheet()
	PaperDollItemSlotButton_Update(head)
	H.check(not TextsOf(head)['H 4/6'], '33 the slot track is off by default')
	local blizzard = function() end
	_G.InspectPaperDollItemSlotButton_Update = blizzard
	H.fire('ADDON_LOADED', 'Blizzard_InspectUI')
	H.check(_G.InspectPaperDollItemSlotButton_Update == blizzard, '34 the inspect marks are off by default: nothing is hooked')
end

do
	local _, head = BootSheet(function(C) C.charsheet.inspect = true end)
	-- The inspect window loads later; its slot update is hooked then.
	_G.InspectFrame = H.NewFrame('Frame', 'InspectFrame', UIParent)
	InspectFrame.unit = 'target'
	local slot = H.NewFrame('Button', 'InspectHeadSlot', InspectFrame)
	H.NewFrame('Button', 'InspectHandsSlot', InspectFrame)
	local blizzard = 0
	_G.InspectPaperDollItemSlotButton_Update = function() blizzard = blizzard + 1 end
	H.fire('ADDON_LOADED', 'Blizzard_InspectUI')
	W.asked = {}
	InspectPaperDollItemSlotButton_Update(slot)
	local texts = TextsOf(slot)
	H.check(blizzard == 1 and W.asked[1] == 'target', '34 the inspect slot is read for the inspected unit, after Blizzard\'s update')
	H.check(texts['700'] and texts['target enchant'], '34 the inspect slot gets the item level and the enchant')

	-- In a running key the marks are cleared and nothing is read.
	W.running, W.asked = true, {}
	InspectPaperDollItemSlotButton_Update(slot)
	H.check(#W.asked == 0 and not TextsOf(slot)['700'], '34 no marks in a running key')
	W.running = false

	-- A secret link is never used.
	W.inv.target = Secret('inspect link')
	local ok = pcall(InspectPaperDollItemSlotButton_Update, slot)
	H.check(ok and not TextsOf(slot)['700'], '34 a secret item link leaves the slot empty')
	-- The character sheet still works with the same code.
	PaperDollItemSlotButton_Update(head)
	H.check(TextsOf(head)['player enchant'], '34 the character sheet keeps its own marks')
	NoErrors('34 the inspect marks')
end

H.done()
