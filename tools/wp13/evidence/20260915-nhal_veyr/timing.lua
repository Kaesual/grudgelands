-- Build time of Nhal Veyr, against the capitals contract's section 2.3 budget.
--
--     luajit  tools/wp13/evidence/20260915-nhal_veyr/timing.lua . luajit
--     tools/bin/lua51 tools/wp13/evidence/20260915-nhal_veyr/timing.lua . puc51
--
-- WHY THIS IS HERE AND NOT `tools/wp13/capital_timing.lua`. That file is the
-- generalised harness Dur Brannoc landed, and it is generalised over the wrong
-- axis for this capital: it reads `capital.district.plots` -- ONE district --
-- and it builds the road with `palettes.new("dwarf")`. Nhal Veyr has four
-- districts and sixteen fill dressings behind `nhal_veyr_districts.resolve()`
-- and an undead palette, so the harness answers nothing about it. Two lines
-- would fix that (take the race from the roster profile, and take the plot
-- list from the source rather than from a `district` field), but
-- `capital_timing.lua` is Lane D's file in the wave-2 brief's ownership and
-- this lane's timing is not worth a merge conflict in somebody else's tool.
-- The gap is named in the lane report; this file is the measurement.
--
-- Times are `os.clock` seconds -- CPU time -- reported as milliseconds with
-- three digits. Nothing here is part of any digest: a timing is the one thing
-- two interpreters must NOT agree on.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local label = assert(arg[2], "interpreter label required")

local function ms(seconds) return string.format("%.3f", seconds * 1000) end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"

local started = os.clock()
local palettes = dofile(wp13 .. "/palette.lua")
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local capital = dofile(wp13 .. "/nhal_veyr.lua")(wp13)
local districts = dofile(wp13 .. "/nhal_veyr_districts.lua")(wp13)
local load_time = os.clock() - started

-- One construction of each, timed on its own. A second construction of the
-- core follows, because the first also warms whatever the interpreter caches
-- and the successor's lazy construction pays the warm price on every capital
-- but the first.
started = os.clock()
local core = capital.core()
local core_time = os.clock() - started

started = os.clock()
capital.core()
local core_again = os.clock() - started

started = os.clock()
local resolved = districts.resolve()
local plot_cells, worst, worst_id = 0, 0, "-"
for _, entry in ipairs(resolved) do
	local built = entry.build()
	plot_cells = plot_cells + #built.cells
	if #built.cells > worst then worst, worst_id = #built.cells, entry.id end
end
local plots_time = os.clock() - started

local undead = palettes.new("undead")
local function surface(x, z)
	local height = 20 + math.floor((x + 128) / 32) * 2
	if z <= -2 then height = height - 1 end
	return height
end
started = os.clock()
local run = avenue.run(undead, {id = "timing", axis = "x", at = 0,
	from = -256, to = -48}, surface)
local avenue_time = os.clock() - started

-- And the seam's own two costs, which are what a server actually pays:
--
--   * PREPARE, once at load: every blueprint of the capital built, validated,
--     canonically serialised and hashed, then released again;
--   * THE LAZY REBUILD, on the first mapchunk that touches the envelope: the
--     core built again, hashed again and compared with the published identity.
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local sha = common.new_sha256()
local profile
for index = 1, #settlement.roster do
	if settlement.roster[index].key == "nhal_veyr" then
		profile = settlement.roster[index]
	end
end
assert(profile and profile.slot == "capital",
	"the roster carries no capital called nhal_veyr")
local source_factory = dofile(wp40 .. "/" .. profile.blueprint_file)

started = os.clock()
local prepared = settlement.prepare(profile, source_factory(), sha)
local prepare_time = os.clock() - started

started = os.clock()
local rebuilt = settlement.prepare(profile, source_factory(), sha)
local rebuild_time = os.clock() - started

local prepared_cells = 0
for index = 1, #prepared.blueprints do
	prepared_cells = prepared_cells + (prepared.blueprints[index].cells and
		#prepared.blueprints[index].cells or 0)
end

io.write(table.concat({"subject", "interpreter", "ms", "cells"}, "\t"), "\n")
local function row(subject, seconds, cells)
	io.write(table.concat({subject, label, ms(seconds), cells or "-"},
		"\t"), "\n")
end
row("module_load", load_time)
row("core", core_time, #core.cells)
row("core_second", core_again, #core.cells)
row("plots_52", plots_time, plot_cells)
row("avenue_run_209", avenue_time, #run.cells)
row("seam_prepare", prepare_time, prepared_cells)
row("seam_prepare_again", rebuild_time, prepared_cells)
io.write(table.concat({"largest_plot", label, "-", worst .. ":" .. worst_id},
	"\t"), "\n")
io.write(table.concat({"whole_capital", label, "-",
	(#core.cells + plot_cells)}, "\t"), "\n")
io.write(table.concat({"blueprints", label, "-", #rebuilt.blueprints},
	"\t"), "\n")
