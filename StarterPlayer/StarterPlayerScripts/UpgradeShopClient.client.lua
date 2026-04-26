local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UpgradeConfig"))
local remotesFolder = ReplicatedStorage:WaitForChild("UpgradeRemotes")
local requestPlaceRemote = remotesFolder:WaitForChild("RequestPlaceUpgrade")
local requestDeleteRemote = remotesFolder:WaitForChild("RequestDeleteUpgrade")
local requestTurretFireRemote = remotesFolder:WaitForChild("RequestTurretFire")
local notifyClientRemote = remotesFolder:WaitForChild("NotifyClient")

local state = {
	open = false,
	selectedItemId = "Booster",
	placing = false,
	deleteMode = false,
	hoverData = nil,
	rotY = 0,
	dragging = false,
	lastMouseX = 0,
}

local ui = {}

local function makeButton(parent, text, size, pos)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = pos
	button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Text = text
	button.Parent = parent
	return button
end

local function cloneCharacterForViewport(viewport)
	viewport:ClearAllChildren()
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(0, 2, 8)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local character = player.Character or player.CharacterAdded:Wait()
	local clone = character:Clone()
	clone.Name = "PreviewCharacter"
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	clone.Parent = worldModel
	return clone, camera
end

local function buildGui()
	local screen = Instance.new("ScreenGui")
	screen.Name = "UpgradeShopGui"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(0.75, 0.75)
	root.Position = UDim2.fromScale(0.125, 0.12)
	root.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	root.Parent = screen

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.1)
	title.BackgroundTransparency = 1
	title.Text = "R6 Body Upgrade Shop (Press B to open/close)"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Parent = root

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "MoneyLabel"
	moneyLabel.Size = UDim2.fromScale(0.3, 0.08)
	moneyLabel.Position = UDim2.fromScale(0.68, 0.02)
	moneyLabel.BackgroundColor3 = Color3.fromRGB(35, 80, 35)
	moneyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	moneyLabel.TextScaled = true
	moneyLabel.Parent = root

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "CharacterViewport"
	viewport.Size = UDim2.fromScale(0.64, 0.82)
	viewport.Position = UDim2.fromScale(0.02, 0.14)
	viewport.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	viewport.Parent = root

	local listFrame = Instance.new("Frame")
	listFrame.Size = UDim2.fromScale(0.3, 0.54)
	listFrame.Position = UDim2.fromScale(0.68, 0.14)
	listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	listFrame.Parent = root

	local y = 0.03
	for itemId, itemData in pairs(UpgradeConfig.Items) do
		local itemBtn = makeButton(
			listFrame,
			string.format("%s ($%d)", itemData.displayName, itemData.cost),
			UDim2.fromScale(0.9, 0.2),
			UDim2.fromScale(0.05, y)
		)
		y += 0.24
		itemBtn.MouseButton1Click:Connect(function()
			state.selectedItemId = itemId
		end)
	end

	local placeBtn = makeButton(root, "Buy + Place", UDim2.fromScale(0.3, 0.1), UDim2.fromScale(0.68, 0.70))
	local deleteBtn = makeButton(root, "Delete Mode", UDim2.fromScale(0.3, 0.1), UDim2.fromScale(0.68, 0.82))
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.fromScale(0.62, 0.08)
	statusLabel.Position = UDim2.fromScale(0.02, 0.02)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Select an upgrade, click Buy + Place, then click on your body in the preview."
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.TextScaled = true
	statusLabel.Parent = root

	ui = {
		screen = screen,
		root = root,
		moneyLabel = moneyLabel,
		viewport = viewport,
		placeBtn = placeBtn,
		deleteBtn = deleteBtn,
		statusLabel = statusLabel,
	}
end

buildGui()

local previewCharacter, previewCamera, previewWorldModel

local function refreshPreview()
	previewCharacter, previewCamera = cloneCharacterForViewport(ui.viewport)
	previewWorldModel = ui.viewport:FindFirstChildOfClass("WorldModel")
	state.hoverData = nil
end

local function updateMoneyLabel()
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild(UpgradeConfig.CurrencyName)
	ui.moneyLabel.Text = string.format("Money: $%d", money and money.Value or 0)
end

