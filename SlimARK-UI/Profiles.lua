local _, ns = ...

-- 3.0 (51) Profiles. Export writes the saved SlimARK-UI changes (only the values that differ from
-- Config.lua) as one line of text: SlimARK:1: and then the settings packed by the game's own
-- encoder (CBOR, Deflate, Base64). Import reads such a text, checks every value against the
-- settings of this version and puts them into the panel as changes; Save and reload UI uses them.
-- The profile per character keeps this character's changes with the character instead of the
-- account. Nothing here runs until a button is pressed.
local P = {}
ns.Profiles = P

local PREFIX = 'SlimARK:'
local FORMAT = 1

local function Encoder()
	local E = C_EncodingUtil
	if E and E.SerializeCBOR and E.DeserializeCBOR and E.CompressString and E.DecompressString
		and E.EncodeBase64 and E.DecodeBase64 then
		return E
	end
end

-- Saved values are numbers, booleans, strings and three-number colors.
local function Copy(value)
	if type(value) ~= 'table' then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = Copy(v) end
	return out
end

-- The export text, or nil and the reason in plain words.
function P.Export()
	local E = Encoder()
	if not E then return nil, 'Profile texts need the game\'s encoder, which this client does not have.' end
	local data = { format = FORMAT, settings = Copy(ns.Settings.Store()) }
	local ok, text = pcall(function()
		return E.EncodeBase64(E.CompressString(E.SerializeCBOR(data)))
	end)
	if not ok or type(text) ~= 'string' then return nil, 'The settings could not be packed into a text.' end
	return PREFIX .. FORMAT .. ':' .. text
end

-- The export button: the text goes into the box, selected, ready for Ctrl+C.
function P.ExportTo(box)
	local text, problem = P.Export()
	if not text then
		ns.Print(problem)
		return
	end
	box:SetText(text)
	box:SetFocus()
	box:HighlightText()
	ns.Print('The profile text is selected in the box: press Ctrl+C to copy it.')
end

local function Options(row)
	local set = {}
	for _, option in ipairs(row.options or {}) do set[option[1]] = true end
	return set
end

-- Whether one imported value fits the setting it names.
local function Fits(row, default, value)
	if type(value) ~= type(default) then return false end
	if type(default) == 'table' then
		for i = 1, 3 do
			local c = value[i]
			if type(c) ~= 'number' or c ~= c or c < 0 or c > 1 then return false end
		end
		return true
	end
	if type(default) == 'number' then
		if value ~= value then return false end
		if row and row.t == 'range' and (value < row.min or value > row.max) then return false end
	end
	if type(default) == 'string' and row and row.t == 'choice' and row.options then
		return Options(row)[value] == true
	end
	return true
end

-- Reads a profile text. Returns the settings it holds, how many were skipped, or nil and the problem.
function P.Read(text)
	if type(text) ~= 'string' then return nil, 'Paste a SlimARK-UI profile text into the box first.' end
	-- A pasted text may carry line breaks and spaces.
	text = text:gsub('%s', '')
	if text == '' then return nil, 'Paste a SlimARK-UI profile text into the box first.' end
	local format, body = text:match('^SlimARK:(%d+):(.+)$')
	if not format then return nil, 'This is not a SlimARK-UI profile text. It starts with SlimARK:1:' end
	if tonumber(format) ~= FORMAT then return nil, 'This profile text is from a newer SlimARK-UI version. Update the addon first.' end
	local E = Encoder()
	if not E then return nil, 'Profile texts need the game\'s encoder, which this client does not have.' end
	local ok, data = pcall(function()
		return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(body)))
	end)
	if not ok or type(data) ~= 'table' or type(data.settings) ~= 'table' then
		return nil, 'The profile text is damaged or cut off. Copy the whole text again.'
	end
	local S = ns.Settings
	local byPath = {}
	for _, row in ipairs(S.rows) do byPath[row.path] = row end
	local settings, skipped = {}, 0
	for path, value in pairs(data.settings) do
		local default
		if type(path) == 'string' then default = S.defaults[path] end
		if default ~= nil and Fits(byPath[path], default, value) then
			settings[path] = Copy(value)
		else
			skipped = skipped + 1
		end
	end
	return settings, skipped
end

-- The import button: every setting takes the text's value, or its default when the text has none.
function P.Import(text)
	local settings, skipped = P.Read(text)
	if not settings then return false, skipped end
	local S = ns.Settings
	local count = 0
	for path, default in pairs(S.defaults) do
		local value = settings[path]
		if value ~= nil then count = count + 1 else value = default end
		S.Set(path, value)
	end
	local message = ('Profile read: %d changed setting%s.'):format(count, count == 1 and '' or 's')
	if skipped > 0 then
		message = message .. (' %d value%s this version does not know or cannot use %s left out.'):format(
			skipped, skipped == 1 and '' or 's', skipped == 1 and 'was' or 'were')
	end
	return true, message .. ' Press Save and reload UI to use it.'
end

function P.ImportFrom(text, box)
	local ok, message = P.Import(text)
	ns.Print(message)
	if ok then box:SetText('') end
	if ok and ns.SettingsRefresh then ns.SettingsRefresh() end
end

local function Char()
	return type(SlimARKCharDB) == 'table' and SlimARKCharDB or nil
end

function P.IsPerCharacter()
	local char = Char()
	return char ~= nil and char.ownProfile == true
end

local function Same(a, b)
	for path, value in pairs(a) do
		if not ns.Settings.Equal(value, b[path]) then return false end
	end
	for path in pairs(b) do
		if a[path] == nil then return false end
	end
	return true
end

-- On: this character starts from a copy of the shared changes, so nothing moves. Off: the shared
-- changes come back, with a reload when they differ.
function P.SetPerCharacter(on)
	local char = Char()
	if not char or on == P.IsPerCharacter() then return end
	if InCombatLockdown() then
		ns.Print('Not possible in combat, try again afterwards.')
		return
	end
	SlimARKDB.settings = SlimARKDB.settings or {}
	if on then
		char.settings = Copy(SlimARKDB.settings)
		char.ownProfile = true
		ns.Print('This character keeps its own settings from now on, starting from the shared ones.')
	else
		local differs = not Same(char.settings or {}, SlimARKDB.settings)
		char.ownProfile = nil
		char.settings = nil
		ns.Print('This character uses the shared settings again.')
		if differs then ReloadUI() end
	end
end
