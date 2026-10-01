-- The canonical form of the quest registry (Round 28 Lane B4): what a
-- registered quest MEANS to a player -- giver, turn-in, gates, objectives,
-- rewards and the dialogue text -- without bookkeeping fields. The content
-- migration proves "same ids, same behaviour" by comparing this form of the
-- registry built from the deleted Lua content generators with the one built
-- from the per-zone quest files (tools/r28_b4_quests/portable_test.lua and
-- the engine probe).
--
-- Deliberate differences of the migration are NOT hidden here; the tests
-- list them (Ruling 29's two wild_turkey targets). Not part of the form:
-- the unused `effort` tag and objective `description` overrides (the quest
-- format has neither; dialogue and log name the item itself).
local canonical = {}

local function list(values)
	local out = {}
	for i, v in ipairs(values or {}) do out[i] = v end
	return out
end

function canonical.objective(objective)
	return {type = objective.type, count = objective.count, item = objective.item,
		group = objective.group, mobs = objective.mobs and list(objective.mobs) or nil,
		-- The generators wrote `zone = false` for "no zone filter".
		zone = objective.zone or nil, area = objective.area, npc = objective.npc}
end

function canonical.quest(def)
	local objectives = {}
	for i, objective in ipairs(def.objectives) do objectives[i] = canonical.objective(objective) end
	local items = {}
	for i, item in ipairs(def.rewards.items or {}) do items[i] = tostring(item) end
	local rewards = {copper = def.rewards.copper, items = items}
	if def.rewards.weight then rewards.weight = def.rewards.weight
	else rewards.xp = def.rewards.xp end
	return {
		id = def.id, title = def.title, description = def.description,
		npc = def.npc, turnin_npc = def.turnin_npc,
		min_level = def.min_level, level = def.level or def.target_level,
		prerequisites = list(def.prerequisites), faction = def.faction, race = def.race,
		objectives = objectives, rewards = rewards,
		repeatable = def.repeatable and {cooldown = def.repeatable.cooldown} or nil,
	}
end

function canonical.registry(quests, npcs)
	local out = {quests = {}, npcs = {}}
	for id, def in pairs(quests) do out.quests[id] = canonical.quest(def) end
	for id, def in pairs(npcs) do
		out.npcs[id] = {settlement = def.settlement, socket = def.socket, title = def.title}
	end
	return out
end

return canonical
