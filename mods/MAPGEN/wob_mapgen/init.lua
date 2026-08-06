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

local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/biomes.lua")
dofile(path .. "/ores.lua")
dofile(path .. "/decorations.lua")
dofile(path .. "/structures.lua")
