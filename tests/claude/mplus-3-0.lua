-- 3.0 Mythic+ parts: the panel rows (current pull 2, battle res and Bloodlust 5, splits 7, time in
-- combat 15), the raid battle res row (5), the teleport under the join text (3), the run summary
-- with its loot (6, 9) and the keystone tooltip with the season table and party keys (8, 10).
-- Run from the repository root:  lua5.1 tests/claude/mplus-3-0.lua
local H = dofile('tests/codex/lib/runtime.lua')
local world

-- Hidden values are plain tables here: any comparison or sum with one raises, so a test passes
-- only when the code hands them to widgets untouched.
local function Hidden()
	local v = {}
	H.secret = H.secret or {}
	H.secret[v] = true
	return v
end

local function FindFrame(test)
	for _, f in ipairs(H.frames) do
		if test(f) then return f end
	end
end

local function TextOf(text)
	return FindFrame(function(f) return f._text == text end)
end

local function Ticker(interval)
	for i = #H.tickers, 1, -1 do
		local t = H.tickers[i]
		if t.interval == interval and not t.cancelled then return t end
	end
end

------------------------------------------------------------------------
-- The Mythic+ panel.
------------------------------------------------------------------------
local function BootPanel(features)
	local ns = H.boot()
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	world = {
		active = false, elapsed = 0, kind = 'party', plates = {}, combat = {},
		criteria = {
			{ description = 'Overseer Kaal', completed = false },
			{ description = 'Thrall of the Void', completed = false },
			{ isWeightedProgress = true, totalQuantity = 460, quantityString = '292', quantity = 63, completed = false },
		},
	}
	C_ChallengeMode = {
		IsChallengeModeActive = function() return world.active end,
		GetActiveChallengeMapID = function() return 585 end,
		GetActiveKeystoneInfo = function() return 12 end,
		GetMapUIInfo = function() return 'Voidscar Arena', 585, 1980 end,
		GetDeathCount = function() return 0 end,
		GetChallengeCompletionInfo = function() return world.completion end,
	}
	C_ScenarioInfo = {
		GetScenarioStepInfo = function() return { numCriteria = #world.criteria } end,
		GetCriteriaInfo = function(i) return world.criteria[i] end,
		GetUnitCriteriaProgressValues = function(unit) return world.plates[unit] and world.plates[unit].value end,
	}
	GetWorldElapsedTimers = function() return 1 end
	GetWorldElapsedTime = function() return 'Challenge', world.elapsed, Enum.WorldElapsedTimerTypes.ChallengeMode end
	C_Spell = { GetSpellCharges = function(id) return id == 20484 and world.charges or nil end }
	C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return world.sated and world.sated.id == id and world.sated or nil end }
	UnitAffectingCombat = function(unit)
		if world.plates[unit] then return world.plates[unit].combat end
		return world.combat[unit]
	end
	UnitExists = function(unit) return world.plates[unit] ~= nil end
	UnitCanAttack = function(_, unit) return world.plates[unit] ~= nil end
	UnitIsDead = function() return false end
	GetInstanceInfo = function() return 'Somewhere', world.kind end
	IsEncounterInProgress = function() return world.encounter == true end
	ObjectiveTrackerFrame = H.NewFrame('Frame')
	SlimARK_MythicPlus, SlimARK_RaidBrez = nil, nil
	ns.Register = function() end
	H.load('MythicPlus.lua')
	H.fire('PLAYER_LOGIN')
	return ns
end

local function StartKey()
	world.active = true
	H.fire('CHALLENGE_MODE_START')
	H.runTimers(0.5)
	return SlimARK_MythicPlus
end

local function Tick(seconds)
	H.now = H.now + (seconds or 1)
	Ticker(0.25).fn()
end

do
	-- Every 3.0 part off: the panel is the 2.3.0 one, nothing new is made or registered.
	local ns = BootPanel({ mplusCombat = false, mplusBrLust = false, mplusPull = false, mplusSplits = false, raidBrLust = false })
	local panel = StartKey()
	H.check(panel.Combat == nil and panel.Brez == nil, 'panel off: no combat line and no battle res row')
	local forces = FindFrame(function(f)
		local p = f._kind == 'StatusBar' and H.calls(f, 'SetPoint')[1]
		return p and p[1] == 'TOPLEFT' and p[3] == -102
	end)
	H.check(forces ~= nil, 'panel off: the forces bar keeps its 2.3.0 place')
	world.combat.player = true
	world.plates.nameplate1 = { value = 18, combat = true }
	Tick(1)
	H.check(not FindFrame(function(f) return f._kind == 'StatusBar' and H.lastCall(f, 'SetValue') and H.lastCall(f, 'SetValue')[1] == 18 end),
		'panel off: no pull segment')
	world.kind = 'raid'
	H.fire('ENCOUNTER_START')
	H.check(SlimARK_RaidBrez == nil, 'raid row off: nothing is made in a raid fight')
	H.fire('PLAYER_REGEN_DISABLED')
	H.now = H.now + 5
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(ns.KeyCombatTime(), 5, 'panel off: the combat clock still runs for the run summary (on by default)')
	H.noErrors()
end

