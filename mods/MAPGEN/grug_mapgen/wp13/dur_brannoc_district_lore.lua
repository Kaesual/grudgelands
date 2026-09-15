-- Dur Brannoc, the lore and spiritual district: nine terrain-relative plots and
-- four dressings.
--
-- The contract's third district role. What a plot is and how it is built is
-- `dur_brannoc_plot.lua`; where the nine plots stand is
-- `dur_brannoc_quadrants.lua`. This file is the roster and nothing else.
--
-- WHAT A DWARF LORE QUARTER IS, and where the reading of it comes from. The
-- capitals contract's section 2.4 gives this race "stone-block citadel walls
-- with pillars and arrowslits, pine-and-slate halls, forge court, stair streets
-- between terraces" and nothing about its dead or its records; the core already
-- carries the hall of the ancestors and the capital's one quest socket. So this
-- quarter is a DESIGN DECISION of this lane, labelled as one: the dwarves keep
-- their memory in stone, so the quarter is halls of record, a carvers' yard
-- where the names are cut, and a barrow terrace where they stand. The wave-2
-- activities `carve` and `mourn` are what it is built around.
--
-- THE SECOND QUEST SOCKET IS THE TEMPLE'S OWN. `capitals.temple` publishes one
-- wherever it is built, which is how Highcourt comes to have two (its core's
-- and its lore district's) and how this capital comes to have two.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/dur_brannoc_plot.lua")(directory)

	local M = {}

	local WATCH = "dur_brannoc_deep_watch"

	-- The shopfront of every profession house of this capital; see
	-- `dur_brannoc_district.lua` for why the apron's front row is the one place
	-- a building plot's dressing may stand.
	local function shop_counter(buf, palette, area)
		area.dressing.counter(buf, palette, area.x1 - 5, area.z0 + 1, 4, "x")
	end

	local PLOTS = {
		-- 1. The hall of record: the district's temple, which publishes the
		-- quest socket of the sockets contract wherever it stands.
		{id = "deep_hall_of_record", module = "capitals", make = "temple",
			order = 1, roof = "slate", spec = {w = 13, d = 17, wall_h = 6},
			decorate = function(buf, palette, area)
				-- A candle on the apron, which is the `pray` rule's own "an
				-- altar, a candle or a grave marker". A torch stands on an
				-- opaque full node, so the block under it is laid first.
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("plaza_edge"))
				area.parts.floor_torch(buf, palette, area.x0 + 3, 2,
					area.z0 + 1)
			end,
			extra_sockets = function(area)
				return {
					plots.work("record_vigil", "pray", area.x0 + 3,
						area.z0, 0),
				}
			end},
		-- 2. The scriptorium: where what is cut in stone is first written down.
		{id = "deep_scriptorium", module = "capitals", make = "scriptorium",
			order = 2, roof = "slate", spec = {w = 13, d = 17, wall_h = 6},
			decorate = function(buf, palette, area)
				area.dressing.bench(buf, palette, area.x0 + 3, area.z0 + 1,
					2, 2, "x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("scriptorium_bench", "sit", area.x0 + 3,
						area.z0 + 1, 2, {"bench"}, 2),
				}
			end},
		-- 3. The memory hall, under slate: the long room the roll of the dead
		-- is read in, with the barrow markers on its own apron -- and, since the
		-- review of 2026-09-15, THE EMBALMER'S COUNTER.
		--
		-- The sockets contract's section 8.4 says a profession vendor's socket
		-- stands at the matching building, and the first version of this roster
		-- broke that rule twice over: it gave the `embalmer` kind to the socket
		-- at the CARVERS' bench (whose id, comment and building all said mason)
		-- and the `mason` kind to an ordinary longhouse store in the forge
		-- quarter. The kinds are where they belong now: the mason at the
		-- carvers' (plot 4), the embalmer here, and the forge quarter's store
		-- sells through its own smith.
		{id = "deep_memory_hall", module = "buildings", make = "hall",
			roof = "slate", order = 3,
			spec = {w = 15, d = 17, wall_h = 5, infill = true},
			decorate = function(buf, palette, area)
				area.dwarf.barrow_line(buf, palette, area.x0 + 2, area.z0 + 1,
					3, "x", true)
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("memory_vigil", "mourn", area.x0 + 2,
						area.z0, 0),
					plots.vendor("deep_embalmer", "embalmer", area.x1 - 4,
						area.z0, 0),
				}
			end},
		-- 4. The carvers' workshop, turned and opening in its x- wall like
		-- every workshop of this capital, with the blocks it works on the
		-- apron and the mason who sells the work at the counter.
		{id = "deep_carvers", module = "buildings", make = "workshop",
			order = 4, turns = 3,
			spec = {w = 11, d = 15, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				area.dwarf.cut_blocks(buf, palette, area.x0 + 2, area.z0 + 1,
					4, "x")
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("carver_blocks", "carve", area.x0 + 2,
						area.z0, 0),
					plots.vendor("deep_mason_stall", "mason", area.x1 - 4,
						area.z0, 0),
				}
			end},
		-- 5. The lantern court: the quarter's public ground, five nodes wider
		-- all round than a building's plot and planted in the ring that buys.
		{id = "deep_lantern_court", module = "capitals", make = "well_court",
			order = 5, margin = 5, garden = true, spec = {size = 11},
			extra_sockets = function(area)
				return {
					plots.work("lantern_bench", "sit", -1, area.z1 - 2, 2,
						{"bench"}, 2),
					plots.spare("lantern_court", area.x0 + 3, area.z0 + 2, 0),
				}
			end},
		-- 6. The archive: the racks the rolls are kept on.
		{id = "deep_archive", module = "buildings", make = "longhouse",
			order = 6,
			spec = {w = 13, d = 15, wall_h = 5, door_side = "z-",
				door_index = 6, infill = true}},
		-- 7. The keeper's house.
		{id = "deep_keeper", module = "buildings", make = "cottage",
			order = 7,
			spec = {w = 11, d = 7, wall_h = 4, roof = "hip", infill = true}},
		-- 8. The lamp store, four nodes of yard: the oil and the stands that
		-- light the barrow terrace.
		{id = "deep_lamp_store", module = "buildings", make = "shed",
			order = 8, margin = 4, spec = {w = 13, d = 9, wall_h = 4},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 2, 1, area.z0 + 1, palette.node("tree_log"))
				area.dressing.crates(buf, palette, area.x1 - 3, area.z0 + 1, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("lamp_saw", "chop", area.x0 + 2, area.z0, 0),
				}
			end},
		-- 9. The quarter's watch, and its second spare.
		{id = "deep_watch", module = "buildings", make = "watchpost",
			order = 9, turns = 1, spec = {},
			extra_sockets = function(area)
				return {
					plots.spare("deep_watch", area.x1 - 2, area.z1 - 2, 2),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL: the ground the quarter's trades need. A mushroom
	-- garden in the lee of the wall, the barrow terrace itself, the masons'
	-- yard where the markers are cut, and one green.
	local FILL = {
		-- 1. THE MUSHROOM GARDEN: raised beds against a low rock face, which is
		-- how a dwarf city grows food inside a curtain wall. The beds are what
		-- `forage` faces.
		{id = "deep_mushroom_garden", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				local dwarf = area.dwarf
				dwarf.rock_face(buf, palette, -10, 10, 10, 10, 3)
				dwarf.mushroom_bed(buf, palette, -9, 4, -2, 8)
				dwarf.mushroom_bed(buf, palette, 2, 4, 9, 8)
				dwarf.mushroom_bed(buf, palette, -9, -2, -2, 1)
				dressing.crates(buf, palette, 8, -6, 0)
				dressing.bench(buf, palette, -3, -9, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("garden_west", "forage", -6, 3, 0),
					plots.work("garden_east", "forage", 6, 3, 0),
					plots.work("garden_lower", "forage", -6, -3, 0),
					plots.spare("mushroom_garden", 9, -9, 0),
				}
			end},
		-- 2. THE BARROW TERRACE: the markers in rows behind a kerb, with the
		-- two who keep the ground. `mourn` faces a marker.
		{id = "deep_barrow_terrace", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.low_wall_line(buf, palette, -11, 9, 11, 9)
				area.dwarf.barrow_line(buf, palette, -8, 2, 3, "x", true)
				area.dwarf.barrow_line(buf, palette, -8, 6, 3, "x", false)
				area.dwarf.barrow_line(buf, palette, 4, 2, 2, "x", false)
				-- Nine and not ten: a conifer's crown reaches two nodes, and a
				-- tree at -10 puts a leaf cell at -12, outside the reach-11
				-- fill lot this dressing stands on.
				dressing.tree(buf, palette, -9, -6, 5)
				dressing.tree(buf, palette, 9, -6, 5)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("terrace_vigil", "mourn", -8, 1, 0),
					plots.work("terrace_rake", "sweep", -1, -2, 0),
					plots.spare("barrow_terrace", 9, -9, 0),
				}
			end},
		-- 3. THE MARKERS' YARD: the blocks, the bankers and the two who cut
		-- them.
		{id = "deep_markers_yard", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				local dwarf = area.dwarf
				dwarf.cut_blocks(buf, palette, -6, 2, 5, "x")
				dwarf.banker(buf, palette, -4, -2)
				dwarf.banker(buf, palette, 3, -2)
				dressing.rubble_heap(buf, palette, 5, 4, 2)
				dressing.crates(buf, palette, 6, -6, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("yard_banker_west", "carve", -4, -3, 0),
					plots.work("yard_banker_east", "carve", 3, -3, 0),
				}
			end},
		-- 4. THE LORE GREEN: a pine, a bench, the stores and the district's
		-- third spare.
		{id = "deep_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.tree(buf, palette, 0, 2, 5)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.crates(buf, palette, 3, -3, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("green_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("deep_green", 4, -5, 0),
				}
			end},
	}

	M.lore = plots.district({
		key = "dur_brannoc_deep",
		role = "lore_spiritual",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
