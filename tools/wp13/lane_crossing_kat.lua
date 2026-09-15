-- Acceptance for the crossing rule of `wp13/avenue.lua`: what a capital's
-- street does where a WP40 route passes over it.
--
-- THE RULING (playtest round 3). A bridge deck is written by WP40 as a
-- walking surface with a support course under it, so the underside of a deck
-- whose surface is `d` is `d - 1` and a street walked at `t` has
-- `d - 1 - t - 1` blocks of air over it. Three or more and the street passes
-- under the route unchanged. Fewer and the street is raised in one-block
-- ground steps up to the route's grade and CROSSES IT AT GRADE, on both
-- sides. A street never simply ends at a route.
--
-- `tools/wp13/lane_routes.lua` measures that ruling against the real WP40
-- terrain of the two gate seeds, which is what says the rule was needed and
-- what it did. THIS file is the property: synthetic profiles, no terrain, no
-- engine, both interpreters, and it turns red if the rule stops holding --
-- including on the profiles the real seeds do not happen to contain.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.

return function(repo)
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local palettes = dofile(wp13 .. "/palette.lua")
	local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local human = palettes.new("human")

	local report = {}
	local function say(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	local HALF = (avenue.WIDTH - 1) / 2
	local CLEAR = avenue.MIN_CLEAR

	-- One run along x at z = 0, so a lane index is a z and a position is an x.
	local function build(spec, ground, decks)
		local overhead
		if decks then
			overhead = function(x, z) return decks(x, z) end
		end
		-- The lamp phase is the WHOLE run's start for every piece of it, which
		-- is what the seam passes and what keeps one lamp line across a
		-- mapchunk border.
		return avenue.run(human, {id = spec.id or "kat", axis = "x", at = 0,
			from = spec.from, to = spec.to,
			lamp_phase = spec.lamp_phase or spec.from,
			overhead = overhead}, ground)
	end

	-- The built road, column by column: the topmost cell of each carriageway
	-- column, the lowest, and whether the stack between them is unbroken.
	local function profile(run)
		local top, low, stack, columns = {}, {}, {}, {}
		for _, cell in ipairs(run.cells) do
			if cell.z >= -HALF and cell.z <= HALF then
				local key = cell.x .. ":" .. cell.z
				if top[key] == nil then
					top[key], low[key], stack[key] = cell.y, cell.y, {}
					columns[#columns + 1] = {key = key, x = cell.x, z = cell.z}
				end
				if cell.y > top[key] then top[key] = cell.y end
				if cell.y < low[key] then low[key] = cell.y end
				stack[key][cell.y] = true
			end
		end
		return {top = top, low = low, stack = stack, columns = columns}
	end

	local function same_cells(label, a, b)
		assert(#a.cells == #b.cells, label .. ": " .. #a.cells ..
			" cells against " .. #b.cells)
		for index = 1, #a.cells do
			local one, other = a.cells[index], b.cells[index]
			for _, field in ipairs({"x", "y", "z", "name", "param2"}) do
				assert(one[field] == other[field],
					label .. ": cell " .. index .. " differs on " .. field)
			end
		end
	end

	-- THE PROPERTY, in one place. Every carriageway column of a run:
	--   1. is one unbroken stack, standing on the ground it was read from or
	--      on the deck that carries it -- nothing the road writes hangs in the
	--      air, which is what an abutment beside a narrow bridge is for;
	--   2. is walkable to its neighbour along the run, one node at a time, so
	--      the road never dead ends;
	--   3. passes under a deck with at least CLEAR blocks of air or stands at
	--      or above it, never in between and never inside it;
	--   4. and where any lane of a position joins a deck, EVERY lane of that
	--      position does, so a crossing is a crossing and not a ledge.
	local function verify(label, run, ground, decks)
		local built = profile(run)
		local spanned, joined, passed = 0, 0, 0
		for _, column in ipairs(built.columns) do
			local key = column.key
			for y = built.low[key], built.top[key] do
				assert(built.stack[key][y], label .. ": the column " .. key ..
					" has a hole at " .. y)
			end
			local deck_y = decks and decks(column.x, column.z) or nil
			local natural = ground(column.x, column.z)
			assert(built.low[key] == natural or built.low[key] == deck_y,
				label .. ": the column " .. key .. " starts at " ..
					built.low[key] .. ", neither its ground " .. natural ..
					" nor a deck " .. tostring(deck_y))
			if deck_y ~= nil then
				spanned = spanned + 1
				local road = built.top[key]
				if road >= deck_y then
					joined = joined + 1
				else
					assert(deck_y - road - 2 >= CLEAR, label .. ": the column " ..
						key .. " is walked at " .. road .. " under a deck at " ..
						deck_y .. " -- " .. (deck_y - road - 2) ..
						" blocks of air, not " .. CLEAR)
					passed = passed + 1
				end
			end
		end
		for z = -HALF, HALF do
			for x = run.from, run.to - 1 do
				local here = built.top[x .. ":" .. z]
				local ahead = built.top[(x + 1) .. ":" .. z]
				assert(here and ahead, label .. ": the lane " .. z ..
					" has no surface at " .. x)
				assert(math.abs(ahead - here) <= 1, label .. ": the lane " .. z ..
					" steps " .. (ahead - here) .. " between " .. x .. " and " ..
					(x + 1))
			end
		end
		for x = run.from, run.to do
			local lowest, highest, spans = nil, nil, false
			for z = -HALF, HALF do
				local value = built.top[x .. ":" .. z]
				if lowest == nil or value < lowest then lowest = value end
				if highest == nil or value > highest then highest = value end
				if decks and decks(x, z) ~= nil then spans = true end
			end
			if spans then
				assert(lowest == highest, label .. ": the carriageway at " .. x ..
					" falls " .. (highest - lowest) ..
					" across a column a route spans")
			end
		end
		return spanned, joined, passed
	end

	-- A run cut at `x` is, cell for cell, the run built whole. The crossing
	-- rule raises columns and a raised column lifts its neighbours, so a piece
	-- that could not see the deck would climb differently -- and the border
	-- between two mapchunks is exactly where that would leave a wall.
	local function cut_equals_whole(label, whole, spec, ground, decks, at)
		local union = {}
		for _, side in ipairs({{spec.from, at}, {at + 1, spec.to}}) do
			local piece = build({id = spec.id, from = side[1], to = side[2],
				lamp_phase = spec.from}, ground, decks)
			for _, cell in ipairs(piece.cells) do
				union[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
					cell.name .. ":" .. cell.param2
			end
		end
		for _, cell in ipairs(whole.cells) do
			local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
			assert(union[key] == cell.name .. ":" .. cell.param2,
				label .. ": the cut at " .. at .. " lost " .. key)
			union[key] = nil
		end
		for key in pairs(union) do
			error(label .. ": the cut at " .. at .. " invented " .. key, 0)
		end
	end

	local SPAN = {from = -60, to = 60}
	local cases = 0

	----------------------------------------------------------------------
	-- 1. No route geometry is the road this module built before the rule,
	--    and so is a deck the road already clears.
	----------------------------------------------------------------------
	local function flat(_, _) return 35 end
	local bare = build(SPAN, flat, nil)
	same_cells("a nil overhead", bare, build(SPAN, flat, nil))
	-- A deck at 35 + CLEAR + 2 is the lowest one the road may pass under.
	local function high_deck(x)
		if x >= -5 and x <= 5 then return 35 + CLEAR + 2 end
		return nil
	end
	local cleared = build(SPAN, flat, high_deck)
	same_cells("a deck the road clears", bare, cleared)
	local spanned, joined, passed = verify("cleared", cleared, flat, high_deck)
	assert(spanned == 11 * avenue.WIDTH and joined == 0 and passed == spanned,
		"the cleared deck was not measured: " .. spanned .. "/" .. joined ..
			"/" .. passed)
	cases = cases + 1
	say("lane_crossing_cleared", spanned, passed)

	----------------------------------------------------------------------
	-- 2. THE PLAYTEST CASE. One node of air under the deck: the lane was
	--    unwalkable and therefore ended at the route. It now climbs onto it.
	----------------------------------------------------------------------
	local function low_deck(x)
		if x >= -5 and x <= 5 then return 38 end
		return nil
	end
	local crossed = build(SPAN, flat, low_deck)
	spanned, joined, passed = verify("playtest", crossed, flat, low_deck)
	assert(spanned == 11 * avenue.WIDTH and passed == 0 and joined == spanned,
		"the playtest crossing did not join the route: " .. joined .. "/" ..
			spanned)
	local climbed = profile(crossed)
	for z = -HALF, HALF do
		for x = -5, 5 do
			assert(climbed.top[x .. ":" .. z] == 38,
				"the crossing is not at the route's grade at " .. x .. "," .. z)
		end
		-- One block per column down the approach, on BOTH sides, and back on
		-- the ground before the run ends: a crossing, not a dead end.
		for _, side in ipairs({{-6, -1}, {6, 1}}) do
			for step = 0, 2 do
				local x = side[1] + side[2] * step
				assert(climbed.top[x .. ":" .. z] == 37 - step,
					"the approach at " .. x .. " is " ..
						climbed.top[x .. ":" .. z] .. ", not " .. (37 - step))
			end
		end
		assert(climbed.top[SPAN.from .. ":" .. z] == 35 and
			climbed.top[SPAN.to .. ":" .. z] == 35,
			"the road did not come back down to its own ground")
	end
	-- The raised columns stand on the deck and fill nothing under it: a road
	-- that filled would be a dam across the river the bridge spans.
	for z = -HALF, HALF do
		assert(climbed.low["0:" .. z] == 38,
			"the road under the deck was filled from " .. climbed.low["0:" .. z])
	end
	for _, at in ipairs({-7, -6, -5, -1, 0, 4, 5, 6}) do
		cut_equals_whole("playtest", crossed, SPAN, flat, low_deck, at)
	end
	cases = cases + 1
	say("lane_crossing_playtest", spanned, joined)

	----------------------------------------------------------------------
	-- 3. THE FIXED POINT. The test is against the road's WALKING level, not
	--    its raw ground: this deck has exactly CLEAR blocks over the ground
	--    and none over the road, because a terrace thirty columns away lifts
	--    the envelope into it. A rule that asked the ground would pass it.
	----------------------------------------------------------------------
	local function terraced(x)
		if x >= 20 then return 44 end
		return 35
	end
	local function reached_deck(x)
		if x >= 8 and x <= 12 then return 35 + CLEAR + 2 end
		return nil
	end
	local naive = build(SPAN, terraced, nil)
	local naive_top = profile(naive).top
	local deck_y = 35 + CLEAR + 2
	assert(deck_y - 35 - 2 == CLEAR,
		"the case no longer sits on the threshold from the ground")
	assert(naive_top["12:0"] == 44 - (20 - 12),
		"the terrace did not lift the envelope where the case expects: " ..
			naive_top["12:0"])
	assert(deck_y - naive_top["12:0"] - 2 < CLEAR,
		"the lifted envelope still clears the deck; the case proves nothing")
	local settled = build(SPAN, terraced, reached_deck)
	spanned, joined, passed = verify("fixed point", settled, terraced,
		reached_deck)
	assert(joined > 0, "the fixed point left the road under its own deck")
	assert(settled.raise_passes >= 1,
		"the crossing rule reported no raise pass")
	for _, at in ipairs({7, 8, 10, 12, 13, 19}) do
		cut_equals_whole("fixed point", settled, SPAN, terraced, reached_deck, at)
	end
	cases = cases + 1
	say("lane_crossing_fixed_point", spanned, joined, passed,
		settled.raise_passes)

	----------------------------------------------------------------------
	-- 4. A BRIDGE NARROWER THAN THE ROAD. Three lanes are carried by the
	--    deck and two have to build an abutment. Every lane crosses at the
	--    same grade and none of them hangs in the air.
	----------------------------------------------------------------------
	local function narrow_deck(x, z)
		if x >= -3 and x <= 3 and z >= -HALF and z <= 0 then return 38 end
		return nil
	end
	local narrow = build(SPAN, flat, narrow_deck)
	spanned, joined, passed = verify("narrow bridge", narrow, flat, narrow_deck)
	assert(passed == 0 and joined == spanned,
		"a lane of the narrow crossing did not join")
	local abutment = profile(narrow)
	for z = 1, HALF do
		assert(abutment.top["0:" .. z] == 38 and abutment.low["0:" .. z] == 35,
			"the abutment lane " .. z .. " runs from " ..
				abutment.low["0:" .. z] .. " to " .. abutment.top["0:" .. z] ..
				", not a solid 35..38")
	end
	for z = -HALF, 0 do
		assert(abutment.low["0:" .. z] == 38,
			"the carried lane " .. z .. " filled down to " ..
				abutment.low["0:" .. z])
	end
	cases = cases + 1
	say("lane_crossing_narrow", spanned, joined)

	----------------------------------------------------------------------
	-- 5. THE VERGE. A lamp standard is its footing and three courses over it,
	--    which is exactly CLEAR blocks of air, so a verge that cannot carry
	--    one is a verge the rule lifts onto the deck with the road.
	----------------------------------------------------------------------
	local function verge_deck(x, z)
		if x >= -8 and x <= 8 then
			if math.abs(z) == HALF + 1 then return 38 end
			return 35 + CLEAR + 2
		end
		return nil
	end
	local lit = build(SPAN, flat, verge_deck)
	local standards = 0
	for _, lamp in ipairs(lit.lamps) do
		if lamp.x >= -8 and lamp.x <= 8 then
			standards = standards + 1
			assert(lamp.y == 38 + 3, "a standard under a deck it cannot clear " ..
				"stands at " .. lamp.y .. ", not on the deck")
		end
	end
	assert(standards > 0, "the verge case raised no standard at all")
	local ample = build(SPAN, flat, function(x, z)
		if x >= -8 and x <= 8 then return 35 + CLEAR + 2 end
		return nil
	end)
	for _, lamp in ipairs(ample.lamps) do
		assert(lamp.y == 35 + 3,
			"a standard with room under the deck left its own ground")
	end
	cases = cases + 1
	say("lane_crossing_verge", standards)

	----------------------------------------------------------------------
	-- 6. THE RULE NEVER LOWERS THE ROAD, on any of the profiles above: it is
	--    a rule about getting out from under something, so a column of the
	--    road with route geometry is never below the same column without it.
	----------------------------------------------------------------------
	local lowered = 0
	for _, case in ipairs({{flat, low_deck}, {flat, narrow_deck},
			{terraced, reached_deck}, {flat, verge_deck}}) do
		local without = profile(build(SPAN, case[1], nil)).top
		local with = profile(build(SPAN, case[1], case[2])).top
		for key, value in pairs(without) do
			if with[key] < value then lowered = lowered + 1 end
		end
	end
	assert(lowered == 0, "the crossing rule lowered " .. lowered .. " columns")
	cases = cases + 1
	say("lane_crossing_monotone", lowered)

	----------------------------------------------------------------------
	-- 7. Determinism, and a digest of the built crossing so a silent change
	--    to the rule shows up as a moved value rather than as nothing.
	----------------------------------------------------------------------
	same_cells("determinism", crossed, build(SPAN, flat, low_deck))
	local rows = {}
	for _, cell in ipairs(crossed.cells) do
		rows[#rows + 1] = table.concat({cell.x, cell.y, cell.z, cell.name,
			cell.param2 or 0}, ":")
	end
	say("lane_crossing_digest", #crossed.cells,
		common.hex(common.new_sha256()(table.concat(rows, "\n"))))

	assert(cases == 6, "a crossing case was lost")
	say("lane_crossing_cases", cases, "min_clear", CLEAR)
	return table.concat(report)
end
