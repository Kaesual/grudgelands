-- Disposable engine probe of Round 70 lane SPAWN. Never shipped: staged with
-- PROBE= on tools/luanti_headless.sh. The harness cannot see native
-- decorations, so this emerges two cave regions per source, counts the plants
-- and the open cave floors of their host rocks, prints the rates and stops.
local P = "[r70_caves] "
local REGIONS = {
	{key = "cave_cap", node = "grug_mapgen:cave_cap_source",
		hosts = {"default:stone", "grug_materials:t2_stone", "grug_materials:t3_stone",
			"grug_materials:t4_stone"},
		boxes = {{x = -640, y = -500, z = -1440}, {x = 640, y = -500, z = 1360}}, height = 400},
	{key = "ember_moss", node = "grug_mapgen:ember_moss_source",
		hosts = {"grug_materials:t5_stone"},
		boxes = {{x = -640, y = -940, z = -1440}, {x = 640, y = -940, z = 1360}}, height = 240},
}
local SIDE = 240
local jobs = {}
for _, region in ipairs(REGIONS) do
	for _, box in ipairs(region.boxes) do jobs[#jobs + 1] = {region = region, box = box} end
end

local function run(index)
	local job = jobs[index]
	if not job then
		print(P .. "done")
		core.request_shutdown()
		return
	end
	local region, box = job.region, job.box
	local minp = {x = box.x, y = box.y, z = box.z}
	local maxp = {x = box.x + SIDE - 1, y = box.y + region.height - 1, z = box.z + SIDE - 1}
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		local vm = core.get_voxel_manip()
		vm:read_from_map(minp, maxp)
		local plants = #core.find_nodes_in_area(minp, maxp, {region.node})
		local floors = #core.find_nodes_in_area_under_air(minp, maxp, region.hosts)
		print(P .. ("%s box %d,%d,%d: %d plants, %d open floors (1 in %s), %.0f s"):format(
			region.key, box.x, box.y, box.z, plants, floors,
			plants > 0 and ("%.0f"):format((floors + plants) / plants) or "none",
			(core.get_us_time() - started) / 1000000))
		run(index + 1)
	end)
end

core.after(2, function() run(1) end)
