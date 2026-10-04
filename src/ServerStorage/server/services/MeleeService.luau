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
	Evaded = "Event",
	Refunded = "Event",
}

MeleeService.AttackHistory = {}
-- Landed hits that a dodge pressed in time could still refund; see LandHit.
MeleeService.RecentHits = {}

function MeleeService:Start()
	self.Resolver = HitResolver.new()

	Stepper.Bind("Melee", MeleeConfig.simulation.priority, function(deltaTime, now)
		for character in AgentRegistry.GetAgents() do
			MeleeSimulation.StepCharacter(character, AgentRegistry.ReadInput(character, now, deltaTime), now, function(hit)
				if hit.evaded then
					self:NotifyEvaded(hit.target, hit.attacker, hit.weapon)
				else
					self:LandHit(hit, nil)
				end
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

-- Applies a hit immediately and remembers it until a dodge pressed in time could no longer arrive
-- (the dodge deadline plus the victim's latency). Damage never waits on the network; instead a dodge
-- that turns out to have been pressed in time refunds the hit.
function MeleeService:LandHit(hit, attackerPlayer)
	local victim = Players:GetPlayerFromCharacter(hit.target)

	hit.time = hit.time or Clock.Now()
	hit.swingTime = hit.swingTime or hit.time
	hit.attackerLatency = hit.attackerLatency or 0

	if not self:ApplyHit(hit, attackerPlayer) then
		return false
	end

	local deadline = self:GetDodgeDeadline(hit, victim)

	table.insert(self.RecentHits, {
		hit = hit,
		attackerPlayer = attackerPlayer,
		deadline = deadline,
		expiresAt = deadline + (if victim then self.Replication:GetLatency(victim) else 0),
	})

	return true
end

-- Whether a dodge that has arrived since the hit landed covers it: the victim was already dodging at
-- the hit (the dodge just reached the server late), or started one within the dodge deadline.
function MeleeService:WasDodged(hit, deadline)
	local weapon = MeleeRegistry.Get(hit.weapon)

	if weapon and weapon:IsDodgeProtected(hit.target, hit.time) then
		return true
	end

	local dodgeStart = hit.target:GetAttribute(movementAttributes.dodgeStart)

	return dodgeStart ~= nil and dodgeStart >= hit.time and dodgeStart <= deadline
end

-- Tells a player victim they evaded a hit, so their client can show it.
function MeleeService:NotifyEvaded(target, attacker, weaponName)
	local victim = Players:GetPlayerFromCharacter(target)

	if victim then
		self.Remotes.Evaded:Fire(victim, attacker, weaponName)
	end
end

function MeleeService:Refund(recent)
	local hit = recent.hit
	local humanoid = hit.humanoid

	-- A lethal hit cannot be undone.
	if not humanoid.Parent or humanoid.Health <= 0 then
		return
	end

	humanoid.Health = math.min(humanoid.Health + hit.damage, humanoid.MaxHealth)
	self:NotifyEvaded(hit.target, hit.attacker, hit.weapon)

	if recent.attackerPlayer and recent.attackerPlayer.Parent then
		self.Remotes.Refunded:Fire(recent.attackerPlayer, hit.target, hit.weapon)
	end
end

function MeleeService:Update()
	local now = Clock.Now()

	for index = #self.RecentHits, 1, -1 do
		local recent = self.RecentHits[index]

		if self:WasDodged(recent.hit, recent.deadline) then
			table.remove(self.RecentHits, index)
			self:Refund(recent)
		elseif now >= recent.expiresAt then
			table.remove(self.RecentHits, index)
		end
	end

	if self.Resolver then
		self.Resolver:Update(function(request, hits, evaded)
			local landed = {}

			for _, target in evaded do
				self:NotifyEvaded(target, request.attacker, request.weapon.Name)
			end

			for _, hit in hits do
				if self:LandHit(hit, request.player) then
					table.insert(landed, hit.target)
				end
			end

			if request.player.Parent then
				self.Remotes.Confirm:Fire(request.player, request.attackId, request.weapon.Name, landed, evaded)
			end
		end)
	end
end

return MeleeService
