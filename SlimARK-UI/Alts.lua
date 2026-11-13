local _, ns = ...
local C = ns.C

-- 3.0 (31): the Alts element of the top bar. Every character keeps its item level, keystone, Great
-- Vault progress, Mythic+ score and crests beside its gold in ns.DB.gold (the gold element's store),
-- written at login and logout and when one of them changes. Hovering the element shows a table of
-- every character; hovering a name there lists that character's crests.
local A = {}
ns.Alts = A

local MUTED = { 0.6, 0.59, 0.55 }
local GOLD = { 0.95, 0.72, 0.29 }
local PAD, GAP, ROW_H, FONT = 10, 14, 18, 14
local WEEK = 7 * 24 * 3600

local enabled, queued
local tip, owner
local rows = {}

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

local function HasMythicPlus()
	return not ns.isForever and C_MythicPlus and C_ChallengeMode and true or false
end

------------------------------------------------------------------------
-- The store
------------------------------------------------------------------------
local function Crests()
	local list = {}
	if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return list end
	for _, id in ipairs(C.upgrade.crests) do
		local info = C_CurrencyInfo.GetCurrencyInfo(id)
		if info and Readable(info.quantity) then list[id] = info.quantity end
	end
	return list
end

local function KeyName(mapID)
	local name = C_ChallengeMode.GetMapUIInfo(mapID)
	if not name then return end
	-- "Ara-Kara, City of Echoes" is "Ara-Kara" in the narrow column.
	return name:match('^([^,]+),') or name
end

local function Save()
	queued = false
	local entry = ns.CharEntry and ns.CharEntry()
	if not entry then return end
	entry.money = GetMoney()
	-- During a loading screen the item level can read 0; the last real one stays then.
	local _, equipped = GetAverageItemLevel()
	if Readable(equipped) and equipped and equipped > 0 then entry.ilvl = equipped end
	if HasMythicPlus() then
		local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
		local level = C_MythicPlus.GetOwnedKeystoneLevel()
		if mapID and mapID > 0 and level and level > 0 then
			entry.keyName, entry.keyLevel = KeyName(mapID) or entry.keyName, level
		else
			entry.keyName, entry.keyLevel = nil, nil
		end
		local score = C_ChallengeMode.GetOverallDungeonScore and C_ChallengeMode.GetOverallDungeonScore()
		if Readable(score) and score then entry.score = score end
		if C_WeeklyRewards and ns.VaultCounts then
			local done = 0
			for _, n in ipairs(ns.VaultCounts()) do done = done + n end
			entry.vault = done
		end
	end
	entry.crests = Crests()
	entry.updated = GetServerTime()
end
A.Save = Save

-- Bursts of bag, currency and money events end in one write a second later.
local function Queue()
	if queued then return end
	queued = true
	C_Timer.After(1, Save)
end

------------------------------------------------------------------------
-- The tooltip: a table, one row per character
------------------------------------------------------------------------
-- The start of this week: keys and vault progress saved before it are gone.
local function WeekStart()
	local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
	if not Readable(left) or not left then return 0 end
	return GetServerTime() + left - WEEK
end

local function Columns()
	if HasMythicPlus() then
		return { { 'Name' }, { 'ilvl', true }, { 'Key' }, { 'Vault', true }, { 'Score', true }, { 'Gold', true } }
	end
	return { { 'Name' }, { 'ilvl', true }, { 'Gold', true } }
end

local function Gold(money)
	return BreakUpLargeNumbers(math.floor((money or 0) / 10000))
end

local function Characters()
	local list, total = {}, 0
	local realm = GetRealmName()
	local weekStart = WeekStart()
	for key, data in pairs(ns.DB and ns.DB.gold or {}) do
		local r, name = data.realm, data.name
		if not r then r, name = key:match('^(.-)|(.+)$') end
		if name then
			total = total + (data.money or 0)
			local fresh = (data.updated or 0) >= weekStart
			table.insert(list, { data = data, name = name, realm = r, other = r ~= realm, fresh = fresh })
		end
	end
	table.sort(list, function(a, b)
		local ia, ib = a.data.ilvl or 0, b.data.ilvl or 0
		if ia ~= ib then return ia > ib end
		return (a.data.money or 0) > (b.data.money or 0)
	end)
	return list, total
end

-- The cells of one character, in the order of Columns(): text and color.
local function Cells(c)
	local d = c.data
	local color = RAID_CLASS_COLORS[d.class] or NORMAL_FONT_COLOR
	local name = c.name
	if c.other and c.realm then name = name .. ' |cff9a968c- ' .. c.realm .. '|r' end
	local cells = { { name, { color.r, color.g, color.b } } }
	table.insert(cells, { d.ilvl and tostring(math.floor(d.ilvl + 0.0001)) or '-' })
	if HasMythicPlus() then
		local key = c.fresh and d.keyName and d.keyLevel and (d.keyName .. ' +' .. d.keyLevel) or '-'
		table.insert(cells, { key, key == '-' and MUTED or nil })
		local vault = c.fresh and d.vault and (d.vault .. '/9') or '-'
		table.insert(cells, { vault, vault == '-' and MUTED or nil })
		local score, scoreColor = '-', MUTED
		if d.score and d.score > 0 then
			score = tostring(math.floor(d.score))
			local rarity = C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(d.score)
			scoreColor = rarity and { rarity:GetRGB() } or nil
		end
		table.insert(cells, { score, scoreColor })
	end
	table.insert(cells, { Gold(d.money), GOLD })
	return cells
end

local function Hide()
	if tip then tip:Hide() end
	owner = nil
end

-- The table stays while the mouse is on the element or on the table itself.
local function MaybeHide()
	if not tip or not tip:IsShown() then return end
	if tip:IsMouseOver() or (owner and owner:IsMouseOver()) then return end
	GameTooltip:Hide()
	Hide()
end
A.Leave = MaybeHide

local function CrestTooltip(row)
	local c = row.char
	if not c then return end
	GameTooltip:SetOwner(row, 'ANCHOR_NONE')
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint('TOPLEFT', tip, 'TOPRIGHT', 4, 0)
	GameTooltip:AddLine(c.name .. ': crests')
	local crests = c.data.crests
	local any = false
	for _, id in ipairs(C.upgrade.crests) do
		local info = C_CurrencyInfo.GetCurrencyInfo(id)
		local amount = crests and crests[id]
		if info and info.name and amount then
			any = true
			local icon = info.iconFileID and ('|T' .. info.iconFileID .. ':14:14:0:0:64:64:5:59:5:59|t ') or ''
			GameTooltip:AddDoubleLine(icon .. info.name, BreakUpLargeNumbers(amount), 1, 1, 1, 1, 1, 1)
		end
	end
	if not any then GameTooltip:AddLine('Not saved yet: log in with this character once.', MUTED[1], MUTED[2], MUTED[3], true) end
	GameTooltip:Show()
end

local function Text(parent, justify, size)
	local fs = ns.Text(parent, size or FONT, justify)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	return fs
end

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame('Button', nil, tip)
	row:SetHeight(ROW_H)
	row.cells = {}
	local hl = row:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.05)
	row:SetScript('OnEnter', CrestTooltip)
	row:SetScript('OnLeave', function()
		GameTooltip:Hide()
		MaybeHide()
	end)
	rows[i] = row
	return row
