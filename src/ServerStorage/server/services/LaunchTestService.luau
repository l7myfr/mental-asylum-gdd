local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.shared.config.DebugConfig)

local settings = DebugConfig.launchTest

local LaunchTestService = {}

LaunchTestService.Remotes = {
	Request = "Event",
	Launch = "Event",
}

function LaunchTestService:Start()
	self.Remotes.Request:Connect(function()
		-- Each client owns its character's physics, so every client applies the launch itself.
		if settings.enabled then
			self.Remotes.Launch:FireAll(settings.velocity)
		end
	end)
end

return LaunchTestService
