local _, ns = ...
local C = ns.C

-- Blizzard windows in the SlimARK look (2.0). Only when the look chosen in the setup
-- window (or on the Blizzard windows settings page) is SlimARK: with Original nothing here
-- runs. A window gets its look the first time it opens, never at login, and only its
-- textures and colors change: buttons, scripts, positions and Blizzard's functions stay.
local K = {}
ns.BlizzSkin = K

local BODY = { 0.071, 0.075, 0.094, 0.97 }
local HEAD = { 0.063, 0.067, 0.082, 1 }
local INSET = { 0.055, 0.059, 0.071, 0.85 }
local BUTTON = { 0.09, 0.094, 0.114, 1 }
local FIELD = { 0.047, 0.051, 0.063, 1 }
local OUTER = { 0.169, 0.176, 0.208, 1 }
local BLACK = { 0, 0, 0, 1 }
local GOLD = { 0.95, 0.72, 0.29, 1 }
local TEXT = { 0.93, 0.91, 0.87 }
local SOFT = { 0.73, 0.71, 0.66 }
local ROW_FILL = { 0.09, 0.094, 0.114, 1 }
K.GOLD, K.TEXT, K.SOFT, K.BODY, K.BUTTON, K.FIELD, K.INSET = GOLD, TEXT, SOFT, BODY, BUTTON, FIELD, INSET

-- True when the Blizzard windows have the SlimARK look and this window is switched on.
function K.On(key)
	return C.blizz.look == 'slimark' and (key == nil or C.blizz[key] ~= false)
end

-- Each object is dressed once per kind.
local done = setmetatable({}, { __mode = 'k' })
function K.Done(object, tag)
	tag = tag or 'skin'
	local list = done[object]
	if list and list[tag] then return true end
	list = list or {}
	list[tag] = true
	done[object] = list
	return false
end

-- A texture or frame made invisible. The alpha survives Blizzard's SetAtlas and Show calls.
function K.Hide(region)
	if region and region.SetAlpha then region:SetAlpha(0) end
end

-- For textures whose alpha Blizzard animates: hidden and emptied instead.
function K.Kill(region)
	if region and region.Hide then
		region:Hide()
		if region.GetObjectType and region:GetObjectType() == 'Texture' then region:SetTexture(nil) end
	end
end

-- Every texture the frame draws itself (not its children), except the ones in keep.
function K.Strip(frame, keep)
	if not frame or not frame.GetRegions then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == 'Texture' and not (keep and keep[region]) then region:SetAlpha(0) end
	end
end

-- Our drawing order on a frame's BACKGROUND layer, below Blizzard's own art (sublevel 0 and up):
-- grey outer line -8, black edge -7, fill -6, header band and its line -5, gold line -4.
local function Fill(frame, color, layer, sub)
	local t = frame:CreateTexture(nil, layer or 'BACKGROUND', nil, sub or -6)
	t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return t
end
K.Fill = Fill

-- The flat box on a frame's own background layer: an optional grey line, a black
-- one-pixel edge and the fill. inset: left, top, right, bottom, inside the frame.
local function Box(frame, color, inset, outer)
	local px = ns.Px()
	local l, t, r, b = 0, 0, 0, 0
	if inset then l, t, r, b = inset[1], inset[2], inset[3], inset[4] end
	local function Rect(c, n, sub)
		local tex = Fill(frame, c, 'BACKGROUND', sub)
		tex:SetPoint('TOPLEFT', l - n * px, -t + n * px)
		tex:SetPoint('BOTTOMRIGHT', -r + n * px, b - n * px)
		return tex
	end
	if outer then Rect(OUTER, 2, -8) end
	Rect(BLACK, 1, -7)
	local fill = Rect(color, 0, -6)
	return fill
end
K.Box = Box

