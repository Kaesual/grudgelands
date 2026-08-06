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

--
-- The two forest-pair rares (biomes_mobs §3.3: Old Whitefang ~L32 in the
-- A-center deep forest / outer, Marrowclaw ~L35 in the T-west bone forest /
-- outer)
--
-- Same rule as above: the level is a property of WHERE the route runs.
-- Field math from grug_core/init.lua (radial_n + level_at_n):
--
--   dx = max(|x| - 300, 0)              CORE_X_HALF = 300
--   dz = | |z| - 900 |                  SEAT_Z = 900
--   n  = sqrt((dx/1150)^2 + (dz/f)^2)   FIELD_X = 1150, f = 1000 on the
--                                       strait side (|z| < 900), 775 behind
--   L  = 25 + (n - 0.55)/0.35 * 20      for 0.55 < n <= 0.90
--
-- Zone check for all six points: n > 0.55 = "outer"; none of them is in the
-- coast band (needs |x| > 1350 or |z| > 1550) and all have |z| > 600, so the
-- war-coast cap does not apply either.
--

-- Old Whitefang — Accord centre, deep-forest back country.
--   (200, -1400): dx 0, dz 500 -> n 0.6452 -> L 30.4 -> 30
--   (300, -1440): dx 0, dz 540 -> n 0.6968 -> L 33.4 -> 33
--   (150, -1425): dx 0, dz 525 -> n 0.6774 -> L 32.3 -> 32
-- Average ~32, exactly the §3.3 target. The route deliberately sits at
-- |z| ~1400 rather than nearer the coast: further out the field climbs
-- past 39. That band is the meadows/deep-forest voronoi overlap (§1.3
-- "settled inner, patchy middle, wild outer"), i.e. forest patches — which
-- is what the broadcast hint promises and where grug_mobs:wolf spawns
-- anyway (forest litter AND grass are in its whitelist).
-- No `texture`: the base wolf skin is the grey-white one, and levels.lua
-- lays the rare violet tint over it.
grug_mobs.register_rare("old_whitefang", {
	name = "Old Whitefang",
	mob = "grug_mobs:wolf",
	route = {{x = 200, z = -1400}, {x = 300, z = -1440}, {x = 150, z = -1425}},
	biome_hint = "the deep forest",
	respawn_min = 7200, -- 2 h (§3.3: respawn 2-4 h after kill)
	respawn_max = 14400, -- 4 h
})

-- Marrowclaw — Throng west, bone forest (grug_bone_forest cuboid
-- x -1500..-750, §1.3).
--   (-1050, 1150): dx 750, dz 250 -> n 0.7276 -> L 35.2 -> 35
--   (-1120, 1060): dx 820, dz 160 -> n 0.7423 -> L 36.0 -> 36
--   ( -980, 1230): dx 680, dz 330 -> n 0.7287 -> L 35.2 -> 35
-- Average ~35, the §3.3 target. NB the level out here is driven by the x
-- axis, not by z: at |z| ~1000 the dz term is small, so the route has to sit
-- around |x| ~1050 to reach L35 — closer to the capital (|x| ~900) the field
-- is still ~24, which is why the route is further west than a first guess.
-- No `texture`: grug_mobs:plaguehide_bear already wears the right skin.
grug_mobs.register_rare("marrowclaw", {
	name = "Marrowclaw",
	mob = "grug_mobs:plaguehide_bear",
	route = {{x = -1050, z = 1150}, {x = -1120, z = 1060}, {x = -980, z = 1230}},
	biome_hint = "the bone forest",
	respawn_min = 7200,
	respawn_max = 14400,
})

--
-- The four mountain/jungle rares (biomes_mobs §3.3, WP6/T6)
--
-- Same rule as above: the level is a property of WHERE the route runs, and
-- the field math is the one quoted before Old Whitefang —
--
--   dx = max(|x| - 300, 0) ; dz = | |z| - 900 |
--   n  = sqrt((dx/1150)^2 + (dz/f)^2)   f = 1000 for |z| < 900, else 775
--   L  = 25 + (n - 0.55)/0.35 * 20      for 0.55 < n <= 0.90
--   L  = 45 + (n - 0.90)/0.10 * 15      for 0.90 < n <= 1.00
--
-- — plus the second segment above, which the two coast rares need.
-- Zone reminder (grug_core.zone_at): "coast" is |x| >= 1350 or |z| >= 1550;
-- everything else with n > 0.55 is "outer". None of the twelve points below
-- is inside the war-coast cap band (all have |z| > 600).
--

