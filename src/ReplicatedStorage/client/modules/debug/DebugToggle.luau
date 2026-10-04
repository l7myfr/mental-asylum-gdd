local Players = game:GetService("Players")

local DebugToggle = {}

-- Binds settings.toggleKeys to a Bool InputAction and calls onToggle when it is pressed.
function DebugToggle.new(settings, onToggle)
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

	action.Pressed:Connect(onToggle)

	return context
end

return DebugToggle
