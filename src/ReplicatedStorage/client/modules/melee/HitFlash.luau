local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spring = require(ReplicatedStorage.client.modules.utils.Spring)

local HitFlash = {}
HitFlash.__index = HitFlash

function HitFlash.new(character, settings, color)
	local self = setmetatable({}, HitFlash)

	local highlight = Instance.new("Highlight")
	highlight.FillColor = color or settings.color
	highlight.OutlineColor = color or settings.color
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = settings.fillStart
	highlight.OutlineTransparency = settings.outlineStart
	highlight.Adornee = character
	highlight.Parent = character

	self.Highlight = highlight
	self.Settings = settings
	self.Spring = Spring.new(0, settings.damping, settings.speed)
	self.Spring.Target = 1

	return self
end

function HitFlash:Update()
	local settings = self.Settings
	local alpha = math.clamp(self.Spring.Position, 0, 1)

	self.Highlight.FillTransparency = settings.fillStart + (1 - settings.fillStart) * alpha
	self.Highlight.OutlineTransparency = settings.outlineStart + (1 - settings.outlineStart) * alpha

	return alpha < 0.99 and self.Highlight.Parent ~= nil
end

function HitFlash:SetColor(color)
	self.Highlight.FillColor = color
	self.Highlight.OutlineColor = color
end

function HitFlash:Destroy()
	self.Highlight:Destroy()
end

return HitFlash
