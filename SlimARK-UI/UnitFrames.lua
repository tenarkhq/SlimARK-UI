local _, ns = ...
local oUF = ns.oUF
local C = ns.C
local TEX = ns.TEX

local Tags = oUF.Tags
Tags.Methods['slim:cur'] = function(u)
	if UnitIsDead(u) or UnitIsGhost(u) or not UnitIsConnected(u) then return end
	return AbbreviateNumbers(UnitHealth(u))
end
Tags.Methods['slim:pct'] = function(u)
	if UnitIsDead(u) or UnitIsGhost(u) or not UnitIsConnected(u) then return end
	return string.format('%d%%', UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
end
Tags.Methods['slim:hp'] = function(u)
	if UnitIsDead(u) or UnitIsGhost(u) or not UnitIsConnected(u) then return end
	return string.format('%s · %d%%', AbbreviateNumbers(UnitHealth(u)), UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
end
for _, tag in ipairs({ 'slim:cur', 'slim:pct', 'slim:hp' }) do
	Tags.Events[tag] = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION'
end

function ns.StyleAuraButton(element, button)
	if button.Icon then button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	ns.Outline(button)
	if button.Count then button.Count:SetFont(ns.FONT, 16, 'OUTLINE') end
	if button.Time then
		button.Time:SetFont(ns.FONT, 15, 'OUTLINE')
		button.Time:ClearAllPoints()
		button.Time:SetPoint('BOTTOM', button, 'BOTTOM', 0, 1)
	end
end

local function CreateHealth(self, bottomOffset)
	local health = CreateFrame('StatusBar', nil, self)
	health:SetStatusBarTexture(TEX)
	health:SetPoint('TOPLEFT')
	health:SetPoint('BOTTOMRIGHT', 0, bottomOffset)
	ns.Track(health)
	ns.Gloss(health)
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorClass = true
	health.colorReaction = true
	self.Health = health
	return health
end

local function CreatePower(self, bottomOffset)
	local power = CreateFrame('StatusBar', nil, self)
	power:SetStatusBarTexture(TEX)
	power:SetHeight(6)
	power:SetPoint('BOTTOMLEFT', 0, bottomOffset)
	power:SetPoint('BOTTOMRIGHT', 0, bottomOffset)
	ns.Track(power)
	ns.Gloss(power)
	power.colorPower = true
	self.Power = power
end

local function CreateClassPower(self, width, height)
	local pips = {}
	local gap = 1
	local w = (width - gap * 4) / 5
	for i = 1, 5 do
		local pip = CreateFrame('StatusBar', nil, self)
		pip:SetStatusBarTexture(TEX)
		pip:SetSize(w, height)
		pip:SetPoint('BOTTOMLEFT', (i - 1) * (w + gap), 0)
		ns.Track(pip)
		ns.Gloss(pip)
		pips[i] = pip
	end
	-- Az oUF a játék halvány színét adná, itt minden osztálynál sárgás narancs.
	pips.PostUpdateColor = function(element)
		local c = C.colors.classPower
		for i = 1, #element do
			element[i]:SetStatusBarColor(c[1], c[2], c[3])
		end
	end
	self.ClassPower = pips
end

-- Közös castbar. Ellenfélnél világoskék, a játék szerint fontos castnál narancs,
-- nem szakítható castnál szürke.
function ns.CreateCastbar(self, width, height, canInterrupt, fontSize)
	local cb = CreateFrame('StatusBar', nil, self)
	cb:SetSize(width, height)
	cb:SetStatusBarTexture(TEX)
	local base = canInterrupt and C.colors.enemyCast or C.colors.cast
	cb:SetStatusBarColor(base[1], base[2], base[3])
	ns.Outline(cb)
	ns.Track(cb)
	ns.Gloss(cb)

	cb.Text = ns.Text(cb, fontSize or 14)
	cb.Text:SetPoint('LEFT', 6, 0)
	cb.Text:SetPoint('RIGHT', -40, 0)
	cb.Time = ns.Text(cb, fontSize or 14, 'RIGHT')
	cb.Time:SetPoint('RIGHT', -6, 0)

	if canInterrupt then
		local shield = cb:CreateTexture(nil, 'OVERLAY', nil, 0)
		shield:SetTexture(TEX)
		local c = C.colors.notInterruptible
		shield:SetVertexColor(c[1], c[2], c[3], 0.95)
		shield:SetAllPoints()
		cb.Shield = shield

		local important = ns.Edge(cb, 2, C.colors.important, 3)
		important:SetAlpha(0)
		cb.Important = important
		local normalColor = CreateColor(base[1], base[2], base[3])
		local i = C.colors.important
		local importantColor = CreateColor(i[1], i[2], i[3])
		cb.PostCastStart = function(element, _, spellID)
			local isImportant = C_Spell.IsSpellImportant(spellID)
			element:GetStatusBarTexture():SetVertexColorFromBoolean(isImportant, importantColor, normalColor)
			element.Important:SetAlphaFromBoolean(isImportant, 1, 0)
			if element.ImportantPlate then
				element.ImportantPlate:SetAlphaFromBoolean(isImportant, 1, 0)
			end
		end
	end

	self.Castbar = cb
	return cb
end

local function Style(self, unit)
	local parentName = self:GetParent() and self:GetParent():GetName()
	local kind = (parentName == 'SlimARK_Party' and 'party')
		or (parentName == 'SlimARK_Raid' and 'raid')
		or ((unit or ''):match('^boss') and 'boss')
		or unit
	local o = C.units[kind]
	if not o then return end

	self:RegisterForClicks('AnyUp')
	self:HookScript('OnEnter', function(frame) UnitFrame_OnEnter(frame) end)
	self:HookScript('OnLeave', function(frame) UnitFrame_OnLeave(frame) end)
	ns.Outline(self)

	if kind ~= 'party' and kind ~= 'raid' then
		self:SetSize(o.w, o.h)
	end

	local isGroup = kind == 'party' or kind == 'raid'

	if kind == 'player' then
		CreateClassPower(self, o.w, o.classPower)
		CreatePower(self, o.classPower + 1)
		CreateHealth(self, o.classPower + 8)
	elseif kind == 'party' then
		CreatePower(self, 0)
		CreateHealth(self, 7)
	else
		CreateHealth(self, 0)
	end

	local health = self.Health
	local name = ns.Text(health, o.font)
	local value = ns.Text(health, o.font, 'RIGHT')

	if kind == 'boss' then
		name:SetPoint('TOPLEFT', 5, -3)
		name:SetPoint('RIGHT', -5, 0)
		self:Tag(name, '[name]')
		local current = ns.Text(health, 24, 'CENTER')
		current:SetPoint('CENTER', 0, -5)
		self:Tag(current, '[dead][slim:cur]')
		value:SetPoint('BOTTOMRIGHT', -5, 3)
		self:Tag(value, '[slim:pct]')
	else
		name:SetPoint('LEFT', 6, 0)
		self:Tag(name, '[name]')
		if kind == 'player' or kind == 'target' then
			value:SetPoint('RIGHT', -6, 0)
			name:SetPoint('RIGHT', value, 'LEFT', -6, 0)
			self:Tag(value, '[dead][offline][slim:hp]')
		elseif kind == 'focus' or kind == 'party' then
			value:SetPoint('RIGHT', -6, 0)
			name:SetPoint('RIGHT', value, 'LEFT', -6, 0)
			self:Tag(value, '[dead][offline][slim:pct]')
		elseif kind == 'raid' then
			name:SetPoint('RIGHT', -4, 0)
			value:SetFont(ns.FONT, 14, 'OUTLINE')
			value:SetPoint('BOTTOMRIGHT', -3, 2)
			self:Tag(value, '[dead][offline]')
		else
			name:SetPoint('RIGHT', -4, 0)
		end
	end

	if kind == 'player' or kind == 'target' then
		local cb = ns.CreateCastbar(self, o.w, 24, kind == 'target', 17)
		cb:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', 0, -4)
	elseif kind == 'focus' then
		local cb = ns.CreateCastbar(self, o.w, 24, true, 17)
		cb:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', 0, -4)
	elseif kind == 'boss' then
		local cb = ns.CreateCastbar(self, 200, 24, true, 16)
		cb:SetPoint('RIGHT', self, 'LEFT', -5, 0)
	end

	if kind == 'player' then
		local a = C.auras.buffs
		local buffs = self:CreateAuras({ initialAnchor = 'TOPRIGHT', growthX = 'LEFT', growthY = 'DOWN', layoutLimit = a.width })
		buffs:SetSize(a.width, a.height)
		buffs:SetPoint('TOPRIGHT', UIParent, 'TOPLEFT', a.right, -a.y)
		buffs.size = a.size
		buffs.elementSpacing = 3
		buffs.lineSpacing = 3
		buffs.disableCooldown = true
		buffs.showDuration = true
		buffs.showCount = true
		buffs.cancelButton = 'RightButtonUp'
		buffs.PostCreateButton = ns.StyleAuraButton
		buffs:AddGroup('HELPFUL', { maxFrameCount = a.max })

		local d = C.auras.debuffs
		local debuffs = self:CreateAuras({ initialAnchor = 'TOPRIGHT', growthX = 'LEFT', growthY = 'DOWN', layoutLimit = d.width })
		debuffs:SetSize(d.width, d.height)
		debuffs:SetPoint('TOPRIGHT', UIParent, 'TOPLEFT', d.right, -d.y)
		debuffs.size = d.size
		debuffs.elementSpacing = 3
		debuffs.disableCooldown = true
		debuffs.showDuration = true
		debuffs.showCount = true
		debuffs.showDebuffBorder = true
		debuffs.PostCreateButton = ns.StyleAuraButton
		debuffs:AddGroup('HARMFUL', { maxFrameCount = d.max })
	elseif kind == 'target' then
		local size = C.auras.targetDebuffSize
		local mine = self:CreateAuras({ initialAnchor = 'BOTTOMLEFT', growthX = 'RIGHT', growthY = 'UP', layoutLimit = o.w })
		mine:SetSize(o.w, size)
		mine:SetPoint('BOTTOMLEFT', self, 'TOPLEFT', 0, 6)
		mine.size = size
		mine.elementSpacing = 3
		mine.showDuration = true
		mine.showCount = true
		mine.PostCreateButton = ns.StyleAuraButton
		mine:AddGroup('HARMFUL|PLAYER', { maxFrameCount = 8 })
	end

	if isGroup then
		self.Range = { insideAlpha = 1, outsideAlpha = 0.45 }

		-- Minden debuff kis ikonnal, a típus színes kerettel.
		local debuffs = self:CreateAuras({ initialAnchor = 'BOTTOMRIGHT', growthX = 'LEFT', growthY = 'UP', layoutLimit = o.w })
		debuffs:SetSize(o.w, o.debuff)
		debuffs:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT', -1, 1)
		debuffs:SetFrameLevel(health:GetFrameLevel() + 3)
		debuffs.size = o.debuff
		debuffs.elementSpacing = 1
		debuffs.disableMouse = true
		debuffs.disableCooldown = kind == 'raid'
		debuffs.showDebuffBorder = true
		debuffs.PostCreateButton = ns.StyleAuraButton
		debuffs:AddGroup('HARMFUL', { maxFrameCount = 3 })

		-- Amit te tudsz levenni: a teljes keret felvillan a típus színével.
		-- A RAID szűrő retrinél a poisont és a diseaset adja.
		local glow = self:CreateAuras({ initialAnchor = 'TOPLEFT', layoutLimit = o.w })
		glow:SetAllPoints(self)
		glow:SetFrameLevel(health:GetFrameLevel() + 5)
		glow:AddSlot('HARMFUL|RAID', {
			CreateButton = function(element, _, button)
				button:SetSize(o.w, o.h)
				button:EnableMouse(false)
				local border = button:CreateTexture(nil, 'OVERLAY')
				border:SetAllPoints()
				button:AddDispelTypeTexture(border, {
					style = Enum.CustomAuraButtonDispelTypeTextureStyle.Border,
					showWhenHarmful = true,
					customDispelColorMap = element.__owner.colors.dispel,
				})
			end,
		})

		self.TargetIndicator = ns.Edge(self, 2, C.colors.target, 1)
	end
end

oUF:RegisterStyle('SlimARK-UI', Style)

oUF:Factory(function(self)
	self:SetActiveStyle('SlimARK-UI')

	for _, unit in ipairs({ 'player', 'target', 'targettarget', 'pet', 'focus' }) do
		local o = C.units[unit]
		ns.Register(self:Spawn(unit, 'SlimARK_' .. unit), o.x, o.y, { key = unit, w = o.w, h = o.h })
	end

	local b = C.units.boss
	local first, previous
	for i = 1, 5 do
		local frame = self:Spawn('boss' .. i, 'SlimARK_Boss' .. i)
		if i == 1 then
			first = ns.Register(frame, b.x, b.y, { key = 'boss', w = b.w, h = 5 * (b.h + b.gap) - b.gap })
		else
			ns.Register(frame, b.x, b.y, { owner = first, after = previous, gap = b.gap })
		end
		previous = frame
	end

	local function init(o)
		return ('self:SetWidth(%d) self:SetHeight(%d)'):format(o.w, o.h)
	end

	local p = C.units.party
	local party = self:SpawnHeader('SlimARK_Party', nil,
		'showParty', true, 'showPlayer', true, 'showRaid', true,
		'point', 'TOP', 'yOffset', -p.gap,
		'oUF-initialConfigFunction', init(p))
	party:SetVisibility('custom [@raid6,exists] hide; [group] show; hide')
	ns.Register(party, p.x, p.y, { key = 'party', w = p.w, h = 5 * (p.h + p.gap) - p.gap })

	local r = C.units.raid
	local raid = self:SpawnHeader('SlimARK_Raid', nil,
		'showRaid', true,
		'groupFilter', '1,2,3,4,5,6,7,8', 'groupingOrder', '1,2,3,4,5,6,7,8', 'groupBy', 'GROUP',
		'point', 'LEFT', 'xOffset', r.gap,
		'unitsPerColumn', 5, 'maxColumns', 8,
		'columnAnchorPoint', 'TOP', 'columnSpacing', r.gap,
		'oUF-initialConfigFunction', init(r))
	raid:SetVisibility('custom [@raid6,exists] show; hide')
	ns.Register(raid, r.x, r.y, { key = 'raid', w = 5 * (r.w + r.gap) - r.gap, h = 8 * (r.h + r.gap) - r.gap })

	ns.Block(CompactRaidFrameContainer)
	ns.Block(CompactPartyFrame)
	ns.Block(BuffFrame)
	ns.Block(DebuffFrame)
end)
