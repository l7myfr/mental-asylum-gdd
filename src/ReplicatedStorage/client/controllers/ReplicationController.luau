local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replication = require(ReplicatedStorage.shared.simulation.Replication)

local ReplicationController = {}

function ReplicationController:init()
	local Chrono = Replication.Start()

	-- Chrono anchors locked entities it doesn't own so Roblox's replication can't move them, but only
	-- when the lock flag is known before the model is set. For entities that arrive with their model
	-- (player characters) the flag is assigned afterwards, so apply the anchoring once registered.
	Chrono.Events.EntityAdded:Connect(function(entity)
		local root = entity._lockedCFReplication and not entity.isContextOwner and Chrono.Entity.GetPrimaryPart(entity)

		if root then
			root.Anchored = true
		end
	end)
end

return ReplicationController
