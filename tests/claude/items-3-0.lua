-- 3.0 part D, item items: bag marks (37), fast loot (38), guild repair and stack buy (39), the low
-- supplies line (40). Run from the repository root:
--   lua5.1 tests/claude/items-3-0.lua
local H = dofile('tests/claude/lib/helpers.lua')

local world

local function Secret(value)
	H.secret = H.secret or {}
	H.secret[value] = true
	return value
end

local function HasEvent(event)
	for _, f in ipairs(H.frames) do
		if f._events[event] and f._scripts.OnEvent then return true end
	end
	return false
end

local function Printed(pattern)
	for _, line in ipairs(H.prints) do
		if line:find(pattern, 1, true) then return line end
	end
end

------------------------------------------------------------------------
-- (37) Bag marks.
------------------------------------------------------------------------
local function ItemButton(name, bag, slot)
	local b = H.NewFrame('ItemButton', name, UIParent)
	b._bag, b._slot = bag, slot
	function b:GetBagID() return self._bag end
	function b:GetBankTabID() return self._bag end
	function b:GetContainerSlotID() return self._slot end
	b:SetID(slot)
	return b
end

local function BootBags(features, betterBags)
	local ns = H.setup()
	world = { items = {}, slots = {}, betterBags = betterBags or false, merchant = {}, loot = {} }
	local class, bind = Enum.ItemClass, Enum.ItemBind
	world.WEAPON, world.ARMOR, world.CONSUMABLE = class.Weapon, class.Armor, class.Consumable
	world.BOE, world.BOP, world.ACCOUNT, world.WUE = bind.OnEquip, bind.OnAcquire, bind.ToBnetAccount, bind.ToBnetAccountUntilEquipped
	world.POOR, world.EPIC = Enum.ItemQuality.Poor, 4
	C_AddOns.IsAddOnLoaded = function(name) return name == 'BetterBags' and world.betterBags end
	_G.C_Item = {
		GetItemInfoInstant = function(link)
			local item = world.items[link]
			if item then return 1, nil, nil, nil, nil, item.class end
		end,
		GetItemInfo = function(link)
			local item = world.items[link]
			if not item or item.uncached then return nil end
			return 'Item', link, item.quality or 4, item.level, 1, nil, nil, 1, item.loc or 'INVTYPE_LEGS', 1, 1, item.class, 0, item.bind
		end,
		GetDetailedItemLevelInfo = function(link) local item = world.items[link] return item and item.level end,
		IsItemBindToAccountUntilEquip = function(link) local item = world.items[link] return item and item.wue == true end,
	}
	_G.C_Container = {
		GetContainerItemInfo = function(bag, slot)
			local s = world.slots[bag .. ':' .. slot]
			return s and { hyperlink = s.link, isBound = s.bound }
		end,
	}
	-- Bags: one container with three slots.
	local bag = H.NewFrame('Frame', 'ContainerFrame1', UIParent)
	world.bagButtons = { ItemButton(nil, 0, 1), ItemButton(nil, 0, 2), ItemButton(nil, 0, 3) }
	function bag:UpdateItems() end
	function bag:EnumerateValidItems()
		local i = 0
		return function()
			i = i + 1
			if world.bagButtons[i] then return i, world.bagButtons[i] end
		end
	end
	_G.NUM_CONTAINER_FRAMES = 1
	-- The bank: a pool of buttons.
	_G.BankPanel = H.NewFrame('Frame', 'BankPanel', UIParent)
	world.bankButtons = { ItemButton(nil, 6, 1) }
	function BankPanel:GenerateItemSlotsForSelectedTab() end
	function BankPanel:RefreshAllItemsForSelectedTab() end
	function BankPanel:EnumerateValidItems()
		local active = {}
		for _, b in ipairs(world.bankButtons) do active[b] = true end
		return pairs(active)
	end
	-- Merchant and loot.
	_G.MerchantFrame = H.NewFrame('Frame', 'MerchantFrame', UIParent)
	MerchantFrame.selectedTab = 1
	world.merchantButtons = { ItemButton('MerchantItem1ItemButton', 0, 1), ItemButton('MerchantItem2ItemButton', 0, 2) }
	_G.MerchantFrame_UpdateMerchantInfo = function() end
	_G.MerchantFrame_UpdateBuybackInfo = function() end
	_G.GetMerchantItemLink = function(index) return world.merchant[index] end
	_G.GetBuybackItemLink = function(index) return world.merchant[index] end
	_G.GetBuybackItemInfo = function(index) return 'Item', 1, 100, 1, 1, true, world.buybackBound and world.buybackBound[index] end
	_G.LootFrame = H.NewFrame('Frame', 'LootFrame', UIParent)
	LootFrame.ScrollBox = H.NewFrame('Frame', nil, LootFrame)
	_G.ScrollUtil = { AddInitializedFrameCallback = function(box, fn, owner) world.lootCallback = { box, fn, owner } end }
	_G.GetLootSlotLink = function(slot) return world.loot[slot] end
	H.load('Config.lua')
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	H.load('Core.lua')
	H.load('Bags.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

-- The item level and the bind text on a button, '' or nil when there is none.
local function MarksOf(button)
	local level, bind
	for _, f in ipairs(H.frames) do
		if f._parent == button and f._kind == 'FontString' then
			local point = H.calls(f, 'SetPoint')[1]
			if point and point[1] == 'BOTTOMLEFT' then level = f:GetText() end
			if point and point[1] == 'TOPRIGHT' then bind = f:GetText() end
		end
	end
	return level, bind
end

do
	-- Off: nothing is hooked.
	BootBags({ bagItemLevel = false, bagBind = false })
	world.items.legs = { class = world.ARMOR, level = 684, bind = world.BOE }
	world.slots['0:1'] = { link = 'legs', bound = false }
	ContainerFrame1:UpdateItems()
	H.equal(MarksOf(world.bagButtons[1]), nil, '37 off: no marks')
	H.equal(world.lootCallback, nil, '37 off: the loot list is not watched')
end

do
	BootBags()
	world.items.legs = { class = world.ARMOR, level = 684, bind = world.BOE }
	world.items.ring = { class = world.ARMOR, level = 671, bind = world.ACCOUNT }
	world.items.potion = { class = world.CONSUMABLE, level = 1, bind = world.BOE }
	world.items.cloak = { class = world.ARMOR, level = 650, bind = world.BOE, wue = true }
	world.slots['0:1'] = { link = 'legs', bound = false }
	world.slots['0:2'] = { link = 'ring', bound = true }
	world.slots['0:3'] = { link = 'potion', bound = false }
	ContainerFrame1:UpdateItems()
	local level, bind = MarksOf(world.bagButtons[1])
	H.check(level == 684 and bind == 'BoE', '37 an unbound BoE item shows its item level and BoE')
	level, bind = MarksOf(world.bagButtons[2])
	H.check(level == 671 and bind == 'WB', '37 a warbound item shows WB')
	H.equal(MarksOf(world.bagButtons[3]), nil, '37 no mark on a consumable')

	-- Bound now: the BoE mark goes, the item level stays.
	world.slots['0:1'].bound = true
	ContainerFrame1:UpdateItems()
	level, bind = MarksOf(world.bagButtons[1])
	H.check(level == 684 and bind == '', '37 a bound item keeps only its item level')

	-- Warbound until equipped reads as BoE in the item data.
	world.slots['0:1'] = { link = 'cloak', bound = false }
	ContainerFrame1:UpdateItems()
	level, bind = MarksOf(world.bagButtons[1])
	H.equal(bind, 'WB', '37 warbound until equipped shows WB')

	-- An emptied slot loses its marks; uncached item data shows nothing yet.
	world.slots['0:1'] = nil
	ContainerFrame1:UpdateItems()
	level, bind = MarksOf(world.bagButtons[1])
	H.check(level == '' and bind == '', '37 an empty slot is cleared')
	world.items.legs.uncached = true
	world.slots['0:1'] = { link = 'legs', bound = false }
	ContainerFrame1:UpdateItems()
	level = MarksOf(world.bagButtons[1])
	H.equal(level, '', '37 item data not loaded: no guess')
	world.items.legs.uncached = nil

	-- A secret link is not read.
	world.slots['0:1'] = { link = Secret('legs2'), bound = false }
	ContainerFrame1:UpdateItems()
	H.equal((MarksOf(world.bagButtons[1])), '', '37 a secret link is not read')

	-- The bank.
	world.slots['6:1'] = { link = 'legs', bound = false }
	BankPanel:GenerateItemSlotsForSelectedTab()
	level, bind = MarksOf(world.bankButtons[1])
	H.check(level == 684 and bind == 'BoE', '37 bank items get the marks')

	-- The merchant: what it sells is not yours, so BoE shows; the buyback tab shows only WB.
	world.merchant = { 'legs', 'ring' }
	for _, b in ipairs(world.merchantButtons) do b.hasItem = true end
	MerchantFrame_UpdateMerchantInfo()
	level, bind = MarksOf(world.merchantButtons[1])
	H.check(level == 684 and bind == 'BoE', '37 merchant items get the marks')
	MerchantFrame.selectedTab = 2
	world.buybackBound = { true, true }
	MerchantFrame_UpdateBuybackInfo()
	level, bind = MarksOf(world.merchantButtons[1])
	H.check(level == 684 and bind == '', '37 a bound item sold back does not claim BoE')
	H.equal(select(2, MarksOf(world.merchantButtons[2])), 'WB', '37 warbound keeps WB')
	world.buybackBound = { false }
	MerchantFrame_UpdateBuybackInfo()
	H.equal(select(2, MarksOf(world.merchantButtons[1])), 'BoE', '37 an unbound BoE sold back shows BoE')

	-- Loot.
	world.loot = { 'ring' }
	local frame = H.NewFrame('Frame', nil, LootFrame)
	frame.Item = H.NewFrame('ItemButton', nil, frame)
	local cb = world.lootCallback
	H.check(cb and cb[1] == LootFrame.ScrollBox, '37 the loot list is watched')
	cb[2](cb[3], frame, { slotIndex = 1 })
	level, bind = MarksOf(frame.Item)
	H.check(level == 671 and bind == 'WB', '37 loot icons get the marks')
end

do
	-- Only the bind marks: no item level.
	BootBags({ bagItemLevel = false })
	world.items.legs = { class = world.ARMOR, level = 684, bind = world.BOE }
	world.slots['0:1'] = { link = 'legs', bound = false }
	ContainerFrame1:UpdateItems()
	local level, bind = MarksOf(world.bagButtons[1])
	H.check(level == '' and bind == 'BoE', '37 the item level has its own switch')
end

do
	-- BetterBags shows its own: the bags and the bank are left to it, merchant and loot are not.
	BootBags(nil, true)
	world.items.legs = { class = world.ARMOR, level = 684, bind = world.BOE }
	world.slots['0:1'] = { link = 'legs', bound = false }
	world.slots['6:1'] = { link = 'legs', bound = false }
	ContainerFrame1:UpdateItems()
	BankPanel:GenerateItemSlotsForSelectedTab()
	H.equal(MarksOf(world.bagButtons[1]), nil, '37 with BetterBags: no marks on Blizzard\'s bags')
	H.equal(MarksOf(world.bankButtons[1]), nil, '37 with BetterBags: none on the bank')
	world.merchant = { 'legs' }
	world.merchantButtons[1].hasItem = true
	MerchantFrame_UpdateMerchantInfo()
	H.equal((MarksOf(world.merchantButtons[1])), 684, '37 with BetterBags: the merchant still gets them')
end

------------------------------------------------------------------------
-- (38) Fast loot.
------------------------------------------------------------------------
local function BootLoot(features)
	local ns = H.setup()
	world = { autoLoot = true, modifier = false, loot = {}, looted = {} }
	_G.C_CVar = { GetCVarBool = function(name) return name == 'autoLootDefault' and world.autoLoot end }
	_G.IsModifiedClick = function(action) return action == 'AUTOLOOTTOGGLE' and world.modifier end
	_G.GetNumLootItems = function() return #world.loot end
	_G.GetLootSlotInfo = function(slot) local s = world.loot[slot] return 1, 'Item', 1, nil, 2, s.locked end
	_G.LootSlot = function(slot) table.insert(world.looted, slot) end
	H.load('Config.lua')
	ns.C.modules.loot = false
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	H.load('Core.lua')
	H.load('Loot.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

do
	BootLoot({ fastLoot = false })
	H.equal(HasEvent('LOOT_READY'), false, '38 off: the loot event is not listened to')
end

do
	BootLoot()
	world.loot = { {}, { locked = true }, {} }
	H.fire('LOOT_READY', true)
	H.equal(table.concat(world.looted, ','), '3,1', '38 every free slot is taken at once')

	world.looted, world.modifier = {}, true
	H.fire('LOOT_READY', false)
	H.equal(#world.looted, 0, '38 the modifier held turns auto loot off: nothing taken')

	world.autoLoot = false
	H.fire('LOOT_READY', true)
	H.equal(#world.looted, 2, '38 auto loot off but the modifier held: taken')

	world.looted, world.modifier = {}, false
	H.fire('LOOT_READY', false)
	H.equal(#world.looted, 0, '38 auto loot off: the game\'s window stays')
end

------------------------------------------------------------------------
-- (39) Guild repair and stack buy.
------------------------------------------------------------------------
local function Slot(name)
	local slot = H.NewFrame('Frame', name, MerchantFrame)
	local button = H.NewFrame('Button', name .. 'ItemButton', slot)
	button.IconQuestTexture = H.NewFrame('Texture', nil, button)
	for _, part in ipairs({ 'Name', 'MoneyFrame', 'AltCurrencyFrame', 'NameFrame' }) do
		H.NewFrame('Frame', name .. part, slot)
	end
	return slot
end

local function BootVendor(features, modules)
	local ns = H.setup()
	world = { money = 100000, cost = 500, repairs = {}, guild = true, limit = -1, bank = 0, guildWorks = true, bought = {} }
	_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
	_G.C_Container = { GetContainerNumSlots = function() return 0 end, GetBagSlotFlag = function() return false end }
	_G.C_MerchantFrame = { IsSellAllJunkEnabled = function() return true end, GetNumJunkItems = function() return 0 end,
		SellAllJunkItems = function() end }
	_G.GetMoney = function() return world.money end
	_G.GetMoneyString = function(copper) return copper .. 'c' end
	_G.CanMerchantRepair = function() return true end
	_G.GetRepairAllCost = function() return world.cost, world.cost > 0 end
	_G.RepairAllItems = function(guild)
		table.insert(world.repairs, guild and 'guild' or 'own')
		if not guild or world.guildWorks then world.cost = 0 end
	end
	_G.CanGuildBankRepair = function() return world.guild end
	_G.GetGuildBankWithdrawMoney = function() return world.limit end
	_G.GetGuildBankMoney = function() return world.bank end
	_G.MerchantFrame = H.NewFrame('Frame', 'MerchantFrame', UIParent)
	MerchantFrame.selectedTab, MerchantFrame.page = 1, 1
	for i = 1, 12 do Slot('MerchantItem' .. i) end
	_G.MerchantFrameBottomLeftBorder = H.NewFrame('Frame', 'MerchantFrameBottomLeftBorder', MerchantFrame)
	_G.MerchantNextPageButton = H.NewFrame('Button', 'MerchantNextPageButton', MerchantFrame)
	_G.MerchantPrevPageButton = H.NewFrame('Button', 'MerchantPrevPageButton', MerchantFrame)
	local createFrame = CreateFrame
	_G.CreateFrame = function(kind, name, parent, template)
		if template == 'MerchantItemTemplate' then return Slot(name) end
		return createFrame(kind, name, parent, template)
	end
	_G.MerchantFrame_UpdateMerchantInfo = function() end
	_G.MerchantFrame_UpdateBuybackInfo = function() end
	_G.MerchantFrame_UpdateItemQualityBorders = function() end
	world.original = function() end
	_G.MerchantItemButton_OnModifiedClick = world.original
	_G.StackSplitFrame = H.NewFrame('Frame', 'StackSplitFrame', UIParent)
	StackSplitFrame:Hide()
	H.load('Config.lua')
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	for key, value in pairs(modules or {}) do ns.C.modules[key] = value end
	H.load('Core.lua')
	H.load('Vendor.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

do
	BootVendor()
	H.fire('MERCHANT_SHOW')
	H.equal(world.repairs[1], 'guild', '39 the guild bank pays when the guild allows it')
	H.equal(Printed('Repaired with guild gold'), nil, '39 the message waits for the answer')
	H.runTimers(1)
	H.check(Printed('Repaired with guild gold: 500c') ~= nil, '39 then says the guild paid')
	H.equal(#world.repairs, 1, '39 your own gold is not touched')
end

do
	-- The guild bank could not pay after all: your own gold pays what is left.
	BootVendor()
	world.guildWorks = false
	H.fire('MERCHANT_SHOW')
	MerchantFrame:Show()
	H.runTimers(1)
	H.equal(table.concat(world.repairs, ','), 'guild,own', '39 a refused guild repair falls back to your gold')
	H.check(Printed('Repaired: 500c') ~= nil, '39 and says so')
end

do
	-- Not allowed, over today's limit, not enough in the bank, or switched off: your own gold.
	BootVendor()
	world.guild = false
	H.fire('MERCHANT_SHOW')
	H.equal(world.repairs[1], 'own', '39 no guild repair right: your own gold')
	BootVendor()
	world.limit = 100
	H.fire('MERCHANT_SHOW')
	H.equal(world.repairs[1], 'own', '39 over the daily guild limit: your own gold')
	BootVendor()
	world.bank = 200
	H.fire('MERCHANT_SHOW')
	H.equal(world.repairs[1], 'own', '39 a guild bank with too little gold: your own gold')
	BootVendor({ guildRepair = false })
	H.fire('MERCHANT_SHOW')
	H.equal(world.repairs[1], 'own', '39 guild repair off: your own gold')
end

do
	-- Shift-click buys a full stack in place of the how-many window.
	BootVendor()
	local button = MerchantItem1ItemButton
	button.SplitStack = function(_, amount) table.insert(world.bought, amount) end
	StackSplitFrame:Show()
	StackSplitFrame.owner, StackSplitFrame.maxStack, StackSplitFrame.minSplit = button, 200, 1
	MerchantItemButton_OnModifiedClick(button, 'LeftButton')
	H.equal(world.bought[1], 200, '39 a full stack is bought')
	H.equal(StackSplitFrame:IsShown(), false, '39 the how-many window closes')

	-- Sold in fives: whole fives only.
	StackSplitFrame:Show()
	StackSplitFrame.maxStack, StackSplitFrame.minSplit = 13, 5
	MerchantItemButton_OnModifiedClick(button, 'LeftButton')
	H.equal(world.bought[2], 10, '39 an item sold in fives buys whole fives')

	-- The window was not opened for this button (a chat link, another button): nothing bought.
	StackSplitFrame:Hide()
	MerchantItemButton_OnModifiedClick(button, 'LeftButton')
	StackSplitFrame:Show()
	StackSplitFrame.owner = MerchantItem2ItemButton
	MerchantItemButton_OnModifiedClick(button, 'LeftButton')
	H.equal(#world.bought, 2, '39 nothing bought when the how-many window is not this item\'s')

	-- The buyback tab is left alone.
	MerchantFrame.selectedTab = 2
	StackSplitFrame.owner = button
	MerchantItemButton_OnModifiedClick(button, 'LeftButton')
	H.equal(#world.bought, 2, '39 not on the buyback tab')
end

do
	BootVendor({ stackBuy = false })
	H.check(MerchantItemButton_OnModifiedClick == world.original, '39 stack buy off: Blizzard\'s click is not hooked')

	-- The vendor page's module off: no repair of any kind, no stack buy.
	BootVendor(nil, { vendor = false })
	H.fire('MERCHANT_SHOW')
	H.runTimers(1)
	H.equal(#world.repairs, 0, '39 vendor module off: no repair')
	H.check(MerchantItemButton_OnModifiedClick == world.original, '39 vendor module off: no stack buy')
end

------------------------------------------------------------------------
-- (40) The low supplies line.
------------------------------------------------------------------------
local function BootSupplies(features)
	local ns = H.setup()
	world = { bag = {}, instance = { 'Ara-Kara', 'party', 1, 'Mythic', 5, 0, false, 2660 } }
	local consumable = Enum.ItemClass.Consumable
	_G.GetLocale = function() return 'enUS' end
	_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
	_G.C_Container = {
		GetContainerNumSlots = function() return #world.bag end,
		GetContainerItemInfo = function(_, slot) local item = world.bag[slot] return item and { itemID = item.id, iconFileID = 1 } end,
	}
	_G.C_Item = {
		GetItemInfoInstant = function(id)
			for _, item in ipairs(world.bag) do
				if item.id == id then return id, nil, nil, nil, nil, consumable, item.subclass end
			end
		end,
		GetItemInfo = function(id)
			for _, item in ipairs(world.bag) do
				if item.id == id then return 'Item', nil, 1, 1, 1, nil, nil, 20, '', 1, 1, consumable, item.subclass, 0, item.expansion end
			end
		end,
		GetItemCount = function(id)
			for _, item in ipairs(world.bag) do if item.id == id then return item.count end end
			return 0
		end,
	}
	_G.C_TooltipInfo = { GetBagItem = function() return { lines = {} } end }
	_G.GetInstanceInfo = function() return unpack(world.instance) end
	H.load('Config.lua')
	ns.C.modules.consumables = false
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	H.load('Core.lua')
	H.load('Consumables.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

local function SuppliesLines()
	local n = 0
	for _, line in ipairs(H.prints) do if line:find('Low on supplies', 1, true) then n = n + 1 end end
	return n
end

do
	BootSupplies({ lowSupplies = false })
	H.equal(HasEvent('PLAYER_ENTERING_WORLD'), false, '40 off: entering the world is not listened to')
end

do
	BootSupplies()
	world.bag = {
		{ id = 1, subclass = 1, count = 3, expansion = 11 },   -- current potions
		{ id = 2, subclass = 1, count = 20, expansion = 10 },  -- old potions do not count
		{ id = 3, subclass = 5, count = 10, expansion = 11 },  -- food
	}
	H.fire('PLAYER_ENTERING_WORLD', false, false)
	H.equal(SuppliesLines(), 0, '40 the bags are read a moment later')
	H.runTimers(3)
	H.check(Printed('Low on supplies: 3 potions.') ~= nil, '40 fewer than 5 current potions: one chat line')
	H.equal(SuppliesLines(), 1, '40 one line, food is fine')

	-- A reload or a new loading screen in the same dungeon: no second line.
	H.fire('PLAYER_ENTERING_WORLD', false, true)
	H.fire('PLAYER_ENTERING_WORLD', false, false)
	H.runTimers(3)
	H.equal(SuppliesLines(), 1, '40 not again in the same dungeon')

	-- Out and in again: a new entry.
	world.instance = { 'Dornogal', 'none' }
	H.fire('PLAYER_ENTERING_WORLD', false, false)
	world.instance = { 'Ara-Kara', 'party', 1, 'Mythic', 5, 0, false, 2660 }
	world.bag[1].count = 8
	world.bag[3].count = 2
	H.fire('PLAYER_ENTERING_WORLD', false, false)
	H.runTimers(3)
	H.check(Printed('Low on supplies: 2 food.') ~= nil, '40 a new entry tells again (only what is low)')

	-- Enough of both: nothing; a raid is not a dungeon.
	BootSupplies()
	world.bag = { { id = 1, subclass = 1, count = 5, expansion = 11 }, { id = 3, subclass = 5, count = 5, expansion = 11 } }
	H.fire('PLAYER_ENTERING_WORLD', true, false)
	H.runTimers(3)
	H.equal(SuppliesLines(), 0, '40 five of each: no line')
	BootSupplies()
	world.instance = { 'Raid', 'raid', 14, 'Normal', 20, 0, false, 9000 }
	H.fire('PLAYER_ENTERING_WORLD', false, false)
	H.runTimers(3)
	H.equal(SuppliesLines(), 0, '40 not in a raid')
end

H.done()
