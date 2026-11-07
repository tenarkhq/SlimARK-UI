local _, ns = ...
local C = ns.C

local _, class = UnitClass('player')
local spec = C.cooldowns[class]
if not spec then return end

local cfg = C.cooldowns
local rows, icons = {}, {}
local formatter, zero

local function Known(id)
	return C_SpellBook.IsSpellInSpellBook(id)
end

local function PickSpell(ids)
	for _, id in ipairs(ids) do
		if Known(id) then return id end
	end
end

local function CreateRow(parent, index, data)
	local row = CreateFrame('Frame', nil, parent)
	row:SetSize(cfg.w, cfg.rowH)
	row:SetPoint('TOPLEFT', 0, -(index - 1) * (cfg.rowH + cfg.gap))
	row.data = data

	local icon = row:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(cfg.rowH, cfg.rowH)
	icon:SetPoint('LEFT')
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.Icon = icon

	local bar = CreateFrame('StatusBar', nil, row)
	bar:SetPoint('TOPLEFT', cfg.rowH + 2, 0)
	bar:SetPoint('BOTTOMRIGHT')
	bar:SetStatusBarTexture(ns.TEX)
	bar:SetStatusBarColor(data.color[1], data.color[2], data.color[3])
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	ns.Outline(bar)
	local bg = bar:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.65)
	ns.Gloss(bar)
	row.Bar = bar

	-- Kész állapotban teli, élénk sáv. Cooldown alatt eltűnik, és a fogyó sáv látszik.
	local ready = bar:CreateTexture(nil, 'ARTWORK', nil, 1)
	ready:SetAllPoints()
	ready:SetColorTexture(data.color[1], data.color[2], data.color[3], 0.85)
	row.Ready = ready

	row.Name = ns.Text(bar, cfg.font)
	row.Name:SetPoint('LEFT', 5, 0)
	row.Time = ns.Text(bar, cfg.font, 'RIGHT')
	row.Time:SetPoint('RIGHT', -5, 0)

	row.binding = C_DurationUtil.CreateDurationTextBinding()
	row.binding:SetFormatter(formatter)
	row.binding:SetFontString(row.Time)
	row.binding:SetExpiredText('kész')
	return row
end

local function UpdateRow(row)
	local id = PickSpell(row.data.ids)
	row.spellID = id
	row:SetShown(id ~= nil)
	if not id then return end

	row.Icon:SetTexture(C_Spell.GetSpellTexture(id))
	row.Name:SetText(C_Spell.GetSpellName(id))

	local info = C_Spell.GetSpellCooldown(id)
	local active = info and info.isActive and not info.isOnGCD
	local duration = active and C_Spell.GetSpellCooldownDuration(id, true)
	if duration then
		row.Bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
		row.binding:SetDuration(duration)
		row.binding:SetEnabled(true)
		row.Ready:Hide()
	else
		row.Bar:SetTimerDuration(zero, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
		row.binding:SetEnabled(false)
		row.Time:SetText('kész')
		row.Ready:Show()
	end
end

local function CreateIcon(parent)
	local f = CreateFrame('Frame', nil, parent)
	f:SetSize(cfg.iconSize, cfg.iconSize)
	ns.Outline(f)
	local tex = f:CreateTexture(nil, 'ARTWORK')
	tex:SetAllPoints()
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.Icon = tex
	local cd = CreateFrame('Cooldown', nil, f, 'CooldownFrameTemplate')
	cd:SetAllPoints()
	cd:SetDrawEdge(false)
	cd:SetHideCountdownNumbers(false)
	f.Cooldown = cd
	local top = CreateFrame('Frame', nil, f)
	top:SetAllPoints()
	top:SetFrameLevel(cd:GetFrameLevel() + 2)
	f.Count = ns.Text(top, 16, 'RIGHT')
	f.Count:SetPoint('BOTTOMRIGHT', -2, 2)
	return f
end

local function UpdateIcon(f)
	local id = f.spellID
	f.Icon:SetTexture(C_Spell.GetSpellTexture(id))

	local charges = C_Spell.GetSpellCharges(id)
	if charges and charges.maxCharges > 1 then
		f.Count:SetText(charges.currentCharges)
		f.Icon:SetDesaturated(false)
		local duration = charges.isActive and C_Spell.GetSpellChargeDuration(id)
		if duration then
			f.Cooldown:SetCooldownFromDurationObject(duration)
		else
			f.Cooldown:Clear()
		end
		return
	end

	f.Count:SetText('')
	local info = C_Spell.GetSpellCooldown(id)
	local active = info and info.isActive and not info.isOnGCD
	local duration = active and C_Spell.GetSpellCooldownDuration(id, true)
	if duration then
		f.Icon:SetDesaturated(true)
		f.Cooldown:SetCooldownFromDurationObject(duration)
	else
		f.Icon:SetDesaturated(false)
		f.Cooldown:Clear()
	end
end

local function LayoutIcons()
	local known = {}
	for i, id in ipairs(spec.icons) do
		icons[i]:Hide()
		if Known(id) then
			icons[i].spellID = id
			table.insert(known, icons[i])
		end
	end
	local step = cfg.iconSize + cfg.iconGap
	local startX = (cfg.w - (#known * step - cfg.iconGap)) / 2
	for i, f in ipairs(known) do
		f:ClearAllPoints()
		f:SetPoint('TOPLEFT', startX + (i - 1) * step, 0)
		f:Show()
	end
end

local function UpdateAll()
	for _, row in ipairs(rows) do UpdateRow(row) end
	for _, f in ipairs(icons) do
		if f:IsShown() then UpdateIcon(f) end
	end
end

local function Refresh()
	LayoutIcons()
	UpdateAll()
end

ns.On('PLAYER_LOGIN', function()
	formatter = C_StringUtil.CreateSecondsFormatter()
	formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
	formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
	zero = C_DurationUtil.CreateDuration()

	local barFrame = CreateFrame('Frame', 'SlimARK_CooldownBars', UIParent)
	barFrame:SetSize(cfg.w, #spec.bars * (cfg.rowH + cfg.gap))
	ns.Register(barFrame, cfg.x, cfg.y, { key = 'cooldownbars' })
	for i, data in ipairs(spec.bars) do
		rows[i] = CreateRow(barFrame, i, data)
	end

	local iconFrame = CreateFrame('Frame', 'SlimARK_CooldownIcons', UIParent)
	iconFrame:SetSize(cfg.w, cfg.iconSize)
	ns.Register(iconFrame, cfg.x, cfg.iconY, { key = 'cooldownicons' })
	for i = 1, #spec.icons do
		icons[i] = CreateIcon(iconFrame)
	end

	Refresh()
	ns.On('SPELL_UPDATE_COOLDOWN', UpdateAll)
	ns.On('SPELL_UPDATE_CHARGES', UpdateAll)
	ns.On('SPELLS_CHANGED', Refresh)
	ns.On('PLAYER_TALENT_UPDATE', Refresh)
	ns.On('TRAIT_CONFIG_UPDATED', Refresh)
	ns.On('PLAYER_ENTERING_WORLD', Refresh)
end)
