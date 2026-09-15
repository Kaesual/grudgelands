-- Gor Drazhak, the BAZAAR: the market and professions district, nine
-- terrain-relative plots and four fill lots.
--
-- The contract's first district role. What a plot is and how it is built is
-- `gor_drazhak_plot.lua`; where the nine plots stand is
-- `gor_drazhak_quadrants.lua`. This file is the roster and nothing else.
--
-- WHAT MAKES IT ORCISH rather than a market with an adobe skin. The five
-- profession vendors of the sockets contract's section 8.4 that fit this race
-- are here and nowhere else in the capital -- butcher, tanner, brewer,
-- armourer, smith -- and each one stands at the trade it sells: the butcher at
-- a hanging rack over a chopping block, the tanner at his vats, the brewer at
-- the grog cauldrons, the armourer and the smith at their anvils. The race and
-- general vendors are the core's two royal booths (contract section 4's
-- `grug_traders` rule: at most one of each kind in a capital).
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/gor_drazhak_plot.lua")(directory)

	local M = {}

	local WATCH = "gor_drazhak_bazaar_watch"

	local PLOTS = {
		-- 1. THE BUTCHER ROW, which is the first thing the contract's orc
		-- line asks for that no other capital has: a workshop with the
		-- hanging racks on its apron and the chopping block in front of them.
		-- `chop` is the activity, and the feature under its `dir` is that
		-- block -- a log, which is exactly what the vocabulary names.
		{id = "bazaar_butcher", module = "buildings", make = "workshop",
			order = 1, handle = "ors",
			parapet = {y = 7},
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, roof = "flat_deck",
				door_side = "z-", door_index = 5, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.drying_rack(buf, palette, area.x0 + 2, area.z1 - 3,
					5, "x")
				dressing.drying_rack(buf, palette, area.x0 + 2, area.z1 - 1,
					5, "x")
				buf:put(area.x1 - 3, 1, area.z1 - 2, palette.node("tree_log"))
				buf:put(area.x1 - 5, 1, area.z1 - 2, palette.node("tree_log"))
				dressing.crates(buf, palette, area.x1 - 2, area.z0 + 4, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.vendor("butcher", "butcher", area.x1 - 4,
						area.z1 - 2, 3),
					plots.work("butcher_block", "chop", area.x1 - 4,
						area.z1 - 2, 1),
					plots.work("butcher_rack", "carve", area.x0 + 4,
						area.z1 - 2, 2),
				}
			end},

		-- 2. THE TANNERY: a shed over the pits, the vats on the yard and the
		-- hides on their frames. `brew` is the vocabulary's word for a
		-- resident stirring a cauldron, and a tan vat is a cauldron.
		{id = "bazaar_tannery", module = "buildings", make = "shed",
			order = 2, margin = 4,
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-"}},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, vat in ipairs({{area.x0 + 3, area.z1 - 3},
						{area.x0 + 5, area.z1 - 3},
						{area.x0 + 7, area.z1 - 3}}) do
					buf:put(vat[1], 1, vat[2], palette.node("hearth"))
				end
				dressing.drying_rack(buf, palette, area.x1 - 4, area.z1 - 4,
					4, "z")
				dressing.crates(buf, palette, area.x1 - 2, area.z0 + 3, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.vendor("tanner", "tanner", area.x0 + 5,
						area.z1 - 2, 2),
					plots.work("tan_vat_west", "brew", area.x0 + 3,
						area.z1 - 2, 2),
					plots.idle("tan_vat_east", area.x0 + 7,
						area.z1 - 2, 2, {"work"}),
				}
			end},

		-- 3. THE GROG HOUSE. The brewer's own vats stand outdoors in front of
		-- it, which is where a socket has to be (a socket is never inside a
		-- room) and where a grog vat belongs in a camp that never stopped
		-- being one.
		{id = "bazaar_brewhouse", module = "buildings", make = "workshop",
			order = 3, margin = 3,
			parapet = {y = 7},
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, roof = "flat_deck",
				door_side = "z-", door_index = 5, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, vat in ipairs({{area.x0 + 2, area.z1 - 2},
						{area.x0 + 4, area.z1 - 2}}) do
					buf:put(vat[1], 1, vat[2], palette.node("hearth"))
				end
				buf:put(area.x0 + 3, 1, area.z1 - 4,
					palette.node("storage"))
				dressing.bench(buf, palette, area.x1 - 5, area.z1 - 2, 2, 3,
					"x")
				dressing.wood_pile(buf, palette, area.x1 - 2, area.z0 + 3,
					3, "z")
			end,
			extra_sockets = function(area)
				return {
					plots.vendor("brewer", "brewer", area.x0 + 6,
						area.z1 - 2, 3),
					plots.work("grog_vat", "brew", area.x0 + 3,
						area.z1 - 1, 2),
					plots.idle("grog_bench", area.x1 - 4,
						area.z1 - 2, 0, {"bench"}, 2),
				}
			end},

		-- 4. THE ARMOURER, and 5. THE SMITH: two forges, because an orc city
		-- that sells one kind of iron is an orc city nobody fights out of.
		-- Both open in their x- wall like Dawnmere's smithy -- the `workshop`
		-- kit stands the forge's cauldrons on the odd cells of the z- gable's
		-- inner run and the generator's chimney on that wall's middle cell, so
		-- a door there would open onto a hearth.
		{id = "bazaar_armourer", module = "buildings", make = "workshop",
			order = 4, margin = 3, handle = "ors",
			parapet = {y = 7},
			spec = {w = 11, d = 15, wing = 7, wall_h = 5, roof = "flat_deck",
				door_side = "x-", door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for _, anvil in ipairs({{area.x1 - 3, area.z0 + 3},
						{area.x1 - 3, area.z0 + 5}}) do
					buf:put(anvil[1], 1, anvil[2], palette.node("workbench"))
				end
				buf:put(area.x1 - 3, 1, area.z0 + 7, palette.node("hearth"))
				dressing.crates(buf, palette, area.x1 - 2, area.z1 - 3, 2)
				dressing.wood_pile(buf, palette, area.x0 + 2, area.z1 - 2,
					3, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.vendor("armourer", "armourer", area.x1 - 5,
						area.z0 + 4, 1),
					plots.work("armour_anvil", "smith", area.x1 - 4,
						area.z0 + 3, 1),
					plots.idle("armour_forge", area.x1 - 4,
						area.z0 + 7, 1, {"work"}),
				}
			end},

		{id = "bazaar_smithy", module = "buildings", make = "workshop",
			order = 5, margin = 3, handle = "ors",
			parapet = {y = 7},
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, roof = "flat_deck",
				door_side = "x-", door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				buf:put(area.x1 - 3, 1, area.z0 + 4, palette.node("workbench"))
				buf:put(area.x1 - 3, 1, area.z0 + 6, palette.node("hearth"))
				dressing.wood_pile(buf, palette, area.x0 + 2, area.z1 - 2,
					4, "x")
				dressing.crates(buf, palette, area.x1 - 2, area.z1 - 2, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.vendor("smith", "smith", area.x1 - 5,
						area.z0 + 5, 1),
					plots.work("smith_anvil", "smith", area.x1 - 4,
						area.z0 + 4, 1),
					plots.spare("smithy", area.x0 + 2, area.z0 + 2, 0),
				}
			end},

		-- 6. THE STORE HOUSE: the granary generator, which is a store with
		-- bins down both walls and a cart-wide double door, and the counter on
		-- its apron where the keeper stands.
		{id = "bazaar_store", module = "capitals", make = "granary",
			order = 6, margin = 3, handle = "ors",
			spec = {w = 11, d = 15, wall_h = 5},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.counter(buf, palette, area.x1 - 4, area.z1 - 2, 3,
					"x")
				dressing.crates(buf, palette, area.x0 + 2, area.z1 - 2, 2)
				dressing.crates(buf, palette, area.x0 + 2, area.z1 - 4, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("store_counter", "stall", area.x1 - 3,
						area.z1 - 3, 2),
				}
			end},

		-- 7. THE WAIN YARD: the shed open on two sides with the carts under it
		-- and the timber it hauls stacked on the apron.
		{id = "bazaar_wain_yard", module = "buildings", make = "shed",
			order = 7, margin = 4,
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.wagon(buf, palette, area.x0 + 3, area.z1 - 3, "x")
				dressing.wood_pile(buf, palette, area.x1 - 3, area.z1 - 4,
					4, "z")
				buf:put(area.x0 + 2, 1, area.z1 - 5, palette.node("tree_log"))
				dressing.crates(buf, palette, area.x1 - 2, area.z0 + 3, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("wain_saw", "chop", area.x0 + 2,
						area.z1 - 4, 2),
					plots.idle("wain_load", area.x0 + 5,
						area.z1 - 2, 0, {"work"}),
				}
			end},

		-- 8. THE CARVER: the bone and horn work the contract's totem posts are
		-- made of. The half-cut post stands on his apron and the finished ones
		-- flank his door.
		{id = "bazaar_carver", module = "buildings", make = "cottage",
			order = 8, margin = 3,
			parapet = {y = 6},
			spec = {w = 9, d = 11, wall_h = 4, roof = "flat_deck",
				infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.totem(buf, palette, area.x0 + 2, area.z0 + 3, 4)
				dressing.totem(buf, palette, area.x1 - 2, area.z0 + 3, 4)
				buf:put(area.x0 + 3, 1, area.z1 - 2, palette.node("tree_log"))
				buf:put(area.x0 + 3, 2, area.z1 - 2, palette.node("tree_log"))
				dressing.bench(buf, palette, area.x1 - 5, area.z1 - 2, 2, 3,
					"x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("carver_post", "carve", area.x0 + 3,
						area.z1 - 3, 2),
					plots.idle("carver_bench", area.x1 - 4, area.z1 - 2, 0,
						{"bench"}),
				}
			end},

		-- 9. THE TRADER'S HOUSE, and the district's second spare.
		{id = "bazaar_house", module = "buildings", make = "cottage",
			order = 9,
			parapet = {y = 6},
			spec = {w = 11, d = 9, wall_h = 4, roof = "flat_deck",
				infill = true, fancy_bed = true},
			extra_sockets = function(area)
				return {
					plots.spare("bazaar_house", area.x1 - 2, area.z1 - 2, 2),
					plots.idle("house_step", area.x0 + 3, area.z1 - 2, 2,
						{"door"}),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL: four dressings on the quadrant's four fill
	-- lots, reaches 11, 11, 8 and 5. A bazaar quarter's open ground is the
	-- ground a market keeps -- the stock it has not sold, the ochre it dries,
	-- the spoil it throws out and one fire to sit at.
	local FILL = {
		-- 1. THE STOCK PEN: rails, straw, a handcart and the two who keep it.
		{id = "bazaar_stock_pen", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -11, -8, -11, 11)
				dressing.fence_line(buf, palette, 11, -8, 11, 11)
				dressing.fence_line(buf, palette, -11, 11, 11, 11)
				dressing.undergrowth(buf, palette, -10, -5, 10, 10, 5)
				dressing.bale_stack(buf, palette, -4, 6, 3)
				dressing.bale_stack(buf, palette, -2, 6, 2)
				dressing.handcart(buf, palette, 3, -8, "x")
				dressing.wood_pile(buf, palette, -9, -8, 3, "x")
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("pen_saw", "chop", -8, -9, 0),
					plots.idle("pen_forage", -6, -4, 2, {"work"}),
					plots.spare("stock_pen", 10, -11, 0),
				}
			end},

		-- 2. THE DRYING FLOOR: where the hides and the ochre lie out. Racks in
		-- ranks, a shrub border that has not been cleared, and the rakers.
		{id = "bazaar_drying_floor", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				for x = -8, 8, 4 do
					dressing.drying_rack(buf, palette, x, -2, 5, "z")
				end
				dressing.undergrowth(buf, palette, -11, 6, 11, 11, 4)
				dressing.crates(buf, palette, -9, -8, 2)
				dressing.crates(buf, palette, 9, -8, 0)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("dry_rake", "sweep", 0, -6, 0),
					plots.idle("dry_forage", -6, 5, 2, {"work"}),
					plots.idle("dry_bench", -2, -10, 0, {"bench"}),
				}
			end},

		-- 3. THE SPOIL HEAP at the outer corner: what a city throws out, and
		-- the one who picks it over.
		{id = "bazaar_spoil_heap", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.rubble_heap(buf, palette, -4, 2, 3)
				dressing.rubble_heap(buf, palette, 3, 3, 2)
				dressing.crates(buf, palette, 5, -4, 0)
				dressing.wood_pile(buf, palette, -6, -4, 4, "x")
				dressing.undergrowth(buf, palette, -8, -8, 8, 8, 6)
			end,
			extra_sockets = function()
				return {
					plots.work("spoil_pick", "forage", -4, -1, 2),
					plots.idle("spoil_saw", -6, -5, 0, {"work"}),
					plots.spare("spoil", 6, 6, 2),
				}
			end},

		-- 4. THE FIRE COURT inside the lot grid: one cauldron on a paved
		-- square, benches round it, and the district's own idle corner.
		{id = "bazaar_fire_court", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.inlay(buf, palette, -4, -4, 4, 4, "plaza_edge")
				buf:put(0, 1, 0, palette.node("hearth"))
				dressing.bench(buf, palette, -3, -2, 0, 3, "x")
				dressing.bench(buf, palette, 1, 2, 2, 3, "x")
				dressing.crates(buf, palette, 4, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("fire_brew", "brew", 0, -1, 2),
					plots.idle("fire_seat", -2, -2, 0, {"bench"}, 2),
				}
			end},
	}

	M.market = plots.district({
		key = "gor_drazhak_bazaar",
		role = "market_professions",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
