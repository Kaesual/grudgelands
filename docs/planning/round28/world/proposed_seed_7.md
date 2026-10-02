# Spawn levels across the mainland: seed 7, proposed recipes

Built with `tools/r28_world/run.sh` from the border rule's recipe copies (`border_rule.py --out`; a zone without a copy keeps its shipped file) (one world build, every mainland zone's region map through the game's `spawn_regions_core.lua`). The two dragon islands are left out (one belt, L60, no land border). Border edges are sides shared by land cells (32 nodes each) of two zones; the gap is the distance between the two regions' level ranges.

## Border length per class

| class | meaning | nodes | share |
|---|---|---:|---:|
| fit | fit: gap <= 1 (ranges overlap or touch) | 46336 | 75.6 % |
| step | step: gap 2-5 | 9088 | 14.8 % |
| jump | jump: gap > 5 | 928 | 1.5 % |
| forced | forced: the zones' bands lie > 5 apart | 4960 | 8.1 % |
| none | a side without recipe | 0 | 0.0 % |
| total | | 61312 | |

## Red borders (gap > 5)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 128 | Copperfell Foothills | L11-13 | Frostbarrow Shelf | L21-23 | 8 |
| 128 | The Shattered Line | L41-43 | The Skyglass Canopy | L51-53 | 8 |
| 96 | The Broken Causeway | L31-33 | The Shattered Line | L41-43 | 8 |
| 64 | Ashenward March | L31-33 | Whitebridge Shire | L21-23 | 8 |
| 64 | Goldmead Vale | L11-13 | Whitebridge Shire | L21-23 | 8 |
| 64 | Blackwind Rise | L31-33 | Speargrass Reach | L21-23 | 8 |
| 64 | Raincall Basin | L11-13 | Totemwater Reach | L21-23 | 8 |
| 64 | Thunderroot Wilds | L31-33 | Whispering Reedlands | L21-23 | 8 |
| 32 | Frostbarrow Shelf | L21-23 | Stormvault Heights | L31-33 | 8 |
| 32 | Glassroot Wilds | L31-33 | Lorindor | L21-23 | 8 |
| 32 | Glassroot Wilds | L31-33 | Moonfall Wood | L21-23 | 8 |
| 32 | Stormvault Heights | L31-33 | Whitebridge Shire | L21-23 | 8 |
| 32 | Bannerbreak Mesa | L31-33 | Speargrass Reach | L21-23 | 8 |
| 32 | Bannerbreak Mesa | L31-33 | Whispering Reedlands | L21-23 | 8 |
| 32 | Blackwind Rise | L31-33 | Ossuary Reach | L21-23 | 8 |
| 32 | Thunderroot Wilds | L31-33 | Totemwater Reach | L21-23 | 8 |

