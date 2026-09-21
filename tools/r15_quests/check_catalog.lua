-- Bounded Round 15 quest registry and local-availability fixture.
-- Run with LuaJIT; the package-level final parity pair belongs to the coordinator.

local root = arg[1] or "."

function table.copy(value)
	local result = {}
	for key, item in pairs(value) do result[key] = item end
	return result
end

local settlements = {
	dwarf = {"hearthpine", "copperfell_village", "copperfell_outpost", "copperfell_bandit_camp"},
	human = {"dawnmere", "goldmead_village", "goldmead_outpost", "goldmead_bandit_camp"},
	elf = {"silverleaf", "starbough_village", "starbough_outpost", "starbough_bandit_camp"},
	undead = {"stillgrave", "mournfen_village", "mournfen_outpost", "mournfen_bandit_camp"},
	orc = {"sunscar", "redtusk_village", "redtusk_outpost", "redtusk_bandit_camp"},
	troll = {"kapok", "raincall_village", "raincall_outpost", "raincall_bandit_camp"},
}

local sockets = {}
local settlement_records = {}
for _, route in pairs(settlements) do
	for index, key in ipairs(route) do
		settlement_records[#settlement_records + 1] = {key = key}
		if index == 1 then
			sockets[key] = {{id = "hall_quest", role = "quest"}}
		elseif index == 2 then
			sockets[key] = {
				{id = "quest_steward", role = "quest"},
				{id = "quest_local", role = "quest"},
			}
		elseif index == 3 then
			sockets[key] = {{id = "quest_scout", role = "quest"}}
		else
			sockets[key] = {{id = "quest_captive", role = "quest"}}
		end
	end
end

grug_core = {
	settlement_socket_settlements = function() return settlement_records end,
	settlement_sockets_at = function(key) return sockets[key] or {} end,
}

local entity_names = {
	"boar", "giant_rat", "zombie", "ibex", "fox", "goblin_raider",
	"goblin_slinger", "goblin_hound", "bandit", "bandit_archer",
	"wild_turkey", "poacher", "plague_boar", "bog_ooze", "crocodile",
	"scorpion", "sun_dried_husk", "plains_runner", "hyena", "jungle_boar",
	"viper", "jungle_lynx",
}

core = {registered_entities = {}, registered_items = {
	["mobs:meat_raw"] = {}, ["default:axe_wood"] = {},
	["default:pick_stone"] = {}, ["default:cobble"] = {},
	["mobs:leather"] = {}, ["grug_mobs:slime_gel"] = {},
	["grug_mobs:linen_cloth"] = {},
}}
for _, name in ipairs(entity_names) do core.registered_entities["grug_mobs:" .. name] = {} end

function ItemStack(spec)
	local name = spec:match("^([^ ]+)") or ""
	return {is_empty = function() return name == "" end,
		get_name = function() return name end}
end

grug_quests = {}
dofile(root .. "/mods/PLAYER/grug_quests/registry.lua")
dofile(root .. "/mods/PLAYER/grug_quests/content.lua")
grug_quests.validate_registry()

local allowed = {
	dwarf = {ibex = true, fox = true, goblin_raider = true,
		goblin_slinger = true, goblin_hound = true, bandit = true,
		bandit_archer = true},
	human = {wild_turkey = true, fox = true, poacher = true, bandit = true,
		bandit_archer = true},
	elf = {fox = true, poacher = true, bandit = true, bandit_archer = true},
	undead = {bog_ooze = true, plague_boar = true, crocodile = true,
		bandit = true, bandit_archer = true},
	orc = {scorpion = true, hyena = true, bandit = true, bandit_archer = true},
	troll = {viper = true, jungle_lynx = true, bandit = true,
		bandit_archer = true},
}

local clocks = {
	ibex = "day", fox = "day", goblin_raider = "night",
	goblin_slinger = "night", goblin_hound = "night", bandit = "any",
	bandit_archer = "any", wild_turkey = "day", poacher = "night",
	bog_ooze = "any", plague_boar = "day", crocodile = "any",
	scorpion = "night", hyena = "any", viper = "night", jungle_lynx = "day",
}

local quest_count, npc_count, r14_count, r15_count = 0, 0, 0, 0
local local_kills, local_items = 0, 0
local local_by_race, local_by_npc = {}, {}
local items_by_race = {}
for id, def in pairs(grug_quests.registered_quests) do
	quest_count = quest_count + 1
	if id:match("^r14_") then
		r14_count = r14_count + 1
		assert(def.target_level and def.effort, "missing authored reward basis: " .. id)
	elseif id:match("^r15_") then
		r15_count = r15_count + 1
		assert(def.min_level == def.target_level and def.effort)
		assert(#def.prerequisites == 1 and def.prerequisites[1]:match("^r14_"))
		local_by_race[def.race] = (local_by_race[def.race] or 0) + 1
		local_by_npc[def.npc] = (local_by_npc[def.npc] or 0) + 1
		for _, objective in ipairs(def.objectives) do
			if objective.type == "item" then
				local_items = local_items + 1
				assert(core.registered_items[objective.item])
				items_by_race[def.race] = items_by_race[def.race] or {}
				items_by_race[def.race][objective.item] = objective.count
			else
				local_kills = local_kills + 1
				assert(objective.zone)
				for _, mob in ipairs(objective.mobs) do
					local short = mob:match("^grug_mobs:(.+)$")
					assert(short and allowed[def.race][short], id .. " unavailable target " .. mob)
					assert(clocks[short], id .. " missing checked spawn clock " .. mob)
				end
			end
		end
	else
		error("unexpected quest namespace: " .. id)
	end
end
for id in pairs(grug_quests.registered_npcs) do
	npc_count = npc_count + 1
	if id:match("^r15_") then assert(local_by_npc[id] == 2, id .. " must own two tasks") end
end

assert(quest_count == 102 and r14_count == 66 and r15_count == 36)
assert(npc_count == 30)
assert(local_items == 12 and local_kills == 24)
local village_items = {dwarf = {"default:cobble", 8},
	human = {"mobs:meat_raw", 4}, elf = {"mobs:leather", 2},
	undead = {"grug_mobs:slime_gel", 3}, orc = {"mobs:leather", 2},
	troll = {"mobs:meat_raw", 4}}
for race in pairs(settlements) do
	assert(local_by_race[race] == 6)
	assert(local_by_npc["r15_" .. race .. "_local"] == 2)
	assert(local_by_npc["r14_" .. race .. "_scout"] == 2)
	assert(local_by_npc["r14_" .. race .. "_captive"] == 2)
	assert(items_by_race[race][village_items[race][1]] == village_items[race][2])
	assert(items_by_race[race]["grug_mobs:linen_cloth"] == 5)
end

io.write("quests=102;r14=66;r15=36;npcs=30;routes=6;local_per_route=6;local_per_poi=2;items=12;kills=24\n")
