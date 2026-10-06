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
-- and the Kraken (user ruling 2026-10-04).
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
	"lava_flan", "mesa_golem", "mirefolk", "oerkki", "poacher", "rift_boss", "rift_spawn",
	"skeleton_archer", "skeleton_raider", "stone_golem", "storm_whelp",
	"war_construct", "wisp",
})

-- Families an achievement counts, by base role (a sub-type joins its base's
-- family): kill:family:<family>.
C.FAMILIES = {
	boar = set({"boar", "plague_boar", "jungle_boar"}),
	rat = set({"giant_rat"}),
	skeleton = set({"skeleton_archer", "skeleton_raider", "frost_stray", "bog_witch"}),
	golem = set({"stone_golem", "mesa_golem"}),
	construct = set({"war_construct"}),
}

-- Named leaders by their own sub-type role: kill:group:<group>.
C.ROLE_GROUPS = {
	-- the six level-29 leaders outside the capitals
	final_notice = set({"ore_factor_brakk", "tollmaster_penn", "bough_counter_rusk",
		"mortuary_clerk_hush", "ration_broker_garr", "offering_broker_takka"}),
	-- the two level-58 leaders
	last_word = set({"watch_captain_huskell", "paymaster_chirr"}),
}

-- Named rares by their registry id (`_grug_rare_id`, rares.lua):
-- kill:rare:<group>.
C.RARE_GROUPS = {
	bonerattle = set({"bonerattle_south", "bonerattle_north"}),
}

-- Settlement and faction NPCs, by role name.
local NPC_ROLES = {"^guard_", "^royal_guard_", "^king_", "^villager_",
	"^elder_", "^captain_", "^commander_", "^general_", "^bodyguard_", "^land_guard$"}

local function role_of(name)
	return type(name) == "string" and name:match("^grug_mobs:(.+)$") or nil
end

-- The base role of an entity name: a sub-type answers with its base mob's
-- role, any other mob with its own. nil for anything grug_mobs did not
-- register.
function C.base_of(name, subtype_of)
	local role = role_of(name)
	if not role then
		return nil
	end
	local sub = subtype_of and subtype_of(name)
	if sub then
		return role_of(sub.base) or role
	end
	return role
end

-- The achievement family of a base role, or nil.
function C.family_of(base)
	for family, bases in pairs(C.FAMILIES) do
		if bases[base] then
			return family
		end
	end
	return nil
end

-- The role group of an entity's own role, or nil.
function C.role_group(name)
	local role = role_of(name)
	for group, roles in pairs(C.ROLE_GROUPS) do
		if role and roles[role] then
			return group
		end
	end
	return nil
end

-- The rare group of a rare registry id, or nil.
function C.rare_group(id)
	for group, ids in pairs(C.RARE_GROUPS) do
		if ids[id] then
			return group
		end
	end
	return nil
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
		local base = C.base_of(name, subtype_of)
		if base and not (C.ANIMALS[base] or C.ZOMBIES[base] or C.OTHERS[base]
				or is_npc_role(base)) then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

return C