## Yellow borders (gap 2-5)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 1344 | Ashenward March | L38-40 | The Broken Causeway | L31-33 | 5 |
| 928 | The Broken Causeway | L31-33 | Bannerbreak Mesa | L38-40 | 5 |
| 672 | Stormvault Heights | L38-40 | The Broken Causeway | L31-33 | 5 |
| 672 | The Broken Causeway | L31-33 | Blackwind Rise | L38-40 | 5 |
| 448 | Kezamba | L28-30 | Whispering Reedlands | L21-23 | 5 |
| 416 | Nhal Veyr | L28-30 | Ossuary Reach | L21-23 | 5 |
| 384 | Dur Brannoc | L28-30 | Frostbarrow Shelf | L21-23 | 5 |
| 384 | The Broken Causeway | L34-37 | The Shattered Line | L41-43 | 4 |
| 384 | Nhal Veyr | L28-30 | Speargrass Reach | L21-23 | 5 |
| 352 | Highcourt | L28-30 | Whitebridge Shire | L21-23 | 5 |
| 288 | Lethariel | L28-30 | Moonfall Wood | L21-23 | 5 |
| 288 | Kezamba | L28-30 | Totemwater Reach | L21-23 | 5 |
| 256 | Highcourt | L28-30 | Lorindor | L21-23 | 5 |
| 224 | Gor Drazhak | L28-30 | Whispering Reedlands | L21-23 | 5 |
| 192 | The Shattered Line | L44-47 | The Skyglass Canopy | L51-53 | 4 |
| 192 | Mournfen | L14-17 | Stillgrave Hollow | L8-10 | 4 |
| 160 | Dur Brannoc | L28-30 | Whitebridge Shire | L21-23 | 5 |
| 160 | Lethariel | L28-30 | Lorindor | L21-23 | 5 |
| 160 | Raincall Basin | L14-17 | Totemwater Reach | L21-23 | 4 |
| 128 | Gor Drazhak | L28-30 | Speargrass Reach | L21-23 | 5 |
| 96 | Ashenward March | L31-33 | Lorindor | L24-27 | 4 |
| 96 | Mournfen | L14-17 | Speargrass Reach | L21-23 | 4 |
| 64 | Ashenward March | L31-33 | Whitebridge Shire | L24-27 | 4 |
| 64 | Copperfell Foothills | L14-17 | Whitebridge Shire | L21-23 | 4 |
| 64 | Frostbarrow Shelf | L24-27 | Stormvault Heights | L31-33 | 4 |
| 64 | Glassroot Wilds | L31-33 | Lorindor | L24-27 | 4 |
| 64 | Goldmead Vale | L14-17 | Whitebridge Shire | L21-23 | 4 |
| 64 | Bannerbreak Mesa | L31-33 | Speargrass Reach | L24-27 | 4 |
| 64 | Bannerbreak Mesa | L31-33 | Whispering Reedlands | L24-27 | 4 |
| 64 | Blackwind Rise | L31-33 | Speargrass Reach | L24-27 | 4 |
| 64 | Mournfen | L14-17 | Ossuary Reach | L21-23 | 4 |
| 64 | Thunderroot Wilds | L31-33 | Totemwater Reach | L24-27 | 4 |
| 64 | Thunderroot Wilds | L31-33 | Whispering Reedlands | L24-27 | 4 |
| 32 | Copperfell Foothills | L14-17 | Frostbarrow Shelf | L21-23 | 4 |
| 32 | Glassroot Wilds | L31-33 | Moonfall Wood | L24-27 | 4 |
| 32 | Stormvault Heights | L31-33 | Whitebridge Shire | L24-27 | 4 |
| 32 | Blackwind Rise | L31-33 | Ossuary Reach | L24-27 | 4 |
| 32 | Redtusk Savanna | L14-17 | Speargrass Reach | L21-23 | 4 |

## Forced gaps (the bands lie more than 5 apart)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 960 | Glassroot Wilds | L38-40 | The Skyglass Canopy | L51-53 | 11 |
| 960 | Gravesalt Escarpment | L51-53 | Blackwind Rise | L38-40 | 11 |
| 928 | The Skyglass Canopy | L51-53 | Thunderroot Wilds | L38-40 | 11 |
| 736 | Stormvault Heights | L38-40 | Gravesalt Escarpment | L51-53 | 11 |
| 352 | Ossuary Reach | L21-23 | Stillgrave Hollow | L8-10 | 11 |
| 224 | The Broken Causeway | L34-37 | Gravesalt Escarpment | L51-53 | 14 |
| 192 | Dawnmere Fields | L8-10 | Whitebridge Shire | L21-23 | 11 |
| 160 | The Broken Causeway | L31-33 | Gravesalt Escarpment | L51-53 | 18 |
| 160 | The Broken Causeway | L38-40 | Gravesalt Escarpment | L51-53 | 11 |
| 128 | Frostbarrow Shelf | L21-23 | Hearthpine Vale | L8-10 | 11 |
| 128 | Kapok Cradle | L8-10 | Totemwater Reach | L21-23 | 11 |
| 32 | The Skyglass Canopy | L54-57 | Thunderroot Wilds | L38-40 | 14 |

## Per zone pair

| zone | zone | fit | step | jump | forced | none | atlas neighbours |
|---|---|---:|---:|---:|---:|---:|---|
| Ashenward March | Glassroot Wilds | 608 |  |  |  |  | yes |
| Ashenward March | Highcourt | 1088 |  |  |  |  | yes |
| Ashenward March | Lorindor | 320 | 96 |  |  |  | yes |
| Ashenward March | Stormvault Heights | 800 |  |  |  |  | yes |
| Ashenward March | Whitebridge Shire | 576 | 64 | 64 |  |  | yes |
| Ashenward March | The Broken Causeway |  | 1344 |  |  |  | yes |
| Ashenward March | The Shattered Line | 864 |  |  |  |  | yes |
| Copperfell Foothills | Dur Brannoc | 1472 |  |  |  |  | yes |
| Copperfell Foothills | Frostbarrow Shelf | 608 | 32 | 128 |  |  | yes |
| Copperfell Foothills | Hearthpine Vale | 1568 |  |  |  |  | yes |
| Copperfell Foothills | Whitebridge Shire | 512 | 64 |  |  |  | yes |
| Dawnmere Fields | Goldmead Vale | 1472 |  |  |  |  | yes |
| Dawnmere Fields | Whitebridge Shire |  |  |  | 192 |  | **no** |
| Dur Brannoc | Frostbarrow Shelf | 960 | 384 |  |  |  | yes |
| Dur Brannoc | Stormvault Heights | 1024 |  |  |  |  | yes |
| Dur Brannoc | Whitebridge Shire | 160 | 160 |  |  |  | yes |
| Frostbarrow Shelf | Hearthpine Vale |  |  |  | 128 |  | **no** |
| Frostbarrow Shelf | Stormvault Heights | 448 | 64 | 32 |  |  | yes |
| Glassroot Wilds | Lethariel | 1120 |  |  |  |  | yes |
| Glassroot Wilds | Lorindor | 640 | 64 | 32 |  |  | yes |
| Glassroot Wilds | Moonfall Wood | 352 | 32 | 32 |  |  | yes |
| Glassroot Wilds | The Shattered Line | 352 |  |  |  |  | yes |
| Glassroot Wilds | The Skyglass Canopy |  |  |  | 960 |  | yes |
| Goldmead Vale | Highcourt | 1312 |  |  |  |  | yes |
| Goldmead Vale | Lorindor | 288 |  |  |  |  | yes |
| Goldmead Vale | Whitebridge Shire | 192 | 64 | 64 |  |  | yes |
| Highcourt | Lorindor | 384 | 256 |  |  |  | yes |
| Highcourt | Whitebridge Shire | 640 | 352 |  |  |  | yes |
| Lethariel | Lorindor | 416 | 160 |  |  |  | yes |
| Lethariel | Moonfall Wood | 608 | 288 |  |  |  | yes |
| Lethariel | Starbough Vale | 992 |  |  |  |  | yes |
| Lorindor | Starbough Vale | 480 |  |  |  |  | yes |
| Moonfall Wood | Starbough Vale | 608 |  |  |  |  | yes |
| Silverleaf Glades | Starbough Vale | 1632 |  |  |  |  | yes |
| Stormvault Heights | Whitebridge Shire | 640 | 32 | 32 |  |  | yes |
| Stormvault Heights | The Broken Causeway |  | 672 |  |  |  | yes |
| Stormvault Heights | Gravesalt Escarpment |  |  |  | 736 |  | yes |
| The Broken Causeway | Gravesalt Escarpment |  |  |  | 544 |  | yes |
| The Broken Causeway | The Shattered Line | 288 | 384 | 96 |  |  | yes |
| The Broken Causeway | Bannerbreak Mesa |  | 928 |  |  |  | yes |
| The Broken Causeway | Blackwind Rise |  | 672 |  |  |  | yes |
| Gravesalt Escarpment | Blackwind Rise |  |  |  | 960 |  | yes |
| The Shattered Line | The Skyglass Canopy | 288 | 192 | 128 |  |  | yes |
| The Shattered Line | Bannerbreak Mesa | 1792 |  |  |  |  | yes |
| The Shattered Line | Thunderroot Wilds | 608 |  |  |  |  | yes |
| The Skyglass Canopy | Thunderroot Wilds |  |  |  | 960 |  | yes |
| Bannerbreak Mesa | Blackwind Rise | 576 |  |  |  |  | yes |
| Bannerbreak Mesa | Gor Drazhak | 1504 |  |  |  |  | yes |
| Bannerbreak Mesa | Speargrass Reach | 704 | 64 | 32 |  |  | yes |
| Bannerbreak Mesa | Thunderroot Wilds | 320 |  |  |  |  | yes |
| Bannerbreak Mesa | Whispering Reedlands | 384 | 64 | 32 |  |  | yes |
| Blackwind Rise | Nhal Veyr | 1152 |  |  |  |  | yes |
| Blackwind Rise | Ossuary Reach | 320 | 32 | 32 |  |  | yes |
| Blackwind Rise | Speargrass Reach | 768 | 64 | 64 |  |  | yes |
| Gor Drazhak | Redtusk Savanna | 1120 |  |  |  |  | yes |
| Gor Drazhak | Speargrass Reach | 256 | 128 |  |  |  | yes |
| Gor Drazhak | Whispering Reedlands | 448 | 224 |  |  |  | yes |
| Kapok Cradle | Raincall Basin | 1472 |  |  |  |  | yes |
| Kapok Cradle | Totemwater Reach |  |  |  | 128 |  | yes |
| Kezamba | Raincall Basin | 992 |  |  |  |  | yes |
| Kezamba | Thunderroot Wilds | 800 |  |  |  |  | yes |
| Kezamba | Totemwater Reach | 576 | 288 |  |  |  | yes |
| Kezamba | Whispering Reedlands | 544 | 448 |  |  |  | yes |
| Mournfen | Nhal Veyr | 832 |  |  |  |  | yes |
| Mournfen | Ossuary Reach | 544 | 64 |  |  |  | yes |
| Mournfen | Speargrass Reach | 320 | 96 |  |  |  | yes |
| Mournfen | Stillgrave Hollow | 960 | 192 |  |  |  | yes |
| Nhal Veyr | Ossuary Reach | 672 | 416 |  |  |  | yes |
| Nhal Veyr | Speargrass Reach | 512 | 384 |  |  |  | yes |
| Ossuary Reach | Stillgrave Hollow |  |  |  | 352 |  | yes |
| Raincall Basin | Totemwater Reach | 704 | 160 | 64 |  |  | yes |
| Raincall Basin | Whispering Reedlands | 288 |  |  |  |  | yes |
| Redtusk Savanna | Speargrass Reach | 544 | 32 |  |  |  | yes |
| Redtusk Savanna | Sunscar Flats | 1216 |  |  |  |  | yes |
| Redtusk Savanna | Whispering Reedlands | 448 |  |  |  |  | yes |
| Thunderroot Wilds | Totemwater Reach | 608 | 64 | 32 |  |  | yes |
| Thunderroot Wilds | Whispering Reedlands | 640 | 64 | 64 |  |  | yes |

## Zone pairs that touch on this seed but are not neighbours in the atlas

The atlas lists seed 42's neighbours, and the border rule names only those; a border below is neither entry nor exit in any recipe.

- Dawnmere Fields | Whitebridge Shire: 192 nodes (forced 192)
- Frostbarrow Shelf | Hearthpine Vale: 128 nodes (forced 128)

## Zones

| zone | band | from | to | recipe file | notes |
|---|---|---|---|---|---|
| Hearthpine Vale | 1-10 | anchor start | border elandor_copperfell_foothills | `proposal/elandor_hearthpine_vale.spawns.json` |  |
| Copperfell Foothills | 11-20 | border elandor_hearthpine_vale | border elandor_dur_brannoc, elandor_frostbarrow_shelf, elandor_whitebridge_shire | `proposal/elandor_copperfell_foothills.spawns.json` |  |
| Dur Brannoc | 20-30 | anchor capital + border elandor_copperfell_foothills | border elandor_stormvault_heights | `proposal/elandor_dur_brannoc.spawns.json` |  |
| Frostbarrow Shelf | 21-30 | border elandor_dur_brannoc, elandor_copperfell_foothills | border elandor_stormvault_heights | `proposal/elandor_frostbarrow_shelf.spawns.json` |  |
| Stormvault Heights | 31-40 | border elandor_dur_brannoc, elandor_frostbarrow_shelf, elandor_whitebridge_shire | border front_broken_causeway, front_gravesalt_escarpment | `proposal/elandor_stormvault_heights.spawns.json` |  |
| Dawnmere Fields | 1-10 | anchor start | border elandor_goldmead_vale | `proposal/elandor_dawnmere_fields.spawns.json` |  |
| Goldmead Vale | 11-20 | border elandor_dawnmere_fields | border elandor_highcourt, elandor_lorindor, elandor_whitebridge_shire | `proposal/elandor_goldmead_vale.spawns.json` |  |
| Highcourt | 20-30 | anchor capital + border elandor_goldmead_vale | border elandor_ashenward_march | `proposal/elandor_highcourt.spawns.json` |  |
| Whitebridge Shire | 21-30 | border elandor_copperfell_foothills, elandor_dur_brannoc, elandor_goldmead_vale, elandor_highcourt | border elandor_ashenward_march, elandor_stormvault_heights | `proposal/elandor_whitebridge_shire.spawns.json` |  |
| Ashenward March | 31-40 | border elandor_highcourt, elandor_lorindor, elandor_whitebridge_shire | border front_broken_causeway, front_shattered_line | `proposal/elandor_ashenward_march.spawns.json` |  |
| Silverleaf Glades | 1-10 | anchor start | border elandor_starbough_vale | `proposal/elandor_silverleaf_glades.spawns.json` |  |
| Starbough Vale | 11-20 | border elandor_silverleaf_glades | border elandor_lethariel, elandor_lorindor, elandor_moonfall_wood | `proposal/elandor_starbough_vale.spawns.json` |  |
| Lethariel | 20-30 | anchor capital + border elandor_starbough_vale | border elandor_glassroot_wilds | `proposal/elandor_lethariel.spawns.json` |  |
| Lorindor | 21-30 | border elandor_goldmead_vale, elandor_highcourt, elandor_lethariel, elandor_starbough_vale | border elandor_ashenward_march, elandor_glassroot_wilds | `proposal/elandor_lorindor.spawns.json` |  |
| Moonfall Wood | 21-30 | border elandor_lethariel, elandor_silverleaf_glades, elandor_starbough_vale | border elandor_glassroot_wilds | `proposal/elandor_moonfall_wood.spawns.json` |  |
| Glassroot Wilds | 31-40 | border elandor_lethariel, elandor_lorindor, elandor_moonfall_wood | border front_shattered_line, front_skyglass_canopy | `proposal/elandor_glassroot_wilds.spawns.json` |  |
| Stillgrave Hollow | 1-10 | anchor start | border kragmar_mournfen | `proposal/kragmar_stillgrave_hollow.spawns.json` |  |
| Mournfen | 11-20 | border kragmar_stillgrave_hollow | border kragmar_nhal_veyr, kragmar_ossuary_reach, kragmar_speargrass_reach | `proposal/kragmar_mournfen.spawns.json` |  |
| Nhal Veyr | 20-30 | anchor capital + border kragmar_mournfen | border kragmar_blackwind_rise | `proposal/kragmar_nhal_veyr.spawns.json` |  |
| Ossuary Reach | 21-30 | border kragmar_mournfen, kragmar_nhal_veyr, kragmar_stillgrave_hollow | border kragmar_blackwind_rise | `proposal/kragmar_ossuary_reach.spawns.json` |  |
| Blackwind Rise | 31-40 | border kragmar_nhal_veyr, kragmar_ossuary_reach, kragmar_speargrass_reach | border front_broken_causeway, front_gravesalt_escarpment | `proposal/kragmar_blackwind_rise.spawns.json` |  |
| Sunscar Flats | 1-10 | anchor start | border kragmar_redtusk_savanna | `proposal/kragmar_sunscar_flats.spawns.json` |  |
| Redtusk Savanna | 11-20 | border kragmar_sunscar_flats | border kragmar_gor_drazhak, kragmar_speargrass_reach, kragmar_whispering_reedlands | `proposal/kragmar_redtusk_savanna.spawns.json` |  |
| Gor Drazhak | 20-30 | anchor capital + border kragmar_redtusk_savanna | border kragmar_bannerbreak_mesa | `proposal/kragmar_gor_drazhak.spawns.json` |  |
| Speargrass Reach | 21-30 | border kragmar_gor_drazhak, kragmar_mournfen, kragmar_nhal_veyr, kragmar_redtusk_savanna, kragmar_sunscar_flats | border kragmar_bannerbreak_mesa, kragmar_blackwind_rise | `proposal/kragmar_speargrass_reach.spawns.json` |  |
| Bannerbreak Mesa | 31-40 | border kragmar_gor_drazhak, kragmar_speargrass_reach, kragmar_whispering_reedlands | border front_broken_causeway, front_shattered_line | `proposal/kragmar_bannerbreak_mesa.spawns.json` |  |
| Kapok Cradle | 1-10 | anchor start | border kragmar_raincall_basin | `proposal/kragmar_kapok_cradle.spawns.json` |  |
| Raincall Basin | 11-20 | border kragmar_kapok_cradle | border kragmar_kezamba, kragmar_totemwater_reach, kragmar_whispering_reedlands | `proposal/kragmar_raincall_basin.spawns.json` |  |
| Kezamba | 20-30 | anchor capital + border kragmar_raincall_basin | border kragmar_thunderroot_wilds | `proposal/kragmar_kezamba.spawns.json` |  |
| Whispering Reedlands | 21-30 | border kragmar_gor_drazhak, kragmar_kezamba, kragmar_raincall_basin, kragmar_redtusk_savanna | border kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds | `proposal/kragmar_whispering_reedlands.spawns.json` |  |
| Totemwater Reach | 21-30 | border kragmar_kapok_cradle, kragmar_kezamba, kragmar_raincall_basin | border kragmar_thunderroot_wilds | `proposal/kragmar_totemwater_reach.spawns.json` |  |
| Thunderroot Wilds | 31-40 | border kragmar_kezamba, kragmar_totemwater_reach, kragmar_whispering_reedlands | border front_shattered_line, front_skyglass_canopy | `proposal/kragmar_thunderroot_wilds.spawns.json` |  |
| Gravesalt Escarpment | 51-60 | border elandor_stormvault_heights, front_broken_causeway, kragmar_blackwind_rise | core | `proposal/front_gravesalt_escarpment.spawns.json` |  |
| The Broken Causeway | 31-40 | border elandor_ashenward_march, elandor_stormvault_heights, kragmar_bannerbreak_mesa, kragmar_blackwind_rise | core | `proposal/front_broken_causeway.spawns.json` |  |
| The Shattered Line | 41-50 | border elandor_ashenward_march, elandor_glassroot_wilds, front_broken_causeway, kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds | core | `proposal/front_shattered_line.spawns.json` |  |
| The Skyglass Canopy | 51-60 | border elandor_glassroot_wilds, front_shattered_line, kragmar_thunderroot_wilds | core | `proposal/front_skyglass_canopy.spawns.json` |  |

Cells two zones both claim (kept by the first): 138. Seconds: world 17.5, raster 3.3, regions 11.4.
