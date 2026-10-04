local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputConfig = require(ReplicatedStorage.shared.config.InputConfig)

local gameSettings = UserSettings():GetService("UserGameSettings")
local flatMask = Vector3.new(1, 0, 1)

local LocalInput = {}

local context = nil
local moveSource = nil
local cached = nil

local function resolvePath(path)
	local instance = game:GetService(path[1])

	for index = 2, #path do
		instance = instance:WaitForChild(path[index], InputConfig.sourceTimeout)

		if not instance then
			return nil
		end
	end

	return instance
end

local function getCameraBasis()
	local cameraCFrame = workspace.CurrentCamera.CFrame
	local forward = cameraCFrame.LookVector * flatMask

	if forward.Magnitude < 1e-3 then
		forward = cameraCFrame.UpVector * flatMask
	end

	forward = forward.Unit

	return forward, Vector3.new(-forward.Z, 0, forward.X)
end

function LocalInput.Init()
	if context then
		return
	end

	context = Instance.new("InputContext")
	context.Name = InputConfig.contextName
	context.Priority = InputConfig.priority
	context.Sink = InputConfig.sink

	for actionName, actionConfig in InputConfig.actions do
		local action = Instance.new("InputAction")
		action.Name = actionName
		action.Type = actionConfig.type

		for _, keyCode in actionConfig.bindings do
			local binding = Instance.new("InputBinding")
			binding.KeyCode = keyCode
			binding.Parent = action
		end

		action.Parent = context
	end

	context.Parent = Players.LocalPlayer

	task.spawn(function()
		moveSource = resolvePath(InputConfig.moveSource)
	end)
end

function LocalInput.GetState(actionName)
	local action = context and context:FindFirstChild(actionName)

	return action and action:GetState()
end

function LocalInput.Read(now)
	if cached and cached.time == now then
		return cached.input
	end

	local raw = if moveSource then moveSource:GetState() else Vector2.zero
	local forward, right = getCameraBasis()
	local move = right * raw.X + forward * raw.Y

	if move.Magnitude > 1 then
		move = move.Unit
	end

	local input = {
		Move = move,
		Look = forward,
		FaceCamera = gameSettings.RotationType == Enum.RotationType.CameraRelative,
	}

	for actionName in InputConfig.actions do
		input[actionName] = LocalInput.GetState(actionName)
	end

	cached = {
		time = now,
		input = input,
	}

	return input
end

return LocalInput
