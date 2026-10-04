local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MeleeSimulation = require(ReplicatedStorage.shared.simulation.MeleeSimulation)
local MeleeRegistry = require(ReplicatedStorage.shared.melee.MeleeRegistry)
local CameraShaker = require(ReplicatedStorage.client.modules.utils.CameraShaker)
local MeleePresenter = require(ReplicatedStorage.client.modules.melee.MeleePresenter)
local HitFlash = require(ReplicatedStorage.client.modules.melee.HitFlash)
local AnimationTracks = require(ReplicatedStorage.client.modules.animation.AnimationTracks)
local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local DebugConfig = require(ReplicatedStorage.shared.config.DebugConfig)
local Replication = require(ReplicatedStorage.shared.simulation.Replication)
local Stepper = require(ReplicatedStorage.shared.simulation.Stepper)
local LocalInput = require(ReplicatedStorage.client.modules.input.LocalInput)

local MeleeController = {}

MeleeController.Namespace = "MeleeService"
MeleeController.Remotes = {
	Hit = "Event",
	Attack = "Event",
}

MeleeController.Presenters = {}
MeleeController.Flashes = {}

function MeleeController:Start()
	local animationRoots = {}

	for _, weapon in MeleeRegistry.GetAll() do
		table.insert(animationRoots, weapon.Config.animations)
	end

	task.spawn(AnimationTracks.Preload, animationRoots)

	Stepper.Bind("Melee", MeleeConfig.simulation.priority, function(deltaTime, now)
		self:Step(now)
	end)

	self.Shaker = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCFrame)
		local camera = workspace.CurrentCamera
		camera.CFrame *= shakeCFrame
	end)
	self.Shaker:Start()

	self.Remotes.Hit:Connect(function(attacker, target, position, weaponName)
		self:OnHit(attacker, target, position, weaponName)
	end)

	RunService.PreAnimation:Connect(function()
		self:Render()
	end)

	self:LinkObject(function(model)
		task.spawn(self.AddCharacter, self, model)
	end, MeleeConfig.entityTag, function(model)
		self:RemoveCharacter(model)
	end)
end

function MeleeController:Step(now)
	local character = Players.LocalPlayer.Character

	if not character then
		return
	end

	local started = MeleeSimulation.StepCharacter(character, LocalInput.Read(now), now)

	if started then
		self.Remotes.Attack:Fire(started.attack, started.combo, started.id, started.start, self:GetViewDelays(character))

		if DebugConfig.validation.logEnabled then
			print(DebugConfig.validation.prefix, "Attack sent", started.attack, "id", started.id)
		end
	end
end

function MeleeController:GetViewDelays(character)
	local delays = {}
	local root = character:FindFirstChild("HumanoidRootPart")
	local range = ChronoSettings.lagCompensation.viewRange

	if not root then
		return delays
	end

	for entityId, entity in Replication.GetEntities() do
		local model = entity.model

		if model and model ~= character and typeof(model) == "Instance" and model:IsA("Model") then
			local pivot = model:GetPivot()

			if (pivot.Position - root.Position).Magnitude <= range then
				delays[tostring(entityId)] = Replication.GetViewDelay(entity)
			end
		end
	end

	return delays
end

function MeleeController:Render()
	for _, presenter in self.Presenters do
		presenter:Update()
	end

	for index = #self.Flashes, 1, -1 do
		local flash = self.Flashes[index]

		if not flash:Update() then
			flash:Destroy()
			table.remove(self.Flashes, index)
		end
	end
end

function MeleeController:Shake(settings)
	if settings then
		self.Shaker:ShakeOnce(settings.magnitude, settings.roughness, settings.fadeIn, settings.fadeOut)
	end
end

function MeleeController:OnHit(attacker, target, position, weaponName)
	local weapon = MeleeRegistry.Get(weaponName)
	local effects = weapon and weapon.Config.effects

	if not effects then
		return
	end

	local localCharacter = Players.LocalPlayer.Character

	if target and effects.hitFlash then
		table.insert(self.Flashes, HitFlash.new(target, effects.hitFlash))
	end

	if attacker == localCharacter then
		self:Shake(effects.attackerShake)
	end

	if target == localCharacter then
		self:Shake(effects.victimShake)
	end
end

function MeleeController:AddCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", MeleeConfig.characterLoadTimeout)
	local animator = humanoid and humanoid:WaitForChild("Animator", MeleeConfig.characterLoadTimeout)

	if not animator or not character.Parent or self.Presenters[character] then
		return
	end

	self.Presenters[character] = MeleePresenter.new(character, animator)
end

function MeleeController:RemoveCharacter(character)
	local presenter = self.Presenters[character]

	if presenter then
		presenter:Destroy()
		self.Presenters[character] = nil
	end
end

function MeleeController:CharacterAdded(player, character)
	self:AddCharacter(character)
end

function MeleeController:CharacterRemoving(player, character)
	self:RemoveCharacter(character)
end

return MeleeController
