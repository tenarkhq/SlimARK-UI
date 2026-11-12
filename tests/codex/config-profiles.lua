-- F8/F20: failures remain retryable, login never selects a foreign profile.
local reloads, messages, errors = 0, {}, {}
ReloadUI = function() reloads = reloads + 1 end
InCombatLockdown = function() return false end
geterrorhandler = function() return function(err) errors[#errors + 1] = err end end
UnitName = function() return 'Tester' end
C_Timer = { After = function(_, fn) fn() end }

local function skins()
	messages, errors = {}, {}
	Details, DBM, DBM_AllSavedOptions, DBT, BigWigsLoader, BigWigs3DB, BigWigsAPI = nil, nil, nil, nil, nil, nil, nil
	CHATTYNATOR_CONFIG, CHATTYNATOR_CURRENT_PROFILE = nil, nil
	local events = {}
	local ns = {
		CharDB = { applied = 3, appliedVersion = '2.1.0' }, version = '2.1.1',
		Print = function(text) messages[#messages + 1] = text end,
		Scale = function() return 1 end, FitX = function(x) return x end, FitY = function(y) return y end,
		ScreenHeight = function() return 1600 end, ShowSetup = function() end,
		ApplyEditMode = function() return true end,
	}
	ns.On = function(event, fn)
		events[event] = events[event] or {}
		table.insert(events[event], fn)
	end
	ns.Emit = function(event, ...)
		for _, fn in ipairs(events[event] or {}) do fn(event, ...) end
	end
	assert(loadfile('SlimARK-UI/Config.lua'))('SlimARK-UI', ns)
	ns.C.modules.betterbags = false
	ns.C.blizz.look = 'original'
	assert(loadfile('SlimARK-UI/Skins.lua'))('SlimARK-UI', ns)
	return ns
end

do
	local ns = skins()
	ns.ApplyEditMode = function() return false end
	local before = reloads
	assert(ns.ApplyAll() == false and reloads == before)
	assert(ns.CharDB.applyPending and ns.CharDB.appliedVersion == '2.1.0')
	local asked = false
	ns.CharDB.appliedVersion = ns.version
	ns.ShowSetup = function() asked = true end
	ns.Emit('PLAYER_ENTERING_WORLD', false, true)
	assert(asked, 'A partial apply must be offered again even for the same version')
	ns.ApplyEditMode = function() return true end
	assert(ns.ApplyAll() and reloads == before + 1)
	assert(not ns.CharDB.applyPending and ns.CharDB.appliedVersion == '2.1.1')
end

do
	local ns = skins()
	Details = { tabela_instancias = {}, GetCurrentProfileName = function() return 'Mine' end,
		GetProfile = function() error('profile backend unavailable') end }
	local before, count = reloads, #errors
	assert(ns.ApplyAll() == false and reloads == before and #errors == count + 1)
	for _, text in ipairs(messages) do
		assert(not text:find('Details is not loaded', 1, true), 'A thrown profile error is not a missing addon')
	end
	Details = nil
	ns.C.modules.betterbags = true
	ns.BetterBagsProfile = function() return false end
	ns.ApplyBetterBags = function() return false end
	assert(ns.ApplyAll() == false and reloads == before, 'A false application result must propagate')
end

do
	local ns = skins()
	local selected, switches = 'Mine', 0
	local window = { baseframe = { ClearAllPoints = function() end, SetPoint = function() end },
		IsEnabled = function() return true end, barras = {}, row_info = {}, automation = {} }
	setmetatable(window, { __index = function() return function() end end })
	Details = { tabela_instancias = {}, GetProfile = function() return {} end,
		GetCurrentProfileName = function() return selected end, GetInstance = function() return window end,
		ApplyProfile = function(_, name) selected = name switches = switches + 1 end }
	assert(ns.ApplyAll() and selected == 'SlimARK-UI' and switches == 1, 'Explicit apply must still select SlimARK')
end
