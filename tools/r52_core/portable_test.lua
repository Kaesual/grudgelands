-- Round 52 lane CORE-B portable test (round52-class-plan.md §3 "CORE-B",
-- C3-C5, D1, D9; skill-inventory.md §3a). Loads the REAL grug_core/area.lua,
-- particles.lua, particle_effects.lua, hud_layout.lua, status_icons.lua,
-- status.lua and grug_classes/talent_windows.lua under a minimal `core` stub
-- with a fake node map and a stepping raycast, and checks:
--   A  the ground search: flat ground, a mob's centre, a step, stacked
--      floors, a cave floor and its ceiling, shallow and deep water, plants,
--      a flying mob, a wall face, unloaded map;
--   B  the anchor: an enemy's position, the terrain point through plants
--      and onto a water surface, a ray miss, the "No ground found." refusal;
--   C  the area query: radius, the +-3 band, the filter, line of sight
--      (stone blocks, grass and water do not), nearest-first order with a
--      deterministic tie and the cap;
--   D  the delayed impact: warning and falling particles live the delay and
--      the fall starts below the ceiling, the impact runs with the caster
--      fetched by name, the caster leaving cancels it, a dead caster lands
--      it, a malformed spec is refused, the particle counts per cast;
--   E  the group helper: self always, the cap, lowest HP share first, a
--      deterministic tie, range and line of sight;
--   F  an area heal as a status: the HoT keeps ticking on a recipient that
--      left the area (C5), through the real status.lua;
--   G  readiness windows by any id: open, consume once, expiry, the ICD on
--      the monotonic clock (kept through death, dropped once run out), the
--      status icon; the old talent_trigger_ready is gone (Round 53).
--
-- Usage (repo root): luajit tools/r52_core/portable_test.lua [REPO]
local ROOT = arg[1] or "."

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
		label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

--
-- Vectors.
--
vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x or 0, y = y or 0, z = z or 0}
end
function vector.copy(v) return vector.new(v) end
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(a, s) return vector.new(a.x * s, a.y * s, a.z * s) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.normalize(v)
	local l = vector.length(v)
	return l > 0 and vector.multiply(v, 1 / l) or vector.new(0, 0, 0)
end

--
-- The fake world: a node map, unloaded below y = -40.
--
local nodes = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function set(x, y, z, name) nodes[key(x, y, z)] = name end
local function fill(x1, y1, z1, x2, y2, z2, name)
	for x = x1, x2 do for y = y1, y2 do for z = z1, z2 do set(x, y, z, name) end end end
end
local function node_at(x, y, z)
	if y < -40 then return nil end
	return nodes[key(x, y, z)] or "air"
end

local REGISTERED = {
	air = {walkable = false, pointable = false},
	stone = {walkable = true},
	slab = {walkable = true},
	leaves = {walkable = true},
	grass = {walkable = false},
	water = {walkable = false, liquidtype = "source"},
}

-- A stepping raycast over the node map: every node the segment enters, in
-- order (the start node excluded, as the engine's ray begins outside it),
-- `above` the node it came from. Air is never pointed; liquids only when
-- asked. Objects are not modelled (the area code casts node-only rays).
local function raycast(from, to, objects, liquids)
	local hits = {}
	local d = vector.subtract(to, from)
	local length = vector.length(d)
	local steps = math.max(1, math.ceil(length / 0.01))
	local function cell(p)
		return math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5)
	end
	local px, py, pz = cell(from)
	for i = 1, steps do
		local p = vector.add(from, vector.multiply(d, i / steps))
		local x, y, z = cell(p)
		if x ~= px or y ~= py or z ~= pz then
			local name = node_at(x, y, z)
			local def = name and REGISTERED[name]
			local pointable = def and def.pointable ~= false and
				(liquids or not def.liquidtype)
			if pointable then
				hits[#hits + 1] = {type = "node", under = {x = x, y = y, z = z},
					above = {x = px, y = py, z = pz}, intersection_point = p}
			end
			px, py, pz = x, y, z
		end
	end
	local index = 0
	return function()
		index = index + 1
		return hits[index]
	end
