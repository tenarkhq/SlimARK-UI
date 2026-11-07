local _, ns = ...

-- Mozgatható Blizzard ablakok. A betöltés nélküliek akkor kerülnek sorra, amikor megjelennek.
local WINDOWS = {
	'CharacterFrame', 'PlayerSpellsFrame', 'ProfessionsBookFrame', 'ProfessionsFrame', 'CollectionsJournal',
	'EncounterJournal', 'AchievementFrame', 'FriendsFrame', 'PVEFrame', 'CommunitiesFrame', 'GuildFrame',
	'MerchantFrame', 'GossipFrame', 'QuestFrame', 'QuestLogPopupDetailFrame', 'MailFrame', 'OpenMailFrame',
	'TradeFrame', 'BankFrame', 'AuctionHouseFrame', 'InspectFrame', 'DressUpFrame', 'ContainerFrameCombinedBags',
	'ItemUpgradeFrame', 'ItemSocketingFrame', 'ItemInteractionFrame', 'WeeklyRewardsFrame', 'MacroFrame',
	'AddonList', 'SettingsPanel', 'TimeManagerFrame', 'TaxiFrame', 'FlightMapFrame', 'HousingDashboardFrame',
}

local MIN_SCALE, MAX_SCALE, STEP = 0.5, 1.6, 0.05
local hooked = {}
local applying = false

local function Blocked(frame)
	return InCombatLockdown() and frame:IsProtected()
end

local function Store(name)
	ns.CharDB.windows = ns.CharDB.windows or {}
	ns.CharDB.windows[name] = ns.CharDB.windows[name] or {}
	return ns.CharDB.windows[name]
end

-- A pozíció UIParent egységben van tárolva, így a méretezés nem tolja el az ablakot.
local function Apply(frame, name)
	local saved = ns.CharDB.windows and ns.CharDB.windows[name]
	if not saved or applying or Blocked(frame) then return end
	applying = true
	local scale = saved.scale or frame:GetScale()
	if saved.scale then frame:SetScale(scale) end
	if saved.left then
		frame:ClearAllPoints()
		frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', saved.left / scale, saved.top / scale)
	end
	applying = false
end

local function SavePosition(frame, name)
	local saved = Store(name)
	local scale = frame:GetScale()
	saved.left = frame:GetLeft() * scale
	saved.top = frame:GetTop() * scale
end

local function Wheel(frame, name, delta)
	if not IsControlKeyDown() or Blocked(frame) then return end
	SavePosition(frame, name)
	local saved = Store(name)
	local scale = math.max(MIN_SCALE, math.min(MAX_SCALE, frame:GetScale() + delta * STEP))
	saved.scale = scale
	Apply(frame, name)
end

local function Hook(name)
	local frame = _G[name]
	if hooked[name] or not frame or not frame.SetMovable then return end
	hooked[name] = true

	frame:SetMovable(true)
	frame:SetClampedToScreen(true)

	-- A fejléc sávja húzható, az ablak felett Ctrl+görgő méretez.
	local handle = CreateFrame('Frame', nil, frame)
	handle:SetPoint('TOPLEFT', 0, 0)
	handle:SetPoint('TOPRIGHT', -28, 0)
	handle:SetHeight(24)
	handle:SetFrameLevel(frame:GetFrameLevel() + 20)
	handle:EnableMouse(true)
	handle:RegisterForDrag('LeftButton')
	handle:SetScript('OnDragStart', function()
		if not Blocked(frame) then frame:StartMoving() end
	end)
	handle:SetScript('OnDragStop', function()
		frame:StopMovingOrSizing()
		SavePosition(frame, name)
		Apply(frame, name)
	end)

	frame:EnableMouseWheel(true)
	frame:HookScript('OnMouseWheel', function(_, delta) Wheel(frame, name, delta) end)
	frame:HookScript('OnShow', function() Apply(frame, name) end)
	hooksecurefunc(frame, 'SetPoint', function() Apply(frame, name) end)
	Apply(frame, name)
end

local function HookAll()
	for _, name in ipairs(WINDOWS) do Hook(name) end
end

ns.On('PLAYER_LOGIN', HookAll)
ns.On('ADDON_LOADED', function()
	if ns.CharDB then HookAll() end
end)

-- A saját keretek az Edit Mode-ban húzhatók, Ctrl+görgővel méretezhetők.
local overlays = {}

local function Pixels(frame)
	local _, height = GetPhysicalScreenSize()
	local ratio = frame:GetEffectiveScale() * height / 768
	return frame:GetLeft() * ratio, height - frame:GetTop() * ratio
end

local function Save(item, overlay, scale)
	local x, y = Pixels(overlay)
	ns.CharDB.pos = ns.CharDB.pos or {}
	local saved = ns.CharDB.pos[item.key] or {}
	saved.x, saved.y = x, y
	saved.scale = scale or saved.scale or 1
	ns.CharDB.pos[item.key] = saved
end

local function Refresh(item, overlay)
	if InCombatLockdown() then return end
	ns.Place(item)
	ns.Place(item, overlay)
	for _, other in ipairs(ns.Placed) do
		if other.owner == item then ns.Place(other) end
	end
end

local function CreateOverlay(item)
	local overlay = CreateFrame('Frame', nil, UIParent)
	overlay:SetFrameStrata('DIALOG')
	overlay:SetMovable(true)
	overlay:SetClampedToScreen(true)
	overlay:EnableMouse(true)
	overlay:EnableMouseWheel(true)
	overlay:RegisterForDrag('LeftButton')
	local w, h = item.w or item.frame:GetWidth(), item.h or item.frame:GetHeight()
	overlay:SetSize(w, h)

	local fill = overlay:CreateTexture(nil, 'BACKGROUND')
	fill:SetAllPoints()
	fill:SetColorTexture(0.25, 0.6, 1, 0.35)
	ns.Edge(overlay, 1, { 0.35, 0.75, 1 }, 0)
	local label = ns.Text(overlay, 16, 'CENTER')
	label:SetPoint('CENTER')
	label:SetText(item.key)

	overlay:SetScript('OnDragStart', overlay.StartMoving)
	overlay:SetScript('OnDragStop', function(self)
		self:StopMovingOrSizing()
		Save(item, self)
		Refresh(item, self)
	end)
	overlay:SetScript('OnMouseWheel', function(self, delta)
		if not IsControlKeyDown() then return end
		local saved = ns.Saved(item)
		local scale = (saved and saved.scale or 1) + delta * STEP
		Save(item, self, math.max(MIN_SCALE, math.min(MAX_SCALE, scale)))
		Refresh(item, self)
	end)
	return overlay
end

local function ShowOverlays()
	if InCombatLockdown() then return end
	for _, item in ipairs(ns.Placed) do
		if item.key then
			local overlay = overlays[item] or CreateOverlay(item)
			overlays[item] = overlay
			ns.Place(item, overlay)
			overlay:Show()
		end
	end
end

local function HideOverlays()
	for _, overlay in pairs(overlays) do overlay:Hide() end
end

ns.On('PLAYER_LOGIN', function()
	EventRegistry:RegisterCallback('EditMode.Enter', ShowOverlays, ns)
	EventRegistry:RegisterCallback('EditMode.Exit', HideOverlays, ns)
end)
