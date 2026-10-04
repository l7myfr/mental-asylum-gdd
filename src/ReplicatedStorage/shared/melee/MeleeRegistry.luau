local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MeleeClass = require(script.Parent.MeleeClass)

local weaponsFolder = script.Parent.weapons

local MeleeRegistry = {}

local weapons = {}

for weaponName, config in MeleeConfig.weapons do
	local classModule = config.class and weaponsFolder:FindFirstChild(config.class)
	local class = if classModule then require(classModule) else MeleeClass

	weapons[weaponName] = class.new(weaponName, config)
end

function MeleeRegistry.Get(weaponName)
	return weaponName and weapons[weaponName]
end

function MeleeRegistry.GetAll()
	return weapons
end

return MeleeRegistry
