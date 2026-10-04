--!optimize 2
--!native

-- BinaryEncoder.lua (Revised for LZ4 Compatibility, Cyclic References, Pack Formats, Recursion Fixes, and Integer Check)
-- Author: Asta (@TheYusufGamer)
-- Version: v1.5.4 (Fixed instance handling)

local BinaryEncoder = {}

-- Binary type identifiers 
local type2 = {
	NIL = 0, BOOLEAN_FALSE = 1, BOOLEAN_TRUE = 2, NUMBER_INT8 = 3, NUMBER_INT16 = 4,
	NUMBER_INT32 = 5, NUMBER_FLOAT32 = 6, STRING_SHORT = 7, STRING_LONG = 8, TABLE_START = 9,
	TABLE_END = 10, ARRAY_START = 11, ARRAY_END = 12, REFERENCE = 13, VECTOR3 = 14,
	COLOR3 = 15, UDIM2 = 16, CFRAME = 17, VECTOR2 = 18, RECT = 19, ENUM = 20,
	INSTANCE_REF = 21, DATETIME = 22, BRICKCOLOR = 23, NUMBERSEQUENCE = 24, COLORSEQUENCE = 25,
	BUFFER = 26, ARRAY_HOMOGENEOUS = 27, VALUE_TYPE_ID = 28, NUMBER_ZERO = 29, STRING_EMPTY = 30,
}

-- HOMOGENEOUS_TYPE_MAP 
local homogeneousTypeMap = {
	["number"] = type2.NUMBER_FLOAT32, ["string"] = type2.STRING_SHORT, ["Vector3"] = type2.VECTOR3,
	["Vector2"] = type2.VECTOR2, ["Color3"] = type2.COLOR3, ["boolean"] = type2.BOOLEAN_FALSE,
	["CFrame"] = type2.CFRAME, ["UDim2"] = type2.UDIM2, ["Rect"] = type2.RECT, ["EnumItem"] = type2.ENUM,
	["BrickColor"] = type2.BRICKCOLOR, ["DateTime"] = type2.DATETIME, ["buffer"] = type2.BUFFER,
}

-- Roblox Globals Cache 
local vector3New = Vector3.new; local vector2New = Vector2.new; local color3New = Color3.new
local uDim2New = UDim2.new; local rectNew = Rect.new; local cFrameNew = CFrame.new
local enumType = Enum; local dateTimeFromMillis = DateTime.fromUnixTimestampMillis
local brickColorNew = BrickColor.new; local numberSequenceNew = NumberSequence.new
local colorSequenceNew = ColorSequence.new; local numberSequenceKeypointNew = NumberSequenceKeypoint.new
local colorSequenceKeypointNew = ColorSequenceKeypoint.new; local bufferLen = buffer.len
local bufferTostring = buffer.tostring; local bufferFromstring = buffer.fromstring
local stringPack = string.pack; local stringUnpack = string.unpack; local stringSub = string.sub
local stringByte = string.byte; local stringChar = string.char; local tableInsert = table.insert
local tableConcat = table.concat; local pairs = pairs; local ipairs = ipairs; local type = type
local typeof = typeof; local mathFloor = math.floor; local mathMax = math.max
local mathAbs = math.abs; local pcall = pcall; local warn = warn; local error = error
local tostring = tostring

-- Reuse string characters Cache 
local charCache = {}
for i = 0, 255 do charCache[i] = stringChar(i) end

-- Recursion depth limit 
local maxDepth = 500

-- Error formatting helper 
local function encodingError(msg: string, currentDepth: number): nil error(("[BE Enc Err d%d] %s"):format(currentDepth, msg), 3) return nil end
local function decodingError(msg: string, index: number): nil error(("[BE Dec Err @%d] %s"):format(index, msg), 3) return nil end

--[[ Helper: isInteger ]]
local function isInteger(value: number): boolean return mathAbs(value - mathFloor(value)) < 0.00001 end

-- Helper to write/read length 
local function writeLength(len: number): string if len < 255 then return charCache[len] else return charCache[255] .. string_pack(">I4", len) end end
local function readLength(data: string, index: number): (number?, number?) local b=stringByte(data,index); if not b then return decodingError("readLen byte",index) end; index+=1; if b<255 then return b,index else if index+3>#data then return decodingError("readLen data",index) end; local l,ni=stringUnpack(">I4",data,index); if not l then return decodingError("readLen unpack",index) end; return l,ni end end

