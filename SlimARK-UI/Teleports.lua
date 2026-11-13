local _, ns = ...

-- Challenge map ID -> Hero's Path teleport spell. The season's dungeons come from the game
-- (C_ChallengeMode.GetMapTable), this table only pairs them with their teleport. A new
-- dungeon gets a line here when its season starts.
local TELEPORTS = {
	[2] = 131204, -- Temple of the Jade Serpent
	[56] = 131205, -- Stormstout Brewery
	[57] = 131225, -- Gate of the Setting Sun
	[58] = 131206, -- Shado-Pan Monastery
	[59] = 131228, -- Siege of Niuzao Temple
	[60] = 131222, -- Mogu'shan Palace
	[76] = 131232, -- Scholomance
	[77] = 131231, -- Scarlet Halls
	[78] = 131229, -- Scarlet Monastery
	[161] = 159898, -- Skyreach
	[163] = 159895, -- Bloodmaul Slag Mines
	[164] = 159897, -- Auchindoun
	[165] = 159899, -- Shadowmoon Burial Grounds
	[166] = 159900, -- Grimrail Depot
	[167] = 159902, -- Upper Blackrock Spire
	[168] = 159901, -- The Everbloom
	[169] = 159896, -- Iron Docks
	[198] = 424163, -- Darkheart Thicket
	[199] = 424153, -- Black Rook Hold
	[200] = 393764, -- Halls of Valor
	[206] = 410078, -- Neltharion's Lair
	[210] = 393766, -- Court of Stars
	[227] = 373262, -- Return to Karazhan: Lower
	[234] = 373262, -- Return to Karazhan: Upper
	[239] = 1254551, -- Seat of the Triumvirate
	[244] = 424187, -- Atal'Dazar
	[245] = 410071, -- Freehold
	[248] = 424167, -- Waycrest Manor
	[249] = 1286831, -- Kings' Rest
	[250] = 1286828, -- Temple of Sethraliss
	[251] = 410074, -- The Underrot
	[369] = 373274, -- Operation: Mechagon - Junkyard
	[370] = 373274, -- Operation: Mechagon - Workshop
	[375] = 354464, -- Mists of Tirna Scithe
	[376] = 354462, -- The Necrotic Wake
	[377] = 354468, -- De Other Side
	[378] = 354465, -- Halls of Atonement
	[379] = 354463, -- Plaguefall
	[380] = 354469, -- Sanguine Depths
	[381] = 354466, -- Spires of Ascension
	[382] = 354467, -- Theater of Pain
	[391] = 367416, -- Tazavesh: Streets of Wonder
	[392] = 367416, -- Tazavesh: So'leah's Gambit
	[399] = 393256, -- Ruby Life Pools
	[400] = 393262, -- The Nokhud Offensive
	[401] = 393279, -- The Azure Vault
	[402] = 393273, -- Algeth'ar Academy
	[403] = 393222, -- Uldaman: Legacy of Tyr
	[404] = 393276, -- Neltharus
	[405] = 393267, -- Brackenhide Hollow
	[406] = 393283, -- Halls of Infusion
	[438] = 410080, -- The Vortex Pinnacle
	[456] = 424142, -- Throne of the Tides
	[463] = 424197, -- Dawn of the Infinite: Galakrond's Fall
	[499] = 445444, -- Priory of the Sacred Flame
	[500] = 445443, -- The Rookery
	[501] = 445269, -- The Stonevault
	[502] = 445416, -- City of Threads
	[503] = 445417, -- Ara-Kara, City of Echoes
	[504] = 445441, -- Darkflame Cleft
	[505] = 445414, -- The Dawnbreaker
	[506] = 445440, -- Cinderbrew Meadery
	[507] = 445424, -- Grim Batol
	[525] = 1216786, -- Operation: Floodgate
	[542] = 1237215, -- Eco-Dome Al'dani
	[556] = 1254555, -- Pit of Saron
	[557] = 1254400, -- Windrunner Spire
	[558] = 1254572, -- Magisters' Terrace
	[559] = 1254563, -- Nexus-Point Xenas
	[560] = 1254559, -- Maisara Caverns
	[584] = 1286801, -- The Blinding Vale
	[585] = 1286804, -- Voidscar Arena
	[586] = 1286807, -- Den of Nalorakk
	[587] = 1286809, -- Murder Row
	[588] = 1286812, -- Altar of Fangs
}
ns.TELEPORTS = TELEPORTS

local ROW_H, WIDTH, PAD = 30, 300, 8
local menu, header, anchorFrame, ticker
local rows = {}

local function Known(spellID)
	return C_SpellBook.IsSpellKnown(spellID) == true
end

-- The season's dungeons with a learned teleport: the keystone's dungeon first, then by name.
local function Entries()
	local list = {}
	if not C_ChallengeMode or not C_ChallengeMode.GetMapTable then return list end
	local own = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
		local spellID = TELEPORTS[mapID]
		if spellID and Known(spellID) then
			local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
			table.insert(list, { mapID = mapID, spellID = spellID, name = name or '?', texture = texture, own = mapID == own })
		end
	end
	table.sort(list, function(a, b)
		if a.own ~= b.own then return a.own end
		return a.name < b.name
	end)
	return list
end

function ns.HasTeleports()
	return #Entries() > 0
end

-- 3.0 (3): the learned teleport of a dungeon by its instance map ID, the one the Group Finder
-- names. Returns the spell and the challenge map ID, or nothing.
function ns.TeleportForInstance(instanceMapID)
	if not instanceMapID or issecretvalue(instanceMapID) or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then return end
	for challengeID, spellID in pairs(TELEPORTS) do
		local _, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(challengeID)
		if mapID == instanceMapID and Known(spellID) then return spellID, challengeID end
	end
