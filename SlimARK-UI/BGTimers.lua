local _, ns = ...
local C = ns.C

-- 3.0 (58) Battleground timers: when a base is assaulted, a flat bar counts down to the moment it is
-- taken, in the place of the boss frames (a battleground has none). The game tells only that a base
-- changed its map icon (AREA_POIS_UPDATED, C_AreaPoiInfo); how long a capture takes is fixed per
-- battleground. A change starts the count. Going back to the icon it had before (defended) or a
-- change at the end (taken) stops it; a change on the way (assaulted back) starts it again. Only the
-- battlegrounds where every map icon is a base are watched: in Alterac Valley, Isle of Conquest and
-- Eye of the Storm mines, gates, workshops or the flag change icons too, so they get no timers.
-- The map icons are listened to only inside a watched battleground, and the clock runs only while a
-- bar counts. Arena frames are another part.

-- Seconds an assault takes, by instance ID. Blitz (the rated solo battleground) takes half.
local CAPTURE = {
	[2107] = 60, [529] = 60, [1681] = 60, [2177] = 60, -- Arathi Basin and its brawls
	[761] = 60, -- Battle for Gilneas
	[2245] = 60, [1105] = 60, -- Deepwind Gorge and its brawl
}
-- A change this many seconds before the end of the count is the capture itself; a change this many
-- seconds after the count ran out is still the capture, a little late.
local EARLY, LATE = 3, 6
-- Bars shown at most; the box in Edit Mode is this tall.
local ROWS = 5

local watcher, holder, ticker
local capture = 0
local nodes, pool, active = {}, {}, {}

local function NewBar()
	local cfg = C.bgtimers
	local bar = CreateFrame('StatusBar', nil, holder)
	bar:SetSize(cfg.w, cfg.h)
	bar:SetStatusBarTexture(ns.SOFT)
	local gold = C.colors.classPower
	bar:SetStatusBarColor(gold[1], gold[2], gold[3])
	ns.Track(bar)
	ns.Outline(bar)
	bar.name = ns.Text(bar, cfg.font, 'LEFT')
	bar.name:SetPoint('LEFT', 6, 0)
	bar.name:SetPoint('RIGHT', -54, 0)
	bar.time = ns.Text(bar, cfg.font, 'RIGHT')
	bar.time:SetPoint('RIGHT', -6, 0)
	return bar
end

local function Layout()
	table.sort(active, function(a, b) return a.ends < b.ends end)
	local cfg = C.bgtimers
	for i, node in ipairs(active) do
		node.bar:ClearAllPoints()
		node.bar:SetPoint('TOPLEFT', holder, 'TOPLEFT', 0, -(i - 1) * (cfg.h + cfg.gap))
		node.bar:SetShown(i <= ROWS)
	end
	holder:SetShown(#active > 0)
end

local function Release(node)
	for i, other in ipairs(active) do
		if other == node then table.remove(active, i) break end
	end
	node.ends = nil
	if node.bar then
		node.bar:Hide()
		table.insert(pool, node.bar)
		node.bar = nil
	end
end

local function StopClock()
	if ticker then ticker:Cancel() ticker = nil end
end

local function Tick()
	local now = GetTime()
	for i = #active, 1, -1 do
		local node = active[i]
		local left = node.ends - now
		if left <= 0 then
			-- Taken: the icon change that follows in a moment is this capture.
			node.ended = now
			Release(node)
		else
			node.bar:SetValue(left)
			node.bar.time:SetText(('%d:%02d'):format(math.floor(left / 60), math.floor(left % 60)))
		end
	end
	if #active == 0 then StopClock() end
	Layout()
end

local function Count(node, name)
	if not node.ends then table.insert(active, node) end
	node.ends = GetTime() + capture
	node.bar = node.bar or table.remove(pool) or NewBar()
	node.bar.name:SetText(name)
	node.bar:SetMinMaxValues(0, capture)
	if not ticker then ticker = C_Timer.NewTicker(0.2, Tick) end
	Tick()
end

local function Changed(node, name, state)
	local now = GetTime()
	local before = node.state
	node.state = state
	if node.ends then
		if state == node.before or now >= node.ends - EARLY then
			Release(node)
			Layout()
			if #active == 0 then StopClock() end
		else
			Count(node, name)
		end
	elseif node.ended and now - node.ended <= LATE then
		node.ended = nil
	else
		node.ended = nil
		node.before = before
		Count(node, name)
	end
end

-- first: the icons seen on entering are only remembered, a running assault there has no known time.
local function Scan(first)
	local map = C_Map.GetBestMapForUnit('player')
	if not map then return end
	for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(map) or {}) do
		local info = C_AreaPoiInfo.GetAreaPOIInfo(map, id)
		local state = info and (info.atlasName or info.textureIndex)
		if state ~= nil and not issecretvalue(state) then
			local node = nodes[id]
			if not node then
				nodes[id] = { state = state }
			elseif node.state ~= state then
				if first then
					node.state = state
				else
					local name = info.name
					if name == nil or issecretvalue(name) then name = '?' end
					Changed(node, name, state)
				end
			end
		end
	end
end

local function Reset()
	for _, node in pairs(nodes) do Release(node) end
	wipe(nodes)
	StopClock()
	holder:Hide()
end

local function Enter()
	Reset()
	local _, kind, _, _, _, _, _, id = GetInstanceInfo()
	local seconds = kind == 'pvp' and CAPTURE[id]
	if not seconds then
		watcher:UnregisterEvent('AREA_POIS_UPDATED')
		return
	end
	local blitz = C_PvP and C_PvP.IsRatedSoloRBG and C_PvP.IsRatedSoloRBG()
	capture = blitz and seconds / 2 or seconds
	watcher:RegisterEvent('AREA_POIS_UPDATED')
	Scan(true)
end

ns.On('PLAYER_LOGIN', function()
	if not C.features.bgTimers or not C_AreaPoiInfo or not C_Map then return end
	local cfg = C.bgtimers
	holder = CreateFrame('Frame', nil, UIParent)
	holder:SetSize(cfg.w, cfg.h)
	holder:Hide()
	ns.Register(holder, cfg.x, cfg.y, { key = 'bgtimers', w = cfg.w, h = ROWS * (cfg.h + cfg.gap) - cfg.gap, side = 'RIGHT' })
	watcher = CreateFrame('Frame')
	watcher:SetScript('OnEvent', function() Scan(false) end)
	ns.On('PLAYER_ENTERING_WORLD', Enter)
end)
