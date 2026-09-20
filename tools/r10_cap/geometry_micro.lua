-- Bounded real plot/service construction; full cities remain LuaJIT-only.
return function(repo)
 local dir=repo.."/mods/MAPGEN/grug_mapgen/wp13"
 local services=dofile(dir.."/capital_services.lua")
 local parts=dofile(dir.."/parts.lua")
 local out={}
 for _,city in ipairs({"highcourt","dur_brannoc","lethariel","nhal_veyr","gor_drazhak","kezamba"}) do
  local districts=dofile(dir.."/"..city.."_districts.lua")(dir)
  local built=0
  for _,row in ipairs(districts.resolve()) do
   local service=services.service(city,row.id)
   if service=="forge" or (city=="highcourt" and service=="riding") then
    local bp=row.build();local cells={};local trainers,stations,mounts,riding=0,0,0,0
    for _,cell in ipairs(bp.cells) do cells[cell.x..":"..cell.y..":"..cell.z]=cell end
    for _,socket in ipairs(bp.landmarks.sockets) do
     local key=socket.x..":"..socket.y..":"..socket.z
     if socket.role=="public_station" then
      stations=stations+1
      assert(cells[key].name=="grug_jobs:forge")
      assert(parts.param2_kind(cells[key].name)==parts.FACEDIR)
     elseif socket.role=="trainer" then
      assert(socket.profession=="weaponsmith" or socket.profession=="armorsmith")
      trainers=trainers+1;assert(cells[key].name=="air")
     elseif socket.role=="mount_display" then
      mounts=mounts+1;assert(cells[key].name=="air")
     elseif socket.role=="riding_trainer" then
      riding=riding+1;assert(cells[key].name=="air")
     end
    end
    if service=="forge" then assert(stations==1 and trainers==2)
    else assert(mounts==4 and riding==1 and cells["0:3:6"].name~="air") end
    out[#out+1]=table.concat({city,service,#bp.cells,trainers,stations,mounts,riding},"\t")
    built=built+1
   end
  end
  assert(built==(city=="highcourt" and 2 or 1))
 end
 for _,name in ipairs({"default:furnace","grug_brewing:brewing_stand","grug_jobs:forge",
  "grug_jobs:tailor_bench","grug_jobs:tanning_rack","grug_jobs:carving_bench","grug_jobs:jewellers_bench"}) do
  assert(parts.param2_kind(name)==parts.FACEDIR)
 end
 assert(parts.full_solid("default:furnace"))
 table.sort(out)
 return "CAP geometry micro PASS\n"..table.concat(out,"\n").."\n"
end
