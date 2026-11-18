-- One Dur Brannoc district plot, built from a roster row: the capital plot
-- engine (`capital_plot.lua`, what a plot is and every option) in the dwarf
-- palette.
--
--   * THE PALETTE IS THE DWARF ONE and the second handle is SLATE, not white
--     stone. The capitals contract's section 2.4 dwarf column is "stone-block
--     citadel walls with pillars and arrowslits, pine-and-slate halls", and
--     the dwarf signature IS `default:stone_block`. So there is no "white"
--     handle to rebind: the one rebinding a civic dwarf building needs is its
--     ROOF, and a hall roofed in the same pine boards as a cottage reads as a
--     big cottage.
--   * THE CLEAR ALSO REACHES THE TEMPLATE'S `top` (`clear_to_top`, audit
--     W2-05): a `grove`'s authored air reaches y = 24 over its trees while
--     `peak` stops at the canopy, and the seam's load-time `audit_terrain`
--     measured the difference out of the engine (wave 1, `forge_copse`).
--   * A GARDEN PLANTS PINES, and never on the two street corners: a
--     conifer's crown reaches two nodes and `dressing.tree` writes where it
--     is told, so a tree on the corner buries the lamp post there.
--   * `decorate` gets the dwarf dressing kit as `area.dwarf`
--     (`dwarf_dressing.lua`).
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory, context)
	return dofile(directory .. "/capital_plot.lua")(directory, {
		key = "dur_brannoc", label = "dur brannoc",
		main = function() return "town" end,
		roof = function(plot) return plot.roof == "slate" and "slate" or nil end,
		garden = {tree = "tree", size = 6, spots = "back"},
		clear_to_top = true,
		area = {dwarf = "dwarf_dressing"},
	}, context)
end

return loader
