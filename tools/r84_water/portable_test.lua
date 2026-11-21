-- Round 84 lane WATER portable test (LuaJIT; round84-plan.md rulings 3 and 4,
-- §4 WATER). Loads the REAL tortoise.lua, disposition.lua and
-- grug_core/homing.lua, and cuts the touched pieces out of the vendored
-- mobs/api.lua, grug_mobs/verbs.lua and grug_mobs/aggro.lua, on a small fake
-- engine. Checks:
--   W  the water speed (api.lua grug_liquid_speed): water keeps the land
--      speed, a definition's factor applies in water only, lava still slows
--      to 1/8, a swimmer and dry ground are unchanged; register_mob copies
--      the factor;
--   T  the Tortoise: neutral (acquires nobody, bites back), run 3 on land and
--      3.5-4 in water, view range 8, a shot range just beyond the player's
--      31, dogshoot with the mud ball (stamped damage, the bite clip), all
--      six sub-types share it (they copy the base);
--   H  the mud ball's hit: the stamped damage on a player and a mob, a slow
--      of 40-50 % for a few seconds on a player only, through the one
--      mob-slow slot (verbs.lua slow_player: a hex and the mud do not stack);
--   R  answering at 32: a hit sets the attacker as target at any distance
--      (do_attack), the 45-node give-up distance keeps it, the ranged mode at
--      that distance, the mob stands and shoots inside its shot range and
--      closes in beyond it, the arrow's lock accepts 32 m and refuses a
--      target beyond the shot range, and its flight reaches 33 m in at most
--      2 s;
--   A  the mob is active at 33 nodes: the engine's active block sphere
--      (serverenvironment.cpp fillRadiusBlock) of the default
--      active_block_range 4, which the game does not change;
--   S  the swim speeds: the engine's player swim speed in water (about 2.7
--      nodes/s, localplayer.cpp/clientenvironment.cpp, modelled), below
--      every land attacker's run and the Tortoise's water speed.
-- Usage (repo root): luajit tools/r84_water/portable_test.lua [REPO]
-- Prints "R84 WATER PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function eq(a, b, label)
	check(a == b, label .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")")
