local MeleeClass = require(script.Parent.Parent.MeleeClass)

local flatMask = Vector3.new(1, 0, 1)

local Dagger = setmetatable({}, MeleeClass)
Dagger.__index = Dagger

function Dagger.new(name, config)
	return setmetatable(MeleeClass.new(name, config), Dagger)
end

function Dagger:SelectAttack(character, context)
	local running = self.Config.runningAttack

	if running and context.sprinting and context.speed >= running.minimumSpeed then
		return running.attack, 0
	end

	return MeleeClass.SelectAttack(self, character, context)
end

function Dagger:IsBackstab(character, target)
	local attackerRoot = character:FindFirstChild("HumanoidRootPart")
	local attackerPosition = if target.attackerCFrame then target.attackerCFrame.Position elseif attackerRoot then attackerRoot.Position else nil
	local targetCFrame = target.cframe or (target.root and target.root.CFrame)

	if not attackerPosition or not targetCFrame then
		return false
	end

	local toAttacker = (attackerPosition - targetCFrame.Position) * flatMask
	local facing = targetCFrame.LookVector * flatMask

	if toAttacker.Magnitude < 1e-3 or facing.Magnitude < 1e-3 then
		return false
	end

	return facing.Unit:Dot(toAttacker.Unit) <= -self.Config.backstab.minimumDot
end

function Dagger:ComputeDamage(character, target, attack)
	local damage = MeleeClass.ComputeDamage(self, character, target, attack)

	if self.Config.backstab and self:IsBackstab(character, target) then
		return damage * self.Config.backstab.multiplier
	end

	return damage
end

return Dagger
