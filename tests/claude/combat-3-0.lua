-- 3.0 part B: the enemy cast list and YOU mark (1), forces % (2), interrupt strips (4), focus mark
-- (11), focus sound (12), purge rows (13), plate marks (14), GCD line (16), spender marks (17), buff
-- reminder (22), raid order (24), arena frames (58) and their test mode. Run from the repository root:
--   lua5.1 tests/claude/combat-3-0.lua
local H = dofile('tests/claude/lib/helpers.lua')

------------------------------------------------------------------------
-- Hidden values. The game's secret values can only go to widgets; here they are userdata whose
-- concatenation, arithmetic, ordering, length and indexing fail loudly, and issecretvalue knows them.
------------------------------------------------------------------------
local function Secret(label)
	local value = newproxy(true)
	local meta = getmetatable(value)
	local function fail() error('a hidden value (' .. label .. ') was used in Lua', 2) end
	meta.__concat, meta.__add, meta.__sub, meta.__mul, meta.__div = fail, fail, fail, fail, fail
	meta.__lt, meta.__le, meta.__len, meta.__index, meta.__unm, meta.__call = fail, fail, fail, fail, fail, fail
	meta.__tostring = function() return 'secret:' .. label end
	H.secret = H.secret or {}
	H.secret[value] = true
	return value
end

-- An object whose every method call is recorded: duration objects, bindings, formatters, curves.
local function Recorder()
	local r = { calls = {} }
	return setmetatable(r, { __index = function(t, key)
		local fn = function(_, ...)
			table.insert(t.calls, { key, ... })
		end
		rawset(t, key, fn)
		return fn
	end })
