-- Disposable Round 49 NAV probe (tools/r49_nav/run.sh). Never shipped.
--
-- Builds the short-range chase scenes (scenes.lua) as a grid of walled lanes
-- on a forceloaded floor high above deep ocean (the Round 42 NV0 arena) and
-- drives REAL mobs on the REAL code through them, one mover kind per batch
-- (every lane at once), at night (the zombie burns by day). Each mob is
-- forced to attack a punchable, player-sized dummy standing still on the
-- scene's target cell; a mob that gives the dummy up or drops it is sent at
-- it again after 1 s (the dummy steps one node aside, as a player who moves
-- would be acquired again), so loops show.
--
-- Recorded per trial, on top of Round 42 NV0's hit/arrival times:
--   * the navigation module's events (grug_nav.on_event: stuck, found,
--     no_path, rejected, refused, cap_wait, leave_<reason>, give_up);
--   * every detector window's verdict and its self-movement ratio (moved /
--     expected), read from the module's own window state;
--   * every failure the module counts and why (a failed search, stuck on
--     a path, stuck after leaving a path on a clear line: "line_fail");
--   * every walkable-line test against the target (true/false), every
--     engine search (ends, padding, found, length, cost) and every path the
--     head-room/width check rejects (the first waypoint that fails);
--   * mobs_redo's stop_attack and the give-ups;
--   * static checks at the start: the walkable line from the start to the
--     target, and the engine's search from the start with padding 6 (the
--     module's first) and 12;
--   * Round 49 NAV2: every shot of a ranged mover (the "shoot" clip) and
--     whether the mob saw its target then; at the start, every registered
--     dogshoot mob (flier or ground, pathfinding) in the results' meta;
--   * a track every 0.25 s: position, commanded speed, distance, in sight,
--     striking, following a path, a horizontal node collision.
--
-- Phases (setting grug_r49nav_phases, comma separated, default "scenes"):
--   scenes  the main scene list (scenes.list), every mover;
--   extra   the second list (scenes.extra: a strafing target, a target on a
--           bush, a grove), every mover;
--   real    natural terrain of the world seed: the first meadows, deep
--           forest and pine hills sites near the origin are generated (a
--           small box each), bushes, blueberry bushes and tree trunks are
--           found there, and each gets one trial: the target 1-3 nodes
--           behind the obstacle (preferably 1-2 nodes higher for a bush), the
--           mob 3-8 nodes away on the other side; the geometry round every
--           trial is saved with the results.
-- Settings (staged by run.sh): grug_r49nav_movers (default
-- "zombie,rat,archer"), grug_r49nav_scenes (a filter, default all).
-- Results go to <world>/r49nav_results.json; every log line carries
-- "[r49nav]".

