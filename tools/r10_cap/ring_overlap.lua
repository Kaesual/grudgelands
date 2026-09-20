-- Inspect actual pre-ring cells; ordinary buildings must not meet the ring.
local repo=assert(arg[1]);local dir=repo..'/mods/MAPGEN/grug_mapgen/wp13';local original=dofile
for _,city in ipairs({'highcourt','dur_brannoc','lethariel','nhal_veyr','gor_drazhak','kezamba'}) do
 local buffers={};local counts={};local joins=0;local foliage=0;local checked=0
 local natural={['default:leaves']=true,['grug_trees:silverwood_leaves']=true,
  ['default:fern_1']=true,['default:grass_1']=true,['default:junglegrass']=true}
 local tower={dur_brannoc={['grug_decor:castle_stonewall']=true},
  nhal_veyr={['grug_decor:castle_dungeon_stone']=true},
  gor_drazhak={['default:acacia_tree']=true,['grug_decor:darkage_ors_block']=true}}
 dofile=function(path)
  local module=original(path)
  if path==dir..'/parts.lua' then
   local buffer=module.buffer;module.buffer=function(...) local b=buffer(...);buffers[#buffers+1]=b;return b end
  elseif path==dir..'/precinct_ring.lua' then
   local walk=module.walk
   module.walk=function(write,opts)
    return walk(function(x,z)
     for _,b in ipairs(buffers) do
      if b:at(-49,0,-49) then
       checked=checked+1
       for y=1,24 do local c=b:at(x,y,z)
        if c and c.name~='air' then
         if natural[c.name] then foliage=foliage+1
         else
          assert(tower[city] and tower[city][c.name] and
           math.min(math.abs(x),math.abs(z))==45,
           city..": ordinary building intersects ring at "..x..","..y..","..z)
          joins=joins+1
         end
        end
       end
      end
     end
     write(x,z)
    end,opts)
   end
  end
  return module
 end
 local c=dofile(dir..'/'..city..'.lua')(dir).core();dofile=original
 assert(checked>0,"no actual core buffer inspected")
 print(city,"ordinary_building_overlaps=0","corner_tower_join_cells="..joins,
  "natural_foliage_cells="..foliage,"ring_columns="..checked)
end
