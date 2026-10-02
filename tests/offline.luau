-- Runs the actual OfflineEarningsService against deterministic service mocks.
local function check(condition, message) assert(condition, message) end
local function equal(actual, expected, message)
	assert(actual == expected, (message or "Unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function signal()
	local callbacks={}
	return {
		Connect=function(_,callback) table.insert(callbacks,callback); return {Disconnect=function() end} end,
		Fire=function(_,...) for _, callback in ipairs(callbacks) do callback(...) end end,
	}
end
local function node(name, className)
	local object={Name=name,ClassName=className,children={},attributes={}}
	function object:IsA(class) return self.ClassName==class end
	function object:GetFullName() return self.Name end
	function object:FindFirstChild(name) return self.children[name] end
	function object:WaitForChild(name) return assert(self.children[name],"Missing mock child "..name) end
	function object:GetChildren()
		local list={}
		for _, child in pairs(self.children) do table.insert(list,child) end
		return list
	end
	function object:GetAttribute(key) return self.attributes[key] end
	function object:SetAttribute(key,value) self.attributes[key]=value end
	return object
end
local function fixture()
	return {now=1000,guid=0,disk={},inbox={},consumed={},markers={},saves=0,enqueues=0,
		saveFailure=nil,inboxFailure=false,events={}}
end
local persistedFields={"OfflineClaimId","OfflineClaimAmount","OfflineClaimState",
	"OfflineClaimPurchaseId","OfflinePremiumPendingAmount","OfflineTabletCarry"}
local function start(state)
	local Players=node("Players","Players")
	Players.PlayerAdded,Players.PlayerRemoving=signal(),signal()
	local player=node("TestPlayer","Player")
	player.UserId,player.Parent=7,Players
	player.attributes={TycoonDataLoaded=true,TycoonDataClosing=false,GamePassOwnershipReady=true,
		OccupiedPlot="P",OfflineEarningsRate=100,OfflineEarningsRateVersion=2,
		LastOfflineAt=100,OfflineTabletCarry=50,OfflineFrenzyMultiplier=1,OfflineFrenzyExpiresAt=0}
	for key,value in pairs(state.disk) do player.attributes[key]=value end
	local leaderstats=node("leaderstats","Folder")
	leaderstats.children.Wallet=node("Wallet","NumberValue")
	player.children.leaderstats=leaderstats
	function Players:GetPlayers() return {player} end
	function Players:GetPlayerByUserId(id) return id==player.UserId and player or nil end
	local ReplicatedStorage=node("ReplicatedStorage","ReplicatedStorage")
	local remotes=node("OfflineEarningsRemotes","Folder")
	for _, name in ipairs({"RequestOfflineEarnings","ClaimOfflineEarnings","BeginPremiumOfflineClaim"}) do
		remotes.children[name]=node(name,"RemoteFunction")
	end
	local result=node("OfflinePremiumClaimResult","RemoteEvent")
	function result:FireClient(_,...) table.insert(state.events,{...}) end
	remotes.children.OfflinePremiumClaimResult=result
	ReplicatedStorage.children.OfflineEarningsRemotes=remotes
	local Workspace=node("Workspace","Workspace")
	local tycoons=node("Tycoons","Folder")
	local plot=node("P","Model")
	plot.children.PlacedCars=node("PlacedCars","Folder")
	tycoons.children.P=plot
	Workspace.children.Tycoons=tycoons
	local ServerStorage=node("ServerStorage","ServerStorage")
	local admin=node("TycoonAdminAPI","BindableFunction")
	local function saveProfile()
		state.saves+=1
		local failure=state.saveFailure
		state.saveFailure=nil
		if failure~="before" then
			for _, key in ipairs(persistedFields) do state.disk[key]=player:GetAttribute(key) end
			state.disk.LastOfflineAt=state.now
		end
		return failure==nil
	end
	function admin:Invoke(action,_,...)
		if action=="SaveNow" then return saveProfile() end
		if action=="HasReceiptGrant" then local id=...; return state.markers[id]==true end
		if action=="MarkDirty" or action=="QueueSaveSoon" then return true end
		error("Unmocked admin action "..action)
	end
	ServerStorage.children.TycoonAdminAPI=admin
	local MarketplaceService=node("MarketplaceService","MarketplaceService")
	MarketplaceService.PromptProductPurchaseFinished=signal()
	local ServerScriptService=node("ServerScriptService","ServerScriptService")
	local inboxApi={}
	function inboxApi.HasIssued(_,id)
		if state.inboxFailure then return nil,"Inbox unavailable" end
		return state.inbox[id]~=nil or state.consumed[id]==true
	end
	function inboxApi.Enqueue(_,id,reward)
		if state.inboxFailure then return false,"Inbox unavailable" end
		if state.inbox[id] or state.consumed[id] then return true,"Already delivered" end
		state.inbox[id]=table.clone(reward)
		state.enqueues+=1
		return true,"Delivered"
	end
	local function module(parent,name,export)
		local child=node(name,"ModuleScript"); child.export=export; parent.children[name]=child
	end
	module(ReplicatedStorage,"CarStats",{GetCarStats=function() return nil end,
		IsMythicalCar=function() return false end,CalculateEffectiveBaseCPS=function() return 0 end})
	module(ReplicatedStorage,"GamePassConfig",{GetOfflineEarningsMultiplier=function() return 1 end})
	module(ReplicatedStorage,"GlobalMoneyFrenzyConfig",{StackConfig={MaxMultiplier=5}})
	module(ServerScriptService,"GlobalMoneyFrenzyService",{GetMultiplier=function() return 1 end})
	module(ServerScriptService,"InboxService",inboxApi)
	local HttpService={}
	function HttpService:GenerateGUID() state.guid+=1; return "mock-"..tostring(state.guid) end
	local services={Players=Players,ReplicatedStorage=ReplicatedStorage,MarketplaceService=MarketplaceService,
		Workspace=Workspace,ServerStorage=ServerStorage,ServerScriptService=ServerScriptService,HttpService=HttpService}
	local game={GetService=function(_,name) return assert(services[name],name) end}
	local require=function(object) return object.export end
	local _G={}
	local os={time=function() return state.now end,clock=function() return state.now end}
	local queued={}
	local task={
		spawn=function(callback,...) table.insert(queued,{callback=callback,args={...}}) end,
		defer=function(callback,...) table.insert(queued,{callback=callback,args={...}}) end,
		delay=function(_,callback,...) table.insert(queued,{callback=callback,args={...}}) end,
		wait=function() error("Background worker should remain queued in unit tests") end,
	}
-- SOURCE:OfflineEarningsService
	return {
		player=player,players=Players,api=_G.OfflineEarningsService,
		request=function() return remotes.children.RequestOfflineEarnings.OnServerInvoke(player) end,
		claim=function() return remotes.children.ClaimOfflineEarnings.OnServerInvoke(player) end,
		premium=function() return remotes.children.BeginPremiumOfflineClaim.OnServerInvoke(player) end,
		promptFinished=function(purchased)
			MarketplaceService.PromptProductPurchaseFinished:Fire(player.UserId,3598967453,purchased)
		end,
		save=saveProfile,
	}
end
do
	local state=fixture()
	local service=start(state)
	local response=service.request()
	check(response.ready and response.canClaim)
	equal(response.amount,27050,"Offline rate plus carry")
	equal(state.disk.OfflineTabletCarry,0,"Carry must commit with freeze")
	equal(state.enqueues,0)
	local ok,_,amount=service.claim()
	check(ok); equal(amount,27050); equal(state.enqueues,1)
	equal(service.player:GetAttribute("OfflineClaimState"),"Consumed")
	check(not service.claim()); equal(state.enqueues,1)
end
do
	local state=fixture()
	local service=start(state)
	state.saveFailure="after"
	check(not service.request().ready,"Unconfirmed freeze must not be ready")
	equal(state.enqueues,0)
	local id=service.player:GetAttribute("OfflineClaimId")
	service.player:SetAttribute("OfflineEarningsRate",999999)
	local ok,_,amount=service.claim()
	check(ok); equal(amount,27050,"Retry must use frozen amount")
	equal(service.player:GetAttribute("OfflineClaimId"),id); equal(state.enqueues,1)
end
do
	local state=fixture()
	local service=start(state)
	service.request()
	local id=state.disk.OfflineClaimId
	state.saveFailure="before"
	check(service.claim(),"Durable delivery survives failed consumed save")
	equal(service.player:GetAttribute("OfflineClaimState"),"Consumed")
	equal(state.disk.OfflineClaimState,"Pending")
	local restarted=start(state)
	local response=restarted.request()
	check(response.ready and not response.canClaim,"Recovery must detect issued award")
	equal(state.enqueues,1)
	equal(restarted.player:GetAttribute("OfflineClaimId"),id)
	equal(restarted.player:GetAttribute("OfflineClaimState"),"Consumed")
	check(not restarted.premium(),"Issued award cannot be sold again")
end
do
	local state=fixture()
	local service=start(state)
	service.request()
	local id=service.player:GetAttribute("OfflineClaimId")
	check(service.premium())
	equal(state.disk.OfflineClaimState,"Premium")
	service.promptFinished(false)
	equal(service.player:GetAttribute("OfflineClaimState"),"Pending")
	equal(service.player:GetAttribute("OfflineClaimId"),id)
	equal(service.player:GetAttribute("OfflineTabletCarry"),0)
	local ok,_,amount=service.claim()
	check(ok); equal(amount,27050); equal(state.enqueues,1)
end
do
	local state=fixture()
	local service=start(state)
	service.request(); check(service.premium())
	service.promptFinished(true); service.promptFinished(false)
	equal(service.player:GetAttribute("OfflineClaimState"),"Premium","Submitted purchase survives cancellation")
	state.saveFailure="before"
	check(not service.api.TryGrantPremium(service.player,"paid-1"))
	equal(state.enqueues,0,"Failed binding must block delivery")
	check(not service.api.TryGrantPremium(service.player,"paid-2"))
	local ok,amount=service.api.TryGrantPremium(service.player,"paid-1")
	check(ok); equal(amount,270500); equal(state.enqueues,1)
	local replayOk,replayAmount=service.api.TryGrantPremium(service.player,"paid-1")
	check(replayOk); equal(replayAmount,270500); equal(state.enqueues,1)
end
do
	local state=fixture()
	local service=start(state)
	service.request(); check(service.premium())
	check(service.api.TryGrantPremium(service.player,"paid-recovery"))
	state.now=2000
	local restarted=start(state)
	check(not restarted.request().ready,"New award must retain unsettled premium recovery")
	equal(restarted.player:GetAttribute("OfflineClaimPurchaseId"),"paid-recovery")
	check(restarted.api.TryGrantPremium(restarted.player,"paid-recovery"))
	equal(state.enqueues,1)
	state.markers["paid-recovery"]=true
	local response=restarted.request()
	check(response.ready and response.canClaim)
	equal(response.amount,30000)
	check(restarted.player:GetAttribute("OfflineClaimId")~=service.player:GetAttribute("OfflineClaimId"))
	equal(restarted.player:GetAttribute("OfflineClaimPurchaseId"),"")
end
do
	local state=fixture()
	local service=start(state)
	state.inboxFailure=true
	check(not service.request().ready); check(not service.premium()); equal(state.enqueues,0)
	state.inboxFailure=false
	check(service.request().ready)
	service.player:SetAttribute("TycoonDataClosing",true)
	check(not service.claim()); check(not service.premium())
	check(not service.api.TryGrantPremium(service.player,"closing")); equal(state.enqueues,0)
end
do
	local state=fixture()
	state.disk.OfflinePremiumPendingAmount=27050
	state.inbox["Receipt:legacy-paid:OfflinePremium"]={RewardType="Wallet",Amount=270500}
	local service=start(state)
	local ok,amount=service.api.TryGrantPremium(service.player,"legacy-paid")
	check(ok); equal(amount,270500); equal(state.enqueues,0)
	equal(service.player:GetAttribute("OfflineClaimState"),"Consumed")
end
do
	local state=fixture()
	state.disk.LastOfflineAt=1000
	state.disk.OfflineTabletCarry=0
	local service=start(state)
	local response=service.request()
	check(response.ready and not response.canClaim)
	service.save()
	state.now=2000
	local restarted=start(state)
	local response2=restarted.request()
	check(response2.ready and response2.canClaim); equal(response2.amount,30000)
end
print("Offline regressions passed: freezing, uncertain saves, recovery, paid binding, cancellation and migration")
