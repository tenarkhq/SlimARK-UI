local addonName, ns = ...
local C = ns.C

ns.TEX = [[Interface\Buttons\WHITE8x8]]
ns.FONT = [[Interface\AddOns\SlimARK-UI\Media\SlimARK.ttf]]
ns.FONT_NAME = 'SlimARK'
ns.SOFT_NAME = 'SlimARK Soft'
ns.SOFT = [[Interface\AddOns\SlimARK-UI\Media\Soft.tga]]

local handlers = {}
local driver = CreateFrame('Frame')
driver:SetScript('OnEvent', function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		fn(event, ...)
	end
end)

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		driver:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

-- The multiplier that makes 1 unit of the frame exactly 1 physical pixel.
function ns.Scale()
	local _, height = GetPhysicalScreenSize()
	return (768 / height) / UIParent:GetEffectiveScale()
end

ns.Placed = {}
-- True in a healer spec. Set by Role.lua.
ns.healer = false

-- The two layouts record dragged positions separately. What does not move with the role is shared.
function ns.PosStore(item, create)
	local owner = item.owner or item
	if not ns.CharDB then return end
	local name = ns.healer and owner.heal and 'posHeal' or 'pos'
	if create then ns.CharDB[name] = ns.CharDB[name] or {} end
	return ns.CharDB[name]
end

-- The saved position and size come from dragging in Edit Mode, without them Config.lua applies.
function ns.Saved(item)
	local owner = item.owner or item
	local store = ns.PosStore(item)
	return owner.key and store and store[owner.key]
end

-- Puts the element in its place. Another frame can be given too, like the Edit Mode box.
function ns.Place(item, frame)
	local saved = ns.Saved(item)
	local size = saved and saved.scale or 1
	frame = frame or item.frame
	frame:SetScale(ns.Scale() * size)
	frame:ClearAllPoints()
	if item.after and frame == item.frame then
		frame:SetPoint('TOPLEFT', item.after, 'BOTTOMLEFT', 0, -item.gap)
	else
		local base = ns.healer and item.heal or item
		local x = saved and saved.x or base.x
		local y = saved and saved.y or base.y
		frame:SetPoint(item.point or 'TOPLEFT', UIParent, 'TOPLEFT', x / size, -y / size)
	end
end

-- opts.key: draggable in Edit Mode. opts.w, opts.h: size of the box with an empty header.
-- opts.after, opts.owner: goes under the previous frame and follows its size.
-- opts.heal: position in the healer layout. opts.point: which point of the frame the x, y refers to.
-- opts.forHealer: exists in only one of the roles, not draggable in the other.
function ns.Register(frame, x, y, opts)
	local item = opts or {}
	item.frame, item.x, item.y = frame, x, y
	table.insert(ns.Placed, item)
	ns.Place(item)
	return item
end

local function Rescale()
	if InCombatLockdown() then
		ns.rescalePending = true
		return
	end
	for _, item in ipairs(ns.Placed) do
		ns.Place(item)
	end
end

ns.On('UI_SCALE_CHANGED', Rescale)
ns.On('DISPLAY_SIZE_CHANGED', Rescale)
ns.On('PLAYER_REGEN_ENABLED', function()
	if ns.rescalePending then
		ns.rescalePending = nil
		Rescale()
	end
end)

-- Black 1 px border around the frame.
function ns.Outline(frame)
	local t = frame:CreateTexture(nil, 'BACKGROUND', nil, -8)
	t:SetColorTexture(0, 0, 0, 1)
	t:SetPoint('TOPLEFT', -1, 1)
	t:SetPoint('BOTTOMRIGHT', 1, -1)
	return t
end

function ns.Track(frame)
	local t = frame:CreateTexture(nil, 'BACKGROUND')
	t:SetAllPoints()
	t:SetColorTexture(C.colors.track[1], C.colors.track[2], C.colors.track[3], 1)
	return t
end

