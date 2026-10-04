local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputConfig = require(ReplicatedStorage.shared.config.InputConfig)
local LocalInput = require(ReplicatedStorage.client.modules.input.LocalInput)

local InputController = {}

function InputController:init()
	LocalInput.Init()
end

function InputController:Start()
	for _, rebind in InputConfig.rebinds do
		for _, target in rebind.targets do
			task.spawn(self.ApplyRebind, self, target, rebind.bindings)
		end
	end
end

function InputController:ResolveRoot(rootName)
	if rootName == "LocalPlayer" then
		return Players.LocalPlayer
	end

	return game:GetService(rootName)
end

function InputController:ApplyRebind(target, bindings)
	local instance = self:ResolveRoot(target[1])

	for index = 2, #target do
		instance = instance:WaitForChild(target[index], InputConfig.rebindTimeout)

		if not instance then
			return
		end
	end

	for bindingName, keyCode in bindings do
		local binding = instance:WaitForChild(bindingName, InputConfig.rebindTimeout)

		if binding then
			binding.KeyCode = keyCode
		end
	end
end

return InputController
