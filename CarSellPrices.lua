-- Purpose: Defines the sell prices for all cars, used by Lorraine NPC system.
-- Runs on: Shared
-- Location: ReplicatedStorage > CarSellPrices
-- Dependencies: CarStats
-- Public API: CarSellPrices.GetPrice(carId)
-- Security: Server relies on this to calculate transaction amounts.
-- Performance: Prices are cached at load time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CarStats = require(ReplicatedStorage:WaitForChild("CarStats"))

local CarSellPrices = {}
local SELL_MULTIPLIER = 0.50 -- 50% of base price

CarSellPrices.Prices = {}

-- Initialize the sell prices based on CarStats
for carId, stats in pairs(CarStats.Cars) do
	if stats.Price and stats.Name then
		CarSellPrices.Prices[carId] = {
			Name = stats.Name,
			SellPrice = math.floor(stats.Price * SELL_MULTIPLIER)
		}
	end
end

-- Safely lookup car sell price and display name
function CarSellPrices.GetDetails(carId)
	if not carId then return nil end

	-- Clean ID just in case it has " Item" appended
	local cleanId = carId:gsub(" Item", ""):gsub("Item", "")

	return CarSellPrices.Prices[cleanId]
end

return CarSellPrices
