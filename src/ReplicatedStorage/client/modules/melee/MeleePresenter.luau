local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.shared.utils.Clock)

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MeleeRegistry = require(ReplicatedStorage.shared.melee.MeleeRegistry)
local AnimationTracks = require(ReplicatedStorage.client.modules.animation.AnimationTracks)

local attributes = MeleeConfig.attributes

local MeleePresenter = {}
MeleePresenter.__index = MeleePresenter

function MeleePresenter.new(character, animator)
	local self = setmetatable({}, MeleePresenter)

	self.Character = character
	self.Tracks = AnimationTracks.new(animator)
	self.Weapon = nil
	self.Model = nil
	self.Joint = nil
	self.AttackId = character:GetAttribute(attributes.attackId)
	self.AttackAnimation = nil

	return self
end

function MeleePresenter:StopAttack(fadeTime)
	if self.AttackAnimation then
		self.Tracks:Stop(self.AttackAnimation, fadeTime)
		self.AttackAnimation = nil
	end
end

function MeleePresenter:ClearModel()
	self:StopAttack(0)

	if self.Model then
		self.Model:Destroy()
	end

	if self.Joint then
		self.Joint:Destroy()
	end

	self.Model = nil
	self.Joint = nil
end

function MeleePresenter:SetWeapon(weapon)
	if weapon ~= self.Weapon then
		self:ClearModel()
		self.Weapon = weapon
	end

	-- CreateModel returns nil until the grip limb has loaded; Update calls this every frame, so a
	-- missing model is retried instead of staying unequipped.
	if weapon and not self.Model then
		self.Model, self.Joint = weapon:CreateModel(self.Character)
	end
end

function MeleePresenter:UpdateAttack(now)
	local weapon = self.Weapon
	local attackId = self.Character:GetAttribute(attributes.attackId)

	if attackId == self.AttackId then
		return
	end

	self.AttackId = attackId

	local animationSettings = weapon.Config.animation
	self:StopAttack(animationSettings.fadeOutTime)

	local attackName = self.Character:GetAttribute(attributes.attack)
	local attack = weapon:GetAttack(attackName)
	local start = self.Character:GetAttribute(attributes.attackStart)

	if not attack or not start or now - start > attack.duration + animationSettings.renderSlack then
		return
	end

	local animation = weapon:GetAnimation(attackName)

	if not animation then
		return
	end

	self.AttackAnimation = animation
	self.Tracks:Play(animation, {
		priority = animationSettings.priority,
		fadeTime = animationSettings.fadeTime,
		speed = attack.animationSpeed,
		restart = true,
	})
end

function MeleePresenter:Update()
	local weapon = MeleeRegistry.Get(self.Character:GetAttribute(attributes.melee))
	self:SetWeapon(weapon)

	if weapon then
		self:UpdateAttack(Clock.Now())
	end
end

function MeleePresenter:Destroy()
	self:ClearModel()
	self.Tracks:Destroy()
end

return MeleePresenter
