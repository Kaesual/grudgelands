--
-- Shared route walking (named-rare amble, rares.lua; outpost patrols,
-- guard.lua / camps.lua — docs/design/world.md §4 "between outposts: ambient
-- patrols").
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
-- single nudge is a suggestion, not a command — but do_custom runs BEFORE
-- do_states in the same step and this repeats once a second, so the mob
-- makes net progress instead of a straight line. That is exactly what an
-- amble should look like.
--
-- `pos` is passed in because both callers already fetched it; y is only used
-- to keep the yaw horizontal.
--
function grug_mobs.walk_toward(self, x, z, pos)
	self:yaw_to_pos(vector.new(x, pos.y, z), 0, 4)
	self.state = "walk"
	self:set_velocity(self.walk_velocity)
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
-- STUCK RESCUE (playtest round 1, 2026-09-15). A route is a DIRECTION, not a
-- path, so a waypoint behind a building, a fence line or another guard is
-- something a nudged mob can push against forever -- and with a settlement full
-- of guards, groups walking into each other did exactly that. Three stages,
-- each one more drastic than the last:
--
--   1. STALL_PATH   ask `core.find_path` for a way round and steer at its first
--                   node instead of straight at the waypoint. This is the only
--                   pathfinding a route carrier can get: mobs_redo's own
--                   `pathfinding` field is consulted in the ATTACK state alone
--                   (smart_mobs), which an ambling guard never enters.
--   2. STALL_SKIP   give the waypoint up and take the next one. A loop is a
--                   patrol, not a delivery: what matters is that the guard keeps
--                   walking, not that it stands on node N.
--   3. STALL_SNAP   teleport onto the waypoint -- but ONLY while no player is
--                   within SNAP_PLAYER_RANGE (the user's 2026-09-15 ruling: an
--                   out-of-sight teleport is fine, one in plain view is not).
--
-- TWO CLOCKS, and that is what makes the escalation real. `stalled` is reset by
-- measurable progress and LOWERED (not cleared) by stage 2, so a skipped
-- waypoint buys a grace period and not a fresh timeout; `total` is reset by
-- progress alone, so a mob wedged in a corner reaches stage 3 however often its
-- target is changed for it. Both live in `self.temp`, i.e. runtime only: a mob
-- that was unloaded was not stuck while nobody was watching it, and its clocks
-- start again from zero on the next activation.
--
-- The ordinary case -- a guard that walks -- never reaches stage 1 at all.
--
local PROGRESS = 1 -- squared-distance improvement that counts as progress
local STALL_PATH = 20 -- s without progress: ask the pathfinder
local STALL_SKIP = 45 -- s without progress: give this waypoint up
local STALL_SNAP = 90 -- s stuck in total: teleport, out of sight only
local SNAP_PLAYER_RANGE = 48 -- nodes; the user's "out of sight" radius
local PATH_SEARCH = 24 -- nodes of core.find_path search distance
-- A LOOP NOBODY CAN WALK IS A TERMINAL STATE, not something to report for ever.
-- After QUIET_AFTER give-ups the mob keeps trying in silence, and a refused
-- teleport is retried every SNAP_RETRY seconds instead of on every tick: with
-- every waypoint unreachable AND a player inside SNAP_PLAYER_RANGE, the
-- unthrottled version logged one line and called `get_objects_inside_radius`
-- once a second for as long as the player stood there.
local SNAP_RETRY = 10 -- s between out-of-sight attempts once one was refused
local QUIET_AFTER = 4 -- give-up cycles before the log goes quiet

--
-- How long this mob has made no measurable progress toward (x, z). Returns the
-- two clocks of the header: the one a skip may lower, and the one only progress
-- clears.
--
-- A CHANGED TARGET replaces the yardstick and keeps both clocks. Measuring
-- against the new target from scratch would hand a stuck mob a fresh timeout
-- every time something re-aimed it.
--
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
-- Stage 3 with a back-off. The first attempt runs the moment the mob is due; a
-- refusal -- a player inside SNAP_PLAYER_RANGE, or a column with nowhere to
-- stand -- is retried only every SNAP_RETRY seconds.
--
function grug_mobs.snap_try(self, pos, x, z, elapsed, after)
	self.temp = self.temp or {}
	local t = self.temp
	local wait = (t.grug_snap_wait or 0) - (elapsed or 0)
	if wait > 0 then
		t.grug_snap_wait = wait
		return false
	end
	if grug_mobs.snap_to(self, pos, x, z, after) then
		t.grug_snap_wait = nil
		return true
	end
	t.grug_snap_wait = SNAP_RETRY
	return false
end

-- One give-up, counted. Reports the first QUIET_AFTER - 1 of them, then says
-- once that it is going quiet, then says nothing until something clears the
-- clocks (arrival, a fight, an unload).
local function report_give_up(self)
	local t = self.temp
	t.grug_stall_cycles = (t.grug_stall_cycles or 0) + 1
	if t.grug_stall_cycles < QUIET_AFTER then
		core.log("action", "[grug_mobs] " .. self.name ..
			" could not reach its waypoint in " .. STALL_SKIP ..
			" s and walks on to the next one")
	elseif t.grug_stall_cycles == QUIET_AFTER then
		core.log("action", "[grug_mobs] " .. self.name ..
			" cannot reach any waypoint of its loop; it keeps trying without" ..
			" reporting until it makes progress")
	end
end

-- Lower the skip clock without clearing the total one (stage 2).
local function stall_grace(self)
	local t = self.temp
	if t then
		t.grug_stall = STALL_PATH
	end
end

--
-- ONE nudge along a PATH to (x, z) instead of straight at it. `core.find_path`
-- is a ground search over the loaded map; max_jump 1 / max_drop 2 is what a
-- guard can actually do (stepheight 1.1, fear_height 4). Only the first node far
-- enough away to yaw at is used: the next tick asks again from the new position,
-- so the mob follows a path without ever carrying one in its staticdata.
--
-- Returns false when there is no path at all, which is what makes stage 2 the
-- next thing that happens.
--
function grug_mobs.path_nudge(self, x, z, pos)
	local from = {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5)}
	local to = {x = math.floor(x + 0.5), y = from.y, z = math.floor(z + 0.5)}
	local path = core.find_path(from, to, PATH_SEARCH, 1, 2, "A*_noprefetch")
	if not path then
		return false
	end
	for index = 1, #path do
		local step = path[index]
		local dx, dz = step.x - pos.x, step.z - pos.z
		if dx * dx + dz * dz > 1 then
			grug_mobs.walk_toward(self, step.x, step.z, pos)
			return true
		end
	end
	return false
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

