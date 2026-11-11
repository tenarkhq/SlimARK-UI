local H = dofile('tests/codex/lib/runtime.lua')
local world

local function Link(level) return '|cffa335ee|Hkeystone:180653:1:' .. level .. ':0|h[Keystone]|h|r' end

local function Boot(flavor)
	local ns = H.boot(flavor)
	world = { level = 5, locked = false, sent = {}, hooks = 0 }
	NUM_BAG_SLOTS = 0
	C_Container = {
		GetContainerNumSlots = function() return 1 end,
		GetContainerItemInfo = function() return { hyperlink = world.link } end,
	}
	C_ChallengeMode = {}
	C_MythicPlus = {
		GetOwnedKeystoneChallengeMapID = function() return 1 end,
		GetOwnedKeystoneLevel = function() return world.level end,
	}
	C_ChatInfo = {
		InChatMessagingLockdown = function() return world.locked end,
		SendChatMessage = function(message, channel) world.sent[#world.sent + 1] = { message, channel } end,
	}
	IsInGroup = function() return true end
	ShowChallengesKeystoneFrame = function() end
	local hook = hooksecurefunc
	hooksecurefunc = function(...) world.hooks = world.hooks + 1 return hook(...) end
	H.load('Keystone.lua')
	H.fire('PLAYER_LOGIN')
	H.fire('CHALLENGE_MODE_START')
	return ns
end

do
	Boot()
	world.level = 6
	H.fire('CHALLENGE_MODE_COMPLETED')
	H.fire('PLAYER_ENTERING_WORLD')
	assert(#world.sent == 0)
	world.link = Link(5)
	H.fire('BAG_UPDATE_DELAYED')
	assert(#world.sent == 0, 'A stale bag link is not the new key')
	world.link = Link(6)
	H.fire('BAG_UPDATE_DELAYED')
	assert(#world.sent == 1 and world.sent[1][1]:find(Link(6), 1, true))
	H.fire('BAG_UPDATE_DELAYED')
	H.runTimers(2)
	assert(#world.sent == 1, 'A delayed key is announced exactly once')
	H.noErrors()
end

do
	Boot()
	world.level, world.locked = 6, true
	world.link = Link(6)
	H.fire('CHALLENGE_MODE_COMPLETED')
	H.runTimers(121) -- the bounded polling ends; the already built message remains queued
	assert(#world.sent == 0)
	world.locked = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.fire('BAG_UPDATE_DELAYED')
	assert(#world.sent == 1, 'Chat lockdown keeps a message until chat is allowed again')
	H.noErrors()
end

do
	Boot()
	H.fire('CHALLENGE_MODE_COMPLETED') -- somebody else's key; ours never changes
	H.runTimers(121)
	world.level, world.link = 6, Link(6)
	H.fire('BAG_UPDATE_DELAYED')
	assert(#world.sent == 0 and #H.timers == 0, 'An unchanged key stops polling at the deadline')
	H.noErrors()
end

do
	Boot('forever')
	world.level, world.link = 6, Link(6)
	H.fire('CHALLENGE_MODE_COMPLETED')
	H.fire('BAG_UPDATE_DELAYED')
	assert(world.hooks == 0 and #world.sent == 0 and #H.timers == 0,
		'Forever installs no keystone automation despite available namespaces')
	H.noErrors()
end
