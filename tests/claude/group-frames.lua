-- H1: group frames (audit F2, F5). Run from the repository root:
--   lua5.1 tests/claude/group-frames.lua
local H = dofile('tests/claude/lib/helpers.lua')

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

------------------------------------------------------------------------
-- Debuff tint: a typed debuff colors the health area on the player and the group frames.
------------------------------------------------------------------------
do
	-- The slots a styled frame asked for: { filter, options } per AddSlot call of its aura elements.
	local function Slots(frame)
		local list = {}
		for _, f in ipairs(H.frames) do
			if f._parent == frame then
				for _, call in ipairs(H.calls(f, 'AddSlot')) do list[#list + 1] = call end
			end
		end
		return list
	end
	local function Typed(slots)
		for _, call in ipairs(slots) do
			local filters = call[2].candidateFilters
			if call[1] == 'HARMFUL' and filters and filters.includeDispelTypes then return call end
		end
	end
	local function Styled(parent, unit, features)
		local ns, oUF = Boot({}, 'DAMAGER')
		for key, value in pairs(features or {}) do ns.C.features[key] = value end
		local frame = H.NewFrame('Button', nil, parent and _G[parent] or UIParent)
		frame.colors = { dispel = { Poison = {} } }
		_G.UnitClassBase = function() return 'PALADIN' end
		oUF.styles['SlimARK-UI'](frame, unit)
		return frame, ns
	end

	for _, case in ipairs({ { nil, 'player' }, { 'SlimARK_Party' }, { 'SlimARK_Raid' }, { 'SlimARK_HealParty' } }) do
		local label = case[2] or case[1]
		local frame = Styled(case[1], case[2])
		local slots = Slots(frame)
		local typed = Typed(slots)
		H.check(typed ~= nil, 'tint ' .. label .. ': a slot for any typed debuff')
		local types = typed and typed[2].candidateFilters.includeDispelTypes or {}
		H.check(types.Magic and types.Curse and types.Disease and types.Poison and types.Bleed,
			'tint ' .. label .. ': magic, curse, disease, poison and bleed all color the frame')
		local mine = 0
		for _, call in ipairs(slots) do if call[1] == 'HARMFUL|RAID' then mine = mine + 1 end end
		H.equal(mine, case[2] == 'player' and 1 or 2, 'tint ' .. label .. ': what you can dispel has its own slot above')

		-- The button of the slot: a fill and four edges, all colored by the game from the type.
		local button = H.NewFrame('Frame', nil, frame)
		local textures = {}
		function button:AddDispelTypeTexture(texture, options) textures[#textures + 1] = { texture, options } end
		local ok, err = pcall(typed[2].CreateButton, H.NewFrame('Frame', nil, frame), nil, button)
		H.check(ok, 'tint ' .. label .. ': the button builds without an error: ' .. tostring(err))
		H.equal(#textures, 5, 'tint ' .. label .. ': a fill and four edges')
		local fill = textures[1] and textures[1][1]
		H.check(fill and fill:GetAlpha() < 1, 'tint ' .. label .. ': the fill is see-through, the health level stays readable')
		for _, t in ipairs(textures) do
			H.equal(t[2].customDispelColorMap, frame.colors.dispel, 'tint ' .. label .. ': the game\'s own type colors')
		end
		H.equal(#H.calls(button, 'EnableMouse'), 1, 'tint ' .. label .. ': the button takes no clicks')
	end

	-- The colored layer follows the health area, not the button: the player's health shrinks
	-- while the class power shows.
	do
		local frame = Styled(nil, 'player')
		local typed = Typed(Slots(frame))
		local container
		for _, f in ipairs(H.frames) do
			if f._parent == frame then
				for _, call in ipairs(H.calls(f, 'AddSlot')) do if call == typed then container = f end end
			end
		end
		H.equal(H.lastCall(container, 'SetAllPoints')[1], frame.Health, 'tint player: the slot sits on the health bar')
		local button = H.NewFrame('Frame', nil, frame)
		function button:AddDispelTypeTexture() end
		local before = #H.frames
		typed[2].CreateButton(container, nil, button)
		local layer
		for i = before + 1, #H.frames do
			if H.frames[i]._parent == button and H.frames[i]._kind == 'Frame' then layer = H.frames[i] end
		end
		H.check(layer and H.lastCall(layer, 'SetAllPoints')[1] == container, 'tint player: the colored layer follows the health area')
	end

	-- Off with the Dispel highlight switch; other frames never get it.
	H.check(Typed(Slots((Styled(nil, 'player', { dispelGlow = false })))) == nil, 'tint off: no slot on the player frame')
	H.check(Typed(Slots((Styled('SlimARK_Party', nil, { dispelGlow = false })))) == nil, 'tint off: no slot on a party frame')
	H.check(Typed(Slots((Styled(nil, 'target')))) == nil, 'tint: the target frame has none')
	H.check(Typed(Slots((Styled(nil, 'focus')))) == nil, 'tint: the focus frame has none')
end

H.done()
