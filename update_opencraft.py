import re

for filepath in ["MythicalShopController", "LegendaryShopController"]:
    with open(filepath, "r") as f:
        content = f.read()

    # Move the 'Already crafting' logic from AttemptCraft to OpenCraftingMenu.

    # Wait, the user specifically said: "Now, if a player is already crafting a car and tries to select another one (e.g., from the MainFrame like Larossa or another legendary car), they shouldn’t be able to proceed directly. Instead: The NPC should display dialogue indicating that a car is already being crafted. After about 3 seconds, the Active Craft Frame appears."
    # Wait, what if they select the SAME car that is currently crafting? Should it also just show the Active Craft frame?
    # Yes, any selection if crafting is active.
    # What if they just click the "Premium Craft" on the Active Craft frame? The Active Craft frame has a "Premium Craft" button too, right?
    # NO! The Active Craft frame ONLY has an "Exit" button!
    # Wait, where is the "Premium Craft" button? It's on the `carName .. "Crafting"` menu! (The carFrame).
    # "What’s currently happening is incorrect: the Active Craft Frame appears immediately after clicking the normal confirm button (non-premium), which skips the intended flow."
    # Wait, "the Active Craft Frame appears immediately after clicking the normal confirm button (non-premium)".
    # If they click the normal confirm button, `AttemptCraft` runs, starts the craft, and currently `UpdateDisplay` does NOT auto-show the Active Craft frame because I removed it.
    # But wait, if they start a craft, shouldn't they see the Active Craft frame eventually?
    # The user says: "To clarify the correct behavior: The Active Craft Frame should only appear when crafting is already in progress and the player attempts another craft."
    # Wait! The user says "The Active Craft Frame should ONLY appear when crafting is already in progress and the player attempts another craft."
    # "Players can still browse cars freely in the MainFrame. However, when they attempt to select a new car while crafting is ongoing, that’s when the restriction + NPC dialogue + delayed Active Craft Frame should happen."
    pass
