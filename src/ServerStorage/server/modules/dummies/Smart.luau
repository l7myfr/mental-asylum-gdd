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

local function randomRange(range)
	return random:NextNumber(range.min, range.max)
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

	return closest
end

-- Perception: everything the dummy decides on comes from what the target looked like a reaction time
-- ago, never from the current frame.

local function record(memory, target, now, settings)
	if memory.target ~= target then
		memory.target = target
		memory.history = {}
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")

	table.insert(memory.history, {
		time = now,
		cframe = humanoid.RootPart.CFrame,
		velocity = Replication.GetVelocity(target) * flatMask,
		attackName = target:GetAttribute(meleeAttributes.attack),
		attackStart = target:GetAttribute(meleeAttributes.attackStart),
		attackId = target:GetAttribute(meleeAttributes.attackId),
		dodgeName = target:GetAttribute(movementAttributes.dodge),
		dodgeStart = target:GetAttribute(movementAttributes.dodgeStart),
		health = humanoid.Health / humanoid.MaxHealth,
	})

	while #memory.history > 1 and now - memory.history[1].time > settings.memoryLength do
		table.remove(memory.history, 1)
	end
end

local function perceive(memory, now, delay)
	local seen = memory.history[1]

	for _, observation in memory.history do
		if now - observation.time < delay then
			break
		end

		seen = observation
	end

	return seen
end

-- Where the target will be after lead seconds, extrapolated from what was seen (a person's read of
-- the motion, so sudden direction changes fool it).
local function project(seen, now, lead)
	return seen.cframe.Position + seen.velocity * (now - seen.time + lead)
end

-- Situation

-- Time since the target's last seen dodge started, and that dodge's visible movement duration. The
-- dummy judges dodges by what it can see, never by hidden invulnerability or exact cooldown state.
local function getSeenDodge(context)
	local seen = context.seen

	if not seen.dodgeName or not seen.dodgeStart or not dodgeDirections[seen.dodgeName] then
		return nil
	end

	return context.now - seen.dodgeStart, seen.dodgeName
end

local function getThreat(context)
	local weapon = context.targetWeapon
	local seen = context.seen
	local attack = weapon and weapon:GetAttack(seen.attackName)

	if not attack or not seen.attackStart then
		return nil
	end

	local elapsed = context.now - seen.attackStart

	if elapsed < 0 or elapsed > attack.hitEnd then
		return nil
	end

	local hitbox = attack.hitbox or weapon.Config.hitbox
	local lead = math.max(attack.hitStart - elapsed, 0)
	local cframe = (seen.cframe + seen.velocity * (context.now - seen.time + lead)) * hitbox.offset
	local root = context.agent.Root

	if outsideDistance(cframe, hitbox.size + root.Size, root.Position) >= context.settings.defense.dangerMargin then
		return nil
	end

	return {
		cframe = cframe,
		size = hitbox.size,
		id = seen.attackId,
	}
end

-- An opening a player would punish: the target just finished a dodge (so it is recharging; the
-- cooldown is game knowledge), or its swing just ended without a follow-up.
local function hasOpening(context)
	local seen = context.seen
	local sinceDodge, dodgeName = getSeenDodge(context)

	if
		sinceDodge
		and sinceDodge > MovementSimulation.GetDodgeSetting(dodgeName, "duration")
		and sinceDodge < MovementSimulation.GetDodgeSetting(dodgeName, "cooldown")
	then
		return true
	end

	local attack = context.targetWeapon and context.targetWeapon:GetAttack(seen.attackName)

	if attack and seen.attackStart then
		local sinceEnd = context.now - seen.attackStart - attack.duration

		return sinceEnd > 0 and sinceEnd < context.settings.punish.recoveryWindow
	end

	return false
end

local function inReach(context, padding)
	local weapon = context.weapon
	local attack = weapon:GetAttack(weapon.Config.combo[1])
	local cframe, size = weapon:GetHitbox(context.agent.Character, attack)
	local predicted = project(context.seen, context.now, (attack.hitStart + attack.hitEnd) * 0.5)

	return outsideDistance(cframe, size + context.agent.Root.Size, predicted) <= padding
end

local function getMood(context)
	local settings = context.settings.mood
	local humanoid = context.agent.Humanoid
	local lead = humanoid.Health / humanoid.MaxHealth - context.seen.health

	return math.clamp(settings.aggression + lead * settings.healthInfluence, settings.minimum, settings.maximum)
end

-- Decisions

