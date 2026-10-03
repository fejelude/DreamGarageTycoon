-- Actual-source ownership/receipt and variant reservation regressions.
do
	local Players = {}
	local MAX_INVENTORY_SIZE, DEFAULT_CAR_STORAGE_LIMIT = 500, 5
	local deferred, indexCalls, nextId = {}, 0, 0
	local task = {defer = function(callback) table.insert(deferred, callback) end}
	local function container(name)
		local value = {Name=name, Children={}}
		function value:GetChildren() return table.clone(self.Children) end
		return value
	end
	local backpack, gear = container("Backpack"), container("StarterGear")
	local player = {Parent=Players, Attributes={RankStorageLimit=5}, Backpack=backpack, StarterGear=gear}
	backpack.Parent, gear.Parent = player, player
	local waitClosesSession = false
	function player:FindFirstChild(name)
		if name == "Backpack" then
			if waitClosesSession then return nil end
			return backpack
		end
		return name == "StarterGear" and gear or nil
	end
	function player:WaitForChild()
		waitClosesSession = false
		self.Attributes.TycoonDataClosing = true
		return backpack
	end
	function player:GetAttribute(key) return self.Attributes[key] end
	function player:SetAttribute(key,value) self.Attributes[key]=value end
	local session = {DataLoaded=true, RobuxProductReceipts={}, LuckySpinHistory={}}
	local SessionData = {[player]=session}
	local function tool(name)
		local value = {Name=name, Attributes={}, _parent=nil}
		function value:IsA(class) return class=="Tool" end
		function value:GetAttribute(key) return self.Attributes[key] end
		function value:SetAttribute(key,child) self.Attributes[key]=child end
		function value:Clone() return tool(self.Name) end
		function value:Destroy() self.Parent=nil end
		return setmetatable(value, {
			__index=function(self,key) if key=="Parent" then return rawget(self,"_parent") end end,
			__newindex=function(self,key,child)
				if key~="Parent" then rawset(self,key,child); return end
				local old=rawget(self,"_parent")
				if old then
					for i,entry in ipairs(old.Children) do if entry==self then table.remove(old.Children,i); break end end
				end
				rawset(self,"_parent",child)
				if child then table.insert(child.Children,self) end
			end,
		})
	end
	local template=tool("Delta Item")
	local function safeFindCarTool() return template end
	local function FindToolNameFromModel() return "Delta" end
	local function tagIssued(value,id)
		nextId+=1
		value:SetAttribute("ToolId",id)
		value:SetAttribute("IssuedId","issued:"..nextId)
		value:SetAttribute("IssuedByServer",true)
	end
	local function compactRobuxReceiptHistory(value) return value end
	local function getCurrentInventoryCount() return #backpack.Children end
	local capacityCallback
	local function canAddCarToStorage()
		if capacityCallback then capacityCallback() end
		return true
	end
	local function markDirty() session.DirtyVersion=(session.DirtyVersion or 0)+1 end
	local function markIndexDiscovered(_,id)
		indexCalls+=1
		assert(id=="Delta Item","Deferred discovery must capture the canonical name before assets change")
		coroutine.yield("slow-index")
	end