-- The window body: dark fill, black edge, grey line outside it, gold line on top.
-- opts.header: height of the darker title band, with a black line under it.
-- opts.inset: left, top, right, bottom insets of the body inside the frame.
function K.Body(frame, opts)
	if not frame or K.Done(frame, 'body') then return end
	opts = opts or {}
	local px = ns.Px()
	local fill = Box(frame, opts.color or BODY, opts.inset, true)
	local gold = Fill(frame, GOLD, 'BACKGROUND', -4)
	gold:SetPoint('TOPLEFT', fill, 'TOPLEFT')
	gold:SetPoint('TOPRIGHT', fill, 'TOPRIGHT')
	gold:SetHeight(2 * px)
	if opts.header then
		local band = Fill(frame, HEAD, 'BACKGROUND', -5)
		band:SetPoint('TOPLEFT', fill, 'TOPLEFT')
		band:SetPoint('TOPRIGHT', fill, 'TOPRIGHT')
		band:SetHeight(opts.header)
		local line = Fill(frame, BLACK, 'BACKGROUND', -5)
		line:SetPoint('TOPLEFT', band, 'BOTTOMLEFT')
		line:SetPoint('TOPRIGHT', band, 'BOTTOMRIGHT')
		line:SetHeight(px)
	end
	frame.slimFill = fill
end

-- Only the edges and the header of a window, no fill: for a frame that lies over its
-- content (the world map's border sits above the map). Black edge, grey line outside it,
-- the darker header band with a black line under it and the gold line on top.
function K.Rim(frame, header)
	if not frame or K.Done(frame, 'rim') then return end
	local px = ns.Px()
	ns.Edge(frame, 1, OUTER, 2 * px)
	ns.Edge(frame, 1, BLACK, px)
	local band = Fill(frame, HEAD, 'BACKGROUND', -5)
	band:SetPoint('TOPLEFT')
	band:SetPoint('TOPRIGHT')
	band:SetHeight(header or 24)
	local line = Fill(frame, BLACK, 'BACKGROUND', -5)
	line:SetPoint('TOPLEFT', band, 'BOTTOMLEFT')
	line:SetPoint('TOPRIGHT', band, 'BOTTOMRIGHT')
	line:SetHeight(px)
	local gold = Fill(frame, GOLD, 'BACKGROUND', -4)
	gold:SetPoint('TOPLEFT')
	gold:SetPoint('TOPRIGHT')
	gold:SetHeight(2 * px)
end

-- Blizzard's old backdrop art (BackdropTemplate: the wood and gold borders of the achievements,
-- tooltip-style edges on rows) is cleared. Later SetBackdropBorderColor calls do nothing then.
function K.NoBackdrop(frame)
	if frame and frame.ClearBackdrop and frame.backdropInfo then frame:ClearBackdrop() end
end

-- The same for every frame under this one.
function K.NoBackdrops(frame, depth)
	if not frame or not frame.GetChildren then return end
	depth = depth or 4
	if depth <= 0 then return end
	for _, child in ipairs({ frame:GetChildren() }) do
		K.NoBackdrop(child)
		K.NoBackdrops(child, depth - 1)
	end
end

-- An inner panel (InsetFrameTemplate and its kind): a darker flat box with a black edge.
function K.Inset(inset, color)
	if not inset or K.Done(inset, 'inset') then return end
	K.Hide(inset.NineSlice)
	K.Hide(inset.Bg)
	K.Strip(inset)
	Box(inset, color or INSET)
end

-- The standard window frame (PortraitFrameTemplate, ButtonFrameTemplate and their kind).
function K.Frame(frame, opts)
	if not frame then return end
	opts = opts or {}
	K.Hide(frame.NineSlice)
	K.Hide(frame.Bg)
	K.Hide(frame.Background)
	K.Hide(frame.TopTileStreaks)
	K.Hide(frame.PortraitContainer)
	K.Hide(frame.portrait)
	K.Hide(frame.PortraitButton)
	if frame.GetName and frame:GetName() then
		local name = frame:GetName()
		K.Hide(_G[name .. 'Portrait'])
		K.Hide(_G[name .. 'Bg'])
		K.Hide(_G[name .. 'TitleBg'])
	end
	if not opts.keepRegions then K.Strip(frame) end
	K.Body(frame, { header = opts.header or 24, inset = opts.inset })
	if frame.Inset then K.Inset(frame.Inset) end
	if frame.CloseButton then K.Close(frame.CloseButton) end
	local title = frame.TitleContainer and frame.TitleContainer.TitleText or frame.TitleText
	if title and title.SetTextColor then title:SetTextColor(TEXT[1], TEXT[2], TEXT[3]) end
