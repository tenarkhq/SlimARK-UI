-- 3.0 part D, group items: the ready check group table (23), premade rows, score filter and sort
-- (25), the applications list and invite sound (26), auto accept (28). Run from the repository root:
--   lua5.1 tests/claude/group-items-3-0.lua
local H = dofile('tests/claude/lib/helpers.lua')

local world

local function Secret(value)
	H.secret = H.secret or {}
	H.secret[value] = true
	return value
end

-- Edit boxes need a few methods the shared fake frames do not have.
local function WithEditBoxes()
	local create = CreateFrame
	_G.CreateFrame = function(kind, name, parent, template)
		local f = create(kind, name, parent, template)
		if kind == 'EditBox' then
			f.SetAutoFocus = function() end
			f.SetNumeric = function() end
			f.SetMaxLetters = function() end
			f.ClearFocus = function(self) local s = self._scripts.OnEditFocusLost if s then s(self) end end
		end
		return f
	end
end

-- Fires a unit event the way RegisterUnitEvent filters it: a frame that asked for other units
-- does not get it.
local function FireUnit(event, unit)
	for _, f in ipairs(H.frames) do
		local wanted = f._events[event]
		local script = f._scripts.OnEvent
		if script and wanted then
			local match = wanted == true
			if type(wanted) == 'table' then
				for _, u in ipairs(wanted) do if u == unit then match = true end end
			end
			if match then script(f, event, unit) end
		end
	end
end

local function HasEvent(event)
	for _, f in ipairs(H.frames) do
		if f._events[event] and f._scripts.OnEvent then return true end
	end
	return false
end

