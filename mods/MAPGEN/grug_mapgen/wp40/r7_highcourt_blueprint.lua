-- Highcourt, the human capital, as the R7 seam sees it: not one blueprint but
-- a SOURCE declaring three kinds of them (`r7_settlement.lua`, contract
-- section 2.2.3).
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start;
--   * the 36 plots of the four districts, each with its own offset from the
--     capital anchor and its own reference column, because WP40 terraces the
--     rest of the 512 envelope and a plot sixty nodes out does not stand at
--     the core's height;
--   * the avenue and ring-street overlay, which has no cells until a column
--     surface is handed to it and is therefore declared as its runs plus the
--     function that turns one run into road.
--
-- WHICH DISTRICT STANDS IN WHICH QUADRANT IS THE WORLD SEED'S (the capitals
-- contract, section 2.1). The permutation is `wp13/highcourt_quadrants.lua`,
-- and the seed and the SHA-256 it needs are HANDED TO THIS FILE by
-- `r7_runtime.lua`, which validates the seed once and refuses to build if the
-- live value has moved since. That is what makes main and emerge agree about
-- where a district stands exactly when they agree about `full_seed` -- the
-- comparison `r7_mapgen.lua` already makes. This file reading the setting for
-- itself was the version where the value the offsets came from was never the
-- value anything checked.
--
-- An engine-free caller -- a fixture, the renderer, the timing harness -- can
-- pass no options at all and gets the canonical assignment, and the KAT is
-- what checks the seeded ones. Nothing in the manifest moves either way: a
-- plot's identity is its cells, and its cells do not know where they will
-- stand.
--
-- Nothing is BUILT here. Every entry carries a builder the seam calls once at
-- load to hash the blueprint's identity and again, lazily, on the first
-- mapchunk that touches it.
--
-- The architecture lives in the WP13 building library under
-- `mods/MAPGEN/grug_mapgen/wp13/`; this file only locates that library and
-- names what the seam takes from it. `r7_wp13_library.lua`, which sits next to
-- this file, does the locating; the only thing this wrapper has to work out
-- for itself is where "next to this file" is.

local info = debug and debug.getinfo and debug.getinfo(1, "S")
local here = type(info) == "table" and type(info.source) == "string" and
	info.source:sub(1, 1) == "@" and info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not here or here == "" then here = core.get_modpath("grug_mapgen") .. "/wp40" end

local library = dofile(here .. "/r7_wp13_library.lua")

-- The quadrant seam, exactly as handed over, or nothing at all.
--
-- `r7_runtime.lua` passes the validated world seed and the engine's raw
-- SHA-256. A caller that passes neither is engine-free and gets the canonical
-- assignment; a caller that passes a half-seam is a defect and is refused
-- here rather than silently placing the districts somewhere else.
local function quadrant_options(options)
	if options == nil then return {} end
	if type(options) ~= "table" then
		error("WP13 Highcourt: the blueprint options differ", 0)
	end
	if options.full_seed == nil and options.raw_sha256 == nil and
			options.permutation == nil then
		return {}
	end
	if options.permutation == nil and
			(type(options.full_seed) ~= "string" or
				not options.full_seed:match("^%-?%d+$") or
				type(options.raw_sha256) ~= "function") then
		error("WP13 Highcourt: the quadrant seam differs", 0)
	end
	return {full_seed = options.full_seed, raw_sha256 = options.raw_sha256,
		permutation = options.permutation}
end

return function(options)
	local path = library.path()
	local palettes = dofile(path .. "/palette.lua")
	local avenue = dofile(path .. "/avenue.lua")(path)
	local highcourt = library.composition("highcourt")
	if type(highcourt) ~= "table" or type(highcourt.core) ~= "function" or
			type(highcourt.district) ~= "table" or
			type(highcourt.avenues) ~= "table" or type(highcourt.ring) ~= "table" then
		error("WP13 Highcourt: the capital composition seam differs", 0)
	end
	local districts = dofile(path .. "/highcourt_districts.lua")(path)

	-- The plot list's ids are the rosters' own and its offsets are this
	-- world's quadrant assignment (`wp13/highcourt_districts.lua`); the schema
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
			schema = "grug_wp13_highcourt_plot_" .. plot.id .. "_v1",
			build = plot.build}
	end

	-- The four avenues first, then the four sides of the ring street, then the
	-- district lanes, in the composition's own order: the overlay identity is
	-- written from this list, and the successor's arbitration gives a shared
	-- cell to the run that comes FIRST -- so the great roads run through and
	-- the side streets yield at the kerb.
	--
	-- The lanes belong to the four QUADRANTS, not to the districts standing in
	-- them, so this list is the same on every world and the overlay's identity
	-- does not depend on the seed.
	local runs = {}
	for _, list in ipairs({highcourt.avenues, highcourt.ring,
			districts.quadrants.lane_runs()}) do
		for index = 1, #list do runs[#runs + 1] = list[index] end
	end

	-- One palette handle for the road, built once and closed over: the
	-- carriageway is the citadel paving of the human palette and the overlay
	-- never asks for a capital handle of its own.
	local road = palettes.new("human")

	return {
		schema = "grug_wp13_capital_source_v1",
		core = {schema = "grug_wp13_highcourt_core_v1", build = highcourt.core},
		plots = plots,
		-- What this world decided, for the probe's log and the KAT; the seam
		-- itself neither reads nor publishes it.
		districts = {assignment = assignment, permutation = permutation},
		overlay = {
			schema = "grug_wp13_highcourt_avenue_v1",
			runs = runs,
			width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING,
			reach = avenue.REACH,
			names = avenue.palette_names(road),
			run = function(spec, surface) return avenue.run(road, spec, surface) end,
		},
	}
end
