local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Fremy = require(ReplicatedStorage.shared.Fremy)

local Server = Fremy.new()
Fremy.Instance = Server

Server:Start(ServerStorage.server.services)