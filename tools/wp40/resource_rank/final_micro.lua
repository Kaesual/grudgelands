-- One compact final-byte process, run once per interpreter by final_micro.sh.
local repo = assert(arg[1], "repository root required")
local parts = {"schema\tgrug_wp40_tree_resource_final_micro_v1\n"}
for _, relative in ipairs({"tools/wp40/tree_slices/fixture.lua",
		"tools/wp40/resource_rank/primitives.lua", "tools/wp40/resource_rank/fixture.lua"}) do
	parts[#parts + 1] = dofile(repo .. "/" .. relative)(repo)
	collectgarbage("collect")
end
io.write(table.concat(parts))
