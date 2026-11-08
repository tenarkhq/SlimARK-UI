local _, ns = ...
local S = ns.Settings

-- The /slimark panel: sections listed on the left, the chosen one's settings on the
-- right, search in the header, save and resets in the footer. Values are in
-- real pixels, like Config.lua. Changes apply after the reload that saving does.
local W, H, NAV, BAR = 980, 640, 210, 46
local PAD = 22
local GOLD = { 0.95, 0.72, 0.29 }
local TEXT = { 0.95, 0.95, 0.96 }
local SOFT = { 0.84, 0.84, 0.86 }
local MUTED = { 0.6, 0.61, 0.65 }
local GREY = { 0.43, 0.44, 0.47 }
local PANEL = { 0.063, 0.067, 0.082 }
local PANEL2 = { 0.086, 0.09, 0.11 }
local NAVBG = { 0.051, 0.055, 0.067 }
local TRACK = { 0.137, 0.145, 0.169 }
local HAIR = { 0.17, 0.18, 0.21 }

local panel, navScroll, navChild, mainScroll, mainChild, stateText, saveButton, searchBox
local current = 'party'
local query = ''

local function Fill(frame, color, alpha, layer, sublevel)
	local t = frame:CreateTexture(nil, layer or 'BACKGROUND', nil, sublevel or 0)
	t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
	t:SetAllPoints()
	return t
end

local function Text(parent, size, color, justify)
	local fs = ns.Text(parent, size, justify)
	fs:SetFont(ns.FONT, size, '')
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 0.9)
	color = color or TEXT
	fs:SetTextColor(color[1], color[2], color[3])
	return fs
end

local function Hex(c)
	return ('#%02x%02x%02x'):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function Format(value, step)
	if step >= 1 then return tostring(math.floor(value + 0.5)) end
	local text = ('%.2f'):format(value):gsub('0+$', ''):gsub('%.$', '')
	return text
end

local function Round(value, row)
	value = math.max(row.min, math.min(row.max, value))
	value = math.floor(value / row.step + 0.5) * row.step
	return tonumber(('%.2f'):format(value))
end

-- A flat button: gold for the main action, plain, or ghost (text only).
local function MakeButton(parent, label, width, height, style)
	local b = CreateFrame('Button', nil, parent)
	b:SetSize(width, height)
	local base = style == 'gold' and GOLD or TRACK
	if style ~= 'ghost' then
		b.bg = Fill(b, base)
		ns.Outline(b)
	end
	b.text = Text(b, 13, style == 'gold' and { 0.1, 0.08, 0.03 } or (style == 'ghost' and MUTED or TEXT), 'CENTER')
	if style == 'gold' then b.text:SetShadowOffset(0, 0) end
	b.text:SetPoint('CENTER')
	b.text:SetText(label)
	b:SetScript('OnEnter', function(self)
		if style == 'ghost' then self.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		elseif self.bg then self.bg:SetColorTexture(math.min(1, base[1] + 0.06), math.min(1, base[2] + 0.06), math.min(1, base[3] + 0.06), 1) end
	end)
	b:SetScript('OnLeave', function(self)
		if style == 'ghost' then self.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		elseif self.bg then self.bg:SetColorTexture(base[1], base[2], base[3], 1) end
	end)
	return b
end

-- A scroll area moved by the mouse wheel, with a thin position line at its right edge.
local function MakeScroll(parent)
	local scroll = CreateFrame('ScrollFrame', nil, parent)
	local child = CreateFrame('Frame', nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	local thumb = scroll:CreateTexture(nil, 'OVERLAY')
	thumb:SetColorTexture(1, 1, 1, 0.18)
	thumb:SetWidth(3)
	scroll.thumb = thumb
	function scroll:UpdateThumb()
		local view, total = self:GetHeight(), child:GetHeight()
		if total <= view + 1 then thumb:Hide() return end
		local h = math.max(24, view * view / total)
		local y = (view - h) * self:GetVerticalScroll() / (total - view)
		thumb:SetHeight(h)
		thumb:ClearAllPoints()
		thumb:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -2, -y)
		thumb:Show()
	end
	function scroll:ScrollTo(offset)
		local max = math.max(0, child:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, offset)))
		self:UpdateThumb()
	end
	scroll:EnableMouseWheel(true)
	scroll:SetScript('OnMouseWheel', function(self, delta) self:ScrollTo(self:GetVerticalScroll() - delta * 60) end)
	scroll:SetScript('OnSizeChanged', function(self, width) child:SetWidth(width) self:UpdateThumb() end)
	return scroll, child
