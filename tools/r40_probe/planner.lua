-- Round 40 lane V4: the planned Charge path (round40-plan.md §3.3, "Option:
-- a planned path"). PURE Lua: the map is read only through `boxes(x, y, z)`
-- (a node's collision boxes, node-relative, or nil when passable -- the same
-- contract as grug_abilities/blink.lua's `world.boxes`), so the portable
-- fixture runs the real planner against built test geometry.
--
-- The ground is sampled ONCE at the cast along the horizontal line from the
-- caster's feet to the destination: every `sample` metres the highest feet
-- height within reach (at most `max_rise` above and `max_drop` below the
-- previous sample) where the player box fits and stands. Level stretches
-- become runs (one velocity, no acceleration); every edge (a step, a slope,
-- a low obstacle, a drop) becomes a ballistic hop from a takeoff before the
-- edge to a landing after it (one velocity and one acceleration, so a client
-- extrapolating pos += v*dt + a*dt*dt/2 draws the arc without help). A hop
-- is solved from its apex: the arc clears the highest ground under it by
-- `clear`; when the box would still touch something on the way, the apex
-- rises in 0.25 m steps and then the takeoff moves back. Where no sample
-- fits (a wall higher than `max_rise`, a drop deeper than `max_drop`) or no
-- hop clears, the path runs up to the edge and is cut short there; a cut
-- path shorter than `min_move` is refused.

local planner = {}

local floor, ceil, abs, sqrt = math.floor, math.ceil, math.abs, math.sqrt
local min, max = math.min, math.max
local EPS = 0.001

planner.DEFAULTS = {
	speed = 16,       -- m/s along the ground (the dash speed)
	sample = 0.25,    -- metres between ground samples
	half = 0.3,       -- player box half width (collisionbox x/z)
	height = 1.7,     -- player box height
	max_rise = 1.6,   -- highest rise between two samples the path accepts
	max_drop = 4.0,   -- deepest drop between two samples
	clear = 0.35,     -- apex clearance above the highest ground under a hop
	apex_extra = 1.5, -- how far the apex may rise above that before giving up
	hop_pre = 0.75,   -- takeoff this far before an edge
	hop_post = 0.5,   -- landing this far after it
	max_hop = 6.0,    -- longest single hop, horizontal metres
	bump = 2.0,       -- an obstacle at most this long (box width included) is hopped over whole
	g_max = 50,       -- a hop steeper than this is lengthened while it can be
	hop_speed = 1.0,  -- horizontal speed in a hop, as a fraction of `speed`
	min_move = 1.5,   -- a cut path shorter than this is refused (blink.lua)
	flat = 0.05,      -- height change between samples that still counts as level
	arc_step = 0.1,   -- horizontal metres between arc clearance checks
}

local function options(opts)
	local o = {}
	for k, v in pairs(planner.DEFAULTS) do o[k] = v end
	for k, v in pairs(opts or {}) do o[k] = v end
	return o
end

-- Every node is read once per plan: samples 0.25 m apart with a 0.6 m box
-- visit the same nodes again and again.
local function cached(boxes)
	local cache, stats = {}, {reads = 0, unique = 0}
	local function query(x, y, z)
		stats.reads = stats.reads + 1
		local key = ((z + 32768) * 65536 + (y + 32768)) * 65536 + (x + 32768)
		local hit = cache[key]
		if hit == nil then
			stats.unique = stats.unique + 1
			hit = boxes(x, y, z) or false
			cache[key] = hit
		end
		return hit or nil
	end
	return query, stats
end

-- Highest top of any solid box overlapping the player box with its feet at
-- (x, y, z); nil when the box is free. Faces that merely touch do not
-- overlap. One extra node row below is read because node boxes may reach up
-- out of their node (blink.lua's blocking_top, same rule).
local function overlap_top(q, o, x, y, z)
	local x1, x2 = x - o.half + EPS, x + o.half - EPS
	local y1, y2 = y + EPS, y + o.height - EPS
	local z1, z2 = z - o.half + EPS, z + o.half - EPS
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
planner.overlap_top = overlap_top

-- The highest feet height in [y_lo, y_hi] where the box stands on a solid top
-- under its footprint and overlaps nothing; nil when there is none.
local function stand_height(q, o, x, z, y_hi, y_lo)
	local x1, x2 = x - o.half + EPS, x + o.half - EPS
	local z1, z2 = z - o.half + EPS, z + o.half - EPS
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
	for _, t in ipairs(tops) do
		if not overlap_top(q, o, x, t, z) then
			return t
		end
	end
	return nil
end

-- A straight segment list for the non-planned carrier: one velocity from the
-- feet to the destination, through whatever lies between.
function planner.straight(from, dest, speed)
	local d = sqrt((dest.x - from.x) * (dest.x - from.x) +
		(dest.y - from.y) * (dest.y - from.y) + (dest.z - from.z) * (dest.z - from.z))
	local t = d / speed
	local v = t > 0 and {x = (dest.x - from.x) / t, y = (dest.y - from.y) / t,
		z = (dest.z - from.z) / t} or {x = 0, y = 0, z = 0}
	return {
		segments = {{kind = "line", t0 = 0, t = t, len = d,
			p0 = {x = from.x, y = from.y, z = from.z}, v = v, a = {x = 0, y = 0, z = 0}}},
		total = t, dist = d, finish = {x = dest.x, y = dest.y, z = dest.z},
	}
end

-- Plan the path. Returns the plan, or nil and a reason. The plan:
--   segments  list of {kind = "run"|"hop", t0, t, len, p0, v, a[, apex, rise, g]}
--   total     seconds; dist: horizontal metres covered; finish: end feet
--   cut       true when cut short (cut_at: metres along the line, cut_why)
--   samples, reads, unique  (the planning cost in node reads)
function planner.plan(boxes, from, dest, opts)
	local o = options(opts)
	local q, stats = cached(boxes)
	local dx, dz = dest.x - from.x, dest.z - from.z
	local span = sqrt(dx * dx + dz * dz)
	local ux, uz = 0, 0
	if span > EPS then ux, uz = dx / span, dz / span end
	local n = max(1, ceil(span / o.sample - EPS))
	local xs, hs = {[0] = 0}, {[0] = from.y}
	local e, cut_at, cut_why = n, nil, nil
	for k = 1, n do
		local d = min(k * o.sample, span)
		xs[k] = d
		local g = stand_height(q, o, from.x + ux * d, from.z + uz * d,
			hs[k - 1] + o.max_rise, hs[k - 1] - o.max_drop)
		if not g then
			e, cut_at, cut_why = k - 1, d, "no ground within reach"
			break
		end
		hs[k] = g
	end

	local function flat(k)
		return abs(hs[k + 1] - hs[k]) <= o.flat
	end
	local u = o.speed * o.hop_speed
	local function arc_clear(a, b, vy, g, t_hop)
		local steps = max(1, ceil((xs[b] - xs[a]) / o.arc_step))
		for s = 1, steps do
			local t = t_hop * s / steps
			local x = xs[a] + u * t
			if overlap_top(q, o, from.x + ux * x, hs[a] + vy * t - 0.5 * g * t * t,
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
		local t_hop = len / u
		local top = max(hs[a], hs[b])
		for k = a + 1, b - 1 do top = max(top, hs[k]) end
		local dy = hs[b] - hs[a]
		local apex = top - hs[a] + o.clear
		local limit = apex + o.apex_extra
		while apex <= limit + EPS do
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

	local pre = ceil(o.hop_pre / o.sample - EPS)
	local post = ceil(o.hop_post / o.sample - EPS)
	local longest = max(1, floor(o.max_hop / o.sample + EPS))
	local parts = {}
	local i, run_start = 0, 0
	while i < e do
		if flat(i) then
			i = i + 1
		else
			local a = max(run_start, i - pre)
			local b = min(e, i + 1 + post)
			local up = hs[i + 1] > hs[i]
			local bumped, keep_b = false, false
			-- A low obstacle (the ground comes back down within `bump`) is
			-- one hop over it, not a hop onto it and another one off.
			if up then
				for j = i + 2, min(e, i + 1 + ceil(o.bump / o.sample - EPS)) do
					if hs[j] <= hs[i] + o.flat then
						b, bumped = max(b, min(e, j + post)), true
						break
					end
				end
			end
			if not bumped then
				-- Stairs: further edges the same way, with treads shorter
				-- than half a hop between them, join one climb (or descent),
				-- flown as equal hops of at most `max_hop` each.
				local c, j = i + 1, i + 1
				while j < e do
					if not flat(j) then
						if (hs[j + 1] > hs[j]) ~= up then break end
						c = j + 1
					elseif xs[j] - xs[c] > o.max_hop / 2 then
						break
					end
					j = j + 1
				end
				local land = min(e, c + post)
				b = max(b, a + ceil((land - a) / ceil((land - a) / longest)))
				-- More hops of this climb follow: lengthening must not steal
				-- from them.
				keep_b = b < land
			end
			local hop
			while true do
				hop = make_hop(a, b)
				if hop or a <= run_start then break end
				a = a - 1
			end
			-- At dash speed a short hop needs an absurd gravity: lengthen it
			-- (takeoff earlier going up, landing later going down) while the
			-- longer arc still clears and stays within `max_hop`.
			while hop and hop.g > o.g_max and b - a < longest do
				-- Up: an earlier takeoff; down: a later landing; level (a
				-- bump): both in turn, so the obstacle stays mid-arc.
				local na, nb = a, b
				local rising = hop.rise > o.flat or
					(hop.rise >= -o.flat and (b - a) % 2 == 0)
				if rising and a > run_start then na = a - 1
				elseif b < e and flat(b) and not keep_b then nb = b + 1
				elseif a > run_start then na = a - 1
				else break end
				local longer = make_hop(na, nb)
				if not longer then break end
				hop, a, b = longer, na, nb
			end
			if not hop then
				-- Run up to the edge and stop there (the box fits at i).
				cut_at, cut_why = xs[i + 1], "no hop clears the edge"
				e = i
				break
			end
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
	if cut_at and xs[e] < o.min_move then
		return nil, ("refused: %s (blocked %.2f m out, shorter than %.1f m)"):format(
			cut_why, cut_at, o.min_move)
	end

	local segments, t0 = {}, 0
	for _, p in ipairs(parts) do
		local p0 = {x = from.x + ux * xs[p.i], y = hs[p.i], z = from.z + uz * xs[p.i]}
		local seg
		if p.kind == "run" then
			local len = xs[p.j] - xs[p.i]
			local t = len / o.speed
			seg = {kind = "run", t = t, len = len, p0 = p0,
				v = {x = ux * o.speed, y = t > 0 and (hs[p.j] - hs[p.i]) / t or 0,
					z = uz * o.speed},
				a = {x = 0, y = 0, z = 0}}
		else
			seg = {kind = "hop", t = p.t, len = p.len, p0 = p0,
				v = {x = ux * u, y = p.vy, z = uz * u}, a = {x = 0, y = -p.g, z = 0},
				apex = p.apex, rise = p.rise, g = p.g}
		end
		seg.t0 = t0
		t0 = t0 + seg.t
		segments[#segments + 1] = seg
	end
	return {
		segments = segments, total = t0, dist = xs[e],
		finish = {x = from.x + ux * xs[e], y = hs[e], z = from.z + uz * xs[e]},
		cut = cut_at ~= nil, cut_at = cut_at, cut_why = cut_why,
		samples = n, reads = stats.reads, unique = stats.unique,
	}
end

-- The planned position, velocity and acceleration `t` seconds after the
-- cast; `index` is the segment that holds t (the last one past the end).
function planner.state_at(plan, t)
	local segs = plan.segments
	local index = #segs
	for k = 1, #segs do
		if t < segs[k].t0 + segs[k].t then index = k break end
	end
	local s = segs[index]
	if not s then return nil end
	local dt = min(max(t - s.t0, 0), s.t)
	local p = {
		x = s.p0.x + s.v.x * dt + 0.5 * s.a.x * dt * dt,
		y = s.p0.y + s.v.y * dt + 0.5 * s.a.y * dt * dt,
		z = s.p0.z + s.v.z * dt + 0.5 * s.a.z * dt * dt,
	}
	local v = {x = s.v.x + s.a.x * dt, y = s.v.y + s.a.y * dt, z = s.v.z + s.a.z * dt}
	return p, v, s.a, index
end

-- One line per segment for the chat report.
function planner.describe(plan)
	local out = {}
	for _, s in ipairs(plan.segments) do
		if s.kind == "hop" then
			out[#out + 1] = ("hop %+.2f m over %.2f m in %.2f s (apex %.2f, g %.0f)"):format(
				s.rise, s.len, s.t, s.apex, s.g)
		else
			out[#out + 1] = ("%s %.2f m in %.2f s"):format(s.kind, s.len, s.t)
		end
	end
	return table.concat(out, " | ")
end

return planner
