io.stderr:write(_VERSION, "\t", type(jit) == "table" and jit.version or "PUC", "\n")
local repo = assert(arg[1], "repository path required")
local production_repo = arg[2] or repo
local expanded = arg[3] == "expanded"
if arg[3] ~= nil and not expanded then error("unknown resource sampling mode", 0) end
if expanded and type(jit) ~= "table" then error("expanded mode requires LuaJIT", 0) end
local fixture = dofile(repo .. "/tools/wp40/resource_sampling/sampler_fixture.lua")
io.write(fixture(repo, production_repo, expanded))
local writer = dofile(repo .. "/tools/wp40/resource_sampling/writer_fixture.lua")
io.write(writer(production_repo, expanded))