-- The standing y for (x, z) near `around_y`: the topmost cell whose own node and
-- head room are not walkable and which has walkable ground under it. nil when
-- the column offers none, which is a refusal to teleport rather than a guess.
local function standing_y(x, z, around_y)
	local base = math.floor(around_y + 0.5)
	for y = base + 4, base - 8, -1 do
		local here = core.get_node_or_nil({x = x, y = y, z = z})
		local above = core.get_node_or_nil({x = x, y = y + 1, z = z})
		local below = core.get_node_or_nil({x = x, y = y - 1, z = z})
		local here_def = here and core.registered_nodes[here.name]
		local above_def = above and core.registered_nodes[above.name]
		local below_def = below and core.registered_nodes[below.name]
		if here_def and above_def and below_def and
				here_def.walkable ~= true and above_def.walkable ~= true and
				below_def.walkable == true then
			return y
		end
	end
	return nil
end

--
-- Stage 3: put the mob down on (x, z) through the same `place_on_ground`
-- correction every hand placement in this mod uses -- a standing y is a FEET
-- position and an entity position is its collisionbox origin. Refuses while a
-- player is within SNAP_PLAYER_RANGE, and refuses when the column has nowhere
-- to stand.
--
-- `after` is the caller's own timeout, for the log line only. It is a
-- parameter rather than the module's `STALL_SNAP` because the callers do not
-- share one: the route and the guard post snap after 90 s, a work resident
-- walking back to its socket after 30 s (start_villagers.lua), and a log line
-- that always said 90 was a log line that lied about two of the three.
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
	core.log("action", "[grug_mobs] " .. self.name .. " was stuck for " ..
		(after or STALL_SNAP) .. " s and was moved to " ..
		core.pos_to_string(to) ..
		" with no player within " .. SNAP_PLAYER_RANGE)
	return true
end

--
-- points     — array of {x = , z = }, at least 2; y is never used, the mob
--              walks on whatever ground it finds (the route is a direction,
--              not a path — the stuck rescue above handles the obstacles).
-- wp_holder  — the table holding the current waypoint index, and
-- wp_key     — its key inside it. Both callers keep that index in a PLAIN
--              entity field (directly on self for rares, inside the route
--              table for guards), so the position in the route survives
--              unload/reload with the mob. Never an ObjectRef, never a
--              function — those do not reach staticdata.
-- rescue     — opt in to the three-stage stuck rescue above. The start and
--              capital watch passes true (guard.lua); the named rares keep the
--              plain nudge, because their waypoints are wilderness and a rare
--              that has to be teleported is somebody else's work package.
--
function grug_mobs.route_tick(self, dtime, points, wp_holder, wp_key, rescue)
	if not points or #points < 2 then
		return
	end
	self.temp = self.temp or {}
	local t = self.temp
	t.grug_route_acc = (t.grug_route_acc or 0) + dtime
	if t.grug_route_acc < TICK then
		return
	end
	local elapsed = t.grug_route_acc
	t.grug_route_acc = 0
	-- Idle only: fighting, fleeing and flopping all own the movement.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		grug_mobs.stall_clear(self)
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
		-- Arrived: the next leg starts with clean clocks.
		grug_mobs.stall_clear(self)
	end
	if not rescue then
		grug_mobs.walk_toward(self, pt.x, pt.z, pos)
		return
	end
	local stalled, total = grug_mobs.stall_clock(self, pt.x, pt.z, pos, elapsed)
	if total >= STALL_SNAP and
			grug_mobs.snap_try(self, pos, pt.x, pt.z, elapsed,
				STALL_SNAP) then
		return
	end
	if stalled >= STALL_SKIP then
		idx = idx % #points + 1
		wp_holder[wp_key] = idx
		pt = points[idx]
		stall_grace(self)
		stalled = STALL_PATH
		report_give_up(self)
	end
	if stalled >= STALL_PATH and grug_mobs.path_nudge(self, pt.x, pt.z, pos) then
		return
	end
	grug_mobs.walk_toward(self, pt.x, pt.z, pos)
end
