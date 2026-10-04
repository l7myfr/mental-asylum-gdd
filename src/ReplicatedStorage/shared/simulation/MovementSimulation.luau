local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)

local attributes = MovementConfig.attributes
local dodgeConfig = MovementConfig.dodge
local facingConfig = MovementConfig.facing
local flatMask = Vector3.new(1, 0, 1)

local MovementSimulation = {}

local function flatten(vector)
	return vector * flatMask
end

local function flatUnit(vector)
	local flat = flatten(vector)

	if flat.Magnitude < 1e-3 then
		return nil
	end

	return flat.Unit
end

local function approach(current, target, maxDelta)
	if current < target then
		return math.min(current + maxDelta, target)
	end

	return math.max(current - maxDelta, target)
end

local function yawDifference(from, to)
	local fromAngle = math.atan2(from.X, from.Z)
	local toAngle = math.atan2(to.X, to.Z)

	return fromAngle, (toAngle - fromAngle + math.pi) % (2 * math.pi) - math.pi
end

local function fromYaw(angle)
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

local function turnToward(from, to, maxAngle)
	local fromAngle, difference = yawDifference(from, to)

	return fromYaw(fromAngle + math.clamp(difference, -maxAngle, maxAngle))
end

local function smoothTurn(from, to, sharpness, deltaTime)
	local fromAngle, difference = yawDifference(from, to)

	return fromYaw(fromAngle + difference * (1 - math.exp(-sharpness * deltaTime)))
end

-- Rotating through a constraint keeps the root physically simulated; writing root.CFrame every
-- frame counts as a teleport and breaks native replication of server-simulated characters.
local function getFacingDriver(root)
	local driver = root:FindFirstChild(facingConfig.driverName)

	if driver then
		return driver
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = facingConfig.attachmentName
	attachment.Parent = root

	driver = Instance.new("AlignOrientation")
	driver.Name = facingConfig.driverName
	driver.Mode = Enum.OrientationAlignmentMode.OneAttachment
	driver.Attachment0 = attachment
	driver.RigidityEnabled = true
	driver.Parent = root

	return driver
end

local function getRight(look)
	return Vector3.new(-look.Z, 0, look.X)
end

function MovementSimulation.GetDodgeSetting(dodgeName, key)
	local direction = dodgeConfig.directions[dodgeName]

	if direction and direction[key] ~= nil then
		return direction[key]
	end

	return dodgeConfig[key]
end

function MovementSimulation.GetLastDodge(character, now)
	local dodgeName = character:GetAttribute(attributes.dodge)
	local start = character:GetAttribute(attributes.dodgeStart)

	if not dodgeName or not start or not dodgeConfig.directions[dodgeName] then
		return nil
	end

	return dodgeName, now - start, MovementSimulation.GetDodgeSetting(dodgeName, "duration")
end

function MovementSimulation.GetDodge(character, now)
	local dodgeName, elapsed, duration = MovementSimulation.GetLastDodge(character, now)

	if not dodgeName or elapsed < 0 or elapsed >= duration then
		return nil
	end

	return dodgeName, elapsed
end

function MovementSimulation.GetDodgeInput(dodgeName, look)
	local direction = dodgeConfig.directions[dodgeName]
	local vector = direction.vector

	return (getRight(look) * vector.X - look * vector.Z).Unit
end

function MovementSimulation.ResolveDodge(moveVector, look)
	local bestName = dodgeConfig.fallback
	local bestDot = dodgeConfig.minimumInputDot

	if moveVector.Magnitude > MovementConfig.inputDeadzone then
		local localMove = Vector3.new(moveVector:Dot(getRight(look)), 0, -moveVector:Dot(look)).Unit

		for dodgeName, direction in dodgeConfig.directions do
			local dot = localMove:Dot(direction.vector.Unit)

			if dot > bestDot then
				bestName = dodgeName
				bestDot = dot
			end
		end
	end

	return bestName, MovementSimulation.GetDodgeInput(bestName, look)
end

function MovementSimulation.GetDodgeSpeed(dodgeName, elapsed)
	local duration = MovementSimulation.GetDodgeSetting(dodgeName, "duration")
	local peak = MovementSimulation.GetDodgeSetting(dodgeName, "speed")
	local finish = MovementSimulation.GetDodgeSetting(dodgeName, "endSpeed")
	local easing = MovementSimulation.GetDodgeSetting(dodgeName, "easing")
	local alpha = math.clamp(elapsed / duration, 0, 1)

	return finish + (peak - finish) * (1 - alpha) ^ easing
end

