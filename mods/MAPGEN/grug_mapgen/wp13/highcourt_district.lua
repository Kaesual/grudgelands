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
-- THE PROFESSIONS ARE HERE (playtest round 3). The district's name promised
-- them and the first version delivered a workshop, a counting house and a
-- store with nothing to say what was sold in them. Three of the nine now carry
-- a shopfront on the two-node ring their own plot leaves round the building --
-- a trestle counter, the tool of the trade beside it -- plus the two sockets
-- that make it a trade: a PROFESSION VENDOR at the counter (sockets contract
-- section 8.4) and a WORK socket at the tool (section 8.1). The buildings did
-- not move and their kits did not change; what changed is that the smithy has
-- an anvil in front of it and somebody standing at it.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/highcourt_plot.lua")(directory)

	local M = {}

	local WATCH = "highcourt_market_watch"

	-- The shopfront every profession house carries, in one place so three of
	-- them are the same shopfront: a four-node trestle counter on the street
	-- row of the plot's own ring, clear of the two lamps at the corners and of
	-- the doorstep path down the middle. The vendor stands OUTSIDE it on the
	-- plot's outermost row and looks at it, which is what a trader at a counter
	-- is and also what makes the socket's `dir` name the feature (section 8.1).
	local function shop_counter(buf, palette, area)
		area.dressing.counter(buf, palette, area.x1 - 5, area.z0 + 1, 4, "x")
	end
	local function shop_vendor(id, kind, area)
		return plots.vendor(id, kind, area.x1 - 4, area.z0, 0)
	end

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
		--
		-- THE SMITHY. The forge of the capital: an anvil on the apron with
		-- the smith at it, and the smith's own counter at the other end of
		-- the shopfront. The anvil is the human palette's `workbench`, which
		-- is `grug_decor:cottages_anvil` and is the node the sockets
		-- contract's `smith` activity names.
		{id = "market_workshop", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("workbench"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("anvil", "smith", area.x0 + 3, area.z0, 0),
					shop_vendor("smith", "smith", area),
				}
			end},
		--
		-- THE TAILOR'S. A scriptorium is a long room with shelving down both
		-- walls and desks in front of it, which is also what a cloth hall is;
		-- what says which of the two it is here is the shopfront. Its work
		-- socket is the contract's `sit`, on the bench outside the door -- the
		-- one activity that names no feature, because it sits on the ground it
		-- stands on, and the one that reads as needlework rather than as
		-- swinging a hammer. The socket's y is 2: the seat is a walkable node
		-- and the tailor sits ON it.
		{id = "market_counting_house", module = "capitals",
			make = "scriptorium", order = 4, roof = "slate",
			spec = {w = 13, d = 17, wall_h = 6},
			decorate = function(buf, palette, area)
				area.dressing.bench(buf, palette, area.x0 + 3, area.z0 + 1,
					2, 2, "x")
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("bench", "sit", area.x0 + 3, area.z0 + 1, 2,
						{"bench"}, 2),
					shop_vendor("tailor", "tailor", area),
				}
			end},
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
		-- THE BUTCHER'S. The block is a log of the palette's own `tree_log`,
		-- which is what the contract's `chop` activity names, so the butcher
		-- swinging a cleaver at it is the same animation the woodcutter in
		-- the orchard uses and the same feature rule.
		{id = "market_store", module = "buildings", make = "longhouse",
			order = 10,
			spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("tree_log"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.spare("store", area.x1 - 1, area.z1 - 1, 2),
					plots.work("block", "chop", area.x0 + 3, area.z0, 0),
					shop_vendor("butcher", "butcher", area),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL (playtest round 3): four dressings on the
	-- quadrant's four fill lots, in the order they take them. The reaches are
	-- 11, 11, 8 and 5 and `highcourt_quadrants.FILL_AUTHORED` owns those
	-- numbers, so a roster says WHAT a dressing is and never how big its lot
	-- is.
	--
	-- EVERY DRESSING IS LAID OUT THE SAME WAY, and the reason is the sockets.
	-- The three rows nearest the street (`z0` to `z0 + 2`) are the FORECOURT:
	-- the gate path, the two lamps, the props a socket faces and the sockets
	-- themselves. Everything from `z0 + 3` inwards is the FEATURE -- the pond,
	-- the furrows, the orchard rows -- and nothing authored there may land on
	-- a standing position, because ground cover is scattered by a hash and a
	-- tuft of grass in a socket's feet cell is a socket that has no headroom.
	-- A work socket therefore stands on `z0 + 2` and looks into `z0 + 3`,
	-- where the feature's first row is.
	local FILL = {
		--
		-- 1. THE TOWN POND, and the fishmonger beside it. The user's round-3
		-- ruling asked for "a small pond where citizens fish with a
		-- fishmonger beside it", and this is the whole of it: a lined basin
		-- three courses deep with its surface flush with the grass, a gravel
		-- shore, a bank walk with three fishing stands on it, and the
		-- fishmonger's counter at the gate with his own socket at it.
		--
		-- It is LEGAL water. The lot it stands on is dry on both gate seeds
		-- (`highcourt_plots.lua` rule 1, and the seam's own `audit_terrain`),
		-- and the basin is the PLOT's own cells, lined on five sides by
		-- `dressing.pond` -- so this is not a river the capital was built
		-- into but a pond the capital dug.
		--
		-- The pond stands in the NORTH half and the bank walk runs along
		-- z = 0. That is not composition: z = 0 is the plot's REFERENCE
		-- COLUMN, the one column whose terrain height the whole plot is
		-- levelled to, and it has to be walkable ground. A pond over it would
		-- be a plot levelled to the bottom of its own water.
		{id = "market_pond", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.pond(buf, palette, -8, 2, 8, 9, 3)
				for x = -9, 9 do buf:put(x, 0, 0, palette.node("path")) end
				dressing.broadleaf(buf, palette, -8, -5, 5)
				dressing.broadleaf(buf, palette, 8, -5, 5)
				dressing.undergrowth(buf, palette, -7, -8, 7, -2, 4)
				dressing.counter(buf, palette, -9, -10, 4, "x")
				dressing.crates(buf, palette, 8, -10, 0)
				dressing.bench(buf, palette, 3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("rod_west", "fish", -6, 0, 0),
					plots.work("rod_mid", "fish", 0, 0, 0),
					plots.work("rod_east", "fish", 6, 0, 0),
					plots.vendor("fishmonger", "fishmonger", -8, -11, 0),
				}
			end},
		--
		-- 2. THE ORCHARD INSIDE THE WALL RING, which is the contract's own
		-- line for the human capital (section 2.4) and the reason fill lot 1
		-- of every quadrant stands in the outer band, between the lot grid and
		-- the curtain. Three rows of standards over kept grass, a hedge on the
		-- field side, physic beds and a wood pile at the head of it, and the
		-- three who work it: two tending, one at the pile.
		{id = "market_orchard_close", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, z in ipairs({-2, 4, 8}) do
					for x = -8, 7, 5 do
						dressing.broadleaf(buf, palette, x, z, 5)
					end
				end
				dressing.hedge_line(buf, palette, -11, 11, 11, 11, 2)
				dressing.undergrowth(buf, palette, -10, -5, 10, 10, 5)
				dressing.flower_bed(buf, palette, -9, -8, -6, -6)
				dressing.flower_bed(buf, palette, 6, -8, 9, -6)
				dressing.wood_pile(buf, palette, 2, -8, 3, "x")
				dressing.bench(buf, palette, -4, -10, 0, 3, "x")
				dressing.crates(buf, palette, 8, -10, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("orchard_west", "tend", -8, -9, 0),
					plots.work("orchard_east", "tend", 8, -9, 0),
					plots.work("orchard_pile", "chop", 2, -9, 0),
				}
			end},
		--
		-- 3. THE MARKET GARDENS: the ploughed ground the district's stalls
		-- sell out of, hedged on the field side, with two at work in the rows
		-- and one of the district's spare wander spots at the gate.
		{id = "market_gardens", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.crop_rows(buf, palette, -6, -5, 6, 6, "z")
				dressing.hedge_line(buf, palette, -8, 8, 8, 8, 2)
				dressing.bench(buf, palette, -3, -7, 0, 3, "x")
				dressing.crates(buf, palette, 5, -7, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("row_west", "farm", -4, -6, 0),
					plots.work("row_east", "farm", 4, -6, 0),
					plots.spare("gardens", 7, -8, 0),
				}
			end},
		--
		-- 4. THE GREEN between two of the district's houses: the garden-sized
		-- fill lot, and the one that stands INSIDE the lot grid rather than
		-- round it. A standard, a bench under it, a flower bed and the
		-- district's second spare.
		{id = "market_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.broadleaf(buf, palette, 0, 2, 5)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.flower_bed(buf, palette, 1, -3, 4, -1)
			end,
			extra_sockets = function()
				return {
					plots.work("green_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("green", 4, -5, 0),
				}
			end},
	}

	M.market = plots.district({
		key = "highcourt_market",
		role = "market_professions",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
