local _, ns = ...
local oUF = ns.oUF
local C = ns.C

-- Casternek jelöli a mage osztályú és a hadnagy NPC-ket: lila, magasabb plate.
-- Korlátozott tartalomban ez az adat rejtett lehet, ilyenkor a jelölés elmarad,
-- a cast kiemelés akkor is él.
local function UpdateCasterMark(frame, unit)
	local isCaster = false
	local class = UnitClassBase(unit)
	if class and not issecretvalue(class) and class == 'MAGE' then
		isCaster = true
	end
	local lieutenant = UnitIsLieutenant(unit)
	if lieutenant and not issecretvalue(lieutenant) then
		isCaster = true
	end
	frame.isCaster = isCaster
	frame.Health:SetHeight(isCaster and C.plate.casterH or C.plate.h)
	if isCaster then
		local c = C.colors.caster
		frame.PlateName:SetTextColor(c[1], c[2], c[3])
	else
		frame.PlateName:SetTextColor(1, 1, 1)
	end
end

local MAX_TARGETERS = 4
local plateFrames = {}
local members = {}

-- Partyban a négy társ, raidben a tankok. Raidben mindenkit figyelni drága lenne.
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
	if not frame.unit then return end
	for i, slot in ipairs(frame.Targeters) do
		local member = members[i]
		if member and UnitExists(member.target) and C_Secrets.CanCompareUnitTokens(member.target, frame.unit) then
			slot:SetText(UnitName(member.unit))
			local c = member.color
			if c then slot:SetTextColor(c.r, c.g, c.b) else slot:SetTextColor(1, 1, 1) end
			slot:SetAlphaFromBoolean(UnitIsUnit(member.target, frame.unit), 1, 0)
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
	self.Health = health

	local name = ns.Text(health, C.plate.font, 'CENTER')
	name:SetPoint('BOTTOM', health, 'TOP', 0, 3)
	name:SetWidth(o.w)
	self:Tag(name, '[name]')
	self.PlateName = name

	local pct = ns.Text(health, C.plate.font, 'RIGHT')
	pct:SetPoint('RIGHT', -3, 0)
	self:Tag(pct, '[slim:pct]')

	local cb = ns.CreateCastbar(self, o.w, o.castH, true, 14)
	cb:SetPoint('TOP', health, 'BOTTOM', 0, -3)
	-- Szakítás után a bar még látszik, rajta a szakító neve.
	cb.timeToHold = o.holdTime
	cb.PostCastInterrupted = function(element, _, _, interruptedBy)
		element.Text:SetText('Szakította:')
		element.Time:SetText(UnitNameFromGUID(interruptedBy))
	end
	-- Amíg castol, a plate körül világoskék keret van, fontos castnál narancs.
	-- Mindkettő a castbarral együtt tűnik el.
	ns.Edge(cb, 2, C.colors.casting, 2, health)
	cb.ImportantPlate = ns.Edge(cb, 3, C.colors.important, 2, health)
	cb.ImportantPlate:SetFrameLevel(cb:GetFrameLevel() + 12)
	cb.ImportantPlate:SetAlpha(0)

	local debuffs = self:CreateAuras({ initialAnchor = 'BOTTOMLEFT', growthX = 'RIGHT', growthY = 'UP', layoutLimit = o.w })
	debuffs:SetSize(o.w, o.debuff)
	debuffs:SetPoint('BOTTOMLEFT', health, 'TOPLEFT', 0, 18)
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

	-- Target: vékony fehér keret és két kis nyíl, ami a plate-re mutat.
	-- Ha van targeted, a többi plate elhalványul.
	local indicator = ns.Edge(self, 1, C.colors.target, 2, health)
	for _, side in ipairs({ 'LEFT', 'RIGHT' }) do
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

	-- Kik targetelik ezt a mobot: a társak neve a plate jobb oldalán.
	local slots = {}
	for i = 1, MAX_TARGETERS do
		local slot = ns.Text(health, o.targeterFont)
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
