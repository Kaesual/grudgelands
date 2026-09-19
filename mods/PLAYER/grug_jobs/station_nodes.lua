local brewing = rawget(_G, "grug_brewing")
if brewing and brewing._grug_station_factory then
	return brewing._grug_station_factory
end

local factory = {}
local PUBLIC_STATIONS = {
	brewing_stand = true,
	forge = true,
	tanning_rack = true,
	tailor_bench = true,
	carving_bench = true,
	jewellers_bench = true,
}
local public_positions = {}
local nodes_registered = false
local jobs_installed = false

local function pos_key(pos)
	return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

function factory.register_public_position(station, pos)
	if not PUBLIC_STATIONS[station] or type(pos) ~= "table" or
			type(pos.x) ~= "number" or type(pos.y) ~= "number" or
			type(pos.z) ~= "number" then
		error("grug_jobs: public station position differs", 0)
	end
	public_positions[station .. "\0" .. pos_key(pos)] = true
end

function factory.is_public_station(station, pos)
	return public_positions[station .. "\0" .. pos_key(pos)] == true
end

local function may_access(station, pos, player)
	if factory.is_public_station(station, pos) then return true end
	return player and player.is_player and player:is_player() and
		not core.is_protected(pos, player:get_player_name())
end

local function jobs_api()
	local jobs = rawget(_G, "grug_jobs")
	if type(jobs) ~= "table" then
		error("grug_jobs: station runtime is unavailable", 0)
	end
	return jobs
end

local function formspec(station)
	local jobs = jobs_api()
	local info = jobs.station_info(station)
	return "formspec_version[3]size[10,10]" ..
		"label[1.5,0.35;" .. core.formspec_escape(info.display_name) .. "]" ..
		"label[1.5,0.75;Craft]list[context;craft;1.5,1.1;3,3;]" ..
		"image[5.0,2.05;1,1;gui_furnace_arrow_bg.png^[transformR270]" ..
		"label[6.2,0.75;Output]list[context;output;6.2,2.05;1,1;]" ..
		"list[current_player;main;1,5.15;8,1;]" ..
		"list[current_player;main;1,6.4;8,3;8]" ..
		"listring[context;output]listring[current_player;main]" ..
		"listring[context;craft]listring[current_player;main]" ..
		default.get_hotbar_bg(1, 5.15) ..
		jobs.station_book_button(station)
end

local function recipe_at(pos, station)
	local jobs = jobs_api()
	local inv = core.get_meta(pos):get_inventory()
	return jobs.recipe_for_craft(station, ItemStack(""),
		inv:get_list("craft") or {})
end

local function refresh_output(pos, station)
	local inv = core.get_meta(pos):get_inventory()
	local recipe = recipe_at(pos, station)
	inv:set_stack("output", 1, recipe and ItemStack(recipe.output) or ItemStack(""))
end

local function initialize(pos, station)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	if inv:get_size("craft") ~= 9 then inv:set_size("craft", 9) end
	if inv:get_size("output") ~= 1 then inv:set_size("output", 1) end
	meta:set_string("formspec", formspec(station))
	meta:set_string("infotext", jobs_api().station_info(station).display_name)
	refresh_output(pos, station)
end

local function consume_inputs(pos)
	local inv = core.get_meta(pos):get_inventory()
	for index = 1, 9 do
		local stack = inv:get_stack("craft", index)
		if not stack:is_empty() then
			stack:take_item(1)
			inv:set_stack("craft", index, stack)
		end
	end
end

