local addonName, ns = ...
local C = ns.C

-- Floating combat text in the SlimARK look (2.0, on by default, independent of the Blizzard
-- windows choice). Crits stand apart: twice the size, a stronger color (orange on the target), they land with a pop and shake,
-- and stay up longer. The source is the game's UNIT_COMBAT event: its kind and the crit flag
-- are always readable, the amount can be secret (boss fights, Mythic+) and is then shown
-- as the game gives it, without arithmetic.
--
-- What is shown where:
--   damage you take and heals you get: left and right of your character, from the player unit;
--   damage on your target: above the middle, only while you are not in a group, because the
--   game tells the damage the target takes from everyone, not only yours. In a group the
--   game's own numbers show your damage, in the SlimARK font.
local MAX = 24

local GOLD = { 1, 0.78, 0.22 }
local CRIT_HIT = { 1, 0.55, 0.1 }
local WHITE = { 1, 1, 1 }
local HEAL = { 0.36, 0.94, 0.48 }
local HEAL_CRIT = { 0.43, 1, 0.54 }
local HURT = { 1, 0.29, 0.23 }
local HURT_CRIT = { 1, 0.35, 0.23 }
local GREY = { 0.72, 0.74, 0.78 }

local MISSES = { DODGE = true, PARRY = true, MISS = true, IMMUNE = true, EVADE = true, DEFLECT = true, REFLECT = true, BLOCK = true, ABSORB = true, RESIST = true }

local root, pool, used = nil, {}, {}

local function Size(base)
	return math.floor(base * (C.combattext.size or 100) / 100 + 0.5)
end

local function Release(line)
	line.fs:Hide()
	line.busy = false
end

local function NewLine()
	local line = { busy = false }
	local fs = root:CreateFontString(nil, 'OVERLAY')
	fs:SetFont(ns.FONT, 26, 'OUTLINE')
	fs:SetShadowOffset(0, -2)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:Hide()
	line.fs = fs

	local group = fs:CreateAnimationGroup()
	local pop = group:CreateAnimation('Scale')
	pop:SetOrder(1)
	pop:SetDuration(0.12)
	pop:SetScaleFrom(2.2, 2.2)
	pop:SetScaleTo(1, 1)
	pop:SetSmoothing('OUT')
	local shakeA = group:CreateAnimation('Translation')
	shakeA:SetOrder(2)
	shakeA:SetDuration(0.04)
	shakeA:SetOffset(-3, 0)
	local shakeB = group:CreateAnimation('Translation')
	shakeB:SetOrder(3)
	shakeB:SetDuration(0.06)
	shakeB:SetOffset(6, 0)
	local shakeC = group:CreateAnimation('Translation')
	shakeC:SetOrder(4)
	shakeC:SetDuration(0.04)
	shakeC:SetOffset(-3, 0)
	local move = group:CreateAnimation('Translation')
	move:SetOrder(5)
	move:SetSmoothing('OUT')
	local fade = group:CreateAnimation('Alpha')
	fade:SetOrder(5)
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	group:SetScript('OnFinished', function() Release(line) end)
	line.group, line.pop, line.shake, line.move, line.fade = group, pop, { shakeA, shakeB, shakeC }, move, fade
	table.insert(pool, line)
	return line
end

local function Take()
	for _, line in ipairs(pool) do
		if not line.busy then return line end
	end
	if #pool < MAX then return NewLine() end
	-- All lines are in use: the oldest one makes room.
	local oldest = table.remove(used, 1)
	if oldest then
		oldest.group:Stop()
		Release(oldest)
		return oldest
	end
end

-- Shows one number. place: 'target', 'hurt' or 'heal'. crit: the big landing look.
local function Show(place, text, sign, color, crit)
	local line = Take()
	if not line then return end
	line.busy = true
	for i, l in ipairs(used) do
		if l == line then table.remove(used, i) break end
	end
	table.insert(used, line)

	local fs = line.fs
	local impact = crit and C.combattext.crit == 'impact'
	fs:SetFont(ns.FONT, Size(crit and 52 or (place == 'target' and 26 or 24)), crit and 'THICKOUTLINE' or 'OUTLINE')
	fs:SetTextColor(color[1], color[2], color[3])
	if issecretvalue(text) then
		if not (sign and pcall(fs.SetFormattedText, fs, '%s%s', sign, text)) then fs:SetText(text) end
	elseif type(text) == 'number' then
		fs:SetText((sign or '') .. BreakUpLargeNumbers(math.floor(text + 0.5)))
	else
		fs:SetText(text)
	end

	local x, y, dy
	if place == 'target' then
		x, y, dy = math.random(-70, 70), crit and 150 or math.random(110, 190), crit and 46 or 80
	elseif place == 'heal' then
		x, y, dy = math.random(-260, -200), math.random(-20, 20), crit and 40 or 70
	else
		x, y, dy = math.random(-170, -120), math.random(-40, 0), -(crit and 40 or 60)
	end
	fs:ClearAllPoints()
	fs:SetPoint('CENTER', root, 'CENTER', x, y)
	fs:SetAlpha(1)
	fs:Show()

	line.pop:SetDuration(impact and 0.12 or 0.001)
	line.pop:SetScaleFrom(impact and 2.2 or 1, impact and 2.2 or 1)
	for _, step in ipairs(line.shake) do step:SetDuration(impact and 0.05 or 0.001) end
	line.shake[1]:SetOffset(impact and -3 or 0, 0)
	line.shake[2]:SetOffset(impact and 6 or 0, 0)
	line.shake[3]:SetOffset(impact and -3 or 0, 0)
	line.move:SetOffset(0, dy)
	line.move:SetDuration(crit and 1.6 or 1.2)
	line.fade:SetStartDelay(crit and 1.0 or 0.7)
	line.fade:SetDuration(crit and 0.6 or 0.5)
	line.group:Stop()
	line.group:Play()
