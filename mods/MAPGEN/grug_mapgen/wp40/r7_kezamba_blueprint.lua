-- Kezamba, the troll capital, as the R7 seam sees it: not one blueprint but a
-- SOURCE declaring three kinds of them (`r7_settlement.lua`, contract section
-- 2.2.3).
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start;
--   * the fifty-two plots of the four districts -- thirty-six buildings and
--     sixteen fill dressings -- each with its own offset from the capital
--     anchor and its own reference column, because WP40 terraces the rest of
--     the 512 envelope in three-node steps and a plot a hundred nodes out does
--     not stand at the core's height;
--   * ONE overlay, carrying twelve runs: the four avenues, the four sides of
--     the ring street and the four GATE THRESHOLDS.
--
-- WHY THERE IS NO CURTAIN WALL IN THAT LIST. Kezamba is one of the two capitals
-- the user's ruling of 2026-09-14 left OPEN ("open edges ... for Highcourt,
-- Lethariel and Kezamba"; the round-3 plan later gave Highcourt a wall and left
-- these two alone). What stands at its four gate points instead is a threshold:
-- two totem posts with a junglewood lintel across the road, `wp13/
-- kezamba_gate.lua`. It is an overlay run for the same three reasons the
-- curtain wall is one, and it shares the capital's single overlay with the
-- avenues because the successor's cross-run arbitration -- which is what lets
-- the road keep the cells of its own carriageway under the lintel -- only
-- exists within one overlay. The run list's ORDER is therefore load bearing,
-- and `wp13/kezamba.lua` owns it: avenues, then the ring street, then the
-- thresholds.
--
-- WHY THE PLOT OFFSETS ARE NOT SEEDED. Highcourt permutes its four districts
-- between four quadrants with the world seed. Kezamba's quadrants are not
-- interchangeable: WP40's authored cenote (`kezamba_cenote` in
-- `wp40/water_authored.lua`, the footprint of the old `hydro_kezamba_cenote`)
-- fills the north-east one in every world, so a permutation would put a
-- district in the lake three times out of four. The offsets come from
-- `wp13/kezamba_lots.lua`, searched against the terrain and gated by
-- `tools/wp13/kezamba_lots.lua check`.
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

return function(options)
	local path = library.path()
	local palettes = dofile(path .. "/palette.lua")
	local avenue = dofile(path .. "/avenue.lua")(path)
	local capital = library.composition("kezamba")
	local districts = dofile(path .. "/kezamba_districts.lua")(path)
	if type(capital) ~= "table" or type(capital.core) ~= "function" or
			type(capital.avenues) ~= "table" or type(capital.ring) ~= "table" or
			type(capital.gates) ~= "table" or
			type(capital.gate_plan) ~= "table" or
			type(capital.overlay_runs) ~= "function" or
			type(capital.overlay_names) ~= "function" or
			type(capital.overlay_run) ~= "function" then
		error("WP13 Kezamba: the capital composition seam differs", 0)
	end
	-- The seam's own options are validated by the district module, which is the
	-- only place that would ever read them.
	districts.check_options(options)

	-- The plot list's positions and ids are the composition's own
	-- (`wp13/kezamba_lots.lua` and `wp13/kezamba_districts.lua`); the schema
	-- string is the one each plot publishes, spelled here so the seam can
	-- compare it after the build instead of trusting it.
	local resolved = districts.resolve(options)
	local plots = {}
	for index = 1, #resolved do
		local plot = resolved[index]
		plots[index] = {id = plot.id, x = plot.x, z = plot.z,
			schema = "grug_wp13_kezamba_plot_" .. plot.id .. "_v1",
			build = plot.build}
	end

	-- One palette handle for the overlay, built once and closed over: the
	-- carriageway is the troll boardwalk and basalt of the Kapok palette and the
	-- threshold is its totem post and beam, and neither asks for a handle of its
	-- own.
	local road = palettes.new("troll")

	return {
		schema = "grug_wp13_capital_source_v1",
		core = {schema = "grug_wp13_kezamba_core_v1", build = capital.core},
		plots = plots,
		overlay = {
			schema = "grug_wp13_kezamba_overlay_v1",
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
