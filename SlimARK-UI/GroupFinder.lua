local _, ns = ...
local C = ns.C

-- 3.0: the premade Group Finder.
-- (25) Blizzard's own list entries get the leader's Mythic+ score in its color, and where Blizzard
-- shows plain role icons, a class colored mark under each member's icon (in the Dungeons category
-- Blizzard draws class colored role icons itself). Applicants show their spec beside the name; the
-- score of an applicant is Blizzard's own column. Above the Dungeons list: a minimum leader score
-- and a sort by score. Nothing is read in combat on a dungeon map, in a running key or a boss fight;
-- Blizzard's list stays as it is then.
-- (26) Your applications in a small window beside the Group Finder with their status, and one short
-- sound when a group invites you.

local BG = { 0.055, 0.059, 0.075, 0.95 }
local GOLD = { 0.95, 0.72, 0.29 }
local GREEN = { 0.5, 0.82, 0.5 }
local RED = { 0.88, 0.34, 0.29 }
local GREY = { 0.6, 0.6, 0.62 }
local ROLE_ORDER = { 'TANK', 'HEALER', 'DAMAGER' }
local INVITE_SOUND = 12867 -- SOUNDKIT.ALARM_CLOCK_WARNING_2: short, unlike the game's own invite sound

-- The group finder's data is closed to addons in combat on a dungeon map, in a running key and in a
-- boss fight; "Activating" counts as on, the restriction is about to start.
local function Restricted()
	local actions = C_RestrictedActions
	local kind, state = Enum.AddOnRestrictionType, Enum.AddOnRestrictionState
	if not actions or not actions.GetAddOnRestrictionState or not kind or not state then
		return InCombatLockdown()
	end
	local function on(t)
		if t == nil then return false end
		local s = actions.GetAddOnRestrictionState(t)
		return issecretvalue(s) or s ~= state.Inactive
	end
	return (on(kind.Map) and on(kind.Combat)) or on(kind.ChallengeMode) or on(kind.Encounter)
end
ns.GroupFinderRestricted = Restricted

local function Readable(v)
	return not issecretvalue(v) and v ~= nil
end

local function OpenTable(t)
	return type(t) == 'table' and not issecretvalue(t) and (not canaccesstable or canaccesstable(t))
end

local function Dungeons()
	return GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2
end

local function SearchPanel()
	return LFGListFrame and LFGListFrame.SearchPanel
end

local function InDungeons(panel)
	return panel ~= nil and panel.categoryID == Dungeons()
end

