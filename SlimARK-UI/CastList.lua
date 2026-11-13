local _, ns = ...
local C = ns.C

------------------------------------------------------------------------
-- 1: every enemy cast in one column above the focus frame (spell, who it is aimed at, time left),
-- and a red YOU on the player frame while a cast is aimed at you. The casts come from the
-- nameplate units. The game hides the spell, the target and the times of other units' casts, so
-- they only go to the widgets: the bar runs on the cast's duration object, the time on a duration
-- text binding, the names go to SetText, "it is you", "important" and "not interruptible" go to
-- the calls that take hidden values. No timer runs; the cast events drive everything.
------------------------------------------------------------------------
local casts = {}   -- unit -> cast entry
local order = {}   -- the casting units, oldest first
local column, header
local rows = {}
local youMark
local youFree, youUsed = {}, {}
local formatter
local testing = false
local queued = false

local MUTED = { 0.6, 0.61, 0.65 }
local YOU_RED = { 1, 0.23, 0.19 }

local function Enabled()
	return C.features.castList or C.features.castYou
end

-- The time left like the nameplate cast bars: tenths under a minute.
local function Formatter()
	if formatter or not C_StringUtil then return formatter end
	formatter = C_StringUtil.CreateSecondsFormatter()
	formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
	formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
	formatter:SetMillisecondsThreshold(60)
	return formatter
end

------------------------------------------------------------------------
-- The column: a header and up to max rows, the first row right above the focus frame.
------------------------------------------------------------------------
local function CreateRow(index)
	local cfg = C.castlist
	local row = CreateFrame('StatusBar', nil, column)
	row:SetSize(cfg.w, cfg.rowH)
	row:SetStatusBarTexture(ns.TEX)
	row:SetPoint('BOTTOMLEFT', column, 'BOTTOMLEFT', 0, (index - 1) * (cfg.rowH + cfg.gap))
	ns.Outline(row)
	ns.Track(row)
	ns.Gloss(row)
	-- Not interruptible: the gray cover of the plate bars.
	local shield = row:CreateTexture(nil, 'OVERLAY', nil, 0)
	shield:SetTexture(ns.TEX)
	local g = C.colors.notInterruptible
	shield:SetVertexColor(g[1], g[2], g[3], 0.95)
	shield:SetAllPoints()
	shield:SetAlpha(0)
	row.Shield = shield
	row.Time = ns.Text(row, cfg.font, 'RIGHT')
	row.Time:SetPoint('RIGHT', -6, 0)
	row.Target = ns.Text(row, cfg.font - 1, 'RIGHT')
	row.Target:SetPoint('RIGHT', row.Time, 'LEFT', -8, 0)
	row.You = ns.Text(row, cfg.font - 1, 'RIGHT')
	row.You:SetPoint('RIGHT', row.Target, 'RIGHT')
	row.You:SetText('YOU')
	row.You:SetTextColor(YOU_RED[1], YOU_RED[2], YOU_RED[3])
	row.You:SetAlpha(0)
	row.Text = ns.Text(row, cfg.font)
	row.Text:SetPoint('LEFT', 6, 0)
	row.Text:SetPoint('RIGHT', row.Target, 'LEFT', -6, 0)
	if C_DurationUtil and Formatter() then
		row.binding = C_DurationUtil.CreateDurationTextBinding()
		row.binding:SetFormatter(Formatter())
		row.binding:SetFontString(row.Time)
	end
	-- The same colors as the plate bars, dark while your interrupt is on cooldown.
	if ns.EnemyCastBar then ns.EnemyCastBar(row) end
	row:Hide()
	return row
end

local function Column()
	if column then return column end
	local cfg = C.castlist
	local height = 14 + cfg.max * (cfg.rowH + cfg.gap)
	column = CreateFrame('Frame', 'SlimARK_CastList', UIParent)
	column:SetSize(cfg.w, height)
	ns.Register(column, cfg.x, cfg.y, { key = 'castlist', w = cfg.w, h = height, heal = { x = cfg.heal.x, y = cfg.heal.y } })
	header = ns.Text(column, 12)
	header:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	header:SetText('ENEMY CASTS')
	header:Hide()
	for i = 1, cfg.max do rows[i] = CreateRow(i) end
	return column
end

local function CastDuration(entry)
	local unit = entry.unit
	if entry.channel and UnitChannelDuration then return UnitChannelDuration(unit) end
	return UnitCastingDuration and UnitCastingDuration(unit)
end

-- Who the cast is aimed at: the name in class color, a red YOU when it is you, a gray - for none.
local function ShowTarget(row, unit)
	if UnitShouldDisplaySpellTargetName and UnitShouldDisplaySpellTargetName(unit) then
		local class = UnitSpellTargetClass(unit)
		local color = type(class) ~= 'nil' and C_ClassColor.GetClassColor(class)
		row.Target:SetText(UnitSpellTargetName(unit))
		if color then row.Target:SetTextColor(color.r, color.g, color.b) else row.Target:SetTextColor(1, 1, 1) end
		local onMe = PlayerIsSpellTarget(unit)
		row.Target:SetAlphaFromBoolean(onMe, 0, 1)
		row.You:SetAlphaFromBoolean(onMe, 1, 0)
	else
		row.Target:SetText('-')
		row.Target:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		row.Target:SetAlpha(1)
		row.You:SetAlpha(0)
	end
