-- Round 82 lane BASE engine probe (disposable, never shipped; staged by
-- tools/r82_gen/region.sh): on a fresh world, waits for the world
-- preparation, then generates the chunks of region.txt (staged next to this
-- file; "x y z label" minp per line) one at a time in file order, timing
-- each from its request to its completion (wall and process CPU), waits
-- SETTLE seconds, hashes every chunk read back from the map (nodes by name
-- with param2, light, metadata) and shuts the server down.
--
-- Log lines (prefix "[r82_region] "): "prep ready ..." (the time to a ready
-- world), one "chunk ..." per request (action 4 = generated fresh;
-- otherwise NOT_FRESH, kept out of the totals), "gen ..." (the totals), one
-- "hash ..." per chunk, "region ..." (the region's hashes) and "RESULT".

local PREFIX = "[r82_region] "
local SETTLE = 10 -- seconds between the last chunk and the read-back
local modpath = core.get_modpath(core.get_current_modname())
local function log(message) core.log("action", PREFIX .. message) end

local probe_us = core.get_us_time()
local step_us
log(("loaded epoch=%d cpu_s=%.2f"):format(os.time(), os.clock()))
core.after(0, function()
	step_us = core.get_us_time()
	log(("first server step epoch=%d cpu_s=%.2f since_load_s=%.2f"):format(os.time(),
		os.clock(), (step_us - probe_us) / 1e6))
end)

local list = {}
do
	local file = assert(io.open(modpath .. "/region.txt", "r"))
	for line in file:lines() do
		local x, y, z, label = line:match("^(%-?%d+) (%-?%d+) (%-?%d+) (.*)$")
		if x then
			list[#list + 1] = {x = tonumber(x), y = tonumber(y), z = tonumber(z), label = label}
		end
	end
	file:close()
end

local function finish(ok, message)
	log(("RESULT %s %s"):format(ok and "PASS" or "FAIL", message))
	core.request_shutdown("r82 region probe done", false, 0)
end

-- A content id's stable number: from its name (ids are this process's own).
local stable = {}
local function stable_id(cid)
	local value = stable[cid]
	if not value then
		value = tonumber(core.sha256(core.get_name_from_content_id(cid)):sub(1, 7), 16)
		stable[cid] = value
	end
	return value
end

local function canonical(value, out)
	if type(value) == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			out[#out + 1] = tostring(key) .. "="
			local v = value[key]
			if type(v) == "userdata" and v.to_string then v = v:to_string() end
			canonical(v, out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = ("%q"):format(tostring(value))
	end
	return out
end

-- The hashes of one chunk read back from the map.
local function hash_chunk(row)
	local minp = {x = row.x, y = row.y, z = row.z}
	local maxp = {x = row.x + 79, y = row.y + 79, z = row.z + 79}
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data, param2, light = vm:get_data(), vm:get_param2_data(), vm:get_light_data()
	local a, b, la, lb = 7, 11, 7, 11
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local i = area:index(minp.x, y, z)
			for _ = minp.x, maxp.x do
				local v = stable_id(data[i]) * 256 + param2[i]
				a = (a * 31 + v) % 2147483647
				b = (b * 37 + v) % 2147483629
				la = (la * 31 + light[i]) % 2147483647
				lb = (lb * 37 + light[i]) % 2147483629
				i = i + 1
			end
		end
	end
	local positions = core.find_nodes_with_meta(minp, maxp)
	table.sort(positions, function(p, q)
		if p.z ~= q.z then return p.z < q.z end
		if p.y ~= q.y then return p.y < q.y end
		return p.x < q.x
	end)
	local parts = {}
	for _, pos in ipairs(positions) do
		parts[#parts + 1] = ("%d,%d,%d"):format(pos.x, pos.y, pos.z)
		canonical(core.get_meta(pos):to_table(), parts)
	end
	local meta = #positions == 0 and "0" or
		#positions .. ":" .. core.sha256(table.concat(parts)):sub(1, 16)
	return ("%08x%08x"):format(a, b), ("%08x%08x"):format(la, lb), meta
end

local function read_back()
	local started = core.get_us_time()
	local nodes, lights = {}, {}
	for index, row in ipairs(list) do
		local n, l, m = hash_chunk(row)
		log(("hash id=%d minp=%d,%d,%d nodes=%s light=%s meta=%s"):format(index, row.x, row.y,
			row.z, n, l, m))
		nodes[#nodes + 1] = ("%d,%d,%d %s %s"):format(row.x, row.y, row.z, n, m)
		lights[#lights + 1] = l
	end
	log(("region chunks=%d nodes_meta=%s light=%s read_s=%.1f"):format(#list,
		core.sha256(table.concat(nodes, "\n")), core.sha256(table.concat(lights, "\n")),
		(core.get_us_time() - started) / 1e6))
end

local function run_chunks()
	local index, fresh = 0, 0
	local sum_wall, sum_cpu = 0, 0
	local first_us = core.get_us_time()
	local function step()
		index = index + 1
		local row = list[index]
		if not row then
			log(("gen chunks=%d fresh=%d sum_wall_s=%.2f sum_cpu_s=%.2f span_wall_s=%.2f"):format(
				#list, fresh, sum_wall, sum_cpu, (core.get_us_time() - first_us) / 1e6))
			core.after(SETTLE, function()
				local ok, err = pcall(read_back)
				if not ok then return finish(false, "read-back failed: " .. tostring(err)) end
				finish(fresh == #list, ("%d chunks, %d fresh"):format(#list, fresh))
			end)
			return
		end
		local p = {x = row.x + 8, y = row.y + 8, z = row.z + 8}
		local t0, c0 = core.get_us_time(), os.clock()
		core.emerge_area(p, p, function(_, action, remaining)
			if remaining ~= 0 then return end
			local wall, cpu = (core.get_us_time() - t0) / 1e6, os.clock() - c0
			local ok = action == core.EMERGE_GENERATED
			if ok then
				fresh = fresh + 1
				sum_wall, sum_cpu = sum_wall + wall, sum_cpu + cpu
			end
			log(("chunk id=%d minp=%d,%d,%d action=%d wall_ms=%.1f cpu_ms=%.1f %s%s"):format(index,
				row.x, row.y, row.z, action, wall * 1000, cpu * 1000, row.label,
				ok and "" or " NOT_FRESH"))
			core.after(0, step)
		end)
	end
	step()
end

-- Wait for the world preparation (the starts preload of a fresh world), so
-- nothing else uses the emerge thread, then generate.
local function wait_ready()
	local status = grug_core.world_preparation_status()
	if status.failed then return finish(false, "world preparation failed") end
	if status.ready then
		log(("prep ready epoch=%d cpu_s=%.2f since_step_s=%.2f chunks=%d"):format(os.time(),
			os.clock(), step_us and (core.get_us_time() - step_us) / 1e6 or -1, status.total))
		if #list == 0 then return finish(false, "no region.txt rows") end
		run_chunks()
		return
	end
	core.after(0.2, wait_ready)
end
core.after(0, wait_ready)
