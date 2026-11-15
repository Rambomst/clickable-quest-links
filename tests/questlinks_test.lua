-- Scenario tests for Clickable Quest Links on SkillUp Forever's headless Forever client (forever_sim): Blizzard's
-- real chat filter registry (ChatFrameUtil), SetItemRef and ItemRefTooltip, with a fake QuestieDB
-- (fixtures/QuestieDB) and, for the "real QuestieDB" scenarios, the released one. Run with tests/run.sh, which sets
-- FOREVER_SIM, QUESTLINKS_SIM_CACHE and REAL_QUESTIEDB.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local SIM = assert(os.getenv("FOREVER_SIM"), "FOREVER_SIM is not set: run tests/run.sh")
local CACHE = assert(os.getenv("QUESTLINKS_SIM_CACHE"), "QUESTLINKS_SIM_CACHE is not set: run tests/run.sh")
local ADDON = "ClickableQuestLinks"
-- The repository root holds the addon's TOC; QUESTLINKS_ADDON_DIR runs the scenarios against another copy, such as
-- the installed one.
local ADDON_DIR = os.getenv("QUESTLINKS_ADDON_DIR") or (here .. "..")
local FAKE_DB_DIR = here .. "fixtures/QuestieDB"
-- The development-only addon behind /cqltest, which runs these quests in the real client.
local SELFTEST_DIR = here .. "ingame/ClickableQuestLinks_SelfTest"
-- The other quest databases the addon reads, as stand-ins with their APIs' shapes.
local FAKE_SOURCES = { ding = "fixtures/Ding", polestar = "fixtures/Polestar", donData = "fixtures/DonData" }
-- The UiMap names the fixtures' and the real databases' spawns need, as the pinned Forever build names those maps.
local MAP_NAMES = {
	[1411] = "Durotar",
	[1413] = "The Barrens",
	[1431] = "Duskwood",
	[1434] = "Stranglethorn Vale",
	[1436] = "Westfall",
	[1440] = "Ashenvale",
	[1454] = "Orgrimmar",
}

-- The released databases, pinned and fetched by tests/run.sh. QuestieDB keeps its data in TOC metadata that
-- C_EncodingUtil decodes; REAL_POLESTAR holds Polestar and its load-on-demand Polestar_QuestDB.
local function real(name)
	return assert(os.getenv(name), name .. " is not set: run tests/run.sh")
end
local REAL_QUESTIEDB, REAL_DING = real("REAL_QUESTIEDB"), real("REAL_DING")
local REAL_DONDATA, REAL_POLESTAR = real("REAL_DONDATA"), real("REAL_POLESTAR")
-- The sim has no AreaTable, the client's source of zone names; these are the pinned Forever build's names for the
-- area IDs the real QuestieDB gives the quests below.
local AREA_NAMES = {
	[10] = "Duskwood",
	[17] = "The Barrens",
	[33] = "Stranglethorn Vale",
	[40] = "Westfall",
	[331] = "Ashenvale",
	[1637] = "Orgrimmar",
}

local Sim = dofile(SIM .. "sim.lua")
local EncodingUtil = dofile(here .. "encodingutil.lua")

local RAPTOR = "|cffffff00|Hquest:194:34|h[Raptor Mastery]|h|r"

