local _, ns = ...
local oUF = ns.oUF
local C = ns.C

-- Caster marking before the cast already. A mob is a caster if it is mage class, a lieutenant,
-- mana is its power (in the game mage and paladin NPCs get mana), or we have already
-- seen it cast. The class can be hidden in restricted content, the mana type
-- cannot, so it works in dungeons too. Seen casters are remembered by name.
local function IsCaster(unit)
	local class = UnitClassBase(unit)
	if class and not issecretvalue(class) and class == 'MAGE' then return true end
	local lieutenant = UnitIsLieutenant(unit)
	if lieutenant and not issecretvalue(lieutenant) then return true end
	local powerType = UnitPowerType(unit)
	if powerType and not issecretvalue(powerType) and powerType == Enum.PowerType.Mana then return true end
	local name = UnitName(unit)
	if name and not issecretvalue(name) and ns.DB and ns.DB.casters[name] then return true end
	return false
end

local function SetCasterMark(frame, isCaster)
	frame.isCaster = isCaster
	frame.Health:SetHeight(isCaster and C.plate.casterH or C.plate.h)
	if frame.Health.ForceUpdate then frame.Health:ForceUpdate() end
end

local function UpdateCasterMark(frame, unit)
	SetCasterMark(frame, IsCaster(unit))
end

-- If an unmarked mob casts, it is a caster from then on, and its name is kept.
local function LearnCaster(frame, unit)
	if frame.isCaster or UnitIsPlayer(unit) or UnitIsFriend('player', unit) then return end
	SetCasterMark(frame, true)
	local name = UnitName(unit)
	if name and not issecretvalue(name) and ns.DB then ns.DB.casters[name] = true end
end

-- Who interrupted: the game gives the GUID, but in restricted content it can be hidden or left out.
-- So we also watch the party's own interrupt casts. The mob a kick went to is not given either:
-- the plate the kicker had targeted at the moment of the cast is noted, and a kick from the last
-- half second at the interrupted plate names the kicker in class color. A kick at another mob
-- names nobody here.
local recentKicks = {} -- unit -> { name, class, time, plate }
local KICK_WINDOW = 0.5
local plateFrames = {}

local function SameUnit(a, b)
	if not UnitExists(a) or not C_Secrets.CanCompareUnitTokens(a, b) then return false end
	local same = UnitIsUnit(a, b)
	return not issecretvalue(same) and same == true
end

-- The plate unit the kicker targets right now.
local function TargetPlate(kicker)
	local target = kicker .. 'target'
	for _, frame in ipairs(plateFrames) do
		local unit = frame.__unit
		if unit and SameUnit(target, unit) then return unit end
	end
end

local KICKS = ns.KICKS

local kickWatch = CreateFrame('Frame')
kickWatch:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player', 'party1', 'party2', 'party3', 'party4')
kickWatch:SetScript('OnEvent', function(_, _, unit, _, spellID)
	if issecretvalue(spellID) or not KICKS[spellID] then return end
	local name = UnitName(unit)
	if not name or issecretvalue(name) then return end
	local class = UnitClassBase(unit)
	if issecretvalue(class) then class = nil end
	recentKicks[unit] = { name = name, class = class, time = GetTime(), plate = TargetPlate(unit) }
end)

-- The freshest party interrupt cast at this plate's unit.
-- The party interrupt that went to this plate's unit. When the game does not let us compare the
-- kicker's target with the plate (restricted content), a single fresh kick that is not tied to
-- another plate counts too: with only one kick in that half second it was the one.
local function KickOn(unit)
	if not unit then return end
	local best, loose, looseCount = nil, nil, 0
	local now = GetTime()
	for _, kick in pairs(recentKicks) do
		if now - kick.time < KICK_WINDOW then
			if kick.plate == unit then
				if not best or kick.time > best.time then best = kick end
			elseif kick.plate == nil then
				loose, looseCount = kick, looseCount + 1
			else
				looseCount = looseCount + 2 -- a kick at another plate: no guessing
			end
		end
	end
	if best then return best end
	if looseCount == 1 then return loose end
end

