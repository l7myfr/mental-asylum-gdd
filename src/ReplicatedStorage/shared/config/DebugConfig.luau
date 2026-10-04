return {
	hitboxes = {
		enabledByDefault = false,
		folderName = "HitboxDebug",
		contextName = "DebugContext",
		contextPriority = 3000,
		toggleAction = "ToggleHitboxes",
		toggleKeys = { Enum.KeyCode.B },
		hurtboxPart = "HumanoidRootPart",
		evasionWeapon = "Dagger",
		entityTag = "Entity",
		alwaysOnTop = false,

		hitbox = {
			windupColor = Color3.fromRGB(255, 200, 60),
			activeColor = Color3.fromRGB(255, 50, 50),
			windupTransparency = 0.8,
			activeTransparency = 0.45,
		},

		-- Bigger dodge-detection box; drawn around the attack hitbox.
		evadeBox = {
			color = Color3.fromRGB(60, 230, 230),
			windupTransparency = 0.92,
			activeTransparency = 0.8,
		},

		hurtbox = {
			color = Color3.fromRGB(60, 255, 120),
			invulnerableColor = Color3.fromRGB(80, 200, 255),
			transparency = 0.7,
		},
	},
}
