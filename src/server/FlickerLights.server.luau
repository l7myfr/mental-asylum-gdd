local CollectionService = game:GetService("CollectionService")

local function flicker(fixture)
	local light = fixture:FindFirstChildOfClass("PointLight")

	while fixture.Parent do
		task.wait(math.random(2, 8))
		for _ = 1, math.random(2, 5) do
			light.Enabled = false
			fixture.Material = Enum.Material.SmoothPlastic
			task.wait(0.03 + math.random() * 0.12)
			light.Enabled = true
			fixture.Material = Enum.Material.Neon
			task.wait(0.03 + math.random() * 0.15)
		end
	end
end

for _, fixture in CollectionService:GetTagged("FlickerLight") do
	task.spawn(flicker, fixture)
end

CollectionService:GetInstanceAddedSignal("FlickerLight"):Connect(function(fixture)
	task.spawn(flicker, fixture)
end)
