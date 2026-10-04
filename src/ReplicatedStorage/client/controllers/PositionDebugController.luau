local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.shared.config.DebugConfig)
local DebugToggle = require(ReplicatedStorage.client.modules.debug.DebugToggle)

local settings = DebugConfig.positions

local PositionDebugController = {}

PositionDebugController.Namespace = "PositionDebugService"
PositionDebugController.Remotes = {
	Position = "Unreliable",
}

PositionDebugController.Views = {}

local function createBox(parent, color)
	local box = Instance.new("BoxHandleAdornment")
	box.Adornee = workspace.Terrain
	box.AlwaysOnTop = settings.alwaysOnTop
	box.ZIndex = 2
	box.Color3 = color
	box.Transparency = settings.transparency
	box.Visible = false
	box.Parent = parent

	return box
end

function PositionDebugController:Start()
	self.Enabled = settings.enabledByDefault

	self.Folder = Instance.new("Folder")
	self.Folder.Name = settings.folderName
	self.Folder.Parent = workspace.CurrentCamera

	DebugToggle.new(settings, function()
		self.Enabled = not self.Enabled
	end)

	self.Remotes.Position:Connect(function(character, cframe)
		self:OnPosition(character, cframe)
	end)

	-- Runs after Chrono and physics have placed the parts for this frame.
	RunService.PreRender:Connect(function()
		self:Render()
	end)
end

function PositionDebugController:OnPosition(character, cframe)
	if typeof(character) ~= "Instance" or typeof(cframe) ~= "CFrame" then
		return
	end

	local view = self.Views[character]

	if not view then
		view = {
			Server = createBox(self.Folder, settings.serverColor),
			Client = createBox(self.Folder, settings.clientColor),
		}
		self.Views[character] = view
	end

	view.ServerCFrame = cframe
end

function PositionDebugController:Render()
	for character, view in self.Views do
		local root = character.Parent and character:FindFirstChild(settings.rootName)

		if not root then
			view.Server:Destroy()
			view.Client:Destroy()
			self.Views[character] = nil
		else
			view.Server.Visible = self.Enabled
			view.Client.Visible = self.Enabled

			if self.Enabled then
				view.Server.CFrame = view.ServerCFrame
				view.Server.Size = root.Size
				view.Client.CFrame = root.CFrame
				view.Client.Size = root.Size
			end
		end
	end
end

return PositionDebugController
