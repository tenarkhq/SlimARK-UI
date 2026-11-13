local _, ns = ...
local C = ns.C
local cfg = C.loot

-- Loot rolls and the pop-ups (loot won, upgrades, money, achievements, new mounts, pets, toys,
-- cosmetics) in one column left of the character, in the flat SlimARK look. Blizzard's frames and
-- logic stay: the buttons roll the same way, the pop-ups stay as long and click the same way.
-- The look is set when a roll or a pop-up appears; nothing runs in between.

local BG = { 0.055, 0.059, 0.075, 0.93 }
local GOLD = { 0.95, 0.72, 0.29 }
local LABEL = { 0.7, 0.68, 0.64 }

local holder
local own = {} -- textures we made, per frame: they are never cleared

local function Px(frame)
	return ns.Scale() / ns.Fit() / frame:GetEffectiveScale() * UIParent:GetEffectiveScale()
end

local function Font(text, size, flags)
	if not text then return end
	text:SetFont(ns.FONT, size, flags or '')
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
end

-- Dark plate, black edge and a side stripe, made once per frame.
local function Plate(frame)
	local s = own[frame]
	if s then return s end
	s = {}
	own[frame] = s
	s.bg = frame:CreateTexture(nil, 'BACKGROUND', nil, -7)
	s.bg:SetAllPoints()
	s.bg:SetColorTexture(BG[1], BG[2], BG[3], BG[4])
	s.edge = frame:CreateTexture(nil, 'BACKGROUND', nil, -8)
	s.edge:SetColorTexture(0, 0, 0, 1)
	s.side = frame:CreateTexture(nil, 'ARTWORK', nil, 7)
	s.side:SetPoint('TOPLEFT')
	s.side:SetPoint('BOTTOMLEFT')
	s[s.bg], s[s.edge], s[s.side] = true, true, true
	return s
end

local function FitPlate(frame, s)
	local px = Px(frame)
	s.edge:ClearAllPoints()
	s.edge:SetPoint('TOPLEFT', -px, px)
	s.edge:SetPoint('BOTTOMRIGHT', px, -px)
	s.side:SetWidth(2 * px)
end

-- Blizzard's art on the frame itself goes; the kept textures stay.
local function ClearArt(frame, keep)
	local s = own[frame]
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType('Texture') and not (s and s[region]) and not (keep and keep[region]) then
			region:SetTexture(nil)
			region:SetAlpha(0)
		end
	end
end

local function IconBox(frame, icon, size)
	if not icon then return end
	local s = own[frame]
	icon:ClearAllPoints()
	icon:SetPoint('LEFT', frame, 'LEFT', 6, 0)
	icon:SetSize(size, size)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetAlpha(1)
	if not s.iconEdge then
		s.iconEdge = frame:CreateTexture(nil, 'BACKGROUND', nil, -6)
		s.iconEdge:SetColorTexture(0, 0, 0, 1)
		s[s.iconEdge] = true
	end
	local px = Px(frame)
	s.iconEdge:ClearAllPoints()
	s.iconEdge:SetPoint('TOPLEFT', icon, 'TOPLEFT', -px, px)
	s.iconEdge:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', px, -px)
end

local function QualityRGB(link)
	local quality = link and C_Item.GetItemQualityByID(link)
	if quality and ColorManager and ColorManager.GetColorDataForItemQuality then
		local c = ColorManager.GetColorDataForItemQuality(quality)
		if c then return { c.r, c.g, c.b } end
	end
	return GOLD
end

------------------------------------------------------------------------
-- Roll rows.
------------------------------------------------------------------------
local ROLL_BUTTONS = { 'NeedButton', 'GreedButton', 'TransmogButton', 'PassButton' }

local function StyleRollButton(frame, button)
	if not button then return end
	local s = own[button]
	local size = 30
	button:SetSize(size, size)
	if not s then
		s = {}
		own[button] = s
		s.bg = button:CreateTexture(nil, 'BACKGROUND', nil, -7)
		s.bg:SetAllPoints()
		s.bg:SetColorTexture(0.137, 0.145, 0.169, 1)
		s.edge = button:CreateTexture(nil, 'BACKGROUND', nil, -8)
		s.edge:SetColorTexture(0, 0, 0, 1)
		local px = Px(button)
		s.edge:SetPoint('TOPLEFT', -px, px)
		s.edge:SetPoint('BOTTOMRIGHT', px, -px)
		for _, get in ipairs({ 'GetNormalTexture', 'GetPushedTexture', 'GetDisabledTexture' }) do
			local t = button[get] and button[get](button)
			if t then
				t:ClearAllPoints()
				t:SetPoint('TOPLEFT', 4, -4)
				t:SetPoint('BOTTOMRIGHT', -4, 4)
			end
		end
		local hl = button:GetHighlightTexture()
		if hl then
			hl:SetColorTexture(1, 1, 1, 0.14)
			hl:SetAllPoints()
		end
	end
