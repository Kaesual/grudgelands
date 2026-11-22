-- The arena "Breach Road" (Round 85, round85-plan.md §4 WORLD, rulings 1, 3,
-- 9, 18): its layout relative to its site. Pure data and arithmetic, no
-- engine calls, plain Lua 5.1: the world generation (`breach_site.lua`,
-- `height.lua`, `road_layout.lua`), the arena's blocks, its territory, the
-- spawn rules and every tool read the same answers.
--
-- The site is a rule of world generation (`breach_site.lua`, searched near
-- (0, 0) on the natural terrain); it is never a constant. Every world holds
-- it in its placement text (`placement.lua`, the "breach" line), which main,
-- emerge, the layout cache and every tool already have:
--
--   local L = dofile(wp40 .. "/breach_layout.lua")
--   local site = L.from_placement(placement_text)  -- {x, z, y, reach}
--   local world = L.world(site)                     -- everything in world nodes
--
-- Local coordinates: lx = x - site.x, lz = z - site.z, ly = y - site.y (the
-- datum, the road's surface node), +x east, +z north. The orientation is
-- fixed (the draft's): the road runs north-south through the middle, the
-- Accord's hall stands east of it (the Accord's fortress side, placement
-- rules), the Throng's west; the west wing is the east wing turned through
-- 180 degrees about the centre.
local M = {}

M.ID = "breach_road"
-- The place's name (a coordinator default, round85-plan.md §2).
M.NAME = "Breach Road"

-- The draft's levels (tools/r84_arena_draft/REPORT.md §1): the road, the
-- ruined galleries, both halls and the lookout spurs, nodes above the datum.
-- World generation levels the whole footprint to the datum; the terraces
-- above it are the arena's blocks.
M.LEVELS = {road = 0, gallery = 3, upper = 6}

-- The footprint: the draft's surveyed rim (`sites.py` RIM, the east wing)
-- and its point mirror, one closed polygon of integer vertices. A column
-- belongs to the footprint when its centre lies inside it or on its edge
-- (`M.inside`). Its bounds are x -49..49, z -45..45 (99 x 91).
local RIM = {{0, -45}, {6, -45}, {9, -38}, {17, -36}, {25, -39}, {37, -32}, {40, -24},
	{48, -21}, {49, -15}, {49, 16}, {46, 21}, {38, 29}, {30, 38}, {18, 40}, {10, 35},
	{6, 45}, {0, 45}}
local POLYGON = {}
for index = 1, #RIM do POLYGON[#POLYGON + 1] = RIM[index] end
for index = 2, #RIM - 1 do POLYGON[#POLYGON + 1] = {-RIM[index][1], -RIM[index][2]} end
M.POLYGON = POLYGON
M.HALF_X, M.HALF_Z = 49, 45

-- The levelled ground: the footprint's convex hull, counter-clockwise (x
-- east, z north). It is flat at the datum; outside it the ground blends into
-- the natural terrain (`breach_site.lua`). Being convex, every column outside
-- it has one nearest point on it that moves continuously, so the blend has
-- no seam.
M.HULL = {{-49, -16}, {-46, -21}, {-30, -38}, {-6, -45}, {6, -45}, {25, -39}, {37, -32},
	{48, -21}, {49, -15}, {49, 16}, {46, 21}, {30, 38}, {6, 45}, {-6, 45}, {-25, 39},
	{-37, 32}, {-48, 21}, {-49, 15}}

-- The road: |lx| <= ROAD.half_width at the datum from the south mouth to the
-- north mouth; outside them the middle road leaves straight along the axis
-- (`road_layout.lua`, the mouth nodes).
M.ROAD = {half_width = 3, min_z = -45, max_z = 45}
M.MOUTHS = {
	{id = "north", x = 0, z = 45, dz = 1},
	{id = "south", x = 0, z = -45, dz = -1},
}

