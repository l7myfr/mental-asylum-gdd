return function(core, pk)
	local c, mat, rng, P = core.c, core.mat, core.rng, core.p
	local V = Vector3.new
	local root = core.root
	for _, n in {"Pond", "Fountain"} do local o = root:FindFirstChild(n) if o then o:Destroy() end end
	local g = root.Ground
	g:ClearAllChildren()
	local px1, px2, pz1, pz2 = -152, -38, 32, 108
	local lawnCol = core.rgb(70, 140, 60)
	core.block(g, -300, -2, -250, 300, 0, pz1, lawnCol, mat.Grass, {Name = "Lawn"})
	core.block(g, -300, -2, pz2, 300, 0, 250, lawnCol, mat.Grass, {Name = "Lawn"})
	core.block(g, -300, -2, pz1, px1, 0, pz2, lawnCol, mat.Grass, {Name = "Lawn"})
	core.block(g, px2, -2, pz1, 300, 0, pz2, lawnCol, mat.Grass, {Name = "Lawn"})
	local pond = core.model("Pond")
	local stone = core.rgb(185, 178, 160)
	core.block(pond, px1, -4, pz1, px2, -3, pz2, core.rgb(70, 75, 60), mat.Slate, {Name = "Pond Bed"})
	for _, w in {{px1, pz1, px2, pz1 + 1.2}, {px1, pz2 - 1.2, px2, pz2}, {px1, pz1 + 1.2, px1 + 1.2, pz2 - 1.2}, {px2 - 1.2, pz1 + 1.2, px2, pz2 - 1.2}} do
		core.block(pond, w[1], -3, w[2], w[3], -0.02, w[4], core.rgb(120, 115, 105), mat.Cobblestone, {Name = "Retaining Wall"})
	end
	for _, w in {{px1 - 1, pz1 - 1, px2 + 1, pz1 + 1.4}, {px1 - 1, pz2 - 1.4, px2 + 1, pz2 + 1}, {px1 - 1, pz1 + 1.4, px1 + 1.4, pz2 - 1.4}, {px2 - 1.4, pz1 + 1.4, px2 + 1, pz2 - 1.4}} do
		core.block(pond, w[1], 0, w[2], w[3], 0.6, w[4], stone, mat.Concrete, {Name = "Coping"})
	end
	core.block(pond, px1 + 1.2, -3, pz1 + 1.2, px2 - 1.2, -0.9, pz2 - 1.2, core.rgb(55, 120, 150), mat.Glass, {Name = "Water", Transparency = 0.35, CanCollide = false, CastShadow = false, Reflectance = 0.15})
	for _, sx in {-1, 1} do
		local x = sx < 0 and px1 + 1.2 or px2 - 1.2
		for i = 0, 3 do
			local w = 3 - i * 0.75
			core.block(pond, sx < 0 and x or x - w, -3, 62, sx < 0 and x + w or x, -2.25 + i * 0.75, 78, stone, mat.Concrete, {Name = "Steps"})
		end
	end
	local isl = core.model("Island", pond)
	core.cylY(isl, CFrame.new(-95, 0, 70), 0, -1.5, 0, 3, 30, core.rgb(120, 115, 105), mat.Cobblestone)
	core.cylY(isl, CFrame.new(-95, 0, 70), 0, 0.05, 0, 0.3, 28.4, lawnCol, mat.Grass)
	P.tree(isl, CFrame.new(-98, 0.2, 74), 1.3, "oak")
	P.bush(isl, CFrame.new(-87, 0.2, 66), 1, true)
	P.bush(isl, CFrame.new(-103, 0.2, 64), 0.9)
	P.rock(isl, CFrame.new(-88, 0.2, 77), 0.7)
	P.parkBench(isl, CFrame.new(-95, 0.2, 60) * CFrame.Angles(0, math.pi, 0), 6)
	pk.bridge(pond, V(-95, 0, 26), V(-95, 0, 57), 7, 3.2)
	pk.bridge(pond, V(-95, 0, 83), V(-95, 0, 113), 7, 3.2)
	local reedCol = {core.rgb(90, 130, 60), core.rgb(110, 140, 70)}
	for i = 1, 24 do
		local side = rng:NextInteger(1, 4)
		local x = side <= 2 and rng:NextNumber(px1 + 3, px2 - 3) or (side == 3 and px1 + rng:NextNumber(2.5, 4) or px2 - rng:NextNumber(2.5, 4))
		local z = side == 1 and pz1 + rng:NextNumber(2.5, 4) or side == 2 and pz2 - rng:NextNumber(2.5, 4) or rng:NextNumber(pz1 + 3, pz2 - 3)
		if math.abs(x + 95) > 6 and not (math.abs(z - 70) < 9 and (side == 3 or side == 4)) then
			local m = core.model("Reeds", pond)
			for k = 1, 6 do
				local h = rng:NextNumber(3, 5)
				local dx, dz = rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8)
				core.seg(m, CFrame.new(), V(x + dx, -3, z + dz), V(x + dx * 1.6, -3 + h, z + dz * 1.6), 0.12, reedCol[rng:NextInteger(1, 2)], mat.SmoothPlastic, {CanCollide = false})
				if k <= 2 then core.cylY(m, CFrame.new(), x + dx * 1.5, -3 + h - 0.6, z + dz * 1.5, 0.9, 0.28, core.rgb(110, 75, 48), mat.Fabric, {CanCollide = false}) end
			end
		end
	end
	for i = 1, 6 do
		local lx, lz = rng:NextNumber(px1 + 6, px2 - 6), rng:NextNumber(pz1 + 5, pz2 - 5)
		if (V(lx, 0, lz) - V(-95, 0, 70)).Magnitude > 17 and math.abs(lx + 95) > 6 then
			core.cylY(pond, CFrame.new(), lx, -0.88, lz, 0.04, rng:NextNumber(1.6, 2.6), lawnCol, mat.SmoothPlastic, {CanCollide = false, Name = "Lily Pad"})
			if i % 2 == 0 then core.ball(pond, CFrame.new(), lx, -0.75, lz, 0.5, core.rgb(255, 180, 210), mat.SmoothPlastic, {CanCollide = false}) end
		end
	end
	for _, d in {{-130, 50}, {-60, 90}, {-125, 92}, {-70, 48}} do P.duck(pond, CFrame.new(d[1], -1.25, d[2]) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)) end
	for _, r in {{px1 - 4, 40, 0.8}, {px2 + 4, 100, 0.7}, {-60, pz2 + 4.5, 0.6}, {-140, pz1 - 4.5, 0.6}} do P.rock(pond, CFrame.new(r[1], 0, r[2]), r[3]) end

	local fountain = core.model("Fountain")
	local fc = CFrame.new(0, 0.2, 0)
	core.cylY(fountain, fc, 0, 0.9, 0, 1.8, 30, stone, mat.Concrete)
	core.cylY(fountain, fc, 0, 1.95, 0, 0.3, 31, stone, mat.Marble)
	core.cylY(fountain, fc, 0, 1.2, 0, 1.6, 28.4, core.rgb(55, 120, 150), mat.Glass, {Transparency = 0.25, CanCollide = false, Name = "Water", Reflectance = 0.2})
	core.cylY(fountain, fc, 0, 0.6, 0, 0.4, 28.6, core.rgb(80, 100, 110), mat.Slate)
	core.cylY(fountain, fc, 0, 3.4, 0, 4.6, 3.6, stone, mat.Marble)
	core.cylY(fountain, fc, 0, 6, 0, 0.8, 14, stone, mat.Marble)
	core.cylY(fountain, fc, 0, 6.3, 0, 0.6, 12.6, core.rgb(55, 120, 150), mat.Glass, {Transparency = 0.25, CanCollide = false})
	core.cylY(fountain, fc, 0, 8.4, 0, 4, 2.2, stone, mat.Marble)
	core.cylY(fountain, fc, 0, 10.6, 0, 0.6, 7, stone, mat.Marble)
	core.cylY(fountain, fc, 0, 10.85, 0, 0.3, 6, core.rgb(55, 120, 150), mat.Glass, {Transparency = 0.25, CanCollide = false})
	core.cylY(fountain, fc, 0, 12, 0, 2.2, 1.1, stone, mat.Marble)
	core.ball(fountain, fc, 0, 13.4, 0, 1.6, stone, mat.Marble)
	core.cylY(fountain, fc, 0, 15, 0, 2.6, 0.5, core.rgb(200, 230, 245), mat.Glass, {Transparency = 0.4, CanCollide = false})
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		core.seg(fountain, fc, V(math.cos(a) * 6.6, 6.3, math.sin(a) * 6.6), V(math.cos(a) * 9, 1.9, math.sin(a) * 9), 0.3, core.rgb(200, 230, 245), mat.Glass, {Transparency = 0.45, CanCollide = false})
		core.seg(fountain, fc, V(math.cos(a) * 3.2, 10.8, math.sin(a) * 3.2), V(math.cos(a) * 5.4, 6.4, math.sin(a) * 5.4), 0.25, core.rgb(200, 230, 245), mat.Glass, {Transparency = 0.45, CanCollide = false})
		local fa = a + math.pi / 8
		core.ball(fountain, fc, math.cos(fa) * 14.6, 2.4, math.sin(fa) * 14.6, 0.9, stone, mat.Marble)
	end
	for i = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, 13)
		core.cylY(fountain, fc, math.cos(a) * r, 0.82, math.sin(a) * r, 0.04, 0.3, ({c.yellow, c.steel, core.rgb(184, 115, 51)})[rng:NextInteger(1, 3)], mat.Metal, {CanCollide = false, Name = "Coin"})
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		P.parkBench(fountain, CFrame.lookAt(V(math.cos(a) * 21, 0.2, math.sin(a) * 21), V(math.cos(a) * 40, 0.2, math.sin(a) * 40)), 7)
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		P.lamp(fountain, CFrame.new(math.cos(a) * 33, 0.2, math.sin(a) * 33))
		P.flowerBed(fountain, CFrame.lookAt(V(math.cos(a) * 27.5, 0.2, math.sin(a) * 27.5), V(0, 0.2, 0)), 8, 4)
	end
end
