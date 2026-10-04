local ContentProvider = game:GetService("ContentProvider")

local AnimationTracks = {}
AnimationTracks.__index = AnimationTracks

function AnimationTracks.Preload(roots)
	local animations = {}

	for _, root in roots do
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("Animation") then
				table.insert(animations, descendant)
			end
		end
	end

	ContentProvider:PreloadAsync(animations)
end

function AnimationTracks.new(animator)
	return setmetatable({
		Animator = animator,
		Cache = {},
	}, AnimationTracks)
end

-- Only tracks this object loaded are used. Looking tracks up on the Animator can return the copy Roblox
-- replicates from another player's client, which replication also drives, so local Stop/Play on it
-- is unreliable (remote swings would sometimes not play).
function AnimationTracks:Get(animation)
	local cached = self.Cache[animation]

	if cached then
		return cached
	end

	local track = self.Animator:LoadAnimation(animation)
	self.Cache[animation] = track

	return track
end

function AnimationTracks:Play(animation, settings)
	local track = self:Get(animation)

	if settings.priority then
		track.Priority = settings.priority
	end

	if settings.looped ~= nil then
		track.Looped = settings.looped
	end

	if settings.restart and track.IsPlaying then
		track:Stop(0)
	end

	if not track.IsPlaying then
		track:Play(settings.fadeTime, settings.weight, settings.speed)
	end

	return track
end

function AnimationTracks:IsPlaying(animation)
	local track = self.Cache[animation]

	return track ~= nil and track.IsPlaying
end

function AnimationTracks:Stop(animation, fadeTime)
	local track = self.Cache[animation]

	if track then
		track:Stop(fadeTime)
	end
end

function AnimationTracks:Destroy()
	for _, track in self.Cache do
		track:Stop(0)
		track:Destroy()
	end

	table.clear(self.Cache)
end

return AnimationTracks
