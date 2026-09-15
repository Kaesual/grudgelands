-- Nhal Veyr, the undead capital, as the R7 seam sees it: not one blueprint but
-- a SOURCE declaring three kinds of them (`r7_settlement.lua`, contract
-- section 2.2.3).
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start;
--   * the 52 plots of the four districts -- nine building lots and four fill
--     dressings each -- every one with its own offset from the capital anchor
--     and its own reference column, because WP40 terraces the rest of the 512
--     envelope in three-node steps and a plot sixty nodes out does not stand
--     at the core's height;
--   * ONE overlay, carrying twenty runs: the four avenues, the four sides of
--     the ring street, the eight district lanes and the four sides of the
--     CURTAIN WALL. It has no cells until a column surface is handed to it and
--     is therefore declared as its runs plus the function that turns one run
--     into road or into masonry.
--
-- ONE overlay and not two, for the reason Dur Brannoc records: the successor's
-- cross-run arbitration -- the rule that gives a shared cell to the run that
-- comes first -- only exists WITHIN one overlay. The avenue runs first and the
-- wall yields the cells of the road it lets through its gate; in two overlays
-- neither could see the other and the gate would be a wall with a road in it.
--
-- WHICH DISTRICT STANDS IN WHICH QUADRANT IS THE WORLD SEED'S (the capitals
-- contract, section 2.1). The permutation is `wp13/nhal_veyr_quadrants.lua`,
-- and the seed and the SHA-256 it needs are HANDED TO THIS FILE by
-- `r7_runtime.lua`, which validates the seed once and refuses to build if the
-- live value has moved since. That is what makes main and emerge agree about
-- where a district stands exactly when they agree about `full_seed`. An
-- engine-free caller -- a fixture, the renderer, the timing harness -- can pass
-- no options at all and gets the canonical assignment; a caller that passes
-- HALF a seam has a defect upstream and is refused here rather than silently
-- placing the districts somewhere the other environment did not.
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
local function quadrant_options(options)
	if options == nil then return {} end
	if type(options) ~= "table" then
		error("WP13 Nhal Veyr: the blueprint options differ", 0)
	end
	if options.full_seed == nil and options.raw_sha256 == nil and
			options.permutation == nil then
		return {}
	end
	if options.permutation == nil and
			(type(options.full_seed) ~= "string" or
				not options.full_seed:match("^%-?%d+$") or
				type(options.raw_sha256) ~= "function") then
		error("WP13 Nhal Veyr: the quadrant seam differs", 0)
	end
	return {full_seed = options.full_seed, raw_sha256 = options.raw_sha256,
		permutation = options.permutation}
end

return function(options)
	local path = library.path()
	local palettes = dofile(path .. "/palette.lua")
	local avenue = dofile(path .. "/avenue.lua")(path)
	local nhal_veyr = library.composition("nhal_veyr")
	if type(nhal_veyr) ~= "table" or type(nhal_veyr.core) ~= "function" or
			type(nhal_veyr.avenues) ~= "table" or
			type(nhal_veyr.ring) ~= "table" or
			type(nhal_veyr.wall) ~= "table" or
			type(nhal_veyr.wall_plan) ~= "table" or
			type(nhal_veyr.overlay_runs) ~= "function" or
			type(nhal_veyr.overlay_names) ~= "function" or
			type(nhal_veyr.overlay_run) ~= "function" then
		error("WP13 Nhal Veyr: the capital composition seam differs", 0)
	end
	local districts = dofile(path .. "/nhal_veyr_districts.lua")(path)

	-- The plot list's ids are the rosters' own and its offsets are this
	-- world's quadrant assignment (`wp13/nhal_veyr_districts.lua`); the schema
	-- string is the one each plot publishes, spelled here so the seam can
	-- compare it after the build instead of trusting it.
	local resolved, assignment, permutation =
		districts.resolve(quadrant_options(options))
	local plots = {}
	for index = 1, #resolved do
		local plot = resolved[index]
		plots[index] = {id = plot.id, x = plot.x, z = plot.z,
			district = plot.district, role = plot.role,
			quadrant = plot.quadrant, lot = plot.lot,
			schema = "grug_wp13_nhal_veyr_plot_" .. plot.id .. "_v1",
			build = plot.build}
	end

	-- The four avenues first, then the four sides of the ring street, then the
	-- district lanes, then the four sides of the curtain wall, in the
	-- composition's own order (`nhal_veyr.overlay_runs`): the overlay identity
	-- is written from this list, and the successor's arbitration gives a shared
	-- cell to the run that comes FIRST -- so the great roads run through, the
	-- side streets yield at the kerb, and the wall yields the road it lets
	-- through its gate.
	--
	-- The lanes belong to the four QUADRANTS, not to the districts standing in
	-- them, so this list is the same on every world and the overlay's identity
	-- does not depend on the seed.
	local runs = nhal_veyr.overlay_runs(districts.quadrants.lane_runs())

	-- One palette handle for both overlays, built once and closed over: the
	-- carriageway is the castle pavement of the Stillgrave palette and the
	-- curtain is its dungeon stone over obsidian-brick string courses, so
	-- neither asks for a capital handle of its own.
	local road = palettes.new("undead")

	return {
		schema = "grug_wp13_capital_source_v1",
		core = {schema = "grug_wp13_nhal_veyr_core_v1",
			build = nhal_veyr.core},
		plots = plots,
		-- What this world decided, for the probe's log and the KAT; the seam
		-- itself neither reads nor publishes it.
		districts = {assignment = assignment, permutation = permutation},
		overlay = {
			schema = "grug_wp13_nhal_veyr_avenue_v1",
			runs = runs,
			width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING,
			reach = avenue.REACH,
			names = nhal_veyr.overlay_names(avenue, road),
			run = function(spec, surface)
				return nhal_veyr.overlay_run(avenue, road, spec, surface)
			end,
		},
	}
end
