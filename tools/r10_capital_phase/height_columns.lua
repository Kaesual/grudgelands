-- Bounded source projection: actual zones, blueprint, prepare/config and tail.
-- It deliberately supplies no native-v7 nodes and does not emulate node timers.
local repo,key,out=assert(arg[1]),assert(arg[2]),assert(arg[3])
local seed='531802985935182545'
local d=repo..'/mods/MAPGEN/grug_mapgen/wp40'
local common=dofile(repo..'/tools/wp40/r6/common.lua');local sha=common.new_sha256()
local zones=dofile(d..'/zones.lua')({source=dofile(d..'/source/simple_map.lua'),schemas=dofile(d..'/schemas.lua'),canonical=dofile(d..'/canonical.lua'),deterministic=dofile(d..'/deterministic.lua'),index128=dofile(d..'/index128.lua'),horizontal_factory=dofile(d..'/simple_map.lua'),coupled_grade=dofile(d..'/coupled_grade.lua')(),height_factory=dofile(d..'/height.lua'),raw_sha256=sha})
local session,planner=zones.new_with_planner_source_runtime(seed,1)
local module=dofile(d..'/r7_settlement.lua');local profile
for _,p in ipairs(module.roster) do if p.key==key then profile=p end end
assert(profile,'missing capital')
local anchor=session.anchor(profile.zone_id,profile.slot)
local output=assert(io.open(out,'w'))
for line in io.lines(arg[4]) do
 local x,z=line:match('([^\t]+)\t([^\t]+)');x,z=tonumber(x),tonumber(z)
 local y=session.terrain_height_at(anchor.x+x,anchor.z+z)-anchor.y
 output:write(x,'\t',z,'\t',y,'\n')
end
output:close()
