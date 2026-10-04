local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local MeleeSimulation = require(ReplicatedStorage.shared.simulation.MeleeSimulation)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)
local AgentRegistry = require(ReplicatedStorage.shared.simulation.AgentRegistry)
local Stepper = require(ReplicatedStorage.shared.simulation.Stepper)
local Clock = require(ReplicatedStorage.shared.utils.Clock)
local HitResolver = require(ServerStorage.server.modules.combat.HitResolver)

local attributes = MeleeConfig.attributes
local validation = ChronoSettings.validation

local MeleeService = {}

MeleeService.Remotes = {
	Hit = "Event",
	Attack = "Event",
	Confirm = "Event",
}

MeleeService.AttackHistory = {}
MeleeService.PendingHits = {}

function MeleeService:Start()
	self.Resolver = HitResolver.new()

	Stepper.Bind("Melee", MeleeConfig.simulation.priority, function(deltaTime, now)
		for character in AgentRegistry.GetAgents() do
			MeleeSimulation.StepCharacter(character, AgentRegistry.ReadInput(character, now, deltaTime), now, function(hit)
				table.insert(self.PendingHits, hit)
			end)
		end
	end)

	self.Remotes.Attack:Connect(function(player, attackName, comboIndex, attackId, start, delays)
		-- A rejected swing confirms no hits, so the client cancels any hit effects it predicted.
		if not self:OnAttack(player, attackName, comboIndex, attackId, start, delays) then
			self.Remotes.Confirm:Fire(player, attackId, nil, {})
		end
	end)
end

-- Returns true when the swing is accepted and queued for hit resolution.
function MeleeService:OnAttack(player, attackName, comboIndex, attackId, start, delays)
	if type(attackName) ~= "string" or type(attackId) ~= "number" or type(start) ~= "number" then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local weapon = character and MeleeSimulation.GetWeapon(character)
	local attack = weapon and weapon:GetAttack(attackName)

	if not attack or not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = Clock.Now()
	local latency = math.clamp(now - start, 0, validation.maxLatency)
	start = math.clamp(start, now - validation.maxLatency, now)

	local history = self.AttackHistory[player]

	if history and start < history.ready - validation.cooldownTolerance then
		return
	end

	if not weapon.Config.canAttackWhileDodging and MovementSimulation.GetDodge(character, start) then
		return
	end

	local id = if history then math.max(attackId, history.id + 1) else attackId

	self.AttackHistory[player] = {
		ready = start + (attack.cooldown or attack.duration),
		id = id,
	}

	character:SetAttribute(attributes.attack, attackName)
	character:SetAttribute(attributes.attackStart, start)
	character:SetAttribute(attributes.attackId, id)
	character:SetAttribute(attributes.combo, if type(comboIndex) == "number" then comboIndex else 0)
	character:SetAttribute(attributes.attackReady, start + (attack.cooldown or attack.duration))

	self.Resolver:Queue({
		attacker = character,
		player = player,
		weapon = weapon,
		attackName = attackName,
		attack = attack,
		start = start,
		latency = latency,
		attackId = attackId,
		delays = HitResolver.SanitizeDelays(delays),
	})

	return true
end

function MeleeService:CharacterAdded(player, character)
	self.AttackHistory[player] = nil

	if MeleeConfig.starterMelee then
		self:Equip(character, MeleeConfig.starterMelee)
	end
end

function MeleeService:PlayerRemoving(player)
	self.AttackHistory[player] = nil
end

function MeleeService:Equip(character, weaponName)
	MeleeSimulation.Equip(character, weaponName)
end

function MeleeService:Unequip(character)
	MeleeSimulation.Equip(character, nil)
end

-- Returns true when the hit is applied. The attacking player (if any) learns about its hits through
-- Confirm instead of the broadcast, since it already predicted them.
function MeleeService:ApplyHit(hit, attackerPlayer)
	local humanoid = hit.humanoid

	if not humanoid.Parent or humanoid.Health <= 0 then
		return false
	end

	humanoid:TakeDamage(hit.damage)

	if attackerPlayer then
		self.Remotes.Hit:FireExcept(attackerPlayer, hit.attacker, hit.target, hit.position, hit.weapon)
	else
		self.Remotes.Hit:FireAll(hit.attacker, hit.target, hit.position, hit.weapon)
	end

	return true
end

function MeleeService:Update()
	local pending = self.PendingHits
	self.PendingHits = {}

	for _, hit in pending do
		self:ApplyHit(hit)
	end

	if self.Resolver then
		self.Resolver:Update(function(request, hits)
			local confirmed = {}

			for _, hit in hits do
				if self:ApplyHit(hit, request.player) then
					table.insert(confirmed, hit.target)
				end
			end

			if request.player.Parent then
				self.Remotes.Confirm:Fire(request.player, request.attackId, request.weapon.Name, confirmed)
			end
		end)
	end
end

return MeleeService
