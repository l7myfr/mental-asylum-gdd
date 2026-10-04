--[[
╔═══════════════════════════════════════════════════════════════╗
║  Configify  —  Real-time config editor (core module)          ║
║  Place in: ReplicatedStorage.Configify                        ║
╚═══════════════════════════════════════════════════════════════╝

    Usage:
        local Configify  = require(game.ReplicatedStorage.Configify)
        local GunConfigs = require(...)

        local cfg = Configify.new("SMG9", GunConfigs["SMG9"])
        cfg:buildUI()

    Nested tables are flattened to dot-path keys:
        GunConfigs["SMG9"].Recoil.Vertical  →  key "Recoil.Vertical"
        Writes go directly back into the original nested table.
]]

local Configify   = {}
Configify.__index = Configify

-- ─── Type helpers ────────────────────────────────────────────────────────────
local function getType(v)
	local t = typeof(v)
	if     t == "number"  then return "number"
	elseif t == "boolean" then return "boolean"
	elseif t == "string"  then return "string"
	elseif t == "Vector2" then return "Vector2"
	elseif t == "Vector3" then return "Vector3"
	elseif t == "CFrame"  then return "CFrame"
	elseif t == "Color3"  then return "Color3"
	elseif t == "UDim2"   then return "UDim2"
	elseif t == "UDim"    then return "UDim"
	end
	-- returns nil for plain tables (drill into them) and unsupported types
end

-- ─── Parsers ─────────────────────────────────────────────────────────────────
local parsers = {}

parsers.number  = function(r) local n = tonumber(r); return n, n == nil and "Expected number" or nil end
parsers.boolean = function(r)
	local s = r:lower():match("^%s*(.-)%s*$")
	if s=="true"  or s=="1" then return true  end
	if s=="false" or s=="0" then return false end
	return nil, "Expected true/false"
end
parsers.string  = function(r) return r end
parsers.Vector2 = function(r)
	local x,y = r:match("^([%d%.%-]+)%s*[,%s]+([%d%.%-]+)$")
	if not x then return nil,"Expected X, Y" end
	return Vector2.new(tonumber(x),tonumber(y))
end
parsers.Vector3 = function(r)
	local x,y,z = r:match("^([%d%.%-]+)%s*[,%s]+([%d%.%-]+)%s*[,%s]+([%d%.%-]+)$")
	if not x then return nil,"Expected X, Y, Z" end
	return Vector3.new(tonumber(x),tonumber(y),tonumber(z))
