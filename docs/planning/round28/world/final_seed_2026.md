# Spawn levels across the mainland: seed 2026, final recipes (border rule applied)

Built with `tools/r28_world/run.sh` from the recipes of the tree it ran in (final recipes (border rule applied)) (one world build, every mainland zone's region map through the game's `spawn_regions_core.lua`). The two dragon islands are left out (one belt, L60, no land border). Border edges are sides shared by land cells (32 nodes each) of two zones; the gap is the distance between the two regions' level ranges.

## Border length per class

| class | meaning | nodes | share |
|---|---|---:|---:|
| fit | fit: gap <= 1 (ranges overlap or touch) | 50784 | 83.1 % |
| step | step: gap 2-5 | 3936 | 6.4 % |
| jump | jump: gap > 5 | 704 | 1.2 % |
| forced | forced: the zones' bands lie > 5 apart | 5664 | 9.3 % |
| none | a side without recipe | 0 | 0.0 % |
| total | | 61088 | |

## Red borders (gap > 5)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 96 | The Broken Causeway | L41-43 | Gravesalt Escarpment | L51-53 | 8 |
| 64 | Frostbarrow Shelf | L21-23 | Stormvault Heights | L31-33 | 8 |
| 64 | Glassroot Wilds | L31-33 | Lorindor | L21-23 | 8 |
| 64 | Glassroot Wilds | L31-33 | Moonfall Wood | L21-23 | 8 |
| 64 | The Shattered Line | L41-43 | The Skyglass Canopy | L51-53 | 8 |
| 64 | Blackwind Rise | L31-33 | Speargrass Reach | L21-23 | 8 |
| 64 | Raincall Basin | L11-13 | Totemwater Reach | L21-23 | 8 |
| 32 | Ashenward March | L31-33 | Whitebridge Shire | L21-23 | 8 |
| 32 | Copperfell Foothills | L11-13 | Frostbarrow Shelf | L21-23 | 8 |
| 32 | Stormvault Heights | L31-33 | Whitebridge Shire | L21-23 | 8 |
| 32 | Bannerbreak Mesa | L31-33 | Whispering Reedlands | L21-23 | 8 |
| 32 | Blackwind Rise | L31-33 | Ossuary Reach | L21-23 | 8 |
| 32 | Thunderroot Wilds | L31-33 | Totemwater Reach | L21-23 | 8 |
| 32 | Thunderroot Wilds | L31-33 | Whispering Reedlands | L21-23 | 8 |

