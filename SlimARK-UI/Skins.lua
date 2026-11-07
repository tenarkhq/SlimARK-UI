local _, ns = ...
local C = ns.C

local PROFILE = 'SlimARK-UI'

-- The left panel is overall (0), the right is the current fight (1). Under Midnight the window draws from the Blizzard
-- damage meter session type, and the old segment setting does nothing here.
local DETAILS_SESSIONS = { 0, 1 }

-- Details stores the font and the texture by name, we write them back on every login.
-- Details does not restore the session type, so that is also restored here.
-- Under Midnight Details gets the player names as hidden values, so it cannot measure them and
-- never shortens them: a long name ran under the numbers. The name gets a right edge here, left
-- of the value columns, and the game cuts it with an ellipsis.
local nameRoom = 0

local function FitName(row)
	if not row or not row.statusbar or nameRoom <= 0 then return end
	for _, key in ipairs({ 'lineText1', 'lineText11' }) do
		local text = row[key]
		if text then
			local point, relativeTo, relativePoint, x, y = text:GetPoint(1)
			if point then
				text:ClearAllPoints()
				text:SetPoint(point, relativeTo, relativePoint, x, y)
				text:SetPoint('RIGHT', row.statusbar, 'RIGHT', -nameRoom, 0)
				text:SetJustifyH('LEFT')
				text:SetWordWrap(false)
				text:SetNonSpaceWrap(false)
				text:SetMaxLines(1)
			end
		end
	end
end

local fitHooked = false
local function FitAllNames(D, window)
	for _, row in pairs(window.barras or {}) do FitName(row) end
	if not fitHooked and D.gump and D.gump.CreateNewLine then
		fitHooked = true
		hooksecurefunc(D.gump, 'CreateNewLine', function(_, instance, index)
			FitName(instance and instance.barras and instance.barras[index])
		end)
	end
end

local function StyleDetails()
	local D = _G.Details
	if not D or not D.GetInstance then return end
	local cfg = C.details
	local s = ns.Scale()
	local fontSize = math.floor(cfg.fontSize * s + 0.5)
	-- Two value columns, total and per second: three do not leave room for a name in a 300 px panel.
	-- The share of each player is already the length of the bar.
	local format = D.righttext_simple_formatting
	if format then
		format.enabled = false
		format.use_alignment = true
		format.alignment_space = math.floor(fontSize * 4.2 + 0.5)
		nameRoom = format.alignment_space * 2 + 4
	end
	for i = 1, 2 do
		local window = D:GetInstance(i)
		if window then
			window:SetBarSettings(math.floor(cfg.barHeight * s + 0.5), ns.SOFT_NAME)
			window:SetBarTextSettings(fontSize, ns.FONT_NAME, nil, nil, nil, true, true)
			if window.SetBarRightTextSettings then window:SetBarRightTextSettings(true, true, false) end
			FitAllNames(D, window)
			-- Because of the third parameter, Details pulls back to here at the start of every fight.
			window:SetSegmentType(DETAILS_SESSIONS[i], true, true)
			-- At the end of a key Details would switch to overall; the right panel should stay on the current fight.
			if window.automation then window.automation.overall_mythic_plus = i == 1 end
		end
	end
end

local function ApplyDetails()
	local D = _G.Details
	if not D or not D.GetInstance then return end
	local cfg = C.details
	local s = ns.Scale()

	for i = 1, 2 do
		local window = D:GetInstance(i) or D:CreateInstance(true)
		if not window then return end
		if not window:IsEnabled() then window:EnableInstance() end
		window:UngroupInstance()
		window:ChangeSkin(cfg.skin)
		window:SetWindowScale(1)

		local right = cfg.right - (2 - i) * (cfg.w + cfg.gap)
		window.baseframe:ClearAllPoints()
		window.baseframe:SetPoint('BOTTOMRIGHT', UIParent, 'TOPLEFT', right * s, -cfg.bottom * s)
		window:SetSize(cfg.w * s, cfg.h * s)
		window:SaveMainWindowPosition()
		window:SetDisplay(nil, 1, 1) -- both panels show damage
		window:LockInstance(true)
	end
	StyleDetails()
