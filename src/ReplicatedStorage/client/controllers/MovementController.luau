local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)
local AnimationConfig = require(ReplicatedStorage.shared.config.MovementAnimationConfig)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)
local MeleeSimulation = require(ReplicatedStorage.shared.simulation.MeleeSimulation)
local Stepper = require(ReplicatedStorage.shared.simulation.Stepper)
local LocalInput = require(ReplicatedStorage.client.modules.input.LocalInput)
local MovementAnimator = require(ReplicatedStorage.client.modules.animation.MovementAnimator)
local AnimationTracks = require(ReplicatedStorage.client.modules.animation.AnimationTracks)

local MovementController = {}

MovementController.Namespace = "MovementService"
MovementController.Remotes = {
	Dodge = "Event",
}

MovementController.Animators = {}

function MovementController:Start()
	task.spawn(AnimationTracks.Preload, { AnimationConfig.folder })

	Stepper.Bind("Movement", MovementConfig.simulation.priority, function(deltaTime, now)
		self:Step(deltaTime, now)
	end)

	RunService.PreAnimation:Connect(function(deltaTime)
		for _, animator in self.Animators do
			animator:Update(deltaTime)
		end
	end)

	self:LinkObject(function(model)
		task.spawn(self.AddCharacter, self, model)
	end, AnimationConfig.entityTag, function(model)
		self:RemoveCharacter(model)
	end)
end

function MovementController:Step(deltaTime, now)
	local character = Players.LocalPlayer.Character

	if not character then
		return
	end

	local attacking = MeleeSimulation.IsAttacking(character, now)
	local startedDodge = MovementSimulation.StepCharacter(character, LocalInput.Read(now), deltaTime, now, attacking)

	if startedDodge then
		self.Remotes.Dodge:Fire(startedDodge, now)
	end
end

function MovementController:AddCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", AnimationConfig.characterLoadTimeout)
	local animator = humanoid and humanoid:WaitForChild("Animator", AnimationConfig.characterLoadTimeout)

	if not animator or not character.Parent or self.Animators[character] then
		return
	end

	self.Animators[character] = MovementAnimator.new(character, humanoid, animator)
end

function MovementController:RemoveCharacter(character)
	local animator = self.Animators[character]

	if animator then
		animator:Destroy()
		self.Animators[character] = nil
	end
end

function MovementController:CharacterAdded(player, character)
	self:AddCharacter(character)
end

function MovementController:CharacterRemoving(player, character)
	self:RemoveCharacter(character)
end

return MovementController
