local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)

local attributes = MeleeConfig.attributes

local MeleeClass = {}
MeleeClass.__index = MeleeClass

function MeleeClass.new(name, config)
	local self = setmetatable({}, MeleeClass)

	self.Name = name
	self.Config = config
	self.HitRecords = setmetatable({}, { __mode = "k" })

	return self
end

function MeleeClass:GetAttack(attackName)
	return attackName and self.Config.attacks[attackName]
end

function MeleeClass:GetActiveAttack(character, now)
	local attackName = character:GetAttribute(attributes.attack)
	local attack = self:GetAttack(attackName)
	local start = character:GetAttribute(attributes.attackStart)

	if not attack or not start then
		return nil
	end

	local elapsed = now - start

	if elapsed < 0 or elapsed >= attack.duration then
		return nil
	end

	return attackName, attack, elapsed
end

function MeleeClass:WantsAttack(context)
	if self.Config.holdToAttack then
		return context.held
	end

	return context.pressed
end

function MeleeClass:CanAttack(character, context)
	if context.dodging and not self.Config.canAttackWhileDodging then
		return false
	end

	if MovementSimulation.IsStaggered(character, context.now) then
		return false
	end

	if self:GetActiveAttack(character, context.now) then
		return false
	end

	return context.now >= (character:GetAttribute(attributes.attackReady) or 0)
end

function MeleeClass:SelectAttack(character, context)
	local combo = self.Config.combo
	local lastAttack = self:GetAttack(character:GetAttribute(attributes.attack))
	local lastStart = character:GetAttribute(attributes.attackStart)
	local comboIndex = character:GetAttribute(attributes.combo) or 0
	local chained = lastAttack ~= nil
		and lastStart ~= nil
		and context.now - lastStart <= lastAttack.duration + self.Config.comboResetTime

	local nextIndex = if chained then comboIndex % #combo + 1 else 1

	return combo[nextIndex], nextIndex
end

function MeleeClass:StartAttack(character, attackName, comboIndex, context)
	local attack = self:GetAttack(attackName)

	character:SetAttribute(attributes.attack, attackName)
	character:SetAttribute(attributes.attackStart, context.now)
	character:SetAttribute(attributes.attackId, (character:GetAttribute(attributes.attackId) or 0) + 1)
	character:SetAttribute(attributes.combo, comboIndex)
	character:SetAttribute(attributes.attackReady, context.now + (attack.cooldown or attack.duration))
end

function MeleeClass:Step(character, context)
	if not self:WantsAttack(context) or not self:CanAttack(character, context) then
		return
	end

	local attackName, comboIndex = self:SelectAttack(character, context)

	if self:GetAttack(attackName) then
		self:StartAttack(character, attackName, comboIndex, context)
	end
end

function MeleeClass:GetHitbox(character, attack)
	local root = character:FindFirstChild("HumanoidRootPart")
	local hitbox = attack.hitbox or self.Config.hitbox

	return root.CFrame * hitbox.offset, hitbox.size, hitbox
end

-- The bigger box that detects dodges, placed relative to the attacker's root. A dodging target inside
-- it evades the swing (and staggers the attacker) even if the damage hitbox would have missed it.
-- Falls back to the damage hitbox when the weapon doesn't define one.
function MeleeClass:GetEvadeBox(rootCFrame, attack)
	local box = attack.evadeHitbox or self.Config.evadeHitbox or attack.hitbox or self.Config.hitbox

	return rootCFrame * box.offset, box.size
end

-- Whether a dodge's invulnerability frames cover this moment. They start with the dodge and last
-- dodgeEvasion.iframes, or the dodge's own movement duration when that is not set.
function MeleeClass:IsDodgeProtected(character, now)
	local evasion = self.Config.dodgeEvasion
	local dodgeName, elapsed, duration = MovementSimulation.GetLastDodge(character, now)

	return evasion ~= nil and dodgeName ~= nil and elapsed >= 0 and elapsed <= (evasion.iframes or duration)
end

function MeleeClass:IsEvading(target, cframe, size, now)
	local evasion = self.Config.dodgeEvasion

	if not evasion or not target.root or not self:IsDodgeProtected(target.character, now) then
		return false
	end

	if evasion.invulnerable then
		return true
	end

	local localPosition = cframe:PointToObjectSpace(target.position or target.root.Position)
	local halfSize = size * evasion.hitboxScale * 0.5

	return math.abs(localPosition.X) > halfSize.X
		or math.abs(localPosition.Y) > halfSize.Y
		or math.abs(localPosition.Z) > halfSize.Z
