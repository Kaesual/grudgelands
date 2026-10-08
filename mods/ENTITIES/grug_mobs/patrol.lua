--
-- Shared route walking (named-rare amble, rares.lua; outpost patrols,
-- guard.lua / camps.lua — docs/design/world.md §4 "between outposts: ambient
-- patrols") and the fixed walks on the shared navigation (Round 42 NV2,
-- `walk_fixed` below: patrols, posts and seats, the evade run home, the rift
-- boss's way home).
--
-- ONE implementation for both, because they are literally the same movement:
-- walk to the current waypoint, take the next one when you arrive, wrap
-- around. Only the storage of the route and of the waypoint index differs, so
-- the caller passes both in.
--
-- We do NOT use mobs_redo's mob_class:go_to(pos) (api.lua:1833-1840). It works by
-- spawning a temporary "mobs:_pos" entity and calling do_attack(obj, true) on
-- it — i.e. it puts the mob into state "attack" with a dummy target. Three
-- things break for us: general_attack() bails out entirely while
-- state == "attack" (api.lua:1853-1858), so a patrolling mob would be BLIND to
-- players; our threat/leash logic would see an attack state with a non-player
-- target; and the telegraph would count the dummy as melee combat. A yaw +
-- walk-velocity nudge once a second is all an amble needs.
--

local nav = mobs.grug_nav
local WAYPOINT_REACHED = 4 -- m
local TICK = 1 -- s between nudges (performance rule: throttled)

--
-- ONE nudge toward a horizontal point: turn, and keep walking. This is the
-- whole movement primitive — shared with the camp roam cap in aggro.lua
-- (world.md §4a, "while idle they roam only a small radius around their
-- anchor"), which is the same "walk that way" with a different target.
--
-- mobs_redo's own walk state re-randomizes the yaw with a 30 % chance per
-- do_states call (mobs/api.lua, the walk state), so a single nudge is a
-- suggestion, not a command — but do_states runs only once a second on its
-- own timer and this repeats once a second, so the mob makes net progress
-- instead of a straight line. That is exactly what an amble should look like.
--
-- THE NUDGE MARKS THE MOB AS DRIVEN (Round 42 ST, ruling 25; mobs/grug_nav.lua
-- `nav.steer`): for 1.5 s after it the walk state's random stop
-- (`stand_chance`) does not apply, so a mob one of our movers walks no longer
-- stands for up to a second every few seconds. Its stops in front of a fence,
-- wall or closed gate that blocks and at a cliff stay.
--
-- `pos` is passed in because both callers already fetched it; y is only used
-- to keep the yaw horizontal.
--
-- The turn is INSTANT (Round 28 ruling 11). mob_class:set_velocity builds the
-- velocity from the object's CURRENT yaw, and a smoothed turn (the former
-- `yaw_to_pos(..., 0, 4)`) leaves that yaw where it was for four more steps,
-- while the walk state refreshes the velocity only about once a second -- so a
-- gate guard turned round and kept walking the old way for up to a second.
-- Clearing `delay` also drops a smoothed random turn still in flight, which
-- would otherwise turn the mob away again right after this.
--
-- The walk clip is set here too (Round 41 ruling 1), see walk_animation below.
--
-- `speed` (optional, default walk_velocity) is for a caller that steers every
-- step and so keeps its speed against do_states' own once-a-second
-- `set_velocity(walk_velocity)`: the royal follow of a fighting leader
-- (bosses.lua). A speed above the walk speed plays the run clip.
--
function grug_mobs.walk_toward(self, x, z, pos, speed)
	nav.steer(self)
	self:yaw_to_pos(vector.new(x, pos.y, z), 0, 0)
	self.delay = 0
	self.state = "walk"
	self:set_velocity(speed or self.walk_velocity)
	grug_mobs.walk_animation(self,
		speed ~= nil and speed > (self.walk_velocity or 0))
end

--
-- THE LEGS MOVE WITH THE NUDGE (Round 41 ruling 1). walk_toward used to leave
-- the clip to mobs_redo's walk state, but outside a fight do_states runs only
-- once a second on mobs_redo's own timer (api.lua on_step, "one second timed
-- calls"), out of step with the callers' nudges: a mob started from standing
-- glided up to a second in its stand pose, and a caller that returns false
-- from do_custom (the royal follow, bosses.lua) never reached do_states at all.
--
-- The clip is the one do_states' walk state would pick: a mob with a fly clip
-- that is inside its element (flight_check) flies unless it stands on walkable
-- ground out of water; every other mob walks. A definition without the clip
-- keeps what it plays (set_animation ignores a clip it does not have).
--
-- A hot path (every nudge; the royal follow every step): nothing is written
-- when the clip already plays. The swing lock (mobs/api.lua set_animation,
-- Round 37 MB) may hold one write back while a punch clip ends; the next call
-- writes it. `run`: the run clip, where the definition has one.
--
function grug_mobs.walk_animation(self, run)
	local anims = self.animation
	if not anims then
		return
	end
	local clip = run and anims.run_start and "run" or "walk"
	if anims.fly_start and anims.fly_end and self:flight_check() then
		local on = core.registered_nodes[self.standing_on]
		local within = core.registered_nodes[self.standing_in]
		if not (on and on.walkable) or
				(within and within.groups and within.groups.water) then
			clip = "fly"
		end
	end
	if self.animation_current ~= clip then
		self:set_animation(clip)
	end
end

--
-- MAKE A MOB FACE ONE DIRECTION AND KEEP IT.
--
-- `set_yaw(yaw, 0)` alone is not enough, and the reason is api.lua:3638-3781:
-- `mob_activate` gives every mob a RANDOM yaw with a SIX-STEP smooth rotation,
-- and the step function keeps feeding that pending target
-- (api.lua:3638-3781) until the six steps are spent. An instant yaw written
-- while such a rotation is pending is turned away again over the next half
-- second. Overwriting `target_yaw` first makes the pending rotation a no-op
-- (`shortest_rotation(yaw, yaw) == 0`), so the facing sticks.
--
-- This is what an authored standing position needs: a guard at its post and a
-- villager at its spot face the direction the blueprint gave them, on every
-- activation, not a random one (WP13 sockets).
--
function grug_mobs.face_yaw(self, yaw)
	if type(yaw) ~= "number" or not self.object then
		return
	end
	self.target_yaw = yaw
	self:set_yaw(yaw, 0)
end

--
-- FIXED WALKS (Round 42 NV2; round42-plan.md rulings 5, 10, 11, 17 and 18;
-- world.md §4a). A walk to a goal that stays where it is -- a patrol
-- waypoint, a post, a king's seat, home after an evade, the rift boss's spot
-- -- runs on the shared navigation (mobs/grug_nav.lua `fixed_step`), the one
-- stuck detector of every mover:
--
--   1. the mob walks straight at its goal, a nudge once a second as before;
--   2. a mob that wants to move but does not (less than 30 % of its speed
--      over 1 s) asks the engine's pathfinder for a short, bounded local
--      search, at most once every 5 s, and follows the path to its end; more
--      than 2 nodes off it, it searches again. While it follows a path or
--      waits for a search it is steered every step (`walk_follow`): a
--      once-a-second nudge overshoots a corner by a second's walk;
--   3. the owner's later stages are fed by the failed searches in a row
--      (`walk_fixed` returns them): a patrol takes its next waypoint, a
--      patrol or a post snaps out of sight (`snap_try`).
--
-- HELD WALKERS. mobs_redo stops a walker that faces a blocking (walkable)
-- node named fence, gate or wall (`facing_fence`, do_states; Round 42 ST: a
-- wall torch or a wall sign no longer does) and the ambient cliff guard
-- stops it at a drop of 1.5 (`is_at_cliff`); a town wall or gate is where
-- guards stand. The walk still wants to move there, so the detector hears the
-- speed the nudge commanded, not the speed mobs_redo left it: such a walker
-- is stuck like one pressed into a trunk, and a path down a drop the cliff
-- guard refuses is followed (the engine plans drops up to the mob's fear
-- height). mobs_redo's random stop (`stand_chance`) no longer reaches a
-- walker the nudges drive (walk_toward above, ruling 25); a stand that is no
-- hold all the same (the owner's own stop before a walk, a fight's end)
-- is not measured.
--
-- One walk per mob in `self.temp.grug_walk` (runtime only): its owner (the
-- tick that drives it), its key (one goal; a new key is a new walk for the
-- navigation) and the goal's feet position. Fliers never search (their walk
-- stays the plain nudge), like in a fight.
--
-- THROUGH A DOOR (Round 42 DR, ruling 15). A door is a wall to the engine,
-- so a settlement NPC's fixed walk whose search failed looks for a door
-- (npc_doors.between: one near the walker or its goal whose wall stands
-- between the two) and walks there as a DOOR DETOUR in place of its walk:
-- to the cell in front of the door (a fixed walk, VIA_FAILS failed searches
-- drop it), then over the door's centre to the cell behind it, steered
-- every step and opening the door on the way (CROSS_TIME bounds it), then
-- on to its goal. Each door is tried once per walk, at most VIA_DOORS of
-- them. Only the walkers and the post guards (DOOR_WALKS) do this: never a
-- fight, a camp, a wild mob, nor a walker on a cached route (routes.lua
-- builds its doors into the route).
--
local doors = grug_mobs.npc_doors
local DOOR_WALKS = {amble = true, post = true}
local VIA_FAILS = 2 -- failed searches toward the cell in front of the door
local VIA_DOORS = 2 -- doors tried per walk
local CROSS_REACH = 0.4 -- nodes: the door's centre and the cell behind passed
-- (the cell in front is reached closer, npc_doors.FRONT_REACH: lined up)
local CROSS_TIME = 8 -- s: a crossing that takes longer is dropped

