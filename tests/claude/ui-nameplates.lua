-- H2: who interrupted a nameplate's cast (audit F18). Run from the repository root:
--   lua5.1 tests/claude/ui-nameplates.lua
local H = dofile('tests/claude/lib/helpers.lua')

local world

-- Loads UnitFrames.lua (it makes the cast bar) and NamePlates.lua with a stand-in oUF, then
-- styles one plate for nameplate1.
-- tweak(ns): changes ns.C after Config.lua, before the modules read it.
local function Boot(tweak)
	local ns = H.setup()
	world = { names = {}, classes = {}, targets = {}, guidNames = {}, guidClasses = {}, comparable = true,
		role = 'DAMAGER', threat = {}, fighting = {}, grouped = false }
	local oUF = { Tags = { Methods = {}, Events = {} }, styles = {} }
	function oUF:RegisterStyle(name, fn) self.styles[name] = fn end
	function oUF:Factory(fn) self.factory = fn end
	function oUF:SetActiveStyle() end
	function oUF:SpawnNamePlates()
		return { SetSize = function() end, SetAddedCallback = function(_, fn) world.added = fn end }
	end
	ns.oUF = oUF
	_G.C_SpecializationInfo = {
		GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function() return world.spec or 70, nil, nil, nil, world.role end,
	}
	_G.C_SpellBook = { IsSpellKnownOrInSpellBook = function(id, bank) return bank == nil and id == world.kick end }
	_G.IsInGroup = function() return world.grouped end
	_G.IsInRaid = function() return false end
	_G.GetNumSubgroupMembers = function() return 0 end
	_G.UnitIsPlayer = function() return false end
	_G.UnitIsLieutenant = function() return false end
	_G.UnitPowerType = function() return 1 end
	_G.UnitIsFriend = function() return false end
	_G.UnitThreatSituation = function(_, unit) return world.threat[unit] end
	_G.UnitAffectingCombat = function(unit) return world.fighting[unit] or false end
	_G.UnitShouldDisplaySpellTargetName = function(unit) return world.castTarget ~= nil end
	_G.UnitSpellTargetName = function() return world.castTarget and world.castTarget.name end
	_G.UnitSpellTargetClass = function() return world.castTarget and world.castTarget.class end
	_G.PlayerIsSpellTarget = function() return world.castTarget and world.castTarget.me or false end
	_G.UnitName = function(unit) return world.names[unit] end
	_G.UnitClassBase = function(unit) return world.classes[unit] end
	_G.UnitExists = function(unit)
		local owner = unit:match('^(.-)target$')
		if owner then return world.targets[owner] ~= nil end
		return unit == 'focus' and world.targets.focus ~= nil or world.names[unit] ~= nil
	end
	_G.UnitIsUnit = function(a, b)
		local owner = a:match('^(.-)target$')
		local target = owner and world.targets[owner] or (a == 'focus' and world.targets.focus) or a
		return target == b
	end
	_G.C_Secrets = { CanCompareUnitTokens = function() return world.comparable end }
	_G.UnitNameFromGUID = function(guid) return world.guidNames[guid] end
	_G.GetPlayerInfoByGUID = function(guid) return nil, world.guidClasses[guid] end
	_G.C_ClassColor = { GetClassColor = function(class) return { r = 0.1, g = 0.2, b = 0.3, class = class } end }
	_G.C_Spell = {
		IsSpellImportant = function() return world.important or false end,
		GetSpellCooldown = function() return world.cooldown end,
		GetSpellCooldownDuration = function() return world.cooldown and {} end,
	}
	H.load('Config.lua')
	if tweak then tweak(ns) end
	H.load('Core.lua')
	H.load('Role.lua')
	H.load('UnitFrames.lua')
	H.load('NamePlates.lua')
	oUF:factory()
	-- Two plates: the interrupted mob and another one.
	local other = H.NewFrame('Frame', nil, UIParent)
	oUF.styles.SlimARKPlate(other)
	other.__unit = 'nameplate2'
	local plate = H.NewFrame('Frame', nil, UIParent)
	oUF.styles.SlimARKPlate(plate)
	plate.__unit = 'nameplate1'
	plate.Castbar.__owner = plate -- oUF sets this when it enables the element
	-- oUF recolors the health bar on a forced update.
	plate.Health.__owner = plate
	plate.Health.ForceUpdate = function(element)
		element:SetStatusBarColor(1, 0, 0)
		element.PostUpdateColor(element)
	end
	return plate.Castbar, plate, ns
end

