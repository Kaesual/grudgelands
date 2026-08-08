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

-- Climate BLEND noise (decided 2026-08-08, D3). The engine adds these two
-- fields on top of the heat/humidity fields above (mg_biome.cpp:163-173 and
-- :180-196) and their only job is to fray the voronoi borders between biome
-- climate points. We never set them, so they ran at the engine defaults
-- (scale 1.5, spread 8, mg_biome.h:153-154) — a per-node dither with a
-- fringe of ~19 nodes, invisible next to a 3000-node continent.
--
-- offset 0 / scale 4 / spread 32 / octaves 2 / persist 1.0 gives ~45 nodes of
-- fingering in ~32-node lobes: coherent fingers instead of dither, ~7.5 % of
-- the land reassigned near a border. Seeds stay at the engine's 13 / 90003 —
-- they are only "which noise", not a tuning knob.
--
-- HARD CEILING: scale 6. The blend displaces the sampled climate by up to
-- +-2 * scale in each axis, and the tightest same-continent point pair
-- (elf forest 70/60 <-> deep forest 60/75) is 18.0 units apart; above ~6 the
-- displacement exceeds half that and the border salt-and-peppers instead of
-- fingering. Every new climate point must keep that 18.0 floor.
--
-- COSTS NOTHING: all four climate noises are computed for every mapchunk
-- regardless (mg_biome.cpp:181-194), so scale/spread change no work at all.
-- Needs a FRESH WORLD like every override_meta setting above.
--
-- `flags = "eased"` for the same reason as the two noises above: it is
-- spelled out for readability and changes nothing, because a Lua
-- noiseparams table without `flags` gets NOISE_FLAG_DEFAULTS
-- (c_content.cpp:2070-2073) and 2D noise treats DEFAULTS as eased
-- (noise.cpp:325-326). Only 3D noise needs it spelled out to be eased.
core.set_mapgen_setting_noiseparams("mg_biome_np_heat_blend", {
	offset = 0, scale = 4, spread = {x = 32, y = 32, z = 32},
	seed = 13, octaves = 2, persist = 1.0, lacunarity = 2.0,
	flags = "eased",
}, true)
core.set_mapgen_setting_noiseparams("mg_biome_np_humidity_blend", {
	offset = 0, scale = 4, spread = {x = 32, y = 32, z = 32},
	seed = 90003, octaves = 2, persist = 1.0, lacunarity = 2.0,
	flags = "eased",
}, true)

local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/biomes.lua")
dofile(path .. "/ores.lua")
dofile(path .. "/decorations.lua")
-- Before structures.lua: it publishes grug_mapgen.geometry (the coast profile),
-- which structures.lua reads to clamp outpost/bandit-camp heights. geometry.lua
-- itself is dofile'd from here AND from the mapgen environment — see the file
-- headers of ocean_mask.lua and ocean_mask_mapgen.lua.
dofile(path .. "/ocean_mask.lua")
dofile(path .. "/structures.lua")
