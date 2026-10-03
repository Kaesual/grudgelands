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
-- and how long a player may stand on thin ice before it breaks.
M.ICE_WATER_DPS, M.EMBER_DPS = 250, 350
M.ICE_SLOW_FACTOR, M.ICE_SLOW_TIME = 0.6, 0.5
M.ICE_BREAK_TIME = 1.5
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

-- Standing on thin ice: the time spent on the same node so far (`entry` =
-- {key, time} or nil) and whether it breaks now.
function M.ice_step(entry, key, dtime)
	if not key then return nil, false end
	local time = (entry and entry.key == key and entry.time or 0) + dtime
	if time >= M.ICE_BREAK_TIME then return nil, true end
	return {key = key, time = time}, false
end

return M
