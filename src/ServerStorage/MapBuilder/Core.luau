local core = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
core.rgb = rgb
core.mat = Enum.Material
core.gridTex = "rbxassetid://7139083631"
core.c = {
	white = rgb(248, 248, 248), offWhite = rgb(237, 234, 234), light = rgb(202, 203, 209), mid = rgb(163, 162, 165),
	fossil = rgb(159, 161, 172), steel = rgb(124, 124, 126), dark = rgb(99, 95, 98), darker = rgb(91, 93, 105),
	charcoal = rgb(52, 52, 56), black = rgb(17, 17, 17), navy = rgb(27, 42, 53), accent = rgb(140, 18, 28),
	accentBright = rgb(196, 40, 28), wood = rgb(108, 88, 75), darkWood = rgb(86, 66, 54), lightWood = rgb(160, 132, 79),
	tan = rgb(188, 155, 93), cardboard = rgb(186, 145, 92), green = rgb(58, 125, 21), leaf = rgb(44, 101, 29),
	grass = rgb(75, 151, 75), glass = rgb(128, 187, 219), yellow = rgb(245, 205, 48), brick = rgb(151, 79, 64),
	water = rgb(60, 130, 170), sand = rgb(205, 190, 140), stone = rgb(226, 220, 188),
}
core.palette = {rgb(196, 40, 28), rgb(13, 105, 172), rgb(245, 205, 48), rgb(75, 151, 75), rgb(218, 134, 122), rgb(180, 128, 255), rgb(248, 248, 248), rgb(255, 176, 0), rgb(4, 175, 236)}
core.rng = Random.new(11)
core.world = CFrame.new()
core.origin = Vector3.zero

function core.setOrigin(origin, root)
	core.origin = origin
	core.world = CFrame.new(origin)
	core.root = root
end

function core.randColor() return core.palette[core.rng:NextInteger(1, #core.palette)] end

function core.model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or core.root
	return m
end

function core.folder(name, parent)
	parent = parent or core.root
	local f = parent:FindFirstChild(name)
	if f then return f end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function core.group(name, parent)
	parent = parent or core.root
	return parent:FindFirstChild(name) or core.model(name, parent)
end

function core.part(parent, cf, size, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = core.world * cf
	p.Color = color or core.c.mid
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then for k, v in props do p[k] = v end end
	p.Parent = parent
	return p
end

function core.block(parent, x1, y1, z1, x2, y2, z2, color, material, props)
	return core.part(parent, CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1)), color, material, props)
end

function core.box(m, base, x, y, z, sx, sy, sz, color, material, props, rot)
	local cf = base * CFrame.new(x, y, z)
	if rot then cf *= rot end
	return core.part(m, cf, Vector3.new(sx, sy, sz), color, material, props)
end

local function shaped(p, shape)
	p.Shape = shape
	return p
end
function core.cylY(m, base, x, y, z, h, d, color, material, props)
	return shaped(core.part(m, base * CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, d, d), color, material, props), Enum.PartType.Cylinder)
end
function core.cylX(m, base, x, y, z, len, d, color, material, props)
	return shaped(core.part(m, base * CFrame.new(x, y, z), Vector3.new(len, d, d), color, material, props), Enum.PartType.Cylinder)
end
function core.cylZ(m, base, x, y, z, len, d, color, material, props)
	return shaped(core.part(m, base * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(len, d, d), color, material, props), Enum.PartType.Cylinder)
end
function core.ball(m, base, x, y, z, d, color, material, props)
	return shaped(core.part(m, base * CFrame.new(x, y, z), Vector3.new(d, d, d), color, material, props), Enum.PartType.Ball)
end
function core.seg(m, base, a, b, t, color, material, props, t2)
	return core.part(m, base * CFrame.lookAt((a + b) / 2, b), Vector3.new(t, t2 or t, (b - a).Magnitude), color, material, props)
end
function core.wedge(m, cf, size, color, material, props)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = core.world * cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	if props then for k, v in props do w[k] = v end end
	w.Parent = m
	return w
end

function core.at(x, y, z, yaw) return CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0) end
local dirs = {n = Vector3.new(0, 0, 1), s = Vector3.new(0, 0, -1), e = Vector3.new(1, 0, 0), w = Vector3.new(-1, 0, 0)}
function core.face(x, z, dir, y)
	local pos = Vector3.new(x, y or 0, z)
	return CFrame.lookAt(pos, pos + (typeof(dir) == "Vector3" and dir or dirs[dir]))
