-- Highcourt's four districts, and where this world puts them.
--
-- The four rosters are `highcourt_district.lua` (market and professions),
-- `highcourt_district_martial.lua`, `highcourt_district_lore.lua` and
-- `highcourt_district_homes.lua`; the four quadrants' lot grids and the
-- seeded permutation are `highcourt_quadrants.lua`. This file is the one
-- place the two meet, and it is what the WP40 capital source asks for its
-- plot list.
--
-- `M.resolve(options)` returns the 36 plots in a FIXED order -- district by
-- district in the contract's own role order, plot by plot in roster order --
-- each with the offset from the capital anchor that this world's permutation
-- gives it. The order does not depend on the seed, only the offsets do, which
-- is what keeps the manifest's field order and every blueprint identity
-- independent of the world: a plot's identity is its cells, and its cells do
-- not know which quadrant they will stand in.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local quadrants = dofile(directory .. "/highcourt_quadrants.lua")()
	local market = dofile(directory .. "/highcourt_district.lua")(directory)
	local martial = dofile(directory .. "/highcourt_district_martial.lua")(directory)
	local lore = dofile(directory .. "/highcourt_district_lore.lua")(directory)
	local homes = dofile(directory .. "/highcourt_district_homes.lua")(directory)

	local M = {}

	M.quadrants = quadrants

	-- The four districts in the contract's role order, which is also the
	-- order `highcourt_quadrants.ROLES` names them in and the order the
	-- permutation is read against.
	M.districts = {market.market, martial.martial, lore.lore, homes.homes}

	do
		local roles = quadrants.ROLES
		if #M.districts ~= #roles then
			error("wp13 highcourt: district roster differs", 0)
		end
		for index = 1, #roles do
			if M.districts[index].role ~= roles[index] then
				error("wp13 highcourt: district " .. index .. " is not " ..
					roles[index], 0)
			end
			if #M.districts[index].plots ~= #quadrants.AUTHORED then
				error("wp13 highcourt: " .. roles[index] ..
					" does not have one plot per lot", 0)
			end
		end
	end

	-- The 36 plots with their offsets, for this world.
	--
	-- `options` is the quadrant seam of `highcourt_quadrants.assign`:
	-- `full_seed` plus `raw_sha256` where a world is being generated, an
	-- explicit `permutation` where a test names one, and neither where there
	-- is no world at all -- an engine-free fixture, a renderer, the timing
	-- harness -- in which case the roles take the quadrants in authored
	-- order.
	function M.resolve(options)
		local assignment, permutation = quadrants.assign(options)
		local list = {}
		for index = 1, #M.districts do
			local district = M.districts[index]
			local placement = assignment[district.role]
			for plot_index = 1, #district.plots do
				local plot = district.plots[plot_index]
				local lot = placement.lots[plot_index]
				list[#list + 1] = {
					id = plot.id,
					district = district.key,
					role = district.role,
					quadrant = placement.quadrant,
					lot = plot_index,
					x = lot.x,
					z = lot.z,
					build = plot.build,
				}
			end
		end
		return list, assignment, permutation
	end

	return M
end

return loader
