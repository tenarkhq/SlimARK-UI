local _, ns = ...
local C = ns.C

local LEFT = { Head = 1, Neck = 2, Shoulder = 3, Back = 15, Chest = 5, Shirt = 4, Tabard = 19, Wrist = 9 }
local RIGHT = { Hands = 10, Waist = 6, Legs = 7, Feet = 8, Finger0 = 11, Finger1 = 12, Trinket0 = 13, Trinket1 = 14 }
local BOTTOM = { MainHand = 16, SecondaryHand = 17 }

local overlays = {}

local function Overlay(button, side)
	local o = overlays[button]
	if o then return o end
	o = { gems = {} }

	o.Level = ns.Text(button, 15, 'CENTER')
	o.Level:SetFont(ns.FONT, 15, 'OUTLINE')
	o.Level:SetPoint('BOTTOM', 0, 2)

	local info = CreateFrame('Frame', nil, button)
	info:SetSize(150, 36)
	if side == 'left' then
		info:SetPoint('LEFT', button, 'RIGHT', 6, 0)
	elseif side == 'right' then
		info:SetPoint('RIGHT', button, 'LEFT', -6, 0)
	else
		info:SetPoint('BOTTOM', button, 'TOP', 0, 4)
	end
	local justify = side == 'right' and 'RIGHT' or (side == 'left' and 'LEFT' or 'CENTER')
	o.Enchant = ns.Text(info, 12, justify)
	o.Enchant:SetPoint('TOPLEFT')
	o.Enchant:SetPoint('TOPRIGHT')

	for i = 1, 3 do
		local gem = info:CreateTexture(nil, 'OVERLAY')
		gem:SetSize(15, 15)
		local step = (i - 1) * 17
		if side == 'right' then
			gem:SetPoint('BOTTOMRIGHT', -step, 2)
		elseif side == 'left' then
			gem:SetPoint('BOTTOMLEFT', step, 2)
		else
			gem:SetPoint('BOTTOM', (i - 2) * 17, 2)
		end
		o.gems[i] = gem
	end
	o.Info = info
	overlays[button] = o
	return o
end

local function ReadItem(slot)
	local result = { gems = {}, empty = 0 }
	local data = C_TooltipInfo.GetInventoryItem('player', slot)
	if not data or not data.lines then return result end
	local types = Enum.TooltipDataLineType
	for _, line in ipairs(data.lines) do
		if line.type == types.ItemEnchantmentPermanent then
			result.enchant = (line.leftText or ''):gsub('^[^:]+:%s*', '')
		elseif line.type == types.GemSocket then
			if line.gemIcon then
				table.insert(result.gems, line.gemIcon)
			else
				result.empty = result.empty + 1
			end
		end
	end
	return result
end

local function Update(button, side, slot)
	local o = Overlay(button, side)
	local link = GetInventoryItemLink('player', slot)

	o.Level:SetText('')
	o.Enchant:SetText('')
	for _, gem in ipairs(o.gems) do gem:Hide() end
	if not link then return end

	local level = C_Item.GetDetailedItemLevelInfo(link)
	if level then
		o.Level:SetText(level)
		local quality = C_Item.GetItemQualityByID(link)
		local color = quality and ITEM_QUALITY_COLORS[quality]
		if color then o.Level:SetTextColor(color.r, color.g, color.b) end
	end

	local item = ReadItem(slot)

	if item.enchant then
		o.Enchant:SetText(item.enchant)
		o.Enchant:SetTextColor(0.3, 1, 0.3)
	elseif C.enchantSlots[slot] then
		local isWeaponSlot = slot == 16 or slot == 17
		local classID = select(6, C_Item.GetItemInfoInstant(link))
		if not isWeaponSlot or classID == Enum.ItemClass.Weapon then
			o.Enchant:SetText('No enchant')
			o.Enchant:SetTextColor(1, 0.25, 0.25)
		end
	end

	local i = 0
	for _, icon in ipairs(item.gems) do
		i = i + 1
		if o.gems[i] then
			o.gems[i]:SetTexture(icon)
			o.gems[i]:SetVertexColor(1, 1, 1)
			o.gems[i]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			o.gems[i]:Show()
		end
	end
	for _ = 1, item.empty do
		i = i + 1
		if o.gems[i] then
			o.gems[i]:SetColorTexture(1, 0.15, 0.15, 1)
			o.gems[i]:Show()
		end
	end
end

local slots = {}

ns.On('PLAYER_LOGIN', function()
	local function collect(list, side)
		for name, id in pairs(list) do
			local button = _G['Character' .. name .. 'Slot']
			if button then slots[button] = { side = side, id = id } end
		end
	end
	collect(LEFT, 'left')
	collect(RIGHT, 'right')
	collect(BOTTOM, 'bottom')

	hooksecurefunc('PaperDollItemSlotButton_Update', function(button)
		-- Only while the character sheet is open: it updates every slot again when shown.
		local s = slots[button]
		if s and CharacterFrame and CharacterFrame:IsShown() then Update(button, s.side, s.id) end
	end)
end)
