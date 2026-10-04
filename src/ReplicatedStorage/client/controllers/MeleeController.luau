local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MeleeSimulation = require(ReplicatedStorage.shared.simulation.MeleeSimulation)
local MeleeRegistry = require(ReplicatedStorage.shared.melee.MeleeRegistry)
local CameraShaker = require(ReplicatedStorage.client.modules.utils.CameraShaker)
local MeleePresenter = require(ReplicatedStorage.client.modules.melee.MeleePresenter)
local HitFlash = require(ReplicatedStorage.client.modules.melee.HitFlash)
local EvadePopup = require(ReplicatedStorage.client.modules.melee.EvadePopup)
local AnimationTracks = require(ReplicatedStorage.client.modules.animation.AnimationTracks)
local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local Replication = require(ReplicatedStorage.shared.simulation.Replication)
local Stepper = require(ReplicatedStorage.shared.simulation.Stepper)
local LocalInput = require(ReplicatedStorage.client.modules.input.LocalInput)

local MeleeController = {}

MeleeController.Namespace = "MeleeService"
MeleeController.Remotes = {
	Hit = "Event",
	Attack = "Event",
	Confirm = "Event",
	Evaded = "Event",
}

local prediction = MeleeConfig.prediction

MeleeController.Presenters = {}
MeleeController.Flashes = {}
-- [attackId] = { expires, hits = { [target] = played effects } }
MeleeController.Predictions = {}

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
		self:PlayHit(attacker, target, weaponName)
	end)

	self.Remotes.Confirm:Connect(function(attackId, weaponName, hitTargets, evadedTargets)
		self:OnConfirm(attackId, weaponName, hitTargets, evadedTargets)
	end)

	self.Remotes.Evaded:Connect(function(attacker, weaponName)
		self:OnEvaded(weaponName)
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

	local started = MeleeSimulation.StepCharacter(character, LocalInput.Read(now), now, function(hit)
		self:PredictHit(hit)
	end)

	if started then
		self.SentAttackId = started.id
		self.Remotes.Attack:Fire(started.attack, started.combo, started.id, started.start, self:GetViewDelays(character))
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
	local clock = os.clock()

	for attackId, pending in self.Predictions do
		if clock >= pending.expires then
			self.Predictions[attackId] = nil
			self:CancelHits(pending, {})
		end
	end

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
		return self.Shaker:ShakeOnce(settings.magnitude, settings.roughness, settings.fadeIn, settings.fadeOut)
	end

	return nil
end

-- Plays hit effects and returns them so a mispredicted hit can be cancelled. flashColor overrides
-- the flash color (used for evaded hits).
function MeleeController:PlayHit(attacker, target, weaponName, flashColor)
	local weapon = MeleeRegistry.Get(weaponName)
	local effects = weapon and weapon.Config.effects
	local played = { shakes = {} }

	if not effects then
		return played
	end

	local localCharacter = Players.LocalPlayer.Character

	if target and effects.hitFlash then
		played.flash = HitFlash.new(target, effects.hitFlash, flashColor)
		table.insert(self.Flashes, played.flash)
	end

	local attackerShake = attacker == localCharacter and self:Shake(effects.attackerShake)
	local victimShake = target == localCharacter and self:Shake(effects.victimShake)

	if attackerShake then
		table.insert(played.shakes, attackerShake)
	end

	if victimShake then
		table.insert(played.shakes, victimShake)
	end

	return played
end

function MeleeController:CancelHit(played)
	local index = played.flash and table.find(self.Flashes, played.flash)

	if index then
		table.remove(self.Flashes, index)
		played.flash:Destroy()
	end

	for _, shake in played.shakes do
		shake:StartFadeOut(prediction.cancelFadeOut)
	end
end

-- Cancels every predicted hit whose target the server did not confirm.
function MeleeController:CancelHits(pending, confirmed)
	for target, played in pending.hits do
		if not confirmed[target] then
			self:CancelHit(played)
		end
	end
end

function MeleeController:PredictHit(hit)
	local attackId = self.SentAttackId

	-- Evasions are only shown once the server confirms them.
	if not attackId or hit.evaded then
		return
	end

	local pending = self.Predictions[attackId]

	if not pending then
		pending = {
			expires = os.clock() + prediction.confirmTimeout,
			hits = {},
		}
		self.Predictions[attackId] = pending
	end

	if not pending.hits[hit.target] then
		pending.hits[hit.target] = self:PlayHit(hit.attacker, hit.target, hit.weapon)
	end
end

-- Shows an evaded hit in the weapon's evaded color, recoloring the predicted flash if it is still playing.
function MeleeController:ShowEvaded(played, target, weaponName)
	local weapon = MeleeRegistry.Get(weaponName)
	local hitFlash = weapon and weapon.Config.effects and weapon.Config.effects.hitFlash

	if not hitFlash then
		return
	end

	if played and played.flash and table.find(self.Flashes, played.flash) then
		played.flash:SetColor(hitFlash.evadedColor)
	else
		table.insert(self.Flashes, HitFlash.new(target, hitFlash, hitFlash.evadedColor))
	end
end

-- The local player evaded a hit: flash their character and show a rising label.
function MeleeController:OnEvaded(weaponName)
	local character = Players.LocalPlayer.Character
	local weapon = MeleeRegistry.Get(weaponName)
	local hitFlash = weapon and weapon.Config.effects and weapon.Config.effects.hitFlash
	local feedback = MeleeConfig.evadeFeedback

	if not character then
		return
	end

	if hitFlash then
		table.insert(self.Flashes, HitFlash.new(character, hitFlash, feedback.color))
	end

	EvadePopup.Show(character, feedback)
end

function MeleeController:OnConfirm(attackId, weaponName, hitTargets, evadedTargets)
	local pending = self.Predictions[attackId]
	local resolved = {}

	self.Predictions[attackId] = nil

	for _, target in if type(hitTargets) == "table" then hitTargets else {} do
		resolved[target] = true

		-- The server can land hits the client missed; play those now.
		if not (pending and pending.hits[target]) then
			self:PlayHit(Players.LocalPlayer.Character, target, weaponName)
		end
	end

	for _, target in if type(evadedTargets) == "table" then evadedTargets else {} do
		resolved[target] = true
		self:ShowEvaded(pending and pending.hits[target], target, weaponName)
	end

	if pending then
		self:CancelHits(pending, resolved)
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
