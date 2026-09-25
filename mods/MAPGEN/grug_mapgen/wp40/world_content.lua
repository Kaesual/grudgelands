-- P9G-2 surface/cave/reef extension, inside the existing R6 private transaction.
return function(catalog, content, habitat)
 assert(type(habitat)=="table" and type(habitat.initial_denominator)=="function")
 assert(catalog.schema=="grug_world_content_v1" and #catalog.plants==15 and #catalog.names==24)
 for i,name in ipairs(catalog.names) do assert(content.content_names[i+12]==name) end
 local config={}
 function config.new(deps)
  local contract=deps.content.content_contract()
  local air=contract.r5.resolve(1,0,0)
  local phase=0
  for i=1,#deps.full_seed_string do phase=(phase*131+string.byte(deps.full_seed_string,i))%65521 end
  -- Exact-double integer mixing, no global random state or per-voxel SHA.
  local function hash(x,y,z,salt)
   local value=(x*374761+y*193939+z*668265+phase*69069+salt*83491)%16777213
   return (value*48271)%16777213
  end
  -- A separate mixed stream prevents the visible axis-aligned runs produced
  -- by the general linear plant hash. Keep it local so existing wild plants
  -- retain their exact positions.
  local function reef_hash(x,z,salt)
   local a=hash(x*37+z*11,salt,x*7-z*29,151)
   return hash(a%4093,x*53-z*17,math.floor(a/4093),salt+157)
  end
  local zones,hosts={},{}
  for i,row in ipairs(catalog.plants) do
   zones[i]={};hosts[i]={}
   for _,zone in ipairs(row.zones) do zones[i][zone]=true end
   for biome,names in pairs(row.hosts) do
    local set={};hosts[i][biome]=set
    for _,name in ipairs(names) do
     local found=false
     for ref,candidate in ipairs(contract.content_names) do
      if candidate==name then set[contract.content_cids[ref]]=true;found=true end
     end
     assert(found,"world content support absent: "..name)
    end
   end
  end
  local function shore(ctx,row,x,y,z)
   if row.shore=="none" then return true end
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
    local water,_,_,_,_,bed,level=ctx.column_values_at(x+d[1],z+d[2])
    if level and bed<level and math.abs(y-level)<=1 and
     (water=="planned_water" or (row.shore=="any" and
      (water=="coastal_shelf" or water=="deep_ocean" or water=="immutable_dragon_channel"))) then return true end
   end
   return false
  end
  local function support(ctx,x,y,z)
   if ctx.inside_owner(x,y,z) then return ctx.settled_at(x,y,z) end
   return ctx.analytic_p7_tuple(x,y,z)
  end
  local tail={};local bound,generation;local total=0
  local cave_rows={}
  for i,row in ipairs(catalog.plants) do if row.mode=="cave" then cave_rows[#cave_rows+1]={i,row} end end
  function tail.bind(plan,gen) bound,generation=plan,gen end
  function tail.settle(ctx)
   assert(ctx.plan==bound and ctx.generation==generation,"world content plan binding differs")
   local counts={};for i=1,#catalog.names do counts[i]=0 end
   local function write(index,x,y,z,param2)
    local ref=index+12
    local cid=content.resolve_p9g(ref,param2)
    ctx.write_p9g(x,y,z,cid,param2,ref,ref)
    counts[index]=counts[index]+1;total=total+1
   end
   for z=ctx.min_z,ctx.max_z do
    for x=ctx.min_x,ctx.max_x do
     local water,_,zone,biome,_,ground,water_y,river_id,_,_,_,_,_,step=
      ctx.column_values_at(x,z)
     local excluded,excluded_id=ctx.exclusion_at(x,z)
     -- Inland water and its banks (stale-rule R5) are claim exclusions of
     -- their own: freshwater plants belong in that water, and shore rows
     -- on the bank; everything else keeps off both.
     local bank=excluded_id=="exclude:water_bank"
     if excluded_id=="exclude:inland_water" or bank then excluded=nil end
     local housing=ctx.housing_excluded_at(x,z)
     if water=="land" and not excluded and not housing then
      local level=deps.zones_session.surface_mob_level_at(x,z)
      local y=ground+1
      if y>=ctx.min_y and y<=ctx.max_y then
       local cid,_,occupancy,opcode=ctx.settled_at(x,y,z)
       if cid==air and occupancy==0 and opcode==0 then
        local below,below_p2,_,below_op=support(ctx,x,ground,z)
        if below_p2==0 and below_op>=1 and below_op<=4 then
         for i,row in ipairs(catalog.plants) do
          local allowed=hosts[i][biome] or hosts[i].any
          if row.mode=="surface" and (not bank or row.shore~="none") and
           allowed and allowed[below] and level and
           level>=row.min and level<=row.max and (#row.zones==0 or zones[i][zone]) and
           hash(x,y,z,i)%habitat.initial_denominator(row.key,row.density)==0 and
           shore(ctx,row,x,ground,z) then
           write(i,x,y,z,0);break
          end
         end
        end
       end
      end
     end
     -- Deep candidates use actual original/final air, not analytic surface air.
     -- A support crossing the owner boundary is rejected: no order-dependent
     -- guess about an uncommitted neighbouring slice's stratum is permitted.
     if ctx.call_mode ~= "evidence_fixture" and water=="land" and not housing then
      for _,entry in ipairs(cave_rows) do
       local i,row=entry[1],entry[2]
       if row.max>=ctx.min_y and row.min<=ctx.max_y then
        local low=math.max(ctx.min_y+1,row.min)
        local high=math.min(ctx.max_y,row.max,ground-2)
        for y=low,high do
         if hash(x,y,z,i)%habitat.initial_denominator(row.key,row.density)==0 and
          ctx.cave_content_allowed_at(x,y,z) then
          local cid,p2,occupancy=ctx.settled_at(x,y,z)
          local below=ctx.settled_at(x,y-1,z)
          if cid==air and p2==0 and occupancy==0 and hosts[i].stone[below] then write(i,x,y,z,0) end
         end
        end
       end
      end
     end
     -- Rooted meshes occupy their bed cube; all stems must remain in sea water.
     if not excluded and not housing and water=="coastal_shelf" and water_y and
      water_y-ground>=2 and water_y-ground<=10 and
      ctx.inside_owner(x,ground,z) then
      local cell_x=math.floor(x/16)
      local cell_z=math.floor(z/16)
      local local_x=x-cell_x*16
      local local_z=z-cell_z*16
      local reef_cell=reef_hash(cell_x,cell_z,101)
      local center_x=3+reef_hash(cell_x,cell_z,103)%10
      local center_z=3+reef_hash(cell_x,cell_z,107)%10
      local dx=local_x-center_x
      local dz=local_z-center_z
      local swapped=reef_hash(cell_x,cell_z,109)%2==1
      local long=swapped and dz or dx
      local short=swapped and dx or dz
      local patch=long*long+2*short*short<=15 and reef_hash(x,z,113)%5~=0
      if reef_cell%8==0 and patch then
      local bed,p2,occupancy,opcode=ctx.settled_at(x,ground,z)
      local _,sand=ctx.production_content("default:sand")
      local _,gravel=ctx.production_content("default:gravel")
      local _,stone=ctx.production_content("default:stone")
      if (bed==sand or bed==gravel or bed==stone) and p2==0 and occupancy==0 and opcode>=1 and opcode<=4 then
       local index=16+reef_hash(x,z,127)%7
       local height=index==22 and math.min(6,water_y-ground-1) or 1
       local clear=true
       if index==22 and bed~=sand then clear=false end
       for y=ground+1,ground+height do
        if not ctx.inside_owner(x,y,z) then clear=false;break end
        local current,param2=ctx.settled_at(x,y,z)
        local _,family,liquid=contract.classify(current,param2)
        if family~=contract.ordinary_water_family_id or liquid~=1 then clear=false;break end
       end
       if clear then write(index,x,ground,z,index==22 and height*16 or 0) end
      end
      end
     end
     -- Freshwater waterweed uses only a natural sand bed. Functional water
     -- corridors and authored structures are already closed by the water
     -- class and the shared exclusion/housing predicates above. Lakes (and
     -- bays) hold ordinary water; a river reach holds river water and gets
     -- weed at half the rate, never on a step face (rapid or fall).
     local river=type(river_id)=="string" and river_id:sub(1,6)=="river:"
     local family=river and contract.river_water_family_id or
      contract.ordinary_water_family_id
     if not excluded and not housing and water=="planned_water" and water_y and
      water_y-ground>=2 and water_y-ground<=6 and step==nil and
      ctx.inside_owner(x,ground,z) and reef_hash(x,z,211)%(river and 192 or 96)==0 then
      local bed,p2,occupancy,opcode=ctx.settled_at(x,ground,z)
      local _,sand=ctx.production_content("default:sand")
      if bed==sand and p2==0 and occupancy==0 and opcode>=1 and opcode<=4 then
       local height=math.min(4,water_y-ground-1)
       local clear=true
       for y=ground+1,ground+height do
        if not ctx.inside_owner(x,y,z) then clear=false;break end
        local current,param2=ctx.settled_at(x,y,z)
        local _,found,liquid=contract.classify(current,param2)
        if found~=family or liquid~=1 then clear=false;break end
       end
       if clear then write(24,x,ground,z,height*16) end
      end
     end
     if not excluded and not housing and water=="planned_water" and water_y and
      water_y-ground>=2 and water_y-ground<=6 and
      ctx.inside_owner(x,water_y,z) and ctx.inside_owner(x,water_y+1,z) and
      reef_hash(x,z,223)%192==0 then
      local surface,param2,occupancy,opcode=ctx.settled_at(x,water_y+1,z)
      local below,below_p2=ctx.settled_at(x,water_y,z)
      local _,family,liquid=contract.classify(below,below_p2)
      if surface==air and param2==0 and occupancy==0 and opcode==0 and
       family==contract.ordinary_water_family_id and liquid==1 then
       write(23,x,water_y+1,z,reef_hash(x,z,227)%4)
      end
     end
    end
   end
   return {schema="grug_world_content_ledger_v1",counts=counts}
  end
  function tail.metrics() return {accepted=total} end
  return tail
 end
 return config
end
