local _, ns = ...
local C = ns.C

-- The setup window of a new version (2.0), in place of the old Apply popup. Until a look is
-- chosen for Blizzard's windows it shows two cards, Original and SlimARK, neither selected,
-- and Apply now stays grey until one is picked. Later closes it; it comes back at the next
-- login. Once the look is chosen, later versions show the short form with the saved choice.
local W = 640
local GOLD = { 0.95, 0.72, 0.29 }
local TEXT = { 0.93, 0.91, 0.87 }
local SOFT = { 0.73, 0.71, 0.66 }
local MUTED = { 0.55, 0.54, 0.5 }
local PANEL = { 0.071, 0.075, 0.094 }
local CARD = { 0.09, 0.094, 0.114 }
local TRACK = { 0.137, 0.145, 0.169 }
local HEAD = { 0.055, 0.059, 0.071 }
-- The header band with the name and version, the heading below it, the footer with the buttons.
local TOP, FOOT = 50, 62

local frame, chosen

local function Fill(parent, color, layer, sub)
	local t = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, sub or 0)
	t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return t
end

local function Text(parent, size, color, justify)
	local fs = ns.Text(parent, size, justify)
	fs:SetFont(ns.FONT, size, '')
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 0.9)
	fs:SetTextColor(color[1], color[2], color[3])
	return fs
end

local function Button(parent, label, primary)
	local b = CreateFrame('Button', nil, parent)
	b:SetSize(120, 30)
	b.bg = Fill(b, primary and GOLD or TRACK)
	b.bg:SetAllPoints()
	ns.Outline(b)
	b.text = Text(b, 14, primary and { 0.1, 0.08, 0.03 } or TEXT, 'CENTER')
	b.text:SetPoint('CENTER')
	b.text:SetText(label)
	b.primary = primary
	function b:SetActive(on)
		self:SetEnabled(on)
		local c = (primary and on) and GOLD or TRACK
		self.bg:SetColorTexture(c[1], c[2], c[3], 1)
		local t = (primary and on) and { 0.1, 0.08, 0.03 } or (on and TEXT or MUTED)
		self.text:SetTextColor(t[1], t[2], t[3])
	end
	return b
end

-- A small drawing of a window in each look.
local function Preview(card, slim)
	local p = CreateFrame('Frame', nil, card)
	p:SetPoint('TOPLEFT', 12, -12)
	p:SetPoint('TOPRIGHT', -12, -12)
	p:SetHeight(110)
	local bg = Fill(p, slim and { 0.055, 0.059, 0.071 } or { 0.16, 0.12, 0.08 })
	bg:SetAllPoints()
	ns.Outline(p)
	if slim then
		local gold = Fill(p, GOLD, 'ARTWORK')
		gold:SetPoint('TOPLEFT')
		gold:SetPoint('TOPRIGHT')
		gold:SetHeight(2)
		local head = Fill(p, { 0.063, 0.067, 0.082 }, 'BORDER')
		head:SetPoint('TOPLEFT', 0, -2)
		head:SetPoint('TOPRIGHT', 0, -2)
		head:SetHeight(18)
	else
		local frameTex = Fill(p, { 0.42, 0.33, 0.18 }, 'BORDER')
		frameTex:SetPoint('TOPLEFT')
		frameTex:SetPoint('TOPRIGHT')
		frameTex:SetHeight(20)
		local ring = p:CreateTexture(nil, 'ARTWORK')
		ring:SetColorTexture(0.55, 0.45, 0.25, 1)
		ring:SetSize(34, 34)
		ring:SetPoint('TOPLEFT', -6, 6)
	end
	-- Item slots down both sides and a figure in the middle.
	for side = 0, 1 do
		for i = 0, 3 do
			local slot = Fill(p, slim and { 0.12, 0.125, 0.15 } or { 0.3, 0.24, 0.15 }, 'ARTWORK')
			slot:SetSize(16, 16)
			slot:SetPoint(side == 0 and 'TOPLEFT' or 'TOPRIGHT', side == 0 and 10 or -10, -28 - i * 20)
			if slim then
				local q = (i + side) % 3 == 0 and { 0.64, 0.21, 0.93 } or { 0, 0.44, 0.87 }
				local edge = Fill(p, q, 'ARTWORK', -1)
				edge:SetPoint('TOPLEFT', slot, -1, 1)
				edge:SetPoint('BOTTOMRIGHT', slot, 1, -1)
			end
		end
	end
	local figure = Fill(p, slim and { 0.2, 0.17, 0.27 } or { 0.36, 0.28, 0.18 }, 'ARTWORK')
	figure:SetSize(30, 62)
	figure:SetPoint('TOP', 0, -32)
	return p
