# Spawn levels across the mainland: seed 42, current recipes

Built with `tools/r28_world/run.sh` from the shipped recipes (one world build, every mainland zone's region map through the game's `spawn_regions_core.lua`). The two dragon islands are left out (one belt, L60, no land border). Border edges are sides shared by land cells (32 nodes each) of two zones; the gap is the distance between the two regions' level ranges.

## Border length per class

| class | meaning | nodes | share |
|---|---|---:|---:|
| fit | fit: gap <= 1 (ranges overlap or touch) | 38496 | 61.8 % |
| step | step: gap 2-5 | 16096 | 25.8 % |
| jump | jump: gap > 5 | 1984 | 3.2 % |
| forced | forced: the zones' bands lie > 5 apart | 5696 | 9.1 % |
| none | a side without recipe | 0 | 0.0 % |
| total | | 62272 | |

## Red borders (gap > 5)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 224 | Moonfall Wood | L21-23 | Starbough Vale | L11-13 | 8 |
| 224 | Raincall Basin | L11-13 | Totemwater Reach | L21-23 | 8 |
| 192 | Goldmead Vale | L14-17 | Lorindor | L24-27 | 7 |
| 160 | Goldmead Vale | L11-13 | Whitebridge Shire | L21-23 | 8 |
| 160 | The Broken Causeway | L31-33 | The Shattered Line | L41-43 | 8 |
| 160 | Mournfen | L11-13 | Ossuary Reach | L21-23 | 8 |
| 160 | Redtusk Savanna | L11-13 | Speargrass Reach | L21-23 | 8 |
| 160 | Redtusk Savanna | L14-17 | Whispering Reedlands | L24-27 | 7 |
| 96 | The Shattered Line | L41-43 | The Skyglass Canopy | L51-53 | 8 |
| 96 | Mournfen | L14-17 | Speargrass Reach | L24-27 | 7 |
| 64 | Frostbarrow Shelf | L21-23 | Stormvault Heights | L31-33 | 8 |
| 64 | Glassroot Wilds | L31-33 | Moonfall Wood | L21-23 | 8 |
| 64 | Blackwind Rise | L31-33 | Ossuary Reach | L21-23 | 8 |
| 32 | Ashenward March | L31-33 | Whitebridge Shire | L21-23 | 8 |
| 32 | Glassroot Wilds | L31-33 | Lorindor | L21-23 | 8 |
| 32 | Bannerbreak Mesa | L31-33 | Speargrass Reach | L21-23 | 8 |
| 32 | Thunderroot Wilds | L31-33 | Totemwater Reach | L21-23 | 8 |
| 32 | Thunderroot Wilds | L31-33 | Whispering Reedlands | L21-23 | 8 |

