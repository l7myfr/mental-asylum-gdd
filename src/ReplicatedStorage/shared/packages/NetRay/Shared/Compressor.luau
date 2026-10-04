--!native
--!optimize 2

--[[
    LZ4_Lib

    Pure Luau implementation of LZ4 Block Compression Format (Luau Compliant)
    Includes BinaryEncoder integration and header handling.
]]

local lz4Lib = {}

--[[* Dependencies *]]
local BinaryEncoderModule = require(script.Parent.Parent.ThirdParty.BinaryEncoder)
type BinaryEncoder = {
	encode: (data: any) -> string?, -- Returns string on success, nil on error
	decode: (encoded: string) -> any? -- Returns original data on success, nil on error
}

-- Assert dependency exists and has expected methods
assert(BinaryEncoderModule, "LZ4_Lib requires the BinaryEncoder module.")
assert(typeof(BinaryEncoderModule.encode) == "function", "BinaryEncoder module must have an 'encode' function.")
assert(typeof(BinaryEncoderModule.decode) == "function", "BinaryEncoder module must have a 'decode' function.")

-- Assign typed module
local BinaryEncoder: BinaryEncoder = BinaryEncoderModule

--[[* Type Definitions *]]
-- Type for the LZ4_Lib module itself
export type LZ4Module = {
	Compress: (self: LZ4Module, data: any) -> string?, -- Returns header+payload string or nil
	Decompress: (self: LZ4Module, data: string) -> any? -- Returns original data or nil
}

--[[* Constants *]]
-- Header Bytes (Using string constants)
local rawStringHeader: string     = string.char(0x01)
local rawEncodedHeader: string    = string.char(0x02)
local lz4StringHeader: string     = string.char(0x03)
local lz4EncodedHeader: string    = string.char(0x04)

-- LZ4 Constants (number types assumed)
local minmatch = 4; local kb = 1024; local mb = 1024 * kb; local maxInputSize = 50 * mb
local hashLog = 12; local hashTableSize = bit32.lshift(1, hashLog)
local maxDistance = bit32.lshift(1, 16) - 1; local mlBits = 4
local mlMask = bit32.lshift(1, mlBits) - 1; local runBits = 8 - mlBits
local runMask = bit32.lshift(1, runBits) - 1; local hashSeed32 = 2654435761
local minCompressionInputLen = 64; local compressionWorthRatio = 0.98

-- Character cache table (type { [number]: string })
local chars: {[number]: string} = {}
for i = 0, 255 do chars[i] = string.char(i) end

--[[* Helper Functions (LZ4 Core & General) - Typed *]]
local function readU16Le(input: string, pos: number): (number?, number?) -- Returns value?, newPos?
	local b1 = string.byte(input, pos); local b2 = string.byte(input, pos + 1)
	if not b1 or not b2 then return nil, nil end
	return bit32.bor(b1, bit32.lshift(b2, 8)), pos + 2
end
local function writeU16Le(value: number, chunks: {string})
	table.insert(chunks, chars[bit32.band(value, 0xFF)])
	table.insert(chunks, chars[bit32.band(bit32.rshift(value, 8), 0xFF)])
end
local function writeLz4Len(lenToEncode: number, baseValue: number, chunks: {string})
	local extraLen = lenToEncode - baseValue
	if extraLen < 0 then extraLen = 0 end
	local val = extraLen
	while val >= 255 do table.insert(chunks, chars[0xFF]); val -= 255 end
	table.insert(chunks, chars[val])
end
local function readLength(input: string, pos: number, baseLength: number, maskValue: number): (number?, number?) -- Returns length?, newPos?
	local length = baseLength
	if length == maskValue then
		local byteVal; local sum = 0
		repeat
			byteVal = string.byte(input, pos)
			if not byteVal then return nil, pos end -- Check for end of string
			sum += byteVal; pos += 1
		until byteVal ~= 255
		length += sum
	end
	return length, pos
end
local function mul32(a: number, b: number): number -- Internal bit manipulation, returns number
	local aL=bit32.band(a,0xFFFF); local aH=bit32.rshift(a,16); local bL=bit32.band(b,0xFFFF); local bH=bit32.rshift(b,16)
	local p1=aL*bL; local p2=aL*bH; local p3=aH*bL; local rL=bit32.band(p1,0xFFFF); local cy=bit32.rshift(p1,16)
	local mS=cy+bit32.band(p2,0xFFFF)+bit32.band(p3,0xFFFF); local rH=bit32.band(mS,0xFFFF)
	return bit32.bor(bit32.lshift(rH,16),rL)
end
local function hashSequence(input: string, pos: number): number -- Returns hash number
	local b1=string.byte(input,pos) or 0; local b2=string.byte(input,pos+1) or 0; local b3=string.byte(input,pos+2) or 0; local b4=string.byte(input,pos+3) or 0
	local sequence=bit32.bor(b1,bit32.lshift(b2,8),bit32.lshift(b3,16),bit32.lshift(b4,24))
	local h=mul32(sequence,hashSeed32); return bit32.rshift(h,32-hashLog)
