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
-- THE CEILINGS below are MEASUREMENTS, not derivations. They were taken on
-- 2026-09-15 with the step bands in place and rounded up, and what each of them
-- replaced is in the same row. A WP40 terrain change may move them; a change
-- that moves one UP past its ceiling is a capital growing walls again, and
-- re-taking a ceiling is a decision with a number attached, not a silent edit.
--
-- Per mille of the window's own land columns, seed 531802985935182545 then
-- 8675309, before the bands / after / ceiling:
--
--     capital_dwarf   (Dur Brannoc) 116  78  85     109  65  75
--     capital_human   (Highcourt)    60   5  15      75  11  20
--     capital_elf     (Lethariel)    42   3  15      50   8  20
--     capital_undead  (Nhal Veyr)    42   2  15      52   5  20
--     capital_orc     (Gor Drazhak)  31   2  15      39   3  20
--     capital_troll   (Kezamba)      91  56  65      97  68  80
--
-- The residue that is left is the ground's own. The same +-250 envelope
-- measured on the UNGRADED relief answers 7 per mille at Highcourt and 26 at
-- Dur Brannoc, against 12 and 27 for the shaped one: the dwarf plateau crosses
-- real crags and the troll one a cenote, and a fitting may not be much worse
-- than the rock it stands on. That, and not zero, is what the ceilings say.
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
	capital_dwarf = {["531802985935182545"] = 85, ["8675309"] = 75},
	capital_human = {["531802985935182545"] = 15, ["8675309"] = 20},
	capital_elf = {["531802985935182545"] = 15, ["8675309"] = 20},
	capital_undead = {["531802985935182545"] = 15, ["8675309"] = 20},
	capital_orc = {["531802985935182545"] = 15, ["8675309"] = 20},
	capital_troll = {["531802985935182545"] = 65, ["8675309"] = 80},
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
		-- One row of the window at a time, so the whole window is never held.
		-- `land` and `y` are read once per column and reused as the previous
		-- row, which is what keeps this two passes over the window and not five.
		local previous_y, previous_land = nil, nil
		local histogram = {0, 0, 0, 0, 0, 0}
		local land_count, worst, unclimbable = 0, 0, 0
		for z = -reach, reach + 1 do
			local row_y, row_land = {}, {}
			if z <= reach then
				for x = -reach, reach + 1 do
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
						if x > -reach then
							consider(previous_y[x - 1], previous_land[x - 1])
						end
						if z <= reach then consider(row_y[x], row_land[x]) end
						local bucket = climb < 5 and climb + 1 or 6
						histogram[bucket] = histogram[bucket] + 1
						if climb > worst then worst = climb end
						if climb > 1 then unclimbable = unclimbable + 1 end
					end
				end
			end
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
