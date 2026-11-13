local _, ns = ...
local C = ns.C

------------------------------------------------------------------------
-- 4: a strip at the bottom of the party, raid and healer grid frames: green while the member's
-- interrupt is ready, white while it fills, with the seconds left beside it.
--
-- Who interrupted is hidden in instances (their casts are hidden values), but the game's own
-- damage meter keeps an interrupt count per member, and its rows carry the class, the spec icon
-- and "it is you" as plain values. A landed kick changes the meter in one of three ways that name
-- the kicker for sure: their row appears (their first kick of the fight), their row moves up past
-- another one (their count passed it), or their list of kicked spells grows (read by their group
-- GUID, the list length is plain). Anything else names nobody: a kick that changes none of these
-- is not seen, and a kick that misses never is. Your own kicks are your own casts.
--
-- The cooldown is the spec's base value from the table below (talents are not read). The kicker's
-- spec comes from their meter row, from the game's inspect data out of combat, or from their role.
------------------------------------------------------------------------

-- Cooldown of each spec's interrupt in seconds (12.1 base values). false: the spec has none.
local KICK_CD = {
	[250] = 15, [251] = 15, [252] = 15,      -- Death Knight: Mind Freeze
	[577] = 15, [581] = 15, [1480] = 15,     -- Demon Hunter: Disrupt
	[102] = 60, [103] = 15, [104] = 15, [105] = false, -- Druid: Solar Beam, Skull Bash
	[1467] = 20, [1468] = false, [1473] = 20, -- Evoker: Quell
	[253] = 24, [254] = 24, [255] = 15,      -- Hunter: Counter Shot, Muzzle
	[62] = 25, [63] = 25, [64] = 25,         -- Mage: Counterspell
	[268] = 15, [269] = 15, [270] = false,   -- Monk: Spear Hand Strike
	[65] = false, [66] = 15, [70] = 15,      -- Paladin: Rebuke
	[256] = false, [257] = false, [258] = 30, -- Priest: Silence
	[259] = 15, [260] = 15, [261] = 15,      -- Rogue: Kick
	[262] = 12, [263] = 12, [264] = 30,      -- Shaman: Wind Shear
	[265] = 24, [266] = 30, [267] = 24,      -- Warlock: Spell Lock, Axe Toss (the demon's)
	[71] = 15, [72] = 15, [73] = 15,         -- Warrior: Pummel
}

-- A member whose spec is not known yet counts as the usual spec of their class for their role.
local USUAL = {
	HEALER = { DRUID = 105, EVOKER = 1468, MONK = 270, PALADIN = 65, PRIEST = 257, SHAMAN = 264 },
	TANK = { DEATHKNIGHT = 250, DEMONHUNTER = 581, DRUID = 104, MONK = 268, PALADIN = 66, WARRIOR = 73 },
	DAMAGER = { DEATHKNIGHT = 251, DEMONHUNTER = 577, DRUID = 103, EVOKER = 1467, HUNTER = 253, MAGE = 62,
		MONK = 269, PALADIN = 70, PRIEST = 258, ROGUE = 259, SHAMAN = 262, WARLOCK = 265, WARRIOR = 71 },
}

-- Avenger's Shield also interrupts, but it is not the paladin's kick.
local NOT_A_KICK = { [31935] = true }

local members = {}   -- GUID -> { unit, pet, class, role, spec, spells, petSpells }
local kicks = {}     -- GUID -> { duration, token } while the interrupt fills
local strips = {}
local rowsBefore = {}
local playerGUID
local formatter
local started = false
local refreshQueued, rosterQueued = false, false
local token = 0
local INTERRUPTS, CURRENT

local function Plain(value)
	if value == nil or issecretvalue(value) then return nil end
	return value
end

local function Formatter()
	if formatter or not C_StringUtil then return formatter end
	formatter = C_StringUtil.CreateSecondsFormatter()
	formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
	formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
	return formatter
end

-- The spec of a meter row's icon: icon -> spec ID per class, built once.
local specOfIcon
local function SpecOfIcon(class, icon)
	if not specOfIcon then
		specOfIcon = {}
		if GetSpecializationInfoByID then
			for spec in pairs(KICK_CD) do
				local _, _, _, specIcon, _, specClass = GetSpecializationInfoByID(spec)
				if specIcon and specClass then
					specOfIcon[specClass] = specOfIcon[specClass] or {}
					specOfIcon[specClass][specIcon] = spec
				end
			end
		end
	end
	return specOfIcon[class] and specOfIcon[class][icon]
end

-- The member's interrupt cooldown, or nil when they have none.
local function Cooldown(member)
	if not member or not member.class then return nil end
	local spec = member.spec
	if not spec then
		local role = member.role
		if role ~= 'HEALER' and role ~= 'TANK' then role = 'DAMAGER' end
		spec = USUAL[role][member.class]
	end
	return spec and KICK_CD[spec] or nil
end

------------------------------------------------------------------------
-- The strips.
------------------------------------------------------------------------
local function ShowStrip(strip)
	local frame = strip.frame
	local unit = frame.__unit
	local guid = unit and UnitExists(unit) and Plain(UnitGUID(unit))
	local member = guid and members[guid]
	local cd = member and Cooldown(member)
	if not cd then
		strip.bar:Hide()
		return
	end
	local kick = kicks[guid]
	local bar = strip.bar
	if kick and bar.SetTimerDuration then
		bar:SetStatusBarColor(1, 1, 1)
		bar:SetTimerDuration(kick.duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
		if strip.binding then
			strip.binding:SetDuration(kick.duration)
			strip.binding:SetEnabled(true)
		end
	else
		local c = C.colors.kickReady
		bar:SetStatusBarColor(c[1], c[2], c[3])
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		if strip.binding then strip.binding:SetEnabled(false) end
		bar.Time:SetText('')
	end
	bar:Show()
end

local function RefreshStrips(guid)
	for _, strip in ipairs(strips) do
		if not guid or strip.guid == guid or strip.guid == nil then
			local unit = strip.frame.__unit
			strip.guid = unit and UnitExists(unit) and Plain(UnitGUID(unit)) or nil
			ShowStrip(strip)
		end
	end
end

local function QueueRefresh()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0, function()
		refreshQueued = false
		RefreshStrips()
	end)
end

-- A kick landed (or you cast yours): the member's interrupt fills for its cooldown.
local function Kicked(guid)
	local member = members[guid]
	local cd = Cooldown(member)
	if not cd or not C_DurationUtil then return end
	token = token + 1
	local mine = token
	local duration = C_DurationUtil.CreateDuration()
	duration:SetTimeFromStart(GetTime(), cd)
	kicks[guid] = { duration = duration, token = mine }
	RefreshStrips(guid)
	-- One timer per kick while its strip fills; the green comes back when it ends.
	C_Timer.After(cd, function()
		local kick = kicks[guid]
		if kick and kick.token == mine then
			kicks[guid] = nil
			RefreshStrips(guid)
		end
	end)
end

------------------------------------------------------------------------
-- The group.
------------------------------------------------------------------------
local function GroupUnits()
	local list = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do list[#list + 1] = { 'raid' .. i, 'raidpet' .. i } end
	else
		list[1] = { 'player', 'pet' }
		for i = 1, GetNumSubgroupMembers() do list[#list + 1] = { 'party' .. i, 'partypet' .. i } end
	end
	return list
end

local function ReadRoster()
	rosterQueued = false
	playerGUID = Plain(UnitGUID('player'))
	local seen = {}
	local fight = InCombatLockdown()
	for _, pair in ipairs(GroupUnits()) do
		local unit, pet = pair[1], pair[2]
		local guid = Plain(UnitGUID(unit))
		if guid then
			local member = members[guid] or { spells = 0, petSpells = 0 }
			members[guid] = member
			seen[guid] = true
			member.unit, member.pet = unit, pet
			member.class = Plain(UnitClassBase(unit)) or member.class
			member.role = Plain(UnitGroupRolesAssigned(unit)) or member.role
			member.petGUID = UnitExists(pet) and Plain(UnitGUID(pet)) or nil
			if guid == playerGUID then
				member.spec = ns.SpecInfo() or member.spec
			elseif not fight and GetInspectSpecialization then
				-- The game's cached inspect data; 0 while it has none.
				local spec = Plain(GetInspectSpecialization(unit))
				if spec and KICK_CD[spec] ~= nil then member.spec = spec end
			end
		end
	end
	for guid in pairs(members) do
		if not seen[guid] then
			members[guid] = nil
			kicks[guid] = nil
		end
	end
	RefreshStrips()
end

local function QueueRoster()
	if rosterQueued then return end
	rosterQueued = true
	C_Timer.After(0, ReadRoster)
end

------------------------------------------------------------------------
-- The meter.
------------------------------------------------------------------------
-- The member a meter row belongs to: the only one of that class, or the only one of that class
-- with that spec icon. Your own row is yours. A row no member can own names nobody (false).
local function RowOwner(row)
	local class, icon = row.classFilename, row.specIconID
	if Plain(row.isLocalPlayer) == true then return playerGUID or false end
	local only, count = nil, 0
	for guid, member in pairs(members) do
		if guid ~= playerGUID and member.class == class then
			only, count = guid, count + 1
		end
	end
	if count > 1 then
		only, count = nil, 0
		for guid, member in pairs(members) do
			if guid ~= playerGUID and member.class == class and member.icon == icon then
				only, count = guid, count + 1
			end
		end
	end
	if count ~= 1 then return false end
	-- The row tells the member's spec (a demon's row has no spec icon).
	local spec = SpecOfIcon(class, icon)
	if spec then
		members[only].icon, members[only].spec = icon, spec
	end
	return only
end

local function ReadRows()
	local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, CURRENT, INTERRUPTS)
	if not ok or type(session) ~= 'table' or issecretvalue(session) then return nil end
	local sources = session.combatSources
	if type(sources) ~= 'table' or issecretvalue(sources) then return nil end
	local list = {}
	for i = 1, #sources do
		local row = sources[i]
		if type(row) == 'table' and not issecretvalue(row) then
			list[i] = RowOwner(row)
		else
			list[i] = false
		end
	end
	return list
end

-- How many enemy spells this source has kicked in the fight (a plain list length), or nil.
local function SpellCount(guid)
	if not guid then return nil end
	local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, CURRENT, INTERRUPTS, guid)
	if not ok or type(source) ~= 'table' or issecretvalue(source) then return nil end
	local spells = source.combatSpells
	if type(spells) ~= 'table' or issecretvalue(spells) then return nil end
	return #spells
