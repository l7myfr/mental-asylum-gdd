local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local Replication = require(ReplicatedStorage.shared.simulation.Replication)
local Clock = require(ReplicatedStorage.shared.utils.Clock)

local speedCheck = ChronoSettings.speedCheck
local validation = ChronoSettings.validation
local flatMask = Vector3.new(1, 0, 1)

local ReplicationService = {}

ReplicationService.Strikes = {}
ReplicationService.Latency = {}

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

-- Smoothed one-way client -> server latency, sampled from client-stamped server times
-- (workspace:GetServerTimeNow() on the client) carried by attack and dodge requests.
function ReplicationService:RecordLatency(player, sentAt)
	local sample = math.clamp(Clock.Now() - sentAt, 0, validation.maxLatency)
	local current = self.Latency[player]

	self.Latency[player] = if current then current + (sample - current) * validation.latencySmoothing else sample
end

function ReplicationService:GetLatency(player)
	return self.Latency[player] or math.clamp(player:GetNetworkPing(), 0, validation.maxLatency)
end

function ReplicationService:PlayerRemoving(player)
	self.Strikes[player] = nil
	self.Latency[player] = nil
end

return ReplicationService