end

-- A flat button: dark fill, black edge, light on hover. Used for UIPanelButtonTemplate.
function K.Button(button, primary)
	if not button or K.Done(button, 'button') then return end
	K.Hide(button.Left)
	K.Hide(button.Middle)
	K.Hide(button.Right)
	K.Hide(button.Center)
	for _, key in ipairs({ 'GetNormalTexture', 'GetPushedTexture', 'GetDisabledTexture' }) do
		local tex = button[key] and button[key](button)
		if tex then tex:SetAlpha(0) end
	end
	local fill = Box(button, primary and GOLD or BUTTON)
	local hl = button.GetHighlightTexture and button:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.08)
		hl:ClearAllPoints()
		hl:SetAllPoints(fill)
	end
	if primary then
		local text = button.GetFontString and button:GetFontString()
		if text then text:SetTextColor(0.1, 0.08, 0.03) end
	end
end

-- The close cross: a small flat square with an x.
function K.Close(button)
	if not button or K.Done(button, 'close') then return end
	for _, key in ipairs({ 'GetNormalTexture', 'GetPushedTexture', 'GetDisabledTexture', 'GetHighlightTexture' }) do
		local tex = button[key] and button[key](button)
		if tex then tex:SetAlpha(0) end
	end
	K.Strip(button)
	local px = ns.Px()
	local box = CreateFrame('Frame', nil, button)
	box:SetPoint('CENTER')
	box:SetSize(18, 18)
	box:SetFrameLevel(button:GetFrameLevel())
	Box(box, BUTTON)
	local x = ns.Text(box, 13, 'CENTER')
	x:SetPoint('CENTER', 0, px)
	x:SetText('x')
	x:SetTextColor(SOFT[1], SOFT[2], SOFT[3])
	button:HookScript('OnEnter', function() x:SetTextColor(1, 1, 1) end)
	button:HookScript('OnLeave', function() x:SetTextColor(SOFT[1], SOFT[2], SOFT[3]) end)
end

-- Tabs (PanelTabButtonTemplate and the newer tab system): flat, the selected one with a
-- gold line on top and gold text.
local function TabState(tab)
	local look = tab and tab.slimTab
	if not look then return end
	local selected
	if tab.isSelected ~= nil then selected = tab.isSelected
	elseif tab.LeftActive then selected = tab.LeftActive:IsShown()
	else selected = not tab:IsEnabled() end
	look.gold:SetShown(selected and true or false)
	look.fill:SetColorTexture(selected and 0.11 or BUTTON[1], selected and 0.11 or BUTTON[2], selected and 0.12 or BUTTON[3], 1)
	local text = tab.Text or (tab.GetFontString and tab:GetFontString())
	if text then
		local c = selected and GOLD or SOFT
		text:SetTextColor(c[1], c[2], c[3])
	end
end
K.TabState = TabState