end

-- Widgets are made once and reused on every redraw.
local pools = {}
local function Acquire(kind, parent, make)
	local pool = pools[kind]
	if not pool then
		pool = { items = {}, used = 0 }
		pools[kind] = pool
	end
	pool.used = pool.used + 1
	local item = pool.items[pool.used]
	if not item then
		item = make(parent)
		pool.items[pool.used] = item
	end
	item:SetParent(parent)
	item:ClearAllPoints()
	item:Show()
	return item
end
local function ReleaseAll(kinds)
	for _, kind in ipairs(kinds) do
		local pool = pools[kind]
		if pool then
			for _, item in ipairs(pool.items) do item:Hide() end
			pool.used = 0
		end
	end
end

-- Search: a page, section or setting whose name holds the typed text.
local function Has(text)
	return query == '' or (text or ''):lower():find(query, 1, true) ~= nil
end
local function RowMatches(page, sec, row)
	return Has(page.name) or Has(sec.name) or Has(row.label)
end
local function PageMatches(page)
	if Has(page.name) or Has(page.group) then return true end
	if page.about then return Has('version changelog') end
	for _, sec in ipairs(page.secs or {}) do
		for _, row in ipairs(sec.rows) do
			if RowMatches(page, sec, row) then return true end
		end
	end
	return false
end

local function FindPage(id)
	for _, group in ipairs(S.groups) do
		for _, page in ipairs(group.pages) do
			if page.id == id then return page end
		end
	end
end

local function PageChanged(page)
	if page.module and S.IsChanged(page.module) then return true end
	for _, sec in ipairs(page.secs or {}) do
		for _, row in ipairs(sec.rows) do
			if row.path and S.defaults[row.path] ~= nil and S.IsChanged(row.path) then return true end
		end
	end
	return false
end

local RenderMain, RenderNav

local function RenderState()
	local n = S.PendingCount()
	if n == 0 then
		stateText:SetText('No changes')
		stateText:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		saveButton:SetAlpha(0.45)
	else
		stateText:SetText(('%d change%s not saved yet. They apply after the reload.'):format(n, n > 1 and 's' or ''))
		stateText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		saveButton:SetAlpha(1)
	end
end

-- After one value changed: the row, the dots in the list and the footer.
local function Changed(row)
	if row and row.Refresh then row:Refresh() end
	RenderNav()
	RenderState()
end

-- Navigation list.
local function NavButton(parent)
	local b = CreateFrame('Button', nil, parent)
	b:SetHeight(24)
	b.bg = Fill(b, GOLD, 0.16)
	b.bar = b:CreateTexture(nil, 'ARTWORK')
	b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	b.bar:SetPoint('TOPLEFT')
	b.bar:SetPoint('BOTTOMLEFT')
	b.bar:SetWidth(2)
	b.text = Text(b, 14, SOFT)
	b.text:SetPoint('LEFT', 16, 0)
	b.dot = b:CreateTexture(nil, 'ARTWORK')
	b.dot:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	b.dot:SetSize(6, 6)
	b.dot:SetPoint('RIGHT', -14, 0)
	b.hover = Fill(b, { 1, 1, 1 }, 0.04, 'HIGHLIGHT')
	b:SetScript('OnClick', function(self)
		current = self.pageID
		mainScroll:ScrollTo(0)
		RenderNav()
		RenderMain()
	end)
	return b
end

local function GroupLabel(parent)
	local fs = Text(parent, 11, MUTED)
	return fs
end