## Yellow borders (gap 2-5)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 416 | Nhal Veyr | L28-30 | Speargrass Reach | L21-23 | 5 |
| 384 | Kezamba | L28-30 | Totemwater Reach | L21-23 | 5 |
| 352 | Nhal Veyr | L28-30 | Ossuary Reach | L21-23 | 5 |
| 320 | Lethariel | L28-30 | Moonfall Wood | L21-23 | 5 |
| 288 | Gor Drazhak | L28-30 | Whispering Reedlands | L21-23 | 5 |
| 256 | Dur Brannoc | L28-30 | Frostbarrow Shelf | L21-23 | 5 |
| 224 | Kezamba | L28-30 | Whispering Reedlands | L21-23 | 5 |
| 192 | Highcourt | L28-30 | Whitebridge Shire | L21-23 | 5 |
| 192 | Lethariel | L28-30 | Lorindor | L21-23 | 5 |
| 160 | Dur Brannoc | L28-30 | Whitebridge Shire | L21-23 | 5 |
| 160 | Highcourt | L28-30 | Lorindor | L21-23 | 5 |
| 128 | Gor Drazhak | L28-30 | Speargrass Reach | L21-23 | 5 |
| 96 | The Broken Causeway | L44-47 | Gravesalt Escarpment | L51-53 | 4 |
| 96 | Raincall Basin | L14-17 | Totemwater Reach | L21-23 | 4 |
| 64 | Ashenward March | L31-33 | Lorindor | L24-27 | 4 |
| 64 | Copperfell Foothills | L14-17 | Frostbarrow Shelf | L21-23 | 4 |
| 64 | Glassroot Wilds | L31-33 | Moonfall Wood | L24-27 | 4 |
| 64 | The Shattered Line | L44-47 | The Skyglass Canopy | L51-53 | 4 |
| 64 | Bannerbreak Mesa | L31-33 | Whispering Reedlands | L24-27 | 4 |
| 64 | Blackwind Rise | L31-33 | Speargrass Reach | L24-27 | 4 |
| 64 | Thunderroot Wilds | L31-33 | Whispering Reedlands | L24-27 | 4 |
| 32 | Ashenward March | L31-33 | Whitebridge Shire | L24-27 | 4 |
| 32 | Frostbarrow Shelf | L24-27 | Stormvault Heights | L31-33 | 4 |
| 32 | Glassroot Wilds | L31-33 | Lorindor | L24-27 | 4 |
| 32 | Stormvault Heights | L31-33 | Whitebridge Shire | L24-27 | 4 |
| 32 | Bannerbreak Mesa | L31-33 | Speargrass Reach | L24-27 | 4 |
| 32 | Blackwind Rise | L31-33 | Ossuary Reach | L24-27 | 4 |
| 32 | Thunderroot Wilds | L31-33 | Totemwater Reach | L24-27 | 4 |

## Forced gaps (the bands lie more than 5 apart)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 1408 | Stormvault Heights | L38-40 | Gravesalt Escarpment | L51-53 | 11 |
| 1376 | Gravesalt Escarpment | L51-53 | Blackwind Rise | L38-40 | 11 |
| 1152 | Glassroot Wilds | L38-40 | The Skyglass Canopy | L51-53 | 11 |
| 1120 | The Skyglass Canopy | L51-53 | Thunderroot Wilds | L38-40 | 11 |
| 384 | Kapok Cradle | L8-10 | Totemwater Reach | L21-23 | 11 |
| 128 | Sunscar Flats | L8-10 | Whispering Reedlands | L21-23 | 11 |
| 64 | Frostbarrow Shelf | L21-23 | Hearthpine Vale | L8-10 | 11 |
| 32 | The Skyglass Canopy | L54-57 | Thunderroot Wilds | L38-40 | 14 |

## Per zone pair

