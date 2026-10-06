-- The planned path of Charge's dash (Round 40, round40-plan.md §3.3 "Option:
-- a planned path", rulings §2.3 and §2.16; started from the reviewed probe
-- tools/r40_probe/planner.lua). Pure Lua like blink.lua: the map is read
-- only through `world.boxes(x, y, z)` (a node's collision boxes,
-- node-relative, or nil when passable) and `world.liquid(x, y, z)` (true for
-- a liquid node), so the portable fixture runs the real planner against
-- built geometry. Returns {plan = function, state_at = function, live = world}.
--
-- The ground is sampled ONCE at the cast along the horizontal line from the
-- caster's feet to the destination: every SAMPLE metres the highest feet
-- height within reach (at most MAX_RISE above and MAX_DROP below the
-- previous sample) where the player box fits, stands on a solid top and does
-- not stand in a liquid (liquids count as air: never ground). Level
-- stretches become runs (one velocity, no acceleration); every edge (a step,
-- a slope, a low obstacle, a drop) becomes a ballistic hop from a takeoff
-- before the edge to a landing after it (one velocity and one acceleration:
-- the client extrapolates pos += v*dt + a*dt*dt/2). A hop is solved from its
-- apex: the arc clears the highest ground under it by CLEAR; when the box
-- would still touch something on the way, the apex rises in 0.25 m steps and
-- then the takeoff moves back.
--
-- Holes (the user's ruling §2.16): where the ground ahead drops away -- no
-- ground within reach, a liquid, or ground lower than the rim -- and comes
-- back within MAX_GAP metres (rim to far rim, a hole of up to 4 nodes) at
-- most one node above the rim, the hole is crossed in ONE hop whatever its
-- depth; shallow dips are jumped too. A hole that does not come back that
-- way is not crossed: with no ground within reach the path stops at its
-- rim; a dip with ground in reach is followed down (a ledge, a wide dip);
-- and a path that then cannot climb out (cut while still below the rim of a
-- drop deeper than MAX_RISE) stops at that rim instead. A stop short of the
-- destination is the caller's miss rule, never a refusal: the path is always
-- planned (it may be empty).

local floor, ceil, abs, sqrt = math.floor, math.ceil, math.abs, math.sqrt
local min, max = math.min, math.max
local EPS = 0.001

local SPEED = 24       -- m/s along the ground (the user's pick, §2.16)
local SAMPLE = 0.25    -- metres between ground samples
local HALF = 0.3       -- player box half width (collisionbox x/z)
local HEIGHT = 1.7     -- player box height
local MAX_RISE = 1.6   -- highest rise between two samples (a low wall, a step)
local MAX_DROP = 4.0   -- deepest drop between two samples the path follows
local MAX_GAP = 4.0    -- a hole is jumped when rim to far rim is at most this
local LAND_RISE = 1.0  -- ... and the far rim at most this above the rim
local CLEAR = 0.35     -- apex clearance above the highest ground under a hop
local APEX_EXTRA = 1.5 -- how far the apex may rise above that before giving up
local HOP_PRE = 0.75   -- takeoff this far before an edge
local HOP_POST = 0.5   -- landing this far after it
local MAX_HOP = 6.0    -- longest single hop, horizontal metres
local BUMP = 2.0       -- an obstacle at most this long is hopped over whole
local G_MAX = 50       -- a hop steeper than this is lengthened while it can be
local FLAT = 0.05      -- height change between samples that still counts as level
local ARC_STEP = 0.1   -- horizontal metres between arc clearance checks

-- Every node is read once per plan: samples 0.25 m apart with a 0.6 m box
-- visit the same nodes again and again.
local function cached(world)
	local boxes, liquid = {}, {}
	local stats = {reads = 0, unique = 0}
	local function key(x, y, z)
		return ((z + 32768) * 65536 + (y + 32768)) * 65536 + (x + 32768)
	end
	local function q(x, y, z)
		stats.reads = stats.reads + 1
		local k = key(x, y, z)
		local hit = boxes[k]
		if hit == nil then
			stats.unique = stats.unique + 1
			hit = world.boxes(x, y, z) or false
			boxes[k] = hit
		end
		return hit or nil
	end
	local function wet(x, y, z)
		if not world.liquid then return false end
		local k = key(x, y, z)
		local hit = liquid[k]
		if hit == nil then
			hit = world.liquid(x, y, z) == true
			liquid[k] = hit
		end
		return hit
	end
	return q, wet, stats
end

-- Highest top of any solid box overlapping the player box with its feet at
-- (x, y, z); nil when the box is free. Faces that merely touch do not
-- overlap. One extra node row below is read because node boxes may reach up
-- out of their node (blink.lua's blocking_top, same rule).
local function overlap_top(q, x, y, z)
	local x1, x2 = x - HALF + EPS, x + HALF - EPS
	local y1, y2 = y + EPS, y + HEIGHT - EPS
	local z1, z2 = z - HALF + EPS, z + HALF - EPS
	local top
	for nx = floor(x1 + 0.5), floor(x2 + 0.5) do
		for ny = floor(y1 + 0.5) - 1, floor(y2 + 0.5) do
			for nz = floor(z1 + 0.5), floor(z2 + 0.5) do
				local boxes = q(nx, ny, nz)
				if boxes then
					for _, b in ipairs(boxes) do
						local by2 = ny + max(b[2], b[5])
						if ny + min(b[2], b[5]) < y2 and by2 > y1 and
								nx + min(b[1], b[4]) < x2 and nx + max(b[1], b[4]) > x1 and
								nz + min(b[3], b[6]) < z2 and nz + max(b[3], b[6]) > z1 and
								(not top or by2 > top) then
							top = by2
						end
					end
				end
			end
		end
	end
	return top
end

-- The highest feet height in [y_lo, y_hi] where the box stands on a solid top
-- under its footprint, overlaps nothing and its feet are not in a liquid;
-- nil when there is none.
local function stand_height(q, wet, x, z, y_hi, y_lo)
	local x1, x2 = x - HALF + EPS, x + HALF - EPS
	local z1, z2 = z - HALF + EPS, z + HALF - EPS
	local tops, seen = {}, {}
	for nx = floor(x1 + 0.5), floor(x2 + 0.5) do
		for nz = floor(z1 + 0.5), floor(z2 + 0.5) do
			for ny = floor(y_hi + 0.5), floor(y_lo + 0.5) - 2, -1 do
				local boxes = q(nx, ny, nz)
				if boxes then
					for _, b in ipairs(boxes) do
						local t = ny + max(b[2], b[5])
						if t <= y_hi + EPS and t >= y_lo - EPS and not seen[t] and
								nx + min(b[1], b[4]) < x2 and nx + max(b[1], b[4]) > x1 and
								nz + min(b[3], b[6]) < z2 and nz + max(b[3], b[6]) > z1 then
							seen[t] = true
							tops[#tops + 1] = t
						end
					end
				end
			end
		end
	end
	table.sort(tops, function(a, b) return a > b end)
	local cx, cz = floor(x + 0.5), floor(z + 0.5)
	for _, t in ipairs(tops) do
		if not overlap_top(q, x, t, z) then
			-- Liquids are air: a spot whose feet are in one is no ground, and
			-- every lower spot in the column is under it.
			if wet(cx, floor(t + EPS + 0.5), cz) then return nil end
			return t
		end
	end
	return nil
end

-- Plan the path from the feet `from` to the feet `dest`. The plan:
--   segments  list of {kind = "run"|"hop", t0, t, len, p0, v, a[, apex, rise, g]}
--   total     seconds; dist: horizontal metres covered; finish: end feet
--   cut       true when it stops short (cut_at: metres along the line,
--             cut_why); jumps: holes crossed in one hop
--   samples, reads, unique  (the planning cost in node reads)
local function plan(world, from, dest, speed)
	speed = speed or SPEED
	local q, wet, stats = cached(world)
	local dx, dz = dest.x - from.x, dest.z - from.z
	local span = sqrt(dx * dx + dz * dz)
	local ux, uz = 0, 0
	if span > EPS then ux, uz = dx / span, dz / span end
	local n = max(1, ceil(span / SAMPLE - EPS))
	local xs, hs = {[0] = 0}, {[0] = from.y}
	local function x_at(k) return min(k * SAMPLE, span) end
	local function ground(k, y_hi, y_lo)
		local d = x_at(k)
		return stand_height(q, wet, from.x + ux * d, from.z + uz * d, y_hi, y_lo)
	end

	-- The far rim of a hole that starts after the rim sample r: the first
	-- sample within MAX_GAP whose ground is back at the rim's level (at most
	-- LAND_RISE above it) or, past a part with no ground at all, higher than
	-- everything since the rim. Returns its index and height, plus the
	-- heights of the samples between (nil where there is no ground). A
	-- sample where the box at the rim's height runs into something higher
	-- than the far rim may be is a wall, not a hole: no far rim.
	local function far_rim(r)
		local base, low, deep, between = hs[r], -math.huge, false, {}
		for j = r + 1, n do
			local d = x_at(j)
			if d - xs[r] > MAX_GAP + EPS then return nil end
			local g = ground(j, base + LAND_RISE, base - MAX_DROP)
			if g and j > r + 1 and (g >= base - FLAT or (deep and g > low + FLAT)) then
				return j, g, between
			end
			if not g then
				local top = overlap_top(q, from.x + ux * d, base, from.z + uz * d)
				if top and top > base + LAND_RISE + EPS then return nil end
			end
			if g then low = max(low, g) else deep = true end
			between[j] = g or false
		end
		return nil
	end

	local e, cut_at, cut_why = n, nil, nil
	local jump, hole = {}, {} -- rim index -> far rim index; samples inside a hole
	local pit, pit_level -- the rim of the last drop the path could not climb back
	local pit_at = {[0] = false} -- that rim as it stood at each sample
	local k = 1
	while k <= n do
		xs[k] = x_at(k)
		local prev = hs[k - 1]
		local g = ground(k, prev + MAX_RISE, prev - MAX_DROP)
		local j, gj, between
		if not g or g < prev - FLAT then
			j, gj, between = far_rim(k - 1)
		end
		if j then
			-- One hop over the hole: the samples in between keep their
			-- ground (or lie deep below the rim) only for the arc's apex.
			for m = k, j - 1 do
				xs[m] = x_at(m)
				hs[m] = between[m] or (prev - MAX_DROP)
				hole[m] = true
			end
			jump[k - 1] = j
			xs[j], hs[j] = x_at(j), gj
			if pit and gj >= pit_level - FLAT then pit = nil end
			for m = k, j do pit_at[m] = pit or false end
			k = j + 1
		elseif not g then
			-- No ground within reach and no far rim: stop at the rim, or at
			-- the rim of the drop the path could not climb out of.
			e, cut_at, cut_why = k - 1, xs[k], "no ground within reach"
			if pit and prev < pit_level - FLAT then
				e, cut_why = pit, "cannot climb out of the drop"
				cut_at = xs[pit + 1]
			end
			break
		else
			hs[k] = g
			if g < prev - MAX_RISE then
				pit, pit_level = k - 1, prev
			elseif pit and g >= pit_level - FLAT then
				pit = nil
			end
			pit_at[k] = pit or false
			k = k + 1
		end
	end

	local function flat(i)
		return abs(hs[i + 1] - hs[i]) <= FLAT
	end
	-- The first rim at or after i (a hop must never land inside a hole).
	local function limit(i)
		for r = i, e - 1 do
			if jump[r] then return r end
		end
		return e
	end
	local function arc_clear(a, b, vy, g, t_hop)
		local steps = max(1, ceil((xs[b] - xs[a]) / ARC_STEP))
		for s = 1, steps do
			local t = t_hop * s / steps
			local x = xs[a] + speed * t
			if overlap_top(q, from.x + ux * x, hs[a] + vy * t - 0.5 * g * t * t,
					from.z + uz * x) then
				return false
			end
		end
		return true
	end
	-- Apex height h above the takeoff, rise dy, flight time T: the parabola
	-- through both ends with its top h above the start has
	-- vy = 2h/T * (1 + sqrt(1 - dy/h)) and g = vy^2 / 2h (h > dy always).
	local function make_hop(a, b)
		local len = xs[b] - xs[a]
		if len < EPS then return nil end
		local t_hop = len / speed
		local top = max(hs[a], hs[b])
		for m = a + 1, b - 1 do top = max(top, hs[m]) end
		local dy = hs[b] - hs[a]
		local apex = top - hs[a] + CLEAR
		local ceiling = apex + APEX_EXTRA
		while apex <= ceiling + EPS do
			local r = sqrt(max(0, 1 - dy / apex))
			local vy = 2 * apex / t_hop * (1 + r)
			local g = vy * vy / (2 * apex)
			if arc_clear(a, b, vy, g, t_hop) then
				return {kind = "hop", i = a, j = b, len = len, t = t_hop,
					vy = vy, g = g, apex = apex, rise = dy}
			end
			apex = apex + 0.25
		end
		return nil
	end

	local pre = ceil(HOP_PRE / SAMPLE - EPS)
	local post = ceil(HOP_POST / SAMPLE - EPS)
	local longest = max(1, floor(MAX_HOP / SAMPLE + EPS))
	local parts, jumps = {}, 0
	local i, run_start = 0, 0
	while i < e do
		if not jump[i] and flat(i) then
			i = i + 1
		else
			local a, b, keep_b
			local up = hs[i + 1] > hs[i]
			if jump[i] then
				-- A hole: rim to far rim, lengthened below like any hop.
				a, b, keep_b = i, jump[i], false
			else
				a = max(run_start, i - pre)
				b = min(limit(i + 1), i + 1 + post)
				local bumped = false
				-- A low obstacle (the ground comes back down within BUMP) is
				-- one hop over it, not a hop onto it and another one off.
				if up then
					for j = i + 2, min(limit(i + 1), i + 1 + ceil(BUMP / SAMPLE - EPS)) do
						if hs[j] <= hs[i] + FLAT then
							b, bumped = max(b, min(limit(i + 1), j + post)), true
							break
						end
					end
				end
				keep_b = false
				if not bumped then
					-- Stairs: further edges the same way, with treads shorter
					-- than half a hop between them, join one climb (or
					-- descent), flown as equal hops of at most MAX_HOP each.
					local stop = limit(i + 1)
					local c, j = i + 1, i + 1
					while j < stop do
						if not flat(j) then
							if (hs[j + 1] > hs[j]) ~= up then break end
							c = j + 1
						elseif xs[j] - xs[c] > MAX_HOP / 2 then
							break
						end
						j = j + 1
					end
					local land = min(stop, c + post)
					b = max(b, min(land, a + ceil((land - a) / ceil((land - a) / longest))))
					-- More hops of this climb follow: lengthening must not
					-- steal from them.
					keep_b = b < land
				end
			end
			local hop
			while true do
				hop = make_hop(a, b)
				if hop or a <= run_start then break end
				a = a - 1
			end
			-- At dash speed a short hop needs an absurd gravity: lengthen it
			-- (takeoff earlier going up, landing later going down; a level
			-- hop both in turn, so the obstacle stays mid-arc) while the
			-- longer arc still clears and stays within MAX_HOP.
			-- A later landing keeps the level ground the next edge needs for
			-- its own run-up, half a hop (a wide dip: down, a run, up again).
			local stop = limit(b)
			local function room(at)
				local m = at
				while m < stop and flat(m) do m = m + 1 end
				return m >= e or m - (at + 1) >= longest / 2
			end
			while hop and hop.g > G_MAX and b - a < longest do
				local na, nb = a, b
				local rising = hop.rise > FLAT or
					(hop.rise >= -FLAT and (b - a) % 2 == 0)
				if rising and a > run_start then na = a - 1
				elseif b < stop and flat(b) and not keep_b and room(b) then nb = b + 1
				elseif a > run_start then na = a - 1
				else break end
				local longer = make_hop(na, nb)
				if not longer then break end
				hop, a, b = longer, na, nb
			end
			if not hop then
				-- Run up to the edge (or the rim) and stop there; down in a
				-- drop the path could not climb out of, at that drop's rim.
				cut_at, cut_why = xs[i + 1], "no hop clears the edge"
				e = i
				local r = pit_at[i]
				if r and hs[i] < hs[r] - FLAT then
					e, cut_at, cut_why = r, xs[r + 1], "cannot climb out of the drop"
					-- Keep only what lies before the rim; the hop over it
					-- (the way down) becomes a run to the rim: its takeoff
					-- lies on the level ground before that edge.
					local kept = {}
					for _, part in ipairs(parts) do
						if part.j <= e then
							kept[#kept + 1] = part
						else
							local last = kept[#kept]
							if last and last.kind == "run" and last.j == part.i then
								last.j = e
							elseif part.i < e then
								kept[#kept + 1] = {kind = "run", i = part.i, j = e}
							end
							break
						end
					end
					parts = kept
					run_start = #parts > 0 and parts[#parts].j or 0
				end
				break
			end
			if jump[i] then jumps = jumps + 1 end
			if a > run_start then
				parts[#parts + 1] = {kind = "run", i = run_start, j = a}
			end
			parts[#parts + 1] = hop
			i, run_start = b, b
		end
	end
	if e > run_start then
		parts[#parts + 1] = {kind = "run", i = run_start, j = e}
	end

	local segments, t0 = {}, 0
	for _, p in ipairs(parts) do
		local p0 = {x = from.x + ux * xs[p.i], y = hs[p.i], z = from.z + uz * xs[p.i]}
		local seg
		if p.kind == "run" then
			local len = xs[p.j] - xs[p.i]
			local t = len / speed
			seg = {kind = "run", t = t, len = len, p0 = p0,
				v = {x = ux * speed, y = t > 0 and (hs[p.j] - hs[p.i]) / t or 0,
					z = uz * speed},
				a = {x = 0, y = 0, z = 0}}
		else
			seg = {kind = "hop", t = p.t, len = p.len, p0 = p0,
				v = {x = ux * speed, y = p.vy, z = uz * speed}, a = {x = 0, y = -p.g, z = 0},
				apex = p.apex, rise = p.rise, g = p.g}
		end
		seg.t0 = t0
		t0 = t0 + seg.t
		segments[#segments + 1] = seg
	end
	return {
		segments = segments, total = t0, dist = xs[e],
		finish = {x = from.x + ux * xs[e], y = hs[e], z = from.z + uz * xs[e]},
		cut = cut_at ~= nil, cut_at = cut_at, cut_why = cut_why, jumps = jumps,
		samples = n, reads = stats.reads, unique = stats.unique,
	}
end

-- The planned position, velocity and acceleration `t` seconds after the
-- start; `index` is the segment that holds t (the last one past the end).
local function state_at(p, t)
	local segs = p.segments
	local index = #segs
	for k = 1, #segs do
		if t < segs[k].t0 + segs[k].t then index = k break end
	end
	local s = segs[index]
	if not s then return nil end
	local dt = min(max(t - s.t0, 0), s.t)
	local pos = {
		x = s.p0.x + s.v.x * dt + 0.5 * s.a.x * dt * dt,
		y = s.p0.y + s.v.y * dt + 0.5 * s.a.y * dt * dt,
		z = s.p0.z + s.v.z * dt + 0.5 * s.a.z * dt * dt,
	}
	local v = {x = s.v.x + s.a.x * dt, y = s.v.y + s.a.y * dt, z = s.v.z + s.a.z * dt}
	return pos, v, s.a, index
end

-- The live map: walkable nodes with their collision boxes, everything
-- unknown or unloaded solid (blink.lua's rule); liquids by their def.
local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
local LIVE = {
	boxes = function(x, y, z)
		local pos = {x = x, y = y, z = z}
		local node = core.get_node_or_nil(pos)
		if not node or node.name == "ignore" then return FULL end
		local def = core.registered_nodes[node.name]
		if not def then return FULL end
		if not def.walkable then return nil end
		return core.get_node_boxes("collision_box", pos, node)
	end,
	liquid = function(x, y, z)
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		local def = node and core.registered_nodes[node.name]
		return def ~= nil and (def.liquidtype or "none") ~= "none"
	end,
}

return {plan = plan, state_at = state_at, live = LIVE, SPEED = SPEED}
