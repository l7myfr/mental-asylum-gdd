local CollectionService = game:GetService("CollectionService")

local hallwayLength = 80
local hallwayWidth = 14
local hallwayHeight = 12
local wallThickness = 1
local cellSpacing = 10
local floorTop = 1

local wallColor = Color3.fromRGB(150, 155, 140)
local floorColor = Color3.fromRGB(90, 95, 85)
local doorColor = Color3.fromRGB(60, 62, 58)

local hallway = Instance.new("Model")
hallway.Name = "Hallway"

local function makePart(name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = hallway
	return part
end

local wallX = hallwayWidth / 2 + wallThickness / 2
local wallY = floorTop + hallwayHeight / 2
local endZ = hallwayLength / 2 + wallThickness / 2

makePart("Floor", Vector3.new(hallwayWidth, 1, hallwayLength), CFrame.new(0, floorTop - 0.5, 0), floorColor, Enum.Material.Concrete)
makePart("Ceiling", Vector3.new(hallwayWidth + wallThickness * 2, 1, hallwayLength + wallThickness * 2), CFrame.new(0, floorTop + hallwayHeight + 0.5, 0), wallColor, Enum.Material.Plaster)

for _, side in { -1, 1 } do
	makePart("SideWall", Vector3.new(wallThickness, hallwayHeight, hallwayLength), CFrame.new(side * wallX, wallY, 0), wallColor, Enum.Material.Plaster)
	makePart("EndWall", Vector3.new(hallwayWidth + wallThickness * 2, hallwayHeight, wallThickness), CFrame.new(0, wallY, side * endZ), wallColor, Enum.Material.Plaster)
end

-- Cell doors on both walls, with a dark viewing slot near the top of each door.
for z = -hallwayLength / 2 + cellSpacing, hallwayLength / 2 - cellSpacing, cellSpacing do
	for _, side in { -1, 1 } do
		local doorX = side * (hallwayWidth / 2 - 0.2)
		makePart("CellDoor", Vector3.new(0.4, 8, 5), CFrame.new(doorX, floorTop + 4, z), doorColor, Enum.Material.DiamondPlate)
		makePart("ViewingSlot", Vector3.new(0.5, 1, 2.5), CFrame.new(doorX - side * 0.05, floorTop + 6.5, z), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	end
end

-- Ceiling lights sit between the doors; tagged so FlickerLights can find them.
for z = -hallwayLength / 2 + cellSpacing / 2, hallwayLength / 2 - cellSpacing / 2, cellSpacing do
	local fixture = makePart("LightFixture", Vector3.new(2, 0.3, 4), CFrame.new(0, floorTop + hallwayHeight - 0.15, z), Color3.fromRGB(230, 240, 210), Enum.Material.Neon)
	fixture.CanCollide = false

	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(220, 235, 200)
	light.Shadows = true
	light.Parent = fixture

	CollectionService:AddTag(fixture, "FlickerLight")
end

local spawn = Instance.new("SpawnLocation")
spawn.Name = "HallwaySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(4, 0.2, 4)
spawn.CFrame = CFrame.new(0, floorTop + 0.1, -hallwayLength / 2 + 5)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Parent = hallway

hallway.Parent = workspace
