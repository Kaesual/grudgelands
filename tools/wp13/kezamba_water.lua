-- The cenote: where the water is, how deep the pad is cut, and whether both
-- are the same in every world.
--
--     luajit tools/wp13/kezamba_water.lua <repo>             -- the envelope
--     luajit tools/wp13/kezamba_water.lua <repo> --core      -- the civic core
--     luajit tools/wp13/kezamba_water.lua <repo> --core --map
--     luajit tools/wp13/kezamba_water.lua <repo> --emit      -- the mask module
--     luajit tools/wp13/kezamba_water.lua <repo> --verify    -- against the tree
--     luajit tools/wp13/kezamba_water.lua <repo> --field <field.tsv>
--     luajit tools/wp13/kezamba_water.lua <repo> --walls [<reach>]
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
-- and claim 2 did NOT. Besides the lake, one narrow diagonal RAVINE ran into
-- the pad from its south-west edge and reached up to 26 nodes below it, with
-- the same footprint in every world and only its depth moving.
--
-- WHAT IT FINDS NOW (2026-09-16, on main `f5583e13`): the ravine is GONE. It
-- was a graded ROUTE CORRIDOR, and WP40's wave-2 route lane taught every route
-- to end at the capital's gate points instead of grading on through the
-- envelope. Every dry column of the core now stands at the fitted reference on
-- all nine seeds; the wet mask is unchanged to the column. This is exactly what
-- `--verify` exists for: it went red on the committed ravine the first time it
-- ran on the rebased tree, which is how the change was found rather than shipped.
--
-- Plain Lua 5.1, LuaJIT in practice; no engine, no globals.

local repo = assert(arg[1], "repository root required")
local want_map, csv_dir, core_only, emit, verify = false, nil, false, false, false
local field_path = nil
local walls, walls_reach = false, 250
do
	local index = 2
	while arg[index] do
		local option = arg[index]
		if option == "--map" then want_map = true
		elseif option == "--core" then core_only = true
		elseif option == "--emit" then emit = true; core_only = true
		elseif option == "--verify" then verify = true; core_only = true
		elseif option == "--walls" then
			walls = true
			if arg[index + 1] and arg[index + 1]:match("^%d+$") then
				index = index + 1
				walls_reach = tonumber(arg[index])
			end
		elseif option == "--field" then
			index = index + 1
			field_path = assert(arg[index], "--field needs a field TSV")
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

