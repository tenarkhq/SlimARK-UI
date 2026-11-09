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
		-- pcall: SimpleHTML (the mail body) takes an optional text type before the color.
		pcall(fs.SetTextColor, fs, c[1], c[2], c[3])
		if fs.SetShadowColor and fs:GetObjectType() ~= 'SimpleHTML' then fs:SetShadowColor(0, 0, 0, 0.9) end
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
	-- The stats beside the model: the class picture goes, the section titles get a flat band.
	local stats = _G.CharacterStatsPane
	if stats then
		K.Hide(stats.ClassBackground)
		for _, key in ipairs({ 'ItemLevelCategory', 'AttributesCategory', 'EnhancementsCategory' }) do
			local category = stats[key]
			if category then
				K.Hide(category.Background)
				K.Box(category, K.BUTTON, { 0, 2, 0, 2 })
			end
		end
	end
	K.Auto(_G.ReputationFrame)
	K.Auto(_G.TokenFrame)
	K.Auto(_G.PaperDollFrame)
end)

K.Register('inspect', 'Blizzard_InspectUI', 'InspectFrame', function(frame)
	K.Window(frame)
	ModelBackground(_G.InspectModelFrame)
	HideNamed('InspectModelFrameBorder', { 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight', 'Left', 'Right', 'Top', 'Bottom', 'Bottom2' })
	PaperDollSlots('Inspect')
end)

-- Spellbook and talents.
-- The book's parchment goes; its names are drawn in Blizzard's dark book color, so they turn light.
local function SpellRow(row)
	K.Hide(row.Backplate)
	if row.Text then
		Light(row.Text, true)
		K.Hide(row.Border)
	end
	Light(row.Name)
	Light(row.SubName)
	Light(row.RequiredLevel)
	if row.SubName then row.SubName:SetTextColor(K.SOFT[1], K.SOFT[2], K.SOFT[3]) end
	if row.RequiredLevel then row.RequiredLevel:SetTextColor(K.SOFT[1], K.SOFT[2], K.SOFT[3]) end
end

local function SpellBook(book)
	if not book then return end
	for _, key in ipairs({ 'TopBar', 'BookBGHalved', 'BookBGLeft', 'BookBGRight', 'BookCornerFlipbook', 'Bookmark' }) do K.Hide(book[key]) end
	K.Auto(book)
	local paged = book.PagedSpellsFrame
	if paged then
		local function rows() if paged.ForEachFrame then paged:ForEachFrame(SpellRow) end end
		if paged.DisplayViewsForCurrentPage then hooksecurefunc(paged, 'DisplayViewsForCurrentPage', rows) end
		rows()
		if paged.PagingControls then Light(paged.PagingControls.PageText) end
	end
end

K.Register('spellbook', 'Blizzard_PlayerSpells', 'PlayerSpellsFrame', function(frame)
	K.Window(frame)
	if frame.TabSystem then K.Auto(frame.TabSystem) end
	SpellBook(frame.SpellBookFrame)
	-- Talents: the spec picture behind the tree stays, the bottom bar goes.
	if frame.TalentsFrame then K.Hide(frame.TalentsFrame.BottomBar) end
	-- Specializations: the dark picture behind the three columns goes, our body shows.
	if frame.SpecFrame then
		K.Hide(frame.SpecFrame.Background)
		K.Hide(frame.SpecFrame.BlackBG)
	end
end)

-- Group Finder: dungeons, raids, premade groups; PvP comes with its own addon.
-- The finders' parchment and blue backgrounds go; their reward text is already light.
local FINDER_ART = { 'LFDParentFrameRoleBackground', 'LFDQueueFrameBackground', 'RaidFinderFrameRoleBackground',
	'RaidFinderQueueFrameBackground', 'ScenarioQueueFrameBackground' }

-- Premade group categories: the picture stays, its frame becomes a black edge, the selected
-- one gets a gold edge.
local function LFGCategory(button)
	if not button or K.Done(button, 'lfgcategory') then return end
	K.Hide(button.Cover)
	local px = ns.Px()
	local edge = {}
	for _, p in ipairs({ { 'TOPLEFT', 'TOPRIGHT', nil, px }, { 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, px }, { 'TOPLEFT', 'BOTTOMLEFT', px }, { 'TOPRIGHT', 'BOTTOMRIGHT', px } }) do
		local t = button:CreateTexture(nil, 'OVERLAY', nil, 7)
		t:SetColorTexture(0, 0, 0, 1)
		t:SetPoint(p[1], button.Icon or button, p[1])
		t:SetPoint(p[2], button.Icon or button, p[2])
		if p[3] then t:SetWidth(p[3]) end
		if p[4] then t:SetHeight(p[4]) end
		table.insert(edge, t)
	end
	local function state()
		local on = button.SelectedTexture and button.SelectedTexture:IsShown()
		for _, t in ipairs(edge) do
			if on then t:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1) else t:SetColorTexture(0, 0, 0, 1) end
		end
	end
	if button.SelectedTexture then
		button.SelectedTexture:SetAlpha(0)
		hooksecurefunc(button.SelectedTexture, 'SetShown', state)
		hooksecurefunc(button.SelectedTexture, 'Show', state)
		hooksecurefunc(button.SelectedTexture, 'Hide', state)
	end
	local hl = button.GetHighlightTexture and button:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.08)
		hl:ClearAllPoints()
		hl:SetAllPoints(button.Icon or button)
	end
	state()