end

local function StyleDBM()
	local T = _G.DBT
	if not T or not T.Options then return end
	local s = ns.Scale()
	local options = {
		Texture = ns.SOFT, Font = ns.FONT, FontFlag = 'OUTLINE', FontShadow = false,
		FontSize = math.floor(C.bossmods.fontSize * s + 0.5),
		Spark = false, FlashBar = false, IconLeft = true, IconRight = false,
		BackgroundColorR = 0, BackgroundColorG = 0, BackgroundColorB = 0, BackgroundAlpha = 0.65,
		HugeBackgroundColorR = 0, HugeBackgroundColorG = 0, HugeBackgroundColorB = 0, HugeBackgroundAlpha = 0.65,
		BorderEnabled = true, BorderSize = 1, HugeBorderEnabled = true, HugeBorderSize = 1,
	}
	for key, value in pairs(options) do
		T:SetOption(key, value, true)
	end
	T:Rearrange()
end

local function ApplyDBM()
	local T = _G.DBT
	if not T or not T.Options then return end
	local cfg = C.bossmods
	local s = ns.Scale()
	local n, h = cfg.normal, cfg.huge
	local options = {
		Scale = 1, HugeScale = 1, Alpha = 1, HugeAlpha = 1,
		Width = n.w * s, Height = n.h * s, HugeWidth = h.w * s, HugeHeight = h.h * s,
		TimerPoint = 'TOPLEFT', TimerX = n.x * s, TimerY = -n.y * s,
		HugeTimerPoint = 'TOPLEFT', HugeTimerX = h.x * s, HugeTimerY = -h.y * s,
		BarYOffset = cfg.gap * s, HugeBarYOffset = cfg.gap * s,
		ExpandUpwards = false, ExpandUpwardsLarge = true,
	}
	for key, value in pairs(options) do
		T:SetOption(key, value, true)
	end
	StyleDBM()
end

-- BigWigs bar style: the same flat, black bordered look as the frames.
local function RegisterBigWigsStyle()
	local API = _G.BigWigsAPI
	if not API or ns.bigWigsStyle then return end
	ns.bigWigsStyle = true

	local backdrop = { bgFile = ns.TEX, edgeFile = ns.TEX, edgeSize = 1 }

	local function dress(frame, target)
		frame:SetBackdrop(backdrop)
		frame:SetBackdropColor(0, 0, 0, 0.65)
		frame:SetBackdropBorderColor(0, 0, 0, 1)
		frame:ClearAllPoints()
		frame:SetPoint('TOPLEFT', target, 'TOPLEFT', -1, 1)
		frame:SetPoint('BOTTOMRIGHT', target, 'BOTTOMRIGHT', 1, -1)
	end

	API:RegisterBarStyle('SlimARK-UI', {
		apiVersion = 1,
		version = 1,
		barSpacing = C.bossmods.gap,
		ApplyStyle = function(bar)
			dress(bar.candyBarBackdrop, bar)
			bar.candyBarBackdrop:Show()
			local icon = bar.candyBarIconFrame
			if bar:IsIconVisible() and not icon:IsAnchoringSecret() then
				dress(bar.candyBarIconFrameBackdrop, icon)
				bar.candyBarIconFrameBackdrop:Show()
			end
		end,
		BarStopped = function(bar)
			bar.candyBarBackdrop:Hide()
			bar.candyBarIconFrameBackdrop:Hide()
		end,
		GetStyleName = function() return 'SlimARK-UI' end,
	})
end

-- If the Bars plugin is not loaded yet, we write straight into the profile.
local function BigWigsBars()
	local BW = _G.BigWigs
	local plugin = BW and BW.GetPlugin and BW:GetPlugin('Bars', true)
	if plugin and plugin.db then
		return plugin.db.profile, plugin
	end
	local sv = _G.BigWigs3DB
	sv.namespaces = sv.namespaces or {}
	local space = sv.namespaces.BigWigs_Plugins_Bars or {}
	sv.namespaces.BigWigs_Plugins_Bars = space
	space.profiles = space.profiles or {}
	space.profiles[PROFILE] = space.profiles[PROFILE] or {}
	return space.profiles[PROFILE]
