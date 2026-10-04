local ReplicatedStorage = game:GetService("ReplicatedStorage")

local animations = ReplicatedStorage:WaitForChild("assets"):WaitForChild("animations")

return {
	folder = animations:WaitForChild("movement"),
	allowedRoots = { animations },
	stopForeignTracks = true,
	characterLoadTimeout = 10,
	entityTag = "Entity",

	blendInSpeed = 3,
	remoteSpeedSharpness = 12,
	minimumWeight = 0.001,
	weightSpring = {
		damping = 1,
		speed = 14,
	},

	locomotion = {
		idle = {
			animation = "idle",
			priority = Enum.AnimationPriority.Movement,
		},
		walk = {
			animation = "walk",
			priority = Enum.AnimationPriority.Movement,
			referenceSpeed = 12,
			minimumPlaybackSpeed = 0.6,
			maximumPlaybackSpeed = 1.5,
		},
		run = {
			animation = "run",
			priority = Enum.AnimationPriority.Movement,
			referenceSpeed = 24,
			minimumPlaybackSpeed = 0.7,
			maximumPlaybackSpeed = 1.4,
		},
	},

	airborne = {
		jump = {
			animation = "jump",
			priority = Enum.AnimationPriority.Action,
			fadeTime = 0.08,
			fadeOutTime = 0.2,
			speed = 1,
		},
		fall = {
			animation = "fall",
			priority = Enum.AnimationPriority.Action,
			fadeTime = 0.3,
			fadeOutTime = 0.15,
			speed = 1,
			delay = 0.25,
		},
		land = {
			animation = "land",
			priority = Enum.AnimationPriority.Action,
			fadeTime = 0.05,
			speed = 1,
			minimumAirTime = 0.3,
		},
	},

	dodge = {
		priority = Enum.AnimationPriority.Action2,
		fadeTime = 0.05,
		fadeOutTime = 0.15,
		renderWindow = 0.5,
	},
}
