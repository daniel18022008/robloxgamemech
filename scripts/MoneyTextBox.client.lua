-- Place this LocalScript inside a TextBox (or TextLabel) in StarterGui

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local textObject = script.Parent

local function updateText(value)
	textObject.Text = "Cash: $" .. tostring(value)
end

local function bindMoneyStat()
	local leaderstats = player:WaitForChild("leaderstats")
	local money = leaderstats:WaitForChild("Money")

	updateText(money.Value)
	money:GetPropertyChangedSignal("Value"):Connect(function()
		updateText(money.Value)
	end)
end

bindMoneyStat()
