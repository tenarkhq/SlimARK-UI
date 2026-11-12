local _, ns = ...
local C = ns.C

-- Quick focus: the modifier with a left click on a unit in the world or on a nameplate makes it
-- your focus. A secure button runs "/focus mouseover" and takes that click from the world, so
-- with the modifier held the left click no longer targets or turns the camera there. The
-- SlimARK unit frames get the same click in UnitFrames.lua. A binding changes out of combat only.
local MODIFIERS = { SHIFT = true, CTRL = true, ALT = true }
local button, pending

local function Bind()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	SetOverrideBindingClick(button, true, C.quickFocus.modifier .. '-BUTTON1', button:GetName())
end

ns.On('PLAYER_LOGIN', function()
	if not C.features.quickFocus or not MODIFIERS[C.quickFocus.modifier] then return end
	button = CreateFrame('Button', 'SlimARK_QuickFocus', UIParent, 'SecureActionButtonTemplate')
	-- The click arrives with the modifier held: the starred names match any modifier and button.
	button:SetAttribute('type*', 'macro')
	button:SetAttribute('*type*', 'macro')
	button:SetAttribute('macrotext', '/focus mouseover')
	button:RegisterForClicks('AnyUp', 'AnyDown')
	Bind()
	ns.On('PLAYER_REGEN_ENABLED', function()
		if pending then Bind() end
	end)
end)
