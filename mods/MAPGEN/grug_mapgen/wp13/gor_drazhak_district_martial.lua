-- Gor Drazhak, the WAR YARD: the martial and garrison district, nine
-- terrain-relative plots and four fill lots.
--
-- The contract's second district role. The garrison is the one district that
-- publishes GUARD POSTS -- the sockets contract's "a guard stands here and
-- returns here after fights" -- and it publishes them where a guard would
-- actually be posted: the barracks door, the pit's gate and the tower's foot.
-- There are no vendors here; the professions are the bazaar's and the two
-- royal booths are the core's.
--
-- WHAT MAKES IT ORCISH. The ARENA is this district's centre and this
-- capital's: a sunken sand floor inside a stepped bank with a gate at each
-- end, and the `spar` activity of the sockets contract's wave-2 vocabulary
-- authored as it asks to be -- in PAIRS, each socket facing its partner,
-- which is the vocabulary's own first feature ("another `spar` socket or a
-- training dummy"). Round it: the drill yard's posts, the beast pen, the
-- weapon racks and the standards.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/gor_drazhak_plot.lua")(directory)

	local M = {}

	local WATCH = "gor_drazhak_war_watch"

	local PLOTS = {
		-- 1. THE BARRACKS. Its own generator publishes the guard post, the
		-- muster idle spot and waypoint 1 of the loop, so this row carries no
		-- `order` of its own.
		{id = "war_barracks", module = "capitals", make = "barracks",
			handle = "ors",
			spec = {w = 15, d = 19, wall_h = 6, patrol_group = WATCH,
				order = 1},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.standard(buf, palette, area.x0 + 2, area.z0 + 2, 5)
				dressing.standard(buf, palette, area.x1 - 2, area.z0 + 2, 5)
			end,
			extra_sockets = function(area)
				return {
					plots.guard_post("gate_west", area.x0 + 2, area.z0 + 3, 0),
					plots.guard_post("gate_east", area.x1 - 2, area.z0 + 3, 0),
				}
			end},

		-- 2. THE ARENA: the piece this district exists for. A sunken floor of
		-- beaten sand inside a stepped bank of ors stone, gates on the two
		-- short sides, standards at the corners, and four fighters in two
		-- pairs. A `spar` socket's feature is its partner, so they are
		-- authored two nodes apart looking at each other.
		{id = "war_arena", yard = {w = 13, d = 13}, order = 2,
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				local stone = palette.maybe("castle_wall") or
					palette.node("wall_accent")
				-- The bank: two courses stepped back one node, broken at the
				-- two gates, so the sand floor is a pit and not a paddock.
				for step = 0, 1 do
					local x0, z0 = -11 + step, -11 + step
					local x1, z1 = 11 - step, 11 - step
					for z = z0, z1 do
						for x = x0, x1 do
							if (x == x0 or x == x1 or z == z0 or z == z1) and
									not (math.abs(x) <= 1 and
										(z == z0 or z == z1)) then
								buf:put(x, step + 1, z, stone)
							end
						end
					end
				end
				-- The floor, and the blood sand of the middle of it.
				for z = -9, 9 do
					for x = -9, 9 do
						buf:put(x, 0, z, palette.node("ground_bare"))
					end
				end
				dressing.inlay(buf, palette, -4, -4, 4, 4, "plaza_edge")
				for _, mast in ipairs({{-10, -10}, {10, -10}, {-10, 10},
						{10, 10}}) do
					dressing.standard(buf, palette, mast[1], mast[2], 5)
				end
				dressing.drill_post(buf, palette, 0, 7, 3)
				dressing.bench(buf, palette, -3, -8, 0, 3, "x")
				dressing.bench(buf, palette, 1, 8, 2, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("arena_west_a", "spar", -3, -1, 1),
					plots.work("arena_west_b", "spar", -1, -1, 3),
					plots.work("arena_east_a", "spar", 1, 2, 1),
					plots.work("arena_east_b", "spar", 3, 2, 3),
					plots.idle("arena_dummy", 0, 5, 2, {"work"}),
					plots.idle("arena_bench", -2, -8, 0, {"bench"}, 2),
					plots.spare("arena", 8, -8, 0),
				}
			end},

		-- 3. THE ARMOURY. Turned a quarter so its door faces the lane: the
		-- `workshop` kit stands the forge's cauldrons on the odd cells of the
		-- z- gable's inner run and the chimney on that wall's middle cell, so
		-- the door opens in the x- wall.
		{id = "war_armoury", module = "buildings", make = "workshop",
			order = 3, turns = 3, margin = 3, handle = "ors",
			parapet = {y = 7},
			spec = {w = 11, d = 15, wing = 7, wall_h = 5, roof = "flat_deck",
				door_side = "x-", door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				buf:put(area.x0 + 3, 1, area.z1 - 3, palette.node("workbench"))
				buf:put(area.x0 + 5, 1, area.z1 - 3, palette.node("hearth"))
				dressing.fence_line(buf, palette, area.x1 - 3, area.z1 - 4,
					area.x1 - 3, area.z1 - 1)
				dressing.crates(buf, palette, area.x1 - 2, area.z0 + 3, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("armoury_anvil", "smith", area.x0 + 3,
						area.z1 - 2, 2),
					plots.idle("armoury_forge", area.x0 + 5,
						area.z1 - 2, 2, {"work"}),
				}
			end},

		-- 4. THE BEAST PEN: the wargs and the pack beasts. A stable with
		-- straw, rails and hay outside it.
		{id = "war_beast_pen", module = "capitals", make = "stable",
			order = 4, margin = 4,
			spec = {w = 15, d = 11, wall_h = 5},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, area.x0 + 1, area.z1 - 3,
					area.x1 - 1, area.z1 - 3)
				dressing.bale_stack(buf, palette, area.x0 + 3, area.z1 - 1, 3)
				dressing.bale_stack(buf, palette, area.x0 + 5, area.z1 - 1, 2)
				dressing.handcart(buf, palette, area.x1 - 4, area.z1 - 1, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("pen_tend", "tend", area.x0 + 2,
						area.z1 - 2, 0),
					plots.guard_post("pen", area.x1 - 2, area.z0 + 3, 0),
				}
			end},

		-- 5. THE DRILL YARD. The watchpost is what makes it a yard and not a
		-- field: a guard room with a fighting deck over it, with five nodes of
		-- open ground all round for the posts, the standards and the billets.
		{id = "war_drill_yard", module = "buildings", make = "watchpost",
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
				dressing.wood_pile(buf, palette, area.x1 - 4, area.z0 + 2,
					3, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.guard_post("yard_west", area.x0 + 3, area.oz, 3),
					plots.guard_post("yard_east", area.x1 - 3, area.oz, 1),
					plots.work("yard_spar_a", "spar", area.x0 + 3,
						area.z1 - 4, 1),
					plots.work("yard_spar_b", "spar", area.x0 + 5,
						area.z1 - 4, 3),
					plots.spare("drill_yard", area.x0 + 4, area.z1 - 6, 2),
				}
			end},

		-- 6. THE QUARTERMASTER'S STORE. Door index 6, single leaf: the `store`
		-- kit stands its roof posts on the odd cells of the gable's inner run,
		-- so a centred door on an eleven-wide longhouse opens onto a post.
		{id = "war_quartermaster", module = "buildings", make = "longhouse",
			order = 6, handle = "ors",
			spec = {w = 13, d = 15, wall_h = 5, door_side = "z-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.counter(buf, palette, area.x1 - 4, area.z1 - 2, 3,
					"x")
				dressing.crates(buf, palette, area.x0 + 2, area.z1 - 2, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("quarter_counter", "stall", area.x1 - 3,
						area.z1 - 1, 2),
				}
			end},

		-- 7. THE WAIN SHED: open on two sides, the war carts and the barrels
		-- under it and the rest of the load on the apron.
		{id = "war_wain_shed", module = "buildings", make = "shed",
			order = 7, margin = 4,
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.wagon(buf, palette, area.x0 + 3, area.z1 - 3, "x")
				dressing.crates(buf, palette, area.x1 - 3, area.z1 - 3, 2)
				dressing.wood_pile(buf, palette, area.x0 + 2, area.z0 + 2,
					3, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.idle("wain_saw", area.x0 + 2,
						area.z0 + 3, 0, {"work"}),
				}
			end},

		-- 8. THE WAR CHIEF'S HOUSE.
		{id = "war_chief_house", module = "buildings", make = "cottage",
			order = 8,
			parapet = {y = 6},
			spec = {w = 11, d = 9, wall_h = 4, roof = "flat_deck",
				infill = true, fancy_bed = true},
			extra_sockets = function(area)
				return {
					plots.idle("chief_step", area.x1 - 3, area.z1 - 2, 2,
						{"door"}),
				}
			end},

		-- 9. THE WATCH TOWER at the district's far corner, turned a quarter so
		-- its door faces the lane rather than repeating the drill yard's post,
		-- and the district's second spare.
		{id = "war_watch_tower", module = "buildings", make = "watchpost",
			order = 9, turns = 1, spec = {},
			extra_sockets = function(area)
				return {
					plots.guard_post("tower_foot", area.ox - 1,
						area.z0 + 3, 0),
					plots.spare("watch_tower", area.x1 - 2, area.z1 - 2, 2),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL. A garrison quarter is not fields and gardens,
	-- so its fill is the ground an army keeps.
	local FILL = {
		-- 1. THE MUSTER FIELD: open trodden ground inside a rail, drill posts
		-- across the middle, standards at the head of it and hay at the far
		-- end. `sweep` is the one activity that moves, and somebody rakes a
		-- drill yard.
		{id = "war_muster_field", yard = {},
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
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("muster_rake", "sweep", 0, -9, 0),
					plots.idle("muster_saw", -8, -9, 0, {"work"}),
					plots.idle("muster_spar_a", -3, 4, 1, {"work"}),
					plots.idle("muster_spar_b", -1, 4, 3, {"work"}),
				}
			end},

		-- 2. THE REMOUNT PADDOCK: fenced dry ground, hay, a handcart and the
		-- two who keep it.
		{id = "war_remount_paddock", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -11, -8, -11, 11)
				dressing.fence_line(buf, palette, 11, -8, 11, 11)
				dressing.fence_line(buf, palette, -11, 11, 11, 11)
				dressing.undergrowth(buf, palette, -10, -5, 10, 10, 4)
				dressing.bale_stack(buf, palette, -4, 6, 3)
				dressing.bale_stack(buf, palette, -2, 6, 2)
				dressing.handcart(buf, palette, 3, -8, "x")
				dressing.planter(buf, palette, 5, -8, 8, -6)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("paddock_tend", "tend", 6, -9, 0),
					plots.idle("paddock_forage", -6, -4, 2, {"work"}),
					plots.spare("paddock", 10, -11, 0),
				}
			end},

		-- 3. THE WOOD YARD: stacked timber, two chopping blocks and the two
		-- who cut it.
		{id = "war_wood_yard", yard = {},
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
					plots.idle("saw_east", 4, -6, 0, {"work"}),
				}
			end},

		-- 4. THE GUARD FIRE inside the lot grid: a cauldron, a bench, the
		-- stores and the district's third spare.
		{id = "war_guard_fire", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				buf:put(0, 1, 1, palette.node("hearth"))
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.crates(buf, palette, 3, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("guard_fire_brew", "brew", 0, 0, 0),
					plots.idle("guard_fire_seat", -4, -3, 0,
						{"bench"}, 2),
					plots.spare("guard_fire", 4, -5, 0),
				}
			end},
	}

	M.martial = plots.district({
		key = "gor_drazhak_war",
		role = "martial_garrison",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
