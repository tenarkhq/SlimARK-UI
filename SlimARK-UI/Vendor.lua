local _, ns = ...
local C = ns.C

local PER_PAGE = C.vendor.perPage
local ownedCache = {}
-- The owned check of an item whose data is not loaded yet: kept until item data arrives, so the
-- vendor's many redraws do not read the same tooltips again and again.
local ownedGuess = {}
local visible = {}
local slotIndex = {} -- slot -> merchant index shown in it
local hiddenCount = 0
local slot11Point, slot12Point

-- The junk the game's own Sell All Junk sells: grey items with a sell value, outside the bags
-- excluded from it in the bag menu (Blizzard's ContainerFrame marks junk the same way).
local function JunkItems()
	local list = {}
	local flags = Enum.BagSlotFlags
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4 do
		local excluded = flags and C_Container.GetBagSlotFlag and C_Container.GetBagSlotFlag(bag, flags.ExcludeJunkSell)
		if not excluded then
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				local info = C_Container.GetContainerItemInfo(bag, slot)
				if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
					local price = select(11, C_Item.GetItemInfo(info.itemID))
					table.insert(list, { bag = bag, slot = slot, id = info.itemID,
						value = price and price * (info.stackCount or 1) or nil })
				end
			end
		end
	end
	return list
end

-- Sells the junk with the game's own Sell All Junk. The junk is noted before the sale, so the
-- report is about these items only, not about every change of your gold in the meantime.
local function SellJunk()
	if not C.features.autoSellJunk or not C_MerchantFrame or not C_MerchantFrame.SellAllJunkItems then return end
	if not C_MerchantFrame.IsSellAllJunkEnabled() then return end
	if C_MerchantFrame.GetNumJunkItems() <= 0 then return end
	local junk = JunkItems()
	C_MerchantFrame.SellAllJunkItems()
	return junk
end

-- Once the sale has arrived: the noted items gone from their slot were sold, the gold is their
-- sell value. Without the value of every one of them only the count is told.
local function ReportJunk(junk)
	local sold, gold, known = 0, 0, true
	for _, item in ipairs(junk) do
		local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
		if not info or info.itemID ~= item.id then
			sold = sold + 1
			if item.value then gold = gold + item.value else known = false end
		end
	end
	if sold == 0 then return end
	local items = sold == 1 and '1 item' or sold .. ' items'
	if known and gold > 0 then
		ns.Print('Sold junk: ' .. items .. ', ' .. GetMoneyString(gold, true))
	else
		ns.Print('Sold junk: ' .. items)
	end
end

-- Autorepair at every NPC with a hammer.
local function Repair()
	if not C.features.autoRepair or not CanMerchantRepair() then return 0 end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost <= 0 then return 0 end
	if GetMoney() >= cost then
		RepairAllItems()
		ns.Print('Repaired: ' .. GetMoneyString(cost, true))
		return cost
	end
	ns.Print('Not enough gold to repair: ' .. GetMoneyString(cost, true))
	return 0
end

ns.On('MERCHANT_SHOW', function()
	-- With the vendor module off the vendor is left alone: no sale, no repair, no two pages.
	if not C.modules.vendor then return end
	wipe(ownedCache)
	wipe(ownedGuess)
	C_Timer.After(0.5, function()
		if MerchantFrame:IsShown() then MerchantFrame.update = true end
	end)
	-- Junk first: its gold can pay for the repair.
	local junk = SellJunk()
	Repair()
	if junk then
		C_Timer.After(1.5, function() ReportJunk(junk) end)
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
	if ownedGuess[itemID] ~= nil then return ownedGuess[itemID] end

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
	else
		ownedGuess[itemID] = owned
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
	-- The page number stays in the middle of the wider frame; Next goes to the right edge,
	-- mirroring Prev, instead of staying where the narrow frame had it, over the number.
	MerchantNextPageButton:ClearAllPoints()
	if wide then
		MerchantNextPageButton:SetPoint('CENTER', MerchantFrame, 'BOTTOMRIGHT', -26, 96)
	else
		MerchantNextPageButton:SetPoint('CENTER', MerchantFrame, 'BOTTOMLEFT', 310, 96)
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

	wipe(slotIndex)
	for i = 1, PER_PAGE do
		local index = visible[(page - 1) * PER_PAGE + i]
		if index then
			FillSlot(i, index)
			slotIndex[i] = index
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

-- Item data arrived (GET_ITEM_INFO_RECEIVED): Blizzard has just painted the quality borders of
-- its own ten slots, so ours are painted again at once; the button IDs are not touched. The
-- full list, whose owned checks may change with the new data, is redrawn once on the next frame
-- however many items arrived in this one.
local renderQueued = false
local function OnItemData()
	if MerchantFrame.selectedTab ~= 1 then return end
	for i, index in pairs(slotIndex) do
		MerchantFrameItem_UpdateQuality(_G['MerchantItem' .. i], GetMerchantItemLink(index))
	end
	wipe(ownedGuess)
	if renderQueued then return end
	renderQueued = true
	C_Timer.After(0, function()
		renderQueued = false
		if MerchantFrame:IsShown() then Render() end
	end)
end

local function Restore()
	wipe(slotIndex)
	SetWide(false)
	MerchantItem11:ClearAllPoints()
	MerchantItem11:SetPoint(unpack(slot11Point))
	MerchantItem12:ClearAllPoints()
	MerchantItem12:SetPoint(unpack(slot12Point))
	ns.vendorNote:SetText('')
end

ns.On('PLAYER_LOGIN', function()
	if not C.modules.vendor then return end
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
	hooksecurefunc('MerchantFrame_UpdateItemQualityBorders', OnItemData)
end)
