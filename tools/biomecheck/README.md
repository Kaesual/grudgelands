# biomecheck — retired WP36 diagnostic

This directory is historical evidence for the removed Lua-biome and ocean-mask
pipeline. WP40 R7 has zero Lua biome registrations and one authored simple-map
writer, so these scripts do not model production mapgen and must not be used for
R7 acceptance, tuning or runtime diagnosis.

`dump_biomes.lua` now stops with an explicit retirement error instead of
silently producing a plausible but obsolete CSV. The remaining Python and C
files preserve the method behind the WP36 measurements cited in
`docs/design/biomes_mobs.md`; they have no active procedure.

Use the frozen WP40 R7 offline evidence for cutover acceptance. Real-world
visual, engine-runtime and performance checks belong to R8.
