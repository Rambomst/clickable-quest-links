-- In-game self-test for Clickable Quest Links, for development only: tests/ is not packaged, and
-- ~/scripts/~scratch/wow-forever-quest-links/install.sh installs this next to the dev copy. /cqltest sends the quests
-- the headless "real" scenarios use through this client's own chat filters and ItemRefTooltip, prints a summary and
-- keeps the run in ClickableQuestLinks_SelfTestDB, which the client writes to disk at /reload or logout. What only
-- the real client has gets checked here: its zone names, its quest data, Blizzard's tooltip as it really runs.
-- tests/questlinks_test.lua runs this file on the headless client too.

-- What an English client shows when QuestieDB, Ding! or Polestar answers (the headless scenarios expect the same).
-- Links are matched without their colour, which follows the player's level.
local CASES = {
	{
		message = "[[34] Raptor Mastery (194)]",
		link = "|Hquest:194:34|h[Raptor Mastery]|h",
		lines = {
			"Level:|r 34 (requires 28)",
			"Starts:|r Hemet Nesingwary (Stranglethorn Vale)",
			"Ends:|r Hemet Nesingwary (Stranglethorn Vale)",
		},
	},
	{
		message = "[The Spirits of Stonetalon (1061)]",
		plain = true,
		link = "|Hquest:1061:17|h[The Spirits of Stonetalon]|h",
		lines = {
			"Level:|r 17 (requires 13)",
			"Starts:|r Zor Lonetree (Orgrimmar)",
			"Ends:|r Seereth Stonebreak (The Barrens)",
		},
	},
	{
		message = "[[30] Sharptalon's Claw (2)]",
		link = "|Hquest:2:30|h[Sharptalon's Claw]|h",
		lines = {
			"Level:|r 30 (requires 20)",
			"Starts:|r Sharptalon's Claw (item)",
			"Ends:|r Senani Thunderheart (Ashenvale)",
		},
	},
	{
		message = "[[28] The Legend of Stalvan (68)]",
		link = "|Hquest:68:28|h[The Legend of Stalvan]|h",
		lines = {
			"Level:|r 28 (requires 22)",
			"Starts:|r Old Footlocker (Westfall)",
			"Ends:|r Clerk Daltry (Duskwood)",
		},
	},
	{
		message = "[[10] Report to Gryan Stoutmantle (109)]",
		link = "|Hquest:109:10|h[Report to Gryan Stoutmantle]|h",
		lines = {
			"Level:|r 10 (requires 9)",
			"Starts:|r Farmer Saldean (Westfall), Farmer Furlbrow (Westfall) and 4 more",
			"Ends:|r Gryan Stoutmantle (Westfall)",
		},
	},
	-- Another quest's name: stays text.
	{ message = "[Nope (194)]" },
}

-- In the order Clickable Quest Links asks them; the first loaded one answers.
local DATABASES = { "QuestieDB", "Ding", "Polestar", "DonData" }
local WITH_THESE_LINES = { QuestieDB = true, Ding = true, Polestar = true }
local KEEP_RUNS = 5
-- Long enough for the quest data the conversions asked the server for (C_QuestLog.RequestLoadQuestByID) to arrive.
local DATA_WAIT = 2

local running = false

local function Readable(value)
	if canaccessvalue and not canaccessvalue(value) then
		return "<secret>"
	end
	return value
end

-- A SAY line, as the chat frame would filter it: CHAT_MSG_SAY because whisper addons such as WIM act on whispers.
local function Convert(message, lineID)
	local discard, text = ChatFrameUtil.ProcessMessageEventFilters(
		ChatFrame1,
		"CHAT_MSG_SAY",
		message,
		"Selftest",
		"",
		"",
		"Selftest",
		"",
		0,
		0,
		"",
		0,
		lineID,
		"",
		0,
		false,
		false,
		false
	)
	return not discard and Readable(text) or nil
end

local function OpenTooltip(link)
	ItemRefTooltip:Hide()
	SetItemRef(link:match("|H(.-)|h"), link, "LeftButton", ChatFrame1)
	local lines = {}
	for i = 1, ItemRefTooltip:IsShown() and ItemRefTooltip:NumLines() or 0 do
		local line = _G["ItemRefTooltipTextLeft" .. i]
		lines[i] = line and Readable(line:GetText()) or ""
	end
	return ItemRefTooltip:IsShown(), lines
end

local function HasLine(lines, text)
	for _, line in ipairs(lines) do
		if type(line) == "string" and line:find(text, 1, true) then
			return true
		end
	end
	return false