end

--[[* Core LZ4 Compression Logic - Typed *]]
-- Takes string, returns (success: boolean, result: string | nil) - result is compressed string or nil on critical failure
local function compressor(input: string): (boolean, string?)
	local inputLen = #input
	if inputLen == 0 then return true, "" end
	if inputLen > maxInputSize then warn("LZ4 Input too large"); return false, nil end -- Return nil on failure

	local success, result = pcall(function(): string -- Inner function returns compressed string
		local hashTable: {[number]: number} = {} -- hash -> position
		local outputChunks: {string} = {}
		local ip = 1; local anchor = 1; local inputByte = string.byte

		while ip <= inputLen do
			local ref; local matchFound = false
			if ip <= inputLen - minmatch + 1 then
				local h = hashSequence(input, ip); ref = hashTable[h]; hashTable[h] = ip
				if ref and (ip - ref <= maxDistance) then
					-- Check 4 bytes match (manually for potential slight speedup vs substring compare)
					if inputByte(input, ref) == inputByte(input, ip) and inputByte(input, ref+1) == inputByte(input, ip+1) and
						inputByte(input, ref+2) == inputByte(input, ip+2) and inputByte(input, ref+3) == inputByte(input, ip+3) then
						local literalLength = ip - anchor; local offset = ip - ref; local matchLen = minmatch
						local ipFast = ip + matchLen; local refFast = ref + matchLen
						-- Find full match length
						while ipFast <= inputLen and inputByte(input, ipFast) == inputByte(input, refFast) do matchLen += 1; ipFast += 1; refFast += 1 end
						-- Write token, lengths, literals, offset
						local tokenLitLen = math.min(literalLength, runMask); local tokenMatchLen = math.min(matchLen - minmatch, mlMask)
						local token = bit32.bor(bit32.lshift(tokenLitLen, mlBits), tokenMatchLen)
						table.insert(outputChunks, chars[token])
						if tokenLitLen == runMask then writeLz4Len(literalLength, runMask, outputChunks) end
						if literalLength > 0 then table.insert(outputChunks, string.sub(input, anchor, ip - 1)) end
						writeU16Le(offset, outputChunks)
						if tokenMatchLen == mlMask then writeLz4Len(matchLen - minmatch, mlMask, outputChunks) end
						-- Update pointers
						ip += matchLen; anchor = ip; matchFound = true
					end
				end
			end
			if not matchFound then ip += 1 end -- Advance if no match found
		end
		-- Write final literals
		local finalLiteralLength = inputLen - anchor + 1
		if finalLiteralLength > 0 then
			local tokenLiteralLenPart = math.min(finalLiteralLength, runMask)
			local token = bit32.lshift(tokenLiteralLenPart, mlBits)
			table.insert(outputChunks, chars[token])
			if tokenLiteralLenPart == runMask then writeLz4Len(finalLiteralLength, runMask, outputChunks) end
			table.insert(outputChunks, string.sub(input, anchor, inputLen))
		end
		return table.concat(outputChunks)
	end)

	if success then return true, result :: string? -- result is string or nil if input was empty initially (handled above)
	else warn("LZ4 Compression Internal Error:", result); return false, nil -- Return nil on internal pcall error
	end
end

