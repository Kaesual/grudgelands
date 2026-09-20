-- Acceptance for the STREET RULE of `wp13/avenue.lua` and
-- `wp13/street_plan.lua`: the five things the user ruled about a capital's
-- streets in playtest 5 (2026-09-16), as properties, on synthetic profiles,
-- with no terrain and no engine.
--
-- THE RULINGS, and the section of this file that holds each of them:
--
--   1. "Streets follow the terrain exactly, a wild mix of stairs and
--      orthogonal one-block jumps." WANTED: every block ACROSS the walking
--      direction on ONE y, and the profile ALONG the run climbing at most one
--      node per column.                                       -- section 1
--   2. "The connecting street must be raised artificially at the junction."
--      WANTED: every junction is a SQUARE PLATEAU on one y, and every run
--      arriving at it meets that y with steps of at most one per column.
--                                                             -- sections 3, 4
--   3. The lamp posts followed the ground. WANTED: they stand beside the
--      street on the STREET's actual height profile.           -- section 2
--   4. Streets raised artificially on steep slopes stand on SUPPORT PILLARS
--      with open air beneath; solid fill only where the raise is small.
--                                                             -- section 5
--   5. Piers, rails and deck lanterns wherever ANY capital's street crosses
--      water, and the water body stays ONE body.              -- section 6
--
-- AND ONE MORE THAT THE PLAYTEST AFTER THEM ADDED (2026-09-16, round 4):
--
--   6. "Railings, fences, verge posts and pillars end at the crossing square;
--      the plateau square is rail-free towards every street that joins it."
--      WANTED: no cell of a run's verge inside another run's carriageway, the
--      parapet kept where nothing joins, and the deck continuous across the
--      handover.                                              -- section 11
--
-- AND THE INVARIANT NONE OF THEM MAY COST: a piece of a run is exactly that
-- stretch of the whole run, because the successor emerges a street one
-- mapchunk at a time. Section 7 cuts every run of every case at EVERY column
-- and compares the union with the whole, which is the strongest form of that
-- test the brief asks for.
--
-- `tools/wp13/street_geometry.lua` measures the same rulings against the real
-- WP40 terrain of all six capitals on all nine fixture seeds, which is what
-- says how much the rules changed. THIS file is the property, and it turns red
-- on profiles no seed happens to contain.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.

