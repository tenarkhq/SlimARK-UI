-- 3.0 part C: the new top bar elements (29 spec and loadout, 31 Alts, 35 XP/rep line, 36 friends
-- and addon CPU, 52 quiet switch), the loadout reminder (30) and this week in the vault tooltip (32).
-- Run from the repository root:
--   lua5.1 tests/claude/topbar-3-0.lua
local H = dofile('tests/claude/lib/helpers.lua')

local W -- the made-up game state of one boot
local OLD_SHOW = { 'micro', 'durability', 'fps', 'latency', 'queue', 'currency', 'clock', 'gold', 'itemLevel', 'keystone',
	'vault', 'autoQuest', 'addons' }

-- A secret value: any comparison, arithmetic, concatenation or field read on it raises an error,
-- so a test fails as soon as the code under test uses one the way 12.x forbids.
local function Secret(label)
	local function boom() error('secret value used: ' .. label, 2) end
	local t = setmetatable({}, { __lt = boom, __le = boom, __concat = boom, __add = boom, __sub = boom, __mul = boom,
		__div = boom, __unm = boom, __len = boom, __index = function() boom() end })
	H.secret = H.secret or {}
	H.secret[t] = true
	return t
end

local function Plain(text)
	return (tostring(text or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
end

local function NoErrors(what)
	local errors = {}
	for _, line in ipairs(H.prints) do
		if line:find('ERROR ', 1, true) then table.insert(errors, line) end
	end
	H.check(#errors == 0, what .. ' runs without errors' .. (#errors > 0 and (': ' .. errors[1]) or ''))
end

local function Registered(event)
	for _, f in ipairs(H.frames) do
		if f._events[event] then return true end
	end
	return false
end

local function Seg(key)
	for _, f in ipairs(H.frames) do
		if f.key == key then return f end
	end
end

local function SegText(key)
	local s = Seg(key)
	return s and s:IsShown() and Plain(s.text._text) or nil
end

local function TipLine(label)
	for _, line in ipairs(GameTooltip.lines) do
		if Plain(line[1]) == label then return line[2] ~= nil and Plain(line[2]) or true end
	end
end

local function TipHas(text)
	for _, line in ipairs(GameTooltip.lines) do
		if Plain(line[1]):find(text, 1, true) or (line[2] and Plain(line[2]):find(text, 1, true)) then return true end
	end
	return false
end

local function FakeTooltip()
	local tip = H.NewFrame('GameTooltip', 'GameTooltip', UIParent)
	tip.lines = {}
	function tip:SetOwner(owner) self.owner = owner self.lines = {} end
	function tip:AddLine(text) table.insert(self.lines, { text }) end
	function tip:AddDoubleLine(a, b) table.insert(self.lines, { a, b }) end
	function tip:SetText(text) self.lines = { { text } } end
	_G.GameTooltip_Hide = function() tip:Hide() end
	return tip
end

local function World()
	W = {
		money = 4128800000, ilvl = 681.4, level = 90, keyMap = 585, keyLevel = 12, score = 3120, now = 2000000000,
		resetIn = 3 * 86400 + 14 * 3600, running = false, combatSpec = nil,
		maps = { [585] = 'Voidscar Arena', [503] = 'Ara-Kara, City of Echoes' },
		currencies = { [3442] = { name = 'Adventurer Mistcrest' }, [3443] = { name = 'Veteran Mistcrest' },
			[3444] = { name = 'Champion Mistcrest', quantity = 30, iconFileID = 4 }, [3445] = { name = 'Hero Mistcrest', quantity = 120, iconFileID = 5 },
			[3446] = { name = 'Myth Mistcrest', quantity = 0 } },
		activities = {}, rewardLinks = {}, upgrade = {}, ilvls = {}, runs = {}, saved = {},
		reads = { mythic = 0, profiler = 0 }, calls = {},
	}
	_G.UnitGUID = function() return 'Player-1-ME' end
	_G.UnitName = function() return 'Aril' end
	_G.UnitClass = function() return 'Paladin', 'PALADIN', 2 end
	_G.UnitLevel = function() return W.level end
	_G.GetRealmName = function() return 'Realm' end
	_G.GetMoney = function() return W.money end
	_G.GetServerTime = function() return W.now end
	_G.GetAverageItemLevel = function() return 690, W.ilvl end
	_G.BreakUpLargeNumbers = function(n) return tostring(n) end
	_G.GetMoneyString = function(n) return n .. 'c' end
	_G.RAID_CLASS_COLORS = { PALADIN = { r = 0.96, g = 0.55, b = 0.73 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
		MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
	_G.NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
	_G.LOCALIZED_CLASS_NAMES_MALE = { MAGE = 'Mage', WARRIOR = 'Warrior' }
	_G.GetFramerate = function() return 143.6 end
	_G.GetNetStats = function() return 0, 0, 22, 38 end
	_G.C_MythicPlus = {
		GetOwnedKeystoneChallengeMapID = function() W.reads.mythic = W.reads.mythic + 1 return W.keyMap end,
		GetOwnedKeystoneLevel = function() return W.keyLevel end,
		RequestMapInfo = function() end,
		GetRunHistory = function() return W.runs end,
	}
	_G.C_ChallengeMode = {
		GetMapUIInfo = function(id) return W.maps[id] end,
		GetOverallDungeonScore = function() return W.score end,
		GetDungeonScoreRarityColor = function() return { GetRGB = function() return 1, 0.5, 0 end } end,
		IsChallengeModeActive = function() return W.running end,
	}
	_G.C_WeeklyRewards = {
		GetActivities = function(kind) return W.activities[kind] or {} end,
		HasAvailableRewards = function() return false end,
		GetExampleRewardItemHyperlinks = function(id) return W.rewardLinks[id] end,
	}
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return W.resetIn end }
	_G.C_CurrencyInfo = { GetCurrencyInfo = function(id) return W.currencies[id] end }
	_G.C_Item = {
		GetItemUpgradeInfo = function(link) return W.upgrade[link] end,
		GetDetailedItemLevelInfo = function(link) return W.ilvls[link] end,
	}
	_G.IsShiftKeyDown = function() return W.shift or false end
	_G.IsControlKeyDown = function() return W.ctrl or false end
	_G.GameTooltip = FakeTooltip()
end

local function Enums()
	rawset(Enum, 'WeeklyRewardChestThresholdType', { Raid = 1, Activities = 2, World = 3 })
	rawset(Enum, 'LoadConfigResult', { Error = 0, NoChangesNecessary = 1, LoadInProgress = 2, Ready = 3 })
	rawset(Enum, 'AddOnProfilerMetric', { RecentAverageTime = 1 })
end

-- Loads the top bar with only the old elements this test asks for; the new switches keep their
-- defaults unless setup changes them.
local function BootBar(setup, flavor)
	local ns = H.setup()
	Enums()
	World()
	if flavor then
		C_AddOns.GetAddOnMetadata = function(_, field) if field == 'X-SlimARK-Flavor' then return flavor end return '3.0.0' end
	end
	H.load('Config.lua')
	for _, key in ipairs(OLD_SHOW) do ns.C.databar.show[key] = false end
	ns.C.modules.character = false
	if setup then setup(ns.C, ns) end
	H.load('Core.lua')
	H.load('DataBar.lua')
	H.load('Alts.lua')
	H.load('Talents.lua')
	H.load('Character.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

------------------------------------------------------------------------
-- Defaults: only Alts is on; a new element that is off builds and registers nothing.
------------------------------------------------------------------------
do
	local ns = BootBar()
	NoErrors('the default top bar')
	H.check(Seg('alts') ~= nil and SegText('alts') == 'Alts', '31 Alts is on by default')
	for _, key in ipairs({ 'spec', 'friends', 'quiet' }) do
		H.check(Seg(key) == nil, 'default: no ' .. key .. ' segment')
	end
	H.check(ns.C.databar.show.xp == false and ns.C.databar.addonCPU == false and ns.C.databar.vaultWeek == false,
		'default: the XP line, addon CPU and weekly vault data are off')
	for _, event in ipairs({ 'FRIENDLIST_UPDATE', 'GUILD_ROSTER_UPDATE', 'PLAYER_XP_UPDATE', 'UPDATE_FACTION', 'TRAIT_CONFIG_UPDATED',
		'PLAYER_SPECIALIZATION_CHANGED', 'CHALLENGE_MODE_START', 'PLAYER_REGEN_DISABLED' }) do
		H.check(not Registered(event), 'default: ' .. event .. ' is not registered')
	end
	H.check(Registered('PLAYER_LOGOUT'), '31 Alts saves at logout')
end

do
	BootBar(function(C) C.databar.show.alts = false end)
	H.check(Seg('alts') == nil and not Registered('PLAYER_LOGOUT'), '31 Alts off: no segment, no events')
end

------------------------------------------------------------------------
-- 31: Alts. The store sits beside the gold entry and keeps both writers' fields.
------------------------------------------------------------------------
do
	local ns = BootBar(function(C) C.databar.show.gold = true end)
	-- An old entry under realm|name moves under the GUID, as the gold element did it.
	ns.DB.gold['Realm|Aril'] = { money = 1, class = 'PALADIN' }
	ns.DB.gold['Player-1-ALT'] = { name = 'Morvain', realm = 'Realm', class = 'WARRIOR', money = 882100000, ilvl = 672.2,
		keyName = 'Ara-Kara', keyLevel = 10, vault = 2, score = 2604, updated = W.now - 100, crests = { [3445] = 40 } }
	ns.DB.gold['Player-2-OLD'] = { name = 'Storma', realm = 'Other', class = 'MAGE', money = 210450000, ilvl = 665,
		keyName = 'Priory', keyLevel = 9, vault = 1, score = 1980, updated = W.now - 8 * 86400 }
	ns.DB.gold['Realm|Vexis'] = { money = 93020000, class = 'WARRIOR' }
	W.activities = { [1] = { { progress = 2, threshold = 1 }, { progress = 0, threshold = 4 } },
		[2] = { { progress = 4, threshold = 1 }, { progress = 4, threshold = 4 }, { progress = 4, threshold = 4 } } }
	H.fire('PLAYER_ENTERING_WORLD')
	H.runTimers(1)
	local me = ns.DB.gold['Player-1-ME']
	H.check(me and not ns.DB.gold['Realm|Aril'], '31 this character is kept under its GUID')
	H.equal(me.money, 4128800000, '31 the gold is saved')
	H.equal(me.ilvl, 681.4, '31 the equipped item level is saved')
	H.equal(me.keyName, 'Voidscar Arena', '31 the keystone dungeon is saved')
	H.equal(me.keyLevel, 12, '31 the keystone level is saved')
	H.equal(me.vault, 4, '31 the unlocked vault slots are counted over raid, dungeons and world')
	H.equal(me.score, 3120, '31 the Mythic+ score is saved')
	H.equal(me.crests[3445], 120, '31 the crests of the season table are saved')

	-- The gold element writes into the same entry without dropping the Alts fields.
	W.money = 4128900000
	H.fire('PLAYER_MONEY')
	H.check(me.money == 4128900000 and me.ilvl == 681.4 and me.crests[3445] == 120, '31 the gold update keeps the Alts fields')

	-- A burst of events is one write a second later.
	local saves = 0
	local old = ns.CharEntry
	ns.CharEntry = function() saves = saves + 1 return old() end
	for _ = 1, 5 do H.fire('BAG_UPDATE_DELAYED') H.fire('CURRENCY_DISPLAY_UPDATE') end
	H.runTimers(1)
	H.equal(saves, 1, '31 a burst of bag and currency events is saved once')
	ns.CharEntry = old

	-- The table.
	local seg = Seg('alts')
	seg:GetScript('OnEnter')(seg)
	local tip = _G.SlimARK_AltsTooltip
	H.check(tip and tip:IsShown(), '31 hovering Alts opens the table')
	local texts = {}
	for _, f in ipairs(H.frames) do
		if f._kind == 'FontString' and f._shown and f._text and (f._parent == tip or (f._parent and f._parent._parent == tip)) then
			texts[Plain(f._text)] = true
		end
	end
	for _, want in ipairs({ 'Name', 'ilvl', 'Key', 'Vault', 'Score', 'Gold', 'Aril', '681', 'Voidscar Arena +12', '4/9', '3120',
		'412890', 'Morvain', 'Ara-Kara +10', '2/9', 'Storma - Other', 'Vexis', 'Total gold', '531447g', 'Crests: hover a name' }) do
		H.check(texts[want], '31 the table shows ' .. want)
	end
	H.check(not texts['Priory +9'] and not texts['1/9'], '31 a key and vault progress saved before the weekly reset are not shown')

	-- Hovering a name lists its crests.
	local morvain
	for _, f in ipairs(H.frames) do
		if f._kind == 'Button' and f._parent == tip and f.char and f.char.name == 'Morvain' then morvain = f end
	end
	H.check(morvain ~= nil, '31 every character has a row to hover')
	morvain:GetScript('OnEnter')(morvain)
	H.check(TipLine('Morvain: crests') and TipHas('Hero Mistcrest'), '31 hovering a name lists its crests')

	-- The table stays while the mouse moves onto it and goes when it leaves both.
	tip.IsMouseOver = function() return true end
	seg:GetScript('OnLeave')(seg)
	H.check(tip:IsShown(), '31 the table stays while the mouse is on it')
	tip.IsMouseOver = function() return false end
	tip:GetScript('OnLeave')(tip)
	H.check(not tip:IsShown(), '31 the table goes when the mouse leaves it')
	NoErrors('31 Alts')
end

do
	-- WoW Forever: no Mythic+ columns and no Mythic+ reads.
	local ns = BootBar(nil, 'forever')
	H.fire('PLAYER_ENTERING_WORLD')
	H.runTimers(1)
	H.equal(W.reads.mythic, 0, '31 Forever: the Alts store reads no Mythic+ data')
	local seg = Seg('alts')
	seg:GetScript('OnEnter')(seg)
	local heads = {}
	for _, f in ipairs(H.frames) do
		if f._kind == 'FontString' and f._shown and f._parent == _G.SlimARK_AltsTooltip then heads[Plain(f._text)] = true end
	end
	H.check(heads.Gold and heads.ilvl and not heads.Key and not heads.Vault and not heads.Score, '31 Forever: the table has no Mythic+ columns')
	H.check(ns.DB.gold['Player-1-ME'].keyName == nil, '31 Forever: no keystone saved')
	NoErrors('31 Alts on Forever')
end

------------------------------------------------------------------------
-- 29: spec and loadout. Changes only out of combat; a pick made in combat waits for its end.
------------------------------------------------------------------------
local function TalentWorld()
	W.specIndex, W.lastSelected, W.active, W.loot = 3, { [70] = 22 }, 900, 0
	W.loadResult = 2
	W.configs = { [70] = { 21, 22 } }
	W.configNames = { [21] = 'Raid ST', [22] = 'M+ AoE' }
	W.sets = { { id = 1, name = 'Raid', equipped = false }, { id = 2, name = 'Mythic+', equipped = true } }
	local specs = { { 65, 'Holy' }, { 66, 'Protection' }, { 70, 'Retribution' } }
	_G.C_SpecializationInfo = {
		GetSpecialization = function() return W.specIndex end,
		GetSpecializationInfo = function(i) local s = specs[i] if s then return s[1], s[2] end end,
		GetNumSpecializationsForClassID = function() return 3 end,
		SetSpecialization = function(i) table.insert(W.calls, 'spec ' .. i) end,
	}
	_G.GetSpecializationInfoByID = function(id) for _, s in ipairs(specs) do if s[1] == id then return id, s[2] end end end
	_G.C_ClassTalents = {
		GetConfigIDsBySpecID = function(spec) return W.configs[spec] or {} end,
		GetLastSelectedSavedConfigID = function(spec) return W.lastSelected[spec] end,
		UpdateLastSelectedSavedConfigID = function(spec, id) W.lastSelected[spec] = id end,
		LoadConfig = function(id) table.insert(W.calls, 'load ' .. id) return W.loadResult end,
		GetActiveConfigID = function() return W.active end,
		GetStarterBuildActive = function() return false end,
	}
	_G.C_Traits = { GetConfigInfo = function(id) return W.configNames[id] and { name = W.configNames[id] } end }
	_G.GetLootSpecialization = function() return W.loot end
	_G.SetLootSpecialization = function(id) table.insert(W.calls, 'loot ' .. id) end
	_G.C_EquipmentSet = {
		GetEquipmentSetIDs = function() return { 1, 2 } end,
		GetEquipmentSetInfo = function(id) local s = W.sets[id] return s.name, 0, id, s.equipped end,
		UseEquipmentSet = function(id) table.insert(W.calls, 'gear ' .. id) end,
	}
	_G.MenuResponse = { Close = 3 }
	_G.MenuUtil = { CreateContextMenu = function(owner, generate)
		local menu = { items = {} }
		local root = {}
		function root:CreateTitle(text) menu.title = text end
		function root:CreateRadio(text, isSelected, setSelected, data)
			table.insert(menu.items, { text = text, selected = isSelected(data), pick = function() return setSelected(data) end })
		end
		function root:CreateButton(text, fn) table.insert(menu.items, { text = text, pick = fn }) end
		generate(owner, root)
		W.menu = menu
	end }
end

local function Item(text)
	for _, item in ipairs(W.menu and W.menu.items or {}) do
		if Plain(item.text) == text then return item end
	end
end

do
	BootBar(function(C) C.databar.show.spec = true TalentWorld() end)
	NoErrors('29 the spec element')
	local seg = Seg('spec')
	H.equal(SegText('spec'), 'Retribution · M+ AoE', '29 the element shows the spec and the loadout')
	seg:GetScript('OnEnter')(seg)
	H.equal(TipLine('Loadout'), 'M+ AoE', '29 the tooltip shows the loadout')
	H.equal(TipLine('Loot spec'), 'Current spec (Retribution)', '29 the tooltip shows the loot spec')
	H.equal(TipLine('Gear set'), 'Mythic+', '29 the tooltip shows the worn gear set')

	-- Click: the spec menu; a pick changes the spec out of combat.
	seg:GetScript('OnClick')(seg, 'LeftButton')
	H.equal(W.menu and W.menu.title, 'Specialization', '29 a click opens the spec menu')
	H.check(Item('Retribution').selected and not Item('Holy').selected, '29 the current spec is marked')
	H.equal(Item('Holy').pick(), 3, '29 a pick closes the menu')
	H.equal(W.calls[1], 'spec 1', '29 the picked spec is activated')

	-- A pick made after combat started waits for its end.
	W.calls = {}
	seg:GetScript('OnClick')(seg, 'LeftButton')
	H.combat = true
	Item('Protection').pick()
	H.equal(#W.calls, 0, '29 nothing changes in combat')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(W.calls[1], 'spec 2', '29 the pick made in combat runs when the fight ends')

	-- In combat no menu opens.
	W.menu, W.calls = nil, {}
	H.combat = true
	seg:GetScript('OnClick')(seg, 'LeftButton')
	H.check(W.menu == nil and #W.calls == 0, '29 a click in combat opens nothing')
	H.combat = false

	-- Right click: the loadouts; the mark moves when the change lands.
	seg:GetScript('OnClick')(seg, 'RightButton')
	H.equal(W.menu.title, 'Loadout', '29 a right click opens the loadout menu')
	Item('Raid ST').pick()
	H.equal(W.calls[1], 'load 21', '29 the picked loadout is loaded')
	H.equal(W.lastSelected[70], 22, '29 the mark waits for the change to land')
	H.fire('TRAIT_CONFIG_UPDATED', 12345)
	H.equal(W.lastSelected[70], 22, '29 another config update does not move the mark')
	H.fire('TRAIT_CONFIG_UPDATED', 900)
	H.equal(W.lastSelected[70], 21, '29 the mark moves when the active config is updated')
	H.equal(SegText('spec'), 'Retribution · Raid ST', '29 the element follows the new loadout')

	-- Shift: loot spec; ctrl: gear set.
	W.calls, W.shift = {}, true
	seg:GetScript('OnClick')(seg, 'LeftButton')
	H.equal(W.menu.title, 'Loot spec', '29 shift-click opens the loot spec menu')
	Item('Holy').pick()
	H.equal(W.calls[1], 'loot 65', '29 the loot spec is set')
	W.shift, W.ctrl, W.calls = false, true, {}
	seg:GetScript('OnClick')(seg, 'LeftButton')
	H.equal(W.menu.title, 'Gear set', '29 ctrl-click opens the gear set menu')
	H.check(Item('Mythic+').selected, '29 the worn gear set is marked')
	Item('Raid').pick()
	H.equal(W.calls[1], 'gear 1', '29 the gear set is equipped')
	W.ctrl = false
	NoErrors('29 the spec menus')
end

------------------------------------------------------------------------
-- 30: the loadout reminder on entering a dungeon.
------------------------------------------------------------------------
local function EnterDungeon(id, name, kind)
	_G.GetInstanceInfo = function() return name, kind or 'party', 1, 'Normal', 5, 0, false, id end
	H.fire('PLAYER_ENTERING_WORLD')
	H.runTimers(2)
end

do
	BootBar(function(C) C.loadout.reminder = false TalentWorld() end)
	_G.GetInstanceInfo = function() return 'Ara-Kara', 'party', 1, 'Normal', 5, 0, false, 2660 end
	H.check(not Registered('CHALLENGE_MODE_START') and not Registered('TRAIT_CONFIG_UPDATED'), '30 the reminder off registers nothing')
end

do
	local ns = BootBar(function(C) C.loadout.reminder = true TalentWorld() end)
	ns.CharDB.loadouts = { [2660] = { [70] = 21 } }
	EnterDungeon(2660, 'Ara-Kara')
	local win = _G.SlimARK_LoadoutReminder
	H.check(win and win:IsShown(), '30 a different loadout than last time here shows the reminder')
	H.equal(Plain(win.where._text), 'Ara-Kara', '30 the reminder names the dungeon')
	H.equal(Plain(win.last._text), 'Last time here: Raid ST', '30 the reminder shows the loadout used last time')
	H.equal(Plain(win.now._text), 'Now: M+ AoE', '30 the reminder shows the current loadout')

	-- Combat hides it, its end brings it back.
	H.combat = true
	H.fire('PLAYER_REGEN_DISABLED')
	H.check(not win:IsShown(), '30 the reminder hides in combat')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.check(win:IsShown(), '30 the reminder comes back after combat')

	-- Switch in combat waits for the end of the fight.
	W.calls = {}
	H.combat = true
	win.switch:GetScript('OnClick')(win.switch)
	H.check(#W.calls == 0 and not win:IsShown(), '30 Switch in combat loads nothing yet')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(W.calls[1], 'load 21', '30 Switch loads the loadout used last time after combat')
	H.fire('TRAIT_CONFIG_UPDATED', 900)
	H.equal(ns.CharDB.loadouts[2660][70], 21, '30 the switched loadout is remembered for this dungeon')

	-- Back to M+ AoE inside: remembered; re-entering with it shows nothing.
	C_ClassTalents.UpdateLastSelectedSavedConfigID(70, 22)
	H.equal(ns.CharDB.loadouts[2660][70], 22, '30 a loadout change inside the dungeon is remembered')
	EnterDungeon(2660, 'Ara-Kara')
	H.check(not win:IsShown(), '30 the same loadout as last time shows nothing')

	-- Keep closes it and keeps the current one.
	ns.CharDB.loadouts[2660][70] = 21
	EnterDungeon(2660, 'Ara-Kara')
	H.check(win:IsShown(), '30 the reminder shows again for a different loadout')
	W.calls = {}
	win.keep:GetScript('OnClick')(win.keep)
	H.check(not win:IsShown() and #W.calls == 0, '30 Keep closes the reminder and loads nothing')
	H.equal(ns.CharDB.loadouts[2660][70], 22, '30 Keep remembers the current loadout')

	-- Not in a running key, not outside dungeons.
	ns.CharDB.loadouts[2660][70] = 21
	W.running = true
	EnterDungeon(2660, 'Ara-Kara')
	H.check(not win:IsShown(), '30 no reminder in a running key')
	W.running = false
	ns.CharDB.loadouts[3000] = { [70] = 21 }
	EnterDungeon(3000, 'Liberation', 'raid')
	H.check(not win:IsShown(), '30 no reminder in a raid')
	NoErrors('30 the loadout reminder')
end

------------------------------------------------------------------------
-- 35: the XP/reputation line.
------------------------------------------------------------------------
local function XPWorld()
	W.canXP, W.watched = false, nil
	_G.GameRulesUtil = { CanShowExperienceBar = function() return W.canXP end }
	_G.UnitXP = function() return 4500 end
	_G.UnitXPMax = function() return 10000 end
	_G.GetXPExhaustion = function() return 2000 end
	_G.FACTION_STANDING_LABEL5 = 'Friendly'
	_G.C_Reputation = {
		GetWatchedFactionData = function() return W.watched end,
		IsFactionParagonForCurrentPlayer = function() return false end,
		IsMajorFaction = function() return false end,
	}
	_G.C_GossipInfo = { GetFriendshipReputation = function() return { friendshipFactionID = 0 } end }
end

local function XPLine()
	for _, f in ipairs(H.frames) do
		if f._kind == 'StatusBar' and f._parent and f._parent._parent == _G.SlimARK_DataBar then return f._parent, f end
	end
end

do
	BootBar(function(C) C.databar.show.xp = true XPWorld() end)
	local line, bar = XPLine()
	H.check(line ~= nil, '35 the line is built with its switch on')
	H.check(not line:IsShown(), '35 max level without a watched faction: no line')
	W.watched = { factionID = 2600, name = 'The Severed Threads', reaction = 5, currentReactionThreshold = 3000,
		nextReactionThreshold = 9000, currentStanding = 5760 }
	H.fire('UPDATE_FACTION')
	H.check(line:IsShown(), '35 max level with a watched faction: the reputation line')
	local color = H.lastCall(bar, 'SetStatusBarColor')
	H.check(color[1] < 0.3 and color[2] > 0.6, '35 the reputation line is green')
	H.equal(H.lastCall(bar, 'SetValue')[1], 2760, '35 the line shows the progress in the current standing')
	W.watched, W.canXP = nil, true
	H.fire('PLAYER_XP_UPDATE')
	color = H.lastCall(bar, 'SetStatusBarColor')
	H.check(line:IsShown() and color[1] > 0.5 and color[3] > 0.8, '35 levelling without a faction: the purple XP line')
	W.watched = { factionID = 2600, name = 'The Severed Threads', reaction = 5, currentReactionThreshold = 3000,
		nextReactionThreshold = 9000, currentStanding = 5760 }
	H.fire('UPDATE_FACTION')
	color = H.lastCall(bar, 'SetStatusBarColor')
	H.check(color[1] < 0.3, '35 with both the line shows the reputation')
	line:GetScript('OnEnter')(line)
	H.check(TipLine('The Severed Threads') and TipLine('Friendly') == '2760 / 6000 (46%)', '35 the tooltip shows the reputation')
	H.check(TipLine('XP') == '4500 / 10000 (45%)' and TipLine('Rested') == '2000', '35 and the XP in the tooltip')
	NoErrors('35 the XP/reputation line')
end

do
	BootBar(function() XPWorld() end)
	H.check(XPLine() == nil and not Registered('PLAYER_XP_UPDATE'), '35 the line off builds and registers nothing')
end

------------------------------------------------------------------------
-- 36: friends and guild online, and the addon CPU in the FPS tooltip.
------------------------------------------------------------------------
local function SocialWorld()
	W.roster = 0
	_G.C_FriendList = {
		GetNumOnlineFriends = function() return 1 end,
		GetNumFriends = function() return 2 end,
		GetFriendInfoByIndex = function(i)
			if i == 1 then return { connected = true, name = 'Brakk', className = 'Warrior', area = 'Dornogal' } end
			return { connected = false, name = 'Offline' }
		end,
	}
	_G.BNGetNumFriends = function() return 5, 3 end
	_G.BNET_CLIENT_WOW = 'WoW'
	_G.C_BattleNet = { GetFriendAccountInfo = function(i)
		local list = {
			{ accountName = 'Thundra#1', gameAccountInfo = { isOnline = true, clientProgram = 'WoW', characterName = 'Thundra' } },
			{ accountName = 'Lumi#2', gameAccountInfo = { isOnline = true, clientProgram = 'App' } },
			{ accountName = Secret('bnet name'), gameAccountInfo = { isOnline = true, clientProgram = 'App' } },
			{ accountName = 'Gone#4', gameAccountInfo = { isOnline = false } },
			{ accountName = 'Gone#5', gameAccountInfo = { isOnline = false } },
		}
		return list[i]
	end }
	_G.IsInGuild = function() return true end
	_G.GetNumGuildMembers = function() return 40, 13, 13 end
	_G.GetGuildRosterInfo = function(i)
		if i == 1 then return 'Aril-Realm', 'GM', 0, 90, 'Paladin', 'Dornogal', '', '', true, 0, 'PALADIN' end
		if i == 2 then return 'Vexis-Realm', 'Member', 1, 90, 'Mage', 'Silvermoon', '', '', true, 0, 'MAGE' end
		if i == 3 then return Secret('guild name'), 'Member', 1, 90, 'Mage', 'X', '', '', true, 0, 'MAGE' end
		return 'Off-Realm', 'Member', 1, 90, 'Mage', 'X', '', '', false, 0, 'MAGE'
	end
	_G.Ambiguate = function(name) return (name:gsub('%-.*$', '')) end
	_G.C_GuildInfo = { GuildRoster = function() W.roster = W.roster + 1 end }
end

do
	BootBar(function(C) C.databar.show.friends = true SocialWorld() end)
	H.equal(SegText('friends'), 'F 4 · G 12', '36 the element counts friends and guild members online, without you')
	H.equal(W.roster, 1, '36 the guild list is asked for once at login')
	local seg = Seg('friends')
	seg:GetScript('OnEnter')(seg)
	H.check(TipLine('Brakk') == 'Dornogal' and TipLine('Thundra#1') == 'Thundra' and TipLine('Lumi#2'), '36 the friends are listed by name')
	H.check(TipLine('Vexis') == 'Silvermoon' and not TipLine('Aril') and not TipLine('Offline') and not TipLine('Off'),
		'36 online guild members are listed without you')
	H.equal(W.roster, 1, '36 the guild list is not asked again within 15 seconds')
	H.runTimers(20)
	seg:GetScript('OnEnter')(seg)
	H.equal(W.roster, 2, '36 hovering later asks for the guild list again')
	-- A burst of friend events updates the element once, a second later.
	_G.GetNumGuildMembers = function() return 40, 14, 14 end
	for _ = 1, 4 do H.fire('GUILD_ROSTER_UPDATE', false) end
	H.equal(SegText('friends'), 'F 4 · G 12', '36 the update waits for the burst to end')
	H.runTimers(1)
	H.equal(SegText('friends'), 'F 4 · G 13', '36 the burst ends in one update')
	NoErrors('36 friends and guild, secret names skipped')
end

local function ProfilerWorld()
	_G.C_AddOnProfiler = {
		IsEnabled = function() W.reads.profiler = W.reads.profiler + 1 return true end,
		GetApplicationMetric = function() return 10 end,
		GetOverallMetric = function() return 4 end,
		GetTopKAddOnsForMetric = function() return { { addOnName = 'Details', metricValue = 0.12 }, { addOnName = 'SlimARK-UI', metricValue = 0.036 } } end,
	}
end

do
	BootBar(function(C) C.databar.show.fps = true C.databar.addonCPU = true ProfilerWorld() end)
	local seg = Seg('fps')
	H.equal(W.reads.profiler, 0, '36 the profiler is not read until the FPS tooltip opens')
	seg:GetScript('OnEnter')(seg)
	H.check(W.reads.profiler == 1 and TipLine('Addon CPU (recent)'), '36 the FPS tooltip reads the addon CPU when it opens')
	H.equal(TipLine('Details'), '2.0%', '36 an addon\'s share is its time against the frame, as the addon list shows it')
	H.equal(TipLine('SlimARK-UI'), '0.6%', '36 every top addon gets its share')
	H.equal(TipLine('Home / World'), '22 / 38 ms', '36 the FPS tooltip shows the latency too')
	NoErrors('36 addon CPU')
end

do
	BootBar(function(C) C.databar.show.fps = true ProfilerWorld() end)
	H.check(Seg('fps'):GetScript('OnEnter') == nil and W.reads.profiler == 0, '36 the CPU switch off leaves the FPS element as it was')
end

------------------------------------------------------------------------
-- 52: the quiet switch, built against ns.Quiet only when it is there.
------------------------------------------------------------------------
do
	BootBar(function(C) C.databar.show.quiet = true end)
	H.check(Seg('quiet') == nil, '52 without the quiet mode module there is no switch')
	NoErrors('52 the switch without ns.Quiet')
end

do
	local on = false
	local ns = BootBar(function(C, ns)
		C.databar.show.quiet = true
		ns.Quiet = { IsOn = function() return on end, Toggle = function() on = not on end }
	end)
	H.equal(SegText('quiet'), 'Quiet OFF', '52 the switch shows the quiet mode state')
	local seg = Seg('quiet')
	seg:GetScript('OnClick')(seg)
	H.check(on and SegText('quiet') == 'Quiet ON', '52 a click switches quiet mode')
	on = false
	ns.UpdateQuietSegment()
	H.equal(SegText('quiet'), 'Quiet OFF', '52 ns.UpdateQuietSegment follows a change made elsewhere')
	NoErrors('52 the quiet switch')
end

do
	local ns = BootBar(function(_, ns) ns.Quiet = { IsOn = function() return false end, Toggle = function() end } end)
	H.check(Seg('quiet') == nil, '52 the quiet switch is hidden by default')
	H.check(ns.UpdateQuietSegment ~= nil and pcall(ns.UpdateQuietSegment), '52 ns.UpdateQuietSegment is safe without the switch')
end

------------------------------------------------------------------------
-- 32: this week at the bottom of the Great Vault tooltip.
------------------------------------------------------------------------
local function VaultWorld()
	W.raidInfo = 0
	_G.RequestRaidInfo = function() W.raidInfo = W.raidInfo + 1 end
	_G.GetNumSavedInstances = function() return 2 end
	_G.GetSavedInstanceInfo = function(i)
		if i == 1 then return 'Liberation', 1, 3600, 14, true, false, 0, true, 30, 'Normal', 8, 6 end
		return 'Old Raid', 2, 0, 14, false, false, 0, true, 30, 'Normal', 8, 8
	end
	W.runs = { { level = 11 }, { level = 12 }, { level = 10 }, { level = 12 } }
	W.activities = { [1] = { { id = 1, progress = 2, threshold = 2 } }, [2] = { { id = 2, progress = 4, threshold = 1 }, { id = 3, progress = 4, threshold = 4 } } }
	W.rewardLinks = { [1] = 'item:raid', [2] = 'item:m1', [3] = 'item:m4' }
	W.upgrade = { ['item:raid'] = { trackString = 'Hero', currentLevel = 1, maxLevel = 6 }, ['item:m1'] = { trackString = 'Hero', currentLevel = 1, maxLevel = 6 } }
	W.ilvls = { ['item:m4'] = 285 }
end

do
	BootBar(function(C) C.databar.show.vault = true C.databar.vaultWeek = true VaultWorld() end)
	H.equal(W.raidInfo, 1, '32 the lockouts are asked for once at login')
	local seg = Seg('vault')
	seg:GetScript('OnEnter')(seg)
	H.equal(TipLine('Reset in'), '3d 14h', '32 the time to the weekly reset')
	H.equal(TipLine('Runs'), '+12 +12 +11 +10', '32 this week\'s runs, highest first')
	H.equal(TipLine('Vault rewards'), 'Hero 1 · Hero 1 · 285', '32 the reward level of each unlocked slot')
	H.equal(TipLine('Liberation'), 'Normal 6/8', '32 a raid lockout with its progress')
	H.check(not TipLine('Old Raid'), '32 an expired lockout is not listed')
	NoErrors('32 the weekly vault data')
end

do
	BootBar(function(C) C.databar.show.vault = true VaultWorld() end)
	local seg = Seg('vault')
	seg:GetScript('OnEnter')(seg)
	H.check(not TipLine('This week') and W.raidInfo == 0, '32 off: the vault tooltip is as it was, nothing is asked')
end

------------------------------------------------------------------------
-- Settings: every new switch has its row, on the asked page, with the plan's default.
------------------------------------------------------------------------
do
	SlimARKDB = { settings = {} }
	local ns = { CharDB = {}, Print = function() end, On = function() end }
	assert(loadfile('SlimARK-UI/Config.lua'))('SlimARK-UI', ns)
	assert(loadfile('SlimARK-UI/Settings.lua'))('SlimARK-UI', ns)
	local S = ns.Settings
	local want = {
		['databar.show.alts'] = { true, 'databar' }, ['databar.show.spec'] = { false, 'databar' },
		['databar.show.friends'] = { false, 'databar' }, ['databar.show.quiet'] = { false, 'databar' },
		['databar.show.xp'] = { false, 'databar' }, ['databar.addonCPU'] = { false, 'databar' },
		['databar.vaultWeek'] = { false, 'databar' }, ['loadout.reminder'] = { false, 'databar' },
		['tooltipExtras.upgrade'] = { false, 'tooltip' }, ['tooltipExtras.ids'] = { false, 'tooltip' },
		['tooltipExtras.bagCount'] = { false, 'tooltip' }, ['tooltipExtras.known'] = { false, 'tooltip' },
		['tooltipExtras.mount'] = { false, 'tooltip' }, ['tooltipExtras.hideCombat'] = { false, 'tooltip' },
		['charsheet.upgrade'] = { false, 'character' }, ['charsheet.inspect'] = { false, 'character' },
	}
	for path, w in pairs(want) do
		H.check(S.defaults[path] == w[1] and S.pageOf[path] and S.pageOf[path].id == w[2],
			'settings: ' .. path .. ' is on the ' .. w[2] .. ' page, ' .. (w[1] and 'on' or 'off') .. ' by default')
	end
end

H.done()
