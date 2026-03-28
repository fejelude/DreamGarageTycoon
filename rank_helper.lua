-- Add this snippet to every DialogueLogic script
local RANK_VALUES = {
	["Player"] = 0,
	["VIP"] = 1,
	["VIP+"] = 2,
	["MVP"] = 3,
	["MVP+"] = 4,
	["MVP++"] = 5
}

local function getPlayerRankValue()
	local rank = player:GetAttribute("Rank")
	return RANK_VALUES[rank] or 0
end

local function hasRequiredRank(requiredRankName)
	local requiredValue = RANK_VALUES[requiredRankName] or 0
	return getPlayerRankValue() >= requiredValue
end
