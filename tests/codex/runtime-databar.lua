local H = dofile('tests/codex/lib/runtime.lua')
local world

local function Boot(flavor)
	local ns = H.boot(flavor)
	world = { guid = 'Player-1-CURRENT', name = 'Original', realm = 'Realm', money = 100000,
		now = 2000000000, namespaceReads = 0, tips = {}, menu = {} }
	UnitGUID = function() return world.guid end
	UnitName = function() return world.name end
	UnitClass = function() return 'Warrior', 'WARRIOR' end
	GetRealmName = function() return world.realm end
	GetMoney = function() return world.money end
	GetMoneyString = function(money) return money .. 'c' end
	GetServerTime = function() return world.now end
	date = function(_, stamp) return 'timestamp:' .. stamp end
	BreakUpLargeNumbers = tostring
	RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 1, b = 1 } }
	NORMAL_FONT_COLOR = RAID_CLASS_COLORS.WARRIOR
	GameTooltip = H.NewFrame('GameTooltip')
	GameTooltip.SetOwner = function() world.tips = {} end
	GameTooltip.AddLine = function(_, text) world.tips[#world.tips + 1] = { text } end
	GameTooltip.AddDoubleLine = function(_, a, b) world.tips[#world.tips + 1] = { a, b } end
	MenuUtil = { CreateContextMenu = function(owner, build)
		local root = { CreateTitle = function() end, CreateButton = function(_, title, fn) world.menu[title] = fn end }
		build(owner, root)
	end }
	local function Read(value)
		return function() world.namespaceReads = world.namespaceReads + 1 return value end
	end
	C_MythicPlus = { GetOwnedKeystoneChallengeMapID = Read(nil), GetOwnedKeystoneLevel = Read(0), RequestMapInfo = Read(nil) }
	C_ChallengeMode = { GetMapUIInfo = Read('Dungeon') }
	C_WeeklyRewards = { GetActivities = Read({}) }
	for key in pairs(ns.C.databar.show) do ns.C.databar.show[key] = false end
	ns.C.databar.show.gold, ns.C.databar.show.keystone, ns.C.databar.show.vault = true, true, true
	ns.DB.gold = { ['Realm|Original'] = { money = 100000, class = 'WARRIOR' },
		['Realm|UnknownOldName'] = { money = 100000, class = 'WARRIOR' } }
	H.load('DataBar.lua')
	H.fire('PLAYER_LOGIN')
	H.noErrors()
	local gold
	for _, frame in ipairs(H.frames) do if frame.key == 'gold' then gold = frame end end
	return ns, gold
end

local function Tip(gold, label)
	gold:GetScript('OnEnter')(gold)
	for _, line in ipairs(world.tips) do if line[1] == label then return line[2] end end
end

do
	local ns, gold = Boot()
	assert(ns.DB.gold[world.guid].money == 100000 and not ns.DB.gold['Realm|Original'], 'The current legacy name is promoted to GUID')
	assert(ns.DB.gold[world.guid].updatedAt == world.now)
	world.name = 'Renamed'
	H.fire('PLAYER_MONEY')
	assert(ns.DB.gold[world.guid].name == 'Renamed' and Tip(gold, 'Saved realm total') == '100000c',
		'A rename updates the same snapshot; unidentified legacy aliases are excluded from the total')
	assert(ns.DB.gold['Realm|UnknownOldName'].money == 100000, 'Old offline information is preserved')
	local warning, timestamp = false, false
	for _, line in ipairs(world.tips) do
		warning = warning or line[1]:find('excluded from total', 1, true) ~= nil
		timestamp = timestamp or line[1]:find('Last seen: timestamp:', 1, true) ~= nil
	end
	assert(warning and timestamp, 'The tooltip distinguishes unverified and dated snapshots')
	ns.DB.gold['Player-1-DELETED'] = { name = 'Gone', realm = 'Realm', class = 'WARRIOR', money = 70,
		updatedAt = world.now - 31 * 86400 }
	assert(Tip(gold, 'Saved realm total') == '100070c', 'Old snapshots are not silently set to zero')
	local stale = false
	for _, line in ipairs(world.tips) do stale = stale or line[1]:find('over 30 days old', 1, true) ~= nil end
	assert(stale, 'Stale information is labelled')
	gold:GetScript('OnClick')(gold, 'RightButton')
	assert(not world.menu['Renamed (Realm)'], 'The live character is not offered for removal')
	assert(world.menu['Gone (Realm)'], 'An offline/deleted character has a removal action')
	world.menu['Gone (Realm)']()
	assert(not ns.DB.gold['Player-1-DELETED'] and Tip(gold, 'Saved realm total') == '100000c')
	world.realm = 'OtherRealm'
	H.fire('PLAYER_MONEY')
	assert(ns.DB.gold[world.guid].realm == 'OtherRealm' and Tip(gold, 'Saved realm total') == '100000c')
	assert(world.namespaceReads > 0, 'Retail still provides the key and vault segments')
	H.noErrors()
end

do
	Boot('forever')
	for _, frame in ipairs(H.frames) do
		assert(frame.key ~= 'keystone' and frame.key ~= 'vault', 'Forever does not create unsupported segments')
	end
	assert(world.namespaceReads == 0, 'Forever does not request unsupported Mythic+ or vault data')
	H.noErrors()
end
