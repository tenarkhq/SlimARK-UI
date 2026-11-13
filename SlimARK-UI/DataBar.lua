local _, ns = ...
local C = ns.C

-- The top bar: a flat strip on the top pixel row over the whole width. Left: the micro menu,
-- durability, FPS, latency, the queue and the tracked currencies. Middle: the clock. Right:
-- gold, item level, the keystone with the teleport list, the Great Vault, the auto quest
-- switch and the addon icons above the map.
-- 3.0 adds, each with its own switch: friends and guild online and the spec and loadout (left), Alts
-- and the quiet mode switch (right), an XP/reputation line on the bottom edge, the addon CPU in the
-- FPS tooltip and this week's data in the Great Vault tooltip.
local cfg = C.databar
local show = cfg.show
local PAD = 10
local MUTED = 'ff9a968c'
local GOLD = 'fff2b84a'

local bar, micro
local leftChain, rightChain = {}, {}
local seg = {}
local currencySegs = {}
local sessionMoney

local function Snap(w)
	local fit = ns.Fit()
	return math.floor(w * fit + 0.5) / fit
end

local function Label(text)
	return '|c' .. MUTED .. text .. '|r '
end

local function Colored(color, text)
	return '|c' .. color .. text .. '|r'
end

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

local function Tooltip(owner)
	GameTooltip:SetOwner(owner, 'ANCHOR_NONE')
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint('TOP', owner, 'BOTTOM', 0, -4)
end

-- A segment: text with a black line on its inner side, its width follows the text.
local function Segment(name, rightSide)
	local s = CreateFrame('Button', nil, bar)
	s:SetHeight(cfg.h)
	s:RegisterForClicks('AnyUp')
	s.text = ns.Text(s, cfg.font, 'LEFT')
	s.text:SetPoint('LEFT', PAD, 0)
	local line = s:CreateTexture(nil, 'ARTWORK')
	line:SetColorTexture(0, 0, 0, 1)
	line:SetWidth(ns.Px())
	line:SetPoint(rightSide and 'TOPLEFT' or 'TOPRIGHT')
	line:SetPoint(rightSide and 'BOTTOMLEFT' or 'BOTTOMRIGHT')
	local hl = s:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.06)
	s:SetScript('OnLeave', GameTooltip_Hide)
	s.key = name
	return s
end

local function SetText(s, text)
	if s.value == text and s:IsShown() then return end
	s.value = text
	s.text:SetText(text)
	s:SetWidth(Snap(s.text:GetUnboundedStringWidth() + 2 * PAD))
	s:Show()
end

local function Hide(s)
	if not s then return end
	s.value = nil
	s:SetWidth(0.001)
	s:Hide()
end

-- Left segments follow each other from the micro menu, right segments from the addon icons.
local function Chain()
	local prev = micro
	for _, s in ipairs(leftChain) do
		s:ClearAllPoints()
		if prev then
			s:SetPoint('LEFT', prev, 'RIGHT', 0, 0)
		else
			s:SetPoint('LEFT', bar, 'LEFT', 0, 0)
		end
		prev = s
	end
	local next = ns.barLogos
	for i = #rightChain, 1, -1 do
		local s = rightChain[i]
		s:ClearAllPoints()
		if next then
			s:SetPoint('RIGHT', next, 'LEFT', next == ns.barLogos and -6 or 0, 0)
		else
			s:SetPoint('RIGHT', bar, 'RIGHT', -6, 0)
		end
		next = s
	end
end

------------------------------------------------------------------------
-- Micro menu: the Blizzard buttons' own pictures, small. A click presses the real button
-- through a secure click, so every window opens the same way and nothing is tainted.
------------------------------------------------------------------------
local MICRO = {
	{ 'CharacterMicroButton' },
	{ 'ProfessionMicroButton', 'UI-HUD-MicroMenu-Professions-Up' },
	{ 'PlayerSpellsMicroButton', 'UI-HUD-MicroMenu-SpecTalents-Up' },
	{ 'AchievementMicroButton', 'UI-HUD-MicroMenu-Achievements-Up' },
	{ 'QuestLogMicroButton', 'UI-HUD-MicroMenu-Questlog-Up' },
	{ 'HousingMicroButton', 'UI-HUD-MicroMenu-Housing-Up' },
	{ 'GuildMicroButton', 'UI-HUD-MicroMenu-GuildCommunities-Up' },
	{ 'LFDMicroButton', 'UI-HUD-MicroMenu-Groupfinder-Up' },
	{ 'CollectionsMicroButton', 'UI-HUD-MicroMenu-Collections-Up' },
	{ 'EJMicroButton', 'UI-HUD-MicroMenu-AdventureGuide-Up' },
	{ 'StoreMicroButton', 'UI-HUD-MicroMenu-Shop-Up' },
	{ 'MainMenuMicroButton', 'UI-HUD-MicroMenu-GameMenu-Up' },
}

-- The atlas pictures are 64x82 buttons with the symbol in the middle. The picture is loaded from
-- its file with the coordinates of the file, and a square around the symbol is cut out of it.
-- (Texture coordinates set after SetAtlas would count inside the atlas piece instead.)
local function MicroIcon(tex, atlas)
	local info = C_Texture.GetAtlasInfo(atlas)
	local file = info and (info.file or info.filename)
	if not file then
		tex:SetAtlas(atlas)
		return
	end
	local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	local w, h = r - l, b - t
	local side = 0.1
	-- The same pixel width cut from the height gives a square.
	local keep = (1 - 2 * side) * (info.width or 64) / (info.height or 82)
	local top = (1 - keep) / 2
	tex:SetTexture(file)
	tex:SetTexCoord(l + w * side, r - w * side, t + h * top, b - h * top)
end

local function HasAlert(real)
	local flash = real.FlashBorder
	local note = real.NotificationOverlay
	return (flash and flash:IsShown()) or (note and note:IsShown()) or false
end