end

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

-- The game's own word for a miss (DODGE = 'Dodge', PARRY = 'Parry' ...).
local function Word(kind)
	local text = _G[kind]
	return type(text) == 'string' and text or kind
end

local function OnCombat(unit, kind, flag, amount)
	if not Readable(kind) then return end
	local crit = Readable(flag) and flag == 'CRITICAL'
	local cfg = C.combattext
	if unit == 'target' then
		if IsInGroup() or not cfg.target then return end
		local hostile = UnitCanAttack('player', 'target')
		if Readable(hostile) and not hostile then return end
		if kind == 'WOUND' then
			Show('target', amount, nil, crit and CRIT_HIT or WHITE, crit)
		elseif MISSES[kind] then
			Show('target', Word(kind), nil, GREY, false)
		end
	elseif unit == 'player' then
		if kind == 'WOUND' and cfg.incoming then
			Show('hurt', amount, '-', crit and HURT_CRIT or HURT, crit)
		elseif kind == 'HEAL' and cfg.heals then
			Show('heal', amount, '+', crit and HEAL_CRIT or HEAL, crit)
		elseif MISSES[kind] and cfg.incoming then
			Show('hurt', Word(kind), nil, GREY, false)
		end
	end
end

-- The game's own numbers: the center text on yourself goes (ours replaces it), and your damage
-- on the target is the game's own while you are in a group. The values before are kept and come
-- back when the module is switched off. CVars change out of combat only.
local function SetCVarSafe(name, value)
	if GetCVar(name) ~= nil and GetCVar(name) ~= value then SetCVar(name, value) end
end

local pendingCVars = false
local function GameNumbers()
	if InCombatLockdown() then
		pendingCVars = true
		return
	end
	pendingCVars = false
	local saved = ns.DB.combatTextCVars
	if C.modules.combattext then
		if not saved then
			saved = { enableFloatingCombatText = GetCVar('enableFloatingCombatText'), floatingCombatTextCombatDamage = GetCVar('floatingCombatTextCombatDamage') }
			ns.DB.combatTextCVars = saved
		end
		SetCVarSafe('enableFloatingCombatText', '0')
		local ours = C.combattext.target and not IsInGroup()
		SetCVarSafe('floatingCombatTextCombatDamage', ours and '0' or (saved.floatingCombatTextCombatDamage or '1'))
	elseif saved then
		for name, value in pairs(saved) do SetCVarSafe(name, value) end
		ns.DB.combatTextCVars = nil
	end
end

-- The game's floating numbers read their font once, while the UI loads.
ns.On('ADDON_LOADED', function(_, name)
	if name == addonName and C.modules.combattext then
		DAMAGE_TEXT_FONT = ns.FONT
	end
end)

ns.On('PLAYER_LOGIN', function()
	GameNumbers()
	if not C.modules.combattext then return end
	root = CreateFrame('Frame', 'SlimARK_CombatText', UIParent)
	root:SetSize(10, 10)
	root:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	root:SetFrameStrata('HIGH')
	root:SetScale(ns.Scale())
	local events = CreateFrame('Frame')
	events:RegisterUnitEvent('UNIT_COMBAT', 'player', 'target')
	events:SetScript('OnEvent', function(_, _, unit, kind, flag, amount)
		OnCombat(unit, kind, flag, amount)
	end)
	ns.On('GROUP_ROSTER_UPDATE', GameNumbers)
	ns.On('PLAYER_REGEN_ENABLED', function()
		if pendingCVars then GameNumbers() end
	end)
end)

-- The Show a sample button on the Combat text page.
function ns.CombatTextSample()
	if not root then return end
	Show('target', 48920, nil, CRIT_HIT, true)
	Show('heal', 21300, '+', HEAL_CRIT, true)
	Show('hurt', 6420, '-', HURT, false)
end
