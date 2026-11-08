local _, ns = ...
local C = ns.C

-- The red error text in the middle of the screen, and the voice that reads it out.
-- Blizzard already hides the out of energy, rage, focus and cooldown messages. This hides the
-- other ones that come with every missed press in combat: range, facing, line of sight, no or
-- wrong target, moving, mana, an item not ready. Everything else stays, the full bags too.
-- Done once at login through Blizzard's own switch for each message type: no hook, no cost later.

local HIDDEN = {
	ERR_OUT_OF_RANGE = true, ERR_SPELL_OUT_OF_RANGE = true, SPELL_FAILED_OUT_OF_RANGE = true,
	ERR_BADATTACKFACING = true, ERR_BADATTACKPOS = true, SPELL_FAILED_UNIT_NOT_INFRONT = true,
	SPELL_FAILED_LINE_OF_SIGHT = true,
	ERR_GENERIC_NO_TARGET = true, ERR_NO_ATTACK_TARGET = true, ERR_INVALID_ATTACK_TARGET = true,
	SPELL_FAILED_BAD_TARGETS = true, SPELL_FAILED_BAD_IMPLICIT_TARGETS = true, SPELL_FAILED_TARGETS_DEAD = true,
	SPELL_FAILED_MOVING = true,
	ERR_OUT_OF_MANA = true, SPELL_FAILED_NO_POWER = true,
	ERR_ITEM_COOLDOWN = true, SPELL_FAILED_ITEM_NOT_READY = true, SPELL_FAILED_NOT_READY = true,
	SPELL_FAILED_SPELL_IN_PROGRESS = true, ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS = true,
	SPELL_FAILED_CASTER_AURASTATE = true, SPELL_FAILED_TARGET_AURASTATE = true,
}
ns.HiddenErrors = HIDDEN

-- The message types are numbers the game gives at runtime; their names come from GetGameMessageInfo.
local LAST_TYPE = 2000

ns.On('PLAYER_LOGIN', function()
	if not C.features.errorFilter then return end
	local frame = UIErrorsFrame
	if not frame or not frame.SetMessageTypeEnabled or not GetGameMessageInfo then return end
	for messageType = 0, LAST_TYPE do
		local name = GetGameMessageInfo(messageType)
		if name and HIDDEN[name] then frame:SetMessageTypeEnabled(messageType, false) end
	end
end)
