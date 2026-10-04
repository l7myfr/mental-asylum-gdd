return {
	contextName = "GameplayContext",
	priority = 2000,
	sink = true,

	actions = {
		Sprint = {
			type = Enum.InputActionType.Bool,
			bindings = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
		},
		Dodge = {
			type = Enum.InputActionType.Bool,
			bindings = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB },
		},
		Attack = {
			type = Enum.InputActionType.Bool,
			bindings = { Enum.KeyCode.MouseLeftButton, Enum.KeyCode.ButtonR2 },
		},
	},

	moveSource = { "StarterPlayer", "PlayerModule", "InputContexts", "CharacterContext", "MoveAction" },
	sourceTimeout = 10,

	rebindTimeout = 10,
	rebinds = {
		shiftLock = {
			targets = {
				{ "StarterPlayer", "PlayerModule", "InputContexts", "CameraContext", "MouseLockSwitchAction" },
			},
			bindings = {
				KeyboardPrimaryBinding = Enum.KeyCode.LeftControl,
				KeyboardSecondaryBinding = Enum.KeyCode.RightControl,
			},
		},
	},
}
