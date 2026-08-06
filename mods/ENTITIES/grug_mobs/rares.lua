--
-- Named rares: scheduled spawner, patrol and faction broadcast
-- (docs/design/biomes_mobs.md §3.3, combat_stats.md §3 "named rares
-- broadcast their spawn faction-wide").
--
-- A named rare is NOT its own mob registration: it is an ordinary mob of an
-- existing family (Grimtusk = grug_mobs:boar) placed by this spawner,
-- renamed, optionally re-textured, and promoted to tier "rare" by the level
-- engine (levels.lua: x5 HP, x2.2 dmg, x6 XP, armor 70, scale x2, violet
-- tint, star prefix). Its LEVEL still comes from the field at its spawn
-- position, so the route points in the registrations below decide the level
-- — see the level check comments there.
--
-- Persistence: one mod-storage record per rare id (next_spawn / alive /
-- spawned_at, all in core.get_gametime() seconds so the timer counts played
-- world time and survives restarts). Runtime work is ONE globalstep
-- throttled to 10 s over the whole registry — no ABM, no per-mob polling.
--

local storage = grug_mobs.storage

local CHECK_INTERVAL = 10 -- s between spawner passes
-- A player has to be this close (horizontally) before we even try: outside
-- the active block range mobs:add_mob refuses anyway (it needs a player
-- within aoc_range * 2 = 128 m, api.lua:3347/3439), and an entity added to
-- an inactive block would be pointless. Slightly under 128 so the check we
-- make and the check add_mob makes agree.
local PLAYER_RANGE = 120
-- Anti-duplicate / "is it still out there" scan radius around each route
-- point. Comfortably larger than the 40 m leash (aggro.lua), so a rare
-- chasing a player cannot hide from the scan.
local SCAN_RADIUS = 100
-- find_surface() returns the position it was GIVEN when it finds nothing
-- (grug_core/init.lua:388) — an impossible input y makes that detectable.
local NO_SURFACE_Y = -1000
local BROADCAST_COLOR = "#ffb733" -- amber (combat_stats §3)

grug_mobs.registered_rares = {} -- id -> spec

-- id -> {alive = bool, next_spawn = n, spawned_at = n, seen_at = n}
-- The first three are mirrored into mod storage; `seen_at` is runtime only
-- (see rare_watch).
local state = {}

local function save(id)
	local st = state[id]
	storage:set_int("rare_alive:" .. id, st.alive and 1 or 0)
	storage:set_int("rare_next:" .. id, st.next_spawn)
	storage:set_int("rare_born:" .. id, st.spawned_at)
end

--
-- Registration
--

-- spec = {
--   name = "Grimtusk",              -- nametag (plain field `description`)
--   mob = "grug_mobs:boar",         -- an already registered mob name
--   texture = {"a.png", "b.png"},   -- optional, one entry per model slot
--   route = {{x=..,z=..}, ...},     -- 2-3 patrol points, y resolved at spawn
--   biome_hint = "the meadows",     -- used verbatim in the broadcast
--   respawn_min = 7200, respawn_max = 14400,  -- seconds of game time
-- }
function grug_mobs.register_rare(id, spec)
	grug_mobs.registered_rares[id] = spec
	state[id] = {
		alive = storage:get_int("rare_alive:" .. id) == 1,
		next_spawn = storage:get_int("rare_next:" .. id),
		spawned_at = storage:get_int("rare_born:" .. id),
	}
end

--
-- Position helpers
--

-- Surface position of a route point, or nil while the area is not loaded.
-- Cached per point once resolved: grug_core.find_surface scans y 120..-16
-- with get_node_or_nil, and terrain does not move.
local surface_cache = {}

local function route_pos(pt)
	local key = pt.x .. "," .. pt.z
	local y = surface_cache[key]
	if y then
		return vector.new(pt.x, y, pt.z)
	end
	local p = grug_core.find_surface({x = pt.x, y = NO_SURFACE_Y, z = pt.z})
	if not p or p.y == NO_SURFACE_Y then
		return nil
	end
	-- Sea level is y = 1, so all land is at y >= 1. A hit below that means
	-- the surface column was not loaded and find_surface answered with a
	-- cave floor instead — do not use it and above all do not cache it.
	if p.y < 1 then
		return nil
	end
	surface_cache[key] = p.y
	return p
end

-- Horizontal player proximity to a route point. Horizontal on purpose: the
-- route points have no y until the surface is resolved, and a player 30
-- nodes underground still keeps the area loaded.
local function player_near_xz(pt, range)
	local players = core.get_connected_players()
	for i = 1, #players do
		local pp = players[i]:get_pos()
		if pp then
			local dx, dz = pp.x - pt.x, pp.z - pt.z
			if dx * dx + dz * dz <= range * range then
				return true
			end
		end
	end
	return false
end

local function route_has_player(spec)
	for i = 1, #spec.route do
		if player_near_xz(spec.route[i], PLAYER_RANGE) then
			return true
		end
	end
	return false
end

-- Is a rare with this id already loaded somewhere along its route? Covers
-- both the "alive flag lost" case (world file rolled back, storage cleared)
-- and the fallback respawn below — a second Grimtusk would be a bug, not a
-- feature.
local function find_existing(id, spec)
	for i = 1, #spec.route do
		local pos = route_pos(spec.route[i])
		if pos then
			local objs = core.get_objects_inside_radius(pos, SCAN_RADIUS)
			for n = 1, #objs do
				local ent = objs[n]:get_luaentity()
				if ent and ent._grug_rare_id == id then
					return ent
				end
			end
		end
	end
	return nil
end

--
-- Spawn + broadcast
--

-- Faction-wide sighting message (combat_stats §3). Goes to the players of
-- the faction whose continent the rare stands on; factionless players (a
-- brand new character still on the spawn platform) get nothing, and neither
-- does the enemy faction — a rare is a meeting point for your own side.
-- grug_core.territory_at returns the same ids as get_player_faction
-- ("accord"/"throng"), so the comparison is direct.
local function broadcast(spec, pos)
	local territory = grug_core.territory_at(pos)
	if territory ~= "accord" and territory ~= "throng" then
		return
	end
	local msg = core.colorize(BROADCAST_COLOR,
		spec.name .. " has been sighted in " .. spec.biome_hint .. "!")
	local players = core.get_connected_players()
	for i = 1, #players do
		local name = players[i]:get_player_name()
		if grug_core.get_player_faction(name) == territory then
			core.chat_send_player(name, msg)
		end
	end
end

local function mark_alive(id, now)
	local st = state[id]
	st.alive = true
	st.spawned_at = now
	st.seen_at = now
	save(id)
end

local function try_spawn(id, spec, now)
	-- Only route points that actually have somebody near them are
	-- candidates; picking blindly would waste most passes on the far end of
	-- the route. Which of the viable ones is used stays random, so a rare
	-- does not always appear in the same corner.
	local viable, n = {}, 0
	for i = 1, #spec.route do
		if player_near_xz(spec.route[i], PLAYER_RANGE) then
			n = n + 1
			viable[n] = spec.route[i]
		end
	end
	if n == 0 then
		return -- nobody there; retry on the next pass
	end
	local pt = viable[math.random(n)]
	if find_existing(id, spec) then
		-- Already out there (stale alive flag): adopt it, never duplicate.
		mark_alive(id, now)
		return
	end
	local pos = route_pos(pt)
	if not pos then
		return -- area not loaded yet
	end
	local ent = mobs:add_mob(pos, {
		name = spec.mob,
		texture = spec.texture,
		ignore_count = true, -- a rare ignores the family's spawn cap
	})
	if not ent then
		return
	end
	-- `description` is a plain field of every mobs_redo entity (api.lua:3217)
	-- and is what levels.lua's tag_text prints, so the nametag reads
	-- "★ Grimtusk [Lv 12] 325/325". It must be set BEFORE the tier: set_tier
	-- refreshes the tag.
	ent.description = spec.name
	ent._grug_rare_id = id
	-- Named rares must not evaporate when the last player walks away:
	-- mobs_redo deletes an unloading mob whose lifetimer is below 20000
	-- (api.lua:2838) and expires it on a timer below the same threshold
	-- (api.lua:3006). A plain field, so the exemption persists with the mob.
	ent.lifetimer = 30000
	grug_mobs.set_tier(ent, "rare")
	mark_alive(id, now)
	broadcast(spec, pos)
	core.log("action", "[grug_mobs] rare " .. spec.name .. " spawned at " ..
		core.pos_to_string(vector.round(pos)))
end

--
-- Death -> respawn timer
--

-- Called from init.lua's do_punch wrapper on the lethal player punch.
function grug_mobs.rare_killed(id)
	local spec = grug_mobs.registered_rares[id]
	local st = state[id]
	if not spec or not st then
		return
	end
	st.alive = false
	st.next_spawn = core.get_gametime() +
		math.random(spec.respawn_min, spec.respawn_max)
	save(id)
end

-- Watchdog for deaths nobody reported: lava, fall damage, a guard NPC, or a
-- mob deleted by an admin/world edit. Without it such a rare would be gone
-- for good, because `alive` would stay true forever.
--
-- The trap is that get_objects_inside_radius is BLIND in inactive areas, so
-- "scan found nothing" alone would happily conjure a second Grimtusk while
-- the first one stands two route points away in an unloaded block. Hence:
--   * we only scan while a player is near the route (area active);
--   * a successful scan stamps a runtime-only `seen_at` — deliberately not
--     persisted, so a restart falls back to spawned_at instead of writing
--     mod storage every ten seconds;
--   * the respawn is only released once a full respawn_max has passed
--     WITHOUT a sighting despite players being around.
local function rare_watch(id, spec, now)
	local st = state[id]
	if not route_has_player(spec) then
		return
	end
	if find_existing(id, spec) then
		st.seen_at = now
		return
	end
	if now - math.max(st.spawned_at, st.seen_at or 0) <= spec.respawn_max then
		return
	end
	st.alive = false
	st.next_spawn = now -- lost without a kill: let it come back immediately
	save(id)
	core.log("action", "[grug_mobs] rare " .. spec.name ..
		" lost without a recorded kill, respawn released")
end

--
-- The one slow globalstep (performance rule: accumulator-throttled, and the
-- body only runs over a handful of registry entries).
--

local acc = 0

core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < CHECK_INTERVAL then
		return
	end
	acc = 0
	local now = core.get_gametime()
	for id, spec in pairs(grug_mobs.registered_rares) do
		local st = state[id]
		if st.alive then
			rare_watch(id, spec, now)
		elseif now >= st.next_spawn then
			try_spawn(id, spec, now)
		end
	end
end)