------------------------------------------------------------------------
-- (23) The ready check group table.
------------------------------------------------------------------------
local function BootReadyCheck(features)
	local ns = H.setup()
	world = { bag = {}, auras = {}, classes = { player = 'WARRIOR' }, raid = false, members = 1, unitAuras = {},
		hidden = {}, offline = {}, keyActive = false, secretAuras = false, names = {} }
	_G.GetLocale = function() return 'enUS' end
	_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
	_G.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() return nil end }
	_G.C_Item = {
		GetItemInfoInstant = function() return nil end, GetItemInfo = function() return nil end,
		GetItemNameByID = function() return nil end, GetItemSpell = function() return nil end,
	}
	_G.C_TooltipInfo = { GetBagItem = function() return { lines = {} } end }
	_G.C_UnitAuras = {
		GetAuraDataByIndex = function(_, i) return world.auras[i] end,
		GetPlayerAuraBySpellID = function() return nil end,
		GetUnitAuraBySpellID = function(unit, id)
			world.auraCalls = (world.auraCalls or 0) + 1
			local value = world.unitAuras[unit] and world.unitAuras[unit][id]
			return value
		end,
	}
	_G.C_ChallengeMode = { IsChallengeModeActive = function() return world.keyActive end }
	_G.C_Secrets = { ShouldAurasBeSecret = function() return world.secretAuras end }
	_G.UnitClass = function(unit) local c = world.classes[unit] return c, c end
	_G.UnitName = function(unit) return world.names[unit] or unit end
	_G.IsInRaid = function() return world.raid end
	_G.GetNumGroupMembers = function() return world.members end
	_G.UnitExists = function(unit) return world.classes[unit] ~= nil end
	_G.UnitIsUnit = function(a, b) return a == b end
	_G.UnitIsConnected = function(unit) return not world.offline[unit] end
	_G.UnitIsVisible = function(unit) return not world.hidden[unit] end
	_G.Ambiguate = function(name) return name end
	_G.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 0.5, g = 0.5, b = 0.5 } end })
	_G.C_Spell = { GetSpellName = function(id) return 'Buff ' .. id end, GetSpellTexture = function() return 1 end }
	_G.GetInventoryItemDurability = function() return nil end
	_G.C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function() return nil end }
	_G.ReadyCheckListenerFrame = H.NewFrame('Frame', 'ReadyCheckListenerFrame', UIParent)
	H.load('Config.lua')
	ns.C.modules.consumables = false
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	H.load('Core.lua')
	H.load('Consumables.lua')
	H.load('ReadyCheck.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

local FLASK = 1235108 -- Flask of the Magisters' buff
local FORTITUDE, INTELLECT = 21562, 1459

local function GroupRows()
	local list = {}
	for _, f in ipairs(H.frames) do
		if f._parent == SlimARK_ReadyCheck and f.flaskIcon and f:IsShown() then table.insert(list, f) end
	end
	return list
end

local function RowOf(name)
	for _, r in ipairs(GroupRows()) do
		if r.name:GetText() == name then return r end
	end
end

local function Party()
	world.members = 4
	world.classes = { player = 'ROGUE', party1 = 'PRIEST', party2 = 'MAGE', party3 = 'ROGUE' }
	world.names = { party1 = 'Lumi', party2 = 'Thundra', party3 = 'Brakk' }
	local all = { [FLASK] = {}, [FORTITUDE] = {}, [INTELLECT] = {} }
	world.unitAuras = {
		party1 = all,
		party2 = { [FORTITUDE] = {}, [INTELLECT] = {} },        -- no flask
		party3 = { [FLASK] = {}, [INTELLECT] = {} },            -- no Fortitude
	}
end

do
	-- Off: no table, no member aura lookups, no aura events for the group.
	BootReadyCheck({ readyCheckGroup = false })
	Party()
	H.fire('READY_CHECK', 'Leader', 30)
	H.equal(#GroupRows(), 0, '23 off: no group table')
	H.equal(world.auraCalls, nil, '23 off: no member aura is looked up')
	H.fire('READY_CHECK_FINISHED')
end

do
	BootReadyCheck()
	Party()
	H.fire('READY_CHECK', 'Leader', 30)
	H.equal(#GroupRows(), 3, '23 a row per party member')
	local lumi, thundra, brakk = RowOf('Lumi'), RowOf('Thundra'), RowOf('Brakk')
	H.check(lumi and lumi.flaskIcon:IsShown() and H.lastCall(lumi.flaskIcon, 'SetTexture')[1]:find('%-Ready$') ~= nil,
		'23 a member with a flask gets a check')
	H.check(thundra and H.lastCall(thundra.flaskIcon, 'SetTexture')[1]:find('NotReady$') ~= nil,
		'23 a member without a flask gets a cross')
	H.check(lumi.buffIcon:IsShown() and not lumi.buffText:IsShown(), '23 all class buffs: a check')
	H.equal(brakk.buffText:GetText(), 'no Fortitude', '23 a missing class buff is named')
	-- The window grew by the table.
	local height = H.lastCall(SlimARK_ReadyCheck, 'SetHeight')[1]
	H.check(height >= 34 + 4 * 40 + 26 + 3 * 24, '23 the window is tall enough for the table')

	-- A member far away: the game gives nothing, so nothing is claimed.
	world.hidden.party2 = true
	H.fire('READY_CHECK_FINISHED')
	H.fire('READY_CHECK', 'Leader', 30)
	thundra = RowOf('Thundra')
	H.check(thundra.flaskText:IsShown() and thundra.flaskText:GetText() == '?', '23 an unseen member shows ? for the flask')
	H.equal(thundra.buffText:GetText(), '?', '23 and ? for the buffs')
	H.fire('READY_CHECK_FINISHED')
end

do
	-- A secret aura answer is never compared: the cell says ?.
	BootReadyCheck()
	Party()
	world.unitAuras.party1 = { [FLASK] = Secret({}), [FORTITUDE] = Secret({}), [INTELLECT] = Secret({}) }
	H.fire('READY_CHECK', 'Leader', 30)
	local lumi = RowOf('Lumi')
	H.check(lumi and lumi.flaskText:GetText() == '?' and lumi.buffText:GetText() == '?', '23 secret aura data shows ?')
	H.fire('READY_CHECK_FINISHED')
end

do
	-- In a started key, or while the game keeps auras secret: no table.
	BootReadyCheck()
	Party()
	world.keyActive = true
	H.fire('READY_CHECK', 'Leader', 30)
	H.equal(#GroupRows(), 0, '23 no table in a started key')
	H.fire('READY_CHECK_FINISHED')
	world.keyActive, world.secretAuras = false, true
	H.fire('READY_CHECK', 'Leader', 30)
	H.equal(#GroupRows(), 0, '23 no table while auras are secret')
	H.fire('READY_CHECK_FINISHED')
end

do
	-- Member aura events: nameplates are ignored, a burst refreshes once, nothing after the check.
	BootReadyCheck()
	Party()
	H.fire('READY_CHECK', 'Leader', 30)
	world.unitAuras.party2[FLASK] = {}
	local before = world.auraCalls
	FireUnit('UNIT_AURA', 'nameplate3')
	H.runTimers(1)
	H.equal(world.auraCalls, before, '23 a nameplate aura event does not refresh')
	FireUnit('UNIT_AURA', 'party2')
	FireUnit('UNIT_AURA', 'party1')
	H.runTimers(1)
	H.check(world.auraCalls > before, '23 a member aura event refreshes')
	H.check(H.lastCall(RowOf('Thundra').flaskIcon, 'SetTexture')[1]:find('%-Ready$') ~= nil, '23 the new flask shows')
	H.fire('READY_CHECK_FINISHED')
	H.equal(HasEvent('GROUP_ROSTER_UPDATE'), false, '23 the group events stop with the check')
end

do
	-- A raid lists who misses something first and stops at 15 rows.
	BootReadyCheck()
	world.raid, world.members = true, 21
	world.classes = { player = 'WARRIOR', raid1 = 'WARRIOR' }
	for i = 2, 21 do
		world.classes['raid' .. i] = 'ROGUE'
		world.unitAuras['raid' .. i] = { [FLASK] = {}, [6673] = {} }
	end
	world.unitAuras.raid21 = { [6673] = {} }
	world.names.raid21 = 'NoFlask'
	-- raid1 is the player: not listed.
	_G.UnitIsUnit = function(a, b) return (a == 'raid1' and b == 'player') or a == b end
	H.fire('READY_CHECK', 'Leader', 30)
	local rows = GroupRows()
	H.equal(#rows, 16, '23 a raid shows 15 members and a "more" line')
	local first
	for _, r in ipairs(rows) do
		if r.name:GetText() == 'NoFlask' then first = r end
	end
	H.check(first ~= nil, '23 the member without a flask is listed first in a long raid')
	local more = false
	for _, r in ipairs(rows) do if r.name:GetText() == '+5 more' then more = true end end
	H.check(more, '23 the rest is counted')
	H.fire('READY_CHECK_FINISHED')
end

------------------------------------------------------------------------
-- (25, 26) The Group Finder.
------------------------------------------------------------------------
local function Icon(parent)
	local icon = H.NewFrame('Frame', nil, parent)
	icon.ClassCircle = H.NewFrame('Texture', nil, icon)
	icon.ClassCircle:Hide()
	return icon
end

local function Entry(resultID)
	local entry = H.NewFrame('Button', nil, UIParent)
	entry.resultID = resultID
	entry.DataDisplay = H.NewFrame('Frame', nil, entry)
	entry.DataDisplay.Enumerate = H.NewFrame('Frame', nil, entry.DataDisplay)
	local icons = {}
	for i = 1, 5 do icons[i] = Icon(entry.DataDisplay.Enumerate) end
	entry.DataDisplay.Enumerate.Icons = icons
	return entry
end

local function BootFinder(features, opts)
	local ns = H.setup()
	_G.SlimARK_Applications, _G.SlimARK_PremadeFilter, _G.SlimARK_PremadeMinScore, _G.SlimARK_PremadeSort = nil, nil, nil, nil
	WithEditBoxes()
	world = { infos = {}, members = {}, results = {}, updates = 0, rerun = 0, restrict = {}, sounds = {},
		applicants = {}, applications = {}, appInfo = {}, signups = 0 }
	_G.GROUP_FINDER_CATEGORY_ID_DUNGEONS = 2
	_G.LFGListFrame = { SearchPanel = H.NewFrame('Frame', 'LFGListSearchPanelTest', UIParent) }
	LFGListFrame.SearchPanel.categoryID = 2
	_G.PVEFrame = H.NewFrame('Frame', 'PVEFrame', UIParent)
	PVEFrame:Hide()
	_G.LFGListSearchEntry_Update = function() end
	_G.LFGListApplicationViewer_UpdateApplicantMember = function() end
	_G.LFGListSearchPanel_SetCategory = function(panel, id) panel.categoryID = id end
	_G.LFGListSearchPanel_UpdateResults = function() world.updates = world.updates + 1 end
	_G.LFGListSearchPanel_UpdateResultList = function(panel)
		world.rerun = world.rerun + 1
		local copy = {}
		for i, id in ipairs(world.results) do copy[i] = id end
		panel.results, panel.totalResults = copy, #copy
	end
	local state = Enum.AddOnRestrictionState
	_G.C_RestrictedActions = { GetAddOnRestrictionState = function(kind) return world.restrict[kind] or state.Inactive end }
	_G.C_LFGList = {
		GetSearchResultInfo = function(id) return world.infos[id] end,
		GetSearchResultPlayerInfo = function(id, i) return world.members[id] and world.members[id][i] end,
		GetApplicantMemberInfo = function(appID, i)
			local a = world.applicants[appID] and world.applicants[appID][i] or {}
			return 'Name', 'MAGE', 'Mage', 80, 650, 0, false, false, true, 'DAMAGER', nil, 2500, 0, 0, 1, a.spec, false
		end,
		GetApplications = function() return world.applications end,
		GetApplicationInfo = function(id) return id, world.appInfo[id] or 'none', nil, 0 end,
	}
	_G.C_ChallengeMode = { GetDungeonScoreRarityColor = function() return { r = 1, g = 0.5, b = 0 } end }
	_G.C_ClassColor = { GetClassColor = function(class) return { r = #class / 10, g = 0, b = 0 } end }
	_G.GetSpecializationInfoByID = function(id) return id, 'Spec ' .. id, '', 1000 + id end
	_G.PlaySound = function(kit, channel) table.insert(world.sounds, { kit, channel }) end
	if opts and opts.quality then
		_G.GetLFGRoles = function() return false, false, false, true end
		_G.SetLFGRoles = function() end
		_G.LFGListApplicationDialog = H.NewFrame('Frame', 'LFGListApplicationDialog', UIParent)
		_G.LFGListSearchEntry_OnClick = function(entry) LFGListFrame.SearchPanel.selectedResult = entry.resultID end
		_G.LFGListSearchPanel_SignUp = function() world.signups = world.signups + 1 end
		LFGListFrame.SearchPanel.SignUpButton = H.NewFrame('Button', nil, LFGListFrame.SearchPanel)
		LFGListFrame.SearchPanel.SignUpButton.IsEnabled = function() return true end
	end
	H.load('Config.lua')
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	H.load('Core.lua')
	ns.SpecInfo = function() return 70, 'DAMAGER' end
	if opts and opts.quality then H.load('Quality.lua') end
	H.load('GroupFinder.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

local function Result(id, score, members)
	world.infos[id] = { leaderOverallDungeonScore = score, numMembers = #(members or {}), isDelisted = false, name = 'Group ' .. id }
	world.members[id] = members or {}
end

local function Member(role, class) return { assignedRole = role, classFilename = class } end

local function Score(entry)
	for _, f in ipairs(H.frames) do
		if f._parent == entry and f._kind == 'FontString' and f:IsShown() and f:GetText() then return f end
	end
end

local function Bars(entry)
	local list = {}
	for _, f in ipairs(H.frames) do
		if f._parent == entry and f._kind == 'Texture' and f:IsShown() then table.insert(list, f) end
	end
	return list
end

do
	-- Off: Blizzard's functions are left unhooked and nothing listens.
	BootFinder({ premadeInfo = false, premadeFilter = false, applications = false, inviteSound = false })
	Result(1, 3000, { Member('TANK', 'WARRIOR') })
	local entry = Entry(1)
	LFGListSearchEntry_Update(entry)
	H.equal(Score(entry), nil, '25 off: no score on the row')
	H.equal(HasEvent('LFG_LIST_APPLICATION_STATUS_UPDATED'), false, '26 off: the status event is not registered')
	H.equal(_G.SlimARK_PremadeFilter, nil, '25 off: no filter bar')
end

do
	BootFinder()
	Result(1, 3240, { Member('DAMAGER', 'MAGE'), Member('TANK', 'WARRIOR'), Member('HEALER', 'PRIEST') })
	local entry = Entry(1)
	LFGListSearchEntry_Update(entry)
	local score = Score(entry)
	H.check(score and score:GetText() == 3240, '25 the leader score is on the row')
	local color = H.lastCall(score, 'SetTextColor')
	H.check(color and color[1] == 1 and color[2] == 0.5, '25 in its rarity color')
	local bars = Bars(entry)
	H.equal(#bars, 3, '25 a class mark under each member')
	-- Tank first: the warrior's mark sits under the leftmost filled icon (Blizzard counts from 5 down).
	local first = H.lastCall(bars[1], 'SetPoint')
	H.check(first and first[2] == entry.DataDisplay.Enumerate.Icons[5], '25 the marks follow Blizzard\'s icon order')

	-- Where Blizzard draws class circles itself, no second mark.
	for _, icon in ipairs(entry.DataDisplay.Enumerate.Icons) do icon.ClassCircle:Show() end
	LFGListSearchEntry_Update(entry)
	H.equal(#Bars(entry), 0, '25 no mark over Blizzard\'s own class circles')

	-- Outside the Dungeons category no score.
	LFGListFrame.SearchPanel.categoryID = 3
	LFGListSearchEntry_Update(entry)
	H.equal(Score(entry), nil, '25 no leader score outside the Dungeons category')
	LFGListFrame.SearchPanel.categoryID = 2

	-- A secret score is not compared or shown.
	world.infos[1].leaderOverallDungeonScore = Secret(2999)
	LFGListSearchEntry_Update(entry)
	H.equal(Score(entry), nil, '25 a secret score is not shown')
	local errors = 0
	for _, line in ipairs(H.prints) do if line:find('ERROR', 1, true) then errors = errors + 1 end end
	H.equal(errors, 0, '25 and raises no error')

	-- Restricted: in combat on a dungeon map nothing is read.
	world.infos[1].leaderOverallDungeonScore = 3000
	world.restrict[Enum.AddOnRestrictionType.Map] = Enum.AddOnRestrictionState.Active
	world.restrict[Enum.AddOnRestrictionType.Combat] = Enum.AddOnRestrictionState.Active
	LFGListSearchEntry_Update(entry)
	H.equal(Score(entry), nil, '25 nothing in combat on a dungeon map')
	world.restrict = { [Enum.AddOnRestrictionType.ChallengeMode] = Enum.AddOnRestrictionState.Activating }
	LFGListSearchEntry_Update(entry)
	H.equal(Score(entry), nil, '25 nothing in a running key (also while it is starting)')
	world.restrict = { [Enum.AddOnRestrictionType.Map] = Enum.AddOnRestrictionState.Active }
	LFGListSearchEntry_Update(entry)
	H.check(Score(entry) ~= nil, '25 on a dungeon map out of combat it works')
end

do
	-- The filter and the sort.
	BootFinder()
	local panel = LFGListFrame.SearchPanel
	Result(1, 1800) Result(2, 3100) Result(3, 2600) Result(4, 3100)
	world.results = { 1, 2, 3, 4 }
	LFGListSearchPanel_UpdateResultList(panel)
	H.equal(table.concat(panel.results, ','), '2,4,3,1', '25 sorted by leader score (ties keep their order)')
	H.equal(world.updates, 1, '25 the list is drawn again')

	SlimARKDB.premade.minScore = 2500
	LFGListSearchPanel_UpdateResultList(panel)
	H.equal(table.concat(panel.results, ','), '2,4,3', '25 groups under the minimum leader score go')
	H.equal(panel.totalResults, 3, '25 the count follows')

	SlimARKDB.premade.sortScore = false
	LFGListSearchPanel_UpdateResultList(panel)
	H.equal(table.concat(panel.results, ','), '2,3,4', '25 sort off: Blizzard\'s order, still filtered')

	-- Restricted, other category, secret data: Blizzard's list as it is.
	world.restrict = { [Enum.AddOnRestrictionType.Encounter] = Enum.AddOnRestrictionState.Active }
	LFGListSearchPanel_UpdateResultList(panel)
	H.equal(#panel.results, 4, '25 in a boss fight the list is untouched')
	world.restrict = {}
	panel.categoryID = 3
	LFGListSearchPanel_UpdateResultList(panel)
	H.equal(#panel.results, 4, '25 outside the Dungeons category the list is untouched')
	panel.categoryID = 2
	world.infos[3].leaderOverallDungeonScore = Secret(2700)
	LFGListSearchPanel_UpdateResultList(panel)
	H.equal(#panel.results, 4, '25 a secret score leaves the list untouched')
end

do
	-- The filter bar: only in the Dungeons category; a new minimum runs the list again.
	BootFinder()
	local panel = LFGListFrame.SearchPanel
	panel:Show()
	panel._scripts.OnShow(panel)
	local bar = _G.SlimARK_PremadeFilter
	H.check(bar ~= nil and bar:IsShown(), '25 the filter bar shows in the Dungeons category')
	LFGListSearchPanel_SetCategory(panel, 3)
	H.equal(bar:IsShown(), false, '25 and hides in another category')
	LFGListSearchPanel_SetCategory(panel, 2)
	local before = world.rerun
	SlimARK_PremadeMinScore:SetText('2800')
	SlimARK_PremadeMinScore._scripts.OnEnterPressed(SlimARK_PremadeMinScore)
	H.equal(SlimARKDB.premade.minScore, 2800, '25 the minimum is kept')
	H.equal(world.rerun, before + 1, '25 and the list runs again once')
	SlimARK_PremadeSort._scripts.OnClick(SlimARK_PremadeSort)
	H.equal(SlimARKDB.premade.sortScore, false, '25 the sort button switches the sort')
	H.equal(SlimARK_PremadeSort.text:GetText(), 'Sort: default', '25 and says so')
end

do
	-- Applicants: the spec beside the name.
	BootFinder()
	world.applicants[7] = { { spec = 63 } }
	local member = H.NewFrame('Button', nil, UIParent)
	member.Name = H.NewFrame('FontString', nil, member)
	LFGListApplicationViewer_UpdateApplicantMember(member, 7, 1, 'applied')
	local icon
	for _, f in ipairs(H.frames) do if f._parent == member and f._kind == 'Texture' then icon = f end end
	H.check(icon and icon:IsShown() and H.lastCall(icon, 'SetTexture')[1] == 1063, '25 the applicant\'s spec icon shows')
	world.applicants[7] = { { spec = Secret(64) } }
	LFGListApplicationViewer_UpdateApplicantMember(member, 7, 1, 'applied')
	H.equal(icon:IsShown(), false, '25 a secret spec is not shown')
end

do
	-- Quality.lua's one-click sign-up still works with the premade hooks in place.
	BootFinder(nil, { quality = true })
	Result(5, 3000, { Member('TANK', 'WARRIOR') })
	local entry = Entry(5)
	LFGListSearchEntry_OnClick(entry, 'LeftButton')
	H.equal(world.signups, 1, '25 one-click sign-up still signs up')
	LFGListSearchEntry_Update(entry)
	H.check(Score(entry) ~= nil, '25 and the row still gets its score')
end

do
	-- (26) The applications list and the invite sound.
	BootFinder()
	H.fire('LFG_LIST_APPLICATION_STATUS_UPDATED', 11, 'applied', 'none', '+12 Voidscar, timed')
	H.equal(_G.SlimARK_Applications, nil, '26 nothing is built while the Group Finder is closed')
	PVEFrame:Show()
	PVEFrame._scripts.OnShow(PVEFrame)
	local window = SlimARK_Applications
	H.check(window and window:IsShown(), '26 the list shows beside the Group Finder')
	H.equal(window.title:GetText(), 'Applications 1', '26 with the count')
	H.equal(window.rows[1].group:GetText(), '+12 Voidscar, timed', '26 the group title')
	H.equal(window.rows[1].state:GetText(), 'pending', '26 and its status')

	H.fire('LFG_LIST_APPLICATION_STATUS_UPDATED', 12, 'applied', 'none', '+11 Priory weekly')
	H.fire('LFG_LIST_APPLICATION_STATUS_UPDATED', 12, 'declined', 'applied', '+11 Priory weekly')
	H.fire('LFG_LIST_APPLICATION_STATUS_UPDATED', 11, 'invited', 'applied', '+12 Voidscar, timed')
	H.equal(window.title:GetText(), 'Applications 2', '26 every application is listed')
	H.equal(window.rows[1].state:GetText(), 'declined', '26 newest first: declined')
	H.equal(window.rows[2].state:GetText(), 'invited', '26 invited')
	H.equal(#world.sounds, 1, '26 one sound on the invite')
	H.fire('LFG_LIST_APPLICATION_STATUS_UPDATED', 11, 'invited', 'invited', '+12 Voidscar, timed')
	H.equal(#world.sounds, 1, '26 no second sound for the same invite')

	-- A secret result ID is ignored; the group title may be secret, it only goes to the text.
	H.fire('LFG_LIST_APPLICATION_STATUS_UPDATED', Secret(13), 'applied', 'none', 'x')
	H.equal(window.title:GetText(), 'Applications 2', '26 a secret result ID is ignored')
	local title = Secret('hidden title')
	H.fire('LFG_LIST_APPLICATION_STATUS_UPDATED', 14, 'applied', 'none', title)
	H.equal(window.rows[1].group:GetText(), title, '26 a secret title is shown as it is')

	-- Closing the Group Finder drops the finished ones.
	PVEFrame:Hide()
	PVEFrame._scripts.OnHide(PVEFrame)
	PVEFrame:Show()
	PVEFrame._scripts.OnShow(PVEFrame)
	H.equal(window.title:GetText(), 'Applications 2', '26 finished applications go when the window closes')

	-- Sound only, no list.
	BootFinder({ applications = false })
	PVEFrame:Show()
	H.fire('LFG_LIST_APPLICATION_STATUS_UPDATED', 21, 'invited', 'applied', 'g')
	H.equal(#world.sounds, 1, '26 the sound has its own switch')
	H.equal(_G.SlimARK_Applications, nil, '26 the list stays off')

	-- After a reload the open applications come from the game.
	BootFinder()
	Result(31, 2000)
	world.applications = { 31 }
	world.appInfo[31] = 'applied'
	PVEFrame:Show()
	PVEFrame._scripts.OnShow(PVEFrame)
	H.equal(SlimARK_Applications.rows[1].group:GetText(), 'Group 31', '26 pending applications are read from the game')
end

------------------------------------------------------------------------
-- (28) Auto accept.
------------------------------------------------------------------------
local function BootAccept(features)
	local ns = H.setup()
	world = { accepts = {}, hidden = {}, friends = {}, guild = {}, bnet = {}, inGroup = false, removesQueue = false,
		summonLeft = 0, summons = 0, canTeleport = true, fighting = {}, dead = true, res = 0, encounter = false, delay = 0 }
	_G.AcceptGroup = function(...) table.insert(world.accepts, { ... }) end
	_G.StaticPopup_Hide = function(which) world.hidden[which] = (world.hidden[which] or 0) + 1 end
	_G.StaticPopupSpecial_Hide = function() world.hidden.special = (world.hidden.special or 0) + 1 end
	_G.LFGInvitePopup = H.NewFrame('Frame', 'LFGInvitePopup', UIParent)
	_G.IsInGroup = function() return world.inGroup end
	_G.WillAcceptInviteRemoveQueues = function() return world.removesQueue end
	_G.C_BattleNet = { GetGameAccountInfoByGUID = function(guid) return world.bnet[guid] end }
	_G.C_FriendList = { IsFriend = function(guid) return world.friends[guid] == true end }
	_G.IsGuildMember = function(guid) return world.guild[guid] == true end
	_G.C_SummonInfo = {
		GetSummonConfirmTimeLeft = function() return world.summonLeft end,
		ConfirmSummon = function() world.summons = world.summons + 1 end,
	}
	_G.PlayerCanTeleport = function() return world.canTeleport end
	_G.UnitAffectingCombat = function(unit) return world.fighting[unit] == true end
	_G.UnitIsDeadOrGhost = function() return world.dead end
	_G.AcceptResurrect = function() world.res = world.res + 1 end
	_G.IsEncounterInProgress = function() return world.encounter end
	_G.GetCorpseRecoveryDelay = function() return world.delay end
	_G.Enum.SummonReason = { Scenario = 2 }
	H.load('Config.lua')
	for key, value in pairs(features or {}) do ns.C.features[key] = value end
	H.load('Core.lua')
	ns.SpecInfo = function() return 70, 'DAMAGER' end
	H.load('AutoAccept.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	return ns
end

do
	BootAccept({ acceptInvites = false, acceptSummons = false, acceptRes = false })
	H.equal(HasEvent('PARTY_INVITE_REQUEST'), false, '28 off: invites are not listened to')
	H.equal(HasEvent('CONFIRM_SUMMON'), false, '28 off: summons are not listened to')
	H.equal(HasEvent('RESURRECT_REQUEST'), false, '28 off: resurrections are not listened to')
end

do
	BootAccept()
	world.friends['Player-1'] = true
	world.guild['Player-2'] = true
	world.bnet['Player-3'] = {}
	world.friends['Player-S'] = true
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', false, false, false, true, false, 'Player-9', false)
	H.equal(#world.accepts, 0, '28 an invite from a stranger is left alone')
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', false, false, false, true, false, 'Player-1', false)
	H.equal(#world.accepts, 1, '28 a friend\'s invite is accepted')
	H.equal(world.hidden.PARTY_INVITE, nil, '28 the pop-up stays until the group is joined (it would decline)')
	H.fire('GROUP_ROSTER_UPDATE')
	H.equal(world.hidden.PARTY_INVITE, 1, '28 then it goes')
	H.fire('PARTY_INVITE_REQUEST', 'Lumi', false, false, false, true, false, 'Player-2', false)
	H.equal(#world.accepts, 2, '28 a guild member\'s invite is accepted')
	H.fire('PARTY_INVITE_REQUEST', 'Thundra', false, false, false, true, false, 'Player-3', false)
	H.equal(#world.accepts, 3, '28 a Battle.net friend\'s invite is accepted')

	-- Left to you: in combat, already in a group, a queue would be lost, a quest session, a secret GUID.
	H.combat = true
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', false, false, false, true, false, 'Player-1', false)
	H.combat = false
	world.inGroup = true
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', false, false, false, true, false, 'Player-1', false)
	world.inGroup, world.removesQueue = false, true
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', false, false, false, true, false, 'Player-1', false)
	world.removesQueue = false
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', false, false, false, true, false, 'Player-1', true)
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', false, false, false, true, false, Secret('Player-S'), false)
	H.equal(#world.accepts, 3, '28 combat, a group, a queue, a quest session or a secret GUID: left to you')

	-- A queued group asks for a role: the spec's role when they take it.
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', true, true, false, true, false, 'Player-1', false)
	H.equal(#world.accepts, 3, '28 a role invite without your role is left to you')
	H.fire('PARTY_INVITE_REQUEST', 'Brakk', false, false, true, true, false, 'Player-1', false)
	local last = world.accepts[#world.accepts]
	H.check(#world.accepts == 4 and last[1] == false and last[2] == false and last[3] == true, '28 a role invite is accepted as damage')
end

do
	BootAccept()
	world.summonLeft = 100
	H.fire('CONFIRM_SUMMON', 1, false)
	H.runTimers(1)
	H.equal(world.summons, 1, '28 a summon is accepted')
	H.equal(world.hidden.CONFIRM_SUMMON, 1, '28 and its window goes')

	-- In a fight: taken when it ends.
	H.combat = true
	H.fire('CONFIRM_SUMMON', 1, false)
	H.runTimers(1)
	H.equal(world.summons, 1, '28 no summon in combat')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(world.summons, 2, '28 the summon is taken after the fight')

	-- Cancelled meanwhile: nothing after the fight.
	H.combat = true
	H.fire('CONFIRM_SUMMON', 1, false)
	H.runTimers(1)
	H.fire('CANCEL_SUMMON')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(world.summons, 2, '28 a cancelled summon is not taken after the fight')

	-- Scenario and starting-area summons stay for you.
	H.fire('CONFIRM_SUMMON', 2, false)
	H.fire('CONFIRM_SUMMON', 1, true)
	H.runTimers(1)
	H.equal(world.summons, 2, '28 scenario and starting area summons are left to you')
end

do
	BootAccept()
	H.fire('RESURRECT_REQUEST', 'Lumi')
	H.equal(world.res, 1, '28 a resurrection is accepted')
	H.equal(world.hidden.RESURRECT_NO_TIMER, 1, '28 and its window goes')
	world.fighting.Lumi = true
	H.fire('RESURRECT_REQUEST', 'Lumi')
	H.equal(world.res, 1, '28 a resurrection from someone fighting is left to you')
	world.fighting.Lumi = false
	world.encounter = true
	H.fire('RESURRECT_REQUEST', 'Lumi')
	H.equal(world.res, 1, '28 no resurrection during a boss fight')
	world.encounter = false
	world.fighting.Lumi = Secret(true)
	H.fire('RESURRECT_REQUEST', 'Lumi')
	H.equal(world.res, 2, '28 a secret combat flag is not compared')
	world.fighting.Lumi = false
	world.delay = 5
	H.fire('RESURRECT_REQUEST', 'Lumi')
	H.equal(world.res, 2, '28 with a wait from the game, not at once')
	H.runTimers(6)
	H.equal(world.res, 3, '28 but after the wait')
end

H.done()
