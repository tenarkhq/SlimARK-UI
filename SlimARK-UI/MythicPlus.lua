local _, ns = ...
local C = ns.C

-- Compact Mythic+ panel in place of the quest tracker, only while a key runs:
-- key level and dungeon, deaths, timer with the +3 and +2 marks, enemy forces
-- to two decimals, and one line per boss with its kill time.
local W = 352
local LINE = 24
local MAX_BOSSES = 8

local panel, timerBar, forcesBar, bosses
local timerID, timeLimit = nil, 0
local killTimes = {}
local active = false
local trackerHidden = false

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format('%d:%02d', math.floor(seconds / 60), seconds % 60)
end

local function Bar(parent, height, color)
	local bar = CreateFrame('StatusBar', nil, parent)
	bar:SetHeight(height)
	bar:SetStatusBarTexture(ns.TEX)
	bar:SetStatusBarColor(color[1], color[2], color[3])
	ns.Outline(bar)
	ns.Track(bar)
	ns.Gloss(bar)
	return bar
end

local function Mark(bar, fraction)
	local t = bar:CreateTexture(nil, 'OVERLAY', nil, 2)
	t:SetColorTexture(1, 1, 1, 0.9)
	t:SetSize(2, bar:GetHeight() + 6)
	t:SetPoint('CENTER', bar, 'LEFT', W * fraction, 0)
end

local function Build()
	panel = CreateFrame('Frame', 'SlimARK_MythicPlus', UIParent)
	panel:SetSize(W, 120 + MAX_BOSSES * LINE)
	panel:Hide()

	panel.Title = ns.Text(panel, 19)
	panel.Title:SetPoint('TOPLEFT', 0, 0)
	panel.Title:SetPoint('RIGHT', -110, 0)
	panel.Deaths = ns.Text(panel, 16, 'RIGHT')
	panel.Deaths:SetPoint('TOPRIGHT', 0, -2)

	panel.Time = ns.Text(panel, 30)
	panel.Time:SetPoint('TOPLEFT', 0, -26)
	panel.Limit = ns.Text(panel, 16)
	panel.Limit:SetPoint('BOTTOMLEFT', panel.Time, 'BOTTOMRIGHT', 6, 3)
	panel.Limit:SetTextColor(0.7, 0.7, 0.72)

	timerBar = Bar(panel, 10, C.colors.classPower)
	timerBar:SetPoint('TOPLEFT', 0, -64)
	timerBar:SetWidth(W)
	Mark(timerBar, 0.6)
	Mark(timerBar, 0.8)

	panel.Plus3 = ns.Text(panel, 15)
	panel.Plus3:SetPoint('TOPLEFT', timerBar, 'BOTTOMLEFT', 0, -5)
	panel.Plus2 = ns.Text(panel, 15)
	panel.Plus2:SetPoint('LEFT', panel.Plus3, 'LEFT', 110, 0)

	forcesBar = Bar(panel, 18, C.colors.enemyCast)
	forcesBar:SetPoint('TOPLEFT', 0, -102)
	forcesBar:SetWidth(W)
	forcesBar:SetMinMaxValues(0, 100)
	forcesBar.Text = ns.Text(forcesBar, 15, 'CENTER')
	forcesBar.Text:SetPoint('CENTER')

	bosses = {}
	for i = 1, MAX_BOSSES do
		local name = ns.Text(panel, 16)
		name:SetPoint('TOPLEFT', 0, -128 - (i - 1) * LINE)
		name:SetPoint('RIGHT', -60, 0)
		local time = ns.Text(panel, 16, 'RIGHT')
		time:SetPoint('TOPRIGHT', 0, -128 - (i - 1) * LINE)
		bosses[i] = { name = name, time = time }
	end

	ns.Register(panel, C.tracker.x - W, C.tracker.y, { key = 'mythicplus', w = W, h = panel:GetHeight() })
end

local function Elapsed()
	if not timerID then return 0 end
	local _, elapsed = GetWorldElapsedTime(timerID)
	return elapsed or 0
end

local function UpdateTime()
	local elapsed = Elapsed()
	panel.Time:SetText(Clock(elapsed))
	if timeLimit > 0 then
		timerBar:SetMinMaxValues(0, timeLimit)
		timerBar:SetValue(math.min(elapsed, timeLimit))
		if elapsed > timeLimit then panel.Time:SetTextColor(1, 0.35, 0.35) else panel.Time:SetTextColor(1, 1, 1) end
		local left3, left2 = timeLimit * 0.6 - elapsed, timeLimit * 0.8 - elapsed
		panel.Plus3:SetText('+3 ' .. (left3 >= 0 and Clock(left3) or '-' .. Clock(-left3)))
		panel.Plus2:SetText('+2 ' .. (left2 >= 0 and Clock(left2) or '-' .. Clock(-left2)))
		panel.Plus3:SetTextColor(left3 >= 0 and 0.5 or 0.55, left3 >= 0 and 0.85 or 0.55, left3 >= 0 and 0.5 or 0.58)
		panel.Plus2:SetTextColor(left2 >= 0 and 0.5 or 0.55, left2 >= 0 and 0.85 or 0.55, left2 >= 0 and 0.5 or 0.58)
	end
end

-- Enemy forces: the game gives the raw count in quantityString, its percent is
-- only a whole number. Count divided by the total gives the two decimals.
local function ForcesPercent(info)
	local total = info.totalQuantity or 0
	local count = tonumber((info.quantityString or ''):match('[%d%.]+'))
	if count and total > 0 then
		return count / total * 100, count, total
	end
	return info.quantity or 0
