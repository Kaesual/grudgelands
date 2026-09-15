-- Dur Brannoc, the martial and garrison district: nine terrain-relative plots
-- and four dressings.
--
-- The contract's second district role. What a plot is and how it is built is
-- `dur_brannoc_plot.lua`; where the nine plots stand is
-- `dur_brannoc_quadrants.lua`. This file is the roster and nothing else.
--
-- The garrison is the one district that publishes GUARD POSTS -- the sockets
-- contract's "a guard stands here and returns here after fights" -- and it
-- publishes them at the plots a guard would actually be posted to: the barracks
-- door, the drill yard's gate and the watch tower's foot. NONE OF THEM IS ON A
-- WALL: the user's ruling of 2026-09-15 is that "guards on the walls are not
-- necessary", and the curtain is an overlay that cannot publish a socket in any
-- case (docs/research/wp13-dur-brannoc.md section 8.1).
--
-- The `spar` activity of the sockets contract's wave-2 table lives here, and it
-- is the one activity whose feature is ANOTHER SOCKET: "another `spar` socket
-- or a training dummy". Both halves are built -- the drill posts are the
-- dummies and the pairs face each other -- because a rule satisfied two ways is
-- a rule the KAT can check two ways.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/dur_brannoc_plot.lua")(directory)

	local M = {}

	local WATCH = "dur_brannoc_garrison_watch"

	-- The shopfront of every profession house of this capital, spelled the same
	-- way in all four rosters: a four-node trestle counter on the front row of
	-- the plot's own ring, clear of the two corner lamps and of the doorstep
	-- path down the middle, with the trader OUTSIDE it on the outermost row
	-- looking at it.
	local function shop_counter(buf, palette, area)
		area.dressing.counter(buf, palette, area.x1 - 5, area.z0 + 1, 4, "x")
	end
	local function shop_vendor(id, kind, area)
		return plots.vendor(id, kind, area.x1 - 4, area.z0, 0)
	end

	local PLOTS = {
		-- 1. The barracks: the generator publishes its guard post, its muster
		-- idle spot and waypoint 1 of the loop, so this row carries no `order`.
		{id = "garrison_barracks", module = "capitals", make = "barracks",
			roof = "slate",
			spec = {w = 17, d = 21, wall_h = 6, patrol_group = WATCH,
				order = 1},
			extra_sockets = function(area)
				return {
					plots.guard_post("gate_west", area.x0 + 2, area.z0 + 3, 0),
					plots.guard_post("gate_east", area.x1 - 2, area.z0 + 3, 0),
				}
			end},
		-- 2. The muster hall, where the watch is read its orders: a hall under
		-- slate, so it reads as civic from the lane and not as the biggest
		-- longhouse in the quarter.
		{id = "garrison_muster_hall", module = "buildings", make = "hall",
			roof = "slate", order = 2,
			spec = {w = 15, d = 17, wall_h = 5, infill = true}},
		-- 3. The armoury. A workshop, turned, opening in its x- wall for the
		-- reason the smithy is: the `workshop` kit stands its cauldrons on the
		-- odd cells of the z- gable's inner run and the chimney on that wall's
		-- middle cell, so a door there would open onto a hearth.
		{id = "garrison_armoury", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 15, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("workbench"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("armoury_anvil", "smith", area.x0 + 3,
						area.z0, 0),
					shop_vendor("armourer", "armourer", area),
				}
			end},
		-- 4. The drill yard. The watchpost is what makes it a yard and not a
		-- field: a guard room with a fighting deck over it, five nodes of open
		-- ground all round for the posts and the standards, and the pair who
		-- spar there.
		{id = "garrison_drill_yard", module = "buildings", make = "watchpost",
			order = 4, margin = 5, spec = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, spot in ipairs({{area.x0 + 2, area.z1 - 2},
						{area.x0 + 5, area.z1 - 2}, {area.x1 - 5, area.z1 - 2},
						{area.x1 - 2, area.z1 - 2}}) do
					dressing.drill_post(buf, palette, spot[1], spot[2], 3)
				end
				dressing.standard(buf, palette, area.x0 + 2, area.z0 + 4, 5)
				dressing.standard(buf, palette, area.x1 - 2, area.z0 + 4, 5)
			end,
			extra_sockets = function(area)
				return {
					plots.guard_post("yard_west", area.x0 + 3, area.oz, 3),
					plots.guard_post("yard_east", area.x1 - 3, area.oz, 1),
					plots.work("yard_spar_west", "spar", area.x0 + 2,
						area.z1 - 3, 0),
					plots.work("yard_spar_east", "spar", area.x1 - 2,
						area.z1 - 3, 0),
					plots.spare("drill_yard", area.x0 + 4, area.z1 - 5, 2),
				}
			end},
		-- 5. The garrison's own stable.
		{id = "garrison_stable", module = "capitals", make = "stable",
			order = 5, spec = {w = 15, d = 13, wall_h = 5},
			decorate = function(buf, palette, area)
				area.dressing.plant(buf, palette, area.x0 + 3, area.z0 + 1)
				area.dressing.plant(buf, palette, area.x0 + 4, area.z0 + 1)
			end,
			extra_sockets = function(area)
				return {
					plots.work("stable_tend", "tend", area.x0 + 3, area.z0, 0),
				}
			end},
		-- 6. The quartermaster's store. Door index 6, for the roof-post reason
		-- the forge district's store records.
		{id = "garrison_quartermaster", module = "buildings", make = "longhouse",
			order = 6,
			spec = {w = 13, d = 15, wall_h = 5, door_side = "z-",
				door_index = 6, infill = true}},
		-- 7. The wain shed: open on two sides, four nodes of yard rather than
		-- two, because a wagon, a stack of barrels and a pile of billets need
		-- ground that is not under the shed's own eaves.
		{id = "garrison_wain_shed", module = "buildings", make = "shed",
			order = 7, margin = 4, spec = {w = 13, d = 9, wall_h = 4},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.wagon(buf, palette, area.x0 + 3, area.z1 - 3, "x")
				dressing.crates(buf, palette, area.x1 - 3, area.z1 - 3, 2)
				buf:put(area.x0 + 2, 1, area.z0 + 1, palette.node("tree_log"))
			end,
			extra_sockets = function(area)
				return {
					plots.work("shed_saw", "chop", area.x0 + 2, area.z0, 0),
				}
			end},
		-- 8. The serjeant's house.
		{id = "garrison_serjeant", module = "buildings", make = "cottage",
			order = 8,
			spec = {w = 11, d = 7, wall_h = 4, roof = "hip", infill = true}},
		-- 9. The watch tower at the quarter's far corner, turned a quarter so
		-- its door faces the lane rather than repeating the drill yard's post,
		-- and the district's second spare.
		{id = "garrison_watch_tower", module = "buildings", make = "watchpost",
			order = 9, turns = 1, spec = {},
			extra_sockets = function(area)
				return {
					plots.guard_post("tower_foot", area.ox - 1, area.z0 + 3, 0),
					plots.spare("watch_tower", area.x1 - 2, area.z1 - 2, 2),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL. A garrison quarter is not fields and gardens:
	-- its open ground is the ground an army keeps -- the muster field it drills
	-- on, the pen its pack goats stand in, the wood yard that feeds its fires,
	-- and one green.
	local FILL = {
		-- 1. THE MUSTER FIELD: trodden ground inside a rail, drill posts across
		-- the middle, standards at the head of it, and two pairs who spar. Each
		-- pair faces the other's socket, which is the first half of the `spar`
		-- feature rule; the drill posts beside them are the second.
		{id = "garrison_muster_field", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for x = -8, 8, 4 do
					dressing.drill_post(buf, palette, x, 0, 3)
				end
				dressing.standard(buf, palette, -7, -6, 5)
				dressing.standard(buf, palette, 7, -6, 5)
				dressing.fence_line(buf, palette, -11, 11, 11, 11)
				dressing.wood_pile(buf, palette, -9, -8, 3, "x")
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("muster_spar_south", "spar", 0, -2, 0),
					plots.work("muster_spar_north", "spar", 0, 2, 2),
					plots.work("muster_rake", "sweep", -8, -9, 0),
				}
			end},
		-- 2. THE PACK PEN: the goats the garrison marches with, the trough they
		-- drink at and the two who keep them.
		{id = "garrison_pack_pen", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				area.dwarf.goat_pen(buf, palette, -10, -2, 10, 10)
				dressing.plant(buf, palette, -8, 4)
				dressing.handcart(buf, palette, 3, -8, "x")
				dressing.wood_pile(buf, palette, -9, -8, 3, "x")
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("pen_trough", "tend", -8, 3, 0),
					plots.work("pen_saw", "chop", -8, -9, 0),
					plots.spare("pack_pen", 9, -9, 0),
				}
			end},
		-- 3. THE WOOD YARD: stacked timber, two chopping blocks and the two who
		-- cut it.
		{id = "garrison_wood_yard", yard = {},
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
		-- 4. THE GUARD GREEN: a pine, a bench, the stores and the district's
		-- third spare.
		{id = "garrison_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.tree(buf, palette, 0, 2, 5)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.crates(buf, palette, 3, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("green_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("garrison_green", 4, -5, 0),
				}
			end},
	}

	M.martial = plots.district({
		key = "dur_brannoc_garrison",
		role = "martial_garrison",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
