-- Independent Round 75 CITY source and authoring-contract audit. LuaJIT only.
local root, city = arg[1], arg[2]
local wp = root .. "/mods/MAPGEN/grug_mapgen/wp40"
local decor = dofile(wp .. "/city_decor.lua")(wp)
local catalog = decor.catalog()
local parts = dofile(wp .. "/../wp13/parts.lua")
local expected = {
 alchemy={7,25,0},archive={1,2,0},armoury={5,15,0},barracks={7,14,0},boat={2,2,0},brew={3,4,1},butcher={2,4,0},candle={5,0,5},carver={14,22,3},colonnade={12,0,12},command={11,22,0},council={8,14,0},drill={11,0,11},embalmer={1,2,0},fish={4,6,2},garden={22,5,17},gate={19,0,19},green={60,0,60},guild={6,18,0},home={95,272,0},jewel={6,16,0},kitchen={10,20,3},leather={7,23,0},library={3,9,0},market={9,17,0},royal={6,24,0},ruin={7,0,7},scribe={5,10,0},shelter={7,6,1},shrine={21,12,9},smith={15,35,3},stable={13,13,0},statue={7,0,7},store={20,40,0},tailor={7,25,0},tavern={8,24,0},watch={23,37,0},well={15,15,0},workshop={13,14,2},yard={18,3,15},

}
local walls={herb_bundle=true,tool_board=true,oar=true,sconce_iron=true,sconce_wood=true,wall_shelf=true,wall_shelf_filled=true,tapestry_accord=true,tapestry_throng=true}
local tables={["grug_decor:xdecor_table"]=true,["grug_decor:cottages_table"]=true}
-- Independently reviewed full-cube top supports produced by the finished
-- builders. Stairs, slabs, fences, plants and furniture are intentionally
-- absent; a changed support must be reviewed before this list changes.
local floor_supports={
 -- 0.75.5 special structures: verified normal full cubes in the engine dump.
 ["default:stone_block"]=true,["default:silver_sandstone_block"]=true,
 ["default:desert_sandstone"]=true, -- 0.75.5: unchanged props on the approved flat roof.
 ["default:acacia_wood"]=true,["default:brick"]=true,["default:cobble"]=true,
 ["default:desert_cobble"]=true,["default:desert_stone_block"]=true,
 ["default:desert_stonebrick"]=true,["default:dirt_with_coniferous_litter"]=true,
 ["default:dirt_with_dry_grass"]=true,["default:dirt_with_grass"]=true,
 ["default:dirt_with_rainforest_litter"]=true,["default:junglewood"]=true,
 ["default:mossycobble"]=true,["default:obsidianbrick"]=true,
 ["default:pine_wood"]=true,["default:silver_sandstone_brick"]=true,
 ["default:stonebrick"]=true,["default:wood"]=true,
 ["grug_decor:castle_dungeon_stone"]=true,
 ["grug_decor:castle_pavement_brick"]=true,["grug_decor:castle_stonewall"]=true,
 ["grug_decor:cottages_straw_ground"]=true,
 ["grug_decor:darkage_basalt_brick"]=true,
 ["grug_decor:darkage_serpentine"]=true,["grug_decor:darkage_slate_tile"]=true,
 ["grug_nodes:blight_dirt"]=true,["grug_nodes:dirt_with_silver_litter"]=true,
}
local quiet={statue=true,gate=true,ruin=true,green=true,colonnade=true,drill=true}
local counts,seen,targets={},{},{}
local rows,placements,zero=0,0,0
for _,scopes in pairs(catalog) do for _,entries in pairs(scopes) do for _,row in ipairs(entries) do
 assert(type(row.profile)=="string" and expected[row.profile],row.id..": unknown profile")
 assert(not seen[row.id],"duplicate catalog id "..row.id); seen[row.id]=true
 rows=rows+1; placements=placements+#row.placements
 if #row.placements==0 then zero=zero+1; assert(type(row.reason)=="string",row.id..": silent omission") end
 local c=counts[row.profile] or {0,0,0}; counts[row.profile]=c; c[1]=c[1]+1;c[2]=c[2]+#row.placements;if #row.placements==0 then c[3]=c[3]+1 end
 assert(not quiet[row.profile] or #row.placements==0,row.id..": quiet profile decorated")
 local painting,displays=0,0
 for _,p in ipairs(row.placements) do
  local suffix=assert(p.node:match("^grug_decor:city_(.+)$"),row.id..": non-city node")
  assert(parts.param2_kind(p.node)==parts.FACEDIR,
   row.id..": city clone has no facedir rotation contract")
  local key=row.id.."/"..p.x..":"..p.y..":"..p.z;assert(not targets[key],row.id..": duplicate target");targets[key]=true
  local wall=walls[suffix] or suffix:match("^painting_")
  if wall then
   assert(p.support_dy==0 and math.abs(p.support_dx)+math.abs(p.support_dz)==1,row.id..": wall mount differs")
   assert(not p.support:find("barrel",1,true) and not p.support:find("cauldron",1,true) and
    not p.support:find("shelf",1,true) and not p.support:find("stair",1,true) and
    not p.support:find("slab",1,true) and not p.support:find("leaves",1,true) and
    not p.support:find("wool",1,true) and not p.support:find("straw",1,true) and
    not p.support:find("dirt",1,true) and not p.support:find("litter",1,true),
    row.id..": wall support family differs")
  else
   assert(p.support_dx==0 and p.support_dz==0 and p.support_dy==-1,row.id..": floor/table mount differs")
   assert(tables[p.support] or floor_supports[p.support],row.id..": floor support lacks a full top face")
  end
  if tables[p.support] then assert(not wall,row.id..": wall detail on table") end
  if suffix:match("^painting_") then painting=painting+1 end
  if suffix=="display_armor" or suffix=="display_weapon" then displays=displays+1 end
 end
 if row.profile=="royal" then
  assert(#row.placements==4 and painting==3 and displays==0,
   row.id..": royal wall-only focal set differs")
 end
 if row.profile=="barracks" or row.profile=="armoury" then assert(displays>=2,row.id..": martial displays missing") end
 if row.profile=="well" then for _,p in ipairs(row.placements) do assert(p.node=="grug_decor:city_cottages_bench",row.id..": well family") end end
 if row.profile=="garden" then for _,p in ipairs(row.placements) do assert(p.node=="grug_decor:city_fruit_basket",row.id..": garden family") end end
 if row.profile=="shelter" then for _,p in ipairs(row.placements) do assert(p.node=="grug_decor:city_wicker_basket",row.id..": shelter family") end end
end end end
assert(rows==515 and placements==770 and zero==177,"CITY exact totals differ")
for profile,want in pairs(expected) do local got=assert(counts[profile],"missing profile "..profile);for i=1,3 do assert(got[i]==want[i],profile..": exact count differs") end end
local caps=dofile(wp.."/r7_capital_blueprint.lua")
if caps.CAPITALS[city] then local kit=caps.kit(city);decor.apply(city,"core",kit.core.build(),true);for _,plot in ipairs(kit.plots) do decor.apply(city,plot.id,plot.build(),true) end
else local settlement=dofile(wp.."/r7_settlement.lua");local profile;for _,candidate in ipairs(settlement.roster) do if candidate.key==city then profile=candidate break end end;assert(profile,"unknown CITY settlement "..tostring(city));local build=dofile(wp.."/"..profile.blueprint_file);decor.apply(city,"blueprint",profile.art and build({},profile) or build(),true) end
io.write(city.."\t"..rows.."\t"..placements.."\n")