end

local function StyleBigWigs()
	local cfg = C.bossmods
	local s = ns.Scale()
	local db, plugin = BigWigsBars()
	db.barStyle = 'SlimARK-UI'
	db.texture = ns.SOFT_NAME
	db.fontName = ns.FONT_NAME
	db.fontSize = math.max(10, math.floor(cfg.fontSize * s + 0.5))
	db.fontSizeEmph = db.fontSize
	db.outline = 'OUTLINE'
	if plugin then plugin:SendMessage('BigWigs_ProfileUpdate') end
end

local function ApplyBigWigs()
	local cfg = C.bossmods
	local s = ns.Scale()
	local n, h = cfg.normal, cfg.huge
	local db = BigWigsBars()
	db.spacing = math.max(1, math.floor(cfg.gap * s + 0.5))
	db.normalWidth = math.max(120, math.floor(n.w * s + 0.5))
	db.normalHeight = math.max(10, math.floor(n.h * s + 0.5))
	db.expWidth = math.max(120, math.floor(h.w * s + 0.5))
	db.expHeight = math.max(10, math.floor(h.h * s + 0.5))
	db.normalPosition = { 'TOPLEFT', 'TOPLEFT', math.floor(n.x * s + 0.5), -math.floor(n.y * s + 0.5), 'UIParent' }
	db.expPosition = { 'TOPLEFT', 'TOPLEFT', math.floor(h.x * s + 0.5), -math.floor(h.y * s + 0.5), 'UIParent' }
	db.growup = false
	db.emphasizeGrowup = true
	StyleBigWigs()
end

-- Chattynator does not accept an external skin, so we set its own dark skin in the SlimARK-UI profile.
-- The new profile is a copy of the current one, and it takes effect on the reload after /slimark apply.
local function ChattynatorProfile()
	local cfg = _G.CHATTYNATOR_CONFIG
	if not cfg or not cfg.Profiles then return nil end
	local current = _G.CHATTYNATOR_CURRENT_PROFILE or 'DEFAULT'
	local created = not cfg.Profiles[PROFILE]
	if created then
		cfg.Profiles[PROFILE] = CopyTable(cfg.Profiles[current] or {})
	end
	_G.CHATTYNATOR_CURRENT_PROFILE = PROFILE
	return created
end

local function ApplyChattynator()
	local profile = _G.CHATTYNATOR_CONFIG.Profiles[PROFILE]
	local cfg = C.chat
	local s = ns.Scale()
	local _, height = GetPhysicalScreenSize()
	local window = profile.windows and profile.windows[1]
	if window then
		window.position = { 'BOTTOMLEFT', 'UIParent', 'BOTTOMLEFT', cfg.x * s, (height - cfg.bottom) * s }
		window.size = { cfg.w * s, cfg.h * s }
	end
	profile.current_skin = 'dark'
	profile.skins = profile.skins or {}
	profile.skins.dark = profile.skins.dark or {}
	profile.skins.dark.solid_chat_background = true
	profile.skins.dark.chat_transparency = 0.4
	profile.skins.dark.tab_transparency = 0.2
	profile.message_font = ns.FONT_NAME
	profile.message_font_size = cfg.fontSize
	profile.message_font_outline = 'none'
	profile.show_font_shadow = true
	profile.button_position = 'inside_tabs'
	profile.show_buttons = 'hover'
end

-- Profile switchers. Returns: nil if the addon is not running; true if the
-- new profile was just created; false if it already existed. The new profile is a copy of the current settings,
-- the old profile stays untouched.
local function DetailsProfile()
	local D = _G.Details
	if not D or not D.GetProfile or not D.tabela_instancias then return nil end
	-- The "always use this profile" setting would switch back on login. We turn it off for this character only.
	if D.always_use_profile_exception then
		D.always_use_profile_exception[UnitName('player')] = true
	end
	if D:GetCurrentProfileName() == PROFILE then return false end
	local created = not D:GetProfile(PROFILE)
	if created then D:SaveProfile(PROFILE) end
	D:ApplyProfile(PROFILE)
	return created
