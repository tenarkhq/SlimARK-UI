local _, ns = ...

local MODULES = {
	'ScenarioObjectiveTracker', 'UIWidgetObjectiveTracker', 'CampaignQuestObjectiveTracker',
	'QuestObjectiveTracker', 'AdventureObjectiveTracker', 'AchievementObjectiveTracker',
	'MonthlyActivitiesObjectiveTracker', 'InitiativeTasksObjectiveTracker', 'ProfessionsRecipeTracker',
	'BonusObjectiveTracker', 'WorldQuestObjectiveTracker',
}

-- A thin line instead of the fancy header bar.
local function CleanHeader(header)
	if not header or header.slimLine then return end
	if header.Background then header.Background:SetAlpha(0) end
	local line = header:CreateTexture(nil, 'ARTWORK')
	line:SetColorTexture(0.95, 0.72, 0.29, 0.6)
	line:SetHeight(1)
	line:SetPoint('BOTTOMLEFT', 0, 1)
	line:SetPoint('BOTTOMRIGHT', 0, 1)
	header.slimLine = line
end

ns.On('PLAYER_LOGIN', function()
	for size = 12, 22 do
		local font = _G['ObjectiveTrackerFont' .. size]
		if font then
			font:SetFont(ns.FONT, size, 'OUTLINE')
			font:SetShadowOffset(0, 0)
		end
	end

	if not ObjectiveTrackerFrame then return end
	CleanHeader(ObjectiveTrackerFrame.Header)
	for _, name in ipairs(MODULES) do
		local module = _G[name]
		if module then CleanHeader(module.Header) end
	end
end)
