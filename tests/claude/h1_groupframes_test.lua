-- H1: group frames (audit F2, F5). Run from the repository root:
--   lua5.1 tests/claude/h1_groupframes_test.lua
local H = dofile('tests/claude/helpers.lua')

-- A stand-in for oUF with only what UnitFrames.lua uses. SpawnHeader copies one real oUF
-- behaviour (Libs/oUF/ouf.lua:820-821): a header made with showParty switches Blizzard's
-- party frames off for good.
local function FakeOUF()
	local oUF = { Tags = { Methods = {}, Events = {} }, styles = {}, factories = {} }
	function oUF:RegisterStyle(name, fn) self.styles[name] = fn end
	function oUF:Factory(fn) table.insert(self.factories, fn) end
	function oUF:SetActiveStyle() end
	function oUF:Spawn(_, name) return H.NewFrame('Button', name, UIParent) end
	function oUF:SpawnHeader(name, _, ...)
		local header = H.NewFrame('Frame', name, UIParent)
		for i = 1, select('#', ...), 2 do
			header:SetAttribute((select(i, ...)), (select(i + 1, ...)))
		end
		function header:SetVisibility(value) self.visibility = value end
		if header:GetAttribute('showParty') then
			PartyFrame:UnregisterAllEvents()
			PartyFrame:SetRolesets('alwaysBlocked')
		end
		return header
	end
	return oUF
end

local spec = 'DAMAGER'

-- Loads Config, Core, Role and UnitFrames with the given modules and runs the login.
local function Boot(modules, role, inCombat)
	local ns = H.setup()
	spec = role or 'DAMAGER'
	_G.C_SpecializationInfo = {
		GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function() return 71, nil, nil, nil, spec end,
	}
	_G.PartyFrame = H.NewFrame('Frame', 'PartyFrame', UIParent)
	_G.CompactRaidFrameContainer = H.NewFrame('Frame', 'CompactRaidFrameContainer', UIParent)
	_G.CompactPartyFrame = nil
	local oUF = FakeOUF()
	ns.oUF = oUF
	H.load('Config.lua')
	for key, value in pairs(modules) do ns.C.modules[key] = value end
	H.load('Core.lua')
	H.load('Role.lua')
	H.load('UnitFrames.lua')
	ns.SyncLayout = function() end
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	H.fire('PLAYER_LOGIN')
	H.combat = inCombat and true or false
	for _, fn in ipairs(oUF.factories) do fn(oUF) end
	return ns, oUF
end

local function SwitchSpec(role)
	spec = role
	H.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
end

local function HardBlocked(frame) return #H.calls(frame, 'UnregisterAllEvents') > 0 end

------------------------------------------------------------------------
-- F2: Blizzard's group frames stay for the role without a SlimARK frame in their place.
------------------------------------------------------------------------
do
	-- Every module on (the default): both roles covered, Blizzard's frames off for good.
	Boot({}, 'DAMAGER')
	H.check(HardBlocked(PartyFrame), 'F2 default: Blizzard party frames switched off for good')
	H.equal(PartyFrame._roleset, 'alwaysBlocked', 'F2 default: party roleset')
	H.check(HardBlocked(CompactRaidFrameContainer), 'F2 default: Blizzard raid frames switched off for good')
	SwitchSpec('HEALER')
	H.equal(PartyFrame._roleset, 'alwaysBlocked', 'F2 default: party stays blocked for the healer')
end

do
	-- The audit's case (T02): DPS with Party and Raid off, healer grid on.
	Boot({ party = false, raid = false, grid = true }, 'DAMAGER')
	H.check(not HardBlocked(PartyFrame), 'F2 grid only, DPS: Blizzard party frames keep running')
	H.equal(PartyFrame._roleset, 'unitFrames', 'F2 grid only, DPS: Blizzard party frames shown')
	H.check(not HardBlocked(CompactRaidFrameContainer), 'F2 grid only, DPS: Blizzard raid frames keep running')
	H.check(#H.calls(CompactRaidFrameContainer, 'SetRolesets') > 0 and CompactRaidFrameContainer._roleset == nil,
		'F2 grid only, DPS: Blizzard raid frames shown (roleset cleared)')
	H.equal(SlimARK_HealParty:GetAttribute('showParty'), true, 'F2 grid only: the grid still shows the party')
	H.equal(SlimARK_HealParty.visibility, 'custom hide', 'F2 grid only, DPS: the grid is hidden')

	SwitchSpec('HEALER')
	H.equal(PartyFrame._roleset, 'alwaysBlocked', 'F2 grid only, healer: Blizzard party frames hidden')
	H.equal(CompactRaidFrameContainer._roleset, 'alwaysBlocked', 'F2 grid only, healer: Blizzard raid frames hidden')
	H.check(SlimARK_HealParty.visibility ~= 'custom hide', 'F2 grid only, healer: the grid is shown')

	SwitchSpec('DAMAGER')
	H.equal(PartyFrame._roleset, 'unitFrames', 'F2 grid only, back to DPS: Blizzard party frames come back')
	H.equal(CompactRaidFrameContainer._roleset, nil, 'F2 grid only, back to DPS: Blizzard raid frames come back')
