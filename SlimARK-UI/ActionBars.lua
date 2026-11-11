local _, ns = ...
local cfg = ns.C.actionbars

-- The action bars stay Blizzard's own buttons. This file changes only how they look: textures,
-- colors, fonts and frames of its own on top. It never sets an attribute, a click, a key binding
-- or the press-and-hold setting of a button, and it never changes the icon's picture. Addons that
-- take over a button through those (GSE runs its sequences this way) keep working.

local BARS = {
	{ 'ActionButton', 12 },
	{ 'MultiBarBottomLeftButton', 12 },
	{ 'MultiBarBottomRightButton', 12 },
	{ 'MultiBarRightButton', 12 },
	{ 'MultiBarLeftButton', 12 },
	{ 'MultiBar5Button', 12 },
	{ 'MultiBar6Button', 12 },
	{ 'MultiBar7Button', 12 },
	{ 'StanceButton', 10 },
	{ 'PetActionButton', 10 },
}

local GOLD = { 0.95, 0.72, 0.29 }
local GOLD_DIM = { 0.72, 0.54, 0.2 }
local ASSIST = { 0.25, 0.78, 0.85 }
local SWIPE, SWIPE_GCD = 0.66, 0.32

local skinned = {}

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

-- A button another addon has taken over: its click runs that addon's button, and the addon
-- paints the icon itself. GSE marks such a button with type 'click'.
local function TakenOver(button)
	return button.GetAttribute and button:GetAttribute('type') == 'click'
end

------------------------------------------------------------------------
-- Hotkeys: the modifier as a small gold letter, the key after it.
------------------------------------------------------------------------
local MOD_COLOR = '|cffb88a33'
local KEYS = { MwU = 'MU', MwD = 'MD', ['Mouse Wheel Up'] = 'MU', ['Mouse Wheel Down'] = 'MD' }

function ns.ShortKey(text)
	if not Readable(text) or text == '' or text == RANGE_INDICATOR then return text end
	local mods = ''
	local rest = text
	while true do
		local m, after = rest:match('^([sScCaA])%-(.+)$')
		if not m then break end
		mods = mods .. m:lower()
		rest = after
	end
	rest = KEYS[rest] or rest
	if mods == '' then return rest end
	return MOD_COLOR .. mods .. '|r' .. rest
end

local function UpdateHotkey(button)
	local hotkey = button.HotKey
	if not hotkey or not cfg.shortKeys then return end
	local text = hotkey:GetText()
	local short = ns.ShortKey(text)
	if short ~= text then hotkey:SetText(short) end
end

------------------------------------------------------------------------
-- Icon color: red out of range, blue without the resource, grey when it cannot be used.
------------------------------------------------------------------------
local function Paint(button)
	if not cfg.tint or not button.action or TakenOver(button) then return end
	local icon = button.icon or button.Icon
	if not icon then return end
	local okUse, usable, noMana = pcall(C_ActionBar.IsUsableAction, button.action)
	if not okUse or not Readable(usable) then return end
	if button.slimOutOfRange and usable then
		icon:SetVertexColor(0.85, 0.25, 0.25)
		icon:SetDesaturated(false)
	elseif usable then
		icon:SetVertexColor(1, 1, 1)
		icon:SetDesaturated(false)
	elseif Readable(noMana) and noMana then
		icon:SetVertexColor(0.4, 0.5, 1)
		icon:SetDesaturated(false)
	else
		icon:SetVertexColor(0.5, 0.5, 0.5)
		icon:SetDesaturated(true)
	end
end
ns.PaintActionButton = Paint

------------------------------------------------------------------------
-- Frames of our own on the button: the checked edge, the proc edge, the assisted edge.
------------------------------------------------------------------------
local function EdgeOf(button, key, thickness, color)
	if not button[key] then
		local edge = ns.Edge(button, thickness, color, 0)
		edge:SetFrameLevel(button:GetFrameLevel() + 6)
		edge:Hide()
		button[key] = edge
	end
	return button[key]
end

local function UpdateChecked(button)
	if not cfg.flat then return end
	local checked = button.GetChecked and button:GetChecked()
	EdgeOf(button, 'slimChecked', 1, GOLD_DIM):SetShown(checked and true or false)
end

local function ShowProc(button, shown)
	if not cfg.flat then return end
	if shown then
		if button.SpellActivationAlert then button.SpellActivationAlert:SetAlpha(0) end
		local rotation = button.AssistedCombatRotationFrame
		if rotation and rotation.SpellActivationAlert then rotation.SpellActivationAlert:SetAlpha(0) end
	end
	EdgeOf(button, 'slimProc', 2, GOLD):SetShown(shown)