end

local function CooldownText(spellID)
	local info = C_Spell.GetSpellCooldown(spellID)
	if not info or issecretvalue(info.startTime) or issecretvalue(info.duration) then return '' end
	local left = info.startTime + info.duration - GetTime()
	-- A global cooldown is not a teleport cooldown.
	if info.duration <= 1.5 or left <= 0 then return '|cff3fd16aready|r' end
	local h = math.floor(left / 3600)
	local m = math.floor(left % 3600 / 60)
	local s = math.floor(left % 60)
	return ('%d:%02d:%02d'):format(h, m, s)
end

local function UpdateCooldowns()
	for _, row in ipairs(rows) do
		if row:IsShown() and row.spellID then row.cd:SetText(CooldownText(row.spellID)) end
	end
end

-- One row is a secure spell button: the click casts the teleport, the same as from the spellbook.
local function Row(i)
	if rows[i] then return rows[i] end
	local row = CreateFrame('Button', nil, menu, 'SecureActionButtonTemplate')
	row:SetSize(WIDTH, ROW_H)
	row:SetPoint('TOPLEFT', 0, -(24 + (i - 1) * ROW_H))
	-- A mouse click casts on the release only, so the press must not close the menu under it.
	-- useOnKeyDown false: without it the game follows its "cast on key down" setting, waits for
	-- a press that is not registered, and the click does nothing.
	row:RegisterForClicks('AnyUp')
	row:SetAttribute('useOnKeyDown', false)
	row:SetAttribute('type', 'spell')
	local line = row:CreateTexture(nil, 'ARTWORK')
	line:SetColorTexture(0, 0, 0, 1)
	line:SetHeight(ns.Px())
	line:SetPoint('TOPLEFT')
	line:SetPoint('TOPRIGHT')
	local hl = row:CreateTexture(nil, 'HIGHLIGHT')
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.07)
	row.icon = row:CreateTexture(nil, 'ARTWORK')
	row.icon:SetSize(22, 22)
	row.icon:SetPoint('LEFT', PAD, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.name = ns.Text(row, 15, 'LEFT')
	row.name:SetPoint('LEFT', row.icon, 'RIGHT', 8, 0)
	row.name:SetPoint('RIGHT', -84, 0)
	row.cd = ns.Text(row, 13, 'RIGHT')
	row.cd:SetPoint('RIGHT', -PAD, 0)
	row:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetSpellByID(self.spellID)
		GameTooltip:Show()
	end)
	row:SetScript('OnLeave', GameTooltip_Hide)
	row:HookScript('PostClick', function(_, _, down)
		if not down and not InCombatLockdown() then menu:Hide() end
	end)
	rows[i] = row
	return row
end

local function Build()
	menu = CreateFrame('Frame', 'SlimARK_TeleportMenu', UIParent)
	menu:SetFrameStrata('DIALOG')
	menu:SetWidth(WIDTH)
	menu:EnableMouse(true)
	menu:Hide()
	local bg = menu:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.07, 0.075, 0.09, 0.96)
	ns.Outline(menu)
	header = ns.Text(menu, 12, 'LEFT')
	header:SetPoint('TOPLEFT', PAD, -6)
	header:SetTextColor(0.6, 0.59, 0.55)
	table.insert(UISpecialFrames, 'SlimARK_TeleportMenu')
	menu:SetScript('OnShow', function()
		UpdateCooldowns()
		if not ticker then ticker = C_Timer.NewTicker(1, UpdateCooldowns) end
	end)
	menu:SetScript('OnHide', function()
		if ticker then ticker:Cancel() ticker = nil end
	end)
end

-- Opens under the keystone of the top bar. Secure buttons cannot change in combat, and a
-- teleport cannot be cast then anyway, so in combat it stays closed.
function ns.ToggleTeleports(anchor, bar)
	if InCombatLockdown() then return end
	if not menu then Build() end
	if menu:IsShown() then menu:Hide() return end
	local list = Entries()
	if #list == 0 then return end
	header:SetText('TELEPORT')
	for i, entry in ipairs(list) do
		local row = Row(i)
		row.spellID = entry.spellID
		row:SetAttribute('spell', entry.spellID)
		row.icon:SetTexture(entry.texture or C_Spell.GetSpellTexture(entry.spellID))
		row.name:SetText(entry.name)
		row.name:SetTextColor(entry.own and 0.95 or 0.9, entry.own and 0.72 or 0.89, entry.own and 0.29 or 0.85)
		row:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	menu:SetHeight(24 + #list * ROW_H)
	menu:SetScale(bar:GetScale())
	local x = anchor:GetLeft() - bar:GetLeft()
	x = math.max(0, math.min(x, bar:GetWidth() - WIDTH - 2))
	menu:ClearAllPoints()
	menu:SetPoint('TOPLEFT', bar, 'BOTTOMLEFT', x, -2)
	anchorFrame = anchor
	menu:Show()
end

-- Entering combat closes it while that is still allowed; a click elsewhere closes it too.
ns.On('PLAYER_REGEN_DISABLED', function()
	if menu and menu:IsShown() then menu:Hide() end
end)
ns.On('GLOBAL_MOUSE_DOWN', function()
	if not menu or not menu:IsShown() or InCombatLockdown() then return end
	if menu:IsMouseOver() or (anchorFrame and anchorFrame:IsMouseOver()) then return end
	menu:Hide()
end)
