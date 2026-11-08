local _, ns = ...

-- There are two layouts: DPS and tank share one, the healer has its own. The spec decides, and in combat the switch waits.
local headers, listeners = {}, {}
local pending = false

-- ID and role of the current spec. Both are empty without a spec.
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

-- At load the frames are created in the right place already, so there is no moving here.
function ns.ReadRole()
	ns.healer = IsHealerSpec()
end

-- The group frames of both roles exist, but only one of them is shown at a time.
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

-- The test mode shows the other layout: the SlimARK frames move as on a spec change, Blizzard's
-- Edit Mode layout stays. nil goes back to the layout of the spec. Only out of combat.
function ns.PreviewLayout(healer)
	if InCombatLockdown() then return end
	if healer == nil then healer = IsHealerSpec() end
	ns.previewHealer = healer ~= IsHealerSpec() or nil
	if healer == ns.healer then return end
	ns.healer = healer
	for _, item in ipairs(ns.Placed) do ns.Place(item) end
	for _, entry in ipairs(headers) do ShowHeader(entry) end
	for _, fn in ipairs(listeners) do fn() end
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
