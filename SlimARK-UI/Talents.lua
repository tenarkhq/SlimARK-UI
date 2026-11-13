local _, ns = ...
local C = ns.C

-- 3.0 (29, 30): spec, loadout, loot spec and gear set for the top bar element, and the loadout
-- reminder on entering a dungeon. Every change runs out of combat only: a pick made in combat
-- waits for the end of the fight. Nothing here runs unless the element or the reminder is on.
local T = {}
ns.Talents = T

local MUTED = 'ff9a968c'
local LABEL = { 0.62, 0.6, 0.56 }
local GOLD = { 0.95, 0.72, 0.29 }

local enabled
local waiting -- the change picked in combat, run when it ends
local swap -- the loadout being applied: { spec, config }

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

local function Refresh()
	if ns.UpdateSpecSegment then ns.UpdateSpecSegment() end
end

------------------------------------------------------------------------
-- Reading
------------------------------------------------------------------------
-- The current spec: ID, name, index.
local function Spec()
	local S = C_SpecializationInfo
	if not (S and S.GetSpecialization and S.GetSpecializationInfo) then return end
	local index = S.GetSpecialization()
	if not Readable(index) or not index or index <= 0 then return end
	local id, name = S.GetSpecializationInfo(index)
	if not id or id <= 0 or not name then return end
	return id, name, index
end
T.Spec = Spec

-- Every spec of your class: { index, id, name }.
local function Specs()
	local list = {}
	local S = C_SpecializationInfo
	local classID = select(3, UnitClass('player'))
	if not (S and S.GetNumSpecializationsForClassID and classID) then return list end
	for i = 1, S.GetNumSpecializationsForClassID(classID) do
		local id, name = S.GetSpecializationInfo(i)
		if id and id > 0 and name then table.insert(list, { index = i, id = id, name = name }) end
	end
	return list
end

local function HasLoadouts()
	return C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_ClassTalents.GetLastSelectedSavedConfigID
		and C_Traits and C_Traits.GetConfigInfo and true or false
end

local function LoadoutName(configID)
	if not configID or not HasLoadouts() then return end
	local info = C_Traits.GetConfigInfo(configID)
	return info and info.name
end
T.LoadoutName = LoadoutName

local function StarterActive()
	return C_ClassTalents.GetStarterBuildActive and C_ClassTalents.GetStarterBuildActive() or false
end

-- The loadout in use for a spec: the last one picked, the way the talent window shows it.
local function CurrentLoadout(specID)
	if not specID or not HasLoadouts() or StarterActive() then return end
	return C_ClassTalents.GetLastSelectedSavedConfigID(specID)
end
T.CurrentLoadout = CurrentLoadout

local function Loadouts(specID)
	local list = {}
	if not specID or not HasLoadouts() then return list end
	for _, id in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
		local name = LoadoutName(id)
		if name then table.insert(list, { id = id, name = name }) end
	end
	return list
end

local function LoadoutText(specID)
	if not HasLoadouts() then return end
	if StarterActive() then return 'Starter build' end
	return LoadoutName(CurrentLoadout(specID))
end

local function LootSpecText(specName)
	if not GetLootSpecialization then return end
	local id = GetLootSpecialization()
	if not id or id == 0 then return 'Current spec' .. (specName and (' (' .. specName .. ')') or '') end
	local name = GetSpecializationInfoByID and select(2, GetSpecializationInfoByID(id))
	return name or '?'
end

local function GearSets()
	local list = {}
	if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs) then return list end
	for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
		local name, _, _, equipped = C_EquipmentSet.GetEquipmentSetInfo(id)
		if name then table.insert(list, { id = id, name = name, equipped = equipped }) end
	end
	return list
end

------------------------------------------------------------------------
-- Changing: only out of combat
------------------------------------------------------------------------
local function OutOfCombat(fn)
	if InCombatLockdown() then
		waiting = fn
		ns.Print('The change waits until the fight ends.')
		return
	end
	fn()
end
T.OutOfCombat = OutOfCombat