-- The two halls (the draft's templates `breach_accord.tpl`, `breach_throng.tpl`,
-- placed as `sites.py` Site.place does: x = +-(42 - u), z = -+v, y = 6 + the
-- template's y). Local boxes, inclusive: `interior` the closed room behind the
-- sills (template u 1..11, v -14..14, the air above the floor up to the
-- roof's underside), `floor` its floor layer; `waystone` the marker's base
-- cell (template u 4, y 1, v 0), `arrival` the arrival socket (u 5, y 1, v 0),
-- `muster` the muster point (u 6, y 1, v 0).
local function hall(sign)
	local function x(u) return sign * (42 - u) end
	local x1, x2 = x(1), x(11)
	return {
		floor_y = 6,
		interior = {min = {x = math.min(x1, x2), y = 7, z = -14},
			max = {x = math.max(x1, x2), y = 13, z = 14}},
		waystone = {x = x(4), y = 7, z = 0},
		arrival = {x = x(5), y = 7, z = 0},
		muster = {x = x(6), y = 7, z = 0},
	}
end
M.HALLS = {accord = hall(1), throng = hall(-1)}

-- The two smoke hearths (`sites.py` field: the basalt at (+-7, 0, +-16); the
-- puffs rise from 0.75 above the road surface, REPORT.md §3).
M.HEARTHS = {
	{id = "east", x = 7, y = 0, z = 16, smoke_y = 0.75},
	{id = "west", x = -7, y = 0, z = -16, smoke_y = 0.75},
}

-- The protected box's height above the datum: the halls' tallest towers
-- (the templates' 19 layers on the +6 floor) and 10 nodes of air above, the
-- world protection's box rule (`world_protection.lua` BOX_ABOVE); below,
-- its BOX_BELOW.
M.BOX_ABOVE, M.BOX_BELOW = 6 + 19 + 10, 10

-- Inside or on the edge of the footprint polygon (integer columns).
local function on_segment(px, pz, x1, z1, x2, z2)
	if (x2 - x1) * (pz - z1) - (z2 - z1) * (px - x1) ~= 0 then return false end
	return px >= math.min(x1, x2) and px <= math.max(x1, x2) and
		pz >= math.min(z1, z2) and pz <= math.max(z1, z2)
end
function M.inside(lx, lz)
	if lx < -M.HALF_X or lx > M.HALF_X or lz < -M.HALF_Z or lz > M.HALF_Z then return false end
	local n, odd = #POLYGON, false
	for index = 1, n do
		local a, b = POLYGON[index], POLYGON[index % n + 1]
		local x1, z1, x2, z2 = a[1], a[2], b[1], b[2]
		if on_segment(lx, lz, x1, z1, x2, z2) then return true end
		-- the edge crosses the row lz right of the column (exact integers;
		-- a column on the edge has answered above)
		if (z1 > lz) ~= (z2 > lz) and
				(((lx - x1) * (z2 - z1) < (x2 - x1) * (lz - z1)) == (z2 > z1)) then
			odd = not odd
		end
	end
	return odd
end

-- Inside or on the hull (any local point).
function M.in_hull(lx, lz)
	local n = #M.HULL
	for index = 1, n do
		local a, b = M.HULL[index], M.HULL[index % n + 1]
		if (b[1] - a[1]) * (lz - a[2]) - (b[2] - a[2]) * (lx - a[1]) < 0 then return false end
	end
	return true
end

-- The hull's edges with their arc start, and its perimeter.
local EDGES, PERIMETER = {}, 0
for index = 1, #M.HULL do
	local a, b = M.HULL[index], M.HULL[index % #M.HULL + 1]
	local vx, vz = b[1] - a[1], b[2] - a[2]
	local length = math.sqrt(vx * vx + vz * vz)
	EDGES[index] = {x = a[1], z = a[2], vx = vx, vz = vz, l2 = vx * vx + vz * vz,
		length = length, s = PERIMETER, nx = vz / length, nz = -vx / length}
	PERIMETER = PERIMETER + length
end
M.HULL_EDGES, M.PERIMETER = EDGES, PERIMETER

-- A local point outside the hull: its distance to the hull and the arc
-- position (0 .. PERIMETER, counter-clockwise from the first vertex) of its
-- nearest hull point. Inside or on the hull: 0 and nil.
function M.hull_project(lx, lz)
	if M.in_hull(lx, lz) then return 0, nil end
	local best, arc = math.huge, 0
	for index = 1, #EDGES do
		local e = EDGES[index]
		local u = ((lx - e.x) * e.vx + (lz - e.z) * e.vz) / e.l2
		if u < 0 then u = 0 elseif u > 1 then u = 1 end
		local dx, dz = lx - e.x - u * e.vx, lz - e.z - u * e.vz
		local d2 = dx * dx + dz * dz
		if d2 < best then best, arc = d2, e.s + u * e.length end
	end
	return math.sqrt(best), arc
end

-- The hull point at arc position s and the outward normal of its edge.
function M.hull_point(s)
	s = s % PERIMETER
	for index = #EDGES, 1, -1 do
		local e = EDGES[index]
		if s >= e.s then
			local u = (s - e.s) / e.length
			return e.x + u * e.vx, e.z + u * e.vz, e.nx, e.nz
		end
	end
end

-- The site's line in a placement text: "breach <x> <z> <datum> <reach>"
-- (integers; reach is the widest blend beyond the hull, `breach_site.lua`).
function M.format(site)
	return ("breach %d %d %d %d"):format(site.x, site.z, site.y, site.reach)
end
function M.parse(line)
	local x, z, y, reach = (line or ""):match("^breach (%-?%d+) (%-?%d+) (%-?%d+) (%d+)$")
	if not x then return nil end
	return {x = tonumber(x), z = tonumber(z), y = tonumber(y), reach = tonumber(reach)}
end
-- The site of a world from its placement text (its last line).
function M.from_placement(text)
	assert(type(text) == "string", "breach layout: placement text missing")
	local last = text:match("([^\n]+)\n?$")
	local site = M.parse(last)
	assert(site, "breach layout: the placement text names no site")
	return site
end

-- Everything in world coordinates (inclusive boxes {min = {x, y, z}, max =}).
--   centre, datum         the site and its road surface node y
--   footprint             the polygon's bounds; `inside(x, z)` its columns
--   levelled              the hull's bounds (flat at the datum)
--   protected             the footprint's bounds from BOX_BELOW under the
--                         datum to BOX_ABOVE over it
--   fringe                the levelled ground and its blend: the hull's
--                         bounds grown by the site's reach, the same heights
--   halls[faction]        interior, floor_y, waystone, arrival, muster
--   mouths                north and south road ends {x, y, z, dz}
--   road                  {x, y, min_z, max_z, half_width}: the straight
--                         inner segment between the mouths
--   hearths               {x, y, z, smoke_y}
function M.world(site)
	local cx, cz, y = site.x, site.z, site.y
	local function point(p) return {x = cx + p.x, y = y + p.y, z = cz + p.z} end
	local function box(b) return {min = point(b.min), max = point(b.max)} end
	local out = {id = M.ID, name = M.NAME, centre = {x = cx, z = cz}, datum = y,
		reach = site.reach}
	out.footprint = box({min = {x = -M.HALF_X, y = 0, z = -M.HALF_Z},
		max = {x = M.HALF_X, y = 0, z = M.HALF_Z}})
	function out.inside(x, z) return M.inside(x - cx, z - cz) end
	out.levelled = out.footprint
	out.protected = box({min = {x = -M.HALF_X, y = -M.BOX_BELOW, z = -M.HALF_Z},
		max = {x = M.HALF_X, y = M.BOX_ABOVE, z = M.HALF_Z}})
	out.fringe = box({min = {x = -M.HALF_X - site.reach, y = 0, z = -M.HALF_Z - site.reach},
		max = {x = M.HALF_X + site.reach, y = 0, z = M.HALF_Z + site.reach}})
	out.halls = {}
	for faction, h in pairs(M.HALLS) do
		out.halls[faction] = {floor_y = y + h.floor_y, interior = box(h.interior),
			waystone = point(h.waystone), arrival = point(h.arrival), muster = point(h.muster)}
	end
	out.mouths = {}
	for index, m in ipairs(M.MOUTHS) do
		out.mouths[index] = {id = m.id, x = cx + m.x, y = y, z = cz + m.z, dz = m.dz}
	end
	out.road = {x = cx, y = y, min_z = cz + M.ROAD.min_z, max_z = cz + M.ROAD.max_z,
		half_width = M.ROAD.half_width}
	out.hearths = {}
	for index, h in ipairs(M.HEARTHS) do
		out.hearths[index] = {id = h.id, x = cx + h.x, y = y + h.y, z = cz + h.z,
			smoke_y = y + h.smoke_y}
	end
	return out
end

return M
