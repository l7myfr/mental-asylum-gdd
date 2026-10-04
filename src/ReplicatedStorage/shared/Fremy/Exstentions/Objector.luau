local CollectionService = game:GetService("CollectionService")

local Objector = {}

local function isIgnored(instance, ignoreTable)
	if not ignoreTable then
		return false
	end

	for _, ignoredInstance in ignoreTable do
		if instance == ignoredInstance or instance:IsDescendantOf(ignoredInstance) then
			return true
		end
	end

	return false
end

local function linkObject(self, callback, tagName, removedCallback, ignoreTable)
	assert(type(callback) == "function", "LinkObject expected a function as callback.")
	assert(type(tagName) == "string", "LinkObject expected a string as tagName.")

	for _, instance in CollectionService:GetTagged(tagName) do
		if not isIgnored(instance, ignoreTable) then
			callback(instance)
		end
	end

	local addedConn = CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
		if not isIgnored(instance, ignoreTable) then
			callback(instance)
		end
	end)

	local removedConn

	if removedCallback then
		removedConn = CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
			if not isIgnored(instance, ignoreTable) then
				removedCallback(instance)
			end
		end)
	end

	return addedConn, removedConn
end

function Objector.Init(objects)
	for _, object in objects do
		object.LinkObject = linkObject
	end
end

return Objector
