-- Nhal Veyr's four districts: the rosters `nhal_veyr_district*.lua`,
-- one per role of the capitals contract, in the contract's order
-- (`capital_districts.lua`).
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory, context)
	-- One loader context (`templates.lua`) for everything this build loads.
	context = context or {}
	-- One plot module (and with it one parsed roster and one dressing kit)
	-- for all four districts.
	local plots = dofile(directory .. "/nhal_veyr_plot.lua")(directory, context)
	local market = dofile(directory .. "/nhal_veyr_district.lua")(directory, plots)
	local martial = dofile(directory .. "/nhal_veyr_district_martial.lua")(directory, plots)
	local lore = dofile(directory .. "/nhal_veyr_district_lore.lua")(directory, plots)
	local homes = dofile(directory .. "/nhal_veyr_district_homes.lua")(directory, plots)
	return dofile(directory .. "/capital_districts.lua").new(
		{market.market, martial.martial, lore.lore, homes.homes}, "nhal veyr")
end

return loader
