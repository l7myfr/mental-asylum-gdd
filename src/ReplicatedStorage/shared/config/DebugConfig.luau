return {
	-- Logs swing/dodge requests on the client and the server's verdict, to compare counts.
	validation = {
		logEnabled = true,
		prefix = "[Validation]",
	},

	-- Server-side root position (streamed) next to the locally rendered root, per character.
	positions = {
		enabledByDefault = true,
		sendRate = 1 / 20,
		folderName = "PositionDebug",
		contextName = "PositionDebugContext",
		contextPriority = 3000,
		toggleAction = "TogglePositions",
		toggleKeys = { Enum.KeyCode.F3 },
		entityTag = "Entity",
		rootName = "HumanoidRootPart",
		alwaysOnTop = true,
		transparency = 0.5,
		serverColor = Color3.fromRGB(255, 60, 60),
		clientColor = Color3.fromRGB(60, 200, 255),
	},

	-- A button that launches every player's character at once, to compare replication side by side.
	launchTest = {
		enabled = true,
		velocity = Vector3.new(70, 45, 0),
		buttonText = "Launch all players",
		buttonSize = UDim2.fromOffset(200, 44),
		buttonPosition = UDim2.new(0.5, 0, 1, -80),
	},

	hitboxes = {
		enabledByDefault = true,
		folderName = "HitboxDebug",
		contextName = "DebugContext",
		contextPriority = 3000,
		toggleAction = "ToggleHitboxes",
		toggleKeys = { Enum.KeyCode.F2 },
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

		hurtbox = {
			color = Color3.fromRGB(60, 255, 120),
			invulnerableColor = Color3.fromRGB(80, 200, 255),
			transparency = 0.7,
		},
	},
}
