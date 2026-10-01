--
-- Road and town push (Round 28 ruling 2)
--
-- Roads and towns should feel safe to travel and rest in, but must never
-- become a combat refuge. So an idle, free-roaming AGGRESSIVE mob that sees a
-- road, a bridge, a village, a start town or a capital city near it walks
-- away from it, and nothing else changes: a mob in a fight chases its target
-- across any road exactly as before. It is a cheap tendency, not a guarantee:
-- mobs_redo's random walk may carry a mob back for a while, and the next probe
-- turns it away again.
--
-- The probe: every PROBE_TICKS (4 or 5, picked per mob) of the one-second
-- leash slot, eight points on a horizontal ring of radius `view_range` around
-- the mob, at the mob's own height. A point hits on a road, bridge or village
-- (grug_core.world_feature_at, the world protection's analytic corridors and
-- core boxes) or on a start town or capital city (grug_zones
-- hard_protection_kind_at "town"). Hostile places (bandit and Mirefolk camps,
-- clash sites and the other POI kinds, "camp"/"poi") do not push. With any hit
-- the mob walks away from the hits, the opposite of their mean direction,
-- with the wander leash's own nudge (patrol.lua walk_toward).
--
-- Composition with the wander leash (Round 24 ruling 19, Round 28 ruling 4):
-- aggro.lua roam_check calls the push only for a free roamer INSIDE its
-- WANDER_RADIUS; outside it the leash walks the mob home and the push is not
-- asked. So the two never steer in the same slot, and a mob whose spawn point
-- lies near a road settles at the far side of its leash circle.
--

local sqrt, cos, sin, pi = math.sqrt, math.cos, math.sin, math.pi

-- Leash slots (1 s each) between two probes of one mob, picked per probe
-- from this range (the per-mob jitter that keeps a herd from probing in step).
grug_mobs.ROAM_AVOID_TICKS = {4, 5}

-- The ring's eight unit directions, counter-clockwise from +x.
local PROBES = 8
local DIRS = {}
for index = 1, PROBES do
	local angle = (index - 1) * 2 * pi / PROBES
	DIRS[index] = {cos(angle), sin(angle)}
end
grug_mobs.ROAM_AVOID_DIRS = DIRS

-- world_feature_at kinds that push; "camp" and "poi" are hostile places.
local PUSH_FEATURE = {road = true, bridge = true, village = true}

-- Whether one probe point lies on ground the push keeps mobs away from.
function grug_mobs.roam_avoid_hit(pos)
	if PUSH_FEATURE[grug_core.world_feature_at(pos)] then
		return true
	end
	return grug_zones.hard_protection_kind_at(pos) == "town"
end

-- The unit direction (x, z) to walk away from the hits, or nil when nothing
-- hit or every point hit. `hits[i]` belongs to DIRS[i]. Usually the opposite
-- of the hits' mean direction; when the hits cancel out (a mob standing ON a
-- straight road sees it ahead and behind, a crossroads in four directions)
-- the free direction with the most free neighbours, the first such in ring
-- order: off a straight road at a right angle, off a crossroads diagonally.
function grug_mobs.roam_avoid_away(hits)
	local sx, sz, count = 0, 0, 0
	for index = 1, PROBES do
		if hits[index] then
			sx, sz = sx + DIRS[index][1], sz + DIRS[index][2]
			count = count + 1
		end
	end
	if count == 0 or count == PROBES then
		return nil
	end
	local length = sqrt(sx * sx + sz * sz)
	if length > 0.01 then
		return -sx / length, -sz / length
	end
	local best, best_free = nil, -1
	for index = 1, PROBES do
		if not hits[index] then
			local free = (hits[(index - 2) % PROBES + 1] and 0 or 1) +
				(hits[index % PROBES + 1] and 0 or 1)
			if free > best_free then
				best, best_free = index, free
			end
		end
	end
	return DIRS[best][1], DIRS[best][2]
end

-- The eight probe hits around `pos` at radius `radius` (reused table).
local hits = {}
local point = {x = 0, y = 0, z = 0}
function grug_mobs.roam_avoid_probe(pos, radius)
	point.y = pos.y
	for index = 1, PROBES do
		point.x = pos.x + DIRS[index][1] * radius
		point.z = pos.z + DIRS[index][2] * radius
		hits[index] = grug_mobs.roam_avoid_hit(point)
	end
	return hits
end

-- Called by aggro.lua roam_check once per leash slot for an idle free roamer
-- inside its wander leash; roam_check has already refused fights, follows,
-- flight and the evade run. Only aggressive mobs take the push.
function grug_mobs.roam_avoid_tick(self, pos)
	if self._grug_disposition ~= "aggressive" then
		return
	end
	local t = self.temp
	-- The first probe of an activation lands on a random slot of the period.
	local wait = (t.grug_avoid_wait or math.random(1, grug_mobs.ROAM_AVOID_TICKS[2])) - 1
	if wait > 0 then
		t.grug_avoid_wait = wait
		return
	end
	t.grug_avoid_wait = math.random(grug_mobs.ROAM_AVOID_TICKS[1],
		grug_mobs.ROAM_AVOID_TICKS[2])
	local radius = self.view_range
	if type(radius) ~= "number" or radius <= 0 or
			not grug_core.zone_authority_installed() then
		return
	end
	local away_x, away_z = grug_mobs.roam_avoid_away(grug_mobs.roam_avoid_probe(pos, radius))
	if away_x then
		grug_mobs.walk_toward(self, pos.x + away_x * radius, pos.z + away_z * radius, pos)
	end
end
