local _, ns = ...
local C = ns.C
local feat = C.features

-- The run summary (3.0, items 6 and 9). At the end of a key a flat window shows the time, the
-- limit, the time in combat and its share of the run (the Mythic+ panel's clock, item 15), the
-- deaths and the change of your score; a row per member with damage, healing, kicks and deaths
-- from Blizzard's damage meter, read once the combat is over; and the loot the group got, marked
-- when it is a higher item level than what you wear in that slot. The last 20 runs are kept per
-- character and can be paged back. Nothing is registered while it is off; the window is made on
-- its first use.

local MAX_RUNS = 20
local MAX_LOOT = 10
local MAX_TRIES = 4
local W, HEAD, PAD, ROW = 620, 36, 12, 22
local BG = { 0.071, 0.075, 0.09, 0.96 }
local STRIP = { 0.098, 0.102, 0.122, 1 }
local GOLD = { 0.95, 0.72, 0.29 }
local OK = { 0.49, 0.86, 0.54 }
local NO = { 1, 0.54, 0.48 }
local MUTED = { 0.6, 0.61, 0.65 }
local WHITE = { 1, 1, 1 }
local GROUP = { 'player', 'party1', 'party2', 'party3', 'party4' }

local run      -- the key being played: the meter's state at its start and the loot so far
local current  -- the finished run, still taking the loot handed out until you leave the dungeon
local harvest  -- the finished run waiting for the damage meter
local window, shownIndex, preview

-- A value that is there and not hidden by the game. The hidden test comes first.
local function Readable(v)
	return not issecretvalue(v) and v ~= nil
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format('%d:%02d', math.floor(seconds / 60), seconds % 60)
end

local function Runs()
	if not ns.CharDB then return {} end
	ns.CharDB.runs = ns.CharDB.runs or {}
	return ns.CharDB.runs
end

local function KeyRunning()
	return C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
end

------------------------------------------------------------------------
-- Blizzard's damage meter. Its sessions are hidden in combat, so they are read after it; the
-- Overall session is taken at the key's start too, and the run is the difference.
------------------------------------------------------------------------
local METRICS = { 'damage', 'healing', 'kicks', 'deaths' }
local KINDS = { damage = 'DamageDone', healing = 'HealingDone', kicks = 'Interrupts', deaths = 'Deaths' }
local PETS = { pet = 'player', partypet1 = 'party1', partypet2 = 'party2', partypet3 = 'party3', partypet4 = 'party4' }

-- A demon's kicks are filed under the demon: its row counts for its owner.
local function PetOwners()
	local owners = {}
	for pet, owner in pairs(PETS) do
		local p, o = UnitGUID(pet), UnitGUID(owner)
		if Readable(p) and Readable(o) then owners[p] = o end
	end
	return owners
end

-- The totals of one meter type by GUID, or nil while the session cannot be read whole (in
-- combat, or a hidden value still in it).
local function ReadMeter(key, owners)
	local types, sessions = Enum.DamageMeterType, Enum.DamageMeterSessionType
	local kind, overall = types and types[KINDS[key]], sessions and sessions.Overall
	if kind == nil or overall == nil or not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromType then return nil end
	local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, overall, kind)
	if not ok or type(session) ~= 'table' then return nil end
	local totals, hidden = {}, false
	-- A hidden table is still a table: walking it raises, so the walk is guarded too.
	local walked = pcall(function()
		for _, src in ipairs(session.combatSources) do
			local guid = src.sourceGUID
			if issecretvalue(guid) then
				hidden = true
			elseif guid then
				guid = owners[guid] or guid
				if key == 'deaths' then
					-- One row per death.
					local recap = src.deathRecapID
					if Readable(recap) and recap > 0 then totals[guid] = (totals[guid] or 0) + 1 end
				else
					local amount = src.totalAmount
					if Readable(amount) then totals[guid] = (totals[guid] or 0) + amount else hidden = true end
				end
			end
		end
	end)
	if not walked or hidden then return nil end
	return totals
end

local function Baseline()
	local base, owners = {}, PetOwners()
	for _, key in ipairs(METRICS) do base[key] = ReadMeter(key, owners) or {} end
	return base
end

