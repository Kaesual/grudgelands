-- The cenote: where the water is, how deep the pad is cut, and whether both
-- are the same in every world.
--
--     luajit tools/wp13/kezamba_water.lua <repo>             -- the envelope
--     luajit tools/wp13/kezamba_water.lua <repo> --core      -- the civic core
--     luajit tools/wp13/kezamba_water.lua <repo> --core --map
--     luajit tools/wp13/kezamba_water.lua <repo> --emit      -- the mask module
--     luajit tools/wp13/kezamba_water.lua <repo> --verify    -- against the tree
--
-- WHAT THIS IS FOR.
--
-- Kezamba is the troll capital of the capitals contract's section 2.4 table --
-- "stilted cenote terrace, step 3" -- and the one capital whose 512 envelope
-- carries an AUTHORED LAKE. `wp40/source/simple_map.lua` declares
-- `hydro_kezamba_cenote`, a `deep_cenote` of four basins at FIXED world
-- coordinates inside the envelope, and the WP40 water-correction package of
-- 2026-09-13 (`docs/research/wp40-water-road-polish.md`) raised this capital's
-- civic reference so that no graded ground stands below that lake's surface.
--
-- A capital core is a FIXED cell list in anchor-relative coordinates, and it
-- may be authored around a lake only if two things are true, neither of which
-- is safe to assume:
--
--   1. the lake stands in the same columns in every world;
--   2. the rest of the 96 x 96 pad really is flat at the fitted reference,
--      which is what the contract's section 1 claims of every capital.
--
-- This fixture measures both, on the nine seeds of
-- `tools/wp13/capital_anchor_fixture.lua`, through the planner itself -- the
-- same `terrain_height_at` / `water_class_at` / `water_surface_at` the engine's
-- world authority publishes and `r7_settlement.lua` builds an overlay's surface
-- from.
--
-- WHAT IT FOUND (2026-09-15, and the reason `wp13/kezamba_lagoon.lua` exists):
-- claim 1 holds exactly -- one wet mask, one water surface, on all nine seeds --
-- and claim 2 does NOT. Besides the lake, one narrow diagonal RAVINE runs into
-- the pad from its south-west edge and reaches up to 26 nodes below it. Its
-- footprint is the same in every world; only its depth moves. Both masks are
-- emitted as one committed module so the composition can build round them, and
-- `--verify` is what turns a change in either into a red run.
--
-- Plain Lua 5.1, LuaJIT in practice; no engine, no globals.

local repo = assert(arg[1], "repository root required")
local want_map, csv_dir, core_only, emit, verify = false, nil, false, false, false
do
	local index = 2
	while arg[index] do
		local option = arg[index]
		if option == "--map" then want_map = true
		elseif option == "--core" then core_only = true
		elseif option == "--emit" then emit = true; core_only = true
		elseif option == "--verify" then verify = true; core_only = true
		elseif option == "--csv" then
			index = index + 1
			csv_dir = assert(arg[index], "--csv needs a directory")
		else
			error("unknown argument " .. tostring(option), 0)
		end
		index = index + 1
	end
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()
local horizontal_factory = dofile(wp40 .. "/simple_map.lua")
local height_factory = dofile(wp40 .. "/height.lua")
local coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()

-- The nine seeds of `tools/wp13/capital_anchor_fixture.lua`, unchanged: two
-- gate seeds, the seed the user's world crashed on, and six more.
local SEEDS = {"531802985935182545", "8675309", "15912857179583385436",
	"0", "1", "2", "42", "12345", "999999999"}

local ANCHOR_ID = "anchor_012"        -- Kezamba
local CORE = 47                       -- the core's own bounds
local ENVELOPE = 256                  -- the 512 envelope
-- `--emit` walks the WHOLE envelope at node resolution, because the mask it
-- commits has two consumers at two scales: the core composition, which needs
-- the lake inside its own 95 x 95 pad, and the avenue overlay, which needs it
-- 256 nodes out where the east and north roads cross open water. A coarser
-- sample would commit a shoreline that is not the shoreline.
local HALF = (core_only and not emit) and CORE or ENVELOPE
local STEP = core_only and 1 or 2

-- Hex, because `raw_sha256` answers in raw bytes and a digest in a report is
-- read by a person.
local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return string.format("%02x", string.byte(byte))
	end))
end

