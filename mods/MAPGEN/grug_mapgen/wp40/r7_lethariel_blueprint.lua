-- Lethariel, the elf capital, as the R7 seam sees it: not one blueprint but a
-- SOURCE declaring three kinds of them (`r7_settlement.lua`, contract section
-- 2.2.3).
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start -- and the
--     only core of the six with a hole in it, because WP40 lays its authored
--     crown lake into this capital's pad (`wp40/water_authored.lua`;
--     `wp13/lethariel.lua`, "the mere");
--   * the 44 plots of the four districts, each with its own offset from the
--     capital anchor and its own reference column, because WP40 terraces the
--     rest of the 512 envelope in three-node steps and a plot sixty nodes out
--     does not stand at the core's height;
--   * ONE overlay carrying nineteen runs: the four avenues, the four sides of
--     the ring street, the seven district lanes and the four sides of the
--     GROVE EDGE, which is what an open capital has where a walled one has a
--     curtain.
--
-- ONE overlay and not two, for the reason Dur Brannoc records and Highcourt
-- repeats: the successor's cross-run arbitration -- the rule that gives a
-- shared cell to the run that comes first -- only exists WITHIN one overlay.
-- The avenue runs first and the grove edge yields the cells of the road it
-- lets through its threshold; in two overlays neither could see the other.
--
-- WHICH DISTRICT STANDS IN WHICH QUARTER IS THE WORLD SEED'S, for three of the
-- four. The fourth -- the lore and spiritual district -- is the MERE PRECINCT
-- and does not move, because a precinct built round a lake cannot stand in a
-- quarter that has no lake in it; `wp13/lethariel_quadrants.lua` section 1 is
-- the argument and the measurement. The permutation over the other three is
-- `lethariel_quadrants.lua`, and the seed and the SHA-256 it needs are HANDED
-- TO THIS FILE by `r7_runtime.lua`, which validates the seed once and refuses
-- to build if the live value has moved since. That is what makes main and
-- emerge agree about where a district stands exactly when they agree about
-- `full_seed`.
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

local info = debug and debug.getinfo and debug.getinfo(1, "S")
local here = type(info) == "table" and type(info.source) == "string" and
	info.source:sub(1, 1) == "@" and info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not here or here == "" then here = core.get_modpath("grug_mapgen") .. "/wp40" end

local library = dofile(here .. "/r7_wp13_library.lua")

-- The quadrant seam, exactly as handed over, or nothing at all.
--
-- A caller that passes neither field is engine-free and gets the canonical
-- assignment; a caller that passes a HALF seam is a defect and is refused here
-- rather than silently placing the districts somewhere else.
local function quadrant_options(options)
	if options == nil then return {} end
	if type(options) ~= "table" then
		error("WP13 Lethariel: the blueprint options differ", 0)
	end
	if options.full_seed == nil and options.raw_sha256 == nil and
			options.permutation == nil then
		return {}
	end
	if options.permutation == nil and
			(type(options.full_seed) ~= "string" or
				not options.full_seed:match("^%-?%d+$") or
				type(options.raw_sha256) ~= "function") then
		error("WP13 Lethariel: the quadrant seam differs", 0)
	end
	return {full_seed = options.full_seed, raw_sha256 = options.raw_sha256,
		permutation = options.permutation}
end

return function(options)
	local path = library.path()
	local avenue = dofile(path .. "/avenue.lua")(path)
	local elf = dofile(path .. "/elf_parts.lua")(path)
	local lethariel = library.composition("lethariel")
	if type(lethariel) ~= "table" or type(lethariel.core) ~= "function" or
			type(lethariel.districts) ~= "table" or
			type(lethariel.avenues) ~= "table" or
			type(lethariel.ring) ~= "table" or
			type(lethariel.edge) ~= "table" or
			type(lethariel.edge_plan) ~= "table" or
			type(lethariel.overlay_runs) ~= "function" or
			type(lethariel.overlay_names) ~= "function" or
			type(lethariel.overlay_run) ~= "function" then
		error("WP13 Lethariel: the capital composition seam differs", 0)
	end
	local districts = lethariel.districts

	-- The plot list's ids are the rosters' own and its offsets are this
	-- world's quarter assignment; the schema string is the one each plot
	-- publishes, spelled here so the seam can compare it after the build
	-- instead of trusting it.
	local resolved, assignment, permutation =
		districts.resolve(quadrant_options(options))
	local plots = {}
	for index = 1, #resolved do
		local plot = resolved[index]
		plots[index] = {id = plot.id, x = plot.x, z = plot.z,
			district = plot.district, role = plot.role,
			quadrant = plot.quadrant, lot = plot.lot,
			schema = "grug_wp13_lethariel_plot_" .. plot.id .. "_v1",
			build = plot.build}
	end

	-- The four avenues first, then the four sides of the ring street, then the
	-- district lanes, then the four sides of the grove edge, in the
	-- composition's own order: the overlay identity is written from this list,
	-- and the successor's arbitration gives a shared cell to the run that comes
	-- FIRST -- so the great roads run through, the side streets yield at the
	-- kerb, and the edge yields the road it lets through its threshold.
	--
	-- The lanes belong to the four QUARTERS, not to the districts standing in
	-- them, so this list is the same on every world and the overlay's identity
	-- does not depend on the seed.
	local runs = lethariel.overlay_runs(districts.quadrants.lane_runs())

	-- One palette handle for both overlays, built once and closed over: the
	-- carriageway is the marble paving of the elf palette and the edge is its
	-- own silverwood and marble, so neither asks for a handle of its own. It
	-- is the CAPITAL handle of `elf_parts.lua` and not a bare
	-- `palettes.new("elf")`, because the grove edge plants a hedge and the elf
	-- start palette binds none.
	local road = elf.handles().elf

	return {
		schema = "grug_wp13_capital_source_v1",
		core = {schema = "grug_wp13_lethariel_core_v1", build = lethariel.core},
		plots = plots,
		-- What this world decided, for the probe's log and the KAT; the seam
		-- itself neither reads nor publishes it.
		districts = {assignment = assignment, permutation = permutation},
		overlay = {
			schema = "grug_wp13_lethariel_overlay_v1",
			runs = runs,
			width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING,
			reach = avenue.REACH,
			names = lethariel.overlay_names(avenue, road),
			run = function(spec, surface)
				return lethariel.overlay_run(avenue, road, spec, surface)
			end,
		},
	}
end
