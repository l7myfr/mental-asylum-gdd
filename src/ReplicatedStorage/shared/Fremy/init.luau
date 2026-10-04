local Registry = require(script.Registry)
local Loader = require(script.Loader)
local Lifecycle = require(script.Lifecycle)
local Dispatcher = require(script.Dispatcher)
local Networking = require(script.Networking)
local Objector = require(script.Exstentions.Objector)
local DataStore = require(script.Exstentions.DataStore)

local Framework = {}
Framework.__index = Framework

Framework.Maid = require(script.Util.Maid)
Framework.Signal = require(script.Util.Signal)

function Framework.new()
	return setmetatable({
		Registry = Registry.new(),
		Loaded = {},
	}, Framework)
end

function Framework:Start(folder)
	self.Loaded = Loader.LoadFolder(folder, self.Registry)

	Objector.Init(self.Loaded)
	Lifecycle.InjectDependencies(self.Loaded, self.Registry)
	Networking.Init(self.Loaded)
	DataStore.Init(self.Loaded)
	Lifecycle.InitAll(self.Loaded)
	Lifecycle.StartAll(self.Loaded)

	Dispatcher.Init(self.Loaded)
end

function Framework:Get(name)
	return self.Registry:Get(name)
end

return Framework
