local _, ns = ...
local C = ns.C

-- Auto quest: accepts the quests an NPC offers and turns in the finished ones, finished ones
-- first. When a reward has to be chosen it stops and you choose. With a single talk option it
-- picks that one (events, dungeon talks). It never picks an option that costs something or asks
-- for a confirmation, and leaves vendors, flight masters, innkeepers, trainers, banks and the
-- transmogrifier alone. Holding Shift pauses it. The switch on the top bar turns it off and on.
local cfg = C.autoquest

function ns.AutoQuestOn()
	return C.features.autoQuest and not (ns.DB and ns.DB.autoQuestOff) or false
end

function ns.ToggleAutoQuest()
	if not ns.DB then return end
	ns.DB.autoQuestOff = not ns.DB.autoQuestOff or nil
	ns.Print('Auto quest ' .. (ns.AutoQuestOn() and 'on' or 'off') .. '.')
	if ns.UpdateAutoQuestSegment then ns.UpdateAutoQuestSegment() end
end

local function Active()
	return ns.AutoQuestOn() and not IsShiftKeyDown()
end

-- NPCs that are there for something else: their window stays as it is.
local function ServiceNPC()
	if not UnitExists('npc') then return false end
	return (C_PlayerInteractionManager and (
		C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Merchant)
		or C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Banker)
		or C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Trainer)
		or C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.TaxiNode)
		or C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Transmogrifier)
		or C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Binder)
	)) or false
end

-- The only option an NPC talks with: the chat bubble icon, or the game says it may be picked alone.
local CHAT_ICON = 132053
local SERVICE_ICONS = {
	[132060] = true, -- vendor
	[132057] = true, -- flight master
	[132052] = true, -- innkeeper
	[132058] = true, -- trainer
	[132050] = true, -- bank
	[132055] = true, -- auctioneer
	[1673939] = true, -- transmogrifier
}

local lastGossip, lastTime = nil, 0

local function PickOnlyOption(options)
	if not cfg.gossip or #options ~= 1 then return false end
	local option = options[1]
	if option.status and option.status ~= 0 then return false end
	if SERVICE_ICONS[option.icon] then return false end
	-- An option that casts a spell is not talk. One that costs gold or wants a yes opens the
	-- game's own confirmation (GOSSIP_CONFIRM), which is never answered here.
	if option.spellID and option.spellID > 0 then return false end
	if not (option.selectOptionWhenOnlyOption or option.icon == CHAT_ICON) then return false end
	-- The same option again within two seconds: the NPC loops, it is left to you.
	if lastGossip == option.gossipOptionID and GetTime() - lastTime < 2 then return false end
	lastGossip, lastTime = option.gossipOptionID, GetTime()
	C_GossipInfo.SelectOption(option.gossipOptionID)
	return true
end

ns.On('GOSSIP_SHOW', function()
	if not Active() or ServiceNPC() then return end
	if cfg.turnIn then
		for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
			if quest.isComplete then
				C_GossipInfo.SelectActiveQuest(quest.questID)
				return
			end
		end
	end
	if cfg.accept then
		for _, quest in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
			if not quest.isTrivial then
				C_GossipInfo.SelectAvailableQuest(quest.questID)
				return
			end
		end
	end
	-- Unfinished quests only show their talk; with nothing else to do the single option is picked.
	local active = C_GossipInfo.GetActiveQuests() or {}
	local available = C_GossipInfo.GetAvailableQuests() or {}
	if #available == 0 then
		for _, quest in ipairs(active) do
			if quest.isComplete then return end
		end
		PickOnlyOption(C_GossipInfo.GetOptions() or {})
	end
end)

-- An NPC with several quests and no talk shows the greeting list instead.
ns.On('QUEST_GREETING', function()
	if not Active() then return end
	if cfg.turnIn then
		for i = 1, GetNumActiveQuests() do
			local _, complete = GetActiveTitle(i)
			if complete then
				SelectActiveQuest(i)
				return
			end
		end
	end
	if cfg.accept then
		for i = 1, GetNumAvailableQuests() do
			local trivial = GetAvailableQuestInfo(i)
			if not trivial then
				SelectAvailableQuest(i)
				return
			end
		end
	end
end)

ns.On('QUEST_DETAIL', function()
	if not Active() or not cfg.accept then return end
	-- A quest the game has accepted already is only acknowledged.
	if QuestGetAutoAccept() then
		AcknowledgeAutoAcceptQuest()
		return
	end
	-- A grey (trivial) quest is left to you here too, as in the quest lists: an NPC with one quest
	-- or an item opens its details directly, without a list.
	local questID = GetQuestID()
	if questID and questID > 0 and C_QuestLog.IsQuestTrivial(questID) then return end
	AcceptQuest()
end)

ns.On('QUEST_ACCEPT_CONFIRM', function()
	if not Active() or not cfg.accept then return end
	ConfirmAcceptQuest()
	StaticPopup_Hide('QUEST_ACCEPT')
end)

-- Handing in: a quest that wants gold is your decision.
ns.On('QUEST_PROGRESS', function()
	if not Active() or not cfg.turnIn then return end
	if not IsQuestCompletable() then return end
	if GetQuestMoneyToGet() > 0 then return end
	CompleteQuest()
end)

-- The reward: with one or none it is taken; with a choice the window waits for you.
ns.On('QUEST_COMPLETE', function()
	if not Active() or not cfg.turnIn then return end
	local choices = GetNumQuestChoices()
	if choices > 1 then return end
	if GetQuestMoneyToGet() > 0 then return end
	GetQuestReward(choices)
end)

-- Quests finished out in the world, turned in from the tracker pop-up.
ns.On('QUEST_AUTOCOMPLETE', function(_, questID)
	if not Active() or not cfg.turnIn then return end
	local index = C_QuestLog.GetLogIndexForQuestID(questID)
	if index then ShowQuestComplete(questID) end
end)