end

local function Cell(row, i, justify)
	local fs = row.cells[i]
	if not fs then
		fs = Text(row, justify)
		row.cells[i] = fs
	end
	fs:SetJustifyH(justify)
	return fs
end

local function Build()
	tip = CreateFrame('Frame', 'SlimARK_AltsTooltip', UIParent)
	tip:SetFrameStrata('TOOLTIP')
	tip:SetClampedToScreen(true)
	tip:EnableMouse(true)
	tip:Hide()
	local bg = tip:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.055, 0.059, 0.075, 0.95)
	ns.Outline(tip)
	local stripe = tip:CreateTexture(nil, 'ARTWORK')
	stripe:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	stripe:SetPoint('TOPLEFT')
	stripe:SetPoint('TOPRIGHT')
	stripe:SetHeight(2)
	tip.title = Text(tip, 'LEFT', 15)
	tip.title:SetText('Alts')
	tip.heads = {}
	tip.totalLabel = Text(tip, 'LEFT')
	tip.totalLabel:SetText('Total gold')
	tip.totalLabel:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	tip.total = Text(tip, 'RIGHT')
	tip.total:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	tip.hint = Text(tip, 'LEFT', 12)
	tip.hint:SetText('Crests: hover a name')
	tip.hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	tip.when = Text(tip, 'RIGHT', 12)
	tip.when:SetText('Updated at each login')
	tip.when:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	tip:SetScript('OnLeave', MaybeHide)
