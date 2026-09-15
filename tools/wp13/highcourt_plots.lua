-- Where a Highcourt district plot may stand, and where it may not.
--
--     luajit tools/wp13/highcourt_plots.lua <repo> <scan-a.tsv> <scan-b.tsv>
--     luajit tools/wp13/highcourt_plots.lua <repo> <scan-a.tsv> <scan-b.tsv> --sweep
--
-- The default run VERIFIES the positions `wp13/highcourt_district.lua`
-- currently carries, against every rule below, on both worlds at once. `--sweep`
-- additionally lists the best legal candidates per plot, which is how a plot
-- that has to move finds its new home.
--
-- WHY THIS IS A COMMITTED TOOL AND NOT A SCRATCH SCRIPT. The first version of
-- the seam package moved two plots with an ad-hoc sweep that asked one question
-- -- "where is the ground flattest?" -- and the answer inside a terraced capital
-- envelope is THE RIVER BED. Both plots landed in the water, on both gate seeds,
-- and nothing in the tree could say so: the surface probe measured terrain
-- height only, the composition KAT has no terrain at all, and the settlement
-- seam is deliberately water-agnostic. The predicate belongs in one place that
-- can be re-run and read, and this is it.
--
-- THE RULES, in the order they refuse:
--
--   1. DRY. Not one column of the plot's footprint may be water, and neither
--      may its two-node margin, and neither may its reference column. A plot
--      is not a pier.
--   2. STANDS ON ITS OWN GROUND. The fall under the plot's PERIMETER, measured
--      from its reference column, may not exceed the foundation skirt (6), on
--      either seed; the perimeter is what the skirt carries down.
--   3. FITS UNDER ITS OWN ROOF. The rise under the footprint may not exceed the
--      airspace the plot clears (its own `bounds.max.y`), on either seed.
--   4. INSIDE THE ENVELOPE, one node clear of the gate stations at +-256.
--   5. OFF THE CORE, off all four 32-node gate corridors, off all eight street
--      runs (carriageway plus verge), and one node clear of every other plot.
--
-- The scan TSVs come from `tools/wp13/run_highcourt.sh <out> scan <seed>`; the
-- two must be different seeds, which this tool checks by refusing two files
-- whose values are identical everywhere.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local scan_a = assert(arg[2], "first scan TSV required")
local scan_b = assert(arg[3], "second scan TSV required")
local sweep = arg[4] == "--sweep"

local SKIRT = 6
local MARGIN = 2
local GATE_CORRIDOR = 16      -- half of WP40's 32-node gate corridor
local ENVELOPE = 250          -- the 512 envelope, one node clear of the gates
local CORE = 48               -- the core's own +-47 plus a node of street

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local highcourt = dofile(wp13 .. "/highcourt.lua")(wp13)

local function read(path)
	local rows, count = {}, 0
	local file = assert(io.open(path, "r"), "cannot read " .. path)
	local header = file:read("*l")
	assert(header and header:find("submerged", 1, true),
		path .. " has no submerged column; re-run the scan with a probe that " ..
		"measures water")
	for line in file:lines() do
		local id, x, z, fall, rise, submerged, margin, wet_reference =
			line:match("^(%S+)\t(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t" ..
				"(%-?%d+)\t(%-?%d+)\t(%a+)")
		assert(id, "unreadable scan row: " .. line)
		rows[id] = rows[id] or {}
		rows[id][x .. ":" .. z] = {fall = tonumber(fall), rise = tonumber(rise),
			submerged = tonumber(submerged), margin = tonumber(margin),
			wet_reference = wet_reference == "true"}
		count = count + 1
	end
	file:close()
	assert(count > 0, path .. " is empty")
	return rows, count
end

local a, count_a = read(scan_a)
local b, count_b = read(scan_b)
assert(count_a == count_b, "the two scans do not cover the same grid")
do
	local differs = false
	for id, cells in pairs(a) do
		for key, row in pairs(cells) do
			local other = b[id] and b[id][key]
			assert(other, "the two scans do not cover the same grid")
			if other.fall ~= row.fall or other.submerged ~= row.submerged then
				differs = true
			end
		end
	end
	assert(differs, "the two scans are the same world; use two different seeds")
end

-- The plots, built once, with the footprint the ground fill actually covers.
local plots = {}
for index = 1, #highcourt.district.plots do
	local entry = highcourt.district.plots[index]
	local composition = entry.build()
	plots[index] = {id = entry.id, x = entry.x, z = entry.z,
		bounds = composition.bounds, clear_to = composition.bounds.max.y}
