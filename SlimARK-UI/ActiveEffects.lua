local _, ns = ...
local C = ns.C
local cfg = C.effects

-- Active trinket and potion effects as icons with a gold countdown, shown only while the effect is up.
-- Order is fixed: upper trinket, lower trinket, potion.
--
-- In combat the game hides most aura data (spell ID, name), but the aura instance ID and its
-- duration object stay usable. So an effect is recognized in three ways:
--   1. its spell ID or name, when readable (out of combat, or an aura the game leaves open);
--   2. a new buff right after an item use, as a temporary estimate marked with '?';
--   3. item use spell IDs verified by C_Item.GetItemSpell, kept for later fights.
-- Name matches and timing guesses never teach a permanent spell ID.
-- A trinket that procs by itself has no use event, so it shows only through 1 and 3.

local SLOTS = { 13, 14 }
local CAST_WINDOW = 1
local POTION = Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Potion or 1
local MAX_LOAD_ATTEMPTS = 3

local entries = {}
local recent = {}
local holder, formatter

local function Readable(v)
	return v ~= nil and not issecretvalue(v)
end

local function Learned()
	if not ns.DB then return { potions = {} } end
	-- Older entries mixed verified IDs with timing guesses, so none can be trusted on migration.
	if not ns.DB.effectBuffs or ns.DB.effectBuffs.version ~= 2 then
		ns.DB.effectBuffs = { version = 2, potions = {} }
	end
	return ns.DB.effectBuffs
end

local function Step() return cfg.size + cfg.gap end
local function HolderWidth() return 3 * Step() - cfg.gap end
local function HolderHeight() return cfg.size + 9 + cfg.font end

local function CreateIcon(parent)
	local f = CreateFrame('Frame', nil, parent)
	f:SetSize(cfg.size, cfg.size)
	ns.Outline(f)
	f.Icon = f:CreateTexture(nil, 'ARTWORK')
	f.Icon:SetAllPoints()
	f.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local gold = C.colors.classPower
	f.Edge = ns.Edge(f, 2, gold, 1)

	local bar = CreateFrame('StatusBar', nil, f)
	bar:SetPoint('TOPLEFT', f, 'BOTTOMLEFT', 0, -3)
	bar:SetPoint('TOPRIGHT', f, 'BOTTOMRIGHT', 0, -3)
	bar:SetHeight(4)
	bar:SetStatusBarTexture(ns.TEX)
	bar:SetStatusBarColor(gold[1], gold[2], gold[3])
	bar:SetMinMaxValues(0, 1)
	ns.Outline(bar)
	local bg = bar:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.7)
	f.Bar = bar

	f.Time = ns.Text(f, cfg.font, 'CENTER')
	f.Time:SetPoint('TOP', bar, 'BOTTOM', 0, -2)
	f.Time:SetTextColor(gold[1], gold[2], gold[3])
	f.Estimate = ns.Text(f, cfg.font, 'RIGHT')
	f.Estimate:SetPoint('TOPRIGHT', -1, -1)
	f.Estimate:SetText('?')
	f.Estimate:Hide()
	f.binding = C_DurationUtil.CreateDurationTextBinding()
	f.binding:SetFormatter(formatter)
	f.binding:SetFontString(f.Time)
	f.binding:SetExpiredText('')
	f:Hide()
	return f
end

