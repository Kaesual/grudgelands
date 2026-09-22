-- Bounded authored-source audit: six start compositions and six selected plots.
-- No terrain population, complete capital construction or world generation.
return function(repo)
 local defs=dofile(repo.."/mods/PLAYER/grug_home/locations.lua")
 local report={}
 local settlement=dofile(repo.."/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
 -- These shipped nodes are full normal blocks (default/nodes.lua and
 -- grug_decor/darkage.lua); the audit refuses a changed floor material.
 local floors={["default:dirt_with_coniferous_litter"]=true,["default:cobble"]=true,
  ["default:mossycobble"]=true,["default:desert_cobble"]=true,["default:junglewood"]=true,
  ["grug_decor:darkage_slate_tile"]=true,["grug_decor:darkage_basalt_brick"]=true}
 local offsets={{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1},{0,0}}
 for index,row in ipairs(defs) do
  local source=dofile(repo.."/mods/MAPGEN/grug_mapgen/wp40/r7_"..row.id.."_blueprint.lua")()
  local profile
  for _,candidate in ipairs(settlement.roster) do if candidate.key==row.id then profile=candidate end end
  assert(profile and profile.race==row.race)
  local descriptors=settlement.descriptors(profile,source)
  local selected
  local blueprint,id=source,row.socket
  if index>6 then
   local plot_id=row.socket:match("^(.-)/")
   id=row.socket:match("/(.*)$")
   blueprint=nil
   for _,plot in ipairs(source.plots) do
    if plot.id==plot_id then blueprint=plot.build() end
   end
  end
  assert(blueprint,row.id.." home building missing")
  for _,descriptor in ipairs(descriptors) do
   if index<=6 and descriptor.kind=="anchor" or
     descriptor.plot_id==row.socket:match("^(.-)/") then selected=descriptor end
  end
  assert(selected)
  -- Exercise the production terrain-height socket projector with the actual
  -- selected source descriptor/landmarks; unaffected cells are not populated.
  local projected=settlement.sockets({schema="grug_wp13_settlement_prepared_v1",
   profile=profile,blueprints={{descriptor=selected,landmarks=blueprint.landmarks,
    reference=blueprint.reference}}},{x=500,y=100,z=600},function() return 237 end)
  local resolved
  for _,s in ipairs(projected) do if s.id==row.socket then resolved=s end end
  assert(resolved and resolved.y==(index<=6 and 1 or 138),row.id.." terrain height")
  local socket
  for _,s in ipairs(blueprint.landmarks.sockets) do if s.id==id then socket=s end end
  assert(socket and socket.role=="idle" and socket.spawn~=false,row.id.." socket missing")
  local cells={}
  for _,c in ipairs(blueprint.cells) do cells[c.x..","..c.y..","..c.z]=c.name end
  local function at(y) return cells[socket.x..","..y..","..socket.z] end
  assert(at(socket.y-1) and at(socket.y-1)~="air",row.id.." missing floor")
  assert((not at(socket.y) or at(socket.y)=="air") and
   (not at(socket.y+1) or at(socket.y+1)=="air"),row.id.." blocked innkeeper")
  local safe=0
  for offset_index,offset in ipairs(offsets) do
   local x,z=socket.x+offset[1],socket.z+offset[2]
   local floor=cells[x..","..(socket.y-1)..","..z]
   local a,b=cells[x..","..socket.y..","..z],cells[x..","..(socket.y+1)..","..z]
   local clear=floors[floor] and (not a or a=="air") and (not b or b=="air")
   if offset_index==1 then assert(clear,row.id.." canonical arrival blocked") end
   if clear then safe=safe+1 end
  end
  assert(safe>0,row.id.." has no safe arrival candidate")
  report[#report+1]=table.concat({"home-source",row.id,row.socket,socket.x,socket.y,socket.z,safe},"\t")
 end
 return table.concat(report,"\n").."\n"
end
