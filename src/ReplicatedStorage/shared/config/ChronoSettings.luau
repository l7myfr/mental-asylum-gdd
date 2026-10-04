return {
	config = {
		CHECK_NEW_VERSION = false,
		-- LOW also prints idle/respawn interpolation notices that are expected.
		WARNING_SEVERITY = "MEDIUM",
		PLAYER_REPLICATION = "AUTOMATIC",
		-- Chrono's docs: buffer ~2x the snapshot interval (33ms at 60Hz), max 2-3x the minimum.
		-- The buffer still grows dynamically up to MAX_BUFFER for jittery connections.
		MIN_BUFFER = 0.035,
		MAX_BUFFER = 0.105,
	},

	entityTypes = {
		PLAYER = {
			BUFFER = 0,
			TICK_RATE = 1 / 60,
			-- Turns off Roblox's physics replication so other clients only see Chrono's interpolation.
			MODEL_REPLICATION_MODE = "NATIVE_WITH_LOCK",
			HALF_TICK_DISTANCE = math.huge,
			ASSEMBLY_ROOT_PART_CHECK = true,
		},
		NPC = {
			BUFFER = 0,
			TICK_RATE = 1 / 60,
			STORE_SNAPSHOTS = true,
			-- Dummies are moved by server-side Humanoid physics, which a locked root would freeze.
			MODEL_REPLICATION_MODE = "NATIVE",
			HALF_TICK_DISTANCE = math.huge,
			ASSEMBLY_ROOT_PART_CHECK = true,
		},
	},

	npcEntityType = "NPC",

	lagCompensation = {
		maxRewind = 0.6,
		defaultViewDelay = 0.12,
		sampleInterval = 1 / 60,
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
