-- Lane MGPROF engine probe (disposable, never shipped): generates a fixed,
-- small list of mapchunks one at a time so the stage timer of
-- tools/mgprof/stages.patch (GRUG_MGPROF lines, emerge environment) and the
-- engine profiler (profiler_print_interval = 1, info level on the console)
-- each see exactly one chunk per window.
--
-- Flow: wait until the world preparation (starts preload) has finished, so
-- the single emerge thread is idle; check the two measured chunk columns
-- (every one of their 6400 columns: land, no river, no functional or hard
-- foundation, no road; logged); then generate the warm-up chunk and the
-- measured chunks in order, GAP seconds apart, logging a request and a done
-- line per chunk; then shut the server down. A chunk that does not come back
-- EMERGE_GENERATED (for instance one left on disk by an earlier boot) is
-- reported as NOT_FRESH and fails the run.
--
-- config.lua (written next to this file by tools/mgprof/run.sh) returns
-- {totals_only = bool}. COLUMNS below are pinned (seed 12345); with
-- COLUMNS = nil the probe picks two columns itself (pick_columns) and logs
-- them -- that is how the pinned pair was found.

local PREFIX = "[mgprof_probe] "
local GAP = 2.5 -- seconds between a chunk's completion and the next request
local modpath = core.get_modpath(core.get_current_modname())
local config = {}
do
	local chunk = loadfile(modpath .. "/config.lua")
	if chunk then config = chunk() end
end
local function log(message) core.log("action", PREFIX .. message) end

-- First-start timing (lane MEAS): epoch seconds (os.time) anchor the probe to
-- the launcher's server.conf mtime (run.sh: launch_epoch); get_us_time
-- deltas from the first server step time the preparation precisely. The
-- preparation listener sees "ready" within one 0.2 s notification.
local step_us
log(("loaded epoch=%d cpu_s=%.1f"):format(os.time(), os.clock()))
core.after(0, function()
	step_us = core.get_us_time()
	log(("first server step epoch=%d cpu_s=%.1f"):format(os.time(), os.clock()))
end)
local function step_wall_s()
	return step_us and (core.get_us_time() - step_us) / 1e6 or -1
end
local prepared = false
grug_core.register_on_preparation_progress(function(status)
	if prepared or not status.ready then return end
	prepared = true
	log(("preparation complete chunks=%d step_wall_s=%.2f cpu_s=%.1f epoch=%d"):format(
		status.total, step_wall_s(), os.clock(), os.time()))
end)

-- Before the dedicated server loop starts (it reads the interval once).
core.settings:set("profiler_print_interval", "1")
core.settings:set("grug_mgprof_totals_only", config.totals_only and "true" or "false")

-- Chunk origins (chunksize 5): -32 + 80k on every axis.
local HEIGHTS = {S1 = -32, S2 = 48, B = -112, U1 = -192, U3 = -512, U6 = -1072}
-- Two ordinary land chunk columns {x, z} (minp corners); nil = pick. Pinned
-- from the pick of the lane's first boot (seed 12345): A grug_meadows,
-- terrain y 34..65; B mostly grug_deep_forest, terrain y 48..84.
local COLUMNS = {{368, -2352}, {528, -2192}}
local ORDER_A = {"S1", "S2", "B", "U1", "U3", "U6"}
local ORDER_B = {"U6", "U1", "B"}

local function column_report(x0, z0)
	local source = grug_mapgen.wp40.planner_source
	local stats = {columns = 0, land = 0, river = 0, functional = 0, hard = 0,
		road = 0, protected = 0, tmin = math.huge, tmax = -math.huge, s2 = 0,
		biomes = {}, zones = {}}
	for z = z0, z0 + 79 do
		for x = x0, x0 + 79 do
			local water_class, _, zone_id, biome, _, terrain_y, _, river_id, _,
				functional_kind, _, _, _, _, _, _, _, _, _, hard_foundation =
					source.column_values_at(x, z)
			stats.columns = stats.columns + 1
			if water_class == "land" then stats.land = stats.land + 1 end
			if river_id ~= nil then stats.river = stats.river + 1 end
			if functional_kind ~= nil then stats.functional = stats.functional + 1 end
			if hard_foundation then stats.hard = stats.hard + 1 end
			if source.road_column_at(x, z) ~= nil then stats.road = stats.road + 1 end
			if grug_zones.hard_protection_kind_at({x = x, y = terrain_y, z = z}) then
				stats.protected = stats.protected + 1
			end
			if terrain_y < stats.tmin then stats.tmin = terrain_y end
			if terrain_y > stats.tmax then stats.tmax = terrain_y end
			if terrain_y >= 48 then stats.s2 = stats.s2 + 1 end
			stats.biomes[tostring(biome)] = (stats.biomes[tostring(biome)] or 0) + 1
			stats.zones[tostring(zone_id)] = (stats.zones[tostring(zone_id)] or 0) + 1
		end
	end
	local function top(map)
		local best, count = nil, -1
		for key, n in pairs(map) do
			if n > count or (n == count and key < best) then best, count = key, n end
		end
		return best, count
	end
	stats.biome, stats.biome_n = top(stats.biomes)
	stats.zone = top(stats.zones)
	stats.ordinary = stats.land == stats.columns and stats.river == 0 and
		stats.functional == 0 and stats.hard == 0 and stats.road == 0 and
		stats.protected == 0
	return stats