------------------------------------------------------------------------
-- Loot (9): who got what, with the gain over what you wear in that slot.
------------------------------------------------------------------------
local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CLOAK = { 15 }, INVTYPE_CHEST = { 5 },
	INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
	INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_WEAPON = { 16, 17 },
	INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 },
	INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
}
-- The armor each class wears, by Enum.ItemArmorSubclass name.
local ARMOR = {
	MAGE = 'Cloth', PRIEST = 'Cloth', WARLOCK = 'Cloth', DRUID = 'Leather', ROGUE = 'Leather', MONK = 'Leather',
	DEMONHUNTER = 'Leather', HUNTER = 'Mail', SHAMAN = 'Mail', EVOKER = 'Mail', WARRIOR = 'Plate', PALADIN = 'Plate',
	DEATHKNIGHT = 'Plate',
}

local function ItemLevel(item)
	local level = item and C_Item.GetDetailedItemLevelInfo(item)
	return Readable(level) and level or nil
end

local function WornLevel(slot)
	local link = GetInventoryItemLink('player', slot)
	-- An empty off hand beside a two-hander counts as the two-hander.
	if not link and slot == 17 then link = GetInventoryItemLink('player', 16) end
	return link and ItemLevel(link) or 0
end

-- The item levels above what you wear in its slot (the lower of two rings or trinkets) when it is
-- for you, and a short grey word for the row otherwise.
local function Compare(link)
	local _, _, subType, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
	local slots = equipLoc and SLOTS[equipLoc]
	if not slots then return nil, nil end
	local note = _G[equipLoc] or ''
	local sub = Enum.ItemArmorSubclass
	if sub and classID == Enum.ItemClass.Armor and equipLoc ~= 'INVTYPE_CLOAK' and subclassID
		and (subclassID == sub.Cloth or subclassID == sub.Leather or subclassID == sub.Mail or subclassID == sub.Plate) then
		note = subType or note
		local _, class = UnitClass('player')
		if not ARMOR[class] or subclassID ~= sub[ARMOR[class]] then return nil, note:lower() end
	end
	local level = ItemLevel(link)
	if not level then return nil, note:lower() end
	local worn
	for _, slot in ipairs(slots) do
		local have = WornLevel(slot)
		if not worn or have < worn then worn = have end
	end
	local gain = level - (worn or 0)
	return gain > 0 and gain or nil, note:lower()
end

local RefreshShown

local function OnLoot(_, _, _, link, _, who, class)
	local list = (current and current.loot) or (run and run.loot)
	if not list or #list >= MAX_LOOT or not Readable(link) or not Readable(who) then return end
	local gain, note = Compare(link)
	table.insert(list, { who = Ambiguate(who, 'short'), class = Readable(class) and class or nil, link = link,
		level = ItemLevel(link), gain = gain, note = note })
	if current then RefreshShown() end
end

------------------------------------------------------------------------
-- The end of a run.
------------------------------------------------------------------------
local function Members(info)
	local list = {}
	for _, m in ipairs(info.members or {}) do
		local guid, name = m.memberGUID, m.name
		if Readable(guid) and Readable(name) then
			local class
			if GetPlayerInfoByGUID then
				local _, c = GetPlayerInfoByGUID(guid)
				if Readable(c) then class = c end
			end
			table.insert(list, { guid = guid, name = Ambiguate(name, 'short'), class = class })
		end
	end
	if #list > 0 then return list end
	for _, unit in ipairs(GROUP) do
		if UnitExists(unit) then
			local guid, name = UnitGUID(unit), UnitName(unit)
			local _, class = UnitClass(unit)
			if Readable(guid) and Readable(name) then
				table.insert(list, { guid = guid, name = name, class = Readable(class) and class or nil })
			end
		end
	end
	return list
end

local function Fill(rec, got, base)
	for _, m in ipairs(rec.members) do
		for _, key in ipairs(METRICS) do
			local totals = got[key]
			if totals then
				local before = base[key] and base[key][m.guid] or 0
				m[key] = math.max(0, (totals[m.guid] or 0) - before)
			end
		end
	end
end

local ShowIndex

