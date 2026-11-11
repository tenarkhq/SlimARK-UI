local H = dofile('tests/codex/lib/runtime.lua')
local world

local function Boot(options)
	options = options or {}
	local ns = H.boot()
	world = { cached = options.cached ~= false, requests = 0, auras = {}, sync = options.sync }
	ns.DB.effectBuffs = options.store or { [111] = 999, potions = { [999] = true } } -- unverified old learning
	NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
	GetInventoryItemID = function(_, slot) return slot == 13 and 111 or nil end
	GetInventoryItemTexture = function() return 1 end
	GetInventoryItemCooldown = function() return 0 end
	C_Item = {
		IsItemDataCachedByID = function() return world.cached end,
		GetItemNameByID = function() return world.cached and 'Trinket' end,
		GetItemSpell = function(item)
			if item == 222 then return 'Potion spell', 2222 end
			if world.cached then return 'Trinket spell', 1111 end
		end,
		GetItemInfoInstant = function() return nil, nil, nil, nil, nil, Enum.ItemClass.Consumable, Enum.ItemConsumableSubclass.Potion end,
		RequestLoadItemDataByID = function(id)
			world.requests = world.requests + 1
			if world.sync then world.cached = true H.fire('ITEM_DATA_LOAD_RESULT', id, true) end
		end,
	}
	C_Container = {
		GetContainerNumSlots = function() return 1 end,
		GetContainerItemInfo = function() return { itemID = 222, iconFileID = 2 } end,
		GetItemCooldown = function() return 0 end,
	}
	C_StringUtil = { CreateSecondsFormatter = function()
		return { SetDefaultAbbreviation = function() end, SetMinInterval = function() end }
	end }
	C_DurationUtil = { CreateDurationTextBinding = function()
		return { SetFormatter = function() end, SetFontString = function() end, SetExpiredText = function() end,
			SetDuration = function() end, SetEnabled = function(self, enabled) self.enabled = enabled end }
	end }
	C_UnitAuras = {
		GetAuraDuration = function(_, instance) return world.auras[instance] and {} end,
		GetAuraDataByAuraInstanceID = function(_, instance) return world.auras[instance] end,
		GetPlayerAuraBySpellID = function(id)
			for _, aura in pairs(world.auras) do if aura.spellId == id then return aura end end
		end,
	}
	ns.Register = function() end
	H.load('ActiveEffects.lua')
	H.fire('PLAYER_LOGIN')
	H.noErrors()
	local icons = {}
	for _, frame in ipairs(H.frames) do
		if frame.Estimate then
			frame.Icon.GetTexture = function(self) return H.lastCall(self, 'SetTexture')[1] end
			icons[#icons + 1] = frame
		end
	end
	return ns, icons
end

local function Aura(id, name, instance)
	local aura = { spellId = id, name = name or 'Unrelated buff', auraInstanceID = instance or 50, isHelpful = true, icon = 3 }
	world.auras[aura.auraInstanceID] = aura
	H.fire('UNIT_AURA', 'player', { addedAuras = { aura } })
end

local function Remove(instance)
	world.auras[instance] = nil
	H.fire('UNIT_AURA', 'player', { removedAuraInstanceIDs = { instance } })
end

do
	local ns, icons = Boot()
	assert(ns.DB.effectBuffs.version == 2 and ns.DB.effectBuffs[111] == 1111)
	assert(not ns.DB.effectBuffs.potions[999], 'Legacy guesses are removed once')
	H.fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 1111)
	H.now = H.now + 0.5
	Aura(999)
	assert(icons[1]:IsShown() and icons[1].Estimate:IsShown(), 'A timing guess is visibly marked')
	assert(ns.DB.effectBuffs[111] == 1111 and not ns.DB.effectBuffs.potions[999], 'A timing guess is never persisted')
	H.fire('UNIT_AURA', 'player', { updatedAuraInstanceIDs = { 50 } })
	assert(icons[1].Estimate:IsShown(), 'Refreshing a guessed duration keeps the estimate marker')
	Remove(50)
	Aura(999)
	assert(not icons[1]:IsShown(), 'The unrelated spell was not added to the in-memory known IDs')
	Aura(1111, 'Trinket spell', 51)
	assert(icons[1]:IsShown() and not icons[1].Estimate:IsShown(), 'An exact item spell is not an estimate')
	H.noErrors()
end

do
	local ns, icons = Boot()
	Aura(999)
	H.now = H.now + 0.2
	H.fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 1111)
	assert(icons[1]:IsShown() and icons[1].Estimate:IsShown(), 'Aura-before-cast ordering remains provisional')
	assert(ns.DB.effectBuffs[111] == 1111)
	H.noErrors()
end

do
	local ns, icons = Boot({ cached = false })
	assert(world.requests == 1)
	H.fire('ITEM_DATA_LOAD_RESULT', 111, false)
	H.runTimers(1)
	assert(world.requests == 2, 'A failed load schedules a bounded retry')
	world.cached = true
	H.fire('ITEM_DATA_LOAD_RESULT', 111, true)
	Aura(1111, 'Trinket spell')
	assert(icons[1]:IsShown() and not icons[1].Estimate:IsShown() and ns.DB.effectBuffs[111] == 1111,
		'A later success repairs item metadata and exact aura matching')
	H.noErrors()
end

do
	Boot({ cached = false })
	for _ = 1, 5 do H.fire('ITEM_DATA_LOAD_RESULT', 111, false) H.runTimers(1) end
	assert(world.requests == 3, 'Repeated failures do not create an unbounded request loop')
	H.fire('PLAYER_ENTERING_WORLD')
	assert(world.requests == 4, 'A later world transition permits another bounded attempt')
	H.noErrors()
end

do
	local _, icons = Boot({ cached = false, sync = true })
	Aura(1111, 'Trinket spell')
	assert(world.requests == 1 and icons[1]:IsShown(), 'A synchronous item-data response is handled')
	H.noErrors()
end

do
	local ns = Boot()
	local saved = ns.DB.effectBuffs
	local reloaded, icons = Boot({ cached = false, store = saved })
	Aura(1111, 'Trinket spell')
	assert(reloaded.DB.effectBuffs == saved and icons[1]:IsShown() and not icons[1].Estimate:IsShown(),
		'Verified item spell IDs survive reload while item metadata is loading')
	H.noErrors()
end