local function ClassColor(class)
	if not Readable(class) then return nil end
	return (C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
end

------------------------------------------------------------------------
-- (25) Leader score and class marks on the search entries.
------------------------------------------------------------------------
local entryParts = setmetatable({}, { __mode = 'k' })

local function Parts(entry)
	local parts = entryParts[entry]
	if parts then return parts end
	parts = { bars = {} }
	parts.score = ns.Text(entry, 12, 'RIGHT')
	parts.score:SetPoint('TOPRIGHT', entry, 'TOPRIGHT', -10, -6)
	entryParts[entry] = parts
	return parts
end

local function ClassBar(entry, parts, i, icon)
	local bar = parts.bars[i]
	if not bar then
		bar = entry:CreateTexture(nil, 'OVERLAY', nil, 7)
		bar:SetHeight(2)
		parts.bars[i] = bar
	end
	bar:ClearAllPoints()
	bar:SetPoint('TOPLEFT', icon, 'BOTTOMLEFT', 2, 1)
	bar:SetPoint('TOPRIGHT', icon, 'BOTTOMRIGHT', -2, 1)
	return bar
end

-- The members in Blizzard's icon order: tanks, healers, then damage dealers.
local function MembersByRole(resultID, count)
	local byRole = { TANK = {}, HEALER = {}, DAMAGER = {} }
	for i = 1, count do
		local member = C_LFGList.GetSearchResultPlayerInfo(resultID, i)
		if not OpenTable(member) then return nil end
		local role, class = member.assignedRole, member.classFilename
		if not Readable(role) or not Readable(class) then return nil end
		if byRole[role] then table.insert(byRole[role], class) end
	end
	return byRole
end

local function Marks(entry, resultID, info, parts)
	local display = entry.DataDisplay
	local enumerate = display and display:IsShown() and display.Enumerate
	if not enumerate or not enumerate:IsShown() or not enumerate.Icons then return end
	local count = info.numMembers
	if not Readable(count) or count < 1 then return end
	-- Blizzard numbers the icons from right to left and fills them from the last shown one.
	local icons, shown = enumerate.Icons, 0
	for i = 1, #icons do
		if icons[i]:IsShown() then shown = i end
	end
	local byRole = MembersByRole(resultID, count)
	if not byRole then return end
	local delisted = Readable(info.isDelisted) and info.isDelisted == true
	local index, n = shown, 0
	for _, role in ipairs(ROLE_ORDER) do
		for _, class in ipairs(byRole[role]) do
			local icon = icons[index]
			if not icon then return end
			-- A class colored circle of Blizzard's own needs no second mark.
			local blizzard = icon.ClassCircle and icon.ClassCircle:IsShown()
			local color = ClassColor(class)
			if color and not blizzard then
				n = n + 1
				local bar = ClassBar(entry, parts, n, icon)
				bar:SetColorTexture(color.r, color.g, color.b, delisted and 0.3 or 1)
				bar:Show()
			end
			index = index - 1
		end
	end
end

local function UpdateEntry(entry)
	local parts = entryParts[entry]
	if parts then
		parts.score:Hide()
		for _, bar in ipairs(parts.bars) do bar:Hide() end
	end
	if not C.features.premadeInfo or Restricted() then return end
	local resultID = entry.resultID
	if not Readable(resultID) then return end
	local info = C_LFGList.GetSearchResultInfo(resultID)
	if not OpenTable(info) then return end
	parts = Parts(entry)
	local score = info.leaderOverallDungeonScore
	if InDungeons(SearchPanel()) and not issecretvalue(score) and type(score) == 'number' and score > 0 then
		local color = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score)
		parts.score:SetText(score)
		if color then parts.score:SetTextColor(color.r, color.g, color.b) else parts.score:SetTextColor(1, 1, 1) end
		parts.score:Show()
	end
	Marks(entry, resultID, info, parts)
end
ns.PremadeEntryUpdate = UpdateEntry

------------------------------------------------------------------------
-- (25) The applicants' spec.
------------------------------------------------------------------------
local specIcons = setmetatable({}, { __mode = 'k' })

local function UpdateApplicant(member, appID, memberIdx)
	local icon = specIcons[member]
	if icon then icon:Hide() end
	if not C.features.premadeInfo or Restricted() or not C_LFGList.GetApplicantMemberInfo then return end
	local specID = select(16, C_LFGList.GetApplicantMemberInfo(appID, memberIdx))
	if not Readable(specID) or specID == 0 or not GetSpecializationInfoByID then return end
	local _, _, _, texture = GetSpecializationInfoByID(specID)
	if not texture then return end
	if not icon then
		icon = member:CreateTexture(nil, 'ARTWORK')
		icon:SetSize(14, 14)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:SetPoint('RIGHT', member, 'LEFT', 101, 0)
		-- The name ends before the icon instead of running under it.
		if member.Name then member.Name:SetPoint('RIGHT', member, 'LEFT', 85, 0) end
		specIcons[member] = icon
	end
	icon:SetTexture(texture)
	icon:Show()
end
ns.PremadeApplicantUpdate = UpdateApplicant

------------------------------------------------------------------------
-- (25) Minimum leader score and the sort by score, in the Dungeons category.
------------------------------------------------------------------------
local function Prefs()
	ns.DB.premade = ns.DB.premade or { minScore = 0, sortScore = true }
	return ns.DB.premade
end

