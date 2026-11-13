local _, ns = ...
local C = ns.C

-- 3.0 (57) AFK screen: when you go AFK out of combat the interface fades out and the middle of the
-- screen shows your name, item level, spec, keystone and the time you have been away. It goes away
-- when you move, when combat starts or when AFK ends; a key or a click also brings the interface
-- back (the key still does its job), so the game menu is never opened unseen. The clock counts once
-- a second only while the screen is up; movement and combat are listened to only then. The frame
-- is made the first time.
local GOLD = { 0.95, 0.72, 0.29 }
local MUTED = { 0.6, 0.61, 0.65 }

local watcher, screen, ticker
local since
local dismissed = false
local Dismiss

-- The frame sits on the 3D world, so it stays visible while the interface is faded out. Its scale
-- makes one unit one pixel of the 2560x1600 layout, like the frames on UIParent.
local function Scale()
	local _, height = GetPhysicalScreenSize()
	return (768 / height) * ns.Fit() / WorldFrame:GetEffectiveScale()
end

local function Build()
	screen = CreateFrame('Frame', nil, WorldFrame)
	screen:SetFrameStrata('FULLSCREEN')
	screen:SetAllPoints(WorldFrame)
	screen:Hide()
	screen:EnableMouse(true)
	screen:SetScript('OnMouseDown', function() Dismiss() end)
	screen:EnableKeyboard(true)
	screen:SetPropagateKeyboardInput(true)
	screen:SetScript('OnKeyDown', function() Dismiss() end)
	local shade = screen:CreateTexture(nil, 'BACKGROUND')
	shade:SetAllPoints()
	shade:SetColorTexture(0, 0, 0, 0.45)

	local band = CreateFrame('Frame', nil, screen)
	band:SetPoint('LEFT')
	band:SetPoint('RIGHT')
	band:SetHeight(150 * Scale())
	local fill = band:CreateTexture(nil, 'BACKGROUND')
	fill:SetAllPoints()
	fill:SetColorTexture(0.063, 0.067, 0.082, 0.92)
	ns.Outline(band)
	screen.band = band

	local holder = CreateFrame('Frame', nil, band)
	holder:SetSize(1600, 150)
	holder:SetPoint('CENTER')
	holder:SetScale(Scale())
	screen.holder = holder

	local tag = ns.Text(holder, 18, 'CENTER')
	tag:SetPoint('TOP', 0, -16)
	tag:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	tag:SetText('AFK')
	screen.name = ns.Text(holder, 40, 'CENTER')
	screen.name:SetPoint('TOP', tag, 'BOTTOM', 0, -6)
	screen.info = ns.Text(holder, 20, 'CENTER')
	screen.info:SetPoint('TOP', screen.name, 'BOTTOM', 0, -8)
	screen.away = ns.Text(holder, 18, 'CENTER')
	screen.away:SetPoint('TOP', screen.info, 'BOTTOM', 0, -8)
	screen.away:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

	local fade = screen:CreateAnimationGroup()
	local alpha = fade:CreateAnimation('Alpha')
	alpha:SetFromAlpha(0)
	alpha:SetToAlpha(1)
	alpha:SetDuration(0.4)
	screen.fade = fade
end

local function KeyText()
	if ns.isForever or not (C_MythicPlus and C_ChallengeMode) then return end
	local map = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local level = C_MythicPlus.GetOwnedKeystoneLevel()
	if not (map and map > 0 and level and level > 0) then return end
	local name = C_ChallengeMode.GetMapUIInfo(map)
	return (name or '?') .. ' +' .. level
end

local function SpecText()
	local info = C_SpecializationInfo
	if not (info and info.GetSpecialization) then return end
	local index = info.GetSpecialization()
	if not index or index == 0 then return end
	local _, name = info.GetSpecializationInfo(index)
	return name
end

local function Fill()
	local _, class = UnitClass('player')
	local color = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or RAID_CLASS_COLORS[class])
	screen.name:SetText(UnitName('player') or '')
	if color then screen.name:SetTextColor(color.r, color.g, color.b) end
	local parts = {}
	local _, equipped = GetAverageItemLevel()
	if equipped and equipped > 0 then parts[#parts + 1] = tostring(math.floor(equipped + 0.0001)) end
	parts[#parts + 1] = SpecText()
	parts[#parts + 1] = KeyText()
	screen.info:SetText(table.concat(parts, '  ·  '))
end

local function Tick()
	local seconds = math.max(0, math.floor(GetTime() - since))
	screen.away:SetText(('%d:%02d away'):format(math.floor(seconds / 60), seconds % 60))
end

local function Hide()
	if not (screen and screen:IsShown()) then return end
	screen:Hide()
	UIParent:SetAlpha(1)
	if ticker then ticker:Cancel() ticker = nil end
	watcher:UnregisterEvent('PLAYER_STARTED_MOVING')
	watcher:UnregisterEvent('PLAYER_REGEN_DISABLED')
end

local function Show()
	if not screen then Build() end
	if screen:IsShown() then return end
	since = GetTime()
	Fill()
	Tick()
	screen:Show()
	screen.fade:Play()
	UIParent:SetAlpha(0)
	ticker = C_Timer.NewTicker(1, Tick)
	watcher:RegisterEvent('PLAYER_STARTED_MOVING')
	watcher:RegisterEvent('PLAYER_REGEN_DISABLED')
end

-- The AFK flag can be secret while chat is locked down: then nothing changes.
local function Check()
	local afk = UnitIsAFK('player')
	if issecretvalue and issecretvalue(afk) then return end
	if not afk then
		dismissed = false
		Hide()
	elseif not dismissed and not InCombatLockdown() and not UnitAffectingCombat('player') then
		Show()
	end
end

-- Shown again only after AFK ends and starts again.
Dismiss = function()
	dismissed = true
	Hide()
end

local function OnEvent(_, event)
	if event == 'PLAYER_STARTED_MOVING' or event == 'PLAYER_REGEN_DISABLED' then
		Dismiss()
	else
		Check()
	end
end

ns.On('PLAYER_LOGIN', function()
	if not C.features.afkScreen or not UnitIsAFK then return end
	watcher = CreateFrame('Frame')
	watcher:SetScript('OnEvent', OnEvent)
	watcher:RegisterUnitEvent('PLAYER_FLAGS_CHANGED', 'player')
end)
