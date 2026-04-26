local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local vpf = script.Parent:WaitForChild("CharacterVPF")
local player = Players.LocalPlayer

vpf.Active = true
vpf.Ambient = Color3.fromRGB(200, 200, 200)
vpf.LightColor = Color3.fromRGB(255, 255, 255)
vpf.LightDirection = Vector3.new(-1, -1, -1)

local cam = Instance.new("Camera")
cam.Parent = vpf
vpf.CurrentCamera = cam

local worldModel = Instance.new("WorldModel")
worldModel.Parent = vpf

local clonedChar
local yaw = math.rad(180)
local pitch = math.rad(10)
local distance = 7.5
local dragging = false

local minPitch = math.rad(-45)
local maxPitch = math.rad(50)
local minDistance = 4
local maxDistance = 12

local function setupClone()
	local char = player.Character or player.CharacterAdded:Wait()
	local oldArchivable = char.Archivable
	char.Archivable = true

	if clonedChar then
		clonedChar:Destroy()
	end

	clonedChar = char:Clone()
	char.Archivable = oldArchivable

	for _, obj in ipairs(clonedChar:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
		end
	end

	clonedChar.Parent = worldModel
	clonedChar:PivotTo(CFrame.new(0, 0, 0))
end

local function getFocus()
	if not clonedChar then
		return Vector3.new(0, 2, 0)
	end

	local hrp = clonedChar:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position + Vector3.new(0, 1.5, 0)
	end

	return Vector3.new(0, 2, 0)
end

vpf.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
	end
end)

vpf.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
		yaw -= input.Delta.X * 0.006
		pitch = math.clamp(pitch - input.Delta.Y * 0.006, minPitch, maxPitch)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		distance = math.clamp(distance - input.Position.Z, minDistance, maxDistance)
	end
end)

RunService.RenderStepped:Connect(function()
	local focus = getFocus()
	local offset = Vector3.new(
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		math.cos(pitch) * math.cos(yaw)
	) * distance

	cam.CFrame = CFrame.lookAt(focus + offset, focus)
end)

setupClone()
player.CharacterAdded:Connect(setupClone)
