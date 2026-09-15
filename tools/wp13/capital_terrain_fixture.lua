-- Can a player walk a capital?
--
--     luajit tools/wp13/capital_terrain_fixture.lua <repo>
--     luajit tools/wp13/capital_terrain_fixture.lua <repo> <reach>
--
-- WHAT THIS MEASURES AND WHY IT IS A FIXTURE AND NOT A SCRATCH SCRIPT.
--
-- A capital is terraced: `wp40/height.lua` quantises the fitted envelope onto a
-- lattice of the race's own terrace step (2 for the human, 3 for elf, undead
-- and troll, 4 for dwarf and orc). Until WP13 round 3 the risers between those
-- terraces were VERTICAL, and the player's jump height is one node, so every
-- riser was a wall: the user could not climb from one Highcourt terrace to the
-- next and Dur Brannoc's four-node walls were absurd. The fix turns each riser
-- into a band of one-block ground steps, and the property that has to hold
-- afterwards is exactly this measurement -- the share of the capital's own
-- ground from which a land neighbour is more than one node up.
--
-- It cannot be checked on a fixture world. The terraces follow the contours of
-- the real relief, so the only thing that can answer is the real height session
-- on the real gate seeds, which is why this is a LuaJIT development fixture in
-- the shape of `tools/wp13/terrain_fixture.lua` and not part of the portable
-- micro-KAT pair.
--
-- THE CEILINGS below are MEASUREMENTS, not derivations, taken on 2026-09-15
-- with the step bands in place and rounded up. A WP40 terrain change may move
-- them; a change that moves one UP past its ceiling is a capital growing walls
-- again, and re-taking a ceiling is a decision with a number attached.
--
-- Per mille of the window's own land columns, seed 531802985935182545 then
-- 8675309, before the bands / after / ceiling:
--
--     capital_dwarf   (Dur Brannoc) 122  81  90    114  66  75
--     capital_human   (Highcourt)    71   4  10     83   6  10
--     capital_elf     (Lethariel)    51   4  10     58   9  15
--     capital_undead  (Nhal Veyr)    49   3  10     58   6  10
--     capital_orc     (Gor Drazhak)  38   3  10     44   4  10
--     capital_troll   (Kezamba)     103  62  70    108  74  85
--
-- WHAT THE RESIDUE IS, AND WHAT IT IS NOT. It is NOT the ground's own rock.
-- Measured against the UNGRADED relief of the same envelope (+-200, Dur
-- Brannoc, seed 8675309), 59.5 per cent of the columns that are still
-- unclimbable sit where the relief itself steps at most one node -- ground a
-- player could have walked before the fitting shaped it. In the walkable-relief
-- population alone the residue is 25 per mille.
--
-- It is the band on MIXED ground: a gentle pair of columns inside a disc that
-- is not gentle. The exhaustive one-dimensional sweep in the research note
-- gives the bound exactly -- where the whole disc moves at most one node per
-- column the band is 1-Lipschitz, at two nodes per column its worst output step
-- is 2 for step 2 and 3, and 3 for step 4. Dur Brannoc's and Kezamba's
-- envelopes carry a lot of two-node ground, which is why their ceilings are an
-- order above the other four.
--
-- Plain Lua 5.1, LuaJIT in practice; no engine, no globals.

local repo = assert(arg[1], "repository root required")
local reach = tonumber(arg[2] or "128")
assert(reach and reach % 1 == 0 and reach >= 16 and reach <= 250,
	"reach must be a whole number of nodes in 16..250")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()
local horizontal_factory = dofile(wp40 .. "/simple_map.lua")
local height_factory = dofile(wp40 .. "/height.lua")
local coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()

-- The two gate seeds, and nothing else: this fixture is the walkability gate,
-- not a survey.
local SEEDS = {"531802985935182545", "8675309"}

-- Per capital, per seed, in unclimbable land columns per thousand land columns
-- of the +-128 window. Taken 2026-09-15 on the step-band tree.
local CEILING = {
	capital_dwarf = {["531802985935182545"] = 90, ["8675309"] = 75},
	capital_human = {["531802985935182545"] = 10, ["8675309"] = 10},
	capital_elf = {["531802985935182545"] = 10, ["8675309"] = 15},
	capital_undead = {["531802985935182545"] = 10, ["8675309"] = 10},
	capital_orc = {["531802985935182545"] = 10, ["8675309"] = 10},
	capital_troll = {["531802985935182545"] = 70, ["8675309"] = 85},
}

