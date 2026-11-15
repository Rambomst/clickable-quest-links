-- A stand-in for DonData's DonDataAPI as Clickable Quest Links reads it, version 4, with the shapes of DonData 1.3.0's
-- Engine/API.lua and Engine/QuestData.lua. GetQuest's name is All The Things' display name, tags and part numbers
-- included, and QuestTitle returns it too unless the client or DonData's records have the quest's own title.
-- QuestStart names a giver only for a quest this player took while DonData recorded it, CreatureName knows few quest
-- givers, and TurnInNpc names an NPC once the game or DonData's records know it. No quest levels.
local quests = {
	[4001] = {
		name = "Supplies for the Crossroads (1/2)",
		minLevel = 12,
		givers = { 501, 502 },
		start = { 1413, 0.5, 0.5, "Supply Officer" },
		ender = { 503, "Quartermaster" },
		turnIn = { 1413, 0.4, 0.4, "data" },
	},
	-- The client has this one's title; DonData only guesses where it is turned in.
	[4002] = {
		name = "Word to the Wise [H]",
		title = "Word to the Wise",
		minLevel = 14,
		givers = { 504 },
		start = { 1413, 0.6, 0.6 },
		ender = { 505, "Distant Elder" },
		turnIn = { 1413, 0.6, 0.6, "giver" },
	},
	-- Renamed in a later expansion. Nothing recorded, so the NPCs' names come from DonData's data and the client.
	[4003] = {
		name = "Crossroads Patrol [CATA+] / Barrens Patrol (2/3)",
		minLevel = 15,
		givers = { 506 },
		start = { 1413, 0.7, 0.7 },
		ender = { 507 },
		turnIn = { 1413, 0.7, 0.7, "shared" },
	},
}
local creatures = { [506] = "Patrol Leader" }

DonDataAPI = { version = 4 }

function DonDataAPI.GetQuest(questID)
	local q = quests[questID]
	if not q then
		return nil
	end
	return { questID = questID, mapID = q.start[1], minLevel = q.minLevel, givers = q.givers, name = q.name }
end

function DonDataAPI.QuestTitle(questID)
	local q = quests[questID]
	return q and (q.title or q.name)
end

function DonDataAPI.QuestStart(questID)
	local q = quests[questID]
	if q then
		return q.start[1], q.start[2], q.start[3], q.start[4]
	end
end

function DonDataAPI.CreatureName(creatureID)
	return creatures[creatureID]
end

function DonDataAPI.TurnInNpc(questID)
	local q = quests[questID]
	if q then
		return q.ender[1], q.ender[2]
	end
end

function DonDataAPI.TurnInPoint(questID)
	local q = quests[questID]
	if q then
		return q.turnIn[1], q.turnIn[2], q.turnIn[3], q.turnIn[4]
	end
end