end

--
-- Objects.
--
local objects = {}
local function fake_object(def)
	local o = {pos = vector.copy(def.pos), name = def.name, player = def.player,
		hp = def.hp or 20, hp_max = def.hp_max or 20, box = def.box}
	function o:is_player() return self.player == true end
	function o:get_pos() return self.pos and vector.copy(self.pos) end
	function o:get_player_name() return self.player and self.name or "" end
	function o:get_hp() return self.hp end
	function o:get_properties() return {hp_max = self.hp_max} end
	function o:hud_add() return 1 end
	function o:hud_change() end
	function o:get_luaentity()
		if self.player then return nil end
		return {name = self.name, _grug_cbox = self.box}
	end
	objects[#objects + 1] = o
	return o
end
local function in_box(p, a, b)
	return p.x >= a.x and p.x <= b.x and p.y >= a.y and p.y <= b.y and
		p.z >= a.z and p.z <= b.z
end

--
-- Engine surface.
--
local us_time = 1000000000
local after_jobs, leaves, joins, deaths, steps = {}, {}, {}, {}, {}
local particle_calls = {}
local players_by_name = {}
local connected = {}
core = {
	get_us_time = function() return us_time end,
	get_node_or_nil = function(pos)
		local name = node_at(pos.x, pos.y, pos.z)
		return name and {name = name} or nil
	end,
	registered_nodes = REGISTERED,
	raycast = raycast,
	get_objects_in_area = function(minp, maxp)
		local out = {}
		for _, o in ipairs(objects) do
			if o.pos and in_box(o.pos, minp, maxp) then out[#out + 1] = o end
		end
		return out
	end,
	get_objects_inside_radius = function(centre, radius)
		local out = {}
		for _, o in ipairs(objects) do
			if o.pos and vector.distance(o.pos, centre) <= radius then out[#out + 1] = o end
		end
		return out
	end,
	after = function(delay, fn)
		local job = {delay = delay, fn = fn}
		function job.cancel() job.cancelled = true end
		after_jobs[#after_jobs + 1] = job
		return job
	end,
	get_player_by_name = function(name) return players_by_name[name] end,
	get_connected_players = function() return connected end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_dieplayer = function(fn) deaths[#deaths + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	settings = {get = function() return nil end},
	add_particle = function(def)
		particle_calls[#particle_calls + 1] = {kind = "single", def = def}
	end,
	add_particlespawner = function(def)
		particle_calls[#particle_calls + 1] = {kind = "spawner", def = def}
	end,
	log = function() end,
}
local function run_jobs()
	local jobs = after_jobs
	after_jobs = {}
	for _, job in ipairs(jobs) do
		if not job.cancelled then job.fn() end
	end
end

grug_core = {}
function grug_core.mono_time() return core.get_us_time() / 1e6 end
local ray_result
function grug_core.combat_ray() return ray_result end

local globals_before = {}
for name in pairs(_G) do globals_before[name] = true end
dofile(ROOT .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(ROOT .. "/mods/CORE/grug_core/status_icons.lua")
dofile(ROOT .. "/mods/CORE/grug_core/status.lua")
dofile(ROOT .. "/mods/CORE/grug_core/particles.lua")
dofile(ROOT .. "/mods/CORE/grug_core/particle_effects.lua")
dofile(ROOT .. "/mods/CORE/grug_core/area.lua")
grug_classes = {registered_talents = {}}
dofile(ROOT .. "/mods/PLAYER/grug_classes/talent_windows.lua")
for name in pairs(_G) do
	check(globals_before[name] or name == "grug_classes",
		"no file adds the global " .. tostring(name))
end
local area = grug_core.area
local P = grug_core.particles

--
-- The scene (x, z in 0..40, ground y = 0 unless built otherwise).
--
fill(0, -3, 0, 40, 0, 40, "stone")
-- A one-node step and a slab at x 10..11.
set(10, 1, 5, "stone")
set(11, 1, 5, "slab")
-- Stacked floors at x 20: a floor at y = 4 with an open floor below.
fill(19, 4, 4, 21, 4, 6, "stone")
-- A cave: rock from y = 1 to 9 at x 30..34, hollow y = 1..2 (ceiling at 3).
fill(30, 1, 10, 34, 9, 14, "stone")
fill(31, 1, 11, 33, 2, 13, "air")
-- A tall cave hall: ceiling at y = 9 over x 30..34, z 20..24, floor y = 0.
fill(30, 1, 20, 34, 9, 24, "stone")
fill(31, 1, 21, 33, 8, 23, "air")
-- Shallow water (2 deep) and deep water (5 deep) pits.
fill(5, -1, 30, 7, 0, 32, "water")
fill(12, -4, 30, 14, 0, 32, "water")
fill(12, -5, 30, 14, -5, 32, "stone")
for x = 12, 14 do for z = 30, 32 do set(x, -3, z, "water") end end
-- Grass on the ground at x 2, z 2.
set(2, 1, 2, "grass")
-- A wall at x = 25 (y 1..6), z 0..10.
fill(25, 1, 0, 25, 6, 10, "stone")

--
-- A. The ground search.
--
local function anchor_text(a)
	return a and ("%.2f,%.2f,%.2f"):format(a.x, a.y, a.z) or "none"
end
eq(anchor_text(area.ground_below(vector.new(5.3, 0.5, 5.7))), "5.30,0.50,5.70",
	"A flat ground under a player's feet")
eq(anchor_text(area.ground_below(vector.new(5, 1.5, 5))), "5.00,0.50,5.00",
	"A a mob's centre one node up")
eq(anchor_text(area.ground_below(vector.new(5, 3.5, 5))), "5.00,0.50,5.00",
	"A a point 3 m above the ground still finds it")
eq(anchor_text(area.ground_below(vector.new(5, 3.6, 5))), "none",
	"A a flying mob higher than H finds none")
eq(anchor_text(area.ground_below(vector.new(10, 2.5, 5))), "10.00,1.50,5.00",
	"A a step's top")
eq(anchor_text(area.ground_below(vector.new(11, 2.5, 5))), "11.00,1.50,5.00",
	"A a slab counts as ground (partial node)")
eq(anchor_text(area.ground_below(vector.new(20, 5.5, 5))), "20.00,4.50,5.00",
	"A stacked floors: the upper floor from above")
eq(anchor_text(area.ground_below(vector.new(20, 2, 5))), "20.00,0.50,5.00",
	"A stacked floors: the lower floor from below the upper one")
eq(anchor_text(area.ground_below(vector.new(32, 1.5, 12))), "32.00,0.50,12.00",
	"A a cave floor")
eq(anchor_text(area.ground_below(vector.new(32, 7.5, 22), {x = 32, y = 7, z = 22})),
	"none", "A a tall cave's ceiling hit finds no ground")
eq(anchor_text(area.ground_below(vector.new(6, 0.5, 31), {x = 6, y = 1, z = 31})),
	"6.00,-1.50,31.00", "A shallow water: the ground below the surface")
eq(anchor_text(area.ground_below(vector.new(13, 0.5, 31), {x = 13, y = 1, z = 31})),
	"none", "A deep water: no ground within H")
eq(anchor_text(area.ground_below(vector.new(2, 1.5, 2))), "2.00,0.50,2.00",
	"A grass does not stop the search")
eq(anchor_text(area.ground_below(vector.new(24.5, 2.2, 3), {x = 24, y = 2, z = 3})),
	"24.45,0.50,3.00", "A a wall face: the ground at its foot, inside the column")
eq(anchor_text(area.ground_below(vector.new(5, -40, 5))), "none",
	"A an unloaded map finds none")

--
-- B. The anchor.
--
local caster = fake_object({name = "caster", player = true, pos = vector.new(0, 0.5, 0),
	hp = 20})
players_by_name.caster = caster
local mob_on_ground = fake_object({name = "mob", pos = vector.new(8, 1.5, 8),
	box = {-0.4, -1, -0.4, 0.4, 1, 0.4}})
local flyer = fake_object({name = "flyer", pos = vector.new(9, 6, 9),
	box = {-0.4, -0.5, -0.4, 0.4, 0.5, 0.4}})
local function aim_at(origin, destination, target)
	ray_result = {status = target and "target" or "aim_miss", target = target,
		origin = origin, destination = destination}
end
aim_at(vector.new(0, 2, 0), vector.new(8, 1.5, 8), mob_on_ground)
local anchor, target = area.anchor(caster, 20)
eq(anchor_text(anchor), "8.00,0.50,8.00", "B an enemy gives its position")
check(target == mob_on_ground, "B the enemy is returned")
aim_at(vector.new(0, 2, 0), vector.new(9, 6, 9), flyer)
local none, reason = area.anchor(caster, 20)
eq(none, nil, "B a flying mob without ground gives no anchor")
eq(reason, "No ground found.", "B the refusal text")
-- An enemy the caller's rule refuses falls back to the terrain behind it.
aim_at(vector.new(7, 3, 7), vector.new(7, -1, 7), mob_on_ground)
anchor = area.anchor(caster, 20, {is_enemy = function() return false end})
eq(anchor_text(anchor), "7.00,0.50,7.00", "B a refused enemy: the terrain point")
-- The terrain ray passes grass and stops on a water surface.
aim_at(vector.new(2, 3, 2), vector.new(2, -1, 2), nil)
eq(anchor_text(area.anchor(caster, 20)), "2.00,0.50,2.00",
	"B the terrain point through grass")
aim_at(vector.new(6, 4, 31), vector.new(6, -2, 31), nil)
eq(anchor_text(area.anchor(caster, 20)), "6.00,-1.50,31.00",
	"B shallow water: the ground below the surface")
aim_at(vector.new(13, 4, 31), vector.new(13, -6, 31), nil)
eq(select(2, area.anchor(caster, 20)), "No ground found.", "B deep water is refused")
aim_at(vector.new(5, 3, 5), vector.new(5, 15, 5), nil)
eq(select(2, area.anchor(caster, 20)), "No ground found.", "B a ray miss is refused")
aim_at(vector.new(32, 2, 22), vector.new(32, 12, 22), nil)
eq(select(2, area.anchor(caster, 20)), "No ground found.",
	"B a tall cave's ceiling is refused")

--
-- C. The area query.
--
objects = {caster}
local function mob(name, x, y, z)
	return fake_object({name = name, pos = vector.new(x, y, z),
		box = {-0.4, 0, -0.4, 0.4, 1.6, 0.4}})
end
local centre = vector.new(5, 0.5, 15)
local m_near = mob("a", 6, 0.5, 15)
local m_band_top = mob("b", 5, 3.5, 13)        -- +3: inside the band (flying)
local m_band_out = mob("c", 5, 3.6, 13)        -- above the band
local m_radius_out = mob("d", 7.2, 0.5, 17.2)  -- in the box, outside the circle
local m_tie_1 = mob("e", 7, 0.5, 15)
local m_tie_2 = mob("f", 3, 0.5, 15)           -- same distance, smaller x
local m_friend = fake_object({name = "friend", player = true, pos = vector.new(5, 0.5, 16)})
local filter = function(obj) return not obj:is_player() end
local function names(list)
	local out = {}
	for i, o in ipairs(list) do out[i] = o.name end
	return table.concat(out, ",")
end
eq(names(area.query(centre, {radius = 3, filter = filter})), "a,f,e,b",
	"C radius, band and filter; nearest first, tie by x")
eq(names(area.query(centre, {radius = 3, filter = filter, cap = 2})), "a,f", "C the cap")
eq(names(area.query(centre, {radius = 3})), "friend,a,f,e,b",
	"C no filter: every object (a tie at 1 m: smaller x first)")
-- Line of sight: a stone pillar between the anchor and "e" blocks it ...
set(6, 1, 15, "stone")
set(6, 2, 15, "stone")
m_near.pos = vector.new(5, 0.5, 14)
eq(names(area.query(centre, {radius = 3, filter = filter})), "a,f,b",
	"C stone blocks the line of sight")
eq(names(area.query(centre, {radius = 3, filter = filter, cap = 2})), "a,f",
	"C the cap counts targets in sight")
-- ... grass and water do not.
set(6, 1, 15, "grass")
set(6, 2, 15, "water")
eq(names(area.query(centre, {radius = 3, filter = filter})), "a,f,e,b",
	"C grass and water do not block")
set(6, 1, 15, nil)
set(6, 2, 15, nil)
eq(names(area.query(centre, {radius = 3, band = 1, filter = filter})), "a,f,e",
	"C a narrower band")
check(m_band_out and m_radius_out, "C scene objects exist")
-- Determinism: the same scene in another object order gives the same list.
local reversed = {}
for i = #objects, 1, -1 do reversed[#reversed + 1] = objects[i] end
objects = reversed
eq(names(area.query(centre, {radius = 3, filter = filter})), "a,f,e,b",
	"C the order does not depend on the engine's object order")

--
-- D. The delayed impact.
--
objects = {caster}
local impacts = {}
local function count_particles(calls)
	local n = 0
	for _, c in ipairs(calls) do
		n = n + (c.kind == "single" and 1 or c.def.amount)
	end
	return n
end
particle_calls = {}
local ok = area.delayed(caster, {anchor = vector.new(32, 0.5, 12), delay = 1.5, radius = 3,
	color = "#ff7a2a", impact = function(player, at)
		impacts[#impacts + 1] = {player = player, at = at}
	end})
check(ok == true, "D a delayed area is scheduled")
eq(area.pending_count("caster"), 1, "D one impact pending")
local warning_n, fall = 0, {}
for _, c in ipairs(particle_calls) do
	if c.kind == "single" and c.def.size == 3 then
		warning_n = warning_n + 1
		near(c.def.expirationtime, 1.5, "D a warning mote lives the delay")
	elseif c.kind == "single" and c.def.size >= 8 then
		fall[#fall + 1] = c.def
	end
end
eq(warning_n, 20, "D twenty warning motes")
eq(#fall, 6, "D six falling motes")
-- In the cave (ceiling at y = 3): the fall starts half a node below it.
near(area.fall_height(vector.new(32, 0.5, 12)), 1.5,
	"D the cave's fall height (ceiling face at 2.5, half a node below it)")
for _, def in ipairs(fall) do
	check(def.pos.y <= 2.5 + 1e-9, "D a falling mote starts below the ceiling")
	near(def.expirationtime, 1.5, "D a falling mote lives the delay")
	near(def.pos.y + def.velocity.y * def.expirationtime, 0.5,
		"D a falling mote reaches the ground at the impact")
end
near(area.fall_height(vector.new(5, 0.5, 5)), 12, "D open sky: the cap")
local cast_particles = count_particles(particle_calls)
particle_calls = {}
run_jobs()
eq(#impacts, 1, "D the impact ran")
check(impacts[1].player == caster, "D with the caster fetched by name")
eq(anchor_text(impacts[1].at), "32.00,0.50,12.00", "D at the anchor")
local impact_particles = count_particles(particle_calls)
eq(area.pending_count("caster"), 0, "D nothing pending after the impact")
print(("particles per cast: warning+fall %d, impact %d"):format(cast_particles,
	impact_particles))
check(cast_particles + impact_particles <= 128, "D one cast stays within ~a hundred particles")
-- The caster leaves: the impact is cancelled.
impacts = {}
area.delayed(caster, {anchor = vector.new(5, 0.5, 5), delay = 1, radius = 3,
	impact = function() impacts[#impacts + 1] = true end})
area.delayed(caster, {anchor = vector.new(6, 0.5, 5), delay = 1, radius = 3,
	impact = function() impacts[#impacts + 1] = true end})
eq(area.pending_count("caster"), 2, "D two impacts pending")
for _, fn in ipairs(leaves) do fn(caster) end
eq(area.pending_count("caster"), 0, "D the leave drops them")
run_jobs()
eq(#impacts, 0, "D a caster who left lands nothing")
-- The caster gone without the leave callback (a rejoin is a new session,
-- but a missing player is never invented).
players_by_name.caster = nil
area.delayed(caster, {anchor = vector.new(5, 0.5, 5), delay = 1, radius = 3,
	impact = function() impacts[#impacts + 1] = true end})
run_jobs()
eq(#impacts, 0, "D a caster no longer online lands nothing")
players_by_name.caster = caster
-- A dead caster still lands it.
caster.hp = 0
area.delayed(caster, {anchor = vector.new(5, 0.5, 5), delay = 1, radius = 3,
	impact = function(player) impacts[#impacts + 1] = player:get_hp() end})
run_jobs()
eq(impacts[1], 0, "D a dead caster still lands the impact")
caster.hp = 20
-- Malformed specs are refused.
check(not area.delayed(caster, {anchor = vector.new(5, 0.5, 5), delay = 3.5,
	impact = function() end}), "D a delay above MAX_DELAY is refused")
check(not area.delayed(caster, {anchor = vector.new(5, 0.5, 5), delay = 1}),
	"D an impact function is required")
eq(#after_jobs, 0, "D a refused spec schedules nothing")

-- The three effects keep the budget rules at their extremes.
for _, frame in ipairs({{reach = 1, time = 0.1, height = 1.5},
		{reach = 8, time = 3, height = 12}}) do
	for _, id in ipairs({"area_warning", "area_fall", "area_impact"}) do
		local effect = P.registered(id)
		check(effect ~= nil, "D " .. id .. " is in the catalogue")
		eq(P.check(effect(frame)), nil, "D " .. id .. " keeps the budget rules (time " ..
			frame.time .. ")")
	end
end

--
-- E. The group helper.
--
local function player(name, x, hp, hp_max)
	local p = fake_object({name = name, player = true, pos = vector.new(x, 0.5, 25),
		hp = hp, hp_max = hp_max or 20})
	players_by_name[name] = p
	return p
end
objects = {}
local healer = player("healer", 5, 20)
local p_low = player("low", 7, 5)            -- 25 %
local p_mid = player("mid", 3, 10)           -- 50 %
local p_tie_far = player("tie_far", 9, 10)   -- 50 %, farther
local p_full = player("full", 6, 20)         -- 100 %
local p_out = player("out", 15, 1)           -- out of range
local p_enemy = player("enemy", 4, 1)        -- not eligible
local eligible = function(obj) return obj.name ~= "enemy" end
eq(names(area.group(healer, {radius = 6, cap = 10, eligible = eligible})),
	"low,mid,tie_far,healer,full", "E lowest share first, a tie by distance, self included")
eq(names(area.group(healer, {radius = 6, cap = 3, eligible = eligible})),
	"low,mid,healer", "E the cap counts the caster, who always stays")
healer.hp = 2
eq(names(area.group(healer, {radius = 6, cap = 3, eligible = eligible})),
	"healer,low,mid", "E the caster takes its turn in the order")
healer.hp = 20
eq(names(area.group(healer, {radius = 6, cap = 1, eligible = eligible})), "healer",
	"E a cap of one is the caster alone")
-- A wall between the healer and "low".
fill(6, 1, 25, 6, 2, 25, "stone")
eq(names(area.group(healer, {radius = 6, cap = 10, eligible = eligible})),
	"mid,healer", "E a wall hides everyone behind it")
fill(6, 1, 25, 6, 2, 25, "grass")
eq(names(area.group(healer, {radius = 6, cap = 10, eligible = eligible})),
	"low,mid,tie_far,healer,full", "E grass hides no one")
check(p_out and p_enemy and p_full, "E scene objects exist")

--
-- F. An area heal as a status (C5): the HoT keeps ticking outside the area.
--
connected = {healer, p_low, p_mid}
for _, p in ipairs(connected) do for _, fn in ipairs(joins) do fn(p) end end
local ticks = {}
p_low.hp, p_mid.hp = 5, 10
for _, p in ipairs(area.group(healer, {radius = 6, cap = 3, eligible = eligible})) do
	grug_core.set_status(p, "mend", {label = "Test heal", duration = 12, interval = 3,
		on_tick = function(target)
			ticks[target.name] = (ticks[target.name] or 0) + 1
			target.hp = math.min(target.hp_max, target.hp + 1)
		end})
end
p_low.pos = vector.new(40, 0.5, 40) -- leaves the area at once
local function step(seconds)
	for _ = 1, seconds / 0.5 do
		us_time = us_time + 0.5 * 1e6
		for _, fn in ipairs(steps) do fn(0.5) end
	end
end
step(13)
eq(ticks.low, 4, "F the recipient who left the area got all four ticks")
eq(ticks.mid, 4, "F a recipient who stayed got four")
eq(ticks.healer, 4, "F the caster is a recipient")
eq(p_low.hp, 9, "F the ticks healed")
eq(grug_core.get_status(p_low, "mend"), nil, "F the status ends with its duration")

--
-- G. Readiness windows by any id.
--
grug_core.status_icons.STATUS.test_window = {kind = "buff", name = "Test",
	icon = "x.png"}
grug_core.status_icons.WINDOWS.test_window = "test_window"
local w = healer
eq(grug_classes.open_window(w, "test_window", {duration = 4, icd = 6, value = 0.25,
	label = "Cold Shock"}), true, "G a window opens")
check(grug_core.get_status(w, "test_window") ~= nil, "G its status icon shows")
eq(grug_core.get_status(w, "test_window").label, "Cold Shock", "G with the label")
eq(grug_classes.get_window(w, "test_window").value, 0.25, "G it carries its value")
eq(grug_classes.open_window(w, "test_window", {duration = 4, icd = 6}), false,
	"G the ICD refuses a reopen")
local spent = grug_classes.consume_window(w, "test_window")
eq(spent and spent.value, 0.25, "G the qualifying attack consumes it")
eq(grug_classes.consume_window(w, "test_window"), nil, "G only once (one charge)")
eq(grug_core.get_status(w, "test_window"), nil, "G consuming clears the icon")
-- Expiry.
us_time = us_time + 6 * 1e6
eq(grug_classes.window_icd_ready(w, "test_window"), true, "G the ICD ran out")
grug_classes.open_window(w, "test_window", {duration = 2})
us_time = us_time + 2.5 * 1e6
eq(grug_classes.get_window(w, "test_window"), nil, "G a window expires")
eq(grug_classes.consume_window(w, "test_window"), nil, "G an expired window spends nothing")
-- Any id, no icon, no ICD.
eq(grug_classes.open_window(w, "opening", {duration = 3}), true, "G any id opens")
eq(grug_classes.open_window(w, "opening", {duration = 3}), true, "G no ICD: reopen renews")
eq(grug_classes.open_window(w, "", {duration = 3}), false, "G an empty id is refused")
eq(grug_classes.open_window(w, "x", {duration = 0}), false, "G a zero duration is refused")
-- Death, respec, leave (clear_talent_windows): windows go, a running ICD stays.
grug_core.clear_move_immunity = function() end
grug_core.clear_absorb_modifiers = function() end
grug_classes.open_window(w, "test_window", {duration = 4, icd = 10})
grug_classes.clear_talent_windows(w)
eq(grug_classes.get_window(w, "test_window"), nil, "G clear ends the window")
eq(grug_core.get_status(w, "test_window"), nil, "G and its icon")
eq(grug_classes.get_window(w, "opening"), nil, "G every window of the player")
eq(grug_classes.window_icd_ready(w, "test_window"), false, "G a running ICD survives death")
us_time = us_time + 10 * 1e6
eq(grug_classes.window_icd_ready(w, "test_window"), true,
	"G the ICD runs out on the monotonic clock")
grug_classes.clear_talent_windows(w)
eq(grug_classes.open_window(w, "test_window", {duration = 1}), true,
	"G a run-out ICD is pruned and the window opens")
-- D1's old talent trigger clock (os.time in player meta) went with the old
-- talents (Round 53 INTEG part 2).
eq(grug_classes.talent_trigger_ready, nil, "G the old talent trigger clock is gone")

print(("r52_core portable test: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error(failures .. " failure(s)") end