end
local function DBMProfile()
	local D = _G.DBM
	local saved = _G.DBM_AllSavedOptions
	if not D or not saved or not _G.DBT or not _G.DBT.Options then return nil end
	local current = _G.DBM_UsedProfile or 'Default'
	if current == PROFILE then return false end
	if saved[PROFILE] then
		D:ApplyProfile(PROFILE)
		return false
	end
	D:CreateProfile(PROFILE)
	D:CopyProfile(current)
	return true
end

local function BigWigsProfile()
	local loader = _G.BigWigsLoader
	local db = loader and loader.db
	local sv = _G.BigWigs3DB
	if not db or not sv then return nil end
	local current = db:GetCurrentProfile()
	if current == PROFILE then return false end

	local created = not (sv.profiles and sv.profiles[PROFILE])
	if created then
		-- Raw copy, so the settings of boss modules not loaded yet come over too.
		sv.profiles = sv.profiles or {}
		sv.profiles[PROFILE] = sv.profiles[current] and CopyTable(sv.profiles[current]) or {}
		for _, space in pairs(sv.namespaces or {}) do
			if space.profiles and space.profiles[current] then
				space.profiles[PROFILE] = CopyTable(space.profiles[current])
			end
		end
	end
	db:SetProfile(PROFILE)
	return created
end

local targets = {
	{ name = 'Details', profile = DetailsProfile, apply = ApplyDetails, style = StyleDetails },
	{ name = 'DBM', profile = DBMProfile, apply = ApplyDBM, style = StyleDBM },
	{ name = 'BigWigs', profile = BigWigsProfile, apply = ApplyBigWigs, style = StyleBigWigs },
	{ name = 'Chattynator', profile = ChattynatorProfile, apply = ApplyChattynator },
	{ name = 'BetterBags', module = 'betterbags', profile = function() return ns.BetterBagsProfile() end, apply = function() ns.ApplyBetterBags() end },
}

local function Try(fn)
	return xpcall(fn, geterrorhandler())
end

-- Every position and setting with one command, then a reload so that everything loads the new values.
function ns.ApplyAll()
	if InCombatLockdown() then
		ns.Print('Not possible in combat, try again afterwards.')
		return
	end
	for _, target in ipairs(targets) do
		-- A skin switched off in /slim is left alone.
		if not target.module or C.modules[target.module] then
			local result
			Try(function()
				result = target.profile()
				if result ~= nil then target.apply() end
			end)
			if result == nil then
				ns.Print(target.name .. ' is not loaded right now, skipped.')
			end
		end
	end
	Try(ns.ApplyEditMode)
	ns.CharDB.applied = C.version
	ns.CharDB.appliedVersion = ns.version
	ReloadUI()
end

-- A new version asks for /slimark apply once, in a window in the middle of the screen.
StaticPopupDialogs.SLIMARK_APPLY = {
	text = 'SlimARK-UI %s\n\nRun /slimark apply to set up the positions and skins of this version. The UI reloads afterwards. Your own profiles and layouts stay untouched.',
	button1 = 'Apply now',
	button2 = 'Later',
	OnAccept = function() ns.ApplyAll() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function AskForApply()
	if ns.CharDB.appliedVersion == ns.version then return end
	if InCombatLockdown() then
		ns.applyAskPending = true
		return
	end
	StaticPopup_Show('SLIMARK_APPLY', ns.version)
end

ns.On('PLAYER_REGEN_ENABLED', function()
	if ns.applyAskPending then
		ns.applyAskPending = nil
		AskForApply()
	end
end)

-- On login the profile is restored if something switched it, and the look is applied again.
-- We do not touch the positions here, they are in the profile.
local function KeepSkins()
	AskForApply()
	if not ns.CharDB.applied then return end
	for _, target in ipairs(targets) do
		if target.style then
			Try(function()
				if target.profile() ~= nil then target.style() end
			end)
		end
	end
end

RegisterBigWigsStyle()
ns.On('PLAYER_LOGIN', RegisterBigWigsStyle)
ns.On('PLAYER_ENTERING_WORLD', function(_, isLogin, isReload)
	if isLogin or isReload then C_Timer.After(3, KeepSkins) end
end)
