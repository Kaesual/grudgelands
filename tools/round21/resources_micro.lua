-- Approved density rows through the actual R6 content validator and quota math.
-- No world construction or VM population; portable final-micro input.
return function(repo)
 local dir=repo..'/mods/MAPGEN/grug_mapgen/wp40/'
 local content_set,_,projection,sha=dofile(repo..'/tools/r10_map_b/content_fixture.lua')(repo)
 local manifest=dofile(dir..'r7_r6_manifest.lua')()
 local content=dofile(dir..'r6_content.lua')(manifest,content_set.production,projection)
 local hash=dofile(dir..'r6_hash.lua')(sha)
 local expected={
  coal={64,128,128,128,128,128}, copper={96,192,384,384,384,384},
  tin={96,192,384,384,384,384}, iron={128,96,192,384,384,384},
  quartz={128,256,512,512,512,512}, gold={false,512,256,128,256,256},
  silver={false,false,256,128,256,512}, emberglass={false,false,false,256,128,256},
  abyssal_crystal={false,false,false,false,512,256},
  citrine={false,2048,1024,512,512,512}, garnet={false,2048,1024,512,512,512},
  jade={false,2048,1024,512,512,512}, diamond={false,false,false,2048,1024,512},
  sapphire={false,false,false,2048,1024,512}, ruby={false,false,false,2048,1024,512},
 }
 local rows={}
 for _,r in ipairs(content.resources()) do
  local e=assert(expected[r.key],r.key)
  for tier=1,6 do
   assert(r.denominators[tier]==e[tier],r.key..' tier '..tier)
   if e[tier] then
    -- Exactly divisible host populations make the base and deep quota
    -- expectations independent of the stochastic rounding digest.
    local n=math.min(e[tier]*2,4096)
    local b=hash.budget(n,1,e[tier],1,1,string.rep('\0',32))
    assert(b==n/e[tier],'base quota')
    for _,m in ipairs({{5,4},{3,2}}) do
     local actual=hash.budget(n,1,e[tier],m[1],m[2],string.rep('\0',32))
     local exact=n/e[tier]*m[1]/m[2]
     assert(actual>=math.floor(exact) and actual<=math.ceil(exact),'deep quota')
    end
   end
  end
  assert(r.deep_1500_1999_numerator==5 and r.deep_1500_1999_denominator==4)
  assert(r.deep_2000_floor_numerator==3 and r.deep_2000_floor_denominator==2)
  local parts={};for t=1,6 do parts[t]=e[t] and tostring(e[t]) or '-' end
  rows[#rows+1]=r.key..'='..table.concat(parts,',')
 end
 assert(#rows==15)
 -- All forward pick materials remain available one tier before their host
 -- becomes mandatory. Steel additionally uses already-available iron+coal.
 assert(expected.iron[1] and expected.silver[3] and expected.emberglass[4]
  and expected.abyssal_crystal[5])
 assert(not expected.diamond[3] and not expected.citrine[1])
 table.sort(rows)
 return table.concat(rows,';')
end