RenderNav = function()
	ReleaseAll({ 'nav', 'navgroup' })
	local y = -8
	local width = NAV - 1
	for _, group in ipairs(S.groups) do
		local shown = {}
		for _, page in ipairs(group.pages) do
			if PageMatches(page) then table.insert(shown, page) end
		end
		if #shown > 0 then
			local label = Acquire('navgroup', navChild, function(p)
				local f = CreateFrame('Frame', nil, p)
				f:SetSize(width, 22)
				f.text = GroupLabel(f)
				f.text:SetPoint('BOTTOMLEFT', 16, 4)
				return f
			end)
			label:SetPoint('TOPLEFT', 0, y)
			label.text:SetText(group.name:upper())
			y = y - 22
			for _, page in ipairs(shown) do
				local b = Acquire('nav', navChild, NavButton)
				b:SetPoint('TOPLEFT', 0, y)
				b:SetWidth(width)
				b.pageID = page.id
				b.text:SetText(page.name)
				local on = page.id == current
				local off = page.module and not S.Value(page.module)
				b.bg:SetShown(on)
				b.bar:SetShown(on)
				local color = on and GOLD or (off and GREY or SOFT)
				b.text:SetTextColor(color[1], color[2], color[3])
				b.dot:SetShown(not page.about and PageChanged(page))
				y = y - 24
			end
		end
	end
	navChild:SetHeight(-y + 8)
	navScroll:UpdateThumb()
end

-- Rows of the settings page.
local ROW_H, LABEL_W = 30, 118

local function RowBase(parent)
	local row = CreateFrame('Frame', nil, parent)
	row:SetHeight(ROW_H)
	row.label = Text(row, 13, SOFT)
	row.label:SetPoint('LEFT')
	row.label:SetWidth(LABEL_W)
	row.reset = CreateFrame('Button', nil, row)
	row.reset:SetSize(36, 20)
	row.reset:SetPoint('RIGHT')
	row.reset.text = Text(row.reset, 11, GOLD, 'RIGHT')
	row.reset.text:SetPoint('RIGHT')
	row.reset.text:SetText('Reset')
	row.reset:SetScript('OnClick', function()
		S.Set(row.data.path, S.defaults[row.data.path])
		Changed(row)
	end)
	row.reset:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_TOP')
		local default = S.defaults[row.data.path]
		local text = type(default) == 'table' and Hex(default) or (type(default) == 'boolean' and (default and 'on' or 'off') or Format(default, row.data.step or 1))
		GameTooltip:SetText('Back to ' .. text)
		GameTooltip:Show()
	end)
	row.reset:SetScript('OnLeave', GameTooltip_Hide)
	function row:Mark()
		local changed = S.IsChanged(self.data.path)
		local color = changed and GOLD or SOFT
		self.label:SetTextColor(color[1], color[2], color[3])
		self.reset:SetShown(changed)
	end
	return row
end

