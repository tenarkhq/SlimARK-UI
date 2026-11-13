local _, ns = ...

-- 3.0 (50) Game settings page: a few of the game's own settings (CVars). The rows read the value the
-- game has now, and only a value the player changes is written. The game takes them out of combat
-- only: a change made in combat is written when the fight ends. A setting this client does not have
-- hides its row. Nothing is read or written until the page is opened.
-- 3.0 (21) also lives here: the button that opens the game's own audio alert options.
local G = {}
ns.GameSettings = G

local pending = {}
local waiter

local function Raw(name)
	if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
	return GetCVar(name)
end

local function Read(name)
	local value = pending[name]
	if value == nil then value = Raw(name) end
	return value
end

function G.Has(name)
	return Raw(name) ~= nil
end

function G.Number(name)
	return tonumber(Read(name))
end

local function Store(name, value)
	if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(name, value) else SetCVar(name, value) end
end

local function AfterCombat()
	waiter:UnregisterEvent('PLAYER_REGEN_ENABLED')
	for name, value in pairs(pending) do
		pending[name] = nil
		Store(name, value)
	end
	ns.Print('Game settings changed in combat are written now.')
	if ns.SettingsRefresh then ns.SettingsRefresh() end
end

-- Writes one setting, only when it really changes.
function G.Write(name, value)
	if not G.Has(name) then return false end
	local text = tostring(value)
	local now = Read(name)
	if now == text or (tonumber(now) and tonumber(now) == tonumber(text)) then return false end
	if InCombatLockdown() then
		pending[name] = text
		if not waiter then
			waiter = CreateFrame('Frame')
			waiter:SetScript('OnEvent', AfterCombat)
		end
		if not waiter:IsEventRegistered('PLAYER_REGEN_ENABLED') then
			waiter:RegisterEvent('PLAYER_REGEN_ENABLED')
			ns.Print('In combat: the game setting is written when the fight ends.')
		end
		return 'later'
	end
	Store(name, text)
	return true
end

-- Screen shake is two settings of the game: the camera and the interface. Off sets both to 0, on
-- gives both the game's default back.
local SHAKE = { 'ShakeStrengthCamera', 'ShakeStrengthUI' }

function G.ShakeOn()
	for _, name in ipairs(SHAKE) do
		if (G.Number(name) or 0) > 0 then return true end
	end
	return false
end

function G.SetShake(on)
	for _, name in ipairs(SHAKE) do
		local value = 0
		if on then
			local default = C_CVar and C_CVar.GetCVarDefault and tonumber(C_CVar.GetCVarDefault(name))
			value = (default and default > 0) and default or 1
		end
		G.Write(name, value)
	end
end

-- 3.0 (21): the game's Accessibility > Audio page, where its Combat Audio Alerts are. The game gives
-- that page no fixed ID, so it is found by its title; without it the Audio page opens.
function G.OpenAudioAlerts()
	if InCombatLockdown() then
		ns.Print('Not possible in combat, try again afterwards.')
		return false
	end
	if not (Settings and Settings.OpenToCategory) then return false end
	local id
	local title = ACCESSIBILITY_AUDIO_LABEL
	if title and SettingsPanel and SettingsPanel.GetAllCategories then
		for _, category in ipairs(SettingsPanel:GetAllCategories() or {}) do
			if category.GetName and category:GetName() == title then
				id = category:GetID()
				break
			end
		end
	end
	if ns.OpenSettings and SlimARK_Settings and SlimARK_Settings:IsShown() then SlimARK_Settings:Hide() end
	if id then
		Settings.OpenToCategory(id, CAA_ENABLE_COMBAT_AUDIO_ALERTS)
	else
		Settings.OpenToCategory(Settings.AUDIO_CATEGORY_ID)
	end
	return true
end
