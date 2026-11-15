-- Clickable Quest Links: Questie's plain-text quest links made clickable without Questie (WoW: Forever).
--
-- The chat server drops addon hyperlinks, so Questie sends a quest as text: "[[34] Raptor Mastery (194)]", or
-- "[Raptor Mastery (194)]" when the sender hides quest levels. Only a receiving Questie turns that back into a link
-- (its Modules/QuestLinks/ChatFilter.lua). This rewrites the text into the client's own kind of quest link,
-- quest:ID:LEVEL, so a click opens Blizzard's quest tooltip.
--
-- Sent on as it is, such a link arrives as plain text (seen in game 2026-11-14; the server may reject a link whose
-- colour, payload and text it does not expect). Questie never sends one it built: only the client's own
-- GetQuestLink or its text. So any quest link put in a chat box becomes the client's own link when the quest is in
-- the quest log, and Questie's text otherwise, which Questie and this addon turn back into links.
--
-- A quest database, when one is loaded, adds the quest's level and where it starts and ends to the tooltip of every
-- quest link opened from chat, native ones included: QuestieDB, Ding!'s DingDB, Polestar's or DonData's, the first
-- that knows the quest. The "[[level] Name (id)]" form always converts. "[Name (id)]" also turns up in normal chat, so
-- it converts only when a database or the client knows the quest by that name.
--
-- With Questie loaded this stays out of the way: Questie handles the same text with its own tooltip.

local QUEST_LINK = "|c%s|Hquest:%d:%d|h[%s]|h|r"
local YELLOW = "ffffff00" -- the colour the client gives a quest link that has none (GetFixedLink)
local QUESTIE_TEXT = "[[%d] %s (%d)]"
local QUESTIE_TEXT_NO_LEVEL = "[%s (%d)]"
local MAX_NAMES = 2 -- starters or finishers named before "and N more"
local LABEL = "|cffffd100%s|r %s"
local DEFAULTS = {
	colorByDifficulty = true,
}

-- Text, in English unless the client's language has a translation below.
local L = {
	LEVEL = "Level:",
	LEVEL_REQUIRED = "%d (requires %d)",
	STARTS = "Starts:",
	ENDS = "Ends:",
	ITEM = "%s (item)",
	MORE = "%s and %d more",
	COLOR_OPTION = "Color links by difficulty",
	COLOR_TOOLTIP = "Colors quest links made from Questie's text by how hard the quest is for your character, as the quest log does. When off, they are yellow. Applies to new messages.",
}