local MOD = core.get_current_modname()
local MP = core.get_modpath(MOD)
local scenes = dofile(MP .. "/scenes.lua")
local P = "[r49nav] "
local now = core.get_us_time
local function log(s) core.log("action", P .. s) end
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local function name_set(setting, default)
	local value = core.settings:get(setting)
	if not value or value == "" then value = default end
	if not value then return nil end
	local set, order = {}, {}
	for word in value:gmatch("[%w_]+") do
		set[word] = true
		order[#order + 1] = word
	end
	return set, order
end
local _, MOVER_ORDER = name_set("grug_r49nav_movers", "zombie,rat,archer")
local ONLY_SCENES = name_set("grug_r49nav_scenes")
local PHASES, PHASE_ORDER = name_set("grug_r49nav_phases", "scenes")

local results = {meta = {}, movers = {}, trials = {}, batches = {}, sites = {}}

local function sanitize(value)
	local kind = type(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		return value
	elseif kind == "table" then
		local out = {}
		for k, v in pairs(value) do out[k] = sanitize(v) end
		return out
	elseif kind == "string" or kind == "boolean" then
		return value
	end
	return nil
end

local function write_results()
	local path = core.get_worldpath() .. "/r49nav_results.json"
	local text = core.write_json(sanitize(results))
	if not text or not core.safe_file_write(path, text) then
		core.log("error", P .. "could not write " .. path)
		return
	end
	log("wrote " .. path .. " (" .. #text .. " bytes)")
end

local function r2(value) return floor(value * 100 + 0.5) / 100 end

---------------------------------------------------------------------------
-- The arena
---------------------------------------------------------------------------
local FLOOR_Y = 300 -- y of the floor's top node
local COLS = 4
local PITCH_U, PITCH_V = 22, 26
local MARGIN = 6
local origin

-- The lanes of this boot: the scenes of every selected list, in order.
local LANES = {}
for _, key in ipairs({"scenes", "extra"}) do
	if PHASES[key] then
		for _, scene in ipairs(key == "scenes" and scenes.list or scenes.extra) do
			if not ONLY_SCENES or ONLY_SCENES[scene.name] then
				LANES[#LANES + 1] = {scene = scene, phase = key}
			end
		end
	end
end

local function lane_grid()
	local rows = math.max(1, math.ceil(#LANES / COLS))
	return MARGIN * 2 + COLS * PITCH_U, MARGIN * 2 + rows * PITCH_V
end

-- World x, z of lane cell (0, 0).
local function lane_base(index)
	local col = (index - 1) % COLS
	local row = floor((index - 1) / COLS)
	return origin.x + MARGIN + col * PITCH_U + scenes.LANE_BACK + 1,
		origin.z + MARGIN + row * PITCH_V + scenes.LANE_HALF + 1
end

local function cell_pos(index, u, v, h)
	local x, z = lane_base(index)
	return {x = x + u, y = FLOOR_Y + h, z = z + v}
end

local function arena_box()
	local w, d = lane_grid()
	return vector.new(origin.x, FLOOR_Y + scenes.FLOOR_DEPTH - 1, origin.z),
		vector.new(origin.x + w - 1, FLOOR_Y + 10, origin.z + d - 1)
end

local function find_origin()
	local w, d = lane_grid()
	for r = 0, 40 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 256, c[2] * 256
				local ok = true
				for _, o in ipairs({{0, 0}, {w, 0}, {0, d}, {w, d}, {w / 2, d / 2}}) do
					if grug_zones.water_class_at(x + o[1], z + o[2]) ~= "deep_ocean" then
						ok = false
						break
					end
				end
				if ok then return vector.new(x, 0, z) end
			end
		end
	end
end

local NODES = {
	solid = "default:stone",
	trunk = "default:tree",
	leaves = "default:leaves",
	bush_leaves = "default:bush_leaves",
	bush_stem = "default:bush_stem",
	blueberry = "default:blueberry_bush_leaves_with_berries",
	air = "air",
}

local function build_arena()
	local minp, maxp = arena_box()
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c = {}
	for kind, name in pairs(NODES) do c[kind] = core.get_content_id(name) end
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			for y = minp.y, maxp.y do
				local id = c.air
				if y <= FLOOR_Y and y >= FLOOR_Y + scenes.FLOOR_DEPTH then id = c.solid end
				data[area:index(x, y, z)] = id
			end
		end
	end
	local back, front, half = scenes.LANE_BACK, scenes.LANE_FRONT, scenes.LANE_HALF
	for index, lane in ipairs(LANES) do
		local scene = lane.scene
		local bx, bz = lane_base(index)
		-- The lane's wall, one node outside its cells.
		for u = -back - 1, front + 1 do
			for v = -half - 1, half + 1 do
				if u == -back - 1 or u == front + 1 or v == -half - 1 or v == half + 1 then
					for h = 1, scenes.WALL_H do
						data[area:index(bx + u, FLOOR_Y + h, bz + v)] = c.solid
					end
				end
			end
		end
		for _, op in ipairs(scene.ops) do
			local id = c[op[2]]
			for u = math.min(op[3], op[6]), math.max(op[3], op[6]) do
				for v = math.min(op[4], op[7]), math.max(op[4], op[7]) do
					for h = math.min(op[5], op[8]), math.max(op[5], op[8]) do
						data[area:index(bx + u, FLOOR_Y + h, bz + v)] = id
					end
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

---------------------------------------------------------------------------
-- Instrumentation (wrappers around the real code; they only observe)
---------------------------------------------------------------------------
local mc = mobs.mob_class
local OB = mobs.grug_obstacle
local NAV = mobs.grug_nav
assert(NAV and OB, "mobs.grug_nav / mobs.grug_obstacle missing")
local tracked = setmetatable({}, {__mode = "k"}) -- luaentity -> trial record
local in_combat_step -- the record whose combat_step runs right now

local function trial_time(rec) return (now() - rec.t0) / 1e6 end

local function event(rec, kind, detail)
	if not rec or not rec.t0 or rec.done then return end
	local row = {r2(trial_time(rec)), kind}
	if detail ~= nil then row[3] = detail end
	rec.events[#rec.events + 1] = row
end

local function count(rec, key, by)
	rec.counts[key] = (rec.counts[key] or 0) + (by or 1)
end

-- The trial's local coordinates of a world position: u, v and h, where h is
-- the layer index of feet at that height (a mob on a lane's floor reads 1,
-- on a 1-high terrace 2; a natural trial's start reads 1). A node cell at
-- layer h passes y = by + h - 0.5. rec.bx, rec.bz, rec.by: the frame.
local function lane_cell(rec, pos)
	return r2(pos.x - rec.bx), r2(pos.z - rec.bz), r2(pos.y - rec.by + 0.5)
end

-- Navigation events.
NAV.on_event = function(self, kind)
	local rec = tracked[self]
	if rec and rec.t0 and not rec.done then
		count(rec, "nav_" .. kind)
		local pos = self.object and self.object:get_pos()
		local detail
		if pos then
			local u, v, h = lane_cell(rec, pos)
			detail = {u, v, h}
		end
		event(rec, kind, detail)
	end
end

-- The combat step: window verdicts, counted failures and why.
do
	local orig = NAV.combat_step
	NAV.combat_step = function(self, pos, dtime, target, target_pos, dist,
			striking, never_give_up)
		local rec = tracked[self]
		if not rec or not rec.t0 or rec.done then
			return orig(self, pos, dtime, target, target_pos, dist, striking,
				never_give_up)
		end
		local nst = self.temp and self.temp.grug_nav
		local fails0, line_left0 = 0, nil
		if nst then
			nst.seen = nil -- read back below: set only when a window ends
			fails0, line_left0 = nst.fails or 0, nst.line_left
		end
		local path0 = nst and nst.path ~= nil
		in_combat_step = rec
		local steer, outcome = orig(self, pos, dtime, target, target_pos, dist,
			striking, never_give_up)
		in_combat_step = nil
		nst = self.temp and self.temp.grug_nav
		rec.striking, rec.dist = striking, dist
		if nst and nst.seen then
			local expected = nst.we or 0
			local dx, dz = pos.x - (nst.wx or pos.x), pos.z - (nst.wz or pos.z)
			local ratio = expected > 0 and sqrt(dx * dx + dz * dz) / expected or 0
			count(rec, "win_" .. nst.seen)
			rec.ratios[#rec.ratios + 1] = r2(ratio)
			event(rec, "win_" .. nst.seen, r2(ratio))
		end
		if nst and (nst.fails or 0) > fails0 then
			local why
			if line_left0 then why = "line_fail"
			elseif path0 and not nst.path then why = "path_stuck"
			else why = "search_fail" end
			count(rec, why)
			event(rec, why, nst.fails)
		elseif outcome == "give_up" then
			-- fail() forgot the state: the third failure in a row.
			local why = line_left0 and "line_fail" or (path0 and "path_stuck"
				or "search_fail")
			count(rec, why)
			event(rec, why, fails0 + 1)
		end
		return steer, outcome
	end
end

-- Line tests against the target (the follower's "line" and the episode's
-- "free" check pass rise = 1; the smoothing passes none).
do
	local orig = NAV.line_walkable
	NAV.line_walkable = function(body, a, b, rise)
		local ok = orig(body, a, b, rise)
		local rec = in_combat_step
		if rec and rise then
			count(rec, ok and "line_true" or "line_false")
			event(rec, ok and "line_true" or "line_false")
		end
		return ok
	end
end

-- Engine searches and the head-room/width check (since Round 49 NAV2 the
-- real code repairs a path and escalates the padding itself; the probe's
-- "pad" and "repair" variants went with that). VARIANT is set per batch.
local VARIANT = {}
do
	local orig_search = NAV.search
	NAV.search = function(from, goal, padding, jump, drop)
		local t0 = now()
		local path = orig_search(from, goal, padding, jump, drop)
		local rec = in_combat_step
		if rec then
			local fu, fv, fh = lane_cell(rec, {x = from.x, y = from.y - 0.5, z = from.z})
			local gu, gv, gh = lane_cell(rec, {x = goal.x, y = goal.y - 0.5, z = goal.z})
			count(rec, "searches")
			if path then count(rec, "searches_found") end
			rec.search_us = (rec.search_us or 0) + (now() - t0)
			event(rec, "search", {{fu, fv, fh}, {gu, gv, gh}, padding,
				jump, drop, path and #path or 0, now() - t0})
		end
		return path
	end
	local orig_check = NAV.check_path

	NAV.check_path = function(body, path)
		local out, repaired = orig_check(body, path)
		local rec = in_combat_step
		if rec and not out then
			local bad
			for i = 2, #path do
				local part = {}
				for k = 1, i do part[k] = path[k] end
				if not orig_check(body, part) then bad = i; break end
			end
			local p = bad and path[bad]
			local detail = {bad, #path}
			if p then
				local u, v, h = lane_cell(rec, {x = p.x, y = p.y - 0.5, z = p.z})
				detail[3] = {u, v, h}
			end
			event(rec, "reject_at", detail)
		end
		return out, repaired
	end
end

-- mobs_redo: dropping the target (patience, distance) and our give-up.
local re_engage
do
	local orig = mc.stop_attack
	mc.stop_attack = function(self)
		local rec = tracked[self]
		local was = self.attack
		local r = orig(self)
		if rec and rec.t0 and not rec.done and was then
			count(rec, "stop_attack")
			event(rec, "stop_attack")
			if re_engage then re_engage(rec) end
		end
		return r
	end
	local G = grug_mobs
	local orig_give_up = G.give_up_target
	G.give_up_target = function(self)
		local rec = tracked[self]
		if rec and rec.t0 and not rec.done then
			count(rec, "give_up")
		end
		return orig_give_up(self)
	end
	-- A ranged mover's shot: the shoot branch plays the "shoot" clip as it
	-- fires (mobs/api.lua do_states); recorded with the mob's sight of its
	-- target (the shoot branch's own test).
	local orig_set_animation = mc.set_animation
	mc.set_animation = function(self, anim, force)
		local rec = tracked[self]
		if anim == "shoot" and rec and rec.t0 and not rec.done and self.attack then
			local pos = self.object:get_pos()
			local dpos = self.attack:get_pos()
			local seen = pos and dpos and OB.target_visible(self, pos, dpos, false)
			count(rec, seen and "shots" or "shots_blind")
			if seen and not rec.shot_t then rec.shot_t = r2(trial_time(rec)) end
			event(rec, seen and "shot" or "shot_blind")
		end
		return orig_set_animation(self, anim, force)
	end
	local orig_set_velocity = mc.set_velocity
	mc.set_velocity = function(self, v)
		if tracked[self] then
			self._r49_cmd = self.order == "stand" and 0 or (v or 0)
		end
		return orig_set_velocity(self, v)
	end
end

do
	local orig = mc.on_step
	mc.on_step = function(self, dtime, moveresult)
		local rec = tracked[self]
		if rec and moveresult and moveresult.collisions then
			for _, col in ipairs(moveresult.collisions) do
				if col.type == "node" and col.axis ~= "y" then rec.coll = true end
			end
		end
		return orig(self, dtime, moveresult)
	end
end

---------------------------------------------------------------------------
-- The target dummy (a player's collision box)
---------------------------------------------------------------------------
local hits = setmetatable({}, {__mode = "k"}) -- dummy luaentity -> trial rec

core.register_entity(MOD .. ":dummy", {
	initial_properties = {
		physical = true, collide_with_objects = false, static_save = false,
		hp_max = 1000, visual = "cube",
		textures = {"default_stone.png", "default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png", "default_stone.png"},
		visual_size = {x = 0.6, y = 1.77},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3},
	},
	on_punch = function(self, puncher)
		local rec = hits[self]
		if not rec or not rec.t0 or rec.done then return true end
		local by_mob = puncher and rec.obj and puncher == rec.obj
		local key = by_mob and "hits" or "hits_other"
		count(rec, key)
		if by_mob or (puncher and not puncher:is_player()) then
			local mpos = rec.obj and rec.obj:get_pos()
			local detail
			if mpos then
				local u, v, h = lane_cell(rec, mpos)
				detail = {u, v, h}
			end
			if not rec.hit_t and by_mob then
				rec.hit_t = r2(trial_time(rec))
				rec.hit_at = detail
			end
			if not rec.any_hit_t then rec.any_hit_t = r2(trial_time(rec)) end
			event(rec, by_mob and "hit" or "hit_other", detail)
		end
		return true
	end,
})

---------------------------------------------------------------------------
-- Movers and trials
---------------------------------------------------------------------------
local MOVERS = {
	zombie = {entity = "grug_mobs:zombie", T = 20, note = "narrow, 1.9 tall"},
	rat = {entity = "grug_mobs:giant_rat", T = 20, note = "wide (1.28), 1 tall"},
	-- A candidate the user declined (2026-10-15), applied by the probe only:
	--   narrow the rat's collision box 0.98 wide instead of 1.28 (a narrow
	--          mob: no 2x2 width check, it passes 1-wide gaps).
	-- (Phase 1's "pad" and "repair" candidates are the real code since Round
	-- 49 NAV2: zombie and rat run them.)
	rat_narrow = {entity = "grug_mobs:giant_rat", T = 20, variant = "narrow",
		note = "rat with a 0.98-wide collision box"},
	archer = {entity = "grug_mobs:skeleton_archer", T = 12,
		note = "ranged ground mob (dogshoot): paths to regain sight (Round 49 NAV2)"},
}

local active = {}

local function feet(pos) return {x = pos.x, y = pos.y - 0.5, z = pos.z} end

-- A trial spec: name, phase, the local frame (bx, bz, by), the start and
-- target cells (world node positions of the feet layer), the target in local
-- coordinates, the side step for a re-engagement and an optional strafe.
local function lane_spec(index)
	local lane = LANES[index]
	local scene = lane.scene
	local bx, bz = lane_base(index)
	local t = scene.target
	return {name = scene.name, phase = lane.phase, lane = index,
		bx = bx, bz = bz, by = FLOOR_Y,
		start = cell_pos(index, 0, 0, 1),
		target = cell_pos(index, t[1], t[2], t[3]), target_local = t,
		side = {x = 0, z = 1}, strafe = scene.strafe}
end

-- The "narrow" variant: a collision box 0.98 wide, kept on the entity (the
-- level code rescales from base_colbox).
local function narrow(ent)
	local b = ent.base_colbox
	if b[4] - b[1] <= 0.98 then return end
	ent.base_colbox = {-0.49, b[2], -0.49, 0.49, b[5], 0.49}
	local box = OB.physics_box(ent.base_colbox, ent)
	ent.object:set_properties({collisionbox = box})
	ent._grug_cbox = box
end

local function new_rec(mover_id, spec)
	return {mover = mover_id, scene = spec.name, phase = spec.phase,
		lane = spec.lane, spec = spec, bx = spec.bx, bz = spec.bz, by = spec.by,
		target = spec.target_local, track = {}, events = {}, counts = {},
		ratios = {}, cycles = 0}
end

-- Static checks: the walkable line and the engine's search from the start.
local orig_find_path = core.find_path
local orig_line = NAV.line_walkable
local orig_check_path = NAV.check_path

local function static_checks(rec)
	local ent, obj = rec.ent, rec.obj
	local pos = obj and obj:get_pos()
	if not ent or not pos then return end
	local body = NAV.body(ent)
	local fy = floor(pos.y + body.feet + 0.55)
	local from = {x = floor(pos.x + 0.5), y = fy, z = floor(pos.z + 0.5)}
	local goal = {x = rec.goal_cell.x, y = rec.goal_cell.y, z = rec.goal_cell.z}
	local st = {
		body = {width = r2(body.width), head = body.head, step = body.step,
			jump = body.jump, drop = body.drop},
		line = orig_line(body, {x = pos.x, y = pos.y + body.feet, z = pos.z}, goal, 1),
	}
	for _, pad in ipairs({6, 12}) do
		local path = orig_find_path(from, goal, pad, body.jump, body.drop,
			"A*_noprefetch")
		st["path" .. pad] = path and #path or 0
		if path then st["path" .. pad .. "_ok"] = orig_check_path(body, path) ~= nil end
	end
	rec.static = st
end

re_engage = function(rec)
	if rec.done or rec.pending then return end
	rec.pending = true
	rec.cycles = rec.cycles + 1
	core.after(1, function()
		rec.pending = nil
		if not rec.t0 or rec.done then return end
		local dummy, ent = rec.dummy, rec.ent
		if not dummy or not dummy:get_pos() or not ent or not ent.object
				or not ent.object:get_pos() then
			return
		end
		-- One node aside and back, as a player who moves is acquired again
		-- (a strafing target moves anyway).
		local spec = rec.spec
		if not spec.strafe then
			local side = (rec.cycles % 2 == 1) and 1 or 0
			local g = {x = spec.target.x + spec.side.x * side, y = spec.target.y,
				z = spec.target.z + spec.side.z * side}
			if spec.side_y then g.y = spec.side_y end
			if side == 0 then g.y = spec.target.y end
			dummy:set_pos(feet(g))
			rec.goal_cell = {x = g.x, y = g.y, z = g.z}
		end
		event(rec, "re_engage", rec.cycles)
		ent:do_attack(dummy, true)
	end)
end

local function start_trial(rec)
	local ent, obj = rec.ent, rec.obj
	if not ent or not obj or not obj:get_pos() then
		rec.lost = true
		return
	end
	local spec = rec.spec
	local g = spec.target
	rec.goal_cell = {x = g.x, y = g.y, z = g.z}
	if VARIANT.narrow then narrow(ent) end
	grug_mobs.place_on_ground(obj, feet(spec.start))
	obj:set_velocity({x = 0, y = 0, z = 0})
	ent:set_yaw(core.dir_to_yaw({x = g.x - spec.start.x, y = 0,
		z = g.z - spec.start.z}), 0)
	local dummy = core.add_entity(feet(g), MOD .. ":dummy")
	rec.dummy = dummy
	local dent = dummy and dummy:get_luaentity()
	if dent then hits[dent] = rec end
	static_checks(rec)
	rec.t0 = now()
	ent:do_attack(dummy, true)
end

local SAMPLE_EVERY = 0.25

-- A strafing target walks along the spec's side axis, a sine of `amp` nodes
-- over `period` s, at its feet height (the lanes are flat where it walks).
local function strafe(rec, t)
	local spec = rec.spec
	local s = spec.strafe
	if not s or not rec.dummy or not rec.dummy:get_pos() then return end
	local off = s.amp * math.sin(2 * math.pi * t / s.period)
	local g = spec.target
	local p = {x = g.x + spec.side.x * off, y = g.y, z = g.z + spec.side.z * off}
	rec.dummy:set_pos(feet(p))
	rec.goal_cell = {x = floor(p.x + 0.5), y = g.y, z = floor(p.z + 0.5)}
end

local function sample(rec)
	if not rec.t0 or rec.done then return end
	local obj = rec.obj
	local pos = obj and obj:get_pos()
	if not pos then
		if not rec.lost then
			rec.lost = true
			event(rec, "lost")
		end
		return
	end
	local ent = rec.ent
	local t = trial_time(rec)
	strafe(rec, t)
	local dpos = rec.dummy and rec.dummy:get_pos()
	local ddx, ddz = dpos and pos.x - dpos.x or 99, dpos and pos.z - dpos.z or 0
	local d = sqrt(ddx * ddx + ddz * ddz)
	if not rec.min_d or d < rec.min_d then rec.min_d = d end
	if t < (rec.next_sample or 0) then return end
	rec.next_sample = t + SAMPLE_EVERY
	local flags = 0
	if ent.state == "attack" then flags = flags + 1 end
	if ent.temp and ent.temp.grug_nav and ent.temp.grug_nav.path then flags = flags + 2 end
	if rec.coll then flags = flags + 4 end
	if rec.striking then flags = flags + 8 end
	if ent.attack and dpos and OB.target_visible(ent, pos, dpos,
			ent.attack_type == "dogfight") then
		flags = flags + 16
	end
	rec.coll = false
	local u, v, h = lane_cell(rec, pos)
	local tu, tv = lane_cell(rec, dpos or pos)
	rec.track[#rec.track + 1] = {r2(t), u, v, h, r2(ent._r49_cmd or 0), flags,
		r2(d), tu, tv}
end

core.register_globalstep(function()
	for i = 1, #active do sample(active[i]) end
end)

local function finish_trial(rec, mover)
	rec.done = true
	local spec = rec.spec
	local row = {
		scene = rec.scene, phase = rec.phase, mover = rec.mover, lane = rec.lane,
		entity = rec.entity, T = mover.T, target = rec.target,
		reached = rec.hit_t ~= nil, t_hit = rec.hit_t, hit_at = rec.hit_at,
		any_hit_t = rec.any_hit_t, min_d = rec.min_d and r2(rec.min_d),
		cycles = rec.cycles, counts = rec.counts, ratios = rec.ratios,
		t_shot = rec.shot_t,
		static = rec.static, search_us = rec.search_us, lost = rec.lost,
		events = rec.events, track = rec.track, site = spec.site,
		frame = {x = spec.bx, z = spec.bz, y = spec.by},
	}
	results.trials[#results.trials + 1] = row
	local cn = {}
	for k, v in pairs(rec.counts) do cn[#cn + 1] = k .. "=" .. v end
	table.sort(cn)
	local st = rec.static or {}
	log(("TRIAL %-7s %-22s reached=%-5s t=%-6s min_d=%-5s line0=%s p6=%s p12=%s %s"):format(
		rec.mover, rec.scene, tostring(row.reached), tostring(row.t_hit),
		tostring(row.min_d), tostring(st.line), tostring(st.path6),
		tostring(st.path12), table.concat(cn, " ")))
end

-- One batch: one mover on every spec at once.
local function run_batch(mover_id, specs, label, done)
	local mover = MOVERS[mover_id]
	if not mover or not core.registered_entities[mover.entity] or #specs == 0 then
		log("skip batch " .. label)
		return done()
	end
	core.set_timeofday(0)
	active = {}
	VARIANT = {}
	for word in (mover.variant or ""):gmatch("[%w_]+") do VARIANT[word] = true end
	local recs = {}
	for _, spec in ipairs(specs) do
		local obj = core.add_entity(feet(spec.start), mover.entity)
		local ent = obj and obj:get_luaentity()
		if ent and VARIANT.narrow then narrow(ent) end
		local rec = new_rec(mover_id, spec)
		rec.entity = mover.entity
		if ent then
			rec.obj, rec.ent = obj, ent
			tracked[ent] = rec
		else
			rec.lost = true
			log("could not spawn " .. mover.entity)
		end
		recs[#recs + 1] = rec
	end
	core.after(1, function()
		for _, rec in ipairs(recs) do
			local ok, err = pcall(start_trial, rec)
			if not ok then core.log("error", P .. "start " .. rec.scene .. ": " .. tostring(err)) end
			active[#active + 1] = rec
		end
		local probe = recs[1] and recs[1].ent
		if probe and probe.object and not results.movers[mover_id] then
			local box = probe._grug_cbox or probe.object:get_properties().collisionbox
			results.movers[mover_id] = {entity = mover.entity, note = mover.note,
				T = mover.T, width = r2(box[4] - box[1]), height = r2(box[5] - box[2]),
				run_velocity = probe.run_velocity, reach = probe.reach,
				stepheight = probe.object:get_properties().stepheight,
				jump_height = probe.jump_height, fear_height = probe.fear_height,
				attack_type = probe.attack_type, pathfinding = probe.pathfinding,
				tier = probe._grug_tier, level = probe._grug_level}
		end
		local t_start = now()
		local cpu0 = os.clock()
		local c0 = {searches = NAV.counters.searches, found = NAV.counters.found}
		core.after(mover.T, function()
			for _, rec in ipairs(recs) do
				local ok, err = pcall(finish_trial, rec, mover)
				if not ok then core.log("error", P .. "finish " .. rec.scene .. ": " .. tostring(err)) end
				if rec.ent then tracked[rec.ent] = nil end
				if rec.obj then rec.obj:remove() end
				if rec.dummy then rec.dummy:remove() end
			end
			active = {}
			VARIANT = {}
			results.batches[#results.batches + 1] = {mover = mover_id, label = label,
				seconds = r2((now() - t_start) / 1e6), cpu_s = r2(os.clock() - cpu0),
				searches = NAV.counters.searches - c0.searches,
				found = NAV.counters.found - c0.found,
				largest_us = NAV.counters.largest_us}
			write_results()
			core.after(0.5, done)
		end)
	end)
end

---------------------------------------------------------------------------
-- Natural terrain (phase "real")
---------------------------------------------------------------------------
local REAL_BIOMES = {"grug_meadows", "grug_deep_forest", "grug_pine_hills"}
local REAL_R = 36 -- half side of the generated box round a site
local REAL_MAX = 6 -- trials per obstacle kind and site
local SEP = 12 -- nodes between any two trials' ends

local function node_def(x, y, z)
	local node = core.get_node_or_nil({x = x, y = y, z = z})
	if not node or node.name == "ignore" then return nil, "ignore" end
	return core.registered_nodes[node.name], node.name
end

local function is_liquid(def)
	return def and def.liquidtype and def.liquidtype ~= "none"
end

-- Feet cell (x, y, z) free for a 2-high body on walkable, non-liquid ground.
local function standable(x, y, z)
	for dy = 0, 1 do
		local def = node_def(x, y + dy, z)
		if not def or def.walkable or is_liquid(def) then return false end
	end
	local below = node_def(x, y - 1, z)
	return below ~= nil and below.walkable == true
end

local function stand_y(x, z, y0, band)
	for dy = 0, band do
		if standable(x, y0 + dy, z) then return y0 + dy end
		if dy > 0 and standable(x, y0 - dy, z) then return y0 - dy end
	end
end

local function find_sites()
	local sites, want = {}, {}
	for _, b in ipairs(REAL_BIOMES) do want[b] = true end
	local left = #REAL_BIOMES
	for r = 1, 80 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 40, c[2] * 40
				local b = grug_zones.biome_at(x, z)
				if want[b] then
					local h = grug_zones.terrain_height_at(x, z)
					if h and h >= 3 and h <= 90
							and not grug_zones.hard_protection_kind_at({x = x, y = h, z = z}) then
						want[b] = nil
						left = left - 1
						sites[#sites + 1] = {biome = b, x = x, y = floor(h), z = z}
						if left == 0 then return sites end
					end
				end
			end
		end
	end
	return sites
end

local function site_box(site)
	return {x = site.x - REAL_R, y = site.y - 16, z = site.z - REAL_R},
		{x = site.x + REAL_R, y = site.y + 24, z = site.z + REAL_R}
end

-- Obstacle centres of one kind in a site, separated by 3 nodes.
local function obstacles(site, names, kind)
	local minp, maxp = site_box(site)
	local list, known = {}, {}
	for _, name in ipairs(names) do
		if core.registered_nodes[name] then known[#known + 1] = name end
	end
	if #known == 0 then return list end
	for _, p in ipairs(core.find_nodes_in_area(minp, maxp, known)) do
		local keep = true
		if kind == "trunk" then
			-- The trunk's foot: no trunk node right below.
			local _, below = node_def(p.x, p.y - 1, p.z)
			for _, name in ipairs(known) do
				if below == name then keep = false end
			end
		end
		if keep then
			for _, q in ipairs(list) do
				if abs(q.x - p.x) <= 3 and abs(q.z - p.z) <= 3 and abs(q.y - p.y) <= 3 then
					keep = false
					break
				end
			end
		end
		if keep then list[#list + 1] = p end
	end
	return list
end

local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

local function far_from(chosen, p)
	for _, q in ipairs(chosen) do
		local dx, dz = q.x - p.x, q.z - p.z
		if dx * dx + dz * dz < SEP * SEP then return false end
	end
	return true
end

-- One trial round obstacle `o`: the target `rt` behind it, the mob `k` before
-- it, the line between them through the obstacle. For a bush the best trial
-- has the target 1-2 nodes higher than the mob.
local function trial_round(o, kind, chosen)
	local best, best_score
	local rts = kind == "trunk" and {1, 2} or {2, 3}
	for _, d in ipairs(DIRS) do
		for _, rt in ipairs(rts) do
			local tx, tz = o.x + d[1] * rt, o.z + d[2] * rt
			local ty = stand_y(tx, tz, o.y, 3)
			if ty then
				for k = 2, 7 do
					local sx, sz = o.x - d[1] * k, o.z - d[2] * k
					local sy = stand_y(sx, sz, o.y, 3)
					if sy then
						local dx, dz = tx - sx, tz - sz
						local dist = sqrt(dx * dx + dz * dz)
						local s = {x = sx, y = sy, z = sz}
						local t = {x = tx, y = ty, z = tz}
						if dist >= 3 and dist <= 8 and far_from(chosen, s)
								and far_from(chosen, t) then
							local dh = ty - sy
							local score
							if kind == "trunk" then
								score = (dh == 0 and 10 or (dh > 0 and 8 or 5)) - abs(dist - 5) * 0.1
							else
								score = ((dh == 1 or dh == 2) and 10 or (dh > 2 and 6
									or (dh == 0 and 4 or 2))) - abs(dist - 5) * 0.1
							end
							if not best_score or score > best_score then
								best_score = score
								best = {start = s, target = t, dist = r2(dist), dh = dh,
									dir = d, rt = rt, k = k}
							end
						end
					end
				end
			end
		end
	end
	return best
end

-- The nodes round a trial (its ends' box padded by 3, from 2 below the lower
-- end to 4 above the higher one): a palette and the names' indices, x
-- fastest, then z, then y.
local function geometry(spec)
	local s, t = spec.start, spec.target
	local minp = {x = math.min(s.x, t.x) - 3, y = math.min(s.y, t.y) - 2,
		z = math.min(s.z, t.z) - 3}
	local maxp = {x = math.max(s.x, t.x) + 3, y = math.max(s.y, t.y) + 4,
		z = math.max(s.z, t.z) + 3}
	local palette, index, cells = {}, {}, {}
	for y = minp.y, maxp.y do
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				local name = core.get_node({x = x, y = y, z = z}).name
				if not index[name] then
					palette[#palette + 1] = name
					index[name] = #palette
				end
				cells[#cells + 1] = index[name]
			end
		end
	end
	return {minp = minp, maxp = maxp, palette = palette, cells = cells}
end

local REAL_KINDS = {
	{kind = "bush", names = {"default:bush_stem", "default:pine_bush_stem",
		"default:acacia_bush_stem"}},
	{kind = "blue", names = {"default:blueberry_bush_leaves",
		"default:blueberry_bush_leaves_with_berries"}},
	{kind = "trunk", names = {"default:tree", "default:aspen_tree",
		"default:pine_tree", "default:jungletree", "default:acacia_tree",
		"grug_trees:silverwood_tree", "grug_trees:gravewood_tree",
		"grug_trees:apple_quarter", "grug_trees:aspen_quarter",
		"grug_trees:pine_quarter", "grug_trees:jungle_quarter",
		"grug_trees:acacia_quarter", "grug_trees:silverwood_quarter",
		"grug_trees:gravewood_quarter"}},
}

local real_specs = {}

local function plan_real()
	local chosen = {}
	for si, site in ipairs(results.sites) do
		for _, kd in ipairs(REAL_KINDS) do
			local list = obstacles(site, kd.names, kd.kind)
			site["n_" .. kd.kind] = #list
			local made = 0
			for _, o in ipairs(list) do
				if made >= REAL_MAX then break end
				-- The obstacle's own ground level: a bush stem or trunk foot
				-- stands in the feet layer; blueberry leaves too.
				local tr = trial_round(o, kd.kind, chosen)
				if tr then
					made = made + 1
					chosen[#chosen + 1] = tr.start
					chosen[#chosen + 1] = tr.target
					local _, oname = node_def(o.x, o.y, o.z)
					local spec = {
						name = ("%s_%s%d"):format(site.biome:gsub("^grug_", ""), kd.kind, made),
						phase = "real", bx = tr.start.x, bz = tr.start.z, by = tr.start.y - 1,
						start = tr.start, target = tr.target,
						side = {x = -tr.dir[2], z = tr.dir[1]},
						site = {biome = site.biome, kind = kd.kind, obstacle = o,
							obstacle_node = oname, dist = tr.dist, dh = tr.dh, rt = tr.rt,
							k = tr.k, dir = tr.dir, site = si},
					}
					spec.target_local = {tr.target.x - tr.start.x, tr.target.z - tr.start.z,
						tr.target.y - tr.start.y + 1}
					-- The side step only where the target can stand.
					local sy = stand_y(tr.target.x + spec.side.x, tr.target.z + spec.side.z,
						tr.target.y, 1)
					if sy then spec.side_y = sy else spec.side = {x = 0, z = 0} end
					spec.site.geometry = geometry(spec)
					real_specs[#real_specs + 1] = spec
				end
			end
		end
		log(("SITE %s at %d,%d,%d: bushes %d, blueberry %d, trunks %d"):format(
			site.biome, site.x, site.y, site.z, site.n_bush or 0, site.n_blue or 0,
			site.n_trunk or 0))
	end
	log("real trials: " .. #real_specs)
end

local function prepare_real(done)
	results.sites = find_sites()
	if #results.sites == 0 then
		log("no natural site found")
		return done()
	end
	local pending = #results.sites
	local t0 = now()
	for _, site in ipairs(results.sites) do
		local minp, maxp = site_box(site)
		for bx = floor(minp.x / 16), floor(maxp.x / 16) do
			for bz = floor(minp.z / 16), floor(maxp.z / 16) do
				for by = floor(minp.y / 16), floor(maxp.y / 16) do
					core.forceload_block(vector.new(bx * 16, by * 16, bz * 16), true, -1)
				end
			end
		end
		core.emerge_area(minp, maxp, function(_, _, remaining)
			if remaining ~= 0 then return end
			pending = pending - 1
			if pending == 0 then
				log(("sites emerged in %.1f s"):format((now() - t0) / 1e6))
				-- One second for the forceloaded blocks to activate.
				core.after(1, function()
					local ok, err = pcall(plan_real)
					if not ok then core.log("error", P .. "plan_real: " .. tostring(err)) end
					done()
				end)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
-- Every lane of the selected lists runs in one batch per mover ("lanes"),
-- then the natural trials ("real").
local function lane_specs()
	local specs = {}
	for index in ipairs(LANES) do specs[#specs + 1] = lane_spec(index) end
	return specs
end

local function run_all()
	local queue = {}
	local jobs = {}
	if #LANES > 0 then jobs[#jobs + 1] = "lanes" end
	if PHASES.real then jobs[#jobs + 1] = "real" end
	for _, phase in ipairs(jobs) do
		for _, mover in ipairs(MOVER_ORDER) do
			queue[#queue + 1] = {phase = phase, mover = mover}
		end
	end
	local i = 0
	local cpu0 = os.clock()
	local function next_batch()
		i = i + 1
		local job = queue[i]
		if not job then
			results.meta.cpu_s = r2(os.clock() - cpu0)
			write_results()
			log("RESULT DONE")
			core.request_shutdown("r49nav done", false, 0)
			return
		end
		local specs = job.phase == "real" and real_specs or lane_specs()
		log("batch " .. job.phase .. " " .. job.mover .. " (" .. #specs .. " trials)")
		run_batch(job.mover, specs, job.phase .. "_" .. job.mover, next_batch)
	end
	next_batch()
end

local function after_arena()
	if PHASES.real then
		prepare_real(run_all)
	else
		run_all()
	end
end

core.after(1, function()
	math.randomseed(4949)
	results.meta.seed = core.get_mapgen_setting("seed")
	results.meta.phases = PHASE_ORDER
	results.meta.settings = {}
	for _, key in ipairs({"mob_pathfinding_algorithm", "dedicated_server_step",
			"mob_pathfinding_enable"}) do
		results.meta.settings[key] = core.settings:get(key)
	end
	-- Every registered dogshoot mob: flier or ground, pathfinding.
	results.meta.ranged = {}
	for name, def in pairs(core.registered_entities) do
		if def.attack_type == "dogshoot" then
			results.meta.ranged[#results.meta.ranged + 1] = {name = name,
				fly = def.fly == true, pathfinding = def.pathfinding or false}
			log(("RANGED %s fly=%s pathfinding=%s"):format(name,
				tostring(def.fly == true), tostring(def.pathfinding)))
		end
	end
	results.meta.nav = {PADDING = NAV.PADDING, PADDING_STEPS = NAV.PADDING_STEPS,
		CLOSE = NAV.CLOSE,
		STUCK_RATIO = NAV.STUCK_RATIO, WINDOW = NAV.WINDOW.combat,
		GIVE_UP_AFTER = NAV.GIVE_UP_AFTER, LOCKOUT = NAV.LOCKOUT.combat}
	results.meta.scenes = {}
	for _, lane in ipairs(LANES) do
		local scene = lane.scene
		results.meta.scenes[#results.meta.scenes + 1] = {name = scene.name,
			note = scene.note, target = scene.target, phase = lane.phase}
	end
	if #LANES == 0 then return after_arena() end
	origin = find_origin()
	if not origin then
		core.log("error", P .. "no deep-ocean arena origin")
		return core.request_shutdown("r49nav fail", false, 0)
	end
	local minp, maxp = arena_box()
	results.meta.origin = {x = origin.x, z = origin.z, floor_y = FLOOR_Y}
	log("arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	for bx = floor(minp.x / 16), floor(maxp.x / 16) do
		for bz = floor(minp.z / 16), floor(maxp.z / 16) do
			for by = floor(minp.y / 16), floor(maxp.y / 16) do
				core.forceload_block(vector.new(bx * 16, by * 16, bz * 16), true, -1)
			end
		end
	end
	local t0 = now()
	core.emerge_area(vector.offset(minp, -16, -16, -16), vector.offset(maxp, 16, 16, 16),
		function(_, _, remaining)
			if remaining ~= 0 then return end
			log(("arena emerged in %.1f s"):format((now() - t0) / 1e6))
			core.after(0, function()
				local ok, err = pcall(build_arena)
				if not ok then
					core.log("error", P .. "build: " .. tostring(err))
					return core.request_shutdown("r49nav fail", false, 0)
				end
				log("arena built")
				core.after(1, after_arena)
			end)
		end)
end)