--[[* Core LZ4 Decompression Logic - Typed *]]
-- Takes compressed string, returns (success: boolean, result: string | nil) - result is decompressed string or nil on failure
local function decompressor(input: string): (boolean, string?)
	local inputLen = #input
	if inputLen == 0 then return true, "" end

	local success, result = pcall(function(): string -- Inner function returns decompressed string
		local outputBytes: {string} = {}
		local op = 0; local ip = 1; local inputByte = string.byte; local sub = string.sub

		while ip <= inputLen do
			local token = inputByte(input, ip); if not token then error("LZ4 stream end reading token @ "..ip, 0) end; ip += 1
			local literalLengthBase = bit32.rshift(token, mlBits)
			local literalLength, newIpLl = readLength(input, ip, literalLengthBase, runMask); if not literalLength then error("LZ4 stream truncated literal len @ "..ip, 0) end; ip = newIpLl
			if literalLength > 0 then
				local litEnd = ip + literalLength - 1; if litEnd > inputLen then error("LZ4 stream literal OOB", 0) end
				table.insert(outputBytes, sub(input, ip, litEnd)); op += literalLength; ip += literalLength
			end
			if ip > inputLen then break end -- End of stream after literals
			local offset, newIpOff = readU16Le(input, ip); if not offset then error("LZ4 stream truncated offset @ "..ip, 0) end; if offset == 0 then error("LZ4 stream offset=0 @ "..ip, 0) end; ip = newIpOff
			local matchLengthBase = bit32.band(token, mlMask)
			local matchLength, newIpMl = readLength(input, ip, matchLengthBase, mlMask); if not matchLength then error("LZ4 stream truncated match len @ "..ip, 0) end; ip = newIpMl
			matchLength += minmatch
			local matchSourceStart = op - offset + 1; if matchSourceStart < 1 then error("LZ4 stream invalid offset "..offset.." (op="..op..") @ "..ip, 0) end

			-- Copy match data (Handling overlap)
			local currentOutputStr = table.concat(outputBytes) -- Snapshot current output
			if offset >= matchLength then -- No overlap
				if matchSourceStart + matchLength - 1 > op then error("LZ4 non-overlap OOB", 0) end
				table.insert(outputBytes, sub(currentOutputStr, matchSourceStart, matchSourceStart + matchLength - 1))
			else -- Overlap
				local tempCopyTable = {}; local snapshotLen = #currentOutputStr
				if matchSourceStart > snapshotLen then error("LZ4 overlap source start OOB", 0) end
				for i=1, matchLength do
					local readPos = matchSourceStart + i - 1
					local byteValue: number?
					if readPos <= snapshotLen then byteValue = inputByte(currentOutputStr, readPos)
					else local tempIdx = readPos - snapshotLen; if tempIdx <= 0 or tempIdx > #tempCopyTable then error("LZ4 overlap temp read OOB", 0) end; byteValue = string.byte(tempCopyTable[tempIdx], 1) end
					if not byteValue then error("LZ4 overlap read byte fail", 0) end
					table.insert(tempCopyTable, chars[byteValue])
				end
				table.insert(outputBytes, table.concat(tempCopyTable))
			end
			op += matchLength
		end
		-- Return final concatenated string
		return table.concat(outputBytes)
	end)

	if success then return true, result :: string? -- Result is string or nil if empty
	else warn("LZ4 Decompression Internal Error:", result); return false, nil -- Return nil on internal pcall error
	end
end

--[[* Public Interface Methods - Typed *]]

function lz4Lib:Compress(data: any): string?
	local payloadData: string
	local isRawString: boolean

	if typeof(data) == "string" then payloadData = data; isRawString = true
	else
		local encodeSuccess, encoded = pcall(BinaryEncoder.encode, data)
		if not encodeSuccess or typeof(encoded) ~= "string" then warn("LZ4 Compress: Encode fail - ", encoded); return nil end
		payloadData = encoded; isRawString = false
	end

	local payloadLen = #payloadData
	if payloadLen < minCompressionInputLen then
		return (if isRawString then rawStringHeader else rawEncodedHeader) .. payloadData
	end

	local compressSuccess, compressedData = compressor(payloadData)
	if not compressSuccess then -- compressor returns nil on failure now
		warn("LZ4 Compress: Compressor fail - sending raw. Size:", payloadLen)
		return (if isRawString then rawStringHeader else rawEncodedHeader) .. payloadData
	end

	-- Check if compression worthwhile (compressedData is guaranteed string here)
	local compressedStr = compressedData :: string
	if #compressedStr < (payloadLen * compressionWorthRatio) then
		return (if isRawString then lz4StringHeader else lz4EncodedHeader) .. compressedStr
	else -- Not worthwhile
		return (if isRawString then rawStringHeader else rawEncodedHeader) .. payloadData
	end
end


function lz4Lib:Decompress(data: string): any?
	if typeof(data) ~= "string" or #data < 1 then warn("LZ4 Decompress: Invalid input."); return nil end

	local header: string = string.sub(data, 1, 1)
	local payload: string = string.sub(data, 2)
	local needsDecode = false; local isCompressed = false

	if header == rawStringHeader then needsDecode=false; isCompressed=false
	elseif header == rawEncodedHeader then needsDecode=true; isCompressed=false
	elseif header == lz4StringHeader then needsDecode=false; isCompressed=true
	elseif header == lz4EncodedHeader then needsDecode=true; isCompressed=true
	else warn("LZ4 Decompress: Unknown header:", string.byte(header,1)); return nil
	end

	local processedPayload: string?
	if isCompressed then
		local decompressSuccess, decompressedData = decompressor(payload)
		if not decompressSuccess then warn("LZ4 Decompress: Decompressor fail. Header:", string.byte(header,1)); return nil end
		processedPayload = decompressedData
	else
		processedPayload = payload
	end

	if processedPayload == nil then warn("LZ4 Decompress: Payload nil post-process. Header:", string.byte(header,1)); return nil end

	if needsDecode then
		local decodeSuccess, originalData = pcall(BinaryEncoder.decode, processedPayload)
		if not decodeSuccess then warn("LZ4 Decompress: Decode fail -", originalData, "- Header:", string.byte(header,1)); return nil end
		return originalData -- Return decoded Luau data
	else
		return processedPayload -- Return raw/decompressed string
	end
end

-- Return the module table, asserting its type
return lz4Lib :: LZ4Module