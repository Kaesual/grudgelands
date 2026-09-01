--
-- Camps: the camp-fire node, the guard-banner node and their RESPAWN SLOTS
-- (docs/design/world.md §4a "NPC binding & respawn slots";
-- docs/design/biomes_mobs.md §4, row "Bandits / Mirefolk | **no ABM** — camp
-- anchor with respawn slots: max 3-5, one refill per 120-300 s, dormant
-- catch-up"; docs/design/world.md §4 for the military outposts that reuse it).
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
--     -> node grug_nodes:camp_fire, meta _grug_camp_type = "bandit"
--     -> node timer starts
--   on_timer -> camp_tick(pos, elapsed):
--       roll the camp's target size ONCE (meta _grug_camp_target, 3-5)
--       no player within 80 m?          -> re-arm short, do nothing
--       count the living members, book the missing ones into the REFILL QUEUE
--       drain every refill whose due time has passed (see "RESPAWN SLOTS")
--   the spawned mob gets `_grug_home = camp pos` (WHERE it belongs: aggro.lua
--       runs it back there when it evades further out than its radius) and
--       `_grug_camp_pos = camp pos` (WHO it belongs to — the identity the head
--       count below and the mirefolk swarm verb match on; `_grug_home` is not
--       an identity, a hand-placed mob has one too)
--   with `_grug_leash_range = 25` in the mob defs, that IS "defends camp": a
--       camp mob may be dragged 25 nodes from wherever the fight started
--       before it drops the target, heals and returns to the fire (aggro.lua
--       — the leash measures DRAG from the pull, the evade run-home uses
--       `_grug_home`).
--
-- GUARD POSTS (WP6/T8) reuse the whole mechanism with a second anchor node,
-- grug_nodes:guard_banner, and the camp types "guard_accord"/"guard_throng"
-- at the bottom of this file. What differs:
--   * the banner is placed by R7's single named-zone map writer via a
--     VoxelManip, which fires no node callbacks at all — so the timer of a
--     generated banner is started by the LBM at the bottom (which for that
--     reason must run at EVERY load, see there) instead of by on_construct;
--   * the camp type is not chosen by the placer but by the TERRITORY the
--     banner stands in (grug_zones.faction_at), so a post can never fly the
--     wrong faction's colours;
--   * a guard camp with `patrol = true` designates ONE of its guards as the
--     ambient patrol of world.md §4 (see assign_patrol below);
--   * a post refills one slot per 180-360 s instead of the camp's 120-300 s.
--
-- RESPAWN SLOTS (world.md §4a), the model this file implements since F5.
-- The old rule was "count heads, spawn one if below target, then wait
-- 120-300 s" — a queue of ONE that forgot every death it could not serve
-- immediately: three guards killed at once came back one per interval only
-- because the tick kept re-detecting the deficit, and a camp that went
-- dormant right after a wipe restarted its clock from scratch on the next
-- visit. The production line replaces it:
--
--   * every death observed by a tick books a REFILL into the queue
--     (`_grug_refill_queue`); slots are independent, 3 dead = 3 refills;
--   * the queue carries ONE due time (`_grug_next_refill`, in
--     core.get_gametime() seconds). A refill is served when that time has
--     passed, and the due time then advances by `+ interval` — NOT by
--     `now + interval`;
--   * that `+=` is the whole dormant catch-up: no timer ticks in an
--     unloaded area, so after 15 min of dormancy the due time lags 15 min
--     behind `now`, and the drain loop below serves every refill the
--     elapsed time earned in ONE tick before the remainder continues on
--     cadence. §4a's worked example (target 4, 3 dead, interval 7 min,
--     dormant 15 min) comes out as 2 immediately + the third ~6 min later;
--   * a camp that has never been manned owes its WHOLE garrison from the
--     moment it rolled its size, due immediately (see camp_tick) — that is
--     what keeps a mapgen camp populated when a player first walks up.
--
-- WHY GAMETIME and not the mono clock: core.get_gametime() is world time —
-- it persists across restarts (which the mono clock does not) and it counts
-- while players are elsewhere in the world, so a camp nobody has visited
-- for an hour really is owed an hour of refills. It only stands still while
-- the SERVER is off (and, being world time, while the world is empty) —
-- which is exactly right too: nothing can be missing from a camp that
-- nobody can reach. Same reasoning as the player drop tag in aggro.lua.
-- 32-bit note: meta:set_int truncates to C `int` (l_metadata.cpp l_set_int
-- uses luaL_checkint), i.e. it holds gametime up to ~68 years of server
-- uptime — not a bound worth coding against.
--
-- WHY THE BOOKKEEPING DOES NOT RUN WITHOUT A PLAYER NEARBY: it does not
-- have to. The state is two numbers and a TIMESTAMP, so elapsed time is
-- measured by the clock, not by ticks — a camp that ticks once after an
-- hour of silence is in exactly the state it would be in had it ticked
-- 120 times. And a head count without a player would be a lie:
-- get_objects_inside_radius only sees ACTIVE objects, so it would read
-- every living member as dead and book refills for mobs that are merely
-- unloaded.
--
-- MIGRATION of camps that are already in a world: they carry a target but no
-- queue meta, so both new keys read 0 ("nothing owed") and the first tick
-- books whatever it finds missing with a FRESH due time (now + interval) —
-- an old camp never bursts on the first visit after the update. No LBM, no
-- version flag: "absent = 0 = nothing owed" is the correct reading of an
-- unmigrated camp, and the head count re-derives the rest.
--
-- STATE lives in node meta, so a camp survives restarts and world unloads
-- with zero mod storage:
--   `_grug_camp_type`     string, a key of grug_mobs.registered_camp_types
--   `_grug_camp_target`   int, the rolled 3-5 (0/absent = not rolled yet)
--   `_grug_refill_queue`  int, refills owed (0/absent = camp is full)
--   `_grug_next_refill`   int, gametime second the next refill is due
--   `_grug_camp_patrol_t` int, gametime of the last patrol designation
--   `_grug_camp_init`     int, init idempotency flag (camp fires)
--   `_grug_banner_init`   int, init idempotency flag (guard banners)
--