-- The exact GUID is first, then a party interrupt at this plate (it knows the class, so the name
-- gets its class color), last the name behind a secret GUID (enemy casts in dungeons give the GUID
-- as a secret: the name can still be shown, SetText takes a secret, only its class color is unknown).
local function InterrupterName(guid, unit)
	local secret = issecretvalue(guid)
	if not secret and guid and guid ~= '' then
		local name = UnitNameFromGUID(guid)
		if name and not issecretvalue(name) and name ~= '' then
			local _, class = GetPlayerInfoByGUID(guid)
			return name, class
		end
	end
	local kick = KickOn(unit)
	if kick then return kick.name, kick.class end
	if secret then
		local ok, name = pcall(UnitNameFromGUID, guid)
		if ok and issecretvalue(name) then return name end
		if ok and name and name ~= '' then return name end
	end
end

local MAX_TARGETERS = 4
local members = {}

-- In a party the four teammates, in a raid the tanks. Watching everyone in a raid would be expensive.
local function UpdateMembers()
	wipe(members)
	local inRaid = IsInRaid()
	local count = inRaid and GetNumGroupMembers() or GetNumSubgroupMembers()
	local me = inRaid and UnitInRaid('player')
	for i = 1, count do
		local unit = (inRaid and 'raid' or 'party') .. i
		if #members < MAX_TARGETERS and i ~= me and (not inRaid or UnitGroupRolesAssigned(unit) == 'TANK') then
			local class = UnitClassBase(unit)
			local color = class and not issecretvalue(class) and C_ClassColor.GetClassColor(class)
			table.insert(members, { unit = unit, target = unit .. 'target', color = color })
		end
	end
end

local function UpdateTargeters(frame)
	local unit = frame.__unit
	if not unit then return end
	for i, slot in ipairs(frame.Targeters) do
		local member = members[i]
		if member and UnitExists(member.target) and C_Secrets.CanCompareUnitTokens(member.target, unit) then
			slot:SetText(UnitName(member.unit))
			local c = member.color
			if c then slot:SetTextColor(c.r, c.g, c.b) else slot:SetTextColor(1, 1, 1) end
			slot:SetAlphaFromBoolean(UnitIsUnit(member.target, unit), 1, 0)
		else
			slot:SetAlpha(0)
		end
	end
end

local function UpdateAllTargeters()
	for _, frame in ipairs(plateFrames) do
		if frame:IsVisible() then UpdateTargeters(frame) end
	end
end

------------------------------------------------------------------------
-- Aggro on the plate: only in a group, and only the wrong case gets the warning color. For a
-- tank spec that is a mob fighting the group that is not on you, for every other spec a mob
-- that is on you. Your own threat on a plate is readable in dungeons; a hidden value colors
-- nothing.
------------------------------------------------------------------------
local function Plain(value)
	if issecretvalue(value) then return nil end
	return value
end

local function OnAnotherTank(unit)
	if not IsInRaid() then return false end
	for _, member in ipairs(members) do
		local status = Plain(UnitThreatSituation(member.unit, unit))
		if status and status >= 2 then return true end
	end
	return false
end

local function ThreatWarn(unit)
	if not C.features.plateThreat or not unit or not IsInGroup() then return false end
	if Plain(UnitIsPlayer(unit)) or Plain(UnitIsFriend('player', unit)) then return false end
	local status = UnitThreatSituation('player', unit)
	if issecretvalue(status) then return false end
	local onMe = (status or 0) >= 2
	local _, role = ns.SpecInfo()
	if role ~= 'TANK' then return onMe end
	if onMe then return false end
	local fighting = UnitAffectingCombat(unit)
	if issecretvalue(fighting) then fighting = status ~= nil end
	return fighting and not OnAnotherTank(unit) or false
end

local function UpdateThreat(frame)
	local warn = ThreatWarn(frame.__unit)
	if warn == (frame.threatWarn or false) then return end
	frame.threatWarn = warn
	if frame.Health.ForceUpdate then frame.Health:ForceUpdate() end
end

local function UpdateAllThreat()
	for _, frame in ipairs(plateFrames) do
		if frame:IsVisible() then UpdateThreat(frame) end
	end
end

-- The execute line: a thin mark on the health bar where your finisher starts to work. The
-- setting wins; at 0 the value of your spec or class is used, and without one there is no line.
local function ExecutePercent()
	local o = C.plate
	if not C.features.executeLine then return 0 end
	if o.execute > 0 then return o.execute end
	local spec = ns.SpecInfo()
	return spec and o.executeSpec[spec] or o.executeClass[UnitClassBase('player')] or 0