-- The navigation call, the steer and what it commanded. Returns
-- fixed_step's outcome.
local function drive(self, w, pos)
	local steer, outcome = nav.fixed_step(self, pos, w.dt, w, w.key, w.opts)
	w.dt = 0
	local p = steer or w
	grug_mobs.walk_toward(self, p.x, p.z, pos)
	-- The speed the nudge set (set_velocity applied a liquid's slowdown and
	-- a stand order), whatever holds the walker afterwards.
	local v = self.object:get_velocity()
	nav.command(self, pos, v and math.sqrt(v.x * v.x + v.z * v.z) or 0)
	return outcome
end

-- The standing y for (x, z) near `around_y`: the cell nearest to it (from 4
-- above to 8 below, the lower first at the same distance) whose own node and
-- head room are not walkable and which has walkable ground under it -- the
-- floor under a lintel or an arch, not the lintel's top (Round 42). nil when
-- the column offers none, which is a refusal to teleport rather than a guess.
local function stands_at(x, y, z)
	local here = core.get_node_or_nil({x = x, y = y, z = z})
	local above = core.get_node_or_nil({x = x, y = y + 1, z = z})
	local below = core.get_node_or_nil({x = x, y = y - 1, z = z})
	local here_def = here and core.registered_nodes[here.name]
	local above_def = above and core.registered_nodes[above.name]
	local below_def = below and core.registered_nodes[below.name]
	return here_def and above_def and below_def and
		here_def.walkable ~= true and above_def.walkable ~= true and
		below_def.walkable == true
