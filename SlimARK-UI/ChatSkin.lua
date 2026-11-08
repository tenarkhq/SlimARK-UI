local _, ns = ...
local C = ns.C

-- Chattynator gives other addons no way to add a skin. Its Dark skin stays selected (Skins.lua
-- picks it in the SlimARK-UI profile), and here its tabs and the edit box get the flat SlimARK look
-- on top: a dark rectangle with a 1 px black edge, our font, the selected tab in gold, the tab's
-- own color as a thin stripe on top, and a slow gold line at the bottom for a new message.
-- Only Chattynator's Dark tabs are touched; they are the ones with its Left/Middle/Flash textures.

local GOLD = { 0.95, 0.72, 0.29 }
local MUTED = { 0.73, 0.71, 0.67 }
local ART = { 'Left', 'Right', 'Middle', 'LeftFlash', 'RightFlash', 'MiddleFlash' }

local styled = {}
local hookedBars = {}
local font

local function TabFont()
	if not font then font = CreateFont('SlimARK_ChatTabFont') end
	font:SetFont(ns.FONT, C.chat.tabFont, '')
	font:SetShadowOffset(1, -1)
	font:SetShadowColor(0, 0, 0, 1)
	return font
end

local function Refresh(tab)
	local s = styled[tab]
	if not s then return end
	tab:SetAlpha(1)
	local selected = tab.selected and true or false
	local color = selected and GOLD or MUTED
	if not selected and tab.IsMouseMotionFocus and tab:IsMouseMotionFocus() then color = { 1, 1, 1 } end
	local text = tab:GetFontString()
	if text then text:SetTextColor(color[1], color[2], color[3]) end
	local shade = selected and 0.106 or 0.07
	s.bg:SetColorTexture(shade, shade + 0.008, shade + 0.025, selected and 0.92 or 0.8)
	local c = tab.color
	if c then s.stripe:SetColorTexture(c.r, c.g, c.b, 0.9) end
	s.stripe:SetShown(C.chat.tabStripe and c ~= nil)
	s.line:SetShown(not C.chat.tabStripe and selected)
	local flashing = tab.flashing and true or false
	s.flash:SetShown(flashing)
	if flashing then
		if not s.pulse:IsPlaying() then s.pulse:Play() end
	else
		s.pulse:Stop()
	end
end
ns.RefreshChatTab = Refresh

local function Line(tab, point, height, layer)
	local t = tab:CreateTexture(nil, layer or 'ARTWORK')
	t:SetPoint(point .. 'LEFT')
	t:SetPoint(point .. 'RIGHT')
	t:SetHeight(height)
	return t
end

local function Style(tab)
	if styled[tab] or not tab.Middle or not tab.MiddleFlash then return end
	local s = {}
	styled[tab] = s
	for _, key in ipairs(ART) do
		if tab[key] then tab[key]:SetTexture(nil) end
	end
	s.bg = tab:CreateTexture(nil, 'BACKGROUND')
	s.bg:SetAllPoints()
	ns.Outline(tab)
	s.stripe = Line(tab, 'TOP', 2)
	s.line = Line(tab, 'BOTTOM', 2)
	s.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	s.flash = Line(tab, 'BOTTOM', 2, 'OVERLAY')
	s.flash:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	s.flash:Hide()
	s.pulse = s.flash:CreateAnimationGroup()
	s.pulse:SetLooping('BOUNCE')
	local fade = s.pulse:CreateAnimation('Alpha')
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.25)
	fade:SetDuration(0.6)

	tab:SetNormalFontObject(TabFont())
	local text = tab:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint('CENTER', 0, 0)
	end
	-- Chattynator measures the tab width when the text is set; the new font is measured again.
	if tab.GetText and tab:GetText() then tab:SetText(tab:GetText()) end

	hooksecurefunc(tab, 'SetSelected', Refresh)
	hooksecurefunc(tab, 'SetColor', Refresh)
	hooksecurefunc(tab, 'SetFlashing', Refresh)
	tab:HookScript('OnEnter', Refresh)
	tab:HookScript('OnLeave', Refresh)
	Refresh(tab)
end

local function StyleEditBox()
	local box = _G.ChatFrame1EditBox
	if not box or styled[box] then return end
	styled[box] = true
	ns.Outline(box)
	if box.SetFont then box:SetFont(ns.FONT, C.chat.fontSize, '') end
	local header = _G.ChatFrame1EditBoxHeader
	if header and header.SetFont then header:SetFont(ns.FONT, C.chat.fontSize, '') end
end

local function StyleBar(bar)
	for _, tab in ipairs(bar.Tabs or {}) do Style(tab) end
	if bar.dropdownTabButton then Style(bar.dropdownTabButton) end
end

local function Scan()
	local holder = _G.ChattynatorHyperlinkHandler
	if not holder then return end
	for _, window in ipairs({ holder:GetChildren() }) do
		local bar = window.TabsBar
		if bar then
			if not hookedBars[bar] and bar.RefreshTabs then
				hookedBars[bar] = true
				-- Tabs come and go when they are added, removed or moved.
				hooksecurefunc(bar, 'RefreshTabs', StyleBar)
			end
			StyleBar(bar)
		end
	end
	StyleEditBox()
end
ns.ScanChattynator = Scan

ns.On('PLAYER_ENTERING_WORLD', function(_, isLogin, isReload)
	if not (isLogin or isReload) or not C.chat.flatTabs then return end
	if not (C_AddOns.IsAddOnLoaded('Chattynator')) then return end
	-- Chattynator builds its windows and skins them at login; ours goes on after.
	C_Timer.After(0.5, Scan)
end)