local function toViewportRay(mouseX, mouseY)
	local absPos = ui.viewport.AbsolutePosition
	local relX = mouseX - absPos.X
	local relY = mouseY - absPos.Y
	return previewCamera:ViewportPointToRay(relX, relY)
end

local function findBodyPartAtMouse(mouseX, mouseY)
	if not previewCharacter or not previewCamera then
		return nil
	end

	local ray = toViewportRay(mouseX, mouseY)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { previewCharacter }
	if not previewWorldModel then
		return nil
	end
	local result = previewWorldModel:Raycast(ray.Origin, ray.Direction * 100, raycastParams)

	if not result or not result.Instance then
		return nil
	end

	local hitPart = result.Instance
	if not hitPart:IsA("BasePart") then
		return nil
	end
	if hitPart:GetAttribute("UpgradeId") then
		return {
			bodyPartName = hitPart.Name,
			localOffset = CFrame.new(),
			hitPart = hitPart,
		}
	end

	local bodyPartName = hitPart.Name
	if not player.Character or not player.Character:FindFirstChild(bodyPartName) then
		return nil
	end

	local localOffset = hitPart.CFrame:ToObjectSpace(CFrame.new(result.Position))
	return {
		bodyPartName = bodyPartName,
		localOffset = localOffset,
		hitPart = hitPart,
	}
end

local function updateStatusText(text)
	ui.statusLabel.Text = text
end

ui.placeBtn.MouseButton1Click:Connect(function()
	state.placing = true
	state.deleteMode = false
	updateStatusText("Placing " .. state.selectedItemId .. ": click on body in viewport.")
end)

ui.deleteBtn.MouseButton1Click:Connect(function()
	state.deleteMode = not state.deleteMode
	state.placing = false
	if state.deleteMode then
		updateStatusText("Delete mode ON: click an upgrade in the viewport.")
	else
		updateStatusText("Delete mode OFF.")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.B then
		state.open = not state.open
		ui.screen.Enabled = state.open
		if state.open then
			refreshPreview()
			updateMoneyLabel()
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		requestTurretFireRemote:FireServer()
	end

	if not state.open then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		state.dragging = true
		state.lastMouseX = UserInputService:GetMouseLocation().X
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mousePos = UserInputService:GetMouseLocation()
		if state.placing then
			local hover = findBodyPartAtMouse(mousePos.X, mousePos.Y)
			if hover then
				requestPlaceRemote:FireServer(state.selectedItemId, hover.bodyPartName, hover.localOffset)
				state.placing = false
				updateStatusText("Purchase sent to server...")
			end
		elseif state.deleteMode and previewCharacter then
			local hover = findBodyPartAtMouse(mousePos.X, mousePos.Y)
			if hover and hover.hitPart and hover.hitPart:GetAttribute("UpgradeId") then
				requestDeleteRemote:FireServer(hover.hitPart:GetAttribute("UpgradeId"))
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		state.dragging = false
	end
end)

RunService.RenderStepped:Connect(function()
	if not state.open or not previewCharacter then
		return
	end

	if state.dragging then
		local mouseX = UserInputService:GetMouseLocation().X
		local delta = mouseX - state.lastMouseX
		state.lastMouseX = mouseX
		state.rotY += delta * 0.01
		local hrp = previewCharacter:FindFirstChild("HumanoidRootPart")
		if hrp then
			local basePos = Vector3.new(0, hrp.Position.Y, 0)
			previewCharacter:PivotTo(CFrame.new(basePos) * CFrame.Angles(0, state.rotY, 0))
		end
	end
end)

notifyClientRemote.OnClientEvent:Connect(function(eventName, p1)
	if eventName == "NotEnoughMoney" then
		updateStatusText("Not enough money.")
	elseif eventName == "UpgradePlaced" then
		updateStatusText("Upgrade placed!")
		updateMoneyLabel()
		refreshPreview()
	elseif eventName == "UpgradeDeleted" then
		updateStatusText("Upgrade deleted.")
		refreshPreview()
	end
end)

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if state.open then
		refreshPreview()
	end
end)

local leaderstats = player:WaitForChild("leaderstats", 20)
if leaderstats then
	local money = leaderstats:WaitForChild(UpgradeConfig.CurrencyName, 20)
	if money then
		money:GetPropertyChangedSignal("Value"):Connect(updateMoneyLabel)
		updateMoneyLabel()
	end
end
