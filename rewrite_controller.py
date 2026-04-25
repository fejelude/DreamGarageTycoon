import re

def process_file(filepath, skip_product_id):
    with open(filepath, "r") as f:
        content = f.read()

    # Step 1: Remove auto pop up from UpdateActiveCraftPanel
    # We will just comment out `panel.Visible = true` inside UpdateActiveCraftPanel
    if filepath == "MythicalShopController":
        content = content.replace("			panel.Visible = true\n\n			local nameLabel = panel:FindFirstChild(\"CarNameLabel\")", "			-- panel.Visible = true\n\n			local nameLabel = panel:FindFirstChild(\"CarNameLabel\")")

    # Step 2: Add ShowActiveCraftPanel if missing
    if filepath == "MythicalShopController" and "local function ShowActiveCraftPanel" not in content:
        show_active_craft = """
-- FIX: Sole gatekeeper for showing the Active Craft panel.
local function ShowActiveCraftPanel()
	local panel = gui:FindFirstChild("ActiveCraftPanel")
	if not panel then return end
	if currentState and currentState.ActiveCrafts and next(currentState.ActiveCrafts) then
		panel.Visible = true
		UpdateActiveCraftPanel()
	end
end

local function UpdateDisplay()"""
        content = content.replace("local function UpdateDisplay()", show_active_craft)

    # Step 3: Remove ShowActiveCraftPanel() from OnClientEvent on open
    if filepath == "LegendaryShopController":
        content = content.replace(
            "			mainFrame.Visible = true\n			ShowActiveCraftPanel()\n		end)",
            "			mainFrame.Visible = true\n			-- ShowActiveCraftPanel() removed to not auto pop up\n		end)"
        )
    if filepath == "MythicalShopController":
        # Note: in Mythical, it's just mainFrame.Visible = true. There's no ShowActiveCraftPanel on open previously. Wait, I shouldn't replace end) here because it breaks syntax.
        pass

    # Step 4: Fix AttemptCraft logic
    # Find AttemptCraft
    if filepath == "MythicalShopController":
        pattern = r"\t\t-- Already crafting\n\t\tif currentState\.ActiveCrafts and currentState\.ActiveCrafts\[carName\] then.*?\n\t\t\treturn\n\t\tend"
        replacement = f"""		-- Already crafting
		if currentState.ActiveCrafts and currentState.ActiveCrafts[carName] then
			if isPremium then
				MarketplaceService:PromptProductPurchase(player, {skip_product_id})
				return
			end
			local delta   = math.max(0, currentState.ActiveCrafts[carName] - os.time())
			local timeStr = string.format("%02d:%02d:%02d",
				math.floor(delta / 3600), math.floor((delta % 3600) / 60), math.floor(delta % 60))
			ethourahSpeak(pickRandom({{
				"Patience. you cant make another one dude. im already making the <font color='#B652FF'>" .. displayName .. "</font> right now. It will be ready in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"i am making a car for you at this moment " .. coloredName .. " i am making <font color='#B652FF'>" .. displayName .. "</font>. Check back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"You cant rush perfection " .. coloredName .. " The <font color='#B652FF'>" .. displayName .. "</font> needs <font color='#FF4C4C'>" .. timeStr .. "</font> more time, come back later alright?",
				"I am working as fast as I can. Come back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"The metal is still hot. You must wait exactly <font color='#FF4C4C'>" .. timeStr .. "</font> before the build is complete.",
			}}), function()
				task.wait(2)
				ShowActiveCraftPanel()
				restoreToCraftingFrame()
			end)
			return
		end"""
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    else:
        pattern = r"\t\t-- \S* Already crafting.*?return\n\t\tend"
        replacement = f"""		-- ── Already crafting ─────────────────────────────────────────────────────
		if currentState.ActiveCrafts and currentState.ActiveCrafts[carName] then
			if isPremium then
				MarketplaceService:PromptProductPurchase(player, {skip_product_id})
				return
			end
			local delta   = math.max(0, currentState.ActiveCrafts[carName] - os.time())
			local timeStr = string.format("%02d:%02d:%02d",
				math.floor(delta / 3600), math.floor((delta % 3600) / 60), math.floor(delta % 60))
			angeloSpeak(pickRandom({{
				"Patience. you cant make another one dude. im already making the <font color='#B652FF'>" .. displayName .. "</font> right now. It will be ready in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"i am making a car for you at this moment " .. coloredName .. " i am making <font color='#B652FF'>" .. displayName .. "</font>. Check back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"You cant rush perfection " .. coloredName .. " The <font color='#B652FF'>" .. displayName .. "</font> needs <font color='#FF4C4C'>" .. timeStr .. "</font> more time, come back later alright?",
				"I am working as fast as I can. Come back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"The metal is still hot. You must wait exactly <font color='#FF4C4C'>" .. timeStr .. "</font> before the build is complete.",
			}}), function()
				task.wait(2)
				ShowActiveCraftPanel()
				restoreToCraftingFrame()
			end)
			return
		end"""
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)

    with open(filepath, "w") as f:
        f.write(content)

process_file("MythicalShopController", "MYTHICAL_SKIP_PRODUCT_ID")
process_file("LegendaryShopController", "LEGENDARY_SKIP_PRODUCT_ID")