end

local function GroupButtons(selectedIndex)
	local finder = _G.GroupFinderFrame
	if not finder then return end
	for i = 1, 4 do
		local button = finder['groupButton' .. i]
		local select = K.Category(button, { 'bg', 'ring' })
		if select then select(i == (selectedIndex or finder.selectionIndex)) end
	end
end

K.Register('groupfinder', nil, 'PVEFrame', function(frame)
	K.Window(frame)
	K.Inset(_G.PVEFrameLeftInset)
	K.Hide(frame.shadows)
	GroupButtons()
	if _G.GroupFinderFrame_SelectGroupButton then hooksecurefunc('GroupFinderFrame_SelectGroupButton', GroupButtons) end
	for _, name in ipairs(FINDER_ART) do K.Hide(_G[name]) end
	K.Hide(_G.LFDParentFrame and _G.LFDParentFrame.TopTileStreaks)
	for _, name in ipairs({ 'LFDParentFrameInset', 'RaidFinderFrameRoleInset', 'RaidFinderFrameBottomInset', 'ScenarioFinderFrameInset' }) do K.Inset(_G[name]) end
	K.Strip(_G.ScenarioFinderFrame)
	K.Auto(_G.LFDParentFrame)
	K.Auto(_G.RaidFinderFrame)
	K.Auto(_G.ScenarioFinderFrame)
	local list = _G.LFGListFrame
	if list then
		K.Auto(list)
		local selection = list.CategorySelection
		if selection then
			for _, button in ipairs(selection.CategoryButtons or {}) do LFGCategory(button) end
			if _G.LFGListCategorySelection_AddButton then
				hooksecurefunc('LFGListCategorySelection_AddButton', function(owner, index)
					LFGCategory(owner and owner.CategoryButtons and owner.CategoryButtons[index])
				end)
			end
		end
	end
end)

-- PvP: the same category buttons, the queue buttons flat, the backgrounds gone.
local function PVPButtons(selectedIndex)
	local queue = _G.PVPQueueFrame
	if not queue then return end
	for i, button in ipairs(queue.CategoryButtons or {}) do
		local select = K.Category(button, { 'Background', 'Ring' })
		if select then select(i == selectedIndex) end
	end
end

K.Register('groupfinder', 'Blizzard_PVPUI', 'PVPUIFrame', function(frame)
	K.Auto(frame)
	PVPButtons(1)
	if _G.PVPQueueFrame_SelectButton then hooksecurefunc('PVPQueueFrame_SelectButton', PVPButtons) end
	local queue = _G.PVPQueueFrame
	if queue and queue.HonorInset then K.Inset(queue.HonorInset) end
	local honor, conquest, training = _G.HonorFrame, _G.ConquestFrame, _G.TrainingGroundsFrame
	if honor and honor.BonusFrame then
		local bonus = honor.BonusFrame
		K.Hide(bonus.WorldBattlesTexture)
		K.Hide(bonus.ShadowOverlay)
		for _, key in ipairs({ 'RandomBGButton', 'RandomEpicBGButton', 'Arena1Button', 'BrawlButton', 'BrawlButton2' }) do K.Activity(bonus[key]) end
	end
	if conquest then
		K.Hide(conquest.RatedBGTexture)
		K.Hide(conquest.ShadowOverlay)
		for _, key in ipairs({ 'RatedSoloShuffle', 'RatedBGBlitz', 'Arena2v2', 'Arena3v3', 'RatedBG' }) do K.Activity(conquest[key]) end
	end
	if training and training.BonusTrainingGroundList then
		local bonus = training.BonusTrainingGroundList
		K.Hide(bonus.WorldBattlesTexture)
		K.Hide(bonus.ShadowOverlay)
		for _, button in ipairs(bonus.BonusTrainingGroundButtons or {}) do K.Activity(button) end
	end
	for _, panel in ipairs({ honor, conquest, training, _G.PlunderstormFrame }) do
		if panel and panel.Inset then K.Inset(panel.Inset) end
	end
	if _G.PlunderstormFrame then K.Hide(_G.PlunderstormFrame.Background) end
end)

-- Mythic+: the season picture goes; the dungeon icons keep their pictures with a black edge.
local function DungeonIcons(challenges)
	for _, icon in ipairs(challenges.DungeonIcons or {}) do
		if not K.Done(icon, 'dungeon') then
			K.Strip(icon, { [icon.Icon or false] = true })
			if icon.Icon and icon.Icon.SetTexCoord then icon.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
			ns.Edge(icon, 1, { 0, 0, 0, 1 }, ns.Px())
		end
	end
end

K.Register('groupfinder', 'Blizzard_ChallengesUI', 'ChallengesFrame', function(frame)
	K.Strip(frame)
	K.Inset(_G.ChallengesFrameInset)
	K.Auto(frame)
	DungeonIcons(frame)
	if frame.Update then hooksecurefunc(frame, 'Update', DungeonIcons) end
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
	for _, key in ipairs({ 'Background', 'BorderShadow', 'BorderContainer', 'Blackout', 'Divider1', 'Divider2' }) do K.Hide(frame[key]) end
	if frame.HeaderFrame then K.Strip(frame.HeaderFrame) end
	K.Panel(frame, { header = 44 })
	if frame.CloseButton then K.Close(frame.CloseButton) end
	-- The raid, dungeon, world and PvP rows: their picture and frame go.
	for _, key in ipairs({ 'RaidFrame', 'MythicFrame', 'PVPFrame', 'WorldFrame' }) do
		local row = frame[key]
		if row then
			K.Hide(row.Background)
			K.Hide(row.Border)
		end
	end
	if frame.SelectRewardButton then K.Hide(frame.SelectRewardButton.Background) end
	for _, activity in ipairs(frame.Activities or {}) do VaultSlot(activity) end
	K.Auto(frame)
end)

