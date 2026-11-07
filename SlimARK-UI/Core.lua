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

-- Az a szorzó, amivel a keret 1 egysége pontosan 1 fizikai képpont lesz.
function ns.Scale()
	local _, height = GetPhysicalScreenSize()
	return (768 / height) / UIParent:GetEffectiveScale()
end

ns.Placed = {}

-- A mentett pozíció és méret az Edit Mode húzásából jön, enélkül a Config.lua számít.
function ns.Saved(item)
	local owner = item.owner or item
	return owner.key and ns.CharDB and ns.CharDB.pos and ns.CharDB.pos[owner.key]
end

-- A helyére teszi az elemet. Más frame is megadható, ilyen az Edit Mode doboza.
function ns.Place(item, frame)
	local saved = ns.Saved(item)
	local size = saved and saved.scale or 1
	frame = frame or item.frame
	frame:SetScale(ns.Scale() * size)
	frame:ClearAllPoints()
	if item.after and frame == item.frame then
		frame:SetPoint('TOPLEFT', item.after, 'BOTTOMLEFT', 0, -item.gap)
	else
		local x = saved and saved.x or item.x
		local y = saved and saved.y or item.y
		frame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', x / size, -y / size)
	end
end

-- opts.key: húzható az Edit Mode-ban. opts.w, opts.h: a doboz mérete üres fejlécnél.
-- opts.after, opts.owner: az előző keret alá kerül, annak a méretét követi.
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

-- Fekete 1 px-es keret a frame köré.
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

-- Üres közepű színes keret saját frame-en, hogy egyben lehessen ki-be kapcsolni.
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

-- Puha fény a sávon: felül világosodik, alul sötétedik. A szöveg alatta marad.
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

-- Blizzard keret kikapcsolása, ugyanúgy, ahogy az oUF teszi a sajátjaival.
function ns.Block(frame)
	if frame then
		frame:UnregisterAllEvents()
		frame:SetRolesets('alwaysBlocked')
	end
end

function ns.Print(text)
	print('|cfff2b84bSlimARK-UI|r ' .. text)
end

ns.On('ADDON_LOADED', function(_, name)
	if name == addonName then
		SlimARKCharDB = SlimARKCharDB or {}
		ns.CharDB = SlimARKCharDB
	end
end)

SLASH_SLIMARK1 = '/slim'
SlashCmdList.SLIMARK = function(msg)
	if msg == 'apply' then
		ns.ApplyAll()
	else
		ns.Print('/slim apply: beállít minden pozíciót és skint, majd újratölti a felületet. A régi profilokhoz és layoutokhoz nem nyúl.')
	end
end

SLASH_SLIMARKRELOAD1 = '/rl'
SlashCmdList.SLIMARKRELOAD = function() ReloadUI() end
