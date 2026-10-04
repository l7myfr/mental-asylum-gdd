--!strict
--[[
    Source: https://github.com/probablytukars/LuaQuaternion
    Based on: https://github.com/Quenty/NevermoreEngine/tree/main/src/spring
    [MIT LICENSE]

    Impulse() fixed by @crusherfire
    UDim2 support added
--]]

local errorFormat = "%q is not a valid member of Spring."

export type nlerpable = number | Vector2 | Vector3 | UDim2

local Spring = {_type = "Spring"}

type t_Spring<T = nlerpable> = {
	new: (initial: T, damping: number, speed: number, clock: () -> number) -> Spring<T>,
	Reset: (target: T?) -> nil,
	Impulse: (self: Spring<T>, velocity: T) -> nil,
	TimeSkip: (self: Spring<T>, delta: number) -> nil,

	Position: T,
	p: T,
	Velocity: T,
	v: T,
	Target: T,
	t: T,
	Damping: number,
	d: number,
	Speed: number,
	s: number,
	Clock: () -> number,

	_clock: () -> number,
	_time: number,
	_position: T,
	_velocity: T,
	_target: T,
	_damping: number,
	_speed: number,
	_initial: T,
}

export type Spring<T = nlerpable> = typeof(setmetatable({} :: t_Spring<T>, Spring))


--[=[
    @class Spring
    @grouporder ["Constructors", "Methods"]

    This class represents a spring, which can handle any object which is
    n-lerpable (numbers, Vector3s, UDim2s, etc).

    This is lazily evaluated meaning it only updates when indexed.
]=]

-- Returns the zero value for a given nlerpable type.
local function zero(value: nlerpable): nlerpable
	if typeof(value) == "UDim2" then
		return UDim2.new(0, 0, 0, 0)
	else
		return (value :: any) * 0
	end
end

-- Adds two nlerpable values.
local function add(a: nlerpable, b: nlerpable): nlerpable
	if typeof(a) == "UDim2" then
		local ua, ub = a :: UDim2, b :: UDim2
		return UDim2.new(
			ua.X.Scale  + ub.X.Scale,
			ua.X.Offset + ub.X.Offset,
			ua.Y.Scale  + ub.Y.Scale,
			ua.Y.Offset + ub.Y.Offset
		)
	else
		return (a :: any) + b
	end
end

-- Subtracts b from a.
local function sub(a: nlerpable, b: nlerpable): nlerpable
	if typeof(a) == "UDim2" then
		local ua, ub = a :: UDim2, b :: UDim2
		return UDim2.new(
			ua.X.Scale  - ub.X.Scale,
			ua.X.Offset - ub.X.Offset,
			ua.Y.Scale  - ub.Y.Scale,
			ua.Y.Offset - ub.Y.Offset
		)
	else
		return (a :: any) - b
	end
end

-- Multiplies a nlerpable by a scalar.
local function scale(a: nlerpable, s: number): nlerpable
	if typeof(a) == "UDim2" then
		local ua = a :: UDim2
		return UDim2.new(
			ua.X.Scale  * s,
			ua.X.Offset * s,
			ua.Y.Scale  * s,
			ua.Y.Offset * s
		)
	else
		return (a :: any) * s
	end
end


--[=[
    @function
    @group Constructors

    Constructs a new Spring at the position and target specified, of type <T>.
]=]
function Spring.new<T>(initial: T, damping: number?, speed: number?, clock: (() -> number)?)
	local lDamping = damping or 1
	local lSpeed = speed or 1
	local lClock = clock or os.clock

	local self = {
		_clock    = lClock;
		_time     = lClock();
		_position = initial;
		_velocity = zero(initial :: any) :: T;
		_target   = initial;
		_damping  = lDamping;
		_speed    = lSpeed;
		_initial  = initial;
	}

	return setmetatable(self :: t_Spring<T>, Spring)
end

--[=[
    @method
    @group Methods

    Resets the springs' position and target to the target value provided, or
    to the initial value the spring was created with if target is not specified.
    Sets the velocity to zero.
]=]
local function Reset(self: Spring, target: nlerpable?)
	local now = self._clock()
	local setTo = target or self._initial
	self._position = setTo
	self._target   = setTo
	self._velocity = zero(setTo :: any)
	self._time     = now
end

Spring.Reset = Reset

--[=[
    @method
    @group Methods

    Impulses the spring, increasing velocity by the amount given.
    This is useful to make something shake.
]=]
local function Impulse<T>(self: Spring<T>, velocity: T)
	self.Velocity = add(self.Velocity :: any, velocity :: any) :: any
