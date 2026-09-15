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
-- Prints one TSV row per subject: the module load, one core construction, the
-- four districts (all thirty-six plots) and the avenue overlay over a
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

-- All four districts, thirty-six plots, in the order the capital source hands
-- them to the seam. The offsets are this run's canonical assignment and do not
-- matter here: a plot's cells are the same wherever it stands.
local districts_module = dofile(wp13 .. "/highcourt_districts.lua")(wp13)
local district_roster = districts_module.resolve()
started = os.clock()
local district_cells = 0
for _, entry in ipairs(district_roster) do
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

-- And the seam's own two costs, which are what a server actually pays
-- (`wp40/r7_settlement.lua`, contract section 2.2.4):
--
--   * PREPARE, once at load: every blueprint of the capital built, validated,
--     canonically serialised and hashed, then its cells released again. This is
--     the price of publishing a closed identity document for a lazy settlement.
--   * THE LAZY REBUILD, on the first mapchunk that touches the envelope: the
--     core built again, hashed again and compared with the published identity,
--     and its cells mapped onto the shared content channel.
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local sha = common.new_sha256()
local profile
for index = 1, #settlement.roster do
	if settlement.roster[index].slot == "capital" then
		profile = settlement.roster[index]
	end
end
assert(profile, "the roster carries no capital")
local source = dofile(wp40 .. "/" .. profile.blueprint_file)()
started = os.clock()
local prepared = settlement.prepare(profile, source, sha)
local prepare_time = os.clock() - started

local union = prepared.palette
local ref_by_name = {}
for index = 1, #union do ref_by_name[union[index]] = index end
local content = {schema = "grug_wp13_settlement_content_v1",
	content_names = union}
function content.content_ref(name) return ref_by_name[name] end
function content.resolve(ref, param2) return 1000 + ref, param2 end
local config = settlement.config(prepared, content, sha)
local planner_source = {}
function planner_source.column_values_at(x, z)
	return "land", 1, "zone", "biome", "region", 40
end
local tail = config.new({planner_source = planner_source,
	zones_session = {anchor = function(zone_id, slot)
		if zone_id == profile.zone_id and slot == profile.slot then
			return {id = profile.anchor_id, numeric_id = profile.numeric_id,
				x = profile.x, y = 40, z = profile.z}
		end
	end}})
local plan = {}
tail:bind_plan({x = profile.x - 40, y = 0, z = profile.z - 40},
	{x = profile.x + 39, y = 79, z = profile.z + 39}, plan, 1)
local written = 0
started = os.clock()
tail:settle({plan = plan, generation = 1, call_mode = "fixture",
	min_x = profile.x - 40, min_y = 0, min_z = profile.z - 40,
	max_x = profile.x + 39, max_y = 79, max_z = profile.z + 39,
	inside_owner = function() return true end,
	write_hearthpine = function() written = written + 1 end})
local rebuild_time = os.clock() - started
local seam_metrics = tail:metrics()

io.write(table.concat({"wp13_highcourt_timing", label, "load_ms",
	ms(load_time), "core_ms", ms(core_time), "core_again_ms", ms(core_again),
	"district_ms", ms(district_time), "avenue_ms", ms(avenue_time),
	"seam_prepare_ms", ms(prepare_time), "seam_first_touch_ms",
	ms(rebuild_time),
	"core_cells", #core.cells, "district_cells", district_cells,
	"avenue_cells", #run.cells,
	"capital_cells", #core.cells + district_cells,
	"seam_blueprints", #prepared.blueprints,
	"seam_first_touch_cells", written,
	"seam_builds", seam_metrics.build_calls,
	"seam_height_calls", seam_metrics.height_calls}, "\t"), "\n")
assert(#again.cells == #core.cells, "the two core builds differ")
