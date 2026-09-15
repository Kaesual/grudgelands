-- Gor Drazhak, the BONE HALLS: the lore and spiritual district, nine
-- terrain-relative plots and four fill lots.
--
-- The contract's third district role. What the human capital keeps in a chapel
-- and a library an orc city keeps in a spirit hall, a totem court and a barrow:
-- this district carries the capital's SECOND quest shell (the temple generator
-- publishes it), the `mourn` and `pray` activities of the sockets contract, the
-- `carve` of the totem cutters, and the `mine` of the quarry that the mesa
-- itself is -- the one activity in the wave-2 vocabulary that needs a rock face
-- and the one no other capital has a rock face for.
--
-- No vendors: the professions are the bazaar's. The herbalist's stock would be
-- an eighth vendor kind and the capital already carries seven, which is the
-- whole of `grug_traders`' wave-2 roster.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/gor_drazhak_plot.lua")(directory)

	local M = {}

	local WATCH = "gor_drazhak_bone_watch"

	local PLOTS = {
		-- 1. THE SPIRIT HALL: the district's tallest plot and the carrier of
		-- this capital's second quest shell, which `capitals.temple` publishes
		-- three nodes inside its own door. The user's playtest-round-2 ruling
		-- is that the elder stands ON THE DOORSTEP and shows the street his
		-- face, so this plot moves the shell one node outside the door and tags
		-- it `door`, which is what turns an NPC round
		-- (`grug_mobs/start_npcs.lua`, `socket_face_yaw`).
		{id = "bone_spirit_hall", module = "capitals", make = "temple",
			order = 1, handle = "ors",
			spec = {w = 13, d = 19, wall_h = 7, rise = 5},
			-- ONE NODE IN FROM THE PLOT EDGE, not two. A plot's ground
			-- rectangle is the part's own extent grown by the margin, so
			-- `x0 + 2` is exactly the column the part's EAVE stands in: a totem
			-- there caps itself with a roof slab under the temple's own roof
			-- stair, which is a bottom slab carrying masonry and the one shape
			-- rule this library has held every composition to since round A.
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.totem(buf, palette, area.x0 + 1, area.z0 + 3, 5)
				dressing.totem(buf, palette, area.x1 - 1, area.z0 + 3, 5)
			end,
			socket_overrides = function(area)
				return {bone_spirit_hall_quest = {x = 0, z = area.oz - 1,
					face = 0, tags = {"door"}}}
			end,
			extra_sockets = function(area)
				return {
					plots.work("hall_pray", "pray", 0, area.oz - 2, 0),
					plots.idle("hall_step", -2, area.oz - 1, 2, {"door"}),
				}
			end},

		-- 2. THE TOTEM COURT: the piece that says orc from the lane. A paved
		-- square with nine posts on it, the tallest in the middle, and the two
		-- carvers who keep them.
		{id = "bone_totem_court", yard = {w = 12, d = 12}, order = 2,
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.inlay(buf, palette, -9, -9, 9, 9, "plaza_edge")
				for z = -8, 8 do
					for x = -8, 8 do
						buf:put(x, 0, z, palette.node("plaza"))
					end
				end
				dressing.totem(buf, palette, 0, 0, 7)
				for _, post in ipairs({{-6, -6}, {0, -6}, {6, -6},
						{-6, 0}, {6, 0}, {-6, 6}, {0, 6}, {6, 6}}) do
					dressing.totem(buf, palette, post[1], post[2], 5)
				end
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
				dressing.bench(buf, palette, 1, 10, 2, 3, "x")
				for _, lamp in ipairs({{-9, -9}, {9, -9}, {-9, 9}, {9, 9}}) do
					dressing.path_light(buf, palette, lamp[1], lamp[2])
				end
			end,
			extra_sockets = function()
				return {
					plots.work("totem_carve_west", "carve", -5, -6, 3),
					plots.idle("totem_carve_east", 5, 6, 1, {"work"}),
					plots.idle("totem_pray", 0, -2, 2, {"work"}),
					plots.idle("totem_bench", -2, -10, 0, {"bench"}, 2),
					plots.spare("totem_court", 8, -8, 0),
				}
			end},

		-- 3. THE BARROW: the burial ground, sunk behind a low wall with the
		-- markers in rows and one who stands among them. `mourn` is the
		-- vocabulary's word and a grave marker its feature.
		{id = "bone_barrow", yard = {}, order = 3,
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.low_wall_line(buf, palette, -11, -6, 11, -6)
				dressing.low_wall_line(buf, palette, -11, 11, 11, 11)
				dressing.low_wall_line(buf, palette, -11, -6, -11, 11)
				dressing.low_wall_line(buf, palette, 11, -6, 11, 11)
				for x = -1, 1 do buf:put(x, 1, -6, palette.node("path")) end
				dressing.graveyard(buf, palette, -9, -4, 9, 9)
				dressing.totem(buf, palette, -9, -8, 5)
				dressing.totem(buf, palette, 9, -8, 5)
				dressing.undergrowth(buf, palette, -10, -4, 10, 9, 7)
			end,
			extra_sockets = function()
				return {
					plots.work("barrow_mourn", "mourn", 0, -4, 2),
					plots.idle("barrow_keep", -6, -4, 2, {"work"}),
					plots.work("barrow_pray", "pray", 6, -4, 2),
					plots.spare("barrow", 0, -9, 2),
				}
			end},

		-- 4. THE QUARRY FACE: the mesa itself, cut back into the lot as a
		-- stepped rock shelf. `mine` is the only wave-2 activity that needs a
		-- rock face at head height, and this is the only lot in the game that
		-- has one that a composition authored rather than a mapgen left behind.
		{id = "bone_quarry", yard = {}, order = 4,
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				-- Three terraces stepped back from the lane, each one solid
				-- rock capped with its own scree, so the face a miner swings at
				-- is four courses of stone and not a wall with a hole in it.
				dressing.rock_terrace(buf, palette, -11, 2, 11, 5, 3)
				dressing.rock_terrace(buf, palette, -11, 6, 11, 8, 6)
				dressing.rock_terrace(buf, palette, -11, 9, 11, 11, 9)
				dressing.rubble_heap(buf, palette, -7, -3, 3)
				dressing.rubble_heap(buf, palette, 6, -4, 2)
				dressing.handcart(buf, palette, -2, -7, "x")
				dressing.crates(buf, palette, 9, -7, 0)
				dressing.wood_pile(buf, palette, -10, -8, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("quarry_face_west", "mine", -6, 1, 0),
					plots.work("quarry_face_east", "mine", 5, 1, 0),
					plots.work("quarry_haul", "sweep", -2, -6, 0),
					plots.idle("quarry_saw", -9, -6, 0, {"work"}),
				}
			end},

		-- 5. THE BONE READER'S HALL: the library of this race, which keeps its
		-- record in carved bone rather than in books. The scriptorium generator
		-- publishes the two desk spots.
		{id = "bone_reader_hall", module = "capitals", make = "scriptorium",
			order = 5, handle = "ors",
			spec = {w = 13, d = 17, wall_h = 6},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.totem(buf, palette, area.x0 + 2, area.z1 - 2, 4)
				dressing.bench(buf, palette, area.x1 - 5, area.z1 - 2, 2, 3,
					"x")
			end,
			extra_sockets = function(area)
				return {
					plots.work("reader_carve", "carve", area.x0 + 3,
						area.z1 - 2, 3),
				}
			end},

		-- 6. THE HERB HOUSE: the healer's, with the beds of dry-country
		-- planting she keeps outside her door.
		{id = "bone_herb_house", module = "buildings", make = "cottage",
			order = 6, margin = 4,
			parapet = {y = 6},
			spec = {w = 9, d = 11, wall_h = 4, roof = "flat_deck",
				infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.planter(buf, palette, area.x0 + 1, area.z1 - 3,
					area.x0 + 3, area.z1 - 1)
				dressing.planter(buf, palette, area.x1 - 3, area.z1 - 3,
					area.x1 - 1, area.z1 - 1)
				-- No `dressing.plant` over the beds: `dressing.planter` ALREADY
				-- sows every cell inside its own kerb -- soil at the ground
				-- course and a tuft or a fern above it -- so a second call there
				-- overwrites the soil with a tuft and leaves the first one
				-- standing on a plant, which is an attached node with no
				-- support.
				dressing.crates(buf, palette, area.x1 - 2, area.z0 + 3, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("herb_tend_west", "tend", area.x0 + 2,
						area.z1 - 4, 0),
					plots.idle("herb_tend_east", area.x1 - 2,
						area.z1 - 4, 2, {"work"}),
				}
			end},

		-- 7. THE ANCESTOR STORE: where the bones and the trophies are kept.
		{id = "bone_store", module = "capitals", make = "granary",
			order = 7, handle = "ors",
			spec = {w = 11, d = 15, wall_h = 5},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.totem(buf, palette, area.x0 + 2, area.z1 - 2, 4)
				dressing.crates(buf, palette, area.x1 - 2, area.z1 - 2, 2)
			end,
			extra_sockets = function(area)
				return {
					plots.idle("bone_store_carve", area.x0 + 3,
						area.z1 - 2, 3, {"work"}),
				}
			end},

		-- 8. THE SHAMAN'S HOUSE.
		{id = "bone_shaman_house", module = "buildings", make = "cottage",
			order = 8,
			parapet = {y = 6},
			spec = {w = 11, d = 9, wall_h = 4, roof = "flat_deck",
				infill = true, fancy_bed = true},
			-- Clear of the deck ring for the same reason the spirit hall's
			-- totems are clear of the temple's eave: the breastwork stands on
			-- the column at `x1 - 2`, and it is written BEFORE the dressing.
			decorate = function(buf, palette, area)
				area.dressing.totem(buf, palette, area.x1 - 1, area.z1 - 4, 4)
			end,
			extra_sockets = function(area)
				return {
					plots.idle("shaman_step", area.x0 + 3, area.z1 - 2, 2,
						{"door"}),
					plots.spare("shaman", area.x0 + 2, area.z0 + 2, 0),
				}
			end},

		-- 9. THE ASH COURT: a well court with the cistern in it instead of a
		-- pond, because a mesa shelf has no standing water anywhere in its
		-- envelope -- measured on three worlds, section 1 of
		-- `gor_drazhak_quadrants.lua` -- and a city on one keeps its water in
		-- a tank.
		{id = "bone_ash_court", module = "capitals", make = "well_court",
			order = 9, spec = {size = 11},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.totem(buf, palette, area.x0 + 2, area.z0 + 2, 4)
				dressing.bench(buf, palette, area.x1 - 5, area.z1 - 2, 2, 3,
					"x")
			end,
			extra_sockets = function(area)
				return {
					plots.idle("ash_seat", area.x1 - 4, area.z1 - 2, 0,
						{"bench"}, 2),
				}
			end},
	}

	-- THE DISTRICT'S OWN FILL. A spirit quarter's open ground is the ground the
	-- dead and the growing things are given.
	local FILL = {
		-- 1. THE ANCESTOR FIELD: the older burial ground outside the barrow
		-- wall, with the shrubs grown back over half of it.
		{id = "bone_ancestor_field", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.low_wall_line(buf, palette, -11, 11, 11, 11)
				dressing.graveyard(buf, palette, -9, -4, 9, 9)
				dressing.grave(buf, palette, -2, -4, true)
				dressing.undergrowth(buf, palette, -10, -8, 10, 10, 4)
				dressing.totem(buf, palette, 0, -8, 5)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("ancestor_mourn", "mourn", -2, -6, 0),
					plots.idle("ancestor_forage", 6, -6, 2, {"work"}),
					plots.spare("ancestor_field", 9, -9, 0),
				}
			end},

		-- 2. THE SCRUB GARDEN: the dry-country planting the herb house draws
		-- on, in beds under a rail.
		{id = "bone_scrub_garden", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.fence_line(buf, palette, -11, 11, 11, 11)
				for _, bed in ipairs({{-9, -2, -5, 2}, {-3, -2, 1, 2},
						{3, -2, 7, 2}, {-9, 4, -5, 8}, {-3, 4, 1, 8},
						{3, 4, 7, 8}}) do
					dressing.planter(buf, palette, bed[1], bed[2], bed[3],
						bed[4])
				end
				-- No `dressing.plant` over the beds: `dressing.planter` ALREADY
				-- sows every cell inside its own kerb -- soil at the ground
				-- course and a tuft or a fern above it -- so a second call there
				-- overwrites the soil with a tuft and leaves the first one
				-- standing on a plant, which is an attached node with no
				-- support.
				dressing.undergrowth(buf, palette, -10, -8, 10, -4, 5)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("scrub_tend_west", "tend", -7, -3, 0),
					plots.idle("scrub_tend_east", 5, -3, 0, {"work"}),
					plots.idle("scrub_forage", -1, -5, 0, {"work"}),
					plots.idle("scrub_bench", -2, -10, 0, {"bench"}, 2),
				}
			end},

		-- 3. THE SPOIL SHELF at the outer corner: the quarry's tailings, with
		-- a cut face of its own at the back.
		{id = "bone_spoil_shelf", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.rock_terrace(buf, palette, -8, 5, 8, 8, 4)
				dressing.rubble_heap(buf, palette, -4, 1, 3)
				dressing.rubble_heap(buf, palette, 4, 2, 2)
				dressing.handcart(buf, palette, 3, -5, "x")
				dressing.undergrowth(buf, palette, -8, -8, 8, 0, 6)
			end,
			extra_sockets = function()
				return {
					plots.work("shelf_mine", "mine", -2, 4, 0),
					plots.idle("shelf_haul", 0, -4, 0, {"work"}),
				}
			end},

		-- 4. THE CANDLE COURT inside the lot grid: a stone table, markers on
		-- it, and the one who sits with them.
		{id = "bone_candle_court", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.inlay(buf, palette, -4, -4, 4, 4, "plaza_edge")
				dressing.grave(buf, palette, 0, 1, true)
				dressing.grave(buf, palette, -2, 1, false)
				dressing.grave(buf, palette, 2, 1, false)
				dressing.bench(buf, palette, -3, -2, 0, 3, "x")
			end,
			extra_sockets = function()
				return {
					plots.work("candle_mourn", "mourn", 0, -1, 0),
					plots.idle("candle_seat", -2, -2, 0, {"bench"}, 2),
					plots.spare("candle_court", 3, 3, 0),
				}
			end},
	}

	M.lore = plots.district({
		key = "gor_drazhak_bone",
		role = "lore_spiritual",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
