local _, ns = ...
local C = ns.C
local cfg = C.tooltip

-- The flat SlimARK tooltip: a dark plate with a black edge and our font, the class, reaction or
-- item quality color as a thin stripe on top, a thin health bar under it. Players get their
-- Mythic+ rating, item level and target. It works only while a tooltip is being filled: no timer,
-- and the item level asks the game once per player out of combat and keeps the answer 10 minutes.

local TIPS = { 'GameTooltip', 'ItemRefTooltip', 'ShoppingTooltip1', 'ShoppingTooltip2', 'ItemRefShoppingTooltip1', 'ItemRefShoppingTooltip2' }
local BG = { 0.055, 0.059, 0.075, 0.93 }
local LABEL = { 0.62, 0.6, 0.56 }
local GUILD = { 0.25, 1, 0.25 }
local CACHE_TIME = 600

local styled = {}
local barColor

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

-- One physical pixel in the tooltip's own units.
local function Pixel(tip)
	return ns.Scale() / ns.Fit() / tip:GetScale()
end

local function Style(tip)
	if not tip or styled[tip] or (tip.IsForbidden and tip:IsForbidden()) then return end
	local s = {}
	styled[tip] = s
	local px = Pixel(tip)
	s.bg = tip:CreateTexture(nil, 'BACKGROUND', nil, -7)
	s.bg:SetAllPoints()
	s.bg:SetColorTexture(BG[1], BG[2], BG[3], BG[4])
	s.edge = tip:CreateTexture(nil, 'BACKGROUND', nil, -8)
	s.edge:SetColorTexture(0, 0, 0, 1)
	s.edge:SetPoint('TOPLEFT', -px, px)
	s.edge:SetPoint('BOTTOMRIGHT', px, -px)
	s.stripe = tip:CreateTexture(nil, 'ARTWORK')
	s.stripe:SetPoint('TOPLEFT')
	s.stripe:SetPoint('TOPRIGHT')
	s.stripe:SetHeight(2 * px)
	s.stripe:Hide()
	if tip.NineSlice then tip.NineSlice:SetAlpha(0) end
	tip:HookScript('OnTooltipCleared', function() s.stripe:Hide() end)
end

local function Stripe(tip, r, g, b)
	local s = styled[tip]
	if not s then return end
	s.stripe:SetColorTexture(r, g, b, 1)
	s.stripe:Show()
end
ns.TooltipStripe = Stripe

local function StyleFonts()
	for _, name in ipairs({ 'GameTooltipHeaderText', 'GameTooltipText', 'GameTooltipTextSmall' }) do
		local font = _G[name]
		if font then
			local _, size = font:GetFont()
			font:SetFont(ns.FONT, size or 12, '')
			font:SetShadowOffset(1, -1)
			font:SetShadowColor(0, 0, 0, 1)
		end
	end
end

-- The health bar: thin, flat, right under the tooltip, in the unit's color.
local function StyleBar()
	local bar = GameTooltip.StatusBar or _G.GameTooltipStatusBar
	if not bar then return end
	local px = Pixel(GameTooltip)
	bar:SetStatusBarTexture(ns.TEX)
	bar:ClearAllPoints()
	bar:SetPoint('TOPLEFT', GameTooltip, 'BOTTOMLEFT', 0, -2 * px)
	bar:SetPoint('TOPRIGHT', GameTooltip, 'BOTTOMRIGHT', 0, -2 * px)
	bar:SetHeight(3 * px)
	local back = bar:CreateTexture(nil, 'BACKGROUND', nil, -8)
	back:SetColorTexture(0, 0, 0, 1)
	back:SetPoint('TOPLEFT', -px, px)
	back:SetPoint('BOTTOMRIGHT', px, -px)
	-- Blizzard paints it green on every change; the unit's color goes back on after it.
	bar:HookScript('OnValueChanged', function(self)
		if barColor then self:SetStatusBarColor(barColor[1], barColor[2], barColor[3]) end
	end)
end

------------------------------------------------------------------------
-- Player lines: Mythic+ rating, item level, target.
------------------------------------------------------------------------
local inspected = {} -- guid -> { ilvl, spec, time }
local waitingGUID
local lastRequest = 0

local function ClassColor(unit)
	local _, class = UnitClass(unit)
	if not Readable(class) then return nil end
	local color = RAID_CLASS_COLORS[class]
	return color and { color.r, color.g, color.b }
end

local function ItemLevelText(entry)
	local text = tostring(math.floor(entry.ilvl + 0.5))
	if entry.spec then text = text .. '  ' .. entry.spec end
	return text