end

local function PlaceExecuteLine(frame)
	local line = frame.ExecuteLine
	local percent = ExecutePercent()
	line:SetShown(percent > 0)
	if percent <= 0 then return end
	local x = C.plate.w * percent / 100
	line:ClearAllPoints()
	line:SetPoint('TOP', frame.Health, 'TOPLEFT', x, 0)
	line:SetPoint('BOTTOM', frame.Health, 'BOTTOMLEFT', x, 0)
end

local function PlateStyle(self)
	local o = C.plate
	local health = CreateFrame('StatusBar', nil, self)
	health:SetStatusBarTexture(ns.TEX)
	health:SetSize(o.w, o.h)
	health:SetPoint('CENTER')
	ns.Outline(health)
	ns.Track(health)
	ns.Gloss(health)
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorClass = true
	health.colorReaction = true
	health.PostUpdateColor = function(element)
		local owner = element.__owner
		local c = owner.threatWarn and C.colors.plateThreat or owner.isCaster and C.colors.caster
		if c then element:SetStatusBarColor(c[1], c[2], c[3]) end
	end
	health.Texts = ns.TextLayer(health)
	ns.AddShield(health)
	self.Health = health

	local line = health:CreateTexture(nil, 'OVERLAY', nil, 2)
	line:SetColorTexture(1, 1, 1, 0.9)
	line:SetWidth(2 * ns.Px())
	self.ExecuteLine = line
	PlaceExecuteLine(self)

	-- The name and the HP in the plate, in one line.
	local pct = ns.Text(health.Texts, C.plate.font, 'RIGHT')
	pct:SetPoint('RIGHT', -4, 0)
	self:Tag(pct, '[slim:pct1]')

	local name = ns.Text(health.Texts, C.plate.font, 'LEFT')
	name:SetPoint('LEFT', 4, 0)
	name:SetPoint('RIGHT', pct, 'LEFT', -4, 0)
	self:Tag(name, '[name]')
	self.PlateName = name

	local cb = ns.CreateCastbar(self, o.w, o.castH, true, 14, true)
	cb:SetPoint('TOP', health, 'BOTTOM', 0, -3)
	-- After an interrupt the bar is still visible: Interrupted and the interrupter's name in class color.
	cb.timeToHold = o.holdTime
	-- The time text is driven by a duration binding that would write the countdown
	-- over the name on the next frame, so it rests until the next cast.
	local function ShowInterrupter(element, guid)
		element.Text:SetText('Interrupted')
		if not C.features.interrupter then return end
		local name, class = InterrupterName(guid, element.__owner and element.__owner.__unit)
		-- A secret name can not be tested, only shown.
		if not issecretvalue(name) and not name then return end
		if element.Time.binding then element.Time.binding:SetEnabled(false) end
		local color = class and C_ClassColor.GetClassColor(class)
		element.Time:SetText(name)
		if color then element.Time:SetTextColor(color.r, color.g, color.b) else element.Time:SetTextColor(1, 1, 1) end
	end
	cb.PostCastInterrupted = function(element, _, _, interruptedBy)
		ShowInterrupter(element, interruptedBy)
	end
	-- When the game leaves out who interrupted, our own or a party interrupt at this plate still names them.
	-- The event decides: the bar text can be a hidden value after a secret spell name, it can not be compared.
	cb.PostCastFail = function(element, _, _, event)
		if event == 'UNIT_SPELLCAST_INTERRUPTED' then ShowInterrupter(element, nil) end
	end
	local postStart = cb.PostCastStart
	cb.PostCastStart = function(element, unit, ...)
		if element.Time.binding then element.Time.binding:SetEnabled(true) end
		element.Time:SetTextColor(1, 1, 1)
		LearnCaster(element.__owner, unit)
		if postStart then return postStart(element, unit, ...) end
	end
	-- While it casts, there is a light blue border around the plate, magenta for an important cast.
	-- Both disappear together with the castbar.
	ns.Edge(cb, 2, C.colors.casting, 2, health)
	cb.ImportantPlate = ns.Edge(cb, 3, C.colors.important, 2, health)
	cb.ImportantPlate:SetFrameLevel(cb:GetFrameLevel() + 12)
	cb.ImportantPlate:SetAlpha(0)

	local debuffs = self:CreateAuras({ initialAnchor = 'BOTTOMLEFT', growthX = 'RIGHT', growthY = 'UP', layoutLimit = o.w })
	debuffs:SetSize(o.w, o.debuff)
	debuffs:SetPoint('BOTTOMLEFT', health, 'TOPLEFT', 0, 4)
	debuffs.size = o.debuff
	debuffs.elementSpacing = 2
	debuffs.disableMouse = true
	debuffs.showDuration = true
	debuffs.PostCreateButton = ns.StyleAuraButton
	debuffs:AddGroup('HARMFUL|PLAYER', { maxFrameCount = 6 })

	local raidIcon = health:CreateTexture(nil, 'OVERLAY')
	raidIcon:SetSize(24, 24)
	raidIcon:SetPoint('RIGHT', health, 'LEFT', -24, 0)
	self.RaidTargetIndicator = raidIcon

	-- Target: thin white border and two small arrows pointing at the plate.
	-- If there is a target, the other plates fade.
	local indicator = ns.Edge(self, 1, C.colors.target, 2, health)
	for _, side in ipairs(C.features.plateArrows and { 'LEFT', 'RIGHT' } or {}) do
		local arrow = indicator:CreateTexture(nil, 'OVERLAY')
		arrow:SetTexture([[Interface\AddOns\SlimARK-UI\Media\Arrow.tga]])
		arrow:SetSize(o.arrowW, o.arrowH)
		if side == 'LEFT' then
			arrow:SetPoint('RIGHT', indicator, 'LEFT', -o.arrowGap, 0)
		else
			arrow:SetTexCoord(1, 0, 0, 1)
			arrow:SetPoint('LEFT', indicator, 'RIGHT', o.arrowGap, 0)
		end
	end

	indicator.PostUpdate = function(element, isTargeted)
		local owner = element.__owner
		if UnitExists('target') then
			owner:SetAlphaFromBoolean(isTargeted, 1, C.plate.dimAlpha)
		else
			owner:SetAlpha(1)
		end
	end
	self.TargetIndicator = indicator

	-- Who is targeting this mob: the teammates' names on the right side of the plate.
	local slots = {}
	for i = 1, MAX_TARGETERS do
		local slot = ns.Text(health.Texts, o.targeterFont)
		slot:SetPoint('LEFT', health, 'RIGHT', 20, (MAX_TARGETERS / 2 - i + 0.5) * (o.targeterFont + 2))
		slot:SetWidth(90)
		slot:SetAlpha(0)
		slots[i] = slot
	end
	self.Targeters = slots
	table.insert(plateFrames, self)
