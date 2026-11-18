-- One Highcourt district plot, built from a roster row: the capital plot
-- engine (`capital_plot.lua`, what a plot is and every option) with
-- Highcourt's own choices.
--
-- The crown's white stone and the civic slate roof are the roster's palettes
-- (`building_templates/layouts/highcourt.roster`), exactly as the core binds
-- them: `white` rebinds `signature`, the role every capital part dresses
-- itself in, so one building reads as a royal one; `slate` (and
-- `white_slate` over the white stone) roofs a civic building in slate,
-- because one roofed in the same boards as a cottage reads as a big cottage.
-- A garden plants broadleaf fruit trees on its four corners.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory, context)
	return dofile(directory .. "/capital_plot.lua")(directory, {
		key = "highcourt", label = "highcourt",
		main = function(plot) return plot.handle == "white" and "white" or "town" end,
		roof = function(plot, main)
			if plot.roof == "slate" then
				return main == "white" and "white_slate" or "slate"
			end
		end,
		garden = {tree = "broadleaf", size = 5, spots = "front"},
	}, context)
end

return loader
