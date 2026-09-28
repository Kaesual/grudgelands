-- Disposable Round 23 Phase 2 render probe (staged by tools/r23_tree_line/
-- run_dump.sh only; never shipped). Emerges the boxes listed in boxes.txt
-- (`name x0 z0 x1 z1` per line), dumps every non-air node from three below
-- the planned terrain up to the box top as TSV (x, y, z relative to the box
-- corner, name, param2) into the world folder, counts the surface classes,
-- then requests a normal shutdown.
local modpath = core.get_modpath(core.get_current_modname())
local boxes = {}
local listing = assert(io.open(modpath .. "/boxes.txt", "r"))
local text = listing:read("*a")
listing:close()
for line in text:gmatch("[^\n]+") do
	local name, x0, z0, x1, z1 = line:match("^(%S+)%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)")
	if name then
		boxes[#boxes + 1] = {name = name, x0 = tonumber(x0), z0 = tonumber(z0),
			x1 = tonumber(x1), z1 = tonumber(z1)}
	end
end

local function log(text) core.log("action", "[r23d] " .. text) end

local function dump(box)
	local source = grug_mapgen.wp40.planner_source
	local t0 = core.get_us_time()
	local air = core.get_content_id("air")
	local ignore = core.get_content_id("ignore")
	local names = {}
	local file = assert(io.open(core.get_worldpath() .. "/r23_dump_" .. box.name .. ".tsv", "w"))
	local stats, count, ignored = {}, 0, 0
	-- one column: every non-air node from the box top down to three below
	-- the planned terrain; the topmost node at or below terrain + 1 counts
	-- as the column's surface
	local function column(area, data, param2, x, z)
		local _, _, _, _, _, terrain_y = source.column_values_at(x, z)
		local top_name
		for y = box.y1, math.max(box.y0, terrain_y - 3), -1 do
			local i = area:index(x, y, z)
			local cid = data[i]
			if cid == ignore then
				ignored = ignored + 1
			elseif cid ~= air then
				local name = names[cid]
				if not name then
					name = core.get_name_from_content_id(cid)
					names[cid] = name
				end
				if not top_name and y <= terrain_y + 1 then top_name = name end
				file:write(x - box.x0, "\t", y, "\t", z - box.z0, "\t", name, "\t",
					param2[i], "\n")
				count = count + 1
			end
		end
		if top_name then stats[top_name] = (stats[top_name] or 0) + 1 end
	end
	-- strips of 16 rows keep each VoxelManip small
	for strip = box.z0, box.z1, 16 do
		local last = math.min(box.z1, strip + 15)
		local vm = VoxelManip()
		local e1, e2 = vm:read_from_map({x = box.x0, y = box.y0, z = strip},
			{x = box.x1, y = box.y1, z = last})
		local area = VoxelArea(e1, e2)
		local data, param2 = vm:get_data(), vm:get_param2_data()
		for z = strip, last do
			for x = box.x0, box.x1 do column(area, data, param2, x, z) end
		end
	end
	file:close()
	local keys = {}
	for name in pairs(stats) do keys[#keys + 1] = name end
	table.sort(keys, function(a, b) return stats[a] > stats[b] end)
	local top = {}
	for i = 1, math.min(8, #keys) do top[#top + 1] = keys[i] .. "=" .. stats[keys[i]] end
	log(("dump %s %d,%d..%d,%d y %d..%d: %d nodes, %d ignore, %.1f s; tops %s"):format(
		box.name, box.x0, box.z0, box.x1, box.z1, box.y0, box.y1, count, ignored,
		(core.get_us_time() - t0) / 1e6, table.concat(top, " ")))
end

local started = false
local pending = 0
local function start()
	local source = grug_mapgen.wp40.planner_source
	for _, box in ipairs(boxes) do
		local lo, hi = math.huge, -math.huge
		for z = box.z0, box.z1, 4 do
			for x = box.x0, box.x1, 4 do
				local _, _, _, _, _, y = source.column_values_at(x, z)
				lo, hi = math.min(lo, y), math.max(hi, y)
			end
		end
		box.y0, box.y1 = lo - 8, hi + 40
		pending = pending + 1
		local t0 = core.get_us_time()
		log(("emerge %s y %d..%d"):format(box.name, box.y0, box.y1))
		core.emerge_area({x = box.x0, y = box.y0, z = box.z0},
			{x = box.x1, y = box.y1, z = box.z1}, function(_, _, remaining)
				if remaining == 0 then
					log(("emerged %s in %.1f s"):format(box.name, (core.get_us_time() - t0) / 1e6))
					dump(box)
					pending = pending - 1
					if pending == 0 then
						log("all dumps written")
						core.request_shutdown("r23 dump complete", false, 0)
					end
				end
			end)
	end
end

-- With the verify patch (run_dump.sh VERIFY_REGION), wait until the region's
-- full columns are prepared (at most 240 s), then dump.
local verify = core.settings:get_bool("r23_verify", false)
local waited = 0
core.register_globalstep(function(dtime)
	if started then return end
	if verify then
		waited = waited + dtime
		local status = grug_core.world_preparation_status()
		if not status.ready and waited < 240 then return end
		log(("preparation ready=%s completed=%d/%d after %.0f s"):format(
			tostring(status.ready), status.completed, status.total, waited))
	end
	started = true
	core.after(2, start)
end)
