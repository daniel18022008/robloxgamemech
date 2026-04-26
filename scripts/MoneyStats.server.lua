-- Place this Script in ServerScriptService

local Players = game:GetService("Players")

local DEFAULT_CASH = 1000

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = DEFAULT_CASH
	money.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Covers Studio test edge-case where player may already exist
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