-- Korgan's Bane — Accord west, high crags (grug_crags cuboid x -1500..-750,
-- §1.3; all three points also sit WEST of the grug_pine_hills cuboid edge at
-- x -1250, so the patch mosaic around them is crags, not pine hills).
--   (-1270,  -880): dx 970, dz  20, f 1000 -> n 0.8437 -> L 41.78 -> 42
--   (-1260,  -760): dx 960, dz 140, f 1000 -> n 0.8464 -> L 41.94 -> 42
--   (-1290, -1000): dx 990, dz 100, f  775 -> n 0.8705 -> L 43.31 -> 43
-- Average ~42, the §3.3 target. Out here the level is driven by the x axis
-- (same as Marrowclaw): |x| has to reach ~1270 for L42, while |z| only
-- fine-tunes. All three stay inside |x| < 1350, i.e. zone "outer" as §3.3
-- asks, not "coast".
--
-- NB the base family is the game's only DEF-LEVEL ELITE (golem.lua,
-- _grug_tier = "elite"). set_tier(ent, "rare") in try_spawn REPLACES that
-- tier, it does not stack on it: the rare multipliers are applied to the base
-- formula (x5 HP / x2.2 dmg / x6 XP, armor 70, scale x2), and
-- apply_tier_visuals scales relative to the tier already APPLIED — which at
-- that moment is still "normal", because set_tier runs before the mob's first
-- tick and ensure_init then does level, stats, scale and tint in one go
-- (levels.lua). So Korgan's Bane is x2 scale and violet, never x1.6 gold or
-- x3.2 of both. It keeps the golem's telegraph (telegraph.lua fires for
-- "elite" AND "rare").
-- No `texture`: grug_mobs:stone_golem already wears the crags skin.
grug_mobs.register_rare("korgans_bane", {
	name = "Korgan's Bane",
	mob = "grug_mobs:stone_golem",
	route = {{x = -1270, z = -880}, {x = -1260, z = -760}, {x = -1290, z = -1000}},
	biome_hint = "the high crags",
	respawn_min = 7200, -- 2 h (§3.3: respawn 2-4 h after kill)
	respawn_max = 14400, -- 4 h
})

-- Silkfang — Accord east, jungle fringe COAST (grug_jungle_fringe cuboid
-- x 1150..1500, §1.3).
--   (1356,  -740): dx 1056, dz 160, f 1000 -> n 0.9321 -> L 49.81 -> 50
--   (1352, -1043): dx 1052, dz 143, f  775 -> n 0.9332 -> L 49.98 -> 50
--   (1350, -1060): dx 1050, dz 160, f  775 -> n 0.9361 -> L 50.41 -> 50
-- Exactly L50 at all three points, the §3.3 target, and all three are zone
-- "coast" (|x| >= 1350).
--
-- DEVIATION worth knowing: "coast" and "~L50" together pin |z| to roughly
-- 740..1060. At |x| >= 1350 the field already sits at L47 where dz = 0, and
-- the back-side scale 775 makes it climb fast — (1350, -1300) is L60, so a
-- route further from the seat cannot be L50 no matter how it is shaped.
-- The x values are likewise the INNER edge of the coast band on purpose: the
-- ocean mask insets the shoreline by 0..150 nodes (grug_mapgen/structures.lua
-- INSET_MAX), so a route point at |x| 1450 would often be open water, where
-- route_pos returns nil and the rare never spawns. |x| ~1350 needs an inset
-- close to the clamp before it floods, and the first point sits ~300 nodes
-- away in z — the coast noise has spread 300, so the two ends of the route do
-- not share one noise lobe and cannot both be under water for the same reason.
-- No `texture`: grug_mobs:jungle_spider already wears the jungle skin.
grug_mobs.register_rare("silkfang", {
	name = "Silkfang",
	mob = "grug_mobs:jungle_spider",
	route = {{x = 1356, z = -740}, {x = 1352, z = -1043}, {x = 1350, z = -1060}},
	biome_hint = "the jungle fringe",
	respawn_min = 7200,
	respawn_max = 14400,
})