end

local function AddItemLevel(tip, entry)
	tip:AddDoubleLine('Item level', ItemLevelText(entry), LABEL[1], LABEL[2], LABEL[3], 1, 1, 1)
end

local function RequestInspect(unit, guid)
	if InspectFrame and InspectFrame:IsShown() then return end
	if not CanInspect(unit) or GetTime() - lastRequest < 1.5 then return end
	lastRequest = GetTime()
	waitingGUID = guid
	NotifyInspect(unit)
end

-- Our own answer, or one another addon asked for (Raider.IO inspects in the background) while
-- the same player is under the mouse.
-- A unit's GUID can be secret (in dungeons and raids); a secret one counts as unknown.
local function ReadableGUID(unit)
	local guid = UnitGUID(unit)
	if Readable(guid) then return guid end
end

local function OnInspect(_, guid)
	if not Readable(guid) then return end
	local unit = ReadableGUID('mouseover') == guid and 'mouseover' or nil
	if guid ~= waitingGUID and not unit then return end
	if guid == waitingGUID then waitingGUID = nil end
	if not unit then return end
	-- The tooltip already has the line when the answer was still remembered.
	local known = inspected[guid]
	local hasLine = known and GetTime() - known.time < CACHE_TIME
	local ilvl = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel and C_PaperDollInfo.GetInspectItemLevel(unit)
	if not Readable(ilvl) or ilvl <= 0 then return end
	-- The C_SpecializationInfo functions are there in every client; the old globals are deprecated
	-- fallbacks that WoW Forever does not load at all.
	local specID = C_SpecializationInfo.GetInspectSpecialization(unit)
	-- Blizzard checks for GetSpecializationInfoByID before using it too (UnitFrameUtil.lua).
	local spec = Readable(specID) and specID > 0 and GetSpecializationInfoByID
		and select(2, GetSpecializationInfoByID(specID)) or nil
	local entry = { ilvl = ilvl, spec = spec, time = GetTime() }
	inspected[guid] = entry
	if not hasLine and GameTooltip:IsShown() then
		local _, shown = GameTooltip:GetUnit()
		if Readable(shown) and ReadableGUID(shown) == guid then
			AddItemLevel(GameTooltip, entry)
			GameTooltip:Show()
		end
	end
end

local function PlayerLines(tip, unit)
	-- Raider.IO shows the rating with its own details; ours would say it twice.
	local score
	if not C_AddOns.IsAddOnLoaded('RaiderIO') and C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
		local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
		score = summary and summary.currentSeasonScore
	end
	if Readable(score) and type(score) == 'number' and score > 0 then
		local color = C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score)
		local r, g, b = 1, 1, 1
		if color then r, g, b = color:GetRGB() end
		tip:AddDoubleLine('Mythic+ rating', tostring(score), LABEL[1], LABEL[2], LABEL[3], r, g, b)
	end

	local guid = UnitGUID(unit)
	if UnitIsUnit(unit, 'player') then
		local _, equipped = GetAverageItemLevel()
		local specIndex = C_SpecializationInfo.GetSpecialization()
		local spec = specIndex and specIndex > 0 and select(2, C_SpecializationInfo.GetSpecializationInfo(specIndex)) or nil
		AddItemLevel(tip, { ilvl = equipped, spec = spec })
	elseif Readable(guid) then
		local entry = inspected[guid]
		if entry and GetTime() - entry.time < CACHE_TIME then
			AddItemLevel(tip, entry)
		else
			RequestInspect(unit, guid)
		end
	end

	local target = unit .. 'target'
	if UnitExists(target) then
		local name = UnitName(target)
		if Readable(name) then
			local color = UnitIsPlayer(target) and ClassColor(target) or { 1, 1, 1 }
			if UnitIsUnit(target, 'player') then name = '>> you <<' end
			tip:AddDoubleLine('Target', name, LABEL[1], LABEL[2], LABEL[3], color[1], color[2], color[3])
		end
	end
end

