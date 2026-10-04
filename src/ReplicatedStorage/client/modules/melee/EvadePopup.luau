local TweenService = game:GetService("TweenService")

local EvadePopup = {}

-- Shows a label above the character that rises and fades out, then cleans itself up.
function EvadePopup.Show(character, settings)
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.Size = settings.size
	billboard.StudsOffsetWorldSpace = settings.offset

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = settings.text
	label.TextColor3 = settings.color
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBlack
	label.Parent = billboard

	billboard.Parent = root

	local info = TweenInfo.new(settings.duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(billboard, info, {
		StudsOffsetWorldSpace = settings.offset + Vector3.new(0, settings.rise, 0),
	}):Play()

	local fade = TweenService:Create(label, info, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	fade.Completed:Once(function()
		billboard:Destroy()
	end)

	fade:Play()
end

return EvadePopup