| zone | zone | fit | step | jump | forced | none | atlas neighbours |
|---|---|---:|---:|---:|---:|---:|---|
| Ashenward March | Glassroot Wilds | 768 |  |  |  |  | yes |
| Ashenward March | Highcourt | 1248 |  |  |  |  | yes |
| Ashenward March | Lorindor | 576 | 64 |  |  |  | yes |
| Ashenward March | Stormvault Heights | 736 |  |  |  |  | yes |
| Ashenward March | Whitebridge Shire | 512 | 32 | 32 |  |  | yes |
| Ashenward March | The Broken Causeway | 1696 |  |  |  |  | yes |
| Ashenward March | The Shattered Line | 928 |  |  |  |  | yes |
| Copperfell Foothills | Dur Brannoc | 1056 |  |  |  |  | yes |
| Copperfell Foothills | Frostbarrow Shelf | 384 | 64 | 32 |  |  | yes |
| Copperfell Foothills | Hearthpine Vale | 1408 |  |  |  |  | yes |
| Copperfell Foothills | Whitebridge Shire | 608 |  |  |  |  | yes |
| Dawnmere Fields | Goldmead Vale | 992 |  |  |  |  | yes |
| Dur Brannoc | Frostbarrow Shelf | 608 | 256 |  |  |  | yes |
| Dur Brannoc | Stormvault Heights | 1216 |  |  |  |  | yes |
| Dur Brannoc | Whitebridge Shire | 288 | 160 |  |  |  | yes |
| Frostbarrow Shelf | Hearthpine Vale |  |  |  | 64 |  | **no** |
| Frostbarrow Shelf | Stormvault Heights | 640 | 32 | 64 |  |  | yes |
| Glassroot Wilds | Lethariel | 1152 |  |  |  |  | yes |
| Glassroot Wilds | Lorindor | 544 | 32 | 64 |  |  | yes |
| Glassroot Wilds | Moonfall Wood | 512 | 64 | 64 |  |  | yes |
| Glassroot Wilds | The Shattered Line | 512 |  |  |  |  | yes |
| Glassroot Wilds | The Skyglass Canopy |  |  |  | 1152 |  | yes |
| Goldmead Vale | Highcourt | 864 |  |  |  |  | yes |
| Goldmead Vale | Lorindor | 576 |  |  |  |  | yes |
| Goldmead Vale | Whitebridge Shire | 544 |  |  |  |  | yes |
| Highcourt | Lorindor | 320 | 160 |  |  |  | yes |
| Highcourt | Whitebridge Shire | 544 | 192 |  |  |  | yes |
| Lethariel | Lorindor | 224 | 192 |  |  |  | yes |
| Lethariel | Moonfall Wood | 544 | 320 |  |  |  | yes |
| Lethariel | Starbough Vale | 1216 |  |  |  |  | yes |
| Lorindor | Starbough Vale | 512 |  |  |  |  | yes |
| Moonfall Wood | Starbough Vale | 800 |  |  |  |  | yes |
| Silverleaf Glades | Starbough Vale | 1632 |  |  |  |  | yes |
| Stormvault Heights | Whitebridge Shire | 768 | 32 | 32 |  |  | yes |
| Stormvault Heights | The Broken Causeway | 480 |  |  |  |  | yes |
| Stormvault Heights | Gravesalt Escarpment |  |  |  | 1408 |  | yes |
| The Broken Causeway | Gravesalt Escarpment | 448 | 96 | 96 |  |  | yes |
| The Broken Causeway | The Shattered Line | 704 |  |  |  |  | yes |
| The Broken Causeway | Bannerbreak Mesa | 832 |  |  |  |  | yes |
| The Broken Causeway | Blackwind Rise | 896 |  |  |  |  | yes |
| Gravesalt Escarpment | Blackwind Rise |  |  |  | 1376 |  | yes |
| The Shattered Line | The Skyglass Canopy | 192 | 64 | 64 |  |  | yes |
| The Shattered Line | Bannerbreak Mesa | 1024 |  |  |  |  | yes |
| The Shattered Line | Thunderroot Wilds | 800 |  |  |  |  | yes |
| The Skyglass Canopy | Thunderroot Wilds |  |  |  | 1152 |  | yes |
| Bannerbreak Mesa | Blackwind Rise | 736 |  |  |  |  | yes |
| Bannerbreak Mesa | Gor Drazhak | 1184 |  |  |  |  | yes |
| Bannerbreak Mesa | Speargrass Reach | 640 | 32 |  |  |  | yes |
| Bannerbreak Mesa | Thunderroot Wilds | 928 |  |  |  |  | yes |
| Bannerbreak Mesa | Whispering Reedlands | 672 | 64 | 32 |  |  | yes |
| Blackwind Rise | Nhal Veyr | 768 |  |  |  |  | yes |
| Blackwind Rise | Ossuary Reach | 384 | 32 | 32 |  |  | yes |
| Blackwind Rise | Speargrass Reach | 704 | 64 | 64 |  |  | yes |
| Gor Drazhak | Redtusk Savanna | 1344 |  |  |  |  | yes |
| Gor Drazhak | Speargrass Reach | 288 | 128 |  |  |  | yes |
| Gor Drazhak | Whispering Reedlands | 512 | 288 |  |  |  | yes |
| Kapok Cradle | Raincall Basin | 1152 |  |  |  |  | yes |
| Kapok Cradle | Totemwater Reach |  |  |  | 384 |  | yes |
| Kezamba | Raincall Basin | 1056 |  |  |  |  | yes |
| Kezamba | Thunderroot Wilds | 960 |  |  |  |  | yes |
| Kezamba | Totemwater Reach | 640 | 384 |  |  |  | yes |
| Kezamba | Whispering Reedlands | 256 | 224 |  |  |  | yes |
| Mournfen | Nhal Veyr | 928 |  |  |  |  | yes |
| Mournfen | Ossuary Reach | 736 |  |  |  |  | yes |
| Mournfen | Speargrass Reach | 320 |  |  |  |  | yes |
| Mournfen | Stillgrave Hollow | 1728 |  |  |  |  | yes |
| Nhal Veyr | Ossuary Reach | 544 | 352 |  |  |  | yes |
| Nhal Veyr | Speargrass Reach | 416 | 416 |  |  |  | yes |
| Raincall Basin | Totemwater Reach | 448 | 96 | 64 |  |  | yes |
| Raincall Basin | Whispering Reedlands | 288 |  |  |  |  | yes |
| Redtusk Savanna | Speargrass Reach | 576 |  |  |  |  | yes |
| Redtusk Savanna | Sunscar Flats | 1152 |  |  |  |  | yes |
| Redtusk Savanna | Whispering Reedlands | 544 |  |  |  |  | yes |
| Sunscar Flats | Whispering Reedlands |  |  |  | 128 |  | **no** |
| Thunderroot Wilds | Totemwater Reach | 256 | 32 | 32 |  |  | yes |
| Thunderroot Wilds | Whispering Reedlands | 320 | 64 | 32 |  |  | yes |

