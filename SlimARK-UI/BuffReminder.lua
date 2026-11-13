local _, ns = ...
local C = ns.C

------------------------------------------------------------------------
-- 22: before the pull, what you are missing, as icons above the cooldown bars: the buff your
-- class gives the group, the weapon oil or imbue, the shaman's shield, the pet. Only out of
-- combat in a dungeon, raid or other instance; nothing shows when all is there. Auras can be
-- hidden from addons in a running key: then nothing is claimed missing and the row stays empty.
------------------------------------------------------------------------

-- The buff your class gives, by class: the spell you cast and the buffs it leaves on you
-- (Blessing of the Bronze leaves one per class).
local CLASS_BUFF = {
	MAGE = { 1459, { 1459 } },
	PRIEST = { 21562, { 21562 } },
	WARRIOR = { 6673, { 6673 } },
	DRUID = { 1126, { 1126 } },
	SHAMAN = { 462854, { 462854 } },
	EVOKER = { 364342, { 381748, 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758 } },
}

-- Rogue poisons are buffs on the rogue, not weapon enchants: one lethal poison is wanted. Instant
-- and Wound Poison are class spells; Deadly and Amplifying Poison are Assassination talents.
local LETHAL_POISONS = { 2823, 315584, 8679, 381664 }

-- Shaman shields: Lightning Shield, Water Shield, Earth Shield (on another and on yourself).
local SHIELD_SPELLS = { 192106, 52127 }
local SHIELDS = { 192106, 52127, 974, 383648 }

-- Classes that fight with a pet, by spec (false: that spec has none). The spell gives the icon.
local PET = {
	HUNTER = { spell = 883, specs = { [253] = true, [255] = true } },
	WARLOCK = { spell = 688, sacrifice = 196099 },
	DEATHKNIGHT = { spell = 46584, specs = { [252] = true } },
}

local OIL_ICON = [[Interface\Icons\INV_Sword_04]]
local frame, label
local icons = {}
local watch, queued = nil, false
local testing = false

local function Known(id)
	if IsPlayerSpell then return IsPlayerSpell(id) end
	return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) or false
end

local function HasAura(ids)
	for _, id in ipairs(ids) do
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
		if ok and aura then return true end
	end
	return false
end

