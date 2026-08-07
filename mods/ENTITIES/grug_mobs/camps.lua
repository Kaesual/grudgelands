--
-- Camps: the camp-fire node, the guard-banner node and their respawn timer
-- (docs/design/biomes_mobs.md §4, row "Bandits / Mirefolk | **no ABM** —
-- camp node timer respawns 120-300 s, anchored to camp, 3-5 per camp";
-- docs/design/world.md §4 for the military outposts that reuse it).
--
-- Why a node timer and not an ABM: §4's performance justification puts camps
-- and rares "off the ABM entirely (node timers / scheduled) — zero idle
-- cost". A node timer only ticks while its mapblock is ACTIVE, i.e. while a
-- player is nearby, and it costs nothing at all otherwise. That is also why
-- the empty-area branch below is not a hack but the honest reading of the
-- situation: with no player around there are no loaded objects to count and
-- mobs:add_mob would refuse anyway (api.lua:3435, count_mobs needs a player
-- within active_block_range * 2 = 128 m).
--
-- FLOW, end to end:
--   grug_mobs.place_camp(pos, "bandit")   (WP13's settlement pass, or a
--       hand-placed node in creative -> on_construct defaults to "bandit")
--     -> node grug_mobs:camp_fire, meta _grug_camp_type = "bandit"
--     -> node timer starts
--   on_timer -> camp_tick(pos):
--       roll the camp's target size ONCE (meta _grug_camp_target, 3-5)
--       no player within 80 m?          -> re-arm short, do nothing
--       enough living camp mobs?        -> re-arm short, do nothing
--       otherwise spawn exactly ONE mob near the fire and re-arm 120-300 s
--   the spawned mob gets `_grug_home = camp pos` (WHERE it belongs: aggro.lua
--       snaps it back there when it evades further out than its radius) and
--       `_grug_camp_pos = camp pos` (WHO it belongs to — the identity the head
--       count below and the mirefolk swarm verb match on; `_grug_home` is not
--       an identity, a hand-placed mob has one too)
--   with `_grug_leash_range = 25` in the mob defs, that IS "defends camp": a
--       camp mob may be dragged 25 nodes from wherever the fight started
--       before it drops the target, heals and returns to the fire (aggro.lua
--       — the leash measures DRAG from the pull, the evade snap uses
--       `_grug_home`).
--
-- GUARD POSTS (WP6/T8) reuse the whole mechanism with a second anchor node,
-- grug_nodes:guard_banner, and the camp types "guard_accord"/"guard_throng"
-- at the bottom of this file. Two things differ:
--   * the banner is placed by MAPGEN (grug_mapgen/structures.lua) via a
--     VoxelManip, which fires no node callbacks at all — so the timer of a
--     generated banner is started by the LBM at the bottom instead of by
--     on_construct;
--   * the camp type is not chosen by the placer but by the TERRITORY the
--     banner stands in (grug_core.territory_at), so a post can never fly the
--     wrong faction's colours;
--   * a guard camp with `patrol = true` designates ONE of its guards as the
--     ambient patrol of world.md §4 (see assign_patrol below).
--
-- STATE lives in node meta, so a camp survives restarts and world unloads
-- with zero mod storage:
--   `_grug_camp_type`     string, a key of grug_mobs.registered_camp_types
--   `_grug_camp_target`   int, the rolled 3-5 (0/absent = not rolled yet)
--   `_grug_camp_patrol_t` int, gametime of the last patrol designation
--   `_grug_banner_init`   int, LBM idempotency flag (guard banners only)
--

--
-- Registry
--

grug_mobs.registered_camp_types = {}

-- id -> {mob = "grug_mobs:bandit", count_min = 3, count_max = 5, radius = 12,
--        node = "grug_mobs:camp_fire", patrol = false}
--   node   — the anchor node grug_mobs.place_camp uses for this type
--            (guard posts fly a banner, bandits sit around a fire)
--   patrol — designate one member as an ambient patrol (world.md §4)
function grug_mobs.register_camp_type(id, def)
	grug_mobs.registered_camp_types[id] = {
		mob = def.mob,
		count_min = def.count_min or 3,
		count_max = def.count_max or 5,
		radius = def.radius or 12,
		node = def.node or "grug_mobs:camp_fire",
		patrol = def.patrol or false,
	}