-- A loadout is applied like the talent window does it: the game answers at once when nothing changes,
-- otherwise the "last picked" mark moves when the change has landed (TRAIT_CONFIG_UPDATED).
function T.LoadLoadout(configID)
	local specID = Spec()
	if not specID or not configID or not HasLoadouts() or not C_ClassTalents.LoadConfig then return end
	local result = C_ClassTalents.LoadConfig(configID, true)
	local R = Enum.LoadConfigResult
	if result == R.NoChangesNecessary then
		C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, configID)
	elseif result ~= R.Error then
		swap = { spec = specID, config = configID }
	end
	Refresh()
end

local function OnConfigUpdated(_, configID)
	if swap and C_ClassTalents.GetActiveConfigID and configID == C_ClassTalents.GetActiveConfigID() then
		local done = swap
		swap = nil
		local starter = StarterActive()
		C_ClassTalents.UpdateLastSelectedSavedConfigID(done.spec, done.config)
		-- Leaving the starter build for a saved loadout, as the talent window does after the change.
		if starter and C_ClassTalents.SetStarterBuildActive then C_ClassTalents.SetStarterBuildActive(false) end
	end
	Refresh()
end

------------------------------------------------------------------------
-- The top bar element (29)
------------------------------------------------------------------------
function T.BarText()
	local specID, specName = Spec()
	if not specName then return end
	local loadout = LoadoutText(specID)
	if loadout then return specName .. '|c' .. MUTED .. ' · |r' .. loadout end
	return specName
end

function T.Tooltip()
	local specID, specName = Spec()
	GameTooltip:AddLine(specName or 'Specialization')
	if HasLoadouts() then
		GameTooltip:AddDoubleLine('Loadout', LoadoutText(specID) or 'none', LABEL[1], LABEL[2], LABEL[3], 1, 1, 1)
	end
	local loot = LootSpecText(specName)
	if loot then GameTooltip:AddDoubleLine('Loot spec', loot, LABEL[1], LABEL[2], LABEL[3], 1, 1, 1) end
	if C_EquipmentSet then
		local worn
		for _, set in ipairs(GearSets()) do
			if set.equipped then worn = set.name end
		end
		GameTooltip:AddDoubleLine('Gear set', worn or 'none', LABEL[1], LABEL[2], LABEL[3], 1, 1, 1)
	end
	GameTooltip:AddLine('Click: spec · Right click: loadout', 0.6, 0.6, 0.6)
	GameTooltip:AddLine('Shift-click: loot spec · Ctrl-click: gear set', 0.6, 0.6, 0.6)
	if InCombatLockdown() then GameTooltip:AddLine('Out of combat only', 1, 0.3, 0.3) end
	GameTooltip:Show()
end

local function Close()
	return MenuResponse and MenuResponse.Close
end

local function Menu(owner, title, build)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(title)
		build(root)
	end)
end

local function SpecMenu(owner)
	local _, _, current = Spec()
	Menu(owner, 'Specialization', function(root)
		for _, spec in ipairs(Specs()) do
			root:CreateRadio(spec.name, function() return spec.index == current end, function()
				if spec.index ~= current then
					OutOfCombat(function() C_SpecializationInfo.SetSpecialization(spec.index) end)
				end
				return Close()
			end, spec.index)
		end
	end)
end

local function LoadoutMenu(owner)
	local specID = Spec()
	local current = CurrentLoadout(specID)
	Menu(owner, 'Loadout', function(root)
		local list = Loadouts(specID)
		for _, loadout in ipairs(list) do
			root:CreateRadio(loadout.name, function() return loadout.id == current end, function()
				if loadout.id ~= current then OutOfCombat(function() T.LoadLoadout(loadout.id) end) end
				return Close()
			end, loadout.id)
		end
		if #list == 0 then root:CreateButton('No saved loadouts', function() end) end
	end)
end

