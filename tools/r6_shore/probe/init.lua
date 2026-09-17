-- Disposable engine probe for the round-6 shore contract. The headless
-- launcher stages this mod into an isolated fresh game; it is never shipped.

grug_r6_shore_probe = {}

local CASES = {
	{id = "hearthpine_start", min_x = -1864, max_x = -1737,
		min_z = -2614, max_z = -2487},
	{id = "dawnmere_start", min_x = 30, max_x = 110,
		min_z = -2505, max_z = -2370},
	{id = "goldmead_river", min_x = -60, max_x = 60,
		min_z = -2120, max_z = -2020},
}

local DIRECTIONS = {
	{x = 1, z = 0},
	{x = -1, z = 0},
	{x = 0, z = 1},
	{x = 0, z = -1},
}

local function fail(message)
	error("grug_r6_shore_probe: " .. message, 0)
end

local function is_liquid(name)
	local def = core.registered_nodes[name]
	return def and def.liquidtype and def.liquidtype ~= "none"
end

local function liquid_surface_y(x, z, bed_y)
	local surface_y
	for y = bed_y + 1, bed_y + 32 do
		local name = core.get_node({x = x, y = y, z = z}).name
		if is_liquid(name) then
			surface_y = y
		elseif surface_y then
			break
		end
	end
	return surface_y
end

local totals = {contacts = 0, same = 0, plus_one = 0, below = 0, other = 0,
	water_columns = 0, node_reads = 0}

local function scan(case)
	local counts = {contacts = 0, same = 0, plus_one = 0, below = 0,
		other = 0, water_columns = 0}
	for z = case.min_z, case.max_z do
		for x = case.min_x, case.max_x do
			if grug_zones.water_class_at(x, z) ~= "land" then
				local bed_y = grug_zones.terrain_height_at(x, z)
				local water_y = liquid_surface_y(x, z, bed_y)
				if water_y then
					counts.water_columns = counts.water_columns + 1
					for direction_index = 1, #DIRECTIONS do
						local direction = DIRECTIONS[direction_index]
						local land_x = x + direction.x
						local land_z = z + direction.z
						if grug_zones.water_class_at(land_x, land_z) == "land" then
							local land_y = grug_zones.terrain_height_at(land_x, land_z)
							local node = core.get_node({x = land_x, y = land_y,
								z = land_z})
							local def = core.registered_nodes[node.name]
							if not def or not def.walkable or is_liquid(node.name) then
								fail("land surface is not a walkable dry node at " ..
									land_x .. "," .. land_y .. "," .. land_z ..
									": " .. node.name)
							end
							local delta = land_y - water_y
							counts.contacts = counts.contacts + 1
							if delta == 0 then counts.same = counts.same + 1
							elseif delta == 1 then counts.plus_one = counts.plus_one + 1
							elseif delta < 0 then counts.below = counts.below + 1
							else counts.other = counts.other + 1 end
						end
					end
				end
			end
		end
	end
	for key, value in pairs(counts) do totals[key] = totals[key] + value end
	core.log("action", table.concat({"GRUG_R6_SHORE", "case=" .. case.id,
		"contacts=" .. counts.contacts, "water_y=" .. counts.same,
		"water_y_plus_1=" .. counts.plus_one, "below=" .. counts.below,
		"other=" .. counts.other, "water_columns=" .. counts.water_columns}, " "))
end

local finished = false

local function finish()
	if totals.contacts < 200 then
		fail("fewer than 200 water/land adjacencies were sampled")
	end
	core.log("action", table.concat({"GRUG_R6_SHORE", "total",
		"contacts=" .. totals.contacts, "water_y=" .. totals.same,
		"water_y_plus_1=" .. totals.plus_one, "below=" .. totals.below,
		"other=" .. totals.other, "water_columns=" .. totals.water_columns}, " "))
	finished = true
	core.request_shutdown("round-6 shore probe complete", false, 0.1)
end

local emerge_case

emerge_case = function(index)
	local case = CASES[index]
	if not case then finish() return end
	local failed, done = false, false
	core.emerge_area(
		{x = case.min_x - 1, y = -40, z = case.min_z - 1},
		{x = case.max_x + 1, y = 120, z = case.max_z + 1},
		function(_, action, remaining)
			if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
				failed = true
			end
			if remaining == 0 and not done then
				done = true
				if failed then fail("emerge failed for " .. case.id) end
				scan(case)
				core.after(0, function() emerge_case(index + 1) end)
			end
		end)
end

local function wait_for_starts()
	local ready, total = grug_core.starts_ready()
	if ready == total then emerge_case(1)
	else core.after(0.25, wait_for_starts) end
end

core.register_on_mods_loaded(function()
	core.after(0, wait_for_starts)
	core.after(118, function()
		if not finished then
			core.request_shutdown("round-6 shore probe timeout", true, 0)
		end
	end)
end)
