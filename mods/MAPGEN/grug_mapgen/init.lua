-- WP40 R7 production cutover. Legacy biome/ore/decoration/ocean/structure
-- loaders are deliberately absent: r7_loader owns the one reviewed native
-- allowlist, mapgen script, generated callback and VM transaction.

grug_mapgen = {}

local modpath = core.get_modpath(core.get_current_modname())
grug_mapgen.wp40 = dofile(modpath .. "/wp40/r7_loader.lua")(
	core, modpath, grug_materials, grug_gathering, grug_core)