local function register_station_node(station, info, visual)
	local name = info.node
	local function allow_put(pos, listname, index, stack, player)
		if not may_access(station, pos, player) or listname ~= "craft" then return 0 end
		return stack:get_count()
	end
	local function allow_move(pos, from_list, from_index, to_list, to_index,
			count, player)
		if not may_access(station, pos, player) or from_list == "output" or
				to_list == "output" or to_list ~= "craft" then
			return 0
		end
		return count
	end
	local function allow_take(pos, listname, index, stack, player)
		if not may_access(station, pos, player) then return 0 end
		if listname ~= "output" then return stack:get_count() end
		local recipe = recipe_at(pos, station)
		if not recipe or ItemStack(recipe.output):get_count() ~= stack:get_count() then
			return 0
		end
		local allowed, reason = jobs_api().can_craft_recipe(player, recipe)
		if not allowed then
			core.chat_send_player(player:get_player_name(),
				"Cannot craft " .. recipe.output_name .. ": " .. reason)
			return 0
		end
		return stack:get_count()
	end
	local function on_take(pos, listname, index, stack, player)
		if listname == "output" then
			local recipe = recipe_at(pos, station)
			if recipe and recipe.output_name == stack:get_name() then
				consume_inputs(pos)
				jobs_api().record_craft(player, recipe.profession, recipe.tier)
			end
		end
		refresh_output(pos, station)
	end
	local function on_change(pos)
		refresh_output(pos, station)
	end
	local function can_dig(pos)
		local inv = core.get_meta(pos):get_inventory()
		return inv:is_empty("craft") and inv:is_empty("output")
	end
	local function on_receive_fields(pos, formname, fields, sender)
		if fields.grug_jobs_book and sender and sender:is_player() then
			jobs_api().open_book(sender, "station", station)
		end
	end
	local definition = {
		description = info.display_name,
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = visual.boxes},
		tiles = {visual.texture},
		paramtype = "light", paramtype2 = "facedir",
		is_ground_content = false,
		groups = visual.groups,
		sounds = visual.sounds(),
		_grug_station = station,
		_grug_grid_size = 9,
		on_construct = function(pos) initialize(pos, station) end,
		can_dig = can_dig,
		allow_metadata_inventory_put = allow_put,
		allow_metadata_inventory_move = allow_move,
		allow_metadata_inventory_take = allow_take,
		on_metadata_inventory_put = on_change,
		on_metadata_inventory_move = on_change,
		on_metadata_inventory_take = on_take,
		on_receive_fields = on_receive_fields,
		on_blast = function(pos)
			local drops = {}
			default.get_inventory_drops(pos, "craft", drops)
			drops[#drops + 1] = name
			core.remove_node(pos)
			return drops
		end,
	}
	default.set_inventory_action_loggers(definition, station:gsub("_", " "))
	core.register_node(":" .. name, definition)
end

local wood_boxes = {
	{-0.5, -0.5, -0.45, 0.5, -0.36, 0.45},
	{-0.43, -0.36, -0.38, -0.31, 0.25, -0.26},
	{0.31, -0.36, -0.38, 0.43, 0.25, -0.26},
	{-0.43, -0.36, 0.26, -0.31, 0.25, 0.38},
	{0.31, -0.36, 0.26, 0.43, 0.25, 0.38},
}

local STATION_INFO = {
	forge = {display_name = "Forge", profession = "blacksmith",
		node = "grug_jobs:forge"},
	tanning_rack = {display_name = "Tanning Rack", profession = "leatherworker",
		node = "grug_jobs:tanning_rack"},
	tailor_bench = {display_name = "Tailor Bench", profession = "tailor",
		node = "grug_jobs:tailor_bench"},
	carving_bench = {display_name = "Carving Bench", profession = "woodcarver",
		node = "grug_jobs:carving_bench"},
	jewellers_bench = {display_name = "Jeweller's Bench", profession = "goldsmith",
		node = "grug_jobs:jewellers_bench"},
}

