local _, ns = ...
local C = ns.C

-- Combat logging switches on by itself when a Mythic+ key starts or you enter a raid, and off
-- again when you leave. Only a log this module started is stopped: one you started with
-- /combatlog stays on. The mark is kept with the character, so a reload in a run does not lose it.
local function Wanted()
	local _, kind = GetInstanceInfo()
	if kind == 'raid' then return true end
	local mode = C_ChallengeMode
	return mode and mode.IsChallengeModeActive and mode.IsChallengeModeActive() or false
end

local function Logging()
	if C_ChatInfo and C_ChatInfo.IsLoggingCombat then return C_ChatInfo.IsLoggingCombat() end
	return LoggingCombat()
end

-- want: true when the event itself says a key has started.
local function Sync(want)
	if not C.features.autoCombatLog or not ns.CharDB or not LoggingCombat then return end
	if want == nil then want = Wanted() end
	local logging = Logging()
	if want and not logging then
		-- Log sites need the advanced log. The setting changes out of combat only.
		if GetCVar('advancedCombatLogging') == '0' and not InCombatLockdown() then
			SetCVar('advancedCombatLogging', '1')
			ns.Print('Advanced Combat Logging switched on (System > Network).')
		end
		-- The game refuses the call when it comes too often (it answers nil): the next event tries again.
		if LoggingCombat(true) == nil then return end
		ns.CharDB.autoLog = true
		ns.Print('Combat logging is on.')
	elseif not want and logging and ns.CharDB.autoLog then
		if LoggingCombat(false) == nil then return end
		ns.CharDB.autoLog = nil
		ns.Print('Combat logging is off.')
	elseif not logging then
		ns.CharDB.autoLog = nil
	end
end

ns.On('CHALLENGE_MODE_START', function() Sync(true) end)
ns.On('PLAYER_ENTERING_WORLD', function() Sync() end)
