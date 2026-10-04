local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)
local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MeleeRegistry = require(ReplicatedStorage.shared.melee.MeleeRegistry)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)
local Replication = require(ReplicatedStorage.shared.simulation.Replication)

local meleeAttributes = MeleeConfig.attributes
local movementAttributes = MovementConfig.attributes
local dodgeDirections = MovementConfig.dodge.directions
local flatMask = Vector3.new(1, 0, 1)
local random = Random.new()

local dodgeDistances = {}

for dodgeName in dodgeDirections do
	local duration = MovementSimulation.GetDodgeSetting(dodgeName, "duration")
	local step = 1 / 60
	local distance = 0

	for elapsed = 0, duration, step do
		distance += MovementSimulation.GetDodgeSpeed(dodgeName, elapsed) * step
	end

	dodgeDistances[dodgeName] = distance
end

local function flatUnit(vector, fallback)
	local flat = vector * flatMask

	if flat.Magnitude < 1e-3 then
		return fallback
	end

	return flat.Unit
end

local function getRight(look)
	return Vector3.new(-look.Z, 0, look.X)
end

local function outsideDistance(cframe, size, point)
	local localPoint = cframe:PointToObjectSpace(point)
	local half = size * 0.5

	return math.max(
		math.abs(localPoint.X) - half.X,
		math.abs(localPoint.Y) - half.Y,
		math.abs(localPoint.Z) - half.Z
	)
end

