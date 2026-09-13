local repo = assert(arg[1])
local solver = dofile(repo ..
	"/mods/MAPGEN/grug_mapgen/wp40/coupled_grade.lua")().solve

local result = assert(solver({0, -100, 2, -100}, {0, 100, 2, 100},
	{0, 8, 2, -7}, {{1, 2}, {2, 3}, {3, 4}, {1, 4}}))
assert(result[1] == 0 and result[3] == 2)
for _, edge in ipairs({{1, 2}, {2, 3}, {3, 4}, {1, 4}}) do
	assert(math.abs(result[edge[1]] - result[edge[2]]) <= 1)
end
local failed, node, lower, upper = solver({0, 4}, {0, 4}, {0, 4},
	{{1, 2}})
assert(failed == nil and node == 1 and lower == 3 and upper == 0)
io.write(table.concat(result, ","), "\n")