--
-- Constants
--
-- Declared ahead of the registry below because register_camp_type reads the
-- respawn defaults (a local must be in scope where the function BODY is
-- written, not only where it is called — otherwise it would silently become
-- a global read and trip strict.lua).
--

local DEFAULT_TYPE = "bandit"
local META_TYPE = "_grug_camp_type"
local META_TARGET = "_grug_camp_target"
local META_QUEUE = "_grug_refill_queue"
local META_NEXT = "_grug_next_refill"
local META_PATROL_T = "_grug_camp_patrol_t"
local META_BANNER_INIT = "_grug_banner_init"
local META_FIRE_INIT = "_grug_camp_init"

-- The camp's own heartbeat: how often it looks at itself (head count + the
-- drain check). Short on purpose — it is one cheap check, and it decides how
-- fast a camp reacts once a player walks up to a stale one. It is NOT the
-- respawn interval any more; the refill schedule lives in meta, so this only
-- bounds how LATE a due refill can be served (see camp_tick, which shortens
-- the re-arm when a refill falls due sooner).
local IDLE_PERIOD = 30
-- biomes_mobs.md §4: "one refill per 120-300 s". Per camp type overridable
-- with respawn_exact / respawn_min / respawn_max (see register_camp_type).
local RESPAWN_MIN, RESPAWN_MAX = 120, 300
-- A guard post refills SLOWER than a bandit camp (world.md §4a leaves the
-- number to the implementation): a wiped outpost that is back to full three
-- minutes later removes the point of clearing it, and a garrison is meant to
-- be re-takeable ground for a while. THE tunable of this file — raise it to
-- make outposts feel more expensive to hold, lower it to keep the roads safe.
local GUARD_RESPAWN_MIN, GUARD_RESPAWN_MAX = 180, 360
-- Do no work at all unless a player is this close. Comfortably inside
-- mobs:add_mob's own 128 m requirement, comfortably outside the camp radius.
local PLAYER_RANGE = 80
-- Head-count radius margin on top of the camp radius: a defending camp mob
-- may stand up to its leash range from the fire, and counting it as gone
-- would let the camp overfill. radius + 16 covers every registered camp type
-- (bandit 12 + 16 > leash 25, mirefolk 10 + 16 > 25, guards 15 + 16 > 30).
--
-- That "> leash" comparison is only a sound bound because a defender CANNOT
-- park itself outside it: a mob that ends a chase further than its own radius
-- from `_grug_home` is sent back to the fire by aggro.lua's evade (a run home,
-- with a teleport as the 40 s backstop — so "outside the margin" is bounded by
-- the walk, not open-ended), and since F5 the roam cap in the same file keeps
-- an IDLE camp mob inside 20 nodes of its anchor as well (world.md §4a). Without
-- those two the margin bounded nothing — a guard walked off its post stayed
-- off it, was counted as dead here, and the post refilled behind it, one
-- stray per pull, forever (WP6 re-review F1).
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
-- Registry
--

