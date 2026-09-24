-- Service rooms reuse existing terrain-relative plots and their street access.
-- Runtime consumers receive authored sockets, never trainer-relative offsets.
local M = {}
M.PLOTS = {
 highcourt = {riding="market_stable", forge="market_workshop",
  tailor="market_counting_house", alchemist="lore_herb_garden",
  cooking="homes_bakehouse", leatherworker="market_store",
  woodcarver="martial_wain_shed", goldsmith="lore_archive"},
 dur_brannoc = {riding="forge_pack_stable", forge="forge_smithy",
  tailor="forge_guild_house", alchemist="terrace_brewhouse",
  cooking="terrace_bakehouse", leatherworker="forge_store",
  woodcarver="deep_carvers", goldsmith="forge_ore_yard"},
 lethariel = {riding="market_stable", forge="martial_armoury",
  tailor="market_weaver", alchemist="homes_brewhouse",
  cooking="market_bakehouse", leatherworker="martial_store",
  woodcarver="market_bowyer", goldsmith="mere_lore_hall"},
 nhal_veyr = {riding="market_cart_yard", forge="market_bonesmith",
  tailor="market_shroud_house", alchemist="market_physic",
  cooking="homes_mourners_hall", leatherworker="market_charnel",
  woodcarver="vigil_candle_works", goldsmith="market_bone_store"},
 gor_drazhak = {riding="war_beast_pen", forge="bazaar_smithy",
  tailor="warren_weaver", alchemist="bone_herb_house",
  cooking="warren_cook_court", leatherworker="bazaar_tannery",
  woodcarver="bazaar_carver", goldsmith="bazaar_armourer"},
 kezamba = {riding="canopy_stable", forge="canopy_armoury",
  tailor="shore_tailor", alchemist="vine_herbalist",
  cooking="shore_smokehouse", leatherworker="shore_store",
  woodcarver="shore_carvers", goldsmith="totem_scriptorium"},
}
local STATIONS = {forge="grug_jobs:forge", tailor="grug_jobs:tailor_bench",
 alchemist="grug_brewing:brewing_stand", leatherworker="grug_jobs:tanning_rack",
 woodcarver="grug_jobs:carving_bench", goldsmith="grug_jobs:jewellers_bench",
 cooking="default:furnace"}
local STATION_IDS = {forge="forge", tailor="tailor_bench",
 alchemist="brewing_stand", leatherworker="tanning_rack",
 woodcarver="carving_bench", goldsmith="jewellers_bench", cooking="furnace"}

function M.service(city, plot)
 for service, id in pairs(assert(M.PLOTS[city])) do
  if id == plot then return service end
 end
end

function M.decorate(city, plot, buf, palette, sockets, area)
 local service=M.service(city,plot)
 if not service then return end
 local function socket(id,role,x,y,z,extra)
  local s={id=plot.."_"..id,role=role,x=x,y=y,z=z,face=2,dir={x=0,z=-1}}
  for k,v in pairs(extra or {}) do s[k]=v end
  sockets[#sockets+1]=s
 end
 local function decor(x,y,z,name)
  buf:put(x,y,z,"grug_decor:capital_"..name)
 end
 if service=="riding" then
  -- Shared open shelter: no divider or trough intrudes into movement lanes.
  local positions={{-5,-3},{5,-3},{-5,3},{5,3}}
  for tier,p in ipairs(positions) do
   socket("mount_"..tier,"mount_display",p[1],1,p[2],{tags={tostring(tier)}})
   if tier<=2 then
    local front=city=="kezamba" and tier==2 and -3 or -4
    for _,endpoint in ipairs({{"a",front},{"b",-2}}) do
     socket("mount_"..tier.."_walk_"..endpoint[1],"idle",p[1],1,endpoint[2],
      {spawn=false,tags={"mount_walk"}})
    end
   end
  end
  local resident=0
  for _,s in ipairs(sockets) do
   if s.role=="idle" and s.spawn~=false then
    resident=resident+1;s.x=resident==1 and -8 or 8;s.y=1;s.z=-6
   end
  end
  socket("riding","riding_trainer",0,1,-6)
  return
 end
 -- Free-standing exterior product frames sit beside the central approach.
 -- The plot supplies its actual front boundary; no house-relative guess.
 local products=service=="forge" and {"weaponsmith","armorsmith"} or {service}
 for index,profession in ipairs(products) do
  local x=#products==2 and (index==1 and -3 or 3) or 3
  local z=assert(area,"capital product frame needs plot bounds").z0+1
  for _,post_x in ipairs({x-1,x+1}) do
   buf:fill(post_x,1,z,post_x,3,z,palette.node("post"))
  end
  buf:put(x,3,z,palette.node("post"))
  local display=profession
  if profession=="leatherworker" then display="leatherworker_exterior" end
  decor(x,2,z,"product_"..display)
 end
 -- Existing wall/roof silhouettes and vendor shopfronts remain. The bounded
 -- central room is furnished for its actual service; side aisles stay open.
 buf:clear(-3,1,-3,3,3,3)
 if city=="highcourt" and service=="alchemist" then
  -- Reuse the garden canopy, with its original diagonal supports grounded.
  for y=1,3 do
   buf:put(-1,y,-1,palette.node("post"))
   buf:put(1,y,1,palette.node("post"))
  end
 end
 if city=="gor_drazhak" and service=="cooking" then
  -- Keep the existing cook-counter worker facing a real counter.
  decor(-2,1,-3,"counter")
 end

 buf:put(0,1,1,STATIONS[service])
 socket("station","public_station",0,1,1,{tags={STATION_IDS[service]}})
 if service~="forge" then
  decor(3,1,3,"counter")
  decor(3,2,3,"product_"..service)
 end
 if service=="forge" then
  socket("weaponsmith","trainer",-2,1,-1,{profession="weaponsmith"})
  socket("armorsmith","trainer",2,1,-1,{profession="armorsmith"})
  decor(-3,1,2,"anvil");decor(3,1,2,"quench")
  decor(0,1,3,"lava")
  decor(-3,1,3,"counter");decor(3,1,3,"counter")
  socket("weapon","gear_display",-3,2,3,{tags={"weapon"}})
  socket("armor","gear_display",3,2,3,{tags={"armor"}})
 else
  socket(service,"trainer",-2,1,-1,{profession=service})
  if service=="tailor" then
   decor(-3,1,2,"loom");decor(3,1,2,"cloth")
  elseif service=="alchemist" then
   decor(-3,1,2,"herbs");decor(3,1,2,"herbs")
  elseif service=="leatherworker" then
   decor(-3,1,2,"hides");decor(3,1,2,"quench")
  elseif service=="woodcarver" then
   decor(-3,1,2,"timber");decor(3,1,2,"carving")
  elseif service=="goldsmith" then
   decor(-3,1,2,"case");decor(3,1,2,"case")
   socket("jewel","gear_display",3,2,2,{tags={"jewel"}})
  elseif service=="cooking" then
   decor(-3,1,2,"counter");decor(3,1,2,"counter")
   -- The quest cook is a separate person opposite the existing trainer.
   socket("quest_cook","quest",2,1,-1)
  end
 end
end
return M