end

local function RollInfo(frame)
	local link = GetLootRollItemLink(frame.rollID)
	if not link then return '' end
	local parts = {}
	local _, _, _, _, _, _, _, _, equipLoc = C_Item.GetItemInfo(link)
	if equipLoc and equipLoc ~= '' and _G[equipLoc] then table.insert(parts, _G[equipLoc]) end
	local ilvl = C_Item.GetDetailedItemLevelInfo(link)
	if ilvl and ilvl > 1 then table.insert(parts, tostring(ilvl)) end
	local bop = select(5, GetLootRollItemInfo(frame.rollID))
	if bop then table.insert(parts, 'BoP') end
	return table.concat(parts, ' · ')
end

local function StyleRoll(frame)
	if not frame.rollID then return end
	local s = Plate(frame)
	frame:SetScale(ns.Scale())
	frame:SetSize(cfg.w, cfg.rowH)
	FitPlate(frame, s)
	ClearArt(frame)
	if frame.Border then frame.Border:SetAlpha(0) end

	local iconFrame = frame.IconFrame
	if iconFrame then
		local size = cfg.rowH - 10
		iconFrame:ClearAllPoints()
		iconFrame:SetPoint('LEFT', frame, 'LEFT', 6, 1)
		iconFrame:SetSize(size, size)
		local icon = iconFrame.Icon
		icon:ClearAllPoints()
		icon:SetAllPoints()
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		if iconFrame.Border then iconFrame.Border:SetAlpha(0) end
		if not s.iconEdge then
			s.iconEdge = iconFrame:CreateTexture(nil, 'BACKGROUND', nil, -8)
			s.iconEdge:SetColorTexture(0, 0, 0, 1)
			local px = Px(frame)
			s.iconEdge:SetPoint('TOPLEFT', -px, px)
			s.iconEdge:SetPoint('BOTTOMRIGHT', px, -px)
		end
		Font(iconFrame.Count, 14, 'OUTLINE')
	end

	-- Buttons in a row on the right: Need, Greed or Transmog (they share a spot), Pass.
	local pass = frame.PassButton
	if pass then
		pass:ClearAllPoints()
		pass:SetPoint('RIGHT', frame, 'RIGHT', -8, 1)
	end
	for _, key in ipairs({ 'GreedButton', 'TransmogButton' }) do
		local b = frame[key]
		if b and pass then
			b:ClearAllPoints()
			b:SetPoint('RIGHT', pass, 'LEFT', -3, 0)
		end
	end
	if frame.NeedButton and frame.GreedButton then
		frame.NeedButton:ClearAllPoints()
		frame.NeedButton:SetPoint('RIGHT', frame.GreedButton, 'LEFT', -3, 0)
	end
	for _, key in ipairs(ROLL_BUTTONS) do StyleRollButton(frame, frame[key]) end

	local name = frame.Name
	if name then
		Font(name, cfg.font)
		name:ClearAllPoints()
		name:SetPoint('TOPLEFT', iconFrame or frame, 'TOPRIGHT', 10, -2)
		name:SetPoint('RIGHT', frame.NeedButton or frame, 'LEFT', -8, 0)
		name:SetHeight(cfg.font + 4)
		name:SetJustifyH('LEFT')
		name:SetWordWrap(false)
	end
	if not s.sub then
		s.sub = frame:CreateFontString(nil, 'ARTWORK')
		Font(s.sub, cfg.font - 3)
		s.sub:SetTextColor(LABEL[1], LABEL[2], LABEL[3])
		s.sub:SetJustifyH('LEFT')
		s.sub:SetWordWrap(false)
	end
	s.sub:ClearAllPoints()
	s.sub:SetPoint('TOPLEFT', name or frame, 'BOTTOMLEFT', 0, -1)
	s.sub:SetPoint('RIGHT', name or frame, 'RIGHT', 0, 0)
	s.sub:SetText(RollInfo(frame))

	local timer = frame.Timer
	if timer then
		timer:ClearAllPoints()
		timer:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 0, 0)
		timer:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, 0)
		timer:SetHeight(3 * Px(frame))
		timer:SetStatusBarTexture(ns.TEX)
		timer:SetStatusBarColor(GOLD[1], GOLD[2], GOLD[3])
		if timer.Background then timer.Background:SetColorTexture(0, 0, 0, 0.6) end
	end
	local color = QualityRGB(GetLootRollItemLink(frame.rollID))
	s.side:SetColorTexture(color[1], color[2], color[3], 1)
