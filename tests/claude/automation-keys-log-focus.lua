-- 2.3.0 helpers: automatic combat logging, the "!keys" answer, the text on joining a group and
-- the quick focus binding. Run from the repository root:
--   lua5.1 tests/claude/automation-keys-log-focus.lua
local H = dofile('tests/codex/lib/runtime.lua')
local world

local function Printed(text)
	for _, line in ipairs(H.prints) do
		if line:find(text, 1, true) then return true end
	end
	return false
end

------------------------------------------------------------------------
-- Combat logging.
------------------------------------------------------------------------
local function BootLog(features)
	local ns = H.boot()
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	world = { kind = 'none', key = false, logging = false, advanced = '0', calls = 0 }
	GetInstanceInfo = function() return 'Somewhere', world.kind end
	C_ChallengeMode = { IsChallengeModeActive = function() return world.key end }
	C_ChatInfo = nil
	LoggingCombat = function(state)
		if state == nil then return world.logging end
		world.calls = world.calls + 1
		if world.refuse then return nil end
		world.logging = state
		return state
	end
	GetCVar = function(name) return name == 'advancedCombatLogging' and world.advanced or nil end
	SetCVar = function(name, value) if name == 'advancedCombatLogging' then world.advanced = tostring(value) end end
	H.load('CombatLog.lua')
	return ns
end

do
	local ns = BootLog()
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(not world.logging and world.calls == 0, 'log: nothing happens in the open world')

	world.kind = 'raid'
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(world.logging, 'log: entering a raid switches logging on')
	H.equal(world.advanced, '1', 'log: with Advanced Combat Logging')
	H.check(Printed('Combat logging is on'), 'log: a chat line says so')
	H.fire('PLAYER_ENTERING_WORLD')
	H.equal(world.calls, 1, 'log: a second zone change inside does not ask again')

	world.kind = 'none'
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(not world.logging, 'log: leaving switches it off')
	H.check(ns.CharDB.autoLog == nil, 'log: and forgets that it had started it')
end

do
	BootLog()
	world.kind = 'party'
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(not world.logging, 'log: a dungeon without a key is not logged')
	H.fire('CHALLENGE_MODE_START')
	H.check(world.logging, 'log: the start of a key switches logging on')
	-- A reload in the run: the key is still active, the log stays.
	world.key = true
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(world.logging, 'log: it stays on through a zone change in the run')
	world.key, world.kind = false, 'none'
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(not world.logging, 'log: leaving the dungeon switches it off')
end

do
	-- A log you started yourself is left alone.
	BootLog()
	world.logging = true
	world.kind = 'raid'
	H.fire('PLAYER_ENTERING_WORLD')
	world.kind = 'none'
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(world.logging and world.calls == 0, 'log: your own /combatlog is not touched')
end

do
	-- The game refuses the call: no mark is kept, the next event tries again.
	local ns = BootLog()
	world.kind, world.refuse = 'raid', true
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(not world.logging and ns.CharDB.autoLog == nil, 'log: a refused call leaves no mark')
	world.refuse = false
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(world.logging and ns.CharDB.autoLog == true, 'log: the next event tries again')
end

do
	BootLog({ autoCombatLog = false })
	world.kind = 'raid'
	H.fire('PLAYER_ENTERING_WORLD')
	H.fire('CHALLENGE_MODE_START')
	H.check(not world.logging and world.advanced == '0', 'log off: nothing is switched')
end

------------------------------------------------------------------------
-- "!keys" in chat.
------------------------------------------------------------------------
local LINK = '|cffa335ee|Hkeystone:180653:1:12:0|h[Keystone]|h|r'

