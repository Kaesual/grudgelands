-- WP13 capital streets: the surface overlay that carries every road of a
-- capital across terraced ground, over its own water and past the roads it
-- crosses.
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
-- WHAT PLAYTEST 5 (2026-09-16) FOUND, and what this module now is
-- ---------------------------------------------------------------
-- The user walked Dur Brannoc and Lethariel and made five rulings about the
-- streets. Every one of them is a rule of this module now, because a street
-- rule that lives in a capital is a street rule five capitals do not have.
--
--   1. "Streets follow the terrain exactly, a wild mix of stairs and
--      orthogonal one-block jumps." The road is now walked at ONE level per
--      position: the cross profile of a column of the run is flat, and the
--      profile along the run climbs at most a node per column. The earlier
--      version profiled every LANE on its own, which is why a terrace joint
--      crossing the road at an angle left a five-lane staircase across the
--      carriageway -- measured before this change at a cross-profile spread of
--      up to 8 nodes (tools/wp13/street_geometry.lua).
--   2. "The connecting street must be raised artificially at the junction."
--      A junction is a SQUARE PLATEAU on one y and both runs arrive at it at
--      one node a column. See THE JUNCTION PLATEAU.
--   3. The lamp standards followed the ground and stood below or above the
--      road they light. They stand on the ROAD's level now.
--   4. A street raised on a steep slope was a solid wall. A raise of
--      `MIN_CLEAR` or more now stands on PILLARS with open air under it, and
--      only a small raise is still solid ground. See THE VIADUCT.
--   5. Lethariel's piers, rails and deck lanterns over water: "super, I want
--      that in Highcourt (and every other city where it is missing)." Every
--      street of every capital that stands over water is a BRIDGE now, in that
--      race's own palette. See THE BRIDGE.
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
-- THE GROUND THE ENVELOPE IS TAKEN OF IS THE WHOLE CARRIAGEWAY'S, and that is
-- ruling 1. The earlier version took one envelope per lane so that a terrace
-- joint arriving at the five lanes in five different columns was followed
-- exactly; the user's answer is that a street is not meant to follow a joint,
-- it is meant to be walked. So the road's ground at a position is the HIGHEST
-- of its lanes' -- the road is cut into a slope, not laid over it -- and one
-- envelope of that field is the level of every lane of that position.
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

	-- A DECK STANDS ONE NODE OVER THE WATER, and not two: the shore step a
	-- walker takes onto a bridge is exactly that number, and a player jumps
	-- one node. Lethariel's bridge module chose it and the measurement kept it.
	M.LIFT = 1
	-- A PIER EVERY EIGHT COLUMNS, reaching four nodes under the water surface,
	-- which is Lethariel's own rhythm and depth. It is also the lamp rhythm, so
	-- a standard on a bridge or a viaduct stands on a pier rather than beside
	-- one.
	M.PIER = 8
	M.PIER_DEPTH = 4

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

	-- The street vocabulary, each with its fallback into the start
	-- vocabulary, exactly as `capitals.lua` resolves the same roles: the
	-- capital roles are optional and a palette that has not been given them
	-- still builds a road.
	--
	-- `plank`, `railing`, `post` and `pier` are the BRIDGE vocabulary, and all
	-- four of them are required palette roles of every race (`palette.lua`,
	-- `M.required`) except `signature`, which falls back to `wall_accent` the
	-- way every other capital part resolves it. That is why a bridge needs no
	-- new binding in any race: the elf bridge this generalises was already
	-- written out of roles the other five bind too.
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function kerb(palette)
		return palette.node("plaza_edge")
	end
	local function tread(palette)
		return palette.maybe("castle_wall_stair") or palette.node("roof_stair")
	end
	local function plank(palette)
		return palette.node("floor")
	end
	local function railing(palette)
		return palette.node("railing")
	end
	local function pier(palette)
		return palette.maybe("signature") or palette.node("wall_accent")
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
	-- Derived from the same resolvers the run itself uses plus the two names
	-- the standard is built from, so a change to any of them cannot leave this
	-- list behind.
	function M.palette_names(palette)
		local names, seen, list = {paving(palette), kerb(palette),
			tread(palette), plank(palette), railing(palette), pier(palette),
			palette.node("post"), palette.node("light_post")}, {}, {}
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

	-- The one-Lipschitz upper envelope of `field` over `[low, high]`, in place
	-- into `into`: the lowest height field that is everywhere at or above
	-- `field` and never changes by more than a node between two columns. Two
	-- sweeps are enough because the constraint is local and symmetric.
	local function envelope(field, into, low, high)
		for p = low, high do into[p] = field[p] end
		for p = low + 1, high do
			if into[p] < into[p - 1] - 1 then into[p] = into[p - 1] - 1 end
		end
		for p = high - 1, low, -1 do
			if into[p] < into[p + 1] - 1 then into[p] = into[p + 1] - 1 end
		end
		return into
	end

	-- One run of street.
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
	--   wet           optional `wet(x, z)` -> true where planned water stands
	--                 on the column; see THE BRIDGE below
	--   junctions     optional, from `wp13/street_plan.lua`; see THE JUNCTION
	--                 PLATEAU below
	--
	-- `surface(x, z)` returns the y of the topmost terrain node of that
	-- column -- the water surface where water stands on it, which is what the
	-- seam hands an overlay. It is the ONLY source of ground height in here.
	--
	-- Returns `{cells, lamps, ...}`: `cells` is the canonical cell list (z,
	-- then y, then x) a writer can project directly, `lamps` the lamp
	-- positions for a lighting landmark, `crossings` one row per column that a
	-- WP40 deck spans, `plateaus` one row per junction and `street` the counts
	-- the KAT holds the run to.
	function M.run(palette, spec, surface)
		if type(surface) ~= "function" then
			error("wp13 avenue: a run needs a surface callback", 0)
		end
		local overhead = spec.overhead
		if overhead ~= nil and type(overhead) ~= "function" then
			error("wp13 avenue: the overhead seam is not a callback", 0)
		end
		local wet_at = spec.wet
		if wet_at ~= nil and type(wet_at) ~= "function" then
			error("wp13 avenue: the water seam is not a callback", 0)
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
		local verge = half + 1
		local spacing = spec.lamp_spacing or M.LAMP_SPACING
		local phase = spec.lamp_phase or from
		local at = spec.at
		local reach = spec.reach or M.REACH
		local buf = parts.buffer()
		local lamps = {}
		local crossings = {}
		local plateaus = {}
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
		local function wetness(x, z)
			if not wet_at then return false end
			return wet_at(x, z) and true or false
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

		-- ------------------------------------------------------------------
		-- 1. THE ROAD'S OWN GROUND, one number per position.
		--
		-- `natural` keeps every lane's surface, because the fill under the
		-- road and the foot of a pillar stand on the lane's own ground.
		-- `carry` is what the envelope is taken of: the highest of the lanes,
		-- plus the LIFT over a lane that stands in water, so that a wet
		-- position is walked one node clear of the water rather than paved
		-- into it.
		--
		-- THE BRIDGE, and why a lift of one node is all it takes. The seam
		-- hands a road the WATER surface where water stands rather than the bed
		-- under it, so the first version of this module laid a solid CAUSEWAY
		-- at the water line -- which on Lethariel cut a 38 527-column mere into
		-- six lakes and on Highcourt dammed three rivers. The ruling is that a
		-- water body stays ONE body. A wet position therefore gets a DECK and
		-- no fill: the water passes under the road, along the run and across
		-- it, and piers on the two verge lanes carry the deck.
		--
		-- Lethariel's bridge module ramped the lift from nothing at the shore
		-- to one node inside the span, so that the deck stayed one-Lipschitz
		-- and flush with the road it continues. That needed the whole span --
		-- which is why that capital had to commit a measured water mask. It is
		-- not needed: `carry` is the maximum of the lane surfaces and of
		-- `water + LIFT`, and the maximum of two one-Lipschitz fields is
		-- one-Lipschitz, so the envelope of `carry` is flush with the road at
		-- the shore by construction. A wet column is then a PER-COLUMN
		-- question, the mask goes away, and every capital's water is the seam's
		-- own `wet(x, z)` instead of a number somebody measured once.
		local low_end, high_end = from - reach, to + reach
		local natural, wetlane, decklane = {}, {}, {}
		local carry, level, bare = {}, {}, {}
		for offset = -half, half do
			natural[offset], wetlane[offset], decklane[offset] = {}, {}, {}
		end
		for p = low_end, high_end do
			local top
			for offset = -half, half do
				local x, z = column(p, offset)
				local y = height(x, z)
				local soaked = wetness(x, z)
				natural[offset][p] = y
				wetlane[offset][p] = soaked
				decklane[offset][p] = deck_at(x, z)
				local carried = soaked and (y + M.LIFT) or y
				if top == nil or carried > top then top = carried end
			end
			carry[p] = top
		end
		envelope(carry, bare, low_end, high_end)

		-- ------------------------------------------------------------------
		-- 2. THE JUNCTION PLATEAU (ruling 2).
		--
		-- Where two streets cross, the square they share is one y and both runs
		-- arrive at it a node a column. The level of that square has to be the
		-- SAME NUMBER for both runs -- they are built by two separate calls
		-- that never see each other -- so it is defined symmetrically:
		--
		--     J = max( this run's bare envelope over the square,
		--              the other run's bare envelope over the square )
		--
		-- over EVERY run that stands in the square, and nothing else.
		-- `wp13/street_plan.lua` hands each run the squares it shares and which
		-- stretch of each other run they are -- three streets can meet in one
		-- place, and two squares sharing a column are one junction, which is
		-- that module's own header; the other runs' bare envelopes are computed
		-- here from the same `surface` callback, over the same `reach` window,
		-- by the same two sweeps. Every member therefore computes the
		-- identical J.
		--
		-- IT IS THEN APPLIED AS A GROUND FLOOR and not as an override, which is
		-- what makes the approaches right for free: raising the square's ground
		-- to J lifts the one-Lipschitz envelope on both sides a node at a time,
		-- which is exactly "raised artificially at the junction", and the
		-- envelope over the square is then J exactly -- every column of the
		-- square is at J and no column outside it can push a column of the
		-- square above J, because J is already at or above the bare envelope
		-- there.
		--
		-- THE WINDOW IS BOUNDED, which is what keeps a piece of a run equal to
		-- that stretch of the whole: J reads the ground of both runs within
		-- `reach` of the square and of nothing else, and the square is a
		-- function of the two run rectangles, which are static.
		--
		-- WHAT IS NOT PROVED, and is measured instead: two junctions on ONE run
		-- that are closer to each other than the difference of their plateau
		-- levels would each lift the other's square, and the higher one would
		-- leave the lower one a node or two above J. The plateaus of all six
		-- capitals are measured flat on all nine fixture seeds
		-- (tools/wp13/street_geometry.lua, `junc_spread` 0), and
		-- `tools/wp13/street_kat.lua` section 3 is what goes red if a
		-- composition ever authors two crossings that close together.
		local junctions = spec.junctions
		local floor = {}
		if junctions and #junctions > 0 then
			-- The other run's bare envelope, over the window of ITS OWN axis
			-- that can still reach the square. Its lanes are read here and
			-- nowhere else; the square's own columns are read twice, once for
			-- each run, which is the price of two runs agreeing without talking.
			local function other_envelope(other)
				local odx = (other.axis == "x") and 1 or 0
				-- The window is the other run's OWN look-around and is not
				-- clipped to its span: a run reads `reach` columns beyond both
				-- its ends, so clipping here would compute a different envelope
				-- from the one that run computes for itself, and the two sides
				-- of a junction at the very end of a run would then disagree by
				-- a node. Seed 999999999 disagreed by exactly that at
				-- Highcourt's north-west ring corner before this line lost its
				-- clamp.
				local low = other.low - reach
				local high = other.high + reach
				local field, out = {}, {}
				for q = low, high do
					local top
					for offset = -half, half do
						local x, z
						if odx == 1 then x, z = q, other.at + offset
						else x, z = other.at + offset, q end
						local y = height(x, z)
						local carried = wetness(x, z) and (y + M.LIFT) or y
						if top == nil or carried > top then top = carried end
					end
					field[q] = top
				end
				envelope(field, out, low, high)
				local best
				for q = other.low, other.high do
					if best == nil or out[q] > best then best = out[q] end
				end
				return best
			end
			for index = 1, #junctions do
				local junction = junctions[index]
				local best
				for p = junction.low, junction.high do
					local here = bare[p]
					if here ~= nil and (best == nil or here > best) then
						best = here
					end
				end
				local names = {}
				for member = 1, #junction.members do
					local other = junction.members[member]
					names[member] = other.id
					local across = other_envelope(other)
					if across ~= nil and (best == nil or across > best) then
						best = across
					end
				end
				if best ~= nil then
					for p = junction.low, junction.high do
						if floor[p] == nil or best > floor[p] then
							floor[p] = best
						end
					end
					plateaus[#plateaus + 1] = {id = table.concat(names, "+"),
						low = junction.low, high = junction.high, y = best}
				end
			end
		end

		-- ------------------------------------------------------------------
		-- 3. THE CROSSING RULE.
		--
		-- A street of this module and a WP40 route are two different things
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
		-- It is expressed as a change of the position's GROUND and nothing
		-- else, which is what makes it one rule rather than a special case: the
		-- one-Lipschitz envelope does the rest by itself, lifting the
		-- neighbours a node at a time on both sides, which is the "raised in
		-- one-block ground steps up to route grade, and crosses at grade" the
		-- ruling asks for, built out of the climb the road already uses for a
		-- terrace.
		--
		-- IT IS A FIXED POINT, because the test is against the road's WALKING
		-- level and not against the raw ground: a column with five blocks of
		-- air under the deck can still be lifted into it by a terrace forty
		-- columns away. Raising a column can only raise the envelope, and a
		-- raised column is never lowered, so the iteration is monotone and
		-- stops.
		--
		-- AND IT IS DECIDED ACROSS THE WHOLE CARRIAGEWAY. A bridge is not a
		-- terrace: its deck is six nodes over the water, and a road that sent
		-- three lanes over the bridge and left two under it would be a street
		-- with a six-node wall down the middle of it. Since ruling 1 the whole
		-- carriageway is one profile anyway, so this is now the only shape the
		-- rule can have.
		local ground = {}
		for p = low_end, high_end do
			local base = carry[p]
			local raised = floor[p]
			if raised ~= nil and raised > base then base = raised end
			ground[p] = base
		end
		local raise_passes = 0
		do
			local limit = raise_pass_limit(low_end, high_end)
			local settled = false
			for pass = 0, limit do
				envelope(ground, level, low_end, high_end)
				local moved = false
				for p = low_end, high_end do
					local target
					for offset = -half, half do
						local d = decklane[offset][p]
						-- `d - 1` is the deck's underside and the air over the
						-- road is `d - 1 - level[p] - 1`, so "fewer than
						-- MIN_CLEAR" reads `level[p] > d - MIN_CLEAR - 2`.
						if d ~= nil and ground[p] < d and
								level[p] > d - M.MIN_CLEAR - 2 and
								(target == nil or d > target) then
							target = d
						end
					end
					if target ~= nil and ground[p] < target then
						ground[p] = target
						moved = true
					end
				end
				if not moved then
					raise_passes = pass
					settled = true
					break
				end
			end
			if not settled then
				error("wp13 avenue: the crossing rule did not settle in " ..
					raise_pass_limit(low_end, high_end) .. " passes", 0)
			end
		end

		-- ------------------------------------------------------------------
		-- 4. THE CELLS.
		--
		-- One position at a time, and every lane of it at the same `level[p]`.
		--
		-- WHAT CARRIES THE ROAD, and this is ruling 4. A position standing at
		-- most `MIN_CLEAR - 1` nodes above its own ground is FILLED, because a
		-- terrace stair on fill is a road and not a wall. A position standing
		-- `MIN_CLEAR` or more above it -- or over water -- is a VIADUCT: the
		-- deck course and nothing under it but pillars every `PIER` columns on
		-- the two verge lanes, so a player walks under the street instead of
		-- into it and the water under a bridge stays one body. `MIN_CLEAR` is
		-- the threshold because that is the number this module already uses for
		-- "a road fits under this": a raise of 3 leaves `raise - 1` = 2 nodes
		-- of air under the deck, which is exactly a player, and every raise
		-- above it leaves MIN_CLEAR or more.
		--
		-- The decision is per LANE and not per position, because a street cut
		-- into a hillside is high over the valley and level with the bank on
		-- the other side: the uphill lanes are filled and are the viaduct's own
		-- abutment, and the downhill lanes stand on pillars.
		local PAVING, KERB, TREAD = paving(palette), kerb(palette), tread(palette)
		local PLANK, RAIL, PIER = plank(palette), railing(palette), pier(palette)
		local pavement, treads, risers = 0, 0, 0
		local spans, piers, rails, bridged = 0, 0, 0, 0
		local raised_columns = 0
		local verge_level, spanned_at = {}, {}
		for p = from, to do
			local top = level[p]
			-- A run asked for with no look-around at all has no neighbour
			-- outside its own span; such a column is walked as its own level.
			local before = level[p - 1] or top
			local after = level[p + 1] or top
			local step = (top > before) or (top > after)
			-- A position is SPANNED where any of its lanes stands `MIN_CLEAR`
			-- or more above its own ground, and WET where any of them stands in
			-- water. Either way the verge carries a plank walk and a rail, and
			-- pillars carry the lot.
			--
			-- EXCEPT WHERE A WP40 DECK CARRIES THE POSITION. A route's bridge
			-- may be narrower than the carriageway, and then the outer lanes
			-- have an ABUTMENT to build: the deck carries three lanes at its own
			-- height and the other two must be solid up to it, or the road
			-- beside the deck hangs in the air with the route's own piers under
			-- the middle of it and nothing under the edges. So a position the
			-- crossing rule put ON a deck is filled, not pillared --
			-- `tools/wp13/lane_crossing_kat.lua` section 4 is the case, and it
			-- is the one place the viaduct rule yields to another authority's
			-- geometry.
			local wet_here, span_here, on_deck = false, false, false
			for offset = -half, half do
				if wetlane[offset][p] then wet_here = true end
				if top - natural[offset][p] >= M.MIN_CLEAR then span_here = true end
				local d = decklane[offset][p]
				if d ~= nil and top >= d then on_deck = true end
			end
			local spanned = wet_here or (span_here and not on_deck)
			spanned_at[p] = spanned
			verge_level[p] = top
			if spanned then spans = spans + 1 end
			if wet_here then bridged = bridged + 1 end
			for offset = -half, half do
				local x, z = column(p, offset)
				local surface_name = (offset == -half or offset == half) and
					KERB or PAVING
				-- WHAT THE COLUMN STANDS ON. Ordinarily the ground it was read
				-- from. A column the crossing rule raised stands on the DECK
				-- where it has one -- the route's bridge carries the road, so
				-- the road does not fill the river up to it -- and on its own
				-- ground where it has not, because a deck narrower than the
				-- carriageway leaves the outer lanes an abutment to build.
				local base = natural[offset][p]
				local spanned_by = decklane[offset][p]
				if spanned_by ~= nil and ground[p] > base and
						spanned_by >= base and spanned_by <= top then
					base = spanned_by
				end
				local raise = top - base
				if raise > 0 then raised_columns = raised_columns + 1 end
				if raise > 0 and not wetlane[offset][p] and
						(raise < M.MIN_CLEAR or on_deck) then
					for y = base, top - 1 do
						buf:put(x, y, z, surface_name)
						if y == base then
							pavement = pavement + 1
						else
							risers = risers + 1
						end
					end
				end
				if step then
					-- A one-node change is walked as the two halves of a stair.
					-- The raised half faces the higher neighbour, which is the
					-- way a walker climbs it; a column higher than both is
					-- walked over either half, so the run's own direction
					-- decides.
					local sign = (after >= before) and 1 or -1
					parts.stair(buf, x, top, z, TREAD,
						parts.step_facedir(dx * sign, dz * sign))
					treads = treads + 1
				else
					buf:put(x, top, z, surface_name)
					if raise <= 0 then pavement = pavement + 1 end
				end
				-- What the crossing rule decided here, so a KAT and the
				-- measurement tool can hold the built road to the ruling
				-- instead of re-deriving it from the cells.
				if spanned_by ~= nil then
					crossings[#crossings + 1] = {x = x, y = top, z = z,
						lane = offset, deck_y = spanned_by,
						natural = natural[offset][p], base = base,
						clear = spanned_by - top - 2,
						at_grade = (top >= spanned_by) and true or false}
				end
			end
		end

		-- 5. THE VERGE: the plank walk, the rail, the pillars and the lamps.
		--
		-- A verge lane is read only where something stands on it -- a spanned
		-- position, a pier rhythm or a lamp -- so the two lanes outside the
		-- carriageway cost the run a query per cell and not a query per column
		-- of the whole window.
		local verge_ground = {}
		local function verge_surface(p, offset)
			local key = p .. ":" .. offset
			local y = verge_ground[key]
			if y == nil then
				local x, z = column(p, offset)
				y = {height(x, z), wetness(x, z), deck_at(x, z)}
				verge_ground[key] = y
			end
			return y[1], y[2], y[3]
		end
		for p = from, to do
			local is_lamp = ((p - phase) % spacing == 0)
			local is_pier = ((p - phase) % M.PIER == 0)
			if spanned_at[p] or is_lamp then
				for _, offset in ipairs({-verge, verge}) do
					local top = verge_level[p]
					local x, z = column(p, offset)
					local foot, soaked, verge_deck = verge_surface(p, offset)
					-- A STANDARD UNDER A DECK IT CANNOT CLEAR GOES ON THE DECK.
					-- Ruling 3 puts a lamp on the street's own profile, and a
					-- WP40 route may bridge the VERGE while leaving the
					-- carriageway beside it three blocks of air: the street
					-- passes under unchanged and its standard would be three
					-- courses of post inside the deck. A standard is its footing
					-- and three courses over it, so a verge has room for one
					-- exactly when it has `MIN_CLEAR` blocks of air -- the same
					-- threshold the carriageway is held to -- and a verge that
					-- has not got it carries its standard over the deck instead.
					if is_lamp and verge_deck ~= nil and top < verge_deck and
							top > verge_deck - M.MIN_CLEAR - 2 then
						top = verge_deck
					end
					if spanned_at[p] then
						-- The plank walk a player cannot step off, and its rail
						-- -- except where a lamp standard takes the rail's cell.
						buf:put(x, top, z, PLANK)
						if not is_lamp then
							buf:put(x, top + 1, z, RAIL)
							rails = rails + 1
						end
						if is_pier then
							local bottom = soaked and (foot - M.PIER_DEPTH) or foot
							for y = bottom, top - 1 do buf:put(x, y, z, PIER) end
							piers = piers + 1
						end
					else
						-- On the ground the standard gets its own footing in
						-- the kerb's material, and the verge is carried up to
						-- the road where the road stands above it: a standard
						-- is not part of the carriageway and has no envelope of
						-- its own, and ruling 3 is that it stands on the
						-- STREET's profile and not on the ground beside it.
						--
						-- EVERY STANDARD GETS ITS OWN FOOTING. On ordinary
						-- ground that cell is already solid and the footing is
						-- a paving stone under the post; over water it is the
						-- only thing between the post and the river. The first
						-- engine pass of the WP13 seam took Highcourt's east
						-- avenue across a river as a causeway and sixteen
						-- standards stood in the water with nothing under them.
						local bottom = (foot < top) and foot or top
						for y = bottom, top do buf:put(x, y, z, KERB) end
					end
					if is_lamp then
						buf:put(x, top + 1, z, palette.node("post"))
						buf:put(x, top + 2, z, palette.node("post"))
						parts.floor_torch(buf, palette, x, top + 3, z)
						lamps[#lamps + 1] = {x = x, y = top + 3, z = z}
					end
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
			overhead_queries = overhead_queries, plateaus = plateaus,
			street = {spans = spans, piers = piers, rails = rails,
				bridged = bridged, raised = raised_columns,
				plateaus = #plateaus},
			columns = (to - from + 1) * width, queries = queries,
		}
	end

	return M
end

return loader