local TRANSLATIONS = {
	deDE = {
		LEVEL = "Stufe:",
		LEVEL_REQUIRED = "%d (benötigt %d)",
		STARTS = "Start:",
		ENDS = "Abgabe:",
		ITEM = "%s (Gegenstand)",
		MORE = "%s und %d weitere",
		COLOR_OPTION = "Links nach Schwierigkeit einfärben",
		COLOR_TOOLTIP = "Färbt Questlinks aus Questie-Text danach, wie schwer die Quest für deinen Charakter ist, wie im Questlog. Aus: immer gelb. Gilt für neue Nachrichten.",
	},
	esES = {
		LEVEL = "Nivel:",
		LEVEL_REQUIRED = "%d (requiere %d)",
		STARTS = "Inicio:",
		ENDS = "Entrega:",
		ITEM = "%s (objeto)",
		MORE = "%s y %d más",
		COLOR_OPTION = "Colorear enlaces según la dificultad",
		COLOR_TOOLTIP = "Colorea los enlaces de misión creados a partir del texto de Questie según lo difícil que sea la misión para tu personaje, como el registro de misiones. Desactivado: siempre amarillos. Se aplica a los mensajes nuevos.",
	},
	frFR = {
		LEVEL = "Niveau :",
		LEVEL_REQUIRED = "%d (niveau %d requis)",
		STARTS = "Début :",
		ENDS = "Fin :",
		ITEM = "%s (objet)",
		MORE = "%s et %d de plus",
		COLOR_OPTION = "Colorer les liens selon la difficulté",
		COLOR_TOOLTIP = "Colore les liens de quête créés à partir du texte de Questie selon la difficulté de la quête pour votre personnage, comme le journal de quêtes. Désactivé : toujours jaunes. S'applique aux nouveaux messages.",
	},
	itIT = {
		LEVEL = "Livello:",
		LEVEL_REQUIRED = "%d (richiede %d)",
		STARTS = "Inizio:",
		ENDS = "Consegna:",
		ITEM = "%s (oggetto)",
		MORE = "%s e %d in più",
		COLOR_OPTION = "Colora i link in base alla difficoltà",
		COLOR_TOOLTIP = "Colora i link delle missioni creati dal testo di Questie in base alla difficoltà della missione per il tuo personaggio, come il registro missioni. Disattivato: sempre gialli. Vale per i nuovi messaggi.",
	},
	koKR = {
		LEVEL = "레벨:",
		LEVEL_REQUIRED = "%d (요구 레벨 %d)",
		STARTS = "시작:",
		ENDS = "완료:",
		ITEM = "%s (아이템)",
		MORE = "%s 외 %d개",
		COLOR_OPTION = "난이도에 따라 링크 색상 표시",
		COLOR_TOOLTIP = "Questie 텍스트로 만든 퀘스트 링크를 퀘스트 목록처럼 내 캐릭터 기준 난이도에 따라 색칠합니다. 끄면 항상 노란색입니다. 새 메시지부터 적용됩니다.",
	},
	ptBR = {
		LEVEL = "Nível:",
		LEVEL_REQUIRED = "%d (requer %d)",
		STARTS = "Início:",
		ENDS = "Entrega:",
		ITEM = "%s (item)",
		MORE = "%s e mais %d",
		COLOR_OPTION = "Colorir links pela dificuldade",
		COLOR_TOOLTIP = "Colore os links de missão criados a partir do texto do Questie conforme a dificuldade da missão para o seu personagem, como no registro de missões. Desligado: sempre amarelos. Vale para novas mensagens.",
	},
	ruRU = {
		LEVEL = "Уровень:",
		LEVEL_REQUIRED = "%d (требуется %d)",
		STARTS = "Начало:",
		ENDS = "Сдача:",
		ITEM = "%s (предмет)",
		MORE = "%s и ещё %d",
		COLOR_OPTION = "Окрашивать ссылки по сложности",
		COLOR_TOOLTIP = "Окрашивает ссылки на задания из текста Questie по сложности задания для вашего персонажа, как в журнале заданий. Если выключено, они жёлтые. Действует для новых сообщений.",
	},
	zhCN = {
		LEVEL = "等级：",
		LEVEL_REQUIRED = "%d（需要%d级）",
		STARTS = "开始：",
		ENDS = "结束：",
		ITEM = "%s（物品）",
		MORE = "%s及另外%d个",
		COLOR_OPTION = "按难度为链接着色",
		COLOR_TOOLTIP = "按任务对你角色的难度为由 Questie 文本生成的任务链接着色，与任务日志一致。关闭时始终为黄色。对新消息生效。",
	},
	zhTW = {
		LEVEL = "等級：",
		LEVEL_REQUIRED = "%d（需要%d級）",
		STARTS = "開始：",
		ENDS = "結束：",
		ITEM = "%s（物品）",
		MORE = "%s及另外%d個",
		COLOR_OPTION = "依難度為連結著色",
		COLOR_TOOLTIP = "依任務對你角色的難度為由 Questie 文字產生的任務連結著色，與任務日誌一致。關閉時一律為黃色。對新訊息生效。",
	},
}
TRANSLATIONS.esMX = TRANSLATIONS.esES

for key, text in pairs(TRANSLATIONS[GetLocale()] or {}) do
	L[key] = text
end

-- The chat types Questie's own filter covers.
local EVENTS = {
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
}

local options = DEFAULTS -- the saved settings, once Start has loaded them

