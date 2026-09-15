-- Highcourt, the human capital, as the R7 seam sees it: not one blueprint but
-- a SOURCE declaring three kinds of them (`r7_settlement.lua`, contract
-- section 2.2.3).
--
--   * the 96 x 96 civic core, anchor-relative exactly like a start;
--   * the nine plots of the market and professions district, each with its own
--     offset from the capital anchor and its own reference column, because
--     WP40 terraces the rest of the 512 envelope and a plot sixty nodes out
--     does not stand at the core's height;
--   * the avenue and ring-street overlay, which has no cells until a column
--     surface is handed to it and is therefore declared as its runs plus the
--     function that turns one run into road.
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

return function()
	local path = library.path()
	local palettes = dofile(path .. "/palette.lua")
	local avenue = dofile(path .. "/avenue.lua")(path)
	local highcourt = library.composition("highcourt")
	if type(highcourt) ~= "table" or type(highcourt.core) ~= "function" or
			type(highcourt.district) ~= "table" or
			type(highcourt.avenues) ~= "table" or type(highcourt.ring) ~= "table" then
		error("WP13 Highcourt: the capital composition seam differs", 0)
	end

	-- The plot list's positions and ids are the composition's own
	-- (`wp13/highcourt_district.lua`); the schema string is the one each plot
	-- publishes, spelled here so the seam can compare it after the build
	-- instead of trusting it.
	local plots = {}
	for index = 1, #highcourt.district.plots do
		local plot = highcourt.district.plots[index]
		plots[index] = {id = plot.id, x = plot.x, z = plot.z,
			schema = "grug_wp13_highcourt_plot_" .. plot.id .. "_v1",
			build = plot.build}
	end

	-- The four avenues first, then the four sides of the ring street, in the
	-- composition's own order: the overlay identity is written from this list.
	local runs = {}
	for _, list in ipairs({highcourt.avenues, highcourt.ring}) do
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
