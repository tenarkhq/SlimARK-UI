local _, ns = ...
local C = ns.C

local cfg = C.cooldowns
local MAX_BARS, MAX_ICONS = 5, 8
local rows, icons = {}, {}
local formatter, zero
local barFrame, iconFrame

-- A gyógyító elrendezésben keskenyebb a sáv és az ikonsor.
local function Width()
	return ns.healer and cfg.heal.w or cfg.w
end

-- A pet spelljei külön könyvben vannak, ilyen a warlock Spell Lock.
local function Known(id)
	return C_SpellBook.IsSpellInSpellBook(id)
		or C_SpellBook.IsSpellInSpellBook(id, Enum.SpellBookSpellBank.Pet)
end

local function PickSpell(ids)
	for _, id in ipairs(ids) do
		if Known(id) then return id end
	end
end

-- A játék Cooldown Viewer listája az adott spechez.
local function ViewerSpells(category)
	local spells = {}
	if not C_CooldownViewer.IsCooldownViewerAvailable() then return spells end
	for _, cooldownID in ipairs(C_CooldownViewer.GetCooldownViewerCategorySet(category) or {}) do
		local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
		local id = info and (info.overrideSpellID or info.spellID)
		if id then table.insert(spells, id) end
	end
	return spells
end

local function CurrentSpec()
	return cfg.specs[ns.SpecInfo()] or { bars = {} }
end

local function CreateRow(parent, index)
	local row = CreateFrame('Frame', nil, parent)
	row:SetSize(Width(), cfg.rowH)
	row:SetPoint('TOPLEFT', 0, -(index - 1) * (cfg.rowH + cfg.gap))
	row:Hide()

	local icon = row:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(cfg.rowH, cfg.rowH)
	icon:SetPoint('LEFT')
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.Icon = icon

	local bar = CreateFrame('StatusBar', nil, row)
	bar:SetPoint('TOPLEFT', cfg.rowH + 2, 0)
	bar:SetPoint('BOTTOMRIGHT')
	bar:SetStatusBarTexture(ns.TEX)
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

local function SetRow(row, id, color)
	row.spellID = id
	row.Bar:SetStatusBarColor(color[1], color[2], color[3])
	row.Ready:SetColorTexture(color[1], color[2], color[3], 0.85)
end

-- A spec saját listája megy előre, a maradék helyet a játék listája tölti ki.
-- Visszaadja, mely spellek kerültek sávra.
local function AssignRows(spec)
	local used, count = {}, 0
	local function Add(id, color)
		if count == MAX_BARS or used[id] then return end
		count = count + 1
		used[id] = true
		SetRow(rows[count], id, color)
	end

	for _, data in ipairs(spec.bars) do
		local id = PickSpell(data.ids)
		if id then Add(id, data.color) end
	end
	for _, id in ipairs(ViewerSpells(Enum.CooldownViewerCategory.Utility)) do
		if Known(id) then Add(id, cfg.fillColor) end
	end

	for i, row in ipairs(rows) do row:SetShown(i <= count) end
	return used
end

local function UpdateRow(row)
	if not row:IsShown() then return end
	local id = row.spellID

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

-- A rotációs sor a spec saját listája, ahol nincs, ott a játéké a sávokon lévők nélkül.
local function IconSpells(spec, used)
	local spells, seen = {}, {}
	for _, id in ipairs(spec.icons or ViewerSpells(Enum.CooldownViewerCategory.Essential)) do
		if Known(id) and not seen[id] and (spec.icons or not used[id]) then
			seen[id] = true
			table.insert(spells, id)
		end
	end
	return spells
end

local function LayoutIcons(spec, used)
	local step = cfg.iconSize + cfg.iconGap
	local width = Width()
	local fit = math.min(MAX_ICONS, math.floor((width + cfg.iconGap) / step))

	local known = {}
	for _, f in ipairs(icons) do f:Hide() end
	for i, id in ipairs(IconSpells(spec, used)) do
		if i > fit then break end
		icons[i].spellID = id
		table.insert(known, icons[i])
	end

	local startX = (width - (#known * step - cfg.iconGap)) / 2
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
	local spec = CurrentSpec()
	LayoutIcons(spec, AssignRows(spec))
	UpdateAll()
end

local function Resize()
	local width = Width()
	barFrame:SetWidth(width)
	iconFrame:SetWidth(width)
	for _, row in ipairs(rows) do row:SetWidth(width) end
	Refresh()
end

ns.On('PLAYER_LOGIN', function()
	formatter = C_StringUtil.CreateSecondsFormatter()
	formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
	formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
	zero = C_DurationUtil.CreateDuration()

	barFrame = CreateFrame('Frame', 'SlimARK_CooldownBars', UIParent)
	barFrame:SetSize(Width(), MAX_BARS * (cfg.rowH + cfg.gap))
	ns.Register(barFrame, cfg.x, cfg.y, { key = 'cooldownbars', heal = { x = cfg.heal.x, y = cfg.heal.y } })
	for i = 1, MAX_BARS do
		rows[i] = CreateRow(barFrame, i)
	end

	iconFrame = CreateFrame('Frame', 'SlimARK_CooldownIcons', UIParent)
	iconFrame:SetSize(Width(), cfg.iconSize)
	ns.Register(iconFrame, cfg.x, cfg.iconY, { key = 'cooldownicons', heal = { x = cfg.heal.x, y = cfg.heal.iconY } })
	for i = 1, MAX_ICONS do
		icons[i] = CreateIcon(iconFrame)
	end

	Refresh()
	ns.On('SPELL_UPDATE_COOLDOWN', UpdateAll)
	ns.On('SPELL_UPDATE_CHARGES', UpdateAll)
	ns.On('SPELLS_CHANGED', Refresh)
	ns.On('PLAYER_TALENT_UPDATE', Refresh)
	ns.On('TRAIT_CONFIG_UPDATED', Refresh)
	ns.On('PLAYER_ENTERING_WORLD', Refresh)
	ns.On('PLAYER_SPECIALIZATION_CHANGED', Refresh)
	ns.On('COOLDOWN_VIEWER_DATA_LOADED', Refresh)
	ns.OnRole(Resize)
end)