end

local DEFAULT_TYPE = "bandit"
local META_TYPE = "_grug_camp_type"
local META_TARGET = "_grug_camp_target"
local META_PATROL_T = "_grug_camp_patrol_t"
local META_BANNER_INIT = "_grug_banner_init"
local META_FIRE_INIT = "_grug_camp_init"

-- The two anchor nodes, by name. BANNER_NODE is needed as a value (not only
-- as a camp-type field) because place_camp has to recognise a guard post and
-- let the TERRITORY pick its type — see there.
local BANNER_NODE = "grug_nodes:guard_banner"

-- Re-arm delay when the tick had nothing to do (nobody around, camp full, no
-- free ground). Short on purpose: it is one cheap check, and it decides how
-- fast a camp repopulates once a player walks up to a stale one.
local IDLE_PERIOD = 30
-- §4: "respawns 120-300 s".
local RESPAWN_MIN, RESPAWN_MAX = 120, 300
-- Do no work at all unless a player is this close. Comfortably inside
-- mobs:add_mob's own 128 m requirement, comfortably outside the camp radius.
local PLAYER_RANGE = 80
-- Head-count radius margin on top of the camp radius: a defending camp mob
-- may stand up to its leash range from the fire, and counting it as gone
-- would let the camp overfill. radius + 16 covers every registered camp type
-- (bandit 12 + 16 > leash 25, mirefolk 10 + 16 > 25, guards 15 + 16 > 30).
--
-- That "> leash" comparison is only a sound bound because a defender CANNOT
-- park itself outside it: aggro.lua's leash_reset snaps a mob that ends a
-- chase further than its own radius from `_grug_home` straight back to the
-- fire (the evade). Without that snap the margin bounded nothing — a guard
-- walked off its post stayed off it, was counted as dead here, and the post
-- refilled behind it, one stray per pull, forever (WP6 re-review F1).
local COUNT_MARGIN = 16
-- Minimum game time between two patrol designations at ONE post. A patroller
-- walks far outside the head count (that is the point), so the post refills
-- behind it and the "camp is empty" trigger below could, over a long enough
-- world, designate one patroller after another. This caps that drift at one
-- per hour per post while still healing a post whose patrol really died.
local PATROL_INTERVAL = 3600
-- Attempts to find open ground for one new mob.
local SPOT_TRIES = 12

--
-- Helpers
--

local function camp_cfg(meta)
	local id = meta:get_string(META_TYPE)
	if id == "" then
		id = DEFAULT_TYPE
	end
	return grug_mobs.registered_camp_types[id], id
end

-- Positions read back from entity staticdata are plain tables without the
-- vector metatable, so `==` on them is silently false (luanti-lua.md rule 7).
local function same_pos(a, b)
	return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function player_near(pos, range)
	local players = core.get_connected_players()
	for i = 1, #players do
		local pp = players[i]:get_pos()
		if pp and vector.distance(pp, pos) <= range then
			return true
		end
	end
	return false
end

-- Living mobs of this camp. Identity is `_grug_camp_pos` (a plain field, so
-- it persists in staticdata with the mob), NOT an ObjectRef list — refs must
-- never be stored across steps.
--
-- Known and accepted blind spot: get_objects_inside_radius sees only ACTIVE
-- objects, so a camp member that wandered into an unloaded block is counted
-- as dead and the camp may briefly hold one mob too many. The leash range of
-- 25 keeps that window small, an extra bandit is not a balance problem, and
-- the alternative (persisting a roster in meta) would have to garbage-collect
-- entities it cannot see either.
local function count_camp_mobs(pos, cfg)
	local n = 0
	local objs = core.get_objects_inside_radius(pos, cfg.radius + COUNT_MARGIN)
	for i = 1, #objs do
		local ent = objs[i]:get_luaentity()
		if ent and ent.name == cfg.mob and (ent.health or 0) > 0
				and same_pos(ent._grug_camp_pos, pos) then
			n = n + 1
		end
	end
	return n
