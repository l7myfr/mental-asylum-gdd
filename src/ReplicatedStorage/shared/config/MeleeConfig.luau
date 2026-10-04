local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = ReplicatedStorage:WaitForChild("assets")
local models = assets:WaitForChild("models"):WaitForChild("melee")
local animations = assets:WaitForChild("animations"):WaitForChild("tools")

return {
	simulation = {
		priority = 200,
	},

	-- Hit effects are played as soon as the client detects a hit, then kept or cancelled once the
	-- server confirms the swing. Unconfirmed predictions are cancelled after confirmTimeout.
	prediction = {
		confirmTimeout = 3,
		cancelFadeOut = 0.1,
	},

	starterMelee = "Dagger",
	characterLoadTimeout = 10,
	entityTag = "Entity",

	attributes = {
		melee = "Melee",
		attack = "Attack",
		attackStart = "AttackStart",
		attackId = "AttackId",
		combo = "Combo",
		attackReady = "AttackReady",
		attackHeld = "AttackHeld",
	},

	weapons = {
		Dagger = {
			class = "Dagger",
			model = models:WaitForChild("Dagger"),
			animations = animations:WaitForChild("dagger"),

			grip = {
				limb = "Right Arm",
				joint = "HandleRight",
				c0 = CFrame.new(0, -1, 0),
				c1 = CFrame.identity,
			},

			holdToAttack = true,
			canAttackWhileDodging = false,
			comboResetTime = 0.8,
			combo = { "swing1", "swing2" },

			hitbox = {
				size = Vector3.new(5, 6, 6),
				offset = CFrame.new(0, 0, -3),
				maxTargets = 4,
			},

			dodgeEvasion = {
				invulnerable = true,
				grace = 0.1,
				-- A dodge started up to this long after being hit cancels the hit. Damage is held this long.
				reactionWindow = 0.15,
				consumesSwing = true,
				hitboxScale = 0.35,
			},

			backstab = {
				multiplier = 2,
				minimumDot = 0.4,
			},

			attacks = {
				swing1 = {
					animation = "swing1",
					animationSpeed = 1.15,
					duration = 0.45,
					hitStart = 0.22,
					hitEnd = 0.38,
					damage = 20,
				},
				swing2 = {
					animation = "swing2",
					animationSpeed = 1.15,
					duration = 0.45,
					hitStart = 0.24,
					hitEnd = 0.38,
					damage = 20,
				},
				running = {
					animation = "kniferunningattack",
					animationSpeed = 1.2,
					duration = 0.7,
					hitStart = 0.26,
					hitEnd = 0.5,
					damage = 30,
				},
			},

			animation = {
				priority = Enum.AnimationPriority.Action3,
				fadeTime = 0.06,
				fadeOutTime = 0.15,
				renderSlack = 0.25,
			},

			effects = {
				hitFlash = {
					color = Color3.fromRGB(255, 70, 70),
					evadedColor = Color3.fromRGB(255, 220, 60),
					fillStart = 0.35,
					outlineStart = 0.1,
					damping = 1,
					speed = 9,
				},
				attackerShake = {
					magnitude = 1.2,
					roughness = 8,
					fadeIn = 0,
					fadeOut = 0.25,
				},
				victimShake = {
					magnitude = 3,
					roughness = 10,
					fadeIn = 0,
					fadeOut = 0.4,
				},
			},
		},
	},
}