end

local function ShowAssist(button, shown)
	if not cfg.assist then return end
	if button.AssistedCombatHighlightFrame then button.AssistedCombatHighlightFrame:SetAlpha(0) end
	EdgeOf(button, 'slimAssist', 2, ASSIST):SetShown(shown and true or false)
end

------------------------------------------------------------------------
-- The skin of one button.
------------------------------------------------------------------------
local function Flatten(texture, r, g, b, a, icon)
	if not texture then return end
	texture:SetColorTexture(r, g, b, a)
	texture:ClearAllPoints()
	texture:SetAllPoints(icon)
end

local function Skin(button)
	local icon = button.icon or button.Icon
	if not icon or skinned[button] then return end
	skinned[button] = true
	if button.IconMask then icon:RemoveMaskTexture(button.IconMask) end
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:ClearAllPoints()
	icon:SetAllPoints(button)

	for _, key in ipairs({ 'SlotArt', 'SlotBackground', 'NormalTexture', 'Border' }) do
		if button[key] then button[key]:SetAlpha(0) end
	end
	local normal = button:GetNormalTexture()
	if normal then normal:SetAlpha(0) end
	ns.Outline(button)

	if button.HotKey then button.HotKey:SetFont(ns.FONT, cfg.hotkeyFont, 'OUTLINE') end
	if button.Count then button.Count:SetFont(ns.FONT, cfg.font, 'OUTLINE') end
	if button.Name then
		button.Name:SetFont(ns.FONT, cfg.hotkeyFont, 'OUTLINE')
		button.Name:SetAlpha(cfg.macroNames and 1 or 0)
	end

	local cooldown = button.cooldown
	if cooldown then
		local text = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
		if text then text:SetFont(ns.FONT, cfg.cooldownFont, 'OUTLINE') end
		if cfg.flat then cooldown:SetSwipeColor(0, 0, 0, SWIPE) end
	end

	if cfg.flat then
		Flatten(button.GetHighlightTexture and button:GetHighlightTexture(), 1, 1, 1, 0.14, icon)
		Flatten(button.GetPushedTexture and button:GetPushedTexture(), 0, 0, 0, 0.32, icon)
		Flatten(button.SpellHighlightTexture, 1, 1, 1, 0.2, icon)
		Flatten(button.NewActionTexture, 1, 1, 1, 0.2, icon)
		Flatten(button.Flash, 0.85, 0.15, 0.15, 0.35, icon)
		local checked = button.GetCheckedTexture and button:GetCheckedTexture()
		if checked then checked:SetAlpha(0) end
		-- The cast fill, the targeting circle and the interrupt burst are Blizzard's round art.
		for _, key in ipairs({ 'SpellCastAnimFrame', 'TargetReticleAnimFrame', 'InterruptDisplay' }) do
			if button[key] then button[key]:SetAlpha(0) end
		end
		if button.SetChecked then
			hooksecurefunc(button, 'SetChecked', UpdateChecked)
			UpdateChecked(button)
		end
	end

	if button.UpdateHotkeys then
		hooksecurefunc(button, 'UpdateHotkeys', UpdateHotkey)
		UpdateHotkey(button)
	end
	if button.UpdateUsable then
		hooksecurefunc(button, 'UpdateUsable', Paint)
		Paint(button)
	end
end

------------------------------------------------------------------------
-- Hooks on Blizzard's shared functions; the takeover addons call these too.
------------------------------------------------------------------------
local function HookShared()
	if cfg.tint and ActionButton_UpdateRangeIndicator then
		hooksecurefunc('ActionButton_UpdateRangeIndicator', function(button, checksRange, inRange)
			if not skinned[button] then return end
			local out = nil
			if Readable(checksRange) and Readable(inRange) then out = checksRange and not inRange or nil end
			if button.slimOutOfRange ~= out then
				button.slimOutOfRange = out
				Paint(button)
			end
		end)
	end
	if cfg.flat and ActionButton_UpdateCooldown then
		-- The global cooldown gets a lighter cover. isOnGCD is never a hidden value.
		hooksecurefunc('ActionButton_UpdateCooldown', function(button)
			if not skinned[button] or not button.cooldown or not button.action then return end
			local ok, info = pcall(C_ActionBar.GetActionCooldown, button.action)
			local gcd = ok and info and info.isOnGCD == true
			button.cooldown:SetSwipeColor(0, 0, 0, gcd and SWIPE_GCD or SWIPE)
		end)
	end
	local alerts = ActionButtonSpellAlertManager
	if cfg.flat and alerts then
		hooksecurefunc(alerts, 'ShowAlert', function(_, button)
			if skinned[button] then ShowProc(button, true) end
		end)
		hooksecurefunc(alerts, 'HideAlert', function(_, button)
			if skinned[button] then ShowProc(button, false) end
		end)
	end
	local assisted = AssistedCombatManager
	if cfg.assist and assisted and assisted.SetAssistedHighlightFrameShown then
		hooksecurefunc(assisted, 'SetAssistedHighlightFrameShown', function(_, button, shown)
			if skinned[button] then ShowAssist(button, shown) end
		end)
	end
