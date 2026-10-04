local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local Replication = require(ReplicatedStorage.shared.simulation.Replication)
local AgentRegistry = require(ReplicatedStorage.shared.simulation.AgentRegistry)
local Clock = require(ReplicatedStorage.shared.utils.Clock)

local settings = ChronoSettings.lagCompensation

local HitResolver = {}
HitResolver.__index = HitResolver

local function outsideDistance(cframe, size, point)
	local localPoint = cframe:PointToObjectSpace(point)
	local half = size * 0.5

	return math.max(
		math.abs(localPoint.X) - half.X,
		math.abs(localPoint.Y) - half.Y,
		math.abs(localPoint.Z) - half.Z
	)
end

local function sampleCFrame(character, processTime)
	local entity = Replication.GetEntity(character)
	local cframe = entity and Replication.GetAt(entity, processTime)

	if cframe then
		return cframe
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	return root and root.CFrame
end

local function getCandidates(attacker)
	local candidates = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character

		if character and character ~= attacker then
			table.insert(candidates, character)
		end
	end

	for character in AgentRegistry.GetAgents() do
		if character ~= attacker then
			table.insert(candidates, character)
		end
	end

	return candidates
end

function HitResolver.new()
	return setmetatable({
		Pending = {},
	}, HitResolver)
end

function HitResolver.SanitizeDelays(delays)
	local sanitized = {}

	if type(delays) ~= "table" then
		return sanitized
	end

	for key, value in delays do
		if type(key) == "string" and type(value) == "number" and value == value then
			sanitized[key] = math.clamp(value, 0, settings.maxRewind)
		end
	end

	return sanitized
end

function HitResolver:Queue(request)
	table.insert(self.Pending, request)
end

-- How far in the past the attacker saw this target: the target's state travelled server -> attacker
-- (one-way latency) and was then drawn behind Chrono's interpolation buffer (reported by the client).
function HitResolver:GetDelay(request, entity)
	local delay = entity and request.delays[tostring(entity.id)]

	return request.latency + (delay or settings.defaultViewDelay)
end

function HitResolver:Evaluate(request, target, boxCFrame, size, attackerCFrame, serverTime, processTime)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart

	if not root or humanoid.Health <= 0 then
		return nil
	end

	local delay = self:GetDelay(request, Replication.GetEntity(target))
	local targetCFrame = sampleCFrame(target, processTime - delay)

	if not targetCFrame or outsideDistance(boxCFrame, size + root.Size, targetCFrame.Position) > 0 then
		return nil
	end

	local weapon = request.weapon
	local info = {
		character = target,
		humanoid = humanoid,
		root = root,
		position = targetCFrame.Position,
		cframe = targetCFrame,
		attackerCFrame = attackerCFrame,
	}

	if not weapon:CanHit(request.attacker, info) then
		return nil
	end

	if weapon:IsEvading(info, boxCFrame, size, serverTime - delay) then
		return if weapon.Config.dodgeEvasion.consumesSwing then { evaded = true } else nil
	end

	return {
		hit = {
			attacker = request.attacker,
			target = target,
			humanoid = humanoid,
			weapon = weapon.Name,
			attack = request.attackName,
			damage = weapon:ComputeDamage(request.attacker, info, request.attack),
			position = targetCFrame.Position,
		},
	}
end

-- Returns every hit the swing landed.
function HitResolver:Resolve(request)
	local attack = request.attack
	local hitbox = attack.hitbox or request.weapon.Config.hitbox
	-- The attacker's own position for a given moment reaches the server one-way latency later.
	local latency = request.latency
	local span = attack.hitEnd - attack.hitStart
	local samples = math.max(1, math.ceil(span / settings.sampleInterval))
	local resolved = {}
	local hits = {}

	for index = 0, samples do
		local serverTime = request.start + attack.hitStart + span * index / samples
		local processTime = Clock.ToProcess(serverTime)
		local attackerCFrame = sampleCFrame(request.attacker, processTime + latency)

		if attackerCFrame then
			local boxCFrame = attackerCFrame * hitbox.offset

			for _, target in getCandidates(request.attacker) do
				if not resolved[target] and #hits < hitbox.maxTargets then
					local result = self:Evaluate(request, target, boxCFrame, hitbox.size, attackerCFrame, serverTime, processTime)

					if result then
						resolved[target] = true

						if result.hit then
							table.insert(hits, result.hit)
						end
					end
				end
			end
		end
	end

	return hits
end

-- Calls resolved(request, hits) once per swing whose hit window has fully arrived.
function HitResolver:Update(resolved)
	local now = Clock.Now()

	for index = #self.Pending, 1, -1 do
		local request = self.Pending[index]
		local latency = request.latency

		if not request.attacker.Parent then
			table.remove(self.Pending, index)
		elseif now >= request.start + request.attack.hitEnd + latency + settings.resolveBuffer then
			table.remove(self.Pending, index)
			resolved(request, self:Resolve(request))
		end
	end
end

return HitResolver
