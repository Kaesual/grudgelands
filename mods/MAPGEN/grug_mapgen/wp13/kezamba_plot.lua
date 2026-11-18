-- One Kezamba district plot, built from a roster row: the capital plot engine
-- (`capital_plot.lua`, what a plot is and every option) in the troll palette.
--
--   * A plot walks on TIMBER. The troll palette binds `path` to junglewood --
--     "in a basin that floods, a settlement walks on boardwalks, not on stone"
--     (`palette.lua`) -- so a plot's gate path is deck and not paving, and
--     that one binding is what makes the whole capital read as one continuous
--     timber walk. Its lamps stand on the plot's very edge.
--   * A row names its roster palette in `handle` (`town` the plain troll
--     timber, `basalt` the civic stone, `water`/`basalt_water` with the river
--     water bound, `vine` the raised-bed gardens' jungle growth, `crop` the
--     fields'); no roof palette.
--   * The clear also reaches the template's `top` (`clear_to_top`, audit
--     W2-05).
--   * `garden_ignored` (audit W2-02): the four well courts' rows say
--     `garden = true`, copied from Highcourt's, and this capital's builder
--     never had a garden; they stand on their bare margin.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory, context)
	return dofile(directory .. "/capital_plot.lua")(directory, {
		key = "kezamba", label = "kezamba",
		main = function(plot) return plot.handle or "town" end,
		lamp = {kind = "path_light", inset = 0, row = 1},
		yard_lamp_inset = 0,
		clear_to_top = true,
		garden_ignored = true,
	}, context)
end

return loader
