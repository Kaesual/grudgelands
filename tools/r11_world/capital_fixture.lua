-- Focused real service plots and protected product definitions, no full city.
return function(repo)
 local dir=repo..'/mods/MAPGEN/grug_mapgen/wp13'
 local services=dofile(dir..'/capital_services.lua')
 local parts=dofile(dir..'/parts.lua')
 local station_ok=dofile(repo..'/tools/r10_cap/public_socket_oracle.lua')
 local function key(x,y,z)return x..':'..y..':'..z end
 local definitions={}
 local env=setmetatable({core={register_node=function(name,def)
  assert(not definitions[name]);definitions[name]=def
 end}},{__index=_G})
 local register=assert(loadfile(repo..'/mods/ITEMS/grug_decor/capital.lua'))
 setfenv(register,env);register()
 local products=0
 for name,def in pairs(definitions) do
  if name:find('capital_product_',1,true) then
   products=products+1
   assert(def.diggable==false and def.drop=='' and def.can_dig()==false)
   assert(def.allow_metadata_inventory_put()==0 and def.allow_metadata_inventory_take()==0)
   assert(def.allow_metadata_inventory_move()==0 and #def.on_blast()==0)
   assert(def.on_dig()==nil and def.on_punch()==nil and def.on_rightclick()==nil)
   assert(parts.param2_kind(name)==parts.FACEDIR and def.paramtype2=='facedir')
   assert(def.tiles[6]:find('.png',1,true),'missing product face')
  end
 end
 assert(products==8)
 local output={}
 for _,city in ipairs({'highcourt','dur_brannoc','lethariel','nhal_veyr','gor_drazhak','kezamba'})do
  local districts=dofile(dir..'/'..city..'_districts.lua')(dir)
  local plots,frames=0,0
  for _,plot in ipairs(districts.resolve())do
   local service=services.service(city,plot.id)
   if service then
    plots=plots+1
    local bp=plot.build();local cells={};local sockets={};local plaques=0
    for _,cell in ipairs(bp.cells)do
     cells[key(cell.x,cell.y,cell.z)]=cell
     if cell.name:find('grug_decor:capital_product_',1,true)then
      assert(definitions[cell.name]);plaques=plaques+1
      local suffix=cell.name:match('capital_product_(.+)')
      assert(suffix==service or service=='forge' and
       (suffix=='weaponsmith' or suffix=='armorsmith'))
     end
    end
    for _,socket in ipairs(bp.landmarks.sockets)do
     sockets[socket.id]=socket
     local cell=assert(cells[key(socket.x,socket.y,socket.z)])
     if socket.role=='public_station' then assert(station_ok(socket,cell.name))
     elseif socket.role~='gear_display' then
      assert(cell.name=='air',city..' '..socket.id..' feet blocked')
      assert(cells[key(socket.x,socket.y+1,socket.z)].name=='air',socket.id..' head blocked')
      assert(cells[key(socket.x,socket.y-1,socket.z)].name~='air',socket.id..' unsupported')
     end
    end
    if service=='riding' then
     assert(plaques==0)
     local posts=0
     for z=-8,8 do for x=-10,10 do
      assert(cells[key(x,0,z)].name=='default:dirt','shelter earth floor')
      assert(cells[key(x,6,z)].name~='air','shelter roof')
      local post=cells[key(x,3,z)].name~='air'
      local expected=(x==-10 or x==10) and (z==-8 or z==0 or z==8)
      assert(post==expected,city..' six-post geometry '..x..','..z..' '..cells[key(x,3,z)].name)
      if post then posts=posts+1 end
      if not expected then
       assert(cells[key(x,2,z)].name=='air','open shelter walls')
      end
      if (x==-10 or x==10 or z==8 or z==-8 and math.abs(x)>2)then
       assert(cells[key(x,1,z)].name~='air','one-node fence')
      end
     end end
     assert(posts==6)
     for tier=1,4 do
      local id=plot.id..'_mount_'..tier
      local rest=assert(sockets[id]);assert(rest.tags[1]==tostring(tier))
      if tier<=2 then
       for _,end_id in ipairs({'a','b'}) do
        local point=assert(sockets[id..'_walk_'..end_id])
        assert(point.role=='idle' and point.spawn==false and point.y==rest.y)
        local expected=end_id=="b" and -2 or city=="kezamba" and tier==2 and -3 or -4
        assert(point.x==rest.x and point.z==expected)
       end
      else assert(not sockets[id..'_walk_a']) end
     end
    else
     assert(plaques==2,city..' '..service..' exterior/interior product count')
     frames=frames+(service=='forge' and 2 or 1)
    end
    output[#output+1]=city..'\t'..service..'\t'..#bp.cells..'\t'..plaques
   end
  end
  assert(plots==8 and frames==8)
 end
 table.sort(output)
 return 'R11 CAP PASS: 48 real service plots, 6 open shelters, 24 mounts, 24 authored ground endpoints, 48 exterior product frames; 8 protected product definitions\n'..table.concat(output,'\n')..'\n'
end