--
-- Patrol
--
-- Wired like leash_tick from init.lua's do_custom wrapper (guarded there by
-- _grug_rare_id, so no normal mob ever enters this function).
--
-- We do NOT use mobs_redo's mob_class:go_to(pos) (api.lua:1672). It works by
-- spawning a temporary "mobs:_pos" entity and calling do_attack(obj, true)
-- on it — i.e. it puts the mob into state "attack" with a dummy target.
-- Three things break for us: general_attack() bails out entirely while
-- state == "attack" (api.lua:1695), so a patrolling rare would be BLIND to
-- players; our threat/leash logic would see an attack state with a
-- non-player target; and the telegraph would count the dummy as melee
-- combat. A yaw + walk-velocity nudge once a second is all an amble needs.
--
-- The current waypoint index lives in the plain field `_grug_rare_wp`, so
-- the route position survives unload/reload with the mob.
--

local WAYPOINT_REACHED = 4 -- m

function grug_mobs.rare_tick(self, dtime)
	local spec = grug_mobs.registered_rares[self._grug_rare_id]
	if not spec or not spec.route or #spec.route < 2 then
		return
	end
	self.temp = self.temp or {}
	local t = self.temp
	t.grug_rare_acc = (t.grug_rare_acc or 0) + dtime
	if t.grug_rare_acc < 1 then
		return
	end
	t.grug_rare_acc = 0
	-- Idle only: fighting, fleeing and flopping all own the movement.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		return
	end
	local pos = self.object and self.object:get_pos()
	if not pos then
		return
	end
	local idx = self._grug_rare_wp or 1
	if idx > #spec.route then
		idx = 1
	end
	local pt = spec.route[idx]
	local dx, dz = pt.x - pos.x, pt.z - pos.z
	if dx * dx + dz * dz <= WAYPOINT_REACHED * WAYPOINT_REACHED then
		idx = idx % #spec.route + 1
		self._grug_rare_wp = idx
		pt = spec.route[idx]
	end
	self:yaw_to_pos(vector.new(pt.x, pos.y, pt.z), 0, 4)
	self.state = "walk"
	self:set_velocity(self.walk_velocity)
