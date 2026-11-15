-- Tests for encodingutil.lua. The base64, compressed and CBOR vectors come from Python's base64, zlib, gzip and cbor2;
-- the CBOR forms cbor2 does not write (indefinite lengths, tags, simple values) are from RFC 8949. LuaJIT alone runs
-- it: luajit tests/encodingutil_test.lua (tests/run.sh does, before the scenarios).
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local E = dofile(here .. "encodingutil.lua")

local failed, total = 0, 0
local function check(what, ok)
	total = total + 1
	if not ok then
		failed = failed + 1
		print("FAIL  encodingutil: " .. what)
	end
end

local function hex(s)
	return (s:gsub("%x%x", function(h)
		return string.char(tonumber(h, 16))
	end))
end

local function same(a, b)
	if type(a) ~= type(b) then
		return false
	elseif type(a) ~= "table" then
		return a == b or (a ~= a and b ~= b)
	end
	for k, v in pairs(a) do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Base64, both alphabets, every padding length.
for _, v in ipairs({
	{ "", "", "" },
	{ "f", "Zg==", "Zg==" },
	{ "fo", "Zm8=", "Zm8=" },
	{ "foo", "Zm9v", "Zm9v" },
	{ "foob", "Zm9vYg==", "Zm9vYg==" },
	{ "fooba", "Zm9vYmE=", "Zm9vYmE=" },
	{ "foobar", "Zm9vYmFy", "Zm9vYmFy" },
	{ "\251\255\191", "+/+/", "-_-_" },
}) do
	check("EncodeBase64 " .. v[2], E.EncodeBase64(v[1]) == v[2])
	check("EncodeBase64 URL-safe " .. v[3], E.EncodeBase64(v[1], 1) == v[3])
	check("DecodeBase64 " .. v[2], E.DecodeBase64(v[2]) == v[1])
	check("DecodeBase64 URL-safe " .. v[3], E.DecodeBase64(v[3], 1) == v[1])
end
check("DecodeBase64 without padding", E.DecodeBase64("Zm8") == "fo")
check("DecodeBase64 rejects a stray character", E.DecodeBase64("Zm9v!") == nil)
check("DecodeBase64 rejects one trailing character", E.DecodeBase64("Zm9vY") == nil)
check("DecodeBase64 rejects the other alphabet", E.DecodeBase64("-_-_") == nil)

check("EncodeHex", E.EncodeHex("\0\255ab") == "00ff6162")
check("DecodeHex", E.DecodeHex("00FF6162") == "\0\255ab")
check("DecodeHex rejects an odd length", E.DecodeHex("abc") == nil)
check("DecodeHex rejects a non-hex digit", E.DecodeHex("zz") == nil)

