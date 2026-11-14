-- A stand-in for QuestieDB as Clickable Quest Links reads it: LibQuestieDB with Get(id, field) on Quest, Npc, Object
-- and Item, and RequireContract. Field names follow QuestieDB 1.1.0's src/meta (contract 4); startedBy and
-- finishedBy are { npcIDs, objectIDs, itemIDs } as there. FAKE_QUESTIEDB_CONTRACT lets a test pose as another
-- contract version.
local quests = {
	[194] = {
		name = "Raptor Mastery",
		questLevel = 34,
		requiredLevel = 30,
		startedBy = { { 715 } },
		finishedBy = { { 715 } },
	},
	[155] = {
		name = "The Defias Brotherhood",
		questLevel = 18,
		requiredLevel = 14,
		startedBy = { { 234 } },
		finishedBy = { { 234 } },
	},
	-- Lua pattern characters and a parenthesised part in the name.
	[9001] = {
		name = "100% Ready - Part (2)",
		questLevel = 10,
		requiredLevel = 10,
		startedBy = { nil, { 900 } },
		finishedBy = { { 1, 2, 3 } },
	},
	[9002] = {
		name = "A Note in the Water",
		questLevel = 20,
		requiredLevel = 16,
		startedBy = { nil, nil, { 5000 } },
		finishedBy = { { 1 } },
	},
	-- No level on record.
	[9003] = {
		name = "Levelless Quest",
	},
}

local npcs = {
	[715] = { name = "Hemet Nesingwary Jr.", zoneID = 33 },
	[234] = { name = "Gryan Stoutmantle", zoneID = 40 },
	[1] = { name = "First Finisher", spawns = { [12] = { { 10, 20 } } } },
	[2] = { name = "Second Finisher", zoneID = 12 },
	[3] = { name = "Third Finisher", zoneID = 12 },
}
local objects = { [900] = { name = "Wanted Poster", zoneID = 12 } }
local items = { [5000] = { name = "Soggy Note" } }

local function entity(rows)
	return {
		Get = function(id, field)
			local row = rows[id]
			return row and row[field]
		end,
	}
end

LibQuestieDB = {
	Quest = entity(quests),
	Npc = entity(npcs),
	Object = entity(objects),
	Item = entity(items),
	contractVersion = FAKE_QUESTIEDB_CONTRACT or 4,
	minSupportedContract = 1,
}

function LibQuestieDB.RequireContract(required)
	if required > LibQuestieDB.contractVersion or required < LibQuestieDB.minSupportedContract then
		return false, "incompatible QuestieDB contract"
	end
	return true
end
