-- Round 81 lane HOT portable test (LuaJIT; round81-plan.md §4 HOT, audit
-- X4-01, X4-02, X4-07, X4-09, C1-03, C1-05, C1-06, C1-07, C1-13, E1-01,
-- ruling 2).
--
--   luajit tools/r81_hot/portable_test.lua [REPO]
--
--   P  the REAL grug_core/privs.lua: grug_core.has_priv answers as the
--      engine's privilege table does, one lookup per player and privilege;
--      a grant, a revoke (both callbacks return true), a join, a leave and
--      core.auth_reload drop the answers;
--   B  the REAL combat_ray.lua and the vendored player_api: the player body
--      (eye height, box) is read once, by ObjectRef, and read again after
--      player_body_changed, which player_api's two property writes and
--      grug_mounts.apply_camera call; combat_eye_pos reads it;
--   H  the REAL homing.lua: the aim at a player follows a posture change
--      reported through player_body_changed; a mob's comes from `_grug_cbox`;
--      another entity still reads its properties;
--   S  the REAL status.lua: status_modifier_sum equals the sum over
--      each_status' order to the last bit (fractional values, expired
--      records removed once with on_expire);
--   E  the REAL combat.lua: engage_mob makes the same edges (a dead player,
--      a dying mob and an untracked mob as before) and reads nothing once
--      the edge exists;
--   J  the REAL grug_core/player_slots.lua: every player once per period,
--      at most an eighth of them per tick, the fewest-filled slot at a join,
--      `elapsed` adding up to the game time, a stall collapsed to two ticks;
--      at 0.09 s steps a 0.5 s pass visits each player twice a second and a
--      1 s pass once;
--   R  ruling 2 in the REAL grug_abilities/init.lua (tools/r81_hot/measure.lua's
--      sandbox): a relog keeps the running cooldowns, charges and the mana
--      value and hands the timers to the overlay; expired ones and other
--      names are not touched; a first join fills mana; death keeps them;
--      a leave with full mana and no running timer keeps nothing, and a
--      timers-only record goes at a later leave once they have run out;
--   M  the call counts of tools/r81_hot/measure.lua on this tree (the
--      numbers of the base are in the lane report).
-- Prints "R81 HOT PORTABLE PASS checks=<n>" or raises.
local ROOT = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", want " ..
		tostring(expected) .. ")")
end
local function read(path)
	local f = assert(io.open(ROOT .. "/" .. path, "r"))
	local text = f:read("*a")
	f:close()
	return text
end
local function load_into(env, path)
	local chunk = assert(loadfile(ROOT .. "/" .. path))
	setfenv(chunk, env)
	return chunk()
end
local function noop_register(t)
	return setmetatable(t, {__index = function(_, k)
		if type(k) == "string" and k:match("^register_") then return function() end end
	end})
end
local function vec(x, y, z) return {x = x, y = y, z = z} end
local vector = {
	new = function(x, y, z)
		if type(x) == "table" then return vec(x.x, x.y, x.z) end
		return vec(x, y, z)
	end,
	offset = function(v, x, y, z) return vec(v.x + x, v.y + y, v.z + z) end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
	length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
}

