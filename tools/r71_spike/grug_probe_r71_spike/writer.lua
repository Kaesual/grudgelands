-- The ways to write a box. A job is a list of closures; run() calls `per_step`
-- of them on each `every`-th server step. The pace is a count of steps, never a
-- time: the output does not depend on the clock.
local M = {}
local lib

function M.init(l) lib = l end

local data_buf, param2_buf, light_buf = {}, {}, {}

-- Writes the part of the template between a1 and a2 (absolute, mapblock
-- aligned) with one VoxelManip. `light`: "engine" = write_to_map(true);
-- "none" = write_to_map(false); a flat light array of the template = precomputed
-- param1 and write_to_map(false). Fills M.last with the time of each part.
local function write_area(tpl, slot, a1, a2, light)
	local us = core.get_us_time
	local t0 = us()
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map(a1, a2)
	local t1 = us()
	assert(e1.x == a1.x and e1.y == a1.y and e1.z == a1.z and e2.x == a2.x and e2.y == a2.y and e2.z == a2.z,
		"area not mapblock aligned")
	local data, param2 = tpl.data, tpl.param2
	local rows, w = tpl.rows, tpl.w
	local x0, y0, z0 = a1.x - slot.minp.x, a1.y - slot.minp.y, a1.z - slot.minp.z
	local sx, sy, sz = a2.x - a1.x + 1, a2.y - a1.y + 1, a2.z - a1.z + 1
	local precomputed = type(light) == "table"
	local n = 0
	for z = z0, z0 + sz - 1 do
		for y = y0, y0 + sy - 1 do
			local base = z * rows + y * w + x0
			for x = 1, sx do
				n = n + 1
				data_buf[n] = data[base + x]
				param2_buf[n] = param2[base + x]
				if precomputed then light_buf[n] = light[base + x] end
			end
		end
	end
	local t2 = us()
	vm:set_data(data_buf)
	vm:set_param2_data(param2_buf)
	if precomputed then vm:set_light_data(light_buf) end
	local t3 = us()
	vm:write_to_map(light == "engine")
	local t4 = us()
	local last = M.last
	last.read = last.read + t1 - t0
	last.fill = last.fill + t2 - t1
	last.set = last.set + t3 - t2
	last.write = last.write + t4 - t3
end
M.write_area = write_area

function M.reset_parts() M.last = {read = 0, fill = 0, set = 0, write = 0} end
M.reset_parts()

function M.parts_text()
	local l = M.last
	return ("read %.1f fill %.1f set %.1f write %.1f"):format(l.read / 1000, l.fill / 1000,
		l.set / 1000, l.write / 1000)
end

-- The mapblocks of a box, or its columns, as {a1, a2}.
function M.blocks(slot)
	local list = {}
	for z = slot.minp.z, slot.maxp.z, 16 do
		for x = slot.minp.x, slot.maxp.x, 16 do
			for y = slot.minp.y, slot.maxp.y, 16 do
				list[#list + 1] = {{x = x, y = y, z = z}, {x = x + 15, y = y + 15, z = z + 15}}
			end
		end
	end
	return list
end

function M.columns(slot)
	local list = {}
	for z = slot.minp.z, slot.maxp.z, 16 do
		for x = slot.minp.x, slot.maxp.x, 16 do
			list[#list + 1] = {{x = x, y = slot.minp.y, z = z}, {x = x + 15, y = slot.maxp.y, z = z + 15}}
		end
	end
	return list
end

-- Runs `job` (a list of closures): per_step on every `every`-th step.
function M.run(job, per_step, every)
	local i = 1
	local n = #job
	every = every or 1
	local skip = 0
	while i <= n do
		if skip == 0 then
			lib.timed(function()
				for _ = 1, per_step do
					if i > n then break end
					job[i]()
					i = i + 1
				end
			end)
			skip = every - 1
		else
			skip = skip - 1
		end
		if i <= n then lib.yield() end
	end
end

-- The closures of a VoxelManip writer over `areas`.
function M.vm_job(tpl, slot, areas, light)
	local job = {}
	for k, area in ipairs(areas) do
		job[k] = function() write_area(tpl, slot, area[1], area[2], light) end
	end
	return job
end

-- Reads a box back: its nodes, its light, a hash, and the air nodes that are
-- lit and those whose day and night light differ (sun in the box).
function M.read_box(slot)
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map(slot.minp, slot.maxp)
	local data, param2, light = vm:get_data(), vm:get_param2_data(), vm:get_light_data()
	local hash = 7
	local air, lit, sun = 0, 0, 0
	for i = 1, #data do
		local l = light[i]
		hash = (hash * 31 + data[i] * 7 + param2[i] * 257) % 2147483647
		if data[i] == core.CONTENT_AIR then
			air = air + 1
			local day, night = l % 16, math.floor(l / 16)
			if day > 0 or night > 0 then lit = lit + 1 end
			if day ~= night then sun = sun + 1 end
		end
	end
	assert(e2.x - e1.x + 1 == slot.w)
	return {hash = hash, light = light, data = data, air = air, lit = lit, sun = sun}
end

-- The box against its template: nodes that differ (the first few named) and,
-- on air, light brighter or darker than `truth`.
function M.verify(lib, label, slot, tpl, truth)
	local got = M.read_box(slot)
	local AIR = core.CONTENT_AIR
	local rows, w = tpl.rows, tpl.w
	local nodes, brighter, darker, worst = 0, 0, 0, 0
	local samples = {}
	for i = 1, #got.data do
		local want = tpl.data[i]
		if got.data[i] ~= want then
			nodes = nodes + 1
			if #samples < 8 then
				local at = i - 1
				local z = math.floor(at / rows)
				local y = math.floor((at - z * rows) / w)
				samples[#samples + 1] = ("%d,%d,%d %s~=%s"):format(at % w, y, z,
					core.get_name_from_content_id(got.data[i]), core.get_name_from_content_id(want))
			end
		end
		if want == AIR and truth then
			local a, b = got.light[i] % 16, truth[i] % 16
			if a > b then brighter = brighter + 1 elseif a < b then darker = darker + 1 end
			if math.abs(a - b) > worst then worst = math.abs(a - b) end
		end
	end
	lib.logf("VERIFY %s nodes_wrong %d air_brighter %d air_darker %d worst_level %d sun %d %s", label, nodes,
		brighter, darker, worst, got.sun, table.concat(samples, " "))
	return got
end

-- The closures that fill a box with one node, block by block: the clearing
-- pass. Solid, so no liquid in or round the box can move while it is written.
function M.seal_job(slot, name)
	local job = {}
	local solid = core.get_content_id(name)
	local buffer = {}
	for i = 1, 4096 do buffer[i] = solid end
	local zeros = {}
	for i = 1, 4096 do zeros[i] = 0 end
	for k, area in ipairs(M.blocks(slot)) do
		job[k] = function()
			local vm = VoxelManip()
			vm:read_from_map(area[1], area[2])
			vm:set_data(buffer)
			vm:set_param2_data(zeros)
			vm:write_to_map(true)
		end
	end
	return job
end

return M
