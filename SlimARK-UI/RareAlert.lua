local _, ns = ...
local C = ns.C

-- 3.0 (46) Rare alert: when a rare mob shows up on the minimap, one quiet built-in sound (the soft
-- map ping) and a short flat text at the top of the screen for a few seconds. Each rare is announced
-- once: the same one never sounds again in this session. Rares are the minimap markers the game
-- draws with its rare and rare elite icons (VignetteKill, VignetteKillElite). Off by default; off it
-- registers nothing. The text is made the first time a rare appears.
local GOLD = { 0.95, 0.72, 0.29 }
local RARE = { vignettekill = true, vignettekillelite = true }

local seen = {}
local banner
local shown = 0

local function Build()
	local cfg = C.rareAlert
	banner = CreateFrame('Frame', nil, UIParent)
	banner:SetFrameStrata('HIGH')
	banner:SetSize(cfg.w, cfg.font * 2 + 26)
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
end

local function Announce(name)
	if not banner then Build() end
	local zone = GetMinimapZoneText and GetMinimapZoneText() or ''
	banner.title:SetText(zone ~= '' and ('RARE  ·  ' .. zone) or 'RARE')
	banner.text:SetText(name .. ' is up nearby')
	banner:Show()
	-- A newer rare keeps the text up for its own few seconds.
	shown = shown + 1
	local mine = shown
	C_Timer.After(C.rareAlert.time, function()
		if mine == shown then banner:Hide() end
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
end)
