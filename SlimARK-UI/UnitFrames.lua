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

local function CreateHealth(self, bottomOffset, group)
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
	-- Group frames show incoming heals and heal absorbs; the shield then starts after the heals.
	if group then ns.AddPrediction(health) end
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

-- Class power in the ElvUI colors of its resource: holy power gold, combo points, chi and
-- essence pip by pip, charged combo points blue. A resource without a color keeps the game's.
local function ColorPips(element)
	local power = C.colors.power
	local colors = element.powerType == 'HOLY_POWER' and C.colors.classPower or power[element.powerType]
	if not colors then return end
	local list = type(colors[1]) == 'table'
	for i = 1, #element do
		local c = list and colors[math.min(i, #colors)] or colors
		if element.charged and element.charged[i] then c = power.CHARGED end
		element[i]:SetStatusBarColor(c[1], c[2], c[3])
	end
end

-- The runes follow the spec: Blood red, Frost cyan, Unholy green. oUF calls this after a spec change.
local function ColorRunes(element)
	local id = ns.SpecInfo()
	local c = id and C.colors.power.RUNES[id]
	if not c then return end
	for i = 1, #element do
		element[i]:SetStatusBarColor(c[1], c[2], c[3])
	end
end

-- The pips always fill the width of the frame, however many there are. Widths and gaps are
-- whole screen pixels: with fractional widths the game rounds some one-pixel gaps away, and
-- six runes looked like five. The pixels left over go one each to the first pips.
local function SizePips(pips, count)
	local fit = ns.Fit()
	local total = math.floor(pips.width * fit + 0.5)
	local gap = math.max(1, math.floor(fit + 0.5))
	local base = math.floor((total - gap * (count - 1)) / count)
	local extra = total - gap * (count - 1) - base * count
	local x = 0
	for i = 1, count do
		local w = base + (i <= extra and 1 or 0)
		pips[i]:SetWidth(w / fit)
		pips[i]:SetPoint('BOTTOMLEFT', x / fit, 0)
		x = x + w + gap
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
		runes.PostUpdateColor = ColorRunes
		self.Runes = runes
		ShowClassPowerStrip(self, true)
		return
	end

	local pips = CreatePips(self, MAX_PIPS, width, height)
	pips.PostUpdateColor = ColorPips
	pips.PostUpdate = function(element, _, max, _, hasMaxChanged, powerType, ...)
		if hasMaxChanged and max and max > 0 then SizePips(element, max) end
		-- Repaint only when the resource or the charged points change.
		local key
		if select('#', ...) > 0 and not (issecretvalue and issecretvalue((...))) then key = table.concat({ ... }, ',') end
		if powerType == element.powerType and key == element.chargedKey then return end
		element.powerType, element.chargedKey = powerType, key
		local charged
		if key then
			charged = {}
			for i = 1, select('#', ...) do charged[(select(i, ...))] = true end
		end
		element.charged = charged
		ColorPips(element)
	end
	pips.PostVisibility = function(element, isVisible)
		ShowClassPowerStrip(element.__owner, isVisible)
	end
	self.ClassPower = pips
end

-- Shared castbar. Light blue for an enemy, magenta for a cast the game marks important,
-- gray for an uninterruptible cast.
-- Every class's interrupt. The nameplates also read it to name who interrupted.
ns.KICKS = {
	[96231] = true, [1766] = true, [6552] = true, [47528] = true, [2139] = true,
	[57994] = true, [106839] = true, [78675] = true, [116705] = true, [147362] = true,
	[187707] = true, [183752] = true, [351338] = true, [15487] = true, [19647] = true,
	[119910] = true, [132409] = true, [119914] = true, [31935] = true,
}

------------------------------------------------------------------------
-- Your interrupt and the enemy cast bars: while it is on cooldown the bars are dark, so a
-- bright bar always means "you can interrupt this now". The cooldown state of your own spell
-- is a plain value in combat too; the important flag of the cast is hidden, so the game picks
-- between the two colors we hand it.
------------------------------------------------------------------------
local KICK_DIM = 0.45
local enemyBars = {}
local kickID, kickReady = nil, true
local kickTimer

local function FindKick()
	kickID = nil
	if not (C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook) then return end
	local pet = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
	for id in pairs(ns.KICKS) do
		if C_SpellBook.IsSpellKnownOrInSpellBook(id) or (pet and C_SpellBook.IsSpellKnownOrInSpellBook(id, pet)) then
			kickID = id
			return
		end
	end
end

-- Without an interrupt of your own the bars stay bright, as before.
local function KickReady()
	if not kickID then return true end
	local info = C_Spell.GetSpellCooldown(kickID)
	return not (info and info.isActive and not info.isOnGCD)
end

local function PaintCast(element)
	if not element.casting then return end
	local c = element.castColors
	local texture = element:GetStatusBarTexture()
	if kickReady then
		texture:SetVertexColorFromBoolean(element.isImportant, c.important, c.normal)
	else
		texture:SetVertexColorFromBoolean(element.isImportant, c.importantDim, c.normalDim)
	end
end

local function UpdateKick()
	local ready = KickReady()
	if not ready and kickTimer then
		-- The moment the cooldown ends gives no event of its own.
		local duration = C_Spell.GetSpellCooldownDuration(kickID, true)
		if duration then kickTimer:SetCooldownFromDurationObject(duration) end
	end
	if ready == kickReady then return end
	kickReady = ready
	for _, element in ipairs(enemyBars) do
		if element:IsShown() then PaintCast(element) end
	end
end

local function WatchKick()
	if kickTimer or not C.features.kickReady then return end
	kickTimer = CreateFrame('Cooldown', nil, UIParent, 'CooldownFrameTemplate')
	kickTimer:SetSize(1, 1)
	kickTimer:SetPoint('TOPLEFT')
	kickTimer:SetAlpha(0)
	kickTimer:SetHideCountdownNumbers(true)
	kickTimer:SetScript('OnCooldownDone', UpdateKick)
	local function Relearn()
		FindKick()
		UpdateKick()
	end
	ns.On('SPELLS_CHANGED', Relearn)
	ns.On('SPELL_UPDATE_COOLDOWN', UpdateKick)
	Relearn()
end

-- Who the cast is aimed at. The name and the class are hidden values: they can be shown, not
-- read, so "it is you" swaps the name for a red YOU through the alpha.
local function ShowCastTarget(element, unit)
	local name = element.Target
	if not name then return end
	if UnitShouldDisplaySpellTargetName(unit) then
		local class = UnitSpellTargetClass(unit)
		local color = class and C_ClassColor.GetClassColor(class)
		name:SetText(UnitSpellTargetName(unit))
		if color then name:SetTextColor(color.r, color.g, color.b) else name:SetTextColor(1, 1, 1) end
		local onMe = PlayerIsSpellTarget(unit)
		name:SetAlphaFromBoolean(onMe, 0, 1)
		element.TargetYou:SetAlphaFromBoolean(onMe, 1, 0)
		if element.TargetArrow then element.TargetArrow:Show() end
	else
		name:SetText('')
		element.TargetYou:SetAlpha(0)
		if element.TargetArrow then element.TargetArrow:Hide() end
	end
end

-- targetBelow: the cast target goes on a line of its own under the bar (nameplates); otherwise
-- it sits inside the bar, in front of the time.
function ns.CreateCastbar(self, width, height, canInterrupt, fontSize, targetBelow)
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
		local i = C.colors.important
		cb.castColors = {
			normal = CreateColor(base[1], base[2], base[3]),
			important = CreateColor(i[1], i[2], i[3]),
			normalDim = CreateColor(base[1] * KICK_DIM, base[2] * KICK_DIM, base[3] * KICK_DIM),
			importantDim = CreateColor(i[1] * KICK_DIM, i[2] * KICK_DIM, i[3] * KICK_DIM),
		}
		table.insert(enemyBars, cb)
		WatchKick()

		if C.features.castTarget and UnitSpellTargetName and UnitShouldDisplaySpellTargetName and PlayerIsSpellTarget then
			local size = fontSize or 14
			local name = ns.Text(cb, size)
			local you = ns.Text(cb, size)
			you:SetText('YOU')
			you:SetTextColor(1, 0.23, 0.19)
			you:SetAlpha(0)
			if targetBelow then
				local arrow = ns.Text(cb, size)
				arrow:SetText('>')
				arrow:SetTextColor(0.6, 0.61, 0.65)
				arrow:SetPoint('TOPLEFT', cb, 'BOTTOMLEFT', 2, -3)
				arrow:Hide()
				name:SetPoint('LEFT', arrow, 'RIGHT', 4, 0)
				you:SetPoint('LEFT', arrow, 'RIGHT', 4, 0)
				cb.TargetArrow = arrow
			else
				name:SetJustifyH('RIGHT')
				name:SetPoint('RIGHT', cb.Time, 'LEFT', -8, 0)
				you:SetPoint('RIGHT', name, 'RIGHT')
				cb.Text:ClearAllPoints()
				cb.Text:SetPoint('LEFT', 6, 0)
				cb.Text:SetPoint('RIGHT', name, 'LEFT', -6, 0)
			end
			cb.Target, cb.TargetYou = name, you
		end

		cb.PostCastStart = function(element, unit, spellID)
			element.isImportant = C_Spell.IsSpellImportant(spellID)
			element.casting = true
			PaintCast(element)
			element.Important:SetAlphaFromBoolean(element.isImportant, 1, 0)
			if element.ImportantPlate then
				element.ImportantPlate:SetAlphaFromBoolean(element.isImportant, 1, 0)
			end
			ShowCastTarget(element, unit)
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

-- Quick focus: the modifier with a left click on a SlimARK frame sets the focus. A frame made
-- in combat gets it when the fight ends.
local focusPending = {}

local function AddFocusClick(frame)
	if not C.features.quickFocus then return end
	if InCombatLockdown() then
		focusPending[frame] = true
		return
	end
	frame:SetAttribute(C.quickFocus.modifier:lower() .. '-type1', 'focus')
end

ns.On('PLAYER_REGEN_ENABLED', function()
	for frame in pairs(focusPending) do
		focusPending[frame] = nil
		AddFocusClick(frame)
	end
end)

-- Shaman totems: an icon per totem slot with the time left, in a row of its own that can be
-- dragged in Edit Mode. A slot is see-through while it is empty; the game fills the icons and
-- the countdown itself, so it works in combat too.
local TOTEM_SLOTS = 4

local function CreateTotems(self)
	local t = C.totems
	local holder = CreateFrame('Frame', 'SlimARK_Totems', UIParent)
	holder:SetSize(TOTEM_SLOTS * (t.size + t.gap) - t.gap, t.size)
	ns.Register(holder, t.x, t.y, { key = 'totems', heal = { x = t.heal.x, y = t.heal.y } })
	local totems = {}
	for i = 1, TOTEM_SLOTS do
		local f = CreateFrame('Frame', nil, holder)
		f:SetSize(t.size, t.size)
		f:SetPoint('RIGHT', -(i - 1) * (t.size + t.gap), 0)
		f:SetAlpha(0)
		ns.Outline(f)
		local icon = f:CreateTexture(nil, 'ARTWORK')
		icon:SetAllPoints()
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.Icon = icon
		local cd = CreateFrame('Cooldown', nil, f, 'CooldownFrameTemplate')
		cd:SetAllPoints()
		cd:SetDrawEdge(false)
		cd:SetHideCountdownNumbers(false)
		f.Cooldown = cd
		totems[i] = f
	end
	self.Totems = totems
end

-- The player frame steps back out of combat: combat, a target, the mouse over it, a cast of
-- your own or Edit Mode bring it back. No timer runs, the events and the mouse wake it.
local function AddPlayerFade(self)
	local function Update(event)
		local awake = event == 'PLAYER_REGEN_DISABLED' or InCombatLockdown() or UnitAffectingCombat('player')
			or UnitExists('target') or self:IsMouseOver()
			or (self.Castbar and self.Castbar:IsShown())
			or (EditModeManagerFrame and EditModeManagerFrame:IsShown())
		local alpha = awake and 1 or C.units.player.fadeAlpha / 100
		if self:GetAlpha() ~= alpha then self:SetAlpha(alpha) end
	end
	for _, event in ipairs({ 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'PLAYER_TARGET_CHANGED', 'PLAYER_ENTERING_WORLD' }) do
		ns.On(event, Update)
	end
	self:HookScript('OnEnter', Update)
	self:HookScript('OnLeave', Update)
	if self.Castbar then
		self.Castbar:HookScript('OnShow', Update)
		self.Castbar:HookScript('OnHide', Update)
	end
	if EditModeManagerFrame then
		EditModeManagerFrame:HookScript('OnShow', Update)
		EditModeManagerFrame:HookScript('OnHide', Update)
	end
	Update()
end

-- A typed debuff (poison, disease, curse, magic, bleed) colors the whole health area in the
-- type's color, with a 2 px edge in the same color. The game colors the textures itself, so it
-- works in combat too. Two slots on the same place: any typed debuff, and above it one you
-- can dispel, so with several types on the unit that one's color shows.
local TINT_TYPES = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }
local TINT_ALPHA = 0.58

local function AddDebuffTint(self, health, w, h)
	local level = health:GetFrameLevel()
	-- The texts stay above both tint layers.
	health.Texts:SetFrameLevel(level + 3)
	local function Slot(filter, candidateFilters, offset)
		local tint = self:CreateAuras({ initialAnchor = 'TOPLEFT', layoutLimit = w })
		tint:SetAllPoints(health)
		tint:SetFrameLevel(level + offset)
		tint:AddSlot(filter, {
			candidateFilters = candidateFilters,
			CreateButton = function(_, _, button)
				button:SetSize(w, h)
				button:EnableMouse(false)
				-- A layer of its own: it follows the health area (the player's shrinks while the
				-- class power shows) and has a set level, whatever the game gives the button.
				local layer = CreateFrame('Frame', nil, button)
				layer:SetAllPoints(tint)
				layer:SetFrameLevel(level + offset)
				local options = {
					style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
					showWhenHarmful = true,
					customDispelColorMap = self.colors.dispel,
				}
				local fill = layer:CreateTexture(nil, 'ARTWORK')
				fill:SetAllPoints()
				fill:SetColorTexture(1, 1, 1, 1)
				fill:SetAlpha(TINT_ALPHA)
				button:AddDispelTypeTexture(fill, options)
				local thickness = 2 * ns.Px()
				local function side(p1, p2, width, height)
					local t = layer:CreateTexture(nil, 'OVERLAY')
					t:SetColorTexture(1, 1, 1, 1)
					t:SetPoint(p1)
					t:SetPoint(p2)
					if width then t:SetWidth(width) end
					if height then t:SetHeight(height) end
					button:AddDispelTypeTexture(t, options)
				end
				side('TOPLEFT', 'TOPRIGHT', nil, thickness)
				side('BOTTOMLEFT', 'BOTTOMRIGHT', nil, thickness)
				side('TOPLEFT', 'BOTTOMLEFT', thickness, nil)
				side('TOPRIGHT', 'BOTTOMRIGHT', thickness, nil)
			end,
		})
	end
	Slot('HARMFUL', { includeDispelTypes = TINT_TYPES }, 1)
	Slot('HARMFUL|RAID', nil, 2)
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
		CreateHealth(self, 7, true)
	else
		CreateHealth(self, 0, isGroup)
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
		-- The own HoTs take the end of the name row.
		name:SetPoint('RIGHT', -(4 + (C.features.ownHots and o.hotsInName and o.hotMax * (o.hot + 1) or 0)), 0)
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

	if kind == 'player' and C.features.dispelGlow then
		AddDebuffTint(self, health, o.w, o.h)
	end
	if kind == 'player' and C.features.totems and GetTotemInfo and TotemFrame and UnitClassBase('player') == 'SHAMAN' then
		CreateTotems(self)
	end
	if kind == 'player' and C.features.playerFade then
		AddPlayerFade(self)
	end
	AddFocusClick(self)

	if kind == 'player' and C.modules.auras then
		local a = C.auras.buffs
		local buffs = self:CreateAuras({ initialAnchor = 'TOPRIGHT', growthX = 'LEFT', growthY = 'DOWN', layoutLimit = a.width })
		buffs:SetSize(a.width, a.height)
		buffs:SetPoint('TOPRIGHT', UIParent, 'TOPLEFT', ns.FitX(a.right, 'RIGHT'), -ns.FitY(a.y + ns.TopInset()))
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
		debuffs:SetPoint('TOPRIGHT', UIParent, 'TOPLEFT', ns.FitX(d.right, 'RIGHT'), -ns.FitY(d.y + ns.TopInset()))
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
		debuffs:SetFrameLevel(health:GetFrameLevel() + 4)
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
		defensives:SetFrameLevel(health:GetFrameLevel() + 4)
		defensives.size = o.defensive
		defensives.elementSpacing = 1
		defensives.disableMouse = true
		defensives.disableCooldown = true
		defensives.showDuration = true
		defensives.PostCreateButton = StyleDefensive
		defensives:AddGroup('HELPFUL|BIG_DEFENSIVE', { maxFrameCount = 2 })
		defensives:AddGroup('HELPFUL|EXTERNAL_DEFENSIVE', { maxFrameCount = 2 })

		-- A typed debuff colors the health area. What you can dispel: the whole frame also
		-- flashes in the type's color.
		-- The RAID filter gives poison and disease for Retribution.
		if C.features.dispelGlow then
			AddDebuffTint(self, health, o.w, o.h)
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

		-- Your own HoTs: small icons on the right under the value (raid: at the end of the name
		-- row), the remaining time as the dark swipe. RAID_IN_COMBAT with PLAYER gives the
		-- self-cast HoTs the game shows on raid frames; the spells are hidden in combat, so they
		-- come in the game's order, not in fixed corners.
		if C.features.ownHots then
			local hots = self:CreateAuras({ initialAnchor = 'TOPRIGHT', growthX = 'LEFT', growthY = 'DOWN', layoutLimit = o.hotMax * (o.hot + 1) })
			hots:SetSize(o.hotMax * (o.hot + 1), o.hot)
			hots:SetPoint('TOPRIGHT', health, 'TOPRIGHT', -1, -o.hotY)
			hots:SetFrameLevel(health:GetFrameLevel() + 4)
			hots.size = o.hot
			hots.elementSpacing = 1
			hots.disableMouse = true
			hots.PostCreateButton = function(element, button)
				ns.StyleAuraButton(element, button)
				if button.Cooldown then
					button.Cooldown:SetHideCountdownNumbers(true)
					button.Cooldown:SetDrawEdge(false)
				end
			end
			hots:AddGroup('HELPFUL|PLAYER|RAID_IN_COMBAT', { maxFrameCount = o.hotMax })
		end

		-- Private auras: the boss debuffs the game keeps from addons. Blizzard draws them (icon,
		-- swipe, countdown) in the place given here, in the middle, above everything.
		if C.features.privateAuras then
			local private = CreateFrame('Frame', nil, self)
			local num = o.privateNum or 1
			private:SetSize(num * o.center + (num - 1) * 2, o.center)
			private:SetPoint('TOP', health, 'TOP', 0, -o.centerY)
			private:SetFrameLevel(self:GetFrameLevel() + 14)
			private.size = o.center
			private.spacing = 2
			private.num = num
			private.initialAnchor = 'TOPLEFT'
			private.growthX = 'RIGHT'
			private.growthY = 'DOWN'
			private.maxCols = num
			self.PrivateAuras = private
		end

		-- Leader crown and raid marker on the left; res, summon, ready check and phase in the
		-- middle, where the private auras are (those come in combat, these mostly out of it).
		if C.features.statusIcons then
			local top = CreateFrame('Frame', nil, self)
			top:SetAllPoints(self)
			top:SetFrameLevel(self:GetFrameLevel() + 13)
			local leader = top:CreateTexture(nil, 'OVERLAY')
			leader:SetSize(o.ind, o.ind)
			leader:SetPoint('TOPLEFT', health, 'TOPLEFT', 3, -o.indY)
			self.LeaderIndicator = leader
			local marker = top:CreateTexture(nil, 'OVERLAY')
			marker:SetSize(o.ind, o.ind)
			marker:SetPoint('TOPLEFT', health, 'TOPLEFT', 3 + o.ind + 2, -o.indY)
			self.RaidTargetIndicator = marker
			local function Center(texture)
				texture:SetSize(o.center, o.center)
				texture:SetPoint('TOP', health, 'TOP', 0, -o.centerY)
				return texture
			end
			self.ResurrectIndicator = Center(top:CreateTexture(nil, 'OVERLAY', nil, 1))
			self.SummonIndicator = Center(top:CreateTexture(nil, 'OVERLAY', nil, 2))
			self.ReadyCheckIndicator = Center(top:CreateTexture(nil, 'OVERLAY', nil, 3))
			local phase = CreateFrame('Frame', nil, top)
			Center(phase)
			phase.Icon = phase:CreateTexture(nil, 'OVERLAY')
			phase.Icon:SetAllPoints()
			self.PhaseIndicator = phase
		end

		-- Aggro: a red frame inside the edge of the member a mob hits (threat 2 or 3). Asked for
		-- one unit only, the threat state is readable in combat; a hidden value hides the frame.
		-- The unit is oUF's own (__unit); .unit is only filled in when the mouse shows the tooltip.
		if C.features.aggro then
			local aggro = ns.Edge(self, 2, C.colors.aggro, 0)
			aggro:SetFrameLevel(self:GetFrameLevel() + 11)
			aggro:Hide()
			aggro.Override = function(frame, _, unit)
				local current = frame.__unit
				if not current then
					aggro:Hide()
					return
				end
				if unit and unit ~= current then return end
				local ok, status = pcall(UnitThreatSituation, current)
				local hit = ok and status ~= nil and not issecretvalue(status) and status >= 2
				aggro:SetShown(hit and UnitExists(current) or false)
			end
			self.ThreatIndicator = aggro
		end

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

	-- Blizzard's party and raid frames step aside for the role that has a SlimARK frame in their
	-- place: Party and Raid for DPS and tanks, the grid for healers. With both roles covered they
	-- are switched off for good, as oUF does it. With one role covered they are only hidden for
	-- that role (Role.lua), so a spec change or a module switched off gives them back.
	local partyCovered = M.party and M.grid
	local raidCovered = M.raid and M.grid
	-- oUF switches Blizzard's party frames off for good when a header is made with showParty, so
	-- with one role covered showParty is set right after the header is made.
	local showPartyLater = not partyCovered

	if M.party then
		local p = C.units.party
		-- The player has an own frame, so the DPS party column holds only the other four.
		local party = self:SpawnHeader('SlimARK_Party', nil,
			'showParty', not showPartyLater, 'showRaid', true,
			'point', 'TOP', 'yOffset', -p.gap,
			'oUF-initialConfigFunction', init(p))
		if showPartyLater then party:SetAttribute('showParty', true) end
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
			'showParty', not showPartyLater, 'showPlayer', true, 'showRaid', true,
			'point', 'LEFT', 'xOffset', g.gap,
			'oUF-initialConfigFunction', init(g))
		if showPartyLater then healParty:SetAttribute('showParty', true) end
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

	-- A Blizzard group frame stays for the role whose SlimARK frame for that group is switched off.
	-- PartyFrame holds the party frames of both styles (CompactPartyFrame is made inside it later).
	if raidCovered then
		ns.Block(CompactRaidFrameContainer)
	elseif M.raid or M.grid then
		ns.AddBlizzardGroup(CompactRaidFrameContainer, nil, M.raid, M.grid)
	end
	if partyCovered then
		ns.Block(CompactPartyFrame)
	elseif M.party or M.grid then
		ns.AddBlizzardGroup(PartyFrame, 'unitFrames', M.party, M.grid)
	end
	-- The buffs and debuffs belong to the player frame.
	if M.unitframes and M.auras then
		ns.Block(BuffFrame)
		ns.Block(DebuffFrame)
	end
end)
