-- In-game self-test for Clickable Quest Links, for development only: tests/ is not packaged. Installed next to the
-- addon (README, "In game"), /cqltest sends the quests the headless "real" scenarios use through this client's own
-- chat filters and ItemRefTooltip, prints a summary and keeps the run in ClickableQuestLinks_SelfTestDB, which the
-- client writes to disk at /reload or logout. What only the real client has gets checked here: its zone names, its
-- quest data, Blizzard's tooltip as it really runs, and the colour its quest log gives each quest.
-- tests/questlinks_test.lua runs this file on the headless client too.

-- What an English client shows when QuestieDB, Ding! or Polestar answers (the headless scenarios expect the same).
-- Links are matched without their colour, which follows the player's level and is checked against the quest log's.
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
-- What the addon gives a link when "Color links by difficulty" is off.
local UNCOLORED = "ffffff00"

local running = false

local function Readable(value)
	if canaccessvalue and not canaccessvalue(value) then
		return "<secret>"
	end
	return value
end

-- Forever's quest log colours a quest by C_PlayerInfo.GetContentDifficultyQuestForPlayer, which the client works out
-- itself, while links take GetQuestDifficultyColor(level): only a real client can say whether the two agree.
local function QuestLogDifficulty(questID)
	if questID and C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer and GetDifficultyColor then
		return C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)
	end
end

local function DifficultyName(difficulty)
	for name, value in pairs(Enum.RelativeContentDifficulty or {}) do
		if value == difficulty then
			return name
		end
	end
	return tostring(difficulty)
end

local function ColorCode(color)
	return ("ff%02x%02x%02x"):format(
		math.floor(color.r * 255 + 0.5),
		math.floor(color.g * 255 + 0.5),
		math.floor(color.b * 255 + 0.5)
	)
end

local function ClientTitle(questID)
	local title = C_QuestLog.GetTitleForQuestID(questID)
	return type(title) == "string" and title ~= "" and title or nil
end

-- Whether the quest log's verdict needs the client's data for the quest decides whether links could use it before
-- that data arrives. Only quests the client has never loaded tell, and it keeps quest data on disk
-- (Cache/WDB/<locale>/questcache.wdb), so each run walks quest IDs from a random start (most IDs below 10000 are
-- quests) for ones it has no title for, which loading them then uses up.
local PROBE_SIZE = 25
local PROBE_RANGE = 10000
local PROBE_STRIDE = 97 -- shares no factor with PROBE_RANGE, so the walk can reach every ID

