local Loader = {}

function Loader.LoadFolder(folder, registry)
	assert(typeof(folder) == "Instance", "Loader.LoadFolder expected an Instance.")
	assert(registry, "Loader.LoadFolder expected a registry instance.")

	local loaded = {}

	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, object = pcall(require, child)

			if not ok then
				error(("Loader failed to require '%s': %s"):format(child:GetFullName(), tostring(object)))
			end

			if type(object) ~= "table" then
				error(("Module '%s' did not return a table."):format(child:GetFullName()))
			end

			object.Name = object.Name or child.Name

			registry:Register(object.Name, object)
			table.insert(loaded, object)
		elseif child:IsA("Folder") then
			local nested = Loader.LoadFolder(child, registry)

			for _, object in nested do
				table.insert(loaded, object)
			end
		end
	end

	return loaded
end

return Loader