## Yellow borders (gap 2-5)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 1472 | The Broken Causeway | L31-33 | Bannerbreak Mesa | L38-40 | 5 |
| 1376 | Ashenward March | L38-40 | The Broken Causeway | L31-33 | 5 |
| 928 | Goldmead Vale | L18-20 | Highcourt | L24-27 | 4 |
| 928 | Stormvault Heights | L38-40 | The Broken Causeway | L31-33 | 5 |
| 896 | Lethariel | L24-27 | Starbough Vale | L18-20 | 4 |
| 768 | Copperfell Foothills | L18-20 | Dur Brannoc | L24-27 | 4 |
| 736 | Mournfen | L18-20 | Nhal Veyr | L24-27 | 4 |
| 672 | Gor Drazhak | L24-27 | Redtusk Savanna | L18-20 | 4 |
| 608 | The Broken Causeway | L31-33 | Blackwind Rise | L38-40 | 5 |
| 608 | Kezamba | L24-27 | Raincall Basin | L18-20 | 4 |
| 480 | Lethariel | L28-30 | Moonfall Wood | L21-23 | 5 |
| 448 | Kezamba | L28-30 | Whispering Reedlands | L21-23 | 5 |
| 448 | Redtusk Savanna | L14-17 | Speargrass Reach | L21-23 | 4 |
| 416 | Gor Drazhak | L28-30 | Speargrass Reach | L21-23 | 5 |
| 384 | Lethariel | L28-30 | Lorindor | L21-23 | 5 |
| 352 | Kezamba | L28-30 | Totemwater Reach | L21-23 | 5 |
| 352 | Nhal Veyr | L28-30 | Ossuary Reach | L21-23 | 5 |
| 320 | Dur Brannoc | L28-30 | Frostbarrow Shelf | L21-23 | 5 |
| 320 | Highcourt | L28-30 | Whitebridge Shire | L21-23 | 5 |
| 320 | The Broken Causeway | L34-37 | The Shattered Line | L41-43 | 4 |
| 320 | The Shattered Line | L44-47 | The Skyglass Canopy | L51-53 | 4 |
| 288 | Goldmead Vale | L14-17 | Whitebridge Shire | L21-23 | 4 |
| 288 | Raincall Basin | L14-17 | Whispering Reedlands | L21-23 | 4 |
| 256 | Goldmead Vale | L18-20 | Lorindor | L24-27 | 4 |
| 256 | Raincall Basin | L14-17 | Totemwater Reach | L21-23 | 4 |
| 256 | Redtusk Savanna | L18-20 | Whispering Reedlands | L24-27 | 4 |
| 224 | Copperfell Foothills | L18-20 | Whitebridge Shire | L24-27 | 4 |
| 192 | Copperfell Foothills | L14-17 | Frostbarrow Shelf | L21-23 | 4 |
| 192 | Moonfall Wood | L21-23 | Starbough Vale | L14-17 | 4 |
| 192 | Mournfen | L14-17 | Ossuary Reach | L21-23 | 4 |
| 192 | Mournfen | L18-20 | Speargrass Reach | L24-27 | 4 |
| 160 | Bannerbreak Mesa | L31-33 | Speargrass Reach | L24-27 | 4 |
| 64 | Ashenward March | L31-33 | Whitebridge Shire | L24-27 | 4 |
| 64 | Frostbarrow Shelf | L24-27 | Stormvault Heights | L31-33 | 4 |
| 64 | Glassroot Wilds | L31-33 | Moonfall Wood | L24-27 | 4 |
| 64 | The Shattered Line | L44-47 | Bannerbreak Mesa | L38-40 | 4 |
| 64 | Thunderroot Wilds | L31-33 | Totemwater Reach | L24-27 | 4 |
| 32 | Glassroot Wilds | L31-33 | Lorindor | L24-27 | 4 |
| 32 | Lorindor | L21-23 | Starbough Vale | L14-17 | 4 |
| 32 | Blackwind Rise | L31-33 | Ossuary Reach | L24-27 | 4 |
| 32 | Thunderroot Wilds | L31-33 | Whispering Reedlands | L24-27 | 4 |

## Forced gaps (the bands lie more than 5 apart)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 1536 | Gravesalt Escarpment | L51-53 | Blackwind Rise | L38-40 | 11 |
| 1152 | Glassroot Wilds | L38-40 | The Skyglass Canopy | L51-53 | 11 |
| 1056 | The Skyglass Canopy | L51-53 | Thunderroot Wilds | L38-40 | 11 |
| 544 | Stormvault Heights | L38-40 | Gravesalt Escarpment | L51-53 | 11 |
| 288 | The Broken Causeway | L34-37 | Gravesalt Escarpment | L51-53 | 14 |
| 256 | The Broken Causeway | L38-40 | Gravesalt Escarpment | L51-53 | 11 |
| 256 | Kapok Cradle | L8-10 | Totemwater Reach | L21-23 | 11 |
| 256 | Ossuary Reach | L21-23 | Stillgrave Hollow | L8-10 | 11 |
| 192 | Moonfall Wood | L21-23 | Silverleaf Glades | L8-10 | 11 |
| 160 | The Broken Causeway | L31-33 | Gravesalt Escarpment | L51-53 | 18 |

