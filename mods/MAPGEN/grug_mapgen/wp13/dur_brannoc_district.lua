-- Dur Brannoc, the forge and professions district: nine terrain-relative plots
-- and four dressings.
--
-- The contract's FIRST district role (`market_professions`), and the one this
-- capital shipped with in wave 1 under the ad-hoc role name `martial_craft`.
-- What a plot is and how it is built is `dur_brannoc_plot.lua`; where the nine
-- plots stand is `dur_brannoc_quadrants.lua`. This file is the roster and
-- nothing else.
--
-- THE NINE PLOT IDS ARE WAVE 1'S, UNCHANGED, and so are every socket id they
-- publish. The upgrade to four districts moves the plots -- they stood at nine
-- hand-picked positions and they stand on a quadrant's lot grid now -- but a
-- socket id is what an entity in the user's existing world is remembered
-- against, so `forge_charcoal`, `forge_pack_stable`, `forge_smithy`,
-- `forge_guild_house`, `forge_quench_court`, `forge_watch`, `forge_copse`,
-- `forge_ore_yard` and `forge_store` keep their names and their generators.
-- What is new here is their WORK: wave 1 published one flair spot per plot and
-- no workplace at all, which is the "every resident is a doorstep-stander"
-- finding of playtest round 3.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/dur_brannoc_plot.lua")(directory)

	local M = {}

	local WATCH = "dur_brannoc_forge_watch"

	-- THE APRON IS WHERE A BUILDING PLOT'S DRESSING GOES, and the rule is
	-- geometric rather than a matter of taste: a plot's ground is the part's
	-- own extent grown by its margin, so the only cells a `decorate` may write
	-- without landing inside the building are the ring round it. The front row
	-- of that ring -- `z0 + 1`, between the two corner lamps and clear of the
	-- doorstep path down the middle -- is the one every plot has, whatever its
	-- margin, and it is also the row a passer-by on the lane sees. So every
	-- workplace of a building plot stands on the outermost row `z0` and faces
	-- the feature on `z0 + 1`, which is what makes the socket's `dir` name the
	-- feature (sockets contract section 8.1). The wave-1 version of this file
	-- wrote its dressing at `x1 - 4, z0 + 3` and put a wood pile inside the
	-- granary; the KAT's own "a bottom slab carries nothing" rule found it.
	local function shop_counter(buf, palette, area)
		area.dressing.counter(buf, palette, area.x1 - 5, area.z0 + 1, 4, "x")
	end
	local function shop_vendor(id, kind, area)
		return plots.vendor(id, kind, area.x1 - 4, area.z0, 0)
	end

	local PLOTS = {
		-- 1. The charcoal store: the fuel the forge court burns, kept dry in a
		-- granary and stacked on the apron outside it.
		{id = "forge_charcoal", module = "capitals", make = "granary",
			order = 1, spec = {w = 11, d = 15, wall_h = 5},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("tree_log"))
				buf:put(area.x1 - 3, 1, area.z0 + 1, palette.node("tree_log"))
			end,
			extra_sockets = function(area)
				return {
					plots.work("charcoal_west", "chop", area.x0 + 3,
						area.z0, 0),
					plots.work("charcoal_east", "chop", area.x1 - 3,
						area.z0, 0),
				}
			end},
		-- 2. The pack stable: the goats that carry ore down from the workings.
		{id = "forge_pack_stable", module = "capitals", make = "stable",
			order = 2, spec = {w = 15, d = 11, wall_h = 5},
			decorate = function(buf, palette, area)
				-- The fodder on the apron: a planter's KERB is solid masonry
				-- and stops the feature search on the socket's own course, so
				-- the thing a `tend` socket faces is a plant standing on the
				-- ground beside it and not a raised bed it cannot see into.
				area.dressing.plant(buf, palette, area.x0 + 3, area.z0 + 1)
				area.dressing.plant(buf, palette, area.x0 + 4, area.z0 + 1)
			end,
			extra_sockets = function(area)
				return {
					plots.work("stable_tend", "tend", area.x0 + 3, area.z0, 0),
					plots.spare("stable", area.x1 - 1, area.z0, 0),
				}
			end},
		-- 3. The smithy. It opens in its x- wall and the plot is TURNED, for
		-- the two reasons wave 1 recorded: the `workshop` interior kit stands
		-- the forge's cauldrons on the odd cells of the z- gable's inner run,
		-- and the generator's own chimney stack stands on the middle cell of
		-- that same wall and is written after the door.
		{id = "forge_smithy", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				-- The anvil on the apron: the dwarf palette's `workbench` is
				-- `grug_materials:iron_block`, which is the node the sockets
				-- contract's `smith` activity names.
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("workbench"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("anvil", "smith", area.x0 + 3, area.z0, 0),
					shop_vendor("smith", "smith", area),
				}
			end},
		-- 4. The guild house of the forge, roofed in slate so it reads as
		-- civic from the lane rather than as the largest workshop in it.
		{id = "forge_guild_house", module = "capitals", make = "scriptorium",
			order = 4, roof = "slate", spec = {w = 13, d = 17, wall_h = 6},
			decorate = function(buf, palette, area)
				area.dressing.bench(buf, palette, area.x0 + 3, area.z0 + 1,
					2, 2, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("guild_bench", "sit", area.x0 + 3, area.z0 + 1,
						2, {"bench"}, 2),
				}
			end},
		-- 5. The quenching court is the district's public ground, so its plot
		-- is five nodes wider all round than a building's and the ring that
		-- buys is planted.
		{id = "forge_quench_court", module = "capitals", make = "well_court",
			order = 5, margin = 5, garden = true, spec = {size = 11},
			extra_sockets = function(area)
				return {
					plots.work("quench_bench", "sit", -1, area.z1 - 2, 2,
						{"bench"}, 2),
					plots.spare("quench", area.x0 + 3, area.z0 + 2, 0),
				}
			end},
		-- 6. The district watch. The barracks generator publishes its own
		-- guard post, its muster idle spot and waypoint 6 of the loop, so this
		-- row carries no `order` of its own.
		{id = "forge_watch", module = "capitals", make = "barracks",
			roof = "slate",
			spec = {w = 15, d = 21, wall_h = 5, patrol_group = WATCH,
				order = 6}},
		-- 7. A pine copse rather than a broadleaf grove: this is the
		-- Hearthpine terrace, and `grove` takes the dressing silhouette it is
		-- given. It is also where the district forages.
		{id = "forge_copse", module = "capitals", make = "grove",
			order = 7, spec = {size = 15, kind = "tree", height = 8},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1,
					palette.node("undergrowth"))
			end,
			extra_sockets = function(area)
				return {
					plots.work("copse_forage", "forage", area.x0 + 3,
						area.z0, 0),
				}
			end},
		-- 8. The ore yard: what comes down from the workings before it is
		-- smelted, kept in a granary with the heaps on the apron.
		{id = "forge_ore_yard", module = "capitals", make = "granary",
			order = 8, spec = {w = 11, d = 15, wall_h = 5},
			decorate = function(buf, palette, area)
				-- A face of bedded granite on the apron, two courses, which is
				-- what a `mine` socket at the outer row looks at.
				area.dwarf.rock_face(buf, palette, area.x0 + 2, area.z0 + 1,
					area.x0 + 5, area.z0 + 1, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("ore_sort", "mine", area.x0 + 3, area.z0, 0),
					plots.spare("ore_yard", area.x1 - 1, area.z0, 0),
				}
			end},
		-- 9. The store. Door index 4, single leaf: the `store` kit stands its
		-- roof posts on the odd cells of the gable's inner run, so an
		-- eleven-wide longhouse's centred door opens onto a post.
		{id = "forge_store", module = "buildings", make = "longhouse",
			order = 9,
			spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true},
			decorate = function(buf, palette, area)
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("store_counter", "stall", area.x1 - 2,
						area.z0, 0),
					shop_vendor("mason", "mason", area),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL: four dressings on the quadrant's four fill lots,
	-- reaches 11, 11, 8 and 5. A forge quarter's open ground is the ground the
	-- trade needs: the workings it digs, the fuel it burns, the spoil it throws
	-- and one green to sit in.
	local FILL = {
		-- 1. THE ORE COURT: a cut rock face along the back of the lot with a
		-- mine mouth in the middle of it, the heaps in front, and the two who
		-- work it. This is the `mine` activity's home, and the rock face is the
		-- feature the contract's section 8.2 requires under `dir`.
		{id = "forge_ore_court", yard = {},
			decorate = function(buf, palette, area)
				local dwarf = area.dwarf
				dwarf.rock_face(buf, palette, -10, 9, -4, 9, 5)
				dwarf.mine_mouth(buf, palette, 2, 9, 9, 5)
				dwarf.ore_heap(buf, palette, -7, 3, 3)
				dwarf.ore_heap(buf, palette, 6, 2, 2)
				area.dressing.crates(buf, palette, -9, -6, 0)
				area.dressing.handcart(buf, palette, 3, -6, "x")
				area.dressing.bench(buf, palette, -3, -9, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("court_face", "mine", -7, 8, 0),
					plots.work("court_adit", "mine", 5, 8, 0),
					plots.work("court_spoil", "mine", -9, 8, 0),
					plots.spare("ore_court", 9, -9, 0),
				}
			end},
		-- 2. THE CHARCOAL FIELD: the clamps, the billet stacks and the two
		-- burners who keep them.
		{id = "forge_charcoal_field", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				local dwarf = area.dwarf
				dwarf.charcoal_clamp(buf, palette, -6, 7)
				dwarf.charcoal_clamp(buf, palette, 5, 7)
				-- The billet stacks the clamps are fed from. The two burners
				-- stand SOUTH of them and face the timber, because `chop` names
				-- a log and a clamp's own earth dome is dirt.
				dressing.wood_pile(buf, palette, -8, 1, 5, "x")
				dressing.wood_pile(buf, palette, 2, 1, 5, "x")
				dressing.fence_line(buf, palette, -11, 10, 11, 10)
				dressing.handcart(buf, palette, 8, -6, "x")
				dressing.bench(buf, palette, -3, -9, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("field_west", "chop", -6, 0, 0),
					plots.work("field_east", "chop", 4, 0, 0),
					plots.spare("charcoal_field", 9, -9, 0),
				}
			end},
		-- 3. THE SLAG YARD: what the smelting throws away, and the mason who
		-- squares the good stone out of it.
		{id = "forge_slag_yard", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				local dwarf = area.dwarf
				dressing.rubble_heap(buf, palette, -4, 3, 3)
				dressing.rubble_heap(buf, palette, 4, 3, 2)
				dwarf.cut_blocks(buf, palette, -2, -2, 4, "x")
				dwarf.banker(buf, palette, 3, -3)
				dressing.crates(buf, palette, 6, -6, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("slag_banker", "carve", 3, -4, 0),
					plots.work("slag_blocks", "carve", -2, -3, 0),
				}
			end},
		-- 4. THE FORGE GREEN inside the outer band: a pine, a bench, the
		-- stores, and the district's second spare.
		{id = "forge_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.tree(buf, palette, 0, 2, 5)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.crates(buf, palette, 3, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("green_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("forge_green", 4, -5, 0),
				}
			end},
	}

	M.forge = plots.district({
		key = "dur_brannoc_forge",
		role = "market_professions",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