end
ns.StyleLootRoll = StyleRoll

-- Rows stack upward from the bottom of the column, one row height apart.
local function PlaceRolls()
	local container = GroupLootContainer
	if not container or not container.rollFrames then return end
	for i = 1, container.maxIndex or 0 do
		local frame = container.rollFrames[i]
		if frame then
			frame:ClearAllPoints()
			frame:SetPoint('BOTTOM', holder, 'BOTTOM', 0, (i - 1) * (cfg.rowH + cfg.gap))
		end
	end
	local n = container.maxIndex or 0
	container:SetScale(ns.Scale())
	container:SetHeight(math.max(1, n * (cfg.rowH + cfg.gap)))
end

------------------------------------------------------------------------
-- Pop-ups.
------------------------------------------------------------------------
local function Row(frame, icon, kind, name, color)
	local s = Plate(frame)
	frame:SetScale(ns.Scale())
	frame:SetSize(cfg.w, cfg.rowH + 4)
	FitPlate(frame, s)
	s.side:SetColorTexture(color[1], color[2], color[3], 1)
	IconBox(frame, icon, cfg.rowH - 6)
	if kind then
		Font(kind, cfg.font - 5)
		kind:ClearAllPoints()
		kind:SetPoint('TOPLEFT', icon or frame, 'TOPRIGHT', 10, -3)
		kind:SetPoint('RIGHT', frame, 'RIGHT', -10, 0)
		kind:SetJustifyH('LEFT')
		kind:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		kind:SetWordWrap(false)
	end
	if name then
		Font(name, cfg.font)
		name:ClearAllPoints()
		name:SetPoint('TOPLEFT', kind or icon or frame, kind and 'BOTTOMLEFT' or 'TOPRIGHT', 0, -2)
		name:SetPoint('RIGHT', frame, 'RIGHT', -10, 0)
		name:SetJustifyH('LEFT')
		name:SetJustifyV('TOP')
		name:SetHeight(cfg.font + 4)
		name:SetWordWrap(false)
	end
end

local function HideAll(...)
	for i = 1, select('#', ...) do
		local t = select(i, ...)
		if t then
			if t.SetTexture then t:SetTexture(nil) end
			t:SetAlpha(0)
		end
	end
end

