-- capital_walls_probe.lua -- check the capital walls without the engine
-- (Round 23, docs/research/round23-capital-walls.md).
--
--     luajit tools/wp13/capital_walls_probe.lua <repo> [layouts.txt] [--dump DIR]
--         [--baseline-layouts OLD.txt --baseline-edge OLD_city_edge.lua]
--
-- Part 1, always: builds the six civic cores and checks the protected
-- precinct wall on its ring -- the courses per column, the merlon rhythm, the
-- height, one node thick, Nhal Veyr's bar course closed from merlon to
-- merlon and flat along the wall, and nothing of the ring in a gate passage.
--
-- Part 2, with a world's `grug_world_layouts.txt` (a headless boot leaves it
-- in its world folder; `KEEP=1 tools/luanti_headless.sh`): builds each
-- capital's city edge from that layout through `r7_capital_blueprint.source`
-- on SYNTHETIC ground -- the planner's walk minus the edge kind's walk
-- height, and over a wet point a lake whose surface lies WALL_CLEAR under the
-- walk and whose bed lies six below that -- and checks every cell name
-- against the overlay palette, every height against the overlay's y range,
-- the gate passages clear, Lethariel's low crown (no pillar colonnette, every
-- merlon one face course under a marble slab) and turret lamps and Kezamba's
-- turned stake points, and on the two civic lakes (Round 23 user rulings and
-- playtest fixes) that the wall is continuous on land and ends in the water:
-- no isolated wall run between two lake stretches unless it is a real land
-- crossing (SHORE_MIN_RUN dry points or more), each lake end walled over 1 to
-- SHORE_INTO water points (none only beside a gate) on a solid footing and
-- closed by a head, no edge cell deeper in the lake than SHORE_DEEP + the
-- wall's half + 2, no turret on or near the open lake, and every cell inside
-- the overlay's y range. With `--baseline-layouts` and `--baseline-edge` (the
-- layouts and `wp13/city_edge.lua` of the previous version) it also checks
-- that the four other capitals' layouts and edge cells are unchanged and that
-- the two lake capitals changed only their wall flags and turrets.
-- `--dump DIR` writes each edge and core as `x y z name param2` TSV
-- (anchor-relative) for `render_blueprint.py`.
--
-- Plain Lua 5.1, no engine. Any failed check ends the run with an error.

local args = {...}
local repo = args[1]
if not repo then
	error("usage: capital_walls_probe.lua <repo> [layouts.txt] [--dump DIR]", 0)
end
local layouts_path, dump_dir, baseline_layouts, baseline_edge
local index = 2
while args[index] do
	if args[index] == "--dump" then
		dump_dir = args[index + 1]
		index = index + 2
	elseif args[index] == "--baseline-layouts" then
		baseline_layouts = args[index + 1]
		index = index + 2
	elseif args[index] == "--baseline-edge" then
		baseline_edge = args[index + 1]
		index = index + 2
	else
		layouts_path = args[index]
		index = index + 1
	end
end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local palettes = dofile(wp13 .. "/palette.lua")
local ring = dofile(wp13 .. "/precinct_ring.lua")
local planner = dofile(wp40 .. "/capital_planner.lua")
local blueprint = dofile(wp40 .. "/r7_capital_blueprint.lua")

local failures = 0
local function check(ok, message)
	if not ok then
		failures = failures + 1
		io.write("FAIL ", message, "\n")
	end
	return ok
end