end

local function Fill()
	local columns = Columns()
	local list, total = Characters()
	local widths = {}
	for i, col in ipairs(columns) do
		local head = tip.heads[i] or Text(tip, 'LEFT', 13)
		tip.heads[i] = head
		head:SetText(col[1])
		head:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		head:SetJustifyH(col[2] and 'RIGHT' or 'LEFT')
		head:Show()
		widths[i] = head:GetUnboundedStringWidth()
	end
	for i = #columns + 1, #tip.heads do tip.heads[i]:Hide() end

	for r, c in ipairs(list) do
		local row = Row(r)
		row.char = c
		for i, cell in ipairs(Cells(c)) do
			local fs = Cell(row, i, columns[i][2] and 'RIGHT' or 'LEFT')
			fs:SetText(cell[1])
			local color = cell[2] or { 1, 1, 1 }
			fs:SetTextColor(color[1], color[2], color[3])
			fs:Show()
			widths[i] = math.max(widths[i], fs:GetUnboundedStringWidth())
		end
		for i = #columns + 1, #row.cells do row.cells[i]:Hide() end
		row:Show()
	end
	for r = #list + 1, #rows do rows[r]:Hide() end

	-- Columns side by side, numbers right aligned in theirs.
	local x, xs = PAD, {}
	for i in ipairs(columns) do
		xs[i] = x
		x = x + math.ceil(widths[i]) + GAP
	end
	local width = math.max(x - GAP + PAD, 300)
	local y = -PAD
	tip.title:ClearAllPoints()
	tip.title:SetPoint('TOPLEFT', PAD, y)
	y = y - 22
	for i in ipairs(columns) do
		local head = tip.heads[i]
		head:ClearAllPoints()
		head:SetWidth(math.ceil(widths[i]))
		head:SetPoint('TOPLEFT', xs[i], y)
	end
	y = y - ROW_H
	for r in ipairs(list) do
		local row = rows[r]
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', 0, y)
		row:SetPoint('TOPRIGHT', 0, y)
		for i in ipairs(columns) do
			local fs = row.cells[i]
			fs:ClearAllPoints()
			fs:SetWidth(math.ceil(widths[i]))
			fs:SetPoint('LEFT', row, 'LEFT', xs[i], 0)
		end
		y = y - ROW_H
	end
	y = y - 6
	tip.totalLabel:ClearAllPoints()
	tip.totalLabel:SetPoint('TOPLEFT', PAD, y)
	tip.total:ClearAllPoints()
	tip.total:SetPoint('TOPRIGHT', -PAD, y)
	tip.total:SetText(Gold(total) .. 'g')
	y = y - ROW_H
	tip.hint:ClearAllPoints()
	tip.hint:SetPoint('TOPLEFT', PAD, y)
	tip.when:ClearAllPoints()
	tip.when:SetPoint('TOPRIGHT', -PAD, y)
	y = y - 16
	tip:SetSize(width, -y + PAD)
end

-- Right under the element, touching it, so the mouse can move onto a name.
function A.Show(segment)
	if not tip then Build() end
	owner = segment
	tip:SetScale(ns.Scale())
	Fill()
	tip:ClearAllPoints()
	tip:SetPoint('TOP', segment, 'BOTTOM', 0, 0)
	tip:Show()
end

------------------------------------------------------------------------
-- Switching on: only when the element is on the bar.
------------------------------------------------------------------------
function A.Enable()
	if enabled then return end
	enabled = true
	ns.On('PLAYER_ENTERING_WORLD', Queue)
	for _, event in ipairs({ 'PLAYER_MONEY', 'PLAYER_EQUIPMENT_CHANGED', 'PLAYER_AVG_ITEM_LEVEL_UPDATE', 'BAG_UPDATE_DELAYED',
		'CURRENCY_DISPLAY_UPDATE', 'CHALLENGE_MODE_COMPLETED', 'CHALLENGE_MODE_MAPS_UPDATE', 'WEEKLY_REWARDS_UPDATE' }) do
		ns.On(event, Queue)
	end
	ns.On('PLAYER_LOGOUT', Save)
end