end

function core.tex(part, face, id, studs, transparency)
	local t = Instance.new("Texture")
	t.Face = face
	t.Texture = id
	t.StudsPerTileU = studs or 4
	t.StudsPerTileV = studs or 4
	t.Transparency = transparency or 0
	t.Parent = part
	return t
end

function core.sign(parent, cf, w, h, d, text, bg, fg, font, props)
	local p = core.part(parent, cf, Vector3.new(w, h, d or 0.2), bg, Enum.Material.SmoothPlastic, props)
	p.Name = "Sign"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBold
	label.TextColor3 = fg or core.c.white
	label.Parent = gui
	return p
end

function core.prop(name, parent, cf, args)
	local m = core.model(name, parent)
	m:SetAttribute("Prop", name)
	m:SetAttribute("Base", core.world * cf)
	if args then m:SetAttribute("Args", game:GetService("HttpService"):JSONEncode(args)) end
	return m
end

function core.objectives(list)
	local f = core.folder("Objectives")
	f:ClearAllChildren()
	for _, o in list do
		local part = core.part(f, CFrame.new(o[4], o[5], o[6]), Vector3.new(1.1, 1.1, 1.1), BrickColor.new("Forest green").Color, Enum.Material.Neon, {Transparency = 0.5, CanCollide = false, Name = "ObjectivePart", CastShadow = false})
		local n = Instance.new("StringValue") n.Name = "ObjectiveName" n.Value = o[1] n.Parent = part
		local pr = Instance.new("ProximityPrompt") pr.Name = "ObjectivePrompt" pr.ActionText = "Interact" pr.ObjectText = "" pr.HoldDuration = 20 pr.Parent = part
		local t = Instance.new("StringValue") t.Name = "ObjectiveText" t.Value = o[2] t.Parent = part
		local tm = Instance.new("IntValue") tm.Name = "ObjectiveTime" tm.Value = o[3] tm.Parent = part
	end
	return f
end

function core.spawns(points, floorY)
	local f = core.folder("Spawns")
	f:ClearAllChildren()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {f, core.folder("Objectives")}
	params.RespectCanCollide = true
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {f, core.folder("Objectives")}
	local failed = {}
	local blue = BrickColor.new("Electric blue").Color
	for _, pt in points do
		local base = pt[3] or floorY or 0
		local placed = false
		for r = 0, 12, 1.5 do
			local steps = r == 0 and 1 or 10
			for k = 0, steps - 1 do
				local a = k / steps * math.pi * 2
				local px, pz = pt[1] + math.cos(a) * r, pt[2] + math.sin(a) * r
				local center = core.origin + Vector3.new(px, base + 2.6, pz)
				local free = true
				for _, h in workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(3, 4.6, 3), params) do
					if h.Transparency < 1 then free = false break end
				end
				if free then
					local hit = workspace:Raycast(center, Vector3.new(0, -4, 0), rp)
					if hit and math.abs(hit.Position.Y - (core.origin.Y + base)) < 0.6 then
						core.part(f, CFrame.new(px, hit.Position.Y - core.origin.Y + 2.6, pz), Vector3.new(5, 5, 5), blue, Enum.Material.Plastic, {Transparency = 0.5, CanCollide = false, CanQuery = false, CastShadow = false, Name = "Part"})
						placed = true
						break
					end
				end
			end
			if placed then break end
		end
		if not placed then table.insert(failed, pt[1] .. "," .. pt[2]) end
	end
	return #f:GetChildren(), failed
end

function core.boundary(x1, z1, x2, z2, height, capY)
	local f = core.folder("Mold Casting")
	f:ClearAllChildren()
	local inv = {Transparency = 1, Name = "Molding", CanCollide = true, CastShadow = false}
	core.block(f, x1 - 4, -2, z1 - 4, x1, height, z2 + 4, core.c.mid, nil, inv)
	core.block(f, x2, -2, z1 - 4, x2 + 4, height, z2 + 4, core.c.mid, nil, inv)
	core.block(f, x1 - 4, -2, z1 - 4, x2 + 4, height, z1, core.c.mid, nil, inv)
	core.block(f, x1 - 4, -2, z2, x2 + 4, height, z2 + 4, core.c.mid, nil, inv)
	if capY then core.block(f, x1 - 4, capY, z1 - 4, x2 + 4, capY + 2, z2 + 4, core.c.mid, nil, inv) end
	return f
