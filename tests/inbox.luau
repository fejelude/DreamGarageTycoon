-- Executes the repository InboxService, including its DataStore transforms.
local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = deepCopy(item) end
	return result
end
local now, guid = 1000, 0
local documents = {}
local readCalls, writeCalls = 0, 0
local failWrites = 0
local failRemoval = false
local store = {}
function store:GetAsync(key)
	readCalls += 1
	return deepCopy(documents[key])
end
function store:UpdateAsync(key, transform)
	writeCalls += 1
	if failWrites > 0 then failWrites -= 1; error("Injected DataStore outage") end
	local nextValue = transform(deepCopy(documents[key]))
	if nextValue == nil then return nil end
	if failRemoval and documents[key] and #nextValue.Entries < #documents[key].Entries then
		failRemoval = false
		error("Injected Inbox acknowledgement outage")
	end
	documents[key] = deepCopy(nextValue)
	return deepCopy(nextValue)
end
local claimMarkers = {}
local wallet = 0
local failGrant = false
local admin = {}
function admin:Invoke(action, player, entry)
	if action == "ForgetInboxClaim" then
		claimMarkers[type(entry) == "table" and entry.Id or entry] = nil
		return true
	end
	if action == "CommitInboxClaim" then
		if failGrant then return false, "Injected grant failure" end
		if not claimMarkers[entry.Id] then
			claimMarkers[entry.Id] = true
			wallet += entry.Amount
		end
		return true
	end
	error("Unexpected admin action: " .. tostring(action))
end
local event = {Connect = function() return {Disconnect = function() end} end}
local services = {
	DataStoreService = {GetDataStore = function() return store end},
	ServerStorage = {FindFirstChild = function(_, name) return name == "TycoonAdminAPI" and admin or nil end},
	ServerScriptService = {WaitForChild = function(_, name) return name end},
	HttpService = {GenerateGUID = function() guid += 1; return tostring(guid) end},
	Players = {PlayerRemoving = event},
}
local game = {JobId = "test-server", GetService = function(_, name)
	assert(services[name], "Unexpected service " .. tostring(name))
	return services[name]
end}
local os = {time = function() return math.floor(now) end, clock = function() return now end}
local scheduled = {}
local task = {
	wait = function(seconds) now += seconds or 0.1; return seconds or 0.1 end,
	spawn = function(callback, ...) table.insert(scheduled, {Callback=callback, Args=table.pack(...)}); return {} end,
	defer = function(callback, ...) callback(...) end,
	delay = function() return {} end,
	cancel = function() end,
}
local require = function(name)
	assert(name == "GiftEntitlementService")
	return {Grant = function() return true end}
end
local player = {UserId = 17, Name = "Test", Parent = services.Players, GetAttribute = function(_, name)
	if name == "TycoonDataLoaded" then return true end
	if name == "DataLoadState" then return "Ready" end
	return false
end}
local function loadInbox()
-- SOURCE:InboxService
end
local Inbox = loadInbox()
local function advance() now += 10 end
local function reward(amount, declineable)
	return {RewardType = "Wallet", Amount = amount, DisplayName = "Test reward", Declineable = declineable}
end
local function mailbox() return documents.User_17 end

assert(Inbox.Enqueue(17, "claim-once", reward(25, false)))
assert(Inbox.Accept(player, "claim-once"))
assert(wallet == 25 and #mailbox().Entries == 0, "Claim must grant and remove entry")
advance()
assert(Inbox.Enqueue(17, "claim-once", reward(25, false)))
assert(#mailbox().Entries == 0, "Acknowledged identity must never be re-enqueued")

advance()
assert(Inbox.Enqueue(17, "decline-once", reward(100, true)))
assert(Inbox.Decline(player, "decline-once"))
assert(Inbox.Enqueue(17, "decline-once", reward(100, true)))
assert(wallet == 25 and #mailbox().Entries == 0, "Decline tombstone must prevent replay")

advance()
assert(Inbox.Enqueue(17, "grant-failure", reward(7, false)))
failGrant = true
assert(not Inbox.Accept(player, "grant-failure"))
assert(mailbox().Entries[1].State == "Pending", "Failed grant must release claim lease")
failGrant = false
advance()
assert(Inbox.Accept(player, "grant-failure"))
assert(wallet == 32)

advance()
assert(Inbox.Enqueue(17, "cleanup-failure", reward(11, false)))
failRemoval = true
assert(Inbox.Accept(player, "cleanup-failure"))
assert(wallet == 43 and #mailbox().Entries == 1)
assert(claimMarkers["cleanup-failure"], "Unacknowledged profile marker must be retained")
now += 130
assert(Inbox.Accept(player, "cleanup-failure"))
assert(wallet == 43 and #mailbox().Entries == 0, "Cleanup retry must not grant twice")
assert(Inbox.Enqueue(17, "cleanup-failure", reward(11, false)))
assert(#mailbox().Entries == 0)

advance()
local callsBefore = writeCalls
assert(not Inbox.Accept(player, string.rep("x", 500)))
assert(writeCalls == callsBefore, "Oversized IDs must be rejected before a write")
assert(not Inbox.Accept(player, "nonexistent"))
assert(writeCalls == callsBefore, "Unknown IDs must be rejected before a write")

advance()
failWrites = 1
assert(not Inbox.Enqueue(17, "outage", reward(3, false)))
assert(Inbox.Enqueue(17, "outage", reward(3, false)))
assert(#mailbox().Entries == 1, "Failed enqueue must remain safely retryable")

advance()
assert(Inbox.Enqueue(17, "identity", {
	RewardType = "Car", RewardId = "TestCar", IssuedId = "issued-car-123",
	IsRobuxExclusive = true, DisplayName = "Test car",
}))
local found
for _, entry in ipairs(Inbox.Get(17)) do if entry.Id == "identity" then found = entry end end
assert(found and found.IssuedId == "issued-car-123" and found.IsRobuxExclusive,
	"Car ownership identity and paid variant must survive delivery")

print("Inbox regressions passed: claim/decline replay, uncertain cleanup, lease release, invalid IDs, outages, car identity")