end

local function PaintRow(row, entry)
	local duration = CastDuration(entry)
	if duration then
		-- A channel runs down, a cast fills up, as on the plates.
		local direction = entry.channel and Enum.StatusBarTimerDirection.RemainingTime
			or Enum.StatusBarTimerDirection.ElapsedTime
		row:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
		if row.binding then
			row.binding:SetDuration(duration)
			row.binding:SetEnabled(true)
		end
	end
	row.Text:SetText(entry.name)
	row.Shield:SetAlphaFromBoolean(entry.notInterruptible, 1, 0)
	row.isImportant = entry.important
	row.casting = true
	row:Show()
	if ns.PaintCast then ns.PaintCast(row) end
	ShowTarget(row, entry.unit)
end

local function ClearRow(row)
	row.casting = nil
	if row.binding then row.binding:SetEnabled(false) end
	row:Hide()
end

-- The first max casts get a row, the first row at the bottom. The header sits above the top one.
local function Layout()
	queued = false
	if testing or not C.features.castList then return end
	Column()
	local shown = 0
	for i, row in ipairs(rows) do
		local entry = casts[order[i]]
		if entry then
			shown = i
			PaintRow(row, entry)
		else
			ClearRow(row)
		end
	end
	header:SetShown(shown > 0)
	if shown > 0 then
		header:ClearAllPoints()
		header:SetPoint('BOTTOMLEFT', rows[shown], 'TOPLEFT', 0, 3)
	end
end

-- Several casts start and stop in one frame on a pull: the column is laid out once, on the next frame.
local function QueueLayout()
	if queued or not C.features.castList then return end
	queued = true
	C_Timer.After(0, Layout)
end

------------------------------------------------------------------------
-- The YOU mark on the player frame. "Aimed at you" is a hidden value per cast, and hidden values
-- cannot be added up: every cast gets a layer of its own on the same spot, and the game shows the
-- layers of the casts that are aimed at you. The layers look the same, so one or three read YOU.
------------------------------------------------------------------------
function ns.AddYouMark(frame)
	if youMark then return end
	youMark = CreateFrame('Frame', nil, frame)
	youMark:SetSize(40, 16)
	youMark:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', 2, 0)
	youMark:SetFrameLevel(frame:GetFrameLevel() + 20)
	frame.YouMark = youMark
end

local function YouLayer()
	local layer = table.remove(youFree)
	if not layer then
		layer = CreateFrame('Frame', nil, youMark)
		layer:SetAllPoints()
		local bg = layer:CreateTexture(nil, 'BACKGROUND')
		bg:SetAllPoints()
		bg:SetColorTexture(YOU_RED[1], YOU_RED[2], YOU_RED[3], 1)
		ns.Outline(layer)
		local text = ns.Text(layer, 12, 'CENTER')
		text:SetPoint('CENTER', 0, 0)
		text:SetText('YOU')
		layer.text = text
	end
	layer:SetAlpha(0)
	layer:Show()
	return layer
end

local function FreeLayer(layer)
	layer:SetAlpha(0)
	layer:Hide()
	youUsed[layer] = nil
	table.insert(youFree, layer)
end

------------------------------------------------------------------------
-- Tracking the casts.
------------------------------------------------------------------------
local function IsPlate(unit)
	return type(unit) == 'string' and unit:sub(1, 9) == 'nameplate'
end

-- Only clearly friendly plates are left out; a hidden answer keeps the cast.
local function Hostile(unit)
	local attackable = UnitCanAttack('player', unit)
	if issecretvalue(attackable) then return true end
	return attackable and true or false
end

local function Remove(unit)
	local entry = casts[unit]
	if not entry then return end
	casts[unit] = nil
	for i, u in ipairs(order) do
		if u == unit then
			table.remove(order, i)
			break
		end
	end
	if entry.you then FreeLayer(entry.you) end
	QueueLayout()
end

local function Start(unit)
	if not Hostile(unit) then return Remove(unit) end
	local name, text, _, _, _, _, _, notInterruptible, spellID = UnitCastingInfo(unit)
	local channel = false
	if type(name) == 'nil' then
		name, text, _, _, _, _, notInterruptible, spellID = UnitChannelInfo(unit)
		channel = true
	end
	-- type() is the existence test a hidden value allows.
	if type(name) == 'nil' then return Remove(unit) end
	if type(text) ~= 'nil' then name = text end
	local entry = casts[unit]
	if not entry then
		entry = { unit = unit }
		casts[unit] = entry
		table.insert(order, unit)
	end
	entry.name, entry.notInterruptible, entry.channel = name, notInterruptible, channel
	-- A hidden flag is only assigned, never tested: the row's color call takes it as it is.
	entry.important = false
	if C_Spell.IsSpellImportant then entry.important = C_Spell.IsSpellImportant(spellID) end
	if youMark and C.features.castYou then
		entry.you = entry.you or YouLayer()
		youUsed[entry.you] = true
		entry.you:SetAlphaFromBoolean(PlayerIsSpellTarget(unit), 1, 0)
	end
	QueueLayout()
