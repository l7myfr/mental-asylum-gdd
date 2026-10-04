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
			leashRadius = 60,
			homeRadius = 2,

			-- It sees the target as it was this long ago (a human reaction time), re-rolled every decision,
			-- so it reacts late, can be baited, and is fooled by sudden direction changes.
			reactionTime = {
				min = 0.17,
				max = 0.3,
			},
			-- How often it re-thinks its plan; inputs are held in between, like a person's would be.
			decisionInterval = {
				min = 0.1,
				max = 0.22,
			},
			memoryLength = 1,

			-- Willingness to commit. Being ahead on health makes it bolder, being behind makes it careful.
			mood = {
				aggression = 0.55,
				healthInfluence = 0.5,
				minimum = 0.15,
				maximum = 0.9,
			},

			spacing = {
				min = 5,
				preferred = 7.5,
				-- Keeps further away while its own dodge is recharging.
				cooldownPreferred = 10,
				strafeStrength = 0.7,
				strafeSwitch = {
					min = 0.6,
					max = 1.8,
				},
				wallCheck = 4,
				-- Per neutral decision: step in to draw out a swing, then back off.
				baitChance = 0.2,
				baitDuration = {
					min = 0.25,
					max = 0.45,
				},
				sprintBeyond = 16,
			},

			engage = {
				-- Time spent circling before committing to an attack, longer when it feels cautious.
				patience = {
					min = 0.6,
					max = 2.2,
				},
				reachPadding = 0.3,
				combo = {
					min = 1,
					max = 3,
				},
				-- Sometimes swings slightly out of range, like a mistimed attack.
				whiffChance = 0.08,
				whiffReach = 2,
				respectDodge = true,
				strafeStrength = 0.25,
				-- Stops chasing a target it cannot catch.
				giveUpTime = 2.5,
			},

			punish = {
				-- How often it notices and takes an opening (dodge on cooldown, swing that just ended).
				chance = 0.75,
				recoveryWindow = 0.35,
			},

			-- Backs off for this long after finishing a combo.
			recover = {
				min = 0.35,
				max = 0.9,
			},

			defense = {
				dodgeChance = 0.6,
				dangerMargin = 1,
				-- Dodges a fast approach even without a swing coming (a misread).
				panicDodgeChance = 0.12,
				panicClosingSpeed = 14,
				-- After dodging a swing, goes straight for the punish.
				counterChance = 0.7,
				retreatSprint = false,
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
