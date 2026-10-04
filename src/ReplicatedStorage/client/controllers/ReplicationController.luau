local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replication = require(ReplicatedStorage.shared.simulation.Replication)

local ReplicationController = {}

function ReplicationController:init()
	Replication.Start()
end

return ReplicationController