local tabHooks = false
function K.Tab(tab)
	if not tab or K.Done(tab, 'tab') then return end
	K.Strip(tab)
	for _, key in ipairs({ 'Left', 'Middle', 'Right', 'LeftActive', 'MiddleActive', 'RightActive', 'LeftHighlight', 'MiddleHighlight', 'RightHighlight', 'LeftDisabled', 'MiddleDisabled', 'RightDisabled' }) do
		K.Hide(tab[key])
	end
	local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
	if hl then hl:SetAlpha(0) end
	local px = ns.Px()
	local fill = Box(tab, BUTTON, { 2, 4, 2, 0 })
	local gold = Fill(tab, GOLD, 'BACKGROUND', -5)
	gold:SetPoint('TOPLEFT', fill, 'TOPLEFT')
	gold:SetPoint('TOPRIGHT', fill, 'TOPRIGHT')
	gold:SetHeight(2 * px)
	tab.slimTab = { fill = fill, gold = gold }
	if not tabHooks then
		tabHooks = true
		hooksecurefunc('PanelTemplates_SelectTab', TabState)
		hooksecurefunc('PanelTemplates_DeselectTab', TabState)
	end
	if tab.SetTabSelected then hooksecurefunc(tab, 'SetTabSelected', TabState) end
	tab:HookScript('OnEnable', TabState)
	tab:HookScript('OnDisable', TabState)
	TabState(tab)
end

-- Scroll bars (MinimalScrollBar and WowTrimScrollBar): a thin dark track and a grey thumb.
function K.Scroll(bar)
	if not bar or K.Done(bar, 'scroll') then return end
	local track = bar.Track
	if not track then return end
	K.Strip(track)
	K.Hide(track.Begin)
	K.Hide(track.End)
	K.Hide(track.Middle)
	K.Strip(bar)
	K.Hide(bar.Background)
	local px = ns.Px()
	local line = Fill(track, { 0.03, 0.035, 0.045, 0.9 }, 'BACKGROUND', 0)
	line:SetPoint('TOP')
	line:SetPoint('BOTTOM')
	line:SetWidth(4 * px)
	local thumb = track.Thumb
	if thumb then
		K.Hide(thumb.Begin)
		K.Hide(thumb.End)
		K.Hide(thumb.Middle)
		K.Strip(thumb)
		local t = Fill(thumb, { 0.35, 0.36, 0.4, 1 }, 'ARTWORK', 0)
		t:SetPoint('TOP')
		t:SetPoint('BOTTOM')
		t:SetWidth(4 * px)
		thumb:HookScript('OnEnter', function() t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1) end)
		thumb:HookScript('OnLeave', function() t:SetColorTexture(0.35, 0.36, 0.4, 1) end)
	end
	for _, key in ipairs({ 'Back', 'Forward' }) do
		local step = bar[key]
		if step then
			K.Strip(step)
			K.Hide(step.Texture)
			for _, getter in ipairs({ 'GetNormalTexture', 'GetPushedTexture', 'GetHighlightTexture', 'GetDisabledTexture' }) do
				local tex = step[getter] and step[getter](step)
				if tex then tex:SetAlpha(0) end
			end
		end
	end
end

-- Edit and search boxes: a dark field with a black edge.
function K.Edit(box)
	if not box or K.Done(box, 'edit') then return end
	K.Hide(box.Left)
	K.Hide(box.Middle)
	K.Hide(box.Right)
	K.Hide(box.Mid)
	K.Hide(box.NineSlice)
	K.NoBackdrop(box)
	K.Strip(box, { [box.searchIcon or false] = true, [box.Instructions or false] = true })
	Box(box, FIELD, { -4, 2, 0, 2 })
end

-- Dropdowns: a flat button look, the arrow stays.
function K.Dropdown(dd)
	if not dd or K.Done(dd, 'dropdown') then return end
	K.Hide(dd.Background)
	K.Hide(dd.NineSlice)
	K.Hide(dd.Left)
	K.Hide(dd.Middle)
	K.Hide(dd.Right)
	Box(dd, BUTTON)
end

-- Item buttons: icon cropped, Blizzard's border replaced by a one-pixel edge in the
-- quality color (black when there is no quality).
local function EdgeColor(button, r, g, b)
	local edge = button.slimEdge
	if edge then
		for _, t in ipairs(edge) do t:SetColorTexture(r, g, b, 1) end
	end
