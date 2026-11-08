-- Disposable Round 72 BOSSRESET probe (tools/r72_bossreset/run.sh). Never shipped.
--
-- For every King's seat (the capitals' `king` sockets) and every General's seat (the
-- fortresses' `general` sockets): emerge the seat's leash range (30 nodes round it,
-- the same up and down, plus a margin), then run the boss floor's own fill
-- (grug_mobs.boss_floor, boss_floor.lua) with a King's body (his definition's box,
-- the elite size, the physics cut; nav.body) in the shipped steps of FILL cells, and
-- log the cells, the steps and the time (core.load_area included, as the game runs
-- it). Then the floor test's cost: a target on the floor and one off it (the cell
-- above the seat's column 10 nodes up). Every line carries "[r72bossreset]"; the last
-- one is "RESULT DONE".
local P = "[r72bossreset] "
local function log(s) core.log("action", P .. s) end
local F = grug_mobs.boss_floor
local nav, O = mobs.grug_nav, mobs.grug_obstacle
local RANGE, MARGIN, FILL = 30, 4, 400

local function king_body()
	local def = core.registered_entities["grug_mobs:king_human"]
	local c = def.initial_properties.collisionbox
	local box = {}
	for i = 1, 6 do box[i] = c[i] * 1.4 end -- the elite size (levels.lua)
	local fake = {_grug_cbox = O.physics_box(box), initial_properties = {stepheight = 1.1},
		jump_height = 4, fear_height = 4}
	return nav.body(fake)
end

local function seats()
	local out = {}
	for _, s in ipairs(grug_core.settlement_socket_settlements()) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(s.key)) do
			if socket.role == "king" or socket.role == "general" then
				out[#out + 1] = {label = socket.role .. " " .. s.key, pos = socket.pos}
			end
		end
	end
	table.sort(out, function(a, b) return a.label < b.label end)
	return out
end

local function measure(seat, body)
	local p = seat.pos
	local bounds = {cx = p.x, cz = p.z, r = RANGE, y0 = p.y - RANGE, y1 = p.y + RANGE}
	local t0 = core.get_us_time()
	core.load_area({x = p.x - RANGE, y = bounds.y0, z = p.z - RANGE},
		{x = p.x + RANGE, y = bounds.y1, z = p.z + RANGE})
	local st = F.new({x = p.x, y = p.y, z = p.z}, body, bounds)
	local first = core.get_us_time() - t0
	repeat until F.step(st, FILL)
	local total = core.get_us_time() - t0
	-- the steps again, timed each (a second fill on the same ground)
	local st2 = F.new({x = p.x, y = p.y, z = p.z}, body, bounds)
	local worst, steps = 0, 0
	repeat
		local t1 = core.get_us_time()
		local done = F.step(st2, FILL)
		worst = math.max(worst, core.get_us_time() - t1)
		steps = steps + 1
	until done
	local on_us, off_us = 0, 0
	if not st.failed then
		local n = 2000
		local on = {x = p.x, y = p.y - 0.5, z = p.z}
		local off = {x = p.x, y = p.y + 9.5, z = p.z}
		local t1 = core.get_us_time()
		for _ = 1, n do F.holds(st.cells, on, 3) end
		on_us = (core.get_us_time() - t1) / n
		t1 = core.get_us_time()
		for _ = 1, n do F.holds(st.cells, off, 3) end
		off_us = (core.get_us_time() - t1) / n
	end
	log(("SEAT %s at %d,%d,%d: %s %d cells, %d steps of %d, first fill %d us (load %d us), "
		.. "largest step %d us; floor test on %.2f us, off %.2f us")
		:format(seat.label, p.x, p.y, p.z, st.failed and "FAILED" or "ok", st.count, steps, FILL,
			total, first, worst, on_us, off_us))
end

core.after(1, function()
	local list = seats()
	log("seats " .. #list)
	local body = king_body()
	log(("king body: width %.2f, head %d, step %d, jump %d, drop %d"):format(body.width,
		body.head, body.step, body.jump, body.drop))
	local index = 0
	local function next_seat()
		index = index + 1
		local seat = list[index]
		if not seat then
			log("RESULT DONE")
			return core.request_shutdown("r72bossreset done", false, 0)
		end
		local p, r = seat.pos, RANGE + MARGIN
		local t0 = core.get_us_time()
		core.emerge_area({x = p.x - r, y = p.y - r, z = p.z - r}, {x = p.x + r, y = p.y + r, z = p.z + r},
			function(_, _, remaining)
				if remaining > 0 then return end
				log(("emerged %s in %.1f s"):format(seat.label, (core.get_us_time() - t0) / 1e6))
				-- one step later, so the last chunk's on_generated work has run
				core.after(0.5, function()
					measure(seat, body)
					next_seat()
				end)
			end)
	end
	next_seat()
end)
