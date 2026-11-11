-- H2: the tooltip without deprecated spec globals (audit F3) and the character sheet's enchant
-- names in any language (audit F11). Run from the repository root:
--   lua5.1 tests/claude/ui-tooltip-character.lua
local H = dofile('tests/claude/lib/helpers.lua')

------------------------------------------------------------------------
-- F3: Tooltip.lua with WoW Forever's globals: GetSpecialization, GetSpecializationInfo and
-- GetInspectSpecialization do not exist, the C_SpecializationInfo functions do.
------------------------------------------------------------------------
local postCalls = {}

local function BootTooltip()
	local ns = H.setup()
	postCalls = {}
	_G.GetSpecialization, _G.GetSpecializationInfo, _G.GetInspectSpecialization = nil, nil, nil
	_G.C_SpecializationInfo = {
		GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function(index) if index == 1 then return 71, 'Arms' end end,
		GetInspectSpecialization = function(unit) return unit == 'mouseover' and 72 or 0 end,
	}
	_G.GetSpecializationInfoByID = function(id) if id == 72 then return 72, 'Fury' end end
	local tip = H.NewFrame('GameTooltip', 'GameTooltip', UIParent)
	tip.lines = {}
	tip.unit = 'player'
	function tip:AddDoubleLine(left, right) table.insert(self.lines, { left, right }) end
	function tip:AddLine(text) table.insert(self.lines, { text }) end
	function tip:GetUnit() return 'Name', self.unit end
	tip.StatusBar = H.NewFrame('StatusBar', nil, tip)
	_G.GameTooltipTextLeft1 = H.NewFrame('FontString', 'GameTooltipTextLeft1', tip)
	_G.GameTooltipTextLeft2 = H.NewFrame('FontString', 'GameTooltipTextLeft2', tip)
	_G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[kind] = fn end }
	_G.UnitIsPlayer = function() return true end
	_G.UnitClass = function() return 'Warrior', 'WARRIOR' end
	_G.RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
	_G.GetGuildInfo = function() return nil end
	_G.C_PlayerInfo = {}
	_G.UnitGUID = function(unit) return unit == 'mouseover' and 'Player-1-ABC' or 'Player-1-ME' end
	_G.UnitIsUnit = function(a, b) return a == b end
	_G.UnitExists = function() return false end
	_G.GetAverageItemLevel = function() return 701.2, 699.6 end
	_G.C_PaperDollInfo = { GetInspectItemLevel = function() return 650 end }
	_G.CanInspect = function() return true end
	_G.NotifyInspect = function() end
	H.load('Config.lua')
	H.load('Core.lua')
	H.load('Tooltip.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns, tip
end

local function Line(tip, label)
	for _, line in ipairs(tip.lines) do
		if line[1] == label then return line[2] end
	end
end

do
	local _, tip = BootTooltip()
	local onUnit = postCalls[Enum.TooltipDataType.Unit]
	H.check(onUnit ~= nil, 'F3 the tooltip unit post-call is registered')
	local ok, err = pcall(onUnit, tip)
	H.check(ok, 'F3 your own tooltip runs without the deprecated globals' .. (ok and '' or (': ' .. tostring(err))))
	H.equal(Line(tip, 'Item level'), '700  Arms', 'F3 your own item level and spec come from C_SpecializationInfo')
	H.check(#H.calls(tip.StatusBar, 'SetStatusBarColor') > 0, 'F3 the health bar gets your class color after it')

	-- The inspect answer for the player under the mouse.
	tip.lines = {}
	tip.unit = 'mouseover'
	tip:Show()
	local fired, inspectErr = pcall(H.fire, 'INSPECT_READY', 'Player-1-ABC')
	H.check(fired, 'F3 the inspect answer runs without GetInspectSpecialization' .. (fired and '' or (': ' .. tostring(inspectErr))))
	H.equal(Line(tip, 'Item level'), '650  Fury', 'F3 the inspected spec comes from C_SpecializationInfo')
end

------------------------------------------------------------------------
-- F11: the enchant name beside a slot is cut the same way in every language.
------------------------------------------------------------------------
local function Enchant(leftText)
	H.setup()
	local enchantType = Enum.TooltipDataLineType.ItemEnchantmentPermanent
	_G.CharacterFrame = H.NewFrame('Frame', 'CharacterFrame', UIParent)
	local head = H.NewFrame('Button', 'CharacterHeadSlot', CharacterFrame)
	H.NewFrame('Button', 'CharacterHandsSlot', CharacterFrame)
	_G.PaperDollItemSlotButton_Update = function() end
	_G.GetInventoryItemLink = function(_, slot) return slot == 1 and 'item:1' or nil end
	_G.C_Item = {
		GetDetailedItemLevelInfo = function() return 700 end,
		GetItemQualityByID = function() return 4 end,
		GetItemInfoInstant = function() return 1, nil, nil, nil, nil, 4 end,
	}
	_G.ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } }
	_G.C_TooltipInfo = { GetInventoryItem = function() return { lines = { { type = enchantType, leftText = leftText } } } end }
	H.load('Config.lua')
	H.load('Core.lua')
	H.load('Character.lua')
	H.fire('PLAYER_LOGIN')
	PaperDollItemSlotButton_Update(head)
	for _, f in ipairs(H.frames) do
		if f._kind == 'FontString' and f._text and f._text ~= '' and f._text ~= 700 then return f._text end
	end
end

H.equal(Enchant('Enchanted: Enchant Helm - Empowered Blessing of Speed'), 'Empowered Blessing of Speed',
	'F11 enUS: the slot before the name is cut')
H.equal(Enchant('Verzaubert: Helm verzaubern - Kraftvoller Segen der Geschwindigkeit'), 'Kraftvoller Segen der Geschwindigkeit',
	'F11 deDE: the slot before the name is cut too')
H.equal(Enchant('Enchanté : Enchantement de casque - Bénédiction de vitesse'), 'Bénédiction de vitesse',
	'F11 frFR: the label with a spaced colon and the slot are cut')
H.equal(Enchant('Enchanted: Radiant Mastery'), 'Radiant Mastery', 'F11 a name without a slot part is kept whole')

H.done()
