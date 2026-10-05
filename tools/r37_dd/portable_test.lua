-- Round 37 lane DD portable test (LuaJIT): the generated placement table.
--
-- docs/design/zone_mobs.md is printed by tools/r37_dd/zone_mobs.lua from the
-- spawn recipes, the catalogue and the mapgen zone records. This fixture
-- fails when the file is stale (a recipe, catalogue or band changed without
-- a regeneration) and checks a few facts the table must carry:
--   A. the file equals the generator's output;
--   B. all 38 zones, each with a day and a night family;
--   C. six capital zones, each with hostile night families outside the city
--      (the Round 28 recipes; round37-plan.md §2.2.4);
--   D. the Rift Spawn row zones are the four that keep it.
--
--   luajit tools/r37_dd/portable_test.lua [REPO]
-- Prints "R37 DD PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end

local generator = dofile(repo .. "/tools/r37_dd/zone_mobs.lua")
local text, zones = generator.build(repo)

-- A. the shipped file is the generator's output.
local handle = io.open(repo .. "/" .. generator.DOC, "rb")
local current = handle and handle:read("*a")
if handle then handle:close() end
check(current == text, "A " .. generator.DOC ..
	" is stale: run luajit tools/r37_dd/zone_mobs.lua")

-- B. every zone, each with both clocks populated.
check(#zones == 38, "B 38 zones, got " .. #zones)
for _, row in ipairs(zones) do
	check(next(row.day) ~= nil, "B day families in " .. row.zone.id)
	check(next(row.night) ~= nil, "B night families in " .. row.zone.id)
end

-- C. the capital zones carry hostile night families outside the city.
local capitals = 0
for _, row in ipairs(zones) do
	if row.capital then
		capitals = capitals + 1
		check(row.night.Zombie or row.night.Bandit,
			"C night zombies or bandits in capital zone " .. row.zone.id)
		check(#row.leaders > 0, "C a named leader in capital zone " .. row.zone.id)
	end
end
check(capitals == 6, "C six capital zones, got " .. capitals)

-- D. the Rift Spawn line names the four zones of RECIPE_ZONE_ROWS.
local rift = text:match("%*%*Rift Spawn%*%*.-:%s*(.-)%.\n")
check(rift == "The Wyrmglass Crown, Gravesalt Escarpment, The Skyglass Canopy, " ..
	"Stormscale Summit", "D Rift Spawn zones: " .. tostring(rift))

if failures > 0 then
	error(("R37 DD PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R37 DD PORTABLE PASS checks=%d"):format(checks))
