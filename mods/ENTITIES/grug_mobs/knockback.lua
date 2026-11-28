--
-- How hard a mob's hit pushes a player (Round 88 ruling 7, combat_stats.md §3
-- "Knockback on players"): the weight class of its family, never its damage
-- or its level. grug_core/knockback.lua owns the speeds of the four classes,
-- the elite factor, the window and the direction; this file names each mob's
-- class and installs the seam grug_core.mob_knockback. Order:
--   1. a boss, one by one (BOSSES, the kings and Generals by name);
--   2. a named rare, one by one (RARES, by its rare id), its tier's factor none;
--   3. a critter pushes nothing;
--   4. the family's class (FAMILIES), times the elite factor for an elite.
-- A mob of no listed family (the guards of every kind, a captain, a
-- commander, a bodyguard) pushes `medium`: a person's push.
-- Mob-on-mob knockback is separation.lua's.
--

local K = grug_core.KNOCKBACK

-- family (grug_mobs.family_of, or the family of a base's sub-types) -> class.
local FAMILIES = {
	-- Small, light or bodiless: no push. The critters never attack.
	bog_fowl = "none", bone_weevil = "none", cave_bat = "none",
	cave_crawler = "none", gull = "none", hare = "none", parrot = "none",
	rabbit = "none", song_bird = "none", wild_turkey = "none",
	reed_angelfish = "none", goby = "none",
	crow = "none", blood_bat = "none", riftwing = "none", frog = "none",
	weevil = "none", spiderling = "none",
	-- An ooze's aura ticks every second; a wisp has no body.
	ooze = "none", wisp = "none", ember_wisp = "none", glowwing = "none",
	-- Light: small bodies and light frames.
	rat = "light", fox = "light", poison_small = "light", goblin = "light",
	goblin_miner = "light", goblin_miner_slinger = "light",
	goblin_hound = "light", raptor_bird = "light", crab = "light",
	stingray = "light", skeleton = "light", tortoise = "light",
	plains_runner = "light", lava_flan = "light", crystal_shard = "light",
	rift_spawn = "light",
	-- Medium: a person or a large dog or deer.
	wolf = "medium", hyena = "medium", cat = "medium", outlaw = "medium",
	zombie = "medium", mirefolk = "medium", spider = "medium",
	serpent = "medium", stag = "medium", ibex = "medium", tapir = "medium",
	zebra = "medium", boar = "medium", jungle_boar = "medium",
	plague_boar = "medium", oerkki = "medium", bay_shark = "medium",
	ice_whelp = "medium", storm_whelp = "medium", dungeon_master = "medium",
	-- Heavy: big and heavy.
	bear = "heavy", ape = "heavy", tiger = "heavy", crocodile = "heavy",
	treant = "heavy", golem = "heavy", construct = "heavy", ram = "heavy",
	abyssal_shark = "heavy", land_guard = "heavy",
}
local DEFAULT = "medium"

-- Bosses, one by one: entity name -> class and whether the elite factor applies.
local BOSSES = {
	["grug_mobs:ice_dragon"] = {"heavy", elite = true},
	["grug_mobs:jungle_wyvern"] = {"heavy", elite = true},
	["grug_mobs:kraken"] = {"heavy", elite = true},
	["grug_mobs:rift_boss"] = {"heavy", elite = true},
	-- The Expeditions' bosses (their templates' boss markers).
	["grug_mobs:duewarden"] = {"heavy", elite = true},
	["grug_mobs:flintback"] = {"heavy", elite = true},
	["grug_mobs:auditor_nemm"] = {"medium", elite = true},
}
-- Every King and both Generals (bosses.lua).
local ROYAL = {"heavy", elite = true}

-- Named rares, one by one: rare id (rares.lua) -> class.
local RARES = {
	grimtusk = "heavy", ashmaw = "heavy", old_whitefang = "heavy",
	marrowclaw = "heavy", korgans_bane = "heavy", emerald_coil = "heavy",
	silkfang = "medium", dustwing = "medium",
	bonerattle_south = "medium", bonerattle_north = "medium",
}

grug_mobs.KNOCKBACK_FAMILIES = FAMILIES
grug_mobs.KNOCKBACK_BOSSES = BOSSES
grug_mobs.KNOCKBACK_RARES = RARES

local function role_of(name)
	return name:match("^grug_mobs:(.+)$") or name
end

-- base role -> the family its sub-types name (a base is its own family
-- otherwise: grug_mobs.family_of("grug_mobs:jungle_ape") is "jungle_ape", its
-- sub-types' "ape"). Built on the first miss, after every sub-type registered.
local base_family

local function family_class(name)
	local class = FAMILIES[grug_mobs.family_of(name)]
	if class then return class end
	if not base_family then
		base_family = {}
		for _, sub in pairs(grug_mobs.subtypes or {}) do
			base_family[role_of(sub.base)] = sub.family
		end
	end
	local family = base_family[role_of(name)]
	return family and FAMILIES[family] or DEFAULT
end

local boss_rows = {} -- entity name -> its boss row, or false

local function boss_row(name)
	local row = boss_rows[name]
	if row == nil then
		row = BOSSES[name] or ((name:match("^grug_mobs:king_")
			or name:match("^grug_mobs:general_")) and ROYAL) or false
		boss_rows[name] = row
	end
	return row or nil
end

local classes = {} -- entity name -> its family's class

-- The class name of a mob's own hit, ignoring a rare's or an elite's tier.
function grug_mobs.knockback_class(name)
	local row = boss_row(name)
	if row then return row[1] end
	local class = classes[name]
	if not class then
		class = family_class(name)
		classes[name] = class
	end
	return class
end

-- m/s of the push a hit of `ent` carries.
function grug_mobs.knockback_speed(ent)
	local name = ent and ent.name
	if type(name) ~= "string" then return 0 end
	local row = boss_row(name)
	if row then
		return K[row[1]] * (row.elite and K.elite or 1)
	end
	local rare = ent._grug_rare_id and RARES[ent._grug_rare_id]
	if rare then return K[rare] end
	local tier = ent._grug_tier
	if tier == "critter" then return 0 end
	local speed = K[grug_mobs.knockback_class(name)]
	return tier == "elite" and speed * K.elite or speed
end

grug_core.mob_knockback = grug_mobs.knockback_speed
