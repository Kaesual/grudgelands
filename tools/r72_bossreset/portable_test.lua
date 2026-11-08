-- Round 72 lane BOSSRESET portable test (LuaJIT): the reset of kings, Generals and
-- bosses (round72-plan.md §2.3, §4 BOSSRESET). Loads the REAL code on a small fake
-- engine (a node grid): mobs/grug_obstacle.lua and mobs/grug_nav.lua in full,
-- grug_core/combat.lua in full (threat, taunt, engagement), grug_mobs/aggro.lua and
-- grug_mobs/boss_floor.lua in full, grug_expeditions/packs.lua in full, and cut out
-- of bosses.lua the royal reset (boss_leash_reset, royal_reset with the whole-retinue
-- test) and of grug_expeditions/encounters.lua the boss room. Checks:
--   F  the floor: one fill from a throne seat over flat floor, a dais, stairs to a
--      balcony over the ground floor (floors above each other), through a door and a
--      2-high doorway, not through a 1-high gap, into a sealed room or onto a pillar,
--      bounded by the 30 m leash radius; "within reach" of the floor; the cell count
--      and the fill's and the check's time (measured here, LuaJIT, fake nodes);
--   L  a melee and a ranged king against a target on a ledge and out of range:
--      reset at once (healed, threat, ledger and retinue, evade home); a ranged king's
--      locked shots do not hold it; a target on a low block in reach holds;
--   S  a step over the leash line and back: reset, and walking back saves nothing;
--   Q  the 15 s rule: a safe spot while Shatter fires at nobody (the clock runs) and
--      when it catches a player (it holds), a dodged hit counts, the rift boss, not an
--      elite, not a dragon;
--   T  a tank swap by Taunt inside 3 s keeps the fight; without one, or a Taunt by the
--      one who left, the reset comes at 3 s; the window is no evade;
--   O  a logout counts as leaving (alone: reset at once), a death does not;
--   G  a General in his room; an Expedition boss in its room (the template's
--      envelope): the room is its range, the navigation's give-up jumps nothing, a
--      leaver leaves the list, the reset is the pack's wipe;
--   N  the navigation's give-up: with a floor it decides nothing, without one it is
--      the "no way";
--   C  search counts: a king against a ledge target and against a target behind a
--      shut door over 30 s (the fake engine's searches; `--before=FILE` runs the same
--      scenes on an older aggro.lua for the comparison).
-- Usage (repo root): luajit tools/r72_bossreset/portable_test.lua [REPO] [--before=FILE]
-- Prints "R72 BOSSRESET PORTABLE PASS checks=<n>" or raises.
local repo, before = ".", nil
for _, a in ipairs(arg) do
	local b = a:match("^%-%-before=(.+)$")
	if b then before = b else repo = a end
end
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
local function cut(text, from, to, label)
	local a = text:find(from, 1, true)
	check(a ~= nil, label .. ": start anchor")
	local b, e = text:find(to, a, true)
	check(b ~= nil, label .. ": end anchor")
	return text:sub(a, e)
end
local function load_in(source, env, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

-- ---------------------------------------------------------------------------
-- The fake engine: a node grid (unset is air, at or below y 0 stone), a clock.
-- ---------------------------------------------------------------------------
local us = 1000000
local function advance(seconds) us = us + math.floor(seconds * 1e6 + 0.5) end
local world = {}
local LIMIT = 600
local function wkey(x, y, z) return x .. "," .. y .. "," .. z end
local function fill(x1, y1, z1, x2, y2, z2, name)
	for x = math.min(x1, x2), math.max(x1, x2) do
		for y = math.min(y1, y2), math.max(y1, y2) do
			for z = math.min(z1, z2), math.max(z1, z2) do world[wkey(x, y, z)] = name end
		end
	end
end
local function name_at(x, y, z)
	local n = world[wkey(x, y, z)]
	if n then return n end
	return y <= 0 and "stone" or "air"
end
local function round(v) return math.floor(v + 0.5) end
local function vec(x, y, z) return {x = x, y = y, z = z} end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return vec(x.x, x.y, x.z) end
		return vec(x, y, z)
	end,
	add = function(a, n) return vec(a.x + n, a.y + n, a.z + n) end,
	subtract = function(a, n) return vec(a.x - n, a.y - n, a.z - n) end,
	distance = function(a, b)
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
	end,
}
local NODES = {
	air = {name = "air", walkable = false},
	stone = {name = "stone", walkable = true},
	["doors:door_wood_a"] = {name = "doors:door_wood_a", walkable = true},
	["doors:hidden"] = {name = "doors:hidden", walkable = true},
}
doors = {registered_doors = {["doors:door_wood_a"] = true}}
local players = {}
local callbacks = {die = {}, leave = {}, join = {}}
local add_entity -- below
core = {
	registered_nodes = NODES,
	get_us_time = function() return us end,
	is_player = function(obj)
		return type(obj) == "table" and obj.is_player ~= nil and obj:is_player()
	end,
	get_player_by_name = function(name) return players[name] end,
	get_node_or_nil = function(pos)
		if math.abs(pos.x) > LIMIT or math.abs(pos.z) > LIMIT then return nil end
		return {name = name_at(round(pos.x), round(pos.y), round(pos.z))}
	end,
	get_node = function(pos) return {name = name_at(round(pos.x), round(pos.y), round(pos.z))} end,
	load_area = function() end,
	log = function() end,
	after = function() end,
	serialize = function(t) return t end,
	add_entity = function(...) return add_entity(...) end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
}
setmetatable(core, {__index = function(_, k)
	if type(k) == "string" and k:match("^register_") then return function() end end
	return nil
end})
local searches = 0
local function walkable(x, y, z)
	local def = NODES[name_at(x, y, z)]
	return not def or def.walkable == true
