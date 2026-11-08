local addonName, ns = ...
local C = ns.C

-- The /slimark settings: every adjustable value of Config.lua, by its path in ns.C.
-- Changed values are kept in SlimARKDB.settings and written over ns.C when the
-- addon loads, before any module builds its frames, so a reload applies them.
local S = {}
ns.Settings = S

local function R(label, path, min, max, step) return { t = 'range', label = label, path = path, min = min, max = max, step = step or 1 } end
local function T(label, path) return { t = 'toggle', label = label, path = path } end
local function Col(label, path) return { t = 'color', label = label, path = path } end
local function Btn(label, fn) return { t = 'button', label = label, fn = fn } end
local function Pos(path, heal)
	local rows = { R('X', path .. '.x', 0, 2560), R('Y', path .. '.y', 0, 1600) }
	if heal then
		table.insert(rows, R('Healer X', path .. '.heal.x', 0, 2560))
		table.insert(rows, R('Healer Y', path .. '.heal.y', 0, 1600))
	end
	return { name = 'Position', rows = rows }
end
local function Size(path, maxW, maxH)
	return { name = 'Size', rows = { R('Width', path .. '.w', 40, maxW or 600), R('Height', path .. '.h', 10, maxH or 160) } }
end
local function Font(path, key) return { name = 'Text', rows = { R('Font size', path .. '.' .. (key or 'font'), 8, 32) } } end

local function ForgetCutscenes()
	if not ns.DB then return end
	wipe(ns.DB.seenMovies)
	wipe(ns.DB.seenCinematics)
	ns.Print('Seen cinematics forgotten. They play again next time.')
end