end

-- The meter's interrupt data changed. rebase: only take the new state, a new fight began.
local function ReadMeter(rebase)
	if not (C_DamageMeter and INTERRUPTS and CURRENT) or not IsInGroup() then return end
	local rows = ReadRows()
	local kicked = {}
	if rows and not rebase then
		if #rows > #rowsBefore then
			-- New rows: the members whose row was not there before.
			local left = {}
			for _, owner in ipairs(rowsBefore) do
				if owner then left[owner] = (left[owner] or 0) + 1 end
			end
			for _, owner in ipairs(rows) do
				if owner and (left[owner] or 0) > 0 then
					left[owner] = left[owner] - 1
				elseif owner then
					kicked[owner] = true
				end
			end
		elseif #rows == #rowsBefore then
			-- The first row that differs moved up past the one that was there.
			for i, owner in ipairs(rows) do
				if owner ~= rowsBefore[i] then
					if owner then kicked[owner] = true end
					break
				end
			end
		end
	end
	if rows then rowsBefore = rows end
	-- The kicked spells by member, and by their demon for a warlock.
	for guid, member in pairs(members) do
		if guid ~= playerGUID then
			local count = SpellCount(guid)
			if count then
				if not rebase and count > member.spells then kicked[guid] = true end
				member.spells = count
			end
			local petCount = SpellCount(member.petGUID)
			if petCount then
				if not rebase and petCount > member.petSpells then kicked[guid] = true end
				member.petSpells = petCount
			end
		end
	end
	for guid in pairs(kicked) do
		if guid ~= playerGUID then Kicked(guid) end
	end
