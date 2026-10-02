-- Runs both repository migration implementations against pad and model mocks.
local warn = function() end
local frameMeta = {__mul=function(a,b) return setmetatable({Value=a.Value+b.Value}, getmetatable(a)) end}
local function frame(value) return setmetatable({Value=value}, frameMeta) end
local CFrame = {new=function(_, y) return frame(y) end}
local function getMainPart(pad) return pad end
local function getLevelModel(plot, name) return plot.Levels[name] end
local function loadUpgrade()
-- FUNCTION:BaseUpgradeTransactionHandler:migratePadOccupancy
	return migratePadOccupancy
end
local function loadProgression()
-- FUNCTION:PadProgressionHandler:migratePadOccupancy
	return migratePadOccupancy
end
local function car(value, failAt)
	local result = {Parent=true, Pivot=frame(value), Origin=frame(value), Calls=0}
	function result:IsA(kind) return kind == "Model" end
	function result:GetPivot() return self.Pivot end
	function result:GetAttribute() return self.Origin end
	function result:SetAttribute(_, value) self.Origin=value end
	function result:PivotTo(value)
		self.Calls += 1
		if self.Calls == failAt then error("Injected pivot failure") end
		self.Pivot=value
	end
	return result
end
local function pad(name, linked, target)
	local result = {Name=name, CFrame=frame(target or 0), Size={Y=2},
		IsOccupied={Value=linked ~= nil}, LinkedCar={Value=linked}}
	function result:FindFirstChild(name) return self[name] end
	return result
end
local function folder(children)
	local result = {Children=children}
	function result:GetChildren() return self.Children end
	function result:FindFirstChild(name)
		for _, child in ipairs(self.Children) do if child.Name == name then return child end end
	end
	return result
end
local function plot(from, to)
	local sourceParent, targetParent = {Pads=folder(from)}, {Pads=folder(to)}
	function sourceParent:FindFirstChild(name) return self[name] end
	function targetParent:FindFirstChild(name) return self[name] end
	return {Levels={Level1={Parent=sourceParent}, Level2={Parent=targetParent}}}
end
for _, migrate in ipairs({loadUpgrade(), loadProgression()}) do
	local first, second = car(10), car(20)
	local source = {pad("Pad1", first), pad("Pad2", second)}
	local destination = {pad("Pad1", nil, 100)}
	assert(not migrate(plot(source,destination),1,2), "Missing destination must reject all moves")
	assert(source[1].LinkedCar.Value == first and first.Pivot.Value == 10)
	assert(not destination[1].IsOccupied.Value, "Validation must not move the first car")

	first, second = car(10), car(20,1)
	source = {pad("Pad1",first), pad("Pad2",second)}
	destination = {pad("Pad1",nil,100), pad("Pad2",nil,200)}
	assert(not migrate(plot(source,destination),1,2), "Mid-application error must fail")
	for i, owned in ipairs({first,second}) do
		assert(source[i].LinkedCar.Value == owned and source[i].IsOccupied.Value)
		assert(destination[i].LinkedCar.Value == nil and not destination[i].IsOccupied.Value)
		assert(owned.Pivot.Value == i*10 and owned.Origin.Value == i*10, "Rollback restores pivot and animation origin")
	end

	first, second = car(10), car(20)
	source = {pad("Pad1",first), pad("Pad2",second)}
	destination = {pad("Pad1",nil,100), pad("Pad2",nil,200)}
	assert(migrate(plot(source,destination),1,2))
	for i, owned in ipairs({first,second}) do
		assert(source[i].LinkedCar.Value == nil and not source[i].IsOccupied.Value)
		assert(destination[i].LinkedCar.Value == owned and destination[i].IsOccupied.Value)
		assert(owned.Pivot.Value == i*100+7 and owned.Origin.Value == i*100+7)
	end
end
print("Base migration regressions passed: preflight, rollback, links and animation origins")
