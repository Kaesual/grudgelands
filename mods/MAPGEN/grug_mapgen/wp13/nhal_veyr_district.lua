-- Nhal Veyr, the ossuary market and trades district: the first of the
-- capital's four, nine terrain-relative plots and four fill dressings.
--
-- This file is a ROSTER. What a plot is, how it is levelled, skirted, cleared
-- and dressed, and what it publishes, all live in `nhal_veyr_plot.lua`, which
-- is the same builder for all four districts. WHERE the nine plots stand is
-- `nhal_veyr_quadrants.lua`: a district owns no coordinates of its own,
-- because the world seed decides which quadrant of the capital it occupies
-- and the ground decides where the nine lots of that quadrant are.
--
-- THE TRADES ARE THE POINT OF THIS DISTRICT. Four of the nine carry a
-- shopfront on the two-node ring their own plot leaves round the building -- a
-- trestle counter, the tool of the trade beside it -- plus the two sockets
-- that make it a trade: a PROFESSION VENDOR at the counter (sockets contract
-- section 8.4) and a WORK socket at the tool (section 8.1). Nhal Veyr's four
-- are the bonesmith, the shroud house, the physic house and the charnel store,
-- and the kinds they carry are `smith`, `tailor`, `herbalist` and -- in the
-- vigil district, which is where an embalmer belongs -- `embalmer`. The core's
-- own ossuary court holds the two `grug_traders` families, so the city's
-- vendor multiset is six kinds and one of each, which the KAT asserts.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/nhal_veyr_plot.lua")(directory)

	local M = {}

	local WATCH = "nhal_veyr_market_watch"

	-- The shopfront every profession house carries, in one place so four of
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
	-- is one loop with one group and no gaps: the KAT walks it 1..n. The
	-- barracks carries its own inside `spec`, because that generator publishes
	-- the waypoint itself.
	local PLOTS = {
		{id = "market_bone_store", module = "capitals", make = "granary",
			order = 1, handle = "crypt", roof = "vault",
			spec = {w = 11, d = 15, wall_h = 5}},
		{id = "market_cart_yard", module = "capitals", make = "stable",
			order = 2, spec = {w = 15, d = 11, wall_h = 5}},
		--
		-- THE BONESMITH. The forge of the necropolis: the contract's own
		-- "bonesmith (use `smith`)". The anvil on the apron is
		-- `grug_decor:cottages_anvil` written by name rather than through a
		-- palette role, because this palette's `workbench` is the bone
		-- carver's bench (an xdecor workbench cube) and the sockets contract
		-- says `smith` faces "an anvil or a furnace". A role that means one
		-- thing in the Hollow and another here is worse than a name.
		--
		-- The workshop opens in its x- wall and the PLOT is turned so that
		-- wall faces the street. Its z- gable cannot carry the door: the
		-- `workshop` interior kit stands the forge's cauldrons on the odd
		-- cells of the inner run of that very wall, and a double door takes an
		-- odd cell whichever index it is given, so the doorway would open onto
		-- a hearth. The same wall also carries the generator's chimney stack.
		{id = "market_bonesmith", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, "grug_decor:cottages_anvil")
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("anvil", "smith", area.x0 + 3, area.z0, 0),
					shop_vendor("smith", "smith", area),
				}
			end},
		--
		-- THE SHROUD HOUSE. A scriptorium is a long room with shelving down
		-- both walls and desks in front of it, which is also what a shroud
		-- weaver's hall is; what says which of the two it is here is the
		-- shopfront. Its work socket is the contract's `sit`, on the bench
		-- outside the door -- the one activity that names no feature, because
		-- it sits on the ground it stands on. The socket's y is 2: the seat is
		-- a walkable node and the weaver sits ON it.
		{id = "market_shroud_house", module = "capitals", make = "scriptorium",
			order = 4, handle = "crypt", roof = "vault",
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
		-- The cistern court is the district's public ground, so its plot is
		-- five nodes wider all round than a building's and the ring that buys
		-- is planted with gravewoods.
		{id = "market_cistern", module = "capitals", make = "well_court",
			order = 5, margin = 5, garden = true, spec = {size = 11}},
		{id = "market_watch", module = "capitals", make = "barracks",
			handle = "crypt", roof = "vault",
			spec = {w = 15, d = 21, wall_h = 5, patrol_group = WATCH,
				order = 6}},
		-- The gravewood copse, and the district's first SPARE wander spot: an
		-- idle position a walking NPC may use as a destination and which the
		-- placement engine is meant not to staff with an inhabitant of its own.
		{id = "market_copse", module = "capitals", make = "grove",
			order = 7,
			spec = {size = 15, kind = "gravewood", height = 6},
			extra_sockets = function(area)
				return {plots.spare("copse", area.x0 + 1, area.z1 - 1, 2)}
			end},
		--
		-- THE PHYSIC HOUSE, and the herbalist. `brew` is the wave-2 activity
		-- and its feature is "a cauldron, barrel or cooking pot"; this
		-- palette's `hearth` IS `grug_decor:xdecor_cauldron`, so the pot on
		-- the apron is the palette's own role and the socket faces it.
		{id = "market_physic", module = "buildings", make = "hall",
			order = 8,
			spec = {w = 13, d = 17, wall_h = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("hearth"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("pot", "brew", area.x0 + 3, area.z0, 0),
					shop_vendor("herbalist", "herbalist", area),
				}
			end},
		--
		-- THE CHARNEL STORE. Door index 4, single leaf: the `store` kit stands
		-- its roof posts on the odd cells of the gable's inner run, so an
		-- eleven-wide longhouse's centred door opens onto a post. The block on
		-- its apron is the palette's own `tree_log` -- gravewood -- which is
		-- what the wave-2 `carve` activity names, so the carver working bone
		-- at it is the same feature rule the woodcutter's is.
		{id = "market_charnel", module = "buildings", make = "longhouse",
			order = 9,
			spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("tree_log"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.spare("charnel", area.x1 - 1, area.z1 - 1, 2),
					plots.work("block", "carve", area.x0 + 3, area.z0, 0),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL: four dressings on the quadrant's four fill
	-- lots, in the order they take them. The reaches are 11, 11, 8 and 5 and
	-- `nhal_veyr_quadrants.FILL_AUTHORED` owns those numbers, so a roster says
	-- WHAT a dressing is and never how big its lot is.
	--
	-- EVERY DRESSING IS LAID OUT THE SAME WAY, and the reason is the sockets.
	-- The three rows nearest the street (`z0` to `z0 + 2`) are the FORECOURT:
	-- the gate path, the two lamps, the props a socket faces and the sockets
	-- themselves. Everything from `z0 + 3` inwards is the FEATURE -- the grave
	-- rows, the bone yard, the candle court -- and nothing authored there may
	-- land on a standing position, because ground cover is scattered by a hash
	-- and a tuft of dry shrub in a socket's feet cell is a socket with no
	-- headroom. A work socket therefore stands on `z0 + 2` and looks into
	-- `z0 + 3`, where the feature's first row is.
	local FILL = {
		--
		-- 1. THE GRAVE FIELD. The undead capital's answer to Highcourt's crop
		-- fields (the lane brief: "graveyard fields instead of crop fields").
		-- Rows of markers on flagstones with the odd plot left open, a walk
		-- along the reference column, and the three who keep it: two MOURNING
		-- at the markers and one TENDING the blight bed at the gate.
		--
		-- The walk runs along z = 0 and the grave rows stand either side of
		-- it. That is not composition: z = 0 is the plot's REFERENCE COLUMN,
		-- the one column whose terrain height the whole plot is levelled to,
		-- and it has to be walkable ground.
		--
		-- `tend` FACES A PLANT AND NOT A GRAVE, and the two halves of that are
		-- both deliberate. The lane brief's design space says "`tend` on the
		-- graves"; the sockets contract's section 8.1 says a `tend` socket
		-- faces "a plant or a flower" within three nodes. So the tender stands
		-- among the graves and faces the blight bed that has grown over them,
		-- which satisfies the contract's rule and the brief's picture at once.
		{id = "market_grave_field", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.graveyard(buf, palette, -9, 2, 9, 10)
				dressing.graveyard(buf, palette, -9, -7, 9, -3)
				for x = -10, 10 do buf:put(x, 0, 0, palette.node("path")) end
				-- Two markers set DELIBERATELY on the row the walk runs
				-- along, because the two mourners have to face one and
				-- `dressing.graveyard` decides by a hash which of its
				-- columns carry a marker at all. A socket whose feature is
				-- whatever a scatter happened to leave is a socket that
				-- breaks the day the scatter's phase changes.
				dressing.grave(buf, palette, -6, 1, false)
				dressing.grave(buf, palette, 6, 1, false)
				dressing.gravewood(buf, palette, -8, 1, 6)
				dressing.gravewood(buf, palette, 8, 1, 5)
				-- THE BLIGHT BED THE TENDER WORKS, and why its kerb is
				-- broken at one cell. A raised bed is masonry round soil and
				-- the sockets contract's feature search stops at the first
				-- solid node on the socket's own course, so a tender standing
				-- outside a bed looks at brick and the growth two cells
				-- further in does not count. `dressing.plant` breaks the kerb
				-- and grows something in the gap, which is where the hands
				-- are.
				dressing.flower_bed(buf, palette, 2, -10, 5, -8)
				dressing.plant(buf, palette, 4, -8)
				dressing.counter(buf, palette, -9, -11, 4, "x")
				dressing.crates(buf, palette, 8, -11, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("mourn_west", "mourn", -6, 0, 0),
					plots.work("mourn_east", "mourn", 6, 0, 0),
					plots.work("bed", "tend", 4, -7, 2),
				}
			end},
		--
		-- 2. THE BONE YARD, where the city's spoil is stacked and worked: bone
		-- piles on gravel, drying racks, crates, and a gravewood stack at the
		-- head of it. Two at work -- one CARVING at the stack, one FORAGING
		-- over the piles -- and the district's second spare at the gate.
		--
		-- `forage` names "a mushroom, a bush, a plant, a vine or leaves"; this
		-- palette's `undergrowth` is `grug_nodes:bone_pile`, which is none of
		-- those, so the forager faces the IVY on the yard wall instead. The
		-- distinction matters: the KAT reads the contract's list and not the
		-- picture, and a rule that accepted a bone pile because a necropolis
		-- has bone piles in it would accept anything.
		{id = "market_bone_yard", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.blight_flora(buf, palette, -9, 2, 9, 10, 7, 2, 2)
				for x = -10, 10 do buf:put(x, 0, 0, palette.node("path")) end
				dressing.drying_rack(buf, palette, -7, 4, 5, "x")
				dressing.drying_rack(buf, palette, 3, 4, 5, "x")
				dressing.wood_pile(buf, palette, -6, -3, 4, "x")
				dressing.rubble_heap(buf, palette, 7, -4, 2)
				-- The yard wall the forager works over, and why it is
				-- obsidian brick rather than the palette's `low_wall`: ivy is
				-- a wallmounted `signlike` and `parts.wall_prop` refuses any
				-- support that is not an OPAQUE FULL CUBE, which
				-- `walls:mossycobble` is not -- it is a nodebox. A wall of the
				-- palette's own `foundation` carries it, and the ivy is the
				-- `forage` feature of section 8.2 ("a mushroom, a bush, a
				-- plant, a VINE or leaves"). The bone piles beside it are not:
				-- `grug_nodes:bone_pile` is none of the five, and a rule that
				-- accepted it because a necropolis has bone piles in it would
				-- accept anything.
				for x = 2, 8 do
					for y = 1, 2 do
						buf:put(x, y, -3, palette.node("foundation"))
					end
				end
				local vines = 0
				for _, x in ipairs({4, 5, 6}) do
					for y = 1, 2 do
						if dressing.ivy(buf, palette, x, y, -4, 0, 1) then
							vines = vines + 1
						end
					end
				end
				if vines < 3 then
					error("wp13 nhal veyr: the bone yard wall carries " ..
						vines .. " vines and the forager needs one", 0)
				end
				dressing.counter(buf, palette, -9, -11, 4, "x")
				dressing.crates(buf, palette, 8, -11, 0)
				dressing.bench(buf, palette, 2, -11, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("stack", "carve", -6, -4, 0),
					plots.work("wall", "forage", 5, -5, 0),
					plots.spare("bone_yard", 7, -9, 0),
				}
			end},
		--
		-- 3. THE CANDLE COURT, the one open place in the district where a
		-- light burns: the paved square of `undead_parts.candle_court` with
		-- its altar, and two PRAYING at it.
		{id = "market_candle_court", module = "undead", make = "candle_court",
			margin = 3, spec = {size = 11},
			-- The two who keep the light. They stand two nodes off the altar
			-- step on its own axis and look at it, so the first cell on their
			-- course carries a votive torch one course up -- which is the
			-- `pray` feature of section 8.1 ("an altar, a candle or a grave
			-- marker"). `ox`/`oz` is the part's origin on the plot, so
			-- `ox + 5, oz + 3` is the part's own cell (5, 3).
			extra_sockets = function(area)
				return {
					plots.work("vigil_south", "pray",
						area.ox + 5, area.oz + 3, 0),
					plots.work("vigil_north", "pray",
						area.ox + 5, area.oz + 7, 2),
				}
			end},
		--
		-- 4. THE CLOSE between two of the district's houses: the garden-sized
		-- fill lot. A gravewood, a bench under it, a blight bed and the
		-- district's last spare.
		{id = "market_close", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.gravewood(buf, palette, 0, 2, 5)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.flower_bed(buf, palette, 1, -3, 4, -1)
			end,
			extra_sockets = function()
				return {
					plots.work("close_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("close", 4, -5, 0),
				}
			end},
	}

	M.market = plots.district({
		key = "nhal_veyr_market",
		role = "market_professions",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
