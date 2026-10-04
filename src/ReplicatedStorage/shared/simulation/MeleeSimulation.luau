local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)
local MeleeRegistry = require(ReplicatedStorage.shared.melee.MeleeRegistry)
local MovementSimulation = require(script.Parent.MovementSimulation)

local attributes = MeleeConfig.attributes
local movementAttributes = MovementConfig.attributes

local MeleeSimulation = {}

function MeleeSimulation.Equip(character, weaponName)
	character:SetAttribute(attributes.melee, weaponName)
end

function MeleeSimulation.GetWeapon(character)
	return MeleeRegistry.Get(character:GetAttribute(attributes.melee))
end

function MeleeSimulation.StepCharacter(character, input, now, report)
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid or not humanoid.RootPart then
		return nil
	end

	local held = input.Attack == true
	local wasHeld = character:GetAttribute(attributes.attackHeld) == true
	character:SetAttribute(attributes.attackHeld, held)

	local weapon = MeleeSimulation.GetWeapon(character)

	if not weapon or humanoid.Health <= 0 then
		return nil
	end

	local context = {
		now = now,
		held = held,
		pressed = held and not wasHeld,
		dodging = MovementSimulation.GetDodge(character, now) ~= nil,
		speed = character:GetAttribute(movementAttributes.speed) or 0,
		sprinting = character:GetAttribute(movementAttributes.sprinting) == true,
	}

	local previousId = character:GetAttribute(attributes.attackId)

	weapon:Step(character, context)

	if report then
		weapon:ProcessHits(character, context, report)
	end

	local attackId = character:GetAttribute(attributes.attackId)

	if attackId == previousId then
		return nil
	end

	return {
		attack = character:GetAttribute(attributes.attack),
		combo = character:GetAttribute(attributes.combo),
		id = attackId,
		start = character:GetAttribute(attributes.attackStart),
	}
end

return MeleeSimulation
