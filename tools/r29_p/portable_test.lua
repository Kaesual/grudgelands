-- Round 29 Lane P portable test (spawn playtest fixes, round29-plan.md §7):
--   P1  mobs:add_mob places a mob without a particle puff;
--   P2  leaders have 1.5x HP at 1.15x size (the real registration is checked
--       in tools/r28_b2/portable_test.lua, the HP factor in tools/r28_s1);
-- Usage (repo root): luajit tools/r29_p/portable_test.lua [REPO]
local repo = arg[1] or "."
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")

local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end

local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- P1: the body of mobs:add_mob calls no effect().
do
	local api = read("mods/ENTITIES/mobs/api.lua")
	local body = api:match("\nfunction mobs:add_mob%(pos, def%)(.-)\nend\n")
	check(body ~= nil, "P1: mobs:add_mob found")
	check(body and not body:find("effect%(") and not body:find("add_particle"),
		"P1: mobs:add_mob plays no particles")
end

-- P2: the constant (the one place for both factors).
do
	local src = read("mods/ENTITIES/grug_mobs/subtypes.lua")
	check(src:find("grug_mobs.LEADER = {size = 1.15, hp = 1.5}", 1, true) ~= nil,
		"P2: grug_mobs.LEADER = {size = 1.15, hp = 1.5}")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R29 P PORTABLE FAIL") end
print("R29 P PORTABLE PASS checks=" .. checks)
