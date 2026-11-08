-- Every position and size is here, in real pixels, from the top left corner of the 2560x1600 image.
-- /slimark apply calculates the position and size of the Blizzard elements from this for the current UI scale.
local _, ns = ...

-- Colors of the cooldown bars per role.
local MAIN = { 0.89, 0.70, 0.24 }
local KICK = { 0.84, 0.42, 0.23 }
local DEFENSIVE = { 0.50, 0.82, 0.91 }
local IMMUNE = { 0.95, 0.88, 0.54 }
local UTILITY = { 0.44, 0.80, 0.55 }

-- One bar. With several IDs, the first known spell is used.
local function Bar(color, ...)
	return { ids = { ... }, color = color }
end

ns.C = {
	-- Raised when /slimark apply has new positions to write (Edit Mode, boss mods).
	version = 3,

	colors = {
		track = { 0.137, 0.145, 0.169 },
		-- Gold accent of the UI, also the paladin's holy power (his choice over ElvUI's yellow).
		classPower = { 1, 0.7, 0.12 },
		-- Class power colors after the ElvUI defaults, by the resource the game uses.
		-- A list colors the pips one by one, from the first to the last.
		power = {
			COMBO_POINTS = {
				{ 0.75, 0.31, 0.31 }, { 0.78, 0.56, 0.31 }, { 0.81, 0.81, 0.31 }, { 0.56, 0.78, 0.31 },
				{ 0.43, 0.76, 0.31 }, { 0.31, 0.75, 0.31 }, { 0.36, 0.81, 0.54 },
			},
			CHARGED = { 0.16, 0.64, 1 },
			CHI = {
				{ 0.71, 0.76, 0.32 }, { 0.58, 0.73, 0.36 }, { 0.49, 0.71, 0.39 },
				{ 0.39, 0.69, 0.42 }, { 0.27, 0.66, 0.46 }, { 0.14, 0.63, 0.5 },
			},
			ESSENCE = {
				{ 0.1, 0.92, 1 }, { 0.17, 0.94, 0.84 }, { 0.24, 0.96, 0.69 },
				{ 0.31, 0.98, 0.53 }, { 0.34, 0.99, 0.45 }, { 0.38, 1, 0.38 },
			},
			ARCANE_CHARGES = { 0, 0.4, 1 },
			ICICLES = { 0, 0.8, 1 },
			SOUL_SHARDS = { 0.5, 0.25, 0.8 },
			MAELSTROM = { 0.35, 0.15, 1 },
			SOUL_FRAGMENTS = { 0.3, 0.15, 1 },
			TIP_OF_THE_SPEAR = { 0, 0.85, 0.85 },
			-- Runes by spec ID: Blood, Frost, Unholy.
			RUNES = { [250] = { 1, 0.25, 0.25 }, [251] = { 0.25, 1, 1 }, [252] = { 0.25, 1, 0.25 } },
		},
		cast = { 0.79, 0.64, 0.29 },
		notInterruptible = { 0.45, 0.45, 0.48 },
		enemyCast = { 0.35, 0.75, 1 },
		-- Magenta: far from the red, orange and yellow plates and the purple caster.
		important = { 1, 0.2, 0.75 },
		casting = { 0.35, 0.75, 1 },
		caster = { 0.62, 0.4, 1 },
		target = { 1, 1, 1 },
		mana = { 0.25, 0.5, 0.88 },
		-- Shields (damage absorbs) on the health bars.
		shield = { 0.85, 0.95, 1 },
		-- The cooldown bars share these tables, so a color set in /slimark reaches every bar.
		cdMain = MAIN,
		cdKick = KICK,
		cdDefensive = DEFENSIVE,
		cdImmune = IMMUNE,
		cdUtility = UTILITY,
	},

	-- Whole modules, switched in /slimark. Off leaves the Blizzard frame in place.
	modules = {
		unitframes = true, party = true, raid = true, grid = true, nameplates = true, auras = true,
		cooldowns = true, consumables = true, mythicplus = true, actionbars = true, minimap = true,
		tracker = true, vendor = true, character = true, movers = true, betterbags = true, effects = true,
		databar = true, tooltip = true, loot = true, markers = true, readycheck = true,
		combattext = true,
	},

	-- Single features, switched in /slimark.
	features = {
		roleIcon = true, dispelGlow = true, interrupter = true, plateArrows = true,
		autoRepair = true, autoRoleCheck = true, oneClickSignup = true,
		skipCinematics = true, skipMovies = true, loginMessage = true, shields = true, activeAuras = true,
		autoQuest = true, autoKeystone = true, announceKey = true, errorFilter = true,
		easyDelete = true,
	},

	-- The look of Blizzard's own windows (2.0). 'none' until the setup window asks for it,
	-- then 'original' (left alone) or 'slimark'. The switches name the windows SlimARK dresses.
	blizz = {
		look = 'none',
		character = true, inspect = true, spellbook = true, groupfinder = true, vault = true,
		journal = true, collections = true, achievements = true, friends = true, guild = true,
		mail = true, map = true, gossip = true, talkinghead = true, merchant = true, auction = true,
		professions = true, menu = true, bags = true,
	},

	-- Floating combat text (2.0). crit: 'impact' (lands with a pop and shake) or 'bigger'.
	-- size: percent of the default. target: numbers on the target while not in a group.
	combattext = { crit = 'impact', size = 100, heals = true, incoming = true, target = true },

	units = {
		player = { x = 720, y = 1160, w = 340, h = 66, font = 20, classPower = 12, heal = { x = 630, y = 1160 } },
		target = { x = 1500, y = 1160, w = 340, h = 66, font = 20, heal = { x = 1600, y = 1160 } },
		targettarget = { x = 1500, y = 1255, w = 170, h = 27, font = 16, heal = { x = 1600, y = 1255 } },
		pet = { x = 720, y = 1255, w = 170, h = 27, font = 16, heal = { x = 630, y = 1120 } },
		focus = { x = 1500, y = 1050, w = 260, h = 38, font = 18, heal = { x = 1600, y = 1050 } },
		boss = { x = 1920, y = 430, w = 270, h = 50, gap = 8, font = 16 },
		-- Party (DPS and tank): a column of large frames right next to the character.
		party = { x = 710, y = 690, w = 240, h = 72, gap = 4, debuff = 26, defensive = 28, font = 16 },
		raid = { x = 12, y = 760, w = 112, h = 48, gap = 3, debuff = 18, defensive = 20, font = 15 },
		-- The grid of the healer group above the action bars. The y is the bottom of the grid, it grows upward.
		grid = { x = 974, y = 1420, w = 120, h = 56, gap = 3, debuff = 22, defensive = 26, font = 16 },
	},

	auras = {
		-- timeH: the countdown bar under the icon. gap: space between the icons.
		buffs = { right = 2254, y = 12, size = 40, timeH = 18, gap = 6, width = 700, height = 122, max = 30, timeFont = 16, countFont = 18 },
		debuffs = { right = 2254, y = 142, size = 52, timeH = 20, gap = 6, width = 400, height = 72, max = 7, timeFont = 18, countFont = 22 },
		targetDebuffSize = 38,
	},

	plate = { w = 200, h = 22, casterH = 28, castH = 16, debuff = 24, font = 14, targeterFont = 13, holdTime = 1.5, dimAlpha = 0.6, arrowW = 11, arrowH = 16, arrowGap = 4 },

	cooldowns = {
		x = 1100, y = 1100, w = 360, rowH = 22, gap = 3, font = 16,
		iconY = 1228, iconSize = 46, iconGap = 3,
		-- In the healer layout the bars and the icons go under the player frame.
		heal = { x = 640, y = 1262, w = 320, iconY = 1390 },
		-- If fewer than five spells of a spec's list are known, the game's own list fills the rest.
		fillColor = { 0.62, 0.66, 0.72 },
		-- By spec ID. What the character does not know is not shown.
		-- The icons are the rotation row. Where there is none, the game's own spec list provides it.
		specs = {
			-- Death Knight: Blood, Frost, Unholy
			[250] = { bars = { Bar(MAIN, 49028), Bar(KICK, 47528), Bar(DEFENSIVE, 55233), Bar(DEFENSIVE, 48792), Bar(DEFENSIVE, 48707) } },
			[251] = { bars = { Bar(MAIN, 51271), Bar(KICK, 47528), Bar(DEFENSIVE, 48792), Bar(DEFENSIVE, 48707), Bar(UTILITY, 47568) } },
			[252] = { bars = { Bar(MAIN, 63560), Bar(KICK, 47528), Bar(DEFENSIVE, 48792), Bar(DEFENSIVE, 48707), Bar(UTILITY, 42650) } },
			-- Demon Hunter: Havoc, Vengeance, Devourer
			[577] = { bars = { Bar(MAIN, 191427), Bar(KICK, 183752), Bar(DEFENSIVE, 198589), Bar(DEFENSIVE, 196718), Bar(UTILITY, 370965) } },
			[581] = { bars = { Bar(MAIN, 187827), Bar(KICK, 183752), Bar(DEFENSIVE, 203720), Bar(DEFENSIVE, 204021), Bar(DEFENSIVE, 196718) } },
			[1480] = { bars = { Bar(MAIN, 1217605), Bar(KICK, 183752), Bar(DEFENSIVE, 198589), Bar(DEFENSIVE, 196718) } },
			-- Druid: Balance, Feral, Guardian, Restoration
			[102] = { bars = { Bar(MAIN, 102560, 194223), Bar(KICK, 78675), Bar(DEFENSIVE, 22812), Bar(DEFENSIVE, 108238), Bar(UTILITY, 29166) } },
			[103] = { bars = { Bar(MAIN, 102543, 106951), Bar(KICK, 106839), Bar(DEFENSIVE, 61336), Bar(DEFENSIVE, 22812), Bar(UTILITY, 5217) } },
			[104] = { bars = { Bar(MAIN, 102558, 50334), Bar(KICK, 106839), Bar(DEFENSIVE, 61336), Bar(DEFENSIVE, 22812), Bar(UTILITY, 200851) } },
			[105] = { bars = { Bar(MAIN, 740), Bar(MAIN, 33891, 391528), Bar(DEFENSIVE, 102342), Bar(DEFENSIVE, 22812), Bar(UTILITY, 132158) } },
			-- Evoker: Devastation, Preservation, Augmentation
			[1467] = { bars = { Bar(MAIN, 375087), Bar(KICK, 351338), Bar(DEFENSIVE, 363916), Bar(DEFENSIVE, 374348), Bar(UTILITY, 370553) } },
			[1468] = { bars = { Bar(MAIN, 363534), Bar(MAIN, 359816), Bar(DEFENSIVE, 357170), Bar(DEFENSIVE, 363916), Bar(UTILITY, 370537) } },
			[1473] = { bars = { Bar(MAIN, 403631), Bar(KICK, 351338), Bar(DEFENSIVE, 363916), Bar(DEFENSIVE, 374348), Bar(UTILITY, 404977) } },
			-- Hunter: Beast Mastery, Marksmanship, Survival
			[253] = { bars = { Bar(MAIN, 19574), Bar(KICK, 147362), Bar(IMMUNE, 186265), Bar(DEFENSIVE, 109304), Bar(UTILITY, 359844) } },
			[254] = { bars = { Bar(MAIN, 288613), Bar(KICK, 147362), Bar(IMMUNE, 186265), Bar(DEFENSIVE, 109304), Bar(DEFENSIVE, 264735) } },
			[255] = { bars = { Bar(MAIN, 360952), Bar(KICK, 187707), Bar(IMMUNE, 186265), Bar(DEFENSIVE, 109304), Bar(DEFENSIVE, 264735) } },
			-- Mage: Arcane, Fire, Frost
			[62] = { bars = { Bar(MAIN, 365350), Bar(KICK, 2139), Bar(IMMUNE, 45438, 414658), Bar(DEFENSIVE, 342245), Bar(UTILITY, 55342) } },
			[63] = { bars = { Bar(MAIN, 190319), Bar(KICK, 2139), Bar(IMMUNE, 45438, 414658), Bar(DEFENSIVE, 342245), Bar(UTILITY, 55342) } },
			[64] = { bars = { Bar(MAIN, 12472), Bar(KICK, 2139), Bar(IMMUNE, 45438, 414658), Bar(DEFENSIVE, 342245), Bar(UTILITY, 55342) } },
			-- Monk: Brewmaster, Mistweaver, Windwalker
			[268] = { bars = { Bar(MAIN, 132578), Bar(KICK, 116705), Bar(DEFENSIVE, 115203), Bar(DEFENSIVE, 322507), Bar(DEFENSIVE, 115176) } },
			[270] = { bars = { Bar(MAIN, 115310, 388615), Bar(MAIN, 322118, 325197), Bar(DEFENSIVE, 116849), Bar(DEFENSIVE, 115203), Bar(UTILITY, 116680) } },
			[269] = { bars = { Bar(MAIN, 137639, 123904), Bar(KICK, 116705), Bar(DEFENSIVE, 115203), Bar(DEFENSIVE, 122470), Bar(UTILITY, 322109) } },
			-- Paladin: Holy, Protection, Retribution
			[65] = { bars = { Bar(MAIN, 31821), Bar(MAIN, 31884), Bar(DEFENSIVE, 6940), Bar(DEFENSIVE, 633), Bar(IMMUNE, 642) } },
			[66] = { bars = { Bar(MAIN, 389539, 31884), Bar(KICK, 96231), Bar(DEFENSIVE, 31850), Bar(DEFENSIVE, 86659), Bar(DEFENSIVE, 633) } },
			[70] = {
				bars = { Bar(MAIN, 31884), Bar(KICK, 96231), Bar(DEFENSIVE, 633), Bar(IMMUNE, 642), Bar(UTILITY, 1044) },
				icons = { 255937, 184575, 20271, 24275, 375576, 343721, 343527 },
			},
			-- Priest: Discipline, Holy, Shadow
			[256] = { bars = { Bar(MAIN, 62618), Bar(MAIN, 47536, 472433), Bar(DEFENSIVE, 33206), Bar(DEFENSIVE, 19236), Bar(UTILITY, 10060) } },
			[257] = { bars = { Bar(MAIN, 64843), Bar(MAIN, 200183), Bar(DEFENSIVE, 47788), Bar(DEFENSIVE, 19236), Bar(UTILITY, 10060) } },
			[258] = { bars = { Bar(MAIN, 228260), Bar(KICK, 15487), Bar(DEFENSIVE, 47585), Bar(DEFENSIVE, 19236), Bar(UTILITY, 10060) } },
			-- Rogue: Assassination, Outlaw, Subtlety
			[259] = { bars = { Bar(MAIN, 360194), Bar(KICK, 1766), Bar(DEFENSIVE, 31224), Bar(DEFENSIVE, 5277), Bar(UTILITY, 1856) } },
			[260] = { bars = { Bar(MAIN, 13750), Bar(KICK, 1766), Bar(DEFENSIVE, 31224), Bar(DEFENSIVE, 5277), Bar(UTILITY, 1856) } },
			[261] = { bars = { Bar(MAIN, 121471), Bar(KICK, 1766), Bar(DEFENSIVE, 31224), Bar(DEFENSIVE, 5277), Bar(UTILITY, 1856) } },
			-- Shaman: Elemental, Enhancement, Restoration
			[262] = { bars = { Bar(MAIN, 114050, 198067), Bar(KICK, 57994), Bar(DEFENSIVE, 108271), Bar(UTILITY, 198103) } },
			[263] = { bars = { Bar(MAIN, 114051, 384352), Bar(KICK, 57994), Bar(DEFENSIVE, 108271), Bar(UTILITY, 51533), Bar(UTILITY, 198103) } },
			[264] = { bars = { Bar(MAIN, 98008), Bar(MAIN, 108280), Bar(MAIN, 114052), Bar(DEFENSIVE, 108271), Bar(KICK, 57994) } },
			-- Warlock: Affliction, Demonology, Destruction
			[265] = { bars = { Bar(MAIN, 205180), Bar(KICK, 19647), Bar(DEFENSIVE, 104773), Bar(DEFENSIVE, 108416), Bar(UTILITY, 6789) } },
			[266] = { bars = { Bar(MAIN, 265187), Bar(KICK, 19647), Bar(DEFENSIVE, 104773), Bar(DEFENSIVE, 108416), Bar(UTILITY, 6789) } },
			[267] = { bars = { Bar(MAIN, 1122), Bar(KICK, 19647), Bar(DEFENSIVE, 104773), Bar(DEFENSIVE, 108416), Bar(UTILITY, 6789) } },
			-- Warrior: Arms, Fury, Protection
			[71] = { bars = { Bar(MAIN, 107574), Bar(KICK, 6552), Bar(DEFENSIVE, 118038), Bar(DEFENSIVE, 97462), Bar(UTILITY, 167105) } },
			[72] = { bars = { Bar(MAIN, 1719), Bar(KICK, 6552), Bar(DEFENSIVE, 184364), Bar(DEFENSIVE, 97462), Bar(UTILITY, 107574) } },
			[73] = { bars = { Bar(MAIN, 107574), Bar(KICK, 6552), Bar(DEFENSIVE, 871), Bar(DEFENSIVE, 12975), Bar(DEFENSIVE, 97462) } },
		},
	},

	vendor = { perPage = 20 },

	-- Midnight: head, shoulder, chest, legs (spellthread), boots, rings, weapons.
	enchantSlots = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [11] = true, [12] = true, [16] = true, [17] = true },

	-- Active trinket and potion effects: icons above the cooldown bars, above the player frame for healers.
	effects = {
		x = 1216, y = 1028, size = 40, gap = 4, font = 16, trinkets = true, potions = true,
		heal = { x = 736, y = 1048 },
	},

	consumables = {
		x = 1942, y = 1284, size = 40, gap = 3,
		-- Order and count per category. The subclass is the Enum.ItemConsumableSubclass value.
		groups = {
			{ subclass = 3, count = 2 }, -- flask, phial
			{ subclass = 1, count = 3 }, -- potion
			{ subclass = 5, count = 1 }, -- food
			{ subclass = 6, count = 1 }, -- oil, weightstone
		},
		extraItems = { 5512, 224464 }, -- healthstone
	},

	-- anchor: 'fixed' puts the tooltip's bottom right corner above the Details windows, 'cursor' next to the mouse.
	tooltip = { anchor = 'fixed' },

	-- The column of loot rolls and pop-ups: x, y is its top left, the rows stack up from its bottom.
	loot = { x = 640, y = 480, w = 380, rowH = 50, gap = 4, font = 16, alerts = true },

	-- place: 'map' under the minimap in three rows, 'party' in two columns next to the party frames.
	markers = { place = 'map', size = 28, gap = 3 },

	-- useButtons: a button on each missing row uses the item from your bags.
	readycheck = { x = 1115, y = 380, useButtons = true },

	details = {
		right = 2548, bottom = 1588, w = 300, h = 230, gap = 6,
		barHeight = 26, fontSize = 18, skin = 'ElvUI Frame Style',
	},

	-- flatTabs: the flat SlimARK look on Chattynator's tabs and edit box; tabStripe: the tab's color as a
	-- thin stripe on top, otherwise a gold line under the selected tab.
	chat = { x = 12, bottom = 1588, w = 614, h = 300, fontSize = 15, flatTabs = true, tabStripe = true, tabFont = 13 },

	bossmods = {
		-- Normal bars sit opposite the party frames, on the right of the character.
		normal = { x = 1590, y = 690, w = 320, h = 24 },
		huge = { x = 1100, y = 620, w = 360, h = 28 },
		gap = 3, fontSize = 16,
	},

	-- The top bar sits on the top pixel row over the whole width. With it on, everything placed
	-- at the top of the screen (minimap, buffs, quest tracker, ...) moves down by its height.
	databar = {
		h = 26, font = 15, iconSize = 22,
		show = { micro = true, durability = true, fps = true, latency = true, queue = true, currency = true,
			clock = true, gold = true, itemLevel = true, keystone = true, vault = true, autoQuest = true, addons = true },
	},

	-- Talks to quest NPCs: accepts, turns in, picks the only gossip option. Holding Shift pauses it.
	autoquest = { accept = true, turnIn = true, gossip = true },

	-- coords: the player's map position at the bottom of the map, where the clock was.
	minimap = { x = 2290, y = 8, size = 260, buttonSize = 28, buttonGap = 3, coords = true, coordsFont = 20 },

	-- x, y: the top right corner of the quest tracker. The M+ panel takes its place during a key.
	-- The coordinates sit inside the map now, so the tracker starts right under it.
	tracker = { x = 2548, y = 280, height = 580, textSize = 12 },
	fps = { y = 6 },

	-- flat: flat button states and the gold proc edge. tint: icon color when it cannot be used.
	-- shortKeys: s-T becomes a small gold s and T. fade: the bars above the bottom rows fade out of
	-- combat to fadeAlpha percent. assist: a turquoise edge in place of Blizzard's assisted highlight.
	actionbars = { font = 15, hotkeyFont = 13, cooldownFont = 21, flat = true, tint = true, shortKeys = true,
		macroNames = false, fade = true, fadeAlpha = 0, assist = true },

	-- Blizzard elements in the Edit Mode layout.
	-- { system, subindex, which point of the frame, x, y }, x and y are real pixels from the top left.
	layout = {
		name = 'SlimARK-UI',
		healName = 'SlimARK-UI Heal',
		bars = { size = 48, padding = 2, bottom = 1578, center = 1280 },
		-- The first three enabled bars go bottom center, from the bottom up. The rest go above the chat.
		centerRows = 3,
		order = {
			{ index = 'MainBar' },
			{ index = 'Bar2', frame = 'MultiBarBottomLeft' },
			{ index = 'Bar3', frame = 'MultiBarBottomRight' },
			{ index = 'RightBar1', frame = 'MultiBarRight' },
			{ index = 'RightBar2', frame = 'MultiBarLeft' },
			{ index = 'ExtraBar1', frame = 'MultiBar5' },
			{ index = 'ExtraBar2', frame = 'MultiBar6' },
			{ index = 'ExtraBar3', frame = 'MultiBar7' },
		},
		sideX = 12, sideBottom = 1282,
		bagsSize = 75,
		-- System, index, point, x, y, side, top: side 'LEFT' or 'RIGHT' stays at that screen edge, the rest
		-- stays centered. top: moves down with the top bar. The quest tracker follows C.tracker.
		systems = {
			{ 'ActionBar', 'StanceBar', 'BOTTOMRIGHT', 960, 1578 },
			{ 'ActionBar', 'PetActionBar', 'BOTTOMLEFT', 1600, 1578 },
			{ 'ActionBar', 'PossessActionBar', 'BOTTOM', 1280, 1420 },
			{ 'Minimap', nil, 'TOPRIGHT', 2550, 8, 'RIGHT', true },
			{ 'MicroMenu', nil, 'TOPLEFT', 12, 10, 'LEFT', true },
			{ 'Bags', nil, 'BOTTOMRIGHT', 2548, 1324, 'RIGHT' },
			{ 'HudTooltip', nil, 'BOTTOMRIGHT', 2548, 1276, 'RIGHT' },
			{ 'ChatFrame', nil, 'BOTTOMLEFT', 12, 1588, 'LEFT' },
			{ 'TalkingHeadFrame', nil, 'TOP', 1280, 100 },
			{ 'TimerBars', nil, 'TOP', 1280, 40, nil, true },
			{ 'EncounterBar', nil, 'TOP', 1280, 200 },
			{ 'ExtraAbilities', nil, 'BOTTOM', 960, 1150 },
			{ 'VehicleLeaveButton', nil, 'BOTTOM', 780, 1150 },
			{ 'LootFrame', nil, 'TOPLEFT', 640, 300 },
			{ 'DurabilityFrame', nil, 'TOPRIGHT', 2280, 230, 'RIGHT', true },
			{ 'VehicleSeatIndicator', nil, 'TOPRIGHT', 1900, 230, 'RIGHT', true },
			{ 'ArchaeologyBar', nil, 'BOTTOM', 1280, 1040 },
			{ 'PersonalResourceDisplay', nil, 'BOTTOM', 1280, 1000 },
			{ 'LossOfControl', nil, 'CENTER', 1280, 560 },
			{ 'RaidWarning', nil, 'TOP', 1280, 250 },
			{ 'CooldownViewer', 'Essential', 'BOTTOM', 1280, 1336 },
			{ 'CooldownViewer', 'Utility', 'BOTTOM', 1280, 1378 },
			{ 'CooldownViewer', 'BuffIcon', 'BOTTOM', 1280, 1420 },
			{ 'CooldownViewer', 'BuffBar', 'BOTTOM', 1280, 1092 },
			{ 'AuraFrame', 'ExternalDefensivesFrame', 'TOPRIGHT', 2170, 230, 'RIGHT', true },
			{ 'CastBar', nil, 'BOTTOM', 1280, 1000 },
		},
		-- The healer layout is the same, only these elements are placed elsewhere.
		healSystems = {
			{ 'CooldownViewer', 'Essential', 'BOTTOM', 1770, 1336 },
			{ 'CooldownViewer', 'Utility', 'BOTTOM', 1770, 1378 },
			{ 'CooldownViewer', 'BuffIcon', 'BOTTOM', 1770, 1420 },
			{ 'ExtraAbilities', nil, 'BOTTOM', 880, 1150 },
			{ 'VehicleLeaveButton', nil, 'BOTTOM', 700, 1115 },
		},
		cooldownIcons = { Essential = 46, Utility = 36, BuffIcon = 36 },
	},
}
