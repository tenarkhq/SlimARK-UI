local _, ns = ...
local cfg = ns.C.minimap

local holder, row
local adopted = {}
local placing = false
-- With the top bar the addon icons sit in its right end, above the map, in one row.
local inBar = false

-- Only the icon stays; the frame, the number on it and the text written onto it later disappear.
local function Strip(button)
	for _, region in ipairs({ button:GetRegions() }) do
		if region ~= button.icon then region:SetAlpha(0) end
	end
	for _, child in ipairs({ button:GetChildren() }) do
		child:SetAlpha(0)
	end
end

-- The addon icons go in a column at the left edge of the map, the space below the map is for the coordinates.
local function LayoutButtons()
	local shown = {}
	for _, button in ipairs(adopted) do
		Strip(button)
		if button:IsShown() then table.insert(shown, button) end
	end
	placing = true
	if inBar then
		local size, gap = ns.C.databar.iconSize, 3
		for i, button in ipairs(shown) do
			button:SetSize(size, size)
			button:ClearAllPoints()
			button:SetPoint('RIGHT', row, 'RIGHT', -(i - 1) * (size + gap), 0)
		end
		row:SetWidth(math.max(1, #shown * (size + gap) - gap))
		if ns.OnLogosResized then ns.OnLogosResized() end
	else
		local step = cfg.buttonSize + cfg.buttonGap
		local perColumn = math.max(1, math.floor((cfg.size + cfg.buttonGap) / step))
		for i, button in ipairs(shown) do
			local line = (i - 1) % perColumn
			local col = math.floor((i - 1) / perColumn)
			button:ClearAllPoints()
			button:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -col * step, -line * step)
		end
	end
	placing = false
end

local function Adopt(button)
	if button.slimAdopted then return end
	button.slimAdopted = true
	button:SetParent(row)
	local size = inBar and ns.C.databar.iconSize or cfg.buttonSize
	button:SetSize(size, size)
	button:SetScript('OnDragStart', nil)
	button:SetScript('OnDragStop', nil)
	button:ClearHighlightTexture()
	if button.icon then
		button.icon:ClearAllPoints()
		button.icon:SetAllPoints()
		button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	-- A dark square behind the icon, so transparent icons stay readable on the map art.
	local bg = button:CreateTexture(nil, 'BACKGROUND', nil, -7)
	bg:SetAllPoints()
	bg:SetColorTexture(0.06, 0.065, 0.08, 0.92)
	if button.icon then
		button.icon:ClearAllPoints()
		button.icon:SetPoint('TOPLEFT', 2, -2)
		button.icon:SetPoint('BOTTOMRIGHT', -2, 2)
	end
	ns.Outline(button)
	hooksecurefunc(button, 'SetPoint', function()
		if not placing then LayoutButtons() end
	end)
	button:HookScript('OnShow', LayoutButtons)
	button:HookScript('OnHide', LayoutButtons)
	table.insert(adopted, button)
	-- SlimARK's own button comes first, the others follow by name.
	table.sort(adopted, function(a, b)
		if a.slimOwn ~= b.slimOwn then return a.slimOwn == true end
		return (a:GetName() or '') < (b:GetName() or '')
	end)
end

-- SlimARK-UI's own button in the column: a click opens the settings.
local function OwnButton()
	local button = CreateFrame('Button', 'SlimARK_MinimapButton', row)
	button.slimOwn = true
	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetTexture([[Interface\AddOns\SlimARK-UI\Media\Icon]])
	button:RegisterForClicks('AnyUp')
	button:SetScript('OnClick', function()
		if ns.OpenSettings then ns.OpenSettings() end
	end)
	button:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
		GameTooltip:AddLine('SlimARK-UI ' .. ns.version)
		GameTooltip:AddLine('Click: open the settings', 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', GameTooltip_Hide)
	Adopt(button)
end

local function CollectButtons()
	local lib = LibStub and LibStub('LibDBIcon-1.0', true)
	if not lib then return end
	for _, button in pairs(lib.objects) do
		Adopt(button)
	end
	LayoutButtons()
	if not ns.dbIconHooked then
		ns.dbIconHooked = true
		lib.RegisterCallback(ns, 'LibDBIcon_IconCreated', function(_, button)
			Adopt(button)
			LayoutButtons()
		end)
	end
end

local function Inside(frame, point, x, y, size)
	if not frame then return end
	frame:SetParent(Minimap)
	frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	frame:ClearAllPoints()
	frame:SetPoint(point, Minimap, point, x, y)
	if size then frame:SetSize(size, size) end
end

local function StyleClock()
	local clock = TimeManagerClockButton
	if not clock then return end
	-- The clock is in the middle of the top bar; its spot belongs to the coordinates.
	if ns.ClockInBar() then
		clock:SetAlpha(0)
		clock:EnableMouse(false)
		return
	end
	Inside(clock, 'BOTTOM', 0, 2)
	local background = clock:GetRegions()
	if background and background:IsObjectType('Texture') then background:SetAlpha(0) end
	if TimeManagerClockTicker then
		TimeManagerClockTicker:SetFont(ns.FONT, 16, 'OUTLINE')
		TimeManagerClockTicker:SetShadowOffset(0, 0)
	end
end

-- Blizzard puts the header elements back when Edit Mode loads, so this runs again.
local function Arrange()
	local cluster = MinimapCluster
	if cluster.BorderTop then cluster.BorderTop:SetAlpha(0) end
	cluster:EnableMouse(false)

	local zone = cluster.ZoneTextButton
	if zone then
		Inside(zone, 'TOP', 0, -3)
		zone:SetWidth(cfg.size - 50)
		if MinimapZoneText then
			ns.SetFont(MinimapZoneText, 16, 'OUTLINE')
			MinimapZoneText:SetShadowOffset(0, 0)
			MinimapZoneText:SetJustifyH('CENTER')
		end
	end

	local tracking = cluster.Tracking
	if tracking then
		Inside(tracking, 'TOPLEFT', 2, -2, 22)
		if tracking.Background then tracking.Background:SetAlpha(0) end
	end

	Inside(cluster.IndicatorFrame, 'BOTTOMLEFT', 3, 3)
	Inside(cluster.InstanceDifficulty, 'TOPRIGHT', -2, -2)
	-- The addon list counter, the addon icons make it unnecessary.
	if AddonCompartmentFrame then
		AddonCompartmentFrame:SetAlpha(0)
		AddonCompartmentFrame:EnableMouse(false)
	end
	Inside(ExpansionLandingPageMinimapButton, 'BOTTOMRIGHT', -3, 26)
	if ExpansionLandingPageMinimapButton then ExpansionLandingPageMinimapButton:SetScale(0.6) end

	if GameTimeFrame then GameTimeFrame:Hide() end
	StyleClock()
end

function ns.ClockInBar()
	return ns.C.modules.databar and ns.C.databar.show.clock
end

-- The player's map position at the bottom of the map, large and on a dark strip so it reads on
-- any map art. Inside instances the game gives no position, then it hides.
local function Coordinates()
	local strip = CreateFrame('Frame', nil, Minimap)
	strip:SetFrameLevel(Minimap:GetFrameLevel() + 6)
	strip:SetHeight(cfg.coordsFont + 8)
	strip:SetPoint('BOTTOM', 0, 3)
	local bg = strip:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)
	local text = ns.Text(strip, cfg.coordsFont, 'CENTER')
	text:SetFont(ns.FONT, cfg.coordsFont, 'THICKOUTLINE')
	text:SetPoint('CENTER', 0, 0)
	text:SetTextColor(1, 1, 1)
	local last
	local function Update()
		local map = C_Map.GetBestMapForUnit('player')
		local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
		local x, y = pos and pos.x, pos and pos.y
		if not x or issecretvalue(x) or (x == 0 and y == 0) then
			strip:Hide()
			last = nil
			return
		end
		local value = ('%.1f, %.1f'):format(x * 100, y * 100)
		if value ~= last then
			last = value
			text:SetText(value)
			strip:SetWidth(text:GetUnboundedStringWidth() + 16)
		end
		strip:Show()
	end
	-- A light timer, only while the map is on screen.
	local ticker
	local function Start()
		if not ticker then ticker = C_Timer.NewTicker(0.2, Update) end
		Update()
	end
	local function Stop()
		if ticker then ticker:Cancel() ticker = nil end
	end
	Minimap:HookScript('OnShow', Start)
	Minimap:HookScript('OnHide', Stop)
	if Minimap:IsVisible() then Start() end
end

ns.On('PLAYER_LOGIN', function()
	if not ns.C.modules.minimap then return end
	-- Addons use this to know that the map is square.
	function GetMinimapShape() return 'SQUARE' end

	holder = CreateFrame('Frame', 'SlimARK_Minimap', UIParent)
	holder:SetSize(cfg.size, cfg.size)
	ns.Register(holder, cfg.x, cfg.y + ns.TopInset(), { key = 'minimap', side = 'RIGHT' })

	Minimap:SetParent(holder)
	Minimap:ClearAllPoints()
	Minimap:SetAllPoints(holder)
	Minimap:SetSize(cfg.size, cfg.size)
	Minimap:SetMaskTexture([[Interface\ChatFrame\ChatFrameBackground]])
	ns.Outline(holder)

	if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(0) end
	for _, key in ipairs({ 'ZoomIn', 'ZoomOut' }) do
		local button = Minimap[key]
		if button then
			button:SetAlpha(0)
			button:EnableMouse(false)
		end
	end

	if ns.barLogos then
		inBar = true
		row = ns.barLogos
	else
		row = CreateFrame('Frame', nil, holder)
		row:SetSize(cfg.buttonSize, cfg.size)
		row:SetPoint('TOPRIGHT', holder, 'TOPLEFT', -4, 0)
	end
	if cfg.coords then Coordinates() end

	Arrange()
	hooksecurefunc(MinimapCluster, 'SetHeaderUnderneath', Arrange)
	if ExpansionLandingPageMinimapButton and ExpansionLandingPageMinimapButton.UpdateIcon then
		hooksecurefunc(ExpansionLandingPageMinimapButton, 'UpdateIcon', function()
			Inside(ExpansionLandingPageMinimapButton, 'BOTTOMRIGHT', -3, 26)
		end)
	end
	OwnButton()
	CollectButtons()
	C_Timer.After(3, CollectButtons)
	C_Timer.After(10, LayoutButtons)
end)

ns.On('ADDON_LOADED', function(_, name)
	if name == 'Blizzard_TimeManager' and holder then StyleClock() end
end)