end

local function standing_y(x, z, around_y)
	local base = math.floor(around_y + 0.5)
	for d = 0, 8 do
		if stands_at(x, base - d, z) then return base - d end
		if d > 0 and d <= 4 and stands_at(x, base + d, z) then return base + d end
	end
	return nil
end

-- The door detour is over (through, or given up): the walk it replaced
-- starts again on the next decision; the doors it tried stay tried.
local function drop_via(t, w)
	t.grug_walk, t.grug_door_next = nil, nil
	local nst = t.grug_nav
	if nst and nst.target == w.key then nav.forget(t) end
end

-- A crossing step of door detour `w`: steer at the door's centre, then at
-- the cell behind it, opening the door on the way. True when it is over
-- (through, or given up after CROSS_TIME).
local function cross(self, pos, w, dtime)
	w.ct = w.ct + dtime
	local t = self.temp
	doors.approach(self, pos, w.door)
	local c = doors.aim(w.door, w.centred and w.behind or w.door)
	local dx, dz = c.x - pos.x, c.z - pos.z
	if dx * dx + dz * dz < CROSS_REACH * CROSS_REACH then
		if w.centred then
			drop_via(t, w)
			return true
		end
		w.centred, c = true, doors.aim(w.door, w.behind)
	end
	if w.ct > CROSS_TIME then
		drop_via(t, w)
		return true
	end
	grug_mobs.walk_toward(self, c.x, c.z, pos)
	return false
