-- CONTINENT OCEAN MASK — the mapgen-environment half (docs/design/world.md
-- §1/§2b). Registered with core.register_mapgen_script (see ocean_mask.lua),
-- so this file is loaded ONCE PER MAPGEN THREAD into a Lua state of its own and
-- is never executed in the main environment.
--
-- WHAT IT DOES: the world is two separate continents mirrored at z = 0,
-- everything else is ocean — "the terrain generates, but it MUST be water, no
-- islands". v7 happily grows land outside the continent rectangles, so this
-- pass caps the surface of every column near or outside a rectangle edge and
-- floods what it cut. The shoreline is soft: a 2D noise insets the rectangle by
-- 0..150 nodes, and because the inset is clamped at 0 it only ever moves the
-- coast INWARD — the 200-node strait of §1 (|z| < 100 is water) is guaranteed
-- by construction, never by luck of the noise. The cap rises across a 150-node
-- ramp to ~115 nodes above sea level and is then dropped entirely (columns
-- further inland are never even looked at), so the mask shapes the coast and
-- leaves the hinterland to v7. What it does cut it re-dresses: sand at beach
-- level, otherwise the column's own biome surface, so a shaved coastal hill
-- stays walkable land. The geometry itself lives in geometry.lua — this file
-- owns only the voxel work.
--
-- WHY THE MAPGEN ENV (WP36 item 2). It used to be a core.register_on_generated
-- in the MAIN env. That callback fires from EmergeThread::finishGen (emerge.cpp
-- :619-624) — i.e. AFTER ServerMap::finishBlockMake has already blitted the
-- generated chunk to the map (servermap.cpp:291) — under the environment lock,
-- so every coastal chunk was written to the map twice and the second write
-- happened on the server step. lua_api.md:6585 says so outright ("Consider the
-- Mapgen environment as an alternative"). The mapgen-env callback instead runs
-- at emerge.cpp:745, between Mapgen::makeChunk and finishGen: the chunk is
-- masked BEFORE it ever reaches the map, on the emerge thread, and there is
-- exactly one blit.
--
-- ORDER IS PRESERVED. structures.lua's camp / outpost / bandit passes stay in
-- the main env (they need grug_core, mod storage and the POI registry, none of
-- which exist here — lua_api.md:7686 "Refer to Async environment for the usual
-- disclaimer on what environment isolation entails"), and they still run AFTER
-- the mask, because emerge.cpp:745 (this file) strictly precedes emerge.cpp:619
-- (theirs) for the same chunk. The column rule's "run before the camps" comment
-- is therefore still true, and now true by engine ordering rather than by file
-- order.
--
-- THE VOXELMANIP IS THE ENGINE'S. It is handed to the callback (lua_api.md
-- :7699-7706) and read_from_map/write_to_map are DISALLOWED on it
-- (l_vmanip.cpp:45, :157) — the engine blits it back itself in finishGen.
-- get_data/set_data/update_liquids/calc_lighting all work (calc_lighting is
-- even mapgen-vm-only, l_vmanip.cpp:369). update_liquids feeds the emerge
-- thread's own transforming-liquid queue in this env (l_mapgen.cpp:1983-1988),
-- which finishBlockMake then processes — the main-env pass had to go through
-- the server map's queue instead.

local modpath = core.get_modpath("grug_mapgen")

-- The continent rectangle. This env cannot see grug_core, so the main env
-- publishes grug_core's three numbers under this key before the mapgen threads
-- start (ocean_mask.lua). IPC is one of the few APIs both environments have
-- (lua_api.md:7825-7840); the mapgen threads are initialized after all mods are
-- loaded (lua_api.md:7688-7690, emerge.cpp:643-660), so the value is always
-- there by now.
local rect = core.ipc_get("grug_mapgen:continent")
if not rect then
	core.log("error", "[grug_mapgen] mapgen env: the continent rectangle is " ..
		"missing from IPC — the ocean mask is DISABLED for this session")
	return
end

local geom = dofile(modpath .. "/geometry.lua")(rect)

local column_cap = geom.column_cap
local box_needs_mask = geom.box_needs_mask
local WATER_LEVEL = geom.WATER_LEVEL
local DECO_MARGIN = geom.DECO_MARGIN
local SHELL = geom.SHELL

local BEACH_DEPTH = 3 -- sand layers put on a newly exposed beach top
local FILLER_DEPTH = 2 -- filler layers under a re-dressed biome top
-- Ceiling for the shell clean. Honest bound, not a proof: the fresh overflow it
-- removes sits within DECO_MARGIN of this chunk's own terrain (that is the
-- tighter bound actually used), and coastal canopies live far below this.
-- A tree on a ramp column whose cap is near the maximum W+114 could in
-- principle put leaves up to ~147 — not worth a taller loop over every shell
-- column of every coastal chunk, so it is bounded here on purpose.
local SHELL_MAX_Y = 120

