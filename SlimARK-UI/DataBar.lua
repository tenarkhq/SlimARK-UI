local _, ns = ...
local C = ns.C

-- The top bar: a flat strip on the top pixel row over the whole width. Left: the micro menu,
-- durability, FPS, latency, the queue and the tracked currencies. Middle: the clock. Right:
-- gold, item level, the keystone with the teleport list, the Great Vault, the auto quest
-- switch and the addon icons above the map.
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

local function UpdateGold()
	if not seg.gold then return end
	local money = GetMoney()
	sessionMoney = sessionMoney or money
	if ns.DB then
		ns.DB.gold = ns.DB.gold or {}
		local name, realm = UnitName('player'), GetRealmName()
		ns.DB.gold[(realm or '?') .. '|' .. (name or '?')] = nil
		ns.DB.gold[CharKey()] = { money = money, class = select(2, UnitClass('player')), name = name, realm = realm }
	end
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
	Tooltip(self)
	GameTooltip:AddLine('Mythic+ keystone')
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
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
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
	if show.fps then Add(leftChain, 'fps') end
	if show.latency then
		Add(leftChain, 'latency', false, function(self)
			Tooltip(self)
			local _, _, home, world = GetNetStats()
			GameTooltip:AddDoubleLine('Home', home .. ' ms', 1, 1, 1, 1, 1, 1)
			GameTooltip:AddDoubleLine('World', world .. ' ms', 1, 1, 1, 1, 1, 1)
			GameTooltip:Show()
		end)
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
