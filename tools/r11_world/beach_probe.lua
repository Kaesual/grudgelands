-- Bounded diagnostic on real source and runtime constructors; no engine or VM.
local repo=assert(arg[1])
local dir=repo..'/mods/MAPGEN/grug_mapgen/wp40'
local common=dofile(repo..'/tools/wp40/r6/common.lua')
local deps={source=dofile(dir..'/source/simple_map.lua'),
 canonical=dofile(dir..'/canonical.lua'),deterministic=dofile(dir..'/deterministic.lua'),
 schemas=dofile(dir..'/schemas.lua'),raw_sha256=common.new_sha256()}
local seed='15140735923413111218'
local radius=tonumber(arg[2]) or 6
assert(radius>=0 and radius<=48)
local horizontal=dofile(dir..'/simple_map.lua')(deps).new(seed)
deps.horizontal_session=horizontal
deps.coupled_grade=dofile(dir..'/coupled_grade.lua')()
-- Read-only instrumentation exports the pre-composition value from its exact
-- lexical production closure. It changes no calculation, predicate or writer.
local bytes=common.read_file(dir..'/height.lua')
local marker='function session.coast_profile_at(x, z)'
local injected=[[function session.r11_incoming(x,z)
 return derived_water_evidence.r11_incoming(x,z)
end
]]..marker
local changed,n=bytes:gsub('function session%.coast_profile_at%(x, z%)',function()return injected end)
assert(n==2,'height diagnostic seam changed')
changed=changed:gsub('derived_water_evidence%.coast_profile_at = function',function() return [[derived_water_evidence.r11_incoming = function(x,z)
 local class,_,owner,bay,water=classified_values(x,z)
 return scalar_before_nonpath_grades(x,z,class,owner,bay,water)
end
derived_water_evidence.coast_profile_at = function]] end)
if arg[3]=='cardinal' then
 local old='best_distance, orientation, water_y, freshwater = lattice_shore_at(x, z)'
 local replacement=old..[[
 if best_distance then
  local nearest_cardinal
  for direction=1,4 do
   for distance=17,52 do
    if nearest_cardinal and distance>=nearest_cardinal then break end
    local class,_,_,bay_id,hydrology_id=classified_values(
     x+direction_x[direction]*distance,z+direction_z[direction]*distance)
    if class~="land" then
     local level=pregrade_water_surface_at(x+direction_x[direction]*distance,
      z+direction_z[direction]*distance,class,bay_id,hydrology_id)
     if level~=nil then orientation=direction;nearest_cardinal=distance end
     break
    end
   end
  end
 end]]
 local count
 changed,count=changed:gsub(old:gsub('([%(%)%.])','%%%1'),function()return replacement end)
 assert(count==1,'coast fallback diagnostic seam changed')
end
local height=assert(loadstring(changed,'@'..dir..'/height.lua:r11-readonly-probe'))()(deps).new_runtime(seed)
io.write('case\tx\tz\towner_x\towner_z\tclass\tclaim\tcave_claim\tincoming\tfinal\tkind\tfunctional_id\tlandmark\tprofile\tdistance\twidth\trun\tcoast_y\n')
for case,p in ipairs({{-414,-2724},{-511,-2562}}) do
 for z=p[2]-radius,p[2]+radius do for x=p[1]-radius,p[1]+radius do
  local class=horizontal.classification_values_at(x,z)
  local _,claim=horizontal.static_exclusion_values_at(x,z)
  local _,cave=horizontal.static_exclusion_values_at(x,z,'cave')
  local kind,_,id=height.functional_surface_values_at(x,z)
  local profile,distance,width,_,run,cy=height.coast_profile_at(x,z)
  local row={case,x,z,x%80,z%80,class,claim or '-',cave or '-',
   height.r11_incoming(x,z),height.terrain_height_at(x,z),kind or '-',id or '-',
   tostring(height.landmark_excluded_at(x,z)),profile or '-',distance or '-',width or '-',run or '-',cy or '-'}
  for i=1,#row do row[i]=tostring(row[i]) end
  io.write(table.concat(row,'\t'),'\n')
 end end
end