end

-- One decision of a door detour (walk_fixed with the walk's own key).
local function via_step(self, dtime, pos, w)
	local t = self.temp
	w.dt = w.dt + dtime
	doors.heading(self, w.door)
	if w.phase == "to" then
		local dx, dz = w.x - pos.x, w.z - pos.z
		if dx * dx + dz * dz >= doors.FRONT_REACH * doors.FRONT_REACH then
			drive(self, w, pos)
			local nst = t.grug_nav
			local fails = nst and nst.target == w.key and nst.fails or 0
			if fails >= VIA_FAILS then
				-- Not even to the door: back to the walk, which counts on.
				drop_via(t, w)
			end
			return fails
		end
		w.phase, w.ct = "cross", 0
		local nst = t.grug_nav
		if nst and nst.target == w.key then nav.forget(t) end
	end
	cross(self, pos, w, dtime)
	return 0
end

-- A door detour for walk `w` (key `key`, owner `owner`) whose search
-- failed, or nil.
local function door_via(self, pos, w, key, owner)
	local t = self.temp
	local tried = t.grug_door_tried
	if not tried or tried.walk ~= key then
		tried = {walk = key, n = 0}
		t.grug_door_tried = tried
	end
	if tried.n >= VIA_DOORS then return nil end
	local feet = {x = pos.x, y = pos.y + mobs.grug_obstacle.mob_cbox(self)[2],
		z = pos.z}
	local d = doors.between(feet, w, tried)
	if not d then return nil end
	tried[d.key], tried.n = true, tried.n + 1
	local front, behind = doors.sides(d, feet)
	doors.heading(self, d)
	return {owner = owner, key = key .. "#door", main = key, dt = 0,
		phase = "to", x = front.x, y = front.y, z = front.z, behind = behind,
		door = {x = d.x, y = d.y, z = d.z, key = d.key}}
end

--
-- One decision of a fixed walk, from its owner's once-a-second tick: walk
-- toward (x, y, z), `y` the goal's feet height or nil when the goal is given
-- in plan only (a route point, a post), as walk `key` of `owner`. `opts`:
-- fixed_step's search options (the evade's local point); `opts.route`: a
-- corner of a cached route (no door detour). Returns the failed searches in
-- a row of this walk (of its door detour while it has one).
--
function grug_mobs.walk_fixed(self, dtime, pos, x, y, z, key, owner, opts)
	self.temp = self.temp or {}
	local t = self.temp
	local w = t.grug_walk
	if w and w.main == key and w.owner == owner and not self.fly then
		return via_step(self, dtime, pos, w)
	end
	if not w or w.owner ~= owner or w.key ~= key then
		w = {owner = owner, key = key, dt = 0}
		t.grug_walk = w
	end
	w.dt = w.dt + dtime
	if self.fly then
		grug_mobs.walk_toward(self, x, z, pos)
		return 0
	end
	if y == nil then
		-- The ground of a goal given in plan only, looked up until found.
		if w.x ~= x or w.z ~= z then w.ground = nil end
		if not w.ground then
			local feet = pos.y + mobs.grug_obstacle.mob_cbox(self)[2]
			w.ground = standing_y(math.floor(x + 0.5), math.floor(z + 0.5), feet)
			y = w.ground or feet
		else
			y = w.ground
		end
	end
	w.x, w.y, w.z, w.opts = x, y, z, opts
	local nst = t.grug_nav
	local stepped = nst and nst.target == key and (nst.path or nst.want)
	if not stepped and self.state == "stand"
			and not self.facing_fence and not self.at_cliff then
		-- Stood since the last nudge, and not by a hold: no measure.
		nav.command(self, pos, 0)
	end
	drive(self, w, pos)
	nst = t.grug_nav
	local fails = nst and nst.target == key and nst.fails or 0
	if fails > (w.door_fails or 0) and DOOR_WALKS[owner]
			and not (opts and opts.route) then
		-- A new failure: is there a door between the walker and its goal?
		w.door_fails = fails
		local via = door_via(self, pos, w, key, owner)
		if via then t.grug_walk = via end
	end
	return fails
