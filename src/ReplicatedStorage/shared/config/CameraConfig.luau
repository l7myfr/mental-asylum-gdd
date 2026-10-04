return {
	renderStepName = "CharacterCameraFocus",
	focusName = "CameraFocus",
	subjectPart = "Head",
	baseOffset = Vector3.new(0, 1.5, 0),
	influence = Vector3.new(1, 1, 1),
	maxOffset = 4,

	headSpring = {
		damping = 1,
		speed = 10,
	},

	mouseLock = {
		offset = Vector3.new(1.75, 0, 0),
		damping = 1,
		speed = 9,
	},
}