end

local function describe(tag, x0, z0, s)
	log(("column %s x %d..%d z %d..%d: zone %s, biome %s (%d of 6400), terrain y " ..
		"%d..%d (%d columns at y >= 48), land %d, river %d, functional %d, " ..
		"hard foundation %d, road %d, hard-protected %d -> %s"):format(tag, x0,
		x0 + 79, z0, z0 + 79, tostring(s.zone), tostring(s.biome), s.biome_n,
		s.tmin, s.tmax, s.s2, s.land, s.river, s.functional, s.hard, s.road,
		s.protected, s.ordinary and "ordinary" or "NOT ordinary"))
end

-- Cheap pre-screen on a 5 x 5 sample, then the full 6400-column check.
local function pick_columns()
	local source = grug_mapgen.wp40.planner_source
	local function sample_ok(x0, z0)
		for dz = 0, 4 do
			for dx = 0, 4 do
				local x, z = x0 + dx * 19 + 2, z0 + dz * 19 + 2
				local water_class, _, _, _, _, terrain_y, _, river_id, _,
					functional_kind = source.column_values_at(x, z)
				if water_class ~= "land" or river_id ~= nil or functional_kind ~= nil or
						terrain_y < 4 or terrain_y > 120 then
					return false
				end
			end
		end
		return true
	end
	local ordinary = {}
	local function choose()
		local first
		for _, row in ipairs(ordinary) do
			if row.hill then first = row break end
		end
		if not first then
			first = ordinary[1]
			if first then log("no hill column found; A is the first ordinary column") end
		end
		if not first then return nil end
		for _, row in ipairs(ordinary) do
			if row.s.biome ~= first.s.biome then
				return {first.x, first.z}, {row.x, row.z}
			end
		end
		return nil
	end
	local checked = 0
	for ring = 0, 30 do
		for kz = -ring, ring do
			for kx = -ring, ring do
				if math.max(math.abs(kx), math.abs(kz)) == ring then
					-- around (368, -2352), a land column of seed 12345 (tools/r46_or)
					local x0, z0 = 368 + kx * 160, -2352 + kz * 160
					if x0 >= -3600 and x0 <= 3520 and z0 >= -3200 and z0 <= 3120 and
							sample_ok(x0, z0) then
						checked = checked + 1
						local s = column_report(x0, z0)
						if s.ordinary then
							ordinary[#ordinary + 1] = {x = x0, z = z0, s = s,
								hill = s.s2 >= 640 and s.s2 <= 5760}
							local a, b = choose()
							local has_hill = false
							for _, row in ipairs(ordinary) do
								if row.hill then has_hill = true end
							end
							if a and has_hill then
								log("picked after " .. checked .. " full checks")
								return a, b
							end
						end
						if checked >= 40 then
							log("stopped picking after " .. checked .. " full checks")
							return choose()
						end
					end
				end
			end
		end
	end
	return choose()
end

-- The cost of one P8 frontier rank digest (helpers.digest11: an 11-field
-- framed string through core.sha256), measured with the shipped r6_hash.lua
-- in this process, to turn the boot's digest counts into milliseconds.
local function bench_digest()
	local hash = dofile(core.get_modpath("grug_mapgen") .. "/wp40/r6_hash.lua")(
		function(bytes) return core.sha256(bytes, true) end)
	local fields = {"iron", 22, -63, -145, "grug_materials:t2_stone", 2, 0, 7,
		360, -1001, -2300}
	local n = 20000
	local t0 = core.get_us_time()
	for index = 1, n do
		fields[8] = index
		hash.digest_count("resource_frontier_rank_v1", "12345", fields, 11)
	end
	log(("bench digest11 n=%d us_per_call=%.2f"):format(n,
		(core.get_us_time() - t0) / n))
end