-- Adventure Guide. The pages of a dungeon or a boss stay on their parchment: Blizzard writes
-- their text in black, the way the quest log on the map does.

-- A card Blizzard draws with an atlas and lights with the same atlas again
-- (AlphaHighlightButtonTemplate): the atlas goes, a flat box comes, the hover is a light film.
local function FlatCard(button)
	if not button or K.Done(button, 'card') then return end
	K.Hide(button.NormalTexture or button:GetNormalTexture())
	K.Hide(button.PushedTexture or button:GetPushedTexture())
	local fill = K.Box(button, ROW, { 2, 2, 2, 2 })
	local function Film(b)
		local hl = b:GetHighlightTexture()
		if hl then
			hl:SetColorTexture(1, 1, 1, 0.06)
			hl:ClearAllPoints()
			hl:SetAllPoints(fill)
		end
	end
	if button.UpdateHighlightForState then hooksecurefunc(button, 'UpdateHighlightForState', Film) end
	Film(button)
end

-- A flat bar box behind a status bar whose frame and background were atlases.
local function FlatBar(bar, bg, border)
	if not bar or K.Done(bar, 'bar') then return end
	K.Hide(bg)
	K.Hide(border)
	K.Box(bar, K.FIELD)
end

-- The path at the top (Home > Dungeons > ...): the help-window art goes, each step is a flat box.
local function NavButton(button)
	if not button or K.Done(button, 'nav') then return end
	K.Hide(button:GetNormalTexture())
	K.Hide(button:GetPushedTexture())
	K.Hide(button.arrowUp)
	K.Hide(button.arrowDown)
	K.Hide(button.selected)
	local name = button.GetName and button:GetName()
	if name then K.Hide(_G[name .. 'Left']) end
	local fill = K.Box(button, K.BUTTON, { 0, 1, 1, 1 })
	local hl = button:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.06)
		hl:ClearAllPoints()
		hl:SetAllPoints(fill)
	end
	local arrow = button.MenuArrowButton
	if arrow then
		K.Hide(arrow.NormalTexture)
		K.Hide(arrow.PushedTexture)
	end
end

local function NavBar(bar)
	if not bar or K.Done(bar, 'navbar') then return end
	K.Strip(bar)
	K.Strip(bar.overlay)
	K.Box(bar, K.FIELD)
	NavButton(bar.home)
	for _, button in ipairs(bar.navList or {}) do NavButton(button) end
	hooksecurefunc('NavBar_AddButton', function(self)
		if self == bar and self.navList then NavButton(self.navList[#self.navList]) end
	end)
end

-- A dungeon or raid in the list: the gold frame goes, the picture keeps a black edge.
local function InstanceButton(button)
	if not button.bgImage then return end
	K.Hide(button:GetNormalTexture())
	K.Hide(button:GetPushedTexture())
	ns.Edge(button, 1, { 0, 0, 0, 1 }, ns.Px(), button.bgImage)
	local hl = button:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.08)
		hl:ClearAllPoints()
		hl:SetAllPoints(button.bgImage)
	end
end

-- Journeys: renown and other journey cards, the category lines and the open journey page.
local function JourneyRow(row)
	if row.RenownCardFactionName then
		FlatCard(row)
	elseif row.JourneyCardProgressBar then
		FlatCard(row)
		local bar = row.JourneyCardProgressBar
		FlatBar(bar, bar.JourneyCardProgressBarBG, bar.JourneyCardProgressBarFrame)
	elseif row.CategoryDivider then
		K.Hide(row.CategoryDivider)
		local line = K.Fill(row, { 0.169, 0.176, 0.208, 1 }, 'ARTWORK')
		line:SetPoint('LEFT', 8, 0)
		line:SetPoint('RIGHT', -8, 0)
		line:SetHeight(ns.Px())
	end
end

local function Journeys(journeys)
	if not journeys then return end
	if journeys.BorderFrame then
		K.Hide(journeys.BorderFrame.Border)
		K.Hide(journeys.BorderFrame.TopDetail)
	end
	K.ScrollRows(journeys.JourneysList, JourneyRow)
	local progress = journeys.JourneyProgress
	if progress then
		K.Hide(progress.DividerTexture)
		K.Hide(progress.DividerGlowTexture)
		local bar = progress.DelveRewardProgressBar
		if bar then FlatBar(bar, bar.DelveRewardProgressBarBG, bar.DelveRewardProgressBarFrame) end
	end
	local overview = journeys.JourneyOverview
	if overview then
		K.Hide(overview.DividerTexture)
		K.Hide(overview.DividerGlowTexture)
	end
	K.Auto(journeys)
end

-- Traveler's Log: the themed border, the paper and the shadows go; the bar and its chest stay.
local function ActivityRow(row)
	if not row.NormalTexture then return end
	K.Hide(row.NormalTexture)
	local fill = K.Box(row, ROW, { 0, 1, 0, 1 })
	local hl = row.HighlightTexture or row:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.06)
		hl:ClearAllPoints()
		hl:SetAllPoints(fill)
	end
