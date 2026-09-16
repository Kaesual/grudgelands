-- What the whole street overlay of a capital COSTS, with no WP40 construction
-- in the way.
--
--     luajit tools/wp13/evidence/20260916-streets-r4/overlay_bench.lua <repo> <label>
--
-- Round 4's copy of wave 3's bench, identical but for this header and for the
-- two run-spec fields the seam hands a run (`plain_verge`, `clear_verge`): a
-- tree that carries neither builds the road it used to, so the same file still
-- times `main` and this branch.
--
-- The junction plateau reads the ground of the OTHER run's window as well as
-- its own, so it costs columns. This measures how many and how long, per
-- capital, over a synthetic terraced surface that is the same on both trees:
-- every street run of every capital, built once, timed with `os.clock`, with
-- the run's own `surface` call count beside it.
--
-- It runs unchanged on `main` and on this branch -- it asks the composition for
-- its runs and hands each of them to the overlay's own `run`, so a tree whose
-- run list carries no junctions simply builds the road it used to.
--
-- THE SEAM MEMOISES. `wp40/r7_settlement.lua` keeps one `column_values_at`
-- answer per column per session, so a column two runs both read is paid for
-- once in the engine and twice here; `queries` is therefore an upper bound on
-- what the engine pays, not the number itself.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local label = arg[2] or "tree"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"

local palettes = dofile(wp13 .. "/palette.lua")
local elf_parts = dofile(wp13 .. "/elf_parts.lua")(wp13)
local settlement = dofile(wp40 .. "/r7_settlement.lua")

-- A terraced hillside with cross fall, deterministic and cheap: the point is
-- the overlay's own work, not the terrain's.
local function surface(x, z)
	local base = 60 + math.floor(x / 11) - math.floor(z / 7)
	local terrace = base - (base % 3)
	if (x + z) % 97 == 0 then terrace = terrace + 2 end
	return terrace
end
local function wet(x, z)
	return (x % 211) < 8 and z > -200
end

local KEYS = {"highcourt", "dur_brannoc", "gor_drazhak", "lethariel",
	"kezamba", "nhal_veyr"}

local function is_road(id)
	return not (id:match("^wall_") or id:match("^edge_") or id:match("^gate_"))
end

io.write("capital\t", label, "_ms\tcells\tqueries\truns\n")
local total_ms, total_queries = 0, 0
for _, key in ipairs(KEYS) do
	local profile
	for index = 1, #settlement.roster do
		if settlement.roster[index].key == key then
			profile = settlement.roster[index]
		end
	end
	local source = dofile(wp40 .. "/r7_" .. key .. "_blueprint.lua")()
	local overlay = source.overlay
	local runs = {}
	for _, run in ipairs(overlay.runs) do
		if is_road(run.id) then runs[#runs + 1] = run end
	end
	-- Warm the loaders before the clock starts.
	local _ = palettes.new(profile.race)
	local _ = elf_parts.handles
	local started = os.clock()
	local cells, queries = 0, 0
	for _, run in ipairs(runs) do
		local piece = overlay.run({id = run.id, axis = run.axis, at = run.at,
			from = run.from, to = run.to, width = overlay.width,
			lamp_spacing = overlay.lamp_spacing, lamp_phase = run.from,
			reach = overlay.reach, wet = wet, junctions = run.junctions,
			plain_verge = run.plain_verge, clear_verge = run.clear_verge},
			surface)
		cells = cells + #piece.cells
		queries = queries + (piece.queries or 0)
	end
	local ms = (os.clock() - started) * 1000
	total_ms = total_ms + ms
	total_queries = total_queries + queries
	io.write(string.format("%s\t%.1f\t%d\t%d\t%d\n", key, ms, cells, queries,
		#runs))
end
io.write(string.format("TOTAL\t%.1f\t-\t%d\t-\n", total_ms, total_queries))
