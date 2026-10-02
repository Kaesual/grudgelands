-- Round 29 Lane P portable test (spawn playtest fixes, round29-plan.md §7):
--   P1  mobs:add_mob places a mob without a particle puff;
--   P2  leaders have 1.5x HP at 1.15x size (the real registration is checked
--       in tools/r28_b2/portable_test.lua, the HP factor in tools/r28_s1);
--   P3  no legacy kill objective without an area names a target its kill
--       zone's recipe never spawns while another of its targets does spawn
--       (kinds by day and night, camps, leaders; faction guards stand at
--       their posts). Objectives none of whose targets spawn stay: they are
--       the accepted W-recipe-target warnings, counted here.
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

-- P3: shipped quest data against the shipped recipes.
local function list(dir, suffix)
	local out = {}
	local pipe = assert(io.popen('ls "' .. repo .. "/" .. dir .. '"'))
	for name in pipe:lines() do
		if name:sub(-#suffix) == suffix then out[#out + 1] = name end
	end
	pipe:close()
	table.sort(out)
	return out
end

local function bare(name) return name:match("^grug_mobs:(.+)$") or name end

local spawned = {}
for _, name in ipairs(list("mods/ENTITIES/grug_mobs/data/zones", ".spawns.json")) do
	local data = json.decode(read("mods/ENTITIES/grug_mobs/data/zones/" .. name))
	local recipe = data.recipe
	if recipe then
		local roles = {}
		local function add(rows)
			if type(rows) == "table" then
				for _, row in ipairs(rows) do roles[bare(row.role)] = true end
			end
		end
		for _, belt in ipairs(recipe.belts or {}) do
			local kinds = belt.kinds or {}
			for _, kind in pairs(kinds) do
				for _, clock in ipairs({"day", "night"}) do
					local rows = kind[clock]
					if rows == "open" then rows = kinds.open and kinds.open[clock] end
					add(rows)
				end
			end
		end
		for _, camp in ipairs(recipe.camps or {}) do add(camp.roster) end
		add(recipe.leaders)
		spawned[data.zone] = roles
	end
end

local mixed, absent, full = {}, 0, 0
for _, name in ipairs(list("mods/PLAYER/grug_quests/data/zones", ".json")) do
	local file_zone = name:match("^([^.]+)")
	local data = json.decode(read("mods/PLAYER/grug_quests/data/zones/" .. name))
	for _, quest in ipairs(data.quests) do
		for n, objective in ipairs(quest.objectives or {}) do
			local zone = type(objective.zone) == "string" and objective.zone or file_zone
			if objective.type == "kill" and not objective.area and objective.mobs and spawned[zone] then
				local yes, no = 0, {}
				for _, mob in ipairs(objective.mobs) do
					local role = bare(mob)
					if role:match("^guard_") or spawned[zone][role] then yes = yes + 1
					else no[#no + 1] = role end
				end
				if yes == 0 then absent = absent + 1
				elseif #no > 0 then mixed[#mixed + 1] = ("%s obj %d: %s"):format(quest.id, n, table.concat(no, ", "))
				else full = full + 1 end
			end
		end
	end
end
check(#mixed == 0, "P3: no objective names an unspawned target next to a spawned one: "
	.. table.concat(mixed, "; "))
check(full > 0, "P3: objectives with spawned targets seen")
print(("P3: %d legacy kill objectives with every target spawned, %d with none (W-recipe-target)"):format(
	full, absent))

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R29 P PORTABLE FAIL") end
print("R29 P PORTABLE PASS checks=" .. checks)
