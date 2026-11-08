local _, ns = ...
local cfg = ns.C.minimap

local holder, row
local adopted = {}
local placing = false

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
	local step = cfg.buttonSize + cfg.buttonGap
	local perColumn = math.max(1, math.floor((cfg.size + cfg.buttonGap) / step))
	placing = true
	for i, button in ipairs(shown) do
		local line = (i - 1) % perColumn
		local col = math.floor((i - 1) / perColumn)
		button:ClearAllPoints()
		button:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -col * step, -line * step)
	end
	placing = false
end

local function Adopt(button)
	if button.slimAdopted then return end
	button.slimAdopted = true
	button:SetParent(row)
	button:SetSize(cfg.buttonSize, cfg.buttonSize)
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
			MinimapZoneText:SetFont(ns.FONT, 16, 'OUTLINE')
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

ns.On('PLAYER_LOGIN', function()
	if not ns.C.modules.minimap then return end
	-- Addons use this to know that the map is square.
	function GetMinimapShape() return 'SQUARE' end

	holder = CreateFrame('Frame', 'SlimARK_Minimap', UIParent)
	holder:SetSize(cfg.size, cfg.size)
	ns.Register(holder, cfg.x, cfg.y, { key = 'minimap', side = 'RIGHT' })

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

	row = CreateFrame('Frame', nil, holder)
	row:SetSize(cfg.buttonSize, cfg.size)
	row:SetPoint('TOPRIGHT', holder, 'TOPLEFT', -4, 0)

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
