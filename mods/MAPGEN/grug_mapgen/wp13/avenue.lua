-- WP13 capital avenues: the surface overlay that carries a gate road across
-- terraced ground.
--
-- The capitals contract (docs/research/wp13-capitals-pois-contract.md section
-- 2.1) gives a capital four avenues from the core edge to the four gate
-- stations, and says what they are: "pavement at surface, one stair node at
-- each terrace rise, lamp posts every 8 nodes, no height queries". The last
-- clause is the design: a blueprint is anchor-relative and an avenue is not,
-- because WP40's terraces put every node of it at a different height, so the
-- avenue cannot be authored as cells at all. It is authored as a FUNCTION of
-- the column surface, and the surface arrives through one callback the caller
-- owns.
--
-- That makes this module the one piece of WP13 a successor can run per
-- mapchunk: give it the run and a `surface(x, z)` that answers for the
-- columns of the chunk it is emerging, and it yields the cells of that piece
-- of road and nothing else. It queries no height of its own, reads no engine
-- and keeps no state; two calls with the same arguments produce the identical
-- cell list.
--
-- Where the contract's sentence is not enough
-- -------------------------------------------
-- "One stair node at each terrace rise" is one stair per NODE of rise, not
-- one per rise. A player walks up half a node and jumps a whole one, and the
-- race terrace steps of WP40 are 2 (human), 3 (elf, undead, troll) and 4
-- (dwarf, orc), so a single stair in front of a two-node rise leaves the
-- second node to be jumped, which is not a road.
--
-- The first version of this module built a flight per joint and it was wrong
-- twice, in ways a per-joint rule cannot be right: two joints closer than
-- their flights fought over the columns between them and left a wall, and a
-- joint that fell on the border between two PIECES of the run was walked by
-- neither, so a road emerged one mapchunk at a time grew a four-node step
-- where a single call had a flight.
--
-- What replaces it is one rule with no joints in it: the road's walking
-- level is the ONE-LIPSCHITZ UPPER ENVELOPE of the ground -- the lowest
-- height field that is everywhere at or above the surface and never changes
-- by more than a node between two columns. Fill carries each column up to
-- its envelope and a tread caps it wherever the envelope stands above the
-- ground or above a neighbour, because a one-node change is walked as the
-- two halves of a stair. A rise of `h` still climbs over `h` columns; two
-- joints in a row simply make the road leave the ground earlier; and the
-- envelope of a column depends on the ground within `REACH` columns of it
-- and on nothing else, which is what makes a piece of the run equal to that
-- stretch of the whole.
--
-- Every lane of the road is profiled on its own, because a terrace joint
-- crossing the road at an angle arrives at the five lanes in five different
-- columns; a per-lane envelope follows it, a road-wide one would step where
-- the ground does not.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The capitals contract's own numbers.
	M.WIDTH = 5
	M.LAMP_SPACING = 8
	-- How far beyond a piece the ground is read; see the carriageway below.
	M.REACH = 40

	-- THE AIR A ROAD NEEDS UNDER SOMETHING THAT SPANS IT.
	--
	-- WP40's long-distance routes bridge the same rivers a capital's streets
	-- do, and a bridge deck is written as three courses: the walking surface
	-- at the route's own height, the support one course under it, and open
	-- air below that. So the UNDERSIDE of a deck whose surface is `d` is
	-- `d - 1`, and a road walked at `t` has `d - 1 - t - 1` blocks of air
	-- over it.
	--
	-- Three is the number, and it is the same number twice over: a player is
	-- two nodes tall, so two is the bare minimum and three is a corridor
	-- rather than a crawlspace; and a lamp standard is three courses of post
	-- and torch above its own footing, so a verge with three blocks of air is
	-- exactly a verge that can still be lit.
	M.MIN_CLEAR = 3
	-- HOW MANY PASSES THE CROSSING RULE MAY TAKE, and what is actually known
	-- about that.
	--
	-- PROVED: the iteration terminates. It only ever raises a column's ground,
	-- and it never raises one above the highest deck in the window, so it is
	-- monotone and bounded and cannot run forever.
	--
	-- NOT PROVED: a tight pass count. What decides it is the SHAPE of the deck.
	-- A LEVEL deck settles at once -- every column of it conflicts in the same
	-- pass and is raised in the same pass -- and a second pass only picks up
	-- the neighbours the first one lifted into it. A deck that CLIMBS one node
	-- per column does not: the far end of it clears the road until the raise
	-- has walked towards it, so such a deck takes on the order of one pass per
	-- two columns of its span. Every WP40 deck is level (`wp40/planner.lua`
	-- writes one `functional_y` per crossing run and the planner pins it), so
	-- the climbing case is unreachable today and the measured capitals settle
	-- in one or two passes -- but the bound may not assume that, because a
	-- bound that is wrong aborts a mapchunk instead of catching a bug.
	--
	-- So the bound is derived from the run's own window: one pass per column
	-- of it, plus a margin. That is above the worst shape a deck inside the
	-- window can have, and it still turns a rule that did not converge into a
	-- loud failure rather than a hung mapchunk.
	local function raise_pass_limit(low_end, high_end)
		return (high_end - low_end) + 2
	end

	-- The avenue vocabulary, each with its fallback into the start
	-- vocabulary, exactly as `capitals.lua` resolves the same roles: the
	-- capital roles are optional and a palette that has not been given them
	-- still builds a road.
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function kerb(palette)
		return palette.node("plaza_edge")
	end
	local function tread(palette)
		return palette.maybe("castle_wall_stair") or palette.node("roof_stair")
	end

	-- Every node name a run may write, in ASCII byte order and without
	-- duplicates. The seam needs it because an overlay has NO CELLS until a
	-- surface is handed to it, so the one thing its identity can be written
	-- from is its specification, and the palette is part of that
	-- specification (`wp40/r7_settlement.lua`, the "overlay" blueprint kind).
	-- It is also what lets a settlement's shared content channel carry the
	-- road: the channel is closed at load, and a name the road can write but
	-- the channel does not know would only fail on the mapchunk that finally
	-- needs it.
	--
	-- Derived from the same four resolvers the run itself uses plus the two
	-- names the standard is built from, so a change to any of them cannot
	-- leave this list behind.
	function M.palette_names(palette)
		local names, seen, list = {paving(palette), kerb(palette),
			tread(palette), palette.node("post"),
			palette.node("light_post")}, {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 avenue: the palette has no name for a road role", 0)
			end
			if not seen[name] then
				seen[name] = true
				list[#list + 1] = name
			end
		end
		table.sort(list, parts.less_bytes)
		return list
	end

	local function axis_steps(axis)
		if axis == "x" then return 1, 0 end
		if axis == "z" then return 0, 1 end
		error("wp13 avenue: unknown axis " .. tostring(axis), 0)
	end

	-- One run of avenue.
	--
	-- `spec`:
	--   axis          "x" or "z", the direction the road runs
	--   at            the OTHER coordinate: the centre line of the road
	--   from, to      inclusive span along `axis`, from <= to
	--   width         odd, default 5 (the contract's gate corridor)
	--   lamp_spacing  default 8
	--   lamp_phase    the position along `axis` the lamp rhythm is anchored
	--                 to, default `from`; a successor emerging the road in
	--                 pieces passes the same phase for every piece, which is
	--                 what keeps one lamp line across a chunk border
	--   id            a label carried into the returned table
	--   overhead      optional `overhead(x, z)`; see THE CROSSING RULE below
	--
	-- `surface(x, z)` returns the y of the topmost terrain node of that
	-- column. It is called exactly once per column this run touches and is
	-- the ONLY source of ground height in here.
	--
	-- Returns `{cells, lamps, pavement, treads, risers, columns, queries,
	-- overhead_queries, crossings}`: `cells` is the canonical cell list (z,
	-- then y, then x) a writer can project directly, `lamps` the lamp
	-- positions for a lighting landmark, `crossings` one row per column that
	-- a deck spans, and the counts are what the KAT holds the run to.
	function M.run(palette, spec, surface)
		if type(surface) ~= "function" then
			error("wp13 avenue: a run needs a surface callback", 0)
		end
		local overhead = spec.overhead
		if overhead ~= nil and type(overhead) ~= "function" then
			error("wp13 avenue: the overhead seam is not a callback", 0)
		end
		local dx, dz = axis_steps(spec.axis)
		local from, to = spec.from, spec.to
		if type(from) ~= "number" or type(to) ~= "number" or from > to then
			error("wp13 avenue: the run has no span", 0)
		end
		local width = spec.width or M.WIDTH
		if width % 2 ~= 1 or width < 3 then
			error("wp13 avenue: the width " .. tostring(width) ..
				" is not an odd carriageway", 0)
		end
		local half = (width - 1) / 2
		local spacing = spec.lamp_spacing or M.LAMP_SPACING
		local phase = spec.lamp_phase or from
		local at = spec.at
		local buf = parts.buffer()
		local lamps = {}
		local crossings = {}
		local queries, overhead_queries = 0, 0

		-- The column (x, z) of position `p` along the run, `offset` lanes to
		-- the side. The side runs with the axis: +x is offset +1 for a road
		-- along z, +z for a road along x, so a lane index means the same
		-- hand of the road whichever way it points.
		local function column(p, offset)
			if dx == 1 then return p, at + offset end
			return at + offset, p
		end
		local function height(x, z)
			local y = surface(x, z)
			queries = queries + 1
			if type(y) ~= "number" or y % 1 ~= 0 then
				error("wp13 avenue: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- The walking surface of whatever spans this column, or nil where
		-- nothing does. Asked exactly once per column, like the ground.
		local function deck_at(x, z)
			if not overhead then return nil end
			local y = overhead(x, z)
			overhead_queries = overhead_queries + 1
			if y == nil then return nil end
			if type(y) ~= "number" or y % 1 ~= 0 then
				error("wp13 avenue: the overhead at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- THE CROSSING RULE.
		--
		-- A road of this module and a WP40 route are two different things
		-- built by two different authorities, and where the route crosses the
		-- capital on a bridge the two meet in the air: the deck's underside
		-- passes over the street. The playtest found the case this leaves --
		-- a district lane with one block of air over it, which is a lane a
		-- player cannot walk and therefore a lane that DEAD ENDS at the route.
		--
		-- The rule, and it is one sentence: a column the road can walk under
		-- with `MIN_CLEAR` blocks of air passes under unchanged; a column it
		-- cannot, the road CLIMBS ONTO, so the street joins the route's own
		-- surface and carries on down the far side.
		--
		-- It is expressed as a change of the column's GROUND and nothing
		-- else, which is what makes it one rule rather than a special case:
		--
		--   * the road stands on the deck instead of on the river bed, so it
		--     writes one paving cell at the deck and does NOT fill the
		--     bridge's own airspace from the water up -- a lane that filled
		--     would be a dam with a road on it;
		--   * the one-Lipschitz envelope above does the rest by itself. A
		--     raised column lifts its neighbours a node at a time, on BOTH
		--     sides, which is exactly the "raised in one-block ground steps
		--     up to route grade, and crosses at grade" the ruling asks for,
		--     built out of the climb the road already uses for a terrace.
		--
		-- IT IS A FIXED POINT, because the test is against the road's WALKING
		-- level and not against the raw ground: a column with five blocks of
		-- air under the deck can still be lifted into it by a terrace forty
		-- columns away. Raising a column can only raise the envelope, and a
		-- raised column is never lowered, so the iteration is monotone and
		-- stops. The two gate seeds settle in one pass (a single crossing) and
		-- two (a crossing whose raise pulls its neighbours into the deck as
		-- well).
		--
		-- AND IT IS DECIDED ACROSS THE WHOLE CARRIAGEWAY, which is the one
		-- place this rule does NOT follow the per-lane profiling above. A
		-- lane is profiled on its own because a terrace crossing the road at
		-- an angle reaches the five lanes in five different columns and the
		-- difference is a node or two. A bridge is not a terrace: its deck is
		-- six nodes over the water, and a road that sent three lanes over the
		-- bridge and left two under it would be a street with a six-node wall
		-- down the middle of it. A crossing is a crossing of the whole road,
		-- so the decision is taken per POSITION along the run and applied to
		-- every lane of that position.
		--
		-- Each lane keeps `bare`, the envelope of its UNTOUCHED ground -- the
		-- road this module would have built with no route geometry at all.
		-- The difference between that and the settled level is exactly the
		-- stretch the crossing rule moved, ramps included, and the LAMPS need
		-- it: a standard is not part of the carriageway and has no envelope of
		-- its own, so without it a verge beside a crossing keeps its
		-- river-level ground and the standard ends up under the road.
		local function resolve_profiles(low_end, high_end, lanes)
			local limit = raise_pass_limit(low_end, high_end)
			for pass = 0, limit do
				for index = 1, #lanes do
					local lane = lanes[index]
					local ground, level = lane.ground, lane.level
					for p = low_end, high_end do level[p] = ground[p] end
					for p = low_end + 1, high_end do
						if level[p] < level[p - 1] - 1 then level[p] = level[p - 1] - 1 end
					end
					for p = high_end - 1, low_end, -1 do
						if level[p] < level[p + 1] - 1 then level[p] = level[p + 1] - 1 end
					end
					-- The first pass runs on ground nothing has raised yet, so
					-- its envelope IS the bare road.
					if pass == 0 then
						local bare = {}
						for p = low_end, high_end do bare[p] = level[p] end
						lane.bare = bare
					end
				end
				local raised = false
				for p = low_end, high_end do
					-- The grade this position has to reach: the highest deck any
					-- lane of it cannot pass under. `d - 1` is the deck's
					-- underside and the air over the road is
					-- `d - 1 - level[p] - 1`, so "fewer than MIN_CLEAR" reads
					-- `level[p] > d - MIN_CLEAR - 2`.
					local target
					for index = 1, #lanes do
						local lane = lanes[index]
						local d = lane.deck[p]
						if d ~= nil and lane.ground[p] < d and
								lane.level[p] > d - M.MIN_CLEAR - 2 and
								(target == nil or d > target) then
							target = d
						end
					end
					if target ~= nil then
						for index = 1, #lanes do
							local lane = lanes[index]
							if lane.ground[p] < target then
								lane.ground[p] = target
								raised = true
							end
						end
					end
				end
				if not raised then return pass end
			end
			error("wp13 avenue: the crossing rule did not settle in " ..
				limit .. " passes", 0)
		end

		-- 1. The carriageway, lane by lane.
		--
		-- The road's walking level is the ONE-LIPSCHITZ UPPER ENVELOPE of the
		-- lane's own surface: the lowest height field that is everywhere at or
		-- above the ground and never changes by more than one node between two
		-- columns. A column whose envelope stands above its ground is filled up
		-- to one course below it and capped with a tread; a column whose
		-- envelope is higher than a neighbour's is a step and is capped with a
		-- tread too, because a one-node change is walked as two half nodes --
		-- the tread's own lower half and its raised half -- and a full cube
		-- there would be a node to jump.
		--
		-- That single rule replaces the per-joint flights the first version
		-- built, and it is what makes the road work where those did not:
		--
		--   * a rise of `h` still climbs over `h` columns, one half node at a
		--     time, which is the contract's stair per terrace rise generalised
		--     to the two-, three- and four-node race terrace steps;
		--   * TWO JOINTS CLOSER THAN THEIR FLIGHTS no longer fight over the
		--     columns between them. The envelope simply rises earlier: the
		--     profile 0, 0, 2, 4 is walked as 1, 2, 3, 4 and the road leaves
		--     the ground where it has to, instead of leaving a wall the
		--     per-joint version could not reach back over;
		--   * and it is CHUNK INDEPENDENT. The envelope of a column depends on
		--     the ground within `reach` columns of it and on nothing else, so
		--     the profile is read that far beyond both ends of the piece and
		--     the union of the pieces is the whole run, cell for cell.
		--
		-- `reach` is the distance a terrace can still raise the envelope here.
		-- WP40 terraces the capital envelope within cut 24 and fill 16, so no
		-- column further than 40 away can lift this one: the influence of a
		-- column decays by exactly one node per column of distance. A caller
		-- that knows its own terrain is flatter may pass a smaller `reach`.
		local reach = spec.reach or M.REACH
		local low_end, high_end = from - reach, to + reach
		local pavement, treads, risers = 0, 0, 0
		-- The ground and the route geometry of every lane, read in the same
		-- order as before -- lane by lane, column by column, once each -- and
		-- then resolved together, because the crossing rule is a rule about
		-- the whole carriageway.
		local lanes = {}
		for offset = -half, half do
			local lane = {offset = offset, ground = {}, level = {},
				deck = {}, natural = {}}
			for p = low_end, high_end do
				local x, z = column(p, offset)
				lane.ground[p] = height(x, z)
				lane.natural[p] = lane.ground[p]
				lane.deck[p] = deck_at(x, z)
			end
			lanes[#lanes + 1] = lane
		end
		local raise_passes = resolve_profiles(low_end, high_end, lanes)
		-- The kerb lane a verge stands beside, per verge, so a standard can be
		-- carried at the level of the road it lights.
		local kerb_lane = {[-half - 1] = lanes[1], [half + 1] = lanes[#lanes]}
		for lane_index = 1, #lanes do
			local lane = lanes[lane_index]
			local offset = lane.offset
			local ground, level, deck, natural =
				lane.ground, lane.level, lane.deck, lane.natural
			local surface_name = (offset == -half or offset == half) and
				kerb(palette) or paving(palette)
			for p = from, to do
				local x, z = column(p, offset)
				local top = level[p]
				-- WHAT THE COLUMN STANDS ON.
				--
				-- Ordinarily the ground it was read from. A column the
				-- crossing rule raised stands on the DECK where it has one --
				-- the bridge carries the road, so the road does not fill the
				-- river up to it, which would be a dam with a street on top --
				-- and on its own ground where it has not, because a bridge
				-- narrower than the carriageway leaves the outer lanes an
				-- abutment to build, and an abutment is solid or the road
				-- beside the deck hangs in the air.
				local base = natural[p]
				local spanned = deck[p]
				if spanned ~= nil and ground[p] > base and spanned >= base and
						spanned <= ground[p] then
					base = spanned
				end
				for y = base, top - 1 do
					buf:put(x, y, z, surface_name)
					if y == base then
						pavement = pavement + 1
					else
						risers = risers + 1
					end
				end
				local before, after = level[p - 1], level[p + 1]
				if top > before or top > after then
					-- A step. The raised half faces the higher neighbour, which is
					-- the way a walker climbs it; a column higher than both is
					-- walked over either half, so the run's own direction decides.
					local sign = (after >= before) and 1 or -1
					parts.stair(buf, x, top, z, tread(palette),
						parts.step_facedir(dx * sign, dz * sign))
					treads = treads + 1
				else
					buf:put(x, top, z, surface_name)
				end
				if top == base then pavement = pavement + 1 end
				-- What the crossing rule decided here, so a KAT and the
				-- measurement tool can hold the built road to the ruling
				-- instead of re-deriving it from the cells.
				if spanned ~= nil then
					crossings[#crossings + 1] = {x = x, y = top, z = z,
						lane = offset, deck_y = spanned, natural = natural[p],
						base = base, clear = spanned - top - 2,
						at_grade = (top >= spanned) and true or false}
				end
			end
		end

		-- 2. The lamps: a standard on each verge, one node outside the
		-- carriageway, every `spacing` nodes. The verge column carries the
		-- lamp at its OWN surface, so a standard beside a terrace joint
		-- stands on the ground it is next to and not on the road's level.
		--
		-- EVERY STANDARD GETS ITS OWN FOOTING, at the verge column's surface and
		-- in the kerb's material. On ordinary ground that cell is already solid
		-- and the footing is a paving stone under the post; over water it is the
		-- only thing between the post and the river. The run cannot tell the two
		-- apart -- it is a pure function of one surface number and knows nothing
		-- about water -- so it lays the footing unconditionally, which is both
		-- correct and cheaper than a rule with a case in it.
		--
		-- This is not hypothetical: the first engine pass of the WP13 seam took
		-- Highcourt's east avenue across a river as a causeway, and sixteen
		-- standards stood in the water with nothing under them.
		--
		-- THE CROSSING RULE REACHES THE VERGE TOO, and here it needs no
		-- envelope: a standard is its footing and three courses over it, so a
		-- verge under a deck has room for one exactly when it has `MIN_CLEAR`
		-- blocks of air -- the same threshold the carriageway is held to. A
		-- verge that has not got it carries its standard on the deck instead,
		-- which is where the road beside it now runs.
		for p = from, to do
			if (p - phase) % spacing == 0 then
				for _, offset in ipairs({-half - 1, half + 1}) do
					local x, z = column(p, offset)
					local y = height(x, z)
					local d = deck_at(x, z)
					if d ~= nil and y < d and y > d - M.MIN_CLEAR - 2 then
						y = d
					end
					-- AND IT COMES UP WITH THE ROAD. The test above is the
					-- verge column's OWN clearance, and that is not enough: a
					-- bridge narrower than the road spans the carriageway and
					-- not the verge, so the verge keeps its river-level ground
					-- and the standard ends up five or six nodes under the
					-- crossing beside it -- post, torch and all, standing in
					-- the water against the abutment. Four standards of the
					-- user seed did exactly that before this rule.
					--
					-- So wherever the crossing rule MOVED the road -- the
					-- crossing itself and the ramps up to it, which is exactly
					-- where the kerb lane stands above the bare road it would
					-- otherwise have been -- the verge is carried with it. A
					-- standard beside an ordinary terrace climb still stands on
					-- its own ground, because there the two levels agree and
					-- this does nothing.
					local beside = kerb_lane[offset]
					if beside.level[p] > beside.bare[p] and
							beside.level[p] > y then
						y = beside.level[p]
					end
					buf:put(x, y, z, kerb(palette))
					buf:put(x, y + 1, z, palette.node("post"))
					buf:put(x, y + 2, z, palette.node("post"))
					parts.floor_torch(buf, palette, x, y + 3, z)
					lamps[#lamps + 1] = {x = x, y = y + 3, z = z}
				end
			end
		end

		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		return {
			id = spec.id, axis = spec.axis, at = at, from = from, to = to,
			width = width, cells = cells, lamps = lamps,
			pavement = pavement, treads = treads, risers = risers,
			crossings = crossings, raise_passes = raise_passes,
			overhead_queries = overhead_queries,
			columns = (to - from + 1) * width, queries = queries,
		}
	end

	return M
end

return loader