-- Dustwing — Throng centre, badlands back country (grug_badlands cuboid
-- x -700..700, z 1100..1700, §1.3).
--   (300, 1500): dx   0, dz 600, f 775 -> n 0.7742 -> L 37.81 -> 38
--   (400, 1500): dx 100, dz 600, f 775 -> n 0.7791 -> L 38.09 -> 38
--   (220, 1490): dx   0, dz 590, f 775 -> n 0.7613 -> L 37.07 -> 37
-- Average ~38, the §3.3 target. Here the z axis does the work: inside the
-- centre band dx is 0 up to |x| 300, so the level is essentially 20 * (dz/775
-- - 0.55)/0.35 + 25. The route stops at |z| 1500 — from 1550 on the back
-- coast band starts (zone "coast", §3.3 says "outer") and the field passes 40.
-- No `texture`: grug_mobs:vulture already wears the dark badlands retint.
grug_mobs.register_rare("dustwing", {
	name = "Dustwing",
	mob = "grug_mobs:vulture",
	route = {{x = 300, z = 1500}, {x = 400, z = 1500}, {x = 220, z = 1490}},
	biome_hint = "the badlands",
	respawn_min = 7200,
	respawn_max = 14400,
})

-- Emerald Coil — Throng east, deep jungle COAST (grug_deep_jungle cuboid
-- x 750..1500, §1.3).
--   (1352,  976): dx 1052, dz  76, f 775 -> n 0.9200 -> L 48.00 -> 48
--   (1355,  800): dx 1055, dz 100, f 1000 -> n 0.9228 -> L 48.42 -> 48
--   (1350, 1020): dx 1050, dz 120, f  775 -> n 0.9261 -> L 48.91 -> 49
-- Average ~48, the §3.3 target; all three are zone "coast" (|x| >= 1350).
-- Same two constraints as Silkfang apply and are handled the same way: the
-- level pins |z| to ~800..1020, and the x values hug the inner edge of the
-- coast band so the coast-noise inset cannot drown the whole route (the
-- middle point is ~200 nodes away in z from the other two).
-- No `texture`: grug_mobs:serpent has only the one skin.
grug_mobs.register_rare("emerald_coil", {
	name = "Emerald Coil",
	mob = "grug_mobs:serpent",
	route = {{x = 1352, z = 976}, {x = 1355, z = 800}, {x = 1350, z = 1020}},
	biome_hint = "the deep jungle",
	respawn_min = 7200,
	respawn_max = 14400,
})

