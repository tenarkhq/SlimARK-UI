local _, ns = ...

-- Két elrendezés van: DPS és tank közös, a gyógyító külön. A spec dönt, harc közben a váltás vár.
local headers, listeners = {}, {}
local pending = false

-- A mostani spec azonosítója és szerepe. Spec nélkül mindkettő üres.
function ns.SpecInfo()
	local index = C_SpecializationInfo.GetSpecialization()
	if not index or index == 0 then return end
	local id, _, _, _, role = C_SpecializationInfo.GetSpecializationInfo(index)
	return id, role
end

local function IsHealerSpec()
	local _, role = ns.SpecInfo()
	return role == 'HEALER'
end

-- Betöltéskor a keretek már a jó helyen jönnek létre, ezért itt nincs mozgatás.
function ns.ReadRole()
	ns.healer = IsHealerSpec()
end

-- Mindkét szerep csoportkeretei léteznek, mindig csak az egyiké látszik.
local function ShowHeader(entry)
	entry.header:SetVisibility(entry.forHealer == ns.healer and entry.visibility or 'custom hide')
end

function ns.AddGroupHeader(header, forHealer, visibility)
	local entry = { header = header, forHealer = forHealer, visibility = visibility }
	table.insert(headers, entry)
	ShowHeader(entry)
end

function ns.OnRole(fn)
	table.insert(listeners, fn)
end

local function Check()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false

	local healer = IsHealerSpec()
	if healer ~= ns.healer then
		ns.healer = healer
		for _, item in ipairs(ns.Placed) do ns.Place(item) end
		for _, entry in ipairs(headers) do ShowHeader(entry) end
		for _, fn in ipairs(listeners) do fn() end
	end
	ns.SyncLayout()
end

ns.On('PLAYER_LOGIN', ns.ReadRole)
ns.On('PLAYER_SPECIALIZATION_CHANGED', function(_, unit)
	if unit == 'player' then Check() end
end)
ns.On('PLAYER_REGEN_ENABLED', function()
	if pending then Check() end
end)
ns.On('PLAYER_ENTERING_WORLD', function(_, isLogin, isReload)
	if isLogin or isReload then C_Timer.After(3, Check) end
end)
