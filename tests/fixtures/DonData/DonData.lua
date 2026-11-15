-- A stand-in for DonData's DonDataAPI as Clickable Quest Links reads it, version 4 as in DonData's Engine/API.lua:
-- GetQuest (no quest level), QuestTitle, QuestStart (mapID, x, y, npcName), TurnInNpc (creatureID, name) and
-- TurnInPoint (mapID, x, y, source).
local quests = {
	[4001] = {
		name = "Supplies for the Crossroads",
		minLevel = 12,
		givers = { 501, 502 },
		start = { 1413, 0.5, 0.5, "Supply Officer" },
		ender = { 503, "Quartermaster" },
		turnIn = { 1413, 0.4, 0.4, "data" },
	},
	-- DonData only guesses where this one is turned in.
	[4002] = {
		name = "Word to the Wise",
		minLevel = 14,
		givers = { 504 },
		start = { 1413, 0.6, 0.6, "Wandering Sage" },
		ender = { 505, "Distant Elder" },
		turnIn = { 1413, 0.6, 0.6, "giver" },
	},
}

DonDataAPI = { version = 4 }

function DonDataAPI.GetQuest(questID)
	local q = quests[questID]
	if not q then
		return nil
	end
	return { questID = questID, mapID = q.start[1], minLevel = q.minLevel, givers = q.givers, name = q.name }
end

function DonDataAPI.QuestTitle(questID)
	return quests[questID] and quests[questID].name
end

function DonDataAPI.QuestStart(questID)
	local q = quests[questID]
	if q then
		return unpack(q.start)
	end
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
		return unpack(q.turnIn)
	end
end
