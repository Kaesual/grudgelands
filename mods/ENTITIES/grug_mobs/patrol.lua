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

local WAYPOINT_REACHED = 4 -- m
local TICK = 1 -- s between nudges (performance rule: throttled)

--
-- ONE nudge toward a horizontal point: turn, and keep walking. This is the
-- whole movement primitive — shared with the camp roam cap in aggro.lua
-- (world.md §4a, "while idle they roam only a small radius around their
-- anchor"), which is the same "walk that way" with a different target.
--
-- mobs_redo's own walk state re-randomizes the yaw with a 30 % chance per
-- do_states call (api.lua:2176-2864) and may stop the mob (`stand_chance`), so a
-- single nudge is a suggestion, not a command — but do_states runs only once a
-- second on its own timer and this repeats once a second, so the mob makes net
-- progress instead of a straight line. That is exactly what an amble should
-- look like.
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
-- HELD WALKERS. mobs_redo stops a walker that faces a node named fence, gate
-- or wall (`facing_fence`, do_states) and the ambient cliff guard stops it at
-- a drop of 1.5 (`is_at_cliff`); a town wall or gate is where guards stand.
-- The walk still wants to move there, so the detector hears the speed the
-- nudge commanded, not the speed mobs_redo left it: such a walker is stuck
-- like one pressed into a trunk, and a path down a drop the cliff guard
-- refuses is followed (the engine plans drops up to the mob's fear height).
-- mobs_redo's random stop (`stand_chance`) is no hold: a once-a-second window
-- that ends with the walker stood still for no reason of its own is not
-- measured.
--
-- One walk per mob in `self.temp.grug_walk` (runtime only): its owner (the
-- tick that drives it), its key (one goal; a new key is a new walk for the
-- navigation) and the goal's feet position. Fliers never search (their walk
-- stays the plain nudge), like in a fight.
--
local nav = mobs.grug_nav

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

--
-- One decision of a fixed walk, from its owner's once-a-second tick: walk
-- toward (x, y, z), `y` the goal's feet height or nil when the goal is given
-- in plan only (a route point, a post), as walk `key` of `owner`. `opts`:
-- fixed_step's search options (the evade's local point). Returns the failed
-- searches in a row of this walk.
--
function grug_mobs.walk_fixed(self, dtime, pos, x, y, z, key, owner, opts)
	self.temp = self.temp or {}
	local t = self.temp
	local w = t.grug_walk
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
		-- mobs_redo stood the walker since the last nudge: no measure.
		nav.command(self, pos, 0)
	end
	drive(self, w, pos)
	nst = t.grug_nav
	return nst and nst.target == key and nst.fails or 0
end

--
-- Every other step of the walk's owner: the time since the last decision,
-- and the steer every step while the walk follows a path or waits for a
-- search. Idle only, like the decisions (a fight owns the movement).
--
function grug_mobs.walk_follow(self, dtime, owner)
	local t = self.temp
	local w = t and t.grug_walk
	if not w or w.owner ~= owner then return end
	w.dt = w.dt + dtime
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
	t.grug_walk = nil
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
-- THE VILLAGERS' STALL CLOCK (start_villagers.lua; Round 42 NV3 moves the
-- villagers onto the navigation too). How long this mob has made no
-- measurable progress toward (x, z), as two clocks: the one a caller may
-- lower, and the one only progress clears. A CHANGED TARGET replaces the
-- yardstick and keeps both clocks.
--
local PROGRESS = 1 -- squared-distance improvement that counts as progress

function grug_mobs.stall_clock(self, x, z, pos, elapsed)
	self.temp = self.temp or {}
	local t = self.temp
	local dx, dz = x - pos.x, z - pos.z
	local d2 = dx * dx + dz * dz
	if t.grug_stall_x ~= x or t.grug_stall_z ~= z then
		t.grug_stall_x, t.grug_stall_z = x, z
		t.grug_stall_d2 = d2
		return t.grug_stall or 0, t.grug_stall_total or 0
	end
	local base = t.grug_stall_d2
	if not base or d2 <= base - PROGRESS then
		t.grug_stall_d2 = d2
		t.grug_stall, t.grug_stall_total = 0, 0
		return 0, 0
	end
	t.grug_stall = (t.grug_stall or 0) + (elapsed or 0)
	t.grug_stall_total = (t.grug_stall_total or 0) + (elapsed or 0)
	return t.grug_stall, t.grug_stall_total
end

-- Forget both clocks AND the terminal state: the mob arrived, or something else
-- took the movement over. A fight is not a stall, and a mob that has just made
-- progress is allowed to report its next problem out loud again.
function grug_mobs.stall_clear(self)
	local t = self.temp
	if not t then
		return
	end
	t.grug_stall, t.grug_stall_total, t.grug_stall_d2 = nil, nil, nil
	t.grug_stall_x, t.grug_stall_z = nil, nil
	t.grug_stall_cycles, t.grug_snap_wait = nil, nil
end

--
-- The snap with a back-off. The first attempt runs the moment the mob is due;
-- a refusal -- a player inside SNAP_PLAYER_RANGE, or a column with nowhere to
-- stand -- is retried only SNAP_RETRY seconds later: a deadline on the server
-- clock (`grug_snap_wait`, runtime only), so a caller that asks rarely (a
-- patrol, after three fresh failures) waits as long as one that asks every
-- tick. `elapsed` is no longer read (the villagers still pass it).
--
function grug_mobs.snap_try(self, pos, x, z, elapsed, after)
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
			" failed searches in a row) and walks on to the next one")
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
-- caller that still times its stall (a work resident walking back to its
-- socket after 30 s, start_villagers.lua), or the reason of one fed by the
-- navigation (failed searches).
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
	grug_mobs.stall_clear(self)
	grug_mobs.walk_clear(self)
	core.log("action", "[grug_mobs] " .. self.name .. " was stuck " ..
		(type(after) == "number" and ("for " .. after .. " s") or (after or "")) ..
		" and was moved to " .. core.pos_to_string(to) ..
		" with no player within " .. SNAP_PLAYER_RANGE)
	return true
end

-- A patrol's walk is over: the next leg starts clean.
local function route_clear(self)
	grug_mobs.walk_clear(self, "route")
	local t = self.temp
	t.grug_route_skips, t.grug_stall_cycles, t.grug_snap_wait = nil, nil, nil
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
--
function grug_mobs.route_tick(self, dtime, points, wp_holder, wp_key, snap)
	if not points or #points < 2 then
		return
	end
	self.temp = self.temp or {}
	local t = self.temp
	t.grug_route_acc = (t.grug_route_acc or 0) + dtime
	if t.grug_route_acc < TICK then
		grug_mobs.walk_follow(self, dtime, "route")
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
		idx = idx % #points + 1
		wp_holder[wp_key] = idx
		pt = points[idx]
		route_clear(self)
	end
	if grug_mobs.walk_fixed(self, dtime, pos, pt.x, pt.y, pt.z, idx,
			"route") < SKIP_AFTER then
		return
	end
	if snap and (t.grug_route_skips or 0) > 0 and grug_mobs.snap_try(self, pos,
			pt.x, pt.z, TICK, "on two waypoints in a row") then
		return
	end
	wp_holder[wp_key] = idx % #points + 1
	t.grug_route_skips = (t.grug_route_skips or 0) + 1
	report_give_up(self)
end
