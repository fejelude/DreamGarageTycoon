import re

def process_file(filepath, skip_product_id):
    with open(filepath, "r") as f:
        content = f.read()

    # Step 1: Remove the "Already crafting" block from AttemptCraft since it will be handled in OpenCraftingMenu.
    if filepath == "MythicalShopController":
        pattern = r"\t\t-- Already crafting\n\t\tif currentState\.ActiveCrafts and currentState\.ActiveCrafts\[carName\] then.*?\n\t\t\treturn\n\t\tend"
        content = re.sub(pattern, "", content, flags=re.DOTALL)
    else:
        pattern = r"\t\t-- ── Already crafting ─────────────────────────────────────────────────────\n\t\tif currentState\.ActiveCrafts and currentState\.ActiveCrafts\[carName\] then.*?\n\t\t\treturn\n\t\tend"
        content = re.sub(pattern, "", content, flags=re.DOTALL)

    # Step 2: Add the "Already crafting" block into OpenCraftingMenu.
    # We will find `local function OpenCraftingMenu(carName)`
    # And insert the check right after `activeCarFocus = carName`.

    if filepath == "MythicalShopController":
        new_block = f"""
	-- ALREADY CRAFTING INTERCEPT
	if currentState and currentState.ActiveCrafts and next(currentState.ActiveCrafts) then
		local activeCar, endTime
		for c, e in pairs(currentState.ActiveCrafts) do
			activeCar, endTime = c, e
			break
		end

		local displayName = getDisplayCarName(activeCar)
		local coloredName = "<font color='" .. USER_COLOR .. "'>@" .. player.Name .. "</font>"
		local delta   = math.max(0, endTime - os.time())
		local timeStr = string.format("%02d:%02d:%02d", math.floor(delta / 3600), math.floor((delta % 3600) / 60), math.floor(delta % 60))

		ethourahSpeak(pickRandom({{
			"Patience. you cant make another one dude. im already making the <font color='#B652FF'>" .. displayName .. "</font> right now. It will be ready in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
			"i am making a car for you at this moment " .. coloredName .. " i am making <font color='#B652FF'>" .. displayName .. "</font>. Check back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
			"You cant rush perfection " .. coloredName .. " The <font color='#B652FF'>" .. displayName .. "</font> needs <font color='#FF4C4C'>" .. timeStr .. "</font> more time, come back later alright?",
			"I am working as fast as I can. Come back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
			"The metal is still hot. You must wait exactly <font color='#FF4C4C'>" .. timeStr .. "</font> before the build is complete.",
		}}), function()
			task.wait(3)
			mainFrame.Visible = true
			ShowActiveCraftPanel()
		end)
		return
	end
"""
    else:
        new_block = f"""
	-- ALREADY CRAFTING INTERCEPT
	if currentState and currentState.ActiveCrafts and next(currentState.ActiveCrafts) then
		local activeCar, endTime
		for c, e in pairs(currentState.ActiveCrafts) do
			activeCar, endTime = c, e
			break
		end

		local displayName = getDisplayCarName(activeCar)
		local coloredName = "<font color='" .. USER_COLOR .. "'>@" .. player.Name .. "</font>"
		local delta   = math.max(0, endTime - os.time())
		local timeStr = string.format("%02d:%02d:%02d", math.floor(delta / 3600), math.floor((delta % 3600) / 60), math.floor(delta % 60))

		angeloSpeak(pickRandom({{
			"Patience. you cant make another one dude. im already making the <font color='#B652FF'>" .. displayName .. "</font> right now. It will be ready in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
			"i am making a car for you at this moment " .. coloredName .. " i am making <font color='#B652FF'>" .. displayName .. "</font>. Check back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
			"You cant rush perfection " .. coloredName .. " The <font color='#B652FF'>" .. displayName .. "</font> needs <font color='#FF4C4C'>" .. timeStr .. "</font> more time, come back later alright?",
			"I am working as fast as I can. Come back in <font color='#FF4C4C'>" .. timeStr .. "</font>.",
			"The metal is still hot. You must wait exactly <font color='#FF4C4C'>" .. timeStr .. "</font> before the build is complete.",
		}}), function()
			task.wait(3)
			mainFrame.Visible = true
			ShowActiveCraftPanel()
		end)
		return
	end
"""
    content = content.replace("	activeCarFocus        = carName", "	activeCarFocus        = carName\n" + new_block)

    with open(filepath, "w") as f:
        f.write(content)

process_file("MythicalShopController", "MYTHICAL_SKIP_PRODUCT_ID")
process_file("LegendaryShopController", "LEGENDARY_SKIP_PRODUCT_ID")