--
-- Captain Bonerattle x2 (biomes_mobs §3.3, WP6/T7)
--
-- §3.3's last row: "Captain Bonerattle (x2, one per continent) | Skeleton
-- Raider | war coast | 28". Both instances carry the SAME name — they are
-- the same legend on both shores of the strait, one per continent, exactly
-- as the row says; only the ids differ.
--
-- LEVEL VERIFICATION — the war coast is the one place where the radial field
-- does NOT decide, the CAP does (grug_core/init.lua):
--
--   war_coast_cap(az) = 20 + (az - 100) / (300 - 100) * 10     for az <= 300
--   mob_level_at      = min(level_at_n(radial_n), cap)         inside the band
--
-- so the level is a pure function of |z| as long as the uncapped field stays
-- ABOVE the cap. Both routes run at |z| = 268 -> cap 28.40 -> **L28** after
-- math.round (levels.lua). The uncapped field at the six points, for the
-- record (dx = max(|x|-300, 0), dz = |az - 900| = 632, f = 1000 because
-- az < 900, n = sqrt((dx/1150)^2 + (dz/f)^2), L = 25 + (n-0.55)/0.35 * 20):
--   x  285 -> dx   0 -> n 0.6320 -> L 29.7  \
--   x  410 -> dx 110 -> n 0.6392 -> L 30.1   |  all > 28.40,
--   x  535 -> dx 235 -> n 0.6642 -> L 31.5   |  so the CAP governs
--   x  555 -> dx 255 -> n 0.6698 -> L 31.8   |  at every point and
--   x  680 -> dx 380 -> n 0.7166 -> L 34.5   |  the level is uniform
--   x  805 -> dx 505 -> n 0.7696 -> L 37.5  /
-- Zone check: |z| 268 is > CONTINENT_Z_MIN (100) and <= WAR_COAST_Z (300),
-- so grug_core.zone_at answers "war_coast" for all six; |x| stays well under
-- 1350, so none of them slips into the "coast" band.
--
-- WHY |z| = 268 AND NOT NEARER THE WATER: the ocean mask insets the coastline
-- 0..150 nodes INTO the rectangle (grug_mapgen/structures.lua INSET_MAX), so
-- the strait-facing shoreline wanders between |z| 100 and 250 and the dry
-- beach only starts ~30 nodes further in (§1.5). A route at |z| 150..250
-- would often be open water, where route_pos returns nil and the rare never
-- spawns at all. |z| 268 still yields exactly 28 (the cap only reaches 30 at
-- |z| 300) and sits behind the deepest possible inset.
--
-- WHY THESE EXACT x VALUES: the coast noise is WORLD-SEED INDEPENDENT —
-- LuaValueNoise::l_get_2d evaluates NoiseFractal2D with seed 0, so
-- coast_inset(x, z) is the same number in every world and the coastline can
-- be computed offline. All six columns were checked against the real mask
-- formula (continent_distance -> surface_cap(d - coast_inset)) and come out
-- ABOVE water level, together with their +-8 node neighbourhood; the ~10% of
-- the |z| 268 band that the mask floods is avoided by construction instead of
-- by luck. The two continents needed DIFFERENT x values because the noise is
-- not mirrored at z = 0 — this is the one rare pair that is not a geometric
-- mirror, and that is why.
--
-- WHY THE ROUTE SPANS ONLY 250 NODES: `_grug_home` is the point a rare
-- happened to SPAWN at, and the leash check compares against
-- grug_mobs.RARE_LEASH_RANGE = 300 (aggro.lua). A rare that has ambled to the
-- far end of a longer route would sit further from its home than the leash
-- allows and reset — heal to full, drop the target — on every single pull,
-- i.e. it would be unkillable. 250 keeps the whole route inside the leash
-- from any spawn point, with room to be pulled a little further.
--
-- No `texture`: grug_mobs:skeleton_raider already wears the grimy war-coast
-- bones, and levels.lua lays the rare violet tint over them.
--

grug_mobs.register_rare("bonerattle_south", {
	name = "Captain Bonerattle",
	mob = "grug_mobs:skeleton_raider",
	-- Accord is negative z (grug_core.territory_at).
	route = {{x = 555, z = -268}, {x = 680, z = -268}, {x = 805, z = -268}},
	biome_hint = "the war coast",
	respawn_min = 7200, -- 2 h (§3.3: respawn 2-4 h after kill)
	respawn_max = 14400, -- 4 h
})

-- Same |z|, same span, same level — different x because the coast noise is
-- not z-symmetric (see above). Two instances of ONE legend: §3.3 lists
-- "Captain Bonerattle (x2, one per continent)", so both carry the same
-- `name` and only the registry ids differ. The ids keep them apart where it
-- matters: find_existing/rare_watch match on `_grug_rare_id`, so the northern
-- captain can never be mistaken for the southern one.
grug_mobs.register_rare("bonerattle_north", {
	name = "Captain Bonerattle",
	mob = "grug_mobs:skeleton_raider",
	route = {{x = 285, z = 268}, {x = 410, z = 268}, {x = 535, z = 268}},
	biome_hint = "the war coast",
	respawn_min = 7200,
	respawn_max = 14400,
})