local function BootKeys(features)
	local ns = H.boot()
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	world = { link = LINK, locked = false, sent = {} }
	NUM_BAG_SLOTS = 0
	C_Container = {
		GetContainerNumSlots = function() return 1 end,
		GetContainerItemInfo = function() return { hyperlink = world.link } end,
	}
	C_ChallengeMode = {}
	C_MythicPlus = {
		GetOwnedKeystoneChallengeMapID = function() return 1 end,
		GetOwnedKeystoneLevel = function() return 12 end,
	}
	C_ChatInfo = {
		InChatMessagingLockdown = function() return world.locked end,
		SendChatMessage = function(message, channel) world.sent[#world.sent + 1] = { message, channel } end,
	}
	IsInGroup = function() return true end
	H.load('Keystone.lua')
	H.fire('PLAYER_LOGIN')
	return ns
end

do
	BootKeys()
	H.fire('CHAT_MSG_PARTY', 'hello there')
	H.equal(#world.sent, 0, 'keys: ordinary chat is not answered')
	H.fire('CHAT_MSG_PARTY', ' !Keys ')
	H.check(#world.sent == 1 and world.sent[1][1] == LINK and world.sent[1][2] == 'PARTY', 'keys: !keys in party chat is answered with the keystone')
	H.fire('CHAT_MSG_PARTY_LEADER', '!keys')
	H.equal(#world.sent, 1, 'keys: several askers at once get one answer')
	H.now = H.now + 11
	H.fire('CHAT_MSG_PARTY_LEADER', '!key')
	H.equal(#world.sent, 2, 'keys: a later !key from the leader is answered again')
	H.fire('CHAT_MSG_GUILD', '!keys')
	H.check(#world.sent == 3 and world.sent[3][2] == 'GUILD', 'keys: guild chat is answered in guild chat')
end

do
	BootKeys()
	world.locked = true
	H.fire('CHAT_MSG_PARTY', '!keys')
	H.equal(#world.sent, 0, 'keys: nothing is sent while the game blocks addon chat')
	world.locked = false
	H.secret = { ['!keys'] = true }
	local ok = pcall(H.fire, 'CHAT_MSG_PARTY', '!keys')
	H.check(ok and #world.sent == 0, 'keys: a hidden chat text is left alone')
	H.secret = nil
	world.link = nil
	H.fire('CHAT_MSG_PARTY', '!keys')
	H.equal(#world.sent, 0, 'keys: without a keystone there is no answer')
	H.noErrors()
end

do
	BootKeys({ answerKeys = false })
	H.fire('CHAT_MSG_PARTY', '!keys')
	H.equal(#world.sent, 0, 'keys off: no answer')
end

------------------------------------------------------------------------
-- The text on joining a premade group.
------------------------------------------------------------------------
local function BootJoined(features)
	local ns = H.boot()
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	world = { activities = { 501 } }
	SlimARK_Joined = nil -- a named frame of an earlier environment
	C_SpecializationInfo = { GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return 70, nil, nil, nil, 'DAMAGER' end }
	C_Map = { GetBestMapForUnit = function() return 1 end }
	GetLFGRoles = function() return false end
	SetLFGRoles = function() end
	C_LFGList = {
		GetSearchResultInfo = function() return world.activities and { activityIDs = world.activities } end,
		GetActivityFullName = function(id) return id == 501 and 'Windrunner Spire (Mythic Keystone)' or nil end,
	}
	H.load('Role.lua')
	H.load('Quality.lua')
	return ns
end

do
	BootJoined()
	H.fire('LFG_LIST_JOINED_GROUP', 7, '+12 chill')
	local frame = SlimARK_Joined
	H.check(frame and frame:IsShown(), 'joined: the text shows when you join a group')
	H.equal(frame.Name:GetText(), 'Windrunner Spire (Mythic Keystone)', 'joined: the activity name in large text')
	H.equal(frame.Title:GetText(), '+12 chill', 'joined: the group title under it, as written')
	H.runTimers(5)
	H.check(frame:IsShown(), 'joined: it stays for a few seconds')
	H.runTimers(2)
	H.check(not frame:IsShown(), 'joined: then it goes away')

	-- A second join while the first text is up keeps the text for its own full time.
	H.fire('LFG_LIST_JOINED_GROUP', 7, 'first')
	H.runTimers(4)
	H.fire('LFG_LIST_JOINED_GROUP', 7, 'second')
	H.runTimers(3)
	H.check(frame:IsShown() and frame.Title:GetText() == 'second', 'joined: a new join restarts the time')
	H.runTimers(4)
	H.check(not frame:IsShown(), 'joined: and it still goes away')

	-- A hidden title is shown as it is; an unknown activity leaves the name empty.
	H.secret = { ['secret title'] = true }
	world.activities = nil
	local ok = pcall(H.fire, 'LFG_LIST_JOINED_GROUP', 7, 'secret title')
	H.check(ok and frame:IsShown() and frame.Title:GetText() == 'secret title' and frame.Name:GetText() == '',
		'joined: a hidden title is passed on untested')
	H.secret = nil
	H.noErrors()
end

do
	BootJoined({ joinedText = false })
	H.fire('LFG_LIST_JOINED_GROUP', 7, '+12 chill')
	H.check(SlimARK_Joined == nil, 'joined off: nothing is made')
end

------------------------------------------------------------------------
-- Quick focus: the binding in the world.
------------------------------------------------------------------------
local function BootFocus(tweak)
	local ns = H.boot()
	world = { bindings = {} }
	SlimARK_QuickFocus = nil -- a named frame of an earlier environment
	SetOverrideBindingClick = function(owner, priority, key, name) world.bindings[#world.bindings + 1] = { owner, priority, key, name } end
	if tweak then tweak(ns) end
	H.load('QuickFocus.lua')
	H.fire('PLAYER_LOGIN')
	return ns
end

do
	BootFocus()
	local button = SlimARK_QuickFocus
	H.check(button ~= nil, 'focus: the secure button exists')
	H.equal(button:GetAttribute('macrotext'), '/focus mouseover', 'focus: it focuses what the mouse is over')
	H.equal(button:GetAttribute('*type*'), 'macro', 'focus: for any modifier and button')
	local bind = world.bindings[1]
	H.check(bind and bind[3] == 'SHIFT-BUTTON1' and bind[4] == 'SlimARK_QuickFocus', 'focus: Shift + left click is bound to it')
end

do
	BootFocus(function(ns) ns.C.quickFocus.modifier = 'CTRL' end)
	H.equal(world.bindings[1] and world.bindings[1][3], 'CTRL-BUTTON1', 'focus: the chosen modifier is bound')
end

do
	-- Logging in during combat: the binding waits for the end of the fight.
	BootFocus(function() H.combat = true end)
	H.equal(#world.bindings, 0, 'focus: no binding is set in combat')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(#world.bindings, 1, 'focus: it is set when combat ends')
end

do
	BootFocus(function(ns) ns.C.features.quickFocus = false end)
	H.check(SlimARK_QuickFocus == nil and #world.bindings == 0, 'focus off: no button, no binding')
end

do
	BootFocus(function(ns) ns.C.quickFocus.modifier = 'NONE' end)
	H.check(SlimARK_QuickFocus == nil and #world.bindings == 0, 'focus: an unknown modifier binds nothing')
end

H.done()