-- Each missing thing: icon and name.
local function Missing()
	local list = {}
	local _, class = UnitClass('player')
	local buff = CLASS_BUFF[class]
	if buff and Known(buff[1]) and not HasAura(buff[2]) then
		list[#list + 1] = { C_Spell.GetSpellTexture(buff[1]), C_Spell.GetSpellName(buff[1]) }
	end
	-- The weapon: a temporary enchant (oil, stone, a shaman's or paladin's imbue) on the main hand.
	if GetInventoryItemID('player', INVSLOT_MAINHAND or 16) and C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
		if not C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND or 16) then
			list[#list + 1] = { OIL_ICON, 'weapon oil' }
		end
	end
	if class == 'ROGUE' and not HasAura(LETHAL_POISONS) then
		for _, id in ipairs(LETHAL_POISONS) do
			if Known(id) then
				list[#list + 1] = { C_Spell.GetSpellTexture(id), 'poison' }
				break
			end
		end
	end
	if class == 'SHAMAN' and not HasAura(SHIELDS) then
		for _, id in ipairs(SHIELD_SPELLS) do
			if Known(id) then
				list[#list + 1] = { C_Spell.GetSpellTexture(id), C_Spell.GetSpellName(id) }
				break
			end
		end
	end
	local pet = PET[class]
	if pet and not IsMounted() then
		local spec = ns.SpecInfo()
		local wanted = not pet.specs or (spec and pet.specs[spec])
		if wanted and pet.sacrifice and HasAura({ pet.sacrifice }) then wanted = false end
		if wanted and (not UnitExists('pet') or UnitIsDead('pet')) then
			list[#list + 1] = { C_Spell.GetSpellTexture(pet.spell), 'pet' }
		end
	end
	return list
end

local function Frame()
	if frame then return frame end
	local cfg = C.buffreminder
	frame = CreateFrame('Frame', 'SlimARK_BuffReminder', UIParent)
	frame:SetSize(4 * (cfg.size + cfg.gap) + 300, cfg.size)
	ns.Register(frame, cfg.x, cfg.y, { key = 'buffreminder', heal = { x = cfg.heal.x, y = cfg.heal.y } })
	label = ns.Text(frame, cfg.font)
	label:SetTextColor(1, 0.54, 0.48)
	frame:Hide()
	return frame
end

local function Icon(i)
	local cfg = C.buffreminder
	local f = icons[i]
	if f then return f end
	f = CreateFrame('Frame', nil, frame)
	f:SetSize(cfg.size, cfg.size)
	f:SetPoint('LEFT', (i - 1) * (cfg.size + cfg.gap), 0)
	ns.Outline(f)
	f.tex = f:CreateTexture(nil, 'ARTWORK')
	f.tex:SetAllPoints()
	f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.tex:SetDesaturated(true)
	ns.Edge(f, 2, { 1, 0.23, 0.19 }, 0)
	icons[i] = f
	return f
end

local function Show(list)
	Frame()
	for _, f in ipairs(icons) do f:Hide() end
	if #list == 0 then
		frame:Hide()
		return
	end
	local names = {}
	for i, item in ipairs(list) do
		local f = Icon(i)
		f.tex:SetTexture(item[1] or OIL_ICON)
		f:Show()
		names[i] = item[2] or ''
	end
	label:ClearAllPoints()
	label:SetPoint('LEFT', icons[#list], 'RIGHT', 6, 0)
	label:SetText('Missing: ' .. table.concat(names, ', '))
	frame:Show()
end

local function Wanted()
	if InCombatLockdown() or UnitIsDeadOrGhost('player') then return false end
	local inInstance = IsInInstance()
	if not inInstance then return false end
	-- Hidden auras would all look missing.
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return false end
	return true
end

local function Update()
	queued = false
	if testing then return end
	if not Wanted() then
		if frame then frame:Hide() end
		return
	end
	Show(Missing())
end

-- A burst of aura or bag events checks once, a moment later.
local function Queue()
	if queued then return end
	queued = true
	C_Timer.After(0.2, Update)
end

-- Your auras are only watched out of combat: in combat the row is hidden anyway.
local function OnEvent(_, event)
	if event == 'PLAYER_REGEN_DISABLED' then
		watch:UnregisterEvent('UNIT_AURA')
		if frame and not testing then frame:Hide() end
		return
	elseif event == 'PLAYER_REGEN_ENABLED' then
		watch:RegisterUnitEvent('UNIT_AURA', 'player')
	end
	Queue()
end

local function Test(on)
	testing = on
	if on then
		local _, class = UnitClass('player')
		local buff = CLASS_BUFF[class] or CLASS_BUFF.WARRIOR
		Show({ { C_Spell.GetSpellTexture(buff[1]), C_Spell.GetSpellName(buff[1]) }, { OIL_ICON, 'weapon oil' } })
	else
		if frame then frame:Hide() end
		Update()
	end
end

ns.On('PLAYER_LOGIN', function()
	if not C.features.buffReminder then return end
	Frame()
	watch = CreateFrame('Frame')
	watch:RegisterUnitEvent('UNIT_AURA', 'player')
	watch:RegisterUnitEvent('UNIT_INVENTORY_CHANGED', 'player')
	watch:RegisterUnitEvent('UNIT_PET', 'player')
	watch:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
	watch:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')
	watch:RegisterEvent('PLAYER_ENTERING_WORLD')
	watch:RegisterEvent('ZONE_CHANGED_NEW_AREA')
	watch:RegisterEvent('PLAYER_MOUNT_DISPLAY_CHANGED')
	watch:RegisterEvent('SPELLS_CHANGED')
	watch:RegisterEvent('PLAYER_REGEN_DISABLED')
	watch:RegisterEvent('PLAYER_REGEN_ENABLED')
	watch:RegisterEvent('PLAYER_ALIVE')
	watch:RegisterEvent('PLAYER_UNGHOST')
	watch:SetScript('OnEvent', OnEvent)
	ns.TestParts = ns.TestParts or {}
	table.insert(ns.TestParts, Test)
	Queue()
end)