end

function MeleeClass:CanHit(character, target)
	return target.humanoid.Health > 0
end

-- Characters a swing can hit: player characters and tagged entities (dummies), minus the attacker.
function MeleeClass.GetCandidates(attacker)
	local candidates = {}
	local seen = { [attacker] = true }

	local function add(character)
		if character and not seen[character] then
			seen[character] = true
			table.insert(candidates, character)
		end
	end

	for _, player in Players:GetPlayers() do
		add(player.Character)
	end

	for _, character in CollectionService:GetTagged(MeleeConfig.entityTag) do
		add(character)
	end

	return candidates
end

-- The single hitbox test shared by client hit prediction, NPC attacks and the server's lag-compensated
-- resolution. It checks the target's root (expanded by its size) because Chrono snapshots, which the
-- server rewinds, only hold root CFrames; any per-limb test would disagree with the server.
function MeleeClass.Overlaps(boxCFrame, boxSize, rootPosition, rootSize)
	local localPoint = boxCFrame:PointToObjectSpace(rootPosition)
	local half = (boxSize + rootSize) * 0.5

	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- Targets in the damage hitbox, plus dodging targets anywhere in the evade box (marked evaded).
function MeleeClass:QueryTargets(character, attack, now)
	local cframe, size = self:GetHitbox(character, attack)
	local evadeCFrame, evadeSize = self:GetEvadeBox(character.HumanoidRootPart.CFrame, attack)
	local targets = {}

	for _, model in MeleeClass.GetCandidates(character) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		local inDamage = root and MeleeClass.Overlaps(cframe, size, root.Position, root.Size)
		local inEvade = root and MeleeClass.Overlaps(evadeCFrame, evadeSize, root.Position, root.Size)

		if inDamage or inEvade then
			local target = {
				character = model,
				humanoid = humanoid,
				root = root,
				position = root.Position,
				cframe = root.CFrame,
				attackerCFrame = character:GetPivot(),
			}

			if self:CanHit(character, target) then
				target.evaded = inEvade and self:IsEvading(target, evadeCFrame, evadeSize, now)

				if inDamage or target.evaded then
					table.insert(targets, target)
				end
			end
		end
	end

	return targets
end

function MeleeClass:ComputeDamage(character, target, attack)
	return attack.damage
end

function MeleeClass:GetHitRecord(character)
	local attackId = character:GetAttribute(attributes.attackId)
	local record = self.HitRecords[character]

	if not record or record.attackId ~= attackId then
		record = {
			attackId = attackId,
			hit = {},
			count = 0,
		}
		self.HitRecords[character] = record
	end

	return record
end

function MeleeClass:ProcessHits(character, context, report)
	local attackName, attack, elapsed = self:GetActiveAttack(character, context.now)

	if not attack or elapsed < attack.hitStart or elapsed > attack.hitEnd then
		return
	end

	local record = self:GetHitRecord(character)
	local evasion = self.Config.dodgeEvasion
	local _, _, hitbox = self:GetHitbox(character, attack)

	for _, target in self:QueryTargets(character, attack, context.now) do
		if record.count >= hitbox.maxTargets then
			break
		end

		if not record.hit[target.humanoid] then
			if target.evaded then
				if evasion.consumesSwing then
					record.hit[target.humanoid] = true

					report({
						attacker = character,
						target = target.character,
						humanoid = target.humanoid,
						weapon = self.Name,
						attack = attackName,
						evaded = true,
					})
				end
			else
				record.hit[target.humanoid] = true
				record.count += 1

				report({
					attacker = character,
					target = target.character,
					humanoid = target.humanoid,
					weapon = self.Name,
					attack = attackName,
					damage = self:ComputeDamage(character, target, attack),
					position = target.position,
				})
			end
		end
	end
end

function MeleeClass:GetAnimation(attackName)
	local attack = self:GetAttack(attackName)

	return attack and self.Config.animations:FindFirstChild(attack.animation)
end

function MeleeClass:CreateModel(character)
	local grip = self.Config.grip
	local limb = character:FindFirstChild(grip.limb)

	if not limb or not self.Config.model then
		return nil
	end

	local model = self.Config.model:Clone()
	local handle = model.PrimaryPart

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end

	local joint = Instance.new("Motor6D")
	joint.Name = grip.joint
	joint.Part0 = limb
	joint.Part1 = handle
	joint.C0 = grip.c0
	joint.C1 = grip.c1
	joint.Parent = limb

	model.Parent = character

	return model, joint
end

return MeleeClass
