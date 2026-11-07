-- Minden pozíció és méret itt van, valódi képpontban, a 2560x1600-as kép bal felső sarkától.
-- A Blizzard elemek helyét és méretét a /slim apply ebből számolja ki az aktuális UI scale-hez.
local _, ns = ...

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
		player = { x = 720, y = 1160, w = 340, h = 66, font = 20, classPower = 12 },
		target = { x = 1500, y = 1160, w = 340, h = 66, font = 20 },
		targettarget = { x = 1500, y = 1255, w = 170, h = 27, font = 16 },
		pet = { x = 720, y = 1255, w = 170, h = 27, font = 16 },
		focus = { x = 1500, y = 1050, w = 260, h = 38, font = 18 },
		boss = { x = 1920, y = 430, w = 270, h = 50, gap = 8, font = 16 },
		party = { x = 12, y = 860, w = 230, h = 50, gap = 6, debuff = 24, font = 18 },
		raid = { x = 12, y = 760, w = 112, h = 48, gap = 3, debuff = 18, font = 15 },
	},

	auras = {
		buffs = { right = 2280, y = 12, size = 40, width = 700, height = 86, max = 32 },
		debuffs = { right = 2280, y = 104, size = 52, width = 400, height = 56, max = 8 },
		targetDebuffSize = 38,
	},

	plate = { w = 200, h = 18, casterH = 24, castH = 16, debuff = 24, font = 15, targeterFont = 13, holdTime = 1.5, dimAlpha = 0.6, arrowW = 11, arrowH = 16, arrowGap = 4 },

	cooldowns = {
		x = 1100, y = 1100, w = 360, rowH = 22, gap = 3, font = 16,
		iconY = 1228, iconSize = 46, iconGap = 3,
		PALADIN = {
			-- A keskeny countdown sávok. Több ID esetén az első ismert spell él.
			bars = {
				{ ids = { 31884 }, color = { 0.89, 0.70, 0.24 } }, -- Avenging Wrath
				{ ids = { 96231 }, color = { 0.84, 0.42, 0.23 } }, -- Rebuke
				{ ids = { 633 }, color = { 0.50, 0.82, 0.91 } }, -- Lay on Hands
				{ ids = { 642 }, color = { 0.95, 0.88, 0.54 } }, -- Divine Shield
				{ ids = { 1044 }, color = { 0.44, 0.80, 0.55 } }, -- Blessing of Freedom
			},
			-- A rotációs ikonsor. Amit nem ismersz, az nem jelenik meg.
			icons = { 255937, 184575, 20271, 24275, 375576, 343721, 343527 },
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
		cooldownIcons = { Essential = 46, Utility = 36, BuffIcon = 36 },
	},
}
