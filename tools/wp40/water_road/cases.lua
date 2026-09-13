-- Actual user-seed basin across nine adjacent owners; the tenth covers depth.
assert(core.settings:get("grug_wp40_profile_seed") == "531802985935182545")
local cases = {}
for z = 1450, 1610, 80 do
	for x = 1770, 1930, 80 do
		cases[#cases + 1] = {id = "kezamba_" .. x .. "_" .. z, x = x, y = 72, z = z}
	end
end
-- Dry shores previously ended at y58..64 while the neighboring lake is y65.
cases[5].expected_nodes = {
	{x = 1862, y = 65, z = 1492, name = "default:stone"},
	{x = 1838, y = 65, z = 1493, name = "default:stone"},
}
cases[7].expected_nodes = {
	{x = 1777, y = 65, z = 1574, name = "default:stone"},
	{x = 1767, y = 65, z = 1600, name = "default:stone"},
}
cases[10] = {id = "deep", x = 0, y = -1000, z = 0}
return cases