## Zone pairs that touch on this seed but are not neighbours in the atlas

The atlas lists seed 42's neighbours, and the border rule names only those; a border below is neither entry nor exit in any recipe.

- Frostbarrow Shelf | Hearthpine Vale: 64 nodes (forced 64)
- Sunscar Flats | Whispering Reedlands: 128 nodes (forced 128)

## Zones

| zone | band | from | to | recipe file | notes |
|---|---|---|---|---|---|
| Hearthpine Vale | 1-10 | anchor start | border elandor_copperfell_foothills | `mods/ENTITIES/grug_mobs/data/zones/elandor_hearthpine_vale.spawns.json` |  |
| Copperfell Foothills | 11-20 | border elandor_hearthpine_vale | border elandor_dur_brannoc, elandor_frostbarrow_shelf, elandor_whitebridge_shire | `mods/ENTITIES/grug_mobs/data/zones/elandor_copperfell_foothills.spawns.json` |  |
| Dur Brannoc | 20-30 | anchor capital + border elandor_copperfell_foothills | border elandor_stormvault_heights | `mods/ENTITIES/grug_mobs/data/zones/elandor_dur_brannoc.spawns.json` |  |
| Frostbarrow Shelf | 21-30 | border elandor_dur_brannoc, elandor_copperfell_foothills | border elandor_stormvault_heights | `mods/ENTITIES/grug_mobs/data/zones/elandor_frostbarrow_shelf.spawns.json` |  |
| Stormvault Heights | 31-40 | border elandor_dur_brannoc, elandor_frostbarrow_shelf, elandor_whitebridge_shire | border front_broken_causeway, front_gravesalt_escarpment | `mods/ENTITIES/grug_mobs/data/zones/elandor_stormvault_heights.spawns.json` |  |
| Dawnmere Fields | 1-10 | anchor start | border elandor_goldmead_vale | `mods/ENTITIES/grug_mobs/data/zones/elandor_dawnmere_fields.spawns.json` |  |
| Goldmead Vale | 11-20 | border elandor_dawnmere_fields | border elandor_highcourt, elandor_lorindor, elandor_whitebridge_shire | `mods/ENTITIES/grug_mobs/data/zones/elandor_goldmead_vale.spawns.json` |  |
| Highcourt | 20-30 | anchor capital + border elandor_goldmead_vale | border elandor_ashenward_march | `mods/ENTITIES/grug_mobs/data/zones/elandor_highcourt.spawns.json` |  |
| Whitebridge Shire | 21-30 | border elandor_copperfell_foothills, elandor_dur_brannoc, elandor_goldmead_vale, elandor_highcourt | border elandor_ashenward_march, elandor_stormvault_heights | `mods/ENTITIES/grug_mobs/data/zones/elandor_whitebridge_shire.spawns.json` |  |
| Ashenward March | 31-40 | border elandor_highcourt, elandor_lorindor, elandor_whitebridge_shire | border front_broken_causeway, front_shattered_line | `mods/ENTITIES/grug_mobs/data/zones/elandor_ashenward_march.spawns.json` |  |
| Silverleaf Glades | 1-10 | anchor start | border elandor_starbough_vale | `mods/ENTITIES/grug_mobs/data/zones/elandor_silverleaf_glades.spawns.json` |  |
| Starbough Vale | 11-20 | border elandor_silverleaf_glades | border elandor_lethariel, elandor_lorindor, elandor_moonfall_wood | `mods/ENTITIES/grug_mobs/data/zones/elandor_starbough_vale.spawns.json` |  |
| Lethariel | 20-30 | anchor capital + border elandor_starbough_vale | border elandor_glassroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/elandor_lethariel.spawns.json` |  |
| Lorindor | 21-30 | border elandor_goldmead_vale, elandor_highcourt, elandor_lethariel, elandor_starbough_vale | border elandor_ashenward_march, elandor_glassroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/elandor_lorindor.spawns.json` |  |
| Moonfall Wood | 21-30 | border elandor_lethariel, elandor_silverleaf_glades, elandor_starbough_vale | border elandor_glassroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/elandor_moonfall_wood.spawns.json` |  |
| Glassroot Wilds | 31-40 | border elandor_lethariel, elandor_lorindor, elandor_moonfall_wood | border front_shattered_line, front_skyglass_canopy | `mods/ENTITIES/grug_mobs/data/zones/elandor_glassroot_wilds.spawns.json` |  |
| Stillgrave Hollow | 1-10 | anchor start | border kragmar_mournfen | `mods/ENTITIES/grug_mobs/data/zones/kragmar_stillgrave_hollow.spawns.json` |  |
| Mournfen | 11-20 | border kragmar_stillgrave_hollow | border kragmar_nhal_veyr, kragmar_ossuary_reach, kragmar_speargrass_reach | `mods/ENTITIES/grug_mobs/data/zones/kragmar_mournfen.spawns.json` |  |
| Nhal Veyr | 20-30 | anchor capital + border kragmar_mournfen | border kragmar_blackwind_rise | `mods/ENTITIES/grug_mobs/data/zones/kragmar_nhal_veyr.spawns.json` |  |
| Ossuary Reach | 21-30 | border kragmar_mournfen, kragmar_nhal_veyr, kragmar_stillgrave_hollow | border kragmar_blackwind_rise | `mods/ENTITIES/grug_mobs/data/zones/kragmar_ossuary_reach.spawns.json` |  |
| Blackwind Rise | 31-40 | border kragmar_nhal_veyr, kragmar_ossuary_reach, kragmar_speargrass_reach | border front_broken_causeway, front_gravesalt_escarpment | `mods/ENTITIES/grug_mobs/data/zones/kragmar_blackwind_rise.spawns.json` |  |
| Sunscar Flats | 1-10 | anchor start | border kragmar_redtusk_savanna | `mods/ENTITIES/grug_mobs/data/zones/kragmar_sunscar_flats.spawns.json` |  |
| Redtusk Savanna | 11-20 | border kragmar_sunscar_flats | border kragmar_gor_drazhak, kragmar_speargrass_reach, kragmar_whispering_reedlands | `mods/ENTITIES/grug_mobs/data/zones/kragmar_redtusk_savanna.spawns.json` |  |
| Gor Drazhak | 20-30 | anchor capital + border kragmar_redtusk_savanna | border kragmar_bannerbreak_mesa | `mods/ENTITIES/grug_mobs/data/zones/kragmar_gor_drazhak.spawns.json` |  |
| Speargrass Reach | 21-30 | border kragmar_gor_drazhak, kragmar_mournfen, kragmar_nhal_veyr, kragmar_redtusk_savanna, kragmar_sunscar_flats | border kragmar_bannerbreak_mesa, kragmar_blackwind_rise | `mods/ENTITIES/grug_mobs/data/zones/kragmar_speargrass_reach.spawns.json` |  |
| Bannerbreak Mesa | 31-40 | border kragmar_gor_drazhak, kragmar_speargrass_reach, kragmar_whispering_reedlands | border front_broken_causeway, front_shattered_line | `mods/ENTITIES/grug_mobs/data/zones/kragmar_bannerbreak_mesa.spawns.json` |  |
| Kapok Cradle | 1-10 | anchor start | border kragmar_raincall_basin | `mods/ENTITIES/grug_mobs/data/zones/kragmar_kapok_cradle.spawns.json` |  |
| Raincall Basin | 11-20 | border kragmar_kapok_cradle | border kragmar_kezamba, kragmar_totemwater_reach, kragmar_whispering_reedlands | `mods/ENTITIES/grug_mobs/data/zones/kragmar_raincall_basin.spawns.json` |  |
| Kezamba | 20-30 | anchor capital + border kragmar_raincall_basin | border kragmar_thunderroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/kragmar_kezamba.spawns.json` |  |
| Whispering Reedlands | 21-30 | border kragmar_gor_drazhak, kragmar_kezamba, kragmar_raincall_basin, kragmar_redtusk_savanna | border kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/kragmar_whispering_reedlands.spawns.json` |  |
| Totemwater Reach | 21-30 | border kragmar_kapok_cradle, kragmar_kezamba, kragmar_raincall_basin | border kragmar_thunderroot_wilds | `mods/ENTITIES/grug_mobs/data/zones/kragmar_totemwater_reach.spawns.json` |  |
| Thunderroot Wilds | 31-40 | border kragmar_kezamba, kragmar_totemwater_reach, kragmar_whispering_reedlands | border front_shattered_line, front_skyglass_canopy | `mods/ENTITIES/grug_mobs/data/zones/kragmar_thunderroot_wilds.spawns.json` |  |
| Gravesalt Escarpment | 51-60 | border elandor_stormvault_heights, front_broken_causeway, kragmar_blackwind_rise | core | `mods/ENTITIES/grug_mobs/data/zones/front_gravesalt_escarpment.spawns.json` |  |
| The Broken Causeway | 41-50 | border elandor_ashenward_march, elandor_stormvault_heights, kragmar_bannerbreak_mesa, kragmar_blackwind_rise | border front_gravesalt_escarpment | `mods/ENTITIES/grug_mobs/data/zones/front_broken_causeway.spawns.json` |  |
| The Shattered Line | 41-50 | border elandor_ashenward_march, elandor_glassroot_wilds, kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds | border front_skyglass_canopy | `mods/ENTITIES/grug_mobs/data/zones/front_shattered_line.spawns.json` |  |
| The Skyglass Canopy | 51-60 | border elandor_glassroot_wilds, front_shattered_line, kragmar_thunderroot_wilds | core | `mods/ENTITIES/grug_mobs/data/zones/front_skyglass_canopy.spawns.json` |  |

Cells two zones both claim (kept by the first): 137. Seconds: world 17.7, raster 3.1, regions 10.8.
