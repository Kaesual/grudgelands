-- Diagnostic only: derives candidate constants, then exercises a copied strict
-- manifest constructor with precisely those constants. Never changes live pins.
local repo=assert(arg[1])
local common=dofile(repo.."/tools/wp40/r6/common.lua")
local sha=common.new_sha256()
local dir=repo.."/mods/MAPGEN/grug_mapgen/wp40"
local api,projection=dofile(repo.."/tools/r10_map_b/runtime_fixture.lua")(repo)
local read=common.read_file
local catalog_source=read(repo.."/mods/ITEMS/grug_gathering/catalog.lua")
local catalog=assert(loadstring(catalog_source))()
local catalog_sha=common.hex(sha(catalog.manifest().canonical_bytes))
local old_catalog=catalog.manifest().sha256
catalog=assert(loadstring((catalog_source:gsub(old_catalog,catalog_sha))))()
local original_dofile=dofile
local report={"diagnostic\tcopied strict constructor; live pins unchanged"}
local function emit(key,value) report[#report+1]=key.."\t"..value end
local captured
rawset(_G,"dofile",function(path)
 if path~=dir.."/r7_manifest.lua" then return original_dofile(path) end
 local source=read(path)
 return function(canonical,raw_sha,order)
  local original=assert(loadstring(source))()(canonical,raw_sha,order)
  local graph=original.graph_digest_for_evidence
  return {new=function(inputs)
   captured=inputs
   local frozen={schema="grug_wp40_r7_source_projection_v1",
    r6_catalog=graph({surfaces=inputs.r6_manifest.surfaces,resources=inputs.r6_manifest.resources,
     cultural=inputs.r6_manifest.cultural,decorations=inputs.r6_manifest.decorations}),
    accepted_r6_content=graph(inputs.accepted_r6_rows),decoded_templates=graph(inputs.decoded_templates),
    wp43_projection=graph(inputs.wp43_projection),production_semantics=inputs.production_content.semantic_digest,
    p9g_semantics=inputs.p9g_content.semantic_digest,world_rules=graph(inputs.world_content_rules),
    native_noise=inputs.native_identities.noise_digest,native_allowlist=inputs.native_identities.native_digest,
    gathering=catalog_sha,cultural=graph(inputs.cultural_registrations),consumer_payload=graph(inputs.consumer_payload)}
   local replacements={
    [old_catalog]=catalog_sha,
    ["c8088a4b6802c0fc1a74d8826e3df0bb49b64f9ab4c6e93bcbd66aa2a16b9895"]=frozen.wp43_projection,
    ["9b7a978d178352521ae61fb87b897c5f79e12838b0829caa229ad90832ddedb8"]=frozen.production_semantics,
    ["450c35e94af32721768d3771454db89dbdb43099660b2118c178a3ca6b438d49"]=frozen.p9g_semantics,
    ["466abcd49cac58c68aabf26b17e0ae3925425e1396ab73bc61f8d27de8cf996b"]=frozen.accepted_r6_content,
    ["faa8fdd2beabd0807b5a41cd207163bbbb741fa8ee263a212bd7fbe34f2ff4df"]=frozen.decoded_templates,
    ["674ddc3f6a9b9bfd1a1e50c88db6908f5022960200e88128665292047ade9c51"]=graph(frozen),
    ["5c56b81314cb82f5b98b95e8b94173d585280c6cb20dfb1ce806adbcbf879be0"]=graph(frozen),
   }
   local copied=source:gsub("grug_wp33_gathering_catalog_v2","grug_wp33_gathering_catalog_v3")
   for before,after in pairs(replacements) do copied=copied:gsub(before,after) end
   local strict=assert(loadstring(copied,"diagnostic strict manifest"))()(canonical,raw_sha,order)
   local receipt=strict.new(inputs)
   assert(strict.validate(receipt))
   local keys={};for key in pairs(frozen) do keys[#keys+1]=key end;table.sort(keys)
   for _,key in ipairs(keys) do emit(key,frozen[key]) end
   emit("SOURCE_PROJECTION_SHA256",graph(frozen))
   emit("strict_manifest_sha256",receipt.sha256)
   return receipt
  end,validate=original.validate}
 end
end)
local ok,result=pcall(function()
 local runtime=dofile(dir.."/r7_runtime.lua")(api,dir,repo.."/mods/BASE/default/schematics",projection,catalog)
 local built=runtime.build_authority(dofile(dir.."/r7_native.lua").identities())
 assert(built.manifest.sha256)
 return built
end)
rawset(_G,"dofile",original_dofile)
if not ok then error(result,0) end
io.write(table.concat(report,"\n"),"\n")