end

-- The eight street runs, carriageway plus a verge column either side: that is
-- the width the overlay actually writes.
local runs = {}
for _, list in ipairs({highcourt.avenues, highcourt.ring}) do
	for index = 1, #list do
		local run = list[index]
		local half = (avenue.WIDTH - 1) / 2 + 1
		if run.axis == "x" then
			runs[#runs + 1] = {id = run.id, min_x = run.from, max_x = run.to,
				min_z = run.at - half, max_z = run.at + half}
		else
			runs[#runs + 1] = {id = run.id, min_z = run.from, max_z = run.to,
				min_x = run.at - half, max_x = run.at + half}
		end
	end
end

local function overlaps(a1, a2, b1, b2) return a1 <= b2 and b1 <= a2 end

-- Geometry only: everything that can be decided without terrain.
local function geometry(plot, x, z, moving)
	local min_x, max_x = x + plot.bounds.min.x, x + plot.bounds.max.x
	local min_z, max_z = z + plot.bounds.min.z, z + plot.bounds.max.z
	if min_x < -ENVELOPE or max_x > ENVELOPE or min_z < -ENVELOPE or
			max_z > ENVELOPE then
		return false, "envelope"
	end
	if overlaps(min_x, max_x, -CORE, CORE) and
			overlaps(min_z, max_z, -CORE, CORE) then
		return false, "core"
	end
	if overlaps(min_z, max_z, -GATE_CORRIDOR, GATE_CORRIDOR) then
		return false, "gate_corridor_x"
	end
	if overlaps(min_x, max_x, -GATE_CORRIDOR, GATE_CORRIDOR) then
		return false, "gate_corridor_z"
	end
	for _, run in ipairs(runs) do
		if overlaps(min_x, max_x, run.min_x, run.max_x) and
				overlaps(min_z, max_z, run.min_z, run.max_z) then
			return false, "street:" .. run.id
		end
	end
	for _, other in ipairs(plots) do
		if other.id ~= moving and
				overlaps(min_x, max_x, other.x + other.bounds.min.x - 1,
					other.x + other.bounds.max.x + 1) and
				overlaps(min_z, max_z, other.z + other.bounds.min.z - 1,
					other.z + other.bounds.max.z + 1) then
			return false, "plot:" .. other.id
		end
	end
	return true
end

-- Terrain, on BOTH worlds. A position legal on one seed and not the other is
-- not legal.
local function terrain(plot, x, z)
	local key = x .. ":" .. z
	local first, second = a[plot.id] and a[plot.id][key], b[plot.id] and b[plot.id][key]
	if not first or not second then return false, "unscanned" end
	for _, row in ipairs({first, second}) do
		if row.wet_reference then return false, "reference_in_water" end
		if row.submerged > 0 then
			return false, "submerged:" .. row.submerged
		end
		if row.margin > 0 then return false, "margin_in_water:" .. row.margin end
		if row.fall > SKIRT then return false, "fall:" .. row.fall end
		if row.rise > plot.clear_to then return false, "rise:" .. row.rise end
	end
	return true, nil, math.max(first.fall, second.fall),
		math.max(first.rise, second.rise)
end

local failures = 0
io.write("plot\tx\tz\tverdict\tworst_fall\tworst_rise\tsubmerged_a" ..
	"\tsubmerged_b\n")
for _, plot in ipairs(plots) do
	local ok, why = geometry(plot, plot.x, plot.z, plot.id)
	local fall, rise = "-", "-"
	if ok then
		local measured_fall, measured_rise
		ok, why, measured_fall, measured_rise = terrain(plot, plot.x, plot.z)
		fall = measured_fall or "-"
		rise = measured_rise or "-"
	end
	local key = plot.x .. ":" .. plot.z
	local first = a[plot.id] and a[plot.id][key]
	local second = b[plot.id] and b[plot.id][key]
	if not ok then failures = failures + 1 end
	io.write(table.concat({plot.id, plot.x, plot.z,
		ok and "legal" or ("ILLEGAL " .. tostring(why)), fall, rise,
		first and first.submerged or "-", second and second.submerged or "-"},
		"\t"), "\n")
end

-- `--assign` proposes a whole district at once: every plot that is already
-- legal and comfortable keeps its authored position, and every plot that is not
-- takes the NEAREST one that is, with the plots already placed blocking the
-- ground they stand on. Nearest, not flattest: the authored layout is a design,
-- and the first version of this package lost it by sorting on flatness alone.
--
-- "Comfortable" is a margin on both terrain rules: a fall of at most four
-- against a skirt of six, and a rise at least two nodes under the plot's own
-- airspace clear, so a plot is not one node from failing on the next seed.
local COMFORT_FALL = 4
local COMFORT_RISE_MARGIN = 2

