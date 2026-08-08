-- CONTINENT OCEAN MASK — the main-environment half. Three jobs, none of them
-- voxel work (the carve itself lives in ocean_mask_mapgen.lua and runs in the
-- mapgen environment):
--
--   1. build the shared geometry from grug_core's continent rectangle and hand
--      the same three numbers to the mapgen environment via IPC;
--   2. register the mapgen script;
--   3. register the idempotent healing LBM for worlds generated before WP36.
--
-- Nothing here may assume the mapgen env exists yet: the mapgen threads are
-- initialized after every mod is loaded (lua_api.md:7688-7690), so the IPC value
-- below is always in place by the time ocean_mask_mapgen.lua reads it.

local path = core.get_modpath(core.get_current_modname())

--
-- (1) Geometry — one source of truth for two Lua states
--

local CONTINENT = {
	x_half = grug_core.CONTINENT_X_HALF,
	z_min = grug_core.CONTINENT_Z_MIN,
	z_max = grug_core.CONTINENT_Z_MAX,
}

local geom = dofile(path .. "/geometry.lua")(CONTINENT)
grug_mapgen.geometry = geom

-- Kept as direct handles for the same reason they always were: these are pure
-- arithmetic and can be exercised headless, without the engine. Nothing outside
-- this mod may re-derive the coast profile — ask these.
-- NB tools/biomecheck/model.py re-implements exactly this geometry and its
-- header cites structures.lua; the logic now lives in geometry.lua.
grug_mapgen.continent_distance = geom.continent_distance
grug_mapgen.surface_cap = geom.surface_cap
grug_mapgen.column_cap = geom.column_cap

--
-- (2) The mapgen script
--

-- The mapgen env is a separate Lua state: no grug_core, no mod storage, no POI
-- registry. It gets the rectangle — and only the rectangle, the profile is
-- geometry.lua's — through the engine's cross-environment key/value store
-- (lua_api.md:7825-7840).
core.ipc_set("grug_mapgen:continent", CONTINENT)
core.register_mapgen_script(path .. "/ocean_mask_mapgen.lua")

