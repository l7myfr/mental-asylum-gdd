local ServerStorage = game:GetService("ServerStorage")

local templates = ServerStorage:WaitForChild("assets"):WaitForChild("dummies")

return {
	folderName = "Dummies",
	tag = "Entity",

	dummies = {
		DodgeDummy = {
			template = templates:WaitForChild("DodgeDummy"),
			spawn = CFrame.new(-12, 4, -12),
			respawnDelay = 3,
			behaviour = "Dodge",
		},
		SmartDummy = {
			template = templates:WaitForChild("DodgeDummy"),
			spawn = CFrame.new(-30, 4, -12),
			respawnDelay = 3,
			behaviour = "Smart",
			melee = "Dagger",
		},
	},

	behaviours = {
		Dodge = {
			interval = 1.3,
			sequence = { "left", "right", "back" },
			homeRadius = 2,
			homeStrength = 0.6,
			faceNearestPlayer = true,
			sightRange = 80,
		},

		Smart = {
			sightRange = 90,
			leashRadius = 45,
			homeRadius = 2,
			dangerMargin = 1,
			retreatSprint = false,
			dodgeChance = 0.5,
			commitToAttack = true,

			reactionTime = {
				min = 0.12,
				max = 0.28,
			},

			predict = {
				enabled = true,
				lookahead = 0.15,
				minClosingSpeed = 6,
				chance = 0.3,
			},

			spacing = {
				min = 4,
				max = 8,
				cooldownMin = 7,
				cooldownSprint = false,
				sprintBeyond = 24,
				strafeStrength = 0.6,
				wallCheck = 4,
				strafeSwitch = {
					min = 1,
					max = 2.4,
				},
			},

			attack = {
				enabled = true,
				aggression = 0.65,
				reachPadding = 0.3,
				hesitation = {
					min = 0.2,
					max = 0.5,
				},
				maxCombo = 2,
				engageDistance = 4.5,
				recover = {
					min = 0.7,
					max = 1.4,
				},
				respectDodge = true,
			},

			dodgeScoring = {
				wallMargin = 1,
				wallPenalty = 100,
				lateralBias = 0.6,
				randomness = 0.5,
			},
		},
	},
}
