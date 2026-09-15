-- Highcourt, the residential and cultural district: nine terrain-relative
-- plots.
--
-- The contract's fourth district role: "houses, half-timbered lanes,
-- orchards, well, tavern, small square". What a plot is and how it is built
-- is `highcourt_plot.lua`; where the nine plots stand is
-- `highcourt_quadrants.lua`. This file is the roster and nothing else.
--
-- THE THREE HOUSES ARE DELIBERATELY THREE DIFFERENT HOUSES. Footprint, roof
-- form and door side are what give a lane of cottages three silhouettes
-- instead of one repeated, which is the same rule Hearthpine's four houses
-- follow; all three are half timbered, because the loam infill of the human
-- palette is what the contract's "half-timbered lanes" is made of.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/highcourt_plot.lua")(directory)

	local M = {}

	local WATCH = "highcourt_lanes_watch"

	local PLOTS = {
		-- 1. The tavern, on the lot nearest the core: the district's one big
		-- room, plank roofed like everything a citizen built, with the
		-- trestles and the wood pile on its apron.
		{id = "homes_tavern", module = "buildings", make = "hall",
			order = 1, margin = 3,
			spec = {w = 13, d = 15, wall_h = 5, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.bench(buf, palette, area.x0 + 2, area.z1 - 2, 2, 3, "x")
				dressing.bench(buf, palette, area.x1 - 4, area.z1 - 2, 2, 3, "x")
				dressing.wood_pile(buf, palette, area.x1 - 3, area.z0 + 2, 3, "z")
			end},
		-- 2. The neighbourhood well: the well court as a paved court, not as
		-- a garden -- three nodes of verge, benches, planters, and the draw
		-- well the lanes come to.
		{id = "homes_well", module = "capitals", make = "well_court",
			order = 2, margin = 3, spec = {size = 11},
			extra_sockets = function(area)
				return {plots.spare("well", area.x0 + 2, area.z1 - 2, 2)}
			end},
		-- 3. The small square: a stepped plinth with a standing figure on it
		-- in the crown's white stone, a lamp at each corner of the base. A
		-- square with nothing in the middle reads as a car park (which is the
		-- defect the core's waypoint plaza record names), so this one has a
		-- monument to stand round.
		{id = "homes_monument", module = "capitals", make = "statue_plinth",
			handle = "white", order = 3, margin = 4, spec = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				-- A SQUARE IS PAVED. The first render of this plot was a
				-- monument standing on a lawn with a kerb round it, because
				-- the plinth is nine nodes across and its margin is the
				-- plot's own grass. Everything inside the kerb that the
				-- plinth does not already pave is laid in the same citadel
				-- paving the core's plazas are, so the four lanes arrive at
				-- a floor and not at a verge.
				local plaza = palette.maybe("castle_paving") or
					palette.node("plaza")
				for z = area.z0 + 1, area.z1 - 1 do
					for x = area.x0 + 1, area.x1 - 1 do
						local inside = x >= area.ox and
							x <= area.ox + area.pw - 1 and z >= area.oz and
							z <= area.oz + area.pd - 1
						if not inside then buf:put(x, 0, z, plaza) end
					end
				end
				dressing.bench(buf, palette, area.x0 + 2, area.z1 - 2, 2, 3, "x")
				dressing.planter(buf, palette, area.x1 - 3, area.z1 - 3,
					area.x1 - 2, area.z1 - 2)
			end,
			extra_sockets = function(area)
				return {plots.spare("square", area.x1 - 2, area.z0 + 3, 0)}
			end},
		-- 4-6. The three houses of the lane: a gabled cottage, a hip-roofed
		-- one twice as wide, and one that opens on its side street.
		{id = "homes_house_gable", module = "buildings", make = "cottage",
			order = 4, spec = {w = 9, d = 7, wall_h = 4, infill = true}},
		{id = "homes_house_hip", module = "buildings", make = "cottage",
			order = 5,
			spec = {w = 11, d = 9, wall_h = 4, roof = "hip", infill = true}},
		{id = "homes_house_lane", module = "buildings", make = "cottage",
			order = 6, turns = 3,
			spec = {w = 9, d = 9, wall_h = 4, infill = true}},
		-- 7. The tenement: one long saltbox roof over the row. Door index 4,
		-- single leaf, for the `store` kit's post rhythm.
		{id = "homes_tenement", module = "buildings", make = "longhouse",
			order = 7,
			spec = {w = 11, d = 17, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true}},
		-- 8. The bakehouse. A workshop, turned, opening in its x- wall for
		-- the same reason the market's workshop and the armoury do.
		--
		-- THE BAKEHOUSE IS THE BAKER'S (playtest round 3). It gets the same
		-- shopfront the market district's three professions carry: a trestle
		-- counter on the street row of its own ring, the baker's vendor socket
		-- at one end of it and a WORK socket at the other.
		--
		-- THE ACTIVITY IS `stall`, AND THE CONTRACT ASKED FOR THE CHOICE TO BE
		-- WRITTEN DOWN (section 8.1: "baker at the furnace as `stall` or
		-- `smith`, choose and document"). `stall` is chosen because the other
		-- option names a feature this palette does not have: the human palette
		-- binds no furnace -- its `hearth` is `grug_decor:xdecor_cauldron` and
		-- its `workbench` is an anvil -- so a `smith` socket at a bakehouse
		-- would have to face a blacksmith's anvil to satisfy its own feature
		-- rule. The baker therefore stands at the counter he has, and the
		-- hammering loop stays with the smith, who has an anvil.
		{id = "homes_bakehouse", module = "buildings", make = "workshop",
			order = 8, turns = 3,
			spec = {w = 11, d = 11, wing = 5, wall_h = 4, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				area.dressing.counter(buf, palette, area.x1 - 5,
					area.z0 + 1, 4, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.vendor("baker", "baker", area.x1 - 4, area.z0, 0),
					plots.work("oven", "stall", area.x1 - 2, area.z0, 0),
				}
			end},
		-- 9. The orchard on the district's outer edge, which is what
		-- Highcourt has instead of a wall. Its generator publishes two
		-- waypoints (9 and 10), so this row carries no `order`.
		{id = "homes_orchard", module = "capitals", make = "orchard_edge",
			spec = {len = 21, d = 13, patrol_group = WATCH, order = 9}},
	}

	-- THE DISTRICT'S OWN FILL (playtest round 3): four dressings on the
	-- quadrant's four fill lots, reaches 11, 11, 8 and 5, on the
	-- forecourt/feature rule the market district's roster writes down. This is
	-- the district the user's "loose, with fields and gardens" is most
	-- literally about: the common field the lane feeds itself from, the green
	-- its geese stand on, the park it walks in, and the kitchen garden between
	-- two of its cottages.
	local FILL = {
		-- 1. THE COMMON FIELD: the ploughed ground of the residential quarter,
		-- three at work in the furrows, the cart and the hay at the gate.
		{id = "homes_common_field", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.crop_rows(buf, palette, -9, -8, 9, 9, "z")
				dressing.fence_line(buf, palette, -11, 11, 11, 11)
				dressing.bale_stack(buf, palette, -9, -10, 3)
				dressing.handcart(buf, palette, 7, -10, "x")
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("furrow_west", "farm", -6, -9, 0),
					plots.work("furrow_mid", "farm", 0, -9, 0),
					plots.work("furrow_east", "farm", 6, -9, 0),
				}
			end},
		-- 2. THE GOOSE GREEN: kept grass inside a rail with a hedge on the
		-- field side, two standards, a wood pile and beds at the gate, and the
		-- two who keep it.
		{id = "homes_goose_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -11, -8, -11, 11)
				dressing.fence_line(buf, palette, 11, -8, 11, 11)
				dressing.hedge_line(buf, palette, -11, 11, 11, 11, 2)
				dressing.undergrowth(buf, palette, -10, -5, 10, 10, 4)
				dressing.broadleaf(buf, palette, -6, 4, 5)
				dressing.broadleaf(buf, palette, 6, 4, 5)
				dressing.wood_pile(buf, palette, -9, -8, 3, "x")
				dressing.flower_bed(buf, palette, 5, -9, 8, -7)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("green_saw", "chop", -8, -9, 0),
					plots.work("green_beds", "tend", 6, -10, 0),
					plots.spare("goose", 10, -11, 0),
				}
			end},
		-- 3. THE LANE PARK: a crossing of paths, benches under two standards,
		-- beds at the gate, and the two who sit and sweep in it.
		{id = "homes_lane_park", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for x = -7, 7 do buf:put(x, 0, 0, palette.node("path")) end
				for z = -5, 7 do buf:put(0, 0, z, palette.node("path")) end
				dressing.broadleaf(buf, palette, -5, 4, 5)
				dressing.broadleaf(buf, palette, 5, 4, 5)
				dressing.bench(buf, palette, -4, -3, 0, 3, "x")
				dressing.bench(buf, palette, 2, -3, 0, 3, "x")
				dressing.flower_bed(buf, palette, -8, -6, -6, -4)
				dressing.flower_bed(buf, palette, 6, -6, 8, -4)
			end,
			extra_sockets = function()
				return {
					plots.work("park_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.work("park_sweep", "sweep", 0, -6, 0),
				}
			end},
		-- 4. THE KITCHEN GARDEN between two cottages: two raised beds, a bench
		-- and the district's second spare.
		{id = "homes_kitchen_garden", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.planter(buf, palette, -4, -1, -2, 2)
				dressing.planter(buf, palette, 2, -1, 4, 2)
				dressing.bench(buf, palette, -3, -3, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("beds", "tend", 0, 0, 3),
					plots.spare("kitchen", 4, -5, 0),
				}
			end},
	}

	M.homes = plots.district({
		key = "highcourt_homes",
		role = "residential_cultural",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
