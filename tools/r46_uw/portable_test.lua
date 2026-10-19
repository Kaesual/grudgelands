-- Round 46 lane UW portable test (LuaJIT): underground spawns from -1, light
-- 7, sight and the elite roll (round46-plan.md §4.10, rulings 4 and 15),
-- and 10 torches per coal or charcoal.
--
--   luajit tools/r46_uw/portable_test.lua [REPO]
--
-- A. The real spawn roster (tools/r24_density_xp/roster.lua: spawn_policy.lua
--    and every mob file init.lua loads): every underground row (top at or
--    below grug_mobs.UNDERGROUND_TOP = -1) spawns up to light 7 or in any
--    light, has no day_toggle and carries the underground on_spawn; the rows
--    that ended at -40 now reach up to -1; no surface row reaches below 0
--    except the water rows (Kraken, Reed Angelfish, since Round 51 the sharks
--    and the Tide Goby).
-- B. spawn_policy_allows at the boundary: an underground family from node
--    y -2 down, nothing at y -1 (the one layer between surface and
--    underground rows), the start footprint first, a def-elite (golem) only
--    from the elite floor; spawn_domain_at and spawn_clock_for agree.
-- C. underground_spawned: a hostile's view range reaches mob_nospawn_range
--    + 2, a critter's stays; the elite roll (scripted math.random) promotes
--    below UNDERGROUND_ELITE_CHANCE only at or above the level floor,
--    outside the start footprint and without `skip_elite`; the row's own
--    on_spawn still runs first.
-- D. levels.lua pending_level: the level ensure_init will give, unwritten.
-- E. The torch row of the Basic catalog: 10 per coal lump or charcoal (one
--    recipe with the coal group since Round 46 lane ID; charcoal is in it).
-- Prints "R46 UW PORTABLE PASS checks=<n>" or raises.

