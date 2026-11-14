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
-- QuestieDB, when loaded, confirms the quest exists and adds its level and where it starts and ends to the tooltip
-- of every quest link opened from chat, native ones included. Without it only the "[[level] Name (id)]" form is
-- trusted: "[some text (123)]" also turns up in normal chat.
--
-- With Questie loaded this stays out of the way: Questie handles the same text with its own tooltip.

local QUEST_LINK = "|c%s|Hquest:%d:%d|h[%s]|h|r"
local YELLOW = "ffffff00" -- the colour the client gives a quest link that has none (GetFixedLink)
local QUESTIE_TEXT = "[[%d] %s (%d)]"
local QUESTIE_TEXT_NO_LEVEL = "[%s (%d)]"
local QUESTIEDB_CONTRACT = 4
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

local questieDB -- LibQuestieDB once bound; false when it is missing or speaks an incompatible contract

local function DB()
	if questieDB == nil then
		local lib = LibQuestieDB
		local ok = lib and lib.Quest and lib.Npc and lib.Object and lib.Item
		if ok and lib.RequireContract then
			ok = lib.RequireContract(QUESTIEDB_CONTRACT)
		end
		questieDB = ok and lib or false
	end
	return questieDB or nil
end

local function SameName(a, b)
	return type(a) == "string" and type(b) == "string" and a:lower() == b:lower()
end

local function ClientTitle(questID)
	local title = C_QuestLog.GetTitleForQuestID(questID)
	if type(title) == "string" and title ~= "" then
		return title
	end
end

-- The quest's difficulty colour for this character, as the quest log shows it, or yellow.
local function LinkColor(level)
	local color = options.colorByDifficulty and level > 0 and GetQuestDifficultyColor(level)
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
	local db = DB()
	local dbName = db and db.Quest.Get(questID, "name")
	if db and not dbName then
		return nil -- not a quest QuestieDB knows; Questie skips these the same way
	end
	if not db and not sentLevel then
		return nil
	end
	local title = ClientTitle(questID)
	if not sentLevel and not (SameName(sentName, dbName) or SameName(sentName, title)) then
		return nil
	end
	if not title and not requested[questID] then
		-- Fetches the quest now so its tooltip has the quest text by the time the link is clicked.
		requested[questID] = true
		C_QuestLog.RequestLoadQuestByID(questID)
	end
	local level = (db and tonumber(db.Quest.Get(questID, "questLevel")))
		or tonumber(sentLevel and sentLevel:match("^%-?%d+"))
		or -1
	local name = title or dbName or sentName -- the client's title is in the player's language
	return QUEST_LINK:format(LinkColor(level), questID, level, name)
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

-- "Name (Zone)" for an NPC or object.
local function PlaceName(entity, id)
	local name = entity.Get(id, "name")
	if not name then
		return nil
	end
	local areaID = tonumber(entity.Get(id, "zoneID"))
	if not areaID or areaID <= 0 then
		local spawns = entity.Get(id, "spawns")
		areaID = type(spawns) == "table" and tonumber((next(spawns))) or nil
	end
	local area = areaID and areaID > 0 and C_Map.GetAreaInfo(areaID)
	if type(area) == "string" and area ~= "" then
		return ("%s (%s)"):format(name, area)
	end
	return name
end

-- Up to MAX_NAMES of a quest's starters or finishers ({ npcIDs, objectIDs, itemIDs }), then "and N more".
local function Describe(db, by)
	if type(by) ~= "table" then
		return nil
	end
	local entities = { db.Npc, db.Object }
	local names, total = {}, 0
	for kind = 1, 3 do
		local ids = type(by[kind]) == "table" and by[kind] or {}
		for _, id in ipairs(ids) do
			total = total + 1
			if #names < MAX_NAMES then
				local name
				if kind == 3 then
					local itemName = db.Item.Get(id, "name")
					name = itemName and L.ITEM:format(itemName)
				else
					name = PlaceName(entities[kind], id)
				end
				names[#names + 1] = name
			end
		end
	end
	if #names == 0 then
		return nil
	end
	local text = table.concat(names, ", ")
	if total > #names then
		text = L.MORE:format(text, total - #names)
	end
	return text
end

local function AddQuestInfo(tooltip, questID)
	local db = DB()
	if not db or not questID then
		return false
	end
	local quest = db.Quest
	local name = quest.Get(questID, "name")
	if not name then
		return false
	end
	if tooltip:NumLines() == 0 then
		tooltip:AddLine(name, 1, 1, 1)
	end
	tooltip:AddLine(" ")
	local level, required = tonumber(quest.Get(questID, "questLevel")), tonumber(quest.Get(questID, "requiredLevel"))
	if level and level > 0 then
		local text = tostring(level)
		if required and required > 0 and required ~= level then
			text = L.LEVEL_REQUIRED:format(level, required)
		end
		tooltip:AddLine(LABEL:format(L.LEVEL, text), 1, 1, 1)
	end
	local starts = Describe(db, quest.Get(questID, "startedBy"))
	if starts then
		tooltip:AddLine(LABEL:format(L.STARTS, starts), 1, 1, 1, true)
	end
	local ends = Describe(db, quest.Get(questID, "finishedBy"))
	if ends then
		tooltip:AddLine(LABEL:format(L.ENDS, ends), 1, 1, 1, true)
	end
	return true
end

local function QuestIDFromLink(link)
	return type(link) == "string" and tonumber(link:match("quest:(%d+)")) or nil
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
			local questID = data and tonumber(data.id) or QuestIDFromLink(LinkOf(tooltip:GetPrimaryTooltipInfo()))
			AddQuestInfo(tooltip, questID)
		end)
	end

	-- With no client data for a quest, Blizzard hides ItemRefTooltip and the click shows nothing, so this shows
	-- QuestieDB's details instead. Hiding is also how Blizzard closes the tooltip on a second click of its link;
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
		local questID = QuestIDFromLink(link)
		if not questID or tooltip:IsShown() or C_TooltipInfo.GetHyperlink(link) then
			return
		end
		if closedLink == link and closedAt == GetTime() then
			return
		end
		tooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
		if AddQuestInfo(tooltip, questID) then
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
