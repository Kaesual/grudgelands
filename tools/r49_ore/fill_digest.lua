-- Round 49 lane ORE: the fill-ore choice (r6_settlement.lua
-- r49_fill_ores_new) over a fixed 64^3 fill volume, as one text line, so
-- tools/r49_ore/portable_test.lua can compare LuaJIT with plain Lua 5.1.
-- Pure: loads no engine seam. Exact integer arithmetic only.
--
--   luajit tools/r49_ore/fill_digest.lua REPO
--   tools/bin/lua51 tools/r49_ore/fill_digest.lua REPO
local repo = assert(arg and arg[1], "usage: fill_digest.lua REPO")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local resources = dofile(wp40 .. "/r7_r6_manifest.lua")().resources
-- T1 as grug_materials.TIERS[1] has it (the fixture checks it is the same).
local tier = {y_min = -100, lower_half_y_max = -50}
local mix = dofile(wp40 .. "/r6_hash.lua")().placement("10536739806879207652")
local fill_ore_at = dofile(wp40 .. "/r6_settlement.lua").r49_fill_ores_new(
	resources, tier, mix)
local count, acc = 0, 0
for z = -3000, -2937 do
	for y = -80, -17 do
		for x = 2900, 2963 do
			local index = fill_ore_at(x, y, z)
			if index then
				count = count + 1
				acc = (acc * 31 + index * 1000003 + (x + 4000) * 7 + (y + 4000) * 13 +
					(z + 4000) * 17) % 2147483647
			end
		end
	end
end
print(("fill digest: %d ores, checksum %d"):format(count, acc))