-- Runs after Blizzard filled and sorted the list. Any value the game keeps hidden leaves its list as it is.
local function FilterResults(panel)
	if not C.features.premadeFilter or not ns.DB or Restricted() then return end
	if not InDungeons(panel) or not OpenTable(panel.results) then return end
	local prefs = Prefs()
	local minScore = prefs.minScore or 0
	if minScore <= 0 and not prefs.sortScore then return end
	local list, scores, order = {}, {}, {}
	for i, resultID in ipairs(panel.results) do
		if not Readable(resultID) then return end
		local info = C_LFGList.GetSearchResultInfo(resultID)
		if not OpenTable(info) then return end
		local score = info.leaderOverallDungeonScore
		if issecretvalue(score) then return end
		score = type(score) == 'number' and score or 0
		if score >= minScore then
			list[#list + 1] = resultID
			scores[resultID], order[resultID] = score, i
		end
	end
	if prefs.sortScore then
		table.sort(list, function(a, b)
			if scores[a] ~= scores[b] then return scores[a] > scores[b] end
			return order[a] < order[b]
		end)
	end
	panel.results = list
	panel.totalResults = #list
	LFGListSearchPanel_UpdateResults(panel)
end
ns.PremadeFilter = FilterResults

local filterBar

local function SortLabel()
	return Prefs().sortScore and 'Sort: score' or 'Sort: default'
end

-- The list again with the new choice: Blizzard's own refill, then the filter above.
local function Rerun()
	local panel = SearchPanel()
	if panel and panel:IsShown() and not Restricted() and LFGListSearchPanel_UpdateResultList then
		LFGListSearchPanel_UpdateResultList(panel)
	end
end

local function ApplyMinScore(box)
	local value = tonumber(box:GetText() or '') or 0
	value = math.max(0, math.floor(value))
	box:SetText(value > 0 and tostring(value) or '')
	if value ~= (Prefs().minScore or 0) then
		Prefs().minScore = value
		Rerun()
	end
end

local function FilterBar(panel)
	if filterBar then return filterBar end
	local bar = CreateFrame('Frame', 'SlimARK_PremadeFilter', panel)
	bar:SetSize(190, 20)
	bar:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -8, -32)
	local label = ns.Text(bar, 12, 'RIGHT')
	label:SetPoint('LEFT')
	label:SetText('Min score')
	label:SetTextColor(GREY[1], GREY[2], GREY[3])

	local box = CreateFrame('EditBox', 'SlimARK_PremadeMinScore', bar)
	box:SetSize(46, 18)
	box:SetPoint('LEFT', label, 'RIGHT', 6, 0)
	box:EnableMouse(true)
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(4)
	ns.SetFont(box, 12, 'OUTLINE')
	box:SetJustifyH('CENTER')
	local back = box:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints()
	back:SetColorTexture(0.137, 0.145, 0.169, 1)
	ns.Outline(box)
	local min = Prefs().minScore or 0
	box:SetText(min > 0 and tostring(min) or '')
	box:SetScript('OnEnterPressed', function(self) ApplyMinScore(self) self:ClearFocus() end)
	box:SetScript('OnEditFocusLost', ApplyMinScore)
	box:SetScript('OnEscapePressed', function(self)
		local value = Prefs().minScore or 0
		self:SetText(value > 0 and tostring(value) or '')
		self:ClearFocus()
	end)
	bar.box = box

	local sort = CreateFrame('Button', 'SlimARK_PremadeSort', bar)
	sort:SetSize(84, 18)
	sort:SetPoint('LEFT', box, 'RIGHT', 8, 0)
	sort.text = ns.Text(sort, 12, 'LEFT')
	sort.text:SetPoint('LEFT')
	sort.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	sort.text:SetText(SortLabel())
	sort:SetScript('OnClick', function(self)
		Prefs().sortScore = not Prefs().sortScore
		self.text:SetText(SortLabel())
		Rerun()
	end)
	bar.sort = sort
	filterBar = bar
	return bar
