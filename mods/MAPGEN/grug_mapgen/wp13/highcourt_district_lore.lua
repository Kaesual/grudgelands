-- Highcourt, the lore and spiritual district: nine terrain-relative plots.
--
-- The contract's third district role. What a plot is and how it is built is
-- `highcourt_plot.lua`; where the nine plots stand is
-- `highcourt_quadrants.lua`. This file is the roster and nothing else.
--
-- THE CHAPEL IS ALREADY BUILT, AND IT IS NOT HERE. The civic core's west
-- quarter carries the chapel with its belfry (`highcourt.lua`), which is what
-- the contract's section 2.4 line about the human capital asks for, and a
-- second chapel two hundred nodes away would be the same building twice. The
-- shrine below is `capitals.temple` -- hip roofed, taller, with its own bell
-- on the ridge and the quest socket its generator publishes -- so the
-- district has a place of its own without repeating the core's.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/highcourt_plot.lua")(directory)

	local M = {}

	local WATCH = "highcourt_cloister_watch"

	local PLOTS = {
		-- 1. The shrine, on the lot nearest the core: the tallest plot of the
		-- district, and the one that publishes the district's quest socket.
		-- The temple generator stands its quest spot three nodes INSIDE the
		-- nave, which is where a shrine's own keeper belongs and not where a
		-- quest-giver does: the user's playtest-round-2 ruling is that the
		-- elder stands on the doorstep and shows the street his face. So this
		-- plot moves the socket out onto its own path and tags it `door`,
		-- which is what turns the NPC round (`start_npcs.lua`
		-- `socket_face_yaw`). Both halves are here rather than in
		-- `capitals.lua` because the generator cannot know which of its walls
		-- this composition puts to a lane, nor where this plot's path runs.
		{id = "lore_shrine", module = "capitals", make = "temple",
			roof = "slate", order = 1,
			socket_overrides = function(area)
				return {lore_shrine_quest = {x = 0, z = area.oz - 2, face = 0,
					tags = {"door"}}}
			end,
			spec = {w = 13, d = 17, wall_h = 6}},
		-- 2. The library. A hall under slate, the biggest room in the
		-- district, with shuttered reveals left open so it reads as a place
		-- that is used.
		{id = "lore_library", module = "buildings", make = "hall",
			roof = "slate", order = 2,
			spec = {w = 15, d = 19, wall_h = 6, infill = true}},
		-- 3. The scriptorium: shelving the length of both walls, desks in
		-- front of it, and the saltbox roof that stands its rear wall taller
		-- than its front.
		{id = "lore_scriptorium", module = "capitals", make = "scriptorium",
			roof = "slate", order = 3,
			spec = {w = 15, d = 17, wall_h = 6}},
		-- 4. The archive. A granary is a stone box with bins down both walls
		-- and a cart door in the gable, which is also what a record store
		-- is; slate rather than plank, because this one belongs to the crown.
		{id = "lore_archive", module = "capitals", make = "granary",
			roof = "slate", order = 4,
			spec = {w = 13, d = 15, wall_h = 6}},
		-- 5. The herb garden: the well court with five nodes of planted
		-- ground all round instead of two, the same way the market's well is
		-- a garden rather than a paved square in a field, plus the beds that
		-- make it a physic garden and not a lawn.
		{id = "lore_herb_garden", module = "capitals", make = "well_court",
			order = 5, margin = 5, garden = true, spec = {size = 11},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.flower_bed(buf, palette, area.x0 + 1, area.oz + 3,
					area.x0 + 3, area.z1 - 3)
				dressing.flower_bed(buf, palette, area.x1 - 3, area.oz + 3,
					area.x1 - 1, area.z1 - 3)
			end,
			extra_sockets = function(area)
				return {plots.spare("garden", area.x0 + 4, area.z1 - 2, 2)}
			end},
		-- 6. The chapter house, where the district's own business is done.
		-- Door index 4, single leaf, for the `store` kit's post rhythm.
		{id = "lore_chapter_house", module = "buildings", make = "longhouse",
			order = 6,
			spec = {w = 11, d = 13, wall_h = 5, door_side = "z-",
				door_index = 4, infill = true}},
		-- 7. The almonry.
		{id = "lore_almonry", module = "buildings", make = "cottage",
			order = 7, spec = {w = 9, d = 11, wall_h = 4, infill = true}},
		-- 8. The cloister walk: the colonnade, in the crown's white stone
		-- like the two flanking the core's throne approach, with its own
		-- waypoint in the loop (so this row carries no `order`).
		{id = "lore_cloister_walk", module = "capitals", make = "colonnade",
			handle = "white",
			spec = {len = 15, d = 5, patrol_group = WATCH, order = 8}},
		-- 9. The quiet grove: columnar trees rather than the market's
		-- broadleaf, so the two groves of the capital do not read as one
		-- piece of dressing used twice, and the district's second spare.
		{id = "lore_quiet_grove", module = "capitals", make = "grove",
			order = 9, spec = {size = 15, kind = "columnar", height = 7},
			extra_sockets = function(area)
				return {plots.spare("grove", area.x1 - 2, area.z1 - 2, 2)}
			end},
	}

	-- THE DISTRICT'S OWN FILL (playtest round 3): four dressings on the
	-- quadrant's four fill lots, reaches 11, 11, 8 and 5, on the
	-- forecourt/feature rule the market district's roster writes down.
	--
	-- THE CHAPEL WITH ITS GRAVEYARD IS FILL LOT 1, and it is the one fill row
	-- of the capital that is a BUILDING. The user's round-3 ruling asked for
	-- "a chapel with a graveyard in the lore district"; a graveyard is open
	-- ground and a chapel is not, and both belong to one piece of the city, so
	-- the row builds the small parish chapel of `buildings.chapel` in the
	-- middle of the lot and lays the burial ground on the strip behind it,
	-- inside a low wall. It is NOT the core's chapel repeated: the core
	-- carries the great chapel with the belfry, and this is the one the
	-- district buries from.
	local FILL = {
		{id = "lore_chapel_yard", module = "buildings", make = "chapel",
			roof = "slate", margin = 3,
			spec = {w = 11, d = 13, wall_h = 5, infill = true},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.graveyard(buf, palette, area.x0 + 1, area.z1 - 2,
					area.x1 - 1, area.z1 - 1)
				dressing.low_wall_line(buf, palette, area.x0, area.z1,
					area.x1, area.z1)
				dressing.flower_bed(buf, palette, 2, area.z0, 4, area.z0 + 2)
			end,
			extra_sockets = function(area)
				return {
					plots.work("chapel_pray", "pray", -3, area.z0 + 2, 0),
					plots.work("chapel_beds", "tend", 5, area.z0 + 1, 3),
				}
			end},
		-- 2. THE PHYSIC FIELD: the district's own ploughed ground, the herb
		-- rows the herb garden inside the district has no room for, a hedge on
		-- the field side and the three who work it.
		{id = "lore_physic_field", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.crop_rows(buf, palette, -7, -8, 7, 8, "z")
				dressing.hedge_line(buf, palette, -11, 11, 11, 11, 2)
				dressing.flower_bed(buf, palette, -11, -9, -9, -7)
				dressing.flower_bed(buf, palette, 9, -9, 11, -7)
				dressing.bench(buf, palette, -3, -10, 0, 3, "x")
				dressing.crates(buf, palette, 8, -10, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("physic_west", "farm", -5, -9, 0),
					plots.work("physic_east", "farm", 5, -9, 0),
					plots.work("physic_beds", "tend", -8, -8, 3),
				}
			end},
		-- 3. THE SEXTON'S GARDEN: two beds, a dead tree kept for the look of
		-- the place, and the two who tend them.
		{id = "lore_sexton_garden", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.flower_bed(buf, palette, -6, -5, -3, -2)
				dressing.flower_bed(buf, palette, 3, -5, 6, -2)
				dressing.gravewood(buf, palette, 0, 4, 5)
				dressing.bench(buf, palette, -3, -7, 0, 2, "x")
				dressing.crates(buf, palette, 6, -7, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("beds_west", "tend", -2, -4, 3),
					plots.work("beds_east", "tend", 2, -4, 1),
					plots.spare("sexton", 7, -8, 0),
				}
			end},
		-- 4. THE QUIET GREEN inside the lot grid: a columnar tree rather than
		-- the market's broadleaf, so the two greens do not read as one piece
		-- of dressing used twice, a bench and the district's second spare.
		{id = "lore_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.columnar(buf, palette, 0, 2, 6)
				dressing.bench(buf, palette, -4, -3, 0, 2, "x")
				dressing.flower_bed(buf, palette, 1, -3, 4, -1)
			end,
			extra_sockets = function()
				return {
					plots.work("green_bench", "sit", -4, -3, 0, {"bench"}, 2),
					plots.spare("green", 4, -5, 0),
				}
			end},
	}

	M.lore = plots.district({
		key = "highcourt_lore",
		role = "lore_spiritual",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
