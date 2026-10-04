--!strict
-- Hitbox Module
-- Usage: local hitbox = Hitbox.new(params, hitboxPart)
-- hitbox:Start()            → begins shapecasting each heartbeat
-- hitbox:Stop()             → halts shapecasting
-- hitbox:ShowVisualizer()   → renders the hitbox + sweep + hit markers every frame
-- hitbox:HideVisualizer()   → removes all visualizer parts
-- hitbox.onHit              → callback fired with every HitboxResult

local RunService = game:GetService("RunService")

-- ─── Types ───────────────────────────────────────────────────────────────────

export type HitboxParams = {
	castDirection: Vector3?,   -- defaults to part's LookVector
	castLength: number?,       -- defaults to 0 (pure overlap); set > 0 for a sweep
	raycastParams: RaycastParams?,
	castInterval: number?,     -- seconds between casts; nil = every Heartbeat
	filterRepeats: boolean?,   -- skip already-hit instances until Stop()
	sweepWithPartMotion: boolean?,
	motionSampleCount: number?,
}

export type HitboxResult = {
	instance: Instance,
	position: Vector3,
	normal:   Vector3,
	material: Enum.Material,
	distance: number,
}

export type Hitbox = {
	Start:          (self: Hitbox) -> (),
	Stop:           (self: Hitbox) -> (),
	Destroy:        (self: Hitbox) -> (),
	ShowVisualizer: (self: Hitbox) -> (),
	HideVisualizer: (self: Hitbox) -> (),

	onHit:    ((result: HitboxResult) -> ())?,
	isActive: boolean,
}

-- ─── Private impl type ───────────────────────────────────────────────────────

type VisualizerState = {
	folder:          Folder,
	castBox:         Part,         -- mirrors the hitbox volume
	sweepBox:        Part,         -- elongated box showing the sweep path
	hitMarkerPool:   { Part },     -- reused hit-point spheres
	connection:      RBXScriptConnection?,
	lastHitPositions: { Vector3 }, -- positions from the most recent cast
}

type HitboxImpl = Hitbox & {
	_params:     HitboxParams,
	_part:       BasePart,
	_connection: RBXScriptConnection?,
	_elapsed:    number,
	_hitFilter:  { [Instance]: boolean },
	_lastHits:   { HitboxResult },
	_lastCFrame: CFrame?,
	_lastCastCFrame: CFrame?,
	_lastCastDirection: Vector3,
	_vis:        VisualizerState?,
}


local VIS_CAST_COLOR  = Color3.fromRGB(0, 200, 255) 
local VIS_HIT_COLOR   = Color3.fromRGB(255, 60,  60) 
local VIS_SWEEP_COLOR = Color3.fromRGB(255, 200, 0)  
local VIS_MARKER_COLOR = Color3.fromRGB(255, 255, 255)
local VIS_TRANSPARENCY = 0.55
local VIS_SWEEP_TRANSPARENCY = 0.75
local VIS_MARKER_SIZE  = Vector3.new(0.35, 0.35, 0.35)
local VIS_MARKER_POOL_SIZE = 20 


local function makeAdornPart(name: string, color: Color3, size: Vector3, transparency: number): Part
	local p      = Instance.new("Part")
	p.Name        = name
	p.Anchored    = true
	p.CanCollide  = false
	p.CanQuery    = false
	p.CanTouch    = false
	p.CastShadow  = false
	p.Color        = color
	p.Material     = Enum.Material.Neon
	p.Size         = size
	p.Transparency = transparency
	return p
end

