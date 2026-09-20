-- Pure production orientation consumer: diagonal identity, ties and call bound.
return function(repo)
 local _,factory=dofile(repo..'/mods/MAPGEN/grug_mapgen/wp40/height.lua')
 local rules=factory('15140735923413111218')
 local n=0
 assert(rules.cardinal_orientation(0,0,4,function()n=n+1;return false end)==4)
 assert(n==144,'fallback query budget changed')
 local max_calls=n
 for x=10,14 do for z=10,14 do
  n=0
  local orientation=rules.cardinal_orientation(x,z,(x+z)%2==0 and 2 or 4,function(a,b)
   n=n+1;return a+b<=0
  end)
  assert(orientation==2,'diagonal shore has an alternating run axis')
  assert(n<=max_calls)
 end end
 n=0
 assert(rules.cardinal_orientation(0,0,4,function(x,z)
  n=n+1;return x==17 or z==17
 end)==1 and n==1,'direction-order tie or shortest-hit short circuit changed')
 n=0
 assert(rules.cardinal_orientation(0,0,1,function(x,z)
  n=n+1;return x==0 and z==-52
 end)==4 and n==144,'far boundary omitted')
 return 'R11 coast PASS: 25 diagonal samples, deterministic ties, unchanged absent-shore fallback, max144 cached water probes per fallback\n'
end
