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
-- A saved choice between a few options, shown as a row of buttons.
local function Choice(label, path, options) return { t = 'choice', label = label, path = path, options = options } end
-- A switch of one Blizzard window: grey while the look is not SlimARK.
local function NotSlim() return ns.Settings.Value('blizz.look') ~= 'slimark' end
local function W(label, key) local row = T(label, 'blizz.' .. key) row.dim = NotSlim return row end
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
				T('Tooltip', 'modules.tooltip'), T('Loot and pop-ups', 'modules.loot'), T('Marker bar', 'modules.markers'), T('Ready check', 'modules.readycheck'),
				T('Combat text font', 'modules.combatfont'),
			} } } },
		{ id = 'testmode', name = 'Test mode', noReset = true,
			desc = 'Fills the frames with made-up players so you can see the layout without a group. Combat or a reload ends it. Edit Mode works while it is on, so you can drag the filled frames. Layout opens on your current spec; the other one moves only the SlimARK frames, Blizzard\'s own elements stay where your spec has them.',
			secs = { { name = 'Show', rows = { { t = 'choice', label = 'Show test mode party raid mythic',
					options = { { 'off', 'Off' }, { 'party', 'Party' }, { 'raid20', 'Raid 20' }, { 'raid40', 'Raid 40' }, { 'mplus', 'Mythic+' } },
					get = function() return ns.TestMode and ns.TestMode.mode end, set = function(v) ns.SetTestMode(v) end } } },
				{ name = 'Layout', rows = { { t = 'choice', label = 'Layout healer dps tank',
					options = { { 'dps', 'DPS and tank' }, { 'heal', 'Healer' } },
					get = function() return ns.TestLayout and ns.TestLayout() end, set = function(v) ns.SetTestLayout(v) end } } } } },
		{ id = 'colors', name = 'Colors', desc = 'Colors shared by several elements.',
			secs = { { name = 'Colors', rows = {
				Col('Bar background', 'colors.track'), Col('Target border', 'colors.target'), Col('Gold accent and holy power', 'colors.classPower'),
				Col('Mana', 'colors.mana'),
				-- 3.0 part B (4)
				Col('Interrupt ready', 'colors.kickReady'),
			} }, { name = 'Shields', rows = { T('Shields on health bars', 'features.shields'), Col('Shield', 'colors.shield') } },
			{ name = 'Other', rows = { T('Version at login', 'features.loginMessage') } } } },
	} },
	{ name = 'Unit frames', pages = {
		{ id = 'player', name = 'Player', keys = { 'player' }, secs = { Pos('units.player', true), Size('units.player'), Font('units.player'),
			{ name = 'Class power and cast bar', rows = { R('Class power height', 'units.player.classPower', 4, 30), Col('Cast bar', 'colors.cast') } },
			{ name = 'Fade', rows = { T('Fade out of combat without a target', 'features.playerFade'), R('Faded opacity (%)', 'units.player.fadeAlpha', 0, 100) } },
			-- 3.0 part B (1, 16, 17)
			{ name = 'Combat', rows = { T('Red YOU while an enemy cast is aimed at you', 'features.castYou'),
				T('Global cooldown line under the cast bar', 'features.gcdLine'), T('Spender marks on the power bar', 'features.spenderTicks') } } } },
		{ id = 'totems', name = 'Totems', module = 'features.totems', keys = { 'totems' }, desc = 'Shaman only: your totems as icons with the time left, above the player frame. Drag the row in Edit Mode.',
			secs = { Pos('totems', true), { name = 'Icons', rows = { R('Icon size', 'totems.size', 16, 64), R('Gap', 'totems.gap', 0, 20) } } } },
		{ id = 'target', name = 'Target', keys = { 'target' }, secs = { Pos('units.target', true), Size('units.target'), Font('units.target'),
			{ name = 'Debuffs', rows = { R('Icon size', 'auras.targetDebuffSize', 16, 64) } },
			-- 3.0 part B (13)
			{ name = 'Buffs', rows = { T('Buffs you can purge or soothe: magic blue, enrage orange', 'features.targetPurge') } } } },
		{ id = 'targettarget', name = 'Target of target', keys = { 'targettarget' }, secs = { Pos('units.targettarget', true), Size('units.targettarget'), Font('units.targettarget') } },
		{ id = 'pet', name = 'Pet', keys = { 'pet' }, secs = { Pos('units.pet', true), Size('units.pet'), Font('units.pet') } },
		{ id = 'focus', name = 'Focus', keys = { 'focus' }, secs = { Pos('units.focus', true), Size('units.focus'), Font('units.focus'),
			-- 3.0 part B (12)
			{ name = 'Sound', rows = { T('Short, quiet sound when the focus starts a cast', 'features.focusSound') } } } },
		{ id = 'boss', name = 'Boss', keys = { 'boss' }, secs = { Pos('units.boss'), Size('units.boss'), Font('units.boss'),
			{ name = 'Spacing', rows = { R('Gap', 'units.boss.gap', 0, 40) } },
			-- 3.0 part B (58)
			{ name = 'Arena', rows = { T('Arena enemy frames in the place of the boss frames', 'features.arenaFrames') } } } },
	} },
	{ name = 'Group', pages = {
		{ id = 'party', name = 'Party', module = 'modules.party', keys = { 'party' }, desc = 'Party frames for DPS and tank specs, in a column next to your character.',
			secs = { Pos('units.party'), { name = 'Size', rows = { R('Width', 'units.party.w', 60, 400), R('Height', 'units.party.h', 20, 160), R('Gap', 'units.party.gap', 0, 30) } },
				{ name = 'Icons', rows = { R('Debuff size', 'units.party.debuff', 10, 48), R('Defensive size', 'units.party.defensive', 10, 48),
					T('Role icon', 'features.roleIcon'), T('Dispel highlight', 'features.dispelGlow'),
					T('Private auras (boss debuffs)', 'features.privateAuras'), T('Incoming heals and heal absorbs', 'features.healPrediction'),
					T('Your HoTs', 'features.ownHots'), T('Leader, marker, res, summon, ready check, phase', 'features.statusIcons'),
					T('Red frame on aggro', 'features.aggro') } }, Font('units.party'),
				-- 3.0 part B (4)
				{ name = 'Interrupts', rows = { T('Interrupt strip: green ready, white filling, seconds left', 'features.kickStrip') } } } },
		{ id = 'raid', name = 'Raid', module = 'modules.raid', keys = { 'raid' },
			secs = { Pos('units.raid'), { name = 'Size', rows = { R('Width', 'units.raid.w', 60, 300), R('Height', 'units.raid.h', 20, 120), R('Gap', 'units.raid.gap', 0, 30) } },
				{ name = 'Icons', rows = { R('Debuff size', 'units.raid.debuff', 10, 48), R('Defensive size', 'units.raid.defensive', 10, 48),
					T('Role icon', 'features.roleIcon'), T('Dispel highlight', 'features.dispelGlow'),
					T('Private auras (boss debuffs)', 'features.privateAuras'), T('Incoming heals and heal absorbs', 'features.healPrediction'),
					T('Your HoTs', 'features.ownHots'), T('Leader, marker, res, summon, ready check, phase', 'features.statusIcons'),
					T('Red frame on aggro', 'features.aggro') } }, Font('units.raid'),
				-- 3.0 part B (4, 24)
				{ name = 'Interrupts', rows = { T('Interrupt strip: green ready, white filling, seconds left', 'features.kickStrip') } },
				{ name = 'Order', rows = { T('You first, then tanks, healers, damage (set out of combat)', 'features.raidSort') } } } },
		{ id = 'grid', name = 'Healer grid', module = 'modules.grid', keys = { 'healparty', 'healraid' }, desc = 'Group frames of the healer layout, above the action bars. X and Y are the bottom left corner.',
			secs = { Pos('units.grid'), { name = 'Size', rows = { R('Width', 'units.grid.w', 60, 300), R('Height', 'units.grid.h', 20, 120), R('Gap', 'units.grid.gap', 0, 30) } },
				{ name = 'Icons', rows = { R('Debuff size', 'units.grid.debuff', 10, 48), R('Defensive size', 'units.grid.defensive', 10, 48),
					T('Role icon', 'features.roleIcon'), T('Dispel highlight', 'features.dispelGlow'),
					T('Private auras (boss debuffs)', 'features.privateAuras'), T('Incoming heals and heal absorbs', 'features.healPrediction'),
					T('Your HoTs', 'features.ownHots'), T('Leader, marker, res, summon, ready check, phase', 'features.statusIcons'),
					T('Red frame on aggro', 'features.aggro') } }, Font('units.grid'),
				-- 3.0 part B (4)
				{ name = 'Interrupts', rows = { T('Interrupt strip: green ready, white filling, seconds left', 'features.kickStrip') } } } },
	} },
	{ name = 'Combat', pages = {
		{ id = 'markers', name = 'Marker bar', module = 'modules.markers', apply = true, keys = { 'markers' },
			desc = 'Target markers, ground markers, ready check and pull countdown, only in a group. Ready check and pull show for the leader and assistants. Under the minimap the quest tracker moves down by the bar\'s height.',
			secs = { { name = 'Place', rows = { Choice('Place', 'markers.place', { { 'map', 'Under the minimap' }, { 'party', 'Next to the party frames' } }) } },
				{ name = 'Buttons', rows = { R('Button size', 'markers.size', 20, 44), R('Gap', 'markers.gap', 0, 10) } } } },
		{ id = 'readycheck', name = 'Ready check', module = 'modules.readycheck', keys = { 'readycheck' },
			desc = 'A flat ready check window that shows what is on you and what is missing: flask, food, augment rune, weapon oil, the group\'s class buffs and durability. In combat Blizzard\'s window stays.',
			secs = { Pos('readycheck'), { name = 'Missing items', rows = { T('A button that uses the missing item', 'readycheck.useButtons') } } } },
		{ id = 'plates', name = 'Nameplates', module = 'modules.nameplates', desc = 'Enemy nameplates: name and health inside the plate, caster mark, cast bar, interrupts, cast target, aggro and the execute line. The dark cast bars and the cast target also show on the target, focus and boss cast bars.',
			secs = { { name = 'Size', rows = { R('Width', 'plate.w', 80, 400), R('Height', 'plate.h', 8, 50), R('Caster height', 'plate.casterH', 8, 60), R('Cast bar height', 'plate.castH', 6, 40) } },
				{ name = 'Text and icons', rows = { R('Font size', 'plate.font', 8, 28), R('Targeter font', 'plate.targeterFont', 8, 28), R('Debuff size', 'plate.debuff', 10, 48) } },
				{ name = 'Target', rows = { R('Other plates alpha', 'plate.dimAlpha', 0.1, 1, 0.05), T('Arrows on target', 'features.plateArrows') } },
				{ name = 'Colors', rows = { Col('Cast bar', 'colors.enemyCast'), Col('Casting border', 'colors.casting'), Col('Important cast', 'colors.important'),
					Col('Caster mark', 'colors.caster'), Col('Not interruptible', 'colors.notInterruptible'), Col('Aggro warning', 'colors.plateThreat') } },
				{ name = 'Interrupts', rows = { T('Show who interrupted', 'features.interrupter'), R('Hold time (s)', 'plate.holdTime', 0, 5, 0.1),
					T('Dark cast bars while your interrupt is on cooldown', 'features.kickReady') } },
				{ name = 'Cast target', rows = { T('Show who the cast is aimed at', 'features.castTarget') } },
				{ name = 'Aggro', rows = { T('Warning color in a group: not on you as a tank, on you otherwise', 'features.plateThreat') } },
				{ name = 'Execute line', rows = { T('Line where your finisher starts to work', 'features.executeLine'),
					R('At health % (0: your class or spec value)', 'plate.execute', 0, 50) } },
				-- 3.0 part B (2, 11, 13, 14)
				{ name = 'Marks', rows = { T('Quest, rare and elite mark before the name', 'features.plateMarks'),
					T('Turquoise mark on the focus plate', 'features.focusMark'), Col('Focus mark', 'colors.focusMark') } },
				{ name = 'Buffs', rows = { T('Buffs you can purge or soothe at the top right', 'features.platePurge'),
					Col('Magic', 'colors.purgeMagic'), Col('Enrage', 'colors.purgeEnrage') } },
				{ name = 'Mythic+', rows = { T('Enemy forces % under the plate during a key', 'features.plateForces') } } } },
		-- 3.0 part B (1, 22)
		{ id = 'castlist', name = 'Enemy casts', module = 'features.castList', keys = { 'castlist' },
			desc = 'Every enemy cast in one column above the focus frame: the spell, who it is aimed at (a red YOU for you) and the time left, at most five. The colors are the nameplate cast bars\' ones, dark while your interrupt is on cooldown. Drag it in Edit Mode.',
			secs = { Pos('castlist', true) } },
		{ id = 'buffreminder', name = 'Buff reminder', module = 'features.buffReminder', keys = { 'buffreminder' },
			desc = 'Out of combat in a dungeon, raid or other instance: icons for what you are missing, the buff your class gives, weapon oil or imbue, a shaman\'s shield, your pet. Nothing shows when all is there. Drag it in Edit Mode.',
			secs = { Pos('buffreminder', true), { name = 'Icons', rows = { R('Icon size', 'buffreminder.size', 20, 80), R('Gap', 'buffreminder.gap', 0, 20), R('Font size', 'buffreminder.font', 8, 30) } } } },
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
			secs = {
				-- 3.0: time in combat (15), battle res and Bloodlust (5), current pull (2), splits (7).
				{ name = 'Panel rows', rows = { T('Time in combat under the timer', 'features.mplusCombat'),
					T('Battle res charges and Bloodlust', 'features.mplusBrLust'), T('Current pull on the forces bar', 'features.mplusPull'),
					T('Personal best split per boss', 'features.mplusSplits') } },
				-- 3.0 (5): the same row in raid boss fights.
				{ name = 'Raid', rows = { T('Battle res and Bloodlust above the boss frames in raid fights', 'features.raidBrLust') } },
				-- 3.0: the run summary (6) with its loot (9).
				{ name = 'Run summary', rows = { T('Run summary window at the end of a key', 'features.runSummary'),
					T('Loot in the run summary', 'features.runLoot'),
					Btn('Show the last runs', function() if ns.ShowRunHistory then ns.ShowRunHistory() end end) } },
			} },
	} },
	{ name = 'Interface', pages = {
		{ id = 'databar', name = 'Top bar', module = 'modules.databar', desc = 'A flat bar on the top row of the screen. With it on, the minimap, the buffs, the quest tracker and the other top elements move down by its height. Click the keystone for the dungeon teleports you have learned. Hover Alts for all your characters, then a name for its crests. Spec, loadout, loot spec and gear set change out of combat only.',
			secs = { { name = 'Bar', rows = { R('Height', 'databar.h', 18, 40), R('Font size', 'databar.font', 10, 24), R('Icon size', 'databar.iconSize', 14, 36) } },
				{ name = 'Left side', rows = { T('Micro menu', 'databar.show.micro'), T('Durability', 'databar.show.durability'), T('FPS', 'databar.show.fps'),
					T('Latency', 'databar.show.latency'), T('Queue time', 'databar.show.queue'), T('Tracked currencies', 'databar.show.currency'),
					-- 3.0 (36, 29)
					T('Friends and guild online', 'databar.show.friends'), T('Spec and loadout', 'databar.show.spec') } },
				{ name = 'Middle and right side', rows = { T('Clock', 'databar.show.clock'), T('Gold', 'databar.show.gold'), T('Item level', 'databar.show.itemLevel'),
					T('Keystone and teleports', 'databar.show.keystone'), T('Great Vault', 'databar.show.vault'), T('Auto quest switch', 'databar.show.autoQuest'),
					T('Addon icons', 'databar.show.addons'),
					-- 3.0 (31, 52)
					T('Alts', 'databar.show.alts'), T('Quiet mode switch', 'databar.show.quiet') } },
				-- 3.0 (35, 36, 32, 30)
				{ name = 'Extras', rows = { T('XP and reputation line on the bottom edge', 'databar.show.xp'), T('Addon CPU in the FPS tooltip', 'databar.addonCPU'),
					T('This week in the Great Vault tooltip', 'databar.vaultWeek'), T('Loadout reminder on entering a dungeon', 'loadout.reminder') } } } },
		{ id = 'actionbars', name = 'Action bars', module = 'modules.actionbars', apply = true, desc = 'Button size and padding are written into the SlimARK-UI Edit Mode layouts.',
			secs = { { name = 'Buttons', rows = { R('Button size', 'layout.bars.size', 28, 72), R('Padding', 'layout.bars.padding', 0, 10) } },
				{ name = 'Look', rows = { T('Flat button states and gold proc edge', 'actionbars.flat'), T('Red, blue or grey icon when it cannot be used', 'actionbars.tint'),
					T('Turquoise edge for the assisted highlight', 'actionbars.assist') } },
				{ name = 'Text', rows = { R('Font size', 'actionbars.font', 8, 28), R('Hotkey font', 'actionbars.hotkeyFont', 8, 28), R('Cooldown font', 'actionbars.cooldownFont', 10, 36),
					T('Short hotkeys (sT)', 'actionbars.shortKeys'), T('Macro names', 'actionbars.macroNames') } },
				{ name = 'Fade', rows = { T('Fade the upper bars out of combat', 'actionbars.fade'), R('Faded opacity (%)', 'actionbars.fadeAlpha', 0, 100) } } } },
		{ id = 'tooltip', name = 'Tooltip', module = 'modules.tooltip',
			desc = 'Flat tooltip with the class, reaction or item quality color as a stripe on top and a thin health bar. Players show their Mythic+ rating (with Raider.IO installed, Raider.IO\'s lines show it), item level and target; the item level is asked for out of combat only.',
			secs = { { name = 'Place', rows = { Choice('Place', 'tooltip.anchor', { { 'fixed', 'Fixed, above the Details windows' }, { 'cursor', 'Next to the mouse' } }) } },
				-- 3.0 (33, 42): these work with the flat tooltip on or off.
				{ name = 'Tooltip extras', rows = { T('Upgrade track and crests to max', 'tooltipExtras.upgrade'), T('Spell and item ID', 'tooltipExtras.ids'),
					T('Count in bags', 'tooltipExtras.bagCount'), T('Already known', 'tooltipExtras.known'), T('Mount of a player', 'tooltipExtras.mount'),
					T('Hide the tooltip in combat', 'tooltipExtras.hideCombat') } } } },
		{ id = 'loot', name = 'Loot and pop-ups', module = 'modules.loot', keys = { 'loot' },
			desc = 'Loot rolls and the loot won, achievement, money and new mount, pet or toy pop-ups in one column left of your character. Drag it in Edit Mode.',
			secs = { Pos('loot'), { name = 'Rows', rows = { R('Width', 'loot.w', 240, 600), R('Row height', 'loot.rowH', 36, 80), R('Font size', 'loot.font', 10, 24) } },
				{ name = 'Pop-ups', rows = { T('Flat pop-ups', 'loot.alerts') } } } },
		{ id = 'minimap', name = 'Minimap', module = 'modules.minimap', keys = { 'minimap' },
			secs = { Pos('minimap'), { name = 'Map', rows = { R('Size', 'minimap.size', 140, 400) } },
				{ name = 'Coordinates', rows = { T('Coordinates on the map', 'minimap.coords'), R('Font size', 'minimap.coordsFont', 10, 32) } },
				{ name = 'Addon buttons', rows = { R('Button size', 'minimap.buttonSize', 16, 48), R('Gap', 'minimap.buttonGap', 0, 12) } } } },
		{ id = 'tracker', name = 'Quest tracker', module = 'modules.tracker', apply = true, desc = 'Position and size are written into the SlimARK-UI Edit Mode layouts. X is the right edge.',
			secs = { Pos('tracker'), { name = 'Tracker', rows = { R('Height', 'tracker.height', 400, 1200, 10), R('Text size', 'tracker.textSize', 12, 20) } } } },
		{ id = 'vendor', name = 'Vendor', module = 'modules.vendor', secs = { { name = 'Vendor', rows = { T('Automatic repair', 'features.autoRepair'), T('Sell junk (grey items)', 'features.autoSellJunk') } } } },
		{ id = 'character', name = 'Character sheet', module = 'modules.character', desc = 'Item level, gems, enchants and what is missing on each item.',
			-- 3.0 (33, 34)
			secs = { { name = 'More', rows = { T('Upgrade track on the slots', 'charsheet.upgrade'), T('The same marks on the inspect window', 'charsheet.inspect') } } } },
		{ id = 'blizzwindows', name = 'Blizzard windows',
			desc = 'The look of Blizzard\'s own windows. Original leaves them alone. SlimARK makes them flat and dark with a thin black edge and the SlimARK font; each window is dressed the first time you open it. The switches pick the windows SlimARK dresses. With BetterFriendlist its window is dressed in place of the friends list; with BetterBags the bags keep the BetterBags skin.',
			secs = { { name = 'Look', rows = { { t = 'choice', label = 'Look', path = 'blizz.look', rerender = true, options = { { 'original', 'Original' }, { 'slimark', 'SlimARK' } } } } },
				{ name = 'Windows', rows = {
					W('Character sheet', 'character'), W('Inspect', 'inspect'), W('Spellbook and talents', 'spellbook'),
					W('Group Finder and PvP', 'groupfinder'), W('Great Vault', 'vault'), W('Adventure Guide', 'journal'),
					W('Collections', 'collections'), W('Achievements', 'achievements'), W('Friends list', 'friends'),
					W('Guild and calendar', 'guild'), W('Mail', 'mail'), W('World map', 'map'),
					W('Quests and NPC talk', 'gossip'), W('Talking head', 'talkinghead'), W('Merchant and bank', 'merchant'),
					W('Auction House and trade', 'auction'), W('Professions', 'professions'), W('Game menu and pop-ups', 'menu'),
					W('Bags (without BetterBags)', 'bags'), W('Housing dashboard', 'housing'),
				} } } },
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
			secs = { { name = 'Window', rows = { R('X', 'chat.x', 0, 2560), R('Bottom edge', 'chat.bottom', 0, 1600), R('Width', 'chat.w', 200, 1200), R('Height', 'chat.h', 100, 800), R('Font size', 'chat.fontSize', 8, 28) } },
				{ name = 'Tabs', rows = { T('Flat SlimARK tabs and edit box', 'chat.flatTabs'), T('Tab color as a stripe on top', 'chat.tabStripe'), R('Tab font size', 'chat.tabFont', 8, 24) } } } },
	} },
	{ name = 'Quality of life', pages = {
		{ id = 'autoquest', name = 'Auto quest', desc = 'Accepts and turns in quests, finished ones first. It stops when you have to choose a reward or pay gold, and leaves vendors, flight masters, innkeepers, trainers, banks and the transmogrifier alone. Hold Shift at an NPC to pause it. The top bar has an on/off switch.',
			secs = { { name = 'Auto quest', rows = { T('Auto quest', 'features.autoQuest'), T('Accept quests', 'autoquest.accept'),
				T('Turn in quests', 'autoquest.turnIn'), T('Pick the only talk option', 'autoquest.gossip') } } } },
		{ id = 'groupfinder', name = 'Group Finder', secs = { { name = 'Group Finder', rows = { T('Accept role checks with spec role', 'features.autoRoleCheck'), T('Sign up with one click', 'features.oneClickSignup'),
				T('Show the dungeon in large text when you join a group', 'features.joinedText'),
				-- 3.0 (3): the teleport button under that text.
				T('Teleport button under it when you know the dungeon\'s teleport', 'features.joinTeleport') } } } },
		{ id = 'keystone', name = 'Keystone', desc = 'Your keystone goes into the Font of Power the moment you open it. After a run your new keystone is posted to the party, as soon as the game allows addon chat again. "!keys" in party or guild chat is answered with your keystone, outside a running key and boss fights.',
			secs = { { name = 'Keystone', rows = { T('Put the keystone in the Font of Power', 'features.autoKeystone'), T('Post my new keystone to the party', 'features.announceKey'),
				T('Answer !keys in party and guild chat', 'features.answerKeys') } },
				-- 3.0: the top bar's keystone tooltip, season table and affixes (8) and the party's keys (10).
				{ name = 'Keystone tooltip', rows = { T('Season best and this week\'s affixes', 'features.keystoneSeason'),
					T('Party keys (from addons that share them)', 'features.partyKeys') } } } },
		{ id = 'combatlog', name = 'Combat log', desc = 'Combat logging switches on when a Mythic+ key starts or you enter a raid, and off when you leave, with Advanced Combat Logging on for the log sites. A log you started yourself with /combatlog is left alone.',
			secs = { { name = 'Combat log', rows = { T('Log Mythic+ runs and raids', 'features.autoCombatLog') } } } },
		{ id = 'quickfocus', name = 'Quick focus', desc = 'The modifier with a left click sets your focus: on a mob in the world, on a nameplate and on the SlimARK frames. With the modifier held the left click no longer targets or turns the camera in the world. Needs a reload.',
			secs = { { name = 'Quick focus', rows = { T('Modifier + left click sets the focus', 'features.quickFocus'),
				Choice('Modifier', 'quickFocus.modifier', { { 'SHIFT', 'Shift' }, { 'CTRL', 'Ctrl' }, { 'ALT', 'Alt' } }) } } } },
		{ id = 'delete', name = 'Deleting items', desc = 'Destroying a good item asks for a click on Confirm, with the item shown, instead of typing DELETE.',
			secs = { { name = 'Deleting items', rows = { T('Confirm button instead of typing DELETE', 'features.easyDelete') } } } },
		{ id = 'errors', name = 'Error messages', desc = 'Hides the red error text and its voice for range, facing, line of sight, no or wrong target, moving, mana and items not ready. Blizzard already hides the out of energy and cooldown ones. Full bags and every other message stay. Needs a reload.',
			secs = { { name = 'Error messages', rows = { T('Hide the combat error spam', 'features.errorFilter') } } } },
		{ id = 'cinematics', name = 'Cinematics', secs = { { name = 'Cinematics', rows = { T('Skip seen cinematics', 'features.skipCinematics'), T('Skip seen movies', 'features.skipMovies') } },
			{ name = 'Memory', rows = { Btn('Forget seen ones', ForgetCutscenes) } } } },
	} },
	{ name = 'About', pages = { { id = 'about', name = 'Version and changelog', about = true } } },
}

