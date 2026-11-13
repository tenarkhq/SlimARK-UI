local _, ns = ...
local C = ns.C

-- Compact Mythic+ panel in place of the quest tracker, only while a key runs:
-- key level and dungeon, deaths, timer with the +3 and +2 marks, enemy forces
-- to two decimals, and one line per boss with its kill time.
-- 3.0 rows, each with its own switch: the time in combat under the timer (15), the battle res
-- charges and Bloodlust (5), the current pull on the forces bar (2) and the personal best split
-- of every boss (7). The battle res and Bloodlust row also shows above the boss frames in a raid
-- boss fight.
local W = 352
local LINE = 24
local ROW = 22
local MAX_BOSSES = 8
local feat = C.features
local OK = { 0.49, 0.86, 0.54 }
local NO = { 1, 0.54, 0.48 }
local MUTED = { 0.6, 0.61, 0.65 }

local panel, timerBar, forcesBar, bosses
local timerID, timeLimit = nil, 0
local killTimes = {}
local completed = {}
local active = false
local finished = false
local trackerHidden = false
local ticker, previewTicker
-- The height of the 3.0 rows between the timer and the forces bar.
local shift = 0
local lastSecond

local function StopPreview()
	if previewTicker then previewTicker:Cancel() previewTicker = nil end
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format('%d:%02d', math.floor(seconds / 60), seconds % 60)
end

-- A value that is there and not hidden by the game. The hidden test comes first: a hidden value
-- is never compared, not even with nil.
local function Readable(v)
	return not issecretvalue(v) and v ~= nil
end

local function PlainTrue(v)
	return not issecretvalue(v) and v == true
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

------------------------------------------------------------------------
-- 3.0 (15): time in combat during a key, measured between PLAYER_REGEN_DISABLED and _ENABLED while
-- the key runs. The panel line and the run summary (6) read this one clock. It is kept in the
-- character's saved data, so a reload in the run keeps what was measured.
------------------------------------------------------------------------
local combat = { total = 0, since = nil, on = false }

local function SaveCombat(done)
	if ns.CharDB then ns.CharDB.keyCombat = { total = combat.total, done = done or nil } end
end

local function CombatEnd()
	if not combat.since then return end
	combat.total = combat.total + math.max(0, GetTime() - combat.since)
	combat.since = nil
end

function ns.KeyCombatTime()
	return combat.total + (combat.since and math.max(0, GetTime() - combat.since) or 0)
end

local function KeyRunning()
	return C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
end

local function CombatClock()
	ns.On('CHALLENGE_MODE_START', function()
		combat.total, combat.since, combat.on = 0, nil, true
		SaveCombat()
	end)
	-- A reload or a zone change: a running key goes on from what was saved for it.
	ns.On('PLAYER_ENTERING_WORLD', function()
		if not KeyRunning() then
			CombatEnd()
			combat.on = false
			return
		end
		if combat.on then return end
		local saved = ns.CharDB and ns.CharDB.keyCombat
		combat.total = saved and saved.total or 0
		combat.on = not (saved and saved.done)
		if combat.on and InCombatLockdown() then combat.since = GetTime() end
	end)
	ns.On('PLAYER_REGEN_DISABLED', function()
		if combat.on and not combat.since then combat.since = GetTime() end
	end)
	ns.On('PLAYER_REGEN_ENABLED', function()
		if not combat.since then return end
		CombatEnd()
		SaveCombat()
	end)
	ns.On('CHALLENGE_MODE_COMPLETED', function()
		if not combat.on then return end
		CombatEnd()
		combat.on = false
		SaveCombat(true)
	end)
	ns.On('CHALLENGE_MODE_RESET', function()
		combat.total, combat.since, combat.on = 0, nil, false
		SaveCombat()
	end)
end

------------------------------------------------------------------------
-- 3.0 (5): battle res charges and Bloodlust. Rebirth's charges are the group's shared pool in a
-- key and in a raid boss fight. The Sated debuffs are found by their IDs; when the game hides
-- their end (in combat and in a key), the end is counted from when the debuff was first seen.
------------------------------------------------------------------------
local BREZ = 20484
-- Exhaustion, Sated, Temporal Displacement, Insanity, Fatigued (two), Exhaustion of the evoker.
local SATED = { 57723, 57724, 80354, 95809, 160455, 264689, 390435 }
local SATED_SECONDS = 600
local satedUntil