-- Pages by group. module: the page's on/off switch. keys: Edit Mode keys whose dragged
-- position a changed X or Y replaces. apply: saving runs /slimark apply, because these
-- values are written into Blizzard's Edit Mode or another addon's profile.
S.groups = {
	{ name = 'General', pages = {
		{ id = 'modules', name = 'Modules', desc = 'Switch whole modules on or off. A module that is off leaves the Blizzard frame in place. Buffs and debuffs belong to the player frame, they need Unit frames on.',
			secs = { { name = 'Modules', rows = {
				T('Unit frames', 'modules.unitframes'), T('Party frames', 'modules.party'), T('Raid frames', 'modules.raid'),
				T('Healer grid', 'modules.grid'), T('Nameplates', 'modules.nameplates'), T('Buffs and debuffs', 'modules.auras'),
				T('Cooldown bars', 'modules.cooldowns'), T('Consumables', 'modules.consumables'), T('Mythic+ panel', 'modules.mythicplus'),
				T('Action bar skin', 'modules.actionbars'), T('Minimap', 'modules.minimap'), T('Quest tracker', 'modules.tracker'),
				T('Vendor', 'modules.vendor'), T('Character sheet', 'modules.character'), T('Window mover', 'modules.movers'),
				T('BetterBags skin', 'modules.betterbags'), T('Trinkets and potions', 'modules.effects'), T('Top bar', 'modules.databar'),
			} } } },
		{ id = 'colors', name = 'Colors', desc = 'Colors shared by several elements.',
			secs = { { name = 'Colors', rows = {
				Col('Bar background', 'colors.track'), Col('Target border', 'colors.target'), Col('Gold accent and holy power', 'colors.classPower'),
				Col('Mana', 'colors.mana'),
			} }, { name = 'Shields', rows = { T('Shields on health bars', 'features.shields'), Col('Shield', 'colors.shield') } },
			{ name = 'Other', rows = { T('Version at login', 'features.loginMessage') } } } },
	} },
	{ name = 'Unit frames', pages = {
		{ id = 'player', name = 'Player', keys = { 'player' }, secs = { Pos('units.player', true), Size('units.player'), Font('units.player'),
			{ name = 'Class power and cast bar', rows = { R('Class power height', 'units.player.classPower', 4, 30), Col('Cast bar', 'colors.cast') } } } },
		{ id = 'target', name = 'Target', keys = { 'target' }, secs = { Pos('units.target', true), Size('units.target'), Font('units.target'),
			{ name = 'Debuffs', rows = { R('Icon size', 'auras.targetDebuffSize', 16, 64) } } } },
		{ id = 'targettarget', name = 'Target of target', keys = { 'targettarget' }, secs = { Pos('units.targettarget', true), Size('units.targettarget'), Font('units.targettarget') } },
		{ id = 'pet', name = 'Pet', keys = { 'pet' }, secs = { Pos('units.pet', true), Size('units.pet'), Font('units.pet') } },
		{ id = 'focus', name = 'Focus', keys = { 'focus' }, secs = { Pos('units.focus', true), Size('units.focus'), Font('units.focus') } },
		{ id = 'boss', name = 'Boss', keys = { 'boss' }, secs = { Pos('units.boss'), Size('units.boss'), Font('units.boss'),
			{ name = 'Spacing', rows = { R('Gap', 'units.boss.gap', 0, 40) } } } },
	} },
	{ name = 'Group', pages = {
		{ id = 'party', name = 'Party', module = 'modules.party', keys = { 'party' }, desc = 'Party frames for DPS and tank specs, in a column next to your character.',
			secs = { Pos('units.party'), { name = 'Size', rows = { R('Width', 'units.party.w', 60, 400), R('Height', 'units.party.h', 20, 160), R('Gap', 'units.party.gap', 0, 30) } },
				{ name = 'Icons', rows = { R('Debuff size', 'units.party.debuff', 10, 48), R('Defensive size', 'units.party.defensive', 10, 48),
					T('Role icon', 'features.roleIcon'), T('Dispel highlight', 'features.dispelGlow') } }, Font('units.party') } },
		{ id = 'raid', name = 'Raid', module = 'modules.raid', keys = { 'raid' },
			secs = { Pos('units.raid'), { name = 'Size', rows = { R('Width', 'units.raid.w', 60, 300), R('Height', 'units.raid.h', 20, 120), R('Gap', 'units.raid.gap', 0, 30) } },
				{ name = 'Icons', rows = { R('Debuff size', 'units.raid.debuff', 10, 48), R('Defensive size', 'units.raid.defensive', 10, 48),
					T('Role icon', 'features.roleIcon'), T('Dispel highlight', 'features.dispelGlow') } }, Font('units.raid') } },
		{ id = 'grid', name = 'Healer grid', module = 'modules.grid', keys = { 'healparty', 'healraid' }, desc = 'Group frames of the healer layout, above the action bars. X and Y are the bottom left corner.',
			secs = { Pos('units.grid'), { name = 'Size', rows = { R('Width', 'units.grid.w', 60, 300), R('Height', 'units.grid.h', 20, 120), R('Gap', 'units.grid.gap', 0, 30) } },
				{ name = 'Icons', rows = { R('Debuff size', 'units.grid.debuff', 10, 48), R('Defensive size', 'units.grid.defensive', 10, 48),
					T('Role icon', 'features.roleIcon'), T('Dispel highlight', 'features.dispelGlow') } }, Font('units.grid') } },
	} },
	{ name = 'Combat', pages = {
		{ id = 'plates', name = 'Nameplates', module = 'modules.nameplates', desc = 'Enemy nameplates: name and health inside the plate, caster mark, cast bar and interrupts.',
			secs = { { name = 'Size', rows = { R('Width', 'plate.w', 80, 400), R('Height', 'plate.h', 8, 50), R('Caster height', 'plate.casterH', 8, 60), R('Cast bar height', 'plate.castH', 6, 40) } },
				{ name = 'Text and icons', rows = { R('Font size', 'plate.font', 8, 28), R('Targeter font', 'plate.targeterFont', 8, 28), R('Debuff size', 'plate.debuff', 10, 48) } },
				{ name = 'Target', rows = { R('Other plates alpha', 'plate.dimAlpha', 0.1, 1, 0.05), T('Arrows on target', 'features.plateArrows') } },
				{ name = 'Colors', rows = { Col('Cast bar', 'colors.enemyCast'), Col('Casting border', 'colors.casting'), Col('Important cast', 'colors.important'),
					Col('Caster mark', 'colors.caster'), Col('Not interruptible', 'colors.notInterruptible') } },
				{ name = 'Interrupts', rows = { T('Show who interrupted', 'features.interrupter'), R('Hold time (s)', 'plate.holdTime', 0, 5, 0.1) } } } },
		{ id = 'buffs', name = 'Buffs', module = 'modules.auras',
			secs = { { name = 'Position', rows = { R('Right edge', 'auras.buffs.right', 0, 2560), R('Y', 'auras.buffs.y', 0, 1600) } },
				{ name = 'Icons', rows = { R('Icon size', 'auras.buffs.size', 16, 80), R('Gap', 'auras.buffs.gap', 0, 20), R('Max shown', 'auras.buffs.max', 1, 40),
					R('Area width', 'auras.buffs.width', 100, 1400), R('Area height', 'auras.buffs.height', 30, 400) } },
				{ name = 'Text', rows = { R('Time font', 'auras.buffs.timeFont', 8, 30), R('Time height', 'auras.buffs.timeH', 8, 40), R('Stack font', 'auras.buffs.countFont', 8, 30) } } } },
		{ id = 'debuffs', name = 'Debuffs', module = 'modules.auras',
			secs = { { name = 'Position', rows = { R('Right edge', 'auras.debuffs.right', 0, 2560), R('Y', 'auras.debuffs.y', 0, 1600) } },
				{ name = 'Icons', rows = { R('Icon size', 'auras.debuffs.size', 16, 80), R('Gap', 'auras.debuffs.gap', 0, 20), R('Max shown', 'auras.debuffs.max', 1, 20),
					R('Area width', 'auras.debuffs.width', 100, 1400), R('Area height', 'auras.debuffs.height', 30, 400) } },
				{ name = 'Text', rows = { R('Time font', 'auras.debuffs.timeFont', 8, 30), R('Time height', 'auras.debuffs.timeH', 8, 40), R('Stack font', 'auras.debuffs.countFont', 8, 30) } } } },
		{ id = 'cooldowns', name = 'Cooldown bars', module = 'modules.cooldowns', keys = { 'cooldownbars', 'cooldownicons' },
			secs = { { name = 'Position', rows = { R('X', 'cooldowns.x', 0, 2560), R('Y', 'cooldowns.y', 0, 1600), R('Healer X', 'cooldowns.heal.x', 0, 2560), R('Healer Y', 'cooldowns.heal.y', 0, 1600) } },
				{ name = 'Bars', rows = { R('Width', 'cooldowns.w', 100, 700), R('Healer width', 'cooldowns.heal.w', 100, 700), R('Row height', 'cooldowns.rowH', 10, 40),
					R('Gap', 'cooldowns.gap', 0, 20), R('Font size', 'cooldowns.font', 8, 30) } },
				{ name = 'Rotation icons', rows = { R('Y', 'cooldowns.iconY', 0, 1600), R('Healer Y', 'cooldowns.heal.iconY', 0, 1600), R('Icon size', 'cooldowns.iconSize', 20, 80), R('Gap', 'cooldowns.iconGap', 0, 20) } },
				{ name = 'Active effect', rows = { T('Count down the effect first', 'features.activeAuras') } },
				{ name = 'Colors', rows = { Col('Main', 'colors.cdMain'), Col('Interrupt', 'colors.cdKick'), Col('Defensive', 'colors.cdDefensive'),
					Col('Immunity', 'colors.cdImmune'), Col('Utility', 'colors.cdUtility'), Col('Bar fill', 'cooldowns.fillColor') } } } },
		{ id = 'effects', name = 'Trinkets and potions', module = 'modules.effects', keys = { 'effects' },
			desc = 'Icons with a gold countdown while a trinket or potion effect is up: above the cooldown bars, above the player frame for healers.',
			secs = { Pos('effects', true), { name = 'Icons', rows = { R('Icon size', 'effects.size', 20, 80), R('Gap', 'effects.gap', 0, 20), R('Font size', 'effects.font', 8, 30) } },
				{ name = 'Show', rows = { T('Trinkets', 'effects.trinkets'), T('Potions', 'effects.potions') } } } },
		{ id = 'consumables', name = 'Consumables', module = 'modules.consumables', keys = { 'consumables' },
			secs = { Pos('consumables'), { name = 'Icons', rows = { R('Icon size', 'consumables.size', 20, 80), R('Gap', 'consumables.gap', 0, 20) } } } },
		{ id = 'mythicplus', name = 'Mythic+ panel', module = 'modules.mythicplus', desc = 'Compact panel in place of the quest tracker while a key runs. It sits left of the quest tracker position (Interface: Quest tracker); drag it in Edit Mode to move it.',
			secs = {} },
	} },
	{ name = 'Interface', pages = {
		{ id = 'databar', name = 'Top bar', module = 'modules.databar', desc = 'A flat bar on the top row of the screen. With it on, the minimap, the buffs, the quest tracker and the other top elements move down by its height. Click the keystone for the dungeon teleports you have learned.',
			secs = { { name = 'Bar', rows = { R('Height', 'databar.h', 18, 40), R('Font size', 'databar.font', 10, 24), R('Icon size', 'databar.iconSize', 14, 36) } },
				{ name = 'Left side', rows = { T('Micro menu', 'databar.show.micro'), T('Durability', 'databar.show.durability'), T('FPS', 'databar.show.fps'),
					T('Latency', 'databar.show.latency'), T('Queue time', 'databar.show.queue'), T('Tracked currencies', 'databar.show.currency') } },
				{ name = 'Middle and right side', rows = { T('Clock', 'databar.show.clock'), T('Gold', 'databar.show.gold'), T('Item level', 'databar.show.itemLevel'),
					T('Keystone and teleports', 'databar.show.keystone'), T('Great Vault', 'databar.show.vault'), T('Auto quest switch', 'databar.show.autoQuest'),
					T('Addon icons', 'databar.show.addons') } } } },
		{ id = 'actionbars', name = 'Action bars', module = 'modules.actionbars', apply = true, desc = 'Button size and padding are written into the SlimARK-UI Edit Mode layouts.',
			secs = { { name = 'Buttons', rows = { R('Button size', 'layout.bars.size', 28, 72), R('Padding', 'layout.bars.padding', 0, 10) } },
				{ name = 'Text', rows = { R('Font size', 'actionbars.font', 8, 28), R('Hotkey font', 'actionbars.hotkeyFont', 8, 28) } } } },
		{ id = 'minimap', name = 'Minimap', module = 'modules.minimap', keys = { 'minimap' },
			secs = { Pos('minimap'), { name = 'Map', rows = { R('Size', 'minimap.size', 140, 400) } },
				{ name = 'Coordinates', rows = { T('Coordinates on the map', 'minimap.coords'), R('Font size', 'minimap.coordsFont', 10, 32) } },
				{ name = 'Addon buttons', rows = { R('Button size', 'minimap.buttonSize', 16, 48), R('Gap', 'minimap.buttonGap', 0, 12) } } } },
		{ id = 'tracker', name = 'Quest tracker', module = 'modules.tracker', apply = true, desc = 'Position and size are written into the SlimARK-UI Edit Mode layouts. X is the right edge.',
			secs = { Pos('tracker'), { name = 'Tracker', rows = { R('Height', 'tracker.height', 400, 1200, 10), R('Text size', 'tracker.textSize', 12, 20) } } } },
		{ id = 'vendor', name = 'Vendor', module = 'modules.vendor', secs = { { name = 'Vendor', rows = { T('Automatic repair', 'features.autoRepair') } } } },
		{ id = 'character', name = 'Character sheet', module = 'modules.character', desc = 'Item level, gems, enchants and what is missing on each item.', secs = {} },
		{ id = 'windows', name = 'Windows', module = 'modules.movers', desc = 'Move Blizzard windows by their title bar, resize them with Ctrl + mouse wheel.',
			secs = { { name = 'Frame rate', rows = { R('FPS counter Y', 'fps.y', 0, 200) } } } },
	} },
	{ name = 'Addon skins', pages = {
		{ id = 'details', name = 'Details!', apply = true, secs = { { name = 'Position', rows = { R('Right edge', 'details.right', 0, 2560), R('Bottom edge', 'details.bottom', 0, 1600) } },
			{ name = 'Windows', rows = { R('Width', 'details.w', 150, 600), R('Height', 'details.h', 100, 600), R('Gap', 'details.gap', 0, 30), R('Bar height', 'details.barHeight', 14, 40), R('Font size', 'details.fontSize', 8, 28) } } } },
		{ id = 'bossmods', name = 'Boss mods', apply = true, desc = 'Deadly Boss Mods and BigWigs bars.',
			secs = { { name = 'Normal bars', rows = { R('X', 'bossmods.normal.x', 0, 2560), R('Y', 'bossmods.normal.y', 0, 1600), R('Width', 'bossmods.normal.w', 100, 600), R('Height', 'bossmods.normal.h', 12, 40) } },
				{ name = 'Large bars', rows = { R('X', 'bossmods.huge.x', 0, 2560), R('Y', 'bossmods.huge.y', 0, 1600), R('Width', 'bossmods.huge.w', 100, 600), R('Height', 'bossmods.huge.h', 12, 40) } },
				{ name = 'Text', rows = { R('Gap', 'bossmods.gap', 0, 20), R('Font size', 'bossmods.fontSize', 8, 28) } } } },
		{ id = 'betterbags', name = 'BetterBags', module = 'modules.betterbags', apply = true, desc = 'Flat dark SlimARK theme for the classic bags and BetterBags Next. Saving selects it in BetterBags.', secs = {} },
		{ id = 'chat', name = 'Chat', apply = true, desc = 'Chattynator window.',
			secs = { { name = 'Window', rows = { R('X', 'chat.x', 0, 2560), R('Bottom edge', 'chat.bottom', 0, 1600), R('Width', 'chat.w', 200, 1200), R('Height', 'chat.h', 100, 800), R('Font size', 'chat.fontSize', 8, 28) } } } },
	} },
	{ name = 'Quality of life', pages = {
		{ id = 'autoquest', name = 'Auto quest', desc = 'Accepts and turns in quests, finished ones first. It stops when you have to choose a reward or pay gold, and leaves vendors, flight masters, innkeepers, trainers, banks and the transmogrifier alone. Hold Shift at an NPC to pause it. The top bar has an on/off switch.',
			secs = { { name = 'Auto quest', rows = { T('Auto quest', 'features.autoQuest'), T('Accept quests', 'autoquest.accept'),
				T('Turn in quests', 'autoquest.turnIn'), T('Pick the only talk option', 'autoquest.gossip') } } } },
		{ id = 'groupfinder', name = 'Group Finder', secs = { { name = 'Group Finder', rows = { T('Accept role checks with spec role', 'features.autoRoleCheck'), T('Sign up with one click', 'features.oneClickSignup') } } } },
		{ id = 'cinematics', name = 'Cinematics', secs = { { name = 'Cinematics', rows = { T('Skip seen cinematics', 'features.skipCinematics'), T('Skip seen movies', 'features.skipMovies') } },
			{ name = 'Memory', rows = { Btn('Forget seen ones', ForgetCutscenes) } } } },
	} },
	{ name = 'About', pages = { { id = 'about', name = 'Version and changelog', about = true } } },
}

