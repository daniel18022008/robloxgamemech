local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UpgradeConfig"))

local remotesFolder = ReplicatedStorage:FindFirstChild("UpgradeRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "UpgradeRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

local requestPlaceRemote = getOrCreateRemote("RequestPlaceUpgrade")
local requestDeleteRemote = getOrCreateRemote("RequestDeleteUpgrade")
local requestTurretFireRemote = getOrCreateRemote("RequestTurretFire")
local notifyClientRemote = getOrCreateRemote("NotifyClient")

local playerData = {}

local function getMoneyValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end
	return leaderstats:FindFirstChild(UpgradeConfig.CurrencyName)
end

local function buildUpgradePart(itemId)
	local itemData = UpgradeConfig.Items[itemId]
	if not itemData then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = itemId
	part.Size = itemData.size
	part.Color = itemData.color
	part.Shape = itemData.shape
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("UpgradeItemId", itemId)
	return part
end

local function applySpeedBuff(player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local upgrades = playerData[player] and playerData[player].upgrades or {}
	local boosterCount = 0
	for _, entry in pairs(upgrades) do
		if entry.itemId == "Booster" then
			boosterCount += 1
		end
	end

	local multiplier = 1 + (boosterCount * UpgradeConfig.Items.Booster.effect.speedMultiplierPerItem)
	humanoid.WalkSpeed = UpgradeConfig.BaseWalkSpeed * multiplier
end

local function attachSpikeDamageLogic(ownerPlayer, part)
	local itemData = UpgradeConfig.Items.Spike
	local cooldownMap = {}

	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local targetPlayer = Players:GetPlayerFromCharacter(character)
		if not targetPlayer or targetPlayer == ownerPlayer then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local now = os.clock()
		local last = cooldownMap[targetPlayer]
		if last and (now - last) < itemData.effect.cooldown then
			return
		end
		cooldownMap[targetPlayer] = now
		humanoid:TakeDamage(itemData.effect.damageOnTouch)
	end)
end

local function createAndAttachUpgrade(player, character, entry)
	local bodyPart = character:FindFirstChild(entry.bodyPartName)
	if not bodyPart then
		return
	end

	local upgradePart = buildUpgradePart(entry.itemId)
	if not upgradePart then
		return
	end

	upgradePart.Name = string.format("Upgrade_%s_%s", entry.itemId, entry.id)
	upgradePart:SetAttribute("UpgradeId", entry.id)
	upgradePart.CFrame = bodyPart.CFrame * entry.localOffset
	upgradePart.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = upgradePart
	weld.Parent = upgradePart

	if entry.itemId == "Spike" then
		attachSpikeDamageLogic(player, upgradePart)
	end
end

local function rebuildCharacterUpgrades(player, character)
	local data = playerData[player]
	if not data then
		return
	end

	for _, entry in pairs(data.upgrades) do
		createAndAttachUpgrade(player, character, entry)
	end

	applySpeedBuff(player)
end

local function createLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local money = Instance.new("IntValue")
	money.Name = UpgradeConfig.CurrencyName
	money.Value = UpgradeConfig.StartingMoney
	money.Parent = leaderstats
end

local function addUpgradeRecord(player, itemId, bodyPartName, localOffset)
	local data = playerData[player]
	if not data then
		return nil
	end

	local entry = {
		id = HttpService:GenerateGUID(false),
		itemId = itemId,
		bodyPartName = bodyPartName,
		localOffset = localOffset,
	}
	data.upgrades[entry.id] = entry
	return entry
end

local function removeUpgradeRecord(player, upgradeId)
	local data = playerData[player]
	if not data then
		return nil
	end
	local old = data.upgrades[upgradeId]
	data.upgrades[upgradeId] = nil
	return old
end

requestPlaceRemote.OnServerEvent:Connect(function(player, itemId, bodyPartName, localOffset)
	if typeof(itemId) ~= "string" or typeof(bodyPartName) ~= "string" or typeof(localOffset) ~= "CFrame" then
		return
	end

	local itemData = UpgradeConfig.Items[itemId]
	if not itemData then
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

	local money = getMoneyValue(player)
	if not money then
		return
	end

	if money.Value < itemData.cost then
		notifyClientRemote:FireClient(player, "NotEnoughMoney", itemData.cost)
		return
	end

	money.Value -= itemData.cost
	local entry = addUpgradeRecord(player, itemId, bodyPartName, localOffset)
	if not entry then
		return
	end

	createAndAttachUpgrade(player, character, entry)
	applySpeedBuff(player)
	notifyClientRemote:FireClient(player, "UpgradePlaced", entry.id, itemId)
end)

requestDeleteRemote.OnServerEvent:Connect(function(player, upgradeId)
	if typeof(upgradeId) ~= "string" then
		return
	end

	local removed = removeUpgradeRecord(player, upgradeId)
	if not removed then
		return
	end

	local character = player.Character
	if character then
		local part = character:FindFirstChild(string.format("Upgrade_%s_%s", removed.itemId, removed.id))
		if part then
			part:Destroy()
		end
	end

	applySpeedBuff(player)
	notifyClientRemote:FireClient(player, "UpgradeDeleted", removed.id)
end)

requestTurretFireRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then
		return
	end

	local data = playerData[player]
	if not data then
		return
	end

	local now = os.clock()
	if data.lastTurretShot and now - data.lastTurretShot < UpgradeConfig.Items.Turret.effect.fireCooldown then
		return
	end
	data.lastTurretShot = now

	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part:GetAttribute("UpgradeItemId") == "Turret" then
			local bullet = Instance.new("Part")
			bullet.Name = "TurretPellet"
			bullet.Shape = Enum.PartType.Ball
			bullet.Size = Vector3.new(0.3, 0.3, 0.3)
			bullet.Material = Enum.Material.Neon
			bullet.Color = Color3.fromRGB(255, 255, 0)
			bullet.CanCollide = false
			bullet.CFrame = part.CFrame * CFrame.new(0, 0, -(part.Size.Z / 2 + 0.4))
			bullet.Parent = workspace

			local velocity = Instance.new("LinearVelocity")
			velocity.MaxForce = math.huge
			velocity.VectorVelocity = part.CFrame.LookVector * UpgradeConfig.Items.Turret.effect.bulletSpeed
			local attachment = Instance.new("Attachment")
			attachment.Parent = bullet
			velocity.Attachment0 = attachment
			velocity.Parent = bullet

			bullet.Touched:Connect(function(hit)
				local hitCharacter = hit:FindFirstAncestorOfClass("Model")
				if not hitCharacter or hitCharacter == character then
					return
				end
				local humanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(UpgradeConfig.Items.Turret.effect.bulletDamage)
					bullet:Destroy()
				end
			end)

			Debris:AddItem(bullet, UpgradeConfig.Items.Turret.effect.bulletLifetime)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	playerData[player] = {
		upgrades = {},
		lastTurretShot = 0,
	}

	createLeaderstats(player)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.15)
		rebuildCharacterUpgrades(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)
