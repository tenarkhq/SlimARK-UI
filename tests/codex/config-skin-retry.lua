-- F8: retry transient failures, but bound persistent skin failures and their side effects.
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

for _, initiallyShown in ipairs({ false, true }) do
	for _, failure in ipairs({ 'error', 'false' }) do
		local ns, frames = namespace(), {}
		assert(loadfile('SlimARK-UI/BlizzSkin.lua'))('SlimARK-UI', ns)
		for i = 1, 2 do
			local frame = { calls = 0, hooks = 0, textures = 0, children = 0 }
			function frame:IsShown() return initiallyShown end
			function frame:HookScript(event, fn) assert(event == 'OnShow') self.onShow = fn end
			function frame:CreateTexture() self.textures = self.textures + 1 end
			frames[i] = frame
		end
		local oldHook, oldCreate = hooksecurefunc, CreateFrame
		local callbacks = {}
		hooksecurefunc = function(_, fn) callbacks[#callbacks + 1] = fn end
		CreateFrame = function(_, _, parent) parent.children = parent.children + 1 end
		local startErrors = #errors
		ns.BlizzSkin.Register('persistent', nil, frames, function(frame)
			frame.calls = frame.calls + 1
			frame:CreateTexture()
			CreateFrame('Frame', nil, frame)
			hooksecurefunc('TestSkinEvent', function() frame.hooks = frame.hooks + 1 end)
			if failure == 'error' then error('permanent client frame mismatch') end
			return false
		end)
		ns.Emit('PLAYER_LOGIN')
		for _ = 1, 20 do
			for _, frame in ipairs(frames) do frame.onShow(frame) end
		end
		for _, callback in ipairs(callbacks) do callback() end
		hooksecurefunc, CreateFrame = oldHook, oldCreate
		for _, frame in ipairs(frames) do
			assert(frame.calls == 2, 'Persistent failure: at most two attempts per frame, with independent budgets')
			assert(frame.hooks == 2 and frame.children == 2 and frame.textures == 2,
				'Repeated OnShow must not keep adding hooks, child frames or textures')
			assert(not ns.BlizzSkin.Done(frame, 'window'), 'Failed skins must not be marked successful')
		end
		assert(#errors - startErrors == (failure == 'error' and 4 or 0),
			'Persistent errors must be reported at most twice per frame; false is not an exception')
	end
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
