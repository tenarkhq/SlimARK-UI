local _, ns = ...
local K = ns.BlizzSkin

-- The Blizzard windows of the 2.0 look, one entry per settings switch. Each function runs
-- once, the first time its window opens (see BlizzSkin.lua). Nothing here runs with the
-- Original look.
local ROW = { 0.09, 0.094, 0.114, 1 }

local function HideNamed(prefix, list)
	for _, suffix in ipairs(list) do K.Hide(_G[prefix .. suffix]) end
end

local function Items(prefix, from, to, suffix)
	for i = from, to do K.Item(_G[prefix .. i .. (suffix or '')]) end
end

-- Light text for windows whose text Blizzard draws dark on parchment.
local function Light(fs, gold)
	if fs and fs.SetTextColor then
		local c = gold and K.GOLD or K.TEXT
		fs:SetTextColor(c[1], c[2], c[3])
		if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0.9) end
	end
end

-- Character sheet, reputation, currency and the equipment manager.
local SLOTS = { 'Head', 'Neck', 'Shoulder', 'Back', 'Chest', 'Shirt', 'Tabard', 'Wrist', 'Hands', 'Waist', 'Legs', 'Feet',
	'Finger0', 'Finger1', 'Trinket0', 'Trinket1', 'MainHand', 'SecondaryHand' }

local function PaperDollSlots(prefix)
	for _, slot in ipairs(SLOTS) do
		local button = _G[prefix .. slot .. 'Slot']
		if button then
			K.Item(button)
			K.Hide(_G[prefix .. slot .. 'SlotFrame'])
		end
	end
end

local function ModelBackground(scene)
	if not scene then return end
	for _, key in ipairs({ 'BackgroundTopLeft', 'BackgroundTopRight', 'BackgroundBotLeft', 'BackgroundBotRight', 'BackgroundOverlay' }) do
		K.Hide(scene[key])
	end
end

