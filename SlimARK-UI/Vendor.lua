local _, ns = ...
local C = ns.C

local PER_PAGE = C.vendor.perPage
local ownedCache = {}
local visible = {}
local hiddenCount = 0
local slot11Point, slot12Point

-- Autorepair at every NPC with a hammer.
ns.On('MERCHANT_SHOW', function()
	wipe(ownedCache)
	C_Timer.After(0.5, function()
		if MerchantFrame:IsShown() then MerchantFrame.update = true end
	end)
	if not CanMerchantRepair() then return end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost <= 0 then return end
	if GetMoney() >= cost then
		RepairAllItems()
		ns.Print('Repaired: ' .. GetMoneyString(cost, true))
	else
		ns.Print('Not enough gold to repair: ' .. GetMoneyString(cost, true))
	end
end)

local function TooltipSaysOwned(index, itemID)
	local data = C_TooltipInfo.GetMerchantItem(index)
	if not data or not data.lines then return false end
	local unique = false
	for _, line in ipairs(data.lines) do
		local text = line.leftText
		if text == ITEM_SPELL_KNOWN then return true end
		if text == ITEM_UNIQUE then unique = true end
	end
	return unique and C_Item.GetItemCount(itemID, true) > 0
end

local function IsOwned(index)
	local itemID = GetMerchantItemID(index)
	if not itemID then return false end
	if ownedCache[itemID] ~= nil then return ownedCache[itemID] end

	local owned = false
	if C_Heirloom.IsItemHeirloom(itemID) and C_Heirloom.PlayerHasHeirloom(itemID) then
		owned = true
	end
	if not owned then
		local mountID = C_MountJournal.GetMountFromItem(itemID)
		if mountID then
			owned = select(11, C_MountJournal.GetMountInfoByID(mountID)) == true
		end
	end
	if not owned then
		local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
		if speciesID then
			local collected, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
			owned = collected and limit and limit > 0 and collected >= limit or false
		end
	end
	owned = owned or TooltipSaysOwned(index, itemID)

	if C_Item.IsItemDataCachedByID(itemID) then
		ownedCache[itemID] = owned
	end
	return owned
end

-- On top of the Blizzard check, it also looks at the currency and item cost.
local function CanPay(index, info)
	if GetMoney() < (info.price or 0) then return false end
	if CanAffordMerchantItem(index) == false then return false end
	for i = 1, GetMerchantItemCostInfo(index) do
		local _, needed, link, currencyName = GetMerchantItemCostItem(index, i)
		if link and needed then
			if currencyName then
				local id = C_CurrencyInfo.GetCurrencyIDFromLink(link)
				local currency = id and C_CurrencyInfo.GetCurrencyInfo(id)
				if currency and currency.quantity < needed then return false end
			elseif C_Item.GetItemCount(link, true, false, true) < needed then
				return false
			end
		end
	end
	return true
end

local function ResetSlot(i)
	local merchantButton = _G['MerchantItem' .. i]
	local itemButton = _G['MerchantItem' .. i .. 'ItemButton']
	itemButton.price = nil
	itemButton.hasItem = nil
	itemButton.name = nil
	itemButton:Hide()
	SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5)
	SetItemButtonSlotVertexColor(merchantButton, 0.4, 0.4, 0.4)
	_G['MerchantItem' .. i .. 'Name']:SetText('')
	_G['MerchantItem' .. i .. 'MoneyFrame']:Hide()
	_G['MerchantItem' .. i .. 'AltCurrencyFrame']:Hide()
end

-- Blizzard keeps this same value in its own file as a local variable.
local MONEY_WIDTH = 120

