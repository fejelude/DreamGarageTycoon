-- Exercise the actual craft delivery and receipt handlers from both tiers.
local warn = function() end
local os = {time=function() return 1000 end}
local function exercise(tier, makeHandlers)
	local CRAFT_TIER, DEALER_NAME = tier, "Test dealer"
	local RECIPES = {TestCar={TargetCar="TestCar", CraftTime=60}}
	local InteractionLocks = {}
	local player = {UserId=17, Parent=true, GetAttribute=function(_, name)
		return name == "TycoonDataLoaded" and true or false
	end}
	local session, logs, delivered = nil, {}, {}
	local failures, failEnqueue = {}, false
	local saves = 0
	local queued = 0
	local function getSession() return session end
	local function savePlayerNow()
		saves += 1
		table.insert(logs,"save")
		if failures[saves] then return false, "Injected save outage" end
		return true
	end
	local function queuePlayerSaveSoon() queued += 1; return true end
	local function pushUpdate() end
	local InboxService = {Enqueue=function(_, id, reward)
		table.insert(logs,"enqueue")
		assert(saves > 0, "Craft identity must be saved before enqueue")
		if failEnqueue then return false,"Injected Inbox outage" end
		delivered[id]=reward
		return true
	end}
	local handlers = makeHandlers({
		CRAFT_TIER=CRAFT_TIER, DEALER_NAME=DEALER_NAME, RECIPES=RECIPES,
		InteractionLocks=InteractionLocks, getSession=getSession,
		savePlayerNow=savePlayerNow, queuePlayerSaveSoon=queuePlayerSaveSoon,
		pushUpdate=pushUpdate, InboxService=InboxService,
	})
	local function reset()
		session={CraftJobIds={TestCar=tier.."Craft:17:TestCar:job1"}, ActiveCrafts={TestCar=990},
			PendingPremiumCraft="TestCar", PremiumReceipts={}, CraftProgress={TestCar={Ingredient=2}},
			CompletedCrafts={}, AwardedCrafts={}}
		logs,delivered,failures,saves,queued={}, {}, {},0,0
		failEnqueue=false
	end
	reset()
	failures[1]=true
	assert(not handlers.skip(player,"receipt1"))
	assert(next(delivered)==nil and session.PremiumReceipts.receipt1.Completed==false,
		"Failed binding save must not deliver")
	assert(handlers.skip(player,"receipt1"))
	assert(session.PremiumReceipts.receipt1.Completed and next(delivered)~=nil)
	local deliveries = delivered
	session.CraftJobIds.TestCar=tier.."Craft:17:TestCar:job2"
	session.ActiveCrafts.TestCar=2000
	session.PendingPremiumCraft="TestCar"
	session.CompletedCrafts.TestCar=nil
	assert(handlers.skip(player,"receipt1"))
	assert(session.ActiveCrafts.TestCar==2000 and session.PendingPremiumCraft=="TestCar",
		"Old receipt must never finish a newly started craft")
	assert(delivered==deliveries and delivered[session.CraftJobIds.TestCar]==nil)

	reset()
	failures[3]=true -- binding, preflight, then uncertain completion save
	assert(not handlers.skip(player,"receipt2"))
	assert(session.PremiumReceipts.receipt2.Completed and session.ActiveCrafts.TestCar==nil)
	assert(handlers.skip(player,"receipt2"))
	assert(queued>0, "Uncertain completion must queue a retry")

	reset()
	failEnqueue=true
	assert(not handlers.finish(player,session,"TestCar"))
	assert(session.ActiveCrafts.TestCar==990 and session.CraftProgress.TestCar.Ingredient==2,
		"Failed Inbox write must preserve active craft and ingredients")

	reset()
	session.CraftJobIds={}
	local legacy=handlers.job(player,session,"TestCar")
	local restarted={CraftJobIds={},ActiveCrafts={TestCar=990},PendingPremiumCraft="TestCar"}
	assert(handlers.job(player,restarted,"TestCar")==legacy, "Legacy job identity must survive a crash")
	assert(not handlers.skip(player,nil), "Missing receipt identity must be rejected")
end
local function legendary(deps)
	local CRAFT_TIER, DEALER_NAME, RECIPES = deps.CRAFT_TIER, deps.DEALER_NAME, deps.RECIPES
	local InteractionLocks, getSession = deps.InteractionLocks, deps.getSession
	local savePlayerNow, queuePlayerSaveSoon = deps.savePlayerNow, deps.queuePlayerSaveSoon
	local pushUpdate, InboxService = deps.pushUpdate, deps.InboxService
	local SkipCraftFunc={}
-- FUNCTION:LegendaryShopService:isReady
-- FUNCTION:LegendaryShopService:ensureCraftJobId
-- FUNCTION:LegendaryShopService:finishCraftDelivery
-- HANDLER:LegendaryShopService:SkipCraftFunc.OnInvoke
	return {skip=SkipCraftFunc.OnInvoke,finish=finishCraftDelivery,job=ensureCraftJobId}
end
local function mythical(deps)
	local CRAFT_TIER, DEALER_NAME, RECIPES = deps.CRAFT_TIER, deps.DEALER_NAME, deps.RECIPES
	local InteractionLocks, getSession = deps.InteractionLocks, deps.getSession
	local savePlayerNow, queuePlayerSaveSoon = deps.savePlayerNow, deps.queuePlayerSaveSoon
	local pushUpdate, InboxService = deps.pushUpdate, deps.InboxService
	local SkipCraftFunc={}
-- FUNCTION:MythicalShopService:isReady
-- FUNCTION:MythicalShopService:ensureCraftJobId
-- FUNCTION:MythicalShopService:finishCraftDelivery
-- HANDLER:MythicalShopService:SkipCraftFunc.OnInvoke
	return {skip=SkipCraftFunc.OnInvoke,finish=finishCraftDelivery,job=ensureCraftJobId}
end
exercise("Legendary",legendary)
exercise("Mythical",mythical)
print("Craft regressions passed: durable identity, receipt binding, save outages and Inbox outages")
