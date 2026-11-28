-- Round 88 lane GATHER portable test (LuaJIT): gathering in enemy home
-- territory (round88-plan.md §2.6). Loads the shipped grug_core/protection.lua,
-- grug_gathering/territory.lua with the real gathering catalogue, and
-- grug_housing/protection.lua on top, over a stub of the zone policy that
-- answers as wp40/zones.lua, its guild-room and functional-column wrappers
-- and the road and POI layer do (zone_authority.lua). The node population is
-- the real one: the twelve catalogue sources and the wild sources of
-- wp40/world_content_catalog.lua (grug_mapgen/world_nodes.lua gives every one
-- the group grug_gathering_source), the apple and the ripe blueberry bush.
-- The ground plants and their near misses are stubs with the groups,
-- buildable_to and drop of their registrations (default/nodes.lua,
-- grug_nodes/init.lua and plants.lua, grug_trees/init.lua,
-- grug_mapgen/world_nodes.lua); each on_dig and on_punch stands for builtin's
-- and asks protection as builtin does, under the wrappers the first server
-- step installs. Prints the allowed list and
-- "R88 GATHER PORTABLE PASS checks=<n>".
--
--   luajit tools/r88_gather/portable_test.lua [REPO]
--
--   A  allowed nodes in enemy home territory, for both factions
--   B  refused nodes there (trees, leaves, a bare bush, ores, stone, soil,
--      decoration plants), with the territory hint; placing refused
--   C  every other refusal kind still refuses an allowed node, with its hint:
--      road, bridge, settlement core, town, landmark, guild room, open sea,
--      protected water, no faction, before the zone authority
--   D  own territory and contested land unchanged; a claim refuses; bypass
--   E  ground plants (Round 88 follow-up, the user): grass, ferns, flowers and
--      their kin dug and punched (no hint) there; placing into a buildable_to
--      plant refused, also during a dig at another position; decoration
--      leaves, corals, water plants, hanging plants, saplings and torches
--      refused; the other refusal kinds and a claim refuse a plant
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
local world_content = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/world_content_catalog.lua")

-- ---- the node population ----------------------------------------------------
local registered_nodes = {air = {groups = {}, buildable_to = true}}
local inner -- what the innermost on_dig / on_punch saw: protected, and the hint
local probe_pos -- a second position the innermost on_dig also asks about
local function node(name, groups, extra)
	local def = {groups = groups or {}}
	for field, value in pairs(extra or {}) do def[field] = value end
	-- builtin's node_dig and node_punch, as far as protection goes
	def.on_dig = function(pos, _, digger)
		local who = digger:get_player_name()
		inner = {protected = core.is_protected(pos, who),
			other = probe_pos and core.is_protected(probe_pos, who)}
		return not inner.protected
	end
	def.on_punch = function(pos, _, puncher)
		inner = {hint = grug_core.protection_hint(pos, puncher:get_player_name())}
	end
	registered_nodes[name] = def
