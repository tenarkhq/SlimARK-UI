local _, ns = ...
local cfg = ns.C.actionbars

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

-- Square icon, thin black border. It does not touch how the buttons work, only the textures and the fonts.
local function Skin(button)
	local icon = button.icon or button.Icon
	if not icon then return end
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
	if button.Name then button.Name:SetFont(ns.FONT, cfg.hotkeyFont, 'OUTLINE') end
end

ns.On('PLAYER_LOGIN', function()
	for _, bar in ipairs(BARS) do
		for i = 1, bar[2] do
			local button = _G[bar[1] .. i]
			if button then Skin(button) end
		end
	end
end)