end

--
-- The two boar-based rares (biomes_mobs §3.3)
--
-- Both are ~L12, which is a property of WHERE they walk, not of a number in
-- this file: grug_core.mob_level_at is a radial field around the faction
-- seat at (0, +-900). Level check for the route points below (level_at_n of
-- the radial value, world.md §1 anchors):
--   (250, 560) -> n 0.340 -> L12    (340, 580) -> n 0.322 -> L11
--   (180, 540) -> n 0.360 -> L14
-- All three are zone "inner" (radial 400-470 nodes out from the capital),
-- matching "inner ring" in §3.3, and all sit inside the center race band
-- (|x| <= 700, world.md §7) so the biome is the center one: meadows on the
-- Accord side, savanna on the Throng side.
--
-- Accord is negative z, Throng positive — Ashmaw's route is the exact
-- mirror of Grimtusk's, so both get the same level and the same walk.
--

grug_mobs.register_rare("grimtusk", {
	name = "Grimtusk",
	mob = "grug_mobs:boar",
	route = {{x = 250, z = -560}, {x = 340, z = -580}, {x = 180, z = -540}},
	biome_hint = "the central meadows",
	respawn_min = 7200, -- 2 h (biomes_mobs §3.3: respawn 2-4 h after kill)
	respawn_max = 14400, -- 4 h
})

grug_mobs.register_rare("ashmaw", {
	name = "Ashmaw",
	mob = "grug_mobs:boar",
	-- The boar model has TWO texture slots (boar.lua: {boar, blank}), and
	-- mobs:add_mob assigns def.texture straight to base_texture and to
	-- set_properties{textures=...} (api.lua:3465ff) — so it has to be the
	-- full per-slot list, not a bare string. levels.lua then reads this list
	-- as the pristine base and layers the rare violet tint on top of it.
	texture = {"grug_mobs_boar_plague.png", "grug_mobs_blank.png"},
	route = {{x = 250, z = 560}, {x = 340, z = 580}, {x = 180, z = 540}},
	biome_hint = "the savanna",
	respawn_min = 7200,
	respawn_max = 14400,
})
