return {
	config = {
		CHECK_NEW_VERSION = false,
		WARNING_SEVERITY = "LOW",
		PLAYER_REPLICATION = "AUTOMATIC",
	},

	entityTypes = {
		PLAYER = {
			BUFFER = 0,
			TICK_RATE = 1 / 30,
			MODEL_REPLICATION_MODE = "NATIVE",
			HALF_TICK_DISTANCE = math.huge,
			ASSEMBLY_ROOT_PART_CHECK = true,
		},
		NPC = {
			BUFFER = 0,
			TICK_RATE = 1 / 30,
			STORE_SNAPSHOTS = true,
			MODEL_REPLICATION_MODE = "NATIVE",
			HALF_TICK_DISTANCE = math.huge,
			ASSEMBLY_ROOT_PART_CHECK = true,
		},
	},

	npcEntityType = "NPC",

	lagCompensation = {
		maxRewind = 0.6,
		defaultViewDelay = 0.12,
		sampleInterval = 1 / 30,
		resolveBuffer = 0.08,
		viewRange = 60,
	},

	validation = {
		maxLatency = 0.6,
		cooldownTolerance = 0.08,
	},

	speedCheck = {
		enabled = true,
		priority = 100,
		maxHorizontalSpeed = 60,
		maxStrikes = 6,
		strikeDecay = 0.5,
	},
}