end

local function UpdateFilterBar()
	local panel = SearchPanel()
	if not panel then return end
	local show = C.features.premadeFilter and InDungeons(panel) and not Restricted()
	if show then FilterBar(panel):Show() elseif filterBar then filterBar:Hide() end
end
ns.UpdatePremadeFilterBar = UpdateFilterBar

------------------------------------------------------------------------
-- (26) Your applications beside the Group Finder.
------------------------------------------------------------------------
-- The game's status names, as shown.
local STATUS = {
	applied = { 'pending', GOLD }, invited = { 'invited', GREEN }, inviteaccepted = { 'joined', GREEN },
	invitedeclined = { 'invite declined', GREY }, declined = { 'declined', RED }, declined_full = { 'full', RED },
	declined_delisted = { 'delisted', RED }, timedout = { 'timed out', GREY }, cancelled = { 'cancelled', GREY },
	failed = { 'cancelled', GREY },
}
local OPEN_STATUS = { applied = true, invited = true }
local W, HEAD, ROW, MAX_ROWS = 240, 28, 22, 10

local apps, appOrder = {}, 0
local appWindow

local function AppWindow()
	if appWindow then return appWindow end
	local f = CreateFrame('Frame', 'SlimARK_Applications', PVEFrame)
	f:SetWidth(W)
	f:SetPoint('TOPLEFT', PVEFrame, 'TOPRIGHT', 4, 0)
	local back = f:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints()
	back:SetColorTexture(BG[1], BG[2], BG[3], BG[4])
	ns.Outline(f)
	f.title = ns.Text(f, 14)
	f.title:SetPoint('TOPLEFT', 10, -8)
	f.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local line = f:CreateTexture(nil, 'ARTWORK')
	line:SetColorTexture(0, 0, 0, 1)
	line:SetHeight(1)
	line:SetPoint('TOPLEFT', 0, -HEAD)
	line:SetPoint('TOPRIGHT', 0, -HEAD)
	f.rows = {}
	f:Hide()
	appWindow = f
	return f
end

local function AppRow(f, i)
	if f.rows[i] then return f.rows[i] end
	local r = CreateFrame('Frame', nil, f)
	r:SetHeight(ROW)
	r:SetPoint('TOPLEFT', 0, -HEAD - (i - 1) * ROW)
	r:SetPoint('RIGHT')
	r.state = ns.Text(r, 13, 'RIGHT')
	r.state:SetPoint('RIGHT', -10, 0)
	r.group = ns.Text(r, 13)
	r.group:SetPoint('LEFT', 10, 0)
	r.group:SetPoint('RIGHT', r, 'RIGHT', -104, 0)
	f.rows[i] = r
	return r
end

