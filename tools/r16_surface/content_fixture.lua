return function(repo)
 local factory=dofile(repo.."/mods/MAPGEN/grug_mapgen/wp40/preparation_source.lua")
 local columns={column_values_at=function(x,z)
  local ground,water,functional,upper,lower=20,nil,nil,nil,nil
  if x==1 then ground,water=-100,1 end
  if x==2 then ground,water=-3,1 end
  if x==3 then functional=95 end
  if x==4 then upper,lower=100,-10 end
  return "land",1,"zone","biome","race",ground,water,nil,nil,nil,functional,nil,nil,nil,nil,upper,lower
 end}
 local template={{rotations={{min_x=-5,max_x=5,min_z=-5,max_z=5,min_y=-4,max_y=40}}}}
 local anchor={id="a",x=0,y=30,z=0}
 local blueprints={
  {descriptor={kind="anchor"},bounds={min={x=-2,y=-3,z=-2},max={x=2,y=100,z=2}}},
  {descriptor={kind="reference",offset={x=10,z=0}},reference={x=0,z=0},bounds={min={x=0,y=0,z=0},max={x=1,y=80,z=1}}},
  {descriptor={kind="overlay"},reach=40,half=2,bounds={min={x=100,y=-5,z=100},max={x=150,y=100,z=150}}},
 }
 local settlements={{profile={zone_id="zone",slot="capital",anchor_id="a"},prepared={blueprints=blueprints}}}
 local source=factory(columns,template,{{cells={{x=0,y=1,z=0}}}},settlements,
  {anchor=function() return anchor end},{copy_rows=function() return {{x=200,y=300,z=200}} end},"fixture",function(bytes) assert(#bytes>0);return "fixture-digest" end)
 local low,high=source.column_bounds(0,0);assert(low==17 and high==61,"tree support/crown")
 low,high=source.column_bounds(1,0);assert(low==-10 and high==42,"deep sea capped")
 low,high=source.column_bounds(2,0);assert(low==-6 and high==42,"shallow actual seabed")
 low,high=source.column_bounds(3,0);assert(high==136,"functional bridge")
 low,high=source.column_bounds(4,0);assert(low==-13 and high==141,"transition waterfall")
 local radius,bottom,top=source.tile_bounds({x=-5,z=-5},{x=5,z=5})
 assert(radius==5 and bottom==27 and top==130,"fixed structure bounds")
 radius,bottom,top=source.tile_bounds({x=10,z=0},{x=11,z=1})
 assert(bottom==20 and top==100,"reference-height plot")
 radius,bottom,top=source.tile_bounds({x=100,z=100},{x=101,z=101})
 assert(radius==43 and bottom==25 and top==130,"avenue neighborhood")
 radius,bottom,top=source.tile_bounds({x=200,z=200},{x=201,z=201})
 assert(bottom==300 and top==301,"activation anchor")
 -- Actual selector consumes this adapter across a Y boundary and root reach.
 local plan=dofile(repo.."/mods/CORE/grug_core/preparation_plan.lua")
 local ids={};for i=1,6 do ids[i]={anchor={x=0,y=0,z=0}} end
 local p=plan.new("full",{x=5,y=5,z=5},ids)
 local nx=(p.bounds.max.x-p.bounds.min.x)/80+1
 p.cursor=math.floor((0-p.bounds.min.z)/80)*nx+math.floor((0-p.bounds.min.x)/80)
 local scan=plan.begin(p,source)
 while not plan.scan(p,scan,source,512) do end
 assert(p.selection.y_max>=128,"structure and crown across Y boundary")
 return "r16-surface-content: water bridge waterfall templates fixed/reference structures avenues anchors=ok\n"
end
