-- C_EncodingUtil for forever_sim. The sim generates the namespace from Blizzard's API docs but implements none of
-- it, so every call returned an empty value; QuestieDB's baked mode decodes its whole database through it.
-- install(sim) fills sim.impl, so the generated stubs keep the documented argument and secret rules.
-- Implemented: DecodeBase64, EncodeBase64, DecodeHex, EncodeHex, DecompressString (Deflate, Zlib, Gzip) and
-- DeserializeCBOR. CompressString, SerializeCBOR and the JSON pair keep the stubs' empty answers.
-- Pure Lua (LuaJIT's bit library only), written for this repository's tests; MIT like the rest of it.
local bit = require("bit")
local band, bxor, lshift, rshift = bit.band, bit.bxor, bit.lshift, bit.rshift
local byte, char, sub, concat = string.byte, string.char, string.sub, table.concat
local floor, ldexp, huge = math.floor, math.ldexp, math.huge

local M = {}

-- Base64, RFC 4648. Enum.Base64Variant: 0 Standard, 1 StandardUrlSafe.
local ALPHABETS = {
	[0] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
	[1] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
}
local DECODE = {}
for variant, alphabet in pairs(ALPHABETS) do
	DECODE[variant] = {}
	for i = 1, 64 do
		DECODE[variant][byte(alphabet, i)] = i - 1
	end
end

function M.DecodeBase64(source, variant)
	local map = DECODE[variant or 0]
	if type(source) ~= "string" or not map then
		return nil
	end
	source = source:gsub("=+$", "")
	local len, out, n = #source, {}, 0
	local rest = len % 4
	if rest == 1 then
		return nil
	end
	for i = 1, len - rest, 4 do
		local a, b, c, d =
			map[byte(source, i)], map[byte(source, i + 1)], map[byte(source, i + 2)], map[byte(source, i + 3)]
		if not (a and b and c and d) then
			return nil
		end
		local v = a * 262144 + b * 4096 + c * 64 + d
		n = n + 1
		out[n] = char(floor(v / 65536), floor(v / 256) % 256, v % 256)
	end
	if rest > 0 then
		local i = len - rest + 1
		local a, b = map[byte(source, i)], map[byte(source, i + 1)]
		local c = rest == 3 and map[byte(source, i + 2)] or 0
		if not (a and b and c) then
			return nil
		end
		local v = a * 262144 + b * 4096 + c * 64
		n = n + 1
		out[n] = rest == 2 and char(floor(v / 65536)) or char(floor(v / 65536), floor(v / 256) % 256)
	end
	return concat(out)
end

function M.EncodeBase64(source, variant)
	local alphabet = ALPHABETS[variant or 0]
	if type(source) ~= "string" or not alphabet then
		return nil
	end
	local out = {}
	for i = 1, #source, 3 do
		local a, b, c = byte(source, i, i + 2)
		local v = a * 65536 + (b or 0) * 256 + (c or 0)
		local s1, s2, s3, s4 = floor(v / 262144) + 1, floor(v / 4096) % 64 + 1, floor(v / 64) % 64 + 1, v % 64 + 1
		out[#out + 1] = sub(alphabet, s1, s1)
			.. sub(alphabet, s2, s2)
			.. (b and sub(alphabet, s3, s3) or "=")
			.. (c and sub(alphabet, s4, s4) or "=")
	end
	return concat(out)
end

function M.EncodeHex(source)
	if type(source) ~= "string" then
		return nil
	end
	return (source:gsub(".", function(c)
		return ("%02x"):format(byte(c))
	end))
end

function M.DecodeHex(source)
	if type(source) ~= "string" or #source % 2 == 1 or source:find("%X") then
		return nil
	end
	return (source:gsub("%x%x", function(h)
		return char(tonumber(h, 16))
	end))
end

-- Inflate, RFC 1951, after zlib's puff.c: canonical Huffman codes decoded a bit at a time.
-- stylua: ignore start
local LBASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DBASE = {
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
	1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
}
local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }
-- stylua: ignore end

local function huffman(lengths, n)
	local count, offs, symbol = {}, { [1] = 0 }, {}
	for len = 0, 15 do
		count[len] = 0
	end
	for s = 0, n - 1 do
		count[lengths[s]] = count[lengths[s]] + 1
	end
	for len = 1, 14 do
		offs[len + 1] = offs[len] + count[len]
	end
	for s = 0, n - 1 do
		local len = lengths[s]
		if len > 0 then
			symbol[offs[len]] = s
			offs[len] = offs[len] + 1
		end
	end
	return { count = count, symbol = symbol }
end

local fixedLit, fixedDist

local function inflate(input, pos)
	local bitbuf, bitcnt, out, outn = 0, 0, {}, 0

	-- Refilling a byte at a time keeps fewer than 8 spare bits, all from the last byte read, so a stored block can
	-- align by dropping them, and the shifts stay far below LuaJIT's 32-bit limit.
	local function bits(need)
		while bitcnt < need do
			local b = byte(input, pos)
			if not b then
				error("truncated", 0)
			end
			bitbuf = bitbuf + lshift(b, bitcnt)
			pos, bitcnt = pos + 1, bitcnt + 8
		end
		local v = band(bitbuf, lshift(1, need) - 1)
		bitbuf, bitcnt = rshift(bitbuf, need), bitcnt - need
		return v
	end

	local function decode(h)
		local code, first, index, count = 0, 0, 0, h.count
		for len = 1, 15 do
			code = code + bits(1)
			local c = count[len]
			if code - c < first then
				return h.symbol[index + code - first]
			end
			index, first, code = index + c, (first + c) * 2, code * 2
		end
		error("bad code", 0)
	end

	repeat
		local last, kind = bits(1), bits(2)
		if kind == 0 then
			bitbuf, bitcnt = 0, 0
			local l1, l2, n1, n2 = byte(input, pos, pos + 3)
			if not n2 or l1 + l2 * 256 ~= 65535 - (n1 + n2 * 256) then
				error("bad stored block", 0)
			end
			local len = l1 + l2 * 256
			pos = pos + 4
			if pos + len - 1 > #input then
				error("truncated", 0)
			end
			for i = pos, pos + len - 1 do
				outn = outn + 1
				out[outn] = byte(input, i)
			end
			pos = pos + len
		elseif kind == 1 or kind == 2 then
			local lit, dist
			if kind == 1 then
				if not fixedLit then
					local l, d = {}, {}
					for s = 0, 287 do
						l[s] = s < 144 and 8 or s < 256 and 9 or s < 280 and 7 or 8
					end
					for s = 0, 29 do
						d[s] = 5
					end
					fixedLit, fixedDist = huffman(l, 288), huffman(d, 30)
				end
				lit, dist = fixedLit, fixedDist
			else
				local nlen, ndist, ncode = bits(5) + 257, bits(5) + 1, bits(4) + 4
				if nlen > 286 or ndist > 30 then
					error("bad code counts", 0)
				end
				local lengths = {}
				for i = 1, 19 do
					lengths[ORDER[i]] = i <= ncode and bits(3) or 0
				end
				local lencode, all, i = huffman(lengths, 19), {}, 0
				while i < nlen + ndist do
					local sym = decode(lencode)
					if sym < 16 then
						all[i], i = sym, i + 1
					else
						local val, rep = 0, nil
						if sym == 16 then
							if i == 0 then
								error("repeat without a length", 0)
							end
							val, rep = all[i - 1], 3 + bits(2)
						elseif sym == 17 then
							rep = 3 + bits(3)
						else
							rep = 11 + bits(7)
						end
						if i + rep > nlen + ndist then
							error("too many lengths", 0)
						end
						for _ = 1, rep do
							all[i], i = val, i + 1
						end
					end
				end
				local l, d = {}, {}
				for s = 0, nlen - 1 do
					l[s] = all[s]
				end
				for s = 0, ndist - 1 do
					d[s] = all[nlen + s]
				end
				lit, dist = huffman(l, nlen), huffman(d, ndist)
			end
			while true do
				local sym = decode(lit)
				if sym < 256 then
					outn = outn + 1
					out[outn] = sym
				elseif sym == 256 then
					break
				else
					sym = sym - 256
					if sym > 29 then
						error("bad length code", 0)
					end
					local len = LBASE[sym] + bits(LEXT[sym])
					local dsym = decode(dist) + 1
					if dsym > 30 then
						error("bad distance code", 0)
					end
					local back = DBASE[dsym] + bits(DEXT[dsym])
					if back > outn then
						error("distance too far back", 0)
					end
					for _ = 1, len do
						outn = outn + 1
						out[outn] = out[outn - back]
					end
				end
			end
		else
			error("bad block type", 0)
		end
	until last == 1
	return out, outn, pos
end

local function adler32(out, n)
	local a, b = 1, 0
	for i = 1, n do
		a = (a + out[i]) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end

local CRC
local function crc32(out, n)
	if not CRC then
		CRC = {}
		for i = 0, 255 do
			local c = i
			for _ = 1, 8 do
				c = band(c, 1) == 1 and bxor(rshift(c, 1), 0xEDB88320) or rshift(c, 1)
			end
			CRC[i] = c
		end
	end
	local c = -1
	for i = 1, n do
		c = bxor(rshift(c, 8), CRC[band(bxor(c, out[i]), 255)])
	end
	c = bxor(c, -1)
	return c < 0 and c + 4294967296 or c
end

local function bytesToString(out, n)
	local parts = {}
	for i = 1, n, 4096 do
		parts[#parts + 1] = char(unpack(out, i, math.min(i + 4095, n)))
	end
	return concat(parts)
end

local function be32(s, pos)
	local b1, b2, b3, b4 = byte(s, pos, pos + 3)
	if not b4 then
		error("truncated", 0)
	end
	return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
end

-- Enum.CompressionMethod: 0 Deflate (raw), 1 Zlib, 2 Gzip.
function M.DecompressString(source, method)
	if type(source) ~= "string" then
		return nil
	end
	method = method or 0
	local ok, result = pcall(function()
		local pos = 1
		if method == 1 then
			local cmf, flg = byte(source, 1, 2)
			if not flg or band(cmf, 15) ~= 8 or (cmf * 256 + flg) % 31 ~= 0 or band(flg, 32) ~= 0 then
				error("bad zlib header", 0)
			end
			pos = 3
		elseif method == 2 then
			local id1, id2, cm, flags = byte(source, 1, 4)
			if id1 ~= 31 or id2 ~= 139 or cm ~= 8 then
				error("bad gzip header", 0)
			end
			pos = 11
			if band(flags, 4) ~= 0 then
				pos = pos + 2 + byte(source, pos) + byte(source, pos + 1) * 256
			end
			for _, flag in ipairs({ 8, 16 }) do
				if band(flags, flag) ~= 0 then
					pos = assert(source:find("\0", pos, true)) + 1
				end
			end
			if band(flags, 2) ~= 0 then
				pos = pos + 2
			end
		elseif method ~= 0 then
			error("unknown compression method", 0)
		end
		local out, n, after = inflate(source, pos)
		if method == 1 and be32(source, after) ~= adler32(out, n) then
			error("adler32 mismatch", 0)
		elseif method == 2 then
			local c1, c2, c3, c4 = byte(source, after, after + 3)
			if not c4 or ((c4 * 256 + c3) * 256 + c2) * 256 + c1 ~= crc32(out, n) then
				error("crc32 mismatch", 0)
			end
		end
		return bytesToString(out, n)
	end)
	if ok then
		return result
	end
	return nil
end

-- CBOR, RFC 8949. Arrays become sequences, maps keep their keys, null and undefined become nil. Tags carry no
-- meaning for the client, so a tagged item decodes as the item itself.
local function float(s, pos, n)
	local b1, b2 = byte(s, pos, pos + 1)
	local sign, exp, mant, bias, mbits, emax = b1 >= 128 and -1 or 1, nil, nil, nil, nil, nil
	if n == 2 then
		exp, mant, bias, mbits, emax = floor(b1 / 4) % 32, (b1 % 4) * 256 + b2, 15, 10, 31
	elseif n == 4 then
		local b3, b4 = byte(s, pos + 2, pos + 3)
		exp, mant = (b1 % 128) * 2 + floor(b2 / 128), ((b2 % 128) * 256 + b3) * 256 + b4
		bias, mbits, emax = 127, 23, 255
	else
		local b3, b4, b5, b6, b7, b8 = byte(s, pos + 2, pos + 7)
		exp = (b1 % 128) * 16 + floor(b2 / 16)
		mant = ((((((b2 % 16) * 256 + b3) * 256 + b4) * 256 + b5) * 256 + b6) * 256 + b7) * 256 + b8
		bias, mbits, emax = 1023, 52, 2047
	end
	if exp == emax then
		return mant == 0 and sign * huge or 0 / 0
	elseif exp == 0 then
		return sign * ldexp(mant, 1 - bias - mbits)
	end
	return sign * ldexp(mant + 2 ^ mbits, exp - bias - mbits)
end

function M.DeserializeCBOR(source)
	if type(source) ~= "string" then
		return nil
	end
	local pos, item = 1, nil

	local function uint(n)
		if pos + n - 1 > #source then
			error("truncated", 0)
		end
		local v = 0
		for i = pos, pos + n - 1 do
			v = v * 256 + byte(source, i)
		end
		pos = pos + n
		return v
	end

	local function argument(info)
		if info < 24 then
			return info
		elseif info <= 27 then
			return uint(2 ^ (info - 24))
		elseif info == 31 then
			return nil -- indefinite length
		end
		error("bad additional information", 0)
	end

	local function atBreak()
		if byte(source, pos) == 255 then
			pos = pos + 1
			return true
		end
		return false
	end

	item = function()
		local initial = byte(source, pos)
		if not initial then
			error("truncated", 0)
		end
		pos = pos + 1
		local major, info = rshift(initial, 5), band(initial, 31)
		if major == 0 or major == 1 then
			local v = argument(info)
			if not v then
				error("indefinite integer", 0)
			end
			return major == 0 and v or -1 - v
		elseif major == 2 or major == 3 then
			local n = argument(info)
			if not n then
				local parts = {}
				while not atBreak() do
					parts[#parts + 1] = item()
				end
				return concat(parts)
			end
			if pos + n - 1 > #source then
				error("truncated", 0)
			end
			pos = pos + n
			return sub(source, pos - n, pos - 1)
		elseif major == 4 then
			local n, t = argument(info), {}
			if n then
				for i = 1, n do
					t[i] = item()
				end
			else
				local i = 0
				while not atBreak() do
					i = i + 1
					t[i] = item()
				end
			end
			return t
		elseif major == 5 then
			local n, t = argument(info), {}
			local i = 0
			while (n and i < n) or (not n and not atBreak()) do
				local k = item()
				local v = item()
				if k ~= nil then
					t[k] = v
				end
				i = i + 1
			end
			return t
		elseif major == 6 then
			argument(info)
			return item()
		end
		if info == 20 then
			return false
		elseif info == 21 then
			return true
		elseif info >= 25 and info <= 27 then
			local n = 2 ^ (info - 24)
			if pos + n - 1 > #source then
				error("truncated", 0)
			end
			pos = pos + n
			return float(source, pos - n, n)
		elseif info == 24 then
			pos = pos + 1
			return nil
		elseif info < 24 then
			return nil -- null, undefined and unassigned simple values
		end
		error("bad simple value", 0)
	end

	local ok, value = pcall(item)
	if ok then
		return value
	end
	return nil
end

function M.install(sim)
	for _, name in ipairs({
		"DecodeBase64",
		"EncodeBase64",
		"DecodeHex",
		"EncodeHex",
		"DecompressString",
		"DeserializeCBOR",
	}) do
		sim.impl["C_EncodingUtil." .. name] = M[name]
	end
end

return M
