-- A stand-in for Polestar's quest database as Clickable Quest Links reads it: Polestar.QuestDB with GetQuest, GetNpc,
-- GetObject and GetItem, returning the shapes Polestar's Quests/QuestDB.lua documents. Spawns are { map = uiMapID,
-- x, y, r }. FAKE_POLESTAR_UNLOADED makes every read fail, as reads can before Polestar has loaded its data.
local quests = {
	[2001] = {
		title = "Cleansing the Oasis",
		level = 25,
		minLevel = 20,
		start = { npc = { 3001 }, object = {}, item = {} },
		finish = { npc = { 3002 }, object = { 3003 } },
	},
}
local npcs = {
	[3001] = {
		name = "Oasis Druid",
		spawns = { { map = 1413, x = 45, y = 30, r = 5 }, { map = 1413, x = 46, y = 31, r = 5 } },
	},
	[3002] = { name = "Grove Keeper", spawns = { { map = 1440, x = 20, y = 40, r = 5 } } },
}
local objects = {
	[3003] = { name = "Moonwell", spawns = { { map = 1440, x = 21, y = 41, r = 5 } } },
}

local function read(rows, id)
	if FAKE_POLESTAR_UNLOADED then
		error("attempt to index a nil value (field 'quests')")
	end
	local row = rows[id]
	if not row then
		return nil
	end
	local out = { id = id }
	for k, v in pairs(row) do
		out[k] = v
	end
	return out
end

Polestar = {
	QuestDB = {
		GetQuest = function(id)
			return read(quests, id)
		end,
		GetNpc = function(id)
			return read(npcs, id)
		end,
		GetObject = function(id)
			return read(objects, id)
		end,
		GetItem = function()
			return nil
		end,
	},
}
