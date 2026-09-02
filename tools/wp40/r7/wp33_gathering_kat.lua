-- Focused LuaJIT development KAT for the R7-A registration/harvest package.

local root = assert(arg[1], "repository root missing")
local ffi = assert(rawget(_G, "wp40_ffi"), "injected LuaJIT FFI missing")
local sha256_factory = assert(loadfile(root ..
	"/tools/wp40/r6/sha256_stream.lua"))()
local sha256 = sha256_factory(ffi)

local function fail(message)
	error("WP33 gathering KAT: " .. message, 0)
end

local function check(value, message)
	if not value then fail(message) end
end

local function sha256_hex(bytes)
	local hasher = sha256.new()
	hasher.update(bytes)
	return hasher.final_hex()
end

local function raw_sha256(bytes)
	return (sha256_hex(bytes):gsub("..", function(pair)
		return string.char(tonumber(pair, 16))
	end))
end

local function load_in(path, environment)
	local chunk = assert(loadfile(path))
	setfenv(chunk, environment)
	return chunk()
end

local catalog_path = root .. "/mods/ITEMS/grug_gathering/catalog.lua"
local catalog = assert(loadfile(catalog_path))()
local manifest = catalog.manifest()
check(manifest.schema == "grug_wp33_gathering_catalog_v1", "manifest schema")
check(sha256_hex(manifest.canonical_bytes) == manifest.sha256,
	"manifest digest")
check(manifest.population.new_p9g_source == 12 and
	manifest.population.reuse_r6_source == 8 and
	manifest.population.r6_cultural_slot == 6, "manifest population")
for index = 1, #manifest.source_files do
	local source = manifest.source_files[index]
	check(sha256.file(root .. "/" .. source.path) == source.sha256,
		"source digest " .. source.path)
end

