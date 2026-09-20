-- LuaJIT-only development regressions on immutable source inputs.
local repo=assert(arg[1])
local jobs={
 "tools/r10_map_b/registration_fixture.lua",
 "tools/r10_map_b/placement_fixture.lua",
 "tools/r10_map_b/writer_fixture.lua",
 "tools/r10_map_b/template_refs.lua",
 "tools/r10_farm/farming_completion_kat.lua",
 "tools/r10_art/art_kat.lua",
 "tools/wp40/r6/micro_kat.lua",
 "tools/r8_map_a/kat.lua",
 "tools/r8_map_a/writer_kat.lua",
 "tools/wp13/library_kat.lua",
 "tools/wp13/blueprint_kat.lua",
 "tools/wp13/seam_kat.lua",
 "tools/wp13/integration_fixture.lua",
}
local failed=0
for _,path in ipairs(jobs) do
 io.write("BEGIN\t",path,"\n");io.flush()
 local ok,result=pcall(function() return dofile(repo.."/"..path)(repo) end)
 if not ok then failed=failed+1;io.write("FAIL\t",path,"\t",tostring(result),"\n")
 else io.write("PASS\t",path,"\n",tostring(result or ""),"\n") end
 io.flush();collectgarbage("collect")
end
assert(failed==0,"MAP-B regression failures: "..failed)
