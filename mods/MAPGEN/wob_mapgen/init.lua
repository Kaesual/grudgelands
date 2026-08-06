-- Territory mapgen (WP2). Architecture decision: we use the engine's biome
-- system on mapgen v7 and confine each biome to its territory/race region
-- with the biome definition's min_pos/max_pos cuboid limits (C++-side, fast,
-- ores/decorations/dungeons keep working). A small register_on_generated
-- pass adds only what biomes cannot express: the spawn camp platforms and
-- the east-west border mountain wall.
--
-- default's own biomes/ores/decorations are NOT registered (see the tail of
-- mods/BASE/default/mapgen.lua): unresolved biome names in ore/decoration
-- defs would silently make them world-wide, so wob_mapgen registers its own
-- complete, territory-aware set instead.

wob_mapgen = {}

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

local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/biomes.lua")
dofile(path .. "/ores.lua")
dofile(path .. "/decorations.lua")
dofile(path .. "/structures.lua")
