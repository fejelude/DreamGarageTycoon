-- ==============================================================================
-- 🛠️ Car System Diagnostics Report
-- ==============================================================================
-- Purpose: Scans ServerStorage (CarModels & CarTools) and Tycoon Pads to detect
-- missing models, missing tools, misnamed objects, missing prompts, and
-- configuration issues that prevent cars from being placed or picked up.
-- Runs on: Server
-- Location: ServerScriptService > CarSystemDiagnostics
-- ==============================================================================

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local TycoonsFolder = Workspace:FindFirstChild("Tycoons")

local CarModels = ServerStorage:FindFirstChild("CarModels")
local CarTools = ServerStorage:FindFirstChild("CarTools")

print("\n\n==================================================")
print("🚀 STARTING CAR SYSTEM DIAGNOSTICS...")
print("==================================================\n")

-- 1. Check base folders
local fatalError = false
if not CarModels then warn("❌ FATAL: ServerStorage.CarModels is missing!"); fatalError = true end
if not CarTools then warn("❌ FATAL: ServerStorage.CarTools is missing!"); fatalError = true end
if not TycoonsFolder then warn("❌ FATAL: Workspace.Tycoons is missing!"); fatalError = true end

if fatalError then
	warn("🚨 Halting diagnostics due to missing core folders.")
	return
end

-- 2. Analyze Models
print("📦 Checking CarModels...")
local modelNames = {}
local modelCount = 0
for _, model in pairs(CarModels:GetDescendants()) do
	if model:IsA("Model") then
		modelCount += 1
		local cleanName = model.Name:gsub(" Item", ""):gsub("Item", "")
		modelNames[cleanName] = model

		-- Check for PrimaryPart
		if not model.PrimaryPart then
			warn("  ⚠️ Model without PrimaryPart found: " .. model.Name)
		end
	end
end
print("   ✅ Found " .. modelCount .. " models.")

-- 3. Analyze Tools
print("\n🎒 Checking CarTools...")
local toolNames = {}
local toolCount = 0
for _, tool in pairs(CarTools:GetDescendants()) do
	if tool:IsA("Tool") then
		toolCount += 1
		local cleanName = tool.Name:gsub(" Item", ""):gsub("Item", "")
		toolNames[cleanName] = tool

		-- Check Handle
		if not tool:FindFirstChild("Handle") then
			warn("  ⚠️ Tool missing 'Handle': " .. tool.Name)
		end

		-- Check ToolId Attribute
		local toolId = tool:GetAttribute("ToolId")
		if not toolId then
			warn("  ⚠️ Tool missing 'ToolId' Attribute: " .. tool.Name)
		elseif toolId ~= cleanName and toolId ~= tool.Name then
			warn("  ⚠️ ToolId Attribute mismatch: " .. tool.Name .. " (ToolId: " .. toolId .. ")")
		end
	end
end
print("   ✅ Found " .. toolCount .. " tools.")

-- 4. Cross-Reference Tools and Models
print("\n🔄 Cross-Referencing Tools and Models...")
local orphanedModels = 0
local orphanedTools = 0

for cleanName, _ in pairs(modelNames) do
	if not toolNames[cleanName] then
		warn("  ❌ Missing Tool for Model: " .. cleanName)
		orphanedModels += 1
	end
end

for cleanName, tool in pairs(toolNames) do
	if not modelNames[cleanName] then
		warn("  ❌ Missing Model for Tool: " .. tool.Name)
		orphanedTools += 1
	end
end

if orphanedModels == 0 and orphanedTools == 0 then
	print("   ✅ All tools and models are perfectly paired!")
else
	warn("   ⚠️ Found " .. orphanedModels .. " orphaned models and " .. orphanedTools .. " orphaned tools.")
end

-- 5. Analyze Tycoon Pads
print("\n🏢 Checking Tycoon Placement Pads...")
local padIssues = 0
for _, tycoon in pairs(TycoonsFolder:GetChildren()) do
	local padsFolder = tycoon:FindFirstChild("Pads")
	if not padsFolder then
		warn("  ⚠️ Tycoon missing 'Pads' folder: " .. tycoon.Name)
		padIssues += 1
		continue
	end

	for _, padModel in pairs(padsFolder:GetChildren()) do
		local padPart = nil
		if padModel:IsA("BasePart") then
			padPart = padModel
		elseif padModel:IsA("Model") then
			padPart = padModel.PrimaryPart or padModel:FindFirstChildWhichIsA("BasePart")
		end

		if not padPart then
			warn("  ❌ Pad missing BasePart: " .. tycoon.Name .. " -> " .. padModel.Name)
			padIssues += 1
			continue
		end

		-- Check Prompts
		local placePrompt = padPart:FindFirstChild("PlacePrompt")
		local pickupPrompt = padPart:FindFirstChild("PickupPrompt")

		if not placePrompt then warn("  ❌ Missing PlacePrompt: " .. tycoon.Name .. " -> " .. padModel.Name); padIssues += 1 end
		if not pickupPrompt then warn("  ❌ Missing PickupPrompt: " .. tycoon.Name .. " -> " .. padModel.Name); padIssues += 1 end

		-- Check State Values
		local isOccupied = padPart:FindFirstChild("IsOccupied")
		if not isOccupied or not isOccupied:IsA("BoolValue") then
			warn("  ❌ Missing or invalid 'IsOccupied' BoolValue: " .. tycoon.Name .. " -> " .. padModel.Name)
			padIssues += 1
		end

		local linkedCar = padPart:FindFirstChild("LinkedCar")
		if not linkedCar or not linkedCar:IsA("ObjectValue") then
			warn("  ❌ Missing or invalid 'LinkedCar' ObjectValue: " .. tycoon.Name .. " -> " .. padModel.Name)
			padIssues += 1
		end
	end
end

if padIssues == 0 then
	print("   ✅ All pads are correctly configured!")
else
	warn("   🚨 Found " .. padIssues .. " issues with tycoon pads.")
end

print("\n==================================================")
print("✅ DIAGNOSTICS COMPLETE")
print("==================================================\n")
