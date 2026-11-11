-- H3: cutscenes (audit F13), Group Finder roles (audit F17) and the auto quest details (audit
-- F16). Run from the repository root:
--   lua5.1 tests/claude/automation-quality-quests.lua
local H = dofile('tests/claude/lib/helpers.lua')

local world

local function Boot(features)
	local ns = H.setup()
	world = { stops = 0, finished = 0, roles = {}, setRoles = 0, accepted = 0, acknowledged = 0,
		trivial = false, autoAccept = false, shift = false, questID = 123 }
	_G.C_Map = { GetBestMapForUnit = function() return 2393 end }
	_G.GetSubZoneText = function() return 'Sunwell Plateau' end
	_G.GetZoneText = function() return 'Isle of Quel\'Danas' end
	_G.StopCinematic = function() world.stops = world.stops + 1 end
	_G.IsInCinematicScene = function() return false end
	_G.CanCancelScene = function() return false end
	_G.MovieFrame = H.NewFrame('Frame', 'MovieFrame', UIParent)
	function MovieFrame:FinishMovie() world.finished = world.finished + 1 end
	_G.GetLFGRoles = function() return false, true, true, true end
	_G.SetLFGRoles = function(leader, tank, healer, dps)
		world.setRoles = world.setRoles + 1
		world.roles = { leader, tank, healer, dps }
	end
	_G.IsShiftKeyDown = function() return world.shift end
	_G.QuestGetAutoAccept = function() return world.autoAccept end
	_G.AcknowledgeAutoAcceptQuest = function() world.acknowledged = world.acknowledged + 1 end
	_G.AcceptQuest = function() world.accepted = world.accepted + 1 end
	_G.GetQuestID = function() return world.questID end
	_G.C_QuestLog = { IsQuestTrivial = function(id) return id == world.questID and world.trivial end }
	_G.UnitExists = function() return false end
	H.load('Config.lua')
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	H.load('Core.lua')
	ns.SpecInfo = function() return 73, 'TANK' end
	H.load('Quality.lua')
	H.load('AutoQuest.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

------------------------------------------------------------------------
-- F13: an in-game cutscene is not skipped because one played in the same place before.
------------------------------------------------------------------------
do
	Boot()
	H.fire('CINEMATIC_START', true)
	H.runTimers(0)
	H.fire('CINEMATIC_START', true) -- another scene of the quest chain, same spot
	H.runTimers(0)
	H.equal(world.stops, 0, 'F13 a second cutscene in the same place plays (default settings)')

	-- Movies have an ID: a seen movie is still skipped.
	MovieFrame:Show()
	H.fire('PLAY_MOVIE', 42)
	H.runTimers(0)
	H.fire('PLAY_MOVIE', 42)
	H.runTimers(0)
	H.equal(world.finished, 1, 'F13 a movie seen before is still skipped by its ID')
	H.fire('PLAY_MOVIE', 43)
	H.runTimers(0)
	H.equal(world.finished, 1, 'F13 a new movie plays')
end

do
	-- The skip by place only as an option chosen on purpose.
	Boot({ skipCinematicsByPlace = true })
	H.fire('CINEMATIC_START', true)
	H.runTimers(0)
	H.fire('CINEMATIC_START', true)
	H.runTimers(0)
	H.equal(world.stops, 1, 'F13 the skip by place still works when chosen')
end

------------------------------------------------------------------------
-- F17: roles picked by hand stay when both role features are off.
------------------------------------------------------------------------
do
	Boot({ autoRoleCheck = false, oneClickSignup = false })
	H.equal(world.setRoles, 0, 'F17 both off: the login does not touch the roles')
	H.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
	H.equal(world.setRoles, 0, 'F17 both off: a spec change does not touch them either')

	Boot({ autoRoleCheck = true, oneClickSignup = false })
	H.equal(world.setRoles, 1, 'F17 role check on: the spec\'s role is set at login')
	H.check(world.roles[2] == true and world.roles[3] == false and world.roles[4] == false,
		'F17 role check on: tank spec gives tank only')

	Boot({ autoRoleCheck = false, oneClickSignup = true })
	H.equal(world.setRoles, 1, 'F17 one-click sign-up on: the spec\'s role is set at login')
end

------------------------------------------------------------------------
-- F16: a grey quest whose details open directly is not accepted.
------------------------------------------------------------------------
do
	Boot()
	world.trivial = true
	H.fire('QUEST_DETAIL')
	H.equal(world.accepted, 0, 'F16 a grey quest opened directly is not accepted')

	world.trivial = false
	H.fire('QUEST_DETAIL')
	H.equal(world.accepted, 1, 'F16 a normal quest opened directly is accepted')

	-- The game accepted it already: only acknowledged, grey or not.
	world.trivial, world.autoAccept = true, true
	H.fire('QUEST_DETAIL')
	H.check(world.acknowledged == 1 and world.accepted == 1, 'F16 an auto-accepted quest is only acknowledged')

	-- Shift pauses everything.
	world.trivial, world.autoAccept, world.shift = false, false, true
	H.fire('QUEST_DETAIL')
	H.equal(world.accepted, 1, 'F16 Shift still pauses it')
end

H.done()
