-- F24: removing an old buyback entry must not turn its neighbours into new sales.
local H = dofile('tests/claude/lib/helpers.lua')

local function Report(old, new, beforeCount, afterCount)
	local ns = H.setup()
	H.load('Config.lua')
	ns.C.features.autoRepair = false
	local list, count = old, beforeCount
	_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
	_G.C_Container = {
		GetContainerNumSlots = function() return beforeCount end,
		GetContainerItemInfo = function(_, slot) return { itemID = slot, quality = Enum.ItemQuality.Poor } end,
	}
	_G.C_MerchantFrame = {
		IsSellAllJunkEnabled = function() return true end,
		GetNumJunkItems = function() return count end,
		SellAllJunkItems = function() list, count = new, afterCount end,
	}
	_G.GetNumBuybackItems = function() return #list end
	_G.GetBuybackItemLink = function(i) return list[i] and ('item:' .. list[i]) end
	_G.GetBuybackItemInfo = function(i) if list[i] then return 'Junk', 1, 100, 1 end end
	_G.GetMoneyString = function(copper) return copper .. 'c' end
	_G.MerchantFrame = H.NewFrame('Frame')
	H.load('Core.lua')
	H.load('Vendor.lua')
	H.fire('MERCHANT_SHOW')
	H.runTimers(2)
	for _, line in ipairs(H.prints) do
		if line:find('Sold junk:', 1, true) then return line end
	end
end

assert(Report({ 1, 2, 3 }, { 1, 3 }, 3, 3) == nil, 'A buyback removal alone is no sale')
assert(Report({ 1, 2, 3 }, { 1, 3, 4 }, 4, 3):find('at least 1 item, 100c', 1, true),
	'Only the added fourth item is confirmed, even when another entry is removed')
assert(Report({ 1, 2 }, { 1, 2, 2 }, 2, 1):find('at least 1 item, 100c', 1, true),
	'An excess identical entry is a sale; the older identical copy is excluded')
assert(Report({ 1, 1 }, { 1, 1 }, 1, 0):find('about 1 item', 1, true),
	'An indistinguishable replacement falls back to an explicitly estimated count')
