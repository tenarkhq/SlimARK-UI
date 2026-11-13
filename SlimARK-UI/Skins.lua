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
			-- The retail Details reads the percent column from show_percent, not from the flags above. It draws
			-- it only when the names are not hidden, so out of combat, when overall updates, a third column came
			-- in and ran over the name.
			if window.row_info and window.row_info.show_percent ~= false then
				if window.SetSimpleFormattingSettings then window:SetSimpleFormattingSettings(false)
				else window.row_info.show_percent = false end
			end
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
		if not window then return false end
		if not window:IsEnabled() then window:EnableInstance() end
		window:UngroupInstance()
		window:ChangeSkin(cfg.skin)
		window:SetWindowScale(1)

		local right = ns.FitX(cfg.right - (2 - i) * (cfg.w + cfg.gap), 'RIGHT')
		window.baseframe:ClearAllPoints()
		window.baseframe:SetPoint('BOTTOMRIGHT', UIParent, 'TOPLEFT', right * s, -ns.FitY(cfg.bottom) * s)
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
		TimerPoint = 'TOPLEFT', TimerX = ns.FitX(n.x) * s, TimerY = -ns.FitY(n.y) * s,
		HugeTimerPoint = 'TOPLEFT', HugeTimerX = ns.FitX(h.x) * s, HugeTimerY = -ns.FitY(h.y) * s,
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
	local backdrop = { bgFile = ns.TEX, edgeFile = ns.TEX, edgeSize = 1 }

	local function dress(frame, target)
		frame:SetBackdrop(backdrop)
		frame:SetBackdropColor(0, 0, 0, 0.65)
		frame:SetBackdropBorderColor(0, 0, 0, 1)
		frame:ClearAllPoints()
		frame:SetPoint('TOPLEFT', target, 'TOPLEFT', -1, 1)
		frame:SetPoint('BOTTOMRIGHT', target, 'BOTTOMRIGHT', 1, -1)
	end

	local registered = API:RegisterBarStyle('SlimARK-UI', {
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
	if registered ~= false then ns.bigWigsStyle = true end
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
	db.normalPosition = { 'TOPLEFT', 'TOPLEFT', math.floor(ns.FitX(n.x) * s + 0.5), -math.floor(ns.FitY(n.y) * s + 0.5), 'UIParent' }
	db.expPosition = { 'TOPLEFT', 'TOPLEFT', math.floor(ns.FitX(h.x) * s + 0.5), -math.floor(ns.FitY(h.y) * s + 0.5), 'UIParent' }
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
	local window = profile.windows and profile.windows[1]
	if window then
		window.position = { 'BOTTOMLEFT', 'UIParent', 'BOTTOMLEFT', ns.FitX(cfg.x, 'LEFT') * s, (ns.ScreenHeight() - ns.FitY(cfg.bottom)) * s }
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
	{ name = 'BetterBags', module = 'betterbags', profile = function() return ns.BetterBagsProfile() end, apply = function() return ns.ApplyBetterBags() end },
}

local function Try(fn)
	return xpcall(fn, geterrorhandler())
end

-- Every position and setting with one command, then a reload so that everything loads the new values.
function ns.ApplyAll()
	if InCombatLockdown() then
		ns.Print('Not possible in combat, try again afterwards.')
		return false
	end
	ns.CharDB.applyPending = true
	local complete = true
	for _, target in ipairs(targets) do
		-- A skin switched off in /slimark is left alone.
		if not target.module or C.modules[target.module] then
			local ok, result = Try(function()
				if target.profile() == nil then return nil end
				return target.apply() ~= false
			end)
			if not ok or result == false then
				complete = false
				ns.Print(target.name .. ' could not be applied. Fix the reported problem and try again.')
			elseif result == nil then
				ns.Print(target.name .. ' is not loaded right now, skipped.')
			end
		end
	end
	local ok, applied = Try(ns.ApplyEditMode)
	if not ok or applied ~= true then complete = false end
	if not complete then
		ns.Print('Apply is incomplete. The UI was not reloaded; run /slimark apply again after fixing the problem.')
		return false
	end
	ns.CharDB.applied = C.version
	ns.CharDB.appliedVersion = ns.version
	ns.CharDB.applyPending = nil
	ReloadUI()
	return true
end

-- A new version asks for /slimark apply once, in the setup window (Setup.lua). Until the look
-- of Blizzard's windows is chosen, the window asks for it on every login.
local function AskForApply()
	local chosen = C.blizz.look == 'original' or C.blizz.look == 'slimark'
	if chosen and not ns.CharDB.applyPending and ns.CharDB.appliedVersion == ns.version then return end
	if InCombatLockdown() then
		ns.applyAskPending = true
		return
	end
	ns.ShowSetup()
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

Try(RegisterBigWigsStyle)
ns.On('PLAYER_LOGIN', RegisterBigWigsStyle)
ns.On('PLAYER_ENTERING_WORLD', function(_, isLogin, isReload)
	if isLogin or isReload then C_Timer.After(3, KeepSkins) end
end)

------------------------------------------------------------------------
-- 3.0 (20): Blizzard's damage meter in the SlimARK look. Its place and size go into Edit Mode with
-- /slimark apply (EditMode.lua); here only the look: flat bars with the SlimARK texture and font on
-- a dark track, a flat header and background with a black edge. Nothing is touched until the meter
-- is shown for the first time. Names and amounts can be secret in combat: they are never read, only
-- the fonts and textures of the rows change.
------------------------------------------------------------------------
local dressed = setmetatable({}, { __mode = 'k' })

local function MeterFont(fs, size)
	if not (fs and fs.SetFont) then return end
	fs:SetFont(ns.FONT, size, 'OUTLINE')
	fs:SetShadowOffset(0, 0)
end

-- Blizzard shows the shadow art behind each bar again on every style change; it stays hidden.
local function HideBarShadow(entry)
	local bar = entry.StatusBar
	for _, region in ipairs(bar and bar.BackgroundRegions or {}) do region:SetAlpha(0) end
end

local function DressEntry(entry)
	if not entry or dressed[entry] or not entry.StatusBar then return end
	dressed[entry] = true
	local bar = entry.StatusBar
	bar:SetStatusBarTexture(ns.SOFT)
	local track = bar:CreateTexture(nil, 'BACKGROUND', nil, -7)
	track:SetAllPoints()
	local c = C.colors.track
	track:SetColorTexture(c[1], c[2], c[3], 0.85)
	local size = math.floor(C.details.fontSize * ns.Scale() + 0.5)
	MeterFont(bar.Name, size)
	MeterFont(bar.Value, size)
	local icon = entry.Icon and entry.Icon.Icon
	if icon then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	HideBarShadow(entry)
	for _, method in ipairs({ 'UpdateBackground', 'UpdateStyle' }) do
		if entry[method] then hooksecurefunc(entry, method, HideBarShadow) end
	end
end

-- Rows come and go with the scroll list: every row it hands out is dressed once.
local function DressList(scrollBox)
	if not scrollBox or dressed[scrollBox] then return end
	dressed[scrollBox] = true
	if scrollBox.ForEachFrame then scrollBox:ForEachFrame(DressEntry) end
	if ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
		ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, entry) DressEntry(entry) end, ns)
	end