end

local function Card(parent, key, title, desc, slim)
	local card = CreateFrame('Button', nil, parent)
	card:SetSize((W - 3 * 20) / 2, 210)
	card.bg = Fill(card, CARD)
	card.bg:SetAllPoints()
	card.edge = ns.Edge(card, 1, { 0, 0, 0 }, 0)
	Preview(card, slim)
	card.title = Text(card, 18, TEXT)
	card.title:SetPoint('TOPLEFT', 14, -132)
	card.title:SetText(title)
	card.desc = Text(card, 12, SOFT)
	card.desc:SetPoint('TOPLEFT', card.title, 'BOTTOMLEFT', 0, -6)
	card.desc:SetPoint('RIGHT', -14, 0)
	card.desc:SetWordWrap(true)
	card.desc:SetText(desc)
	card.key = key
	card.gold = ns.Edge(card, 2, GOLD, 0)
	card.gold:Hide()
	card:SetScript('OnEnter', function(self) if chosen ~= self.key then self.bg:SetColorTexture(0.11, 0.115, 0.14, 1) end end)
	card:SetScript('OnLeave', function(self) self.bg:SetColorTexture(CARD[1], CARD[2], CARD[3], 1) end)
	return card
end

local function Choose(key)
	chosen = key
	for _, card in ipairs(frame.cards) do card.gold:SetShown(card.key == key) end
	frame.apply:SetActive(true)
	frame.hint:SetText('')
end

local function Save(look)
	SlimARKDB.settings = SlimARKDB.settings or {}
	SlimARKDB.settings['blizz.look'] = look
	C.blizz.look = look
end

local function Build()
	frame = CreateFrame('Frame', 'SlimARK_Setup', UIParent)
	frame:SetFrameStrata('DIALOG')
	frame:SetToplevel(true)
	frame:SetWidth(W)
	frame:SetPoint('CENTER', 0, 80)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
	frame:SetScale(math.max(0.8, ns.Scale()))
	local bg = Fill(frame, PANEL)
	bg:SetAllPoints()
	ns.Outline(frame)
	tinsert(UISpecialFrames, 'SlimARK_Setup')
	local head = Fill(frame, HEAD, 'BORDER')
	head:SetPoint('TOPLEFT')
	head:SetPoint('TOPRIGHT')
	head:SetHeight(TOP)
	local headLine = Fill(frame, { 0, 0, 0 }, 'BORDER', 1)
	headLine:SetPoint('TOPLEFT', head, 'BOTTOMLEFT')
	headLine:SetPoint('TOPRIGHT', head, 'BOTTOMRIGHT')
	headLine:SetHeight(1)
	local foot = Fill(frame, HEAD, 'BORDER')
	foot:SetPoint('BOTTOMLEFT')
	foot:SetPoint('BOTTOMRIGHT')
	foot:SetHeight(FOOT)
	local footLine = Fill(frame, { 0, 0, 0 }, 'BORDER', 1)
	footLine:SetPoint('BOTTOMLEFT', foot, 'TOPLEFT')
	footLine:SetPoint('BOTTOMRIGHT', foot, 'TOPRIGHT')
	footLine:SetHeight(1)

	frame.title = Text(frame, 17, TEXT)
	frame.title:SetPoint('LEFT', frame, 'TOPLEFT', 18, -TOP / 2)
	frame.title:SetText('Slim|cfff2b84bARK|r-UI')
	local tag = CreateFrame('Frame', nil, frame)
	tag:SetPoint('LEFT', frame.title, 'RIGHT', 10, 0)
	tag:SetHeight(22)
	Fill(tag, TRACK):SetAllPoints()
	ns.Outline(tag)
	frame.version = Text(tag, 12, SOFT, 'CENTER')
	frame.version:SetPoint('CENTER')
	frame.tag = tag
	frame.heading = Text(frame, 22, TEXT)
	frame.heading:SetPoint('TOPLEFT', 20, -TOP - 20)
	frame.body = Text(frame, 13, SOFT)
	frame.body:SetPoint('TOPLEFT', frame.heading, 'BOTTOMLEFT', 0, -8)
	frame.body:SetWidth(W - 40)
	frame.body:SetWordWrap(true)

	frame.cards = {
		Card(frame, 'original', 'Original', "Blizzard's own windows stay as they are. SlimARK leaves them alone.", false),
		Card(frame, 'slimark', 'SlimARK', 'Flat dark windows with a thin black edge and the SlimARK font, like the rest of the UI.', true),
	}
	for _, card in ipairs(frame.cards) do card:SetScript('OnClick', function(self) Choose(self.key) end) end

	frame.note = Text(frame, 12, MUTED)
	frame.note:SetWidth(W - 40)
	frame.note:SetWordWrap(true)
	frame.saved = Text(frame, 13, SOFT)

	frame.apply = Button(frame, 'Apply now', true)
	frame.apply:SetPoint('BOTTOMRIGHT', -18, (FOOT - 30) / 2)
	frame.later = Button(frame, 'Later', false)
	frame.later:SetPoint('RIGHT', frame.apply, 'LEFT', -8, 0)
	frame.later:SetScript('OnClick', function() frame:Hide() end)
	frame.hint = Text(frame, 13, GOLD)
	frame.hint:SetPoint('LEFT', frame, 'BOTTOMLEFT', 20, FOOT / 2)
	frame.apply:SetScript('OnClick', function()
		if frame.mode == 'choose' then
			if not chosen then return end
			Save(chosen)
		end
		if ns.ApplyAll() == false then
			frame.hint:SetText('Apply failed. See chat, then try again.')
		else
			frame:Hide()
		end
	end)