local function buildVisualizer(part: BasePart): VisualizerState
	local folder = Instance.new("Folder")
	folder.Name  = "HitboxVisualizer"
	folder.Parent = workspace

	-- Cast box: mirrors the hitbox part exactly
	local castBox = makeAdornPart("CastBox", VIS_CAST_COLOR, part.Size, VIS_TRANSPARENCY)
	castBox.Parent = folder

	-- Sweep box: shows the direction+length of the cast (updated each frame)
	local sweepBox = makeAdornPart("SweepBox", VIS_SWEEP_COLOR, Vector3.new(0, 0, 0), VIS_SWEEP_TRANSPARENCY)
	sweepBox.Parent = folder

	-- Hit marker pool
	local pool: { Part } = {}
	for i = 1, VIS_MARKER_POOL_SIZE do
		local m = makeAdornPart("HitMarker" .. i, VIS_MARKER_COLOR, VIS_MARKER_SIZE, 1)
		m.Shape  = Enum.PartType.Ball
		m.Parent  = folder
		pool[i]   = m
	end

	return {
		folder           = folder,
		castBox          = castBox,
		sweepBox         = sweepBox,
		hitMarkerPool    = pool,
		connection       = nil,
		lastHitPositions = {},
	}
end

local function destroyVisualizer(vis: VisualizerState)
	if vis.connection then
		vis.connection:Disconnect()
		vis.connection = nil
	end
	vis.folder:Destroy()
end

-- Updates all visualizer parts to reflect the current state of the hitbox.
local function updateVisualizer(self: HitboxImpl)
	local vis  = self._vis
	if not vis then return end

	local part   = self._part
	local params = self._params
	local castDir = self._lastCastDirection
	local castLen = castDir.Magnitude
	local castCFrame = self._lastCastCFrame or part.CFrame

	if castLen <= 0 then
		castLen = params.castLength or 0
		if params.castDirection and params.castDirection.Magnitude > 0 then
			castDir = params.castDirection.Unit * castLen
		else
			castDir = part.CFrame.LookVector * castLen
		end
		castCFrame = part.CFrame
	end

	-- ── Cast box ──────────────────────────────────────────────────────────────
	vis.castBox.Size  = part.Size
	vis.castBox.CFrame = part.CFrame

	-- Flash red when something was hit this frame, otherwise cyan
	if #self._lastHits > 0 then
		vis.castBox.Color = VIS_HIT_COLOR
	else
		vis.castBox.Color = VIS_CAST_COLOR
	end

	-- ── Sweep box ─────────────────────────────────────────────────────────────
	-- The sweep box sits half-way between the origin and the cast end point,
	-- elongated along the cast direction. If castLength is 0 it's hidden.
	if castLen > 0 then
		vis.sweepBox.Transparency = VIS_SWEEP_TRANSPARENCY

		-- Dimensions: same cross-section as the hitbox, cast-length deep
		vis.sweepBox.Size = Vector3.new(part.Size.X, part.Size.Y, castLen)

		-- Position: offset from part centre by half the cast vector, then rotated
		-- so the box aligns with the cast direction.
		local dir = castDir.Magnitude > 0 and castDir.Unit or castCFrame.LookVector
		local sweepCF = CFrame.lookAt(castCFrame.Position, castCFrame.Position + dir) * CFrame.new(0, 0, -castLen / 2)
		vis.sweepBox.CFrame = sweepCF
	else
		vis.sweepBox.Transparency = 1
	end

	-- ── Hit markers ───────────────────────────────────────────────────────────
	local pool = vis.hitMarkerPool
	for i, marker in ipairs(pool) do
		local hitResult = self._lastHits[i]
		if hitResult then
			marker.Transparency = 0
			-- Face the surface normal
			marker.CFrame  = CFrame.new(hitResult.position, hitResult.position + hitResult.normal)
		else
			marker.Transparency = 1
		end
	end
end

-- ─── Cast logic ──────────────────────────────────────────────────────────────

local function getFilterList(rParams: RaycastParams, extraInstances: { Instance }, vis: VisualizerState?): { Instance }
	local filterList = { table.unpack(rParams.FilterDescendantsInstances) }
	for _, instance in ipairs(extraInstances) do
		table.insert(filterList, instance)
	end
	if vis then
		table.insert(filterList, vis.folder)
	end
	return filterList
end

local function makeRaycastParams(rParams: RaycastParams, extraInstances: { Instance }, vis: VisualizerState?): RaycastParams
	local workParams = RaycastParams.new()
	workParams.FilterType = rParams.FilterType
	workParams.FilterDescendantsInstances = getFilterList(rParams, extraInstances, vis)
	workParams.IgnoreWater = rParams.IgnoreWater
	workParams.CollisionGroup = rParams.CollisionGroup
	return workParams
