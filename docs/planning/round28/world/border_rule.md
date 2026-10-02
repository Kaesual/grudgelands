# Border rule: spawn recipes' from / to per zone

Atlas `docs/planning/round28/zones`, recipes `mods/ENTITIES/grug_mobs/data/zones`. Low = `from` (entry), high = `to` (exit). Kinds by the atlas role; the rule table is in `tools/r28_world/border_rule.py`.

| zone | kind | current from -> to | rule from -> to | neutral | status |
|---|---|---|---|---|---|
| Ashenward March | contested | border elandor_highcourt, elandor_lorindor, elandor_whitebridge_shire -> border front_broken_causeway, front_shattered_line | border elandor_highcourt, elandor_lorindor, elandor_whitebridge_shire -> border front_broken_causeway, front_shattered_line | glassroot_wilds, stormvault_heights | same |
| Copperfell Foothills | home | border elandor_hearthpine_vale -> border elandor_dur_brannoc | border elandor_hearthpine_vale -> border elandor_dur_brannoc, elandor_frostbarrow_shelf, elandor_whitebridge_shire |  | changes |
| Dawnmere Fields | start | anchor start -> border elandor_goldmead_vale | anchor start -> border elandor_goldmead_vale |  | same |
| Dur Brannoc | capital | anchor capital -> border elandor_stormvault_heights | anchor capital + border elandor_copperfell_foothills -> border elandor_stormvault_heights | frostbarrow_shelf, whitebridge_shire | changes |
| Frostbarrow Shelf | heartland | border elandor_copperfell_foothills, elandor_dur_brannoc -> border elandor_stormvault_heights | border elandor_copperfell_foothills, elandor_dur_brannoc -> border elandor_stormvault_heights |  | same |
| Glassroot Wilds | contested | border elandor_lethariel, elandor_lorindor, elandor_moonfall_wood -> border front_shattered_line, front_skyglass_canopy | border elandor_lethariel, elandor_lorindor, elandor_moonfall_wood -> border front_shattered_line, front_skyglass_canopy | ashenward_march | same |
| Goldmead Vale | home | border elandor_dawnmere_fields -> border elandor_highcourt | border elandor_dawnmere_fields -> border elandor_highcourt, elandor_lorindor, elandor_whitebridge_shire |  | changes |
| Hearthpine Vale | start | anchor start -> border elandor_copperfell_foothills | anchor start -> border elandor_copperfell_foothills |  | same |
| Highcourt | capital | anchor capital -> border elandor_ashenward_march | anchor capital + border elandor_goldmead_vale -> border elandor_ashenward_march | lorindor, whitebridge_shire | changes |
| Lethariel | capital | anchor capital -> border elandor_glassroot_wilds | anchor capital + border elandor_starbough_vale -> border elandor_glassroot_wilds | lorindor, moonfall_wood | changes |
| Lorindor | heartland | border elandor_lethariel, elandor_starbough_vale -> border elandor_ashenward_march, elandor_glassroot_wilds | border elandor_goldmead_vale, elandor_highcourt, elandor_lethariel, elandor_starbough_vale -> border elandor_ashenward_march, elandor_glassroot_wilds |  | changes |
| Moonfall Wood | heartland | border elandor_lethariel, elandor_starbough_vale -> border elandor_glassroot_wilds | border elandor_lethariel, elandor_silverleaf_glades, elandor_starbough_vale -> border elandor_glassroot_wilds |  | changes |
| Silverleaf Glades | start | anchor start -> border elandor_starbough_vale | anchor start -> border elandor_starbough_vale | moonfall_wood | same |
| Starbough Vale | home | border elandor_silverleaf_glades -> border elandor_lethariel | border elandor_silverleaf_glades -> border elandor_lethariel, elandor_lorindor, elandor_moonfall_wood |  | changes |
| Stormvault Heights | contested | border elandor_dur_brannoc, elandor_frostbarrow_shelf, elandor_whitebridge_shire -> border front_broken_causeway, front_gravesalt_escarpment | border elandor_dur_brannoc, elandor_frostbarrow_shelf, elandor_whitebridge_shire -> border front_broken_causeway, front_gravesalt_escarpment | ashenward_march | same |
| Whitebridge Shire | heartland | border elandor_goldmead_vale, elandor_highcourt -> border elandor_ashenward_march, elandor_stormvault_heights | border elandor_copperfell_foothills, elandor_dur_brannoc, elandor_goldmead_vale, elandor_highcourt -> border elandor_ashenward_march, elandor_stormvault_heights |  | changes |
| The Broken Causeway | front | border elandor_ashenward_march, elandor_stormvault_heights, kragmar_bannerbreak_mesa, kragmar_blackwind_rise -> core core | as today |  | unchanged (front) |
| Gravesalt Escarpment | front | border elandor_stormvault_heights, front_broken_causeway, kragmar_blackwind_rise -> core core | as today |  | unchanged (front) |
| The Shattered Line | front | border elandor_ashenward_march, elandor_glassroot_wilds, front_broken_causeway, kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds -> core core | as today |  | unchanged (front) |
| The Skyglass Canopy | front | border elandor_glassroot_wilds, front_shattered_line, kragmar_thunderroot_wilds -> core core | as today |  | unchanged (front) |
| Stormscale Summit | island | - -> - | as today |  | unchanged (island) |
| The Wyrmglass Crown | island | - -> - | as today |  | unchanged (island) |
| Bannerbreak Mesa | contested | border kragmar_gor_drazhak, kragmar_speargrass_reach, kragmar_whispering_reedlands -> border front_broken_causeway, front_shattered_line | border kragmar_gor_drazhak, kragmar_speargrass_reach, kragmar_whispering_reedlands -> border front_broken_causeway, front_shattered_line | blackwind_rise, thunderroot_wilds | same |
| Blackwind Rise | contested | border kragmar_nhal_veyr, kragmar_ossuary_reach, kragmar_speargrass_reach -> border front_broken_causeway, front_gravesalt_escarpment | border kragmar_nhal_veyr, kragmar_ossuary_reach, kragmar_speargrass_reach -> border front_broken_causeway, front_gravesalt_escarpment | bannerbreak_mesa | same |
| Gor Drazhak | capital | anchor capital -> border kragmar_bannerbreak_mesa | anchor capital + border kragmar_redtusk_savanna -> border kragmar_bannerbreak_mesa | speargrass_reach, whispering_reedlands | changes |
| Kapok Cradle | start | anchor start -> border kragmar_raincall_basin | anchor start -> border kragmar_raincall_basin | totemwater_reach | same |
| Kezamba | capital | anchor capital -> border kragmar_thunderroot_wilds | anchor capital + border kragmar_raincall_basin -> border kragmar_thunderroot_wilds | totemwater_reach, whispering_reedlands | changes |
| Mournfen | home | border kragmar_stillgrave_hollow -> border kragmar_nhal_veyr | border kragmar_stillgrave_hollow -> border kragmar_nhal_veyr, kragmar_ossuary_reach, kragmar_speargrass_reach |  | changes |
| Nhal Veyr | capital | anchor capital -> border kragmar_blackwind_rise | anchor capital + border kragmar_mournfen -> border kragmar_blackwind_rise | ossuary_reach, speargrass_reach | changes |
| Ossuary Reach | heartland | border kragmar_mournfen, kragmar_nhal_veyr -> border kragmar_blackwind_rise | border kragmar_mournfen, kragmar_nhal_veyr, kragmar_stillgrave_hollow -> border kragmar_blackwind_rise |  | changes |
| Raincall Basin | home | border kragmar_kapok_cradle -> border kragmar_kezamba | border kragmar_kapok_cradle -> border kragmar_kezamba, kragmar_totemwater_reach, kragmar_whispering_reedlands |  | changes |
| Redtusk Savanna | home | border kragmar_sunscar_flats -> border kragmar_gor_drazhak | border kragmar_sunscar_flats -> border kragmar_gor_drazhak, kragmar_speargrass_reach, kragmar_whispering_reedlands |  | changes |
| Speargrass Reach | heartland | border kragmar_gor_drazhak, kragmar_redtusk_savanna -> border kragmar_bannerbreak_mesa, kragmar_blackwind_rise | border kragmar_gor_drazhak, kragmar_mournfen, kragmar_nhal_veyr, kragmar_redtusk_savanna, kragmar_sunscar_flats -> border kragmar_bannerbreak_mesa, kragmar_blackwind_rise |  | changes |
| Stillgrave Hollow | start | anchor start -> border kragmar_mournfen | anchor start -> border kragmar_mournfen | ossuary_reach | same |
| Sunscar Flats | start | anchor start -> border kragmar_redtusk_savanna | anchor start -> border kragmar_redtusk_savanna | speargrass_reach | same |
| Thunderroot Wilds | contested | border kragmar_kezamba, kragmar_totemwater_reach, kragmar_whispering_reedlands -> border front_shattered_line, front_skyglass_canopy | border kragmar_kezamba, kragmar_totemwater_reach, kragmar_whispering_reedlands -> border front_shattered_line, front_skyglass_canopy | bannerbreak_mesa | same |
| Totemwater Reach | heartland | border kragmar_kezamba, kragmar_raincall_basin -> border kragmar_thunderroot_wilds | border kragmar_kapok_cradle, kragmar_kezamba, kragmar_raincall_basin -> border kragmar_thunderroot_wilds |  | changes |
| Whispering Reedlands | heartland | border kragmar_kezamba, kragmar_raincall_basin -> border kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds | border kragmar_gor_drazhak, kragmar_kezamba, kragmar_raincall_basin, kragmar_redtusk_savanna -> border kragmar_bannerbreak_mesa, kragmar_thunderroot_wilds |  | changes |

Zones: changes 19, same 13, unchanged 6.
Recipe files written to `/tmp/r28_world.4JzR7n/proposal`: 38.
