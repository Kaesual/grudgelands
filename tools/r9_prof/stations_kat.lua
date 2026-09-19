-- Real-code KAT for the five shared profession stations and capital projection.

return function(repo)
	local saved = {core = rawget(_G, "core"), default = rawget(_G, "default"),
		ItemStack = rawget(_G, "ItemStack"), grug_jobs = rawget(_G, "grug_jobs"),
		grug_core = rawget(_G, "grug_core"),
		grug_brewing = rawget(_G, "grug_brewing")}
	local function restore()
		for name, value in pairs(saved) do rawset(_G, name, value) end
	end
	local function fail(message)
		restore()
		error("r9 profession stations: " .. message, 0)
	end
	local function check(value, message) if not value then fail(message) end end

	local function stack(value)
		local text = tostring(value or "")
		if type(value) == "table" and type(value.get_name) == "function" then
			text = value:get_name() .. " " .. value:get_count()
		end
		local name = text:match("^%s*([^%s]+)") or ""
		local count = tonumber(text:match("%s+(%d+)%s*$")) or (name == "" and 0 or 1)
		local result = {}
		function result:get_name() return name end
		function result:get_count() return count end
		function result:is_empty() return name == "" or count == 0 end
		function result:take_item(amount)
			count = math.max(0, count - (amount or 1))
			if count == 0 then name = "" end
			return self
		end
		return result
	end
	ItemStack = stack

	local metas = {}
	local function key(pos) return pos.x .. ":" .. pos.y .. ":" .. pos.z end
	local function new_inventory()
		local sizes, lists = {}, {}
		local inv = {}
		function inv:set_size(name, size)
			sizes[name], lists[name] = size, {}
			for index = 1, size do lists[name][index] = stack("") end
		end
		function inv:get_size(name) return sizes[name] or 0 end
		function inv:get_list(name) return lists[name] or {} end
		function inv:get_stack(name, index)
			return stack((lists[name] or {})[index] or "")
		end
		function inv:set_stack(name, index, value)
			lists[name][index] = stack(value)
		end
		function inv:is_empty(name)
			for index = 1, sizes[name] or 0 do
				if not lists[name][index]:is_empty() then return false end
			end
			return true
		end
		return inv
	end
	local function meta_at(pos)
		local id = key(pos)
		if metas[id] then return metas[id] end
		local strings, inv = {}, new_inventory()
		local meta = {get_inventory = function() return inv end,
			set_string = function(_, name, value) strings[name] = value end,
			get_string = function(_, name) return strings[name] or "" end}
		metas[id] = meta
		return meta
	end

	local engine_recipes, mods_loaded = {}, {}
	core = {registered_items = {}, registered_nodes = {}}
	function core.register_node(name, definition)
		name = name:gsub("^:", "")
		core.registered_nodes[name], core.registered_items[name] = definition, definition
	end
	function core.register_craft(definition)
		local output = definition.output:match("^([^%s]+)")
		local list = engine_recipes[output] or {}
		list[#list + 1] = {method = definition.type == "cooking" and
			"cooking" or "normal", items = definition.recipe,
			output = definition.output}
		engine_recipes[output] = list
	end
	function core.get_all_craft_recipes(output) return engine_recipes[output] end
	function core.get_item_group(name, group)
		local definition = core.registered_items[name]
		return definition and definition.groups and definition.groups[group] or 0
	end
	function core.register_lbm() end
	function core.register_on_mods_loaded(callback)
		mods_loaded[#mods_loaded + 1] = callback
	end
	function core.formspec_escape(value) return tostring(value) end
	function core.get_meta(pos) return meta_at(pos) end
	function core.is_protected() return false end
	function core.chat_send_player() end
	function core.remove_node() end
	default = {
		get_hotbar_bg = function() return "" end,
		get_inventory_drops = function() end,
		set_inventory_action_loggers = function() end,
		node_sound_metal_defaults = function() return {} end,
		node_sound_wood_defaults = function() return {} end,
	}
	grug_core = {}
	grug_brewing = {}

	local base_items = {
		["grug_materials:steel_bar"] = {},
		["default:furnace"] = {}, ["default:stonebrick"] = {},
		["default:paper"] = {}, ["default:chest"] = {},
		["default:stick"] = {}, ["default:glass"] = {}, ["default:torch"] = {},
		["default:wood"] = {groups = {wood = 1}},
	}
	for name, definition in pairs(base_items) do core.registered_items[name] = definition end

	grug_jobs = {}
	dofile(repo .. "/mods/PLAYER/grug_jobs/registry.lua")
	function grug_jobs.station_book_button()
		return "image_button[0.35,1.45;0.85,0.85;book.png;grug_jobs_book;]"
	end
	function grug_jobs.has() return true end
	function grug_jobs.can_craft_recipe() return true end
	function grug_jobs.record_craft() end
	function grug_jobs.open_book() end
	grug_jobs.register_station("grid", {
		register_recipe = function(recipe)
			core.register_craft({output = recipe.output, recipe = recipe.inputs})
		end,
	})
	local station_factory = dofile(repo ..
		"/mods/PLAYER/grug_jobs/station_nodes.lua")
	station_factory.register_nodes()
	station_factory.install_jobs(grug_jobs)

	local expected = {
		{profession = "blacksmith", station = "forge", node = "grug_jobs:forge",
			x = 0, y = 1, z = -8, trainer_x = -1, trainer_z = -8},
		{profession = "leatherworker", station = "tanning_rack",
			node = "grug_jobs:tanning_rack", x = 2, y = 1, z = -20,
			trainer_x = 1, trainer_z = -20},
		{profession = "tailor", station = "tailor_bench",
			node = "grug_jobs:tailor_bench", x = 0, y = 1, z = -16,
			trainer_x = -1, trainer_z = -16},
		{profession = "woodcarver", station = "carving_bench",
			node = "grug_jobs:carving_bench", x = 0, y = 1, z = -24,
			trainer_x = -1, trainer_z = -24},
		{profession = "goldsmith", station = "jewellers_bench",
			node = "grug_jobs:jewellers_bench", x = 2, y = 1, z = -28,
			trainer_x = 1, trainer_z = -28},
	}
	local node_names = {}
	for index = 1, #expected do
		local row = expected[index]
		local info = grug_jobs.station_info(row.station)
		check(info and info.profession == row.profession and info.node == row.node,
			row.station .. " metadata differs")
		local definition = core.registered_nodes[row.node]
		check(definition and definition._grug_station == row.station and
			definition._grug_grid_size == 9 and
			type(definition.on_receive_fields) == "function",
			row.station .. " node handler differs")
		local pos = {x = index, y = 0, z = 0}
		definition.on_construct(pos)
		local node_meta = core.get_meta(pos)
		check(node_meta:get_inventory():get_size("craft") == 9 and
			node_meta:get_inventory():get_size("output") == 1 and
			node_meta:get_string("formspec"):find("grug_jobs_book", 1, true),
			row.station .. " formspec differs")
		node_names[row.node] = true
	end

	local housing = {}
	for index = 1, #grug_jobs.recipes do
		local recipe = grug_jobs.recipes[index]
		if node_names[recipe.output_name] then housing[recipe.output_name] = recipe end
	end
	for index = 1, #expected do
		local row, recipe = expected[index], housing[expected[index].node]
		check(recipe and recipe.profession == row.profession and recipe.tier == 3 and
			recipe.station == "grid", row.station .. " T3 housing recipe differs")
		for input_index = 1, #recipe.flat_inputs do
			check(not node_names[recipe.flat_inputs[input_index]],
				row.station .. " housing recipe is circular")
		end
	end

	core.registered_items["test:t3"] = {}
	core.registered_items["test:base_a"] = {}
	core.registered_items["test:base_b"] = {}
	core.registered_items["test:station_output"] = {}
	core.registered_items["test:shapeless_output"] = {}
	grug_jobs.register_ingredient_tier("test:t3", 3)
	grug_jobs.register_recipe({profession = "blacksmith", tier = 3,
		station = "forge", inputs = {{"test:t3", "test:base_a"},
			{"", "test:base_b"}}, output = "test:station_output",
		hint = "Forge test"})
	local shifted = {stack(""), stack("test:t3"), stack("test:base_a"),
		stack(""), stack(""), stack("test:base_b"), stack(""), stack(""), stack("")}
	local mirrored = {stack(""), stack("test:base_a"), stack("test:t3"),
		stack(""), stack("test:base_b"), stack(""), stack(""), stack(""), stack("")}
	check(grug_jobs.recipe_for_craft("forge", stack(""), shifted) ~= nil,
		"shifted shaped recipe was refused")
	check(grug_jobs.recipe_for_craft("forge", stack(""), mirrored) == nil,
		"mirrored shaped recipe was accepted")
	check(grug_jobs.recipe_for_craft("grid", stack(""), shifted) == nil and
		grug_jobs.recipe_for_craft("tanning_rack", stack(""), shifted) == nil,
		"station-bound recipe escaped its station")
	grug_jobs.register_recipe({profession = "leatherworker", tier = 3,
		station = "tanning_rack",
		inputs = {"test:t3", "test:base_a", "test:base_b"}, shapeless = true,
		output = "test:shapeless_output", hint = "Rack test"})
	check(grug_jobs.recipe_for_craft("tanning_rack", stack(""),
		{stack("test:base_b"), stack("test:t3"), stack("test:base_a")}) ~= nil,
		"shapeless station recipe permutation was refused")

	restore()
	local settlement = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
	local capitals = 0
	for profile_index = 1, #settlement.roster do
		local profile = settlement.roster[profile_index]
		if profile.slot == "capital" then
			capitals = capitals + 1
			local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/" ..
				profile.blueprint_file)()
			local original, original_cells = source.core.build(), {}
			for index = 1, #original.cells do
				local cell = original.cells[index]
				original_cells[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name
			end
			local descriptors = settlement.descriptors(profile, source)
			local projected
			local blueprints = {}
			for index = 1, #descriptors do
				local descriptor = descriptors[index]
				if descriptor.kind ~= "overlay" then
					local blueprint = descriptor.build()
					blueprints[#blueprints + 1] = {descriptor = descriptor,
						landmarks = blueprint.landmarks, reference = blueprint.reference}
					if descriptor.id == "core" then projected = blueprint end
				end
			end
			local projected_cells, station_cells = {}, {}
			for index = 1, #projected.cells do
				local cell = projected.cells[index]
				projected_cells[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name
				if node_names[cell.name] or cell.name == "grug_brewing:brewing_stand" then
					station_cells[#station_cells + 1] = cell.x .. ":" .. cell.y .. ":" .. cell.z
				end
			end
			check(#station_cells == 6, profile.key .. " station count differs")
			local occupied = {}
			for index = 1, #expected do
				local row = expected[index]
				local cell_key = row.x .. ":" .. row.y .. ":" .. row.z
				check(math.abs(row.x - row.trainer_x) +
					math.abs(row.z - row.trainer_z) == 1,
					profile.key .. " " .. row.station .. " is not trainer-adjacent")
				check(original_cells[cell_key] == "air" and
					projected_cells[cell_key] == row.node and not occupied[cell_key],
					profile.key .. " " .. row.station .. " projection differs")
				occupied[cell_key] = true
			end
			local brewing_key = "2:1:-12"
			check(original_cells[brewing_key] == "air" and
				projected_cells[brewing_key] == "grug_brewing:brewing_stand" and
				not occupied[brewing_key], profile.key .. " brewing stand differs")
			occupied[brewing_key] = true
			local prepared = {schema = "grug_wp13_settlement_prepared_v1",
				profile = profile, blueprints = blueprints}
			local sockets = settlement.sockets(prepared, {x = 0, y = 20, z = 0},
				function() return 20 end)
			for index = 1, #sockets do
				local socket = sockets[index]
				check(not occupied[socket.x .. ":" .. socket.y .. ":" .. socket.z],
					profile.key .. " station overlaps socket " .. socket.id)
			end
		end
	end
	check(capitals == 6, "capital population differs")

	local report = {"stations\tids=5\tnodes=5\tgrid=3x3\tbook_button\n",
		"recipes\thousing_t3=5\tacyclic\tshaped+shapeless\tstation_isolated\n",
		"capitals\tcount=6\tstations_each=6\tformer_air\tadjacent\tdistinct\n"}
	for index = 1, #expected do
		local row = expected[index]
		report[#report + 1] = table.concat({row.profession, row.station, row.node,
			row.x .. "," .. row.y .. "," .. row.z}, "\t") .. "\n"
	end
	return table.concat(report)
end
