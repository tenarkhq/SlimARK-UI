-- H3: the shared event dispatcher (audit F15) and the action bar fade at the start of combat
-- (audit F14). Run from the repository root:
--   lua5.1 tests/claude/automation-events.lua
local H = dofile('tests/claude/lib/helpers.lua')

------------------------------------------------------------------------
-- F15: one module's error does not stop the others.
------------------------------------------------------------------------
do
	local ns = H.setup()
	H.load('Config.lua')
	H.load('Core.lua')
	local ran = {}
	ns.On('PLAYER_LOGIN', function() table.insert(ran, 'A') error('module A failed') end)
	ns.On('PLAYER_LOGIN', function() table.insert(ran, 'B') end)
	ns.On('PLAYER_LOGIN', function() table.insert(ran, 'C') end)
	local ok = pcall(H.fire, 'PLAYER_LOGIN')
	H.check(ok, 'F15 the event does not break off at the failing module')
	H.equal(table.concat(ran, ','), 'A,B,C', 'F15 the modules after the failing one still run')
	local reported = false
	for _, line in ipairs(H.prints) do
		if line:find('ERROR', 1, true) and line:find('module A failed', 1, true) then reported = true end
	end
	H.check(reported, 'F15 the error goes to the error handler, not swallowed')

	local got = {}
	ns.On('TEST_EVENT', function(event, a, b, c) got = { event, a, b, c } end)
	H.fire('TEST_EVENT', 1, nil, 'x')
	H.check(got[1] == 'TEST_EVENT' and got[2] == 1 and got[3] == nil and got[4] == 'x',
		'F15 the callbacks still get the event and every argument, nil included')
end

------------------------------------------------------------------------
-- F14: the faded bars come back as combat starts, even without a target.
------------------------------------------------------------------------
local affecting = false

local function BootBars()
	H.setup()
	affecting = false
	_G.UnitExists = function() return false end
	_G.UnitAffectingCombat = function(unit) return unit == 'player' and affecting end
	_G.GetCursorInfo = function() return nil end
	_G.MultiBarBottomLeft = H.NewFrame('Frame', 'MultiBarBottomLeft', UIParent)
	_G.MultiBarBottomRight = H.NewFrame('Frame', 'MultiBarBottomRight', UIParent)
	_G.MultiBarRight = H.NewFrame('Frame', 'MultiBarRight', UIParent)
	H.load('Config.lua')
	H.load('Core.lua')
	H.load('ActionBars.lua')
	H.fire('PLAYER_LOGIN')
	H.runTimers(1) -- the fade starts a second after login
	return MultiBarRight
end

do
	local bar = BootBars()
	H.equal(bar:GetAlpha(), 0, 'F14 out of combat the upper bar is faded')

	-- PLAYER_REGEN_DISABLED: no target, InCombatLockdown() still false in the event.
	H.combat = false
	H.fire('PLAYER_REGEN_DISABLED')
	H.equal(bar:GetAlpha(), 1, 'F14 combat start without a target brings the bar back')

	-- In the fight, an update without an event (the mouse over a button) keeps it.
	H.combat, affecting = true, true
	H.ns.UpdateActionBarFade(H.NewFrame('Button'))
	H.equal(bar:GetAlpha(), 1, 'F14 an update in the fight keeps the bar shown')

	-- The fight ends.
	H.combat, affecting = false, false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(bar:GetAlpha(), 0, 'F14 after the fight the bar fades again')
end

do
	-- Combat state known only from UnitAffectingCombat (no lockdown yet, no event): shown.
	BootBars()
	affecting = true
	H.ns.UpdateActionBarFade()
	H.equal(MultiBarRight:GetAlpha(), 1, 'F14 UnitAffectingCombat alone counts as combat')
end

H.done()
