-- The /slimark settings window: its size and the corner grip, the group tabs, the page list, the
-- section cards in one or two columns, and the Quality of life group in six pages. Run from the
-- repository root:
--   lua5.1 tests/claude/settings-window.lua
local H = dofile('tests/codex/lib/runtime.lua')

-- The fake frames know only the widget methods the helpers list; the panel needs a few more.
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

local function Record(self, name, ...)
	local list = self._calls[name] or {}
	self._calls[name] = list
	table.insert(list, { ... })
end

AddMethods({
	-- Sizes are kept, so the layout can read them back.
	SetSize = function(self, w, h) Record(self, 'SetSize', w, h) self._w, self._h = w, h end,
	SetWidth = function(self, w) Record(self, 'SetWidth', w) self._w = w end,
	SetHeight = function(self, h) Record(self, 'SetHeight', h) self._h = h end,
	GetWidth = function(self) return self._w or 100 end,
	GetHeight = function(self) return self._h or 20 end,
	-- Pooled rows move between cards.
	SetParent = function(self, parent) Record(self, 'SetParent', parent) self._parent = parent end,
	SetScrollChild = function() end, GetVerticalScroll = function() return 0 end, SetVerticalScroll = function() end,
	SetOrientation = function() end, SetThumbTexture = function() end, SetValueStep = function() end,
	SetAutoFocus = function() end, SetTextInsets = function() end, SetMaxLetters = function() end,
	HasFocus = function() return false end, ClearFocus = function() end, SetHitRectInsets = function() end,
	SetResizable = function(self, on) Record(self, 'SetResizable', on) end,
	SetResizeBounds = function(self, ...) Record(self, 'SetResizeBounds', ...) end,
	StartSizing = function(self, ...) Record(self, 'StartSizing', ...) end,
	CreateLine = function(self) return H.NewFrame('Line', nil, self) end,
	SetStartPoint = function() end, SetEndPoint = function() end, SetThickness = function() end,
})

local quiet
-- A fresh client with the settings and the panel. saved: SlimARKDB before loading; screen: its pixels.
local function Boot(saved, screen)
	local ns = H.setup()
	if screen then GetPhysicalScreenSize = function() return screen[1], screen[2] end end
	C_AddOns.GetAddOnMetadata = function(_, field)
		if field == 'X-SlimARK-Flavor' then return 'retail' end
		return '3.1.1'
	end
	UISpecialFrames = {}
	H.load('Config.lua')
	H.load('Core.lua')
	H.load('Settings.lua')
	H.load('SettingsPanel.lua')
	SlimARKDB = saved
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	-- The modules behind the rows that act at once.
	quiet = { sets = 0 }
	ns.Quiet = { IsOn = function() return false end, Hides = function() return true end, SoundText = function() return '' end,
		Set = function() quiet.sets = quiet.sets + 1 end, SetHides = function() quiet.sets = quiet.sets + 1 end,
		SetSounds = function() quiet.sets = quiet.sets + 1 end }
	ns.Macros = { Label = function() return 'Create' end, Scope = function() return 'character' end, SetScope = function() end }
	ns.Profiles = { IsPerCharacter = function() return false end }
	ns.GameSettings = { Has = function() return true end, Number = function() return 1 end, ShakeOn = function() return true end }
	return ns
end

local function Find(test)
	for _, f in ipairs(H.frames) do
		if test(f) then return f end
	end
end

local function Point(f)
	return H.lastCall(f, 'SetPoint') or {}
end

