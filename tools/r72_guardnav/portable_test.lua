-- Round 72 lane GUARDNAV portable test (LuaJIT): guards and captains out of reach
-- reset at once (round72-plan.md §2.5, §3.3, §4 GUARDNAV). Loads the REAL code on a
-- small fake engine (a node grid with a pathfinder modelled on the engine's, its
-- hovering goal lowered by up to the mob's jump): mobs/grug_obstacle.lua and
-- mobs/grug_nav.lua in full, grug_core/combat.lua in full (threat, engagement, the
-- combat state), grug_mobs/aggro.lua and grug_mobs/boss_floor.lua in full. A mob
-- steps like mobs_redo's dogfight branch (the navigation's step, a straight walk at
-- its steer point blocked by walkable cells, the strike in reach, the do_punch
-- wrapper's evade cancel, the retaliation of an idle mob). Checks:
--   O  open ground at 18: a reachable target is walked to and struck, no search,
--      no reset; behind a wall with a gap: one search at the pull, a found path, no
--      reset;
--   P  a guard and a captain against a target on a pillar (18), at a ladder's top
--      (19) and in a ladder's top node (17): a search at the pull, padding 16, two
--      failures, the reset about a second after the hit: healed, threat, target and
--      combat cleared, the evade home untouchable (a hit lands nothing and starts
--      no chase), attackable again at home at full health, and a new hit starts a
--      chase that resets again; the same mob without the switch (the rules before):
--      no search at the pull, three failures and its padding steps;
--   R  a found path that ends out of the mob's reach of the target (a hovering goal
--      the engine lowered) is a failed search; one that ends in reach is not;
--   W  who: the switch per definition (guard chassis, the rift boss, leaders, rares,
--      read by grug_mobs.reach_reset); a king, an Expedition boss, a royal guard,
--      a pack mob and wildlife are untouched; a patroller heals without the run;
--   H  the Return Home loop of the wave-1 note: a guard that sees a player at a
--      ladder's top, over 60 s, the player's time in combat before and after.
-- Prints the comparisons (searches per pull, the largest padding, the time from the
-- hit to the reset, the damage before it) for the report.
-- Usage (repo root): luajit tools/r72_guardnav/portable_test.lua [REPO]
-- Prints "R72 GUARDNAV PORTABLE PASS checks=<n>" or raises.
local repo = arg and arg[1] or "."
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

-- ---------------------------------------------------------------------------
-- The fake engine: a node grid (unset is air, at or below y 0 stone), a clock.
-- ---------------------------------------------------------------------------
local us = 1000000
local function advance(seconds) us = us + math.floor(seconds * 1e6 + 0.5) end
local world = {}
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
	distance = function(a, b)
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
	end,
}
local NODES = {
	air = {name = "air", walkable = false},
	stone = {name = "stone", walkable = true},
	ladder = {name = "ladder", walkable = false, climbable = true},
}
local players = {}
local callbacks = {die = {}, leave = {}, join = {}}
core = {
	registered_nodes = NODES,
	get_us_time = function() return us end,
	is_player = function(obj)
		return type(obj) == "table" and obj.is_player ~= nil and obj:is_player()
	end,
	get_player_by_name = function(name) return players[name] end,
	get_node_or_nil = function(pos)
		return {name = name_at(round(pos.x), round(pos.y), round(pos.z))}
	end,
	get_node = function(pos) return {name = name_at(round(pos.x), round(pos.y), round(pos.z))} end,
	load_area = function() end,
	log = function() end,
	after = function() end,
	serialize = function(t) return t end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
}
setmetatable(core, {__index = function(_, k)
	if type(k) == "string" and k:match("^register_") then return function() end end
	return nil
end})
local function walkable(x, y, z)
	local def = NODES[name_at(x, y, z)]
	return not def or def.walkable == true
end
-- pathfinder.cpp walkDownwards: a hovering end goes down to the cell above the
-- first walkable node when that is at most `max` cells down.
local function walk_down(p, max)
	if max == 0 then return p end
	local y, down = p.y, 0
	while not walkable(p.x, y, p.z) and down <= max do
		y, down = y - 1, down + 1
	end
	if walkable(p.x, y, p.z) then
		if down == 0 then return vec(p.x, y, p.z) end
		if down - 1 <= max then return vec(p.x, y + 1, p.z) end
	end
	return p
