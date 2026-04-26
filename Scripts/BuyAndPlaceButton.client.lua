-- Place this LocalScript under your TextButton

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local button = script.Parent

local function getTemplatePart()
	local upgrades = ReplicatedStorage:WaitForChild("Upgrades", 10)
	local basic = upgrades and upgrades:WaitForChild("Basic", 10)
	local part = basic and basic:WaitForChild("Part", 10)
	if not part or not part:IsA("BasePart") then
		error("Missing BasePart at ReplicatedStorage/Upgrades/Basic/Part")
	end
	return part
end

local templatePart = getTemplatePart()
local remotes = ReplicatedStorage:WaitForChild("UpgradeRemotes")
local placeRequest = remotes:WaitForChild("PlacePartRequest")

local placementActive = false
local previewPart = nil
local renderConnection = nil

local function createPreviewPart()
	if previewPart then
		previewPart:Destroy()
	end
	previewPart = templatePart:Clone()
	previewPart.Name = "PlacementPreview"
	previewPart.Anchored = true
	previewPart.CanCollide = false
	previewPart.CanQuery = false
	previewPart.CanTouch = false
	previewPart.Transparency = math.clamp(templatePart.Transparency + 0.5, 0.45, 0.85)
	previewPart.Parent = workspace
end

local function stopPlacementMode()
	placementActive = false
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if previewPart then
		previewPart:Destroy()
		previewPart = nil
	end
end

local function getHitOnOwnCharacter()
	local character = player.Character
	if not character then
		return nil
	end

	local target = mouse.Target
	if not target or not target:IsDescendantOf(character) or not target:IsA("BasePart") then
		return nil
	end

	local hitPosition = mouse.Hit.Position
	local localHit = target.CFrame:PointToObjectSpace(hitPosition)

	local half = target.Size * 0.5
	local absX, absY, absZ = math.abs(localHit.X), math.abs(localHit.Y), math.abs(localHit.Z)

	local normalLocal
	local px = half.X - absX
	local py = half.Y - absY
	local pz = half.Z - absZ

	if px <= py and px <= pz then
		normalLocal = Vector3.new(math.sign(localHit.X), 0, 0)
	elseif py <= px and py <= pz then
		normalLocal = Vector3.new(0, math.sign(localHit.Y), 0)
	else
		normalLocal = Vector3.new(0, 0, math.sign(localHit.Z))
	end

	if normalLocal.Magnitude == 0 then
		normalLocal = Vector3.new(0, 1, 0)
	end

	local normalWorld = target.CFrame:VectorToWorldSpace(normalLocal).Unit
	return target, hitPosition, normalWorld
end

local function updatePreview()
	local targetPart, hitPos, normal = getHitOnOwnCharacter()
	if not targetPart then
		previewPart.Transparency = 1
		previewPart:SetAttribute("BodyPartName", nil)
		return
	end

	local offset = normal * (previewPart.Size.Z * 0.5)
	local goalCFrame = CFrame.lookAt(hitPos + offset, hitPos + normal) * CFrame.Angles(0, math.rad(180), 0)

	previewPart.Transparency = math.clamp(templatePart.Transparency + 0.5, 0.45, 0.85)
	previewPart.CFrame = previewPart.CFrame:Lerp(goalCFrame, 0.35)
	previewPart:SetAttribute("BodyPartName", targetPart.Name)
end

local function startPlacementMode()
	if placementActive then
		return
	end

	placementActive = true
	createPreviewPart()
	renderConnection = RunService.RenderStepped:Connect(updatePreview)
end

button.MouseButton1Click:Connect(function()
	startPlacementMode()
end)

mouse.Button1Down:Connect(function()
	if not placementActive or not previewPart then
		return
	end

	local bodyPartName = previewPart:GetAttribute("BodyPartName")
	if typeof(bodyPartName) ~= "string" then
		return
	end

	placeRequest:FireServer(bodyPartName, previewPart.CFrame)
	stopPlacementMode()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not placementActive then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		stopPlacementMode()
	end
end)
