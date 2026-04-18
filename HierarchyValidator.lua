-- Purpose: Validates Tycoon plot hierarchy dynamically on server boot.
-- Runs on: Server
-- Location: ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TycoonFolder = Workspace:WaitForChild("Tycoons")

local function validateHierarchy()
	local allGood = true
	local dedicatedFolder = ReplicatedStorage:FindFirstChild("TycoonLevelStorage")

	if not dedicatedFolder then
		warn("⚠️ Hierarchy Validator: 'TycoonLevelStorage' missing in ReplicatedStorage! Level 2 bases will fail to load.")
		allGood = false
	end

	for i = 1, 6 do
		local plotName = "Tycoon" .. i
		local plot = TycoonFolder:FindFirstChild(plotName)

		if not plot then
			warn("⚠️ Hierarchy Validator: Missing Plot '" .. plotName .. "' in Workspace.Tycoons")
			allGood = false
		else
			if not plot:FindFirstChild("Level1") then
				warn("⚠️ Hierarchy Validator: Missing 'Level1' in Workspace.Tycoons." .. plotName)
				allGood = false
			end
			if plot:FindFirstChild("Level2") then
				warn("⚠️ Hierarchy Validator: 'Level2' should NOT be in Workspace.Tycoons." .. plotName .. " on startup! It must be parked in TycoonLevelStorage.")
				allGood = false
			end
		end

		if dedicatedFolder then
			local plotStorage = dedicatedFolder:FindFirstChild(plotName)
			if not plotStorage then
				warn("⚠️ Hierarchy Validator: Missing '" .. plotName .. "' folder in TycoonLevelStorage")
				allGood = false
			else
				if not plotStorage:FindFirstChild("Level2") then
					warn("⚠️ Hierarchy Validator: Missing 'Level2' in TycoonLevelStorage." .. plotName)
					allGood = false
				end
				if plotStorage:FindFirstChild("Level1") then
					warn("⚠️ Hierarchy Validator: 'Level1' should NOT be in TycoonLevelStorage." .. plotName .. " on startup! It must be strictly left in Workspace.")
					allGood = false
				end
			end
		end
	end

	if allGood then
		print("✅ Hierarchy Validator: Tycoon Level structure is perfectly configured.")
	end
end

task.spawn(validateHierarchy)
