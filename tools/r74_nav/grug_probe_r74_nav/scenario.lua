-- The one scenario of Round 74 lane NAV (round74-plan.md section 4 NAV, verification 3),
-- on one Expedition (config.expedition) at its catalogue level. The same script runs on
-- the lane's branch and, evade only (config.mode "evade"), on 0.73.1 as the baseline.
--   1. Every pack room is placed: the character (a peaceful player: no mob takes it)
--      walks by each room's markers; then it stands in the box's middle (plan.centre), so
--      every block of the box stays active.
--   2. The evade, in waves: every pack mob is put on its wave's cell (plan.drags: behind
--      corners, then across stairs; The Last Mint also three mobs across the lake) and
--      sent home (grug_mobs.evade_home). Counted per mob: walked home (the evade ended
--      before the 40 s net), the net's teleport (it ended at 40 s or later), the time, and
--      the seconds it stood (moved less than half a node in a second while evading); a
--      mob that needed the net or more than 15 s gets a TRACE line: its place each
--      second, on the branch with the guide's answer there.
--   3. The chase (mode "full"): per pack, the character stands on the room's chase cell
--      (plan.chase: round a corner, out of every marker's straight line), no longer
--      peaceful, and the pack is pulled (grug_core.engage_mob). Counted per member: at
--      striking range by walking, by the pack's jump (a move of more than 4 nodes in one
--      step), or not within CHASE_SECONDS; then the pack is reset (its wipe) and the
--      character is peaceful again.
local E = grug_expeditions
local LEVEL = {stilled_seam = 20, second_shift = 40, last_mint = 60}
local WAVE_SECONDS, CHASE_SECONDS, NET = 46, 25, 40

local function rel(run, p) return {x = run.minp.x + p[1], y = run.minp.y + p[2], z = run.minp.z + p[3]} end
local function key_of(run, pos)
	return ("%d,%d,%d"):format(math.floor(pos.x - run.minp.x + 0.5), math.floor(pos.y - run.minp.y + 0.5),
		math.floor(pos.z - run.minp.z + 0.5))
end