-- Reused across mapchunks: vm:get_data() without a buffer allocates a fresh
-- ~11 MB table for every masked chunk. One per mapgen thread, and a mapgen
-- thread runs one chunk at a time, so this stays a private buffer.
local vm_data = {}

-- Content ids at file scope. This script is loaded when the mapgen thread
-- starts, which is after every mod is registered and after the node definitions
-- are frozen (server.cpp:534-553 vs :1098), so all of these resolve.
local c_air = core.get_content_id("air")
local c_ignore = core.get_content_id("ignore")
local c_sand = core.get_content_id("default:sand")
local c_water = core.get_content_id("default:water_source")

-- Content the mask must not overwrite (it only ever replaces the solid material
-- it just exposed, and it must not turn `ignore` — never-generated volume —
-- into anything).
local not_solid = {
	[c_air] = true,
	[c_ignore] = true,
	[c_water] = true,
	[core.get_content_id("default:water_flowing")] = true,
	[core.get_content_id("default:river_water_source")] = true,
	[core.get_content_id("default:river_water_flowing")] = true,
}

-- Content that counts as "the mask already cut here" when it sits directly
-- above a column's cap: air and every liquid, i.e. not_solid MINUS `ignore`.
-- `ignore` is never-generated volume, which means the NEIGHBOURING chunk has
-- not run its own mask yet — and when it does, it owns that column with its own
-- heightmap. Not answering for it is the correct answer, not a gap.
local clear_above = {}
for c in pairs(not_solid) do
	clear_above[c] = true
end
clear_above[c_ignore] = nil

-- What a CARVED column shows at its cap: exactly what the re-dress below writes
-- there — c_sand at beach level, otherwise the column biome's node_top. So the
-- set is every registered biome's node_top plus c_sand, and deliberately NOT
-- node_filler/node_stone (a cave floor at cap height would read as a re-dress
-- and cost that column its tree) or node_riverbed (a river channel floor would,
-- with its own water above it). Same set and same reasoning as the healing
-- LBM's in ocean_mask.lua; lazily built for the same reason biome_surface is.
local ground_ids
local function is_ground(c)
	if not ground_ids then
		ground_ids = {[c_sand] = true}
		for _, def in pairs(core.registered_biomes) do
			local name = def.node_top
			local ndef = name and core.registered_nodes[name]
			if ndef and (not ndef.liquidtype or ndef.liquidtype == "none") then
				ground_ids[core.get_content_id(name)] = true
			end
		end
	end
	return ground_ids[c] == true
end

-- Surface layers of a biome, by biome id, for re-dressing a cut top above beach
-- level: node_top (depth_top layers) over node_filler (FILLER_DEPTH layers).
-- Without it a shaved coastal hill would end in bare stone — not
-- walkable-looking, no mob spawn surface, no decorations. Resolved lazily and
-- cached: core.registered_biomes and core.get_biome_name exist in this env
-- (lua_api.md:7752-7757, :7742-7744) and are fixed once mapgen runs.
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