-- Shown on the About page, newest first.
S.changelog = {
	{ version = '1.4.1', lines = {
		'Fixed: the micro menu icons of the top bar showed only a colored patch instead of the symbol',
	} },
	{ version = '1.4.0', lines = {
		'Top bar on the top row: micro menu, durability, FPS, latency, queue time, tracked currencies, clock, gold, item level, keystone, Great Vault, auto quest switch and the addon icons',
		'Click the keystone: the dungeons of the season you have a teleport to, one click teleports',
		'Auto quest: accepts and turns in quests, stops at a reward choice, Shift pauses it',
		'The minimap clock moved to the top bar, the coordinates took its place, larger',
	} },
	{ version = '1.3.4', lines = {
		'Fixed: on the two-page vendor the Next button covered the page number',
	} },
	{ version = '1.3.3', lines = {
		'Fixed: the gaps between the runes and other class power pips no longer vanish, six runes show as six',
	} },
	{ version = '1.3.2', lines = {
		'Class power in the colors of its resource, like in ElvUI: Frost runes cyan, Unholy green, combo points from red to green, holy power stays gold',
	} },
	{ version = '1.3.1', lines = {
		'The layout fits itself to your screen: 1080p, 1440p, ultrawide and 4K',
	} },
	{ version = '1.3.0', lines = {
		'WoW Forever support: the same zip loads there too, retail is unchanged',
	} },
	{ version = '1.2.9', lines = {
		'Fixed: the quest tracker over the Mythic+ panel in combat',
		'Nameplates keep the name of who interrupted, also in dungeons where the game allows it',
	} },
	{ version = '1.2.8', lines = {
		'Wider party frames with larger icons',
	} },
	{ version = '1.2.7', lines = {
		'The party frames show only the other four members, the healer grid still shows you',
	} },
	{ version = '1.2.6', lines = {
		'Fixed: C stack overflow errors with a trinket that has no use or equip effect',
	} },
	{ version = '1.2.5', lines = {
		'Fixed: a used trinket did not show above the cooldown bars',
		'Class buffs like the wings are never taken for a trinket or potion effect',
	} },
	{ version = '1.2.4', lines = {
		'Active trinket and potion effects: icons with a gold countdown above the cooldown bars, above the player frame for healers',
		'Both trinkets have their own place, the one you use and the one that procs by itself',
	} },
	{ version = '1.2.3', lines = {
		'Fixed: unit frames and nameplates lost their colors in 1.2.2 (white health and power bars)',
	} },
	{ version = '1.2.2', lines = {
		'Shields (damage absorbs) show on every unit frame and nameplate in light stripes, enemy shields too; damage takes the striped part first',
		'Cooldown bars count down the effect first while it is up, like the wings, then the cooldown',
	} },
	{ version = '1.2.1', lines = {
		'The settings panel opens with /slimark (was /slim); /slimark apply still sets up the layout',
	} },
	{ version = '1.2.0', lines = {
		'Settings panel: type /slimark, or click the SlimARK button at the minimap, to change every element',
		'/slimark apply sets up the layout; a new version asks for it once in a window',
		'Details! names no longer run into the numbers',
		'BetterBags skin for the classic bags and BetterBags Next',
	} },
	{ version = '1.1.0', lines = {
		'Nameplates: name and health with one decimal inside the plate, casters marked before they cast, magenta important casts, who interrupted',
		'Party frames as large rectangles next to your character, role icons on party, raid and grid',
		'Buffs and debuffs: time left under each icon, gaps between icons, larger stack counts',
		'Compact Mythic+ panel with enemy forces to two decimals',
		'Automatic role checks, one-click premade sign-up, seen cinematics skipped',
	} },
	{ version = '1.0.0', lines = { 'First release' } },
}

