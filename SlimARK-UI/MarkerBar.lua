local _, ns = ...
local C = ns.C
local cfg = C.markers

-- Target markers, ground markers, ready check and pull countdown, shown only in a group.
-- The marker buttons are Blizzard's secure marker actions, so they work in combat too.
-- It updates on group, leader and target changes only: no timer.

-- Raid target icon order: star, circle, diamond, triangle, moon, square, cross, skull.
-- The ground markers are numbered differently; this maps each icon to its ground marker.
local WORLD = { 5, 6, 3, 2, 7, 1, 4, 8 }
local WORLD_COLOR = {
	[1] = { 0.24, 0.56, 1 }, [2] = { 0.25, 0.82, 0.25 }, [3] = { 0.76, 0.36, 1 }, [4] = { 1, 0.23, 0.23 },
	[5] = { 1, 0.82, 0.23 }, [6] = { 1, 0.54, 0.16 }, [7] = { 0.79, 0.83, 0.88 }, [8] = { 0.95, 0.95, 0.95 },
}
local BG = { 0.106, 0.114, 0.133 }
local GOLD = { 0.95, 0.72, 0.29 }

local bar
local targets = {}
local utility = {}

-- How far the quest tracker moves down under the bar when it sits under the minimap.
function ns.MarkerInset()
	if not C.modules.markers or cfg.place ~= 'map' then return 0 end
	return 3 * (cfg.size + cfg.gap) + 8
end

local function Box(button)
	local bg = button:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(BG[1], BG[2], BG[3], 1)
	ns.Outline(button)
	local hl = button:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.12)
end

local function Icon(button, i, inset)
	local icon = button:CreateTexture(nil, 'ARTWORK')
	icon:SetPoint('TOPLEFT', inset, -inset)
	icon:SetPoint('BOTTOMRIGHT', -inset, inset)
	icon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcon_]] .. i)
	return icon
end

local function Tip(button, title, line)
	button:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
		GameTooltip:AddLine(title)
		if line then GameTooltip:AddLine(line, 1, 1, 1) end
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', function() GameTooltip:Hide() end)
end

local function TargetButton(i)
	local b = CreateFrame('Button', 'SlimARK_Marker' .. i, bar, 'SecureActionButtonTemplate')
	b:SetSize(cfg.size, cfg.size)
	b:RegisterForClicks('AnyUp')
	b:SetAttribute('useOnKeyDown', false) -- acts on the release it is registered for
	b:SetAttribute('type', 'raidtarget')
	b:SetAttribute('action', 'toggle')
	b:SetAttribute('marker', i)
	b:SetAttribute('unit', 'target')
	Box(b)
	Icon(b, i, 3)
	b.edge = ns.Edge(b, 1, GOLD, 0)
	b.edge:Hide()
	Tip(b, 'Target marker', 'Click: put it on your target, click again: take it off')
	return b
end

local function GroundButton(i)
	local world = WORLD[i]
	local b = CreateFrame('Button', 'SlimARK_GroundMarker' .. i, bar, 'SecureActionButtonTemplate')
	b:SetSize(cfg.size, cfg.size)
	b:RegisterForClicks('AnyUp')
	b:SetAttribute('useOnKeyDown', false)
	b:SetAttribute('type', 'worldmarker')
	b:SetAttribute('marker', world)
	b:SetAttribute('action1', 'set')
	b:SetAttribute('action2', 'clear')
	Box(b)
	local color = WORLD_COLOR[world]
	local square = b:CreateTexture(nil, 'BORDER')
	square:SetPoint('TOPLEFT', 3, -3)
	square:SetPoint('BOTTOMRIGHT', -3, 3)
	square:SetColorTexture(color[1], color[2], color[3], 0.85)
	local icon = Icon(b, i, 8)
	icon:SetDesaturated(true)
	icon:SetVertexColor(0.1, 0.1, 0.1)
	Tip(b, 'Ground marker', 'Left click: place it where you click, right click: pick it up')
	return b
end

local function TextButton(label, secure)
	local b = CreateFrame('Button', nil, bar, secure and 'SecureActionButtonTemplate' or nil)
	b:SetHeight(cfg.size)
	b:RegisterForClicks('AnyUp')
	if secure then b:SetAttribute('useOnKeyDown', false) end
	Box(b)
	b.text = ns.Text(b, math.max(10, cfg.size - 15), 'CENTER')
	b.text:SetPoint('CENTER')
	b.text:SetText(label)
	return b