local function setIntent(memory, intent, now)
	if memory.intent ~= intent then
		memory.intent = intent
		memory.intentSince = now
	end
end

local function enterNeutral(context)
	local memory = context.memory
	local patience = randomRange(context.settings.engage.patience) * (1.5 - context.mood)

	setIntent(memory, "neutral", context.now)
	memory.engageAt = context.now + patience
end

local function decide(context)
	local memory = context.memory
	local settings = context.settings
	local now = context.now

	if memory.comboLeft then
		return
	end

	if memory.intent == "recover" and now < memory.recoverUntil then
		return
	end

	if hasOpening(context) and random:NextNumber() < settings.punish.chance then
		setIntent(memory, "punish", now)
		return
	end

	if memory.intent == "engage" or memory.intent == "punish" then
		if now - memory.intentSince > settings.engage.giveUpTime then
			enterNeutral(context)
		end

		return
	end

	if memory.intent ~= "neutral" then
		enterNeutral(context)
		return
	end

	if now >= memory.engageAt then
		setIntent(memory, "engage", now)
		return
	end

	if random:NextNumber() < settings.spacing.baitChance then
		memory.baitUntil = now + randomRange(settings.spacing.baitDuration)
	end

	local closingSpeed = context.seen.velocity:Dot(-context.look)

	if
		context.dodgeReady
		and closingSpeed > settings.defense.panicClosingSpeed
		and context.distance < settings.spacing.min + 2
		and random:NextNumber() < settings.defense.panicDodgeChance
	then
		memory.panicDodge = true
	end
end

-- Actions

local function chooseDodge(context, threat)
	local scoring = context.settings.dodgeScoring
	local position = context.agent.Root.Position
	local params = makeRaycastParams(context.agent, context.target)
	local bestName, bestScore = nil, -math.huge

	for dodgeName, direction in dodgeDirections do
		local worldDirection = MovementSimulation.GetDodgeInput(dodgeName, context.look)
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

local function pressDodge(context, input, threat)
	local memory = context.memory

	input.Move = MovementSimulation.GetDodgeInput(chooseDodge(context, threat), context.look)
	input.Dodge = true
	memory.pressedDodge = true
	memory.comboLeft = nil
end

local function getStrafe(context)
	local memory = context.memory
	local spacing = context.settings.spacing

	if context.now >= (memory.strafeSwitchAt or 0) then
		memory.strafeSide = if random:NextNumber() < 0.5 then -1 else 1
		memory.strafeSwitchAt = context.now + randomRange(spacing.strafeSwitch)
	end

	local direction = getRight(context.look) * memory.strafeSide
	local params = makeRaycastParams(context.agent, context.target)

	if workspace:Raycast(context.agent.Root.Position, direction * spacing.wallCheck, params) then
		memory.strafeSide = -memory.strafeSide
		direction = -direction
	end

	return direction
end

-- Reflexes run every frame on what was perceived; returns true when they decided this frame's input.
local function react(context, threat, input)
	local memory = context.memory
	local defense = context.settings.defense

	if memory.threatId ~= threat.id then
		memory.threatId = threat.id
		memory.willDodge = random:NextNumber() < defense.dodgeChance
	end

	if context.dodging then
		return true
	end

	if memory.willDodge and context.dodgeReady and not context.pressedLast then
		pressDodge(context, input, threat)

		if random:NextNumber() < defense.counterChance then
			setIntent(memory, "punish", context.now)
		end

		return true
	end

	-- Already mid-combo: trade instead of backing off.
	if memory.comboLeft then
		return false
	end

	input.Move = flatUnit(context.agent.Root.Position - threat.cframe.Position, -context.look)
	input.Sprint = defense.retreatSprint

	return true
end

local function attack(context, input)
	local memory = context.memory
	local engage = context.settings.engage
	local weapon = context.weapon

	if memory.comboLeft then
		if memory.comboLeft > 0 and inReach(context, engage.whiffReach) then
			input.Attack = true
		elseif not weapon:GetActiveAttack(context.agent.Character, context.now) then
			memory.comboLeft = nil
			memory.recoverUntil = context.now + randomRange(context.settings.recover)
			setIntent(memory, "recover", context.now)
		end

		return
	end

	local character = context.agent.Character

	if weapon:GetActiveAttack(character, context.now) or context.now < (character:GetAttribute(meleeAttributes.attackReady) or 0) then
		return
	end

	local probe = weapon:GetAttack(weapon.Config.combo[1])

	-- Holds a swing while the target is visibly mid-dodge, the way a player would.
	local sinceDodge, dodgeName = getSeenDodge(context)

	if
		engage.respectDodge
		and sinceDodge
		and sinceDodge + probe.hitStart < MovementSimulation.GetDodgeSetting(dodgeName, "duration")
	then
		return
	end

	local padding = if random:NextNumber() < engage.whiffChance then engage.whiffReach else -engage.reachPadding

	if inReach(context, padding) then
		memory.comboLeft = random:NextInteger(engage.combo.min, engage.combo.max)
		input.Attack = true
	end