-- Shown on the About page, newest first.
S.changelog = {
	{ version = '2.3.0', lines = {
		'Enemy cast bars go dark while your interrupt is on cooldown',
		'Who a cast is aimed at: the name in class color, a red YOU when it is you',
		'Aggro warning color on nameplates in a group; an execute line for your finisher',
		'Shaman totem row; Shift + left click sets the focus; optional player frame fade',
		'"!keys" answered with your keystone; combat log in keys and raids; the dungeon in large text when you join a group',
	} },
	{ version = '2.2.0', lines = {
		'Frames take the color of a typed debuff: poison, disease, curse, magic, bleed',
		'On the player frame, party, raid and healer grid; what you can dispel keeps its bright frame',
	} },
	{ version = '2.1.4', lines = {
		'Interrupter names: only the kick at that mob counts, in class color again',
		'Trinket icons: chance buffs are not remembered; item data asked for again',
		'Gold: a renamed character is counted once',
		'Auto quest leaves grey quests alone when their details open directly',
	} },
	{ version = '2.1.3', lines = {
		'Auto quest accepts directly opened grey quests again',
		'Gold tooltip as in 2.1.0: your characters and one total',
		'Trinket and potion icons without question marks; learned effects kept',
		'Interrupter names on nameplates without question marks',
	} },
	{ version = '2.1.2', lines = {
		'Seen cinematics are skipped again by default, as before 2.1.1',
		'Details, DBM and BigWigs switch back to the SlimARK profile at login again',
	} },
	{ version = '2.1.1', lines = {
		'Settings apply the newly saved values; a failed apply stays open for a retry',
		'Your selected Details and boss-mod profiles stay selected after login and reload',
		'Group-frame fallback, aggro and ready check fixes; current Retail and Forever tooltip APIs',
		'Mythic+ previews stop before real runs; old boss kills do not get invented times',
		'Consumable recognition, item-data retries and interrupt attribution are more reliable',
		'Disabled automation stays off; low-level quests and unseen cinematics are left alone',
		'Regression checks and a reproducible addon package without unused developer tools',
	} },
	{ version = '2.1.0', lines = {
		'Group frames: private auras (boss debuffs) in the middle, drawn by the game',
		'Group frames: incoming heals in pale green after the health, heal absorbs in dark red stripes at its end',
		'Group frames: your own HoTs as small icons with a swipe',
		'Group frames: leader, raid marker, resurrection, summon, ready check and phase icons',
		'Group frames: a red frame on the member a mob is hitting',
	} },
	{ version = '2.0.1', lines = {
		'Combat text is off by default: the game\'s own numbers stay until you switch it on under Combat: Combat text',
	} },
	{ version = '2.0.0', lines = {
		'Setup window: choose how Blizzard\'s windows look, Original or SlimARK. Change it any time under Interface: Blizzard windows',
		'SlimARK windows: flat and dark with a thin black edge, a gold line on top and the SlimARK font. Character sheet, inspect, spellbook and talents, Group Finder and PvP, Great Vault, Adventure Guide, collections, achievements, friends (BetterFriendlist too), guild and calendar, mail, world map, quests and NPC talk, talking head, merchant and bank, Auction House and trade, professions, game menu, pop-ups and bags. Each window is dressed the first time you open it, one switch per window',
		'Combat text: floating numbers in the SlimARK font. Crits are twice the size, orange on your target, and land with a pop and shake; damage you take and heals you get beside your character, damage on your target while you are not in a group',
		'Deleting a good item asks for a click on Confirm, with the item shown, instead of typing DELETE',
		'BetterBags: the SlimARK theme has the gold line and the title on the left, like the new windows',
		'Tooltip: with Raider.IO installed the Mythic+ rating shows once, in Raider.IO\'s lines; the item level also uses the inspects Raider.IO makes',
	} },
	{ version = '1.8.1', lines = {
		'Tooltip: the fixed place sits right above the bags and consumables row, clear of the Details title bar',
		'Quest tracker: shorter by the marker bar\'s height when the bar is under the minimap',
	} },
	{ version = '1.8.0', lines = {
		'Tooltip: flat, with the class, reaction or item quality color as a stripe on top and a thin health bar; players show their Mythic+ rating, item level and target. Fixed above the Details windows or next to the mouse',
		'Loot rolls and pop-ups (loot won, upgrades, money, achievements, new mounts, pets, toys) in one flat column left of your character',
		'Marker bar in a group: target and ground markers, ready check and pull countdown, under the minimap or next to the party frames',
		'Ready check window: what is on you and what is missing, with a button that uses the missing flask, food, rune or oil',
	} },
	{ version = '1.7.0', lines = {
		'Keystone: it goes into the Font of Power the moment you open it, and your new keystone is posted to the party after a run',
		'Error messages: the red text and its voice for range, facing, line of sight, no or wrong target, moving, mana and items not ready are hidden',
		'Action bars: the fade of the upper bars runs no timer any more',
	} },
	{ version = '1.6.0', lines = {
		'Action bars: flat buttons, a gold edge for procs, a turquoise edge for the assisted highlight',
		'Action bars: red, blue or grey icons when a spell is out of range, short of its resource or not usable',
		'Action bars: short hotkeys (sT for Shift-T), hidden macro names, large cooldown numbers, a lighter cover for the global cooldown',
		'Action bars: the upper bars fade out of combat and come back in combat, with a target or under the mouse. Every part can be switched on the Action bars page',
		'Chattynator: flat tabs in the SlimARK font, the tab color as a stripe on top, the selected tab in gold, a gold line for new messages',
	} },
	{ version = '1.5.2', lines = {
		'Fixed: an error on nameplates when a cast was interrupted and the game hid the spell name',
		'Fixed: an error from the trinket and potion icons when the game hid a buff update in combat',
	} },
	{ version = '1.5.1', lines = {
		'Fixed: a click on a dungeon in the keystone teleport list closed the list without teleporting',
		'Fixed: test mode showed no party and raid frames while you were not in a group',
		'Fixed: Details! added a percent column when overall updated out of combat, and the texts ran into each other',
	} },
	{ version = '1.5.0', lines = {
		'Test mode (General: Test mode, or /slimark test): made-up players fill the party, raid 20, raid 40 or Mythic+ frames, so you see the layout without a group',
		'Test mode shows the healer or the DPS and tank layout, whichever spec you play, and stays on in Edit Mode so you can drag the filled frames',
	} },
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
	local previous, positions, seen = {}, {}, {}
	for path, value in pairs(S.pending) do
		previous[#previous + 1] = { path = path, live = Copy(S.Get(path)), saved = Copy(store[path]) }
		if S.Equal(value, S.defaults[path]) then
			store[path] = nil
		else
			store[path] = Copy(value)
		end
		-- ApplyAll reads the same tables captured by the other modules at load time.
		Write(path, value)
		local page = S.pageOf[path]
		if page and page.apply then apply = true end
		-- Position choices replace an Edit Mode override just like explicit coordinates.
		local last = path:match('[^.]+$')
		if page and page.keys and (last == 'x' or last == 'y' or last == 'right' or last == 'iconY'
			or path == 'markers.place' or path:find('%.heal%.')) and ns.CharDB then
			for _, key in ipairs(page.keys) do
				for _, name in ipairs({ 'pos', 'posHeal' }) do
					local saved = ns.CharDB[name]
					if saved then
						seen[saved] = seen[saved] or {}
						if not seen[saved][key] then
							positions[#positions + 1] = { store = saved, key = key, value = saved[key] }
							seen[saved][key] = true
						end
						saved[key] = nil
					end
				end
			end
		end
	end
	if apply and ns.ApplyAll then
		if ns.ApplyAll() == false then
			-- External profiles may be partially applied; keep the edit and allow a retry.
			for _, old in ipairs(previous) do
				store[old.path] = old.saved
				Write(old.path, old.live)
			end
			for _, old in ipairs(positions) do old.store[old.key] = old.value end
			ns.Print('Settings were not saved. Your changes are still in this panel; fix the reported problem and save again.')
			return false
		end
	else
		wipe(S.pending)
		ReloadUI()
	end
	wipe(S.pending)
	return true
end
