-- Purpose: Handles Global Shop Restock notifications sent by Admins.
-- Runs on: Client (StarterPlayerScripts)
-- Dependencies: ReplicatedStorage.CarStats, ReplicatedStorage.RestockNotificationEvent
-- Setup needed in Studio:
--   StarterGui > Notifications > RestockNotificationFrame > RestockNotification
--   RichText MUST be enabled on the RestockNotification TextLabel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

-- 🎨 RARITY COLOR CODES (Hex Format for RichText)
-- Common — Gray
local COLOR_COMMON    = "#B2B2B2"
-- Uncommon — Teal
local COLOR_UNCOMMON  = "#008080"
-- Rare — Blue
local COLOR_RARE      = "#0000FF"
-- Epic — Violet
local COLOR_EPIC      = "#8A2BE2"
-- Legendary — Orange/Gold
local COLOR_LEGENDARY = "#FFA500"
-- Mythic — Magenta/Pink
local COLOR_MYTHIC    = "#FF00FF"
-- All / Global Impact Color
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
local activeTween = nil
local displayTime = 5

-- Hide instantly on spawn
notifFrame.Visible = false
notifFrame.BackgroundTransparency = 1
notifText.TextTransparency = 1

local function getRarityColor(rarity)
	if rarity == "Common" then return COLOR_COMMON end
	if rarity == "Uncommon" then return COLOR_UNCOMMON end
	if rarity == "Rare" then return COLOR_RARE end
	if rarity == "Epic" then return COLOR_EPIC end
	if rarity == "Legendary" then return COLOR_LEGENDARY end
	if rarity == "Mythic" then return COLOR_MYTHIC end
	return COLOR_COMMON -- Fallback
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
	if activeTween then
		activeTween:Cancel()
	end

	notifText.Text = textString
	notifFrame.Visible = true

	-- Fade In
	local fadeInInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenInFrame = TweenService:Create(notifFrame, fadeInInfo, {BackgroundTransparency = 0})
	local tweenInText = TweenService:Create(notifText, fadeInInfo, {TextTransparency = 0})

	tweenInFrame:Play()
	tweenInText:Play()

	playRestockSound()

	task.spawn(function()
		task.wait(0.5 + displayTime)

		-- Fade Out
		local fadeOutInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tweenOutFrame = TweenService:Create(notifFrame, fadeOutInfo, {BackgroundTransparency = 1})
		local tweenOutText = TweenService:Create(notifText, fadeOutInfo, {TextTransparency = 1})

		activeTween = tweenOutFrame

		tweenOutFrame:Play()
		tweenOutText:Play()

		tweenOutFrame.Completed:Wait()
		notifFrame.Visible = false
	end)
end

RestockNotificationEvent.OnClientEvent:Connect(function(carName)
	if type(carName) ~= "string" then return end

	local message = ""

	if carName:lower() == "all" then
		message = string.format([[<font color="%s"><b>Everything has been restocked on all shops!!</b></font>]], COLOR_ALL)
	else
		local carData = CarStats.Cars and CarStats.Cars[carName]
		if carData then
			local rarity = carData.Rarity or "Common"
			local colorHex = getRarityColor(rarity)
			local nameStr = carData.Name or carName

			-- E.g. <font color="#008080"><b>Nissan Skyline</b></font> has been restocked to the <font color="#008080"><b>Uncommon</b></font> Shop!
			message = string.format([[<font color="%s"><b>%s</b></font> has been restocked to the <font color="%s"><b>%s</b></font> Shop!]], colorHex, nameStr, colorHex, rarity)
		else
			-- Fallback if car isn't in CarStats for some reason
			message = string.format([[<font color="%s"><b>%s</b></font> has been restocked!]], COLOR_COMMON, carName)
		end
	end

	displayNotification(message)
end)
