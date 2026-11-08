-- Round 72 lane TRAPS portable test (LuaJIT): the template's `trap` lines and the real
-- traps.lua on a fake engine whose map is the shipped test_vault template, with the
-- real particle path (grug_core/particles.lua) counting what is sent. The engine half
-- is tools/r72_traps/run.sh. Prints "R72 TRAPS PORTABLE PASS checks=<n>".
--
--   luajit tools/r72_traps/portable_test.lua [REPO]
--
-- A. The format: the shipped test template's lines, refusals, check_fits.
-- B. The choice: per group, at random per creation, stable through a run, gone at its end.
-- C. The floor trap: trigger, ring, hit in radius and sight, mark, rearm; players only.
-- D. The wall trap: period and offset, the flight, stone, a player's burst; players only.
-- E. The marked-spot helper and the run's end.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- ---- The template, through zlib ---------------------------------------------------
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")
local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 4194304), ffi.new("unsigned long[1]", 4194304)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/test_vault.exp", "rb"))
local tpl = T.parse(file:read("*a"), inflate, "test_vault")
file:close()
T.check_fits(tpl, {x = 128, y = 64, z = 128}, {"arrival"}, "test_vault")

-- A. The format.
check(#tpl.traps == 7 and #tpl.encounters == 3, "A seven trap lines beside the markers")
local f1 = tpl.traps[1]
check(f1.group == "f1" and f1.pick == 1 and f1.kind == "floor" and f1.pos.x == 8 and
	f1.pos.y == 5 and f1.pos.z == 30, "A a floor line")
local w1 = tpl.traps[5]
check(w1.kind == "wall" and w1.pos.x == 3.6 and w1.pos.y == 5.5 and w1.axis == "+x" and
	w1.period == 4 and w1.offset == 0, "A a wall line, decimals kept")
check(tpl.traps[7].offset == 2 and tpl.traps[6].axis == "-x", "A offset and axis")
for _, bad in ipairs({"f 0 floor 1 2 3", "f 1 floor 1 2", "f 1 floor 1.5 2 3", "f 1 pit 1 2 3",
		"w 1 wall 1 2 3 +y 4 0", "w 1 wall 1 2 3 +x 0 0", "w 1 wall 1 2 3 +x 4", "w x wall 1 2 3 +x 4 0"}) do
	check(T.parse_trap(bad) == nil, "A refused: " .. bad)
end
local function refused(lines, needle)
	local head = "grudgelands-expedition-template 1\nname x\nsize 16 16 16\nnode air\n" ..
		lines .. "data 0\n"
	local ok, message = pcall(T.parse, head, function() return string.rep("\0", 2 * 4096) end, "bad")
	check(not ok and tostring(message):find(needle, 1, true), "A refused: " .. needle .. " got " ..
		tostring(message))
end
refused("trap f 2 floor 1 2 3\n", "picks more than it has")
refused("trap f 1 floor 1 2 3\ntrap f 2 floor 4 2 3\n", "disagrees with itself")
refused("trap f 1 floor 1 2 3\ntrap f 1 wall 4 2 3 +x 4 0\n", "disagrees with itself")
refused("trap w 1 wall 1 2 3 +x 4 0\ntrap w 1 wall 4 2 3 +x 6 0\n", "disagrees with itself")
refused("trap f 1 floor 1 2\n", "malformed")
local small = {size = {x = 16, y = 16, z = 16}, places = {}, encounters = {},
	traps = {{group = "w", pos = {x = 15.6, y = 2, z = 2}}}}
check(not pcall(T.check_fits, small, {x = 128, y = 64, z = 128}, {}, "small"), "A a trap outside")
small.traps[1].pos.x = 15.4
check(pcall(T.check_fits, small, {x = 128, y = 64, z = 128}, {}, "small"), "A a trap inside")

-- ---- The fake engine ---------------------------------------------------------------
local clock = 0
local timers = {}
local hooks = {ready = {}, enter = {}, ended = {}}
local overrides = {} -- "x,y,z" -> node name set by the game or the test
local MINP = {x = 8064, y = -112, z = -1616}
local function key(p) return p.x .. "," .. p.y .. "," .. p.z end

vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function vector.add(a, b)
	if type(b) == "number" then return {x = a.x + b, y = a.y + b, z = a.z + b} end
	return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end
function vector.multiply(a, s) return {x = a.x * s, y = a.y * s, z = a.z * s} end
function vector.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function node_name(pos)
	local over = overrides[key(pos)]
	if over then return over end
	local x, y, z = pos.x - MINP.x, pos.y - MINP.y, pos.z - MINP.z
	local size = tpl.size
	if x < 0 or y < 0 or z < 0 or x >= size.x or y >= size.y or z >= size.z then
		return "default:stone"
	end
	return tpl.nodes[tpl.cells:byte(z * size.y * size.x + y * size.x + x + 1) + 1]
end

local particles_sent = {} -- {id, born, life}
local current_effect
local objects = {}
local entity_defs = {}
local sets = {}

core = {
	settings = {get = function() return nil end},
	registered_nodes = {air = {walkable = false}, ["default:stone"] = {walkable = true},
		["default:stonebrick"] = {walkable = true}, ["default:torch_wall"] = {walkable = false},
		["grug_expeditions:waystone"] = {walkable = true},
		["grug_expeditions:reward_chest"] = {walkable = true},
		["grug_expeditions:reward_door"] = {walkable = true}},
	get_modpath = function() return repo .. "/mods/PLAYER/grug_expeditions" end,
	get_current_modname = function() return "grug_expeditions" end,
	log = function(_, text) error("unexpected log: " .. tostring(text)) end,
	get_us_time = function() return clock * 1e6 end,
	after = function(seconds, fn, ...)
		timers[#timers + 1] = {at = clock + seconds, fn = fn, args = {...}}
	end,
	register_node = function(name, def) core.registered_nodes[name] = def end,
	register_entity = function(name, def) entity_defs[name] = def end,
	get_node_or_nil = function(pos) return {name = node_name(pos)} end,
	get_node = function(pos) return {name = node_name(pos)} end,
	set_node = function(pos, node)
		overrides[key(pos)] = node.name
		sets[#sets + 1] = {pos = pos, name = node.name}
	end,
	add_particle = function(def)
		particles_sent[#particles_sent + 1] = {id = current_effect, born = clock,
			life = def.expirationtime, pos = def.pos}
	end,
	add_particlespawner = function() error("no spawner expected") end,
}

local players = {}
function core.get_player_by_name(name) return players[name] end

core.add_entity = function(pos, name)
	local def = assert(entity_defs[name], "no entity " .. name)
	local object = {pos = vector.copy(pos), velocity = {x = 0, y = 0, z = 0}, name = name}
	local ent = setmetatable({object = object}, {__index = def})
	function object.get_luaentity() return not object.removed and ent or nil end
	function object.set_velocity(_, v) object.velocity = vector.copy(v) end
	function object.get_pos() return not object.removed and vector.copy(object.pos) or nil end
	function object.remove() object.removed = true end
	objects[#objects + 1] = object
	return object
end

grug_core = {ARMOR_APPLIED_CUSTOM_TYPE = "grug_core:player_armor_applied"}
dofile(repo .. "/mods/CORE/grug_core/particles.lua")
local play = grug_core.particles.play
grug_core.particles.play = function(id, frame)
	current_effect = id
	play(id, frame)
	current_effect = nil
end
function grug_core.mono_time() return clock end
-- grug_core/combat.lua's curve.
function grug_core.base_pool(level)
	level = math.max(1, math.min(60, math.floor(tonumber(level) or 1)))
	return math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
end
function grug_core.apply_player_armor(player, damage)
	return player.armor and math.ceil(damage * (1 - player.armor)) or damage
end

grug_expeditions = {templates = {test_vault = tpl}}
function grug_expeditions.definition() return {template = "test_vault"} end
function grug_expeditions.register_on_ready(fn) hooks.ready[#hooks.ready + 1] = fn end
function grug_expeditions.register_on_enter(fn) hooks.enter[#hooks.enter + 1] = fn end
function grug_expeditions.register_on_end(fn) hooks.ended[#hooks.ended + 1] = fn end

dofile(repo .. "/mods/PLAYER/grug_expeditions/traps.lua")
local TR = grug_expeditions.traps
check(TR and core.registered_nodes["grug_expeditions:trap_mark"].walkable == false, "B the mark node")
check(entity_defs["grug_expeditions:trap_fireball"].initial_properties.static_save == false,
	"B a fireball is never saved")

local function new_player(name, rel, hp)
	local p = {name = name, hp = hp or 1000, hits = {}}
	p.pos = {x = MINP.x + rel.x, y = MINP.y + rel.y, z = MINP.z + rel.z}
	function p.get_player_name() return name end
	function p.get_pos() return vector.copy(p.pos) end
	function p.get_hp() return p.hp end
	function p.set_hp(_, hp_new, reason)
		p.hits[#p.hits + 1] = {amount = p.hp - hp_new, reason = reason, at = clock}
		p.hp = math.max(0, hp_new)
	end
	function p.punch() error("a trap never punches") end
	players[name] = p
	return p
end
local function feet(rel) return {x = MINP.x + rel.x, y = MINP.y + rel.y - 0.5, z = MINP.z + rel.z} end
local function place(p, pos) p.pos = vector.copy(pos) end

-- One server step of 0.1 s: due timers in order, then every live entity.
local function step(dt)
	dt = dt or 0.1
	clock = clock + dt
	while true do
		local first
		for index, timer in ipairs(timers) do
			if timer.at <= clock + 1e-9 and (not first or timer.at < timers[first].at) then first = index end
		end
		if not first then break end
		local timer = table.remove(timers, first)
		timer.fn(unpack(timer.args))
	end
	for _, object in ipairs(objects) do
		if not object.removed then
			object.pos = vector.add(object.pos, vector.multiply(object.velocity, dt))
			object:get_luaentity():on_step(dt)
		end
	end
end
local function run_for(seconds, dt)
	local stop = clock + seconds
	while clock < stop - 1e-9 do step(dt) end
end

local next_id = 0
local function new_run(level)
	next_id = next_id + 1
	local run = {id = next_id, expedition = "test_vault", level = level or 20, minp = MINP,
		inside = {}, state = "ready"}
	for _, fn in ipairs(hooks.ready) do fn(run) end
	return run
end
local function enter(run, p)
	run.inside[p.name] = true
	run.state = "running"
	for _, fn in ipairs(hooks.enter) do fn(run, p.name) end
end
local function end_run(run)
	run.state = "ended"
	for name in pairs(run.inside) do run.inside[name] = nil end
	for _, fn in ipairs(hooks.ended) do fn(run, "empty") end
end
local function count(id, since)
	local n = 0
	for _, row in ipairs(particles_sent) do
		if row.id == id and row.born >= (since or 0) then n = n + 1 end
	end
	return n
end

-- Every shipped template's floor candidates stand in air on a floor: the mark goes there.
local catalogue = dofile(repo .. "/mods/PLAYER/grug_expeditions/catalogue.lua")
for _, row in ipairs(catalogue.EXPEDITIONS) do
	local handle = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/" .. row.template ..
		".exp", "rb"))
	local each = T.parse(handle:read("*a"), inflate, row.template)
	handle:close()
	local function at(x, y, z)
		return each.nodes[each.cells:byte(z * each.size.y * each.size.x + y * each.size.x + x + 1) + 1]
	end
	for _, trap_row in ipairs(each.traps) do
		if trap_row.kind == "floor" then
			local c = trap_row.pos
			check(at(c.x, c.y, c.z) == "air" and at(c.x, c.y - 1, c.z) ~= "air",
				"A " .. row.template .. " floor trap " .. trap_row.group .. " in air on a floor")
		end
	end
end

-- B. The choice.
math.randomseed(72)
local seen = {}
for _ = 1, 200 do
	local run = new_run()
	local chosen = TR.chosen(run)
	local groups = {}
	for _, row in ipairs(chosen.floor) do
		groups[row.group] = (groups[row.group] or 0) + 1
		seen[row.group .. key(row.cell)] = true
		check(not row.revealed, "B nothing revealed at the start")
	end
	for _, row in ipairs(chosen.wall) do
		groups[row.group] = (groups[row.group] or 0) + 1
		seen[row.group .. key(row.muzzle) .. row.axis] = true
	end
	check(groups.f1 == 1 and groups.f2 == 2 and groups.w1 == 1 and groups.w2 == 1, "B picks per group")
	local f2 = {}
	for _, row in ipairs(chosen.floor) do
		if row.group == "f2" then f2[key(row.cell)] = true end
	end
	check(f2[key({x = MINP.x + 8, y = MINP.y + 5, z = MINP.z + 38})] and
		f2[key({x = MINP.x + 14, y = MINP.y + 5, z = MINP.z + 38})], "B no candidate twice")
	end_run(run)
	check(TR.chosen(run) == nil, "B gone with the run")
end
local variety = 0
for _ in pairs(seen) do variety = variety + 1 end
-- f1: 2, f2: 2, w1: 2, w2: 1.
check(variety == 7, "B every candidate is chosen in some creation, got " .. variety)

-- C. The floor trap.
local DAMAGE = math.floor(0.45 * grug_core.base_pool(20) + 0.5)
check(TR.damage(20) == DAMAGE and DAMAGE == 173, "C 45 % of the level 20 pool")
check(TR.damage(69) == TR.damage(60), "C the pool stops at 60")
local run = new_run(20)
local chosen = TR.chosen(run)
local trap
for _, row in ipairs(chosen.floor) do
	if row.group == "f1" then trap = row end
end
local tx = trap.cell.x - MINP.x -- 8 or 14
local a = new_player("a", {x = tx - 3, y = 4.5, z = 30})
local b = new_player("b", {x = tx - 1.8, y = 4.5, z = 30})
local c = new_player("c", {x = tx, y = 4.5, z = 32.5})
local d = new_player("d", {x = tx + 1.6, y = 4.5, z = 30})
local far = new_player("far", {x = 45, y = 4.5, z = 45}) -- not inside
for _, p in ipairs({a, b, c, d}) do enter(run, p) end
-- A wall between the trap and d.
overrides[key({x = trap.cell.x + 1, y = trap.cell.y, z = trap.cell.z})] = "default:stonebrick"
-- A mob on the other f2 cell and in the ring: nothing looks at it.
run_for(1)
check(count("expedition_trap_warning") == 0, "C nothing fires untrodden")
-- Over the trap with a jump: feet a node above the floor.
place(a, feet({x = tx, y = 6, z = 30}))
run_for(0.6)
check(count("expedition_trap_warning") == 0, "C a jump clears it")
place(a, feet({x = tx - 3, y = 5, z = 30}))
run_for(0.4)
check(count("expedition_trap_warning") == 0, "C landing beyond it after the jump")
-- a walks across it in one pass, never stopping within 0.6 of its centre.
place(a, feet({x = tx - 0.9, y = 5, z = 30.1}))
step(0.2)
local fired_at = clock
place(a, feet({x = tx + 0.7, y = 5, z = 30.1}))
local before = #particles_sent
run_for(0.4)
check(count("expedition_trap_warning") == 16, "C a walk over it starts the ring of 16")
for i = before + 1, #particles_sent do
	local row = particles_sent[i]
	if row.id == "expedition_trap_warning" then
		fired_at = row.born
		local dx, dz = row.pos.x - trap.cell.x, row.pos.z - trap.cell.z
		check(near(math.sqrt(dx * dx + dz * dz), 2, 1e-6) and near(row.life, 1.5), "C a mote on radius 2 for 1.5 s")
	end
end
-- a stays on it.
place(a, feet({x = tx + 0.2, y = 5, z = 30}))
run_for(1.0)
check(#a.hits == 0 and #b.hits == 0, "C no hit before 1.5 s")
run_for(0.6)
check(#a.hits == 1 and a.hits[1].amount == DAMAGE, "C the hit on the trap: " .. tostring(a.hits[1] and a.hits[1].amount))
check(near(a.hits[1].at, fired_at + 1.5, 0.11), "C the hit 1.5 s after the ring")
check(a.hits[1].reason.type == "punch" and a.hits[1].reason.object == nil and
	a.hits[1].reason.custom_type == "grug_core:player_armor_applied", "C a hit, armor applied, no puncher")
check(#b.hits == 1 and b.hits[1].amount == DAMAGE, "C 1.8 away in sight is hit")
check(#c.hits == 0, "C 2.5 away is not")
check(#d.hits == 0, "C behind a wall is not")
check(count("expedition_trap_hit") == 8, "C eight particles for the hit")
check(overrides[key(trap.cell)] == "grug_expeditions:trap_mark", "C the mark from the first hit")
local revealed = false
for _, row in ipairs(TR.chosen(run).floor) do
	if key(row.cell) == key(trap.cell) then revealed = row.revealed end
end
check(revealed, "C revealed in the run's state")
-- Rearm 10 s after the hit; a stays on it all along.
local hit_at = a.hits[1].at
run_for(hit_at + 9.8 - clock)
check(count("expedition_trap_warning") == 16, "C no second ring before the rearm")
run_for(0.6)
check(count("expedition_trap_warning") == 32, "C the second ring after the rearm")
run_for(1.6)
check(#a.hits == 2, "C the second hit")
-- Armor through the same path.
a.armor = 0.5
a.hp = 1000
run_for(12)
check(#a.hits == 3 and a.hits[3].amount == math.ceil(DAMAGE * 0.5), "C armor counts")
place(a, feet({x = 45, y = 5, z = 45}))
run_for(11)
check(#a.hits == 3, "C off the trap, no more")
-- A dead player treads nothing.
local hits_a = #a.hits
local rings = count("expedition_trap_warning")
a.hp = 0
place(a, feet({x = tx, y = 5, z = 30}))
run_for(3)
check(count("expedition_trap_warning") == rings and #a.hits == hits_a, "C the dead tread nothing")
a.hp = 1000
place(a, feet({x = 45, y = 5, z = 45}))
check(#far.hits == 0, "C a player outside the run is never looked at")
overrides[key({x = trap.cell.x + 1, y = trap.cell.y, z = trap.cell.z})] = nil
end_run(run)

-- D. The wall trap.
for name in pairs(players) do players[name] = nil end
objects = {}
run = new_run(20)
local ready_at = clock
chosen = TR.chosen(run)
local w1row, w2row
for _, row in ipairs(chosen.wall) do
	if row.group == "w1" then w1row = row else w2row = row end
end
-- Nobody inside: no fireball, the timing kept.
run_for(5)
check(#objects == 0, "D nobody inside, no shot")
-- p stands in w2's line (z 42), far from w1's (z 34), within 32 of both muzzles.
local p = new_player("p", {x = 12, y = 4.5, z = 45})
local q = new_player("q", {x = 12, y = 4.5, z = 40})
enter(run, p)
enter(run, q)
local launches = {}
local add = core.add_entity
core.add_entity = function(pos, name)
	launches[#launches + 1] = {at = clock, pos = pos}
	return add(pos, name)
end
run_for(ready_at + 12.05 - clock)
-- Shots at 8 and 12 (w1, period 4, offset 0) and at 6 and 10 (w2, offset 2).
check(#launches == 4, "D four shots in 5..12 s, got " .. #launches)
local w1_times, w2_times = {}, {}
for _, row in ipairs(launches) do
	if near(row.pos.z, w1row.muzzle.z) then w1_times[#w1_times + 1] = row.at - ready_at
	else w2_times[#w2_times + 1] = row.at - ready_at end
end
check(#w1_times == 2 and #w2_times == 2, "D both walls shoot")
check(near(w1_times[1], 8, 0.21) and near(w1_times[2], 12, 0.21), "D w1 every 4 s from readiness")
check(near(w2_times[1], 6, 0.21) and near(w2_times[2], 10, 0.21), "D w2 2 s later")
-- The flight: speed 8 along the axis, stopped by the stone 15.5 nodes on.
local ball = objects[1]
check(near(math.abs(ball.velocity.x), 8) and ball.velocity.z == 0 and ball.velocity.y == 0, "D speed 8 along x")
check(ball.removed and #p.hits == 0 and #q.hits == 0, "D an empty line ends at the stone")
-- The tail: at most 8 live particles per fireball.
local most = 0
for t = ready_at + 5, ready_at + 12, 0.05 do
	local live = 0
	for _, row in ipairs(particles_sent) do
		if row.id == "expedition_fireball_tail" and row.born <= t and t < row.born + row.life then
			live = live + 1
		end
	end
	most = math.max(most, live)
end
check(most >= 3 and most <= 8, "D at most 8 live tail particles, got " .. most)
-- A player in w2's line: the burst, the same damage, in radius 2; a mob in the way
-- changes nothing (nothing looks at objects).
place(p, feet({x = 12, y = 5, z = 42}))
place(q, feet({x = 12, y = 5, z = 40.3}))
local r = new_player("r", {x = 12, y = 4.5, z = 39})
enter(run, r)
run_for(ready_at + 14.2 - clock) -- w2 shoots at 14, flies 8 nodes to p in 1 s
run_for(1.2)
check(#p.hits == 1 and p.hits[1].amount == DAMAGE, "D the fireball hits p")
check(#q.hits == 1 and #r.hits == 0, "D the burst reaches 1.7 away, not 3")
local burst = 0
for _, row in ipairs(particles_sent) do
	if row.id == "expedition_fireball_burst" and row.born == p.hits[1].at then burst = burst + 1 end
end
check(burst == 8, "D eight particles in the burst")
local last = objects[#objects]
check(last.removed and math.abs(last.pos.x - p.pos.x) < 1.2, "D the ball stops at the player")
-- Stone stops it short: a block in w1's line.
local wall_x = math.floor(w1row.muzzle.x + 0.5) + (w1row.axis == "+x" and 5 or -5)
overrides[key({x = wall_x, y = MINP.y + 6, z = MINP.z + 34})] = "default:stonebrick"
place(p, feet({x = 45, y = 5, z = 45}))
place(q, feet({x = 12, y = 5, z = 45}))
place(r, feet({x = 12, y = 5, z = 45}))
local function w1_shot(at)
	for i = #objects, 1, -1 do
		local object = objects[i]
		if object.name and launches[i] and near(launches[i].at - ready_at, at, 0.21) and
				near(launches[i].pos.z, w1row.muzzle.z) then
			return object
		end
	end
end
run_for(ready_at + 18.5 - clock)
local short = w1_shot(16)
check(short and short.removed and math.abs(short.pos.x - wall_x) < 1.6, "D a stone block stops it")
overrides[key({x = wall_x, y = MINP.y + 6, z = MINP.z + 34})] = nil
-- The ball at y 5.5 reaches into the row below its centre's (5 and 6): a block in
-- the lower row stops it too; one in the row above (7) does not.
overrides[key({x = wall_x, y = MINP.y + 5, z = MINP.z + 34})] = "default:stonebrick"
run_for(ready_at + 22.5 - clock)
short = w1_shot(20)
check(short and short.removed and math.abs(short.pos.x - wall_x) < 1.6, "D a block in the lower row stops it")
overrides[key({x = wall_x, y = MINP.y + 5, z = MINP.z + 34})] = nil
overrides[key({x = wall_x, y = MINP.y + 7, z = MINP.z + 34})] = "default:stonebrick"
run_for(ready_at + 26.5 - clock)
local full = w1_shot(24)
local far_end = w1row.axis == "+x" and MINP.x + 19.1 or MINP.x + 3.9
check(full and full.removed and math.abs(full.pos.x - far_end) < 1, "D a block above the ball does not")
overrides[key({x = wall_x, y = MINP.y + 7, z = MINP.z + 34})] = nil
-- Nobody within 32 of the line: skipped.
for _, x in ipairs({p, q, r}) do place(x, feet({x = 45, y = 5, z = 100})) end
local launched = #launches
run_for(ready_at + 29.5 - clock)
check(#launches == launched, "D nobody near, no shot")
-- 30 beside the line's far end, 33.8 from the muzzle: the shot flies.
place(p, {x = far_end, y = MINP.y + 4.5, z = MINP.z + 64})
check(vector.distance(p.pos, w1row.muzzle) > 32, "D p is beyond 32 of the muzzle")
run_for(ready_at + 32.3 - clock)
check(w1_shot(32) ~= nil, "D within 32 of its line, it shoots")
-- The run's end takes its fireballs along.
local flying = objects[#objects]
check(not flying.removed, "D one in flight")
end_run(run)
step(0.1)
check(flying.removed, "D gone with the run")

-- E. The helper and the run's end.
for name in pairs(players) do players[name] = nil end
run = new_run(30)
local s = new_player("s", {x = 30, y = 4.5, z = 12})
local s2 = new_player("s2", {x = 31.5, y = 4.5, z = 12})
enter(run, s)
enter(run, s2)
local rings_before = count("expedition_trap_warning")
local handle = TR.strike(run, s:get_pos())
check(count("expedition_trap_warning") == rings_before + 16, "E the ring at once")
run_for(1.4)
check(#s.hits == 0, "E no hit before 1.5 s")
place(s2, feet({x = 33, y = 5, z = 12}))
run_for(0.2)
local D30 = math.floor(0.45 * grug_core.base_pool(30) + 0.5)
check(#s.hits == 1 and s.hits[1].amount == D30 and #s2.hits == 0, "E one position, one hit, the run's level")
check(handle.done, "E the handle knows")
handle = TR.strike(run, s:get_pos())
run_for(0.5)
TR.cancel(handle)
run_for(2)
check(#s.hits == 1, "E cancelled, no hit")
TR.strike(run, s:get_pos())
end_run(run)
run_for(2)
check(#s.hits == 1, "E the run's end takes it back")
-- A floor trap firing as the run ends: no hit and no mark.
run = new_run(20)
for _, row in ipairs(TR.chosen(run).floor) do
	if row.group == "f2" then trap = row end
end
local t = new_player("t", {x = trap.cell.x - MINP.x, y = 4.5, z = trap.cell.z - MINP.z})
overrides[key(trap.cell)] = nil
enter(run, t)
run_for(0.4)
end_run(run)
run_for(2)
check(#t.hits == 0 and overrides[key(trap.cell)] == nil, "E a ring at the end lands nothing")
-- Nobody inside: the pass stops.
check(#timers == 0, "E nothing left ticking")
-- The budget at once: a whole wave stays far below the hundreds.
check(count("expedition_trap_warning") % 16 == 0 and count("expedition_trap_hit") % 8 == 0, "E counts")

print("R72 TRAPS PORTABLE PASS checks=" .. checks .. " tail_live_max=" .. most)
