-- Isolated native integration probe; no production definitions are replaced.
local wp = core.get_modpath("grug_mapgen") .. "/wp40"
local rows = dofile(wp .. "/r7_settlement.lua").roster
local selected, completed = {}, 0
local function log(s) core.log("action", "[r14_integration] " .. s) end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function check(row)
 local a, source = row.record.anchor, row.source
 local checked=0
 for _,cell in ipairs(source.cells) do
  if not (row.profile.reserve_anchor_root and cell.x==0 and cell.y==1 and cell.z==0) then
   local p={x=a.x+cell.x,y=a.y+cell.y,z=a.z+cell.z}
   local node=core.get_node(p)
   assert(node.name==cell.name, row.profile.key.." "..core.pos_to_string(p).." expected="..cell.name.." actual="..node.name)
   local def=core.registered_nodes[node.name]
   if def and (def.paramtype2=="facedir" or def.paramtype2=="wallmounted" or def.paramtype2=="4dir") then
    assert(node.param2==cell.param2,"orientation differs at "..core.pos_to_string(p))
   end
   checked=checked+1
  end
 end
 local root=core.get_node({x=a.x,y=a.y+1,z=a.z}).name
 if row.profile.reserve_anchor_root then
  assert(root==(row.profile.slot=="bandit_1" and "grug_nodes:camp_fire" or "grug_nodes:guard_banner"), "lost functional root: "..root)
 end
 for _,socket in ipairs(grug_core.settlement_sockets_at(row.profile.key)) do
  assert(core.get_node(socket.pos).name=="air", "blocked socket "..socket.id)
  assert(core.get_node({x=socket.pos.x,y=socket.pos.y-1,z=socket.pos.z}).name~="air", "unsupported socket")
 end
 log("cells PASS key="..row.profile.key.." checked="..checked.." root="..root.." anchor="..core.pos_to_string(a))
end
core.register_on_mods_loaded(function()
 grug_quests.validate_registry()
 assert(count(grug_quests.registered_quests)==66 and count(grug_quests.registered_npcs)==24)
 log("catalog PASS quests=66 npcs=24 manifest="..grug_mapgen.wp40.manifest_sha256)
 local records={}
 for _,record in ipairs(grug_core.settlement_socket_settlements()) do records[record.key]=record end
 local geometry=core.get_mapgen_chunksize()
 local kinds={}
 for _,profile in ipairs(rows) do
  local kind=profile.slot
  if (kind=="village_1" or kind=="outpost_1" or kind=="bandit_1") and not kinds[kind] and records[profile.key] then
   local source=dofile(wp.."/"..profile.blueprint_file)()
   local a=records[profile.key].anchor
   local lo,hi={},{}
   for _,axis in ipairs({"x","y","z"}) do
    local width=geometry[axis]*16
    local origin=-math.floor(geometry[axis]/2)*16
    lo[axis]=math.floor((a[axis]-origin)/width)*width+origin
    hi[axis]=lo[axis]+width-1
   end
   local fits=true
   for _,cell in ipairs(source.cells) do
    for _,axis in ipairs({"x","y","z"}) do
     local v=a[axis]+cell[axis]
     if v<lo[axis] or v>hi[axis] then fits=false end
    end
   end
   if fits then
    kinds[kind]=true
    selected[#selected+1]={profile=profile,record=records[profile.key],source=source,lo=lo,hi=hi}
   end
  end
 end
 assert(#selected==3,"need three fully contained POI chunks")
 core.after(0,function()
  for _,row in ipairs(selected) do
   log("emerge key="..row.profile.key.." min="..core.pos_to_string(row.lo).." max="..core.pos_to_string(row.hi))
   core.emerge_area(row.lo,row.hi,function(_,action,left)
    assert(action==core.EMERGE_GENERATED or action==core.EMERGE_FROM_MEMORY or action==core.EMERGE_FROM_DISK)
    if left==0 then
     core.after(0,function()
      core.load_area(row.lo,row.hi)
      check(row)
      for _,s in ipairs(grug_core.settlement_sockets_at(row.profile.key)) do core.forceload_block(s.pos,true) end
      completed=completed+1
      if completed==3 then core.after(6,function()
       local census={}
       for _,r in ipairs(grug_mobs.start_npc_census()) do census[r.key]=r end
       for _,r in ipairs(selected) do
        local c=assert(census[r.profile.key])
        assert(c.live==c.roster and c.roster>0,"NPC roster not live: "..r.profile.key.." "..c.live.."/"..c.roster)
        local quest_found=false
        for _,obj in ipairs(core.get_objects_inside_radius(r.record.anchor,35)) do
         local entity=obj:get_luaentity()
         if entity and entity._grug_start==r.profile.key then
          local id=grug_quests.npc_by_socket[r.profile.key.."/"..tostring(entity._grug_socket)]
          if id then
           assert(entity._grug_npc_name==grug_quests.registered_npcs[id].title,"NPC title differs")
           quest_found=true
          end
         end
        end
        assert(quest_found,"quest NPC missing")
        log("NPC PASS key="..r.profile.key.." live="..c.live.." roster="..c.roster)
       end
       log("PASS three_chunks=3 catalog=66/24")
       core.request_shutdown("bounded Round 14 integration complete",false,0)
      end) end
     end)
    end
   end)
  end
 end)
end)
core.after(110,function() error("Round 14 integration deadline") end)
