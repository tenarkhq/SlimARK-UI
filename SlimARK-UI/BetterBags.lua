local _, ns = ...

-- BetterBags skin: a SlimARK theme for both of its windows, the classic bags
-- (Sonata) and BetterBags Next (SonataNext). Flat dark panels with a black
-- one-pixel edge, the SlimARK font, gold accent, cropped item icons with a black
-- border, no glow, shimmer or bounce. /slimark apply selects it; it can be changed
-- back in BetterBags' own theme menu at any time.
local THEME = 'SlimARK'
local GOLD = { 0.95, 0.72, 0.29, 1 }
local BLACK = { 0, 0, 0, 1 }
local BODY = { 0.06, 0.063, 0.075, 0.94 }
local CARD = { 0.1, 0.105, 0.122, 1 }
local TRACK = { 0.137, 0.145, 0.169, 1 }
local HOVER = { 1, 1, 1, 0.15 }
-- The SlimARK font covers Latin alphabets; other locales keep the client's font.
local LATIN = { 'enUS', 'enGB', 'deDE', 'frFR', 'esES', 'esMX', 'itIT', 'ptBR' }

local function BetterBags()
	if not LibStub then return nil end
	local aceAddon = LibStub('AceAddon-3.0', true)
	return aceAddon and aceAddon:GetAddon('BetterBags', true)
end

local function Module(addon, name)
	local ok, module = pcall(addon.GetModule, addon, name, true)
	return ok and module or nil
end

-- The classic bags.
local BACKDROP = {
	BgFile = 'Interface\\Buttons\\WHITE8X8',
	EdgeFile = 'Interface\\Buttons\\WHITE8X8',
	EdgeSize = 1,
	Color = BODY,
	BorderColor = BLACK,
	Opacity = false,
}
local TITLE = {
	Font = { Path = ns.FONT, Size = 15, Flags = 'OUTLINE', Color = GOLD },
	Points = { { Point = 'TOP', X = 0, Y = -8 } },
	Height = 22,
}
local CLOSE = {
	Template = 'UIPanelCloseButtonNoScripts',
	Size = 24,
	Points = { { Point = 'TOPRIGHT', X = -2, Y = -2 } },
}

local function Titled(noClose)
	return { Backdrop = BACKDROP, Title = TITLE, CloseButton = not noClose and CLOSE or nil }
end

local function ClassicTheme()
	local bag = Titled()
	bag.Layout = {
		Search = {
			Points = {
				{ Point = 'TOPLEFT', X = 10, Y = -36 },
				{ Point = 'BOTTOMRIGHT', RelativePoint = 'TOPRIGHT', X = -10, Y = -56 },
			},
		},
		MenuButton = { Points = { { Point = 'TOPLEFT', X = 4, Y = -4 } } },
	}
	local flat = { Color = CARD }
	local edge = { Color = BLACK, EdgeSize = 1 }
	return {
		Name = THEME,
		DisplayName = 'SlimARK',
		Description = 'Flat dark SlimARK-UI look with black edges and the SlimARK font.',
		Masque = false,
		Windows = {
			Bag = bag,
			Panel = Titled(),
			Flat = Titled(),
			Dialog = Titled(true),
			Slots = { Backdrop = BACKDROP },
			Search = { Backdrop = BACKDROP },
		},
		Elements = {
			ItemButton = {
				Icon = { Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } },
				Highlight = { Color = HOVER, BlendMode = 'ADD', Inset = { Left = 1, Right = 1, Top = 1, Bottom = 1 } },
				Pushed = { Color = HOVER, BlendMode = 'ADD', Inset = { Left = 1, Right = 1, Top = 1, Bottom = 1 } },
				Backdrop = { Color = TRACK, BorderColor = BLACK, EdgeSize = 1 },
				QualityBorder = 'Backdrop',
				-- Common items keep the black edge, better ones show their quality color.
				QualityColors = { [1] = BLACK },
			},
			Tab = {
				Art = 'Flat',
				Background = flat,
				Border = edge,
				TextOffset = { X = 0, Y = 0 },
				SelectedTextOffset = { X = 0, Y = 0 },
			},
			SearchBox = { Strip = true, Background = { Color = TRACK }, Border = edge },
			Button = { Strip = true, Background = flat, Border = edge, HoverBorderColor = GOLD, Highlight = false },
			EditBox = { Strip = true, Background = { Color = TRACK }, Border = edge },
		},
	}
end

