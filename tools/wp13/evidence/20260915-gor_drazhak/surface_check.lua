-- Hold every plot's real per-column relief to the plot rules, on every seed.
--
--     GRUG_REPO=. luajit surface_check.lua <surface-a.tsv> ...
--
-- The dumps come from `run_capital.sh <out> gor_drazhak surface|full <seed>`,
-- which samples every plot column by column at its position with the same
-- `grug_zones.terrain_height_at` the load-time `r7_settlement.audit_terrain`
-- uses, and with the same sampling pattern (the margin ring, the edge, and
-- every other interior column).
--
-- WHAT IS ASSERTED HERE AND WHAT IS ONLY REPORTED, and the difference is a
-- known defect in a tool this lane does not own:
--
--   * `tools/wp13/capital_probe` builds the blueprint source with NO options,
--     so its plot list carries the CANONICAL quadrant assignment, while the
--     engine's own settlement was built with the SEEDED one. On a world whose
--     permutation is not the identity -- which is most of them -- a dump row
--     therefore names a LOT correctly and pairs it with the wrong district's
--     plot. (The coordinator has this: Lane D is landing the probe fix.)
--   * WATER and PERIMETER FALL are properties of the POSITION and survive that
--     mispairing intact -- every lot is held to the same two-node dry margin
--     and the same six-course skirt, whichever plot stands on it. Those are
--     asserted.
--   * A RISE is checked against the plot's own `clear_to`, and THAT is the
--     pairing the probe gets wrong: a yard clearing 9 may be reported on a lot
--     a hall clearing 13 actually stands on. So a rise over its row's clear is
--     printed as a row to explain, not as a failure, and the authority for it
--     is the engine's own audit -- `nine/audit-nine-seeds.txt`, zero findings
--     on all nine worlds.
--
-- Plain Lua 5.1.
local repo = os.getenv("GRUG_REPO") or "."
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local SKIRT = 6
-- The airspace floor is the plot builder's own constant, read from the module
-- rather than repeated here: the fix round moved it from 8 to 9 and a literal
-- would have gone on asserting the old one.
local CLEAR_FLOOR = dofile(wp13 .. "/gor_drazhak_plot.lua")(wp13).MIN_CLEAR

local worst = {}
local rows, hard, soft = 0, 0, 0
for index = 1, #arg do
	local path = arg[index]
	local file = assert(io.open(path, "r"), "cannot read " .. path)
	local header = file:read("*l")
	assert(header and header:find("perimeter_fall", 1, true), path)
	local columns = {}
	local order = 1
	for name in header:gmatch("[^\t\n]+") do
		columns[name] = order
		order = order + 1
	end
	for line in file:lines() do
		local field = {}
		for value in line:gmatch("[^\t\n]+") do field[#field + 1] = value end
		local id = field[columns.plot]
		local fall = tonumber(field[columns.perimeter_fall])
		local rise = tonumber(field[columns.perimeter_rise])
		local submerged = tonumber(field[columns.submerged])
		local margin = tonumber(field[columns.submerged_margin])
		local clear = tonumber(field[columns.clear_to])
		local wet = field[columns.reference_wet]
		local label = path:match("[^/]+/[^/]+$") or path
		rows = rows + 1
		local why
		if wet == "true" then why = "reference_in_water"
		elseif submerged > 0 then why = "submerged:" .. submerged
		elseif margin > 0 then why = "margin_in_water:" .. margin
		elseif fall > SKIRT then why = "fall:" .. fall
		elseif clear < CLEAR_FLOOR then why = "clear:" .. clear end
		if why then
			hard = hard + 1
			io.write("ILLEGAL\t", id, "\t", label, "\t", why, "\n")
		elseif rise > clear then
			soft = soft + 1
			io.write("EXPLAIN\t", id, "\t", label, "\trise:", rise,
				"/clear:", clear,
				"\t(the probe's canonical-assignment pairing; the engine's ",
				"own audit is the authority and logs none)\n")
		end
		local entry = worst[id] or {fall = 0, rise = 0, clear = clear}
		if fall > entry.fall then entry.fall = fall end
		if rise > entry.rise then entry.rise = rise end
		worst[id] = entry
	end
	file:close()
end

local ids = {}
for id in pairs(worst) do ids[#ids + 1] = id end
table.sort(ids)
local max_fall, max_rise, max_fall_id, max_rise_id = 0, 0, "-", "-"
for _, id in ipairs(ids) do
	local entry = worst[id]
	if entry.fall > max_fall then max_fall, max_fall_id = entry.fall, id end
	if entry.rise > max_rise then max_rise, max_rise_id = entry.rise, id end
end
io.write("rows\t", rows, "\tplots\t", #ids, "\tillegal\t", hard,
	"\tto explain\t", soft, "\n")
io.write("worst perimeter fall\t", max_fall, "\t", max_fall_id,
	"\t(skirt ", SKIRT, ")\n")
io.write("worst rise\t", max_rise, "\t", max_rise_id,
	"\t(airspace floor ", CLEAR_FLOOR, ")\n")
io.write("plot\tworst_fall\tworst_rise\tclear\n")
for _, id in ipairs(ids) do
	local entry = worst[id]
	io.write(id, "\t", entry.fall, "\t", entry.rise, "\t", entry.clear, "\n")
end
if hard > 0 then os.exit(1) end
