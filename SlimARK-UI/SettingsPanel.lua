local _, ns = ...
local S = ns.Settings

-- The /slimark panel: the groups as tabs under the header, the chosen group's pages listed
-- on the left, the chosen page's sections as cards on the right, search in the header, save
-- and resets in the footer. The corner grip resizes it; its size and place are kept for the
-- account. Values are in real pixels, like Config.lua. Changes apply after the reload that
-- saving does.
local W, H, NAV, BAR, TAB = 1280, 800, 210, 46, 34
local MIN_W, MIN_H = 980, 640
local PAD = 22
-- Cards go into two columns from this width of the page on.
local TWO_COLUMNS, GAP, CARD_PAD, CARD_TOP = 820, 12, 12, 32
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
local tabs = {}
-- The page last open in each group: its tab opens that one again.
local lastPage = {}
-- While the corner grip is held the page is not laid out again; letting it go does that.
local sizing, relayout = false, false

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

-- The tab of the shown group is gold with a gold line under it; during a search none is.
local function RenderTabs(selected)
	for _, tab in ipairs(tabs) do
		local on = tab.group == selected
		local color = on and GOLD or MUTED
		tab.text:SetTextColor(color[1], color[2], color[3])
		tab.line:SetShown(on)
	end
end

-- Without a search the list holds the pages of the current page's group, with one the
-- matching pages of every group under their group's name.
RenderNav = function()
	ReleaseAll({ 'nav', 'navgroup' })
	local y = -8
	local width = NAV - 1
	local selected = query == '' and FindPage(current).group or nil
	for _, group in ipairs(S.groups) do
		local shown = {}
		if not selected or group.name == selected then
			for _, page in ipairs(group.pages) do
				if PageMatches(page) then table.insert(shown, page) end
			end
		end
		if #shown > 0 then
			if not selected then
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
			end
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
	RenderTabs(selected)
end

-- A tab opens the page last open in its group, its first page before that, and ends a search.
local function OpenGroup(group)
	current = lastPage[group.name] or group.pages[1].id
	if query ~= '' then
		query = ''
		searchBox:SetText('')
	end
	mainScroll:ScrollTo(0)
	RenderNav()
	RenderMain()
end

-- Rows of the settings page.
local ROW_H, LABEL_W = 30, 118

-- 3.0: a row with get/set acts on the game or on its own saved state at once, the others on a saved value.
local function Current(data)
	if data.get then return data.get() end
	return S.Value(data.path)
end

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
		-- 3.0: a row that acts at once has no saved default to go back to.
		if not self.data.path then
			self.label:SetTextColor(SOFT[1], SOFT[2], SOFT[3])
			self.reset:Hide()
			return
		end
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
		local value = Current(data) or data.min
		self.slider:SetValue(value)
		if not self.box:HasFocus() then self.box:SetText(Format(value, data.step)) end
		self:Mark()
	end
	slider:SetScript('OnValueChanged', function(_, value, userInput)
		if not userInput then return end
		value = Round(value, row.data)
		if row.data.set then row.data.set(value) else S.Set(row.data.path, value) end
		box:SetText(Format(value, row.data.step))
		Changed(row)
	end)
	local function Commit()
		local value = tonumber(box:GetText())
		if value then
			value = Round(value, row.data)
			if row.data.set then row.data.set(value) else S.Set(row.data.path, value) end
		end
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
		local on = Current(self.data)
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
		local data = row.data
		if data.set then data.set(not Current(data)) else S.Set(data.path, not S.Value(data.path)) end
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
	row.button:SetScript('OnClick', function()
		if row.data.fn then row.data.fn() end
		-- 3.0: a button whose text follows the state (Create / Update) shows the new state.
		if row.data.text then row:Refresh() end
	end)
	function row:Refresh()
		self.button.text:SetText(self.data.text and self.data.text() or self.data.label)
		self.button:SetWidth(math.max(170, math.floor(self.button.text:GetUnboundedStringWidth() + 28)))
	end
	return row
end

