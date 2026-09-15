-- Kezamba's four districts, their fifty-two plots, and where this world puts
-- them.
--
-- `M.resolve(options)` returns the 52 plots in a FIXED order -- district by
-- district in the contract's own role order, each district's building plots in
-- roster order and then its fill plots in roster order -- with the offset from
-- the capital anchor that `kezamba_lots.lua` searched for it.
--
-- THE ORDER DOES NOT DEPEND ON THE SEED AND NEITHER DO THE OFFSETS, which is
-- where Kezamba differs from Highcourt and why. `highcourt_districts.lua`
-- permutes its four districts between four interchangeable quadrants with the
-- world seed; Kezamba's quadrants are not interchangeable, because WP40's
-- authored cenote fills one of them in every world
-- (`tools/wp13/kezamba_water.lua`, nine seeds, one wet mask). A permutation
-- over ground like that would put a district in the lake three times out of
-- four. So the districts are pinned, and `options` is read only to refuse a
-- half seam -- exactly as `r7_dur_brannoc_blueprint.lua` refuses one.
--
-- WHAT EACH DISTRICT IS, against the contract's section 2.1 roles:
--
--   * `shore`  (market and professions), south-east: the cauldron market, the
--     butcher, the tailor, the brewer, the carvers' yard and the stores.
--   * `vine`   (residential and cultural), south-west: longhouses and cottages
--     on their own garden terraces, with the herbalist among them.
--   * `canopy` (martial and garrison), west and north-west: two barracks, the
--     drill ground, the armourer, the wood yard and the remount pasture.
--   * `totem`  (lore and spiritual), on the lake's far bank: the scriptorium,
--     the carvers of the ancestor posts, the burial ground and the groves.
--
-- WORK SOCKETS AND THE 80/20 RULE. The sockets contract's section 8.3 asks a
-- structure lane for at least one `idle` spawn socket per `work` socket, so
-- that the NPC lane's "every fifth idle spawn socket walks" yields a walker
-- share inside 10-30 %. Every roster row below is written to that: a plot with
-- two workplaces carries two flair spots, and the district totals are asserted
-- by `tools/wp13/kezamba_kat.lua` rather than counted by eye.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plot = dofile(directory .. "/kezamba_plot.lua")(directory)
	local lots = dofile(directory .. "/kezamba_lots.lua")()

	local M = {}

	M.lots = lots

	local work, vendor, spare, guard_post =
		plot.work, plot.vendor, plot.spare, plot.guard_post

	-- ------------------------------------------------------------------
	-- shared dressings
	-- ------------------------------------------------------------------

	-- A yard's FORECOURT is its three rows nearest the street (`z0`..`z0 + 2`):
	-- the gate path, the two lamps, the props a socket faces and the sockets
	-- themselves. Everything from `z0 + 3` inwards is the FEATURE, and nothing
	-- authored there may land on a standing position -- ground cover scattered
	-- by a position hash in a socket's feet cell is a socket with no headroom.
	-- That is the Highcourt fill's rule and it is repeated here because it is
	-- what makes a work socket's "feature under `dir` within three nodes"
	-- reliable: the worker stands on `z0 + 2` and looks into `z0 + 3`.
	local function crop_field(buf, palette, area)
		area.dressing.crop_rows(buf, palette, area.x0 + 1, area.z0 + 3,
			area.x1 - 1, area.z1 - 1, "x")
	end
	local function vine_terrace(buf, palette, area)
		for z = area.z0 + 3, area.z1 - 1, 3 do
			area.dressing.planter(buf, palette, area.x0 + 1, z, area.x1 - 1, z)
		end
		area.dressing.plant(buf, palette, area.x0 + 2, area.z0 + 3)
		area.dressing.plant(buf, palette, area.x1 - 2, area.z0 + 3)
	end
	local function log_yard(buf, palette, area)
		for z = area.z0 + 3, area.z1 - 2, 3 do
			area.dressing.wood_pile(buf, palette, area.x0 + 1, z,
				math.min(5, area.x1 - area.x0 - 2), "x")
		end
	end
	local function green(buf, palette, area)
		area.dressing.bench(buf, palette, area.x0 + 2, area.z0 + 3, 0, 3, "x")
		area.dressing.bench(buf, palette, area.x1 - 4, area.z0 + 3, 0, 3, "x")
		area.dressing.basin_flora(buf, palette, area.x0 + 1, area.z0 + 4,
			area.x1 - 1, area.z1 - 1)
	end
	local function grove(buf, palette, area)
		for z = area.z0 + 4, area.z1 - 3, 5 do
			for x = area.x0 + 3, area.x1 - 3, 5 do
				area.dressing.jungle_tree(buf, palette, x, z, 7)
			end
		end
		-- Two sprigs on the feature row, AUTHORED rather than scattered. A
		-- forager's socket has to face something the contract calls a plant
		-- within three nodes, and a jungle tree gives it a log at that range
		-- and its leaves ten courses up -- neither of which is a thing to
		-- forage. A hash scatter would be right on average and wrong at the
		-- one cell the socket looks at.
		area.dressing.plant(buf, palette, area.x0 + 2, area.z0 + 3)
		area.dressing.plant(buf, palette, area.x1 - 2, area.z0 + 3)
	end
	-- A PASTURE: two sprigs on the feature row for the herder to look at, cover
	-- behind them and a rail along the back. The sprigs are authored and not
	-- scattered for the reason the grove's are: a socket's rule is about one
	-- cell, and a hash is right on average.
	local function pasture(buf, palette, area)
		area.dressing.plant(buf, palette, area.x0 + 3, area.z0 + 3)
		area.dressing.plant(buf, palette, area.x1 - 3, area.z0 + 3)
		area.dressing.basin_flora(buf, palette, area.x0 + 1, area.z0 + 4,
			area.x1 - 1, area.z1 - 1)
		area.dressing.fence_line(buf, palette, area.x0 + 1, area.z1 - 1,
			area.x1 - 1, area.z1 - 1)
	end

	local function drill_ground(buf, palette, area)
		for _, spot in ipairs({{area.x0 + 3, area.z0 + 4},
				{area.x1 - 3, area.z0 + 4}}) do
			area.dressing.drill_post(buf, palette, spot[1], spot[2], 3)
		end
		area.dressing.standard(buf, palette, area.x0 + 2, area.z0 + 3, 4)
	end
	local function burial_ground(buf, palette, area)
		area.dressing.graveyard(buf, palette, area.x0 + 1, area.z0 + 3,
			area.x1 - 1, area.z1 - 1)
		-- The sexton's own sprig, on the feature row and AFTER the markers, so
		-- the gardener of this ground has a plant to face and not a headstone.
		area.dressing.plant(buf, palette, area.x1 - 3, area.z0 + 3)
	end
	local function totem_row(buf, palette, area)
		for x = area.x0 + 3, area.x1 - 3, 4 do
			area.dressing.totem(buf, palette, x, area.z0 + 4, 5)
		end
	end
	local function racks(buf, palette, area)
		for x = area.x0 + 2, area.x1 - 2, 4 do
			area.dressing.drying_rack(buf, palette, x, area.z0 + 3, 4, "z")
		end
	end

	-- A shopfront: a four-node trestle counter on the street row of the plot's
	-- own ring, clear of the two corner lamps and of the doorstep path, with the
	-- vendor outside it looking at it. `stall`'s feature rule is "a counter (any
	-- solid node at waist height)", which is exactly what this is.
	local function shopfront(buf, palette, area)
		area.dressing.counter(buf, palette, area.x0 + 3, area.z0 + 2, 4, "x")
	end

	-- ------------------------------------------------------------------
	-- 1. shore -- the market and professions quarter
	-- ------------------------------------------------------------------

	local SHORE = "kezamba_shore_watch"
	local shore = {
		key = "shore", role = "market_trades", patrol_group = SHORE,
		plots = {
			{id = "shore_market", module = "troll", make = "cauldron_court",
				order = 1, spec = {size = 15},
				extra_sockets = function(area)
					return {vendor("brewer", "brewer", area.x0 + 2, area.z0 + 2, 0),
						spare("market", area.x1 - 2, area.z0 + 2, 0)}
				end},
			{id = "shore_butcher", module = "buildings", make = "workshop",
				order = 2, turns = 3,
				spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
					door_index = 6, infill = true},
				decorate = function(buf, palette, area)
					shopfront(buf, palette, area)
					area.dressing.wood_pile(buf, palette, area.x0 + 1,
						area.z0 + 2, 3, "x")
				end,
				extra_sockets = function(area)
					return {vendor("butcher", "butcher", area.x0 + 4,
							area.z0 + 1, 0),
						work("butcher_block", "chop", area.x0 + 1,
							area.z0 + 1, 0)}
				end},
			{id = "shore_tailor", module = "buildings", make = "cottage",
				order = 3, turns = 1,
				spec = {w = 11, d = 11, wall_h = 5, roof = "gable",
					ridge_axis = "x", infill = true, shutters = true},
				decorate = function(buf, palette, area)
					shopfront(buf, palette, area)
					area.dressing.bench(buf, palette, area.x0 + 1, area.z0 + 3,
						0, 3, "x")
				end,
				extra_sockets = function(area)
					return {vendor("tailor", "tailor", area.x0 + 4,
							area.z0 + 1, 0),
						work("tailor_bench", "sit", area.x0 + 2, area.z0 + 3,
							0, {"bench"}, 2)}
				end},
			{id = "shore_store", module = "capitals", make = "granary",
				order = 4, spec = {w = 11, d = 15, wall_h = 5},
				extra_sockets = function(area)
					return {spare("store", area.x1 - 2, area.z0 + 2, 0)}
				end},
			-- THE SMOKER'S ACTIVITY IS `stall`, and the reason is the one the
			-- Highcourt fill wrote down about its baker: the closed vocabulary
			-- of section 8.2 has no word for curing fish. The nearest
			-- candidates are worse than honest: `tend`'s feature is a plant and
			-- a drying rack is not one, and `chop`'s is a log -- the rack IS
			-- posts and a beam, so a `chop` socket here would PASS its own rule
			-- while naming a man with an axe at a fish rack. `stall` is "a
			-- counter (any solid node at waist height)", the smokehouse has
			-- one, and that is the reading that is true of what stands there.
			-- A later package that wants a curer adds `cure` to section 8.2.
			{id = "shore_smokehouse", module = "buildings", make = "shed",
				order = 5,
				spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}},
				decorate = function(buf, palette, area)
					racks(buf, palette, area)
					shopfront(buf, palette, area)
				end,
				extra_sockets = function(area)
					return {work("smoke_counter", "stall", area.x0 + 4,
							area.z0 + 1, 0),
						{id = "smoke_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 1, face = 0, tags = {"work"}}}
				end},
			{id = "shore_carvers", module = "troll", make = "carver_yard",
				order = 6, spec = {size = 15}},
			{id = "shore_well", module = "capitals", make = "well_court",
				order = 7, spec = {size = 11}, margin = 4, garden = true},
			{id = "shore_watch", module = "capitals", make = "barracks",
				order = 8, spec = {w = 15, d = 21, wall_h = 5,
					patrol_group = SHORE, order = 9},
				extra_sockets = function(area)
					return {guard_post("shore_gate", area.x0 + 2,
						area.z0 + 2, 0)}
				end},
			{id = "shore_house", module = "buildings", make = "longhouse",
				order = 10,
				spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
					door_index = 4, infill = true}},
		},
		fill = {
			{id = "shore_vineyard", yard = {}, order = 11,
				decorate = vine_terrace,
				extra_sockets = function(area)
					return {work("vine_a", "tend", area.x0 + 3, area.z0 + 2, 0),
						work("vine_b", "forage", area.x1 - 2, area.z0 + 2, 0),
						{id = "vine_idle", role = "idle", x = area.x0 + 1,
							z = area.z0 + 2, face = 0, tags = {"work"}},
						spare("vineyard", area.x1 - 1, area.z0 + 2, 0)}
				end},
			{id = "shore_gardens", yard = {}, order = 12, decorate = crop_field,
				extra_sockets = function(area)
					return {work("garden_a", "farm", area.x0 + 3,
							area.z0 + 2, 0),
						work("garden_b", "farm", area.x1 - 3, area.z0 + 2, 0),
						{id = "garden_idle", role = "idle", x = area.x0 + 1,
							z = area.z0 + 2, face = 0, tags = {"work"}},
						{id = "garden_idle_b", role = "idle", x = area.x1 - 1,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "shore_logyard", yard = {}, order = 13, decorate = log_yard,
				extra_sockets = function(area)
					return {work("log_a", "chop", area.x0 + 2, area.z0 + 2, 0),
						{id = "log_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "shore_green", yard = {}, order = 14, decorate = green,
				extra_sockets = function(area)
					return {work("green_sit", "sit", area.x0 + 3,
							area.z0 + 3, 0, {"bench"}, 2),
						{id = "green_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"bench"}}}
				end},
		},
	}

	-- ------------------------------------------------------------------
	-- 2. vine -- the residential and cultural quarter
	-- ------------------------------------------------------------------

	local VINE = "kezamba_vine_watch"
	local function cottage(id, order, roof, axis, extra)
		local row = {id = id, module = "buildings", make = "cottage",
			order = order, turns = 1,
			spec = {w = 11, d = 11, wall_h = 5, roof = roof, ridge_axis = axis,
				infill = true, shutters = true}}
		for key, value in pairs(extra or {}) do row[key] = value end
		return row
	end

	local vine = {
		key = "vine", role = "residential_cultural", patrol_group = VINE,
		plots = {
			cottage("vine_house_a", 1, "gable", "x"),
			cottage("vine_house_b", 2, "hip", "x"),
			cottage("vine_house_c", 3, "saltbox", "x"),
			cottage("vine_house_d", 4, "gable", "z"),
			{id = "vine_longhouse", module = "buildings", make = "longhouse",
				order = 5,
				spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
					door_index = 4, infill = true},
				extra_sockets = function(area)
					return {spare("longhouse", area.x1 - 2, area.z0 + 2, 0)}
				end},
			{id = "vine_herbalist", module = "buildings", make = "cottage",
				order = 6, turns = 1,
				spec = {w = 11, d = 11, wall_h = 5, roof = "hip",
					infill = true, shutters = true},
				decorate = function(buf, palette, area)
					shopfront(buf, palette, area)
					area.dressing.flower_bed(buf, palette, area.x0 + 1,
						area.z1 - 4, area.x1 - 1, area.z1 - 1)
				end,
				extra_sockets = function(area)
					return {vendor("herbalist", "herbalist", area.x0 + 4,
							area.z0 + 1, 0),
						work("physic", "tend", area.x0 + 2, area.z1 - 5, 0)}
				end},
			{id = "vine_moot", module = "capitals", make = "colonnade",
				order = 7, spec = {len = 15, patrol_group = VINE, order = 8},
				-- A colonnade is a roof on pillars and has nothing to sit on,
				-- so the bench comes with the plot. `sit` sits ON the seat --
				-- a seat is a walkable node -- which is why the socket is at
				-- y = 2.
				decorate = function(buf, palette, area)
					area.dressing.bench(buf, palette, area.x0 + 2,
						area.z0 + 2, 0, 3, "x")
				end,
				extra_sockets = function(area)
					return {work("moot_sit", "sit", area.x0 + 3, area.z0 + 2,
						0, {"bench"}, 2)}
				end},
			{id = "vine_well", module = "capitals", make = "well_court",
				order = 9, spec = {size = 11}, margin = 4, garden = true},
			{id = "vine_store", module = "capitals", make = "granary",
				order = 10, spec = {w = 11, d = 15, wall_h = 5}},
		},
		fill = {
			{id = "vine_common", yard = {}, order = 11, decorate = crop_field,
				extra_sockets = function(area)
					return {work("common_a", "farm", area.x0 + 3,
							area.z0 + 2, 0),
						work("common_b", "farm", area.x1 - 3, area.z0 + 2, 0),
						{id = "common_idle", role = "idle", x = area.x0 + 1,
							z = area.z0 + 2, face = 0, tags = {"work"}},
						{id = "common_idle_b", role = "idle", x = area.x1 - 1,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "vine_terraces", yard = {}, order = 12,
				decorate = vine_terrace,
				extra_sockets = function(area)
					return {work("terrace_a", "tend", area.x0 + 3,
							area.z0 + 2, 0),
						work("terrace_b", "forage", area.x1 - 2,
							area.z0 + 2, 0),
						{id = "terrace_idle", role = "idle", x = area.x0 + 1,
							z = area.z0 + 2, face = 0, tags = {"work"}},
						spare("terraces", area.x1 - 1, area.z0 + 2, 0)}
				end},
			{id = "vine_park", yard = {}, order = 13, decorate = green,
				extra_sockets = function(area)
					return {work("park_sit", "sit", area.x0 + 3, area.z0 + 3,
							0, {"bench"}, 2),
						{id = "park_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"bench"}}}
				end},
			{id = "vine_kitchen", yard = {}, order = 14, decorate = crop_field,
				extra_sockets = function(area)
					return {work("kitchen", "farm", area.x0 + 2,
							area.z0 + 2, 0),
						{id = "kitchen_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
		},
	}

	-- ------------------------------------------------------------------
	-- 3. canopy -- the martial and garrison quarter
	-- ------------------------------------------------------------------

	local CANOPY = "kezamba_canopy_watch"
	local canopy = {
		key = "canopy", role = "martial_garrison", patrol_group = CANOPY,
		plots = {
			{id = "canopy_barracks_a", module = "capitals", make = "barracks",
				order = 1, spec = {w = 15, d = 21, wall_h = 5,
					patrol_group = CANOPY, order = 12},
				extra_sockets = function(area)
					return {guard_post("canopy_a", area.x0 + 2, area.z0 + 2, 0)}
				end},
			{id = "canopy_barracks_b", module = "capitals", make = "barracks",
				order = 2, spec = {w = 15, d = 21, wall_h = 5,
					patrol_group = CANOPY, order = 13},
				extra_sockets = function(area)
					return {guard_post("canopy_b", area.x0 + 2, area.z0 + 2, 0)}
				end},
			{id = "canopy_armoury", module = "buildings", make = "workshop",
				order = 3, turns = 3,
				spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
					door_index = 6, infill = true},
				decorate = function(buf, palette, area)
					shopfront(buf, palette, area)
					-- The anvil stands on the FEATURE row, z0 + 3, like every
					-- other feature in this capital: the worker stands on
					-- z0 + 2 and looks into it.
					buf:put(area.x0 + 1, 1, area.z0 + 3,
						palette.node("workbench"))
				end,
				extra_sockets = function(area)
					return {work("anvil", "smith", area.x0 + 1, area.z0 + 2, 0),
						{id = "armoury_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "canopy_watchpost", module = "buildings", make = "watchpost",
				order = 4, spec = {w = 9, d = 9, wall_h = 5},
				extra_sockets = function(area)
					return {guard_post("canopy_tower", area.x0 + 2,
						area.z0 + 2, 0)}
				end},
			{id = "canopy_stable", module = "capitals", make = "stable",
				order = 5, spec = {w = 15, d = 11, wall_h = 5}},
			{id = "canopy_store", module = "capitals", make = "granary",
				order = 6, spec = {w = 11, d = 15, wall_h = 5}},
			{id = "canopy_hall", module = "buildings", make = "longhouse",
				order = 7,
				spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
					door_index = 4, infill = true},
				extra_sockets = function(area)
					return {spare("canopy_hall", area.x1 - 2, area.z0 + 2, 0)}
				end},
			cottage("canopy_house_a", 8, "gable", "x"),
			cottage("canopy_house_b", 9, "hip", "x"),
			{id = "canopy_carvers", module = "troll", make = "carver_yard",
				order = 10, spec = {size = 15}},
			{id = "canopy_well", module = "capitals", make = "well_court",
				order = 11, spec = {size = 11}, margin = 4, garden = true},
		},
		fill = {
			{id = "canopy_muster", yard = {}, order = 14,
				decorate = drill_ground,
				extra_sockets = function(area)
					-- `spar` wants "another `spar` socket or a training dummy
					-- (a fence post or a wool node)" under `dir` within three
					-- nodes, and `dressing.drill_post` plants exactly the fence
					-- post the rule names. The two stand facing their own post.
					return {work("spar_a", "spar", area.x0 + 3, area.z0 + 2, 0),
						work("spar_b", "spar", area.x1 - 3, area.z0 + 2, 0),
						{id = "muster_idle", role = "idle", x = area.x0 + 1,
							z = area.z0 + 2, face = 0, tags = {"work"}},
						{id = "muster_idle_b", role = "idle", x = area.x1 - 1,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "canopy_pasture", yard = {}, order = 15, decorate = pasture,
				extra_sockets = function(area)
					return {work("pasture", "tend", area.x0 + 3,
							area.z0 + 2, 0),
						{id = "pasture_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "canopy_woodyard", yard = {}, order = 16, decorate = log_yard,
				extra_sockets = function(area)
					return {work("wood_a", "chop", area.x0 + 2, area.z0 + 2, 0),
						{id = "wood_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "canopy_green", yard = {}, order = 17, decorate = green,
				extra_sockets = function(area)
					return {work("guard_sit", "sit", area.x0 + 3, area.z0 + 3,
							0, {"bench"}, 2),
						spare("canopy_green", area.x1 - 2, area.z0 + 2, 0)}
				end},
		},
	}

	-- ------------------------------------------------------------------
	-- 4. totem -- the lore and spiritual quarter, on the far bank
	-- ------------------------------------------------------------------

	local TOTEM = "kezamba_totem_watch"
	local totem = {
		key = "totem", role = "lore_spiritual", patrol_group = TOTEM,
		plots = {
			{id = "totem_scriptorium", module = "capitals",
				make = "scriptorium", order = 1,
				spec = {w = 13, d = 17, wall_h = 6},
				extra_sockets = function(area)
					return {spare("scriptorium", area.x1 - 2, area.z0 + 2, 0)}
				end},
			{id = "totem_carvers", module = "troll", make = "carver_yard",
				order = 2, spec = {size = 15}},
			{id = "totem_shrine", module = "capitals", make = "temple",
				order = 3, spec = {w = 13, d = 19, wall_h = 7, rise = 5},
				-- A CAPITAL HAS EXACTLY ONE QUEST SHELL and the core's shrine
				-- carries it (`wp13/kezamba.lua`), so the temple's own is
				-- dropped here rather than the shared generator being edited.
				drop = {quest = true},
				-- THE ALTAR IS THE PLOT'S AND NOT THE GENERATOR'S. `pray`'s
				-- feature rule is "an altar, a candle or a grave marker" and it
				-- is answered OUTSIDE, because every socket stands outside a
				-- room; `capitals.temple` furnishes its nave and puts nothing
				-- on its doorstep. So the plot sets a basalt altar stone on the
				-- feature row with a flame on it, and the shaman stands one
				-- node in front of it.
				decorate = function(buf, palette, area)
					buf:put(area.x0 + 2, 1, area.z0 + 3,
						palette.maybe("signature") or palette.node("foundation"))
					area.parts.floor_torch(buf, palette, area.x0 + 2, 2,
						area.z0 + 3)
				end,
				extra_sockets = function(area)
					return {work("shrine_pray", "pray", area.x0 + 2,
						area.z0 + 2, 0)}
				end},
			{id = "totem_hall", module = "buildings", make = "longhouse",
				order = 4,
				spec = {w = 11, d = 15, wall_h = 5, door_side = "z-",
					door_index = 4, infill = true}},
			cottage("totem_house_a", 5, "gable", "x"),
			{id = "totem_store", module = "capitals", make = "granary",
				order = 6, spec = {w = 11, d = 15, wall_h = 5}},
			{id = "totem_well", module = "capitals", make = "well_court",
				order = 7, spec = {size = 11}, margin = 4, garden = true},
		},
		fill = {
			{id = "totem_graves", yard = {}, order = 8,
				decorate = burial_ground,
				extra_sockets = function(area)
					-- `mourn` wants "a grave marker, a coffin or a candle"
					-- under `dir` within three nodes, and `dressing.graveyard`
					-- plants its markers from `area.z0 + 3` inward.
					return {work("mourn_a", "mourn", area.x0 + 3,
							area.z0 + 2, 0),
						work("tend_graves", "tend", area.x1 - 3,
							area.z0 + 2, 0),
						{id = "graves_idle", role = "idle", x = area.x0 + 1,
							z = area.z0 + 2, face = 0, tags = {"work"}},
						{id = "graves_idle_b", role = "idle", x = area.x1 - 1,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "totem_posts", yard = {}, order = 9, decorate = totem_row,
				extra_sockets = function(area)
					return {work("post_carve", "carve", area.x0 + 3,
							area.z0 + 3, 0),
						{id = "posts_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"work"}}}
				end},
			{id = "totem_grove", yard = {}, order = 10, decorate = grove,
				extra_sockets = function(area)
					return {work("grove_forage", "forage", area.x0 + 2,
							area.z0 + 2, 0),
						spare("grove", area.x1 - 2, area.z0 + 2, 0)}
				end},
			{id = "totem_green", yard = {}, order = 11, decorate = green,
				extra_sockets = function(area)
					return {work("quiet_sit", "sit", area.x0 + 3, area.z0 + 3,
							0, {"bench"}, 2),
						{id = "quiet_idle", role = "idle", x = area.x1 - 2,
							z = area.z0 + 2, face = 0, tags = {"bench"}}}
				end},
		},
	}

	-- ------------------------------------------------------------------
	-- the seam
	-- ------------------------------------------------------------------

	M.definitions = {shore, vine, canopy, totem}

	do
		local roles = lots.ROLES
		if #M.definitions ~= #roles then
			error("wp13 kezamba: district roster differs", 0)
		end
		for index = 1, #roles do
			if M.definitions[index].role ~= roles[index] then
				error("wp13 kezamba: district " .. index .. " is not " ..
					roles[index], 0)
			end
		end
	end

	local built
	local function districts()
		if built then return built end
		built = {}
		for index = 1, #M.definitions do
			local definition = M.definitions[index]
			local plots, fill = lots.of(definition.key)
			built[index] = plot.district(definition, plots, fill)
		end
		return built
	end
	M.districts = districts

	-- `options` is the seam `r7_runtime.lua` hands every blueprint source. This
	-- capital reads NEITHER field -- its districts are pinned to the ground and
	-- not permuted by the seed -- but it refuses a HALF seam rather than
	-- shrugging at it: a caller that passes one field and not the other has a
	-- defect upstream, and the day this capital grows a seeded assignment the
	-- refusal is already where it belongs.
	function M.check_options(options)
		if options == nil then return end
		if type(options) ~= "table" then
			error("wp13 kezamba: the blueprint options differ", 0)
		end
		if options.full_seed == nil and options.raw_sha256 == nil then return end
		if type(options.full_seed) ~= "string" or
				not options.full_seed:match("^%-?%d+$") or
				type(options.raw_sha256) ~= "function" then
			error("wp13 kezamba: the blueprint seam differs", 0)
		end
	end

	function M.resolve(options)
		M.check_options(options)
		local list = {}
		for index = 1, #M.definitions do
			local district = districts()[index]
			local plots, fill = lots.of(district.key)
			local function append(rows, available, kind)
				for row = 1, #rows do
					list[#list + 1] = {
						id = rows[row].id,
						district = district.key,
						role = district.role,
						kind = kind,
						lot = row,
						x = available[row].x,
						z = available[row].z,
						reach = available[row].reach,
						build = rows[row].build,
					}
				end
			end
			append(district.plots, plots, "plot")
			append(district.fill, fill, "fill")
		end
		return list
	end

	return M
end

return loader
