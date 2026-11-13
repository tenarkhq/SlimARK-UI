local _, ns = ...
local C = ns.C

-- 3.0 (45) World map coordinates: your position and the mouse's on the open world map, on a dark
-- strip at the bottom of the map. Inside instances the game gives no position, so nothing shows
-- there. A light timer runs only while the map is open. Off by default; off it hooks nothing.
local strip, ticker
local hooked = false

local function Format(label, x, y)
	if not x or (x == 0 and y == 0) then return label .. '  -' end
	return ('%s  %.1f, %.1f'):format(label, x * 100, y * 100)
end

local function Build(map)
	local canvas = map.ScrollContainer or map
	strip = CreateFrame('Frame', nil, canvas)
	strip:SetFrameLevel(canvas:GetFrameLevel() + 20)
	strip:SetHeight(24)
	strip:SetPoint('BOTTOM', canvas, 'BOTTOM', 0, 4)
	local bg = strip:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)
	strip.text = ns.Text(strip, 14, 'CENTER')
	strip.text:SetPoint('CENTER')
end

local function Update()
	local map = WorldMapFrame
	if IsInInstance() then
		strip:Hide()
		return
	end
	local mapID = map:GetMapID()
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, 'player')
	local px, py = pos and pos.x, pos and pos.y
	if px and (issecretvalue(px) or issecretvalue(py)) then px, py = nil, nil end
	local cx, cy
	local canvas = map.ScrollContainer
	if canvas and canvas.GetNormalizedCursorPosition and canvas:IsMouseOver() then
		cx, cy = canvas:GetNormalizedCursorPosition()
		if cx and (cx < 0 or cx > 1 or cy < 0 or cy > 1) then cx, cy = nil, nil end
	end
	local text = Format('Player', px, py) .. '      ' .. Format('Cursor', cx, cy)
	if text ~= strip.last then
		strip.last = text
		strip.text:SetText(text)
		strip:SetWidth(strip.text:GetUnboundedStringWidth() + 24)
	end
	strip:Show()
end

local function Start()
	if not strip then Build(WorldMapFrame) end
	Update()
	if not ticker then ticker = C_Timer.NewTicker(0.1, Update) end
end

local function Stop()
	if ticker then ticker:Cancel() ticker = nil end
end

local function Hook()
	local map = WorldMapFrame
	if not map or hooked then return end
	hooked = true
	map:HookScript('OnShow', Start)
	map:HookScript('OnHide', Stop)
	if map:IsShown() then Start() end
end

ns.On('PLAYER_LOGIN', function()
	if not C.features.mapCoords or not C_Map then return end
	if WorldMapFrame then
		Hook()
	else
		ns.On('ADDON_LOADED', function(_, name)
			if name == 'Blizzard_WorldMap' then Hook() end
		end)
	end
end)