local function StartProbe()
	local probe = {}
	local id = math.random(1, PROBE_RANGE)
	for _ = 1, PROBE_RANGE do
		if #probe == PROBE_SIZE then
			break
		end
		id = (id + PROBE_STRIDE - 1) % PROBE_RANGE + 1
		if not ClientTitle(id) then
			probe[#probe + 1] =
				{ id = id, before = QuestLogDifficulty(id), levelBefore = C_QuestLog.GetQuestDifficultyLevel(id) }
			C_QuestLog.RequestLoadQuestByID(id)
		end
	end
	return probe
end

-- The probed IDs that turned out to be quests, with the verdict before and after their data loaded.
local function FinishProbe(probe)
	local result = { tried = #probe, loaded = 0, same = 0, quests = {} }
	for _, quest in ipairs(probe) do
		if ClientTitle(quest.id) then
			local after = QuestLogDifficulty(quest.id)
			result.loaded = result.loaded + 1
			result.same = result.same + (after == quest.before and 1 or 0)
			result.quests[#result.quests + 1] = {
				id = quest.id,
				level = C_QuestLog.GetQuestDifficultyLevel(quest.id),
				levelBefore = quest.levelBefore,
				before = DifficultyName(quest.before),
				after = DifficultyName(after),
			}
		end
	end
	return result
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
		("|cff3fa9f5Clickable Quest Links self-test:|r %d of %d checks passed (%s; answering: %s; %s). /reload writes the results to disk."):format(
			passed,
			run.total,
			#databases > 0 and table.concat(databases, ", ") or "no quest database",
			run.answering or "none",
			run.locale
		)
	)
	if run.skipped then
		print("  Lines not checked: " .. run.skipped .. ".")
	end
	if run.colorSkipped then
		print("  Colours not checked: " .. run.colorSkipped .. ".")
	end
	if run.probe then
		print(
			("  Quest log verdict on %d quests the client had never loaded: the same before their data for %d."):format(
				run.probe.loaded,
				run.probe.same
			)
		)
	end
	for _, check in ipairs(run.checks) do
		if not check.ok then
			print(("  |cffff4040FAIL|r %s: got %s"):format(check.name, tostring(check.detail)))
		end
	end
end

local function Run(onDone, round)
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
		-- What the link colours depend on.
		player = {
			level = UnitLevel("player"),
			effectiveLevel = UnitEffectiveLevel("player"),
			trivialRange = UnitQuestTrivialLevelRange and UnitQuestTrivialLevelRange("player"),
			questLogColors = C_CVar.GetCVarBool("showQuestDifficultyColor"),
		},
		databases = {},
		checks = {},
		links = {},
		tooltips = {},
		colors = {},
		errors = {},
	}
	for _, name in ipairs(DATABASES) do
		if C_AddOns.IsAddOnLoaded(name) then
			run.databases[name] = C_AddOns.GetAddOnMetadata(name, "Version") or "?"
		end
	end
	run.polestarData = C_AddOns.IsAddOnLoaded("Polestar_QuestDB") or nil
	for _, name in ipairs(DATABASES) do
		-- Polestar's quest data is the load-on-demand Polestar_QuestDB, which Polestar loads for its quest features.
		if run.databases[name] and (name ~= "Polestar" or run.polestarData) then
			run.answering = run.answering or name
		end
	end
	if run.locale ~= "enUS" then
		run.skipped = "the expected lines are the English client's"
	elseif not run.answering then
		run.skipped = run.databases.Polestar and "Polestar's quest data (Polestar_QuestDB) is not loaded"
			or "no quest database is loaded"
	elseif not WITH_THESE_LINES[run.answering] then
		run.skipped = run.answering
			.. " answers: Starts and Ends not checked (their names come from what the client or DonData has learned)"
	end
	-- Links are checked exactly whenever an English client has a database answering; DonData only gets the Level lines.
	local exact = run.locale == "enUS" and run.answering ~= nil
	local allLines = exact and WITH_THESE_LINES[run.answering]

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
		if round then
			run.round = round
			check("only " .. round .. " answers in its round", run.answering == round, run.answering)
		end
		Report(run)
		running = false
		if onDone then
			onDone(run)
		end
	end

	for i, case in ipairs(CASES) do
		local text = Convert(case.message, 900000 + i)
		run.links[case.message] = text
		case.text = text
		case.questID = type(text) == "string" and tonumber(text:match("|Hquest:(%d+):")) or nil
		if not case.link then
			check(case.message .. " stays text", text == case.message, text)
		elseif exact or not case.plain then
			local converted = type(text) == "string" and text:find(exact and case.link or "|Hquest:", 1, true) ~= nil
			check(case.message .. " converts", converted, text)
		end
	end

	local probe = StartProbe()

	C_Timer.After(DATA_WAIT, function()
		local ok, err = pcall(function()
			run.probe = FinishProbe(probe)
			for _, case in ipairs(CASES) do
				if case.link and type(case.text) == "string" and case.text:find("|Hquest:", 1, true) then
					local shown, lines = OpenTooltip(case.text)
					run.tooltips[case.message] = lines
					check(case.message .. ": tooltip opens", shown, #lines .. " lines")
					for _, want in ipairs(exact and case.lines or {}) do
						if allLines or want:find("^Level:") then
							check(case.message .. ": " .. want, HasLine(lines, want), table.concat(lines, " / "))
						end
					end
					local linkColor = case.text:match("^|c(%x%x%x%x%x%x%x%x)|H")
					local difficulty = QuestLogDifficulty(case.questID)
					if difficulty == nil then
						run.colorSkipped = "this client has no C_PlayerInfo.GetContentDifficultyQuestForPlayer"
					elseif linkColor == UNCOLORED then
						run.colorSkipped = "links are plain yellow, so Color links by difficulty is off"
					else
						local questLog = ColorCode(GetDifficultyColor(difficulty))
						run.colors[case.message] = {
							link = linkColor,
							questLog = questLog,
							difficulty = DifficultyName(difficulty),
						}
						check(
							case.message .. ": colour matches the quest log",
							linkColor == questLog,
							("link %s, quest log %s (%s)"):format(
								tostring(linkColor),
								questLog,
								DifficultyName(difficulty)
							)
						)
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

-- Rounds: one run per database with only that one enabled, because the addon asks QuestieDB first and the others
-- answer only without it. A round sets the databases' enable states for this character, reloads, and runs once the
-- character is back in the world; after the last, the states go back as they were. Between reloads the plan lives in
-- ClickableQuestLinks_SelfTestDB.rounds, so a queue written there while the game is closed
-- (rounds = { queue = { "Ding", "DonData" } }) starts at the next login.
local DATABASE_ADDONS = { "QuestieDB", "Ding", "Polestar", "Polestar_QuestDB", "DonData" }
local ROUND_ADDONS = {
	QuestieDB = { QuestieDB = true },
	Ding = { Ding = true },
	Polestar = { Polestar = true, Polestar_QuestDB = true },
	DonData = { DonData = true },
}
local SETTLE = 5 -- seconds after login before a round runs, for the other addons to finish setting up
local POLESTAR_WAIT = 30 -- longest wait for Polestar to load its quest data after login

local function Say(message)
	print("|cff3fa9f5Clickable Quest Links self-test:|r " .. message)
end

-- As Blizzard's AddOns list does in game: the character is the player's GUID, and the changes last past a reload
-- only once saved.
local function SetDatabaseAddOns(character, enabled)
	for _, name in ipairs(DATABASE_ADDONS) do
		if C_AddOns.DoesAddOnExist(name) then
			if enabled[name] then
				C_AddOns.EnableAddOn(name, character)
			else
				C_AddOns.DisableAddOn(name, character)
			end
		end
	end
	C_AddOns.SaveAddOns()
end

-- The client reloads the UI for an addon only from a key press or a click, not from a timer (2026-11-15: every round
-- waited for a typed /reload). So the slash commands reload at once, and a round, which ends on a timer, offers a
-- button.
local function Reload(message, now)
	if now then
		Say(message)
		ReloadUI()
		return
	end
	Say(message .. " Click Reload UI, or type /reload.")
	if StaticPopupDialogs and StaticPopup_Show then
		StaticPopupDialogs.CQL_SELFTEST_RELOAD = StaticPopupDialogs.CQL_SELFTEST_RELOAD
			or {
				text = "Clickable Quest Links self-test:\n%s",
				button1 = RELOADUI or "Reload UI",
				button2 = CANCEL or "Cancel",
				OnAccept = function()
					ReloadUI()
				end,
				timeout = 0,
				whileDead = 1,
				hideOnEscape = 1,
			}
		StaticPopup_Show("CQL_SELFTEST_RELOAD", message)
	end
end

local function StartRounds(queue, now)
	if not queue[1] then
		Say("no quest database is installed.")
		return
	end
	local rounds = { queue = queue, character = UnitGUID("player"), restore = {} }
	for _, name in ipairs(DATABASE_ADDONS) do
		if C_AddOns.DoesAddOnExist(name) then
			rounds.restore[name] = C_AddOns.GetAddOnEnableState(name, rounds.character) > 0
		end
	end
	ClickableQuestLinks_SelfTestDB = ClickableQuestLinks_SelfTestDB or {}
	ClickableQuestLinks_SelfTestDB.rounds = rounds
	SetDatabaseAddOns(rounds.character, ROUND_ADDONS[queue[1]] or {})
	Reload(("%d rounds, first %s alone."):format(#queue, queue[1]), now)
end

local function ContinueRounds(rounds)
	local database = rounds.queue[1]
	local waited = 0
	local function go()
		if database == "Polestar" and not C_AddOns.IsAddOnLoaded("Polestar_QuestDB") and waited < POLESTAR_WAIT then
			waited = waited + 1
			C_Timer.After(1, go)
			return
		end
		Run(function()
			table.remove(rounds.queue, 1)
			if rounds.queue[1] then
				SetDatabaseAddOns(rounds.character, ROUND_ADDONS[rounds.queue[1]] or {})
				Reload(("next, %s alone."):format(rounds.queue[1]))
			else
				SetDatabaseAddOns(rounds.character, rounds.restore)
				ClickableQuestLinks_SelfTestDB.rounds = nil
				Reload("rounds done, the AddOns list is back as it was.")
			end
		end, database)
	end
	go()
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	local rounds = ClickableQuestLinks_SelfTestDB and ClickableQuestLinks_SelfTestDB.rounds
	if type(rounds) ~= "table" or type(rounds.queue) ~= "table" or not rounds.queue[1] then
		return
	end
	C_Timer.After(SETTLE, function()
		if rounds.restore then
			ContinueRounds(rounds)
		else
			StartRounds(rounds.queue)
		end
	end)
end)

SLASH_CQLSELFTEST1 = "/cqltest"
SlashCmdList.CQLSELFTEST = function(message)
	message = (message or ""):match("^%s*(.-)%s*$"):lower()
	if message == "rounds" then
		local queue = {}
		for _, database in ipairs(DATABASES) do
			if C_AddOns.DoesAddOnExist(database) then
				queue[#queue + 1] = database
			end
		end
		StartRounds(queue, true)
	elseif message == "stop" then
		local rounds = ClickableQuestLinks_SelfTestDB and ClickableQuestLinks_SelfTestDB.rounds
		if type(rounds) == "table" and rounds.restore then
			SetDatabaseAddOns(rounds.character, rounds.restore)
		end
		if ClickableQuestLinks_SelfTestDB then
			ClickableQuestLinks_SelfTestDB.rounds = nil
		end
		Reload("rounds stopped, the AddOns list is back as it was.", true)
	else
		Run()
	end
end