local function SatedLeft()
	if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then return nil end
	local aura
	for _, id in ipairs(SATED) do
		aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
		if aura then break end
	end
	local now = GetTime()
	if not aura then
		satedUntil = nil
	else
		local expires = aura.expirationTime
		if Readable(expires) and expires > 0 then
			satedUntil = expires
		elseif not satedUntil or satedUntil <= now then
			satedUntil = now + SATED_SECONDS
		end
	end
	if ns.CharDB then ns.CharDB.satedUntil = satedUntil end
	return satedUntil and math.max(0, satedUntil - now)
end

-- One row: "BR 2 · next 3:12" on the left, "Lust ready" or "Sated 7:12" on the right. The
-- caller places the label and the Lust text.
local function BrezRow(parent, size)
	local row = {}
	row.label = ns.Text(parent, size)
	row.label:SetText('BR')
	row.count = ns.Text(parent, size)
	row.count:SetPoint('LEFT', row.label, 'RIGHT', 5, 0)
	row.next = ns.Text(parent, size)
	row.next:SetPoint('LEFT', row.count, 'RIGHT', 0, 0)
	row.next:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	row.lust = ns.Text(parent, size, 'RIGHT')
	return row
end

local function UpdateBrez(row)
	local info = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(BREZ)
	local charges = info and info.currentCharges
	if type(charges) == 'nil' then
		row.count:SetText('-')
		row.count:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		row.next:SetText('')
	else
		-- The count can be hidden: the text takes it as it is, only a readable one is colored.
		row.count:SetText(charges)
		if Readable(charges) then
			local c = charges > 0 and OK or NO
			row.count:SetTextColor(c[1], c[2], c[3])
		else
			row.count:SetTextColor(1, 1, 1)
		end
		local start, duration, max = info.cooldownStartTime, info.cooldownDuration, info.maxCharges
		if Readable(charges) and Readable(start) and Readable(duration) and Readable(max)
			and charges < max and start > 0 and duration > 0 then
			row.next:SetText(' · next ' .. Clock(start + duration - GetTime()))
		else
			row.next:SetText('')
		end
	end
	local left = SatedLeft()
	if left then
		row.lust:SetText('Sated |cffff8a7a' .. Clock(left) .. '|r')
	else
		row.lust:SetText('Lust |cff7ddc8aready|r')
	end
end

------------------------------------------------------------------------
-- 3.0 (2): the current pull. Each enemy in combat gives its forces through
-- GetUnitCriteriaProgressValues, a hidden value in a key: each one goes straight into a lighter
-- bar that starts where the one before it ends, so the pull adds up on the screen without a sum
-- in the code. The "+x%" needs that sum, so it is shown only while the values are readable.
-- Refreshed with the panel's once-a-second clock, and only while the group fights.
------------------------------------------------------------------------
local PULL = { 0.62, 0.82, 1, 0.85 }
local GROUP = { 'player', 'party1', 'party2', 'party3', 'party4' }
local pull = { segs = {} }
local forcesTotal = 0
local forcesDone = false

local function GroupInCombat()
	for _, unit in ipairs(GROUP) do
		if PlainTrue(UnitAffectingCombat(unit)) then return true end
	end
	return false
end

local function Segment(i)
	local seg = pull.segs[i]
	if seg then return seg end
	seg = CreateFrame('StatusBar', nil, pull.clip)
	seg:SetStatusBarTexture(ns.TEX)
	seg:SetStatusBarColor(PULL[1], PULL[2], PULL[3], PULL[4])
	seg:SetSize(W, forcesBar:GetHeight())
	pull.segs[i] = seg
	return seg
end

