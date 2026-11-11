local H = dofile('tests/codex/lib/runtime.lua')
local world

local function Boot(flavor)
	local ns = H.boot(flavor)
	world = { active = false, elapsed = 12, done = true }
	C_ChallengeMode = {
		IsChallengeModeActive = function() return world.active end,
		GetActiveChallengeMapID = function() return 1 end,
		GetActiveKeystoneInfo = function() return 10 end,
		GetMapUIInfo = function() return 'Dungeon', nil, 1800 end,
		GetDeathCount = function() return 0 end,
	}
	C_ScenarioInfo = {
		GetScenarioStepInfo = function() return { numCriteria = 2 } end,
		GetCriteriaInfo = function(i) return { description = 'Boss ' .. i, completed = i == 1 and world.done } end,
	}
	GetWorldElapsedTimers = function() return 1 end
	GetWorldElapsedTime = function() return 'Challenge', world.elapsed, Enum.WorldElapsedTimerTypes.ChallengeMode end
	ObjectiveTrackerFrame = H.NewFrame('Frame')
	ns.Register = function() end -- positioning is independent of the run state
	H.load('MythicPlus.lua')
	H.fire('PLAYER_LOGIN')
	return ns
end

local function HasText(text)
	for _, f in ipairs(H.frames) do if f:GetText() == text then return true end end
	return false
end

do
	local ns = Boot()
	ns.MythicPlusPreview(true)
	local preview = H.tickers[#H.tickers]
	assert(preview.interval == 1 and not preview.cancelled)
	world.active = true
	H.fire('CHALLENGE_MODE_START')
	H.runTimers(0.5)
	assert(preview.cancelled, 'A real run cancels the preview clock')
	local panel = SlimARK_MythicPlus
	assert(panel.Time:GetText() == '0:12')
	assert(HasText('✓'), 'A completed boss with an unknown time has a checkmark')
	assert(not HasText('14:33'), 'The preview cannot overwrite the real run')
	ns.MythicPlusPreview(false)
	assert(panel:IsShown(), 'Ending test mode must leave the real run visible')
	H.fire('CHALLENGE_MODE_RESET')
	for _, ticker in ipairs(H.tickers) do assert(ticker.cancelled) end
	H.noErrors()
end

do
	Boot()
	world.active, world.elapsed = true, 1200
	H.fire('PLAYER_ENTERING_WORLD')
	H.runTimers(1)
	-- Only the timer says 20:00. A boss killed before reload gets the unknown-time checkmark.
	local times = 0
	for _, f in ipairs(H.frames) do if f:GetText() == '20:00' then times = times + 1 end end
	assert(times == 1 and HasText('✓'), 'Reload must not fabricate old boss times')
	world.done = false
	H.fire('SCENARIO_CRITERIA_UPDATE')
	world.done, world.elapsed = true, 1300
	H.fire('SCENARIO_CRITERIA_UPDATE')
	assert(HasText('21:40'), 'An observed completion transition gets a kill time')
	world.elapsed = 1400
	H.fire('SCENARIO_CRITERIA_UPDATE')
	assert(HasText('21:40') and not HasText('23:20'), 'Later refreshes preserve the observed time')
	H.noErrors()
end

do
	local ns = Boot('forever')
	ns.MythicPlusPreview(true)
	assert(#H.tickers == 0, 'Forever does not create a Mythic+ panel or timer, even with the namespace')
	H.noErrors()
end
