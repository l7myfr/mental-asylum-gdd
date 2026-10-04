local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spring = require(ReplicatedStorage.client.modules.utils.Spring)
local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)
local AnimationConfig = require(ReplicatedStorage.shared.config.MovementAnimationConfig)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)
local AnimationTracks = require(script.Parent.AnimationTracks)
local Clock = require(ReplicatedStorage.shared.utils.Clock)

local attributes = MovementConfig.attributes
local flatMask = Vector3.new(1, 0, 1)

local airborneStates = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
}

local MovementAnimator = {}
MovementAnimator.__index = MovementAnimator

local function getAnimation(animationName)
	return animationName and AnimationConfig.folder:FindFirstChild(animationName)
end

local function isAllowed(animation)
	if not animation then
		return false
	end

	for _, root in AnimationConfig.allowedRoots do
		if animation:IsDescendantOf(root) then
			return true
		end
	end

	return false
end

function MovementAnimator.new(character, humanoid, animator)
	local self = setmetatable({}, MovementAnimator)

	self.Character = character
	self.Humanoid = humanoid
	self.Tracks = AnimationTracks.new(animator)
	self.Springs = {}
	self.Connections = {}
	self.LastState = humanoid:GetState()
	self.AirborneSince = nil
	self.DodgeKey = nil
	self.DodgeAnimation = nil
	self.LastPosition = nil
	self.MeasuredSpeed = 0

	for role in AnimationConfig.locomotion do
		local initial = if role == "idle" then 1 else 0
		self.Springs[role] = Spring.new(initial, AnimationConfig.weightSpring.damping, AnimationConfig.weightSpring.speed)
	end

	if AnimationConfig.stopForeignTracks then
		for _, track in animator:GetPlayingAnimationTracks() do
			self:FilterTrack(track)
		end

		table.insert(self.Connections, animator.AnimationPlayed:Connect(function(track)
			self:FilterTrack(track)
		end))
	end

	return self
end

function MovementAnimator:FilterTrack(track)
	if not isAllowed(track.Animation) then
		track:Stop(0)
	end
end

function MovementAnimator:UpdateLocomotion(speed)
	local moveBlend = math.clamp(speed / AnimationConfig.blendInSpeed, 0, 1)
	local runRange = MovementConfig.runSpeed - MovementConfig.walkSpeed
	local runBlend = math.clamp((speed - MovementConfig.walkSpeed) / runRange, 0, 1)

	local targets = {
		idle = 1 - moveBlend,
		walk = moveBlend * (1 - runBlend),
		run = moveBlend * runBlend,
	}

	for role, settings in AnimationConfig.locomotion do
		local animation = getAnimation(settings.animation)
		local spring = self.Springs[role]

		if animation and spring then
			spring.Target = targets[role] or 0

			local weight = math.max(math.clamp(spring.Position, 0, 1), AnimationConfig.minimumWeight)
			local playbackSpeed = 1

			if settings.referenceSpeed then
				playbackSpeed = math.clamp(speed / settings.referenceSpeed, settings.minimumPlaybackSpeed, settings.maximumPlaybackSpeed)
			end

			local track = self.Tracks:Play(animation, {
				priority = settings.priority,
				looped = true,
				fadeTime = 0,
				weight = weight,
				speed = playbackSpeed,
			})

			track:AdjustWeight(weight, 0)
			track:AdjustSpeed(playbackSpeed)
		end
	end
end

function MovementAnimator:PlayAirborne(key)
	local settings = AnimationConfig.airborne[key]
	local animation = getAnimation(settings.animation)

	if animation then
		self.Tracks:Play(animation, {
			priority = settings.priority,
			fadeTime = settings.fadeTime,
			speed = settings.speed,
			restart = true,
		})
	end
end

function MovementAnimator:StopAirborne(key)
	local settings = AnimationConfig.airborne[key]
	local animation = getAnimation(settings.animation)

	if animation then
		self.Tracks:Stop(animation, settings.fadeOutTime)
	end
end

function MovementAnimator:UpdateAirborne(now)
	local state = self.Humanoid:GetState()
	local previous = self.LastState

	if state ~= previous then
		self.LastState = state

		local wasAirborne = airborneStates[previous] == true
		local isAirborne = airborneStates[state] == true

		if state == Enum.HumanoidStateType.Jumping then
			self:StopAirborne("fall")
			self:PlayAirborne("jump")
		end

		if isAirborne and not wasAirborne then
			self.AirborneSince = now
		elseif wasAirborne and not isAirborne then
			local airTime = if self.AirborneSince then now - self.AirborneSince else 0
			self.AirborneSince = nil

			self:StopAirborne("jump")
			self:StopAirborne("fall")

			if state ~= Enum.HumanoidStateType.Dead and airTime >= AnimationConfig.airborne.land.minimumAirTime then
				self:PlayAirborne("land")
			end
		end
	end

	if state ~= Enum.HumanoidStateType.Freefall or not self.AirborneSince then
		return
	end

	if now - self.AirborneSince < AnimationConfig.airborne.fall.delay then
		return
	end

	local fall = getAnimation(AnimationConfig.airborne.fall.animation)

	if fall and not self.Tracks:IsPlaying(fall) then
		self:PlayAirborne("fall")
	end
end

function MovementAnimator:UpdateDodge(now)
	local start = self.Character:GetAttribute(attributes.dodgeStart)

	-- A stagger can cancel a dodge that is already playing.
	if self.DodgeAnimation and not MovementSimulation.GetLastDodge(self.Character, now) then
		self.Tracks:Stop(self.DodgeAnimation, AnimationConfig.dodge.fadeOutTime)
		self.DodgeAnimation = nil
	end

	if start == self.DodgeKey then
		return
	end

	self.DodgeKey = start

	if self.DodgeAnimation then
		self.Tracks:Stop(self.DodgeAnimation, AnimationConfig.dodge.fadeOutTime)
		self.DodgeAnimation = nil
	end

	local dodgeName = self.Character:GetAttribute(attributes.dodge)

	if not dodgeName or not start or now - start > AnimationConfig.dodge.renderWindow then
		return
	end

	local animation = getAnimation(MovementSimulation.GetDodgeSetting(dodgeName, "animation"))

	if not animation then
		return
	end

	self.DodgeAnimation = animation
	self.Tracks:Play(animation, {
		priority = AnimationConfig.dodge.priority,
		fadeTime = AnimationConfig.dodge.fadeTime,
		speed = MovementSimulation.GetDodgeSetting(dodgeName, "animationSpeed"),
		restart = true,
	})
end

function MovementAnimator:MeasureSpeed(root, deltaTime)
	if self.Character == Players.LocalPlayer.Character then
		return (root.AssemblyLinearVelocity * flatMask).Magnitude
	end

	local position = root.Position
	local last = self.LastPosition
	self.LastPosition = position

	if not last or deltaTime <= 0 then
		return self.MeasuredSpeed
	end

	local sample = ((position - last) * flatMask).Magnitude / deltaTime
	local alpha = 1 - math.exp(-AnimationConfig.remoteSpeedSharpness * deltaTime)
	self.MeasuredSpeed += (sample - self.MeasuredSpeed) * alpha

	return self.MeasuredSpeed
end

function MovementAnimator:Update(deltaTime)
	local root = self.Humanoid.RootPart

	if not root then
		return
	end

	local now = Clock.Now()

	self:UpdateLocomotion(self:MeasureSpeed(root, deltaTime or 0))
	self:UpdateAirborne(now)
	self:UpdateDodge(now)
end

function MovementAnimator:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end

	table.clear(self.Connections)
	self.Tracks:Destroy()
end

return MovementAnimator