end
function K.Item(button)
	if not button or K.Done(button, 'item') then return end
	local icon = button.icon or button.Icon or (button.GetName and button:GetName() and _G[button:GetName() .. 'IconTexture'])
	if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	local normal = button.GetNormalTexture and button:GetNormalTexture()
	if normal then normal:SetAlpha(0) end
	K.Hide(button.NormalTexture)
	local px = ns.Px()
	local edge = {}
	local function side(p1, p2, w, h)
		local t = button:CreateTexture(nil, 'OVERLAY', nil, 6)
		t:SetColorTexture(0, 0, 0, 1)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		table.insert(edge, t)
	end
	side('TOPLEFT', 'TOPRIGHT', nil, px)
	side('BOTTOMLEFT', 'BOTTOMRIGHT', nil, px)
	side('TOPLEFT', 'BOTTOMLEFT', px, nil)
	side('TOPRIGHT', 'BOTTOMRIGHT', px, nil)
	button.slimEdge = edge
	local border = button.IconBorder
	if border then
		border:SetAlpha(0)
		hooksecurefunc(border, 'SetVertexColor', function(_, r, g, b) EdgeColor(button, r, g, b) end)
		-- No quality: Blizzard hides the border with Hide or SetShown(false), the edge goes black.
		hooksecurefunc(border, 'Hide', function() EdgeColor(button, 0, 0, 0) end)
		hooksecurefunc(border, 'SetShown', function(_, shown) if not shown then EdgeColor(button, 0, 0, 0) end end)
		if border:IsShown() then EdgeColor(button, border:GetVertexColor()) end
	end
end

-- A big list button with a picture (Group Finder and PvP categories): the blue frame and the
-- ring go, the picture stays; a flat dark box, a light hover and a gold line on the left of the
-- selected one. Returns the function that shows or hides the gold line.
function K.Category(button, keys)
	if not button or K.Done(button, 'category') then return button and button.slimSelect end
	for _, key in ipairs(keys) do K.Hide(button[key]) end
	local hl = button.GetHighlightTexture and button:GetHighlightTexture()
	local fill = Box(button, BUTTON, { 1, 1, 1, 1 })
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.06)
		hl:ClearAllPoints()
		hl:SetAllPoints(fill)
	end
	local gold = Fill(button, GOLD, 'BACKGROUND', -5)
	gold:SetPoint('TOPLEFT', fill, 'TOPLEFT')
	gold:SetPoint('BOTTOMLEFT', fill, 'BOTTOMLEFT')
	gold:SetWidth(2 * ns.Px())
	gold:Hide()
	button.slimSelect = function(on) gold:SetShown(on and true or false) end
	return button.slimSelect
end

-- A wide activity button drawn by an atlas (PvP queues): the atlas goes, a flat box comes, the
-- hover is a light film and the selected state a gold film. The normal texture is emptied, not
-- faded, because Blizzard sets its alpha for disabled queues.
function K.Activity(button)
	if not button or K.Done(button, 'activity') then return end
	local normal = button.GetNormalTexture and button:GetNormalTexture()
	if normal then normal:SetTexture(nil) end
	local pushed = button.GetPushedTexture and button:GetPushedTexture()
	if pushed then pushed:SetTexture(nil) end
	local fill = Box(button, ROW_FILL, { 2, 2, 2, 2 })
	local hl = button.GetHighlightTexture and button:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.06)
		hl:ClearAllPoints()
		hl:SetAllPoints(fill)
	end
	if button.SelectedTexture then
		button.SelectedTexture:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.14)
		button.SelectedTexture:ClearAllPoints()
		button.SelectedTexture:SetAllPoints(fill)
	end
end

-- A checkbox gets no new look: Blizzard's is small and clear on the dark body.

