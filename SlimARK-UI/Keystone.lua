local _, ns = ...
local C = ns.C

-- Three keystone helpers, all on events only:
-- the Font of Power gets your keystone the moment its window opens, after a run your new
-- keystone is posted to the party once the game has handed it over, and "!keys" in party or
-- guild chat is answered with your keystone.

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

------------------------------------------------------------------------
-- "!keys" in party or guild chat: your keystone is posted as the answer. In a running key and
-- in a boss fight the game hides the chat text and blocks addon chat, so nothing happens there.
------------------------------------------------------------------------
local ANSWER_GAP = 10
local answered = {}

local function AnswerKeys(event, text)
	if not C.features.answerKeys or issecretvalue(text) or type(text) ~= 'string' or Locked() then return end
	local word = strtrim(text):lower()
	if word ~= '!keys' and word ~= '!key' then return end
	local channel = event == 'CHAT_MSG_GUILD' and 'GUILD' or 'PARTY'
	-- Several players asking at once get one answer.
	local now = GetTime()
	if answered[channel] and now - answered[channel] < ANSWER_GAP then return end
	local _, _, link = FindKeystone()
	if not link then return end
	answered[channel] = now
	local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
	send(link, channel)
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
	for _, event in ipairs({ 'CHAT_MSG_PARTY', 'CHAT_MSG_PARTY_LEADER', 'CHAT_MSG_GUILD' }) do
		ns.On(event, AnswerKeys)
	end
	before = Owned()
end)

------------------------------------------------------------------------
-- 3.0 (8, 10): more in the keystone tooltip of the top bar. The season's best level and score per
-- dungeon with this week's affixes, and the party's keys by the LibKeystone protocol that BigWigs,
-- Details! and other addons speak: "R" on the LibKS prefix asks the party, each one answers
-- "level,mapID,rating". Nothing is sent or taken in a running key, in a boss fight or while the
-- game blocks addon chat, and a send the game refuses is not counted. Your own key answers the
-- others' requests, unless a LibKeystone of another addon already does.
------------------------------------------------------------------------
local MUTED = { 0.6, 0.61, 0.65 }

local function Readable(v)
	return not issecretvalue(v) and v ~= nil
end

local function ClassColor(class)
	local c = Readable(class) and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

-- The season table, best score first.
local function SeasonLines(tip)
	local maps = C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable() or {}
	if #maps == 0 then return end
	local rows = {}
	for _, mapID in ipairs(maps) do
		local name = C_ChallengeMode.GetMapUIInfo(mapID)
		local intime, overtime = C_MythicPlus.GetSeasonBestForMap(mapID)
		local run = intime or overtime
		local _, score = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
		table.insert(rows, { name = name or '?', level = run and run.level, timed = intime ~= nil, score = score or 0 })
	end
	table.sort(rows, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.name < b.name
	end)
	tip:AddLine(' ')
	tip:AddLine('SEASON BEST', MUTED[1], MUTED[2], MUTED[3])
	for _, row in ipairs(rows) do
		local right = '|cff9a9ca5-|r'
		if row.level then
			local level = (row.timed and '+' or '|cff9a9ca5+') .. row.level .. (row.timed and '' or '|r')
			local score = tostring(math.floor(row.score + 0.5))
			local color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(row.score)
			if color and color.WrapTextInColorCode then score = color:WrapTextInColorCode(score) end
			right = level .. '   ' .. score
		end
		tip:AddDoubleLine(row.name, right, 0.9, 0.9, 0.9, 1, 1, 1)
	end
	local names = {}
	for _, affix in ipairs(C_MythicPlus.GetCurrentAffixes and C_MythicPlus.GetCurrentAffixes() or {}) do
		local name = affix.id and C_ChallengeMode.GetAffixInfo and C_ChallengeMode.GetAffixInfo(affix.id)
		if name then table.insert(names, name) end
	end
	-- This week's affixes in their own section, one per line, so the tooltip keeps the width of the
	-- season table.
	if #names > 0 then
		tip:AddLine(' ')
		tip:AddLine('THIS WEEK', MUTED[1], MUTED[2], MUTED[3])
		for _, name in ipairs(names) do tip:AddLine(name, 0.9, 0.9, 0.9) end
	end
end

local PREFIX = 'LibKS'
local REQUEST_GAP, STALE, REPLY_GAP = 10, 30, 3
local partyKeys = {} -- by the name the protocol gives (Name, or Name-Realm from another realm)
local keysOn = false
local lastRequest, lastReply = -1e9, -1e9
local requestQueued, replyQueued, redrawQueued = false, false, false
local tipOwner

local function InParty()
	return IsInGroup() and not IsInRaid()
end

local function Busy()
	if Locked() then return true end
	if C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return true end
	return ns.InEncounter()
