--
-- Guard posts: the guard-banner node and its RESPAWN SLOTS
-- (docs/design/world.md §4a "NPC binding & respawn slots", §4 for the
-- military outposts), and the recipe camps of the spawn regions (bottom of
-- this file).
--
-- Why a node timer and not an ABM: §4's performance justification puts camps
-- and rares "off the ABM entirely (node timers / scheduled) — zero idle
-- cost". A node timer only ticks while its mapblock is ACTIVE, i.e. while a
-- player is nearby, and it costs nothing at all otherwise. That is also why
-- the empty-area branch below is not a hack but the honest reading of the
-- situation: with no player around there are no loaded objects to count and
-- mobs:add_mob would refuse anyway (api.lua, count_mobs needs a player
-- within active_block_range * 2 = 128 m).
--
-- FLOW, end to end:
--   R7's named-zone writer places grug_nodes:guard_banner (or a hand-placed
--     banner in creative); the LBM / on_construct types it and arms its timer
--   on_timer -> camp_tick(pos, elapsed):
--       roll the post's target size ONCE (meta _grug_camp_target, 2-3)
--       no player within 80 m?          -> re-arm short, do nothing
--       count the living members, book the missing ones into the REFILL QUEUE
--       drain every refill whose due time has passed (see "RESPAWN SLOTS")
--   the spawned guard gets `_grug_home = post pos` (WHERE it belongs:
--       aggro.lua runs it back there when it evades further out than its
--       radius) and `_grug_camp_pos = post pos` (WHO it belongs to — the
--       identity the head count below matches on; `_grug_home` is not an
--       identity, a hand-placed mob has one too)
--
-- What a guard post does beyond the slots:
--   * an authenticated outpost anchor supplies its race-bound garrison
--     faction; other banners use the faction territory they stand in. This is
--     necessary because frontier outposts deliberately stand on contested
--     land, where grug_zones.faction_at returns nil;
--   * a post with `patrol = true` designates ONE of its guards as the
--     ambient patrol of world.md §4 (see assign_patrol below);
--   * a post refills one slot per 180-360 s.
--
-- The CAMP FIRE (grug_nodes:camp_fire) is scenery since the Round 28 spawn
-- recipes: a camp POI's population is its recipe camp (bottom of this file).
-- Round 81 (audit MOB2-05, ruling 6) removed its timer, its bandit and
-- mirefolk camp types and grug_mobs.place_camp; the node keeps only its
-- infotext (init_camp_fire), and a timer an older world armed fires once and
-- stops (the node has no on_timer).
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
-- STATE lives in node meta, so a camp survives restarts and world unloads
-- with zero mod storage:
--   `_grug_camp_type`     string, a key of grug_mobs.registered_camp_types
--   `_grug_camp_target`   int, the rolled 2-3 (0/absent = not rolled yet)
--   `_grug_refill_queue`  int, refills owed (0/absent = camp is full)
--   `_grug_next_refill`   int, gametime second the next refill is due
--   `_grug_camp_patrol_t` int, gametime of the last patrol designation
--   `_grug_camp_init`     int, infotext idempotency flag (camp fires)
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
-- The default refill window of a camp type's slot (register_camp_type); the
-- guard posts state their own slower pair below.
local RESPAWN_MIN, RESPAWN_MAX = 30, 60
-- A guard post refills SLOWLY (world.md §4a leaves the number to the
-- implementation): a wiped outpost that is back to full three
-- minutes later removes the point of clearing it, and a garrison is meant to
-- be re-takeable ground for a while. THE tunable of this file — raise it to
-- make outposts feel more expensive to hold, lower it to keep the roads safe.
local GUARD_RESPAWN_MIN, GUARD_RESPAWN_MAX = 180, 360
-- Do no work at all unless a player is this close. Comfortably inside
-- mobs:add_mob's own 128 m requirement, comfortably outside the camp radius.
local PLAYER_RANGE = 80
-- Head-count radius margin on top of the camp radius: a defending guard
-- may stand up to its leash range from the banner, and counting it as gone
-- would let the post overfill. radius + 16 covers the guard posts
-- (15 + 16 > leash 30).
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

-- id -> {mob = "grug_mobs:guard_accord", count_min = 2, count_max = 3,
--        radius = 15, node = "grug_nodes:guard_banner", patrol = true,
--        respawn_exact = nil, respawn_min = 180, respawn_max = 360}
--   node          — the anchor node of this type (the guard banner)
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
		node = def.node,
		patrol = def.patrol or false,
		respawn_exact = def.respawn_exact,
		respawn_min = def.respawn_min or RESPAWN_MIN,
		respawn_max = def.respawn_max or RESPAWN_MAX,
	}