end

local function Report(run)
	local passed = 0
	for _, check in ipairs(run.checks) do
		if check.ok then
			passed = passed + 1
		end
	end
	run.passed, run.total = passed, #run.checks
	ClickableQuestLinks_SelfTestDB = ClickableQuestLinks_SelfTestDB or {}
	local db = ClickableQuestLinks_SelfTestDB
	db.runs = db.runs or {}
	table.insert(db.runs, 1, run)
	while #db.runs > KEEP_RUNS do
		table.remove(db.runs)
	end
	local databases = {}
	for _, name in ipairs(DATABASES) do
		if run.databases[name] then
			databases[#databases + 1] = name .. " " .. run.databases[name]
		end
	end
	print(
		("|cff3fa9f5Clickable Quest Links self-test:|r %d of %d checks passed (%s, %s). /reload writes the results to disk."):format(
			passed,
			run.total,
			#databases > 0 and table.concat(databases, ", ") or "no quest database",
			run.locale
		)
	)
	if run.skipped then
		print("  Lines not checked: " .. run.skipped .. ".")
	end
	for _, check in ipairs(run.checks) do
		if not check.ok then
			print(("  |cffff4040FAIL|r %s: got %s"):format(check.name, tostring(check.detail)))
		end
	end
end

local function Run()
	if running then
		print("Clickable Quest Links self-test: already running.")
		return
	end
	running = true
	local build, buildNumber = GetBuildInfo()
	local run = {
		at = date("%Y-%m-%d %H:%M:%S"),
		addon = C_AddOns.GetAddOnMetadata("ClickableQuestLinks", "Version"),
		build = build .. "." .. buildNumber,
		locale = GetLocale(),
		databases = {},
		checks = {},
		links = {},
		tooltips = {},
		errors = {},
	}
	for _, name in ipairs(DATABASES) do
		if C_AddOns.IsAddOnLoaded(name) then
			run.databases[name] = C_AddOns.GetAddOnMetadata(name, "Version") or "?"
		end
	end
	run.polestarData = C_AddOns.IsAddOnLoaded("Polestar_QuestDB") or nil
	local answering
	for _, name in ipairs(DATABASES) do
		answering = answering or (run.databases[name] and name)
	end
	if run.locale ~= "enUS" then
		run.skipped = "the expected lines are the English client's"
	elseif not answering then
		run.skipped = "no quest database is loaded"
	elseif not WITH_THESE_LINES[answering] then
		run.skipped = answering .. " answers, with other lines (no quest levels, NPC names once the client knows them)"
	end
	local exact = not run.skipped

	-- Errors from any addon during the run, passed on to whatever handler was there (BugGrabber, the default).
	local previous = geterrorhandler()
	seterrorhandler(function(message, ...)
		run.errors[#run.errors + 1] = tostring(message)
		return previous(message, ...)
	end)
	local function check(name, ok, detail)
		run.checks[#run.checks + 1] = { name = name, ok = ok and true or false, detail = detail }
	end

	local function finish()
		ItemRefTooltip:Hide()
		seterrorhandler(previous)
		check("no Lua errors during the run", #run.errors == 0, run.errors[1])
		Report(run)
		running = false
	end

	for i, case in ipairs(CASES) do
		local text = Convert(case.message, 900000 + i)
		run.links[case.message] = text
		case.text = text
		if not case.link then
			check(case.message .. " stays text", text == case.message, text)
		elseif exact or not case.plain then
			local converted = type(text) == "string" and text:find(exact and case.link or "|Hquest:", 1, true) ~= nil
			check(case.message .. " converts", converted, text)
		end
	end

	C_Timer.After(DATA_WAIT, function()
		local ok, err = pcall(function()
			for _, case in ipairs(CASES) do
				if case.link and type(case.text) == "string" and case.text:find("|Hquest:", 1, true) then
					local shown, lines = OpenTooltip(case.text)
					run.tooltips[case.message] = lines
					check(case.message .. ": tooltip opens", shown, #lines .. " lines")
					for _, want in ipairs(exact and case.lines or {}) do
						check(case.message .. ": " .. want, HasLine(lines, want), table.concat(lines, " / "))
					end
				end
			end
		end)
		if not ok then
			check("the self-test itself ran", false, err)
		end
		finish()
	end)
end

SLASH_CQLSELFTEST1 = "/cqltest"
SlashCmdList.CQLSELFTEST = Run
