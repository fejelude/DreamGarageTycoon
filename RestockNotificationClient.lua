-- Purpose: Handles Global Shop Restock notifications sent by Admins.
-- Runs on: Client (StarterPlayerScripts)
-- Dependencies: ReplicatedStorage.CarStats, ReplicatedStorage.RestockNotificationEvent
-- Setup needed in Studio:
--   StarterGui > Notifications > RestockNotificationFrame > RestockNotification
--   RichText MUST be enabled on the RestockNotification TextLabel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

-- 🎨 RARITY COLOR CODES (Hex Format for RichText)
-- Common — Gray (Clean, neutral silver)
local COLOR_COMMON    = "#A1A1AA"
-- Uncommon — Teal (Vibrant, bright cyan/teal)
local COLOR_UNCOMMON  = "#00F5D4"
-- Rare — Blue (Rich, neon royal blue)
local COLOR_RARE      = "#3A86FF"
-- Epic — Violet (Deep, vivid purple)
local COLOR_EPIC      = "#9D4EDD"
-- Legendary — Orange/Gold (Striking bright gold)
local COLOR_LEGENDARY = "#FFBE0B"
-- Mythic — Magenta/Pink (Punchy neon magenta)
local COLOR_MYTHIC    = "#FF006E"
-- All / Global Impact Color (Bright Gold/Yellow)
local COLOR_ALL       = "#FFD700"

-- 🔊 AUDIO ID
local RESTOCK_AUDIO_ID = "rbxassetid://81822437427070"

-- Modules & Events
local CarStats = require(ReplicatedStorage:WaitForChild("CarStats"))
local RestockNotificationEvent = ReplicatedStorage:WaitForChild("RestockNotificationEvent")

-- UI Elements
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local notificationsGui = playerGui:WaitForChild("Notifications")
local notifFrame = notificationsGui:WaitForChild("RestockNotificationFrame")
local notifText = notifFrame:WaitForChild("RestockNotification")

-- State
local displayTime = 5
local activeRoutine = nil

-- Hide instantly on spawn
notifFrame.Visible = false

local function getRarityColor(rarity)
	if rarity == "Common" then return COLOR_COMMON end
	if rarity == "Uncommon" then return COLOR_UNCOMMON end
	if rarity == "Rare" then return COLOR_RARE end
	if rarity == "Epic" then return COLOR_EPIC end
	if rarity == "Legendary" then return COLOR_LEGENDARY end
	if rarity == "Mythic" then return COLOR_MYTHIC end
	return COLOR_COMMON -- Fallback
end

-- 👑 RANK REQUIREMENTS
local RANK_VALUES = {
	["Player"] = 0,
	["VIP"] = 1,
	["VIP+"] = 2,
	["MVP"] = 3,
	["MVP+"] = 4,
	["MVP++"] = 5
}

local SHOP_REQUIREMENTS = {
	Common = "Player",
	Uncommon = "VIP",
	Rare = "VIP+",
	Epic = "MVP",
	Legendary = "MVP+",
	Mythic = "MVP++"
}

local function hasAccessToShop(shopRarity)
	local requiredRankName = SHOP_REQUIREMENTS[shopRarity] or "Player"
	local requiredValue = RANK_VALUES[requiredRankName] or 0

	local playerRankName = player:GetAttribute("Rank") or "Player"
	local playerValue = RANK_VALUES[playerRankName] or 0

	return playerValue >= requiredValue, requiredRankName
end

local function playRestockSound()
	local sound = Instance.new("Sound")
	sound.SoundId = RESTOCK_AUDIO_ID
	sound.Volume = 1
	sound.Parent = SoundService
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function displayNotification(textString)
	if activeRoutine then
		task.cancel(activeRoutine)
		activeRoutine = nil
	end

	notifText.Text = textString
	notifFrame.Visible = true

	playRestockSound()

	activeRoutine = task.spawn(function()
		task.wait(displayTime)
		notifFrame.Visible = false
		activeRoutine = nil
	end)
end

RestockNotificationEvent.OnClientEvent:Connect(function(arg1, arg2)
	if type(arg1) ~= "string" then return end

	local message = ""

	if arg1 == "AutoRestock" then
		local shopRarity = arg2 or "Common"
		local colorHex = getRarityColor(shopRarity)
		local hasAccess, requiredRank = hasAccessToShop(shopRarity)

		if hasAccess then
			-- Has rank
			message = string.format([[<font color="%s"><b>%s</b></font> Shop has restocked!!]], colorHex, shopRarity)
		else
			-- Lacks rank
			message = string.format([[🔒 <font color="%s"><b>%s</b></font> Shop has restocked!! (Unlock at <font color="#FF4444">%s</font>)]], colorHex, shopRarity, requiredRank)
		end
	elseif arg1:lower() == "all" then
		message = string.format([[<font color="%s"><b>Everything has been restocked on all shops!!</b></font>]], COLOR_ALL)
	else
		local carName = arg1
		local carData = CarStats.Cars and CarStats.Cars[carName]
		if carData then
			local rarity = carData.Rarity or "Common"
			local colorHex = getRarityColor(rarity)
			local nameStr = carData.Name or carName

			-- Remove " Car" from the nameStr if it's already there to avoid duplicates, then append it
			if nameStr:lower():sub(-4) == " car" then
				nameStr = nameStr:sub(1, -5)
			end

			-- E.g. <font color="#00F5D4"><b>Nissan Skyline Car</b></font> has been restocked to the <font color="#00F5D4"><b>Uncommon</b></font> Shop!
			message = string.format([[<font color="%s"><b>%s Car</b></font> has been restocked to the <font color="%s"><b>%s</b></font> Shop!]], colorHex, nameStr, colorHex, rarity)
		else
			-- Fallback if car isn't in CarStats for some reason
			message = string.format([[<font color="%s"><b>%s Car</b></font> has been restocked!]], COLOR_COMMON, carName)
		end
	end

	displayNotification(message)
end)