end

------------------------------------------------------------------------
-- Out of combat the bars above the bottom rows fade; combat, a target, the mouse over the bar,
-- a spell on the cursor, an open flyout or Edit Mode bring them back.
------------------------------------------------------------------------
local fadeBars = {}

local function FindFadeBars()
	wipe(fadeBars)
	local layout = ns.C.layout
	local center = (layout.centerRows or 3) - 1 -- the main bar is the first center row
	for _, bar in ipairs(layout.order) do
		local frame = bar.frame and _G[bar.frame]
		if frame and frame:IsShown() then
			if center > 0 then
				center = center - 1
			else
				table.insert(fadeBars, frame)
			end
		end
	end
	return fadeBars
end
ns.ActionBarFadeBars = FindFadeBars

-- PLAYER_REGEN_DISABLED comes before the combat lockdown begins, so InCombatLockdown() is still
-- false in it: the event itself counts as combat, and UnitAffectingCombat covers the calls that
-- come without an event (Blizzard's own action bars take the combat state from it too).
local function WantsBars(event)
	if event == 'PLAYER_REGEN_DISABLED' or InCombatLockdown() or UnitAffectingCombat('player') then return true end
	if UnitExists('target') then return true end
	if GetCursorInfo() then return true end
	if SpellFlyout and SpellFlyout:IsShown() then return true end
	if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return true end
	return false
end

local recheck = false
local UpdateFade

local function Recheck()
	recheck = false
	UpdateFade()
end

-- event: the event name when an event calls it (a frame when a script does).
function UpdateFade(event)
	if not cfg.fade then return end
	local all = WantsBars(event)
	local hovered = false
	for _, frame in ipairs(fadeBars) do
		local over = not all and frame:IsMouseOver()
		if over then hovered = true end
		local alpha = (all or over) and 1 or cfg.fadeAlpha / 100
		if frame:GetAlpha() ~= alpha then frame:SetAlpha(alpha) end
	end
	-- Leaving a bar through the gap between two buttons gives no event, so only while the
	-- mouse is over a faded bar is it looked at again a moment later.
	if hovered and not recheck then
		recheck = true
		C_Timer.After(0.25, Recheck)
	end
end
ns.UpdateActionBarFade = UpdateFade

local function StartFade()
	if not cfg.fade then return end
	FindFadeBars()
	UpdateFade()
	-- No timer runs: the mouse entering a button, combat, the target, the cursor, the flyout and
	-- Edit Mode wake the fade.
	for _, bar in ipairs(BARS) do
		for i = 1, bar[2] do
			local button = _G[bar[1] .. i]
			if button then button:HookScript('OnEnter', UpdateFade) end
		end
	end
	for _, event in ipairs({ 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'PLAYER_TARGET_CHANGED', 'CURSOR_CHANGED' }) do
		ns.On(event, UpdateFade)
	end
	-- Bars switched on or off in the options change which ones fade.
	ns.On('ACTIONBAR_SHOWGRID', UpdateFade)
	ns.On('ACTIONBAR_HIDEGRID', UpdateFade)
	if SpellFlyout then
		SpellFlyout:HookScript('OnShow', UpdateFade)
		SpellFlyout:HookScript('OnHide', UpdateFade)
	end
	if EditModeManagerFrame then
		EditModeManagerFrame:HookScript('OnShow', UpdateFade)
		EditModeManagerFrame:HookScript('OnHide', function() FindFadeBars() UpdateFade() end)
	end
end

ns.On('PLAYER_LOGIN', function()
	if not ns.C.modules.actionbars then return end
	for _, bar in ipairs(BARS) do
		for i = 1, bar[2] do
			local button = _G[bar[1] .. i]
			if button then Skin(button) end
		end
	end
	HookShared()
	-- The rows are placed by the Edit Mode layout a moment after login.
	C_Timer.After(1, StartFade)
end)