-- Walks the children of a frame and dresses the known Blizzard widgets: buttons, tabs,
-- close crosses, edit boxes, scroll bars, dropdowns and inner panels. Runs once per frame,
-- the first time its window opens.
local function Classify(child)
	local kind = child:GetObjectType()
	if kind == 'EditBox' then K.Edit(child) return end
	if child.Track and child.Track.Thumb then K.Scroll(child) return end
	local name = child.GetName and child:GetName()
	if kind == 'Button' then
		if child.LeftActive or child.slimTabLike then K.Tab(child) return end
		if name and name:find('CloseButton$') then K.Close(child) return end
		if child.Left and child.Middle and child.Right and child.Left.GetObjectType and child.Left:GetObjectType() == 'Texture' then
			K.Button(child)
			return
		end
		if child.IconBorder then K.Item(child) return end
	end
	if kind == 'DropdownButton' or child.Arrow and child.Background and kind ~= 'Frame' then K.Dropdown(child) return end
	if child.NineSlice and child.Bg and (child.layoutType or (name and name:find('Inset$'))) then K.Inset(child) end
	if name and name:find('Inset$') and child.NineSlice then K.Inset(child) end
end

function K.Auto(frame, depth)
	if not frame or not frame.GetChildren then return end
	depth = depth or 6
	if depth <= 0 then return end
	for _, child in ipairs({ frame:GetChildren() }) do
		if not K.Done(child, 'auto') then
			Classify(child)
			K.Auto(child, depth - 1)
		end
	end
end

-- Rows that a scroll box makes later (lists in Group Finder, the guild roster, the mail,
-- the auction house) are dressed when the scroll box takes them.
function K.ScrollRows(scrollBox, fn)
	if not scrollBox or K.Done(scrollBox, 'rows') then return end
	if ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
		ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, row)
			if row and not K.Done(row, 'row') then fn(row) end
		end, scrollBox, true)
	end
end

-- The usual work for a window: frame, then everything inside it.
function K.Window(frame, opts)
	if not frame then return end
	K.Frame(frame, opts)
	K.Auto(frame)
end

-- A plain flat panel for frames that are not windows (popups, the talking head).
function K.Panel(frame, opts)
	if not frame then return end
	opts = opts or {}
	K.Hide(frame.NineSlice)
	K.Hide(frame.Border)
	K.Hide(frame.Bg)
	K.Hide(frame.Background)
	if opts.strip ~= false then K.Strip(frame) end
	K.Body(frame, opts)
end

-- Windows by settings key. Each entry: the Blizzard addon that owns the frame (nil when it
-- is always loaded), the frame names, and the function that dresses it. The function runs
-- once, on the frame's first OnShow, or at once when the frame is already shown.
K.windows = {}
function K.Register(key, addon, frames, fn)
	table.insert(K.windows, { key = key, addon = addon, frames = type(frames) == 'table' and frames or { frames }, fn = fn })
end

local function Dress(entry, frame)
	if K.Done(frame, 'window') then return end
	xpcall(function() entry.fn(frame) end, geterrorhandler())
end

local function Arm(entry)
	if entry.armed then return end
	entry.armed = true
	for _, name in ipairs(entry.frames) do
		local frame = type(name) == 'string' and _G[name] or name
		if type(name) == 'function' then frame = name() end
		if frame and frame.HookScript then
			if frame:IsShown() then
				Dress(entry, frame)
			else
				frame:HookScript('OnShow', function(self) Dress(entry, self) end)
			end
		end
	end
end

local waiting = {}
ns.On('PLAYER_LOGIN', function()
	if not K.On() then return end
	for _, entry in ipairs(K.windows) do
		if K.On(entry.key) then
			if not entry.addon or C_AddOns.IsAddOnLoaded(entry.addon) then
				Arm(entry)
			else
				waiting[entry.addon] = waiting[entry.addon] or {}
				table.insert(waiting[entry.addon], entry)
			end
		end
	end
	if next(waiting) then
		ns.On('ADDON_LOADED', function(_, name)
			local list = waiting[name]
			if not list then return end
			waiting[name] = nil
			for _, entry in ipairs(list) do Arm(entry) end
		end)
	end
end)
