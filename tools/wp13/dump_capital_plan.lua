-- dump_capital_plan.lua -- print a WHOLE capital on one flat plane, as TSV.
--
--     luajit tools/wp13/dump_capital_plan.lua <repo> <key> [<world seed>]
--
-- The civic core, every district plot and dressing at the offsets a world's
-- permutation gives it, and every run of the overlay -- avenues, ring street,
-- district lanes and, for a walled capital, the curtain and its gates. The
-- ground is FLAT, so the terraces the plots really stand on are not in it, and
-- that is exactly what makes the picture readable as a PLAN: which district
-- took which quarter, how its lots sit round the ring street's corner, how far
-- out the far lot stands, and how dense the whole envelope is. It is the
-- picture a reader needs to compare one capital's density with another's by
-- eye, which is the comparison
-- docs/research/wp13-capitals-pois-contract.md section 2.3 asks for and no
-- number answers.
--
-- This is `tools/wp13/dump_highcourt.lua`'s `capital` subject with the capital
-- lifted out of it; that file is the pilot capital's own dumper and stays as it
-- is. Any capital works here as long as its composition publishes `core`,
-- `avenues`, `ring`, `overlay_runs`, `overlay_run` and either `districts`
-- (four districts, with `resolve`) or `district` (one).
--
-- WITHOUT A SEED the canonical assignment is drawn -- the roles in authored
-- order -- and the label on stderr says so. With one, the seeded permutation
-- is, computed exactly the way `r7_runtime.lua` computes it, so the plan is the
-- plan of that world.
--
-- Plain Lua 5.1, no engine.

local repo = assert(arg[1], "repository root required")
local key = assert(arg[2], "settlement key required")
local full_seed = arg[3]

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local capital = dofile(wp13 .. "/" .. key .. ".lua")(wp13)
local common = dofile(repo .. "/tools/wp40/r6/common.lua")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local profile
for index = 1, #settlement.roster do
	if settlement.roster[index].key == key then
		profile = settlement.roster[index]
	end
end
assert(profile and profile.slot == "capital",
	"the roster carries no capital called " .. key)

-- The plot list, with this world's offsets. A capital with four districts
-- resolves them against the permutation; a capital with one publishes its
-- plots directly and has nothing to permute.
local options = nil
if full_seed then
	assert(full_seed:match("^%-?%d+$"), "the seed must be decimal")
	options = {full_seed = full_seed, raw_sha256 = common.new_sha256()}
end
local resolved, assignment
if type(capital.districts) == "table" and
		type(capital.districts.resolve) == "function" then
	resolved, assignment = capital.districts.resolve(options)
elseif type(capital.district) == "table" then
	resolved = capital.district.plots
else
	error("the composition of " .. key .. " publishes no district plots", 0)
end

local cells, seen = {}, {}
local function emit(x, y, z, name, param2)
	local position = x .. ":" .. y .. ":" .. z
	if seen[position] then return end
	seen[position] = true
	cells[#cells + 1] = {x = x, y = y, z = z, name = name,
		param2 = param2 or 0}
end

local core = capital.core()
for _, cell in ipairs(core.cells) do
	emit(cell.x, cell.y, cell.z, cell.name, cell.param2)
end
for _, entry in ipairs(resolved) do
	for _, cell in ipairs(entry.build().cells) do
		emit(entry.x + cell.x, cell.y, entry.z + cell.z, cell.name,
			cell.param2)
	end
end

-- The whole overlay, in the composition's own run order, so the plan shows the
-- wall ring and its gates and not only the roads inside it. `emit` keeps the
-- FIRST writer of a cell, which is the same first-run-wins arbitration the
-- successor applies, so an avenue rides through its gate here too.
local road = palettes.new(profile.race)
local function flat() return 0 end
local lanes = {}
if type(capital.quadrants) == "table" and
		type(capital.quadrants.lane_runs) == "function" then
	lanes = capital.quadrants.lane_runs()
end
for _, spec in ipairs(capital.overlay_runs(lanes)) do
	-- The three fields the seam fills in from the overlay's own declaration
	-- (`r7_settlement.lua` builds a per-run spec out of the blueprint's
	-- `width`, `lamp_spacing` and `reach`) travel with the run here too: the
	-- causeway rail reads `spec.width` to find its kerb lanes, and a run
	-- without one is refused rather than railed down the middle.
	local piece = capital.overlay_run(avenue, road,
		{id = spec.id, axis = spec.axis, at = spec.at, from = spec.from,
			to = spec.to, lamp_phase = spec.from, width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING, reach = avenue.REACH}, flat)
	for _, cell in ipairs(piece.cells) do
		emit(cell.x, cell.y, cell.z, cell.name, cell.param2)
	end
end

-- The ground everything stands on, so the plan reads as a city on a plain
-- rather than as pieces floating in the dark.
local GROUND = palettes.new(profile.race).node("ground")
for z = -262, 262 do
	for x = -262, 262 do
		emit(x, -1, z, GROUND, 0)
	end
end

local out = {}
for _, cell in ipairs(cells) do
	out[#out + 1] = string.format("%d\t%d\t%d\t%s\t%d\n",
		cell.x, cell.y, cell.z, cell.name, cell.param2 or 0)
end
io.write(table.concat(out))

local label = key .. " plan"
if assignment then
	local roles = {}
	for role in pairs(assignment) do roles[#roles + 1] = role end
	table.sort(roles)
	for index = 1, #roles do
		roles[index] = roles[index] .. "=" .. assignment[roles[index]].quadrant
	end
	label = label .. " " .. table.concat(roles, " ")
end
io.stderr:write(string.format("%s: %d plots, %d cells, seed %s\n", label,
	#resolved, #cells, full_seed or "canonical"))