end
-- A plain grid search modelled on the engine's (r72_ranged's, shortened): walkable
-- ends refused, steps of one up and drops.
function core.find_path(from, to, pad, jump, drop)
	searches = searches + 1
	if walkable(from.x, from.y, from.z) or walkable(to.x, to.y, to.z) then return nil end
	local x1, x2 = math.min(from.x, to.x) - pad, math.max(from.x, to.x) + pad - 1
	local z1, z2 = math.min(from.z, to.z) - pad, math.max(from.z, to.z) + pad - 1
	local seen, queue, first = {[wkey(from.x, from.y, from.z)] = {}}, {from}, 1
	while first <= #queue do
		local c = queue[first]
		first = first + 1
		if c.x == to.x and c.y == to.y and c.z == to.z then
			local rev, k = {}, wkey(c.x, c.y, c.z)
			while k do
				local e = seen[k]
				rev[#rev + 1] = e.cell or from
				k = e.from
			end
			local path = {}
			for i = #rev, 1, -1 do path[#path + 1] = rev[i] end
			return path
		end
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z, y = c.x + d[1], c.z + d[2], c.y
			if x >= x1 and x <= x2 and z >= z1 and z <= z2 then
				local ny
				if not walkable(x, y, z) then
					local yy = y
					while yy > y - drop - 1 and not walkable(x, yy - 1, z) do yy = yy - 1 end
					if walkable(x, yy - 1, z) and y - yy <= drop then ny = yy end
				elseif not walkable(x, y + 1, z) and not walkable(c.x, c.y + 1, c.z) then
					ny = y + 1
				end
				if ny and not seen[wkey(x, ny, z)] then
					seen[wkey(x, ny, z)] = {from = wkey(c.x, c.y, c.z), cell = vec(x, ny, z)}
					queue[#queue + 1] = vec(x, ny, z)
				end
			end
		end
	end
	return nil
end

local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
nav.init({obstacle = O, max_jump = 4, max_drop = 6})
mobs = {grug_nav = nav}

-- ---------------------------------------------------------------------------
-- The real combat state, leash, boss rules and packs.
-- ---------------------------------------------------------------------------
grug_core = {}
local tracked = {}
grug_mobs = {registered_cadence = tracked}
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
grug_core.death_message = function(name) return "fled", name .. " fled" end
grug_core.damage_source = function(object)
	local ent = object and object.get_luaentity and object:get_luaentity()
	return ent and ent._grug_source or object
end
-- homing.lua's lock, reduced: sight and range are the scene's word.
local lock_ok = true
grug_core.actor_projectile_lock = function() return lock_ok and {} or nil end

local stats = {encounter_resets = 0, attempt_resets = 0, summons_removed = 0}
grug_mobs.give_up_stuck = function() end
grug_mobs.idle_health_tick = function() end
grug_mobs.walk_toward = function() end
grug_mobs.walk_fixed = function() end
grug_mobs.walk_follow = function() end
grug_mobs.walk_clear = function() end
grug_mobs.roam_avoid_tick = function() end
grug_mobs.in_swimmer_reach = function() return true end
grug_mobs.touch_boss_activity = function() end
grug_mobs.place_on_ground = function(object, pos) object:set_pos(pos) end
grug_mobs.set_tier = function(ent, tier) ent._grug_tier = tier end
grug_mobs.ensure_init = function() end
grug_mobs.settle_mob_death = function() return true end
grug_mobs.live_claim = function() return true end
grug_mobs.boss_attempt_reset = function() stats.attempt_resets = stats.attempt_resets + 1 end
grug_mobs.royal_encounter_reset = function(self)
	stats.encounter_resets = stats.encounter_resets + 1
	grug_mobs.boss_attempt_reset(self._grug_boss_id)
end

local aggro_path = before or (repo .. "/mods/ENTITIES/grug_mobs/aggro.lua")
dofile(aggro_path)
if not before then
	dofile(repo .. "/mods/ENTITIES/grug_mobs/boss_floor.lua")
end
local F = grug_mobs.boss_floor

-- The royal reset, cut out of bosses.lua.
local retinue = {} -- the scene's retinue members (luaentity tables)
do
	local bosses = read("mods/ENTITIES/grug_mobs/bosses.lua")
	load_in("local royal_reset\n" ..
		cut(bosses, "local ROYAL_RETINUE = 2", "\tremove_royal_summons(self)\nend\n", "royal_reset") ..
		"\n" .. cut(bosses, "function grug_mobs.boss_leash_reset(self)", "\nend\n", "boss_leash_reset"),
		{grug_mobs = grug_mobs,
			royal_objects = function() return retinue end,
			remove_royal_summons = function() stats.summons_removed = stats.summons_removed + 1 end},
		"royal reset")
end

-- ---------------------------------------------------------------------------
-- Mobs and players.
-- ---------------------------------------------------------------------------
local mob_class = {}
local mob_mt = {__index = mob_class}
function mob_class:do_attack(player, force)
	if self.state == "attack" and not force then return end
	self.attack, self.state = player, "attack"
	grug_core.engage_mob(self, player)
	if self._grug_pack and grug_mobs.pack_contact then grug_mobs.pack_contact(self, player) end
end
function mob_class:stop_attack()
	grug_core.disengage_target(self, self.attack)
	self.attack, self.state = nil, "stand"
end
function mob_class:update_tag() end

local function new_mob(name, pos, fields)
	local m = setmetatable({name = name, state = "stand", health = 1000, hp_max = 1000,
		attack_type = "dogfight", reach = 3, view_range = 18, temp = {}, jump_height = 4, damage = 10,
		fear_height = 4, initial_properties = {stepheight = 1.1}}, mob_mt)
	local at = vector.new(pos)
	m.object = {
		get_pos = function() return at and vector.new(at) end,
		set_pos = function(_, p) at = vector.new(p) end,
		set_velocity = function() end,
		set_properties = function() end,
		get_luaentity = function() return at and m or nil end,
		remove = function() at = nil end,
		is_player = function() return false end,
	}
	for k, v in pairs(fields or {}) do m[k] = v end
	tracked[name] = true
	return m
end

-- A king's live box: his definition's, the elite size and the physics cut (2.72 tall
-- to look at, 1.95 to walk).
local S = 8 / 7 * 1.4
local KING_BOX = O.physics_box({-0.3 * S, 0, -0.3 * S, 0.3 * S, 1.7 * S, 0.3 * S})
local function new_king(id, seat, fields)
	local m = new_mob("grug_mobs:" .. id:gsub(":", "_"), seat, {type = "npc",
		_grug_royal_king = true, _grug_royal_race = "human", _grug_boss_id = id,
		_grug_home = vector.new(seat),
		_grug_leash_range = 30, _grug_cbox = KING_BOX, _grug_tier = "elite"})
	for k, v in pairs(fields or {}) do m[k] = v end
	return m
end

local function new_player(name, pos)
	local p = {name = name, pos = vector.new(pos), hp = 20}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return self.pos and vector.new(self.pos) end
	function p:get_hp() return self.hp end
	function p:get_luaentity() return nil end
	function p:get_attach() return nil end
	-- A mob's punch: the engine's hp change runs the central modifier, whose first
	-- step marks the hit (before the dodge roll).
	function p:punch(source) grug_core.mark_player_hit(self, source) end
	function p:add_velocity() end
	function p:get_properties() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3}} end
	players[name] = p
	return p