local function BuildMicro()
	micro = CreateFrame('Frame', nil, bar)
	micro:SetHeight(cfg.h)
	micro:SetPoint('LEFT', bar, 'LEFT', 0, 0)
	local size, gap = cfg.iconSize, 4
	local x = 6
	for _, entry in ipairs(MICRO) do
		local real = _G[entry[1]]
		if real then
			local b = CreateFrame('Button', nil, micro, 'SecureActionButtonTemplate')
			b:SetSize(size, size)
			b:SetPoint('LEFT', micro, 'LEFT', x, 0)
			b:RegisterForClicks('AnyUp')
			b:SetAttribute('useOnKeyDown', false) -- acts on the release it is registered for
			b:SetAttribute('type', 'click')
			b:SetAttribute('clickbutton', real)
			local bg = b:CreateTexture(nil, 'BACKGROUND')
			bg:SetAllPoints()
			bg:SetColorTexture(0.137, 0.145, 0.169, 1)
			ns.Outline(b)
			local icon = b:CreateTexture(nil, 'ARTWORK')
			icon:SetPoint('TOPLEFT', 1, -1)
			icon:SetPoint('BOTTOMRIGHT', -1, 1)
			if entry[2] then
				MicroIcon(icon, entry[2])
			else
				-- The character button shows your portrait, like Blizzard's.
				SetPortraitTexture(icon, 'player')
				icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
				b:RegisterEvent('UNIT_PORTRAIT_UPDATE')
				b:RegisterEvent('PLAYER_ENTERING_WORLD')
				b:SetScript('OnEvent', function() SetPortraitTexture(icon, 'player') end)
			end
			local hl = b:CreateTexture(nil, 'HIGHLIGHT')
			hl:SetAllPoints()
			hl:SetColorTexture(1, 1, 1, 0.15)
			-- A gold dot where the Blizzard button would glow: unspent talents, new mail in the guild, ...
			local dot = b:CreateTexture(nil, 'OVERLAY')
			dot:SetSize(6, 6)
			dot:SetPoint('TOPRIGHT', -1, -1)
			dot:SetColorTexture(0.95, 0.72, 0.29, 1)
			local function Alert() dot:SetShown(HasAlert(real)) end
			for _, part in ipairs({ real.FlashBorder, real.NotificationOverlay }) do
				if part then
					hooksecurefunc(part, 'Show', Alert)
					hooksecurefunc(part, 'Hide', Alert)
					if part.SetShown then hooksecurefunc(part, 'SetShown', Alert) end
				end
			end
			Alert()
			b:SetScript('OnEnter', function(self)
				Tooltip(self)
				GameTooltip:SetText(real.tooltipText or entry[1]:gsub('MicroButton', ''), 1, 1, 1)
				if real.newbieText then GameTooltip:AddLine(real.newbieText, nil, nil, nil, true) end
				GameTooltip:Show()
			end)
			b:SetScript('OnLeave', GameTooltip_Hide)
			-- The real button stays where Blizzard keeps it, unseen and not in the way of the mouse.
			real:SetAlpha(0)
			real:EnableMouse(false)
			x = x + size + gap
		end
	end
	micro:SetWidth(x + 2)
	if MicroMenu then MicroMenu:SetAlpha(0) end
	local line = micro:CreateTexture(nil, 'ARTWORK')
	line:SetColorTexture(0, 0, 0, 1)
	line:SetWidth(ns.Px())
	line:SetPoint('TOPRIGHT')
	line:SetPoint('BOTTOMRIGHT')
end

------------------------------------------------------------------------
-- Values
------------------------------------------------------------------------
local DURABILITY_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17 }

local function UpdateDurability()
	if not seg.durability then return end
	local low
	for _, slot in ipairs(DURABILITY_SLOTS) do
		local cur, max = GetInventoryItemDurability(slot)
		if cur and max and max > 0 then low = math.min(low or 1, cur / max) end
	end
	if not low then
		SetText(seg.durability, Label('Durability') .. '-')
		return
	end
	local pct = math.floor(low * 100 + 0.5)
	local color = pct > 50 and 'ff3fd16a' or (pct > 25 and 'fff2c94a' or 'ffe5484d')
	SetText(seg.durability, Label('Durability') .. Colored(color, pct .. '%'))
end

