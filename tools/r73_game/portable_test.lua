-- Round 73 lane GAME portable test (LuaJIT): the template's new lines, the ambush, the
-- critters, the particles and lava immunity, on the real code and small fake engines.
-- The engine half is tools/r73_game/run.sh. Prints "R73 GAME PORTABLE PASS checks=<n>".
--
--   luajit tools/r73_game/portable_test.lua [REPO]
--
-- A. The format (template.lua): the test vault's lines, every refusal, check_fits; the
--    writers' half in Python (writers_test.py, run from here).
-- B. The ambush (traps.lua): armed by pick with the trap groups; sprung by a walk, a
--    sprint, a jump, a Blink, a Charge and a knockback across the zone, at any height in
--    the passage, never by a teleport (respawn, travel), a dead player or a long move;
--    once per run, untouched by a wipe; the dust burst its only cue.
-- C. The rooms (encounters.lua): an ambush room never by proximity, sprung once and set
--    on the player at once; critters by proximity outside the pack logic; no drop; the
--    load checks (roster, melee only).
-- D. The packs (packs.lua): lava immunity at spawn and on every activation, a critter
--    without a pack, no fight with a critter, the pull, a jump beside a player in lava
--    lands on the rim.
-- E. A critter's death settles nothing (grug_mobs init.lua), and the critter tier pays
--    no XP (levels.lua).
-- F. The particles (particles.lua): one spawner per line and run player inside, to them
--    alone, within the amount, gone on leaving and at the end; the scale.
-- G. Lava stays a boundary with lava_damage 0 (mobs/api.lua is_node_dangerous,
--    grug_nav's cell test), and the boss floor over stairs and a basin
--    (grug_mobs/boss_floor.lua).
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(text, from, to)
	local a = assert(text:find(from, 1, true), "anchor " .. from)
	local _, e = assert(text:find(to, a, true))
	return text:sub(a, e)
end
local function load_in(source, env, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function vector.add(a, b)
	if type(b) == "number" then return {x = a.x + b, y = a.y + b, z = a.z + b} end
	return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end
function vector.subtract(a, b)
	if type(b) == "number" then return {x = a.x - b, y = a.y - b, z = a.z - b} end
	return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
end
function vector.offset(v, x, y, z) return {x = v.x + x, y = v.y + y, z = v.z + z} end
function vector.multiply(a, s) return {x = a.x * s, y = a.y * s, z = a.z * s} end
function vector.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- ---- A. The format ------------------------------------------------------------------
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")
local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 4194304), ffi.new("unsigned long[1]", 4194304)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
local function load_template(name)
	local text = read("mods/PLAYER/grug_expeditions/templates/" .. name .. ".exp")
	local tpl = T.parse(text, inflate, name)
	T.check_fits(tpl, {x = 128, y = 64, z = 128}, {"arrival", "start_waystone", "end_waystone"}, name)
	return tpl
end
local vault = load_template("test_vault")
check(#vault.ambushes == 1 and #vault.particles == 1 and #vault.encounters == 7, "A the vault's lines")
local a1 = vault.ambushes[1]
check(a1.group == "a1" and a1.pick == 1 and a1.kind == "ambush" and a1.room == "drift" and
	a1.min.x == 11 and a1.min.y == 5 and a1.min.z == 18 and a1.max.x == 13 and a1.max.z == 20,
	"A the ambush line")
local dust = vault.particles[1]
check(dust.style == "dust" and dust.amount == 24 and dust.min.x == 5 and dust.max.y == 9, "A the particles line")
local critters = 0
for _, row in ipairs(vault.encounters) do
	if row.tier == "critter" then critters = critters + 1 end
end
check(critters == 2, "A two critter markers")
-- Every real template still reads (wave 2 of Round 73 adds ambush and particles lines to them).
for _, name in ipairs({"stilled_seam", "second_shift", "last_mint"}) do
	local tpl = load_template(name)
	check(#tpl.encounters > 0, "A " .. name .. " reads")
end
check(T.parse_ambush("a 1 r 3 5 9 1 2").min.x == 1 and T.parse_ambush("a 1 r 3 5 9 1 2").max.z == 9,
	"A corners in either order")
for _, bad in ipairs({"a 0 r 1 2 3 4 5", "a 1 r 1 2 3 4", "a 1 r 1 2 3 4 5 6", "a x r 1 2 3 4 5",
		"a 1 r 1.5 2 3 4 5", "a 1 r -1 2 3 4 5"}) do
	check(T.parse_ambush(bad) == nil, "A refused ambush: " .. bad)
end
for _, bad in ipairs({"fog 1 2 3 4 5 6 7", "dust 1 2 3 4 5 6 0", "dust 1 2 3 4 5 6", "dust 1 2 3 4 5 6 7.5"}) do
	check(T.parse_particles(bad) == nil, "A refused particles: " .. bad)
end
for style in pairs(T.PARTICLE_STYLES) do
	check(T.parse_particles(style .. " 1 2 3 4 5 6 7") ~= nil, "A the style " .. style)
end
local function refused(lines, needle)
	local head = "grudgelands-expedition-template 1\nname x\nsize 16 16 16\nnode air\n" .. lines .. "data 0\n"
	local ok, message = pcall(T.parse, head, function() return string.rep("\0", 2 * 4096) end, "bad")
	check(not ok and tostring(message):find(needle, 1, true), "A refused: " .. needle .. " got " .. tostring(message))
end
local zombie = "encounter r grug_mobs:zombie 1 normal 5 2 9\n"
refused("ambush a 1 r 1 2 3 4\n", "malformed")
refused("particles fog 1 2 3 4 5 6 7\n", "malformed")
refused(zombie .. "ambush a 1 r 1 2 3 4 5\nencounter s grug_mobs:zombie 1 normal 5 2 9\nambush a 2 s 1 2 3 4 5\n",
	"disagrees with itself")
refused(zombie .. "ambush f 1 r 1 2 3 4 5\ntrap f 1 floor 1 2 3\n", "disagrees with itself")
refused(zombie .. "ambush a 2 r 1 2 3 4 5\n", "picks more than it has")
refused("ambush a 1 r 1 2 3 4 5\n", "names no markers")
refused("encounter r grug_mobs:zombie 1 elite 5 2 9\nambush a 1 r 1 2 3 4 5\n", "holds a elite")
refused(zombie .. "ambush a 1 r 1 2 3 4 5\nambush b 1 r 6 2 3 7 5\n", "has two ambushes")
refused(zombie .. "encounter r grug_mobs:cave_bat 1 critter 5 2 9\n", "mixes critters and a pack")
refused(string.rep("particles dust 1 2 3 4 5 6 100\n", 4), "over the budget")
check(pcall(T.parse, "grudgelands-expedition-template 1\nname x\nsize 16 16 16\nnode air\n" .. zombie ..
	"ambush a 1 r 1 2 3 4 5\nparticles ash 1 2 3 4 5 6 300\ndata 0\n",
	function() return string.rep("\0", 2 * 4096) end, "good"), "A a good head reads")
local small = {size = {x = 16, y = 16, z = 16}, places = {}, encounters = {},
	ambushes = {{group = "a", min = {x = 1, y = 2, z = 1}, max = {x = 16, y = 2, z = 2}}}}
check(not pcall(T.check_fits, small, {x = 128, y = 64, z = 128}, {}, "small"), "A an ambush outside")
small.ambushes[1].max.x = 15
check(pcall(T.check_fits, small, {x = 128, y = 64, z = 128}, {}, "small"), "A an ambush inside")
small.particles = {{style = "dust", min = {x = 1, y = 1, z = 1}, max = {x = 3, y = 16, z = 3}}}
check(not pcall(T.check_fits, small, {x = 128, y = 64, z = 128}, {}, "small"), "A particles outside")
-- The writers (Python), the same rules at build.
local status = os.execute("python3 -I " .. repo .. "/tools/r73_game/writers_test.py " .. repo)
check(status == 0 or status == true, "A the writers")

-- ---- B. The ambush (traps.lua) --------------------------------------------------------
local clock = 0
local timers = {}
local function after(seconds, fn, ...)
	timers[#timers + 1] = {at = clock + seconds, fn = fn, args = {...}}
end
local function flush_due()
	while true do
		local first
		for index, timer in ipairs(timers) do
			if timer.at <= clock + 1e-9 and (not first or timer.at < timers[first].at) then first = index end
		end
		if not first then return end
		local timer = table.remove(timers, first)
		timer.fn(unpack(timer.args))
	end
end
local function step(dt)
	clock = clock + (dt or 0.1)
	flush_due()
end

local particles_sent = {}
local current_effect
local players = {}
local teleport_hooks = {}
local springs = {}
core = {
	settings = {get = function() return nil end},
	registered_nodes = {air = {walkable = false}},
	get_modpath = function() return repo .. "/mods/PLAYER/grug_expeditions" end,
	get_current_modname = function() return "grug_expeditions" end,
	log = function(_, text) error("unexpected log: " .. tostring(text)) end,
	get_us_time = function() return clock * 1e6 end,
	after = after,
	register_node = function(name, def) core.registered_nodes[name] = def end,
	register_entity = function() end,
	get_node_or_nil = function() return {name = "air"} end,
	get_node = function() return {name = "air"} end,
	set_node = function() error("an ambush sets no node") end,
	add_particle = function(def)
		particles_sent[#particles_sent + 1] = {id = current_effect, pos = def.pos, glow = def.glow}
	end,
	add_particlespawner = function() error("no spawner expected") end,
	-- The vault's wall traps shoot on: no fireball here (traps.lua launch gives up).
	add_entity = function() return nil end,
	get_player_by_name = function(name) return players[name] end,
}
grug_core = {}
grug_mobs = {}
grug_home = {register_on_teleport = function(fn) teleport_hooks[#teleport_hooks + 1] = fn end}
dofile(repo .. "/mods/CORE/grug_core/particles.lua")
local play = grug_core.particles.play
grug_core.particles.play = function(id, frame)
	current_effect = id
	play(id, frame)
	current_effect = nil
end
function grug_core.mono_time() return clock end
local hooks = {ready = {}, enter = {}, ended = {}}
local templates = {test_vault = vault}
grug_expeditions = {templates = templates}
local current_template = "test_vault"
function grug_expeditions.definition() return {template = current_template} end
function grug_expeditions.register_on_ready(fn) hooks.ready[#hooks.ready + 1] = fn end
function grug_expeditions.register_on_enter(fn) hooks.enter[#hooks.enter + 1] = fn end
function grug_expeditions.register_on_end(fn) hooks.ended[#hooks.ended + 1] = fn end
function grug_expeditions._spring_room(run, room, player)
	springs[#springs + 1] = {run = run, room = room, name = player:get_player_name(), at = clock}
end
dofile(repo .. "/mods/PLAYER/grug_expeditions/traps.lua")
local TR = grug_expeditions.traps
check(#teleport_hooks == 1, "B the teleport hook")

local MINP = {x = 8064, y = -112, z = -1616}
local FLOOR = MINP.y + 5 - 0.5 -- the drift's feet height
local function at(x, z, dy) return {x = MINP.x + x, y = FLOOR + (dy or 0), z = MINP.z + z} end
local function new_player(name)
	local p = {name = name, hp = 20, pos = at(8, 19)}
	function p.get_player_name() return name end
	function p.get_pos() return vector.copy(p.pos) end
	function p.get_hp() return p.hp end
	players[name] = p
	return p
end
local next_id = 0
local function new_run()
	next_id = next_id + 1
	local run = {id = next_id, expedition = "test_vault", level = 30, minp = MINP, inside = {}, state = "ready"}
	for _, fn in ipairs(hooks.ready) do fn(run) end
	return run
end
local function enter(run, p)
	run.inside[p.name] = true
	run.state = "running"
	for _, fn in ipairs(hooks.enter) do fn(run, p.name) end
end
local function teleport(p, pos)
	p.pos = vector.copy(pos)
	for _, fn in ipairs(teleport_hooks) do fn(p) end
end
local function count_dust()
	local n = 0
	for _, row in ipairs(particles_sent) do
		if row.id == "expedition_ambush_dust" then n = n + 1 end
	end
	return n
end
-- Moves `p` along x at `speed` nodes a second, from x0 to x1 on z, in server steps.
local function walk(p, x0, x1, z, speed, dy)
	teleport(p, at(x0, z, dy))
	step(0.2)
	local dir = x1 > x0 and 1 or -1
	local x = x0
	while (x1 - x) * dir > 0 do
		x = x + dir * math.min(speed * 0.1, math.abs(x1 - x))
		p.pos = at(x, z, dy)
		step(0.1)
	end
	step(0.3)
end
-- Places `p` at each position for one trap pass (0.2 s) in turn.
local function hops(p, list)
	for _, pos in ipairs(list) do
		p.pos = pos
		step(0.2)
	end
	step(0.2)
end

check(TR.chosen(new_run()).ambush[1].room == "drift", "B the vault's candidate is armed")
local function scene(label, moves, expect)
	local p = new_player("p" .. next_id)
	local run = new_run()
	enter(run, p)
	step(0.3)
	local before, dust_before = #springs, count_dust()
	moves(p, run)
	local fired = #springs - before
	check(fired == expect, "B " .. label .. ": " .. fired .. " springs")
	if expect == 1 then
		local row = springs[#springs]
		check(row.run == run and row.room == "drift" and row.name == p.name, "B " .. label .. ": the room and its player")
		check(count_dust() - dust_before == 20, "B " .. label .. ": a dust burst at both alcoves")
		check(TR.chosen(run).ambush[1].fired, "B " .. label .. ": spent")
	end
	run.inside[p.name] = nil
	return run, p
end
scene("a walk", function(p) walk(p, 8, 17, 19, 4) end, 1)
scene("a walk the other way", function(p) walk(p, 17, 9, 18.6, 4) end, 1)
scene("a sprint", function(p) walk(p, 8, 17, 20.4, 5.6) end, 1)
scene("a jump over it between two passes", function(p)
	hops(p, {at(10.3, 19), at(14.7, 19, 1.2), at(15.5, 19)}) end, 1)
scene("a Blink across", function(p) hops(p, {at(8, 19), at(17.5, 19)}) end, 1)
scene("a Charge across", function(p) hops(p, {at(5.1, 19), at(9.9, 19), at(14.7, 19), at(19.5, 19)}) end, 1)
scene("a knockback across", function(p) hops(p, {at(10, 19.5), at(13.9, 18.2)}) end, 1)
scene("at the passage's top", function(p) walk(p, 8, 17, 19, 4, 2.5) end, 1)
scene("on a floor above", function(p) walk(p, 8, 17, 19, 4, 4) end, 0)
scene("beside the zone", function(p) walk(p, 8, 17, 21.6, 4) end, 0)
scene("a teleport across", function(p)
	hops(p, {at(8, 19)})
	teleport(p, at(17, 19))
	step(0.2)
	walk(p, 17, 22, 19, 4)
end, 0)
scene("a respawn across in one pass", function(p)
	hops(p, {at(9, 19)})
	p.hp = 0
	teleport(p, at(15, 19))
	p.hp = 20
	step(0.2)
	walk(p, 15, 20, 19, 4)
end, 0)
scene("a dead player", function(p) p.hp = 0; walk(p, 8, 17, 19, 4) end, 0)
scene("a move too long for a pass", function(p) hops(p, {at(-6, 19), at(17, 19)}) end, 0)
-- Teleported past it, the zone stays armed for a walk back.
scene("a walk back after a teleport", function(p)
	hops(p, {at(8, 19)})
	teleport(p, at(17, 19))
	step(0.2)
	walk(p, 17, 8, 19, 4)
end, 1)
-- Once: a second crossing, a wipe (nothing of the trap moves) and a third crossing.
do
	local run, p = scene("the first crossing", function(p) walk(p, 8, 17, 19, 4) end, 1)
	enter(run, p)
	local before = #springs
	walk(p, 17, 8, 19, 4)
	p.hp = 0
	step(0.5)
	p.hp = 20
	teleport(p, at(8, 8))
	walk(p, 8, 17, 19, 4)
	check(#springs == before, "B once per run, a wipe rearms nothing")
	for _, fn in ipairs(hooks.ended) do fn(run, "empty") end
	check(TR.chosen(run) == nil, "B gone with the run")
end
-- Pick 1 of 2: one candidate armed per run, both over many runs; the other stays quiet.
do
	templates.two = {traps = {}, encounters = vault.encounters, ambushes = {
		{group = "a", pick = 1, kind = "ambush", room = "drift", min = {x = 11, y = 5, z = 18},
			max = {x = 13, y = 5, z = 20}},
		{group = "a", pick = 1, kind = "ambush", room = "drift2", min = {x = 30, y = 5, z = 18},
			max = {x = 32, y = 5, z = 20}}}}
	current_template = "two"
	local armed = {}
	for _ = 1, 60 do
		local chosen = TR.chosen(new_run()).ambush
		check(#chosen == 1, "B pick 1 of 2")
		armed[chosen[1].room] = true
	end
	check(armed.drift and armed.drift2, "B either candidate over many runs")
	local p = new_player("quiet")
	local run
	repeat run = new_run() until TR.chosen(run).ambush[1].room == "drift2"
	enter(run, p)
	local before = #springs
	walk(p, 8, 17, 19, 4)
	check(#springs == before, "B the unarmed candidate stays quiet")
	walk(p, 27, 35, 19, 4)
	check(#springs == before + 1 and springs[#springs].room == "drift2", "B the armed one springs")
	run.inside.quiet = nil
	current_template = "test_vault"
end
-- The trap groups beside it keep their own choice (Round 72's rule).
do
	local chosen = TR.chosen(new_run())
	check(#chosen.floor == 3 and #chosen.wall == 2 and #chosen.ambush == 1, "B the trap groups and the ambush")
end
for _, row in ipairs(particles_sent) do
	if row.id == "expedition_ambush_dust" then
		check(row.glow > 0 and row.glow <= 5, "B the dust glows faintly")
	end
end

-- ---- C. The rooms (encounters.lua) -----------------------------------------------------
local packs_log = {}
local fake_packs = {}
function fake_packs.new(run, boss_id)
	local pack = {run = run, boss_id = boss_id, added = {}}
	packs_log[#packs_log + 1] = {"new", pack}
	return pack
end
function fake_packs.add(pack, row, pos)
	pack.added[#pack.added + 1] = row
	packs_log[#packs_log + 1] = {"add", row.room, row.tier}
	return true
end
function fake_packs.add_critter(run, row)
	packs_log[#packs_log + 1] = {"critter", row.room, row.mob, run.id}
	return true
end
function fake_packs.pull(pack, player)
	packs_log[#packs_log + 1] = {"pull", pack, player:get_player_name()}
end
function fake_packs.standable() return true end
function fake_packs.has_floor() return true end
local real_dofile, real_loadfile = dofile, loadfile
local fake_loot = {ore_items = function() return {} end, check = function() end, TABLES = {}}
dofile = function(file)
	local base = file:match("[^/]+$")
	if base == "packs.lua" then return fake_packs end
	if base == "loot.lua" then return fake_loot end
	return real_dofile(file)
end
loadfile = function(file)
	if file:match("chest%.lua$") then return function() end end
	return real_loadfile(file)
end
local loaded = {}
core.register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end
core.load_area = function() end
core.objects_in_area = function() return function() return nil end end
core.registered_entities = {["grug_mobs:zombie"] = {attack_type = "dogfight"},
	["grug_mobs:skeleton_archer"] = {attack_type = "shoot"},
	["grug_mobs:giant_spider"] = {attack_type = "dogfight"}, ["grug_mobs:stone_golem"] = {attack_type = "dogshoot"},
	["grug_mobs:cave_bat"] = {}, ["grug_mobs:cave_crawler"] = {}, ["grug_mobs:rabbit"] = {}}
grug_materials = {RESOURCES = {}}
grug_mobs.rift_rules = {SPAWN_RANGE = 48}
grug_mobs.settle_mob_death = function() return true end
local base_filter_calls = 0
grug_mobs._item_drop_filter = function(_, drops) base_filter_calls = base_filter_calls + 1; return drops end
local M = grug_expeditions
M.catalogue = {EXPEDITIONS = {}}
local runs_encounters = {}
function M.encounters(run) return runs_encounters[run] end
M.register_on_ready = function(fn) hooks.ready[#hooks.ready + 1] = fn end
hooks.ready, hooks.enter, hooks.ended = {}, {}, {}
dofile(repo .. "/mods/PLAYER/grug_expeditions/encounters.lua")
dofile, loadfile = real_dofile, real_loadfile
check(type(M._spring_room) == "function", "C the ambush's half")
local crun = {id = 900, expedition = "test_vault", level = 30, minp = MINP, inside = {}, state = "ready",
	places = {}}
local rows = {}
for index, row in ipairs(vault.encounters) do
	rows[index] = {room = row.room, mob = row.mob, count = row.count, tier = row.tier,
		pos = {x = MINP.x + row.pos.x, y = MINP.y + row.pos.y, z = MINP.z + row.pos.z}}
end
runs_encounters[crun] = rows
M.definition = function() return {template = "test_vault"} end
for _, fn in ipairs(hooks.ready) do fn(crun) end
local news = 0
for _, row in ipairs(packs_log) do if row[1] == "new" then news = news + 1 end end
check(news == 3, "C a pack for hall, court and the drift, none for critters: " .. news)
local walker = new_player("walker")
walker.pos = at(30, 12)
crun.inside.walker = true
for _, fn in ipairs(hooks.enter) do fn(crun, "walker") end
step(0.1)
step(1.1)
local placed = {}
for _, row in ipairs(packs_log) do
	if row[1] == "add" or row[1] == "critter" then placed[row[2]] = (placed[row[2]] or 0) + 1 end
end
check(placed.hall == 3 and placed.court == 1, "C the hall and the court by proximity")
check(placed.crawlers == 1 and placed.bats == 1, "C both critters by proximity, outside the packs")
check(not placed.drift, "C the ambush room waits, the walker within range")
M._spring_room(crun, "drift", walker)
local adds, pulled = 0, nil
for _, row in ipairs(packs_log) do
	if row[1] == "add" and row[2] == "drift" then adds = adds + 1 end
	if row[1] == "pull" then pulled = row end
end
check(adds == 2 and pulled and pulled[3] == "walker" and #pulled[2].added == 2,
	"C sprung: both alcoves placed and set on the walker at once")
local log_size = #packs_log
M._spring_room(crun, "drift", walker)
step(1.1)
check(#packs_log == log_size, "C once: nothing placed again")
check(M.rewards_open(crun) == false, "C the critters gate nothing: the boss still closes the chest")
check(grug_mobs._item_drop_filter({_grug_expedition = 1, _grug_scenery = true}, {{name = "mobs:meat_raw"}}) == nil,
	"C a critter drops nothing")
check(base_filter_calls == 0, "C nor rolls a drop")
-- The load checks.
local function load_fails(tpl)
	M.templates = {t = tpl}
	local ok, message = pcall(loaded[1])
	return not ok and message or nil
end
local good = {ambushes = {{room = "r"}}, encounters = {{room = "r", mob = "grug_mobs:zombie", tier = "normal", count = 1},
	{room = "b", mob = "grug_mobs:cave_bat", tier = "critter", count = 2}}}
check(load_fails(good) == nil, "C a good template loads")
good.encounters[3] = {room = "c", mob = "grug_mobs:rabbit", tier = "critter", count = 1}
check((load_fails(good) or ""):find("is no critter", 1, true), "C a critter off the roster stops the load")
good.encounters[3] = {room = "r", mob = "grug_mobs:skeleton_archer", tier = "normal", count = 1}
check((load_fails(good) or ""):find("the archer", 1, true), "C an archer in an ambush stops the load")
good.encounters[3] = {room = "h", mob = "grug_mobs:skeleton_archer", tier = "normal", count = 1}
check(load_fails(good) == nil, "C an archer elsewhere is fine")
M.templates = templates

-- ---- D. The packs (packs.lua) ----------------------------------------------------------
local world = {} -- "x,y,z" -> node name; default stone below y 0, air from y 0
local function wkey(x, y, z) return x .. "," .. y .. "," .. z end
local function node_at(pos)
	local x, y, z = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
	return world[wkey(x, y, z)] or (y < 0 and "default:stone" or "air")
end
core.registered_nodes = {air = {walkable = false, groups = {}}, ["default:stone"] = {walkable = true, groups = {}},
	["default:lava_source"] = {walkable = false, damage_per_second = 8, liquidtype = "source",
		groups = {lava = 3, liquid = 2}},
	["stairs:stair_stone"] = {walkable = true, groups = {stair = 1}}}
core.get_node_or_nil = function(pos) return {name = node_at(pos)} end
core.get_node = core.get_node_or_nil
core.line_of_sight = function() return true end
core.serialize = function(t) return t end
core.is_player = function(p) return type(p) == "table" and p.get_player_name ~= nil end
core.register_on_dieplayer = function() end
core.register_on_shutdown = function() end
core.register_on_leaveplayer = function() end
core.register_on_joinplayer = function() end
core.calculate_knockback = function() return 0 end
local entities = {}
core.add_entity = function(pos, name, data)
	local object = {pos = vector.copy(pos)}
	local ent = {name = name, object = object, lava_damage = 4}
	for k, v in pairs(data or {}) do ent[k] = v end
	function object.get_luaentity() return not object.removed and ent or nil end
	function object.get_pos() return not object.removed and vector.copy(object.pos) or nil end
	function object.set_velocity() end
	function object.remove() object.removed = true end
	function object.set_properties() end
	function ent.do_attack(self, player) self.attack, self.state = player, "attack" end
	entities[#entities + 1] = ent
	return object
end
local engaged = {}
grug_core.engage_mob = function(ent, player) engaged[#engaged + 1] = {ent, player} end
grug_core.mark_in_combat = function() end
grug_core.damage_source = function(o) return o end
grug_mobs.place_on_ground = function(object, pos) object.pos = vector.copy(pos); object.placed = vector.copy(pos) end
grug_mobs.set_tier = function(ent, tier) ent._grug_tier = tier end
grug_mobs.ensure_init = function() end
grug_mobs.live_claim = function() return true end
grug_mobs.walk_clear = function() end
mobs = {grug_nav = {forget = function() end}}
M.run_inside = function(name) return name == "walker" and crun or nil end
M.register_on_leave = function() end
M.LOGOUT_DEATH = "x"
local P = dofile(repo .. "/mods/PLAYER/grug_expeditions/packs.lua")
local pack = P.new(crun)
check(P.add(pack, {room = "hall", mob = "grug_mobs:zombie", tier = "normal", count = 1}, {x = 0, y = 0, z = 0}),
	"D a pack member")
local member = entities[#entities]
check(member.lava_damage == 0 and member._grug_expedition == crun.id and member._grug_pack, "D immune at spawn")
member.lava_damage = 4 -- an activation from its definition
grug_mobs.live_claim(member)
check(member.lava_damage == 0, "D immune again on activation")
local wild = {lava_damage = 4, object = {}}
grug_mobs.live_claim(wild)
check(wild.lava_damage == 4, "D the open world's mobs unchanged")
check(P.add_critter(crun, {room = "bats", mob = "grug_mobs:cave_bat", tier = "critter"}, {x = 4, y = 0, z = 4}),
	"D a critter")
local critter = entities[#entities]
check(critter._grug_scenery and critter._grug_expedition == crun.id and not critter._grug_pack and
	critter.lava_damage == 0 and critter.group_attack == false and critter._grug_authored, "D a critter's fields")
critter.lava_damage = 4
grug_mobs.live_claim(critter)
check(critter.lava_damage == 0, "D a critter immune on activation too")
grug_core.engage_mob(critter, walker)
check(#engaged == 0, "D a critter starts no fight")
grug_core.engage_mob(wild, walker)
check(#engaged == 1, "D any other mob does")
P.pull(pack, walker)
check(member.attack == walker and member.state == "attack", "D the pull sets the pack on the player")
-- A jump to a player standing in a lava basin lands on its rim, never in the lava.
for x = 9, 11 do for z = 9, 11 do world[wkey(x, -1, z)] = "default:lava_source" end end
walker.pos = {x = 10, y = -1.5, z = 10} -- sunk in the basin, on its bottom
member.attack = walker
grug_mobs.pack_left_behind(member)
local landed = member.object.placed
check(landed and landed.y == 0 and node_at({x = landed.x, y = -1, z = landed.z}) == "default:stone",
	"D the jump lands on the basin's rim: " .. (landed and (landed.x .. "," .. landed.y .. "," .. landed.z) or "nil"))
check(P.has_floor({x = 10, y = 0, z = 10}) == false and P.has_floor({x = 12, y = 0, z = 10}),
	"D lava is no floor for a spawn spot")

-- ---- E. A critter's death -----------------------------------------------------------
do
	local init = read("mods/ENTITIES/grug_mobs/init.lua")
	local calls = {}
	local env = {grug_mobs = {}, grug_core = {disengage_mob = function() calls.disengage = true end},
		kill_loot_hooks = {function() calls.loot = true end}}
	env.grug_mobs.player_drop_tagger = function() return "walker" end
	env.grug_mobs.award_kill_xp = function() calls.xp = true return true end
	env.grug_mobs.cleanup_xp_participants = function() calls.cleanup = true end
	load_in(cut(init, "function grug_mobs.settle_mob_death(self)", "\nend\n"), env, "settle_mob_death")
	local settle = env.grug_mobs.settle_mob_death
	check(settle({_grug_scenery = true, _grug_expedition = 1}) == false and calls.disengage and calls.cleanup and
		not calls.loot and not calls.xp, "E a critter's death: no loot, no XP, no credit")
	calls = {}
	settle({})
	check(calls.loot and calls.xp, "E any other death settles as before")
	local levels = read("mods/ENTITIES/grug_mobs/levels.lua")
	check(levels:find("critter = {hp = 1, dmg = 1, xp = 1, armor = nil, scale = 1,", 1, true) and
		levels:find("level = 1, hp_flat = 1, xp_flat = 0", 1, true), "E the critter tier pays no XP anywhere")
end

-- ---- F. The particles (particles.lua) ---------------------------------------------------
do
	local spawners, deleted, next_spawner = {}, {}, 10
	core.add_particlespawner = function(def)
		next_spawner = next_spawner + 1
		spawners[next_spawner] = def
		return next_spawner
	end
	core.delete_particlespawner = function(id, name) deleted[#deleted + 1] = {id = id, name = name} end
	local scale = 1
	grug_core.particles.count = function(n) return scale > 0 and math.max(1, math.floor(n * scale + 0.5)) or 0 end
	local leave_hooks = {}
	M.register_on_leave = function(fn) leave_hooks[#leave_hooks + 1] = fn end
	hooks.ready, hooks.enter, hooks.ended = {}, {}, {}
	dofile(repo .. "/mods/PLAYER/grug_expeditions/particles.lua")
	local A = M.ambience
	-- Every style keeps its amount for every amount.
	for name, style in pairs(A.STYLES) do
		check(T.PARTICLE_STYLES[name], "F " .. name .. " is a known style")
		for amount = 1, 300 do
			local rate, short, long = A.rate(style, amount)
			check(rate >= 1 and rate % 1 == 0 and short <= long and rate * long <= amount + 1e-9,
				"F " .. name .. " keeps " .. amount)
		end
	end
	for name in pairs(T.PARTICLE_STYLES) do check(A.STYLES[name], "F " .. name .. " is drawn") end
	local prun = {id = 950, expedition = "test_vault", level = 30, minp = MINP, inside = {}, state = "ready"}
	for _, fn in ipairs(hooks.ready) do fn(prun) end
	check(next(spawners) == nil, "F nothing before anyone is inside")
	local ann, bob = new_player("ann"), new_player("bob")
	new_player("eve") -- not of the run: never entered
	for _, p in ipairs({ann, bob}) do
		prun.inside[p.name] = true
		for _, fn in ipairs(hooks.enter) do fn(prun, p.name) end
	end
	local mine = {}
	for id, def in pairs(spawners) do mine[def.playername] = mine[def.playername] or {}; table.insert(mine[def.playername], id) end
	check(mine.ann and #mine.ann == 1 and mine.bob and #mine.bob == 1 and not mine.eve, "F one spawner per run player, theirs alone")
	local def = spawners[mine.ann[1]]
	check(def.time == 0 and def.amount * def.exptime.max <= 24 and def.pos.min.x == MINP.x + 4.5 and
		def.pos.max.y == MINP.y + 9.5 and def.texture.name:find("grug_core_mote.png", 1, true) and
		def.texture.alpha_tween, "F the dust spawner: endless, within its amount, its box, a shipped PNG")
	check(A.count(prun, "ann") == 1, "F counted")
	prun.inside.ann = nil
	for _, fn in ipairs(leave_hooks) do fn(prun, "ann", "travel") end
	check(#deleted == 1 and deleted[1].id == mine.ann[1] and deleted[1].name == "ann", "F gone when ann leaves")
	prun.inside.ann = true
	for _, fn in ipairs(hooks.enter) do fn(prun, "ann") end
	check(A.count(prun, "ann") == 1, "F back on entering again")
	players.bob = nil -- logged out meanwhile: the delete goes out without a name, freeing the id
	for name in pairs(prun.inside) do
		prun.inside[name] = nil
		for _, fn in ipairs(leave_hooks) do fn(prun, name, "ended") end
	end
	for _, fn in ipairs(hooks.ended) do fn(prun, "empty") end
	check(#deleted == 3 and A.count(prun, "ann") == 0, "F every spawner gone at the end")
	local bobs
	for _, row in ipairs(deleted) do if row.id == mine.bob[1] then bobs = row end end
	check(bobs and bobs.name == nil, "F an absent player's spawner deleted server-wide")
	scale = 0
	local quiet = {id = 951, expedition = "test_vault", level = 30, minp = MINP, inside = {}, state = "ready"}
	for _, fn in ipairs(hooks.ready) do fn(quiet) end
	local count_before = next_spawner
	quiet.inside.ann = true
	for _, fn in ipairs(hooks.enter) do fn(quiet, "ann") end
	check(next_spawner == count_before, "F grug_particle_scale 0: none")
	for _, name in ipairs({"stilled_seam", "second_shift", "last_mint", "test_vault"}) do
		local total = 0
		for _, row in ipairs(load_template(name).particles) do total = total + row.amount end
		check(total <= T.PARTICLE_BUDGET, "F " .. name .. " within the budget")
	end
end

-- ---- G. Lava stays a boundary --------------------------------------------------------------
do
	local api = read("mods/ENTITIES/mobs/api.lua")
	local danger = load_in(cut(api, "local function is_node_dangerous(self, nodename)", "\nend\n") ..
		"\nreturn is_node_dangerous", {core = core}, "is_node_dangerous")
	-- mobs_redo's defaults (api.lua mob_class): node_damage true, water 0, fire 4.
	local immune = setmetatable({lava_damage = 0}, {__index = {water_damage = 0, fire_damage = 4,
		node_damage = true}})
	check(danger(immune, "default:lava_source") == true, "G lava stays dangerous at lava_damage 0 (node_damage)")
	check(api:find("node_damage = true,", 1, true) and api:find("local function has_safe_support", 1, true),
		"G the defaults and the cliff probe")
	check(cut(api, "local function has_safe_support", "\nend\n"):find("return not (def.groups and def.groups.lava)", 1, true),
		"G the Round 34 F1 patch: lava is no support even for an immune mob")
	local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
	local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
	nav.init({obstacle = O, max_jump = 4, max_drop = 6})
	nav.set_dangerous(danger)
	local body = {mob = immune, width = 1, hw = 0.5, head = 2, feet = 0, step = 1, jump = 1, drop = 6, wades = false}
	local open, ground = nav.cell(body, 10, -1, 10)
	check(not open and not ground, "G grug_nav: a lava cell is neither open nor ground for an immune mob")
	body.wades = true
	open, ground = nav.cell(body, 10, -1, 10)
	check(not open and not ground, "G nor for a wading one")
	-- The boss floor: a fill over flat floor, a stair-ringed rise and a basin.
	mobs = {grug_nav = nav}
	grug_core.mark_player_hit = function() end
	grug_core.actor_projectile_lock = function() end
	dofile(repo .. "/mods/ENTITIES/grug_mobs/boss_floor.lua")
	local F = grug_mobs.boss_floor
	for x = 2, 5 do for z = 2, 5 do world[wkey(x, 0, z)] = "default:stone" end end
	for x = 1, 6 do
		for _, z in ipairs({1, 6}) do world[wkey(x, 0, z)] = "stairs:stair_stone" end
		for _, z in ipairs({2, 3, 4, 5}) do
			if x == 1 or x == 6 then world[wkey(x, 0, z)] = "stairs:stair_stone" end
		end
	end
	for x = -6, 16 do for z = -6, 16 do
		if x < -4 or x > 14 or z < -4 or z > 14 then world[wkey(x, 0, z)] = "default:stone" world[wkey(x, 1, z)] = "default:stone" world[wkey(x, 2, z)] = "default:stone" end
	end end
	local bbody = {mob = immune, width = 1, hw = 0.5, head = 2, feet = 0, step = 1, jump = 1, drop = 6, wades = false}
	local fill = F.new({x = 0, y = -0.5, z = 0}, bbody, {x0 = -4, x1 = 14, z0 = -4, z1 = 14, y0 = -4, y1 = 4})
	while not F.step(fill, 400) do end
	local cells = fill.cells
	check(cells[F.key(0, 0, 0)] and cells[F.key(3, 1, 3)] and cells[F.key(1, 1, 1)], "G the floor: flat, the rise and its stairs")
	check(not cells[F.key(10, 0, 10)] and not cells[F.key(10, -1, 10)], "G a basin is no floor")
	-- boss_floor.lua's test: a boss's reach (3 without one of its own) from a floor cell.
	check(F.holds(cells, {x = 10, y = -1.5, z = 10}, 3), "G a target in the basin is within reach of its rim")
	check(F.holds(cells, {x = 10.4, y = -1.5, z = 9.6}, 3), "G anywhere in a small basin")
end

print("R73 GAME PORTABLE PASS checks=" .. checks)
