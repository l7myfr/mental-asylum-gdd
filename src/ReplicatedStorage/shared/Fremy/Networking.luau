local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local isserver = RunService:IsServer()

local Networking = {}

local remotesFolder

local function getRemotesFolder()
	if remotesFolder then
		return remotesFolder
	end

	if isserver then
		remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

		if not remotesFolder then
			remotesFolder = Instance.new("Folder")
			remotesFolder.Name = "Remotes"
			remotesFolder.Parent = ReplicatedStorage
		end
	else
		remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	end

	return remotesFolder
end

local function getServiceFolder(serviceName)
	local root = getRemotesFolder()
	if isserver then
		local folder = root:FindFirstChild(serviceName)

		if not folder then
			folder = Instance.new("Folder")
			folder.Name = serviceName
			folder.Parent = root
		end

		return folder
	else
		return root:WaitForChild(serviceName)
	end
end

local function WrapEvent(instance)
	local wrapper = {}

	if isserver then
		function wrapper:Fire(player, ...)
			instance:FireClient(player, ...)
		end

		function wrapper:FireAll(...)
			instance:FireAllClients(...)
		end

		function wrapper:FireExcept(excludedPlayer, ...)
			for _, player in Players:GetPlayers() do
				if player ~= excludedPlayer then
					instance:FireClient(player, ...)
				end
			end
		end

		function wrapper:Connect(callback)
			return instance.OnServerEvent:Connect(callback)
		end
	else
		function wrapper:Fire(...)
			instance:FireServer(...)
		end

		function wrapper:Connect(callback)
			return instance.OnClientEvent:Connect(callback)
		end
	end

	return wrapper
end

local function WrapFunction(instance)
	local wrapper = {}

	if isserver then
		function wrapper:SetCallback(callback)
			instance.OnServerInvoke = callback
		end
		function wrapper:Invoke(player, ...)
			return instance:InvokeClient(player,...)
		end
	else
		function wrapper:SetCallback(callback)
			instance.OnClientInvoke = callback
		end
		function wrapper:Invoke(...)
			return instance:InvokeServer(...)
		end
	end

	return wrapper
end

local wrapperCache = {}

function Networking.Init(objects)
	for _, object in objects do
		local declarations = object.Remotes

		if declarations then
			local serviceName = object.Namespace or object.Name
			local folder = getServiceFolder(serviceName)
			local wrapped = {}

			for remoteName, remoteType in declarations do
				local cacheKey = serviceName .. "." .. remoteName
				local wrapper = wrapperCache[cacheKey]

				if not wrapper then
					local instance

					if isserver then
						instance = folder:FindFirstChild(remoteName)

						if not instance then
							instance = Instance.new(remoteType == "Function" and "RemoteFunction" or "RemoteEvent")
							instance.Name = remoteName
							instance.Parent = folder
						end
					else
						instance = folder:WaitForChild(remoteName)
					end

					wrapper = (remoteType == "Function") and WrapFunction(instance) or WrapEvent(instance)
					wrapperCache[cacheKey] = wrapper
				end

				wrapped[remoteName] = wrapper
			end

			object.Remotes = wrapped
		end
	end
end

return Networking
