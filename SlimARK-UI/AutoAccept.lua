local _, ns = ...
local C = ns.C

-- 3.0 (28): accepts on its own a group invite from a friend or a guild member, a summon and a
-- resurrection, each with its own switch, only out of combat. A summon that comes in a fight is
-- taken when the fight ends; a resurrection during a fight (or from someone fighting) is left to
-- you. An invite that would take you out of a queue, or comes with a quest session, is left to you.

local function Readable(v)
	return not issecretvalue(v) and v ~= nil
end

local function Fighting(unit)
	local fighting = UnitAffectingCombat(unit)
	return Readable(fighting) and fighting == true
end

-- A Battle.net friend, a character friend or a guild member.
local function Known(guid)
	if not Readable(guid) or guid == '' then return false end
	local function yes(v) return Readable(v) and v ~= false end
	if C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID and yes(C_BattleNet.GetGameAccountInfoByGUID(guid)) then return true end
	if C_FriendList and C_FriendList.IsFriend and yes(C_FriendList.IsFriend(guid)) then return true end
	if IsGuildMember and yes(IsGuildMember(guid)) then return true end
	return false
end
ns.AutoAcceptKnown = Known

------------------------------------------------------------------------
-- Group invites.
------------------------------------------------------------------------
local watcher, hidePopup

-- Blizzard's invite pop-up declines the group when it is hidden before you are in, so it goes once
-- the roster says you joined.
local function HidePopupWhenJoined()
	if not watcher then
		watcher = CreateFrame('Frame')
		watcher:SetScript('OnEvent', function(self)
			self:UnregisterEvent('GROUP_ROSTER_UPDATE')
			if not hidePopup then return end
			hidePopup = false
			StaticPopup_Hide('PARTY_INVITE')
			if LFGInvitePopup and StaticPopupSpecial_Hide then StaticPopupSpecial_Hide(LFGInvitePopup) end
		end)
	end
	hidePopup = true
	watcher:RegisterEvent('GROUP_ROSTER_UPDATE')
end

local function OnInvite(_, name, tank, healer, damage, _, _, guid, questSession)
	if InCombatLockdown() or IsInGroup() then return end
	if issecretvalue(questSession) or questSession == true then return end
	if WillAcceptInviteRemoveQueues and WillAcceptInviteRemoveQueues() then return end
	if not Known(guid) then return end
	local function flag(v) return Readable(v) and v == true end
	if flag(tank) or flag(healer) or flag(damage) then
		-- The inviting group is queued and asks for a role: your spec's role, when it is one they take.
		local _, role = ns.SpecInfo()
		local t, h, d = role == 'TANK' and flag(tank), role == 'HEALER' and flag(healer), role == 'DAMAGER' and flag(damage)
		if not (t or h or d) then return end
		AcceptGroup(t, h, d)
	else
		AcceptGroup()
	end
	HidePopupWhenJoined()
	if Readable(name) then ns.Print('Accepted the group invite from ' .. name .. '.') end
end
ns.OnPartyInvite = OnInvite

------------------------------------------------------------------------
-- Summons.
------------------------------------------------------------------------
local summonWaiting = false

local function TakeSummon()
	local info = C_SummonInfo
	if not info or not info.GetSummonConfirmTimeLeft or (info.GetSummonConfirmTimeLeft() or 0) <= 0 then
		summonWaiting = false
		return
	end
	if InCombatLockdown() or Fighting('player') or (PlayerCanTeleport and not PlayerCanTeleport()) then
		summonWaiting = true
		return
	end
	summonWaiting = false
	info.ConfirmSummon()
	StaticPopup_Hide('CONFIRM_SUMMON')
end
ns.TakeSummon = TakeSummon

-- Only the plain summon: a scenario summon and the one that skips the starting area stay for you.
local function OnSummon(_, reason, skipStart)
	if skipStart == true then return end
	if Readable(reason) and Enum.SummonReason and reason == Enum.SummonReason.Scenario then return end
	-- The game's window comes with the same event: the summon is taken a moment later.
	C_Timer.After(0.5, TakeSummon)
end

------------------------------------------------------------------------
-- Resurrections.
------------------------------------------------------------------------
local function TakeRes()
	if not UnitIsDeadOrGhost('player') or InCombatLockdown() then return end
	AcceptResurrect()
	StaticPopup_Hide('RESURRECT')
	StaticPopup_Hide('RESURRECT_NO_SICKNESS')
	StaticPopup_Hide('RESURRECT_NO_TIMER')
end

local function OnRes(_, reviver)
	if InCombatLockdown() or (IsEncounterInProgress and IsEncounterInProgress()) then return end
	if Readable(reviver) and Fighting(reviver) then return end
	-- After many deaths the game holds the answer back for a while: the same wait here.
	local delay = GetCorpseRecoveryDelay and GetCorpseRecoveryDelay() or 0
	if Readable(delay) and delay > 0 then
		C_Timer.After(delay + 0.2, TakeRes)
	else
		TakeRes()
	end
end
ns.OnResRequest = OnRes

ns.On('PLAYER_LOGIN', function()
	local f = C.features
	if f.acceptInvites then ns.On('PARTY_INVITE_REQUEST', OnInvite) end
	if f.acceptSummons then
		ns.On('CONFIRM_SUMMON', OnSummon)
		ns.On('CANCEL_SUMMON', function() summonWaiting = false end)
		ns.On('PLAYER_REGEN_ENABLED', function()
			if summonWaiting then TakeSummon() end
		end)
	end
	if f.acceptRes then ns.On('RESURRECT_REQUEST', OnRes) end
end)
