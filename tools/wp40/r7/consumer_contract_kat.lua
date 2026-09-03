local root = assert(arg[1], "repository root argument required")
local common = dofile(root .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()

local function check(condition, message)
	if not condition then error(message, 2) end
end

local previous_calls = 0
local saved_core, saved_grug_core, saved_grug_mobs = rawget(_G, "core"),
	rawget(_G, "grug_core"), rawget(_G, "grug_mobs")
rawset(_G, "core", {
	sha256 = function(bytes, raw)
		local digest = raw_sha256(bytes)
		return raw and digest or common.hex(digest)
	end,
	is_protected = function(pos, name)
		previous_calls = previous_calls + 1
		return name == "legacy"
	end,
	check_player_privs = function(name, wanted)
		return name == "bypass" and wanted.protection_bypass == true
	end,
})
rawset(_G, "grug_core", {
	get_player_faction = function(name)
		if name == "alice" or name == "bypass" or name == "legacy" then
			return "accord"
		elseif name == "thor" then
			return "throng"
		end
		return nil
	end,
})

dofile(root .. "/mods/CORE/grug_core/zone_authority.lua")
dofile(root .. "/mods/CORE/grug_core/protection.lua")
check(rawget(_G, "grug_zones") == nil, "authority published before validation")
check(grug_core.world_protected_for_faction({x = 0, y = 0, z = 0},
	"accord") == true, "pre-install protection did not fail closed")
check(core.is_protected({x = 0, y = 0, z = 0}, "alice") == true,
	"engine protection did not fail closed")
check(core.is_protected({x = 0, y = 0, z = 0}, "") == true,
	"empty actor protection changed")
local calls_before_bypass = previous_calls
check(core.is_protected({x = 0, y = 0, z = 0}, "bypass") == false and
	previous_calls == calls_before_bypass + 1, "bypass did not delegate")

local function ref(zone_id, slot_id)
	return {zone_id = zone_id, slot_id = slot_id}
end

local payload = {
	schema = "grug_wp40_r7_consumer_payload_v1",
	races = {
		{race_id = "dwarf", faction_id = "accord",
			start = ref("elandor_hearthpine_vale", "start"),
			capital = ref("elandor_dur_brannoc", "capital")},
		{race_id = "human", faction_id = "accord",
			start = ref("elandor_dawnmere_fields", "start"),
			capital = ref("elandor_highcourt", "capital")},
		{race_id = "elf", faction_id = "accord",
			start = ref("elandor_silverleaf_glades", "start"),
			capital = ref("elandor_lethariel", "capital")},
		{race_id = "undead", faction_id = "throng",
			start = ref("kragmar_stillgrave_hollow", "start"),
			capital = ref("kragmar_nhal_veyr", "capital")},
		{race_id = "orc", faction_id = "throng",
			start = ref("kragmar_sunscar_flats", "start"),
			capital = ref("kragmar_gor_drazhak", "capital")},
		{race_id = "troll", faction_id = "throng",
			start = ref("kragmar_kapok_cradle", "start"),
			capital = ref("kragmar_kezamba", "capital")},
	},
	outposts = {},
	rare_routes = {},
}

local outpost_rows = {
	{"dwarf", "accord", "elandor_copperfell_foothills", "outpost_1"},
	{"dwarf", "accord", "elandor_frostbarrow_shelf", "outpost_1"},
	{"dwarf", "accord", "elandor_stormvault_heights", "outpost_1"},
	{"dwarf", "accord", "elandor_stormvault_heights", "outpost_2"},
	{"human", "accord", "elandor_goldmead_vale", "outpost_1"},
	{"human", "accord", "elandor_whitebridge_shire", "outpost_1"},
	{"human", "accord", "elandor_ashenward_march", "outpost_1"},
	{"human", "accord", "elandor_ashenward_march", "outpost_2"},
	{"elf", "accord", "elandor_starbough_vale", "outpost_1"},
	{"elf", "accord", "elandor_lorindor", "outpost_1"},
	{"elf", "accord", "elandor_moonfall_wood", "outpost_1"},
	{"elf", "accord", "elandor_glassroot_wilds", "outpost_1"},
	{"undead", "throng", "kragmar_mournfen", "outpost_1"},
	{"undead", "throng", "kragmar_ossuary_reach", "outpost_1"},
	{"undead", "throng", "kragmar_blackwind_rise", "outpost_1"},
	{"undead", "throng", "kragmar_blackwind_rise", "outpost_2"},
	{"orc", "throng", "kragmar_redtusk_savanna", "outpost_1"},
	{"orc", "throng", "kragmar_speargrass_reach", "outpost_1"},
	{"orc", "throng", "kragmar_bannerbreak_mesa", "outpost_1"},
	{"orc", "throng", "kragmar_bannerbreak_mesa", "outpost_2"},
	{"troll", "throng", "kragmar_raincall_basin", "outpost_1"},
	{"troll", "throng", "kragmar_whispering_reedlands", "outpost_1"},
	{"troll", "throng", "kragmar_totemwater_reach", "outpost_1"},
	{"troll", "throng", "kragmar_thunderroot_wilds", "outpost_1"},
}
for i = 1, #outpost_rows do
	local row = outpost_rows[i]
	payload.outposts[i] = {race_id = row[1], faction_id = row[2],
		anchor = ref(row[3], row[4])}
end

local offsets = {{x = -48, z = -24}, {x = 16, z = 40}, {x = 56, z = -16}}
local rare_rows = {
	{"grimtusk", "elandor_goldmead_vale", "rare_grimtusk"},
	{"old_whitefang", "elandor_ashenward_march", "rare_old_whitefang"},
	{"korgans_bane", "elandor_stormvault_heights", "rare_korgans_bane"},
	{"silkfang", "front_skyglass_canopy", "rare_silkfang"},
	{"marrowclaw", "kragmar_blackwind_rise", "rare_marrowclaw"},
	{"dustwing", "kragmar_bannerbreak_mesa", "rare_dustwing"},
	{"emerald_coil", "front_stormscale_summit", "rare_emerald_coil"},
	{"ashmaw", "kragmar_redtusk_savanna", "rare_ashmaw"},
	{"bonerattle_north", "front_broken_causeway", "rare_captain_bonerattle"},
	{"bonerattle_south", "front_shattered_line", "rare_captain_bonerattle"},
}
for i = 1, #rare_rows do
	local row = rare_rows[i]
	payload.rare_routes[i] = {id = row[1], anchor = ref(row[2], row[3]),
		patrol_offsets = offsets}
end

-- Use the production-owned, source-derived payload for the actual authority
-- checks. The local rows above remain readable fixture documentation only.
payload = dofile(root ..
	"/mods/MAPGEN/grug_mapgen/wp40/r7_consumer_payload.lua")(
	dofile(root .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"),
	dofile(root .. "/mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua"),
	function(bytes) return core.sha256(bytes) end)

local anchors, zone_at_point, faction_at_point = {}, {}, {}
local biome_at_point, race_region_at_point = {}, {}
local anchor_ordinal = 0
local function add_anchor(anchor_ref, faction_id, numeric_id, race_id)
	local key = anchor_ref.zone_id .. "\0" .. anchor_ref.slot_id
	if anchors[key] then return end
	anchor_ordinal = anchor_ordinal + 1
	local x = 1000 + anchor_ordinal * 100
	local z = faction_id == "accord" and -1000 or 1000
	anchors[key] = {id = ("anchor_%03d"):format(numeric_id),
		numeric_id = numeric_id, slot_id = anchor_ref.slot_id,
		x = x, y = 20, z = z}
	zone_at_point[x .. "," .. z] = anchor_ref.zone_id
	faction_at_point[x .. "," .. z] = faction_id
	race_region_at_point[x .. "," .. z] = race_id
end
local race_source_ids = {
	dwarf = {1, 7}, human = {2, 8}, elf = {3, 9},
	undead = {4, 10}, orc = {5, 11}, troll = {6, 12},
}
for i = 1, #payload.races do
	local row = payload.races[i]
	add_anchor(row.start, row.faction_id, race_source_ids[row.race_id][1],
		row.race_id)
	add_anchor(row.capital, row.faction_id, race_source_ids[row.race_id][2],
		row.race_id)
end
local contested_outpost_zones = {
	elandor_stormvault_heights = true, elandor_ashenward_march = true,
	elandor_glassroot_wilds = true, kragmar_blackwind_rise = true,
	kragmar_bannerbreak_mesa = true, kragmar_thunderroot_wilds = true,
}
for i = 1, #payload.outposts do
	local row = payload.outposts[i]
	local coordinate_faction = row.faction_id
	if contested_outpost_zones[row.anchor.zone_id] then
		coordinate_faction = nil
	end
	add_anchor(row.anchor, coordinate_faction, i + 24, row.race_id)
end
for i = 1, #payload.rare_routes do
	local row = payload.rare_routes[i]
	local faction = row.anchor.zone_id:match("^elandor_") and "accord" or
		(row.anchor.zone_id:match("^kragmar_") and "throng" or nil)
	add_anchor(row.anchor, faction, i + 90, nil)
end

local session = {}
function session.get(id) return "get:" .. id end
function session.at(pos) return "at:" .. pos.x end
function session.neighbors(id) return {id} end
function session.travel_links(id) return {id} end
function session.anchor(zone_id, slot_id)
	local row = anchors[zone_id .. "\0" .. slot_id]
	if not row then return nil end
	local copy = {}
	for key, value in pairs(row) do copy[key] = value end
	return copy
end
function session.id_at(x, z) return zone_at_point[x .. "," .. z] end
function session.biome_at(x, z)
	return biome_at_point[x .. "," .. z] or "biome"
end
function session.race_region_at(x, z)
	return race_region_at_point[x .. "," .. z] or "region"
end
function session.faction_at(pos) return faction_at_point[pos.x .. "," .. pos.z] end
function session.territory_rule_at(pos)
	return pos.protected and "hard_protected" or "accord_home"
end
function session.pvp_rule_at(pos)
	return pos.z == 99 and "contested" or "peaceful"
end
function session.surface_mob_level_at(x, z)
	if x == 1 then return 3 elseif x == 2 then return 10 end
	return 30
end
function session.mob_level_at(pos) return 40 end
function session.guard_level_at(pos) return 60 end
function session.terrain_height_at(x, z) return 30 end
function session.water_class_at(x, z)
	if x == 100 then return "deep_ocean"
	elseif x == 101 then return "immutable_dragon_channel"
	elseif x == 102 then return "coastal_shelf" end
	return "land"
end
function session.nearest_route_at(x, z) return nil end
function session.nearest_hydrology_at(x, z) return nil end
function session.housing_eligible_at(x, z) return false end
session.compatibility = {
	surface_level_at = session.terrain_height_at,
	mob_level_at = session.mob_level_at,
	guard_level_at = session.guard_level_at,
	open_sea_at = function(pos)
		return session.water_class_at(pos.x, pos.z) == "deep_ocean"
	end,
	territory_at = function(pos) return session.faction_at(pos) or "ocean" end,
	zone_at = function(pos) return "compat" end,
	world_protected_for_faction = function(pos, faction_id)
		return pos.protected == true or faction_id ~= "accord"
	end,
}

check(not pcall(grug_core.install_zone_authority, session, {schema = "wrong"}),
	"malformed payload was accepted")
check(rawget(_G, "grug_zones") == nil, "failed validation published registry")
payload.rare_routes[1].patrol_offsets[1].x = -47
check(not pcall(grug_core.install_zone_authority, session, payload),
	"altered source patrol offset was accepted")
check(rawget(_G, "grug_zones") == nil,
	"failed exact-payload validation published registry")
payload.rare_routes[1].patrol_offsets[1].x = -48
check(grug_core.install_zone_authority(session, payload) == true,
	"valid authority did not install")

local public_methods = {"get", "at", "neighbors", "travel_links", "anchor",
	"id_at", "biome_at", "race_region_at", "faction_at",
	"territory_rule_at", "pvp_rule_at", "surface_mob_level_at",
	"mob_level_at", "guard_level_at", "terrain_height_at", "water_class_at",
	"nearest_route_at", "nearest_hydrology_at", "housing_eligible_at"}
for i = 1, #public_methods do
	check(type(grug_zones[public_methods[i]]) == "function",
		"public R4 method is absent")
end
check(grug_zones.not_public == nil, "unexpected public R4 method exists")
check(not pcall(function() grug_zones.get = false end),
	"public R4 registry was mutable")
check(grug_zones.get("zone") == "get:zone", "public get delegation differs")
check(grug_zones.at({x = 7, y = 0, z = 0}) == "at:7",
	"public at delegation differs")

local dwarf_start = grug_core.start_position("accord", "dwarf")
check(dwarf_start and dwarf_start.y == 21, "stable start position differs")
check(grug_core.start_position("throng", "dwarf") == nil,
	"foreign start position did not fail closed")
local first_outpost = anchors["elandor_copperfell_foothills\0outpost_1"]
local outpost = grug_core.outpost_at(first_outpost)
check(outpost and outpost.race == "dwarf", "stable outpost lookup differs")
local contested_dwarf = anchors["elandor_stormvault_heights\0outpost_1"]
local contested_undead = anchors["kragmar_blackwind_rise\0outpost_1"]
check(session.faction_at(contested_dwarf) == nil and
	session.faction_at(contested_undead) == nil and
	grug_core.outpost_at(contested_dwarf).faction == "accord" and
	grug_core.outpost_at(contested_undead).faction == "throng",
	"contested outpost garrison authority differs")
local patrol_target_slots = {2, 3, 4, 3}
for i = 1, #payload.outposts do
	local source_row = payload.outposts[i]
	local source_anchor = anchors[source_row.anchor.zone_id .. "\0" ..
		source_row.anchor.slot_id]
	local source = grug_core.outpost_at(source_anchor)
	local slot = (i - 1) % 4 + 1
	local target_index = i - slot + patrol_target_slots[slot]
	local target_row = payload.outposts[target_index]
	local expected_anchor = anchors[target_row.anchor.zone_id .. "\0" ..
		target_row.anchor.slot_id]
	local target = grug_core.outpost_patrol_target(source)
	check(target and target.id == expected_anchor.id and
		target.race == source.race and target.faction == source.faction and
		target.anchor.x == expected_anchor.x and
		target.anchor.y == expected_anchor.y and
		target.anchor.z == expected_anchor.z,
		"stable outpost patrol relation differs at row " .. i)
	local original_x = target.anchor.x
	target.anchor.x = original_x + 1
	check(grug_core.outpost_patrol_target(source).anchor.x == original_x,
		"outpost patrol target was not defensively copied")
end
check(grug_core.outpost_patrol_target(nil) == nil and
	grug_core.outpost_patrol_target({}) == nil,
	"invalid outpost patrol input did not fail closed")
local altered_outpost = grug_core.outpost_at(first_outpost)
altered_outpost.id = "anchor_unknown"
check(grug_core.outpost_patrol_target(altered_outpost) == nil,
	"unknown outpost patrol identity did not fail closed")
altered_outpost = grug_core.outpost_at(first_outpost)
altered_outpost.race = "human"
check(grug_core.outpost_patrol_target(altered_outpost) == nil,
	"altered outpost patrol race did not fail closed")
altered_outpost = grug_core.outpost_at(first_outpost)
altered_outpost.faction = "throng"
check(grug_core.outpost_patrol_target(altered_outpost) == nil,
	"altered outpost patrol faction did not fail closed")
altered_outpost = grug_core.outpost_at(first_outpost)
altered_outpost.anchor.x = altered_outpost.anchor.x + 1
check(grug_core.outpost_patrol_target(altered_outpost) == nil,
	"altered outpost patrol position did not fail closed")
outpost.anchor.x = 0
check(grug_core.outpost_at(first_outpost).anchor.x == first_outpost.x,
	"outpost authority was not defensively copied")

local grim_anchor = anchors["elandor_goldmead_vale\0rare_grimtusk"]
local grim_route = grug_core.rare_route("grimtusk")
check(#grim_route == 3 and grim_route[1].x == grim_anchor.x - 48 and
	grim_route[1].y == 31 and grim_route[1].z == grim_anchor.z - 24,
	"stable rare route projection differs")
grim_route[1].x = 0
check(grug_core.rare_route("grimtusk")[1].x == grim_anchor.x - 48,
	"rare route was not defensively copied")

check(core.is_protected({x = 0, y = 0, z = 0}, "alice") == false,
	"own mutable terrain did not delegate")
check(core.is_protected({x = 0, y = 0, z = 0, protected = true}, "alice") == true,
	"hard volume was not protected")
check(core.is_protected({x = 0, y = 0, z = 0}, "thor") == true,
	"foreign faction was not protected")
check(core.is_protected({x = 0, y = 0, z = 0}, "legacy") == true,
	"previous handler was not preserved")
check(not pcall(grug_core.install_zone_authority, session, payload),
	"second authority installation was accepted")

rawset(_G, "grug_mobs", {})
dofile(root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")
-- User-ratified R7 rule: named-zone content palettes and the accepted
-- node/biome whitelists jointly own ordinary surface habitat. The dispatcher
-- must not reconstruct core/inner/outer/coast buckets from mob levels.
check(grug_mobs.spawn_domain_at({x = 1, y = 0, z = 0}) == nil and
	grug_mobs.spawn_domain_at({x = 2, y = 0, z = 0}) == nil and
	grug_mobs.spawn_domain_at({x = 3, y = 0, z = 0}) == nil,
	"retired surface-level buckets were reconstructed")
check(grug_mobs.spawn_domain_at({x = 3, y = 0, z = 99}) == "contested",
	"contested domain differs")
check(grug_mobs.spawn_domain_at({x = 1, y = -41, z = 0}) == "underground",
	"underground boundary differs")
local domains = grug_mobs.compile_spawn_domains(
	{"contested", "underground"}, "fixture")
check(grug_mobs.spawn_domains_allow(domains, {x = 3, y = 0, z = 99}) and
	grug_mobs.spawn_domains_allow(domains, {x = 1, y = -41, z = 0}) and
	not grug_mobs.spawn_domains_allow(domains, {x = 2, y = 0, z = 0}),
	"spawn-domain set dispatch differs")
check(not pcall(grug_mobs.compile_spawn_domains,
	{"peaceful_1_5"}, "retired_fixture"),
	"retired surface-level domain was accepted")

local mob_fixture_ordinal = 0
local function mob_fixture(zone_id, biome_id, race_region, y)
	mob_fixture_ordinal = mob_fixture_ordinal + 1
	local x = 20000 + mob_fixture_ordinal
	local z = 21000
	local key = x .. "," .. z
	zone_at_point[key] = zone_id
	biome_at_point[key] = biome_id or "grug_meadows"
	race_region_at_point[key] = race_region or "human"
	return {x = x, y = y or 20, z = z}
end

local mob_families = {
	["grug_mobs:boar"] = {settled = true},
	["grug_mobs:plague_boar"] = {settled = true},
	["grug_mobs:jungle_boar"] = {settled = true},
	["grug_mobs:rabbit"] = {settled = true},
	["grug_mobs:hare"] = {settled = true},
	["grug_mobs:zombie"] = {settled = true, war = true},
	["grug_mobs:wolf"] = {forest = true},
	["grug_mobs:blightfang_wolf"] = {forest = true},
	["grug_mobs:bear"] = {forest = true},
	["grug_mobs:plaguehide_bear"] = {forest = true},
	["grug_mobs:stag"] = {forest = true},
	["grug_mobs:gaunt_stag"] = {forest = true},
	["grug_mobs:giant_spider"] = {forest = true},
	["grug_mobs:pale_spider"] = {forest = true},
	["grug_mobs:skeleton_archer"] = {forest = true, war = true},
	["grug_mobs:bone_weevil"] = {forest = true},
	["grug_mobs:crag_eagle"] = {mountain = true},
	["grug_mobs:vulture"] = {mountain = true},
	["grug_mobs:stone_golem"] = {mountain = true},
	["grug_mobs:mesa_golem"] = {mountain = true},
	["grug_mobs:mountain_ram"] = {mountain = true},
	["grug_mobs:hyena"] = {mountain = true, savanna = true},
	["grug_mobs:zebra"] = {savanna = true},
	["grug_mobs:jungle_lynx"] = {jungle_edge = true, jungle = true},
	["grug_mobs:panther"] = {jungle = true},
	["grug_mobs:serpent"] = {jungle = true},
	["grug_mobs:jungle_ape"] = {jungle = true},
	["grug_mobs:jungle_spider"] = {jungle = true},
	["grug_mobs:parrot"] = {jungle_edge = true},
	["grug_mobs:crocodile"] = {swamp = true},
	["grug_mobs:bog_ooze"] = {swamp = true},
	["grug_mobs:bog_fowl"] = {swamp = true},
	["grug_mobs:skeleton_raider"] = {war = true},
	["grug_mobs:carrion_crow"] = {war = true},
}
local zone_families = {
	elandor_hearthpine_vale = {settled = true},
	elandor_copperfell_foothills = {settled = true},
	elandor_dur_brannoc = {},
	elandor_frostbarrow_shelf = {mountain = true},
	elandor_stormvault_heights = {mountain = true},
	elandor_dawnmere_fields = {settled = true},
	elandor_goldmead_vale = {settled = true},
	elandor_highcourt = {},
	elandor_whitebridge_shire = {settled = true, forest = true},
	elandor_ashenward_march = {forest = true, war = true},
	elandor_silverleaf_glades = {settled = true},
	elandor_starbough_vale = {settled = true},
	elandor_lethariel = {},
	elandor_lorindor = {},
	elandor_moonfall_wood = {forest = true},
	elandor_glassroot_wilds = {forest = true, jungle = true},
	kragmar_stillgrave_hollow = {settled = true},
	kragmar_mournfen = {settled = true, swamp = true},
	kragmar_nhal_veyr = {},
	kragmar_ossuary_reach = {forest = true},
	kragmar_blackwind_rise = {forest = true},
	kragmar_sunscar_flats = {settled = true},
	kragmar_redtusk_savanna = {settled = true, savanna = true},
	kragmar_gor_drazhak = {},
	kragmar_speargrass_reach = {savanna = true, mountain = true},
	kragmar_bannerbreak_mesa = {mountain = true, war = true},
	kragmar_kapok_cradle = {settled = true, jungle_edge = true},
	kragmar_raincall_basin = {settled = true, jungle_edge = true},
	kragmar_kezamba = {},
	kragmar_whispering_reedlands = {jungle_edge = true, swamp = true},
	kragmar_totemwater_reach = {jungle_edge = true, swamp = true},
	kragmar_thunderroot_wilds = {jungle = true},
	front_wyrmglass_crown = {mountain = true, war = true},
	front_gravesalt_escarpment = {forest = true, war = true},
	front_broken_causeway = {war = true},
	front_shattered_line = {mountain = true, war = true},
	front_skyglass_canopy = {jungle = true, war = true},
	front_stormscale_summit = {jungle = true, war = true},
}
local zone_count, war_count, mob_count = 0, 0, 0
for _ in pairs(mob_families) do mob_count = mob_count + 1 end
for zone_id, expected in pairs(zone_families) do
	zone_count = zone_count + 1
	if expected.war then war_count = war_count + 1 end
	local pos = mob_fixture(zone_id)
	for mob_name, families in pairs(mob_families) do
		local allowed = zone_id == "elandor_lorindor" and
			mob_name == "grug_mobs:stag"
		if not allowed then
			for family in pairs(families) do
				if expected[family] then allowed = true; break end
			end
		end
		check(grug_mobs.spawn_policy_allows(mob_name, pos) == allowed,
			"named-zone mob mapping differs for " .. zone_id .. ":" ..
			mob_name)
	end
end
check(zone_count == 38, "named-zone mob-palette population differs")
check(war_count == 8, "explicit war-palette population differs")
check(mob_count == 34, "surface mob-palette population differs")

local lorindor = mob_fixture("elandor_lorindor")
check(grug_mobs.spawn_policy_allows("grug_mobs:stag", lorindor) and
	not grug_mobs.spawn_policy_allows("grug_mobs:gaunt_stag", lorindor) and
	not grug_mobs.spawn_policy_allows("grug_mobs:wolf", lorindor) and
	not grug_mobs.spawn_policy_allows("grug_mobs:bear", lorindor),
	"Lorindor's exact pale-stag palette differs")

local beach = mob_fixture("elandor_dur_brannoc", "grug_beach")
local inland = mob_fixture("front_wyrmglass_crown", "grug_crags", "dwarf")
check(grug_mobs.spawn_policy_allows("grug_mobs:gull", beach) and
	not grug_mobs.spawn_policy_allows("grug_mobs:boar", beach) and
	not grug_mobs.spawn_policy_allows("grug_mobs:gull", inland),
	"universal beach Gull authority differs")

local cave_mobs = {
	"grug_mobs:zombie", "grug_mobs:giant_spider",
	"grug_mobs:stone_golem", "grug_mobs:mesa_golem",
	"grug_mobs:cave_bat", "grug_mobs:cave_crawler",
}
local cave = mob_fixture("elandor_dur_brannoc", nil, "human", -41)
for i = 1, #cave_mobs do
	check(grug_mobs.spawn_policy_allows(cave_mobs[i], cave),
		"cave roster rejected " .. cave_mobs[i])
end
local cave_boundary = mob_fixture("elandor_dur_brannoc", nil, "human", -40)
check(not grug_mobs.spawn_policy_allows("grug_mobs:cave_bat", cave_boundary) and
	not grug_mobs.spawn_policy_allows("grug_mobs:wolf", cave) and
	not grug_mobs.spawn_policy_allows("grug_mobs:unknown", cave),
	"closed cave roster or strict y < -40 boundary differs")

local race_factions = {
	dwarf = "accord", human = "accord", elf = "accord",
	undead = "throng", orc = "throng", troll = "throng",
}
for race_region, faction in pairs(race_factions) do
	local pos = mob_fixture("front_wyrmglass_crown", nil, race_region)
	check(grug_mobs.race_region_spawn_allows(faction, pos) and
		not grug_mobs.race_region_spawn_allows(
			faction == "accord" and "throng" or "accord", pos),
		"race-region mob side differs for " .. race_region)
end
check(not grug_mobs.spawn_policy_allows("grug_mobs:unknown",
	mob_fixture("unknown_zone")), "unknown surface mob/zone did not fail closed")

local function read_file(relative)
	local handle = assert(io.open(root .. "/" .. relative, "rb"))
	local content = assert(handle:read("*a"))
	handle:close()
	return content
end

-- The accepted pre-R7 dispatcher had exactly 26 assignments covering its 27
-- definitions. R7 removes every old bucket assignment from those same files;
-- four direct narrowing gates remain (two contested and two depth) in addition
-- to the common named-zone policy.
local migrated_spawn_files = {
	"bear.lua", "boar.lua", "boar_variants.lua", "bog_ooze.lua",
	"carrion_crow.lua", "cave_bat.lua", "cave_crawler.lua", "crocodile.lua",
	"eagle.lua", "golem.lua", "gull.lua", "hyena.lua", "jungle_ape.lua",
	"jungle_lynx.lua", "panther.lua", "parrot.lua", "rabbit.lua", "ram.lua",
	"serpent.lua", "skeleton_archer.lua", "skeleton_raider.lua", "spider.lua",
	"stag.lua", "wolf.lua", "zebra.lua", "zombie.lua",
}
local direct_gate_count = 0
for i = 1, #migrated_spawn_files do
	local content = read_file("mods/ENTITIES/grug_mobs/" ..
		migrated_spawn_files[i])
	check(not content:find("_grug_spawn_zones", 1, true),
		"legacy spawn-zone field remains in " .. migrated_spawn_files[i])
	for body in content:gmatch("_grug_spawn_domains%s*=%s*{(.-)}") do
		direct_gate_count = direct_gate_count + 1
		check(not body:match('"core"') and not body:match('"inner"') and
			not body:match('"outer"') and not body:match('"coast"') and
			not body:match('"war_coast"') and not body:match('"strait"'),
			"retired ring gate remains in " .. migrated_spawn_files[i])
	end
end
check(direct_gate_count == 4, "direct spawn-gate population differs")
check(read_file("mods/ENTITIES/grug_mobs/skeleton_archer.lua"):find(
	'grug_mobs.zone_spawn_palette_allows("war", pos)', 1, true),
	"Skeleton Archer generic row does not use explicit war authority")
check(read_file("mods/ENTITIES/grug_mobs/spawn_policy.lua"):find(
	"grug_zones.pvp_rule_at", 1, true) ~= nil,
	"direct PvP authority is absent")
check(read_file("mods/ENTITIES/grug_mobs/kraken.lua"):find(
	"grug_zones.water_class_at", 1, true) ~= nil,
	"direct water authority is absent")
check(read_file("mods/ENTITIES/grug_mobs/bandit.lua"):find(
	"grug_zones.surface_mob_level_at", 1, true) ~= nil,
	"direct surface-level authority is absent")

rawset(_G, "core", saved_core)
rawset(_G, "grug_core", saved_grug_core)
rawset(_G, "grug_mobs", saved_grug_mobs)
io.write("R7_CONSUMER_KAT_V1\tPASS\n")