-- 3.0 (51, 52): a text box with a button: the profile text, the muted sound list. The button hands the
-- text and the box to the row's fn; get fills the box again.
local function TextboxRow(parent)
	local row = CreateFrame('Frame', nil, parent)
	row:SetHeight(ROW_H)
	row.label = Text(row, 13, SOFT)
	row.label:SetPoint('LEFT')
	row.label:SetWidth(LABEL_W)
	row.button = MakeButton(row, '', 110, 24, 'plain')
	row.button:SetPoint('RIGHT')
	local box = CreateFrame('EditBox', nil, row)
	box:SetHeight(24)
	box:SetPoint('LEFT', LABEL_W + 10, 0)
	box:SetPoint('RIGHT', row.button, 'LEFT', -8, 0)
	box:SetAutoFocus(false)
	box:SetMaxLetters(0)
	box:SetFont(ns.FONT, 12, '')
	box:SetTextInsets(6, 6, 0, 0)
	box:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	Fill(box, TRACK)
	ns.Outline(box)
	box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
	box:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
	row.box = box
	row.button:SetScript('OnClick', function()
		if row.data.fn then row.data.fn(box:GetText() or '', box) end
		Changed(row)
	end)
	function row:Refresh()
		self.button.text:SetText(self.data.button or 'OK')
		if self.data.get and not self.box:HasFocus() then self.box:SetText(self.data.get() or '') end
	end
	return row
end

