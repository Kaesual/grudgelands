-- Highcourt, the martial and garrison district: nine terrain-relative plots.
--
-- The contract's second district role. What a plot is and how it is built is
-- `highcourt_plot.lua`; where the nine plots stand is
-- `highcourt_quadrants.lua`. This file is the roster and nothing else.
--
-- The garrison is the one district that publishes GUARD POSTS -- the sockets
-- contract's "a guard stands here and returns here after fights" -- and it
-- publishes them at the three plots a guard would actually be posted to: the
-- barracks door, the drill yard's gate and the watch tower's foot. Vendors
-- belong to the market and to the core's service court and there are none
-- here, which is the contract's own rule about the two `grug_traders`
-- families: six vendor sockets would have the runtime place six traders.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/highcourt_plot.lua")(directory)

	local M = {}

	local WATCH = "highcourt_garrison_watch"

	local PLOTS = {
		-- 1. The barracks: the district's own generator publishes its guard
		-- post, its muster idle spot and waypoint 1 of the loop, so this row
		-- carries no `order` of its own.
		{id = "martial_barracks", module = "capitals", make = "barracks",
			roof = "slate",
			spec = {w = 17, d = 21, wall_h = 6, patrol_group = WATCH,
				order = 1},
			extra_sockets = function(area)
				return {
					plots.guard_post("gate_west", area.x0 + 2, area.z0 + 3, 0),
					plots.guard_post("gate_east", area.x1 - 2, area.z0 + 3, 0),
				}
			end},
		-- 2. The muster hall: where the watch is read its orders. A hall, hip
		-- roofed under slate, so it reads as civic from the avenue rather
		-- than as the biggest cottage in the district.
		{id = "martial_muster_hall", module = "buildings", make = "hall",
			roof = "slate", order = 2,
			spec = {w = 15, d = 17, wall_h = 5, infill = true}},
		-- 3. The armoury. A workshop, turned, opening in its x- wall like
		-- Dawnmere's smithy and like the market's own workshop: the
		-- `workshop` kit stands the forge's cauldrons on the odd cells of the
		-- z- gable's inner run and the generator's default chimney stack on
		-- that wall's middle cell, so a door there opens onto a hearth.
		{id = "martial_armoury", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 15, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true}},
		-- 4. The stables: the garrison's own, beside the wain shed.
		{id = "martial_stables", module = "capitals", make = "stable",
			order = 4, spec = {w = 15, d = 13, wall_h = 5}},
		-- 5. The drill yard. The watchpost is the piece that makes it a yard
		-- and not a field: a guard room with a fighting deck over it, with
		-- five nodes of open ground all round for the posts, the standards
		-- and the armourer's stack of billets.
		{id = "martial_drill_yard", module = "buildings", make = "watchpost",
			order = 5, margin = 5, spec = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, spot in ipairs({{area.x0 + 2, area.z1 - 2},
						{area.x0 + 5, area.z1 - 2}, {area.x1 - 5, area.z1 - 2},
						{area.x1 - 2, area.z1 - 2}}) do
					dressing.drill_post(buf, palette, spot[1], spot[2], 3)
				end
				dressing.standard(buf, palette, area.x0 + 2, area.z0 + 4, 5)
				dressing.standard(buf, palette, area.x1 - 2, area.z0 + 4, 5)
				dressing.wood_pile(buf, palette, area.x1 - 4, area.z0 + 2, 3, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.guard_post("yard_west", area.x0 + 3, area.oz, 3),
					plots.guard_post("yard_east", area.x1 - 3, area.oz, 1),
					plots.spare("yard", area.x0 + 4, area.z1 - 4, 2),
				}
			end},
		-- 6. The quartermaster's store. Door index 4, single leaf: the
		-- `store` kit stands its roof posts on the odd cells of the gable's
		-- inner run, so an eleven-wide longhouse's centred door opens onto a
		-- post.
		{id = "martial_quartermaster", module = "buildings", make = "longhouse",
			order = 6,
			spec = {w = 13, d = 15, wall_h = 5, door_side = "z-",
				door_index = 6, infill = true}},
		-- 7. The wain shed: open on two sides, the carts and the barrels
		-- under it and the rest of the load on the apron.
		{id = "martial_wain_shed", module = "buildings", make = "shed",
			-- Four nodes of yard rather than two: a wagon, a stack of
			-- barrels and a pile of billets need ground that is not under
			-- the shed's own eaves.
			order = 7, margin = 4, spec = {w = 13, d = 9, wall_h = 4},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.wagon(buf, palette, area.x0 + 3, area.z1 - 3, "x")
				dressing.crates(buf, palette, area.x1 - 3, area.z1 - 3, 2)
				dressing.wood_pile(buf, palette, area.x0 + 2, area.z0 + 2, 3, "x")
			end},
		-- 8. The serjeant's house.
		{id = "martial_guard_house", module = "buildings", make = "cottage",
			order = 8,
			spec = {w = 11, d = 7, wall_h = 4, roof = "hip", infill = true}},
		-- 9. The watch tower at the district's far corner, turned a quarter
		-- so its door faces the lane rather than repeating the drill yard's
		-- post, and the second of the district's two spare wander spots.
		{id = "martial_watch_tower", module = "buildings", make = "watchpost",
			order = 9, turns = 1, spec = {},
			extra_sockets = function(area)
				return {
					plots.guard_post("tower_foot", area.ox - 1, area.z0 + 3, 0),
					plots.spare("tower", area.x1 - 2, area.z1 - 2, 2),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL (playtest round 3): four dressings on the
	-- quadrant's four fill lots, reaches 11, 11, 8 and 5, laid out on the
	-- forecourt/feature rule the market district's roster writes down. A
	-- garrison quarter is not fields and gardens, so its fill is the ground an
	-- army keeps: the muster field it drills on, the pasture its remounts
	-- stand in, the wood yard that feeds its fires, and one green.
	local FILL = {
		-- 1. THE MUSTER FIELD: open trodden ground inside a rail, drill posts
		-- across the middle, standards at the head of it and hay at the far
		-- end. The sweeper is the one activity that moves (contract section
		-- 8.2) and this is where it belongs: somebody rakes a drill yard.
		{id = "martial_muster_field", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for x = -8, 8, 4 do
					dressing.drill_post(buf, palette, x, 0, 3)
				end
				dressing.standard(buf, palette, -7, -6, 5)
				dressing.standard(buf, palette, 7, -6, 5)
				dressing.fence_line(buf, palette, -11, 11, 11, 11)
				dressing.wood_pile(buf, palette, -9, -8, 3, "x")
				dressing.bale_stack(buf, palette, 9, 6, 2)
				dressing.bale_stack(buf, palette, 7, 6, 2)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("muster_rake", "sweep", 0, -9, 0),
					plots.work("muster_saw", "chop", -8, -9, 0),
				}
			end},
		-- 2. THE REMOUNT PASTURE: fenced grass with a hedge on the field side,
		-- hay, a handcart and the two who keep it.
		{id = "martial_remount_pasture", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -11, -8, -11, 11)
				dressing.fence_line(buf, palette, 11, -8, 11, 11)
				dressing.hedge_line(buf, palette, -11, 11, 11, 11, 2)
				dressing.undergrowth(buf, palette, -10, -5, 10, 10, 4)
				dressing.bale_stack(buf, palette, -4, 6, 3)
				dressing.bale_stack(buf, palette, -2, 6, 2)
				dressing.handcart(buf, palette, 3, -8, "x")
				dressing.wood_pile(buf, palette, -9, -8, 3, "x")
				dressing.flower_bed(buf, palette, 5, -8, 8, -6)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("pasture_saw", "chop", -8, -9, 0),
					plots.work("pasture_tend", "tend", 6, -9, 0),
					plots.spare("pasture", 10, -11, 0),
				}
			end},
		-- 3. THE WOOD YARD: stacked timber, two chopping blocks and the two
		-- who cut it.
		{id = "martial_wood_yard", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.wood_pile(buf, palette, -6, 0, 5, "x")
				dressing.wood_pile(buf, palette, -6, 3, 5, "x")
				buf:put(-4, 1, -5, palette.node("tree_log"))
				buf:put(4, 1, -5, palette.node("tree_log"))
				dressing.crates(buf, palette, 6, -7, 0)
				dressing.bench(buf, palette, -3, -7, 0, 2, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("saw_west", "chop", -4, -6, 0),
					plots.work("saw_east", "chop", 4, -6, 0),
				}
			end},
		-- 4. THE GUARD GREEN inside the lot grid: a tree, a bench, the stores
		-- and the district's second spare.
		{id = "martial_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.broadleaf(buf, palette, 0, 2, 5)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.crates(buf, palette, 3, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("green_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("green", 4, -5, 0),
				}
			end},
	}

	M.martial = plots.district({
		key = "highcourt_martial",
		role = "martial_garrison",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
