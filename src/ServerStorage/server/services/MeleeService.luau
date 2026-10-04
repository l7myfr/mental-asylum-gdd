local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)
local MeleeRegistry = require(ReplicatedStorage.shared.melee.MeleeRegistry)
local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local MeleeSimulation = require(ReplicatedStorage.shared.simulation.MeleeSimulation)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)
local AgentRegistry = require(ReplicatedStorage.shared.simulation.AgentRegistry)
local Stepper = require(ReplicatedStorage.shared.simulation.Stepper)
local Clock = require(ReplicatedStorage.shared.utils.Clock)
local HitResolver = require(ServerStorage.server.modules.combat.HitResolver)

local attributes = MeleeConfig.attributes
local movementAttributes = MovementConfig.attributes
local validation = ChronoSettings.validation

local MeleeService = {}

MeleeService.Dependencies = {
	Replication = "ReplicationService",
}

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
				self:HoldHit(hit, nil)
			end)
		end
	end)

	self.Remotes.Attack:Connect(function(player, attackName, comboIndex, attackId, start, delays)
		-- A rejected swing confirms no hits, so the client cancels any hit effects it predicted.
		if not self:OnAttack(player, attackName, comboIndex, attackId, start, delays) then
			self.Remotes.Confirm:Fire(player, attackId, nil, {}, {})
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
	self.Replication:RecordLatency(player, start)
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

function MeleeService:GetReactionWindow(hit)
	local weapon = MeleeRegistry.Get(hit.weapon)
	local evasion = weapon and weapon.Config.dodgeEvasion

	return evasion and evasion.reactionWindow or 0
end

-- The latest a dodge may start and still evade a hit: reactionWindow after the swing could first be
-- seen by the victim. A player victim sees it late by the attacker's latency, their own latency and
-- Chrono's interpolation buffer, so measuring from the hit itself would leave them almost no window.
function MeleeService:GetDodgeDeadline(hit, victim)
	local seenAt = hit.swingTime + hit.attackerLatency

	if victim then
		seenAt += self.Replication:GetLatency(victim) + ChronoSettings.config.MAX_BUFFER
	end

	return seenAt + self:GetReactionWindow(hit)
end

-- Hits are held until the dodge deadline has passed (plus the victim's latency, so a dodge sent in
-- time has arrived) before damage, so a dodge started in reaction to the hit still evades it.
function MeleeService:HoldHit(hit, batch)
	local victim = Players:GetPlayerFromCharacter(hit.target)

	hit.time = hit.time or Clock.Now()
	hit.swingTime = hit.swingTime or hit.time
	hit.attackerLatency = hit.attackerLatency or 0

	local deadline = self:GetDodgeDeadline(hit, victim)

	table.insert(self.PendingHits, {
		hit = hit,
		batch = batch,
		deadline = deadline,
		releaseAt = deadline + (if victim then self.Replication:GetLatency(victim) else 0),
	})

	if batch then
		batch.waiting += 1
	end
end

function MeleeService:DodgedLate(hit, deadline)
	local dodgeStart = hit.target:GetAttribute(movementAttributes.dodgeStart)

	return dodgeStart ~= nil and dodgeStart >= hit.time and dodgeStart <= deadline
end

function MeleeService:ReleaseHit(hit, batch, deadline)
	if self:DodgedLate(hit, deadline) then
		if batch then
			table.insert(batch.evaded, hit.target)
		end
	elseif self:ApplyHit(hit, batch and batch.player) and batch then
		table.insert(batch.hits, hit.target)
	end

	if batch then
		batch.waiting -= 1

		if batch.waiting == 0 then
			self:Confirm(batch)
		end
	end
end

function MeleeService:Confirm(batch)
	if batch.player.Parent then
		self.Remotes.Confirm:Fire(batch.player, batch.attackId, batch.weapon, batch.hits, batch.evaded)
	end
end

function MeleeService:Update()
	local now = Clock.Now()

	for index = #self.PendingHits, 1, -1 do
		local pending = self.PendingHits[index]

		if now >= pending.releaseAt then
			table.remove(self.PendingHits, index)
			self:ReleaseHit(pending.hit, pending.batch, pending.deadline)
		end
	end

	if self.Resolver then
		self.Resolver:Update(function(request, hits, evaded)
			local batch = {
				player = request.player,
				attackId = request.attackId,
				weapon = request.weapon.Name,
				hits = {},
				evaded = evaded,
				waiting = 0,
			}

			for _, hit in hits do
				self:HoldHit(hit, batch)
			end

			if batch.waiting == 0 then
				self:Confirm(batch)
			end
		end)
	end
end

return MeleeService