K.Register('character', nil, 'CharacterFrame', function(frame)
	K.Window(frame)
	K.Inset(frame.InsetRight or _G.CharacterFrameInsetRight)
	HideNamed('PaperDollInnerBorder', { 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight', 'Left', 'Right', 'Top', 'Bottom', 'Bottom2' })
	K.Hide(_G.PaperDollSidebarTabs and _G.PaperDollSidebarTabs.DecorLeft)
	K.Hide(_G.PaperDollSidebarTabs and _G.PaperDollSidebarTabs.DecorRight)
	ModelBackground(_G.CharacterModelScene)
	PaperDollSlots('Character')
	K.Auto(_G.ReputationFrame)
	K.Auto(_G.TokenFrame)
	K.Auto(_G.PaperDollFrame)
end)

K.Register('inspect', 'Blizzard_InspectUI', 'InspectFrame', function(frame)
	K.Window(frame)
	ModelBackground(_G.InspectModelFrame)
	PaperDollSlots('Inspect')
end)

-- Spellbook and talents.
K.Register('spellbook', 'Blizzard_PlayerSpells', 'PlayerSpellsFrame', function(frame)
	K.Window(frame)
	if frame.TabSystem then K.Auto(frame.TabSystem) end
end)

-- Group Finder: dungeons, raids, premade groups; PvP comes with its own addon.
K.Register('groupfinder', nil, 'PVEFrame', function(frame)
	K.Window(frame)
	K.Inset(_G.PVEFrameLeftInset)
	K.Hide(frame.shadows)
	if _G.LFGListFrame and _G.LFGListFrame.SearchPanel then K.Auto(_G.LFGListFrame.SearchPanel) end
end)
K.Register('groupfinder', 'Blizzard_PVPUI', 'PVPUIFrame', function(frame)
	K.Auto(frame)
end)

-- Great Vault: flat rows, a gold line on the left of the unlocked slots.
local function VaultSlot(activity)
	if K.Done(activity, 'vault') then return end
	K.Hide(activity.Background)
	K.Hide(activity.Border)
	K.Box(activity, ROW)
	local gold = K.Fill(activity, K.GOLD, 'BACKGROUND', -5)
	gold:SetPoint('TOPLEFT')
	gold:SetPoint('BOTTOMLEFT')
	gold:SetWidth(2 * ns.Px())
	local function state() gold:SetShown(activity.unlocked and true or false) end
	if activity.Refresh then hooksecurefunc(activity, 'Refresh', state) end
	state()
end

K.Register('vault', 'Blizzard_WeeklyRewards', 'WeeklyRewardsFrame', function(frame)
	for _, key in ipairs({ 'Background', 'BorderShadow', 'BorderContainer', 'Blackout' }) do K.Hide(frame[key]) end
	if frame.HeaderFrame then K.Strip(frame.HeaderFrame) end
	K.Panel(frame, { header = 44 })
	if frame.CloseButton then K.Close(frame.CloseButton) end
	for _, activity in ipairs(frame.Activities or {}) do VaultSlot(activity) end
	K.Auto(frame)
end)

-- Adventure Guide.
K.Register('journal', 'Blizzard_EncounterJournal', 'EncounterJournal', function(frame)
	K.Window(frame)
	K.Inset(_G.EncounterJournalInset)
end)

-- Collections: mounts, pets, toys, heirlooms, appearances, and the transmogrifier.
K.Register('collections', 'Blizzard_Collections', { 'CollectionsJournal', 'WardrobeFrame' }, function(frame)
	K.Window(frame)
end)

-- Achievements: the parchment and the wood and metal frame go, the rows get a flat box.
local function AchievementRow(row)
	K.Hide(row.Background)
	K.Hide(row.BottomLeftTsunami)
	K.Hide(row.BottomRightTsunami)
	K.Hide(row.TopLeftTsunami)
	K.Hide(row.TopRightTsunami)
	K.Hide(row.BottomTsunami1)
	K.Hide(row.TopTsunami1)
	K.Hide(row.Glow)
	if row.TitleBar then K.Hide(row.TitleBar) end
	K.Box(row, ROW, { 2, 2, 2, 2 })
	Light(row.Description)
	Light(row.HiddenDescription)
end

K.Register('achievements', 'Blizzard_AchievementUI', 'AchievementFrame', function(frame)
	K.Hide(frame.Background)
	HideNamed('AchievementFrame', { 'MetalBorderLeft', 'MetalBorderRight', 'MetalBorderBottom', 'MetalBorderTop',
		'MetalBorderTopLeft', 'MetalBorderTopRight', 'MetalBorderBottomLeft', 'MetalBorderBottomRight',
		'WoodBorderTopLeft', 'WoodBorderTopRight', 'WoodBorderBottomLeft', 'WoodBorderBottomRight',
		'CategoriesBG', 'WaterMark', 'GuildEmblemLeft', 'GuildEmblemRight' })
	if frame.Header then
		K.Hide(frame.Header.Left)
		K.Hide(frame.Header.Right)
		K.Hide(frame.Header.PointBorder)
	end
	K.Hide(_G.AchievementFrameAchievements and _G.AchievementFrameAchievements.Background)
	K.Hide(_G.AchievementFrameSummary and _G.AchievementFrameSummary.Background)
	K.Hide(_G.AchievementFrameStatsBG)
	K.Panel(frame, { header = 40, strip = false })
	K.Auto(frame)
	local list = _G.AchievementFrameAchievements
	if list and list.ScrollBox then K.ScrollRows(list.ScrollBox, AchievementRow) end
end)

-- Friends, or BetterFriendlist's window when it is installed (both use the same Blizzard frame template).
local function FriendsWindow()
	if C_AddOns.IsAddOnLoaded('BetterFriendlist') and _G.BetterFriendsFrame then return _G.BetterFriendsFrame end
	return _G.FriendsFrame
end
K.Register('friends', nil, { FriendsWindow }, function(frame)
	K.Window(frame)
end)

-- Guild and communities, the calendar.
K.Register('guild', nil, 'CommunitiesFrame', function(frame)
	K.Window(frame)
	if frame.ChatTab then K.Auto(frame.ChatTab) end
end)

K.Register('guild', 'Blizzard_Calendar', 'CalendarFrame', function(frame)
	K.Strip(frame)
	K.Panel(frame, { header = 40, strip = false })
	for i = 1, 42 do
		local day = _G['CalendarDayButton' .. i]
		if day then
			K.Hide(_G['CalendarDayButton' .. i .. 'Background'])
			local normal = day.GetNormalTexture and day:GetNormalTexture()
			if normal then normal:SetAlpha(0) end
			K.Box(day, ROW, { 1, 1, 1, 1 })
		end
	end
	K.Auto(frame)
end)

-- Mail: inbox, send, the open letter.
K.Register('mail', nil, { 'MailFrame', 'OpenMailFrame' }, function(frame)
	K.Window(frame)
	if frame == _G.MailFrame then
		for i = 1, 7 do
			K.Item(_G['MailItem' .. i .. 'Button'])
			K.Hide(_G['MailItem' .. i .. 'ButtonSlot'])
		end
		K.Auto(_G.SendMailFrame)
	else
		K.Hide(_G.OpenMailFrameIcon)
		Light(_G.OpenMailBodyText)
	end
end)

-- World map and quest log.
-- The border frame lies above the map (strata HIGH), so it gets only edges and the header;
-- the dark fill goes on the map window itself, under the map.
K.Register('map', nil, 'WorldMapFrame', function(frame)
	K.Box(frame, K.BODY)
	local border = frame.BorderFrame
	if border then
		for _, key in ipairs({ 'NineSlice', 'Bg', 'TopTileStreaks', 'PortraitContainer', 'portrait' }) do K.Hide(border[key]) end
		K.Rim(border, 22)
		if border.CloseButton then K.Close(border.CloseButton) end
		local title = border.TitleContainer and border.TitleContainer.TitleText
		if title then title:SetTextColor(K.TEXT[1], K.TEXT[2], K.TEXT[3]) end
		K.Auto(border)
	end
	K.Auto(_G.QuestMapFrame)
end)

-- Gossip and quest windows: the parchment goes and the text turns light.
local QUEST_TEXT = { 'QuestInfoDescriptionText', 'QuestInfoObjectivesText', 'QuestInfoGroupSize', 'QuestInfoRewardText',
	'QuestInfoSpellObjectiveLearnLabel', 'QuestProgressText', 'QuestProgressRequiredItemsText', 'QuestProgressRequiredMoneyText',
	'GreetingText', 'CurrentQuestsText', 'AvailableQuestsText', 'QuestInfoXPFrameReceiveText', 'QuestInfoRewardsFrameReceiveText' }
local QUEST_HEADERS = { 'QuestInfoTitleHeader', 'QuestInfoDescriptionHeader', 'QuestInfoObjectivesHeader', 'QuestProgressTitleText' }

local function QuestColors()
	for _, name in ipairs(QUEST_TEXT) do Light(_G[name]) end
	for _, name in ipairs(QUEST_HEADERS) do Light(_G[name], true) end
	local rewards = _G.QuestInfoRewardsFrame
	if rewards then
		Light(rewards.Header, true)
		Light(rewards.ItemChooseText)
		Light(rewards.ItemReceiveText)
		Light(rewards.PlayerTitleText)
		Light(rewards.XPFrame and rewards.XPFrame.ReceiveText)
	end
	for i = 1, 12 do
		local line = _G['QuestInfoObjective' .. i]
		if not line then break end
		Light(line)
	end
end

local questHooked = false
K.Register('gossip', nil, { 'GossipFrame', 'QuestFrame', 'ItemTextFrame' }, function(frame)
	K.Window(frame)
	if frame == _G.GossipFrame then
		K.Hide(frame.Background)
		local panel = frame.GreetingPanel
		if panel then
			K.Hide(panel.Bg)
			K.ScrollRows(panel.ScrollBox, function(row)
				Light(row.GreetingText)
				local text = row.GetFontString and row:GetFontString()
				Light(text)
			end)
		end
	elseif frame == _G.QuestFrame then
		for _, name in ipairs({ 'QuestFrameDetailPanel', 'QuestFrameRewardPanel', 'QuestFrameProgressPanel', 'QuestFrameGreetingPanel' }) do
			local panel = _G[name]
			if panel then
				K.Hide(panel.Bg)
				K.Hide(panel.SealMaterialBG)
			end
		end
		if not questHooked and _G.QuestInfo_Display then
			questHooked = true
			hooksecurefunc('QuestInfo_Display', QuestColors)
		end
		if _G.QuestFrameGreetingPanel then hooksecurefunc(_G.QuestFrameGreetingPanel, 'Show', QuestColors) end
		QuestColors()
	else
		Light(_G.ItemTextPageText)
		K.Hide(_G.ItemTextMaterialTopLeft)
	end
end)

-- The talking head: a flat dark bar, square portrait, gold name. Blizzard animates the
-- alpha of its art, so the art is hidden instead of faded.
K.Register('talkinghead', nil, 'TalkingHeadFrame', function(frame)
	local main = frame.MainFrame
	if frame.BackgroundFrame then K.Kill(frame.BackgroundFrame.TextBackground) end
	if frame.PortraitFrame then K.Kill(frame.PortraitFrame.Portrait) end
	if main then
		K.Kill(main.Sheen)
		K.Kill(main.TextSheen)
		if main.Overlay then
			K.Kill(main.Overlay.Glow_TopBar)
			K.Kill(main.Overlay.Glow_LeftBar)
			K.Kill(main.Overlay.Glow_RightBar)
		end
		if main.Model then
			K.Kill(main.Model.PortraitBg)
			local px = ns.Px()
			local edge = main.Model:CreateTexture(nil, 'BACKGROUND', nil, -8)
			edge:SetColorTexture(0, 0, 0, 1)
			edge:SetPoint('TOPLEFT', -px, px)
			edge:SetPoint('BOTTOMRIGHT', px, -px)
		end
		if main.CloseButton then K.Close(main.CloseButton) end
	end
	local holder = CreateFrame('Frame', nil, frame)
	holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
	holder:SetPoint('TOPLEFT', 12, -12)
	holder:SetPoint('BOTTOMRIGHT', -12, 12)
	K.Body(holder)
	if frame.NameFrame and frame.NameFrame.Name then
		local c = K.GOLD
		frame.NameFrame.Name:SetTextColor(c[1], c[2], c[3])
		hooksecurefunc(frame.NameFrame.Name, 'SetTextColor', function(self, r)
			if r ~= c[1] then self:SetTextColor(c[1], c[2], c[3]) end
		end)
	end
end)

-- Merchant (SlimARK's two-page vendor keeps working) and bank.
local function MerchantSlot(i)
	local slot = _G['MerchantItem' .. i]
	if not slot or K.Done(slot, 'merchant') then return end
	K.Hide(_G['MerchantItem' .. i .. 'SlotTexture'])
	K.Hide(_G['MerchantItem' .. i .. 'NameFrame'])
	K.Box(slot, ROW)
	K.Item(_G['MerchantItem' .. i .. 'ItemButton'])
end

K.Register('merchant', nil, { 'MerchantFrame', 'BankFrame' }, function(frame)
	K.Window(frame)
	if frame == _G.MerchantFrame then
		for i = 1, 20 do MerchantSlot(i) end
		K.Item(_G.MerchantBuyBackItemItemButton)
		K.Hide(_G.MerchantBuyBackItemSlotTexture)
		K.Hide(_G.MerchantBuyBackItemNameFrame)
		HideNamed('MerchantFrame', { 'BottomLeftBorder', 'BottomRightBorder' })
		HideNamed('Merchant', { 'MoneyInset', 'MoneyBg', 'ExtraCurrencyInset', 'ExtraCurrencyBg' })
		local function dressItems() for i = 1, 20 do MerchantSlot(i) end end
		if _G.MerchantFrame_Update then hooksecurefunc('MerchantFrame_Update', dressItems) end
	else
		local panel = _G.BankPanel
		if panel then
			K.Auto(panel)
			local function dressItems()
				if panel.EnumerateValidItems then
					for _, item in panel:EnumerateValidItems() do K.Item(item) end
				end
			end
			if panel.GenerateItemSlotsForSelectedTab then hooksecurefunc(panel, 'GenerateItemSlotsForSelectedTab', dressItems) end
			dressItems()
		end
	end
end)

-- Auction house and trade.
K.Register('auction', 'Blizzard_AuctionHouseUI', 'AuctionHouseFrame', function(frame)
	K.Window(frame)
end)
K.Register('auction', nil, 'TradeFrame', function(frame)
	K.Window(frame)
	for i = 1, 7 do
		K.Item(_G['TradePlayerItem' .. i .. 'ItemButton'])
		K.Item(_G['TradeRecipientItem' .. i .. 'ItemButton'])
		K.Hide(_G['TradePlayerItem' .. i .. 'SlotTexture'])
		K.Hide(_G['TradeRecipientItem' .. i .. 'SlotTexture'])
		K.Hide(_G['TradePlayerItem' .. i .. 'NameFrame'])
		K.Hide(_G['TradeRecipientItem' .. i .. 'NameFrame'])
	end
	HideNamed('Trade', { 'RecipientItemsInset', 'PlayerItemsInset', 'RecipientEnchantInset', 'PlayerEnchantInset', 'RecipientMoneyInset', 'PlayerInputMoneyInset', 'RecipientMoneyBg', 'PlayerInputMoneyBg' })
end)

-- Professions.
K.Register('professions', 'Blizzard_Professions', 'ProfessionsFrame', function(frame)
	K.Window(frame)
	if frame.TabSystem then K.Auto(frame.TabSystem) end
end)

-- The game menu (Esc) and Blizzard's pop-up dialogs.
local function MenuButtons(menu)
	for _, child in ipairs({ menu:GetChildren() }) do
		if child:GetObjectType() == 'Button' and child.GetFontString and child:GetFontString() and child ~= menu.CloseButton then
			K.Button(child)
		end
	end
end

K.Register('menu', nil, 'GameMenuFrame', function(frame)
	K.Hide(frame.Border)
	if frame.Header then K.Strip(frame.Header) end
	K.Panel(frame, { header = 30 })
	MenuButtons(frame)
	if frame.InitButtons then hooksecurefunc(frame, 'InitButtons', MenuButtons) end
end)

local function Dialog(dialog)
	K.Hide(dialog.Border)
	K.Hide(dialog.BG)
	K.Panel(dialog, { strip = false })
	if dialog.GetButtons then
		for _, button in ipairs(dialog:GetButtons()) do K.Button(button) end
	end
	if dialog.GetEditBox then K.Edit(dialog:GetEditBox()) end
	if dialog.GetItemFrame and dialog:GetItemFrame().Item then K.Item(dialog:GetItemFrame().Item) end
	if dialog.CloseButton then K.Close(dialog.CloseButton) end
end
K.Register('menu', nil, { 'StaticPopup1', 'StaticPopup2', 'StaticPopup3', 'StaticPopup4' }, Dialog)

-- Blizzard's own bags, only when BetterBags does not handle them.
local function BagItems(bag)
	if bag.EnumerateValidItems then
		for _, item in bag:EnumerateValidItems() do K.Item(item) end
	end
end

local function Bag(bag)
	K.Window(bag)
	BagItems(bag)
	if bag.UpdateItems then hooksecurefunc(bag, 'UpdateItems', BagItems) end
end

local BAGS = { 'ContainerFrameCombinedBags' }
for i = 1, 6 do table.insert(BAGS, 'ContainerFrame' .. i) end
K.Register('bags', nil, BAGS, function(bag)
	if C_AddOns.IsAddOnLoaded('BetterBags') then return end
	Bag(bag)
end)