local function OnUnit(tip)
	if tip ~= GameTooltip then return end
	local _, unit = tip:GetUnit()
	if not Readable(unit) then return end
	local color
	if UnitIsPlayer(unit) then
		color = ClassColor(unit)
		if color then GameTooltipTextLeft1:SetTextColor(color[1], color[2], color[3]) end
		local guild = GetGuildInfo(unit)
		local line = GameTooltipTextLeft2
		local text = line and line:GetText()
		if Readable(guild) and Readable(text) and text:find(guild, 1, true) then
			line:SetTextColor(GUILD[1], GUILD[2], GUILD[3])
		end
		if not InCombatLockdown() then PlayerLines(tip, unit) end
	else
		local reaction = UnitReaction(unit, 'player')
		local c = Readable(reaction) and FACTION_BAR_COLORS[reaction]
		if c then color = { c.r, c.g, c.b } end
	end
	barColor = color
	if color then
		Stripe(tip, color[1], color[2], color[3])
		local bar = tip.StatusBar or _G.GameTooltipStatusBar
		if bar then bar:SetStatusBarColor(color[1], color[2], color[3]) end
	end
end

local function QualityColor(quality)
	if ColorManager and ColorManager.GetColorDataForItemQuality then
		local c = ColorManager.GetColorDataForItemQuality(quality)
		if c then return c.r, c.g, c.b end
	end
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if c then return c.r, c.g, c.b end
end

local function OnItem(tip)
	if not styled[tip] or not tip.GetItem then return end
	local _, link = tip:GetItem()
	if not Readable(link) then return end
	local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
	if not quality or quality < 1 then return end
	local r, g, b = QualityColor(quality)
	if r then Stripe(tip, r, g, b) end
end

------------------------------------------------------------------------
-- Where the tooltip appears.
------------------------------------------------------------------------
local function Anchor(tip, parent)
	if tip ~= GameTooltip or (tip.IsForbidden and tip:IsForbidden()) then return end
	if cfg.anchor == 'cursor' then
		tip:SetOwner(parent, 'ANCHOR_CURSOR_RIGHT', 24, 8)
		return
	end
	-- Fixed: its bottom right corner over the bags and consumables row, above the Details windows,
	-- so it covers neither the Details title bar nor the bag buttons.
	local x = ns.FitX(C.details.right, 'RIGHT')
	local y = ns.FitY(C.consumables.y - 8)
	local scale = ns.Scale() / tip:GetScale()
	tip:ClearAllPoints()
	tip:SetPoint('BOTTOMRIGHT', UIParent, 'TOPLEFT', x * scale, -y * scale)
end
ns.AnchorTooltip = Anchor

ns.On('PLAYER_LOGIN', function()
	if not C.modules.tooltip then return end
	for _, name in ipairs(TIPS) do Style(_G[name]) end
	StyleFonts()
	StyleBar()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
	end
	if GameTooltip_SetDefaultAnchor then hooksecurefunc('GameTooltip_SetDefaultAnchor', Anchor) end
	ns.On('INSPECT_READY', OnInspect)
end)

------------------------------------------------------------------------
-- 3.0 extras (33, 42). Each has its own switch and works with the flat skin above on or off; a
-- switch that is off hooks nothing. Everything is read while the tooltip is being filled.
------------------------------------------------------------------------
local extra = C.tooltipExtras
local KNOWN_RED = { 0.9, 0.3, 0.3 }

-- 33: the upgrade track in place of Blizzard's "Upgrade Level" line, with the crests to max.
-- When a value cannot be read, Blizzard's own line stays.
local function OnUpgradeLine(tip)
	if (tip.IsForbidden and tip:IsForbidden()) or not tip.GetProcessingTooltipInfo then return end
	local info = tip:GetProcessingTooltipInfo()
	local data = info and info.tooltipData
	if not data then return end
	local link
	if Readable(data.guid) and data.guid ~= '' and C_Item.GetItemLinkByGUID then
		link = C_Item.GetItemLinkByGUID(data.guid)
	elseif Readable(data.hyperlink) then
		link = data.hyperlink
	end
	local up = ns.UpgradeTrack and ns.UpgradeTrack(link)
	if not up then return end
	local right
	if up.left == 0 then
		right = 'max'
	elseif up.crests then
		right = ('%d left · %d %s'):format(up.left, up.crests, up.crest)
	else
		right = up.left .. ' left'
	end
	tip:AddDoubleLine(('Upgrade: %s %d/%d'):format(up.track, up.rank, up.max), right, 1, 1, 1, LABEL[1], LABEL[2], LABEL[3])
	return true
end