local repo = arg and arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---------------------------------------------------------------------------
-- A. The real rows
-- ---------------------------------------------------------------------------
local roster = dofile(repo .. "/tools/r24_density_xp/roster.lua")(repo)
check(#roster.failed == 0, "every mob file loads: " .. table.concat(roster.failed, "; "))
local gm = roster.grug_mobs
check(gm.UNDERGROUND_TOP == -1, "A the underground begins below y -1")

local TOP = gm.UNDERGROUND_TOP
local reaching = {} -- mob -> true for underground rows whose top is -1
local underground_rows = 0
local raw_by_index = roster.raw_rows
for index, row in ipairs(roster.rows) do
	local raw = raw_by_index[index]
	if row.max_height and row.max_height <= TOP then
		underground_rows = underground_rows + 1
		local light = row.max_light
		check(light == nil or light == 7, "A " .. row.name .. " underground light 7 or any: " ..
			tostring(light))
		check(row.day_toggle == nil, "A " .. row.name .. " underground: no day_toggle")
		check(type(row.on_spawn) == "function" and row.on_spawn ~= raw.on_spawn,
			"A " .. row.name .. " underground: the underground on_spawn")
		if row.max_height == TOP then reaching[row.name] = true end
	else
		-- The water rows reach below 0 (Round 51 MOBS M2 added the sharks and
		-- the Tide Goby to the Kraken and the Reed Angelfish).
		local water_row = ({["grug_mobs:kraken"] = true, ["grug_mobs:reed_angelfish"] = true,
			["grug_mobs:bay_shark"] = true, ["grug_mobs:abyssal_shark"] = true,
			["grug_mobs:goby"] = true})[row.name]
		check((row.min_height or 0) >= 0 or water_row,
			"A " .. row.name .. " surface row stays above ground: " .. tostring(row.min_height))
	end
end
-- 18 since lane DP: the deep rows of the Land Guard and the Rift Spawn moved
-- into the depth pulse (depth_pulse.lua).
check(underground_rows >= 18, "A the underground rows are seen: " .. underground_rows)
for _, name in ipairs({"zombie", "giant_spider", "stone_golem", "mesa_golem", "cave_bat",
		"cave_crawler", "giant_rat", "spiderling"}) do
	check(reaching["grug_mobs:" .. name], "A " .. name .. " reaches up to -1")
end
local reach_count = 0
for _ in pairs(reaching) do reach_count = reach_count + 1 end
check(reach_count == 8, "A exactly the former -40 rows reach -1: " .. reach_count)

-- ---------------------------------------------------------------------------
-- B. The policy at the boundary
-- ---------------------------------------------------------------------------
_G.grug_mobs = gm
local level_here = 3
local footprint = false
_G.grug_zones = {
	mob_level_at = function() return level_here end,
	id_at = function() return nil end,
	biome_at = function() return "grug_meadows" end,
}
_G.grug_core = {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125}
_G.core = {settings = {get = function(_, key)
	if key == "mob_nospawn_range" then return "24" end
end}, get_timeofday = function() return 0.5 end}
gm.in_start_footprint = function() return footprint end
local allows = gm.spawn_policy_allows
check(allows("grug_mobs:zombie", {x = 0, y = -2, z = 0}), "B zombie at node y -2")
check(allows("grug_mobs:cave_bat", {x = 0, y = -2, z = 0}), "B cave bat at node y -2")
check(allows("grug_mobs:zombie", {x = 0, y = -39, z = 0}), "B zombie in the former dead band")
check(not allows("grug_mobs:zombie", {x = 0, y = -1, z = 0}), "B nothing at node y -1")
check(not allows("grug_mobs:wolf", {x = 0, y = -2, z = 0}), "B no surface family underground")
check(gm.spawn_domain_at({x = 0, y = -2, z = 0}) == "underground" and
	gm.spawn_clock_for("grug_mobs:zombie", {x = 0, y = -2, z = 0}) == "any",
	"B domain and clock underground from -2")
footprint = true
check(not allows("grug_mobs:zombie", {x = 0, y = -5, z = 0}), "B start footprint refuses a hostile")
check(allows("grug_mobs:cave_bat", {x = 0, y = -5, z = 0}), "B a critter in the footprint")
footprint = false
level_here = gm.UNDERGROUND_ELITE_MIN_LEVEL - 1
check(not allows("grug_mobs:stone_golem", {x = 0, y = -5, z = 0}), "B no golem below the floor")
check(allows("grug_mobs:zombie", {x = 0, y = -5, z = 0}), "B a normal mob below the floor")
level_here = gm.UNDERGROUND_ELITE_MIN_LEVEL
check(allows("grug_mobs:stone_golem", {x = 0, y = -5, z = 0}), "B golem at the floor")
level_here = 60
-- Lane DP: the Land Guard has no ABM row any more (the depth pulse brings it,
-- outside this policy), so the closed underground list refuses it.
check(not allows("grug_mobs:land_guard", {x = 0, y = -1200, z = 0}), "B no Land Guard row deep")

-- ---------------------------------------------------------------------------
-- C. underground_spawned and the row hook
-- ---------------------------------------------------------------------------
local promoted, level = {}, 10
local real_pending_level = gm.pending_level
gm.set_tier = function(ent, tier) promoted[#promoted + 1] = tier; ent._grug_tier = tier end
gm.pending_level = function() return level end
local rolls = {}
local real_random = math.random
math.random = function(...)
	if select("#", ...) == 0 and #rolls > 0 then return table.remove(rolls, 1) end
	return real_random(...)
end
local function fresh(name, view)
	return {name = name, object = {}, view_range = view}
end
local pos = {x = 0, y = -20, z = 0}
check(gm.underground_view_range() == 26, "C sight = nospawn 24 + 2")
local zombie = fresh("grug_mobs:zombie", 14)
rolls = {0.5}
check(not gm.underground_spawned(zombie, pos), "C no elite on a high roll")
check(zombie.view_range == 26, "C zombie sees the spawn distance")
local far = fresh("grug_mobs:crystal_shard", 30)
rolls = {0.5}
gm.underground_spawned(far, pos)
check(far.view_range == 30, "C a longer view range stays")
local bat = fresh("grug_mobs:cave_bat", 8)
rolls = {0.0}
check(not gm.underground_spawned(bat, pos) and bat.view_range == 8 and #promoted == 0,
	"C a critter keeps its sight and never rolls")
rolls = {0.039}
check(gm.underground_spawned(fresh("grug_mobs:zombie", 14), pos) and
	promoted[#promoted] == "elite", "C a roll under 4 % promotes")
local before = #promoted
rolls = {0.04}
check(not gm.underground_spawned(fresh("grug_mobs:zombie", 14), pos) and #promoted == before,
	"C exactly 4 % does not")
level = gm.UNDERGROUND_ELITE_MIN_LEVEL - 1
rolls = {0.0}
check(not gm.underground_spawned(fresh("grug_mobs:zombie", 14), pos) and #promoted == before,
	"C never below the level floor")
level = 30
footprint = true
rolls = {0.0}
check(not gm.underground_spawned(fresh("grug_mobs:zombie", 14), pos) and #promoted == before,
	"C never in a start footprint")
footprint = false
rolls = {0.0}
local skipped = fresh("grug_mobs:zombie", 14)
check(not gm.underground_spawned(skipped, pos, true) and #promoted == before and
	skipped.view_range == 26, "C skip_elite keeps the sight, skips the roll")
-- The prepared row's hook: the row's own on_spawn first, then the roll.
local order = {}
local row = gm.prepare_spawn_row({name = "grug_mobs:zombie", max_height = -1,
	min_height = -31000, max_light = 7, day_toggle = false,
	on_spawn = function() order[#order + 1] = "own" end})
local real_spawned = gm.underground_spawned
gm.underground_spawned = function() order[#order + 1] = "underground" end
row.on_spawn(fresh("grug_mobs:zombie", 14), pos)
gm.underground_spawned = real_spawned
check(order[1] == "own" and order[2] == "underground" and row.day_toggle == nil,
	"C the row's own hook, then the underground one")
-- Over many rolls: about 4 % promoted.
math.random = real_random
math.randomseed(46)
local count, n = 0, 20000
gm.set_tier = function(ent, tier) ent._grug_tier = tier end
for _ = 1, n do
	if gm.underground_spawned(fresh("grug_mobs:giant_spider", 12), pos) then count = count + 1 end
end
check(count > n * 0.035 and count < n * 0.045, "C about 4 % elite: " .. count .. "/" .. n)

-- ---------------------------------------------------------------------------
-- D. pending_level
-- ---------------------------------------------------------------------------
gm.pending_level = real_pending_level
math.round = math.round or function(x) return math.floor(x + 0.5) end
gm.register_level_cfg("test:mob", {_grug_min_level = 3})
_G.grug_core.mob_level_at = function(p) return p.y < -100 and 20 or 1 end
local mob = {name = "test:mob", object = {get_pos = function() return {x = 0, y = -5, z = 0} end}}
check(gm.pending_level(mob) == 3 and mob._grug_level == nil, "D the def floor, unwritten")
mob.object.get_pos = function() return {x = 0, y = -500, z = 0} end
check(gm.pending_level(mob) == 20, "D the field level")
mob._grug_level = 7
check(gm.pending_level(mob) == 7, "D a settled level wins")
check(gm.pending_level({name = "unknown"}) == nil, "D no config: nil")

-- ---------------------------------------------------------------------------
-- E. Torches
-- ---------------------------------------------------------------------------
-- Lane ID merged the two rows into one (the coal group: coal lump and
-- charcoal).
local catalog = dofile(repo .. "/mods/PLAYER/grug_jobs/basic_recipes.lua")
local torches = {}
for _, recipe in ipairs(catalog.recipes) do
	if recipe.output == "default:torch" then
		torches[#torches + 1] = recipe
		check(#recipe.ingredients == 2 and recipe.ingredients[1].group == "coal" and
			recipe.ingredients[2].group == "stick" and recipe.ingredients[2].n == 1 and
			recipe.ingredients[1].n == 1, "E the torch row is one coal and one stick")
	end
end
check(#torches == 1 and torches[1].count == 10, "E one torch row: 10 per coal or charcoal")
local smelting = io.open(repo .. "/mods/ITEMS/grug_smelting/recipes.lua"):read("*a")
check(smelting:find("groups = {grug_furnace_fuel = 1, coal = 1}", 1, true) ~= nil,
	"E charcoal is in the coal group")
local light = io.open(repo .. "/mods/BASE/default/torch.lua"):read("*a")
local twelve = 0
for _ in light:gmatch("light_source = 12") do twelve = twelve + 1 end
check(twelve == 3, "E the torch light stays 12 (floor, wall, ceiling)")

print(("R46 UW PORTABLE PASS checks=%d"):format(checks))