-- A row of buttons, one of them pressed (gold). With a path it is saved like the other values,
-- with set (the test mode's choices) it acts at once.
local function ChoiceRow(parent)
	local row = CreateFrame('Frame', nil, parent)
	row:SetHeight(ROW_H)
	row.buttons = {}
	function row:Refresh()
		local current
		if self.data.get then current = self.data.get() elseif self.data.path then current = S.Value(self.data.path) end
		local x = 0
		for i, option in ipairs(self.data.options) do
			local b = self.buttons[i]
			if not b then
				b = MakeButton(self, '', 10, 26, 'plain')
				b:SetScript('OnClick', function(button)
					-- A choice with a path is saved like the other values; the test mode's acts at once.
					if self.data.set then self.data.set(button.value) elseif self.data.path then S.Set(self.data.path, button.value) end
					Changed(self)
					-- A choice other rows depend on (the Blizzard windows look) greys or wakes them.
					if self.data.rerender then RenderMain() end
				end)
				self.buttons[i] = b
			end
			b.value = option[1]
			b.text:SetText(option[2])
			b:SetWidth(math.floor(b.text:GetUnboundedStringWidth() + 32))
			b:ClearAllPoints()
			b:SetPoint('LEFT', x, 0)
			local on = option[1] == current
			local base = on and GOLD or TRACK
			b.bg:SetColorTexture(base[1], base[2], base[3], 1)
			local color = on and { 0.1, 0.08, 0.03 } or TEXT
			b.text:SetTextColor(color[1], color[2], color[3])
			b:SetScript('OnLeave', function(button) button.bg:SetColorTexture(base[1], base[2], base[3], 1) end)
			b:SetScript('OnEnter', function(button) button.bg:SetColorTexture(math.min(1, base[1] + 0.06), math.min(1, base[2] + 0.06), math.min(1, base[3] + 0.06), 1) end)
			b:Show()
			x = x + b:GetWidth() + 1
		end
		for i = #self.data.options + 1, #self.buttons do self.buttons[i]:Hide() end
	end
	return row
end

local MAKERS = { range = RangeRow, toggle = ToggleRow, color = ColorRow, button = ButtonRow, choice = ChoiceRow,
	textbox = TextboxRow } -- 3.0

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

-- One section of a page: a card with a thin edge, its title in small gold capitals, its rows inside.
local function Card(parent)
	local f = CreateFrame('Frame', nil, parent)
	Fill(f, HAIR)
	local fill = f:CreateTexture(nil, 'BACKGROUND', nil, 1)
	fill:SetColorTexture(PANEL2[1], PANEL2[2], PANEL2[3], 1)
	fill:SetPoint('TOPLEFT', 1, -1)
	fill:SetPoint('BOTTOMRIGHT', -1, 1)
	f.title = Text(f, 11, GOLD)
	f.title:SetPoint('TOPLEFT', CARD_PAD, -13)
	return f
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

local KINDS = { 'range', 'toggle', 'color', 'button', 'choice', 'section', 'para', 'aboutkey', 'aboutval', 'abouthead', 'aboutbar', 'aboutline',
	'textbox', 'card' } -- 3.0

-- The width of the page inside its margins: the panel without the list.
local function PageWidth()
	return panel:GetWidth() - NAV - 2 * PAD
end

-- One card: the section's text, then its rows one under the other. Returns the card's height.
local function RenderCard(card, sec, rows, width)
	card.title:SetText(sec.name:upper())
	local y = -CARD_TOP
	if sec.desc then
		local p = Acquire('para', card, Paragraph)
		p:SetPoint('TOPLEFT', CARD_PAD, y)
		p:SetWidth(width - 2 * CARD_PAD)
		p:SetText(sec.desc)
		y = y - (p:GetStringHeight() + 8)
	end
	for _, data in ipairs(rows) do
		local row = Acquire(data.t, card, MAKERS[data.t])
		row:SetPoint('TOPLEFT', CARD_PAD, y)
		row:SetWidth(width - 2 * CARD_PAD)
		row.data = data
		if data.t == 'range' then
			row.slider:SetMinMaxValues(data.min, data.max)
			row.slider:SetValueStep(data.step)
		end
		if data.t ~= 'button' and data.t ~= 'choice' then row.label:SetText(data.label) end
		row:Refresh()
		-- A row that does nothing in the current state is grey and cannot be clicked.
		local off = data.dim and data.dim() or false
		row:SetAlpha(off and 0.4 or 1)
		if row.switch then row.switch:SetEnabled(not off) end
		y = y - ROW_H
	end
	local height = -y + 6
	card:SetHeight(height)
	return height
end

RenderMain = function()
	PageHeader()
	ReleaseAll(KINDS)
	local width = PageWidth()
	local page = FindPage(current)
	lastPage[page.group] = page.id
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
	header.reset:SetShown(not page.noReset)
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
		row:SetAlpha(1)
		row.switch:Enable()
		row.label:SetText('Enable ' .. page.name:lower())
		row:Refresh()
		y = y - 38 - 16
	end

	-- Every section is a card. With room for it they go into two columns, each card under the
	-- shorter one, in the page's order. A page with a text box keeps one column: the box needs the width.
	local sections, wide = {}, false
	for _, sec in ipairs(page.secs or {}) do
		local rows = {}
		for _, row in ipairs(sec.rows) do
			if row.t == 'textbox' then wide = true end
			-- 3.0: hidden rows are settings this client does not have.
			if (not row.path or S.defaults[row.path] ~= nil) and RowMatches(page, sec, row) and not (row.hidden and row.hidden()) then
				table.insert(rows, row)
			end
		end
		if #rows > 0 then table.insert(sections, { sec = sec, rows = rows }) end
	end
	local columns = (not wide and width >= TWO_COLUMNS) and 2 or 1
	local cardW = columns == 2 and math.floor((width - GAP) / 2) or width
	local tops, bottom = { y, y }, y
	for _, section in ipairs(sections) do
		local col = (columns == 2 and tops[2] > tops[1]) and 2 or 1
		local card = Acquire('card', mainChild, Card)
		card:SetPoint('TOPLEFT', PAD + (col - 1) * (cardW + GAP), tops[col])
		card:SetWidth(cardW)
		local height = RenderCard(card, section.sec, section.rows, cardW)
		bottom = math.min(bottom, tops[col] - height)
		tops[col] = tops[col] - height - GAP
	end
	y = bottom
	mainChild:SetHeight(-y + PAD)
	mainScroll:ScrollTo(mainScroll:GetVerticalScroll())
end

-- The screen in the panel's units: its scale makes one unit max(fit, 0.8) physical pixels.
local function ScreenSize()
	local width, height = GetPhysicalScreenSize()
	local unit = math.max(ns.Fit(), 0.8)
	return math.floor(width / unit), math.floor(height / unit)
end

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

-- The last size and place, kept for the account; never larger than the screen.
local function Place()
	local sw, sh = ScreenSize()
	local saved = ns.DB and ns.DB.settingsWindow or {}
	local w = math.min(math.max(tonumber(saved.w) or W, MIN_W), sw)
	local h = math.min(math.max(tonumber(saved.h) or H, MIN_H), sh)
	if panel.SetResizeBounds then panel:SetResizeBounds(math.min(MIN_W, sw), math.min(MIN_H, sh), sw, sh) end
	panel:SetSize(w, h)
	panel:ClearAllPoints()
	local x, y = tonumber(saved.x), tonumber(saved.y)
	if x and y then
		panel:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', Clamp(x, 0, sw - w), Clamp(y, h, sh))
	else
		panel:SetPoint('CENTER')
	end
end

local function Remember()
	if not ns.DB then return end
	local left, top = panel:GetLeft(), panel:GetTop()
	ns.DB.settingsWindow = { w = math.floor(panel:GetWidth() + 0.5), h = math.floor(panel:GetHeight() + 0.5),
		x = left and math.floor(left + 0.5), y = top and math.floor(top + 0.5) }
end

-- The grip let go (or the panel closed while it was held): keep the size, lay the page out once.
local function StopSizing()
	if not sizing then return end
	sizing = false
	panel:StopMovingOrSizing()
	Remember()
	RenderMain()
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
	if panel.SetResizable then panel:SetResizable(true) end
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:Hide()
	Fill(panel, PANEL, 0.98)
	ns.Outline(panel)
	tinsert(UISpecialFrames, 'SlimARK_Settings')
	-- A size set outside the grip (opening, a smaller screen) lays the page out again once, a frame later.
	panel:SetScript('OnSizeChanged', function()
		if sizing or relayout then return end
		relayout = true
		C_Timer.After(0, function()
			relayout = false
			if panel:IsShown() and not sizing then RenderMain() end
		end)
	end)
	panel:SetScript('OnHide', StopSizing)

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
	head:SetScript('OnDragStop', function()
		panel:StopMovingOrSizing()
		Remember()
	end)

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

	-- The grip: three short gold lines in the bottom right corner. Dragging it resizes the panel.
	if panel.StartSizing then
		local grip = CreateFrame('Button', nil, panel)
		grip:SetSize(16, 16)
		grip:SetPoint('BOTTOMRIGHT', -2, 2)
		grip:SetFrameLevel(saveButton:GetFrameLevel() + 2)
		-- Only the corner with the lines takes the mouse, clear of the save button beside it.
		grip:SetHitRectInsets(6, 0, 6, 0)
		if grip.CreateLine then
			for i = 1, 3 do
				local line = grip:CreateLine(nil, 'OVERLAY')
				line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
				line:SetThickness(1.5)
				line:SetStartPoint('BOTTOMRIGHT', grip, -4 * i, 0)
				line:SetEndPoint('BOTTOMRIGHT', grip, 0, 4 * i)
			end
		end
		grip:SetScript('OnMouseDown', function()
			sizing = true
			panel:StartSizing('BOTTOMRIGHT', true)
		end)
		grip:SetScript('OnMouseUp', StopSizing)
	end

	-- Tabs: one per group with its page count. They sit under the header, over the list and the page.
	local tabRow = CreateFrame('Frame', nil, panel)
	tabRow:SetPoint('TOPLEFT', 0, -BAR)
	tabRow:SetPoint('TOPRIGHT', 0, -BAR)
	tabRow:SetHeight(TAB)
	Fill(tabRow, PANEL2)
	local tabLine = tabRow:CreateTexture(nil, 'ARTWORK')
	tabLine:SetColorTexture(HAIR[1], HAIR[2], HAIR[3], 1)
	tabLine:SetHeight(1)
	tabLine:SetPoint('BOTTOMLEFT')
	tabLine:SetPoint('BOTTOMRIGHT')
	local x = 12
	for _, group in ipairs(S.groups) do
		local tab = CreateFrame('Button', nil, tabRow)
		tab.group = group.name
		tab.text = Text(tab, 14, MUTED)
		tab.text:SetPoint('LEFT', 12, 0)
		tab.text:SetText(group.name)
		local width = tab.text:GetUnboundedStringWidth() + 24
		-- About is a single page: no count.
		if not group.pages[1].about then
			tab.count = Text(tab, 12, GREY)
			tab.count:SetPoint('BOTTOMLEFT', tab.text, 'BOTTOMRIGHT', 4, 0)
			tab.count:SetText(tostring(#group.pages))
			width = width + 4 + tab.count:GetUnboundedStringWidth()
		end
		width = math.ceil(width)
		tab.line = tab:CreateTexture(nil, 'ARTWORK')
		tab.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
		tab.line:SetHeight(2)
		tab.line:SetPoint('BOTTOMLEFT')
		tab.line:SetPoint('BOTTOMRIGHT')
		Fill(tab, { 1, 1, 1 }, 0.04, 'HIGHLIGHT')
		tab:SetSize(width, TAB - 1)
		tab:SetPoint('TOPLEFT', x, 0)
		tab:SetScript('OnClick', function() OpenGroup(group) end)
		x = x + width + 2
		table.insert(tabs, tab)
	end

	-- Body: the list on the left, the page on the right.
	local navFrame = CreateFrame('Frame', nil, panel)
	navFrame:SetPoint('TOPLEFT', 0, -(BAR + TAB))
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
	mainScroll:SetPoint('TOPLEFT', NAV, -(BAR + TAB))
	mainScroll:SetPoint('BOTTOMRIGHT', 0, BAR)
	mainChild:SetWidth(W - NAV)
end

-- Opens the panel, or closes it when open. pageID opens that page; an old page's id opens
-- the page it moved into.
function ns.OpenSettings(pageID)
	if not panel then Build() end
	pageID = pageID and S.moved[pageID] or pageID
	if pageID and FindPage(pageID) then
		current = pageID
	elseif panel:IsShown() then
		panel:Hide()
		return
	end
	panel:SetScale(ns.Scale() / ns.Fit() * math.max(ns.Fit(), 0.8))
	if not panel:IsShown() then Place() end
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

-- Redraws the open page, for values changed from outside the panel (the test mode banner).
function ns.SettingsRefresh()
	if panel and panel:IsShown() and RenderMain then RenderMain() end
end