end

-- The short form once the look is known, the cards until then.
function ns.ShowSetup()
	if not frame then Build() end
	local look = C.blizz.look
	frame.version:SetText('v' .. ns.version)
	frame.tag:SetWidth(frame.version:GetUnboundedStringWidth() + 16)
	if look ~= 'original' and look ~= 'slimark' then
		frame.mode = 'choose'
		chosen = nil
		frame.heading:SetText("How should Blizzard's windows look?")
		frame.body:SetText('Character sheet, spellbook, Group Finder, map, mail and the other game windows. Pick one to continue; you can change it later in /slimark.')
		local y = -TOP - 20 - 30 - frame.body:GetStringHeight() - 18
		frame.cards[1]:ClearAllPoints()
		frame.cards[1]:SetPoint('TOPLEFT', 20, y)
		frame.cards[2]:ClearAllPoints()
		frame.cards[2]:SetPoint('TOPRIGHT', -20, y)
		for _, card in ipairs(frame.cards) do card:Show() card.gold:Hide() end
		frame.note:ClearAllPoints()
		frame.note:SetPoint('TOPLEFT', frame.cards[1], 'BOTTOMLEFT', 0, -14)
		frame.note:SetText('Then Apply now sets up the positions and skins of this version and reloads the UI. Your own profiles and layouts stay untouched.')
		frame.note:Show()
		frame.saved:Hide()
		frame.apply:SetActive(false)
		frame.hint:SetText('Choose a look to continue')
		frame:SetHeight(-y + 210 + 14 + frame.note:GetStringHeight() + 18 + FOOT)
	else
		frame.mode = 'short'
		frame.heading:SetText('Set up this version')
		frame.body:SetText('Run Apply now to set up the positions and skins of this version. The UI reloads afterwards. Your own profiles and layouts stay untouched.')
		for _, card in ipairs(frame.cards) do card:Hide() end
		frame.note:Hide()
		frame.saved:ClearAllPoints()
		frame.saved:SetPoint('TOPLEFT', frame.body, 'BOTTOMLEFT', 0, -12)
		frame.saved:SetText('Blizzard windows: |cfff2b84b' .. (look == 'slimark' and 'SlimARK' or 'Original') .. '|r  ·  change it in /slimark')
		frame.saved:Show()
		frame.apply:SetActive(true)
		frame.hint:SetText('')
		frame:SetHeight(TOP + 20 + 30 + frame.body:GetStringHeight() + 12 + 20 + 18 + FOOT)
	end
	frame:Show()
end
