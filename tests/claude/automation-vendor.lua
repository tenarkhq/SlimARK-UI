-- H3: the vendor module (audit F7, F24, F26). Run from the repository root:
--   lua5.1 tests/claude/automation-vendor.lua
local H = dofile('tests/claude/lib/helpers.lua')

local world

-- A merchant slot as Blizzard's MerchantItemTemplate makes it: the slot and its named parts.
local function Slot(name)
	local slot = H.NewFrame('Frame', name, MerchantFrame)
	local button = H.NewFrame('Button', name .. 'ItemButton', slot)
	button.IconQuestTexture = H.NewFrame('Texture', nil, button)
	for _, part in ipairs({ 'Name', 'MoneyFrame', 'AltCurrencyFrame', 'NameFrame' }) do
		H.NewFrame('Frame', name .. part, slot)
	end
	return slot
end

local function Boot(modules)
	local ns = H.setup()
	world = { money = 100000, junk = {}, bags = { [0] = {} }, excluded = {}, sold = 0, repairs = 0,
		tooltips = 0, qualityPaints = 0, items = 0, cached = {}, prices = {}, buyback = {} }
	local poor = Enum.ItemQuality.Poor
	world.POOR = poor
	_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 1
	_G.C_Container = {
		GetContainerNumSlots = function(bag) return world.bags[bag] and #world.bags[bag] or 0 end,
		GetContainerItemInfo = function(bag, slot)
			local item = world.bags[bag] and world.bags[bag][slot]
			if item and item.id then
				return { itemID = item.id, quality = item.quality, hasNoValue = item.noValue or false, stackCount = item.count or 1 }
			end
		end,
		GetBagSlotFlag = function(bag) return world.excluded[bag] == true end,
	}
	_G.C_Item = {
		GetItemInfo = function(id) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, world.prices[id] end,
		IsItemDataCachedByID = function(id) return world.cached[id] == true end,
		GetItemCount = function() return 0 end,
	}
	_G.C_MerchantFrame = {
		IsSellAllJunkEnabled = function() return true end,
		GetNumJunkItems = function()
			local n = 0
			for _, items in pairs(world.bags) do
				for _, item in ipairs(items) do if item.quality == poor then n = n + 1 end end
			end
			return n
		end,
		-- The game sells the junk outside excluded bags into the buyback list (it keeps the latest
		-- 12); gold from elsewhere comes in meanwhile. saleFails: nothing is sold.
		SellAllJunkItems = function()
			world.sold = world.sold + 1
			if world.saleFails then return end
			for bag, items in pairs(world.bags) do
				if not world.excluded[bag] then
					for slot, item in ipairs(items) do
						if item.quality == poor and not item.noValue then
							local gold = (world.prices[item.id] or 0) * (item.count or 1)
							world.money = world.money + gold
							items[slot] = {}
							if not world.noBuyback then
								table.insert(world.buyback, { link = 'item:' .. item.id, price = gold, quantity = item.count or 1 })
								if #world.buyback > 12 then table.remove(world.buyback, 1) end
							end
						end
					end
				end
			end
			world.money = world.money + (world.incoming or 0)
		end,
		GetItemInfo = function(index)
			return { name = 'Item ' .. index, texture = 1, price = 100, stackCount = 1, numAvailable = -1,
				isPurchasable = true, isUsable = true, hasExtendedCost = false }
		end,
		IsMerchantItemRefundable = function() return false end,
	}
	_G.GetMoney = function() return world.money end
	_G.GetNumBuybackItems = function() return #world.buyback end
	_G.GetBuybackItemInfo = function(i)
		local e = world.buyback[i]
		if e then return 'Junk', 1, e.price, e.quantity end
	end
	_G.GetBuybackItemLink = function(i) return world.buyback[i] and world.buyback[i].link end
	_G.BUYBACK_ITEMS_PER_PAGE = 12
	_G.GetMoneyString = function(copper) return copper .. 'c' end
	_G.CanMerchantRepair = function() return true end
	_G.GetRepairAllCost = function() return 500, true end
	_G.RepairAllItems = function() world.repairs = world.repairs + 1 world.money = world.money - 500 end

	-- The merchant window.
	_G.MerchantFrame = H.NewFrame('Frame', 'MerchantFrame', UIParent)
	MerchantFrame.selectedTab, MerchantFrame.page = 1, 1
	for i = 1, 12 do Slot('MerchantItem' .. i) end
	_G.MerchantFrameBottomLeftBorder = H.NewFrame('Frame', 'MerchantFrameBottomLeftBorder', MerchantFrame)
	_G.MerchantNextPageButton = H.NewFrame('Button', 'MerchantNextPageButton', MerchantFrame)
	_G.MerchantPrevPageButton = H.NewFrame('Button', 'MerchantPrevPageButton', MerchantFrame)
	_G.MerchantPageText = H.NewFrame('FontString', 'MerchantPageText', MerchantFrame)
	_G.MERCHANT_PAGE_NUMBER = 'Page %s of %s'
	local createFrame = CreateFrame
	_G.CreateFrame = function(kind, name, parent, template)
		if template == 'MerchantItemTemplate' then return Slot(name) end
		return createFrame(kind, name, parent, template)
	end
	_G.MerchantFrame_UpdateMerchantInfo = function() end
	_G.MerchantFrame_UpdateBuybackInfo = function() end
	_G.MerchantFrame_UpdateItemQualityBorders = function() end
	_G.GetMerchantNumItems = function() return world.items end
	_G.GetMerchantItemID = function(index) return 1000 + index end
	_G.GetMerchantItemLink = function(index) return 'item:' .. (1000 + index) end
	_G.CanAffordMerchantItem = function() return true end
	_G.GetMerchantItemCostInfo = function() return 0 end
	_G.C_TooltipInfo = { GetMerchantItem = function() world.tooltips = world.tooltips + 1 return { lines = {} } end }
	_G.C_Heirloom = { IsItemHeirloom = function() return false end, PlayerHasHeirloom = function() return false end }
	_G.C_MountJournal = { GetMountFromItem = function() return nil end }
	_G.C_PetJournal = { GetPetInfoByItemID = function() return nil end }
	_G.MerchantFrameItem_UpdateQuality = function() world.qualityPaints = world.qualityPaints + 1 end
	for _, name in ipairs({ 'SetItemButtonCount', 'SetItemButtonStock', 'SetItemButtonTexture', 'SetItemButtonDesaturated',
		'SetItemButtonNameFrameVertexColor', 'SetItemButtonSlotVertexColor', 'SetItemButtonTextureVertexColor',
		'SetItemButtonNormalTextureVertexColor', 'MoneyFrame_SetMaxDisplayWidth', 'MoneyFrame_Update', 'SetMoneyFrameColor' }) do
		_G[name] = function() end
	end
	_G.MerchantFrame_UpdateAltCurrency = function() return 0 end

	H.load('Config.lua')
	for key, value in pairs(modules or {}) do ns.C.modules[key] = value end
	H.load('Core.lua')
	H.load('Vendor.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

local function Printed(pattern)
	for _, line in ipairs(H.prints) do
		if line:find(pattern, 1, true) then return line end
	end
end

------------------------------------------------------------------------
-- F7: with the vendor module off, the vendor is left alone.
------------------------------------------------------------------------
do
	Boot({ vendor = false })
	world.bags[0] = { { id = 1, quality = world.POOR } }
	world.prices[1] = 50
	H.fire('MERCHANT_SHOW')
	H.runTimers(2)
	H.equal(world.sold, 0, 'F7 vendor module off: no junk sold')
	H.equal(world.repairs, 0, 'F7 vendor module off: no repair')

	Boot()
	world.bags[0] = { { id = 1, quality = world.POOR } }
	world.prices[1] = 50
	H.fire('MERCHANT_SHOW')
	H.check(world.sold == 1 and world.repairs == 1, 'F7 vendor module on: junk sold and gear repaired')
end

------------------------------------------------------------------------
-- F24: the gold reported is what the junk brought, not every change of the money.
------------------------------------------------------------------------
do
	Boot()
	world.bags[0] = {
		{ id = 1, quality = world.POOR, count = 3 },
		{ id = 2, quality = world.POOR },
		{ id = 3, quality = 3 }, -- a blue item: not junk
		{ id = 4, quality = world.POOR, noValue = true }, -- grey without value: not junk
	}
	world.bags[1] = { { id = 5, quality = world.POOR } } -- a bag excluded from the sale
	world.excluded[1] = true
	world.prices[1], world.prices[2], world.prices[5] = 100, 250, 999
	world.incoming = 1000000 -- 100 gold from the mail, a trade, a quest in the same moment
	H.fire('MERCHANT_SHOW')
	H.runTimers(2)
	H.check(Printed('Sold junk: 2 items, 550c') ~= nil, 'F24 the report is the junk\'s value only (2 items, 550c)')
	H.check(Printed('1000') == nil, 'F24 the 100 gold from elsewhere is not counted')
end

do
	-- The sale does not go through; the player moves the junk item to another slot meanwhile.
	Boot()
	world.bags[0] = { { id = 1, quality = world.POOR }, {} }
	world.prices[1] = 100
	world.saleFails = true
	H.fire('MERCHANT_SHOW')
	world.bags[0] = { {}, { id = 1, quality = world.POOR } }
	H.runTimers(2)
	H.equal(Printed('Sold junk'), nil, 'F24 an emptied slot is no proof: nothing sold, nothing reported')
end

do
	-- More junk than the buyback list keeps: the report is a lower bound, marked as such.
	Boot()
	for i = 1, 5 do table.insert(world.buyback, { link = 'item:900' .. i, price = 7, quantity = 1 }) end
	world.bags[0] = {}
	for i = 1, 14 do
		world.bags[0][i] = { id = 100 + i, quality = world.POOR }
		world.prices[100 + i] = 10
	end
	H.fire('MERCHANT_SHOW')
	H.runTimers(2)
	H.check(Printed('Sold junk: at least 12 items, 120c') ~= nil, 'F24 a full buyback list gives "at least" (12 of 14 seen)')
end

do
	-- The buyback list shows nothing: only the junk count's drop, as an estimate and without gold.
	Boot()
	world.bags[0] = { { id = 1, quality = world.POOR }, { id = 2, quality = world.POOR } }
	world.prices[1], world.prices[2] = 100, 200
	world.noBuyback = true
	H.fire('MERCHANT_SHOW')
	H.runTimers(2)
	local line = Printed('Sold junk:')
	H.check(line ~= nil and line:match('Sold junk: about 2 items$') ~= nil, 'F24 without buyback proof only an estimated count')
end

------------------------------------------------------------------------
-- F26: item data arriving does not redraw the whole list once per item.
------------------------------------------------------------------------
do
	Boot()
	world.items = 100 -- 100 items, none of them loaded yet
	MerchantFrame_UpdateMerchantInfo()
	H.equal(world.tooltips, 100, 'F26 the first draw reads each unloaded item once')
	H.equal(MerchantItem1ItemButton:GetID(), 1, 'F26 slot 1 buys item 1')

	-- Blizzard redraws again in the same moment (bags, currency): the unloaded items are not read again.
	MerchantFrame_UpdateMerchantInfo()
	H.equal(world.tooltips, 100, 'F26 a redraw before any item data arrives reads no tooltip again')

	-- Data of some other item arrives: none of the waiting ones, so no redraw.
	local paints = world.qualityPaints
	MerchantFrame_UpdateItemQualityBorders(MerchantFrame)
	H.runTimers(0)
	H.equal(world.tooltips, 100, 'F26 data of an item not on this vendor redraws nothing')
	H.equal(world.qualityPaints - paints, 20, 'F26 the 20 shown slots still get their quality border at once')

	-- Three of the vendor's items arrive in the same frame.
	world.cached[1001], world.cached[1002], world.cached[1003] = true, true, true
	for _ = 1, 3 do MerchantFrame_UpdateItemQualityBorders(MerchantFrame) end
	H.equal(world.tooltips, 100, 'F26 no full redraw right at the item data events')
	H.equal(MerchantItem1ItemButton:GetID(), 1, 'F26 the slots still buy the items they show')
	H.runTimers(0)
	H.equal(world.tooltips, 103, 'F26 one redraw on the next frame reads only the 3 arrived items')
	H.equal(MerchantItem20ItemButton:GetID(), 20, 'F26 after the redraw slot 20 still buys item 20')

	-- Once the items are loaded the owned check is kept for good.
	for id = 1001, 1100 do world.cached[id] = true end
	MerchantFrame_UpdateItemQualityBorders(MerchantFrame)
	H.runTimers(0)
	local reads = world.tooltips
	MerchantFrame_UpdateMerchantInfo()
	H.equal(world.tooltips, reads, 'F26 loaded items are not read again')
end

do
	-- The audit's case: 100 unloaded items, one of them loads.
	Boot()
	world.items = 100
	MerchantFrame_UpdateMerchantInfo()
	world.cached[1050] = true
	MerchantFrame_UpdateItemQualityBorders(MerchantFrame)
	H.runTimers(0)
	H.equal(world.tooltips, 101, 'F26 one loaded item: 101 reads in all, not 200')
end

H.done()
