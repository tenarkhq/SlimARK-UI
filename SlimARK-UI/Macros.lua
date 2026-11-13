local _, ns = ...

-- 3.0 (49) Macro maker. Each button of the Macros page makes one macro, or rewrites it when a macro
-- of that name is already there: your interrupt on your focus, your dispel on the frame under the
-- mouse, your healthstone and a healing potion. Spell names come from the game in your language.
-- Macros change out of combat only: a click in combat is done when the fight ends. Nothing runs
-- until a button is pressed.
local M = {}
ns.Macros = M

-- The question mark icon: the game shows the spell or item of the #showtooltip line.
local ICON = 134400
local NAMES = { kick = 'SlimARK Kick', dispel = 'SlimARK Dispel', heal = 'SlimARK Heal' }
local LABELS = { kick = 'focus kick', dispel = 'mouseover dispel', heal = 'healthstone + potion' }

-- Interrupts, your own before the pet's: Rebuke, Kick, Pummel, Mind Freeze, Counterspell, Wind Shear,
-- Skull Bash, Solar Beam, Spear Hand Strike, Counter Shot, Muzzle, Disrupt, Quell, Silence; then the
-- warlock's Spell Lock (pet, command and sacrificed) and the felguard's Axe Toss.
local KICKS = { 96231, 1766, 6552, 47528, 2139, 57994, 106839, 78675, 116705, 147362, 187707, 183752, 351338,
	15487, 19647, 119910, 132409, 119914 }
-- Dispels on friends, the healer one first: Nature's Cure, Remove Corruption, Purify Spirit, Cleanse
-- Spirit, Purify, Purify Disease, Cleanse, Cleanse Toxins, Detox (Mistweaver), Detox, Remove Curse,
-- Naturalize, Expunge.
local DISPELS = { 88423, 2782, 77130, 51886, 527, 213634, 4987, 213644, 115450, 218164, 475, 360823, 365585 }
-- The demonic healthstone of the warlock talent first, then the common one.
local STONES = { 224464, 5512 }
-- Healing potions, best first: Midnight (Concentrated Silvermoon, Silvermoon), The War Within (Algari).
local POTIONS = { 271884, 271883, 241304, 241305, 211880, 211879, 211878 }

local pending = {}
local waiter

local function Known(id)
	local book = C_SpellBook
	if not (book and book.IsSpellKnownOrInSpellBook) then return false end
	if book.IsSpellKnownOrInSpellBook(id) then return true end
	local pet = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
	return pet ~= nil and book.IsSpellKnownOrInSpellBook(id, pet) == true
end

local function FirstSpell(list)
	for _, id in ipairs(list) do
		local name = Known(id) and C_Spell.GetSpellName(id)
		if name then return name end
	end
end

local function InBags(id)
	local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0
	return count > 0
end

-- The macro text, or nil and the reason in plain words.
local function Body(kind)
	if kind == 'kick' then
		local name = FirstSpell(KICKS)
		if not name then return nil, 'You know no interrupt, so there is no focus kick macro to make.' end
		return '#showtooltip\n/cast [@focus,harm,nodead][] ' .. name
	elseif kind == 'dispel' then
		local name = FirstSpell(DISPELS)
		if not name then return nil, 'You know no dispel for friends, so there is no dispel macro to make.' end
		return '#showtooltip\n/cast [@mouseover,help,nodead][] ' .. name
	elseif kind == 'heal' then
		local stone = InBags(STONES[1]) and STONES[1] or STONES[2]
		local lines = { '#showtooltip', '/use item:' .. stone }
		for _, id in ipairs(POTIONS) do
			if InBags(id) then
				lines[#lines + 1] = '/use item:' .. id
				break
			end
		end
		if #lines == 2 then
			ns.Print('No healing potion in your bags: the macro uses the healthstone only. Update it when you have potions.')
		end
		return table.concat(lines, '\n')
	end
end

function M.Scope()
	return ns.DB and ns.DB.macroScope or 'character'
end

function M.SetScope(scope)
	if ns.DB then ns.DB.macroScope = scope end
end

local function Exists(kind)
	return (GetMacroIndexByName(NAMES[kind]) or 0) > 0
end

function M.Label(kind)
	return (Exists(kind) and 'Update ' or 'Create ') .. LABELS[kind]
end

local function Room(perCharacter)
	local account, character = GetNumMacros()
	local consts = Constants and Constants.MacroConsts or {}
	if perCharacter then return (character or 0) < (consts.MAX_CHARACTER_MACROS or 30) end
	return (account or 0) < (consts.MAX_ACCOUNT_MACROS or 120)
end

local function Write(kind)
	local body, problem = Body(kind)
	if not body then
		ns.Print(problem)
		return false
	end
	local name = NAMES[kind]
	local index = GetMacroIndexByName(name) or 0
	if index > 0 then
		EditMacro(index, name, ICON, body)
		ns.Print(name .. ' is up to date.')
		return true
	end
	local perCharacter = M.Scope() == 'character'
	if not Room(perCharacter) then
		ns.Print(('Your %s macros are full. Delete one in the macro window and try again.'):format(perCharacter and 'character' or 'account'))
		return false
	end
	CreateMacro(name, ICON, body, perCharacter)
	ns.Print(name .. ' is made. Drag it from the macro window (/macro) to a bar.')
	return true
end

local function AfterCombat()
	waiter:UnregisterEvent('PLAYER_REGEN_ENABLED')
	for _, kind in ipairs({ 'kick', 'dispel', 'heal' }) do
		if pending[kind] then
			pending[kind] = nil
			Write(kind)
		end
	end
end

-- Makes or updates the macro. In combat it waits for the end of the fight.
function M.Make(kind)
	if not NAMES[kind] then return false end
	if InCombatLockdown() then
		pending[kind] = true
		if not waiter then
			waiter = CreateFrame('Frame')
			waiter:SetScript('OnEvent', AfterCombat)
		end
		waiter:RegisterEvent('PLAYER_REGEN_ENABLED')
		ns.Print('In combat: the macro is made when the fight ends.')
		return 'later'
	end
	return Write(kind)
end