-- Column rule (per x/z):
--   cap = column_cap(x, z), nil -> column untouched
--   carve when the mapgen heightmap h exceeds cap: water_source for
--   y <= water level, air above, from cap+1 up to the carve ceiling, then
--   re-dress the exposed top (sand at beach level, else the column's biome
--   surface).
-- h is clamped by the engine when the real surface lies outside the chunk's y
-- range (maxp.y if the ground continues above it, -MAX_MAP_GENERATION_LIMIT if
-- the column holds no walkable node at all), and `h > cap` happens to be the
-- correct decision in every one of those cases: ground above -> carve the whole
-- chunk, nothing walkable -> nothing to carve. h decides only WHETHER a column
-- is cut, never WHERE — the cut height is (x, z)-deterministic, so vertically
-- stacked mapchunks of one column cut at exactly the same y.
--
-- THE CARVE CEILING IS emax.y, NOT maxp.y (WP36 item 2, the floating-tree bug).
-- Decorations are placed by the engine before this callback and a schematic may
-- reach up to the EMERGED area's top edge, not the mapchunk's:
-- DecoSchematic::generate rejects a schematic only when
-- `p.Y + size.Y - 1 > vm->m_area.MaxEdge.Y` (mg_decoration.cpp:424), and
-- m_area.MaxEdge IS emax. With chunksize 5 that is maxp.y + 16, so every tree
-- rooted in the top 16 nodes of a mapchunk used to lose its trunk at maxp.y and
-- leave its crown hanging over the water — 192 crowns in one measured coast
-- band, 116 of 117 cuts at exactly y = 48. Whether the chunk above healed it
-- depended on emerge order, which is why the artefact looked nondeterministic.
-- Carving to emax.y is provably sufficient because the engine cannot place a
-- decoration node above it, and it costs no extra memory: the whole emerged
-- volume is in this VoxelManip already. The ceiling only ever moved UP; y1
-- (= cap + 1) is untouched, so no cut height changed.
--
-- The second bound stays max_h + DECO_MARGIN, and it is now the chunk-wide max
-- height rather than the column's own h. Same reason as clean_shell below,
-- which has always used max_h: a tree rooted on a cliff column 30 nodes higher
-- spills sideways into a low column, so the low column's own h is not a bound
-- for what can float above it. This only ever raises the ceiling, always within
-- the volume the mask owns (everything above cap), and it keeps the "a mapchunk
-- high above the terrain costs nothing" property, because max_h is low exactly
-- when the terrain is low.
--
-- Returns whether any water was placed (the caller then updates liquids), the
-- highest terrain in the chunk (the shell clean bounds itself by it) and
-- whether anything was written at all.
local function build_ocean_mask(data, area, minp, maxp, emax)
	local heightmap = core.get_mapgen_object("heightmap")
	if not heightmap then
		return false, nil, false
	end
	local biomemap = core.get_mapgen_object("biomemap")
	local width = maxp.x - minp.x + 1
	local ystride = area.ystride
	local wrote_water = false
	local dirty = false
	local max_h = -31000
	for i = 1, width * (maxp.z - minp.z + 1) do
		local h = heightmap[i]
		if h and h > max_h then
			max_h = h
		end
	end
	local ceiling = math.min(emax.y, max_h + DECO_MARGIN)
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
				-- Deliberately still maxp.y and not emax.y: a cap inside the
				-- shell above belongs to the chunk above, which owns both the
				-- carve and the re-dress for it.
				if h and h > cap and cap <= maxp.y then
					local y1 = math.max(cap + 1, minp.y)
					local y2 = ceiling
					local wet = math.min(y2, WATER_LEVEL)
					if wet >= y1 then
						local idx = area:index(x, y1, z)
						for _ = y1, wet do
							data[idx] = c_water
							idx = idx + ystride
						end
						wrote_water = true
						dirty = true
					end
					local dry = math.max(y1, WATER_LEVEL + 1)
					if y2 >= dry then
						local idx = area:index(x, dry, z)
						for _ = dry, y2 do
							data[idx] = c_air
							idx = idx + ystride
						end
						dirty = true
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
								dirty = true
							end
							idx = idx - ystride
						end
					end
				end
			end
		end
	end
	return wrote_water, max_h, dirty
end

