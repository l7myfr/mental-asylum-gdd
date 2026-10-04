local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.shared.utils.Clock)

local Stepper = {}

local steps = {}
local ordered = {}
local connection = nil

local function rebuild()
	ordered = {}

	for _, step in steps do
		table.insert(ordered, step)
	end

	table.sort(ordered, function(a, b)
		return a.priority < b.priority
	end)
end

local function run(deltaTime)
	local now = Clock.Now()

	for _, step in ordered do
		step.callback(deltaTime, now)
	end
end

function Stepper.Bind(name, priority, callback)
	steps[name] = {
		priority = priority,
		callback = callback,
	}

	rebuild()

	if not connection then
		connection = RunService.PreSimulation:Connect(run)
	end
end

function Stepper.Unbind(name)
	steps[name] = nil
	rebuild()
end

return Stepper
