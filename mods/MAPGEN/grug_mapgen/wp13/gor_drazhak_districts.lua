-- Gor Drazhak's four districts, and where this world puts them.
--
-- The four rosters are `gor_drazhak_district_market.lua` (the bazaar),
-- `_martial.lua` (the war yard), `_lore.lua` (the bone halls) and `_homes.lua`
-- (the warrens); the four quadrants' lot grids and the seeded permutation are
-- `gor_drazhak_quadrants.lua`. This file is the one place the two meet, and it
-- is what the WP40 capital source asks for its plot list.
--
-- `M.resolve(options)` returns the 52 plots in a FIXED order -- district by
-- district in the contract's own role order, the district's nine BUILDING plots
-- in roster order and then its four FILL plots in roster order -- each with the
-- offset from the capital anchor that this world's permutation gives it. The
-- order does not depend on the seed, only the offsets do, which is what keeps
-- the manifest's field order and every blueprint identity independent of the
-- world: a plot's identity is its cells, and its cells do not know which
-- quadrant they will stand in.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local quadrants = dofile(directory .. "/gor_drazhak_quadrants.lua")()
	local market = dofile(directory .. "/gor_drazhak_district_market.lua")(directory)
	local martial = dofile(directory .. "/gor_drazhak_district_martial.lua")(directory)
	local lore = dofile(directory .. "/gor_drazhak_district_lore.lua")(directory)
	local homes = dofile(directory .. "/gor_drazhak_district_homes.lua")(directory)

	local M = {}

	M.quadrants = quadrants

	-- The four districts in the contract's role order, which is also the order
	-- `gor_drazhak_quadrants.ROLES` names them in and the order the permutation
	-- is read against.
	M.districts = {market.market, martial.martial, lore.lore, homes.homes}

	do
		local roles = quadrants.ROLES
		if #M.districts ~= #roles then
			error("wp13 gor drazhak: district roster differs", 0)
		end
		for index = 1, #roles do
			if M.districts[index].role ~= roles[index] then
				error("wp13 gor drazhak: district " .. index .. " is not " ..
					roles[index], 0)
			end
			if #M.districts[index].plots ~= #quadrants.AUTHORED then
				error("wp13 gor drazhak: " .. roles[index] ..
					" does not have one plot per lot", 0)
			end
			if #M.districts[index].fill ~= #quadrants.FILL_AUTHORED then
				error("wp13 gor drazhak: " .. roles[index] ..
					" does not have one dressing per fill lot", 0)
			end
		end
	end

	-- The 52 plots with their offsets, for this world.
	--
	-- `options` is the quadrant seam of `gor_drazhak_quadrants.assign`:
	-- `full_seed` plus `raw_sha256` where a world is being generated, an
	-- explicit `permutation` where a test names one, and neither where there is
	-- no world at all -- an engine-free fixture, a renderer, the timing harness
	-- -- in which case the roles take the quadrants in authored order.
	function M.resolve(options)
		local assignment, permutation = quadrants.assign(options)
		local list = {}
		for index = 1, #M.districts do
			local district = M.districts[index]
			local placement = assignment[district.role]
			local function append(plots, lots, kind)
				for plot_index = 1, #plots do
					local plot = plots[plot_index]
					local lot = lots[plot_index]
					list[#list + 1] = {
						id = plot.id,
						district = district.key,
						role = district.role,
						quadrant = placement.quadrant,
						kind = kind,
						lot = plot_index,
						x = lot.x,
						z = lot.z,
						build = plot.build,
					}
				end
			end
			append(district.plots, placement.lots, "plot")
			append(district.fill, placement.fill_lots, "fill")
		end
		return list, assignment, permutation
	end

	return M
end

return loader
