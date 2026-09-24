-- MAP-B P9G-2 extension. Pure data shared by registration and mapgen.
local M={schema="grug_world_content_v1", p9g_count=36}
local starts={"elandor_hearthpine_vale","elandor_dawnmere_fields","elandor_silverleaf_glades",
 "kragmar_stillgrave_hollow","kragmar_sunscar_flats","kragmar_kapok_cradle"}
local homes={"elandor_copperfell_foothills","elandor_goldmead_vale","elandor_starbough_vale",
 "kragmar_mournfen","kragmar_redtusk_savanna","kragmar_raincall_basin"}
local function subset(a,first,last,b)
 local out={};for i=first,last do out[#out+1]=a[i];if b then out[#out+1]=b[i] end end
 table.sort(out);return out
end
local soil={
 meadows={"default:dirt_with_grass","default:dirt","grug_nodes:dirt_with_forest_litter"},
 pine_hills={"default:dirt_with_coniferous_litter","grug_nodes:dirt_with_forest_litter","default:dirt_with_grass"},
 elf_forest={"grug_nodes:dirt_with_silver_litter","grug_nodes:dirt_with_moss","default:dirt_with_grass"},
 deep_forest={"grug_nodes:dirt_with_forest_litter","default:dirt_with_coniferous_litter","default:dirt_with_grass"},
 savanna={"default:dry_dirt_with_dry_grass","default:dry_dirt","grug_nodes:mesa_clay"},
 blight={"grug_nodes:blight_dirt","grug_nodes:ash_ground","grug_nodes:dirt_with_bone_litter"},
 jungle_edge={"default:dirt_with_rainforest_litter","grug_nodes:dirt_with_canopy_litter","grug_nodes:mud"},
 badlands={"grug_nodes:mesa_clay"},swamp={"grug_nodes:mud"},crags={"default:gravel"}}
local function hosts(keys)
 local out={};for _,key in ipairs(keys) do out["grug_"..key]=soil[key] end;return out
end
local common=hosts({"meadows","pine_hills","elf_forest","savanna","blight","jungle_edge"})
local function row(key,zones,support,min,max,shore,density,mode)
 return {key=key,node="grug_mapgen:"..key.."_source",item="grug_cooking:"..key,
  zones=zones,hosts=support,min=min,max=max,shore=shore or "none",density=density or 256,
  mode=mode or "surface"}
end
M.plants={
 row("bamboo_shoot",{}, {grug_jungle_edge={"default:sand","grug_nodes:mud"},
  grug_deep_jungle={"default:sand","grug_nodes:mud"},grug_swamp={"default:sand","grug_nodes:mud"}},1,60,"any"),
 row("blightberry",{homes[4]},hosts({"blight"}),11,20),
 row("carrot",subset(starts,1,3),hosts({"meadows","pine_hills","elf_forest"}),1,6),
 row("cassava",subset(starts,4,6),hosts({"savanna","blight","jungle_edge"}),1,6),
 row("cave_cap",{}, {stone={"default:stone","grug_materials:granite","grug_materials:slate","grug_materials:basalt"}},-500,-100,"none",768,"cave"),
 row("ember_moss",{}, {stone={"grug_materials:emberrock"}},-30912,-701,"none",1024,"cave"),
 row("fire_pepper",subset(starts,4,6,homes),hosts({"savanna","blight","jungle_edge","badlands"}),1,20,"none",512),
 row("frost_melon",{"elandor_frostbarrow_shelf","elandor_whitebridge_shire"},hosts({"crags","swamp"}),21,30,"fresh"),
 row("jungle_berry",{homes[6]},hosts({"jungle_edge"}),11,20),
 row("pumpkin",subset(homes,1,6),hosts({"meadows","swamp","blight"}),11,20),
 row("salt_crust",{"front_shattered_line"},hosts({"badlands"}),44,50,"none",512),
 row("sugar_cane",{}, {any={"default:sand"}},1,60,"any"),
 row("sunberry",{homes[5]},hosts({"savanna"}),11,20),
 row("wild_grain",subset(starts,1,6,homes),common,4,20),
 row("wild_onion",subset(starts,1,3,homes),hosts({"deep_forest","pine_hills","elf_forest"}),1,20,"none",512),
}
M.reef={"default:coral_brown","default:coral_cyan","default:coral_green",
 "default:coral_orange","default:coral_pink","default:coral_skeleton","default:sand_with_kelp"}
M.freshwater={"grug_mapgen:freshwater_waterlily","grug_mapgen:freshwater_waterweed"}
M.names={}
for _,p in ipairs(M.plants) do M.names[#M.names+1]=p.node end
for _,name in ipairs(M.reef) do M.names[#M.names+1]=name end
for _,name in ipairs(M.freshwater) do M.names[#M.names+1]=name end
return M
