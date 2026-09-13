-- LuaJIT development witness over actual height construction and exact shore neighbors.
local repo, production, out = assert(arg[1]), assert(arg[2]), assert(arg[3])
local seed = arg[4] or '531802985935182545'
local wp=production..'/mods/MAPGEN/grug_mapgen/wp40/'
local sha=dofile(repo..'/tools/wp40/r6/common.lua').new_sha256()
local source=dofile(wp..'source/simple_map.lua')
local canonical,det=dofile(wp..'canonical.lua'),dofile(wp..'deterministic.lua')
local h=dofile(wp..'simple_map.lua')({source=source,schemas=dofile(wp..'schemas.lua'),canonical=canonical,deterministic=det,raw_sha256=sha}).new(seed)
local height=dofile(wp..'height.lua')({source=source,canonical=canonical,deterministic=det,raw_sha256=sha,horizontal_session=h,coupled_grade=dofile(wp..'coupled_grade.lua')()}).new_runtime_checked(seed)
local f=assert(io.open(out,'w'))
f:write('x\tz\ty\twater\tclass\tkind\tfeature\tneighbor_x\tneighbor_z\tneighbor_y\n')
local count=0
for z=1300,1700 do for x=1600,2050 do
 local water=height.water_surface_at(x,z)
 if water and h.water_class_at(x,z)=='planned_water' then
  local y=height.terrain_height_at(x,z)
  if water>y then
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
    local nx,nz=x+d[1],z+d[2]
    if h.water_class_at(nx,nz)=='land' then
     local ny=height.terrain_height_at(nx,nz)
     if ny<water then
      local kind,sy,feature=height.functional_surface_values_at(nx,nz)
      f:write(x,'\t',z,'\t',y,'\t',water,'\t',h.water_class_at(x,z),'\t',kind or '-','\t',feature or '-','\t',nx,'\t',nz,'\t',ny,'\n'); count=count+1
     end
    end
   end
  end
 end
end end
f:close();print('Leak boundary count',count)
if arg[5] == 'sealed' then assert(count == 0, 'uncontained Kezamba shore') end
