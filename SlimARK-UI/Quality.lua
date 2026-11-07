local _, ns = ...

-- Cutscenes: what you have seen once is skipped on its own next time.
-- Movies are identified by their ID, in-game cutscenes by the map and zone
-- name, because these have no ID of their own.
ns.On('PLAY_MOVIE', function(_, movieID)
	if not ns.DB or not movieID then return end
	if ns.DB.seenMovies[movieID] then
		-- MovieFrame starts the movie on the same event, we stop it afterwards.
		C_Timer.After(0, function()
			if MovieFrame and MovieFrame:IsShown() and MovieFrame.FinishMovie then MovieFrame:FinishMovie() end
		end)
	else
		ns.DB.seenMovies[movieID] = true
	end
end)

local function CinematicKey()
	local map = C_Map.GetBestMapForUnit('player') or 0
	return map .. ':' .. (GetSubZoneText() or '') .. ':' .. (GetZoneText() or '')
end

ns.On('CINEMATIC_START', function(_, canBeCancelled)
	if not ns.DB then return end
	local scene = not canBeCancelled and IsInCinematicScene and IsInCinematicScene()
	-- We do not touch the vehicle cutscene: it could only be cancelled after leaving the vehicle.
	if not canBeCancelled and not scene then return end
	local key = CinematicKey()
	if not ns.DB.seenCinematics[key] then
		ns.DB.seenCinematics[key] = true
		return
	end
	C_Timer.After(0, function()
		if canBeCancelled then
			StopCinematic()
		elseif CanCancelScene() then
			CancelScene()
		end
	end)
end)

-- The role by spec: tank, heal or dps.
local function MyRoles()
	local _, role = ns.SpecInfo()
	return role == 'TANK', role == 'HEALER', role == 'DAMAGER'
end

-- The Group Finder ticks the role by spec, so the application and the
-- role check send this too.
local function SyncLFGRoles()
	if InCombatLockdown() then return end
	local tank, healer, dps = MyRoles()
	if not (tank or healer or dps) then return end
	local leader = GetLFGRoles()
	SetLFGRoles(leader, tank, healer, dps)
end
ns.On('PLAYER_LOGIN', SyncLFGRoles)
ns.On('PLAYER_SPECIALIZATION_CHANGED', function(_, unit)
	if unit == 'player' then SyncLFGRoles() end
end)

-- Role check: accepts on its own with the role by spec.
ns.On('LFG_ROLE_CHECK_SHOW', function()
	C_Timer.After(0, function()
		local tank, healer, dps = MyRoles()
		if not (tank or healer or dps) then return end
		local _, _, _, _, _, isBG = GetLFGRoleUpdate()
		if isBG then
			SetPVPRoles(tank, healer, dps)
		else
			if LFDPopupCheckRoleSelectionValid and not LFDPopupCheckRoleSelectionValid(tank, healer, dps) then return end
			SetLFGRoles(GetLFGRoles(), tank, healer, dps)
		end
		if CompleteLFGRoleCheck(true) and LFDRoleCheckPopup then
			StaticPopupSpecial_Hide(LFDRoleCheckPopup)
		end
	end)
end)

-- Premade group: clicking on the listing applies at once, the role window
-- sends the application without confirmation. It starts from the click, so the
-- game allows this application.
local premadeHooked = false
local function HookPremade()
	if premadeHooked or not LFGListApplicationDialog or not LFGListSearchEntry_OnClick then return end
	premadeHooked = true

	hooksecurefunc('LFGListSearchEntry_OnClick', function(entry, button)
		if button == 'RightButton' then return end
		local panel = LFGListFrame and LFGListFrame.SearchPanel
		if not panel or panel.selectedResult ~= entry.resultID then return end
		if panel.SignUpButton and panel.SignUpButton:IsEnabled() then
			LFGListSearchPanel_SignUp(panel)
		end
	end)

	LFGListApplicationDialog:HookScript('OnShow', function(dialog)
		local signUp = dialog.SignUpButton
		if signUp and signUp:IsEnabled() then
			signUp:Click()
		end
	end)
end

ns.On('ADDON_LOADED', function(_, name)
	if name == 'Blizzard_GroupFinder' then HookPremade() end
end)
ns.On('PLAYER_LOGIN', HookPremade)
