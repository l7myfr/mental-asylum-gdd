local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)

local movementAttributes = MovementConfig.attributes
local flatMask = Vector3.new(1, 0, 1)

local function flatUnit(vector, fallback)
	local flat = vector * flatMask

	if flat.Magnitude < 1e-3 then
		return fallback
	end

	return flat.Unit
end

local function findThreat(agent, settings)
	local closest, closestDistance = nil, settings.sightRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart

		if root and humanoid.Health > 0 then
			local distance = ((root.Position - agent.Root.Position) * flatMask).Magnitude

			if distance < closestDistance then
				closest = root
				closestDistance = distance
			end
		end
	end

	return closest, closestDistance
end

-- Runs directly away, bending back toward home near the leash edge and turning aside from walls.
local function getEscape(agent, settings, threatRoot)
	local position = agent.Root.Position
	local away = flatUnit(position - threatRoot.Position, agent.HomeLook)
	local toHome = (agent.Home - position) * flatMask
	local leashPull = math.clamp((toHome.Magnitude - settings.leashRadius * 0.7) / (settings.leashRadius * 0.3), 0, 1)
	local direction = flatUnit(away + flatUnit(toHome, Vector3.zero) * leashPull * 2, away)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { agent.Character, threatRoot.Parent }

	if workspace:Raycast(position, direction * settings.wallCheck, params) then
		local right = Vector3.new(-direction.Z, 0, direction.X)

		direction = if workspace:Raycast(position, right * settings.wallCheck, params) then -right else right
	end

	return direction
end

return function(agent, now)
	local settings = agent.Settings
	local memory = agent.Memory
	local character = agent.Character

	local input = {
		Move = Vector3.zero,
		Look = agent.HomeLook,
		FaceCamera = false,
		Sprint = false,
		Dodge = false,
		Attack = false,
	}

	local pressedLast = memory.pressedDodge
	memory.pressedDodge = false

	local threatRoot, distance = findThreat(agent, settings)

	-- Hysteresis: starts fleeing inside fleeRadius and only calms down beyond safeRadius.
	if threatRoot and distance < settings.fleeRadius then
		memory.fleeing = true
	elseif not threatRoot or distance > settings.safeRadius then
		memory.fleeing = false
	end

	if memory.fleeing and threatRoot then
		local toward = flatUnit(threatRoot.Position - agent.Root.Position, agent.HomeLook)
		local dodgeReady = now >= (character:GetAttribute(movementAttributes.dodgeReady) or 0)

		-- Too close: dodge straight back (facing the threat, so the dodge resolves to "back").
		if distance < settings.dodgeRadius and dodgeReady and not pressedLast then
			input.Look = toward
			input.FaceCamera = true
			input.Move = -toward
			input.Dodge = true
			memory.pressedDodge = true

			return input
		end

		input.Move = getEscape(agent, settings, threatRoot)
		input.Look = input.Move
		input.Sprint = true

		return input
	end

	local toHome = (agent.Home - agent.Root.Position) * flatMask

	if toHome.Magnitude > settings.homeRadius then
		input.Move = toHome.Unit
		input.Look = toHome.Unit
	end

	-- Keeps a nervous eye on a nearby player while it's calm.
	if threatRoot then
		input.Look = flatUnit(threatRoot.Position - agent.Root.Position, input.Look)
		input.FaceCamera = toHome.Magnitude <= settings.homeRadius
	end

	return input
end
