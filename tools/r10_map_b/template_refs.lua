-- LuaJIT: decode the shipped MTS files and prove the changed graph limb is only
-- the sorted content-reference shift caused by the two new surface materials.
return function(repo)
 local dir=repo.."/mods/MAPGEN/grug_mapgen/wp40"
 local common=dofile(repo.."/tools/wp40/r6/common.lua")
 local content_set,_,projection,sha=dofile(repo.."/tools/r10_map_b/content_fixture.lua")(repo)
 local actual=dofile(dir.."/r6_content.lua")(dofile(dir.."/r7_r6_manifest.lua")(),content_set.production,projection)
 local source=dofile(dir.."/r7_template_source.lua")({read_schematic=common.read_mts},
  repo.."/mods/BASE/default/schematics",repo.."/mods/ITEMS/grug_trees/schematics")
 local templates=dofile(dir.."/r6_templates.lua")(dofile(dir.."/r6_hash.lua")(sha),actual,source)
 local graph=dofile(dir.."/r7_manifest.lua")(dofile(dir.."/canonical.lua"),sha,
  {{key="fixture",anchor_id="anchor",delta_schema="delta",blueprints={{id="one",prefix="one",
   identity_schema="identity",kind="anchor",bounds={min={x=0,y=0,z=0},max={x=1,y=1,z=1}}}}}}).graph_digest_for_evidence
 local current=templates.records()
 assert(#current==21)
 local current_hash=graph(current)
 local prior_ref={};local n=0
 for _,name in ipairs(content_set.production.content_names) do
  if name~="grug_nodes:ash_ground" and name~="grug_nodes:dirt_with_moss" then n=n+1;prior_ref[name]=n end
 end
 assert(n==88)
 local shifted=0
 for _,definition in ipairs(current) do
  for _,rotation in ipairs(definition.rotations) do
   for _,cell in ipairs(rotation.cells) do
    if cell.name~="air" then
     local prior=assert(prior_ref[cell.name])
     if cell.content_ref~=prior then shifted=shifted+1 end
     cell.content_ref=prior
    end
   end
  end
 end
 local previous_hash=graph(current)
 assert(previous_hash=="faa8fdd2beabd0807b5a41cd207163bbbb741fa8ee263a212bd7fbe34f2ff4df",
  "template bytes changed beyond content refs: "..previous_hash)
 assert(current_hash=="0f9c1230f22f7a2782cd57d3b7d5d5029d9f3eeed18a29f729f10b8bf92b9ec0")
 return "templates\t21\nrotations\t84\nshifted_refs\t"..shifted..
  "\nbaseline_ref_graph\t"..previous_hash.."\ncurrent_ref_graph\t"..current_hash.."\n"
end