local function Kick(unit, name, class, target)
	world.names[unit], world.classes[unit], world.targets[unit] = name, class, target
	H.fire('UNIT_SPELLCAST_SUCCEEDED', unit, 'cast-guid', 1766) -- Kick
end

local function Shown(cb)
	if cb.Time:GetText() ~= nil and cb.Text:GetText() == 'Interrupted' then return cb.Time:GetText() end
end

do
	-- No GUID from the game; Alice kicked the mob she targeted: her name in class color.
	local cb = Boot()
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	H.now = H.now + 0.2
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), 'Alice', 'a party kick at this plate names the kicker')
	local color = H.lastCall(cb.Time, 'SetTextColor')
	H.check(color and color[1] == 0.1, 'in class color, no question mark')
end

do
	-- Alice kicked the other mob and switched her target to this one right after.
	local cb = Boot()
	Kick('party1', 'Alice', 'ROGUE', 'nameplate2')
	H.now = H.now + 0.05
	world.targets.party1 = 'nameplate1'
	H.now = H.now + 0.05
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), nil, 'F18 a quick target switch after the kick does not move it to this mob')
end

do
	-- Alice kicked another mob; this one was interrupted by someone the game does not name.
	local cb = Boot()
	Kick('party1', 'Alice', 'ROGUE', 'nameplate2')
	H.now = H.now + 0.2
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), nil, 'F18 a kick at another mob does not name anybody here')
end

do
	-- The game gives a secret GUID (its name has no class color); Alice's kick on this mob is fresh.
	local cb = Boot()
	H.secret = { ['SECRET-GUID'] = true, Bob = true }
	world.guidNames['SECRET-GUID'] = 'Bob'
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	H.now = H.now + 0.1
	cb.PostCastInterrupted(cb, 'nameplate1', 0, 'SECRET-GUID')
	H.equal(Shown(cb), 'Alice', 'the party kick at this mob wins over the uncolored secret name')
	H.secret = nil
end

do
	-- A kick older than half a second names nobody.
	local cb = Boot()
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	H.now = H.now + 0.8
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), nil, 'F18 an old kick names nobody')
end

do
	-- The game cannot compare the units (restricted content): the only fresh kick names the kicker.
	local cb = Boot()
	world.comparable = false
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	H.now = H.now + 0.1
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), 'Alice', 'a single untied kick names the kicker')
	local color = H.lastCall(cb.Time, 'SetTextColor')
	H.check(color and color[1] == 0.1, 'in class color')
end

do
	-- The player has this mob as focus but kicked their target, another mob.
	local cb = Boot()
	world.targets.focus = 'nameplate1'
	Kick('player', 'Me', 'MAGE', 'nameplate2')
	H.now = H.now + 0.1
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), nil, 'F18 a focus on this mob does not prove the kick went to it')
end

do
	-- Your own kick at your target names you.
	local cb = Boot()
	Kick('player', 'Me', 'MAGE', 'nameplate1')
	H.now = H.now + 0.1
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), 'Me', 'your own kick at your target names you')
end

do
	-- A readable GUID always names the exact player, with the class color.
	local cb = Boot()
	world.guidNames['Player-1-CAROL'] = 'Carol'
	world.guidClasses['Player-1-CAROL'] = 'SHAMAN'
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	cb.PostCastInterrupted(cb, 'nameplate1', 0, 'Player-1-CAROL')
	H.equal(Shown(cb), 'Carol', 'F18 a readable GUID names the exact interrupter')
	local color = H.lastCall(cb.Time, 'SetTextColor')
	H.check(color and color[1] == 0.1, 'F18 in their class color')
end

do
	-- Two untied kicks in the same half second: nobody can tell which one it was.
	local cb = Boot()
	world.comparable = false
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	Kick('party2', 'Dave', 'WARRIOR', 'nameplate2')
	H.now = H.now + 0.1
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), nil, 'two untied kicks name nobody')
end

do
	-- Secret GUID and no kick: the name behind it is still shown.
	local cb = Boot()
	H.secret = { ['SECRET-GUID'] = true, Bob = true }
	world.guidNames['SECRET-GUID'] = 'Bob'
	cb.PostCastInterrupted(cb, 'nameplate1', 0, 'SECRET-GUID')
	H.equal(Shown(cb), 'Bob', 'the secret name shows when no kick was seen')
	H.secret = nil
end

------------------------------------------------------------------------
-- 2.3.0: the cast bar by your interrupt's cooldown.
------------------------------------------------------------------------
local function BarColors(cb)
	local call = H.lastCall(cb:GetStatusBarTexture(), 'SetVertexColorFromBoolean')
	return call and call[2], call and call[3]
end