local function StyleAlert(frame)
	if not cfg.alerts then return end
	if frame.lootItem and frame.ItemName then
		-- Loot won
		local item = frame.lootItem
		local icon = item.Icon
		local keep = { [icon] = true }
		ClearArt(item, keep)
		-- The icon moves onto the frame on the first show; it stays kept there.
		ClearArt(frame, { [icon] = true, [frame.RollTypeIcon or icon] = true })
		HideAll(frame.glow, frame.shine)
		Row(frame, icon, frame.Label, frame.ItemName, QualityRGB(frame.hyperlink))
		icon:SetParent(frame)
		if frame.RollValue then
			Font(frame.RollValue, cfg.font - 2)
			frame.RollValue:ClearAllPoints()
			frame.RollValue:SetPoint('RIGHT', frame, 'RIGHT', -10, 0)
			if frame.RollTypeIcon then
				frame.RollTypeIcon:ClearAllPoints()
				frame.RollTypeIcon:SetPoint('RIGHT', frame.RollValue, 'LEFT', -3, 0)
				frame.RollTypeIcon:SetSize(18, 18)
			end
		end
	elseif frame.UpgradeQualityItemName then
		-- Loot upgrade
		ClearArt(frame, { [frame.Icon] = true })
		Row(frame, frame.Icon, frame.TitleText, frame.UpgradeQualityItemName, GOLD)
		HideAll(frame.BaseQualityItemName, frame.WhiteText, frame.WhiteText2)
	elseif frame.Amount and frame.Label then
		-- Money
		ClearArt(frame, { [frame.Icon] = true })
		Row(frame, frame.Icon, frame.Label, frame.Amount, GOLD)
	elseif frame.Unlocked and frame.Icon and frame.Icon.Texture then
		-- Achievement and its steps
		local icon = frame.Icon.Texture
		ClearArt(frame, { [icon] = true })
		ClearArt(frame.Icon, { [icon] = true })
		HideAll(frame.glow, frame.shine, frame.GuildBanner, frame.GuildBorder)
		icon:SetParent(frame)
		Row(frame, icon, frame.Unlocked, frame.Name, GOLD)
		if frame.Shield then
			if frame.Shield.Icon then HideAll(frame.Shield.Icon) end
			local points = frame.Shield.Points
			if points then
				Font(points, cfg.font - 2)
				points:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
				points:ClearAllPoints()
				points:SetPoint('RIGHT', frame, 'RIGHT', -10, 0)
				if frame.Name then frame.Name:SetPoint('RIGHT', points, 'LEFT', -8, 0) end
			end
		end
	elseif frame.SetUpDisplay and frame.Icon and frame.Name then
		-- New mount, pet, toy, cosmetic and the like
		ClearArt(frame, { [frame.Icon] = true })
		HideAll(frame.glow, frame.shine, frame.IconBorder, frame.IconOverlay)
		Row(frame, frame.Icon, frame.Label, frame.Name, GOLD)
	end
end
ns.StyleAlert = StyleAlert

local function PlaceBase()
	if not AlertFrame then return end
	AlertFrame:SetScale(ns.Scale())
	AlertFrame:ClearAllPoints()
	AlertFrame:SetPoint('BOTTOM', holder, 'BOTTOM', 0, 0)
	local container = GroupLootContainer
	if container then
		container:ClearAllPoints()
		container:SetPoint('BOTTOM', holder, 'BOTTOM', 0, 0)
	end
end

ns.On('PLAYER_LOGIN', function()
	if not C.modules.loot then return end
	holder = CreateFrame('Frame', 'SlimARK_LootColumn', UIParent)
	holder:SetSize(cfg.w, 200)
	ns.Register(holder, cfg.x, cfg.y, { key = 'loot' })

	local container = GroupLootContainer
	if container then
		-- Out of Blizzard's bottom frame manager, so the column decides where the rows go.
		container.ignoreFramePositionManager = true
		if container.layoutParent and container.layoutParent.RemoveManagedFrame then
			container.layoutParent:RemoveManagedFrame(container)
		end
		container:SetParent(UIParent)
		for i = 1, 4 do
			local frame = _G['GroupLootFrame' .. i]
			if frame then frame:HookScript('OnShow', StyleRoll) end
		end
		if GroupLootContainer_Update then hooksecurefunc('GroupLootContainer_Update', PlaceRolls) end
	end
	PlaceBase()
	if AlertFrame and AlertFrame.AddAlertFrame then
		hooksecurefunc(AlertFrame, 'AddAlertFrame', function(_, frame) StyleAlert(frame) end)
	end
	if AlertFrame and AlertFrame.UpdateAnchors then
		-- The base goes back under the column if something else moved it.
		hooksecurefunc(AlertFrame, 'UpdateAnchors', function()
			local _, relative = AlertFrame:GetPoint(1)
			if relative ~= holder then PlaceBase() end
		end)
	end
end)

-- 3.0 (38): faster auto loot. When the game loots on its own (auto loot on and the modifier that
-- turns it around not held, or off and the modifier held), every slot is taken at once instead of
-- one after the other. Slots that are being rolled for stay. Its own switch, apart from the module.
local function FastLoot()
	local cvar = C_CVar and C_CVar.GetCVarBool or GetCVarBool
	if not cvar or cvar('autoLootDefault') == IsModifiedClick('AUTOLOOTTOGGLE') then return end
	for slot = GetNumLootItems(), 1, -1 do
		local _, _, _, _, _, locked = GetLootSlotInfo(slot)
		if not locked then LootSlot(slot) end
	end
end
ns.FastLoot = FastLoot

ns.On('PLAYER_LOGIN', function()
	if C.features.fastLoot then ns.On('LOOT_READY', FastLoot) end
end)
