-- Lethariel's four districts, their rosters, and where this world puts them.
--
-- The builder is `lethariel_plot.lua`; the lots and the permutation are
-- `lethariel_quadrants.lua`. This file is the one place the two meet, and it
-- is what the WP40 capital source asks for its plot list.
--
-- `M.resolve(options)` returns the plots in a FIXED order -- district by
-- district in the contract's own role order, each district's BUILDING plots in
-- roster order and then its FILL plots in roster order -- each with the offset
-- from the capital anchor that this world gives it. The order does not depend
-- on the seed, only the offsets do, which is what keeps the manifest's field
-- order and every blueprint identity independent of the world: a plot's
-- identity is its cells, and its cells do not know which quarter they will
-- stand in.
--
-- THREE DISTRICTS OF NINE AND ONE OF THREE. The lore and spiritual district is
-- the MERE PRECINCT and the lake is why it is smaller; the argument and the
-- measurement are in `lethariel_quadrants.lua` section 1. So the rosters here
-- are not four of a kind: three carry nine plots and four dressings, the
-- fourth carries three plots and two, and the resolve holds each of them to
-- the lot count of the quarter it actually stands in rather than to a number
-- typed twice.
--
-- WHAT MAKES A DISTRICT ELVEN, and it is not the palette alone. Every
-- profession house carries a SHOPFRONT on the two-node ring its own plot
-- leaves round the building -- a trestle counter, the tool of the trade beside
-- it -- plus the two sockets that make it a trade: a profession VENDOR at the
-- counter (sockets contract section 8.4) and a WORK socket at the tool
-- (section 8.1). What is elven is which trades they are: a bowyer at a
-- silverwood log, a herbalist at a cauldron, a weaver on a bench, a carver at
-- a standing stone -- and the groves between them, which is the contract's own
-- word for this race (section 2.4).
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/lethariel_plot.lua")(directory)
	local quadrants = dofile(directory .. "/lethariel_quadrants.lua")()

	local M = {}

	M.quadrants = quadrants

	----------------------------------------------------------------------
	-- Shared shopfront
	----------------------------------------------------------------------

	-- The counter every profession house carries, in one place so five of
	-- them are the same counter: a four-node trestle on the street row of the
	-- plot's own ring, clear of the two lantern pillars at the corners and of
	-- the doorstep path down the middle. The vendor stands OUTSIDE it on the
	-- plot's outermost row and looks at it, which is what a trader at a
	-- counter is and also what makes the socket's `dir` name the feature.
	local function shop_counter(buf, palette, area)
		area.dressing.counter(buf, palette, area.x1 - 5, area.z0 + 1, 4, "x")
	end
	local function shop_vendor(id, kind, area)
		return plots.vendor(id, kind, area.x1 - 4, area.z0, 0)
	end
	-- A TRAINING DUMMY, the feature the sockets contract's `spar` activity
	-- names: "another `spar` socket or a training dummy (a fence post or a
	-- wool node)". A fence post with a wool head is both halves of that
	-- sentence, and it is authored here rather than taken from
	-- `dressing.drill_post`, whose post is a LOG -- which is `chop`'s feature
	-- and not `spar`'s.
	local function dummy(buf, palette, x, z)
		buf:put(x, 1, z, palette.node("fence"))
		buf:put(x, 2, z, palette.node("fence"))
		buf:put(x, 3, z, palette.node("rug"))
	end

	-- And the work socket at the counter's own far end, facing it: `stall` is
	-- the sockets contract's "stands at a counter", and a counter is a solid
	-- node at waist height, which is exactly what `dressing.counter` writes.
	local function shop_work(id, area)
		return plots.work(id, "stall", area.x1 - 5, area.z0, 0)
	end

	----------------------------------------------------------------------
	-- 1. Market and professions
	----------------------------------------------------------------------

	local MARKET_WATCH = "lethariel_market_watch"

	local MARKET = {
		-- 1. The grain hall.
		{id = "market_granary", module = "capitals", make = "granary",
			order = 1, roof = "pale", spec = {w = 11, d = 15, wall_h = 5}},
		-- 2. The stable, for the beasts the avenues carry.
		{id = "market_stable", module = "capitals", make = "stable",
			order = 2, spec = {w = 15, d = 11, wall_h = 5}},
		-- 3. THE BOWYER'S, the first of this race's own trades. The workshop
		-- opens in its x- wall (the `workshop` interior kit stands its
		-- cauldrons on the odd cells of the z- gable's inner run, so a door
		-- there opens onto a hearth) and the PLOT is turned so that wall
		-- faces the street. The stave on the apron is a silverwood log, which
		-- is what the sockets contract's `carve` activity names.
		{id = "market_bowyer", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("tree_log"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("stave", "carve", area.x0 + 3, area.z0, 0),
					shop_vendor("bowyer", "bowyer", area),
				}
			end},
		-- 4. THE WEAVER'S. A scriptorium is a long room with shelving down
		-- both walls and desks in front of it, which is also what a cloth hall
		-- is; what says which of the two it is here is the shopfront. Its work
		-- socket is `sit`, on the bench outside the door -- the one activity
		-- that names no feature, because it sits on the ground it stands on,
		-- and the one that reads as needlework. The socket's y is 2: a seat is
		-- a walkable node and the weaver sits ON it.
		{id = "market_weaver", module = "capitals", make = "scriptorium",
			order = 4, roof = "pale", spec = {w = 13, d = 17, wall_h = 6},
			decorate = function(buf, palette, area)
				-- x0 + 5 and not x0 + 3: the plot's own lantern pillar is
				-- three by three at (x0 + 2, z0 + 2), so a bench three nodes
				-- in shares a column with one of its posts and the weaver
				-- sitting on it has a pillar through her head.
				area.dressing.bench(buf, palette, area.x0 + 5, area.z0 + 1,
					2, 2, "x")
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("bench", "sit", area.x0 + 5, area.z0 + 1, 2,
						{"bench"}, 2),
					shop_vendor("weaver", "tailor", area),
				}
			end},
		-- 5. The fountain court: the district's public garden, so its plot is
		-- three nodes wider all round than a building's and the ring that buys
		-- is planted.
		{id = "market_fountain", module = "capitals", make = "well_court",
			order = 5, margin = 4, garden = true, spec = {size = 11}},
		-- 6. The market watch.
		{id = "market_watch", module = "capitals", make = "barracks",
			roof = "pale",
			spec = {w = 13, d = 17, wall_h = 5, patrol_group = MARKET_WATCH,
				order = 6}},
		-- 7. The grove between the plots, which is the contract's own word for
		-- what stands between elf buildings. It carries one of the district's
		-- two SPARE wander spots and its forager.
		{id = "market_grove", module = "capitals", make = "grove",
			order = 7,
			spec = {size = 15, kind = "columnar", height = 7},
			-- ONE PLANT, WHERE THE FORAGER'S HANDS ARE. A grove is leaves and
			-- litter and a socket facing into it may look down three nodes of
			-- open air; the sockets contract's feature test reads the first
			-- solid node on the socket's own course, so the thing being
			-- foraged is authored rather than hoped for.
			decorate = function(buf, palette, area)
				area.dressing.plant(buf, palette, 0, -2)
			end,
			extra_sockets = function(area)
				return {
					plots.spare("grove", area.x0 + 1, area.z1 - 1, 2),
					plots.work("forage", "forage", 0, -3, 0),
				}
			end},
		-- 8. The orchard edge along the district's own outer row.
		{id = "market_orchard", module = "capitals", make = "orchard_edge",
			spec = {len = 21, d = 11, patrol_group = MARKET_WATCH, order = 8},
			-- `orchard_edge` puts its two street waypoints two nodes in from
			-- each end of its own ring street, and on a 23-node plot that is
			-- exactly where the plot's own lantern pillars stand. The
			-- generator cannot know that -- it knows its own piece and nothing
			-- about the plot it is stamped into -- so the roster says so,
			-- through the hook the builder gives it.
			socket_overrides = function(area)
				return {
					market_orchard_street_a = {x = -5, z = area.z0 + 1},
					market_orchard_street_b = {x = 5, z = area.z0 + 1},
				}
			end},
		-- 9. THE BAKER'S. Door index 4, single leaf: the `store` kit stands
		-- its roof posts on the odd cells of the gable's inner run, so an
		-- eleven-wide longhouse's centred door opens onto a post.
		{id = "market_bakehouse", module = "buildings", make = "longhouse",
			order = 10,
			spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true},
			decorate = function(buf, palette, area)
				area.dressing.counter(buf, palette, area.x0 + 2, area.z0 + 1,
					3, "x")
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.spare("bakehouse", area.x1 - 1, area.z1 - 1, 2),
					plots.work("oven", "stall", area.x0 + 2, area.z0, 0),
					shop_vendor("baker", "baker", area),
				}
			end},
	}

	-- THE MARKET'S FILL. Every dressing is laid out the same way and the
	-- reason is the sockets: the three rows nearest the street (`z0`..`z0 + 2`)
	-- are the FORECOURT -- the gate path, the two lanterns, the props a socket
	-- faces and the sockets themselves -- and everything from `z0 + 3` inwards
	-- is the FEATURE. Nothing authored in the feature may land on a standing
	-- position, because ground cover is scattered by a hash and a tuft of
	-- grass in a socket's feet cell is a socket with no headroom. A work socket
	-- therefore stands on `z0 + 2` and looks into `z0 + 3`.
	local MARKET_FILL = {
		-- 1. THE GARDEN ROWS the district's stalls sell out of, hedged on the
		-- field side, with two at work in the furrows.
		{id = "market_gardens", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.crop_rows(buf, palette, -8, -5, 8, 8, "z")
				dressing.hedge_line(buf, palette, -10, 10, 10, 10, 2)
				dressing.bench(buf, palette, -4, -8, 0, 3, "x")
				dressing.crates(buf, palette, 7, -8, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("row_west", "farm", -5, -6, 0),
					plots.work("row_east", "farm", 5, -6, 0),
					plots.spare("gardens", 9, -9, 0),
				}
			end},
		-- 2. THE ORCHARD CLOSE: three rows of standards over kept grass, a
		-- hedge on the field side, flower beds at the head of it, and the
		-- three who work it.
		{id = "market_close", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, z in ipairs({-1, 4, 9}) do
					for x = -8, 7, 5 do
						dressing.columnar(buf, palette, x, z, 7)
					end
				end
				dressing.hedge_line(buf, palette, -10, 10, 10, 10, 2)
				dressing.flower_bed(buf, palette, -9, -8, -6, -6)
				dressing.flower_bed(buf, palette, 6, -8, 9, -6)
				dressing.plant(buf, palette, -8, -8)
				dressing.plant(buf, palette, 8, -8)
				dressing.wood_pile(buf, palette, 2, -8, 3, "x")
				dressing.bench(buf, palette, -4, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("close_west", "tend", -8, -9, 0),
					plots.work("close_east", "tend", 8, -9, 0),
					plots.work("close_pile", "chop", 2, -9, 0),
				}
			end},
		-- 3. THE PADDOCK, on the outer corner of the quarter.
		{id = "market_paddock", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -7, 7, 7, 7)
				dressing.fence_line(buf, palette, -7, -1, -7, 7)
				dressing.fence_line(buf, palette, 7, -1, 7, 7)
				dressing.bale_stack(buf, palette, -5, -3, 2)
				dressing.handcart(buf, palette, 4, -3, "x")
				dressing.plant(buf, palette, 0, -3)
			end,
			extra_sockets = function()
				return {
					plots.work("paddock_tend", "tend", 0, -4, 0),
					plots.spare("paddock", 5, -6, 0),
				}
			end},
		-- 4. THE GREEN between two of the district's houses: the garden-sized
		-- lot, and the one that stands INSIDE the lot grid rather than round
		-- it.
		{id = "market_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.columnar(buf, palette, 0, 2, 6)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.flower_bed(buf, palette, 1, -3, 4, -1)
				-- The kerb broken at the one cell the gardener reaches into.
				dressing.plant(buf, palette, 2, -3)
			end,
			extra_sockets = function()
				return {
					plots.work("green_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.work("green_bed", "tend", 2, -4, 0),
				}
			end},
	}

	----------------------------------------------------------------------
	-- 2. Martial and garrison
	----------------------------------------------------------------------

	local MARTIAL_WATCH = "lethariel_martial_watch"

	local MARTIAL = {
		{id = "martial_barracks", module = "capitals", make = "barracks",
			roof = "pale",
			spec = {w = 13, d = 17, wall_h = 5, patrol_group = MARTIAL_WATCH,
				order = 1},
			extra_sockets = function(area)
				-- x = -4: the plot builder sets a bench at x 3..5 on this very
				-- row, and a guard standing in it is a guard standing in a
				-- bench.
				return {plots.guard_post("barracks_gate", -4, area.z0 + 2, 0)}
			end},
		-- The armoury, with the armourer's counter on the apron.
		{id = "martial_armoury", module = "buildings", make = "workshop",
			order = 2, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("workbench"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					shop_work("counter", area),
					shop_vendor("armourer", "armourer", area),
				}
			end},
		-- The watch tower, which is what an open capital has in place of a
		-- wall turret.
		{id = "martial_tower", module = "buildings", make = "watchpost",
			order = 3, spec = {w = 9, d = 9, wall_h = 4},
			extra_sockets = function(area)
				return {plots.guard_post("tower", -3, area.z0 + 2, 0)}
			end},
		-- The muster hall.
		{id = "martial_hall", module = "buildings", make = "hall",
			order = 4, roof = "pale",
			spec = {w = 13, d = 17, wall_h = 6, infill = true}},
		-- The stable of the guard.
		{id = "martial_stable", module = "capitals", make = "stable",
			order = 5, spec = {w = 15, d = 11, wall_h = 5}},
		-- The armoury store.
		{id = "martial_store", module = "buildings", make = "longhouse",
			order = 6,
			spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true},
			extra_sockets = function(area)
				return {plots.spare("store", area.x1 - 1, area.z1 - 1, 2)}
			end},
		-- The grove the district musters in front of.
		{id = "martial_grove", module = "capitals", make = "grove",
			order = 7, spec = {size = 15, kind = "columnar", height = 7},
			extra_sockets = function(area)
				return {plots.spare("grove", area.x0 + 1, area.z1 - 1, 2)}
			end},
		-- The wardens' lodge.
		{id = "martial_lodge", module = "buildings", make = "cottage",
			order = 8, turns = 1,
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
		-- The look-out platform in the boughs: this capital's own part, and
		-- the martial district is where a lookout belongs.
		{id = "martial_bough", module = "elf", make = "tree_platform",
			order = 9, spec = {size = 11, deck = 7, wall_h = 3}},
	}

	local MARTIAL_FILL = {
		-- 1. THE TRAINING LAWN, and the three who spar on it. The sockets
		-- contract's `spar` wants another `spar` socket or a training dummy --
		-- a fence post or a wool node -- under `dir` within three nodes; the
		-- two on the lawn face each other across two nodes and the third
		-- faces a post.
		{id = "martial_lawn", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -9, 9, 9, 9)
				for _, x in ipairs({-3, 0, 3}) do
					dummy(buf, palette, x, 5)
				end
				dressing.standard(buf, palette, -8, 3, 5)
				dressing.standard(buf, palette, 8, 3, 5)
				dressing.bench(buf, palette, -4, -8, 0, 3, "x")
				dressing.crates(buf, palette, 7, -8, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("spar_west", "spar", -3, 3, 0),
					plots.work("spar_east", "spar", 3, 3, 0),
					plots.work("spar_mid", "spar", 0, 3, 0),
				}
			end},
		-- 2. THE ARCHERY WALK: the butts at the far end and the line at the
		-- near one.
		{id = "martial_butts", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.hedge_line(buf, palette, -10, 10, 10, 10, 3)
				for _, x in ipairs({-6, 0, 6}) do
					dummy(buf, palette, x, 4)
				end
				dressing.bench(buf, palette, 3, -8, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("butt_west", "spar", -6, 2, 0),
					plots.work("butt_mid", "spar", 0, 2, 0),
					plots.spare("butts", 8, -9, 0),
				}
			end},
		-- 3. THE WOODYARD on the outer corner: the fuel the garrison burns.
		{id = "martial_woodyard", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.wood_pile(buf, palette, -5, 3, 5, "x")
				dressing.wood_pile(buf, palette, -5, 5, 5, "x")
				buf:put(2, 1, 3, palette.node("tree_log"))
				dressing.crates(buf, palette, 6, -3, 0)
				dressing.fence_line(buf, palette, -7, 7, 7, 7)
			end,
			extra_sockets = function()
				return {
					plots.work("block", "chop", 2, 2, 0),
					plots.work("pile", "chop", -4, 2, 0),
				}
			end},
		-- 4. THE MESS GREEN: benches and a cauldron between two of the
		-- district's houses.
		{id = "martial_mess", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				buf:put(0, 1, 1, palette.node("hearth"))
				dressing.bench(buf, palette, -4, -3, 0, 3, "x")
				dressing.bench(buf, palette, 2, -3, 0, 3, "x")
				dressing.columnar(buf, palette, 3, 2, 6)
			end,
			extra_sockets = function()
				return {
					plots.work("pot", "brew", 0, 0, 0),
					plots.work("mess_bench", "sit", -4, -3, 0, {"bench"}, 2),
				}
			end},
	}

	----------------------------------------------------------------------
	-- 3. Lore and spiritual -- THE MERE PRECINCT
	----------------------------------------------------------------------

	local MERE_WATCH = "lethariel_mere_watch"

	local MERE = {
		-- 1. THE SHRINE OF THE MERE, this capital's own part, with the
		-- district's quest shell on its own landing.
		-- MARGIN 3, not the default 2: the shrine's own south flight of three
		-- treads stands on the row a two-node ring would put this plot's gate
		-- socket on, and a socket in a stair is a socket with no feet cell.
		{id = "mere_shrine", module = "elf", make = "shrine",
			order = 1, margin = 3, spec = {size = 9, rise = 5, quest = true}},
		-- 2. THE LORE HALL on the shelf above the water.
		{id = "mere_lore_hall", module = "capitals", make = "scriptorium",
			order = 2, roof = "pale", spec = {w = 13, d = 17, wall_h = 6},
			decorate = function(buf, palette, area)
				area.dressing.counter(buf, palette, area.x1 - 5,
					area.z0 + 1, 4, "x")
				-- The herbalist's cauldron on the apron: the feature the
				-- `brew` activity names.
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("hearth"))
			end,
			extra_sockets = function(area)
				return {
					plots.vendor("herbalist", "herbalist", area.x1 - 4,
						area.z0, 0),
					plots.work("herbs", "brew", area.x0 + 3, area.z0, 0),
					plots.spare("lore", area.x0 + 1, area.z1 - 1, 2),
				}
			end,
			-- The herbalist's cauldron on the apron, which is the feature the
			-- `brew` activity names.
			socket_overrides = function() return {} end},
		-- 3. THE MOURNING GROVE: the graves of the city, under kept boughs.
		{id = "mere_mourning", module = "capitals", make = "grove",
			order = 3, spec = {size = 15, kind = "columnar", height = 7},
			-- THE GRAVE ROW RUNS DOWN THE WEST SIDE, not across the
			-- forecourt. A grove's own standards stand at the four corners of
			-- its pad -- (-5, -5) and (5, -5) among them -- and a crown
			-- reaches two nodes: every position on the south rows is either a
			-- stem, a leaf, the builder's own bench or one of the plot's two
			-- lantern pillars. The west ring is the one strip of this plot
			-- that belongs to nothing else.
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, z in ipairs({-2, 0, 2}) do
					dressing.grave(buf, palette, -8, z, z == 0)
				end
			end,
			extra_sockets = function()
				return {
					plots.work("grave_north", "mourn", -7, -2, 3),
					plots.work("grave_south", "mourn", -7, 2, 3),
					plots.spare("mourning", -4, -8, 0),
				}
			end},
	}

	local MERE_FILL = {
		-- 1. THE FISHING STAGES on the city's own basin, with three anglers on
		-- the deck and the fishmonger at the counter behind them. The basin is
		-- the PLOT's own cells, lined on five sides by `dressing.pond`, so this
		-- is water the capital dug and not the lake the capital was built
		-- beside -- every lot is dry ground by the predicate's first rule.
		{id = "mere_stages", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				-- The basin fills the far half and the BANK WALK runs along
				-- z = 0, which is the plot's REFERENCE COLUMN: the one column
				-- the whole plot is levelled to has to be walkable ground, so
				-- a pond over it would be a plot levelled to the bottom of its
				-- own water.
				dressing.pond(buf, palette, -6, 2, 6, 7, 3)
				for x = -7, 7 do buf:put(x, 0, 0, palette.node("path")) end
				dressing.counter(buf, palette, -7, -3, 4, "x")
				dressing.crates(buf, palette, 6, -3, 0)
				dressing.bench(buf, palette, 1, -3, 0, 3, "x")
				dressing.columnar(buf, palette, -6, 6, 6)
				dressing.columnar(buf, palette, 6, 6, 6)
			end,
			extra_sockets = function()
				return {
					-- Three anglers on the bank, each looking at the water two
					-- nodes in front of it. The water's own surface stands at
					-- the plot's ground course, which is one below the feet
					-- cell -- the feature search reads the course and the two
					-- either side of it, exactly as the sockets contract says.
					plots.work("rod_west", "fish", -5, 0, 0),
					plots.work("rod_mid", "fish", 0, 0, 0),
					plots.work("rod_east", "fish", 5, 0, 0),
					plots.vendor("fishmonger", "fishmonger", -6, -4, 0),
				}
			end},
		-- 2. THE LANTERN WALK: the small lot, a walk of lantern pillars over
		-- the shore with a bench under each.
		{id = "mere_walk", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for x = -3, 3 do
					for z = -1, 1 do
						buf:put(x, 0, z, palette.node("plaza"))
					end
				end
				dressing.lantern_pillar(buf, palette, -3, 2)
				dressing.lantern_pillar(buf, palette, 3, 2)
				-- x 2..4, clear of the gate path this builder lays down the
				-- middle of every yard and of the flair spot standing on it.
				dressing.bench(buf, palette, 2, -3, 0, 3, "x")
				dressing.plant(buf, palette, 0, 2)
			end,
			extra_sockets = function()
				return {
					plots.work("walk_bench", "sit", 2, -3, 0, {"bench"}, 2),
					plots.spare("walk", -3, -4, 0),
				}
			end},
	}

	----------------------------------------------------------------------
	-- 4. Residential and cultural
	----------------------------------------------------------------------

	local HOMES_WATCH = "lethariel_homes_watch"

	local HOMES = {
		{id = "homes_terrace_west", module = "buildings", make = "cottage",
			order = 1, turns = 1,
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
		{id = "homes_terrace_east", module = "buildings", make = "cottage",
			order = 2, turns = 3,
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip", infill = true,
				shutters = true}},
		{id = "homes_longhouse", module = "buildings", make = "longhouse",
			order = 3,
			spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true}},
		-- THE BREWHOUSE, with the brewer's counter on the apron and the
		-- cauldron beside it.
		{id = "homes_brewhouse", module = "buildings", make = "workshop",
			order = 4, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("hearth"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("vat", "brew", area.x0 + 3, area.z0, 0),
					shop_vendor("brewer", "brewer", area),
				}
			end},
		-- THE CARVER'S YARD: a hall with a standing stone on the apron, which
		-- is the feature `carve` names.
		{id = "homes_carver", module = "buildings", make = "hall",
			order = 5, roof = "pale",
			spec = {w = 13, d = 17, wall_h = 6, infill = true},
			decorate = function(buf, palette, area)
				local signature = palette.maybe("signature") or
					palette.node("wall_accent")
				buf:put(area.x0 + 3, 1, area.z0 + 1, signature)
				buf:put(area.x0 + 3, 2, area.z0 + 1, signature)
				area.dressing.crates(buf, palette, area.x0 + 5, area.z0 + 1, 0)
			end,
			extra_sockets = function(area)
				return {plots.work("stone", "carve", area.x0 + 3, area.z0, 0)}
			end},
		-- The hall of feasts.
		{id = "homes_feast_hall", module = "capitals", make = "scriptorium",
			order = 6, roof = "pale", spec = {w = 13, d = 17, wall_h = 6}},
		-- The bough house, the second of this capital's tree platforms.
		{id = "homes_bough", module = "elf", make = "tree_platform",
			order = 7, spec = {size = 11, deck = 6, wall_h = 3},
			extra_sockets = function(area)
				return {plots.spare("bough", area.x1 - 1, area.z1 - 1, 2)}
			end},
		-- The garden court.
		{id = "homes_court", module = "capitals", make = "well_court",
			order = 8, margin = 4, garden = true, spec = {size = 11}},
		-- The grove the quarter sits in.
		{id = "homes_grove", module = "capitals", make = "grove",
			order = 9, spec = {size = 15, kind = "columnar", height = 7},
			decorate = function(buf, palette, area)
				area.dressing.plant(buf, palette, 0, -2)
			end,
			extra_sockets = function(area)
				return {
					plots.spare("grove", area.x0 + 1, area.z1 - 1, 2),
					plots.work("forage", "forage", 0, -3, 0),
				}
			end},
	}

	local HOMES_FILL = {
		-- 1. THE HOUSEHOLD GARDENS.
		{id = "homes_gardens", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.crop_rows(buf, palette, -8, -5, 8, 6, "z")
				dressing.hedge_line(buf, palette, -10, 8, 10, 8, 2)
				dressing.flower_bed(buf, palette, -9, -8, -6, -6)
				dressing.plant(buf, palette, -8, -8)
				dressing.bench(buf, palette, 2, -8, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("row_west", "farm", -5, -6, 0),
					plots.work("row_east", "farm", 5, -6, 0),
					plots.work("beds", "tend", -8, -9, 0),
				}
			end},
		-- 2. THE SINGING GROVE, the quarter's own stand of silverwood with a
		-- lantern walk through it.
		{id = "homes_singing_grove", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, spot in ipairs({{-7, 0}, {0, 3}, {7, 1}, {-4, 7},
						{5, 7}}) do
					dressing.columnar(buf, palette, spot[1], spot[2], 8)
				end
				for z = -8, 9 do buf:put(0, 0, z, palette.node("path")) end
				dressing.lantern_pillar(buf, palette, -3, -6)
				dressing.lantern_pillar(buf, palette, 3, -6)
				dressing.bench(buf, palette, -5, -9, 0, 3, "x")
				dressing.undergrowth(buf, palette, -9, -4, 9, 9, 5)
				dressing.plant(buf, palette, -6, -2)
			end,
			extra_sockets = function()
				return {
					plots.work("grove_forage", "forage", -6, -3, 0),
					plots.work("grove_bench", "sit", -5, -9, 0, {"bench"}, 2),
					plots.spare("singing", 7, -9, 0),
				}
			end},
		-- 3. THE POTTERS' YARD on the outer corner.
		{id = "homes_yard", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				buf:put(-3, 1, 3, palette.node("hearth"))
				dressing.crates(buf, palette, 3, 3, 0)
				dressing.counter(buf, palette, 1, 3, 3, "x")
				dressing.fence_line(buf, palette, -7, 7, 7, 7)
				dressing.bench(buf, palette, -6, -6, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("kiln", "brew", -3, 2, 0),
					plots.work("bench", "stall", 1, 2, 0),
				}
			end},
		-- 4. THE CHILDREN'S GREEN.
		{id = "homes_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.columnar(buf, palette, 0, 2, 6)
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

	----------------------------------------------------------------------
	-- The four districts
	----------------------------------------------------------------------

	M.districts = {
		plots.district({key = "lethariel_market",
			role = "market_professions", patrol_group = MARKET_WATCH,
			plots = MARKET, fill = MARKET_FILL,
			fill_reaches = quadrants.FILL_REACHES}),
		plots.district({key = "lethariel_martial",
			role = "martial_garrison", patrol_group = MARTIAL_WATCH,
			plots = MARTIAL, fill = MARTIAL_FILL,
			fill_reaches = quadrants.FILL_REACHES}),
		plots.district({key = "lethariel_mere",
			role = "lore_spiritual", patrol_group = MERE_WATCH,
			plots = MERE, fill = MERE_FILL,
			fill_reaches = quadrants.MERE_FILL_REACHES}),
		plots.district({key = "lethariel_homes",
			role = "residential_cultural", patrol_group = HOMES_WATCH,
			plots = HOMES, fill = HOMES_FILL,
			fill_reaches = quadrants.FILL_REACHES}),
	}

	do
		local roles = quadrants.ROLES
		if #M.districts ~= #roles then
			error("wp13 lethariel: district roster differs", 0)
		end
		for index = 1, #roles do
			if M.districts[index].role ~= roles[index] then
				error("wp13 lethariel: district " .. index .. " is not " ..
					roles[index], 0)
			end
		end
	end

	-- The plots with their offsets, for this world.
	--
	-- `options` is the quadrant seam of `lethariel_quadrants.assign`:
	-- `full_seed` plus `raw_sha256` where a world is being generated, an
	-- explicit `permutation` where a test names one, and neither where there
	-- is no world at all -- an engine-free fixture, a renderer, the timing
	-- harness -- in which case the moving roles take the moving quarters in
	-- authored order.
	function M.resolve(options)
		local assignment, permutation = quadrants.assign(options)
		local list = {}
		for index = 1, #M.districts do
			local district = M.districts[index]
			local placement = assignment[district.role]
			if placement == nil then
				error("wp13 lethariel: no quarter for " .. district.role, 0)
			end
			local function append(entries, lots, kind)
				if #entries ~= #lots then
					error("wp13 lethariel: " .. district.role .. " has " ..
						#entries .. " " .. kind .. " rows against " .. #lots ..
						" lots in " .. placement.quadrant, 0)
				end
				for plot_index = 1, #entries do
					local plot = entries[plot_index]
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
