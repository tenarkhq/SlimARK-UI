local _, ns = ...
local C = ns.C

-- Test mode: made-up players fill the frames, so the party, the raid and Mythic+ can be seen
-- without a group. The made-up frames are plain frames of their own, drawn like the real ones
-- and pinned onto the real frames' places, so they follow Edit Mode and never touch the secure
-- group frames. Combat or a reload ends it.
local state = { mode = 'off', layout = nil }
ns.TestMode = state

local MODES = { off = 'Off', party = 'Party', raid20 = 'Raid 20', raid40 = 'Raid 40', mplus = 'Mythic+' }

-- The made-up roster: name, class, role. The first raid group has a tank and a healer, like a real one.
local ROSTER = {
	{ 'Brakk', 'WARRIOR', 'TANK' }, { 'Lysara', 'PRIEST', 'HEALER' }, { 'Venrik', 'MAGE', 'DAMAGER' }, { 'Shade', 'ROGUE', 'DAMAGER' },
	{ 'Korra', 'HUNTER', 'DAMAGER' }, { 'Thornwyn', 'DRUID', 'HEALER' }, { 'Grimvald', 'DEATHKNIGHT', 'TANK' }, { 'Elune', 'SHAMAN', 'HEALER' },
	{ 'Mordrek', 'WARLOCK', 'DAMAGER' }, { 'Jinzo', 'MONK', 'DAMAGER' }, { 'Vyx', 'DEMONHUNTER', 'DAMAGER' }, { 'Sereth', 'EVOKER', 'DAMAGER' },
	{ 'Halvar', 'WARRIOR', 'DAMAGER' }, { 'Nimue', 'MAGE', 'DAMAGER' }, { 'Ashka', 'HUNTER', 'DAMAGER' }, { 'Torin', 'PALADIN', 'DAMAGER' },
	{ 'Qiri', 'MONK', 'HEALER' }, { 'Draven', 'DEATHKNIGHT', 'DAMAGER' }, { 'Lumi', 'PRIEST', 'DAMAGER' }, { 'Okoro', 'SHAMAN', 'DAMAGER' },
	{ 'Fenwick', 'DRUID', 'DAMAGER' }, { 'Rhyse', 'ROGUE', 'DAMAGER' }, { 'Ilsa', 'EVOKER', 'HEALER' }, { 'Garrok', 'WARRIOR', 'DAMAGER' },
	{ 'Selwyn', 'PALADIN', 'HEALER' }, { 'Tamsin', 'WARLOCK', 'DAMAGER' }, { 'Kael', 'MAGE', 'DAMAGER' }, { 'Brunhild', 'DEATHKNIGHT', 'DAMAGER' },
	{ 'Oren', 'HUNTER', 'DAMAGER' }, { 'Wren', 'DEMONHUNTER', 'DAMAGER' }, { 'Mako', 'MONK', 'DAMAGER' }, { 'Isolde', 'PRIEST', 'HEALER' },
	{ 'Durgan', 'SHAMAN', 'DAMAGER' }, { 'Faye', 'DRUID', 'DAMAGER' }, { 'Corvin', 'ROGUE', 'DAMAGER' }, { 'Yara', 'EVOKER', 'DAMAGER' },
	{ 'Bastian', 'PALADIN', 'DAMAGER' }, { 'Nerys', 'WARLOCK', 'DAMAGER' }, { 'Holt', 'WARRIOR', 'DAMAGER' }, { 'Pip', 'MAGE', 'DAMAGER' },
}
local HEALTH = { 100, 87.4, 64.2, 100, 41.8, 92.1, 100, 23.6, 78.9, 100, 55.5, 100, 96.3 }
-- Icons of real spells, so the pictures are the game's own: a debuff, a magic debuff and a defensive.
local DEBUFF, MAGIC, DEFENSIVE = 589, 118, 33206

