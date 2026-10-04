local DataStoreService = game:GetService("DataStoreService")

local DataStore = {}

local storeCache = {}

local function attempt(callback, ...)
	local args = {...}
	local success, result

	for attemptIndex = 1, 5 do
		success, result = pcall(callback, table.unpack(args))

		if success then
			return true, result
		end

		task.wait(attemptIndex * 0.5)
	end

	return false, result
end

local function WrapStore(instance)
	local wrapper = {}

	function wrapper:Get(key, default)
		local success, value = attempt(function()
			return instance:GetAsync(key)
		end)

		if not success then
			warn(("DataStore failed to get '%s': %s"):format(key, tostring(value)))
			return default
		end

		if value == nil then
			return default
		end

		return value
	end

	function wrapper:Set(key, value)
		local success, err = attempt(function()
			instance:SetAsync(key, value)
		end)

		if not success then
			warn(("DataStore failed to set '%s': %s"):format(key, tostring(err)))
		end

		return success
	end

	function wrapper:Update(key, transformFunction)
		assert(type(transformFunction) == "function", "DataStore:Update expected a function.")

		local success, err = attempt(function()
			instance:UpdateAsync(key, transformFunction)
		end)

		if not success then
			warn(("DataStore failed to update '%s': %s"):format(key, tostring(err)))
		end

		return success
	end

	function wrapper:Increment(key, delta)
		local success, result = attempt(function()
			return instance:IncrementAsync(key, delta or 1)
		end)

		if not success then
			warn(("DataStore failed to increment '%s': %s"):format(key, tostring(result)))
		end

		return success, result
	end

	function wrapper:Remove(key)
		local success, err = attempt(function()
			instance:RemoveAsync(key)
		end)

		if not success then
			warn(("DataStore failed to remove '%s': %s"):format(key, tostring(err)))
		end

		return success
	end

	return wrapper
end

function DataStore.GetStore(name, scope)
	local cacheKey = scope and (name .. "." .. scope) or name
	local wrapper = storeCache[cacheKey]

	if wrapper then
		return wrapper
	end

	local instance = scope and DataStoreService:GetDataStore(name, scope) or DataStoreService:GetDataStore(name)
	wrapper = WrapStore(instance)
	storeCache[cacheKey] = wrapper

	return wrapper
end

function DataStore.GetOrderedStore(name, scope)
	local cacheKey = "ordered." .. (scope and (name .. "." .. scope) or name)
	local wrapper = storeCache[cacheKey]

	if wrapper then
		return wrapper
	end

	local instance = scope and DataStoreService:GetOrderedDataStore(name, scope) or DataStoreService:GetOrderedDataStore(name)
	wrapper = WrapStore(instance)
	storeCache[cacheKey] = wrapper

	return wrapper
end

function DataStore.Init(objects)
	for _, object in objects do
		local declarations = object.Stores

		if declarations then
			local wrapped = {}

			for storeName, storeInfo in declarations do
				if type(storeInfo) == "table" then
					wrapped[storeName] = storeInfo.Ordered
						and DataStore.GetOrderedStore(storeInfo.Name or storeName, storeInfo.Scope)
						or DataStore.GetStore(storeInfo.Name or storeName, storeInfo.Scope)
				else
					wrapped[storeName] = DataStore.GetStore(storeInfo)
				end
			end

			object.Stores = wrapped
		end
	end
end

return DataStore
