local Registry = {}
Registry.__index = Registry

function Registry.new()
	return setmetatable({
		Objects = {},
	}, Registry)
end

function Registry:Register(name : string, object)
	assert(type(name) == "string", "Registry:Register expected string name.")
	assert(type(object) == "table", "Registry:Register expected table.")

	if self.Objects[name] then
		error(("'%s' is already registered."):format(name))
	end

	self.Objects[name] = object
end

function Registry:Get(name)
	local object = self.Objects[name]

	if not object then
		error(("'%s' is not registered."):format(name))
	end

	return object
end

function Registry:Has(name)
	return self.Objects[name] ~= nil
end

function Registry:GetAll()
	return self.Objects
end

function Registry:Iterate()
	return next, self.Objects
end

return Registry
