local keepChildClasses = {
	"DataModelMesh", "Decal", "SurfaceAppearance", "SurfaceGui", "Attachment", "Light", "ParticleEmitter",
}
local function isKeptChild(inst)
	for _, cls in keepChildClasses do if inst:IsA(cls) then return true end end
	return false
end
local function isGuiDescendant(inst)
	return inst:FindFirstAncestorWhichIsA("SurfaceGui") ~= nil
end
return function(root, opts)
	opts = opts or {}
	local report = {scripts = 0, seats = 0, removed = 0, parts = 0}
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			report.scripts += 1
		end
	end
	for _, d in root:GetDescendants() do
		if d.Parent and (d:IsA("Seat") or d:IsA("VehicleSeat") or d:IsA("SpawnLocation") or d:IsA("TrussPart") and opts.noTruss) then
			local p = Instance.new("Part")
			p.Name = d.Name
			p.Size = d.Size
			p.CFrame = d.CFrame
			p.Color = d.Color
			p.Material = d.Material
			p.Transparency = d.Transparency
			p.Reflectance = d.Reflectance
			p.CanCollide = d.CanCollide
			p.CastShadow = d.CastShadow
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			for _, ch in d:GetChildren() do ch.Parent = p end
			p.Parent = d.Parent
			d:Destroy()
			report.seats += 1
		end
	end
	for _, d in root:GetDescendants() do
		if d.Parent then
			if d:IsA("BasePart") then
				d.Anchored = true
				d.Massless = false
				d.AssemblyLinearVelocity = Vector3.zero
				d.AssemblyAngularVelocity = Vector3.zero
				report.parts += 1
			elseif d:IsA("Model") or d:IsA("Folder") then
			elseif isGuiDescendant(d) then
			elseif d.Parent:IsA("BasePart") and isKeptChild(d) then
				if d:IsA("ParticleEmitter") and not opts.keepParticles then d:Destroy() report.removed += 1 end
			elseif d:IsA("Attachment") or d:IsA("Light") then
			else
				d:Destroy()
				report.removed += 1
			end
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and #d:GetChildren() == 0 then d:Destroy() end
	end
	return report
end
