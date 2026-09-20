-- Small production-tail cases. Actual resolver/registered semantics, controlled
-- settled VM accessors; the separate writer fixture proves transaction emission.
return function(repo)
 local dir=repo.."/mods/MAPGEN/grug_mapgen/wp40"
 local content,api=dofile(repo.."/tools/r10_map_b/content_fixture.lua")(repo)
 local catalog=dofile(dir.."/world_content_catalog.lua")
 local config=dofile(dir.."/world_content.lua")(catalog,content.p9g,
  dofile(dir.."/habitat_registry.lua"))
 local cases={
  {"bamboo_shoot","kragmar_kapok_cradle","grug_jungle_edge","grug_nodes:mud",3,30,"planned_water"},
  {"blightberry","kragmar_mournfen","grug_blight","grug_nodes:blight_dirt",15,30},
  {"carrot","elandor_dawnmere_fields","grug_meadows","default:dirt_with_grass",3,30},
  {"cassava","kragmar_sunscar_flats","grug_savanna","default:dry_dirt_with_dry_grass",3,30},
  {"cave_cap","elandor_dawnmere_fields","grug_meadows","default:stone",3,-200},
  {"ember_moss","kragmar_mournfen","grug_blight","grug_materials:emberrock",15,-800},
  {"fire_pepper","kragmar_sunscar_flats","grug_savanna","default:dry_dirt_with_dry_grass",7,30},
  {"frost_melon","elandor_frostbarrow_shelf","grug_crags","default:gravel",25,30,"planned_water"},
  {"jungle_berry","kragmar_raincall_basin","grug_jungle_edge","default:dirt_with_rainforest_litter",15,30},
  {"pumpkin","elandor_goldmead_vale","grug_meadows","default:dirt_with_grass",15,30},
  {"salt_crust","front_shattered_line","grug_badlands","grug_nodes:mesa_clay",47,30},
  {"sugar_cane","elandor_dawnmere_fields","grug_beach","default:sand",3,30,"coastal_shelf"},
  {"sunberry","kragmar_redtusk_savanna","grug_savanna","default:dry_dirt_with_dry_grass",15,30},
  {"wild_grain","elandor_dawnmere_fields","grug_meadows","default:dirt_with_grass",7,30},
  {"wild_onion","elandor_hearthpine_vale","grug_pine_hills","default:dirt_with_coniferous_litter",3,30},
 }
 local records={}
 for index,case in ipairs(cases) do
  assert(catalog.plants[index].key==case[1])
  local air=api.get_content_id("air")
  local level,zone,host,shore=case[5],case[2],case[4],case[7]
  local protected,housing,allow_cave,occupied=false,false,true,0
  local cave=case[6]<0
  local y=cave and case[6] or case[6]+1
  local plan={};local writes={}
  local tail=config.new({content={content_contract=function() return content.production end},
   full_seed_string="4151598227737528026",
   zones_session={surface_mob_level_at=function() return level end}})
  tail.bind(plan,1)
  local ctx={plan=plan,generation=1,min_z=0,max_z=0,min_y=y-1,max_y=y}
  function ctx.inside_owner(x,yy,z) return x==ctx.min_x and z==0 and yy>=ctx.min_y and yy<=ctx.max_y end
  function ctx.column_values_at(x,z)
   if x~=ctx.min_x or z~=0 then
    return shore or "land",1,zone,case[3],"human",case[6]-1,shore and case[6] or nil
   end
   return "land",1,zone,case[3],"human",cave and 30 or case[6]
  end
  function ctx.exclusion_at() return protected end
  function ctx.housing_excluded_at() return housing end
  function ctx.cave_content_allowed_at() return allow_cave and not protected end
  function ctx.settled_at(_,yy)
   if yy==y then return air,0,occupied,cave and 27 or 0 end
   return api.get_content_id(host),0,0,4
  end
  ctx.analytic_p7_tuple=ctx.settled_at
  function ctx.write_p9g(x,yy,z,cid,p2,ref,feature)
   assert(ctx.inside_owner(x,yy,z) and ref==feature and p2==0)
   writes[#writes+1]={x,yy,z,api.get_name_from_content_id(cid),ref}
  end
  local function run(x)
   writes={};ctx.min_x=x;ctx.max_x=x;tail.settle(ctx)
   for _,row in ipairs(writes) do if row[5]==index+12 then return row end end
  end
  local found
  for x=0,8191 do found=run(x);if found then break end end
  assert(found,"missing positive case "..case[1])
  records[#records+1]=table.concat(found,"\t")
  local x=found[1]
  protected=true;assert(not run(x),case[1].." protected write");protected=false
  housing=true;assert(not run(x),case[1].." housing write");housing=false
  occupied=1;assert(not run(x),case[1].." occupancy overwrite");occupied=0
  host="default:clay";assert(not run(x),case[1].." wrong support");host=case[4]
  if cave then
   allow_cave=false;assert(not run(x),case[1].." non-native air");allow_cave=true
  else
   level=61;assert(not run(x),case[1].." wrong band");level=case[5]
   if #catalog.plants[index].zones>0 then
    zone="ocean";assert(not run(x),case[1].." wrong zone");zone=case[2]
   end
   if case[7] then shore=nil;assert(not run(x),case[1].." missing shoreline");shore=case[7] end
   if case[1]=="frost_melon" then shore="coastal_shelf";assert(not run(x),"saltwater frost melon");shore=case[7] end
  end
  assert(run(x),case[1].." replay changed")
 end
 -- Seven native rooted sea-bed variants, with actual liquid-family resolver.
 local sea,depth,bed_name,water_name="coastal_shelf",6,"default:sand","default:water_source"
 local denied,reef_writes=false,{}
 local plan={};local tail=config.new({content={content_contract=function() return content.production end},
  full_seed_string="4151598227737528026",zones_session={surface_mob_level_at=function() return 1 end}})
 tail.bind(plan,1)
 local ctx={plan=plan,generation=1,min_y=-12,max_y=0}
 function ctx.inside_owner(x,y,z) return x==ctx.min_x and z==ctx.min_z and y>=ctx.min_y and y<=ctx.max_y end
 function ctx.column_values_at() return sea,1,"ocean","grug_beach","neutral",-depth,0 end
 function ctx.exclusion_at() return denied end
 function ctx.housing_excluded_at() return false end
 function ctx.settled_at(_,y)
  return api.get_content_id(y==-depth and bed_name or water_name),0,0,y==-depth and 1 or 0
 end
 function ctx.production_content(name)
  for ref,value in ipairs(content.production.content_names) do
   if value==name then return ref,api.get_content_id(name) end
  end
  error("missing production name "..name)
 end
 function ctx.write_p9g(x,y,z,cid,p2,ref)
  assert(ctx.inside_owner(x,y,z) and y==-depth)
  assert(ref>=28 and ref<=34)
  if ref==34 then assert(p2==math.min(6,depth-1)*16) else assert(p2==0) end
  reef_writes[#reef_writes+1]={x,y,z,api.get_name_from_content_id(cid),p2,ref}
 end
 local function reef_run(x,z)
  ctx.min_x=x;ctx.max_x=x;ctx.min_z=z;ctx.max_z=z;reef_writes={};tail.settle(ctx)
  return reef_writes[1]
 end
 local found,count={},0
 for z=0,255 do
  for x=0,255 do
   local row=reef_run(x,z)
   if row and not found[row[6]] then found[row[6]]=row;count=count+1 end
   if count==7 then break end
  end
  if count==7 then break end
 end
 assert(count==7,"reef palette absent")
 for ref=28,34 do
  local row=found[ref];records[#records+1]=table.concat(row,"\t")
  local x,z=row[1],row[3]
  sea="planned_water";assert(not reef_run(x,z),"lake reef");sea="coastal_shelf"
  depth=1;assert(not reef_run(x,z),"too shallow");depth=11;assert(not reef_run(x,z),"too deep");depth=6
  denied=true;assert(not reef_run(x,z),"protected reef");denied=false
  water_name="default:river_water_source";assert(not reef_run(x,z),"river liquid reef")
  water_name="default:water_flowing";assert(not reef_run(x,z),"flowing liquid reef")
  water_name="default:water_source"
  if ref==34 then bed_name="default:gravel";assert(not reef_run(x,z),"kelp without sand");bed_name="default:sand" end
  assert(reef_run(x,z),"reef replay changed")
 end

 table.sort(records)
 return "world_plants\t15\nreef_variants\t7\nnegative_boundaries\tPASS\n"..table.concat(records,"\n").."\n"
end
