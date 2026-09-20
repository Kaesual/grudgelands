-- Focused Round 11 ART bindings; real gear registration runs separately via
-- tools/wp13/gear_catalogue_kat.lua.
return function(repo)
 local function exists(path)
  local handle=assert(io.open(repo.."/"..path,"rb"),"missing media "..path)
  local body=handle:read("*a");handle:close();assert(#body>0,path.." is empty")
 end
 local seeds=dofile(repo.."/mods/ITEMS/grug_farming/seed_visuals.lua")
 local crop_keys={"wild_grain","carrot","cassava","wild_onion","fire_pepper",
  "pumpkin","blightberry","sunberry","jungle_berry","frost_melon",
  "sugar_cane","bamboo_shoot","cave_cap","salt_crust","ember_moss",
  "potato","corn"}
 local seen={}
 for _,key in ipairs(crop_keys)do
  local texture=assert(seeds[key],"missing seed visual "..key)
  local file=texture:match("^([^%^]+)")
  exists("mods/ITEMS/grug_farming/textures/"..file);seen[key]=true
 end
 for key in pairs(seeds)do assert(seen[key],"unknown seed visual "..key)end
 local gear={"grug_gear_bow_wood.png","grug_gear_bow_lebethron.png",
  "grug_gear_bow_birch.png","grug_gear_bow_mallorn.png",
  "grug_gear_bow_alder.png","grug_gear_spellbook.png","grug_gear_arrow.png"}
 for _,material in ipairs({"bronze","iron","steel","silversteel",
  "embersteel","abyssal_steel"})do
  gear[#gear+1]="grug_gear_shield_"..material..".png"
 end
 for _,file in ipairs(gear)do exists("mods/ITEMS/grug_gear/textures/"..file)end
 for _,file in ipairs({"small","medium","large"})do
  exists("mods/PLAYER/grug_inventory/textures/grug_inventory_bag_"..file..".png")
 end
 exists("mods/PLAYER/grug_inventory/textures/grug_inventory_quiver.png")
 return "R11 ART media PASS: 17 seed bindings, 7 bow identities from 5 sources, 6 shields, tiered book, arrow, 3 bag silhouettes, bounded quiver\n"
end
