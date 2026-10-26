-- Every race, camp size and rotation: protected entrances, actor clearance,
-- walking routes, and one lift on the column shared with underground rooms.
local repo=assert(arg[1])
local dir=repo.."/mods/MAPGEN/grug_mapgen/wp40"
local build=dofile(dir.."/r63_camp_blueprint.lua")
local rot=dofile(dir.."/../wp13/plot_approach.lua").rot
local function key(x,y,z) return x..":"..y..":"..z end
local count=0
for _,race in ipairs({"human","dwarf","elf","orc","undead","troll"}) do
 local faction=(race=="human" or race=="dwarf" or race=="elf") and "accord" or "throng"
 for _,kind in ipairs({"mining_camp","pvp_camp_low","pvp_camp_high"}) do
  for turns=0,3 do
   local bp=build({}, {blueprint_schema="test",art={kind=kind,faction=faction,turns=turns,contested=true}},race)
   local cells,lifts,banners={},0,0
   for _,c in ipairs(bp.cells) do
    cells[key(c.x,c.y,c.z)]=c.name
    if c.name=="grug_mapgen:guild_lift" then lifts=lifts+1 end
    if c.name=="grug_mapgen:faction_banner_"..faction then banners=banners+1 end
    assert(c.name~="wool:red" and c.name~="wool:blue","bright faction wool remains")
   end
   assert(lifts==1 and banners==4,"lift or faction banners missing")
   local function clear(x,y,z)
    local n=cells[key(x,y,z)]
    return n=="air" or n=="grug_mapgen:faction_banner_"..faction
   end
   local function stand(x,z) return clear(x,1,z) and clear(x,2,z) and cells[key(x,0,z)]~=nil end
   local r=kind=="pvp_camp_high" and 13 or 11
   local gx,gz=rot(0,-r,turns)
   assert(stand(gx,gz),"gate blocked")
   local queue,seen={{gx,gz}},{[key(gx,1,gz)]=true}
   local at=1
   while queue[at] do
    local p=queue[at];at=at+1
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
     local x,z=p[1]+d[1],p[2]+d[2]
     local k=key(x,1,z)
     if not seen[k] and stand(x,z) then seen[k]=true;queue[#queue+1]={x,z} end
    end
   end
   local by_id={}
   for _,s in ipairs(bp.landmarks.sockets) do by_id[s.id]=s end
   if kind=="pvp_camp_high" then
    local c,w=by_id.captain,by_id.yard_west
    local x,z=2*c.x-w.x,2*c.z-w.z
    local dx,dz=x-c.x,z-c.z
    assert(dx*dx+dz*dz==25 and seen[key(x,1,z)],"commander post blocked or misplaced")
   end
   for _,s in ipairs(bp.landmarks.sockets) do
    if s.role=="lift" then
     local x,z=rot(-1,7,turns)
     assert(s.x==x and s.z==z,"lift column mismatch")
     local fx,fz=rot(-1,6,turns)
     assert(seen[key(fx,1,fz)],"lift approach unreachable")
    else
     assert(seen[key(s.x,1,s.z)],"unreachable socket "..race.." "..kind.." "..s.id)
    end
   end
   for z=-2,2 do for x=-2,2 do for y=1,3 do
    assert(cells[key(x,y,z)]=="air","anchor clearance blocked")
   end end end
   count=count+1
  end
 end
end
print("r63_camps: "..count.." race/kind/rotation combinations reachable")