end
local function logout(p)
	for _, fn in ipairs(callbacks.leave) do fn(p) end
	players[p.name] = nil
	function p:is_player() return false end
	function p:get_player_name() return "" end
	function p:get_pos() return nil end
end
local function kill(p)
	p.hp = 0
	for _, fn in ipairs(callbacks.die) do fn(p) end
end

local DT = 0.25
local function step(mob, seconds)
	for _ = 1, math.floor(seconds / DT + 0.5) do
		advance(DT)
		grug_mobs.leash_tick(mob, DT)
	end
end
-- Steps until the floor is ready (its fill spread over steps).
local function settle_floor(mob)
	local n = 0
	while not grug_mobs.boss_floor_of(mob) and n < 400 do
		grug_mobs.leash_tick(mob, 0)
		n = n + 1
	end
	return grug_mobs.boss_floor_of(mob), n
end
local in_combat = grug_core.in_combat
local function feet(x, y, z) return vec(x, y - 0.5, z) end -- the feet position on cell y
local function healthy(m) return m.health == m.hp_max end
local function evading(m) return m.temp.grug_evading ~= nil end

-- ---------------------------------------------------------------------------
-- F. The floor.
-- ---------------------------------------------------------------------------
local hall_cells, hall_us
if not before then
	-- A throne hall round the seat (0, 1, 0), floor top at y 0.
	fill(-3, 1, -3, -1, 1, -1, "stone")            -- a dais, one node
	fill(10, 1, 0, 10, 3, 0, "stone")              -- a pillar, top cell 4
	fill(12, 1, 3, 12, 2, 3, "stone")              -- a low block, top cell 3
	for k = 1, 5 do fill(4 + k, 1, 9, 4 + k, k, 9, "stone") end -- stairs, top cells 2..6
	fill(10, 5, 8, 14, 5, 14, "stone")             -- a balcony over the floor, cell 6
	fill(-5, 1, -10, 5, 3, -10, "stone")           -- a wall with a door
	world[wkey(0, 1, -10)], world[wkey(0, 2, -10)] = "doors:door_wood_a", "doors:hidden"
	fill(-12, 1, -8, -12, 3, 8, "stone")           -- a wall with a 2-high doorway at z 0
	world[wkey(-12, 1, 0)], world[wkey(-12, 2, 0)] = nil, nil
	fill(-12, 1, 12, -12, 3, 20, "stone")          -- and one with a 1-high gap at z 16
	fill(-20, 1, 12, -12, 3, 12, "stone")
	fill(-20, 1, 20, -12, 3, 20, "stone")
	fill(-20, 1, 12, -20, 3, 20, "stone")
	world[wkey(-12, 1, 16)] = nil
	fill(20, 1, -4, 24, 3, -4, "stone")            -- a sealed room
	fill(20, 1, 4, 24, 3, 4, "stone")
	fill(20, 1, -4, 20, 3, 4, "stone")
	fill(24, 1, -4, 24, 3, 4, "stone")
	fill(20, 4, -4, 24, 4, 4, "stone")

	local king = new_king("king:human", feet(0, 1, 0))
	local t0 = os.clock()
	local cells, steps = settle_floor(king)
	hall_us = (os.clock() - t0) * 1e6
	check(cells ~= nil, "F1 the floor is ready")
	local entry = grug_mobs.boss_floors["king:human"]
	hall_cells = entry.count
	check(steps > 1, "F1 the fill is spread over steps: " .. steps)
	local K = F.key
	check(cells[K(0, 1, 0)] and cells[K(29, 1, 0)] and not cells[K(31, 1, 0)],
		"F2 bounded by the 30 m leash radius round the seat")
	check(cells[K(-2, 2, -2)] and not cells[K(-2, 1, -2)], "F3 the dais: up one step")
	check(cells[K(12, 6, 12)] and cells[K(12, 1, 12)], "F4 the balcony over the ground floor")
	check(cells[K(9, 6, 9)], "F4 up the stairs")
	check(not cells[K(10, 4, 0)] and not cells[K(12, 3, 3)], "F5 not onto the pillar or the block")
	check(cells[K(0, 1, -12)], "F6 through the door")
	check(cells[K(-15, 1, 0)], "F7 through a 2-high doorway")
	check(not cells[K(-16, 1, 16)], "F8 not through a 1-high gap")
	check(not cells[K(22, 1, 0)], "F9 not into a sealed room")
	-- within reach: the low block (2 up, 1 aside) yes, the pillar (3 up) no
	check(F.holds(cells, vec(12, 2.5, 3), 3), "F10 a target on a low block is within reach")
	check(not F.holds(cells, vec(10, 3.5, 0), 3), "F10 a target on the pillar is not")
	check(F.holds(cells, vec(3, 1.7, 3), 3), "F10 a jumping target is")
	-- the check's cost: one lookup on the floor, (2r+1)^3 off it
	local n = 20000
	t0 = os.clock()
	for _ = 1, n do F.holds(cells, vec(3, 0.5, 3), 3) end
	local on_us = (os.clock() - t0) * 1e6 / n
	t0 = os.clock()
	for _ = 1, n do F.holds(cells, vec(10, 3.5, 0), 3) end
	local off_us = (os.clock() - t0) * 1e6 / n
	print(("  F hall: %d cells in %d steps, fill %.0f us (fake nodes); check on the floor %.2f us, off it %.2f us")
		:format(hall_cells, steps, hall_us, on_us, off_us))
	grug_mobs.boss_floor_forget("king:human")
	check(grug_mobs.boss_floors["king:human"] == nil, "F11 a floor can be forgotten")
	-- A seat the body cannot stand on: no floor, nothing breaks.
	local stuck = new_king("king:stuck", feet(20, 2, 0)) -- inside the sealed room's wall
	settle_floor(stuck)
	check(grug_mobs.boss_floor_of(stuck) == nil and grug_mobs.boss_floors["king:stuck"].count == 0,
		"F12 a seat the body does not stand on gives no floor")
	-- A fill that meets nodes not loaded (past the fake world's edge) is not used,
	-- and runs again RETRY seconds later.
	local edge = new_king("king:edge", feet(LIMIT - 10, 1, 0))
	settle_floor(edge)
	check(grug_mobs.boss_floor_of(edge) == nil and grug_mobs.boss_floors["king:edge"].retry ~= nil,
		"F13 a fill that met unloaded nodes is not used")
	LIMIT = LIMIT + 100
	advance(5)
	settle_floor(edge)
	check(grug_mobs.boss_floor_of(edge) == nil, "F13 not before its retry")
	advance(5)
	settle_floor(edge)
	check(grug_mobs.boss_floor_of(edge) ~= nil, "F13 loaded later: it runs again and is used")
	LIMIT = LIMIT - 100
end

-- A flat arena for the rules: the seat at (100, 1, 100), a pillar 5 high at (110, *, 100).
local SEAT = feet(100, 1, 100)
fill(110, 1, 100, 110, 4, 100, "stone")
local king_n = 0
local function fresh_king(fields)
	king_n = king_n + 1
	local k = new_king("king:arena" .. king_n, SEAT, fields)
	if not before then settle_floor(k) end
	k.object:set_pos(vec(105, 0.5, 100)) -- off the seat: a reset runs him home
	retinue = {{health = 10, hp_max = 10}, {health = 10, hp_max = 10}}
	return k
end
local function pull(king, player, amount)
	grug_core.run_player_hit_mob(player, king, amount or 50)
	king:do_attack(player, true)
	king.health = king.health - (amount or 50)
end

if not before then
-- ---------------------------------------------------------------------------
-- L. Ledge and range: a melee and a ranged king.
-- ---------------------------------------------------------------------------
for _, kind in ipairs({"dogfight", "dogshoot"}) do
	local king = fresh_king({attack_type = kind})
	local mage = new_player("mage_" .. kind, vec(104, 0.5, 100))
	pull(king, mage)
	step(king, 2)
	check(king.attack == mage and in_combat(mage) and not evading(king),
		"L1 " .. kind .. ": a target on the floor holds")
	mage.pos = vec(110, 4.5, 100) -- onto the pillar
	if kind == "dogshoot" then grug_mobs.boss_attacked(king) end -- a shot with sight
	local resets = stats.attempt_resets
	step(king, 1)
	check(king.attack == nil and healthy(king) and king.temp.grug_threat == nil,
		"L2 " .. kind .. ": a ledge target: reset at once, healed, threat cleared")
	check(stats.attempt_resets > resets and not in_combat(mage), "L2 " .. kind .. ": ledger cleared, out of combat")
	check(grug_mobs.gave_up_on(king, mage), "L2 " .. kind .. ": not taken again by sight for now")
	players[mage.name] = nil
	-- out of range on open ground
	king = fresh_king({attack_type = kind})
	local far = new_player("far_" .. kind, vec(129, 0.5, 100))
	pull(king, far)
	step(king, 2)
	check(king.attack == far, "L3 " .. kind .. ": 29 m from the seat holds")
	far.pos = vec(134, 0.5, 100) -- past the line and the reach from it
	king.object:set_pos(vec(126, 0.5, 100)) -- he followed
	step(king, 1)
	check(king.attack == nil and healthy(king) and evading(king),
		"L4 " .. kind .. ": out of range: reset, the evade home from where he stands")
	players[far.name] = nil
end
-- The retinue: whole and healthy it stays, hurt it is restored.
do
	local king = fresh_king()
	local p = new_player("rp", vec(104, 0.5, 100))
	pull(king, p)
	local before_resets = stats.encounter_resets
	p.pos = vec(110, 4.5, 100)
	step(king, 1)
	check(stats.encounter_resets == before_resets and stats.summons_removed > 0,
		"L5 a whole retinue stays as it is (the summons go)")
	king.object:set_pos(SEAT)
	king.temp.grug_evading = nil
	retinue[1].health = 5
	p.pos = vec(104, 0.5, 100)
	king.temp.grug_gave_up = nil
	pull(king, p)
	p.pos = vec(110, 4.5, 100)
	step(king, 1)
	check(stats.encounter_resets == before_resets + 1, "L5 a hurt retinue is restored")
	players.rp = nil
end
-- A signature winding up when he resets never lands.
do
	local king = fresh_king()
	local p = new_player("cast", vec(104, 0.5, 100))
	pull(king, p)
	king.temp.grug_royal_cast = {left = 1}
	p.pos = vec(110, 4.5, 100)
	step(king, 1)
	check(king.temp.grug_royal_cast == nil, "L6 a reset cancels the wind-up")
	players.cast = nil
end

-- ---------------------------------------------------------------------------
-- S. A step over the leash line and back.
-- ---------------------------------------------------------------------------
do
	local king = fresh_king()
	local p = new_player("stepper", vec(125, 0.5, 100))
	pull(king, p)
	step(king, 1)
	check(king.attack == p, "S1 inside the line")
	p.pos = vec(134, 0.5, 100)
	advance(0.25)
	grug_mobs.leash_tick(king, 0.25) -- no full second yet
	p.pos = vec(129, 0.5, 100) -- back before the check: never left
	step(king, 1)
	check(king.attack == p, "S2 back inside before the once-a-second test")
	p.pos = vec(134, 0.5, 100)
	king.object:set_pos(vec(120, 0.5, 100))
	step(king, 1)
	check(king.attack == nil and healthy(king) and evading(king), "S3 over the line: reset")
	p.pos = vec(129, 0.5, 100)
	step(king, 1)
	check(king.attack == nil and evading(king) and king.temp.grug_threat == nil,
		"S4 walking back saves nothing")
	-- the evader takes nobody, and a hit on it is no threat
	grug_core.add_threat(king, p, 100)
	check(king.temp.grug_threat == nil, "S4 the evader gains no threat")
	players.stepper = nil
end

-- ---------------------------------------------------------------------------
-- Q. The 15 s rule.
-- ---------------------------------------------------------------------------
-- The kings' Shatter, cut out of bosses.lua: a punch for each player in its area.
local hit_players
do
	local bosses = read("mods/ENTITIES/grug_mobs/bosses.lua")
	hit_players = load_in(cut(bosses, "local function hit_players(", "\nend\n", "hit_players") ..
		"\nreturn hit_players", {
			player_enemy_of = function() return true end,
			core = setmetatable({get_objects_inside_radius = function(pos, r)
				local out = {}
				for _, p in pairs(players) do
					if vector.distance(pos, p:get_pos()) <= r then out[#out + 1] = p end
				end
				return out
			end, yaw_to_dir = function() return vec(1, 0, 0) end}, {__index = core}),
		}, "hit_players")
end
do
	-- A safe spot on the floor the king does not get to, out of Shatter's 6.
	local king = fresh_king()
	king.get_yaw = function() return 0 end
	local p = new_player("safe", vec(104, 0.5, 100))
	pull(king, p)
	p.pos = vec(108, 0.5, 108)
	for second = 1, 15 do
		if second % 8 == 0 then hit_players(king, 6, 3, false, 8) end -- casts at nobody
		step(king, 1)
		check(king.attack == p, "Q1 the clock runs, second " .. second)
	end
	step(king, 1)
	step(king, 1)
	check(king.attack == nil and healthy(king), "Q1 15 s without an attack: reset")
	players.safe = nil

	-- Shatter that catches a player, a dodged swing and a locked shot hold the clock.
	king = fresh_king()
	king.get_yaw = function() return 0 end
	local tank = new_player("tank", vec(102, 0.5, 100))
	pull(king, tank)
	for second = 1, 40 do
		if second % 12 == 0 then hit_players(king, 6, 3, false, 8) end
		if second % 12 == 5 then tank:punch(king.object) end -- dodged or not: marked
		if second % 12 == 9 then grug_core.actor_projectile_lock(king.object) end
		step(king, 1)
	end
	check(king.attack == tank and not healthy(king), "Q2 attacks every few seconds: no reset in 40 s")
	-- a projectile's hit counts as its shooter's
	local arrow = {get_luaentity = function() return {_grug_source = king.object} end,
		is_player = function() return false end}
	king.temp.grug_boss_attack_at = 0
	tank:punch(arrow)
	check(king.temp.grug_boss_attack_at > 0, "Q3 an arrow's hit is its shooter's attack")
	players.tank = nil

	-- the rift boss: the clock only; an elite and a dragon: nothing
	local rift = new_mob("grug_mobs:rift_boss", vec(300, 0.5, 300), {type = "monster",
		_grug_boss_id = "rift:site", _grug_home = vec(300, 0.5, 300), _grug_tier = "elite"})
	local r = new_player("riftp", vec(304, 0.5, 300))
	pull(rift, r)
	-- hit all along, so its contact leash never fires: the 15 s rule alone
	for second = 1, 16 do
		if second % 3 == 0 then grug_core.run_player_hit_mob(r, rift, 1) end
		step(rift, 1)
	end
	check(rift.attack == r, "Q4 the rift boss holds through 15 s")
	step(rift, 1)
	check(rift.attack == nil and healthy(rift), "Q4 ... and resets after them, hit or not")
	check(grug_mobs.reset_boss_kind(rift) == "clock" and grug_mobs.boss_floor_of(rift) == nil,
		"Q4 no floor for the rift boss")
	for _, fields in ipairs({{_grug_tier = "elite"}, {_grug_boss_id = "dragon:x"},
			{_grug_boss_id = "king:arena1", _grug_royal_race = "human"}}) do
		local m = new_mob("grug_mobs:other", vec(300, 0.5, 340), fields)
		check(grug_mobs.reset_boss_kind(m) == nil, "Q5 no reset rules for " .. next(fields))
	end
	players.riftp = nil
end

-- ---------------------------------------------------------------------------
-- T. The window: a tank swap by Taunt.
-- ---------------------------------------------------------------------------
local function taunt(king, p)
	check(grug_core.taunt(king, p), "T taunt accepted")
	king:do_attack(p, true)
end
for _, case in ipairs({"taunt", "none", "leaver"}) do
	local king = fresh_king()
	local a = new_player("a_" .. case, vec(104, 0.5, 100))
	local b = new_player("b_" .. case, vec(96, 0.5, 100))
	pull(king, b, 20)
	pull(king, a, 80) -- a has the threat
	step(king, 1)
	check(king.attack == a, "T0 " .. case .. ": a is the target")
	a.pos = vec(110, 4.5, 100)
	step(king, 1)
	local window = king.temp.grug_boss_window
	check(window ~= nil and not evading(king) and (king.temp.grug_threat[a.name] or 0) == 0,
		"T1 " .. case .. ": a left: threat zero, the window opens, no evade")
	check(not healthy(king), "T1 nothing reset yet")
	a.pos = vec(104, 0.5, 100) -- walks back: nothing saved
	if case == "taunt" then
		step(king, 1)
		taunt(king, b)
		step(king, 4)
		check(king.attack == b and not healthy(king) and king.temp.grug_boss_window == nil,
			"T2 a Taunt by another player inside 3 s keeps the fight (a tank swap)")
	elseif case == "leaver" then
		step(king, 1)
		taunt(king, a)
		step(king, 2.5)
		check(healthy(king) and evading(king), "T3 a Taunt by the one who left keeps nothing")
	else
		step(king, 2)
		check(not healthy(king), "T4 inside the 3 s nothing yet")
		step(king, 1.25)
		check(healthy(king) and king.attack == nil and evading(king), "T4 no Taunt: reset at 3 s")
	end
	players[a.name], players[b.name] = nil, nil
end

-- ---------------------------------------------------------------------------
-- O. A logout leaves, a death does not.
-- ---------------------------------------------------------------------------
do
	local king = fresh_king()
	local p = new_player("quitter", vec(104, 0.5, 100))
	pull(king, p)
	step(king, 1)
	logout(p)
	king:stop_attack() -- mobs_redo drops a gone target
	step(king, 1)
	check(healthy(king) and evading(king), "O1 a logout alone: reset at once")

	king = fresh_king()
	local d = new_player("dier", vec(104, 0.5, 100))
	pull(king, d)
	step(king, 1)
	kill(d)
	king:stop_attack()
	step(king, 2)
	check(not healthy(king) and not evading(king), "O2 a death is no leaving")
	players.dier = nil

	-- a logout with a second player engaged: the window
	king = fresh_king()
	local q = new_player("q2", vec(104, 0.5, 100))
	local r = new_player("r2", vec(96, 0.5, 100))
	pull(king, r, 10)
	pull(king, q, 90)
	step(king, 1)
	logout(q)
	king:stop_attack()
	step(king, 1)
	check(king.temp.grug_boss_window ~= nil and not healthy(king), "O3 with another engaged: the window")
	step(king, 3)
	check(healthy(king), "O3 ... and the reset at 3 s")
	players.r2 = nil
end

-- ---------------------------------------------------------------------------
-- G. A General in his room; an Expedition boss in its room.
-- ---------------------------------------------------------------------------
do
	-- The General's keep: a hall 20 x 20 with walls, the seat inside.
	fill(190, 1, 190, 210, 4, 190, "stone")
	fill(190, 1, 210, 210, 4, 210, "stone")
	fill(190, 1, 190, 190, 4, 210, "stone")
	fill(210, 1, 190, 210, 4, 210, "stone")
	world[wkey(210, 1, 200)], world[wkey(210, 2, 200)] = nil, nil -- the gate
	local general = new_king("general:accord", feet(200, 1, 200))
	settle_floor(general)
	check(grug_mobs.reset_boss_kind(general) == "floor" and grug_mobs.boss_floor_of(general),
		"G1 a General has a floor")
	local p = new_player("gp", vec(204, 0.5, 200))
	pull(general, p)
	p.pos = vec(205, 4.5, 190) -- onto the wall
	step(general, 1)
	check(healthy(general) and general.attack == nil, "G1 a General's target on his wall: reset")
	players.gp = nil
end
do
	-- packs.lua and the boss room of encounters.lua.
	local run = {id = 7, level = 30, expedition = "seam", minp = vec(400, -10, 400),
		maxp = vec(527, 30, 527), places = {boss_room_min = vec(448, 1, 488),
			boss_room_max = vec(479, 1, 519)}, inside = {}}
	local run_of = {}
	grug_expeditions = {
		LOGOUT_DEATH = "x",
		run_inside = function(name)
			if type(name) ~= "string" then name = name:get_player_name() end
			return run_of[name]
		end,
		register_on_end = function() end,
		register_on_leave = function() end,
		run_at = function() return run end,
	}
	local P = dofile(repo .. "/mods/PLAYER/grug_expeditions/packs.lua")
	local encounters = read("mods/PLAYER/grug_expeditions/encounters.lua")
	load_in(cut(encounters, "function grug_mobs.expedition_boss_room(self)", "\nend\n", "boss room"),
		{M = grug_expeditions, grug_mobs = grug_mobs}, "boss room")
	add_entity = function(pos, name, data)
		local m = new_mob(name, pos, data)
		m._grug_cbox = O.physics_box({-0.42, -1.4, -0.42, 0.42, 0.98, 0.42})
		m.object:set_pos(pos)
		return m.object
	end
	-- The court: walls round [448, 479] x [488, 519], a passage east at z 504..511.
	fill(447, 1, 487, 480, 9, 487, "stone")
	fill(447, 1, 520, 480, 9, 520, "stone")
	fill(447, 1, 487, 447, 9, 520, "stone")
	fill(480, 1, 487, 480, 9, 520, "stone")
	fill(480, 1, 504, 480, 5, 511, "air")
	local pack = P.new(run, "expedition:seam:7")
	assert(P.add(pack, {mob = "grug_mobs:flintback", tier = "boss", count = 1},
		vec(468, 1, 508)))
	local boss
	for _, entry in pairs(pack.members) do boss = entry.object:get_luaentity() end
	check(boss._grug_expedition == 7 and boss._grug_boss_id == "expedition:seam:7",
		"G2 the boss carries its run and ledger id")
	boss.object:set_pos(vec(474, 0.5, 508)) -- off its marker: a reset runs it home
	settle_floor(boss)
	local cells = grug_mobs.boss_floor_of(boss)
	check(cells ~= nil, "G2 an Expedition boss's floor is its room")
	check(cells[F.key(448, 1, 488)] and cells[F.key(479, 1, 519)] and not cells[F.key(485, 1, 508)],
		"G2 the envelope bounds it: no passage pursuit")
	local tank = new_player("et", vec(470, 0.5, 508))
	local dps = new_player("ed", vec(472, 0.5, 508))
	run_of.et, run_of.ed = run, run
	pull(boss, tank, 80)
	pull(boss, dps, 10)
	boss:do_attack(tank, true)
	check(pack.players.et and pack.players.ed, "G3 both on the list")
	step(boss, 1)
	check(boss.attack == tank, "G3 in the room: the fight")
	-- the navigation's give-up: with a floor, no jump and nothing dropped
	local at = boss.object:get_pos()
	grug_mobs.give_up_target(boss)
	check(boss.attack == tank and vector.distance(boss.object:get_pos(), at) < 0.01,
		"G4 a give-up with a floor: no jump, nothing dropped")
	tank.pos = vec(486, 0.5, 508) -- into the passage
	step(boss, 1)
	check(not pack.players.et and pack.players.ed and boss.temp.grug_boss_window ~= nil,
		"G5 the tank left the room: off the list, the window")
	step(boss, 3)
	check(next(pack.players) == nil and healthy(boss) and evading(boss),
		"G5 no Taunt: the reset is the wipe, the list empty, healed, home")
	-- alone: at once
	boss.temp.grug_evading = nil
	boss.object:set_pos(vec(470, 0.5, 508))
	tank.pos = vec(470, 0.5, 508)
	boss.temp.grug_gave_up = nil
	pull(boss, tank)
	boss:do_attack(tank, true)
	check(pack.players.et and not pack.players.ed, "G6 pulled again")
	tank.pos = vec(486, 0.5, 508)
	step(boss, 1)
	check(next(pack.players) == nil and healthy(boss), "G6 alone out of the room: reset at once")
	-- a template without the envelope: no floor, the give-up is the "no way"
	run.places = {}
	grug_mobs.boss_floor_forget("expedition:seam:7")
	boss.temp.grug_evading = nil
	boss.object:set_pos(vec(470, 0.5, 508))
	boss.temp.grug_gave_up = nil
	tank.pos = vec(470, 0.5, 508)
	settle_floor(boss)
	check(grug_mobs.boss_floor_of(boss) == nil, "N1 no envelope, no floor")
	pull(boss, tank)
	boss:do_attack(tank, true)
	grug_mobs.give_up_target(boss)
	check(boss.attack == nil and healthy(boss) and next(pack.players) == nil,
		"N1 without a floor the give-up is the no way: reset")
	players.et, players.ed = nil, nil
end
end -- not before

-- ---------------------------------------------------------------------------
-- C. Search counts over 30 s (the fake engine's searches, the real navigation).
-- A king who cannot move, at the foot of a ledge or before a shut door; sight
-- acquisition once a second as general_attack's.
-- ---------------------------------------------------------------------------
local function scene(target_pos, label)
	local king = fresh_king()
	local p = new_player("c_" .. label, target_pos)
	grug_core.run_player_hit_mob(p, king, 1)
	king:do_attack(p, true)
	searches = 0
	nav.counters.searches = 0
	local acq = 0
	for _ = 1, math.floor(30 / DT) do
		advance(DT)
		O.begin_server_step()
		nav.begin_server_step(DT)
		local pos = king.object:get_pos()
		if king.attack and not evading(king) then
			local tp = king.attack:get_pos()
			nav.command(king, pos, 4.6)
			local _, outcome = nav.combat_step(king, pos, DT, king.attack, tp,
				vector.distance(pos, tp), false, false)
			if outcome == "give_up" then grug_mobs.give_up_target(king) end
		end
		grug_mobs.leash_tick(king, DT)
		king.object:set_pos(pos)
		acq = acq + DT
		if acq >= 1 then
			acq = 0
			if evading(king) and vector.distance(king.object:get_pos(), SEAT) > 4 then
				king.object:set_pos(SEAT) -- the evade's walk, shortened
			end
			if not king.attack and not evading(king) and not grug_mobs.gave_up_on(king, p) then
				king:do_attack(p)
			end
		end
	end
	players[p.name] = nil
	return nav.counters.searches
end
do
	-- the ledge: the pillar at 110; the door: a closed hut round the target
	local ledge = scene(vec(110, 4.5, 100), "ledge")
	fill(98, 1, 110, 102, 3, 110, "stone")
	fill(98, 1, 114, 102, 3, 114, "stone")
	fill(98, 1, 110, 98, 3, 114, "stone")
	fill(102, 1, 110, 102, 3, 114, "stone")
	fill(98, 4, 110, 102, 4, 114, "stone")
	world[wkey(100, 1, 110)], world[wkey(100, 2, 110)] = "doors:door_wood_a", "doors:hidden"
	local door = scene(vec(100, 0.5, 112), "door")
	print(("  C %s: searches in 30 s, ledge %d, behind a shut door %d"):format(
		before and "before" or "after", ledge, door))
	if not before then
		check(ledge <= 2, "C1 a ledge target: the floor resets before the navigation searches on")
		check(door >= 3, "C2 behind a shut door the king keeps searching (the 15 s rule ends it)")
	end
end

print("R72 BOSSRESET PORTABLE PASS checks=" .. checks)
