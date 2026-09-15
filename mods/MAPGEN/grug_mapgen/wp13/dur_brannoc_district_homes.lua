-- Dur Brannoc, the residential and cultural district: nine terrain-relative
-- plots and four dressings.
--
-- The contract's fourth district role, and the quarter that has to read as a
-- place people LIVE rather than a place they work: cottages and longhouses
-- along a lane, the alehouse and the bakehouse on it, a small market at its
-- head, and the gardens and pens between them.
--
-- What a plot is and how it is built is `dur_brannoc_plot.lua`; where the nine
-- plots stand is `dur_brannoc_quadrants.lua`. This file is the roster and
-- nothing else.
--
-- THE THREE PROFESSION VENDORS OF THIS QUARTER are `baker`, `butcher` and
-- `brewer` (the sockets contract's section 8.4, the wave-2 list for the last of
-- them). A capital holds at most ONE vendor of each kind, and the KAT's family
-- rule asserts that over every composition of this settlement at once: the core
-- has `race` and `general`, the forge district `smith` and `mason`, the
-- garrison `armourer`, and these three are the rest.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/dur_brannoc_plot.lua")(directory)

	local M = {}

	local WATCH = "dur_brannoc_terrace_watch"

	-- The shopfront of every profession house of this capital; see
	-- `dur_brannoc_district.lua` for why the apron's front row is the one place
	-- a building plot's dressing may stand.
	local function shop_counter(buf, palette, area)
		area.dressing.counter(buf, palette, area.x1 - 5, area.z0 + 1, 4, "x")
	end
	local function shop_vendor(id, kind, area)
		return plots.vendor(id, kind, area.x1 - 4, area.z0, 0)
	end

	local PLOTS = {
		-- 1. The terrace market: a covered arcade rather than a square, and the
		-- reason is a socket rather than a taste. `capitals.market_square`
		-- always publishes a `waypoint` -- the travel pad WP17 has reserved --
		-- and a capital has exactly one of those, in its civic core; a district
		-- market built from that generator would give this capital two. The
		-- arcade is `capitals.colonnade`, a roofed walk on piers, which is what
		-- a dwarf market under a terrace edge looks like; the butcher's counter
		-- stands on its apron.
		-- The colonnade publishes its OWN waypoint (the walk under the arcade),
		-- so this row carries no `order` and hands the loop in through `spec`,
		-- exactly as the barracks rows of the other districts do.
		{id = "terrace_market", module = "capitals", make = "colonnade",
			spec = {len = 15, d = 5, patrol_group = WATCH, order = 1},
			decorate = function(buf, palette, area)
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("market_stall", "stall", area.x1 - 2,
						area.z0, 0),
					shop_vendor("butcher", "butcher", area),
					plots.spare("terrace_market", area.x0 + 2, area.z0, 0),
				}
			end},
		-- 2. The brewhouse: the workshop kit again, turned, with the vats on
		-- its apron. `brew` faces a cauldron or a cask.
		{id = "terrace_brewhouse", module = "buildings", make = "workshop",
			order = 2, turns = 3,
			spec = {w = 11, d = 15, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				area.dwarf.brew_vats(buf, palette, area.x0 + 2, area.z0 + 1,
					2, "x")
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("brewhouse_vats", "brew", area.x0 + 2,
						area.z0, 0),
					shop_vendor("brewer", "brewer", area),
				}
			end},
		-- 3. The alehouse: a hall under slate with the trestles outside it.
		{id = "terrace_alehouse", module = "buildings", make = "hall",
			roof = "slate", order = 3,
			spec = {w = 13, d = 15, wall_h = 5, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.bench(buf, palette, area.x0 + 2, area.z0 + 1, 2, 2,
					"x")
				dressing.bench(buf, palette, area.x1 - 4, area.z0 + 1, 2, 2,
					"x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("alehouse_bench", "sit", area.x0 + 2,
						area.z0 + 1, 2, {"bench"}, 2),
					plots.work("alehouse_bench_east", "sit", area.x1 - 4,
						area.z0 + 1, 2, {"bench"}, 2),
				}
			end},
		-- 4. The bakehouse, and the baker's counter on the lane.
		{id = "terrace_bakehouse", module = "buildings", make = "workshop",
			order = 4, turns = 1,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("bakehouse_counter", "stall", area.x1 - 2,
						area.z0, 0),
					shop_vendor("baker", "baker", area),
				}
			end},
		-- 5. The well court, planted in the ring its wider ground buys.
		{id = "terrace_well_court", module = "capitals", make = "well_court",
			order = 5, margin = 5, garden = true, spec = {size = 11},
			extra_sockets = function(area)
				return {
					plots.work("well_bench", "sit", -1, area.z1 - 2, 2,
						{"bench"}, 2),
					plots.spare("well_court", area.x0 + 3, area.z0 + 2, 0),
				}
			end},
		-- 6. The long house: the quarter's biggest dwelling, several families
		-- under one roof, which is what a terrace city does with its ground.
		{id = "terrace_long_house", module = "buildings", make = "longhouse",
			order = 6,
			spec = {w = 13, d = 17, wall_h = 5, door_side = "z-",
				door_index = 6, infill = true}},
		-- 7. and 8. Two cottages, one hipped and one gabled, so the lane does
		-- not read as one house built twice.
		{id = "terrace_cottage_west", module = "buildings", make = "cottage",
			order = 7,
			spec = {w = 11, d = 9, wall_h = 4, roof = "hip", infill = true}},
		{id = "terrace_cottage_east", module = "buildings", make = "cottage",
			order = 8,
			spec = {w = 9, d = 11, wall_h = 4, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
		-- 9. The quarter's watch, and its second spare.
		{id = "terrace_watch", module = "buildings", make = "watchpost",
			order = 9, turns = 1, spec = {},
			extra_sockets = function(area)
				return {
					plots.spare("terrace_watch", area.x1 - 2, area.z1 - 2, 2),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL: what people keep behind their houses. A kitchen
	-- garden of raised beds, a goat pasture, a brewing court, and one green.
	local FILL = {
		-- 1. THE KITCHEN GARDEN: raised beds, a planter run and the two who
		-- weed them. `tend` faces a plant.
		{id = "terrace_kitchen_garden", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				local dwarf = area.dwarf
				dwarf.mushroom_bed(buf, palette, -9, 3, -2, 8)
				dwarf.mushroom_bed(buf, palette, 2, 3, 9, 8)
				dressing.planter(buf, palette, -8, -3, -3, -1)
				dressing.planter(buf, palette, 3, -3, 8, -1)
				dressing.flower_bed(buf, palette, -2, -3, 2, -1)
				-- A raised bed's kerb is masonry and stops a work socket's
				-- feature search on its own course, so the plant the gardener
				-- actually reaches is written INTO the kerb at the one cell the
				-- socket looks at (`dressing.plant` exists for exactly this).
				dressing.plant(buf, palette, -6, -3)
				dressing.bench(buf, palette, -3, -9, 0, 3, "x")
				dressing.crates(buf, palette, 8, -7, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("garden_beds_west", "tend", -6, 2, 0),
					plots.work("garden_beds_east", "tend", 6, 2, 0),
					plots.work("garden_planter", "tend", -6, -4, 0),
					plots.spare("kitchen_garden", 9, -9, 0),
				}
			end},
		-- 2. THE GOAT PASTURE: the milk and the wool of a terrace city, fenced,
		-- with hay and a handcart and the two who keep it.
		{id = "terrace_goat_pasture", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				area.dwarf.goat_pen(buf, palette, -10, -2, 10, 10)
				dressing.handcart(buf, palette, 3, -8, "x")
				dressing.flower_bed(buf, palette, -8, -8, -5, -6)
				dressing.plant(buf, palette, -7, -8)
				dressing.plant(buf, palette, -8, 4)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("pasture_trough", "tend", -8, 3, 0),
					plots.work("pasture_bed", "tend", -7, -9, 0),
					plots.spare("goat_pasture", 9, -9, 0),
				}
			end},
		-- 3. THE BREWING COURT: the vats the quarter's ale is made in, and the
		-- two who stir them.
		{id = "terrace_brew_court", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				area.dwarf.brew_vats(buf, palette, -5, 3, 3, "x")
				area.dwarf.brew_vats(buf, palette, -5, -1, 3, "x")
				dressing.crates(buf, palette, 6, -6, 0)
				dressing.bench(buf, palette, -3, -7, 0, 2, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("court_vats_north", "brew", -5, 2, 0),
					plots.work("court_vats_south", "brew", -1, -2, 0),
				}
			end},
		-- 4. THE TERRACE GREEN: a pine, a bench, the stores and the district's
		-- third spare.
		{id = "terrace_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.tree(buf, palette, 0, 2, 5)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.crates(buf, palette, 3, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("green_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("terrace_green", 4, -5, 0),
				}
			end},
	}

	M.homes = plots.district({
		key = "dur_brannoc_terraces",
		role = "residential_cultural",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