end

-- A new fight starts the meter's current session from zero.
local function Rebase()
	wipe(rowsBefore)
	for _, member in pairs(members) do member.spells, member.petSpells = 0, 0 end
	ReadMeter(true)
end

------------------------------------------------------------------------
-- Start: the first strip made switches the tracking on.
------------------------------------------------------------------------
local function OnEvent(_, event, ...)
	if event == 'DAMAGE_METER_COMBAT_SESSION_UPDATED' then
		if ... == INTERRUPTS then ReadMeter(false) end
	elseif event == 'DAMAGE_METER_CURRENT_SESSION_UPDATED' or event == 'DAMAGE_METER_RESET' then
		Rebase()
	elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
		-- Your own and your demon's casts are plain values.
		local _, _, spellID = ...
		if Plain(spellID) and ns.KICKS[spellID] and not NOT_A_KICK[spellID] and playerGUID then Kicked(playerGUID) end
	elseif event == 'PLAYER_REGEN_ENABLED' or event == 'PLAYER_SPECIALIZATION_CHANGED' then
		QueueRoster()
	else
		QueueRoster()
	end
end

local function Start()
	if started then return end
	started = true
	INTERRUPTS = Enum.DamageMeterType and Enum.DamageMeterType.Interrupts
	CURRENT = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current
	local watch = CreateFrame('Frame')
	watch:RegisterEvent('GROUP_ROSTER_UPDATE')
	watch:RegisterEvent('PLAYER_ENTERING_WORLD')
	watch:RegisterEvent('PLAYER_ROLES_ASSIGNED')
	watch:RegisterEvent('PLAYER_REGEN_ENABLED')
	watch:RegisterEvent('UNIT_PET')
	watch:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
	watch:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player', 'pet')
	if C_DamageMeter and INTERRUPTS and CURRENT then
		watch:RegisterEvent('DAMAGE_METER_COMBAT_SESSION_UPDATED')
		watch:RegisterEvent('DAMAGE_METER_CURRENT_SESSION_UPDATED')
		watch:RegisterEvent('DAMAGE_METER_RESET')
	end
	watch:SetScript('OnEvent', OnEvent)
	QueueRoster()