-- values: made-up forces of the test mode, otherwise the enemies in combat on the nameplates.
local function UpdatePull(values)
	if not pull.clip then return end
	local n, sum, readable = 0, 0, true
	local anchor = forcesBar:GetStatusBarTexture()
	local function add(value)
		n = n + 1
		local seg = Segment(n)
		seg:SetMinMaxValues(0, forcesTotal)
		seg:ClearAllPoints()
		seg:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', 0, 0)
		seg:SetValue(value)
		seg:Show()
		anchor = seg:GetStatusBarTexture()
		if Readable(value) then sum = sum + value else readable = false end
	end
	if values then
		for _, value in ipairs(values) do add(value) end
	elseif active and not finished and not forcesDone and forcesTotal > 0 and C_ScenarioInfo.GetUnitCriteriaProgressValues
		and GroupInCombat() then
		for i = 1, 40 do
			local unit = 'nameplate' .. i
			if PlainTrue(UnitExists(unit)) and PlainTrue(UnitCanAttack('player', unit))
				and PlainTrue(UnitAffectingCombat(unit)) and not PlainTrue(UnitIsDead(unit)) then
				-- Nothing for an enemy without forces. Only the type is tested, never the value.
				local value = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
				if type(value) ~= 'nil' then add(value) end
			end
		end
	end
	for i = n + 1, #pull.segs do pull.segs[i]:Hide() end
	if n > 0 and readable and forcesTotal > 0 then
		pull.text:SetFormattedText('+%.2f%%', sum / forcesTotal * 100)
		pull.text:Show()
	else
		pull.text:Hide()
	end
end

------------------------------------------------------------------------
-- 3.0 (7): personal best splits. A finished run whose every boss time was seen is kept per
-- dungeon and key level when it is the fastest at that level. The next run of that dungeon at
-- that level shows each killed boss ahead (green) or behind (red) of it, and the best time of the
-- bosses still alive.
------------------------------------------------------------------------
local best

local function BestStore()
	if not ns.CharDB then return nil end
	ns.CharDB.mplusBest = ns.CharDB.mplusBest or {}
	return ns.CharDB.mplusBest
end

local function LoadBest(mapID, level)
	local store = BestStore()
	local map = store and mapID and store[mapID]
	return map and level and map[level] or nil
end

local function SaveBest()
	if not feat.mplusSplits or not C_ChallengeMode.GetChallengeCompletionInfo then return end
	local info = C_ChallengeMode.GetChallengeCompletionInfo()
	if not info or info.practiceRun or not info.time or info.time <= 0 or not info.mapChallengeModeID then return end
	local splits, n = {}, 0
	for i, done in pairs(completed) do
		-- A boss whose kill was not seen (a reload in the run) leaves no best from this run.
		if not done or not killTimes[i] then return end
		splits[i] = killTimes[i]
		n = n + 1
	end
	if n == 0 then return end
	local store = BestStore()
	if not store then return end
	local seconds = info.time / 1000
	local map = store[info.mapChallengeModeID] or {}
	store[info.mapChallengeModeID] = map
	local old = map[info.level]
	if not old or seconds < old.time then map[info.level] = { time = seconds, splits = splits } end
end

local function ShowSplit(row, i)
	if not row.split then return end
	local pb = best and best.splits and best.splits[i]
	if pb and killTimes[i] then
		local diff = killTimes[i] - pb
		local c = diff <= 0 and OK or NO
		row.split:SetText((diff <= 0 and '-' or '+') .. Clock(math.abs(diff)))
		row.split:SetTextColor(c[1], c[2], c[3])
	else
		row.split:SetText('')
	end
end

