local Lifecycle = {}

function Lifecycle.InjectDependencies(objects, registry)
	for _, object in objects do
		if object.Dependencies then
			for fieldName, dependencyName in object.Dependencies do
				if not registry:Has(dependencyName) then
					error(("'%s' declares dependency '%s' which is not registered.")
						:format(object.Name or "?", dependencyName))
				end

				object[fieldName] = registry:Get(dependencyName)
			end
		end
	end
end

function Lifecycle.InitAll(objects)
	for _, object in objects do
		if object.init then
			object:init()
		end
	end
end

function Lifecycle.StartAll(objects)
	for _, object in objects do
		if object.Start then
			task.spawn(object.Start, object)
		end
	end
end

return Lifecycle