local p9g = catalog.p9g_sources()
local reuse = catalog.reuse_sources()
local cultural = catalog.cultural_sources()
check(#p9g == 12 and #reuse == 8 and #cultural == 6, "catalog arrays")
for _, rows in ipairs({p9g, reuse, cultural}) do
	for index = 2, #rows do
		check(rows[index - 1].id < rows[index].id, "catalog ASCII order")
	end
end
check(p9g[1].id == "wp33_corn_source_v1" and
	p9g[12].id == "wp33_wild_cocoa_source_v1", "P9G bounds")
check(reuse[1].id == "wp33_apple_r6_reuse_v1" and
	reuse[8].id == "wp33_spikethorn_acacia_r6_reuse_v1", "reuse bounds")
check(cultural[1].key == "gravesalt" and cultural[6].key == "sunwax",
	"cultural bounds")
local changed = catalog.p9g_sources()
changed[1].zones[1] = "mutated"
check(catalog.p9g_sources()[1].zones[1] == "elandor_ashenward_march",
	"catalog defensive copy")

local r6_factory = assert(loadfile(root ..
	"/mods/MAPGEN/grug_mapgen/wp40/r6.lua"))()
local r6_hash_factory = assert(loadfile(root ..
	"/mods/MAPGEN/grug_mapgen/wp40/r6_hash.lua"))()
local dummy_factory = function() return {} end
local r6 = r6_factory({
	r5_factory = dummy_factory,
	zones_factory = {},
	r5_planner_factory = {},
	r5_adapter_factory = {},
	manifest_module = {},
	allocator_factory = {},
	source = {},
	schemas = {},
	canonical = {},
	deterministic = {},
	index128 = {},
	horizontal_factory = {},
	height_factory = {},
	raw_sha256 = raw_sha256,
	hash_factory = r6_hash_factory,
	content_factory = dummy_factory,
	templates_factory = dummy_factory,
	planner_factory = {new = dummy_factory},
	settlement_factory = {new = dummy_factory},
})
local cultural_api = r6.cultural_slot_api()
local required_keys = cultural_api.required_keys()
local registrations = catalog.cultural_registrations()
for index = 1, #registrations do
	local registration = registrations[index]
	check(required_keys[index] == registration.cultural_key,
		"R6 cultural order")
	local checked, digest = cultural_api.validate(registration.cultural_key, {
		id = registration.id,
		template_or_simple_kind = registration.template_or_simple_kind,
		immutable_content = {cells = registration.cells},
		footprint_min_x = registration.footprint_min_x,
		footprint_max_x = registration.footprint_max_x,
		footprint_min_y = registration.footprint_min_y,
		footprint_max_y = registration.footprint_max_y,
		footprint_min_z = registration.footprint_min_z,
		footprint_max_z = registration.footprint_max_z,
		lower_two_policy = registration.lower_two_policy,
	})
	check(digest == registration.digest and checked.digest == registration.digest,
		"R6 cultural digest " .. registration.cultural_key)
end

local callbacks = {leave = {}, loaded = {}}
local registered_nodes, registered_items, registration_order = {}, {}, {}
for index = 1, #cultural do
	registered_items[cultural[index].raw_item] = {type = "craft"}
end
for index = 1, #reuse do
	for _, item_name in ipairs(reuse[index].source_items) do
		registered_items[item_name] = {type = "node"}
	end
	for _, item_name in ipairs(reuse[index].outputs) do
		registered_items[item_name] = {type = "node"}
	end
end
local now = 1000000
local engine = {
	registered_nodes = registered_nodes,
	registered_items = registered_items,
	get_current_modname = function() return "grug_gathering" end,
	get_modpath = function() return root .. "/mods/ITEMS/grug_gathering" end,
	sha256 = sha256_hex,
	get_us_time = function() now = now + 2000000 return now end,
	chat_send_player = function() end,
	register_node = function(name, definition)
		check(not registered_items[name], "duplicate node " .. name)
		registered_nodes[name], registered_items[name] = definition, definition
		registration_order[#registration_order + 1] = name
	end,
	register_craftitem = function(name, definition)
		check(not registered_items[name], "duplicate item " .. name)
		registered_items[name] = definition
	end,
	register_on_leaveplayer = function(callback)
		callbacks.leave[#callbacks.leave + 1] = callback
	end,
	register_on_mods_loaded = function(callback)
		callbacks.loaded[#callbacks.loaded + 1] = callback
	end,
	node_dig = function() return true end,
}
local materials = {
	TIERS = {{}, {}, {}, {}, {}, {}},
	tier_at = function() return 1 end,
	max_depth_for_pick_tier = function() return -100 end,
}
local environment = setmetatable({
	core = engine,
	grug_materials = materials,
	default = {
		node_sound_stone_defaults = function() return {} end,
		node_sound_leaves_defaults = function() return {} end,
	},
}, {__index = _G})
environment._G = environment
environment.dofile = function(path) return load_in(path, environment) end
load_in(root .. "/mods/ITEMS/grug_materials/mining.lua", environment)
load_in(root .. "/mods/ITEMS/grug_gathering/init.lua", environment)
for index = 1, #callbacks.loaded do callbacks.loaded[index]() end
check(#registration_order == 18, "source registration population")
for index = 1, 6 do
	check(registration_order[index] == cultural[index].source_node,
		"cultural registration order")
end
for index = 1, 12 do
	check(registration_order[index + 6] == p9g[index].source_node,
		"P9G registration order")
end
for index = 1, #p9g do
	local definition = registered_nodes[p9g[index].source_node]
	local groups = definition.groups
	check(definition.drop == p9g[index].raw_item and
		groups.grug_gathering_source == 1, "P9G source registration")
	if p9g[index].harvest_kind == "healing_herb" then
		check(groups.grug_healing_herb == p9g[index].required_group,
			"healing-herb group")
	elseif p9g[index].harvest_kind == "spice" then
		check(groups.grug_spice == p9g[index].required_group, "spice group")
	elseif p9g[index].harvest_kind == "food" then
		check(groups.grug_food == 1 and not groups.grug_found_only_food,
			"food group")
	else
		check(groups.grug_food == 1 and groups.grug_found_only_food == 1,
			"found-only group")
	end
end

local function stack(groups, empty)
	return {
		is_empty = function() return empty == true end,
		get_definition = function() return {groups = groups or {}} end,
	}
end
check(materials.tool_tier_for_stack(stack({pickaxe = 1, grug_pick_tier = 4}),
	"pick") == 4, "pick resolver")
local tier, reason = materials.tool_tier_for_stack(stack({axe = 1}), "axe")
check(tier == nil and reason == "tier_unavailable", "missing axe tier")
tier, reason = materials.tool_tier_for_stack(stack({axe = 1,
	grug_axe_tier = "4"}), "axe")
check(tier == nil and reason == "tier_unavailable", "string axe tier")
tier, reason = materials.tool_tier_for_stack(stack({pickaxe = 1}), "shovel")
check(tier == nil and reason == "wrong_family", "wrong resolver family")
check(not pcall(materials.tool_tier_for_stack, stack({}), "hammer"),
	"unknown resolver family")

local player = {
	is_player = function() return true end,
	get_player_name = function() return "tester" end,
	get_wielded_item = function(self) return self.wielded end,
	wielded = stack({}, true),
}
local herb_factory = load_in(root ..
	"/mods/ITEMS/grug_gathering/harvest.lua", environment)
local function herb_result(provider, row)
	local runtime = herb_factory({core = engine, materials = materials})
	if provider then runtime.register_herb_authorizer(provider) end
	return runtime.decision({x = 0, y = 2, z = 0}, player, row)
end
local gravemoss
for index = 1, #p9g do
	if p9g[index].key == "gravemoss" then gravemoss = p9g[index] end
end
local allowed, denial = herb_result(nil, gravemoss)
check(not allowed and denial == "profession_unavailable", "missing herb provider")
allowed, denial = herb_result(function() error("boom") end, gravemoss)
check(not allowed and denial == "profession_unavailable", "throwing herb provider")
allowed, denial = herb_result(function() return 1 end, gravemoss)
check(not allowed and denial == "profession_unavailable", "malformed herb provider")
allowed, denial = herb_result(function() return false, "no_alchemist" end,
	gravemoss)
check(not allowed and denial == "no_alchemist", "Alchemist denial")
allowed, denial = herb_result(function() return false, "book_group_locked" end,
	gravemoss)
check(not allowed and denial == "book_group_locked", "book denial")
allowed, denial = herb_result(function() return true, nil end, gravemoss)
check(allowed and denial == nil, "herb authorization")
local single = herb_factory({core = engine, materials = materials})
single.register_herb_authorizer(function() return true, nil end)
check(not pcall(single.register_herb_authorizer, function() return true, nil end),
	"second authorizer registration")

local cultural_runtime = herb_factory({core = engine, materials = materials})
local gravesalt = cultural[1]
environment.grug_zones = nil
allowed, denial = cultural_runtime.decision({x = 1, y = 2, z = 3}, player,
	gravesalt)
check(not allowed and denial == "zone_authority_unavailable", "missing zones")
local zone_calls, current_zone = 0, "ordinary_zone"
environment.grug_zones = {id_at = function(x, z)
	check(x == 1 and z == 3, "cultural zone query signature")
	zone_calls = zone_calls + 1
	return current_zone
end}
allowed, denial = cultural_runtime.decision({x = 1, y = 2, z = 3}, player,
	gravesalt)
check(allowed and denial == nil, "ordinary cultural harvest")
allowed, denial = cultural_runtime.decision({y = 2}, player, gravesalt)
check(not allowed and denial == "zone_authority_unavailable",
	"malformed cultural position")
current_zone = gravesalt.concentrated_zone
player.wielded = stack({shovel = 1, grug_shovel_tier = 4})
allowed, denial = cultural_runtime.decision({x = 1, y = 2, z = 3}, player,
	gravesalt)
check(not allowed and denial == "wrong_tool_family", "concentrated family")
player.wielded = stack({pickaxe = 1, grug_pick_tier = 3})
allowed, denial = cultural_runtime.decision({x = 1, y = 2, z = 3}, player,
	gravesalt)
check(not allowed and denial == "tool_tier_too_low", "concentrated tier")
player.wielded = stack({pickaxe = 1, grug_pick_tier = 7})
allowed, denial = cultural_runtime.decision({x = 1, y = 2, z = 3}, player,
	gravesalt)
check(not allowed and denial == "resolver_unavailable", "malformed tier")
player.wielded = stack({pickaxe = 1, grug_pick_tier = 4})
allowed, denial = cultural_runtime.decision({x = 1, y = 2, z = 3}, player,
	gravesalt)
check(allowed and denial == nil, "concentrated harvest")
check(zone_calls == 5, "cultural zone query count")

io.write("wp33_gathering_kat_v1\n")
io.write("manifest_sha256\t", manifest.sha256, "\n")
io.write("population\t12/8/6\n")
io.write("cultural_digests\t6\n")
io.write("registered_nodes\t18\n")
io.write("harvest_cases\tpass\n")
