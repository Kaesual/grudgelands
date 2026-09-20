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

	local world, timers, metadata = {}, {}, {}
	local crafts, lbms, mods_loaded = {}, {}, {}
	local protected, protection_violations = {}, 0
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
	function core_mock.get_meta(pos)
		local key = pos_key(pos)
		local values = metadata[key]
		if not values then
			values = {}
			metadata[key] = values
		end
		return {
			get_float = function(_, name) return values[name] or 0 end,
			set_float = function(_, name, value) values[name] = value end,
		}
	end
	function core_mock.get_node_timer(pos)
		local key = pos_key(pos)
		local timer = timers[key]
		if timer then return timer end
		timer = {started = false, timeout = 0, elapsed = 0,
			start_count = 0, set_count = 0}
		function timer:start(timeout)
			self.started, self.timeout, self.elapsed = true, timeout, 0
			self.start_count = self.start_count + 1
		end
		function timer:set(timeout, elapsed)
			self.started, self.timeout, self.elapsed = timeout ~= 0, timeout, elapsed
			self.set_count = self.set_count + 1
		end
		function timer:stop()
			self.started, self.timeout, self.elapsed = false, 0, 0
		end
		function timer:is_started()
			return self.started
		end
		function timer:get_elapsed()
			return self.elapsed
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
	function core_mock.is_protected(pos)
		return protected[pos_key(pos)] == true
	end
	function core_mock.record_protection_violation()
		protection_violations = protection_violations + 1
	end
	function core_mock.is_creative_enabled() return false end
	function core_mock.sound_play() end

	local function sound() return {} end
	local default_mock = {
		node_sound_dirt_defaults = sound,
		node_sound_leaves_defaults = sound,
	}

	register_item("air", {buildable_to = true, walkable = false}, "node")
	local dirt_family = {
		"default:dirt",
		"default:dirt_with_grass",
		"default:dirt_with_grass_footsteps",
		"default:dirt_with_dry_grass",
		"default:dirt_with_snow",
		"default:dirt_with_rainforest_litter",
		"default:dirt_with_coniferous_litter",
		"default:dry_dirt",
		"default:dry_dirt_with_dry_grass",
	}
	for index = 1, #dirt_family do
		register_item(dirt_family[index],
			{description = dirt_family[index], groups = {soil = 1}}, "node")
	end
	register_item("test:soil", {description = "Grouped Soil", groups = {soil = 2}},
		"node")
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
			local expected_tile = "grug_farming_" .. row.key .. "_" .. stage .. ".png"
			check(definition and definition._grug_crop_harvest == row.harvest_item and
				definition._grug_crop_stage == stage,
				"growth stage differs for " .. row.key)
			local bound_tile = type(definition.tiles[1]) == "table" and
				definition.tiles[1].name or definition.tiles[1]
			check(bound_tile == expected_tile and
				definition.inventory_image == expected_tile and
				definition.wield_image == expected_tile,
				"growth art binding differs for " .. row.key)
			if row.key == "salt_crust" then
				check(definition.drawtype == "nodebox" and definition.node_box and
					type(definition.tiles[1]) == "table" and
					definition.tiles[1].animation.type == "vertical_frames" and
					definition.walkable == false,
					"salt crust node visual differs at stage " .. stage)
				for _, name in ipairs({"grug_farming_salt_crust_" .. stage .. "_side.png",
					"grug_farming_salt_crust_bottom.png"}) do
					local extra = io.open(repo .. "/mods/ITEMS/grug_farming/textures/" .. name, "rb")
					check(extra ~= nil, "salt crust node texture missing: " .. name)
					if extra then extra:close() end
				end
			end
			local media = io.open(repo .. "/mods/ITEMS/grug_farming/textures/" ..
				expected_tile, "rb")
			check(media ~= nil, "growth art is missing for " .. row.key)
			if media then media:close() end
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
	local function expire_crop(pos, elapsed)
		core_mock.get_node_timer(pos):stop()
		local definition = core_mock.registered_nodes[core_mock.get_node(pos).name]
		return definition.on_timer(pos, elapsed)
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
	check(not core_mock.get_node_timer(crop_pos):is_started(),
		"dry crop timer did not pause")

	local first_stage = core_mock.registered_nodes[crop.stages[1]]
	check(expire_crop(crop_pos, 600) == false and
		core_mock.get_node(crop_pos).name == crop.stages[1],
		"stale dry callback credited growth")
	local replacement_seed = stack(crop.seed, 1)
	core_mock.registered_items[crop.seed].on_place(replacement_seed, player, pointed)
	check(replacement_seed.count == 1 and
		core_mock.get_node(crop_pos).name == crop.stages[1],
		"seed replaced an existing crop")
	world[pos_key({x = 3, y = 0, z = 0})] = {name = "default:water_source"}
	core_mock.registered_nodes[farming.SOIL_DRY].on_timer(soil_pos, 15)
	check(core_mock.get_node(soil_pos).name == farming.SOIL_WET,
		"soil did not become wet at radius three")
	check(core_mock.get_node_timer(crop_pos):is_started() and
		core_mock.get_node_timer(crop_pos).timeout == 200 and
		core_mock.get_node_timer(crop_pos).elapsed == 0,
		"hydration did not resume crop timer")
	check(expire_crop(crop_pos, 599) == false and
		core_mock.get_node(crop_pos).name == crop.stages[3],
		"non-multiple late timer did not advance two stages")
	check(core_mock.get_node_timer(crop_pos):is_started() and
		core_mock.get_node_timer(crop_pos).elapsed == 199 and
		core_mock.get_meta(crop_pos):get_float("wet_progress") == 199,
		"non-multiple late timer did not carry its remainder")
	check(expire_crop(crop_pos, 200) == false and
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
	check(expire_crop(crop_pos, 200) == false and
		core_mock.get_node(crop_pos).name == crop.stages[2] and
		core_mock.get_node_timer(crop_pos):is_started() and
		core_mock.get_node_timer(crop_pos).elapsed == 0,
		"plain stage timer did not restart from zero")

	core_mock.get_node_timer(crop_pos).elapsed = 75
	world[pos_key({x = 3, y = 0, z = 0})] = {name = "air"}
	core_mock.registered_nodes[farming.SOIL_WET].on_timer(soil_pos, 15)
	check(core_mock.get_node(soil_pos).name == farming.SOIL_DRY and
		not core_mock.get_node_timer(crop_pos):is_started() and
		core_mock.get_meta(crop_pos):get_float("wet_progress") == 75,
		"drying did not pause wet crop progress")
	world[pos_key({x = 3, y = 0, z = 0})] = {name = "default:water_source"}
	core_mock.registered_nodes[farming.SOIL_DRY].on_timer(soil_pos, 15)
	check(core_mock.get_node(soil_pos).name == farming.SOIL_WET and
		core_mock.get_node_timer(crop_pos):is_started() and
		core_mock.get_node_timer(crop_pos).elapsed == 75,
		"rewetting did not resume wet crop progress")
	check(expire_crop(crop_pos, 200) == false and
		core_mock.get_node(crop_pos).name == crop.stages[3] and
		core_mock.get_node_timer(crop_pos).elapsed == 0,
		"resumed crop timer did not finish one stage")

	-- Model nodetimer.cpp's collection of all expired timers before callbacks:
	-- the crop timer is absent when the soil callback dries the node, then its
	-- already queued callback arrives with a large elapsed value.
	local overdue_soil = {x = 30, y = 0, z = 0}
	local overdue_crop = {x = 30, y = 1, z = 0}
	local overdue_water = {x = 33, y = 0, z = 0}
	world[pos_key(overdue_soil)] = {name = farming.SOIL_DRY}
	world[pos_key(overdue_crop)] = {name = "air"}
	world[pos_key(overdue_water)] = {name = "default:water_source"}
	local overdue_seed = stack(crop.seed, 1)
	core_mock.registered_items[crop.seed].on_place(overdue_seed, player,
		{type = "node", under = overdue_soil, above = overdue_crop})
	check(core_mock.get_node(overdue_soil).name == farming.SOIL_WET and
		core_mock.get_node_timer(overdue_crop):is_started(),
		"overdue callback fixture did not start wet")
	core_mock.get_node_timer(overdue_crop):stop()
	world[pos_key(overdue_water)] = {name = "air"}
	core_mock.registered_nodes[farming.SOIL_WET].on_timer(overdue_soil, 15)
	check(first_stage.on_timer(overdue_crop, 599) == false and
		core_mock.get_node(overdue_crop).name == crop.stages[1] and
		not core_mock.get_node_timer(overdue_crop):is_started() and
		core_mock.get_meta(overdue_crop):get_float("wet_progress") == 0,
		"simultaneous overdue dry callback credited stale elapsed")
	world[pos_key(overdue_water)] = {name = "default:water_source"}
	core_mock.registered_nodes[farming.SOIL_DRY].on_timer(overdue_soil, 15)
	check(core_mock.get_node_timer(overdue_crop):is_started() and
		core_mock.get_node_timer(overdue_crop).elapsed == 0,
		"stale callback did not leave a resumable crop")

	local hoe = core_mock.registered_items["grug_farming:hoe"]
	local hoe_stack = stack("grug_farming:hoe", 1)
	local tillable_nodes = {}
	for index = 1, #dirt_family do tillable_nodes[index] = dirt_family[index] end
	tillable_nodes[#tillable_nodes + 1] = "test:soil"
	for index = 1, #tillable_nodes do
		local under = {x = 100 + index, y = 0, z = 0}
		local above = {x = 100 + index, y = 1, z = 0}
		world[pos_key(under)] = {name = tillable_nodes[index]}
		world[pos_key(above)] = {name = "air"}
		local wear_before = hoe_stack.wear
		hoe.on_use(hoe_stack, player,
			{type = "node", under = under, above = above})
		check(core_mock.get_node(under).name == farming.SOIL_DRY and
			hoe_stack.wear > wear_before,
			"hoe did not till grouped soil " .. tillable_nodes[index])
	end
	local stone_under = {x = 120, y = 0, z = 0}
	local stone_above = {x = 120, y = 1, z = 0}
	world[pos_key(stone_under)] = {name = "default:stone"}
	world[pos_key(stone_above)] = {name = "air"}
	local refusal_wear = hoe_stack.wear
	hoe.on_use(hoe_stack, player,
		{type = "node", under = stone_under, above = stone_above})
	check(core_mock.get_node(stone_under).name == "default:stone" and
		hoe_stack.wear == refusal_wear, "hoe converted stone")
	local protected_under = {x = 121, y = 0, z = 0}
	local protected_above = {x = 121, y = 1, z = 0}
	world[pos_key(protected_under)] = {name = "default:dirt_with_grass"}
	world[pos_key(protected_above)] = {name = "air"}
	protected[pos_key(protected_under)] = true
	hoe.on_use(hoe_stack, player,
		{type = "node", under = protected_under, above = protected_above})
	check(core_mock.get_node(protected_under).name == "default:dirt_with_grass" and
		hoe_stack.wear == refusal_wear and protection_violations == 1,
		"hoe ignored protection")

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
