-- capital_walls_probe.lua -- check the capital walls without the engine
-- (Round 23, docs/research/round23-capital-walls.md).
--
--     luajit tools/wp13/capital_walls_probe.lua <repo> [layouts.txt] [--dump DIR]
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
-- the gate passages clear, Lethariel's colonnettes and turret lamps and
-- Kezamba's turned stake points. `--dump DIR` writes each edge and core as
-- `x y z name param2` TSV (anchor-relative) for `render_blueprint.py`.
--
-- Plain Lua 5.1, no engine. Any failed check ends the run with an error.

local args = {...}
local repo = args[1]
if not repo then
	error("usage: capital_walls_probe.lua <repo> [layouts.txt] [--dump DIR]", 0)
end
local layouts_path, dump_dir
local index = 2
while args[index] do
	if args[index] == "--dump" then
		dump_dir = args[index + 1]
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
	local base = "grug_decor:castle_pillar_silver_sandstone_brick"
	local brick = "default:silver_sandstone_brick"
	if (x + z) % 2 == 0 then
		return {brick, brick, "grug_decor:darkage_marble", base .. "_bottom",
			base .. "_top"}, 5
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

if layouts_path then
	local f = assert(io.open(layouts_path))
	local all = f:read("*a")
	f:close()
	local section = all:match("section capital %d+ %x+\n(.-)\nsection meta")
	if not section then error("no capital section in " .. layouts_path, 0) end
	local texts, current = {}, nil
	for line in (section .. "\n"):gmatch("([^\n]*)\n") do
		if line:sub(1, 3) == "C2 " then current = {}; texts[#texts + 1] = current end
		if current and line ~= "" then current[#current + 1] = line end
	end
	local ANCHOR_KEY = {anchor_007 = "dur_brannoc", anchor_008 = "highcourt",
		anchor_009 = "lethariel", anchor_010 = "nhal_veyr", anchor_011 = "gor_drazhak",
		anchor_012 = "kezamba"}
	for _, lines in ipairs(texts) do
		local text = table.concat(lines, "\n") .. "\n"
		local layout = planner.deserialize(text)
		local key = ANCHOR_KEY[layout.anchor.id]
		local cfg = blueprint.CAPITALS[key]
		local dims = planner.EDGE[cfg.edge]
		local height = dims.opts.WALL_HEIGHT
		local clear = dims.opts.WALL_CLEAR or planner.DEFAULTS.WALL_CLEAR
		local source = blueprint.source(key, layout, text)
		local overlay = source.overlay
		local allowed = {}
		for _, name in ipairs(overlay.names) do allowed[name] = true end
		local W = layout.wall
		local n = #W.pts
		-- synthetic terrain: the nearest wall point's walk, less the walk height
		local function column(x, z)
			local lx, lz = x - layout.anchor.x, z - layout.anchor.z
			for c = 1, 4 do
				local g = layout.gates[c]
				local dd = (lx - g.x) * g.dx + (lz - g.z) * g.dz
				local ww = -(lx - g.x) * g.dz + (lz - g.z) * g.dx
				if math.abs(dd) <= dims.depth + 1 and math.abs(ww) <= dims.width + 1 then
					return g.y, nil, false
				end
			end
			local best, bi
			for i = 1, n do
				local dx, dz = lx - W.pts[i][1], lz - W.pts[i][2]
				local d = dx * dx + dz * dz
				if not best or d < best then best, bi = d, i end
			end
			local walk = math.floor(W.walk[bi] / 2)
			if W.wet[bi] then
				local water = walk - clear
				return water - 6, water, false
			end
			return walk - height, nil, false
		end
		local AX, AZ = layout.anchor.x, layout.anchor.z
		local edge = overlay.make({x = AX, z = AZ})
		local box = {min_x = AX + overlay.reach.min_x, max_x = AX + overlay.reach.max_x,
			min_z = AZ + overlay.reach.min_z, max_z = AZ + overlay.reach.max_z}
		local cells = edge.cells(box, column)
		local by = {}
		local local_cells = {}
		local lamps, bases, tops, caps, bad_caps = 0, 0, 0, 0, 0
		local ymin, ymax = math.huge, -math.huge
		for _, c in ipairs(cells) do
			check(allowed[c.name], key .. ": edge name outside the overlay palette: " .. c.name)
			if c.y < ymin then ymin = c.y end
			if c.y > ymax then ymax = c.y end
			by[c.x .. ":" .. c.y .. ":" .. c.z] = c
			local_cells[#local_cells + 1] = {x = c.x - AX, y = c.y, z = c.z - AZ,
				name = c.name, param2 = c.param2}
			if c.name == "grug_materials:emberglass_lamp" then lamps = lamps + 1 end
			if c.name:find("_pillar_", 1, true) and c.name:sub(-7) == "_bottom" then bases = bases + 1 end
			if c.name:find("_pillar_", 1, true) and c.name:sub(-4) == "_top" then tops = tops + 1 end
			if c.name == "stairs:stair_outer_junglewood" then
				caps = caps + 1
				if c.param2 ~= ((c.x - AX) + (c.z - AZ)) % 4 then bad_caps = bad_caps + 1 end
			end
		end
		check(ymax <= overlay.y_max, ("%s: edge reaches y %d above its y_max %d"):format(key, ymax, overlay.y_max))
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
			check(lamps == #W.turrets, ("lethariel: %d turret lamps for %d turrets"):format(lamps, #W.turrets))
			check(bases > 0 and bases == tops, ("lethariel: colonnettes %d bases, %d tops"):format(bases, tops))
		end
		if key == "kezamba" then
			check(caps > 0 and bad_caps == 0, ("kezamba: %d stake points, %d not turned by column"):format(caps, bad_caps))
		end
		local wet = 0
		for i = 1, n do if W.wet[i] and not W.gap[i] then wet = wet + 1 end end
		io.write(("edge %-12s kind %-15s cells %6d, y %d..%d (overlay %d..%d), turrets %2d, wet points %3d, lamps %d, colonnettes %d, turned points %d\n")
			:format(key, layout.kind, #cells, ymin, ymax, overlay.y_min, overlay.y_max,
				#W.turrets, wet, lamps, bases, caps))
		dump(key .. "_edge", local_cells)
	end
end

-- a failed check ends the run with an error, so the exit status is 1
if failures > 0 then error(("capital walls probe: FAIL (%d)"):format(failures), 0) end
io.write("capital walls probe: PASS\n")