local function RangeRow(parent)
	local row = RowBase(parent)
	local slider = CreateFrame('Slider', nil, row)
	slider:SetOrientation('HORIZONTAL')
	slider:SetHeight(16)
	slider:SetObeyStepOnDrag(true)
	slider:SetPoint('LEFT', LABEL_W + 10, 0)
	slider:SetPoint('RIGHT', -(36 + 56 + 20), 0)
	local track = slider:CreateTexture(nil, 'BACKGROUND')
	track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], 1)
	track:SetHeight(6)
	track:SetPoint('LEFT')
	track:SetPoint('RIGHT')
	local edge = slider:CreateTexture(nil, 'BACKGROUND', nil, -1)
	edge:SetColorTexture(0, 0, 0, 1)
	edge:SetPoint('TOPLEFT', track, -1, 1)
	edge:SetPoint('BOTTOMRIGHT', track, 1, -1)
	local thumb = slider:CreateTexture(nil, 'OVERLAY')
	thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	thumb:SetSize(10, 16)
	slider:SetThumbTexture(thumb)
	row.slider = slider

	local box = CreateFrame('EditBox', nil, row)
	box:SetSize(56, 22)
	box:SetPoint('RIGHT', -(36 + 10), 0)
	box:SetAutoFocus(false)
	box:SetFont(ns.FONT, 13, '')
	box:SetJustifyH('RIGHT')
	box:SetTextInsets(4, 6, 0, 0)
	box:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	Fill(box, TRACK)
	ns.Outline(box)
	row.box = box

	function row:Refresh()
		local data = self.data
		local value = S.Value(data.path)
		self.slider:SetValue(value)
		if not self.box:HasFocus() then self.box:SetText(Format(value, data.step)) end
		self:Mark()
	end
	slider:SetScript('OnValueChanged', function(_, value, userInput)
		if not userInput then return end
		value = Round(value, row.data)
		S.Set(row.data.path, value)
		box:SetText(Format(value, row.data.step))
		Changed(row)
	end)
	local function Commit()
		local value = tonumber(box:GetText())
		if value then S.Set(row.data.path, Round(value, row.data)) end
		box:ClearFocus()
		Changed(row)
	end
	box:SetScript('OnEnterPressed', Commit)
	box:SetScript('OnTabPressed', Commit)
	box:SetScript('OnEscapePressed', function(self) self:ClearFocus() row:Refresh() end)
	box:SetScript('OnEditFocusLost', function() row:Refresh() end)
	return row
end

local function ToggleRow(parent)
	local row = RowBase(parent)
	local switch = CreateFrame('Button', nil, row)
	switch:SetSize(34, 18)
	switch:SetPoint('LEFT', LABEL_W + 10, 0)
	switch.bg = Fill(switch, TRACK)
	ns.Outline(switch)
	switch.knob = switch:CreateTexture(nil, 'ARTWORK')
	switch.knob:SetSize(12, 12)
	row.switch = switch
	-- Toggles have longer labels: they get the room the slider would take.
	row.label:SetWidth(0)
	row.label:ClearAllPoints()
	row.label:SetPoint('LEFT', switch, 'RIGHT', 10, 0)
	row.label:SetPoint('RIGHT', row.reset, 'LEFT', -6, 0)
	switch:ClearAllPoints()
	switch:SetPoint('LEFT')
	function row:Refresh()
		local on = S.Value(self.data.path)
		local knob = self.switch.knob
		knob:ClearAllPoints()
		if on then
			knob:SetPoint('RIGHT', -3, 0)
			knob:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
			self.switch.bg:SetColorTexture(0.23, 0.18, 0.09, 1)
		else
			knob:SetPoint('LEFT', 3, 0)
			knob:SetColorTexture(GREY[1], GREY[2], GREY[3], 1)
			self.switch.bg:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], 1)
		end
		self:Mark()
	end
	switch:SetScript('OnClick', function()
		S.Set(row.data.path, not S.Value(row.data.path))
		Changed(row)
		-- A module switch greys its page in the list and changes the enable box.
		if row.data.isModule then RenderMain() end
	end)
	return row
end

local function ColorRow(parent)
	local row = RowBase(parent)
	row.hex = Text(row, 12, MUTED)
	row.hex:SetPoint('LEFT', LABEL_W + 10, 0)
	local swatch = CreateFrame('Button', nil, row)
	swatch:SetSize(56, 22)
	swatch:SetPoint('RIGHT', -(36 + 10), 0)
	swatch.fill = Fill(swatch, { 1, 1, 1 })
	ns.Outline(swatch)
	row.swatch = swatch
	function row:Refresh()
		local c = S.Value(self.data.path)
		self.swatch.fill:SetColorTexture(c[1], c[2], c[3], 1)
		self.hex:SetText(Hex(c))
		self:Mark()
	end
	swatch:SetScript('OnClick', function()
		local path = row.data.path
		local c = S.Value(path)
		ColorPickerFrame:SetupColorPickerAndShow({
			r = c[1], g = c[2], b = c[3],
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				S.Set(path, { r, g, b })
				Changed(row)
			end,
			cancelFunc = function(previous)
				if previous then S.Set(path, { previous.r, previous.g, previous.b }) end
				Changed(row)
			end,
		})
	end)
	return row