end

--
-- Every other step of the walk's owner: the time since the last decision,
-- and the steer every step while the walk follows a path or waits for a
-- search. Idle only, like the decisions (a fight owns the movement).
--
function grug_mobs.walk_follow(self, dtime, owner)
	local t = self.temp
	if t and t.grug_door_open then
		-- A door it opened: closed behind it once it is through.
		local pos = self.object:get_pos()
		if pos then doors.settle(self, pos) end
	end
	local w = t and t.grug_walk
	if not w or w.owner ~= owner then return end
	w.dt = w.dt + dtime
	if w.phase and not self.attack
			and (self.state == "stand" or self.state == "walk") then
		-- A door detour: in front of the door it crosses (checked every
		-- step, a once-a-second decision walks into the door; steered
		-- every step for its last two nodes, lined up with the doorway).
		local pos = self.object:get_pos()
		if pos and w.phase == "to" then
			local dx, dz = w.x - pos.x, w.z - pos.z
			local d2 = dx * dx + dz * dz
			if d2 < doors.FRONT_REACH * doors.FRONT_REACH then
				w.phase, w.ct = "cross", 0
				local nst = t.grug_nav
				if nst and nst.target == w.key then nav.forget(t) end
			elseif d2 < 4 then
				local nst = t.grug_nav
				if not (nst and nst.target == w.key and nst.path) then
					local a = doors.aim(w.door, w)
					grug_mobs.walk_toward(self, a.x, a.z, pos)
				end
			end
		end
		if pos and w.phase == "cross" then
			cross(self, pos, w, dtime)
			return
		end
	end
	local nst = t.grug_nav
	if not nst or nst.target ~= w.key or not (nst.path or nst.want)
			or self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		return
	end
	local pos = self.object:get_pos()
	if pos then drive(self, w, pos) end
end

-- The walk is over (arrived, snapped, a fight or another owner took over).
-- `owner` (optional): only that owner's walk. The navigation state is
-- forgotten only when it is the walk's own (a fight's stays).
function grug_mobs.walk_clear(self, owner)
	local t = self.temp
	local w = t and t.grug_walk
	if not w or (owner and w.owner ~= owner) then return end
	t.grug_walk, t.grug_door_next = nil, nil
	local tried = t.grug_door_tried
	if tried and (tried.walk == w.key or tried.walk == w.main) then
		t.grug_door_tried = nil
	end
	local nst = t.grug_nav
	if nst and nst.target == w.key then nav.forget(t) end
end