-- FUNCTION:TycoonDataHandler:giveTool
	local grant=coroutine.create(function()
		return giveTool(player,"Delta",{ReceiptPurchaseId="paid:1",ReceiptProductId=123})
	end)
	local resumed, granted=coroutine.resume(grant)
	assert(resumed and granted and coroutine.status(grant)=="dead","Car grants must return before yielding index discovery")
	assert(indexCalls==0 and #deferred==1 and #backpack.Children==1)
	assert(session.RobuxProductReceipts["paid:1"],"Ownership and paid identity must commit synchronously")
	assert(backpack.Children[1]:GetAttribute("IssuedId")==gear.Children[1]:GetAttribute("IssuedId"))
	template.Name="Renamed Item"
	local discovery=coroutine.create(deferred[1])
	assert(coroutine.resume(discovery))
	assert(indexCalls==1 and session.RobuxProductReceipts["paid:1"],"A yielding derived update must see an already recorded paid grant")
	template.Name="Delta Item"
	assert(giveTool(player,"Delta",{ReceiptPurchaseId="paid:1",ReceiptProductId=123}))
	assert(#backpack.Children==1,"Retrying a receipt must not grant another car")

	local CarStats={GetCarId=function(id) return id=="Delta" and "Delta" or nil end}
	local rank={Invoke=function() return true end}
	local ServerStorage={FindFirstChild=function() return rank end}
	local function queueCriticalSave() return true end
	local function getWalletValue() return {Value=100} end
	local snapshots=0
	local function save()
		snapshots+=1
		assert(session.RobuxProductReceipts["Inbox:reward:1"],"Inbox identity must exist before a save can include its car")
		return true
	end
-- FUNCTION:TycoonDataHandler:commitInboxClaim
	local claim=coroutine.create(function()
		return commitInboxClaim(player,{Id="reward:1",RewardType="Car",RewardId="Delta",Source="Daily Reward"})
	end)
	local ok, accepted=coroutine.resume(claim)
	assert(ok and accepted and coroutine.status(claim)=="dead" and snapshots==1)
	assert(#backpack.Children==2 and session.RobuxProductReceipts["Inbox:reward:1"])
	assert(commitInboxClaim(player,{Id="reward:1",RewardType="Car",RewardId="Delta",Source="Daily Reward"}))
	assert(#backpack.Children==2,"Inbox retries must preserve one ownership grant")

	capacityCallback=function() session.Closing=true end
	assert(not giveTool(player,"Delta"),"A capacity callback cannot grant after closing the session")
	assert(#backpack.Children==2)
	session.Closing=false
	capacityCallback=function() player:SetAttribute("RankStorageLimit",1) end
	assert(not giveTool(player,"Delta"),"Capacity must be rechecked after yielding rank validation")
	assert(#backpack.Children==2)
	capacityCallback=nil
	player:SetAttribute("RankStorageLimit",5)
	waitClosesSession=true
	assert(not giveTool(player,"Delta"),"Backpack wait cannot resume into a closing profile grant")
	assert(#backpack.Children==2)
	player:SetAttribute("TycoonDataClosing",false)
	session.LeaseLost=true
	assert(not giveTool(player,"Delta"),"A lost lease cannot receive an ownership mutation")
	session.LeaseLost=false
	session.DataLoaded=false
	assert(not giveTool(player,"Delta"),"Ordinary grants must wait for full profile readiness")
	assert(giveTool(player,"Delta",{Source="DataLoad",SuppressIndexMark=true}),"Authoritative restoration must remain allowed during initialization")
end

do
	local player={Attributes={},Backpack={Children={}},StarterGear={Children={}}}
	function player:GetAttribute(key) return self.Attributes[key] end
	function player:FindFirstChild(name) return self[name] end
	function player.Backpack:GetChildren() return table.clone(self.Children) end
	function player.StarterGear:GetChildren() return table.clone(self.Children) end
	local function owned(id,exclusive,parent)
		local value={Name=exclusive and "Exclusive (Delta)" or "Delta Item",Attributes={
			ToolId="Delta Item",IssuedId=id,IsRobuxExclusive=exclusive,
		},Parent=parent}
		function value:IsA(class) return class=="Tool" end
		function value:GetAttribute(key) return self.Attributes[key] end
		function value:Destroy()
			for i,entry in ipairs(self.Parent.Children) do if entry==self then table.remove(self.Parent.Children,i); break end end
			self.Parent=nil
		end
		table.insert(parent.Children,value)
		return value
	end
	local function reset(normalSlot,exclusiveSlot)
		player.Backpack.Children={}
		player.StarterGear.Children={}
		player.Attributes={HotbarSlot1=normalSlot and "Delta" or "",HotbarSlot2=exclusiveSlot and "Exclusive (Delta)" or ""}
		local normal=owned("normal",false,player.Backpack)
		local exclusive=owned("exclusive",true,player.Backpack)
		owned("normal",false,player.StarterGear)
		owned("exclusive",true,player.StarterGear)
		return normal,exclusive
	end
-- FUNCTION:TycoonDataHandler:toolMatchesId
-- FUNCTION:TycoonDataHandler:toolIdMatchesTarget
-- FUNCTION:TycoonDataHandler:getHotbarReservationCount
-- FUNCTION:TycoonDataHandler:hasProtectedSacrificeAttribute
-- FUNCTION:TycoonDataHandler:isProtectedFromSacrifice
-- FUNCTION:TycoonDataHandler:selectPreferredSacrificeTool
-- FUNCTION:TycoonDataHandler:removeMatchingTools
	reset(true,false)
	assert(getHotbarReservationCount(player,"Delta",false)==1 and getHotbarReservationCount(player,"Delta",true)==0)
	assert(selectPreferredSacrificeTool(player,"Delta").IssuedId=="exclusive","An ordinary slot protects the ordinary copy")
	reset(false,true)
	assert(selectPreferredSacrificeTool(player,"Delta").IssuedId=="normal","An exclusive slot protects the exclusive copy")
	reset(true,true)
	assert(getHotbarReservationCount(player,"Delta")==2)
	assert(not selectPreferredSacrificeTool(player,"Delta"),"Both reserved variants must remain unavailable")
	player.Attributes.HotbarSlot2="Exclusive (Other)"
	assert(getHotbarReservationCount(player,"Delta")==1,"Different base cars must not share reservations")
	local normal,exclusive=reset(false,true)
	assert(removeMatchingTools(player,"Delta",2)==1)
	assert(normal.Parent==nil and exclusive.Parent==player.Backpack,"Legacy removals must preserve the reserved exclusive")
	assert(#player.StarterGear.Children==1 and player.StarterGear.Children[1]:GetAttribute("IssuedId")=="exclusive")
	normal,exclusive=reset(true,false)
	assert(removeMatchingTools(player,"Delta",2)==1)
	assert(exclusive.Parent==nil and normal.Parent==player.Backpack,"Legacy removals must preserve the reserved ordinary copy")
	assert(#player.StarterGear.Children==1 and player.StarterGear.Children[1]:GetAttribute("IssuedId")=="normal")
end
print("Ownership regressions passed: synchronous grants, lifecycle checks and exact variant hotbar reservations")
