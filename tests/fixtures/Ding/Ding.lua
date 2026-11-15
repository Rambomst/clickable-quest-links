-- A stand-in for Ding!'s DingDB as Clickable Quest Links reads it: LibDingDB.Get(kind, id) and Name(kind, id), as in
-- Ding's Core/DingDB.lua and docs/dingdb.md (API version 1). Quests hold QuestieDB's fields by name; NPC and object
-- spawns are { [uiMapID] = { x1, y1, x2, y2, ... } }. `name` is in the client's language, `englishName` always English.
local records = {
	quest = {
		[194] = {
			name = "Raptor Mastery",
			questLevel = 34,
			requiredLevel = 30,
			startedBy = { { 7150 } },
			finishedBy = { { 7150 } },
		},
		[1061] = {
			name = "The Spirits of Stonetalon",
			questLevel = 17,
			requiredLevel = 13,
			startedBy = { { 3216 } },
			finishedBy = { { 4049 } },
		},
		-- A German client: the name is translated, the English one kept.
		[7001] = {
			name = "Ein Brief im Wasser",
			englishName = "A Letter in the Water",
			questLevel = 12,
			requiredLevel = 9,
			startedBy = { nil, nil, { 9200 } },
			finishedBy = { { 4049 } },
		},
		[7002] = {
			name = "Posted Bounty",
			questLevel = 15,
			requiredLevel = 15,
			startedBy = { nil, { 9100 } },
			finishedBy = { nil, { 9100 } },
		},
	},
	npc = {
		-- Not QuestieDB's starter for 194: the scenario that loads both sees whose answer is used.
		[7150] = { name = "Ding's Hemet", spawns = { [1434] = { 35.6, 10.8 } } },
		[3216] = { name = "Zor Lonetree", spawns = { [1454] = { 38.9, 38.3, 39.0, 38.4 }, [1411] = { 10, 10 } } },
		[4049] = { name = "Seereth Stonebreak", spawns = { [1413] = { 49.4, 15.1, 49.5, 15.2 } } },
	},
	object = {
		[9100] = { name = "Bounty Board", spawns = { [1413] = { 52.0, 30.0 } } },
	},
	item = {
		[9200] = { name = "Torn Letter" },
	},
}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = copy(v)
	end
	return out
end

LibDingDB = { version = 1 }

function LibDingDB.Get(kind, id)
	local record = records[kind] and records[kind][id]
	if not record then
		return nil
	end
	local out = copy(record)
	out.id = id
	out.englishName = record.englishName or record.name
	return out
end

function LibDingDB.Name(kind, id)
	local record = records[kind] and records[kind][id]
	return record and record.name
end