end

local function aligned(cf)
	for _, v in {cf.RightVector, cf.UpVector, cf.LookVector} do
		if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.999 then return false end
	end
	return true
end
function core.zsweep(root, fix, skip)
	local o = core.origin
	local planes, boxes = {}, {}
	for _, p in root:GetDescendants() do
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Transparency < 0.95 and aligned(p.CFrame) and not p:FindFirstAncestor("Spawns") and not p:FindFirstAncestor("Objectives") then
			local cf, s = p.CFrame, p.Size
			local ext = Vector3.new(
				math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
				math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
				math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z)
			local mn, mx = cf.Position - o - ext / 2, cf.Position - o + ext / 2
			table.insert(boxes, {p, mn, mx})
			for axis = 1, 3 do
				for _, sgn in {-1, 1} do
					local coord = axis == 1 and (sgn > 0 and mx.X or mn.X) or axis == 2 and (sgn > 0 and mx.Y or mn.Y) or (sgn > 0 and mx.Z or mn.Z)
					local key = axis * 10 + (sgn + 1) .. ":" .. math.floor(coord * 50 + 0.5)
					planes[key] = planes[key] or {}
					table.insert(planes[key], {p, mn, mx, axis, sgn, coord})
				end
			end
		end
	end
	local function range(f, axis)
		if axis == 1 then return f[2].Y, f[3].Y, f[2].Z, f[3].Z elseif axis == 2 then return f[2].X, f[3].X, f[2].Z, f[3].Z end
		return f[2].X, f[3].X, f[2].Y, f[3].Y
	end
	local found = {}
	for _, list in planes do
		if #list > 1 and #list < 600 then
			for i = 1, #list do
				for j = i + 1, #list do
					local f, g = list[i], list[j]
					local axis, sgn, coord = f[4], f[5], f[6]
					if not (axis == 2 and sgn < 0 and math.abs(coord) < 0.05) and (f[1].Color ~= g[1].Color or f[1].Material ~= g[1].Material) then
						local fa1, fa2, fb1, fb2 = range(f, axis)
						local ga1, ga2, gb1, gb2 = range(g, axis)
						local a1, a2, b1, b2 = math.max(fa1, ga1), math.min(fa2, ga2), math.max(fb1, gb1), math.min(fb2, gb2)
						if a2 - a1 > 0.05 and b2 - b1 > 0.05 then
							local m1, m2 = (a1 + a2) / 2, (b1 + b2) / 2
							local probe = axis == 1 and Vector3.new(coord + sgn * 0.02, m1, m2) or axis == 2 and Vector3.new(m1, coord + sgn * 0.02, m2) or Vector3.new(m1, m2, coord + sgn * 0.02)
							local hidden = false
							for _, b in boxes do
								if b[1] ~= f[1] and b[1] ~= g[1] and probe.X > b[2].X and probe.X < b[3].X and probe.Y > b[2].Y and probe.Y < b[3].Y and probe.Z > b[2].Z and probe.Z < b[3].Z then hidden = true break end
							end
							if not hidden then
								local fArea, gArea = (fa2 - fa1) * (fb2 - fb1), (ga2 - ga1) * (gb2 - gb1)
								table.insert(found, {fArea <= gArea and f[1] or g[1], axis, sgn, fArea <= gArea and g[1] or f[1]})
							end
						end
					end
				end
			end
		end
	end
	if fix then
		local done = {}
		for _, h in found do
			local part, axis, sgn = h[1], h[2], h[3]
			local k = part:GetDebugId() .. axis .. sgn
			if not done[k] and not (skip and skip(part)) then
				done[k] = true
				local worldAxis = axis == 1 and Vector3.xAxis or axis == 2 and Vector3.yAxis or Vector3.zAxis
				local cf = part.CFrame
				local la = cf:VectorToObjectSpace(worldAxis)
				part.Size += Vector3.new(math.abs(la.X), math.abs(la.Y), math.abs(la.Z)) * 0.03
				part.CFrame = cf + worldAxis * sgn * 0.015
			end
		end
	end
	return found
end

return core
