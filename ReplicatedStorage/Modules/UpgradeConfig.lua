local UpgradeConfig = {}

UpgradeConfig.CurrencyName = "Money"
UpgradeConfig.StartingMoney = 500
UpgradeConfig.BaseWalkSpeed = 16

UpgradeConfig.Items = {
	Booster = {
		id = "Booster",
		displayName = "Booster",
		cost = 100,
		color = Color3.fromRGB(0, 170, 255),
		size = Vector3.new(0.8, 0.8, 0.8),
		shape = Enum.PartType.Ball,
		effect = {
			speedMultiplierPerItem = 0.5,
		},
	},
	Spike = {
		id = "Spike",
		displayName = "Spike",
		cost = 150,
		color = Color3.fromRGB(255, 0, 0),
		size = Vector3.new(0.5, 1.2, 0.5),
		shape = Enum.PartType.Cylinder,
		effect = {
			damageOnTouch = 15,
			cooldown = 0.5,
		},
	},
	Turret = {
		id = "Turret",
		displayName = "Turret",
		cost = 250,
		color = Color3.fromRGB(70, 70, 70),
		size = Vector3.new(1, 0.6, 1.2),
		shape = Enum.PartType.Block,
		effect = {
			bulletSpeed = 120,
			bulletDamage = 20,
			bulletLifetime = 3,
			fireCooldown = 0.25,
		},
	},
}

return UpgradeConfig
