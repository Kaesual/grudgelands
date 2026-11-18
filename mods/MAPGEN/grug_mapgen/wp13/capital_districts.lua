-- The district seam of the six capitals (Round 82, audit W2-09): what every
-- `<capital>_districts.lua` did the same way.
--
-- A capital has four districts, one per role of the capitals contract
-- (market and professions, martial and garrison, lore and spiritual,
-- residential and cultural), each with its BUILDING plots and its FILL
-- dressings (fields, orchards, pastures, parks). `plots(districts)` returns
-- their plots in a FIXED order -- district by district in the role order,
-- building plots in roster order, then fill plots: {id, district, role, kind
-- ("plot" or "fill"), build}. Where a plot stands and how it is turned is the
-- capital planner's per-world layout (Round 22, `wp40/capital_planner.lua`):
-- districts stay recognisable groups (plan D69), and a plot's identity is its
-- cells, which do not know where they will stand.
--
-- `dofile(directory .. "/capital_districts.lua")` returns this table. Plain
-- Lua 5.1, pure, no engine calls, no globals.

local M = {}

-- The contract's role order.
M.ROLES = {"market_professions", "martial_garrison", "lore_spiritual",
	"residential_cultural"}

-- The districts (or their definitions) stand in `roles` order, one each.
function M.check_roles(list, roles, label)
	if #list ~= #roles then
		error("wp13 " .. label .. ": district roster differs", 0)
	end
	for index = 1, #roles do
		if list[index].role ~= roles[index] then
			error("wp13 " .. label .. ": district " .. index .. " is not " ..
				roles[index], 0)
		end
	end
end

-- The plots of `districts` in the fixed order.
function M.plots(districts)
	local list = {}
	for index = 1, #districts do
		local district = districts[index]
		for _, pair in ipairs({{district.plots, "plot"}, {district.fill, "fill"}}) do
			for _, plot in ipairs(pair[1]) do
				list[#list + 1] = {id = plot.id, district = district.key,
					role = district.role, kind = pair[2], build = plot.build}
			end
		end
	end
	return list
end

-- A capital's districts module from its four districts in the contract's
-- role order: `districts` and `plots()`.
function M.new(districts, label)
	M.check_roles(districts, M.ROLES, label)
	return {districts = districts, plots = function() return M.plots(districts) end}
end

return M
