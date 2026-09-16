-- Nhal Veyr, the kept houses: the residential and cultural district, nine
-- terrain-relative plots and four fill dressings.
--
-- The contract's fourth district role. What a plot is and how it is built is
-- `nhal_veyr_plot.lua`; where the nine plots stand is
-- `nhal_veyr_quadrants.lua`. This file is the roster.
--
-- THE CONTRACT'S LINE FOR THIS RACE IS BUILT HERE. Section 2.4 asks for
-- "stepped terraces with RUINS MIXED AMONG KEPT HOUSES", and this is the
-- district where that is literal: two of the nine lots carry a
-- `buildings.ruin` between the cottages rather than a house, so the street a
-- player walks is kept, kept, fallen, kept. The vigil district's ruin close
-- is the other half of the same line and is a whole lot of decay; this is the
-- half that matters more, because a ruin only reads as a ruin next to
-- something somebody still lives in.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local plots = dofile(directory .. "/nhal_veyr_plot.lua")(directory)

	local M = {}

	local WATCH = "nhal_veyr_homes_watch"

	-- What a ruin lot gets that a house lot does not: iron bars in the gaps of
	-- the standing gable and a candle burning on the step, which is the rest
	-- of the contract's line for this race and the `mourn` feature of the
	-- sockets contract's section 8.2.
	local function barred_and_lit(buf, palette, area)
		for y = 2, 3 do
			buf:put(area.ox + 2, y, area.oz, palette.node("window"))
			buf:put(area.ox + 6, y, area.oz, palette.node("window"))
		end
		area.dressing.path_light(buf, palette, area.ox + 4, area.oz - 2)
		-- And a marker on the step, which is what the mourner actually faces:
		-- a lamp standard's light is three courses up and the feature search
		-- reaches one above the feet, so the candle lights the ruin and the
		-- marker is the feature. See the vigil district's ruin close.
		area.dressing.grave(buf, palette, area.ox + 4, area.oz - 3, false)
	end

	local PLOTS = {
		-- 1 to 4. The kept houses. Each keeps the generator's own door side
		-- (`z-`) and is TURNED to face its lane instead: a cottage's `home`
		-- kit furnishes the cell behind every other wall -- bed corner,
		-- hearth, table -- and only the z- doorway is authored clear of it.
		{id = "homes_gate_house", module = "buildings", make = "cottage",
			order = 1,
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
		{id = "homes_lane_house", module = "buildings", make = "cottage",
			order = 2,
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip",
				infill = true, fancy_bed = true}},
		{id = "homes_terrace_house", module = "buildings", make = "cottage",
			order = 3,
			spec = {w = 11, d = 9, wall_h = 5, roof = "saltbox",
				ridge_axis = "x", infill = true, shutters = true}},
		{id = "homes_corner_house", module = "buildings", make = "cottage",
			order = 4,
			spec = {w = 9, d = 11, wall_h = 5, roof = "gable",
				ridge_axis = "x", infill = true, shutters = true}},
		--
		-- 5 and 6. THE TWO FALLEN ONES, between the kept houses. A ruin
		-- publishes no door, no destination and an OPEN room, so nothing that
		-- reads a composition mistakes it for a house somebody lives in; what
		-- it publishes here is the district's spare wander spot and, at the
		-- west one, a mourner at the candle on its step.
		{id = "homes_fallen_west", module = "buildings", make = "ruin",
			order = 5, spec = {w = 9, d = 9, wall_h = 5, phase = 0},
			decorate = barred_and_lit,
			extra_sockets = function(area)
				return {plots.work("step_candle", "mourn",
					area.ox + 4, area.oz - 4, 0)}
			end},
		{id = "homes_fallen_east", module = "buildings", make = "ruin",
			order = 6, spec = {w = 9, d = 11, wall_h = 5, phase = 2},
			decorate = barred_and_lit,
			extra_sockets = function(area)
				return {plots.spare("fallen", area.x1 - 1, area.z1 - 1, 2)}
			end},
		--
		-- 7. THE MOURNERS' HALL: the district's cultural building, where the
		-- quarter gathers. A hall in dungeon stone under a vaulted roof, so it
		-- reads as civic from the lane. Its bench outside the door carries the
		-- `sit` work socket, which is the one activity that names no feature.
		{id = "homes_mourners_hall", module = "buildings", make = "hall",
			order = 7, handle = "crypt", roof = "vault",
			spec = {w = 15, d = 17, wall_h = 5, infill = true},
			decorate = function(buf, palette, area)
				area.dressing.bench(buf, palette, area.x0 + 3, area.z0 + 1,
					2, 2, "x")
			end,
			extra_sockets = function(area)
				return {plots.work("bench", "sit", area.x0 + 3, area.z0 + 1,
					2, {"bench"}, 2)}
			end},
		-- 8. The quarter's own watch.
		{id = "homes_watch", module = "capitals", make = "barracks",
			handle = "crypt", roof = "vault",
			spec = {w = 15, d = 21, wall_h = 5, patrol_group = WATCH,
				order = 8}},
		-- 9. The cistern court the houses draw from, five nodes wider all
		-- round than a building's, its ring planted with gravewoods, and the
		-- district's second spare.
		{id = "homes_cistern", module = "capitals", make = "well_court",
			order = 9, margin = 5, garden = true, spec = {size = 11},
			extra_sockets = function(area)
				-- On the back row of the planted ring, not its corner: the
				-- corner is where `garden` stands a gravewood.
				return {plots.spare("cistern", area.x0 + 4, area.z1 - 1, 2)}
			end},
	}

	-- THE DISTRICT'S OWN FILL: the ground a quarter of houses keeps -- the
	-- family plots its dead lie in, the blight garden it forages, the candle
	-- court it gathers at, and one green.
	local FILL = {
		-- 1. THE FAMILY PLOTS: the small burial ground a residential quarter
		-- keeps for itself, walled rather than open, with the household names
		-- along the walk. Two MOURN and one TENDS the bed at the gate.
		{id = "homes_family_plots", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.graveyard(buf, palette, -8, 3, 8, 10)
				for x = -10, 10 do buf:put(x, 0, 0, palette.node("path")) end
				-- The two household markers the mourners face, set
				-- deliberately rather than left to the scatter's hash; see
				-- the market district's grave field for why.
				dressing.grave(buf, palette, -6, 1, false)
				dressing.grave(buf, palette, 6, 1, true)
				dressing.low_wall_line(buf, palette, -11, 11, 11, 11)
				dressing.low_wall_line(buf, palette, -11, 2, -11, 11)
				dressing.low_wall_line(buf, palette, 11, 2, 11, 11)
				dressing.gravewood(buf, palette, -8, 1, 6)
				dressing.gravewood(buf, palette, 8, 1, 5)
				dressing.path_light(buf, palette, 0, 1)
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
				dressing.bench(buf, palette, -4, -11, 0, 3, "x")
				dressing.crates(buf, palette, 8, -11, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("mourn_west", "mourn", -6, 0, 0),
					plots.work("mourn_east", "mourn", 6, 0, 0),
					plots.work("bed", "tend", 4, -7, 2),
				}
			end},
		-- 2. THE BLIGHT GARDEN: what grows in a necropolis, which is not a
		-- crop. Beds of the palette's own planter soil with dry growth in
		-- them, a gravewood at each end and a wall of the household's own
		-- masonry with vines on it -- the `forage` feature of section 8.2.
		{id = "homes_blight_garden", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.flower_bed(buf, palette, -9, 3, -3, 8)
				dressing.flower_bed(buf, palette, 3, 3, 9, 8)
				for x = -10, 10 do buf:put(x, 0, 0, palette.node("path")) end
				dressing.gravewood(buf, palette, -8, 1, 5)
				dressing.gravewood(buf, palette, 8, 1, 6)
				-- The flora is sown in two bands with the SOCKET ROW left
				-- out between them. `dressing.blight_flora` sows any column
				-- whose ground is its own and whose cell above is free, and a
				-- standing position is exactly a free cell above its own
				-- ground: a dead shrub in a sparring guard's feet is a socket
				-- with no headroom, which is what the KAT said about the first
				-- version of this row.
				dressing.blight_flora(buf, palette, -10, -8, 10, -6, 7, 2, 3)
				dressing.blight_flora(buf, palette, -10, -4, 10, -2, 7, 2, 3)
				for x = 2, 8 do
					for y = 1, 2 do
						buf:put(x, y, -3, palette.node("foundation"))
					end
				end
				local vines = 0
				for _, x in ipairs({4, 5, 6}) do
					for y = 1, 2 do
						if dressing.ivy(buf, palette, x, y, -4, 0, 1) then
							vines = vines + 1
						end
					end
				end
				if vines < 3 then
					error("wp13 nhal veyr: the blight garden wall carries " ..
						vines .. " vines and the forager needs one", 0)
				end
				dressing.plant(buf, palette, -6, 2)
				dressing.bench(buf, palette, -4, -11, 0, 3, "x")
				dressing.crates(buf, palette, 8, -11, 0)
			end,
			extra_sockets = function()
				return {
					plots.work("bed_west", "tend", -6, 1, 0),
					plots.work("wall", "forage", 5, -5, 0),
					plots.spare("garden", 9, -10, 0),
				}
			end},
		-- 3. THE QUARTER'S CANDLE COURT, where the houses gather.
		{id = "homes_candle_court", module = "undead", make = "candle_court",
			margin = 3, spec = {size = 11},
			extra_sockets = function(area)
				return {
					plots.work("vigil_south", "pray",
						area.ox + 5, area.oz + 3, 0),
					plots.work("vigil_north", "pray",
						area.ox + 5, area.oz + 7, 2),
				}
			end},
		-- 4. THE GREEN between two of the district's houses: a gravewood, a
		-- bench under it, a blight bed and the district's last spare.
		{id = "homes_green", yard = {},
			decorate = function(buf, palette, area)
				local dressing = area.dressing
				dressing.gravewood(buf, palette, 0, 2, 5)
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

	M.homes = plots.district({
		key = "nhal_veyr_homes",
		role = "residential_cultural",
		patrol_group = WATCH,
		plots = PLOTS,
		fill = FILL,
		fill_reaches = {11, 11, 8, 5},
	})

	return M
end

return loader
