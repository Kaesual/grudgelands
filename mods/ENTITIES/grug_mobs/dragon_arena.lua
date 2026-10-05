-- Dragon arena rules (Round 31 DA2, round31-plan.md §6 item 11), pure
-- functions shared by boss_dragons.lua and its fixture (tools/r31_da2).
--
-- The arena's clear edge is the dragon's leash: a hostile player inside it is
-- a target whatever their height (within the arena's protected band), a
-- player outside it can neither be targeted nor hurt the dragon, and once
-- the dragon has no hostile target left inside, the fight ends: it heals
-- fully, forgets the attempt and flies back to its spawn.
local M = {}

-- The arena radius (the mapgen's dragon profile `arena_radius`,
-- grug_mapgen/wp40/source/simple_map.lua; the fixture checks they match).
M.RADIUS = 40
-- The band around the arena floor that counts as inside: the POI
-- protection box's 10 below and 22 above the floor, plus the player's height.
M.BELOW, M.ABOVE = 10, 24
-- Hazards: damage per second (not reduced by armour), the ice water's slow,
-- and how long after a player's step thin ice breaks.
M.ICE_WATER_DPS, M.EMBER_DPS = 250, 350
M.ICE_SLOW_FACTOR, M.ICE_SLOW_TIME = 0.6, 0.5
M.ICE_BREAK_DELAY = 1
-- The dragon's wrath (user ruling 2026-10-03): damage per second to a fight
-- participant who stands outside the arena while the fight runs.
M.WRATH_DPS = 500
-- A supporter (heal, shield) of a participant joins the fight only within
-- the arena radius + SUPPORT_REACH of its centre (horizontal).
M.SUPPORT_REACH = 15

function M.near(arena, pos)
	if not arena or not pos then return false end
	local dx, dz = pos.x - arena.x, pos.z - arena.z
	local r = (arena.radius or M.RADIUS) + M.SUPPORT_REACH
	return dx * dx + dz * dz <= r * r
end

-- `arena` = {x, y, z, radius}: the spawn point (y the floor + 1) and radius.
function M.inside(arena, pos)
	if not arena or not pos then return false end
	local dx, dz = pos.x - arena.x, pos.z - arena.z
	local r = arena.radius or M.RADIUS
	return dx * dx + dz * dz <= r * r and pos.y >= arena.y - M.BELOW and
		pos.y <= arena.y + M.ABOVE
end

-- A destination for the dragon's flight kept inside the arena (`margin`
-- nodes from the edge), so it never chases or dives out of it.
function M.clamp(arena, pos, margin)
	local dx, dz = pos.x - arena.x, pos.z - arena.z
	local limit = (arena.radius or M.RADIUS) - (margin or 0)
	local d2 = dx * dx + dz * dz
	if d2 <= limit * limit or d2 == 0 then return pos end
	local f = limit / math.sqrt(d2)
	return {x = arena.x + dx * f, y = pos.y, z = arena.z + dz * f}
end

-- The dragon's push (Round 36, the wing gust and the dive's slam): a player
-- in the air brakes at the engine's default air acceleration (AIR_BRAKE nodes
-- per s², Luanti `movement_acceleration_air`), so a push of `speed` carries
-- him speed² / (2 * AIR_BRAKE) nodes; slowed to SLOW_FLOOR he brakes less and
-- slides 1 / SLOW_FLOOR as far. The push never carries even such a player
-- beyond radius - PUSH_EDGE (the hazards' edge margin), so nobody is pushed
-- out of the arena into the wrath or over the floor's outer edge.
M.AIR_BRAKE, M.SLOW_FLOOR, M.PUSH_EDGE = 20, 0.6, 4

-- How far a push of `speed` (nodes per second) carries an unslowed player.
function M.push_travel(speed)
	return speed * speed / (2 * M.AIR_BRAKE)
end

-- The velocity that pushes a player at `pos` away from `origin` (horizontal,
-- plus `lift` upward), weakened so he stays inside the arena; nil when there
-- is no direction or less than one node of room is left. `arena` nil: the
-- full push.
function M.push(arena, origin, pos, speed, lift)
	if not origin or not pos then return nil end
	local dx, dz = pos.x - origin.x, pos.z - origin.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length <= 1e-6 then return nil end
	dx, dz = dx / length, dz / length
	local scale = 1
	if arena then
		-- The room along the push to the circle of radius - PUSH_EDGE: the
		-- positive root t of |pos - centre + t * dir| = limit.
		local limit = (arena.radius or M.RADIUS) - M.PUSH_EDGE
		local px, pz = pos.x - arena.x, pos.z - arena.z
		local b = px * dx + pz * dz
		local c = px * px + pz * pz - limit * limit
		local room = 0
		if c < 0 then room = -b + math.sqrt(b * b - c) end
		room = room * M.SLOW_FLOOR
		if room < 1 then return nil end
		local travel = M.push_travel(speed)
		if room < travel then scale = math.sqrt(room / travel) end
	end
	return {x = dx * speed * scale, y = lift, z = dz * speed * scale}
end

-- Whether the fight ends now: the dragon was engaged and no hostile living
-- player is left inside its arena.
function M.should_reset(engaged, hostiles_inside)
	return engaged == true and (hostiles_inside or 0) == 0
end

-- What the hazard node at a player's feet does per second: damage, and
-- whether it slows; nil for any other node. `nodes` = arena_layout.NODES.
function M.hazard(nodes, name)
	if name == nodes.ice_water then return M.ICE_WATER_DPS, true end
	if name == nodes.ember then return M.EMBER_DPS, false end
	return nil
end

-- Thin ice (user ruling 2026-10-04, Round 34, refined the same day): each
-- sample of the 0.25 s hazard pass marks every thin-ice node in the 3x3x3
-- cube around a player's feet, and a marked node breaks ICE_BREAK_DELAY
-- seconds later, whether the player is still there or not. The cube covers
-- the gap between two samples, so the path between them is not walked. A
-- node holds at most one pending break, server-wide: marking it again never
-- resets or postpones it (the earlier break wins).

-- A sample at `feet` (a rounded node position) at time `now`: marks every
-- node of the cube that `is_thin_ice(pos)` and has no pending break
-- (`pending`: node key -> true; `key_of(pos)` the key) and returns their
-- break event {due, at, nodes}, or nil when nothing new was marked.
function M.ice_step(pending, feet, now, key_of, is_thin_ice)
	local nodes = {}
	for dy = -1, 1 do
		for dx = -1, 1 do
			for dz = -1, 1 do
				local pos = {x = feet.x + dx, y = feet.y + dy, z = feet.z + dz}
				local key = key_of(pos)
				if not pending[key] and is_thin_ice(pos) then
					pending[key] = true
					nodes[#nodes + 1] = pos
				end
			end
		end
	end
	if #nodes == 0 then return nil end
	return {due = now + M.ICE_BREAK_DELAY, at = feet, nodes = nodes}
end

-- The events at the head of `queue` (kept in sample order) that are due at
-- `now`, removed from it.
function M.ice_due(queue, now)
	local due = {}
	while queue[1] and queue[1].due <= now + 1e-6 do
		due[#due + 1] = table.remove(queue, 1)
	end
	return due
end

return M