-- Quest databases, best first. The first one that knows a quest answers for it, so whichever one a player runs is
-- used. Each is checked once, on first use, and left out when its addon is missing or offers another interface.
--
-- Quest(handle, questID) returns nil or { name, englishName, names, level, requiredLevel, record }; chat links need
-- only that. `name` is the quest's own title, which a converted link may show; `names` are other spellings that only
-- count as a match for a plain link. For a tooltip, Starts and Ends(handle, questID, info) list the quest's starters
-- and finishers, each { kind, id } (kind "npc", "object" or "item") or text, with `total` when there are more than
-- listed, and Place(handle, kind, id) names one: "Name (Zone)", or the item's name. A guarded source is read through
-- pcall: it is another addon's internals, which may change or not have loaded yet.

local KINDS = { "npc", "object", "item" }

-- { npcIDs, objectIDs, itemIDs }, as QuestieDB and DingDB keep starters and finishers, as { kind, id } pairs.
local function Entries(by)
	local list = {}
	if type(by) == "table" then
		for index, kind in ipairs(KINDS) do
			if type(by[index]) == "table" then
				for _, id in ipairs(by[index]) do
					list[#list + 1] = { kind, id }
				end
			end
		end
	end
	return list
end

local function WithZone(name, zone)
	if type(zone) == "string" and zone ~= "" then
		return ("%s (%s)"):format(name, zone)
	end
	return name
end

local function AreaName(areaID)
	return areaID and areaID > 0 and C_Map.GetAreaInfo(areaID) or nil
end

local function MapName(uiMapID)
	local info = uiMapID and C_Map.GetMapInfo(uiMapID)
	return info and info.name
end

-- The map with the most spawns, from { [uiMapID] = count }; the lowest ID of a tie, so the answer is stable.
local function Busiest(counts)
	local best, most
	for map, count in pairs(counts) do
		if type(map) == "number" and (not most or count > most or (count == most and map < best)) then
			best, most = map, count
		end
	end
	return best
end

local function ItemText(name)
	return type(name) == "string" and L.ITEM:format(name) or nil
end

-- The spellings in an All The Things display name, as DonData keeps quest names: "Raptor Hunting [CATA+] / Raptor
-- Mastery (1/4)" gives "Raptor Mastery", then "Raptor Hunting". Tags and part numbers go; a trailing note such as
-- "(Horde)" is tried with and without; a name marked for a later expansion comes last.
local function NameVariants(name)
	local first, later = {}, {}
	if type(name) ~= "string" then
		return first
	end
	for part in (name .. " / "):gmatch("(.-) / ") do
		local list = part:find("%[%u+%+%]") and later or first
		local bare = part:gsub("%s*%b[]", ""):gsub("%s*%(%d+/%d+%)", ""):match("^%s*(.-)%s*$")
		if bare ~= "" then
			list[#list + 1] = bare
			local short = bare:gsub("%s*%b()$", "")
			if short ~= bare and short ~= "" then
				list[#list + 1] = short
			end
		end
	end
	for _, variant in ipairs(later) do
		first[#first + 1] = variant
	end
	return first
end

-- A creature's name as the client has it, from its tooltip, or nil until the client has asked the server for it
-- (a later click then has it). DonData names NPCs the same way.
local function ClientCreatureName(creatureID)
	local data = C_TooltipInfo.GetHyperlink(("unit:Creature-0-0-0-0-%d-0000000000"):format(creatureID))
	local line = data and data.lines and data.lines[1]
	local name = line and line.leftText
	if canaccessvalue and not canaccessvalue(name) then
		return nil
	end
	if type(name) == "string" and name ~= "" and not name:find("^Creature%-") then
		return name
	end
end

local QUESTIEDB_CONTRACT = 4

local SOURCES = {
	{
		-- QuestieDB: LibQuestieDB, Get(id, field) on each entity; zones are AreaIDs.
		Bind = function()
			local lib = LibQuestieDB
			local ok = type(lib) == "table" and lib.Quest and lib.Npc and lib.Object and lib.Item
			if ok and lib.RequireContract then
				ok = lib.RequireContract(QUESTIEDB_CONTRACT)
			end
			return ok and lib or nil
		end,
		Quest = function(lib, questID)
			local quest = lib.Quest
			local name = quest.Get(questID, "name")
			if not name then
				return nil
			end
			return {
				name = name,
				level = tonumber(quest.Get(questID, "questLevel")),
				requiredLevel = tonumber(quest.Get(questID, "requiredLevel")),
			}
		end,
		Starts = function(lib, questID)
			return Entries(lib.Quest.Get(questID, "startedBy"))
		end,
		Ends = function(lib, questID)
			return Entries(lib.Quest.Get(questID, "finishedBy"))
		end,
		Place = function(lib, kind, id)
			if kind == "item" then
				return ItemText(lib.Item.Get(id, "name"))
			end
			local entity = kind == "npc" and lib.Npc or lib.Object
			local name = entity.Get(id, "name")
			if not name then
				return nil
			end
			local areaID = tonumber(entity.Get(id, "zoneID"))
			if not areaID or areaID <= 0 then
				local spawns = entity.Get(id, "spawns")
				areaID = type(spawns) == "table" and tonumber((next(spawns))) or nil
			end
			return WithZone(name, AreaName(areaID))
		end,
	},
	{
		-- Ding!'s DingDB: LibDingDB (its docs/dingdb.md), QuestieDB's records by field name; spawns are by UiMapID.
		Bind = function()
			local lib = LibDingDB
			return type(lib) == "table" and type(lib.Get) == "function" and type(lib.Name) == "function" and lib or nil
		end,
		Quest = function(lib, questID)
			local quest = lib.Get("quest", questID)
			if type(quest) ~= "table" or not quest.name then
				return nil
			end
			return {
				name = quest.name,
				englishName = quest.englishName,
				level = tonumber(quest.questLevel),
				requiredLevel = tonumber(quest.requiredLevel),
				record = quest,
			}
		end,
		Starts = function(_, _, info)
			return Entries(info.record.startedBy)
		end,
		Ends = function(_, _, info)
			return Entries(info.record.finishedBy)
		end,
		Place = function(lib, kind, id)
			if kind == "item" then
				return ItemText(lib.Name("item", id))
			end
			local entity = lib.Get(kind, id)
			if type(entity) ~= "table" or not entity.name then
				return nil
			end
			local counts = {}
			for map, points in pairs(type(entity.spawns) == "table" and entity.spawns or {}) do
				counts[map] = type(points) == "table" and #points or 0
			end
			return WithZone(entity.name, MapName(Busiest(counts)))
		end,
	},
	{
		-- Polestar's quest database (Polestar.QuestDB, its Quests/QuestDB.lua). Polestar keeps it for itself, and its
		-- data loads only while one of Polestar's quest features is on. Spawns are by UiMapID.
		guarded = true,
		Bind = function()
			local db = type(Polestar) == "table" and Polestar.QuestDB
			return type(db) == "table" and type(db.GetQuest) == "function" and db or nil
		end,
		Quest = function(db, questID)
			local quest = db.GetQuest(questID)
			if type(quest) ~= "table" or not quest.title then
				return nil
			end
			return {
				name = quest.title,
				level = tonumber(quest.level),
				requiredLevel = tonumber(quest.minLevel),
				record = quest,
			}
		end,
		Starts = function(_, _, info)
			local start = type(info.record.start) == "table" and info.record.start or {}
			return Entries({ start.npc, start.object, start.item })
		end,
		Ends = function(_, _, info)
			local finish = type(info.record.finish) == "table" and info.record.finish or {}
			return Entries({ finish.npc, finish.object })
		end,
		Place = function(db, kind, id)
			if kind == "item" then
				local item = db.GetItem(id)
				return ItemText(type(item) == "table" and item.name)
			end
			local entity = (kind == "npc" and db.GetNpc or db.GetObject)(id)
			if type(entity) ~= "table" or not entity.name then
				return nil
			end
			local counts = {}
			for _, spawn in ipairs(type(entity.spawns) == "table" and entity.spawns or {}) do
				if type(spawn) == "table" and type(spawn.map) == "number" then
					counts[spawn.map] = (counts[spawn.map] or 0) + 1
				end
			end
			return WithZone(entity.name, MapName(Busiest(counts)))
		end,
	},
	{
		-- DonData's DonDataAPI (its Engine/API.lua, version 4), which Questdon and Leveldon use: no quest level, and
		-- one starter and one finisher by name, with their map.
		guarded = true,
		Bind = function()
			local api = DonDataAPI
			local ok = type(api) == "table" and (tonumber(api.version) or 0) >= 4 and type(api.GetQuest) == "function"
			return ok and api or nil
		end,
		Quest = function(api, questID)
			local quest = api.GetQuest(questID)
			if type(quest) ~= "table" or type(quest.name) ~= "string" then
				return nil
			end
			-- quest.name is All The Things' display name (NameVariants). QuestTitle gives the client's or a
			-- recorded title when DonData has one, else that same display name, which a link must not show.
			local title = api.QuestTitle(questID)
			return {
				name = type(title) == "string" and title ~= quest.name and title or nil,
				names = NameVariants(quest.name),
				requiredLevel = tonumber(quest.minLevel),
				record = quest,
			}
		end,
		Starts = function(api, questID, info)
			local starts, givers = {}, info.record.givers
			local map, _, _, giver = api.QuestStart(questID)
			if type(giver) == "string" then
				-- Recorded when this player took the quest, with where they took it.
				starts[1] = WithZone(giver, MapName(map))
			elseif type(givers) == "table" and givers[1] then
				-- DonData's own creature names cover few quest givers. The quest's map is its one giver's; with
				-- several it may belong to another, so it is left out.
				local name = (api.CreatureName and api.CreatureName(givers[1])) or ClientCreatureName(givers[1])
				if type(name) == "string" then
					starts[1] = WithZone(name, #givers == 1 and MapName(map) or nil)
				end
			end
			starts.total = type(givers) == "table" and #givers or 0
			return starts
		end,
		Ends = function(api, questID)
			local npc, finisher = api.TurnInNpc(questID)
			if type(finisher) ~= "string" and npc then
				finisher = ClientCreatureName(npc)
			end
			if type(finisher) ~= "string" then
				return {}
			end
			-- Leaves out the map where DonData only guesses the turn-in: the giver's, or the next quest's giver's.
			-- "shared" (two or more other players reported it) is a source its API comment does not list.
			local map, _, _, from = api.TurnInPoint(questID)
			local known = from == "data" or from == "blizzard" or from == "learned" or from == "shared"
			return { WithZone(finisher, known and MapName(map) or nil) }
		end,
		Place = function()
			return nil
		end,
	},
}

local bound -- { source, handle } for each database whose addon is loaded, from the first lookup on

local function Read(entry, method, ...)
	local source, handle = entry[1], entry[2]
	if not source.guarded then
		return source[method](handle, ...)
	end
	local ok, result = pcall(source[method], handle, ...)
	if ok then
		return result
	end
end

-- The quest's record from the first database that knows it, and that database.
local function QuestInfo(questID)
	if not bound then
		bound = {}
		for _, source in ipairs(SOURCES) do
			local handle = source.Bind()
			if handle then
				bound[#bound + 1] = { source, handle }
			end
		end
	end
	for _, entry in ipairs(bound) do
		local info = Read(entry, "Quest", questID)
		if info then
			return info, entry
		end
	end
end

local function SameName(a, b)
	return type(a) == "string" and type(b) == "string" and a:lower() == b:lower()
end

local function KnownName(info, name)
	if SameName(name, info.name) or SameName(name, info.englishName) then
		return true
	end
	for _, variant in ipairs(info.names or {}) do
		if SameName(name, variant) then
			return true
		end
	end
	return false
end

-- The name each quest's last converted link showed, for its tooltip when neither the client nor the database has a
-- title to show.
local linkNames = {}

local function ClientTitle(questID)
	local title = C_QuestLog.GetTitleForQuestID(questID)
	if type(title) == "string" and title ~= "" then
		return title
	end
end

-- The quest's level from the client's data, for a link without one and a database without levels (DonData). Only
-- once the client has the quest, as in LinkColor, whose quest log colour is a placeholder until then.
local function ClientLevel(questID)
	if ClientTitle(questID) then
		local level = C_QuestLog.GetQuestDifficultyLevel(questID)
		return type(level) == "number" and level > 0 and level or nil
	end
end

-- The quest's difficulty colour for this character, or yellow. Forever's quest log colours by
-- C_PlayerInfo.GetContentDifficultyQuestForPlayer, which works from the client's data for the quest and keeps a quest
-- green further down than GetQuestDifficultyColor's level rule does (level 30 at level 36: green, the rule says
-- grey). A quest the client has not loaded yet only has the level rule.
local function LinkColor(questID, level, loaded)
	if not options.colorByDifficulty then
		return YELLOW
	end
	local difficulty = loaded and C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)
	local color = (difficulty and GetDifficultyColor(difficulty)) or (level > 0 and GetQuestDifficultyColor(level))
	if not color then
		return YELLOW
	end
	return ("ff%02x%02x%02x"):format(
		math.floor(color.r * 255 + 0.5),
		math.floor(color.g * 255 + 0.5),
		math.floor(color.b * 255 + 0.5)
	)
end

local requested = {}

-- The client link for a quest named in chat, or nil to leave the text as it is.
local function QuestLink(id, sentName, sentLevel)
	local questID = tonumber(id)
	if not questID or questID <= 0 or questID > 2147483647 then
		return nil
	end
	local info = QuestInfo(questID)
	local title = ClientTitle(questID)
	if not sentLevel and not (SameName(sentName, title) or (info and KnownName(info, sentName))) then
		return nil
	end
	if not title and not requested[questID] then
		-- Fetches the quest now so its tooltip has the quest text by the time the link is clicked.
		requested[questID] = true
		C_QuestLog.RequestLoadQuestByID(questID)
	end
	local level = (info and info.level)
		or tonumber(sentLevel and sentLevel:match("^%-?%d+"))
		or ClientLevel(questID)
		or -1
	local name = title or (info and info.name) or sentName -- the client's title is in the player's language
	linkNames[questID] = name
	return QUEST_LINK:format(LinkColor(questID, level, title ~= nil), questID, level, name)
end

-- Rewrites the quest texts in a stretch of chat that holds no hyperlink. Links go to `links` and come back as
-- placeholders, so the second pattern cannot match inside a link the first one made.
local function RewritePlain(text, links)
	local function stash(link)
		if link then
			links[#links + 1] = link
			return "\1" .. #links .. "\2"
		end
	end
	text = text:gsub("%[%[(%-?%d+[^%[%]|]*)%] ([^%[%]|]-) %((%d+)%)%]", function(level, name, id)
		return stash(QuestLink(id, name, level))
	end)
	return (
		text:gsub("%[([^%[%]|\1\2]-) %((%d+)%)%]", function(name, id)
			return stash(QuestLink(id, name, nil))
		end)
	)
end

local function Rewrite(msg)
	if not msg:find("%(%d+%)%]") then
		return nil
	end
	local links, parts, pos = {}, {}, 1
	while true do
		-- Text inside existing links (an item called "[Something (5)]") stays as it is.
		local s, e = msg:find("|H.-|h.-|h", pos)
		parts[#parts + 1] = RewritePlain(msg:sub(pos, s and s - 1 or -1), links)
		if not s then
			break
		end
		parts[#parts + 1] = msg:sub(s, e)
		pos = e + 1
	end
	if #links == 0 then
		return nil
	end
	return (table.concat(parts):gsub("\1(%d+)\2", function(i)
		return links[tonumber(i)]
	end))
end

local function Filter(_, _, msg, ...)
	if type(msg) ~= "string" then
		return false
	end
	local rewritten = Rewrite(msg)
	if rewritten then
		return false, rewritten, ...
	end
	return false
end

-- What goes in the chat box for a quest link: the client's own link when the quest is in the quest log (the quest
-- log inserts the same), otherwise Questie's text.
local function RelinkText(questID, level, name)
	local inLog = C_QuestLog.GetLogIndexForQuestID(questID)
	local link = inLog and GetQuestLink and GetQuestLink(questID)
	if link then
		return link
	end
	if level > 0 then
		return QUESTIE_TEXT:format(level, name, questID)
	end
	return QUESTIE_TEXT_NO_LEVEL:format(name, questID)
end

local function PatternEscape(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Runs after Blizzard, or an addon such as WIM, has put a link into a chat box. It goes by the link's content, not
-- by whether this session made it: WIM shows saved whispers again without running chat filters, so a converted link
-- from an earlier session reaches here too.
local function OnInsertLink(text)
	if type(text) ~= "string" or (canaccessvalue and not canaccessvalue(text)) then
		return
	end
	local id, level, name = text:match("|Hquest:(%d+):(%-?%d+)[^|]*|h%[(.-)%]|h")
	if not id then
		return
	end
	local replacement = RelinkText(tonumber(id), tonumber(level), name)
	if replacement == text then
		return
	end
	local box = ChatFrameUtil.GetActiveWindow() or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
	local current = box and box.GetText and box:GetText()
	if type(current) ~= "string" or not current:find(text, 1, true) then
		return
	end
	box:SetText((current:gsub(PatternEscape(text), (replacement:gsub("%%", "%%%%")))))
end

-- Up to MAX_NAMES of a quest's starters or finishers, then "and N more".
local function Describe(entry, list)
	if type(list) ~= "table" then
		return nil
	end
	local names = {}
	for _, item in ipairs(list) do
		if #names >= MAX_NAMES then
			break
		end
		local name = item
		if type(item) == "table" then
			name = Read(entry, "Place", item[1], item[2])
		end
		if type(name) == "string" then
			names[#names + 1] = name
		end
	end
	if #names == 0 then
		return nil
	end
	local text = table.concat(names, ", ")
	local total = math.max(tonumber(list.total) or 0, #list)
	if total > #names then
		text = L.MORE:format(text, total - #names)
	end
	return text
end

-- linkLevel is the level on the link that was clicked, for a database that has no quest levels.
local function AddQuestInfo(tooltip, questID, linkLevel)
	if not questID then
		return false
	end
	local info, entry = QuestInfo(questID)
	if not info then
		return false
	end
	local title = info.name or linkNames[questID] or (info.names and info.names[1])
	if tooltip:NumLines() == 0 and title then
		tooltip:AddLine(title, 1, 1, 1)
	end
	tooltip:AddLine(" ")
	local level, required = info.level or linkLevel, info.requiredLevel
	if not (level and level > 0) then
		level = ClientLevel(questID)
	end
	if level and level > 0 then
		local text = tostring(level)
		if required and required > 0 and required ~= level then
			text = L.LEVEL_REQUIRED:format(level, required)
		end
		tooltip:AddLine(LABEL:format(L.LEVEL, text), 1, 1, 1)
	end
	local starts = Describe(entry, Read(entry, "Starts", questID, info))
	if starts then
		tooltip:AddLine(LABEL:format(L.STARTS, starts), 1, 1, 1, true)
	end
	local ends = Describe(entry, Read(entry, "Ends", questID, info))
	if ends then
		tooltip:AddLine(LABEL:format(L.ENDS, ends), 1, 1, 1, true)
	end
	return true
end

-- The quest ID and level of a link holding "quest:ID:LEVEL".
local function QuestFromLink(link)
	if type(link) ~= "string" or (canaccessvalue and not canaccessvalue(link)) then
		return nil
	end
	local id, level = link:match("quest:(%d+):?(%-?%d*)")
	return tonumber(id), tonumber(level)
end

local function LinkOf(info)
	return info and info.getterName == "GetHyperlink" and info.getterArgs and info.getterArgs[1] or nil
end

local settingsCategory

-- The row goes in through Settings.RegisterInitializer: on Forever, rows added with Settings.CreateCheckbox taint
-- the settings search (SkillUp Forever's finding).
local function RegisterSettings()
	local category = Settings.RegisterVerticalLayoutCategory("Clickable Quest Links")
	local setting = Settings.RegisterAddOnSetting(
		category,
		"ClickableQuestLinks_colorByDifficulty",
		"colorByDifficulty",
		options,
		Settings.VarType.Boolean,
		L.COLOR_OPTION,
		DEFAULTS.colorByDifficulty
	)
	Settings.RegisterInitializer(category, Settings.CreateCheckboxInitializer(setting, nil, L.COLOR_TOOLTIP))
	Settings.RegisterAddOnCategory(category)
	settingsCategory = category
end

-- Blizzard's Settings.OpenToCategory is refused from addon code on Forever, so this calls the client's own opener.
local function OpenSettings()
	if not settingsCategory then
		return
	end
	if InCombatLockdown() then
		print("Clickable Quest Links: " .. ERR_NOT_IN_COMBAT)
		return
	end
	if C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
		securecallfunction(C_SettingsUtil.OpenSettingsPanel, settingsCategory:GetID())
	end
end

local function Start()
	if C_AddOns.IsAddOnLoaded("Questie") then
		return
	end
	ClickableQuestLinksDB = ClickableQuestLinksDB or {}
	options = ClickableQuestLinksDB
	for key, value in pairs(DEFAULTS) do
		if options[key] == nil then
			options[key] = value
		end
	end

	local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	for _, event in ipairs(EVENTS) do
		addFilter(event, Filter)
	end
	hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)

	-- Blizzard runs tooltip post-calls each time it rebuilds the tooltip (also when quest data arrives later),
	-- right before showing it, so the lines are added once per build and survive refreshes.
	if TooltipDataProcessor and Enum.TooltipDataType and Enum.TooltipDataType.Quest then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Quest, function(tooltip, data)
			if tooltip ~= ItemRefTooltip then
				return
			end
			local linkID, linkLevel = QuestFromLink(LinkOf(tooltip:GetPrimaryTooltipInfo()))
			local questID = data and tonumber(data.id) or linkID
			AddQuestInfo(tooltip, questID, questID == linkID and linkLevel or nil)
		end)
	end

	-- With no client data for a quest, Blizzard hides ItemRefTooltip and the click shows nothing, so this shows
	-- the quest database's details instead. Hiding is also how Blizzard closes the tooltip on a second click of its link;
	-- the client having data tells the two apart, and closedLink/closedAt give the fallback the same close. Hiding
	-- wipes the tooltip's own record of its link (ClearHandlerInfo), hence fallbackLink.
	local fallbackLink, closedLink, closedAt
	ItemRefTooltip:HookScript("OnTooltipCleared", function()
		fallbackLink = nil
	end)
	ItemRefTooltip:HookScript("OnHide", function()
		closedLink, closedAt, fallbackLink = fallbackLink, GetTime(), nil
	end)
	hooksecurefunc(ItemRefTooltip, "ItemRefSetHyperlink", function(tooltip, link)
		local questID, level = QuestFromLink(link)
		if not questID or tooltip:IsShown() or C_TooltipInfo.GetHyperlink(link) then
			return
		end
		if closedLink == link and closedAt == GetTime() then
			return
		end
		tooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
		if AddQuestInfo(tooltip, questID, level) then
			tooltip:Show()
			fallbackLink = link
		end
	end)

	-- Last, so a settings page that fails to build cannot take the links down with it.
	RegisterSettings()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	Start()
end)

SLASH_CLICKABLEQUESTLINKS1 = "/cql"
SLASH_CLICKABLEQUESTLINKS2 = "/clickablequestlinks"
SlashCmdList.CLICKABLEQUESTLINKS = OpenSettings
