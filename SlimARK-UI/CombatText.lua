local addonName, ns = ...
local C = ns.C

-- The game's own floating combat text in the SlimARK font. The game reads DAMAGE_TEXT_FONT once,
-- while the UI loads, so switching it shows after a reload.
ns.On('ADDON_LOADED', function(_, name)
	if name == addonName and C.modules.combatfont then DAMAGE_TEXT_FONT = ns.FONT end
end)

-- Until 2.0.5 SlimARK had its own combat text and switched parts of the game's off while it was on.
-- Whoever had it on gets the game's settings back once, out of combat.
local function RestoreGameNumbers()
	local saved = ns.DB and ns.DB.combatTextCVars
	if not saved or InCombatLockdown() then return end
	for cvar, value in pairs(saved) do
		if GetCVar(cvar) ~= nil and GetCVar(cvar) ~= value then SetCVar(cvar, value) end
	end
	ns.DB.combatTextCVars = nil
end
ns.On('PLAYER_LOGIN', RestoreGameNumbers)
ns.On('PLAYER_REGEN_ENABLED', RestoreGameNumbers)
