local addonName, ns = ...
local C = ns.C

ns.TEX = [[Interface\Buttons\WHITE8x8]]
ns.FONT = [[Interface\AddOns\SlimARK-UI\Media\SlimARK.ttf]]
ns.FONT_NAME = 'SlimARK'
ns.SOFT_NAME = 'SlimARK Soft'
ns.SOFT = [[Interface\AddOns\SlimARK-UI\Media\Soft.tga]]

-- 3.1.1: the SlimARK font has Latin letters only, so a Cyrillic, Korean or Chinese name showed as
-- boxes. Text goes through a font family instead: the game draws each string with the member of its
-- alphabet, so Latin text keeps the SlimARK font and the other scripts take Blizzard's own faces
-- (the same files Blizzard's font families use). A family is made once per size and flags. A
-- string must take its family from its first font write: a plain SetFont pins its face for good.
local FAMILY = {
	{ 'roman' },
	{ 'russian', [[Fonts\FRIZQT___CYR.TTF]] },
	{ 'korean', [[Fonts\2002.TTF]] },
	{ 'simplifiedchinese', [[Fonts\ARKai_T.ttf]] },
	{ 'traditionalchinese', [[Fonts\blei00d.TTF]] },
}
local families, familyCount = {}, 0

-- The family of the SlimARK font at this size and flags, or nil where the client cannot make one.
-- A tag gives a family of its own (one whose shadow is set on the family itself).
function ns.FontFamily(size, flags, tag)
	flags = flags or ''
	local key = tostring(size) .. '|' .. flags .. '|' .. (tag or '')
	local family = families[key]
	if family == nil then
		family = false
		if CreateFontFamily then
			local members = {}
			for i, member in ipairs(FAMILY) do
				members[i] = { alphabet = member[1], file = member[2] or ns.FONT, height = size, flags = flags }
			end
			familyCount = familyCount + 1
			local ok, made = pcall(CreateFontFamily, 'SlimARKFont' .. familyCount, members)
			family = ok and made or false
		end
		families[key] = family
	end
	return family or nil
end

-- The SlimARK font on a font string or edit box, with Blizzard's faces for the other scripts.
function ns.SetFont(object, size, flags)
	local family = object.SetFontObject and ns.FontFamily(size, flags)
	if family then
		object:SetFontObject(family)
	else
		object:SetFont(ns.FONT, size, flags or '')
	end
end

local handlers = {}
local driver = CreateFrame('Frame')
-- Every module's callback runs on its own: an error goes to the game's error handler (or BugSack)
-- and the other modules still get the event. WoW's xpcall hands the extra arguments on, the way
-- Blizzard's own FunctionUtil.lua calls scripts.
driver:SetScript('OnEvent', function(_, event, ...)
	local onError = geterrorhandler()
	for _, fn in ipairs(handlers[event]) do
		xpcall(fn, onError, event, ...)
	end
end)

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		driver:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

-- The layout is drawn for 2560x1600. On another screen it is scaled with the
-- screen (the smaller of the two ratios), the edge groups stay at their edge and
-- the rest stays in the middle. Read from the real screen size, nothing to choose.
local BASE_W, BASE_H = 2560, 1600

-- 12.1: the encounter state lives in C_InstanceEncounter; the old global is a deprecated fallback.
function ns.InEncounter()
	local inProgress = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress
	return inProgress ~= nil and inProgress() == true
end

function ns.Fit()
	local width, height = GetPhysicalScreenSize()
	return math.min(width / BASE_W, height / BASE_H)
end

-- The multiplier that makes 1 unit of the frame exactly ns.Fit() physical pixels
-- (one pixel on a 2560x1600 screen).
function ns.Scale()
	local _, height = GetPhysicalScreenSize()
	return (768 / height) / UIParent:GetEffectiveScale() * ns.Fit()
end

-- A thin border width in frame units: never thinner than one physical pixel.
function ns.Px()
	local fit = ns.Fit()
	return fit < 1 and 1 / fit or 1
end

-- The screen size in layout units, and the room it has beyond 2560x1600.
local function Spare()
	local width, height = GetPhysicalScreenSize()
	local fit = ns.Fit()
	return width / fit - BASE_W, height / fit - BASE_H
end

-- A layout x on this screen. side: 'LEFT' and 'RIGHT' stay at that edge, anything else stays centered.
function ns.FitX(x, side)
	local spare = Spare()
	if side == 'LEFT' then return x end
	if side == 'RIGHT' then return x + spare end
	return x + spare / 2
end

-- A layout y on this screen (only screens narrower than 16:10 have room here).
-- The top third stays at the top, the bottom third at the bottom, the middle in the middle.
function ns.FitY(y, h)
	local _, spare = Spare()
	local middle = y + (h or 0) / 2
	if middle < BASE_H / 3 then return y end
	if middle > BASE_H * 2 / 3 then return y + spare end
	return y + spare / 2
end

-- How far the elements at the top of the screen move down: the height of the top bar when it is on.
function ns.TopInset()
	return C.modules.databar and C.databar.h or 0
end

-- The screen height in layout units.
function ns.ScreenHeight()
	local _, height = GetPhysicalScreenSize()
	return height / ns.Fit()
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
		local x, y
		if saved and saved.x then
			-- Dragged positions are kept in physical pixels of this screen.
			local fit = ns.Fit()
			x, y = saved.x / fit, saved.y / fit
		else
			local base = ns.healer and item.heal or item
			local w = item.w or item.frame:GetWidth()
			local h = item.h or item.frame:GetHeight()
			-- The vertical group is decided by the top edge, a BOTTOMLEFT y is the bottom.
			local top = item.point == 'BOTTOMLEFT' and base.y - h or base.y
			x = ns.FitX(base.x, item.side)
			y = base.y + ns.FitY(top, h) - top
		end
		frame:SetPoint(item.point or 'TOPLEFT', UIParent, 'TOPLEFT', x / size, -y / size)
	end
end

-- opts.key: draggable in Edit Mode. opts.w, opts.h: size of the box with an empty header.
-- opts.after, opts.owner: goes under the previous frame and follows its size.
-- opts.heal: position in the healer layout. opts.point: which point of the frame the x, y refers to.
-- opts.forHealer: exists in only one of the roles, not draggable in the other.
-- opts.side: 'LEFT' or 'RIGHT' keeps it at that screen edge on wider screens, otherwise it stays centered.
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
	local px = ns.Px()
	t:SetPoint('TOPLEFT', -px, px)
	t:SetPoint('BOTTOMRIGHT', px, -px)
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
	thickness = thickness * ns.Px()
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

-- Shields (damage absorbs) on a health bar, in light stripes. The part that fits
-- in the missing health follows the health; what does not fit is drawn from the
-- right edge back over the health, with a bright line at the edge. Damage takes the
-- striped part first. The amounts are the game's own (secret in combat), the bars
-- take them as they are.
local SHIELD_FILL = [[Interface\RaidFrame\Shield-Fill]]
local SHIELD_STRIPES = [[Interface\RaidFrame\Shield-Overlay]]

local function ShieldBar(health, color)
	local bar = CreateFrame('StatusBar', nil, health)
	bar:SetFrameLevel(health:GetFrameLevel() + 1)
	bar:SetStatusBarTexture(SHIELD_FILL)
	bar:SetStatusBarColor(color[1], color[2], color[3], 0.35)
	bar:SetPoint('TOP')
	bar:SetPoint('BOTTOM')
	local stripes = bar:CreateTexture(nil, 'ARTWORK', nil, 1)
	stripes:SetTexture(SHIELD_STRIPES, 'REPEAT', 'REPEAT')
	stripes:SetHorizTile(true)
	stripes:SetVertTile(true)
	stripes:SetVertexColor(color[1], color[2], color[3], 0.9)
	stripes:SetAllPoints(bar:GetStatusBarTexture())
	return bar
end

-- The test mode draws its own shields with the same look.
ns.ShieldBar = ShieldBar

function ns.AddShield(health)
	if not C.features.shields then return end
	local color = C.colors.shield

	-- oUF fills this one, clamped to the missing health. With incoming heals on the bar it starts
	-- after them and fits in what the heals leave free.
	local after = ShieldBar(health, color)
	if health.HealingAll then
		after:SetPoint('LEFT', health.HealingAll:GetStatusBarTexture(), 'RIGHT')
		health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MissingHealth
	else
		after:SetPoint('LEFT', health:GetStatusBarTexture(), 'RIGHT')
		health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals
	end
	after:SetWidth(health:GetWidth())
	health.DamageAbsorb = after

	-- The whole shield from the right edge, shown only when it does not fit.
	local over = ShieldBar(health, color)
	over:SetPoint('LEFT')
	over:SetPoint('RIGHT')
	over:SetReverseFill(true)
	over:SetAlpha(0)
	local edge = over:CreateTexture(nil, 'OVERLAY', nil, 2)
	edge:SetColorTexture(1, 1, 1, 1)
	edge:SetWidth(2)
	edge:SetPoint('TOPRIGHT')
	edge:SetPoint('BOTTOMRIGHT')

	local whole = CreateUnitHealPredictionCalculator()
	whole:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
	local function Overflow(element, unit)
		UnitGetDetailedHealPrediction(unit, 'player', whole)
		over:SetMinMaxValues(0, (whole:GetMaximumHealth()))
		-- GetDamageAbsorbs returns two values; the second one must not reach SetValue's interpolation slot.
		local amount = whole:GetDamageAbsorbs()
		over:SetValue(amount)
		local _, clamped = element.values:GetDamageAbsorbs()
		over:SetAlphaFromBoolean(clamped, 1, 0)
	end
	local post = health.PostUpdate
	health.PostUpdate = function(element, unit, ...)
		-- A shield error must never stop oUF before it colors the bar.
		if element.values and not pcall(Overflow, element, unit) then over:SetAlpha(0) end
		if post then return post(element, unit, ...) end
	end
end

-- Incoming heals after the health (pale green, never past the end of the bar) and heal absorbs
-- (debuffs that eat healing) in dark red stripes at the end of the health. The amounts are the
-- game's own (secret in combat); oUF hands them to the bars. Call it before ns.AddShield.
function ns.AddPrediction(health)
	if not C.features.healPrediction then return end
	local c = C.colors.incomingHeal
	local heal = CreateFrame('StatusBar', nil, health)
	heal:SetFrameLevel(health:GetFrameLevel() + 1)
	heal:SetStatusBarTexture(ns.TEX)
	heal:SetStatusBarColor(c[1], c[2], c[3], c[4] or 0.5)
	heal:SetPoint('TOP')
	heal:SetPoint('BOTTOM')
	heal:SetPoint('LEFT', health:GetStatusBarTexture(), 'RIGHT')
	heal:SetWidth(health:GetWidth())
	health.HealingAll = heal
	health.incomingHealOverflow = 1

	local a = C.colors.healAbsorb
	local absorb = CreateFrame('StatusBar', nil, health)
	absorb:SetFrameLevel(health:GetFrameLevel() + 1)
	absorb:SetStatusBarTexture(SHIELD_FILL)
	absorb:SetStatusBarColor(a[1], a[2], a[3], 0.6)
	absorb:SetReverseFill(true)
	absorb:SetPoint('TOP')
	absorb:SetPoint('BOTTOM')
	absorb:SetPoint('RIGHT', health:GetStatusBarTexture(), 'RIGHT')
	absorb:SetWidth(health:GetWidth())
	local stripes = absorb:CreateTexture(nil, 'ARTWORK', nil, 1)
	stripes:SetTexture(SHIELD_STRIPES, 'REPEAT', 'REPEAT')
	stripes:SetHorizTile(true)
	stripes:SetVertTile(true)
	stripes:SetVertexColor(a[1] * 0.5, a[2] * 0.5, a[3] * 0.5, 1)
	stripes:SetAllPoints(absorb:GetStatusBarTexture())
	health.HealAbsorb = absorb
	health.healAbsorbClampMode = Enum.UnitHealAbsorbClampMode.CurrentHealth
end

-- Texts and icons of a health bar go on this layer, above the shield.
function ns.TextLayer(health)
	local layer = CreateFrame('Frame', nil, health)
	layer:SetAllPoints()
	layer:SetFrameLevel(health:GetFrameLevel() + 2)
	return layer
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
	ns.SetFont(fs, size, 'OUTLINE')
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
		-- 1.4.0 put the top bar on the top row: an old dragged minimap or M+ panel would sit under it.
		if ns.CharDB.layoutRev < 4 then
			for _, store in ipairs({ ns.CharDB.pos or {}, ns.CharDB.posHeal or {} }) do
				store.minimap, store.mythicplus = nil, nil
			end
			ns.CharDB.layoutRev = 4
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

-- /slimark opens the settings panel, /slimark apply writes every position and skin,
-- /slimark test [party|raid|raid40|mplus|healer|dps|off] switches the test mode.
SLASH_SLIMARK1 = '/slimark'
SlashCmdList.SLIMARK = function(msg)
	local cmd, arg = strtrim(msg or ''):lower():match('^(%S*)%s*(%S*)')
	local TEST = { party = 'party', raid = 'raid20', raid20 = 'raid20', raid40 = 'raid40', mplus = 'mplus', ['m+'] = 'mplus', off = 'off' }
	if cmd == 'apply' then
		ns.ApplyAll()
	elseif cmd == 'test' and ns.SetTestMode then
		if arg == 'healer' or arg == 'dps' then
			ns.SetTestLayout(arg == 'healer' and 'heal' or 'dps')
		else
			ns.SetTestMode(TEST[arg] or ((ns.TestMode.mode == 'off') and 'party' or 'off'))
		end
	elseif ns.OpenSettings then
		ns.OpenSettings()
	end
end

SLASH_SLIMARKRELOAD1 = '/rl'
SlashCmdList.SLIMARKRELOAD = function() ReloadUI() end