if arg[4] == "--assign" then
	local taken = {}
	local function blocked(plot, x, z)
		local min_x, max_x = x + plot.bounds.min.x, x + plot.bounds.max.x
		local min_z, max_z = z + plot.bounds.min.z, z + plot.bounds.max.z
		for _, box in ipairs(taken) do
			if overlaps(min_x, max_x, box.min_x, box.max_x) and
					overlaps(min_z, max_z, box.min_z, box.max_z) then
				return true
			end
		end
		return false
	end
	-- The legality rule is one node of gap; a DISTRICT wants more than that, or
	-- two plots read as one building with a seam in it. Six is the width of a
	-- lane between them, which is what the authored layout has.
	local DISTRICT_GAP = 6
	local function keep(plot, x, z)
		taken[#taken + 1] = {min_x = x + plot.bounds.min.x - DISTRICT_GAP,
			max_x = x + plot.bounds.max.x + DISTRICT_GAP,
			min_z = z + plot.bounds.min.z - DISTRICT_GAP,
			max_z = z + plot.bounds.max.z + DISTRICT_GAP}
	end
	local function comfortable(plot, x, z)
		local ok, why, fall, rise = terrain(plot, x, z)
		if not ok then return false, why end
		if fall > COMFORT_FALL then return false, "fall:" .. fall end
		if rise > plot.clear_to - COMFORT_RISE_MARGIN then
			return false, "rise:" .. rise
		end
		return true, nil, fall, rise
	end
	io.write("\n== proposed district\n")
	for _, plot in ipairs(plots) do
		local ok = geometry(plot, plot.x, plot.z, plot.id) and
			not blocked(plot, plot.x, plot.z)
		local fall, rise
		if ok then ok, _, fall, rise = comfortable(plot, plot.x, plot.z) end
		if ok then
			keep(plot, plot.x, plot.z)
			io.write(string.format("%-24s keep  x=%4d z=%4d fall=%d rise=%d\n",
				plot.id, plot.x, plot.z, fall, rise))
		else
			local best
			for z = -96, 96, 4 do
				for x = 52, 204, 4 do
					if geometry(plot, x, z, plot.id) and not blocked(plot, x, z) then
						local good, _, candidate_fall, candidate_rise =
							comfortable(plot, x, z)
						if good then
							local distance = math.abs(x - plot.x) + math.abs(z - plot.z)
							if not best or distance < best.distance then
								best = {x = x, z = z, fall = candidate_fall,
									rise = candidate_rise, distance = distance}
							end
						end
					end
				end
			end
			assert(best, "no legal home for " .. plot.id)
			keep(plot, best.x, best.z)
			io.write(string.format(
				"%-24s MOVE  x=%4d z=%4d fall=%d rise=%d (was %d,%d, move %d)\n",
				plot.id, best.x, best.z, best.fall, best.rise, plot.x, plot.z,
				best.distance))
		end
	end
	os.exit(0)
end

if sweep then
	for _, plot in ipairs(plots) do
		io.write("\n== candidates for ", plot.id, " (now at ", plot.x, ",",
			plot.z, ")\n")
		local best = {}
		for z = -96, 96, 4 do
			for x = 52, 204, 4 do
				local ok = geometry(plot, x, z, plot.id)
				local fall, rise
				if ok then ok, _, fall, rise = terrain(plot, x, z) end
				if ok then
					best[#best + 1] = {x = x, z = z, fall = fall, rise = rise,
						distance = math.abs(x - plot.x) + math.abs(z - plot.z)}
				end
			end
		end
		table.sort(best, function(p, q)
			if p.fall ~= q.fall then return p.fall < q.fall end
			if p.rise ~= q.rise then return p.rise < q.rise end
			return p.distance < q.distance
		end)
		for index = 1, math.min(10, #best) do
			local row = best[index]
			io.write(string.format("  x=%4d z=%4d fall=%d rise=%d move=%d\n",
				row.x, row.z, row.fall, row.rise, row.distance))
		end
		io.write("  legal candidates: ", #best, "\n")
	end
end

if failures > 0 then
	io.write("\n", failures, " plot(s) stand somewhere they may not\n")
	os.exit(1)
end
io.write("\nevery district plot is dry, inside the skirt and under its own roof",
	" on both worlds\n")
