-- H2: the ready check window (audit F3, F9, F10, F11). Run from the repository root:
--   lua5.1 tests/claude/ui-readycheck.lua
local H = dofile('tests/claude/lib/helpers.lua')

-- The world the window reads: bag items, buffs, the group and the gear.
local world

local function Boot(locale)
	local ns = H.setup()
	world = {
		bag = {}, auras = {}, classes = { player = 'WARRIOR' }, raid = false, members = 1,
		durability = { [1] = { 80, 100 } }, enchant = nil, itemSpells = {}, locale = locale or 'enUS',
	}
	local consumable, enhancement = Enum.ItemClass.Consumable, Enum.ItemClass.ItemEnhancement
	world.CONSUMABLE, world.ENHANCEMENT = consumable, enhancement
	_G.GetLocale = function() return world.locale end
	_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
	_G.C_Container = {
		GetContainerNumSlots = function() return #world.bag end,
		GetContainerItemInfo = function(_, slot)
			local item = world.bag[slot]
			return item and { itemID = item.id, iconFileID = item.icon or 1 }
		end,
	}
	_G.C_Item = {
		GetItemInfoInstant = function(id)
			for _, item in ipairs(world.bag) do
				if item.id == id then return id, nil, nil, nil, nil, item.class, item.subclass end
			end
		end,
		GetItemInfo = function() return nil end,
		GetItemNameByID = function(id)
			for _, item in ipairs(world.bag) do if item.id == id then return item.name end end
		end,
		GetItemSpell = function(id)
			local spell = world.itemSpells[id]
			if spell then return 'spell', spell end
		end,
	}
	_G.C_TooltipInfo = { GetBagItem = function() return { lines = {} } end }
	_G.ITEM_SPELL_TRIGGER_ONUSE = 'Use:'
	_G.C_UnitAuras = {
		GetAuraDataByIndex = function(_, i) return world.auras[i] end,
		GetPlayerAuraBySpellID = function(id)
			for _, aura in ipairs(world.auras) do if aura.spellId == id then return aura end end
		end,
	}
	_G.UnitClass = function(unit) local c = world.classes[unit] return c, c end
	_G.IsInRaid = function() return world.raid end
	_G.GetNumGroupMembers = function() return world.members end
	_G.UnitExists = function(unit) return world.classes[unit] ~= nil end
	_G.UnitIsUnit = function(a, b) return a == b end
	_G.Ambiguate = function(name) return name end
	_G.C_Spell = { GetSpellName = function(id) return 'Buff ' .. id end, GetSpellTexture = function() return 1 end }
	_G.GetInventoryItemDurability = function(slot)
		local d = world.durability[slot]
		if d then return d[1], d[2] end
	end
	_G.C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot) return slot == 16 and world.enchant or nil end }
	_G.INVSLOT_MAINHAND = 16
	-- The deprecated fallback is not loaded (loadDeprecationFallbacks off, or a future patch).
	_G.GetWeaponEnchantInfo = nil
	_G.ReadyCheckListenerFrame = H.NewFrame('Frame', 'ReadyCheckListenerFrame', UIParent)
	H.load('Config.lua')
	-- Only its IsWeaponImbue is used here, not the consumable bar.
	ns.C.modules.consumables = false
	H.load('Core.lua')
	H.load('Consumables.lua')
	H.load('ReadyCheck.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

local function Rows()
	local rows = {}
	for _, f in ipairs(H.frames) do
		if f._parent == SlimARK_ReadyCheck and f.label and f.status then table.insert(rows, f) end
	end
	return rows
end

local function RowByLabel(label)
	for _, r in ipairs(Rows()) do
		if r:IsShown() and r.label:GetText() == label then return r end
	end
end

local function UseButtonShown()
	for i = 1, 4 do
		local b = _G['SlimARK_ReadyCheckUse' .. i]
		if b and b:IsShown() then return b end
	end
end

------------------------------------------------------------------------
-- F3: no GetWeaponEnchantInfo; the main hand enchant comes from C_PaperDollInfo.
------------------------------------------------------------------------
do
	Boot('enUS')
	world.enchant = { remainingTimeMs = 45 * 60000, enchantID = 1, chargesRemaining = 0, hasExpirationTime = true }
	ReadyCheckListenerFrame:Show()
	H.fire('READY_CHECK', 'Leader', 30)
	H.equal(SlimARK_ReadyCheck:IsShown(), true, 'F3 the window opens without GetWeaponEnchantInfo')
	local oil = RowByLabel('Weapon oil')
	H.check(oil and oil.status:GetText() == '45 min', 'F3 the weapon oil row reads the C_PaperDollInfo enchant (45 min)')
	H.equal(ReadyCheckListenerFrame:IsShown(), false, 'F3 Blizzard\'s window steps aside once ours is built')
	H.equal(SlimARK_ReadyCheck.yes:IsShown(), true, 'F3 the Ready button is there')
	H.fire('READY_CHECK_FINISHED')
end

do
	-- Building fails: ours closes again and Blizzard's window keeps the check.
	Boot('enUS')
	_G.C_PaperDollInfo.GetTemporaryEnchantmentInfo = function() error('no enchant API') end
	ReadyCheckListenerFrame:Show()
	H.fire('READY_CHECK', 'Leader', 30)
	H.equal(SlimARK_ReadyCheck:IsShown(), false, 'F3 a failed build closes our window')
	H.equal(ReadyCheckListenerFrame:IsShown(), true, 'F3 a failed build leaves Blizzard\'s window shown')
	local reported = false
	for _, line in ipairs(H.prints) do if line:find('no enchant API', 1, true) then reported = true end end
	H.check(reported, 'F3 the error is reported, not swallowed')
end

------------------------------------------------------------------------
-- F10: a raid with every class buff and worn gear shows all 11 rows.
------------------------------------------------------------------------
do
	Boot('enUS')
	world.raid, world.members = true, 6
	world.classes = { player = 'WARRIOR', raid1 = 'MAGE', raid2 = 'PRIEST', raid3 = 'WARRIOR', raid4 = 'DRUID', raid5 = 'SHAMAN', raid6 = 'EVOKER' }
	H.fire('READY_CHECK', 'Leader', 30)
	local shown = 0
	for _, r in ipairs(Rows()) do if r:IsShown() then shown = shown + 1 end end
	H.equal(shown, 11, 'F10 eleven rows in a full raid')
	local durability = RowByLabel('Durability')
	H.check(durability ~= nil and durability.status:GetText() == '80%', 'F10 the durability row is shown (80%)')
	local height = H.lastCall(SlimARK_ReadyCheck, 'SetHeight')
	H.check(height and height[1] >= 34 + 11 * 40, 'F10 the window is tall enough for 11 rows')
	H.fire('READY_CHECK_FINISHED')
end

------------------------------------------------------------------------
-- F9: the secure Use buttons go when combat starts, before the lockdown.
------------------------------------------------------------------------
do
	Boot('enUS')
	world.bag = { { id = 5001, class = world.CONSUMABLE, subclass = 3, name = 'Flask of Testing' } }
	world.itemSpells[5001] = 9001
	H.fire('READY_CHECK', 'Leader', 30)
	local button = UseButtonShown()
	H.check(button ~= nil, 'F9 a missing flask gets a Use button')

	-- PLAYER_REGEN_DISABLED comes while InCombatLockdown() is still false.
	H.fire('PLAYER_REGEN_DISABLED')
	H.equal(button:IsShown(), false, 'F9 the Use button is hidden as combat starts')
	H.equal(button:GetAlpha(), 1, 'F9 it is really hidden, not only transparent')
	H.equal(RowByLabel('Flask').status:IsShown(), true, 'F9 the flask row shows its status again')

	H.combat = true
	H.fire('READY_CHECK_FINISHED')
	H.equal(button:IsShown(), false, 'F9 the check ends in combat: no invisible button left behind')

	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(UseButtonShown(), nil, 'F9 after combat a closed check shows no button')
end

do
	-- The check outlasts the fight: after combat its buttons come back.
	Boot('enUS')
	world.bag = { { id = 5001, class = world.CONSUMABLE, subclass = 3, name = 'Flask of Testing' } }
	world.itemSpells[5001] = 9001
	H.fire('READY_CHECK', 'Leader', 30)
	H.fire('PLAYER_REGEN_DISABLED')
	H.combat = true
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.check(UseButtonShown() ~= nil, 'F9 an open check gets its Use button back after combat')
end

------------------------------------------------------------------------
-- F11: a German client: runes and oils by item ID, flask buffs by their item's spell.
------------------------------------------------------------------------
do
	Boot('deDE')
	world.bag = {
		{ id = 224572, class = world.CONSUMABLE, subclass = 8, name = 'Kristallisierte Augmentrune' },
		{ id = 243735, class = world.CONSUMABLE, subclass = 6, name = 'Öl der Morgendämmerung' },
		{ id = 5002, class = world.CONSUMABLE, subclass = 3, name = 'Fläschchen der Prüfung' },
	}
	world.itemSpells[224572] = 453250
	world.itemSpells[5002] = 9002
	H.fire('READY_CHECK', 'Leader', 30)
	local rune = RowByLabel('Augment rune')
	H.check(rune ~= nil and not rune.status:IsShown(), 'F11 deDE: the rune in the bags is found by ID and gets a Use button')
	local oil = RowByLabel('Weapon oil')
	H.check(oil ~= nil and not oil.status:IsShown(), 'F11 deDE: Oil of Dawn is found by ID and gets an Apply button')
	H.fire('READY_CHECK_FINISHED')

	-- The flask is drunk: none left in the bags, its buff (German name) is on.
	world.bag = {}
	world.auras = { { name = 'Fläschchen der Prüfung', spellId = 9002, icon = 2, expirationTime = H.now + 1800 } }
	H.fire('READY_CHECK', 'Leader', 30)
	local flask = RowByLabel('Flask')
	H.check(flask ~= nil and flask.status:GetText() == '30 min', 'F11 deDE: the flask buff is known by its item\'s spell (30 min)')

	-- A rune buff with no rune in the bags: known from the rune items' own spells.
	world.auras = { { name = 'Augmentrune', spellId = 453250, icon = 3, expirationTime = H.now + 3600 } }
	H.fire('READY_CHECK', 'Leader', 30)
	rune = RowByLabel('Augment rune')
	H.check(rune ~= nil and rune.status:GetText() == '60 min', 'F11 deDE: the rune buff is known without a rune in the bags')
	H.fire('READY_CHECK_FINISHED')
end

do
	-- deDE: a buff with an English-looking name is not taken for a flask by its name.
	Boot('deDE')
	world.auras = { { name = 'Flask of Nothing', spellId = 7777, icon = 2, expirationTime = H.now + 600 } }
	H.fire('READY_CHECK', 'Leader', 30)
	H.equal(RowByLabel('Flask').status:GetText(), 'missing', 'F11 deDE: English name rules are not applied')
	H.fire('READY_CHECK_FINISHED')

	-- enUS keeps the name rule as a last resort (cauldron flask, no item seen).
	Boot('enUS')
	world.auras = { { name = 'Flask of Nothing', spellId = 7777, icon = 2, expirationTime = H.now + 600 } }
	H.fire('READY_CHECK', 'Leader', 30)
	H.equal(RowByLabel('Flask').status:GetText(), '10 min', 'F11 enUS: the English name rule still works')
end

do
	-- Consumables: an unknown item is not parsed as English text on a German client.
	local ns = Boot('deDE')
	local asked = false
	_G.C_TooltipInfo.GetBagItem = function() asked = true return { lines = { { leftText = 'Use: Coat your weapon for 60 min.' } } } end
	H.equal(ns.IsWeaponImbue(0, 1, 999999), false, 'F11 deDE: an unknown item is not read as English')
	H.equal(asked, false, 'F11 deDE: its tooltip is not even scanned')
	H.equal(ns.IsWeaponImbue(0, 1, 243737), true, 'F11 deDE: Smuggler\'s Enchanted Edge is known by ID')
	world.locale = 'enUS'
	H.equal(ns.IsWeaponImbue(0, 1, 999998), true, 'F11 enUS: an older oil is still read from its English description')
end

H.done()