end

local function makeOverlapParams(rParams: RaycastParams, extraInstances: { Instance }, vis: VisualizerState?): OverlapParams
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = rParams.FilterType
	overlapParams.FilterDescendantsInstances = getFilterList(rParams, extraInstances, vis)
	overlapParams.CollisionGroup = rParams.CollisionGroup
	overlapParams.MaxParts = 50
	return overlapParams
end

local function getClosestPoint(part: BasePart, worldPoint: Vector3): Vector3
	local localPoint = part.CFrame:PointToObjectSpace(worldPoint)
	local halfSize = part.Size * 0.5
	local clampedPoint = Vector3.new(
		math.clamp(localPoint.X, -halfSize.X, halfSize.X),
		math.clamp(localPoint.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
	)
	return part.CFrame:PointToWorldSpace(clampedPoint)
end

local function getNormal(origin: Vector3, position: Vector3): Vector3
	local offset = position - origin
	if offset.Magnitude > 0.001 then
		return offset.Unit
	end
	return Vector3.new(0, 1, 0)
end

local function performCast(self: HitboxImpl, deltaTime: number)
	local part = self._part
	if not part:IsDescendantOf(workspace) then return end

	local params = self._params
	local rParams = params.raycastParams or RaycastParams.new()
	local currentCFrame = part.CFrame
	local lastCFrame = self._lastCFrame or currentCFrame
	local castLen = params.castLength or 0
	local configuredDirection = Vector3.zero
	local motionDirection = currentCFrame.Position - lastCFrame.Position

	if castLen > 0 then
		if params.castDirection and params.castDirection.Magnitude > 0 then
			configuredDirection = params.castDirection.Unit * castLen
		else
			configuredDirection = currentCFrame.LookVector * castLen
		end
	end

	self._lastCastCFrame = configuredDirection.Magnitude >= motionDirection.Magnitude and currentCFrame or lastCFrame
	self._lastCastDirection = configuredDirection.Magnitude >= motionDirection.Magnitude and configuredDirection or motionDirection

	local hitResults: { HitboxResult } = {}
	local seenParts: { [Instance]: boolean } = {}
	local extraExclusions: { Instance } = {}

	local function addHit(hitPart: BasePart, position: Vector3, normal: Vector3, material: Enum.Material, distance: number)
		if seenParts[hitPart] or #hitResults >= 50 then return end
		seenParts[hitPart] = true
		table.insert(hitResults, {
			instance = hitPart,
			position = position,
			normal = normal,
			material = material,
			distance = distance,
		})
	end

	local function addOverlap(cframe: CFrame)
		local overlapParams = makeOverlapParams(rParams, extraExclusions, self._vis)
		for _, hitPart in ipairs(workspace:GetPartBoundsInBox(cframe, part.Size, overlapParams)) do
			local position = getClosestPoint(hitPart, cframe.Position)
			addHit(hitPart, position, getNormal(cframe.Position, position), hitPart.Material, (position - cframe.Position).Magnitude)
			table.insert(extraExclusions, hitPart)
		end
	end

	local function addBlockcast(cframe: CFrame, direction: Vector3)
		if direction.Magnitude <= 0.001 then return end

		while #hitResults < 50 do
			local workParams = makeRaycastParams(rParams, extraExclusions, self._vis)
			local result = workspace:Blockcast(cframe, part.Size, direction, workParams)
			if not result then break end

			if result.Instance:IsA("BasePart") then
				addHit(result.Instance, result.Position, result.Normal, result.Material, result.Distance)
			end
			table.insert(extraExclusions, result.Instance)
		end
	end

	local sampleCount = math.floor(math.clamp(tonumber(params.motionSampleCount) or 4, 1, 12))
	for sample = 0, sampleCount do
		addOverlap(lastCFrame:Lerp(currentCFrame, sample / sampleCount))
	end

	if params.sweepWithPartMotion ~= false then
		addBlockcast(lastCFrame, motionDirection)
	end
	addBlockcast(currentCFrame, configuredDirection)

	self._lastCFrame = currentCFrame
	self._lastHits = {}

	for _, hitResult in ipairs(hitResults) do
		local hitInst = hitResult.instance
		if params.filterRepeats and self._hitFilter[hitInst] then
			continue
		end
		if params.filterRepeats then
			self._hitFilter[hitInst] = true
		end

		table.insert(self._lastHits, hitResult)
		if self.onHit then
			self.onHit(hitResult)
		end
	end
end

-- ─── Module ──────────────────────────────────────────────────────────────────

local Hitbox = {}
Hitbox.__index = Hitbox

-- ─── Constructor ─────────────────────────────────────────────────────────────

function Hitbox.new(params: HitboxParams, hitboxPart: BasePart): Hitbox
	assert(
		typeof(hitboxPart) == "Instance" and hitboxPart:IsA("BasePart"),
		"[Hitbox] hitboxPart must be a BasePart"
	)

	local self: HitboxImpl = setmetatable({} :: any, Hitbox)

	self._params     = params
	self._part       = hitboxPart
	self._connection = nil
	self._elapsed    = 0
	self._hitFilter  = {}
	self._lastHits   = {}
	self._lastCFrame = nil
	self._lastCastCFrame = nil
	self._lastCastDirection = Vector3.zero
	self._vis        = nil
	self.isActive    = false
	self.onHit       = nil

	return self
end

-- ─── Core methods ────────────────────────────────────────────────────────────

function Hitbox:Start()
	local self = self :: HitboxImpl
	if self.isActive then return end

	self.isActive   = true
	self._elapsed   = 0
	self._hitFilter = {}
	self._lastHits  = {}
	self._lastCFrame = self._part.CFrame
	self._lastCastCFrame = self._part.CFrame
	self._lastCastDirection = Vector3.zero

	self._connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not self.isActive then return end

		local interval = self._params.castInterval
		if interval and interval > 0 then
			self._elapsed += deltaTime
			if self._elapsed < interval then return end
			self._elapsed = 0
		end

		performCast(self, deltaTime)
	end)