-- Decoration overflow cleanup on the emerged SHELL.
-- The schematics the engine placed for THIS chunk may have spilled up to SHELL
-- nodes into the neighbouring chunks; those neighbours ran their own mask
-- earlier and cannot remove nodes that appear afterwards, which left floating
-- canopies standing over the water. The overflow is still inside this VM
-- (blitBackAll writes the whole emerged area, servermap.cpp:291), so we clean it
-- here, using the very same column_cap — it depends on (x, z) only, so this
-- chunk cuts the neighbour's column at exactly the height the neighbour used,
-- and the pass is idempotent: a column the neighbour already masked is
-- air/water above the cap and nothing matches.
-- Only solid content is replaced; `ignore` (never-generated volume) and every
-- water variant are left alone, and nothing below the cap is touched, so caves
-- and seabeds survive.
--
-- IT ONLY CLEANS COLUMNS THE MASK ACTUALLY CARVED (WP36 review). A shell column
-- has no heightmap entry — the mapgen heightmap covers minp..maxp only — so
-- this pass never knew whether the neighbour's `h > cap` even held, and cut
-- unconditionally. On an UNCARVED neighbour column (terrain at or below its
-- cap) that shaved a legitimate tree down to a stump, in a 16-node ring around
-- every coastal mapchunk, and it did so since the pass was written. The map
-- answers the question here as well as it does for the healing LBM in
-- ocean_mask.lua, and cheaper: the whole emerged area is already in `data`, so
-- the test is two array reads — biome ground AT the cap (that is the mask's
-- re-dress, which a carved column always has) and air/liquid directly above it.
-- A cap outside this VoxelManip cannot be tested and is left alone; that column
-- belongs to a mapchunk far below anyway, and the healing LBM covers it.
local function clean_shell(data, area, minp, maxp, emin, emax, max_h)
	-- Fresh overflow can only sit near this chunk's own terrain.
	local y_top = math.min(emax.y, SHELL_MAX_Y, max_h + DECO_MARGIN)
	if y_top < emin.y then
		return false, false
	end
	local ystride = area.ystride
	local wrote_water = false
	local dirty = false
	for z = emin.z, emax.z do
		local inner_z = z >= minp.z and z <= maxp.z
		for x = emin.x, emax.x do
			if not (inner_z and x >= minp.x and x <= maxp.x) then
				local cap = column_cap(x, z)
				-- `cap < y_top` also guarantees cap + 1 is inside the VM, so
				-- both probes below are in range.
				if cap and cap >= emin.y and cap < y_top and
						is_ground(data[area:index(x, cap, z)]) and
						clear_above[data[area:index(x, cap + 1, z)]] then
					local idx = area:index(x, cap + 1, z)
					for y = cap + 1, y_top do
						if not not_solid[data[idx]] then
							if y <= WATER_LEVEL then
								data[idx] = c_water
								wrote_water = true
							else
								data[idx] = c_air
							end
							dirty = true
						end
						idx = idx + ystride
					end
				end
			end
		end
	end
	return wrote_water, dirty
end

core.register_on_generated(function(vm, minp, maxp, blockseed)
	if not box_needs_mask(minp, maxp, SHELL) then
		return -- fully inland or fully below the deepest possible cap
	end

	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	-- Reused buffer: a fresh get_data() table is ~11 MB of garbage per chunk.
	local data = vm:get_data(vm_data)

	local wrote_water, max_h, dirty = build_ocean_mask(data, area, minp, maxp, emax)
	if max_h then
		-- After the mapchunk pass: the shell columns belong to already finished
		-- neighbours, only this chunk's decoration overflow is new there.
		local shell_water, shell_dirty =
			clean_shell(data, area, minp, maxp, emin, emax, max_h)
		wrote_water = wrote_water or shell_water
		dirty = dirty or shell_dirty
	end

	if not dirty then
		-- A coastal chunk that turned out to have nothing to cut (open sea
		-- below the shelf cap, air above the ramp). Writing the untouched
		-- buffer back and re-lighting it would be pure cost.
		return
	end

	vm:set_data(data)
	if wrote_water then
		-- Without this the water we placed never starts flowing: coastal caves
		-- and cut-open hollows keep standing water walls.
		vm:update_liquids()
	end
	-- The engine already lit this chunk inside makeChunk (mapgen_v7.cpp:378);
	-- we changed it afterwards, so it has to be redone. NOT write_to_map:
	-- that is disallowed here and unnecessary — finishGen blits.
	--
	-- THE RANGE IS EXPLICIT, and that is WP36's second half of the
	-- floating-tree fix. calc_lighting() without arguments lights
	-- emin.y + 16 .. emax.y - 16, i.e. exactly minp.y..maxp.y in y
	-- (l_vmanip.cpp:219-221 — x/z are NOT trimmed, so the shell clean's columns
	-- are covered by the default, only the height is not). The carve now
	-- reaches up to emax.y, so the top 16 nodes it newly clears would keep the
	-- light values of the leaves they replaced — default:leaves does not
	-- propagate sunlight — and a dark air/water band would sit over every
	-- coastal mapchunk whose neighbour above was generated first. Nothing else
	-- would ever repair it: the chunk above lights from its own minp.y - 1
	-- upward, so it only covers this band if it generates AFTER us.
	--
	-- The upper edge is emax.y - 1, not emax.y, on purpose:
	-- Mapgen::propagateSunlight seeds each column from the node ONE ABOVE the
	-- range it is given (mapgen.cpp:489), so emax.y would index outside the
	-- VoxelManip's own area. This is the same shape the engine uses for itself,
	-- one node of headroom (mapgen_v7.cpp:378 passes node_max + (0,1,0)), just
	-- 15 nodes higher because our writes are.
	vm:calc_lighting({x = emin.x, y = minp.y, z = emin.z},
		{x = emax.x, y = emax.y - 1, z = emax.z})
end)