end

local function TravelersLog(log)
	if not log then return end
	for _, key in ipairs({ 'Bg', 'DividerVertical', 'ShadowLeft', 'ShadowRight', 'Divider' }) do K.Hide(log[key]) end
	if log.ThemeContainer then
		for _, key in ipairs({ 'Top', 'Bottom', 'Left', 'Right', 'FilterList' }) do K.Hide(log.ThemeContainer[key]) end
	end
	if log.FilterList then
		K.Hide(log.FilterList.Bg)
		K.Box(log.FilterList, K.INSET)
	end
	K.ScrollRows(log.ScrollBox, ActivityRow)
	K.Auto(log)
end

-- Suggested Content: the stone panes go, each suggestion is a flat box.
local function Suggestions(suggest)
	if not suggest then return end
	for i = 1, 3 do
		local pane = suggest['Suggestion' .. i]
		if pane and pane.bg then
			K.Hide(pane.bg)
			K.Box(pane, ROW, { 0, 0, 0, 0 })
		end
	end
	K.Auto(suggest)
end

K.Register('journal', 'Blizzard_EncounterJournal', 'EncounterJournal', function(frame)
	K.Window(frame)
	K.Inset(_G.EncounterJournalInset)
	NavBar(frame.navBar)
	local select = frame.instanceSelect
	if select then
		-- The expansion picture and the stone of Journeys (one texture, its atlas changes).
		K.Hide(select.bg)
		K.Hide(select.evergreenBg)
		K.ScrollRows(select.ScrollBox, InstanceButton)
	end
	Journeys(frame.JourneysFrame)
	TravelersLog(frame.MonthlyActivitiesFrame)
	Suggestions(frame.suggestFrame)
	-- Item sets: the paper behind the tab and behind each set goes; the item frames keep quality.
	if frame.LootJournal then K.Strip(frame.LootJournal) end
	local items = frame.LootJournalItems
	if items then
		K.Strip(items)
		if items.ItemSetsFrame then
			K.ScrollRows(items.ItemSetsFrame.ScrollBox, function(row)
				if row.Background then
					K.Hide(row.Background)
					K.Box(row, ROW, { 0, 1, 0, 1 })
				end
			end)
		end
		K.Auto(items)
	end
	-- Tutorials: the picture stays, the ornate line under it goes.
	if frame.TutorialsFrame and frame.TutorialsFrame.Contents then K.Hide(frame.TutorialsFrame.Contents.Divider) end
end)

-- Collections: mounts, pets, toys, heirlooms, appearances; the transmogrifier is its own addon in 12.x.
-- A flat box (black edge and fill) laid over the place of one of Blizzard's textures.
local function BoxOn(frame, region, color)
	local px = ns.Px()
	local edge = K.Fill(frame, { 0, 0, 0, 1 }, 'BACKGROUND', -7)
	edge:SetPoint('TOPLEFT', region, 'TOPLEFT', -px, px)
	edge:SetPoint('BOTTOMRIGHT', region, 'BOTTOMRIGHT', px, -px)
	local fill = K.Fill(frame, color, 'BACKGROUND', -6)
	fill:SetAllPoints(region)
	return fill
end

-- A list row whose paper strip sits beside its icon (mounts, pets, appearance sets): a flat box
-- on the strip's place, the hover a light film and the selected row a gold film on it.
local function StripRow(row)
	local strip = row.background or row.Background
	if not strip or K.Done(row, 'striprow') then return end
	K.Hide(strip)
	BoxOn(row, strip, ROW)
	local selected = row.selectedTexture or row.SelectedTexture
	if selected then
		selected:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 0.14)
		selected:ClearAllPoints()
		selected:SetAllPoints(strip)
	end
	local hl = row.GetHighlightTexture and row:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.06)
		hl:ClearAllPoints()
		hl:SetAllPoints(strip)
	end
end

-- The collected-count bars of toys, heirlooms and appearances.
local function CollectionBar(bar)
	if not bar or K.Done(bar, 'bar') then return end
	K.Hide(bar.border)
	K.Box(bar, K.FIELD)
end

local function PetJournal(pets)
	if not pets then return end
	K.ScrollRows(pets.ScrollBox, StripRow)
	K.Strip(pets.loadoutBorder)
	for i = 1, 3 do
		local slot = pets.Loadout and pets.Loadout['Pet' .. i]
		if slot then
			local name = slot:GetName()
			if name then K.Hide(_G[name .. 'BG']) end
			K.Hide(slot.shadows)
			K.Box(slot, ROW)
		end
	end
	local card = pets.PetCard
	if card then
		K.Strip(card)
		K.Box(card, ROW)
	end
	K.Strip(pets.AchievementStatus)
end

local function MountJournal(mounts)
	if not mounts then return end
	K.ScrollRows(mounts.ScrollBox, StripRow)
	-- The landscape behind the mount, like the backdrop behind the character model.
	if mounts.MountDisplay then K.Hide(mounts.MountDisplay.YesMountsTex) end
	local inset = mounts.BottomLeftInset
	if inset then
		K.Strip(inset)
		K.Hide(inset.Background)
	end
end