local capitals = {}
for index = 1, #source.anchors do
	local anchor = source.anchors[index]
	if anchor.slot_id == "capital" then
		capitals[#capitals + 1] = {id = anchor.id, template = anchor.template_id,
			zone = anchor.zone_numeric_id}
	end
end
assert(#capitals == 6, "the roster carries " .. #capitals .. " capitals")
local step_by_template = {}
for index = 1, #source.anchor_profiles do
	local profile = source.anchor_profiles[index]
	if profile.terrace_step then
		step_by_template[profile.id] = profile.terrace_step
	end
end

io.write("kind\tseed\tcapital\tstep\tland\tclimb0\tclimb1\tclimb2\tclimb3",
	"\tclimb4\tclimb5plus\tmax\tunclimbable\tper_mille\tceiling\n")
local digest_rows = {}
local failures = 0
for seed_index = 1, #SEEDS do
	local seed = SEEDS[seed_index]
	local horizontal = horizontal_factory({source = source, schemas = schemas,
		canonical = canonical, deterministic = deterministic,
		raw_sha256 = raw_sha256}).new(seed)
	local height = height_factory({source = source, canonical = canonical,
		deterministic = deterministic, raw_sha256 = raw_sha256,
		horizontal_session = horizontal, coupled_grade = coupled_grade}).new_runtime(seed)
	for capital_index = 1, #capitals do
		local capital = capitals[capital_index]
		local anchor = assert(height.selected_anchor_3d_by_id(capital.id),
			"capital anchor missing: " .. capital.id)
		-- THREE ROWS AT A TIME, so a column can be asked about all FOUR of its
		-- neighbours. The first version of this fixture kept two rows and
		-- therefore never looked at -z: it measured three neighbours out of
		-- four and its ceilings were taken against that.
		--
		-- `y` and the land class are read once per column and carried forward,
		-- which is what keeps this one pass over the window and not five.
		local before_y, before_land = nil, nil
		local previous_y, previous_land = nil, nil
		local histogram = {0, 0, 0, 0, 0, 0}
		local land_count, worst, unclimbable = 0, 0, 0
		for z = -reach, reach + 1 do
			local row_y, row_land = nil, nil
			if z <= reach then
				row_y, row_land = {}, {}
				for x = -reach - 1, reach + 1 do
					local wx, wz = anchor.x + x, anchor.z + z
					row_y[x] = height.terrain_height_at(wx, wz)
					row_land[x] = horizontal.water_class_at(wx, wz) == "land"
				end
			end
			if previous_y then
				for x = -reach, reach do
					if previous_land[x] then
						land_count = land_count + 1
						local here, climb = previous_y[x], 0
						local function consider(other_y, other_land)
							if other_land and other_y - here > climb then
								climb = other_y - here
							end
						end
						consider(previous_y[x + 1], previous_land[x + 1])
						consider(previous_y[x - 1], previous_land[x - 1])
						if row_y then consider(row_y[x], row_land[x]) end
						if before_y then consider(before_y[x], before_land[x]) end
						local bucket = climb < 5 and climb + 1 or 6
						histogram[bucket] = histogram[bucket] + 1
						if climb > worst then worst = climb end
						if climb > 1 then unclimbable = unclimbable + 1 end
					end
				end
			end
			before_y, before_land = previous_y, previous_land
			previous_y, previous_land = row_y, row_land
		end
		local per_mille = land_count > 0 and
			math.floor(unclimbable * 1000 / land_count) or 0
		local ceiling = assert(CEILING[capital.template],
			"no ceiling for " .. capital.template)[seed]
		assert(ceiling, "no ceiling for " .. capital.template .. " on " .. seed)
		local row = table.concat({"capital_walk", seed, capital.template,
			step_by_template[capital.template] or 0, land_count,
			histogram[1], histogram[2], histogram[3], histogram[4],
			histogram[5], histogram[6], worst, unclimbable, per_mille,
			ceiling}, "\t")
		io.write(row, "\n")
		digest_rows[#digest_rows + 1] = row
		if per_mille > ceiling then
			failures = failures + 1
			io.write("FAIL\t", capital.template, " on ", seed, " is ", per_mille,
				" per mille unclimbable against a ceiling of ", ceiling, "\n")
		end
	end
end
io.write("capital_walk_digest\t", #digest_rows, "\t",
	canonical.hex(raw_sha256(table.concat(digest_rows, "\n"))), "\n")
assert(failures == 0, failures ..
	" capital window(s) are less walkable than the committed ceiling")
