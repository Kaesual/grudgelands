-- Round-10 completion fixture for the real grug_farming registration and
-- lifecycle. MAP-B separately owns wild placement and field projection.
return function(repo)
	local function check(value, message)
		if not value then error("R10 farming KAT: " .. message, 0) end
		return value
	end
	local world, timers, metadata, protected = {}, {}, {}, {}
	local crafts, lbms, violations = {}, {}, {}
	local function key(pos) return pos.x .. "/" .. pos.y .. "/" .. pos.z end
	local function pos(x, y, z) return {x = x, y = y, z = z} end
	local core_mock = {registered_items = {}, registered_nodes = {}}
	local function register(name, definition)
		name = name:gsub("^:", "")
		definition.groups = definition.groups or {}
		core_mock.registered_items[name] = definition
		if definition._kat_node then core_mock.registered_nodes[name] = definition end
	end
	function core_mock.register_node(name, definition)
		definition._kat_node = true
		register(name, definition)
	end
	function core_mock.register_craftitem(name, definition) register(name, definition) end
	function core_mock.register_tool(name, definition) register(name, definition) end
	function core_mock.register_craft(definition) crafts[#crafts + 1] = definition end
	function core_mock.register_lbm(definition) lbms[#lbms + 1] = definition end
	function core_mock.register_on_mods_loaded() end
	function core_mock.register_abm() error("R10 farming registered an ABM", 0) end
	function core_mock.register_globalstep()
		error("R10 farming registered a globalstep", 0)
	end
	function core_mock.get_node(p) return world[key(p)] or {name = "air"} end
	function core_mock.set_node(p, node) world[key(p)] = {name = node.name} end
	core_mock.swap_node = core_mock.set_node
	function core_mock.get_meta(p)
		local values = metadata[key(p)] or {}
		metadata[key(p)] = values
		return {
			get_float = function(_, name) return values[name] or 0 end,
			set_float = function(_, name, value) values[name] = value end,
		}
	end
	function core_mock.get_node_timer(p)
		local timer = timers[key(p)]
		if timer then return timer end
		timer = {started = false, elapsed = 0, starts = 0, sets = 0}
		function timer:start(timeout)
			self.started, self.timeout, self.elapsed = true, timeout, 0
			self.starts = self.starts + 1
		end
		function timer:set(timeout, elapsed)
			self.started, self.timeout, self.elapsed = true, timeout, elapsed
			self.sets = self.sets + 1
		end
		function timer:stop() self.started, self.timeout, self.elapsed = false, 0, 0 end
		function timer:is_started() return self.started end
		function timer:get_elapsed() return self.elapsed end
		timers[key(p)] = timer
		return timer
	end
	function core_mock.find_node_near(p, radius, names)
		check(radius == 3 and names[1] == "group:water", "water query differs")
		for y = p.y - radius, p.y + radius do
			for z = p.z - radius, p.z + radius do
				for x = p.x - radius, p.x + radius do
					local name = core_mock.get_node(pos(x, y, z)).name
					local definition = core_mock.registered_nodes[name]
					if definition and definition.groups.water then return pos(x, y, z) end
				end
			end
		end
		return nil
	end
	function core_mock.is_protected(p) return protected[key(p)] == true end
	function core_mock.record_protection_violation(p)
		violations[#violations + 1] = key(p)
	end
	function core_mock.is_creative_enabled() return false end
	function core_mock.sound_play() end

	local function node(name, groups, buildable)
		core_mock.register_node(name, {groups = groups or {},
			buildable_to = buildable == true})
	end
	node("air", {}, true)
	node("default:dirt", {soil = 1})
	node("default:water_source", {water = 1})
	local plants = {}
	local cooking_file = assert(io.open(repo ..
		"/mods/ITEMS/grug_cooking/init.lua", "rb"))
	for line in cooking_file:lines() do
		local name, description = line:match('{name = "([a-z_]+)", description = "([^"]+)"')
		if name then
			local item = "grug_cooking:" .. name
			core_mock.register_craftitem(item, {description = description,
				inventory_image = "grug_cooking_" .. name .. ".png"})
			plants[#plants + 1] = {name = name, description = description,
				item = item, image = "grug_cooking_" .. name .. ".png"}
		end
	end
	assert(cooking_file:close())
	check(#plants == 15, "Cooking plant roster differs")
	for _, name in ipairs({"potato", "corn"}) do
		core_mock.register_craftitem("grug_gathering:" .. name,
			{description = name, inventory_image = name .. ".png"})
	end

	local stack_methods = {}
	function stack_methods:get_name() return self.name end
	function stack_methods:get_count() return self.count end
	function stack_methods:take_item(amount)
		self.count = math.max(0, self.count - (amount or 1)); return self
	end
	function stack_methods:add_wear(amount) self.wear = self.wear + amount end
	local function stack(name, count)
		return setmetatable({name = name, count = count or 1, wear = 0},
			{__index = stack_methods})
	end
	local player = {get_player_name = function() return "farmer" end}
	local global_names = {"core", "default", "grug_cooking", "grug_farming", "grug_nodes"}
	local saved, present = {}, {}
	for _, name in ipairs(global_names) do
		present[name] = rawget(_G, name) ~= nil
		saved[name] = rawget(_G, name)
	end
	local function restore()
		for _, name in ipairs(global_names) do
			rawset(_G, name, present[name] and saved[name] or nil)
		end
	end
	rawset(_G, "core", core_mock)
	rawset(_G, "default", {node_sound_dirt_defaults = function() return {} end,
		node_sound_leaves_defaults = function() return {} end})
	rawset(_G, "grug_cooking", {PLANTS = plants})
	rawset(_G, "grug_farming", nil)
 rawset(_G, "grug_nodes", {
  crop_visual = dofile(repo .. "/mods/ITEMS/grug_nodes/crop_visual.lua"),
  bind_crop_soil_callbacks = dofile(repo .. "/mods/ITEMS/grug_nodes/crop_soil.lua")(core_mock, default),
 })

	local ok, result = pcall(function()
		assert(loadfile(repo .. "/mods/ITEMS/grug_farming/init.lua"))()
		check(#grug_farming.CROPS == 17, "crop population differs")
		check(#lbms == 1 and lbms[1].run_at_every_load,
			"VM soil activation LBM differs")
		local recipes = {}
		for _, craft in ipairs(crafts) do
			if craft.type == "shapeless" then recipes[craft.recipe[1]] = craft.output end
		end
		local hoe = check(core_mock.registered_items["grug_farming:hoe"],
			"hoe absent")
		for index, crop in ipairs(grug_farming.CROPS) do
			check(recipes[crop.harvest_item] == crop.seed .. " 2",
				"harvest-to-seed route differs: " .. crop.key)
			local x = index * 10
			local under, above, water = pos(x, 0, 0), pos(x, 1, 0), pos(x + 3, 0, 0)
			world[key(under)], world[key(above)], world[key(water)] =
				{name = "default:dirt"}, {name = "air"}, {name = "default:water_source"}
			local tool = stack("grug_farming:hoe")
			hoe.on_use(tool, player, {type = "node", under = under, above = above})
			check(core_mock.get_node(under).name == grug_farming.SOIL_WET and
				tool.wear > 0, "hoe/water route differs: " .. crop.key)
			local seeds = stack(crop.seed)
			core_mock.registered_items[crop.seed].on_place(seeds, player,
				{type = "node", under = under, above = above})
			check(seeds.count == 0 and core_mock.get_node(above).name == crop.stages[1],
				"plant route differs: " .. crop.key)
			local first = core_mock.registered_nodes[crop.stages[1]]
			first.on_timer(above, 600)
			check(core_mock.get_node(above).name == crop.stages[4],
				"growth route differs: " .. crop.key)
			local drop = core_mock.registered_nodes[crop.stages[4]].drop.items
			check(drop[1].items[1] == crop.harvest_item and drop[2].items[1] == crop.seed,
				"harvest/replant return differs: " .. crop.key)
			world[key(above)] = {name = "air"}
			local returned = stack(crop.seed)
			core_mock.registered_items[crop.seed].on_place(returned, player,
				{type = "node", under = under, above = above})
			check(returned.count == 0 and core_mock.get_node(above).name == crop.stages[1],
				"returned seed does not replant: " .. crop.key)
		end

		-- VoxelManip fields do not call on_construct. The every-load activation is
		-- idempotent and also restarts a persisted soil whose timer is absent.
		local vm_soil = pos(500, 0, 0)
		world[key(vm_soil)] = {name = grug_farming.SOIL_DRY}
		lbms[1].action(vm_soil)
		local vm_timer = core_mock.get_node_timer(vm_soil)
		check(vm_timer.started and vm_timer.starts == 1,
			"VM-created soil timer was not activated")
		lbms[1].action(vm_soil)
		check(vm_timer.starts == 1, "soil activation is not idempotent")
		vm_timer:stop()
		lbms[1].action(vm_soil)
		check(vm_timer.starts == 2, "reload did not restore missing soil timer")

		local crop = grug_farming.CROPS[1]
		local pause_soil, pause_crop, pause_water = pos(550, 0, 0),
			pos(550, 1, 0), pos(553, 0, 0)
		world[key(pause_soil)], world[key(pause_crop)], world[key(pause_water)] =
			{name = grug_farming.SOIL_WET}, {name = crop.stages[1]},
			{name = "default:water_source"}
		core_mock.registered_nodes[crop.stages[1]].on_construct(pause_crop)
		core_mock.get_node_timer(pause_crop).elapsed = 75
		world[key(pause_water)] = {name = "air"}
		core_mock.registered_nodes[grug_farming.SOIL_WET].on_timer(pause_soil, 15)
		check(core_mock.get_node(pause_soil).name == grug_farming.SOIL_DRY and
			not core_mock.get_node_timer(pause_crop):is_started() and
			core_mock.get_meta(pause_crop):get_float("wet_progress") == 75,
			"dry transition did not persist partial wet progress")
		-- Soil activation after reload must not restart the crop while dry. Once
		-- water returns, the soil callback resumes exactly the stored remainder.
		core_mock.get_node_timer(pause_soil):stop()
		lbms[1].action(pause_soil)
		check(not core_mock.get_node_timer(pause_crop):is_started(),
			"dry reload restarted crop growth")
		world[key(pause_water)] = {name = "default:water_source"}
		core_mock.registered_nodes[grug_farming.SOIL_DRY].on_timer(pause_soil, 15)
		check(core_mock.get_node(pause_soil).name == grug_farming.SOIL_WET and
			core_mock.get_node_timer(pause_crop):is_started() and
			core_mock.get_node_timer(pause_crop).elapsed == 75,
			"wet resume lost persisted progress")

		local function protected_case(offset, protect_under, protect_above)
			local under, above, water = pos(600 + offset, 0, 0),
				pos(600 + offset, 1, 0), pos(603 + offset, 0, 0)
			world[key(under)], world[key(above)], world[key(water)] =
				{name = grug_farming.SOIL_DRY}, {name = "air"},
				{name = "default:water_source"}
			protected[key(under)], protected[key(above)] = protect_under, protect_above
			local seeds = stack(crop.seed)
			core_mock.registered_items[crop.seed].on_place(seeds, player,
				{type = "node", under = under, above = above})
			check(seeds.count == 1 and core_mock.get_node(under).name == grug_farming.SOIL_DRY and
				core_mock.get_node(above).name == "air" and not timers[key(under)],
				"protected planting mutated soil/crop/timer")
			return key(protect_under and under or above)
		end
		local under_violation = protected_case(0, true, false)
		local above_violation = protected_case(10, false, true)
		check(violations[#violations - 1] == under_violation and
			violations[#violations] == above_violation,
			"protection violation recorded at wrong touched position")
		return table.concat({"r10_farming\tPASS\n", "families\t17\n",
			"full_loops\t17\n", "vm_timer_activation\tidempotent+reload\n",
			"dry_pause_resume\tpersisted_75\n",
			"protected_touched_positions\tunder+above\n"})
	end)
	restore()
	if not ok then error(result, 0) end
	return result
end
