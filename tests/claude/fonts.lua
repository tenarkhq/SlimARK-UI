-- 3.1.1: text goes through a font family, so Cyrillic, Korean and Chinese names draw with
-- Blizzard's faces while Latin text keeps the SlimARK font. Run from the repository root:
--   lua5.1 tests/claude/fonts.lua
local H = dofile('tests/claude/lib/helpers.lua')

local made
local function Boot(withFamilies)
	local ns = H.setup()
	made = {}
	CreateFontFamily = withFamilies and function(name, members)
		local family = { name = name, members = members }
		made[#made + 1] = family
		return family
	end or nil
	H.load('Config.lua')
	H.load('Core.lua')
	return ns
end

do
	local ns = Boot(true)
	local fs = ns.Text(UIParent, 14)
	local call = H.lastCall(fs, 'SetFontObject')
	H.check(call and call[1] == made[1], 'family: a SlimARK text takes a font family')
	H.check(H.lastCall(fs, 'SetFont') == nil, 'family: no plain font that would pin the face')
	local alphabets = {}
	for _, member in ipairs(made[1].members) do
		alphabets[member.alphabet] = member
		if member.height ~= 14 or member.flags ~= 'OUTLINE' then alphabets.bad = true end
	end
	H.equal(alphabets.roman and alphabets.roman.file, ns.FONT, 'family: Latin text keeps the SlimARK font')
	H.equal(alphabets.russian and alphabets.russian.file, [[Fonts\FRIZQT___CYR.TTF]], 'family: Cyrillic takes Blizzard\'s Cyrillic face')
	H.check(alphabets.korean and alphabets.simplifiedchinese and alphabets.traditionalchinese, 'family: Korean and Chinese have a member each')
	H.check(not alphabets.bad, 'family: every member has the same size and flags')
	ns.Text(UIParent, 14)
	H.equal(#made, 1, 'family: one family per size and flags, made once')
	ns.Text(UIParent, 12)
	ns.SetFont(ns.Text(UIParent, 12), 12, '')
	H.equal(#made, 3, 'family: another size or flags makes its own')
	H.check(ns.FontFamily(12, '', 'chattab') ~= ns.FontFamily(12, ''), 'family: a tag gives a family of its own')
end

do
	local ns = Boot(false)
	local fs = ns.Text(UIParent, 14)
	local call = H.lastCall(fs, 'SetFont')
	H.check(call and call[1] == ns.FONT and call[2] == 14 and call[3] == 'OUTLINE', 'no families: the plain SlimARK font as before')
end

H.done()