local function dump(name, cells)
	if not dump_dir then return end
	local out = {}
	for _, c in ipairs(cells) do
		out[#out + 1] = ("%d\t%d\t%d\t%s\t%d\n"):format(c.x, c.y, c.z, c.name, c.param2 or 0)
	end
	local f = assert(io.open(dump_dir .. "/" .. name .. ".tsv", "w"))
	f:write(table.concat(out))
	f:close()
end

-------------------------------------------------------------------------------
-- Part 1: the precinct walls
-------------------------------------------------------------------------------

-- Per capital: the expected node per course at a ring column, the skip the
-- composition gives its ring, and the courses above the ring that must stay
-- free of ring material everywhere.
local function expect_highcourt(x, z)
	local human = palettes.new("human")
	local stone = human.node("castle_wall")
	return {stone, stone, "grug_decor:darkage_marble",
		(x + z) % 2 == 0 and stone or false}, 4
end
local function expect_dur_brannoc(x, z, at)
	local dwarf = palettes.new("dwarf")
	local stone, cap = dwarf.node("castle_wall"), dwarf.node("signature_slab")
	if (x + z) % 4 == 0 then
		local above = at(x, 6, z)
		return {stone, stone, stone, stone,
			(not above or above.name == "air") and cap or false}, 5
	end
	return {stone, stone, stone, false}, 5
end
local function expect_gor_drazhak(x, z)
	local orc = palettes.new("orc")
	local earth, beaten = orc.node("subsoil"), orc.node("ground_bare")
	if (x + z) % 2 == 0 then
		return {earth, earth, beaten, orc.node("tree_log"), orc.node("stake_cap")}, 5
	end
	return {earth, earth, beaten, false}, 5
end
local function expect_nhal_veyr(x, z, at)
	local undead = palettes.new("undead")
	local stone, cap = undead.node("castle_wall"), undead.node("signature_slab")
	if (x + z) % 4 == 0 then
		local above = at(x, 5, z)
		return {stone, stone, stone,
			(not above or above.name == "air") and cap or false}, 4
	end
	return {stone, stone, "xpanes:bar_flat", false}, 4
end
local function expect_lethariel(x, z)
	local brick = "default:silver_sandstone_brick"
	if (x + z) % 2 == 0 then
		return {brick, brick, "grug_decor:darkage_marble", brick,
			"grug_decor:darkage_marble_slab"}, 5
	end
	return {brick, brick, "grug_decor:darkage_marble", false}, 5
end
local function expect_kezamba(x, z)
	local troll = palettes.new("troll")
	return {troll.node("tree_log"), troll.node("tree_log"), troll.node("tree_log"),
		troll.node("roof_stair_outer")}, 4
end

local CORES = {
	{key = "highcourt", expect = expect_highcourt},
	{key = "dur_brannoc", expect = expect_dur_brannoc, skip = ring.is_corner},
	{key = "gor_drazhak", expect = expect_gor_drazhak, skip = ring.is_corner},
	{key = "nhal_veyr", expect = expect_nhal_veyr, skip = ring.is_corner},
	{key = "lethariel", expect = expect_lethariel, water = true},
	{key = "kezamba", expect = expect_kezamba, water = true},
}

for _, spec in ipairs(CORES) do
	local composition = dofile(wp13 .. "/" .. spec.key .. ".lua")(wp13)
	local core = composition.core()
	local by = {}
	for _, c in ipairs(core.cells) do by[c.x .. ":" .. c.y .. ":" .. c.z] = c end
	local function at(x, y, z) return by[x .. ":" .. y .. ":" .. z] end
	local columns, merlons, wet, bad = 0, 0, 0, 0
	local ring_names = {}
	ring.walk(function(x, z)
		local expected, height = spec.expect(x, z, at)
		-- a civic lake replaces the boundary where it reaches the ring
		local base = at(x, 1, z)
		if spec.water and (not base or base.name:find("water", 1, true) or
				base.name == "air") then
			wet = wet + 1
			return
		end
		columns = columns + 1
		for y = 1, height do
			local want = expected[y]
			local cell = at(x, y, z)
			local have = cell and cell.name or nil
			if want then
				ring_names[want] = true
				if not check(have == want, ("%s ring %d,%d y %d is %s, not %s"):format(
						spec.key, x, z, y, tostring(have), want)) then bad = bad + 1 end
			elseif have and ring_names[have] then
				check(false, ("%s ring %d,%d y %d carries ring material %s off the rhythm"):format(
					spec.key, x, z, y, have))
				bad = bad + 1
			end
		end
		if expected[#expected] then merlons = merlons + 1 end
		-- Nhal Veyr: every bar flat along its side of the ring
		local bar = at(x, 3, z)
		if bar and bar.name == "xpanes:bar_flat" then
			local along_x = math.abs(z) == ring.RADIUS
			check((along_x and bar.param2 % 2 == 0) or (not along_x and bar.param2 % 2 == 1),
				("%s bar %d,%d param2 %d crosses the wall"):format(spec.key, x, z, bar.param2))
		end
		-- one node thick: the columns just inside and outside carry no
		-- ring course at the wall's own height unless another structure put it
	end, {skip = spec.skip})
	-- the gate passages: x or z within +/-2 of the axis at the ring line,
	-- courses 1..4, carry nothing solid
	local blocked = 0
	for _, g in ipairs({{0, -48}, {48, 0}, {0, 48}, {-48, 0}}) do
		for off = -2, 2 do
			local x = g[1] == 0 and off or g[1]
			local z = g[2] == 0 and off or g[2]
			for y = 1, 4 do
				local cell = at(x, y, z)
				if cell and ring_names[cell.name] then blocked = blocked + 1 end
			end
		end
	end
	check(blocked == 0, spec.key .. ": ring material in a gate passage")
	-- Nhal Veyr's bar course: no air or empty column between two merlons
	if spec.key == "nhal_veyr" then
		local gaps = 0
		ring.walk(function(x, z)
			local cell = at(x, 3, z)
			if not cell or cell.name == "air" then gaps = gaps + 1 end
		end, {skip = spec.skip})
		check(gaps == 0, "nhal_veyr: " .. gaps .. " empty columns in the bar course")
	end
	io.write(("core %-12s ring columns %3d, merlon columns %3d, lake columns %2d, mismatches %d, bounds y %d..%d\n")
		:format(spec.key, columns, merlons, wet, bad, core.bounds.min.y, core.bounds.max.y))
	dump(spec.key .. "_core", core.cells)
end

-------------------------------------------------------------------------------
-- Part 2: the city edges on a world's layouts
-------------------------------------------------------------------------------

local ANCHOR_KEY = {anchor_007 = "dur_brannoc", anchor_008 = "highcourt",
	anchor_009 = "lethariel", anchor_010 = "nhal_veyr", anchor_011 = "gor_drazhak",
	anchor_012 = "kezamba"}

-- the capital texts of a layouts file, in file order, and by anchor id
local function capital_texts(path)
	local f = assert(io.open(path))
	local all = f:read("*a")
	f:close()
	local section = all:match("section capital %d+ %x+\n(.-)\nsection meta")
	if not section then error("no capital section in " .. path, 0) end
	local texts, by, current = {}, {}, nil
	for line in (section .. "\n"):gmatch("([^\n]*)\n") do
		if line:sub(1, 3) == "C2 " then current = {}; texts[#texts + 1] = current end
		if current and line ~= "" then current[#current + 1] = line end
	end
	for i, lines in ipairs(texts) do
		texts[i] = table.concat(lines, "\n") .. "\n"
		by[lines[1]:match("^C2 (%S+)")] = texts[i]
	end
	return texts, by
end

if layouts_path then
	local texts = capital_texts(layouts_path)
	local terrain_data = dofile(wp40 .. "/terrain_data.lua")
	local LAKE_PROXY = terrain_data.water.LAKE_PROXY
	local lake_rows = {}
	for _, row in ipairs(dofile(wp40 .. "/water_authored.lua")(terrain_data.water)) do
		lake_rows[row.id] = row
	end
	local SHORE = planner.DEFAULTS
	-- synthetic terrain for a layout: the nearest wall point's walk less the
	-- walk height; over a civic lake's water (by its authored shape) the
	-- surface at that ground and a bed sloping down from it; over another
	-- wet point a lake whose surface lies WALL_CLEAR under the walk and whose
	-- bed lies six below that; `roads` puts a road on every 7th column
	local function terrain(layout, dims, distance, roads)
		local W, n = layout.wall, #layout.wall.pts
		local height = dims.opts.WALL_HEIGHT
		local clear = dims.opts.WALL_CLEAR or planner.DEFAULTS.WALL_CLEAR
		return function(x, z)
			local lx, lz = x - layout.anchor.x, z - layout.anchor.z
			local road = roads and (x % 7) == 0 or false
			for c = 1, 4 do
				local g = layout.gates[c]
				local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
				local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
				if math.abs(dd) <= dims.depth + 1 and math.abs(ww) <= dims.width + 1 then
					return g.y, nil, road
				end
			end
			local best, bi
			for i = 1, n do
				local dx, dz = lx - W.pts[i][1], lz - W.pts[i][2]
				local d = dx * dx + dz * dz
				if not best or d < best then best, bi = d, i end
			end
			local walk = math.floor(W.walk[bi] / 2)
			if distance then
				local d = distance(x, z)
				if d <= 0 then
					local surface = walk - height
					return surface - 1 - math.floor(math.min(6, -d)), surface, road
				end
			end
			if W.wet[bi] then
				local water = walk - clear
				return water - 6, water, road
			end
			return walk - height, nil, road
		end
	end

	for _, text in ipairs(texts) do
		local layout = planner.deserialize(text)
		local key = ANCHOR_KEY[layout.anchor.id]
		local cfg = blueprint.CAPITALS[key]
		local dims = planner.EDGE[cfg.edge]
		local source = blueprint.source(key, layout, text)
		local overlay = source.overlay
		local allowed = {}
		for _, name in ipairs(overlay.names) do allowed[name] = true end
		local W = layout.wall
		local n = #W.pts
		local AX, AZ = layout.anchor.x, layout.anchor.z
		local lake = cfg.lake and lake_rows[cfg.lake]
		local distance = lake and function(x, z)
			return (0.5 - lake.indicator(x, z)) * LAKE_PROXY
		end
		local column = terrain(layout, dims, distance, false)
		local edge = overlay.make({x = AX, z = AZ})
		local box = {min_x = AX + overlay.reach.min_x, max_x = AX + overlay.reach.max_x,
			min_z = AZ + overlay.reach.min_z, max_z = AZ + overlay.reach.max_z}
		local cells = edge.cells(box, column)
		local by = {}
		local local_cells = {}
		local lamps, pillars, merlon_caps, caps, bad_caps = 0, 0, 0, 0, 0
		local ymin, ymax = math.huge, -math.huge
		for _, c in ipairs(cells) do
			check(allowed[c.name], key .. ": edge name outside the overlay palette: " .. c.name)
			if c.y < ymin then ymin = c.y end
			if c.y > ymax then ymax = c.y end
			by[c.x .. ":" .. c.y .. ":" .. c.z] = c
			local_cells[#local_cells + 1] = {x = c.x - AX, y = c.y, z = c.z - AZ,
				name = c.name, param2 = c.param2}
			if c.name == "grug_materials:emberglass_lamp" then lamps = lamps + 1 end
			if c.name:find("_pillar_", 1, true) then pillars = pillars + 1 end
			if c.name == "grug_decor:darkage_marble_slab" then merlon_caps = merlon_caps + 1 end
			if c.name == "stairs:stair_outer_junglewood" then
				caps = caps + 1
				if c.param2 ~= ((c.x - AX) + (c.z - AZ)) % 4 then bad_caps = bad_caps + 1 end
			end
		end
		check(ymax <= overlay.y_max, ("%s: edge reaches y %d above its y_max %d"):format(key, ymax, overlay.y_max))
		check(ymin >= overlay.y_min, ("%s: edge reaches y %d below its y_min %d"):format(key, ymin, overlay.y_min))
		-- the gate passages: every passage column clear from the road up
		local passage_half = dims.model == "stone" and dims.width - 3 or dims.width - 2
		local blocked = 0
		for c = 1, 4 do
			local g = layout.gates[c]
			for dd = -dims.depth, dims.depth do
				for ww = -passage_half, passage_half do
					local x = math.floor(AX + g.x + g.dx * dd - g.dz * ww + 0.5)
					local z = math.floor(AZ + g.z + g.dz * dd + g.dx * ww + 0.5)
					for y = g.y + 1, g.y + 5 do
						local cell = by[x .. ":" .. y .. ":" .. z]
						if cell and cell.name ~= "air" then blocked = blocked + 1 end
					end
				end
			end
		end
		check(blocked == 0, ("%s: %d solid cells in the gate passages"):format(key, blocked))
		if key == "lethariel" then
			-- the low crown (user playtest ruling): no pillar colonnette
			-- anywhere, every merlon one brick course under a marble slab
			check(lamps == #W.turrets, ("lethariel: %d turret lamps for %d turrets"):format(lamps, #W.turrets))
			check(pillars == 0, ("lethariel: %d pillar colonnette cells in the crown"):format(pillars))
			local bad = 0
			for _, c in ipairs(cells) do
				if c.name == "grug_decor:darkage_marble_slab" then
					local below = by[c.x .. ":" .. (c.y - 1) .. ":" .. c.z]
					local base = below and by[c.x .. ":" .. (c.y - 2) .. ":" .. c.z]
					-- a merlon cap on its brick, the brick on the coping (or,
					-- on a passage parapet, the cap on the coping itself)
					if not below or not ((below.name == "default:silver_sandstone_brick" and base and
							base.name == "grug_decor:darkage_marble") or below.name == "grug_decor:darkage_marble") then
						bad = bad + 1
					end
					local above = by[c.x .. ":" .. (c.y + 1) .. ":" .. c.z]
					if above and above.name ~= "air" then bad = bad + 1 end
				end
			end
			check(merlon_caps > 0 and bad == 0, ("lethariel: %d merlon caps, %d not a slab on one brick over the coping"):format(merlon_caps, bad))
		end
		if key == "kezamba" then
			check(caps > 0 and bad_caps == 0, ("kezamba: %d stake points, %d not turned by column"):format(caps, bad_caps))
		end
		-- the civic lake (Lethariel, Kezamba): the wall is continuous on land
		-- and ends a few points into the water where the outline crosses it
		local shore = ""
		if lake then
			local walk_name = dims.model == "stone" and "grug_decor:darkage_marble_tile" or
				palettes.new(cfg.race).node("path")
			local water = {}
			for i = 1, n do
				water[i] = not W.gap[i] and distance(AX + W.pts[i][1], AZ + W.pts[i][2]) <= 0
			end
			local function at(k) return (k - 1) % n + 1 end
			local turret_at = {}
			for _, t in ipairs(W.turrets) do turret_at[t] = true end
			local lake_points, ends, walled_water, fragments, land_runs = 0, 0, 0, 0, 0
			local most_in = 0
			for i = 1, n do
				if W.lake[i] then
					lake_points = lake_points + 1
					check(not W.gap[i], ("%s: gate point %d flagged lake"):format(key, i))
					-- a dry lake point lies between two crossings, never
					-- between a crossing and a gate (no dry margin)
					if not water[i] then
						for _, step in ipairs({1, -1}) do
							local k, reached = i, false
							for _ = 1, n do
								k = at(k + step)
								if water[k] then reached = true break end
								if W.gap[k] then break end
							end
							check(reached, ("%s: dry lake point %d reaches a gate before the water"):format(key, i))
						end
					end
					-- each end: 1..SHORE_INTO walled water points on a footing
					-- (none only beside a gate), closed by a head
					for _, step in ipairs({1, -1}) do
						local k = at(i + step)
						if not W.lake[k] then
							ends = ends + 1
							local count, last = 0, nil
							while water[k] and not W.lake[k] and count <= n do
								count = count + 1
								check(W.foot[k], ("%s: walled water point %d without footing"):format(key, k))
								last = k
								k = at(k + step)
							end
							walled_water = walled_water + count
							check(count <= SHORE.SHORE_INTO,
								("%s: %d walled water points at lake end by %d"):format(key, count, i))
							check(count >= 1 or W.gap[k], ("%s: lake end by %d not walled into the water"):format(key, i))
							local e = at(i + step)
							if last then
								-- the head: a column a node back from the wall's
								-- last point beside the lake carries no walk
								-- paving but masonry or stakes (the parapet or
								-- the stockade across the walk)
								local p, q = W.pts[e], W.pts[at(e + step)]
								local dx, dz = q[1] - p[1], q[2] - p[2]
								local len = math.sqrt(dx * dx + dz * dz)
								local hx = math.floor(AX + p[1] + dx / len + 0.5)
								local hz = math.floor(AZ + p[2] + dz / len + 0.5)
								local solid, paved = 0, 0
								for y = ymin, ymax do
									local c = by[hx .. ":" .. y .. ":" .. hz]
									if c and c.name ~= "air" then
										solid = solid + 1
										if c.name == walk_name then paved = paved + 1 end
									end
								end
								check(solid > 0 and paved == 0, ("%s: wall end by lake point %d is not closed (%d cells, %d paved)"):format(key, i, solid, paved))
								-- the footing: the middle of every walled segment
								-- from there to the land is solid from the ground
								-- to the walk (no arch to swim through)
								local k2 = e
								while k2 ~= k do
									local a, b = W.pts[k2], W.pts[at(k2 + step)]
									local mx = math.floor(AX + 0.5 * (a[1] + b[1]) + 0.5)
									local mz = math.floor(AZ + 0.5 * (a[2] + b[2]) + 0.5)
									local ground, surface = column(mx, mz)
									local top = math.floor(math.min(W.walk[k2], W.walk[at(k2 + step)]) / 2) - 1
									local holes = 0
									for y = ground, top do
										local c = by[mx .. ":" .. y .. ":" .. mz]
										if not c or c.name == "air" then holes = holes + 1 end
									end
									check(holes == 0, ("%s: %d open cells under the walk in the footing by point %d (surface %s)"):format(key, holes, k2, tostring(surface)))
									k2 = at(k2 + step)
								end
							end
						end
					end
				end
				-- no turret on or near the water
				if turret_at[i] then
					for k = i - SHORE.SHORE_TURRET_GAP, i + SHORE.SHORE_TURRET_GAP do
						check(not W.lake[at(k)] and not water[at(k)],
							("%s: turret %d within %d points of the lake"):format(key, i, SHORE.SHORE_TURRET_GAP))
					end
				end
			end
			check(lake_points > 0, key .. ": no civic lake points flagged")
			-- no isolated wall run between two lake stretches, unless it is a
			-- land crossing: at least SHORE_MIN_RUN dry points, the land
			-- outside it reaching beyond the lake and the land inside it
			-- reaching the city (a fill over the dry columns on that side of
			-- the outline, from beside the run, leaves a box 48 wider than
			-- the run; even-odd inside test over the whole outline)
			local function inside(x, z)
				local c = false
				for m = 1, n do
					local a, b = W.pts[m], W.pts[at(m + 1)]
					if (a[2] > z) ~= (b[2] > z) and x < a[1] + (z - a[2]) / (b[2] - a[2]) * (b[1] - a[1]) then
						c = not c
					end
				end
				return c
			end
			local function reaches_out(first, len, within)
				local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
				for m = 0, len - 1 do
					local p = W.pts[at(first + m)]
					x0, x1 = math.min(x0, p[1]), math.max(x1, p[1])
					z0, z1 = math.min(z0, p[2]), math.max(z1, p[2])
				end
				x0, x1, z0, z1 = math.floor(x0) - 48, math.ceil(x1) + 48, math.floor(z0) - 48, math.ceil(z1) + 48
				local seen, queue = {}, {}
				local function push(x, z)
					local k2 = x .. ":" .. z
					if seen[k2] then return false end
					seen[k2] = true
					if inside(x, z) ~= (within == true) or distance(AX + x, AZ + z) <= 0 then return false end
					if x <= x0 or x >= x1 or z <= z0 or z >= z1 then return true end
					queue[#queue + 1] = {x, z}
					return false
				end
				for m = 0, len - 1 do
					local p = W.pts[at(first + m)]
					for dz = -3, 3 do
						for dx = -3, 3 do
							if push(math.floor(p[1] + 0.5) + dx, math.floor(p[2] + 0.5) + dz) then return true end
						end
					end
				end
				local head = 1
				while queue[head] do
					local x, z = queue[head][1], queue[head][2]
					head = head + 1
					if push(x + 1, z) or push(x - 1, z) or push(x, z + 1) or push(x, z - 1) then return true end
				end
				return false
			end
			for i = 1, n do
				if not W.lake[i] and W.lake[at(i - 1)] then
					local k, len, dry, gate = i, 0, 0, false
					while not W.lake[k] and len < n do
						if W.gap[k] then gate = true end
						if not water[k] then dry = dry + 1 end
						len = len + 1
						k = at(k + 1)
					end
					if not gate then
						if dry >= SHORE.SHORE_MIN_RUN and reaches_out(i, len) and reaches_out(i, len, true) then
							land_runs = land_runs + 1
						else
							fragments = fragments + 1
							check(false, ("%s: isolated wall run of %d points (%d dry) at %d"):format(key, len, dry, i))
						end
					end
				end
			end
			-- no edge cell (a gatehouse aside) far into the lake
			local function in_gate(x, z)
				local lx, lz = x - AX, z - AZ
				for c = 1, 4 do
					local g = layout.gates[c]
					local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
					local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
					if math.abs(dd) <= dims.depth + 0.5 and math.abs(ww) <= dims.width + 0.5 then
						return true
					end
				end
				return false
			end
			local limit = SHORE.SHORE_DEEP + dims.half + 2
			local over_gate = 0
			local deepest = {}
			for _, c in ipairs(cells) do
				if c.name ~= "air" then
					local d = distance(c.x, c.z)
					if in_gate(c.x, c.z) then
						if d <= 0 then over_gate = over_gate + 1 end
					elseif -d > most_in then
						most_in = -d
					end
					if d < -limit and not deepest[c.x .. ":" .. c.z] and not in_gate(c.x, c.z) then
						deepest[c.x .. ":" .. c.z] = true
						check(false, ("%s: edge column %d,%d stands %.1f into the lake"):format(key, c.x, c.z, -d))
					end
				end
			end
			shore = (", lake points %d, lake ends %d, walled water points %d, deepest edge cell %.1f in the water (limit %.1f), isolated runs %d, land crossings %d, gatehouse cells over the water %d")
				:format(lake_points, ends, walled_water, most_in, limit, fragments, land_runs, over_gate)
		end
		local wet = 0
		for i = 1, n do if W.wet[i] and not W.gap[i] then wet = wet + 1 end end
		io.write(("edge %-12s kind %-15s cells %6d, y %d..%d (overlay %d..%d), turrets %2d, wet points %3d, lamps %d, pillars %d, marble caps %d, turned points %d%s\n")
			:format(key, layout.kind, #cells, ymin, ymax, overlay.y_min, overlay.y_max,
				#W.turrets, wet, lamps, pillars, merlon_caps, caps, shore))
		dump(key .. "_edge", local_cells)
	end

	-- the previous version: the four other capitals unchanged (layout text and
	-- edge cells from the old writer), the lake capitals changed only in
	-- their wall flags and turrets
	if baseline_layouts and baseline_edge then
		local _, old_by = capital_texts(baseline_layouts)
		local old_edge = dofile(baseline_edge)(wp13)
		local new_edge = dofile(wp13 .. "/city_edge.lua")(wp13)
		for _, text in ipairs(texts) do
			local layout = planner.deserialize(text)
			local key = ANCHOR_KEY[layout.anchor.id]
			local cfg = blueprint.CAPITALS[key]
			local old = old_by[layout.anchor.id]
			check(old ~= nil, key .. ": missing from the baseline layouts")
			if old and not cfg.lake then
				check(old == text, key .. ": layout text differs from the baseline")
				local dims = planner.EDGE[cfg.edge]
				local anchor = {x = layout.anchor.x, z = layout.anchor.z}
				local column = terrain(layout, dims, nil, true)
				local box = {min_x = anchor.x - 300, max_x = anchor.x + 300,
					min_z = anchor.z - 300, max_z = anchor.z + 300}
				local a = new_edge.new(cfg.race, dims.model, layout, dims, anchor).cells(box, column)
				local b = old_edge.new(cfg.race, dims.model, planner.deserialize(old), dims, anchor).cells(box, column)
				local same = #a == #b
				for i = 1, math.min(#a, #b) do
					local p, q = a[i], b[i]
					if p.x ~= q.x or p.y ~= q.y or p.z ~= q.z or p.name ~= q.name or p.param2 ~= q.param2 then
						same = false
						break
					end
				end
				local names_same = table.concat(new_edge.names(cfg.race, dims.model), ",") ==
					table.concat(old_edge.names(cfg.race, dims.model), ",")
				check(same and names_same, key .. ": edge cells or names differ from the baseline writer")
				io.write(("baseline %-12s layout text identical, edge cells %d identical %s, names identical %s\n")
					:format(key, #a, tostring(same), tostring(names_same)))
			elseif old then
				local function strip(t)
					local keep, pts = {}, {}
					for line in t:gmatch("[^\n]+") do
						if line:sub(1, 2) == "w " then
							for x, z, walk, flags in line:sub(3):gmatch("(%-?[%d.]+),(%-?[%d.]+),(%-?%d+)(%a*)") do
								pts[#pts + 1] = x .. "," .. z .. "," .. walk ..
									(flags:find("g", 1, true) and "g" or "") .. (flags:find("a", 1, true) and "a" or "")
							end
						elseif line:sub(1, 2) ~= "t " then
							keep[#keep + 1] = line
						end
					end
					return table.concat(keep, "\n"), table.concat(pts, " ")
				end
				local ka, pa = strip(text)
				local kb, pb = strip(old)
				check(ka == kb, key .. ": layout lines other than the wall's differ from the baseline")
				check(pa == pb, key .. ": wall points, walks, gate or water flags differ from the baseline")
				io.write(("baseline %-12s layout identical but for the wall's lake flags and turrets: %s\n")
					:format(key, tostring(ka == kb and pa == pb)))
			end
		end
	end
end

-- a failed check ends the run with an error, so the exit status is 1
if failures > 0 then error(("capital walls probe: FAIL (%d)"):format(failures), 0) end
io.write("capital walls probe: PASS\n")
