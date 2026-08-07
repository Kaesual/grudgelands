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
-- We do NOT use mobs_redo's mob_class:go_to(pos) (api.lua:1672). It works by
-- spawning a temporary "mobs:_pos" entity and calling do_attack(obj, true) on
-- it — i.e. it puts the mob into state "attack" with a dummy target. Three
-- things break for us: general_attack() bails out entirely while
-- state == "attack" (api.lua:1695), so a patrolling mob would be BLIND to
-- players; our threat/leash logic would see an attack state with a non-player
-- target; and the telegraph would count the dummy as melee combat. A yaw +
-- walk-velocity nudge once a second is all an amble needs.
--

local WAYPOINT_REACHED = 4 -- m
local TICK = 1 -- s between nudges (performance rule: throttled)

--
-- points     — array of {x = , z = }, at least 2; y is never used, the mob
--              walks on whatever ground it finds (the route is a direction,
--              not a path — pathfinding = 1 handles the obstacles).
-- wp_holder  — the table holding the current waypoint index, and
-- wp_key     — its key inside it. Both callers keep that index in a PLAIN
--              entity field (directly on self for rares, inside the route
--              table for guards), so the position in the route survives
--              unload/reload with the mob. Never an ObjectRef, never a
--              function — those do not reach staticdata.
--
function grug_mobs.route_tick(self, dtime, points, wp_holder, wp_key)
	if not points or #points < 2 then
		return
	end
	self.temp = self.temp or {}
	local t = self.temp
	t.grug_route_acc = (t.grug_route_acc or 0) + dtime
	if t.grug_route_acc < TICK then
		return
	end
	t.grug_route_acc = 0
	-- Idle only: fighting, fleeing and flopping all own the movement.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
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
	end
	self:yaw_to_pos(vector.new(pt.x, pos.y, pt.z), 0, 4)
	self.state = "walk"
	self:set_velocity(self.walk_velocity)
end