-- `--field`: THE ENGINE'S OWN ANSWER TO THE SAME QUESTION.
--
-- Everything else in this file asks the PLANNER, engine-free, and that is what
-- makes it a fixture. `tools/wp13/run_capital.sh <out> kezamba field <seed>`
-- asks the running server instead: the probe writes `kezamba-field.tsv`, the
-- final height and the land/water class of every column within +-250 of the
-- anchor, read from `grug_zones` inside the boot. This mode reads that file back
-- and compares it, column by column, with the mask this package COMMITTED. A
-- disagreement means the committed lagoon is not the lake the world has, which
-- is the one failure mode a purely offline fixture cannot see.
-- `--walls`: THE WALL THE PLAYTEST FOUND, AS A NUMBER, ON ALL NINE SEEDS.
--
-- Playtest 5 (2026-09-16, user): "The capital core in Kezamba stands on an
-- unnatural plateau, the terrain has no natural course there."
--
-- `tools/wp13/capital_terrain_fixture.lua` measures CLIMBS -- how much of a
-- capital's ground has a neighbour more than a jump above it -- which is the
-- right instrument for a terrace riser and the wrong one for this: a pad that
-- ends in a twenty-node face has exactly ONE unclimbable column per edge
-- column and reads as a rounding error in a per-mille figure. What the user
-- saw is the DROP, and the two numbers below are it:
--
--   * `perimeter`  the step between a column on the civic core's own edge and
--                  the column one outside it, over all 384 of them. The core
--                  is flat at the fitted reference by contract and the ground
--                  outside it is whatever `capital_terrace_value` leaves, so
--                  this is the height of the pad's own face. It measured 17 to
--                  28 nodes over the nine seeds before `wp40/height.lua`'s
--                  `cenote_terrace` apron and is the terrace step afterwards.
--   * `land_land`  the worst fall between any two 4-adjacent LAND columns in
--                  the envelope, which catches the second wall of the same
--                  cause: the cenote's own rim, held at the water floor by
--                  `water_banks.protect` with the graded delta 20 to 30 nodes
--                  below it one column away.
--
-- Land against WATER is reported and not gated. The cenote's bed is
-- `water_y - varied_depth(deep_cenote.depth)` -- a flat-bottomed bowl with a
-- twelve-node side -- and that side is the `deep_cenote` HYDRO PROFILE's, not
-- the `cenote_terrace` shape's. It is entirely below the water surface, it did
-- not move in either direction here, and section 7 of
-- `docs/research/wp13-kezamba.md` carries it as an open point.
--
-- AND THE APRON'S OWN TWO NUMBERS, which exist because the independent review
-- of 2026-09-16 found that the safety ARGUMENT for the apron was false while
-- the apron itself was fine. `wp40/height.lua` claims both of its cones are
-- `step`-Lipschitz; the lake cone's first two formulations were not (worst own
-- 4-neighbour step 54 nodes, from a pruning cut-off and the reach's taper
-- gradient), and up to a 6-node face leaked into the shipped field where the
-- ground had had none. A claim of that kind must be gated and not asserted, so:
--
--   * `cone_step`  -- the lake cone's OWN worst 4-neighbour step, computed here
--                     from the authored geometry alone, over the whole window
--                     the cone can reach. The ceiling is the terrace step, and
--                     it is not a tuning knob: it is the theorem.
--   * `apron_faces` -- over-step falls in the SHIPPED field where the apron is
--                     the binding constraint on the HIGHER column, which is the
--                     single-tree form of "a face the apron made or deepened".
--                     The ceiling is the coordinator's, from the fix round.
--   * `apron_below` -- columns where the shipped height is BELOW the apron
--                     floor this file computes, which cannot happen if this
--                     file's copy of the cone matches `height.lua`'s. It is the
--                     cross-check that the copy has not drifted, and its
--                     ceiling is zero.
--
-- THE COPY IS A COPY, and that is the price of measuring a private function
-- from outside. It reads the same `source.hydrology` rows and the same three
-- constants; `apron_below` is what turns a drift into a red gate rather than a
-- silent zero.
--
-- THE CEILINGS ARE MEASUREMENTS. `PERIMETER_CEILING` is the race's own terrace
-- step, which is the user's ruling turned into a number and is not a tuning
-- knob. `WALL_CEILING` is the worst `land_land` fall measured on the nine
-- seeds with the apron in, with headroom; a change that pushes it past this is
-- a capital growing walls again and is a decision with a number attached.
if walls then
	local PERIMETER_CEILING = 3      -- the troll terrace step
	local WALL_CEILING = 14
	-- `wp40/height.lua`'s own three, copied: the shape's terrace step, the
	-- shore hold, and the civic width the Chebyshev cone is measured from.
	local APRON_STEP = 3
	local APRON_HOLD = 2
	local APRON_SPACING = 16
	local APRON_REACH = 64
	local APRON_FACE_CEILING = 9
	local CORE_LOW, CORE_HIGH = -CORE - 1, CORE   -- the half-open [-48, 47]
	local failures = 0

	-- The reach's sample discs, exactly as `fitting_grids.apron.value` builds
	-- them: every wet reach whose zone owns this capital.
	local ANCHOR_ZONE = 29           -- kragmar_kezamba
	local profile_by_id = {}
	for index = 1, #source.hydrology_profiles do
		profile_by_id[source.hydrology_profiles[index].id] =
			source.hydrology_profiles[index]
	end
	local discs = {}
	for index = 1, #source.hydrology do
		local row = source.hydrology[index]
		local profile = profile_by_id[row.profile_id]
		if row.zone_numeric_id == ANCHOR_ZONE and profile.depth > 0 then
			local line = row.centreline
			local rim = 1 + row.water_surface_offset + 1
			for point = 1, #line do
				local sample = line[point]
				discs[#discs + 1] = {x = sample.x, z = sample.z,
					half_width = sample.half_width, rim = rim,
					limit = sample.half_width + APRON_REACH}
				local next_sample = line[point + 1]
				if next_sample then
					local vx = next_sample.x - sample.x
					local vz = next_sample.z - sample.z
					local length = deterministic.isqrt(vx * vx + vz * vz)
					local parts = deterministic.floor_div(
						length + APRON_SPACING - 1, APRON_SPACING)
					for part = 1, parts - 1 do
						local half = sample.half_width +
							deterministic.round_ratio(
								(next_sample.half_width - sample.half_width) *
								part, parts)
						discs[#discs + 1] = {
							x = sample.x +
								deterministic.round_ratio(vx * part, parts),
							z = sample.z +
								deterministic.round_ratio(vz * part, parts),
							half_width = half, rim = rim,
							limit = half + APRON_REACH}
					end
				end
			end
		end
	end
	if #discs == 0 then
		error("kezamba walls: the capital's own cenote is absent", 0)
	end

	local function lake_cone(wx, wz)
		local best
		for index = 1, #discs do
			local disc = discs[index]
			local dx, dz = wx - disc.x, wz - disc.z
			local square = dx * dx + dz * dz
			if square <= disc.limit * disc.limit then
				local outside = deterministic.isqrt(square) - disc.half_width
				if outside < APRON_HOLD then outside = APRON_HOLD end
				local value = disc.rim - APRON_STEP * (outside - APRON_HOLD)
				if best == nil or value > best then best = value end
			end
		end
		return best
	end

	-- The civic cone, from the same half-open square `height.lua` uses.
	local function civic_outside_at(x, z)
		return math.max(0, CORE_LOW - x, x - CORE_HIGH, CORE_LOW - z,
			z - CORE_HIGH)
	end

	-- THE CONE'S OWN LIPSCHITZ BOUND, from the authored geometry only: no seed,
	-- no height session, no terrain. The window is every column within the
	-- widest disc plus the distance the cone takes to fall a hundred nodes,
	-- which is further than any ground this delta carries.
	local cone_worst, cone_at, cone_columns = 0, "-", 0
	-- `WATER_LEVEL - 24`, the value `height.lua`'s own `final_terrain_height_at`
	-- returns for a column outside the map: a cone below it can never be the
	-- maximum of anything and may therefore be pruned.
	local CONE_INERT = 1 - 24
	local cone_edges = 0
	do
		local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge,
			-math.huge
		for index = 1, #discs do
			local disc = discs[index]
			local span = disc.half_width + APRON_HOLD + 40
			if disc.x - span < min_x then min_x = disc.x - span end
			if disc.x + span > max_x then max_x = disc.x + span end
			if disc.z - span < min_z then min_z = disc.z - span end
			if disc.z + span > max_z then max_z = disc.z + span end
		end
		local previous
		for z = min_z, max_z do
			local row = {}
			for x = min_x, max_x do row[x] = lake_cone(x, z) end
			for x = min_x, max_x do
				local here = row[x]
				if here ~= nil then
					cone_columns = cone_columns + 1
					local neighbours = {row[x + 1], row[x - 1],
						previous and previous[x] or nil}
					for index = 1, 3 do
						local other = neighbours[index]
						if other ~= nil then
							local delta = here > other and here - other or
								other - here
							if delta > cone_worst then
								cone_worst, cone_at = delta, x .. "," .. z
							end
						elseif x + index <= max_x + 1 and here > CONE_INERT then
							-- The one place the cone can be discontinuous is
							-- where a disc leaves `APRON_REACH`, and that is
							-- only allowed because the cone there is already
							-- below the floor the height session itself
							-- returns outside the map. A neighbour with no
							-- cone at all beside a cone ABOVE that floor would
							-- be the review's pruning cliff, back again.
							cone_edges = cone_edges + 1
						end
					end
				end
			end
			previous = row
		end
	end
	io.write("kezamba_apron_cone\tcolumns\t", cone_columns,
		"\tworst_own_step\t", cone_worst, "\tat\t", cone_at,
		"\tceiling\t", APRON_STEP, "\tlive_prune_edges\t", cone_edges, "\n")
	if cone_edges ~= 0 then
		failures = failures + 1
		io.write("FAIL\t", cone_edges, " column(s) lose their last disc while ",
			"the cone still stands above ", CONE_INERT,
			", which is a pruning cliff and not an inert window\n")
	end
	if cone_worst > APRON_STEP then
		failures = failures + 1
		io.write("FAIL\tthe lake cone's own worst 4-neighbour step is ",
			cone_worst, " against the terrace step of ", APRON_STEP,
			", so `wp40/height.lua`'s Lipschitz claim is false\n")
	end

	io.write("kind\tseed\treach\tland\tperimeter_min\tperimeter_max",
		"\tperimeter_mean_x100\tworst_land_land\tat\tover_step",
		"\tworst_land_water\tapron_faces\tapron_below\n")
	for seed_index = 1, #SEEDS do
		local seed = SEEDS[seed_index]
		local horizontal = horizontal_factory({source = source,
			schemas = schemas, canonical = canonical,
			deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
		local height = height_factory({source = source, canonical = canonical,
			deterministic = deterministic, raw_sha256 = raw_sha256,
			horizontal_session = horizontal,
			coupled_grade = coupled_grade}).new_runtime(seed)
		local anchor = height.selected_anchor_3d_by_id(ANCHOR_ID)
		if type(anchor) ~= "table" then
			error("kezamba walls: the capital anchor is absent", 0)
		end
		-- One pass over the window, heights and land class read once per
		-- column: the whole +-250 envelope is 251 001 columns and every one of
		-- them is asked about by four neighbours.
		local ys, land = {}, {}
		for z = -walls_reach - 1, walls_reach + 1 do
			local row_y, row_land = {}, {}
			for x = -walls_reach - 1, walls_reach + 1 do
				local wx, wz = anchor.x + x, anchor.z + z
				row_y[x] = height.terrain_height_at(wx, wz)
				row_land[x] = horizontal.water_class_at(wx, wz) == "land"
			end
			ys[z], land[z] = row_y, row_land
		end
		-- The apron floor of every column of the window, from this file's own
		-- copy of the two cones. `binding` is the column where the shipped
		-- height IS that floor, which is where the apron decided the ground.
		local apron, binding = {}, {}
		for z = -walls_reach - 1, walls_reach + 1 do
			local row_apron, row_binding = {}, {}
			for x = -walls_reach - 1, walls_reach + 1 do
				local outside = civic_outside_at(x, z)
				local floor_y
				if outside > 0 then
					floor_y = anchor.y - APRON_STEP * outside
					local from_water = lake_cone(anchor.x + x, anchor.z + z)
					if from_water ~= nil and from_water > floor_y then
						floor_y = from_water
					end
				end
				row_apron[x] = floor_y
				row_binding[x] = floor_y ~= nil and land[z][x] and
					ys[z][x] == floor_y
			end
			apron[z], binding[z] = row_apron, row_binding
		end

		local land_columns, over_step = 0, 0
		local apron_faces, apron_below = 0, 0
		local worst_land, worst_at, worst_water = 0, "-", 0
		for z = -walls_reach, walls_reach do
			for x = -walls_reach, walls_reach do
				if land[z][x] then
					land_columns = land_columns + 1
					local here = ys[z][x]
					-- The shipped ground may never stand BELOW the apron floor:
					-- the apron is a `max`, so a column that does is this
					-- file's copy of the cone disagreeing with `height.lua`'s.
					if apron[z][x] ~= nil and here < apron[z][x] then
						apron_below = apron_below + 1
					end
					for side = 1, 4 do
						local nx, nz = x, z
						if side == 1 then nx = x + 1
						elseif side == 2 then nx = x - 1
						elseif side == 3 then nz = z + 1
						else nz = z - 1 end
						local drop = here - ys[nz][nx]
						if land[nz][nx] then
							if drop > PERIMETER_CEILING then
								over_step = over_step + 1
								-- The apron made or deepened this face only if
								-- it is what lifted the HIGHER of the two.
								if binding[z][x] then
									apron_faces = apron_faces + 1
								end
							end
							if drop > worst_land then
								worst_land, worst_at = drop, x .. "," .. z
							end
						elseif drop > worst_water then
							worst_water = drop
						end
					end
				end
			end
		end
		-- The civic core's own face: every edge column against the column one
		-- step outside it, all four sides.
		local low, high, total = 9999, -9999, 0
		for at = CORE_LOW, CORE_HIGH do
			local steps = {ys[CORE_LOW][at] - ys[CORE_LOW - 1][at],
				ys[CORE_HIGH][at] - ys[CORE_HIGH + 1][at],
				ys[at][CORE_LOW] - ys[at][CORE_LOW - 1],
				ys[at][CORE_HIGH] - ys[at][CORE_HIGH + 1]}
			for index = 1, 4 do
				local step = steps[index]
				total = total + step
				if step < low then low = step end
				if step > high then high = step end
			end
		end
		local count = 4 * (CORE_HIGH - CORE_LOW + 1)
		io.write(table.concat({"kezamba_walls", seed, walls_reach,
			land_columns, low, high,
			math.floor(total * 100 / count), worst_land, worst_at, over_step,
			worst_water, apron_faces, apron_below}, "\t"), "\n")
		if apron_faces > APRON_FACE_CEILING then
			failures = failures + 1
			io.write("FAIL\tthe apron is the binding constraint on the high ",
				"side of ", apron_faces, " over-step faces on ", seed,
				" against a ceiling of ", APRON_FACE_CEILING, "\n")
		end
		if apron_below ~= 0 then
			failures = failures + 1
			io.write("FAIL\t", apron_below, " column(s) on ", seed,
				" stand below this file's copy of the apron floor, which a ",
				"`max` cannot do: the copy has drifted from wp40/height.lua\n")
		end
		if high > PERIMETER_CEILING then
			failures = failures + 1
			io.write("FAIL\tthe civic pad on ", seed, " ends in a face of ",
				high, " nodes against the terrace step of ",
				PERIMETER_CEILING, "\n")
		end
		if worst_land > WALL_CEILING then
			failures = failures + 1
			io.write("FAIL\ta land wall of ", worst_land, " nodes at ",
				worst_at, " on ", seed, " against a ceiling of ",
				WALL_CEILING, "\n")
		end
	end
	if failures ~= 0 then
		io.write("kezamba_walls FAIL: ", failures,
			" wall measurement(s) past their ceiling\n")
		os.exit(1)
	end
	io.write("kezamba_walls PASS: the lake cone is ", APRON_STEP,
		"-Lipschitz, the civic pad steps down at the terrace step, no land ",
		"wall exceeds ", WALL_CEILING, " nodes and the apron is the high side ",
		"of at most ", APRON_FACE_CEILING, " over-step faces, on all ",
		#SEEDS, " seeds\n")
	os.exit(0)
end

if field_path then
	local mask = dofile(wp13 .. "/kezamba_lagoon.lua")()
	local heights, land, reach = {}, {}, nil
	for line in io.lines(field_path) do
		if line:sub(1, 1) ~= "#" then
			local z, hs, ls = line:match("^(-?%d+)\t([^\t]*)\t(%S*)$")
			if z then
				z = tonumber(z)
				local row = {}
				for value in hs:gmatch("%-?%d+") do
					row[#row + 1] = tonumber(value)
				end
				reach = reach or (#row - 1) / 2
				heights[z], land[z] = row, ls
			end
		end
	end
	assert(reach and reach > CORE, "the field TSV carries no rows")
	local function height_at(x, z) return heights[z][x + reach + 1] end
	local function wet_at(x, z)
		return land[z]:sub(x + reach + 1, x + reach + 1) ~= "1"
	end
	local core_wet, core_bad = 0, 0
	local envelope_wet, envelope_bad = 0, 0
	local dry_low, dry_high = 9999, -9999
	local wet_low, wet_high = 9999, -9999
	local ravine_low, ravine_high = 9999, -9999
	for z = -reach, reach do
		for x = -reach, reach do
			local engine_wet = wet_at(x, z)
			local mask_wet = mask.lagoon(x, z) and true or false
			if engine_wet then envelope_wet = envelope_wet + 1 end
			if engine_wet ~= mask_wet then envelope_bad = envelope_bad + 1 end
			if x >= -CORE and x <= CORE and z >= -CORE and z <= CORE then
				local y = height_at(x, z)
				if engine_wet then
					core_wet = core_wet + 1
					if y < wet_low then wet_low = y end
					if y > wet_high then wet_high = y end
				elseif mask.ravine(x, z) then
					if y < ravine_low then ravine_low = y end
					if y > ravine_high then ravine_high = y end
				else
					if y < dry_low then dry_low = y end
					if y > dry_high then dry_high = y end
				end
				if engine_wet ~= mask_wet then core_bad = core_bad + 1 end
			end
		end
	end
	io.write(string.format(
		"kezamba_field\treach=%d\tcore_wet=%d\tcore_disagreements=%d" ..
		"\tenvelope_wet_engine=%d\tenvelope_wet_mask=%d" ..
		"\tenvelope_disagreements=%d\tdry_y=%d..%d\travine_y=%d..%d" ..
		"\twet_y=%d..%d\treference_y=%d\twater_surface_y=%d\n",
		reach, core_wet, core_bad, envelope_wet, mask.LAGOON_COLUMNS,
		envelope_bad, dry_low, dry_high, ravine_low, ravine_high,
		wet_low, wet_high, mask.REFERENCE_Y, mask.WATER_SURFACE_Y))
	if envelope_bad ~= 0 then
		io.write("kezamba_field FAIL: the engine's water class differs from ",
			"the committed lagoon mask on ", envelope_bad, " columns\n")
		os.exit(1)
	end
	io.write("kezamba_field PASS: the engine's own field agrees with the ",
		"committed mask on every one of the ", (2 * reach + 1) * (2 * reach + 1),
		" columns it covers\n")
	os.exit(0)
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
-- Kezamba's one hole in the pad: the CENOTE. And the RAVINE, which was a
-- ROUTE and is now empty.
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
-- it is flat over 6 380 of its 9 025 columns and not over the other 2 645, and
-- that exception is WP40's own authored geometry rather than noise:
--
--   * THE CENOTE. `hydro_kezamba_cenote` is a `deep_cenote` of four basins at
--     fixed world coordinates, and its north-east wedge reaches into the core.
--     The lake's surface stands at y = 65 -- exactly ONE NODE below the fitted
--     reference of 66 -- on every seed measured, which is the WP40 water
--     correction of 2026-09-13 doing what it says: the civic water minimum is a
--     hard floor under the reference solver.
--   * THE RAVINE IS EMPTY, and the story is worth keeping. Until WP40's routes
--     were taught to END at the capital gates (the wave-2 route lane, main
--     `0518a01b`), one graded ROUTE CORRIDOR ran diagonally through the pad
--     from its south-west edge and cut up to 26 nodes into it. This fixture
--     measured that as a ravine, and the composition was built around it as a
--     gorge. With the routes stopping at the gate points, every dry column of
--     the core stands at the reference on all nine seeds and the union is zero
--     columns wide. The mask stays in the module as an API and a GUARD: the
--     composition still refuses to lay a lane or stand a stilt in a ravine
--     column, so if a later terrain package cuts the pad again, `--verify`
--     turns red here and the refusals fire there.
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