--
-- THE LATER STAGES (playtest round 1, 2026-09-15; fed by the navigation since
-- Round 42). A patrol that still cannot reach its waypoint after SKIP_AFTER
-- failed searches in a row takes the next one: a loop is a patrol, not a
-- delivery. The second waypoint in a row it gives up is snapped to instead --
-- ONLY while no player is within SNAP_PLAYER_RANGE (the user's 2026-09-15
-- ruling: an out-of-sight teleport is fine, one in plain view is not; Round
-- 42 ruling 11) -- and skipped too when somebody watches. A post has no next
-- waypoint: it snaps after POST_SNAP_AFTER failures (start_npcs.lua).
--
local SKIP_AFTER = 3 -- failed searches in a row toward one waypoint
local SNAP_PLAYER_RANGE = 48 -- nodes; the user's "out of sight" radius
-- A LOOP NOBODY CAN WALK IS A TERMINAL STATE, not something to report for ever.
-- After QUIET_AFTER give-ups the mob keeps trying in silence, and a refused
-- teleport is retried every SNAP_RETRY seconds instead of on every tick: with
-- every waypoint unreachable AND a player inside SNAP_PLAYER_RANGE, the
-- unthrottled version logged one line and called `get_objects_inside_radius`
-- once a second for as long as the player stood there.
local SNAP_RETRY = 10 -- s between out-of-sight attempts once one was refused
local QUIET_AFTER = 4 -- give-up cycles before the log goes quiet

--
-- The snap with a back-off. The first attempt runs the moment the mob is due;
-- a refusal -- a player inside SNAP_PLAYER_RANGE, or a column with nowhere to
-- stand -- is retried only SNAP_RETRY seconds later: a deadline on the server
-- clock (`grug_snap_wait`, runtime only), so a caller that asks rarely (a
-- patrol, after three fresh failures) waits as long as one that asks every
-- tick.
--
function grug_mobs.snap_try(self, pos, x, z, after)
	self.temp = self.temp or {}
	local t = self.temp
	local now = core.get_us_time() / 1000000
	if now < (t.grug_snap_wait or 0) then
		return false
	end
	if grug_mobs.snap_to(self, pos, x, z, after) then
		t.grug_snap_wait = nil
		return true
	end
	t.grug_snap_wait = now + SNAP_RETRY
	return false
end

-- One give-up, counted. Reports the first QUIET_AFTER - 1 of them, then says
-- once that it is going quiet, then says nothing until something clears the
-- count (arrival, a fight, an unload).
local function report_give_up(self)
	local t = self.temp
	t.grug_stall_cycles = (t.grug_stall_cycles or 0) + 1
	if t.grug_stall_cycles < QUIET_AFTER then
		core.log("action", "[grug_mobs] " .. self.name ..
			" could not reach its waypoint (" .. SKIP_AFTER ..
			" failed searches in a row, or no route) and walks on to the next one")
	elseif t.grug_stall_cycles == QUIET_AFTER then
		core.log("action", "[grug_mobs] " .. self.name ..
			" cannot reach any waypoint of its loop; it keeps trying without" ..
			" reporting until it makes progress")
	end
end

-- Is nobody watching? Every connected player is an active object, so
-- `get_objects_inside_radius` answers exactly the question the user's ruling
-- asks. Only ever called for a mob that is already stuck.
function grug_mobs.unwatched(pos, range)
	local objects = core.get_objects_inside_radius(pos,
		range or SNAP_PLAYER_RANGE)
	for index = 1, #objects do
		if objects[index]:is_player() then
			return false
		end
	end
	return true
end

--
-- The snap: put the mob down on (x, z) through the same `place_on_ground`
-- correction every hand placement in this mod uses -- a standing y is a FEET
-- position and an entity position is its collisionbox origin. Refuses while a
-- player is within SNAP_PLAYER_RANGE, and refuses when the column has nowhere
-- to stand.
--
-- `after` says for the log line what the mob was stuck for: the seconds of a
-- caller that times its walk (a work resident walking back to its socket for
-- 30 s, start_villagers.lua), or the reason of one fed by the navigation
-- (failed searches).
function grug_mobs.snap_to(self, pos, x, z, after)
	if not grug_mobs.unwatched(pos, SNAP_PLAYER_RANGE) then
		return false
	end
	local y = standing_y(math.floor(x + 0.5), math.floor(z + 0.5), pos.y)
	if not y then
		return false
	end
	local to = {x = x, y = y, z = z}
	grug_mobs.place_on_ground(self.object, to)
	-- Arrived by other means: the walk, its leg and the give-up count end.
	local t = self.temp
	if t then t.grug_stall_cycles, t.grug_snap_wait, t.grug_leg = nil, nil, nil end
	grug_mobs.walk_clear(self)
	core.log("action", "[grug_mobs] " .. self.name .. " was stuck " ..
		(type(after) == "number" and ("for " .. after .. " s") or (after or "")) ..
		" and was moved to " .. core.pos_to_string(to) ..
		" with no player within " .. SNAP_PLAYER_RANGE)
	return true
