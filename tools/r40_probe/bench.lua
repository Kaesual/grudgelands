-- Round 40 lane V4: server-side timings only (plan §2.5, §3.4). Lua cost of
-- the calls, measured with core.get_us_time on the server that runs them:
--   planner  the planned path on every test course (table world) and on
--            the real terrain (live map), plus the game's destination search
--   overlay  one update pass with N running cooldowns (a stand-in player
--            counts the HUD calls; the engine's packet cost of hud_change
--            cannot be measured without a connected client, §3.4)
--   carrier  the per-step cost of a dash (live: printed after every
--            /pcharge; headless: a bench rider entity in force-loaded blocks)
-- `/pbench` runs the first two anywhere. A headless boot runs all three when
-- the staged probe folder holds a file named BENCH (never committed), then
-- shuts the server down.

return function(P)
local MOD, planner, shapes, hudmath = P.MOD, P.planner, P.shapes, P.hudmath
local bench = {}
P.bench = bench

local US = core.get_us_time
local BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}

local function median(list)
	table.sort(list)
	return list[math.floor((#list + 1) / 2)] or 0
end

-- The planner and the destination search on every course, `n` times each.
function bench.planner(n)
	local out = {}
	for _, key in ipairs(shapes.ORDER) do
		local shape = shapes.LIST[key]
		local world = shapes.table_world(shape)
		local from, tf = shapes.start(shape), shapes.target(shape)
		local dests, plans = {}, {}
		local dest, plan
		for _ = 1, n do
			local c0 = US()
			dest = grug_abilities.charge_destination(from, 1.47, BOX, tf, world)
			dests[#dests + 1] = US() - c0
			if dest then
				c0 = US()
				plan = planner.plan(world.xyz, from, dest)
				plans[#plans + 1] = US() - c0
			end
		end
		if dest and plan then
			out[#out + 1] = ("%-9s plan median %4d us (%2d segments, %3d node reads, %3d nodes); destination search %3d us")
				:format(key, median(plans), #plan.segments, plan.reads, plan.unique, median(dests))
		else
			out[#out + 1] = ("%-9s refused at the cast; destination search %d us"):format(key, median(dests))
		end
	end
	return out
end

-- One overlay pass with `count` running cooldowns, steady state over
-- `seconds` of simulated time (a finished cooldown restarts at once).
function bench.overlay(count, number, seconds)
	local id, calls = 0, {add = 0, change = 0, remove = 0}
	local fake = {
		get_player_name = function() return "bench:overlay" end,
		hud_add = function() id = id + 1 calls.add = calls.add + 1 return id end,
		hud_change = function() calls.change = calls.change + 1 end,
		hud_remove = function() calls.remove = calls.remove + 1 end,
		hud_get_hotbar_itemcount = function() return count end,
		get_inventory = function() return {get_size = function() return 32 end} end,
	}
	local ov = P.overlay
	local real_info = ov.window_info
	ov.window_info = function()
		return {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	end
	local st = ov.settings_for("bench:overlay")
	st.number = number
	local durations = {2, 5, 10, 30, 60, 90, 120, 300}
	for slot = 1, count do
		ov.start(fake, slot, durations[(slot - 1) % #durations + 1], 0)
	end
	local start_calls = calls.add
	local samples, passes = {}, math.floor(seconds / 0.1)
	for k = 1, passes do
		local now = k * 0.1
		local c0 = US()
		ov.pass(fake, st, now)
		samples[#samples + 1] = US() - c0
		for slot = 1, count do
			if not st.cds[slot] then
				ov.start(fake, slot, durations[(slot - 1) % #durations + 1], now)
			end
		end
	end
	local sum, top = 0, 0
	for _, s in ipairs(samples) do
		sum = sum + s
		if s > top then top = s end
	end
	local writes = calls.change + calls.remove + calls.add - start_calls
	ov.window_info = real_info
	ov.players["bench:overlay"] = nil
	return ("overlay %2d cooldowns, number %-6s: pass avg %.1f us, median %d us, max %d us; %.2f HUD writes per pass (%.1f per second)")
		:format(count, number, sum / passes, median(samples), top, writes / passes, writes / seconds)
end

function bench.quick()
	local lines = {"planner on the test courses (table world, 50 runs each):"}
	for _, l in ipairs(bench.planner(50)) do lines[#lines + 1] = "  " .. l end
	for _, c in ipairs({{8, "text"}, {8, "shadow"}, {8, "image"}, {32, "text"}}) do
		lines[#lines + 1] = bench.overlay(c[1], c[2], 60)
	end
	return lines
end

--
-- The headless part: live terrain and carriers.
--

core.register_entity(MOD .. ":bench_rider", {
	initial_properties = {
		physical = false, static_save = false, pointable = false,
		visual = "sprite", textures = {"grug_mobs_blank.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
})

local function log(line)
	core.log("action", "[r40 bench] " .. line)
end

local function surface(x, z, y_hi, y_lo)
	for y = y_hi, y_lo, -1 do
		local below = core.get_node({x = x, y = y - 1, z = z})
		local here = core.get_node({x = x, y = y, z = z})
		local up = core.get_node({x = x, y = y + 1, z = z})
		local d1 = core.registered_nodes[below.name]
		local d2 = core.registered_nodes[here.name]
		local d3 = core.registered_nodes[up.name]
		if d1 and d1.walkable and d2 and not d2.walkable and d3 and not d3.walkable then
			return y - 0.5
		end
	end
	return nil
end

local function live_planner(origin)
	local times, reads, segs, refused = {}, 0, 0, 0
	for k = 0, 7 do
		local ang = k * math.pi / 4
		local x = math.floor(origin.x + 10 * math.cos(ang) + 0.5)
		local z = math.floor(origin.z + 10 * math.sin(ang) + 0.5)
		local y = surface(x, z, math.floor(origin.y) + 8, math.floor(origin.y) - 8)
		if y then
			local dest = {x = x, y = y, z = z}
			for _ = 1, 10 do
				local c0 = US()
				local plan = planner.plan(P.charge.live_boxes, origin, dest)
				times[#times + 1] = US() - c0
				if plan then
					reads, segs = reads + plan.reads, segs + #plan.segments
				else
					refused = refused + 1
				end
			end
		end
	end
	log(("live terrain at %s: %d plans to 8 points 10 m away, median %d us, %.0f node reads and %.1f segments per plan, %d refused")
		:format(core.pos_to_string(origin), #times, median(times),
			reads / math.max(1, #times - refused), segs / math.max(1, #times - refused), refused))
end

local function carriers(origin, done)
	local variants = {"ghost", "path", "physical", "ghost", "path", "physical"}
	local tx = origin.x + 10
	local ty = surface(tx, origin.z, math.floor(origin.y) + 6, math.floor(origin.y) - 6)
	local target = ty and core.add_entity({x = tx, y = ty + 0.85, z = origin.z}, MOD .. ":dummy")
	if not target then
		log("no target spot 10 m east: carrier bench skipped")
		return done()
	end
	local k = 0
	local function next_run()
		k = k + 1
		if k > #variants then
			target:remove()
			return done()
		end
		local rider = core.add_entity(origin, MOD .. ":bench_rider")
		local opts = {}
		for key, v in pairs(P.charge.DEFAULTS) do opts[key] = v end
		local ok, why = P.charge.start(rider, target, variants[k], opts, "bench:" .. k,
			function(run)
				for _, l in ipairs(run.lines) do log(l) end
				rider:remove()
				core.after(0.2, next_run)
			end)
		if not ok then
			log(variants[k] .. ": " .. tostring(why))
			rider:remove()
			core.after(0.2, next_run)
		end
	end
	next_run()
end

-- A land column (surface at y >= 2) with land 10 m east of it, in the
-- emerged box around (cx, cz); nil if there is none.
local function land_near(cx, cz)
	for dz = -12, 12, 4 do
		for dx = -12, 8, 4 do
			local x, z = cx + dx, cz + dz
			local y = surface(x, z, 78, 2)
			if y and surface(x + 10, z, math.floor(y) + 6, math.floor(y) - 6) then
				return {x = x, y = y, z = z}
			end
		end
	end
	return nil
end

-- Every course built for real next to `origin` (guarded like the command:
-- world_alterable, no world feature ...), each variant but push (that needs
-- a client) charged by a bench rider, then the course cleared again.
local function courses(origin, done)
	local name = "bench:course"
	local pos = {x = origin.x, y = origin.y, z = origin.z}
	local fake = {
		get_player_name = function() return name end,
		get_look_horizontal = function() return -math.pi / 2 end, -- facing +x
		get_pos = function() return {x = pos.x, y = pos.y, z = pos.z} end,
		set_pos = function(_, p) pos = {x = p.x, y = p.y, z = p.z} end,
		set_look_horizontal = function() end,
		set_look_vertical = function() end,
	}
	local variants = {"teleport", "ghost", "physical", "path"}
	local ci, vi = 0, #variants
	local function step()
		vi = vi + 1
		if vi > #variants then
			if ci > 0 then
				local restored, kept = P.course.clear(name)
				log(("course %s cleared, %d nodes restored, %d kept"):format(shapes.ORDER[ci],
					restored, kept))
			end
			ci, vi = ci + 1, 1
			local key = shapes.ORDER[ci]
			if not key then return done() end
			pos = {x = origin.x, y = origin.y, z = origin.z}
			local ok, msg = P.course.build(fake, key)
			log(("course %s: %s"):format(key, msg))
			if not ok then
				vi = #variants
				return core.after(0.1, step)
			end
		end
		local key = shapes.ORDER[ci]
		local start = P.course.start_of(name)
		local target = P.course.target(name)
		local rider = core.add_entity(start, MOD .. ":bench_rider")
		local opts = {}
		for k, v in pairs(P.charge.DEFAULTS) do opts[k] = v end
		local ok, why = P.charge.start(rider, target, variants[vi], opts,
			"bench:" .. key .. ":" .. variants[vi], function(run)
				for _, l in ipairs(run.lines) do log(key .. " | " .. l) end
				rider:remove()
				core.after(0.2, step)
			end)
		if not ok then
			log(("%s | %s"):format(key, tostring(why)))
			rider:remove()
			core.after(0.1, step)
		end
	end
	step()
end

local function run_live(origin)
	live_planner(origin)
	-- Entities only step in active blocks; with no player that means
	-- force-loaded ones (serverenvironment.cpp:93): every block of the box
	-- the dashes and the courses use (at most 3 x 2 x 2).
	local blocks = {}
	for bx = math.floor((origin.x - 3) / 16), math.floor((origin.x + 17) / 16) do
		for by = math.floor((origin.y - 2) / 16), math.floor((origin.y + 10) / 16) do
			for bz = math.floor((origin.z - 3) / 16), math.floor((origin.z + 3) / 16) do
				local b = {x = bx * 16, y = by * 16, z = bz * 16}
				if core.forceload_block(b, true) then blocks[#blocks + 1] = b end
			end
		end
	end
	core.after(1, function()
		carriers(origin, function()
			courses(origin, function()
				for _, b in ipairs(blocks) do core.forceload_free_block(b, true) end
				log("done")
				core.request_shutdown("r40 bench done", false, 0)
			end)
		end)
	end)
end

local CANDIDATES = {{0, 0}, {256, 0}, {0, 256}, {-256, 0}, {0, -256}, {512, 512}}

function bench.headless()
	for _, l in ipairs(bench.quick()) do log(l) end
	local k = 0
	local function try_next()
		k = k + 1
		local c = CANDIDATES[k]
		if not c then
			log("no land found near the candidates: live part skipped")
			core.request_shutdown("r40 bench done", false, 0)
			return
		end
		local p1 = {x = c[1] - 16, y = -32, z = c[2] - 16}
		local p2 = {x = c[1] + 31, y = 79, z = c[2] + 16}
		local t0 = US()
		core.emerge_area(p1, p2, function(_, _, remaining)
			if remaining > 0 then return end
			log(("emerged %s..%s in %.1f s"):format(core.pos_to_string(p1),
				core.pos_to_string(p2), (US() - t0) / 1e6))
			local origin = land_near(c[1], c[2])
			if origin then
				run_live(origin)
			else
				try_next()
			end
		end)
	end
	try_next()
end

local marker = io.open(P.path .. "/BENCH", "r")
if marker then
	marker:close()
	core.register_on_mods_loaded(function()
		core.after(2, bench.headless)
	end)
end
end
