local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.shared.utils.Clock)

local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MovementConfig = require(ReplicatedStorage.shared.config.MovementConfig)
local MovementSimulation = require(ReplicatedStorage.shared.simulation.MovementSimulation)
local CharacterPopup = require(ReplicatedStorage.client.modules.melee.CharacterPopup)
local MeleeRegistry = require(ReplicatedStorage.shared.melee.MeleeRegistry)
local AnimationTracks = require(ReplicatedStorage.client.modules.animation.AnimationTracks)

local attributes = MeleeConfig.attributes
local movementAttributes = MovementConfig.attributes
local staggerFeedback = MeleeConfig.staggerFeedback

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
	self.AttackStart = character:GetAttribute(attributes.attackStart)
	self.AttackAnimation = nil
	self.StaggerStart = character:GetAttribute(movementAttributes.staggerStart)
	self.StaggerHighlight = nil

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

	local start = self.Character:GetAttribute(attributes.attackStart)

	-- The attack attributes replicate separately, so a new AttackId can arrive while AttackStart still
	-- holds the previous swing's time. Wait for the new start instead of judging the swing stale.
	if attackId == self.AttackId or start == self.AttackStart then
		return
	end

	self.AttackId = attackId
	self.AttackStart = start

	local animationSettings = weapon.Config.animation
	self:StopAttack(animationSettings.fadeOutTime)

	local attackName = self.Character:GetAttribute(attributes.attack)
	local attack = weapon:GetAttack(attackName)

	if not attack or not start or now - start > attack.duration + animationSettings.renderSlack then
		return
	end

	local animation = weapon:GetAnimation(attackName)

	if not animation then
		return
	end

	self.AttackAnimation = animation

	local track = self.Tracks:Play(animation, {
		priority = animationSettings.priority,
		fadeTime = animationSettings.fadeTime,
		speed = attack.animationSpeed,
		restart = true,
	})

	-- Swings from other clients arrive late; skip ahead so the windup shows when it really happened
	-- and defenders can react to it. Capped, since start times come from another client's clock.
	local catchUp = math.clamp(now - start, 0, animationSettings.maxCatchUp)
	track.TimePosition = catchUp * attack.animationSpeed
end

-- Shows a stagger to everyone: the swing animation is cut off, a label pops up, and the character
-- stays tinted until the stagger ends.
function MeleePresenter:UpdateStagger(now)
	local character = self.Character
	local start = character:GetAttribute(movementAttributes.staggerStart)
	local finish = character:GetAttribute(movementAttributes.staggerEnd)
	local staggered = MovementSimulation.IsStaggered(character, now)

	-- The attributes replicate separately; only treat a new start as a stagger once its end arrived.
	if start ~= self.StaggerStart and start and finish and finish > start then
		self.StaggerStart = start

		if staggered then
			self:StopAttack(if self.Weapon then self.Weapon.Config.animation.fadeOutTime else 0)
			CharacterPopup.Show(character, staggerFeedback)
		end
	end

	if staggered and not self.StaggerHighlight then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = staggerFeedback.color
		highlight.OutlineColor = staggerFeedback.color
		highlight.FillTransparency = staggerFeedback.fillTransparency
		highlight.OutlineTransparency = staggerFeedback.outlineTransparency
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = character
		highlight.Parent = character
		self.StaggerHighlight = highlight
	elseif not staggered and self.StaggerHighlight then
		self.StaggerHighlight:Destroy()
		self.StaggerHighlight = nil
	end
end

function MeleePresenter:Update()
	local now = Clock.Now()
	local weapon = MeleeRegistry.Get(self.Character:GetAttribute(attributes.melee))
	self:SetWeapon(weapon)

	if weapon then
		self:UpdateAttack(now)
	end

	self:UpdateStagger(now)
end

function MeleePresenter:Destroy()
	self:ClearModel()
	self.Tracks:Destroy()

	if self.StaggerHighlight then
		self.StaggerHighlight:Destroy()
	end
end

return MeleePresenter
