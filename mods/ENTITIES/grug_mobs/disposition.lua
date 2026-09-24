-- Fixed family disposition used by combat behavior and DISPLAY. A disposition
-- describes what the family does before combat; it never varies by position,
-- current target, faction or tier promotion.

local DISPOSITIONS = {}

local function classify(disposition, names)
	for i = 1, #names do
		local name = "grug_mobs:" .. names[i]
		if DISPOSITIONS[name] then
			error("[grug_mobs] duplicate disposition for " .. name)
		end
		DISPOSITIONS[name] = disposition
	end
end

classify("critter", {
	"bog_fowl", "bone_weevil", "cave_bat", "cave_crawler", "gull",
	"hare", "parrot", "plains_runner", "rabbit", "song_bird",
	"wild_turkey", "reed_angelfish",
})

classify("neutral", {
	"boar", "carrion_crow", "gaunt_stag", "ibex", "jungle_boar",
	"mountain_ram", "plague_boar", "reef_lurker", "shore_crab", "stag",
	"tapir", "zebra",
})

classify("aggressive", {
	"ashen_treant", "bandit", "bandit_archer", "bear", "blightfang_wolf",
	"blood_bat", "bog_ooze", "bog_witch", "crag_eagle", "crocodile",
	"crystal_shard", "dungeon_master", "ember_wisp", "fox", "frost_stray",
	"giant_rat", "giant_spider", "glowwing", "goblin_hound",
	"goblin_miner", "goblin_miner_slinger", "goblin_raider",
	"goblin_slinger", "gravewood_treant", "hyena", "ice_dragon",
	"ice_whelp", "jungle_ape", "jungle_lynx", "jungle_spider",
	"jungle_wyvern", "kraken", "lava_flan", "mesa_golem", "mirefolk",
	"oerkki", "pale_spider", "panther", "plaguehide_bear", "poacher", "rift_spawn",
	"scorpion", "serpent", "skeleton_archer", "skeleton_raider",
	"snow_leopard", "speargrass_tiger", "spiderling", "stone_golem",
	"stone_mite", "storm_whelp", "sun_dried_husk", "viper", "vulture",
	"war_construct", "wisp", "wolf", "zombie",
})

local function role_disposition(name)
	if name:match("^grug_mobs:king_") then return "aggressive" end
	-- Guards and royal guards are DISPLAY's guard role, independent of ambient
	-- creature disposition. Peaceful settlement residents bypass this wrapper.
	if name == "grug_mobs:guard_accord" or name == "grug_mobs:guard_throng"
			or name == "grug_mobs:land_guard"
			or name:match("^grug_mobs:royal_guard_") then
		return nil
	end
	return DISPOSITIONS[name]
end

function grug_mobs.disposition(subject)
	if type(subject) == "string" then
		return role_disposition(subject)
	end
	if type(subject) == "table" then
		return subject._grug_disposition or role_disposition(subject.name or "")
	end
	if type(subject) == "userdata" and subject.get_luaentity then
		local entity = subject:get_luaentity()
		return entity and (entity._grug_disposition
			or role_disposition(entity.name or "")) or nil
	end
	return nil
end

function grug_mobs.apply_disposition(name, def)
	local disposition = role_disposition(name)
	if not disposition then
		if name == "grug_mobs:guard_accord" or name == "grug_mobs:guard_throng"
				or name == "grug_mobs:land_guard"
				or name:match("^grug_mobs:royal_guard_") then
			return nil
		end
		error("[grug_mobs] missing fixed disposition for " .. name)
	end

	def._grug_disposition = disposition
	if disposition == "neutral" then
		-- mobs_redo's passive=true cannot retaliate. These fields suppress
		-- acquisition while retaining its normal punch retaliation path.
		def.passive = false
		def.attack_players = false
		def.attack_npcs = false
		def.runaway = false
		def.group_attack = false
		def.attack_type = def.attack_type or "dogfight"
	elseif disposition == "critter" then
		if def._grug_tier ~= "critter" then
			error("[grug_mobs] critter disposition without critter tier: " .. name)
		end
		def.passive = true
		def.attack_players = false
		def.attack_npcs = false
		def.runaway = true
	else
		def.passive = false
		def.attack_players = true
		def.runaway = false
	end
	return disposition
end
