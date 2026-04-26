-- Place in ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local CASH_COST = 50
local STARTING_CASH = 250
local DATASTORE_NAME = "PlayerMoneyAndPlacedParts_v1"

local templatePart = ReplicatedStorage:WaitForChild("Upgrades"):WaitForChild("Basic"):WaitForChild("Part")

local remotesFolder = ReplicatedStorage:FindFirstChild("UpgradeRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "UpgradeRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local placeRequest = remotesFolder:FindFirstChild("PlacePartRequest")
if not placeRequest then
	placeRequest = Instance.new("RemoteEvent")
	placeRequest.Name = "PlacePartRequest"
	placeRequest.Parent = remotesFolder
end

local cashChanged = remotesFolder:FindFirstChild("CashChanged")
if not cashChanged then
	cashChanged = Instance.new("RemoteEvent")
	cashChanged.Name = "CashChanged"
	cashChanged.Parent = remotesFolder
end

local datastore = DataStoreService:GetDataStore(DATASTORE_NAME)
local sessionData = {}

local function serializeCFrame(cf)
	local components = {cf:GetComponents()}
	return components
end

local function deserializeCFrame(components)
	if typeof(components) ~= "table" or #components ~= 12 then
		return CFrame.new()
	end
	return CFrame.new(table.unpack(components))
end

local function ensureStats(player, cashValue)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	local money = stats:FindFirstChild("Money")
	if not money then
		money = Instance.new("IntValue")
		money.Name = "Money"
		money.Parent = stats
	end

	money.Value = cashValue or STARTING_CASH
	return money
end

local function attachSavedPart(character, placement)
	if typeof(placement) ~= "table" then
		return
	end

	local bodyPart = character:FindFirstChild(placement.bodyPartName)
	if not bodyPart or not bodyPart:IsA("BasePart") then
		return
	end

	local newPart = templatePart:Clone()
	newPart.Anchored = false
	newPart.CanCollide = false
	newPart.CanQuery = false
	newPart.CanTouch = false
	newPart.Massless = true
	newPart.CFrame = bodyPart.CFrame * deserializeCFrame(placement.localOffset)
	newPart.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = newPart
	weld.Parent = newPart
end

local function restorePlacements(player, character)
	local playerData = sessionData[player]
	if not playerData then
		return
	end

	for _, placement in ipairs(playerData.placements) do
		attachSavedPart(character, placement)
	end
end

local function savePlayerData(player)
	local playerData = sessionData[player]
	if not playerData then
		return
	end

	local payload = {
		cash = playerData.moneyValue.Value,
		placements = playerData.placements,
	}

	local ok, err = pcall(function()
		datastore:SetAsync(tostring(player.UserId), payload)
	end)

	if not ok then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

Players.PlayerAdded:Connect(function(player)
	local stored = nil
	local ok = pcall(function()
		stored = datastore:GetAsync(tostring(player.UserId))
	end)

	if not ok or typeof(stored) ~= "table" then
		stored = {
			cash = STARTING_CASH,
			placements = {},
		}
	end

	stored.cash = tonumber(stored.cash) or STARTING_CASH
	stored.placements = typeof(stored.placements) == "table" and stored.placements or {}

	local moneyValue = ensureStats(player, stored.cash)
	sessionData[player] = {
		moneyValue = moneyValue,
		placements = stored.placements,
	}

	cashChanged:FireClient(player, moneyValue.Value)

	player.CharacterAdded:Connect(function(character)
		restorePlacements(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	sessionData[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

placeRequest.OnServerEvent:Connect(function(player, bodyPartName, worldCFrame)
	local playerData = sessionData[player]
	if not playerData then
		return
	end

	if typeof(bodyPartName) ~= "string" or typeof(worldCFrame) ~= "CFrame" then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local bodyPart = character:FindFirstChild(bodyPartName)
	if not bodyPart or not bodyPart:IsA("BasePart") then
		return
	end

	if playerData.moneyValue.Value < CASH_COST then
		cashChanged:FireClient(player, playerData.moneyValue.Value)
		return
	end

	local localOffset = bodyPart.CFrame:ToObjectSpace(worldCFrame)

	local newPart = templatePart:Clone()
	newPart.Anchored = false
	newPart.CanCollide = false
	newPart.CanQuery = false
	newPart.CanTouch = false
	newPart.Massless = true
	newPart.CFrame = worldCFrame
	newPart.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = newPart
	weld.Parent = newPart

	playerData.moneyValue.Value -= CASH_COST
	table.insert(playerData.placements, {
		bodyPartName = bodyPart.Name,
		localOffset = serializeCFrame(localOffset),
	})

	cashChanged:FireClient(player, playerData.moneyValue.Value)
end)
