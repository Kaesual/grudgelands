-- Disposable Round 34 F1 probe (tools/r34_f1/engine.sh). Never shipped.
--
-- Finds two real water crossings of the generated world (a river or lake
-- neck with land on both banks, away from the start towns; the second one
-- wider or deeper than the first), forceloads them and runs one melee mob (a
-- Wolf) per site through four cases, both sites at the same time. Site 1's
-- banks are raised one node above the water (a placed stone row), site 2
-- keeps its own banks:
--   AMBIENT   20 s of the mob's own random walk, turned to face the water
--             every 0.25 s and always choosing to walk: it must stay out.
--   CHASE     a stand-in target stands on the far bank, four nodes past the
--             water (out of reach from the water); the mob attacks it and must
--             cross the water, climb out and reach it.
--   RETURN    the target vanishes: the fight ends, the mob runs home (the
--             evade) and must stand on land at home again. (Since Round 36 a
--             free mob reset inside its 32-node wander radius only heals and
--             stays: a crossing narrower than that reports evade_seen=false.)
--   STRANDED  an idle second mob set down in the middle of the water (its
--             home on the near bank) must reach land.
-- COST: every mob's is_at_cliff (the support probe) and grug_mobs.leash_tick
-- calls are timed for the whole run (all mobs in the forceloaded area).
-- Every line carries "[r34f1]"; the probe ends the server when done.
local P = "[r34f1] "
local MOB = "grug_mobs:wolf"
local function log(s) core.log("action", P .. s) end
local now_us = core.get_us_time

-- ------------------------------------------------------------------ cost
local cost = {cliff_us = 0, cliff_n = 0, leash_us = 0, leash_n = 0}
local mob_class = mobs.mob_class
local orig_cliff = mob_class.is_at_cliff
mob_class.is_at_cliff = function(self)
	local t0 = now_us()
	local r = orig_cliff(self)
	cost.cliff_us = cost.cliff_us + (now_us() - t0)
	cost.cliff_n = cost.cliff_n + 1
	return r
end
core.register_on_mods_loaded(function()
	local orig_leash = grug_mobs.leash_tick
	grug_mobs.leash_tick = function(self, dtime)
		local t0 = now_us()
		orig_leash(self, dtime)
		cost.leash_us = cost.leash_us + (now_us() - t0)
		cost.leash_n = cost.leash_n + 1
	end
end)

