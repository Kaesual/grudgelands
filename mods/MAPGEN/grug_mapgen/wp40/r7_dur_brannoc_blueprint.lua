-- Dur Brannoc, the dwarf capital, as the R7 seam sees it: not one blueprint
-- but a SOURCE declaring three kinds of them (`r7_settlement.lua`, contract
-- section 2.2.3).
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start;
--   * the nine plots of the forge and craft district, each with its own offset
--     from the capital anchor and its own reference column, because WP40
--     terraces the rest of the 512 envelope in four-node steps -- the deepest
--     of the six races -- and a plot sixty nodes out does not stand at the
--     core's height;
--   * ONE overlay, carrying twelve runs: the four avenues, the four sides of
--     the ring street and the four sides of the CURTAIN WALL.
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

-- The seam `r7_runtime.lua` hands every blueprint source: the world seed it
-- validated once and the engine's raw SHA-256. Dur Brannoc has ONE district and
-- no quadrant permutation, so it reads neither -- but it still refuses a HALF
-- seam rather than shrugging at it. A caller that passes one field and not the
-- other has a defect somewhere upstream, and the day this capital grows a
-- seeded assignment the refusal is already where it belongs. A caller that
-- passes nothing at all is engine-free (a fixture, the renderer, the timing
-- harness) and is fine.
local function check_options(options)
	if options == nil then return end
	if type(options) ~= "table" then
		error("WP13 Dur Brannoc: the blueprint options differ", 0)
	end
	if options.full_seed == nil and options.raw_sha256 == nil then return end
	if type(options.full_seed) ~= "string" or
			not options.full_seed:match("^%-?%d+$") or
			type(options.raw_sha256) ~= "function" then
		error("WP13 Dur Brannoc: the blueprint seam differs", 0)
	end
end

return function(options)
	check_options(options)
	local path = library.path()
	local palettes = dofile(path .. "/palette.lua")
	local avenue = dofile(path .. "/avenue.lua")(path)
	local capital = library.composition("dur_brannoc")
	if type(capital) ~= "table" or type(capital.core) ~= "function" or
			type(capital.district) ~= "table" or
			type(capital.avenues) ~= "table" or type(capital.ring) ~= "table" or
			type(capital.wall) ~= "table" or
			type(capital.wall_plan) ~= "table" or
			type(capital.overlay_runs) ~= "function" or
			type(capital.overlay_names) ~= "function" or
			type(capital.overlay_run) ~= "function" then
		error("WP13 Dur Brannoc: the capital composition seam differs", 0)
	end

	-- The plot list's positions and ids are the composition's own
	-- (`wp13/dur_brannoc_district.lua`); the schema string is the one each plot
	-- publishes, spelled here so the seam can compare it after the build
	-- instead of trusting it.
	local plots = {}
	for index = 1, #capital.district.plots do
		local plot = capital.district.plots[index]
		plots[index] = {id = plot.id, x = plot.x, z = plot.z,
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
		overlay = {
			schema = "grug_wp13_dur_brannoc_overlay_v1",
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
