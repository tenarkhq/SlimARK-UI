-- 3.0 system parts: boss timeline and damage meter in Edit Mode (19, 20), the damage meter skin (20),
-- audio alerts button (21), world map coordinates (45), rare alert (46), macro maker (49), game
-- settings (50), profiles (51), quiet mode (52), screenshots (53), AFK screen (57) and battleground
-- timers (58). Run from the repository root:
--   lua5.1 tests/claude/system-3-0.lua
local H = dofile('tests/codex/lib/runtime.lua')

-- The fake frames know only the widget methods the helpers list; a few more are added here.
local function AddMethods(list)
	local index = getmetatable(H.NewFrame('Frame')).__index
	local i = 1
	while true do
		local name, value = debug.getupvalue(index, i)
		if not name then break end
		if name == 'methods' then
			for key, fn in pairs(list) do value[key] = fn end
			return
		end
		i = i + 1
	end
	error('the fake frame methods were not found')
end

local function Printed(text)
	for _, line in ipairs(H.prints) do
		if line:find(text, 1, true) then return true end
	end
	return false
end

-- A fresh client with these addon files. before runs ahead of ADDON_LOADED (saved variables).
local function Boot(files, features, flavor, before)
	local ns = H.setup()
	C_AddOns.GetAddOnMetadata = function(_, field)
		if field == 'X-SlimARK-Flavor' then return flavor or 'retail' end
		return '3.0.0'
	end
	H.tickers = {}
	C_Timer.NewTicker = function(interval, fn)
		local ticker = { interval = interval, fn = fn }
		function ticker:Cancel() self.cancelled = true end
		H.tickers[#H.tickers + 1] = ticker
		return ticker
	end
	AddMethods({
		EnableKeyboard = function() end, SetPropagateKeyboardInput = function() end,
		SetMaxLetters = function() end, HasFocus = function() return false end,
		SetFocus = function(self) self._focus = true end, HighlightText = function(self) self._highlight = true end,
	})
	H.load('Config.lua')
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	H.load('Core.lua')
	for _, file in ipairs(files) do H.load(file) end
	if before then before(ns) end
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	return ns
end

local function Driver()
	for _, f in ipairs(H.frames) do
		if f._events.ADDON_LOADED and f._scripts.OnEvent then return f end
	end
end

local function FindText(text)
	for _, f in ipairs(H.frames) do
		if f._kind == 'FontString' and f._text == text then return f end
	end
end

local function LastTicker(interval)
	for i = #H.tickers, 1, -1 do
		if H.tickers[i].interval == interval then return H.tickers[i] end
	end
end

------------------------------------------------------------------------
-- 19, 20: boss timeline, warnings and damage meter in the SlimARK Edit Mode layouts.
------------------------------------------------------------------------
local function EditModeClient(ns)
	local S = Enum.EditModeSystem
	local I = Enum.EditModeEncounterEventsSystemIndices
	local function Layout(name)
		return { layoutName = name, layoutType = Enum.EditModeLayoutType.Account, systems = {
			{ system = S.EncounterEvents, systemIndex = I.Timeline, settings = {} },
			{ system = S.EncounterEvents, systemIndex = I.CriticalWarnings, settings = {} },
			{ system = S.EncounterEvents, systemIndex = I.MediumWarnings, settings = {} },
			{ system = S.EncounterEvents, systemIndex = I.NormalWarnings, settings = {} },
			{ system = S.DamageMeter, settings = {} },
		} }
	end
	local saved = { layouts = { Layout('SlimARK-UI'), Layout('SlimARK-UI Heal') }, activeLayout = 2 }
	CopyTable = function(t) return t end
	tAppendAll = function(a, b) for _, v in ipairs(b) do a[#a + 1] = v end end
	Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 5 } }
	EditModePresetLayoutManager = { GetCopyOfPresetLayouts = function() return { { layoutName = 'Modern', layoutType = Enum.EditModeLayoutType.Preset, systems = {} } } end }
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

local function Setting(info, setting)
	for _, entry in ipairs(info.settings) do
		if entry.setting == setting then return entry.value end
	end
end

do
	local ns = Boot({})
	local state = EditModeClient(ns)
	H.check(ns.ApplyEditMode() == true and state.saves == 1, 'edit mode: the layouts are written')
	local layout = state.saved.layouts[1]
	local timeline, critical, normal, meter = layout.systems[1], layout.systems[2], layout.systems[4], layout.systems[5]
	local E = Enum.EditModeEncounterEventsSetting
	-- One unit is 0.48 of a layout pixel at 2560x1600 with the fake UI scale.
	H.equal(timeline.anchorInfo.point, 'TOP', 'timeline: anchored by its top')
	H.check(math.abs(timeline.anchorInfo.offsetX - 1280 * 0.48) < 0.01 and math.abs(timeline.anchorInfo.offsetY + 150 * 0.48) < 0.01,
		'timeline: top middle, 150 px down')
	H.equal(Setting(timeline, E.Orientation), Enum.EncounterEventsOrientation.Horizontal, 'timeline: horizontal')
	H.equal(Setting(timeline, E.OverallSize), 1, 'timeline: 60% overall size (1.2 px per unit)')
	H.check(math.abs(critical.anchorInfo.offsetY + 318 * 0.48) < 0.01 and math.abs(normal.anchorInfo.offsetY + 424 * 0.48) < 0.01,
		'warnings: stacked under the timeline')
	H.equal(Setting(critical, E.Orientation), nil, 'warnings: no orientation written')
	local D = Enum.EditModeDamageMeterSetting
	H.equal(Setting(meter, D.FrameWidth), 91, 'damage meter: the width of both Details windows (291 units)')
	H.equal(Setting(meter, D.FrameHeight), 0, 'damage meter: height kept at Blizzard\'s smallest')
	H.equal(Setting(meter, D.BarHeight), 0, 'damage meter: bar height kept at Blizzard\'s smallest')
	H.equal(meter.anchorInfo.point, 'BOTTOMRIGHT', 'damage meter: anchored by its bottom right corner')
	H.check(math.abs(meter.anchorInfo.offsetX - 2548 * 0.48) < 0.01 and math.abs(meter.anchorInfo.offsetY + 1588 * 0.48) < 0.01,
		'damage meter: where the Details windows end')
	H.check(state.saved.layouts[2].systems[5].anchorInfo ~= nil, 'damage meter: the healer layout too')
	H.noErrors()