--
-- (3) The healing LBM (WP36 item 2)
--
-- Every world generated before this WP carries floating tree crowns over the
-- coastal water: the mask clamped its carve to maxp.y while the engine places
-- schematic decorations up to emax.y = maxp.y + 16 (mg_decoration.cpp:424).
-- Mapgen never runs over a generated chunk again, so the fix in
-- ocean_mask_mapgen.lua cannot reach those worlds — an LBM can.
--
-- WHY IT IS SAFE TO RUN AT EVERY LOAD: column_cap is a pure function of (x, z),
-- so the sweep knows WHERE the mask cuts a column, in any session, and a column
-- that is already correct is air/water above its cap, where nothing below
-- matches. It is therefore SELF-EXTINGUISHING: once a block is healed it has no
-- matching node above its cap left, so every later activation writes nothing.
--
-- WHAT IT KNOWS AND WHAT IT HAS TO RECONSTRUCT (the WP36 review's High 1).
-- column_cap says where the cut sits, NOT whether the mapgen made it: the carve
-- is conditional on the chunk heightmap — `h and h > cap` in
-- ocean_mask_mapgen.lua — and that is the design, "the mask shapes the coast
-- and leaves the hinterland to v7". A column whose terrain already stands at or
-- below its cap is never touched by the mask, and cutting it here would shave
-- perfectly legal coastal forest: with terrain h = 10 and cap = 15 an apple
-- tree grows y 11..21, and an unconditional sweep would air everything above
-- y 15 and leave a 5-node stump. The vulnerable band is 12-23 nodes wide over
-- the whole coastline of both continents.
--
-- An LBM has no heightmap, but the map itself carries the answer, because the
-- mask leaves a signature and v7 leaves a different one:
--
--   * a CARVED column (h > cap) whose cap node was solid material shows the
--     mask's RE-DRESSED SURFACE exactly at the cap — sand at beach level, else
--     the biome's node_top over node_filler (ocean_mask_mapgen.lua's re-dress
--     block) — and air or water directly above it, because the carve cleared
--     cap+1 upward before re-dressing.
--   * an UNCARVED column (h <= cap) shows at the cap whatever v7 and the
--     decoration stage put there: air, a trunk, leaves, a snow layer — its
--     ground top is at h, BELOW the cap. In the case above it reads
--     `default:tree` at y 15 and dirt_with_grass at y 10.
--
-- THE FIRST BULLET IS SUFFICIENT, NOT NECESSARY (WP36 re-review). An earlier
-- version of this header claimed the re-dress "cannot be skipped for a carved
-- column, because `h > cap` means the node at the cap was solid material". That
-- is not what `h` is. It comes from Mapgen::updateHeightmap -> findGroundLevel,
-- the topmost WALKABLE node of the column (mapgen.cpp:238-252, :276-290), taken
-- directly after generateTerrain and therefore BEFORE biomes, caves, dungeons
-- and decorations (mapgen_v7.cpp:322-324 vs :331-364). `h > cap` says only that
-- something walkable stands above the cap; the node AT the cap may be a
-- mountain-noise overhang gap, a river channel or a cave. The re-dress loop
-- tests `not not_solid[...]` per layer, writes nothing there, and the column
-- keeps air at its cap — so it reads as UNCARVED here forever. Residual class
-- (1) below; the direction is the safe one.
--
-- Hence the discriminator in column_carved(): cut only where the node AT the
-- cap is biome ground AND the node directly above it is air or liquid. Both
-- halves are needed — the first protects the leaf columns of an overhanging
-- canopy (their ground is below the cap), the second the trunk column of a tree
-- rooted exactly at h = cap, and every structure whose base the mapgen clamped
-- ONTO the cap (an outpost pad is cobble at the cap with posts above it, and
-- cobble is not biome ground either).
--
-- ERRORS ARE ALMOST ALL ONE-SIDED BY CONSTRUCTION. Everything unexpected —
-- `ignore` from an unloaded neighbour, a cave mouth at the cap, a player's
-- floor above the cap, cobble from a structure — fails one of the two tests and
-- the column is left ALONE, so the sweep misses overflow far more often than it
-- over-reaches, and a miss is retried on every later load. It is NOT, however,
-- incapable of cutting something the mapgen would have kept: class (2) below is
-- exactly that, and an earlier version of this header denied it existed ("it
-- cannot invent a cut the mapgen would not have made", "all of them overflow
-- survives, none of them legal terrain is cut"). Both sentences were wrong.
--
-- FOUR RESIDUAL CLASSES. The label each one carries is the honest one; do not
-- summarise them as if they were all "overflow survives".
--
--   (1) OVERFLOW SURVIVES. A column the mask DID carve but could not re-dress
--       at the cap (the paragraph above: overhang gap, river channel or cave at
--       the cap level). It reads as uncarved, so its share of an old world's
--       floating crown stays. Caves crossing the coast band's cap range are not
--       rare.
--   (2) LEGAL TERRAIN IS CUT — the direction this header used to call
--       impossible. A column whose terrain top is EXACTLY at its cap carries
--       the biome's node_top there (is_ground ✓) and air at cap+1
--       (clear_above ✓), so the discriminator answers CARVED and the sweep airs
--       every healable node above the cap. Right for a floating crown, wrong
--       for foliage rooted in a NEIGHBOURING column: default's apple_tree.mts
--       is 7x8x7 placed with place_center_x/z, and while its trunk slices
--       y+0..y+3 reach 0 columns sideways, its crown reaches 3 columns at
--       y+4/y+5 and still 2 at y+6. A column two nodes from such a trunk, with
--       h == cap, therefore holds leaves at root+4..root+6 over air at cap+1 —
--       and loses them. Confined to the h == cap contour line of the coast
--       band, and indistinguishable from a floating crown by ANY per-column
--       signal: the only signal left is sideways, and probing eight neighbours
--       over several y per candidate column is not something a sweep that runs
--       on every block load can pay for. Kept as a documented cut.
--   (3) OVERFLOW SURVIVES, and the more common of the (2)/(3) pair: a tree
--       rooted in a CARVED column whose schematic footprint (5x5 for aspen,
--       jungle and pine, 7x7 for apple and the emergent jungle tree) reaches
--       into a neighbour column with h <= cap. The neighbour was never carved, so the
--       neighbour's share of the crown is not overflow by this sweep's
--       definition and is left standing. Concretely: inland ramp at s = 90,
--       i.e. cap = 38, mapchunk -32..47, root column h = 40 > cap, neighbour
--       column h = 35 <= cap; the old world clipped the crown at maxp.y = 47,
--       this sweep heals the root column and the neighbour keeps its leaves at
--       48..51. So "a genuinely floating crown is still fully removed" holds
--       only where the whole footprint sits over carved columns; at the h ~ cap
--       boundary a fringe survives, and it survives DELIBERATELY — healing a
--       neighbour column because some other column near it was carved is
--       exactly the unconditional cut that decapitates a legitimate coastal
--       tree (the WP36 review's High 1), only with a wider blast radius.
--   (4) OVERFLOW SURVIVES, in worlds generated before the WP36 re-review's
--       Medium 1 fix only. A column whose cap lands EXACTLY on a mapchunk top
--       edge — y 47 is the only such edge inside the -15..114 cap range at the
--       default chunksize — used to keep bare `default:stone` at the cap: the
--       lower chunk's `h > cap` can never fire there (h is clamped to maxp.y by
--       findGroundLevel, mapgen.cpp:238-252) and the upper chunk's re-dress
--       loop came out empty (sy1 = cap+1). Stone is no biome's node_top, so
--       is_ground fails and such a column reads UNCARVED here and in
--       clean_shell forever, whatever stands above it — plus a bare-stone
--       contour along the whole coastline with no biome top, no decoration
--       surface and no _grug_spawn_zones ground. Fresh worlds do not have it:
--       build_ocean_mask owns that re-dress now (its `cap == maxp.y` branch).
--       Old ones keep it, because repairing it here would mean WRITING ground
--       at a cap this sweep is not sure was cut — the unconditional write the
--       whole discriminator exists to avoid.
--
-- All four are bounded to the h ~ cap contour of the coast band. NONE of them
-- is LBM-only. clean_shell in ocean_mask_mapgen.lua runs the SAME two-node
-- signature test (`is_ground(...) and clear_above[...]`), so (1), (2) and (4)
-- hit the 16-node shell ring of every coastal mapchunk in a BRAND NEW world as
-- well, and (3) is a property of the mapchunk carve itself, i.e. of generation
-- time. An earlier version of this list claimed "(1) and (2) are LBM-only — the
-- mapgen pass carves by heightmap, not by signature": true of build_ocean_mask,
-- false of clean_shell, whose own header has documented the signature test for
-- (1) since it was written.
--
-- PROTECTED POIs ARE NEVER TOUCHED (the review's High 2). candidate_ground_y in
-- structures.lua clamps an outpost to its column_cap, so its four
-- `default:tree` corner posts stand ABOVE the cap by construction — and
-- `default:tree` is healable content. The discriminator above already saves
-- them (cobble at the cap, a post at cap+1), but "the LBM must not touch a
-- protected POI" is the rule, not a lucky consequence, so the whole mapblock is
-- skipped when grug_core's registry reports a protected zone in it. That covers
-- the capital platforms, the 24 outposts and whatever WP13 registers next, by
-- the same rule and at the price of one arithmetic scan per candidate block.
--
-- run_at_every_load = true is required, not preferred: an LBM with
-- run_at_every_load = false never runs on mapblocks generated after the LBM was
-- introduced (lua_api.md:10312-10316), which would leave any chunk generated
-- from now on — i.e. exactly the ones a player is about to walk into —
-- unhealed on a world that is otherwise fixed.
--
-- COST. Four gates, in increasing order of price; the first three are O(1) per
-- mapblock:
--
--  a) The engine already scans every activated mapblock for run_at_every_load
--     LBMs — grug_mobs' guard_banner_init and camp_fire_init are two of them —
--     and all of them share ONE bucket in the lookup table (blockmodifier.cpp
--     :380-386, keyed U32_MAX). Adding this LBM therefore adds no block scan
--     at all; it only extends the content-id -> LBM mapping that scan already
--     consults. Nothing reaches Lua for a block without a matching node.
--  b) box_needs_mask on the mapblock box: a block that is fully inland
--     (continent_distance >= TAPER + INSET_MAX everywhere) or entirely at or
--     below the deepest cap the mask can ever produce (MASK_MIN_Y) returns
--     immediately — the same arithmetic gate the mapgen pass uses, with
--     grow = 0 because an LBM only sees the block's own nodes.
--  c) box_cap_bounds, still without a noise sample: below the box's lowest
--     possible cap there is nothing to do (this covers the low-altitude forest
--     of the inner coast band, the bulk of what survives gate b). The mirror
--     shortcut of the first version — "above the box's highest possible cap,
--     skip the per-column lookup entirely" — is GONE: the discriminator has to
--     probe AT the cap, so the exact cap is needed for every column that
--     carries a candidate node. That is the price of not decapitating trees.
--     Then the POI box test of grug_core, same arithmetic class.
--  d) Per COLUMN THAT ACTUALLY CARRIES A CANDIDATE NODE (never 256 unless the
--     block is solid canopy): one column_cap — i.e. one noise sample — and two
--     core.get_node_raw probes, all memoised for the whole mapblock, not just
--     for one bulk_action call: applyLBMs batches per content id
--     (blockmodifier.cpp:471-535), so a coastal forest block enters here 4-8
--     times in a row with the same block position (s_env.cpp:464-477 guarantees
--     one bulk_action = one mapblock).
--
-- Measured over 133 705 mapblock boxes spread across the whole coast band
-- (the headless gate census, geometry only): 47.8 % never get past gate b,
-- 3.7 % are killed by the low cap bound, and 48.4 % reach the per-column stage
-- — of which 31.9 percentage points are the class the removed above-cap
-- shortcut used to resolve for free. That census counts BOXES, not LBM calls:
-- the shortcut class is the volume above the coast, where a block only reaches
-- Lua at all if it holds decoration content, i.e. a hilltop tree or exactly the
-- floating crown this sweep exists for.
--
-- BLAST RADIUS. nodenames is not "everything solid": it is the content the
-- engine's own decoration stage can place, minus terrain material (see
-- healable_nodes below). An LBM cannot tell mapgen overflow from a player
-- build, and the honest limit of that is stated there.
--

