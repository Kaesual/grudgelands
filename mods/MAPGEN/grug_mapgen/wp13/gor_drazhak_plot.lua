-- One Gor Drazhak district plot, built from a roster row: the capital plot
-- engine (`capital_plot.lua`, what a plot is and every option) in the orc
-- palette, whose FLAT DECKS BEHIND PARAPETS are the thing the contract's
-- section 2.4 orc line names first.
--
--   * THE SECOND PALETTE. Adobe is the orc signature and is already the
--     `wall` binding, so a capital building made grander by a richer wall
--     material is not available the way Highcourt's marble crown is. What IS
--     available, and is the contract's own word, is the ORS-STONE BASE
--     COURSE: the banded red sandstone this palette already infills its
--     adobe walls with, the roster's `ors` palette
--     (`building_templates/layouts/gor_drazhak.roster`). A civic building
--     built with it throughout is stone where a dwelling is mud brick. No
--     roof palette: the decks are flat.
--   * MIN_CLEAR IS NINE AND NOT EIGHT, the nine-seed sweep's doing: eight left
--     one lot of the south-west quarter with no legal position within eighty
--     nodes for a rise of seven; one more course of authored air bought it its
--     own ground back.
--   * No garden; a fill plot's gate spot is a spare (`fill_gate_spare`); an
--     `extra_sockets` entry keeps its `group` and `order` (`extra_group_order`,
--     audit W2-06); the landmarks carry the deck's `parapet_columns`.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory, context)
	return dofile(directory .. "/capital_plot.lua")(directory, {
		key = "gor_drazhak", label = "gor drazhak",
		min_clear = 9,
		main = function(plot) return plot.handle == "ors" and "ors" or "town" end,
		fill_gate_spare = true,
		extra_group_order = true,
		parapet_columns = true,
	}, context)
end

return loader
