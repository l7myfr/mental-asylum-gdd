local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.shared.config.DebugConfig)

local settings = DebugConfig.positions

local PositionDebugService = {}

PositionDebugService.Remotes = {
	Position = "Unreliable",
}

PositionDebugService.Elapsed = 0

function PositionDebugService:Send(character, sent)
	local root = character and character:FindFirstChild(settings.rootName)

	if root and not sent[character] then
		sent[character] = true
		self.Remotes.Position:FireAll(character, root.CFrame)
	end
end

function PositionDebugService:Update(deltaTime)
	self.Elapsed += deltaTime

	if self.Elapsed < settings.sendRate then
		return
	end

	self.Elapsed = 0

	local sent = {}

	for _, player in Players:GetPlayers() do
		self:Send(player.Character, sent)
	end

	for _, character in CollectionService:GetTagged(settings.entityTag) do
		self:Send(character, sent)
	end
end

return PositionDebugService