## Per zone pair

| zone | zone | fit | step | jump | forced | none | atlas neighbours |
|---|---|---:|---:|---:|---:|---:|---|
| Ashenward March | Glassroot Wilds | 832 |  |  |  |  | yes |
| Ashenward March | Highcourt | 1312 |  |  |  |  | yes |
| Ashenward March | Lorindor | 448 |  |  |  |  | yes |
| Ashenward March | Stormvault Heights | 544 |  |  |  |  | yes |
| Ashenward March | Whitebridge Shire | 544 | 64 | 32 |  |  | yes |
| Ashenward March | The Broken Causeway |  | 1376 |  |  |  | yes |
| Ashenward March | The Shattered Line | 1216 |  |  |  |  | yes |
| Copperfell Foothills | Dur Brannoc | 352 | 768 |  |  |  | yes |
| Copperfell Foothills | Frostbarrow Shelf | 320 | 192 |  |  |  | yes |
| Copperfell Foothills | Hearthpine Vale | 1600 |  |  |  |  | yes |
| Copperfell Foothills | Whitebridge Shire |  | 224 |  |  |  | yes |
| Dawnmere Fields | Goldmead Vale | 1504 |  |  |  |  | yes |
| Dur Brannoc | Frostbarrow Shelf | 608 | 320 |  |  |  | yes |
| Dur Brannoc | Stormvault Heights | 832 |  |  |  |  | yes |
| Dur Brannoc | Whitebridge Shire | 896 |  |  |  |  | yes |
| Frostbarrow Shelf | Stormvault Heights | 352 | 64 | 64 |  |  | yes |
| Glassroot Wilds | Lethariel | 800 |  |  |  |  | yes |
| Glassroot Wilds | Lorindor | 608 | 32 | 32 |  |  | yes |
| Glassroot Wilds | Moonfall Wood | 704 | 64 | 64 |  |  | yes |
| Glassroot Wilds | The Shattered Line | 512 |  |  |  |  | yes |
| Glassroot Wilds | The Skyglass Canopy |  |  |  | 1152 |  | yes |
| Goldmead Vale | Highcourt | 448 | 928 |  |  |  | yes |
| Goldmead Vale | Lorindor |  | 256 | 192 |  |  | yes |
| Goldmead Vale | Whitebridge Shire | 192 | 288 | 160 |  |  | yes |
| Highcourt | Lorindor | 448 |  |  |  |  | yes |
| Highcourt | Whitebridge Shire | 384 | 320 |  |  |  | yes |
| Lethariel | Lorindor | 256 | 384 |  |  |  | yes |
| Lethariel | Moonfall Wood | 864 | 480 |  |  |  | yes |
| Lethariel | Starbough Vale | 256 | 896 |  |  |  | yes |
| Lorindor | Starbough Vale | 288 | 32 |  |  |  | yes |
| Moonfall Wood | Silverleaf Glades |  |  |  | 192 |  | yes |
| Moonfall Wood | Starbough Vale | 128 | 192 | 224 |  |  | yes |
| Silverleaf Glades | Starbough Vale | 1344 |  |  |  |  | yes |
| Stormvault Heights | Whitebridge Shire | 736 |  |  |  |  | yes |
| Stormvault Heights | The Broken Causeway |  | 928 |  |  |  | yes |
| Stormvault Heights | Gravesalt Escarpment |  |  |  | 544 |  | yes |
| The Broken Causeway | Gravesalt Escarpment |  |  |  | 704 |  | yes |
| The Broken Causeway | The Shattered Line |  | 320 | 160 |  |  | yes |
| The Broken Causeway | Bannerbreak Mesa |  | 1472 |  |  |  | yes |
| The Broken Causeway | Blackwind Rise |  | 608 |  |  |  | yes |
| Gravesalt Escarpment | Blackwind Rise |  |  |  | 1536 |  | yes |
| The Shattered Line | The Skyglass Canopy | 160 | 320 | 96 |  |  | yes |
| The Shattered Line | Bannerbreak Mesa | 1280 | 64 |  |  |  | yes |
| The Shattered Line | Thunderroot Wilds | 480 |  |  |  |  | yes |
| The Skyglass Canopy | Thunderroot Wilds |  |  |  | 1056 |  | yes |
| Bannerbreak Mesa | Blackwind Rise | 576 |  |  |  |  | yes |
| Bannerbreak Mesa | Gor Drazhak | 1152 |  |  |  |  | yes |
| Bannerbreak Mesa | Speargrass Reach | 448 | 160 | 32 |  |  | yes |
| Bannerbreak Mesa | Thunderroot Wilds | 768 |  |  |  |  | yes |
| Bannerbreak Mesa | Whispering Reedlands | 704 |  |  |  |  | yes |
| Blackwind Rise | Nhal Veyr | 928 |  |  |  |  | yes |
| Blackwind Rise | Ossuary Reach | 352 | 32 | 64 |  |  | yes |
| Blackwind Rise | Speargrass Reach | 416 |  |  |  |  | yes |
| Gor Drazhak | Redtusk Savanna | 512 | 672 |  |  |  | yes |
| Gor Drazhak | Speargrass Reach | 320 | 416 |  |  |  | yes |
| Gor Drazhak | Whispering Reedlands | 768 |  |  |  |  | yes |
| Kapok Cradle | Raincall Basin | 1504 |  |  |  |  | yes |
| Kapok Cradle | Totemwater Reach |  |  |  | 256 |  | yes |
| Kezamba | Raincall Basin | 384 | 608 |  |  |  | yes |
| Kezamba | Thunderroot Wilds | 832 |  |  |  |  | yes |
| Kezamba | Totemwater Reach | 448 | 352 |  |  |  | yes |
| Kezamba | Whispering Reedlands | 544 | 448 |  |  |  | yes |
| Mournfen | Nhal Veyr | 128 | 736 |  |  |  | yes |
| Mournfen | Ossuary Reach | 128 | 192 | 160 |  |  | yes |
| Mournfen | Speargrass Reach |  | 192 | 96 |  |  | yes |
| Mournfen | Stillgrave Hollow | 1440 |  |  |  |  | yes |
| Nhal Veyr | Ossuary Reach | 640 | 352 |  |  |  | yes |
| Nhal Veyr | Speargrass Reach | 800 |  |  |  |  | yes |
| Ossuary Reach | Stillgrave Hollow |  |  |  | 256 |  | yes |
| Raincall Basin | Totemwater Reach | 224 | 256 | 224 |  |  | yes |
| Raincall Basin | Whispering Reedlands | 224 | 288 |  |  |  | yes |
| Redtusk Savanna | Speargrass Reach | 352 | 448 | 160 |  |  | yes |
| Redtusk Savanna | Sunscar Flats | 1632 |  |  |  |  | yes |
| Redtusk Savanna | Whispering Reedlands |  | 256 | 160 |  |  | yes |
| Thunderroot Wilds | Totemwater Reach | 416 | 64 | 32 |  |  | yes |
| Thunderroot Wilds | Whispering Reedlands | 608 | 32 | 32 |  |  | yes |