--[[ Helper: Get Instance Path ]]
local function getInstancePath(instance: Instance): string?
	if not instance then return nil end -- Handle nil input gracefully

	local names = {}
	local current: Instance? = instance
	local gameService = game -- Cache the global

	-- Walk up the hierarchy until 'game' or nil is reached
	while current and current ~= gameService do
		-- Check for invalid characters in names if necessary, though usually not an issue
		-- if string.find(current.Name, ".", 1, true) then
		--     warn("[BE Enc] Instance name contains '.' which might break pathfinding:", current:GetFullName())
		-- end
		tableInsert(names, 1, current.Name) -- Prepend name
		current = current.Parent
	end

	-- If the loop stopped because we hit 'game', the path is valid relative to game
	if current == gameService then
		return tableConcat(names, ".")
	else
		-- Instance is not a descendant of game (e.g., parented to nil, CoreGui, etc.)
		-- These often cannot or should not be reliably serialized by path.
		warn(("[BE Enc] Instance %q is not a descendant of game, cannot create serializable path."):format(tostring(instance)))
		return nil
	end
end

--[[ Helper: Get Instance At Path ]]
function GetInstanceAtPath(path)
	local current = game
	for segment in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(segment)
		if not current then
			return nil
		end
	end
	return current
end

--[[--- Internal Encoding Logic ---]]
local function encodeValue(value: any, refsEncoding: {}, buffer: {string}, currentDepth: number)

	if currentDepth > maxDepth then return encodingError("Max depth", currentDepth) end

	local valueType = typeof(value)
	local rawType = type(value)

	if value == nil then tableInsert(buffer, charCache[type2.NIL])
	elseif rawType == "boolean" then tableInsert(buffer, charCache[value and type2.BOOLEAN_TRUE or type2.BOOLEAN_FALSE])
	elseif rawType == "number" then
		if value == 0 then tableInsert(buffer, charCache[type2.NUMBER_ZERO])
		elseif isInteger(value) then
			if value >= -128 and value <= 127 then tableInsert(buffer, charCache[type2.NUMBER_INT8]); tableInsert(buffer, stringPack("<i1", value))
			elseif value >= -32768 and value <= 32767 then tableInsert(buffer, charCache[type2.NUMBER_INT16]); tableInsert(buffer, stringPack("<i2", value))
			elseif value >= -2147483648 and value <= 2147483647 then tableInsert(buffer, charCache[type2.NUMBER_INT32]); tableInsert(buffer, stringPack("<i4", value))
			else warn("[BE Enc] Int >32bit->Float32:", value); tableInsert(buffer, charCache[type2.NUMBER_FLOAT32]); tableInsert(buffer, stringPack("<f", value)) end
		else tableInsert(buffer, charCache[type2.NUMBER_FLOAT32]); tableInsert(buffer, stringPack("<f", value)) end
	elseif rawType == "string" then
		local len = #value; if len == 0 then tableInsert(buffer, charCache[type2.STRING_EMPTY])
		else local lb=writeLength(len); tableInsert(buffer, charCache[#lb==1 and type2.STRING_SHORT or type2.STRING_LONG]); tableInsert(buffer,lb); tableInsert(buffer, value) end
	elseif rawType == "table" then
		local refId = refsEncoding[value]; if refId then tableInsert(buffer, charCache[type2.REFERENCE]); encodeValue(refId, refsEncoding, buffer, currentDepth + 1)
		else
			local currentRefId = #refsEncoding + 1; refsEncoding[value] = currentRefId
			local count, max_idx, is_dictionary = 0, 0, false
			for k in pairs(value) do count += 1; if type(k) == "number" and k >= 1 and mathFloor(k) == k then max_idx = mathMax(max_idx, k) else is_dictionary = true end end
			if not is_dictionary and count > 0 and max_idx > count * 2 and max_idx > 10 then is_dictionary = true end -- Sparse check

			if not is_dictionary and count == max_idx then -- Array
				if count == 0 then tableInsert(buffer, charCache[type2.ARRAY_START]); tableInsert(buffer, charCache[type2.ARRAY_END])
				else
					local fV, is_homo, fVTI, fVRT, fVTo = value[1], true, nil, nil, nil
					fVRT = type(fV); fVTo = typeof(fV); local tidfc = homogeneousTypeMap[fVTo]
					if count > 1 and tidfc then
						fVTI = tidfc; local isFBool = fVTo=="boolean"
						for i = 2, count do local cV = value[i]; local cVTo = typeof(cV); if cVTo ~= fVTo and not (isFBool and cVTo == "boolean") then is_homo = false; break end; if fVRT == "number" and type(cV) ~= "number" then is_homo = false; break end end
					else is_homo = false end

					if is_homo and fVTI then -- Homo Array
						tableInsert(buffer, charCache[type2.ARRAY_HOMOGENEOUS]); local ttw = (fVTI==type2.BOOLEAN_TRUE or fVTI==type2.BOOLEAN_FALSE) and type2.BOOLEAN_FALSE or fVTI
						tableInsert(buffer, charCache[ttw]); tableInsert(buffer, charCache[type2.VALUE_TYPE_ID]); encodeValue(count, refsEncoding, buffer, currentDepth + 1)
						if ttw == type2.NUMBER_FLOAT32 then for i=1,count do local n=value[i]; if n==0 then tableInsert(buffer,charCache[type2.NUMBER_ZERO]) else tableInsert(buffer,stringPack("<f",n)) end end
						elseif ttw == type2.BOOLEAN_FALSE then for i=1,count do tableInsert(buffer,charCache[value[i] and type2.BOOLEAN_TRUE or type2.BOOLEAN_FALSE]) end
						elseif ttw == type2.STRING_SHORT then for i=1, count do encodeValue(value[i], refsEncoding, buffer, currentDepth + 1) end
						else for i=1, count do encodeValue(value[i], refsEncoding, buffer, currentDepth + 1) end end
					else -- Regular Array
						tableInsert(buffer, charCache[type2.ARRAY_START]); for i=1, count do encodeValue(value[i], refsEncoding, buffer, currentDepth + 1) end; tableInsert(buffer, charCache[type2.ARRAY_END])
					end
				end
			else -- Dictionary
				tableInsert(buffer, charCache[type2.TABLE_START])
				for k, v in pairs(value) do local kt=type(k); if kt=="string" or kt=="number" then encodeValue(k, refsEncoding, buffer, currentDepth+1); encodeValue(v, refsEncoding, buffer, currentDepth+1) else warn("[BE Enc] Skip table key:", kt, k) end end
				tableInsert(buffer, charCache[type2.TABLE_END])
			end
		end
		-- Roblox Types (Standardized pack formats)
	elseif valueType == "Vector3" then tableInsert(buffer,charCache[type2.VECTOR3]); tableInsert(buffer, stringPack("<ddd", value.X, value.Y, value.Z)) -- FIX: <ddd
	elseif valueType == "Vector2" then tableInsert(buffer,charCache[type2.VECTOR2]); tableInsert(buffer, stringPack("<dd", value.X, value.Y))             -- FIX: <dd
	elseif valueType == "Color3" then tableInsert(buffer,charCache[type2.COLOR3]); tableInsert(buffer, stringPack("<ddd", value.R, value.G, value.B))   -- FIX: <ddd
	elseif valueType == "UDim2" then tableInsert(buffer,charCache[type2.UDIM2]); tableInsert(buffer, stringPack("<dddd", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)) -- FIX: <dddd
	elseif valueType == "Rect" then tableInsert(buffer,charCache[type2.RECT]); tableInsert(buffer, stringPack("<dddd", value.Min.X, value.Min.Y, value.Max.X, value.Max.Y))       -- FIX: <dddd
	elseif valueType == "CFrame" then tableInsert(buffer,charCache[type2.CFRAME]); tableInsert(buffer, stringPack("<dddddddddddd", value:GetComponents())) -- FIX: <d * 12
	elseif valueType == "EnumItem" then tableInsert(buffer,charCache[type2.ENUM]); encodeValue(tostring(value.EnumType), refsEncoding, buffer, currentDepth+1); encodeValue(tostring(value.Name), refsEncoding, buffer, currentDepth+1)
	elseif valueType == "Instance" then
		-- Use the robust path function (Unchanged)
		local path = getInstancePath(value)
		if path then
			if path == "" then
				warn("[BE Enc] Instance path resulted in empty string for:", value)
				tableInsert(buffer, charCache[type2.NIL])
			else
				tableInsert(buffer, charCache[type2.INSTANCE_REF])
				encodeValue(path, refsEncoding, buffer, currentDepth + 1)
			end
		else
			-- getInstancePath already warned if it couldn't generate a path
			tableInsert(buffer, charCache[type2.NIL]) -- Encode as nil if path generation failed
		end
	elseif valueType == "DateTime" then tableInsert(buffer,charCache[type2.DATETIME]); tableInsert(buffer, stringPack("<q", value.UnixTimestampMillis))
	elseif valueType == "BrickColor" then tableInsert(buffer,charCache[type2.BRICKCOLOR]); encodeValue(value.Number, refsEncoding, buffer, currentDepth+1)
	elseif valueType == "NumberSequence" then tableInsert(buffer,charCache[type2.NUMBERSEQUENCE]); local kp=value.Keypoints; encodeValue(#kp, refsEncoding, buffer, currentDepth+1); for _,k in ipairs(kp) do tableInsert(buffer, stringPack("<ddd", k.Time, k.Value, k.Envelope)) end -- Kept <ddd
	elseif valueType == "ColorSequence" then tableInsert(buffer,charCache[type2.COLORSEQUENCE]); local kp=value.Keypoints; encodeValue(#kp, refsEncoding, buffer, currentDepth+1); for _,k in ipairs(kp) do tableInsert(buffer, stringPack("<dddd", k.Time, k.Value.R, k.Value.G, k.Value.B)) end -- Kept <dddd
	elseif valueType == "buffer" then tableInsert(buffer, charCache[type2.BUFFER]); local l=bufferLen(value); local lb=writeLength(l); tableInsert(buffer,lb); tableInsert(buffer, bufferTostring(value))
	else warn("[BE Enc] Unsupported:", valueType, value); tableInsert(buffer, charCache[type2.NIL])
	end
end


--[[--- Internal Decoding Logic ---]]
local function decodeValue(data: string, indexRef: {number}, refsDecoding: {}, currentDepth: number)

	if currentDepth > maxDepth then return decodingError("Max depth", indexRef[1]) end
	local index = indexRef[1]; if index > #data then return decodingError("EOF start", index) end
	local typeId = stringByte(data, index); if not typeId then return decodingError("EOF TypeID", index) end
	index += 1; indexRef[1] = index

	if typeId == type2.NIL then return nil
	elseif typeId == type2.BOOLEAN_FALSE then return false
	elseif typeId == type2.BOOLEAN_TRUE then return true
	elseif typeId == type2.NUMBER_ZERO then return 0
	elseif typeId == type2.STRING_EMPTY then return ""
	elseif typeId == type2.NUMBER_INT8 then if index>#data then return decodingError("EOF I8",index) end; local v,idx=stringUnpack("<i1",data,index); if not idx then return decodingError("Unpk I8",index) end; indexRef[1]=idx; return v
	elseif typeId == type2.NUMBER_INT16 then if index+1>#data then return decodingError("EOF I16",index) end; local v,idx=stringUnpack("<i2",data,index); if not idx then return decodingError("Unpk I16",index) end; indexRef[1]=idx; return v
	elseif typeId == type2.NUMBER_INT32 then if index+3>#data then return decodingError("EOF I32",index) end; local v,idx=stringUnpack("<i4",data,index); if not idx then return decodingError("Unpk I32",index) end; indexRef[1]=idx; return v
	elseif typeId == type2.NUMBER_FLOAT32 then if index+3>#data then return decodingError("EOF F32",index) end; local v,idx=stringUnpack("<f",data,index); if not idx then return decodingError("Unpk F32",index) end; indexRef[1]=idx; return v
	elseif typeId == type2.STRING_SHORT or typeId == type2.STRING_LONG then local l,il=readLength(data,indexRef[1]); if not l then return nil end; local eos=il+l; if eos>#data+1 then return decodingError("Str OOB "..l,il) end; local s=stringSub(data,il,eos-1); indexRef[1]=eos; return s
	elseif typeId == type2.REFERENCE then local rid=decodeValue(data,indexRef,refsDecoding,currentDepth+1); if type(rid)~="number" then return decodingError("RefID type "..type(rid), indexRef[1]) end; local v=refsDecoding[rid]; if v==nil then return decodingError("RefID inv "..rid, indexRef[1]) end; return v
	elseif typeId == type2.TABLE_START then local tbl={}; local id=#refsDecoding+1; refsDecoding[id]=tbl; while true do if indexRef[1]>#data then return decodingError("EOF TBL", indexRef[1]) end; local p=stringByte(data,indexRef[1]); if not p then return decodingError("Peek TBL", indexRef[1]) end; if p==type2.TABLE_END then indexRef[1]+=1; break end; local k=decodeValue(data,indexRef,refsDecoding,currentDepth+1); if indexRef[1]>#data and stringByte(data, indexRef[1])~=type2.TABLE_END then return decodingError("EOF TBL Key", indexRef[1]) end; local v=decodeValue(data,indexRef,refsDecoding,currentDepth+1); tbl[k]=v end; return tbl
	elseif typeId == type2.ARRAY_START then local arr={}; local id=#refsDecoding+1; refsDecoding[id]=arr; local i=1; while true do if indexRef[1]>#data then return decodingError("EOF ARR", indexRef[1]) end; local p=stringByte(data,indexRef[1]); if not p then return decodingError("Peek ARR", indexRef[1]) end; if p==type2.ARRAY_END then indexRef[1]+=1; break end; arr[i]=decodeValue(data,indexRef,refsDecoding,currentDepth+1); i+=1 end; return arr
	elseif typeId == type2.ARRAY_HOMOGENEOUS then local arr={}; local id=#refsDecoding+1; refsDecoding[id]=arr; index=indexRef[1]; if index+1>#data then return decodingError("EOF HomoHdr",index) end; local vtid=stringByte(data,index); index+=1; local sep=stringByte(data,index); index+=1; indexRef[1]=index; if sep~=type2.VALUE_TYPE_ID then return decodingError("Homo Sep "..sep,index-1) end; local cnt=decodeValue(data,indexRef,refsDecoding,currentDepth+1); if type(cnt)~="number" or cnt<0 or cnt~=mathFloor(cnt) then return decodingError("Homo Cnt "..tostring(cnt), indexRef[1]) end
		if cnt > 0 then index=indexRef[1]; local isBool=vtid==type2.BOOLEAN_FALSE or vtid==type2.BOOLEAN_TRUE; local evtid=isBool and type2.BOOLEAN_FALSE or vtid;
			if evtid == type2.NUMBER_FLOAT32 then for i=1,cnt do if index>#data then return decodingError(("HomoNum EOF %d/%d"):format(i,cnt),index) end; local p=stringByte(data,index); if p==type2.NUMBER_ZERO then arr[i]=0; index+=1 else if index+3>#data then return decodingError(("HomoFlt EOF %d/%d"):format(i,cnt),index) end; local v,ni=stringUnpack("<f",data,index); if not ni then return decodingError(("HomoFlt Unpk %d/%d"):format(i,cnt),index) end; arr[i]=v; index=ni end end
			elseif isBool then if index+cnt>#data+1 then return decodingError(("HomoBool EOF %d/%d"):format(cnt,cnt),index) end; for i=1,cnt do local b=stringByte(data,index); arr[i]=(b==type2.BOOLEAN_TRUE); index+=1 end
			elseif evtid == type2.STRING_SHORT then for i=1,cnt do indexRef[1]=index; local s=decodeValue(data,indexRef,refsDecoding,currentDepth+1); if type(s)~="string" then return decodingError(("HomoStr Type %d/%d got %s"):format(i,cnt,type(s)),index) end; arr[i]=s; index=indexRef[1] end
			else for i=1, cnt do indexRef[1]=index; arr[i]=decodeValue(data,indexRef,refsDecoding,currentDepth+1); index=indexRef[1] end
			end; indexRef[1]=index
		end; return arr
		-- Roblox Types (Standardized unpack formats)
	elseif typeId == type2.VECTOR3 then if indexRef[1]+23>#data then return decodingError("EOF VEC3",indexRef[1]) end; local x,y,z,idx=stringUnpack("<ddd",data,indexRef[1]); if not idx then return decodingError("Unpk VEC3",indexRef[1]) end; indexRef[1]=idx; return vector3New(x,y,z) -- FIX: <ddd
	elseif typeId == type2.VECTOR2 then if indexRef[1]+15>#data then return decodingError("EOF VEC2",indexRef[1]) end; local x,y,idx=stringUnpack("<dd",data,indexRef[1]); if not idx then return decodingError("Unpk VEC2",indexRef[1]) end; indexRef[1]=idx; return vector2New(x,y)     -- FIX: <dd
	elseif typeId == type2.COLOR3 then if indexRef[1]+23>#data then return decodingError("EOF COL3",indexRef[1]) end; local r,g,b,idx=stringUnpack("<ddd",data,indexRef[1]); if not idx then return decodingError("Unpk COL3",indexRef[1]) end; indexRef[1]=idx; return color3New(r,g,b)    -- FIX: <ddd
	elseif typeId == type2.UDIM2 then if indexRef[1]+31>#data then return decodingError("EOF UDIM2",indexRef[1]) end; local xs,xo,ys,yo,idx=stringUnpack("<dddd",data,indexRef[1]); if not idx then return decodingError("Unpk UDIM2",indexRef[1]) end; indexRef[1]=idx; return uDim2New(xs,xo,ys,yo) -- FIX: <dddd
	elseif typeId == type2.RECT then if indexRef[1]+31>#data then return decodingError("EOF RECT",indexRef[1]) end; local nx,ny,xx,xy,idx=stringUnpack("<dddd",data,indexRef[1]); if not idx then return decodingError("Unpk RECT",indexRef[1]) end; indexRef[1]=idx; return rectNew(vector2New(nx,ny),vector2New(xx,xy)) -- FIX: <dddd
	elseif typeId == type2.CFRAME then if indexRef[1]+95>#data then return decodingError("EOF CFRAME",indexRef[1]) end; local c={stringUnpack("<dddddddddddd",data,indexRef[1])}; local idx=table.remove(c); if not idx then return decodingError("Unpk CFRAME",indexRef[1]) end; indexRef[1]=idx; return cFrameNew(table.unpack(c,1,12)) -- FIX: <d * 12
	elseif typeId == type2.ENUM then local etn=decodeValue(data,indexRef,refsDecoding,currentDepth+1); local evn=decodeValue(data,indexRef,refsDecoding,currentDepth+1); if type(etn)~="string" or type(evn)~="string" then return decodingError("Enum str",indexRef[1]) end; local ok,ei=pcall(function()return enumType[etn][evn]end); if ok and ei then return ei else warn("[BE Dec] Enum fail:",etn,evn); return nil end
	elseif typeId == type2.INSTANCE_REF then
		local path = decodeValue(data, indexRef, refsDecoding, currentDepth + 1)
		if type(path) ~= "string" then
			return decodingError("Instance reference path must be a string, got " .. type(path), indexRef[1])
		end
		if path == "" then
			warn("[BE Dec] Decoded empty instance path.")
			return nil -- Treat empty path as nil
		end
		
		local instance = GetInstanceAtPath(path)

		if instance then
			-- Found the instance successfully
			return instance
		else
			-- Instance not found (FindFirstChild returned nil)
			warn(("[BE Dec] Instance not found via path %q. (Possible reasons: Not replicated yet, FilteringEnabled issue, destroyed, invalid path)."):format(path))
			return nil -- Return nil as the instance couldn't be resolved
		end
	elseif typeId == type2.DATETIME then if indexRef[1]+7>#data then return decodingError("EOF DT",indexRef[1]) end; local ms,idx=stringUnpack("<q",data,indexRef[1]); if not idx then return decodingError("Unpk DT",indexRef[1]) end; indexRef[1]=idx; local ok,dt=pcall(dateTimeFromMillis,ms); if ok then return dt else warn("[BE Dec] DT fail:",ms); return nil end
	elseif typeId == type2.BRICKCOLOR then local num=decodeValue(data,indexRef,refsDecoding,currentDepth+1); if type(num)~="number" then return decodingError("BC num",indexRef[1]) end; local ok,bc=pcall(brickColorNew,num); if ok then return bc else warn("[BE Dec] BC fail:",num); return nil end
	elseif typeId == type2.NUMBERSEQUENCE then local nk=decodeValue(data,indexRef,refsDecoding,currentDepth+1); if type(nk)~="number" or nk<0 or nk>20 then warn("[BE Dec] NS cnt clamp:",nk); nk=math.max(0,math.min(20,nk)) elseif nk~=math.floor(nk) then return decodingError("NS cnt int",indexRef[1]) end; local kps={}; local idx=indexRef[1]; local bn=nk*24; if idx+bn>#data+1 then return decodingError(("NS EOF %d need %d"):format(nk,bn),idx) end
		for i=1,nk do local t,v,e,ni=stringUnpack("<ddd",data,idx); if not ni then return decodingError(("NS Unpk %d/%d"):format(i,nk),idx) end; idx=ni; local ok,kp=pcall(numberSequenceKeypointNew,t,v,e); if ok then kps[i]=kp else warn("[BE Dec] NS Key fail:",t,v,e) end end; indexRef[1]=idx; local ok,ns=pcall(numberSequenceNew,kps); if ok then return ns else warn("[BE Dec] NS New fail"); return nil end -- Kept <ddd
	elseif typeId == type2.COLORSEQUENCE then local nk=decodeValue(data,indexRef,refsDecoding,currentDepth+1); if type(nk)~="number" or nk<0 or nk>20 then warn("[BE Dec] CS cnt clamp:",nk); nk=math.max(0,math.min(20,nk)) elseif nk~=math.floor(nk) then return decodingError("CS cnt int",indexRef[1]) end; local kps={}; local idx=indexRef[1]; local bn=nk*32; if idx+bn>#data+1 then return decodingError(("CS EOF %d need %d"):format(nk,bn),idx) end
		for i=1,nk do local t,r,g,b,ni=stringUnpack("<dddd",data,idx); if not ni then return decodingError(("CS Unpk %d/%d"):format(i,nk),idx) end; idx=ni; local co,cv=pcall(color3New,r,g,b); if co then local ok,kp=pcall(colorSequenceKeypointNew,t,cv); if ok then kps[i]=kp else warn("[BE Dec] CS Key fail:",t,cv) end else warn("[BE Dec] CS Col3 fail:",r,g,b) end end; indexRef[1]=idx; local ok,cs=pcall(colorSequenceNew,kps); if ok then return cs else warn("[BE Dec] CS New fail"); return nil end -- Kept <dddd
	elseif typeId == type2.BUFFER then local l,il=readLength(data,indexRef[1]); if not l then return nil end; local eob=il+l; if eob>#data+1 then return decodingError("Buf OOB "..l,il) end; local bd=stringSub(data,il,eob-1); indexRef[1]=eob; local ok,buf=pcall(bufferFromstring,bd); if ok then return buf else warn("[BE Dec] Buf fail"); return nil end
	else return decodingError("Unknown TypeID: " .. typeId, indexRef[1] - 1)
	end
end


--[[--- Public Interface ---]]
function BinaryEncoder.encode(value: any): (string?) 
	local buffer = {}
	local refsEncoding = {}
	local ok, err = pcall(encodeValue, value, refsEncoding, buffer, 0)
	if not ok then
		-- Rethrow the error, ensuring it's captured by any outer pcall (like the one around LZ4)
		error("[BinaryEncoder.encode error] " .. tostring(err), 0) -- Use level 0 to preserve stack trace from encodeValue
		-- return nil -- Alternative: return nil instead of erroring
	end
	return tableConcat(buffer)
end

function BinaryEncoder.decode(data: string): any
	if type(data) ~= "string" then error("BE decode requires string, got "..type(data), 2) end
	if #data == 0 then error("BE decode requires non-empty string", 2) end
	local refsDecoding = {}
	local indexRef = {1}
	-- Wrap decodeValue in pcall to catch internal errors more gracefully if needed,
	-- though decodeValue already uses decodingError which halts execution.
	local result = decodeValue(data, indexRef, refsDecoding, 0)
	if indexRef[1] <= #data then
		warn(("[BE Dec Warning] Extra %d bytes left. End: %d, Total: %d"):format(#data - indexRef[1] + 1, indexRef[1], #data))
	end
	return result
end

return BinaryEncoder