end

function Hitbox:Stop()
	local self = self :: HitboxImpl

	self.isActive  = false
	self._lastHits = {}
	self._lastCFrame = nil
	self._lastCastDirection = Vector3.zero

	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	-- Clear visualizer decorations when stopped
	if self._vis then
		self._vis.castBox.Color = VIS_CAST_COLOR
		for _, marker in ipairs(self._vis.hitMarkerPool) do
			marker.Transparency = 1
		end
	end
end

function Hitbox:Destroy()
	local self = self :: HitboxImpl

	self:Stop()
	self:HideVisualizer()
	self.onHit      = nil
	self._params    = {} :: any
	self._hitFilter = {}
end

-- ─── Visualizer methods ──────────────────────────────────────────────────────

--[[
	ShowVisualizer()
	Spawns a set of neon parts in workspace that track the hitbox every frame:
	  • Cyan box  – the hitbox volume (flashes red on hit)
	  • Gold box  – the sweep path (only visible when castLength > 0)
	  • White spheres – one per hit point returned by the most recent cast

	Safe to call before or after Start(). Works even when the hitbox is stopped
	(shows the resting shape). Call HideVisualizer() to clean up.
--]]
function Hitbox:ShowVisualizer()
	local self = self :: HitboxImpl
	if self._vis then return end   -- already showing

	self._vis = buildVisualizer(self._part)

	-- Drive the visual update every RenderStepped (client) or Heartbeat (server)
	local updateSignal = RunService:IsClient()
		and RunService.RenderStepped
		or  RunService.Heartbeat

	self._vis.connection = updateSignal:Connect(function()
		updateVisualizer(self)
	end)
end

--[[
	HideVisualizer()
	Removes all visualizer parts and disconnects the render loop.
	Safe to call even if ShowVisualizer was never called.
--]]
function Hitbox:HideVisualizer()
	local self = self :: HitboxImpl
	if not self._vis then return end

	destroyVisualizer(self._vis)
	self._vis = nil
end

-- ─── Return ──────────────────────────────────────────────────────────────────

return Hitbox