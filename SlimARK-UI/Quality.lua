local _, ns = ...

-- Cutscenes: what you have seen once is skipped on its own next time.
-- Movies are identified by their ID, in-game cutscenes by the map and zone
-- name, because these have no ID of their own.
ns.On('PLAY_MOVIE', function(_, movieID)
	if not ns.DB or not movieID or not ns.C.features.skipMovies then return end
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
	if not ns.DB or not ns.C.features.skipCinematics then return end
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
-- role check send this too. Only for whoever uses one of those two: with both off, the roles
-- picked by hand (a tank queueing as tank and DPS) stay as they are.
local function SyncLFGRoles()
	local features = ns.C.features
	if not (features.autoRoleCheck or features.oneClickSignup) then return end
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
	if not ns.C.features.autoRoleCheck then return end
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
	if premadeHooked or not ns.C.features.oneClickSignup or not LFGListApplicationDialog or not LFGListSearchEntry_OnClick then return end
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

-- Joining a premade group: the activity (the dungeon) in large text for a few seconds, with
-- the group's title under it as its leader wrote it. The game has no field for the key level
-- and the title can only be shown, not read, so the level is seen when the title has it.
local JOINED_SECONDS = 6
local joined

local function JoinedFrame()
	if joined then return joined end
	joined = CreateFrame('Frame', 'SlimARK_Joined', UIParent)
	joined:SetSize(900, 110)
	joined:SetScale(ns.Scale())
	joined:SetPoint('TOP', UIParent, 'TOP', 0, -340)
	joined:SetFrameStrata('HIGH')
	joined:Hide()
	local head = ns.Text(joined, 16, 'CENTER')
	head:SetPoint('TOP')
	head:SetText('YOU JOINED')
	local c = ns.C.colors.classPower
	head:SetTextColor(c[1], c[2], c[3])
	joined.Name = ns.Text(joined, 44, 'CENTER')
	joined.Name:SetPoint('TOP', head, 'BOTTOM', 0, -8)
	joined.Name:SetWidth(900)
	joined.Title = ns.Text(joined, 24, 'CENTER')
	joined.Title:SetPoint('TOP', joined.Name, 'BOTTOM', 0, -8)
	joined.Title:SetWidth(900)
	joined.Title:SetTextColor(0.84, 0.84, 0.86)
	return joined
end

-- 3.0 (3): a teleport button under the text when you know the dungeon's teleport. It is a secure
-- spell button, so it is made, changed and shown out of combat only, and it sits on UIParent (not
-- on the text) so hiding the text never touches it. While it shows, the text stays longer; the
-- click, combat, entering an instance and leaving the group take it away.
local TELEPORT_SECONDS = 30
local teleport

local function HideTeleport()
	if teleport and not InCombatLockdown() then teleport:Hide() end
end

local function TeleportButton()
	if teleport then return teleport end
	teleport = CreateFrame('Button', 'SlimARK_JoinedTeleport', UIParent, 'SecureActionButtonTemplate')
	teleport:SetSize(440, 40)
	teleport:SetFrameStrata('HIGH')
	teleport:RegisterForClicks('AnyUp')
	-- Acts on the release it is registered for, whatever the "cast on key down" setting says.
	teleport:SetAttribute('useOnKeyDown', false)
	teleport:SetAttribute('type', 'spell')
	local c = ns.C.colors.classPower
	local bg = teleport:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(c[1], c[2], c[3], 1)
	ns.Outline(teleport)
	local hl = teleport:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.18)
	-- Dark text on the gold button, without the outline of the other texts.
	teleport.text = teleport:CreateFontString(nil, 'OVERLAY')
	ns.SetFont(teleport.text, 19, '')
	teleport.text:SetTextColor(0.1, 0.1, 0.1)
	teleport.text:SetPoint('CENTER')
	teleport:HookScript('PostClick', HideTeleport)
	teleport:Hide()
	-- Entering combat: the button goes while that is still allowed (this event comes before the lockdown).
	ns.On('PLAYER_REGEN_DISABLED', function() if teleport:IsShown() then teleport:Hide() end end)
	ns.On('GROUP_LEFT', HideTeleport)
	ns.On('PLAYER_ENTERING_WORLD', function()
		if IsInInstance() then HideTeleport() end
	end)
	return teleport
end

-- The instance map of the activity, matched to a learned teleport. Any hidden value stops it quietly.
local function JoinedTeleport(activity)
	if ns.isForever or not ns.C.features.joinTeleport or not activity or not ns.TeleportForInstance
		or not C_LFGList.GetActivityInfoTable then return end
	local ok, spellID, challengeID = pcall(function()
		local info = C_LFGList.GetActivityInfoTable(activity)
		local mapID = info and info.mapID
		if mapID == nil or issecretvalue(mapID) then return end
		return ns.TeleportForInstance(mapID)
	end)
	if ok then return spellID, challengeID end
end

local function ShowTeleport(activity)
	local spellID, challengeID = JoinedTeleport(activity)
	if not spellID or InCombatLockdown() then
		HideTeleport()
		return false
	end
	local b = TeleportButton()
	b:SetAttribute('spell', spellID)
	local dungeon = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(challengeID)
	b.text:SetText('Teleport to ' .. (dungeon or 'the dungeon'))
	b:SetScale(ns.Scale())
	b:ClearAllPoints()
	b:SetPoint('TOP', UIParent, 'TOP', 0, -470)
	b:Show()
	return true
end

local joinedShown = 0
ns.On('LFG_LIST_JOINED_GROUP', function(_, resultID, groupName)
	if not ns.C.features.joinedText or not C_LFGList or not C_LFGList.GetSearchResultInfo then return end
	local info = resultID and C_LFGList.GetSearchResultInfo(resultID)
	local activities = info and info.activityIDs
	local activity = activities and not issecretvalue(activities) and activities[1]
	local name = activity and C_LFGList.GetActivityFullName and C_LFGList.GetActivityFullName(activity)
	-- The title can be a hidden value: it is handed to the text as it is, never tested.
	local hasTitle = issecretvalue(groupName) or (groupName ~= nil and groupName ~= '')
	if not name and not hasTitle then return end
	local frame = JoinedFrame()
	frame.Name:SetText(name or '')
	if hasTitle then frame.Title:SetText(groupName) else frame.Title:SetText('') end
	frame:Show()
	joinedShown = joinedShown + 1
	local shown = joinedShown
	local seconds = ShowTeleport(activity) and TELEPORT_SECONDS or JOINED_SECONDS
	C_Timer.After(seconds, function()
		if shown == joinedShown then
			frame:Hide()
			HideTeleport()
		end
	end)
end)
