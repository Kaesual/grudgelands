-- Dur Brannoc, the dwarf capital, as the R7 seam sees it: not one blueprint
-- but a SOURCE declaring three kinds of them (`r7_settlement.lua`, contract
-- section 2.2.3).
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start;
--   * the 52 plots of the four districts -- nine buildings and four dressings
--     each -- with their own offsets from the capital anchor and their own
--     reference columns, because WP40 terraces the rest of the 512 envelope in
--     four-node steps, the deepest of the six races, and a plot sixty nodes out
--     does not stand at the core's height;
--   * ONE overlay, carrying twenty runs: the four avenues, the four sides of
--     the ring street, the eight district lanes and the four sides of the
--     CURTAIN WALL.
--
-- WHICH DISTRICT STANDS IN WHICH QUADRANT IS THE WORLD SEED'S (the capitals
-- contract, section 2.1). The permutation is `wp13/dur_brannoc_quadrants.lua`,
-- and the seed and the SHA-256 it needs are HANDED TO THIS FILE by
-- `r7_runtime.lua`, which validates the seed once and refuses to build if the
-- live value has moved since. That is what makes main and emerge agree about
-- where a district stands exactly when they agree about `full_seed`. An
-- engine-free caller -- a fixture, the renderer, the timing harness -- can pass
-- no options at all and gets the canonical assignment. Nothing in the manifest
-- moves either way: a plot's identity is its cells, and its cells do not know
-- where they will stand.
--
-- WHY THE WALL IS IN THE SAME OVERLAY AS THE ROAD. The seam gives a settlement
-- exactly one overlay blueprint, and that is the right number here rather than
-- a limitation worked around: the road and the wall are the same kind of thing
-- (a pure function of the column surface, evaluated per mapchunk), they share
-- one content channel, and -- decisively -- the successor's cross-run
-- arbitration only exists WITHIN one overlay. The avenue runs first and the
-- wall yields the cells of the road it lets through its gate; two overlays
-- could not have agreed on that. The run list's order is therefore load
-- bearing, and `wp13/dur_brannoc.lua` owns it.
--
-- Nothing is BUILT here. Every entry carries a builder the seam calls once at
-- load to hash the blueprint's identity and again, lazily, on the first
-- mapchunk that touches it.
--
-- The architecture lives in the WP13 building library under
-- `mods/MAPGEN/grug_mapgen/wp13/`; this file only locates that library and
-- names what the seam takes from it.

local info = debug and debug.getinfo and debug.getinfo(1, "S")
local here = type(info) == "table" and type(info.source) == "string" and
	info.source:sub(1, 1) == "@" and info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not here or here == "" then here = core.get_modpath("grug_mapgen") .. "/wp40" end

local library = dofile(here .. "/r7_wp13_library.lua")

-- The quadrant seam, exactly as handed over, or nothing at all.
--
-- `r7_runtime.lua` passes the validated world seed and the engine's raw
-- SHA-256. A caller that passes neither is engine-free and gets the canonical
-- assignment; a caller that passes a HALF seam is a defect and is refused here
-- rather than silently placing the districts somewhere else. Wave 1 made the
-- same refusal with nothing behind it -- this capital had one district and read
-- neither field -- and said so; wave 2 is where it starts to matter.
local function quadrant_options(options)
	if options == nil then return {} end
	if type(options) ~= "table" then
		error("WP13 Dur Brannoc: the blueprint options differ", 0)
	end
	if options.full_seed == nil and options.raw_sha256 == nil and
			options.permutation == nil then
		return {}
	end
	if options.permutation == nil and
			(type(options.full_seed) ~= "string" or
				not options.full_seed:match("^%-?%d+$") or
				type(options.raw_sha256) ~= "function") then
		error("WP13 Dur Brannoc: the quadrant seam differs", 0)
	end
	return {full_seed = options.full_seed, raw_sha256 = options.raw_sha256,
		permutation = options.permutation}
end

return function(options)
	local path = library.path()
	local palettes = dofile(path .. "/palette.lua")
	local avenue = dofile(path .. "/avenue.lua")(path)
	local capital = library.composition("dur_brannoc")
	if type(capital) ~= "table" or type(capital.core) ~= "function" or
			type(capital.districts) ~= "table" or
			type(capital.quadrants) ~= "table" or
			type(capital.avenues) ~= "table" or type(capital.ring) ~= "table" or
			type(capital.wall) ~= "table" or
			type(capital.wall_plan) ~= "table" or
			type(capital.overlay_runs) ~= "function" or
			type(capital.overlay_names) ~= "function" or
			type(capital.overlay_run) ~= "function" then
		error("WP13 Dur Brannoc: the capital composition seam differs", 0)
	end

	-- The plot list's ids are the rosters' own and its offsets are this world's
	-- quadrant assignment (`wp13/dur_brannoc_districts.lua`); the schema string
	-- is the one each plot publishes, spelled here so the seam can compare it
	-- after the build instead of trusting it.
	local resolved, assignment, permutation =
		capital.districts.resolve(quadrant_options(options))
	local plots = {}
	for index = 1, #resolved do
		local plot = resolved[index]
		plots[index] = {id = plot.id, x = plot.x, z = plot.z,
			district = plot.district, role = plot.role,
			quadrant = plot.quadrant, lot = plot.lot, kind = plot.kind,
			schema = "grug_wp13_dur_brannoc_plot_" .. plot.id .. "_v1",
			build = plot.build}
	end

	-- One palette handle for both overlays, built once and closed over: the
	-- carriageway is the citadel paving of the Hearthpine palette and the wall
	-- is its castle kit, and neither asks for a capital handle of its own.
	local road = palettes.new("dwarf")

	return {
		schema = "grug_wp13_capital_source_v1",
		core = {schema = "grug_wp13_dur_brannoc_core_v1", build = capital.core},
		plots = plots,
		-- What this world decided, for the probe's log and the KAT; the seam
		-- itself neither reads nor publishes it.
		districts = {assignment = assignment, permutation = permutation},
		overlay = {
			schema = "grug_wp13_dur_brannoc_overlay_v1",
			-- The avenues first, then the ring street, then the eight district
			-- lanes, then the four sides of the curtain wall. The successor's
			-- arbitration gives a shared cell to the run that comes FIRST, so
			-- the great roads run through, the lanes yield at the kerb, and the
			-- wall yields the road it lets through its gate. The lanes belong
			-- to the QUADRANTS and not to the districts standing in them, so
			-- this list is the same on every world and the overlay's identity
			-- does not depend on the seed.
			runs = capital.overlay_runs(capital.quadrants.lane_runs()),
			width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING,
			reach = avenue.REACH,
			names = capital.overlay_names(avenue, road),
			run = function(spec, surface)
				return capital.overlay_run(avenue, road, spec, surface)
			end,
		},
	}
end