end
-- The engine's search, modelled: walkable ends refused, the start dropped and the
-- goal lowered as above, steps of up to `jump` up and `drop` down onto ground.
local search_log = {}
function core.find_path(from, to, pad, jump, drop)
	search_log[#search_log + 1] = {pad = pad}
	if walkable(from.x, from.y, from.z) or walkable(to.x, to.y, to.z) then return nil end
	local s, g = walk_down(from, drop), walk_down(to, jump)
	if walkable(s.x, s.y - 1, s.z) == false or walkable(g.x, g.y - 1, g.z) == false then
		return nil -- an end still hovering: no surface cell
	end
	local x1, x2 = math.min(from.x, to.x) - pad, math.max(from.x, to.x) + pad - 1
	local z1, z2 = math.min(from.z, to.z) - pad, math.max(from.z, to.z) + pad - 1
	local seen, queue, first = {[wkey(s.x, s.y, s.z)] = {}}, {s}, 1
	while first <= #queue do
		local c = queue[first]
		first = first + 1
		if c.x == g.x and c.y == g.y and c.z == g.z then
			local rev, k = {}, wkey(c.x, c.y, c.z)
			while k do
				local e = seen[k]
				rev[#rev + 1] = e.cell or s
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
				else
					for up = 1, jump do
						if not walkable(x, y + up, z) and not walkable(c.x, c.y + up, c.z) then
							ny = y + up
							break
						end
					end
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
local events
nav.on_event = function(self, kind)
	if events and self == events.mob then
		events[kind] = (events[kind] or 0) + 1
		if kind == "give_up" and not events.give_up_at then events.give_up_at = us end
	end
end

-- ---------------------------------------------------------------------------
-- The real combat state, leash and reset.
-- ---------------------------------------------------------------------------
grug_core = {}
local tracked = {}
grug_mobs = {registered_cadence = tracked}
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
grug_core.death_message = function(name) return "fled", name .. " fled" end
grug_core.damage_source = function(object) return object end
grug_core.actor_projectile_lock = function() return nil end
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
grug_mobs.settle_mob_death = function() return true end
grug_mobs.live_claim = function() return true end
grug_mobs.boss_attempt_reset = function() end
grug_mobs.royal_encounter_reset = function() end
local stats = {pack_resets = 0}
grug_mobs.pack_reset = function() stats.pack_resets = stats.pack_resets + 1 return true end
grug_mobs.pack_left_behind = function() stats.left_behind = true end
dofile(repo .. "/mods/ENTITIES/grug_mobs/aggro.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/boss_floor.lua")
check(nav.strict == grug_mobs.reach_reset, "aggro.lua installs the strict rule's predicate")

-- ---------------------------------------------------------------------------
-- Mobs and players.
-- ---------------------------------------------------------------------------
local mob_class = {}
local mob_mt = {__index = mob_class}
function mob_class:do_attack(player, force)
	if self.state == "attack" and not force then return end
	self.attack, self.state = player, "attack"
	if core.is_player(player) and not self.temp.grug_evading then
		grug_core.engage_mob(self, player)
	end
end
-- mobs_redo's stop_attack forgets the navigation (GRUG PATCH Round 42 NV1).
function mob_class:stop_attack()
	grug_core.disengage_target(self, self.attack)
	self.attack, self.state = nil, "stand"
	nav.forget(self.temp)
	O.forget_no_path(self.temp)
end
function mob_class:update_tag() end
function mob_class:set_velocity(v) self.velocity = v end
function mob_class:set_animation(a) self.anim = a end

local GUARD_BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local function scaled(box, k)
	local out = {}
	for i = 1, 6 do out[i] = box[i] * k end
	return out
end
local mob_n = 0
-- A guard (the guard chassis' fields), at its home `home` (a feet position).
local function new_mob(home, fields)
	mob_n = mob_n + 1
	local m = setmetatable({name = "grug_mobs:guard_throng", type = "npc", state = "stand",
		health = 1276, hp_max = 1276, attack_type = "dogfight", reach = 3, view_range = 14,
		temp = {}, jump_height = 4, fear_height = 4, damage = 10, run_velocity = 4.6,
		initial_properties = {stepheight = 1.1}, _grug_cbox = GUARD_BOX,
		_grug_leash_range = 30, _grug_reach_reset = true, _grug_faction = "throng",
		_grug_home = vector.new(home), id = mob_n}, mob_mt)
	local at = vector.new(home)
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
	tracked[m.name] = true
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
	function p:punch(source) grug_core.mark_player_hit(self, source) end
	function p:add_velocity() end
	function p:get_properties() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3}} end
	players[name] = p
	return p
end
local function feet(x, y, z) return vec(x, y - 0.5, z) end -- feet on cell y
local function evading(m) return m.temp.grug_evading ~= nil end
local function healthy(m) return m.health == m.hp_max end
local in_combat = grug_core.in_combat

-- A Mage's hit through the mob's punch: the do_punch wrapper's evade cancel first
-- (init.lua), then the accepted hit (threat, contact), the health, and an idle mob
-- takes its attacker (api.lua's retaliation). Returns the health it took.
local function hit(m, player, amount)
	if m.temp.grug_evading then return 0 end
	grug_core.run_player_hit_mob(player, m, amount)
	m.health = m.health - amount
	if not (m.attack and m.state == "attack") then m:do_attack(player) end
	return amount
end

local DT = 0.1
-- The open cell a body steps into from feet height y at column (x, z): level, a
-- step up of one, or down to its fear height; nil when blocked.
local function settle(x, y, z)
	if walkable(x, y, z) or walkable(x, y + 1, z) then
		if not walkable(x, y + 1, z) and not walkable(x, y + 2, z) and walkable(x, y, z) then
			return y + 1
		end
		return nil
	end
	for d = 0, 4 do
		if walkable(x, y - 1 - d, z) then return y - d end
	end
	return nil
end
-- Walk straight at `goal` by v*DT; blocked by walkable cells at the leading edge.
local function walk(m, goal, v)
	local p = m.object:get_pos()
	local dx, dz = goal.x - p.x, goal.z - p.z
	local l = math.sqrt(dx * dx + dz * dz)
	if l < 0.05 then return end
	local d = math.min(l, v * DT)
	local ux, uz = dx / l, dz / l
	local cy = math.floor(p.y + 0.55)
	local edge_x, edge_z = round(p.x + ux * (d + 0.3)), round(p.z + uz * (d + 0.3))
	local ny = settle(edge_x, cy, edge_z)
	if not ny then return end
	m.object:set_pos(vec(p.x + ux * d, ny - 0.5, p.z + uz * d))
end
-- One server step of the mob: leash, evade and give-up bookkeeping, the dogfight
-- branch's navigation, its walk, its strike. Returns true when it struck.
local function mob_step(m)
	advance(DT)
	O.begin_server_step()
	nav.begin_server_step(DT)
	grug_mobs.leash_tick(m, DT)
	if m.temp.grug_evading then
		walk(m, m._grug_home, m.run_velocity * 1.5)
		return false
	end
	local target = m.attack
	if not target then return false end
	local p, tp = m.object:get_pos(), target:get_pos()
	local dist = vector.distance(p, tp)
	local striking = dist <= m.reach
	local steer, outcome = nav.combat_step(m, p, DT, target, tp, dist, striking, false)
	if outcome == "give_up" then
		grug_mobs.give_up_target(m)
		return false
	end
	if striking then
		nav.command(m, p, 0)
		return true
	end
	nav.command(m, p, m.run_velocity)
	walk(m, steer or tp, m.run_velocity)
	return false
end

-- One trial: a player at `spot` hits the mob once a second for `seconds`.
-- Records the time from the first hit to the first reset, the health lost before
-- it, the searches (and their largest padding) per pull, the strikes, the hits
-- that landed nothing during an evade and whether a hit after the reset started a
-- new chase.
local function trial(m, spot, seconds, opts)
	opts = opts or {}
	local p = new_player("mage" .. m.id, spot)
	events = {mob = m}
	search_log = {}
	local t0, next_hit = us, 0
	local r = {lost = 0, pulls = 0, strikes = 0, cancelled = 0, resets = 0, rechase = nil}
	local had, lost_total = false, 0
	local reset_seen = false
	local wrapped = grug_mobs.give_up_target
	grug_mobs.give_up_target = function(self)
		if self == m then
			r.resets = r.resets + 1
			if not r.reset_at then
				r.reset_at = (us - t0) / 1e6
				r.lost_before = lost_total
				r.searches_first = #search_log
			end
		end
		return wrapped(self)
	end
	local after_reset = {}
	for _ = 1, math.floor(seconds / DT + 0.5) do
		local t = (us - t0) / 1e6
		if t >= next_hit - 1e-6 and not opts.no_hits then
			next_hit = next_hit + 1
			local evaded = m.temp.grug_evading ~= nil
			local lost = hit(m, p, opts.amount or 38)
			lost_total = lost_total + lost
			if evaded then r.cancelled = r.cancelled + 1 end
			if r.reset_at and not r.after then
				r.after = {evading = evaded, lost = lost, chased = m.attack == p}
			end
		end
		if mob_step(m) then r.strikes = r.strikes + 1 end
		local targets = m.attack == p
		if targets and not had then r.pulls = r.pulls + 1 end
		had = targets
		if opts.each then opts.each(m, p, (us - t0) / 1e6) end
	end
	grug_mobs.give_up_target = wrapped
	r.searches = #search_log
	r.largest_pad = 0
	for _, s in ipairs(search_log) do
		if s.pad > r.largest_pad then r.largest_pad = s.pad end
	end
	r.events = events
	r.player = p
	r.lost_total = lost_total
	events = nil
	return r, p
end

-- The scenes, one lane each along x; home at (0, 1, z), floor top at y 0.
local function lane(z) return feet(0, 1, z) end
local Z = {open = 0, wall = 30, pillar = 60, ladder_top = 90, ladder_hang = 120, reach = 150,
	reach2 = 180, loop = 210, cap = 240, patrol = 270}
-- pillar: 1x1, 4 high at x 18
fill(18, 1, Z.pillar, 18, 4, Z.pillar, "stone")
-- ladder_top: a 3x3 tower 4 high at x 19..21, a ladder on its near face at x 18
fill(19, 1, Z.ladder_top - 1, 21, 4, Z.ladder_top + 1, "stone")
fill(18, 1, Z.ladder_top, 18, 4, Z.ladder_top, "ladder")
-- ladder_hang: the tower 5 high one further, the ladder at x 17, the player in its top node
fill(18, 1, Z.ladder_hang - 1, 20, 5, Z.ladder_hang + 1, "stone")
fill(17, 1, Z.ladder_hang, 17, 5, Z.ladder_hang, "ladder")
-- wall: a wall across x 9 with a gap at its far end (z +7)
fill(9, 1, Z.wall - 8, 9, 3, Z.wall + 6, "stone")
fill(9, 1, Z.wall + 8, 9, 3, Z.wall + 10, "stone")
-- the Return Home loop: a tower 4 high at 10 nodes, a ladder, the player on top
fill(11, 1, Z.loop - 1, 13, 4, Z.loop + 1, "stone")
fill(10, 1, Z.loop, 10, 4, Z.loop, "ladder")
-- the patroller's pillar
fill(18, 1, Z.patrol, 18, 4, Z.patrol, "stone")

local SPOTS = {
	pillar = vec(18, 4.5, Z.pillar),
	ladder_top = vec(20, 4.5, Z.ladder_top),
	ladder_hang = vec(17, 4.5, Z.ladder_hang),
}
local report = {}

-- ---------------------------------------------------------------------------
-- O. Reachable: open ground, and behind a wall with a gap.
-- ---------------------------------------------------------------------------
do
	local m = new_mob(lane(Z.open))
	local r = trial(m, vec(18, 0.5, Z.open), 12)
	check(r.resets == 0 and r.strikes > 0, "O1 open ground at 18: struck, no reset")
	check(r.searches == 0 and not r.events.pull, "O1 a walkable line: no search at the pull")
	report[#report + 1] = ("open 18: searches %d, resets %d, health lost before the first strike n/a")
		:format(r.searches, r.resets)
	m = new_mob(lane(Z.wall))
	r = trial(m, vec(18, 0.5, Z.wall), 15)
	check(r.events.pull == 1 and r.searches >= 1 and r.events.found and r.events.found >= 1,
		"O2 behind a wall: a search at the pull finds the gap")
	check(r.resets == 0 and r.strikes > 0, "O2 the target behind the wall is reached, no reset")
	report[#report + 1] = ("wall with a gap 18: searches %d, resets %d"):format(r.searches, r.resets)
end

-- ---------------------------------------------------------------------------
-- P. Out of reach: a guard and a captain, after and before (no switch).
-- ---------------------------------------------------------------------------
local function out_of_reach(scene, fields, label, switch)
	local f = {}
	for k, v in pairs(fields or {}) do f[k] = v end
	if not switch then f._grug_reach_reset = false end
	local m = new_mob(lane(Z[scene]), f)
	local r = trial(m, SPOTS[scene], 20)
	return m, r
end
for _, who in ipairs({{label = "guard"}, {label = "captain",
		fields = {name = "grug_mobs:captain_throng", health = 1914, hp_max = 1914,
			_grug_cbox = scaled(GUARD_BOX, 1.15)}}}) do
	for _, scene in ipairs({"pillar", "ladder_top", "ladder_hang"}) do
		local tag = who.label .. " " .. scene
		local m, r = out_of_reach(scene, who.fields, tag, true)
		check(r.reset_at and r.reset_at <= 1.3,
			"P1 " .. tag .. ": the reset about a second after the hit: " .. tostring(r.reset_at))
		check(r.searches_first == 2 and r.largest_pad == nav.STRICT_PADDING,
			"P1 " .. tag .. ": two searches, padding 16, before it: " .. tostring(r.searches_first))
		check(r.strikes == 0, "P1 " .. tag .. ": never struck")
		check(r.after and r.after.evading and r.after.lost == 0 and not r.after.chased,
			"P2 " .. tag .. ": the next hit lands nothing during the evade and starts no chase")
		check(r.resets >= 2, "P3 " .. tag .. ": home at full health, hit again: a new chase, reset again")
		local per_pull = r.searches / math.max(1, r.pulls)
		report[#report + 1] = ("%s after: reset %.1f s after the first hit, health lost before %d (%.1f %%), "
			.. "searches %d per pull, largest padding %d, %d resets in 20 s, %d of 20 hits cancelled")
			:format(tag, r.reset_at, r.lost_before, 100 * r.lost_before / m.hp_max,
				per_pull, r.largest_pad, r.resets, r.cancelled)
		-- The reset's state, on a fresh mob, at the moment it comes.
		local m2 = new_mob(lane(Z[scene]), who.fields)
		local p2 = new_player("state" .. m2.id, SPOTS[scene])
		hit(m2, p2, 38)
		check(in_combat(p2), "P4 " .. tag .. ": in combat from the hit")
		local n = 0
		while not evading(m2) and n < 30 do mob_step(m2) n = n + 1 end
		check(evading(m2) and healthy(m2) and m2.attack == nil and m2.temp.grug_threat == nil,
			"P4 " .. tag .. ": reset: healed at once, target and threat cleared, evading")
		check(not in_combat(p2) and grug_mobs.gave_up_on(m2, p2), "P4 " .. tag
			.. ": the player is out of combat and not taken again by sight for now")
		n = 0
		while evading(m2) and n < 100 do mob_step(m2) n = n + 1 end
		local home = m2._grug_home
		local at = m2.object:get_pos()
		check(not evading(m2) and healthy(m2) and math.abs(at.x - home.x) <= 4,
			"P5 " .. tag .. ": back home, untouchable until there, at full health")
		check(m2.velocity == 0 and m2.state == "stand",
			"P5 " .. tag .. ": it stops where it arrived (no carry past its post)")
		check(hit(m2, p2, 38) == 38 and m2.attack == p2, "P5 " .. tag .. ": attackable again at home")
		players[p2.name] = nil
		players[r.player.name] = nil
		-- Before: the same mob without the switch (the rules of 0.71.0).
		local mb, rb = out_of_reach(scene, who.fields, tag, false)
		check(not rb.events.pull and (not rb.reset_at or rb.reset_at > 2.5),
			"P6 " .. tag .. " before: no search at the pull, the give-up late: " .. tostring(rb.reset_at))
		check(rb.cancelled == 0, "P6 " .. tag .. " before: no evade near home, every hit lands")
		report[#report + 1] = ("%s before: reset %s s after the first hit, health lost before %d (%.1f %%), "
			.. "searches %.1f per pull, largest padding %d, %d resets in 20 s, %d of 20 hits cancelled")
			:format(tag, rb.reset_at and ("%.1f"):format(rb.reset_at) or "none", rb.lost_before or rb.lost_total,
				100 * (rb.lost_before or rb.lost_total) / mb.hp_max, rb.searches / math.max(1, rb.pulls),
				rb.largest_pad, rb.resets, rb.cancelled)
		players[rb.player.name] = nil
	end
end

-- ---------------------------------------------------------------------------
-- R. A found path counts only if it ends within reach of the target.
-- ---------------------------------------------------------------------------
do
	-- A mob that jumps two (jump_height 8): the engine lowers a goal hovering two
	-- above the ground to it; the target hangs on a ladder, feet two above.
	fill(12, 1, Z.reach, 12, 4, Z.reach, "ladder")
	fill(13, 1, Z.reach - 1, 13, 4, Z.reach + 1, "stone")
	local spot = vec(12, 2.5, Z.reach)
	local m = new_mob(lane(Z.reach), {jump_height = 8, reach = 1.5})
	local r = trial(m, spot, 8)
	check(r.events.short and r.events.short >= 1 and r.reset_at,
		"R1 a path ending 2 below the target, reach 1.5: a failed search, the reset")
	fill(12, 1, Z.reach2, 12, 4, Z.reach2, "ladder")
	fill(13, 1, Z.reach2 - 1, 13, 4, Z.reach2 + 1, "stone")
	m = new_mob(lane(Z.reach2), {jump_height = 8, reach = 3})
	r = trial(m, vec(12, 2.5, Z.reach2), 6)
	check(not r.events.short and r.resets == 0 and r.strikes > 0,
		"R2 the same path with reach 3 ends in reach: struck, no reset")
end

-- ---------------------------------------------------------------------------
-- W. Who.
-- ---------------------------------------------------------------------------
do
	local P = function(fields) return new_mob(lane(Z.cap), fields) end
	check(grug_mobs.reach_reset(P()), "W1 a guard (the chassis' switch)")
	check(grug_mobs.reach_reset(P({_grug_boss_id = "rift:a"})), "W1 the rift boss")
	check(grug_mobs.reach_reset(P({_grug_leader = true})), "W1 a leader")
	check(grug_mobs.reach_reset(P({_grug_rare_id = "grimtusk"})), "W1 a rare")
	check(not grug_mobs.reach_reset(P({_grug_royal_king = true, _grug_boss_id = "king:human"})),
		"W2 a king keeps his floor")
	check(not grug_mobs.reach_reset(P({_grug_expedition = "r1", _grug_boss_id = "exp:1"})),
		"W2 an Expedition boss keeps its floor")
	check(not grug_mobs.reach_reset(P({_grug_no_leash = true})), "W2 a royal guard keeps its rules")
	check(not grug_mobs.reach_reset(P({_grug_pack = "p1"})), "W2 a pack mob keeps its pack")
	check(not grug_mobs.reach_reset(P({_grug_reach_reset = false, type = "monster"})),
		"W2 wildlife (no switch)")
	-- The switch per definition: one field, published by register_mob, set by the
	-- definitions.
	local guard = read("mods/ENTITIES/grug_mobs/guard.lua")
	check(guard:find("local function guard_def%(") and guard:find("\t\t_grug_reach_reset = true,\n", 1, true),
		"W3 guard.lua: the guard chassis (guards, captains, war commanders)")
	check(read("mods/ENTITIES/grug_mobs/rift.lua"):find("\t_grug_reach_reset = true,\n", 1, true),
		"W3 rift.lua: the rift boss")
	check(read("mods/ENTITIES/grug_mobs/subtypes.lua"):find("def._grug_reach_reset = true", 1, true),
		"W3 subtypes.lua: every leader")
	check(read("mods/ENTITIES/grug_mobs/rares.lua"):find(
		"if not self._grug_reach_reset then self._grug_reach_reset = true end", 1, true),
		"W3 rares.lua: every named rare")
	check(read("mods/ENTITIES/grug_mobs/init.lua"):find(
		"core.registered_entities[name]._grug_reach_reset = true", 1, true),
		"W3 init.lua: the definition's field reaches the entity")
	-- A king against the pillar: no strict search, his give-up goes to his rules.
	local king = new_mob(lane(Z.pillar), {_grug_royal_king = true, _grug_boss_id = "king:test",
		_grug_cbox = GUARD_BOX})
	local r = trial(king, SPOTS.pillar, 3)
	check(not r.events.pull and not r.events.short, "W4 a king: no strict search at the pull")
	players[r.player.name] = nil
	-- Wildlife: the rules before (no search at the pull, padding steps).
	local wolf = new_mob(lane(Z.pillar), {_grug_reach_reset = false, type = "monster"})
	r = trial(wolf, SPOTS.pillar, 8)
	check(not r.events.pull, "W5 wildlife: no search at the pull")
	check(search_log[1] and search_log[1].pad == 6, "W5 wildlife: its first search pads 6, as before")
	players[r.player.name] = nil
	-- The designated patroller: the fast give-up heals, without the run to its post.
	local pat = new_mob(lane(Z.patrol), {_grug_patrol_route = {points = {}}})
	local pp = new_player("patrol", vec(18, 4.5, Z.patrol))
	hit(pat, pp, 38)
	local n = 0
	while pat.attack and n < 30 do mob_step(pat) n = n + 1 end
	check(pat.attack == nil and healthy(pat) and not evading(pat),
		"W6 a patroller: reset at once, healed, no run to its post")
	players.patrol = nil
end

-- ---------------------------------------------------------------------------
-- H. The Return Home loop (wave-1 GUI note): a guard that sees a player at a
-- ladder's top 10-12 nodes from its home; sight acquisition once a second as
-- general_attack's (its give-up veto included); 60 s, nobody hits it.
-- ---------------------------------------------------------------------------
local function loop(switch)
	local m = new_mob(lane(Z.loop), {_grug_reach_reset = switch})
	local p = new_player("loop" .. m.id, vec(12, 4.5, Z.loop))
	local acq, busy, pulls = 0, 0, 0
	local was
	for _ = 1, math.floor(60 / DT + 0.5) do
		mob_step(m)
		acq = acq + DT
		if acq >= 1 - 1e-9 then
			acq = 0
			if not m.attack and not evading(m) and not grug_mobs.gave_up_on(m, p)
					and vector.distance(m.object:get_pos(), p:get_pos()) <= m.view_range then
				m:do_attack(p)
			end
		end
		local now = in_combat(p)
		if now then busy = busy + DT end
		if now and not was then pulls = pulls + 1 end
		was = now
	end
	players[p.name] = nil
	return busy, pulls
end
do
	local busy_after, pulls_after = loop(true)
	local busy_before, pulls_before = loop(false)
	check(busy_after < busy_before, "H1 less time in combat: " .. busy_after .. " < " .. busy_before)
	check(busy_after <= 60 * 0.15, "H1 the player is out of combat most of the minute: " .. busy_after)
	report[#report + 1] = ("Return Home loop, 60 s, guard sees a player at a ladder's top: in combat "
		.. "%.1f s in %d spells after, %.1f s in %d spells before"):format(busy_after, pulls_after,
			busy_before, pulls_before)
end

for _, line in ipairs(report) do print("  " .. line) end
print(("R72 GUARDNAV PORTABLE PASS checks=%d"):format(checks))