local function Layout()
	local shown = {}
	for _, e in ipairs(entries) do
		local on = e.instance ~= nil
		e.f:SetShown(on)
		if on then table.insert(shown, e.f) end
	end
	local step = Step()
	local startX = (HolderWidth() - (#shown * step - cfg.gap)) / 2
	for i, f in ipairs(shown) do
		f:ClearAllPoints()
		f:SetPoint('TOPLEFT', startX + (i - 1) * step, 0)
	end
end

local function Clear(e)
	e.instance = nil
	e.estimated = nil
	e.f.binding:SetEnabled(false)
	Layout()
end

local function Show(e, instance, icon, estimated)
	local ok, duration = pcall(C_UnitAuras.GetAuraDuration, 'player', instance)
	if not ok or not duration then return false end
	e.instance, e.castAt, e.shownAt = instance, nil, GetTime()
	e.estimated = estimated == true
	local f = e.f
	f.Estimate:SetShown(e.estimated)
	f.Icon:SetTexture(icon or e.texture)
	f.Bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
	f.binding:SetDuration(duration)
	f.binding:SetEnabled(true)
	Layout()
	return true
end

-- The icon of the effect: the aura's own when readable, otherwise the item's.
local function IconFor(e, aura, castSpell)
	if aura and Readable(aura.icon) then return aura.icon end
	return e.icons and castSpell and e.icons[castSpell] or e.texture
end

local function SetupTrinket(e)
	local item = GetInventoryItemID('player', e.slot)
	if item ~= e.item then e.requested, e.attempts = nil, 0 end
	e.item, e.ids, e.names = item, {}, {}
	e.texture = GetInventoryItemTexture('player', e.slot)
	e.enabled = cfg.trinkets and item ~= nil
	if not item then e.loaded = false return end
	local spellName, spellID = C_Item.GetItemSpell(item)
	-- Right after login the item data may not be loaded yet; it is read again when it arrives.
	-- A trinket may have no spell at all, so "loaded" comes from the item cache, and the
	-- requests have a bounded retry count; a request can fire its result event at once.
	e.loaded = C_Item.IsItemDataCachedByID(item) == true
	if e.loaded then e.requested = nil end
	if Readable(spellID) then
		e.ids[spellID] = true
		Learned()[item] = spellID
	end
	if spellName then e.names[spellName] = true end
	local itemName = C_Item.GetItemNameByID(item)
	if itemName then e.names[itemName] = true end
	local learned = Learned()[item]
	if learned then e.ids[learned] = true end
	-- Request last: the result event can run synchronously and rebuild these fields.
	if not e.loaded and e.requested ~= item and (e.attempts or 0) < MAX_LOAD_ATTEMPTS then
		e.requested, e.attempts = item, (e.attempts or 0) + 1
		C_Item.RequestLoadItemDataByID(item)
	end
end

local function SetupPotion(e)
	e.ids, e.names, e.icons, e.items, e.texture = {}, {}, {}, {}, nil
	local seen = {}
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and not seen[info.itemID] then
				seen[info.itemID] = true
				local _, _, _, _, _, classID, subclass = C_Item.GetItemInfoInstant(info.itemID)
				if classID == Enum.ItemClass.Consumable and subclass == POTION then
					local name, id = C_Item.GetItemSpell(info.itemID)
					if Readable(id) then
						e.ids[id] = true
						e.icons[id] = info.iconFileID
						Learned().potions[id] = true
					end
					if name then e.names[name] = true end
					table.insert(e.items, info.itemID)
					e.texture = e.texture or info.iconFileID
				end
			end
		end
	end
	for id in pairs(Learned().potions) do e.ids[id] = true end
	e.enabled = cfg.potions and #e.items > 0
end

-- Auras the game's Cooldown Manager tracks belong to class spells (like the wings), never to a trinket or potion.
local VIEWERS = { 'EssentialCooldownViewer', 'UtilityCooldownViewer', 'BuffIconCooldownViewer', 'BuffBarCooldownViewer' }

local function ClassAura(instance)
	for _, name in ipairs(VIEWERS) do
		local viewer = _G[name]
		if viewer and viewer.itemFramePool then
			for item in viewer.itemFramePool:EnumerateActive() do
				if item.GetAuraSpellInstanceID then
					local ok, id = pcall(item.GetAuraSpellInstanceID, item)
					if ok and Readable(id) and id == instance then return true end
				end
			end
		end
	end
	return false
end

-- Only an item spell ID is exact; name matches and temporal matches remain estimates.
local function Match(aura, now)
	local id, name = aura.spellId, aura.name
	local idOk, nameOk = Readable(id), Readable(name)
	for _, e in ipairs(entries) do
		if e.enabled then
			if idOk and e.ids[id] then return e end
			if nameOk and e.names[name] then return e, true end
		end
	end
	if ClassAura(aura.auraInstanceID) then return end
	for _, e in ipairs(entries) do
		if e.enabled and e.castAt and now - e.castAt <= CAST_WINDOW then
			return e, true
		end
	end
end

local function Owner(instance)
	for _, e in ipairs(entries) do
		if e.instance == instance then return e end
	end
end

-- After a full aura update (login, zone change, encounter start) the shown effects are checked
-- again; where the game lets us, the active ones are looked up by spell ID.
local function FullCheck()
	for _, e in ipairs(entries) do
		if e.instance then
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, 'player', e.instance)
			if not ok or not aura then Clear(e) end
		end
		if e.enabled and not e.instance then
			for id in pairs(e.ids) do
				local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
				if ok and aura and Readable(aura.auraInstanceID) and Show(e, aura.auraInstanceID, IconFor(e, aura)) then
					break
				end
			end
		end
	end
end

local function OnAura(info)
	local now = GetTime()
	-- In combat the game can hide the whole update, its flags and lists too. Then nothing in it
	-- can be tested, and the shown effects are checked the full way instead.
	local full = info and info.isFullUpdate
	if not info or issecretvalue(full) or full
		or issecretvalue(info.removedAuraInstanceIDs) or issecretvalue(info.updatedAuraInstanceIDs)
		or issecretvalue(info.addedAuras) then
		FullCheck()
		return
	end
	if info.removedAuraInstanceIDs then
		for _, instance in ipairs(info.removedAuraInstanceIDs) do
			local e = Readable(instance) and Owner(instance)
			if e then Clear(e) end
		end
	end
	if info.updatedAuraInstanceIDs then
		-- A refreshed effect gets its new duration.
		for _, instance in ipairs(info.updatedAuraInstanceIDs) do
			local e = Readable(instance) and Owner(instance)
			if e then Show(e, instance, e.f.Icon:GetTexture(), e.estimated) end
		end
	end
	if info.addedAuras then
		for _, aura in ipairs(info.addedAuras) do
			local helpful = aura.isHelpful
			local instance = aura.auraInstanceID
			if Readable(instance) and (not Readable(helpful) or helpful) then
				local e, estimated = Match(aura, now)
				if e then
					Show(e, instance, IconFor(e, aura, e.castSpell), estimated)
				else
					table.insert(recent, { instance = instance, time = now, aura = aura })
				end
			end
		end
	end
	for i = #recent, 1, -1 do
		if now - recent[i].time > CAST_WINDOW then table.remove(recent, i) end
	end
end

local function CooldownJustStarted(start, now)
	return Readable(start) and start > 0 and now - start <= CAST_WINDOW
end

-- Hidden cast: the trinket or potion whose cooldown has just started was the one used.
local function JustUsed(e, now)
	if e.kind == 'trinket' then
		local ok, start = pcall(GetInventoryItemCooldown, 'player', e.slot)
		return ok and CooldownJustStarted(start, now)
	end
	for _, item in ipairs(e.items) do
		local ok, start = pcall(C_Container.GetItemCooldown, item)
		if ok and CooldownJustStarted(start, now) then return true end
	end
	return false
end

local function Used(e, now, spellID)
	e.castAt, e.castSpell = now, spellID
	-- The effect's aura may have come a moment before the cast event.
	for i = #recent, 1, -1 do
		local r = recent[i]
		if now - r.time <= CAST_WINDOW and not ClassAura(r.instance) then
			table.remove(recent, i)
			local id = r.aura.spellId
			local exact = Readable(id) and e.ids[id]
			Show(e, r.instance, IconFor(e, r.aura, spellID), not exact)
			return
		end
	end
end

local function OnCast(spellID)
	local now = GetTime()
	local readable = Readable(spellID)
	local matched = false
	if readable then
		for _, e in ipairs(entries) do
			if e.enabled and e.ids[spellID] then
				Used(e, now, spellID)
				matched = true
			end
		end
	end
	if matched then return end
	-- Hidden or unknown spell: the trinket or potion whose cooldown has just started was the one used.
	for _, e in ipairs(entries) do
		local busy = (e.castAt and now - e.castAt <= CAST_WINDOW) or (e.shownAt and now - e.shownAt <= CAST_WINDOW)
		if e.enabled and not busy and JustUsed(e, now) then Used(e, now) end
	end
end

ns.On('PLAYER_LOGIN', function()
	if not C.modules.effects then return end
	formatter = C_StringUtil.CreateSecondsFormatter()
	formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
	formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)

	holder = CreateFrame('Frame', 'SlimARK_ActiveEffects', UIParent)
	holder:SetSize(HolderWidth(), HolderHeight())
	ns.Register(holder, cfg.x, cfg.y, { key = 'effects', heal = { x = cfg.heal.x, y = cfg.heal.y } })

	for i, slot in ipairs(SLOTS) do
		entries[i] = { kind = 'trinket', slot = slot, ids = {}, names = {}, f = CreateIcon(holder) }
	end
	entries[3] = { kind = 'potion', ids = {}, names = {}, items = {}, f = CreateIcon(holder) }

	local watch = CreateFrame('Frame')
	watch:RegisterUnitEvent('UNIT_AURA', 'player')
	watch:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
	watch:SetScript('OnEvent', function(_, event, _, a, b)
		if event == 'UNIT_AURA' then
			OnAura(a)
		else
			OnCast(b)
		end
	end)

	ns.On('PLAYER_EQUIPMENT_CHANGED', function(_, slot)
		for _, e in ipairs(entries) do
			if e.slot == slot then
				if e.instance then Clear(e) end
				SetupTrinket(e)
			end
		end
	end)
	ns.On('BAG_UPDATE_DELAYED', function() SetupPotion(entries[3]) end)
	-- Item data that was not loaded at login.
	ns.On('ITEM_DATA_LOAD_RESULT', function(_, itemID, success)
		for _, e in ipairs(entries) do
			if e.kind == 'trinket' and e.item == itemID and not e.loaded then
				e.requested = nil
				if success and C_Item.IsItemDataCachedByID(itemID) then
					SetupTrinket(e)
					FullCheck()
				elseif (e.attempts or 0) < MAX_LOAD_ATTEMPTS then
					C_Timer.After(1, function()
						if e.item == itemID and not e.loaded then SetupTrinket(e) end
					end)
				end
			end
		end
	end)
	ns.On('PLAYER_ENTERING_WORLD', function()
		for _, e in ipairs(entries) do
			if e.kind == 'trinket' and not e.loaded then
				e.attempts = 0
				SetupTrinket(e)
			end
		end
	end)
	-- Register the result handler before requesting: cached requests may answer immediately.
	for i = 1, #SLOTS do SetupTrinket(entries[i]) end
	SetupPotion(entries[3])
	FullCheck()
end)
