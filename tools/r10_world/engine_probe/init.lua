-- Disposable isolated-world probe. Reports actual persisted map output.
local seed = "4151598227737528026"
assert(core.get_mapgen_setting("seed") == seed, "R10 witness seed differs")
local cases = {
	{id = "reported_roof", x = -71, z = -2458, radius = 3},
	{id = "wyrmglass", x = -3160, z = -310, radius = 3},
	{id = "stormscale", x = 3235, z = -310, radius = 3},
	{id = "high_freshwater", x = -2008, z = -80, radius = 3},
	{id = "gravesalt", x = -2500, z = 164, radius = 3},
}
local report, case_index = {"schema\tgrug_r10_world_engine_v1", "seed\t" .. seed}, 0
local function record(...)
	local row = {}
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		row[index] = value == nil and "-" or tostring(value)
	end
	report[#report + 1] = table.concat(row, "\t")
end
local function save()
	assert(core.safe_file_write(core.get_worldpath() .. "/r10-world.tsv",
		table.concat(report, "\n") .. "\n"))
end
local function read_case(case)
	for z = case.z - case.radius, case.z + case.radius do
		for x = case.x - case.radius, case.x + case.radius do
			local terrain = grug_zones.terrain_height_at(x, z)
			local values = {}
			for y = terrain - 4, terrain + 1 do
				local node = core.get_node({x = x, y = y, z = z})
				assert(node.name ~= "ignore", "unemerged witness cell")
				values[#values + 1] = node.name .. ":" .. node.param2
			end
			record("column", case.id, x, terrain, z, grug_zones.water_class_at(x, z),
				grug_zones.biome_at(x, z), table.concat(values, ","))
		end
	end
	save()
	core.log("action", "[R10_WORLD] case complete " .. case.id)
end
local function next_case()
	case_index = case_index + 1
	local case = cases[case_index]
	if not case then
		record("complete", #cases)
		save()
		core.log("action", "[R10_WORLD] COMPLETE")
		core.request_shutdown("R10 world witness complete", false, 0.1)
		return
	end
	local low, high = 31000, -31000
	for z = case.z - case.radius, case.z + case.radius do
		for x = case.x - case.radius, case.x + case.radius do
			local y = grug_zones.terrain_height_at(x, z)
			low, high = math.min(low, y - 4), math.max(high, y + 1)
		end
	end
	core.emerge_area({x = case.x - case.radius, y = low, z = case.z - case.radius},
		{x = case.x + case.radius, y = high, z = case.z + case.radius},
		function(_, action, remaining)
			assert(action ~= core.EMERGE_CANCELLED and action ~= core.EMERGE_ERRORED,
				"R10 witness emerge failed")
			if remaining == 0 then
				core.after(0, function() read_case(case); next_case() end)
			end
		end)
end
core.register_on_mods_loaded(function() core.after(0, next_case) end)
