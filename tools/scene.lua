-- Chat messages for the listing screenshots (tools/screenshots.py): each one as it arrives and as the addon's own
-- chat filter rewrites it on SkillUp Forever's headless Forever client (forever_sim). Prints one JSON object per
-- line: {"before": ..., "after": ...}.
--
-- Run through tools/screenshots.py, which sets FOREVER_SIM, QUESTLINKS_SIM_CACHE and the messages (one per line on
-- stdin) and the player's level (QUESTLINKS_SCENE_LEVEL).
local SIM = assert(os.getenv("FOREVER_SIM"), "FOREVER_SIM is not set: run tools/screenshots.py")
local CACHE = assert(os.getenv("QUESTLINKS_SIM_CACHE"), "QUESTLINKS_SIM_CACHE is not set: run tools/screenshots.py")
local LEVEL = tonumber(os.getenv("QUESTLINKS_SCENE_LEVEL") or "") or 30
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"

local Sim = dofile(SIM .. "sim.lua")
local sim = Sim.new({ cache = CACHE })
sim:loadBlizzard("Blizzard_ChatFrameBase")
sim:addon(here .. "..")
local unitLevel = sim.impl.UnitEffectiveLevel
sim.impl.UnitEffectiveLevel = function(unit)
	if unit == "player" then
		return LEVEL
	end
	return unitLevel(unit)
end
-- The sim's UnitQuestTrivialLevelRange is a bare stub; 8 stands in for the client's value. tools/screenshots.py picks
-- quest levels whose colour does not hang on it.
rawset(sim.G, "UnitQuestTrivialLevelRange", function()
	return 8
end)
sim:login({ savedVariables = { ClickableQuestLinksDB = { colorByDifficulty = true } } })

local function json(text)
	return '"' .. text:gsub('[%c"\\]', function(c)
		return ("\\u%04x"):format(c:byte())
	end) .. '"'
end

local G = sim.G
for msg in io.lines() do
	local discard, out = G.ChatFrameUtil.ProcessMessageEventFilters(
		G.ChatFrame1,
		"CHAT_MSG_CHANNEL",
		msg,
		"Scene-Realm",
		"",
		"1. General",
		"Scene",
		"",
		1,
		1,
		"General",
		0,
		1,
		"Player-1-0001",
		0,
		false,
		false,
		false
	)
	assert(not discard, "a filter discarded the message")
	print(("{%s: %s, %s: %s}"):format(json("before"), json(msg), json("after"), json(out or msg)))
end