-- Colored border with an empty center on its own frame, so it can be switched on and off as one.
function ns.Edge(parent, thickness, color, outset, anchor)
	local f = CreateFrame('Frame', nil, parent)
	anchor = anchor or parent
	f:SetPoint('TOPLEFT', anchor, 'TOPLEFT', -outset, outset)
	f:SetPoint('BOTTOMRIGHT', anchor, 'BOTTOMRIGHT', outset, -outset)
	f:SetFrameLevel(parent:GetFrameLevel() + 10)
	local function side(p1, p2, w, h)
		local t = f:CreateTexture(nil, 'OVERLAY')
		t:SetColorTexture(color[1], color[2], color[3], 1)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
	end
	side('TOPLEFT', 'TOPRIGHT', nil, thickness)
	side('BOTTOMLEFT', 'BOTTOMRIGHT', nil, thickness)
	side('TOPLEFT', 'BOTTOMLEFT', thickness, nil)
	side('TOPRIGHT', 'BOTTOMRIGHT', thickness, nil)
	return f
end

-- Soft glow on the bar: lighter on top, darker at the bottom. The text stays below it.
function ns.Gloss(bar)
	local top = bar:CreateTexture(nil, 'OVERLAY', nil, 1)
	top:SetTexture(ns.TEX)
	top:SetPoint('TOPLEFT')
	top:SetPoint('BOTTOMRIGHT', bar, 'RIGHT')
	top:SetGradient('VERTICAL', CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.22))

	local bottom = bar:CreateTexture(nil, 'OVERLAY', nil, 1)
	bottom:SetTexture(ns.TEX)
	bottom:SetPoint('TOPLEFT', bar, 'LEFT')
	bottom:SetPoint('BOTTOMRIGHT')
	bottom:SetGradient('VERTICAL', CreateColor(0, 0, 0, 0.4), CreateColor(0, 0, 0, 0))
end

function ns.Text(parent, size, justify)
	local fs = parent:CreateFontString(nil, 'OVERLAY', nil, 7)
	fs:SetFont(ns.FONT, size, 'OUTLINE')
	fs:SetShadowOffset(0, 0)
	fs:SetJustifyH(justify or 'LEFT')
	fs:SetWordWrap(false)
	return fs
end

-- Disables a Blizzard frame, the same way oUF does with its own.
function ns.Block(frame)
	if frame then
		frame:UnregisterAllEvents()
		frame:SetRolesets('alwaysBlocked')
	end
end

function ns.Print(text)
	print('|cfff2b84bSlimARK-UI|r ' .. text)
end

ns.version = C_AddOns.GetAddOnMetadata(addonName, 'Version') or '?'

ns.On('ADDON_LOADED', function(_, name)
	if name == addonName then
		SlimARKCharDB = SlimARKCharDB or {}
		ns.CharDB = SlimARKCharDB
		-- 1.1.0 moved the party frames next to the character: an old dragged spot would hide that.
		if (ns.CharDB.layoutRev or 0) < 3 then
			if ns.CharDB.pos then ns.CharDB.pos.party = nil end
			ns.CharDB.layoutRev = 3
		end
		-- Shared by every character: seen cutscenes, remembered caster mobs.
		SlimARKDB = SlimARKDB or {}
		SlimARKDB.seenMovies = SlimARKDB.seenMovies or {}
		SlimARKDB.seenCinematics = SlimARKDB.seenCinematics or {}
		SlimARKDB.casters = SlimARKDB.casters or {}
		ns.DB = SlimARKDB
	end
end)

ns.On('PLAYER_LOGIN', function()
	if not C.features.loginMessage then return end
	ns.Print(ns.version .. ' loaded. /slimark opens the settings, /slimark apply sets up the layout.')
end)

-- /slimark opens the settings panel, /slimark apply writes every position and skin.
SLASH_SLIMARK1 = '/slimark'
SlashCmdList.SLIMARK = function(msg)
	if strtrim(msg or ''):lower() == 'apply' then
		ns.ApplyAll()
	elseif ns.OpenSettings then
		ns.OpenSettings()
	end
end

SLASH_SLIMARKRELOAD1 = '/rl'
SlashCmdList.SLIMARKRELOAD = function() ReloadUI() end