end

Spring.Impulse = Impulse

local function positionVelocity(self: Spring, now: number)
	local currentPosition = self._position
	local currentVelocity = self._velocity
	local targetPosition  = self._target
	local dampingFactor   = self._damping
	local speed           = self._speed

	local deltaTime    = speed * (now - self._time)
	local dampingSquared = dampingFactor * dampingFactor

	local angFreq, sinTheta, cosTheta
	if dampingSquared < 1 then
		angFreq = math.sqrt(1 - dampingSquared)
		local exponential = math.exp(-dampingFactor * deltaTime) / angFreq
		cosTheta = exponential * math.cos(angFreq * deltaTime)
		sinTheta = exponential * math.sin(angFreq * deltaTime)
	elseif dampingSquared == 1 then
		angFreq = 1
		local exponential = math.exp(-dampingFactor * deltaTime) / angFreq
		cosTheta, sinTheta = exponential, exponential * deltaTime
	else
		angFreq = math.sqrt(dampingSquared - 1)
		local angFreq2 = 2 * angFreq
		local u = math.exp((-dampingFactor + angFreq) * deltaTime) / angFreq2
		local v = math.exp((-dampingFactor - angFreq) * deltaTime) / angFreq2
		cosTheta, sinTheta = u + v, u - v
	end

	local pullToTarget  = 1 - (angFreq * cosTheta + dampingFactor * sinTheta)
	local velPosPush    = sinTheta / speed
	local velPushRate   = speed * sinTheta
	local velocityDecay = angFreq * cosTheta - dampingFactor * sinTheta

	local positionDifference = sub(targetPosition :: any, currentPosition :: any)

	local newPosition = add(
		add(currentPosition :: any, scale(positionDifference, pullToTarget)),
		scale(currentVelocity :: any, velPosPush)
	)

	local newVelocity = add(
		scale(positionDifference, velPushRate),
		scale(currentVelocity :: any, velocityDecay)
	)

	return newPosition, newVelocity
end


--[=[
    @method
    @group Methods
    Instantly skips the spring forwards by the given time.
]=]
local function TimeSkip(self: Spring, delta: number)
	local now = self._clock()
	local position, velocity = positionVelocity(self, now + delta)
	self._position = position
	self._velocity = velocity
	self._time     = now
end

Spring.TimeSkip = TimeSkip


function Spring.__index(self: Spring, index)
	if Spring[index] then
		return Spring[index]
	elseif index == "Position" or index == "p" then
		local position, _ = positionVelocity(self, self._clock())
		return position
	elseif index == "Velocity" or index == "v" then
		local _, velocity = positionVelocity(self, self._clock())
		return velocity
	elseif index == "Target" or index == "t" then
		return self._target
	elseif index == "Damping" or index == "d" then
		return self._damping
	elseif index == "Speed" or index == "s" then
		return self._speed
	elseif index == "Clock" then
		return self._clock
	elseif index == "Initial" then
		return self._initial
	end
	error(string.format(errorFormat, tostring(index)), 2)
end

function Spring.__newindex(self: Spring, index, value: any)
	local now = self._clock()
	if index == "Position" or index == "p" then
		local _, velocity = positionVelocity(self, now)
		self._position = value
		self._velocity = velocity
		self._time     = now
	elseif index == "Velocity" or index == "v" then
		local position, _ = positionVelocity(self, now)
		self._position = position
		self._velocity = value
		self._time     = now
	elseif index == "Target" or index == "t" then
		local position, velocity = positionVelocity(self, now)
		self._position = position
		self._velocity = velocity
		self._target   = value
		self._time     = now
	elseif index == "Damping" or index == "d" then
		local position, velocity = positionVelocity(self, now)
		self._position = position
		self._velocity = velocity
		self._damping  = value
		self._time     = now
	elseif index == "Speed" or index == "s" then
		local position, velocity = positionVelocity(self, now)
		self._position = position
		self._velocity = velocity
		self._speed    = value < 0 and 0 or value
		self._time     = now
	elseif index == "Clock" then
		local position, velocity = positionVelocity(self, now)
		self._position = position
		self._velocity = velocity
		self._clock    = value
		self._time     = value()
	elseif index == "Initial" then
		self._initial = value
	elseif index == "Position" then
		self._position = value
	else
		error(string.format(errorFormat, tostring(index)), 2)
	end
end

return Spring