-- Enum.CompressionMethod 0 Deflate, 1 Zlib, 2 Gzip, at levels that give stored, fixed and dynamic Huffman blocks.
local SHORT = "hello hello hello"
local lines, bytes = {}, {}
for i = 0, 59 do
	lines[#lines + 1] = ("line %d: the quick brown fox jumps over the lazy dog\n"):format(i)
end
for i = 0, 255 do
	bytes[#bytes + 1] = string.char(i)
end
local TEXT, BINARY = table.concat(lines), table.concat(bytes):rep(4)
for _, v in ipairs({
	{ "short", 0, 0, SHORT, "011100eeff68656c6c6f2068656c6c6f2068656c6c6f" },
	{ "short", 0, 1, SHORT, "cb48cdc9c957c8409000" },
	{ "short", 0, 9, SHORT, "cb48cdc9c957c8409000" },
	{ "short", 1, 0, SHORT, "7801011100eeff68656c6c6f2068656c6c6f2068656c6c6f3a2e067d" },
	{ "short", 1, 1, SHORT, "7801cb48cdc9c957c84090003a2e067d" },
	{ "short", 1, 9, SHORT, "78dacb48cdc9c957c84090003a2e067d" },
	{
		"short",
		2,
		0,
		SHORT,
		"1f8b08080000000000ff746578742e74787400011100eeff68656c6c6f2068656c6c6f2068656c6c6f8088f9e5110000" .. "00",
	},
	{ "short", 2, 1, SHORT, "1f8b08080000000004ff746578742e74787400cb48cdc9c957c84090008088f9e511000000" },
	{ "short", 2, 9, SHORT, "1f8b08080000000002ff746578742e74787400cb48cdc9c957c84090008088f9e511000000" },
	{
		"text",
		0,
		1,
		TEXT,
		"9dd2c91501511400d1bd285e08de64cac6f0d1b4fe346d8ade2103b5ae53bbdb365d91f1426efb2297a1591f65d5d747"
			.. "27dbfa94c3703a5fa5de4bffcbedf2fd924ddd8ddaefa3e031f03878023c099e0978a6e09981670e1e45108804251494"
			.. "585082418906251c9478500242890823228c883022c2880823228c883022c2880823228c887022c2890827229c887022"
			.. "c2890827229c887022c28988202282880822228888202282880822228888202282884822228988242292884822228988"
			.. "24229288482222ff14f101",
	},
	{
		"text",
		1,
		9,
		TEXT,
		"78da9dd6c711c2400c40d13b55a8049448dd101630182f184caa9e810ef867cd3fe9cdaedaa62b325ec86d5fe43234eb"
			.. "a3acfafae8645b9f72184ee7abd47be97fe376f97ec9a6ee46edb751d018681c34019a04cd043453d0cc4033273b4510"
			.. "8804251494585082418906251c9478500242890823220cbd0d4484111146441811614484111146441811e1448413118e"
			.. "be0b22c2890827229c887022c28908272282880822228888401704111144441011414404111144441211494424119144"
			.. "44a2a3928848222289882422f24f111f95ef572d",
	},
	{
		"text",
		2,
		9,
		TEXT,
		"1f8b08080000000002ff746578742e747874009dd6c711c2400c40d13b55a8049448dd101630182f184caa9e810ef867"
			.. "cd3fe9cdaedaa62b325ec86d5fe43234eba3acfafae8645b9f72184ee7abd47be97fe376f97ec9a6ee46edb751d01868"
			.. "1c34019a04cd043453d0cc4033273b45108804251494585082418906251c9478500242890823220cbd0d448411114644"
			.. "1811614484111146441811e1448413118ebe0b22c2890827229c887022c2890827228288082222888840170411114444"
			.. "101141440411114444121149442411914444a2a3928848222289882422f24f111fa94d10c3620c0000",
	},
	{
		"binary",
		0,
		9,
		BINARY,
		"6360646266616563e7e0e4e2e6e1e5e3171014121611151397909492969195935750545256515553d7d0d4d2d6d1d5d3"
			.. "3730343236313533b7b0b4b2b6b1b5b37770747276717573f7f0f4f2f6f1f5f30f080c0a0e090d0b8f888c8a8e898d8b"
			.. "4f484c4a4e494d4bcfc8cccacec9cdcb2f282c2a2e292d2bafa8acaaaea9adab6f686c6a6e696d6befe8eceaeee9edeb"
			.. "9f3071d2e42953a74d9f3173d6ec3973e7cd5fb070d1e2254b972d5fb172d5ea356bd7addfb071d3e62d5bb76ddfb173"
			.. "d7ee3d7bf7ed3f70f0d0e123478f1d3f71f2d4e93367cf9dbf70f1d2e52b57af5dbf71f3d6ed3b77efdd7ff0f0d1e327"
			.. "4f9f3d7ff1f2d5eb376fdfbdfff0f1d3e72f5fbf7dfff1f3d7ef3f7ffffd6718f5ffa8ff47b0ff01",
	},
	{
		"binary",
		1,
		1,
		BINARY,
		"78016360646266616563e7e0e4e2e6e1e5e3171014121611151397909492969195935750545256515553d7d0d4d2d6d1"
			.. "d5d33730343236313533b7b0b4b2b6b1b5b37770747276717573f7f0f4f2f6f1f5f30f080c0a0e090d0b8f888c8a8e89"
			.. "8d8b4f484c4a4e494d4bcfc8cccacec9cdcb2f282c2a2e292d2bafa8acaaaea9adab6f686c6a6e696d6befe8eceaeee9"
			.. "edeb9f3071d2e42953a74d9f3173d6ec3973e7cd5fb070d1e2254b972d5fb172d5ea356bd7addfb071d3e62d5bb76ddf"
			.. "b173d7ee3d7bf7ed3f70f0d0e123478f1d3f71f2d4e93367cf9dbf70f1d2e52b57af5dbf71f3d6ed3b77efdd7ff0f0d1"
			.. "e3274f9f3d7ff1f2d5eb376fdfbdfff0f1d3e72f5fbf7dfff1f3d7ef3f7ffffd6718f5ff68fc8fe0f40f00e4c9fe10",
	},
}) do
	local got = E.DecompressString(hex(v[5]), v[2])
	check(("DecompressString %s, method %d, level %d"):format(v[1], v[2], v[3]), got == v[4])
end
local zlibText = hex(
	"78da9dd6c711c2400c40d13b55a8049448dd101630182f184caa9e810ef867cd3fe9cdaedaa62b325ec86d5fe43234eb"
		.. "a3acfafae8645b9f72184ee7abd47be97fe376f97ec9a6ee46edb751d018681c34019a04cd043453d0cc4033273b4510"
		.. "8804251494585082418906251c9478500242890823220cbd0d4484111146441811614484111146441811e1448413118e"
		.. "be0b22c2890827229c887022c28908272282880822228888401704111144441011414404111144441211494424119144"
		.. "44a2a3928848222289882422f24f111f95ef572d"
)
check("DecompressString rejects a wrong Adler-32", E.DecompressString(zlibText:sub(1, -2) .. "\0", 1) == nil)
check("DecompressString rejects a truncated stream", E.DecompressString(zlibText:sub(1, 40), 1) == nil)
check("DecompressString rejects zlib data read as gzip", E.DecompressString(zlibText, 2) == nil)
check("DecompressString rejects an unknown method", E.DecompressString(zlibText, 7) == nil)

for _, v in ipairs({
	{ "00", 0 },
	{ "17", 23 },
	{ "1818", 24 },
	{ "18ff", 255 },
	{ "190100", 256 },
	{ "19ffff", 65535 },
	{ "1a00010000", 65536 },
	{ "1b0000000100000000", 4294967296 },
	{ "1b0000010000000003", 1099511627779 },
	{ "20", -1 },
	{ "37", -24 },
	{ "3818", -25 },
	{ "38ff", -256 },
	{ "3affffffff", -4294967296 },
	{ "f93e00", 1.5 },
	{ "fb3ff8000000000000", 1.5 },
	{ "f98000", -0.0 },
	{ "fa47c35000", 100000.0 },
	{ "fb3ff199999999999a", 1.1 },
	{ "f90001", 5.960464477539063e-08 },
	{ "f97bff", 65504.0 },
	{ "f97c00", math.huge },
	{ "6668c3a96c6c6f", "h\195\169llo" },
	{ "420001", "\0\1" },
	{
		"a54170191286016e526170746f72204d61737465727904181c0518220281811902cb",
		{ p = 4742, [1] = "Raptor Mastery", [2] = { { 715 } }, [4] = 28, [5] = 34 },
	},
	{ "9f0102ff", { 1, 2 } },
	{ "7f61616162ff", "ab" },
	{ "5f4201024103ff", "\1\2\3" },
	{ "bf616101ff", { a = 1 } },
	{ "8301f603", { [1] = 1, [3] = 3 } },
	{ "c11a514b67b0", 1363896240 },
	{ "f5", true },
	{ "f4", false },
	{ "f6", nil },
}) do
	check("DeserializeCBOR " .. v[1], same(E.DeserializeCBOR(hex(v[1])), v[2]))
end
local nan = E.DeserializeCBOR(hex("f97e00"))
check("DeserializeCBOR NaN", nan ~= nan)
check("DeserializeCBOR rejects truncated input", E.DeserializeCBOR(hex("1a0001")) == nil)
check("DeserializeCBOR of nothing", E.DeserializeCBOR("") == nil)

print(("encodingutil: %d of %d checks passed"):format(total - failed, total))
if failed > 0 then
	os.exit(1)
end
