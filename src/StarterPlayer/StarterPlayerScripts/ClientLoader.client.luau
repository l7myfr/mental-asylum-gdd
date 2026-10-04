local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fremy = require(ReplicatedStorage.shared.Fremy)

local Client = Fremy.new()
Fremy.Instance = Client

Client:Start(ReplicatedStorage.client.controllers)