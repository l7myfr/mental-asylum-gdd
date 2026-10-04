local config = {
	suffix = "_Mirrored",
	mirroredPairs = {
		{ "Left Arm", "Right Arm" },
		{ "Left Leg", "Right Leg" },
	},
}

local swapNames = {}
for _, pair in config.mirroredPairs do
	swapNames[pair[1]] = pair[2]
	swapNames[pair[2]] = pair[1]
end

local function mirrorCFrame(cframe: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cframe:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function mirrorPose(pose: Pose)
	pose.CFrame = mirrorCFrame(pose.CFrame)
	pose.Name = swapNames[pose.Name] or pose.Name
end

local KeyframeSequenceMirror = {}

function KeyframeSequenceMirror.mirror(sequence: KeyframeSequence): KeyframeSequence
	local mirrored = sequence:Clone()
	mirrored.Name = sequence.Name .. config.suffix

	for _, descendant in mirrored:GetDescendants() do
		if descendant:IsA("Pose") then
			mirrorPose(descendant)
		end
	end

	return mirrored
end

return KeyframeSequenceMirror