-- Path helpers. A path names a value in ns.C, like 'units.party.w'.
local function Split(path)
	local parts = {}
	for part in path:gmatch('[^.]+') do table.insert(parts, part) end
	return parts
end

function S.Get(path)
	local node = C
	for _, part in ipairs(Split(path)) do
		if type(node) ~= 'table' then return nil end
		node = node[part]
	end
	return node
end

-- Colors are written into their table, because other tables share it (the cooldown bars).
local function Write(path, value)
	local parts = Split(path)
	local node = C
	for i = 1, #parts - 1 do
		node = node[parts[i]]
		if type(node) ~= 'table' then return end
	end
	local key = parts[#parts]
	if type(node[key]) == 'table' and type(value) == 'table' then
		for i = 1, 3 do node[key][i] = value[i] end
	else
		node[key] = value
	end
end

local function Copy(value)
	if type(value) == 'table' then return { value[1], value[2], value[3] } end
	return value
end

function S.Equal(a, b)
	if type(a) == 'table' and type(b) == 'table' then
		for i = 1, 3 do
			if math.abs((a[i] or 0) - (b[i] or 0)) > 0.002 then return false end
		end
		return true
	end
	if type(a) == 'number' and type(b) == 'number' then return math.abs(a - b) < 0.0001 end
	return a == b
end

-- Every row with a path, and the default from Config.lua before anything is changed.
S.rows, S.defaults, S.pageOf = {}, {}, {}
for _, group in ipairs(S.groups) do
	for _, page in ipairs(group.pages) do
		page.group = group.name
		local function add(row)
			if row.path and S.defaults[row.path] == nil then
				S.defaults[row.path] = Copy(S.Get(row.path))
				S.pageOf[row.path] = S.pageOf[row.path] or page
				table.insert(S.rows, row)
			end
		end
		if page.module then add(T('Enabled', page.module)) end
		for _, sec in ipairs(page.secs or {}) do
			for _, row in ipairs(sec.rows) do add(row) end
		end
	end
end

-- The saved changes go over Config.lua while loading, before the modules build.
ns.On('ADDON_LOADED', function(_, name)
	if name ~= addonName then return end
	SlimARKDB.settings = SlimARKDB.settings or {}
	for path, value in pairs(SlimARKDB.settings) do
		local default = S.defaults[path]
		if default ~= nil and type(default) == type(value) then
			Write(path, value)
		else
			-- A setting a later version no longer has.
			SlimARKDB.settings[path] = nil
		end
	end
end)

-- Changes made in the panel wait here until they are saved.
S.pending = {}

function S.Value(path)
	local value = S.pending[path]
	if value == nil then value = S.Get(path) end
	return value
end

function S.Set(path, value)
	if S.Equal(value, S.Get(path)) then
		S.pending[path] = nil
	else
		S.pending[path] = Copy(value)
	end
end

function S.IsChanged(path)
	return not S.Equal(S.Value(path), S.defaults[path])
end

function S.PendingCount()
	local n = 0
	for _ in pairs(S.pending) do n = n + 1 end
	return n
end

function S.ResetPaths(paths)
	for _, path in ipairs(paths) do S.Set(path, S.defaults[path]) end
end

function S.ResetAll()
	for path in pairs(S.defaults) do S.Set(path, S.defaults[path]) end
end

function S.Undo()
	wipe(S.pending)
end

-- Saves the changes, then reloads; values another addon or Edit Mode keeps run /slimark apply.
function S.Save()
	if S.PendingCount() == 0 then return end
	-- The reload starts from the click, so it waits for the end of combat with the click.
	if InCombatLockdown() then
		ns.Print('Not possible in combat, save again afterwards. Your changes are kept.')
		return false
	end
	local apply = false
	local store = SlimARKDB.settings
	for path, value in pairs(S.pending) do
		if S.Equal(value, S.defaults[path]) then
			store[path] = nil
		else
			store[path] = Copy(value)
		end
		local page = S.pageOf[path]
		if page and page.apply then apply = true end
		-- A new X or Y replaces the spot the frame was dragged to in Edit Mode.
		local last = path:match('[^.]+$')
		if page and page.keys and (last == 'x' or last == 'y' or last == 'right' or path:find('%.heal%.')) and ns.CharDB then
			for _, key in ipairs(page.keys) do
				if ns.CharDB.pos then ns.CharDB.pos[key] = nil end
				if ns.CharDB.posHeal then ns.CharDB.posHeal[key] = nil end
			end
		end
	end
	wipe(S.pending)
	if apply and ns.ApplyAll then
		ns.ApplyAll()
	else
		ReloadUI()
	end
end
