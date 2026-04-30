-- Place this LocalScript under your TextLabel

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local label = script.Parent
local remotes = ReplicatedStorage:WaitForChild("UpgradeRemotes")
local cashChanged = remotes:WaitForChild("CashChanged")

local function updateText(value)
	label.Text = string.format("Cash: %d", value)
end

local function hookLeaderstats()
	local stats = player:WaitForChild("leaderstats")
	local money = stats:WaitForChild("Money")
	updateText(money.Value)
	money:GetPropertyChangedSignal("Value"):Connect(function()
		updateText(money.Value)
	end)
end

cashChanged.OnClientEvent:Connect(updateText)
task.spawn(hookLeaderstats)