local function Harvest()
	local h = harvest
	if not h then return end
	if InCombatLockdown() then
		h.waiting = true
		return
	end
	local owners, whole = PetOwners(), true
	for _, key in ipairs(METRICS) do
		if not h.got[key] then
			local totals = ReadMeter(key, owners)
			if totals then h.got[key] = totals else whole = false end
		end
	end
	-- The meter can stay hidden a moment after the combat: a few more tries, then what was read.
	if not whole and h.tries < MAX_TRIES then
		h.tries = h.tries + 1
		C_Timer.After(2, Harvest)
		return
	end
	harvest = nil
	Fill(h.rec, h.got, h.base)
	if Runs()[1] == h.rec then ShowIndex(1) end
end

local function Finish()
	local info = C_ChallengeMode.GetChallengeCompletionInfo()
	local mapID = info and info.mapChallengeModeID
	if not info or info.practiceRun or not Readable(mapID) or mapID == 0 then
		run = nil
		return
	end
	local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
	local deaths = C_ChallengeMode.GetDeathCount()
	local old, new = info.oldOverallDungeonScore, info.newOverallDungeonScore
	local rec = {
		map = mapID, name = name or '?', level = info.level, time = (info.time or 0) / 1000, limit = limit,
		onTime = info.onTime == true, upgrade = info.keystoneUpgradeLevels,
		combat = ns.KeyCombatTime and ns.KeyCombatTime() or nil, deaths = deaths,
		score = (Readable(old) and Readable(new)) and math.floor(new - old + 0.5) or nil,
		date = GetServerTime and GetServerTime() or nil, members = Members(info),
		loot = run and run.loot or {}, reset = run and run.reset or nil,
	}
	local runs = Runs()
	table.insert(runs, 1, rec)
	for i = #runs, MAX_RUNS + 1, -1 do runs[i] = nil end
	current = rec
	harvest = { rec = rec, base = run and run.base or {}, got = {}, tries = 0 }
	run = nil
	if InCombatLockdown() then harvest.waiting = true else C_Timer.After(1, Harvest) end
end

------------------------------------------------------------------------
-- The window, in the flat look of the ready check window.
------------------------------------------------------------------------
local function Texture(frame, color, layer)
	local t = frame:CreateTexture(nil, layer or 'BACKGROUND')
	t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return t
end

local function Hairline(parent)
	local t = Texture(parent, { 0.15, 0.153, 0.176 }, 'ARTWORK')
	t:SetHeight(1)
	return t
end

local function FlatButton(parent, label, width)
	local b = CreateFrame('Button', nil, parent)
	b:SetSize(width, 24)
	Texture(b, { 0.165, 0.169, 0.192 }):SetAllPoints()
	ns.Outline(b)
	local hl = b:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.1)
	b.text = ns.Text(b, 14, 'CENTER')
	b.text:SetPoint('CENTER')
	b.text:SetText(label)
	return b
end

local function Muted(fs)
	fs:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	return fs
end

-- The right edges of the number columns, from the window's left side.
local COLS = { W - PAD - 270, W - PAD - 170, W - PAD - 85, W - PAD }
local COL_NAMES = { 'DAMAGE', 'HEALING', 'KICKS', 'DEATHS' }

