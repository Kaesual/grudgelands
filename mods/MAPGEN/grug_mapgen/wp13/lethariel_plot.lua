-- One Lethariel district plot, built from a roster row: the capital plot
-- engine (`capital_plot.lua`, what a plot is and every option) in the elf
-- palette.
--
--   * The two palettes are the roster's (`building_templates/layouts/
--     lethariel.roster`): `elf` the city's, `pale` the civic quarter's, which
--     also names its roof.
--   * THE REACH IS 11 AND NOT 13: the crown lake left less room when the lots
--     were measured, and it is still four nodes inside the contract's own
--     +-15 plot volume.
--   * A building plot's two lamps are lantern pillars two nodes in from its
--     street corners, and the beacon and hanging lights count as lights.
--   * A garden plants columnar trees on its four corners.
--   * An `extra_sockets` entry keeps its `group` and `order`
--     (`extra_group_order`, audit W2-06).
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory, context)
	return dofile(directory .. "/capital_plot.lua")(directory, {
		key = "lethariel", label = "lethariel",
		reach = 11,
		main = function(plot) return plot.handle == "pale" and "pale" or "elf" end,
		roof = function(plot) return plot.roof == "pale" and "pale" or nil end,
		lamp = {kind = "lantern_pillar", inset = 2, row = 2},
		lights = {"light_beacon", "light_hanging"},
		garden = {tree = "columnar", size = 6, spots = "front"},
		extra_group_order = true,
	}, context)
end

return loader