do
	local cb = Boot(function() world.kick = 96231 end)
	local colors = cb.castColors
	cb.PostCastStart(cb, 'nameplate1', 100)
	local important, normal = BarColors(cb)
	H.check(important == colors.important and normal == colors.normal, 'kick ready: the bar has its bright colors')

	world.cooldown = { isActive = true, isOnGCD = false }
	H.fire('SPELL_UPDATE_COOLDOWN')
	important, normal = BarColors(cb)
	H.check(important == colors.importantDim and normal == colors.normalDim, 'kick on cooldown: a running cast goes dark')
	H.check(colors.normalDim.r < colors.normal.r, 'the dark color is a darker shade of the same color')

	world.cooldown = { isActive = true, isOnGCD = true }
	H.fire('SPELL_UPDATE_COOLDOWN')
	important, normal = BarColors(cb)
	H.check(normal == colors.normal, 'the global cooldown alone does not darken the bar')

	-- A bar that is not shown is left alone; the next cast paints it with the state of that moment.
	cb:Hide()
	local before = #H.calls(cb:GetStatusBarTexture(), 'SetVertexColorFromBoolean')
	world.cooldown = { isActive = true, isOnGCD = false }
	H.fire('SPELL_UPDATE_COOLDOWN')
	H.equal(#H.calls(cb:GetStatusBarTexture(), 'SetVertexColorFromBoolean'), before, 'a hidden cast bar is not repainted')
	cb:Show()
	cb.PostCastStart(cb, 'nameplate1', 100)
	important, normal = BarColors(cb)
	H.check(normal == colors.normalDim, 'a cast that starts while the kick is on cooldown starts dark')
end

do
	-- No interrupt of your own: the bars stay bright whatever the cooldowns do.
	local cb = Boot()
	world.cooldown = { isActive = true, isOnGCD = false }
	H.fire('SPELL_UPDATE_COOLDOWN')
	cb.PostCastStart(cb, 'nameplate1', 100)
	local _, normal = BarColors(cb)
	H.check(normal == cb.castColors.normal, 'without an interrupt the bar stays bright')
end

do
	local cb = Boot(function(ns) world.kick = 96231 ns.C.features.kickReady = false end)
	world.cooldown = { isActive = true, isOnGCD = false }
	H.fire('SPELL_UPDATE_COOLDOWN')
	cb.PostCastStart(cb, 'nameplate1', 100)
	local _, normal = BarColors(cb)
	H.check(normal == cb.castColors.normal, 'switched off: the bar stays bright')
end

------------------------------------------------------------------------
-- 2.3.0: who the cast is aimed at.
------------------------------------------------------------------------
do
	local cb = Boot()
	world.castTarget = { name = 'Bob', class = 'PRIEST', me = false }
	cb.PostCastStart(cb, 'nameplate1', 100)
	H.equal(cb.Target:GetText(), 'Bob', 'cast target: the name is shown')
	local color = H.lastCall(cb.Target, 'SetTextColor')
	H.check(color and color[1] == 0.1, 'cast target: in the class color')
	local nameAlpha, youAlpha = H.lastCall(cb.Target, 'SetAlphaFromBoolean'), H.lastCall(cb.TargetYou, 'SetAlphaFromBoolean')
	H.check(nameAlpha[2] == 0 and nameAlpha[3] == 1 and youAlpha[2] == 1 and youAlpha[3] == 0,
		'cast target: when it is you, YOU takes the place of the name')
	H.equal(cb.TargetYou:GetText(), 'YOU', 'cast target: the YOU text')
	H.check(cb.TargetArrow:IsShown(), 'cast target: the arrow under a nameplate bar shows')

	world.castTarget = nil
	cb.PostCastStart(cb, 'nameplate1', 100)
	H.equal(cb.Target:GetText(), '', 'cast target: a cast without a target clears the name')
	H.check(not cb.TargetArrow:IsShown() and cb.TargetYou:GetAlpha() == 0, 'cast target: and hides the arrow and YOU')
end

do
	local cb = Boot(function(ns) ns.C.features.castTarget = false end)
	H.check(cb.Target == nil, 'cast target off: nothing is made')
	world.castTarget = { name = 'Bob', class = 'PRIEST' }
	local ok = pcall(cb.PostCastStart, cb, 'nameplate1', 100)
	H.check(ok, 'cast target off: a cast start still works')
end

------------------------------------------------------------------------
-- 2.3.0: aggro color on the plate.
------------------------------------------------------------------------
local function PlateColor(plate)
	local c = H.lastCall(plate.Health, 'SetStatusBarColor')
	return c and (c[1] .. ',' .. c[2] .. ',' .. c[3])
end

do
	local _, plate, ns = Boot()
	local warn = table.concat(ns.C.colors.plateThreat, ',')
	-- Solo: everything is on you, nothing is colored.
	world.threat.nameplate1 = 3
	world.added(plate, nil, 'nameplate1')
	H.check(PlateColor(plate) ~= warn, 'aggro: solo nothing is colored')

	world.grouped = true
	H.fire('UNIT_THREAT_LIST_UPDATE', 'nameplate1')
	H.equal(PlateColor(plate), warn, 'aggro, damage dealer: a mob on you gets the warning color')

	world.threat.nameplate1 = 1
	H.fire('UNIT_THREAT_LIST_UPDATE', 'nameplate1')
	H.check(PlateColor(plate) ~= warn, 'aggro, damage dealer: high threat without the mob on you is not colored')

	world.threat.nameplate1 = 2
	H.fire('UNIT_THREAT_SITUATION_UPDATE', 'player')
	H.equal(PlateColor(plate), warn, 'aggro: your own threat change looks at every plate')

	H.secret = { [3] = true }
	world.threat.nameplate1 = 3
	H.fire('UNIT_THREAT_LIST_UPDATE', 'nameplate1')
	H.check(PlateColor(plate) ~= warn, 'aggro: a hidden threat value colors nothing')
	H.secret = nil
end

do
	local _, plate, ns = Boot()
	local warn = table.concat(ns.C.colors.plateThreat, ',')
	world.role, world.grouped = 'TANK', true
	world.threat.nameplate1 = 3
	world.added(plate, nil, 'nameplate1')
	H.check(PlateColor(plate) ~= warn, 'aggro, tank: a mob on you is not colored')

	world.threat.nameplate1, world.fighting.nameplate1 = 0, true
	H.fire('UNIT_THREAT_LIST_UPDATE', 'nameplate1')
	H.equal(PlateColor(plate), warn, 'aggro, tank: a fighting mob that is not on you gets the warning color')

	world.threat.nameplate1, world.fighting.nameplate1 = nil, false
	H.fire('UNIT_THREAT_LIST_UPDATE', 'nameplate1')
	H.check(PlateColor(plate) ~= warn, 'aggro, tank: a mob out of combat is not colored')

	-- The caster color comes back when the warning ends, and the warning wins over it.
	plate.isCaster = true
	plate.Health:ForceUpdate()
	H.equal(PlateColor(plate), table.concat(ns.C.colors.caster, ','), 'aggro: a caster keeps its color without a warning')
	world.threat.nameplate1, world.fighting.nameplate1 = 0, true
	H.fire('UNIT_THREAT_LIST_UPDATE', 'nameplate1')
	H.equal(PlateColor(plate), warn, 'aggro: the warning wins over the caster color')
end

do
	local _, plate, ns = Boot(function(ns) ns.C.features.plateThreat = false end)
	world.grouped = true
	world.threat.nameplate1 = 3
	world.added(plate, nil, 'nameplate1')
	H.fire('UNIT_THREAT_LIST_UPDATE', 'nameplate1')
	H.check(PlateColor(plate) ~= table.concat(ns.C.colors.plateThreat, ','), 'aggro off: nothing is colored')
end

------------------------------------------------------------------------
-- 2.3.0: the execute line.
------------------------------------------------------------------------
local function LineX(plate)
	if not plate.ExecuteLine:IsShown() then return nil end
	local point = H.lastCall(plate.ExecuteLine, 'SetPoint')
	return point and point[4]
end

do
	local _, plate, ns = Boot(function() world.classes.player = 'PALADIN' end)
	H.equal(LineX(plate), ns.C.plate.w * 0.20, 'execute line: a paladin has it at 20% of the plate width')

	-- Fire mage: the spec value wins over the class.
	world.classes.player, world.spec = 'MAGE', 63
	H.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
	H.equal(LineX(plate), ns.C.plate.w * 0.30, 'execute line: a spec value moves it on a spec change')

	world.classes.player, world.spec = 'DEMONHUNTER', 577
	H.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
	H.equal(LineX(plate), nil, 'execute line: a class without a finisher has no line')
end

do
	local _, plate, ns = Boot(function(ns) world.classes.player = 'DEMONHUNTER' ns.C.plate.execute = 35 end)
	H.equal(LineX(plate), ns.C.plate.w * 0.35, 'execute line: the setting wins over the class')
end

do
	local _, plate = Boot(function(ns) world.classes.player = 'PALADIN' ns.C.features.executeLine = false end)
	H.equal(LineX(plate), nil, 'execute line off: no line')
end

H.done()