local function Build()
	window = CreateFrame('Frame', 'SlimARK_RunSummary', UIParent)
	window:SetFrameStrata('DIALOG')
	window:SetSize(W, 400)
	window:EnableMouse(true)
	Texture(window, BG):SetAllPoints()
	ns.Outline(window)
	local strip = Texture(window, STRIP, 'BORDER')
	strip:SetPoint('TOPLEFT')
	strip:SetPoint('TOPRIGHT')
	strip:SetHeight(HEAD)
	local gold = Texture(window, GOLD, 'ARTWORK')
	gold:SetPoint('TOPLEFT')
	gold:SetPoint('TOPRIGHT')
	gold:SetHeight(2)
	local under = Texture(window, { 0, 0, 0 }, 'ARTWORK')
	under:SetPoint('TOPLEFT', 0, -HEAD)
	under:SetPoint('TOPRIGHT', 0, -HEAD)
	under:SetHeight(1)
	window:Hide()
	table.insert(UISpecialFrames, 'SlimARK_RunSummary')
	ns.Register(window, C.runsummary.x, C.runsummary.y, { key = 'runsummary', w = W, h = 400 })

	window.title = ns.Text(window, 17)
	window.title:SetPoint('TOPLEFT', PAD, -11)
	window.title:SetPoint('RIGHT', -230, 0)
	window.sub = Muted(ns.Text(window, 14, 'RIGHT'))
	window.sub:SetPoint('TOPRIGHT', -PAD, -12)

	-- Five numbers in a row, a small grey name above each.
	window.stats = {}
	local cell = (W - 2 * PAD) / 5
	for i = 1, 5 do
		local label = Muted(ns.Text(window, 12))
		label:SetPoint('TOPLEFT', PAD + (i - 1) * cell, -HEAD - 10)
		local value = ns.Text(window, 19)
		value:SetPoint('TOPLEFT', PAD + (i - 1) * cell, -HEAD - 26)
		window.stats[i] = { label = label, value = value }
	end

	-- The members' table.
	local top = -HEAD - 62
	local head = Muted(ns.Text(window, 12))
	head:SetPoint('TOPLEFT', PAD, top)
	head:SetText('PLAYER')
	for i, name in ipairs(COL_NAMES) do
		local h = Muted(ns.Text(window, 12, 'RIGHT'))
		h:SetPoint('TOPRIGHT', window, 'TOPLEFT', COLS[i], top)
		h:SetText(name)
	end
	local line = Hairline(window)
	line:SetPoint('TOPLEFT', PAD, top - 16)
	line:SetPoint('TOPRIGHT', -PAD, top - 16)
	window.members = {}
	for r = 1, 5 do
		local y = top - 22 - (r - 1) * ROW
		local row = { name = ns.Text(window, 15), cols = {} }
		row.name:SetPoint('TOPLEFT', PAD, y)
		row.name:SetPoint('RIGHT', window, 'LEFT', COLS[1] - 90, 0)
		for i = 1, 4 do
			local fs = ns.Text(window, 15, 'RIGHT')
			fs:SetPoint('TOPRIGHT', window, 'TOPLEFT', COLS[i], y)
			row.cols[i] = fs
		end
		window.members[r] = row
	end

	-- The loot list and its heading; placed under the members on every render.
	window.lootHead = Muted(ns.Text(window, 12))
	window.lootHead:SetText('LOOT')
	window.lootLine = Hairline(window)
	window.loot = {}
	for r = 1, MAX_LOOT do
		local row = { who = ns.Text(window, 15), item = ns.Text(window, 15), level = ns.Text(window, 15, 'RIGHT'), note = ns.Text(window, 14) }
		window.loot[r] = row
	end
	window.note = Muted(ns.Text(window, 13))

	-- History paging and the close button.
	window.older = FlatButton(window, '<', 28)
	window.older:SetPoint('BOTTOMLEFT', PAD, PAD)
	window.older:SetScript('OnClick', function() ShowIndex((shownIndex or 1) + 1) end)
	window.newer = FlatButton(window, '>', 28)
	window.newer:SetPoint('LEFT', window.older, 'RIGHT', 4, 0)
	window.newer:SetScript('OnClick', function() ShowIndex((shownIndex or 1) - 1) end)
	window.counter = Muted(ns.Text(window, 13))
	window.counter:SetPoint('LEFT', window.newer, 'RIGHT', 10, 0)
	window.close = FlatButton(window, 'Close', 80)
	window.close:SetPoint('BOTTOMRIGHT', -PAD, PAD)
	window.close:SetScript('OnClick', function() window:Hide() end)
	window:SetScript('OnHide', function() preview = nil end)
end

-- 412.3k, 2.41M, 1.20B.
local function Short(n)
	if not n then return '-' end
	if n >= 1e9 then return ('%.2fB'):format(n / 1e9) end
	if n >= 1e6 then return ('%.2fM'):format(n / 1e6) end
	if n >= 1e4 then return ('%.1fk'):format(n / 1e3) end
	return tostring(math.floor(n + 0.5))
end

local function ClassColor(class)
	local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function SetStat(i, label, text, color)
	local s = window.stats[i]
	color = color or WHITE
	s.label:SetText(label)
	s.value:SetText(text)
	s.value:SetTextColor(color[1], color[2], color[3])
