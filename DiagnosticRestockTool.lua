-- Purpose: Deep Diagnostic Tool for Global Shop Restock implementation.
-- Runs on: Server (ServerScriptService)
-- Instructions: Place this in ServerScriptService and run the game. Read the output in the Developer Console (F9) or Output window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local function logResult(passed, name, path, notes)
	if passed then
		print(string.format("✅ PASS | %s | Found at: %s", name, path))
	else
		warn(string.format("❌ FAIL | %s | Missing from: %s | Fix: %s", name, path, notes or "Create it."))
	end
end

local function runDiagnostics()
	print("\n=======================================================")
	print("🔍 STARTING GLOBAL RESTOCK DIAGNOSTICS...")
	print("=======================================================\n")

	-- 1. ServerScriptService Scripts
	print("--- 📜 SERVER SCRIPTS ---")

	local adminCommands = ServerScriptService:FindFirstChild("AdminCommands")
	logResult(adminCommands ~= nil, "AdminCommands", "ServerScriptService", "Make sure AdminCommands script is placed here.")

	local localShop = ServerScriptService:FindFirstChild("LocalShopService")
	logResult(localShop ~= nil, "LocalShopService", "ServerScriptService", "Make sure LocalShopService script is placed here.")

	local uncommonShop = ServerScriptService:FindFirstChild("UncommonShopService")
	logResult(uncommonShop ~= nil, "UncommonShopService", "ServerScriptService", "Make sure UncommonShopService script is placed here.")

	local rareShop = ServerScriptService:FindFirstChild("RareShopService")
	logResult(rareShop ~= nil, "RareShopService", "ServerScriptService", "Make sure RareShopService script is placed here.")

	local epicShop = ServerScriptService:FindFirstChild("EpicShopService")
	logResult(epicShop ~= nil, "EpicShopService", "ServerScriptService", "Make sure EpicShopService script is placed here.")

	local legShop = ServerScriptService:FindFirstChild("LegendaryShopService")
	logResult(legShop ~= nil, "LegendaryShopService", "ServerScriptService", "Should be here, but /restock will ignore it.")

	local mythicShop = ServerScriptService:FindFirstChild("MythicalShopService")
	logResult(mythicShop ~= nil, "MythicalShopService", "ServerScriptService", "Should be here, but /restock will ignore it.")

	-- 2. StarterPlayerScripts (Client Scripts)
	print("\n--- 💻 CLIENT SCRIPTS ---")
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if starterScripts then
		local notifClient = starterScripts:FindFirstChild("RestockNotificationClient")
		logResult(notifClient ~= nil, "RestockNotificationClient", "StarterPlayer > StarterPlayerScripts", "Create a LocalScript with the notification code here.")
	else
		logResult(false, "StarterPlayerScripts", "StarterPlayer", "Could not find StarterPlayerScripts folder.")
	end

	-- 3. ReplicatedStorage (Shared Modules & Remotes)
	print("\n--- 📦 REPLICATED STORAGE ---")
	local carStats = ReplicatedStorage:FindFirstChild("CarStats")
	logResult(carStats ~= nil, "CarStats Module", "ReplicatedStorage", "Make sure CarStats ModuleScript is placed here.")

	local notifRemote = ReplicatedStorage:FindFirstChild("RestockNotificationEvent")
	logResult(notifRemote ~= nil, "RestockNotificationEvent", "ReplicatedStorage", "Create a RemoteEvent named RestockNotificationEvent here.")

	-- 4. ServerStorage (Server Bindables)
	print("\n--- 🔐 SERVER STORAGE ---")
	local adminRestockBindable = ServerStorage:FindFirstChild("AdminRestockEvent")
	logResult(adminRestockBindable ~= nil, "AdminRestockEvent", "ServerStorage", "Create a BindableEvent named AdminRestockEvent here (or AdminCommands will auto-create it).")

	-- 5. StarterGui (UI Hierarchy)
	print("\n--- 🖥️ UI HIERARCHY ---")
	local notificationsGui = StarterGui:FindFirstChild("Notifications")
	if notificationsGui then
		logResult(true, "Notifications ScreenGui", "StarterGui", "")

		local notifFrame = notificationsGui:FindFirstChild("RestockNotificationFrame")
		if notifFrame then
			logResult(true, "RestockNotificationFrame", "StarterGui > Notifications", "")

			local notifText = notifFrame:FindFirstChild("RestockNotification")
			if notifText then
				logResult(true, "RestockNotification TextLabel", "StarterGui > Notifications > RestockNotificationFrame", "")

				if notifText:IsA("TextLabel") then
					if notifText.RichText then
						logResult(true, "RichText Enabled", "Properties of RestockNotification", "")
					else
						logResult(false, "RichText Enabled", "Properties of RestockNotification", "You MUST check the 'RichText' property to ON for the rarity colors to work!")
					end
				else
					logResult(false, "RestockNotification is TextLabel", "StarterGui > Notifications > RestockNotificationFrame", "RestockNotification must be a TextLabel, not a " .. notifText.ClassName)
				end
			else
				logResult(false, "RestockNotification", "StarterGui > Notifications > RestockNotificationFrame", "Create a TextLabel named RestockNotification inside the frame.")
			end
		else
			logResult(false, "RestockNotificationFrame", "StarterGui > Notifications", "Create a Frame named RestockNotificationFrame inside the Notifications ScreenGui.")
		end
	else
		logResult(false, "Notifications ScreenGui", "StarterGui", "Create a ScreenGui named Notifications in StarterGui.")
	end

	print("\n=======================================================")
	print("✅ DIAGNOSTICS COMPLETE!")
	print("Read the logs above. Anything marked ❌ FAIL needs to be fixed in Studio.")
	print("=======================================================\n")
end

-- Delay slightly to ensure everything is loaded if running in a live game
task.delay(1, runDiagnostics)
