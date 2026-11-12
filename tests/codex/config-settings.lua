-- F1/F27: execute the real settings module, including rollback after failed apply.
wipe = function(t) for k in pairs(t) do t[k] = nil end end
local locked = false
InCombatLockdown = function() return locked end
local reloads = 0
ReloadUI = function() reloads = reloads + 1 end

local function settings(saved)
	SlimARKDB = { settings = saved or {} }
	local ns = { CharDB = {}, Print = function() end }
	local loaded
	ns.On = function(event, fn) if event == 'ADDON_LOADED' then loaded = fn end end
	assert(loadfile('SlimARK-UI/Config.lua'))('SlimARK-UI', ns)
	assert(loadfile('SlimARK-UI/Settings.lua'))('SlimARK-UI', ns)
	loaded('ADDON_LOADED', 'SlimARK-UI')
	return ns, ns.Settings
end

do
	local ns, s = settings()
	local color = ns.C.colors.cdMain
	s.Set('layout.bars.size', 60)
	s.Set('bossmods.normal.x', 1234)
	s.Set('chat.x', 111)
	s.Set('colors.cdMain', { 0.2, 0.3, 0.4 })
	local applied = false
	ns.ApplyAll = function()
		assert(ns.C.layout.bars.size == 60)
		assert(ns.C.bossmods.normal.x == 1234 and ns.C.chat.x == 111)
		assert(ns.C.colors.cdMain == color and color[1] == 0.2)
		assert(SlimARKDB.settings['layout.bars.size'] == 60)
		applied = true
		return true
	end
	assert(s.Save() and applied and s.PendingCount() == 0)
end

do
	local ns, s = settings({ ['layout.bars.size'] = 55 })
	local old = { x = 99, y = 77, scale = 1.2 }
	local healer = { x = 66, y = 55 }
	ns.CharDB.pos = { markers = old, cooldownicons = old }
	ns.CharDB.posHeal = { markers = healer, cooldownicons = healer }
	s.Set('layout.bars.size', 60)
	s.Set('markers.place', 'party')
	s.Set('cooldowns.iconY', 800)
	s.Set('cooldowns.x', 123)
	s.Set('cooldowns.y', 234)
	ns.ApplyAll = function()
		assert(ns.C.layout.bars.size == 60)
		assert(not ns.CharDB.pos.markers and not ns.CharDB.pos.cooldownicons)
		return false
	end
	local before = reloads
	assert(s.Save() == false and reloads == before)
	assert(ns.C.layout.bars.size == 55 and SlimARKDB.settings['layout.bars.size'] == 55)
	assert(ns.C.markers.place == 'map' and SlimARKDB.settings['markers.place'] == nil)
	assert(ns.CharDB.pos.markers == old and ns.CharDB.pos.cooldownicons == old)
	assert(ns.CharDB.posHeal.markers == healer and ns.CharDB.posHeal.cooldownicons == healer)
	assert(s.PendingCount() == 5 and s.Value('layout.bars.size') == 60)
	ns.ApplyAll = function() return true end
	assert(s.Save())
	assert(SlimARKDB.settings['layout.bars.size'] == 60 and ns.C.layout.bars.size == 60)
	assert(not ns.CharDB.pos.markers and not ns.CharDB.pos.cooldownicons)
	assert(not ns.CharDB.posHeal.markers and not ns.CharDB.posHeal.cooldownicons)
end

do
	local ns, s = settings()
	ns.CharDB.pos = { cooldownicons = { x = 42 } }
	s.Set('cooldowns.iconGap', 9)
	local before = reloads
	assert(s.Save() and reloads == before + 1)
	assert(ns.CharDB.pos.cooldownicons.x == 42, 'Non-position changes must preserve dragged positions')
	s.Set('layout.bars.size', 60)
	locked = true
	assert(s.Save() == false)
	assert(SlimARKDB.settings['layout.bars.size'] == nil and ns.C.layout.bars.size ~= 60)
	assert(s.PendingCount() == 1)
	locked = false
end

