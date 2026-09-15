-- Gor Drazhak, the WARRENS: the residential and cultural district, nine
-- terrain-relative plots and four fill lots.
--
-- The contract's fourth district role. Where the other three quarters are the
-- city working, this one is the city living in it: long houses for the clans,
-- round lodges for the chiefs of them, a cook court, a story fire, and the
-- open ground between.
--
-- WHAT MAKES IT ORCISH. Every dwelling here is FLAT DECKED BEHIND A
-- BREASTWORK, which is the contract's own first word about this race's
-- architecture and the thing that separates its skyline from the other five
-- capitals' at a hundred nodes: Highcourt is all ridges, Dur Brannoc all
-- slate, and this is a terrace of fighting tops. The ROUND LODGE is the one
-- piece of architecture this roster builds that is not in the shared library --
-- two overlapping rectangles, which is as round as an axis-aligned voxel house
-- gets, and the same shape Sunscar Camp's chief's lodge has, so the start and
-- the capital of this race read as one people.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/gor_drazhak_plot.lua")(directory)
	local buildings = dofile(directory .. "/buildings.lua")(directory)

	local M = {}

	local WATCH = "gor_drazhak_warren_watch"

	-- THE ROUND LODGE. `buildings.build` takes rectangles, and the union of a
	-- tall narrow one with a short wide one is an octagon: the four corner
	-- cells of the square are never built, and every wall cell that falls
	-- strictly inside the other rectangle is opened, so the two blocks are one
	-- room. It is registered into the roster's own generator table rather than
	-- into `buildings.lua`, which is not this lane's file.
	local function round_lodge(palette, spec)
		local w, d = spec.w or 11, spec.d or 11
		local wall_h = spec.wall_h or 5
		return buildings.build(palette, {
			id = spec.id, overhang = 1, infill = true,
			blocks = {
				{x0 = 1, z0 = 0, x1 = w - 2, z1 = d - 1, wall_h = wall_h,
					roof = "flat_deck", kit = "home",
					kit_spec = {hearth_x = w - 3, hearth_z = 1,
						hearth_face = 3}},
				{x0 = 0, z0 = 1, x1 = w - 1, z1 = d - 2, wall_h = wall_h,
					roof = "flat_deck"},
			},
			chimneys = {{x = w - 2, z = 1}},
			doors = {{side = "z-", index = math.floor(w / 2)}},
			inside = {x = 3, y = 1, z = d - 3},
		})
	end

	local PLOTS = {
		-- 1. THE CLAN LONGHOUSE, the biggest dwelling of the quarter. Door
		-- index 6, single leaf: the `store` kit stands its roof posts on the
		-- odd cells of the gable's inner run, so a centred door on an
		-- eleven-wide longhouse would open onto a post.
		{id = "warren_clan_house", module = "buildings", make = "longhouse",
			order = 1, handle = "ors",
			spec = {w = 13, d = 17, wall_h = 5, door_side = "z-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.standard(buf, palette, area.x0 + 2, area.z0 + 2, 5)
				dressing.bench(buf, palette, area.x1 - 5, area.z1 - 2, 2, 3,
					"x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("clan_seat", "sit", area.x1 - 4, area.z1 - 2, 0,
						{"bench"}, 2),
					plots.idle("clan_step", area.x0 + 3, area.z1 - 2, 2,
						{"door"}),
				}
			end},

		-- 2. THE CHIEF'S ROUND LODGE.
		-- NINE BY NINE and not eleven, which the first version of this roster
		-- tried: the `home` kit hangs its indoor light on the wall beside the
		-- hearth, and at eleven the octagon's chamfer cuts that wall away, so
		-- the kit refuses to build ("indoor light found no solid wall"). Nine
		-- is the plan Sunscar Camp's chief's lodge already proves. What makes
		-- this one the chief's is its height and its stone: six courses of ors
		-- block where the clan lodges are four of adobe.
		{id = "warren_round_lodge", module = "homes", make = "round_lodge",
			order = 2, handle = "ors",
			parapet = {y = 8, grow = 0},
			spec = {w = 9, d = 9, wall_h = 6},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.standard(buf, palette, area.x0 + 2, area.z1 - 2, 4)
				dressing.standard(buf, palette, area.x1 - 2, area.z1 - 2, 4)
			end,
			extra_sockets = function(area)
				return {
					plots.idle("lodge_step", area.x0 + 4, area.z1 - 2, 2,
						{"door"}),
					plots.spare("round_lodge", area.x1 - 1, area.z1 - 4, 3),
				}
			end},

		-- 3. THE COOK COURT: the communal ovens, which is what a settlement
		-- that eats together has instead of a kitchen per house.
		{id = "warren_cook_court", yard = {w = 11, d = 11}, order = 3,
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.inlay(buf, palette, -8, -8, 8, 8, "plaza_edge")
				for z = -7, 7 do
					for x = -7, 7 do
						buf:put(x, 0, z, palette.node("plaza"))
					end
				end
				for _, oven in ipairs({{-5, 3}, {-2, 3}, {1, 3}, {4, 3}}) do
					buf:put(oven[1], 1, oven[2], palette.node("hearth"))
					buf:put(oven[1], 2, oven[2], palette.node("chimney"))
					buf:put(oven[1], 3, oven[2], palette.node("chimney_cap"))
				end
				dressing.counter(buf, palette, -4, -3, 5, "x")
				dressing.bench(buf, palette, -3, 7, 2, 3, "x")
				dressing.crates(buf, palette, 7, -6, 0)
				for _, lamp in ipairs({{-8, -8}, {8, -8}, {-8, 8}, {8, 8}}) do
					dressing.path_light(buf, palette, lamp[1], lamp[2])
				end
			end,
			extra_sockets = function()
				return {
					plots.work("cook_oven_west", "brew", -5, 2, 0),
					plots.idle("cook_oven_east", 4, 2, 2, {"work"}),
					plots.work("cook_counter", "stall", -2, -4, 0),
					plots.idle("cook_bench", -2, 7, 2, {"bench"}, 2),
					plots.spare("cook_court", 10, -6, 0),
				}
			end},

		-- 4-6. THREE CLAN DWELLINGS, each a different plan so a terrace of
		-- flat decks is not a terrace of one house repeated.
		{id = "warren_house_spear", module = "buildings", make = "cottage",
			order = 4,
			parapet = {y = 6},
			spec = {w = 11, d = 9, wall_h = 4, roof = "flat_deck",
				infill = true, shutters = true},
			extra_sockets = function(area)
				return {
					plots.idle("spear_step", area.x1 - 3, area.z1 - 2, 2,
						{"door"}),
				}
			end},

		{id = "warren_house_tusk", module = "homes", make = "round_lodge",
			order = 5,
			parapet = {y = 6, grow = 0},
			spec = {w = 9, d = 9, wall_h = 4},
			extra_sockets = function(area)
				return {
					plots.idle("tusk_step", area.x0 + 3, area.z1 - 2, 2,
						{"door"}),
				}
			end},

		{id = "warren_house_bone", module = "buildings", make = "cottage",
			order = 6, margin = 3,
			parapet = {y = 7},
			spec = {w = 9, d = 11, wall_h = 5, roof = "flat_deck",
				infill = true, fancy_bed = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.bale_stack(buf, palette, area.x0 + 2, area.z1 - 2, 2)
				dressing.wood_pile(buf, palette, area.x1 - 4, area.z1 - 2,
					3, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("bone_house_saw", "chop", area.x1 - 3,
						area.z1 - 3, 0),
					plots.spare("house_bone", area.x0 + 2, area.z0 + 2, 0),
				}
			end},

		-- 7. THE WEAVER'S SHED: the hides and the cloth the quarter makes, on
		-- racks under an open roof.
		{id = "warren_weaver", module = "buildings", make = "shed",
			order = 7, margin = 4,
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-"}},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.drying_rack(buf, palette, area.x0 + 3, area.z1 - 3,
					5, "x")
				dressing.drying_rack(buf, palette, area.x0 + 3, area.z1 - 1,
					5, "x")
				dressing.crates(buf, palette, area.x1 - 2, area.z0 + 3, 2)
				dressing.counter(buf, palette, area.x1 - 5, area.z1 - 2, 3,
					"x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("weaver_counter", "stall", area.x1 - 4,
						area.z1 - 3, 0),
					plots.work("weaver_rack", "tend", area.x0 + 5,
						area.z1 - 2, 2),
				}
			end},

		-- 8. THE STORE LODGE: the quarter's own grain and dried meat.
		{id = "warren_store", module = "capitals", make = "granary",
			order = 8, handle = "ors",
			spec = {w = 11, d = 15, wall_h = 5},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.counter(buf, palette, area.x0 + 2, area.z1 - 2, 3,
					"x")
				dressing.bale_stack(buf, palette, area.x0 + 6, area.z1 - 2, 3)
				dressing.crates(buf, palette, area.x1 - 2, area.z1 - 2, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("warren_store_stall", "stall", area.x0 + 3,
						area.z1 - 1, 2),
				}
			end},

		-- 9. THE STORY FIRE: the cultural half of this district's role. A
		-- circle of benches round one great cauldron, a standard at each
		-- quarter, and the quarter's third spare.
		{id = "warren_story_fire", yard = {w = 10, d = 10}, order = 9,
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for z = -6, 6 do
					for x = -6, 6 do
						if math.abs(x) + math.abs(z) <= 7 then
							buf:put(x, 0, z, palette.node("path"))
						end
					end
				end
				buf:put(0, 1, 0, palette.node("hearth"))
				dressing.bench(buf, palette, -4, -3, 0, 3, "x")
				dressing.bench(buf, palette, 2, -3, 0, 3, "x")
				dressing.bench(buf, palette, -4, 3, 2, 3, "x")
				dressing.bench(buf, palette, 2, 3, 2, 3, "x")
				for _, mast in ipairs({{-7, -7}, {7, -7}, {-7, 7}, {7, 7}}) do
					dressing.standard(buf, palette, mast[1], mast[2], 4)
				end
				dressing.undergrowth(buf, palette, -9, -9, 9, 9, 6)
			end,
			extra_sockets = function()
				return {
					plots.work("story_brew", "brew", 0, -2, 0),
					plots.work("story_seat_west", "sit", -3, -3, 0,
						{"bench"}, 2),
					plots.idle("story_seat_east", 3, 3, 2, {"bench"}, 2),
					plots.spare("story_fire", 8, -8, 0),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL. A living quarter's open ground is the ground
	-- people keep: what they grow, what they dry, what they burn and one green
	-- to sit in.
	local FILL = {
		-- 1. THE CLAN GROUND: dry scrub inside a rail, with the bales, the
		-- carts and the fire the quarter musters round.
		{id = "warren_clan_ground", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -11, -8, -11, 11)
				dressing.fence_line(buf, palette, 11, -8, 11, 11)
				dressing.undergrowth(buf, palette, -10, -5, 10, 10, 4)
				buf:put(0, 1, 2, palette.node("hearth"))
				dressing.bale_stack(buf, palette, -4, 7, 3)
				dressing.handcart(buf, palette, 4, -8, "x")
				dressing.standard(buf, palette, -9, -8, 5)
				dressing.standard(buf, palette, 9, -8, 5)
				dressing.bench(buf, palette, -3, -2, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("clan_ground_brew", "brew", 0, 1, 0),
					plots.idle("clan_ground_forage", -6, -5, 2, {"work"}),
					plots.spare("clan_ground", 10, -11, 0),
				}
			end},

		-- 2. THE DRY GARDEN: beds of what will grow on a mesa, in rows under a
		-- rail, with the two who keep them.
		{id = "warren_dry_garden", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -11, 11, 11, 11)
				for _, bed in ipairs({{-9, 0, -5, 4}, {-3, 0, 1, 4},
						{3, 0, 7, 4}, {-9, 6, -5, 10}, {-3, 6, 1, 10},
						{3, 6, 7, 10}}) do
					dressing.planter(buf, palette, bed[1], bed[2], bed[3],
						bed[4])
				end
				-- No `dressing.plant` over the beds: `dressing.planter` ALREADY
				-- sows every cell inside its own kerb -- soil at the ground
				-- course and a tuft or a fern above it -- so a second call there
				-- overwrites the soil with a tuft and leaves the first one
				-- standing on a plant, which is an attached node with no
				-- support.
				dressing.undergrowth(buf, palette, -10, -8, 10, -2, 5)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("garden_tend_west", "tend", -7, -1, 0),
					plots.idle("garden_tend_east", 5, -1, 0, {"work"}),
					plots.idle("garden_forage", -1, -3, 0, {"work"}),
					plots.idle("garden_bench", -2, -10, 0, {"bench"}, 2),
				}
			end},

		-- 3. THE FUEL YARD at the outer corner: the brush and the timber the
		-- quarter burns, and the two who cut it.
		{id = "warren_fuel_yard", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.wood_pile(buf, palette, -6, 1, 5, "x")
				dressing.wood_pile(buf, palette, -6, 4, 5, "x")
				buf:put(-4, 1, -4, palette.node("tree_log"))
				buf:put(4, 1, -4, palette.node("tree_log"))
				dressing.bale_stack(buf, palette, 6, 3, 2)
				dressing.crates(buf, palette, 6, -6, 0)
				dressing.undergrowth(buf, palette, -8, -8, 8, -6, 5)
			end,
			extra_sockets = function()
				return {
					plots.work("fuel_saw_west", "chop", -4, -5, 0),
					plots.idle("fuel_saw_east", 4, -5, 0, {"work"}),
					plots.spare("fuel_yard", 7, 7, 2),
				}
			end},

		-- 4. THE WARREN GREEN inside the lot grid: one acacia, a bench, the
		-- stores and a place to stand.
		{id = "warren_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.acacia(buf, palette, 0, 2, 5)
				buf:put(0, 1, 0, palette.node("undergrowth"))
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.crates(buf, palette, 3, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.idle("green_seat", -4, -3, 0, {"bench"}, 2),
					plots.work("green_forage", "forage", 0, -1, 0),
					plots.spare("warren_green", 4, -5, 0),
				}
			end},
	}

	M.homes = plots.district({
		key = "gor_drazhak_warren",
		role = "residential_cultural",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
		generators = {round_lodge = round_lodge},
	})

	return M
end

return loader
