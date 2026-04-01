import os

services = ['LocalShopService', 'UncommonShopService', 'RareShopService', 'EpicShopService']

old_code = '''		local toolSource = nil
		if toolsFolder then
			toolSource = (function()
				local t = toolsFolder:FindFirstChild(carName, true) or toolsFolder:FindFirstChild(carName .. " Item", true)
				if not t then
					local clean = carName:gsub(" Item", ""):gsub("Item", "")
					for _, d in pairs(toolsFolder:GetDescendants()) do
						if d.Name == clean or d.Name:gsub(" Item", "") == clean then return d end
					end
				end
				return t
			end)()
			if not toolSource then
				local clean = carName:gsub(" Item", ""):gsub("Item", "")
				for _, t in pairs(toolsFolder:GetDescendants()) do
					if t.Name == clean or t.Name:gsub(" Item", "") == clean then
						toolSource = t
						break
					end
				end
			end
		end'''

new_code = '''		local toolSource = nil
		if toolsFolder then
			toolSource = toolsFolder:FindFirstChild(carName, true) or toolsFolder:FindFirstChild(carName .. " Item", true)
			if not toolSource then
				local clean = carName:gsub(" Item", ""):gsub("Item", "")
				for _, t in pairs(toolsFolder:GetDescendants()) do
					if t.Name == clean or t.Name:gsub(" Item", "") == clean then
						toolSource = t
						break
					end
				end
			end
		end'''

for s in services:
    if not os.path.exists(s):
        continue
    with open(s, 'r') as f:
        content = f.read()
    if old_code in content:
        content = content.replace(old_code, new_code)
        with open(s, 'w') as f:
            f.write(content)
        print(f"Cleaned {s}")