do
	-- Without the panel line and the run summary the combat clock registers nothing.
	local ns = BootPanel({ mplusCombat = false, runSummary = false })
	StartKey()
	H.fire('PLAYER_REGEN_DISABLED')
	H.now = H.now + 5
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(ns.KeyCombatTime(), 0, 'combat clock off: nothing measured')
	H.check(ns.CharDB.keyCombat == nil, 'combat clock off: nothing saved')
	H.noErrors()
end

do
	-- Time in combat (15): measured between the combat events while the key runs.
	local ns = BootPanel()
	local panel = StartKey()
	H.fire('PLAYER_REGEN_DISABLED')
	H.now = H.now + 60
	H.fire('PLAYER_REGEN_ENABLED')
	world.elapsed = 120
	Tick(1)
	local call = H.lastCall(panel.Combat, 'SetFormattedText')
	H.check(call and call[2] == '1:00' and call[3] == 50, 'combat: "In combat 1:00 · 50%" from the panel clock')
	H.equal(ns.CharDB.keyCombat.total, 60, 'combat: kept in the saved data for a reload')
	H.fire('PLAYER_REGEN_DISABLED')
	H.now = H.now + 30
	H.equal(ns.KeyCombatTime(), 90, 'combat: a running fight counts live')
	H.fire('CHALLENGE_MODE_COMPLETED')
	H.now = H.now + 100
	H.equal(ns.KeyCombatTime(), 90, 'combat: the end of the key stops the clock')
	H.check(ns.CharDB.keyCombat.done, 'combat: the finished run is marked')
	H.equal(#H.tickers, 1, 'combat: no timer of its own (only the panel clock)')
	H.noErrors()
end

do
	-- A reload in the run goes on from the saved time.
	local ns = BootPanel()
	ns.CharDB.keyCombat = { total = 300 }
	world.active = true
	H.fire('PLAYER_ENTERING_WORLD')
	H.equal(ns.KeyCombatTime(), 300, 'combat: a reload in the key keeps the time measured before it')
	H.noErrors()
end

do
	-- Battle res and Bloodlust (5), readable values.
	BootPanel()
	local panel = StartKey()
	world.charges = { currentCharges = 1, maxCharges = 5, cooldownStartTime = H.now, cooldownDuration = 600, isActive = true }
	world.sated = { id = 57724, expirationTime = H.now + 301 }
	Tick(1)
	H.equal(panel.Brez.count:GetText(), 1, 'brez: the charges')
	H.equal(panel.Brez.next:GetText(), ' · next 9:59', 'brez: the time to the next charge')
	H.equal(panel.Brez.lust:GetText(), 'Sated |cffff8a7a5:00|r', 'lust: Sated with the time left')
	world.sated = nil
	Tick(1)
	H.equal(panel.Brez.lust:GetText(), 'Lust |cff7ddc8aready|r', 'lust: ready without the debuff')
	H.noErrors()
end

do
	-- Hidden charges and a hidden Sated end: the count goes to the text untouched, the end is
	-- counted from the first sight of the debuff.
	local ns = BootPanel()
	local panel = StartKey()
	local count = Hidden()
	world.charges = { currentCharges = count, maxCharges = 5, cooldownStartTime = Hidden(), cooldownDuration = Hidden(), isActive = true }
	world.sated = { id = 80354, expirationTime = Hidden() }
	local ok = pcall(Tick, 1)
	H.check(ok, 'brez: hidden values raise nothing')
	H.check(panel.Brez.count:GetText() == count, 'brez: the hidden count is handed to the text as it is')
	H.equal(panel.Brez.next:GetText(), '', 'brez: no next time from hidden values')
	H.equal(panel.Brez.lust:GetText(), 'Sated |cffff8a7a10:00|r', 'lust: a hidden end counts ten minutes from the first sight')
	Tick(10)
	H.equal(panel.Brez.lust:GetText(), 'Sated |cffff8a7a9:50|r', 'lust: and counts down')
	H.check(ns.CharDB.satedUntil ~= nil, 'lust: the counted end is kept for a reload')
	H.secret = nil
	H.noErrors()
end

do
	-- The current pull (2): readable values add up to "+x%".
	BootPanel()
	StartKey()
	world.combat.player = true
	world.plates.nameplate1 = { value = 18, combat = true }
	world.plates.nameplate2 = { value = 14, combat = true }
	world.plates.nameplate3 = { value = 40, combat = false } -- not pulled
	Tick(1)
	local segs = {}
	for _, f in ipairs(H.frames) do
		local v = f._kind == 'StatusBar' and f:IsShown() and H.lastCall(f, 'SetValue')
		if v and (v[1] == 18 or v[1] == 14 or v[1] == 40) then segs[#segs + 1] = v[1] end
	end
	H.equal(#segs, 2, 'pull: a segment per enemy in combat')
	local text = FindFrame(function(f) local c = H.lastCall(f, 'SetFormattedText') return c and c[1] == '+%.2f%%' end)
	H.check(text and text:IsShown() and math.abs(H.lastCall(text, 'SetFormattedText')[2] - 32 / 460 * 100) < 0.001,
		'pull: "+x%" is the readable sum')
	world.combat.player = false
	world.plates.nameplate1.combat, world.plates.nameplate2.combat = false, false
	Tick(1)
	H.check(not text:IsShown(), 'pull: gone when the fight ends')
	H.noErrors()
end

do
	-- Hidden pull values: straight into the bars, no sum and no text.
	BootPanel()
	StartKey()
	world.combat.player = true
	local a, b = Hidden(), Hidden()
	world.plates.nameplate1 = { value = a, combat = true }
	world.plates.nameplate2 = { value = b, combat = true }
	local ok = pcall(Tick, 1)
	H.check(ok, 'pull: hidden values raise nothing')
	local got = 0
	for _, f in ipairs(H.frames) do
		local v = f._kind == 'StatusBar' and H.lastCall(f, 'SetValue')
		if v and (v[1] == a or v[1] == b) then got = got + 1 end
	end
	H.equal(got, 2, 'pull: each hidden value goes to its own bar')
	local text = FindFrame(function(f) local c = H.lastCall(f, 'SetFormattedText') return c and c[1] == '+%.2f%%' end)
	H.check(not text or not text:IsShown(), 'pull: no "+x%" from hidden values')
	H.secret = nil
	H.noErrors()
end

do
	-- Personal best splits (7).
	local ns = BootPanel()
	ns.CharDB.mplusBest = { [585] = { [12] = { time = 1800, splits = { [1] = 313, [2] = 627 } } } }
	StartKey()
	H.check(TextOf('best 5:13') ~= nil, 'splits: a living boss shows its best time')
	world.elapsed = 291
	world.criteria[1].completed = true
	H.fire('SCENARIO_CRITERIA_UPDATE')
	local ahead = TextOf('-0:22')
	H.check(ahead and H.lastCall(ahead, 'SetTextColor')[2] > 0.8, 'splits: ahead of the best in green')
	world.elapsed = 668
	world.criteria[2].completed = true
	H.fire('SCENARIO_CRITERIA_UPDATE')
	local behind = TextOf('+0:41')
	H.check(behind and H.lastCall(behind, 'SetTextColor')[1] == 1 and H.lastCall(behind, 'SetTextColor')[2] < 0.6,
		'splits: behind the best in red')
	world.completion = { mapChallengeModeID = 585, level = 12, time = 1700000, onTime = true }
	H.fire('CHALLENGE_MODE_COMPLETED')
	local saved = ns.CharDB.mplusBest[585][12]
	H.check(saved.time == 1700 and saved.splits[1] == 291 and saved.splits[2] == 668, 'splits: a faster run becomes the best')
	H.noErrors()
end

do
	-- A boss killed before a reload has no time: that run is never a best.
	local ns = BootPanel()
	world.criteria[1].completed = true
	StartKey()
	world.elapsed = 600
	world.criteria[2].completed = true
	H.fire('SCENARIO_CRITERIA_UPDATE')
	world.completion = { mapChallengeModeID = 585, level = 12, time = 900000, onTime = true }
	H.fire('CHALLENGE_MODE_COMPLETED')
	H.check(not (ns.CharDB.mplusBest and ns.CharDB.mplusBest[585]), 'splits: a run with a missing boss time is not kept')
	H.noErrors()
end

do
	-- The test mode shows the new rows.
	local ns = BootPanel()
	ns.MythicPlusPreview(true)
	local panel = SlimARK_MythicPlus
	H.equal(panel.Brez.next:GetText(), ' · next 3:12', 'preview: the battle res row')
	H.check(TextOf('-0:22') and TextOf('+0:41') and TextOf('best 19:45'), 'preview: the splits')
	H.check(H.lastCall(panel.Combat, 'SetFormattedText') ~= nil, 'preview: the combat line')
	ns.MythicPlusPreview(false)
	H.noErrors()
end

do
	-- The raid row (5): only in a raid boss fight, its clock only while it shows.
	BootPanel()
	H.fire('ENCOUNTER_START')
	H.check(SlimARK_RaidBrez == nil, 'raid row: not in a dungeon boss fight')
	world.kind = 'raid'
	world.charges = { currentCharges = 2, maxCharges = 2, cooldownStartTime = 0, cooldownDuration = 0, isActive = false }
	H.fire('ENCOUNTER_START')
	local block = SlimARK_RaidBrez
	H.check(block and block:IsShown(), 'raid row: shown in a raid boss fight')
	H.equal(block.row.count:GetText(), 2, 'raid row: the shared charges')
	local clock = Ticker(1)
	H.check(clock ~= nil, 'raid row: a one second clock while it shows')
	H.fire('ENCOUNTER_END')
	H.check(not block:IsShown() and clock.cancelled, 'raid row: hidden and the clock stopped after the fight')
	H.noErrors()
end

do
	-- WoW Forever: none of it.
	local ns = H.boot('forever')
	C_ChallengeMode = { IsChallengeModeActive = function() return false end }
	ns.Register = function() end
	SlimARK_MythicPlus, SlimARK_RaidBrez = nil, nil
	H.load('MythicPlus.lua')
	H.fire('PLAYER_LOGIN')
	GetInstanceInfo = function() return 'Raid', 'raid' end
	H.fire('ENCOUNTER_START')
	H.check(SlimARK_MythicPlus == nil and SlimARK_RaidBrez == nil, 'forever: no panel and no raid row')
	ns.RaidBrezPreview(true)
	H.check(SlimARK_RaidBrez == nil, 'forever: no raid row in the test mode either')
	H.noErrors()
end

------------------------------------------------------------------------
-- The teleport under the join text (3).
------------------------------------------------------------------------
local function BootJoin(features)
	local ns = H.boot()
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	world = { known = { [1286804] = true }, instance = false }
	SlimARK_Joined, SlimARK_JoinedTeleport = nil, nil
	C_SpecializationInfo = { GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return 70, nil, nil, nil, 'DAMAGER' end }
	C_Map = { GetBestMapForUnit = function() return 1 end }
	GetLFGRoles = function() return false end
	SetLFGRoles = function() end
	IsInInstance = function() return world.instance end
	C_SpellBook = { IsSpellKnown = function(id) return world.known[id] == true end }
	C_ChallengeMode = {
		GetMapUIInfo = function(id)
			if id == 585 then return 'Voidscar Arena', 585, 1980, nil, nil, 2900 end
			return 'Other', id, 1800, nil, nil, 100000 + id
		end,
	}
	C_LFGList = {
		GetSearchResultInfo = function() return { activityIDs = { 77 } } end,
		GetActivityFullName = function() return 'Voidscar Arena (Mythic Keystone)' end,
		GetActivityInfoTable = function() return { mapID = world.mapID or 2900 } end,
	}
	H.load('Role.lua')
	H.load('Teleports.lua')
	H.load('Quality.lua')
	return ns
end

do
	BootJoin()
	H.fire('LFG_LIST_JOINED_GROUP', 7, '+12 timed')
	local button = SlimARK_JoinedTeleport
	H.check(button and button:IsShown(), 'teleport: a button under the join text')
	H.equal(button:GetAttribute('type'), 'spell', 'teleport: a secure spell button')
	H.equal(button:GetAttribute('spell'), 1286804, 'teleport: the dungeon\'s teleport from the teleport table')
	H.equal(button.text:GetText(), 'Teleport to Voidscar Arena', 'teleport: the dungeon\'s name on it')
	H.runTimers(7)
	H.check(SlimARK_Joined:IsShown() and button:IsShown(), 'teleport: the text stays longer with the button')
	H.fire('PLAYER_REGEN_DISABLED')
	H.check(not button:IsShown(), 'teleport: combat takes the button away before the lockdown')
	H.runTimers(30)
	H.check(not SlimARK_Joined:IsShown(), 'teleport: the text goes later')
	H.noErrors()
end

do
	BootJoin()
	H.fire('LFG_LIST_JOINED_GROUP', 7, '+12 timed')
	local button = SlimARK_JoinedTeleport
	H.combat = true
	H.fire('LFG_LIST_JOINED_GROUP', 8, '+12 again')
	H.check(button:IsShown() and button:GetAttribute('spell') == 1286804, 'teleport: nothing is changed on the button in combat')
	H.combat = false
	world.instance = true
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(not button:IsShown(), 'teleport: entering the dungeon takes it away')
	H.noErrors()
end

do
	BootJoin()
	H.combat = true
	H.fire('LFG_LIST_JOINED_GROUP', 7, '+12 timed')
	H.check(SlimARK_JoinedTeleport == nil, 'teleport: a join in combat makes no secure button')
	H.combat = false
	world.known = {}
	H.fire('LFG_LIST_JOINED_GROUP', 7, '+12 timed')
	H.check(SlimARK_JoinedTeleport == nil, 'teleport: no button without a learned teleport')
	H.runTimers(7)
	H.check(not SlimARK_Joined:IsShown(), 'teleport: the text keeps its 6 seconds then')
	H.noErrors()
end

do
	BootJoin()
	world.mapID = Hidden()
	local ok = pcall(H.fire, 'LFG_LIST_JOINED_GROUP', 7, '+12 timed')
	H.check(ok and SlimARK_JoinedTeleport == nil, 'teleport: a hidden map ID is left alone')
	H.secret = nil
	H.noErrors()
end

do
	BootJoin({ joinTeleport = false })
	H.fire('LFG_LIST_JOINED_GROUP', 7, '+12 timed')
	H.check(SlimARK_Joined:IsShown() and SlimARK_JoinedTeleport == nil, 'teleport off: the text without a button')
	H.noErrors()
end

------------------------------------------------------------------------
-- The run summary and its loot (6, 9).
------------------------------------------------------------------------
local function BootSummary(features, flavor)
	local ns = H.boot(flavor)
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	ns.C.modules.mythicplus = false
	world = { meter = {}, active = false, instance = true, worn = {} }
	SlimARK_RunSummary = nil
	UISpecialFrames = {}
	C_ChallengeMode = {
		IsChallengeModeActive = function() return world.active end,
		GetChallengeCompletionInfo = function() return world.completion end,
		GetMapUIInfo = function() return 'Voidscar Arena', 585, 1980 end,
		GetDeathCount = function() return 3, 15 end,
	}
	C_DamageMeter = { GetCombatSessionFromType = function(_, kind) return { combatSources = world.meter[kind] or {} } end }
	UnitGUID = function(unit) return ({ player = 'G1', party1 = 'G2' })[unit] end
	UnitClass = function() return 'Paladin', 'PALADIN' end
	GetPlayerInfoByGUID = function(guid) return 'x', ({ G1 = 'PALADIN', G2 = 'WARRIOR' })[guid] end
	Ambiguate = function(name) return (name:gsub('%-.*$', '')) end
	GetServerTime = function() return 1800000000 end
	date = function() return '2026-11-13 21:40' end
	IsInInstance = function() return world.instance end
	RAID_CLASS_COLORS = { PALADIN = { r = 0.96, g = 0.55, b = 0.73 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
	INVTYPE_LEGS, INVTYPE_WAIST = 'Legs', 'Waist'
	C_Item = {
		GetItemInfoInstant = function(link)
			if link:find('Greaves') then return 1, 'Armor', 'Plate', 'INVTYPE_LEGS', 0, Enum.ItemClass.Armor, Enum.ItemArmorSubclass.Plate end
			return 2, 'Armor', 'Cloth', 'INVTYPE_WAIST', 0, Enum.ItemClass.Armor, Enum.ItemArmorSubclass.Cloth
		end,
		GetDetailedItemLevelInfo = function(link) return link == 'worn-legs' and 675 or 684 end,
	}
	GetInventoryItemLink = function(_, slot) return slot == 7 and 'worn-legs' or nil end
	H.load('MythicPlus.lua')
	H.load('RunSummary.lua')
	H.fire('PLAYER_LOGIN')
	return ns
end

local function Meter(damage, healing, kicks, deaths)
	local t = Enum.DamageMeterType
	world.meter = {
		[t.DamageDone] = damage, [t.HealingDone] = healing, [t.Interrupts] = kicks, [t.Deaths] = deaths,
	}
end

local COMPLETION = { mapChallengeModeID = 585, level = 12, time = 120000, onTime = true, keystoneUpgradeLevels = 1,
	oldOverallDungeonScore = 3106, newOverallDungeonScore = 3120,
	members = { { memberGUID = 'G1', name = 'Aril' }, { memberGUID = 'G2', name = 'Brakk-OtherRealm' } } }

local function PlayKey(finalMeter)
	world.active = true
	Meter({ { sourceGUID = 'G1', totalAmount = 1000 } }, {}, {}, { { sourceGUID = 'G2', deathRecapID = 4 } })
	H.fire('CHALLENGE_MODE_START')
	H.fire('PLAYER_REGEN_DISABLED')
	H.now = H.now + 60
	H.fire('PLAYER_REGEN_ENABLED')
	finalMeter()
	world.completion = COMPLETION
	H.combat = true
	H.fire('PLAYER_REGEN_DISABLED')
	H.fire('CHALLENGE_MODE_COMPLETED')
end

do
	local ns = BootSummary()
	PlayKey(function()
		Meter({ { sourceGUID = 'G1', totalAmount = 412301000 }, { sourceGUID = 'G2', totalAmount = 298000000 } },
			{ { sourceGUID = 'G1', totalAmount = 18200000 } },
			{ { sourceGUID = 'G1', totalAmount = 14 }, { sourceGUID = 'G2', totalAmount = 11 } },
			{ { sourceGUID = 'G2', deathRecapID = 4 }, { sourceGUID = 'G2', deathRecapID = 9 }, { sourceGUID = 'G1', deathRecapID = 2 } })
	end)
	H.check(SlimARK_RunSummary == nil, 'summary: nothing while the fight goes on')
	H.equal(#ns.CharDB.runs, 1, 'summary: the run is saved at once')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.runTimers(1)
	local w = SlimARK_RunSummary
	H.check(w and w:IsShown(), 'summary: the window opens after the combat')
	H.equal(w.title:GetText(), 'Voidscar Arena +12', 'summary: dungeon and level')
	H.equal(w.sub:GetText(), 'timed +1 · run summary', 'summary: timed and the upgrade')
	H.equal(w.stats[1].value:GetText(), '2:00', 'summary: time')
	H.equal(w.stats[2].value:GetText(), '33:00', 'summary: limit')
	H.equal(w.stats[3].value:GetText(), '1:00 · 50%', 'summary: time in combat and its share, from the panel clock')
	H.equal(w.stats[4].value:GetText(), '3', 'summary: deaths')
	H.equal(w.stats[5].value:GetText(), '+14', 'summary: score change')
	local aril, brakk = w.members[1], w.members[2]
	H.equal(aril.name:GetText(), 'Aril', 'summary: the members')
	H.equal(aril.cols[1]:GetText(), '412.30M', 'summary: damage of the run (the start of the key taken away)')
	H.equal(aril.cols[2]:GetText(), '18.20M', 'summary: healing')
	H.equal(aril.cols[3]:GetText(), '14', 'summary: kicks')
	H.equal(brakk.name:GetText(), 'Brakk', 'summary: names without the realm')
	H.equal(brakk.cols[4]:GetText(), '1', 'summary: deaths in the run, not before it')
	H.equal(aril.cols[4]:GetText(), '1', 'summary: deaths of the other member')

	-- Loot after the end, until leaving the dungeon.
	H.fire('ENCOUNTER_LOOT_RECEIVED', 1, 1, '|cffa335ee|Hitem:1::|h[Voidscarred Greaves]|h|r', 1, 'Brakk-OtherRealm', 'WARRIOR')
	H.fire('ENCOUNTER_LOOT_RECEIVED', 1, 2, '|cffa335ee|Hitem:2::|h[Ritualist\'s Cord]|h|r', 1, 'Aril', 'PALADIN')
	local loot = ns.CharDB.runs[1].loot
	H.check(#loot == 2 and loot[1].gain == 9 and loot[1].who == 'Brakk', 'loot: an upgrade for you is marked with its gain')
	H.check(loot[2].gain == nil and loot[2].note == 'cloth', 'loot: not your armor type: no mark, its type in grey')
	H.check(TextOf('upgrade for you (+9)') and TextOf('|cffa335eeVoidscarred Greaves|r'), 'loot: shown in the open window')
	world.instance = false
	H.fire('PLAYER_ENTERING_WORLD')
	H.fire('ENCOUNTER_LOOT_RECEIVED', 1, 3, '|cffa335ee|Hitem:3::|h[Later]|h|r', 1, 'Aril', 'PALADIN')
	H.equal(#ns.CharDB.runs[1].loot, 2, 'loot: nothing after leaving the dungeon')
	H.noErrors()
end

do
	-- Hidden meter values: a few tries, then the window with what could be read.
	local ns = BootSummary()
	PlayKey(function()
		Meter({ { sourceGUID = 'G1', totalAmount = Hidden() } }, { { sourceGUID = 'G1', totalAmount = 500 } }, {}, {})
	end)
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	local ok = pcall(H.runTimers, 1)
	H.check(ok and SlimARK_RunSummary == nil, 'summary: a hidden total is not read, it is tried again')
	for _ = 1, 4 do H.runTimers(2) end
	local w = SlimARK_RunSummary
	H.check(w and w:IsShown(), 'summary: after the tries the window opens')
	H.equal(w.members[1].cols[1]:GetText(), '-', 'summary: the unread damage is a dash')
	H.equal(w.members[1].cols[2]:GetText(), '500', 'summary: the readable healing is there')
	H.secret = nil
	H.noErrors()
end

do
	-- History: 20 runs kept, paged back with the buttons.
	local ns = BootSummary()
	for i = 1, 23 do
		world.completion = COMPLETION
		H.fire('CHALLENGE_MODE_START')
		H.fire('CHALLENGE_MODE_COMPLETED')
	end
	H.equal(#ns.CharDB.runs, 20, 'history: the last 20 runs are kept')
	H.runTimers(1)
	local w = SlimARK_RunSummary
	w.older:GetScript('OnClick')(w.older)
	H.equal(w.counter:GetText(), 'Run 2 of 20 · 2026-11-13 21:40', 'history: the older button pages back')
	H.noErrors()
end

do
	local ns = BootSummary()
	ns.ShowRunHistory()
	H.check(SlimARK_RunSummary == nil and H.prints[#H.prints]:find('No Mythic+ run saved yet', 1, true),
		'history: without a saved run the settings button says so')
	ns.RunSummaryPreview(true)
	H.check(SlimARK_RunSummary:IsShown() and SlimARK_RunSummary.title:GetText() == 'Voidscar Arena +12', 'preview: the test mode shows a made-up run')
	ns.RunSummaryPreview(false)
	H.check(not SlimARK_RunSummary:IsShown() and #ns.CharDB.runs == 0, 'preview: gone with the test mode, never saved')
	H.noErrors()
end

do
	local ns = BootSummary({ runSummary = false, runLoot = false })
	PlayKey(function() end)
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.runTimers(10)
	H.check(SlimARK_RunSummary == nil and ns.CharDB.runs == nil, 'summary off: no window, nothing saved')
	H.noErrors()
end

do
	local ns = BootSummary(nil, 'forever')
	PlayKey(function() end)
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.runTimers(10)
	H.check(SlimARK_RunSummary == nil and ns.CharDB.runs == nil, 'summary: off in WoW Forever')
	H.noErrors()
end

------------------------------------------------------------------------
-- The keystone tooltip: season table (8) and party keys (10).
------------------------------------------------------------------------
local function BootKeys(features)
	local ns = H.boot()
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	world = { sent = {}, prefixes = {}, result = 0, locked = false, active = false, tips = {}, group = true }
	NUM_BAG_SLOTS = 0
	C_Container = { GetContainerNumSlots = function() return 0 end }
	C_ChallengeMode = {
		IsChallengeModeActive = function() return world.active end,
		GetMapTable = function() return { 503, 585, 560 } end,
		GetMapUIInfo = function(id) return ({ [503] = 'Ara-Kara, City of Echoes', [585] = 'Voidscar Arena', [560] = 'Maisara Caverns' })[id] end,
		GetAffixInfo = function(id) return ({ [10] = 'Fortified', [160] = 'Xal\'atath\'s Guile' })[id] end,
	}
	C_MythicPlus = {
		GetOwnedKeystoneChallengeMapID = function() return 585 end,
		GetOwnedKeystoneLevel = function() return 12 end,
		GetSeasonBestForMap = function(id)
			if id == 585 then return { level = 14 } end
			if id == 503 then return nil, { level = 13 } end
		end,
		GetSeasonBestAffixScoreInfoForMap = function(id) return {}, ({ [585] = 412, [503] = 398 })[id] or 0 end,
		GetCurrentAffixes = function() return { { id = 10 }, { id = 160 } } end,
	}
	C_PlayerInfo = { GetPlayerMythicPlusRatingSummary = function() return { currentSeasonScore = 3120.4 } end }
	C_ChatInfo = {
		InChatMessagingLockdown = function() return world.locked end,
		RegisterAddonMessagePrefix = function(prefix) world.prefixes[#world.prefixes + 1] = prefix return 0 end,
		SendAddonMessage = function(prefix, message, channel)
			world.sent[#world.sent + 1] = { prefix, message, channel }
			return world.result
		end,
	}
	IsInGroup = function() return world.group end
	IsInRaid = function() return false end
	IsEncounterInProgress = function() return world.encounter == true end
	UnitName = function(unit) return ({ player = 'Aril', party1 = 'Brakk', party2 = 'Lumi' })[unit] end
	GetUnitName = function(unit) return ({ party1 = 'Brakk-OtherRealm', party2 = 'Lumi' })[unit] end
	UnitExists = function(unit) return unit == 'party1' or unit == 'party2' end
	UnitClass = function(unit) return 'x', ({ party1 = 'WARRIOR', party2 = 'PRIEST' })[unit] end
	Ambiguate = function(name) return name end
	RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PRIEST = { r = 1, g = 1, b = 1 } }
	LibStub = nil
	H.load('Keystone.lua')
	H.fire('PLAYER_LOGIN')
	return ns
end

local function Tip(ns, owner)
	world.tips = {}
	local tip = {
		AddLine = function(_, text) world.tips[#world.tips + 1] = { text } end,
		AddDoubleLine = function(_, a, b) world.tips[#world.tips + 1] = { a, b } end,
	}
	ns.AddKeystoneTooltip(tip, owner)
	return world.tips
end

local function Line(tips, left)
	for i, l in ipairs(tips) do if l[1] == left then return l[2], i end end
end

do
	local ns = BootKeys()
	local tips = Tip(ns)
	local _, first = Line(tips, 'Voidscar Arena')
	local _, second = Line(tips, 'Ara-Kara, City of Echoes')
	H.check(Line(tips, 'SEASON BEST') == nil and tips[2][1] == 'SEASON BEST', 'season: its own section')
	H.check(first and second and first < second, 'season: best score first')
	H.equal(Line(tips, 'Voidscar Arena'), '+14   412', 'season: best level and score')
	H.equal(Line(tips, 'Ara-Kara, City of Echoes'), '|cff9a9ca5+13|r   398', 'season: an over-time best is grey')
	H.equal(Line(tips, 'Maisara Caverns'), '|cff9a9ca5-|r', 'season: a dungeon not run yet')
	H.equal(Line(tips, 'This week'), 'Fortified · Xal\'atath\'s Guile', 'season: this week\'s affixes')
	H.noErrors()
end

do
	local ns = BootKeys()
	H.equal(world.prefixes[1], 'LibKS', 'party keys: the LibKeystone prefix is registered')
	H.fire('GROUP_ROSTER_UPDATE')
	H.check(#world.sent == 1 and world.sent[1][1] == 'LibKS' and world.sent[1][2] == 'R' and world.sent[1][3] == 'PARTY',
		'party keys: the party is asked')
	H.fire('CHAT_MSG_ADDON', 'LibKS', '13,503,2900', 'PARTY', 'Brakk-OtherRealm')
	local tips = Tip(ns)
	H.equal(Line(tips, 'Brakk'), 'Ara-Kara, City of Echoes +13', 'party keys: an answer shows the member\'s key')
	H.equal(Line(tips, 'Lumi'), 'no data', 'party keys: "no data" without an answer')
	H.equal(#world.sent, 1, 'party keys: the tooltip does not ask again right away')
	H.fire('CHAT_MSG_ADDON', 'LibKS', '0,0,1500', 'PARTY', 'Lumi')
	H.equal(Line(Tip(ns), 'Lumi'), 'no key', 'party keys: an answer without a key')

	-- In a running key: nothing sent, nothing taken.
	world.active = true
	H.now = H.now + 60
	H.fire('GROUP_ROSTER_UPDATE')
	H.equal(#world.sent, 1, 'party keys: nothing is sent in a running key')
	H.fire('CHAT_MSG_ADDON', 'LibKS', '15,585,3000', 'PARTY', 'Brakk-OtherRealm')
	H.equal(Line(Tip(ns), 'Brakk'), 'Ara-Kara, City of Echoes +13', 'party keys: not refreshed in a running key')
	world.active = false
	world.encounter = true
	H.fire('GROUP_ROSTER_UPDATE')
	H.equal(#world.sent, 1, 'party keys: nothing is sent in a boss fight')
	world.encounter = false
	H.noErrors()
end

do
	local ns = BootKeys()
	-- The game refuses the send (addon chat lockdown): it does not count, the next try goes out.
	world.result = 11
	H.fire('GROUP_ROSTER_UPDATE')
	H.equal(#world.sent, 1, 'party keys: one try')
	world.result = 0
	H.fire('GROUP_ROSTER_UPDATE')
	H.equal(#world.sent, 2, 'party keys: a refused send is tried again without waiting')
	H.fire('GROUP_ROSTER_UPDATE')
	H.equal(#world.sent, 2, 'party keys: a sent request waits before the next')
	H.runTimers(10)
	H.equal(#world.sent, 3, 'party keys: the waiting request goes out once')
	world.locked = true
	H.runTimers(20)
	H.fire('GROUP_ROSTER_UPDATE')
	H.equal(#world.sent, 3, 'party keys: nothing while the game blocks addon chat')
	H.noErrors()
end

do
	local ns = BootKeys()
	H.fire('CHAT_MSG_ADDON', 'LibKS', 'R', 'PARTY', 'Brakk-OtherRealm')
	H.check(world.sent[1] and world.sent[1][2] == '12,585,3120', 'party keys: a request is answered with your key')
	H.fire('CHAT_MSG_ADDON', 'LibKS', 'R', 'PARTY', 'Lumi')
	H.equal(#world.sent, 1, 'party keys: answers are spaced out')
	H.runTimers(3.2)
	H.equal(#world.sent, 2, 'party keys: the held answer goes out once')
	H.fire('CHAT_MSG_ADDON', 'LibKS', 'R', 'PARTY', 'Aril')
	H.runTimers(5)
	H.equal(#world.sent, 2, 'party keys: your own request is not answered')
	local hidden = Hidden()
	local ok = pcall(H.fire, 'CHAT_MSG_ADDON', 'LibKS', hidden, 'PARTY', 'Lumi')
	H.check(ok and #world.sent == 2, 'party keys: a hidden message is left alone')
	H.secret = nil
	LibStub = function() return {} end
	H.runTimers(5)
	H.fire('CHAT_MSG_ADDON', 'LibKS', 'R', 'PARTY', 'Lumi')
	H.equal(#world.sent, 2, 'party keys: another addon\'s LibKeystone answers instead')
	H.noErrors()
end

do
	local ns = BootKeys()
	local owner = H.NewFrame('Button')
	local redraws = 0
	owner:SetScript('OnEnter', function() redraws = redraws + 1 end)
	GameTooltip = { IsOwned = function(_, frame) return frame == owner end }
	Tip(ns, owner)
	H.fire('CHAT_MSG_ADDON', 'LibKS', '13,503,2900', 'PARTY', 'Brakk-OtherRealm')
	H.fire('CHAT_MSG_ADDON', 'LibKS', '11,560,2500', 'PARTY', 'Lumi')
	H.runTimers(0.2)
	H.equal(redraws, 1, 'party keys: answers redraw the open tooltip once')
	H.noErrors()
end

do
	local ns = BootKeys({ partyKeys = false, keystoneSeason = false })
	H.equal(#world.prefixes, 0, 'party keys off: no prefix')
	H.fire('GROUP_ROSTER_UPDATE')
	H.fire('CHAT_MSG_ADDON', 'LibKS', 'R', 'PARTY', 'Brakk-OtherRealm')
	H.equal(#world.sent, 0, 'party keys off: nothing sent, no answer')
	local tips = Tip(ns)
	H.equal(#tips, 0, 'season and party keys off: the tooltip has no new lines')
	H.noErrors()
end

do
	-- The top bar's keystone tooltip calls in with itself as the owner.
	local ns = H.boot()
	world = { tips = {} }
	UnitGUID = function() return 'G' end
	UnitName = function() return 'Aril' end
	UnitClass = function() return 'Paladin', 'PALADIN' end
	GetRealmName = function() return 'Realm' end
	GetMoney = function() return 0 end
	BreakUpLargeNumbers = tostring
	GameTooltip = H.NewFrame('GameTooltip')
	GameTooltip.SetOwner = function() world.tips = {} end
	GameTooltip.AddLine = function(_, text) world.tips[#world.tips + 1] = text end
	C_MythicPlus = { GetOwnedKeystoneChallengeMapID = function() return 585 end, GetOwnedKeystoneLevel = function() return 12 end }
	C_ChallengeMode = { GetMapUIInfo = function() return 'Voidscar Arena' end }
	for key in pairs(ns.C.databar.show) do ns.C.databar.show[key] = false end
	ns.C.databar.show.keystone = true
	local got
	ns.AddKeystoneTooltip = function(tip, owner) got = { tip, owner } end
	H.load('DataBar.lua')
	H.fire('PLAYER_LOGIN')
	local seg = FindFrame(function(f) return f.key == 'keystone' end)
	seg:GetScript('OnEnter')(seg)
	H.equal(world.tips[1], 'Voidscar Arena +12', 'tooltip: your keystone as the title')
	H.check(got and got[1] == GameTooltip and got[2] == seg, 'tooltip: the season and party lines are added with the segment as owner')
	H.noErrors()
end

H.done()
