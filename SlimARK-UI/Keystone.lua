local _, ns = ...
local C = ns.C

-- Two keystone helpers, both on events only:
-- the Font of Power gets your keystone the moment its window opens, and after a run
-- your new keystone is posted to the party once the game has handed it over.

local function FindKeystone()
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local link = info and info.hyperlink
			if link and not issecretvalue(link) and link:find('|Hkeystone:') then return bag, slot, link end
		end
	end
end
ns.FindKeystone = FindKeystone

local function Insert()
	if not C.features.autoKeystone or InCombatLockdown() then return end
	if C_ChallengeMode.HasSlottedKeystone() or CursorHasItem() then return end
	local bag, slot = FindKeystone()
	if not bag then return end
	C_Container.PickupContainerItem(bag, slot)
	if CursorHasItem() then C_ChallengeMode.SlotKeystone() end
end
ns.InsertKeystone = Insert

------------------------------------------------------------------------
-- The new keystone after a run.
------------------------------------------------------------------------
local before -- the keystone you had when the run started: 'mapID:level'
local waiting = false
local pending -- a message held back while the game blocks addon chat

local function Owned()
	local map = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local level = C_MythicPlus.GetOwnedKeystoneLevel()
	if not map or not level or level == 0 then return nil end
	return map .. ':' .. level
end

local function Locked()
	return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function Send()
	if not pending or Locked() then return end
	if IsInGroup(LE_PARTY_CATEGORY_HOME) then
		local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
		send(pending, 'PARTY')
	end
	pending = nil
end

local function CheckNewKey()
	if not waiting then return end
	local now = Owned()
	if not now or now == before then return end
	waiting = false
	before = now
	local _, _, link = FindKeystone()
	if not link then return end
	pending = 'My new key: ' .. link
	Send()
end
ns.CheckNewKeystone = CheckNewKey

ns.On('PLAYER_LOGIN', function()
	-- WoW Forever has no Mythic+.
	if not C_ChallengeMode or not C_MythicPlus then return end
	if ShowChallengesKeystoneFrame then hooksecurefunc('ShowChallengesKeystoneFrame', Insert) end

	ns.On('CHALLENGE_MODE_START', function() before = Owned() end)
	ns.On('CHALLENGE_MODE_COMPLETED', function()
		if not C.features.announceKey then return end
		waiting = true
		CheckNewKey()
	end)
	ns.On('BAG_UPDATE_DELAYED', function()
		CheckNewKey()
		Send()
	end)
	-- Leaving the dungeon or the end of combat lifts the chat block. A run with another
	-- player's keystone leaves yours as it was: leaving the dungeon stops the wait.
	ns.On('PLAYER_ENTERING_WORLD', function()
		waiting = false
		Send()
	end)
	ns.On('PLAYER_REGEN_ENABLED', Send)
	before = Owned()
end)