-- 42: a mount, toy or pet item you already have. Blizzard says so itself for some; then not twice.
local function IsKnown(id)
	if C_MountJournal and C_MountJournal.GetMountFromItem then
		local mountID = C_MountJournal.GetMountFromItem(id)
		if Readable(mountID) and mountID and mountID > 0 then
			return select(11, C_MountJournal.GetMountInfoByID(mountID)) == true
		end
	end
	if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(id) then
		return PlayerHasToy and PlayerHasToy(id) == true or false
	end
	if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
		local species = select(13, C_PetJournal.GetPetInfoByItemID(id))
		if Readable(species) and species then
			local owned = C_PetJournal.GetNumCollectedInfo(species)
			return Readable(owned) and (owned or 0) > 0
		end
	end
	return false
end

local function SaysKnown(data)
	local known = ITEM_SPELL_KNOWN
	if not known then return false end
	for _, line in ipairs(data.lines or {}) do
		if Readable(line.leftText) and line.leftText == known then return true end
	end
	return false
end

local function OnItemExtras(tip, data)
	if tip ~= GameTooltip and tip ~= ItemRefTooltip then return end
	local id = data and data.id
	if not Readable(id) or type(id) ~= 'number' then return end
	if extra.ids then
		local spellID
		if C_Item.GetItemSpell then spellID = select(2, C_Item.GetItemSpell(id)) end
		local spell = Readable(spellID) and spellID or '-'
		tip:AddDoubleLine('Spell ID / Item ID', spell .. ' / ' .. id, LABEL[1], LABEL[2], LABEL[3], 1, 1, 1)
	end
	if extra.bagCount and C_Item.GetItemCount then
		local count = C_Item.GetItemCount(id)
		if Readable(count) and count > 0 then
			tip:AddDoubleLine('In bags', tostring(count), LABEL[1], LABEL[2], LABEL[3], 1, 1, 1)
		end
	end
	if extra.known and IsKnown(id) and not SaysKnown(data) then
		tip:AddLine(ITEM_SPELL_KNOWN or 'Already known', KNOWN_RED[1], KNOWN_RED[2], KNOWN_RED[3])
	end
end

-- Spells and auras. An aura's spell ID is secret in combat; then there is no line.
local function OnSpellExtras(tip, data)
	if tip ~= GameTooltip and tip ~= ItemRefTooltip then return end
	local id = data and data.id
	if not Readable(id) or type(id) ~= 'number' then return end
	tip:AddDoubleLine('Spell ID', tostring(id), LABEL[1], LABEL[2], LABEL[3], 1, 1, 1)
end

-- 42: the mount a player rides, from the mount aura. Auras are not read in combat or while the game
-- keeps them secret (a running key, boss fights, PvP).
local function MountName(unit)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_MountJournal and C_MountJournal.GetMountFromSpell) then return end
	for i = 1, 40 do
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, 'HELPFUL')
		if not ok or not aura then return end
		local spellID = aura.spellId
		if Readable(spellID) then
			local mountID = C_MountJournal.GetMountFromSpell(spellID)
			if Readable(mountID) and mountID and mountID > 0 then
				local name = C_MountJournal.GetMountInfoByID(mountID)
				if Readable(name) and name then return name end
			end
		end
	end
end

local function OnUnitExtras(tip)
	if tip ~= GameTooltip or InCombatLockdown() then return end
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end
	local _, unit = tip:GetUnit()
	if not Readable(unit) or not unit or not UnitIsPlayer(unit) then return end
	local name = MountName(unit)
	if name then tip:AddDoubleLine('Mount', name, LABEL[1], LABEL[2], LABEL[3], 1, 1, 1) end
end

ns.On('PLAYER_LOGIN', function()
	local P = TooltipDataProcessor
	local types = Enum.TooltipDataType or {}
	if P and P.AddLinePreCall and extra.upgrade and not ns.isForever then
		P.AddLinePreCall(Enum.TooltipDataLineType.ItemUpgradeLevel, OnUpgradeLine)
	end
	-- A tooltip type an older client lacks is skipped.
	local function Post(kind, fn)
		if P and P.AddTooltipPostCall and kind then P.AddTooltipPostCall(kind, fn) end
	end
	if extra.ids or extra.bagCount or extra.known then Post(types.Item, OnItemExtras) end
	if extra.ids then
		Post(types.Spell, OnSpellExtras)
		Post(types.UnitAura, OnSpellExtras)
	end
	if extra.mount then Post(types.Unit, OnUnitExtras) end
	-- 42: no tooltip in combat; one already open goes when the fight starts.
	if extra.hideCombat then
		GameTooltip:HookScript('OnShow', function(self)
			if InCombatLockdown() then self:Hide() end
		end)
		ns.On('PLAYER_REGEN_DISABLED', function() GameTooltip:Hide() end)
	end
end)