K.Register('collections', 'Blizzard_Collections', 'CollectionsJournal', function(frame)
	K.Window(frame)
	MountJournal(_G.MountJournal)
	PetJournal(_G.PetJournal)
	CollectionBar(_G.ToyBox and _G.ToyBox.progressBar)
	CollectionBar(_G.HeirloomsJournal and _G.HeirloomsJournal.progressBar)
	local wardrobe = _G.WardrobeCollectionFrame
	if wardrobe then
		CollectionBar(wardrobe.progressBar)
		local sets = wardrobe.SetsCollectionFrame
		if sets and sets.ListContainer then K.ScrollRows(sets.ListContainer.ScrollBox, StripRow) end
	end
end)

-- The transmogrifier (12.x): already dark; the extra dark layers, the ornate tab frame and the
-- divider lines go. Gear slots keep their frames: they show pending and saved states.
K.Register('collections', 'Blizzard_Transmog', 'TransmogFrame', function(frame)
	K.Window(frame)
	local outfits = frame.OutfitCollection
	if outfits then
		for _, key in ipairs({ 'Background', 'GradientTop', 'GradientBottom', 'DividerBar' }) do K.Hide(outfits[key]) end
		if outfits.OutfitList then
			K.Hide(outfits.OutfitList.DividerTop)
			K.Hide(outfits.OutfitList.DividerBottom)
		end
	end
	local wardrobe = frame.WardrobeCollection
	if wardrobe then
		K.Hide(wardrobe.Background)
		local content = wardrobe.TabContent
		if content then
			K.Hide(content.Background)
			K.Hide(content.Border)
			K.Box(content, K.INSET)
			if content.ItemsFrame then K.Hide(content.ItemsFrame.Divider) end
		end
	end
end)

-- Achievements. The wood frame and the gold edges are Blizzard backdrops (12.x), the panels are
-- parchment; all of it goes. Rows, categories, stats and the summary get flat boxes.
local function AchievementCard(card)
	if not card or K.Done(card, 'card') then return end
	K.NoBackdrop(card)
	for _, key in ipairs({ 'Background', 'BottomLeftTsunami', 'BottomRightTsunami', 'TopLeftTsunami', 'TopRightTsunami',
		'BottomTsunami1', 'TopTsunami1', 'Glow', 'TitleBar', 'RewardBackground', 'GuildCornerL', 'GuildCornerR' }) do
		K.Hide(card[key])
	end
	if card.GetName and card:GetName() then K.Hide(_G[card:GetName() .. 'Background']) end
	K.Box(card, ROW, { 2, 2, 2, 2 })
	Light(card.Description)
	Light(card.HiddenDescription)
end

local function AchievementRow(row)
	AchievementCard(row)
end

-- Category list: flat rows; Blizzard shows the selected one by locking the hover light.
local function AchievementCategory(row)
	local button = row.Button
	if not button or K.Done(button, 'achcategory') then return end
	K.Hide(button.Background)
	local fill = K.Box(button, ROW, { 0, 1, 0, 1 })
	local hl = button:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 0.12)
		hl:ClearAllPoints()
		hl:SetAllPoints(fill)
	end
end

-- Statistics rows: the striped button art goes, every second row stays a shade lighter.
local function AchievementStat(row)
	if K.Done(row, 'achstat') then return end
	for _, key in ipairs({ 'Background', 'Left', 'Right', 'Middle', 'Left2', 'Right2', 'Middle2' }) do K.Hide(row[key]) end
	K.Box(row, ROW, { 0, 1, 0, 1 })
end

-- Comparison rows: the player's and the friend's half are both cards.
local function AchievementComparison(row)
	AchievementCard(row.Player)
	AchievementCard(row.Friend)
end

-- Summary progress bars: the header art around the bar goes, a dark box goes under it.
local function SummaryBar(bar)
	if not bar or K.Done(bar, 'achbar') then return end
	local name = bar:GetName()
	if name then HideNamed(name, { 'Left', 'Right', 'Middle' }) end
	K.Hide(bar.Left)
	K.Hide(bar.Right)
	K.Hide(bar.Middle)
	K.Box(bar, K.FIELD)
end

local function SummaryAchievements()
	local holder = _G.AchievementFrameSummaryAchievements
	for _, button in ipairs(holder and holder.buttons or {}) do AchievementCard(button) end
end

K.Register('achievements', 'Blizzard_AchievementUI', 'AchievementFrame', function(frame)
	K.NoBackdrop(frame)
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
	if frame.HeaderDetails then K.Hide(frame.HeaderDetails.TopTileStreaks) end
	K.NoBackdrops(frame, 3)
	for _, name in ipairs({ 'AchievementFrameAchievements', 'AchievementFrameSummary', 'AchievementFrameComparison', 'AchievementFrameStatsBG' }) do
		K.Strip(_G[name])
	end
	K.Hide(_G.AchievementFrameSummaryAchievementsHeaderHeader)
	K.Hide(_G.AchievementFrameSummaryCategoriesHeaderTexture)
	K.Hide(_G.AchievementFrameComparisonHeaderBG)
	K.Panel(frame, { header = 40, strip = false })
	if frame.Categories then K.Box(frame.Categories, K.INSET) end
	K.Auto(frame)
	local search = frame.SearchResults
	if search then
		K.Strip(search)
		K.Panel(search, { header = 24 })
		if search.CloseButton then K.Close(search.CloseButton) end
	end
	local list = _G.AchievementFrameAchievements
	if list and list.ScrollBox then K.ScrollRows(list.ScrollBox, AchievementRow) end
	if frame.Categories and frame.Categories.ScrollBox then K.ScrollRows(frame.Categories.ScrollBox, AchievementCategory) end
	local stats = _G.AchievementFrameStats
	if stats and stats.ScrollBox then K.ScrollRows(stats.ScrollBox, AchievementStat) end
	local comparison = _G.AchievementFrameComparison
	if comparison then
		if comparison.AchievementContainer and comparison.AchievementContainer.ScrollBox then
			K.ScrollRows(comparison.AchievementContainer.ScrollBox, AchievementComparison)
		end
		if comparison.StatContainer and comparison.StatContainer.ScrollBox then
			K.ScrollRows(comparison.StatContainer.ScrollBox, AchievementStat)
		end
		if comparison.Summary then
			AchievementCard(comparison.Summary.Player)
			AchievementCard(comparison.Summary.Friend)
		end
	end
	SummaryBar(_G.AchievementFrameSummaryCategoriesStatusBar)
	for i = 1, 12 do SummaryBar(_G['AchievementFrameSummaryCategoriesCategory' .. i]) end
	SummaryAchievements()
	if _G.AchievementFrameSummary_UpdateAchievements then hooksecurefunc('AchievementFrameSummary_UpdateAchievements', SummaryAchievements) end
end)

