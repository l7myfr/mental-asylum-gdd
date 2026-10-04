local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.shared.config.DebugConfig)

local settings = DebugConfig.launchTest

local LaunchTestController = {}

LaunchTestController.Namespace = "LaunchTestService"
LaunchTestController.Remotes = {
	Request = "Event",
	Launch = "Event",
}

function LaunchTestController:Start()
	if not settings.enabled then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LaunchTest"
	gui.ResetOnSpawn = false

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = settings.buttonPosition
	button.Size = settings.buttonSize
	button.Text = settings.buttonText
	button.TextScaled = true
	button.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	button.Activated:Connect(function()
		self.Remotes.Request:Fire()
	end)

	self.Remotes.Launch:Connect(function(velocity)
		self:Launch(velocity)
	end)
end

function LaunchTestController:Launch(velocity)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart

	if root and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = velocity
	end
end

return LaunchTestController
