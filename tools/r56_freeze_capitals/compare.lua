-- Round 56 FREEZE-CAPITALS: compare the probe's node counts (run.sh) with the
-- blueprints: Highcourt's core (built from its templates, kit core) and
-- Dawnmere. A building node (doors, beds, decor, stairs, panes, wool, walls,
-- torches, fences) appears in the world exactly as often as in the blueprint;
-- terrain and trees are not compared (the world around the pad is the seed's).
-- Usage: luajit tools/r56_freeze_capitals/compare.lua <repo> <probe.txt>
local repo, probe = arg[1], arg[2]
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local counts = {}
for line in io.lines(probe) do
	local town, name, count = line:match("%[r56capitals%] (%a+) count (%S+) (%d+)")
	if town then
		counts[town] = counts[town] or {}
		counts[town][name] = tonumber(count)
	end
end
local BUILDING = {"^doors:", "^beds:", "^grug_decor:", "^xpanes:", "^wool:", "^walls:",
	"^stairs:", "^default:torch", "^default:fence"}
local blueprints = {
	highcourt = function()
		return dofile(wp40 .. "/r7_capital_blueprint.lua").kit("highcourt").core.build()
	end,
	dawnmere = function() return dofile(wp40 .. "/r7_dawnmere_blueprint.lua")() end,
}
local failed = 0
for _, town in ipairs({"highcourt", "dawnmere"}) do
	local world = counts[town]
	if not world then
		print(town .. ": no counts from the probe")
		failed = failed + 1
	else
		local want = {}
		for _, cell in ipairs(blueprints[town]().cells) do
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
