-- Engine-free reconstruction of the registered-node fields consumed by R7.
-- The definitions come from the production registration files, with Luanti's
-- node defaults and flowing-liquid preprocessing modelled at the registration
-- seam.  The returned rows are deliberately reduced to R7's semantic surface.

return function(repo, catalog, expected_names)
	local saved = {}
	local globals = {"core", "minetest", "default", "grug_materials",
		"grug_trees", "ItemStack", "vector"}
	for index = 1, #globals do
		local name = globals[index]
		saved[name] = rawget(_G, name)
	end
	local saved_table_copy = table.copy

	local function restore()
		for index = 1, #globals do
			local name = globals[index]
			rawset(_G, name, saved[name])
		end
		table.copy = saved_table_copy
	end

	local function build()
		if type(repo) ~= "string" or type(catalog) ~= "table" or
				type(expected_names) ~= "table" then
			error("WP40 R7 node semantics fixture: dependencies differ", 0)
		end

		local function copy(value)
			if type(value) ~= "table" then return value end
			local result = {}
			for key, child in pairs(value) do result[copy(key)] = copy(child) end
			return result
		end
		table.copy = copy

		local function read_file(path)
			local handle = assert(io.open(path, "rb"), "cannot open " .. path)
			local bytes = assert(handle:read("*a"))
			assert(handle:close())
			return bytes
		end
		local item_builtin = read_file(repo ..
			"/reference_projects/luanti/builtin/game/item.lua")
		local defaults_source = item_builtin:match(
			"core%.nodedef_default = {(.-)core%.craftitemdef_default = {")
		if not defaults_source then
			error("WP40 R7 node semantics fixture: Luanti node defaults missing", 0)
		end
		local expected_engine_defaults = {
			paramtype = "\"none\"", paramtype2 = "\"none\"",
			sunlight_propagates = "false", floodable = "false",
			liquidtype = "\"none\"", liquid_alternative_source = "\"\"",
			light_source = "0", walkable = "true", buildable_to = "false",
			diggable = "true", is_ground_content = "true",
		}
		for key, expected in pairs(expected_engine_defaults) do
			local value = defaults_source:match("[\r\n]%s*" .. key ..
				"%s*=%s*([^,%s]+)")
			if value ~= expected then
				error("WP40 R7 node semantics fixture: Luanti default differs: " .. key, 0)
			end
		end
		local register_builtin = read_file(repo ..
			"/reference_projects/luanti/builtin/game/register.lua")
		if not register_builtin:match(
			"if nodedef%.liquidtype == \"flowing\" then%s*" ..
			"nodedef%.paramtype2 = \"flowingliquid\"%s*end") then
			error("WP40 R7 node semantics fixture: Luanti liquid preprocessing differs", 0)
		end

		local callbacks = {mods_loaded = {}, dignode = {}, leaveplayer = {}}
		local current_modname = "default"
		local nodedef_default = {
			groups = {}, paramtype = "none", paramtype2 = "none",
			sunlight_propagates = false, floodable = false,
			liquidtype = "none", liquid_alternative_source = "",
			light_source = 0, walkable = true, buildable_to = false,
			diggable = true, is_ground_content = true,
		}
		local itemdef_default = {groups = {}}
		local api = {
			LIGHT_MAX = 14, nodedef_default = nodedef_default,
			registered_nodes = {}, registered_items = {}, registered_aliases = {},
		}

		local function register_item(name, definition, kind)
			name = name:gsub("^:", "")
			definition.name, definition.type = name, kind
			if kind == "node" and definition.liquidtype == "flowing" then
				definition.paramtype2 = "flowingliquid"
			end
			setmetatable(definition, {__index = kind == "node" and
				nodedef_default or itemdef_default})
			api.registered_items[name] = definition
			if kind == "node" then api.registered_nodes[name] = definition end
		end
		function api.register_node(name, definition)
			register_item(name, definition, "node")
		end
		function api.register_craftitem(name, definition)
			register_item(name, definition, "craft")
		end
		function api.register_tool(name, definition)
			register_item(name, definition, "tool")
		end
		function api.override_item(name, fields)
			local definition = api.registered_items[name]
			if not definition then error("missing override target " .. name, 0) end
			for key, value in pairs(fields) do rawset(definition, key, value) end
		end
		function api.register_alias_force(source, target)
			api.registered_aliases[source] = target
			api.registered_items[source], api.registered_nodes[source] = nil, nil
		end
		function api.get_current_modname() return current_modname end
		function api.get_modpath(name)
			local roots = {
				default = repo .. "/mods/BASE/default",
				grug_trees = repo .. "/mods/ITEMS/grug_trees",
				grug_materials = repo .. "/mods/ITEMS/grug_materials",
				grug_nodes = repo .. "/mods/ITEMS/grug_nodes",
				grug_gathering = repo .. "/mods/ITEMS/grug_gathering",
			}
			return roots[name]
		end
		function api.register_on_mods_loaded(callback)
			callbacks.mods_loaded[#callbacks.mods_loaded + 1] = callback
		end
		function api.register_on_dignode(callback)
			callbacks.dignode[#callbacks.dignode + 1] = callback
		end
		function api.register_on_leaveplayer(callback)
			callbacks.leaveplayer[#callbacks.leaveplayer + 1] = callback
		end
		function api.register_craft() end
		function api.clear_craft() return false end
		function api.log() end
		function api.item_eat() return function() end end
		function api.get_mapgen_setting() return "1" end
		function api.register_schematic() return {} end
		function api.read_schematic() return {} end
		function api.place_schematic() end
		function api.get_node() return {name = "air"} end
		function api.set_node() end
		function api.get_node_timer()
			return {start = function() end}
		end
		function api.get_meta()
			return {get_string = function() return "" end,
				set_string = function() end}
		end
		function api.node_dig() end
		function api.handle_node_drops() end
		function api.get_us_time() return 0 end
		function api.item_place(itemstack) return itemstack end
		function api.item_place_node(itemstack) return itemstack end
		function api.is_creative_enabled() return false end
		function api.dir_to_facedir() return 0 end
		api.settings = {get_bool = function() return false end}

		rawset(_G, "core", api)
		rawset(_G, "minetest", api)
		rawset(_G, "vector", {subtract = function(left, right)
			return {x = left.x - right.x, y = left.y - right.y,
				z = left.z - right.z}
		end})
		rawset(_G, "ItemStack", function() return {} end)
		local function noop() end
		local function sound(values) return values or {} end
		rawset(_G, "default", {
			LIGHT_MAX = 14, get_translator = function(value) return value end,
			get_hotbar_bg = function() return "" end,
			after_place_leaves = noop, grow_sapling = noop,
			grow_large_cactus = noop, dig_up = noop, log_player_action = noop,
			get_inventory_drops = noop, sapling_on_place = function(stack) return stack end,
			set_inventory_action_loggers = noop, register_fence = noop,
			register_fence_rail = noop, register_mesepost = noop,
			register_leafdecay = noop, register_sapling_growth = noop,
			node_sound_defaults = sound, node_sound_dirt_defaults = sound,
			node_sound_glass_defaults = sound, node_sound_gravel_defaults = sound,
			node_sound_ice_defaults = sound, node_sound_leaves_defaults = sound,
			node_sound_metal_defaults = sound, node_sound_sand_defaults = sound,
			node_sound_snow_defaults = sound, node_sound_stone_defaults = sound,
			node_sound_water_defaults = sound, node_sound_wood_defaults = sound,
		})

		api.register_node(":air", {paramtype = "light", sunlight_propagates = true,
			floodable = true, walkable = false, diggable = false,
			buildable_to = true})
		api.register_node(":ignore", {walkable = false, diggable = false,
			buildable_to = true})

		dofile(repo .. "/mods/BASE/default/nodes.lua")

		current_modname = "grug_trees"
		dofile(repo .. "/mods/ITEMS/grug_trees/init.lua")

		-- The material initializer modifies four vendored tools. Their item
		-- semantics are irrelevant here, but the authentic initializer requires
		-- the registrations to exist before applying its production overrides.
		for _, name in ipairs({"default:pick_wood", "default:pick_stone",
				"default:pick_bronze", "default:pick_steel"}) do
			api.register_tool(name, {groups = {pickaxe = 1}, tool_capabilities = {
				punch_attack_uses = 20, groupcaps = {}, damage_groups = {}}})
		end
		current_modname = "grug_materials"
		dofile(repo .. "/mods/ITEMS/grug_materials/init.lua")

		current_modname = "grug_nodes"
		dofile(repo .. "/mods/ITEMS/grug_nodes/init.lua")

		current_modname = "grug_gathering"
		local harvest = {can_dig = function() return function() return false end end}
		dofile(repo .. "/mods/ITEMS/grug_gathering/nodes.lua")(api, catalog, harvest)

		local definitions = {}
		local seen = {}
		for index = 1, #expected_names do
			local name = expected_names[index]
			if type(name) ~= "string" or seen[name] then
				error("WP40 R7 node semantics fixture: target names differ", 0)
			end
			seen[name] = true
			local definition = rawget(api.registered_nodes, name)
			if type(definition) ~= "table" then
				error("WP40 R7 node semantics fixture: missing production node " .. name, 0)
			end
			definitions[name] = {
				groups = {grug_natural = (definition.groups or {}).grug_natural,
					grug_camp = (definition.groups or {}).grug_camp},
				liquidtype = definition.liquidtype,
				liquid_alternative_source = definition.liquid_alternative_source,
				floodable = definition.floodable,
				paramtype = definition.paramtype,
				sunlight_propagates = definition.sunlight_propagates,
				light_source = definition.light_source,
				paramtype2 = definition.paramtype2,
				walkable = definition.walkable,
				is_ground_content = definition.is_ground_content,
				drop = definition.drop,
			}
		end
		return {schema = "grug_wp40_r7_node_semantics_fixture_v1",
			definitions = definitions, target_count = #expected_names,
			sources = {
				"reference_projects/luanti/builtin/game/item.lua",
				"reference_projects/luanti/builtin/game/register.lua",
				"mods/BASE/default/nodes.lua",
				"mods/ITEMS/grug_trees/init.lua",
				"mods/ITEMS/grug_materials/init.lua",
				"mods/ITEMS/grug_nodes/init.lua",
				"mods/ITEMS/grug_gathering/nodes.lua",
			}}
	end

	local ok, result = pcall(build)
	restore()
	if not ok then error(result, 0) end
	return result
end
