-- F8: first-show errors and theme registration failures must not become permanent.
local errors = {}
geterrorhandler = function() return function(err) errors[#errors + 1] = err end end

local function namespace()
	local events, ns = {}, { C = { blizz = { look = 'slimark' }, modules = { betterbags = true } } }
	ns.On = function(event, fn) events[event] = fn end
	ns.Emit = function(event, ...) if events[event] then events[event](event, ...) end end
	return ns
end

for _, initiallyShown in ipairs({ false, true }) do
	local ns, calls = namespace(), 0
	assert(loadfile('SlimARK-UI/BlizzSkin.lua'))('SlimARK-UI', ns)
	local hook
	local frame = { IsShown = function() return initiallyShown end,
		HookScript = function(_, event, fn) assert(event == 'OnShow') hook = fn end }
	ns.BlizzSkin.Register('test', nil, { frame }, function()
		calls = calls + 1
		if calls == 1 then error('frame data not ready') end
	end)
	ns.Emit('PLAYER_LOGIN')
	if not initiallyShown then hook(frame) end
	hook(frame)
	hook(frame)
	assert(calls == 2, 'Retry the failed skin, then skip the completed one')
end

do
	local ns = namespace()
	local attempts, nextAttempts, applied = 0, 0, 0
	local classic = { RegisterTheme = function()
		attempts = attempts + 1
		if attempts == 1 then error('theme data not ready') end
	end }
	local nextUI = { RegisterTheme = function() nextAttempts = nextAttempts + 1 end }
	local database = { SetTheme = function() applied = applied + 1 end, SetNextTheme = function() applied = applied + 1 end }
	local addon = { GetModule = function(_, key) return ({ Sonata = classic, SonataNext = nextUI, Database = database })[key] end }
	LibStub = function() return { GetAddon = function() return addon end } end
	assert(loadfile('SlimARK-UI/BetterBags.lua'))('SlimARK-UI', ns)
	ns.Emit('ADDON_LOADED', 'SlimARK-UI')
	assert(attempts == 1 and nextAttempts == 1)
	assert(ns.BetterBagsProfile() == false)
	assert(attempts == 2 and nextAttempts == 1, 'Keep successful registration; retry only the failed one')
	assert(ns.ApplyBetterBags() and applied == 2)
	database.SetNextTheme = function() return false end
	assert(ns.ApplyBetterBags() == false)
	LibStub = nil
	assert(ns.BetterBagsProfile() == nil, 'Missing optional addon is distinct from registration failure')
end