end

local function SendAddon(message)
	if Busy() or not InParty() then return false end
	local result = C_ChatInfo.SendAddonMessage(PREFIX, message, 'PARTY')
	-- 0 is Enum.SendAddonMessageResult.Success; a lockdown (11) or a throttle is not a send.
	return result == 0 or result == true
end

local function Request()
	if not keysOn or not InParty() then return end
	local wait = REQUEST_GAP - (GetTime() - lastRequest)
	if wait > 0 then
		if not requestQueued then
			requestQueued = true
			C_Timer.After(wait, function()
				requestQueued = false
				Request()
			end)
		end
		return
	end
	if SendAddon('R') then lastRequest = GetTime() end
end

local function OwnKey()
	local level = C_MythicPlus.GetOwnedKeystoneLevel()
	local map = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local summary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_PlayerInfo.GetPlayerMythicPlusRatingSummary('player')
	local rating = summary and summary.currentSeasonScore
	local function whole(v) return type(v) == 'number' and not issecretvalue(v) and math.floor(v) or 0 end
	return whole(level), whole(map), whole(rating)
end

local function Reply()
	replyQueued = false
	lastReply = GetTime()
	SendAddon(('%d,%d,%d'):format(OwnKey()))
end

-- An answer that comes while the tooltip shows redraws it once.
local function Redraw()
	if redrawQueued or not tipOwner then return end
	redrawQueued = true
	C_Timer.After(0.2, function()
		redrawQueued = false
		local onEnter = tipOwner:GetScript('OnEnter')
		if onEnter and GameTooltip:IsOwned(tipOwner) then onEnter(tipOwner) end
	end)
end

local function OnAddonMessage(_, prefix, text, channel, sender)
	if issecretvalue(prefix) or issecretvalue(text) or issecretvalue(channel) or issecretvalue(sender) then return end
	if prefix ~= PREFIX or channel ~= 'PARTY' or type(text) ~= 'string' or type(sender) ~= 'string' then return end
	local name = Ambiguate(sender, 'none')
	if name == UnitName('player') then return end
	if text == 'R' then
		-- Another addon's LibKeystone answers for us when there is one.
		if LibStub and LibStub('LibKeystone', true) then return end
		local wait = REPLY_GAP - (GetTime() - lastReply)
		if wait <= 0 then
			Reply()
		elseif not replyQueued then
			replyQueued = true
			C_Timer.After(wait + 0.1, Reply)
		end
		return
	end
	-- Not refreshed in a running key or a boss fight.
	if Busy() then return end
	local level, map = text:match('^(%d+),(%d+),%d+$')
	if not level then return end
	partyKeys[name] = { level = tonumber(level), map = tonumber(map) }
	Redraw()
end

local function PartyLines(tip)
	if not InParty() then return end
	if GetTime() - lastRequest > STALE then Request() end
	local lines = {}
	for i = 1, 4 do
		local unit = 'party' .. i
		local full, short = GetUnitName(unit, true), UnitName(unit)
		if UnitExists(unit) and Readable(full) and Readable(short) then
			local _, class = UnitClass(unit)
			local key = partyKeys[full]
			local text, gray = 'no data', true
			if key and key.level > 0 then
				text, gray = (C_ChallengeMode.GetMapUIInfo(key.map) or '?') .. ' +' .. key.level, false
			elseif key then
				text = 'no key'
			end
			table.insert(lines, { short, text, gray, ClassColor(class) })
		end
	end
	if #lines == 0 then return end
	tip:AddLine(' ')
	tip:AddLine('PARTY KEYS', MUTED[1], MUTED[2], MUTED[3])
	for _, l in ipairs(lines) do
		local c = l[3] and MUTED or { 1, 1, 1 }
		tip:AddDoubleLine(l[1], l[2], l[4], l[5], l[6], c[1], c[2], c[3])
	end
end

-- Called by the keystone segment of the top bar while it builds its tooltip.
function ns.AddKeystoneTooltip(tip, owner)
	if ns.isForever or not C_ChallengeMode or not C_MythicPlus then return end
	tipOwner = owner
	if C.features.keystoneSeason then SeasonLines(tip) end
	if keysOn then PartyLines(tip) end
end

ns.On('PLAYER_LOGIN', function()
	if ns.isForever or not C.features.partyKeys or not C_ChallengeMode or not C_MythicPlus then return end
	if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix or not C_ChatInfo.SendAddonMessage then return end
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	keysOn = true
	ns.On('CHAT_MSG_ADDON', OnAddonMessage)
	ns.On('GROUP_ROSTER_UPDATE', Request)
	ns.On('PLAYER_ENTERING_WORLD', Request)
	ns.On('GROUP_LEFT', function() wipe(partyKeys) end)
end)
