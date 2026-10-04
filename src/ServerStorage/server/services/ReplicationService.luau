local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local Replication = require(ReplicatedStorage.shared.simulation.Replication)

local speedCheck = ChronoSettings.speedCheck
local flatMask = Vector3.new(1, 0, 1)

local ReplicationService = {}

ReplicationService.Strikes = {}

function ReplicationService:init()
	local Chrono = Replication.Start()

	if speedCheck.enabled then
		Chrono.ServerReceiver.RegisterMiddleMan("SpeedCheck", speedCheck.priority, function(player, entity, cframe, arriveTime)
			return self:CheckSpeed(player, entity, cframe, arriveTime, Chrono)
		end)
	end
end

function ReplicationService:CheckSpeed(player, entity, cframe, arriveTime, Chrono)
	local last = entity.latestCFrame
	local lastTime = entity.latestTime

	if not last or not lastTime then
		return false
	end

	local elapsed = math.max(arriveTime - lastTime, entity.entityConfig.TICK_RATE)
	local speed = ((cframe.Position - last.Position) * flatMask).Magnitude / elapsed
	local strikes = self.Strikes[player] or 0

	if speed <= speedCheck.maxHorizontalSpeed then
		self.Strikes[player] = math.max(strikes - speedCheck.strikeDecay, 0)

		return false
	end

	strikes += 1
	self.Strikes[player] = strikes

	if strikes >= speedCheck.maxStrikes then
		self.Strikes[player] = 0
		Chrono.Entity.SetCFrame(entity, last)
	end

	return true
end

function ReplicationService:CharacterAdded(player, character)
	local comparison = ChronoSettings.comparison

	if comparison.enabled and not comparison.nativePlayers[player.Name] and character:WaitForChild("HumanoidRootPart") then
		Replication.RegisterPlayer(player, character)
	end
end

function ReplicationService:PlayerRemoving(player)
	self.Strikes[player] = nil

	if ChronoSettings.comparison.enabled then
		Replication.UnregisterPlayer(player)
	end
end

return ReplicationService