------------------------------------------------------------------------
-- The panel.
------------------------------------------------------------------------
local function Build()
	-- The 3.0 rows that are switched on push the forces bar and the bosses down.
	local showCombat = feat.mplusCombat
	local showBrez = feat.mplusBrLust
	shift = (showCombat and ROW or 0) + (showBrez and ROW or 0)

	panel = CreateFrame('Frame', 'SlimARK_MythicPlus', UIParent)
	panel:SetSize(W, 120 + shift + MAX_BOSSES * LINE)
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

	local y = -100
	if showCombat then
		panel.Combat = ns.Text(panel, 16)
		panel.Combat:SetPoint('TOPLEFT', 0, y)
		panel.Combat:SetTextColor(0.84, 0.84, 0.86)
		y = y - ROW
	end
	if showBrez then
		panel.Brez = BrezRow(panel, 16)
		panel.Brez.label:SetPoint('TOPLEFT', 0, y)
		panel.Brez.lust:SetPoint('TOPRIGHT', 0, y)
	end

	forcesBar = Bar(panel, 18, C.colors.enemyCast)
	forcesBar:SetPoint('TOPLEFT', 0, -102 - shift)
	forcesBar:SetWidth(W)
	forcesBar:SetMinMaxValues(0, 100)
	if feat.mplusPull then
		-- The pull segments end at the bar's end; the texts sit on a layer above them.
		pull.clip = CreateFrame('Frame', nil, forcesBar)
		pull.clip:SetAllPoints()
		pull.clip:SetFrameLevel(forcesBar:GetFrameLevel() + 1)
		if pull.clip.SetClipsChildren then pull.clip:SetClipsChildren(true) end
	end
	local layer = ns.TextLayer(forcesBar)
	forcesBar.Text = ns.Text(layer, 15, 'CENTER')
	forcesBar.Text:SetPoint('CENTER')
	if pull.clip then
		pull.text = ns.Text(layer, 15, 'RIGHT')
		pull.text:SetPoint('RIGHT', -4, 0)
		pull.text:SetTextColor(PULL[1], PULL[2], PULL[3])
		pull.text:Hide()
	end

	bosses = {}
	for i = 1, MAX_BOSSES do
		local top = -128 - shift - (i - 1) * LINE
		local name = ns.Text(panel, 16)
		name:SetPoint('TOPLEFT', 0, top)
		name:SetPoint('RIGHT', feat.mplusSplits and -130 or -60, 0)
		local time = ns.Text(panel, 16, 'RIGHT')
		time:SetPoint('TOPRIGHT', 0, top)
		local row = { name = name, time = time }
		if feat.mplusSplits then
			row.split = ns.Text(panel, 16, 'RIGHT')
			row.split:SetPoint('TOPRIGHT', -64, top)
		end
		bosses[i] = row
	end

	ns.Register(panel, C.tracker.x - W, C.tracker.y + ns.TopInset() + (ns.MarkerInset and ns.MarkerInset() or 0), { key = 'mythicplus', w = W, h = panel:GetHeight(), side = 'RIGHT' })
end

local function Elapsed()
	if not timerID then return 0 end
	local _, elapsed = GetWorldElapsedTime(timerID)
	return elapsed or 0
end

-- The 3.0 rows, once a second from the panel's clock.
local function UpdateSlow()
	if panel.Combat then
		local spent, elapsed = ns.KeyCombatTime(), Elapsed()
		local pct = elapsed > 0 and math.floor(math.min(spent / elapsed, 1) * 100 + 0.5) or 0
		panel.Combat:SetFormattedText('In combat %s · %d%%', Clock(spent), pct)
	end
	if panel.Brez then UpdateBrez(panel.Brez) end
	UpdatePull()
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
	local second = math.floor(GetTime())
	if second ~= lastSecond then
		lastSecond = second
		UpdateSlow()
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
				forcesTotal = total or 0
				forcesDone = info.completed == true
				forcesBar:SetValue(math.min(pct, 100))
				if count then
					forcesBar.Text:SetFormattedText('%.2f%%  (%d/%d)', pct, count, total)
				else
					forcesBar.Text:SetFormattedText('%.2f%%', pct)
				end
			elseif line < MAX_BOSSES then
				line = line + 1
				local row = bosses[line]
				-- A boss already dead on the first snapshot has an unknown kill time (reload).
				-- Only a completion transition observed during this session supplies a time.
				if info.completed and completed[i] == false then killTimes[i] = Elapsed() end
				completed[i] = info.completed == true
				row.name:SetText(info.description)
				if info.completed then
					row.name:SetTextColor(0.5, 0.85, 0.5)
					row.time:SetTextColor(0.5, 0.85, 0.5)
					row.time:SetText(killTimes[i] and Clock(killTimes[i]) or '✓')
				else
					row.name:SetTextColor(1, 1, 1)
					local pb = row.split and best and best.splits and best.splits[i]
					row.time:SetText(pb and ('best ' .. Clock(pb)) or '')
					row.time:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
				end
				ShowSplit(row, i)
			end
		end
	end
	for i = line + 1, MAX_BOSSES do
		bosses[i].name:SetText('')
		bosses[i].time:SetText('')
		if bosses[i].split then bosses[i].split:SetText('') end
	end
	panel:SetHeight(128 + shift + line * LINE)
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