local function LootMenu(owner)
	local _, specName = Spec()
	local current = GetLootSpecialization and GetLootSpecialization() or 0
	Menu(owner, 'Loot spec', function(root)
		local options = { { id = 0, name = 'Current spec' .. (specName and (' (' .. specName .. ')') or '') } }
		for _, spec in ipairs(Specs()) do table.insert(options, { id = spec.id, name = spec.name }) end
		for _, option in ipairs(options) do
			root:CreateRadio(option.name, function() return option.id == current end, function()
				OutOfCombat(function() SetLootSpecialization(option.id) end)
				return Close()
			end, option.id)
		end
	end)
end

local function GearMenu(owner)
	Menu(owner, 'Gear set', function(root)
		local list = GearSets()
		for _, set in ipairs(list) do
			root:CreateRadio(set.name, function() return set.equipped end, function()
				OutOfCombat(function() C_EquipmentSet.UseEquipmentSet(set.id) end)
				return Close()
			end, set.id)
		end
		if #list == 0 then root:CreateButton('No gear sets', function() end) end
	end)
end

-- Click: spec, right click: loadout, shift: loot spec, ctrl: gear set. In combat nothing opens.
function T.Click(owner, button)
	if InCombatLockdown() then
		ns.Print('Spec, loadout, loot spec and gear set change out of combat only.')
		return
	end
	if IsShiftKeyDown() then
		LootMenu(owner)
	elseif IsControlKeyDown() then
		GearMenu(owner)
	elseif button == 'RightButton' then
		LoadoutMenu(owner)
	else
		SpecMenu(owner)
	end
end

------------------------------------------------------------------------
-- The loadout reminder (30)
------------------------------------------------------------------------
local cfg = C.loadout
local win
local remind -- { id, name, spec, last, now } while the reminder applies

local function Store()
	if not ns.CharDB then return end
	ns.CharDB.loadouts = ns.CharDB.loadouts or {}
	return ns.CharDB.loadouts
end

-- The dungeon you are in: instance ID and name. Not in raids, delves or the open world.
local function Dungeon()
	local name, kind, _, _, _, _, _, id = GetInstanceInfo()
	if kind ~= 'party' or not Readable(id) or not id then return end
	return id, name
end

local function InRunningKey()
	return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() or false
end

-- The loadout used in this dungeon, per spec: what you have when you leave is what you used.
local function Remember(specID, configID)
	if not cfg.reminder then return end
	local id = Dungeon()
	local store = Store()
	if not (id and store and specID and configID) then return end
	store[id] = store[id] or {}
	store[id][specID] = configID
end

local function HideWindow()
	if win then win:Hide() end
end

local function FlatButton(parent, text, gold)
	local b = CreateFrame('Button', nil, parent)
	b:SetSize(90, 26)
	local bg = b:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	if gold then bg:SetColorTexture(0.42, 0.33, 0.13, 1) else bg:SetColorTexture(0.17, 0.18, 0.21, 1) end
	ns.Outline(b)
	local label = ns.Text(b, 14, 'CENTER')
	label:SetPoint('CENTER')
	label:SetText(text)
	if gold then label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
	local hl = b:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.08)
	return b
end

local function BuildWindow()
	win = CreateFrame('Frame', 'SlimARK_LoadoutReminder', UIParent)
	win:SetSize(300, 112)
	win:SetFrameStrata('DIALOG')
	win:EnableMouse(true)
	win:Hide()
	local bg = win:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.063, 0.067, 0.082, 0.96)
	ns.Outline(win)
	local stripe = win:CreateTexture(nil, 'ARTWORK')
	stripe:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	stripe:SetPoint('TOPLEFT')
	stripe:SetPoint('TOPRIGHT')
	stripe:SetHeight(2)

	win.title = ns.Text(win, 16)
	win.title:SetPoint('TOPLEFT', 10, -10)
	win.title:SetText('Loadout')
	win.where = ns.Text(win, 14, 'RIGHT')
	win.where:SetPoint('TOPRIGHT', -10, -11)
	win.where:SetTextColor(LABEL[1], LABEL[2], LABEL[3])
	win.last = ns.Text(win, 15)
	win.last:SetPoint('TOPLEFT', 10, -36)
	win.now = ns.Text(win, 14)
	win.now:SetPoint('TOPLEFT', 10, -56)
	win.now:SetTextColor(LABEL[1], LABEL[2], LABEL[3])

	win.switch = FlatButton(win, 'Switch', true)
	win.switch:SetPoint('BOTTOMLEFT', 10, 10)
	win.switch:SetScript('OnClick', function()
		local target = remind and remind.last
		remind = nil
		HideWindow()
		if target then OutOfCombat(function() T.LoadLoadout(target) end) end
	end)
	win.keep = FlatButton(win, 'Keep')
	win.keep:SetPoint('LEFT', win.switch, 'RIGHT', 8, 0)
	win.keep:SetScript('OnClick', function()
		remind = nil
		HideWindow()
	end)
	ns.Register(win, cfg.x, cfg.y, { w = 300, h = 112 })