grug_mobs.registered_camp_types = {}

-- id -> {mob = "grug_mobs:bandit", count_min = 3, count_max = 5, radius = 12,
--        node = "grug_nodes:camp_fire", patrol = false,
--        respawn_exact = nil, respawn_min = 120, respawn_max = 300}
--   node          — the anchor node grug_mobs.place_camp uses for this type
--                   (guard posts fly a banner, bandits sit around a fire)
--   patrol        — designate one member as an ambient patrol (world.md §4)
--   respawn_*     — the refill interval of ONE slot (world.md §4a: "either an
--                   exact duration or a min-max range rolled per refill").
--                   respawn_exact wins when set; the range is the default.
function grug_mobs.register_camp_type(id, def)
	grug_mobs.registered_camp_types[id] = {
		mob = def.mob,
		count_min = def.count_min or 3,
		count_max = def.count_max or 5,
		radius = def.radius or 12,
		node = def.node or "grug_nodes:camp_fire",
		patrol = def.patrol or false,
		respawn_exact = def.respawn_exact,
		respawn_min = def.respawn_min or RESPAWN_MIN,
		respawn_max = def.respawn_max or RESPAWN_MAX,
	}
end

-- The two anchor nodes, by name. BANNER_NODE is needed as a value (not only
-- as a camp-type field) because place_camp has to recognise a guard post and
-- let the TERRITORY pick its type — see there.
local BANNER_NODE = "grug_nodes:guard_banner"
local CAMP_FIRE_NODE = "grug_nodes:camp_fire"

-- Forward declaration: camp_cfg (a helper, far above the guard-post section)
-- needs the territory rule to type a banner whose meta went missing. The
-- definition lives with the rest of the guard-post code further down.
local banner_camp_type

--
-- Helpers
--

-- Config of the camp anchored at pos. The type normally comes from meta; the
-- fallback for an EMPTY meta value is decided by the NODE, never by
-- DEFAULT_TYPE alone: a guard banner that lost its meta (a /clearobjects-style
-- accident, a hand-placed node whose on_construct was bypassed, an old world
-- from before the init LBMs ran) would otherwise be read as a bandit camp and
-- spawn BANDITS inside a military outpost. Territory stays authoritative for a
-- banner here exactly as it is in place_camp and init_banner; only the camp
-- fire falls back to "bandit".
local function camp_cfg(pos, meta)
	local id = meta:get_string(META_TYPE)
	if id == "" then
		local node = core.get_node(pos)
		if node.name == BANNER_NODE then
			id = banner_camp_type(pos)
		else
			id = DEFAULT_TYPE
		end
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
-- solid, non-liquid ground below. Searched locally (pos.y +-3) because a camp
-- refill must not substitute a different authored terrain level.
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
-- ObjectRef, never a function. R7 authenticates all 24 outpost anchors and
-- projects WP6's three-leg patrol chain onto each race's authored four-row
-- home-to-frontier order: 1 -> 2 -> 3 -> 4, with 4 returning to 3.
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
	-- Both endpoints come from the same exact validated payload.
	local ax, az = grug_core.outpost_position(anchor)
	local tx, tz = grug_core.outpost_position(target)
	ent._grug_patrol_route = {
		points = {{x = ax, z = az}, {x = tx, z = tz}},
		wp = 1,
	}
	meta:set_int(META_PATROL_T, now)
	core.log("action", "[grug_mobs] patrol " .. anchor.id .. " -> " ..
		target.id .. " sent out")
end

--
-- Refills
--

-- How long ONE slot takes (world.md §4a: "either an exact duration or a
-- min-max range rolled per refill"). Rolled per refill, never cached, so a
-- camp's rhythm stays irregular.
local function roll_interval(cfg)
	if cfg.respawn_exact then
		return cfg.respawn_exact
	end
	return math.random(cfg.respawn_min, cfg.respawn_max)
end

-- Serve ONE refill. Returns true when a mob really arrived; false means the
-- ground was blocked or mobs:add_mob declined — the caller must then leave
-- the due time alone and retry on a later tick, or the camp would silently
-- eat the refill it could not serve.
--
-- `living` is the head count BEFORE this spawn (the patrol rule below reads
-- it), which is why the drain loop counts up as it goes.
local function spawn_one(pos, meta, cfg, living)
	local spot = free_spot_near(pos, cfg.radius)
	if not spot then
		return false
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
		return false
	end
	-- Plain-table copy, never the caller's table and never an ObjectRef.
	-- `_grug_home` is where aggro.lua's evade sends this mob back to when it
	-- ends a chase too far out, and what its idle roam cap measures against
	-- (world.md §4a) — i.e. what makes it a CAMP member and not just a mob
	-- that happens to stand here. levels.lua's ensure_init only fills the
	-- field in if it is still unset, and we are ahead of the mob's first tick
	-- here, so this wins.
	ent._grug_home = {x = pos.x, y = pos.y, z = pos.z}
	ent._grug_camp_pos = {x = pos.x, y = pos.y, z = pos.z}
	-- The patroller is the member spawned into an EMPTY post: it leaves
	-- immediately and the post then fills up behind it with guards that stay.
	-- Tying the designation to "empty" (instead of to a slot number) keeps the
	-- post at target + 1 mobs at most and re-sends a patrol after a wipe,
	-- while PATROL_INTERVAL bounds the drift the head count cannot see.
	if cfg.patrol and living == 0 then
		assign_patrol(pos, meta, ent)
	end
	return true
end

--
-- The tick. Returns the number of seconds until the next one.
--
-- `elapsed` is what the engine says really passed since the timer was armed
-- (lua_api.md on_timer). It is normally the armed timeout; it is MUCH larger
-- on the first tick after the mapblock was dormant, because the engine steps
-- a reactivated block's timers by the whole downtime in one go
-- (serverenvironment.cpp activateBlock -> block->step(dtime_s), and
-- nodetimer.cpp NodeTimerList::step hands the overshoot to the callback).
-- That single catch-up tick is what makes the drain loop below spawn
-- everything a dormant camp is owed the moment a player shows up.
--

local function camp_tick(pos, elapsed)
	local meta = core.get_meta(pos)
	local cfg, id = camp_cfg(pos, meta)
	if not cfg then
		-- A camp type that no mod registered (typo, or a removed family):
		-- log once per tick instead of spinning. IDLE_PERIOD and not something
		-- slower, so this function keeps its invariant that it NEVER re-arms
		-- longer than IDLE_PERIOD — the catch-up detection further down reads
		-- `elapsed > IDLE_PERIOD + 1` as "the mapblock was dormant", and a
		-- longer re-arm here would make that a lie the moment the missing camp
		-- type is registered again (a mod re-enabled mid-world).
		core.log("warning", "[grug_mobs] camp fire at " ..
			core.pos_to_string(pos) .. " has unknown camp type '" .. id .. "'")
		return IDLE_PERIOD
	end
	local now = core.get_gametime()
	-- Camp size is rolled ONCE and kept, so a camp has a stable identity
	-- ("this is a five-bandit camp") instead of re-rolling every respawn.
	local target = meta:get_int(META_TARGET)
	if target <= 0 then
		target = math.random(cfg.count_min, cfg.count_max)
		meta:set_int(META_TARGET, target)
		-- FIRST POPULATION. A camp that has only just rolled its size has
		-- never been manned, so its whole garrison is owed and the first
		-- refill is due RIGHT NOW: one member arrives on this very tick (as
		-- it did before the slot model) and the rest follow on cadence. A
		-- camp that mapgen wrote into a chunk nobody has visited collects
		-- that debt while it waits — by the time someone finally walks up,
		-- the due time lies far in the past and the drain hands it its full
		-- garrison at once, which is what a camp standing in the world is
		-- supposed to look like.
		meta:set_int(META_QUEUE, target)
		meta:set_int(META_NEXT, now)
	end
	-- Nobody here: the head count would read every unloaded member as dead
	-- and mobs:add_mob would refuse anyway. Re-arm and leave — the refill
	-- schedule is a pair of timestamps and loses nothing by not being looked
	-- at (see the header).
	if not player_near(pos, PLAYER_RANGE) then
		return IDLE_PERIOD
	end
	local living = count_camp_mobs(pos, cfg)
	local queue = meta:get_int(META_QUEUE)
	local next_refill = meta:get_int(META_NEXT)
	-- What is on disk right now, so the write-back at the end can skip a
	-- no-op: a full camp ticks every IDLE_PERIOD forever, and set_int marks
	-- the mapblock dirty unconditionally — writing the same two numbers back
	-- every 30 s would re-save the block for the whole time a player stands
	-- anywhere near it.
	local queue_on_disk, next_on_disk = queue, next_refill
	-- A queue with no due time is meta damage (an admin edit, a half-written
	-- block): schedule it instead of letting the drain read "due at second 0"
	-- and empty the whole queue at once.
	if queue > 0 and next_refill <= 0 then
		next_refill = now + roll_interval(cfg)
	end
	local missing = target - living
	if missing > queue then
		-- Deaths this camp had not booked yet: everything missing BEYOND the
		-- queue is new. The clock starts only when the queue was empty —
		-- otherwise a fresh death would push back the refill already running.
		--
		-- Skipped on a CATCH-UP tick: a block that just reactivated may hold
		-- members whose own mapblock has not been activated yet, and those
		-- read as dead here. Booking that would make a camp overfill a little
		-- more with every visit — and guards never despawn. The queue itself
		-- is unaffected (it is authoritative, not derived from the count), so
		-- the drain below still serves everything the dormancy earned; a real
		-- death simply gets booked one heartbeat later. `elapsed` can only
		-- exceed IDLE_PERIOD when time was skipped, because this function
		-- never re-arms longer than that.
		if not elapsed or elapsed <= IDLE_PERIOD + 1 then
			if queue <= 0 then
				next_refill = now + roll_interval(cfg)
			end
			queue = missing
		end
	elseif missing < queue then
		-- The queue overcounts: a member the last tick could not see walked
		-- back into range (or an admin added mobs). Self-correcting — the
		-- head count is the truth about the PRESENT, the queue only about
		-- what is owed. Negative `missing` (camp overfull) clamps to 0.
		queue = missing > 0 and missing or 0
	end
	-- THE DRAIN. `next_refill = next_refill + interval` (not `now +
	-- interval`) is the entire dormant catch-up: after a long silence the due
	-- time lags far behind `now`, so this loop serves every refill the
	-- elapsed time earned, one interval apart, and stops on the first one
	-- that is still in the future. Bounded by the queue, which is bounded by
	-- the target (<= 5), so the worst case is five spawns in one tick.
	local blocked = false
	while queue > 0 and now >= next_refill do
		if not spawn_one(pos, meta, cfg, living) then
			-- No free ground / add_mob declined: retry on a later tick and
			-- deliberately do NOT advance the due time, so the refill is late
			-- rather than lost.
			blocked = true
			break
		end
		living = living + 1
		queue = queue - 1
		next_refill = next_refill + roll_interval(cfg)
	end
	if queue ~= queue_on_disk then
		meta:set_int(META_QUEUE, queue)
	end
	if next_refill ~= next_on_disk then
		meta:set_int(META_NEXT, next_refill)
	end
	if queue <= 0 or blocked then
		return IDLE_PERIOD
	end
	-- A refill is pending: wake up when it falls due, but never later than
	-- the heartbeat (which keeps the head count running) and never faster
	-- than once a second.
	local wait = next_refill - now
	if wait < 1 then
		wait = 1
	elseif wait > IDLE_PERIOD then
		wait = IDLE_PERIOD
	end
	return wait
end

--
-- The node
--

-- Shared by on_construct (hand/place_camp placement) and the LBM below
-- (mapgen placement, see there). Idempotent: the meta flag makes a second
-- call a no-op, and an already typed fire keeps its type.
--
-- The TIMER is armed BEFORE that early return, on purpose. The LBM runs at
-- every load (see there), so this function is the one place that sees every
-- camp fire on every activation — and a fire whose timer went missing (an old
-- world generated before the init LBM existed, a mapblock written by a tool,
-- an engine-side loss) would otherwise stay a dead node forever while its meta
-- flag says "initialised". `is_started` keeps the repeat cost at one meta read
-- plus one timer query per node per activation and never re-arms a running
-- timer, so a camp mid-respawn is not reset by a reload.
--
-- THE ORDER MATTERS AND IT IS IN OUR FAVOUR (checked against the engine):
-- activateBlock runs the LBMs FIRST and steps the block's node timers AFTER
-- (serverenvironment.cpp:576/581). So on the activation of a dormant camp
-- this function sees the stored timer still armed and un-fired —
-- `is_started()` is true, we leave it alone, and the catch-up tick that the
-- following block->step(dtime_s) delivers survives. Re-arming here would
-- have thrown away exactly the tick that drains a dormant camp's owed
-- refills (world.md §4a).
local function init_camp_fire(pos)
	local timer = core.get_node_timer(pos)
	if not timer:is_started() then
		timer:start(IDLE_PERIOD)
	end
	local meta = core.get_meta(pos)
	if meta:get_int(META_FIRE_INIT) == 1 then
		return
	end
	meta:set_int(META_FIRE_INIT, 1)
	if meta:get_string(META_TYPE) == "" then
		meta:set_string(META_TYPE, DEFAULT_TYPE)
	end
	meta:set_string("infotext", "Camp Fire")
end

-- grug_nodes owns both pure activation nodes so R7 can authenticate them before
-- grug_mobs loads. This higher layer supplies their runtime behaviour. The old
-- name is a compatibility alias only; fresh R7 worlds write CAMP_FIRE_NODE.
core.register_alias("grug_mobs:camp_fire", CAMP_FIRE_NODE)
core.override_item(CAMP_FIRE_NODE, {
	on_construct = init_camp_fire,
	-- Returning true would make the engine re-arm the elapsed timer with its
	-- old timeout. Refill proximity changes the next period, so install that
	-- freshly computed timeout ourselves and leave the expired timer stopped.
	on_timer = function(pos, elapsed)
		core.get_node_timer(pos):start(camp_tick(pos, elapsed))
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
-- Assigns the forward-declared local at the top of the file (camp_cfg uses it
-- as the meta-less fallback); NOT a global.
function banner_camp_type(pos)
	local territory = grug_zones.faction_at(pos)
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
--
-- Same self-healing arm as init_camp_fire above and for the same reason: the
-- LBM runs at every load, so an outpost banner whose node timer was lost gets
-- it back on the next activation instead of standing there as a decorative
-- flag with no garrison. `is_started` never resets a running timer — which,
-- per the engine ordering noted at init_camp_fire, is what keeps a dormant
-- post's catch-up tick intact.
local function init_banner(pos)
	local timer = core.get_node_timer(pos)
	if not timer:is_started() then
		timer:start(IDLE_PERIOD)
	end
	local meta = core.get_meta(pos)
	if meta:get_int(META_BANNER_INIT) == 1 then
		return
	end
	meta:set_int(META_BANNER_INIT, 1)
	if meta:get_string(META_TYPE) == "" then
		meta:set_string(META_TYPE, banner_camp_type(pos))
	end
	meta:set_string("infotext", "Guard Post")
end

core.override_item("grug_nodes:guard_banner", {
	on_construct = init_banner,
	-- Same re-arm reasoning as the camp fire above: start the next timer
	-- ourselves and return false, because the period shortens when a refill
	-- is about to fall due.
	on_timer = function(pos, elapsed)
		core.get_node_timer(pos):start(camp_tick(pos, elapsed))
		return false
	end,
})

-- WHY THIS LBM EXISTS: R7's named-zone writer writes the outpost banners (and
-- the capital-watch banner on every spawn platform) straight into the
-- mapchunk's VoxelManip. A VM write is not set_node — it fires NO node
-- callbacks at all, so on_construct above never runs for a generated banner
-- and its node timer would never be armed. The LBM is the init path for
-- exactly those nodes.
--
-- WHY run_at_every_load = true, and why `false` was a total loss here:
-- lua_api.md:10312-10316 spells the semantics out — a `false` LBM only runs on
-- a mapblock whose "last active" timestamp is OLDER than the LBM's
-- introduction timestamp, and a block's timestamp is set WHEN IT IS GENERATED.
-- So `false` means "run once on blocks that already existed before this LBM
-- was introduced" and, verbatim from the docs, "It never runs on mapblocks
-- generated after the LBM's introduction". Every banner in this game is placed
-- by mapgen, i.e. in a block generated after the LBM existed — the init never
-- ran for a single one of them, no timer was ever armed, and the entire guard
-- post / bandit camp mechanism was dead in every world (engine side:
-- LBMManager puts a non-every-load LBM into the bucket of its introduction
-- time, and getLBMsIntroducedAfter only ever selects buckets at or after the
-- block's own, i.e. later, timestamp).
-- `true` runs the action on EVERY activation of a block holding this node,
-- which is what the two init functions are written for (cheap, idempotent,
-- self-healing). It also repairs EXISTING worlds: the engine refiles the LBM
-- into the always-selected bucket on the next load, so every banner already in
-- the map gets its timer on the next visit.
core.register_lbm({
	name = "grug_mobs:guard_banner_init",
	nodenames = {BANNER_NODE},
	run_at_every_load = true,
	action = function(pos)
		init_banner(pos)
	end,
})

-- The same problem, the same fix, for the CAMP FIRE: R7's named-zone writer
-- writes the deterministic bandit camps of world.md §4 straight into the
-- mapchunk's VoxelManip, which fires no node callbacks, so on_construct never
-- runs for a generated fire and its node timer would never be armed (a camp
-- that never spawns anybody). init_camp_fire does exactly what on_construct
-- does — default type "bandit", infotext, arm the timer — and its meta flag
-- makes the pair idempotent.
--
-- run_at_every_load = true for exactly the reason spelled out at the banner
-- LBM above: with `false` this LBM would never have run on a single
-- mapgen-placed fire (they all live in blocks generated after the LBM's
-- introduction), and no bandit camp in the world would ever have spawned
-- anybody.
core.register_lbm({
	name = "grug_mobs:camp_fire_init",
	nodenames = {CAMP_FIRE_NODE},
	run_at_every_load = true,
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
	-- A re-typed camp is a NEW camp: its slots belong to the old population
	-- (possibly of a different mob and a different size), so the queue and its
	-- due time start empty and the first tick books whatever is missing.
	meta:set_int(META_QUEUE, 0)
	meta:set_int(META_NEXT, 0)
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
-- Their refill slot runs slower than a camp's (GUARD_RESPAWN_MIN/MAX,
-- 180-360 s — THE tunable of this file, see there): clearing a post should
-- buy a while of open road.
--

grug_mobs.register_camp_type("guard_accord", {
	mob = "grug_mobs:guard_accord",
	count_min = 2,
	count_max = 3,
	radius = 15,
	node = "grug_nodes:guard_banner",
	patrol = true,
	respawn_min = GUARD_RESPAWN_MIN,
	respawn_max = GUARD_RESPAWN_MAX,
})

grug_mobs.register_camp_type("guard_throng", {
	mob = "grug_mobs:guard_throng",
	count_min = 2,
	count_max = 3,
	radius = 15,
	node = "grug_nodes:guard_banner",
	patrol = true,
	respawn_min = GUARD_RESPAWN_MIN,
	respawn_max = GUARD_RESPAWN_MAX,
})
