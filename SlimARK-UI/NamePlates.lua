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

-- Who interrupted: the game gives the GUID, but in restricted content it can be hidden.
-- So we also watch the party's own interrupt casts, the most recent wins.
local lastKick = { name = nil, class = nil, time = 0 }

local KICKS = {
	[96231] = true, [1766] = true, [6552] = true, [47528] = true, [2139] = true,
	[57994] = true, [106839] = true, [78675] = true, [116705] = true, [147362] = true,
	[187707] = true, [183752] = true, [351338] = true, [15487] = true, [19647] = true,
	[119910] = true, [132409] = true, [119914] = true, [31935] = true,
}

local kickWatch = CreateFrame('Frame')
kickWatch:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player', 'party1', 'party2', 'party3', 'party4')
kickWatch:SetScript('OnEvent', function(_, _, unit, _, spellID)
	if issecretvalue(spellID) or not KICKS[spellID] then return end
	local name = UnitName(unit)
	if issecretvalue(name) then return end
	lastKick.name, lastKick.class, lastKick.time = name, UnitClassBase(unit), GetTime()
	if issecretvalue(lastKick.class) then lastKick.class = nil end
end)

-- The exact GUID is first, then the party's fresh interrupt, finally the name
-- behind a secret GUID. Enemy casts in dungeons give the GUID as a secret: the
-- name can still be shown (SetText takes a secret), only its class color is unknown.
local function InterrupterName(guid)
	local secret = issecretvalue(guid)
	if not secret and guid and guid ~= '' then
		local name = UnitNameFromGUID(guid)
		if name and not issecretvalue(name) and name ~= '' then
			local _, class = GetPlayerInfoByGUID(guid)
			return name, class
		end
	end
	if lastKick.name and GetTime() - lastKick.time < 0.5 then
		return lastKick.name, lastKick.class
	end
	if secret then
		local ok, name = pcall(UnitNameFromGUID, guid)
		if ok then return name end
	end
end

local MAX_TARGETERS = 4
local plateFrames = {}
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
		if element.__owner.isCaster then
			local c = C.colors.caster
			element:SetStatusBarColor(c[1], c[2], c[3])
		end
	end
	health.Texts = ns.TextLayer(health)
	ns.AddShield(health)
	self.Health = health

	-- The name and the HP in the plate, in one line.
	local pct = ns.Text(health.Texts, C.plate.font, 'RIGHT')
	pct:SetPoint('RIGHT', -4, 0)
	self:Tag(pct, '[slim:pct1]')

	local name = ns.Text(health.Texts, C.plate.font, 'LEFT')
	name:SetPoint('LEFT', 4, 0)
	name:SetPoint('RIGHT', pct, 'LEFT', -4, 0)
	self:Tag(name, '[name]')
	self.PlateName = name

	local cb = ns.CreateCastbar(self, o.w, o.castH, true, 14)
	cb:SetPoint('TOP', health, 'BOTTOM', 0, -3)
	-- After an interrupt the bar is still visible: Interrupted and the interrupter's name in class color.
	cb.timeToHold = o.holdTime
	-- The time text is driven by a duration binding that would write the countdown
	-- over the name on the next frame, so it rests until the next cast.
	local function ShowInterrupter(element, guid)
		element.Text:SetText('Interrupted')
		if not C.features.interrupter then return end
		local name, class = InterrupterName(guid)
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
	-- When the game leaves out who interrupted, our own or a party interrupt seen right then still names them.
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
	end)
	UpdateMembers()
	ns.On('GROUP_ROSTER_UPDATE', function()
		UpdateMembers()
		UpdateAllTargeters()
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
