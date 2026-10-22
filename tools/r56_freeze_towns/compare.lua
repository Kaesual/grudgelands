-- Round 56 FREEZE-TOWNS: compare the probe's node counts (run.sh) with the
-- blueprints. A building node (one a template places: doors, beds, decor, the
-- props moved into the templates) appears in the world exactly as often as in
-- the blueprint; terrain nodes are not compared (the world around and under
-- the pad is the seed's).
-- Usage: luajit tools/r56_freeze_towns/compare.lua <repo> <probe.txt>
local repo, probe = arg[1], arg[2]
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local counts = {}
for line in io.lines(probe) do
	local town, name, count = line:match("%[r56freeze%] (%a+) count (%S+) (%d+)")
	if town then
		counts[town] = counts[town] or {}
		counts[town][name] = tonumber(count)
	end
end
local BUILDING = {"^doors:", "^beds:", "^grug_decor:", "^xpanes:", "^wool:", "^walls:",
	"^stairs:", "^default:torch", "^default:fence"}
local failed = 0
for _, town in ipairs({"dawnmere", "sunscar"}) do
	local world = counts[town]
	if not world then
		print(town .. ": no counts from the probe")
		failed = failed + 1
	else
		local blueprint = dofile(wp40 .. "/r7_" .. town .. "_blueprint.lua")()
		local want = {}
		for _, cell in ipairs(blueprint.cells) do
			want[cell.name] = (want[cell.name] or 0) + 1
		end
		local names, compared = {}, 0
		for name in pairs(want) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do
			local building = false
			for _, pattern in ipairs(BUILDING) do
				if name:find(pattern) then building = true end
			end
			if building then
				compared = compared + 1
				if (world[name] or 0) ~= want[name] then
					print(("%s: %s %d in the world, %d in the blueprint"):format(town, name,
						world[name] or 0, want[name]))
					failed = failed + 1
				end
			end
		end
		print(("%s: %d building node names compared"):format(town, compared))
	end
end
if failed > 0 then error("compare: FAIL (" .. failed .. ")", 0) end
print("compare: PASS")