end

local function Render(rec, counter)
	window.title:SetText(('%s +%d'):format(rec.name or '?', rec.level or 0))
	if rec.onTime then
		window.sub:SetText(('timed +%d · run summary'):format(rec.upgrade or 1))
	else
		window.sub:SetText('over time · run summary')
	end
	SetStat(1, 'TIME', Clock(rec.time), rec.onTime and OK or NO)
	SetStat(2, 'LIMIT', rec.limit and Clock(rec.limit) or '-')
	local spent = '-'
	if rec.combat and rec.time and rec.time > 0 then
		spent = ('%s · %d%%'):format(Clock(rec.combat), math.floor(math.min(rec.combat / rec.time, 1) * 100 + 0.5))
	end
	SetStat(3, 'IN COMBAT', spent)
	SetStat(4, 'DEATHS', rec.deaths and tostring(rec.deaths) or '-')
	SetStat(5, 'SCORE', rec.score and ((rec.score > 0 and '+' or '') .. rec.score) or '-', rec.score and rec.score > 0 and OK or nil)

	local members = rec.members or {}
	for r, row in ipairs(window.members) do
		local m = members[r]
		if m then
			row.name:SetText(m.name or '?')
			row.name:SetTextColor(ClassColor(m.class))
			for i, key in ipairs(METRICS) do
				local v = m[key]
				row.cols[i]:SetText((key == 'damage' or key == 'healing') and Short(v) or (v and tostring(v) or '-'))
			end
		else
			row.name:SetText('')
			for i = 1, 4 do row.cols[i]:SetText('') end
		end
	end

	local y = -HEAD - 62 - 22 - math.max(#members, 1) * ROW - 10
	local loot = rec.loot or {}
	local showLoot = feat.runLoot
	window.lootHead:SetShown(showLoot)
	window.lootLine:SetShown(showLoot)
	if showLoot then
		window.lootHead:ClearAllPoints()
		window.lootHead:SetPoint('TOPLEFT', PAD, y)
		window.lootLine:ClearAllPoints()
		window.lootLine:SetPoint('TOPLEFT', PAD, y - 16)
		window.lootLine:SetPoint('TOPRIGHT', -PAD, y - 16)
		y = y - 22
		if #loot == 0 then
			window.lootHead:SetText('LOOT · none seen')
		else
			window.lootHead:SetText('LOOT')
		end
	end
	for r, row in ipairs(window.loot) do
		local item = showLoot and loot[r]
		for _, fs in pairs(row) do fs:SetShown(item and true or false) end
		if item then
			row.who:ClearAllPoints()
			row.who:SetPoint('TOPLEFT', PAD, y)
			row.who:SetWidth(110)
			row.who:SetText(item.who or '?')
			row.who:SetTextColor(ClassColor(item.class))
			row.item:ClearAllPoints()
			row.item:SetPoint('TOPLEFT', PAD + 118, y)
			row.item:SetWidth(W - 2 * PAD - 118 - 210)
			-- The name in its quality color, without the link part.
			local name = (item.link or ''):gsub('|H.-|h%[?(.-)%]?|h', '%1')
			row.item:SetText(name)
			row.level:ClearAllPoints()
			row.level:SetPoint('TOPRIGHT', window, 'TOPLEFT', W - PAD - 165, y)
			row.level:SetText(item.level and tostring(item.level) or '')
			row.note:ClearAllPoints()
			row.note:SetPoint('TOPLEFT', W - PAD - 155, y)
			row.note:SetWidth(155)
			if item.gain then
				row.note:SetText(('upgrade for you (+%d)'):format(item.gain))
				row.note:SetTextColor(OK[1], OK[2], OK[3])
			else
				row.note:SetText(item.note or '')
				row.note:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
			end
			y = y - ROW
		end
	end

	window.note:SetShown(rec.reset == true)
	if rec.reset then
		window.note:ClearAllPoints()
		window.note:SetPoint('TOPLEFT', PAD, y - 4)
		window.note:SetText('The damage meter was reset during the run: its numbers cover only the part after it.')
		y = y - ROW
	end

	window.counter:SetText(counter or '')
	window:SetHeight(-y + 12 + 24 + PAD)
end

ShowIndex = function(i)
	local runs = Runs()
	local rec = runs[i]
	if not rec then return end
	if not window then Build() end
	shownIndex, preview = i, nil
	local when = rec.date and date and date('%Y-%m-%d %H:%M', rec.date)
	Render(rec, ('Run %d of %d%s'):format(i, #runs, when and (' · ' .. when) or ''))
	window.older:SetEnabled(i < #runs)
	window.older:SetAlpha(i < #runs and 1 or 0.4)
	window.newer:SetEnabled(i > 1)
	window.newer:SetAlpha(i > 1 and 1 or 0.4)
	window:Show()
end

RefreshShown = function()
	if window and window:IsShown() and not preview and shownIndex and Runs()[shownIndex] == current then
		ShowIndex(shownIndex)
	end
end

-- The settings page opens the newest saved run.
function ns.ShowRunHistory()
	if ns.isForever or not feat.runSummary then return end
	if #Runs() == 0 then
		ns.Print('No Mythic+ run saved yet. The summary of a key is kept when it ends.')
		return
	end
	ShowIndex(1)
end

-- The test mode shows a made-up run (never saved).
local SAMPLE = {
	name = 'Voidscar Arena', level = 12, time = 1878, limit = 1980, onTime = true, upgrade = 1, combat = 1300,
	deaths = 3, score = 14,
	members = {
		{ name = 'Aril', class = 'PALADIN', damage = 412300000, healing = 18200000, kicks = 14, deaths = 1 },
		{ name = 'Brakk', class = 'WARRIOR', damage = 298000000, healing = 9100000, kicks = 11, deaths = 0 },
		{ name = 'Thundra', class = 'SHAMAN', damage = 387600000, healing = 12400000, kicks = 9, deaths = 2 },
		{ name = 'Lumi', class = 'PRIEST', damage = 61200000, healing = 402900000, kicks = 0, deaths = 0 },
	},
	loot = {
		{ who = 'Brakk', class = 'WARRIOR', link = '|cffa335eeVoidscarred Greaves|r', level = 684, gain = 9 },
		{ who = 'Thundra', class = 'SHAMAN', link = '|cffa335eeRitualist\'s Cord|r', level = 684, note = 'cloth' },
	},
}

function ns.RunSummaryPreview(on)
	if ns.isForever or not feat.runSummary then return end
	if not on then
		if window and preview then window:Hide() end
		return
	end
	if not window then Build() end
	Render(SAMPLE, 'Test mode: a made-up run')
	for _, b in ipairs({ window.older, window.newer }) do
		b:SetEnabled(false)
		b:SetAlpha(0.4)
	end
	preview = true
	window:Show()
end

ns.On('PLAYER_LOGIN', function()
	if ns.isForever or not feat.runSummary or not C_ChallengeMode or not C_ChallengeMode.GetChallengeCompletionInfo then return end
	ns.On('CHALLENGE_MODE_START', function()
		run = { base = Baseline(), loot = {} }
		current, harvest = nil, nil
	end)
	ns.On('CHALLENGE_MODE_COMPLETED', function()
		-- A second delivery of the same end keeps the first record.
		if not run and current then return end
		Finish()
	end)
	ns.On('CHALLENGE_MODE_RESET', function() run = nil end)
	ns.On('PLAYER_REGEN_ENABLED', function()
		if harvest and harvest.waiting then
			harvest.waiting = false
			C_Timer.After(1, Harvest)
		end
	end)
	ns.On('PLAYER_ENTERING_WORLD', function()
		-- Leaving the dungeon closes the loot list of the finished run.
		if current and not IsInInstance() then current = nil end
		-- A reload in a running key collects from here, without the meter's state at the start.
		if not run and not current and KeyRunning() then run = { base = {}, loot = {} } end
	end)
	-- A meter reset in the run: the numbers start again from it, and the summary says so.
	ns.On('DAMAGE_METER_RESET', function()
		if not run then return end
		run.base = {}
		if ns.KeyCombatTime and ns.KeyCombatTime() > 0 then run.reset = true end
	end)
	if feat.runLoot then ns.On('ENCOUNTER_LOOT_RECEIVED', OnLoot) end
end)