-- Insecure diagnostic boots only (io.open outside the world is refused in
-- the sandbox): the process's executable mappings, to locate the LuaJIT
-- library and the anonymous machine-code areas the emerge log's
-- jit_mcode_min addresses fall into.
local function log_maps()
	local file = io.open("/proc/self/maps", "r")
	if not file then return end
	local exec_anon, lines = 0, {}
	for line in file:lines() do
		local range, perms, path = line:match("^(%S+)%s+(%S+)%s+%S+%s+%S+%s+%S+%s*(.*)$")
		if perms and perms:sub(3, 3) == "x" then
			if path == "" then
				exec_anon = exec_anon + 1
				lines[#lines + 1] = "anon " .. range
			elseif path:find("luajit") or path:find("luanti") then
				lines[#lines + 1] = (path:match("([^/]+)$") or path) .. " " .. range
			end
		end
	end
	file:close()
	log(("maps: %d anonymous executable mappings; %s"):format(exec_anon,
		table.concat(lines, "; ")))
end

local function finish(ok, message)
	pcall(bench_digest)
	pcall(log_maps)
	-- os.clock(): CPU seconds of the whole server process (all threads) so far.
	log(("cpu_s=%.1f at the end step_wall_s=%.2f epoch=%d"):format(os.clock(),
		step_wall_s(), os.time()))
	log(("RESULT %s %s"):format(ok and "PASS" or "FAIL", message))
	core.request_shutdown("mgprof probe done", false, 0)
end

local function run_chunks(list)
	local index = 0
	local function step()
		index = index + 1
		local row = list[index]
		if not row then
			-- one more profiler window after the last chunk, then stop
			core.after(GAP, function() finish(true, #list .. " chunks") end)
			return
		end
		local p = {x = row.x + 8, y = row.y + 8, z = row.z + 8}
		log(("request id=%s minp=%d,%d,%d"):format(row.id, row.x, row.y, row.z))
		local t0 = core.get_us_time()
		core.emerge_area(p, p, function(_, action, remaining)
			if remaining ~= 0 then return end
			local wall = (core.get_us_time() - t0) / 1000
			local fresh = action == core.EMERGE_GENERATED
			log(("done id=%s minp=%d,%d,%d action=%d wall_ms=%.1f%s"):format(row.id,
				row.x, row.y, row.z, action, wall, fresh and "" or " NOT_FRESH"))
			if not fresh then
				finish(false, "chunk " .. row.id .. " was not generated fresh")
				return
			end
			core.after(GAP, step)
		end)
	end
	step()
end

local function start()
	local a, b
	if COLUMNS then
		a, b = COLUMNS[1], COLUMNS[2]
	else
		a, b = pick_columns()
		if not a then return finish(false, "no column pair found") end
	end
	local sa, sb = column_report(a[1], a[2]), column_report(b[1], b[2])
	describe("A", a[1], a[2], sa)
	describe("B", b[1], b[2], sb)
	if not (sa.ordinary and sb.ordinary) then
		return finish(false, "a measured column is not ordinary land")
	end
	-- The warm-up chunk: three chunk columns east of A, at the B height.
	local warm = {a[1] + 240, a[2]}
	-- Columns whose blocks tools/mgprof/reset_columns.py deletes before a
	-- re-used world's next boot (every chunk here must generate fresh).
	core.safe_file_write(core.get_worldpath() .. "/mgprof_columns.txt",
		("%d %d\n%d %d\n%d %d\n"):format(a[1], a[2], b[1], b[2], warm[1], warm[2]))
	local list = {{id = "warmup", x = warm[1], y = HEIGHTS.B, z = warm[2]}}
	for _, id in ipairs(ORDER_A) do
		list[#list + 1] = {id = "A_" .. id, x = a[1], y = HEIGHTS[id], z = a[2]}
	end
	for _, id in ipairs(ORDER_B) do
		list[#list + 1] = {id = "B_" .. id, x = b[1], y = HEIGHTS[id], z = b[2]}
	end
	log(("mode=%s chunks=%d gap=%.1fs"):format(config.totals_only and "totals" or
		"stages", #list, GAP))
	run_chunks(list)
end

-- Wait for the starts preload (first boot of a world) so nothing else uses the
-- emerge thread, then start.
local waited = 0
local function wait_ready()
	local status = grug_core.world_preparation_status()
	if status.failed then return finish(false, "world preparation failed") end
	if status.ready then
		log(("preparation ready after %.0f s of waiting (%d/%d chunks), cpu_s=%.1f"):format(
			waited, status.completed, status.total, os.clock()))
		core.after(GAP, start)
		return
	end
	if waited % 15 == 0 then
		log(("waiting for preparation %d/%d"):format(status.completed, status.total))
	end
	waited = waited + 1
	core.after(1, wait_ready)
end
core.after(1, wait_ready)
