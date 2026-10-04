return {
	simulation = {
		priority = 100,
	},

	walkSpeed = 12,
	runSpeed = 24,
	inputDeadzone = 0.1,
	stopThreshold = 0.05,
	steerDistance = 4,
	turnSpeed = math.rad(900),
	airControl = 0.4,

	acceleration = {
		walk = 24,
		run = 16,
	},

	deceleration = {
		slowdown = 20,
		stop = 34,
	},

	facing = {
		driverName = "FacingAlign",
		attachmentName = "FacingAttachment",
		moveSharpness = 14,
		cameraSharpness = 16,
		dodgeSharpness = 30,
	},

	dodge = {
		cooldown = 1.1,
		duration = 0.4,
		speed = 72,
		endSpeed = 8,
		easing = 2,
		animationSpeed = 1,
		minimumInputDot = 0.35,
		fallback = "back",
		requiresGround = true,

		directions = {
			back = {
				vector = Vector3.new(0, 0, 1),
				animation = "dodgeback",
				duration = 0.4,
				animationSpeed = 0.6,
			},
			left = {
				vector = Vector3.new(-1, 0, 0),
				animation = "dodgeleft",
				animationSpeed = 1,
			},
			right = {
				vector = Vector3.new(1, 0, 0),
				animation = "dodgeright",
				animationSpeed = 1,
			},
		},
	},

	-- While staggered (after having a swing evaded) a character can't dodge and moves slower.
	stagger = {
		moveMultiplier = 0.5,
	},

	removedCharacterChildren = { "Animate" },
	removedChildTimeout = 5,

	attributes = {
		speed = "MoveSpeed",
		heading = "MoveHeading",
		facing = "Facing",
		sprinting = "Sprinting",
		dodge = "Dodge",
		dodgeStart = "DodgeStart",
		dodgeDirection = "DodgeDirection",
		dodgeFacing = "DodgeFacing",
		dodgeReady = "DodgeReady",
		dodgeHeld = "DodgeHeld",
		staggerStart = "StaggerStart",
		staggerEnd = "StaggerEnd",
	},
}
