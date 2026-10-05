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

	-- Shown to a player when they evade a hit: a flash on their character and a rising label.
	evadeFeedback = {
		text = "EVADED",
		color = Color3.fromRGB(255, 220, 60),
		offset = Vector3.new(0, 3, 0),
		rise = 2,
		duration = 0.6,
		size = UDim2.fromOffset(160, 40),
	},

	-- Shown on a staggered character to everyone: a tint for the stagger's duration and a rising label.
	staggerFeedback = {
		text = "STAGGERED",
		color = Color3.fromRGB(170, 110, 255),
		offset = Vector3.new(0, 3, 0),
		rise = 2,
		duration = 0.6,
		size = UDim2.fromOffset(200, 40),
		fillTransparency = 0.55,
		outlineTransparency = 0.1,
	},

	-- An attack press is remembered this long and fires as soon as an attack is allowed.
	inputBuffer = 0.2,

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
		attackBuffer = "AttackBuffer",
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

			-- Bigger box that only detects dodges: a target dodging anywhere inside it while the swing is
			-- active evades it (and staggers the attacker), even if it already left the damage hitbox.
			evadeHitbox = {
				size = Vector3.new(9, 7, 10),
				offset = CFrame.new(0, 0, -4),
			},

			dodgeEvasion = {
				invulnerable = true,
				-- Invulnerability lasts the whole dodge movement (0.34-0.4s). Set iframes (seconds from the
				-- dodge start) to make it shorter or longer than the movement.
				iframes = 0.7,
				consumesSwing = true,
				-- A swing that gets evaded staggers the attacker for this long.
				staggerDuration = 0.4,
				hitboxScale = 0.35,
			},

			backstab = {
				multiplier = 2,
				minimumDot = 0.4,
			},

			attacks = {
				swing1 = {
					animation = "swing1",
					animationSpeed = 1,
					duration = 0.45,
					hitStart = 0.22,
					hitEnd = 0.38,
					damage = 20,
				},
				swing2 = {
					animation = "swing2",
					animationSpeed = 1,
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
				-- How late after a swing ends it may still start playing on other clients. It covers
				-- network delay plus the difference between two clients' server-time estimates.
				renderSlack = 1,
				-- Most a remote swing animation is skipped ahead to make up for network delay.
				maxCatchUp = 0.25,
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
				-- Both characters' animations freeze briefly when a hit lands.
				hitStop = {
					duration = 0.07,
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
