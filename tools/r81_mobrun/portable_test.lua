-- Round 81 lane MOBRUN portable test (round81-plan.md §4 "MOBRUN", ruling 7;
-- audit findings X4-04, MOB1-02, MOB1-03, MOB1-04, MOB1-06, MOB3-01, MOB3-02,
-- MOB3-03, X4-12). Real code on a small fake engine; where a whole file needs
-- too much of the engine, its piece is cut out of the real source:
--   M  measurements, printed (they also run on the base commit:
--      MEASURE_ONLY=1 stops after them): the sight rays of a mob in the
--      attack state (api.lua's attack-state sight and strike, cut out, over
--      the REAL grug_obstacle.lua) and the engine calls of the ambusher, the
--      ooze aura (verbs.lua, cut out) and the stuck snap's watch (patrol.lua
--      `unwatched`) at 100 players;
--   S  X4-04: a ray at most every third step; a strike and a fuse never take
--      a reused answer (a wall that appears blocks the very next strike); a
--      new target casts at once;
--   T  MOB1-02 (ruling 7): the REAL telegraph.lua winds up against a player,
--      never against a mob, and a switch to a player starts the engagement
--      clock afresh;
--   L  MOB3-01: bosses.lua's hit hook and encounter death (cut out): a hit
--      on a whelp joins its dragon's ledger, a whelp's kill gives the grace;
--   P  MOB1-03: aggro.lua's prototype publication and activation cleanup and
--      init.lua's speed effects (cut out): definition values stay off the
--      instance, a different value (a spawner's, the Kraken's) stays;
--   K  MOB1-04, MOB3-02: the stun branch is gone from the do_custom wrapper;
--      the enraged glow is written once per activation;
--   R  MOB3-03: the rift effects on the REAL particle helper and catalogue
--      (1 s spawners, never private, off at grug_particle_scale 0), rift.lua
--      calls no spawner of its own;
--   W  MOB1-06, X4-12: the snap's watch, the ambusher and the aura answer
--      from the player snapshot as before.
-- Usage (repo root): luajit tools/r81_mobrun/portable_test.lua [REPO]
-- Prints "R81 MOBRUN PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local measure_only = os.getenv("MEASURE_ONLY") == "1"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
	return ok
