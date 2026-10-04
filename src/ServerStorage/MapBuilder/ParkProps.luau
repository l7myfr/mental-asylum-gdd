return function(core)
	local p = {}
	local c, mat, rng = core.c, core.mat, core.rng
	local box, cylY, cylX, cylZ, ball, seg = core.box, core.cylY, core.cylX, core.cylZ, core.ball, core.seg
	local V = Vector3.new
	local nc = {CanCollide = false}
	local leafColors = {core.rgb(58, 125, 21), core.rgb(44, 101, 29), core.rgb(75, 151, 75), core.rgb(39, 110, 50)}

	function p.tree(parent, cf, s, kind)
		s = s or 1
		kind = kind or (rng:NextNumber() < 0.7 and "oak" or "pine")
		local m = core.prop("Tree", parent, cf, {s, kind})
		local bark = core.rgb(105, 74, 50)
		local barkDark = core.rgb(84, 58, 40)
		if kind == "pine" then
			cylY(m, cf, 0, 1.2 * s, 0, 2.4 * s, 1.6 * s, barkDark, mat.Wood)
			cylY(m, cf, 0, 9 * s, 0, 16 * s, 1.1 * s, bark, mat.Wood)
			for i = 0, 6 do
				local y = (4.2 + i * 1.9) * s
				local r = (5 - i * 0.68) * s
				local col = i % 2 == 0 and core.rgb(39, 90, 45) or core.rgb(46, 104, 52)
				cylY(m, cf, 0, y, 0, 1.6 * s, r * 1.5, col, mat.Grass)
				local n = 9 - i
				for k = 1, n do
					local a = k / n * math.pi * 2 + i * 0.4
					seg(m, cf, V(math.cos(a) * r * 0.5, y + 0.6 * s, math.sin(a) * r * 0.5), V(math.cos(a) * r, y - 1.1 * s, math.sin(a) * r), 1.4 * s, col, mat.Grass, nil, 0.5 * s)
				end
			end
			for k = 0, 2 do cylY(m, cf, 0, (17 + k * 0.7) * s, 0, 0.8 * s, (1.8 - k * 0.5) * s, core.rgb(46, 104, 52), mat.Grass) end
			for i = 1, 3 do
				local a = rng:NextNumber(0, math.pi * 2)
				box(m, cf, math.cos(a) * rng:NextNumber(1, 3) * s, 0.05, math.sin(a) * rng:NextNumber(1, 3) * s, 0.5 * s, 0.1, 0.35 * s, core.rgb(120, 85, 50), mat.Wood, nc, CFrame.Angles(0, a, 0))
			end
			return m
		end
		local trunkTop = 7 * s
		cylY(m, cf, 0, 1.5 * s, 0, 3 * s, 2.1 * s, barkDark, mat.Wood)
		cylY(m, cf, 0, trunkTop / 2 + 1, 0, trunkTop - 1, 1.5 * s, bark, mat.Wood)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2 + 0.4
			seg(m, cf, V(0, 0.6 * s, 0), V(math.cos(a) * 1.8 * s, 0.05, math.sin(a) * 1.8 * s), 0.7 * s, barkDark, mat.Wood)
		end
		local tips = {}
		local n = rng:NextInteger(4, 5)
		for i = 1, n do
			local a = i / n * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local start = V(0, trunkTop * rng:NextNumber(0.7, 0.95), 0)
			local mid = V(math.cos(a) * 2.2 * s, trunkTop + rng:NextNumber(0.5, 1.5) * s, math.sin(a) * 2.2 * s)
			local tip = V(math.cos(a) * rng:NextNumber(3.5, 5) * s, trunkTop + rng:NextNumber(2.5, 4) * s, math.sin(a) * rng:NextNumber(3.5, 5) * s)
			seg(m, cf, start, mid, 0.8 * s, bark, mat.Wood)
			seg(m, cf, mid, tip, 0.55 * s, bark, mat.Wood)
			local twig = mid + V(math.cos(a + 0.9) * 1.6 * s, 1.4 * s, math.sin(a + 0.9) * 1.6 * s)
			seg(m, cf, mid, twig, 0.3 * s, bark, mat.Wood)
			table.insert(tips, tip)
			table.insert(tips, twig)
		end
		table.insert(tips, V(0, trunkTop + 4.5 * s, 0))
		for _, t in tips do
			ball(m, cf, t.X, t.Y + 0.5 * s, t.Z, rng:NextNumber(4.5, 6.5) * s, leafColors[rng:NextInteger(1, #leafColors)], mat.Grass)
			for k = 1, 2 do
				ball(m, cf, t.X + rng:NextNumber(-2, 2) * s, t.Y + rng:NextNumber(0.5, 2.5) * s, t.Z + rng:NextNumber(-2, 2) * s, rng:NextNumber(2.5, 4) * s, leafColors[rng:NextInteger(1, #leafColors)], mat.Grass)
			end
		end
		for i = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			box(m, cf, math.cos(a) * rng:NextNumber(2, 5) * s, 0.03, math.sin(a) * rng:NextNumber(2, 5) * s, 0.6, 0.06, 0.4, core.rgb(150, 160, 60), mat.SmoothPlastic, nc, CFrame.Angles(0, a, 0))
		end
		return m
	end

	function p.bush(parent, cf, s, flowers)
		s = s or 1
		local m = core.prop("Bush", parent, cf, {s})
		for i = 1, 3 do seg(m, cf, V(0, 0, 0), V(rng:NextNumber(-0.8, 0.8) * s, 1.2 * s, rng:NextNumber(-0.8, 0.8) * s), 0.18 * s, core.rgb(90, 65, 40), mat.Wood) end
		ball(m, cf, 0, 1.5 * s, 0, 3.4 * s, leafColors[rng:NextInteger(1, #leafColors)], mat.Grass)
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local r = rng:NextNumber(1.1, 1.7) * s
			ball(m, cf, math.cos(a) * r, rng:NextNumber(0.9, 2) * s, math.sin(a) * r, rng:NextNumber(1.8, 2.7) * s, leafColors[rng:NextInteger(1, #leafColors)], mat.Grass)
		end
		local fc = flowers and core.randColor() or core.rgb(170, 30, 40)
		local count = flowers and 12 or (rng:NextNumber() < 0.5 and 6 or 0)
		for i = 1, count do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(1.2, 2.2) * s
			ball(m, cf, math.cos(a) * r, rng:NextNumber(1.2, 2.9) * s, math.sin(a) * r, (flowers and 0.45 or 0.3) * s, fc, mat.SmoothPlastic, nc)
		end
		return m
	end

	function p.flowerBed(parent, cf, w, d)
		local m = core.prop("Flower Bed", parent, cf, {w, d})
		for _, sx in {-1, 1} do
			box(m, cf, sx * (w / 2 - 0.3), 0.45, 0, 0.6, 0.9, d, c.brick, mat.Brick)
			box(m, cf, sx * (w / 2 - 0.3), 0.95, 0, 0.8, 0.1, d + 0.2, c.stone, mat.Concrete)
		end
		for _, sz in {-1, 1} do
			box(m, cf, 0, 0.45, sz * (d / 2 - 0.3), w - 1.2, 0.9, 0.6, c.brick, mat.Brick)
			box(m, cf, 0, 0.96, sz * (d / 2 - 0.3), w - 1.6, 0.1, 0.8, c.stone, mat.Concrete)
		end
		box(m, cf, 0, 0.4, 0, w - 1.2, 0.8, d - 1.2, core.rgb(86, 60, 40), mat.Fabric)
		local cols = {core.randColor(), core.randColor(), c.white}
		for x = -w / 2 + 1.2, w / 2 - 1.2, 1.2 do
			for z = -d / 2 + 1.2, d / 2 - 1.2, 1.2 do
				local h = rng:NextNumber(0.9, 1.5)
				local fx, fz = x + rng:NextNumber(-0.2, 0.2), z + rng:NextNumber(-0.2, 0.2)
				local col = cols[rng:NextInteger(1, #cols)]
				box(m, cf, fx, 0.8 + h / 2, fz, 0.07, h, 0.07, c.green, mat.SmoothPlastic, nc)
				for k = 0, 4 do
					local a = k / 5 * math.pi * 2
					box(m, cf, fx + math.cos(a) * 0.17, 0.85 + h, fz + math.sin(a) * 0.17, 0.22, 0.05, 0.16, col, mat.SmoothPlastic, nc, CFrame.Angles(0, -a, math.rad(15)))
				end
				ball(m, cf, fx, 0.88 + h, fz, 0.16, c.yellow, mat.SmoothPlastic, nc)
				box(m, cf, fx + 0.18, 0.8 + h * 0.4, fz, 0.35, 0.04, 0.16, c.green, mat.SmoothPlastic, nc, CFrame.Angles(0, 0, math.rad(30)))
				box(m, cf, fx - 0.18, 0.8 + h * 0.55, fz, 0.35, 0.04, 0.16, c.green, mat.SmoothPlastic, nc, CFrame.Angles(0, 0, math.rad(-30)))
			end
		end
		return m
	end

	function p.lamp(parent, cf)
		local m = core.prop("Lamp Post", parent, cf, {})
		local iron = core.rgb(30, 34, 32)
		cylY(m, cf, 0, 0.4, 0, 0.8, 1.4, iron, mat.Metal)
		cylY(m, cf, 0, 1.1, 0, 0.6, 0.9, iron, mat.Metal)
		cylY(m, cf, 0, 6.6, 0, 10.4, 0.45, iron, mat.Metal)
		cylY(m, cf, 0, 11.9, 0, 0.3, 0.8, iron, mat.Metal)
		box(m, cf, 0, 12.2, 0, 1.3, 0.3, 1.3, iron, mat.Metal)
		local glass = box(m, cf, 0, 13.3, 0, 1, 1.9, 1, core.rgb(255, 235, 190), mat.Neon)
		for _, o in {{-0.55, -0.55}, {0.55, -0.55}, {-0.55, 0.55}, {0.55, 0.55}} do box(m, cf, o[1], 13.3, o[2], 0.14, 2, 0.14, iron, mat.Metal) end
		box(m, cf, 0, 14.4, 0, 1.6, 0.3, 1.6, iron, mat.Metal)
		cylY(m, cf, 0, 14.8, 0, 0.5, 0.5, iron, mat.Metal)
		ball(m, cf, 0, 15.15, 0, 0.35, iron, mat.Metal)
		local l = Instance.new("PointLight")
		l.Range = 26
		l.Brightness = 0.9
		l.Color = core.rgb(255, 225, 180)
		l.Parent = glass
		return m
	end

	function p.parkBench(parent, cf, w)
		w = w or 7
		local m = core.prop("Park Bench", parent, cf, {w})
		local iron = core.rgb(30, 34, 32)
		local wood = core.rgb(120, 82, 52)
		for i = 0, 3 do box(m, cf, 0, 1.75, -0.7 + i * 0.45, w, 0.18, 0.38, wood, mat.Wood) end
		for i = 0, 2 do box(m, cf, 0, 2.55 + i * 0.5, 0.95 + i * 0.08, w, 0.38, 0.14, wood, mat.Wood, nil, CFrame.Angles(math.rad(-10), 0, 0)) end
		local xs = {-w / 2 + 0.5, w / 2 - 0.5}
		if w > 8 then table.insert(xs, 0) end
		for _, x in xs do
			seg(m, cf, V(x, 0, -0.85), V(x, 1.65, -0.6), 0.22, iron, mat.Metal)
			seg(m, cf, V(x, 0, 0.75), V(x, 4.2, 1.25), 0.22, iron, mat.Metal)
			box(m, cf, x, 1.6, 0.05, 0.22, 0.18, 1.8, iron, mat.Metal)
			box(m, cf, x, 0.06, -0.85, 0.45, 0.12, 0.45, iron, mat.Metal)
			box(m, cf, x, 0.06, 0.75, 0.45, 0.12, 0.45, iron, mat.Metal)
			if x ~= 0 then
				seg(m, cf, V(x, 2.7, -0.95), V(x, 2.6, 0.9), 0.24, iron, mat.Metal)
				seg(m, cf, V(x, 1.65, -0.85), V(x, 2.7, -0.95), 0.2, iron, mat.Metal)
				ball(m, cf, x, 2.7, -1, 0.35, iron, mat.Metal)
			end
			for i = 0, 3 do cylX(m, cf, x, 1.86, -0.7 + i * 0.45, 0.3, 0.1, c.steel, mat.Metal, nc) end
		end
		box(m, cf, 0, 3.05, 1.06, 1.4, 0.35, 0.04, c.brass or core.rgb(188, 155, 93), mat.Metal, nc, CFrame.Angles(math.rad(-10), 0, 0))
		return m
	end

	function p.picnicTable(parent, cf)
		local m = core.prop("Picnic Table", parent, cf, {})
		local wood = core.rgb(140, 100, 65)
		for i = 0, 4 do box(m, cf, 0, 3.05, -1.4 + i * 0.7, 8, 0.2, 0.62, wood, mat.Wood) end
		for _, z in {-2.9, 2.9} do
			box(m, cf, 0, 1.85, z - 0.32, 8, 0.2, 0.6, wood, mat.Wood)
			box(m, cf, 0, 1.85, z + 0.32, 8, 0.2, 0.6, wood, mat.Wood)
		end
		for _, x in {-3, 3} do
			seg(m, cf, V(x, 0, -2.5), V(x, 2.95, -0.4), 0.3, wood, mat.Wood, nil, 0.5)
			seg(m, cf, V(x, 0, 2.5), V(x, 2.95, 0.4), 0.3, wood, mat.Wood, nil, 0.5)
			box(m, cf, x, 1.65, 0, 0.3, 0.25, 6.6, wood, mat.Wood)
			box(m, cf, x, 2.85, 0, 0.3, 0.2, 2.6, wood, mat.Wood)
		end
		return m
	end

	function p.grill(parent, cf)
		local m = core.prop("Grill", parent, cf, {})
		local iron = core.rgb(30, 34, 32)
		box(m, cf, 0, 0.1, 0, 1.4, 0.2, 1.4, c.mid, mat.Concrete)
		cylY(m, cf, 0, 1.6, 0, 2.8, 0.35, iron, mat.Metal)
		box(m, cf, 0, 3.2, 0, 2.6, 0.6, 1.8, iron, mat.Metal)
		for x = -1.1, 1.1, 0.3 do box(m, cf, x, 3.52, 0, 0.06, 0.04, 1.7, c.steel, mat.Metal, nc) end
		box(m, cf, 0, 3.6, 0.85, 2.6, 0.8, 0.1, iron, mat.Metal)
		return m
	end

	function p.bin(parent, cf, color)
		color = color or core.rgb(40, 90, 55)
		local m = core.prop("Trash Bin", parent, cf, {})
		cylY(m, cf, 0, 0.1, 0, 0.2, 2.2, color, mat.Metal)
		for _, y in {0.5, 2.8} do cylY(m, cf, 0, y, 0, 0.2, 2.1, color, mat.Metal) end
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			box(m, cf, math.cos(a) * 0.95, 1.6, math.sin(a) * 0.95, 0.35, 3, 0.12, color, mat.Metal, nil, CFrame.Angles(0, -a + math.pi / 2, 0))
		end
		cylY(m, cf, 0, 1.5, 0, 2.8, 1.6, c.black, mat.SmoothPlastic)
		cylY(m, cf, 0, 3.05, 0, 0.12, 1.9, c.black, mat.SmoothPlastic, nc)
		cylY(m, cf, 0, 3.25, 0, 0.25, 2.3, color, mat.Metal)
		cylY(m, cf, 0, 3.55, 0, 0.5, 1.2, color, mat.Metal)
		cylY(m, cf, 0, 3.85, 0, 0.12, 1.4, color, mat.Metal)
		core.sign(m, cf * CFrame.new(0, 2, -1.03), 0.9, 0.5, 0.02, "PARK", color, c.white, Enum.Font.GothamBlack, nc)
		return m
	end

	function p.ironFence(parent, a, b, h)
		h = h or 5
		local m = core.model("Iron Fence", parent)
		local iron = core.rgb(30, 34, 32)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(a, b)
		box(m, cf, 0, 0.6, -len / 2, 0.25, 0.15, len, iron, mat.Metal)
		box(m, cf, 0, h - 0.6, -len / 2, 0.25, 0.15, len, iron, mat.Metal)
		for d = 0, len, 0.9 do
			box(m, cf, 0, h / 2 - 0.1, -d, 0.12, h - 0.2, 0.12, iron, mat.Metal)
			box(m, cf, 0, h, -d, 0.22, 0.4, 0.22, iron, mat.Metal, nc, CFrame.Angles(math.rad(45), 0, 0))
		end
		for d = 0, len, 9 do
			box(m, cf, 0, h / 2 + 0.2, -d, 0.5, h + 0.4, 0.5, iron, mat.Metal)
			ball(m, cf, 0, h + 0.6, -d, 0.6, iron, mat.Metal)
		end
		return m
	end

	function p.chainFence(parent, a, b, h)
		h = h or 10
		local m = core.model("Chain Fence", parent)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(a, b)
		local mesh = box(m, cf, 0, h / 2, -len / 2, 0.08, h - 0.4, len, c.steel, mat.Metal, {Transparency = 1})
		for _, face in {Enum.NormalId.Left, Enum.NormalId.Right} do
			local t = core.tex(mesh, face, core.gridTex, 0.7, 0.15)
			t.Color3 = core.rgb(150, 150, 155)
			local t2 = core.tex(mesh, face, core.gridTex, 0.7, 0.15)
			t2.Color3 = core.rgb(150, 150, 155)
			t2.OffsetStudsU = 0.35
			t2.OffsetStudsV = 0.35
		end
		box(m, cf, 0, h - 0.1, -len / 2, 0.3, 0.3, len, c.steel, mat.Metal)
		box(m, cf, 0, 0.3, -len / 2, 0.2, 0.2, len, c.steel, mat.Metal)
		box(m, cf, 0, h / 2, -len / 2, 0.15, 0.15, len, c.steel, mat.Metal)
		for d = 0, len, 8 do
			cylY(m, cf, 0, h / 2, -d, h, 0.4, c.steel, mat.Metal)
			ball(m, cf, 0, h + 0.1, -d, 0.5, c.steel, mat.Metal)
		end
		cylY(m, cf, 0, h / 2, -len, h, 0.4, c.steel, mat.Metal)
		ball(m, cf, 0, h + 0.1, -len, 0.5, c.steel, mat.Metal)
		return m
	end

	function p.hedge(parent, a, b, h, w)
		h, w = h or 7, w or 3
		local m = core.model("Hedge", parent)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(a, b)
		local shades = {core.rgb(44, 101, 29), core.rgb(48, 108, 32), core.rgb(40, 94, 28)}
		box(m, cf, 0, (h - 1) / 2, -len / 2, w - 0.6, h - 1, len + w - 1.4, shades[1], mat.Grass)
		box(m, cf, 0, 0.15, -len / 2, w + 0.2, 0.3, len + w + 0.2, core.rgb(86, 60, 40), mat.Fabric)
		local rows = math.max(2, math.ceil((h - 2) / 1.5) + 1)
		for d = -w / 2 + 0.9, len + w / 2 - 0.9, 1.7 do
			for r = 0, rows - 1 do
				local y = 1.3 + r * (h - 2.3) / (rows - 1)
				ball(m, cf, rng:NextNumber(-0.2, 0.2), y + rng:NextNumber(-0.25, 0.25), -d + rng:NextNumber(-0.3, 0.3), w + rng:NextNumber(0.1, 0.5), shades[rng:NextInteger(1, #shades)], mat.Grass)
			end
		end
		return m
	end

	function p.rock(parent, cf, s)
		s = s or 1
		local m = core.prop("Rock", parent, cf, {s})
		local greys = {core.rgb(120, 118, 115), core.rgb(140, 138, 132), core.rgb(105, 104, 100)}
		local function chunk(x, y, z, sx, sy, sz, col)
			return box(m, cf, x * s, y * s, z * s, sx * s, sy * s, sz * s, col, mat.Slate, nil, CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)))
		end
		local main = chunk(0, 1.6, 0, 5, 3.6, 4.2, greys[1])
		chunk(1.9, 1, 1.3, 3, 2.4, 2.6, greys[2])
		chunk(-1.7, 0.6, -1.5, 2, 1.5, 1.8, greys[3])
		chunk(-2.6, 0.35, 1.4, 1.2, 0.8, 1, greys[2])
		chunk(2.8, 0.3, -1.6, 0.9, 0.6, 0.8, greys[3])
		for i = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			ball(m, cf, math.cos(a) * 2.4 * s, 0.25 * s, math.sin(a) * 2.2 * s, rng:NextNumber(0.6, 1.1) * s, core.rgb(80, 110, 50), mat.Grass, nc)
		end
		for i = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			box(m, cf, math.cos(a) * 2.8 * s, 0.15, math.sin(a) * 2.8 * s, 0.6, 0.3, 0.5, greys[rng:NextInteger(1, 3)], mat.Slate, nil, CFrame.Angles(0, a, 0.2))
		end
		return m
	end

	function p.infoBoard(parent, cf, title)
		local m = core.prop("Info Board", parent, cf, {})
		local wood = core.rgb(110, 75, 48)
		for _, x in {-2.6, 2.6} do box(m, cf, x, 3.6, 0, 0.45, 7.2, 0.45, wood, mat.Wood) end
		box(m, cf, 0, 4.3, 0, 4.8, 3.6, 0.25, wood, mat.Wood)
		box(m, cf, 0, 4.3, -0.14, 4.4, 3.2, 0.02, core.rgb(110, 170, 100), mat.SmoothPlastic)
		for i = 1, 6 do box(m, cf, rng:NextNumber(-1.8, 1.8), rng:NextNumber(3.2, 5.4), -0.16, rng:NextNumber(0.5, 1.4), rng:NextNumber(0.3, 0.9), 0.02, ({c.water, c.sand, c.white, c.grass})[rng:NextInteger(1, 4)], mat.SmoothPlastic, nc) end
		core.sign(m, cf * CFrame.new(0, 6.6, -0.14), 4.4, 0.8, 0.05, title or "CITY PARK", wood, c.white, Enum.Font.GothamBlack, nc)
		core.wedge(m, cf * CFrame.new(0, 7.6, -0.6) * CFrame.Angles(0, math.pi, 0), V(6, 0.8, 1.4), core.rgb(70, 50, 35), mat.WoodPlanks)
		core.wedge(m, cf * CFrame.new(0, 7.6, 0.6), V(6, 0.8, 1.4), core.rgb(70, 50, 35), mat.WoodPlanks)
		return m
	end

	function p.drinkingFountain(parent, cf)
		local m = core.prop("Drinking Fountain", parent, cf, {})
		local body = core.rgb(55, 85, 70)
		box(m, cf, 0, 0.1, 0, 3, 0.2, 3, c.mid, mat.Concrete)
		box(m, cf, 0, 0.35, 0, 1.6, 0.3, 1.6, body, mat.Metal)
		box(m, cf, 0, 1.95, 0, 1.15, 3, 1.15, body, mat.Metal)
		for _, o in {{-0.58, -0.58}, {0.58, -0.58}, {-0.58, 0.58}, {0.58, 0.58}} do cylY(m, cf, o[1], 1.95, o[2], 3, 0.22, body, mat.Metal) end
		box(m, cf, 0, 3.5, 0, 1.4, 0.15, 1.4, body, mat.Metal)
		cylY(m, cf, 0, 3.7, -0.15, 0.35, 2.2, c.steel, mat.Metal)
		cylY(m, cf, 0, 3.92, -0.15, 0.1, 2.3, c.steel, mat.Metal)
		cylY(m, cf, 0, 3.9, -0.15, 0.08, 1.8, core.rgb(90, 92, 98), mat.Metal, nc)
		cylY(m, cf, 0, 3.95, -0.15, 0.02, 0.35, c.black, mat.Metal, nc)
		local s1 = V(0, 3.85, 0.55)
		local s2 = V(0, 4.45, 0.45)
		local s3 = V(0, 4.55, 0.15)
		seg(m, cf, s1, s2, 0.22, c.steel, mat.Metal, nc)
		seg(m, cf, s2, s3, 0.2, c.steel, mat.Metal, nc)
		ball(m, cf, s3.X, s3.Y, s3.Z, 0.24, c.steel, mat.Metal, nc)
		box(m, cf, 0, 3.05, -0.6, 0.6, 0.6, 0.12, c.steel, mat.Metal)
		cylZ(m, cf, 0, 3.05, -0.7, 0.12, 0.4, c.charcoal, mat.Metal, nc)
		core.sign(m, cf * CFrame.new(0, 2.35, -0.59), 0.8, 0.35, 0.02, "PUSH", body, c.white, Enum.Font.GothamBold, nc)
		cylY(m, cf, 0.9, 0.35, -0.9, 0.3, 1.1, c.steel, mat.Metal)
		cylY(m, cf, 0.9, 0.46, -0.9, 0.1, 0.85, core.rgb(90, 92, 98), mat.Metal, nc)
		box(m, cf, 0.45, 0.9, -0.6, 0.12, 0.6, 0.12, c.steel, mat.Metal)
		return m
	end


	function p.ring(m, cf, center, radius, thick, color, material, n, axis)
		n = n or 18
		local pts = {}
		for i = 0, n do
			local a = i / n * math.pi * 2
			if axis == "x" then
				table.insert(pts, center + V(0, math.sin(a) * radius, math.cos(a) * radius))
			else
				table.insert(pts, center + V(math.cos(a) * radius, 0, math.sin(a) * radius))
			end
		end
		for i = 1, n do
			local a, b = pts[i], pts[i + 1]
			local dir = (b - a).Unit
			seg(m, cf, a - dir * thick * 0.35, b + dir * thick * 0.35, thick, color, material or mat.SmoothPlastic, nc)
		end
	end

	function p.bike(parent, cf, color)
		local m = core.prop("Bike", parent, cf, {})
		color = color or core.randColor()
		local r = 1.15
		local rear, front = V(0, r, 1.7), V(0, r, -1.7)
		for _, hub in {rear, front} do
			p.ring(m, cf, hub, r, 0.2, c.black, mat.SmoothPlastic, 20, "x")
			p.ring(m, cf, hub, r - 0.12, 0.07, c.steel, mat.Metal, 20, "x")
			cylX(m, cf, hub.X, hub.Y, hub.Z, 0.35, 0.22, c.steel, mat.Metal, nc)
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				seg(m, cf, hub, hub + V(0, math.sin(a) * (r - 0.15), math.cos(a) * (r - 0.15)), 0.035, c.fossil, mat.Metal, nc)
			end
		end
		local bb = V(0, 0.95, 0.35)
		local seatTop = V(0, 2.75, 0.9)
		local head = V(0, 2.65, -1.15)
		local headLow = V(0, 2.25, -1.25)
		local t = 0.13
		seg(m, cf, bb, seatTop, t, color, mat.Metal, nc)
		seg(m, cf, seatTop - V(0, 0.15, 0), head, t, color, mat.Metal, nc)
		seg(m, cf, bb, headLow, t + 0.03, color, mat.Metal, nc)
		seg(m, cf, head + V(0, 0.15, 0.02), headLow - V(0, 0.05, 0.03), t + 0.04, color, mat.Metal, nc)
		for _, x in {-0.1, 0.1} do
			seg(m, cf, V(x, r, 1.7), bb + V(x, 0, 0), 0.08, color, mat.Metal, nc)
			seg(m, cf, V(x, r, 1.7), seatTop - V(-x, 0.15, 0), 0.08, color, mat.Metal, nc)
			seg(m, cf, V(x, r, -1.7), headLow + V(x, 0, 0), 0.09, c.steel, mat.Metal, nc)
		end
		seg(m, cf, head, head + V(0, 0.45, 0.08), 0.1, c.steel, mat.Metal, nc)
		local bar = head + V(0, 0.45, 0.08)
		for _, x in {-1, 1} do
			seg(m, cf, bar, bar + V(x * 0.55, 0.05, 0.12), 0.08, c.steel, mat.Metal, nc)
			seg(m, cf, bar + V(x * 0.55, 0.05, 0.12), bar + V(x * 0.7, 0, 0.35), 0.12, c.black, mat.SmoothPlastic, nc)
		end
		seg(m, cf, seatTop, seatTop + V(0, 0.4, 0.05), 0.08, c.steel, mat.Metal, nc)
		box(m, cf, 0, seatTop.Y + 0.45, seatTop.Z + 0.05, 0.38, 0.12, 0.85, c.black, mat.SmoothPlastic, nc)
		box(m, cf, 0, seatTop.Y + 0.42, seatTop.Z + 0.35, 0.5, 0.1, 0.3, c.black, mat.SmoothPlastic, nc)
		cylX(m, cf, 0.18, bb.Y, bb.Z, 0.05, 0.75, c.steel, mat.Metal, nc)
		for _, sgn in {-1, 1} do
			local pedal = bb + V(sgn * 0.32, sgn * 0.55, sgn * 0.1)
			seg(m, cf, bb + V(sgn * 0.22, 0, 0), pedal, 0.07, c.steel, mat.Metal, nc)
			box(m, cf, pedal.X + sgn * 0.15, pedal.Y, pedal.Z, 0.3, 0.06, 0.2, c.black, mat.SmoothPlastic, nc)
		end
		seg(m, cf, bb + V(0.18, 0.37, 0), rear + V(0.15, 0.15, 0), 0.03, c.charcoal, mat.Metal, nc)
		seg(m, cf, bb + V(0.18, -0.37, 0), rear + V(0.15, -0.15, 0), 0.03, c.charcoal, mat.Metal, nc)
		seg(m, cf, rear + V(0, 0.15, 0) + V(0, r - 0.1, 0) * 0, V(0, 2.25, 1.85), 0.06, c.steel, mat.Metal, nc)
		box(m, cf, 0, 2.3, 1.75, 0.3, 0.05, 1.3, color, mat.Metal, nc, CFrame.Angles(math.rad(-6), 0, 0))
		return m
	end


	function p.bikeRack(parent, cf, n, bikes)
		n = n or 4
		local m = core.prop("Bike Rack", parent, cf, {n})
		box(m, cf, 0, 0.08, 0, n * 2.4 + 0.6, 0.16, 3, c.mid, mat.Concrete)
		for i = 0, n - 1 do
			local x = -(n - 1) * 1.2 + i * 2.4
			local top = 2.6
			local pts = {}
			for k = 0, 8 do
				local a = k / 8 * math.pi
				table.insert(pts, V(x, top + math.sin(a) * 0.9 - 0.9 + 0.9, math.cos(a) * 0.9))
			end
			seg(m, cf, V(x, 0.16, 0.9), V(x, top, 0.9), 0.16, c.steel, mat.Metal)
			seg(m, cf, V(x, 0.16, -0.9), V(x, top, -0.9), 0.16, c.steel, mat.Metal)
			for k = 1, 8 do
				local a, b = pts[k], pts[k + 1]
				local dir = (b - a).Unit
				seg(m, cf, a - dir * 0.06, b + dir * 0.06, 0.16, c.steel, mat.Metal)
			end
			if bikes and rng:NextNumber() < 0.6 then p.bike(m, cf * CFrame.new(x + 0.35, 0.16, 0)) end
		end
		return m
	end


	function p.duck(parent, cf)
		local m = core.prop("Duck", parent, cf, {})
		local white = c.white
		box(m, cf, 0, 0.5, 0.05, 0.85, 0.65, 1.3, white, mat.SmoothPlastic, nc)
		box(m, cf, 0, 0.45, -0.35, 0.75, 0.55, 0.6, white, mat.SmoothPlastic, nc, CFrame.Angles(math.rad(20), 0, 0))
		seg(m, cf, V(0, 0.7, -0.45), V(0, 1.15, -0.6), 0.32, white, mat.SmoothPlastic, nc)
		ball(m, cf, 0, 1.25, -0.6, 0.55, core.rgb(39, 110, 50), mat.SmoothPlastic, nc)
		box(m, cf, 0, 1.2, -0.95, 0.22, 0.1, 0.35, c.yellow, mat.SmoothPlastic, nc)
		for _, x in {-0.2, 0.2} do ball(m, cf, x, 1.33, -0.78, 0.1, c.black, mat.SmoothPlastic, nc) end
		for _, x in {-0.44, 0.44} do box(m, cf, x, 0.6, 0.15, 0.08, 0.4, 0.9, core.rgb(200, 200, 195), mat.SmoothPlastic, nc, CFrame.Angles(math.rad(-10), 0, 0)) end
		box(m, cf, 0, 0.75, 0.75, 0.45, 0.25, 0.35, white, mat.SmoothPlastic, nc, CFrame.Angles(math.rad(35), 0, 0))
		return m
	end

	function p.iceCreamCart(parent, cf)
		local m = core.prop("Ice Cream Cart", parent, cf, {})
		box(m, cf, 0, 2.4, 0, 5, 2.8, 2.6, c.white, mat.SmoothPlastic)
		box(m, cf, 0, 2.4, -1.31, 4.6, 0.6, 0.02, core.rgb(255, 160, 190), mat.SmoothPlastic)
		box(m, cf, 0, 3.85, 0, 5.2, 0.1, 2.8, c.steel, mat.Metal)
		for _, x in {-1.8, 1.8} do cylX(m, cf, x, 0.8, 1.3, 0.3, 1.6, c.black, mat.SmoothPlastic) cylX(m, cf, x, 0.8, -1.3, 0.3, 1.6, c.black, mat.SmoothPlastic) end
		box(m, cf, 0, 0.9, 0, 4.6, 0.2, 2.6, c.steel, mat.Metal)
		cylY(m, cf, 2.2, 6, 0.8, 4.3, 0.15, c.steel, mat.Metal)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			seg(m, cf, V(2.2, 8.4, 0.8), V(2.2 + math.cos(a) * 3.2, 7.2, 0.8 + math.sin(a) * 3.2), 2.4, i % 2 == 0 and core.rgb(255, 160, 190) or c.white, mat.Fabric, nc, 0.05)
		end
		core.sign(m, cf * CFrame.new(0, 3.2, -1.33), 3.6, 0.6, 0.02, "ICE CREAM", core.rgb(255, 160, 190), c.white, Enum.Font.GothamBlack, nc)
		for i = 0, 2 do
			cylY(m, cf, -1.4 + i * 0.6, 4.1, 0.3, 0.4, 0.3, c.tan, mat.SmoothPlastic, nc)
			ball(m, cf, -1.4 + i * 0.6, 4.45, 0.3, 0.45, core.randColor(), mat.SmoothPlastic, nc)
		end
		return m
	end

	return p
end