local function makeRaycastParams(agent, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { agent.Character, target }

	return params
end

local function getWeapon(character)
	return MeleeRegistry.Get(character:GetAttribute(meleeAttributes.melee))
end

local function findTarget(agent, settings)
	local closest, closestDistance = nil, settings.sightRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart

		if root and humanoid.Health > 0 then
			local distance = (root.Position - agent.Root.Position).Magnitude

			if distance < closestDistance then
				closest = character
				closestDistance = distance
			end
		end
	end

	return closest, closestDistance
end

local function predictPosition(character, leadTime)
	local root = character.HumanoidRootPart

	return root.Position + Replication.GetVelocity(character) * flatMask * leadTime
end

local function predictHitbox(attacker, weapon, attack, leadTime)
	local cframe, size = weapon:GetHitbox(attacker, attack)
	local velocity = Replication.GetVelocity(attacker) * flatMask

	return cframe + velocity * leadTime, size
end

local function isEvasive(character, time, evasion)
	local dodgeName, elapsed, duration = MovementSimulation.GetLastDodge(character, time)

	return dodgeName ~= nil and elapsed >= 0 and elapsed <= duration + evasion.grace
end

local function assessActiveAttack(agent, target, weapon, now, settings)
	local memory = agent.Memory
	local _, attack, elapsed = weapon:GetActiveAttack(target, now)

	if not attack or elapsed > attack.hitEnd then
		return nil
	end

	local attackId = target:GetAttribute(meleeAttributes.attackId)

	if memory.seenAttackId ~= attackId then
		memory.seenAttackId = attackId
		memory.reactAt = now + random:NextNumber(settings.reactionTime.min, settings.reactionTime.max)
		memory.willDodge = random:NextNumber() < settings.dodgeChance
	end

	if not memory.willDodge or now < memory.reactAt then
		return nil
	end

	local cframe, size = predictHitbox(target, weapon, attack, math.max(attack.hitStart - elapsed, 0))

	if outsideDistance(cframe, size, agent.Root.Position) >= settings.dangerMargin then
		return nil
	end

	return {
		cframe = cframe,
		size = size,
	}
end

local function assessIncomingAttack(agent, target, weapon, now, settings)
	local predict = settings.predict
	local memory = agent.Memory

	if not predict.enabled then
		return nil
	end

	local ready = target:GetAttribute(meleeAttributes.attackReady) or 0
	local untilAttack = math.max(ready - now, 0)

	if untilAttack > predict.lookahead then
		return nil
	end

	local targetRoot = target.HumanoidRootPart
	local toSelf = flatUnit(agent.Root.Position - targetRoot.Position, Vector3.zero)
	local closingSpeed = (Replication.GetVelocity(target) * flatMask):Dot(toSelf)
	local held = target:GetAttribute(meleeAttributes.attackHeld) == true

	if not held and closingSpeed < predict.minClosingSpeed then
		return nil
	end

	local attack = weapon:GetAttack(weapon.Config.combo[1])
	local cframe, size = predictHitbox(target, weapon, attack, untilAttack + attack.hitStart)

	if outsideDistance(cframe, size, agent.Root.Position) >= settings.dangerMargin then
		return nil
	end

	if memory.predictKey ~= ready then
		memory.predictKey = ready
		memory.predictRoll = random:NextNumber() < predict.chance
	end

	if not memory.predictRoll then
		return nil
	end

	return {
		cframe = cframe,
		size = size,
	}
end

local function assessThreat(agent, target, now, settings)
	local weapon = getWeapon(target)

	if not weapon then
		return nil
	end

	return assessActiveAttack(agent, target, weapon, now, settings)
		or assessIncomingAttack(agent, target, weapon, now, settings)
end

local function chooseDodge(agent, target, threat, look, settings)
	local scoring = settings.dodgeScoring
	local position = agent.Root.Position
	local params = makeRaycastParams(agent, target)
	local bestName, bestScore = nil, -math.huge

	for dodgeName, direction in dodgeDirections do
		local worldDirection = MovementSimulation.GetDodgeInput(dodgeName, look)
		local distance = dodgeDistances[dodgeName]
		local score = outsideDistance(threat.cframe, threat.size, position + worldDirection * distance)

		if workspace:Raycast(position, worldDirection * (distance + scoring.wallMargin), params) then
			score -= scoring.wallPenalty
		end

		if direction.vector.X ~= 0 then
			score += scoring.lateralBias
		end

		score += random:NextNumber(0, scoring.randomness)

		if score > bestScore then
			bestName = dodgeName
			bestScore = score
		end
	end

	return bestName
end

local function trackCombo(agent, now, settings)
	local memory = agent.Memory
	local attackId = agent.Character:GetAttribute(meleeAttributes.attackId)

	if attackId == memory.lastOwnAttackId then
		return
	end

	memory.lastOwnAttackId = attackId
	memory.comboCount = (memory.comboCount or 0) + 1

	if memory.comboCount >= settings.attack.maxCombo then
		memory.comboCount = 0
		memory.engageAt = now + random:NextNumber(settings.attack.recover.min, settings.attack.recover.max)
	end
end

local function wantsToAttack(agent, target, now, settings, dodging)
	local attackSettings = settings.attack
	local memory = agent.Memory
	local character = agent.Character
	local weapon = getWeapon(character)

	if not attackSettings.enabled or not weapon or dodging then
		return false
	end

	if now < (memory.attackBlockedUntil or 0) or now < (memory.engageAt or 0) then
		return false
	end

	if weapon:GetActiveAttack(character, now) or now < (character:GetAttribute(meleeAttributes.attackReady) or 0) then
		return false
	end

	local attack = weapon:GetAttack(weapon.Config.combo[1])
	local leadTime = (attack.hitStart + attack.hitEnd) * 0.5
	local evasion = weapon.Config.dodgeEvasion

	if attackSettings.respectDodge and evasion and isEvasive(target, now + attack.hitStart, evasion) then
		return false
	end

	local cframe, size = weapon:GetHitbox(character, attack)

	if outsideDistance(cframe, size, predictPosition(target, leadTime)) > -attackSettings.reachPadding then
		return false
	end

	if random:NextNumber() > attackSettings.aggression then
		memory.attackBlockedUntil = now + random:NextNumber(attackSettings.hesitation.min, attackSettings.hesitation.max)

		return false
	end

	return true
end

local function getSpacingMove(agent, target, look, distance, now, settings, dodgeReady)
	local spacing = settings.spacing
	local memory = agent.Memory
	local right = getRight(look)

	if now >= (memory.strafeSwitchAt or 0) then
		memory.strafeSide = if random:NextNumber() < 0.5 then -1 else 1
		memory.strafeSwitchAt = now + random:NextNumber(spacing.strafeSwitch.min, spacing.strafeSwitch.max)
	end

	local strafeDirection = right * memory.strafeSide

	if workspace:Raycast(agent.Root.Position, strafeDirection * spacing.wallCheck, makeRaycastParams(agent, target)) then
		memory.strafeSide = -memory.strafeSide
		strafeDirection = -strafeDirection
	end

	local strafe = strafeDirection * spacing.strafeStrength
	local minimumDistance = if dodgeReady then spacing.min else spacing.cooldownMin

	if distance < minimumDistance then
		return (strafe - look).Unit, not dodgeReady and spacing.cooldownSprint
	end

	if distance > spacing.max then
		return (look + strafe * 0.5).Unit, distance > spacing.sprintBeyond
	end

	return strafe, false
end

local function getEngageMove(agent, look, distance, settings)
	if distance <= settings.attack.engageDistance then
		return getRight(look) * agent.Memory.strafeSide * settings.spacing.strafeStrength * 0.5, false
	end

	return look, distance > settings.spacing.max
end

local function shouldEngage(agent, target, now, settings, dodgeReady)
	if not settings.attack.enabled or not dodgeReady or now < (agent.Memory.engageAt or 0) then
		return false
	end

	return getWeapon(agent.Character) ~= nil
end

return function(agent, now)
	local settings = agent.Settings
	local memory = agent.Memory
	local character = agent.Character
	local position = agent.Root.Position

	local input = {
		Move = Vector3.zero,
		Look = agent.HomeLook,
		FaceCamera = true,
		Sprint = false,
		Dodge = false,
		Attack = false,
	}

	memory.strafeSide = memory.strafeSide or 1

	local pressedLast = memory.pressedDodge
	memory.pressedDodge = false

	trackCombo(agent, now, settings)

	local target, distance = findTarget(agent, settings)
	local toHome = (agent.Home - position) * flatMask

	if not target or toHome.Magnitude > settings.leashRadius then
		if toHome.Magnitude > settings.homeRadius then
			input.Move = toHome.Unit
			input.Look = toHome.Unit
			input.Sprint = toHome.Magnitude > settings.spacing.sprintBeyond
		end

		return input
	end

	local look = flatUnit(target.HumanoidRootPart.Position - position, agent.HomeLook)
	input.Look = look

	local dodging = MovementSimulation.GetDodge(character, now) ~= nil
	local dodgeReady = now >= (character:GetAttribute(movementAttributes.dodgeReady) or 0)
	local weapon = getWeapon(character)
	local committed = settings.commitToAttack and weapon ~= nil and weapon:GetActiveAttack(character, now) ~= nil
	local threat = if committed then nil else assessThreat(agent, target, now, settings)

	if threat then
		if dodgeReady and not dodging and not pressedLast then
			input.Move = MovementSimulation.GetDodgeInput(chooseDodge(agent, target, threat, look, settings), look)
			input.Dodge = true
			memory.pressedDodge = true

			return input
		end

		if not dodging then
			input.Move = flatUnit(position - threat.cframe.Position, -look)
			input.Sprint = settings.retreatSprint
		end

		return input
	end

	input.Attack = wantsToAttack(agent, target, now, settings, dodging)

	if shouldEngage(agent, target, now, settings, dodgeReady) then
		input.Move, input.Sprint = getEngageMove(agent, look, distance, settings)
	else
		input.Move, input.Sprint = getSpacingMove(agent, target, look, distance, now, settings, dodgeReady)
	end

	return input
end
