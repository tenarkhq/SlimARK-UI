local H = dofile('tests/codex/lib/runtime.lua')
local ns = H.boot()
UnitName = function() return 'You' end
UnitClass = function() return 'Warrior', 'WARRIOR' end
RAID_CLASS_COLORS = {}
ns.SpecInfo = function() return 73, 'TANK' end
ns.C.modules.unitframes, ns.C.modules.grid = false, false
SlimARK_Raid = H.NewFrame('Frame')
ns.Placed = { { frame = SlimARK_Raid, w = 100, h = 100 } }
ns.Place = function() end
H.load('TestMode.lua')
ns.SetTestMode('raid20')
local own
for _, frame in ipairs(H.frames) do
	if frame.ui and frame.ui.name:GetText() == 'You' then own = frame break end
end
assert(own and H.lastCall(own.ui.role, 'SetAtlas')[1] == 'UI-LFG-RoleIcon-Tank-Micro-Raid',
	'The real test-mode entry point preserves the tank specialization role')
H.fire('CHALLENGE_MODE_START')
assert(ns.TestMode.mode == 'off' and not own:IsShown(), 'A real challenge ends the made-up roster')
H.noErrors()