end

-- A member of the camp's head count.
local function camp_member(cfg, name)
	return name == cfg.mob
end

-- The two anchor nodes, by name.
local BANNER_NODE = "grug_nodes:guard_banner"
local CAMP_FIRE_NODE = "grug_nodes:camp_fire"

-- Forward declaration: camp_cfg (a helper, far above the guard-post section)
-- needs the authority rule to type a banner whose meta went missing. The
-- definition lives with the rest of the guard-post code further down.
local banner_camp_type

--
-- Helpers
--

-- Config of the post anchored at pos. The type normally comes from meta; for
-- an EMPTY meta value (VoxelManip placement bypasses on_construct) the
-- authenticated outpost/territory authority decides, exactly as in
-- init_banner.
local function camp_cfg(pos, meta)
	local id = meta:get_string(META_TYPE)
	if id == "" then
		id = banner_camp_type(pos)
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
-- as dead and the post may briefly hold one guard too many. The leash range
-- keeps that window small, an extra guard is not a balance problem, and
-- the alternative (persisting a roster in meta) would have to garbage-collect
-- entities it cannot see either.
local function count_camp_mobs(pos, cfg)
	local n = 0
	local objs = core.get_objects_inside_radius(pos, cfg.radius + COUNT_MARGIN)
	for i = 1, #objs do
		local ent = objs[i]:get_luaentity()
		if ent and camp_member(cfg, ent.name) and (ent.health or 0) > 0
				and same_pos(ent._grug_camp_pos, pos) then
			n = n + 1
		end
	end
	return n
end

-- The levels a spot is searched at, relative to the anchor, in order. A camp
-- fire takes the first fit from pos.y + 3 down to pos.y - 3. A guard post
-- (Round 78 ruling 4) only at street level: the banner's own cell (it stands
-- on the street) first, then one below and one above for a slope, so a lamp
-- post's top (posts at +0 and +1, a floor torch at +2, its top at +3) and
-- any other raised spot are out of reach.
local CAMP_LEVELS = {3, 2, 1, 0, -1, -2, -3}
local STREET_LEVELS = {0, -1, 1}

-- A standable spot in the ring around the fire: air with air above it and
-- solid, non-liquid ground below. Searched locally (see the levels above)
-- because a camp refill must not substitute a different authored terrain
-- level. `street`: a guard post's levels, and the ground must be walkable
-- (no torch, plant or rope under the feet).
local function free_spot_near(pos, radius, street)
	local levels = street and STREET_LEVELS or CAMP_LEVELS
	for _ = 1, SPOT_TRIES do
		local angle = math.random() * 2 * math.pi
		local dist = 2 + math.random() * math.max(0, radius - 2)
		local x = math.floor(pos.x + math.cos(angle) * dist + 0.5)
		local z = math.floor(pos.z + math.sin(angle) * dist + 0.5)
		for index = 1, #levels do
			local p = {x = x, y = pos.y + levels[index], z = z}
			local here = core.get_node_or_nil(p)
			local above = core.get_node_or_nil({x = x, y = p.y + 1, z = z})
			local below = core.get_node_or_nil({x = x, y = p.y - 1, z = z})
			if here and above and below
					and here.name == "air" and above.name == "air"
					and below.name ~= "air" and below.name ~= "ignore"
					and core.get_item_group(below.name, "liquid") == 0 then
				local floor = street and core.registered_nodes[below.name]
				if not street or (floor and floor.walkable ~= false) then
					return p
				end
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
	local spot = free_spot_near(pos, cfg.radius, cfg.node == BANNER_NODE)
	if not spot then
		return false
	end
	-- `ignore_count = true` is REQUIRED: mobs:add_mob otherwise compares
	-- against the family's mobs:spawn aoc, and a camp family has no
	-- mobs:spawn row at all, so that cap defaults to 1 (api.lua mobs:add_mob) — every
	-- camp would top out at a single mob. The camp's own target is the cap.
	-- add_mob returns nil whenever it declines (no player in range, active
	-- mob limit, entity missing); that must never be an error here.
	-- grug_mobs.add_mob, not mobs:add_mob: the wrapper applies the
	-- collisionbox y-lift the ABM spawner does and add_mob does not (init.lua)
	-- — a camp family with a negative box floor would otherwise stand sunk
	-- into the ground.
	local name = cfg.mob
	-- Round 25 ruling 24: a hostile camp type's slot whose spot lies in an
	-- active housing claim is not served, like blocked ground (the due time
	-- stays, a later tick rolls a new spot). Guards are `type = "npc"` and
	-- never refused.
	if grug_mobs.claim_refuses_spawn(name, spot) then
		return false
	end
	local ent = grug_mobs.add_mob(spot, {name = name, ignore_count = true})
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
		core.log("warning", "[grug_mobs] guard post at " ..
			core.pos_to_string(pos) .. " has unknown camp type '" .. id .. "'")
		return IDLE_PERIOD
	end
	local now = core.get_gametime()
	-- Camp size is rolled ONCE and kept, so a post has a stable identity
	-- ("this is a three-guard post") instead of re-rolling every respawn.
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

