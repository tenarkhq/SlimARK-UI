local _, ns = ...
local C = ns.C
local cfg = C.layout

local INDEX_ENUMS = {
	ActionBar = 'EditModeActionBarSystemIndices',
	CooldownViewer = 'EditModeCooldownViewerSystemIndices',
	AuraFrame = 'EditModeAuraFrameSystemIndices',
}

local function Find(layout, systemName, indexName)
	local system = Enum.EditModeSystem[systemName]
	local index = indexName and Enum[INDEX_ENUMS[systemName]][indexName]
	for _, info in ipairs(layout.systems) do
		if info.system == system and (not index or info.systemIndex == index) then
			return info
		end
	end
end

local function Set(info, setting, value)
	for _, entry in ipairs(info.settings) do
		if entry.setting == setting then
			entry.value = value
			return
		end
	end
	table.insert(info.settings, { setting = setting, value = value })
end

-- x, y: real pixels from the top left. Blizzard divides the offset by the frame's scale itself.
local function Move(info, point, x, y)
	local unit = ns.Scale()
	info.isInDefaultPosition = false
	info.anchorInfo = { point = point, relativeTo = 'UIParent', relativePoint = 'TOPLEFT', offsetX = x * unit, offsetY = -y * unit }
	info.anchorInfo2 = nil
end

-- What percent the requested pixel size is at the current UI scale, rounded to tens.
local function IconPercent(pixels)
	local percent = pixels * ns.Scale() / 45 * 100
	return math.max(50, math.min(200, math.floor(percent / 10 + 0.5) * 10))
end

local function StyleBar(info, percent)
	local S = Enum.EditModeActionBarSetting
	Set(info, S.Orientation, Enum.ActionBarOrientation.Horizontal)
	Set(info, S.NumRows, 1)
	Set(info, S.NumIcons, 12)
	Set(info, S.IconSize, (percent - 50) / 10)
	Set(info, S.IconPadding, cfg.bars.padding)
end

local function ArrangeBars(layout)
	local b = cfg.bars
	local percent = IconPercent(b.size)
	local rowHeight = (45 * percent / 100 + b.padding) / ns.Scale()

	-- The enabled bars come first, the disabled ones behind them.
	local order = {}
	local function IsOn(bar)
		local frame = bar.frame and _G[bar.frame]
		return not bar.frame or (frame and frame:IsShown())
	end
	for _, bar in ipairs(cfg.order) do
		if IsOn(bar) then table.insert(order, bar) end
	end
	for _, bar in ipairs(cfg.order) do
		if not IsOn(bar) then table.insert(order, bar) end
	end

	for i, bar in ipairs(order) do
		local info = Find(layout, 'ActionBar', bar.index)
		if info then
			StyleBar(info, percent)
			if i <= cfg.centerRows then
				Move(info, 'BOTTOM', b.center, b.bottom - (i - 1) * rowHeight)
			else
				Move(info, 'BOTTOMLEFT', cfg.sideX, cfg.sideBottom - (i - cfg.centerRows - 1) * rowHeight)
			end
		end
	end

	local main = Find(layout, 'ActionBar', 'MainBar')
	if main then
		Set(main, Enum.EditModeActionBarSetting.HideBarArt, 1)
		Set(main, Enum.EditModeActionBarSetting.HideBarScrolling, 1)
	end

	for _, index in ipairs({ 'StanceBar', 'PetActionBar', 'PossessActionBar' }) do
		local info = Find(layout, 'ActionBar', index)
		if info then
			Set(info, Enum.EditModeActionBarSetting.IconSize, (percent - 50) / 10)
			Set(info, Enum.EditModeActionBarSetting.IconPadding, b.padding)
		end
	end
end

local function PlaceSystems(layout, systems)
	for _, entry in ipairs(systems) do
		local systemName, indexName, point, x, y = unpack(entry, 1, 5)
		local info = Find(layout, systemName, indexName)
		if info then
			if systemName == 'Bags' then
				Set(info, Enum.EditModeBagsSetting.Size, (cfg.bagsSize - 75) / 5)
			end
			Move(info, point, x, y)
		end
	end
end

