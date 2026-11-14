-- 3.2 fixes from a tester: Blizzard's XP bar (hidden with the top bar line, above the action bars
-- without it), the Edit Mode overlays after leaving Edit Mode, the side bars above Blizzard's chat
-- tabs, the UI size and the way back to the old Edit Mode layout. Run from the repository root:
--   lua5.1 tests/claude/fixes-3-2.lua
local H = dofile('tests/codex/lib/runtime.lua')

local function Boot(setup)
	local ns = H.setup()
	H.load('Config.lua')
	if setup then setup(ns.C) end
	H.load('Core.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	return ns
end

local function Setting(info, setting)
	for _, entry in ipairs(info.settings) do
		if entry.setting == setting then return entry.value end
	end
end

-- A client with one own layout holding the action bars and the two status bars. active: which
-- entry of presets + own layouts is in use.
local function EditModeClient(active)
	local S = Enum.EditModeSystem
	local A = Enum.EditModeActionBarSystemIndices
	local T = Enum.EditModeStatusTrackingBarSystemIndices
	local function Layout(name)
		local systems = {}
		for _, index in ipairs({ 'MainBar', 'Bar2', 'Bar3', 'RightBar1', 'RightBar2', 'ExtraBar1', 'ExtraBar2', 'ExtraBar3' }) do
			systems[#systems + 1] = { system = S.ActionBar, systemIndex = A[index], settings = {}, bar = index }
		end
		systems[#systems + 1] = { system = S.StatusTrackingBar, systemIndex = T.StatusTrackingBar1, settings = {}, bar = 'xp' }
		systems[#systems + 1] = { system = S.StatusTrackingBar, systemIndex = T.StatusTrackingBar2, settings = {}, bar = 'rep' }
		return { layoutName = name, layoutType = Enum.EditModeLayoutType.Account, systems = systems }
	end
	local saved = { layouts = { Layout('SlimARK-UI'), Layout('SlimARK-UI Heal') }, activeLayout = active or 2 }
	CopyTable = function(t) return t end
	tAppendAll = function(a, b) for _, v in ipairs(b) do a[#a + 1] = v end end
	Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 5 } }
	EditModePresetLayoutManager = { GetCopyOfPresetLayouts = function()
		return { { layoutName = 'Modern', layoutType = Enum.EditModeLayoutType.Preset, systems = {} } }
	end }
	local state = { saved = saved }
	C_EditMode = {
		GetLayouts = function() return { layouts = saved.layouts, activeLayout = saved.activeLayout } end,
		SaveLayouts = function() state.saves = (state.saves or 0) + 1 end,
		OnLayoutAdded = function() end,
		SetActiveLayout = function(i) state.active = i end,
	}
	H.load('EditMode.lua')
	return state
end

local function System(layout, bar)
	for _, info in ipairs(layout.systems) do
		if info.bar == bar then return info end
	end
end

local function Near(a, b) return math.abs(a - b) < 0.01 end

------------------------------------------------------------------------
-- Blizzard's XP and reputation bars in the Edit Mode layout.
------------------------------------------------------------------------
do
	-- The top bar's line on (the default): the bars are hidden by DataBar.lua, the layout leaves them.
	local ns = Boot()
	local state = EditModeClient()
	ns.ApplyEditMode()
	local layout = state.saved.layouts[1]
	H.check(System(layout, 'xp').anchorInfo == nil and #System(layout, 'xp').settings == 0, 'xp bar: left alone while the top bar line is on')
end

do
	local ns = Boot(function(C) C.databar.show.xp = false end)
	local state = EditModeClient()
	ns.ApplyEditMode()
	local layout = state.saved.layouts[1]
	local xp, rep = System(layout, 'xp'), System(layout, 'rep')
	local size = Enum.EditModeStatusTrackingBarSetting.Size
	-- 2560x1600 and the fake UI scale: one unit is 0.48 of a layout pixel. A 598 px row: 571 units at 50%.
	H.equal(Setting(xp, size), 0, 'xp bar: 50% size, as wide as an action bar row')
	H.equal(xp.anchorInfo.point, 'BOTTOM', 'xp bar: anchored by its bottom')
	local rowHeight = (45 * 0.5 + 2) / 0.48
	local y = 1578 - 3 * rowHeight - 2
	H.check(Near(xp.anchorInfo.offsetX, 1280 * 0.48) and Near(xp.anchorInfo.offsetY, -y * 0.48), 'xp bar: centered above the three bottom rows')
	local height = 17 * 0.5 / 0.48
	H.check(Near(rep.anchorInfo.offsetY, -(y - height - 2) * 0.48), 'reputation bar: right above the XP bar')
	H.check(state.saved.layouts[2].systems[9].anchorInfo ~= nil, 'xp bar: the healer layout too')
	H.noErrors()
end

do
	-- The top bar off: nothing hides Blizzard's bars, so they are placed as well.
	local ns = Boot(function(C) C.modules.databar = false end)
	local state = EditModeClient()
	ns.ApplyEditMode()
	H.check(System(state.saved.layouts[1], 'xp').anchorInfo ~= nil, 'xp bar: placed when the top bar is off')
end

------------------------------------------------------------------------
-- The side bars start above Blizzard's chat tabs when Chattynator is not there.
------------------------------------------------------------------------
do
	local ns = Boot()
	local state = EditModeClient()
	-- A tall Blizzard chat (300 units); the fake tab is 20 units high.
	ChatFrame1 = H.NewFrame('Frame')
	ChatFrame1.GetHeight = function() return 300 end
	ChatFrame1Tab = H.NewFrame('Button')
	ns.ApplyEditMode()
	-- MainBar, Bar2 and Bar3 take the bottom rows (the fake bars are not shown); RightBar1 is the first side bar.
	local side = System(state.saved.layouts[1], 'RightBar1')
	local bottom = 1588 - (300 + 20 + 4) / 0.48 - 2
	H.check(Near(side.anchorInfo.offsetY, -bottom * 0.48), 'side bars: above Blizzard\'s chat tabs')

	C_AddOns.IsAddOnLoaded = function(name) return name == 'Chattynator' end
	ns.ApplyEditMode()
	H.check(Near(side.anchorInfo.offsetY, -1282 * 0.48), 'side bars: the Chattynator place when it is loaded')
	C_AddOns.IsAddOnLoaded = function() return false end
	ChatFrame1.GetHeight = function() return 100 end
	ns.ApplyEditMode()
	H.check(Near(side.anchorInfo.offsetY, -1282 * 0.48), 'side bars: never lower than the Chattynator place')
	ChatFrame1, ChatFrame1Tab = nil, nil
	H.noErrors()
end

------------------------------------------------------------------------
-- UI size.
------------------------------------------------------------------------
do
	local ns = Boot()
	H.equal(ns.Fit(), 1, 'size: 100% is the fit of the screen')
	ns.C.screen.size = 120
	H.check(Near(ns.Fit(), 1.2), 'size: 120% makes everything a fifth bigger')
end

------------------------------------------------------------------------
-- The way back to the layout used before the first Apply.
------------------------------------------------------------------------
do
	-- Blizzard's Modern preset (the first entry) was in use.
	local ns = Boot()
	local state = EditModeClient(1)
	ns.ApplyEditMode()
	H.equal(ns.CharDB.oldLayout, 'Modern', 'old layout: the preset in use before the Apply is kept')
	state.saved.activeLayout = 2
	ns.ApplyEditMode()
	H.equal(ns.CharDB.oldLayout, 'Modern', 'old layout: a later Apply over our own layout keeps it')
	H.equal(ns.OldLayoutName(), 'Modern', 'old layout: its name for the button')
	ns.RestoreOldLayout()
	H.equal(state.active, 1, 'old layout: the button makes it active again')

	ns.CharDB.oldLayout = 'Gone'
	H.equal(ns.OldLayoutName(), 'Modern', 'old layout: Modern when the kept one is no longer there')
	H.noErrors()
end

------------------------------------------------------------------------
-- The Edit Mode overlays go when the Edit Mode window closes, also without EditMode.Exit.
------------------------------------------------------------------------
do
	local callbacks = {}
	EventRegistry = { RegisterCallback = function(_, event, fn) callbacks[event] = fn end }
	local ns = Boot()
	EditModeManagerFrame = H.NewFrame('Frame')
	EditModeManagerFrame:Show()
	H.load('Movers.lua')
	local item = { key = 'player', frame = H.NewFrame('Frame'), w = 100, h = 20 }
	ns.Placed = { item }
	ns.Place = function() end
	H.fire('PLAYER_LOGIN')
	callbacks['EditMode.Enter']()
	local overlay
	for _, f in ipairs(H.frames) do
		local strata = f._calls and f._calls.SetFrameStrata
		if strata and strata[1][1] == 'DIALOG' and f._calls.EnableMouseWheel then overlay = f end
	end
	H.check(overlay and overlay:IsShown(), 'overlays: shown in Edit Mode')
	-- Blizzard's exit code stops before EditMode.Exit; the window is closed all the same.
	EditModeManagerFrame:Hide()
	for _, f in ipairs(H.frames) do
		if f._scripts and f._scripts.OnUpdate and f:IsShown() then f._scripts.OnUpdate(f, 0.1) end
	end
	H.check(overlay and not overlay:IsShown(), 'overlays: hidden once the Edit Mode window is closed')
	EventRegistry, EditModeManagerFrame = nil, nil
	H.noErrors()
end

H.done()
