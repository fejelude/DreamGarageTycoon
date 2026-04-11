-- Purpose: Verifies all implemented features for the Legendary/Mythical crafting system.
-- Runs on: Server
-- Location: ServerScriptService.CraftingVerifier
-- Dependencies: ReplicatedStorage.CarStats, StarterGui, ServerStorage, ReplicatedStorage.ShopRemotes
-- Public API: None
-- Networking: None
-- Security: Server side script used for structural verification only.
-- Notes: Checks if all required UI elements, stat entries, and hierarchy nodes are present.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local CarStats = require(ReplicatedStorage:WaitForChild("CarStats"))

-- Expected new cars
local expectedLegendaryCars = {"Neo-Periscopio", "Neo-Performante", "Neo-Zentorno", "Neo-Revuelto", "Yamura", "La Rossa"}
local expectedMythicalCars = {"Centurion", "Grotti-Ferocious", "Solitaire", "Hyperspace"}

local expectedRecipes = {
	-- Legendary
	["Neo-Periscopio"] = { "Razor", "Maverick", "Galadriel", "Riva", "Cash" },
	["Neo-Performante"] = { "Sovereign", "Stuttgart", "Kingston", "Riva", "Cash" },
	["Neo-Zentorno"] = { "Classy", "Sadie", "Blackhead", "Riva", "Cash" },
	["Neo-Revuelto"] = { "Shaguar", "Vipera", "Mia", "Riva", "Cash" },
	["Yamura"] = { "Sirene", "Vortex", "Camara", "Mia", "Cash" },
	["LaRossa"] = { "Vortex", "Corvo", "Mia", "Riva", "Cash" },
	-- Mythical
	["Centurion"] = { "Yamura", "Vortex", "Velocity", "Blackhead", "Cash" },
	["Grotti-Ferocious"] = { "Yamura", "Vortex", "Velocity", "Mia", "Cash" },
	["Solitaire"] = { "Neo-Revuelto", "Vortex", "Corvo", "Mia", "Cash" },
	["Hyperspace"] = { "La Rossa", "Vortex", "Corvo", "Mia", "Riva", "Cash" }
}

-- Logger functions
local function logSuccess(msg)
	print("✅ [Verifier] " .. msg)
end

local function logWarning(msg)
	warn("⚠️ [Verifier Warning] " .. msg)
end

local function logError(msg)
	warn("❌ [Verifier Error] " .. msg)
end

-- Begin Verification
print("\n--- 🔍 STARTING CRAFTING SYSTEM VERIFICATION ---\n")
task.wait(2) -- Wait for hierarchy to populate fully

-- 1. Check CarStats Module
local carStatsValid = true
for _, carName in ipairs(expectedLegendaryCars) do
	if not CarStats.Cars[carName] then
		logError("Missing Legendary Car in CarStats: " .. carName)
		carStatsValid = false
	end
end
for _, carName in ipairs(expectedMythicalCars) do
	if not CarStats.Cars[carName] then
		logError("Missing Mythical Car in CarStats: " .. carName)
		carStatsValid = false
	end
end
if carStatsValid then logSuccess("All expected cars found in CarStats.") end

-- 2. Check Scripts
local expectedScripts = {
	{Parent = ServerScriptService, Name = "LegendaryShopService"},
	{Parent = ServerScriptService, Name = "MythicalShopService"}
}
for _, sData in ipairs(expectedScripts) do
	if sData.Parent:FindFirstChild(sData.Name) then
		logSuccess("Found Server Script: " .. sData.Name)
	else
		logError("Missing Server Script: " .. sData.Name)
	end
end

-- 3. Check Remotes
local shopRemotes = ReplicatedStorage:FindFirstChild("ShopRemotes")
if shopRemotes then
	local ls = shopRemotes:FindFirstChild("LegendaryShop")
	if ls then logSuccess("Found LegendaryShop Remotes Folder") else logError("Missing LegendaryShop Remotes Folder") end

	local ms = shopRemotes:FindFirstChild("MythicalShop")
	if ms then logSuccess("Found MythicalShop Remotes Folder") else logError("Missing MythicalShop Remotes Folder") end
else
	logError("Missing ShopRemotes folder in ReplicatedStorage")
end

-- 4. Check Bindables
local expectedBindables = {
	"LegendaryShopPersistenceFunction", "LegendaryCraftingInventoryFunction",
	"MythicalShopPersistenceFunction", "MythicalCraftingInventoryFunction"
}
for _, bName in ipairs(expectedBindables) do
	if ServerStorage:FindFirstChild(bName) then
		logSuccess("Found Bindable: " .. bName)
	else
		logWarning("Missing Bindable: " .. bName .. " (This might be created at runtime)")
	end
end

-- 5. Check UI & Crafting Slots (StarterGui)
local function verifyUI(uiName, recipeList)
	local ui = StarterGui:FindFirstChild(uiName)
	if not ui then
		logError("Missing UI in StarterGui: " .. uiName)
		return
	end

	logSuccess("Found UI: " .. uiName)
	local mainFrame = ui:FindFirstChild("Mainframe")
	if not mainFrame then logError("Missing Mainframe in " .. uiName); return end

	for carKey, ingredients in pairs(recipeList) do
		local craftingFrame = ui:FindFirstChild(carKey .. "Crafting")
		if not craftingFrame then
			logWarning("Missing Crafting Frame for " .. carKey .. " in " .. uiName)
			continue
		end

		local carContainer = craftingFrame:FindFirstChild(carKey)
		if not carContainer then logWarning("Missing Car Container in " .. carKey .. "Crafting"); continue end

		local sacItems = carContainer:FindFirstChild("SacrificeItems")
		if not sacItems then logWarning("Missing SacrificeItems for " .. carKey); continue end

		for _, ingredient in ipairs(ingredients) do
			if not sacItems:FindFirstChild(ingredient) then
				logWarning("Missing UI slot for ingredient '" .. ingredient .. "' in " .. carKey .. " recipe.")
			end
		end
	end
end

local legendaryRecipes = {
	["Neo-Periscopio"] = expectedRecipes["Neo-Periscopio"],
	["Neo-Performante"] = expectedRecipes["Neo-Performante"],
	["Neo-Zentorno"] = expectedRecipes["Neo-Zentorno"],
	["Neo-Revuelto"] = expectedRecipes["Neo-Revuelto"],
	["Yamura"] = expectedRecipes["Yamura"],
	["LaRossa"] = expectedRecipes["LaRossa"]
}
local mythicalRecipes = {
	["Centurion"] = expectedRecipes["Centurion"],
	["Grotti-Ferocious"] = expectedRecipes["Grotti-Ferocious"],
	["Solitaire"] = expectedRecipes["Solitaire"],
	["Hyperspace"] = expectedRecipes["Hyperspace"]
}

verifyUI("LegendaryCarsAngeloUi", legendaryRecipes)
verifyUI("MythicalCarsEthourahUi", mythicalRecipes)

-- 6. Check NPCs
local npcsFolder = Workspace:FindFirstChild("NPCS")
if npcsFolder then
	if npcsFolder:FindFirstChild("Monk3yDAngelo-Cars") then
		logSuccess("Found NPC: Monk3yDAngelo-Cars")
	else
		logWarning("Missing NPC: Monk3yDAngelo-Cars in Workspace.NPCS")
	end

	if npcsFolder:FindFirstChild("ethourah") then
		logSuccess("Found NPC: ethourah")
	else
		logWarning("Missing NPC: ethourah in Workspace.NPCS")
	end
else
	logWarning("Missing Workspace.NPCS folder")
end

print("\n--- 🏁 VERIFICATION COMPLETE ---\n")