end

-- Shown out of combat only, while you are still in that dungeon, the key has not started and the
-- loadout still differs from the one used there last time.
local function ShowWindow()
	if not remind or InCombatLockdown() or InRunningKey() then return end
	local id = Dungeon()
	local specID = Spec()
	local now = CurrentLoadout(specID)
	if id ~= remind.id or specID ~= remind.spec or not now or now == remind.last then
		remind = nil
		return
	end
	if not win then BuildWindow() end
	win.where:SetText(remind.name or '')
	win.last:SetText('Last time here: |cffffffff' .. (LoadoutName(remind.last) or '?') .. '|r')
	win.now:SetText('Now: ' .. (LoadoutName(now) or '?'))
	win:Show()
end

local function Check()
	HideWindow()
	remind = nil
	local id, name = Dungeon()
	if not id or InRunningKey() then return end
	local specID = Spec()
	local now = CurrentLoadout(specID)
	if not now then return end
	local store = Store()
	local last = store and store[id] and store[id][specID]
	-- What you have now is what you use here, unless you switch: then the switch is remembered.
	Remember(specID, now)
	if last and last ~= now and LoadoutName(last) then
		remind = { id = id, name = name, spec = specID, last = last, now = now }
		ShowWindow()
	end
end
T.CheckReminder = Check

------------------------------------------------------------------------
-- Switching on
------------------------------------------------------------------------
-- The events and the hook shared by the element and the reminder, installed once.
function T.Enable()
	if enabled then return end
	enabled = true
	ns.On('PLAYER_REGEN_ENABLED', function()
		if waiting then
			local fn = waiting
			waiting = nil
			fn()
		end
	end)
	ns.On('PLAYER_SPECIALIZATION_CHANGED', function(_, unit)
		if unit and unit ~= 'player' then return end
		local specID = Spec()
		Remember(specID, CurrentLoadout(specID))
		Refresh()
	end)
	if HasLoadouts() then
		ns.On('TRAIT_CONFIG_UPDATED', OnConfigUpdated)
		-- The saved loadouts arrive after login.
		ns.On('TRAIT_CONFIG_LIST_UPDATED', Refresh)
		ns.On('CONFIG_COMMIT_FAILED', function()
			swap = nil
			Refresh()
		end)
		-- Every change of the "last picked" loadout goes through here: the talent window's and ours.
		if C_ClassTalents.UpdateLastSelectedSavedConfigID then
			hooksecurefunc(C_ClassTalents, 'UpdateLastSelectedSavedConfigID', function(specID, configID)
				if Readable(specID) and Readable(configID) then Remember(specID, configID) end
				Refresh()
			end)
		end
	end
end

ns.On('PLAYER_LOGIN', function()
	if not cfg.reminder or not HasLoadouts() then return end
	T.Enable()
	ns.On('PLAYER_ENTERING_WORLD', function()
		-- The talent data settles a moment after the loading screen.
		C_Timer.After(2, Check)
	end)
	ns.On('PLAYER_REGEN_DISABLED', HideWindow)
	ns.On('PLAYER_REGEN_ENABLED', ShowWindow)
	ns.On('CHALLENGE_MODE_START', function()
		remind = nil
		HideWindow()
	end)
end)
