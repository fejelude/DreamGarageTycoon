-- A failed yielding save must not overwrite concurrent wallet changes.
local player={Parent=true,Attributes={}}
function player:SetAttribute(key,value) self.Attributes[key]=value end
local wallet={Value=100}
local session={DataLoaded=true,PromoCodesRedeemed={},PromoCodeRedemptionInProgress={}}
local SessionData={[player]=session}
local PROMO_CODE_REDEEMED_ATTRIBUTE="PromoCodesRedeemedJson"
local HttpService={JSONEncode=function() return "encoded" end}
local queued, dirty, saveCalls=0,0,0
local function sanitizePromoCodeHistory(value) return value end
local function getWalletValue() return wallet end
local function markDirty() dirty+=1 end
local function queueCriticalSave() queued+=1; return true end
local function save()
	saveCalls+=1
	-- Simulates another gameplay operation spending during the DataStore yield.
	wallet.Value-=20
	return false
end
-- FUNCTION:TycoonDataHandler:redeemPromoCode
local success=redeemPromoCode(player,"RELEASE",{
	Enabled=true,RewardType="WalletCash",RewardAmount=50,OncePerPlayer=true,
})
assert(success and wallet.Value==130,"Uncertain saves must keep the reward and concurrent spending")
assert(session.PromoCodesRedeemed.RELEASE and queued==1 and dirty>0)
assert(not redeemPromoCode(player,"RELEASE",{
	Enabled=true,RewardType="WalletCash",RewardAmount=50,OncePerPlayer=true,
}),"A staged redemption marker must prevent a second reward")
assert(wallet.Value==130 and saveCalls==1)
print("Profile reward regression passed: uncertain save preserves redemption and concurrent spending")