end

do
	local ns = Boot({}, { encounterLayout = false, damageMeter = false })
	local state = EditModeClient(ns)
	ns.ApplyEditMode()
	local layout = state.saved.layouts[1]
	H.check(layout.systems[1].anchorInfo == nil and #layout.systems[1].settings == 0, 'timeline off: left alone')
	H.check(layout.systems[5].anchorInfo == nil and #layout.systems[5].settings == 0, 'damage meter off: left alone')
end

do
	-- WoW Forever: no such systems; nothing breaks.
	local ns = Boot({})
	local state = EditModeClient(ns)
	Enum.EditModeSystem = {}
	Enum.EditModeEncounterEventsSetting = nil
	Enum.EditModeDamageMeterSetting = nil
	H.check(ns.ApplyEditMode() == true, 'edit mode: a client without the systems still applies')
	H.check(state.saved.layouts[1].systems[1].anchorInfo == nil, 'edit mode: and writes nothing for them')
	H.noErrors()
end

------------------------------------------------------------------------
-- 20: the damage meter skin.
------------------------------------------------------------------------
local function FakeEntry()
	local entry = H.NewFrame('Button')
	entry.StatusBar = H.NewFrame('StatusBar', nil, entry)
	entry.StatusBar.Name = entry.StatusBar:CreateFontString()
	entry.StatusBar.Value = entry.StatusBar:CreateFontString()
	entry.StatusBar.BackgroundRegions = { entry.StatusBar:CreateTexture(), entry.StatusBar:CreateTexture() }
	entry.Icon = H.NewFrame('Frame', nil, entry)
	entry.Icon.Icon = entry.Icon:CreateTexture()
	entry.UpdateBackground = function(self)
		for _, region in ipairs(self.StatusBar.BackgroundRegions) do region:SetAlpha(1) end
	end
	entry.UpdateStyle = function() end
	return entry
end

local function FakeWindow()
	local window = H.NewFrame('Frame')
	window.Header = window:CreateTexture()
	local box = H.NewFrame('Frame', nil, window)
	window.MinimizeContainer = box
	box.Background = box:CreateTexture()
	box.ScrollBox = H.NewFrame('Frame', nil, box)
	box.ScrollBox.list = { FakeEntry() }
	box.ScrollBox.ForEachFrame = function(self, fn) for _, f in ipairs(self.list) do fn(f) end end
	box.LocalPlayerEntry = FakeEntry()
	window.SessionTimer = window:CreateFontString()
	return window
end

local function MeterClient(shown)
	local window = FakeWindow()
	ScrollUtil = { AddAcquiredFrameCallback = function(box, fn) box.acquired = fn end }
	C_DamageMeter = {}
	DamageMeter = H.NewFrame('Frame', 'DamageMeter')
	DamageMeter:SetShown(shown)
	DamageMeter.ForEachSessionWindow = function(_, fn) fn(window) end
	DamageMeter.SetupSessionWindow = function() end
	return window
end

do
	local ns = Boot({ 'Skins.lua' })
	local window = MeterClient(false)
	local entry = window.MinimizeContainer.ScrollBox.list[1]
	H.fire('PLAYER_LOGIN')
	H.equal(#H.calls(entry.StatusBar, 'SetStatusBarTexture'), 0, 'meter skin: nothing is touched while the meter is hidden')
	DamageMeter:Show()
	DamageMeter._scripts.OnShow(DamageMeter)
	local call = H.lastCall(entry.StatusBar, 'SetStatusBarTexture')
	H.check(call and call[1] == ns.SOFT, 'meter skin: the bars take the SlimARK texture when it shows')
	local font = H.lastCall(entry.StatusBar.Name, 'SetFont')
	H.check(font and font[1] == ns.FONT and font[3] == 'OUTLINE', 'meter skin: the names take the SlimARK font')
	H.check(H.lastCall(window.Header, 'SetColorTexture') ~= nil, 'meter skin: a flat header')
	H.equal(entry.StatusBar.BackgroundRegions[1]:GetAlpha(), 0, 'meter skin: Blizzard\'s bar shadow is hidden')
	entry:UpdateBackground()
	H.equal(entry.StatusBar.BackgroundRegions[2]:GetAlpha(), 0, 'meter skin: and stays hidden when Blizzard redraws it')
	H.check(H.lastCall(window.MinimizeContainer.LocalPlayerEntry.StatusBar, 'SetStatusBarTexture') ~= nil, 'meter skin: your own row too')
	local fresh = FakeEntry()
	window.MinimizeContainer.ScrollBox.acquired(nil, fresh)
	H.check(H.lastCall(fresh.StatusBar, 'SetStatusBarTexture') ~= nil, 'meter skin: a row the list hands out later')
	local second = FakeWindow()
	DamageMeter:SetupSessionWindow(2, { sessionWindow = second })
	H.check(H.lastCall(second.Header, 'SetColorTexture') ~= nil, 'meter skin: a second window opened later')
	local before = #H.calls(entry.StatusBar, 'SetStatusBarTexture')
	DamageMeter._scripts.OnShow(DamageMeter)
	H.equal(#H.calls(entry.StatusBar, 'SetStatusBarTexture'), before, 'meter skin: dressed only once')
	H.noErrors()
end

do
	Boot({ 'Skins.lua' }, { damageMeter = false })
	MeterClient(false)
	H.fire('PLAYER_LOGIN')
	H.check(DamageMeter._scripts.OnShow == nil, 'meter skin off: the meter is not even hooked')
end

------------------------------------------------------------------------
-- The settings schema of the new pages.
------------------------------------------------------------------------
do
	local ns = Boot({ 'Settings.lua', 'CVars.lua', 'Macros.lua', 'Quiet.lua', 'Profiles.lua' })
	local S = ns.Settings
	local KINDS = { range = true, toggle = true, color = true, button = true, choice = true, textbox = true }
	local pages, bad = {}, {}
	for _, group in ipairs(S.groups) do
		for _, page in ipairs(group.pages) do
			pages[page.id] = page
			for _, sec in ipairs(page.secs or {}) do
				for _, row in ipairs(sec.rows) do
					if not KINDS[row.t] or type(row.label) ~= 'string' then bad[#bad + 1] = tostring(row.label) end
					if row.t == 'toggle' or row.t == 'range' then
						if not row.path and not (row.get and row.set) then bad[#bad + 1] = row.label end
					end
				end
			end
		end
	end
	H.equal(#bad, 0, 'schema: every row has a known type, a label and a value to show')
	-- The macro maker and quiet mode are sections of the Quality of life pages Combat helpers and Less noise.
	for _, id in ipairs({ 'profiles', 'combathelpers', 'gamesettings', 'lessnoise', 'other' }) do
		H.check(pages[id] ~= nil, 'schema: the ' .. id .. ' page is there')
	end
	local function Section(id, name)
		for _, sec in ipairs(pages[id] and pages[id].secs or {}) do
			if sec.name == name then return sec end
		end
	end
	H.check(Section('combathelpers', 'Macros') and Section('combathelpers', 'Save as'), 'schema: the macro maker is on Combat helpers')
	H.check(Section('lessnoise', 'Quiet mode') and Section('lessnoise', 'Muted sounds'), 'schema: quiet mode is on Less noise')
	local wanted = {
		['features.encounterLayout'] = true, ['features.damageMeter'] = true, ['features.afkScreen'] = true,
		['features.bgTimers'] = true, ['features.mapCoords'] = false, ['features.rareAlert'] = false,
		['features.shotKey'] = false, ['features.shotKill'] = false, ['features.shotAchievement'] = false,
	}
	for path, default in pairs(wanted) do
		H.equal(S.defaults[path], default, 'schema: default of ' .. path)
	end
	H.equal(S.defaults['bgtimers.x'], 1920, 'schema: the battleground timers have a position')
end

------------------------------------------------------------------------
-- 21, 50: game settings and the audio alerts button.
------------------------------------------------------------------------
local cvars, writes
local function CVarClient()
	cvars = { cameraDistanceMaxZoomFactor = '1.9', SpellQueueWindow = '400', ShakeStrengthCamera = '1', ShakeStrengthUI = '0.25' }
	writes = {}
	C_CVar = {
		GetCVar = function(name) return cvars[name] end,
		SetCVar = function(name, value) writes[#writes + 1] = name cvars[name] = tostring(value) end,
		GetCVarDefault = function() return '1' end,
	}
end

do
	local ns = Boot({ 'Settings.lua', 'CVars.lua' })
	CVarClient()
	local G = ns.GameSettings
	H.equal(G.Number('cameraDistanceMaxZoomFactor'), 1.9, 'game settings: the current value is shown')
	local overlap
	for _, group in ipairs(ns.Settings.groups) do
		for _, page in ipairs(group.pages) do
			for _, sec in ipairs(page.secs or {}) do
				for _, row in ipairs(sec.rows) do
					if row.label == 'Nameplate overlap' then overlap = row end
				end
			end
		end
	end
	H.check(overlap and overlap.hidden(), 'game settings: a setting the client lacks hides its row')
	G.Write('SpellQueueWindow', 400)
	H.equal(#writes, 0, 'game settings: an unchanged value is not written')
	G.Write('SpellQueueWindow', 250)
	H.check(#writes == 1 and cvars.SpellQueueWindow == '250', 'game settings: only the changed one is written')
	H.combat = true
	H.equal(G.Write('cameraDistanceMaxZoomFactor', 2.6), 'later', 'game settings: in combat it waits')
	H.check(#writes == 1 and G.Number('cameraDistanceMaxZoomFactor') == 2.6, 'game settings: nothing written in combat, the row shows the new value')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.check(#writes == 2 and cvars.cameraDistanceMaxZoomFactor == '2.6', 'game settings: written when the fight ends')
	H.check(G.ShakeOn(), 'screen shake: on while either strength is above 0')
	G.SetShake(false)
	H.check(cvars.ShakeStrengthCamera == '0' and cvars.ShakeStrengthUI == '0' and not G.ShakeOn(), 'screen shake: off sets both to 0')
	G.SetShake(true)
	H.check(cvars.ShakeStrengthCamera == '1' and cvars.ShakeStrengthUI == '1', 'screen shake: on gives the default back')
	H.noErrors()
end

do
	local ns = Boot({ 'CVars.lua' })
	local opened
	ACCESSIBILITY_AUDIO_LABEL = 'Audio'
	CAA_ENABLE_COMBAT_AUDIO_ALERTS = 'Enable Combat Audio Alerts'
	local function Category(name, id) return { GetName = function() return name end, GetID = function() return id end } end
	local categories = { Category('Gameplay', 1), Category('Audio', 42) }
	SettingsPanel = { GetAllCategories = function() return categories end }
	Settings = { OpenToCategory = function(id, element) opened = { id, element } end, AUDIO_CATEGORY_ID = 7 }
	ns.GameSettings.OpenAudioAlerts()
	H.check(opened and opened[1] == 42 and opened[2] == 'Enable Combat Audio Alerts', 'audio alerts: the game\'s accessibility audio page opens')
	categories = {}
	ns.GameSettings.OpenAudioAlerts()
	H.equal(opened[1], 7, 'audio alerts: without that page the audio page opens')
	opened = nil
	H.combat = true
	ns.GameSettings.OpenAudioAlerts()
	H.check(opened == nil and Printed('Not possible in combat'), 'audio alerts: not in combat')
end

------------------------------------------------------------------------
-- 49: macro maker.
------------------------------------------------------------------------
local macros, known, bags
local function MacroClient()
	macros, known, bags = {}, {}, {}
	local order = {}
	GetMacroIndexByName = function(name) return macros[name] and macros[name].index or 0 end
	GetNumMacros = function()
		local account, character = 0, 0
		for _, m in pairs(macros) do if m.perCharacter then character = character + 1 else account = account + 1 end end
		return account, character
	end
	CreateMacro = function(name, icon, body, perCharacter)
		order[#order + 1] = name
		macros[name] = { index = #order, icon = icon, body = body, perCharacter = perCharacter, edits = 0 }
	end
	EditMacro = function(index, name, icon, body)
		for _, m in pairs(macros) do
			if m.index == index then m.body = body m.edits = m.edits + 1 end
		end
	end
	Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } }
	C_SpellBook = { IsSpellKnownOrInSpellBook = function(id, bank) return bank == nil and known[id] == true end }
	local names = { [96231] = 'Rebuke', [4987] = 'Cleanse', [19647] = 'Spell Lock' }
	C_Spell = { GetSpellName = function(id) return names[id] end }
	C_Item = { GetItemCount = function(id) return bags[id] or 0 end }
end

do
	local ns = Boot({ 'Macros.lua' })
	MacroClient()
	local M = ns.Macros
	known[96231], known[4987] = true, true
	H.equal(M.Label('kick'), 'Create focus kick', 'macros: Create before the macro is there')
	M.Make('kick')
	local kick = macros['SlimARK Kick']
	H.check(kick and kick.body == '#showtooltip\n/cast [@focus,harm,nodead][] Rebuke', 'macros: focus kick with your interrupt')
	H.check(kick.perCharacter == true, 'macros: a character macro by default')
	H.equal(M.Label('kick'), 'Update focus kick', 'macros: Update once it is there')
	M.Make('kick')
	H.check(kick.edits == 1 and macros['SlimARK Kick'] == kick, 'macros: the second click rewrites the same macro')
	M.Make('dispel')
	H.equal(macros['SlimARK Dispel'].body, '#showtooltip\n/cast [@mouseover,help,nodead][] Cleanse', 'macros: mouseover dispel with your dispel')
	bags[241304], bags[224464] = 3, 1
	M.SetScope('account')
	M.Make('heal')
	local heal = macros['SlimARK Heal']
	H.check(heal.body == '#showtooltip\n/use item:224464\n/use item:241304', 'macros: your healthstone and the potion in your bags')
	H.check(heal.perCharacter == false, 'macros: an account macro when asked for')
	H.noErrors()
end

do
	local ns = Boot({ 'Macros.lua' })
	MacroClient()
	ns.Macros.Make('kick')
	H.check(macros['SlimARK Kick'] == nil and Printed('You know no interrupt'), 'macros: no interrupt, no macro, a plain message')
	known[19647] = nil
	C_SpellBook.IsSpellKnownOrInSpellBook = function(id, bank) return id == 19647 and bank ~= nil end
	ns.Macros.Make('kick')
	H.check(macros['SlimARK Kick'] and macros['SlimARK Kick'].body:find('Spell Lock', 1, true), 'macros: a pet interrupt counts')
	ns.Macros.Make('heal')
	H.check(macros['SlimARK Heal'].body == '#showtooltip\n/use item:5512' and Printed('No healing potion'), 'macros: without a potion only the healthstone')
end

do
	local ns = Boot({ 'Macros.lua' })
	MacroClient()
	known[4987] = true
	H.combat = true
	H.equal(ns.Macros.Make('dispel'), 'later', 'macros: a click in combat waits')
	H.check(macros['SlimARK Dispel'] == nil, 'macros: nothing is made in combat')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.check(macros['SlimARK Dispel'] ~= nil, 'macros: made when the fight ends')
	-- Full character macros.
	for i = 1, 30 do macros['x' .. i] = { index = 200 + i, perCharacter = true } end
	known[96231] = true
	ns.Macros.Make('kick')
	H.check(macros['SlimARK Kick'] == nil and Printed('character macros are full'), 'macros: full character macros, a plain message')
end

------------------------------------------------------------------------
-- 51: profiles.
------------------------------------------------------------------------
local packed
local function Encoder()
	packed = {}
	local function Copy(v)
		if type(v) ~= 'table' then return v end
		local out = {}
		for k, x in pairs(v) do out[k] = Copy(x) end
		return out
	end
	C_EncodingUtil = {
		SerializeCBOR = function(value) packed[#packed + 1] = Copy(value) return 'cbor' .. #packed end,
		DeserializeCBOR = function(text) local n = tonumber(text:match('^cbor(%d+)$')) if not n then error('bad cbor') end return Copy(packed[n]) end,
		CompressString = function(text) return 'z' .. text end,
		DecompressString = function(text) if text:sub(1, 1) ~= 'z' then error('bad deflate') end return text:sub(2) end,
		EncodeBase64 = function(text) return 'b' .. text end,
		DecodeBase64 = function(text) if text:sub(1, 1) ~= 'b' then error('bad base64') end return text:sub(2) end,
	}
end

local function Pack(settings, format)
	packed[#packed + 1] = { format = format or 1, settings = settings }
	return 'SlimARK:' .. (format or 1) .. ':bzcbor' .. #packed
end

do
	local reloads = 0
	ReloadUI = function() reloads = reloads + 1 end
	local ns = Boot({ 'Settings.lua', 'Profiles.lua' }, nil, nil, function()
		SlimARKDB = { settings = { ['features.mapCoords'] = true, ['chat.x'] = 40 } }
	end)
	Encoder()
	local P, S = ns.Profiles, ns.Settings
	H.check(ns.C.chat.x == 40 and ns.C.features.mapCoords == true, 'profiles: the shared changes load')
	local text = P.Export()
	H.equal(text, 'SlimARK:1:bzcbor1', 'profiles: export is one line with the SlimARK:1: mark')
	H.check(packed[1].settings['chat.x'] == 40 and packed[1].settings['features.mapCoords'] == true, 'profiles: the export holds the saved changes')
	local box = H.NewFrame('EditBox')
	P.ExportTo(box)
	H.check(box._text == 'SlimARK:1:bzcbor2' and box._highlight, 'profiles: the text is put in the box, selected')

	local ok, message = P.Import('hello')
	H.check(not ok and message:find('not a SlimARK-UI profile', 1, true), 'import: a foreign text is named in plain words')
	ok, message = P.Import('SlimARK:1:xyz')
	H.check(not ok and message:find('damaged or cut off', 1, true), 'import: a damaged text is named')
	ok, message = P.Import('SlimARK:2:bzcbor1')
	H.check(not ok and message:find('newer SlimARK-UI', 1, true), 'import: a text of a newer version is named')
	ok, message = P.Import('   ')
	H.check(not ok and message:find('Paste', 1, true), 'import: an empty box asks for a text')
	H.equal(S.PendingCount(), 0, 'import: a failed import changes nothing')

	local good = Pack({ ['chat.x'] = 99, ['features.rareAlert'] = true, ['colors.track'] = { 0.1, 0.2, 0.3 },
		['unknown.path'] = 1, ['chat.w'] = 'wide', ['markers.place'] = 'nowhere', ['chat.fontSize'] = 500 })
	-- A pasted text may have broken lines.
	ok, message = P.Import(good:sub(1, 8) .. '\n ' .. good:sub(9))
	H.check(ok and message:find('3 changed settings', 1, true) and message:find('4 values', 1, true), 'import: good values taken, the rest counted')
	H.equal(S.pending['chat.x'], 99, 'import: a number is taken')
	H.equal(S.pending['features.rareAlert'], true, 'import: a switch is taken')
	H.check(S.pending['colors.track'] and S.pending['colors.track'][2] == 0.2, 'import: a color is taken')
	H.equal(S.pending['features.mapCoords'], false, 'import: a setting missing from the text goes back to its default')
	H.check(S.pending['markers.place'] == nil and S.pending['chat.fontSize'] == nil and S.pending['chat.w'] == nil, 'import: wrong values are left out')
	H.check(ns.C.chat.x == 40, 'import: nothing applies before Save')
	S.Undo()

	-- Profile per character.
	P.SetPerCharacter(true)
	H.check(P.IsPerCharacter() and SlimARKCharDB.settings['chat.x'] == 40, 'per character: starts from a copy of the shared changes')
	H.equal(S.Store(), SlimARKCharDB.settings, 'per character: saving goes to the character')
	S.Set('chat.x', 77)
	S.Save()
	H.check(SlimARKCharDB.settings['chat.x'] == 77 and SlimARKDB.settings['chat.x'] == 40, 'per character: the shared changes stay as they were')
	local before = reloads
	P.SetPerCharacter(false)
	H.check(not P.IsPerCharacter() and reloads == before + 1, 'per character: off goes back to the shared changes with a reload')
	H.combat = true
	P.SetPerCharacter(true)
	H.check(not P.IsPerCharacter() and Printed('Not possible in combat'), 'per character: not switched in combat')
	H.combat = false
	H.noErrors()
end

do
	local ns = Boot({ 'Settings.lua', 'Profiles.lua' }, nil, nil, function()
		SlimARKDB = { settings = { ['chat.x'] = 40 } }
		SlimARKCharDB = { ownProfile = true, settings = { ['chat.x'] = 55 } }
	end)
	H.equal(ns.C.chat.x, 55, 'per character: a character with its own profile loads its own changes')
	C_EncodingUtil = nil
	local text, problem = ns.Profiles.Export()
	H.check(text == nil and problem:find('encoder', 1, true), 'profiles: a client without the encoder says so')
end

-- The look picked in the setup window goes to the character's own profile when it has one, and
-- leaves the account's settings alone.
do
	local ns = Boot({ 'Settings.lua', 'Setup.lua' }, nil, nil, function()
		SlimARKDB = { settings = {} }
		SlimARKCharDB = { ownProfile = true, settings = {} }
	end)
	ns.C.blizz.look = nil
	ns.ApplyAll = function() return true end
	UISpecialFrames = {}
	tinsert = tinsert or table.insert
	ns.ShowSetup()
	local frame = _G.SlimARK_Setup
	local card = frame.cards[2]
	card:GetScript('OnClick')(card)
	frame.apply:GetScript('OnClick')(frame.apply)
	H.equal(SlimARKCharDB.settings['blizz.look'], card.key, 'setup: the look is saved in the character profile')
	H.equal(SlimARKDB.settings['blizz.look'], nil, 'setup: the account settings stay as they were')
	H.equal(ns.C.blizz.look, card.key, 'setup: the look applies at once')
	H.noErrors()
end

------------------------------------------------------------------------
-- 52: quiet mode.
------------------------------------------------------------------------
local muted
local function QuietClient()
	muted = {}
	MuteSoundFile = function(id) muted[id] = true end
	UnmuteSoundFile = function(id) muted[id] = nil end
	BossBanner = H.NewFrame('Frame', 'BossBanner')
	ZoneTextFrame = H.NewFrame('Frame', 'ZoneTextFrame')
	SubZoneTextFrame = H.NewFrame('Frame', 'SubZoneTextFrame')
	BNToastFrame = H.NewFrame('Frame', 'BNToastFrame')
end

do
	local ns = Boot({ 'Quiet.lua' })
	QuietClient()
	H.fire('PLAYER_LOGIN')
	local Q = ns.Quiet
	H.check(not Q.IsOn(), 'quiet: off by default')
	H.check(ZoneTextFrame._scripts.OnShow == nil and BossBanner._scripts.OnShow == nil, 'quiet off: nothing is hooked')
	H.check(Q.SetSounds('569593, 12345;12345') and next(muted) == nil, 'quiet: the list is kept, nothing muted while off')
	H.equal(Q.SoundText(), '569593, 12345', 'quiet: the list as text, without doubles')
	local updates = 0
	ns.UpdateQuietSegment = function() updates = updates + 1 end
	Q.Toggle()
	H.check(Q.IsOn() and muted[569593] and muted[12345], 'quiet: on mutes the list')
	H.equal(updates, 1, 'quiet: the top bar element is told')
	ZoneTextFrame._scripts.OnShow(ZoneTextFrame)
	H.check(not ZoneTextFrame:IsShown(), 'quiet: the zone text stays hidden')
	BNToastFrame._scripts.OnShow(BNToastFrame)
	H.check(not BNToastFrame:IsShown(), 'quiet: a Battle.net toast stays hidden')
	local finished = 0
	BossBanner_Stop = function(self) self:Hide() end
	TopBannerMgr = { currentBanner = { frame = BossBanner } }
	TopBannerManager_BannerFinished = function() finished = finished + 1 end
	BossBanner:Show()
	BossBanner._scripts.OnShow(BossBanner)
	H.equal(BossBanner:GetAlpha(), 0, 'quiet: the boss banner is not seen')
	H.runTimers(0)
	H.check(not BossBanner:IsShown() and finished == 1 and BossBanner:GetAlpha() == 1, 'quiet: the banner is dismissed the game\'s own way')
	H.check(not Q.SetSounds('569593 abc') and Printed('"abc" is not a sound file ID'), 'quiet: a wrong entry is named, the list stays')
	H.equal(Q.SoundText(), '569593, 12345', 'quiet: the old list is kept')
	Q.SetSounds('569593')
	H.check(muted[569593] and not muted[12345], 'quiet: a sound taken off the list is heard again')
	Q.SetHides(false)
	ZoneTextFrame:Show()
	ZoneTextFrame._scripts.OnShow(ZoneTextFrame)
	H.check(ZoneTextFrame:IsShown(), 'quiet: the banners can be left on')
	Q.Toggle()
	H.check(not Q.IsOn() and next(muted) == nil and updates == 4, 'quiet: off hears everything again')
	H.noErrors()
end

do
	-- The game forgets muted sounds at a reload: they are muted again at login.
	local ns = Boot({ 'Quiet.lua' }, nil, nil, function()
		SlimARKDB = { quiet = { on = true, hide = true, sounds = { 42 } } }
	end)
	QuietClient()
	H.fire('PLAYER_LOGIN')
	H.check(ns.Quiet.IsOn() and muted[42], 'quiet: on at login mutes the list again')
end

------------------------------------------------------------------------
-- 53: screenshots.
------------------------------------------------------------------------
local shots, completion
local function ShotClient()
	shots, completion = 0, { onTime = true, practiceRun = false }
	Screenshot = function() shots = shots + 1 end
	C_ChallengeMode = { GetChallengeCompletionInfo = function() return completion end }
end

do
	Boot({ 'Screenshots.lua' }, { shotKey = true, shotAchievement = true })
	ShotClient()
	H.fire('PLAYER_LOGIN')
	H.fire('CHALLENGE_MODE_COMPLETED')
	H.equal(shots, 0, 'screenshot: taken a moment later, with the banner on it')
	H.runTimers(1)
	H.equal(shots, 1, 'screenshot: a timed key')
	completion.onTime = false
	H.fire('CHALLENGE_MODE_COMPLETED')
	H.runTimers(1)
	H.equal(shots, 1, 'screenshot: not for a depleted key')
	H.fire('BOSS_KILL', 1, 'Boss')
	H.runTimers(1)
	H.equal(shots, 1, 'screenshot: the boss kill switch is its own')
	H.fire('ACHIEVEMENT_EARNED', 5, false)
	H.fire('ACHIEVEMENT_EARNED', 6, false)
	H.runTimers(1)
	H.equal(shots, 2, 'screenshot: two achievements at once give one picture')
	H.fire('ACHIEVEMENT_EARNED', 7, true)
	H.runTimers(1)
	H.equal(shots, 2, 'screenshot: not for one earned before on the account')
end

do
	Boot({ 'Screenshots.lua' })
	ShotClient()
	H.fire('PLAYER_LOGIN')
	local driver = Driver()
	H.check(not driver._events.CHALLENGE_MODE_COMPLETED and not driver._events.BOSS_KILL and not driver._events.ACHIEVEMENT_EARNED,
		'screenshot off: no event is registered')
	Boot({ 'Screenshots.lua' }, { shotKey = true }, 'forever')
	ShotClient()
	H.fire('PLAYER_LOGIN')
	H.check(not Driver()._events.CHALLENGE_MODE_COMPLETED, 'screenshot: no key screenshot in WoW Forever')
end

------------------------------------------------------------------------
-- 57: AFK screen.
------------------------------------------------------------------------
local afk
local function AFKClient()
	afk = false
	WorldFrame = H.NewFrame('Frame', 'WorldFrame')
	UnitIsAFK = function() return afk end
	UnitAffectingCombat = function() return false end
	UnitName = function() return 'Aril' end
	UnitClass = function() return 'Paladin', 'PALADIN' end
	C_ClassColor = { GetClassColor = function() return { r = 0.96, g = 0.55, b = 0.73 } end }
	GetAverageItemLevel = function() return 679, 681.4 end
	C_SpecializationInfo = { GetSpecialization = function() return 3 end, GetSpecializationInfo = function() return 70, 'Retribution' end }
	C_MythicPlus = { GetOwnedKeystoneChallengeMapID = function() return 500 end, GetOwnedKeystoneLevel = function() return 12 end }
	C_ChallengeMode = { GetMapUIInfo = function() return 'Voidscar Arena' end }
end

local function Screen()
	for _, f in ipairs(H.frames) do
		if f._parent == WorldFrame then return f end
	end
end

local function Watcher()
	for _, f in ipairs(H.frames) do
		if f._events.PLAYER_FLAGS_CHANGED then return f end
	end
end

do
	Boot({ 'AFK.lua' })
	AFKClient()
	H.fire('PLAYER_LOGIN')
	local watcher = Watcher()
	H.check(watcher and watcher._events.PLAYER_FLAGS_CHANGED[1] == 'player', 'afk: only the player\'s flags are listened to')
	H.check(Screen() == nil, 'afk: no screen is made before you go AFK')
	afk = true
	H.fire('PLAYER_FLAGS_CHANGED', 'player')
	local screen = Screen()
	H.check(screen and screen:IsShown() and UIParent:GetAlpha() == 0, 'afk: the interface fades, the screen shows')
	H.check(FindText('Aril') and FindText('681  ·  Retribution  ·  Voidscar Arena +12'), 'afk: name, item level, spec and key in the middle')
	local ticker = LastTicker(1)
	H.check(ticker and not ticker.cancelled, 'afk: the clock counts once a second while shown')
	H.now = H.now + 252
	ticker.fn()
	H.check(FindText('4:12 away'), 'afk: the time away')
	H.check(watcher._events.PLAYER_STARTED_MOVING and watcher._events.PLAYER_REGEN_DISABLED, 'afk: movement and combat listened to while shown')
	H.fire('PLAYER_STARTED_MOVING')
	H.check(not screen:IsShown() and UIParent:GetAlpha() == 1 and ticker.cancelled, 'afk: moving brings the interface back and stops the clock')
	H.check(not watcher._events.PLAYER_STARTED_MOVING, 'afk: movement is not listened to any more')
	H.fire('PLAYER_FLAGS_CHANGED', 'player')
	H.check(not screen:IsShown(), 'afk: still AFK after moving, the screen stays away')
	afk = false
	H.fire('PLAYER_FLAGS_CHANGED', 'player')
	afk = true
	H.fire('PLAYER_FLAGS_CHANGED', 'player')
	H.check(screen:IsShown(), 'afk: shown again the next time you go AFK')
	screen._scripts.OnKeyDown(screen, 'ESCAPE')
	H.check(not screen:IsShown() and UIParent:GetAlpha() == 1, 'afk: a key brings the interface back')
	afk = false
	H.fire('PLAYER_FLAGS_CHANGED', 'player')
	afk = true
	H.combat = true
	H.fire('PLAYER_FLAGS_CHANGED', 'player')
	H.check(not screen:IsShown(), 'afk: not in combat')
	H.combat = false
	afk = false
	H.fire('PLAYER_FLAGS_CHANGED', 'player')
	local secret = {}
	H.secret = { [secret] = true }
	UnitIsAFK = function() return secret end
	H.fire('PLAYER_FLAGS_CHANGED', 'player')
	H.check(not screen:IsShown(), 'afk: a secret flag changes nothing')
	H.noErrors()
end

do
	Boot({ 'AFK.lua' }, { afkScreen = false })
	AFKClient()
	H.fire('PLAYER_LOGIN')
	H.check(Watcher() == nil, 'afk off: nothing is listened to')
end

------------------------------------------------------------------------
-- 46: rare alert.
------------------------------------------------------------------------
local sounds, vignettes
local function RareClient()
	sounds = {}
	vignettes = {
		g1 = { name = 'Kronolith, Might of the Mountain', atlasName = 'VignetteKillElite', isDead = false },
		g2 = { name = 'Glimmering Chest', atlasName = 'VignetteLoot', isDead = false },
		g3 = { name = 'SECRETNAME', atlasName = 'VignetteKill', isDead = false },
		g4 = { name = 'Dead Rare', atlasName = 'VignetteKill', isDead = true },
	}
	C_VignetteInfo = { GetVignetteInfo = function(guid) return vignettes[guid] end }
	SOUNDKIT = { MAP_PING = 3175 }
	PlaySound = function(id, channel) sounds[#sounds + 1] = id .. ':' .. channel end
	GetMinimapZoneText = function() return 'Isle of Dorn' end
end

do
	Boot({ 'RareAlert.lua' }, { rareAlert = true })
	RareClient()
	H.fire('PLAYER_LOGIN')
	H.fire('VIGNETTE_MINIMAP_UPDATED', 'g1', true)
	H.check(#sounds == 1 and sounds[1] == '3175:SFX', 'rare: one quiet built-in sound')
	local text = FindText('Kronolith, Might of the Mountain is up nearby')
	H.check(text and text:GetParent():IsShown() and FindText('RARE  ·  Isle of Dorn'), 'rare: a short text at the top')
	H.fire('VIGNETTE_MINIMAP_UPDATED', 'g1', false)
	H.fire('VIGNETTE_MINIMAP_UPDATED', 'g1', true)
	H.equal(#sounds, 1, 'rare: the same rare never sounds again')
	H.fire('VIGNETTE_MINIMAP_UPDATED', 'g2', true)
	H.fire('VIGNETTE_MINIMAP_UPDATED', 'g4', true)
	H.equal(#sounds, 1, 'rare: treasures and dead rares are left out')
	H.secret = { SECRETNAME = true }
	H.fire('VIGNETTE_MINIMAP_UPDATED', 'g3', true)
	H.equal(#sounds, 1, 'rare: a secret name is never used')
	H.runTimers(5)
	H.check(not text:GetParent():IsShown(), 'rare: the text goes after a few seconds')
	H.noErrors()
end

do
	Boot({ 'RareAlert.lua' })
	RareClient()
	H.fire('PLAYER_LOGIN')
	H.fire('VIGNETTE_MINIMAP_UPDATED', 'g1', true)
	H.check(#sounds == 0 and not Driver()._events.VIGNETTE_MINIMAP_UPDATED, 'rare off: nothing is registered, nothing sounds')
end

------------------------------------------------------------------------
-- 45: world map coordinates.
------------------------------------------------------------------------
local inInstance, playerPos
local function MapClient()
	inInstance, playerPos = false, { x = 0.452, y = 0.678 }
	WorldMapFrame = H.NewFrame('Frame', 'WorldMapFrame')
	WorldMapFrame:Hide()
	WorldMapFrame.ScrollContainer = H.NewFrame('Frame', nil, WorldMapFrame)
	WorldMapFrame.GetMapID = function() return 2248 end
	WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition = function() return 0.123, 0.456 end
	WorldMapFrame.ScrollContainer.IsMouseOver = function() return true end
	C_Map = { GetPlayerMapPosition = function() return playerPos end }
	IsInInstance = function() return inInstance end
end

do
	Boot({ 'MapCoords.lua' }, { mapCoords = true })
	MapClient()
	H.fire('PLAYER_LOGIN')
	H.check(#H.tickers == 0, 'map: no timer while the map is closed')
	WorldMapFrame:Show()
	WorldMapFrame._scripts.OnShow(WorldMapFrame)
	local text = FindText('Player  45.2, 67.8      Cursor  12.3, 45.6')
	H.check(text and text:GetParent():IsShown(), 'map: your position and the mouse\'s')
	local ticker = LastTicker(0.1)
	H.check(ticker and not ticker.cancelled, 'map: a light timer while the map is open')
	WorldMapFrame._scripts.OnHide(WorldMapFrame)
	H.check(ticker.cancelled, 'map: the timer stops when the map closes')
	local secret = 0.5
	playerPos = { x = secret, y = secret }
	H.secret = { [secret] = true }
	WorldMapFrame._scripts.OnShow(WorldMapFrame)
	H.check(FindText('Player  -      Cursor  12.3, 45.6'), 'map: a secret position is not shown')
	inInstance = true
	LastTicker(0.1).fn()
	H.check(not text:GetParent():IsShown(), 'map: nothing inside instances')
	H.noErrors()
end

do
	Boot({ 'MapCoords.lua' })
	MapClient()
	H.fire('PLAYER_LOGIN')
	H.check(WorldMapFrame._scripts.OnShow == nil, 'map off: the map is not hooked')
end

------------------------------------------------------------------------
-- 58: battleground timers.
------------------------------------------------------------------------
local instance, pois, blitz
local function BGClient()
	instance = { 'Arathi Basin', 'pvp', 0, '', 0, 0, false, 2107 }
	pois = { [1] = { name = 'Stables', atlasName = 'node-neutral' }, [2] = { name = 'Farm', atlasName = 'node-horde' } }
	blitz = false
	GetInstanceInfo = function() return unpack(instance) end
	C_Map = { GetBestMapForUnit = function() return 1366 end }
	C_AreaPoiInfo = {
		GetAreaPOIForMap = function() return { 1, 2 } end,
		GetAreaPOIInfo = function(_, id) return pois[id] end,
	}
	C_PvP = { IsRatedSoloRBG = function() return blitz end }
end

local function Bars()
	local out = {}
	for _, f in ipairs(H.frames) do
		if f._kind == 'StatusBar' and f.name and f:IsShown() then out[#out + 1] = f end
	end
	return out
end

local function Change(id, atlas)
	pois[id].atlasName = atlas
	H.fire('AREA_POIS_UPDATED')
end

do
	Boot({ 'BGTimers.lua' })
	BGClient()
	H.fire('PLAYER_LOGIN')
	H.fire('PLAYER_ENTERING_WORLD')
	local watcher
	for _, f in ipairs(H.frames) do if f._events.AREA_POIS_UPDATED then watcher = f end end
	H.check(watcher ~= nil, 'bg: the map icons are listened to in Arathi Basin')
	H.equal(#Bars(), 0, 'bg: the icons seen on entering start nothing')
	Change(1, 'node-assault-alliance')
	local bars = Bars()
	H.check(#bars == 1 and bars[1].name._text == 'Stables' and bars[1].time._text == '1:00', 'bg: an assaulted base counts down a minute')
	local ticker = LastTicker(0.2)
	H.now = H.now + 20
	ticker.fn()
	H.equal(bars[1].time._text, '0:40', 'bg: the bar counts')
	Change(1, 'node-neutral')
	H.check(#Bars() == 0 and ticker.cancelled, 'bg: defended, back to its old icon: the bar goes and the clock stops')
	Change(1, 'node-assault-alliance')
	H.now = H.now + 10
	Change(1, 'node-assault-horde')
	bars = Bars()
	H.check(#bars == 1 and bars[1].time._text == '1:00', 'bg: assaulted back on the way: the count starts again')
	H.now = H.now + 58
	Change(1, 'node-horde')
	H.equal(#Bars(), 0, 'bg: taken at the end: the bar goes')
	Change(2, 'node-assault-alliance')
	H.now = H.now + 61
	LastTicker(0.2).fn()
	H.equal(#Bars(), 0, 'bg: the count runs out')
	Change(2, 'node-alliance')
	H.equal(#Bars(), 0, 'bg: the capture a moment after the end starts nothing')
	Change(2, 'node-assault-horde')
	H.equal(#Bars(), 1, 'bg: the next assault counts again')
	H.noErrors()

	-- Blitz takes half.
	blitz = true
	H.fire('PLAYER_ENTERING_WORLD')
	H.equal(#Bars(), 0, 'bg: a new battleground starts clean')
	Change(1, 'node-assault-alliance-2')
	H.equal(Bars()[1].time._text, '0:30', 'bg: half the time in Blitz')

	-- Alterac Valley changes icons for mines too: no timers there.
	instance[8] = 30
	H.fire('PLAYER_ENTERING_WORLD')
	H.check(not watcher._events.AREA_POIS_UPDATED and #Bars() == 0, 'bg: battlegrounds with other icons are not watched')

	-- A secret icon is never compared.
	instance[8] = 2107
	H.fire('PLAYER_ENTERING_WORLD')
	H.secret = { SECRET = true }
	Change(1, 'SECRET')
	H.equal(#Bars(), 0, 'bg: a secret icon is left alone')
	H.noErrors()
end

do
	Boot({ 'BGTimers.lua' }, { bgTimers = false })
	BGClient()
	H.fire('PLAYER_LOGIN')
	H.fire('PLAYER_ENTERING_WORLD')
	local listened = false
	for _, f in ipairs(H.frames) do if f._events.AREA_POIS_UPDATED then listened = true end end
	H.check(not listened and not Driver()._events.PLAYER_ENTERING_WORLD, 'bg off: nothing is registered')
end

H.done()