## Zone pairs that touch on this seed but are not neighbours in the atlas

The atlas lists seed 42's neighbours, and the border rule names only those; a border below is neither entry nor exit in any recipe.

None.

## Zones

| zone | band | from | to | recipe file | notes |
|---|---|---|---|---|---|
| Hearthpine Vale | 1-10 | anchor start | border elandor_copperfell_foothills | `mods/ENTITIES/grug_mobs/data/zones/elandor_hearthpine_vale.spawns.json` |  |
| Copperfell Foothills | 11-20 | border elandor_hearthpine_vale | border elandor_dur_brannoc | `mods/ENTITIES/grug_mobs/data/zones/elandor_copperfell_foothills.spawns.json` |  |
| Dur Brannoc | 20-30 | anchor capital | border elandor_stormvault_heights | `mods/ENTITIES/grug_mobs/data/zones/elandor_dur_brannoc.spawns.json` |  |
| Frostbarrow Shelf | 21-30 | border elandor_dur_brannoc, elandor_copperfell_foothills | border elandor_stormvault_heights | `mods/ENTITIES/grug_mobs/data/zones/elandor_frostbarrow_shelf.spawns.json` |  |
| Stormvault Heights | 31-40 | border elandor_dur_brannoc, elandor_frostbarrow_shelf, elandor_whitebridge_shire | border front_broken_causeway, front_gravesalt_escarpment | `mods/ENTITIES/grug_mobs/data/zones/elandor_stormvault_heights.spawns.json` |  |
| Dawnmere Fields | 1-10 | anchor start | border elandor_goldmead_vale | `mods/ENTITIES/grug_mobs/data/zones/elandor_dawnmere_fields.spawns.json` |  |
| Goldmead Vale | 11-20 | border elandor_dawnmere_fields | border elandor_highcourt | `mods/ENTITIES/grug_mobs/data/zones/elandor_goldmead_vale.spawns.json` |  |
| Highcourt | 20-30 | anchor capital | border elandor_ashenward_march | `mods/ENTITIES/grug_mobs/data/zones/elandor_highcourt.spawns.json` |  |
| Whitebridge Shire | 21-30 | border elandor_highcourt, elandor_goldmead_vale | border elandor_ashenward_march, elandor_stormvault_heights | `mods/ENTITIES/grug_mobs/data/zones/elandor_whitebridge_shire.spawns.json` |  |
| Ashenward March | 31-40 | border elandor_highcourt, elandor_lorindor, elandor_whitebridge_shire | border front_broken_causeway, front_shattered_line | `mods/ENTITIES/grug_mobs/data/zones/elandor_ashenward_march.spawns.json` |  |
| Silverleaf Glades | 1-10 | anchor start | border elandor_starbough_vale | `mods/ENTITIES/grug_mobs/data/zones/elandor_silverleaf_glades.spawns.json` |  |
| Starbough Vale | 11-20 | border elandor_silverleaf_glades | border elandor_lethariel | `mods/ENTITIES/grug_mobs/data/zones/elandor_starbough_vale.spawns.json` |  |
| Lethariel | 20-30 | anchor capital | border elandor_glassroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/elandor_lethariel.spawns.json` |  |
| Lorindor | 21-30 | border elandor_lethariel, elandor_starbough_vale | border elandor_glassroot_wilds, elandor_ashenward_march | `mods/ENTITIES/grug_mobs/data/zones/elandor_lorindor.spawns.json` |  |
| Moonfall Wood | 21-30 | border elandor_lethariel, elandor_starbough_vale | border elandor_glassroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/elandor_moonfall_wood.spawns.json` |  |
| Glassroot Wilds | 31-40 | border elandor_lethariel, elandor_lorindor, elandor_moonfall_wood | border front_shattered_line, front_skyglass_canopy | `mods/ENTITIES/grug_mobs/data/zones/elandor_glassroot_wilds.spawns.json` |  |
| Stillgrave Hollow | 1-10 | anchor start | border kragmar_mournfen | `mods/ENTITIES/grug_mobs/data/zones/kragmar_stillgrave_hollow.spawns.json` |  |
| Mournfen | 11-20 | border kragmar_stillgrave_hollow | border kragmar_nhal_veyr | `mods/ENTITIES/grug_mobs/data/zones/kragmar_mournfen.spawns.json` |  |
| Nhal Veyr | 20-30 | anchor capital | border kragmar_blackwind_rise | `mods/ENTITIES/grug_mobs/data/zones/kragmar_nhal_veyr.spawns.json` |  |
| Ossuary Reach | 21-30 | border kragmar_nhal_veyr, kragmar_mournfen | border kragmar_blackwind_rise | `mods/ENTITIES/grug_mobs/data/zones/kragmar_ossuary_reach.spawns.json` |  |
| Blackwind Rise | 31-40 | border kragmar_nhal_veyr, kragmar_ossuary_reach, kragmar_speargrass_reach | border front_broken_causeway, front_gravesalt_escarpment | `mods/ENTITIES/grug_mobs/data/zones/kragmar_blackwind_rise.spawns.json` |  |
| Sunscar Flats | 1-10 | anchor start | border kragmar_redtusk_savanna | `mods/ENTITIES/grug_mobs/data/zones/kragmar_sunscar_flats.spawns.json` |  |
| Redtusk Savanna | 11-20 | border kragmar_sunscar_flats | border kragmar_gor_drazhak | `mods/ENTITIES/grug_mobs/data/zones/kragmar_redtusk_savanna.spawns.json` |  |
| Gor Drazhak | 20-30 | anchor capital | border kragmar_bannerbreak_mesa | `mods/ENTITIES/grug_mobs/data/zones/kragmar_gor_drazhak.spawns.json` |  |
| Speargrass Reach | 21-30 | border kragmar_gor_drazhak, kragmar_redtusk_savanna | border kragmar_bannerbreak_mesa, kragmar_blackwind_rise | `mods/ENTITIES/grug_mobs/data/zones/kragmar_speargrass_reach.spawns.json` |  |
| Bannerbreak Mesa | 31-40 | border kragmar_gor_drazhak, kragmar_speargrass_reach, kragmar_whispering_reedlands | border front_broken_causeway, front_shattered_line | `mods/ENTITIES/grug_mobs/data/zones/kragmar_bannerbreak_mesa.spawns.json` |  |
| Kapok Cradle | 1-10 | anchor start | border kragmar_raincall_basin | `mods/ENTITIES/grug_mobs/data/zones/kragmar_kapok_cradle.spawns.json` |  |
| Raincall Basin | 11-20 | border kragmar_kapok_cradle | border kragmar_kezamba | `mods/ENTITIES/grug_mobs/data/zones/kragmar_raincall_basin.spawns.json` |  |
| Kezamba | 20-30 | anchor capital | border kragmar_thunderroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/kragmar_kezamba.spawns.json` |  |
| Whispering Reedlands | 21-30 | border kragmar_kezamba, kragmar_raincall_basin | border kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/kragmar_whispering_reedlands.spawns.json` |  |
| Totemwater Reach | 21-30 | border kragmar_kezamba, kragmar_raincall_basin | border kragmar_thunderroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/kragmar_totemwater_reach.spawns.json` |  |
| Thunderroot Wilds | 31-40 | border kragmar_kezamba, kragmar_totemwater_reach, kragmar_whispering_reedlands | border front_shattered_line, front_skyglass_canopy | `mods/ENTITIES/grug_mobs/data/zones/kragmar_thunderroot_wilds.spawns.json` |  |
| Gravesalt Escarpment | 51-60 | border elandor_stormvault_heights, front_broken_causeway, kragmar_blackwind_rise | core | `mods/ENTITIES/grug_mobs/data/zones/front_gravesalt_escarpment.spawns.json` |  |
| The Broken Causeway | 31-40 | border elandor_ashenward_march, elandor_stormvault_heights, kragmar_bannerbreak_mesa, kragmar_blackwind_rise | core | `mods/ENTITIES/grug_mobs/data/zones/front_broken_causeway.spawns.json` |  |
| The Shattered Line | 41-50 | border elandor_ashenward_march, elandor_glassroot_wilds, front_broken_causeway, kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds | core | `mods/ENTITIES/grug_mobs/data/zones/front_shattered_line.spawns.json` |  |
| The Skyglass Canopy | 51-60 | border elandor_glassroot_wilds, front_shattered_line, kragmar_thunderroot_wilds | core | `mods/ENTITIES/grug_mobs/data/zones/front_skyglass_canopy.spawns.json` |  |

Cells two zones both claim (kept by the first): 151. Seconds: world 18.6, raster 2.9, regions 10.4.
