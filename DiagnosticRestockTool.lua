-- Purpose: Deep Diagnostic Tool for Shop Content and UI Hierarchy.
-- Runs on: Server (ServerScriptService)
-- Instructions: Place this in ServerScriptService and run the game. Read the output in the Developer Console (F9) or Output window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local CarStats = nil
pcall(function()
	CarStats = require(ReplicatedStorage:WaitForChild("CarStats", 3))
end)

local function logResult(passed, name, path, notes)
	if passed then
		print(string.format("  ✅ PASS | %s | Found at: %s", name, path))
	else
		warn(string.format("  ❌ FAIL | %s | Missing from: %s | Fix: %s", name, path, notes or "Create it."))
	end
end

local SHOP_UIs = {
	Common = "LocalShopUI",
	Uncommon = "UncommonShopUi",
	Rare = "RareShopUi",
	Epic = "EpicShopUi"
}

local function runDiagnostics()
	print("\n=======================================================")
	print("🔍 STARTING DEEP SHOP DIAGNOSTICS...")
	print("=======================================================\n")

	if not CarStats or type(CarStats.Cars) ~= "table" then
		warn("❌ CRITICAL FAIL: Could not load ReplicatedStorage.CarStats. Aborting.")
		return
	end

	local carGroups = {
		Common = {},
		Uncommon = {},
		Rare = {},
		Epic = {}
	}

	-- Group cars by rarity
	for carName, data in pairs(CarStats.Cars) do
		if carGroups[data.Rarity] then
			table.insert(carGroups[data.Rarity], carName)
		end
	end

	local CarToolsFolder = ServerStorage:FindFirstChild("CarTools")
	if not CarToolsFolder then
		warn("❌ CRITICAL FAIL: ServerStorage.CarTools folder is missing. No cars can be given!")
	end

	-- Check each tier
	for rarity, expectedCars in pairs(carGroups) do
		print(string.format("\n================ [ %s SHOP ] ================", string.upper(rarity)))

		-- 1. Check UI Hierarchy
		local uiName = SHOP_UIs[rarity]
		local gui = StarterGui:FindFirstChild(uiName)
		local scrollFrame = nil

		if gui then
			local mainFrame = gui:FindFirstChild("MainFrame")
			if mainFrame then
				scrollFrame = mainFrame:FindFirstChild("ScrollFrame")
				if scrollFrame then
					print(string.format("\n--- 🖥️ UI HIERARCHY FOUND: StarterGui > %s > MainFrame > ScrollFrame ---", uiName))
					-- Print the actual contents of the ScrollFrame
					local children = scrollFrame:GetChildren()
					print(string.format("Found %d total UI elements in ScrollFrame.", #children))
					for _, child in ipairs(children) do
						if child:IsA("GuiObject") then
							local subChildren = {}
							for _, sub in ipairs(child:GetChildren()) do table.insert(subChildren, sub.Name) end
							print(string.format("  ├─ [%s] %s -> Contains: { %s }", child.ClassName, child.Name, table.concat(subChildren, ", ")))
						end
					end
				else
					logResult(false, "ScrollFrame", string.format("StarterGui > %s > MainFrame", uiName), "Create a ScrollingFrame named ScrollFrame here.")
				end
			else
				logResult(false, "MainFrame", string.format("StarterGui > %s", uiName), "Create a Frame named MainFrame here.")
			end
		else
			logResult(false, uiName, "StarterGui", "Create a ScreenGui named " .. uiName)
		end

		-- 2. Check Expected Cars (UI Cards & ServerStorage Tools)
		print("\n--- 🚘 EXPECTED CAR VALIDATION ---")
		for _, carName in ipairs(expectedCars) do
			print(string.format("\n  [ Examining: %s ]", carName))

			-- Check Tool
			local toolExists = false
			if CarToolsFolder then
				local rarityFolder = CarToolsFolder:FindFirstChild(rarity)
				if rarityFolder then
					if rarityFolder:FindFirstChild(carName) or rarityFolder:FindFirstChild(carName .. " Item") then
						toolExists = true
					end
				else
					logResult(false, rarity .. " Folder", "ServerStorage > CarTools", "Create a folder named " .. rarity)
				end
			end
			logResult(toolExists, "Tool Model", string.format("ServerStorage > CarTools > %s", rarity), string.format("Add the tool named '%s' or '%s Item'.", carName, carName))

			-- Check UI Card
			if scrollFrame then
				local card = scrollFrame:FindFirstChild(carName)
				if card then
					logResult(true, "UI Card Frame", string.format("ScrollFrame > %s", carName), "")

					-- Check required buttons/images inside the card
					local buyBtn = card:FindFirstChild("BuyButton")
					logResult(buyBtn ~= nil, "BuyButton", string.format("Card '%s'", carName), "Create a TextButton or ImageButton named BuyButton inside this card.")

					local robuxBtn = card:FindFirstChild("RobuxButton")
					-- We won't strictly fail this if they don't want robux buttons, but we'll note it.
					if not robuxBtn then
						print(string.format("  ⚠️ INFO | RobuxButton | Missing from: Card '%s' | Note: Not required, but players cannot buy with Robux.", carName))
					end

					local noStockBtn = card:FindFirstChild("NoStockIndicator")
					logResult(noStockBtn ~= nil, "NoStockIndicator", string.format("Card '%s'", carName), "Create a GuiObject named NoStockIndicator inside this card (used for near-misses).")

					local imageContainer = card:FindFirstChild("CarImageContainer")
					local directImage = card:FindFirstChild(carName .. "-Image") or card:FindFirstChild("CarImage")

					if imageContainer then
						local img = imageContainer:FindFirstChild("CarImage")
						logResult(img ~= nil, "CarImage (inside Container)", string.format("Card '%s' > CarImageContainer", carName), "Create an ImageLabel named CarImage inside the CarImageContainer.")
					elseif directImage then
						logResult(true, "CarImage (Direct)", string.format("Card '%s'", carName), "")
					else
						logResult(false, "Car Image Element", string.format("Card '%s'", carName), "Create EITHER a 'CarImageContainer' with a 'CarImage' inside, OR an ImageLabel named 'CarImage' or '" .. carName .. "-Image'.")
					end
				else
					logResult(false, "UI Card Frame", string.format("ScrollFrame > %s", carName), string.format("Create a Frame inside ScrollFrame and name it EXACTLY '%s' to match CarStats.", carName))
				end
			end
		end
	end

	print("\n=======================================================")
	print("✅ DEEP DIAGNOSTICS COMPLETE!")
	print("Scroll up and fix anything marked ❌ FAIL.")
	print("=======================================================\n")
end

task.delay(1, runDiagnostics)