local function DurabilityTooltip(self)
	Tooltip(self)
	GameTooltip:AddLine('Durability')
	for _, slot in ipairs(DURABILITY_SLOTS) do
		local cur, max = GetInventoryItemDurability(slot)
		local link = GetInventoryItemLink('player', slot)
		if cur and max and max > 0 and link then
			local pct = math.floor(cur / max * 100 + 0.5)
			local r = pct > 50 and 0.25 or 0.9
			local g = pct > 25 and 0.82 or 0.28
			GameTooltip:AddDoubleLine(link, pct .. '%', nil, nil, nil, r, g, 0.3)
		end
	end
	GameTooltip:AddLine('Click: character', 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function UpdatePerformance()
	if seg.fps then SetText(seg.fps, Label('FPS') .. math.floor(GetFramerate() + 0.5)) end
	if seg.latency then
		local _, _, home, world = GetNetStats()
		SetText(seg.latency, Label('ms') .. (world or 0))
	end
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	local s = seconds % 60
	if h > 0 then return ('%d:%02d:%02d'):format(h, m, s) end
	return ('%d:%02d'):format(m, s)
end

local LFG_CATEGORIES = { 'LE_LFG_CATEGORY_LFD', 'LE_LFG_CATEGORY_RF', 'LE_LFG_CATEGORY_SCENARIO', 'LE_LFG_CATEGORY_FLEXRAID', 'LE_LFG_CATEGORY_WORLDPVP' }

-- What you are queued for: the longest wait wins the bar, the tooltip lists everything.
local function Queues()
	local list = {}
	for _, key in ipairs(LFG_CATEGORIES) do
		local category = _G[key]
		if category and GetLFGMode(category) == 'queued' then
			local _, _, tank, healer, dps, _, _, _, _, _, name, average, _, _, _, myWait, queuedTime = GetLFGQueueStats(category)
			if queuedTime then
				table.insert(list, { name = name, waited = GetTime() - queuedTime, average = (myWait and myWait > 0) and myWait or average,
					tank = tank, healer = healer, dps = dps })
			end
		end
	end
	if GetMaxBattlefieldID then
		for i = 1, GetMaxBattlefieldID() do
			local status, name = GetBattlefieldStatus(i)
			if status == 'queued' then
				table.insert(list, { name = name, waited = (GetBattlefieldTimeWaited(i) or 0) / 1000, average = (GetBattlefieldEstimatedWaitTime(i) or 0) / 1000 })
			end
		end
	end
	local applied = 0
	if C_LFGList and C_LFGList.GetApplications then
		for _, id in ipairs(C_LFGList.GetApplications() or {}) do
			local _, status = C_LFGList.GetApplicationInfo(id)
			if status == 'applied' then applied = applied + 1 end
		end
	end
	return list, applied
end

local function UpdateQueue()
	local s = seg.queue
	if not s then return end
	local list, applied = Queues()
	local longest
	for _, q in ipairs(list) do
		if not longest or q.waited > longest.waited then longest = q end
	end
	if longest then
		local avg = longest.average and longest.average > 0 and (' ' .. Colored(MUTED, '/ ~' .. Clock(longest.average))) or ''
		SetText(s, Label('Queue') .. Clock(longest.waited) .. avg)
	elseif applied > 0 then
		SetText(s, Label('Applied') .. applied)
	else
		Hide(s)
	end
end

local function QueueTooltip(self)
	Tooltip(self)
	local list, applied = Queues()
	for _, q in ipairs(list) do
		GameTooltip:AddDoubleLine(q.name or 'Queue', Clock(q.waited), 1, 1, 1, 1, 1, 1)
		if q.average and q.average > 0 then GameTooltip:AddDoubleLine('Average wait', Clock(q.average), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6) end
		local need = {}
		if q.tank and q.tank > 0 then table.insert(need, q.tank .. ' tank') end
		if q.healer and q.healer > 0 then table.insert(need, q.healer .. ' healer') end
		if q.dps and q.dps > 0 then table.insert(need, q.dps .. ' DPS') end
		if #need > 0 then GameTooltip:AddLine('Still needed: ' .. table.concat(need, ', '), 0.95, 0.72, 0.29) end
	end
	if applied > 0 then GameTooltip:AddLine('Premade applications: ' .. applied, 1, 1, 1) end
	GameTooltip:AddLine('Click: the queue menu', 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

-- The queue eye of Blizzard stays the source of truth: unseen, under the queue segment, so its
-- menu and status window open from our segment.
local function AdoptQueueEye()
	local eye = QueueStatusButton
	if not eye then return end
	local function Place()
		eye:ClearAllPoints()
		eye:SetPoint('TOP', seg.queue, 'BOTTOM', 0, -2)
		eye:SetAlpha(0)
		eye:EnableMouse(false)
	end
	Place()
	if eye.UpdatePosition then hooksecurefunc(eye, 'UpdatePosition', Place) end
end

local function UpdateCurrencies()
	if not show.currency or not (C_CurrencyInfo and C_CurrencyInfo.GetBackpackCurrencyInfo) then return end
	local n = 0
	for i = 1, 10 do
		local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
		if not info then break end
		n = i
		local s = currencySegs[i]
		s.currencyID = info.currencyTypesID
		SetText(s, ('|T%d:16:16:0:0:64:64:5:59:5:59|t %s'):format(info.iconFileID, BreakUpLargeNumbers(info.quantity)))
	end
	for i = n + 1, #currencySegs do Hide(currencySegs[i]) end
end

local function UpdateClock()
	if not seg.clock then return end
	local text = GameTime_GetTime(false)
	if C_Calendar and C_Calendar.GetNumPendingInvites and C_Calendar.GetNumPendingInvites() > 0 then
		text = Colored(GOLD, text)
	end
	SetText(seg.clock, text)
end

local function ClockTooltip(self)
	Tooltip(self)
	local hour, minute = GetGameTime()
	GameTooltip:AddDoubleLine('Local time', date('%H:%M'), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine('Realm time', ('%02d:%02d'):format(hour, minute), 1, 1, 1, 1, 1, 1)
	if C_Calendar and C_Calendar.GetNumPendingInvites and C_Calendar.GetNumPendingInvites() > 0 then
		GameTooltip:AddLine('Calendar invites waiting', 0.95, 0.72, 0.29)
	end
	GameTooltip:AddLine('Click: calendar, right click: stopwatch and alarm', 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

-- The gold is kept under the character's GUID, so a renamed character keeps one entry and is not
-- counted twice. The name and realm are kept beside it for the tooltip. Older entries under
-- 'realm|name' stay in the list until that character logs in again.
local function CharKey()
	local guid = UnitGUID('player')
	if guid and not issecretvalue(guid) then return guid end
	return (GetRealmName() or '?') .. '|' .. (UnitName('player') or '?')
end

-- This character's entry. Since 3.0 the Alts element (31) keeps its data in the same entry, so the
-- fields are written one by one and neither writer drops the other's.
local function CharEntry()
	if not ns.DB then return end
	ns.DB.gold = ns.DB.gold or {}
	local store = ns.DB.gold
	local name, realm = UnitName('player'), GetRealmName()
	local key = CharKey()
	local old = (realm or '?') .. '|' .. (name or '?')
	if old ~= key then store[old] = nil end
	local entry = store[key] or {}
	store[key] = entry
	entry.class, entry.name, entry.realm = select(2, UnitClass('player')), name, realm
	return entry
end
ns.CharEntry = CharEntry

local function UpdateGold()
	if not seg.gold then return end
	local money = GetMoney()
	sessionMoney = sessionMoney or money
	local entry = CharEntry()
	if entry then entry.money = money end
	local text = Colored(GOLD, BreakUpLargeNumbers(math.floor(money / 10000)) .. 'g')
	local delta = math.floor((money - sessionMoney) / 10000)
	if delta ~= 0 then
		text = text .. ' ' .. Colored(delta > 0 and 'ff3fd16a' or 'ffe5484d', (delta > 0 and '+' or '') .. BreakUpLargeNumbers(delta))
	end
	SetText(seg.gold, text)
end

local function GoldTooltip(self)
	Tooltip(self)
	GameTooltip:AddLine('Gold')
	local realm = GetRealmName()
	local total, list = 0, {}
	for key, data in pairs(ns.DB and ns.DB.gold or {}) do
		local r, name = data.realm, data.name
		if not r then r, name = key:match('^(.-)|(.+)$') end
		if r == realm and name then
			table.insert(list, { name = name, money = data.money, class = data.class })
			total = total + data.money
		end
	end
	table.sort(list, function(a, b) return a.money > b.money end)
	for _, c in ipairs(list) do
		local color = RAID_CLASS_COLORS[c.class] or NORMAL_FONT_COLOR
		GameTooltip:AddDoubleLine(c.name, GetMoneyString(c.money, true), color.r, color.g, color.b, 1, 1, 1)
	end
	GameTooltip:AddDoubleLine('Total', GetMoneyString(total, true), 0.95, 0.72, 0.29, 1, 1, 1)
	local delta = GetMoney() - (sessionMoney or GetMoney())
	if delta ~= 0 then
		GameTooltip:AddDoubleLine('This session', (delta < 0 and '-' or '+') .. GetMoneyString(math.abs(delta), true), 0.6, 0.6, 0.6, 1, 1, 1)
	end
	GameTooltip:AddLine('Click: bags', 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function UpdateItemLevel()
	if not seg.itemLevel then return end
	local _, equipped = GetAverageItemLevel()
	SetText(seg.itemLevel, Label('ilvl') .. math.floor((equipped or 0) + 0.0001))
end

local function UpdateKeystone()
	local s = seg.keystone
	if not s then return end
	local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local level = C_MythicPlus.GetOwnedKeystoneLevel()
	if mapID and mapID > 0 and level and level > 0 then
		local name = C_ChallengeMode.GetMapUIInfo(mapID)
		SetText(s, Label('Key') .. (name or '?') .. ' +' .. level)
	else
		SetText(s, Label('Key') .. Colored(MUTED, 'none'))
	end
end

local function KeystoneTooltip(self)
	-- While the teleport list is open the tooltip would only cover it.
	if ns.TeleportsShown and ns.TeleportsShown() then return end
	Tooltip(self)
	-- 3.0 (8, 10): your keystone as the title, then the season table, this week's affixes and the
	-- party's keys from Keystone.lua.
	local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local level = C_MythicPlus.GetOwnedKeystoneLevel()
	local name = mapID and mapID > 0 and level and level > 0 and C_ChallengeMode.GetMapUIInfo(mapID)
	GameTooltip:AddLine(name and (name .. ' +' .. level) or 'Mythic+ keystone')
	if ns.AddKeystoneTooltip then ns.AddKeystoneTooltip(GameTooltip, self) end
	if ns.HasTeleports and ns.HasTeleports() then
		GameTooltip:AddLine('Click: teleport to a dungeon of the season', 0.6, 0.6, 0.6)
	else
		GameTooltip:AddLine('A dungeon teleport is learned by timing a +10 there.', 0.6, 0.6, 0.6, true)
	end
	GameTooltip:Show()
end

local VAULT_ROWS = { { 'Raid', 'Raid' }, { 'Activities', 'Dungeons' }, { 'World', 'World' } }

local function VaultCounts()
	local counts = {}
	for i, row in ipairs(VAULT_ROWS) do
		local done = 0
		local kind = Enum.WeeklyRewardChestThresholdType[row[1]]
		for _, activity in ipairs(kind and C_WeeklyRewards.GetActivities(kind) or {}) do
			if activity.progress >= activity.threshold then done = done + 1 end
		end
		counts[i] = done
	end
	return counts
end

ns.VaultCounts = VaultCounts

-- 3.0 (32): this week at the bottom of the Great Vault tooltip: the time to the weekly reset, the
-- Mythic+ runs of the week, the reward level of each unlocked vault slot and the lockouts.
local LABEL_RGB = { 0.62, 0.6, 0.56 }

local function DaysHours(seconds)
	local d = math.floor(seconds / 86400)
	local h = math.floor(seconds % 86400 / 3600)
	local m = math.floor(seconds % 3600 / 60)
	if d > 0 then return ('%dd %dh'):format(d, h) end
	if h > 0 then return ('%dh %dm'):format(h, m) end
	return ('%dm'):format(m)
end

-- "Hero 1" from the example reward of a slot, or its item level when the item has no track.
local function RewardText(activity)
	if not C_WeeklyRewards.GetExampleRewardItemHyperlinks then return end
	local link = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
	if not Readable(link) or not link then return end
	local up = ns.UpgradeTrack and ns.UpgradeTrack(link)
	if up then return up.track .. ' ' .. up.rank end
	local level = C_Item.GetDetailedItemLevelInfo(link)
	return level and tostring(level)
end

local function Line(label, value)
	GameTooltip:AddDoubleLine(label, value, LABEL_RGB[1], LABEL_RGB[2], LABEL_RGB[3], 1, 1, 1)
end

local function VaultWeekLines()
	GameTooltip:AddLine(' ')
	GameTooltip:AddLine('This week', 0.95, 0.72, 0.29)
	local reset = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
	if Readable(reset) and reset then Line('Reset in', DaysHours(reset)) end

	local runs = C_MythicPlus and C_MythicPlus.GetRunHistory and C_MythicPlus.GetRunHistory(false, true) or {}
	local levels = {}
	for _, run in ipairs(runs) do
		if Readable(run.level) and run.level then table.insert(levels, run.level) end
	end
	table.sort(levels, function(a, b) return a > b end)
	local shown = {}
	for i = 1, math.min(#levels, 8) do shown[i] = '+' .. levels[i] end
	if #levels > 8 then table.insert(shown, 'and ' .. (#levels - 8) .. ' more') end
	Line('Runs', #shown > 0 and table.concat(shown, ' ') or 'none')

	local rewards = {}
	for _, row in ipairs(VAULT_ROWS) do
		local kind = Enum.WeeklyRewardChestThresholdType[row[1]]
		for _, activity in ipairs(kind and C_WeeklyRewards.GetActivities(kind) or {}) do
			if activity.progress >= activity.threshold then
				table.insert(rewards, RewardText(activity) or '?')
			end
		end
	end
	Line('Vault rewards', #rewards > 0 and table.concat(rewards, ' · ') or 'none')

	if GetNumSavedInstances and GetSavedInstanceInfo then
		for i = 1, GetNumSavedInstances() do
			local name, _, _, _, locked, extended, _, _, _, difficulty, encounters, killed = GetSavedInstanceInfo(i)
			if name and (locked or extended) and encounters and encounters > 0 then
				Line(name, ('%s %d/%d'):format(difficulty or '', killed or 0, encounters))
			end
		end
	end
end

local function UpdateVault()
	local s = seg.vault
	if not s then return end
	if C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() then
		SetText(s, Label('Vault') .. Colored(GOLD, 'ready'))
		return
	end
	local c = VaultCounts()
	SetText(s, Label('Vault') .. table.concat(c, ' · '))
end

local function VaultTooltip(self)
	Tooltip(self)
	GameTooltip:AddLine('Great Vault')
	local c = VaultCounts()
	for i, row in ipairs(VAULT_ROWS) do
		GameTooltip:AddDoubleLine(row[2], c[i] .. ' / 3', 1, 1, 1, 1, 1, 1)
	end
	if cfg.vaultWeek then VaultWeekLines() end
	GameTooltip:AddLine('Click: open the vault', 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function OpenVault()
	if not WeeklyRewardsFrame then C_AddOns.LoadAddOn('Blizzard_WeeklyRewards') end
	if not WeeklyRewardsFrame then return end
	if WeeklyRewardsFrame:IsShown() then
		HideUIPanel(WeeklyRewardsFrame)
	else
		ShowUIPanel(WeeklyRewardsFrame)
	end
end

local function UpdateAuto()
	local s = seg.autoQuest
	if not s then return end
	local on = ns.AutoQuestOn and ns.AutoQuestOn()
	SetText(s, Label('Auto quest') .. (on and Colored(GOLD, 'ON') or Colored(MUTED, 'OFF')))
end
ns.UpdateAutoQuestSegment = UpdateAuto

------------------------------------------------------------------------
-- 3.0 (52): the quiet mode switch. Quiet mode itself lives in its own module (ns.Quiet), which
-- calls ns.UpdateQuietSegment after every change.
------------------------------------------------------------------------
local function UpdateQuiet()
	local s = seg.quiet
	if not s or not ns.Quiet then return end
	SetText(s, Label('Quiet') .. (ns.Quiet.IsOn() and Colored(GOLD, 'ON') or Colored(MUTED, 'OFF')))
end
ns.UpdateQuietSegment = UpdateQuiet

local function QuietTooltip(self)
	Tooltip(self)
	GameTooltip:AddLine('Quiet mode')
	GameTooltip:AddLine('What it mutes and hides is set in /slimark.', 1, 1, 1, true)
	GameTooltip:AddLine('Click: switch on or off', 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

------------------------------------------------------------------------
-- 3.0 (29): spec and loadout. The menus and the changes are in Talents.lua.
------------------------------------------------------------------------
local function UpdateSpec()
	local s = seg.spec
	if not s then return end
	local text = ns.Talents and ns.Talents.BarText()
	if text then SetText(s, text) else Hide(s) end
end
ns.UpdateSpecSegment = UpdateSpec

------------------------------------------------------------------------
-- 3.0 (36): friends and guild members online, "F 4 · G 12", the names in the tooltip.
------------------------------------------------------------------------
local friendsQueued
local lastRoster = 0
local MAX_NAMES = 25

local function ClassToken(localized)
	if not Readable(localized) or not localized then return end
	for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
		for token, name in pairs(names) do
			if name == localized then return token end
		end
	end
end

local function ClassRGB(token)
	local c = token and RAID_CLASS_COLORS[token]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function GuildOnline()
	if not (IsInGuild and IsInGuild() and GetNumGuildMembers) then return end
	local _, online = GetNumGuildMembers()
	if not Readable(online) then return end
	-- Without you.
	return math.max(0, (online or 0) - 1)
end

local function FriendsOnline()
	local n = 0
	if C_FriendList and C_FriendList.GetNumOnlineFriends then
		local wow = C_FriendList.GetNumOnlineFriends()
		if Readable(wow) then n = n + (wow or 0) end
	end
	if BNGetNumFriends then
		local _, bnet = BNGetNumFriends()
		if Readable(bnet) then n = n + (bnet or 0) end
	end
	return n
end

local function UpdateFriends()
	friendsQueued = false
	local s = seg.friends
	if not s then return end
	local text = Label('F') .. FriendsOnline()
	local guild = GuildOnline()
	if guild then text = text .. Colored(MUTED, ' · ') .. Label('G') .. guild end
	SetText(s, text)
end

local function QueueFriends()
	if friendsQueued then return end
	friendsQueued = true
	C_Timer.After(1, UpdateFriends)
end

-- The guild list is asked from the server at most every 15 seconds; its answer updates the segment.
local function RequestRoster()
	if not (IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster) then return end
	if GetTime() - lastRoster < 15 then return end
	lastRoster = GetTime()
	C_GuildInfo.GuildRoster()
end

-- A list length to loop over; 0 when the game keeps it secret.
local function Count(n)
	return Readable(n) and n or 0
end

local function AddName(count, left, right, r, g, b)
	if count > MAX_NAMES then return end
	GameTooltip:AddDoubleLine(left, right or '', r, g, b, 0.6, 0.6, 0.6)
end

local function FriendsTooltip(self)
	Tooltip(self)
	RequestRoster()
	GameTooltip:AddLine('Friends online')
	local count = 0
	if C_FriendList and C_FriendList.GetNumFriends then
		for i = 1, Count(C_FriendList.GetNumFriends()) do
			local info = C_FriendList.GetFriendInfoByIndex(i)
			if info and Readable(info.connected) and info.connected and Readable(info.name) and info.name then
				count = count + 1
				local r, g, b = ClassRGB(ClassToken(info.className))
				AddName(count, info.name, Readable(info.area) and info.area or nil, r, g, b)
			end
		end
	end
	if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
		for i = 1, Count((BNGetNumFriends())) do
			local account = C_BattleNet.GetFriendAccountInfo(i)
			local game = account and account.gameAccountInfo
			if game and Readable(game.isOnline) and game.isOnline and Readable(account.accountName) then
				count = count + 1
				local right
				if Readable(game.clientProgram) and game.clientProgram == BNET_CLIENT_WOW and Readable(game.characterName) and game.characterName then
					right = game.characterName
				end
				AddName(count, account.accountName, right, 0.51, 0.77, 1)
			end
		end
	end
	if count == 0 then GameTooltip:AddLine('none', 0.6, 0.6, 0.6) end
	if count > MAX_NAMES then GameTooltip:AddLine(('and %d more'):format(count - MAX_NAMES), 0.6, 0.6, 0.6) end

	if IsInGuild and IsInGuild() and GetGuildRosterInfo then
		GameTooltip:AddLine(' ')
		GameTooltip:AddLine('Guild online')
		local me = UnitName('player')
		local shown = 0
		for i = 1, Count((GetNumGuildMembers())) do
			local name, _, _, _, _, zone, _, _, online, _, class = GetGuildRosterInfo(i)
			if Readable(online) and online and Readable(name) and name then
				local short = Ambiguate and Ambiguate(name, 'guild') or name
				if short ~= me then
					shown = shown + 1
					local r, g, b = ClassRGB(class)
					AddName(shown, short, Readable(zone) and zone or nil, r, g, b)
				end
			end
		end
		if shown == 0 then GameTooltip:AddLine('none', 0.6, 0.6, 0.6) end
		if shown > MAX_NAMES then GameTooltip:AddLine(('and %d more'):format(shown - MAX_NAMES), 0.6, 0.6, 0.6) end
	end
	GameTooltip:AddLine('Click: friends, right click: guild', 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

------------------------------------------------------------------------
-- 3.0 (35): XP or reputation as a 3 px line on the bottom edge of the bar. No XP at the level cap,
-- no reputation without a watched faction, nothing without either. With both the line shows the
-- reputation and the tooltip the XP too.
------------------------------------------------------------------------
local xpLine
local XP_RGB = { 0.54, 0.31, 0.85 }
local REP_RGB = { 0.18, 0.64, 0.42 }

local function XPInfo()
	local show
	if GameRulesUtil and GameRulesUtil.CanShowExperienceBar then
		show = GameRulesUtil.CanShowExperienceBar()
	else
		local cap = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or (GetMaxPlayerLevel and GetMaxPlayerLevel())
		show = not cap or UnitLevel('player') < cap
	end
	if not show then return end
	local value, max = UnitXP('player'), UnitXPMax('player')
	if not (Readable(value) and Readable(max)) or not max or max <= 0 then return end
	return { value = value, max = max, level = UnitLevel('player'), rested = GetXPExhaustion and GetXPExhaustion() }
end

local function RepInfo()
	local R = C_Reputation
	local watched = R and R.GetWatchedFactionData and R.GetWatchedFactionData()
	if not watched or not watched.factionID or watched.factionID == 0 or not watched.name or watched.name == '' then return end
	local id = watched.factionID
	local low, high, value = watched.currentReactionThreshold or 0, watched.nextReactionThreshold or 0, watched.currentStanding or 0
	local standing = _G['FACTION_STANDING_LABEL' .. (watched.reaction or 0)]
	if R.IsFactionParagonForCurrentPlayer and R.IsFactionParagonForCurrentPlayer(id) then
		local current, threshold = R.GetFactionParagonInfo(id)
		if current and threshold and threshold > 0 then low, high, value = 0, threshold, current % threshold end
		standing = 'Paragon'
	elseif R.IsMajorFaction and R.IsMajorFaction(id) and C_MajorFactions then
		local data = C_MajorFactions.GetMajorFactionData(id)
		if data then
			low, high, value = 0, data.renownLevelThreshold or 0, data.renownReputationEarned or 0
			-- At the last renown level the line is full.
			if data.maxLevel and data.renownLevel and data.renownLevel >= data.maxLevel then high, value = 1, 1 end
			standing = 'Renown ' .. (data.renownLevel or 0)
		end
	elseif C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
		local friend = C_GossipInfo.GetFriendshipReputation(id)
		if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
			standing = friend.reaction
			if friend.nextThreshold then
				low, high, value = friend.reactionThreshold or 0, friend.nextThreshold, friend.standing or 0
			else
				low, high, value = 0, 1, 1
			end
		end
	end
	local max = high - low
	if max <= 0 then max, value, low = 1, 1, 0 end
	return { name = watched.name, value = value - low, max = max, standing = standing }
end

local function UpdateXP()
	if not xpLine then return end
	local rep, xp = RepInfo(), XPInfo()
	local data = rep or xp
	if not data then
		xpLine:Hide()
		return
	end
	local color = rep and REP_RGB or XP_RGB
	xpLine.bar:SetStatusBarColor(color[1], color[2], color[3])
	xpLine.bar:SetMinMaxValues(0, data.max)
	xpLine.bar:SetValue(data.value)
	xpLine:Show()
end

local function Percent(value, max)
	return math.floor(value / max * 100 + 0.5) .. '%'
end

local function XPTooltip(self)
	Tooltip(self)
	local rep, xp = RepInfo(), XPInfo()
	if rep then
		GameTooltip:AddLine(rep.name)
		GameTooltip:AddDoubleLine(rep.standing or 'Reputation', ('%s / %s (%s)'):format(BreakUpLargeNumbers(rep.value),
			BreakUpLargeNumbers(rep.max), Percent(rep.value, rep.max)), LABEL_RGB[1], LABEL_RGB[2], LABEL_RGB[3], 1, 1, 1)
	end
	if xp then
		if rep then GameTooltip:AddLine(' ') end
		GameTooltip:AddLine('Level ' .. xp.level)
		GameTooltip:AddDoubleLine('XP', ('%s / %s (%s)'):format(BreakUpLargeNumbers(xp.value), BreakUpLargeNumbers(xp.max),
			Percent(xp.value, xp.max)), LABEL_RGB[1], LABEL_RGB[2], LABEL_RGB[3], 1, 1, 1)
		if Readable(xp.rested) and xp.rested and xp.rested > 0 then
			GameTooltip:AddDoubleLine('Rested', BreakUpLargeNumbers(xp.rested), LABEL_RGB[1], LABEL_RGB[2], LABEL_RGB[3], 0.4, 0.6, 1)
		end
	end
	GameTooltip:Show()
end

local function BuildXPLine()
	xpLine = CreateFrame('Frame', nil, bar)
	xpLine:SetPoint('BOTTOMLEFT')
	xpLine:SetPoint('BOTTOMRIGHT')
	xpLine:SetHeight(3)
	xpLine:SetFrameLevel(bar:GetFrameLevel() + 10)
	local track = xpLine:CreateTexture(nil, 'BACKGROUND')
	track:SetAllPoints()
	track:SetColorTexture(0.082, 0.086, 0.102, 1)
	xpLine.bar = CreateFrame('StatusBar', nil, xpLine)
	xpLine.bar:SetAllPoints()
	xpLine.bar:SetStatusBarTexture(ns.TEX)
	xpLine:EnableMouse(true)
	xpLine:SetScript('OnEnter', XPTooltip)
	xpLine:SetScript('OnLeave', GameTooltip_Hide)
	xpLine:Hide()
end

------------------------------------------------------------------------
-- 3.0 (36): the addon CPU in the FPS tooltip, read only while the tooltip opens. The share is the
-- one the game's addon list shows: the addon's recent time against the whole frame.
------------------------------------------------------------------------
local function AddonCPU()
	local P = C_AddOnProfiler
	local metrics = Enum.AddOnProfilerMetric
	if not (P and metrics and P.IsEnabled and P.IsEnabled() and P.GetTopKAddOnsForMetric) then return end
	local metric = metrics.RecentAverageTime
	local app, all = P.GetApplicationMetric(metric), P.GetOverallMetric(metric)
	if not (Readable(app) and Readable(all)) then return end
	local top = P.GetTopKAddOnsForMetric(metric, 5) or {}
	if #top == 0 then return end
	GameTooltip:AddLine(' ')
	GameTooltip:AddLine('Addon CPU (recent)', 0.95, 0.72, 0.29)
	for _, result in ipairs(top) do
		local base = app - all + result.metricValue
		if base > 0 then
			GameTooltip:AddDoubleLine(result.addOnName, ('%.1f%%'):format(result.metricValue / base * 100), 1, 1, 1, 1, 1, 1)
		end
	end
end

local function PerformanceTooltip(self)
	Tooltip(self)
	GameTooltip:AddLine('Performance')
	GameTooltip:AddDoubleLine('FPS', tostring(math.floor(GetFramerate() + 0.5)), 1, 1, 1, 1, 1, 1)
	local _, _, home, world = GetNetStats()
	GameTooltip:AddDoubleLine('Home / World', ('%d / %d ms'):format(home or 0, world or 0), 1, 1, 1, 1, 1, 1)
	AddonCPU()
	GameTooltip:Show()
end

local function UpdateAll()
	UpdateDurability()
	UpdatePerformance()
	UpdateQueue()
	UpdateCurrencies()
	UpdateClock()
	UpdateGold()
	UpdateItemLevel()
	UpdateKeystone()
	UpdateVault()
	UpdateAuto()
	-- 3.0 (29, 35, 36, 52)
	UpdateSpec()
	UpdateFriends()
	UpdateXP()
	UpdateQuiet()
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
-- 3.0: the events of a new element are registered only when it is built.
local function Listen(events, fn)
	for _, event in ipairs(events) do ns.On(event, fn) end
end

local function Add(chain, name, rightSide, onEnter, onClick)
	local s = Segment(name, rightSide)
	if onEnter then s:SetScript('OnEnter', onEnter) end
	if onClick then s:SetScript('OnClick', onClick) end
	table.insert(chain, s)
	seg[name] = s
	return s
end

local function Build()
	bar = CreateFrame('Frame', 'SlimARK_DataBar', UIParent)
	bar:SetFrameStrata('MEDIUM')
	bar:SetFrameLevel(5)
	bar:SetScale(ns.Scale())
	bar:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 0, 0)
	bar:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', 0, 0)
	bar:SetHeight(cfg.h)
	local bg = bar:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.07, 0.075, 0.09, 0.92)
	local edge = bar:CreateTexture(nil, 'BORDER')
	edge:SetColorTexture(0, 0, 0, 1)
	edge:SetHeight(ns.Px())
	edge:SetPoint('BOTTOMLEFT')
	edge:SetPoint('BOTTOMRIGHT')

	if show.micro then BuildMicro() end

	if show.durability then Add(leftChain, 'durability', false, DurabilityTooltip, function() ToggleCharacter('PaperDollFrame') end) end
	-- 3.0 (36): the FPS tooltip with the addon CPU, only with its switch on.
	if show.fps then Add(leftChain, 'fps', false, cfg.addonCPU and PerformanceTooltip or nil) end
	if show.latency then
		Add(leftChain, 'latency', false, function(self)
			Tooltip(self)
			local _, _, home, world = GetNetStats()
			GameTooltip:AddDoubleLine('Home', home .. ' ms', 1, 1, 1, 1, 1, 1)
			GameTooltip:AddDoubleLine('World', world .. ' ms', 1, 1, 1, 1, 1, 1)
			GameTooltip:Show()
		end)
	end
	-- 3.0 (36, 29): friends and guild online, spec and loadout.
	if show.friends then
		Add(leftChain, 'friends', false, FriendsTooltip, function(_, button)
			if button == 'RightButton' then
				if ToggleGuildFrame then ToggleGuildFrame() end
			elseif ToggleFriendsFrame then
				ToggleFriendsFrame(1)
			end
		end)
		Listen({ 'FRIENDLIST_UPDATE', 'BN_FRIEND_ACCOUNT_ONLINE', 'BN_FRIEND_ACCOUNT_OFFLINE', 'BN_CONNECTED', 'BN_DISCONNECTED',
			'GUILD_ROSTER_UPDATE', 'PLAYER_GUILD_UPDATE' }, QueueFriends)
		RequestRoster()
	end
	if show.spec and ns.Talents then
		Add(leftChain, 'spec', false, function(self)
			Tooltip(self)
			ns.Talents.Tooltip()
		end, function(self, button) ns.Talents.Click(self, button) end)
		ns.Talents.Enable()
	end
	if show.queue then
		local q = Add(leftChain, 'queue', false, QueueTooltip, function(_, button)
			if QueueStatusButton then QueueStatusButton:Click(button) end
		end)
		q:RegisterForClicks('AnyUp')
		Hide(q)
	end
	if show.currency then
		for i = 1, 10 do
			local s = Segment('currency' .. i, false)
			s:SetScript('OnEnter', function(self)
				if not self.currencyID then return end
				Tooltip(self)
				GameTooltip:SetCurrencyByID(self.currencyID)
				GameTooltip:Show()
			end)
			s:SetScript('OnClick', function() ToggleCharacter('TokenFrame') end)
			table.insert(leftChain, s)
			currencySegs[i] = s
			Hide(s)
		end
	end

	if show.clock then
		local s = Segment('clock', false)
		s:SetPoint('CENTER', bar, 'CENTER', 0, 0)
		s:SetScript('OnEnter', ClockTooltip)
		s:RegisterForClicks('AnyUp')
		s:SetScript('OnClick', function(_, button)
			if button == 'RightButton' then
				if ToggleTimeManager then ToggleTimeManager() end
			else
				ToggleCalendar()
			end
		end)
		seg.clock = s
	end

	-- 3.0 (31): Alts, left of the gold. Its table is a frame of its own (Alts.lua).
	if show.alts and ns.Alts then
		local alts = Add(rightChain, 'alts', true, function(self) ns.Alts.Show(self) end)
		alts:SetScript('OnLeave', function() ns.Alts.Leave() end)
		SetText(alts, 'Alts')
		ns.Alts.Enable()
	end
	if show.gold then Add(rightChain, 'gold', true, GoldTooltip, function() ToggleAllBags() end) end
	if show.itemLevel then
		Add(rightChain, 'itemLevel', true, function(self)
			Tooltip(self)
			local overall, equipped = GetAverageItemLevel()
			GameTooltip:AddDoubleLine('Equipped item level', ('%.1f'):format(equipped or 0), 1, 1, 1, 1, 1, 1)
			GameTooltip:AddDoubleLine('Best in bags', ('%.1f'):format(overall or 0), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end, function() ToggleCharacter('PaperDollFrame') end)
	end
	if not ns.isForever and show.keystone and C_MythicPlus and C_ChallengeMode then
		local key
		key = Add(rightChain, 'keystone', true, KeystoneTooltip, function()
			if ns.ToggleTeleports then ns.ToggleTeleports(key, bar) end
		end)
	end
	if not ns.isForever and show.vault and C_WeeklyRewards then Add(rightChain, 'vault', true, VaultTooltip, OpenVault) end
	-- 3.0 (52): the quiet mode switch, only when the quiet mode module is there.
	if show.quiet and ns.Quiet then
		Add(rightChain, 'quiet', true, QuietTooltip, function(self)
			ns.Quiet.Toggle()
			UpdateQuiet()
			self:GetScript('OnEnter')(self)
		end)
	end
	if show.autoQuest and C.features.autoQuest then
		Add(rightChain, 'autoQuest', true, function(self)
			Tooltip(self)
			GameTooltip:AddLine('Auto quest')
			GameTooltip:AddLine('Accepts and turns in quests, picks the only talk option. Stops when you have to choose a reward.', 1, 1, 1, true)
			GameTooltip:AddLine('Hold Shift at an NPC to pause it there.', 0.6, 0.6, 0.6, true)
			GameTooltip:AddLine('Click: switch on or off', 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end, function(self)
			if ns.ToggleAutoQuest then ns.ToggleAutoQuest() end
			UpdateAuto()
			self:GetScript('OnEnter')(self)
		end)
	end

	if show.addons then
		local logos = CreateFrame('Frame', nil, bar)
		logos:SetHeight(cfg.h)
		logos:SetWidth(1)
		logos:SetPoint('RIGHT', bar, 'RIGHT', -6, 0)
		ns.barLogos = logos
		ns.OnLogosResized = function() end
	end

	Chain()
	if seg.queue then AdoptQueueEye() end

	-- 3.0 (35): the XP/reputation line, over the bottom edge of the bar.
	if show.xp then
		BuildXPLine()
		Listen({ 'PLAYER_XP_UPDATE', 'PLAYER_LEVEL_UP', 'UPDATE_EXHAUSTION', 'UPDATE_FACTION', 'MAJOR_FACTION_RENOWN_LEVEL_CHANGED',
			'ENABLE_XP_GAIN', 'DISABLE_XP_GAIN' }, UpdateXP)
	end
	-- 3.0 (32): the lockouts come from the server; asked once here, the answer waits for the tooltip.
	if seg.vault and cfg.vaultWeek and RequestRaidInfo then RequestRaidInfo() end
end

local function Rescale()
	if not bar then return end
	if InCombatLockdown() then
		ns.barRescalePending = true
		return
	end
	bar:SetScale(ns.Scale())
end

ns.On('PLAYER_LOGIN', function()
	if not C.modules.databar then return end
	Build()
	UpdateAll()
	-- FPS, latency, the clock and the queue time once a second: the only timer of the bar.
	C_Timer.NewTicker(1, function()
		UpdatePerformance()
		UpdateClock()
		UpdateQueue()
	end)
	if not ns.isForever and C_MythicPlus and C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
end)

local function On(events, fn)
	for _, event in ipairs(events) do
		ns.On(event, function(...)
			if bar then fn(...) end
		end)
	end
end

On({ 'PLAYER_ENTERING_WORLD' }, UpdateAll)
On({ 'UPDATE_INVENTORY_DURABILITY', 'PLAYER_EQUIPMENT_CHANGED' }, UpdateDurability)
On({ 'LFG_UPDATE', 'LFG_QUEUE_STATUS_UPDATE', 'UPDATE_BATTLEFIELD_STATUS', 'LFG_LIST_APPLICATION_STATUS_UPDATED' }, UpdateQueue)
On({ 'CURRENCY_DISPLAY_UPDATE' }, UpdateCurrencies)
On({ 'PLAYER_MONEY' }, UpdateGold)
On({ 'PLAYER_EQUIPMENT_CHANGED', 'PLAYER_AVG_ITEM_LEVEL_UPDATE' }, UpdateItemLevel)
On({ 'BAG_UPDATE_DELAYED', 'CHALLENGE_MODE_MAPS_UPDATE', 'CHALLENGE_MODE_COMPLETED', 'MYTHIC_PLUS_NEW_WEEKLY_RECORD' }, UpdateKeystone)
On({ 'WEEKLY_REWARDS_UPDATE', 'CHALLENGE_MODE_COMPLETED' }, UpdateVault)
On({ 'CALENDAR_UPDATE_PENDING_INVITES' }, UpdateClock)
On({ 'UI_SCALE_CHANGED', 'DISPLAY_SIZE_CHANGED' }, Rescale)
On({ 'PLAYER_REGEN_ENABLED' }, function()
	if ns.barRescalePending then
		ns.barRescalePending = nil
		Rescale()
	end
end)
