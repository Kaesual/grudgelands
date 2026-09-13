local repo = arg[1]
if type(repo) ~= "string" or repo == "" then
	error("usage: lua tools/wp40/tree_slices/run.lua REPO", 0)
end
io.write(dofile(repo .. "/tools/wp40/tree_slices/fixture.lua")(repo, arg[2]))