end

-- A standable spot in the ring around the fire: air with air above it and
-- solid, non-liquid ground below. Searched locally (pos.y +-3) instead of via
-- grug_core.find_surface, which scans the absolute band y 120..-16 and would
-- happily answer with the mountain top above a hillside camp.
local function free_spot_near(pos, radius)
	for _ = 1, SPOT_TRIES do
		local angle = math.random() * 2 * math.pi
		local dist = 2 + math.random() * math.max(0, radius - 2)
		local x = math.floor(pos.x + math.cos(angle) * dist + 0.5)
		local z = math.floor(pos.z + math.sin(angle) * dist + 0.5)
		for dy = 3, -3, -1 do
			local p = {x = x, y = pos.y + dy, z = z}
			local here = core.get_node_or_nil(p)
			local above = core.get_node_or_nil({x = x, y = p.y + 1, z = z})
			local below = core.get_node_or_nil({x = x, y = p.y - 1, z = z})
			if here and above and below
					and here.name == "air" and above.name == "air"
					and below.name ~= "air" and below.name ~= "ignore"
					and core.get_item_group(below.name, "liquid") == 0 then
				return p
			end
		end
	end
	return nil
end

-- Ambient patrol (docs/design/world.md §4: "between outposts: ambient
-- patrols — closes the 'just walk around the outpost' hole").
--
-- The route is a PLAIN table field on the entity ({points = {{x, z}, {x, z}},
-- wp = index}), so it persists in staticdata with the mob — never an
-- ObjectRef, never a function. Both endpoints come from
-- grug_core.outpost_anchors(): this post, and the adjacent outpost of the
-- same race band one ring further toward the strait. That shared anchor list
-- is the ONE source both mapgen and this file read, so a patrol can never
-- walk to a post that was never built.
--
-- A banner that is not on an outpost anchor — the capital watch of world.md
-- §3 — simply gets no route and every guard holds the platform.
local function assign_patrol(pos, meta, ent)
	local now = core.get_gametime()
	local last = meta:get_int(META_PATROL_T)
	if last > 0 and now - last < PATROL_INTERVAL then
		return
	end
	local anchor = grug_core.outpost_at(pos)
	local target = anchor and grug_core.outpost_patrol_target(anchor)
	if not target then
		return
	end
	ent._grug_patrol_route = {
		points = {{x = anchor.x, z = anchor.z}, {x = target.x, z = target.z}},
		wp = 1,
	}
	meta:set_int(META_PATROL_T, now)
	core.log("action", "[grug_mobs] patrol " .. anchor.id .. " -> " ..
		target.id .. " sent out")
end

--
-- The tick. Returns the number of seconds until the next one.
--

local function camp_tick(pos)
	local meta = core.get_meta(pos)
	local cfg, id = camp_cfg(meta)
	if not cfg then
		-- A camp type that no mod registered (typo, or a removed family):
		-- log once per tick at a slow rate instead of spinning.
		core.log("warning", "[grug_mobs] camp fire at " ..
			core.pos_to_string(pos) .. " has unknown camp type '" .. id .. "'")
		return RESPAWN_MAX
	end
	-- Camp size is rolled ONCE and kept, so a camp has a stable identity
	-- ("this is a five-bandit camp") instead of re-rolling every respawn.
	local target = meta:get_int(META_TARGET)
	if target <= 0 then
		target = math.random(cfg.count_min, cfg.count_max)
		meta:set_int(META_TARGET, target)
	end
	-- Nobody here: the objects would not be loaded and mobs:add_mob would
	-- refuse. Re-arm and leave (see the header).
	if not player_near(pos, PLAYER_RANGE) then
		return IDLE_PERIOD
	end
	local living = count_camp_mobs(pos, cfg)
	if living >= target then
		return IDLE_PERIOD
	end
	local spot = free_spot_near(pos, cfg.radius)
	if not spot then
		return IDLE_PERIOD
	end
	-- `ignore_count = true` is REQUIRED: mobs:add_mob otherwise compares
	-- against the family's mobs:spawn aoc, and a camp family has no
	-- mobs:spawn row at all, so that cap defaults to 1 (api.lua:3444) — every
	-- camp would top out at a single mob. The camp's own target is the cap.
	-- add_mob returns nil whenever it declines (no player in range, active
	-- mob limit, entity missing); that must never be an error here.
	-- grug_mobs.add_mob, not mobs:add_mob: the wrapper applies the
	-- collisionbox y-lift the ABM spawner does and add_mob does not (init.lua)
	-- — a camp family with a negative box floor would otherwise stand sunk
	-- into the ground.
	local ent = grug_mobs.add_mob(spot, {name = cfg.mob, ignore_count = true})
	if not ent then
		return IDLE_PERIOD
	end
	-- Plain-table copy, never the caller's table and never an ObjectRef.
	-- `_grug_home` is where aggro.lua's evade snaps this mob back to when it
	-- ends a chase too far out — i.e. what makes it a CAMP member and not just
	-- a mob that happens to stand here. levels.lua's ensure_init only fills the
	-- field in if it is still unset, and we are ahead of the mob's first tick
	-- here, so this wins.
	local home = {x = pos.x, y = pos.y, z = pos.z}
	ent._grug_home = home
	ent._grug_camp_pos = {x = pos.x, y = pos.y, z = pos.z}
	-- The patroller is the member spawned into an EMPTY post: it leaves
	-- immediately and the post then fills up behind it with guards that stay.
	-- Tying the designation to "empty" (instead of to a slot number) keeps the
	-- post at target + 1 mobs at most and re-sends a patrol after a wipe,
	-- while PATROL_INTERVAL bounds the drift the head count cannot see.
	if cfg.patrol and living == 0 then
		assign_patrol(pos, meta, ent)
	end
	return math.random(RESPAWN_MIN, RESPAWN_MAX)
end

--
-- The node
--

-- Shared by on_construct (hand/place_camp placement) and the LBM below
-- (mapgen placement, see there). Idempotent: the meta flag makes a second
-- call a no-op, and an already typed fire keeps its type.
local function init_camp_fire(pos)
	local meta = core.get_meta(pos)
	if meta:get_int(META_FIRE_INIT) == 1 then
		return
	end
	meta:set_int(META_FIRE_INIT, 1)
	if meta:get_string(META_TYPE) == "" then
		meta:set_string(META_TYPE, DEFAULT_TYPE)
	end
	meta:set_string("infotext", "Camp Fire")
	core.get_node_timer(pos):start(IDLE_PERIOD)
end

-- Deliberately family-agnostic ("camp fire", not "bandit fire"): the same
-- node anchors mirefolk pools and whatever WP13 adds later; the camp TYPE
-- lives in meta.
core.register_node("grug_mobs:camp_fire", {
	description = "Camp Fire",
	drawtype = "nodebox",
	tiles = {"grug_mobs_camp_fire.png"},
	paramtype = "light",
	sunlight_propagates = true,
	-- Flat fire pit: ash bed plus two crossed logs. Walkable false so mobs
	-- and players never get stuck on the camp anchor (§4 gives the camp no
	-- collision role).
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.4, 0.5},
			{-0.4, -0.4, -0.1, 0.4, -0.25, 0.1},
			{-0.1, -0.4, -0.4, 0.1, -0.25, 0.4},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5},
	},
	walkable = false,
	is_ground_content = false, -- caves and the ocean mask must not eat a camp
	light_source = 9, -- a camp fire is a landmark at night
	-- cracky 3 = diggable with a pickaxe, not by hand: destroying a camp
	-- should be a deliberate act. grug_camp = 1 is the dispatch group
	-- (AGENTS.md: dispatch on groups, not on name lists) for WP13 and for
	-- anything that later wants to find camps.
	groups = {cracky = 3, grug_camp = 1},
	sounds = default.node_sound_gravel_defaults(),
	-- PORTABLE-SPAWNER EXPLOIT: this node IS a mob spawner (its timer
	-- repopulates the camp forever). Dropping it would let a player mine a
	-- bandit camp, carry it to a safe corner behind their own walls and farm
	-- the drops on tap. Destroying a camp stays possible — it just yields
	-- nothing but the destruction. Same rule on grug_nodes:guard_banner.
	drop = "",

	on_construct = init_camp_fire,

	-- Returning `true` would re-arm with the SAME timeout (mapblock.cpp
	-- MapBlock::step: the engine calls setNodeTimer(timeout, 0) on a true
	-- return), which is not what we want — the period alternates between the
	-- idle check and the 120-300 s respawn. So we start the next timer
	-- ourselves and return false. That order is safe: the elapsed timer has
	-- already been removed from the block's list before the callback runs, so
	-- the timer started here is the one that survives.
	on_timer = function(pos)
		core.get_node_timer(pos):start(camp_tick(pos))
		return false
	end,
})