end
parsers.CFrame = function(r)
	local p={}; for v in r:gmatch("[%d%.%-]+") do p[#p+1]=tonumber(v) end
	if     #p==3  then return CFrame.new(p[1],p[2],p[3])
	elseif #p==6  then return CFrame.new(p[1],p[2],p[3])*CFrame.Angles(math.rad(p[4]),math.rad(p[5]),math.rad(p[6]))
	elseif #p==12 then return CFrame.new(table.unpack(p))
	else return nil,"Expected 3 / 6 / 12 numbers" end
end
parsers.Color3 = function(r)
	local a,b,c = r:match("^([%d%.]+)%s*[,%s]+([%d%.]+)%s*[,%s]+([%d%.]+)$")
	if not a then return nil,"Expected R, G, B" end
	a,b,c=tonumber(a),tonumber(b),tonumber(c)
	return (a>1 or b>1 or c>1) and Color3.fromRGB(a,b,c) or Color3.new(a,b,c)
end
parsers.UDim  = function(r)
	local s,o = r:match("^([%d%.%-]+)%s*[,%s]+([%d%.%-]+)$")
	if not s then return nil,"Expected Scale, Offset" end
	return UDim.new(tonumber(s),tonumber(o))
end
parsers.UDim2 = function(r)
	local xs,xo,ys,yo = r:match("^([%d%.%-]+)%s*[,%s]+([%d%.%-]+)%s*[,%s]+([%d%.%-]+)%s*[,%s]+([%d%.%-]+)$")
	if not xs then return nil,"Expected XScale, XOffset, YScale, YOffset" end
	return UDim2.new(tonumber(xs),tonumber(xo),tonumber(ys),tonumber(yo))
end

-- ─── Serialisers ─────────────────────────────────────────────────────────────
local ser = {}
ser.number  = function(v) return tostring(v) end
ser.boolean = function(v) return tostring(v) end
ser.string  = function(v) return v end
ser.Vector2 = function(v) return string.format("%.3f, %.3f",v.X,v.Y) end
ser.Vector3 = function(v) return string.format("%.3f, %.3f, %.3f",v.X,v.Y,v.Z) end
ser.CFrame  = function(v)
	local p=v.Position; local rx,ry,rz=v:ToEulerAnglesXYZ()
	return string.format("%.3f, %.3f, %.3f,  %.3f, %.3f, %.3f",
		p.X,p.Y,p.Z,math.deg(rx),math.deg(ry),math.deg(rz))
end
ser.Color3  = function(v) return string.format("%.3f, %.3f, %.3f",v.R,v.G,v.B) end
ser.UDim    = function(v) return string.format("%.3f, %d",v.Scale,v.Offset) end
ser.UDim2   = function(v) return string.format("%.3f, %d, %.3f, %d",v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset) end

-- ─── Recursive flattener ─────────────────────────────────────────────────────
-- Walks `tbl` recursively. For every leaf value with a known type it registers:
--   fields[]    = { key (dot-path), valueType, parentTable, leafKey }
--   snapshot[dotPath] = originalValue
-- `parentTable` + `leafKey` let us write directly: parentTable[leafKey] = newValue
local function flatten(tbl, prefix, fields, snapshot, depth)
	depth = depth or 0
	if depth > 8 then return end  -- safety cap on recursion
	for k, v in pairs(tbl) do
		if type(k) == "string" or type(k) == "number" then
			local dotPath = prefix ~= "" and (prefix .. "." .. tostring(k)) or tostring(k)
			local t = getType(v)
			if t then
				-- leaf value
				fields[#fields+1] = {
					key         = dotPath,
					valueType   = t,
					parentTable = tbl,
					leafKey     = k,
					-- section = everything before the last dot (empty = root)
					section     = prefix,
				}
				snapshot[dotPath] = v
			elseif type(v) == "table" then
				-- nested table — recurse
				flatten(v, dotPath, fields, snapshot, depth + 1)
			end
		end
	end
end

-- ─── Constructor ─────────────────────────────────────────────────────────────
function Configify.new(label: string, configTable: table)
	assert(type(label) == "string",       "[Configify] First arg must be a string label")
	assert(type(configTable) == "table",  "[Configify] Second arg must be the config table")

	local self     = setmetatable({}, Configify)
	self._name     = label
	self._root     = configTable
	self._fields   = {}
	self._snapshot = {}
	self._onChange = {}   -- dotPath → { callbacks }
	self._byKey    = {}   -- dotPath → field entry (fast lookup)

	flatten(configTable, "", self._fields, self._snapshot, 0)
	table.sort(self._fields, function(a, b) return a.key < b.key end)

	for _, f in ipairs(self._fields) do
		self._byKey[f.key] = f
	end

	return self
end

-- ─── Public API ──────────────────────────────────────────────────────────────

-- Get the current value for a dot-path key
function Configify:get(key)
	local f = self._byKey[key]
	return f and f.parentTable[f.leafKey]
end

-- Serialise a dot-path key's value to string
function Configify:toString(key)
	local v = self:get(key)
	if v == nil then return "nil" end
	local t = getType(v)
	return (ser[t] and ser[t](v)) or tostring(v)
end

-- Set a dot-path key to a typed value directly
function Configify:set(key, value)
	local f = self._byKey[key]
	assert(f, "[Configify] Unknown key: " .. tostring(key))
	f.parentTable[f.leafKey] = value   -- writes into the original nested table
	if self._onChange[key] then
		for _, cb in ipairs(self._onChange[key]) do pcall(cb, value) end
	end
end

-- Set a dot-path key from a raw string (auto-parses by type)
function Configify:setFromString(key, raw)
	local f = self._byKey[key]
	if not f then return false, "Unknown key: " .. tostring(key) end
	local p = parsers[f.valueType]
	if not p then return false, "No parser for type: " .. f.valueType end
	local value, err = p(raw)
	if value == nil then return false, err or "Parse failed" end
	self:set(key, value)
	return true
end

-- Reset all fields to snapshot values
function Configify:reset()
	for key, v in pairs(self._snapshot) do
		local f = self._byKey[key]
		if f then f.parentTable[f.leafKey] = v end
		if self._onChange[key] then
			for _, cb in ipairs(self._onChange[key]) do pcall(cb, v) end
		end
	end
end

-- Subscribe to changes on a specific dot-path key
function Configify:onChange(key, cb)
	self._onChange[key] = self._onChange[key] or {}
	table.insert(self._onChange[key], cb)
end

-- Iterate all fields: callback(dotPathKey, valueType, currentValueString, section)
function Configify:forEach(cb)
	for _, f in ipairs(self._fields) do
		cb(f.key, f.valueType, self:toString(f.key), f.section)
	end
end

-- Return a list of unique section names in order (sections = dot-paths of nested tables)
function Configify:sections()
	local seen = {}
	local list = {}
	for _, f in ipairs(self._fields) do
		local s = f.section
		if not seen[s] then
			seen[s] = true
			list[#list+1] = s
		end
	end
	return list
end

-- ─── UI Builder ──────────────────────────────────────────────────────────────
function Configify:buildUI(parent)
	local ConfigifyUI = require(script.ConfigifyUI)
	return ConfigifyUI.build(self, parent)
end

return Configify