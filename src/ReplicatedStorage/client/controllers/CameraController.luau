local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraConfig = require(ReplicatedStorage.shared.config.CameraConfig)
local Spring = require(ReplicatedStorage.client.modules.utils.Spring)

local gameSettings = UserSettings():GetService("UserGameSettings")
local flatMask = Vector3.new(1, 0, 1)

local CameraController = {}

function CameraController:Start()
	self.HeadSpring = Spring.new(Vector3.zero, CameraConfig.headSpring.damping, CameraConfig.headSpring.speed)
	self.LockSpring = Spring.new(Vector3.zero, CameraConfig.mouseLock.damping, CameraConfig.mouseLock.speed)
	self.MouseLocked = self:IsMouseLocked()
	self.Focus = self:CreateFocus()

	RunService:BindToRenderStep(CameraConfig.renderStepName, Enum.RenderPriority.Camera.Value - 1, function()
		self:Update()
	end)
end

function CameraController:CreateFocus()
	local focus = Instance.new("Part")
	focus.Name = CameraConfig.focusName
	focus.Size = Vector3.one * 0.2
	focus.Transparency = 1
	focus.Anchored = true
	focus.CanCollide = false
	focus.CanQuery = false
	focus.CanTouch = false
	focus.CastShadow = false
	focus.Parent = workspace.CurrentCamera

	return focus
end

function CameraController:LocalCharacterAdded(player, character)
	self.Character = character
	self.HeadSpring:Reset(Vector3.zero)
end

function CameraController:IsMouseLocked()
	return gameSettings.RotationType == Enum.RotationType.CameraRelative
end

function CameraController:UpdateMouseLock()
	local locked = self:IsMouseLocked()

	if locked == self.MouseLocked then
		return
	end

	self.MouseLocked = locked

	local jump = if locked then -CameraConfig.mouseLock.offset else CameraConfig.mouseLock.offset
	self.LockSpring.Position = self.LockSpring.Position + jump
	self.LockSpring.Target = Vector3.zero
end

function CameraController:GetHeadOffset(root, subject)
	local offset = (root.CFrame:PointToObjectSpace(subject.Position) - CameraConfig.baseOffset) * CameraConfig.influence

	if offset.Magnitude > CameraConfig.maxOffset then
		offset = offset.Unit * CameraConfig.maxOffset
	end

	return offset
end

function CameraController:GetYaw(root)
	local look = root.CFrame.LookVector * flatMask

	if look.Magnitude < 1e-3 then
		return CFrame.identity
	end

	return CFrame.lookAt(Vector3.zero, look)
end

function CameraController:Update()
	self:UpdateMouseLock()

	local camera = workspace.CurrentCamera
	local character = self.Character or Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	local subject = character and character:FindFirstChild(CameraConfig.subjectPart)

	if not root or not subject then
		return
	end

	self.HeadSpring.Target = self:GetHeadOffset(root, subject)

	local focusPosition = root.CFrame:PointToWorldSpace(CameraConfig.baseOffset + self.HeadSpring.Position)
	local lockOffset = camera.CFrame:VectorToWorldSpace(self.LockSpring.Position)

	self.Focus.CFrame = CFrame.new(focusPosition + lockOffset) * self:GetYaw(root)

	if self.Focus.Parent ~= camera then
		self.Focus.Parent = camera
	end

	if camera.CameraSubject ~= self.Focus then
		camera.CameraSubject = self.Focus
	end
end

return CameraController
