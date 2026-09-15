-- Highcourt, the market and professions district: the first of the capital's
-- four districts, nine terrain-relative plots.
--
-- This file is a ROSTER. What a plot is, how it is levelled, skirted, cleared
-- and dressed, and what it publishes, all live in `highcourt_plot.lua`, which
-- is the same builder for all four districts. WHERE the nine plots stand is
-- `highcourt_quadrants.lua`: a district owns no coordinates of its own,
-- because the world seed decides which quadrant of the capital it occupies
-- and the ground decides where the nine lots of that quadrant are.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/highcourt_plot.lua")(directory)

	local M = {}

	local WATCH = "highcourt_market_watch"

	-- The roster, in the order the plots take the quadrant's nine lots.
	--
	-- `order` is the plot's waypoint in the district's own patrol loop, which
	-- is one loop with one group and no gaps: the KAT walks it. Two plots
	-- carry theirs inside `spec` instead, because their generator publishes
	-- the waypoint itself (`barracks`, `orchard_edge`).
	local PLOTS = {
		{id = "market_granary", module = "capitals", make = "granary",
			order = 1, spec = {w = 11, d = 15, wall_h = 5}},
		{id = "market_stable", module = "capitals", make = "stable",
			order = 2, spec = {w = 15, d = 11, wall_h = 5}},
		-- The workshop opens in its x- wall, like Dawnmere's smithy, and the
		-- PLOT is turned so that wall faces the street. Its z- gable cannot
		-- carry the door: the `workshop` interior kit stands the forge's
		-- cauldrons on the odd cells of the inner run of that very wall, and
		-- a double door takes an odd cell whichever index it is given, so
		-- the doorway opens onto a hearth. The same wall also carries the
		-- generator's default chimney stack at its middle cell.
		{id = "market_workshop", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true}},
		{id = "market_counting_house", module = "capitals",
			make = "scriptorium", order = 4, roof = "slate",
			spec = {w = 13, d = 17, wall_h = 6}},
		-- The well court is the district's public garden, so its plot is
		-- five nodes wider all round than a building's and the ring that
		-- buys is planted. On the first render it was a paved square with a
		-- well on it standing in a field, which is what a court with a
		-- two-node verge looks like from outside.
		{id = "market_well", module = "capitals", make = "well_court",
			order = 5, margin = 5, garden = true, spec = {size = 11}},
		{id = "market_watch", module = "capitals", make = "barracks",
			roof = "slate",
			spec = {w = 15, d = 21, wall_h = 5, patrol_group = WATCH,
				order = 6}},
		-- The grove and the store carry the district's two SPARE wander
		-- spots: idle positions a walking NPC may use as a destination and
		-- which the placement engine is meant not to staff with an
		-- inhabitant of its own (see `highcourt_plot.spare`). They stand in
		-- the back corners of the plot's own ground ring, which is the one
		-- part of a plot no generator and no dressing writes to.
		{id = "market_grove", module = "capitals", make = "grove",
			order = 7,
			spec = {size = 15, kind = "broadleaf", height = 6},
			extra_sockets = function(area)
				return {plots.spare("grove", area.x0 + 1, area.z1 - 1, 2)}
			end},
		{id = "market_orchard", module = "capitals", make = "orchard_edge",
			spec = {len = 21, d = 11, patrol_group = WATCH, order = 8}},
		-- Door index 4, single leaf: the `store` kit stands its roof posts
		-- on the odd cells of the gable's inner run, so an eleven-wide
		-- longhouse's centred door opens onto a post (see the same note in
		-- `highcourt.lua` for the household store).
		{id = "market_store", module = "buildings", make = "longhouse",
			order = 10,
			spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true},
			extra_sockets = function(area)
				return {plots.spare("store", area.x1 - 1, area.z1 - 1, 2)}
			end},
	}

	M.market = plots.district({
		key = "highcourt_market",
		role = "market_professions",
		patrol_group = WATCH,
		plots = PLOTS,
	})

	return M
end

return loader