local function packs_of(run)
	local out = {}
	for object in core.objects_in_area(run.minp, run.maxp) do
		local ent = object:get_luaentity()
		if ent and ent._grug_expedition == run.id and ent._grug_pack and not ent._grug_scenery
				and (ent.health or 0) > 0 then
			out[#out + 1] = ent
		end
	end
	return out
end

local function median(list)
	if #list == 0 then return 0 end
	table.sort(list)
	return list[math.ceil(#list / 2)]
end

return function(lib, player, cfg, plan)
	local name = player:get_player_name()
	local function peaceful(on)
		local privs = core.get_player_privs(name)
		privs.peaceful_player = on or nil
		core.set_player_privs(name, privs)
	end
	lib.keep_alive = player
	peaceful(true)
	grug_xp.set_xp(player, grug_xp.xp_for_level(LEVEL[cfg.expedition]))
	local run = assert(E.create(player, cfg.expedition, 0))
	local t0 = core.get_us_time()
	lib.wait_for(function() return run.state == "ready" end, 150)
	lib.logf("ready after %.1f s", (core.get_us_time() - t0) / 1e6)
	assert(run.state == "ready", "the run is not ready")
	assert(E.enter(player, "highcourt"), "enter")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	assert(E.run_inside(player) == run, "inside")
	core.load_area(run.minp, run.maxp)
	local function stand(cell)
		player:set_pos({x = run.minp.x + cell[1], y = run.minp.y + cell[2] - 0.49, z = run.minp.z + cell[3]})
	end

	-- ---- 1. Every pack room placed -----------------------------------------------------
	local ambush = {}
	for _, row in ipairs(E.templates[E.definition(run.expedition).template].ambushes) do ambush[row.room] = true end
	local seen = {}
	for _, row in ipairs(run.encounters) do
		if row.tier ~= "critter" and not ambush[row.room] and not seen[row.room] then
			seen[row.room] = true
			local p = vector.subtract(row.pos, run.minp)
			stand({p.x, p.y, p.z})
			lib.wait(2.5)
		end
	end
	stand(plan.centre)
	lib.wait(3)
	lib.logf("PLACED %d pack mobs", #packs_of(run))

	-- ---- 2. The evade, in waves ----------------------------------------------------------
	local counters = mobs.grug_nav and mobs.grug_nav.counters
	local KEYS = {"searches", "found", "grid", "grid_off_start", "grid_off_goal", "grid_no_way"}
	local function snapshot()
		local out = {}
		for _, k in ipairs(KEYS) do out[k] = counters and counters[k] or 0 end
		return out
	end
	local function delta(label, before)
		local now, parts = snapshot(), {}
		for _, k in ipairs(KEYS) do parts[#parts + 1] = ("%s %d"):format(k, now[k] - before[k]) end
		lib.logf("COUNT %s %s", label, table.concat(parts, " "))
	end
	-- Fix round: every failed search, with the mob, its home, where it stands and its goal
	-- (the chase's target or the walk's point), so a reason can be read off.
	local nopath = 0
	if mobs.grug_nav then
		mobs.grug_nav.on_event = function(ent, kind)
			if kind ~= "no_path" or nopath >= 80 or ent._grug_expedition ~= run.id then return end
			nopath = nopath + 1
			local pos = ent.object and ent.object:get_pos()
			local goal = ent.attack and ent.attack:get_pos()
			local w = ent.temp and ent.temp.grug_walk
			if not goal and w then goal = {x = w.x, y = w.y or 0, z = w.z} end
			local function rel(p) return p and ("%.1f,%.1f,%.1f"):format(p.x - run.minp.x, p.y - run.minp.y,
				p.z - run.minp.z) or "-" end
			lib.logf("NOPATH %s home %s at %s goal %s (%s) evading %s", ent.name, key_of(run, ent._grug_home),
				rel(pos), rel(goal), ent.attack and (ent.attack:is_player() and "player" or "object") or "walk",
				tostring(ent.temp and ent.temp.grug_evading ~= nil))
		end
	end
	-- Fix round: an evader that stands (less than a node in two seconds) is described once,
	-- and again every 10 s: its state, its velocity, its walk and navigation, what is near.
	local function stall(m, pos)
		local ent, t = m.ent, m.ent.temp or {}
		local v = ent.object:get_velocity() or {x = 0, y = 0, z = 0}
		local w, nst = t.grug_walk, t.grug_nav
		local near = {}
		for object in core.objects_inside_radius(pos, 3) do
			if object ~= ent.object then
				local e = object:get_luaentity()
				local q = vector.subtract(object:get_pos(), run.minp)
				near[#near + 1] = ("%s@%.1f,%.1f,%.1f"):format(object:is_player() and "player" or (e and e.name or "?"),
					q.x, q.y, q.z)
			end
		end
		local r = vector.subtract(pos, run.minp)
		lib.logf("STALL %s %s at %.1f,%.1f,%.1f v %.1f,%.1f,%.1f yaw %.2f state %s fence %s cliff %s walk %s %s nav path %s/%s want %s fails %s near %s",
			ent.name, key_of(run, m.home), r.x, r.y, r.z, v.x, v.y, v.z, ent.object:get_yaw() or 0, tostring(ent.state),
			tostring(ent.facing_fence), tostring(ent.at_cliff), w and w.key or "-",
			w and w.x and ("%.1f,%.1f"):format(w.x - run.minp.x, w.z - run.minp.z) or "-",
			nst and nst.path and nst.i or "-", nst and nst.path and #nst.path or "-", tostring(nst and nst.want),
			tostring(nst and nst.fails), table.concat(near, " "))
	end
	local function wave(label, pick)
		local list = {}
		for _, ent in ipairs(packs_of(run)) do
			local cell = pick(ent)
			if cell then
				local home = ent._grug_home
				grug_mobs.place_on_ground(ent.object, {x = run.minp.x + cell[1], y = run.minp.y + cell[2] - 0.49,
					z = run.minp.z + cell[3]})
				ent.object:set_velocity({x = 0, y = 0, z = 0})
				list[#list + 1] = {ent = ent, home = home, from = key_of(run, ent.object:get_pos()),
					last = ent.object:get_pos(), prev = ent.object:get_pos(), stood = 0, trace = {}}
			end
		end
		lib.wait(0.2)
		local before = snapshot()
		for _, m in ipairs(list) do
			m.prev = m.ent.object:get_pos() or m.prev
			grug_mobs.evade_home(m.ent)
			m.started = core.get_us_time()
			m.evading = m.ent.temp and m.ent.temp.grug_evading ~= nil
		end
		local next_sample = core.get_us_time() + 1e6
		lib.wait_for(function()
			local now = core.get_us_time()
			local busy = false
			for _, m in ipairs(list) do
				if not m.done then
					local obj = m.ent.object
					local pos = obj and obj:get_pos()
					-- A move of more than 4 nodes in one step: the mob was placed (the
					-- 40 s net, or since the fix round the instant way home).
					if pos and vector.distance(pos, m.prev) > 4 then m.placed = true end
					if pos then m.prev = pos end
					if not pos then
						m.done, m.how = true, "lost"
					elseif not (m.ent.temp and m.ent.temp.grug_evading) then
						m.done, m.t = true, (now - m.started) / 1e6
						local d = vector.distance({x = pos.x, y = 0, z = pos.z}, {x = m.home.x, y = 0, z = m.home.z})
						m.how = m.t >= NET and "teleport" or m.placed and "set home" or "walked"
						m.d = d
					else
						busy = true
						if now >= next_sample then
							if vector.distance(pos, m.last) < 0.5 then m.stood = m.stood + 1 end
							-- The trace: where it is each second and the guide's last answer
							-- (read, never asked: asking has effects since the fix round).
							local r = vector.subtract(pos, run.minp)
							local gd = m.ent.temp and m.ent.temp.grug_guide
							local g = gd and gd.p
							m.trace[#m.trace + 1] = ("%.1f,%.1f,%.1f%s"):format(r.x, r.y, r.z,
								g and (">%d,%d"):format(g.x - run.minp.x, g.z - run.minp.z) or "")
							m.recent = m.recent or {}
							table.insert(m.recent, 1, pos)
							m.recent[4] = nil
							local age = (now - m.started) / 1e6
							if age > 3 and m.recent[3] and vector.distance(pos, m.recent[3]) < 1 and
									(not m.stalled or age - m.stalled >= 10) then
								m.stalled = age
								stall(m, pos)
							end
							m.last = pos
						end
					end
				end
			end
			if now >= next_sample then next_sample = now + 1e6 end
			return not busy
		end, WAVE_SECONDS)
		delta("wave " .. label, before)
		local walked, teleports, other, times, stood, worst, homed = 0, 0, 0, {}, 0, 0, 0
		for _, m in ipairs(list) do
			if m.how == "walked" then
				walked = walked + 1
				times[#times + 1] = m.t
			elseif m.how == "set home" then
				homed = homed + 1
			elseif m.how == "teleport" then
				teleports = teleports + 1
			else
				other = other + 1
			end
			stood = stood + m.stood
			if m.stood > worst then worst = m.stood end
			lib.logf("EVADE %s %s home %s from %s: %s %.1f s, stood %d s%s", label, m.ent.name,
				key_of(run, m.home), m.from, m.how or "running", m.t or -1, m.stood,
				m.evading and "" or " (no evade started)")
			if m.how ~= "walked" or (m.t or 99) > 15 then
				lib.logf("TRACE %s %s: %s", label, key_of(run, m.home), table.concat(m.trace, " "))
			end
		end
		lib.logf("WAVE %s mobs %d walked %d set_home %d teleports %d other %d time median %.1f max %.1f stood %d worst %d",
			label, #list, walked, homed, teleports, other, median(times), times[#times] or 0, stood, worst)
	end
	local function drag(index)
		return function(ent)
			local d = plan.drags[key_of(run, ent._grug_home)]
			local cell = d and d[index]
			return type(cell) == "table" and cell or nil
		end
	end
	wave("corner", drag(1))
	stand(plan.centre)
	wave("stairs", drag(2))
	if plan.lake and #plan.lake > 0 then
		local k = 0
		wave("lake", function(ent)
			local home = vector.subtract(ent._grug_home, run.minp)
			if k < #plan.lake and home.x > 95 and home.z > 90 then
				k = k + 1
				return plan.lake[k]
			end
		end)
	end
	if counters then
		lib.logf("NAV searches %d found %d grid %d largest_us %d", counters.searches, counters.found,
			counters.grid or 0, counters.largest_us)
	end
	if cfg.mode ~= "full" then return end

	-- ---- 3. The chase ---------------------------------------------------------------------
	for room, cell in pairs(plan.chase) do
		if type(cell) == "table" then
			local members = {}
			for _, ent in ipairs(packs_of(run)) do
				local row
				for _, r in ipairs(run.encounters) do
					if r.room == room and vector.distance(r.pos, ent._grug_home) <= 4.5 then row = r end
				end
				if row then members[#members + 1] = {ent = ent, last = ent.object:get_pos()} end
			end
			stand(cell)
			lib.wait(0.5)
			peaceful(false)
			local before = snapshot()
			local started = core.get_us_time()
			if members[1] then grug_core.engage_mob(members[1].ent, player) end
			lib.wait_for(function()
				local busy = false
				local at = player:get_pos()
				for _, m in ipairs(members) do
					local obj = m.ent.object
					local pos = obj and obj:get_pos()
					if not m.how and pos then
						if vector.distance(pos, m.last) > 4 then m.jumped = true end
						m.last = pos
						if vector.distance(pos, at) <= (m.ent.reach or 3) + 0.5 then
							m.how = m.jumped and "jumped" or "walked"
							m.t = (core.get_us_time() - started) / 1e6
						else
							busy = true
						end
					end
				end
				return not busy
			end, CHASE_SECONDS)
			local walked, jumped, missed, times = 0, 0, 0, {}
			for _, m in ipairs(members) do
				if m.how == "walked" then
					walked, times[#times + 1] = walked + 1, m.t
				elseif m.how == "jumped" then
					jumped = jumped + 1
				else
					missed = missed + 1
				end
				lib.logf("CHASE %s %s: %s %.1f s", room, m.ent.name, m.how or "not in reach", m.t or -1)
			end
			lib.logf("PACK %s at %d,%d,%d members %d walked %d jumped %d missed %d time median %.1f max %.1f",
				room, cell[1], cell[2], cell[3], #members, walked, jumped, missed, median(times), times[#times] or 0)
			delta("pack " .. room, before)
			-- Where the character ended (a pack's hits push it), and who else took it.
			local mine, others = {}, {}
			for _, m in ipairs(members) do mine[m.ent] = true end
			for _, ent in ipairs(packs_of(run)) do
				if not mine[ent] and ent.attack == player then others[#others + 1] = key_of(run, ent._grug_home) end
			end
			lib.logf("AFTER %s character at %s others %s", room, key_of(run, player:get_pos()),
				#others > 0 and table.concat(others, " ") or "none")
			peaceful(true)
			if members[1] and members[1].ent.object and members[1].ent.object:get_pos() then
				grug_mobs.pack_reset(members[1].ent)
			end
			stand(plan.centre)
			lib.wait(2)
		end
	end
	if counters then
		lib.logf("NAV searches %d found %d grid %d largest_us %d", counters.searches, counters.found,
			counters.grid or 0, counters.largest_us)
	end
end
