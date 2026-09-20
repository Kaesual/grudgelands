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
local source=dofile(d..'/'..profile.blueprint_file)({full_seed=seed,raw_sha256=sha})
local prepared=module.prepare(profile,source,sha)
local names,refs={},{}
for i,name in ipairs(prepared.palette) do names[i]=name;refs[name]=i end
local content={schema='grug_wp13_settlement_content_v1',content_names=names}
function content.content_ref(name) return refs[name] end
function content.resolve(ref,p2) return ref,p2 end
local tail=module.config(prepared,content,sha).new({planner_source=planner,zones_session=session})
local roads={};for _,name in ipairs(source.overlay.names) do roads[name]=true end
local function height(x,z) return session.terrain_height_at(anchor.x+x,anchor.z+z) end
local function box(x1,x2,z1,z2,low,high) return {x1=x1,x2=x2,z1=z1,z2=z2,y1=low-anchor.y,y2=high-anchor.y} end
local low,high=anchor.y,anchor.y
for x=40,260,4 do local y=height(x,0);low=math.min(low,y);high=math.max(high,y) end
local regions={avenue={box(40,260,-12,12,low-6,high+6)}}
local wall=false;for _,run in ipairs(source.overlay.runs) do if run.id:sub(1,5)=='wall_' then wall=true end end
if wall then
 low,high=anchor.y,anchor.y
 for z=-80,80,2 do local y=height(256,z);low=math.min(low,y);high=math.max(high,y) end
 regions.rampart={box(250,262,-80,80,low-6,high+24)}
 low,high=anchor.y,anchor.y
 for x=236,266,2 do local y=height(x,0);low=math.min(low,y);high=math.max(high,y) end
 regions.gate={box(232,266,-20,20,low-6,high+26)}
 regions.corner={}
 for _,sx in ipairs({-1,1}) do for _,sz in ipairs({-1,1}) do
  local cx,cz=sx*256,sz*256;low,high=anchor.y,anchor.y
  for x=cx-12,cx+12,2 do for z=cz-12,cz+12,2 do local y=height(x,z);low=math.min(low,y);high=math.max(high,y) end end
  regions.corner[#regions.corner+1]=box(cx-12,cx+12,cz-12,cz+12,low-6,high+24)
 end end
end
local function owner(v) return -30912+math.floor((v+30912)/80)*80 end
local owners={};local order={}
for _,boxes in pairs(regions) do for _,b in ipairs(boxes) do
 for z=owner(anchor.z+b.z1),owner(anchor.z+b.z2),80 do
  for y=owner(anchor.y+b.y1),owner(anchor.y+b.y2),80 do
   for x=owner(anchor.x+b.x1),owner(anchor.x+b.x2),80 do
    local k=x..':'..y..':'..z
    if not owners[k] then owners[k]=true;order[#order+1]={x=x,y=y,z=z} end
   end
  end
 end
end end
table.sort(order,function(a,b) if a.z~=b.z then return a.z<b.z elseif a.y~=b.y then return a.y<b.y else return a.x<b.x end end)
local cells={}
for generation,minp in ipairs(order) do
 local maxp={x=minp.x+79,y=minp.y+79,z=minp.z+79};local plan={}
 tail:bind_plan(minp,maxp,plan,generation)
 local ctx={plan=plan,generation=generation,call_mode='fixture',min_x=minp.x,min_y=minp.y,min_z=minp.z,max_x=maxp.x,max_y=maxp.y,max_z=maxp.z}
 function ctx.inside_owner(x,y,z) return x>=minp.x and x<=maxp.x and y>=minp.y and y<=maxp.y and z>=minp.z and z<=maxp.z end
 function ctx.write_hearthpine(x,y,z,cid,p2,ref)
  local k=(x-anchor.x)..':'..(y-anchor.y)..':'..(z-anchor.z)
  assert(not cells[k],'duplicate settlement writer cell')
  cells[k]={names[ref],p2}
 end
 tail:settle(ctx)
end
local meta=assert(io.open(out..'/'..key..'-projection.tsv','w'))
meta:write('label\tsha256\tcells\towners\n')
for _,label in ipairs({'avenue','rampart','corner','gate'}) do
 if regions[label] then
  local rows={};local tsv=assert(io.open(out..'/'..key..'-'..label..'.tsv','w'))
  for _,b in ipairs(regions[label]) do
   for z=b.z1,b.z2 do for y=b.y1,b.y2 do for x=b.x1,b.x2 do
    local c=cells[x..':'..y..':'..z]
    if c and c[1]~='air' and roads[c[1]] then
     rows[#rows+1]=table.concat({x,y,z,c[1],c[2]},':');tsv:write(table.concat({x,y,z,c[1],c[2]},'\t'),'\n')
    end
   end end end
  end
  tsv:close();meta:write(label,'\t',common.hex(sha(table.concat(rows,'\n'))),'\t',#rows,'\t',#order,'\n');meta:flush()
 end
end
meta:close()
local f=assert(io.open(out..'/'..key..'-road-names.txt','w'));local rr={};for name in pairs(roads) do rr[#rr+1]=name end;table.sort(rr);f:write(table.concat(rr,'\n'),'\n');f:close()
print('source projection complete',key,#order)