end

do
	-- The other way round: Party and Raid on, healer grid off, logged in as a healer.
	Boot({ party = true, raid = true, grid = false }, 'HEALER')
	H.check(not HardBlocked(PartyFrame), 'F2 no grid, healer: Blizzard party frames keep running')
	H.equal(PartyFrame._roleset, 'unitFrames', 'F2 no grid, healer: Blizzard party frames shown')
	H.equal(SlimARK_Party:GetAttribute('showParty'), true, 'F2 no grid: the DPS party header still shows the party')
	SwitchSpec('DAMAGER')
	H.equal(PartyFrame._roleset, 'alwaysBlocked', 'F2 no grid, DPS: Blizzard party frames hidden')
	H.equal(CompactRaidFrameContainer._roleset, 'alwaysBlocked', 'F2 no grid, DPS: Blizzard raid frames hidden')
end

do
	-- Nothing of ours: Blizzard's frames are not touched at all.
	Boot({ party = false, raid = false, grid = false }, 'DAMAGER')
	H.check(not HardBlocked(PartyFrame) and #H.calls(PartyFrame, 'SetRolesets') == 0, 'F2 all off: party frames untouched')
	H.check(#H.calls(CompactRaidFrameContainer, 'SetRolesets') == 0, 'F2 all off: raid frames untouched')
end

do
	-- A reload in combat: the roleset waits for the end of combat.
	Boot({ party = false, raid = false, grid = true }, 'HEALER', true)
	H.equal(#H.calls(PartyFrame, 'SetRolesets'), 0, 'F2 in combat: no roleset change yet')
	H.combat = false
	H.fire('PLAYER_REGEN_ENABLED')
	H.equal(PartyFrame._roleset, 'alwaysBlocked', 'F2 after combat: the healer\'s party roleset is set')
end

------------------------------------------------------------------------
-- F5: the aggro frame follows oUF's unit (__unit), not the tooltip's .unit.
------------------------------------------------------------------------
do
	local _, oUF = Boot({}, 'DAMAGER')
	local style = oUF.styles['SlimARK-UI']
	local frame = H.NewFrame('Button', nil, SlimARK_Party)
	style(frame, nil)
	local aggro = frame.ThreatIndicator
	H.check(aggro and aggro.Override ~= nil, 'F5 party frame has the aggro element')

	local threat = { party1 = 3, party2 = 0 }
	_G.UnitThreatSituation = function(unit) return threat[unit] end
	_G.UnitExists = function(unit) return threat[unit] ~= nil end

	-- Never hovered: .unit is nil, oUF's unit is party1, a mob hits it.
	frame.__unit = 'party1'
	aggro:Hide()
	aggro.Override(frame, 'UNIT_THREAT_SITUATION_UPDATE', 'party1')
	H.equal(aggro:IsShown(), true, 'F5 aggro shows on a frame the mouse never touched')

	aggro.Override(frame, 'UNIT_THREAT_SITUATION_UPDATE', 'party2')
	H.equal(aggro:IsShown(), true, 'F5 an event for another unit leaves it alone')

	-- The frame is reused for party2; the tooltip had left .unit = party1 behind.
	frame.unit, frame.__unit = 'party1', 'party2'
	aggro.Override(frame, 'ForceUpdate', 'party2')
	H.equal(aggro:IsShown(), false, 'F5 after reuse the new unit\'s threat counts, not the stale .unit')

	-- A hidden (secret) threat value hides the frame.
	frame.__unit = 'party1'
	H.secret = { [3] = true }
	aggro:Show()
	aggro.Override(frame, 'UNIT_THREAT_SITUATION_UPDATE', 'party1')
	H.equal(aggro:IsShown(), false, 'F5 a secret threat value hides the frame')
	H.secret = nil

	-- No unit at all: hidden, no error.
	frame.__unit = nil
	aggro:Show()
	local ok = pcall(aggro.Override, frame, 'ForceUpdate', nil)
	H.check(ok and not aggro:IsShown(), 'F5 without a unit the frame hides without an error')
end

H.done()