------------------------------------------------------------------------------
-- P: the privilege cache.
------------------------------------------------------------------------------
do
	local lookups, reloads = 0, 0
	local privs = {anna = {interact = true, noclip = true}, bert = {interact = true}}
	local grants, revokes, leaves, joins = {}, {}, {}, {}
	local env = setmetatable({grug_core = {}, core = {
		get_player_privs = function(name)
			lookups = lookups + 1
			local copy = {}
			for k, v in pairs(privs[name] or {}) do copy[k] = v end
			return copy
		end,
		register_on_priv_grant = function(f) grants[#grants + 1] = f end,
		register_on_priv_revoke = function(f) revokes[#revokes + 1] = f end,
		register_on_leaveplayer = function(f) leaves[#leaves + 1] = f end,
		register_on_joinplayer = function(f) joins[#joins + 1] = f end,
		auth_reload = function() reloads = reloads + 1 return true end,
	}}, {__index = _G})
	load_into(env, "mods/CORE/grug_core/privs.lua")
	local has = env.grug_core.has_priv
	eq(has("anna", "interact"), true, "P anna interacts")
	eq(has("anna", "interact"), true, "P again")
	eq(lookups, 1, "P one lookup for two answers")
	eq(has("anna", "noclip"), true, "P another privilege")
	eq(has("anna", "fly"), false, "P a missing privilege is false")
	eq(lookups, 3, "P one lookup per privilege")
	eq(has("cara", "interact"), false, "P an unknown player holds nothing")
	for _ = 1, 50 do has("anna", "interact"); has("bert", "interact") end
	eq(lookups, 5, "P 100 more answers from the cache")
	privs.bert.fly = true
	eq(grants[1]("bert", "admin", "fly"), true, "P the grant callback returns true")
	eq(has("bert", "fly"), true, "P a grant drops the answers")
	privs.anna.interact = nil
	eq(revokes[1]("anna", "admin", "interact"), true, "P the revoke callback returns true")
	eq(has("anna", "interact"), false, "P a revoke drops the answers")
	privs.anna.interact = true
	local n = lookups
	leaves[1]({get_player_name = function() return "anna" end})
	eq(has("anna", "interact"), true, "P a relog reads again")
	eq(lookups, n + 1, "P leaving drops the answers")
	-- An answer cached after the leave (or a name removed and made again)
	-- goes at the join.
	eq(has("anna", "noclip"), true, "P asked after the leave")
	privs.anna.noclip = nil
	eq(has("anna", "noclip"), true, "P cached after the leave")
	joins[1]({get_player_name = function() return "anna" end})
	eq(has("anna", "noclip"), false, "P joining drops the answers")
	has("bert", "interact")
	privs.bert.interact = nil -- an edit outside the game, then /auth_reload
	eq(has("bert", "interact"), true, "P cached until the reload")
	eq(env.core.auth_reload(), true, "P auth_reload answers as before")
	eq(reloads, 1, "P auth_reload still reloads")
	eq(has("bert", "interact"), false, "P auth_reload drops every answer")
	-- mobs.has_priv is the delegate (tools/r30_p2 C runs it).
	local api = read("mods/ENTITIES/mobs/api.lua")
	check(api:find("function mobs.has_priv(name, priv)\n\treturn grug_core.has_priv(name, priv)\nend",
		1, true) ~= nil, "P mobs.has_priv delegates to grug_core")
	local input = read("mods/PLAYER/grug_abilities/input.lua")
	check(input:find('grug_core.has_priv(player:get_player_name(), "interact")', 1, true) ~= nil and
		not input:find("check_player_privs", 1, true), "P the input gate asks the cache")
	local damage = read("mods/CORE/grug_core/environment_damage.lua")
	check(damage:find('grug_core.has_priv(player:get_player_name(), "noclip")', 1, true) ~= nil and
		not damage:find("get_player_privs", 1, true), "P environment damage asks the cache")
end

------------------------------------------------------------------------------
-- B: the player body and its writers.
------------------------------------------------------------------------------
local ray_env
do
	ray_env = setmetatable({core = noop_register({registered_nodes = {}}),
		grug_core = {unseen_by = function() return false end}, vector = vector},
		{__index = _G})
	load_into(ray_env, "mods/CORE/grug_core/combat_ray.lua")
	local G = ray_env.grug_core
	local reads = 0
	local function player(eye, box)
		local p = {eye = eye, box = box, offset = vec(0, 0, 0)}
		function p:get_pos() return vec(0, 10, 0) end
		function p:get_eye_offset() return self.offset end
		function p:get_look_dir() return vec(0, 0, 1) end
		function p:get_look_horizontal() return 0 end
		function p:get_properties()
			reads = reads + 1
			return {eye_height = self.eye, collisionbox = self.box, hp_max = 20}
		end
		return p
	end
	local a = player(1.47, {-0.3, 0, -0.3, 0.3, 1.7, 0.3})
	eq(G.combat_eye_pos(a).y, 11.47, "B the eye at the eye height")
	for _ = 1, 99 do G.combat_eye_pos(a) end
	eq(reads, 1, "B 100 eyes, one property read")
	a.eye = 0.8 -- sat down: player_api writes the property and reports it
	eq(G.combat_eye_pos(a).y, 11.47, "B unreported, the cached eye")
	G.player_body_changed(a)
	eq(G.combat_eye_pos(a).y, 10.8, "B reported: the new eye")
	eq(reads, 2, "B one read after the report")
	local b = player(1.2, nil)
	eq(G.combat_eye_pos(b).y, 11.2, "B another ObjectRef has its own body")
	local c = player(nil, nil)
	eq(G.combat_eye_pos(c).y, 11.5, "B no eye height: 1.5 as before")
	eq(G.player_body(a).collisionbox[5], 1.7, "B the box")
	-- The writers: player_api's two property writes, the mount camera.
	local reported = {}
	G.player_body_changed = function(p) reported[#reported + 1] = p end
	local steps, joins = {}, {}
	local api_core = noop_register({
		register_on_joinplayer = function(f) joins[#joins + 1] = f end,
		register_globalstep = function(f) steps[#steps + 1] = f end,
		get_us_time = function() return 0 end,
		get_connected_players = function() return {} end,
	})
	local api_env = setmetatable({core = api_core, minetest = api_core, grug_core = G,
		player_api = {}}, {__index = _G})
	api_env._G = api_env -- player_api looks grug_core up in _G
	load_into(api_env, "mods/BASE/player_api/api.lua")
	local PA = api_env.player_api
	PA.register_model("test.b3d", {animation_speed = 30, textures = {"t.png"},
		animations = {stand = {x = 0, y = 79}, walk = {x = 168, y = 187},
			sit = {x = 81, y = 160, eye_height = 0.8, collisionbox = {-0.3, 0, -0.3, 0.3, 1, 0.3}}},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}, eye_height = 1.47})
	local writes = {}
	local p = {name = "pa"}
	function p:get_player_name() return self.name end
	function p:set_properties(props) writes[#writes + 1] = props end
	function p:set_local_animation() end
	function p:set_animation() end
	function p:play_animation() end
	for _, f in ipairs(joins) do f(p) end
	PA.set_model(p, "test.b3d")
	eq(#reported, 1, "B set_model: the stand class written and reported")
	PA.set_animation(p, "walk")
	eq(#reported, 1, "B walk: the same class, nothing written or reported")
	PA.set_animation(p, "sit")
	eq(#reported, 2, "B sit: a new class, reported")
	check(writes[#writes].eye_height == 0.8 and reported[2] == p, "B the report follows the write")
	PA.set_model(p, "unknown.b3d")
	eq(#reported, 3, "B the fallback model's write is reported")
	local camera = read("mods/PLAYER/grug_mounts/entity.lua"):match(
		"function grug_mounts.apply_camera.-\nend")
	check(camera and camera:find("set_properties({eye_height = first.y})", 1, true) <
		camera:find("player_body_changed(player)", 1, true), "B the mount camera reports its write")
end

------------------------------------------------------------------------------
-- H: homing aims without get_properties per step.
------------------------------------------------------------------------------
do
	local env = setmetatable({core = noop_register({registered_nodes = {}}),
		grug_core = {unseen_by = function() return false end}, vector = vector},
		{__index = _G})
	load_into(env, "mods/CORE/grug_core/combat_ray.lua")
	load_into(env, "mods/CORE/grug_core/homing.lua")
	local G = env.grug_core
	local reads = 0
	local function object(pos, kind, entity)
		local o = {pos = pos, box = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}
		function o:get_pos() return vec(self.pos.x, self.pos.y, self.pos.z) end
		function o:get_velocity() return vec(0, 0, 0) end
		function o:get_attach() return nil end
		function o:is_player() return kind == "player" or kind == "owner" end
		function o:get_hp() return 20 end
		function o:get_player_name() return kind end
		function o:get_luaentity() return entity end
		function o:get_properties()
			reads = reads + 1
			return {collisionbox = self.box}
		end
		return o
	end
	local owner = object(vec(0, 0, 0), "owner")
	local target = object(vec(0, 0, 10), "player")
	local players = {owner = owner, player = target}
	env.core.get_player_by_name = function(name) return players[name] end
	local lock = G.homing_lock(owner, target, vec(0, 1.5, 0), 5)
	local aim = G.homing_step(lock, 0.09)
	eq(aim.y, 0.85, "H the player's box centre")
	for _ = 1, 10 do G.homing_step(lock, 0.09) end
	eq(reads, 1, "H eleven steps, one property read")
	target.box = {-0.3, 0, -0.3, 0.3, 1, 0.3}
	G.player_body_changed(target)
	eq(G.homing_step(lock, 0.09).y, 0.5, "H a reported posture change moves the aim")
	local mob_entity = {health = 10, _grug_cbox = {-0.5, 0, -0.5, 0.5, 2, 0.5}}
	local mob = object(vec(0, 0, 10), "mob", mob_entity)
	reads = 0
	lock = G.homing_lock(owner, mob, vec(0, 1.5, 0), 5)
	eq(G.homing_step(lock, 0.09).y, 1, "H a mob's centre from _grug_cbox")
	mob_entity._grug_cbox = {-0.5, 0, -0.5, 0.5, 1, 0.5}
	eq(G.homing_step(lock, 0.09).y, 0.5, "H a scaled mob: its live box")
	eq(reads, 0, "H no property read for a mob")
	local other = object(vec(0, 0, 10), "thing", {health = 5})
	lock = G.homing_lock(owner, other, vec(0, 1.5, 0), 5)
	G.homing_step(lock, 0.09)
	G.homing_step(lock, 0.09)
	eq(reads, 2, "H another entity reads its properties as before")
end

------------------------------------------------------------------------------
-- S: status_modifier_sum against each_status' order.
------------------------------------------------------------------------------
do
	local now = 1e9
	local env = setmetatable({core = noop_register({get_us_time = function() return now end}),
		grug_core = {}}, {__index = _G})
	-- Round 81 PASSES: the status pass registers through grug_core.
	env.grug_core.register_player_pass = function() end
	load_into(env, "mods/CORE/grug_core/hud_layout.lua")
	load_into(env, "mods/CORE/grug_core/status_icons.lua")
	load_into(env, "mods/CORE/grug_core/status.lua")
	local G = env.grug_core
	local function reference(p, key)
		local total = 0
		for _, record in ipairs(G.each_status(p)) do
			total = total + (record.modifiers[key] or 0)
		end
		return total
	end
	local KEYS = {"armor", "crit_percent", "hp_pool_percent", "mana_pool_percent",
		"spell_damage_percent"}
	local VALUES = {0.1, 0.2, 0.7, 6.1, 18.75, 1, -0.3, 3.3}
	local seed = 81
	local function rand(n)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed % n + 1
	end
	local mismatches, expiries, expected_expiries, cases = 0, 0, 0, 0
	for case = 1, 300 do
		local p = {}
		function p:is_player() return true end
		function p:get_player_name() return "s" .. case end
		for i = 1, rand(7) do
			local modifiers = {}
			for _ = 1, rand(3) do modifiers[KEYS[rand(#KEYS)]] = VALUES[rand(#VALUES)] end
			G.set_status(p, "id" .. rand(9) .. "_" .. i, {duration = rand(4),
				modifiers = modifiers, on_expire = function() expiries = expiries + 1 end})
		end
		-- Some run out before the sum is asked.
		local live_before = #G.each_status(p)
		now = now + 2.5e6
		local key = KEYS[rand(#KEYS)]
		local before = expiries
		local sum = G.status_modifier_sum(p, key)
		local removed = expiries - before
		local live_after = #G.each_status(p)
		expected_expiries = expected_expiries + (live_before - live_after)
		if sum ~= reference(p, key) or removed ~= live_before - live_after then
			mismatches = mismatches + 1
		end
		cases = cases + 1
		now = now + 10e6
	end
	eq(mismatches, 0, "S 300 random status sets: the same sum to the last bit")
	eq(expiries, expected_expiries, "S each expired record's on_expire runs once")
	local p = {}
	function p:is_player() return true end
	function p:get_player_name() return "plain" end
	eq(G.status_modifier_sum(p, "armor"), 0, "S no statuses: 0")
	G.set_status(p, "one", {duration = 5, modifiers = {armor = 6.1}})
	eq(G.status_modifier_sum(p, "armor"), 6.1, "S one carrier: its value")
	eq(G.status_modifier_sum(p, "dodge_percent"), 0, "S an unknown key: 0")
	eq(G.status_modifier_sum(nil, "armor"), 0, "S no player: 0")
end

------------------------------------------------------------------------------
-- E: engage_mob.
------------------------------------------------------------------------------
do
	local marked = 0
	local env = setmetatable({core = noop_register({
		is_player = function(p) return type(p) == "table" and p.is_player ~= nil end,
		get_us_time = function() return 1e9 end,
		settings = {get = function() return nil end, get_bool = function() return nil end},
	}), grug_core = {particles = {play = function() end}},
		grug_mobs = {registered_cadence = {["test:mob"] = true}}, vector = vector},
		{__index = _G})
	load_into(env, "mods/CORE/grug_core/hud_layout.lua")
	load_into(env, "mods/CORE/grug_core/item_names.lua")
	load_into(env, "mods/CORE/grug_core/combat.lua")
	local G = env.grug_core
	G.mark_in_combat = function() marked = marked + 1 end
	local reads = 0
	local function player(name, hp)
		local p = {name = name, hp = hp}
		function p:is_player() return true end
		function p:get_player_name() return self.name end
		function p:get_hp() reads = reads + 1 return self.hp end
		return p
	end
	local function mob(name)
		local object = {}
		function object:get_pos() reads = reads + 1 return vec(0, 0, 0) end
		return {name = name, object = object, health = 10, state = "attack"}
	end
	local a, dead = player("a", 20), player("dead", 0)
	local m = mob("test:mob")
	G.engage_mob(m, dead)
	check(m.temp == nil or m.temp.grug_engaged == nil, "E a dead player engages nothing")
	G.engage_mob(m, a)
	check(m.temp.grug_engaged.a == true, "E a live player engages")
	reads = 0
	for _ = 1, 3 do G.engage_mob(m, a) end
	eq(reads, 0, "E an existing edge: no engine read")
	a.hp = 0
	G.engage_mob(m, a)
	check(m.temp.grug_engaged.a == true, "E an existing edge stays as before")
	local dying = mob("test:mob")
	dying.state = "die"
	G.engage_mob(dying, player("b", 20))
	check(dying.temp == nil or dying.temp.grug_engaged == nil, "E a dying mob engages nothing")
	local untracked = mob("other:thing")
	G.engage_mob(untracked, player("c", 20))
	check(marked == 1 and (untracked.temp == nil or untracked.temp.grug_engaged == nil),
		"E an untracked mob: the 5 s timer, no edge")
	G.engage_mob(nil, player("d", 20))
	eq(marked, 2, "E no mob: the 5 s timer")
end

------------------------------------------------------------------------------
-- J: join slots.
------------------------------------------------------------------------------
do
	local steps, joins, leaves = {}, {}, {}
	local env = setmetatable({grug_core = {}, core = {
		register_globalstep = function(f) steps[#steps + 1] = f end,
		register_on_joinplayer = function(f) joins[#joins + 1] = f end,
		register_on_leaveplayer = function(f) leaves[#leaves + 1] = f end,
	}}, {__index = _G})
	load_into(env, "mods/CORE/grug_core/player_slots.lua")
	local G = env.grug_core
	eq(G.PLAYER_PASS_SLOTS, 8, "J eight slots")
	local visits, elapsed_of, per_tick = {}, {}, {}
	local tick_visits = 0
	G.register_player_pass(1, function(player, elapsed)
		local name = player.name
		visits[name] = (visits[name] or 0) + 1
		elapsed_of[name] = (elapsed_of[name] or 0) + elapsed
		tick_visits = tick_visits + 1
	end)
	local other_slots = {}
	G.register_player_pass(1, function(player) other_slots[#other_slots + 1] = player.name end)
	local function new(name)
		local p = {name = name}
		function p:get_player_name() return self.name end
		for _, f in ipairs(joins) do f(p) end
		return p
	end
	local players = {}
	for i = 1, 100 do players[i] = new("p" .. i) end
	local counts = {}
	for i = 1, 100 do
		local slot = G.player_pass_slot("p" .. i)
		counts[slot] = (counts[slot] or 0) + 1
	end
	local even = true
	for slot = 1, 8 do even = even and (counts[slot] == 12 or counts[slot] == 13) end
	check(even, "J 100 joins: 12 or 13 players per slot")
	local step = steps[1]
	local largest = 0
	for _ = 1, 8 do
		tick_visits = 0
		step(0.125)
		if tick_visits > largest then largest = tick_visits end
		per_tick[#per_tick + 1] = tick_visits
	end
	local once = true
	for i = 1, 100 do once = once and visits["p" .. i] == 1 end
	check(once, "J one period: every player visited once")
	eq(largest, 13, "J at most one slot of players per tick")
	-- The second pass started on another slot.
	check(G.player_pass_slot(other_slots[1]) ~= 1, "J the next pass starts on another slot")
	-- Ten more periods of 0.09 s steps: elapsed adds up to the game time.
	for _ = 1, 112 do step(0.09) end
	local total = 1 + 112 * 0.09
	local close = true
	for i = 1, 100 do
		local name = "p" .. i
		-- Each player's elapsed covers the time up to its last visit, at
		-- most a period behind the clock.
		close = close and elapsed_of[name] <= total + 1e-9 and elapsed_of[name] > total - 1.0001
	end
	check(close, "J elapsed adds up to the game time")
	-- Leaves keep the slots usable; a join takes the emptiest slot.
	for i = 1, 12 do
		local name = "p" .. i
		if G.player_pass_slot(name) == 3 then
			for _, f in ipairs(leaves) do f(players[i]) end
		end
	end
	local three = 0
	for i = 1, 100 do
		if G.player_pass_slot("p" .. i) == 3 then three = three + 1 end
	end
	local fresh = new("late")
	local fewest = math.huge
	local filled = {}
	for i = 1, 100 do
		local slot = G.player_pass_slot("p" .. i)
		if slot then filled[slot] = (filled[slot] or 0) + 1 end
	end
	for slot = 1, 8 do
		if (filled[slot] or 0) < fewest then fewest = filled[slot] or 0 end
	end
	eq(filled[G.player_pass_slot("late")] or 0, fewest, "J a join takes the emptiest slot")
	check(three < 12, "J leavers left their slot")
	eq(G.player_pass_slot("p1") == nil or G.player_pass_slot("p1") ~= 3, true,
		"J a leaver has no slot")
	-- A stall: two ticks (the per-step cap), never a burst; the next visit's
	-- elapsed covers it.
	visits = {}
	tick_visits = 0
	local before = elapsed_of.late or 0
	step(5)
	check(tick_visits <= 26, "J a 5 s stall runs at most two ticks")
	for _ = 1, 8 do step(0.125) end
	check((elapsed_of.late or 0) - before >= 5, "J the stall is in the next elapsed")
	for _, f in ipairs(leaves) do f(fresh) end
	eq(G.player_pass_slot("late"), nil, "J leaving clears the slot")
end

-- J: the cadence at 0.09 s server steps (review of the lane, finding 1): a
-- tick shorter than the step serves one or two slots per step, so a 0.5 s
-- pass keeps its period instead of stretching to 0.72 s.
do
	local steps, joins = {}, {}
	local env = setmetatable({grug_core = {}, core = {
		register_globalstep = function(f) steps[#steps + 1] = f end,
		register_on_joinplayer = function(f) joins[#joins + 1] = f end,
		register_on_leaveplayer = function() end,
	}}, {__index = _G})
	load_into(env, "mods/CORE/grug_core/player_slots.lua")
	local G = env.grug_core
	local fast, slow, fast_elapsed = {}, {}, {}
	local most = 0
	local in_step = {}
	G.register_player_pass(0.5, function(player, elapsed)
		fast[player.name] = (fast[player.name] or 0) + 1
		fast_elapsed[player.name] = (fast_elapsed[player.name] or 0) + elapsed
		in_step[player.name] = (in_step[player.name] or 0) + 1
	end)
	G.register_player_pass(1, function(player)
		slow[player.name] = (slow[player.name] or 0) + 1
	end)
	for i = 1, 16 do
		local p = {name = "q" .. i}
		function p:get_player_name() return self.name end
		for _, f in ipairs(joins) do f(p) end
	end
	local twice = false
	for _ = 1, 1000 do -- 90 s
		in_step = {}
		steps[1](0.09)
		for _, n in pairs(in_step) do
			if n > 1 then twice = true end
		end
		local slots = 0
		for _ in pairs(in_step) do slots = slots + 1 end
		if slots > most then most = slots end
	end
	local fast_ok, slow_ok, sums_ok = true, true, true
	for i = 1, 16 do
		local name = "q" .. i
		-- 90 s: 180 visits at 0.5 s (the old code: 125), 90 at 1 s.
		fast_ok = fast_ok and fast[name] >= 179 and fast[name] <= 181
		slow_ok = slow_ok and slow[name] >= 89 and slow[name] <= 91
		sums_ok = sums_ok and fast_elapsed[name] > 90 - 0.5 - 1e-6 and
			fast_elapsed[name] <= 90 + 1e-6
	end
	check(fast_ok, "J 0.5 s pass at 0.09 s steps: two visits per player per second")
	check(slow_ok, "J 1 s pass at 0.09 s steps: one visit per player per second")
	check(sums_ok, "J 0.5 s pass: elapsed still adds up to the game time")
	check(not twice, "J no player twice in one step")
	check(most <= 4, "J at most two slots (of 16 players: 4) per step")
end

------------------------------------------------------------------------------
-- R: ruling 2, a relog keeps cooldowns, charges and the mana value.
------------------------------------------------------------------------------
local M = dofile(ROOT .. "/tools/r81_hot/measure.lua")
do
	local box = M.abilities_sandbox(ROOT)
	local G = box.env.grug_abilities
	local function fire(kind, p)
		for _, fn in ipairs(box.callbacks[kind] or {}) do
			local source = debug.getinfo(fn, "S").source
			if source:find("grug_abilities/init%.lua$") or source:find("crosshair%.lua$") or
					source:find("cooldown_hud%.lua$") or source:find("input%.lua$") then
				fn(p)
			end
		end
	end
	local mana_table
	for i = 1, 20 do
		local name, value = debug.getupvalue(G.get_mana, i)
		if name == "mana" then mana_table = value break end
		if not name then break end
	end
	check(mana_table ~= nil, "R the mana table")
	local SPRINT = {cooldown_key = "r81_sprint"}
	local SHORT = {cooldown_key = "r81_short"}
	local BLOW = {cooldown_key = "r81_blow", charge = 10}
	local first = box.new_player("relog", "mage")
	fire("join", first)
	eq(G.get_mana(first), 1000, "R a first join fills mana")
	mana_table.relog = 123.5
	G.arm_cooldown(first, SPRINT, 300)
	G.arm_cooldown(first, SHORT, 2)
	G.reset_charge(first, BLOW)
	box.advance(5e6)
	check(G.ready(first, "r81_short") and not G.ready(first, "r81_sprint"), "R the clocks run")
	fire("leave", first)
	local second = box.new_player("relog", "mage")
	fire("join", second)
	check(not G.ready(second, "r81_sprint"), "R a relog keeps Sprint's cooldown")
	check(G.ready(second, "r81_short"), "R an expired cooldown stays expired")
	check(not G.charge_ready(second, BLOW), "R a relog keeps the charge")
	eq(G.get_mana(second), 123, "R a relog keeps the mana value")
	local hud = G.cooldown_hud.state("relog")
	check(hud and hud.timers.r81_sprint and hud.timers.r81_blow and not hud.timers.r81_short,
		"R the running timers are on the overlay again")
	box.advance(300e6)
	check(G.ready(second, "r81_sprint") and G.charge_ready(second, BLOW), "R and run out in time")
	-- Death keeps the cooldowns (unchanged).
	G.arm_cooldown(second, SPRINT, 300)
	fire("die", second)
	check(not G.ready(second, "r81_sprint"), "R death keeps the cooldowns")
	-- A smaller pool at the rejoin clamps the kept value.
	fire("leave", second)
	local third = box.new_player("relog", "mage")
	third.max_mana = 100
	fire("join", third)
	eq(G.get_mana(third), 100, "R the kept mana clamps to the pool")
	check(not G.ready(third, "r81_sprint"), "R the second relog keeps it too")
	-- Another name gets nothing of it; the kept record is used once.
	local other = box.new_player("someone", "mage")
	fire("join", other)
	check(G.ready(other, "r81_sprint") and G.get_mana(other) == 1000, "R another name starts fresh")
	-- The departed-player table holds only what a join would restore.
	local kept_table
	for _, fn in ipairs(box.callbacks.leave or {}) do
		if debug.getinfo(fn, "S").source:find("grug_abilities/init%.lua$") then
			for i = 1, 60 do
				local name, value = debug.getupvalue(fn, i)
				if not name then break end
				if name == "kept" then kept_table = value end
			end
		end
	end
	check(kept_table ~= nil, "R the kept table")
	local idle = box.new_player("idle", "mage")
	fire("join", idle)
	eq(G.get_mana(idle), 1000, "R idle: full mana")
	fire("leave", idle)
	eq(kept_table.idle, nil, "R a full-mana leave with no timer keeps nothing")
	local spent = box.new_player("spent", "mage")
	fire("join", spent)
	mana_table.spent = 400
	fire("leave", spent)
	check(kept_table.spent and kept_table.spent.mana == 400, "R a spent pool is kept")
	local timed = box.new_player("timed", "mage")
	fire("join", timed)
	G.arm_cooldown(timed, SHORT, 2)
	fire("leave", timed)
	check(kept_table.timed and kept_table.timed.mana == nil and kept_table.timed.cooldowns,
		"R full mana with a running timer keeps the timer only")
	box.advance(3e6)
	local passer = box.new_player("passer", "mage")
	fire("join", passer)
	fire("leave", passer)
	eq(kept_table.timed, nil, "R a later leave drops the run-out record")
	check(kept_table.spent ~= nil, "R the kept mana stays")
	-- A rage class: rage 0 at the join as before.
	local warrior = box.new_player("w", "warrior")
	fire("join", warrior)
	fire("leave", warrior)
	local back = box.new_player("w", "warrior")
	fire("join", back)
	eq(G.get_rage and G.get_rage(back) or 0, 0, "R rage starts at 0")
end

------------------------------------------------------------------------------
-- M: the call counts on this tree (tools/r81_hot/measure.lua).
------------------------------------------------------------------------------
do
	local n = M.measure(ROOT)
	eq(n.input.wield, 1100, "M input: one wielded-item copy per player and pass")
	eq(n.input.privs, 100, "M input: one privilege lookup per player")
	eq(n.env.props, 145, "M env: one body read per player, the pool only for a tick that hurts")
	eq(n.env.privs, 10, "M env: `noclip` only for the ten stone heads, once each")
	eq(n.env.hurt, 5, "M env: the five stone heads without noclip are hurt")
	eq(n.eye.props, 1, "M eye: one property read for 670 eyes")
	eq(n.homing.props, 1, "M homing: one read for the player lock, none for the mob")
	check(n.homing.player_aim_y == 0.85 and n.homing.mob_aim_y == 0.5, "M homing: the same aims")
	eq(n.status.armor, 0.2 * 30.5 + 0.5 * 37.5, "M status: the armour sum")
	eq(n.status.sorts, 25000, "M status: a sort only for the key two statuses carry")
	eq(n.engage.reads, 0, "M engage: no engine read on an engaged mob")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R81 HOT PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print("R81 HOT PORTABLE PASS checks=" .. checks)