local function Member(i)
	local r = ROSTER[(i - 1) % #ROSTER + 1]
	return {
		name = r[1], class = r[2], role = r[3],
		hp = HEALTH[(i - 1) % #HEALTH + 1],
		shield = i % 7 == 3 and 30 or nil,
		magic = i % 9 == 5,
		debuff = i % 4 == 2,
		defensive = i % 6 == 1,
		dead = i % 13 == 12,
	}
end

local function You()
	local _, class = UnitClass('player')
	local _, role = ns.SpecInfo and ns.SpecInfo()
	if ns.healer then role = 'HEALER' elseif role == 'HEALER' then role = 'DAMAGER' end
	return { name = UnitName('player'), class = class, role = role or 'DAMAGER', hp = 100 }
end

local function ClassColor(class)
	local c = (C_ClassColor and C_ClassColor.GetClassColor(class)) or RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.6, 0.6, 0.6
end

local function SpellIcon(id)
	return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400
end

------------------------------------------------------------------------
-- A made-up unit frame, drawn like the real one of that kind.
------------------------------------------------------------------------
local function Bar(parent)
	local bar = CreateFrame('StatusBar', nil, parent)
	bar:SetStatusBarTexture(ns.TEX)
	bar:SetMinMaxValues(0, 100)
	ns.Track(bar)
	ns.Gloss(bar)
	return bar
end

local function Icon(parent, size)
	local f = CreateFrame('Frame', nil, parent)
	f:SetSize(size, size)
	ns.Outline(f)
	f.tex = f:CreateTexture(nil, 'ARTWORK')
	f.tex:SetAllPoints()
	f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	return f
end

local function Castbar(parent, width, color, fontSize)
	local cb = Bar(parent)
	cb:SetSize(width, 24)
	cb:SetStatusBarColor(color[1], color[2], color[3])
	ns.Outline(cb)
	cb.Text = ns.Text(cb, fontSize)
	cb.Text:SetPoint('LEFT', 6, 0)
	cb.Time = ns.Text(cb, fontSize, 'RIGHT')
	cb.Time:SetPoint('RIGHT', -6, 0)
	return cb
end

local function Mock(kind)
	local o = C.units[kind]
	local f = CreateFrame('Frame', nil, UIParent)
	-- Its parts live in a plain table of their own.
	f.ui = {}
	f:SetFrameStrata('MEDIUM')
	f:SetFrameLevel(20)
	f:SetSize(o.w, o.h)
	f:Hide()
	f.ui.kind = kind
	ns.Outline(f)
	local bottom = 0
	if kind == 'party' then
		f.ui.power = Bar(f)
		f.ui.power:SetHeight(6)
		f.ui.power:SetPoint('BOTTOMLEFT')
		f.ui.power:SetPoint('BOTTOMRIGHT')
		bottom = 7
	end
	local health = Bar(f)
	health:SetPoint('TOPLEFT')
	health:SetPoint('BOTTOMRIGHT', 0, bottom)
	f.ui.health = health
	if C.features.shields and ns.ShieldBar then
		f.ui.shield = ns.ShieldBar(health, C.colors.shield)
		f.ui.shield:SetPoint('LEFT', health:GetStatusBarTexture(), 'RIGHT')
		f.ui.shield:SetMinMaxValues(0, 100)
	end
	local texts = ns.TextLayer(health)
	f.ui.name = ns.Text(texts, o.font)
	f.ui.value = ns.Text(texts, o.font, 'RIGHT')
	local group = kind == 'party' or kind == 'raid' or kind == 'grid'
	if kind == 'boss' then
		f.ui.name:SetPoint('TOPLEFT', 5, -3)
		f.ui.name:SetPoint('RIGHT', -5, 0)
		f.ui.current = ns.Text(texts, 24, 'CENTER')
		f.ui.current:SetPoint('CENTER', 0, -5)
		f.ui.value:SetPoint('BOTTOMRIGHT', -5, 3)
		f.ui.cast = Castbar(f, 200, C.colors.enemyCast, 16)
		f.ui.cast:SetPoint('RIGHT', f, 'LEFT', -5, 0)
	elseif kind == 'party' or kind == 'grid' then
		f.ui.value:SetPoint('TOPRIGHT', -5, -3)
		f.ui.name:SetPoint('TOPLEFT', o.font + 7, -3)
		f.ui.name:SetPoint('TOPRIGHT', f.ui.value, 'TOPLEFT', -4, 0)
	elseif kind == 'raid' then
		f.ui.name:SetPoint('TOPLEFT', o.font + 7, -3)
		f.ui.name:SetPoint('RIGHT', -4, 0)
		f.ui.value:SetFont(ns.FONT, 14, 'OUTLINE')
		f.ui.value:SetPoint('BOTTOMRIGHT', -3, 2)
	else
		f.ui.name:SetPoint('LEFT', 6, 0)
		if kind == 'target' or kind == 'focus' then
			f.ui.value:SetPoint('RIGHT', -6, 0)
			f.ui.name:SetPoint('RIGHT', f.ui.value, 'LEFT', -6, 0)
			f.ui.cast = Castbar(f, o.w, C.colors.enemyCast, 17)
			f.ui.cast:SetPoint('TOPLEFT', f, 'BOTTOMLEFT', 0, -4)
		else
			f.ui.name:SetPoint('RIGHT', -4, 0)
		end
	end
	if group then
		f.ui.role = texts:CreateTexture(nil, 'OVERLAY', nil, 7)
		f.ui.role:SetSize(o.font + 2, o.font + 2)
		f.ui.role:SetPoint('TOPLEFT', 3, -3)
		f.ui.debuffs = {}
		for i = 1, 2 do
			local icon = Icon(texts, o.debuff)
			icon:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT', -1 - (i - 1) * (o.debuff + 1), 1)
			f.ui.debuffs[i] = icon
		end
		f.ui.defensive = Icon(texts, o.defensive)
		f.ui.defensive:SetPoint('BOTTOMLEFT', health, 'BOTTOMLEFT', 1, 1)
		f.ui.defensive.time = ns.Text(f.ui.defensive, 15, 'CENTER')
		f.ui.defensive.time:SetPoint('CENTER')
		f.ui.dispel = ns.Edge(f, 2, { 0.2, 0.6, 1 }, 0)
	end
	return f
end

local ROLE_ATLAS = { TANK = 'UI-LFG-RoleIcon-Tank-Micro-Raid', HEALER = 'UI-LFG-RoleIcon-Healer-Micro-Raid', DAMAGER = 'UI-LFG-RoleIcon-DPS-Micro-Raid' }

local function Fill(f, u)
	local r, g, b = 0.78, 0.18, 0.2
	if not u.hostile then r, g, b = ClassColor(u.class) end
	f.ui.health:SetStatusBarColor(r, g, b)
	f.ui.health:SetValue(u.dead and 0 or u.hp)
	if f.ui.power then
		f.ui.power:SetStatusBarColor(0, 0.55, 1)
		f.ui.power:SetValue(u.dead and 0 or 80)
	end
	if f.ui.shield then
		f.ui.shield:SetWidth(f.ui.health:GetWidth())
		f.ui.shield:SetValue(u.shield and not u.dead and math.min(u.shield, 100 - u.hp) or 0)
	end
	f.ui.name:SetText(u.name)
	local kind = f.ui.kind
	if kind == 'boss' then
		f.ui.current:SetText(u.dead and '' or AbbreviateNumbers(math.floor(u.hp * 1240000)))
		f.ui.value:SetText(('%d%%'):format(math.floor(u.hp)))
	elseif kind == 'party' or kind == 'grid' then
		f.ui.value:SetText(u.dead and 'Dead' or ('%.1f%%'):format(u.hp))
	elseif kind == 'raid' then
		f.ui.value:SetText(u.dead and 'Dead' or '')
	elseif kind == 'target' then
		f.ui.value:SetText(('%s · %d%%'):format(AbbreviateNumbers(math.floor(u.hp * 98000)), math.floor(u.hp)))
	elseif kind == 'focus' then
		f.ui.value:SetText(('%d%%'):format(math.floor(u.hp)))
	end
	if f.ui.cast then
		f.ui.cast:SetShown(u.cast ~= nil)
		if u.cast then
			f.ui.cast:SetValue(u.castValue or 60)
			f.ui.cast.Text:SetText(u.cast)
			f.ui.cast.Time:SetText(u.castTime or '1.2')
			local c = u.important and C.colors.important or C.colors.enemyCast
			f.ui.cast:SetStatusBarColor(c[1], c[2], c[3])
		end
	end
	if f.ui.role then
		f.ui.role:SetShown(C.features.roleIcon and u.role ~= nil)
		if u.role then f.ui.role:SetAtlas(ROLE_ATLAS[u.role]) end
		local debuffs = {}
		if u.magic then table.insert(debuffs, MAGIC) end
		if u.debuff then table.insert(debuffs, DEBUFF) end
		for i, icon in ipairs(f.ui.debuffs) do
			local id = not u.dead and debuffs[i]
			icon:SetShown(id and true or false)
			if id then icon.tex:SetTexture(SpellIcon(id)) end
		end
		f.ui.defensive:SetShown(u.defensive and not u.dead or false)
		f.ui.defensive.tex:SetTexture(SpellIcon(DEFENSIVE))
		f.ui.defensive.time:SetText('6')
		f.ui.dispel:SetShown(C.features.dispelGlow and u.magic and not u.dead or false)
	end
	f:Show()
end

------------------------------------------------------------------------
-- Placing: every made-up frame sits on the place of a real frame, at its scale.
------------------------------------------------------------------------
local mocks = {}
local function Get(key, kind)
	mocks[key] = mocks[key] or Mock(kind)
	return mocks[key]
end

local function Match(f, real)
	f:SetScale(real:GetEffectiveScale() / UIParent:GetEffectiveScale())
end

local function OnFrame(key, kind, real, u)
	if not real then return end
	local f = Get(key, kind)
	Match(f, real)
	f:ClearAllPoints()
	f:SetPoint('TOPLEFT', real, 'TOPLEFT', 0, 0)
	Fill(f, u)
end

-- Without a group the real header is hidden and has no size, so nothing anchored to it is
-- drawn. A plain frame takes the header's place and size, the made-up frames hang on it.
local proxies = {}
state.proxies = proxies
local function Proxy(header)
	for _, item in ipairs(ns.Placed) do
		if item.frame == header then
			local p = proxies[header] or CreateFrame('Frame', nil, UIParent)
			proxies[header] = p
			p:SetSize(item.w, item.h)
			ns.Place(item, p)
			return p
		end
	end
end

-- The group header lays its frames out the same way as the real header does.
local function OnHeader(prefix, kind, header, units, perRow, upward)
	header = header and Proxy(header)
	if not header then return end
	local o = C.units[kind]
	for i, u in ipairs(units) do
		local f = Get(prefix .. i, kind)
		Match(f, header)
		f:ClearAllPoints()
		if perRow == 1 then
			f:SetPoint('TOPLEFT', header, 'TOPLEFT', 0, -(i - 1) * (o.h + o.gap))
		else
			local col = (i - 1) % perRow
			local line = math.floor((i - 1) / perRow)
			if upward then
				f:SetPoint('BOTTOMLEFT', header, 'BOTTOMLEFT', col * (o.w + o.gap), line * (o.h + o.gap))
			else
				f:SetPoint('TOPLEFT', header, 'TOPLEFT', col * (o.w + o.gap), -line * (o.h + o.gap))
			end
		end
		Fill(f, u)
	end
end

local function Roster(count, withYou)
	local list = {}
	if withYou then table.insert(list, You()) end
	local i = 0
	while #list < count do
		i = i + 1
		table.insert(list, Member(i))
	end
	return list
end

local function HideAll()
	for _, f in pairs(mocks) do f:Hide() end
end

local function Draw()
	HideAll()
	if state.mode == 'off' then return end
	local M = C.modules
	if M.unitframes then
		OnFrame('target', 'target', SlimARK_target, { name = 'Training Dummy', hostile = true, hp = 58.3, cast = 'Shadow Bolt' })
		OnFrame('targettarget', 'targettarget', SlimARK_targettarget, Member(1))
		OnFrame('focus', 'focus', SlimARK_focus, { name = 'Void Caster', class = 'DEMONHUNTER', hp = 100, cast = 'Void Eruption', important = true })
		OnFrame('pet', 'pet', SlimARK_pet, { name = 'Felhound', class = 'WARLOCK', hp = 76.5 })
		local bossHealth = { 72.4, 100, 45, 100, 12.8 }
		for i = 1, 5 do
			OnFrame('boss' .. i, 'boss', _G['SlimARK_Boss' .. i], { name = 'Boss ' .. i, hostile = true, hp = bossHealth[i],
				cast = i == 1 and 'Void Eruption' or nil, important = i == 1 })
		end
	end
	local raid = state.mode == 'raid20' and 20 or state.mode == 'raid40' and 40 or nil
	if ns.healer then
		if M.grid then
			if raid then
				OnHeader('healraid', 'grid', SlimARK_HealRaid, Roster(raid, true), 5, true)
			else
				OnHeader('healparty', 'grid', SlimARK_HealParty, Roster(5, true), 5, true)
			end
		end
	elseif raid then
		if M.raid then OnHeader('raid', 'raid', SlimARK_Raid, Roster(raid, true), 5, false) end
	elseif M.party then
		OnHeader('party', 'party', SlimARK_Party, Roster(4, false), 1, false)
	end
end

------------------------------------------------------------------------
-- The banner under the top bar: shows the mode, a click ends it.
------------------------------------------------------------------------
local banner
local function Banner()
	if banner then return banner end
	banner = CreateFrame('Button', 'SlimARK_TestBanner', UIParent)
	banner:SetFrameStrata('HIGH')
	banner:SetSize(520, 40)
	banner:SetScale(ns.Scale())
	-- In its own units (1 = one pixel of the 2560x1600 layout), under the top bar.
	banner:SetPoint('TOP', UIParent, 'TOP', 0, -(ns.TopInset() + 6))
	local bg = banner:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(C.colors.classPower[1], C.colors.classPower[2], C.colors.classPower[3], 1)
	ns.Outline(banner)
	banner.text = ns.Text(banner, 20, 'CENTER')
	banner.text:SetFont(ns.FONT, 20, '')
	banner.text:SetTextColor(0.1, 0.08, 0.03)
	banner.text:SetPoint('CENTER')
	banner:RegisterForClicks('AnyUp')
	banner:SetScript('OnClick', function() ns.SetTestMode('off') end)
	banner:Hide()
	return banner
end

local function Refresh()
	if state.mode == 'off' then
		if banner then banner:Hide() end
	else
		local b = Banner()
		b:SetScale(ns.Scale())
		b.text:SetText('TEST MODE · ' .. MODES[state.mode] .. ' · click to end')
		b:Show()
	end
	Draw()
	if ns.SettingsRefresh then ns.SettingsRefresh() end
end

function ns.SetTestMode(mode)
	if not MODES[mode] then return end
	if mode ~= 'off' and InCombatLockdown() then
		ns.Print('Test mode can be switched on out of combat.')
		return
	end
	local was = state.mode
	state.mode = mode
	if mode == 'off' then
		if ns.MythicPlusPreview then ns.MythicPlusPreview(false) end
		if ns.PreviewLayout then ns.PreviewLayout(nil) end
		state.layout = nil
	else
		if was == 'off' then state.layout = ns.healer and 'heal' or 'dps' end
		if ns.MythicPlusPreview then ns.MythicPlusPreview(mode == 'mplus') end
	end
	Refresh()
end

function ns.SetTestLayout(layout)
	if layout ~= 'dps' and layout ~= 'heal' or InCombatLockdown() then return end
	if state.mode == 'off' then ns.SetTestMode('party') end
	state.layout = layout
	if ns.PreviewLayout then ns.PreviewLayout(layout == 'heal') end
	Refresh()
end

function ns.TestLayout()
	return state.layout or (ns.healer and 'heal' or 'dps')
end

-- Combat ends it while that is still allowed; the frames go back to the spec's layout.
ns.On('PLAYER_REGEN_DISABLED', function()
	if state.mode ~= 'off' then ns.SetTestMode('off') end
end)
-- A real group, a moved frame or a new scale: the made-up frames are drawn again.
ns.On('GROUP_ROSTER_UPDATE', function() if state.mode ~= 'off' then Draw() end end)
ns.On('UI_SCALE_CHANGED', function() if state.mode ~= 'off' then Refresh() end end)
ns.On('DISPLAY_SIZE_CHANGED', function() if state.mode ~= 'off' then Refresh() end end)
-- A frame dragged or resized in Edit Mode draws the made-up frames again at its new place.
function ns.TestRedraw()
	if state.mode ~= 'off' then Draw() end
end

if EditModeManagerFrame then
	EditModeManagerFrame:HookScript('OnHide', function() if state.mode ~= 'off' then Draw() end end)
end
