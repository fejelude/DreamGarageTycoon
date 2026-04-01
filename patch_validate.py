import re

with open('TycoonDataHandler', 'r') as f:
    content = f.read()

# Replace the validateTool logic
old_validate = r'''local function validateTool\(tool\)
	if not tool then return false end
	if not tool:GetAttribute\("IssuedByServer"\) then return false end
	local id = tool:GetAttribute\("ToolId"\)
	if not id then return false end
	if not CarTools:FindFirstChild\(id, true\) then return false end
	return true
end'''

new_validate = """local function validateTool(tool)
	if not tool then return false end
	if not tool:GetAttribute("IssuedByServer") then return false end
	local id = tool:GetAttribute("ToolId")
	if not id then return false end
	-- Support both formats since ID might be "Delta" but tool is "Delta Item"
	if CarTools:FindFirstChild(id, true) then return true end
	if CarTools:FindFirstChild(id .. " Item", true) then return true end
	-- Fallback deep search
	local clean = id:gsub(" Item", ""):gsub("Item", "")
	for _, t in pairs(CarTools:GetDescendants()) do
		if t.Name:gsub(" Item", "") == clean then return true end
	end
	return false
end"""

content = re.sub(old_validate, new_validate, content)

with open('TycoonDataHandler', 'w') as f:
    f.write(content)

print("Patched TycoonDataHandler")
