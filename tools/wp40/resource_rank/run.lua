local repo = arg[1]
if type(repo) ~= "string" or repo == "" then
	error("usage: lua tools/wp40/resource_rank/run.lua REPO [expanded]", 0)
end
local expanded = arg[2] == "expanded"
if arg[2] ~= nil and not expanded then error("unknown resource-rank mode", 0) end
io.write(dofile(repo .. "/tools/wp40/resource_rank/fixture.lua")(repo, expanded))
