local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)

local flatMask = Vector3.new(1, 0, 1)

local function getLook(agent)
	local settings = agent.Settings

	if not settings.faceNearestPlayer then
		return agent.HomeLook
	end

	local closest, closestDistance = nil, settings.sightRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root then
			local distance = (root.Position - agent.Root.Position).Magnitude

			if distance < closestDistance then
				closest = root
				closestDistance = distance
			end
		end
	end

	local direction = closest and (closest.Position - agent.Root.Position) * flatMask

	if not direction or direction.Magnitude < 1e-3 then
		return agent.HomeLook
	end

	return direction.Unit
end

return function(agent, now)
	local settings = agent.Settings
	local memory = agent.Memory
	local look = getLook(agent)

	local input = {
		Move = Vector3.zero,
		Look = look,
		FaceCamera = true,
		Sprint = false,
		Dodge = false,
		Attack = false,
	}

	if now >= (memory.nextDodge or 0) then
		memory.index = (memory.index or 0) % #settings.sequence + 1
		memory.nextDodge = now + settings.interval

		input.Move = MovementSimulation.GetDodgeInput(settings.sequence[memory.index], look)
		input.Dodge = true

		return input
	end

	local toHome = (agent.Home - agent.Root.Position) * flatMask

	if toHome.Magnitude > settings.homeRadius then
		input.Move = toHome.Unit * settings.homeStrength
	end

	return input
end