end

-- After a stop the cast is gone unless the unit already casts the next one.
local function Check(unit)
	if not casts[unit] then return end
	if type((UnitCastingInfo(unit))) == 'nil' and type((UnitChannelInfo(unit))) == 'nil' then Remove(unit) end
end

local function ClearAll()
	for unit in pairs(casts) do Remove(unit) end
end

local START = {
	UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_EMPOWER_START = true,
	UNIT_SPELLCAST_DELAYED = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true, UNIT_SPELLCAST_EMPOWER_UPDATE = true,
	UNIT_SPELLCAST_INTERRUPTIBLE = true, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
}
local STOP = {
	UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_EMPOWER_STOP = true,
	UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true,
}

local function OnEvent(_, event, unit)
	if event == 'PLAYER_ENTERING_WORLD' then return ClearAll() end
	if not IsPlate(unit) then return end
	if START[event] then
		Start(unit)
	elseif STOP[event] then
		Check(unit)
	elseif event == 'NAME_PLATE_UNIT_ADDED' then
		-- A plate that comes into view while its mob casts.
		if type((UnitCastingInfo(unit))) ~= 'nil' or type((UnitChannelInfo(unit))) ~= 'nil' then Start(unit) end
	elseif event == 'NAME_PLATE_UNIT_REMOVED' then
		Remove(unit)
	end
end

------------------------------------------------------------------------
-- Test mode: the column shows made-up casts, the YOU mark shows.
------------------------------------------------------------------------
local TEST_CASTS = {
	{ 'Shadow Bolt Volley', 0.64, true, 'you-class', '1.2s' },
	{ 'Void Lash', 0.38, false, 'YOU', '2.0s' },
	{ 'Mend Flesh', 0.2, false, nil, '2.6s' },
}

local function Test(on)
	testing = on
	if on then
		if C.features.castList then
			Column()
			for i, row in ipairs(rows) do
				local cast = TEST_CASTS[i]
				if cast then
					if row.binding then row.binding:SetEnabled(false) end
					row:SetMinMaxValues(0, 1)
					row:SetValue(cast[2])
					local c = cast[3] and C.colors.important or C.colors.enemyCast
					row:GetStatusBarTexture():SetVertexColor(c[1], c[2], c[3])
					row.Shield:SetAlpha(0)
					row.Text:SetText(cast[1])
					row.Time:SetText(cast[5])
					row.You:SetAlpha(cast[4] == 'YOU' and 1 or 0)
					row.Target:SetAlpha(cast[4] == 'YOU' and 0 or 1)
					if cast[4] == 'you-class' then
						local _, class = UnitClass('player')
						local color = C_ClassColor.GetClassColor(class)
						row.Target:SetText(UnitName('player'))
						if color then row.Target:SetTextColor(color.r, color.g, color.b) end
					else
						row.Target:SetText('-')
						row.Target:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
					end
					row:Show()
				else
					row:Hide()
				end
			end
			header:ClearAllPoints()
			header:SetPoint('BOTTOMLEFT', rows[#TEST_CASTS], 'TOPLEFT', 0, 3)
			header:Show()
		end
		if youMark then
			youMark.test = youMark.test or YouLayer()
			youMark.test:SetAlpha(1)
		end
	else
		if youMark and youMark.test then
			FreeLayer(youMark.test)
			youMark.test = nil
		end
		if column then
			for _, row in ipairs(rows) do ClearRow(row) end
			header:Hide()
			Layout()
		end
	end
end

------------------------------------------------------------------------
-- 12: a short, quiet sound each time your focus starts a cast. Whether it can be interrupted is
-- hidden, so every cast counts. A clearly friendly focus makes no sound.
------------------------------------------------------------------------
local FOCUS_SOUND = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889

local function WatchFocus()
	local watch = CreateFrame('Frame')
	watch:RegisterUnitEvent('UNIT_SPELLCAST_START', 'focus')
	watch:RegisterUnitEvent('UNIT_SPELLCAST_CHANNEL_START', 'focus')
	watch:SetScript('OnEvent', function()
		if not Hostile('focus') then return end
		PlaySound(FOCUS_SOUND, 'SFX')
	end)
end

ns.On('PLAYER_LOGIN', function()
	if C.features.focusSound then WatchFocus() end
	if not Enabled() then return end
	local watch = CreateFrame('Frame')
	for event in pairs(START) do watch:RegisterEvent(event) end
	for event in pairs(STOP) do watch:RegisterEvent(event) end
	watch:RegisterEvent('NAME_PLATE_UNIT_ADDED')
	watch:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
	watch:RegisterEvent('PLAYER_ENTERING_WORLD')
	watch:SetScript('OnEvent', OnEvent)
	if C.features.castList then Column() end
	ns.TestParts = ns.TestParts or {}
	table.insert(ns.TestParts, Test)
end)
