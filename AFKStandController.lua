-- Purpose: Handles Camera movement and UI changes when entering 2x Money AFK Mode.
-- Runs on: Client
-- Location: StarterPlayerScripts
-- Dependencies: Players, Workspace, ReplicatedStorage, TweenService, UserInputService
-- Public API: None
-- Networking: Uses AFKStandEvent to communicate state changes to the server.
-- Performance: Utilizes TweenService for smooth transitions and avoids continuous looping.
-- Notes: Safely hides active screen GUIs while keeping standard chat available. Expects AFKStandEvent in ReplicatedStorage.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")
local starterGui = game:GetService("StarterGui")

local AFKEvent = ReplicatedStorage:WaitForChild("AFKStandEvent", 10)
if not AFKEvent then
	warn("⚠️ AFKStandController: 'AFKStandEvent' RemoteEvent not found in ReplicatedStorage! Please create it.")
end

local moneyFolder = Workspace:WaitForChild("2X-Money", 10)
local cameraFolder = nil
if moneyFolder then
	cameraFolder = moneyFolder:WaitForChild("Cameras", 10)
end

-- UI Setup
local generatingGui = playerGui:WaitForChild("2XMoney", 10)
local generatingFrame = nil
local exitButton = nil

if generatingGui then
	generatingFrame = generatingGui:WaitForChild("GeneratingMoneyFrame", 10)
	if generatingFrame then
		exitButton = generatingFrame:WaitForChild("ExitButton", 10)
	end
end

if not generatingFrame or not exitButton then
	warn("⚠️ AFKStandController: 'GeneratingMoneyFrame' or 'ExitButton' not found in PlayerGui.2XMoney!")
end

local hiddenGuis = {}
local inAFKMode = false
local originalCameraType = Enum.CameraType.Custom

-- SFX Configuration (Matching TabletVisuals)
local HOVER_SOUND_ID = "rbxassetid://6895079853"
local CLICK_SOUND_ID = "rbxassetid://9083627113"
local HOVER_VOLUME = 0.5

local function playSound(soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 1
	sound.Parent = SoundService
	sound:Play()
	game.Debris:AddItem(sound, 1)
end

-- Reset if the player dies/respawns
player.CharacterAdded:Connect(function()
	if inAFKMode then
		-- Fire exit to restore UI and camera without sending the server Exit remote
		-- because the server already handles death on its own.
		inAFKMode = false

		if generatingFrame then
			generatingFrame.Visible = false
		end

		camera.CameraType = originalCameraType
		camera.CameraSubject = player.Character and player.Character:WaitForChild("Humanoid", 5)

		toggleOtherGuis(false)
	end
end)

-- ============================================================================
-- 🎨 UI ANIMATION HELPER
-- ============================================================================
local function playHoverTween(button, isHovering)
	if not button then return end
	if UserInputService.TouchEnabled then return end -- Don't dim hover on mobile

	local targetColor = isHovering and Color3.new(0.7, 0.7, 0.7) or Color3.new(1, 1, 1)
	TweenService:Create(button, TweenInfo.new(0.2), {ImageColor3 = targetColor}):Play()

	if isHovering then
		playSound(HOVER_SOUND_ID, HOVER_VOLUME)
	end
end

if exitButton then
	exitButton.MouseEnter:Connect(function() playHoverTween(exitButton, true) end)
	exitButton.MouseLeave:Connect(function() playHoverTween(exitButton, false) end)
end

-- ============================================================================
-- 👁️ UI VISIBILITY HELPER (Like NPC Dialogue)
-- ============================================================================
local function toggleOtherGuis(shouldHide)
	local playerGui = player:WaitForChild("PlayerGui")
	if shouldHide then
		hiddenGuis = {}
		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui:IsA("ScreenGui") and gui.Name ~= "2XMoney" and gui.Enabled == true then
				gui.Enabled = false
				table.insert(hiddenGuis, gui)
			end
		end
	else
		for _, gui in ipairs(hiddenGuis) do
			if gui and gui.Parent then gui.Enabled = true end
		end
		hiddenGuis = {}
	end
end

-- ============================================================================
-- 🎥 AFK MODE LOGIC
-- ============================================================================

local function enterAFKMode(plotName)
	if inAFKMode then return end
	inAFKMode = true

	-- 1. Find Camera Part
	local plotCamFolder = cameraFolder and cameraFolder:FindFirstChild(plotName)
	local camPart = plotCamFolder and plotCamFolder:FindFirstChild("CameraAimPart")

	-- 2. Move Camera
	if camPart then
		originalCameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable

		local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
		local camTween = TweenService:Create(camera, tweenInfo, {CFrame = camPart.CFrame})
		camTween:Play()
	end

	-- 3. Handle UI
	toggleOtherGuis(true)

	if generatingFrame then
		generatingFrame.Visible = true
	end
end

local function exitAFKMode()
	if not inAFKMode then return end
	inAFKMode = false

	-- 1. Hide Frame
	if generatingFrame then
		generatingFrame.Visible = false
	end

	-- 2. Restore Camera
	camera.CameraType = originalCameraType
	camera.CameraSubject = player.Character and player.Character:FindFirstChild("Humanoid")

	-- 3. Restore UI
	toggleOtherGuis(false)

	-- 4. Notify Server
	if AFKEvent then
		AFKEvent:FireServer("Exit")
	end
end

-- ============================================================================
-- 🔗 CONNECTIONS
-- ============================================================================
if exitButton then
	exitButton.Activated:Connect(function()
		if not inAFKMode then return end
		playSound(CLICK_SOUND_ID, 1)
		exitAFKMode()
	end)
end

if AFKEvent then
	AFKEvent.OnClientEvent:Connect(function(action, plotName)
		if action == "Enter" and plotName then
			enterAFKMode(plotName)
		end
	end)
end
