-- Territory mapgen (WP2). Architecture decision: we use the engine's biome
-- system on mapgen v7 and confine each biome to its territory/race region
-- with the biome definition's min_pos/max_pos cuboid limits (C++-side, fast,
-- ores/decorations/dungeons keep working). A small register_on_generated
-- pass adds only what biomes cannot express: the continent ocean mask (soft
-- noisy coastlines, everything outside the two continent rectangles forced
-- to water) and the race capital platforms.
--
-- default's own biomes/ores/decorations are NOT registered (see the tail of
-- mods/BASE/default/mapgen.lua): unresolved biome names in ore/decoration
-- defs would silently make them world-wide, so grug_mapgen registers its own
-- complete, territory-aware set instead.

grug_mapgen = {}

-- Terrain bias: v7's defaults (offset 4 in both terrain noises) produce
-- archipelago-like starter areas with lots of swimming. Raising the offsets
-- lifts the whole terrain baseline ~6–10 nodes above sea level, so the
-- faction territories become large contiguous landmasses; deep noise
-- valleys still dip below water level and keep lakes/inland seas. Scale/
-- spread/seed stay at engine defaults (mapgen_v7.cpp).
-- NB override_meta=true also affects ALREADY CREATED worlds: new chunks
-- use the lifted terrain, so old worlds get seams — use a fresh world.
core.set_mapgen_setting_noiseparams("mgv7_np_terrain_base", {
	offset = 14, scale = 70, spread = {x = 600, y = 600, z = 600},
	seed = 82341, octaves = 5, persist = 0.6, lacunarity = 2.0,
}, true)
core.set_mapgen_setting_noiseparams("mgv7_np_terrain_alt", {
	offset = 10, scale = 25, spread = {x = 600, y = 600, z = 600},
	seed = 5934, octaves = 5, persist = 0.6, lacunarity = 2.0,
}, true)

-- Climate noise. The biome points of docs/design/biomes_mobs.md §1.3 are
-- deliberately extreme (95/15 badlands, 10/30 crags, 90/90 deep jungle):
-- "extreme climate points need the noise to actually reach them". Values
-- are the engine defaults for both noises (spread 1000, octaves 3,
-- persist 0.5, lacunarity 2.0, eased, seeds 5349/842) with the spec's
-- offset 50 / scale 35, which keeps the band centres near 50 while the
-- tails still reach the outliers. `flags = "eased"` is spelled out only for
-- readability — it changes nothing: a noiseparams table without flags gets
-- NOISE_FLAG_DEFAULTS, and 2D noise (heat/humidity are 2D) treats defaults
-- as eased (noise.cpp: `flags & (NOISE_FLAG_DEFAULTS | NOISE_FLAG_EASED)`).
-- Only 3D noise needs the flag spelled out to be eased.
core.set_mapgen_setting_noiseparams("mg_biome_np_heat", {
	offset = 50, scale = 35, spread = {x = 1000, y = 1000, z = 1000},
	seed = 5349, octaves = 3, persist = 0.5, lacunarity = 2.0,
	flags = "eased",
}, true)
core.set_mapgen_setting_noiseparams("mg_biome_np_humidity", {
	offset = 50, scale = 35, spread = {x = 1000, y = 1000, z = 1000},
	seed = 842, octaves = 3, persist = 0.5, lacunarity = 2.0,
	flags = "eased",
}, true)

local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/biomes.lua")
dofile(path .. "/ores.lua")
dofile(path .. "/decorations.lua")
dofile(path .. "/structures.lua")
