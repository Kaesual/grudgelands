local root = assert(arg[1], "repo root required")
local callbacks = {}
local stored = ""
local now = 1000
local nodes = {}
local meta = {}
local alterable = true
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local old_time, old_random = os.time, math.random
os.time = function() return now end
math.random = function(a) return a end

core = {
	registered_nodes = {},
	get_modpath = function(name)
		local paths = {grug_mapgen = root .. "/mods/MAPGEN/grug_mapgen",
			grug_gathering = root .. "/mods/ITEMS/grug_gathering"}
		return paths[name]
	end,
	get_mod_storage = function()
		return {get_string = function() return stored end,
			set_string = function(_, _, value) stored = value end}
	end,
	serialize = function(value) return value end,
	deserialize = function(value) return value end,
	register_on_mods_loaded = function(fn) callbacks.loaded = fn end,
	register_on_generated = function(fn) callbacks.generated = fn end,
	register_on_placenode = function(fn) callbacks.placed = fn end,
	register_globalstep = function(fn) callbacks.step = fn end,
	register_lbm = function(def) callbacks.lbm = def end,
	override_item = function(name, def)
		for field, value in pairs(def) do core.registered_nodes[name][field] = value end
	end,
	get_meta = function(pos)
		local values = meta[key(pos)] or {}
		meta[key(pos)] = values
		return {get_int = function(_, name) return values[name] or 0 end,
			set_int = function(_, name, value) values[name] = value end}
	end,
	find_nodes_in_area = function() return {{x = 1, y = 2, z = 1}} end,
	get_node = function(pos) return {name = nodes[key(pos)] or "air"} end,
	get_node_or_nil = function(pos) return {name = nodes[key(pos)] or "air"} end,
	set_node = function(pos, node) nodes[key(pos)] = node.name end,
	get_connected_players = function()
		local players = {}
		for index = 1, 100 do
			players[index] = {get_pos = function() return {x = 1, y = 2, z = 1} end}
		end
		return players
	end,
	get_biome_data = function() return {biome = 1} end,
	get_biome_name = function() return "grug_meadows" end,
	get_item_group = function(name, group)
		return ((core.registered_nodes[name] or {}).groups or {})[group] or 0
	end,
}
grug_core = {world_alterable = function() return alterable end}
grug_farming = {SOIL_DRY = "grug_farming:soil",
	SOIL_WET = "grug_farming:soil_wet"}
grug_mapgen = {wp40 = {planner_source = {
	column_values_at = function()
		return nil, nil, "elandor_dawnmere_fields", "grug_meadows", nil, 1
	end,
	static_exclusion_values_at = function() return nil end,
	housing_mask_id_at = function() return nil end,
	functional_surface_values_at = function() return nil end,
	hard_row_at = function() return nil end,
}}}

local world = dofile(root .. "/mods/MAPGEN/grug_mapgen/wp40/world_content_catalog.lua")
for _, row in ipairs(world.plants) do core.registered_nodes[row.node] = {groups = {}} end
local gathering = dofile(root .. "/mods/ITEMS/grug_gathering/catalog.lua")
for _, row in ipairs(gathering.p9g_sources()) do
	core.registered_nodes[row.source_node] = {groups = {}}
end
core.registered_nodes["default:apple"] = {groups = {}}
core.registered_nodes["default:blueberry_bush_leaves_with_berries"] = {groups = {}}
core.registered_nodes["default:dirt_with_grass"] = {groups = {}}

dofile(root .. "/mods/ITEMS/grug_farming/ecology.lua")()
assert(#callbacks.lbm.nodenames == 27, "renewable source population")
callbacks.loaded()
local source = "grug_mapgen:carrot_source"
nodes["1,2,1"], nodes["1,1,1"] = source, "default:dirt_with_grass"
callbacks.generated({x = 0, y = 0, z = 0}, {x = 15, y = 15, z = 15})
nodes["1,2,1"] = "air"
core.registered_nodes[source].after_destruct({x = 1, y = 2, z = 1}, {name = source})
now = now + 14400
callbacks.step(10)
assert(nodes["1,2,1"] == source, "due natural source renews")

-- Replacement without a node callback is found only by bounded reconciliation,
-- creates debt from the recorded identity and still waits the full first delay.
nodes["1,2,1"] = "air"
callbacks.step(10)
assert(nodes["1,2,1"] == "air" and stored.cells["carrot|0|0"].debt == 1,
	"non-dig depletion is observed without immediate replacement")
now = now + 14400
alterable = false
callbacks.step(10)
assert(nodes["1,2,1"] == "air", "protected habitat refuses renewal")
alterable = true
now = now + 1800
callbacks.step(10)
assert(nodes["1,2,1"] == source, "failed attempt backs off and later renews")

local player_pos = {x = 2, y = 2, z = 2}
nodes[key(player_pos)] = source
callbacks.placed(player_pos, {name = source})
callbacks.lbm.action(player_pos, {name = source})
assert(stored.cells["carrot|0|0"] and
	#callbacks.lbm.nodenames == 27, "player placement excluded without catalog drift")
assert(grug_farming.ECOLOGY_LIMITS.node_reads_per_pass == 384 and
	grug_farming.ECOLOGY_LIMITS.candidates_per_pass == 64 and
	grug_farming.ECOLOGY_LIMITS.cells_per_pass == 8 and
	grug_farming.ECOLOGY_LIMITS.placements_per_pass == 2,
	"global budgets")
-- Recreate the module over the same persisted value; no statistical target is
-- inferred and the exact observed baseline survives reload.
dofile(root .. "/mods/ITEMS/grug_farming/ecology.lua")()
assert(stored.cells["carrot|0|0"] and
	stored.cells["carrot|0|0"].positions["1,2,1"], "baseline persists on reload")
os.time, math.random = old_time, old_random
io.write("R11_ECOLOGY_OK 27-renewables/baseline/reload/dig/reconcile/protection/budgets\n")
