-- LuaJIT-only full building export for offline native textured rendering.
local repo=assert(arg[1])
local dir=repo..'/mods/MAPGEN/grug_mapgen/wp13'
local services=dofile(dir..'/capital_services.lua')
for _,city in ipairs({'highcourt','dur_brannoc','lethariel','nhal_veyr','gor_drazhak','kezamba'}) do
 local districts=dofile(dir..'/'..city..'_districts.lua')(dir)
 for _,row in ipairs(districts.resolve()) do
  if services.service(city,row.id)=='riding' or (arg[2]=='all' and services.service(city,row.id)) then
   local key=arg[2]=='all' and (city..'/'..services.service(city,row.id)) or city
   local blueprint=row.build()
   for _,cell in ipairs(blueprint.cells) do
    if cell.name~='air' then
     print(key,'cell',cell.x,cell.y,cell.z,cell.name,cell.param2 or 0)
    end
   end
   for _,socket in ipairs(blueprint.landmarks.sockets) do
    print(key,'socket',socket.x,socket.y,socket.z,socket.role,
     socket.tags and socket.tags[1] or '-',socket.id)
   end
  end
 end
end
