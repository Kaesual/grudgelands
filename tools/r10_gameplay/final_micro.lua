local root = arg[1]
assert(type(root) == "string" and root:sub(1, 1) == "/")
local rows = {
	assert(loadfile(root .. "/tools/r6_food_buffs/kat.lua"))()(root),
	assert(loadfile(root .. "/tools/r8_mob1/bosses_kat.lua"))()(root),
	assert(loadfile(root .. "/tools/r9_mounts/mounts_kat.lua"))()(root),
	assert(loadfile(root .. "/tools/r10_gameplay/potion_kat.lua"))()(root),
}
io.write(table.concat(rows))