-- ---------------------------------------------------------- stand-in target
local hits = 0
core.register_entity("grug_probe_r34_f1:target", {
	initial_properties = {
		physical = false, pointable = true, static_save = false, hp_max = 100,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() hits = hits + 1 return true end,
})

-- --------------------------------------------------------- find a crossing
local function class(x, z) return grug_zones.water_class_at(x, z) end

-- Land at (x, z), planned water from step a (1..3) to b - 1 (3..16 wide),
-- land again for four steps, water beside the middle (not a one-wide nick),
-- both banks' authority heights within 2 of each other.
local function crossing_from(x, z, ux, uz)
	local a, b
	for i = 1, 3 do
		local c = class(x + ux * i, z + uz * i)
		if c == "planned_water" then a = i break end
		if c ~= "land" then return nil end
	end
	if not a then return nil end
	for i = a + 1, a + 16 do
		local c = class(x + ux * i, z + uz * i)
		if c == "land" then b = i break end
		if c ~= "planned_water" then return nil end
	end
	if not b or b - a < 3 then return nil end
	for i = b, b + 3 do
		if class(x + ux * i, z + uz * i) ~= "land" then return nil end
	end
	local m = math.floor((a + b) / 2)
	for _, s in ipairs({-1, 1}) do
		if class(x + ux * m + uz * s, z + uz * m + ux * s) ~= "planned_water" then
			return nil
		end
	end
	local hA = grug_zones.terrain_height_at(x, z)
	local hB = grug_zones.terrain_height_at(x + ux * (b + 2), z + uz * (b + 2))
	if math.abs(hA - hB) > 2 then return nil end
	return {x = x, z = z, ux = ux, uz = uz, a = a, b = b, h = hA}
end

-- From a planned-water sample: back to its near bank along the axis, then
-- crossing_from two land steps behind that bank.
local function crossing_through(x, z, ux, uz)
	for i = 1, 14 do
		local c = class(x - ux * i, z - uz * i)
		if c == "land" then
			local sx, sz = x - ux * (i + 1), z - uz * (i + 1)
			if class(sx, sz) ~= "land" then return nil end
			return crossing_from(sx, sz, ux, uz)
		end
		if c ~= "planned_water" then return nil end
	end
end

-- Rings of 8-node samples 120-600 nodes around the six start positions,
-- nearest rings first; candidates at least 48 nodes apart.
local function find_candidates(centers, want)
	local out = {}
	local t0 = now_us()
	local function far_enough(x, z)
		for _, o in ipairs(out) do
			if math.abs(o.x - x) < 48 and math.abs(o.z - z) < 48 then return false end
		end
		return true
	end
	for d = 120, 600, 8 do
		for _, center in ipairs(centers) do
			for i = -d, d, 8 do
				for _, c in ipairs({{i, -d}, {i, d}, {-d, i}, {d, i}}) do
					local x, z = center.x + c[1], center.z + c[2]
					if class(x, z) == "planned_water" then
						for _, u in ipairs({{1, 0}, {0, 1}}) do
							local cand = crossing_through(x, z, u[1], u[2])
							if cand and far_enough(cand.x, cand.z) then
								out[#out + 1] = cand
								if #out >= want then
									log(("search %.1f s, %d candidates"):format(
										(now_us() - t0) / 1e6, #out))
									return out
								end
							end
						end
					end
				end
			end
		end
	end
	log(("search %.1f s, %d candidates"):format((now_us() - t0) / 1e6, #out))
	return out
end

-- -------------------------------------------------------- real nodes check
local function liquid_def(name)
	local def = core.registered_nodes[name]
	return def and def.liquidtype and def.liquidtype ~= "none"
end

-- Top solid or liquid node of a column near the authority height (plants
-- and air skipped); nil while unloaded.
local function surface(x, z, h)
	for y = h + 10, h - 12, -1 do
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		if not node or node.name == "ignore" then return nil end
		local def = core.registered_nodes[node.name]
		if def and liquid_def(node.name) then return y, "liquid", node.name end
		if def and def.walkable then return y, "solid", node.name end
	end
	return nil
end

local function verify(c)
	local kinds, ys = {}, {}
	for i = 0, c.b + 4 do
		local y, kind = surface(c.x + c.ux * i, c.z + c.uz * i, c.h)
		if not y then return nil, "unloaded at step " .. i end
		kinds[i], ys[i] = kind, y
	end
	local i0, i1
	for i = 0, c.b + 4 do
		if kinds[i] == "liquid" then
			i0 = i0 or i
			i1 = i
		elseif i0 then
			break
		end
	end
	if not i0 or i0 < 2 or i1 - i0 + 1 < 2 then return nil, "no water span" end
	for i = 0, i0 - 1 do
		if kinds[i] ~= "solid" then return nil, "near bank not solid" end
	end
	for i = i1 + 1, math.min(i1 + 4, c.b + 4) do
		if kinds[i] ~= "solid" then return nil, "far bank not solid" end
	end
	if i1 + 4 > c.b + 4 then return nil, "far bank too short" end
	local wy = ys[i0]
	local near, far = i0 - 2, i1 + 4
	if ys[near] < wy or ys[near] > wy + 2 or ys[far] < wy or ys[far] > wy + 2 then
		return nil, ("banks %d/%d against water %d"):format(ys[near], ys[far], wy)
	end
	local depth = 0
	local mid = math.floor((i0 + i1) / 2)
	for y = wy, wy - 8, -1 do
		local n = core.get_node({x = c.x + c.ux * mid, y = y, z = c.z + c.uz * mid})
		if not liquid_def(n.name) then break end
		depth = depth + 1
	end
	local function at(i, y)
		return {x = c.x + c.ux * i, y = y, z = c.z + c.uz * i}
	end
	return {
		i0 = i0, i1 = i1, wy = wy, depth = depth,
		near = at(near, ys[near] + 0.5), far = at(far, ys[far] + 0.5),
		middle = at(mid, wy + 0.5),
		bank_near = ys[near] - wy, bank_far = ys[far] - wy,
		profile = (function()
			local s = {}
			for i = 0, c.b + 4 do s[#s + 1] = kinds[i]:sub(1, 1) .. (ys[i] - wy) end
			return table.concat(s, " ")
		end)(),
	}
end

-- ------------------------------------------------------------------ mobs
local function in_water(ent)
	return liquid_def(ent.standing_on) or liquid_def(ent.standing_in)
end

local function spawn(pos, home)
	local obj = core.add_entity(pos, MOB)
	local ent = obj and obj:get_luaentity()
	if not ent then return nil end
	grug_mobs.place_on_ground(obj, pos)
	if home then ent._grug_home = {x = home.x, y = home.y, z = home.z} end
	return ent
end

local function along(c, pos)
	return (pos.x - c.x) * c.ux + (pos.z - c.z) * c.uz
end

local function hdist(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

local function face(ent, pos, to)
	local yaw = core.dir_to_yaw({x = to.x - pos.x, y = 0, z = to.z - pos.z})
	ent.target_yaw = yaw
	ent.delay = 0
	ent.object:set_yaw(yaw)
end

local function fmt(v) return v and ("%.1f"):format(v) or "never" end

-- --------------------------------------------------------------- one site
-- Cases per site, each ending early when met: AMBIENT 20 s, CHASE up to 30 s,
-- RETURN up to 45 s, STRANDED up to 30 s.
local function site_step(s, dtime)
	s.t = s.t + dtime
	local c = s.cand
	local tag = "site" .. s.id
	local function trace(label, ent)
		s.trace_t = s.trace_t + dtime
		if s.trace_t < 3 then return end
		s.trace_t = 0
		local pos = ent.object:get_pos()
		if not pos then return end
		log(("trace %s %s t=%.1f along=%.2f y=%.2f state=%s cliff=%s water=%s"):format(
			tag, label, s.t, along(c, pos), pos.y, tostring(ent.state),
			tostring(ent.at_cliff), tostring(in_water(ent) and true or false)))
	end
	local function to(case)
		s.case, s.t, s.trace_t, s.sample_t = case, 0, 0, 0
	end
	if s.case == "start" then
		s.w1 = spawn(s.near)
		if not s.w1 then
			log("RESULT " .. tag .. " FAIL could not spawn " .. MOB)
			to("done")
			return
		end
		s.wet, s.samples = 0, 0
		to("ambient")
	elseif s.case == "ambient" then
		-- The mob's own random walk, always facing the water and always
		-- choosing to walk (walk_chance 100, stand_chance 0): no velocity
		-- is forced here.
		local w = s.w1
		local pos = w.object:get_pos()
		if not pos then to("done") return end
		w.walk_chance, w.stand_chance = 100, 0
		s.sample_t = s.sample_t + dtime
		if s.sample_t >= 0.25 then
			s.sample_t = 0
			s.samples = s.samples + 1
			if in_water(w) then s.wet = s.wet + 1 end
			face(w, pos, s.far)
		end
		trace("ambient", w)
		if s.t >= 20 then
			w.walk_chance, w.stand_chance = nil, nil
			log(("RESULT %s AMBIENT wet_samples=%d of %d along=%.2f (water from %d)"):format(
				tag, s.wet, s.samples, along(c, pos), s.i0))
			-- The chase starts from the near bank, the mob's home.
			grug_mobs.place_on_ground(w.object, s.near)
			s.target = core.add_entity(s.far, "grug_probe_r34_f1:target")
			s.hits0 = hits
			w:do_attack(s.target, true)
			to("chase")
		end
	elseif s.case == "chase" then
		local w = s.w1
		local pos = w.object:get_pos()
		if not pos then to("done") return end
		local t = along(c, pos)
		if not s.enter and in_water(w) then s.enter = s.t end
		if not s.cross and t > s.i1 + 0.5 and not in_water(w) then s.cross = s.t end
		if not s.reach and hdist(pos, s.far) <= 3 then s.reach = s.t end
		trace("chase", w)
		if (s.reach and s.t >= s.reach + 3) or s.t >= 30 then
			log(("RESULT %s CHASE entered_water=%s crossed=%s reached=%s state=%s along=%.2f"):format(
				tag, fmt(s.enter), fmt(s.cross), fmt(s.reach), tostring(w.state), t))
			s.target:remove()
			s.evade = false
			to("return")
		end
	elseif s.case == "return" then
		local w = s.w1
		local pos = w.object:get_pos()
		if not pos then to("done") return end
		if w.temp and w.temp.grug_evading then s.evade = true end
		local home = w._grug_home
		if not s.home and home and hdist(pos, home) <= 4 and not in_water(w) then
			s.home = s.t
		end
		trace("return", w)
		if s.home or s.t >= 45 then
			log(("RESULT %s RETURN evade_seen=%s home_on_land=%s home_dist=%.2f in_water=%s along=%.2f"):format(
				tag, tostring(s.evade), fmt(s.home), home and hdist(pos, home) or -1,
				tostring(in_water(w) and true or false), along(c, pos)))
			s.w2 = spawn(s.middle, s.near)
			s.dry = 0
			to("stranded")
		end
	elseif s.case == "stranded" then
		local w = s.w2
		local pos = w and w.object:get_pos()
		if not pos then
			log("RESULT " .. tag .. " STRANDED no mob")
			to("done")
			return
		end
		s.sample_t = s.sample_t + dtime
		if s.sample_t >= 0.25 then
			s.sample_t = 0
			-- Two seconds on land in a row count as out of the water.
			if in_water(w) then s.dry = 0 else s.dry = s.dry + 0.25 end
			if not s.land and s.dry >= 2 then s.land = s.t - 2 end
		end
		trace("stranded", w)
		if s.land or s.t >= 30 then
			log(("RESULT %s STRANDED on_land=%s state=%s along=%.2f in_water=%s"):format(
				tag, fmt(s.land), tostring(w.state), along(c, pos),
				tostring(in_water(w) and true or false)))
			to("done")
		end
	end
end

-- ---------------------------------------------------------------- driver
-- Two sites: the first verified crossing, and the first wider (5+) or
-- deeper (2+) one at least 64 nodes away from it.
local phase, phase_t, total_t = "wait", 0, 0
local cands, ci, cand
local emerge_done
local sites = {}

local function set_phase(p)
	phase, phase_t = p, 0
	log("phase -> " .. p)
end

local function forceload(c)
	local cx, cz = c.x + c.ux * c.b / 2, c.z + c.uz * c.b / 2
	for bx = math.floor((cx - 24) / 16), math.floor((cx + 24) / 16) do
		for bz = math.floor((cz - 24) / 16), math.floor((cz + 24) / 16) do
			for by = math.floor((c.h - 16) / 16), math.floor((c.h + 16) / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	emerge_done = false
	core.emerge_area({x = cx - 32, y = c.h - 24, z = cz - 32},
		{x = cx + 32, y = c.h + 24, z = cz + 32}, function(_, _, remaining)
			if remaining == 0 then emerge_done = true end
		end)
end

local function next_candidate()
	ci = ci + 1
	cand = cands[ci]
	if not cand or ci > 14 then
		if #sites == 0 then
			log("RESULT NOSITE no verified crossing among " .. #cands .. " candidates")
			set_phase("done")
		else
			set_phase("run")
		end
		return
	end
	log(("candidate %d at (%d,%d) dir (%d,%d) water steps %d..%d h %d"):format(
		ci, cand.x, cand.z, cand.ux, cand.uz, cand.a, cand.b - 1, cand.h))
	forceload(cand)
	set_phase("emerge")
end

-- Site 1 gets banks one node above the water surface on both sides (solid
-- bank columns only, nine nodes across): a floating mob must climb out.
local function raise_banks(s)
	local c = s.cand
	local raised = 0
	local function raise(i)
		for l = -4, 4 do
			local x, z = c.x + c.ux * i + c.uz * l, c.z + c.uz * i + c.ux * l
			local below = core.get_node({x = x, y = s.wy, z = z})
			local def = core.registered_nodes[below.name]
			if def and def.walkable then
				core.set_node({x = x, y = s.wy + 1, z = z}, {name = "default:stone"})
				raised = raised + 1
			end
		end
	end
	for i = 0, s.i0 - 1 do raise(i) end
	for i = s.i1 + 1, c.b + 4 do raise(i) end
	s.near.y, s.far.y = s.wy + 1.5, s.wy + 1.5
	s.bank_near, s.bank_far = 1, 1
	s.raised = raised
end

local function accept(s)
	if #sites == 0 then return true end
	local first = sites[1]
	if hdist(s.near, first.near) < 64 then return false end
	return s.i1 - s.i0 + 1 >= 5 or s.depth >= 2
end

local function finish()
	log(("RESULT COST is_at_cliff calls=%d total_us=%d us_per_call=%.3f"):format(
		cost.cliff_n, cost.cliff_us, cost.cliff_n > 0 and cost.cliff_us / cost.cliff_n or 0))
	log(("RESULT COST leash_tick calls=%d total_us=%d us_per_call=%.3f"):format(
		cost.leash_n, cost.leash_us, cost.leash_n > 0 and cost.leash_us / cost.leash_n or 0))
	log("RESULT DONE")
	core.request_shutdown("r34f1 probe done", false, 0)
end

core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			local centers = {}
			for _, fr in ipairs({{"accord", "human"}, {"accord", "elf"},
					{"accord", "dwarf"}, {"throng", "orc"}, {"throng", "troll"},
					{"throng", "undead"}}) do
				centers[#centers + 1] = grug_core.start_position(fr[1], fr[2])
			end
			cands = find_candidates(centers, 24)
			ci = 0
			next_candidate()
		end
	elseif phase == "emerge" then
		-- One more second for the blocks to activate.
		if phase_t > 1 and (emerge_done or phase_t > 60) then
			local s, why = verify(cand)
			if not s then
				log("candidate " .. ci .. " rejected: " .. tostring(why))
			elseif not accept(s) then
				log("candidate " .. ci .. " skipped: not wider or deeper, or too close")
			else
				s.id, s.cand, s.case, s.t, s.trace_t, s.sample_t = #sites + 1, cand, "start", 0, 0, 0
				sites[#sites + 1] = s
				if s.id == 1 then raise_banks(s) end
				log(("SITE %d (%d,%d) dir (%d,%d) water %d..%d wide %d depth %d surface y %d bank near %+d far %+d"):format(
					s.id, cand.x, cand.z, cand.ux, cand.uz, s.i0, s.i1, s.i1 - s.i0 + 1,
					s.depth, s.wy, s.bank_near, s.bank_far))
				log("SITE " .. s.id .. " profile (kind, height above water): " .. s.profile
					.. (s.raised and (" ; banks raised +1 (%d nodes)"):format(s.raised) or ""))
				if #sites == 2 then
					set_phase("run")
					return
				end
			end
			next_candidate()
		end
	elseif phase == "run" then
		local open = 0
		for _, s in ipairs(sites) do
			if s.case ~= "done" then
				site_step(s, dtime)
				open = open + 1
			end
		end
		if open == 0 then set_phase("done") end
	elseif phase == "done" then
		set_phase("off")
		finish()
	end
end)
