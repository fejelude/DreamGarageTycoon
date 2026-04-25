import re

for filepath, skip_product_id in [("MythicalShopController", "MYTHICAL_SKIP_PRODUCT_ID"), ("LegendaryShopController", "LEGENDARY_SKIP_PRODUCT_ID")]:
    with open(filepath, "r") as f:
        content = f.read()

    # Step 1: Remove auto pop up from UpdateActiveCraftPanel
    # We will just comment out `panel.Visible = true` inside UpdateActiveCraftPanel
    if filepath == "MythicalShopController":
        content = content.replace("			panel.Visible = true\n\n			local nameLabel = panel:FindFirstChild(\"CarNameLabel\")", "			-- panel.Visible = true removed\n\n			local nameLabel = panel:FindFirstChild(\"CarNameLabel\")")

    # Step 3: Remove ShowActiveCraftPanel() from OnClientEvent on open
    if filepath == "LegendaryShopController":
        content = content.replace(
            "			mainFrame.Visible = true\n			ShowActiveCraftPanel()\n		end)",
            "			mainFrame.Visible = true\n			-- ShowActiveCraftPanel() removed to not auto pop up\n		end)"
        )
        # In LegendaryShopController, it's actually:
        # mainFrame.Visible = true
        # ShowActiveCraftPanel()
        content = content.replace("			mainFrame.Visible = true\n			ShowActiveCraftPanel()", "			mainFrame.Visible = true\n			-- ShowActiveCraftPanel() removed to not auto pop up")

    if filepath == "MythicalShopController":
        content = content.replace(
            "			mainFrame.Visible = true\n		end)",
            "			mainFrame.Visible = true\n			-- ShowActiveCraftPanel() removed to not auto pop up\n		end)"
        )

    already_crafting_start = content.find("-- Already crafting")
    if already_crafting_start == -1:
        already_crafting_start = content.find("-- ── Already crafting")

    if already_crafting_start != -1:
        # Find the matching 'return\n\t\tend' block
        already_crafting_end = content.find("return\n\t\tend", already_crafting_start) + len("return\n\t\tend")

        replacement = f"""-- Already crafting
		if currentState.ActiveCrafts and currentState.ActiveCrafts[carName] then
			if isPremium then
				-- Skip the dialogue and just prompt the purchase
				MarketplaceService:PromptProductPurchase(player, {skip_product_id})
				return
			end
			local delta   = math.max(0, currentState.ActiveCrafts[carName] - os.time())
			local timeStr = string.format("%02d:%02d:%02d",
				math.floor(delta / 3600), math.floor((delta % 3600) / 60), math.floor(delta % 60))"""

        if filepath == "MythicalShopController":
            replacement += """
			ethourahSpeak(pickRandom({
				"Patience. you cant make another one dude. im already making the <font color='#B652FF'>" .. displayName .. "</font> right now. It will be ready in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"i am making a car for you at this moment " .. coloredName .. " i am making <font color='#B652FF'>" .. displayName .. "</font>. Check back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"You cant rush perfection " .. coloredName .. " The <font color='#B652FF'>" .. displayName .. "</font> needs <font color='#FF4C4C'>" .. timeStr .. "</font> more time, come back later alright?",
				"I am working as fast as I can. Come back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"The metal is still hot. You must wait exactly <font color='#FF4C4C'>" .. timeStr .. "</font> before the build is complete.",
			}), function()
				task.wait(2)
				ShowActiveCraftPanel()
				restoreToCraftingFrame()
			end)
			return
		end"""
        else:
            replacement += """
			angeloSpeak(pickRandom({
				"Patience. you cant make another one dude. im already making the <font color='#B652FF'>" .. displayName .. "</font> right now. It will be ready in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"i am making a car for you at this moment " .. coloredName .. " i am making <font color='#B652FF'>" .. displayName .. "</font>. Check back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"You cant rush perfection " .. coloredName .. " The <font color='#B652FF'>" .. displayName .. "</font> needs <font color='#FF4C4C'>" .. timeStr .. "</font> more time, come back later alright?",
				"I am working as fast as I can. Come back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
				"The metal is still hot. You must wait exactly <font color='#FF4C4C'>" .. timeStr .. "</font> before the build is complete.",
			}), function()
				task.wait(2)
				ShowActiveCraftPanel()
				restoreToCraftingFrame()
			end)
			return
		end"""

        content = content[:already_crafting_start] + replacement + content[already_crafting_end:]

        with open(filepath, "w") as f:
            f.write(content)
