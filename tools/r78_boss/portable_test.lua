-- Round 78 lane BOSS portable test (round78-plan.md ruling 6 and §3.1): the
-- stand-off distance, the distance-based ranged/melee choice and friendly
-- casts past hostile bodies. Loads the REAL mobs/grug_obstacle.lua (the edge
-- measures), the REAL distance mode, shot range and closing helpers and the
-- attack branch conditions cut out of mobs/api.lua, the REAL
-- grug_mobs/separation.lua (its column push), the REAL
-- grug_core/combat_ray.lua and the REAL aimed_target out of
-- grug_abilities/kits.lua, on a small fake engine. Checks:
--   E  the edge measures: gap, step allowance, height beyond it, the reach
--      edge to edge (an ordinary mob reaches as before on level ground, an
--      elite as far past its grown edge), the stop gap, fliers unchanged;
--   C  the contact run: Flintback, Auditor Nemm and the Duewarden (elite
--      scale) and the normal Stone Golem run at a standing player and stop
--      about a node off, never inside, and every hit lands there; a target
--      one node up on a step is struck; a target walking backwards stays
--      in reach at every swing; a body inside the target is pushed out to
--      the column gap;
--   M  the mode choice with hysteresis (no flip at either line), the blind
--      approach and its 1 s re-check (sight back outside the melee line
--      shoots, inside it melees), the unreachable target shot at and melee
--      waiting for reach, a mob without a switch and the saved field;
--   R  the branches: closing in under sight beyond the shot range, shooting
--      inside it, melee by mode, the blind approach walks and may search;
--   F  the friendly ray: past a mob, a hostile and a dead player to the tank;
--      a node still blocks; no ally ends empty (the caster's fallback); the
--      hostile ray unchanged; aimed_target passes the option for friendly
--      skills only;
--   P  the per-step cost of the new decision against the old (printed).
-- Usage (repo root): luajit tools/r78_boss/portable_test.lua [REPO]
-- Prints "R78 BOSS PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
-- The text from `from` up to (not including) `to`.
local function cut(src, from, to, label)
	local s = src:find(from, 1, true)
	check(s ~= nil, "anchor " .. label)
	local e = src:find(to, s + #from, true)
	check(e ~= nil, "end anchor " .. label)
	return src:sub(s, e - 1)
end
local function load_in(src, env, label)
	local chunk = assert(loadstring(src, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.normalize(v)
	local l = vector.length(v)
	return l > 0 and vector.multiply(v, 1 / l) or vector.new(0, 0, 0)
end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end

local nodes = {} -- "x,y,z" -> name; absent: air, below y 1 stone
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function round(v) return math.floor(v + 0.5) end
local function name_at(x, y, z)
	return nodes[key(x, y, z)] or (y <= 0 and "stone" or "air")
end
core = {
	registered_nodes = {air = {name = "air", walkable = false},
		stone = {name = "stone", walkable = true}},
	registered_entities = {},
	get_us_time = function() return 0 end,
	get_objects_in_area = function() return {} end,
}
function core.get_node_or_nil(pos)
	return {name = name_at(round(pos.x), round(pos.y), round(pos.z)), param2 = 0}
end

local api = read("mods/ENTITIES/mobs/api.lua")
local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")

-- The REAL definitions' boxes and reaches (golem.lua, skeleton_raider.lua,
-- land_guard.lua), read from the files.
local function def_box(path, anchor)
	local text = read(path)
	local s = text:find(anchor, 1, true)
	check(s ~= nil, "anchor " .. anchor)
	local box = text:match("collisionbox = (%b{})", s)
	local nums = {}
	for n in box:gmatch("%-?[%d%.]+") do nums[#nums + 1] = tonumber(n) end
	check(#nums == 6, "a box in " .. path)
	local reach = tonumber(text:match("reach = (%d+)", s))
	return nums, reach
end
local GOLEM_BOX, GOLEM_REACH = def_box("mods/ENTITIES/grug_mobs/golem.lua", "local function golem_def")
local RAIDER_BOX, RAIDER_REACH = def_box("mods/ENTITIES/grug_mobs/skeleton_raider.lua",
	"local function raider_def")
local GUARD_BOX, GUARD_REACH = def_box("mods/ENTITIES/grug_mobs/land_guard.lua", "local guard = {")
check(GOLEM_REACH == 3 and RAIDER_REACH == 3 and GUARD_REACH == 3, "E0 the three bosses' reach is 3")
local PLAYER_BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}

-- A player-like target object.
local function new_target(pos, box)
	local t = {pos = pos, box = box or PLAYER_BOX}
	function t:get_pos() return self.pos end
	function t:is_player() return true end
	function t:get_luaentity() return nil end
	function t:get_properties() return {collisionbox = self.box} end
	return t
end
-- A live mob from a registered box at a tier scale (levels.lua: mobs:scale_mob
-- on base_colbox, then grug_obstacle.physics_box).
local function new_mob(box, reach, scale, extra)
	local scaled = {}
	for i = 1, 6 do scaled[i] = box[i] * scale end
	local m = {reach = reach, initial_properties = {collisionbox = box}, temp = {}}
	m._grug_cbox = O.physics_box(scaled, m)
	for k, v in pairs(extra or {}) do m[k] = v end
	return m
end

-- ---------------------------------------------------------------------------
-- E. The edge measures.
-- ---------------------------------------------------------------------------
do
	O.begin_server_step()
	local Y = 0.5 -- player feet on the floor (y 0 top at 0.5)
	-- An ordinary mob with its origin at its feet, radius 0.3, reach 3.
	local raider = new_mob(RAIDER_BOX, 3, 1)
	local target = new_target({x = 3, y = Y, z = 0})
	raider.attack = target
	local edge, gap = O.edge_distance(raider, {x = 0, y = Y, z = 0}, target.pos, target)
	check(near(gap, 2.4) and near(edge, 2.4), "E1 gap = centres - both radii (3 - 0.6)")
	check(near(O.edge_reach(raider), 2.4), "E2 an ordinary mob's reach edge to edge: 3 - 0.3 - 0.3")
	check(edge <= O.edge_reach(raider), "E3 ... so it reaches as before on level ground (3 m centres)")
	-- The golem's origin sits a node above its feet: no height penalty any more.
	local golem = new_mob(GOLEM_BOX, 3, 1)
	golem.attack = target
	edge = O.edge_distance(golem, {x = 0, y = Y + 1, z = 0}, target.pos, target)
	check(near(edge, 2.4), "E4 the golem (origin above its feet) measures from its feet")
	-- Elite scale 1.4: the grown radius counts in the gap, the reach keeps the base.
	local elite = new_mob(GOLEM_BOX, 3, 1.4)
	elite.attack = target
	check(near(O.edge_reach(elite), 2.4), "E5 an elite's edge reach is the normal body's")
	edge, gap = O.edge_distance(elite, {x = 0, y = Y + 1.4, z = 0}, target.pos, target)
	check(near(gap, 3 - 0.42 - 0.3), "E6 the elite's gap subtracts its grown radius")
	-- Height: a step up is free, more adds.
	target.pos = {x = 1.5, y = Y + 1, z = 0}
	edge, gap = O.edge_distance(raider, {x = 0, y = Y, z = 0}, target.pos, target)
	check(near(edge, 0.9, 1e-3) and near(gap, 0.9), "E7 a target one node up on a step: no height cost")
	target.pos = {x = 1.5, y = Y + 3, z = 0}
	edge = O.edge_distance(raider, {x = 0, y = Y, z = 0}, target.pos, target)
	check(near(edge, math.sqrt(0.81 + 4), 0.02), "E8 three nodes up: the two beyond the step count")
	target.pos = {x = 0, y = Y + 4, z = 0}
	edge, gap = O.edge_distance(raider, {x = 0, y = Y, z = 0}, target.pos, target)
	check(near(edge, 3, 0.02) and gap < 0, "E9 straight under a target 4 up: overlap is 0, height 3")
	check(edge > O.edge_reach(raider), "E10 ... out of reach (it was before: 4 > 3)")
	target.pos = {x = 0, y = Y + 3, z = 0}
	check(O.edge_distance(raider, {x = 0, y = Y, z = 0}, target.pos, target) <= O.edge_reach(raider),
		"E11 ... 3 up is in reach (it was before: 3 <= 3)")
	-- melee_measure and the stop gap.
	target.pos = {x = 3, y = Y, z = 0}
	local m_edge, m_gap, m_reach, m_stop = O.melee_measure(raider, {x = 0, y = Y, z = 0}, target.pos, 3)
	check(near(m_edge, 2.4) and near(m_gap, 2.4) and near(m_reach, 2.4) and m_stop == O.STOP_GAP,
		"E12 melee_measure: edge, gap, reach and the stop gap of about a node")
	local short = new_mob(RAIDER_BOX, 2, 1)
	short.attack = target
	local _, _, r2, s2 = O.melee_measure(short, {x = 0, y = Y, z = 0}, target.pos, 3)
	check(near(r2, 1.4) and near(s2, 0.84), "E13 reach 2: edge reach 1.4, stop at 60 % of it")
	local flier = new_mob(RAIDER_BOX, 2, 1, {fly = true})
	flier.attack = target
	local fe, fg, fr, fs = O.melee_measure(flier, {x = 0, y = Y, z = 0}, target.pos, 3.7)
	check(fe == 3.7 and fg == 3.7 and fr == 2 and near(fs, 1.2), "E14 a flier keeps origin distance and 60 %")
	check(near(O.edge_reach(new_mob(RAIDER_BOX, 0, 1)), 0), "E15 reach 0 (villagers): never below 0")
	check(O.should_close_contact(1.1, 1, true) and not O.should_close_contact(1, 1, true)
		and O.should_close_contact(0, 1, false), "E16 the contact run: wider than the stop, or hidden")
end

-- ---------------------------------------------------------------------------
-- C. The contact run on flat ground, 0.09 s steps (the dedicated server step).
-- The attack branch's movement decisions with the REAL measures: chase while
-- out of reach, then the contact run until the stop gap; the swing lands in
-- reach (punch_interval 1 s, banked like api.lua's cadence).
-- ---------------------------------------------------------------------------
local DT = 0.09
local function fight(m, start_x, target, seconds, target_v, origin_dy)
	O.begin_server_step()
	local p = {x = start_x, y = 0.5 + origin_dy, z = 0}
	m.attack = target
	local out = {hits = 0, misses_due = 0, min_gap = math.huge, gaps = {}}
	local timer = 0
	for i = 1, math.floor(seconds / DT + 0.5) do
		O.begin_server_step()
		target.pos = {x = target.pos.x + (target_v or 0) * DT, y = target.pos.y, z = target.pos.z}
		local dx = target.pos.x - p.x
		local dy = target.pos.y - p.y
		local dist = math.sqrt(dx * dx + dy * dy)
		local edge, gap, reach, stop = O.melee_measure(m, p, target.pos, dist)
		timer = math.min(timer + DT, 1)
		local v = 0
		if edge > reach then
			v = m.run_velocity
		elseif O.should_close_contact(gap, stop, true) then
			v = m.run_velocity
		end
		if edge <= reach then out.arrived = true end
		if timer >= 1 then
			if edge <= reach then
				out.hits = out.hits + 1
				timer = 0
			elseif out.arrived then
				out.misses_due = out.misses_due + 1 -- out of reach once it got there
			end
		end
		local step = math.min(v * DT, math.abs(dx))
		p.x = p.x + (dx > 0 and step or -step)
		local _, after = O.edge_distance(m, p, target.pos, target)
		if after < out.min_gap then out.min_gap = after end
		out.gaps[#out.gaps + 1] = after
		out.reach = reach
	end
	local _, gap = O.edge_distance(m, p, target.pos, target)
	out.gap, out.pos = gap, p
	return out
end

local report = {}
do
	local bosses = {
		{name = "Flintback (elite golem)", box = GOLEM_BOX, scale = 1.4, dy = 1.4, run = 4.6},
		{name = "Auditor Nemm (elite raider)", box = RAIDER_BOX, scale = 1.4, dy = 0.014, run = 4.0},
		{name = "Duewarden (elite sentinel)", box = GUARD_BOX, scale = 1.4, dy = 1.414, run = 4.6},
		{name = "Stone Golem (normal)", box = GOLEM_BOX, scale = 1, dy = 1, run = 4.6},
	}
	for _, b in ipairs(bosses) do
		local m = new_mob(b.box, 3, b.scale, {run_velocity = b.run})
		local target = new_target({x = 12, y = 0.5, z = 0})
		local out = fight(m, 0, target, 6, 0, b.dy)
		check(out.gap >= 0.5 and out.gap <= O.STOP_GAP + 1e-9,
			"C1 " .. b.name .. " stops about a node off (" .. string.format("%.2f", out.gap) .. ")")
		check(out.min_gap > 0, "C2 " .. b.name .. " never overlaps its target")
		check(out.hits >= 3 and out.misses_due == 0, "C3 " .. b.name .. " lands every swing there ("
			.. out.hits .. " hits)")
		report[#report + 1] = string.format("%s: stops %.2f nodes off (edge reach %.2f), %d hits in 6 s",
			b.name, out.gap, out.reach, out.hits)
	end
	-- A step: the target one node up.
	local m = new_mob(GOLEM_BOX, 3, 1.4, {run_velocity = 4.6})
	local target = new_target({x = 8, y = 1.5, z = 0})
	local out = fight(m, 0, target, 4, 0, 1.4)
	check(out.hits >= 2 and out.misses_due == 0 and out.gap > 0, "C4 a target one node up on a step is struck")
	-- A target walking backwards at 4.0 from a 4.6 chaser: in reach at every swing.
	m = new_mob(RAIDER_BOX, 3, 1, {run_velocity = 4.6})
	target = new_target({x = 2, y = 0.5, z = 0})
	out = fight(m, 0, target, 10, 4.0, 0)
	check(out.hits >= 9 and out.misses_due == 0, "C5 a target walking backwards is hit at every swing ("
		.. out.hits .. ")")
end

-- The column push (separation.lua): a target that walks into the mob.
do
	grug_mobs = {}
	mobs = {grug_obstacle = O}
	local objects = {}
	function core.get_objects_inside_radius() return objects end
	dofile(repo .. "/mods/ENTITIES/grug_mobs/separation.lua")
	O.begin_server_step()
	local box = {}
	for i = 1, 6 do box[i] = GUARD_BOX[i] * 1.4 end
	local obj = {pos = {x = 0.3, y = 1.914, z = 0}}
	function obj:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function obj:get_yaw() return 0 end
	function obj:move_to(p) self.pos = p end
	local m = {object = obj, _grug_cbox = O.physics_box(box, {}), temp = {}}
	function obj:get_luaentity() return m end
	local target = new_target({x = 0, y = 0.5, z = 0})
	m.attack = target
	objects = {obj}
	grug_mobs.separation_step(m, 0.09, obj:get_pos(), target.pos)
	local _, gap = O.edge_distance(m, obj.pos, target.pos, target)
	check(near(obj.pos.x, 0.8), "C6 a Duewarden inside its tank is pushed back 0.5 m at once")
	grug_mobs.separation_step(m, 1.0, obj:get_pos(), target.pos)
	check(near(obj.pos.x, 1.3), "C7 ... 0.5 m a second ...")
	grug_mobs.separation_step(m, 1.0, obj:get_pos(), target.pos)
	_, gap = O.edge_distance(m, obj.pos, target.pos, target)
	check(near(obj.pos.x, 1.5) and near(gap, 0.5), "C8 ... out to the column gap of 0.5")
	grug_mobs.separation_step(m, 1.0, obj:get_pos(), target.pos)
	check(near(obj.pos.x, 1.5), "C8b ... where the push leaves it (the contact run stops at 1)")
	check(grug_mobs.holds_column == nil, "C9 the old column hold is gone (the stop gap owns it)")
end

-- ---------------------------------------------------------------------------
-- M. The distance mode, cut out of api.lua.
-- ---------------------------------------------------------------------------
local helpers = load_in(cut(api, "local GRUG_SHOT_RANGE_EXTRA = 4", "-- stop attack & reset vars",
	"api helpers") .. "\nreturn {range = grug_shot_range, closing = grug_ranged_closing,"
	.. " mode = grug_dogshoot_mode}", {mobs = {}}, "api helpers")
local mode = helpers.mode
local function shooter(fields)
	local m = {attack_type = "dogshoot", dogshoot_switch = 1, reach = 3, view_range = 16,
		temp = {}, animation_current = "stand"}
	for k, v in pairs(fields or {}) do m[k] = v end
	m.set_velocity = function(self, v) self.velocity = v end
	m.set_animation = function(self, a) self.animation_current = a end
	return m
end
do
	local R = 2.4
	local m = shooter()
	local seq = {{10, 1}, {5, 1}, {4.1, 1}, {3.9, 2}, {4.1, 2}, {3.9, 2}, {5.9, 2}, {6.1, 1},
		{5.9, 1}, {6.1, 1}, {4.01, 1}, {3.99, 2}}
	for i, s in ipairs(seq) do
		check(mode(m, s[1], R, true, 0.09) == s[2] and m.dogshoot_switch == s[2],
			"M1." .. i .. " at " .. s[1] .. " m edge to edge the mode is " .. s[2])
	end
	-- Flip-flop count at either line: none per step of a jittering target.
	local flips, last = 0, mode(m, 3, R, true, 0.09)
	for i = 1, 100 do
		local d = (i % 2 == 0) and 3.95 or 4.05
		local v = mode(m, d, R, true, 0.09)
		if v ~= last then flips = flips + 1 end
		last = v
	end
	check(flips == 0, "M2 a target jittering across the melee line: no flip")
	m.dogshoot_switch = 1
	flips, last = 0, 1
	for i = 1, 100 do
		local v = mode(m, (i % 2 == 0) and 5.95 or 6.05, R, true, 0.09)
		if v ~= last then flips = flips + 1 end
		last = v
	end
	check(flips == 0, "M3 ... and across the ranged line: none")
	-- The blind approach.
	-- (steps of 0.25 s and 0.125 s: exact sums)
	m = shooter()
	check(mode(m, 8, R, true, 0.25) == 1, "M4 a target seen at 8 m is shot")
	local approach = 0
	for _ = 1, 3 do
		if mode(m, 8, R, false, 0.25) == 2 then approach = approach + 1 end
	end
	check(approach == 3 and m.dogshoot_switch == 1, "M5 without sight it approaches (melee branch);"
		.. " the saved mode stays")
	check(mode(m, 8, R, true, 0.125) == 2, "M6 sight back before the 1 s re-check: still approaching")
	check(mode(m, 8, R, true, 0.125) == 1 and m.temp.grug_ds_blind == nil,
		"M7 the re-check with sight outside the melee line: it shoots")
	m = shooter()
	for _ = 1, 4 do mode(m, 8, R, false, 0.25) end
	check(m.temp.grug_ds_blind == 0, "M8 a re-check without sight starts the next second")
	for _ = 1, 3 do mode(m, 3, R, false, 0.25) end
	check(mode(m, 3, R, true, 0.25) == 2 and m.dogshoot_switch == 2,
		"M9 a re-check with sight inside the melee line: it melees")
	m = shooter()
	for _ = 1, 3 do mode(m, 5, R, false, 0.25) end
	check(mode(m, 5, R, true, 0.25) == 1, "M10 sight back at 5 m (between the lines): it shoots")
	-- Unreachable in melee: shot at, melee waits for reach.
	m = shooter({dogshoot_switch = 2})
	m.temp.grug_nav = {fails = 0}
	check(mode(m, 3, R, true, 0.1) == 2, "M11 melee at 3 m while the way is fine")
	m.temp.grug_nav.fails = 1
	check(mode(m, 3, R, true, 0.1) == 1 and m.temp.grug_ds_unreached,
		"M12 a failed search toward a visible target out of reach: it shoots")
	m.temp.grug_nav.fails = 0
	check(mode(m, 3, R, true, 0.1) == 1, "M13 ... and keeps shooting at 3 m (melee waits for reach)")
	check(mode(m, 2, R, true, 0.1) == 2 and not m.temp.grug_ds_unreached,
		"M14 the target in reach: melee again")
	m.temp.grug_nav.fails = 1
	check(mode(m, 3, R, true, 0.1) == 1 and m.temp.grug_ds_unreached, "M15 unreachable again: it shoots")
	check(mode(m, 7, R, true, 0.1) == 1 and not m.temp.grug_ds_unreached,
		"M15b past the ranged line the wait ends")
	m.temp.grug_nav.fails = 0
	check(mode(m, 3.5, R, true, 0.1) == 2, "M16 back at 3.5 m (a fine way) it melees")
	m = shooter({dogshoot_switch = 2})
	m.temp.grug_nav = {fails = 2}
	check(mode(m, 2, R, true, 0.1) == 2, "M17 in reach a failed search changes nothing")
	-- No switch: upstream's ds_var 0, nothing written.
	local none = shooter()
	none.dogshoot_switch = nil
	check(mode(none, 2, R, true, 0.1) == 0 and none.dogshoot_switch == nil, "M18 no switch: ds_var 0")
	-- stop_attack clears the runtime state.
	local stop_src = cut(api, "function mob_class:stop_attack()", "\n-- execute current state", "stop_attack")
	check(stop_src:find("self.temp.grug_ds_blind, self.temp.grug_ds_unreached = nil, nil", 1, true) ~= nil,
		"M19 stop_attack clears the blind approach and the wait")
	check(api:find("ds_var = grug_dogshoot_mode(self, m_edge, m_reach, in_sight, dtime)", 1, true) ~= nil
		and api:find("ds_var = self:dogswitch(dtime)", 1, true) == nil,
		"M20 do_states takes the distance mode, the clock is no longer called")
end

-- ---------------------------------------------------------------------------
-- R. The branches (cut out of api.lua), driven by the mode.
-- ---------------------------------------------------------------------------
do
	local function fn(args, body)
		return assert(loadstring("local pathfinding_enable = true\nreturn function(" .. args ..
			") return " .. body .. " end"))()
	end
	local melee = fn("self, ds_var, dist, in_sight, grug_closing", cut(api,
		"self.attack_type == \"dogfight\" or (self.attack_type == \"dogshoot\"\n", " then\n",
		"melee branch"))
	local shoot = fn("self, ds_var", cut(api, "self.attack_type == \"shoot\"\n", " then\n", "shoot branch"))
	local can_nav = fn("self", cut(api, "local can_nav = ", "\n\t\t\tif can_nav then", "can_nav")
		:gsub("^local can_nav = ", ""))
	-- One step: the mode from the edge distance (dist - 0.6 on level ground
	-- for an ordinary body), then the branch.
	local function step(m, dist, in_sight, dt)
		local ds = mode(m, dist - 0.6, 2.4, in_sight, dt or 0.1)
		local closing = helpers.closing(m, ds, dist)
		if melee(m, ds, dist, in_sight, closing) then return "melee" end
		if shoot(m, ds) then return "shoot" end
	end
	local m = shooter({pathfinding = 1})
	check(step(m, 25, true) == "melee" and m.temp.grug_closing, "R1 beyond its shot range (20) with"
		.. " sight it closes in (the melee branch walks)")
	check(step(m, 18, true) == "melee", "R2 ... inside the range it walks on ...")
	check(step(m, 17, true) == "shoot" and m.velocity == 0, "R3 ... and shoots 3 m inside it")
	check(step(m, 9, true) == "shoot", "R4 a target coming in to 9 m is shot")
	check(step(m, 4.5, true) == "melee" and m.dogshoot_switch == 2, "R5 inside the melee line it melees")
	check(step(m, 6, true) == "melee", "R6 backing to 6 m (edge 5.4): it keeps melee and follows")
	check(step(m, 7, true) == "shoot", "R7 past the ranged line it shoots again")
	check(step(m, 7, false, 0.25) == "melee" and can_nav(m),
		"R8 hidden: the blind approach walks and may search")
	check(step(m, 7, false, 0.25) == "melee" and step(m, 7, true, 0.25) == "melee",
		"R9 sight back inside the second: still on its way")
	check(step(m, 7, true, 0.25) == "shoot", "R10 the re-check: outside the melee line it shoots")
	local wisp = shooter({fly = true, pathfinding = 1})
	check(step(wisp, 10, false) == "melee" and not can_nav(wisp),
		"R11 a flier without sight flies at its target, never searches")
	local king = shooter()
	king.dogshoot_switch = nil
	check(step(king, 2, true) == "melee" and step(king, 10, true) == nil,
		"R12 no switch: upstream's 'in reach forces melee', otherwise as before")
end

-- ---------------------------------------------------------------------------
-- F. The friendly ray (combat_ray.lua, aimed_target out of kits.lua).
-- ---------------------------------------------------------------------------
do
	local factions = {healer = "accord", tank = "accord", foe = "throng", fallen = "accord"}
	grug_core = {get_player_faction = function(name) return factions[name] end}
	dofile(repo .. "/mods/CORE/grug_core/combat_ray.lua")
	local function player(name, x, hp)
		local p = {name = name, pos = vector.new(x, 0, 0), hp = hp or 20}
		function p:get_pos() return self.pos end
		function p:is_player() return true end
		function p:get_player_name() return self.name end
		function p:get_hp() return self.hp end
		function p:get_luaentity() return nil end
		function p:get_observers() return nil end
		return p
	end
	local function mob(x)
		local o = {pos = vector.new(x, 0, 0), ent = {_cmi_is_mob = true, health = 50, name = "grug_mobs:flintback"}}
		function o:get_pos() return self.pos end
		function o:is_player() return false end
		function o:get_luaentity() return self.ent end
		function o:get_observers() return nil end
		return o
	end
	local healer, tank = player("healer", 0), player("tank", 6)
	local boss, foe, fallen = mob(4), player("foe", 3), player("fallen", 2, 0)
	-- The engine's ray: the listed things in order, each at its x.
	local line = {}
	function core.raycast()
		local i = 0
		return function()
			i = i + 1
			local t = line[i]
			if not t then return nil end
			if t.node then
				return {type = "node", under = vector.new(t.node, 1, 0),
					intersection_point = vector.new(t.node - 0.5, 1.5, 0)}
			end
			return {type = "object", ref = t, intersection_point = vector.new(t.pos.x - 0.3, 1.5, 0)}
		end
	end
	local nodes_def = core.registered_nodes
	nodes_def.stone.walkable = true
	function core.get_node_or_nil() return {name = "stone"} end
	local opts = {origin = vector.new(0, 1.5, 0), direction = vector.new(1, 0, 0)}
	local function ray(friendly)
		return grug_core.combat_ray(healer, 20, {origin = opts.origin, direction = opts.direction,
			friendly = friendly})
	end
	line = {healer, boss, tank}
	local r = ray(true)
	check(r.target == tank and r.reason == "friendly", "F1 the friendly ray passes the boss to the tank")
	r = ray(false)
	check(r.target == boss and r.status == "target", "F2 the hostile ray stops at the boss (unchanged)")
	line = {healer, fallen, foe, boss, tank}
	r = ray(true)
	check(r.target == tank, "F3 ... past a dead ally, a hostile player and the boss")
	line = {healer, boss, {node = 5}, tank}
	r = ray(true)
	check(r.target == nil and r.reason == "node", "F4 a wall still blocks")
	line = {healer, boss}
	r = ray(true)
	check(r.target == nil and r.reason == "empty", "F5 no ally on the ray: empty (the caster's fallback)")
	line = {healer, tank, boss}
	r = ray(true)
	check(r.target == tank, "F6 the tank in front of the boss: the tank")
	-- aimed_target passes the option for friendly skills only.
	grug_abilities = {get_range = function() return 20 end,
		valid_target = function(_, obj, kind)
			if kind == "friendly" then return obj:is_player() and obj:get_hp() > 0 end
			return not obj:is_player()
		end}
	local seen, calls = {}, 0
	local real_ray = grug_core.combat_ray
	grug_core.combat_ray = function(p, range, o)
		calls = calls + 1
		seen[calls] = o or false
		return real_ray(p, range, {origin = opts.origin, direction = opts.direction,
			friendly = o and o.friendly})
	end
	assert(loadstring(read("mods/PLAYER/grug_abilities/kits.lua"):match(
		"\n(local function valid_ally%(.-\nfunction grug_abilities%.aimed_target%(.-\nend)\n"),
		"=aimed_target"))()
	line = {healer, boss, tank}
	local heal = {id = "heal", target_kind = "friendly"}
	local smite = {id = "smite", target_kind = "hostile"}
	check(grug_abilities.aimed_target(healer, heal) == tank and seen[1] and seen[1].friendly == true,
		"F7 Heal aims at the tank behind the boss")
	check(grug_abilities.aimed_target(healer, smite) == boss and seen[2] == false,
		"F8 Smite aims at the boss, no option, no table")
	local eye = vector.new(0, 1.5, 0)
	grug_abilities.aimed_target(healer, smite, eye)
	check(seen[3] and seen[3].origin == eye and not seen[3].friendly, "F9 the crosshair's origin passes as before")
	grug_core.combat_ray = real_ray
	-- Every friendly-targeted skill (the three Priest supports).
	local priest = read("mods/PLAYER/grug_abilities/kits_priest.lua")
	local ids = {}
	for block in priest:gmatch("id = \"([%w_]+)\",[^}]-target_kind = \"friendly\"") do ids[#ids + 1] = block end
	report[#report + 1] = "friendly-targeted skills: " .. table.concat(ids, ", ")
end

-- ---------------------------------------------------------------------------
-- P. The per-step cost: the old decision (3D distance, upstream's clock, the
-- 60 % contact test) against the new (melee_measure, the distance mode, the
-- stop gap), on the same mob and target, without the step's shared work.
-- ---------------------------------------------------------------------------
do
	local dogswitch = load_in("local mob_class = {}\n" ..
		cut(api, "function mob_class:dogswitch(dtime)", "\n-- GRUG PATCH (Round 56 MOBAI", "dogswitch") ..
		"\nreturn mob_class.dogswitch", {}, "dogswitch")
	local m = new_mob(GOLEM_BOX, 3, 1.4, {attack_type = "dogshoot", dogshoot_switch = 1,
		dogshoot_count = 0, dogshoot_count_max = 10, dogshoot_count2_max = 3})
	local target = new_target({x = 3, y = 0.5, z = 0})
	m.attack = target
	local s = {x = 0, y = 1.9, z = 0}
	local N = 200000
	O.begin_server_step()
	local sink = 0
	local t0 = os.clock()
	for i = 1, N do
		local dx, dy, dz = target.pos.x - s.x, target.pos.y - s.y, target.pos.z - s.z
		local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
		local ds = dogswitch(m, 0.09)
		if dist > m.reach * 0.6 then sink = sink + ds end
	end
	local before = (os.clock() - t0) / N * 1e9
	t0 = os.clock()
	for i = 1, N do
		local dx, dy, dz = target.pos.x - s.x, target.pos.y - s.y, target.pos.z - s.z
		local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
		local edge, gap, reach, stop = O.melee_measure(m, s, target.pos, dist)
		local ds = mode(m, edge, reach, true, 0.09)
		if O.should_close_contact(gap, stop, true) then sink = sink + ds end
	end
	local after = (os.clock() - t0) / N * 1e9
	check(sink >= 0, "P0 ran")
	report[#report + 1] = string.format("per-step decision: before %.0f ns, after %.0f ns (LuaJIT, %d steps)",
		before, after, N)
end

for _, line in ipairs(report) do print("  " .. line) end
print("R78 BOSS PORTABLE PASS checks=" .. checks)
