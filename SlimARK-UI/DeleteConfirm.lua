local _, ns = ...
local C = ns.C

-- Destroying a good item asks for a click on Confirm instead of typing DELETE (2.0, on by
-- default, with the Original look too). The dialog shows the item, its name and a Confirm
-- and a Cancel button; Escape still cancels. Blizzard's own dialog is used: SlimARK only
-- fills in the word, hides the field and changes the texts.
local TYPED = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }

local function CursorItem()
	local location = C_Cursor and C_Cursor.GetCursorItem()
	if not location or not C_Item.DoesItemExist(location) then return end
	return location, C_Item.GetItemLink(location), C_Item.GetItemName(location), C_Item.GetItemIcon(location),
		C_Item.GetItemQuality(location), C_Item.GetStackCount(location)
end

local function Simplify(which)
	if not TYPED[which] or not C.features.easyDelete then return end
	local dialog = StaticPopup_FindVisible(which)
	if not dialog or not dialog.GetEditBox then return end
	local box = dialog:GetEditBox()
	-- The word goes in first: Blizzard's own text handler then enables the button.
	box:SetText(DELETE_ITEM_CONFIRM_STRING)
	box:ClearFocus()
	box:Hide()
	local location, link, name, icon, quality, count = CursorItem()
	if location and link and dialog.GetItemFrame then
		local item = dialog:GetItemFrame()
		local color = quality and ITEM_QUALITY_COLORS[quality]
		item:DisplayInfo(link, name or link, color and { color.r, color.g, color.b, 1 } or nil, icon, count)
		item:Show()
	end
	dialog:SetText('Destroy this item? This cannot be undone.')
	dialog:GetButton1():SetText('Confirm')
	dialog:GetButton1():Enable()
	dialog:GetButton2():SetText(CANCEL)
	-- Blizzard anchors only the shown parts: the item row goes in, the hidden box drops out.
	if dialog.SetupElementAnchoring then dialog:SetupElementAnchoring() end
	if dialog.Resize then dialog:Resize() end
end

ns.On('PLAYER_LOGIN', function()
	if not C.features.easyDelete then return end
	hooksecurefunc('StaticPopup_Show', Simplify)
end)
