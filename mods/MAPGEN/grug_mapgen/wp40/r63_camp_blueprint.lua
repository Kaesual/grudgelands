-- The approved mining outpost, shared by guild and Battlegrounds camps.
-- Geometry and placement markers are ordinary building templates; gameplay
-- socket identities stay stable across the visual replacement.
local info = debug and debug.getinfo and debug.getinfo(1, "S")
local directory = info and info.source:sub(1,1)=="@" and info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not directory then directory=core.get_modpath("grug_mapgen").."/wp40" end
local wp13=directory.."/../wp13"
local parts=dofile(wp13.."/parts.lua")
local templates=dofile(wp13.."/templates.lua")(wp13)
local palettes=dofile(wp13.."/palette.lua")
local rot=dofile(wp13.."/plot_approach.lua").rot
local catalog=dofile(directory.."/r58_camp_catalog.lua")
local faction_of={human="accord",dwarf="accord",elf="accord",orc="throng",undead="throng",troll="throng"}
local cache={}
local function template(race,high)
 local name="mining_camp_"..race..(high and "_large" or "")
 if not cache[name] then
  local path=templates.ROOT.."/templates/"..name..".tpl"
  local t=templates.parse_template(templates.read(path),path,name)
  local palette=palettes.new(race)
  cache[name]=templates.part(t,name,race,function() return palette end)
 end
 return cache[name]
end
return function(_,profile,race)
 local art=profile.art
 assert(faction_of[race]==art.faction,"Camp race differs from faction")
 local lift=assert(catalog.LIFT[art.kind],"Unknown mining camp kind")
 local high=art.kind=="pvp_camp_high"
 local war=art.kind~="mining_camp"
 local turns=art.turns or 0
 assert(turns%1==0 and turns>=0 and turns<=3,"Camp turns differ")
 local r=high and 13 or 11
 local part=template(race,high)
 local markers={}
 for _,point in ipairs(part.points.camp_points) do markers[point.id]=point end
 assert(markers.lift.x==lift.x and markers.lift.z==lift.z,"Camp lift column differs")
 local cells,names={},{}
 for _,cell in ipairs(part.buffer:cells()) do
  local x,z=rot(cell.x,cell.z,turns)
  cells[#cells+1]={x=x,y=cell.y,z=z,name=cell.name,
   param2=parts.rotate_param2(cell.param2,parts.param2_kind(cell.name),turns)}
  names[cell.name]=true
 end
 parts.sort_cells_zyx(cells)
 local palette={}
 for name in pairs(names) do palette[#palette+1]=name end
 table.sort(palette,parts.less_bytes)
 local sockets={}
 local function socket(id,role,dx,dz,extra)
  local p=assert(markers[id],"Missing camp marker "..id)
  local x,z=rot(p.x,p.z,turns)
  dx,dz=rot(dx,dz,turns)
  local s={id=id,role=role,x=x,y=p.y,z=z,dir={x=dx,z=dz}}
  for k,v in pairs(extra or {}) do s[k]=v end
  sockets[#sockets+1]=s
 end
 socket("gate_west","guard_post",1,0,{tags={"gate"}})
 socket("gate_east","guard_post",-1,0,{tags={"gate"}})
 if high then
  socket("tower_west","guard_post",0,1,{tags={"camp"}})
  socket("tower_east","guard_post",-1,0,{tags={"camp"}})
 end
 if war or art.contested then
  socket("yard_west","guard_post",0,-1,{tags={"camp"}})
  if not high then socket("yard_east","guard_post",0,-1,{tags={"camp"}}) end
 end
 if war then socket("captain","captain",0,-1) end
 socket("lift","lift",0,-1)
 socket("quest_foreman","quest",0,-1)
 socket("vendor_camp","vendor",-1,0,{kind="camp"})
 if not war then socket("held_load","quest_place",-1,0) end
 local structures={}
 for _,b in ipairs({{"stockade",0,0,r,r,6,"palisade"},
  {"lift headframe",-1,7,2,2,16,"lift"},
  {"foreman's tent",-7,5,2,3,4,"foreman"},
  {"shelter",-7,-5,2,2,4,"shelter"},
  {"vendor's stall",7,-4,2,2,4,"stall"}}) do
  local x,z=rot(b[2],b[3],turns)
  local w,d=b[4],b[5]
  if turns%2==1 then w,d=d,w end
  structures[#structures+1]={label=b[1],x=x,z=z,w=w,d=d,h=b[6],kind=b[7]}
 end
 return {schema=profile.blueprint_schema,palette=palette,cells=cells,
  bounds={min={x=-r,y=0,z=-r},max={x=r,y=16,z=r}},clear_to=16,
  landmarks={structures=structures,sockets=sockets,arrival={x=0,y=1,z=0},race=race,faction=art.faction}}
end