local function Start()
	StopPreview()
	local mapID = C_ChallengeMode.GetActiveChallengeMapID()
	if not mapID then return end
	local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
	local level = C_ChallengeMode.GetActiveKeystoneInfo()
	timeLimit = limit or 0
	best = feat.mplusSplits and LoadBest(mapID, level) or nil
	panel.Title:SetText(('+%d %s'):format(level or 0, name or ''))
	panel.Limit:SetText('/ ' .. Clock(timeLimit))
	FindTimer()
	active = true
	panel:Show()
	SetTrackerHidden(true)
	UpdateCriteria()
	UpdateDeaths()
	lastSecond = nil
	UpdateTime()
	-- Four updates a second keep the clock smooth, and the panel does nothing outside a key.
	if not ticker then ticker = C_Timer.NewTicker(0.25, UpdateTime) end
end

local function Stop()
	StopPreview()
	active, finished = false, false
	wipe(killTimes)
	wipe(completed)
	best = nil
	forcesTotal, forcesDone = 0, false
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	if panel then
		UpdatePull()
		panel:Hide()
	end
	SetTrackerHidden(false)
end

local function Check()
	if not panel then return end
	if C_ChallengeMode.IsChallengeModeActive() then Start() else Stop() end
end

-- The test mode shows the panel with a made-up run. A real key always wins.
function ns.MythicPlusPreview(on)
	StopPreview()
	if not panel or active then return end
	if not on then
		best = nil
		forcesTotal = 0
		UpdatePull()
		panel:Hide()
		SetTrackerHidden(false)
		return
	end
	timeLimit = 31 * 60
	panel.Title:SetText('+12 Voidscar Arena')
	panel.Limit:SetText('/ ' .. Clock(timeLimit))
	panel.Deaths:SetFormattedText('%d deaths  -%s', 2, Clock(10))
	forcesBar:SetValue(63.47)
	forcesBar.Text:SetFormattedText('%.2f%%  (%d/%d)', 63.47, 292, 460)
	-- 3.0: two pulled enemies, a best run to compare with and the battle res row.
	forcesTotal = 460
	UpdatePull({ 18, 14 })
	best = { splits = { 313, 627, 1185, 1470 } }
	wipe(killTimes)
	local names = { { 'Kaltrix the Hollow', 291 }, { 'Warden Ossek', 668 }, { 'Mother of Echoes' }, { 'The Unbound' } }
	for i = 1, MAX_BOSSES do
		local row, b = bosses[i], names[i]
		local done = b and b[2]
		killTimes[i] = done or nil
		row.name:SetText(b and b[1] or '')
		row.name:SetTextColor(done and 0.5 or 1, done and 0.85 or 1, done and 0.5 or 1)
		if done then
			row.time:SetText(Clock(b[2]))
			row.time:SetTextColor(0.5, 0.85, 0.5)
		else
			row.time:SetText(b and row.split and ('best ' .. Clock(best.splits[i])) or '')
			row.time:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
		ShowSplit(row, i)
	end
	wipe(killTimes)
	if panel.Brez then
		panel.Brez.count:SetText(2)
		panel.Brez.count:SetTextColor(OK[1], OK[2], OK[3])
		panel.Brez.next:SetText(' · next 3:12')
		panel.Brez.lust:SetText('Lust |cff7ddc8aready|r')
	end
	panel:SetHeight(128 + shift + #names * LINE)
	local elapsed = 14 * 60 + 32
	local function Tick()
		elapsed = elapsed + 1
		panel.Time:SetText(Clock(elapsed))
		panel.Time:SetTextColor(1, 1, 1)
		timerBar:SetMinMaxValues(0, timeLimit)
		timerBar:SetValue(elapsed)
		panel.Plus3:SetText('+3 ' .. Clock(timeLimit * 0.6 - elapsed))
		panel.Plus2:SetText('+2 ' .. Clock(timeLimit * 0.8 - elapsed))
		panel.Plus3:SetTextColor(0.5, 0.85, 0.5)
		panel.Plus2:SetTextColor(0.5, 0.85, 0.5)
		if panel.Combat then
			panel.Combat:SetFormattedText('In combat %s · %d%%', Clock(elapsed * 0.62), 62)
		end
	end
	Tick()
	previewTicker = C_Timer.NewTicker(1, Tick)
	panel:Show()
	SetTrackerHidden(true)
end

------------------------------------------------------------------------
-- 3.0 (5): the battle res and Bloodlust row above the boss frames during a raid boss fight, where
-- the charges are shared. Placed by the boss frames' position; its own one second clock runs
-- only while it shows.
------------------------------------------------------------------------
local raid, raidTicker
local RAID_H = 28

local function RaidBlock()
	if raid then return raid end
	local b = C.units.boss
	raid = CreateFrame('Frame', 'SlimARK_RaidBrez', UIParent)
	raid:SetSize(b.w, RAID_H)
	local bg = raid:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.055, 0.07, 0.85)
	ns.Outline(raid)
	raid.row = BrezRow(raid, 15)
	raid.row.label:SetPoint('LEFT', 8, 0)
	raid.row.lust:SetPoint('RIGHT', -8, 0)
	raid:Hide()
	ns.Register(raid, b.x, b.y - RAID_H - 12, { key = 'raidbrez', w = b.w, h = RAID_H, side = 'RIGHT' })
	return raid