end
local function Called(r, name)
	local list = {}
	for _, call in ipairs(r.calls) do
		if call[1] == name then list[#list + 1] = call end
	end
	return list
end

local world, oUF

-- Loads the 3.0 part B files with a stand-in oUF and runs the login and the oUF factories.
-- tweak(C): changes ns.C after Config.lua, before the modules read it.
local function Boot(tweak, extra)
	-- Named frames of the last boot are gone with it.
	for _, f in ipairs(H.frames) do
		if f._name then _G[f._name] = nil end
	end
	local ns = H.setup()
	world = {
		names = {}, classes = { player = 'ROGUE' }, roles = {}, guids = { player = 'GP' }, exists = { player = true },
		canAttack = {}, casting = {}, channel = {}, spellTarget = {}, classification = {}, quest = {},
		cooldown = {}, spec = 259, power = { 3, 'ENERGY' }, powerMax = 100, auras = {}, known = {},
		party = 0, raid = false, roster = {}, meterRows = {}, spells = {}, inspect = {}, combat = false,
		sounds = {}, inInstance = true, enchant = nil, mainHand = 1234,
	}
	oUF = { Tags = { Methods = {}, Events = {} }, styles = {}, factories = {} }
	function oUF:RegisterStyle(name, fn) self.styles[name] = fn end
	function oUF:Factory(fn) table.insert(self.factories, fn) end
	function oUF:SetActiveStyle() end
	function oUF:Spawn(_, name) return H.NewFrame('Button', name, UIParent) end
	function oUF:SpawnHeader(name, _, ...)
		local header = H.NewFrame('Frame', name, UIParent)
		for i = 1, select('#', ...), 2 do header:SetAttribute((select(i, ...)), (select(i + 1, ...))) end
		function header:SetVisibility(value) self.visibility = value end
		return header
	end
	function oUF:SpawnNamePlates()
		return { SetSize = function() end, SetAddedCallback = function(_, fn) world.added = fn end }
	end
	ns.oUF = oUF

	_G.PartyFrame = H.NewFrame('Frame', 'PartyFrame', UIParent)
	_G.CompactRaidFrameContainer = H.NewFrame('Frame', 'CompactRaidFrameContainer', UIParent)
	_G.C_SpecializationInfo = {
		GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function() return world.spec, nil, nil, nil, world.role or 'DAMAGER' end,
	}
	_G.C_SpellBook = { IsSpellKnownOrInSpellBook = function(id) return world.known[id] or false end }
	_G.C_Spell = {
		IsSpellImportant = function() return world.important end,
		GetSpellCooldown = function(id) return world.cooldown[id] end,
		GetSpellCooldownDuration = function(id) return world.cooldown[id] and world.cooldown[id].duration end,
		GetSpellTexture = function(id) return 'icon' .. id end,
		GetSpellName = function(id) return ({ [6673] = 'Battle Shout', [1459] = 'Arcane Intellect' })[id] or ('spell' .. id) end,
	}
	_G.C_ClassColor = { GetClassColor = function(class) return { r = 0.1, g = 0.2, b = 0.3, class = class } end }
	_G.C_Secrets = { CanCompareUnitTokens = function() return true end, ShouldAurasBeSecret = function() return world.aurasSecret or false end }
	_G.C_StringUtil = { CreateSecondsFormatter = function() return Recorder() end }
	_G.C_DurationUtil = { CreateDuration = function() return Recorder() end, CreateDurationTextBinding = function() return Recorder() end }
	_G.C_CurveUtil = { CreateColorCurve = function() world.curve = Recorder() return world.curve end }
	_G.AuraUtil = { AuraFilters = { Helpful = 'HELPFUL', Dispellable = 'DISPELLABLE' } }
	_G.SOUNDKIT = { ALARM_CLOCK_WARNING_3 = 12889 }
	_G.PlaySound = function(id, channel) table.insert(world.sounds, { id, channel }) end
	_G.IsInGroup = function() return world.party > 0 or world.raid end
	_G.IsInRaid = function() return world.raid end
	_G.GetNumSubgroupMembers = function() return world.party end
	_G.GetNumGroupMembers = function() return world.raid and #world.roster or world.party + 1 end
	_G.GetRaidRosterInfo = function(i)
		local r = world.roster[i]
		if not r then return end
		return r[1], nil, 1, nil, nil, nil, nil, nil, nil, nil, nil, r[2]
	end
	_G.UnitInRaid = function() return world.me end
	_G.UnitName = function(unit) return world.names[unit] or 'Me' end
	_G.UnitClass = function(unit) return 'Class', world.classes[unit] end
	_G.UnitClassBase = function(unit) return world.classes[unit] end
	_G.UnitGUID = function(unit) return world.guids[unit] end
	_G.UnitExists = function(unit) return world.exists[unit] or false end
	_G.UnitIsDead = function() return false end
	_G.UnitIsDeadOrGhost = function() return false end
	_G.UnitGroupRolesAssigned = function(unit) return world.roles[unit] or 'NONE' end
	_G.GetInspectSpecialization = function(unit) return world.inspect[unit] or 0 end
	_G.GetSpecializationInfoByID = function(id)
		local specs = { [259] = { 'Assassination', 'ROGUE' }, [64] = { 'Frost', 'MAGE' }, [62] = { 'Arcane', 'MAGE' } }
		local s = specs[id]
		if s then return id, s[1], '', 'specicon' .. id, nil, s[2] end
	end
	_G.UnitCanAttack = function(_, unit)
		local v = world.canAttack[unit]
		if v == nil then return true end
		return v
	end
	_G.UnitIsPlayer = function() return false end
	_G.UnitIsFriend = function() return false end
	_G.UnitIsLieutenant = function() return false end
	_G.UnitPowerType = function() return world.power[1], world.power[2] end
	_G.UnitPowerMax = function() return world.powerMax end
	_G.UnitClassification = function(unit) return world.classification[unit] or 'normal' end
	_G.C_QuestLog = { UnitIsRelatedToActiveQuest = function(unit) return world.quest[unit] or false end }
	_G.UnitThreatSituation = function() return nil end
	_G.UnitAffectingCombat = function() return false end
	_G.UnitCastingInfo = function(unit)
		local c = world.casting[unit]
		if c then return c.name, c.text, nil, nil, nil, nil, nil, c.notInterruptible, c.spell end
	end
	_G.UnitChannelInfo = function(unit)
		local c = world.channel[unit]
		if c then return c.name, c.text, nil, nil, nil, nil, c.notInterruptible, c.spell end
	end
	_G.UnitCastingDuration = function(unit) return world.casting[unit] and world.casting[unit].duration end
	_G.UnitChannelDuration = function(unit) return world.channel[unit] and world.channel[unit].duration end
	_G.UnitShouldDisplaySpellTargetName = function(unit) return world.spellTarget[unit] ~= nil end
	_G.UnitSpellTargetName = function(unit) return world.spellTarget[unit].name end
	_G.UnitSpellTargetClass = function(unit) return world.spellTarget[unit].class end
	_G.PlayerIsSpellTarget = function(unit) return world.spellTarget[unit] and world.spellTarget[unit].me end
	_G.C_NamePlate = { GetNamePlateForUnit = function(unit) return unit == 'focus' and world.focusPlate or nil end }
	_G.C_ChallengeMode = { IsChallengeModeActive = function() return world.key or false end }
	_G.C_ScenarioInfo = { GetUnitCriteriaProgressValues = function(unit)
		local f = world.forces and world.forces[unit]
		if f then return f[1], f[2], f[3] end
	end }
	_G.C_DamageMeter = {
		GetCombatSessionFromType = function()
			if world.meterSecret then return Secret('session') end
			return { combatSources = world.meterRows }
		end,
		GetCombatSessionSourceFromType = function(_, _, guid)
			local n = world.spells[guid]
			if not n then return { combatSpells = {} } end
			local list = {}
			for i = 1, n do list[i] = { spellID = i } end
			return { combatSpells = list }
		end,
	}
	_G.IsPlayerSpell = function(id) return world.known[id] or false end
	_G.C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return world.auras[id] end }
	_G.C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function() return world.enchant end }
	_G.GetInventoryItemID = function() return world.mainHand end
	_G.INVSLOT_MAINHAND = 16
	_G.IsInInstance = function() return world.inInstance end
	_G.IsMounted = function() return false end
	_G.GetNumArenaOpponentSpecs = function() return 0 end
	_G.GetArenaOpponentSpec = function(i) return world.arenaSpecs and world.arenaSpecs[i] end
	_G.RAID_CLASS_COLORS = {}
	_G.AbbreviateNumbers = function(n) return tostring(n) end
	_G.UnitFrame_OnEnter, _G.UnitFrame_OnLeave = function() end, function() end
	_G.GetTotemInfo, _G.TotemFrame = nil, nil

	H.load('Config.lua')
	if tweak then tweak(ns.C) end
	H.load('Core.lua')
	H.load('Role.lua')
	H.load('UnitFrames.lua')
	H.load('NamePlates.lua')
	H.load('CastList.lua')
	H.load('Kicks.lua')
	H.load('BuffReminder.lua')
	if extra then extra(ns) end
	ns.SyncLayout = function() end
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	for _, fn in ipairs(oUF.factories) do fn(oUF) end
	return ns
end

local function Style(unit, parent)
	local frame = H.NewFrame('Button', nil, parent and _G[parent] or UIParent)
	frame.colors = { dispel = {} }
	oUF.styles['SlimARK-UI'](frame, unit)
	return frame
end

local function Plate(unit)
	local plate = H.NewFrame('Frame', nil, UIParent)
	oUF.styles.SlimARKPlate(plate)
	plate.__unit = unit
	plate.Castbar.__owner = plate
	plate.Health.__owner = plate
	plate.Health.ForceUpdate = function() end
	world.added(plate, nil, unit)
	return plate
end