end

-- kind: 'party' (6 px over the power bar), 'raid' or 'grid' (4 px at the bottom).
function ns.AddKickStrip(frame, kind)
	local height = kind == 'party' and 6 or 4
	local bar = CreateFrame('StatusBar', nil, frame)
	bar:SetStatusBarTexture(ns.TEX)
	bar:SetPoint('BOTTOMLEFT')
	bar:SetPoint('BOTTOMRIGHT')
	bar:SetHeight(height)
	bar:SetFrameLevel(frame:GetFrameLevel() + 12)
	local bg = bar:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.08, 0.09, 0.1, 1)
	bar.Time = ns.Text(bar, kind == 'party' and 13 or 11, 'RIGHT')
	bar.Time:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -4, height + 2)
	bar:Hide()
	local strip = { frame = frame, bar = bar }
	if C_DurationUtil and Formatter() then
		strip.binding = C_DurationUtil.CreateDurationTextBinding()
		strip.binding:SetFormatter(Formatter())
		strip.binding:SetFontString(bar.Time)
		strip.binding:SetExpiredText('')
	end
	table.insert(strips, strip)
	frame.KickStrip = bar
	-- The header hands the frame a new member: a frame that shows looks again.
	frame:HookScript('OnShow', QueueRefresh)
	Start()
	return bar
end
