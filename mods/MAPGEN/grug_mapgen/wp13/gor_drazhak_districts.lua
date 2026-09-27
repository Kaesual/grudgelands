-- Gor Drazhak's four districts: the rosters `gor_drazhak_district*.lua`, one per
-- role of the capitals contract (market and professions, martial and
-- garrison, lore and spiritual, residential and cultural), each with its
-- BUILDING plots and its FILL dressings (fields, orchards, pastures, parks).
--
-- `M.plots()` returns them in a FIXED order -- district by district in the
-- role order, building plots in roster order, then fill plots. Where they
-- stand and how they are turned is the capital planner's per-world layout
-- (Round 22, `wp40/capital_planner.lua`): districts stay recognisable
-- groups (plan D69), and a plot's identity is its cells, which do not know
-- where they will stand.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local market = dofile(directory .. "/gor_drazhak_district_market.lua")(directory)
	local martial = dofile(directory .. "/gor_drazhak_district_martial.lua")(directory)
	local lore = dofile(directory .. "/gor_drazhak_district_lore.lua")(directory)
	local homes = dofile(directory .. "/gor_drazhak_district_homes.lua")(directory)

	local M = {}

	-- The four districts in the contract's role order.
	M.districts = {market.market, martial.martial, lore.lore, homes.homes}

	do
		local roles = {"market_professions", "martial_garrison", "lore_spiritual",
		"residential_cultural"}
		if #M.districts ~= #roles then
			error("wp13 gor drazhak: district roster differs", 0)
		end
		for index = 1, #roles do
			if M.districts[index].role ~= roles[index] then
				error("wp13 gor drazhak: district " .. index .. " is not " ..
					roles[index], 0)
			end
		end
	end

	-- The plots in a FIXED order -- district by district in the contract's own
	-- role order, each district's BUILDING plots in roster order and then its
	-- FILL plots in roster order: {id, district, role, kind ("plot" or
	-- "fill"), build}. Where a plot stands and how it is turned is the capital
	-- planner's per-world layout (Round 22, `wp40/capital_planner.lua`); a
	-- plot's identity is its cells, and its cells do not know where they will
	-- stand.
	function M.plots()
		local list = {}
		for index = 1, #M.districts do
			local district = M.districts[index]
			for _, pair in ipairs({{district.plots, "plot"}, {district.fill, "fill"}}) do
				for _, plot in ipairs(pair[1]) do
					list[#list + 1] = {id = plot.id, district = district.key,
						role = district.role, kind = pair[2], build = plot.build}
				end
			end
		end
		return list
	end

	return M
end

return loader
