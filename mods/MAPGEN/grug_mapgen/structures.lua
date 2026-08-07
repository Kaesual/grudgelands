-- Post-generation pass for the two things the biome system cannot express:
--
--  * the CONTINENT OCEAN MASK (docs/design/world.md §1/§2b): the world is two
--    separate continents mirrored at z = 0, everything else is ocean —
--    "the terrain generates, but it MUST be water, no islands". v7 happily
--    grows land outside the continent rectangles, so this pass caps the
--    surface of every column near or outside a rectangle edge and floods
--    what it cut. The shoreline is soft: a 2D noise insets the rectangle by
--    0..150 nodes, and because the inset is clamped at 0 it only ever moves
--    the coast INWARD — the 200-node strait of §1 (|z| < 100 is water) is
--    guaranteed by construction, never by luck of the noise.
--    The cap rises across a 150-node ramp to ~115 nodes above sea level and
--    is then dropped entirely (columns further inland are never even looked
--    at), so the mask shapes the coast and leaves the hinterland to v7. What
--    it does cut it re-dresses: sand at beach level, otherwise the column's
--    own biome surface, so a shaved coastal hill stays walkable land.
--    The mask also reaches into the 16-node SHELL of the emerged area, not
--    just the mapchunk: schematic decorations for a tree rooted in this chunk
--    spill into the neighbouring chunks, which were generated (and masked)
--    earlier and can no longer remove what arrives after them — that overflow
--    was left hanging as floating canopy over the water (see clean_shell).
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
--    anchor of grug_core.outpost_anchors(). See the outpost section below.
--
--  * the DETERMINISTIC BANDIT CAMPS (WP6 bridge until WP13's settlement
--    pass): a single grug_mobs:camp_fire node at every anchor of
--    grug_core.bandit_camp_anchors(). No pad, no protection — see the bandit
--    camp section below.
--
-- (The old east-west mountain wall at |x| = 2000 is gone: the continent
-- redesign replaces walls with ocean.)

local X_HALF = grug_core.CONTINENT_X_HALF
local Z_MIN = grug_core.CONTINENT_Z_MIN
local Z_MAX = grug_core.CONTINENT_Z_MAX
local CAMP_HALF = grug_core.CAMP_HALF
local CLEAR_HEIGHT = grug_core.CAMP_CLEAR_HEIGHT
local SKIRT_DEPTH = 16 -- platform base reaches this far below the surface

-- Mod-wide persistence (AGENTS.md: fetch at load time). Only the outpost pass
-- writes here, and only the "this anchor was rejected" markers — the accepted
-- ones persist as POI records in grug_core (see the outpost section).
local storage = core.get_mod_storage()

-- Sea level of the active mapgen (v7 default 1); the whole mask profile is
-- expressed relative to it.
local WATER_LEVEL = tonumber(core.get_mapgen_setting("water_level")) or 1

--
-- Continent ocean mask
--

local TAPER = 150 -- width of the shore -> inland ramp; beyond it: no cap
local INSET_MAX = 150 -- the coast noise pulls the shoreline in by 0..150
local SHORE_DROP = 5 -- surface cap right at the shoreline: W - 5
local TAPER_RISE = 119 -- cap gained across the taper band (quadratic ease)
local SHELF_DEPTH = 10 -- seabed drops this much across SHELF_WIDTH
local SHELF_WIDTH = 60 -- ... and is flat further out (v7 takes over)
local BEACH_DEPTH = 3 -- sand layers put on a newly exposed beach top
local FILLER_DEPTH = 2 -- filler layers under a re-dressed biome top
-- Decorations (trees) were already placed when this pass runs and reach at
-- most this far above the mapgen heightmap; carving stops there, so a
-- mapchunk high above the terrain costs nothing.
local DECO_MARGIN = 32
-- Width of the emerged shell around a mapchunk (the mapgen VM reaches this
-- far beyond minp..maxp on every side).
local SHELL = 16
-- Ceiling for the shell clean. Honest bound, not a proof: the fresh overflow
-- it removes sits within DECO_MARGIN of this chunk's own terrain (that is the
-- tighter bound actually used), and coastal canopies live far below this.
-- A tree on a ramp column whose cap is near the maximum W+114 could in
-- principle put leaves up to ~147 — not worth a taller loop over every
-- shell column of every coastal chunk, so it is bounded here on purpose.
local SHELL_MAX_Y = 120

