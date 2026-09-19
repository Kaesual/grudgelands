return function(repo)
	local function check(value, message)
		if not value then error("R9 farming KAT: " .. message, 0) end
		return value
	end

	local function read_file(path)
		local handle = assert(io.open(path, "rb"))
		local bytes = assert(handle:read("*a"))
		assert(handle:close())
		return bytes
	end

	local cooking_source = read_file(repo .. "/mods/ITEMS/grug_cooking/init.lua")
	local plant_block = check(cooking_source:match("local PLANTS = {(.-)\n}"),
		"Cooking plant table missing")
	local plant_keys = {}
	for key in plant_block:gmatch('{name = "([a-z_]+)"') do
		plant_keys[#plant_keys + 1] = key
	end
	check(#plant_keys == 15, "Cooking plant population differs")

	local world, timers = {}, {}
	local crafts, lbms, mods_loaded = {}, {}, {}
	local function pos_key(pos)
		return table.concat({pos.x, pos.y, pos.z}, "/")
	end
	local function copy_pos(pos)
		return {x = pos.x, y = pos.y, z = pos.z}
	end

	local core_mock = {
		registered_items = {},
		registered_nodes = {},
	}

	local function register_item(name, definition, kind)
		definition.name = name
		definition.type = kind
		definition.groups = definition.groups or {}
		core_mock.registered_items[name] = definition
		if kind == "node" then core_mock.registered_nodes[name] = definition end
	end
	function core_mock.register_node(name, definition)
		register_item(name, definition, "node")
	end
	function core_mock.register_craftitem(name, definition)
		register_item(name, definition, "craft")
	end
	function core_mock.register_tool(name, definition)
		register_item(name, definition, "tool")
	end
	function core_mock.register_craft(definition)
		crafts[#crafts + 1] = definition
	end
	function core_mock.register_lbm(definition)
		lbms[#lbms + 1] = definition
	end
	function core_mock.register_abm()
		error("R9 farming KAT: farming registered an ABM", 0)
	end
	function core_mock.register_globalstep()
		error("R9 farming KAT: farming registered a globalstep", 0)
	end
	function core_mock.register_on_mods_loaded(callback)
		mods_loaded[#mods_loaded + 1] = callback
	end
	function core_mock.get_node(pos)
		return world[pos_key(pos)] or {name = "air"}
	end
	function core_mock.set_node(pos, node)
		world[pos_key(pos)] = {name = node.name, param2 = node.param2}
	end
	core_mock.swap_node = core_mock.set_node
	function core_mock.get_node_timer(pos)
		local key = pos_key(pos)
		local timer = timers[key]
		if timer then return timer end
		timer = {started = false, timeout = false, start_count = 0}
		function timer:start(timeout)
			self.started, self.timeout = true, timeout
			self.start_count = self.start_count + 1
		end
		function timer:stop()
			self.started = false
		end
		function timer:is_started()
			return self.started
		end
		timers[key] = timer
		return timer
	end
	function core_mock.find_node_near(pos, radius, names)
		check(radius == 3 and names[1] == "group:water",
			"hydration query differs")
		for y = pos.y - radius, pos.y + radius do
			for z = pos.z - radius, pos.z + radius do
				for x = pos.x - radius, pos.x + radius do
					local node = core_mock.get_node({x = x, y = y, z = z})
					local definition = core_mock.registered_nodes[node.name]
					if definition and (definition.groups or {}).water then
						return {x = x, y = y, z = z}
					end
				end
			end
		end
		return nil
	end
	function core_mock.is_protected() return false end
	function core_mock.record_protection_violation()
		error("R9 farming KAT: unexpected protection violation", 0)
	end
	function core_mock.is_creative_enabled() return false end
	function core_mock.sound_play() end

	local function sound() return {} end
	local default_mock = {
		node_sound_dirt_defaults = sound,
		node_sound_leaves_defaults = sound,
	}

	register_item("air", {buildable_to = true, walkable = false}, "node")
	register_item("default:dirt", {description = "Dirt", groups = {soil = 1}}, "node")
	register_item("default:dry_dirt",
		{description = "Dry Dirt", groups = {soil = 1}}, "node")
	register_item("default:dirt_with_grass",
		{description = "Dirt with Grass", groups = {soil = 1}}, "node")
	register_item("default:stone", {description = "Stone", groups = {}}, "node")
	register_item("default:water_source",
		{description = "Water", groups = {water = 1}}, "node")

	local cooking_plants = {}
	local harvest_snapshots = {}
	for index = 1, #plant_keys do
		local key = plant_keys[index]
		local item = "grug_cooking:" .. key
		local definition = {description = key, inventory_image = "plant_" .. key .. ".png"}
		register_item(item, definition, "craft")
		harvest_snapshots[item] = definition
		cooking_plants[index] = {name = key, description = key, item = item,
			image = definition.inventory_image}
	end
	for _, key in ipairs({"potato", "corn"}) do
		local item = "grug_gathering:" .. key
		local definition = {description = key, inventory_image = key .. ".png"}
		register_item(item, definition, "craft")
		harvest_snapshots[item] = definition
	end

	local saved_core = rawget(_G, "core")
	local saved_default = rawget(_G, "default")
	local saved_cooking = rawget(_G, "grug_cooking")
	local saved_farming = rawget(_G, "grug_farming")
	local function restore()
		rawset(_G, "core", saved_core)
		rawset(_G, "default", saved_default)
		rawset(_G, "grug_cooking", saved_cooking)
		rawset(_G, "grug_farming", saved_farming)
	end
	rawset(_G, "core", core_mock)
	rawset(_G, "default", default_mock)
	rawset(_G, "grug_cooking", {PLANTS = cooking_plants})
	rawset(_G, "grug_farming", nil)

	local ok, result = pcall(dofile, repo .. "/mods/ITEMS/grug_farming/init.lua")
	if not ok then
		restore()
		error(result, 0)
	end
	local farming = grug_farming

	check(farming.SOIL_DRY == "grug_farming:soil" and
		farming.SOIL_WET == "grug_farming:soil_wet",
		"public soil names differ")
	check(farming.STAGES == 4 and farming.STAGE_SECONDS == 200,
		"growth contract differs")
	check(#farming.CROPS == 17, "farmable crop population differs")
	check(#lbms == 1 and lbms[1].run_at_every_load == true,
		"soil activation LBM differs")

	local seen_harvest, seed_recipe = {}, {}
	for index = 1, #crafts do
		local craft = crafts[index]
		if craft.type == "shapeless" and type(craft.output) == "string" and
				craft.output:match("^grug_farming:seed_") then
			seed_recipe[craft.recipe[1]] = craft.output
		end
	end
	for index = 1, #farming.CROPS do
		local row = farming.CROPS[index]
		check(not seen_harvest[row.harvest_item],
			"duplicate harvest concept " .. row.harvest_item)
		seen_harvest[row.harvest_item] = true
		check(core_mock.registered_items[row.harvest_item] ==
			harvest_snapshots[row.harvest_item],
			"existing harvest definition replaced " .. row.harvest_item)
		check(seed_recipe[row.harvest_item] == row.seed .. " 2",
			"seed source differs for " .. row.key)
		check(#row.stages == 4, "growth chain differs for " .. row.key)
		for stage = 1, 4 do
			local definition = core_mock.registered_nodes[row.stages[stage]]
			check(definition and definition._grug_crop_harvest == row.harvest_item and
				definition._grug_crop_stage == stage,
				"growth stage differs for " .. row.key)
			check((stage < 4 and definition.groups.growing == 1 and
				definition.on_timer ~= nil) or (stage == 4 and
				definition.groups.growing == nil and definition.on_timer == nil),
				"maturity timer differs for " .. row.key)
		end
	end
	check(seen_harvest["grug_gathering:potato"] and
		seen_harvest["grug_gathering:corn"], "staples are not farmable")

	local stack_methods = {}
	function stack_methods:get_name() return self.name end
	function stack_methods:get_count() return self.count end
	function stack_methods:take_item(count)
		self.count = math.max(0, self.count - (count or 1))
		return self
	end
	function stack_methods:add_wear(wear) self.wear = self.wear + wear end
	local function stack(name, count)
		return setmetatable({name = name, count = count or 1, wear = 0},
			{__index = stack_methods})
	end
	local player = {get_player_name = function() return "farmer" end}
	local soil_pos = {x = 0, y = 0, z = 0}
	local crop_pos = {x = 0, y = 1, z = 0}
	local pointed = {type = "node", under = copy_pos(soil_pos),
		above = copy_pos(crop_pos)}
	world[pos_key(soil_pos)] = {name = farming.SOIL_DRY}
	world[pos_key(crop_pos)] = {name = "air"}

	local crop = farming.CROPS[1]
	local seeds = stack(crop.seed, 1)
	core_mock.registered_items[crop.seed].on_place(seeds, player, pointed)
	check(seeds.count == 0 and core_mock.get_node(crop_pos).name == crop.stages[1],
		"seed planting differs")
	check(core_mock.get_node_timer(crop_pos):is_started() and
		core_mock.get_node_timer(crop_pos).timeout == 200,
		"crop timer did not start")

	local first_stage = core_mock.registered_nodes[crop.stages[1]]
	check(first_stage.on_timer(crop_pos, 600) == true and
		core_mock.get_node(crop_pos).name == crop.stages[1],
		"dry soil did not stall growth")
	local replacement_seed = stack(crop.seed, 1)
	core_mock.registered_items[crop.seed].on_place(replacement_seed, player, pointed)
	check(replacement_seed.count == 1 and
		core_mock.get_node(crop_pos).name == crop.stages[1],
		"seed replaced an existing crop")
	world[pos_key({x = 3, y = 0, z = 0})] = {name = "default:water_source"}
	core_mock.registered_nodes[farming.SOIL_DRY].on_timer(soil_pos, 15)
	check(core_mock.get_node(soil_pos).name == farming.SOIL_WET,
		"soil did not become wet at radius three")
	check(core_mock.get_node_timer(crop_pos).timeout == 200 and
		core_mock.get_node_timer(crop_pos).start_count == 2,
		"hydration did not discard dry elapsed time")
	check(first_stage.on_timer(crop_pos, 400) == true and
		core_mock.get_node(crop_pos).name == crop.stages[3],
		"late timer did not advance two stages")
	local third_stage = core_mock.registered_nodes[crop.stages[3]]
	check(third_stage.on_timer(crop_pos, 400) == false and
		core_mock.get_node(crop_pos).name == crop.stages[4],
		"late timer did not clamp at maturity")

	local mature_drop = core_mock.registered_nodes[crop.stages[4]].drop
	check(mature_drop.items[1].items[1] == crop.harvest_item and
		mature_drop.items[2].items[1] == crop.seed,
		"mature harvest does not return crop and seed")
	world[pos_key(crop_pos)] = {name = "air"}
	local returned_seed = stack(crop.seed, 1)
	core_mock.registered_items[crop.seed].on_place(returned_seed, player, pointed)
	check(returned_seed.count == 0 and
		core_mock.get_node(crop_pos).name == crop.stages[1],
		"harvest seed did not replant")

	world[pos_key({x = 3, y = 0, z = 0})] = {name = "air"}
	core_mock.registered_nodes[farming.SOIL_WET].on_timer(soil_pos, 15)
	check(core_mock.get_node(soil_pos).name == farming.SOIL_DRY,
		"soil did not dry after water removal")

	local hoe = core_mock.registered_items["grug_farming:hoe"]
	local hoe_stack = stack("grug_farming:hoe", 1)
	local hoe_under = {x = 10, y = 0, z = 0}
	local hoe_above = {x = 10, y = 1, z = 0}
	world[pos_key(hoe_under)] = {name = "default:dirt"}
	world[pos_key(hoe_above)] = {name = "air"}
	hoe.on_use(hoe_stack, player,
		{type = "node", under = hoe_under, above = hoe_above})
	check(core_mock.get_node(hoe_under).name == farming.SOIL_DRY and
		hoe_stack.wear > 0, "hoe did not till dirt")
	local refusal_nodes = {"default:stone", "default:dirt_with_grass"}
	for index = 1, #refusal_nodes do
		local under = {x = 10 + index, y = 0, z = 0}
		local above = {x = 10 + index, y = 1, z = 0}
		world[pos_key(under)] = {name = refusal_nodes[index]}
		world[pos_key(above)] = {name = "air"}
		hoe.on_use(hoe_stack, player,
			{type = "node", under = under, above = above})
		check(core_mock.get_node(under).name == refusal_nodes[index],
			"hoe converted non-dirt " .. refusal_nodes[index])
	end
	local dry_under = {x = 13, y = 0, z = 0}
	local dry_above = {x = 13, y = 1, z = 0}
	world[pos_key(dry_under)] = {name = "default:dry_dirt"}
	world[pos_key(dry_above)] = {name = "air"}
	hoe.on_use(hoe_stack, player,
		{type = "node", under = dry_under, above = dry_above})
	check(core_mock.get_node(dry_under).name == farming.SOIL_DRY,
		"hoe did not till dry dirt")

	for index = 1, #mods_loaded do mods_loaded[index]() end
	restore()

	return table.concat({
		"farming_kat\tPASS\n",
		"crops\t17\n",
		"growth_nodes\t68\n",
		"stages\t4\n",
		"stage_seconds\t200\n",
		"soil\tgrug_farming:soil\tgrug_farming:soil_wet\n",
	})
end
