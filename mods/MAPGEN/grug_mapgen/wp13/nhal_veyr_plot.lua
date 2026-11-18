-- One Nhal Veyr district plot, built from a roster row: the capital plot
-- engine (`capital_plot.lua`, what a plot is and every option) in the undead
-- palette.
--
-- The crypt masonry (`crypt`: the civic stone, with `post` and `beam` left
-- unbound on purpose, a lamp standard and a floor torch stack on them), the
-- vault roof over it (`vault`, dressed stone brick, a mid grey over black
-- walls so a tomb reads as a tomb from the end of an avenue) and both
-- (`crypt_vault`) are the roster's palettes
-- (`building_templates/layouts/nhal_veyr.roster`); `town` is the plain undead
-- palette. A garden plants gravewood on its four corners, and a row may turn
-- its gate spot (`gate_face`).
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory, context)
	return dofile(directory .. "/capital_plot.lua")(directory, {
		key = "nhal_veyr", label = "nhal veyr",
		main = function(plot) return plot.handle == "crypt" and "crypt" or "town" end,
		roof = function(plot, main)
			if plot.roof == "vault" then
				return main == "crypt" and "crypt_vault" or "vault"
			end
		end,
		garden = {tree = "gravewood", size = 5, spots = "front"},
	}, context)
end

return loader
