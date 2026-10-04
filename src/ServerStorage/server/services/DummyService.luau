local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DummyConfig = require(ServerStorage.server.config.DummyConfig)
local Replication = require(ReplicatedStorage.shared.simulation.Replication)
local AgentRegistry = require(ReplicatedStorage.shared.simulation.AgentRegistry)

local behaviours = ServerStorage.server.modules.dummies
local flatMask = Vector3.new(1, 0, 1)

local DummyService = {}

DummyService.Dependencies = {
	Melee = "MeleeService",
}

function DummyService:Start()
	self.Folder = Instance.new("Folder")
	self.Folder.Name = DummyConfig.folderName
	self.Folder.Parent = workspace

	for dummyName, settings in DummyConfig.dummies do
		self:Spawn(dummyName, settings)
	end
end

function DummyService:Spawn(dummyName, settings)
	local character = settings.template:Clone()
	character.Name = dummyName
	character:PivotTo(settings.spawn)
	CollectionService:AddTag(character, DummyConfig.tag)
	character.Parent = self.Folder

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local behaviour = require(behaviours:FindFirstChild(settings.behaviour))

	local entity = Replication.RegisterNpc(character)

	if settings.melee then
		self.Melee:Equip(character, settings.melee)
	end

	local agent = {
		Root = humanoid.RootPart,
		Home = settings.spawn.Position,
		HomeLook = (settings.spawn.LookVector * flatMask).Unit,
		Character = character,
		Humanoid = humanoid,
		Settings = DummyConfig.behaviours[settings.behaviour],
		Memory = {},
	}

	AgentRegistry.Register(character, function(_, now, deltaTime)
		return behaviour(agent, now, deltaTime)
	end)

	humanoid.Died:Once(function()
		AgentRegistry.Unregister(character)
		Replication.Unregister(entity)

		task.delay(settings.respawnDelay, function()
			character:Destroy()
			self:Spawn(dummyName, settings)
		end)
	end)
end

return DummyService
