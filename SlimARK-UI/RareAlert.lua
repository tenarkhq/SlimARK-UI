local _, ns = ...
local C = ns.C

-- 3.0 (46) Rare alert: when a rare mob shows up on the minimap, one quiet built-in sound (the soft
-- map ping) and a short flat text at the top of the screen for a few seconds. Each rare is announced
-- once: the same one never sounds again in this session. Rares are the minimap markers the game
-- draws with its rare and rare elite icons (VignetteKill, VignetteKillElite). Off by default; off it
-- registers nothing. The text is made the first time a rare appears.
-- 3.1.0: a click on the text targets the rare (a secure /targetexact macro button over the text).
-- Secure buttons cannot change in combat, so a rare found in combat gets the click once combat ends,
-- if its text is still up.
local GOLD = { 0.95, 0.72, 0.29 }
local MUTED = { 0.6, 0.61, 0.65 }
local RARE = { vignettekill = true, vignettekillelite = true }

local seen = {}
local banner, click
local shown = 0
local current -- the name of the rare whose text is up

local function Build()
	local cfg = C.rareAlert
	banner = CreateFrame('Frame', nil, UIParent)
	banner:SetFrameStrata('HIGH')
	banner:SetSize(cfg.w, cfg.font * 2 + 42)
	banner:Hide()
	ns.Register(banner, 1280 - cfg.w / 2, cfg.y + ns.TopInset())
	local fill = banner:CreateTexture(nil, 'BACKGROUND')
	fill:SetAllPoints()
	fill:SetColorTexture(0.063, 0.067, 0.082, 0.9)
	ns.Outline(banner)
	banner.title = ns.Text(banner, cfg.font - 3, 'CENTER')
	banner.title:SetPoint('TOP', 0, -8)
	banner.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	banner.text = ns.Text(banner, cfg.font, 'CENTER')
	banner.text:SetPoint('TOP', banner.title, 'BOTTOM', 0, -4)
	banner.hint = ns.Text(banner, 12, 'CENTER')
	banner.hint:SetPoint('TOP', banner.text, 'BOTTOM', 0, -4)
	banner.hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
end

-- The secure button over the text. Made, set and shown out of combat only.
local function BuildClick()
	click = CreateFrame('Button', 'SlimARK_RareTarget', UIParent, 'SecureActionButtonTemplate')
	click:SetFrameStrata('HIGH')
	click:SetAllPoints(banner)
	click:RegisterForClicks('AnyUp', 'AnyDown')
	click:SetAttribute('type', 'macro')
	click:Hide()
	-- After the target is taken the text has done its job.
	click:SetScript('PostClick', function()
		banner:Hide()
		current = nil
		if not InCombatLockdown() then click:Hide() end
	end)
end

local function ArmClick()
	if not current or InCombatLockdown() then
		banner.hint:SetText('')
		return
	end
	if not click then BuildClick() end
	click:SetAttribute('macrotext', '/targetexact ' .. current)
	click:Show()
	banner.hint:SetText('Click: target')
end

local function Announce(name)
	if not banner then Build() end
	local zone = GetMinimapZoneText and GetMinimapZoneText() or ''
	banner.title:SetText(zone ~= '' and ('RARE  ·  ' .. zone) or 'RARE')
	banner.text:SetText(name .. ' is up nearby')
	banner:Show()
	current = name
	ArmClick()
	-- A newer rare keeps the text up for its own few seconds.
	shown = shown + 1
	local mine = shown
	C_Timer.After(C.rareAlert.time, function()
		if mine == shown then
			banner:Hide()
			current = nil
			if click and not InCombatLockdown() then click:Hide() end
		end
	end)
	PlaySound(SOUNDKIT.MAP_PING, 'SFX')
end

local function OnMinimap(_, guid, onMinimap)
	if not onMinimap or not guid or issecretvalue(guid) or seen[guid] then return end
	local info = C_VignetteInfo.GetVignetteInfo(guid)
	if not info then return end
	local atlas, name = info.atlasName, info.name
	if issecretvalue(atlas) or issecretvalue(name) or type(atlas) ~= 'string' then return end
	if not RARE[atlas:lower()] or info.isDead then return end
	seen[guid] = true
	Announce(name or '?')
end

ns.On('PLAYER_LOGIN', function()
	if not C.features.rareAlert or not C_VignetteInfo then return end
	ns.On('VIGNETTE_MINIMAP_UPDATED', OnMinimap)
	-- The click button is protected: it goes away while that is still allowed, and comes back
	-- after combat when the text is still up.
	ns.On('PLAYER_REGEN_DISABLED', function()
		if click and click:IsShown() then click:Hide() end
		if banner then banner.hint:SetText('') end
	end)
	ns.On('PLAYER_REGEN_ENABLED', function()
		if banner and banner:IsShown() and current then ArmClick() end
	end)
end)