end

local function RaidShow(on)
	if on then
		local f = RaidBlock()
		UpdateBrez(f.row)
		f:Show()
		if not raidTicker then raidTicker = C_Timer.NewTicker(1, function() UpdateBrez(raid.row) end) end
	else
		if raidTicker then raidTicker:Cancel() raidTicker = nil end
		if raid then raid:Hide() end
	end
end

local function InRaid()
	if not GetInstanceInfo then return false end
	local _, kind = GetInstanceInfo()
	return kind == 'raid'
end

function ns.RaidBrezPreview(on)
	if ns.isForever or not feat.raidBrLust or raidTicker then return end
	if not on then
		if raid then raid:Hide() end
		return
	end
	local f = RaidBlock()
	f.row.count:SetText(2)
	f.row.count:SetTextColor(OK[1], OK[2], OK[3])
	f.row.next:SetText(' · next 3:12')
	f.row.lust:SetText('Lust |cff7ddc8aready|r')
	f:Show()
end

ns.On('PLAYER_LOGIN', function()
	if ns.isForever or not C_ChallengeMode then return end
	if ns.CharDB and ns.CharDB.satedUntil and ns.CharDB.satedUntil > GetTime() then satedUntil = ns.CharDB.satedUntil end
	-- The combat clock serves the panel line and the run summary; with both off it is not there.
	if (C.modules.mythicplus and feat.mplusCombat) or feat.runSummary then CombatClock() end
	if feat.raidBrLust then
		ns.On('ENCOUNTER_START', function() RaidShow(InRaid()) end)
		ns.On('ENCOUNTER_END', function() RaidShow(false) end)
		ns.On('PLAYER_ENTERING_WORLD', function()
			RaidShow(InRaid() and ns.InEncounter())
		end)
	end
end)

ns.On('PLAYER_LOGIN', function()
	if ns.isForever or not C.modules.mythicplus or not C_ChallengeMode then return end
	Build()
	KeepTrackerHidden()
end)
ns.On('CHALLENGE_MODE_START', function()
	if panel then Stop() end
	C_Timer.After(0.5, Check)
end)
ns.On('PLAYER_ENTERING_WORLD', function() C_Timer.After(1, Check) end)
ns.On('WORLD_STATE_TIMER_START', function()
	if active then FindTimer() end
end)
ns.On('CHALLENGE_MODE_COMPLETED', function()
	if not active or not panel then return end
	UpdateCriteria()
	-- The pull goes, the last combat line and battle res row stay with the final time.
	finished = true
	UpdateTime()
	UpdateSlow()
	SaveBest()
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
