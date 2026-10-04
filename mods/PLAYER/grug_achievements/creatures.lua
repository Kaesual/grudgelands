--
-- Which kills count as what (round33-plan.md §2.10). "Wild animals" are
-- every animal mob, critters and hostile beasts included, no humanoids; the
-- zombie family has its own counter. Pure: the sub-type lookup is handed in,
-- so the fixture runs this file as is.
--
-- A sub-type (grug_mobs data/subtypes.json) counts as its base mob. Every
-- mob grug_mobs registers is in exactly one of the three lists or is a
-- settlement or faction NPC by its name; init.lua checks that at load, so a
-- new mob nobody classified shows up in the log instead of silently never
-- counting.
--

local C = {}

local function set(names)
	local out = {}
	for _, name in ipairs(names) do
		out[name] = true
	end
	return out
end

-- Animals: beasts, birds, fish, crabs, snakes, spiders and other crawlers,
-- and the Kraken Guard (user ruling 2026-10-04).
C.ANIMALS = set({
	"bear", "blightfang_wolf", "blood_bat", "boar", "bog_fowl", "bone_weevil",
	"carrion_crow", "cave_bat", "cave_crawler", "crag_eagle", "crocodile",
	"fox", "gaunt_stag", "giant_rat", "giant_spider", "glowwing",
	"goblin_hound", "gull", "hare", "hyena", "ibex", "jungle_ape",
	"jungle_boar", "jungle_lynx", "jungle_spider", "kraken", "mountain_ram",
	"pale_spider", "panther", "parrot", "plague_boar", "plaguehide_bear",
	"plains_runner", "rabbit", "reed_angelfish", "reef_lurker", "scorpion",
	"serpent", "shore_crab", "snow_leopard", "song_bird", "speargrass_tiger",
	"spiderling", "stag", "stone_mite", "tapir", "viper", "vulture",
	"wild_turkey", "wolf", "zebra",
})

C.ZOMBIES = set({"zombie", "sun_dried_husk"})

-- Neither: humanoids (bandits, goblins, mirefolk, skeletons, witches),
-- constructs, spirits, slimes, plants, and the dragons and their whelps
-- (bosses and boss adds, user ruling 2026-10-04).
C.OTHERS = set({
	"ashen_treant", "bandit", "bandit_archer", "bog_ooze", "bog_witch",
	"crystal_shard", "dungeon_master", "ember_wisp", "frost_stray",
	"goblin_miner", "goblin_miner_slinger", "goblin_raider", "goblin_slinger",
	"gravewood_treant", "ice_dragon", "ice_whelp", "jungle_wyvern",
	"lava_flan", "mesa_golem", "mirefolk", "oerkki", "poacher", "rift_spawn",
	"skeleton_archer", "skeleton_raider", "stone_golem", "storm_whelp",
	"war_construct", "wisp",
})

-- Settlement and faction NPCs, by role name.
local NPC_ROLES = {"^guard_", "^royal_guard_", "^king_", "^villager_",
	"^elder_", "^captain_", "^general_", "^bodyguard_", "^land_guard$"}

local function role_of(name)
	return type(name) == "string" and name:match("^grug_mobs:(.+)$") or nil
end

-- The base role of an entity name and its family: a sub-type answers with its
-- base mob's role and its own family, any other mob with its own role twice.
-- nil for anything grug_mobs did not register.
function C.base_and_family(name, subtype_of)
	local role = role_of(name)
	if not role then
		return nil
	end
	local sub = subtype_of and subtype_of(name)
	if sub then
		return role_of(sub.base) or role, sub.family or role
	end
	return role, role
end

-- "animal", "zombie" or nil.
function C.class_of(base)
	if C.ANIMALS[base] then
		return "animal"
	elseif C.ZOMBIES[base] then
		return "zombie"
	end
	return nil
end

local function is_npc_role(base)
	for _, pattern in ipairs(NPC_ROLES) do
		if base:find(pattern) then
			return true
		end
	end
	return false
end

-- The entity names among `names` whose base is in no list and is no NPC
-- role, sorted.
function C.unclassified(names, subtype_of)
	local out = {}
	for _, name in ipairs(names) do
		local base = C.base_and_family(name, subtype_of)
		if base and not (C.ANIMALS[base] or C.ZOMBIES[base] or C.OTHERS[base]
				or is_npc_role(base)) then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

return C