-- Friends, or BetterFriendlist's window when it is installed (both use the same Blizzard frame template).
local function FriendsWindow()
	if C_AddOns.IsAddOnLoaded('BetterFriendlist') and _G.BetterFriendsFrame then return _G.BetterFriendsFrame end
	return _G.FriendsFrame
end
K.Register('friends', nil, { FriendsWindow }, function(frame)
	K.Window(frame)
	if frame ~= _G.FriendsFrame then return end
	-- The Battle.net bar at the top, the Who column headers and the rock behind invite headers.
	K.Strip(_G.FriendsFrameBattlenetFrame)
	for i = 1, 4 do
		local header = _G['WhoFrameColumnHeader' .. i]
		if header then
			K.Hide(header.Left)
			K.Hide(header.Middle)
			K.Hide(header.Right)
			K.Box(header, K.BUTTON, { 1, 0, 1, 0 })
		end
	end
	local list = _G.FriendsListFrame
	if list then K.ScrollRows(list.ScrollBox, function(row) K.Hide(row.BG) end) end
end)

-- Guild and communities, the calendar.
-- Communities: the blue menu with gold filigree on the left goes; its entries are flat rows
-- with a gold film on the selected one. The side tabs lose the old spellbook tab behind the icon.
local function CommunityEntry(entry)
	if not entry.Background or K.Done(entry, 'community') then return end
	K.Hide(entry.Background)
	local fill = K.Box(entry, ROW, { 0, 1, 0, 1 })
	if entry.Selection then
		entry.Selection:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 0.14)
		entry.Selection:ClearAllPoints()
		entry.Selection:SetAllPoints(fill)
	end
	local hl = entry.GetHighlightTexture and entry:GetHighlightTexture()
	if hl then
		hl:SetColorTexture(1, 1, 1, 0.06)
		hl:ClearAllPoints()
		hl:SetAllPoints(fill)
	end
end

local function SideTab(tab)
	if not tab or K.Done(tab, 'sidetab') then return end
	for _, region in ipairs({ tab:GetRegions() }) do
		if region:GetObjectType() == 'Texture' and region:GetDrawLayer() == 'BORDER' then K.Hide(region) end
	end
	K.Box(tab, K.BUTTON, { -1, -1, -1, -1 })
	if tab.Icon then tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
end

K.Register('guild', nil, 'CommunitiesFrame', function(frame)
	K.Window(frame)
	local list = frame.CommunitiesList
	if list then
		for _, key in ipairs({ 'Bg', 'TopFiligree', 'BottomFiligree', 'FilligreeOverlay' }) do K.Hide(list[key]) end
		K.Box(list, K.INSET)
		K.ScrollRows(list.ScrollBox, CommunityEntry)
	end
	for _, key in ipairs({ 'ChatTab', 'RosterTab', 'GuildBenefitsTab', 'GuildInfoTab' }) do SideTab(frame[key]) end
	-- Old inset corners, marble behind scroll bars, the wide picture behind finder pages.
	for _, key in ipairs({ 'GuildBenefitsFrame', 'GuildDetailsFrame', 'GuildFinderFrame', 'CommunityFinderFrame',
		'InvitationFrame', 'ClubFinderInvitationFrame', 'TicketFrame' }) do
		K.Strip(frame[key])
	end
	for _, key in ipairs({ 'MemberList', 'ApplicantList' }) do
		local member = frame[key]
		if member then
			K.Strip(member.ColumnDisplay)
			if member.ScrollBar then K.Hide(member.ScrollBar.Background) end
			K.ScrollRows(member.ScrollBox, function(row)
				local header = row.ProfessionHeader
				if header then
					K.Hide(header.Left)
					K.Hide(header.Right)
					K.Hide(header.Middle)
				end
			end)
		end
	end
	local edit = frame.ChatEditBox
	if edit then
		K.Hide(edit.Left)
		K.Hide(edit.Right)
		K.Hide(edit.Mid)
		K.Box(edit, K.FIELD, { -4, 2, -4, 2 })
	end
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
	-- The event, holiday and invite windows: dialog border and header art go.
	for _, name in ipairs({ 'CalendarViewHolidayFrame', 'CalendarViewRaidFrame', 'CalendarViewEventFrame', 'CalendarCreateEventFrame',
		'CalendarMassInviteFrame', 'CalendarEventPickerFrame', 'CalendarTexturePickerFrame' }) do
		local dialog = _G[name]
		if dialog and not K.Done(dialog, 'dialog') then
			K.Hide(dialog.Border)
			if dialog.Header then K.Strip(dialog.Header) end
			K.Hide(_G[name .. 'ButtonBackground'])
			K.Panel(dialog, { strip = false })
			K.Auto(dialog)
		end
	end
	HideNamed('Calendar', { 'ViewEventDivider', 'CreateEventDivider', 'CreateEventMassInviteButtonBorder', 'CreateEventRaidInviteButtonBorder',
		'CreateEventCreateButtonBorder', 'EventPickerCloseButtonBorder', 'TexturePickerCancelButtonBorder', 'TexturePickerAcceptButtonBorder' })
end)