end

local function UpdateCriteria()
	local step = C_ScenarioInfo.GetScenarioStepInfo()
	local n = step and step.numCriteria or 0
	local line = 0
	for i = 1, n do
		local info = C_ScenarioInfo.GetCriteriaInfo(i)
		if info then
			if info.isWeightedProgress then
				local pct, count, total = ForcesPercent(info)
				if info.completed then pct = 100 end
				forcesBar:SetValue(math.min(pct, 100))
				if count then
					forcesBar.Text:SetFormattedText('%.2f%%  (%d/%d)', pct, count, total)
				else
					forcesBar.Text:SetFormattedText('%.2f%%', pct)
				end
			elseif line < MAX_BOSSES then
				line = line + 1
				local row = bosses[line]
				if info.completed and not killTimes[i] then killTimes[i] = Elapsed() end
				row.name:SetText(info.description)
				if info.completed then
					row.name:SetTextColor(0.5, 0.85, 0.5)
					row.time:SetTextColor(0.5, 0.85, 0.5)
					row.time:SetText(killTimes[i] and Clock(killTimes[i]) or '✓')
				else
					row.name:SetTextColor(1, 1, 1)
					row.time:SetText('')
				end
			end
		end
	end
	for i = line + 1, MAX_BOSSES do
		bosses[i].name:SetText('')
		bosses[i].time:SetText('')
	end
	panel:SetHeight(128 + line * LINE)
end

local function UpdateDeaths()
	local count, lost = C_ChallengeMode.GetDeathCount()
	if count and count > 0 then
		panel.Deaths:SetFormattedText('%d deaths  -%s', count, Clock(lost or 0))
	else
		panel.Deaths:SetText('')
	end
end

-- The quest tracker steps aside while the key runs. It holds secure quest item
-- buttons, so it is only hidden and shown out of combat; in combat it goes
-- transparent at once and is hidden when the combat ends.
local function ApplyTracker()
	local frame = ObjectiveTrackerFrame
	if not frame then return end
	frame:SetAlpha(trackerHidden and 0 or 1)
	if frame:IsShown() ~= trackerHidden then return end
	if InCombatLockdown() then
		ns.trackerPending = true
	else
		frame:SetShown(not trackerHidden)
	end
end

local function SetTrackerHidden(hide)
	-- A tracker we did not hide is left as it is.
	if not hide and not trackerHidden then return end
	trackerHidden = hide
	ApplyTracker()
end

-- Blizzard shows the tracker again on its own updates, in combat too.
local function KeepTrackerHidden()
	if not ObjectiveTrackerFrame then return end
	ObjectiveTrackerFrame:HookScript('OnShow', function()
		if trackerHidden then ApplyTracker() end
	end)
end

local function FindTimer()
	timerID = nil
	for _, id in ipairs({ GetWorldElapsedTimers() }) do
		local _, _, kind = GetWorldElapsedTime(id)
		if kind == Enum.WorldElapsedTimerTypes.ChallengeMode then
			timerID = id
			return
		end
	end
end

local ticker
local function Start()
	local mapID = C_ChallengeMode.GetActiveChallengeMapID()
	if not mapID then return end
	local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
	local level = C_ChallengeMode.GetActiveKeystoneInfo()
	timeLimit = limit or 0
	panel.Title:SetText(('+%d %s'):format(level or 0, name or ''))
	panel.Limit:SetText('/ ' .. Clock(timeLimit))
	FindTimer()
	active = true
	panel:Show()
	SetTrackerHidden(true)
	UpdateCriteria()
	UpdateDeaths()
	UpdateTime()
	-- Four updates a second keep the clock smooth, and the panel does nothing outside a key.
	if not ticker then ticker = C_Timer.NewTicker(0.25, UpdateTime) end
end

local function Stop()
	active = false
	wipe(killTimes)
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	if panel then panel:Hide() end
	SetTrackerHidden(false)
end

local function Check()
	if not panel then return end
	if C_ChallengeMode.IsChallengeModeActive() then Start() else Stop() end
end

ns.On('PLAYER_LOGIN', function()
	-- WoW Forever has no Mythic+: without the API the panel is never built.
	if not C.modules.mythicplus or not C_ChallengeMode then return end
	Build()
	KeepTrackerHidden()
end)
ns.On('CHALLENGE_MODE_START', function() C_Timer.After(0.5, Check) end)
ns.On('PLAYER_ENTERING_WORLD', function() C_Timer.After(1, Check) end)
ns.On('WORLD_STATE_TIMER_START', function()
	if active then FindTimer() end
end)
ns.On('CHALLENGE_MODE_COMPLETED', function()
	if not active or not panel then return end
	UpdateCriteria()
	UpdateTime()
	-- The panel keeps the final time until you leave the dungeon.
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end)
ns.On('CHALLENGE_MODE_RESET', function()
	if panel then Stop() end
end)
ns.On('SCENARIO_CRITERIA_UPDATE', function()
	if active then UpdateCriteria() end
end)
ns.On('CHALLENGE_MODE_DEATH_COUNT_UPDATED', function()
	if active then UpdateDeaths() end
end)
ns.On('PLAYER_REGEN_ENABLED', function()
	if ns.trackerPending then
		ns.trackerPending = nil
		ApplyTracker()
	end
end)