end
local function eq(got, want, label)
	return check(got == want, label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(text, from, to, label)
	local a = text:find(from, 1, true)
	assert(a, label .. ": start anchor")
	local _, e = text:find(to, a, true)
	assert(e, label .. ": end anchor")
	return text:sub(a, e)
end
local function load_in(source, env, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end
local function noop() end

vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x or 0, y = y or 0, z = z or 0}
end
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(a, s) return vector.new(a.x * s, a.y * s, a.z * s) end
function vector.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
local vec = vector.new

-- The engine calls the measurements count.
local calls = {}
local function count(name) calls[name] = (calls[name] or 0) + 1 end
local function reset_calls() calls = {} end

-- Players: a position, hp, punches taken.
local players = {}
local function new_player(name, pos)
	local p = {name = name, pos = vec(pos), hp = 20, punched = 0}
	function p:get_pos() count("get_pos"); return vec(self.pos) end
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_luaentity() return nil end
	function p:get_attach() return nil end
	function p:get_properties() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3}} end
	function p:punch() self.punched = self.punched + 1 end
	players[#players + 1] = p
	return p
end
-- Non-player objects an object query returns (mobs, items).
local objects = {}
local function new_object(pos)
	local o = {pos = vec(pos)}
	function o:is_player() return false end
	function o:get_pos() return vec(self.pos) end
	objects[#objects + 1] = o
	return o
end

core = {
	registered_entities = {},
	get_connected_players = function() count("get_connected_players"); return players end,
	get_objects_inside_radius = function(pos, radius)
		count("get_objects_inside_radius")
		local out = {}
		for _, list in ipairs({players, objects}) do
			for _, o in ipairs(list) do
				if vector.distance(o.pos, pos) <= radius then out[#out + 1] = o end
			end
		end
		calls.objects_returned = (calls.objects_returned or 0) + #out
		return out
	end,
	is_player = function(o) return type(o) == "table" and o.is_player ~= nil and o:is_player() end,
	get_node_or_nil = function() return {name = "air"} end,
	registered_nodes = {air = {liquidtype = "none"}},
	line_of_sight = function() return true end,
	yaw_to_dir = function(yaw) return vec(-math.sin(yaw), 0, math.cos(yaw)) end,
	log = noop,
	after = function(_, fn, ...) fn(...) end,
}
-- grug_core's player snapshot (tag_carrier.lua), here the live list.
grug_core = {
	nearest_tag_player_d2 = function(pos)
		count("snapshot")
		local best
		for _, p in ipairs(players) do
			local dx, dy, dz = pos.x - p.pos.x, pos.y - p.pos.y, pos.z - p.pos.z
			local d2 = dx * dx + dy * dy + dz * dz
			if not best or d2 < best then best = d2 end
		end
		return best
	end,
	particles = {play = noop},
}
grug_mobs = {}
grug_sounds = {play = noop}

local api = read("mods/ENTITIES/mobs/api.lua")
local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")

-- ---------------------------------------------------------------------------
-- The attack step: api.lua's attack-state sight and strike, cut out.
-- ---------------------------------------------------------------------------
local sight_src = cut(api, "local target_pos = grug_obstacle.copy_pos(self.attack:get_pos())",
	"ground_melee)\n", "sight")
local strike_src = cut(api, "local ready = self.punch_timer >= self.punch_interval",
	"if consume then self.punch_timer = 0 end", "strike")
local attack_step = load_in("return function(self, s, dtime)\n" .. sight_src ..
	"\nlocal m_edge, m_reach = self._edge, self.reach\n" ..
	"self.punch_timer = math.min((self.punch_timer or 0) + dtime, self.punch_interval)\n" ..
	strike_src .. "\nreturn in_sight\nend", {
		grug_obstacle = O,
		random = function() return 1 end,
		grug_winding_up = function() return false end,
	}, "attack step")

local wall = false
local rays = 0
local function new_mob(fields)
	local m = {attack_type = "dogfight", reach = 3, punch_interval = 1, punch_timer = 0,
		temp = {}, sounds = {}, damage = 2, _edge = 1,
		_grug_cbox = {-0.4, 0, -0.4, 0.4, 1.6, 0.4}}
	for k, v in pairs(fields or {}) do m[k] = v end
	function m:line_of_sight() rays = rays + 1; if not wall then return true end end
	function m:set_animation() end
	function m:mob_sound() end
	function m:stop_attack() self.attack = nil end
	return m
end
local MOB_POS = vec(0, 0, 0)
local DT = 0.09
local function server_step(m, n)
	local seen
	for _ = 1, n or 1 do
		O.begin_server_step()
		seen = attack_step(m, vec(MOB_POS), DT)
	end
	return seen
end

-- ---------------------------------------------------------------------------
-- M. Measurements.
-- ---------------------------------------------------------------------------
local STEPS = 110 -- about 10 s at the default 0.09 s server step
do
	players = {}
	local target = new_player("target", vec(1.5, 0, 0))
	-- In reach: it strikes once a second.
	local m = new_mob({attack = target})
	rays, wall = 0, false
	server_step(m, STEPS)
	local in_reach_rays, strikes = rays, target.punched
	-- Out of reach: it only chases.
	m = new_mob({attack = target, _edge = 10})
	rays = 0
	server_step(m, STEPS)
	print(("MEASURE X4-04 sight rays in %d attack steps: %d in reach (%d strikes), %d chasing")
		:format(STEPS, in_reach_rays, strikes, rays))
end

-- verbs.lua's ambusher and aura with their shared internals, cut out.
local verbs = read("mods/ENTITIES/grug_mobs/verbs.lua")
local verbs_env = {grug_mobs = {scale_attack_damage = function(d) return d end}}
load_in(cut(verbs, "local function chain_do_custom", "\n--\n-- Player status effects", "internals")
	.. "\n" .. cut(verbs, "local AMBUSH_DIRT", "\n--\n-- Camp swarm", "ambusher")
	.. "\n" .. cut(verbs, "function grug_mobs.damage_aura", "\n--\n-- Generic arrow", "aura"),
	verbs_env, "verbs pieces")
local V = verbs_env.grug_mobs
local function verb_mob(pos)
	local m = {temp = {}, order = "stand", state = "stand"}
	m.object = {get_pos = function() return vec(pos) end}
	return m
end
-- patrol.lua's watch of the stuck snap, cut out.
local patrol_env = {grug_mobs = {}}
load_in("local SNAP_PLAYER_RANGE = 48\n" .. cut(read("mods/ENTITIES/grug_mobs/patrol.lua"),
	"function grug_mobs.unwatched", "\nend\n", "unwatched"), patrol_env, "unwatched")
local unwatched = patrol_env.grug_mobs.unwatched

do
	-- 100 players, none near; 30 mobs and items round the stuck patroller.
	players, objects = {}, {}
	for i = 1, 100 do new_player("p" .. i, vec(200 + i * 3, 0, 0)) end
	for i = 1, 30 do new_object(vec(i, 0, 0)) end
	local croc_def, ooze_def = {}, {}
	V.ambusher(croc_def, {trigger_range = 6})
	V.damage_aura(ooze_def, {radius = 2, damage = 2})
	local croc, ooze = verb_mob(vec(0, 0, 0)), verb_mob(vec(0, 0, 0))
	reset_calls()
	for _ = 1, 10 do
		croc_def.do_custom(croc, 1)
		ooze_def.do_custom(ooze, 1)
	end
	local far = calls
	reset_calls()
	for _ = 1, 10 do unwatched(vec(0, 0, 0), 48) end
	local watch = calls
	-- One player inside the aura.
	players[1].pos = vec(1.5, 0, 0)
	reset_calls()
	for _ = 1, 10 do ooze_def.do_custom(ooze, 1) end
	local near = calls
	print(("MEASURE X4-12 ambusher + aura, 10 s, 100 players none near: " ..
		"%d player lists, %d get_pos, %d object queries")
		:format(far.get_connected_players or 0, far.get_pos or 0, far.get_objects_inside_radius or 0))
	print(("MEASURE X4-12 aura, 10 s, one player inside: %d player lists, %d get_pos, " ..
		"%d object queries"):format(near.get_connected_players or 0, near.get_pos or 0,
		near.get_objects_inside_radius or 0))
	print(("MEASURE MOB1-06 unwatched x10, 30 objects within 48: %d object queries, " ..
		"%d objects returned"):format(watch.get_objects_inside_radius or 0, watch.objects_returned or 0))
end

if measure_only then
	print("R81 MOBRUN MEASURE ONLY checks=" .. checks)
	return
end

-- ---------------------------------------------------------------------------
-- S. X4-04: the reused sight answer.
-- ---------------------------------------------------------------------------
do
	players, objects = {}, {}
	local target = new_player("target", vec(1.5, 0, 0))
	-- S1 chasing: a ray on the first step of every three.
	local m = new_mob({attack = target, _edge = 10})
	rays, wall = 0, false
	server_step(m, 9)
	eq(rays, 3, "S1 nine chasing steps cast three rays")
	-- S2 a wall appears on a step that reuses "visible": the strike due on
	-- that step casts again and does not land.
	m = new_mob({attack = target})
	m.punch_timer = -10 -- not ready yet
	server_step(m, 1)
	rays, wall = 0, true
	m.punch_timer = m.punch_interval
	local seen = server_step(m, 1)
	eq(seen, true, "S2 the step's own answer is the reused one")
	eq(rays, 1, "S2 ...but the due strike casts once")
	eq(target.punched, 0, "S2 ...and does not land through the new wall")
	-- S3 the next steps know the wall from the strike's ray (no further cast).
	rays = 0
	eq(server_step(m, 1), false, "S3 the strike's ray answers the next step")
	eq(rays, 0, "S3 ...without a cast")
	-- S4 no wall: a due strike on a reused step casts and lands.
	wall = false
	m = new_mob({attack = target})
	m.punch_timer = -10
	server_step(m, 1)
	rays = 0
	m.punch_timer = m.punch_interval
	server_step(m, 1)
	eq(rays, 1, "S4 the due strike casts once")
	eq(target.punched, 1, "S4 ...and lands")
	-- S5 a strike on a step that cast uses that ray.
	m = new_mob({attack = target})
	m.punch_timer = m.punch_interval
	rays = 0
	server_step(m, 1)
	eq(rays, 1, "S5 one ray for a step that casts and strikes")
	eq(target.punched, 2, "S5 ...and the strike lands")
	-- S6 a new target casts at once.
	m = new_mob({attack = target, _edge = 10})
	server_step(m, 1)
	local other = new_player("other", vec(2, 0, 0))
	m.attack = other
	rays = 0
	server_step(m, 1)
	eq(rays, 1, "S6 a target switch casts at once")
	-- S7 a mob that explodes casts every step (its fuse).
	m = new_mob({attack = target, attack_type = "explode", _edge = 10})
	rays = 0
	server_step(m, 5)
	eq(rays, 5, "S7 an exploding mob casts every step")
	-- S8 a hidden answer never strikes, also when reused.
	m = new_mob({attack = target})
	m.punch_timer = -10
	wall = true
	server_step(m, 1)
	wall = false
	local before = target.punched
	m.punch_timer = m.punch_interval
	server_step(m, 1)
	eq(target.punched, before, "S8 a reused hidden answer does not strike")
	server_step(m, 1)
	server_step(m, 1)
	eq(target.punched, before + 1, "S8 ...the next cast sees the target and strikes")
	-- S9 a flier's strike keeps its collision-box ray, every time.
	m = new_mob({attack = target, fly = true})
	m.punch_timer = -10
	server_step(m, 1)
	rays = 0
	m.punch_timer = m.punch_interval
	server_step(m, 1)
	eq(rays, 1, "S9 a flier's due strike casts its own ray")
	check(api:find("local in_sight = grug_obstacle.attack_sight(self, s, target_pos,", 1, true) ~= nil,
		"S10 do_states takes the attack sight")
end

-- ---------------------------------------------------------------------------
-- T. MOB1-02 (ruling 7): the wind-up only against a player.
-- ---------------------------------------------------------------------------
do
	grug_mobs.tier_telegraphs = function(tier) return tier == "elite" end
	grug_mobs.root = function(self) self.walk_velocity, self.run_velocity = 0, 0 end
	dofile(repo .. "/mods/ENTITIES/grug_mobs/telegraph.lua")
	players, objects = {}, {}
	local player = new_player("hero", vec(2, 0, 0))
	local wolf = new_object(vec(0, 0, 2))
	function wolf:get_hp() return 10 end
	local guard = {_grug_tier = "elite", state = "attack", reach = 3, damage = 5, temp = {},
		attack = wolf}
	guard.object = {get_pos = function() return vec(0, 0, 0) end, get_yaw = function() return 0 end}
	local wound = false
	for _ = 1, 300 do
		grug_mobs.telegraph_tick(guard, 0.1)
		wound = wound or guard.temp.grug_tg_left ~= nil
	end
	eq(wound, false, "T1 30 s against a mob: no wind-up")
	eq(guard.temp.grug_tg_engaged, nil, "T1 ...and no engagement clock")
	guard.attack = player
	local first
	for i = 1, 100 do
		grug_mobs.telegraph_tick(guard, 0.1)
		if not first and guard.temp.grug_tg_left then first = i end
	end
	check(first ~= nil and first >= 40 and first <= 41,
		"T2 against a player the first wind-up follows 4 s of melee (" .. tostring(first) .. ")")
end

-- ---------------------------------------------------------------------------
-- L. MOB3-01: whelps in the dragon's ledger and death grace.
-- ---------------------------------------------------------------------------
do
	local bosses = read("mods/ENTITIES/grug_mobs/bosses.lua")
	local hooks = {}
	local env = {
		grug_core = {
			get_player_faction = function(name) return name == "loner" and nil or "accord" end,
			opposing_faction = function(f) return f == "accord" and "throng" or "accord" end,
			register_on_player_hit_mob = function(fn) hooks.hit = fn end,
			register_on_effective_heal = noop,
			register_on_effective_absorb = noop,
			damage_source = function(object) return object end,
		},
		core = {
			is_player = core.is_player,
			register_on_dieplayer = function(fn) hooks.die = fn end,
		},
	}
	local ledgers = load_in("local ledgers, RACES, GENERALS = {}, {dwarf = {faction = \"accord\"}}, {}\n" ..
		cut(bosses, "local function player_enemy_of(player, faction)", "\nlocal function crown_stack",
			"ledger hooks"):gsub("\nlocal function crown_stack$", "") ..
		"\nreturn ledgers", env, "ledger hooks")
	players, objects = {}, {}
	local hero = new_player("hero", vec(0, 0, 0))
	local function entity(fields)
		local o = new_object(vec(0, 0, 0))
		o.ent = fields
		function o:get_luaentity() return self.ent end
		return o
	end
	local whelp = entity({_grug_boss_summon = "dragon:x"})
	hooks.hit(hero, whelp.ent)
	eq(ledgers["dragon:x"] and ledgers["dragon:x"].players.hero, true,
		"L1 a hit on a whelp joins its dragon's ledger")
	hooks.die(hero, {object = whelp})
	check(ledgers["dragon:x"].deaths.hero ~= nil, "L2 a whelp's kill gives the death grace")
	ledgers["dragon:x"].deaths.hero = nil
	hooks.die(hero, {object = entity({})})
	eq(ledgers["dragon:x"].deaths.hero, nil, "L3 an ordinary mob's kill gives none")
	local guard = entity({_grug_boss_id = "king:dwarf"})
	hooks.hit(new_player("thrall", vec(0, 0, 0)), guard.ent)
	check(ledgers["king:dwarf"] == nil or ledgers["king:dwarf"].players.thrall == nil,
		"L4 a royal guard still counts only for the king's enemies")
	hooks.hit(hero, entity({}).ent)
	eq(ledgers["dragon:x"].players.hero, true, "L5 nothing else changes the ledger")
end

-- ---------------------------------------------------------------------------
-- P. MOB1-03: definition fields stay on the prototype.
-- ---------------------------------------------------------------------------
do
	local aggro = read("mods/ENTITIES/grug_mobs/aggro.lua")
	local init = read("mods/ENTITIES/grug_mobs/init.lua")
	local G = {CHASE_RANGE = 45, EVADE_SPEED_FACTOR = 1.5}
	local env = {grug_mobs = G, grug_core = {emit_stun_particles = noop, emit_root_crystals = noop}}
	load_in(cut(aggro, "local function no_target_acquisition() end", "\n-- Default leash radius",
		"publication") .. "\n" .. cut(init, "local function save_speed_base(ent)", "\n--\n-- Put an object down",
		"speed effects"), env, "aggro and speeds")
	local proto = {name = "grug_mobs:guard", walk_velocity = 1.2, run_velocity = 4.6}
	proto.__index = proto
	core.registered_entities[proto.name] = proto
	G.publish_aggro_fields(proto, {damage_pursuit = false, leash_range = 30, no_leash = nil,
		soft_deaggro = false, no_acquire = true})
	eq(proto._grug_leash_range, 30, "P1 the leash radius is on the prototype")
	eq(proto._grug_chase_range, 45, "P1 ...the give-up distance")
	eq(proto._grug_soft_deaggro, false, "P1 ...the soft de-aggro opt-out")
	eq(proto._grug_drop_rule, true, "P1 ...the drop rule")
	eq(proto._grug_damage_pursuit_candidate, false, "P1 ...the pursuit policy")
	eq(type(proto.general_attack), "function", "P1 ...and the empty acquisition")
	local function instance(fields)
		local m = setmetatable(fields or {}, proto)
		m.object = {get_velocity = function() return vec(0, 0, 0) end, set_velocity = noop}
		m.health, m.temp = 10, m.temp or {}
		return m
	end
	local m = instance()
	eq(m._grug_leash_range, 30, "P2 an instance reads it")
	eq(rawget(m, "_grug_leash_range"), nil, "P2 ...without its own copy")
	local pack = instance({_grug_chase_range = 1e9})
	eq(pack._grug_chase_range, 1e9, "P2 a pack's own range shadows it")
	-- A root, then its expiry: the speeds come off the instance.
	G.root(m, 1)
	eq(m.run_velocity, 0, "P3 rooted")
	G.tick_speed_effects(m, 0.6)
	G.tick_speed_effects(m, 0.6)
	eq(rawget(m, "walk_velocity"), nil, "P3 the root ends: no saved walk speed")
	eq(rawget(m, "run_velocity"), nil, "P3 ...no saved run speed")
	eq(m.run_velocity, 4.6, "P3 ...the definition's speed")
	G.slow(m, 1, 0.5)
	eq(m.run_velocity, 2.3, "P4 slowed")
	G.tick_speed_effects(m, 1.1)
	eq(rawget(m, "run_velocity"), nil, "P4 the slow ends: the definition's speed again")
	m.temp.grug_evading = true
	G.tick_speed_effects(m, 0.1)
	eq(m.walk_velocity, 4.6 * 1.5, "P5 an evade runs home fast")
	m.temp.grug_evading = nil
	G.tick_speed_effects(m, 0.1)
	eq(rawget(m, "walk_velocity"), nil, "P5 ...and home it walks at the definition's pace")
	-- The Kraken's deep-sea switch writes the base while an effect runs.
	G.root(m, 1)
	m._grug_speed_base.run = 10
	G.tick_speed_effects(m, 1.1)
	eq(rawget(m, "run_velocity"), 10, "P6 a base other than the definition's stays")
	eq(rawget(m, "walk_velocity"), nil, "P6 ...the unchanged one goes")
	-- The activation cleanup of an older save.
	local saved = instance({walk_velocity = 1.2, run_velocity = 5, _grug_leash_range = 30,
		_grug_chase_range = 45, _grug_drop_rule = true, _grug_damage_pursuit_candidate = false,
		_grug_soft_deaggro = false, _grug_no_leash = true, temp = {grug_x = 1}})
	G.drop_prototype_copies(saved)
	for _, field in ipairs({"walk_velocity", "_grug_leash_range", "_grug_chase_range",
			"_grug_drop_rule", "_grug_damage_pursuit_candidate", "_grug_soft_deaggro"}) do
		eq(rawget(saved, field), nil, "P7 a saved copy of " .. field .. " goes")
	end
	eq(rawget(saved, "run_velocity"), 5, "P7 a saved speed of its own stays")
	eq(rawget(saved, "_grug_no_leash"), true, "P7 a spawner's no-leash stays")
	eq(saved.temp.grug_x, 1, "P7 temp is never touched")
	G.drop_prototype_copies({name = "unknown:mob", walk_velocity = 1})
	check(init:find("grug_mobs.apply_aggro_fields", 1, true) == nil
		and aggro:find("function grug_mobs.apply_aggro_fields", 1, true) == nil,
		"P8 no per-step or per-punch field installation left")
	check(init:find("grug_mobs.publish_aggro_fields(prototype, aggro_cfg)", 1, true) ~= nil,
		"P8 register_mob publishes the config once")
	check(init:find("grug_mobs.drop_prototype_copies(self)", 1, true) ~= nil,
		"P8 the after_activate wrapper cleans an older save")
end

-- ---------------------------------------------------------------------------
-- K. MOB1-04 and MOB3-02 in the source.
-- ---------------------------------------------------------------------------
do
	local init = read("mods/ENTITIES/grug_mobs/init.lua")
	local wrapper = cut(init, "def.do_custom = function(self, dtime, moveresult)\n\t\t-- First-tick",
		"\n\tend\n", "do_custom wrapper")
	check(wrapper:find("_grug_stun_left", 1, true) == nil,
		"K1 the do_custom wrapper has no stun branch (api.lua's on_step owns the stun)")
	check(api:find("if grug_stunned then return end", 1, true) ~= nil, "K1 ...which returns before it")
	local dragons = read("mods/ENTITIES/grug_mobs/boss_dragons.lua")
	local glow = "if self._grug_enraged then self.object:set_properties({glow = 8}) end"
	local _, n = dragons:gsub(glow:gsub("%p", "%%%0"), "")
	eq(n, 1, "K2 one enraged-glow write")
	local first = cut(dragons, "\t\tself.temp.grug_dragon = state\n", "\n\tend\n", "first tick")
	check(first:find(glow, 1, true) ~= nil, "K2 ...on the first tick of an activation")
end

-- ---------------------------------------------------------------------------
-- R. MOB3-03: the rift's particles on the one particle path.
-- ---------------------------------------------------------------------------
do
	local spawners = {}
	local function helper(scale)
		local real = rawget(_G, "grug_core")
		local env = setmetatable({grug_core = {}, core = {
			settings = {get = function(_, key) if key == "grug_particle_scale" then return scale end end},
			add_particle = function() end,
			add_particlespawner = function(def) spawners[#spawners + 1] = def end,
			yaw_to_dir = core.yaw_to_dir, log = noop,
			after = function(_, fn, ...) fn(...) end,
		}}, {__index = _G})
		for _, file in ipairs({"particles.lua", "particle_effects.lua"}) do
			local chunk = assert(loadfile(repo .. "/mods/CORE/grug_core/" .. file))
			setfenv(chunk, env)
			chunk()
		end
		_G.grug_core = real
		return env.grug_core.particles
	end
	local P = helper(nil)
	local FRAME = {caster = vec(10, 5, 10), size = {9, 3}, n = 4}
	for _, id in ipairs({"rift_crack", "rift_pulse_windup", "rift_pulse", "rift_rise"}) do
		local effect = P.registered(id)
		if check(effect ~= nil, "R1 " .. id .. " is in the catalogue") then
			local list = type(effect) == "function" and effect(FRAME) or effect
			eq(P.check(list), nil, "R1 " .. id .. " keeps the budget rules")
			spawners = {}
			P.play(id, FRAME)
			check(#spawners >= 1, "R1 " .. id .. " plays")
			for _, def in ipairs(spawners) do
				check(def.time > 0 and def.time <= 1 and def.playername == nil and not def.attached,
					"R1 " .. id .. ": a 1 s spawner at most, for every player in range")
				eq(def.texture, "grug_mobs_rift_particle.png", "R1 " .. id .. ": the rift's motes")
			end
		end
	end
	spawners = {}
	P.play("rift_crack", FRAME)
	local s = spawners[1]
	check(s.amount == 4 and s.pos.min.x == 10 and s.pos.max.x == 19 and s.pos.max.z == 13,
		"R2 the crack's spawner covers the stretch with its motes")
	local off = helper("0")
	spawners = {}
	for _, id in ipairs({"rift_crack", "rift_pulse_windup", "rift_pulse", "rift_rise"}) do
		off.play(id, FRAME)
	end
	eq(#spawners, 0, "R3 grug_particle_scale 0 sends none")
	local rift = read("mods/ENTITIES/grug_mobs/rift.lua")
	check(rift:find("add_particlespawner", 1, true) == nil, "R4 rift.lua adds no spawner of its own")
	local R = dofile(repo .. "/mods/ENTITIES/grug_mobs/rift_core.lua")
	local crack = P.registered("rift_crack")({})[1]
	check(crack.exp[1] == R.PARTICLE_LIFE[1] and crack.exp[2] == R.PARTICLE_LIFE[2],
		"R5 the crack's life is rift_core's")
	local alive = R.particles_alive()
	check(alive >= 20 and alive <= 300, "R5 about " .. alive .. " motes alive (hundreds at most)")
end

-- ---------------------------------------------------------------------------
-- W. MOB1-06, X4-12: the snapshot answers as before.
-- ---------------------------------------------------------------------------
do
	players, objects = {}, {}
	eq(unwatched(vec(0, 0, 0), 48), true, "W1 nobody on the server: unwatched")
	local p = new_player("watcher", vec(47, 0, 0))
	eq(unwatched(vec(0, 0, 0), 48), false, "W1 a player 47 nodes away watches")
	p.pos = vec(49, 0, 0)
	eq(unwatched(vec(0, 0, 0), 48), true, "W1 one 49 nodes away does not")
	-- The ambusher lurks with nobody within 6, breaks with someone there.
	local croc_def = {}
	V.ambusher(croc_def, {trigger_range = 6})
	local croc = verb_mob(vec(0, 0, 0))
	croc.order = ""
	croc_def.do_custom(croc, 1)
	eq(croc.order, "stand", "W2 nobody within 6: the ambusher lurks")
	p.pos = vec(5, 0, 0)
	croc_def.do_custom(croc, 1)
	eq(croc.order, "", "W2 a player within 6: it stirs")
	-- The aura hits who is inside its 2 m, nobody else.
	local ooze_def = {}
	V.damage_aura(ooze_def, {radius = 2, damage = 2})
	local ooze = verb_mob(vec(0, 0, 0))
	ooze.object.pos = vec(0, 0, 0)
	p.pos = vec(3, 0, 0)
	local inside = new_player("inside", vec(1.5, 0, 0))
	local mob = new_object(vec(1, 0, 0))
	function mob:punch() error("a mob in the aura is punched") end
	ooze_def.do_custom(ooze, 1)
	eq(inside.punched, 1, "W3 a player inside the aura is hit")
	eq(p.punched, 0, "W3 ...one 3 m away is not")
	players = {p}
	p.pos = vec(30, 0, 0)
	reset_calls()
	ooze_def.do_custom(ooze, 1)
	eq(calls.get_objects_inside_radius, nil, "W4 nobody near the aura: no object query")
end

print("R81 MOBRUN PORTABLE PASS checks=" .. checks)
