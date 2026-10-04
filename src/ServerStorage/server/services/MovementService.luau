local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)
local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)
local AgentRegistry = require(ReplicatedStorage.shared.simulation.AgentRegistry)
local Stepper = require(ReplicatedStorage.shared.simulation.Stepper)
local Clock = require(ReplicatedStorage.shared.utils.Clock)

local attributes = MovementConfig.attributes
local validation = ChronoSettings.validation

local MovementService = {}

MovementService.Dependencies = {
	Replication = "ReplicationService",
}

MovementService.Remotes = {
	Dodge = "Event",
}

MovementService.DodgeHistory = {}

function MovementService:Start()
	Stepper.Bind("Movement", MovementConfig.simulation.priority, function(deltaTime, now)
		for character in AgentRegistry.GetAgents() do
			MovementSimulation.StepCharacter(character, AgentRegistry.ReadInput(character, now, deltaTime), deltaTime, now)
		end
	end)

	self.Remotes.Dodge:Connect(function(player, dodgeName, start)
		self:OnDodge(player, dodgeName, start)
	end)
end

function MovementService:OnDodge(player, dodgeName, start)
	if type(dodgeName) ~= "string" or type(start) ~= "number" or not MovementConfig.dodge.directions[dodgeName] then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = Clock.Now()
	self.Replication:RecordLatency(player, start)
	start = math.clamp(start, now - validation.maxLatency, now)

	local previous = self.DodgeHistory[player]

	if previous then
		local cooldown = MovementSimulation.GetDodgeSetting(previous.name, "cooldown")

		if start - previous.start < cooldown - validation.cooldownTolerance then
			return
		end
	end

	self.DodgeHistory[player] = {
		name = dodgeName,
		start = start,
	}

	character:SetAttribute(attributes.dodge, dodgeName)
	character:SetAttribute(attributes.dodgeStart, start)
	character:SetAttribute(attributes.dodgeReady, start + MovementSimulation.GetDodgeSetting(dodgeName, "cooldown"))
end

function MovementService:CharacterAdded(player, character)
	self.DodgeHistory[player] = nil

	for _, childName in MovementConfig.removedCharacterChildren do
		local child = character:FindFirstChild(childName) or character:WaitForChild(childName, MovementConfig.removedChildTimeout)

		if child then
			child:Destroy()
		end
	end
end

function MovementService:PlayerRemoving(player)
	self.DodgeHistory[player] = nil
end

return MovementService
