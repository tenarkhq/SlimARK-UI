local _, ns = ...
local C = ns.C

-- 3.0 (37): item level and bind marks on Blizzard's item icons in the bags, the bank, at the
-- merchant and in the loot window. Gear only (weapons and armor): the item level bottom left, BoE
-- (binds when equipped) or WB (warbound) top right. With BetterBags loaded the bags and the bank
-- are left to it, it shows its own marks. The marks are set when Blizzard fills a button; nothing
-- runs in between.

local BOE = { 0.62, 0.82, 1 }
local WARBOUND = { 1, 0.85, 0.29 }

local marks = setmetatable({}, { __mode = 'k' })
local lootOwner = {}

local function Parts(button)
	local m = marks[button]
	if m then return m end
	m = {}
	m.level = ns.Text(button, 12)
	m.level:SetPoint('BOTTOMLEFT', 2, 2)
	m.bind = ns.Text(button, 10, 'RIGHT')
	m.bind:SetPoint('TOPRIGHT', -2, -2)
	marks[button] = m
	return m
end

local NOT_GEAR = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true }

-- The item level and the bind mark of an item link. bound: this copy is bound already (an item
-- you carry); then only a warbound item keeps its mark.
local function Describe(link, bound)
	if issecretvalue(link) or not link or not Enum.ItemClass or not Enum.ItemBind then return nil end
	local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
	if classID ~= Enum.ItemClass.Weapon and classID ~= Enum.ItemClass.Armor then return nil end
	local _, _, quality, _, _, _, _, _, equipLoc, _, _, _, _, bindType = C_Item.GetItemInfo(link)
	-- Item data not loaded yet: Blizzard fills the button again once it is.
	if not equipLoc or equipLoc == '' or NOT_GEAR[equipLoc] or quality == Enum.ItemQuality.Poor then return nil end
	local level = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
	local bind = Enum.ItemBind
	local mark
	if bindType == bind.ToWoWAccount or bindType == bind.ToBnetAccount then
		mark = 'WB'
	elseif not bound then
		-- Warbound until equipped reads as binds when equipped; the game tells it apart.
		if bindType == bind.ToBnetAccountUntilEquipped
			or (bindType == bind.OnEquip and C_Item.IsItemBindToAccountUntilEquip and C_Item.IsItemBindToAccountUntilEquip(link)) then
			mark = 'WB'
		elseif bindType == bind.OnEquip then
			mark = 'BoE'
		end
	end
	return level, mark
end
ns.BagMarkInfo = Describe

local function Mark(button, link, bound)
	if not button then return end
	local level, mark = Describe(link, bound)
	local m = marks[button]
	if not level and not mark then
		if m then m.level:SetText('') m.bind:SetText('') end
		return
	end
	m = m or Parts(button)
	local f = C.features
	m.level:SetText((f.bagItemLevel and level and level > 1) and level or '')
	m.bind:SetText(f.bagBind and mark or '')
	local color = mark == 'WB' and WARBOUND or BOE
	m.bind:SetTextColor(color[1], color[2], color[3])
end

------------------------------------------------------------------------
-- Bags and bank.
------------------------------------------------------------------------
local function MarkBagSlot(button, bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	Mark(button, info and info.hyperlink, info and info.isBound)
end

local function MarkContainer(frame)
	for _, button in frame:EnumerateValidItems() do
		MarkBagSlot(button, button:GetBagID(), button:GetID())
	end
end
ns.MarkContainer = MarkContainer

local function MarkBank(panel)
	for button in panel:EnumerateValidItems() do
		MarkBagSlot(button, button:GetBankTabID(), button:GetContainerSlotID())
	end
end
ns.MarkBank = MarkBank

local function HookBags()
	local frames = { ContainerFrameCombinedBags }
	for i = 1, NUM_CONTAINER_FRAMES or 13 do frames[#frames + 1] = _G['ContainerFrame' .. i] end
	for _, frame in pairs(frames) do
		if frame and frame.UpdateItems and frame.EnumerateValidItems then hooksecurefunc(frame, 'UpdateItems', MarkContainer) end
	end
	local bank = BankPanel
	if bank and bank.EnumerateValidItems then
		if bank.GenerateItemSlotsForSelectedTab then hooksecurefunc(bank, 'GenerateItemSlotsForSelectedTab', MarkBank) end
		if bank.RefreshAllItemsForSelectedTab then hooksecurefunc(bank, 'RefreshAllItemsForSelectedTab', MarkBank) end
	end
end

------------------------------------------------------------------------
-- Merchant (with the vendor module's extra slots) and loot.
------------------------------------------------------------------------
local function MarkMerchant()
	if not MerchantFrame then return end
	local buyback = MerchantFrame.selectedTab ~= 1
	for i = 1, 20 do
		local button = _G['MerchantItem' .. i .. 'ItemButton']
		if not button then break end
		local link, bound
		if button:IsShown() then
			local index = button:GetID()
			if buyback then
				-- What you sold may be bound: the buyback list says so.
				link = GetBuybackItemLink(index)
				bound = link ~= nil and select(7, GetBuybackItemInfo(index)) ~= false
			elseif button.hasItem then
				link = GetMerchantItemLink(index)
			end
		end
		Mark(button, link, bound)
	end
end

local function MarkLoot(_, frame, data)
	local button = frame and frame.Item
	if not button then return end
	local slot = data and data.slotIndex
	Mark(button, slot and GetLootSlotLink(slot), false)
end
ns.MarkLoot = MarkLoot

ns.On('PLAYER_LOGIN', function()
	local f = C.features
	if not (f.bagItemLevel or f.bagBind) then return end
	if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('BetterBags')) then HookBags() end
	if MerchantFrame_UpdateMerchantInfo then
		hooksecurefunc('MerchantFrame_UpdateMerchantInfo', MarkMerchant)
		-- The vendor module draws its pages itself as well.
		ns.MarkMerchant = MarkMerchant
	end
	if MerchantFrame_UpdateBuybackInfo then hooksecurefunc('MerchantFrame_UpdateBuybackInfo', MarkMerchant) end
	if MerchantFrame_UpdateItemQualityBorders then hooksecurefunc('MerchantFrame_UpdateItemQualityBorders', MarkMerchant) end
	if LootFrame and LootFrame.ScrollBox and ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
		ScrollUtil.AddInitializedFrameCallback(LootFrame.ScrollBox, MarkLoot, lootOwner, false)
	end
end)