local function Children(parent, kind)
	local list = {}
	for _, f in ipairs(H.frames) do
		if f._parent == parent and (not kind or f._kind == kind) then list[#list + 1] = f end
	end
	return list
end

-- Which frames listen to an event.
local function Listens(event)
	for _, f in ipairs(H.frames) do
		if f._events[event] and f._scripts.OnEvent then return true end
	end
	return false
end

local ALL_OFF = { 'castList', 'castYou', 'plateForces', 'kickStrip', 'focusMark', 'focusSound', 'platePurge',
	'targetPurge', 'plateMarks', 'gcdLine', 'spenderTicks', 'buffReminder', 'raidSort', 'arenaFrames' }

------------------------------------------------------------------------
-- Every switch off: nothing is made and nothing listens.
------------------------------------------------------------------------
do
	Boot(function(C) for _, key in ipairs(ALL_OFF) do C.features[key] = false end end)
	H.check(_G.SlimARK_CastList == nil, 'off: no cast column')
	H.check(not Listens('UNIT_SPELLCAST_START'), 'off: nobody listens to cast starts')
	H.check(not Listens('NAME_PLATE_UNIT_ADDED'), 'off: nobody listens to plates for the cast list')
	H.check(_G.SlimARK_BuffReminder == nil and not Listens('UNIT_INVENTORY_CHANGED'), 'off: no buff reminder')
	H.check(not Listens('DAMAGE_METER_COMBAT_SESSION_UPDATED'), 'off: the damage meter is not read')
	H.check(_G.SlimARK_Arena1 == nil, 'off: no arena frames')
	H.equal(SlimARK_Raid:GetAttribute('groupFilter'), '1,2,3,4,5,6,7,8', 'off: the raid keeps its group order')
	world.raid, world.roster, world.me = true, { { 'Me', 'DAMAGER' }, { 'Tank', 'TANK' } }, 1
	H.fire('GROUP_ROSTER_UPDATE')
	H.runTimers(0)
	H.check(SlimARK_Raid:GetAttribute('nameList') == nil, 'off: no name list on the raid')
	local player = Style('player')
	H.check(player.YouMark == nil and player.GcdLine == nil and player.SpenderTicks == nil, 'off: no YOU mark, GCD line or spender marks')
	local party = Style(nil, 'SlimARK_Party')
	H.check(party.KickStrip == nil, 'off: no interrupt strip')
	local target = Style('target')
	local purge = false
	for _, f in ipairs(Children(target)) do
		for _, call in ipairs(H.calls(f, 'AddGroup')) do if call[1]:find('DISPELLABLE') then purge = true end end
	end
	H.check(not purge, 'off: no purge row on the target')
	local plate = Plate('nameplate1')
	H.check(plate.PlateMark == nil and plate.Forces == nil and plate.FocusMark == nil, 'off: no plate mark, forces or focus mark')
	purge = false
	for _, f in ipairs(Children(plate)) do
		for _, call in ipairs(H.calls(f, 'AddGroup')) do if call[1]:find('DISPELLABLE') then purge = true end end
	end
	H.check(not purge, 'off: no purge row on the plate')
	H.check(not Listens('PLAYER_FOCUS_CHANGED'), 'off: the focus change is not watched')
end

------------------------------------------------------------------------
-- 1: the enemy cast list and the YOU mark.
------------------------------------------------------------------------
local function Rows()
	local list = {}
	for _, f in ipairs(Children(SlimARK_CastList, 'StatusBar')) do list[#list + 1] = f end
	return list
end

local function Cast(unit, label, me)
	world.casting[unit] = { name = Secret(label), text = Secret(label .. ' text'), notInterruptible = Secret('notInt'),
		spell = Secret('spell'), duration = Recorder() }
	world.spellTarget[unit] = { name = Secret('Bob'), class = Secret('PRIEST'), me = me or Secret('me') }
	world.exists[unit] = true
	H.fire('UNIT_SPELLCAST_START', unit)
end

do
	Boot()
	local player = Style('player')
	H.check(player.YouMark ~= nil, 'cast list: the player frame gets the YOU mark holder')
	H.check(SlimARK_CastList ~= nil, 'cast list: the column exists')
	local placed
	for _, item in ipairs(H.ns.Placed) do if item.key == 'castlist' then placed = item end end
	H.check(placed and placed.heal, 'cast list: it can be dragged in Edit Mode, with a healer place')
	local rows = Rows()
	H.equal(#rows, 5, 'cast list: five rows at most')

	world.important = Secret('important')
	local me = Secret('me')
	Cast('nameplate1', 'Shadow Bolt', me)
	H.check(not rows[1]:IsShown(), 'cast list: the column waits for the next frame')
	H.runTimers(0)
	local row = rows[1]
	H.check(row:IsShown(), 'cast list: a cast gets a row')
	H.check(H.secret[row.Text:GetText()], 'cast list: the hidden spell name goes to the row as it is')
	local timer = H.lastCall(row, 'SetTimerDuration')
	H.check(timer and timer[1] == world.casting.nameplate1.duration, 'cast list: the bar runs on the cast\'s duration object')
	H.check(#Called(row.binding, 'SetDuration') == 1, 'cast list: the time left runs on a duration text binding')
	local shield = H.lastCall(row.Shield, 'SetAlphaFromBoolean')
	H.check(shield and shield[1] == world.casting.nameplate1.notInterruptible, 'cast list: not interruptible goes to the gray cover')
	local color = H.lastCall(row:GetStatusBarTexture(), 'SetVertexColorFromBoolean')
	H.check(color and color[1] == world.important and color[2] == row.castColors.important, 'cast list: important casts are magenta, as on the plates')
	local you = H.lastCall(row.You, 'SetAlphaFromBoolean')
	local name = H.lastCall(row.Target, 'SetAlphaFromBoolean')
	H.check(you and you[1] == me and you[2] == 1 and name[2] == 0, 'cast list: a cast on you shows a red YOU in place of the name')
	H.check(H.secret[row.Target:GetText()], 'cast list: the target name goes to the row as it is')
	local layers = Children(player.YouMark)
	H.equal(#layers, 1, 'YOU mark: one layer per cast')
	local layer = H.lastCall(layers[1], 'SetAlphaFromBoolean')
	H.check(layer and layer[1] == me and layer[2] == 1 and layer[3] == 0, 'YOU mark: the game shows it when the cast is aimed at you')

	-- Your interrupt goes on cooldown: the shown row goes dark like the plate bars, and back.
	world.known[1766] = true
	H.fire('SPELLS_CHANGED')
	world.cooldown[1766] = { isActive = true, isOnGCD = false }
	H.fire('SPELL_UPDATE_COOLDOWN')
	color = H.lastCall(row:GetStatusBarTexture(), 'SetVertexColorFromBoolean')
	H.check(color[2] == row.castColors.importantDim and color[3] == row.castColors.normalDim,
		'cast list: the row goes dark while your interrupt is on cooldown')
	world.cooldown[1766] = nil
	H.fire('SPELL_UPDATE_COOLDOWN')
	color = H.lastCall(row:GetStatusBarTexture(), 'SetVertexColorFromBoolean')
	H.check(color[2] == row.castColors.important, 'cast list: bright again when it is ready')

	-- No target: a gray dash.
	world.casting.nameplate2 = { name = Secret('x'), notInterruptible = false, spell = 1, duration = Recorder() }
	world.exists.nameplate2 = true
	H.fire('UNIT_SPELLCAST_START', 'nameplate2')
	H.runTimers(0)
	H.equal(rows[2].Target:GetText(), '-', 'cast list: a cast without a target shows a dash')
	H.check(rows[2]:IsShown(), 'cast list: the second cast gets the second row')

	-- A friendly plate is left out; a hidden answer keeps the cast.
	world.canAttack.nameplate3 = false
	Cast('nameplate3', 'Heal')
	H.runTimers(0)
	H.check(not rows[3]:IsShown(), 'cast list: a friendly cast is left out')
	world.canAttack.nameplate3 = Secret('attackable')
	Cast('nameplate3', 'Heal')
	H.runTimers(0)
	H.check(rows[3]:IsShown(), 'cast list: a hidden "can attack" keeps the cast')

	-- More than five: the sixth waits for a free row.
	for i = 4, 6 do Cast('nameplate' .. i, 'Bolt ' .. i) end
	H.runTimers(0)
	H.check(rows[5]:IsShown(), 'cast list: five rows show')
	world.casting.nameplate1 = nil
	H.fire('UNIT_SPELLCAST_STOP', 'nameplate1')
	H.runTimers(0)
	H.check(rows[5]:IsShown() and H.lastCall(rows[5], 'SetTimerDuration')[1] == world.casting.nameplate6.duration,
		'cast list: a stopped cast frees its row, the waiting one moves in')
	H.check(not layers[1]:IsShown() and layers[1]:GetAlpha() == 0, 'YOU mark: the layer of a stopped cast hides')

	-- A stop while the unit already casts the next spell keeps the row.
	H.fire('UNIT_SPELLCAST_STOP', 'nameplate2')
	H.runTimers(0)
	H.check(rows[1]:IsShown(), 'cast list: a stop with the next cast running keeps it')

	-- A plate that goes away takes its cast with it; leaving the world clears the column.
	H.fire('NAME_PLATE_UNIT_REMOVED', 'nameplate2')
	H.fire('PLAYER_ENTERING_WORLD')
	H.runTimers(0)
	local any = false
	for _, r in ipairs(rows) do any = any or r:IsShown() end
	H.check(not any, 'cast list: a new world clears the column')
	-- Party members' casts are not enemy casts.
	world.casting.party1 = world.casting.nameplate4
	H.fire('UNIT_SPELLCAST_START', 'party1')
	H.runTimers(0)
	H.check(not rows[1]:IsShown(), 'cast list: only nameplate units count')
	-- A plate that shows while its mob casts.
	H.fire('NAME_PLATE_UNIT_ADDED', 'nameplate4')
	H.runTimers(0)
	H.check(rows[1]:IsShown(), 'cast list: a plate that appears mid-cast gets a row')
	-- A channel runs down.
	world.channel.nameplate7 = { name = Secret('ch'), notInterruptible = false, spell = 2, duration = Recorder() }
	world.exists.nameplate7 = true
	H.fire('UNIT_SPELLCAST_CHANNEL_START', 'nameplate7')
	H.runTimers(0)
	local call = H.lastCall(rows[2], 'SetTimerDuration')
	H.check(call and call[1] == world.channel.nameplate7.duration and call[3] == Enum.StatusBarTimerDirection.RemainingTime,
		'cast list: a channel runs down')
end

do
	-- Only the list on: no YOU mark. Only the YOU mark on: no column, the casts still mark you.
	Boot(function(C) C.features.castYou = false end)
	H.check(Style('player').YouMark == nil, 'YOU mark off: the player frame has none')
	Boot(function(C) C.features.castList = false end)
	local player = Style('player')
	H.check(SlimARK_CastList == nil, 'cast list off: no column')
	Cast('nameplate1', 'Bolt')
	H.runTimers(0)
	H.equal(#Children(player.YouMark), 1, 'cast list off: the YOU mark still follows the casts')
end

------------------------------------------------------------------------
-- 12: the focus cast sound.
------------------------------------------------------------------------
do
	Boot()
	world.canAttack.focus = true
	H.fire('UNIT_SPELLCAST_START', 'focus')
	H.equal(#world.sounds, 1, 'focus sound: a focus cast plays the sound')
	H.equal(world.sounds[1][2], 'SFX', 'focus sound: on the effects channel')
	H.fire('UNIT_SPELLCAST_CHANNEL_START', 'focus')
	H.equal(#world.sounds, 2, 'focus sound: every cast, channels too')
	world.canAttack.focus = false
	H.fire('UNIT_SPELLCAST_START', 'focus')
	H.equal(#world.sounds, 2, 'focus sound: a friendly focus stays quiet')
	world.canAttack.focus = Secret('attackable')
	H.fire('UNIT_SPELLCAST_START', 'focus')
	H.equal(#world.sounds, 3, 'focus sound: a hidden answer still plays')
	Boot(function(C) C.features.focusSound = false end)
	world.canAttack.focus = true
	H.fire('UNIT_SPELLCAST_START', 'focus')
	H.equal(#world.sounds, 0, 'focus sound off: quiet')
end

------------------------------------------------------------------------
-- Plates: 14 marks, 2 forces, 11 focus mark, 13 purge row.
------------------------------------------------------------------------
do
	Boot()
	world.classification.nameplate1 = 'elite'
	local plate = Plate('nameplate1')
	H.check(plate.PlateMark:IsShown() and plate.PlateMark.text:GetText() == 'E', 'marks: an elite gets E')
	H.equal(H.lastCall(plate.PlateName, 'SetPoint')[2], plate.PlatePct, 'marks: the name still ends at the health text')
	world.classification.nameplate2 = 'rareelite'
	H.equal(Plate('nameplate2').PlateMark.text:GetText(), 'R', 'marks: a rare elite gets R')
	world.quest.nameplate3, world.classification.nameplate3 = true, 'elite'
	H.equal(Plate('nameplate3').PlateMark.text:GetText(), '!', 'marks: a quest mob gets ! over E')
	local normal = Plate('nameplate4')
	H.check(not normal.PlateMark:IsShown(), 'marks: a normal mob gets none')
	world.classification.nameplate5 = Secret('class')
	world.quest.nameplate5 = Secret('quest')
	H.check(not Plate('nameplate5').PlateMark:IsShown(), 'marks: hidden values give no mark')
	-- A quest update looks again, once for a burst.
	world.quest.nameplate4 = true
	H.fire('QUEST_LOG_UPDATE')
	H.fire('QUEST_LOG_UPDATE')
	H.runTimers(0.2)
	H.equal(normal.PlateMark.text:GetText(), '!', 'marks: a quest update marks the plate')

	-- Forces: only in a key, the hidden text as it is.
	H.equal(plate.Forces:GetText(), '', 'forces: no text out of a key')
	world.key = true
	local label = Secret('3.12%')
	world.forces = { nameplate1 = { Secret('5'), Secret('3.12'), label } }
	H.fire('CHALLENGE_MODE_START')
	H.equal(plate.Forces:GetText(), label, 'forces: in a key the forces text goes under the plate')
	H.equal(normal.Forces:GetText(), '', 'forces: a mob that gives nothing shows nothing')
	plate.Castbar:Show()
	plate.Castbar:GetScript('OnShow')(plate.Castbar)
	H.equal(plate.Forces:GetAlpha(), 0, 'forces: the cast bar takes the place while it shows')
	plate.Castbar:GetScript('OnHide')(plate.Castbar)
	H.equal(plate.Forces:GetAlpha(), 1, 'forces: and gives it back')
	world.key = false
	H.fire('CHALLENGE_MODE_COMPLETED')
	H.equal(plate.Forces:GetText(), '', 'forces: the text goes when the key ends')

	-- Focus mark: through the game's own plate of the focus.
	world.focusPlate = { unitFrame = plate }
	H.fire('PLAYER_FOCUS_CHANGED')
	H.check(plate.FocusMark:IsShown(), 'focus mark: the focus plate gets the mark')
	world.focusPlate = { unitFrame = normal }
	H.fire('PLAYER_FOCUS_CHANGED')
	H.check(not plate.FocusMark:IsShown() and normal.FocusMark:IsShown(), 'focus mark: it moves with the focus')
	world.focusPlate = nil
	H.fire('PLAYER_FOCUS_CHANGED')
	H.check(not normal.FocusMark:IsShown(), 'focus mark: no focus, no mark')
	world.focusPlate = { unitFrame = plate }
	world.added(plate, nil, 'nameplate1')
	H.check(plate.FocusMark:IsShown(), 'focus mark: a plate that shows up as the focus gets it')
	H.equal(table.concat(H.lastCall(Children(plate.FocusMark, 'Texture')[2], 'SetColorTexture'), ',', 1, 3),
		table.concat(H.ns.C.colors.focusMark, ','), 'focus mark: turquoise')

	-- Purge row: the game's dispellable buffs, an edge colored by the game from the type.
	local row
	for _, f in ipairs(Children(plate)) do
		for _, call in ipairs(H.calls(f, 'AddGroup')) do if call[1] == 'HELPFUL|DISPELLABLE' then row = f end end
	end
	H.check(row ~= nil, 'purge: the plate has a row of dispellable buffs')
	H.equal(H.lastCall(row, 'SetPoint')[1], 'BOTTOMRIGHT', 'purge: at the top right of the plate')
	local button = H.NewFrame('Frame', nil, row)
	button.Icon = button:CreateTexture()
	local textures = {}
	function button:AddDispelTypeTexture(texture, options) textures[#textures + 1] = { texture, options } end
	row.PostCreateButton(row, button)
	H.equal(#textures, 4, 'purge: four colored edges')
	local options = textures[1][2]
	local magic, enrage = H.ns.C.colors.purgeMagic, H.ns.C.colors.purgeEnrage
	H.check(options.showWhenHelpful and options.showWithoutDispelType, 'purge: the edges show on buffs, a hidden type too')
	H.check(options.customDispelColorMap.Magic.b == magic[3] and options.customDispelColorMap.Enrage.r == enrage[1],
		'purge: magic blue, enrage orange')
	H.check(options.customDispelColorCurve == world.curve, 'purge: the game colors the edge through a curve')
	local points = {}
	for _, call in ipairs(Called(world.curve, 'AddPoint')) do points[call[2]] = call[3] end
	H.check(points[1] and points[1].b == magic[3] and points[9] and points[9].r == enrage[1], 'purge: type 1 magic is blue, type 9 enrage orange')
end

do
	-- Target frame: the purge row above its right end, with tooltips.
	Boot()
	local target = Style('target')
	local row
	for _, f in ipairs(Children(target)) do
		for _, call in ipairs(H.calls(f, 'AddGroup')) do if call[1] == 'HELPFUL|DISPELLABLE' then row = f end end
	end
	H.check(row ~= nil and not row.disableMouse, 'purge: the target frame has the row, with tooltips')
	Boot(function(C) C.features.platePurge = false end)
	target = Style('target')
	row = nil
	for _, f in ipairs(Children(target)) do
		for _, call in ipairs(H.calls(f, 'AddGroup')) do if call[1] == 'HELPFUL|DISPELLABLE' then row = f end end
	end
	H.check(row ~= nil, 'purge: the target row has its own switch')
end

------------------------------------------------------------------------
-- 16: the GCD line, 17: the spender marks.
------------------------------------------------------------------------
do
	Boot()
	local player = Style('player')
	local line = player.GcdLine
	H.check(line ~= nil and not line:IsShown(), 'GCD: a line, hidden without a global cooldown')
	local duration = Recorder()
	world.cooldown[61304] = { isActive = true, duration = duration }
	H.fire('SPELL_UPDATE_COOLDOWN')
	H.check(line:IsShown() and H.lastCall(line, 'SetTimerDuration')[1] == duration, 'GCD: it runs on the GCD spell\'s duration object')
	world.cooldown[61304] = { isActive = false }
	H.fire('SPELL_UPDATE_COOLDOWN')
	H.check(not line:IsShown(), 'GCD: it hides when the global cooldown ends')

	-- Assassination: Envenom 35 energy out of 100 gives marks at 35 and 70.
	local ticks = player.SpenderTicks
	local shown = 0
	for _, t in ipairs(ticks) do if t:IsShown() then shown = shown + 1 end end
	H.equal(shown, 2, 'spender marks: two marks for 35 of 100 energy')
	H.check(math.abs(H.lastCall(ticks[1], 'SetPoint')[4] - 340 * 0.35) < 0.01, 'spender marks: the first at 35%')
	world.powerMax = 150
	H.fire('UNIT_MAXPOWER', 'player')
	shown = 0
	for _, t in ipairs(ticks) do if t:IsShown() then shown = shown + 1 end end
	H.equal(shown, 4, 'spender marks: a larger pool gets more marks')
	world.power = { 1, 'RAGE' }
	H.fire('UNIT_DISPLAYPOWER', 'player')
	shown = 0
	for _, t in ipairs(ticks) do if t:IsShown() then shown = shown + 1 end end
	H.equal(shown, 0, 'spender marks: another resource on the bar has no marks')
	world.power, world.powerMax = { 3, 'ENERGY' }, Secret('max')
	H.fire('UNIT_MAXPOWER', 'player')
	shown = 0
	for _, t in ipairs(ticks) do if t:IsShown() then shown = shown + 1 end end
	H.equal(shown, 0, 'spender marks: a hidden maximum gives no marks')
	world.powerMax, world.spec = 100, 65
	H.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
	shown = 0
	for _, t in ipairs(ticks) do if t:IsShown() then shown = shown + 1 end end
	H.equal(shown, 0, 'spender marks: a spec without an entry has none')
end

------------------------------------------------------------------------
-- 4: the interrupt strips.
------------------------------------------------------------------------
local function Party(members)
	world.party = #members
	for i, m in ipairs(members) do
		local unit = 'party' .. i
		world.classes[unit], world.roles[unit], world.guids[unit], world.exists[unit] = m[1], m[2], m[3], true
	end
end

local function Strip(unit, parent)
	local frame = Style(nil, parent or 'SlimARK_Party')
	frame.__unit = unit
	return frame, frame.KickStrip
end

local function Color(bar)
	local c = H.lastCall(bar, 'SetStatusBarColor')
	return c and table.concat(c, ',')
end

do
	Boot()
	local ready = table.concat(H.ns.C.colors.kickReady, ',')
	Party({ { 'ROGUE', 'DAMAGER', 'G1' }, { 'PRIEST', 'HEALER', 'G2' }, { 'MAGE', 'DAMAGER', 'G3' } })
	local rogueFrame, rogue = Strip('party1')
	local _, priest = Strip('party2')
	local _, mage = Strip('party3')
	H.runTimers(0)
	H.check(rogue:IsShown() and Color(rogue) == ready, 'kick strip: a ready interrupt is green')
	H.check(not priest:IsShown(), 'kick strip: a healer without an interrupt gets no strip')
	H.check(Listens('DAMAGE_METER_COMBAT_SESSION_UPDATED'), 'kick strip: the damage meter is watched')

	-- The rogue's first kick of the fight: their row appears.
	local INT = Enum.DamageMeterType.Interrupts
	H.fire('DAMAGE_METER_CURRENT_SESSION_UPDATED')
	world.meterRows = { { classFilename = 'ROGUE', specIconID = 'specicon259', isLocalPlayer = false } }
	H.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', INT, 1)
	H.equal(Color(rogue), '1,1,1', 'kick strip: a landed kick turns the strip white')
	local timer = H.lastCall(rogue, 'SetTimerDuration')
	local duration = timer and timer[1]
	H.check(duration and Called(duration, 'SetTimeFromStart')[1][3] == 15, 'kick strip: it fills for the rogue\'s 15 seconds')
	H.equal(timer[3], Enum.StatusBarTimerDirection.ElapsedTime, 'kick strip: it fills up')
	H.check(Color(mage) == ready, 'kick strip: the others stay green')
	H.runTimers(14)
	H.equal(Color(rogue), '1,1,1', 'kick strip: still filling before the cooldown ends')
	H.runTimers(1)
	H.equal(Color(rogue), ready, 'kick strip: green again when the cooldown ends')

	-- Another meter type changes nothing.
	world.meterRows = { world.meterRows[1], { classFilename = 'MAGE', specIconID = 'specicon62', isLocalPlayer = false } }
	H.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', Enum.DamageMeterType.DamageDone, 1)
	H.equal(Color(mage), ready, 'kick strip: other meter types are not read')
	-- The mage's row appears: the mage kicked, the arcane icon tells the spec (Counterspell 25 s).
	H.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', INT, 1)
	H.equal(Color(mage), '1,1,1', 'kick strip: the mage\'s first kick')
	H.equal(Called(H.lastCall(mage, 'SetTimerDuration')[1], 'SetTimeFromStart')[1][3], 25, 'kick strip: Counterspell fills for 25 seconds')
	H.runTimers(25)
	-- The rogue moves up past the mage: the rogue kicked again.
	world.meterRows = { world.meterRows[2], world.meterRows[1] }
	H.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', INT, 1)
	world.meterRows = { world.meterRows[2], world.meterRows[1] }
	H.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', INT, 1)
	H.equal(Color(rogue), '1,1,1', 'kick strip: a row that moves up names its member')
	H.runTimers(15)
	-- The mage kicks a new spell: their list of kicked spells grows.
	world.spells.G3 = 1
	H.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', INT, 1)
	H.equal(Color(mage), '1,1,1', 'kick strip: a longer list of kicked spells names its member')
	H.runTimers(25)
	-- Nothing visible changed: nobody is named.
	H.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', INT, 1)
	H.check(Color(mage) == ready and Color(rogue) == ready, 'kick strip: an update that shows no change names nobody')
	-- A hidden session is skipped without an error.
	world.meterSecret = true
	local ok = pcall(H.fire, 'DAMAGE_METER_COMBAT_SESSION_UPDATED', INT, 1)
	H.check(ok and Color(rogue) == ready, 'kick strip: a hidden meter session is left alone')
	world.meterSecret = nil

	-- The frame gets another member: its strip follows.
	rogueFrame.__unit = 'party2'
	rogueFrame:GetScript('OnShow')(rogueFrame)
	H.runTimers(0)
	H.check(not rogue:IsShown(), 'kick strip: a frame that now shows a healer hides its strip')
end

do
	-- Two rogues: a new rogue row names nobody until their spec icons tell them apart.
	Boot()
	Party({ { 'ROGUE', 'DAMAGER', 'G1' }, { 'ROGUE', 'DAMAGER', 'G2' } })
	local _, a = Strip('party1')
	local _, b = Strip('party2')
	H.runTimers(0)
	local ready = table.concat(H.ns.C.colors.kickReady, ',')
	world.meterRows = { { classFilename = 'ROGUE', specIconID = 'specicon259', isLocalPlayer = false } }
	H.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', Enum.DamageMeterType.Interrupts, 1)
	H.check(Color(a) == ready and Color(b) == ready, 'kick strip: a row two members could own names nobody')

	-- Your own kick: your own cast, on your own frame in the healer grid.
	Boot()
	Party({ { 'MAGE', 'DAMAGER', 'G3' } })
	local own = Style(nil, 'SlimARK_HealParty')
	own.__unit = 'player'
	H.runTimers(0)
	H.fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast', 1766)
	H.equal(Color(own.KickStrip), '1,1,1', 'kick strip: your own kick cast fills your strip')
	H.check(own.KickStrip:IsShown(), 'kick strip: the raid and grid frames have it too')
	H.fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast', Secret('spell'))
	H.check(true, 'kick strip: a hidden spell of your own is ignored without an error')
end

------------------------------------------------------------------------
-- 22: the buff reminder.
------------------------------------------------------------------------
do
	Boot(function() end)
	world.classes.player = 'WARRIOR'
	world.known[6673] = true
	H.fire('PLAYER_ENTERING_WORLD')
	H.runTimers(0.2)
	local frame = SlimARK_BuffReminder
	H.check(frame:IsShown(), 'buff reminder: in an instance the missing things show')
	local label
	for _, f in ipairs(Children(frame, 'FontString')) do if f:GetText() and f:GetText():find('Missing') then label = f:GetText() end end
	H.equal(label, 'Missing: Battle Shout, weapon oil', 'buff reminder: the class buff and the weapon oil')
	world.auras[6673] = {}
	world.enchant = { remainingTimeMs = 600000 }
	H.fire('UNIT_AURA', 'player')
	H.runTimers(0.2)
	H.check(not frame:IsShown(), 'buff reminder: nothing shows when all is there')
	world.auras[6673] = nil
	H.combat = true
	H.fire('PLAYER_REGEN_DISABLED')
	H.check(not frame:IsShown() and not Listens('UNIT_AURA'), 'buff reminder: in combat it hides and stops watching auras')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.runTimers(0.2)
	H.check(frame:IsShown() and Listens('UNIT_AURA'), 'buff reminder: after combat it looks again')
	world.aurasSecret = true
	H.fire('UNIT_AURA', 'player')
	H.runTimers(0.2)
	H.check(not frame:IsShown(), 'buff reminder: with hidden auras nothing is claimed missing')
	world.aurasSecret = false
	world.inInstance = false
	H.fire('ZONE_CHANGED_NEW_AREA')
	H.runTimers(0.2)
	H.check(not frame:IsShown(), 'buff reminder: not outside instances')
	-- A hunter's pet.
	world.inInstance, world.classes.player, world.spec = true, 'HUNTER', 253
	world.exists.pet = false
	H.fire('UNIT_PET', 'player')
	H.runTimers(0.2)
	H.check(frame:IsShown(), 'buff reminder: a beast master without a pet')
	world.exists.pet = true
	H.fire('UNIT_PET', 'player')
	H.runTimers(0.2)
	H.check(not frame:IsShown(), 'buff reminder: the pet is out')
end

-- An Outlaw or Subtlety rogue knows Instant Poison (a class spell) but not Deadly Poison (an
-- Assassination talent); a missing lethal poison is still reported.
do
	Boot(function() end)
	world.classes.player, world.spec = 'ROGUE', 260
	world.known[315584] = true
	world.enchant = { remainingTimeMs = 600000 }
	H.fire('PLAYER_ENTERING_WORLD')
	H.runTimers(0.2)
	local frame = SlimARK_BuffReminder
	local label
	for _, f in ipairs(Children(frame, 'FontString')) do if f:GetText() and f:GetText():find('Missing') then label = f:GetText() end end
	H.equal(label, 'Missing: poison', 'buff reminder: an Outlaw rogue without a lethal poison')
	world.auras[315584] = {}
	H.fire('UNIT_AURA', 'player')
	H.runTimers(0.2)
	H.check(not frame:IsShown(), 'buff reminder: Instant Poison on counts as a lethal poison')
end

------------------------------------------------------------------------
-- 24: the raid order, 58: the arena frames.
------------------------------------------------------------------------
do
	Boot()
	world.raid, world.me = true, 2
	world.roster = { { 'Dps', 'DAMAGER' }, { 'Me', 'DAMAGER' }, { 'Heal', 'HEALER' }, { 'Tank', 'TANK' }, { 'Who', nil } }
	H.fire('GROUP_ROSTER_UPDATE')
	H.fire('GROUP_ROSTER_UPDATE')
	H.runTimers(0)
	H.equal(SlimARK_Raid:GetAttribute('nameList'), 'Me,Tank,Heal,Dps,Who', 'raid order: you, tanks, healers, damage')
	H.equal(SlimARK_Raid:GetAttribute('sortMethod'), 'NAMELIST', 'raid order: sorted by the name list')
	H.equal(SlimARK_Raid:GetAttribute('groupFilter'), nil, 'raid order: without a group filter')
	-- In combat the header waits.
	H.combat = true
	table.insert(world.roster, 4, { 'Tank2', 'TANK' })
	H.fire('GROUP_ROSTER_UPDATE')
	H.runTimers(0)
	H.equal(SlimARK_Raid:GetAttribute('nameList'), 'Me,Tank,Heal,Dps,Who', 'raid order: nothing changes in combat')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(SlimARK_Raid:GetAttribute('nameList'), 'Me,Tank2,Tank,Heal,Dps,Who', 'raid order: written when combat ends')
	world.roster[1] = { Secret('name'), 'DAMAGER' }
	H.fire('GROUP_ROSTER_UPDATE')
	H.runTimers(0)
	H.equal(SlimARK_Raid:GetAttribute('nameList'), 'Me,Tank2,Tank,Heal,Dps,Who', 'raid order: a hidden name leaves the list alone')
	H.check(SlimARK_HealRaid:GetAttribute('nameList') == nil, 'raid order: the healer grid keeps its own order')

	-- Arena frames in the boss frames' place.
	H.check(SlimARK_Arena1 ~= nil and SlimARK_Arena5 ~= nil, 'arena: five arena frames')
	local boss, arena
	for _, item in ipairs(H.ns.Placed) do
		if item.key == 'boss' then boss = item end
		if item.frame == SlimARK_Arena1 then arena = item end
	end
	H.check(arena and arena.owner == boss, 'arena: they move with the boss frames in Edit Mode')
	local frame = Style('arena1')
	local tagged
	for _, call in ipairs(H.calls(frame, 'Tag')) do if call[2] == '[name][slim:arenaspec]' then tagged = true end end
	H.check(tagged, 'arena: the boss look with the spec after the name')
	H.check(frame.Castbar ~= nil, 'arena: with the cast bar of the boss frames')
	world.arenaSpecs = { 64 }
	world.exists.arena1 = true
	H.equal(oUF.Tags.Methods['slim:arenaspec']('arena1'), ' · Frost', 'arena: "Name · Frost"')
	world.exists.arena1 = false
	H.equal(oUF.Tags.Methods['slim:arenaspec']('arena1'), 'Frost', 'arena: before the gates open only the spec')
	world.arenaSpecs = { Secret('spec') }
	H.equal(oUF.Tags.Methods['slim:arenaspec']('arena1'), nil, 'arena: a hidden spec shows nothing')
end

------------------------------------------------------------------------
-- Test mode: the new parts show made-up data and go away with it.
------------------------------------------------------------------------
do
	local ns = Boot()
	ns.SpecInfo = function() return 259, 'DAMAGER' end
	local player = Style('player')
	H.load('TestMode.lua')
	SlimARK_Party = SlimARK_Party or H.NewFrame('Frame', 'SlimARK_Party', UIParent)
	ns.SetTestMode('party')
	local rows = Rows()
	H.check(rows[1]:IsShown() and rows[3]:IsShown() and not rows[4]:IsShown(), 'test mode: three made-up casts in the column')
	H.equal(rows[2].You:GetAlpha(), 1, 'test mode: one of them is aimed at you')
	local layer = Children(player.YouMark)[1]
	H.check(layer and layer:GetAlpha() == 1, 'test mode: the YOU mark shows')
	H.check(player.GcdLine:IsShown() and H.lastCall(player.GcdLine, 'SetValue')[1] == 0.42, 'test mode: the GCD line half run down')
	H.check(SlimARK_BuffReminder:IsShown(), 'test mode: the buff reminder shows')
	local strips, filling = 0, 0
	for _, f in ipairs(H.frames) do
		if f.ui and f.ui.kick and f:IsShown() and f.ui.kick:IsShown() then
			strips = strips + 1
			if f.ui.kick.time:GetText() == '9' then filling = filling + 1 end
		end
	end
	H.check(strips > 0 and filling > 0, 'test mode: interrupt strips on the made-up party, one filling')
	local plate
	for _, f in ipairs(H.frames) do
		if f.forces and f.focus and f.purge then plate = f end
	end
	H.check(plate and plate:IsShown() and plate.forces:GetText() == '3.12%', 'test mode: a made-up plate with the forces %')
	H.check(plate.focus:IsShown() and plate.mark:IsShown() and plate.purge[2]:IsShown(), 'test mode: with the focus mark, the elite mark and the purge row')
	ns.SetTestMode('off')
	H.check(not rows[1]:IsShown() and layer:GetAlpha() == 0 and not plate:IsShown(), 'test mode off: the made-up parts go away')
	H.check(not player.GcdLine:IsShown(), 'test mode off: the GCD line follows the real cooldown again')
end

H.done()