end
local function near(a, b) return math.abs(a - b) < 1e-9 end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
-- The text from `from` through the first `to` after it (included).
local function cut(src, from, to, label)
	local s = src:find(from, 1, true)
	check(s ~= nil, "anchor " .. label)
	local _, e = src:find(to, s + #from, true)
	check(e ~= nil, "end anchor " .. label)
	return src:sub(s, e)
end
local function load_in(src, env, label)
	local chunk = assert(loadstring(src, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

_G.vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
	offset = function(v, x, y, z) return {x = v.x + x, y = v.y + y, z = v.z + z} end,
	length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
}

local api = read("mods/ENTITIES/mobs/api.lua")
local MOBS = "mods/ENTITIES/grug_mobs"

local nodes = {
	air = {name = "air", groups = {}},
	["default:water_source"] = {liquid_viscosity = 1, groups = {water = 3, liquid = 3}},
	["default:river_water_flowing"] = {liquid_viscosity = 1, groups = {water = 3, liquid = 3}},
	["default:lava_source"] = {liquid_viscosity = 7, groups = {lava = 3, liquid = 2}},
}

-- ---------------------------------------------------------------------------
-- W. The water speed.
-- ---------------------------------------------------------------------------
local speed = load_in(
	cut(api, "local function check_for(look_for, look_inside)", "\nend\n", "check_for") ..
	cut(api, "local function grug_liquid_speed(self, v)", "\nend\n", "grug_liquid_speed") ..
	"return grug_liquid_speed\n",
	{min = math.min, core = {registered_nodes = nodes, registered_items = nodes}}, "liquid speed")
local TORTOISE_FACTOR -- read from the definition in T
do
	local function s(where, v, fields)
		local self = {standing_in = where}
		for k, val in pairs(fields or {}) do self[k] = val end
		return speed(self, v)
	end
	eq(s("default:water_source", 4.6), 4.6, "W1 a land mob swims at its land speed")
	eq(s("default:river_water_flowing", 4.0), 4.0, "W2 flowing river water too")
	eq(s("air", 4.6), 4.6, "W3 dry ground keeps it")
	eq(s("default:water_source", 0), 0, "W4 a standing mob stays standing")
	check(near(s("default:lava_source", 4.6), 4.6 / 8), "W5 lava (viscosity 7) still slows to 1/8")
	check(near(s("default:water_source", 3, {_grug_water_speed_factor = 1.25}), 3.75),
		"W6 a definition's water factor applies in water")
	eq(s("air", 3, {_grug_water_speed_factor = 1.25}), 3, "W7 ...and not on land")
	check(near(s("default:lava_source", 3, {_grug_water_speed_factor = 1.25}), 3 / 8),
		"W8 ...nor in lava")
	eq(s("default:water_source", 4.6, {fly_in = "default:water_source"}), 4.6,
		"W9 a swimmer keeps its speed")
	check(api:find("_grug_water_speed_factor = def._grug_water_speed_factor,", 1, true) ~= nil,
		"W10 register_mob copies the factor onto the entity")
	check(api:find("v = grug_liquid_speed(self, v)", 1, true) ~= nil
		and api:find("and grug_liquid_speed(self, grug_nav_v) or 0)", 1, true) ~= nil,
		"W11 movement and the stuck detector share the one speed")
end

-- ---------------------------------------------------------------------------
-- T. The Tortoise's definition (the REAL tortoise.lua and disposition.lua).
-- ---------------------------------------------------------------------------
local STAMP = function() end
local registered, arrows = {}, {}
local slows = {}
local gm = {
	atlas_textures = function(texture, n)
		local list = {}
		for i = 1, n do list[i] = texture end
		return list
	end,
	stamp_arrow_damage = STAMP,
	scale_attack_damage = function(base) return base * 1.5 end,
	register_homing_arrow = function(name, def) arrows[name] = def end,
	slow_player = function(player, duration, factor)
		slows[#slows + 1] = {player = player, duration = duration, factor = factor}
	end,
}
local env = {
	grug_mobs = gm,
	core = {is_player = function(o) return type(o) == "table" and o.player == true end},
}
load_in(read(MOBS .. "/disposition.lua"), env, "disposition.lua")
gm.register_mob = function(name, def)
	gm.apply_disposition(name, def)
	registered[name] = def
end
load_in(read(MOBS .. "/tortoise.lua"), env, "tortoise.lua")
local T = registered["grug_mobs:tortoise"]
local SHOT_RANGE, RUN
do
	check(T ~= nil, "T0 the tortoise is registered")
	eq(gm.disposition("grug_mobs:tortoise"), "neutral", "T1 it stays neutral")
	eq(T.attack_players, false, "T2 it picks no player by itself")
	eq(T.passive, false, "T3 it fights back")
	eq(T.group_attack, false, "T4 a single pull")
	eq(T.view_range, 8, "T5 view range 8 (unchanged)")
	eq(T.walk_velocity, 0.5, "T6 walks 0.5")
	RUN = T.run_velocity
	check(RUN >= 2.8 and RUN <= 3.2, "T7 runs about 3 on land (" .. RUN .. ")")
	TORTOISE_FACTOR = T._grug_water_speed_factor
	local wet = speed({standing_in = "default:water_source", _grug_water_speed_factor = TORTOISE_FACTOR}, RUN)
	check(wet > RUN and wet >= 3.5 and wet <= 4, "T8 faster in water, 3.5-4 (" .. wet .. ")")
	SHOT_RANGE = T._grug_shot_range
	check(SHOT_RANGE > 31 and SHOT_RANGE <= 34,
		"T9 the shot range lies just beyond the player's 31 (" .. tostring(SHOT_RANGE) .. ")")
	eq(T.attack_type, "dogshoot", "T10 shoots at range, bites close in")
	eq(T.dogshoot_switch, 1, "T11 starts in its ranged mode (the mode by distance)")
	eq(T.arrow, "grug_mobs:tortoise_mud", "T12 its shot is the mud ball")
	eq(T.arrow_override, STAMP, "T13 the shooter's damage and lock are stamped")
	check(arrows["grug_mobs:tortoise_mud"] ~= nil, "T14 the mud ball is registered")
	check(T.shoot_interval and T.shoot_interval >= 2 and T.shoot_interval <= 3,
		"T15 a shot every 2-3 s, as the other shooters")
	check(T.animation.shoot_start == T.animation.punch_start
		and T.animation.shoot_end == T.animation.punch_end, "T16 the shot plays the bite clip")
	eq(T._grug_amphibian, true, "T17 still an amphibian")
	local A = arrows["grug_mobs:tortoise_mud"]
	local png = A.textures[1]
	local f = io.open(repo .. "/" .. MOBS .. "/textures/" .. png, "rb")
	check(f ~= nil, "T18 the sprite " .. png .. " ships")
	if f then f:close() end
	check(read(MOBS .. "/LICENSE-media.md"):find(png, 1, true) ~= nil, "T19 ...with its LICENSE-media row")
	check(A.impact and A.impact:match("^#%x%x%x%x%x%x$") ~= nil, "T20 an impact tint (a bounded puff)")
	-- The sub-types copy the base (subtypes.lua copy_base_def): none of the six
	-- rows sets a speed or an attack.
	local rows = read(MOBS .. "/data/subtypes.json")
	local n = 0
	for block in rows:gmatch('{%s*"role": "tortoise_t%d".-}') do
		n = n + 1
		check(not block:find("velocity") and not block:find("attack") and not block:find("range"),
			"T21 a tortoise sub-type row sets no speed, attack or range")
	end
	eq(n, 6, "T22 six tortoise sub-types")
end

-- ---------------------------------------------------------------------------
-- H. The hit and the slow slot.
-- ---------------------------------------------------------------------------
do
	local A = arrows["grug_mobs:tortoise_mud"]
	local punches = {}
	local function target(is_player)
		local o = {player = is_player}
		function o.punch(_, puncher, tflp, caps) punches[#punches + 1] = {o = o, by = puncher, caps = caps} end
		return o
	end
	local arrow_obj = {}
	local player, mob = target(true), target(false)
	A.hit_player({object = arrow_obj, _grug_damage = 7.5}, player)
	eq(#punches, 1, "H1 a player is hit once")
	eq(punches[1].caps.damage_groups.fleshy, 7.5, "H2 ...for the shooter's stamped damage")
	eq(punches[1].by, arrow_obj, "H3 ...by the projectile (the source is attributed through it)")
	eq(#slows, 1, "H4 ...and slowed")
	local slow = slows[1]
	check(slow.factor >= 0.5 and slow.factor <= 0.6, "H5 a slow of 40-50 % (" .. (1 - slow.factor) .. ")")
	check(slow.duration >= 2 and slow.duration <= 5, "H6 for a few seconds (" .. slow.duration .. ")")
	A.hit_mob({object = arrow_obj, _grug_damage = 7.5}, mob)
	eq(#punches, 2, "H7 a mob it answers is hit too")
	eq(#slows, 1, "H8 ...but never slowed")
	A.hit_player({object = arrow_obj}, player)
	eq(punches[3].caps.damage_groups.fleshy, 1.5, "H9 without a stamp the scaled base damage")

	-- The one mob-slow slot: the real slow_player of verbs.lua on a fake
	-- aggregator. A hex (0.7, 4 s) and then the mud: the stronger factor and the
	-- longer time win in one entry, never two stacked slows.
	local mods = {}
	local verbs = read(MOBS .. "/verbs.lua")
	local g2 = {}
	load_in(cut(verbs, 'local WEB_MODIFIER = "mob_web"', "\n", "web modifier") ..
		cut(verbs, "function grug_mobs.slow_player(player, duration, factor)", "\nend\n", "slow_player"),
		{grug_mobs = g2, core = env.core, grug_core = {
			get_move_modifier = function(_, name)
				local m = mods[name]
				return m and {speed = m.speed, remaining = m.duration}
			end,
			set_move_modifier = function(_, name, delta, duration)
				mods[name] = {speed = delta.speed, duration = duration}
			end,
		}}, "slow_player")
	g2.slow_player(player, 4, 0.7)
	g2.slow_player(player, slow.duration, slow.factor)
	local names = 0
	for _ in pairs(mods) do names = names + 1 end
	eq(names, 1, "H10 one slot for webs, hexes and the mud")
	check(mods.mob_web and near(mods.mob_web.speed, slow.factor - 1) and mods.mob_web.duration == 4,
		"H11 the stronger slow and the longer time win, nothing stacks")
end

-- ---------------------------------------------------------------------------
-- R. Answering at 32 nodes.
-- ---------------------------------------------------------------------------
do
	-- R1 provocation: do_attack (cut out) takes the attacker at any distance.
	local mob_class = {}
	-- (the chunk reads its mob_class from the vararg)
	local chunk = assert(loadstring("local mob_class = ...\n" ..
		cut(api, "function mob_class:do_attack(player, force)", "\nend\n", "do_attack")))
	setfenv(chunk, setmetatable({random = function() return 100 end,
		grug_nav = {forget = function() end},
		grug_obstacle = {forget_no_path = function() end},
		grug_mobs = {start_damage_pursuit = function() end}}, {__index = _G}))
	chunk(mob_class)
	local shooter = {state = "stand", temp = {}, sounds = {}, mob_sound = function() end}
	local attacker = {player = true}
	mob_class.do_attack(shooter, attacker)
	check(shooter.attack == attacker and shooter.state == "attack",
		"R1 a hit from 32 m (beyond view range 8) makes the attacker its target")
	check(api:find("self.state = \"\"\n\t\t\tself:do_attack(hitter) -- attack whoever punched mob", 1, true) ~= nil,
		"R2 on_punch hands every hitter to do_attack, no distance test")
	-- R3 the give-up distance: grug mobs carry CHASE_RANGE (45), not view range.
	local chase = tonumber(read(MOBS .. "/aggro.lua"):match("grug_mobs%.CHASE_RANGE = (%d+)"))
	check(chase and chase > SHOT_RANGE, "R3 the give-up distance " .. tostring(chase) ..
		" lies beyond the shot range, so the target is kept")
	check(api:find("or self._grug_chase_range or self.view_range", 1, true) ~= nil,
		"R4 do_states gives up at the chase range")

	-- R5 the ranged mode by distance (grug_dogshoot_mode, cut out).
	local ds_mode = load_in(cut(api, "local GRUG_MELEE_BELOW = 4", "\nend\n", "dogshoot mode") ..
		"\nreturn grug_dogshoot_mode",
		{grug_nav = {line_to_target = function() return true end}}, "dogshoot mode")
	local t = {dogshoot_switch = 1, temp = {}}
	eq(ds_mode(t, 31, 2, true, 0.1, {}, {}), 1, "R5 at 31-32 m it is in its ranged mode")
	eq(ds_mode(t, 1, 2, true, 0.1, {}, {}), 2, "R6 close in it bites")

	-- R7 inside its shot range it stands and shoots, beyond it closes in.
	local mobs = {}
	local closing = load_in(
		cut(api, "local GRUG_SHOT_RANGE_EXTRA = 4", "\nmobs.grug_shot_range = grug_shot_range\n", "shot range") ..
		cut(api, "local function grug_ranged_closing(self, ds_var, dist)", "\nend\n", "closing") ..
		"return grug_ranged_closing",
		{mobs = mobs}, "ranged closing")
	local stopped = 0
	local m = {attack_type = "dogshoot", _grug_shot_range = SHOT_RANGE, view_range = 8, temp = {},
		set_velocity = function() stopped = stopped + 1 end, set_animation = function() end}
	eq(mobs.grug_shot_range(m), SHOT_RANGE, "R7 the shot range is the definition's")
	eq(closing(m, 1, 32), false, "R8 at 32 m it stands and shoots")
	eq(closing(m, 1, SHOT_RANGE + 5), true, "R9 beyond its shot range it closes in (at run speed)")
	eq(closing(m, 1, SHOT_RANGE - 3.5), false, "R10 ...and stops 3 m inside it")

	-- R11 the arrow's lock and flight (the REAL homing.lua).
	local saved_core, saved_gc = _G.core, _G.grug_core
	_G.core = {
		register_on_joinplayer = function() end, register_on_dieplayer = function() end,
		register_on_respawnplayer = function() end, register_on_leaveplayer = function() end,
		raycast = function() return function() return nil end end,
		get_node = function() return {name = "air"} end,
		registered_nodes = nodes,
		get_player_by_name = function() return nil end,
	}
	_G.grug_core = {player_body = function() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3}} end}
	dofile(repo .. "/mods/CORE/grug_core/homing.lua")
	local lock = _G.grug_core.actor_projectile_lock
	local step = _G.grug_core.homing_step
	local mob_pos = {x = 0, y = 1, z = 0}
	local ent = {health = 30}
	local owner = {get_pos = function() return {x = mob_pos.x, y = mob_pos.y, z = mob_pos.z} end,
		is_player = function() return false end, get_luaentity = function() return ent end}
	local tpos = {x = 32, y = 1, z = 0}
	local player = {get_pos = function() return {x = tpos.x, y = tpos.y, z = tpos.z} end,
		is_player = function() return true end, get_hp = function() return 20 end,
		get_player_name = function() return "tess" end,
		get_velocity = function() return {x = 0, y = 0, z = 0} end,
		get_attach = function() return nil end}
	_G.core.get_player_by_name = function() return player end
	local velocity = arrows["grug_mobs:tortoise_mud"].velocity
	local origin = {x = 0, y = 1.3, z = 0}
	local l = lock(owner, player, origin, velocity, mobs.grug_shot_range(m))
	check(l ~= nil, "R11 the mud ball locks a target 32 m away")
	tpos = {x = 22.6, y = 9, z = 22.6}
	check(lock(owner, player, origin, velocity, mobs.grug_shot_range(m)) ~= nil,
		"R12 ...also diagonally and 8 nodes up (" .. string.format("%.1f", vector.distance(mob_pos, tpos)) .. " m)")
	tpos = {x = SHOT_RANGE + 0.5, y = 1, z = 0}
	check(lock(owner, player, origin, velocity, mobs.grug_shot_range(m)) == nil,
		"R13 a target beyond the shot range is refused")
	tpos = {x = SHOT_RANGE, y = 1, z = 0}
	l = lock(owner, player, origin, velocity, mobs.grug_shot_range(m))
	check(l ~= nil and l.duration <= 2, "R14 the flight to the shot range's edge takes at most 2 s")
	local t_flight, arrived = 0, false
	while not arrived and t_flight < 3 do
		local dest
		dest, arrived = step(l, 0.09)
		check(dest ~= nil, "R15 the lock holds in flight")
		t_flight = t_flight + 0.09
	end
	check(arrived and t_flight <= 2.1, "R16 it arrives (" .. string.format("%.2f", t_flight) .. " s)")
	_G.core, _G.grug_core = saved_core, saved_gc
end

-- ---------------------------------------------------------------------------
-- A. The mob is an active object at 33 nodes (engine model).
-- ---------------------------------------------------------------------------
do
	-- builtin/settingtypes.txt:2321 active_block_range default 4; the game's
	-- minetest.conf and settingtypes.txt leave it alone.
	check(not read("minetest.conf"):find("\nactive_block_range", 1, true)
		and not read("settingtypes.txt"):find("\nactive_block_range", 1, true),
		"A1 the game keeps the engine's active_block_range")
	local R = 4
	local function block(v) return math.floor(v / 16) end
	-- fillRadiusBlock: every block whose block distance to the player's block
	-- is at most R (serverenvironment.cpp:54-65).
	local worst = 0
	for px = 0, 15, 1.5 do
		for pz = 0, 15, 1.5 do
			for py = 0, 15, 5 do
				for a = 0, 63 do
					local ang = a / 64 * 2 * math.pi
					for dy = -12, 12, 4 do
						local h = math.sqrt(33 * 33 - dy * dy)
						local mx, mz, my = px + h * math.cos(ang), pz + h * math.sin(ang), py + dy
						local bx, by, bz = block(mx) - block(px), block(my) - block(py), block(mz) - block(pz)
						local d = math.sqrt(bx * bx + by * by + bz * bz)
						if d > worst then worst = d end
					end
				end
			end
		end
	end
	check(worst <= R, "A2 every mob 33 nodes away lies in an active block (worst block distance " ..
		string.format("%.2f", worst) .. " <= " .. R .. ")")
end

-- ---------------------------------------------------------------------------
-- S. The swim speeds (engine model).
-- ---------------------------------------------------------------------------
do
	-- A player holding forward in water: applyControl's accelerate toward
	-- movement_speed_walk (4) at movement_acceleration_default (3) x BS x BS
	-- per second (localplayer.cpp:570, 715, 784-823), then the liquid brake
	-- min(speed / fluidity, fluidity_smooth) x (move_resistance x 0.3 + 0.7)
	-- x 100 x dtime (clientenvironment.cpp:143-171), water's move_resistance
	-- its viscosity 1 (c_content.cpp:988), sub-steps of at most 0.01 s
	-- (clientenvironment.cpp:96-117); fluidity_smooth 0.75 (minetest.conf).
	local BS = 10
	local function swim(physics_speed, fps)
		local s, t, moved = 0, 0, 0
		local frame = 1 / fps
		while t < 5 do
			local dmax = math.min(s > 0.001 and 0.1 * BS / s or 1, 0.01)
			local steps = math.ceil(frame / dmax)
			local dt = frame / steps
			for _ = 1, steps do
				local target = 4 * BS * physics_speed
				local inc = 3 * BS * physics_speed * BS * dt
				s = s + math.min(target - s, inc)
				local dl = math.min(s / BS, 0.75 * BS) * (1 * 0.3 + 0.7)
				s = s - dl * dt * 100
				if t >= 2 then moved = moved + s * dt end
				t = t + dt
			end
		end
		return moved / (t - 2) / BS
	end
	local plain, fastest = swim(1, 60), swim(1.5, 60)
	check(plain > 2.5 and plain < 3, "S1 a player swims at about 2.7 nodes/s (" ..
		string.format("%.2f", plain) .. "; 4 on land)")
	check(fastest < 4.6, "S2 even at the 1.5 speed cap (" .. string.format("%.2f", fastest) ..
		") below every land attacker's 4.6")
	local wet = RUN * TORTOISE_FACTOR
	check(wet > plain, "S3 the Tortoise in water (" .. wet .. ") outswims a player")
	check(RUN < 4, "S4 on land an unslowed player (4) still walks away from it (" .. RUN .. ")")
	print(string.format("R84 WATER numbers: player swim %.2f n/s (x1.5 cap %.2f), tortoise land %.2f, water %.2f, shot range %d",
		plain, fastest, RUN, wet, SHOT_RANGE))
end

print("R84 WATER PORTABLE PASS checks=" .. checks)
