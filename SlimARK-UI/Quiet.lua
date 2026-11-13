local _, ns = ...

-- 3.0 (52) Quiet mode: the sound files on your list are muted, and the boss kill banner, the zone
-- text and the Battle.net toasts stay hidden. Off by default. The switch in /slimark and the top bar
-- element turn it on and off at once, without a reload; the state and the list are kept for the
-- account. While it is off nothing is muted and nothing is hooked. The game forgets muted sounds at
-- a reload, so they are muted again at login when the mode is on.
local Q = {}
ns.Quiet = Q

local muted = {}
local hooked = false

local function DB()
	if not ns.DB then return nil end
	local db = ns.DB.quiet
	if type(db) ~= 'table' then
		db = { on = false, hide = true, sounds = {} }
		ns.DB.quiet = db
	end
	db.sounds = db.sounds or {}
	return db
end

function Q.IsOn()
	local db = DB()
	return db ~= nil and db.on == true
end

function Q.Hides()
	local db = DB()
	return db ~= nil and db.hide ~= false
end

local function Hiding()
	return Q.IsOn() and Q.Hides()
end

-- The boss banner is part of the game's queue of top banners: it is dismissed the way a right click
-- dismisses it, one frame after it starts, so the queue goes on with the next banner.
local function DismissBanner()
	local banner = BossBanner
	if BossBanner_Stop then BossBanner_Stop(banner) else banner:Hide() end
	local manager = TopBannerMgr
	if manager and manager.currentBanner and manager.currentBanner.frame == banner and TopBannerManager_BannerFinished then
		TopBannerManager_BannerFinished()
	end
	banner:SetAlpha(1)
end

local function Hook()
	if hooked then return end
	hooked = true
	if BossBanner then
		BossBanner:HookScript('OnShow', function(self)
			if not Hiding() then return end
			self:SetAlpha(0)
			C_Timer.After(0, DismissBanner)
		end)
	end
	-- The zone texts fade by themselves; hidden they simply stop. Hiding a toast shows the next one.
	for _, name in ipairs({ 'ZoneTextFrame', 'SubZoneTextFrame', 'BNToastFrame' }) do
		local frame = _G[name]
		if frame then
			frame:HookScript('OnShow', function(self)
				if Hiding() then self:Hide() end
			end)
		end
	end
end

local function Apply()
	local db = DB()
	if not db then return end
	local want = {}
	if db.on and MuteSoundFile then
		for _, id in ipairs(db.sounds) do want[id] = true end
	end
	for id in pairs(muted) do
		if not want[id] then
			UnmuteSoundFile(id)
			muted[id] = nil
		end
	end
	for id in pairs(want) do
		if not muted[id] then
			MuteSoundFile(id)
			muted[id] = true
		end
	end
	if db.on and db.hide ~= false then Hook() end
end

local function Changed()
	Apply()
	if ns.UpdateQuietSegment then ns.UpdateQuietSegment() end
	if ns.SettingsRefresh then ns.SettingsRefresh() end
end

function Q.Set(on)
	local db = DB()
	if not db then return end
	db.on = on and true or false
	Changed()
end

function Q.Toggle()
	Q.Set(not Q.IsOn())
end

function Q.SetHides(on)
	local db = DB()
	if not db then return end
	db.hide = on and true or false
	Changed()
end

-- The muted list as text for the settings box.
function Q.SoundText()
	local db = DB()
	if not db then return '' end
	local parts = {}
	for i, id in ipairs(db.sounds) do parts[i] = tostring(id) end
	return table.concat(parts, ', ')
end

-- Reads a list of sound file IDs typed into the box. Anything that is not a whole number is named
-- and the old list stays.
function Q.SetSounds(text)
	local db = DB()
	if not db then return false end
	local list, seen = {}, {}
	for word in (text or ''):gmatch('[^%s,;]+') do
		local id = word:match('^%d+$') and tonumber(word)
		if not id or id <= 0 then
			ns.Print(('"%s" is not a sound file ID. Use the numbers only, the list was not changed.'):format(word))
			return false
		end
		if not seen[id] then
			seen[id] = true
			list[#list + 1] = id
		end
	end
	db.sounds = list
	ns.Print(('Muted sounds: %d on the list.'):format(#list))
	Changed()
	return true
end

ns.On('PLAYER_LOGIN', function()
	if Q.IsOn() then Changed() end
end)
