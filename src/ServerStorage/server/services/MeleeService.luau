local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local ChronoSettings = require(ReplicatedStorage.shared.config.ChronoSettings)
local MeleeSimulation = require(ReplicatedStorage.shared.simulation.MeleeSimulation)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)
local AgentRegistry = require(ReplicatedStorage.shared.simulation.AgentRegistry)
local Stepper = require(ReplicatedStorage.shared.simulation.Stepper)
local Clock = require(ReplicatedStorage.shared.utils.Clock)
local DebugConfig = require(ReplicatedStorage.shared.config.DebugConfig)
local HitResolver = require(ServerStorage.server.modules.combat.HitResolver)

local attributes = MeleeConfig.attributes
local validation = ChronoSettings.validation
local validationLog = DebugConfig.validation

local MeleeService = {}

MeleeService.Remotes = {
	Hit = "Event",
	Attack = "Event",
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
		local rejection = self:OnAttack(player, attackName, comboIndex, attackId, start, delays)

		if validationLog.logEnabled then
			print(validationLog.prefix, "Attack", if rejection then "REJECTED" else "accepted", player.Name, attackName, "id", attackId,
				"latency", if type(start) == "number" then ("%.3f"):format(Clock.Now() - start) else "?", rejection or "")
		end
	end)
end

-- Returns a rejection reason, or nil when the attack is accepted.
function MeleeService:OnAttack(player, attackName, comboIndex, attackId, start, delays)
	if type(attackName) ~= "string" or type(attackId) ~= "number" or type(start) ~= "number" then
		return "malformed"
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local weapon = character and MeleeSimulation.GetWeapon(character)
	local attack = weapon and weapon:GetAttack(attackName)

	if not attack or not humanoid or humanoid.Health <= 0 then
		return "no weapon, attack or living humanoid"
	end

	local now = Clock.Now()
	start = math.clamp(start, now - validation.maxLatency, now)

	local history = self.AttackHistory[player]

	if history and start < history.ready - validation.cooldownTolerance then
		return ("cooldown (%.3fs early)"):format(history.ready - start)
	end

	if not weapon.Config.canAttackWhileDodging and MovementSimulation.GetDodge(character, start) then
		return "dodging"
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
		delays = HitResolver.SanitizeDelays(delays),
	})
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

function MeleeService:ApplyHit(hit)
	local humanoid = hit.humanoid

	if not humanoid.Parent or humanoid.Health <= 0 then
		return
	end

	humanoid:TakeDamage(hit.damage)
	self.Remotes.Hit:FireAll(hit.attacker, hit.target, hit.position, hit.weapon)
end

function MeleeService:Update()
	local pending = self.PendingHits
	self.PendingHits = {}

	for _, hit in pending do
		self:ApplyHit(hit)
	end

	if self.Resolver then
		self.Resolver:Update(function(hit)
			self:ApplyHit(hit)
		end)
	end
end

return MeleeService