end

local function ButtonRow(parent)
	local row = CreateFrame('Frame', nil, parent)
	row:SetHeight(ROW_H)
	row.button = MakeButton(row, '', 170, 24, 'plain')
	row.button:SetPoint('LEFT')
	row.button:SetScript('OnClick', function() if row.data.fn then row.data.fn() end end)
	function row:Refresh() self.button.text:SetText(self.data.label) end
	return row
end

local MAKERS = { range = RangeRow, toggle = ToggleRow, color = ColorRow, button = ButtonRow }

local function SectionHeader(parent)
	local f = CreateFrame('Frame', nil, parent)
	f:SetHeight(24)
	f.text = Text(f, 12, GOLD)
	f.text:SetPoint('TOPLEFT')
	local line = f:CreateTexture(nil, 'ARTWORK')
	line:SetColorTexture(HAIR[1], HAIR[2], HAIR[3], 1)
	line:SetHeight(1)
	line:SetPoint('BOTTOMLEFT')
	line:SetPoint('BOTTOMRIGHT')
	return f
end

local function Paragraph(parent)
	local fs = Text(parent, 13, MUTED)
	fs:SetWordWrap(true)
	fs:SetJustifyV('TOP')
	return fs
end

local header = {}
local function PageHeader()
	if header.title then return end
	header.title = Text(mainChild, 22, TEXT)
	header.group = Text(mainChild, 12, MUTED)
	header.reset = MakeButton(mainChild, 'Reset page', 90, 24, 'ghost')
	header.reset:SetScript('OnClick', function()
		local page = FindPage(current)
		local paths = {}
		if page.module then table.insert(paths, page.module) end
		for _, sec in ipairs(page.secs or {}) do
			for _, row in ipairs(sec.rows) do
				if row.path and S.defaults[row.path] ~= nil then table.insert(paths, row.path) end
			end
		end
		S.ResetPaths(paths)
		RenderMain()
		RenderNav()
		RenderState()
	end)
	header.enableBox = CreateFrame('Frame', nil, mainChild)
	header.enableBox:SetHeight(38)
	Fill(header.enableBox, PANEL2)
	ns.Outline(header.enableBox)
end

-- The About page: version, commands and the changelog.
local function RenderAbout(width)
	local y = -16
	local function Line(textA, textB)
		local a = Acquire('aboutkey', mainChild, function(p) return Text(p, 13, MUTED) end)
		a:SetPoint('TOPLEFT', PAD, y)
		a:SetText(textA)
		local b = Acquire('aboutval', mainChild, function(p) local fs = Text(p, 13, TEXT) fs:SetWordWrap(true) return fs end)
		b:SetPoint('TOPLEFT', PAD + 140, y)
		b:SetWidth(width - 140)
		b:SetText(textB)
		y = y - math.max(20, b:GetStringHeight() + 6)
	end
	header.title:SetPoint('TOPLEFT', PAD, y)
	header.title:SetText('SlimARK-UI')
	header.group:SetPoint('BOTTOMLEFT', header.title, 'BOTTOMRIGHT', 12, 3)
	header.group:SetText('About')
	header.reset:Hide()
	y = y - 40
	Line('Version', ns.version)
	Line('Game', 'World of Warcraft Retail, Midnight')
	Line('Layout made for', '2560x1600, UI scale 65%')
	Line('Commands', '/slimark opens this panel, /slimark apply sets up the layout, /rl reloads the UI')
	Line('Bugs', 'github.com/tenarkhq/SlimARK-UI/issues')
	y = y - 10
	local sec = Acquire('section', mainChild, SectionHeader)
	sec:SetPoint('TOPLEFT', PAD, y)
	sec:SetWidth(width)
	sec.text:SetText('CHANGELOG')
	y = y - 34
	for i, entry in ipairs(S.changelog) do
		local title = Acquire('abouthead', mainChild, function(p) return Text(p, 16, TEXT) end)
		title:SetPoint('TOPLEFT', PAD + 14, y)
		title:SetText(entry.version .. (entry.version == ns.version and '  |cff9a9ca5this version|r' or ''))
		local bar = Acquire('aboutbar', mainChild, function(p)
			local t = p:CreateTexture(nil, 'ARTWORK')
			return t
		end)
		local color = i == 1 and GOLD or HAIR
		bar:SetColorTexture(color[1], color[2], color[3], 1)
		bar:SetWidth(2)
		bar:SetPoint('TOPLEFT', PAD, y + 2)
		local top = y + 2
		y = y - 24
		for _, line in ipairs(entry.lines) do
			local fs = Acquire('aboutline', mainChild, function(p) local f = Text(p, 13, SOFT) f:SetWordWrap(true) return f end)
			fs:SetPoint('TOPLEFT', PAD + 14, y)
			fs:SetWidth(width - 14)
			fs:SetText('- ' .. line)
			y = y - (fs:GetStringHeight() + 5)
		end
		bar:SetHeight(top - y - 4)
		y = y - 14
	end
	return y
