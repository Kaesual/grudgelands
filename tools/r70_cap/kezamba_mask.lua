-- Kezamba's lake mask from the real water (Round 70; the mask's old generator
-- was deleted in Round 22). Reads `wp40/water_authored.lua`, so it follows the
-- chain with no second copy of it.
--
--   luajit tools/r70_cap/kezamba_mask.lua [REPO]            prints the LAGOON rows
--   luajit tools/r70_cap/kezamba_mask.lua [REPO] --verify   the committed mask
--                                                           against the water
local repo = arg[1] and arg[1] ~= "--verify" and arg[1] or "."
local verify = arg[#arg] == "--verify"
local WINDOW = 80 -- past the pad on every side
local ANCHOR_X, ANCHOR_Z = 1800, 1500

local lake
for _, row in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/water_authored.lua")(
		{LAKE_PROXY = 40})) do
	if row.id == "kezamba_cenote" then lake = row end
end
local function wet(x, z) return lake.indicator(ANCHOR_X + x, ANCHOR_Z + z) >= 0.5 end

if verify then
	local mask = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/kezamba_lagoon.lua")()
	local columns, wrong = 0, 0
	for z = -WINDOW, WINDOW do
		for x = -WINDOW, WINDOW do
			if wet(x, z) then columns = columns + 1 end
			if wet(x, z) ~= mask.lagoon(x, z) then wrong = wrong + 1 end
		end
	end
	if wrong > 0 then
		print("KEZAMBA MASK FAIL " .. wrong .. " of " .. columns .. " columns differ")
		os.exit(1)
	end
	print("KEZAMBA MASK PASS columns=" .. columns)
	return
end

for z = -WINDOW, WINDOW do
	local runs, start = {}, nil
	for x = -WINDOW, WINDOW + 1 do
		if x <= WINDOW and wet(x, z) then
			start = start or x
		elseif start then
			runs[#runs + 1] = ("{%d, %d}"):format(start, x - 1)
			start = nil
		end
	end
	if #runs > 0 then
		print(("\t\t{%d, %s},"):format(z, table.concat(runs, ", ")))
	end
end
