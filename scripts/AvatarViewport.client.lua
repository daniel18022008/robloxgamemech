-- Place this LocalScript inside the ViewportFrame in StarterGui
-- It will render the local player's avatar and let you orbit with click + drag.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local viewportFrame = script.Parent

local camera = Instance.new("Camera")
camera.FieldOfView = 55
camera.Parent = viewportFrame
viewportFrame.CurrentCamera = camera

local avatarModel
local orbitYaw = 0
local orbitPitch = math.rad(12)
local orbitDistance = 7

local isDragging = false
local dragSensitivity = 0.007
local zoomSensitivity = 1

local minPitch = math.rad(-50)
local maxPitch = math.rad(50)
local minDistance = 4
local maxDistance = 12

local function clearViewport()
	for _, child in ipairs(viewportFrame:GetChildren()) do
		if child:IsA("Model") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
end

local function buildAvatar()
	local character = player.Character or player.CharacterAdded:Wait()
	local clone = character:Clone()

	for _, obj in ipairs(clone:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
		end
	end

	clearViewport()

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame

	clone.Parent = worldModel
	avatarModel = clone
end

local function getFocusPosition()
	if not avatarModel then
		return Vector3.new(0, 2, 0)
	end

	local head = avatarModel:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end

	local primary = avatarModel.PrimaryPart or avatarModel:FindFirstChild("HumanoidRootPart")
	if primary and primary:IsA("BasePart") then
		return primary.Position + Vector3.new(0, 1.5, 0)
	end

	return Vector3.new(0, 2, 0)
end

local function updateCamera()
	local focus = getFocusPosition()

	local offset = Vector3.new(
		math.cos(orbitPitch) * math.sin(orbitYaw),
		math.sin(orbitPitch),
		math.cos(orbitPitch) * math.cos(orbitYaw)
	) * orbitDistance

	camera.CFrame = CFrame.lookAt(focus + offset, focus)
end

viewportFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = true
	end
end)

viewportFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
		orbitYaw = orbitYaw - input.Delta.X * dragSensitivity
		orbitPitch = math.clamp(orbitPitch - input.Delta.Y * dragSensitivity, minPitch, maxPitch)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		orbitDistance = math.clamp(orbitDistance - input.Position.Z * zoomSensitivity, minDistance, maxDistance)
	end
end)

RunService.RenderStepped:Connect(updateCamera)

player.CharacterAdded:Connect(function()
	buildAvatar()
	updateCamera()
end)

buildAvatar()
updateCamera()
