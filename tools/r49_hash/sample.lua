-- Round 49 lane HASH: the placement hash (r6_hash.lua `placement`) over a
-- large fixed sample, as one text line, so tools/r49_hash/portable_test.lua
-- can compare LuaJIT with plain Lua 5.1. Pure: no SHA-256, no engine seam,
-- exact integer arithmetic only.
--
--   luajit tools/r49_hash/sample.lua REPO
--   tools/bin/lua51 tools/r49_hash/sample.lua REPO
--
-- The sample: the salts of every placement stream of the real decoration and
-- gathering rows for three seeds; per seed the draws the writers take (the
-- R6 rank and thinning draw at (x, 0, z), the cell remainder, the P9 rotation,
-- height, variant and the chained template trials, the P9G rank at
-- (x, y, z)) over a strip of columns that crosses the world's extremes; and
-- the budget of r6_hash.lua over those draws.
local repo = assert(arg and arg[1], "usage: sample.lua REPO")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local hash = dofile(wp40 .. "/r6_hash.lua")()
local decorations = dofile(wp40 .. "/r7_r6_manifest.lua")().decorations
local gathering = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua").p9g_sources()

local acc, count = 0, 0
local function fold(value)
	acc = (acc * 31 + value) % 2147483647
	count = count + 1
end

for _, seed in ipairs({"12345", "10536739806879207652", "18446744073709551615"}) do
	local mix, salt = hash.placement(seed)
	local rows = {}
	for index = 1, #decorations do
		local id = decorations[index].id
		rows[#rows + 1] = {salt("decoration_candidate_rank", id),
			salt("decoration_candidate_thin", id), salt("decoration_budget_remainder", id),
			salt("decoration_rotation", id), salt("decoration_simple_height", id),
			salt("decoration_variant", id), salt("template_probability", id)}
	end
	local p9g = {}
	for index = 1, #gathering do
		p9g[index] = {salt("gathering_candidate_rank", gathering[index].id),
			salt("gathering_budget_remainder", gathering[index].id)}
	end
	for index = 1, #rows do
		for k = 1, 7 do fold(rows[index][k]) end
	end
	for index = 1, #p9g do fold(p9g[index][1]) fold(p9g[index][2]) end
	-- Columns along a strip from one world corner over the origin to the
	-- other, plus the mapgen limits.
	for step = 0, 3999 do
		local x = -30912 + step * 15 + step % 7
		local z = 30927 - step * 15 - step % 5
		local y = (step * 37) % 2000 - 1000
		local row = rows[step % #rows + 1]
		fold(mix(x, 0, z, row[1]))
		fold(mix(x, 0, z, row[2]))
		fold(mix(math.floor(x / 16), 0, math.floor(z / 16), row[3]))
		fold(mix(x, y, z, row[4]) % 4)
		fold(2 + mix(x, y, z, row[5]) % 3)
		fold(mix(x, y, z, row[6]) % 32)
		local root = mix(x, y, z, row[7])
		fold(mix(-1, step % 64, -1, root) % 256)
		fold(mix(step % 16, step % 64, (step * 3) % 16, root) % 256)
		local source = p9g[step % #p9g + 1]
		fold(mix(x, y + 1, z, source[1]))
		local draw = mix(math.floor(x / 16), 1024, math.floor(z / 16), source[2])
		fold((hash.budget(step % 257, 1, 1 + step % 1024, 1, 1, draw)))
	end
end
print(("placement sample: %d values, checksum %d"):format(count, acc))