end

local function Build()
	bar = CreateFrame('Frame', 'SlimARK_MarkerBar', UIParent, 'SecureHandlerStateTemplate')
	local step = cfg.size + cfg.gap
	for i = 1, 8 do targets[i] = TargetButton(i) end
	local grounds = {}
	for i = 1, 8 do grounds[i] = GroundButton(i) end

	local ready = TextButton('Ready')
	ready:SetScript('OnClick', function()
		local start = C_PartyInfo and C_PartyInfo.DoReadyCheck or DoReadyCheck
		start()
	end)
	Tip(ready, 'Ready check')
	local pull = TextButton('Pull')
	pull:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	pull:SetScript('OnClick', function(_, button)
		if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(button == 'RightButton' and 0 or 10) end
	end)
	Tip(pull, 'Pull countdown', 'Left click: 10 seconds, right click: stop it')
	local clear = TextButton('Clear', true)
	clear:SetAttribute('type', 'worldmarker')
	clear:SetAttribute('action', 'clear')
	Tip(clear, 'Clear ground markers', 'Picks up every ground marker')
	utility.ready, utility.pull = ready, pull

	local w, h
	if cfg.place == 'party' then
		-- Two columns, a row per marker, the three buttons under them.
		for i = 1, 8 do
			targets[i]:SetPoint('TOPLEFT', 0, -(i - 1) * step)
			grounds[i]:SetPoint('TOPLEFT', step, -(i - 1) * step)
		end
		w = 2 * cfg.size + cfg.gap
		for n, b in ipairs({ ready, pull, clear }) do
			b:SetWidth(w)
			b:SetPoint('TOPLEFT', 0, -(7 + n) * step)
		end
		h = 11 * step - cfg.gap
	else
		-- Three rows under the minimap: target markers, ground markers, the buttons.
		w = 8 * step - cfg.gap
		for i = 1, 8 do
			targets[i]:SetPoint('TOPLEFT', (i - 1) * step, 0)
			grounds[i]:SetPoint('TOPLEFT', (i - 1) * step, -step)
		end
		local third = (w - 2 * cfg.gap) / 3
		for n, b in ipairs({ ready, pull, clear }) do
			b:SetWidth(third)
			b:SetPoint('TOPLEFT', (n - 1) * (third + cfg.gap), -2 * step)
		end
		h = 3 * step - cfg.gap
	end
	bar:SetSize(w, h)
	return w, h
end

local function Position(w, h)
	if cfg.place == 'party' then
		local p, g = C.units.party, C.units.grid
		ns.Register(bar, p.x + p.w + 10, p.y, { key = 'markers', w = w, h = h,
			heal = { x = g.x - w - 10, y = g.y - h } })
	else
		local m = C.minimap
		ns.Register(bar, m.x + m.size - w, m.y + m.size + 6 + ns.TopInset(), { key = 'markers', w = w, h = h, side = 'RIGHT' })
	end
end

local function UpdateTarget()
	local index = UnitExists('target') and GetRaidTargetIndex('target')
	if issecretvalue(index) then return end
	for i, b in ipairs(targets) do b.edge:SetShown(index == i) end
end

local function UpdateLeader()
	if InCombatLockdown() then
		bar.leaderPending = true
		return
	end
	local lead = UnitIsGroupLeader('player') or (IsInRaid() and UnitIsGroupAssistant('player'))
	for _, b in pairs(utility) do b:SetShown(lead and true or false) end
end
ns.UpdateMarkerLeader = UpdateLeader

ns.On('PLAYER_LOGIN', function()
	if not C.modules.markers then return end
	local w, h = Build()
	Position(w, h)
	RegisterStateDriver(bar, 'visibility', '[group] show; hide')
	UpdateTarget()
	UpdateLeader()
	ns.On('PLAYER_TARGET_CHANGED', UpdateTarget)
	ns.On('RAID_TARGET_UPDATE', UpdateTarget)
	ns.On('GROUP_ROSTER_UPDATE', UpdateLeader)
	ns.On('PARTY_LEADER_CHANGED', UpdateLeader)
	ns.On('PLAYER_REGEN_ENABLED', function()
		if bar.leaderPending then
			bar.leaderPending = nil
			UpdateLeader()
		end
	end)
end)