-- Inland-signed distance to the NEARER continent rectangle: positive inside,
-- negative outside, in nodes. Only three edges can be the nearest one for a
-- given continent — the flank (|x| = X_HALF), the strait-facing front
-- (|z| = Z_MIN) and the back (|z| = Z_MAX) — and since the two rectangles
-- are mirrored at z = 0, evaluating them on |z| yields the max over both
-- (the far continent is never the nearer one). Pure arithmetic: exposed so
-- it can be exercised without the engine.
local function continent_distance(x, z)
	local ax = x >= 0 and x or -x
	local az = z >= 0 and z or -z
	local d = X_HALF - ax -- flank
	local front = az - Z_MIN
	if front < d then
		d = front
	end
	local back = Z_MAX - az
	if back < d then
		d = back
	end
	return d
end
grug_mapgen.continent_distance = continent_distance

-- Highest y the terrain may keep at inland-signed distance s (after the
-- coast noise inset), or nil for "no cap at all" from TAPER inland — the
-- mask shapes the coast, it must never flatten the hinterland.
-- Seaward of the shoreline the cap is the ocean floor profile: a shelf from
-- ~5 below sea level at the beach to ~15 below out at SHELF_WIDTH (deeper is
-- pointless — v7's own seabed is below that anyway). Inland it rises
-- quadratically to ~W+114 across the ramp, so the last nodes before the
-- water sit at beach level and only real mountains near the shore get cut.
-- Strictly a function of (x, z): vertically stacked mapchunks of the same
-- column MUST agree on the cap, so nothing chunk-local (heightmap!) may
-- enter here.
local function surface_cap(s)
	if s >= TAPER then
		return nil
	end
	if s <= 0 then
		local away = -s
		if away > SHELF_WIDTH then
			away = SHELF_WIDTH
		end
		return math.floor(WATER_LEVEL - SHORE_DROP - 1 -
			away / SHELF_WIDTH * SHELF_DEPTH)
	end
	local t = s / TAPER -- 0 < t < 1, the s >= TAPER case returned above
	return math.floor(WATER_LEVEL - SHORE_DROP + t * t * TAPER_RISE)
end
grug_mapgen.surface_cap = surface_cap

-- Flat part of the shelf: everything from SHELF_WIDTH seaward shares one cap,
-- so the open sea needs no coast noise at all.
local SEA_FLOOR_CAP = surface_cap(-SHELF_WIDTH)

-- Deepest y the mask can ever carve (deepest shelf cap + 1).
-- Everything below is pure underground: such mapchunks are skipped outright,
-- so caves stay caves no matter how far out at sea they are. (The beach
-- re-surfacing reaches BEACH_DEPTH lower, but it only ever runs in a chunk
-- that carved something, i.e. one that is above this line.)
local MASK_MIN_Y = SEA_FLOOR_CAP + 1

-- core.get_perlin was renamed in 5.12; keep working on both.
local get_noise = core.get_value_noise or core.get_perlin

local coast_noise
local function coast_inset(x, z)
	coast_noise = coast_noise or get_noise({
		offset = 75, scale = 75,
		spread = {x = 300, y = 300, z = 300},
		seed = 91744, octaves = 3, persist = 0.55,
	})
	local inset = coast_noise:get_2d({x = x, y = z})
	if inset < 0 then
		return 0
	elseif inset > INSET_MAX then
		return INSET_MAX
	end
	return inset
end

-- Reused across mapchunks: vm:get_data() without a buffer allocates a fresh
-- ~11 MB table for every masked chunk.
local vm_data = {}

-- Content ids at file scope, the pattern the whole file uses: this chunk runs
-- when grug_mapgen loads, and every name below belongs to a mod grug_mapgen
-- declares in mod.conf `depends` (default, grug_nodes), so all of them are
-- registered by now. Only ids that depend on data resolved LATER (the biome
-- table) are looked up lazily — see biome_surface_at.
local c_air = core.get_content_id("air")
local c_ignore = core.get_content_id("ignore")
local c_cobble = core.get_content_id("default:cobble")
local c_sand = core.get_content_id("default:sand")
local c_water = core.get_content_id("default:water_source")
local c_tree = core.get_content_id("default:tree")
local c_banner = core.get_content_id("grug_nodes:guard_banner")

-- Content the re-dressing must not overwrite (it only ever replaces the
-- solid material it just exposed).
local not_solid = {
	[c_air] = true,
	[c_ignore] = true,
	[c_water] = true,
	[core.get_content_id("default:water_flowing")] = true,
	[core.get_content_id("default:river_water_source")] = true,
	[core.get_content_id("default:river_water_flowing")] = true,
}

-- Surface layers of a biome, by biome id, for re-dressing a cut top above
-- beach level: node_top (depth_top layers) over node_filler (FILLER_DEPTH
-- layers). Without it a shaved coastal hill would end in bare stone — not
-- walkable-looking, no mob spawn surface, no decorations. Resolved lazily
-- and cached: registered_biomes and content ids are fixed once mapgen runs.
-- false = "this biome cannot be re-dressed" (leave the cut material).
local biome_surface = {}
local function biome_surface_at(id)
	local surf = biome_surface[id]
	if surf == nil then
		surf = false
		local name = id and core.get_biome_name(id)
		local def = name and core.registered_biomes[name]
		if def and def.node_top and core.registered_nodes[def.node_top] then
			local filler = def.node_filler
			surf = {
				top = core.get_content_id(def.node_top),
				top_depth = def.depth_top or 1,
				filler = (filler and core.registered_nodes[filler]) and
					core.get_content_id(filler) or nil,
			}
		end
		biome_surface[id] = surf
	end
	return surf or nil
end

-- Chunk-level fast path: true only for mapchunks that can contain a coast
-- column at all. Pure arithmetic on the chunk box — no mapgen object is
-- fetched for the (vast majority) fully inland or deep chunks.
-- The box is the EMERGED one (minp..maxp grown by SHELL): the shell clean
-- works on those columns, so a chunk whose shell alone reaches the coast band
-- still has work to do.
local function chunk_needs_mask(minp, maxp)
	if maxp.y < MASK_MIN_Y then
		return false -- pure underground: caves stay caves
	end
	local ax = math.max(math.abs(minp.x), math.abs(maxp.x)) + SHELL
	local az_far = math.max(math.abs(minp.z), math.abs(maxp.z)) + SHELL
	local az_near = 0
	if minp.z > 0 then
		az_near = math.max(minp.z - SHELL, 0)
	elseif maxp.z < 0 then
		az_near = math.max(-maxp.z - SHELL, 0)
	end
	-- Smallest continent_distance anywhere in the emerged box.
	local d = math.min(X_HALF - ax, az_near - Z_MIN, Z_MAX - az_far)
	return d < TAPER + INSET_MAX
end

-- Cap of a single column — the whole geometry of the mask in one place, used
-- by the mapchunk pass and by the shell clean alike. nil means "hands off".
-- Depends on (x, z) only: every mapchunk that ever looks at this column, from
-- whatever direction and at whatever time, derives exactly the same cap.
local function column_cap(x, z)
	local d = continent_distance(x, z)
	if d >= TAPER + INSET_MAX then
		return nil -- inland, beyond the reach of the coast band
	end
	if d <= -SHELF_WIDTH then
		return SEA_FLOOR_CAP -- flat shelf: no noise lookup needed
	end
	return surface_cap(d - coast_inset(x, z))
end

-- Column rule (per x/z, run before the camps):
--   cap = column_cap(x, z), nil -> column untouched
--   carve when the mapgen heightmap h exceeds cap: water_source for
--   y <= water level, air above, from cap+1 up to the top of the column,
--   then re-dress the exposed top (sand at beach level, else the column's
--   biome surface).
-- h is clamped by the engine when the real surface lies outside the chunk's
-- y range (maxp.y if the ground continues above it, -MAX_MAP_GENERATION_LIMIT
-- if the column holds no walkable node at all), and `h > cap` happens to be
-- the correct decision in every one of those cases: ground above -> carve the
-- whole chunk, nothing walkable -> nothing to carve. h decides only WHETHER a
-- column is cut, never WHERE — the cut height is (x, z)-deterministic, so
-- vertically stacked mapchunks of one column cut at exactly the same y.
-- Returns whether any water was placed (the caller then updates liquids) and
-- the highest terrain in the chunk (the shell clean bounds itself by it).
local function build_ocean_mask(data, area, minp, maxp)
	local heightmap = core.get_mapgen_object("heightmap")
	if not heightmap then
		return false, nil
	end
	local biomemap = core.get_mapgen_object("biomemap")
	local width = maxp.x - minp.x + 1
	local ystride = area.ystride
	local wrote_water = false
	local max_h = -31000
	for i = 1, width * (maxp.z - minp.z + 1) do
		local h = heightmap[i]
		if h and h > max_h then
			max_h = h
		end
	end
	for z = minp.z, maxp.z do
		local row = (z - minp.z) * width
		for x = minp.x, maxp.x do
			local cap = column_cap(x, z)
			if cap then
				local i2d = row + (x - minp.x) + 1
				local h = heightmap[i2d]
				-- `cap <= maxp.y` (not <): when the cap sits exactly on the
				-- chunk's top edge the carve ranges come out empty, but the
				-- re-dress below must still run in THIS chunk -- the chunk
				-- above starts at cap+1 and can never write the top layers.
				if h and h > cap and cap <= maxp.y then
					local y1 = math.max(cap + 1, minp.y)
					local y2 = math.min(maxp.y, h + DECO_MARGIN)
					local wet = math.min(y2, WATER_LEVEL)
					if wet >= y1 then
						local idx = area:index(x, y1, z)
						for _ = y1, wet do
							data[idx] = c_water
							idx = idx + ystride
						end
						wrote_water = true
					end
					local dry = math.max(y1, WATER_LEVEL + 1)
					if y2 >= dry then
						local idx = area:index(x, dry, z)
						for _ = dry, y2 do
							data[idx] = c_air
							idx = idx + ystride
						end
					end
					-- Re-dress the exposed top: sand where the cut ends at
					-- beach/seabed level, otherwise the biome's own surface
					-- (a shaved coastal hill must stay walkable land, not a
					-- bare stone plateau).
					local top, top_depth, filler, layers
					if cap <= WATER_LEVEL + 3 then
						top, top_depth, layers = c_sand, BEACH_DEPTH, BEACH_DEPTH
					else
						local surf = biomemap and biome_surface_at(biomemap[i2d])
						if surf then
							top, top_depth = surf.top, surf.top_depth
							filler = surf.filler
							layers = top_depth + (filler and FILLER_DEPTH or 0)
						end
					end
					if top then
						local sy1 = math.max(cap - layers + 1, minp.y)
						local idx = area:index(x, cap, z)
						for y = cap, sy1, -1 do
							if not not_solid[data[idx]] then
								data[idx] = (cap - y) < top_depth and top or filler
							end
							idx = idx - ystride
						end
					end
				end
			end
		end
	end
	return wrote_water, max_h
end

-- Decoration overflow cleanup on the emerged shell (see the file header).
-- The schematics the engine placed for THIS chunk may have spilled up to
-- SHELL nodes into the neighbouring chunks; those neighbours ran their own
-- mask earlier and cannot remove nodes that appear afterwards, which left
-- floating canopies standing over the water. The overflow is still inside
-- this VM, so we clean it here, using the very same column_cap — it depends
-- on (x, z) only, so this chunk cuts the neighbour's column at exactly the
-- height the neighbour used, and the pass is idempotent: a column the
-- neighbour already masked is air/water above the cap and nothing matches.
-- Only solid content is replaced; `ignore` (never-generated volume) and
-- every water variant are left alone, and nothing below the cap is touched,
-- so caves and seabeds survive.
local function clean_shell(data, area, minp, maxp, emin, emax, max_h)
	-- Fresh overflow can only sit near this chunk's own terrain.
	local y_top = math.min(emax.y, SHELL_MAX_Y, max_h + DECO_MARGIN)
	if y_top < emin.y then
		return false
	end
	local ystride = area.ystride
	local wrote_water = false
	for z = emin.z, emax.z do
		local inner_z = z >= minp.z and z <= maxp.z
		for x = emin.x, emax.x do
			if not (inner_z and x >= minp.x and x <= maxp.x) then
				local cap = column_cap(x, z)
				if cap then
					local y1 = math.max(cap + 1, emin.y)
					if y_top >= y1 then
						local idx = area:index(x, y1, z)
						for y = y1, y_top do
							if not not_solid[data[idx]] then
								if y <= WATER_LEVEL then
									data[idx] = c_water
									wrote_water = true
								else
									data[idx] = c_air
								end
							end
							idx = idx + ystride
						end
					end
				end
			end
		end
	end
	return wrote_water
end

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
-- Exposed so the fallback can be exercised with a stub heightmap, without
-- the engine (same reason as continent_distance/surface_cap above).
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
-- there, and a flooded anchor is skipped rather than drowned.
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
-- REJECTION: an anchor whose surface ends up below y 2 or above y 100 is NOT
-- built and is marked as skipped in mod storage. world.md §9 promises a
-- minimum, not a guarantee at every single coordinate: a MISSING outpost is
-- acceptable, a drowned one — guards spawning in water, a banner under the
-- sea — is not.
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

local function outpost_skipped(id)
	return storage:get_string("outpost_skip:" .. id) ~= ""
end

-- Resolves (and persists) the outpost's surface y, or nil when this mapchunk
-- cannot decide it. Persisting happens through grug_core.add_poi: the POI
-- record IS the decision, which keeps the protected zone and the built
-- structure at exactly one shared height by construction.
local function outpost_y(anchor, minp, maxp)
	local poi = grug_core.get_poi(anchor.id)
	if poi then
		return poi.y_base
	end
	if outpost_skipped(anchor.id) then
		return nil
	end
	local y = grug_core.surface_level_at(anchor.x, anchor.z)
		or heightmap_median(anchor.x, anchor.z, OUTPOST_PAD, minp, maxp)
	if not y then
		return nil -- chunk fully above/below the surface: another one decides
	end
	y = math.floor(y)
	-- Clamp to the coast profile (see above): nil = inland, no cap at all.
	local cap = column_cap(anchor.x, anchor.z)
	if cap and cap < y then
		y = cap
	end
	if y < OUTPOST_MIN_Y or y > OUTPOST_MAX_Y then
		local reason = y < OUTPOST_MIN_Y and "flooded" or "too high"
		storage:set_string("outpost_skip:" .. anchor.id, reason)
		core.log("action", ("[grug_mapgen] outpost %s skipped (%s, y=%d)")
			:format(anchor.id, reason, y))
		return nil
	end
	grug_core.add_poi({
		id = anchor.id,
		x = anchor.x,
		z = anchor.z,
		half = OUTPOST_PROTECT_HALF,
		y_base = y,
	})
	core.log("action", ("[grug_mapgen] outpost %s anchored at %d,%d,%d")
		:format(anchor.id, anchor.x, y, anchor.z))
	return y
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
		-- into a live guard post on first load — that is why the LBM exists.
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
-- able to grief; a camp is the opposite). No add_poi call, no skip marker
-- either — there is no structure to leave half-built, so a chunk that cannot
-- decide the height simply does nothing and the anchor stays unbuilt.
--
-- HEIGHT: the same rule as everything else here, minus the persistence. The
-- camp occupies exactly one column, so only ONE mapchunk ever places it and
-- there is no cross-chunk agreement to maintain: engine spawn level first,
-- heightmap median over a 5×5 as the fallback, clamped to the coast profile,
-- and the same 2..100 sanity window the outposts use (all twelve anchors are
-- inland — |x| <= 670, |z| <= 1350, i.e. >= 350 nodes from any rectangle edge
-- — so column_cap returns nil for them and the clamp is pure belt and braces).
--
-- The node arrives by VoxelManip, which fires no callbacks, so its meta and
-- its node timer are set up by the LBM "grug_mobs:camp_fire_init"
-- (grug_mobs/camps.lua) — exactly the same arrangement as the guard banner.
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

