local root = assert(arg[1])
local rows = {
	assert(loadfile(root .. "/tools/wp13/character_visuals_kat.lua"))()(root),
	assert(loadfile(root .. "/tools/r9_farm/farming_kat.lua"))()(root),
	assert(loadfile(root .. "/tools/r9_mounts/mounts_kat.lua"))()(root),
}
io.write(table.concat(rows))