end

oUF:RegisterStyle('SlimARKPlate', PlateStyle)

oUF:Factory(function(self)
	if not C.modules.nameplates then return end
	self:SetActiveStyle('SlimARKPlate')
	local plates = self:SpawnNamePlates('SlimARKPlate')
	plates:SetSize(C.plate.w, C.plate.h + 16)
	plates:SetAddedCallback(function(frame, _, unit)
		UpdateCasterMark(frame, unit)
		UpdateTargeters(frame)
		UpdateThreat(frame)
	end)
	UpdateMembers()
	ns.On('GROUP_ROSTER_UPDATE', function()
		UpdateMembers()
		UpdateAllTargeters()
		UpdateAllThreat()
	end)
	if C.features.plateThreat then
		-- The mob's own threat list changed: only its plate is looked at.
		ns.On('UNIT_THREAT_LIST_UPDATE', function(_, unit)
			for _, frame in ipairs(plateFrames) do
				if frame.__unit == unit then
					if frame:IsVisible() then UpdateThreat(frame) end
					return
				end
			end
		end)
		ns.On('UNIT_THREAT_SITUATION_UPDATE', function(_, unit)
			if unit == 'player' then UpdateAllThreat() end
		end)
		ns.On('PLAYER_REGEN_ENABLED', UpdateAllThreat)
	end
	ns.On('PLAYER_SPECIALIZATION_CHANGED', function(_, unit)
		if unit ~= 'player' then return end
		for _, frame in ipairs(plateFrames) do PlaceExecuteLine(frame) end
		UpdateAllThreat()
	end)
	ns.On('UNIT_TARGET', function(_, unit)
		for _, member in ipairs(members) do
			if member.unit == unit then
				UpdateAllTargeters()
				return
			end
		end
	end)
	self:SetActiveStyle('SlimARK-UI')
end)
