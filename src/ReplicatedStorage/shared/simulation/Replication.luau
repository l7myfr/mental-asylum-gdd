local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chrono = require(ReplicatedStorage.shared.chrono)
local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)

local Replication = {}

local started = false

function Replication.Start()
	if started then
		return Chrono
	end

	started = true

	for key, value in ChronoSettings.config do
		Chrono.Config.SetConfig(key, value)
	end

	for typeName, entityType in ChronoSettings.entityTypes do
		Chrono.Config.RegisterEntityType(typeName, entityType)
	end

	Chrono.Start()

	return Chrono
end

function Replication.GetEntity(character)
	return Chrono.Holder.GetEntityFromModel(character)
end

function Replication.GetAt(entity, processTime)
	return Chrono.Entity.GetAt(entity, processTime)
end

function Replication.GetViewDelay(entity)
	local clock = entity._clientClock

	if not clock then
		local clocks = entity.entityConfig and entity.entityConfig.CLIENT_CLOCK
		clock = clocks and (if entity.isHalfTicked then clocks.HALF else clocks.NORMAL)
	end

	if not clock or not clock.renderAt or not clock.lastClockAt then
		return nil
	end

	return clock:GetEstimatedServerTime() - clock:GetTargetRenderTime()
end

function Replication.RegisterNpc(character)
	return Chrono.Entity.new(ChronoSettings.npcEntityType, character)
end

function Replication.Unregister(entity)
	Chrono.Entity.Destroy(entity)
end

function Replication.GetEntities()
	return Chrono.Holder.idMap
end

return Replication
