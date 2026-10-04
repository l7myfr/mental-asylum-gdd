local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.shared.config.DebugConfig)
local HitboxView = require(ReplicatedStorage.client.modules.debug.HitboxView)

local settings = DebugConfig.hitboxes

local HitboxDebugController = {}

HitboxDebugController.Views = {}

function HitboxDebugController:Start()
	self.Enabled = settings.enabledByDefault

	self.Folder = Instance.new("Folder")
	self.Folder.Name = settings.folderName
	self.Folder.Parent = workspace.CurrentCamera

	self:CreateToggle()

	self:LinkObject(function(model)
		self:AddCharacter(model)
	end, settings.entityTag, function(model)
		self:RemoveCharacter(model)
	end)

	RunService.PreAnimation:Connect(function()
		for _, view in self.Views do
			view:Update(self.Enabled)
		end
	end)
end

function HitboxDebugController:CreateToggle()
	local context = Instance.new("InputContext")
	context.Name = settings.contextName
	context.Priority = settings.contextPriority

	local action = Instance.new("InputAction")
	action.Name = settings.toggleAction
	action.Type = Enum.InputActionType.Bool

	for _, keyCode in settings.toggleKeys do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = keyCode
		binding.Parent = action
	end

	action.Parent = context
	context.Parent = Players.LocalPlayer

	action.Pressed:Connect(function()
		self.Enabled = not self.Enabled
	end)
end

function HitboxDebugController:AddCharacter(character)
	if self.Views[character] or not self.Folder then
		return
	end

	self.Views[character] = HitboxView.new(character, self.Folder)
end

function HitboxDebugController:RemoveCharacter(character)
	local view = self.Views[character]

	if view then
		view:Destroy()
		self.Views[character] = nil
	end
end

function HitboxDebugController:CharacterAdded(player, character)
	self:AddCharacter(character)
end

function HitboxDebugController:CharacterRemoving(player, character)
	self:RemoveCharacter(character)
end

return HitboxDebugController
