-- Build time of the Highcourt capital, against the contract's budget.
--
-- docs/research/wp13-capitals-pois-contract.md section 2.3: "a whole capital
-- stays under 400,000 cells and builds in a few seconds under LuaJIT when
-- first touched. Measure, do not assume: the first capital package records
-- build time under both interpreters."
--
--     luajit tools/wp13/highcourt_timing.lua . luajit
--     tools/bin/lua51 tools/wp13/highcourt_timing.lua . puc51
--
-- Prints one TSV row per subject: the module load, one core construction, one
-- district construction (all nine plots) and the avenue overlay over a
-- 209-node run. Times are `os.clock` seconds, that is CPU time, reported as
-- milliseconds with three digits; the row also carries the cell counts, so a
-- later run can be compared per cell as well as per build.
--
-- The numbers are NOT part of any digest: this file writes to stdout only and
-- is never part of the final micro pair, because a timing is the one thing
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
local highcourt = dofile(wp13 .. "/highcourt.lua")(wp13)
local load_time = os.clock() - started

-- One construction of each, timed on its own. A second construction of the
-- core follows, because the first one also warms whatever the interpreter
-- caches and the successor's lazy construction (contract section 2.2) will
-- pay the warm price on every capital but the first.
started = os.clock()
local core = highcourt.core()
local core_time = os.clock() - started

started = os.clock()
local again = highcourt.core()
local core_again = os.clock() - started

started = os.clock()
local district_cells = 0
for _, entry in ipairs(highcourt.district.plots) do
	district_cells = district_cells + #entry.build().cells
end
local district_time = os.clock() - started

local human = palettes.new("human")
local function surface(x, z)
	local height = 20 + math.floor((x + 128) / 32) * 2
	if z <= -2 then height = height - 1 end
	return height
end
started = os.clock()
local run = avenue.run(human, {id = "timing", axis = "x", at = 0,
	from = -256, to = -48}, surface)
local avenue_time = os.clock() - started

io.write(table.concat({"wp13_highcourt_timing", label, "load_ms",
	ms(load_time), "core_ms", ms(core_time), "core_again_ms", ms(core_again),
	"district_ms", ms(district_time), "avenue_ms", ms(avenue_time),
	"core_cells", #core.cells, "district_cells", district_cells,
	"avenue_cells", #run.cells,
	"capital_cells", #core.cells + district_cells}, "\t"), "\n")
assert(#again.cells == #core.cells, "the two core builds differ")
