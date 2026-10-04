local Connection = {}
Connection.__index = Connection

function Connection.new(signal, callback)
	return setmetatable({
		_signal = signal,
		_callback = callback,
		Connected = true,
	}, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end

	self.Connected = false

	local connections = self._signal._connections

	for index, connection in connections do
		if connection == self then
			table.remove(connections, index)
			break
		end
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_connections = {},
	}, Signal)
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expected a function.")

	local connection = Connection.new(self, callback)
	table.insert(self._connections, connection)

	return connection
end

function Signal:Fire(...)
	local connections = table.clone(self._connections)

	for _, connection in connections do
		if connection.Connected then
			task.spawn(connection._callback, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection

	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

function Signal:Destroy()
	self._connections = {}
end

return Signal
