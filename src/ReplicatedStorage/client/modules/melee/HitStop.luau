local HitStop = {}

-- [track] = { speed, releaseAt }
local frozen = {}

-- Freezes every animation playing on the character for a moment, which gives hits weight.
function HitStop.Apply(character, duration)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return
	end

	local releaseAt = os.clock() + duration

	for _, track in animator:GetPlayingAnimationTracks() do
		local entry = frozen[track]

		if entry then
			entry.releaseAt = math.max(entry.releaseAt, releaseAt)
		else
			frozen[track] = {
				speed = track.Speed,
				releaseAt = releaseAt,
			}
			track:AdjustSpeed(0)
		end
	end
end

function HitStop.Update()
	local clock = os.clock()

	for track, entry in frozen do
		if clock >= entry.releaseAt then
			frozen[track] = nil

			if track.IsPlaying then
				track:AdjustSpeed(entry.speed)
			end
		end
	end
end

return HitStop