-- Mail: inbox, send, the open letter.
K.Register('mail', nil, { 'MailFrame', 'OpenMailFrame' }, function(frame)
	K.Window(frame)
	if frame == _G.MailFrame then
		-- The inbox parchment behind the letters.
		K.Hide(_G.InboxFrameBg)
		for i = 1, 7 do
			local row = _G['MailItem' .. i]
			if row then
				K.Strip(row)
				K.Box(row, ROW, { 0, 1, 0, 1 })
			end
			K.Item(_G['MailItem' .. i .. 'Button'])
			K.Hide(_G['MailItem' .. i .. 'ButtonSlot'])
		end
		-- Send: the stationery goes, the letter is written in light text.
		K.Strip(_G.SendMailFrame)
		K.Hide(_G.SendStationeryBackgroundLeft)
		K.Hide(_G.SendStationeryBackgroundRight)
		local body = _G.SendMailBodyEditBox
		if body and body.SetTextColor then body:SetTextColor(K.TEXT[1], K.TEXT[2], K.TEXT[3]) end
		K.Inset(_G.SendMailMoneyInset)
		K.Auto(_G.SendMailFrame)
	else
		-- The old trainer bar under the sender and subject, both halves.
		local bar = _G.OpenMailHorizontalBarLeft
		K.Hide(bar)
		for _, region in ipairs({ frame:GetRegions() }) do
			local _, relative = region:GetPoint(1)
			if bar and relative == bar then K.Hide(region) end
		end
		K.Hide(_G.OpenStationeryBackgroundLeft)
		K.Hide(_G.OpenStationeryBackgroundRight)
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
			-- The letter material in the corners (12.x has no Bg here).
			K.Strip(panel)
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
		-- The quest log beside the map shows the same texts on its parchment: only the quest
		-- window's own pages turn light. Blizzard sets the dark colors back when the log shows
		-- them, because the material changes there.
		if not questHooked and _G.QuestInfo_Display then
			questHooked = true
			hooksecurefunc('QuestInfo_Display', function(_, parent)
				if parent == _G.QuestDetailScrollChildFrame or parent == _G.QuestRewardScrollChildFrame then QuestColors() end
			end)
		end
		if _G.QuestFrameGreetingPanel then hooksecurefunc(_G.QuestFrameGreetingPanel, 'Show', QuestColors) end
		QuestColors()
	else
		-- Books, letters and plaques: the page and its material go; Blizzard sets the text colors
		-- again for every page it shows, so they are set light after it each time.
		HideNamed('ItemText', { 'FramePageBg', 'MaterialTopLeft', 'MaterialTopRight', 'MaterialBotLeft', 'MaterialBotRight' })
		local function ItemTextColors()
			local page = _G.ItemTextPageText
			if not page then return end
			page:SetTextColor('P', K.TEXT[1], K.TEXT[2], K.TEXT[3])
			for _, tag in ipairs({ 'H1', 'H2', 'H3' }) do page:SetTextColor(tag, K.GOLD[1], K.GOLD[2], K.GOLD[3]) end
		end
		frame:HookScript('OnEvent', ItemTextColors)
		ItemTextColors()
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
-- Auction house panels carry a painted background and an inset frame of their own
-- (AuctionHouseBackgroundTemplate); both go and the panel is a flat inset.
local function AuctionPanel(panel, color)
	if not panel or K.Done(panel, 'ahpanel') then return end
	K.Hide(panel.Background)
	K.Hide(panel.NineSlice)
	K.Box(panel, color or K.INSET)
end

local function AuctionPanels(frame, depth)
	if depth <= 0 or not frame.GetChildren then return end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.backgroundAtlas and child.Background and child.NineSlice then AuctionPanel(child) end
		AuctionPanels(child, depth - 1)
	end
end

-- The header frame around the item being bought or sold.
local function AuctionItem(display)
	if not display then return end
	K.Strip(display)
	AuctionPanel(display, K.FIELD)
end

local function AuctionCategory(button)
	if not button.NormalTexture or K.Done(button, 'ahcategory') then return end
	K.Hide(button.NormalTexture)
	K.Hide(button.Lines)
	local fill = BoxOn(button, button.NormalTexture, K.BUTTON)
	if button.HighlightTexture then
		button.HighlightTexture:SetColorTexture(1, 1, 1, 0.06)
		button.HighlightTexture:ClearAllPoints()
		button.HighlightTexture:SetAllPoints(fill)
	end
	if button.SelectedTexture then
		button.SelectedTexture:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 0.14)
		button.SelectedTexture:SetBlendMode('BLEND')
	end
end

