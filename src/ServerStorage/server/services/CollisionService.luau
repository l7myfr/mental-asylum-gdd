local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionConfig = require(ReplicatedStorage.shared.config.CollisionConfig)

local rig = CollisionConfig.rig

local CollisionService = {}

function CollisionService:init()
	for groupName in CollisionConfig.groups do
		if not PhysicsService:IsCollisionGroupRegistered(groupName) then
			PhysicsService:RegisterCollisionGroup(groupName)
		end
	end

	for groupName, rules in CollisionConfig.groups do
		for otherGroup, collidable in rules do
			PhysicsService:CollisionGroupSetCollidable(groupName, otherGroup, collidable)
		end
	end
end

function CollisionService:Start()
	self:LinkObject(function(model)
		self:ApplyToRig(model)
	end, CollisionConfig.entityTag)
end

function CollisionService:CharacterAdded(player, character)
	self:ApplyToRig(character)
end

function CollisionService:ApplyToPart(part)
	if part.Name == rig.root then
		part.CollisionGroup = rig.rootGroup
		part.CanCollide = rig.rootCollides
	else
		part.CollisionGroup = rig.limbGroup
	end
end

function CollisionService:ApplyToRig(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			self:ApplyToPart(descendant)
		end
	end

	model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			self:ApplyToPart(descendant)
		end
	end)
end

return CollisionService