local function SortedApps()
	local list = {}
	for resultID, app in pairs(apps) do list[#list + 1] = { id = resultID, app = app } end
	table.sort(list, function(a, b) return a.app.order > b.app.order end)
	return list
end

local function UpdateApps()
	if not PVEFrame or not PVEFrame:IsShown() then
		if appWindow then appWindow:Hide() end
		return
	end
	local list = SortedApps()
	if #list == 0 then
		if appWindow then appWindow:Hide() end
		return
	end
	local f = AppWindow()
	local shown = math.min(#list, MAX_ROWS)
	f.title:SetText('Applications ' .. #list)
	for i = 1, math.max(shown, #f.rows) do
		local item = list[i]
		local r = (i <= shown) and AppRow(f, i) or f.rows[i]
		if i <= shown then
			local status = STATUS[item.app.status]
			-- The group's title can be a hidden value: it only goes to the text, never tested.
			if item.app.hasName then r.group:SetText(item.app.name) else r.group:SetText('') end
			r.state:SetText(status[1])
			r.state:SetTextColor(status[2][1], status[2][2], status[2][3])
			r:Show()
		else
			r:Hide()
		end
	end
	f:SetHeight(HEAD + shown * ROW + 4)
	f:Show()
end
ns.UpdateApplications = UpdateApps

-- hasName: a title came with it (the title itself may be hidden and is never tested).
local function Remember(resultID, status, name, hasName)
	if not STATUS[status] then
		apps[resultID] = nil
		return
	end
	local app = apps[resultID]
	if not app then
		appOrder = appOrder + 1
		app = { order = appOrder }
		apps[resultID] = app
	end
	app.status = status
	if hasName then app.name, app.hasName = name, true end
end

-- Applications made before a reload are picked up from the game when the window opens.
local function ReadApplications()
	if Restricted() or not C_LFGList.GetApplications then return end
	local list = C_LFGList.GetApplications()
	if not OpenTable(list) then return end
	for _, resultID in ipairs(list) do
		if Readable(resultID) and not apps[resultID] then
			local _, status = C_LFGList.GetApplicationInfo(resultID)
			local info = C_LFGList.GetSearchResultInfo(resultID)
			if Readable(status) and OPEN_STATUS[status] then
				local open = OpenTable(info)
				local name = open and info.name
				Remember(resultID, status, name, open and (issecretvalue(name) or name ~= nil))
			end
		end
	end
end

local function OnStatus(_, resultID, newStatus, oldStatus, groupName)
	if not Readable(resultID) or not Readable(newStatus) then return end
	if C.features.inviteSound and newStatus == 'invited' and not (Readable(oldStatus) and oldStatus == 'invited') then
		PlaySound(INVITE_SOUND, 'Master')
	end
	if not C.features.applications then return end
	Remember(resultID, newStatus, groupName, issecretvalue(groupName) or groupName ~= nil)
	UpdateApps()
end
ns.OnApplicationStatus = OnStatus

-- A finished application stays until the Group Finder closes.
local function DropFinished()
	for resultID, app in pairs(apps) do
		if not OPEN_STATUS[app.status] then apps[resultID] = nil end
	end
	if appWindow then appWindow:Hide() end
end

------------------------------------------------------------------------
-- Hooks, made once the Group Finder is loaded.
------------------------------------------------------------------------
local hooked = false
local function Hook()
	if hooked or not LFGListFrame or not PVEFrame then return end
	hooked = true
	local f = C.features
	-- The Mythic+ score parts stay off in WoW Forever.
	local premade = not ns.isForever and C_LFGList and (f.premadeInfo or f.premadeFilter)
	if premade and f.premadeInfo then
		if LFGListSearchEntry_Update then hooksecurefunc('LFGListSearchEntry_Update', UpdateEntry) end
		if LFGListApplicationViewer_UpdateApplicantMember then
			hooksecurefunc('LFGListApplicationViewer_UpdateApplicantMember', UpdateApplicant)
		end
	end
	if premade and f.premadeFilter and LFGListSearchPanel_UpdateResultList and LFGListSearchPanel_UpdateResults then
		hooksecurefunc('LFGListSearchPanel_UpdateResultList', FilterResults)
		if LFGListSearchPanel_SetCategory then hooksecurefunc('LFGListSearchPanel_SetCategory', UpdateFilterBar) end
		local panel = SearchPanel()
		if panel then panel:HookScript('OnShow', UpdateFilterBar) end
	end
	if f.applications and C_LFGList then
		PVEFrame:HookScript('OnShow', function()
			ReadApplications()
			UpdateApps()
		end)
		PVEFrame:HookScript('OnHide', DropFinished)
	end
end

ns.On('PLAYER_LOGIN', function()
	local f = C.features
	if not (f.premadeInfo or f.premadeFilter or f.applications or f.inviteSound) then return end
	if f.applications or f.inviteSound then ns.On('LFG_LIST_APPLICATION_STATUS_UPDATED', OnStatus) end
	if f.premadeInfo or f.premadeFilter or f.applications then
		ns.On('ADDON_LOADED', function(_, name)
			if name == 'Blizzard_GroupFinder' then Hook() end
		end)
		Hook()
	end
end)