K.Register('auction', 'Blizzard_AuctionHouseUI', 'AuctionHouseFrame', function(frame)
	K.Window(frame)
	for _, sell in ipairs({ frame.ItemSellFrame, frame.CommoditiesSellFrame, frame.WoWTokenSellFrame }) do
		if sell then AuctionItem(sell.ItemDisplay) end
	end
	if frame.CommoditiesBuyFrame and frame.CommoditiesBuyFrame.BuyDisplay then AuctionItem(frame.CommoditiesBuyFrame.BuyDisplay.ItemDisplay) end
	AuctionPanels(frame, 4)
	local list = frame.CategoriesList
	if list then
		AuctionPanel(list)
		K.ScrollRows(list.ScrollBox, AuctionCategory)
	end
	if frame.MoneyFrameBorder then K.Strip(frame.MoneyFrameBorder) K.Hide(frame.MoneyFrameBorder.NineSlice) end
	-- The sell tabs' ornate header.
	for _, sell in ipairs({ frame.ItemSellFrame, frame.CommoditiesSellFrame, frame.WoWTokenSellFrame }) do
		if sell then
			K.Hide(sell.CreateAuctionTabLeft)
			K.Hide(sell.CreateAuctionTabMiddle)
			K.Hide(sell.CreateAuctionTabRight)
		end
	end
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
-- Recipe list: the paper and the ornate category headers go. Recipe form: the profession's
-- picture and its frame go. The specialization page keeps its dials, like the talent trees.
local function RecipeRow(row)
	if row.CenterPiece then
		K.Hide(row.LeftPiece)
		K.Hide(row.RightPiece)
		K.Hide(row.CenterPiece)
		K.Box(row, K.BUTTON, { 0, 1, 0, 1 })
	end
end

local function RecipeList(list)
	if not list or K.Done(list, 'recipes') then return end
	K.Hide(list.Background)
	K.Box(list, K.INSET)
	K.ScrollRows(list.ScrollBox, RecipeRow)
end

local function RecipeForm(form)
	if not form or K.Done(form, 'recipeform') then return end
	K.Hide(form.Background)
	K.Hide(form.NineSlice)
	K.Box(form, K.INSET)
end

local function RankBar(bar)
	if not bar or K.Done(bar, 'bar') then return end
	K.Hide(bar.Background)
	K.Hide(bar.Border)
	K.Box(bar, K.FIELD, { 4, 4, 4, 4 })
end

local function PaperPanel(panel)
	if not panel or K.Done(panel, 'paper') then return end
	K.Hide(panel.Background)
	K.Box(panel, K.INSET)
end

K.Register('professions', 'Blizzard_Professions', 'ProfessionsFrame', function(frame)
	K.Window(frame)
	if frame.TabSystem then K.Auto(frame.TabSystem) end
	local crafting = frame.CraftingPage
	if crafting then
		RecipeList(crafting.RecipeList)
		RecipeForm(crafting.SchematicForm)
		RankBar(crafting.RankBar)
	end
	local orders = frame.OrdersPage
	if orders then
		local browse = orders.BrowseFrame
		if browse then
			RecipeList(browse.RecipeList)
			PaperPanel(browse.OrderList)
		end
		local view = orders.OrderView
		if view then
			PaperPanel(view.OrderInfo)
			if view.OrderInfo then K.Hide(view.OrderInfo.CutDivider) end
			RankBar(view.RankBar)
			if view.OrderDetails then RecipeForm(view.OrderDetails.SchematicForm) end
		end
	end
end)

-- The profession book (the list of your professions): the book pages go, the spell buttons get
-- an item edge, the skill bars a flat track, and the texts on the old paper turn light.
local function ProfessionSpell(button)
	if not button or K.Done(button, 'profspell') then return end
	local name = button:GetName()
	if name then K.Hide(_G[name .. 'NameFrame']) end
	local icon = button.IconTexture
	if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	ns.Edge(button, 1, { 0, 0, 0, 1 }, 0)
	Light(button.subSpellString)
	if button.subSpellString then button.subSpellString:SetTextColor(K.SOFT[1], K.SOFT[2], K.SOFT[3]) end
end

local function ProfessionBar(bar)
	if not bar or K.Done(bar, 'profbar') then return end
	local name = bar:GetName()
	if name then HideNamed(name, { 'Left', 'Right', 'BGLeft', 'BGRight', 'BGMiddle' }) end
	K.Box(bar, K.FIELD)
end

local function ProfessionEntry(entry, primary)
	if not entry then return end
	local name = entry:GetName()
	if primary and name then K.Hide(_G[name .. 'IconBorder']) end
	Light(entry.professionName, primary)
	Light(entry.missingHeader, true)
	Light(entry.missingText)
	if entry.missingText then entry.missingText:SetTextColor(K.SOFT[1], K.SOFT[2], K.SOFT[3]) end
	ProfessionSpell(entry.SpellButton1)
	ProfessionSpell(entry.SpellButton2)
	ProfessionBar(entry.statusBar)
	K.Box(entry, ROW, { -4, -2, -4, -2 })
end

K.Register('professions', 'Blizzard_ProfessionsBook', 'ProfessionsBookFrame', function(frame)
	K.Window(frame)
	K.Hide(_G.ProfessionsBookPage1)
	K.Hide(_G.ProfessionsBookPage2)
	for i = 1, 2 do ProfessionEntry(_G['PrimaryProfession' .. i], true) end
	for i = 1, 3 do ProfessionEntry(_G['SecondaryProfession' .. i], false) end
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