local function bandit_camp_y(anchor, minp, maxp)
	local y = grug_core.surface_level_at(anchor.x, anchor.z)
		or heightmap_median(anchor.x, anchor.z, BANDIT_SAMPLE, minp, maxp)
	if not y then
		return nil
	end
	y = math.floor(y)
	local cap = column_cap(anchor.x, anchor.z)
	if cap and cap < y then
		y = cap
	end
	if y < OUTPOST_MIN_Y or y > OUTPOST_MAX_Y then
		return nil
	end
	return y
end

core.register_on_generated(function(minp, maxp, blockseed)
	local need_mask = chunk_needs_mask(minp, maxp)

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
	local outposts = {}
	local anchors = grug_core.outpost_anchors()
	for i = 1, #anchors do
		local a = anchors[i]
		if maxp.x >= a.x - OUTPOST_HALF and
				minp.x <= a.x + OUTPOST_HALF and
				maxp.z >= a.z - OUTPOST_HALF and
				minp.z <= a.z + OUTPOST_HALF then
			local y = outpost_y(a, minp, maxp)
			if y and maxp.y >= y - OUTPOST_SKIRT and
					minp.y <= y + OUTPOST_CLEAR then
				outposts[#outposts + 1] = {x = a.x, y = y, z = a.z}
			end
		end
	end

	-- Bandit camps: one node each, so the collect step is just "is this
	-- anchor's column in the chunk, and does its fire node land in the chunk's
	-- y range". Nothing is persisted and nothing is protected (see above).
	local fires = {}
	local fire_id = camp_fire_id()
	if fire_id then
		local bandits = grug_core.bandit_camp_anchors()
		for i = 1, #bandits do
			local b = bandits[i]
			if b.x >= minp.x and b.x <= maxp.x and
					b.z >= minp.z and b.z <= maxp.z then
				local y = bandit_camp_y(b, minp, maxp)
				if y and y + 1 >= minp.y and y + 1 <= maxp.y then
					fires[#fires + 1] = {x = b.x, y = y + 1, z = b.z}
				end
			end
		end
	end

	if not need_mask and #camps == 0 and #outposts == 0 and #fires == 0 then
		return
	end

	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	-- Reused buffer: a fresh get_data() table is ~11 MB of garbage per chunk.
	local data = vm:get_data(vm_data)

	local wrote_water = false
	if need_mask then
		local max_h
		wrote_water, max_h = build_ocean_mask(data, area, minp, maxp)
		if max_h then
			-- After the mapchunk pass: the shell columns belong to already
			-- finished neighbours, only this chunk's decoration overflow is
			-- new there.
			if clean_shell(data, area, minp, maxp, emin, emax, max_h) then
				wrote_water = true
			end
		end
	end
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
	if wrote_water then
		-- Without this the water we placed never starts flowing: coastal
		-- caves and cut-open hollows keep standing water walls.
		vm:update_liquids()
	end
	vm:calc_lighting()
	vm:write_to_map()
end)
