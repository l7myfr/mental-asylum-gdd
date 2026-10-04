local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.shared.utils.Clock)

local DebugConfig = require(ReplicatedStorage.shared.config.DebugConfig)
local MeleeConfig = require(ReplicatedStorage.shared.config.MeleeConfig)
local MeleeRegistry = require(ReplicatedStorage.shared.melee.MeleeRegistry)

local settings = DebugConfig.hitboxes
local meleeAttributes = MeleeConfig.attributes

local HitboxView = {}
HitboxView.__index = HitboxView

local function createBox(parent)
	local box = Instance.new("BoxHandleAdornment")
	box.AlwaysOnTop = settings.alwaysOnTop
	box.ZIndex = 1
	box.Visible = false
	box.Parent = parent

	return box
end

function HitboxView.new(character, folder)
	local self = setmetatable({}, HitboxView)

	self.Character = character
	self.Folder = Instance.new("Folder")
	self.Folder.Name = character.Name
	self.Folder.Parent = folder
	self.Hitbox = createBox(self.Folder)
	self.Hurtboxes = {}
	self.Connections = {}

	for _, descendant in character:GetDescendants() do
		self:TrackPart(descendant)
	end

	table.insert(self.Connections, character.DescendantAdded:Connect(function(descendant)
		self:TrackPart(descendant)
	end))

	table.insert(self.Connections, character.DescendantRemoving:Connect(function(descendant)
		local box = self.Hurtboxes[descendant]

		if box then
			box:Destroy()
			self.Hurtboxes[descendant] = nil
		end
	end))

	return self
end

function HitboxView:TrackPart(part)
	if not part:IsA("BasePart") or part.Name ~= settings.hurtboxPart or self.Hurtboxes[part] then
		return
	end

	local box = createBox(self.Folder)
	box.Adornee = part
	self.Hurtboxes[part] = box
end

function HitboxView:IsInvulnerable(now)
	local weapon = MeleeRegistry.Get(settings.evasionWeapon)
	local evasion = weapon and weapon.Config.dodgeEvasion

	if not evasion or not evasion.invulnerable then
		return false
	end

	return weapon:IsDodgeProtected(self.Character, now)
end

function HitboxView:UpdateHurtboxes(visible, now)
	local color = if self:IsInvulnerable(now) then settings.hurtbox.invulnerableColor else settings.hurtbox.color

	for part, box in self.Hurtboxes do
		local shown = visible
		box.Visible = shown

		if shown then
			box.Size = part.Size
			box.Color3 = color
			box.Transparency = settings.hurtbox.transparency
		end
	end
end

function HitboxView:UpdateHitbox(visible, now)
	local box = self.Hitbox
	local root = self.Character:FindFirstChild("HumanoidRootPart")
	local weapon = MeleeRegistry.Get(self.Character:GetAttribute(meleeAttributes.melee))
	local _, attack, elapsed = nil, nil, nil

	if weapon then
		_, attack, elapsed = weapon:GetActiveAttack(self.Character, now)
	end

	if not visible or not root or not attack then
		box.Visible = false
		return
	end

	local hitbox = attack.hitbox or weapon.Config.hitbox
	local active = elapsed >= attack.hitStart and elapsed <= attack.hitEnd

	box.Adornee = root
	box.CFrame = hitbox.offset
	box.Size = hitbox.size
	box.Color3 = if active then settings.hitbox.activeColor else settings.hitbox.windupColor
	box.Transparency = if active then settings.hitbox.activeTransparency else settings.hitbox.windupTransparency
	box.Visible = true
end

function HitboxView:Update(visible)
	local now = Clock.Now()

	self:UpdateHurtboxes(visible, now)
	self:UpdateHitbox(visible, now)
end

function HitboxView:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end

	table.clear(self.Connections)
	self.Folder:Destroy()
end

return HitboxView