-- BetterBags Next: data only, everything not named here comes from Next's Default.
local FONT_ROLES = {
	'Title', 'Section', 'SectionRecent', 'SectionFree', 'Count', 'Tab', 'TabSelected', 'Footer', 'Empty', 'DragHint',
	'ConfirmTitle', 'ConfirmWarning', 'ConfirmHint', 'Search', 'SearchText', 'Price', 'PriceUnaffordable', 'VendorName',
	'Stack', 'ControlText', 'ControlMuted', 'ControlHelp', 'Button', 'ButtonPrimary', 'ButtonDanger', 'Link', 'LinkHover',
	'MenuItem', 'MenuItemSelected', 'DialogTitle', 'DialogText', 'TopTab', 'TopTabHover', 'TopTabSelected',
	'SettingsBrand', 'SettingsNavGroup', 'SettingsNav', 'SettingsNavHover', 'SettingsNavSelected', 'SettingsVersion',
	'SettingsTitle', 'SettingsDescription', 'SettingsSection', 'SettingsSectionNote', 'SettingsLabel', 'SettingsText',
	'SettingsLink', 'CurrencyCapped', 'CurrencyNone', 'CurrencyName', 'CurrencyGain', 'CurrencyLoss', 'CurrencyMore',
}

local function NextTheme()
	local fonts = {}
	for _, role in ipairs(FONT_ROLES) do
		fonts[role] = { File = ns.FONT, Locales = LATIN }
	end
	fonts.Title.Size = 20
	fonts.SettingsTitle.Size = 20
	return {
		Name = THEME,
		DisplayName = 'SlimARK',
		Description = 'Flat dark SlimARK-UI look: black edges, the SlimARK font, no glow or bounce.',
		Palette = {
			Body = BODY,
			Wash = { 1, 1, 1, 0 },
			Gold = GOLD,
			Lavender = { 0.62, 0.64, 0.7, 1 },
			Text = { 0.95, 0.95, 0.96, 1 },
			Muted = { 0.62, 0.63, 0.67, 1 },
			Tab = { 0.08, 0.085, 0.1, 0.95 },
			TabSelected = { 0.16, 0.17, 0.2, 0.98 },
			Card = CARD,
			SearchFill = TRACK,
			SearchFillFocus = { 0.17, 0.18, 0.21, 1 },
			ButtonIcon = { 0.85, 0.86, 0.9, 1 },
			ControlFill = TRACK,
			ControlHover = { 0.17, 0.18, 0.21, 1 },
			ControlPressed = { 0.1, 0.105, 0.122, 1 },
			Track = TRACK,
		},
		Fonts = fonts,
		Layout = { Gap = 4 },
		Motion = {
			Time = { Open = 0.2, Enter = 0.25, Cascade = 0.15, Stagger = 0.015, Hover = 0.08, Toggle = 0.1, TabMarker = 0.12 },
			Ease = { Open = 'outCubic', Enter = 'outCubic' },
			Rise = 4,
		},
		Panel = {
			Feather = false,
			Wash = false,
			Edge = { Color = { 0, 0, 0, 1 }, Alpha = 1, Size = 1, Full = true },
		},
		Header = { Ribbon = false, Cloud = false, Spark = false, TitleGlow = false, Buttons = { Scale = 0.85 } },
		Sparkles = false,
		Chain = { Braid = false },
		Dock = { Halo = false },
		Currency = { Flash = false },
		ItemButton = {
			Icon = { Inset = 1, TexCoords = { 0.08, 0.92, 0.08, 0.92 } },
			Backdrop = { Color = TRACK, BorderColor = BLACK, EdgeSize = 1 },
			Highlight = { Color = HOVER },
			Pushed = { Color = { 1, 1, 1, 0.25 } },
		},
		Settings = { Edge = { Color = { 0, 0, 0, 1 }, Alpha = 1, Size = 1 } },
	}
end

-- Registered once our saved settings are loaded: BetterBags loads before us (OptionalDeps),
-- and a theme registered after BetterBags applied its saved one is applied on its own.
local registered = false
local function Register()
	if registered then return true end
	if not ns.C.modules.betterbags then return false end
	local addon = BetterBags()
	if not addon then return false end
	registered = true
	local classic, nextUI = Module(addon, 'Sonata'), Module(addon, 'SonataNext')
	if classic and classic.RegisterTheme and not (classic.GetTheme and classic:GetTheme(THEME)) then
		xpcall(function() classic:RegisterTheme(ClassicTheme()) end, geterrorhandler())
	end
	if nextUI and nextUI.RegisterTheme then
		xpcall(function() nextUI:RegisterTheme(NextTheme()) end, geterrorhandler())
	end
	return true
end
ns.On('ADDON_LOADED', function(_, name)
	if name == 'SlimARK-UI' then Register() end
end)

-- For /slimark apply (Skins.lua): selects the SlimARK theme in BetterBags' current
-- profile. Returns nil when BetterBags is not loaded.
function ns.BetterBagsProfile()
	if not Register() or not Module(BetterBags(), 'Database') then return nil end
	return false
end

function ns.ApplyBetterBags()
	local database = Module(BetterBags(), 'Database')
	if database.SetTheme then database:SetTheme(THEME) end
	if database.SetNextTheme then database:SetNextTheme(THEME) end
end
