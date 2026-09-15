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
		{id = "lore_shrine", module = "capitals", make = "temple",
			roof = "slate", order = 1,
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

	M.lore = plots.district({
		key = "highcourt_lore",
		role = "lore_spiritual",
		patrol_group = WATCH,
		plots = PLOTS,
	})

	return M
end

return loader
