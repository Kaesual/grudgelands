-- Post-generation pass for the structures the biome system cannot express.
--
-- NOT HERE ANY MORE (WP36 item 2): the CONTINENT OCEAN MASK. It moved to the
-- MAPGEN environment — `ocean_mask_mapgen.lua`, registered by `ocean_mask.lua`
-- via core.register_mapgen_script — because it is pure voxel work on the chunk
-- the engine has just generated and does not need any of the things this file
-- needs. Running it here meant running it after the chunk was already blitted
-- to the map (servermap.cpp:291), on the server step, and writing every coastal
-- chunk twice.
--
-- The passes below CANNOT follow it: they need `grug_core` (capitals, POI
-- registry, spawn levels), mod storage and the engine's spawn level, none of
-- which exist in the mapgen env (lua_api.md:7678-7691). They still run AFTER
-- the mask for a given chunk, and now by engine ordering rather than by file
-- order: the mapgen-env callback fires at emerge.cpp:745, the main-env one this
-- file registers at emerge.cpp:619-624, for the same chunk.
--
-- What stays here:
--
--  * the RACE CAPITAL PLATFORMS: a walkable, guaranteed flat platform at all
--    six race capitals (grug_core.capitals) — placeholder until WP13 ships
--    real capital structures. The capitals sit at z = ±900, deep inside the
--    safe core, so the mask never reaches them. Each platform also carries
--    ONE guard banner, which is what turns it into the elite city watch of
--    docs/design/world.md §3 (see build_camp).
--
--  * the MILITARY OUTPOSTS of docs/design/world.md §4/§9 ("1 military
--    outpost per ring as the guaranteed minimum"): a 7×7 cobble pad with
--    four wooden corner posts and a guard banner in the middle, at every
--    anchor of grug_core.outpost_anchors() — or, when that column turns out
--    to be under water or on a peak, at the first of its retry candidates
--    that does not. See the outpost section below.
--
--  * the DETERMINISTIC BANDIT CAMPS (WP6 bridge until WP13's settlement
--    pass): a single grug_mobs:camp_fire node at every anchor of
--    grug_core.bandit_camp_anchors() (same retry rule). No pad, no
--    protection — see the bandit camp section below.
--
-- (The old east-west mountain wall at |x| = 2000 is gone: the continent
-- redesign replaces walls with ocean.)

-- The coast profile. `column_cap(x, z)` is a pure function of (x, z) and the
-- ONLY thing this file needs from the ocean mask: it is what stops an outpost
-- or a bandit camp from being anchored on a column the mask is about to flood
-- (see candidate_ground_y). Same table, same numbers, same noise the mapgen-env
-- mask uses — geometry.lua exists so there is exactly one of them.
local column_cap = grug_mapgen.geometry.column_cap

local CAMP_HALF = grug_core.CAMP_HALF
local CLEAR_HEIGHT = grug_core.CAMP_CLEAR_HEIGHT
local SKIRT_DEPTH = 16 -- platform base reaches this far below the surface

-- Mod-wide persistence (AGENTS.md: fetch at load time). The outpost pass
-- writes the "this CANDIDATE was rejected" markers here (the accepted ones
-- persist as POI records in grug_core, see the outpost section) and the bandit
-- pass writes the same per-candidate markers plus one "this camp is built"
-- marker per anchor (it has no POI record to carry that).
local storage = core.get_mod_storage()

-- Reused across mapchunks: vm:get_data() without a buffer allocates a fresh
-- ~11 MB table for every chunk that carries a structure.
local vm_data = {}

-- Content ids at file scope, the pattern the whole file uses: this chunk runs
-- when grug_mapgen loads, and every name below belongs to a mod grug_mapgen
-- declares in mod.conf `depends` (default, grug_nodes), so all of them are
-- registered by now. (grug_mobs:camp_fire is the one exception — see
-- camp_fire_id further down.)
local c_air = core.get_content_id("air")
local c_cobble = core.get_content_id("default:cobble")
local c_tree = core.get_content_id("default:tree")
local c_banner = core.get_content_id("grug_nodes:guard_banner")

--
-- Race capital platforms
--

-- Terrain-adaptive platform height. The value comes from grug_core, which
-- resolves it lazily from the ENGINE'S SPAWN LEVEL at the capital anchor and
-- persists it. That query is a pure function of (x, z): it does not care
-- which mapchunk asks, in which order the chunks generate, or how the
-- chunk's y range cuts the terrain — so every chunk that overlaps the
-- platform volume can build its own slice of the SAME platform, whenever it
-- is generated. Rationale and the exact +2 offset: grug_core/init.lua.
--
-- The trade, honestly: that is the base-terrain level of ONE column instead
-- of a statistic over the footprint, so local relief inside the 25×25 area
-- is not averaged out — the 16-node skirt below and the 64-node clearing
-- above absorb it. The heightmap-median experiment is dead as a PRIMARY
-- rule: the mapgen heightmap only exists per mapchunk, which made the value
-- depend on which chunk measured it (a ±40 window clipped to a biased corner
-- put the orc platform far below its hill and the clearing dug a 25×25 shaft
-- into it) and, once a "only the chunk holding the anchor surface decides"
-- rule was added, made earlier chunks lose their platform slice and — worse
-- — deadlocked completely when the anchor's surface sat exactly on a chunk
-- y edge (Mapgen::findGroundLevel then returns maxp.y, indistinguishable
-- from "ground continues above", while the chunk above reports its bottom
-- sentinel).
--
-- It survives as the FALLBACK, because core.get_spawn_level answers nil for
-- a large share of positions (mgv7: rivers, water, and any terrain above
-- max(terrain offsets, water_level + 16) = y 17 with our noise offsets — see
-- grug_core) and that nil is permanent, not transient. Without a fallback
-- those capitals would get no platform and no spawn clearing at all. It is
-- the FIRST chunk with a usable heightmap over the footprint that decides
-- (no anchor-column gate: that is what deadlocked), so at most the chunks
-- generated before it — with ascending-y emerge, the one holding the lower
-- part of the skirt — can miss their slice.
local SAMPLE_RADIUS = CAMP_HALF + 4 -- footprint + margin, Chebyshev

-- Median of the mapgen heightmap over a footprint box (Chebyshev radius
-- around cx/cz, clipped to the chunk), or nil if this chunk cannot see the
-- surface there. Heights equal to a chunk y edge are dropped: findGroundLevel
-- returns maxp.y when the ground continues above and
-- -MAX_MAP_GENERATION_LIMIT when the column holds nothing walkable.
-- Shared by the capital platforms and the outposts below.
local function heightmap_median(cx, cz, radius, minp, maxp)
	local heightmap = core.get_mapgen_object("heightmap")
	if not heightmap then
		return nil
	end
	local x1 = math.max(minp.x, cx - radius)
	local x2 = math.min(maxp.x, cx + radius)
	local z1 = math.max(minp.z, cz - radius)
	local z2 = math.min(maxp.z, cz + radius)
	local width = maxp.x - minp.x + 1
	local samples = {}
	for z = z1, z2 do
		local row = (z - minp.z) * width
		for x = x1, x2 do
			local h = heightmap[row + (x - minp.x) + 1]
			if h and h > minp.y and h < maxp.y then
				samples[#samples + 1] = h
			end
		end
	end
	if #samples == 0 then
		return nil
	end
	table.sort(samples)
	return samples[math.floor((#samples + 1) / 2)]
end

local function fallback_platform_y(capital, minp, maxp)
	return heightmap_median(capital.x, capital.z, SAMPLE_RADIUS, minp, maxp)
end
-- Exposed so the fallback can be exercised with a stub heightmap, without the
-- engine — the same reason grug_mapgen.continent_distance / .surface_cap /
-- .column_cap are exposed in ocean_mask.lua.
grug_mapgen.fallback_platform_y = fallback_platform_y

-- The capital watch (world.md §3 "elite guards"): ONE guard banner on the
-- platform, offset into the +x/+z corner so it never stands on the spawn
-- point itself (grug_core.get_spawn_pos is the platform CENTRE). Everything
-- else about it is the outpost flow — the LBM in grug_mobs/camps.lua arms its
-- timer, the territory picks the faction, and guard_level_at inside the safe
-- core is 60+, so that watch promotes itself to elite (guard.lua).
-- It needs no POI record: the banner sits inside the platform footprint,
-- which grug_core's capital rule already protects.
local CAMP_BANNER_OFFSET = CAMP_HALF - 1

local function build_camp(data, area, minp, maxp, camp)
	local x1 = math.max(minp.x, camp.x - CAMP_HALF)
	local x2 = math.min(maxp.x, camp.x + CAMP_HALF)
	local z1 = math.max(minp.z, camp.z - CAMP_HALF)
	local z2 = math.min(maxp.z, camp.z + CAMP_HALF)
	local base_y = math.max(minp.y, camp.y - SKIRT_DEPTH)
	local top_y = math.min(maxp.y, camp.y)
	local clear_y1 = math.max(minp.y, camp.y + 1)
	local clear_y2 = math.min(maxp.y, camp.y + CLEAR_HEIGHT)
	for x = x1, x2 do
		for z = z1, z2 do
			for y = base_y, top_y do
				data[area:index(x, y, z)] = c_cobble
			end
			for y = clear_y1, clear_y2 do
				data[area:index(x, y, z)] = c_air
			end
		end
	end
	-- AFTER the clearing loop above, which would otherwise erase it. Written
	-- only by the chunk slice that actually contains the banner column, and
	-- writing the same node again on a re-generated chunk is a no-op — the
	-- platform build as a whole is idempotent.
	local bx, bz = camp.x + CAMP_BANNER_OFFSET, camp.z + CAMP_BANNER_OFFSET
	local by = camp.y + 1
	if bx >= minp.x and bx <= maxp.x and bz >= minp.z and bz <= maxp.z
			and by >= minp.y and by <= maxp.y then
		data[area:index(bx, by, bz)] = c_banner
	end
end

--
-- Military outposts (docs/design/world.md §4/§9)
--
-- Twenty-four deterministic anchors (four rings × six race bands — war_coast,
-- inner, outer and, since the WP6 review, coast), all of them from
-- grug_core.outpost_anchors() — mapgen, the guard camps and the patrol routes
-- read the SAME list, so nothing here re-derives a position.
--
-- The coast anchors are the ones the REJECTION rule below really matters for:
-- they sit at the inner edge of the coast band by construction, but the coast
-- noise still floods a share of those columns depending on the inset it rolls
-- there, and a flooded anchor is retried elsewhere rather than drowned.
--
-- The structure is deliberately minimal (WP13 ships real ones): a 7×7 cobble
-- pad flattening the terrain, two cobble layers of skirt under it, five nodes
-- of air cleared above, four wooden corner posts and ONE guard banner in the
-- middle. The banner is the whole point — grug_mobs/camps.lua turns it into a
-- guard post (LBM arms the node timer, territory picks the faction, the guard
-- field picks the level).
--
-- HEIGHT, same rule and the same rationale as the capital platforms above:
-- ask the engine's spawn level first (a pure function of x/z — every mapchunk
-- that ever looks at this anchor derives the same y, no matter in which order
-- the chunks generate), and fall back to a heightmap median over the footprint
-- where mgv7 refuses to answer. The decision is persisted the moment it is
-- made — as the POI's y_base in grug_core — so later chunk slices of the same
-- outpost read it back instead of re-measuring.
--
-- THE MASK HAS THE LAST WORD on that height. Neither the engine's spawn level
-- nor the mapgen heightmap knows about the continent ocean mask above, so at a
-- war-coast anchor (|z| = 250, i.e. 150 nodes from the rectangle edge and well
-- inside the 0..150 node coast inset) both can happily report dry land for a
-- column this pass is about to turn into sea. column_cap(x, z) is the same
-- pure (x, z) function the mask itself uses, so clamping to it puts the pad on
-- the coastline the player will actually see — and pushes a genuinely flooded
-- anchor below the rejection threshold instead of leaving a cobble island in
-- the water.
--
-- REJECTION AND RETRY: a candidate whose surface ends up below y 2 or above
-- y 100 is NOT built there — a drowned outpost (guards spawning in water, a
-- banner under the sea) is worse than none. It used to end the story for that
-- anchor, and a runtime log then showed 4 of 6 attempted anchors skipped as
-- flooded, i.e. §9's "1 military outpost per ring" delivered almost nothing.
-- Now every anchor has an ordered CANDIDATE list (grug_core.outpost_candidates
-- — the anchor plus three fallbacks that step inland resp. slide along the
-- ring; the direction rules and the zone verification live there), and:
--   * only the REJECTED CANDIDATE is marked, under "outpost_skip:<id>:<index>"
--     — the anchor keeps its other chances, across chunks and sessions;
--   * the candidates are resolved STRICTLY IN ORDER (see the collect loop):
--     the anchor is the outpost, a fallback is what happens when the terrain
--     says no — not what happens when a neighbouring mapchunk is generated
--     first;
--   * the winning candidate is persisted as the POI record with the BUILT
--     position, which is what the per-id "already built" check below reads.
--     Neighbouring chunks and later sessions therefore see one outpost, never
--     two.
--   * LEGACY: worlds from before the retry scheme stored a plain
--     "outpost_skip:<id>". That key means "candidate 1 was rejected" and
--     nothing more — it must never be read as "this anchor is dead", or the
--     fallbacks could not heal an existing world. See candidate_skipped.
local OUTPOST_HALF = grug_core.OUTPOST_HALF
local OUTPOST_PAD = 3 -- 7x7 pad (the structure; OUTPOST_HALF adds the margin)
local OUTPOST_SKIRT = 2 -- cobble layers below the pad top
local OUTPOST_CLEAR = 5 -- air cleared above the pad
local OUTPOST_POST_H = 3 -- height of the four corner posts
local OUTPOST_MIN_Y = 2 -- below this the anchor is (or will be) under water
local OUTPOST_MAX_Y = 100 -- ... and above this it is a mountain top
-- Protected zone of an outpost: the structure half PLUS the >= 10 nodes of
-- surrounding terrain world.md §2 asks for. The registry does not add
-- anything, the caller passes the final half.
local OUTPOST_PROTECT_HALF = OUTPOST_HALF + 10
-- File scope so the corner loop allocates nothing per mapchunk.
local OUTPOST_CORNERS = {{-1, -1}, {-1, 1}, {1, -1}, {1, 1}}

-- True when this candidate of this anchor was already rejected. Index 1 also
-- honours the LEGACY key of the pre-retry scheme (see above): it recorded the
-- rejection of the anchor column, which IS candidate 1 — and of nothing else,
-- so candidates 2..n stay open in an existing world.
local function candidate_skipped(id, index)
	if storage:get_string("outpost_skip:" .. id .. ":" .. index) ~= "" then
		return true
	end
	return index == 1 and storage:get_string("outpost_skip:" .. id) ~= ""
end

-- Does the chunk box reach the column (x, z) grown by `half`?
local function chunk_covers(minp, maxp, x, z, half)
	return maxp.x >= x - half and minp.x <= x + half and
		maxp.z >= z - half and minp.z <= z + half
end

-- Ground level of ONE candidate column, and whether it can carry a structure.
-- Returns y; or nil plus a reason when the ground is unusable; or nil ALONE
-- when nothing here can answer yet. Callers must keep those two nils apart: a
-- REJECTED candidate hands over to the next one, an undecided one keeps its
-- turn (the terrain, never the chunk order, moves a structure).
--
-- Two of the three sources are pure functions of x/z and answer from ANY
-- mapchunk, which is what lets the decision below judge candidates that lie
-- outside the chunk being generated:
--   * column_cap, the ocean mask's own profile. When it caps a column below
--     the minimum, no terrain height can save it — the mask will flood it. So
--     that verdict is taken FIRST, and it is exactly the one the war-coast and
--     coast anchors need: those are the candidates the runtime log showed
--     drowning, and their rejection therefore never waits for a particular
--     chunk.
--   * grug_core.surface_level_at, the engine's spawn level.
-- Only the heightmap fallback is chunk-local (mgv7 answers no spawn level in
-- water, in rivers or above y ~17), so it is used just for a candidate this
-- chunk actually covers. A candidate that ends up needing it stays UNDECIDED
-- until such a chunk is generated — the honest answer, and the one place where
-- the outcome can still depend on chunk order: with a NATURAL lake on the
-- anchor (not the mask, see above), the rejection only happens once the
-- anchor's own chunk is generated, and if the winning fallback's chunk came
-- before that, the structure ends up decided but unbuilt. That is exactly what
-- the pre-retry code did with EVERY flooded anchor, so it is never worse — and
-- the flooding the runtime log actually showed is the mask's, which is handled
-- above.
-- The accepted side effect of that narrow case: the POI record is the
-- decision, so its PROTECTION ZONE goes live at a position where no structure
-- will ever be raised — a block of unbuildable wilderness, and
-- grug_core.outpost_position pointing at bare terrain. Nothing is corrupt (the
-- zone and the never-built structure still agree on one position, which is the
-- invariant this function exists for) and nothing retries it, because the
-- candidate walk only ever runs forward. Accepted for now; revisit with WP13's
-- structure pass, which is where deferred/rebuilt structures belong.
-- Shared with the bandit camps further down (they pass a smaller sample
-- radius); the y window is the same for both.
local function candidate_ground_y(cand, radius, minp, maxp)
	local cap = column_cap(cand.x, cand.z) -- nil = inland, no cap at all
	if cap and cap < OUTPOST_MIN_Y then
		return nil, "flooded"
	end
	local y = grug_core.surface_level_at(cand.x, cand.z)
	if not y and chunk_covers(minp, maxp, cand.x, cand.z, radius) then
		y = heightmap_median(cand.x, cand.z, radius, minp, maxp)
	end
	if not y then
		return nil
	end
	y = math.floor(y)
	if cap and cap < y then
		y = cap -- clamp to the coast profile (see above)
	end
	if y < OUTPOST_MIN_Y or y > OUTPOST_MAX_Y then
		return nil, (y < OUTPOST_MIN_Y and "flooded" or "too high")
	end
	return y
end

-- True when any candidate of this anchor reaches into the chunk — the cheap
-- arithmetic gate that keeps the decision below (and its spawn-level queries)
-- off the vast majority of mapchunks.
local function chunk_near_outpost(anchor, minp, maxp)
	local cands = grug_core.outpost_candidates(anchor)
	for c = 1, #cands do
		if chunk_covers(minp, maxp, cands[c].x, cands[c].z, OUTPOST_HALF) then
			return true
		end
	end
	return false
end

-- Decides WHERE this outpost stands and persists that as the POI record (the
-- record is the decision: position, y_base and "it exists at all", which is
-- what keeps the protected zone, the built structure and
-- grug_core.outpost_position at one shared position by construction). Returns
-- the record, or nil while the question is still open.
--
-- The candidates are walked STRICTLY IN ORDER and a candidate that nothing can
-- decide yet stops the walk — a fallback is what happens when the terrain says
-- no, never what happens when a neighbouring mapchunk was generated first. It
-- deliberately does NOT require the winning candidate to be inside this chunk:
-- deciding early and building later is exactly what the POI record is for, and
-- it means a rejected anchor can hand over to a fallback whose own chunk is
-- generated before or after this one.
local function decide_outpost(anchor, minp, maxp)
	local cands = grug_core.outpost_candidates(anchor)
	for c = 1, #cands do
		if not candidate_skipped(anchor.id, c) then
			local cand = cands[c]
			local y, reason = candidate_ground_y(cand, OUTPOST_PAD, minp, maxp)
			if y then
				core.log("action",
					("[grug_mapgen] outpost %s anchored at %d,%d,%d " ..
					"(candidate %d)"):format(anchor.id, cand.x, y, cand.z, c))
				return grug_core.add_poi({
					id = anchor.id,
					x = cand.x,
					z = cand.z,
					half = OUTPOST_PROTECT_HALF,
					y_base = y,
				})
			end
			if not reason then
				return nil -- undecided: nobody behind it may jump the queue
			end
			storage:set_string("outpost_skip:" .. anchor.id .. ":" .. c, reason)
			core.log("action",
				("[grug_mapgen] outpost %s candidate %d at %d,%d skipped " ..
				"(%s)"):format(anchor.id, c, cand.x, cand.z, reason))
		end
	end
	return nil -- every candidate rejected: this ring keeps no post
end

local function build_outpost(data, area, minp, maxp, o)
	local x1 = math.max(minp.x, o.x - OUTPOST_PAD)
	local x2 = math.min(maxp.x, o.x + OUTPOST_PAD)
	local z1 = math.max(minp.z, o.z - OUTPOST_PAD)
	local z2 = math.min(maxp.z, o.z + OUTPOST_PAD)
	local base_y = math.max(minp.y, o.y - OUTPOST_SKIRT)
	local top_y = math.min(maxp.y, o.y)
	local clear_y1 = math.max(minp.y, o.y + 1)
	local clear_y2 = math.min(maxp.y, o.y + OUTPOST_CLEAR)
	for x = x1, x2 do
		for z = z1, z2 do
			for y = base_y, top_y do
				data[area:index(x, y, z)] = c_cobble
			end
			for y = clear_y1, clear_y2 do
				data[area:index(x, y, z)] = c_air
			end
		end
	end
	-- Posts and banner AFTER the clearing loop, which would erase them.
	local post_y2 = math.min(maxp.y, o.y + OUTPOST_POST_H)
	for i = 1, 4 do
		local cx = o.x + OUTPOST_CORNERS[i][1] * OUTPOST_PAD
		local cz = o.z + OUTPOST_CORNERS[i][2] * OUTPOST_PAD
		if cx >= minp.x and cx <= maxp.x and cz >= minp.z and cz <= maxp.z then
			for y = clear_y1, post_y2 do
				data[area:index(cx, y, cz)] = c_tree
			end
		end
	end
	local by = o.y + 1
	if o.x >= minp.x and o.x <= maxp.x and o.z >= minp.z and o.z <= maxp.z
			and by >= minp.y and by <= maxp.y then
		-- A VoxelManip write fires NO node callbacks, so this banner arrives
		-- without meta and without a node timer. The LBM
		-- "grug_mobs:guard_banner_init" (grug_mobs/camps.lua) is what turns it
		-- into a live guard post — that is why the LBM exists, and why it has
		-- to run at EVERY mapblock load: an LBM with run_at_every_load = false
		-- never runs on a mapblock generated after the LBM's introduction
		-- (lua_api.md:10312-10316), which is every block this line writes into.
		data[area:index(o.x, by, o.z)] = c_banner
	end
end

--
-- Deterministic bandit camps (WP6 bridge, see grug_core.bandit_camp_anchors)
--
-- Twelve anchors, two per race band. The structure is ONE node: a
-- grug_mobs:camp_fire on the ground. That node IS the camp — its timer spawns
-- and respawns 3-5 bandits around itself (grug_mobs/camps.lua) — so a pad, a
-- clearing or corner posts would add nothing but cobble. Placing it is what
-- gives the linen-cloth economy a source before WP13 ships real settlements.
--
-- NOT a POI, unlike the outposts: a bandit camp is meant to be raided and
-- razed (world.md §2's protected zones are for the things players must not be
-- able to grief; a camp is the opposite). No add_poi call.
--
-- RETRY, like the outposts: an anchor column that sits in a lake or a river
-- used to be dropped silently and that band simply had no bandits (and no
-- linen source) forever. grug_core.bandit_camp_candidates gives every anchor
-- two lateral fallbacks, resolved strictly in order — a candidate steps aside
-- only when the TERRAIN rejects it, never because its neighbour's mapchunk was
-- generated first.
-- What a POI-less structure has no home for is the bookkeeping the POI record
-- does for an outpost, so this pass keeps its own two keys in mod storage:
-- "bandit_at:<id>" = "x,z,y", the decided position (without it a fallback
-- candidate's mapchunk — generated at any later time, possibly a session later
-- — would place a SECOND camp 96 nodes from the first, and a world from before
-- the retry scheme, which has no keys at all, would be the worst case), and
-- "bandit_skip:<id>:<index>" for a rejected candidate, so the next one may
-- have its turn. Neither resurrects a razed camp: mapgen never runs over a
-- generated chunk again.
--
-- HEIGHT: the same rule as everything else here, minus the y persistence. A
-- camp occupies exactly one column, so only ONE mapchunk ever places a given
-- candidate and there is no cross-chunk agreement to maintain: engine spawn
-- level first, heightmap median over a 5×5 as the fallback, clamped to the
-- coast profile, and the same 2..100 sanity window the outposts use (all
-- twelve anchors and their candidates are inland — |x| <= 766, |z| <= 1350,
-- i.e. >= 350 nodes from any rectangle edge — so column_cap returns nil for
-- them and the clamp is pure belt and braces).
--
-- The node arrives by VoxelManip, which fires no callbacks, so its meta and
-- its node timer are set up by the LBM "grug_mobs:camp_fire_init"
-- (grug_mobs/camps.lua), which for that reason has to run at EVERY mapblock
-- load — see the note at the LBM — exactly the same arrangement as the guard
-- banner.
local BANDIT_SAMPLE = 2 -- heightmap median radius (5x5) for the fallback

-- Resolved lazily, not at file scope like the other content ids: camp_fire
-- belongs to grug_mobs, which grug_mapgen deliberately does NOT depend on
-- (mapgen must not need the mob engine to load). By the time
-- register_on_generated first runs, every mod is registered.
local c_camp_fire

local function camp_fire_id()
	if c_camp_fire == nil then
		c_camp_fire = core.registered_nodes["grug_mobs:camp_fire"] and
			core.get_content_id("grug_mobs:camp_fire") or false
		if not c_camp_fire then
			core.log("warning", "[grug_mapgen] grug_mobs:camp_fire is not " ..
				"registered — the deterministic bandit camps are skipped")
		end
	end
	return c_camp_fire or nil
end

-- The camp's decided position, "x,z,y" in mod storage, or nil while it is
-- still open. This is the POI record's stand-in (see the section header): the
-- one place that says where — and whether — this camp is.
local function bandit_decision(id)
	local raw = storage:get_string("bandit_at:" .. id)
	local x, z, y = raw:match("^(-?%d+),(-?%d+),(-?%d+)$")
	if not x then
		return nil
	end
	return {x = tonumber(x), z = tonumber(z), y = tonumber(y)}
end

-- Decides where this camp stands, exactly like decide_outpost above and with
-- the same strict candidate order; the answer goes to mod storage instead of
-- the POI registry, because a bandit camp is not protected.
local function decide_bandit_camp(anchor, minp, maxp)
	local cands = grug_core.bandit_camp_candidates(anchor)
	for c = 1, #cands do
		if storage:get_string("bandit_skip:" .. anchor.id .. ":" .. c) == "" then
			local cand = cands[c]
			local y, reason =
				candidate_ground_y(cand, BANDIT_SAMPLE, minp, maxp)
			if y then
				storage:set_string("bandit_at:" .. anchor.id,
					cand.x .. "," .. cand.z .. "," .. y)
				core.log("action",
					("[grug_mapgen] bandit camp %s anchored at %d,%d,%d " ..
					"(candidate %d)"):format(anchor.id, cand.x, y, cand.z, c))
				return {x = cand.x, z = cand.z, y = y}
			end
			if not reason then
				return nil -- undecided: nobody behind it may jump the queue
			end
			storage:set_string("bandit_skip:" .. anchor.id .. ":" .. c, reason)
			core.log("action",
				("[grug_mapgen] bandit camp %s candidate %d at %d,%d skipped " ..
				"(%s)"):format(anchor.id, c, cand.x, cand.z, reason))
		end
	end
	return nil -- every candidate rejected: this band keeps no camp
end

local function chunk_near_bandit_camp(anchor, minp, maxp)
	local cands = grug_core.bandit_camp_candidates(anchor)
	for c = 1, #cands do
		if chunk_covers(minp, maxp, cands[c].x, cands[c].z, 0) then
			return true
		end
	end
	return false
end

-- Main-environment pass. The ocean mask has already run on this chunk in the
-- mapgen environment (ocean_mask_mapgen.lua) — the engine calls that callback
-- before it blits the chunk, and this one after (emerge.cpp:745 vs :619-624) —
-- so the coast profile the outpost heights are clamped to is already in the map
-- by the time anything below reads it.
core.register_on_generated(function(minp, maxp, blockseed)
	local camps = {}
	for race_id, capital in pairs(grug_core.capitals) do
		if maxp.x >= capital.x - CAMP_HALF and
				minp.x <= capital.x + CAMP_HALF and
				maxp.z >= capital.z - CAMP_HALF and
				minp.z <= capital.z + CAMP_HALF then
			local y = grug_core.get_camp_platform_y(race_id)
			if not y then
				-- Engine has no spawn level here (permanent, see above):
				-- measure the footprint in this chunk instead.
				local fallback = fallback_platform_y(capital, minp, maxp)
				if fallback then
					y = grug_core.set_camp_platform_y(race_id, fallback)
				end
				-- Still nothing (chunk fully above/below the surface): skip,
				-- a chunk that can see the surface decides and builds.
			end
			if y and maxp.y >= y - SKIRT_DEPTH and
					minp.y <= y + CLEAR_HEIGHT then
				camps[#camps + 1] = {x = capital.x, y = y, z = capital.z}
			end
		end
	end

	-- Outposts: same shape as the camp block above — decide the height, then
	-- collect the ones whose build volume reaches into this chunk. The x/z
	-- overlap test uses OUTPOST_HALF (structure + breathing room), so a chunk
	-- that only clips the pad still builds its slice.
	--
	-- Two separate questions, in this order: WHERE does this outpost stand
	-- (decide_outpost, once per anchor and per world — the POI record carries
	-- the answer to every later chunk and session), and does the answer reach
	-- into THIS chunk (then build the slice). Keeping them apart is what makes
	-- the retry work in any chunk order: the decision only needs the engine's
	-- spawn level, which any chunk can ask for any column.
	local outposts = {}
	local anchors = grug_core.outpost_anchors()
	for i = 1, #anchors do
		local a = anchors[i]
		local poi = grug_core.get_poi(a.id)
		if not poi and chunk_near_outpost(a, minp, maxp) then
			poi = decide_outpost(a, minp, maxp)
		end
		if poi and chunk_covers(minp, maxp, poi.x, poi.z, OUTPOST_HALF) and
				maxp.y >= poi.y_base - OUTPOST_SKIRT and
				minp.y <= poi.y_base + OUTPOST_CLEAR then
			outposts[#outposts + 1] = {x = poi.x, y = poi.y_base, z = poi.z}
		end
	end

	-- Bandit camps: the same two questions as the outposts above (decide once,
	-- then build the chunk that holds the answer), only with the mod-storage
	-- record instead of a POI and with a single node instead of a pad.
	local fires = {}
	local fire_id = camp_fire_id()
	if fire_id then
		local bandits = grug_core.bandit_camp_anchors()
		for i = 1, #bandits do
			local b = bandits[i]
			local at = bandit_decision(b.id)
			if not at and chunk_near_bandit_camp(b, minp, maxp) then
				at = decide_bandit_camp(b, minp, maxp)
			end
			if at and chunk_covers(minp, maxp, at.x, at.z, 0) and
					at.y + 1 >= minp.y and at.y + 1 <= maxp.y then
				fires[#fires + 1] = {x = at.x, y = at.y + 1, z = at.z}
			end
		end
	end

	-- The overwhelming majority of mapchunks hold no structure at all, and
	-- since the mask left this callback they cost exactly this test: no
	-- VoxelManip is fetched, nothing is written to the map a second time.
	if #camps == 0 and #outposts == 0 and #fires == 0 then
		return
	end

	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	-- Reused buffer: a fresh get_data() table is ~11 MB of garbage per chunk.
	local data = vm:get_data(vm_data)

	for _, camp in ipairs(camps) do
		build_camp(data, area, minp, maxp, camp)
	end
	-- After the camps: the two never overlap (capitals sit at |z| = 900, the
	-- nearest outpost ring at |z| = 500), the order is just the file's order.
	for _, outpost in ipairs(outposts) do
		build_outpost(data, area, minp, maxp, outpost)
	end
	-- Last: the camp fire is a single node and must not be erased by anything
	-- that clears volume. It never shares a column with a pad anyway (the
	-- bandit anchors are 120 nodes off the capital/outpost x), the order is
	-- simply the safe one.
	for _, fire in ipairs(fires) do
		data[area:index(fire.x, fire.y, fire.z)] = fire_id
	end

	vm:set_data(data)
	-- Nothing here PLACES a liquid any more (the ocean mask, which did, now
	-- runs in the mapgen env and updates them there) — but every pass above
	-- REMOVES solid nodes: a platform clearing opens a 25x25x64 shaft and an
	-- outpost a 7x7x5 one, and where that shaft breaks into standing water
	-- (a coastal outpost pad against a lake or a river bank) the water has to
	-- start flowing. A main-env write_to_map does not queue liquids the way
	-- finishBlockMake does for a mapgen VM, so without this the world keeps a
	-- suspended water wall until a player disturbs it by hand. The cost is
	-- bounded by the early return above: only the ~40 mapchunks in a world
	-- that actually carry a capital platform, an outpost or a bandit camp ever
	-- reach this line.
	vm:update_liquids()
	-- Lighting changes for the same reason, so it is recalculated.
	vm:calc_lighting()
	vm:write_to_map()
end)
