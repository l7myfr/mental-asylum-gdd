local Players = game:GetService("Players")

local RunService = game:GetService("RunService")

local Dispatcher = {}

local function BroadcastTo(objects, methodName, ...)
	for _, object in objects do
		local method = object[methodName]

		if method then
			task.spawn(method, object, ...)
		end
	end
end

function Dispatcher.Init(objects)
	local function hookCharacter(player)
		player.CharacterAdded:Connect(function(character)
			if RunService:IsClient() and player == Players.LocalPlayer then
				BroadcastTo(objects, "LocalCharacterAdded", player, character)
			end
			BroadcastTo(objects, "CharacterAdded", player, character)
		end)

		player.CharacterRemoving:Connect(function(character)
			if RunService:IsClient() and player == Players.LocalPlayer then
				BroadcastTo(objects, "LocalCharacterRemoving", player, character)
			end
			BroadcastTo(objects, "CharacterRemoving", player, character)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		BroadcastTo(objects, "PlayerAdded", player)
		hookCharacter(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		BroadcastTo(objects, "PlayerRemoving", player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(BroadcastTo, objects, "PlayerAdded", player)
		hookCharacter(player)

		if player.Character then
			task.spawn(BroadcastTo, objects, "CharacterAdded", player, player.Character)
		end
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		BroadcastTo(objects, "Update", deltaTime)
	end)
end

return Dispatcher
