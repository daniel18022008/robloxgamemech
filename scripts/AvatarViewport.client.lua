-- Place this LocalScript directly inside the ViewportFrame in StarterGui.
-- Supports mouse drag (orbit) and mouse wheel (zoom).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local viewportFrame = script.Parent

-- Required so GUI input events fire on this frame
viewportFrame.Active = true

-- Make sure the model is visible in viewport lighting
viewportFrame.Ambient = Color3.fromRGB(200, 200, 200)
viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
viewportFrame.LightDirection = Vector3.new(-1, -1, -1)

local camera = Instance.new("Camera")
camera.Name = "ViewportCamera"
camera.FieldOfView = 50
camera.Parent = viewportFrame
viewportFrame.CurrentCamera = camera

local worldModel = viewportFrame:FindFirstChildOfClass("WorldModel") or Instance.new("WorldModel")
worldModel.Parent = viewportFrame

local avatarModel
local renderConnection

local yaw = math.rad(180)
local pitch = math.rad(12)
local distance = 6.5

local dragging = false
local dragSensitivity = 0.006
local zoomStep = 0.8

local minPitch = math.rad(-40)
local maxPitch = math.rad(45)
local minDistance = 3.5
local maxDistance = 10

local function clearWorldModel()
	for _, child in ipairs(worldModel:GetChildren()) do
		child:Destroy()
	end
end

local function freezeModel(model)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
		elseif obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		end
	end
end

local function createAvatarFromUserId()
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(player.UserId)
	end)

	if ok and model then
		return model
	end

	return nil
end

local function cloneCurrentCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	local previousArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = previousArchivable
	return clone
end

local function createAvatarModel()
	clearWorldModel()

	local model = createAvatarFromUserId() or cloneCurrentCharacter()
	freezeModel(model)
	model.Parent = worldModel

	-- Move model near origin so viewport camera math is consistent
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model:PivotTo(CFrame.new(0, 0, 0))
	else
		local _, boundsSize = model:GetBoundingBox()
		model:PivotTo(CFrame.new(0, boundsSize.Y * 0.5, 0))
	end

	avatarModel = model
end

local function getFocusPoint()
	if not avatarModel then
		return Vector3.new(0, 1.5, 0)
	end

	local head = avatarModel:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end

	local hrp = avatarModel:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position + Vector3.new(0, 1.2, 0)
	end

	return Vector3.new(0, 1.5, 0)
end

local function updateCamera()
	local focus = getFocusPoint()
	local offset = Vector3.new(
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		math.cos(pitch) * math.cos(yaw)
	) * distance

	camera.CFrame = CFrame.lookAt(focus + offset, focus)
end

local function bindInput()
	viewportFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)

	viewportFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
			yaw -= input.Delta.X * dragSensitivity
			pitch = math.clamp(pitch - input.Delta.Y * dragSensitivity, minPitch, maxPitch)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			distance = math.clamp(distance - input.Position.Z * zoomStep, minDistance, maxDistance)
		end
	end)
end

local function startRender()
	if renderConnection then
		renderConnection:Disconnect()
	end
	renderConnection = RunService.RenderStepped:Connect(updateCamera)
end

local function rebuildAvatar()
	createAvatarModel()
	updateCamera()
end

bindInput()
startRender()
rebuildAvatar()
player.CharacterAdded:Connect(rebuildAvatar)
