-- Nhal Veyr, the vigil: the lore and spiritual district, nine
-- terrain-relative plots and four fill dressings.
--
-- The contract's third district role, and the one this capital is named for.
-- What a plot is and how it is built is `nhal_veyr_plot.lua`; where the nine
-- plots stand is `nhal_veyr_quadrants.lua`. This file is the roster.
--
-- Two of the nine are MAUSOLEA (`undead_parts.lua`), which is the part the
-- shared capital kit does not carry and the contract's section 2.4 line asks
-- for by name. Their doors face the lane and a mourner stands on each doorstep.
--
-- The vigil holds the city's EMBALMER (sockets contract section 8.4, the
-- wave-2 kinds): the one profession of this race that has nowhere else to be.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/nhal_veyr_plot.lua")(directory)

	local M = {}

	local WATCH = "nhal_veyr_vigil_watch"

	local function shop_counter(buf, palette, area)
		area.dressing.counter(buf, palette, area.x1 - 5, area.z0 + 1, 4, "x")
	end

	local PLOTS = {
		-- 1. The ossuary: the bone house of the district, a granary in dungeon
		-- stone under a vaulted roof.
		{id = "vigil_ossuary", module = "capitals", make = "granary",
			order = 1, handle = "crypt", roof = "vault",
			spec = {w = 13, d = 17, wall_h = 6}},
		-- 2. The scriptorium of the keepers: the district's library, shelving
		-- the length of both walls under a saltbox roof.
		{id = "vigil_scriptorium", module = "capitals", make = "scriptorium",
			order = 2, handle = "crypt", roof = "vault",
			spec = {w = 13, d = 17, wall_h = 6}},
		--
		-- 3. THE EMBALMER'S HOUSE, and the city's `embalmer` vendor. The
		-- preparing slab on the apron is a block of the palette's own
		-- signature -- obsidian brick -- which is what the wave-2 `carve`
		-- activity names ("a log, a totem/statue part or a STONE BLOCK"). The
		-- workshop opens in its x- wall and the plot is turned, for the reason
		-- every workshop in this capital is.
		{id = "vigil_embalmer", module = "buildings", make = "workshop",
			order = 3, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("signature"))
				shop_counter(buf, palette, area)
			end,
			extra_sockets = function(area)
				return {
					plots.work("slab", "carve", area.x0 + 3, area.z0, 0),
					plots.vendor("embalmer", "embalmer", area.x1 - 4,
						area.z0, 0),
				}
			end},
		-- 4 and 5. The two mausolea, each on its own plinth with a candle
		-- standard at either front corner. The part publishes the mourner's
		-- place on its doorstep; this roster makes it a WORK socket instead of
		-- an idle one, because a tomb is a workplace in a necropolis and the
		-- candle it faces is the `mourn` feature of section 8.2.
		--
		-- The part's socket is `idle` and is left as it is; the work socket is
		-- published beside it, on the plinth's own front row, looking ALONG
		-- that row at the west candle standard one node away. Recasting the
		-- part's own socket would mean the part knowing what a composition
		-- wants of it.
		{id = "vigil_mausoleum_west", module = "undead", make = "mausoleum",
			order = 4, handle = "crypt", roof = "vault",
			spec = {w = 11, d = 13, wall_h = 4},
			extra_sockets = function(area)
				-- Two nodes west of the west candle standard, on the plinth's
				-- own front row, looking along it. The candle's local x is -2
				-- whatever the tomb's width is, because the plot builder
				-- centres a part on its origin and the part stands the
				-- standard two nodes off its own axis; the mourner stands at
				-- -4 and looks at +x, so the first thing on its course past an
				-- empty cell is the light.
				return {plots.work("candle", "mourn", -4, area.oz - 1, 1)}
			end},
		{id = "vigil_mausoleum_east", module = "undead", make = "mausoleum",
			order = 5, handle = "crypt", roof = "vault",
			spec = {w = 9, d = 13, wall_h = 4},
			extra_sockets = function(area)
				-- Two nodes west of the west candle standard, on the plinth's
				-- own front row, looking along it. The candle's local x is -2
				-- whatever the tomb's width is, because the plot builder
				-- centres a part on its origin and the part stands the
				-- standard two nodes off its own axis; the mourner stands at
				-- -4 and looks at +x, so the first thing on its course past an
				-- empty cell is the light.
				return {plots.work("candle", "mourn", -4, area.oz - 1, 1)}
			end},
		--
		-- 6. THE CANDLE WORKS. The contract's own "candle-maker": a workshop
		-- with the wax pot on its apron, which is this palette's `hearth` --
		-- `grug_decor:xdecor_cauldron` -- and therefore the `brew` feature of
		-- section 8.2 ("a cauldron, barrel or a cooking pot").
		{id = "vigil_candle_works", module = "buildings", make = "workshop",
			order = 6, turns = 3,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true},
			decorate = function(buf, palette, area)
				buf:put(area.x0 + 3, 1, area.z0 + 1, palette.node("hearth"))
				area.dressing.crates(buf, palette, area.x0 + 5, area.z0 + 1, 0)
			end,
			extra_sockets = function(area)
				return {plots.work("pot", "brew", area.x0 + 3, area.z0, 0)}
			end},
		-- 7. The cloister garth: the district's public ground, five nodes
		-- wider all round than a building's, its ring planted with
		-- gravewoods. The sweeper of the cloisters stands on its walk.
		{id = "vigil_cloister", module = "capitals", make = "well_court",
			order = 7, margin = 5, garden = true, spec = {size = 11},
			-- The garth also carries one of the district's four spare wander
			-- spots, on the back row of its own planted ring between the
			-- corner gravewood and the bench: the one part of a garden plot
			-- that neither the trees, the planters, the bench nor the crates
			-- reach.
			extra_sockets = function(area)
				return {
					plots.work("walk", "sweep", area.x0 + 3, area.oz, 1),
					plots.spare("garth", area.x0 + 4, area.z1 - 1, 2),
				}
			end},
		-- 8. The keepers' watch.
		{id = "vigil_watch", module = "capitals", make = "barracks",
			handle = "crypt", roof = "vault",
			spec = {w = 15, d = 21, wall_h = 5, patrol_group = WATCH,
				order = 8}},
		-- 9. The gravewood copse at the far corner, and a spare.
		{id = "vigil_copse", module = "capitals", make = "grove",
			order = 9,
			spec = {size = 15, kind = "gravewood", height = 7},
			extra_sockets = function(area)
				return {plots.spare("copse", area.x0 + 1, area.z1 - 1, 2)}
			end},
	}

	-- THE DISTRICT'S OWN FILL: the grave fields the vigil keeps, the ruin
	-- close of the contract's "ruins mixed among kept houses", the candle
	-- court and one small close.
	local FILL = {
		-- 1. THE OLD BURIAL GROUND: the larger of the city's two grave fields,
		-- older than the market's -- more of its markers are the two-course
		-- kind and more of its plots have sunk. Two MOURN at the markers, one
		-- PRAYS at the candle standard on the walk, one TENDS the blight bed.
		{id = "vigil_burial_ground", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.graveyard(buf, palette, -9, 2, 9, 10)
				dressing.graveyard(buf, palette, -9, -7, 9, -3)
				for x = -10, 10 do buf:put(x, 0, 0, palette.node("path")) end
				-- Markers set DELIBERATELY on the walk's own row for the two
				-- mourners and the keeper of the vigil, for the reason the
				-- market's grave field records: a socket whose feature is
				-- whatever a hash left is a socket that breaks the day the
				-- hash's phase moves.
				dressing.grave(buf, palette, -6, 1, true)
				dressing.grave(buf, palette, 6, 1, true)
				dressing.grave(buf, palette, 0, 1, false)
				dressing.gravewood(buf, palette, -8, 1, 7)
				dressing.gravewood(buf, palette, 8, 1, 6)
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
				dressing.rubble_heap(buf, palette, -8, 1, 2)
				dressing.counter(buf, palette, -9, -11, 4, "x")
				dressing.crates(buf, palette, 8, -11, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("mourn_west", "mourn", -6, 0, 0),
					plots.work("mourn_east", "mourn", 6, 0, 0),
					plots.work("walk_vigil", "pray", 0, 0, 0),
					plots.work("bed", "tend", 4, -7, 2),
				}
			end},
		--
		-- 2. THE RUIN CLOSE: the contract's "ruins mixed among kept houses",
		-- and the one place in the capital where they are the whole of a lot.
		-- Two of `buildings.ruin`'s half-standing shells with iron bars set in
		-- the gaps and candles burning in them, which is the rest of the
		-- contract's line for this race.
		--
		-- A ruin is stamped here rather than taken as a district plot because
		-- `buildings.ruin` publishes an OPEN room -- `closed = false` -- and a
		-- lot of the grid carries a building somebody keeps. A fill lot is
		-- where the city's own decay belongs.
		{id = "vigil_ruin_close", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				local parts = area.parts
				local buildings = area.buildings
				for _, entry in ipairs({{-9, 1, 0}, {1, 2, 2}}) do
					local ruin = buildings.ruin(palette,
						{w = 9, d = 9, wall_h = 5, phase = entry[3]})
					parts.stamp(buf, ruin, entry[1], 0, entry[2], 0)
				end
				dressing.blight_flora(buf, palette, -10, -5, 10, 10, 7, 2, 2)
				-- The bars and the candle on the standing gable of the west
				-- ruin: a barred window is an `xpanes` flat pane and stands in
				-- the opening on its own, and the candle standard beside it is
				-- the `mourn` feature of section 8.2.
				for y = 2, 3 do
					buf:put(-5, y, 1, palette.node("window"))
				end
				dressing.path_light(buf, palette, -5, -1)
				dressing.path_light(buf, palette, 5, -1)
				-- A MARKER in front of each shell, and a marker rather than
				-- the candle standard beside it, because the sockets
				-- contract's feature search looks one course below, level
				-- with and one above the mourner's FEET -- and a lamp
				-- standard's light is three courses up, behind two courses of
				-- post that stop the search. A grave marker is in the same
				-- `mourn` set and is at the height a marker is.
				dressing.grave(buf, palette, -5, -2, false)
				dressing.grave(buf, palette, 5, -2, true)
				dressing.counter(buf, palette, -9, -11, 4, "x")
				dressing.bench(buf, palette, 2, -11, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("west_candle", "mourn", -5, -3, 0),
					plots.work("east_candle", "mourn", 5, -3, 0),
					plots.spare("ruin_close", 9, -9, 0),
				}
			end},
		-- 3. THE HIGH VIGIL: the candle court of `undead_parts.lua` with two
		-- at its altar.
		{id = "vigil_high_court", module = "undead", make = "candle_court",
			margin = 3, spec = {size = 11},
			extra_sockets = function(area)
				return {
					plots.work("vigil_south", "pray",
						area.ox + 5, area.oz + 3, 0),
					plots.work("vigil_north", "pray",
						area.ox + 5, area.oz + 7, 2),
				}
			end},
		-- 4. THE KEEPERS' CLOSE: a gravewood, a bench, a blight bed and the
		-- district's last spare.
		{id = "vigil_close", yard = {},
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

	M.lore = plots.district({
		key = "nhal_veyr_vigil",
		role = "lore_spiritual",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