-- One inclusive run list per row, which is how both masks are committed: the
-- lagoon is one wedge and the ravine one diagonal band, so a run list is a few
-- hundred bytes where a bitmap is nine thousand.
local function runs_of(rows, member, half)
	local out = {}
	for z = -half, half do
		local row, open = {}, nil
		for x = -half, half do
			if member(rows, x, z) then
				if open == nil then open = x end
			elseif open ~= nil then
				row[#row + 1] = {open, x - 1}
				open = nil
			end
		end
		if open ~= nil then row[#row + 1] = {open, half} end
		if #row > 0 then out[#out + 1] = {z = z, runs = row} end
	end
	return out
end

local function runs_text(list, indent)
	local lines = {}
	for index = 1, #list do
		local entry = list[index]
		local pairs_text = {}
		for run_index = 1, #entry.runs do
			pairs_text[run_index] = "{" .. entry.runs[run_index][1] .. ", " ..
				entry.runs[run_index][2] .. "}"
		end
		lines[#lines + 1] = indent .. "{" .. entry.z .. ", " ..
			table.concat(pairs_text, ", ") .. "},"
	end
	return table.concat(lines, "\n")
end

io.write("kind\tseed\tanchor_x\tanchor_y\tanchor_z\tcolumns\twet\twet_core",
	"\tterrain_low\tterrain_high\tsurface_low\tsurface_high\tmask_sha256\n")

local first_mask, mismatch = nil, 0
local surfaces = {}
local wet_all, low_any = {}, {}      -- the two unions this file commits
local anchor_y

for seed_index = 1, #SEEDS do
	local seed = SEEDS[seed_index]
	local horizontal = horizontal_factory({source = source, schemas = schemas,
		canonical = canonical, deterministic = deterministic,
		raw_sha256 = raw_sha256}).new(seed)
	local height = height_factory({source = source, canonical = canonical,
		deterministic = deterministic, raw_sha256 = raw_sha256,
		horizontal_session = horizontal,
		coupled_grade = coupled_grade}).new_runtime(seed)
	local anchor = height.selected_anchor_3d_by_id(ANCHOR_ID)
	if type(anchor) ~= "table" then
		error("kezamba water: the capital anchor is absent", 0)
	end
	anchor_y = anchor.y

	local rows, mask, grid = {}, {}, {}
	local columns, wet, wet_core = 0, 0, 0
	local terrain_low, terrain_high, surface_low, surface_high
	for z = -HALF, HALF, STEP do
		for x = -HALF, HALF, STEP do
			local wx, wz = anchor.x + x, anchor.z + z
			local is_wet = horizontal.water_class_at(wx, wz) ~= "land"
			local y = height.terrain_height_at(wx, wz)
			local surface = is_wet and height.water_surface_at(wx, wz) or nil
			columns = columns + 1
			if is_wet then
				wet = wet + 1
				if x >= -CORE and x <= CORE and z >= -CORE and z <= CORE then
					wet_core = wet_core + 1
				end
				if core_only then wet_all[z * 1024 + x] = true end
				if surface then
					if surface_low == nil or surface < surface_low then
						surface_low = surface
					end
					if surface_high == nil or surface > surface_high then
						surface_high = surface
					end
					surfaces[surface] = (surfaces[surface] or 0) + 1
				end
			elseif core_only and y ~= anchor.y and
					x >= -CORE and x <= CORE and z >= -CORE and z <= CORE then
				low_any[z * 1024 + x] = true
			end
			if terrain_low == nil or y < terrain_low then terrain_low = y end
			if terrain_high == nil or y > terrain_high then terrain_high = y end
			mask[#mask + 1] = is_wet and "1" or "0"
			grid[z .. ":" .. x] = {y = y, wet = is_wet}
			if csv_dir then
				rows[#rows + 1] = table.concat({x, z, y, tostring(is_wet),
					surface or "-"}, "\t") .. "\n"
			end
		end
	end
	local digest = hex(raw_sha256(table.concat(mask)))
	if first_mask == nil then first_mask = digest
	elseif digest ~= first_mask then mismatch = mismatch + 1 end

	io.write(table.concat({"kezamba_water", seed, anchor.x, anchor.y, anchor.z,
		columns, wet, wet_core, terrain_low, terrain_high,
		surface_low or "-", surface_high or "-", digest}, "\t"), "\n")

	if csv_dir then
		local file = assert(io.open(csv_dir .. "/kezamba-water-" .. seed ..
			".tsv", "wb"))
		file:write("x\tz\tterrain_y\twater\twater_surface\n")
		file:write(table.concat(rows))
		assert(file:close())
	end

	if want_map and seed_index == 1 then
		io.write("\n-- seed ", seed, ", ", STEP * 16 / STEP,
			"-node lattice; ~ water, digit = terrain_y // 10\n")
		local digits = "0123456789ABCDEFGHIJ"
		local lattice = core_only and 2 or 16
		for z = -HALF, HALF, lattice do
			local line = {}
			for x = -HALF, HALF, lattice do
				local cell = grid[z .. ":" .. x]
				if cell == nil then line[#line + 1] = "?"
				elseif cell.wet then line[#line + 1] = "~"
				else
					local at = math.floor(cell.y / 10) + 1
					if at < 1 then at = 1 end
					if at > #digits then at = #digits end
					line[#line + 1] = digits:sub(at, at)
				end
			end
			io.write(string.format("%5d %s\n", z, table.concat(line)))
		end
		io.write("\n")
	end
end

local surface_list = {}
for value in pairs(surfaces) do surface_list[#surface_list + 1] = value end
table.sort(surface_list)
local surface_text = {}
for index = 1, #surface_list do
	surface_text[index] = surface_list[index] .. "x" ..
		surfaces[surface_list[index]]
end
io.write("kezamba_water_surfaces\t", table.concat(surface_text, ","), "\n")
io.write("kezamba_water_mask_seeds\t", #SEEDS, "\tmismatch\t", mismatch, "\n")
if mismatch ~= 0 then
	io.write("kezamba_water FAIL: the lake is not the same in every world\n")
	os.exit(1)
end

if not core_only then
	io.write("kezamba_water PASS: one wet mask on all ", #SEEDS, " seeds\n")
	os.exit(0)
end

-- THE RAVINE. The cut columns are dry land whose final height is below the
-- fitted reference, and the composition has to leave them alone for the same
-- reason it leaves the lake alone: a ground course laid at y = 0 over a column
-- that stands 26 nodes lower is a slab in the air. The union over the nine
-- seeds is what is committed, GROWN BY ONE NODE, because the rim of a cut is
-- where the ground is steepest and a plot's own kerb has no business on it.
local ravine = {}
for key in pairs(low_any) do
	local z = math.floor((key + 512) / 1024)
	local x = key - z * 1024
	for dz = -1, 1 do
		for dx = -1, 1 do
			local nx, nz = x + dx, z + dz
			if nx >= -CORE and nx <= CORE and nz >= -CORE and nz <= CORE and
					not wet_all[nz * 1024 + nx] then
				ravine[nz * 1024 + nx] = true
			end
		end
	end
end

local function member(set, x, z) return set[z * 1024 + x] == true end
local lagoon_runs = runs_of(wet_all, member, HALF)
local ravine_runs = runs_of(ravine, member, CORE)
local lagoon_count, ravine_count = 0, 0
for _ in pairs(wet_all) do lagoon_count = lagoon_count + 1 end
for _ in pairs(ravine) do ravine_count = ravine_count + 1 end
local lagoon_digest = hex(raw_sha256(runs_text(lagoon_runs, "")))
local ravine_digest = hex(raw_sha256(runs_text(ravine_runs, "")))

io.write("kezamba_core_lagoon\t", lagoon_count, "\trows\t", #lagoon_runs,
	"\tsha256\t", lagoon_digest, "\n")
io.write("kezamba_core_ravine\t", ravine_count, "\trows\t", #ravine_runs,
	"\tsha256\t", ravine_digest, "\n")
io.write("kezamba_core_reference\t", anchor_y, "\twater_surface\t",
	surface_list[1] or "-", "\n")

if verify then
	local committed = dofile(wp13 .. "/kezamba_lagoon.lua")()
	local bad = 0
	for z = -HALF, HALF do
		for x = -HALF, HALF do
			if committed.lagoon(x, z) ~= (wet_all[z * 1024 + x] == true) then
				bad = bad + 1
			end
			if x >= -CORE and x <= CORE and z >= -CORE and z <= CORE and
					committed.ravine(x, z) ~= (ravine[z * 1024 + x] == true) then
				bad = bad + 1
			end
		end
	end
	if committed.REFERENCE_Y ~= anchor_y or
			committed.WATER_SURFACE_Y ~= (surface_list[1] or -1) then
		bad = bad + 1
	end
	io.write("kezamba_mask_verify\tdisagreements\t", bad, "\n")
	if bad ~= 0 then
		io.write("kezamba_water FAIL: the committed mask is not the map\n")
		os.exit(1)
	end
	io.write("kezamba_water PASS: the committed mask is the map on all ",
		#SEEDS, " seeds\n")
	os.exit(0)
end

if emit then
	local out = assert(io.open(wp13 .. "/kezamba_lagoon.lua", "wb"))
	out:write([==[
-- Kezamba's two holes in the pad: the CENOTE and the RAVINE.
--
-- GENERATED, and regenerated by the tool that measured it:
--
--     luajit tools/wp13/kezamba_water.lua <repo> --emit
--     luajit tools/wp13/kezamba_water.lua <repo> --verify
--
-- Do not hand-edit. `--verify` reads this file back and compares every one of
-- the 95 x 95 columns against the planner on all nine seeds of
-- `tools/wp13/capital_anchor_fixture.lua`; `tools/wp13/kezamba_kat.lua`
-- asserts that the core composition writes no ground into either mask.
--
-- WHY A CAPITAL CORE HAS A MASK AT ALL. The capitals contract's section 1 says
-- "the 96 x 96 civic core is flat at the fitted reference height". At Kezamba
-- it is flat over 6 192 of its 9 025 columns and not over the rest, and both
-- exceptions are WP40's own authored geometry rather than noise:
--
--   * THE CENOTE. `hydro_kezamba_cenote` is a `deep_cenote` of four basins at
--     fixed world coordinates, and its north-east wedge reaches into the core.
--     The lake's surface stands at y = 65 -- exactly ONE NODE below the fitted
--     reference of 66 -- on every seed measured, which is the WP40 water
--     correction of 2026-09-13 doing what it says: the civic water minimum is a
--     hard floor under the reference solver.
--   * THE RAVINE. One diagonal cut runs into the pad from its south-west edge.
--     Its FOOTPRINT is the same in every world and its DEPTH is not: it reaches
--     8 nodes below the pad on seed 531802985935182545 and 26 on seed 0. The
--     committed mask is therefore the UNION over the nine seeds, grown by one
--     node, and the composition treats it as a gorge rather than as ground.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader()
	local M = {}

	-- The core's own half-extent, the fitted reference the pad stands at, and
	-- the lake's surface -- all three measured, none of them assumed.
	M.REACH = ]==] .. CORE .. "\n" ..
		"\tM.ENVELOPE = " .. HALF .. "\n" ..
		"\tM.REFERENCE_Y = " .. anchor_y .. "\n" ..
		"\tM.WATER_SURFACE_Y = " .. (surface_list[1] or -1) .. "\n" ..
		"\tM.LAGOON_COLUMNS = " .. lagoon_count .. "\n" ..
		"\tM.RAVINE_COLUMNS = " .. ravine_count .. "\n" .. [==[

	-- Inclusive x runs per z. A wedge and a band are a few hundred bytes this
	-- way and nine thousand as a bitmap.
	local LAGOON = {
]==] .. runs_text(lagoon_runs, "\t\t") .. [==[

	}
	local RAVINE = {
]==] .. runs_text(ravine_runs, "\t\t") .. [==[

	}

	-- Row lookup, built once at load: 95 small arrays rather than a linear
	-- scan per query, because the core composition asks for every one of its
	-- 9 025 columns at least twice.
	local function index(rows)
		local by_z = {}
		for entry = 1, #rows do
			local row = rows[entry]
			by_z[row[1]] = row
		end
		return by_z
	end
	local LAGOON_BY_Z = index(LAGOON)
	local RAVINE_BY_Z = index(RAVINE)

	local function member(by_z, x, z)
		local row = by_z[z]
		if row == nil then return false end
		for entry = 2, #row do
			if x >= row[entry][1] and x <= row[entry][2] then return true end
		end
		return false
	end

	-- Is this column open water?
	function M.lagoon(x, z) return member(LAGOON_BY_Z, x, z) end
	-- Is this column inside the ravine, or on its rim?
	function M.ravine(x, z) return member(RAVINE_BY_Z, x, z) end
	-- Is this column ground the composition may build on?
	function M.pad(x, z)
		return not member(LAGOON_BY_Z, x, z) and not member(RAVINE_BY_Z, x, z)
	end

	-- Does the rectangle stand wholly on the pad? The composition asks this of
	-- every plot before it stamps it, so a part cannot be laid half over the
	-- lake the way a prop once was laid half over another plot at Dawnmere.
	function M.pad_area(x1, z1, x2, z2)
		for z = z1, z2 do
			for x = x1, x2 do
				if not M.pad(x, z) then return false, x, z end
			end
		end
		return true
	end

	-- The shore: a pad column with open water within one node of it. The quay,
	-- the anglers and the stilt platforms all stand on these.
	function M.shore(x, z)
		if not M.pad(x, z) then return false end
		for dz = -1, 1 do
			for dx = -1, 1 do
				if M.lagoon(x + dx, z + dz) then return true end
			end
		end
		return false
	end

	return M
end

return loader
]==])
	assert(out:close())
	io.write("kezamba_water EMIT: wp13/kezamba_lagoon.lua written\n")
	os.exit(0)
end

io.write("kezamba_water PASS: one wet mask on all ", #SEEDS, " seeds\n")
