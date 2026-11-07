-- Round 70 lane SPAWN: what the water predicates cost the writer, on the
-- seed fleet's harness: the same chunks of the five Stormkelp zones (the only
-- place the 48-neighbour rule runs), a tree against another.
--
--   luajit tools/r70_spawn/chunk_cost.lua REPO SEED [CHUNKS_PER_ZONE]
--
-- Prints the CPU seconds of `plan_slice` and of the writer per zone and in
-- total. The chunks come from the planner, so two trees with the same planner
-- write the same chunks: compare the totals of one machine under one load.
local repo, seed = arg[1], arg[2]
assert(repo and seed and seed:match("^%d+$"), "usage: chunk_cost.lua REPO SEED [CHUNKS_PER_ZONE]")
local wanted = tonumber(arg[3] or 4)
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local WORLD = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").world_bounds
local ZONES = {"front_gravesalt_escarpment", "front_shattered_line", "front_skyglass_canopy",
	"front_stormscale_summit", "front_wyrmglass_crown"}
local found, seen = {}, {}
for _, zone in ipairs(ZONES) do found[zone] = {} end
for z = WORLD.min_z, WORLD.max_z, 160 do
	for x = WORLD.min_x, WORLD.max_x, 160 do
		local water, _, zone, _, _, ground = R.planner_source.column_values_at(x, z)
		local list = found[zone or ""]
		if water == "land" and list and #list < wanted and ground >= 1 then
			local chunk = {x = R.origin(x), y = R.origin(ground), z = R.origin(z)}
			local key = chunk.x .. "," .. chunk.y .. "," .. chunk.z
			if not seen[key] then
				seen[key] = true
				list[#list + 1] = chunk
			end
		end
	end
end
local plan_total, write_total = 0, 0
for _, zone in ipairs(ZONES) do
	local plan_seconds, write_seconds = 0, 0
	for _, chunk in ipairs(found[zone]) do
		local result = R.chunk(chunk)
		plan_seconds = plan_seconds + result.plan_seconds
		write_seconds = write_seconds + result.write_seconds
	end
	print(("%-28s %d chunks: plan %.2fs, write %.2fs"):format(zone, #found[zone], plan_seconds,
		write_seconds))
	plan_total, write_total = plan_total + plan_seconds, write_total + write_seconds
end
print(("total: plan %.2fs, write %.2fs"):format(plan_total, write_total))