-- A client with chat and ItemRef loaded before the addons, as the real client has them.
-- opts.questieDB (default true), opts.questie (Questie stand-in), opts.contract (fake QuestieDB contract),
-- opts.addon (default true; false boots Blizzard's behaviour alone, for comparison), opts.locale (the client language
-- the addon loads under), opts.saved (saved variables; by default difficulty colours are off, so converted links are
-- plain yellow), opts.level (the player's level; the sim's is 60), opts.ding, opts.polestar and opts.donData (load
-- that database's stand-in), opts.polestarUnloaded (Polestar's reads fail, as before its data loads),
-- opts.realQuestieDB (the released QuestieDB instead of the fake one), opts.realDing, opts.realDonData and
-- opts.realPolestar (that released addon), opts.selfTest (the /cqltest addon, after this one).
local function boot(opts)
	opts = opts or {}
	local sim = Sim.new({ cache = CACHE })
	EncodingUtil.install(sim)
	-- Under its folder's name, as the client names an addon. The sim takes the first TOC's name, which for QuestieDB
	-- and DonData is Forever's flavour file (QuestieDB_Camelot.toc), and C_AddOns.IsAddOnLoaded("QuestieDB") then
	-- says false.
	local function realAddon(dir)
		sim:addon(dir, dir:match("([^/]+)/*$"))
	end
	-- Sim gap: its SetOwner drops a tooltip's points even for ANCHOR_PRESERVE, which in the client keeps them (and
	-- Blizzard's ItemRefSetHyperlink then does arithmetic on the unplaced title's GetRight).
	local tooltipMethods = sim.widgets.methods.GameTooltip
	local setOwner = tooltipMethods.SetOwner
	tooltipMethods.SetOwner = function(self, owner, anchor, ...)
		local state = sim.widgets.state[self]
		local points = state and state.points
		setOwner(self, owner, anchor, ...)
		if anchor == "ANCHOR_PRESERVE" and points and next(points) then
			state.points = points
		end
	end
	sim:loadBlizzard("Blizzard_ChatFrameBase")
	sim:loadBlizzard("Blizzard_UIPanels_Game")
	if opts.contract then
		sim.G.FAKE_QUESTIEDB_CONTRACT = opts.contract
	end
	if opts.realQuestieDB then
		realAddon(REAL_QUESTIEDB)
		sim.impl["C_Map.GetAreaInfo"] = function(areaID)
			return AREA_NAMES[areaID]
		end
	elseif opts.questieDB ~= false then
		sim:addon(FAKE_DB_DIR)
	end
	for option, dir in pairs(FAKE_SOURCES) do
		if opts[option] then
			sim:addon(here .. dir)
		end
	end
	if opts.realDing then
		realAddon(REAL_DING)
	end
	if opts.realDonData then
		realAddon(REAL_DONDATA)
	end
	if opts.realPolestar then
		realAddon(REAL_POLESTAR .. "/Polestar")
		realAddon(REAL_POLESTAR .. "/Polestar_QuestDB")
	end
	if opts.polestarUnloaded then
		sim.G.FAKE_POLESTAR_UNLOADED = true
	end
	for mapID, name in pairs(MAP_NAMES) do
		sim.world.maps[mapID] = { name = name }
	end
	if opts.questie then
		sim:stub("Questie")
	end
	if opts.locale then
		-- Set after Blizzard's code has loaded: Sim.new({ locale }) would need that locale's global strings fetched.
		sim.locale = opts.locale
	end
	if opts.addon ~= false then
		sim:addon(ADDON_DIR)
	end
	if opts.selfTest then
		sim:addon(SELFTEST_DIR)
	end
	sim.loadRequests = {}
	sim.impl["C_QuestLog.RequestLoadQuestByID"] = function(questID)
		sim.loadRequests[#sim.loadRequests + 1] = questID
	end
	if opts.level then
		local unitLevel = sim.impl.UnitEffectiveLevel
		sim.impl.UnitEffectiveLevel = function(unit)
			if unit == "player" then
				return opts.level
			end
			return unitLevel(unit)
		end
	end
	-- The sim's UnitQuestTrivialLevelRange is a bare stub; this gives GetQuestDifficultyColor's green band a real size.
	rawset(sim.G, "UnitQuestTrivialLevelRange", function()
		return 8
	end)
	sim:login({ savedVariables = opts.saved or { ClickableQuestLinksDB = { colorByDifficulty = false } } })
	return sim, sim.G
end

-- The message after the chat filters, as ChatFrame_MessageEventHandler gets it.
local function filtered(sim, msg, event)
	local G = sim.G
	local discard, out = G.ChatFrameUtil.ProcessMessageEventFilters(
		G.ChatFrame1,
		event or "CHAT_MSG_WHISPER",
		msg,
		"Mulan-Arugal",
		"",
		"",
		"Mulan",
		"",
		0,
		0,
		"",
		0,
		7,
		"Player-1-0001",
		0,
		false,
		false,
		false
	)
	assert(not discard, "a filter discarded the message")
	return out
end

local function eq(actual, expected, what)
	if actual ~= expected then
		error(("%s:\n  expected %q\n  got      %q"):format(what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function tooltipLines(G)
	local out = {}
	for i = 1, G.ItemRefTooltip:NumLines() do
		local fs = G["ItemRefTooltipTextLeft" .. i]
		out[#out + 1] = fs and fs:GetText() or ""
	end
	return out
end

local function hasLine(lines, text)
	for _, line in ipairs(lines) do
		if line:find(text, 1, true) then
			return true
		end
	end
	return false
end

local function expectLines(lines, wanted)
	for _, text in ipairs(wanted) do
		assert(hasLine(lines, text), text .. " missing:\n" .. table.concat(lines, "\n"))
	end
end

-- Quest tooltip data for the quests the client has, and creature tooltips (a unit link's first line is the name)
-- for the NPCs it has; others get nil, as for a quest or creature the client never loaded.
local function serveQuests(sim, known, creatures)
	local G = sim.G
	sim.impl["C_TooltipInfo.GetHyperlink"] = function(link)
		local npc = tonumber(tostring(link):match("^unit:Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
		if npc then
			local name = creatures and creatures[npc]
			return name and { type = G.Enum.TooltipDataType.Unit, lines = { { leftText = name } } } or nil
		end
		local id = tonumber(tostring(link):match("^quest:(%d+)"))
		local quest = id and known[id]
		if not quest then
			return nil
		end
		return {
			type = G.Enum.TooltipDataType.Quest,
			id = id,
			lines = {
				{ type = G.Enum.TooltipDataLineType.QuestTitle, leftText = quest.title },
				{ type = G.Enum.TooltipDataLineType.None, leftText = quest.text },
			},
		}
	end
end

local function click(G, link)
	G.SetItemRef(link:match("|H(.-)|h"), link, "LeftButton", G.ChatFrame1)
end

local scenarios = {}
local function scenario(name, fn)
	scenarios[#scenarios + 1] = { name = name, fn = fn }
end

scenario("level form becomes a native quest link", function()
	local sim = boot()
	eq(filtered(sim, "[[34] Raptor Mastery (194)]"), RAPTOR)
	sim:expectNoErrors(ADDON)
end)

scenario("plain form converts when the name matches the quest", function()
	local sim = boot()
	eq(filtered(sim, "[Raptor Mastery (194)]"), RAPTOR)
	eq(filtered(sim, "[raptor mastery (194)]"), RAPTOR, "name match ignores case")
end)

scenario("plain form with another quest's ID is left alone", function()
	local sim = boot()
	local msg = "remember [Hello there (194)] lol"
	eq(filtered(sim, msg), msg)
end)

-- The level form is Questie's own, so it converts even for a quest the reader's database does not have yet; the plain
-- form needs a name to check against.
scenario("a quest no database knows converts only in the level form", function()
	local sim = boot()
	eq(filtered(sim, "[[10] Nope (99999)]"), "|cffffff00|Hquest:99999:10|h[Nope]|h|r")
	for _, msg in ipairs({ "[Nope (99999)]", "[[1] Huge (99999999999)]" }) do
		eq(filtered(sim, msg), msg)
	end
end)

scenario("surrounding text and existing links stay as they are", function()
	local sim = boot()
	local item = "|cff9d9d9d|Hitem:3300::::::::34:::::::::|h[Rabbit's Foot (194)]|h|r"
	eq(
		filtered(sim, "need " .. item .. " and [[34] Raptor Mastery (194)] pls"),
		"need " .. item .. " and " .. RAPTOR .. " pls"
	)
end)

scenario("several links in one message", function()
	local sim = boot()
	eq(
		filtered(
			sim,
			"[[34] Raptor Mastery (194)], [The Defias Brotherhood (155)] and [[18] The Defias Brotherhood (155)]"
		),
		RAPTOR
			.. ", |cffffff00|Hquest:155:18|h[The Defias Brotherhood]|h|r and |cffffff00|Hquest:155:18|h[The Defias Brotherhood]|h|r"
	)
end)

scenario("names with pattern characters and their own parentheses", function()
	local sim = boot()
	local link = "|cffffff00|Hquest:9001:10|h[100% Ready - Part (2)]|h|r"
	eq(filtered(sim, "[[10] 100% Ready - Part (2) (9001)]"), link)
	eq(filtered(sim, "[100% Ready - Part (2) (9001)]"), link)
end)

scenario("QuestieDB's level wins over the level the sender showed", function()
	local sim = boot()
	eq(filtered(sim, "[[99+] Raptor Mastery (194)]"), RAPTOR)
end)

scenario("every chat type Questie links in is covered", function()
	local sim = boot()
	for _, event in ipairs({
		"CHAT_MSG_SAY",
		"CHAT_MSG_YELL",
		"CHAT_MSG_EMOTE",
		"CHAT_MSG_WHISPER",
		"CHAT_MSG_WHISPER_INFORM",
		"CHAT_MSG_BN",
		"CHAT_MSG_BN_WHISPER",
		"CHAT_MSG_BN_WHISPER_INFORM",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER",
		"CHAT_MSG_RAID_WARNING",
		"CHAT_MSG_INSTANCE_CHAT",
		"CHAT_MSG_INSTANCE_CHAT_LEADER",
		"CHAT_MSG_GUILD",
		"CHAT_MSG_OFFICER",
		"CHAT_MSG_CHANNEL",
	}) do
		eq(filtered(sim, "[[34] Raptor Mastery (194)]", event), RAPTOR, event)
	end
end)

scenario("a secret message is passed over without errors", function()
	local sim = boot()
	local secret = sim.secret.wrap("[[34] Raptor Mastery (194)]")
	local out = filtered(sim, secret)
	eq(out, secret, "message")
	sim:expectNoErrors(ADDON)
end)

scenario("quest data is requested once per quest the client has not loaded", function()
	local sim = boot()
	filtered(sim, "[[34] Raptor Mastery (194)]")
	filtered(sim, "[[34] Raptor Mastery (194)] again")
	eq(#sim.loadRequests, 1, "requests")
	eq(sim.loadRequests[1], 194, "requested quest")
end)

scenario("the client's own title is used and nothing is requested when it has the quest", function()
	local sim = boot()
	sim.impl["C_QuestLog.GetTitleForQuestID"] = function(questID)
		return questID == 194 and "Raptor Mastery" or nil
	end
	eq(filtered(sim, "[[34] raptor mastery (194)]"), RAPTOR)
	eq(#sim.loadRequests, 0, "requests")
end)

scenario("without QuestieDB only the level form converts, with the sent level", function()
	local sim = boot({ questieDB = false })
	eq(filtered(sim, "[[34] Raptor Mastery (194)]"), RAPTOR)
	local plain = "[Raptor Mastery (194)]"
	eq(filtered(sim, plain), plain)
	sim:expectNoErrors(ADDON)
end)

scenario("a QuestieDB with an incompatible contract counts as missing", function()
	local sim = boot({ contract = 3 })
	eq(filtered(sim, "[[34] Raptor Mastery (194)]"), RAPTOR)
	local plain = "[Raptor Mastery (194)]"
	eq(filtered(sim, plain), plain)
	sim:expectNoErrors(ADDON)
end)

scenario("with Questie loaded nothing is rewritten", function()
	local sim = boot({ questie = true })
	local msg = "[[34] Raptor Mastery (194)]"
	eq(filtered(sim, msg), msg)
	sim:expectNoErrors(ADDON)
end)

scenario("clicking the link shows Blizzard's tooltip plus level, start and end", function()
	local sim, G = boot()
	serveQuests(sim, { [194] = { title = "Raptor Mastery", text = "Kill 10 Stranglethorn Raptors." } })
	click(G, filtered(sim, "[[34] Raptor Mastery (194)]"))
	assert(G.ItemRefTooltip:IsShown(), "tooltip not shown")
	local lines = tooltipLines(G)
	eq(lines[1], "Raptor Mastery", "title")
	eq(lines[2], "Kill 10 Stranglethorn Raptors.", "client text")
	assert(hasLine(lines, "Level:|r 34 (requires 30)"), "level line missing:\n" .. table.concat(lines, "\n"))
	assert(hasLine(lines, "Starts:|r Hemet Nesingwary Jr."), "start line missing")
	assert(hasLine(lines, "Ends:|r Hemet Nesingwary Jr."), "end line missing")
	sim:expectNoErrors(ADDON)
end)

scenario("a refreshed tooltip gets the lines once", function()
	local sim, G = boot()
	serveQuests(sim, { [194] = { title = "Raptor Mastery", text = "Kill 10 Stranglethorn Raptors." } })
	click(G, filtered(sim, "[[34] Raptor Mastery (194)]"))
	local before = G.ItemRefTooltip:NumLines()
	-- What the client does when quest data arrives for a shown tooltip.
	G.ItemRefTooltip:RefreshData()
	eq(G.ItemRefTooltip:NumLines(), before, "line count after refresh")
	sim:expectNoErrors(ADDON)
end)

-- Blizzard closes ItemRefTooltip when the link it shows is clicked again. The sim does not reproduce that close
-- even without the addon, so this holds the addon to Blizzard's behaviour rather than to a fixed outcome.
scenario("a second click on a link the client has data for behaves as without the addon", function()
	local outcome = {}
	for _, withAddon in ipairs({ false, true }) do
		local sim, G = boot({ addon = withAddon })
		serveQuests(sim, { [194] = { title = "Raptor Mastery", text = "Kill 10 Stranglethorn Raptors." } })
		click(G, RAPTOR)
		local first = G.ItemRefTooltip:IsShown()
		click(G, RAPTOR)
		outcome[withAddon] = tostring(first) .. "/" .. tostring(G.ItemRefTooltip:IsShown())
		sim:expectNoErrors(ADDON)
	end
	eq(outcome[true], outcome[false], "shown after first/second click, with the addon vs without")
end)

scenario("a quest the client has no data for still shows QuestieDB's details", function()
	local sim, G = boot()
	serveQuests(sim, {})
	click(G, filtered(sim, "[The Defias Brotherhood (155)]"))
	assert(G.ItemRefTooltip:IsShown(), "tooltip not shown")
	local lines = tooltipLines(G)
	eq(lines[1], "The Defias Brotherhood", "title")
	assert(hasLine(lines, "Starts:|r Gryan Stoutmantle"), "start line missing:\n" .. table.concat(lines, "\n"))
	sim:expectNoErrors(ADDON)
end)

scenario("a data-less tooltip replaces the previous quest's lines", function()
	local sim, G = boot()
	serveQuests(sim, { [194] = { title = "Raptor Mastery", text = "Kill 10 Stranglethorn Raptors." } })
	click(G, filtered(sim, "[[34] Raptor Mastery (194)]"))
	click(G, filtered(sim, "[The Defias Brotherhood (155)]"))
	local lines = tooltipLines(G)
	eq(lines[1], "The Defias Brotherhood", "title")
	assert(not hasLine(lines, "Raptor"), "old quest lines left over:\n" .. table.concat(lines, "\n"))
end)

scenario("objects, items and long finisher lists", function()
	local sim, G = boot()
	serveQuests(sim, {})
	click(G, filtered(sim, "[[10] 100% Ready - Part (2) (9001)]"))
	local lines = tooltipLines(G)
	assert(hasLine(lines, "Starts:|r Wanted Poster"), "object starter missing:\n" .. table.concat(lines, "\n"))
	assert(hasLine(lines, "Ends:|r First Finisher, Second Finisher and 1 more"), "finisher list wrong")
	assert(not hasLine(lines, "requires"), "same required level should not be repeated")
	click(G, filtered(sim, "[[20] A Note in the Water (9002)]"))
	lines = tooltipLines(G)
	assert(hasLine(lines, "Starts:|r Soggy Note (item)"), "item starter missing:\n" .. table.concat(lines, "\n"))
	sim:expectNoErrors(ADDON)
end)

scenario("Ding!'s database gives the lines without QuestieDB, with zones from its UiMap spawns", function()
	local sim, G = boot({ questieDB = false, ding = true })
	serveQuests(sim, {})
	click(G, filtered(sim, "[[17] The Spirits of Stonetalon (1061)]"))
	assert(G.ItemRefTooltip:IsShown(), "tooltip not shown")
	local lines = tooltipLines(G)
	eq(lines[1], "The Spirits of Stonetalon", "title")
	assert(hasLine(lines, "Level:|r 17 (requires 13)"), "level line:\n" .. table.concat(lines, "\n"))
	-- Zor Lonetree has more spawns in Orgrimmar than in Durotar.
	assert(hasLine(lines, "Starts:|r Zor Lonetree (Orgrimmar)"), "start line")
	assert(hasLine(lines, "Ends:|r Seereth Stonebreak (The Barrens)"), "end line")
	click(G, filtered(sim, "[[15] Posted Bounty (7002)]"))
	lines = tooltipLines(G)
	assert(hasLine(lines, "Starts:|r Bounty Board (The Barrens)"), "object starter:\n" .. table.concat(lines, "\n"))
	sim:expectNoErrors(ADDON)
end)

scenario("Ding!'s English names let a plain link from an English client convert on another", function()
	local sim, G = boot({ questieDB = false, ding = true })
	eq(filtered(sim, "[A Letter in the Water (7001)]"), "|cffffff00|Hquest:7001:12|h[Ein Brief im Wasser]|h|r")
	serveQuests(sim, {})
	click(G, filtered(sim, "[A Letter in the Water (7001)]"))
	assert(hasLine(tooltipLines(G), "Starts:|r Torn Letter (item)"), "item starter")
	sim:expectNoErrors(ADDON)
end)

scenario("QuestieDB answers first, and Ding! for quests QuestieDB lacks", function()
	local sim, G = boot({ ding = true })
	serveQuests(sim, {})
	click(G, filtered(sim, "[[34] Raptor Mastery (194)]"))
	local lines = tooltipLines(G)
	assert(hasLine(lines, "Starts:|r Hemet Nesingwary Jr."), "QuestieDB's starter:\n" .. table.concat(lines, "\n"))
	assert(not hasLine(lines, "Ding's Hemet"), "Ding's starter used over QuestieDB's")
	click(G, filtered(sim, "[The Spirits of Stonetalon (1061)]"))
	assert(hasLine(tooltipLines(G), "Starts:|r Zor Lonetree (Orgrimmar)"), "Ding's answer for a quest QuestieDB lacks")
	sim:expectNoErrors(ADDON)
end)

scenario("Polestar's database gives the lines, with objects among the finishers", function()
	local sim, G = boot({ questieDB = false, polestar = true })
	serveQuests(sim, {})
	click(G, filtered(sim, "[Cleansing the Oasis (2001)]"))
	local lines = tooltipLines(G)
	eq(lines[1], "Cleansing the Oasis", "title")
	assert(hasLine(lines, "Level:|r 25 (requires 20)"), "level line:\n" .. table.concat(lines, "\n"))
	assert(hasLine(lines, "Starts:|r Oasis Druid (The Barrens)"), "start line")
	assert(hasLine(lines, "Ends:|r Grove Keeper (Ashenvale), Moonwell (Ashenvale)"), "end line")
	sim:expectNoErrors(ADDON)
end)

scenario("Polestar's database before its data loads is passed over without errors", function()
	local sim, G = boot({ questieDB = false, polestar = true, polestarUnloaded = true })
	eq(filtered(sim, "[[25] Cleansing the Oasis (2001)]"), "|cffffff00|Hquest:2001:25|h[Cleansing the Oasis]|h|r")
	local plain = "[Cleansing the Oasis (2001)]"
	eq(filtered(sim, plain), plain)
	serveQuests(sim, {})
	click(G, filtered(sim, "[[25] Cleansing the Oasis (2001)]"))
	assert(not G.ItemRefTooltip:IsShown(), "a tooltip with nothing to show")
	sim:expectNoErrors(ADDON)
end)

scenario("DonData names a starter and a finisher, with the link's level", function()
	local sim, G = boot({ questieDB = false, donData = true })
	serveQuests(sim, {})
	local link = filtered(sim, "[[14] Supplies for the Crossroads (4001)]")
	eq(link, "|cffffff00|Hquest:4001:14|h[Supplies for the Crossroads]|h|r", "the sender's name, not DonData's")
	click(G, link)
	local lines = tooltipLines(G)
	eq(lines[1], "Supplies for the Crossroads", "title")
	assert(hasLine(lines, "Level:|r 14 (requires 12)"), "level line:\n" .. table.concat(lines, "\n"))
	assert(hasLine(lines, "Starts:|r Supply Officer (The Barrens) and 1 more"), "start line")
	assert(hasLine(lines, "Ends:|r Quartermaster (The Barrens)"), "end line")
	click(G, filtered(sim, "[Word to the Wise (4002)]"))
	lines = tooltipLines(G)
	eq(lines[1], "Word to the Wise", "the client's title")
	assert(hasLine(lines, "Ends:|r Distant Elder"), "end line:\n" .. table.concat(lines, "\n"))
	assert(not hasLine(lines, "Distant Elder ("), "a guessed turn-in map")
	assert(not hasLine(lines, "Starts:"), "a giver nobody has named")
	assert(not hasLine(lines, "Level:"), "a level with none on the link or in DonData")
	sim:expectNoErrors(ADDON)
end)

scenario("DonData's display names match plain links but never reach the link text", function()
	local sim, G = boot({ questieDB = false, donData = true })
	serveQuests(sim, {}, { [507] = "Sergeant Bloodtusk" })
	eq(
		filtered(sim, "[Supplies for the Crossroads (4001)]"),
		"|cffffff00|Hquest:4001:-1|h[Supplies for the Crossroads]|h|r",
		"without the part number"
	)
	eq(filtered(sim, "[Barrens Patrol (4003)]"), "|cffffff00|Hquest:4003:-1|h[Barrens Patrol]|h|r", "one of two names")
	eq(filtered(sim, "[Supply Run (4001)]"), "[Supply Run (4001)]", "another name")
	click(G, filtered(sim, "[[15] Barrens Patrol (4003)]"))
	local lines = tooltipLines(G)
	eq(lines[1], "Barrens Patrol", "title from the link")
	expectLines(lines, {
		"Starts:|r Patrol Leader (The Barrens)",
		"Ends:|r Sergeant Bloodtusk (The Barrens)",
	})
	sim:expectNoErrors(ADDON)
end)

-- The expected names, levels and zone IDs below were read from QuestieDB 1.1.1's data directly (LibQuestieDB.Quest,
-- Npc, Object and Item), not through the addon.
scenario("the real QuestieDB: Raptor Mastery's level, starter and finisher with their zones", function()
	local sim, G = boot({ realQuestieDB = true })
	serveQuests(sim, { [194] = { title = "Raptor Mastery", text = "Kill 10 Stranglethorn Raptors." } })
	click(G, filtered(sim, "[[34] Raptor Mastery (194)]"))
	local lines = tooltipLines(G)
	eq(lines[1], "Raptor Mastery", "title")
	expectLines(lines, {
		"Level:|r 34 (requires 28)",
		"Starts:|r Hemet Nesingwary (Stranglethorn Vale)",
		"Ends:|r Hemet Nesingwary (Stranglethorn Vale)",
	})
	sim:expectNoErrors(ADDON)
end)

scenario("the real QuestieDB: a plain link converts by its name, at its level", function()
	local sim, G = boot({ realQuestieDB = true })
	serveQuests(sim, {})
	local link = filtered(sim, "[The Spirits of Stonetalon (1061)]")
	eq(link, "|cffffff00|Hquest:1061:17|h[The Spirits of Stonetalon]|h|r", "converted link")
	eq(filtered(sim, "[Nope (1061)]"), "[Nope (1061)]", "another name")
	eq(filtered(sim, "[Made Up (999999)]"), "[Made Up (999999)]", "a quest the database lacks")
	click(G, link)
	local lines = tooltipLines(G)
	eq(lines[1], "The Spirits of Stonetalon", "title")
	expectLines(lines, {
		"Level:|r 17 (requires 13)",
		"Starts:|r Zor Lonetree (Orgrimmar)",
		"Ends:|r Seereth Stonebreak (The Barrens)",
	})
	sim:expectNoErrors(ADDON)
end)

scenario("the real QuestieDB: quests started by an item and by an object", function()
	local sim, G = boot({ realQuestieDB = true })
	serveQuests(sim, {})
	click(G, filtered(sim, "[[30] Sharptalon's Claw (2)]"))
	expectLines(tooltipLines(G), {
		"Level:|r 30 (requires 20)",
		"Starts:|r Sharptalon's Claw (item)",
		"Ends:|r Senani Thunderheart (Ashenvale)",
	})
	click(G, filtered(sim, "[[28] The Legend of Stalvan (68)]"))
	expectLines(tooltipLines(G), {
		"Level:|r 28 (requires 22)",
		"Starts:|r Old Footlocker (Westfall)",
		"Ends:|r Clerk Daltry (Duskwood)",
	})
	sim:expectNoErrors(ADDON)
end)

scenario("the real QuestieDB: six starters end in a count", function()
	local sim, G = boot({ realQuestieDB = true })
	serveQuests(sim, {})
	click(G, filtered(sim, "[[10] Report to Gryan Stoutmantle (109)]"))
	expectLines(tooltipLines(G), {
		"Level:|r 10 (requires 9)",
		"Starts:|r Farmer Saldean (Westfall), Farmer Furlbrow (Westfall) and 4 more",
		"Ends:|r Gryan Stoutmantle (Westfall)",
	})
	sim:expectNoErrors(ADDON)
end)

-- The same quests from the other released databases, each on its own, with what each one knows.
scenario("the real Ding!: the same lines from its own database, zones from its map spawns", function()
	local sim, G = boot({ questieDB = false, realDing = true })
	serveQuests(sim, {})
	click(G, filtered(sim, "[[34] Raptor Mastery (194)]"))
	expectLines(tooltipLines(G), {
		"Level:|r 34 (requires 28)",
		"Starts:|r Hemet Nesingwary (Stranglethorn Vale)",
		"Ends:|r Hemet Nesingwary (Stranglethorn Vale)",
	})
	click(G, filtered(sim, "[The Spirits of Stonetalon (1061)]"))
	expectLines(tooltipLines(G), {
		"Level:|r 17 (requires 13)",
		"Starts:|r Zor Lonetree (Orgrimmar)",
		"Ends:|r Seereth Stonebreak (The Barrens)",
	})
	click(G, filtered(sim, "[[28] The Legend of Stalvan (68)]"))
	expectLines(tooltipLines(G), { "Starts:|r Old Footlocker (Westfall)", "Ends:|r Clerk Daltry (Duskwood)" })
	sim:expectNoErrors(ADDON)
end)

scenario("the real Polestar: the same lines once its quest database loads", function()
	local sim, G = boot({ questieDB = false, realPolestar = true })
	serveQuests(sim, {})
	click(G, filtered(sim, "[[30] Sharptalon's Claw (2)]"))
	expectLines(tooltipLines(G), {
		"Level:|r 30 (requires 20)",
		"Starts:|r Sharptalon's Claw (item)",
		"Ends:|r Senani Thunderheart (Ashenvale)",
	})
	click(G, filtered(sim, "[[10] Report to Gryan Stoutmantle (109)]"))
	expectLines(tooltipLines(G), {
		"Level:|r 10 (requires 9)",
		"Starts:|r Farmer Saldean (Westfall), Farmer Furlbrow (Westfall) and 4 more",
		"Ends:|r Gryan Stoutmantle (Westfall)",
	})
	sim:expectNoErrors(ADDON)
end)

scenario("the real DonData: the sender's name on the link, and its NPCs once the client knows them", function()
	local sim, G = boot({ questieDB = false, realDonData = true })
	serveQuests(sim, {}, { [715] = "Hemet Nesingwary", [267] = "Clerk Daltry" })
	eq(filtered(sim, "[[34] Raptor Mastery (194)]"), RAPTOR, "level form")
	-- DonData calls 194 "Raptor Hunting [CATA+] / Raptor Mastery (1/4)" and 68 "The Legend of Stalvan (3/13)".
	eq(filtered(sim, "[Raptor Mastery (194)]"), "|cffffff00|Hquest:194:-1|h[Raptor Mastery]|h|r", "plain form")
	eq(
		filtered(sim, "[The Legend of Stalvan (68)]"),
		"|cffffff00|Hquest:68:-1|h[The Legend of Stalvan]|h|r",
		"plain form of a chain's quest"
	)
	click(G, RAPTOR)
	local lines = tooltipLines(G)
	eq(lines[1], "Raptor Mastery", "title")
	expectLines(lines, {
		"Level:|r 34 (requires 28)",
		"Starts:|r Hemet Nesingwary (Stranglethorn Vale)",
		"Ends:|r Hemet Nesingwary (Stranglethorn Vale)",
	})
	click(G, filtered(sim, "[[28] The Legend of Stalvan (68)]"))
	lines = tooltipLines(G)
	expectLines(lines, { "Level:|r 28 (requires 22)", "Ends:|r Clerk Daltry (Duskwood)" })
	assert(not hasLine(lines, "Starts:"), "DonData has no starter for a quest an object starts")
	sim:expectNoErrors(ADDON)
end)

-- Blizzard's QuestDifficultyColors as colour codes.
local GREY, GREEN, YELLOW, ORANGE, RED = "ff808080", "ff40bf40", "ffffd100", "ffff8040", "ffff1a1a"

-- The quest log's verdict on each self-test quest for a level 36 character, by the same level rules as
-- GetQuestDifficultyColor with boot()'s trivial range of 8. The real client works this out itself.
local QUEST_LOG_AT_36 = { [194] = "Fair", [1061] = "Trivial", [2] = "Easy", [68] = "Easy", [109] = "Trivial" }

-- Boots with the self-test, runs /cqltest with questLog standing in for the client's quest log colours and known for
-- the quest data the server sends, and returns the run and its failed checks, one per line.
local function runSelfTest(opts, questLog, known)
	opts.selfTest, opts.saved, opts.level = true, {}, 36
	local sim, G = boot(opts)
	serveQuests(sim, known or {})
	-- Any other quest is one the client has never loaded, as the probe looks for: it exists once asked for, and the
	-- quest log only gives its verdict after that.
	local loaded = {}
	local request = sim.impl["C_QuestLog.RequestLoadQuestByID"]
	sim.impl["C_QuestLog.RequestLoadQuestByID"] = function(questID)
		loaded[questID] = not questLog[questID] or nil
		return request(questID)
	end
	sim.impl["C_QuestLog.GetTitleForQuestID"] = function(questID)
		return loaded[questID] and ("Quest " .. questID) or nil
	end
	sim.impl["C_PlayerInfo.GetContentDifficultyQuestForPlayer"] = function(questID)
		local verdict = questLog[questID] or (loaded[questID] and "Easy" or "Trivial")
		return G.Enum.RelativeContentDifficulty[verdict]
	end
	G.SlashCmdList.CQLSELFTEST("")
	sim:advance(2.5)
	local db = G.ClickableQuestLinks_SelfTestDB
	local run = db and db.runs and db.runs[1]
	assert(run, "no run recorded; printed:\n" .. table.concat(sim.printed, "\n"))
	local failed = {}
	for _, check in ipairs(run.checks) do
		if not check.ok then
			failed[#failed + 1] = check.name .. ": " .. tostring(check.detail)
		end
	end
	return sim, run, table.concat(failed, "\n")
end

scenario("the in-game self-test passes on the headless client with the real QuestieDB", function()
	local sim, run, failed = runSelfTest({ realQuestieDB = true }, QUEST_LOG_AT_36)
	eq(failed, "", "failed checks")
	eq(run.skipped, nil, "lines left unchecked")
	eq(run.colorSkipped, nil, "colours left unchecked")
	-- 5 conversions and the text left alone, 5 tooltips with 3 lines and a colour each, no errors.
	eq(run.total, 32, "checks run")
	eq(run.player.effectiveLevel, 36, "recorded player level")
	eq(run.colors["[[30] Sharptalon's Claw (2)]"].link, GREEN, "recorded link colour")
	eq(run.probe.tried, 25, "quests probed")
	assert(
		run.probe.loaded > 0 and run.probe.same == 0,
		"probe: " .. run.probe.loaded .. " loaded, " .. run.probe.same .. " same"
	)
	local quest = run.probe.quests[1]
	eq(quest.before .. " then " .. quest.after, "Trivial then Easy", "first probed quest's verdicts")
	sim:expectNoErrors(ADDON)
end)

scenario("the in-game self-test fails a link coloured unlike the quest log", function()
	-- No database: the four quests with a level in the text still convert, and their tooltips show the server's data.
	local questLog = setmetatable({ [2] = "Trivial" }, { __index = QUEST_LOG_AT_36 })
	local sim, run, failed = runSelfTest({ questieDB = false }, questLog, {
		[194] = { title = "Raptor Mastery", text = "Kill 10 Stranglethorn Raptors." },
		[2] = { title = "Sharptalon's Claw", text = "Bring Sharptalon's Claw to Senani Thunderheart." },
		[68] = { title = "The Legend of Stalvan", text = "Take the Dusty Unsent Letter to Clerk Daltry." },
		[109] = { title = "Report to Gryan Stoutmantle", text = "Talk to Gryan Stoutmantle." },
	})
	eq(
		failed,
		"[[30] Sharptalon's Claw (2)]: colour matches the quest log: link ff40bf40, quest log ff808080 (Trivial)",
		"failed checks"
	)
	eq(run.colors["[[34] Raptor Mastery (194)]"].difficulty, "Fair", "recorded quest log verdict")
	sim:expectNoErrors(ADDON)
end)

scenario("a native quest link from a player without Questie gets the same lines", function()
	local sim, G = boot()
	serveQuests(sim, { [194] = { title = "Raptor Mastery", text = "Kill 10 Stranglethorn Raptors." } })
	-- Shift-clicked from the sender's quest log, so it arrives as a link and the chat filter leaves it alone.
	eq(filtered(sim, "lfg " .. RAPTOR), "lfg " .. RAPTOR, "message")
	click(G, RAPTOR)
	local lines = tooltipLines(G)
	assert(hasLine(lines, "Starts:|r Hemet Nesingwary Jr."), "start line missing:\n" .. table.concat(lines, "\n"))
	sim:expectNoErrors(ADDON)
end)

scenario("tooltip labels follow the client's language", function()
	local sim, G = boot({ locale = "deDE" })
	serveQuests(sim, {})
	click(G, filtered(sim, "[[10] 100% Ready - Part (2) (9001)]"))
	local lines = tooltipLines(G)
	assert(hasLine(lines, "Stufe:|r 10"), "level label:\n" .. table.concat(lines, "\n"))
	assert(hasLine(lines, "Start:|r Wanted Poster"), "start label")
	assert(hasLine(lines, "Abgabe:|r First Finisher, Second Finisher und 1 weitere"), "end label and list")
	sim:expectNoErrors(ADDON)
end)

scenario("other quest tooltips are left alone", function()
	local sim, G = boot()
	serveQuests(sim, { [194] = { title = "Raptor Mastery", text = "Kill 10 Stranglethorn Raptors." } })
	G.GameTooltip:SetOwner(G.UIParent, "ANCHOR_NONE")
	G.GameTooltip:SetHyperlink("quest:194:34")
	eq(G.GameTooltip:NumLines(), 2, "GameTooltip lines")
	sim:expectNoErrors(ADDON)
end)

scenario("shift-click hands Blizzard's chat link code the native link", function()
	local sim, G = boot()
	-- The client's default CHATLINK binding is shift; the sim's IsModifiedClick never reports a modifier. The chat
	-- box itself cannot open in the sim (taint layer gap in ChatFrameUtil.OpenChat), so this checks what SetItemRef
	-- passes to HandleModifiedItemClick, which inserts it into the chat box in the client.
	rawset(G, "IsModifiedClick", function(action)
		return sim.modifiers.shift == true and (action == nil or action == "CHATLINK")
	end)
	local inserted
	rawset(G, "HandleModifiedItemClick", function(link)
		inserted = link
	end)
	local link = filtered(sim, "[[34] Raptor Mastery (194)]")
	sim.modifiers.shift = true
	click(G, link)
	sim.modifiers.shift = false
	eq(inserted, RAPTOR, "link handed to the chat box")
	sim:expectNoErrors(ADDON)
end)

scenario("clicking a data-less quest link again closes it, another quest switches", function()
	local sim, G = boot()
	serveQuests(sim, {})
	local defias = filtered(sim, "[The Defias Brotherhood (155)]")
	click(G, defias)
	assert(G.ItemRefTooltip:IsShown(), "first click should show it")
	click(G, filtered(sim, "[[34] Raptor Mastery (194)]"))
	assert(G.ItemRefTooltip:IsShown(), "another quest should show")
	eq(tooltipLines(G)[1], "Raptor Mastery", "title after switching")
	click(G, filtered(sim, "[[34] Raptor Mastery (194)]"))
	assert(not G.ItemRefTooltip:IsShown(), "same quest again should close it")
	click(G, defias)
	assert(G.ItemRefTooltip:IsShown(), "a later click should open it again")
	sim:expectNoErrors(ADDON)
end)

scenario("closing the tooltip, then clicking the same quest, opens it", function()
	local sim, G = boot()
	serveQuests(sim, {})
	local defias = filtered(sim, "[The Defias Brotherhood (155)]")
	click(G, defias)
	G.ItemRefTooltip:Hide()
	sim:advance(0.1)
	click(G, defias)
	assert(G.ItemRefTooltip:IsShown(), "should open again after being closed")
	sim:expectNoErrors(ADDON)
end)

local function raptorIn(color)
	return "|c" .. color .. "|Hquest:194:34|h[Raptor Mastery]|h|r"
end

scenario("by default a converted link takes the quest's difficulty colour for the player", function()
	for _, case in ipairs({ { 60, GREY }, { 40, GREEN }, { 34, YELLOW }, { 31, ORANGE }, { 29, RED } }) do
		local sim = boot({ saved = {}, level = case[1] })
		eq(filtered(sim, "[[34] Raptor Mastery (194)]"), raptorIn(case[2]), "player level " .. case[1])
		sim:expectNoErrors(ADDON)
	end
end)

scenario("a link takes the quest log's colour once the client has the quest, the level rule before", function()
	local SHARPTALON = "[[30] Sharptalon's Claw (2)]"
	for _, case in ipairs({ { true, GREEN }, { false, GREY } }) do
		local loaded, color = case[1], case[2]
		local sim, G = boot({ saved = {}, level = 36 })
		-- Forever's client at level 36: the level rule's green band ends 5 below (UnitQuestTrivialLevelRange), while
		-- its quest log called a level 30 quest Easy (in-game self-test, 2026-11-15).
		rawset(G, "UnitQuestTrivialLevelRange", function()
			return 5
		end)
		sim.impl["C_QuestLog.GetTitleForQuestID"] = function(questID)
			return loaded and questID == 2 and "Sharptalon's Claw" or nil
		end
		sim.impl["C_PlayerInfo.GetContentDifficultyQuestForPlayer"] = function()
			return G.Enum.RelativeContentDifficulty.Easy
		end
		eq(
			filtered(sim, SHARPTALON),
			"|c" .. color .. "|Hquest:2:30|h[Sharptalon's Claw]|h|r",
			"loaded " .. tostring(loaded)
		)
		sim:expectNoErrors(ADDON)
	end
end)

scenario("a quest with no known level stays yellow with colours on", function()
	local sim = boot({ saved = {}, level = 60 })
	eq(filtered(sim, "[Levelless Quest (9003)]"), "|cffffff00|Hquest:9003:-1|h[Levelless Quest]|h|r")
	sim:expectNoErrors(ADDON)
end)

scenario("the colour option is on the settings page, applies to new links, and /cql opens the page", function()
	local sim, G = boot({ saved = {}, level = 60 })
	local opened
	sim.impl["C_SettingsUtil.OpenSettingsPanel"] = function(categoryID)
		opened = categoryID
	end
	local setting = G.Settings.GetSetting("ClickableQuestLinks_colorByDifficulty")
	assert(setting, "setting not registered")
	eq(setting:GetValue(), true, "on by default")
	eq(filtered(sim, "[[34] Raptor Mastery (194)]"), raptorIn(GREY), "coloured while on")
	sim.run(function()
		setting:SetValue(false)
	end)
	eq(sim:savedState().ClickableQuestLinksDB.colorByDifficulty, false, "saved")
	eq(filtered(sim, "[[34] Raptor Mastery (194)]"), RAPTOR, "yellow once off")
	sim:slash("/cql")
	assert(opened, "settings panel not opened")
	local category = G.Settings.GetCategory(opened)
	eq(category and category:GetName(), "Clickable Quest Links", "settings page")
	sim:expectNoErrors(ADDON)
end)

-- An open chat box for shift-clicks to insert into. Blizzard's own cannot open in the sim (taint layer gap in
-- ChatFrameUtil.OpenChat), and the sim's IsModifiedClick never reports a modifier.
local function chatBox(sim)
	local G = sim.G
	local box = G.CreateFrame("EditBox")
	rawset(G.ChatFrameUtil, "GetActiveWindow", function()
		return box
	end)
	rawset(G, "IsModifiedClick", function(action)
		return sim.modifiers.shift == true and (action == nil or action == "CHATLINK")
	end)
	return box
end

-- A shift-click as a chat frame makes it. `bare` hands SetItemRef the link text without its colour code, which
-- Blizzard's GetFixedLink then colours plain yellow; which form the client passes is not visible from its Lua.
local function shiftClick(sim, link, bare)
	local G = sim.G
	sim.modifiers.shift = true
	G.SetItemRef(link:match("|H(.-)|h"), bare and link:match("|H.-|h.-|h") or link, "LeftButton", G.ChatFrame1)
	sim.modifiers.shift = false
end

scenario("the swap holds when Blizzard hands back a coloured link in plain yellow", function()
	for _, bare in ipairs({ false, true }) do
		local sim = boot({ saved = {}, level = 60 })
		local box = chatBox(sim)
		local link = filtered(sim, "[[34] Raptor Mastery (194)]")
		eq(link, raptorIn(GREY), "converted link")
		shiftClick(sim, link, bare)
		eq(box:GetText(), "[[34] Raptor Mastery (194)]", bare and "bare link text" or "coloured link text")
		sim:expectNoErrors(ADDON)
	end
end)

scenario("shift-clicking a converted link for a quest not in the log inserts Questie's text", function()
	local sim = boot()
	local box = chatBox(sim)
	box:SetText("anyone for ")
	shiftClick(sim, filtered(sim, "[[34] Raptor Mastery (194)]"))
	eq(box:GetText(), "anyone for [[34] Raptor Mastery (194)]", "chat box")
	sim:expectNoErrors(ADDON)
end)

scenario("shift-clicking a converted link for a quest in the log inserts the client's own link", function()
	local sim = boot()
	local box = chatBox(sim)
	local own = raptorIn(GREY)
	sim.impl["C_QuestLog.GetLogIndexForQuestID"] = function(questID)
		return questID == 194 and 3 or nil
	end
	rawset(sim.G, "GetQuestLink", function(questID)
		return questID == 194 and own or nil
	end)
	shiftClick(sim, filtered(sim, "[[34] Raptor Mastery (194)]"))
	eq(box:GetText(), own, "chat box")
	sim:expectNoErrors(ADDON)
end)

-- The one quest link in WIM's saved whisper history on 2026-11-14: converted in an earlier session, and shown again
-- by WIM without running chat filters, so nothing in this session made it.
scenario("a converted link WIM shows from its history goes in as Questie's text", function()
	local sim = boot()
	local box = chatBox(sim)
	for _, bare in ipairs({ false, true }) do
		box:SetText("")
		shiftClick(sim, "|cffffff00|Hquest:1061:17|h[The Spirits of Stonetalon]|h|r", bare)
		eq(box:GetText(), "[[17] The Spirits of Stonetalon (1061)]", bare and "bare link text" or "coloured link text")
	end
	sim:expectNoErrors(ADDON)
end)

scenario("another player's quest link goes in as Questie's text when the quest is not in the log", function()
	local sim = boot()
	local box = chatBox(sim)
	shiftClick(sim, "|cff808080|Hquest:155:18:0:0:0|h[The Defias Brotherhood]|h|r")
	eq(box:GetText(), "[[18] The Defias Brotherhood (155)]", "chat box")
	sim:expectNoErrors(ADDON)
end)

scenario("the quest log's own link for a quest in the log goes in unchanged", function()
	local sim, G = boot()
	local box = chatBox(sim)
	local own = raptorIn(GREY)
	sim.impl["C_QuestLog.GetLogIndexForQuestID"] = function(questID)
		return questID == 194 and 3 or nil
	end
	rawset(G, "GetQuestLink", function(questID)
		return questID == 194 and own or nil
	end)
	-- What Blizzard's quest log and tracker do on a shift-click (ChatFrameUtil.TryInsertQuestLinkForQuestID).
	G.ChatFrameUtil.InsertLink(G.GetQuestLink(194))
	eq(box:GetText(), own, "chat box")
	sim:expectNoErrors(ADDON)
end)

scenario("a quest with no level on its link goes in as Questie's text without one", function()
	local sim = boot()
	local box = chatBox(sim)
	shiftClick(sim, "|cffffff00|Hquest:53370:-1:110:120:3|h[Hour of Reckoning]|h|r")
	eq(box:GetText(), "[Hour of Reckoning (53370)]", "chat box")
	sim:expectNoErrors(ADDON)
end)

local only = arg[1]
local passed, failed = 0, 0
for _, s in ipairs(scenarios) do
	if not only or s.name:find(only, 1, true) then
		local ok, err = pcall(s.fn)
		if ok then
			passed = passed + 1
			print("ok    " .. s.name)
		else
			failed = failed + 1
			print("FAIL  " .. s.name .. "\n      " .. tostring(err):gsub("\n", "\n      "))
		end
	end
end
print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