end

-- A patrol's walk is over: the next leg starts clean (on a cached route at
-- the corner nearest to it, routes.lua).
local function route_clear(self)
	grug_mobs.walk_clear(self, "route")
	local t = self.temp
	t.grug_route_skips, t.grug_stall_cycles, t.grug_snap_wait = nil, nil, nil
	if t.grug_leg and t.grug_leg.owner == "route" then t.grug_leg = nil end
end

--
-- points     — array of {x = , z = } (y optional), at least 2; the mob walks
--              on whatever ground it finds and the navigation finds the way
--              round what stands in it.
-- wp_holder  — the table holding the current waypoint index, and
-- wp_key     — its key inside it. Both callers keep that index in a PLAIN
--              entity field (directly on self for rares, inside the route
--              table for guards), so the position in the route survives
--              unload/reload with the mob. Never an ObjectRef, never a
--              function — those do not reach staticdata.
-- snap       — whether the out-of-sight snap is the last stage. The start and
--              capital watch passes true (guard.lua); the named rares walk
--              wilderness waypoints and only skip (a rare that has to be
--              teleported is somebody else's work package).
-- settlement — the settlement key of a start or capital watch (guard.lua):
--              its legs, from the waypoint last reached to the next, come
--              from the route cache (routes.lua; a capital's over its
--              streets), and a leg with no route is skipped at once. Without
--              it (outposts, rares) each waypoint is a plain fixed walk.
--
function grug_mobs.route_tick(self, dtime, points, wp_holder, wp_key, snap,
		settlement)
	if not points or #points < 2 then
		return
	end
	self.temp = self.temp or {}
	local t = self.temp
	t.grug_route_acc = (t.grug_route_acc or 0) + dtime
	if t.grug_route_acc < TICK then
		if settlement then
			grug_mobs.route_follow(self, dtime, "route")
		else
			grug_mobs.walk_follow(self, dtime, "route")
		end
		return
	end
	t.grug_route_acc = 0
	-- Idle only: fighting, fleeing and flopping all own the movement.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		route_clear(self)
		return
	end
	local pos = self.object and self.object:get_pos()
	if not pos then
		return
	end
	local idx = wp_holder[wp_key] or 1
	if idx > #points then
		idx = 1
	end
	local pt = points[idx]
	local dx, dz = pt.x - pos.x, pt.z - pos.z
	if dx * dx + dz * dz <= WAYPOINT_REACHED * WAYPOINT_REACHED then
		t.grug_route_from = idx
		idx = idx % #points + 1
		wp_holder[wp_key] = idx
		pt = points[idx]
		route_clear(self)
	end
	local fails, none
	if settlement then
		-- The leg from the waypoint last reached (runtime; after a reload
		-- the one before this one).
		local from = points[t.grug_route_from or 0]
		if not from or from == pt then from = points[(idx - 2) % #points + 1] end
		fails, none = grug_mobs.route_walk(self, dtime, pos, settlement, from, pt,
			"route", true)
	end
	if not fails then
		fails = grug_mobs.walk_fixed(self, dtime, pos, pt.x, pt.y, pt.z, idx,
			"route")
	end
	if not none and fails < SKIP_AFTER then
		return
	end
	if snap and (t.grug_route_skips or 0) > 0 and grug_mobs.snap_try(self, pos,
			pt.x, pt.z, "on two waypoints in a row") then
		return
	end
	wp_holder[wp_key] = idx % #points + 1
	t.grug_route_skips = (t.grug_route_skips or 0) + 1
	report_give_up(self)
end