end

local function DressWindow(window)
	if not window or dressed[window] then return end
	dressed[window] = true
	local s = ns.Scale()
	local header = window.Header
	if header then header:SetColorTexture(0.086, 0.09, 0.11, 0.95) end
	local box = window.MinimizeContainer
	if box and box.Background then box.Background:SetColorTexture(0, 0, 0, 0.6) end
	ns.Outline(window)
	local headSize = math.floor(15 * s + 0.5)
	MeterFont(window.SessionTimer, headSize)
	MeterFont(window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName, headSize)
	MeterFont(window.SessionDropdown and window.SessionDropdown.SessionName, headSize)
	MeterFont(box and box.NotActive, headSize)
	DressList(box and box.ScrollBox)
	DressEntry(box and box.LocalPlayerEntry)
	-- The spell breakdown of a player opens beside the window.
	local source = box and box.SourceWindow
	if source then
		if source.Background then source.Background:SetColorTexture(0, 0, 0, 0.75) end
		DressList(source.ScrollBox)
	end
end

local function DressMeter()
	local meter = _G.DamageMeter
	if dressed[meter] then return end
	dressed[meter] = true
	if meter.ForEachSessionWindow then meter:ForEachSessionWindow(DressWindow) end
	-- The second and third windows are made when the player opens them.
	if meter.SetupSessionWindow then
		hooksecurefunc(meter, 'SetupSessionWindow', function(_, _, data)
			DressWindow(data and data.sessionWindow)
		end)
	end
end

ns.On('PLAYER_LOGIN', function()
	local meter = _G.DamageMeter
	if not C.features.damageMeter or not meter or not C_DamageMeter then return end
	if meter:IsShown() then
		DressMeter()
	else
		meter:HookScript('OnShow', DressMeter)
	end
end)
