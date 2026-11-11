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
local deadline, generation = 0, 0
local WAIT_SECONDS = 120

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
	waiting = false
	before = Owned()
end

local function CheckNewKey()
	if not waiting then return end
	if GetTime() > deadline then waiting = false return end
	local now = Owned()
	if not now or now == before then return end
	local _, _, link = FindKeystone()
	if not link then return end
	-- The owned API can update before the bags; an older bag link must not close the wait.
	local map, level = link:match('|Hkeystone:%d+:(%d+):(%d+)')
	if not map or map .. ':' .. level ~= now then return end
	pending = 'My new key: ' .. link
	Send()
end
ns.CheckNewKeystone = CheckNewKey

local function Poll(epoch)
	if epoch ~= generation or not waiting then return end
	CheckNewKey()
	if waiting then C_Timer.After(1, function() Poll(epoch) end) end
end

ns.On('PLAYER_LOGIN', function()
	-- WoW Forever has no Mythic+.
	if ns.isForever or not C_ChallengeMode or not C_MythicPlus then return end
	if ShowChallengesKeystoneFrame then hooksecurefunc('ShowChallengesKeystoneFrame', Insert) end

	ns.On('CHALLENGE_MODE_START', function()
		generation = generation + 1
		waiting, pending = false, nil
		before = Owned()
	end)
	ns.On('CHALLENGE_MODE_COMPLETED', function()
		if not C.features.announceKey then return end
		waiting = true
		deadline = GetTime() + WAIT_SECONDS
		generation = generation + 1
		Poll(generation)
	end)
	ns.On('BAG_UPDATE_DELAYED', function()
		CheckNewKey()
		Send()
	end)
	ns.On('ITEM_DATA_LOAD_RESULT', CheckNewKey)
	-- Leaving the dungeon can lift the chat block before the bag link arrives. Keep the
	-- bounded wait alive across that transition; an unchanged key simply expires.
	ns.On('PLAYER_ENTERING_WORLD', function()
		CheckNewKey()
		Send()
	end)
	ns.On('PLAYER_REGEN_ENABLED', Send)
	before = Owned()
end)
