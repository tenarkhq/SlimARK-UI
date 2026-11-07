-- Minden pozíció és méret itt van, valódi képpontban, a 2560x1600-as kép bal felső sarkától.
-- A Blizzard elemek helyét és méretét a /slim apply ebből számolja ki az aktuális UI scale-hez.
local _, ns = ...

-- A cooldown sávok színei szerepenként.
local MAIN = { 0.89, 0.70, 0.24 }
local KICK = { 0.84, 0.42, 0.23 }
local DEFENSIVE = { 0.50, 0.82, 0.91 }
local IMMUNE = { 0.95, 0.88, 0.54 }
local UTILITY = { 0.44, 0.80, 0.55 }

-- Egy sáv. Több ID esetén az első ismert spell él.
local function Bar(color, ...)
	return { ids = { ... }, color = color }
end

ns.C = {
	version = 2,

	colors = {
		track = { 0.137, 0.145, 0.169 },
		classPower = { 1, 0.7, 0.12 },
		cast = { 0.79, 0.64, 0.29 },
		notInterruptible = { 0.45, 0.45, 0.48 },
		enemyCast = { 0.35, 0.75, 1 },
		important = { 1, 0.5, 0.05 },
		casting = { 0.35, 0.75, 1 },
		caster = { 0.62, 0.4, 1 },
		target = { 1, 1, 1 },
		mana = { 0.25, 0.5, 0.88 },
	},

	units = {
		player = { x = 720, y = 1160, w = 340, h = 66, font = 20, classPower = 12, heal = { x = 630, y = 1160 } },
		target = { x = 1500, y = 1160, w = 340, h = 66, font = 20, heal = { x = 1600, y = 1160 } },
		targettarget = { x = 1500, y = 1255, w = 170, h = 27, font = 16, heal = { x = 1600, y = 1255 } },
		pet = { x = 720, y = 1255, w = 170, h = 27, font = 16, heal = { x = 630, y = 1120 } },
		focus = { x = 1500, y = 1050, w = 260, h = 38, font = 18, heal = { x = 1600, y = 1050 } },
		boss = { x = 1920, y = 430, w = 270, h = 50, gap = 8, font = 16 },
		party = { x = 12, y = 860, w = 230, h = 50, gap = 6, debuff = 24, defensive = 22, font = 18 },
		raid = { x = 12, y = 760, w = 112, h = 48, gap = 3, debuff = 18, defensive = 20, font = 15 },
		-- A gyógyító csoport rácsa az action barok fölött. Az y a rács alja, felfelé nő.
		grid = { x = 974, y = 1420, w = 120, h = 56, gap = 3, debuff = 22, defensive = 26, font = 16 },
	},

	auras = {
		buffs = { right = 2254, y = 12, size = 40, width = 700, height = 86, max = 32 },
		debuffs = { right = 2254, y = 104, size = 52, width = 400, height = 56, max = 8 },
		targetDebuffSize = 38,
	},

	plate = { w = 200, h = 18, casterH = 24, castH = 16, debuff = 24, font = 15, targeterFont = 13, holdTime = 1.5, dimAlpha = 0.6, arrowW = 11, arrowH = 16, arrowGap = 4 },

	cooldowns = {
		x = 1100, y = 1100, w = 360, rowH = 22, gap = 3, font = 16,
		iconY = 1228, iconSize = 46, iconGap = 3,
		-- Gyógyító elrendezésben a sávok és az ikonok a játékos kerete alá kerülnek.
		heal = { x = 640, y = 1262, w = 320, iconY = 1390 },
		-- Ha egy spec listájából kevesebb mint öt spell ismert, a játék saját listája tölti ki.
		fillColor = { 0.62, 0.66, 0.72 },
		-- Spec azonosító szerint. Amit a karakter nem ismer, az nem jelenik meg.
		-- Az icons a rotációs sor. Ahol nincs, ott a játék saját spec listája adja.
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

	-- Midnight: fej, váll, mell, láb (spellthread), csizma, gyűrűk, fegyverek.
	enchantSlots = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [11] = true, [12] = true, [16] = true, [17] = true },

	consumables = {
		x = 1942, y = 1284, size = 40, gap = 3,
		-- Sorrend és darabszám kategóriánként. A subclass az Enum.ItemConsumableSubclass értéke.
		groups = {
			{ subclass = 3, count = 2 }, -- flask, phial
			{ subclass = 1, count = 3 }, -- poti
			{ subclass = 5, count = 1 }, -- étel
			{ subclass = 6, count = 1 }, -- olaj, fegyverkő
		},
		extraItems = { 5512, 224464 }, -- healthstone
	},

	details = {
		right = 2548, bottom = 1588, w = 300, h = 230, gap = 6,
		barHeight = 26, fontSize = 18, skin = 'ElvUI Frame Style',
	},

	chat = { x = 12, bottom = 1588, w = 614, h = 300, fontSize = 15 },

	bossmods = {
		normal = { x = 1860, y = 760, w = 320, h = 24 },
		huge = { x = 1100, y = 620, w = 360, h = 28 },
		gap = 3, fontSize = 16,
	},

	minimap = { x = 2290, y = 8, size = 260, buttonSize = 22, buttonGap = 3 },

	tracker = { height = 580, textSize = 12 },
	fps = { y = 6 },

	actionbars = { font = 15, hotkeyFont = 13 },

	-- Blizzard elemek az Edit Mode layoutjában.
	-- { rendszer, alindex, a keret melyik pontja, x, y }, x és y valódi képpont a bal felső saroktól.
	layout = {
		name = 'SlimARK-UI',
		healName = 'SlimARK-UI Heal',
		bars = { size = 48, padding = 2, bottom = 1578, center = 1280 },
		-- Az első három bekapcsolt bar alul középen, alulról felfelé. A többi a chat fölé kerül.
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
		systems = {
			{ 'ActionBar', 'StanceBar', 'BOTTOMRIGHT', 960, 1578 },
			{ 'ActionBar', 'PetActionBar', 'BOTTOMLEFT', 1600, 1578 },
			{ 'ActionBar', 'PossessActionBar', 'BOTTOM', 1280, 1420 },
			{ 'Minimap', nil, 'TOPRIGHT', 2550, 8 },
			{ 'MicroMenu', nil, 'TOPLEFT', 12, 10 },
			{ 'Bags', nil, 'BOTTOMRIGHT', 2548, 1324 },
			{ 'HudTooltip', nil, 'BOTTOMRIGHT', 2548, 1276 },
			{ 'ObjectiveTracker', nil, 'TOPRIGHT', 2548, 330 },
			{ 'ChatFrame', nil, 'BOTTOMLEFT', 12, 1588 },
			{ 'TalkingHeadFrame', nil, 'TOP', 1280, 100 },
			{ 'TimerBars', nil, 'TOP', 1280, 40 },
			{ 'EncounterBar', nil, 'TOP', 1280, 200 },
			{ 'ExtraAbilities', nil, 'BOTTOM', 960, 1150 },
			{ 'VehicleLeaveButton', nil, 'BOTTOM', 780, 1150 },
			{ 'LootFrame', nil, 'TOPLEFT', 640, 300 },
			{ 'DurabilityFrame', nil, 'TOPRIGHT', 2280, 170 },
			{ 'VehicleSeatIndicator', nil, 'TOPRIGHT', 1900, 170 },
			{ 'ArchaeologyBar', nil, 'BOTTOM', 1280, 1040 },
			{ 'PersonalResourceDisplay', nil, 'BOTTOM', 1280, 1000 },
			{ 'LossOfControl', nil, 'CENTER', 1280, 560 },
			{ 'RaidWarning', nil, 'TOP', 1280, 250 },
			{ 'CooldownViewer', 'Essential', 'BOTTOM', 1280, 1336 },
			{ 'CooldownViewer', 'Utility', 'BOTTOM', 1280, 1378 },
			{ 'CooldownViewer', 'BuffIcon', 'BOTTOM', 1280, 1420 },
			{ 'CooldownViewer', 'BuffBar', 'BOTTOM', 1280, 1092 },
			{ 'AuraFrame', 'ExternalDefensivesFrame', 'TOPRIGHT', 2170, 170 },
			{ 'CastBar', nil, 'BOTTOM', 1280, 1000 },
		},
		-- A gyógyító layout ugyanez, csak ezek az elemek állnak máshol.
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
