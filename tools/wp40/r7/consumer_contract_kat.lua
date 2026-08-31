local root = assert(arg[1], "repository root argument required")

local function check(condition, message)
	if not condition then error(message, 2) end
end

local previous_calls = 0
core = {
	is_protected = function(pos, name)
		previous_calls = previous_calls + 1
		return name == "legacy"
	end,
	check_player_privs = function(name, wanted)
		return name == "bypass" and wanted.protection_bypass == true
	end,
}
grug_core = {
	get_player_faction = function(name)
		if name == "alice" or name == "bypass" or name == "legacy" then
			return "accord"
		elseif name == "thor" then
			return "throng"
		end
		return nil
	end,
}

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
	{"bonerattle_south", "front_broken_causeway", "rare_captain_bonerattle"},
	{"bonerattle_north", "front_shattered_line", "rare_captain_bonerattle"},
}
for i = 1, #rare_rows do
	local row = rare_rows[i]
	payload.rare_routes[i] = {id = row[1], anchor = ref(row[2], row[3]),
		patrol_offsets = offsets}
end

local anchors, zone_at_point, faction_at_point = {}, {}, {}
local anchor_ordinal = 0
local function add_anchor(anchor_ref, faction_id, numeric_id)
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
end
local race_source_ids = {
	dwarf = {1, 7}, human = {2, 8}, elf = {3, 9},
	undead = {4, 10}, orc = {5, 11}, troll = {6, 12},
}
for i = 1, #payload.races do
	local row = payload.races[i]
	add_anchor(row.start, row.faction_id, race_source_ids[row.race_id][1])
	add_anchor(row.capital, row.faction_id, race_source_ids[row.race_id][2])
end
for i = 1, #payload.outposts do
	local row = payload.outposts[i]
	add_anchor(row.anchor, row.faction_id, i + 24)
end
for i = 1, #payload.rare_routes do
	local row = payload.rare_routes[i]
	local faction = row.anchor.zone_id:match("^elandor_") and "accord" or
		(row.anchor.zone_id:match("^kragmar_") and "throng" or nil)
	add_anchor(row.anchor, faction, i + 90)
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
function session.biome_at(x, z) return "biome" end
function session.race_region_at(x, z) return "region" end
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
check(grug_core.outpost_patrol_target(outpost) == nil,
	"uncontracted outpost patrol relationship was invented")
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

grug_mobs = {}
dofile(root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")
-- User-ratified R7 rule: accepted node/biome whitelists own ordinary surface
-- habitat. The dispatcher retains only independent direct-authority gates and
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

local function read_file(relative)
	local handle = assert(io.open(root .. "/" .. relative, "rb"))
	local content = assert(handle:read("*a"))
	handle:close()
	return content
end

-- The accepted pre-R7 dispatcher had exactly 26 assignments covering its 27
-- definitions. R7 removes every old bucket assignment from those same files;
-- only four independent direct gates remain (two contested and two depth).
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
check(read_file("mods/ENTITIES/grug_mobs/spawn_policy.lua"):find(
	"grug_zones.pvp_rule_at", 1, true) ~= nil,
	"direct PvP authority is absent")
check(read_file("mods/ENTITIES/grug_mobs/kraken.lua"):find(
	"grug_zones.water_class_at", 1, true) ~= nil,
	"direct water authority is absent")
check(read_file("mods/ENTITIES/grug_mobs/bandit.lua"):find(
	"grug_zones.surface_mob_level_at", 1, true) ~= nil,
	"direct surface-level authority is absent")

io.write("R7_CONSUMER_KAT_V1\tPASS\n")
