local _, ns = ...
local C = ns.C

-- 3.0 (53) Screenshots: one when a Mythic+ key is timed, when a boss dies, when a new achievement is
-- earned, each by its own switch (all off by default). The picture is taken a moment later, so the
-- game's banner or toast is on it; several reasons at once give one picture. A switch that is off
-- registers nothing.
local waiting = false

local function Shoot()
	if waiting or not Screenshot then return end
	waiting = true
	C_Timer.After(1, function()
		waiting = false
		Screenshot()
	end)
end

ns.On('PLAYER_LOGIN', function()
	local f = C.features
	if f.shotKey and not ns.isForever and C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo then
		ns.On('CHALLENGE_MODE_COMPLETED', function()
			local info = C_ChallengeMode.GetChallengeCompletionInfo()
			if info and info.onTime and not info.practiceRun then Shoot() end
		end)
	end
	if f.shotKill then ns.On('BOSS_KILL', Shoot) end
	if f.shotAchievement then
		ns.On('ACHIEVEMENT_EARNED', function(_, _, alreadyEarnedOnAccount)
			if not alreadyEarnedOnAccount then Shoot() end
		end)
	end
end)