-- The page list, top to bottom.
local function NavPages()
	local list = {}
	for _, f in ipairs(H.frames) do
		if f.pageID and f._shown then list[#list + 1] = f end
	end
	table.sort(list, function(a, b) return Point(a)[3] > Point(b)[3] end)
	local ids = {}
	for i, f in ipairs(list) do ids[i] = f.pageID end
	return ids
end

local function Has(list, value)
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	return false
end

-- The group names shown above the pages of the list.
local function NavLabels(S)
	local names = {}
	for _, group in ipairs(S.groups) do names[group.name:upper()] = true end
	local list = {}
	for _, f in ipairs(H.frames) do
		if f._shown and f.text and not f.group and not f.pageID and names[f.text._text] then list[#list + 1] = f.text._text end
	end
	return list
end

local function Tab(name)
	return Find(function(f) return f.group == name and f.line end)
end

local function SelectedTabs()
	local list = {}
	for _, f in ipairs(H.frames) do
		if f.group and f.line and f.line._shown then list[#list + 1] = f.group end
	end
	return list
end

local function Click(f)
	f._scripts.OnClick(f)
end

local function Search(text)
	local box = Find(function(f) return f._kind == 'EditBox' and f._scripts.OnTextChanged end)
	box:SetText(text)
	box._scripts.OnTextChanged(box)
end

-- The page title over the cards.
local function Title()
	local fs = Find(function(f)
		local font = f._kind == 'FontString' and H.lastCall(f, 'SetFont')
		return font and font[2] == 22
	end)
	return fs and fs._text
end

local function Button(label)
	local fs = Find(function(f) return f._kind == 'FontString' and f._text == label end)
	return fs and fs._parent
end

-- The shown cards in the page's section order, with their place and size.
local function Cards()
	local list = {}
	for _, f in ipairs(H.frames) do
		if f.title and f._shown then
			local p = Point(f)
			list[#list + 1] = { title = f.title._text, x = p[2], y = p[3], w = f._w, h = f._h, frame = f }
		end
	end
	return list
end

local function Columns(cards)
	local xs, n = {}, 0
	for _, card in ipairs(cards) do
		if not xs[card.x] then xs[card.x] = true n = n + 1 end
	end
	return n
end

-- Rows shown inside the cards.
local function CardRows()
	local n = 0
	for _, f in ipairs(H.frames) do
		if f._shown and f.data and f._parent and f._parent.title and f._parent._shown then n = n + 1 end
	end
	return n
end

local function Page(S, id)
	for _, group in ipairs(S.groups) do
		for _, page in ipairs(group.pages) do
			if page.id == id then return page end
		end
	end
end

------------------------------------------------------------------------
-- A: size, resize bounds, the grip and what is remembered.
------------------------------------------------------------------------
do
	local ns = Boot(nil)
	ns.OpenSettings()
	local panel = SlimARK_Settings
	H.check(panel._shown, 'window: /slimark opens the panel')
	H.check(panel._w == 1280 and panel._h == 800, 'window: 1280 x 800 by default')
	local bounds = H.lastCall(panel, 'SetResizeBounds')
	H.check(bounds and bounds[1] == 980 and bounds[2] == 640 and bounds[3] == 2560 and bounds[4] == 1600,
		'window: resizable from 980 x 640 up to the screen')
	H.check((H.lastCall(panel, 'SetResizable') or {})[1] == true, 'window: the panel is resizable')
	H.equal(Point(panel)[1], 'CENTER', 'window: centered the first time')

	local grip = Find(function(f) return f._scripts.OnMouseDown and f._scripts.OnMouseUp end)
	H.check(grip ~= nil, 'grip: there is a grip')
	local lines = 0
	for _, f in ipairs(H.frames) do
		if f._kind == 'Line' and f._parent == grip then lines = lines + 1 end
	end
	H.equal(lines, 3, 'grip: three gold lines')
	grip._scripts.OnMouseDown(grip)
	local sizing = H.lastCall(panel, 'StartSizing')
	H.check(sizing and sizing[1] == 'BOTTOMRIGHT', 'grip: dragging it sizes the panel from its bottom right corner')
	-- The client resizes the panel while the grip is held: no new layout until it is let go.
	local timers = #H.timers
	panel._w = 1000
	panel._scripts.OnSizeChanged(panel)
	panel._scripts.OnSizeChanged(panel)
	H.equal(#H.timers, timers, 'grip: no layout while it is held')
	H.equal(Columns(Cards()), 2, 'grip: the page keeps its two columns while it is held')
	panel.GetLeft = function() return 300 end
	panel.GetTop = function() return 900 end
	local stops = #H.calls(panel, 'StopMovingOrSizing')
	grip._scripts.OnMouseUp(grip)
	H.equal(#H.calls(panel, 'StopMovingOrSizing'), stops + 1, 'grip: let go, the sizing stops')
	local saved = ns.DB.settingsWindow
	H.check(saved and saved.w == 1000 and saved.h == 800 and saved.x == 300 and saved.y == 900,
		'grip: the size and place are kept for the account')
	H.equal(Columns(Cards()), 1, 'grip: let go, the page is laid out once, in one column')

	-- A size from outside the grip lays the page out once, a frame later.
	panel._w = 1300
	timers = #H.timers
	panel._scripts.OnSizeChanged(panel)
	panel._scripts.OnSizeChanged(panel)
	panel._scripts.OnSizeChanged(panel)
	H.equal(#H.timers, timers + 1, 'resize: several size changes wait for one layout')
	H.runTimers(0)
	H.equal(Columns(Cards()), 2, 'resize: the layout follows the new size')

	-- Moving the panel by its header is kept too.
	local head = Find(function(f) return f._scripts.OnDragStop end)
	panel.GetLeft = function() return 410 end
	panel.GetTop = function() return 1200 end
	head._scripts.OnDragStop(head)
	H.check(ns.DB.settingsWindow.x == 410 and ns.DB.settingsWindow.y == 1200, 'window: a moved panel keeps its place')

	-- Closed and opened again: the kept size and place come back.
	ns.OpenSettings()
	H.check(not panel._shown, 'window: /slimark again closes it')
	ns.OpenSettings()
	local p = Point(panel)
	H.check(panel._w == 1300 and panel._h == 800, 'window: opened again at the kept size')
	H.check(p[1] == 'TOPLEFT' and p[2] == UIParent and p[3] == 'BOTTOMLEFT' and p[4] == 410 and p[5] == 1200,
		'window: opened again at the kept place')
	H.noErrors()
end

do
	-- Kept from an earlier session.
	Boot({ settingsWindow = { w = 1500, h = 900, x = 200, y = 1100 } })
	_G.SlimARK_OpenSettings()
	local panel = SlimARK_Settings
	local p = Point(panel)
	H.check(panel._w == 1500 and panel._h == 900, 'saved: the kept size comes back')
	H.check(p[1] == 'TOPLEFT' and p[4] == 200 and p[5] == 1100, 'saved: the kept place comes back')
end

do
	-- A smaller screen: 1366 x 768 is 1707 x 960 panel units (one unit is 0.8 pixels there).
	Boot({ settingsWindow = { w = 2400, h = 1500, x = 1500, y = 1400 } }, { 1366, 768 })
	_G.SlimARK_OpenSettings()
	local panel = SlimARK_Settings
	local bounds = H.lastCall(panel, 'SetResizeBounds')
	H.check(panel._w == 1707 and panel._h == 960, 'saved: a kept size larger than the screen is cut to the screen')
	H.check(bounds[3] == 1707 and bounds[4] == 960, 'saved: on a smaller screen the largest size is that screen')
	local p = Point(panel)
	H.check(p[4] == 0 and p[5] == 960, 'saved: a kept place is moved back onto the screen')
end

do
	-- 1024 x 600: the default height does not fit.
	Boot(nil, { 1024, 600 })
	_G.SlimARK_OpenSettings()
	local panel = SlimARK_Settings
	H.check(panel._w == 1280 and panel._h == 750, 'small screen: the default size is cut to the screen')
	Boot({ settingsWindow = { w = 500, h = 300 } })
	_G.SlimARK_OpenSettings()
	panel = SlimARK_Settings
	H.check(panel._w == 980 and panel._h == 640, 'saved: a kept size under the smallest one opens at 980 x 640')
end

------------------------------------------------------------------------
-- B: tabs and the page list.
------------------------------------------------------------------------
do
	local ns = Boot(nil)
	local S = ns.Settings
	ns.OpenSettings()
	local counts = { General = '4', ['Unit frames'] = '7', Group = '3', Combat = '11', Interface = '11', ['Addon skins'] = '4', ['Quality of life'] = '6' }
	local ok = true
	for _, group in ipairs(S.groups) do
		local tab = Tab(group.name)
		if not tab or tab.text._text ~= group.name or (tab.count and tab.count._text) ~= counts[group.name] then ok = false end
	end
	H.check(ok and #S.groups == 8, 'tabs: one per group with its page count, About without one')
	H.check(#SelectedTabs() == 1 and SelectedTabs()[1] == 'Group', 'tabs: the tab of the open page is chosen')
	local nav = NavPages()
	H.check(#nav == 3 and nav[1] == 'party' and nav[2] == 'raid' and nav[3] == 'grid', 'tabs: the list holds the chosen group\'s pages')
	H.equal(#NavLabels(S), 0, 'tabs: no group names in the list')

	Click(Tab('Combat'))
	nav = NavPages()
	H.check(#nav == 11 and nav[1] == 'markers' and nav[3] == 'plates', 'tabs: another tab lists its own pages')
	H.equal(Title(), 'Marker bar', 'tabs: a tab opens its first page')
	H.check(#SelectedTabs() == 1 and SelectedTabs()[1] == 'Combat', 'tabs: the clicked tab is chosen')
	local plates = Find(function(f) return f.pageID == 'plates' and f._shown end)
	Click(plates)
	H.equal(Title(), 'Nameplates', 'list: a page in the list opens')
	Click(Tab('General'))
	H.equal(Title(), 'Modules', 'tabs: General opens Modules')
	Click(Tab('Combat'))
	H.equal(Title(), 'Nameplates', 'tabs: back on a tab, the page last open there opens again')
	Click(Tab('About'))
	H.equal(Title(), 'SlimARK-UI', 'tabs: About opens the version and changelog')
	H.check(#NavPages() == 1 and NavPages()[1] == 'about', 'tabs: About lists its one page')

	-- Search: every group, with the group names, and no chosen tab.
	Search('size')
	nav = NavPages()
	local groups = {}
	for _, id in ipairs(nav) do groups[Page(S, id).group] = true end
	local n = 0
	for _ in pairs(groups) do n = n + 1 end
	H.check(n >= 4 and Has(nav, 'player') and Has(nav, 'plates') and Has(nav, 'minimap'), 'search: matching pages of every group are listed')
	H.check(#NavLabels(S) == n, 'search: each group\'s name is over its pages')
	H.equal(#SelectedTabs(), 0, 'search: no tab is chosen')
	local all = true
	for _, id in ipairs(nav) do
		if id == 'about' then all = false end
	end
	H.check(all and not Has(nav, 'testmode'), 'search: pages without a match are left out')
	Search('premade')
	H.check(Has(NavPages(), 'groupfinder') and Has(NavLabels(S), 'QUALITY OF LIFE'), 'search: a setting of another group is found')
	Search('')
	H.check(#SelectedTabs() == 1 and #NavLabels(S) == 0, 'search: emptied, the tabs and the group list come back')
	Search('premade')
	Click(Tab('Combat'))
	H.check(#SelectedTabs() == 1 and SelectedTabs()[1] == 'Combat' and #NavPages() == 11, 'search: a tab ends the search')
	H.noErrors()
end

------------------------------------------------------------------------
-- B: section cards in one or two columns.
------------------------------------------------------------------------
do
	local ns = Boot(nil)
	local S = ns.Settings
	ns.OpenSettings('plates')
	local panel = SlimARK_Settings
	local cards = Cards()
	local plates = Page(S, 'plates')
	H.equal(#cards, #plates.secs, 'cards: one card per section')
	H.equal(cards[1].title, 'SIZE', 'cards: the section title in capitals')
	H.equal(Columns(cards), 2, 'cards: two columns at 1280 x 800')
	-- Each card goes under the shorter column, in the page's order.
	local tops, placed = { cards[1].y, cards[1].y }, true
	local xs = { 22, 22 + cards[1].w + 12 }
	for _, card in ipairs(cards) do
		local col = tops[2] > tops[1] and 2 or 1
		if card.x ~= xs[col] or card.y ~= tops[col] then placed = false end
		tops[col] = tops[col] - card.h - 12
	end
	H.check(placed, 'cards: each card under the shorter column, in the page\'s order')

	-- 1074 wide leaves 820 for the page: two columns. One pixel less: one column.
	panel._w = 1074
	ns.OpenSettings('plates')
	cards = Cards()
	H.check(Columns(cards) == 2 and cards[1].w == 404, 'cards: two columns from 820 px of page width')
	panel._w = 1073
	ns.OpenSettings('plates')
	cards = Cards()
	H.check(Columns(cards) == 1 and cards[1].w == 819 and cards[1].x == 22, 'cards: one full width column under 820 px')

	-- Every page, wide and narrow: each row it shows today is in a card.
	local missing = {}
	for _, width in ipairs({ 1280, 980 }) do
		panel._w = width
		for _, group in ipairs(S.groups) do
			for _, page in ipairs(group.pages) do
				ns.OpenSettings(page.id)
				local want = 0
				for _, sec in ipairs(page.secs or {}) do
					for _, row in ipairs(sec.rows) do
						if (not row.path or S.defaults[row.path] ~= nil) and not (row.hidden and row.hidden()) then want = want + 1 end
					end
				end
				if CardRows() ~= want then missing[#missing + 1] = page.id .. '@' .. width end
			end
		end
	end
	H.check(#missing == 0, 'cards: every page shows all its rows at 1280 and at 980' .. (#missing > 0 and (': ' .. missing[1]) or ''))

	-- Pages with a text box keep one column, wide or not.
	panel._w = 1280
	ns.OpenSettings('profiles')
	H.equal(Columns(Cards()), 1, 'cards: Profiles keeps one column for its text boxes')
	ns.OpenSettings('lessnoise')
	H.equal(Columns(Cards()), 1, 'cards: Less noise keeps one column for the sound list')
	ns.OpenSettings('testmode')
	H.check(Columns(Cards()) == 2 and #Cards() == 2, 'cards: Test mode\'s two choices in two columns')
	ns.OpenSettings('about')
	H.check(Title() == 'SlimARK-UI' and #Cards() == 0, 'cards: About keeps its own page')
	panel._w = 980
	ns.OpenSettings('about')
	H.equal(Title(), 'SlimARK-UI', 'cards: About at the smallest size')
	H.noErrors()
end

-- A long section (8 rows or more) is a list: its card takes the whole width and its rows go into
-- two columns, so the page is no longer than before the cards.
do
	local ns = Boot(nil)
	local panel = SlimARK_Settings
	ns.OpenSettings('blizzwindows')
	local cards = Cards()
	local list
	for _, card in ipairs(cards) do if card.title == 'WINDOWS' then list = card end end
	local look = cards[1]
	H.check(list and list.w == 1280 - 210 - 44 and list.x == 22, 'long section: its card takes the whole width')
	H.equal(list and list.h, 32 + 10 * 30 + 6, 'long section: 20 rows in two columns of 10')
	H.check(list and look.title == 'LOOK' and list.y == look.y - look.h - 12, 'long section: it starts under the cards before it')
	local xs = {}
	for _, f in ipairs(H.frames) do
		if f._shown and f.data and f._parent == list.frame then xs[Point(f)[2]] = true end
	end
	local n = 0
	for _ in pairs(xs) do n = n + 1 end
	H.equal(n, 2, 'long section: its rows sit in two columns')
	panel._w = 980
	ns.OpenSettings('blizzwindows')
	for _, card in ipairs(Cards()) do if card.title == 'WINDOWS' then list = card end end
	H.equal(list.h, 32 + 10 * 30 + 6, 'long section: two row columns at the smallest size too, as before')
	panel._w = 1280
	ns.OpenSettings('plates')
	local single = true
	for _, card in ipairs(Cards()) do if card.w ~= math.floor((1026 - 12) / 2) then single = false end end
	H.check(single, 'long section: short sections stay in the two card columns')
	H.noErrors()
end

------------------------------------------------------------------------
-- C: Quality of life in six pages.
------------------------------------------------------------------------
-- Every path and every row that acts at once of the fourteen old pages.
local OLD_PATHS = {
	'features.autoQuest', 'autoquest.accept', 'autoquest.turnIn', 'autoquest.gossip',
	'features.autoRoleCheck', 'features.oneClickSignup', 'features.joinedText', 'features.joinTeleport',
	'features.premadeInfo', 'features.premadeFilter', 'features.applications', 'features.inviteSound',
	'features.acceptInvites', 'features.acceptSummons', 'features.acceptRes',
	'features.autoKeystone', 'features.announceKey', 'features.answerKeys', 'features.keystoneSeason', 'features.partyKeys',
	'features.autoCombatLog', 'features.quickFocus', 'quickFocus.modifier', 'features.easyDelete', 'features.errorFilter',
	'features.skipCinematics', 'features.skipMovies',
	'features.shotKey', 'features.shotKill', 'features.shotAchievement', 'features.mapCoords', 'features.rareAlert',
	'features.afkScreen', 'features.bgTimers', 'bgtimers.x', 'bgtimers.y', 'bgtimers.w', 'bgtimers.h', 'bgtimers.font',
}
local OLD_LIVE = {
	'Save new macros as character or account macros', 'Focus kick', 'Mouseover dispel', 'Healthstone and potion',
	'Max camera distance', 'Spell queue window (ms)', 'Nameplate overlap', 'Screen shake', 'Open the game\'s audio alerts',
	'Quiet mode', 'Hide boss banner, zone text and toasts', 'Sound file IDs', 'Forget seen ones',
}
-- Old page: its id, its name, the new page, and whether it had a text.
local OLD_PAGES = {
	{ 'autoquest', 'Auto quest', 'automation', true }, { 'autoaccept', 'Auto accept', 'automation', true },
	{ 'keystone', 'Keystone', 'automation', true }, { 'groupfinder', 'Group Finder', 'groupfinder', false },
	{ 'premade', 'Premade groups', 'groupfinder', true }, { 'quickfocus', 'Quick focus', 'combathelpers', true },
	{ 'combatlog', 'Combat log', 'combathelpers', true }, { 'macros', 'Macros', 'combathelpers', true },
	{ 'quiet', 'Quiet mode', 'lessnoise', true }, { 'errors', 'Error messages', 'lessnoise', true },
	{ 'cinematics', 'Cinematics', 'lessnoise', false }, { 'delete', 'Deleting items', 'lessnoise', true },
}

do
	local ns = Boot(nil)
	local S = ns.Settings
	local qol
	for _, group in ipairs(S.groups) do
		if group.name == 'Quality of life' then qol = group end
	end
	local ids, names = {}, {}
	for i, page in ipairs(qol.pages) do ids[i], names[i] = page.id, page.name end
	H.equal(table.concat(ids, ' '), 'automation groupfinder combathelpers lessnoise gamesettings other', 'qol: six pages, in this order')
	H.equal(table.concat(names, ', '), 'Automation, Group Finder, Combat helpers, Less noise, Game settings, Other', 'qol: their names')

	-- Every path of the schema: how often, and on which pages.
	local count, inQol, twice = {}, {}, {}
	local live = {}
	for _, group in ipairs(S.groups) do
		for _, page in ipairs(group.pages) do
			local seen = {}
			for _, sec in ipairs(page.secs or {}) do
				for _, row in ipairs(sec.rows) do
					if row.path then
						count[row.path] = (count[row.path] or 0) + 1
						if seen[row.path] then twice[#twice + 1] = page.id .. ' ' .. row.path end
						seen[row.path] = true
						if group == qol then inQol[row.path] = true end
					elseif group == qol then
						live[row.label] = (live[row.label] or 0) + 1
					end
				end
			end
		end
	end
	local once, n = true, 0
	for _, path in ipairs(OLD_PATHS) do
		if count[path] ~= 1 or not inQol[path] or S.pageOf[path].group ~= 'Quality of life' then once = false end
	end
	for _ in pairs(inQol) do n = n + 1 end
	H.check(once and n == #OLD_PATHS, 'qol: every path of the old pages is in the schema exactly once, on a Quality of life page')
	H.check(#twice == 0, 'schema: no page lists a path twice' .. (#twice > 0 and (': ' .. twice[1]) or ''))
	local liveOnce, m = true, 0
	for _, label in ipairs(OLD_LIVE) do
		if live[label] ~= 1 then liveOnce = false end
	end
	for _ in pairs(live) do m = m + 1 end
	H.check(liveOnce and m == #OLD_LIVE, 'qol: every row that acts at once is there exactly once')

	-- The old page names are section titles, their texts are over those sections.
	local titled = true
	for _, old in ipairs(OLD_PAGES) do
		local first
		for _, sec in ipairs(Page(S, old[3]).secs) do
			if sec.name == old[2] then first = sec end
		end
		if not first or (old[4] and not first.desc) then titled = false end
	end
	H.check(titled, 'qol: each old page\'s name is a section title, with its text')
	H.check(Page(S, 'gamesettings').noReset and not Page(S, 'combathelpers').noReset and not Page(S, 'lessnoise').noReset,
		'qol: Game settings keeps no reset, the merged pages reset their saved values')

	-- Old page ids open the page they moved into; old names are found by the search.
	ns.OpenSettings()
	local opened = true
	for _, old in ipairs(OLD_PAGES) do
		ns.OpenSettings(old[1])
		if Title() ~= Page(S, old[3]).name then opened = false end
	end
	H.check(opened, 'qol: old page ids open the new page')
	local found = true
	for _, old in ipairs(OLD_PAGES) do
		Search(old[2]:lower())
		if not Has(NavPages(), old[3]) then found = false end
	end
	H.check(found, 'qol: the search finds the old page names')
	Search('')

	-- A section's text is shown in its card.
	ns.OpenSettings('automation')
	local para = Find(function(f)
		return f._kind == 'FontString' and f._shown and (f._text or ''):find('^Accepts and turns in quests') and f._parent.title
	end)
	H.check(para and para._parent.title._text == 'AUTO QUEST', 'qol: the old page text is in its card')

	-- Reset page on Less noise: the saved values go back, quiet mode is not touched.
	ns.OpenSettings('lessnoise')
	S.Set('features.errorFilter', not S.defaults['features.errorFilter'])
	S.Set('features.easyDelete', not S.defaults['features.easyDelete'])
	local reset = Button('Reset page')
	H.check(reset._shown, 'qol: Less noise has Reset page')
	Click(reset)
	H.check(S.PendingCount() == 0 and quiet.sets == 0, 'qol: Reset page resets the saved values and leaves quiet mode alone')
	ns.OpenSettings('gamesettings')
	H.check(not reset._shown, 'qol: Game settings still has no Reset page')
	H.noErrors()
end

H.done()