function factory.register_nodes()
	if nodes_registered then return end
	nodes_registered = true
	register_station_node("forge", STATION_INFO.forge, {
		texture = "default_steel_block.png^[colorize:#34251f:70",
		boxes = {
			{-0.5, -0.5, -0.5, 0.5, -0.12, 0.5},
			{-0.32, -0.12, -0.2, 0.32, 0.08, 0.2},
			{-0.18, 0.08, -0.12, 0.18, 0.35, 0.12},
		},
		groups = {cracky = 2}, sounds = default.node_sound_metal_defaults,
	})
	register_station_node("tanning_rack", STATION_INFO.tanning_rack, {
		texture = "default_wood.png^[colorize:#704020:55",
		boxes = {
			{-0.46, -0.5, -0.1, -0.34, 0.45, 0.1},
			{0.34, -0.5, -0.1, 0.46, 0.45, 0.1},
			{-0.34, -0.38, -0.04, 0.34, 0.34, 0.04},
			{-0.5, 0.34, -0.1, 0.5, 0.46, 0.1},
		},
		groups = {choppy = 2}, sounds = default.node_sound_wood_defaults,
	})
	register_station_node("tailor_bench", STATION_INFO.tailor_bench, {
		texture = "default_wood.png^[colorize:#735493:75",
		boxes = wood_boxes,
		groups = {choppy = 2}, sounds = default.node_sound_wood_defaults,
	})
	register_station_node("carving_bench", STATION_INFO.carving_bench, {
		texture = "default_wood.png^[colorize:#315f35:45",
		boxes = wood_boxes,
		groups = {choppy = 2}, sounds = default.node_sound_wood_defaults,
	})
	register_station_node("jewellers_bench", STATION_INFO.jewellers_bench, {
		texture = "default_steel_block.png^[colorize:#c69a35:105",
		boxes = wood_boxes,
		groups = {cracky = 2}, sounds = default.node_sound_metal_defaults,
	})

	core.register_lbm({
		label = "Activate profession stations",
		name = ":grug_jobs:activate_stations",
		nodenames = {
			"grug_jobs:forge", "grug_jobs:tanning_rack",
			"grug_jobs:tailor_bench", "grug_jobs:carving_bench",
			"grug_jobs:jewellers_bench",
		},
		run_at_every_load = true,
		action = function(pos, node)
			if core.get_meta(pos):get_inventory():get_size("craft") ~= 9 then
				initialize(pos, core.registered_nodes[node.name]._grug_station)
			end
		end,
	})
end

local STEEL = "grug_materials:steel_bar"

local station_recipes = {
	{profession = "blacksmith", output = "grug_jobs:forge", inputs = {
		{STEEL, STEEL, STEEL},
		{"", "default:furnace", ""},
		{"default:stonebrick", "default:stonebrick", "default:stonebrick"},
	}},
	{profession = "leatherworker", output = "grug_jobs:tanning_rack", inputs = {
		{"group:wood", STEEL, "group:wood"},
		{"group:wood", "default:paper", "group:wood"},
		{"group:wood", "", "group:wood"},
	}},
	{profession = "tailor", output = "grug_jobs:tailor_bench", inputs = {
		{"default:paper", STEEL, "default:paper"},
		{"group:wood", "default:chest", "group:wood"},
		{"", "default:paper", ""},
	}},
	{profession = "woodcarver", output = "grug_jobs:carving_bench", inputs = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:wood", STEEL, "group:wood"},
		{"", "default:stick", ""},
	}},
	{profession = "goldsmith", output = "grug_jobs:jewellers_bench", inputs = {
		{"default:glass", STEEL, "default:glass"},
		{"", "default:torch", ""},
		{"default:stonebrick", "default:stonebrick", "default:stonebrick"},
	}},
}

function factory.install_jobs(jobs)
	if jobs_installed then return end
	jobs_installed = true
	factory.register_nodes()
	jobs.register_public_position = factory.register_public_position
	jobs.is_public_station = factory.is_public_station
	for station, info in pairs(STATION_INFO) do
		local station_id, station_info = station, info
		jobs.register_station(station_id, {
			register_recipe = function(recipe)
				if recipe.station ~= station_id then
					error("grug_jobs: station recipe adapter differs", 0)
				end
			end,
			can_use = function(player)
				return jobs.has(player, station_info.profession)
			end,
		})
	end
	jobs.register_ingredient_tier(STEEL, 3)
	for index = 1, #station_recipes do
		local recipe = station_recipes[index]
		jobs.register_recipe({
			profession = recipe.profession, tier = 3, station = "grid",
			inputs = recipe.inputs, output = recipe.output,
			hint = "Craft in the inventory grid",
		})
	end
	core.register_on_mods_loaded(function()
		local settlements = grug_core.settlement_socket_settlements()
		for index = 1, #settlements do
			local sockets = grug_core.settlement_sockets_at(settlements[index].key)
			for socket_index = 1, #sockets do
				local socket = sockets[socket_index]
				for station in pairs(PUBLIC_STATIONS) do
					local info = jobs.station_info(station)
					if info and socket.role == "trainer" and
							socket.profession == info.profession then
						jobs.register_public_position(station, {
							x = socket.pos.x + 1, y = socket.pos.y, z = socket.pos.z,
						})
					end
				end
			end
		end
	end)
end

if brewing then brewing._grug_station_factory = factory end
return factory
