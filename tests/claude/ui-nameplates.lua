-- H2: who interrupted a nameplate's cast (audit F18). Run from the repository root:
--   lua5.1 tests/claude/ui-nameplates.lua
local H = dofile('tests/claude/lib/helpers.lua')

local world

-- Loads UnitFrames.lua (it makes the cast bar) and NamePlates.lua with a stand-in oUF, then
-- styles one plate for nameplate1.
local function Boot()
	local ns = H.setup()
	world = { names = {}, classes = {}, targets = {}, guidNames = {}, guidClasses = {}, comparable = true }
	local oUF = { Tags = { Methods = {}, Events = {} }, styles = {} }
	function oUF:RegisterStyle(name, fn) self.styles[name] = fn end
	function oUF:Factory() end
	ns.oUF = oUF
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
	_G.C_Spell = { IsSpellImportant = function() return false end }
	H.load('Config.lua')
	H.load('Core.lua')
	H.load('UnitFrames.lua')
	H.load('NamePlates.lua')
	local plate = H.NewFrame('Frame', nil, UIParent)
	oUF.styles.SlimARKPlate(plate)
	plate.__unit = 'nameplate1'
	plate.Castbar.__owner = plate -- oUF sets this when it enables the element
	return plate.Castbar
end

local function Kick(unit, name, class, target)
	world.names[unit], world.classes[unit], world.targets[unit] = name, class, target
	H.fire('UNIT_SPELLCAST_SUCCEEDED', unit, 'cast-guid', 1766) -- Kick
end

local function Shown(cb)
	if cb.Time:GetText() ~= nil and cb.Text:GetText() == 'Interrupted' then return cb.Time:GetText() end
end

do
	-- No GUID from the game; Alice kicked the mob she targets: her name, in class color.
	local cb = Boot()
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	H.now = H.now + 0.2
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), 'Alice', 'F18 a party kick aimed at this mob names the kicker')
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
	-- The game gives a secret GUID whose (secret) name is Bob; Alice's kick on the same mob is fresh.
	local cb = Boot()
	H.secret = { ['SECRET-GUID'] = true, Bob = true }
	world.guidNames['SECRET-GUID'] = 'Bob'
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	H.now = H.now + 0.1
	cb.PostCastInterrupted(cb, 'nameplate1', 0, 'SECRET-GUID')
	H.equal(Shown(cb), 'Bob', 'F18 the name behind a secret GUID wins over a party kick')
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
	-- The game cannot compare the units (restricted content): the kick cannot be tied, no name.
	local cb = Boot()
	world.comparable = false
	Kick('party1', 'Alice', 'ROGUE', 'nameplate1')
	H.now = H.now + 0.1
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), nil, 'F18 a kick that cannot be tied to the mob names nobody')
end

do
	-- The player kicked by focus: tied through the focus.
	local cb = Boot()
	world.targets.focus = 'nameplate1'
	Kick('player', 'Me', 'MAGE', 'nameplate3')
	H.now = H.now + 0.1
	cb.PostCastFail(cb, 'nameplate1', 0, 'UNIT_SPELLCAST_INTERRUPTED')
	H.equal(Shown(cb), 'Me', 'F18 your own kick on your focus names you')
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

H.done()
