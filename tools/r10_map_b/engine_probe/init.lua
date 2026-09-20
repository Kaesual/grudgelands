-- Isolated fresh-world readback; no player/world mutation and no content policy.
local seed="4151598227737528026"
assert(core.get_mapgen_setting("seed")==seed)
local cases={
 {id="dawnmere_field",x=0,z=-2550,r=63},
 {id="dawnmere_wild",x=288,z=-2512,r=39},
 {id="mournfen_wild",x=-1800,z=2070,r=39},
 {id="shattered_wild",x=620,z=140,r=39},
 {id="native_cave",x=0,z=-2400,r=39,low=-208,high=-129},
 {id="native_deep",x=0,z=-2400,r=39,low=-848,high=-769},
}
local rows={"schema\tgrug_r10_map_b_engine_v1","seed\t"..seed}
local held={};local soil={};local index=0
local function record(...) local out={};for i=1,select("#",...) do out[i]=tostring(select(i,...)) end;rows[#rows+1]=table.concat(out,"\t") end
local function save() assert(core.safe_file_write(core.get_worldpath().."/r10-map-b.tsv",table.concat(rows,"\n").."\n")) end
local function finish()
 local wet,dry,started,near=0,0,0,0
 for _,pos in ipairs(soil) do
  local node=core.get_node(pos)
  if node.name=="grug_farming:soil_wet" then wet=wet+1 elseif node.name=="grug_farming:soil" then dry=dry+1 else error("field lost real soil") end
  if core.get_node_timer(pos):is_started() then started=started+1 end
  if core.find_node_near(pos,3,{"group:water"}) then near=near+1;assert(node.name=="grug_farming:soil_wet","near-water soil remained dry") end
 end
 record("soil_activation",#soil,wet,dry,started,near)
 assert(#soil>0 and started==#soil,"VM field soil timers did not activate")
 for _,pos in ipairs(held) do core.forceload_free_block(pos,true) end
 record("complete",#cases);save()
 core.log("action","[R10_MAP_B] COMPLETE")
 core.request_shutdown("MAP-B witness complete",false,0.1)
end
local next_case
local function read_case(case)
 local counts={};local content={}
 for z=case.z-case.r,case.z+case.r do
  for x=case.x-case.r,case.x+case.r do
   local ground=grug_zones.terrain_height_at(x,z)
   local low,high=case.low or ground-3,case.high or ground+5
   for y=low,high do
    local pos={x=x,y=y,z=z};local node=core.get_node(pos)
    assert(node.name~="ignore","probe read unemerged cell")
    if node.name:match("^grug_mapgen:.*_source$") or node.name:match("^default:coral_") or node.name=="default:sand_with_kelp" or node.name=="grug_farming:soil" or node.name=="grug_farming:soil_wet" or node.name=="grug_nodes:ash_ground" or node.name=="grug_nodes:dirt_with_moss" then
     counts[node.name]=(counts[node.name] or 0)+1
     content[#content+1]=x..","..y..","..z..":"..node.name..":"..node.param2
     if node.name=="grug_farming:soil" or node.name=="grug_farming:soil_wet" then
      soil[#soil+1]=pos
     end
    end
   end
  end
 end
 local keys={};for name in pairs(counts) do keys[#keys+1]=name end;table.sort(keys);table.sort(content)
 for _,name in ipairs(keys) do record("count",case.id,name,counts[name]) end
 record("case_digest",case.id,core.sha256(table.concat(content,"\n")))
 if case.id=="dawnmere_field" then
  local blocks,selected={},{}
  local population=#soil
  for _,pos in ipairs(soil) do
   local k=math.floor(pos.x/16)..":"..math.floor(pos.y/16)..":"..math.floor(pos.z/16)
   if not blocks[k] and #held<4 then
    assert(core.forceload_block(pos,true),"field block hold failed")
    blocks[k]=true;held[#held+1]=pos
   end
   if blocks[k] then selected[#selected+1]=pos end
  end
  soil=selected;record("soil_sample",population,#soil,#held)
 end
 save();core.log("action","[R10_MAP_B] read "..case.id)
 next_case()
end
next_case=function()
 index=index+1;local case=cases[index]
 if not case then core.after(22,finish);return end
 local low,high=case.low or 31000,case.high or -31000
 if not case.low then
  for z=case.z-case.r,case.z+case.r do for x=case.x-case.r,case.x+case.r do
   local y=grug_zones.terrain_height_at(x,z);low=math.min(low,y-3);high=math.max(high,y+5)
  end end
 end
 core.emerge_area({x=case.x-case.r,y=low,z=case.z-case.r},{x=case.x+case.r,y=high,z=case.z+case.r},function(_,action,remaining)
  assert(action~=core.EMERGE_CANCELLED and action~=core.EMERGE_ERRORED,"MAP-B emerge failed")
  if remaining==0 then core.after(0,function() read_case(case) end) end
 end)
end
core.register_on_mods_loaded(function() core.after(0,next_case) end)