local function ArrangeSystems(layout)
	PlaceSystems(layout, cfg.systems)

	for index, pixels in pairs(cfg.cooldownIcons) do
		local info = Find(layout, 'CooldownViewer', index)
		if info then
			Set(info, Enum.EditModeCooldownViewerSetting.IconSize, (IconPercent(pixels) - 50) / 10)
		end
	end

	local tracker = Find(layout, 'ObjectiveTracker')
	if tracker then
		local S = Enum.EditModeObjectiveTrackerSetting
		Set(tracker, S.Height, (C.tracker.height - 400) / 10)
		Set(tracker, S.TextSize, C.tracker.textSize - 12)
		Set(tracker, S.Opacity, 0)
	end
end

local function NewLayoutSlot(layouts)
	local counts, highest = {}, {}
	for i, layout in ipairs(layouts) do
		local kind = layout.layoutType
		counts[kind] = (counts[kind] or 0) + 1
		highest[kind] = i
	end
	local max = Constants.EditModeConsts.EditModeMaxLayoutsPerType
	local T = Enum.EditModeLayoutType
	if (counts[T.Account] or 0) < max then
		return T.Account, (highest[T.Account] or Enum.EditModePresetLayoutsMeta.NumValues) + 1
	elseif (counts[T.Character] or 0) < max then
		return T.Character, (highest[T.Character] or highest[T.Account]) + 1
	end
end

local function IndexOf(layouts, name)
	for i, layout in ipairs(layouts) do
		if layout.layoutName == name and layout.layoutType ~= Enum.EditModeLayoutType.Preset then
			return i
		end
	end
end

local function WantedName()
	return ns.healer and cfg.healName or cfg.name
end

-- The presets also go into the list, so the indexes match the activeLayout numbering.
local function AllLayouts()
	local info = C_EditMode.GetLayouts()
	local all = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
	tAppendAll(all, info.layouts)
	info.layouts = all
	return info, all
end

-- Creates or updates our two layouts and enables the one that fits the role.
-- It does not touch other layouts. onlyNew also leaves an already existing own layout untouched.
function ns.ApplyEditMode(onlyNew)
	local info, all = AllLayouts()

	local created = {}
	for _, name in ipairs({ cfg.name, cfg.healName }) do
		if not IndexOf(all, name) then
			local kind, slot = NewLayoutSlot(all)
			if not kind then
				ns.Print('Edit Mode has reached its layout limit. Delete one and run /slim apply again.')
				return false
			end
			local layout = CopyTable(all[IndexOf(all, cfg.name) or info.activeLayout])
			layout.layoutIndex = nil
			layout.layoutType = kind
			layout.layoutName = name
			table.insert(all, slot, layout)
			table.insert(created, name)
		end
	end

	for _, name in ipairs(onlyNew and created or { cfg.name, cfg.healName }) do
		local layout = all[IndexOf(all, name)]
		ArrangeBars(layout)
		ArrangeSystems(layout)
		if name == cfg.healName then PlaceSystems(layout, cfg.healSystems) end
	end

	C_EditMode.SaveLayouts(info)
	for _, name in ipairs(created) do
		C_EditMode.OnLayoutAdded(IndexOf(all, name), false, false)
	end
	C_EditMode.SetActiveLayout(IndexOf(all, WantedName()))
	return true
end

local function IsOurs(layout)
	return layout and (layout.layoutName == cfg.name or layout.layoutName == cfg.healName)
end

-- The game records the active layout per spec, so after a spec switch a different one may be active.
-- If ours was active before, we step to the own layout that fits the role, otherwise we leave it alone.
local usesOurs = false

function ns.SyncLayout()
	local info, all = AllLayouts()
	usesOurs = usesOurs or IsOurs(all[info.activeLayout])
	if not usesOurs then return end

	local wanted = IndexOf(all, WantedName())
	if not wanted then
		ns.ApplyEditMode(true)
	elseif wanted ~= info.activeLayout then
		C_EditMode.SetActiveLayout(wanted)
	end
end

-- Whoever picks another layout in Edit Mode does not get switched back on a spec switch either.
ns.On('PLAYER_LOGIN', function()
	EventRegistry:RegisterCallback('EditMode.Exit', function()
		local info, all = AllLayouts()
		usesOurs = IsOurs(all[info.activeLayout])
	end, ns)
end)
