-- Scenario tests for Clickable Quest Links on SkillUp Forever's headless Forever client (forever_sim): Blizzard's
-- real chat filter registry (ChatFrameUtil), SetItemRef and ItemRefTooltip, with a fake QuestieDB
-- (fixtures/QuestieDB). Run with tests/run.sh, which sets FOREVER_SIM and QUESTLINKS_SIM_CACHE.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local SIM = assert(os.getenv("FOREVER_SIM"), "FOREVER_SIM is not set: run tests/run.sh")
local CACHE = assert(os.getenv("QUESTLINKS_SIM_CACHE"), "QUESTLINKS_SIM_CACHE is not set: run tests/run.sh")
local ADDON = "ClickableQuestLinks"
-- The repository root holds the addon's TOC; QUESTLINKS_ADDON_DIR runs the scenarios against another copy, such as
-- the installed one.
local ADDON_DIR = os.getenv("QUESTLINKS_ADDON_DIR") or (here .. "..")
local FAKE_DB_DIR = here .. "fixtures/QuestieDB"

local Sim = dofile(SIM .. "sim.lua")

local RAPTOR = "|cffffff00|Hquest:194:34|h[Raptor Mastery]|h|r"

-- A client with chat and ItemRef loaded before the addons, as the real client has them.
-- opts.questieDB (default true), opts.questie (Questie stand-in), opts.contract (fake QuestieDB contract),
-- opts.addon (default true; false boots Blizzard's behaviour alone, for comparison), opts.locale (the client language
-- the addon loads under), opts.saved (saved variables; by default difficulty colours are off, so converted links are
-- plain yellow), opts.level (the player's level; the sim's is 60).
local function boot(opts)
	opts = opts or {}
	local sim = Sim.new({ cache = CACHE })
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
	if opts.questieDB ~= false then
		sim:addon(FAKE_DB_DIR)
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

-- Quest tooltip data for the quests the client has; others get nil, as for a quest the client never loaded.
local function serveQuests(sim, known)
	local G = sim.G
	sim.impl["C_TooltipInfo.GetHyperlink"] = function(link)
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

scenario("unknown quest IDs are left alone", function()
	local sim = boot()
	for _, msg in ipairs({ "[[10] Nope (99999)]", "[Nope (99999)]", "[[1] Huge (99999999999)]" }) do
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

-- Blizzard's QuestDifficultyColors as colour codes.
local GREY, GREEN, YELLOW, ORANGE, RED = "ff808080", "ff40bf40", "ffffd100", "ffff8040", "ffff1a1a"

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