local column_cap = geom.column_cap
local box_needs_mask = geom.box_needs_mask
local box_cap_bounds = geom.box_cap_bounds
local WATER_LEVEL = geom.WATER_LEVEL
local MASK_MAX_Y = geom.MASK_MAX_Y

local AIR = {name = "air"}
local WATER = {name = "default:water_source"}

-- The set the sweep is allowed to remove.
--
-- Derived, never hand-written: every node name that appears in a registered
-- decoration (the schematic's voxels, or a simple decoration's node list),
-- because that is exactly the content that can end up above the cap after the
-- mask ran — mgv7 places a decoration's ROOT inside minp..maxp
-- (mg_decoration.cpp:229-231), so only the part of a SCHEMATIC that reaches
-- past maxp.y ever survived the old carve.
--
-- Minus two exclusions:
--   * air, ignore and every liquid — the mask never replaces those, and
--     `ignore` in particular is never-generated volume;
--   * terrain material: any node that is also a biome surface/filler/stone/
--     riverbed/dust node or the place_on target of some decoration. The one
--     real case is default:dirt, which papyrus_on_dirt.mts carries in its
--     bottom slice — that slice sits at the decoration's root and was always
--     carved, so it cannot float, and keeping dirt out of this list means a
--     player's dirt platform over the coastal water is not something a block
--     load deletes.
-- The honest residual: a player who builds a treehouse out of trunks and leaves
-- ABOVE the coast profile (above column_cap, which over the water is below sea
-- level) will lose it — unless it stands on its own floor, in which case the
-- carved-column discriminator below sees ground where the mask left none and
-- keeps hands off the whole column. There is no signal in the map that
-- distinguishes a naked crown built by a player from mapgen overflow, and the
-- alternative — never healing existing worlds — is worse. Everything below the
-- cap, and everything outside the coast band, is untouched.
--
-- SCHEMATIC `replacements` ARE PART OF THE DERIVATION (the review's Medium 1).
-- A decoration may rewrite the schematic's node names on placement
-- (decorations.lua: elf_forest_silverwood is default's aspen_tree.mts with
-- default:aspen_tree -> grug_trees:silverwood_tree), and only the REPLACED name
-- ever reaches the map. Reading the raw .mts voxels alone would put the aspen
-- in the list and leave every floating silverwood crown of the elf coast
-- unhealed forever. Each voxel name therefore goes through this decoration's
-- own replacement table, and every replacement TARGET is added unconditionally
-- on top — that second rule is what still covers a decoration whose schematic
-- did not arrive as a voxel table at all (see `blind` below).
--
-- Returns: the LBM's node list, the GROUND set the carved-column discriminator
-- probes with, and the list of decorations whose content could not be
-- enumerated.
--
-- THE GROUND SET IS EXACTLY WHAT THE MASK'S RE-DRESS WRITES AT THE CAP, i.e.
-- every biome's node_top (that includes default:sand, which is the node_top of
-- both grug_beach and grug_ocean and what the mask puts on a cut at beach
-- level). Deliberately NOT the other terrain fields, although they are terrain:
--   * node_filler / node_stone are what a CAVE FLOOR is made of, and a cave
--     floor that happens to sit exactly at a column's cap, with cave air above
--     it, would otherwise read as the mask's re-dress and cost that column's
--     tree;
--   * node_riverbed is the floor of a river channel, with river water above it
--     — the same false reading;
--   * node_dust (a snow layer, say) sits ABOVE the surface, not at it, so it is
--     never what the re-dress writes at a cap — and it is placed by
--     dustTopNodes on whatever the column's top happens to be, which is not a
--     signature of anything. (An earlier version of this line justified the
--     exclusion with "a decoration's place_on can be a tree trunk, e.g.
--     grug_trees:gravewood_tree". That is wrong: GRAVEWOOD is a `decoration`
--     value in decorations.lua:141/270/281, never a `place_on`; every place_on
--     in that file is a biome node_top. The exclusion stands on its own.)
-- The one thing this costs: a carved column that could NOT be re-dressed (the
-- mapgen pass leaves the cut material when it cannot resolve a biome) is not
-- recognised and stays unhealed. mgv7 always provides a biomemap and every
-- biome here defines node_top, so that branch is unreachable in this game.
local function healable_nodes()
	local terrain = {}
	local ground = {}
	local function block(name, is_ground)
		if type(name) == "string" then
			terrain[name] = true
			if is_ground then
				local def = core.registered_nodes[name]
				if def and (not def.liquidtype or def.liquidtype == "none") then
					ground[name] = true
				end
			end
		end
	end
	for _, def in pairs(core.registered_biomes) do
		block(def.node_top, true)
		block(def.node_filler)
		block(def.node_stone)
		block(def.node_riverbed)
		block(def.node_dust)
		block(def.node_water_top)
		block(def.node_water)
		block(def.node_river_water)
		block(def.node_cave_liquid)
	end
	for _, def in pairs(core.registered_decorations) do
		local on = def.place_on
		if type(on) == "table" then
			for i = 1, #on do
				block(on[i])
			end
		else
			block(on)
		end
	end

	local names, seen = {}, {}
	local function add(name)
		if type(name) ~= "string" or name == "" or seen[name] then
			return
		end
		seen[name] = true
		if name == "air" or name == "ignore" or terrain[name] then
			return
		end
		local def = core.registered_nodes[name]
		if not def then
			return
		end
		if def.liquidtype and def.liquidtype ~= "none" then
			return
		end
		names[#names + 1] = name
	end

	local blind = {}
	for _, def in pairs(core.registered_decorations) do
		local repl = type(def.replacements) == "table" and def.replacements
			or nil
		if def.deco_type == "schematic" then
			-- register_decoration keeps the def table we passed
			-- (builtin/game/register.lua:502-512), so this is the read_schematic
			-- table decorations.lua built.
			local schem = def.schematic
			local voxels = type(schem) == "table" and schem.data
			if type(voxels) == "table" then
				for i = 1, #voxels do
					local n = voxels[i].name
					add(repl and repl[n] or n)
				end
			else
				-- A `schematic` that is a file path (or anything else) is
				-- opaque here: the engine loads and caches it in C++ and its
				-- voxels never reach Lua. decorations.lua passes tables for a
				-- different reason (the path cache bug in its header) and this
				-- is the second one.
				blind[#blind + 1] = def.name or "<unnamed decoration>"
			end
		else
			local d = def.decoration
			if type(d) == "table" then
				for i = 1, #d do
					add(repl and repl[d[i]] or d[i])
				end
			else
				add(repl and repl[d] or d)
			end
		end
		if repl then
			for _, target in pairs(repl) do
				add(target)
			end
		end
	end
	return names, ground, blind, terrain
end

-- Filled in at the bottom of this file, where the LBM is registered (the node
-- list has to be complete before core.register_lbm sees it); forward-declared
-- here because heal_block below needs the ground set.
local healable, healable_ground, healable_blind

-- Content ids for the two probes. Resolved on first use, not at load time: the
-- node definitions are only frozen once every mod is registered, and this file
-- runs while grug_mapgen loads.
local ground_ids, clear_ids

local function build_probe_ids(ground_names)
	ground_ids = {}
	for name in pairs(ground_names) do
		if core.registered_nodes[name] then
			ground_ids[core.get_content_id(name)] = true
		end
	end
	-- "clear" = what the mask itself leaves above a cut: air and every liquid
	-- (the carve writes water below sea level, and flowing variants appear
	-- afterwards). `ignore` is deliberately NOT clear — an unloaded or
	-- never-generated neighbour must read as "unknown", i.e. hands off.
	clear_ids = {[core.get_content_id("air")] = true}
	for name, def in pairs(core.registered_nodes) do
		if def.liquidtype and def.liquidtype ~= "none" then
			clear_ids[core.get_content_id(name)] = true
		end
	end
end

-- Does the map still show the mask's own cut in this column? See the block
-- comment above for why this question exists and why every uncertain answer is
-- `false`. `loader` is called at most once per mapblock and pulls the cap level
-- into memory when the probe hits an unloaded neighbour — without it the heal
-- would silently depend on the order in which the engine activates blocks.
local function probe(x, y, z, loader)
	local c, _, _, ok = core.get_node_raw(x, y, z)
	if not ok then
		-- pos_ok = false means the mapblock is not in memory, and the content
		-- id that comes with it is CONTENT_IGNORE (lua_api.md:6914-6918) — not
		-- an answer about the map.
		if not loader() then
			return nil
		end
		c, _, _, ok = core.get_node_raw(x, y, z)
		if not ok then
			return nil
		end
	end
	return c
end

local function column_carved(x, cap, z, loader)
	local at = probe(x, cap, z, loader)
	if not at or not ground_ids[at] then
		return false -- terrain top is elsewhere: v7's column, not the mask's
	end
	local above = probe(x, cap + 1, z, loader)
	return above ~= nil and clear_ids[above] == true
end

-- Per-MAPBLOCK memo, kept across bulk_action calls on purpose: applyLBMs
-- batches per content id (blockmodifier.cpp:471-535), so one coastal forest
-- block calls in 4-8 times in a row and rebuilding the cap table each time
-- would pay for the same up-to-256 noise samples that often. One block at a
-- time is enough — the engine finishes a block's LBMs before it moves on.
local memo_key
local memo_caps = {}
local memo_carved = {}
-- Same lifetime, same reason (WP36 re-review, Low 4): this used to be a local
-- of heal_block, which made "at most once per block" false — it reset on each
-- of the 4-8 bulk_action calls the engine makes for one mapblock while
-- memo_caps/memo_carved survived, so a block with an unloaded neighbour below
-- paid for up to eight core.load_area calls instead of one.
local memo_loaded = false

-- One bulk_action call = one mapblock (s_env.cpp:464-477), one content id.
local function heal_block(pos_list)
	local first = pos_list[1]
	if not first then
		return
	end
	local bx = math.floor(first.x / 16) * 16
	local by = math.floor(first.y / 16) * 16
	local bz = math.floor(first.z / 16) * 16
	local bmin = {x = bx, y = by, z = bz}
	local bmax = {x = bx + 15, y = by + 15, z = bz + 15}
	if not box_needs_mask(bmin, bmax, 0) then
		return
	end
	local cap_lo, cap_hi = box_cap_bounds(bmin, bmax, 0)
	if not cap_lo or bmax.y <= cap_lo then
		return -- the whole block sits at or below the lowest cap it can have
	end
	-- A protected POI is off limits, whatever it is made of (see the header):
	-- the outposts' four default:tree corner posts stand above the cap because
	-- mapgen clamped the pad ONTO the cap, and a capital platform, a WP13
	-- village or anything else in the registry has the same claim.
	if grug_core.protected_zone_in_box(bmin, bmax) then
		return
	end
	if not ground_ids then
		build_probe_ids(healable_ground)
	end

	local block_key = bx .. "," .. by .. "," .. bz
	if memo_key ~= block_key then
		memo_key = block_key
		memo_caps = {}
		memo_carved = {}
		memo_loaded = false
	end
	-- Lazy, at most once per block, and only when a probe actually found an
	-- unloaded neighbour: the cap of a column can sit several mapblocks below
	-- the crown that is being healed. core.load_area reads from disk, it never
	-- generates (lua_api.md), so it cannot pull new terrain into existence.
	local function loader()
		if memo_loaded then
			return false -- already tried; a second call cannot help
		end
		memo_loaded = true
		core.load_area({x = bx, y = cap_lo, z = bz},
			{x = bx + 15, y = math.min(cap_hi or MASK_MAX_Y, bmax.y - 1) + 1,
				z = bz + 15})
		return true
	end

	local air, water, n_air, n_water = {}, {}, 0, 0
	for i = 1, #pos_list do
		local p = pos_list[i]
		local key = (p.x - bx) * 16 + (p.z - bz)
		local cap = memo_caps[key]
		if cap == nil then
			cap = column_cap(p.x, p.z)
			if cap == nil then
				cap = false -- inland column: hands off, memoise that too
			end
			memo_caps[key] = cap
		end
		local cut = false
		if cap and p.y > cap then
			-- Only now, and only once per column: a column whose nodes all sit
			-- at or below its cap is finished without touching the map.
			cut = memo_carved[key]
			if cut == nil then
				cut = column_carved(p.x, cap, p.z, loader)
				memo_carved[key] = cut
			end
		end
		if cut then
			if p.y <= WATER_LEVEL then
				n_water = n_water + 1
				water[n_water] = p
			else
				n_air = n_air + 1
				air[n_air] = p
			end
		end
	end
	-- set_node, not swap_node: removing a canopy changes the light below it and
	-- the water has to start flowing, both of which only the full node-set path
	-- schedules.
	if n_air > 0 then
		core.bulk_set_node(air, AIR)
	end
	if n_water > 0 then
		core.bulk_set_node(water, WATER)
	end
end

-- Registered at LOAD TIME, deliberately, and never from register_on_mods_loaded:
-- core.register_lbm runs check_modname_prefix, which derives the required
-- "grug_mapgen:" prefix from core.get_current_modname()
-- (builtin/game/register.lua:58-69, :106). That is nil outside a mod's own load,
-- so the same call from an on_mods_loaded callback errors out on its own name.
--
-- Load time is sound for the node list too: init.lua dofiles biomes.lua and
-- decorations.lua before this file, and grug_mapgen registers every biome and
-- every decoration in this game (default's own sets are deliberately never
-- called — see the tail of mods/BASE/default/mapgen.lua). The audit below is
-- what keeps that assumption honest instead of silent.
healable, healable_ground, healable_blind = healable_nodes()

if #healable_blind > 0 then
	core.log("warning", "[grug_mapgen] the ocean mask healing LBM cannot see " ..
		"the content of " .. table.concat(healable_blind, ", ") .. ": their " ..
		"`schematic` never reached Lua as a voxel table, so their overflow " ..
		"stays unhealed — register them with core.read_schematic() like " ..
		"decorations.lua does")
end

if #healable > 0 then
	core.register_lbm({
		label = "Ocean mask: remove decoration overflow above the coast cap",
		name = "grug_mapgen:ocean_mask_heal",
		nodenames = healable,
		run_at_every_load = true,
		bulk_action = function(pos_list)
			heal_block(pos_list)
		end,
	})
else
	core.log("warning", "[grug_mapgen] no decoration content found — the " ..
		"ocean mask healing LBM is not registered")
end

-- How far above the mapgen heightmap value can a registered decoration reach?
-- That number is the whole justification for geometry.lua's DECO_MARGIN, which
-- bounds the carve ceiling in BOTH passes of ocean_mask_mapgen.lua — and, since
-- the WP36 re-review's Low 1, the sunlight stamp with it: "above the ceiling
-- there is no decoration content" is what makes "everything above a carved cap
-- is air we wrote" true, and a stamp on a false version of that claim is
-- permanent (spreadLight only ever raises light). Today the maximum is exactly
-- DECO_MARGIN — emergent_jungle_tree.mts, size.Y 37 with place_offset_y = -4,
-- so -4 + 36 = 32, next highest jungle_tree.mts at 16 — i.e. ZERO headroom, and
-- emergent_jungle_tree is a coast-band decoration. One taller schematic and the
-- mask would silently leave floating crowns again, so this is audited instead
-- of assumed.
--
-- The two engine formulas, both taking `p` = the surface node the decoration is
-- placed ON (mg_decoration.cpp:231-247 passes the heightmap value itself):
--   * schematic — DecoSchematic::generate (mg_decoration.cpp:400-421): the
--     bottom slice sits AT p, then `p.Y += place_offset_y` (or
--     `p.Y -= (size.Y-1)/2` when place_center_y is set), so the top node is
--     p.Y + place_offset_y + size.Y - 1.
--   * simple — DecoSimple::generate: the write loop steps +1 BEFORE each node
--     from p.Y + place_offset_y, so the top node is
--     p.Y + place_offset_y + max(height, height_max).
-- Schematics whose voxels never reached Lua have no size here either; they are
-- already reported by the `blind` warning above and are not counted twice.
local function deco_reach()
	local worst, who = 0, nil
	for _, def in pairs(core.registered_decorations) do
		local off = tonumber(def.place_offset_y) or 0
		local reach
		if def.deco_type == "schematic" then
			local schem = def.schematic
			local size = type(schem) == "table" and schem.size
			if type(size) == "table" and tonumber(size.y) then
				local flags = type(def.flags) == "string" and def.flags or ""
				if flags:find("place_center_y", 1, true) and
						not flags:find("noplace_center_y", 1, true) then
					reach = size.y - 1 - math.floor((size.y - 1) / 2)
				else
					reach = off + size.y - 1
				end
			end
		else
			local h = math.max(tonumber(def.height) or 1,
				tonumber(def.height_max) or 0)
			reach = off + h
		end
		if reach and reach > worst then
			worst, who = reach, def.name or "<unnamed decoration>"
		end
	end
	return worst, who
end

-- Startup audit (the grug_traders pattern: silent when clean). Three classes,
-- and the second one is the review's Medium 1 lesson: re-running the same
-- derivation only catches content that ARRIVED LATE, never content the
-- derivation is structurally blind to. So the audit does not stop at the
-- diffing.
--
--  1. LATE DECORATIONS. If a mod that loads after grug_mapgen registers
--     decorations, their content is NOT in the list above and existing worlds
--     would keep floating crowns of exactly that content. Nothing can be
--     repaired here — the LBM is already registered and core.registered_lbms is
--     frozen on the first server step — so this says so out loud.
--  2. CONTENT THE DERIVATION CANNOT SEE. Every registered decoration is walked
--     again and its placeable node names are collected INDEPENDENTLY of how the
--     list above was built: replacement targets from the replacement table
--     itself (this is where the silverwood tree/leaves went missing), and the
--     name of every schematic decoration whose voxels are opaque to Lua. Any
--     such name that is neither covered nor deliberately excluded (air, liquid,
--     terrain material, unregistered) is reported.
--  3. DECO_MARGIN (the re-review's Low 2). See deco_reach above: the carve
--     ceiling and the sunlight stamp both rest on "no decoration reaches more
--     than DECO_MARGIN above the heightmap", the current margin is met exactly,
--     and nothing else would notice a taller schematic.
core.register_on_mods_loaded(function()
	local covered = {}
	for i = 1, #healable do
		covered[healable[i]] = true
	end
	local now, _, blind, terrain = healable_nodes()
	local missing, seen = {}, {}
	for i = 1, #now do
		if not covered[now[i]] and not seen[now[i]] then
			seen[now[i]] = true
			missing[#missing + 1] = now[i]
		end
	end
	-- Independent second opinion on the replacement class: a target that the
	-- derivation dropped shows up here even if the derivation itself changes.
	for _, def in pairs(core.registered_decorations) do
		if type(def.replacements) == "table" then
			for _, target in pairs(def.replacements) do
				if type(target) == "string" and not covered[target]
						and not seen[target] and not terrain[target] then
					local ndef = core.registered_nodes[target]
					if ndef and target ~= "air" and
							(not ndef.liquidtype or
								ndef.liquidtype == "none") then
						seen[target] = true
						missing[#missing + 1] = target ..
							" (replacement target)"
					end
				end
			end
		end
	end
	if #missing > 0 then
		core.log("warning", "[grug_mapgen] the ocean mask healing LBM does " ..
			"not cover " .. table.concat(missing, ", ") .. " — register " ..
			"those decorations in grug_mapgen, or load that mod earlier")
	end
	if #blind > #healable_blind then
		core.log("warning", "[grug_mapgen] decorations with an opaque " ..
			"schematic registered after grug_mapgen: " ..
			table.concat(blind, ", "))
	end
	local reach, who = deco_reach()
	if reach > geom.DECO_MARGIN then
		core.log("warning", ("[grug_mapgen] %s reaches %d nodes above the " ..
			"mapgen heightmap, more than DECO_MARGIN = %d — the ocean mask " ..
			"stops carving below its crown, so it will leave floating " ..
			"foliage over the coast AND stamp daylight under it. Raise " ..
			"DECO_MARGIN in geometry.lua to at least %d.")
			:format(who, reach, geom.DECO_MARGIN, reach))
	end
end)