--
-- The guard post: the same mechanism on grug_nodes:guard_banner
-- (docs/design/world.md §4)
--

-- The banner NODE lives in grug_nodes, which must not depend on grug_mobs —
-- so its behaviour is attached from here, the legal cross-mod way
-- (core.override_item; grug_mobs declares grug_nodes in mod.conf, so the node
-- is registered by the time this file runs).

-- Which watch stands here: the TERRITORY decides, never the placer
-- (world.md §0/§4 — a post cannot fly the wrong faction's colours).
local function banner_camp_type(pos)
	local territory = grug_core.territory_at(pos)
	if territory ~= "accord" and territory ~= "throng" then
		-- Only reachable for a banner placed by hand in the ocean/strait: the
		-- outpost anchors are all well inside a continent rectangle. Not an
		-- error worth refusing over, but worth saying out loud.
		core.log("warning", "[grug_mobs] guard banner at " ..
			core.pos_to_string(pos) .. " stands outside both continents" ..
			" (territory '" .. tostring(territory) ..
			"'); defaulting to the Accord watch")
		territory = "accord"
	end
	return "guard_" .. territory
end

-- Shared by on_construct (hand/place_camp placement) and the LBM below
-- (mapgen placement). Idempotent: the meta flag makes a second call a no-op,
-- and an already typed banner keeps its type.
local function init_banner(pos)
	local meta = core.get_meta(pos)
	if meta:get_int(META_BANNER_INIT) == 1 then
		return
	end
	meta:set_int(META_BANNER_INIT, 1)
	if meta:get_string(META_TYPE) == "" then
		meta:set_string(META_TYPE, banner_camp_type(pos))
	end
	meta:set_string("infotext", "Guard Post")
	core.get_node_timer(pos):start(IDLE_PERIOD)
end

core.override_item("grug_nodes:guard_banner", {
	on_construct = init_banner,
	-- Same re-arm reasoning as the camp fire above: start the next timer
	-- ourselves and return false, because the period alternates between the
	-- idle check and the respawn delay.
	on_timer = function(pos)
		core.get_node_timer(pos):start(camp_tick(pos))
		return false
	end,
})

-- WHY THIS LBM EXISTS: grug_mapgen writes the outpost banners (and the
-- capital-watch banner on every spawn platform) straight into the mapchunk's
-- VoxelManip. A VM write is not set_node — it fires NO node callbacks at all,
-- so on_construct above never runs for a generated banner and its node timer
-- would never be armed. The LBM is the init path for exactly those nodes; it
-- runs once per mapblock (run_at_every_load = false), including on freshly
-- generated blocks, and init_banner's meta flag makes it idempotent on top.
core.register_lbm({
	name = "grug_mobs:guard_banner_init",
	nodenames = {BANNER_NODE},
	run_at_every_load = false,
	action = function(pos)
		init_banner(pos)
	end,
})

-- The same problem, the same fix, for the CAMP FIRE: grug_mapgen's structure
-- pass writes the deterministic bandit camps of world.md §4 straight into the
-- mapchunk's VoxelManip, which fires no node callbacks, so on_construct never
-- runs for a generated fire and its node timer would never be armed (a camp
-- that never spawns anybody). init_camp_fire does exactly what on_construct
-- does — default type "bandit", infotext, arm the timer — and its meta flag
-- makes the pair idempotent.
core.register_lbm({
	name = "grug_mobs:camp_fire_init",
	nodenames = {"grug_mobs:camp_fire"},
	run_at_every_load = false,
	action = function(pos)
		init_camp_fire(pos)
	end,
})

--
-- Placement API
--

-- Places (or re-types) a camp. This is the entry point for WP13's settlement
-- pass and for manual testing; placing the bare node by hand also works and
-- defaults to the bandit camp (fire) resp. the local faction's watch
-- (banner) via on_construct.
--
-- Returns true on success, false for an unknown camp type — a silent no-op
-- would hide a typo in a settlement schematic.
function grug_mobs.place_camp(pos, type_id)
	type_id = type_id or DEFAULT_TYPE
	local cfg = grug_mobs.registered_camp_types[type_id]
	if not cfg then
		core.log("warning", "[grug_mobs] place_camp: unknown camp type '" ..
			tostring(type_id) .. "'")
		return false
	end
	-- TERRITORY IS AUTHORITATIVE for a guard post (world.md §0/§4: "a post can
	-- never fly the wrong faction's colours"). banner_camp_type already
	-- enforces that for every OTHER placement path — on_construct and the
	-- mapgen LBM both go through it — but place_camp used to overwrite the
	-- result with the caller's type_id afterwards, so one
	-- place_camp(pos, "guard_throng") on Accord soil put a Throng garrison
	-- inside Accord territory (and its guards would then hunt the players who
	-- own that continent). The caller's wish loses; it is told so, because a
	-- settlement schematic asking for the wrong watch is a bug worth seeing.
	local effective = type_id
	if cfg.node == BANNER_NODE then
		effective = banner_camp_type(pos)
		if effective ~= type_id then
			core.log("warning", "[grug_mobs] place_camp at " ..
				core.pos_to_string(pos) .. ": requested '" .. type_id ..
				"' but the territory says '" .. effective ..
				"' — territory wins")
		end
	end
	-- set_node fires on_construct, which writes the default type and arms the
	-- timer; the two lines after it overwrite that default.
	core.set_node(pos, {name = cfg.node})
	local meta = core.get_meta(pos)
	meta:set_string(META_TYPE, effective)
	meta:set_int(META_TARGET, 0) -- re-rolled for THIS type on the first tick
	-- Populate promptly instead of after the on_construct idle period: a camp
	-- placed next to a player should not stand empty for half a minute.
	core.get_node_timer(pos):start(1)
	return true
end

--
-- The two camp types of §4
--
-- Both are "3-5 per camp" (§4 aoc column). The radii differ by habitat: a
-- bandit camp sprawls across a clearing, a mirefolk camp huddles around one
-- swamp pool (§3.1 "camps at swamp pools").
--

grug_mobs.register_camp_type("bandit", {
	mob = "grug_mobs:bandit",
	count_min = 3,
	count_max = 5,
	radius = 12,
})

grug_mobs.register_camp_type("mirefolk", {
	mob = "grug_mobs:mirefolk",
	count_min = 3,
	count_max = 5,
	radius = 10,
})

--
-- The two guard posts (world.md §4/§9)
--
-- Deliberately smaller and wider than a bandit camp: 2-3 guards (§9's
-- "guaranteed minimum" outpost is a picket, not a garrison — the numbers can
-- grow with WP13's real structures) spread over the 7x7 pad and its
-- surroundings (radius 15, the pad plus a little patrol ground). Both types
-- patrol; which of the two a banner uses follows from the territory
-- (banner_camp_type above), so the posts of one continent are all the same
-- type and the mob level still varies with the ring via guard_level_at.
--

grug_mobs.register_camp_type("guard_accord", {
	mob = "grug_mobs:guard_accord",
	count_min = 2,
	count_max = 3,
	radius = 15,
	node = "grug_nodes:guard_banner",
	patrol = true,
})

grug_mobs.register_camp_type("guard_throng", {
	mob = "grug_mobs:guard_throng",
	count_min = 2,
	count_max = 3,
	radius = 15,
	node = "grug_nodes:guard_banner",
	patrol = true,
})