-- The camp fire is scenery (header): on_construct and the LBM at the bottom
-- give it its infotext once, nothing else. It has no on_timer, so a timer an
-- older world armed fires once and stops. grug_nodes owns both pure
-- activation nodes so R7 can authenticate them before grug_mobs loads; this
-- higher layer supplies their runtime behaviour.
local function init_camp_fire(pos)
	local meta = core.get_meta(pos)
	if meta:get_int(META_FIRE_INIT) == 1 then
		return
	end
	meta:set_int(META_FIRE_INIT, 1)
	meta:set_string("infotext", "Camp Fire")
end

core.override_item(CAMP_FIRE_NODE, {
	on_construct = init_camp_fire,
})

--
-- The guard post: the same mechanism on grug_nodes:guard_banner
-- (docs/design/world.md §4)
--

-- The banner NODE lives in grug_nodes, which must not depend on grug_mobs —
-- so its behaviour is attached from here, the legal cross-mod way
-- (core.override_item; grug_mobs declares grug_nodes in mod.conf, so the node
-- is registered by the time this file runs).

-- Which watch stands here: an authenticated outpost decides first, otherwise
-- the TERRITORY decides; never the placer (world.md §0/§4 — a post cannot fly
-- the wrong faction's colours). Frontier outposts deliberately live in
-- contested zones, so their race-bound payload is the only faction authority
-- there and grug_zones.faction_at correctly returns nil.
-- Assigns the forward-declared local at the top of the file (camp_cfg uses it
-- as the meta-less fallback); NOT a global.
function banner_camp_type(pos)
	local outpost = grug_core.outpost_at(pos)
	local territory = outpost and outpost.faction or
		grug_zones.faction_at(pos)
	if territory ~= "accord" and territory ~= "throng" then
		-- Only reachable for a non-outpost banner placed outside faction-owned
		-- territory. Not an error worth refusing over, but worth saying out loud.
		core.log("warning", "[grug_mobs] guard banner at " ..
			core.pos_to_string(pos) .. " stands outside both continents" ..
			" (territory '" .. tostring(territory) ..
			"'); defaulting to the Accord watch")
		territory = "accord"
	end
	return "guard_" .. territory
end

-- Shared by on_construct (a hand-placed banner) and the LBM below (mapgen
-- placement). Idempotent: the meta flag makes a second call a no-op, and an
-- already typed banner keeps its type.
--
-- The TIMER is armed BEFORE that early return, on purpose. The LBM runs at
-- every load, so this function is the one place that sees every banner on
-- every activation — and a banner whose timer went missing (an old world
-- generated before the init LBM existed, a mapblock written by a tool, an
-- engine-side loss) would otherwise stand there as a decorative flag with no
-- garrison while its meta flag says "initialised". `is_started` keeps the
-- repeat cost at one meta read plus one timer query per node per activation
-- and never re-arms a running timer, so a post mid-respawn is not reset by a
-- reload.
--
-- THE ORDER MATTERS AND IT IS IN OUR FAVOUR (checked against the engine):
-- activateBlock runs the LBMs FIRST and steps the block's node timers AFTER
-- (serverenvironment.cpp:576/581). So on the activation of a dormant post
-- this function sees the stored timer still armed and un-fired —
-- `is_started()` is true, we leave it alone, and the catch-up tick that the
-- following block->step(dtime_s) delivers survives. Re-arming here would
-- have thrown away exactly the tick that drains a dormant post's owed
-- refills (world.md §4a).
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
	-- Returning true would make the engine re-arm the elapsed timer with its
	-- old timeout. Refill proximity changes the next period, so install that
	-- freshly computed timeout ourselves and leave the expired timer stopped.
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
-- post mechanism was dead in every world (engine side:
-- LBMManager puts a non-every-load LBM into the bucket of its introduction
-- time, and getLBMsIntroducedAfter only ever selects buckets at or after the
-- block's own, i.e. later, timestamp).
-- `true` runs the action on EVERY activation of a block holding this node,
-- which is what the init functions are written for (cheap, idempotent,
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

-- The same path for the CAMP FIRE, which R7's named-zone writer also places
-- through the VoxelManip: its infotext, once (init_camp_fire), with
-- run_at_every_load = true for the reason spelled out at the banner LBM above
-- (a `false` LBM never runs on a mapgen-placed node).
core.register_lbm({
	name = "grug_mobs:camp_fire_init",
	nodenames = {CAMP_FIRE_NODE},
	run_at_every_load = true,
	action = function(pos)
		init_camp_fire(pos)
	end,
})

--
-- The two guard posts (world.md §4/§9)
--
-- 2-3 guards (§9's
-- "guaranteed minimum" outpost is a picket, not a garrison — the numbers can
-- grow with WP13's real structures) spread over the 7x7 pad and its
-- surroundings (radius 15, the pad plus a little patrol ground). Both types
-- patrol; which of the two a banner uses follows from the authenticated
-- outpost first and faction territory otherwise (banner_camp_type above), so
-- the race's frontier posts keep their faction on contested land and the mob
-- level still varies with the ring via guard_level_at.
-- Their refill slot runs slowly (GUARD_RESPAWN_MIN/MAX,
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

-- Round 78 ruling 4, for the guards already standing in a world: a post guard
-- that a spawn before 0.78.0 put on a lamp post or another raised spot (more
-- than one node above its banner's street level, inside the post's radius)
-- is moved to a street spot of its post. guard.lua calls this once per
-- activation; a patroller, a guard in a fight and a guard off its post are
-- left alone, and so is one for whom no street spot is free right now.
function grug_mobs.guard_to_street(self)
	local camp = self._grug_camp_pos
	if not camp or self._grug_patrol_route or self.state == "attack" then return false end
	local pos = self.object and self.object:get_pos()
	if not pos or pos.y <= camp.y + 1 then return false end
	local radius
	for _, cfg in pairs(grug_mobs.registered_camp_types) do
		if cfg.node == BANNER_NODE and camp_member(cfg, self.name) then radius = cfg.radius end
	end
	local dx, dz = pos.x - camp.x, pos.z - camp.z
	if not radius or dx * dx + dz * dz > (radius + 1) * (radius + 1) then return false end
	local spot = free_spot_near(camp, radius, true)
	if not spot then return false end
	-- The spot is the air cell; the body stands on its floor.
	self.object:set_pos({x = spot.x, y = spot.y - 0.5, z = spot.z})
	return true
end

--
-- Recipe camps (Round 28 ruling 37, Lane S1): bandits, poachers and
-- mirefolk of a zone's spawn recipe, at the camp spot its region map picked
-- by rule or on the camp POI the recipe names (spawn_regions_core.lua step
-- 7). A recipe camp on a POI is that POI's only population: the POI's fire
-- is scenery in a recipe zone (header).
--
-- The slot model above without a node: `slots` members, each death booked
-- into a refill queue whose due time advances by a roll in the camp's
-- `respawn` [min, max] (30-60 s by the ruling). What differs from a post:
--   * members roam FREE under the normal wander leash (`_grug_home` = their
--     own spawn point, radius 32): no `_grug_camp_pos`, no camp leash, no
--     roam cap. They carry the camp's tag, and the head count is by that tag;
--   * a spot lies within CAMP_RADIUS (40) of the camp centre (24 for a
--     camp on a POI), outside the drift band for aggressive roles, and keeps
--     `min_player_distance` (16) from every player instead of the ambient 24,
--     so two players standing in the camp do not block it;
--   * levels and species come from the camp (belt range x role range,
--     roster weights);
--   * the state lives in memory, keyed by the camp tag. The first look at a
--     camp after a start fills what is missing at once, which is what a camp
--     standing in the world should look like when a player walks up; after
--     that the queue and its due time behave like a post's, the dormant
--     catch-up included (due times lag `now` while nobody is near, and the
--     drain serves what the elapsed time earned). A look after an absence
--     that books new deaths (members culled while their blocks were unloaded)
--     starts their drain at the last look + one interval, not at now +
--     interval, so the absence earns refills as it does for a post.
-- A camp is looked at only while its centre's mapblock is active and a
-- player stands within SR.LEADER_RANGE of the centre horizontally (48 nodes
-- at the default active_block_range; Round 81 SPAWN, audit MOB2-03): from
-- further out the far members' blocks may be inactive, the count reads them
-- as dead, and the refills overfilled the camp once the player walked in.
-- Ticked every five seconds by spawn_regions.lua's globalstep (a slice of
-- the zones per quarter second), for the camps of the region maps built so
-- far. The same known blind spot as count_camp_mobs remains, smaller: a
-- member roaming into an inactive block reads as dead.
--

-- A look this long after the last one follows an absence (two slow passes).
local REGION_CAMP_ABSENCE = 10
local region_camps = {} -- tag -> {queue, next_refill, fill, seen}

local function region_camp_interval(camp)
	return math.random(camp.respawn[1], camp.respawn[2])
end

-- Where a camp's members may stand: within this of its centre; counted
-- within this plus the wander leash and a margin.
local function camp_radius()
	return grug_mobs.spawn_regions.core.CAMP_RADIUS
end

local function count_region_members(camp, center)
	local n = 0
	local objs = core.get_objects_inside_radius(center, camp_radius() + 48)
	for i = 1, #objs do
		local ent = objs[i]:get_luaentity()
		if ent and ent._grug_area == camp.tag and (ent.health or 0) > 0 then
			n = n + 1
		end
	end
	return n
end

-- One member onto a free spot of the camp. True when a mob arrived. A camp
-- on a POI keeps its members near the POI's tents (POI_MEMBER_RADIUS, 24:
-- a POI may stand close to a road or an outpost); a generated camp uses the
-- whole camp radius. Like an ambient spawn, an aggressive member never
-- stands in the drift band of a road, bridge or settlement.
local function spawn_region_member(unit, zone_id, players, center_y, clock)
	local SR = grug_mobs.spawn_regions
	local camp = unit.camp
	local r = unit.site and SR.core.POI_MEMBER_RADIUS or camp_radius()
	for _ = 1, SPOT_TRIES do
		local angle = math.random() * 2 * math.pi
		local dist = math.sqrt(math.random()) * r
		local x = math.floor(unit.x + math.cos(angle) * dist + 0.5)
		local z = math.floor(unit.z + math.sin(angle) * dist + 0.5)
		if grug_zones.id_at(x, z) == zone_id then
			local g = SR.ground_at(x, z, center_y, 32)
			if g and g.y >= 0 then
				local stand = {x = g.x, y = g.y + 1, z = g.z}
				local role = SR.pick_role(camp.roster)
				local name = "grug_mobs:" .. role
				-- The unit carries the camp's tag and the levels of its
				-- stated belt.
				if SR.players_clear(stand, camp.min_player_distance, players) and
						not SR.spawn_refused(name, stand) and
						not (grug_mobs.disposition(name) == "aggressive" and SR.in_drift(stand)) and
						SR.spawn_mob(unit, role, g, clock) then
					return true
				end
			end
		end
	end
	return false
end

-- The camp's centre while it is in view (header: a player within
-- SR.LEADER_RANGE and the centre's mapblock active), else nil.
local function camp_in_view(SR, unit, players)
	if not SR.player_near_xz(unit.x, unit.z, SR.LEADER_RANGE, players) then
		return nil
	end
	unit.center_y = unit.center_y or grug_zones.terrain_height_at(unit.x, unit.z)
	local center = {x = unit.x, y = unit.center_y, z = unit.z}
	return core.compare_block_status(center, "active") == true and center or nil
end

function grug_mobs.region_camp_tick(now, players, clock, zone_ids)
	local SR = grug_mobs.spawn_regions
	local list = SR.camp_units(zone_ids)
	for i = 1, #list do
		local unit = list[i]
		local camp = unit.camp
		local center = camp_in_view(SR, unit, players)
		if center then
			local center_y = center.y
			local living = count_region_members(camp, center)
			local missing = camp.slots - living
			local st = region_camps[camp.tag]
			if not st then
				-- First look since the start: the whole deficit is due now.
				st = {queue = math.max(missing, 0), next_refill = now, fill = true}
				region_camps[camp.tag] = st
			elseif missing > st.queue then
				if st.queue <= 0 then
					local from = now
					if st.seen and now - st.seen > REGION_CAMP_ABSENCE then
						from = st.seen
					end
					st.next_refill = from + region_camp_interval(camp)
				end
				st.queue = missing
			elseif missing < st.queue then
				st.queue = missing > 0 and missing or 0
			end
			st.seen = now
			local zone_id = camp.tag:match("^([^/]+)/")
			while st.queue > 0 and now >= st.next_refill do
				if not spawn_region_member(unit, zone_id, players, center_y, clock) then
					break
				end
				st.queue = st.queue - 1
				if not st.fill then
					st.next_refill = st.next_refill + region_camp_interval(camp)
				end
			end
			if st.queue <= 0 then
				st.fill = nil
			end
		end
	end
end
