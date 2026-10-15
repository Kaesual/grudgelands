-- Round 49 lane CACHE engine probe (disposable, never shipped): requests
-- mapchunks in the order the engine's block sender would for players moving
-- over fresh land, one chunk at a time, so the per-callback counters of
-- tools/mgprof/stages.patch plus tools/r49_cache/counters.patch (GRUG_MGPROF
-- lines: column cache misses and evictions, planner cell cache, P9G column
-- cache, start front and surface cave caches, heap) show whether later
-- chunks of a column pay the column cost again.
--
-- The order (RemoteClient::GetNextBlocks, server/clientiface.cpp, engine
-- defaults: max_block_generate_distance 10, max_block_send_distance 12,
-- fov 72 degrees, server-side occlusion culling on): from the block of the
-- player's position predicted one block ahead in its walking direction, the
-- cube shells d = 0..10 in FacePositionCache order; a block counts when it
-- is in sight (isBlockInSight: the camera cone, narrowed by the speed, or
-- the 0.1 rad cone along the movement), its mapchunk is not generated yet,
-- and it is not occluded (Map::isBlockOccluded over the loaded map: two
-- light-blocking nodes on each of its rays). The first such block's chunk
-- is generated next. The players' clock advances by each chunk's measured
-- request-to-done time (they keep moving while the one emerge thread works)
-- and jumps ahead when nothing is left to generate. With two players the
-- picks alternate (the emerge queue interleaves both players' requests).
-- Not modelled: looking around, turning, the per-step d window and the
-- emerge queue's batches; a player looks along its path, level.
--
-- Phases (seed 12345, fresh land away from the starts' preparation):
--   1  one player: stands at its spawn until its view is generated, walks
--      400 nodes east at 4 nodes/s, then rides 400 more at 8 nodes/s;
--   2  two players 600 nodes apart, both stand and then walk 400 nodes east.
-- Each chunk logs a req and a done line; RESULT PASS at the end.
local PREFIX = "[r49cache] "
local function log(message) core.log("action", PREFIX .. message) end
local loaded_us = core.get_us_time()
-- Stop requesting after this many seconds from mod load (the launcher's
-- timeout is longer).
local BUDGET_S = 250

core.settings:set("grug_mgprof_totals_only", "false")
-- No player keeps the probed blocks active: keep them loaded, so the
-- occlusion test sees the generated ground as a player's server would.
core.settings:set("server_unload_unused_data_timeout", "3600")

local GEN_D = 10
local SIGHT_RANGE = 12 * 16
local FOV = 72 * math.pi / 180
local BMR = 8 * math.sqrt(3) -- BLOCK_MAX_RADIUS in nodes
local EYE = 1.625

-- FacePositionCache::generateFacePosition.
local face_cache = {}
local function faces(d)
	local list = face_cache[d]
	if list then return list end
	list = {}
	local function add(x, y, z) list[#list + 1] = {x, y, z} end
	if d == 0 then
		add(0, 0, 0)
	elseif d == 1 then
		add(0, 1, 0) add(0, 0, 1) add(-1, 0, 0) add(1, 0, 0) add(0, 0, -1)
		add(0, -1, 0)
		add(-1, 0, 1) add(1, 0, 1) add(-1, 0, -1) add(1, 0, -1) add(-1, -1, 0)
		add(1, -1, 0) add(0, -1, 1) add(0, -1, -1) add(-1, 1, 0) add(1, 1, 0)
		add(0, 1, 1) add(0, 1, -1)
		add(-1, 1, 1) add(1, 1, 1) add(-1, 1, -1) add(1, 1, -1) add(-1, -1, 1)
		add(1, -1, 1) add(-1, -1, -1) add(1, -1, -1)
	else
		for y = 0, d - 1 do
			for z = -d, d do
				add(d, y, z) add(-d, y, z)
				if y ~= 0 then add(d, -y, z) add(-d, -y, z) end
			end
			for x = -d + 1, d - 1 do
				add(x, y, d) add(x, y, -d)
				if y ~= 0 then add(x, -y, d) add(x, -y, -d) end
			end
		end
		for x = -d, d do
			for z = -d, d do add(x, -d, z) add(x, d, z) end
		end
	end
	face_cache[d] = list
	return list
end

-- floatToInt: round half away from zero.
local function round(value)
	if value > 0 then return math.floor(value + 0.5) end
	return math.ceil(value - 0.5)
end

local function chunk_origin(block)
	return (math.floor((block + 2) / 5) * 5 - 2) * 16
end

-- isBlockInSight (util/numeric.cpp), in node units.
local function in_sight(bx, by, bz, cx, cy, cz, dx, dy, dz, fov)
	local px, py, pz = bx * 16 + 8, by * 16 + 8, bz * 16 + 8
	local rx, ry, rz = px - cx, py - cy, pz - cz
	local distance = math.sqrt(rx * rx + ry * ry + rz * rz) - BMR
	if distance < 0 then distance = 0 end
	if distance > SIGHT_RANGE then return false end
	if distance == 0 then return true end
	local adjust = BMR / math.cos((math.pi - fov) / 2)
	local ax, ay, az = px - (cx - dx * adjust), py - (cy - dy * adjust),
		pz - (cz - dz * adjust)
	local forward = ax * dx + ay * dy + az * dz
	return forward / math.sqrt(ax * ax + ay * ay + az * az) >= math.cos(fov * 0.55)
end

-- Map::isOccluded / isBlockOccluded over the loaded map (an unloaded node
-- is not a valid position and blocks nothing).
local opaque_by_name = {}
local function opaque_at(x, y, z)
	local node = core.get_node_or_nil({x = x, y = y, z = z})
	if not node then return false end
	local opaque = opaque_by_name[node.name]
	if opaque == nil then
		local def = core.registered_nodes[node.name]
		opaque = not (def and def.paramtype == "light")
		opaque_by_name[node.name] = opaque
	end
	return opaque
end

local function occluded(cx, cy, cz, tx, ty, tz, end_offset)
	local dx, dy, dz = tx - cx, ty - cy, tz - cz
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	if distance > 0 then dx, dy, dz = dx / distance, dy / distance, dz / distance end
	local step, offset, count = 1.2, 1.0, 0
	while offset < distance + end_offset do
		if opaque_at(round(cx + dx * offset), round(cy + dy * offset),
				round(cz + dz * offset)) then
			count = count + 1
			if count >= 2 then return true end
		end
		offset = offset + step
		step = step * 1.05
	end
	return false
end

local DIR9 = {{0, 0, 0}, {9, 9, 9}, {9, 9, -9}, {9, -9, 9}, {9, -9, -9},
	{-9, 9, 9}, {-9, 9, -9}, {-9, -9, 9}, {-9, -9, -9}}
local function closest(value, minimum, maximum)
	return value <= minimum and minimum or maximum
end
local function block_occluded(bx, by, bz, cx, cy, cz)
	local x0, y0, z0 = bx * 16, by * 16, bz * 16
	local x1, y1, z1 = x0 + 15, y0 + 15, z0 + 15
	local xin = x0 <= cx and cx <= x1
	local yin = y0 <= cy and cy <= y1
	local zin = z0 <= cz and cz <= z1
	if not (xin and yin and zin) then
		local tx, ty, tz
		if xin and yin then tx, ty, tz = cx, cy, closest(cz, z0, z1)
		elseif yin and zin then tx, ty, tz = closest(cx, x0, x1), cy, cz
		elseif xin and zin then tx, ty, tz = cx, closest(cy, y0, y1), cz
		elseif xin then tx, ty, tz = cx, closest(cy, y0, y1), closest(cz, z0, z1)
		elseif yin then tx, ty, tz = closest(cx, x0, x1), cy, closest(cz, z0, z1)
		elseif zin then tx, ty, tz = closest(cx, x0, x1), closest(cy, y0, y1), cz end
		if tx and not occluded(cx, cy, cz, tx, ty, tz, -1.0) then return false end
	end
	for index = 1, #DIR9 do
		local o = DIR9[index]
		if not occluded(cx, cy, cz, x0 + 8 + o[1], y0 + 8 + o[2], z0 + 8 + o[3],
				-16 * 1.732) then
			return false
		end
	end
	return true
end

local function ground_y(x, z)
	local _, _, _, _, _, terrain_y, water_y =
		grug_mapgen.wp40.planner_source.column_values_at(round(x), round(z))
	if water_y and water_y > terrain_y then return water_y end
	return terrain_y
end

-- A player: spawn (x0, z0), direction (+x), segments {speed, length}; it
-- stands until its first idle pick, then moves along the segments.
local function position(player, clock)
	if not player.moving then return player.x0, player.z0, 0, false end
	local t = clock - player.start_t
	local x, z = player.x0, player.z0
	for _, segment in ipairs(player.segments) do
		local duration = segment[2] / segment[1]
		if t < duration then
			return x + player.dx * segment[1] * t, z + player.dz * segment[1] * t,
				segment[1], false
		end
		x, z = x + player.dx * segment[2], z + player.dz * segment[2]
		t = t - duration
	end
	return x, z, 0, true
end

local done, fresh_count, old_count = {}, 0, 0

-- The next chunk this player's sender would have generated, or nil.
local function pick(player, clock)
	local x, z, speed, finished = position(player, clock)
	local feet = ground_y(x, z) + 0.5
	local px, pz = x, z
	if speed > 1 then px, pz = px + player.dx * 16, pz + player.dz * 16 end
	local cbx, cby, cbz = math.floor(round(px) / 16), math.floor(round(feet) / 16),
		math.floor(round(pz) / 16)
	local ex, ey, ez = x, feet + EYE, z
	local camx, camy, camz = round(ex), round(ey), round(ez)
	local fov = FOV / (1 + math.min(300, speed * 10) / 300)
	for d = 0, GEN_D do
		local list = faces(d)
		for index = 1, #list do
			local o = list[index]
			local bx, by, bz = cbx + o[1], cby + o[2], cbz + o[3]
			local key = chunk_origin(bx) .. "," .. chunk_origin(by) .. "," ..
				chunk_origin(bz)
			if not done[key] and (in_sight(bx, by, bz, ex, ey, ez, player.dx, 0,
					player.dz, fov) or (speed > 1 and in_sight(bx, by, bz, ex, ey, ez,
					player.dx, 0, player.dz, 0.1))) and
					not block_occluded(bx, by, bz, camx, camy, camz) then
				return {x = bx, y = by, z = bz}, key, d
			end
		end
	end
	return nil, nil, nil, finished
end

local function finish(ok, message)
	log(("chunks fresh=%d old=%d cpu_s=%.1f wall_s=%.1f"):format(fresh_count,
		old_count, os.clock(), (core.get_us_time() - loaded_us) / 1e6))
	log(("RESULT %s %s"):format(ok and "PASS" or "FAIL", message))
	core.request_shutdown("r49cache probe done", false, 0)
end

local PHASES = {
	{id = 1, players = {
		{id = 1, x0 = 100, z0 = -1800, dx = 1, dz = 0, segments = {{4, 400}, {8, 400}}},
	}},
	{id = 2, players = {
		{id = 2, x0 = 100, z0 = -1000, dx = 1, dz = 0, segments = {{4, 400}}},
		{id = 3, x0 = 100, z0 = -400, dx = 1, dz = 0, segments = {{4, 400}}},
	}},
}

local function run_phase(phase_index)
	local phase = PHASES[phase_index]
	if not phase then return finish(true, "all phases") end
	local clock, turn, seq = 0, 0, 0
	log(("phase %d start players=%d"):format(phase.id, #phase.players))
	local next_pick
	local function request(player, block, key, d)
		seq = seq + 1
		local pos = {x = block.x * 16 + 8, y = block.y * 16 + 8, z = block.z * 16 + 8}
		local x, z, speed = position(player, clock)
		log(("req phase=%d player=%d n=%d chunk=%s d=%d clock=%.2f px=%.1f pz=%.1f speed=%d")
			:format(phase.id, player.id, seq, key, d, clock, x, z, speed))
		local t0 = core.get_us_time()
		core.emerge_area(pos, pos, function(_, action, remaining)
			if remaining ~= 0 then return end
			local wall = (core.get_us_time() - t0) / 1e6
			done[key] = true
			clock = clock + wall
			local is_fresh = action == core.EMERGE_GENERATED
			if is_fresh then fresh_count = fresh_count + 1 else old_count = old_count + 1 end
			log(("done phase=%d player=%d n=%d chunk=%s action=%d wall_ms=%.1f%s")
				:format(phase.id, player.id, seq, key, action, wall * 1000,
					is_fresh and "" or " NOT_FRESH"))
			core.after(0, next_pick)
		end)
	end
	next_pick = function()
		if (core.get_us_time() - loaded_us) / 1e6 > BUDGET_S then
			return finish(true, "budget reached in phase " .. phase.id)
		end
		for _ = 1, 100000 do
			local all_finished = true
			for _ = 1, #phase.players do
				turn = turn % #phase.players + 1
				local player = phase.players[turn]
				if not player.finished then
					local block, key, d, finished = pick(player, clock)
					if block then return request(player, block, key, d) end
					if not player.moving then
						player.moving, player.start_t = true, clock
						log(("player %d view complete at clock=%.2f, starts moving")
							:format(player.id, clock))
						all_finished = false
					elseif finished then
						player.finished = true
						log(("player %d reached its end at clock=%.2f"):format(player.id,
							clock))
					else
						all_finished = false
					end
				end
			end
			if all_finished then
				log(("phase %d done chunks=%d clock=%.2f"):format(phase.id, seq, clock))
				return core.after(1, function() run_phase(phase_index + 1) end)
			end
			-- Nobody has a chunk to generate: the players walk on (two nodes
			-- at the fastest speed).
			clock = clock + 0.25
		end
		finish(false, "idle loop did not end")
	end
	next_pick()
end

-- Wait for the starts preload (first boot of a world) so nothing else uses
-- the emerge thread.
local waited = 0
local function wait_ready()
	local status = grug_core.world_preparation_status()
	if status.failed then return finish(false, "world preparation failed") end
	if status.ready then
		log(("preparation ready after %d s of waiting, wall_s=%.1f"):format(waited,
			(core.get_us_time() - loaded_us) / 1e6))
		core.after(2, function() run_phase(1) end)
		return
	end
	waited = waited + 1
	core.after(1, wait_ready)
end
core.after(1, wait_ready)