local function FillSlot(i, index)
	local itemButton = _G['MerchantItem' .. i .. 'ItemButton']
	local merchantButton = _G['MerchantItem' .. i]
	local money = _G['MerchantItem' .. i .. 'MoneyFrame']
	local alt = _G['MerchantItem' .. i .. 'AltCurrencyFrame']
	local nameText = _G['MerchantItem' .. i .. 'Name']

	local info = C_MerchantFrame.GetItemInfo(index)
	if not info then
		ResetSlot(i)
		return
	end
	if info.currencyID then
		info.name, info.texture, info.numAvailable = CurrencyContainerUtil.GetCurrencyContainerInfo(info.currencyID, info.numAvailable, info.name, info.texture, nil)
	end

	local link = GetMerchantItemLink(index)
	local canAfford = CanAffordMerchantItem(index)
	nameText:SetText(info.name)
	SetItemButtonCount(itemButton, info.stackCount)
	SetItemButtonStock(itemButton, info.numAvailable)
	SetItemButtonTexture(itemButton, info.texture)

	itemButton.name = info.name
	itemButton.link = link
	itemButton.texture = info.texture
	itemButton.extendedCost = info.hasExtendedCost and true or nil
	itemButton.price = (info.price > 0 or not info.hasExtendedCost) and info.price or nil

	if info.hasExtendedCost and info.price <= 0 then
		MerchantFrame_UpdateAltCurrency(index, i, canAfford)
		alt:ClearAllPoints()
		alt:SetPoint('BOTTOMLEFT', 'MerchantItem' .. i .. 'NameFrame', 'BOTTOMLEFT', 0, 31)
		money:Hide()
		alt:Show()
	else
		local altWidth = 0
		if info.hasExtendedCost then
			altWidth = MerchantFrame_UpdateAltCurrency(index, i, canAfford)
			alt:ClearAllPoints()
			alt:SetPoint('LEFT', money:GetName(), 'RIGHT', -14, 0)
			alt:Show()
		else
			alt:Hide()
		end
		MoneyFrame_SetMaxDisplayWidth(money, MONEY_WIDTH - altWidth)
		MoneyFrame_Update(money:GetName(), info.price)
		SetMoneyFrameColor(money:GetName(), canAfford == false and 'gray' or nil)
		money:Show()
	end

	if info.isQuestStartItem then
		itemButton.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
		itemButton.IconQuestTexture:Show()
	else
		itemButton.IconQuestTexture:Hide()
	end

	MerchantFrameItem_UpdateQuality(merchantButton, link)

	local itemID = GetMerchantItemID(index)
	local isHeirloom = itemID and C_Heirloom.IsItemHeirloom(itemID)
	itemButton.showNonrefundablePrompt = not C_MerchantFrame.IsMerchantItemRefundable(index)
	itemButton.hasItem = true
	itemButton:SetID(index)
	itemButton:Show()
	SetItemButtonDesaturated(itemButton, false)

	local red = not info.isPurchasable or (not info.isUsable and not isHeirloom) or not CanPay(index, info)
	if red then
		SetItemButtonNameFrameVertexColor(merchantButton, 1, 0, 0)
		SetItemButtonSlotVertexColor(merchantButton, 1, 0, 0)
		SetItemButtonTextureVertexColor(itemButton, 0.9, 0, 0)
		SetItemButtonNormalTextureVertexColor(itemButton, 0.9, 0, 0)
		nameText:SetTextColor(1, 0.25, 0.25)
	else
		SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5)
		SetItemButtonSlotVertexColor(merchantButton, 1, 1, 1)
		SetItemButtonTextureVertexColor(itemButton, 1, 1, 1)
		SetItemButtonNormalTextureVertexColor(itemButton, 1, 1, 1)
	end
end

local function SetWide(wide)
	local item = MerchantItem1
	local extra = 2 * (item:GetWidth() + 12)
	MerchantFrame:SetWidth(336 + (wide and extra or 0))
	MerchantFrameBottomLeftBorder:SetWidth(334 + (wide and extra or 0))
	for i = 13, PER_PAGE do
		_G['MerchantItem' .. i]:SetShown(wide)
	end
end

local function PlaceRightBlock()
	MerchantItem11:ClearAllPoints()
	MerchantItem11:SetPoint('TOPLEFT', MerchantItem2, 'TOPRIGHT', 12, 0)
	MerchantItem12:ClearAllPoints()
	MerchantItem12:SetPoint('TOPLEFT', MerchantItem11, 'TOPRIGHT', 12, 0)
	MerchantItem11:Show()
	MerchantItem12:Show()
end

local function Render()
	if MerchantFrame.selectedTab ~= 1 then return end

	wipe(visible)
	hiddenCount = 0
	for index = 1, GetMerchantNumItems() do
		if IsOwned(index) then
			hiddenCount = hiddenCount + 1
		else
			visible[#visible + 1] = index
		end
	end

	local pages = math.max(1, math.ceil(#visible / PER_PAGE))
	if MerchantFrame.page > pages then MerchantFrame.page = pages end
	local page = MerchantFrame.page

	SetWide(true)
	PlaceRightBlock()

	for i = 1, PER_PAGE do
		local index = visible[(page - 1) * PER_PAGE + i]
		if index then
			FillSlot(i, index)
		else
			ResetSlot(i)
		end
	end

	MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, page, pages)
	local paged = pages > 1
	MerchantPageText:SetShown(paged)
	MerchantPrevPageButton:SetShown(paged)
	MerchantNextPageButton:SetShown(paged)
	MerchantPrevPageButton:SetEnabled(page > 1)
	MerchantNextPageButton:SetEnabled(page < pages)

	ns.vendorNote:SetText(hiddenCount > 0 and (hiddenCount .. ' hidden, already known') or '')
end

local function Restore()
	SetWide(false)
	MerchantItem11:ClearAllPoints()
	MerchantItem11:SetPoint(unpack(slot11Point))
	MerchantItem12:ClearAllPoints()
	MerchantItem12:SetPoint(unpack(slot12Point))
	ns.vendorNote:SetText('')
end

ns.On('PLAYER_LOGIN', function()
	slot11Point = { MerchantItem11:GetPoint(1) }
	slot12Point = { MerchantItem12:GetPoint(1) }

	-- The two right-hand columns: 11-12 are Blizzard's, 13-20 are ours.
	for i = 13, PER_PAGE do
		local slot = CreateFrame('Frame', 'MerchantItem' .. i, MerchantFrame, 'MerchantItemTemplate')
		local above = i - 2
		slot:SetPoint('TOPLEFT', _G['MerchantItem' .. above], 'BOTTOMLEFT', 0, -8)
		slot:Hide()
	end

	ns.vendorNote = ns.Text(MerchantFrame, 13, 'RIGHT')
	ns.vendorNote:SetPoint('TOPRIGHT', -14, -32)
	ns.vendorNote:SetTextColor(0.75, 0.75, 0.75)

	hooksecurefunc('MerchantFrame_UpdateMerchantInfo', Render)
	hooksecurefunc('MerchantFrame_UpdateBuybackInfo', Restore)
	hooksecurefunc('MerchantFrame_UpdateItemQualityBorders', Render)
end)
