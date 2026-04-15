-- Purpose: Handles 2x Money AFK Stand physical interactions, state, and teleporting.
-- Runs on: Server
-- Location: ServerScriptService
-- Dependencies: Players, Workspace, ReplicatedStorage
-- Public API: None
-- Networking: Uses AFKStandEvent to communicate state changes to the client.
-- Security: Server-side validation for part touching and teleportation.
-- Performance: Utilizes debounces to prevent spam.
-- Notes: Expects `AFKStandEvent` to be manually created in ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local AFKEvent = ReplicatedStorage:WaitForChild("AFKStandEvent", 10)
if not AFKEvent then
	warn("⚠️ AFKStandService: 'AFKStandEvent' RemoteEvent not found in ReplicatedStorage! Please create it.")
end

local moneyFolder = Workspace:WaitForChild("2X-Money", 10)
if not moneyFolder then
	warn("⚠️ AFKStandService: '2X-Money' folder not found in Workspace!")
	return
end

local cashGenerator = moneyFolder:WaitForChild("CashGenerator", 10)
local standPart = cashGenerator:WaitForChild("CashGeneratorPart", 10)
local teleportPad = cashGenerator:WaitForChild("Teleport", 10)
local tycoonsFolder = Workspace:WaitForChild("Tycoons", 10)

local debounce = {}
local activeConnections = {}

-- Helper to find which plot the player owns
local function getPlayerPlot(player)
	for _, plot in pairs(tycoonsFolder:GetChildren()) do
		local ownerVal = plot:FindFirstChild("Owner")
		if ownerVal and ownerVal.Value == player.Name then
			return plot
		end
	end
	return nil
end

-- Touched Event (Enter AFK)
standPart.Touched:Connect(function(hit)
	local character = hit.Parent
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Debounce to prevent multiple fires
	if debounce[player.UserId] then return end
	debounce[player.UserId] = true

	task.delay(1, function()
		debounce[player.UserId] = nil
	end)

	-- Verify plot ownership
	local plot = getPlayerPlot(player)
	if not plot then return end

	-- Ensure not already AFK
	if plot:GetAttribute("IsAFK") == true then return end

	-- Set State
	plot:SetAttribute("IsAFK", true)
	player:SetAttribute("IsAFK", true)

	-- Cleanup existing death connections just in case
	if activeConnections[player.UserId] then
		activeConnections[player.UserId]:Disconnect()
	end

	-- Handle player death/respawn
	activeConnections[player.UserId] = player.CharacterAdded:Connect(function()
		plot:SetAttribute("IsAFK", false)
		player:SetAttribute("IsAFK", false)
		if activeConnections[player.UserId] then
			activeConnections[player.UserId]:Disconnect()
			activeConnections[player.UserId] = nil
		end
	end)

	-- Notify Client
	if AFKEvent then
		AFKEvent:FireClient(player, "Enter", plot.Name)
	end
end)

-- Remote Event (Exit AFK)
if AFKEvent then
	AFKEvent.OnServerEvent:Connect(function(player, action)
		if action == "Exit" then
			local plot = getPlayerPlot(player)

			if plot then
				plot:SetAttribute("IsAFK", false)
			end
			player:SetAttribute("IsAFK", false)

			if activeConnections[player.UserId] then
				activeConnections[player.UserId]:Disconnect()
				activeConnections[player.UserId] = nil
			end

			-- Teleport safely
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") and teleportPad then
				character.HumanoidRootPart.CFrame = teleportPad.CFrame * CFrame.new(0, 3, 0)
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	debounce[player.UserId] = nil
	if activeConnections[player.UserId] then
		activeConnections[player.UserId]:Disconnect()
		activeConnections[player.UserId] = nil
	end

	local plot = getPlayerPlot(player)
	if plot then
		plot:SetAttribute("IsAFK", false)
	end
end)
