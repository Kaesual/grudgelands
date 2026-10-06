-- Round 40 lane PM portable test (LuaJIT): the boss and mob-special particle
-- effects (round40-plan.md §2.15, §3.5, §4.2 "PM") on the REAL helper and
-- catalogue (grug_core/particles.lua, particle_effects.lua, loaded through
-- tools/r40_pm/helper_stub.lua) and the REAL mob code on a fake engine.
--
--   luajit tools/r40_pm/portable_test.lua [repo]
--
--   A  the catalogue: every PM effect passes the budget check and plays
--      1..100 particles, spawners unattached and at most 1 s; the exact
--      rings (Shatter's wind-up on its 6 m circle for the whole 2 s, the
--      lightning ring at 2 m for 1.5 s, the gust ring at 8 m for 1.25 s) and
--      the rings that burst out to a radius (Shatter, gust release, dive
--      slam) land on it; the elite arc lies at the elite's reach and turns
--      with its facing; grug_particle_scale 0.5 halves, 0 plays nothing.
--   B  the kings and Generals (king_tick, royal_signature and their helpers
--      cut out of bosses.lua): each kit's wind-up fires at the cast's start
--      (Shatter its ring once; Cleave and the auras a second 1 s spawner
--      halfway, in the kit's colour) and nothing before; the resolve fires
--      Shatter's burst, Cleave's arc along the king's facing, a rise on each
--      rallied guard (at most four), on each raider Bone Call summoned (none
--      at the cap), on the troll only when Regrowth heals; Volley none.
--   C  the elite wind-up and cone hit (telegraph.lua, the real file): the
--      smoke at the wind-up, the arc only at the resolve, also when the
--      player stepped out of the cone.
--   D  the dragons (boss_dragons.lua, the real file): the breath wind-up at
--      the launch point in the breath's colour and the muzzle burst at the
--      release; 12 trail motes per bolt (6 at 0.5, none at 0); the
--      lightning ring at the wind-up and the strike at the impact; the gust
--      ring and the release ring; the dive's wind-up and slam; the take-off
--      dust; enrage and a puff per whelp, once; a breath patch's burst.
--   E  the mob specials (the real verbs.lua, spider.lua, oerkki.lua,
--      night_families.lua, kraken.lua, bog_ooze.lua, bog_witch.lua): the web
--      only from a spider's bite (not from a plain slow); poison on the
--      application and two on each tick, none after death; a pounce's dust
--      at the take-off and once where it lands, none without a landing; the
--      ambush splash (water) or dirt burst once when it breaks cover; the
--      ooze aura only on a tick that hurts someone; the treant's leaves only
--      while it slows someone, every second tick; the Oerkki's and the
--      Wisp's blink at origin and arrival, none when the blink fails; the
--      Kraken's bubbles at the dragged player; the hex bottle; mob
--      projectile impacts (homing arrival, a straight shot's node and player
--      hits) in the projectile's tint, none without a tint or on a lost lock.
--   F  every effect id grug_mobs plays is in the catalogue; the shipped mob
--      projectiles carry an impact tint; the direct engine calls left in
--      grug_mobs are exactly the known ones.
-- Prints "R40 PM PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
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
local function near(actual, expected, label, tolerance)
	return check(type(actual) == "number" and math.abs(actual - expected) < (tolerance or 1e-6),
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local MOBS = "mods/ENTITIES/grug_mobs/"

-- A small vector library (the engine's builtin is not loaded here).
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
function vector.direction(a, b) return vector.normalize(vector.subtract(b, a)) end
function vector.round(p)
	return vector.new(math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5))
end
local function vec(x, y, z) return vector.new(x, y, z) end

------------------------------------------------------------------------------
-- The fake engine: every particle call recorded, every played effect too.
------------------------------------------------------------------------------
local calls, played = {}, {}
local function reset()
	calls, played = {}, {}
end
local players = {}
local Player = {}
Player.__index = Player
function Player:get_pos() return vector.new(self.pos) end
function Player:get_hp() return self.hp end
function Player:set_hp(hp) self.hp = hp end
function Player:get_player_name() return self.name end
function Player:is_player() return true end
function Player:get_luaentity() return nil end
function Player:get_attach() return self.attach end
function Player:get_velocity() return vec(0, 0, 0) end
function Player:add_velocity(v) self.pushes[#self.pushes + 1] = v end
function Player:get_physics_override() return {speed = 1, acceleration_air = 1} end
function Player:punch() self.punched = (self.punched or 0) + 1 end
local function new_player(name, pos)
	local p = setmetatable({name = name, pos = pos, hp = 50000, pushes = {}}, Player)
	players[#players + 1] = p
	return p
end
local function is_player(o) return type(o) == "table" and getmetatable(o) == Player end

local objects = {} -- non-player objects get_objects_inside_radius sees
local function new_object(pos, entity)
	local o = {pos = vector.new(pos), entity = entity, yaw = 0, valid = true}
	function o:get_pos() return self.valid and vector.new(self.pos) or nil end
	function o:set_pos(p) self.pos = vector.new(p) end
	function o:get_yaw() return self.yaw end
	function o:get_luaentity() return self.valid and self.entity or nil end
	function o:is_player() return false end
	function o:remove() self.valid = false end
	function o:set_velocity(v) self.vel = v end
	function o:get_velocity() return self.vel or vec(0, 0, 0) end
	function o:add_velocity(v) self.added = v end
	function o:set_acceleration() end
	function o:set_properties() end
	function o:get_attach() return nil end
	function o:punch() end
	if entity then entity.object = o end
	return o
end

local node_at = function() return "air" end
local after_queue = {}
local mono = 100
core = {
	add_particle = function(def) calls[#calls + 1] = {kind = "single", def = def} end,
	add_particlespawner = function(def) calls[#calls + 1] = {kind = "spawner", def = def} end,
	settings = {get = function() return nil end,
		get_bool = function(_, _, default) return default end},
	log = function() end,
	registered_entities = {},
	registered_nodes = {
		air = {walkable = false},
		["default:stone"] = {walkable = true},
		["default:water_source"] = {walkable = false, liquidtype = "source"},
	},
	get_node_or_nil = function(pos) return {name = node_at(pos)} end,
	get_modpath = function(mod)
		return ROOT .. (mod == "grug_mapgen" and "/mods/MAPGEN/grug_mapgen" or "/mods/ENTITIES/grug_mobs")
	end,
	yaw_to_dir = function(yaw) return vec(-math.sin(yaw), 0, math.cos(yaw)) end,
	is_player = is_player,
	get_connected_players = function() return players end,
	get_player_by_name = function(name)
		for _, p in ipairs(players) do if p.name == name then return p end end
	end,
	get_objects_inside_radius = function(pos, r)
		local out = {}
		for _, list in ipairs({players, objects}) do
			for _, o in ipairs(list) do
				local p = o:get_pos()
				if p and vector.distance(p, pos) <= r then out[#out + 1] = o end
			end
		end
		return out
	end,
	line_of_sight = function() return true end,
	raycast = function() return function() return nil end end,
	after = function(seconds, fn) after_queue[#after_queue + 1] = {seconds, fn} end,
	get_us_time = function() return 1000000 end,
	add_entity = function(pos, name)
		local entity = {name = name, health = 10, hp_max = 10}
		local o = new_object(pos, entity)
		objects[#objects + 1] = o
		return o
	end,
	chat_send_player = function() end,
	set_node = function() end,
	get_node_timer = function() return {start = function() end} end,
	hash_node_position = function(p) return p.x .. "," .. p.y .. "," .. p.z end,
	register_node = function() end,
	register_globalstep = function() end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_player_hpchange = function() end,
	calculate_knockback = function() return 0 end,
	colorize = function(_, t) return t end,
}

local STUB = dofile(ROOT .. "/tools/r40_pm/helper_stub.lua")
local function helper(scale)
	local P = STUB(ROOT, scale)
	local real = P.play
	P.play = function(id, frame)
		played[#played + 1] = {id = id, frame = frame}
		return real(id, frame)
	end
	return P
end

local function ids()
	local out = {}
	for _, p in ipairs(played) do out[#out + 1] = p.id end
	return table.concat(out, ",")
end
local function plays_of(id)
	local out = {}
	for _, p in ipairs(played) do if p.id == id then out[#out + 1] = p end end
	return out
end
local function total_particles()
	local n = 0
	for _, c in ipairs(calls) do n = n + (c.kind == "spawner" and c.def.amount or 1) end
	return n
end
local function singles()
	local out = {}
	for _, c in ipairs(calls) do if c.kind == "single" then out[#out + 1] = c.def end end
	return out
end
local function spawners()
	local out = {}
	for _, c in ipairs(calls) do if c.kind == "spawner" then out[#out + 1] = c.def end end
	return out
end
local function budget_ok(label)
	for _, c in ipairs(calls) do
		if c.kind == "spawner" then
			check(c.def.time > 0 and c.def.time <= 1, label .. ": spawner time in (0, 1]")
			check(c.def.attached == nil and c.def.playername == nil, label .. ": spawner unattached and public")
		end
	end
end
local function horizontal(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end
-- An exact ring: `n` single particles at `radius` around `centre`, `life` s.
local function ring_ok(label, list, n, centre, radius, life)
	eq(#list, n, label .. ": the ring's count")
	local ok_r, ok_l = true, true
	for _, d in ipairs(list) do
		if math.abs(horizontal(d.pos, centre) - radius) > 1e-6 then ok_r = false end
		if life and math.abs(d.expirationtime - life) > 1e-9 then ok_l = false end
	end
	check(ok_r, label .. ": every mote on the " .. radius .. " m circle")
	if life then check(ok_l, label .. ": every mote lives " .. life .. " s") end
end
-- Rings bursting out: each mote ends its life on `reach` around `centre`.
local function lands_ok(label, list, centre, reach)
	local ok = #list > 0
	for _, d in ipairs(list) do
		local p = vector.add(d.pos, vector.multiply(d.velocity, d.expirationtime))
		if math.abs(horizontal(p, centre) - reach) > 1e-6 then ok = false end
	end
	check(ok, label .. ": every mote lands on " .. reach .. " m")
end

grug_core = {particles = helper(nil)}
local P = grug_core.particles

------------------------------------------------------------------------------
-- A: the catalogue.
------------------------------------------------------------------------------
local PM_IDS = {"king_windup_ring", "king_shatter", "king_cleave_windup", "king_cleave",
	"king_aura", "king_resolve", "elite_windup", "elite_cone", "breath_windup",
	"breath_burst_rime", "breath_burst_scorch", "breath_trail", "dragon_patch_rime",
	"dragon_patch_scorch", "lightning_ring", "lightning_strike", "gust_windup", "gust_release",
	"dragon_takeoff", "dive_windup", "dive_slam", "enrage", "whelp_arrival", "kraken_drag",
	"web", "poison", "poison_tick", "pounce", "ambush", "ooze_aura", "treant_aura",
	"oerkki_blink", "wisp_blink", "projectile_impact", "hex_bottle", "rift_spawn_burst"}
local C = vec(100, 10, -40)
local FRAME = {caster = C, target = vec(106, 10, -40), dir = vec(1, 0, 0), reach = 6, time = 2,
	color = "#ffffff"}
local per = {}
for _, id in ipairs(PM_IDS) do
	local effect = P.registered(id)
	if check(effect ~= nil, "A " .. id .. " is in the catalogue") then
		local list = type(effect) == "function" and effect(FRAME) or effect
		eq(P.check(list), nil, "A " .. id .. " keeps the budget rules")
		reset()
		P.play(id, FRAME)
		local n = total_particles()
		per[#per + 1] = id .. "=" .. n
		check(n >= 1 and n <= 100, "A " .. id .. " plays 1..100 particles (" .. n .. ")")
		budget_ok("A " .. id)
	end
end
print("particles per occurrence at 1.0: " .. table.concat(per, " "))

-- The exact rings.
local KING = vec(0, 5, 0)
reset()
P.play("king_windup_ring", {target = KING, reach = 6, time = 2})
ring_ok("A Shatter's wind-up ring", singles(), 40, KING, 6, 2)
reset()
P.play("lightning_ring", {target = KING, reach = 2, time = 1.5})
ring_ok("A the lightning ring", singles(), 32, KING, 2, 1.5)
reset()
P.play("gust_windup", {target = KING, reach = 8, time = 1.25})
ring_ok("A the gust's warning ring", singles(), 40, KING, 8, 1.25)
for _, case in ipairs({{"king_shatter", 6, 48}, {"gust_release", 8, 48}, {"dive_slam", 7, 48}}) do
	reset()
	P.play(case[1], {target = KING, reach = case[2]})
	local list = singles()
	eq(#list, case[3], "A " .. case[1] .. "'s ring count")
	lands_ok("A " .. case[1], list, KING, case[2])
end
-- The elite arc: at the reach ahead, across it, turned with the facing
-- (facing +z: ahead is +z, the line runs along x).
for _, reach in ipairs({3, 4}) do
	reset()
	P.play("elite_cone", {caster = KING, dir = vec(0, 0, 1), reach = reach})
	local arc = spawners()[1]
	if check(arc and arc.pos_tween, "A the elite arc is a tweened line") then
		near(arc.pos_tween[1].z - KING.z, reach, "A the arc lies at reach " .. reach)
		near(arc.pos_tween[2].z - KING.z, reach, "A the arc ends at reach " .. reach)
		near(math.abs(arc.pos_tween[1].x - arc.pos_tween[2].x), 2 * reach * 2.6 / 3,
			"A the arc spans the cone at reach " .. reach)
	end
end
-- The scale.
grug_core.particles = helper("0.5")
reset()
grug_core.particles.play("king_windup_ring", {target = KING, reach = 6, time = 2})
ring_ok("A Shatter's ring at 0.5", singles(), 20, KING, 6, 2)
reset()
grug_core.particles.play("enrage", {target = KING})
eq(spawners()[1] and spawners()[1].amount, 48, "A enrage's 96 at 0.5")
grug_core.particles = helper("0")
reset()
for _, id in ipairs(PM_IDS) do grug_core.particles.play(id, FRAME) end
eq(#calls, 0, "A grug_particle_scale 0 plays no boss or mob effect")
grug_core.particles = helper(nil)

------------------------------------------------------------------------------
-- B: the kings and Generals.
------------------------------------------------------------------------------
local function cut(text, from, to, label)
	local a = text:find(from, 1, true)
	local b = a and text:find(to, a, true)
	assert(a and b, "cut " .. label)
	return text:sub(a, b + #to - 1)
end
local function cut_before(text, from, to, label)
	local a = text:find(from, 1, true)
	local b = a and text:find(to, a, true)
	assert(a and b, "cut " .. label)
	return text:sub(a, b - 1)
end
local bosses_src = read(MOBS .. "bosses.lua")
local stamped = 0
local boss_env = setmetatable({
	grug_mobs = {
		stamp_arrow_damage = function() stamped = stamped + 1 end,
		stamp_straight_arrow = function() stamped = stamped + 1 end,
		place_on_ground = function(object, pos) object:set_pos(pos) end,
		royal_encounter_reset = function() end,
	},
	grug_sounds = {play = function() end},
}, {__index = _G})
local boss_chunk = assert(loadstring(table.concat({
	"local function player_enemy_of() return true end\n",
	cut(bosses_src, "local RACES = {", "\n}\n", "RACES"),
	cut(bosses_src, "local function shoot(self, target, arrow, offset_angle)", "\nend\n", "shoot"),
	cut(bosses_src, "local function hit_players(", "\nend\n", "hit_players"),
	cut(bosses_src, "local function royal_objects(", "\nend\n", "royal_objects"),
	cut_before(bosses_src, "local BONE_CALL_CAP = 4", "local function king_def(", "signature"),
	"return king_tick\n",
}), "=bosses part"))
setfenv(boss_chunk, boss_env)
local king_tick = boss_chunk()

local function new_king(race, yaw)
	local king = {health = 100, hp_max = 100, damage = 10, temp = {grug_royal_cooldown = 0}}
	new_object(KING, king)
	king.object.yaw = yaw or 0
	king.set_velocity = function() end
	king.set_animation = function() end
	return king
end
-- Runs a cast: the start tick, then `steps` ticks of 0.1 s; returns the ids
-- played at the start, through the first second, after it and at the end.
local function cast(race, setup)
	players, objects = {}, {}
	local target = new_player("target", vec(0, 5, 3))
	local king = new_king(race)
	king.attack = target
	if setup then setup(king) end
	reset()
	king_tick(king, 0.1, race)
	local start = ids()
	reset()
	for _ = 1, 8 do king_tick(king, 0.1, race) end
	local early = ids()
	reset()
	king_tick(king, 0.1, race)
	king_tick(king, 0.1, race)
	local half = ids()
	reset()
	for _ = 1, 8 do king_tick(king, 0.1, race) end
	local late = ids()
	reset()
	for _ = 1, 3 do king_tick(king, 0.1, race) end
	return start, early, half, late, ids(), king, target
end

do
	reset()
	players, objects = {}, {}
	local idle = new_king("dwarf")
	idle.temp.grug_royal_cooldown = 5
	idle.attack = new_player("t", vec(0, 5, 3))
	king_tick(idle, 0.1, "dwarf")
	eq(ids(), "", "B no wind-up while the signature cools down")
end

-- Shatter: the ring once at the start, the burst at the resolve.
do
	local start, early, half, late
	start, early, half, late = cast("dwarf")
	local resolve = ids()
	local burst = plays_of("king_shatter")[1]
	eq(burst and burst.frame.reach, 6, "B Shatter: the burst reaches the blast radius")
	eq(start, "king_windup_ring", "B Shatter: the ring at the cast's start")
	ring_ok("B Shatter's ring", (function()
		reset()
		players, objects = {}, {}
		local k = new_king("dwarf")
		k.attack = new_player("t", vec(0, 5, 3))
		king_tick(k, 0.1, "dwarf")
		return singles()
	end)(), 40, KING, 6, 2)
	eq(early .. half .. late, "", "B Shatter: nothing more during the wind-up")
	eq(resolve, "king_shatter", "B Shatter: the burst at the resolve")
end

-- Cleave: a spawner at the start and one halfway, the arc on the hit along
-- the king's facing (yaw 0: +z).
do
	local start, early, half, late, _, king = cast("orc")
	eq(start, "king_cleave_windup", "B Cleave: the cone lights up at the start")
	eq(early, "", "B Cleave: nothing until the second second")
	eq(half, "king_cleave_windup", "B Cleave: the second 1 s spawner halfway")
	eq(late, "", "B Cleave: nothing more before the hit")
	local resolve = plays_of("king_cleave")
	eq(#resolve, 1, "B Cleave: the arc once on the hit")
	local arc = spawners()[1]
	if check(arc and arc.pos_tween, "B Cleave: the arc is a tweened line") then
		near(arc.pos_tween[1].z - king.object.pos.z, 3.5, "B Cleave: the arc lies ahead of the king")
		near(arc.pos_tween[1].x - king.object.pos.x, 2, "B Cleave: the arc starts on the king's right")
		near(arc.pos_tween[2].x - king.object.pos.x, -2, "B Cleave: the arc ends on the king's left")
	end
end

-- The auras: a 1 s spawner at the start and one halfway, in the kit's colour.
for _, case in ipairs({{"human", "#e8c06a"}, {"elf", "#e6eef0"}, {"undead", "#9aa88a"},
		{"troll", "#7ac943"}}) do
	local race, colour = case[1], case[2]
	local start, early, half, late = cast(race)
	eq(start, "king_aura", "B " .. race .. ": the aura at the start")
	eq(early, "", "B " .. race .. ": nothing until the second second")
	eq(half, "king_aura", "B " .. race .. ": the second aura spawner halfway")
	eq(late, "", "B " .. race .. ": nothing more before the resolve")
end
do
	players, objects = {}, {}
	local king = new_king("troll")
	king.attack = new_player("t", vec(0, 5, 3))
	reset()
	king_tick(king, 0.1, "troll")
	local s = spawners()[1]
	check(s and s.texture.name:find("#7ac943", 1, true) ~= nil, "B Regrowth's aura is green")
	eq(s and s.time, 1, "B the aura spawner lives 1 s")
end

-- Rally: a rise on each rallied guard (at most four), at its new place.
do
	local guards = {}
	local _, _, _, _, resolve = cast("human", function(king)
		for i = 1, 5 do
			local guard = {_grug_boss_id = "king:human", health = 50, hp_max = 100}
			objects[#objects + 1] = new_object(vec(i, 5, -3), guard)
			guards[i] = guard
		end
		king._grug_boss_id = "king:human"
	end)
	eq(resolve, "king_resolve,king_resolve,king_resolve,king_resolve",
		"B Rally: a rise on four of five rallied guards")
	local first = plays_of("king_resolve")[1]
	check(first and vector.distance(first.frame.target, guards[1].object.pos) < 1e-9,
		"B Rally: the rise at the guard's new place")
	eq(first and first.frame.color, "#e8c06a", "B Rally: gold")
end
-- Bone Call: a rise at each raider it summoned; none at the cap.
do
	local _, _, _, _, resolve = cast("undead", function(king) king._grug_boss_id = "king:undead" end)
	eq(resolve, "king_resolve,king_resolve", "B Bone Call: a rise at each of two raiders")
	local _, _, _, _, capped = cast("undead", function(king)
		king._grug_boss_id = "king:undead"
		for i = 1, 4 do
			objects[#objects + 1] = new_object(vec(i, 5, 2),
				{_grug_royal_summon = "king:undead", health = 10})
		end
	end)
	eq(capped, "", "B Bone Call at its cap summons none and shows none")
end
-- Regrowth: on the troll when it heals, none when hurt during the wind-up.
do
	local _, _, _, _, resolve, king = cast("troll")
	eq(resolve, "king_resolve", "B Regrowth: a rise on the troll")
	check(plays_of("king_resolve")[1] and
		vector.distance(plays_of("king_resolve")[1].frame.target, king.object.pos) < 1e-9,
		"B Regrowth: the rise at the troll")
	players, objects = {}, {}
	local hurt = new_king("troll")
	hurt.attack = new_player("t", vec(0, 5, 3))
	king_tick(hurt, 0.1, "troll")
	hurt.health = 80
	reset()
	for _ = 1, 25 do king_tick(hurt, 0.1, "troll") end
	eq(#plays_of("king_resolve"), 0, "B Regrowth hurt during the wind-up shows nothing")
end
-- Volley: the three arrows, no resolve effect.
do
	stamped = 0
	local _, _, _, _, resolve = cast("elf")
	eq(resolve, "", "B Volley shows no resolve effect")
	eq(stamped, 3, "B Volley shot its three arrows")
end

------------------------------------------------------------------------------
-- C: the elite wind-up and cone hit (telegraph.lua).
------------------------------------------------------------------------------
grug_mobs = {
	tier_telegraphs = function(tier) return tier == "elite" end,
	root = function() end,
}
grug_sounds = {play = function() end}
dofile(ROOT .. "/" .. MOBS .. "telegraph.lua")
local function elite_fight(step_out)
	players, objects = {}, {}
	local target = new_player("target", vec(0, 5, 2))
	local elite = {_grug_tier = "elite", state = "attack", attack = target, reach = 3, damage = 10,
		temp = {}, update_tag = function() end}
	new_object(vec(0, 5, 0), elite)
	reset()
	for _ = 1, 35 do grug_mobs.telegraph_tick(elite, 0.1) end
	local before = ids()
	reset()
	for _ = 1, 20 do
		grug_mobs.telegraph_tick(elite, 0.1)
		if #played > 0 then break end
	end
	local windup = ids()
	reset()
	if step_out then target.pos = vec(3, 5, 0) end
	for _ = 1, 17 do grug_mobs.telegraph_tick(elite, 0.1) end
	local during = ids()
	reset()
	for _ = 1, 5 do grug_mobs.telegraph_tick(elite, 0.1) end
	return before, windup, during, ids(), target
end
do
	local before, windup, during, resolve, target = elite_fight(false)
	eq(before, "", "C nothing during the first seconds of melee")
	eq(windup, "elite_windup", "C the smoke at the wind-up")
	eq(during, "", "C nothing during the wind-up")
	eq(resolve, "elite_cone", "C the arc at the cone hit")
	eq(target.punched, 1, "C the player in the cone is hit")
	local arc = plays_of("elite_cone")[1]
	eq(arc and arc.frame.reach, 3, "C the arc at the elite's reach")
	local _, _, _, dodged, out = elite_fight(true)
	eq(dodged, "elite_cone", "C the arc also when the player stepped out")
	eq(out.punched, nil, "C ... who is not hit")
end

------------------------------------------------------------------------------
-- D: the dragons (boss_dragons.lua).
------------------------------------------------------------------------------
local ARENA = {x = 0, y = 10, z = 0, radius = 40}
local dragon_defs, arrow_defs = {}, {}
players, objects = {}, {}
grug_core.register_on_effective_heal = function() end
grug_core.register_on_effective_absorb = function() end
grug_core.clear_status = function() end
grug_core.disengage_target = function() end
grug_core.ground_effect_protected = function() return false end
grug_core.mark_in_combat = function() end
grug_core.set_status = function() end
grug_core.feed = function() return true end
mobs = {has_priv = function() return false end}
grug_mobs = {
	names = dofile(ROOT .. "/tools/r38_b1/names_stub.lua").shipped(ROOT),
	register_homing_arrow = function(name, def) arrow_defs[name] = def end,
	register_mob = function(name, def) dragon_defs[name] = def end,
	scale_attack_damage = function(v) return v end,
	slow_player = function() end,
	stamp_arrow_damage = function() end,
	stamp_straight_arrow = function() end,
	leash_reset = function() end,
}
dofile(ROOT .. "/" .. MOBS .. "boss_dragons.lua")
grug_mobs.register_dragon_bosses({
	arena = function() return ARENA end,
	storage = {set_string = function() end},
	settle = function() end,
	player_enemy_of = function() return true end,
	respawn = 1800,
})
local T = grug_mobs.DRAGON_TUNING
local function new_dragon(name)
	local d = {hp_max = 100000, health = 100000, damage = 50, fly = false,
		_grug_boss_id = "dragon:x", run_velocity = 6.5}
	new_object(vec(ARENA.x, ARENA.y, ARENA.z), d)
	d.set_animation = function() end
	d.yaw_to_pos = function() end
	d.stop_attack = function(self) self.attack = nil end
	d.name = name
	return d
end
local function tick(d, n, dt)
	local def = dragon_defs[d.name]
	for _ = 1, n or 1 do def.do_custom(d, dt or 0.1, {}) end
end
local ICE, STORM = "grug_mobs:ice_dragon", "grug_mobs:jungle_wyvern"

-- The breath: the wind-up at the launch point, the burst at the release.
do
	players, objects = {}, {}
	local target = new_player("near", vec(4, 10, 0))
	local d = new_dragon(ICE)
	d.attack = target
	tick(d)
	local st = d.temp.grug_dragon
	st.gust, st.primary = 99, 0
	reset()
	tick(d)
	eq(ids(), "breath_windup", "D the breath winds up with its gathering motes")
	local w = plays_of("breath_windup")[1]
	check(w and w.frame.caster.y == ARENA.y + 5 and w.frame.caster.x == ARENA.x,
		"D the motes gather at the launch point (eye height 5)")
	eq(w and w.frame.color, "#8ee8ff", "D frost-blue for the ice dragon")
	reset()
	tick(d, 11)
	eq(ids(), "", "D nothing more during the wind-up")
	reset()
	tick(d, 2)
	eq(ids(), "breath_burst_rime", "D the muzzle burst at the release")
	eq(spawners()[1] and spawners()[1].amount, 54, "D the muzzle burst keeps its 54 motes")
end

-- The trail: 12 motes per bolt, spread over 1.44 s; 6 at 0.5, none at 0.
local function trail(scale)
	grug_core.particles = helper(scale)
	local bolt = {_grug_effect = "scorch"}
	new_object(vec(0, 20, 0), bolt)
	reset()
	for _ = 1, 60 do arrow_defs["grug_mobs:storm_breath"].do_custom(bolt, 0.05) end
	local n = #plays_of("breath_trail")
	local first = singles()[1]
	grug_core.particles = helper(nil)
	return n, first
end
do
	local n, first = trail(nil)
	eq(n, 12, "D twelve trail motes per bolt")
	check(first and first.texture.name:find("#ff7338", 1, true) ~= nil, "D the storm bolt's trail is fire")
	eq(trail("0.5"), 6, "D six at grug_particle_scale 0.5")
	eq(trail("0"), 0, "D none at 0")
	eq(T.trail_particles * (T.trail_span / T.trail_particles), T.trail_span, "D the trail's span")
end

-- The lightning: the ring at the wind-up, the strike at the impact.
do
	players, objects = {}, {}
	local target = new_player("struck", vec(5, 10, 0))
	local d = new_dragon(STORM)
	d.attack = target
	tick(d)
	local st = d.temp.grug_dragon
	st.gust, st.primary, st.lightning_next = 99, 0, true
	reset()
	tick(d)
	eq(ids(), "lightning_ring", "D the lightning ring at the wind-up")
	ring_ok("D the lightning ring", singles(), 32, target.pos, 2, T.lightning_windup)
	reset()
	tick(d, 14)
	eq(ids(), "", "D nothing more during the lightning wind-up")
	reset()
	tick(d, 2)
	eq(ids(), "lightning_strike", "D the strike at the impact")
	check(vector.distance(plays_of("lightning_strike")[1].frame.target, target.pos) < 1e-9,
		"D the strike on the snapshot")
	eq(target.punched, 1, "D the struck player is hit")
end

-- The gust: the warning ring, then the release ring.
do
	players, objects = {}, {}
	local target = new_player("gusted", vec(4, 10, 0))
	local d = new_dragon(ICE)
	d.attack = target
	tick(d)
	local st = d.temp.grug_dragon
	st.gust, st.primary = 0, 0.5
	reset()
	tick(d)
	eq(ids(), "gust_windup", "D the gust's warning ring")
	ring_ok("D the gust ring", singles(), 40, d.object.pos, T.gust_radius, T.gust_windup)
	reset()
	tick(d, 12)
	eq(ids(), "", "D nothing during the gust's wind-up")
	reset()
	tick(d)
	eq(ids(), "gust_release", "D the release ring")
	lands_ok("D the release ring", singles(), d.object.pos, T.gust_radius)
end

-- The dive: take-off dust, the wind-up, the slam.
do
	players, objects = {}, {}
	local target = new_player("dived", vec(15, 10, 0))
	local close = new_player("close", vec(3, 10, 0))
	local d = new_dragon(ICE)
	d.attack = target
	reset()
	tick(d)
	eq(ids(), "dragon_takeoff", "D the take-off dust")
	local st = d.temp.grug_dragon
	st.primary, st.gust = 99, 99
	reset()
	tick(d)
	eq(ids(), "", "D no more dust in flight")
	st.primary = 0
	reset()
	tick(d)
	eq(ids(), "dive_windup", "D the dive's wind-up")
	reset()
	for _ = 1, 50 do
		if not st.action then break end
		tick(d)
	end
	eq(ids(), "dive_slam", "D the slam once")
	eq(close.punched, 1, "D the slam hit")
	lands_ok("D the slam ring", singles(), d.object.pos, 7)
end

-- Enrage: once, with a puff per whelp.
do
	players, objects = {}, {}
	local target = new_player("enraged", vec(4, 10, 0))
	local d = new_dragon(ICE)
	d.attack = target
	tick(d)
	local st = d.temp.grug_dragon
	st.primary, st.gust = 99, 99
	d.health = 40000
	reset()
	tick(d)
	eq(ids(), "enrage,whelp_arrival,whelp_arrival", "D enrage and a puff per whelp")
	reset()
	tick(d, 5)
	eq(ids(), "", "D enrage only once")
end

-- A breath patch on the ground.
do
	node_at = function(pos) return pos.y >= 11 and "air" or "default:stone" end
	reset()
	arrow_defs["grug_mobs:ice_breath"].hit_node({_grug_effect = "rime"}, vec(2, 10.5, 2))
	eq(ids(), "dragon_patch_rime", "D a rime patch bursts")
	node_at = function() return "air" end
end

------------------------------------------------------------------------------
-- E: the mob specials.
------------------------------------------------------------------------------
players, objects = {}, {}
local mob_defs = {}
arrow_defs = {}
local modifiers, statuses = {}, {}
grug_core.get_move_modifier = function(player, name) return modifiers[player.name .. name] end
grug_core.set_move_modifier = function(player, name, mod) modifiers[player.name .. name] = mod end
grug_core.get_status = function() return nil end
grug_core.set_status = function(player, id) statuses[#statuses + 1] = id end
grug_core.clear_status = function() end
grug_core.mono_time = function() return mono end
grug_core.invalidate_combat_identity = function() end
local homing_result = {}
grug_core.homing_step = function() return homing_result.dest, homing_result.arrived end
mobs = {
	has_priv = function() return false end,
	is_invisible = function() return false end,
	spawn = function() end,
}
function mobs:register_arrow(name, def)
	arrow_defs[name] = def
	core.registered_entities[name] = {initial_properties = {}}
end
grug_mobs = {
	register_mob = function(name, def) mob_defs[name] = def end,
	scale_attack_damage = function(v) return v end,
	camp_swarm = function() end,
	atlas_textures = function(texture) return texture end,
}
grug_zones = {water_class_at = function() return "deep_ocean" end}
dofile(ROOT .. "/" .. MOBS .. "verbs.lua")
for _, file in ipairs({"spider.lua", "oerkki.lua", "night_families.lua", "kraken.lua",
		"bog_ooze.lua", "bog_witch.lua"}) do
	dofile(ROOT .. "/" .. MOBS .. file)
end

-- Webs: from a spider's bite, not from a plain slow.
do
	local p = new_player("bitten", vec(0, 0, 1))
	reset()
	grug_mobs.slow_player(p, 3, 0.6)
	eq(ids(), "", "E a plain slow spins no web")
	local spider = {attack = p}
	reset()
	check(mob_defs["grug_mobs:giant_spider"].custom_attack(spider, spider, p:get_pos()) == true,
		"E the spider's bite still lands its melee")
	eq(ids(), "web", "E the spider's bite spins a web")
	local list = singles()
	eq(#list, 8, "E eight strands")
	check(list[1] and list[1].pos.y >= p.pos.y + 0.2 and list[1].pos.y <= p.pos.y + 0.6,
		"E the strands at the legs")
	check(read(MOBS .. "zero_asset_variants.lua"):find(
		"grug_mobs.slow_player(target, 2, 0.8)\n\tgrug_mobs.web_particles(target)", 1, true) ~= nil,
		"E the spiderling's bite spins a web too")
end

-- Poison: on the application, two on each tick, none once dead.
do
	after_queue = {}
	local p = new_player("poisoned", vec(0, 0, 0))
	reset()
	grug_mobs.poison_player(p, 3, 2, 1)
	eq(ids(), "poison", "E poison bubbles on the application")
	eq(#singles(), 6, "E six bubbles")
	reset()
	local job = table.remove(after_queue, 1)
	job[2]()
	eq(ids(), "poison_tick", "E two bubbles on a tick")
	eq(#singles(), 2, "E two")
	p.hp = 0
	reset()
	job = table.remove(after_queue, 1)
	job[2]()
	eq(ids(), "", "E no bubbles on a dead player")
end

-- Pounce: dust at the take-off, once where it lands.
local function stalker_mob()
	local def = {}
	grug_mobs.stalker(def, {})
	local target = new_player("prey", vec(6, 0, 0))
	local mob = {state = "attack", attack = target, temp = {}}
	new_object(vec(0, 0, 0), mob)
	return def, mob
end
do
	players = {}
	local def, mob = stalker_mob()
	reset()
	def.do_custom(mob, 1, {touching_ground = true})
	eq(ids(), "pounce", "E the take-off dust")
	local p = played[1]
	check(p and p.frame.caster and not p.frame.target, "E ... at the take-off only")
	eq(#singles(), 6, "E six motes at the take-off")
	reset()
	def.do_custom(mob, 0.05, {touching_ground = true})
	eq(ids(), "", "E no landing before it left the ground")
	def.do_custom(mob, 0.05, {touching_ground = false})
	def.do_custom(mob, 0.05, {touching_ground = false})
	eq(ids(), "", "E nothing in the air")
	mob.object.pos = vec(5, 0, 0)
	def.do_custom(mob, 0.05, {touching_ground = true})
	eq(ids(), "pounce", "E the landing dust")
	check(played[1] and played[1].frame.target and not played[1].frame.caster and
		played[1].frame.target.x == 5, "E ... where it landed")
	reset()
	def.do_custom(mob, 0.05, {touching_ground = false})
	def.do_custom(mob, 0.05, {touching_ground = true})
	eq(ids(), "", "E one landing per pounce")
	-- No landing within the window: none.
	players = {}
	def, mob = stalker_mob()
	def.do_custom(mob, 1, {touching_ground = true})
	reset()
	mono = mono + 3
	def.do_custom(mob, 0.05, {touching_ground = false})
	def.do_custom(mob, 0.05, {touching_ground = true})
	eq(ids(), "", "E no landing dust after the window")
	mono = 100
end

-- Ambush: once when it breaks cover, a splash in water, dirt on land.
local function ambush(node)
	players = {}
	node_at = function() return node end
	local def = {}
	grug_mobs.ambusher(def, {})
	local mob = {temp = {}, order = "stand"}
	new_object(vec(0, 0, 0), mob)
	mob.state, mob.attack = "attack", new_player("wader", vec(2, 0, 0))
	reset()
	def.do_custom(mob, 0.05)
	def.do_custom(mob, 0.05)
	node_at = function() return "air" end
	return ids(), played[1]
end
do
	local list, first = ambush("default:water_source")
	eq(list, "ambush", "E the ambush once when it breaks cover")
	eq(first and first.frame.color, nil, "E a splash in water (the card's colour)")
	local _, dirt = ambush("air")
	eq(dirt and dirt.frame.color, "#8a7350", "E a dirt burst on land")
	-- No cover to break: nothing.
	local def = {}
	grug_mobs.ambusher(def, {})
	local mob = {temp = {}, order = "", state = "attack", attack = new_player("w", vec(1, 0, 0))}
	new_object(vec(0, 0, 0), mob)
	reset()
	def.do_custom(mob, 0.05)
	eq(ids(), "", "E no ambush without a lurk")
end

-- The ooze aura: only on a tick that hurts someone.
do
	players = {}
	local ooze_def = mob_defs["grug_mobs:bog_ooze"]
	local ooze = {temp = {}}
	new_object(vec(0, 0, 0), ooze)
	reset()
	ooze_def.do_custom(ooze, 1)
	eq(ids(), "", "E no bubbles with nobody in the aura")
	local p = new_player("engulfed", vec(1, 0, 0))
	reset()
	ooze_def.do_custom(ooze, 0.5)
	eq(ids(), "", "E none between ticks")
	ooze_def.do_custom(ooze, 0.5)
	eq(ids(), "ooze_aura", "E bubbles on a tick that hurt someone")
	eq(p.punched, 1, "E ... who was hit")
	local list = singles()
	local inside = #list == 5
	for _, d in ipairs(list) do if horizontal(d.pos, ooze.object.pos) > 2 + 1e-9 then inside = false end end
	check(inside, "E five bubbles within the 2 m aura")
	p.hp = 0
	reset()
	ooze_def.do_custom(ooze, 1)
	eq(ids(), "", "E none when only a dead player stands in it")
end

-- The treant aura: while it slows someone, every second tick.
do
	players = {}
	local treant_def = mob_defs["grug_mobs:ashen_treant"]
	local treant = {temp = {}, _grug_cbox = {-0.3, -1, -0.3, 0.3, 0.75, 0.3}}
	new_object(vec(0, 1, 0), treant)
	reset()
	treant_def.do_custom(treant, 1)
	eq(ids(), "", "E no leaves with nobody slowed")
	new_player("slowed", vec(1, 0, 0))
	reset()
	treant_def.do_custom(treant, 1)
	local first = ids()
	treant_def.do_custom(treant, 1)
	treant_def.do_custom(treant, 1)
	treant_def.do_custom(treant, 1)
	eq(first, "treant_aura", "E leaves on the first tick that slows")
	eq(ids(), "treant_aura,treant_aura", "E ... and on every second tick")
	check(played[1] and played[1].frame.target.y == 0, "E the leaves fall around the treant's feet")
	players = {}
	reset()
	treant_def.do_custom(treant, 1)
	treant_def.do_custom(treant, 1)
	eq(ids(), "", "E no leaves once nobody is slowed")
end

-- The blinks: a puff at the origin and the arrival; none when it fails.
local function blink(name, key, node)
	players = {}
	node_at = function() return node end
	local def = mob_defs[name]
	local mob = {state = "attack", temp = {[key] = 10}, attack = new_player("t", vec(10, 0, 0))}
	new_object(vec(0, 0, 0), mob)
	reset()
	def.do_custom(mob, 0)
	node_at = function() return "air" end
	return ids(), played[1], mob
end
do
	local list, p, mob = blink("grug_mobs:oerkki", "grug_oerkki_blink", "air")
	eq(list, "oerkki_blink", "E the Oerkki's blink")
	check(p and p.frame.caster.x == 0 and p.frame.target.x == mob.object.pos.x and mob.object.pos.x > 0,
		"E ... at the origin and the arrival")
	local s = spawners()
	check(#s == 2 and s[1].pos.min.x < 0.5 and s[2].pos.min.x > 2, "E a puff at each end")
	eq(blink("grug_mobs:oerkki", "grug_oerkki_blink", "default:stone"), "",
		"E no puff when the Oerkki cannot blink")
	list, p, mob = blink("grug_mobs:wisp", "grug_wisp_blink", "air")
	eq(list, "wisp_blink", "E the Wisp's blink")
	eq(#singles(), 10, "E five pale motes at each end")
	check(p and p.frame.caster.x == 0 and p.frame.target.x == mob.object.pos.x, "E ... origin and arrival")
	eq(blink("grug_mobs:wisp", "grug_wisp_blink", "default:water_source"), "",
		"E no puff when the Wisp cannot blink")
end

-- The Kraken's drag: bubbles at the dragged player, also on a carrier.
do
	players = {}
	local p = new_player("swimmer", vec(3, 1, 0))
	local kraken = {attack = p}
	reset()
	check(mob_defs["grug_mobs:kraken"].custom_attack(kraken) == true, "E the drag keeps the melee")
	eq(ids(), "kraken_drag", "E bubbles on the drag")
	check(vector.distance(played[1].frame.target, p.pos) < 1e-9, "E ... at the dragged player")
	local boat = new_object(vec(3, 0, 0))
	p.attach = boat
	reset()
	mob_defs["grug_mobs:kraken"].custom_attack(kraken)
	check(boat.added ~= nil and played[1] and vector.distance(played[1].frame.target, p.pos) < 1e-9,
		"E a carrier is dragged, the bubbles stay at the player")
	p.attach = nil
	reset()
	mob_defs["grug_mobs:kraken"].custom_attack({attack = nil})
	eq(ids(), "", "E no drag without a target")
end

-- The hex bottle.
do
	players = {}
	local p = new_player("hexed", vec(1, 0, 1))
	reset()
	arrow_defs["grug_mobs:hex_bottle"].hit_player({object = new_object(vec(1, 1, 1))}, p)
	check(ids():find("hex_bottle", 1, true) ~= nil, "E the hex bottle's puff")
end

-- Projectile impacts.
do
	grug_mobs.register_simple_arrow("test:tinted", {texture = "x.png", impact = "#123456"})
	grug_mobs.register_simple_arrow("test:plain", {texture = "x.png"})
	players = {}
	local p = new_player("shot", vec(0, 0, 5))
	local function homing(name, dest, arrived)
		local arrow = {_grug_lock = {target = p, duration = 1, age = 0}}
		new_object(vec(0, 1, 4.6), arrow)
		homing_result = {dest = dest, arrived = arrived}
		reset()
		arrow_defs[name].on_step(arrow, 0.05)
		return ids(), played[1], arrow
	end
	local list, hit, arrow = homing("test:tinted", vec(0, 1, 5), true)
	eq(list, "projectile_impact", "E a homing arrival puffs")
	eq(hit and hit.frame.color, "#123456", "E ... in the projectile's tint")
	check(hit and vector.distance(hit.frame.caster, arrow.object.pos) < 1e-9, "E ... where the projectile is")
	eq(#singles(), 5, "E five motes")
	eq(p.punched, 1, "E the arrival hit")
	eq(homing("test:plain", vec(0, 1, 5), true), "", "E a projectile without a tint shows none")
	eq(homing("test:tinted", vec(0, 1, 5), false), "", "E nothing in flight")
	eq(homing("test:tinted", nil, nil), "", "E nothing on a lost lock")
	-- A straight side shot into a wall, then into a player.
	local function straight(ray_hit)
		local arrow = {_grug_straight = true, timer = 0, lifetime = 4,
			_grug_source = new_object(vec(0, 0, -10), {}), _grug_last = vec(0, 1, 0)}
		new_object(vec(0, 1, 1), arrow)
		core.raycast = function()
			local done = not ray_hit
			return function()
				if done then return nil end
				done = true
				return {type = "node", under = vec(0, 1, 1), above = vec(0, 1, 0),
					intersection_point = vec(0, 1, 0.5)}
			end
		end
		reset()
		arrow_defs["test:tinted"].on_step(arrow, 0.05)
		core.raycast = function() return function() return nil end end
		return ids(), played[1]
	end
	node_at = function() return "default:stone" end
	players = {}
	local wall, at = straight(true)
	node_at = function() return "air" end
	eq(wall, "projectile_impact", "E a straight shot into a wall puffs")
	check(at and at.frame.caster.z == 0.5, "E ... at the wall")
	players = {}
	local victim = new_player("bystander", vec(0, 0, 0.6))
	local body = straight(false)
	eq(body, "projectile_impact", "E a straight shot into a player puffs")
	eq(victim.punched, 1, "E ... and hits")
end

-- The scale reaches the mob effects: half at 0.5, none at 0.
do
	grug_core.particles = helper("0.5")
	players = {}
	local p = new_player("half", vec(0, 0, 0))
	reset()
	grug_mobs.web_particles(p)
	eq(#singles(), 4, "E a web's eight strands at 0.5")
	grug_core.particles = helper("0")
	reset()
	grug_mobs.web_particles(p)
	grug_mobs.poison_player(p, 1, 1, 1)
	eq(#calls, 0, "E none at 0")
	grug_core.particles = helper(nil)
end

------------------------------------------------------------------------------
-- F: the scan.
------------------------------------------------------------------------------
P = grug_core.particles
local MOB_FILES = {"bosses.lua", "telegraph.lua", "boss_dragons.lua", "kraken.lua", "verbs.lua",
	"spider.lua", "zero_asset_variants.lua", "oerkki.lua", "night_families.lua", "bog_ooze.lua",
	"bog_witch.lua", "rift_spawn.lua", "rift.lua", "crocodile.lua", "panther.lua"}
local seen = 0
for _, file in ipairs(MOB_FILES) do
	local text = read(MOBS .. file)
	for id in text:gmatch('particles%.play%("([%w_]+)"[,)]') do
		seen = seen + 1
		check(P.registered(id) ~= nil, "F " .. file .. " plays a catalogue effect: " .. id)
	end
	for id in text:gmatch('effect = "([%w_]+)"}') do
		seen = seen + 1
		check(P.registered(id) ~= nil, "F " .. file .. " names a catalogue effect: " .. id)
	end
end
check(seen >= 25, "F the scan found grug_mobs' effect calls (" .. seen .. ")")
for _, effect in ipairs({"rime", "scorch"}) do
	check(P.registered("breath_burst_" .. effect) ~= nil, "F the " .. effect .. " breath's burst")
end
for _, file in ipairs({"skeleton_archer.lua", "golem.lua", "crystal_shard.lua", "ember_wisp.lua",
		"dungeon_master.lua", "rift.lua"}) do
	check(read(MOBS .. file):find('impact = "#%x%x%x%x%x%x"') ~= nil,
		"F " .. file .. "'s projectile carries an impact tint")
end
-- The files that called the engine directly before this lane: what is left
-- are the rift's per-player stretches and its pulse (unchanged, rift.lua),
-- the dragon's 8 s return warning (bosses.lua) and the arrow tail
-- (verbs.lua).
local KNOWN = {["bosses.lua"] = 1, ["rift.lua"] = 2, ["verbs.lua"] = 1, ["boss_dragons.lua"] = 0,
	["telegraph.lua"] = 0, ["oerkki.lua"] = 0, ["bog_witch.lua"] = 0, ["rift_spawn.lua"] = 0}
for file, expected in pairs(KNOWN) do
	local n = 0
	for _ in read(MOBS .. file):gmatch("core%.add_particle") do n = n + 1 end
	eq(n, expected, "F direct particle calls in " .. file)
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error("R40 PM PORTABLE FAIL")
end
print("R40 PM PORTABLE PASS checks=" .. checks)