end

local KINDS = { 'range', 'toggle', 'color', 'button', 'section', 'para', 'aboutkey', 'aboutval', 'abouthead', 'aboutbar', 'aboutline' }

RenderMain = function()
	PageHeader()
	ReleaseAll(KINDS)
	local width = (mainScroll:GetWidth() > 0 and mainScroll:GetWidth() or (W - NAV)) - 2 * PAD
	local page = FindPage(current)
	header.title:ClearAllPoints()
	header.group:ClearAllPoints()
	header.reset:ClearAllPoints()
	header.enableBox:Hide()
	if page.about then
		local y = RenderAbout(width)
		mainChild:SetHeight(-y + PAD)
		mainScroll:UpdateThumb()
		return
	end

	local y = -16
	header.title:SetPoint('TOPLEFT', PAD, y)
	header.title:SetText(page.name)
	header.group:SetPoint('BOTTOMLEFT', header.title, 'BOTTOMRIGHT', 12, 3)
	header.group:SetText(page.group)
	header.reset:SetPoint('TOPRIGHT', -PAD + 10, y + 2)
	header.reset:Show()
	y = y - 36

	if page.desc then
		local p = Acquire('para', mainChild, Paragraph)
		p:SetPoint('TOPLEFT', PAD, y)
		p:SetWidth(math.min(width, 620))
		p:SetText(page.desc)
		y = y - (p:GetStringHeight() + 14)
	end

	if page.module then
		local box = header.enableBox
		box:SetPoint('TOPLEFT', PAD, y)
		box:SetWidth(width)
		box:Show()
		local row = Acquire('toggle', box, ToggleRow)
		row:SetPoint('LEFT', 12, 0)
		row:SetPoint('RIGHT', -12, 0)
		row.data = { path = page.module, isModule = true }
		row.label:SetText('Enable ' .. page.name:lower())
		row:Refresh()
		y = y - 38 - 16
	end

	local colW = (width - 26) / 2
	for _, sec in ipairs(page.secs or {}) do
		local rows = {}
		for _, row in ipairs(sec.rows) do
			if (not row.path or S.defaults[row.path] ~= nil) and RowMatches(page, sec, row) then table.insert(rows, row) end
		end
		if #rows > 0 then
			local h = Acquire('section', mainChild, SectionHeader)
			h:SetPoint('TOPLEFT', PAD, y)
			h:SetWidth(width)
			h.text:SetText(sec.name:upper())
			y = y - 32
			for i, data in ipairs(rows) do
				local col = (i - 1) % 2
				local line = math.floor((i - 1) / 2)
				local row = Acquire(data.t, mainChild, MAKERS[data.t])
				row:SetPoint('TOPLEFT', PAD + col * (colW + 26), y - line * (ROW_H + 6))
				row:SetWidth(colW)
				row.data = data
				if data.t == 'range' then
					row.slider:SetMinMaxValues(data.min, data.max)
					row.slider:SetValueStep(data.step)
				end
				if data.t ~= 'button' then row.label:SetText(data.label) end
				row:Refresh()
			end
			y = y - math.ceil(#rows / 2) * (ROW_H + 6) - 14
		end
	end
	mainChild:SetHeight(-y + PAD)
	mainScroll:ScrollTo(mainScroll:GetVerticalScroll())
end

local function Build()
	panel = CreateFrame('Frame', 'SlimARK_Settings', UIParent)
	panel:SetSize(W, H)
	-- The panel follows the screen size but never goes below 80%, so its text stays readable on 1080p.
	panel:SetScale(ns.Scale() / ns.Fit() * math.max(ns.Fit(), 0.8))
	panel:SetPoint('CENTER')
	panel:SetFrameStrata('DIALOG')
	panel:SetToplevel(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:Hide()
	Fill(panel, PANEL, 0.98)
	ns.Outline(panel)
	tinsert(UISpecialFrames, 'SlimARK_Settings')

	-- Header: name, version, search, close. Dragging it moves the panel.
	local head = CreateFrame('Frame', nil, panel)
	head:SetPoint('TOPLEFT')
	head:SetPoint('TOPRIGHT')
	head:SetHeight(BAR)
	Fill(head, PANEL2)
	local headLine = head:CreateTexture(nil, 'ARTWORK')
	headLine:SetColorTexture(0, 0, 0, 1)
	headLine:SetHeight(1)
	headLine:SetPoint('BOTTOMLEFT')
	headLine:SetPoint('BOTTOMRIGHT')
	head:EnableMouse(true)
	head:RegisterForDrag('LeftButton')
	head:SetScript('OnDragStart', function() panel:StartMoving() end)
	head:SetScript('OnDragStop', function() panel:StopMovingOrSizing() end)

	local brand = Text(head, 19, TEXT)
	brand:SetPoint('LEFT', 16, 0)
	brand:SetText('Slim|cfff2b84aARK|r-UI')

	local version = MakeButton(head, 'v' .. ns.version .. '  ·  Changelog', 150, 22, 'plain')
	version:SetPoint('LEFT', brand, 'RIGHT', 14, 0)
	version.text:SetFont(ns.FONT, 12, '')
	version.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	version:SetScript('OnClick', function()
		current = 'about'
		query = ''
		searchBox:SetText('')
		mainScroll:ScrollTo(0)
		RenderNav()
		RenderMain()
	end)

	local close = MakeButton(head, 'x', 26, 26, 'plain')
	close:SetPoint('RIGHT', -10, 0)
	close:SetScript('OnClick', function() panel:Hide() end)

	searchBox = CreateFrame('EditBox', nil, head)
	searchBox:SetSize(240, 26)
	searchBox:SetPoint('RIGHT', close, 'LEFT', -12, 0)
	searchBox:SetAutoFocus(false)
	searchBox:SetFont(ns.FONT, 13, '')
	searchBox:SetTextInsets(8, 8, 0, 0)
	searchBox:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	Fill(searchBox, TRACK)
	ns.Outline(searchBox)
	local hint = Text(searchBox, 13, MUTED)
	hint:SetPoint('LEFT', 8, 0)
	hint:SetText('Search settings')
	searchBox:SetScript('OnTextChanged', function(self)
		local text = strtrim(self:GetText() or '')
		hint:SetShown(text == '')
		query = text:lower()
		local page = FindPage(current)
		if not PageMatches(page) then
			for _, group in ipairs(S.groups) do
				for _, p in ipairs(group.pages) do
					if PageMatches(p) then current = p.id break end
				end
				if PageMatches(FindPage(current)) then break end
			end
		end
		RenderNav()
		RenderMain()
	end)
	searchBox:SetScript('OnEscapePressed', function(self) self:SetText('') self:ClearFocus() end)
	searchBox:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)

	-- Footer: what is waiting, the resets and saving.
	local foot = CreateFrame('Frame', nil, panel)
	foot:SetPoint('BOTTOMLEFT')
	foot:SetPoint('BOTTOMRIGHT')
	foot:SetHeight(BAR)
	Fill(foot, PANEL2)
	local footLine = foot:CreateTexture(nil, 'ARTWORK')
	footLine:SetColorTexture(0, 0, 0, 1)
	footLine:SetHeight(1)
	footLine:SetPoint('TOPLEFT')
	footLine:SetPoint('TOPRIGHT')
	stateText = Text(foot, 13, MUTED)
	stateText:SetPoint('LEFT', 16, 0)

	saveButton = MakeButton(foot, 'Save and reload UI', 160, 28, 'gold')
	saveButton:SetPoint('RIGHT', -12, 0)
	saveButton:SetScript('OnClick', function() S.Save() end)
	local undo = MakeButton(foot, 'Undo changes', 120, 28, 'plain')
	undo:SetPoint('RIGHT', saveButton, 'LEFT', -8, 0)
	undo:SetScript('OnClick', function()
		S.Undo()
		RenderNav()
		RenderMain()
		RenderState()
	end)
	local resetAll = MakeButton(foot, 'Reset everything', 130, 28, 'ghost')
	resetAll:SetPoint('RIGHT', undo, 'LEFT', -8, 0)
	resetAll:SetScript('OnClick', function()
		S.ResetAll()
		RenderNav()
		RenderMain()
		RenderState()
	end)

	-- Body: the list on the left, the page on the right.
	local navFrame = CreateFrame('Frame', nil, panel)
	navFrame:SetPoint('TOPLEFT', 0, -BAR)
	navFrame:SetPoint('BOTTOMLEFT', 0, BAR)
	navFrame:SetWidth(NAV)
	Fill(navFrame, NAVBG)
	local navLine = navFrame:CreateTexture(nil, 'ARTWORK')
	navLine:SetColorTexture(0, 0, 0, 1)
	navLine:SetWidth(1)
	navLine:SetPoint('TOPRIGHT')
	navLine:SetPoint('BOTTOMRIGHT')
	navScroll, navChild = MakeScroll(navFrame)
	navScroll:SetPoint('TOPLEFT')
	navScroll:SetPoint('BOTTOMRIGHT', -1, 0)

	mainScroll, mainChild = MakeScroll(panel)
	mainScroll:SetPoint('TOPLEFT', NAV, -BAR)
	mainScroll:SetPoint('BOTTOMRIGHT', 0, BAR)
	mainChild:SetWidth(W - NAV)
end

-- Opens the panel, or closes it when open. pageID opens that page.
function ns.OpenSettings(pageID)
	if not panel then Build() end
	if pageID and FindPage(pageID) then
		current = pageID
	elseif panel:IsShown() then
		panel:Hide()
		return
	end
	panel:SetScale(ns.Scale() / ns.Fit() * math.max(ns.Fit(), 0.8))
	panel:Show()
	RenderNav()
	RenderMain()
	RenderState()
end

-- The minimap's addon menu (AddonCompartmentFunc in the toc) opens it too.
function SlimARK_OpenSettings()
	ns.OpenSettings()
end

-- Options > AddOns > SlimARK-UI: a short page with a button that opens the panel.
ns.On('PLAYER_LOGIN', function()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local canvas = CreateFrame('Frame')
	local title = canvas:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightLarge')
	title:SetPoint('TOPLEFT', 16, -16)
	title:SetText('SlimARK-UI ' .. ns.version)
	local note = canvas:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	note:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -10)
	note:SetText('Every SlimARK-UI setting is in its own panel. You can also open it with /slimark.')
	local open = CreateFrame('Button', nil, canvas, 'UIPanelButtonTemplate')
	open:SetSize(220, 26)
	open:SetPoint('TOPLEFT', note, 'BOTTOMLEFT', 0, -14)
	open:SetText('Open SlimARK-UI settings')
	open:SetScript('OnClick', function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		if not (panel and panel:IsShown()) then ns.OpenSettings() end
	end)
	local category = Settings.RegisterCanvasLayoutCategory(canvas, 'SlimARK-UI')
	Settings.RegisterAddOnCategory(category)
end)