-- Whether the character is staggered at the given time. endTolerance shortens the stagger, for
-- validating client timestamps.
function MovementSimulation.IsStaggered(character, now, endTolerance)
	local start = character:GetAttribute(attributes.staggerStart)
	local finish = character:GetAttribute(attributes.staggerEnd)

	return start ~= nil and finish ~= nil and now >= start and now < finish - (endTolerance or 0)
end

function MovementSimulation.StepDodge(character, input, moveVector, look, grounded, now)
	local pressed = input.Dodge == true and character:GetAttribute(attributes.dodgeHeld) ~= true
	character:SetAttribute(attributes.dodgeHeld, input.Dodge == true)

	local activeName, elapsed = MovementSimulation.GetDodge(character, now)

	if activeName or not pressed then
		return activeName, elapsed, false
	end

	if dodgeConfig.requiresGround and not grounded then
		return nil
	end

	if now < (character:GetAttribute(attributes.dodgeReady) or 0) or MovementSimulation.IsStaggered(character, now) then
		return nil
	end

	local dodgeName, worldDirection = MovementSimulation.ResolveDodge(moveVector, look)

	character:SetAttribute(attributes.dodge, dodgeName)
	character:SetAttribute(attributes.dodgeStart, now)
	character:SetAttribute(attributes.dodgeDirection, worldDirection)
	character:SetAttribute(attributes.dodgeFacing, look)
	character:SetAttribute(attributes.dodgeReady, now + MovementSimulation.GetDodgeSetting(dodgeName, "cooldown"))

	return dodgeName, 0, true
end

function MovementSimulation.StepCharacter(character, input, deltaTime, now)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart

	if not root or humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand then
		return
	end

	local moveVector = flatten(input.Move or Vector3.zero)

	if moveVector.Magnitude > 1 then
		moveVector = moveVector.Unit
	end

	local hasInput = moveVector.Magnitude > MovementConfig.inputDeadzone
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local sprinting = hasInput and input.Sprint == true

	local facing = character:GetAttribute(attributes.facing) or flatUnit(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local look = flatUnit(input.Look or Vector3.zero) or facing
	local speed = character:GetAttribute(attributes.speed) or 0
	local heading = character:GetAttribute(attributes.heading) or facing

	local goalSpeed = if sprinting then MovementConfig.runSpeed else MovementConfig.walkSpeed

	if MovementSimulation.IsStaggered(character, now) then
		goalSpeed *= MovementConfig.stagger.moveMultiplier
	end
	local targetSpeed = if hasInput then goalSpeed * moveVector.Magnitude else 0

	local rate
	if targetSpeed > speed then
		rate = if sprinting then MovementConfig.acceleration.run else MovementConfig.acceleration.walk
	elseif hasInput then
		rate = MovementConfig.deceleration.slowdown
	else
		rate = MovementConfig.deceleration.stop
	end

	if not grounded then
		rate *= MovementConfig.airControl
	end

	speed = approach(speed, targetSpeed, rate * deltaTime)

	if hasInput then
		heading = turnToward(heading, moveVector.Unit, MovementConfig.turnSpeed * deltaTime)
	end

	local dodgeName, dodgeElapsed, dodgeStarted = MovementSimulation.StepDodge(character, input, moveVector, look, grounded, now)
	local moveDirection = heading
	local moveSpeed = speed
	local facingTarget = nil
	local sharpness = facingConfig.moveSharpness

	if dodgeName then
		moveDirection = character:GetAttribute(attributes.dodgeDirection) or heading
		moveSpeed = MovementSimulation.GetDodgeSpeed(dodgeName, dodgeElapsed)
		facingTarget = character:GetAttribute(attributes.dodgeFacing)
		sharpness = facingConfig.dodgeSharpness
	elseif input.FaceCamera == true then
		facingTarget = look
		sharpness = facingConfig.cameraSharpness
	elseif hasInput or speed > MovementConfig.stopThreshold then
		facingTarget = heading
	end

	if facingTarget then
		facing = smoothTurn(facing, facingTarget, sharpness, deltaTime)
	end

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = moveSpeed
	getFacingDriver(root).CFrame = CFrame.lookAt(Vector3.zero, facing)

	if moveSpeed > MovementConfig.stopThreshold then
		humanoid:MoveTo(root.Position + moveDirection * MovementConfig.steerDistance)
	else
		humanoid:MoveTo(root.Position)
	end

	character:SetAttribute(attributes.speed, speed)
	character:SetAttribute(attributes.heading, heading)
	character:SetAttribute(attributes.facing, facing)
	character:SetAttribute(attributes.sprinting, sprinting)

	return if dodgeStarted then dodgeName else nil
end

return MovementSimulation
