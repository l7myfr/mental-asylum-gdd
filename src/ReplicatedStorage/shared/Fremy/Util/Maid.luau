local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({
		Tasks = {},
	}, Maid)
end

function Maid._cleanupTask(task)
	local taskType = typeof(task)

	if taskType == "function" then
		task()
	elseif taskType == "RBXScriptConnection" then
		task:Disconnect()
	elseif taskType == "Instance" then
		task:Destroy()
	elseif taskType == "table" then

		if task.Destroy then
			task:Destroy()
		elseif task.Disconnect then
			task:Disconnect()
		end
	end
end

function Maid:GiveTask(task)
	assert(task ~= nil, "Maid:GiveTask expected a task.")

	local id = #self.Tasks + 1
	self.Tasks[id] = task

	return id
end

function Maid:RemoveTask(id)
	local task = self.Tasks[id]

	if task then
		self.Tasks[id] = nil
		Maid._cleanupTask(task)
	end
end

function Maid:DoCleaning()
	local tasks = self.Tasks
	self.Tasks = {}

	for _, task in tasks do
		Maid._cleanupTask(task)
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid
