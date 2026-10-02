# Spawn levels across the mainland: seed 42, proposed recipes

Built with `tools/r28_world/run.sh` from the border rule's recipe copies (`border_rule.py --out`; a zone without a copy keeps its shipped file) (one world build, every mainland zone's region map through the game's `spawn_regions_core.lua`). The two dragon islands are left out (one belt, L60, no land border). Border edges are sides shared by land cells (32 nodes each) of two zones; the gap is the distance between the two regions' level ranges.

## Border length per class

| class | meaning | nodes | share |
|---|---|---:|---:|
| fit | fit: gap <= 1 (ranges overlap or touch) | 45536 | 73.1 % |
| step | step: gap 2-5 | 9952 | 16.0 % |
| jump | jump: gap > 5 | 1088 | 1.7 % |
| forced | forced: the zones' bands lie > 5 apart | 5696 | 9.1 % |
| none | a side without recipe | 0 | 0.0 % |
| total | | 62272 | |

## Red borders (gap > 5)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 160 | The Broken Causeway | L31-33 | The Shattered Line | L41-43 | 8 |
| 96 | Moonfall Wood | L21-23 | Starbough Vale | L11-13 | 8 |
| 96 | The Shattered Line | L41-43 | The Skyglass Canopy | L51-53 | 8 |
| 96 | Mournfen | L11-13 | Ossuary Reach | L21-23 | 8 |
| 96 | Raincall Basin | L11-13 | Totemwater Reach | L21-23 | 8 |
| 64 | Frostbarrow Shelf | L21-23 | Stormvault Heights | L31-33 | 8 |
| 64 | Glassroot Wilds | L31-33 | Moonfall Wood | L21-23 | 8 |
| 64 | Blackwind Rise | L31-33 | Ossuary Reach | L21-23 | 8 |
| 64 | Blackwind Rise | L31-33 | Speargrass Reach | L21-23 | 8 |
| 32 | Ashenward March | L31-33 | Lorindor | L21-23 | 8 |
| 32 | Ashenward March | L31-33 | Whitebridge Shire | L21-23 | 8 |
| 32 | Glassroot Wilds | L31-33 | Lorindor | L21-23 | 8 |
| 32 | Stormvault Heights | L31-33 | Whitebridge Shire | L21-23 | 8 |
| 32 | Bannerbreak Mesa | L31-33 | Speargrass Reach | L21-23 | 8 |
| 32 | Bannerbreak Mesa | L31-33 | Whispering Reedlands | L21-23 | 8 |
| 32 | Redtusk Savanna | L11-13 | Speargrass Reach | L21-23 | 8 |
| 32 | Thunderroot Wilds | L31-33 | Totemwater Reach | L21-23 | 8 |
| 32 | Thunderroot Wilds | L31-33 | Whispering Reedlands | L21-23 | 8 |

## Yellow borders (gap 2-5)

| nodes | zone | levels | zone | levels | gap |
|---:|---|---|---|---|---:|
| 1472 | The Broken Causeway | L31-33 | Bannerbreak Mesa | L38-40 | 5 |
| 1376 | Ashenward March | L38-40 | The Broken Causeway | L31-33 | 5 |
| 928 | Stormvault Heights | L38-40 | The Broken Causeway | L31-33 | 5 |
| 608 | The Broken Causeway | L31-33 | Blackwind Rise | L38-40 | 5 |
| 512 | Lethariel | L28-30 | Moonfall Wood | L21-23 | 5 |
| 384 | Kezamba | L28-30 | Whispering Reedlands | L21-23 | 5 |
| 384 | Nhal Veyr | L28-30 | Speargrass Reach | L21-23 | 5 |
| 352 | Dur Brannoc | L28-30 | Whitebridge Shire | L21-23 | 5 |
| 352 | Kezamba | L28-30 | Totemwater Reach | L21-23 | 5 |
| 352 | Nhal Veyr | L28-30 | Ossuary Reach | L21-23 | 5 |
| 320 | Dur Brannoc | L28-30 | Frostbarrow Shelf | L21-23 | 5 |
| 320 | The Broken Causeway | L34-37 | The Shattered Line | L41-43 | 4 |
| 320 | The Shattered Line | L44-47 | The Skyglass Canopy | L51-53 | 4 |
| 320 | Gor Drazhak | L28-30 | Speargrass Reach | L21-23 | 5 |
| 288 | Lethariel | L28-30 | Lorindor | L21-23 | 5 |
| 288 | Gor Drazhak | L28-30 | Whispering Reedlands | L21-23 | 5 |
| 256 | Highcourt | L28-30 | Whitebridge Shire | L21-23 | 5 |
| 160 | Highcourt | L28-30 | Lorindor | L21-23 | 5 |
| 96 | Stormvault Heights | L31-33 | Whitebridge Shire | L24-27 | 4 |
| 64 | Ashenward March | L31-33 | Lorindor | L24-27 | 4 |
| 64 | Ashenward March | L31-33 | Whitebridge Shire | L24-27 | 4 |
| 64 | Frostbarrow Shelf | L24-27 | Stormvault Heights | L31-33 | 4 |
| 64 | Glassroot Wilds | L31-33 | Moonfall Wood | L24-27 | 4 |
| 64 | Moonfall Wood | L21-23 | Starbough Vale | L14-17 | 4 |
| 64 | The Shattered Line | L44-47 | Bannerbreak Mesa | L38-40 | 4 |
| 64 | Blackwind Rise | L31-33 | Speargrass Reach | L24-27 | 4 |
| 64 | Mournfen | L14-17 | Ossuary Reach | L21-23 | 4 |
| 64 | Redtusk Savanna | L14-17 | Speargrass Reach | L21-23 | 4 |
| 64 | Thunderroot Wilds | L31-33 | Totemwater Reach | L24-27 | 4 |
| 32 | Dawnmere Fields | L8-10 | Goldmead Vale | L14-17 | 4 |
| 32 | Glassroot Wilds | L31-33 | Lorindor | L24-27 | 4 |
| 32 | Bannerbreak Mesa | L31-33 | Speargrass Reach | L24-27 | 4 |
| 32 | Bannerbreak Mesa | L31-33 | Whispering Reedlands | L24-27 | 4 |
| 32 | Blackwind Rise | L31-33 | Ossuary Reach | L24-27 | 4 |
| 32 | Raincall Basin | L14-17 | Totemwater Reach | L21-23 | 4 |
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
| Ashenward March | Lorindor | 352 | 64 | 32 |  |  | yes |
| Ashenward March | Stormvault Heights | 544 |  |  |  |  | yes |
| Ashenward March | Whitebridge Shire | 544 | 64 | 32 |  |  | yes |
| Ashenward March | The Broken Causeway |  | 1376 |  |  |  | yes |
| Ashenward March | The Shattered Line | 1216 |  |  |  |  | yes |
| Copperfell Foothills | Dur Brannoc | 1120 |  |  |  |  | yes |
| Copperfell Foothills | Frostbarrow Shelf | 512 |  |  |  |  | yes |
| Copperfell Foothills | Hearthpine Vale | 1600 |  |  |  |  | yes |
| Copperfell Foothills | Whitebridge Shire | 224 |  |  |  |  | yes |
| Dawnmere Fields | Goldmead Vale | 1472 | 32 |  |  |  | yes |
| Dur Brannoc | Frostbarrow Shelf | 608 | 320 |  |  |  | yes |
| Dur Brannoc | Stormvault Heights | 832 |  |  |  |  | yes |
| Dur Brannoc | Whitebridge Shire | 544 | 352 |  |  |  | yes |
| Frostbarrow Shelf | Stormvault Heights | 352 | 64 | 64 |  |  | yes |
| Glassroot Wilds | Lethariel | 800 |  |  |  |  | yes |
| Glassroot Wilds | Lorindor | 608 | 32 | 32 |  |  | yes |
| Glassroot Wilds | Moonfall Wood | 704 | 64 | 64 |  |  | yes |
| Glassroot Wilds | The Shattered Line | 512 |  |  |  |  | yes |
| Glassroot Wilds | The Skyglass Canopy |  |  |  | 1152 |  | yes |
| Goldmead Vale | Highcourt | 1376 |  |  |  |  | yes |
| Goldmead Vale | Lorindor | 448 |  |  |  |  | yes |
| Goldmead Vale | Whitebridge Shire | 640 |  |  |  |  | yes |
| Highcourt | Lorindor | 288 | 160 |  |  |  | yes |
| Highcourt | Whitebridge Shire | 448 | 256 |  |  |  | yes |
| Lethariel | Lorindor | 352 | 288 |  |  |  | yes |
| Lethariel | Moonfall Wood | 832 | 512 |  |  |  | yes |
| Lethariel | Starbough Vale | 1152 |  |  |  |  | yes |
| Lorindor | Starbough Vale | 320 |  |  |  |  | yes |
| Moonfall Wood | Silverleaf Glades |  |  |  | 192 |  | yes |
| Moonfall Wood | Starbough Vale | 384 | 64 | 96 |  |  | yes |
| Silverleaf Glades | Starbough Vale | 1344 |  |  |  |  | yes |
| Stormvault Heights | Whitebridge Shire | 608 | 96 | 32 |  |  | yes |
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
| Bannerbreak Mesa | Speargrass Reach | 576 | 32 | 32 |  |  | yes |
| Bannerbreak Mesa | Thunderroot Wilds | 768 |  |  |  |  | yes |
| Bannerbreak Mesa | Whispering Reedlands | 640 | 32 | 32 |  |  | yes |
| Blackwind Rise | Nhal Veyr | 928 |  |  |  |  | yes |
| Blackwind Rise | Ossuary Reach | 352 | 32 | 64 |  |  | yes |
| Blackwind Rise | Speargrass Reach | 288 | 64 | 64 |  |  | yes |
| Gor Drazhak | Redtusk Savanna | 1184 |  |  |  |  | yes |
| Gor Drazhak | Speargrass Reach | 416 | 320 |  |  |  | yes |
| Gor Drazhak | Whispering Reedlands | 480 | 288 |  |  |  | yes |
| Kapok Cradle | Raincall Basin | 1504 |  |  |  |  | yes |
| Kapok Cradle | Totemwater Reach |  |  |  | 256 |  | yes |
| Kezamba | Raincall Basin | 992 |  |  |  |  | yes |
| Kezamba | Thunderroot Wilds | 832 |  |  |  |  | yes |
| Kezamba | Totemwater Reach | 448 | 352 |  |  |  | yes |
| Kezamba | Whispering Reedlands | 608 | 384 |  |  |  | yes |
| Mournfen | Nhal Veyr | 864 |  |  |  |  | yes |
| Mournfen | Ossuary Reach | 320 | 64 | 96 |  |  | yes |
| Mournfen | Speargrass Reach | 288 |  |  |  |  | yes |
| Mournfen | Stillgrave Hollow | 1440 |  |  |  |  | yes |
| Nhal Veyr | Ossuary Reach | 640 | 352 |  |  |  | yes |
| Nhal Veyr | Speargrass Reach | 416 | 384 |  |  |  | yes |
| Ossuary Reach | Stillgrave Hollow |  |  |  | 256 |  | yes |
| Raincall Basin | Totemwater Reach | 576 | 32 | 96 |  |  | yes |
| Raincall Basin | Whispering Reedlands | 512 |  |  |  |  | yes |
| Redtusk Savanna | Speargrass Reach | 864 | 64 | 32 |  |  | yes |
| Redtusk Savanna | Sunscar Flats | 1632 |  |  |  |  | yes |
| Redtusk Savanna | Whispering Reedlands | 416 |  |  |  |  | yes |
| Thunderroot Wilds | Totemwater Reach | 416 | 64 | 32 |  |  | yes |
| Thunderroot Wilds | Whispering Reedlands | 608 | 32 | 32 |  |  | yes |

## Zone pairs that touch on this seed but are not neighbours in the atlas

The atlas lists seed 42's neighbours, and the border rule names only those; a border below is neither entry nor exit in any recipe.

None.

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

Cells two zones both claim (kept by the first): 151. Seconds: world 17.6, raster 3.0, regions 10.4.