return function(repo)
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local palettes = dofile(wp13 .. "/palette.lua")
	local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
	local street_plan = dofile(wp13 .. "/street_plan.lua")(wp13)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")

	local report = {}
	local function say(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	local HALF = (avenue.WIDTH - 1) / 2
	local VERGE = HALF + 1
	local CLEAR = avenue.MIN_CLEAR

	-- One palette per race, because ruling 5 is "in every other city where it
	-- is missing": a bridge that only the elf palette can name is a bridge five
	-- capitals do not get.
	local RACES = {"human", "dwarf", "elf", "orc", "troll", "undead"}
	local handles = {}
	for _, race in ipairs(RACES) do handles[race] = palettes.new(race) end

	local function run_of(palette, spec, ground, wet, junctions, decks)
		return avenue.run(palette, {id = spec.id or "kat", axis = spec.axis or "x",
			at = spec.at or 0, from = spec.from, to = spec.to,
			width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
			lamp_phase = spec.lamp_phase or spec.from, reach = avenue.REACH,
			wet = wet, junctions = junctions, overhead = decks}, ground)
	end

	-- The walking level of a piece, per position along its own axis and per
	-- lane, read off the CELLS and not off the rule: the topmost cell of a
	-- carriageway column whose name is one of the road's own three surfaces.
	local function walking(palette, spec, piece)
		local dx = (spec.axis == "x") and 1 or 0
		local PAVING = palette.maybe("castle_paving") or palette.node("plaza")
		local KERB = palette.node("plaza_edge")
		local TREAD = palette.maybe("castle_wall_stair") or
			palette.node("roof_stair")
		local road = {[PAVING] = true, [KERB] = true, [TREAD] = true}
		local level = {}
		for _, cell in ipairs(piece.cells) do
			if road[cell.name] then
				local p = (dx == 1) and cell.x or cell.z
				local lane = ((dx == 1) and cell.z or cell.x) - spec.at
				if lane >= -HALF and lane <= HALF then
					local row = level[p]
					if row == nil then
						row = {}
						level[p] = row
					end
					if row[lane] == nil or cell.y > row[lane] then
						row[lane] = cell.y
					end
				end
			end
		end
		return level
	end

	local function flat_row(level, p)
		local row = level[p]
		if row == nil then return nil, nil end
		local low, high
		for lane = -HALF, HALF do
			local y = row[lane]
			if y then
				if low == nil or y < low then low = y end
				if high == nil or y > high then high = y end
			end
		end
		return low, high
	end

	local cases = 0

	----------------------------------------------------------------------
	-- 1. RULING 1: ONE CROSS PROFILE PER POSITION, AND ONE STEP PER COLUMN.
	--
	-- The profile has CROSS FALL in it -- the road's own lanes stand at five
	-- different heights -- which is exactly what the per-lane envelope this
	-- replaced followed and what the user saw as "a wild mix of stairs and
	-- orthogonal one-block jumps". A diagonal terrace joint is in it too, so
	-- the joint reaches the five lanes in five different columns.
	----------------------------------------------------------------------
	local function diagonal(x, z)
		-- Two terraces, the joint running across the road at 45 degrees, plus
		-- one node of cross fall per lane.
		local height = 20
		if x + z >= 0 then height = 24 end
		if x + z >= 40 then height = 27 end
		return height - z
	end
	local SPAN = {from = -48, to = 48}
	do
		local worst_spread, worst_step, positions = 0, 0, 0
		for _, race in ipairs(RACES) do
			local palette = handles[race]
			local spec = {id = "cross", axis = "x", at = 0,
				from = SPAN.from, to = SPAN.to}
			local piece = run_of(palette, spec, diagonal)
			local level = walking(palette, spec, piece)
			local previous
			for p = SPAN.from, SPAN.to do
				local low, high = flat_row(level, p)
				assert(low and high, race ..
					": the run has no walking cell at " .. p)
				for lane = -HALF, HALF do
					assert(level[p][lane], race .. ": the lane " .. lane ..
						" of position " .. p .. " carries no road")
				end
				if high - low > worst_spread then worst_spread = high - low end
				assert(high == low, race .. ": the cross profile at " .. p ..
					" spreads " .. (high - low) .. " nodes")
				if previous then
					local step = high - previous
					if step < 0 then step = -step end
					if step > worst_step then worst_step = step end
					assert(step <= 1, race .. ": the road steps " .. step ..
						" nodes between " .. (p - 1) .. " and " .. p)
				end
				previous = high
				positions = positions + 1
			end
		end
		assert(worst_step == 1,
			"this profile never made the road climb, so the rule is untested")
		cases = cases + 1
		say("street_cross_profile", positions, worst_spread, worst_step)
	end

	----------------------------------------------------------------------
	-- 2. RULING 3: A LAMP STANDS ON THE STREET'S PROFILE.
	--
	-- Same diagonal profile, whose verge columns stand at a different height
	-- from the road beside them at every lamp of the run -- which is the case
	-- that used to put 1222 of the six capitals' 4343 standards off the road.
	----------------------------------------------------------------------
	do
		local standards, off_ground = 0, 0
		for _, race in ipairs(RACES) do
			local palette = handles[race]
			local spec = {id = "lamps", axis = "x", at = 0,
				from = SPAN.from, to = SPAN.to}
			local piece = run_of(palette, spec, diagonal)
			local level = walking(palette, spec, piece)
			for _, lamp in ipairs(piece.lamps) do
				standards = standards + 1
				assert(math.abs(lamp.z) == VERGE,
					race .. ": a standard left its verge")
				local _, high = flat_row(level, lamp.x)
				assert(high, race .. ": a standard stands beside no road")
				assert(lamp.y - 3 == high, race .. ": a standard foots at " ..
					(lamp.y - 3) .. " and the street beside it stands at " ..
					high)
				if lamp.y - 3 ~= diagonal(lamp.x, lamp.z) then
					off_ground = off_ground + 1
				end
			end
		end
		assert(standards > 0, "the rhythm lit nothing")
		assert(off_ground > 0, "no standard on this profile had to leave the " ..
			"ground, so the ruling is untested")
		cases = cases + 1
		say("street_lamps", standards, off_ground)
	end

	----------------------------------------------------------------------
	-- 3. RULING 2: THE JUNCTION PLATEAU, on a slope.
	--
	-- Two runs crossing at the origin of a ground that falls a node a column
	-- along both axes, so the two runs reach the square at two different
	-- heights and the square is exactly the place the user found unwalkable.
	----------------------------------------------------------------------
	local function slope(x, z)
		return 60 - math.floor(x / 2) - math.floor(z / 3)
	end
	local CROSS_RUNS = {
		{id = "avenue", axis = "x", at = 0, from = -60, to = 60},
		{id = "lane", axis = "z", at = 0, from = -60, to = 60},
	}
	do
		local plan = street_plan.junctions(CROSS_RUNS, avenue.WIDTH)
		assert(#plan.avenue == 1 and #plan.lane == 1,
			"the two crossing runs produced " .. #plan.avenue .. " and " ..
				#plan.lane .. " junctions, not one each")
		local palette = handles.human
		local levels, plateau_y = {}, nil
		for _, spec in ipairs(CROSS_RUNS) do
			local piece = run_of(palette, spec, slope, nil, plan[spec.id])
			assert(#piece.plateaus == 1,
				spec.id .. " built " .. #piece.plateaus .. " plateaus, not one")
			if plateau_y == nil then plateau_y = piece.plateaus[1].y end
			assert(piece.plateaus[1].y == plateau_y,
				"the two runs level the same square at " .. plateau_y ..
					" and " .. piece.plateaus[1].y)
			levels[spec.id] = walking(palette, spec, piece)
		end
		-- THE SQUARE IS ONE y IN BOTH RUNS' OWN CELLS.
		for _, spec in ipairs(CROSS_RUNS) do
			local level = levels[spec.id]
			for p = -HALF, HALF do
				local low, high = flat_row(level, p)
				assert(low == plateau_y and high == plateau_y,
					spec.id .. " walks the junction column " .. p .. " at " ..
						tostring(low) .. ".." .. tostring(high) ..
						", not at the plateau " .. plateau_y)
			end
		end
		-- AND BOTH RUNS ARRIVE AT IT A NODE A COLUMN, all the way out.
		local worst_step = 0
		for _, spec in ipairs(CROSS_RUNS) do
			local level = levels[spec.id]
			for p = spec.from + 1, spec.to do
				local _, here = flat_row(level, p)
				local _, before = flat_row(level, p - 1)
				if here and before then
					local step = here - before
					if step < 0 then step = -step end
					if step > worst_step then worst_step = step end
					assert(step <= 1, spec.id .. " steps " .. step ..
						" nodes between " .. (p - 1) .. " and " .. p)
				end
			end
		end
		-- THE PLATEAU IS ARTIFICIAL: it stands above the ground it levels,
		-- which is the whole of "raised artificially at the junction".
		local lifted = 0
		for x = -HALF, HALF do
			for z = -HALF, HALF do
				if plateau_y > slope(x, z) then lifted = lifted + 1 end
			end
		end
		assert(lifted > 0, "this slope needed no raise, so the ruling is " ..
			"untested")
		cases = cases + 1
		say("street_junction", plateau_y, lifted, worst_step)
	end

	----------------------------------------------------------------------
	-- 4. THREE STREETS IN ONE PLACE. Two squares that share a column are ONE
	--    junction: taken as independent pairs they take two different levels
	--    and the shared columns then leave the lower square a node out of
	--    true. Lethariel's east avenue, its ring street and a district lane do
	--    exactly this on the gate seed.
	----------------------------------------------------------------------
	local TRIPLE_RUNS = {
		{id = "avenue", axis = "x", at = 0, from = -60, to = 60},
		{id = "ring", axis = "z", at = 0, from = -60, to = 60},
		{id = "lane", axis = "z", at = 2, from = -60, to = 60},
	}
	do
		local plan, overlaps = street_plan.junctions(TRIPLE_RUNS, avenue.WIDTH)
		assert(#overlaps == 1 and overlaps[1].one == "ring" and
			overlaps[1].two == "lane",
			"the two parallel runs were not reported as an overlap")
		assert(#plan.avenue == 1, "the avenue's two squares were not merged " ..
			"into one junction (" .. #plan.avenue .. ")")
		assert(#plan.avenue[1].members == 2,
			"the merged junction carries " .. #plan.avenue[1].members ..
				" other runs, not two")
		local palette = handles.dwarf
		local level_y, levels = nil, {}
		for _, spec in ipairs(TRIPLE_RUNS) do
			local piece = run_of(palette, spec, slope, nil, plan[spec.id])
			assert(#piece.plateaus == 1, spec.id .. " built " ..
				#piece.plateaus .. " plateaus, not one")
			if level_y == nil then level_y = piece.plateaus[1].y end
			assert(piece.plateaus[1].y == level_y, spec.id ..
				" levels the shared square at " .. piece.plateaus[1].y ..
				" and another run at " .. level_y)
			levels[spec.id] = walking(palette, spec, piece)
		end
		-- The merged square on the avenue's own axis, every column at one y.
		local low_p, high_p = plan.avenue[1].low, plan.avenue[1].high
		assert(high_p - low_p >= avenue.WIDTH,
			"the merge did not widen the avenue's square (" .. low_p .. ".." ..
				high_p .. ")")
		for p = low_p, high_p do
			local low, high = flat_row(levels.avenue, p)
			assert(low == level_y and high == level_y,
				"the merged plateau column " .. p .. " walks at " ..
					tostring(low) .. ".." .. tostring(high) .. ", not " ..
					level_y)
		end
		cases = cases + 1
		say("street_junction_group", level_y, low_p, high_p, #overlaps)
	end

	----------------------------------------------------------------------
	-- 5. RULING 4: THE VIADUCT. A raise of `MIN_CLEAR` or more stands on
	--    pillars with open air under it; a smaller raise is still solid
	--    ground. Both halves are checked, in every race's palette, because a
	--    rule that only fires for one of them is not a rule.
	----------------------------------------------------------------------
	local function cliff(x, z)
		-- Flat, then a fall of two nodes a column -- faster than a road may
		-- descend, so the road leaves the ground -- and then flat again.
		local height = 60
		if x > 0 and x <= 20 then height = 60 - 2 * x end
		if x > 20 then height = 20 end
		return height
	end
	do
		local solid_total, open_total, pillars_total, rails_total = 0, 0, 0, 0
		local worst_clear
		for _, race in ipairs(RACES) do
			local palette = handles[race]
			local spec = {id = "viaduct", axis = "x", at = 0,
				from = -40, to = 60}
			local piece = run_of(palette, spec, cliff)
			local level = walking(palette, spec, piece)
			local written = {}
			for _, cell in ipairs(piece.cells) do
				written[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name
			end
			local solid, open = 0, 0
			for p = spec.from, spec.to do
				local _, top = flat_row(level, p)
				assert(top, race .. ": no road at " .. p)
				for lane = -HALF, HALF do
					local ground = cliff(p, lane)
					local raise = top - ground
					local key = p .. ":" .. ground .. ":" .. lane
					if raise >= CLEAR then
						assert(written[key] == nil, race .. ": the column " ..
							p .. "," .. lane .. " is raised " .. raise ..
							" and still filled at its own ground: a wall, " ..
							"not a viaduct")
						open = open + 1
						local clear = raise - 1
						if worst_clear == nil or clear < worst_clear then
							worst_clear = clear
						end
					elseif raise > 0 then
						for y = ground, top do
							assert(written[p .. ":" .. y .. ":" .. lane],
								race .. ": the column " .. p .. "," .. lane ..
								" is raised only " .. raise ..
								" and has a hole at " .. y)
						end
						solid = solid + 1
					end
				end
			end
			assert(solid > 0 and open > 0, race ..
				": this profile exercised only one of fill and viaduct (" ..
				solid .. " solid, " .. open .. " open)")
			assert(piece.street.piers > 0, race .. ": the viaduct has no pillars")
			assert(piece.street.rails > 0, race .. ": the viaduct has no rail")
			-- Every pillar and every rail on a VERGE lane, never in the
			-- carriageway, and the rail one course over the road.
			local RAIL = palette.node("railing")
			for _, cell in ipairs(piece.cells) do
				if cell.name == RAIL then
					assert(math.abs(cell.z) == VERGE, race ..
						": a rail stands at lane " .. cell.z)
					local _, top = flat_row(level, cell.x)
					assert(top and cell.y == top + 1, race ..
						": a rail at " .. cell.x .. " stands at " .. cell.y ..
						", not one course over the road at " .. tostring(top))
				end
			end
			solid_total = solid_total + solid
			open_total = open_total + open
			pillars_total = pillars_total + piece.street.piers
			rails_total = rails_total + piece.street.rails
		end
		-- A PLAYER IS TWO NODES TALL, and that is the whole of "so a player can
		-- walk under it": the threshold is chosen so that the thinnest viaduct
		-- still has room for one.
		assert(worst_clear >= 2, "a viaduct column leaves " .. worst_clear ..
			" nodes of air")
		cases = cases + 1
		say("street_viaduct", solid_total, open_total, pillars_total,
			rails_total, worst_clear, CLEAR)
	end

	----------------------------------------------------------------------
	-- 6. RULING 5: THE BRIDGE, in every race's palette.
	--
	-- A water body stays ONE body: over a wet column the road writes a deck and
	-- NOTHING at or under the water line -- along the run and across it -- and
	-- the piers stand on the two verge lanes so the whole carriageway is open
	-- water underneath.
	----------------------------------------------------------------------
	local WATER, WET_FROM, WET_TO = 40, -20, 20
	local function lake(x, z)
		-- The seam hands a road the WATER surface where water stands, so the
		-- span itself is flat at the water line and the banks climb away.
		if x >= WET_FROM and x <= WET_TO then return WATER end
		if x < WET_FROM then return WATER + (WET_FROM - x) end
		return WATER + (x - WET_TO)
	end
	local function lake_wet(x, z)
		return x >= WET_FROM and x <= WET_TO
	end
	do
		local decks, piers, rails, touched_total = 0, 0, 0, 0
		for _, race in ipairs(RACES) do
			local palette = handles[race]
			local spec = {id = "bridge", axis = "x", at = 0,
				from = -48, to = 48}
			local piece = run_of(palette, spec, lake, lake_wet)
			local level = walking(palette, spec, piece)
			assert(piece.street.bridged == (WET_TO - WET_FROM + 1), race ..
				": the run bridged " .. piece.street.bridged ..
				" positions of " .. (WET_TO - WET_FROM + 1))
			assert(piece.street.piers > 0, race .. ": the bridge has no piers")
			assert(piece.street.rails > 0, race .. ": the bridge has no rails")
			-- NOTHING AT OR UNDER THE WATER LINE ON THE CARRIAGEWAY, air
			-- included: an air cell at the surface is the writer being told to
			-- take the water out, which would cut the body in two just as a
			-- causeway does.
			local touched = 0
			for _, cell in ipairs(piece.cells) do
				if math.abs(cell.z) <= HALF and cell.x >= WET_FROM and
						cell.x <= WET_TO and cell.y <= WATER then
					touched = touched + 1
				end
			end
			assert(touched == 0, race .. ": the bridge writes into " ..
				touched .. " carriageway cells at or under the water line")
			touched_total = touched_total + touched
			-- The deck stands over the water for every wet column, and never
			-- steps more than a node -- the shore included, which is the step
			-- a walker takes onto the bridge.
			for p = spec.from + 1, spec.to do
				local _, here = flat_row(level, p)
				local _, before = flat_row(level, p - 1)
				assert(here, race .. ": no deck at " .. p)
				if p >= WET_FROM and p <= WET_TO then
					assert(here >= WATER + avenue.LIFT, race ..
						": the deck at " .. p .. " stands at " .. here ..
						", not over the water at " .. WATER)
					decks = decks + 1
				end
				local step = here - before
				if step < 0 then step = -step end
				assert(step <= 1, race .. ": the deck steps " .. step ..
					" nodes between " .. (p - 1) .. " and " .. p)
			end
			-- The piers stand on the verge lanes and reach into the bed.
			local PIER = palette.maybe("signature") or palette.node("wall_accent")
			local deep = 0
			for _, cell in ipairs(piece.cells) do
				if cell.name == PIER and math.abs(cell.z) == VERGE and
						cell.x >= WET_FROM and cell.x <= WET_TO then
					if cell.y < WATER then deep = deep + 1 end
				end
			end
			assert(deep > 0, race ..
				": no pier of this bridge reaches under the water")
			piers = piers + piece.street.piers
			rails = rails + piece.street.rails
		end
		cases = cases + 1
		say("street_bridge", decks, piers, rails, touched_total, avenue.LIFT,
			avenue.PIER, avenue.PIER_DEPTH)
	end

	----------------------------------------------------------------------
	-- 7. A PIECE OF A RUN IS EXACTLY THAT STRETCH OF THE WHOLE RUN, cut at
	--    EVERY column of every case above. This is the invariant the whole
	--    module exists inside: the successor emerges a street one mapchunk at
	--    a time, and a rule that needs the whole run is a rule that builds a
	--    different road on a chunk border.
	----------------------------------------------------------------------
	do
		local CASES = {
			{label = "cross", ground = diagonal, wet = nil,
				spec = {id = "cross", axis = "x", at = 0, from = -20, to = 20}},
			{label = "viaduct", ground = cliff, wet = nil,
				spec = {id = "viaduct", axis = "x", at = 0, from = -10, to = 30}},
			{label = "bridge", ground = lake, wet = lake_wet,
				spec = {id = "bridge", axis = "x", at = 0, from = -30, to = 30}},
			{label = "junction", ground = slope, wet = nil,
				spec = {id = "avenue", axis = "x", at = 0, from = -30, to = 30},
				junctions = street_plan.junctions(CROSS_RUNS,
					avenue.WIDTH).avenue},
		}
		local palette = handles.troll
		local splits = 0
		for _, case in ipairs(CASES) do
			local spec = case.spec
			local whole = run_of(palette, spec, case.ground, case.wet,
				case.junctions)
			local expected = {}
			for _, cell in ipairs(whole.cells) do
				expected[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
					cell.name .. ":" .. (cell.param2 or 0)
			end
			for cut = spec.from, spec.to - 1 do
				local union, count = {}, 0
				for _, part in ipairs({{spec.from, cut}, {cut + 1, spec.to}}) do
					local piece = run_of(palette,
						{id = spec.id, axis = spec.axis, at = spec.at,
							from = part[1], to = part[2],
							lamp_phase = spec.lamp_phase or spec.from}, case.ground, case.wet,
						case.junctions)
					for _, cell in ipairs(piece.cells) do
						local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
						local value = cell.name .. ":" .. (cell.param2 or 0)
						assert(expected[key] == value, case.label ..
							": the piece cut at " .. cut .. " writes " ..
							value .. " at " .. key ..
							", which the whole run does not")
						if union[key] == nil then
							union[key] = value
							count = count + 1
						end
					end
				end
				assert(count == #whole.cells, case.label ..
					": the two pieces cut at " .. cut .. " carry " .. count ..
					" cells, the whole run " .. #whole.cells)
				splits = splits + 1
			end
		end
		cases = cases + 1
		say("street_pieces", #CASES, splits)
	end

	----------------------------------------------------------------------
	-- 8. THE SIX CAPITALS' OWN JUNCTION INVENTORY, pinned.
	--
	-- Computed from the run RECTANGLES alone, so it needs no terrain and no
	-- seed and is the same on every world. Two things are pinned: how many
	-- junctions each capital has, and every PARALLEL OVERLAP -- two streets
	-- running side by side rather than crossing, which is not a junction and
	-- which `wp13/street_plan.lua` refuses to level.
	--
	-- THE INVENTORY IS TWELVE BUTT JOINTS AND NOTHING ELSE since round 4
	-- (2026-09-16). Wave 3 pinned twenty: fourteen butt joints (two runs of one
	-- continuous lane sharing exactly one column, which need nothing) and six
	-- SIDE-BY-SIDE stretches, all Lethariel's, where a district lane at +-98 ran
	-- alongside the ring street at +-96 for up to 97 columns. The user walked
	-- into one of those in playtest 6 -- "two streets overlay each other with a
	-- 2-node offset across the walking direction; the last one written wins and
	-- artefacts of the overwritten street remain" -- and they were the only
	-- unwalkable steps left in the six capitals. Each of those lanes now stands
	-- on the ring's OWN centre line and starts one column past the ring run it
	-- continues, so the two are collinear, share no column and are pinned to one
	-- y by the ring corner's plateau. Lethariel's own two lane/lane butt joints
	-- went with them: the ring street now stands between the two halves that
	-- used to meet at 0. A capital that grows a side-by-side pair again turns
	-- this row red rather than growing one quietly.
	----------------------------------------------------------------------
	-- Do the two ends of a collinear seam lie in ONE junction group? A group is
	-- published per run, so the question is asked of one side and answered by
	-- the other's presence in its members: a record of `one` whose range covers
	-- `one`'s end column and whose member list carries `two` with ITS end column
	-- inside the range that member row publishes.
	local function seam_pinned(plan, one, two, mine, theirs)
		for _, record in ipairs(plan[one.id] or {}) do
			if record.low <= mine and mine <= record.high then
				for _, member in ipairs(record.members) do
					if member.id == two.id and member.low <= theirs and
							theirs <= member.high then
						return true
					end
				end
			end
		end
		return false
	end
	do
		local KEYS = {"highcourt", "dur_brannoc", "gor_drazhak", "lethariel",
			"kezamba", "nhal_veyr"}
		local rows = {}
		local half = HALF
		local collinear_seams = 0
		for _, key in ipairs(KEYS) do
			local source = dofile(wp40 .. "/r7_" .. key .. "_blueprint.lua")()
			local streets, records = {}, 0
			for _, run in ipairs(source.overlay.runs) do
				if not (run.id:match("^wall_") or run.id:match("^edge_") or
						run.id:match("^gate_")) then
					streets[#streets + 1] = run
					-- Every street run of a capital carries the junctions its
					-- own composition attached, which is what the seam hands
					-- the road. A street with none would be a street the plan
					-- forgot.
					records = records + #(run.junctions or {})
				end
			end
			local plan, overlaps = street_plan.junctions(streets,
				source.overlay.width)
			local computed = 0
			for id, list in pairs(plan) do
				computed = computed + #list
				local attached
				for _, run in ipairs(streets) do
					if run.id == id then attached = run.junctions end
				end
				assert(attached ~= nil, key .. ": the run " .. id ..
					" reached the seam with no junction list at all")
				assert(#attached == #list, key .. ": the run " .. id ..
					" carries " .. #attached ..
					" junctions and the plan computes " .. #list)
				-- AND THE RANGES, not only the count. The compositions call
				-- `street_plan.attach` without a width, so the squares come
				-- from `avenue.WIDTH`; the seam's identity argument rests on
				-- the width the capital DECLARES. They are the same number
				-- today and this is what says so -- a capital that ever
				-- declared another carriageway would get squares of the wrong
				-- size, and a count test would not see it.
				for index = 1, #list do
					local mine, theirs = list[index], attached[index]
					assert(mine.low == theirs.low and mine.high == theirs.high,
						key .. ": the run " .. id .. " carries the square " ..
						theirs.low .. ".." .. theirs.high ..
						" and the plan computes " .. mine.low .. ".." ..
						mine.high .. " at the declared width " ..
						source.overlay.width)
					assert(#mine.members == #theirs.members, key ..
						": the run " .. id .. " carries " .. #theirs.members ..
						" members of the square at " .. theirs.low ..
						" and the plan computes " .. #mine.members)
				end
			end
			assert(records == computed, key .. ": the composition attached " ..
				records .. " junction records and the plan computes " ..
				computed)
			local parallel = {}
			for _, pair in ipairs(overlaps) do
				local depth
				-- How deep the overlap runs ALONG the two parallel runs: one
				-- column is a butt joint (one continuous lane authored as two
				-- runs) and needs nothing; more is a shared stretch of street.
				local one, two
				for _, run in ipairs(streets) do
					if run.id == pair.one then one = run end
					if run.id == pair.two then two = run end
				end
				assert(one and two, key .. ": the plan reports an overlap of " ..
					pair.one .. " and " .. pair.two ..
					", and the run list carries no such pair")
				if one.axis == "x" then
					depth = pair.max_x - pair.min_x + 1
				else
					depth = pair.max_z - pair.min_z + 1
				end
				-- THE PIN, and it is an assertion since round 4 (2026-09-16)
				-- rather than a row somebody reads. A parallel overlap is
				-- allowed to be ONE thing: two COLLINEAR runs of one continuous
				-- lane sharing exactly their end column. Anything else is two
				-- streets in one place -- the defect the user walked into at
				-- Lethariel in playtest 6 -- and a composition may not grow one
				-- again.
				assert(one.at == two.at, key .. ": " .. pair.one .. " at " ..
					one.at .. " and " .. pair.two .. " at " .. two.at ..
					" run side by side rather than end to end -- two streets " ..
					"that share columns and no centre line are one street")
				assert(depth == 1, key .. ": " .. pair.one .. " and " ..
					pair.two .. " share " .. depth ..
					" columns of carriageway; a butt joint shares exactly one")
				parallel[#parallel + 1] = pair.one .. "/" .. pair.two .. "/" ..
					depth
			end
			-- EVERY STREET IS REACHABLE, AND EVERY CLOSE COLLINEAR SEAM IS
			-- PINNED. The independent review of 2026-09-16 found that round 4's
			-- own invariant was held by nothing: it moved Lethariel's district
			-- lanes twenty columns off the ring ends they continue -- five
			-- streets left hanging in the fields with a 19-column hole in front
			-- of each -- and every gate in the tree stayed green. The overlap
			-- rule above only looks at the direction where two streets share
			-- TOO MUCH; `walkability.lua` cannot see a GAP at all, because a
			-- gap has no neighbouring road columns to step between.
			--
			-- Two rules, both composition-agnostic, so a capital that grows the
			-- shape later inherits them:
			--
			--   1. A STREET NOBODY CAN REACH IS NOT A STREET. Every run must
			--      share at least one carriageway column with another run --
			--      that is, appear in at least one junction group or in one
			--      parallel overlap. Measured: 0 lonely runs in all six
			--      capitals; the review's mutation makes six of Lethariel's
			--      fifteen lonely at once.
			--   2. A COLLINEAR SEAM IS ADJACENT AND PINNED. Two runs on one
			--      centre line that do NOT share a column, and whose nearer
			--      ends are within a road's half-width plus one of each other,
			--      are a seam a walker crosses: they must be EXACTLY adjacent
			--      (a larger gap is a stretch of ring or lane nobody paves) and
			--      both ends must lie in ONE junction group (or nothing pins
			--      the two envelopes to the same y, which is the step the user
			--      walked into in playtest 6). Measured: six such seams in the
			--      tree, all Lethariel's ring corners, all adjacent and all
			--      pinned; the other five capitals have none, because their
			--      collinear pairs SHARE their end column and a butt joint
			--      needs nothing (wave 3, `street_plan.lua`).
			local touched = {}
			for _, pair in ipairs(overlaps) do
				touched[pair.one] = true
				touched[pair.two] = true
			end
			for id, list in pairs(plan) do
				if #list > 0 then touched[id] = true end
			end
			for _, run in ipairs(streets) do
				assert(touched[run.id], key .. ": the street " .. run.id ..
					" shares no carriageway column with any other street -- " ..
					"it is a road nobody can reach")
			end
			local seams = 0
			for a = 1, #streets do
				for b = a + 1, #streets do
					local one, two = streets[a], streets[b]
					if one.axis == two.axis and one.at == two.at then
						-- The nearer pair of ends, and the columns between
						-- them. A shared column is not a seam: it is the butt
						-- joint the rule above already holds.
						local gap, mine, theirs
						if two.from > one.to then
							gap, mine, theirs = two.from - one.to, one.to, two.from
						elseif one.from > two.to then
							gap, mine, theirs = one.from - two.to, one.from, two.to
						end
						if gap ~= nil and gap <= half + 1 then
							seams = seams + 1
							assert(gap == 1, key .. ": " .. one.id .. " ends at "
								.. mine .. " and " .. two.id .. " begins at " ..
								theirs .. " on the same centre line, leaving " ..
								(gap - 1) .. " column(s) neither of them paves")
							assert(seam_pinned(plan, one, two, mine, theirs),
								key .. ": " .. one.id .. " and " .. two.id ..
								" meet end to end at " .. mine .. "/" ..
								theirs .. " on one centre line and no " ..
								"junction group covers both ends -- nothing " ..
								"pins the two envelopes to the same y")
						end
					end
				end
			end
			collinear_seams = collinear_seams + seams
			table.sort(parallel)
			rows[#rows + 1] = key .. ":" .. #streets .. ":" .. computed ..
				":" .. #overlaps
			say("street_capital", key, #streets, computed, #overlaps,
				table.concat(parallel, ","))
		end
		-- AND THE PINNING TEST ITSELF ANSWERS BOTH WAYS, on two runs built for
		-- it. Every collinear seam in the six capitals IS pinned, so the false
		-- branch of `seam_pinned` is never taken on real data and would be an
		-- assertion nothing exercises; these two cases take it.
		do
			local ALONE = {
				{id = "ring", axis = "z", at = 0, from = -40, to = 0},
				{id = "lane", axis = "z", at = 0, from = 1, to = 40},
			}
			local lonely_plan = street_plan.junctions(ALONE, avenue.WIDTH)
			assert(not seam_pinned(lonely_plan, ALONE[1], ALONE[2], 0, 1),
				"two collinear runs with nothing crossing them were reported " ..
				"as pinned by a junction group")
			local JOINED = {
				{id = "ring", axis = "z", at = 0, from = -40, to = 0},
				{id = "lane", axis = "z", at = 0, from = 1, to = 40},
				{id = "cross", axis = "x", at = 0, from = -40, to = 40},
			}
			local joined_plan = street_plan.junctions(JOINED, avenue.WIDTH)
			assert(seam_pinned(joined_plan, JOINED[1], JOINED[2], 0, 1),
				"a collinear seam with a street crossing it was not reported " ..
				"as pinned")
		end
		-- AND THE LITERAL THE LANES STAND ON IS THE RING'S OWN. Lethariel's
		-- quadrant file cannot read `lethariel.lua` (that file loads this one),
		-- so the centre line it carries is a second copy of the same number.
		-- This is what stops the two drifting apart in silence.
		do
			local quadrants = dofile(wp13 .. "/lethariel_quadrants.lua")()
			local capital = dofile(wp13 .. "/lethariel.lua")(wp13)
			assert(type(quadrants.RING_AT) == "number",
				"lethariel_quadrants publishes no RING_AT for a gate to hold")
			for _, run in ipairs(capital.ring) do
				local magnitude = (run.at < 0) and -run.at or run.at
				assert(magnitude == quadrants.RING_AT, "lethariel: the ring " ..
					"run " .. run.id .. " stands at " .. run.at ..
					" and the district lanes are built against RING_AT " ..
					quadrants.RING_AT)
			end
			assert(quadrants.LANE_START == quadrants.RING_AT + 1,
				"lethariel: the district lanes start at " ..
				quadrants.LANE_START .. " and the ring street ends at " ..
				quadrants.RING_AT .. ": they are no longer collinear neighbours")
			-- Every lane that stands on a ring centre line, counted, so the
			-- case cannot pass by having none.
			local on_ring = 0
			for _, run in ipairs(quadrants.lane_runs()) do
				local magnitude = (run.at < 0) and -run.at or run.at
				if magnitude == quadrants.RING_AT then on_ring = on_ring + 1 end
			end
			assert(on_ring == 6, "lethariel: " .. on_ring ..
				" district lanes stand on a ring centre line, not six")
		end
		cases = cases + 1
		say("street_inventory",
			common.hex(common.new_sha256()(table.concat(rows, "\n"))),
			"collinear_seams", collinear_seams)
	end

	----------------------------------------------------------------------
	-- 9. WHERE THE PLATEAU SITS, AND HOW FAR EACH RUN LOOKS TO AGREE ON IT.
	--
	-- Sections 3 and 4 hold the plateau FLAT and hold the two runs to the same
	-- y. Neither notices two things that would break the rule in the built
	-- world, and the independent review of 2026-09-16 mutated both to prove it:
	--
	--   * the floor applied ONE COLUMN OFF-CENTRE. On a monotone slope the
	--     highest column of a square is its own end, so the envelope puts the
	--     level back where it belongs and nothing moves.
	--   * the other run's window CLIPPED TO THE SQUARE. The research note says
	--     that clamp is exactly what seed 999999999 needed at Highcourt's
	--     north-west ring corner, and the KAT was green without it.
	--
	-- One profile catches both, and it is built to: the ground is FLAT under
	-- the square, and a RIDGE stands on the crossing run's axis eighteen columns
	-- away -- inside `reach`, far outside the square. The plateau's height can
	-- then only come from the other run's envelope reaching over that distance,
	-- so a clipped window computes a different J and the two runs disagree; and
	-- the level over the square comes from the FLOOR and not from the ground
	-- under it, so a floor one column off leaves the square's first column a
	-- node low.
	----------------------------------------------------------------------
	local RIDGE_FROM, RIDGE_TO, RIDGE_Y, PLAIN_Y = 20, 30, 60, 40
	local function ridge(x, z)
		-- The ridge stands on the crossing run's axis (along z), well beyond
		-- the junction square, and the rest of the world is flat.
		if z >= RIDGE_FROM and z <= RIDGE_TO then return RIDGE_Y end
		return PLAIN_Y
	end
	do
		local plan = street_plan.junctions(CROSS_RUNS, avenue.WIDTH)
		local palette = handles.orc
		local levels, plateau_y, square = {}, nil, nil
		for _, spec in ipairs(CROSS_RUNS) do
			local piece = run_of(palette, spec, ridge, nil, plan[spec.id])
			assert(#piece.plateaus == 1, spec.id .. " built " ..
				#piece.plateaus .. " plateaus, not one")
			if plateau_y == nil then
				plateau_y = piece.plateaus[1].y
				square = plan[spec.id][1]
			end
			-- THE TWO RUNS AGREE, and only the full window makes them: the
			-- ridge is 18 columns past the square, so a run that read the other
			-- one's ground over the square alone would answer PLAIN_Y here and
			-- the run that owns the ridge would answer more.
			assert(piece.plateaus[1].y == plateau_y, spec.id ..
				" levels the shared square at " .. piece.plateaus[1].y ..
				" and the other run at " .. plateau_y ..
				": the two windows differ")
			levels[spec.id] = walking(palette, spec, piece)
		end
		-- The ridge really does reach, or the case proves nothing.
		local reached = RIDGE_Y - (RIDGE_FROM - HALF)
		assert(plateau_y > PLAIN_Y, "the ridge did not lift the plateau (" ..
			plateau_y .. " against the flat " .. PLAIN_Y .. ")")
		assert(plateau_y == reached, "the plateau stands at " .. plateau_y ..
			", not at the ridge's own reach " .. reached)
		-- THE PLATEAU IS THE SQUARE AND NOT A COLUMN BESIDE IT: every column of
		-- the square walks at `plateau_y`, and the two columns just outside it
		-- walk strictly lower, because the ground there is flat and the only
		-- thing lifting anything is the floor.
		for _, spec in ipairs(CROSS_RUNS) do
			local level = levels[spec.id]
			for p = square.low, square.high do
				local low, high = flat_row(level, p)
				assert(low == plateau_y and high == plateau_y, spec.id ..
					" walks the square column " .. p .. " at " ..
					tostring(low) .. ".." .. tostring(high) ..
					", not at the plateau " .. plateau_y)
			end
			-- ON THE FLAT RUN ONLY. The ridge stands on the OTHER run's own
			-- axis, so that run legitimately climbs towards it and its columns
			-- beyond the square are higher than the plateau by their own
			-- ground. The run across the flat has nothing but the floor to
			-- lift it, so its square is exactly `width` columns long and the
			-- two beside it are a node lower -- which is what a floor applied
			-- one column off-centre breaks.
			if spec.axis == "x" then
				for _, outside in ipairs({square.low - 1, square.high + 1}) do
					local _, here = flat_row(level, outside)
					assert(here ~= nil, spec.id .. " has no road at " .. outside)
					assert(here == plateau_y - 1, spec.id ..
						" walks the column " .. outside ..
						" -- one outside its square " .. square.low .. ".." ..
						square.high .. " -- at " .. here .. " and not at " ..
						(plateau_y - 1) .. ": the floor is not on the square")
				end
			end
		end
		cases = cases + 1
		say("street_plateau_window", plateau_y, square.low, square.high,
			RIDGE_FROM - HALF)
	end

	----------------------------------------------------------------------
	-- 10. THE PILLAR RHYTHM, AND THE STANDARD THAT STANDS ON ONE.
	--
	-- `M.PIER` is the rhythm of the pillars under a bridge and a viaduct, and
	-- it is deliberately the lamp rhythm as well, "so a standard on a bridge or
	-- a viaduct stands on a pier rather than beside one" (`avenue.lua`). The
	-- review doubled `M.PIER` to 16 and no section noticed: half the standards
	-- on Lethariel's own bridge would then be three courses of post on a plank
	-- with open water under it.
	--
	-- So the property is the sentence itself -- every standard over water or
	-- over air stands on a pillar -- plus the rhythm read off the cells.
	----------------------------------------------------------------------
	do
		local checked, standards = 0, 0
		for _, race in ipairs(RACES) do
			local palette = handles[race]
			local spec = {id = "rhythm", axis = "x", at = 0,
				from = -48, to = 48}
			local piece = run_of(palette, spec, lake, lake_wet)
			local PIER = palette.maybe("signature") or
				palette.node("wall_accent")
			local PLANK = palette.node("floor")
			local written = {}
			local pier_at = {}
			for _, cell in ipairs(piece.cells) do
				written[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name
				if cell.name == PIER and math.abs(cell.z) == VERGE then
					pier_at[cell.x] = true
				end
			end
			-- Every pillar position is on the rhythm, and every position on the
			-- rhythm inside the span carries one.
			for p = WET_FROM, WET_TO do
				local wanted = ((p - spec.from) % avenue.PIER == 0)
				assert((pier_at[p] and true or false) == wanted, race ..
					": the column " .. p .. " " ..
					(pier_at[p] and "carries" or "carries no") ..
					" pillar, and the rhythm of " .. avenue.PIER ..
					" says it should " .. (wanted and "" or "not ") .. "have one")
				checked = checked + 1
			end
			-- AND EVERY STANDARD OVER THE WATER STANDS ON ONE.
			for _, lamp in ipairs(piece.lamps) do
				if lamp.x >= WET_FROM and lamp.x <= WET_TO then
					local foot = lamp.y - 3
					assert(written[lamp.x .. ":" .. foot .. ":" .. lamp.z] ==
						PLANK, race .. ": a standard at " .. lamp.x ..
						" does not foot on the plank walk")
					assert(written[lamp.x .. ":" .. (foot - 1) .. ":" ..
						lamp.z] == PIER, race .. ": the standard at " ..
						lamp.x .. " has no pillar under its plank -- the pier " ..
						"rhythm (" .. avenue.PIER .. ") has left the lamp " ..
						"rhythm (" .. avenue.LAMP_SPACING .. ")")
					standards = standards + 1
				end
			end
		end
		assert(standards > 0, "no standard of this bridge is over the water")
		cases = cases + 1
		say("street_pier_rhythm", avenue.PIER, avenue.LAMP_SPACING, checked,
			standards)
	end

	----------------------------------------------------------------------
	-- 11. THE VERGE ENDS AT THE JOINING STREET (playtest 6, 2026-09-16).
	--
	-- A verge lane is one node OUTSIDE its own carriageway, so at a crossing,
	-- at a corner and at a T-joint it runs straight ACROSS the road that
	-- joins. The user walked into two of them in one session:
	--
	--   * Lethariel ~1900,-1400 -- the north-east ring corner over the mere,
	--     where `ring_east` ends at z = 96 and `ring_north` at x = 96: "two
	--     street ends meet on a bridge over water; the rail of each protrudes
	--     into the other street";
	--   * Kezamba ~1800,1595 -- `avenue_north` crossing `ring_north` over
	--     water: "the side rails leave only a one-node gap into the crossing".
	--
	-- The ruling: "railings, fences, verge posts and pillars end at the
	-- crossing square; the plateau square is rail-free towards every street
	-- that joins it", and the deck itself stays continuous.
	--
	-- Both shapes are built here over a POND, so every position of both runs
	-- is a bridge and the verge carries plank, rail and pillar the whole way --
	-- which is the case that has furniture to put in the wrong place. Three
	-- things are asserted, and the second is what stops the rule from being
	-- "write no verge at all":
	--
	--   (a) no cell on a verge lane stands inside another run's carriageway;
	--   (b) the parapet on the OUTSIDE of the corner, where no street joins,
	--       is still there -- the clearance is per SIDE;
	--   (c) every column the verge handed over is paved by the run that joins,
	--       at the same walking level, so the deck is continuous and a player
	--       walks from either street into the square and out again.
	----------------------------------------------------------------------
	local POND, POND_EDGE = 40, 24
	local function pond(x, z)
		local dx = 0
		if x < -POND_EDGE then dx = -POND_EDGE - x end
		if x > POND_EDGE then dx = x - POND_EDGE end
		local dz = 0
		if z < -POND_EDGE then dz = -POND_EDGE - z end
		if z > POND_EDGE then dz = z - POND_EDGE end
		return POND + ((dx > dz) and dx or dz)
	end
	local function pond_wet(x, z)
		return x >= -POND_EDGE and x <= POND_EDGE and
			z >= -POND_EDGE and z <= POND_EDGE
	end
	-- A CROSSING in the middle of the pond, and a CORNER whose two runs END on
	-- each other at (20, 20) -- the shape of Lethariel's ring corner.
	local VERGE_CASES = {
		{name = "crossing", runs = {
			{id = "avenue", axis = "x", at = 0, from = -48, to = 48},
			{id = "lane", axis = "z", at = 0, from = -48, to = 48}}},
		{name = "corner", runs = {
			{id = "ring_east", axis = "z", at = 20, from = -48, to = 20},
			{id = "ring_north", axis = "x", at = 20, from = -48, to = 20}}},
	}
	do
		local palette = handles.elf
		local RAIL = palette.node("railing")
		local PAVING = palette.maybe("castle_paving") or palette.node("plaza")
		local KERB = palette.node("plaza_edge")
		local TREAD = palette.maybe("castle_wall_stair") or
			palette.node("roof_stair")
		local PLANK = palette.node("floor")
		local ROAD = {[PAVING] = true, [KERB] = true, [TREAD] = true}
		local intruded, cleared_total, kept_outside, handed_over = 0, 0, 0, 0
		for _, case in ipairs(VERGE_CASES) do
			local attached = street_plan.attach(case.runs, avenue.WIDTH)
			-- The same runs WITHOUT the clearance, so the case proves the rule
			-- fires rather than that the geometry had no furniture in it.
			local bare_pieces, pieces = {}, {}
			local rect = {}
			for _, spec in ipairs(attached) do
				local piece = avenue.run(palette, {id = spec.id,
					axis = spec.axis, at = spec.at, from = spec.from,
					to = spec.to, width = avenue.WIDTH,
					lamp_spacing = avenue.LAMP_SPACING, lamp_phase = spec.lamp_phase or spec.from,
					reach = avenue.REACH, wet = pond_wet,
					junctions = spec.junctions,
					clear_verge = spec.clear_verge}, pond)
				local bare = avenue.run(palette, {id = spec.id,
					axis = spec.axis, at = spec.at, from = spec.from,
					to = spec.to, width = avenue.WIDTH,
					lamp_spacing = avenue.LAMP_SPACING, lamp_phase = spec.lamp_phase or spec.from,
					reach = avenue.REACH, wet = pond_wet,
					junctions = spec.junctions}, pond)
				pieces[spec.id] = piece
				bare_pieces[spec.id] = bare
				if spec.axis == "x" then
					rect[spec.id] = {min_x = spec.from, max_x = spec.to,
						min_z = spec.at - HALF, max_z = spec.at + HALF}
				else
					rect[spec.id] = {min_z = spec.from, max_z = spec.to,
						min_x = spec.at - HALF, max_x = spec.at + HALF}
				end
			end
			local function in_other_road(id, x, z)
				for other_id, box in pairs(rect) do
					if other_id ~= id and x >= box.min_x and x <= box.max_x and
							z >= box.min_z and z <= box.max_z then
						return true
					end
				end
				return false
			end
			local function verge_cells_in_road(source)
				local count = 0
				for _, spec in ipairs(attached) do
					local dx = (spec.axis == "x") and 1 or 0
					for _, cell in ipairs(source[spec.id].cells) do
						local lane = ((dx == 1) and cell.z or cell.x) - spec.at
						if (lane == -VERGE or lane == VERGE) and
								in_other_road(spec.id, cell.x, cell.z) then
							count = count + 1
						end
					end
				end
				return count
			end
			-- (a) NOTHING OF THE VERGE STANDS IN THE OTHER ROAD any more, and
			-- the same geometry without the rule has plenty.
			local before = verge_cells_in_road(bare_pieces)
			local after = verge_cells_in_road(pieces)
			assert(before > 0, case.name ..
				": this case has no verge furniture in the joining road at " ..
				"all, so the rule is untested")
			assert(after == 0, case.name .. ": " .. after .. " of " .. before ..
				" verge cells still stand inside the joining street's " ..
				"carriageway")
			intruded = intruded + before
			cleared_total = cleared_total + (before - after)
			-- (b) AND THE PARAPET OUTSIDE THE CORNER SURVIVES. `ring_east`'s
			-- x+ verge is outside `ring_north`'s span, so nothing joins there
			-- and the rail has to stay; a clearance that blanked both sides of
			-- a position would leave a hole in the bridge parapet.
			if case.name == "corner" then
				local kept = 0
				for _, cell in ipairs(pieces.ring_east.cells) do
					if cell.name == RAIL and cell.x == 20 + VERGE and
							cell.z >= 18 and cell.z <= 20 then
						kept = kept + 1
					end
				end
				assert(kept == 3, "the corner's outer parapet carries " ..
					kept .. " of its three rail cells")
				kept_outside = kept_outside + kept
			end
			-- (c) THE DECK IS CONTINUOUS. Every column either run writes a
			-- walking surface on -- carriageway and verge alike -- is read the
			-- way the seam reads it (the highest cell that is not furniture),
			-- and every column the verge handed over has to be paved by the
			-- run that joins, no more than a node from a neighbour's level.
			local top = {}
			for _, spec in ipairs(attached) do
				local dx = (spec.axis == "x") and 1 or 0
				for _, cell in ipairs(pieces[spec.id].cells) do
					local lane = ((dx == 1) and cell.z or cell.x) - spec.at
					if (ROAD[cell.name] or cell.name == PLANK) and
							lane >= -VERGE and lane <= VERGE then
						local key = cell.x .. ":" .. cell.z
						if top[key] == nil or cell.y > top[key] then
							top[key] = cell.y
						end
					end
				end
			end
			for _, spec in ipairs(attached) do
				local dx = (spec.axis == "x") and 1 or 0
				for _, side in ipairs({-VERGE, VERGE}) do
					for p = spec.from, spec.to do
						local x, z
						if dx == 1 then x, z = p, spec.at + side
						else x, z = spec.at + side, p end
						if in_other_road(spec.id, x, z) then
							assert(top[x .. ":" .. z] ~= nil, case.name ..
								": the column " .. x .. "," .. z ..
								" gave up its verge and nothing paved it")
							handed_over = handed_over + 1
						end
					end
				end
			end
			-- AND NO STEP APPEARED WHERE THE HANDOVER HAPPENS.
			local worst = 0
			for key, y in pairs(top) do
				local x, z = key:match("^(-?%d+):(-?%d+)$")
				x, z = tonumber(x), tonumber(z)
				for _, step in ipairs({{1, 0}, {0, 1}}) do
					local other = top[(x + step[1]) .. ":" .. (z + step[2])]
					if other then
						local delta = y - other
						if delta < 0 then delta = -delta end
						if delta > worst then worst = delta end
					end
				end
			end
			assert(worst <= 1, case.name ..
				": the joined road steps " .. worst .. " nodes somewhere")
		end
		assert(cleared_total > 0, "the clearance removed nothing")
		-- (d) AND A PIECE OF SUCH A RUN IS STILL EXACTLY THAT STRETCH OF IT.
		-- Section 7 cuts the cases it was written for; the clearance is a new
		-- per-position input and a successor emerges a street one mapchunk at a
		-- time, so the crossing's own avenue is cut at EVERY column here and the
		-- union of the two pieces compared with the whole.
		local splits = 0
		do
			local runs = street_plan.attach(VERGE_CASES[1].runs, avenue.WIDTH)
			local spec
			for _, entry in ipairs(runs) do
				if entry.id == "avenue" then spec = entry end
			end
			local function build(from, to)
				return avenue.run(palette, {id = spec.id, axis = spec.axis,
					at = spec.at, from = from, to = to, width = avenue.WIDTH,
					lamp_spacing = avenue.LAMP_SPACING,
					lamp_phase = spec.lamp_phase or spec.from, reach = avenue.REACH,
					wet = pond_wet, junctions = spec.junctions,
					clear_verge = spec.clear_verge}, pond)
			end
			local whole = build(spec.from, spec.to)
			local expected = {}
			for _, cell in ipairs(whole.cells) do
				expected[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
					cell.name .. ":" .. (cell.param2 or 0)
			end
			for cut = spec.from, spec.to - 1 do
				local union, count = {}, 0
				for _, part in ipairs({{spec.from, cut}, {cut + 1, spec.to}}) do
					local piece = build(part[1], part[2])
					for _, cell in ipairs(piece.cells) do
						local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
						local value = cell.name .. ":" .. (cell.param2 or 0)
						assert(expected[key] == value,
							"the cleared piece cut at " .. cut .. " writes " ..
							value .. " at " .. key ..
							", which the whole run does not")
						if union[key] == nil then
							union[key] = value
							count = count + 1
						end
					end
				end
				assert(count == #whole.cells, "the two cleared pieces cut at " ..
					cut .. " carry " .. count .. " cells, the whole run " ..
					#whole.cells)
				splits = splits + 1
			end
		end
		cases = cases + 1
		say("street_verge_clearance", intruded, cleared_total, kept_outside,
			handed_over, splits)
	end

	assert(cases == 11, "a street case was lost")
	say("street_cases", cases, "width", avenue.WIDTH, "min_clear", CLEAR,
		"lift", avenue.LIFT, "pier", avenue.PIER)
	return table.concat(report)
end
