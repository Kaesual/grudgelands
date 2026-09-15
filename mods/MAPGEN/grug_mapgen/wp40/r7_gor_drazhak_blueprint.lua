-- Gor Drazhak, the orc capital, as the R7 seam sees it: not one blueprint but
-- a SOURCE declaring three kinds of them (`r7_settlement.lua`, contract
-- section 2.2.3).
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start;
--   * the 52 plots of the four districts -- nine buildings and four fill
--     dressings each -- every one with its own offset from the capital anchor
--     and its own reference column, because WP40 terraces the rest of the 512
--     envelope in FOUR-node steps for a mesa shelf and a plot sixty nodes out
--     does not stand at the core's height;
--   * ONE overlay, carrying twenty runs: the four avenues, the four sides of
--     the ring street, the eight district lanes and the four sides of the
--     RAMPART. It has no cells until a column surface is handed to it and is
--     therefore declared as its runs plus the function that turns one run into
--     road or into bank and stockade.
--
-- ONE overlay and not two, for the reason Dur Brannoc records: the successor's
-- cross-run arbitration -- the rule that gives a shared cell to the run that
-- comes first -- only exists WITHIN one overlay. The avenue runs first and the
-- rampart yields the cells of the road it lets through its gate; in two
-- overlays neither could see the other and the gate would be a bank with a road
-- in it.
--
-- WHICH DISTRICT STANDS IN WHICH QUADRANT IS THE WORLD SEED'S (the capitals
-- contract, section 2.1). The permutation is `wp13/gor_drazhak_quadrants.lua`,
-- and the seed and the SHA-256 it needs are HANDED TO THIS FILE by
-- `r7_runtime.lua`, which validates the seed once and refuses to build if the
-- live value has moved since. That is what makes main and emerge agree about
-- where a district stands exactly when they agree about `full_seed`.
--
-- An engine-free caller -- a fixture, the renderer, the timing harness -- can
-- pass no options at all and gets the canonical assignment, and the KAT is what
-- checks the seeded ones. Nothing in the manifest moves either way: a plot's
-- identity is its cells, and its cells do not know where they will stand.
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

-- The quadrant seam, exactly as handed over, or nothing at all. A caller that
-- passes a HALF seam -- one field and not the other -- has a defect upstream
-- and is refused here rather than silently placing the districts somewhere
-- else.
local function quadrant_options(options)
	if options == nil then return {} end
	if type(options) ~= "table" then
		error("WP13 Gor Drazhak: the blueprint options differ", 0)
	end
	if options.full_seed == nil and options.raw_sha256 == nil and
			options.permutation == nil then
		return {}
	end
	if options.permutation == nil and
			(type(options.full_seed) ~= "string" or
				not options.full_seed:match("^%-?%d+$") or
				type(options.raw_sha256) ~= "function") then
		error("WP13 Gor Drazhak: the quadrant seam differs", 0)
	end
	return {full_seed = options.full_seed, raw_sha256 = options.raw_sha256,
		permutation = options.permutation}
end

return function(options)
	local path = library.path()
	local palettes = dofile(path .. "/palette.lua")
	local avenue = dofile(path .. "/avenue.lua")(path)
	local capital = library.composition("gor_drazhak")
	if type(capital) ~= "table" or type(capital.core) ~= "function" or
			type(capital.avenues) ~= "table" or type(capital.ring) ~= "table" or
			type(capital.lanes) ~= "table" or type(capital.wall) ~= "table" or
			type(capital.wall_plan) ~= "table" or
			type(capital.districts) ~= "table" or
			type(capital.overlay_runs) ~= "function" or
			type(capital.overlay_names) ~= "function" or
			type(capital.overlay_run) ~= "function" then
		error("WP13 Gor Drazhak: the capital composition seam differs", 0)
	end

	-- The plot list's ids are the rosters' own and its offsets are this world's
	-- quadrant assignment (`wp13/gor_drazhak_districts.lua`); the schema string
	-- is the one each plot publishes, spelled here so the seam can compare it
	-- after the build instead of trusting it.
	local resolved, assignment, permutation =
		capital.districts.resolve(quadrant_options(options))
	local plots = {}
	for index = 1, #resolved do
		local plot = resolved[index]
		plots[index] = {id = plot.id, x = plot.x, z = plot.z,
			district = plot.district, role = plot.role,
			quadrant = plot.quadrant, lot = plot.lot,
			schema = "grug_wp13_gor_drazhak_plot_" .. plot.id .. "_v1",
			build = plot.build}
	end

	-- One palette handle for both overlays, built once and closed over: the
	-- carriageway is the desert paving of the orc palette and the rampart is
	-- its own acacia, ors block and dug earth, so neither asks for a capital
	-- handle of its own.
	local road = palettes.new("orc")

	return {
		schema = "grug_wp13_capital_source_v1",
		core = {schema = "grug_wp13_gor_drazhak_core_v1", build = capital.core},
		plots = plots,
		-- What this world decided, for the probe's log and the KAT; the seam
		-- itself neither reads nor publishes it.
		districts = {assignment = assignment, permutation = permutation},
		overlay = {
			schema = "grug_wp13_gor_drazhak_avenue_v1",
			runs = capital.overlay_runs(),
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