end
local SOURCES = {}
for _, row in ipairs(catalog.p9g_sources()) do
	node(row.source_node, {grug_gathering_source = 1, snappy = 3})
	SOURCES[#SOURCES + 1] = row.source_node
end
for _, row in ipairs(world_content.plants) do
	node(row.node, {grug_gathering_source = 1, snappy = 3})
	SOURCES[#SOURCES + 1] = row.node
end
node("default:apple", {fleshy = 3, dig_immediate = 3, food_apple = 1})
node("default:blueberry_bush_leaves_with_berries", {snappy = 3, leaves = 1, dig_immediate = 3})
SOURCES[#SOURCES + 1] = "default:apple"
SOURCES[#SOURCES + 1] = "default:blueberry_bush_leaves_with_berries"
local REFUSED = {
	"default:tree", "default:leaves", "default:jungletree", "grug_trees:gravewood_tree",
	"default:blueberry_bush_leaves", "default:stone", "default:stone_with_iron",
	"default:dirt", "default:dirt_with_grass", "default:sand",
}
for _, name in ipairs(REFUSED) do node(name, {}) end
-- The ground plants (buildable_to unless named) and their near misses.
local B = {buildable_to = true}
local PLANTS = {
	{"default:grass_1", {flora = 1, attached_node = 1, grass = 1}, B},
	{"default:grass_3", {flora = 1, attached_node = 1, grass = 1, not_in_creative_inventory = 1},
		{buildable_to = true, drop = "default:grass_1"}},
	{"default:dry_grass_2", {flora = 1, attached_node = 1, dry_grass = 1}, B},
	{"default:junglegrass", {flora = 1, attached_node = 1, grass = 1}, B},
	{"default:fern_1", {flora = 1, attached_node = 1, fern = 1, grug_decor_plant = 1}, B},
	{"default:fern_2", {flora = 1, attached_node = 1, fern = 1}, {buildable_to = true,
		drop = "default:fern_1"}},
	{"default:marram_grass_1", {flora = 1, attached_node = 1, grug_decor_plant = 1}, B},
	{"default:dry_shrub", {snappy = 3, attached_node = 1}, B},
	{"grug_nodes:flower_ruby_fan", {attached_node = 1, grug_decor_plant = 1}, B},
	{"grug_nodes:alpine_cushion", {attached_node = 1, grug_decor_plant = 1}, B},
	{"grug_nodes:lichen_carpet", {attached_node = 3, grug_decor_plant = 1}, B},
	{"grug_nodes:lichen_carpet_b", {attached_node = 3, not_in_creative_inventory = 1},
		{buildable_to = true, drop = "grug_nodes:lichen_carpet"}},
	{"grug_nodes:moss_carpet", {attached_node = 3}, B},
	{"grug_nodes:cattails", {attached_node = 1}},
	{"grug_nodes:reeds", {snappy = 3}},
}
local NOT_PLANTS = {
	{"grug_trees:gravewood_leaves", {leaves = 1, leafdecay = 3, grug_decor_plant = 1}},
	{"grug_nodes:jungle_bush_leaves", {leaves = 1, grug_decor_plant = 1}},
	{"default:coral_brown", {cracky = 3, grug_decor_plant = 1}},
	{"grug_mapgen:seagrass_1", {snappy = 3, grug_decor_plant = 1}},
	{"grug_mapgen:seagrass_2", {snappy = 3}, {drop = "grug_mapgen:seagrass_1"}},
	{"grug_mapgen:freshwater_waterlily", {flora = 1, grug_decor_plant = 1}, B},
	{"grug_trees:liana", {leafdecay = 3, grug_decor_plant = 1}},
	{"default:sapling", {attached_node = 1, sapling = 1}},
	{"default:torch", {attached_node = 1, torch = 1}},
	{"grug_nodes:mud_with_reeds", {crumbly = 3}, {drop = "grug_nodes:mud"}},
}
for _, row in ipairs(PLANTS) do node(row[1], row[2], row[3]) end
for _, row in ipairs(NOT_PLANTS) do node(row[1], row[2], row[3]) end
check(#catalog.p9g_sources() == 12 and #world_content.plants == 15, "the catalogues' size")

-- ---- the world --------------------------------------------------------------
-- One column per kind of place, keyed by x: territory, hard kind, feature, water.
local PLACES = {
	throng_home = {x = 1, territory = "throng_home"},
	accord_home = {x = 2, territory = "accord_home"},
	contested = {x = 3, territory = "contested_land"},
	road = {x = 4, territory = "throng_home", feature = "road"},
	bridge = {x = 5, territory = "throng_home", feature = "bridge"},
	village = {x = 6, territory = "throng_home", feature = "village"},
	camp = {x = 7, territory = "throng_home", feature = "camp"},
	poi = {x = 8, territory = "throng_home", feature = "poi"},
	town = {x = 9, territory = "hard_protected", hard = "town"},
	landmark = {x = 10, territory = "hard_protected", hard = "landmark"},
	guild_room = {x = 11, territory = "hard_protected", hard = "guild_room"},
	sea = {x = 12, territory = "immutable", water = "deep_ocean"},
	bay = {x = 13, territory = "immutable", water = "bay"},
	claim = {x = 14, territory = "throng_home", claimed = true},
}
local BY_X = {}
for _, place in pairs(PLACES) do BY_X[place.x] = place end
local function at(kind, y) return {x = PLACES[kind].x, y = y or 10, z = 0} end
local function place_of(pos) return BY_X[pos.x] end

local nodes = {}
local function key(pos) return pos.x .. "/" .. pos.y .. "/" .. pos.z end
local installed = true
local FACTION = {ann = "accord", ben = "accord", tom = "throng", tia = "throng",
	nob = nil, admin = "accord"}

local loaded, later = {}, {}
_G.core = {
	registered_nodes = registered_nodes,
	get_node_or_nil = function(pos) return {name = nodes[key(pos)] or "air"} end,
	get_item_group = function(name, group)
		local def = registered_nodes[name]
		return def and def.groups[group] or 0
	end,
	check_player_privs = function(name, privs)
		return name == "admin" and privs.protection_bypass == true
	end,
	-- The engine's own handler under every wrapper: nothing protected.
	is_protected = function() return false end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_on_leaveplayer = function() end,
	after = function(_, fn) later[#later + 1] = fn end,
	log = function() end,
}
_G.grug_zones = {
	territory_rule_at = function(pos) return place_of(pos).territory end,
	hard_protection_kind_at = function(pos) return place_of(pos).hard end,
	water_class_at = function(x) return BY_X[x].water end,
}
-- zones.lua's compatibility.world_protected_for_faction (with its wrappers
-- answering "hard_protected") and zone_authority.lua's road and POI layer.
local function zone_policy(pos, faction)
	if faction ~= "accord" and faction ~= "throng" then return true end
	local territory = grug_zones.territory_rule_at(pos)
	if territory == "hard_protected" or territory == "immutable" then return true end
	if territory == "accord_home" then return faction ~= "accord" end
	if territory == "throng_home" then return faction ~= "throng" end
	return false
end
_G.grug_core = {
	zone_authority_installed = function() return installed end,
	get_player_faction = function(name) return FACTION[name] end,
	world_feature_at = function(pos) return place_of(pos).feature end,
	world_protected_for_faction = function(pos, faction)
		if not installed then return true end
		return zone_policy(pos, faction) or place_of(pos).feature ~= nil
	end,
}
dofile(repo .. "/mods/CORE/grug_core/protection.lua")
local grug_gathering_gatherable =
	dofile(repo .. "/mods/ITEMS/grug_gathering/territory.lua")(catalog)
-- grug_housing's wrapper over grug_core's: an active claim admits only its owner.
_G.grug_housing = {model = {
	protects = function(pos, name) return place_of(pos).claimed == true and name ~= "tia" end,
	arrival_cube_claim = function() return nil end,
	claim_at = function() return nil end,
}}
dofile(repo .. "/mods/PLAYER/grug_housing/protection.lua")
-- All mods loaded, then the first server step.
for _, fn in ipairs(loaded) do fn() end
for _, fn in ipairs(later) do fn() end

local function protected(kind, name, who)
	local pos = at(kind)
	nodes[key(pos)] = name
	return core.is_protected(pos, who)
end
local function hint(kind, name, who)
	local pos = at(kind)
	nodes[key(pos)] = name
	return grug_core.protection_hint(pos, who)
end

-- ---- A. allowed nodes in enemy home territory --------------------------------
for _, name in ipairs(SOURCES) do
	check(protected("throng_home", name, "ann") == false, "A an Accord player gathers " .. name)
	check(hint("throng_home", name, "ann") == nil, "A no hint for " .. name)
	check(protected("accord_home", name, "tom") == false, "A a Throng player gathers " .. name)
end

-- ---- B. refused nodes there; placing -----------------------------------------
for _, name in ipairs(REFUSED) do
	check(protected("throng_home", name, "ann") == true, "B " .. name .. " stays refused")
	check(hint("throng_home", name, "ann") == "Throng home territory – protected",
		"B the territory hint on " .. name)
	check(protected("accord_home", name, "tom") == true, "B " .. name .. " refused the other way")
end
check(protected("throng_home", "air", "ann") == true, "B placing into air refused")
check(hint("throng_home", "air", "ann") == "Throng home territory – protected",
	"B placing names the territory")
check(protected("accord_home", "air", "tom") == true, "B placing refused the other way")

-- ---- C. every other refusal kind still refuses an allowed node ---------------
local HERB = "grug_gathering:gravemoss_source"
local KINDS = {
	road = "Road – protected", bridge = "Bridge – protected",
	village = "Village – protected", camp = "Camp – protected",
	poi = "Point of interest – protected", town = "Town – protected",
	landmark = "Landmark – protected", guild_room = "Miner's Guild – protected",
	sea = "Open sea – protected", bay = "Deep water – protected",
}
for kind, text in pairs(KINDS) do
	for _, name in ipairs({HERB, "default:apple"}) do
		check(protected(kind, name, "ann") == true, "C " .. kind .. " refuses " .. name)
		check(protected(kind, name, "tom") == true, "C " .. kind .. " refuses its owners too")
		check(hint(kind, name, "ann") == text, "C " .. kind .. " keeps its hint")
	end
end
check(protected("throng_home", HERB, "nob") == true, "C no faction: refused")
check(hint("throng_home", HERB, "nob") == "Protected – choose a faction first", "C no faction hint")
check(protected("throng_home", HERB, "") == true, "C an empty actor: refused")
installed = false
check(protected("throng_home", HERB, "ann") == true, "C before the zone authority: refused")
check(protected("accord_home", HERB, "ann") == true, "C before the zone authority: own land too")
installed = true

-- ---- D. own territory, contested land, a claim, bypass -----------------------
for _, name in ipairs({HERB, "default:tree", "default:stone", "air"}) do
	check(protected("accord_home", name, "ann") == false, "D own territory: " .. name)
	check(protected("throng_home", name, "tom") == false, "D own territory, Throng: " .. name)
	check(protected("contested", name, "ann") == false, "D contested land: " .. name)
end
check(protected("claim", HERB, "ann") == true, "D a claim refuses the visitor's herb")
check(protected("claim", "default:apple", "ann") == true, "D a claim refuses the visitor's apple")
check(protected("claim", HERB, "tom") == true, "D a claim refuses a stranger of its faction")
check(protected("claim", HERB, "tia") == false, "D the claim's owner digs")
check(protected("claim", "default:tree", "ann") == true, "D a tree in a claim: refused")
check(protected("throng_home", "default:tree", "admin") == false, "D bypass unchanged")

-- ---- E. ground plants -------------------------------------------------------
local function player(name)
	return {is_player = function() return true end, get_player_name = function() return name end}
end
-- Digs (through the outermost on_dig) and returns what builtin's saw.
local function dig(kind, name, who, other)
	local pos = at(kind)
	nodes[key(pos)] = name
	probe_pos, inner = other, nil
	core.registered_nodes[name].on_dig(pos, {name = name}, player(who))
	probe_pos = nil
	return inner
end
local function punch(kind, name, who)
	local pos = at(kind)
	nodes[key(pos)] = name
	inner = nil
	core.registered_nodes[name].on_punch(pos, {name = name}, player(who))
	return inner.hint
end
for _, row in ipairs(PLANTS) do
	local name = row[1]
	check(grug_gathering_gatherable(name), "E " .. name .. " is a ground plant")
	check(dig("throng_home", name, "ann").protected == false, "E an Accord player digs " .. name)
	check(dig("accord_home", name, "tom").protected == false, "E a Throng player digs " .. name)
	check(punch("throng_home", name, "ann") == nil, "E no hint punching " .. name)
	if registered_nodes[name].buildable_to then
		check(protected("throng_home", name, "ann") == true, "E placing into " .. name .. " refused")
		check(hint("throng_home", name, "ann") == "Throng home territory – protected",
			"E placing into " .. name .. " names the territory")
	else
		check(protected("throng_home", name, "ann") == false, "E " .. name .. " is no placement target")
	end
	check(dig("road", name, "ann").protected == true, "E a road refuses " .. name)
	check(dig("town", name, "ann").protected == true, "E a town refuses " .. name)
	check(dig("claim", name, "ann").protected == true, "E a claim refuses " .. name)
	check(dig("throng_home", name, "nob").protected == true, "E no faction: " .. name)
	SOURCES[#SOURCES + 1] = name
end
-- A dig at one position opens no other: grass beside it takes no placement.
local beside = {x = PLACES.throng_home.x, y = 11, z = 0}
nodes[key(beside)] = "default:grass_1"
check(dig("throng_home", "default:fern_1", "ann", beside).other == true,
	"E digging one plant leaves the grass beside it refused")
check(protected("throng_home", "default:grass_1", "ann") == true, "E the context ends with the dig")
for _, row in ipairs(NOT_PLANTS) do
	local name = row[1]
	check(not grug_gathering_gatherable(name), "E " .. name .. " is no ground plant")
	check(dig("throng_home", name, "ann").protected == true, "E " .. name .. " stays refused")
	check(punch("throng_home", name, "ann") == "Throng home territory – protected",
		"E the territory hint punching " .. name)
end
check(dig("accord_home", "default:grass_1", "ann").protected == false and
	protected("accord_home", "default:grass_1", "ann") == false,
	"E own territory: grass dug and built into")

table.sort(SOURCES)
print("allowed in enemy home territory (" .. #SOURCES .. ", the ground plants as stubs):")
for _, name in ipairs(SOURCES) do print("  " .. name) end
print("R88 GATHER PORTABLE PASS checks=" .. checks)
