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
-- To tenths, used by the nameplate and the party frames.
Tags.Methods['slim:pct1'] = function(u)
	if UnitIsDead(u) or UnitIsGhost(u) or not UnitIsConnected(u) then return end
	return string.format('%.1f%%', UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
end
Tags.Methods['slim:hp'] = function(u)
	if UnitIsDead(u) or UnitIsGhost(u) or not UnitIsConnected(u) then return end
	return string.format('%s · %d%%', AbbreviateNumbers(UnitHealth(u)), UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
end
for _, tag in ipairs({ 'slim:cur', 'slim:pct', 'slim:pct1', 'slim:hp' }) do
	Tags.Events[tag] = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION'
end

function ns.StyleAuraButton(element, button)
	if button.Icon then button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	ns.Outline(button)
	if button.Count then button.Count:SetFont(ns.FONT, 17, 'THICKOUTLINE') end
	if button.Time then
		button.Time:SetFont(ns.FONT, 15, 'OUTLINE')
		button.Time:ClearAllPoints()
		button.Time:SetPoint('BOTTOM', button, 'BOTTOM', 0, 1)
	end
end

-- The player's buffs and debuffs: the icon on top, the countdown below it,
-- the stack count large with a thick outline in the top right corner.
local function AuraBelowStyle(cfg)
	return function(_, button)
		local icon = button.Icon
		icon:ClearAllPoints()
		icon:SetPoint('TOPLEFT')
		icon:SetPoint('TOPRIGHT')
		icon:SetHeight(cfg.size)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local edge = button:CreateTexture(nil, 'BACKGROUND', nil, -8)
		edge:SetColorTexture(0, 0, 0, 1)
		local px = ns.Px()
		edge:SetPoint('TOPLEFT', icon, -px, px)
		edge:SetPoint('BOTTOMRIGHT', icon, px, -px)
		if button.Border then button.Border:SetAllPoints(icon) end
		if button.Count then
			button.Count:SetFont(ns.FONT, cfg.countFont, 'THICKOUTLINE')
			button.Count:ClearAllPoints()
			button.Count:SetPoint('TOPRIGHT', icon, 'TOPRIGHT', 1, 1)
		end
		if button.Time then
			button.Time:SetFont(ns.FONT, cfg.timeFont, 'OUTLINE')
			button.Time:SetTextColor(1, 0.85, 0.35)
			button.Time:ClearAllPoints()
			button.Time:SetPoint('TOP', icon, 'BOTTOM', 0, -2)
		end
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
	health.Texts = ns.TextLayer(health)
	ns.AddShield(health)
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

-- oUF would give the game's pale color, here it is a yellowish orange for every class.
local function ColorPips(element)
	local c = C.colors.classPower
	for i = 1, #element do
		element[i]:SetStatusBarColor(c[1], c[2], c[3])
	end
end

-- The pips always fill the width of the frame, however many there are.
local function SizePips(pips, count)
	local gap = 1
	local w = (pips.width - gap * (count - 1)) / count
	for i = 1, count do
		pips[i]:SetWidth(w)
		pips[i]:SetPoint('BOTTOMLEFT', (i - 1) * (w + gap), 0)
	end
end

local function CreatePips(self, count, width, height)
	local pips = { width = width }
	for i = 1, count do
		local pip = CreateFrame('StatusBar', nil, self)
		pip:SetStatusBarTexture(TEX)
		pip:SetHeight(height)
		pip:Hide()
		ns.Track(pip)
		ns.Gloss(pip)
		pips[i] = pip
	end
	pips.PostUpdateColor = ColorPips
	return pips
end

-- Without class power the health gets the place of the strip.
local function ShowClassPowerStrip(self, shown)
	local strip = shown and C.units.player.classPower + 1 or 0
	self.Power:SetPoint('BOTTOMLEFT', 0, strip)
	self.Power:SetPoint('BOTTOMRIGHT', 0, strip)
	self.Health:SetPoint('BOTTOMRIGHT', 0, strip + 7)
end

local RUNES = 6
-- The Enhancement shaman asks for the most pips, ten from Maelstrom Weapon.
local MAX_PIPS = 10

local function CreateClassPower(self, width, height)
	if UnitClassBase('player') == 'DEATHKNIGHT' then
		local runes = CreatePips(self, RUNES, width, height)
		SizePips(runes, RUNES)
		self.Runes = runes
		ShowClassPowerStrip(self, true)
		return
	end

	local pips = CreatePips(self, MAX_PIPS, width, height)
	pips.PostUpdate = function(element, _, max, _, hasMaxChanged)
		if hasMaxChanged and max and max > 0 then SizePips(element, max) end
	end
	pips.PostVisibility = function(element, isVisible)
		ShowClassPowerStrip(element.__owner, isVisible)
	end
	self.ClassPower = pips
end

-- Shared castbar. Light blue for an enemy, magenta for a cast the game marks important,
-- gray for an uninterruptible cast.
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

local GROUP_KINDS = {
	SlimARK_Party = 'party',
	SlimARK_Raid = 'raid',
	SlimARK_HealParty = 'grid',
	SlimARK_HealRaid = 'grid',
}

-- The defensive's time in the middle of the small icon, easy to read.
local function StyleDefensive(element, button)
	ns.StyleAuraButton(element, button)
	button.Time:SetFont(ns.FONT, 15, 'OUTLINE')
	button.Time:ClearAllPoints()
	button.Time:SetPoint('CENTER', button, 'CENTER', 0, 0)
end

local function Style(self, unit)
	local parentName = self:GetParent() and self:GetParent():GetName()
	local kind = GROUP_KINDS[parentName]
		or ((unit or ''):match('^boss') and 'boss')
		or unit
	local o = C.units[kind]
	if not o then return end

	self:RegisterForClicks('AnyUp')
	-- The Blizzard tooltip reads the .unit field, oUF keeps the unit in the __unit field.
	self:HookScript('OnEnter', function(frame)
		if not frame.__unit then return end
		frame.unit = frame.__unit
		UnitFrame_OnEnter(frame)
	end)
	self:HookScript('OnLeave', function(frame) UnitFrame_OnLeave(frame) end)
	ns.Outline(self)

	local isGroup = kind == 'party' or kind == 'raid' or kind == 'grid'
	if not isGroup then
		self:SetSize(o.w, o.h)
	end

	if kind == 'player' then
		CreatePower(self, 0)
		CreateHealth(self, 7)
		CreateClassPower(self, o.w, o.classPower)
	elseif kind == 'party' then
		CreatePower(self, 0)
		CreateHealth(self, 7)
	else
		CreateHealth(self, 0)
	end

	local health = self.Health
	local name = ns.Text(health.Texts, o.font)
	local value = ns.Text(health.Texts, o.font, 'RIGHT')

	if kind == 'boss' then
		name:SetPoint('TOPLEFT', 5, -3)
		name:SetPoint('RIGHT', -5, 0)
		self:Tag(name, '[name]')
		local current = ns.Text(health.Texts, 24, 'CENTER')
		current:SetPoint('CENTER', 0, -5)
		self:Tag(current, '[dead][slim:cur]')
		value:SetPoint('BOTTOMRIGHT', -5, 3)
		self:Tag(value, '[slim:pct]')
	elseif kind == 'party' or kind == 'grid' then
		-- The name is on top so the defensive and debuff icons fit below.
		-- The role icon comes before it.
		value:SetPoint('TOPRIGHT', -5, -3)
		self:Tag(value, '[dead][offline][slim:pct1]')
		name:SetPoint('TOPLEFT', o.font + 7, -3)
		name:SetPoint('TOPRIGHT', value, 'TOPLEFT', -4, 0)
		self:Tag(name, '[name]')
	elseif kind == 'raid' then
		name:SetPoint('TOPLEFT', o.font + 7, -3)
		name:SetPoint('RIGHT', -4, 0)
		self:Tag(name, '[name]')
		value:SetFont(ns.FONT, 14, 'OUTLINE')
		value:SetPoint('BOTTOMRIGHT', -3, 2)
		self:Tag(value, '[dead][offline]')
	else
		name:SetPoint('LEFT', 6, 0)
		self:Tag(name, '[name]')
		if kind == 'player' or kind == 'target' then
			value:SetPoint('RIGHT', -6, 0)
			name:SetPoint('RIGHT', value, 'LEFT', -6, 0)
			self:Tag(value, '[dead][offline][slim:hp]')
		elseif kind == 'focus' then
			value:SetPoint('RIGHT', -6, 0)
			name:SetPoint('RIGHT', value, 'LEFT', -6, 0)
			self:Tag(value, '[dead][offline][slim:pct]')
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

	if kind == 'player' and C.modules.auras then
		local a = C.auras.buffs
		local buffs = self:CreateAuras({ initialAnchor = 'TOPRIGHT', growthX = 'LEFT', growthY = 'DOWN', layoutLimit = a.width })
		buffs:SetSize(a.width, a.height)
		buffs:SetPoint('TOPRIGHT', UIParent, 'TOPLEFT', ns.FitX(a.right, 'RIGHT'), -ns.FitY(a.y))
		buffs.width = a.size
		buffs.height = a.size + a.timeH
		buffs.elementSpacing = a.gap
		buffs.lineSpacing = a.gap
		buffs.disableCooldown = true
		buffs.showDuration = true
		buffs.showCount = true
		buffs.cancelButton = 'RightButtonUp'
		buffs.PostCreateButton = AuraBelowStyle(a)
		buffs:AddGroup('HELPFUL', { maxFrameCount = a.max })

		local d = C.auras.debuffs
		local debuffs = self:CreateAuras({ initialAnchor = 'TOPRIGHT', growthX = 'LEFT', growthY = 'DOWN', layoutLimit = d.width })
		debuffs:SetSize(d.width, d.height)
		debuffs:SetPoint('TOPRIGHT', UIParent, 'TOPLEFT', ns.FitX(d.right, 'RIGHT'), -ns.FitY(d.y))
		debuffs.width = d.size
		debuffs.height = d.size + d.timeH
		debuffs.elementSpacing = d.gap
		debuffs.lineSpacing = d.gap
		debuffs.disableCooldown = true
		debuffs.showDuration = true
		debuffs.showCount = true
		debuffs.showDebuffBorder = true
		debuffs.PostCreateButton = AuraBelowStyle(d)
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

		-- Every debuff with a small icon, the type with a colored border.
		local debuffs = self:CreateAuras({ initialAnchor = 'BOTTOMRIGHT', growthX = 'LEFT', growthY = 'UP', layoutLimit = o.w })
		debuffs:SetSize(o.w, o.debuff)
		debuffs:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT', -1, 1)
		debuffs:SetFrameLevel(health:GetFrameLevel() + 3)
		debuffs.size = o.debuff
		debuffs.elementSpacing = 1
		debuffs.disableMouse = true
		debuffs.disableCooldown = kind ~= 'party'
		debuffs.showDebuffBorder = true
		debuffs.PostCreateButton = ns.StyleAuraButton
		debuffs:AddGroup('HARMFUL', { maxFrameCount = 3 })

		-- Our own big defensive and the external defensive received, with the remaining time.
		local defensives = self:CreateAuras({ initialAnchor = 'BOTTOMLEFT', growthX = 'RIGHT', growthY = 'UP', layoutLimit = o.w })
		defensives:SetSize(o.w, o.defensive)
		defensives:SetPoint('BOTTOMLEFT', health, 'BOTTOMLEFT', 1, 1)
		defensives:SetFrameLevel(health:GetFrameLevel() + 3)
		defensives.size = o.defensive
		defensives.elementSpacing = 1
		defensives.disableMouse = true
		defensives.disableCooldown = true
		defensives.showDuration = true
		defensives.PostCreateButton = StyleDefensive
		defensives:AddGroup('HELPFUL|BIG_DEFENSIVE', { maxFrameCount = 2 })
		defensives:AddGroup('HELPFUL|EXTERNAL_DEFENSIVE', { maxFrameCount = 2 })

		-- What you can dispel: the whole frame flashes in the type's color.
		-- The RAID filter gives poison and disease for Retribution.
		if C.features.dispelGlow then
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
		end

		self.TargetIndicator = ns.Edge(self, 2, C.colors.target, 1)

		-- Tank, heal or dps icon before the name.
		if C.features.roleIcon then
			local role = health.Texts:CreateTexture(nil, 'OVERLAY', nil, 7)
			role:SetSize(o.font + 2, o.font + 2)
			role:SetPoint('TOPLEFT', 3, -3)
			self.GroupRoleIndicator = role
		end
	end
end

oUF:RegisterStyle('SlimARK-UI', Style)

oUF:Factory(function(self)
	self:SetActiveStyle('SlimARK-UI')
	ns.ReadRole()

	local M = C.modules
	if M.unitframes then
		for _, unit in ipairs({ 'player', 'target', 'targettarget', 'pet', 'focus' }) do
			local o = C.units[unit]
			ns.Register(self:Spawn(unit, 'SlimARK_' .. unit), o.x, o.y, { key = unit, w = o.w, h = o.h, heal = o.heal })
		end

		local b = C.units.boss
		local first, previous
		for i = 1, 5 do
			local frame = self:Spawn('boss' .. i, 'SlimARK_Boss' .. i)
			if i == 1 then
				first = ns.Register(frame, b.x, b.y, { key = 'boss', w = b.w, h = 5 * (b.h + b.gap) - b.gap, side = 'RIGHT' })
			else
				ns.Register(frame, b.x, b.y, { owner = first, after = previous, gap = b.gap })
			end
			previous = frame
		end
	end

	local function init(o)
		return ('self:SetWidth(%d) self:SetHeight(%d)'):format(o.w, o.h)
	end

	local PARTY_SHOWN = 'custom [@raid6,exists] hide; [group] show; hide'
	local RAID_SHOWN = 'custom [@raid6,exists] show; hide'

	if M.party then
		local p = C.units.party
		-- The player has an own frame, so the DPS party column holds only the other four.
		local party = self:SpawnHeader('SlimARK_Party', nil,
			'showParty', true, 'showRaid', true,
			'point', 'TOP', 'yOffset', -p.gap,
			'oUF-initialConfigFunction', init(p))
		ns.AddGroupHeader(party, false, PARTY_SHOWN)
		ns.Register(party, p.x, p.y, { key = 'party', w = p.w, h = 4 * (p.h + p.gap) - p.gap, forHealer = false })
	end

	if M.raid then
		local r = C.units.raid
		local raid = self:SpawnHeader('SlimARK_Raid', nil,
			'showRaid', true,
			'groupFilter', '1,2,3,4,5,6,7,8', 'groupingOrder', '1,2,3,4,5,6,7,8', 'groupBy', 'GROUP',
			'point', 'LEFT', 'xOffset', r.gap,
			'unitsPerColumn', 5, 'maxColumns', 8,
			'columnAnchorPoint', 'TOP', 'columnSpacing', r.gap,
			'oUF-initialConfigFunction', init(r))
		ns.AddGroupHeader(raid, false, RAID_SHOWN)
		ns.Register(raid, r.x, r.y, { key = 'raid', w = 5 * (r.w + r.gap) - r.gap, h = 8 * (r.h + r.gap) - r.gap, forHealer = false, side = 'LEFT' })
	end

	if M.grid then
		-- The healer grid: five frames in a row, the bottom left corner is anchored, the rows grow upward.
		local g = C.units.grid
		local gridWidth = 5 * (g.w + g.gap) - g.gap
		local healParty = self:SpawnHeader('SlimARK_HealParty', nil,
			'showParty', true, 'showPlayer', true, 'showRaid', true,
			'point', 'LEFT', 'xOffset', g.gap,
			'oUF-initialConfigFunction', init(g))
		ns.AddGroupHeader(healParty, true, PARTY_SHOWN)
		ns.Register(healParty, g.x, g.y, { key = 'healparty', w = gridWidth, h = g.h, point = 'BOTTOMLEFT', forHealer = true })

		local healRaid = self:SpawnHeader('SlimARK_HealRaid', nil,
			'showRaid', true,
			'groupFilter', '1,2,3,4,5,6,7,8', 'groupingOrder', '1,2,3,4,5,6,7,8', 'groupBy', 'GROUP',
			'point', 'LEFT', 'xOffset', g.gap,
			'unitsPerColumn', 5, 'maxColumns', 8,
			'columnAnchorPoint', 'BOTTOM', 'columnSpacing', g.gap,
			'oUF-initialConfigFunction', init(g))
		ns.AddGroupHeader(healRaid, true, RAID_SHOWN)
		ns.Register(healRaid, g.x, g.y, { key = 'healraid', w = gridWidth, h = 8 * (g.h + g.gap) - g.gap, point = 'BOTTOMLEFT', forHealer = true })
	end

	-- A Blizzard group frame stays when our frame for that group is switched off.
	if M.raid or M.grid then ns.Block(CompactRaidFrameContainer) end
	if M.party or M.grid then ns.Block(CompactPartyFrame) end
	-- The buffs and debuffs belong to the player frame.
	if M.unitframes and M.auras then
		ns.Block(BuffFrame)
		ns.Block(DebuffFrame)
	end
end)