end

local function act(context, input)
	local memory = context.memory
	local settings = context.settings
	local spacing = settings.spacing
	local intent = memory.intent

	if memory.panicDodge then
		memory.panicDodge = nil

		if context.dodgeReady and not context.pressedLast then
			local probe = context.targetWeapon and context.targetWeapon:GetAttack(context.targetWeapon.Config.combo[1])
			local hitbox = probe and (probe.hitbox or context.targetWeapon.Config.hitbox)

			if hitbox then
				pressDodge(context, input, {
					cframe = context.seen.cframe * hitbox.offset,
					size = hitbox.size,
				})

				return
			end
		end
	end

	local strafe = getStrafe(context)

	if intent == "engage" or intent == "punish" then
		local toward = flatUnit(project(context.seen, context.now, 0) - context.agent.Root.Position, context.look)

		input.Move = toward + strafe * settings.engage.strafeStrength
		input.Sprint = context.distance > spacing.sprintBeyond or (intent == "punish" and context.distance > spacing.preferred)

		if context.weapon then
			attack(context, input)
		end
	elseif intent == "recover" then
		input.Move = -context.look + strafe * spacing.strafeStrength

		if memory.comboLeft and context.weapon then
			attack(context, input)
		end
	else
		local preferred = if context.dodgeReady then spacing.preferred else spacing.cooldownPreferred

		if memory.baitUntil and context.now < memory.baitUntil then
			preferred = spacing.min - 1
		end

		local radial = math.clamp((context.distance - preferred) / 3, -1, 1)

		input.Move = context.look * radial + strafe * spacing.strafeStrength
		input.Sprint = context.distance > spacing.sprintBeyond
	end
end

return function(agent, now)
	local settings = agent.Settings
	local memory = agent.Memory
	local position = agent.Root.Position

	local input = {
		Move = Vector3.zero,
		Look = agent.HomeLook,
		FaceCamera = true,
		Sprint = false,
		Dodge = false,
		Attack = false,
	}

	local pressedLast = memory.pressedDodge
	memory.pressedDodge = false
	memory.strafeSide = memory.strafeSide or 1

	local character = agent.Character
	local attackId = character:GetAttribute(meleeAttributes.attackId)

	if attackId ~= memory.ownAttackId then
		memory.ownAttackId = attackId

		if memory.comboLeft then
			memory.comboLeft -= 1
		end
	end

	local target = findTarget(agent, settings)
	local toHome = (agent.Home - position) * flatMask

	if not target or toHome.Magnitude > settings.leashRadius then
		memory.target = nil
		memory.intent = nil
		memory.comboLeft = nil

		if toHome.Magnitude > settings.homeRadius then
			input.Move = toHome.Unit
			input.Look = toHome.Unit
			input.Sprint = toHome.Magnitude > settings.spacing.sprintBeyond
		end

		return input
	end

	record(memory, target, now, settings)

	local decisionDue = now >= (memory.nextDecision or 0)

	if decisionDue then
		memory.reaction = randomRange(settings.reactionTime)
		memory.nextDecision = now + randomRange(settings.decisionInterval)
	end

	local seen = perceive(memory, now, memory.reaction)
	local targetPosition = project(seen, now, 0)

	local context = {
		agent = agent,
		memory = memory,
		settings = settings,
		target = target,
		seen = seen,
		now = now,
		look = flatUnit(targetPosition - position, agent.HomeLook),
		distance = ((targetPosition - position) * flatMask).Magnitude,
		weapon = getWeapon(character),
		targetWeapon = getWeapon(target),
		dodging = MovementSimulation.GetDodge(character, now) ~= nil,
		dodgeReady = now >= (character:GetAttribute(movementAttributes.dodgeReady) or 0),
		pressedLast = pressedLast,
	}
	context.mood = getMood(context)
	input.Look = context.look

	local threat = getThreat(context)

	if threat and react(context, threat, input) then
		return input
	end

	if decisionDue then
		decide(context)
	end

	act(context, input)

	return input
end
