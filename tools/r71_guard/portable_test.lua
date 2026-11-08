-- Round 71 lane GUARD portable test (LuaJIT): the rules inside an Expedition.
-- Loads the shipped grug_core/protection.lua, grug_mobs/spawn_policy.lua,
-- grug_expeditions catalogue, template reader and guard.lua on stubs. The respawn
-- seam in grug_home/travel.lua is tested in tools/r69_home, the real game in
-- tools/r71_guard/run.sh. Prints "R71 GUARD PORTABLE PASS checks=<n>".
--
--   luajit tools/r71_guard/portable_test.lua [REPO]
--
--   A  the world exception: only refused places ask; nil, true, false and a hint
--   B  the spawn field: every row at any y, the sea's too; the map stays open
--   C  guard.lua's answers: digging, mounts, the respawn row, the field
--   D  the template's `dig` line
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local C = dofile(repo .. "/mods/PLAYER/grug_expeditions/catalogue.lua")
local minp, maxp = C.slot_box(1)
local inside = {x = minp.x + 10, y = minp.y + 5, z = minp.z + 10}

-- ---- A. The world exception ---------------------------------------------------
local world_refuses, asked
_G.core = {is_protected = function() return false end,
	check_player_privs = function(_, privs) return false end}
_G.grug_zones = {hard_protection_kind_at = function() return nil end,
	territory_rule_at = function() return "immutable" end,
	water_class_at = function() return "deep_ocean" end}
_G.grug_core = {zone_authority_installed = function() return true end,
	get_player_faction = function() return "accord" end,
	world_protected_for_faction = function() return world_refuses end,
	world_feature_at = function() return nil end}
dofile(repo .. "/mods/CORE/grug_core/protection.lua")

world_refuses = true
check(core.is_protected(inside, "ann") == true, "A no provider: the world rule stands")
check(grug_core.protection_hint(inside, "ann") == "Open sea – protected", "A the sea's hint")
local answer, hint = nil, nil
asked = 0
grug_core.register_world_exception(function()
	asked = asked + 1
	return answer, hint
end)
check(core.is_protected(inside, "ann") == true and asked == 1, "A nil keeps the world rule")
check(grug_core.protection_hint(inside, "ann") == "Open sea – protected", "A nil keeps its hint")
answer, hint = false, "Somewhere – protected"
check(core.is_protected(inside, "ann") == true, "A false refuses")
check(grug_core.protection_hint(inside, "ann") == "Somewhere – protected", "A false names why")
answer, hint = true, nil
check(core.is_protected(inside, "ann") == false, "A true lifts the world rule")
check(grug_core.protection_hint(inside, "ann") == nil, "A nothing to explain")
check(core.is_protected(inside, "") == true, "A an empty actor stays refused")
world_refuses, asked = false, 0
check(core.is_protected({x = 0, y = 0, z = 0}, "ann") == false and asked == 0,
	"A a place the world rule allows never asks")

-- ---- B. The spawn field ---------------------------------------------------------
local level = 3
_G.core = {settings = {get_bool = function() return true end, get = function() return nil end},
	register_globalstep = function() end, register_on_leaveplayer = function() end,
	get_objects_inside_radius = function() return {} end,
	get_timeofday = function() return 0.5 end}
_G.grug_core = {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125}
_G.grug_zones = {mob_level_at = function() return level end, id_at = function() return nil end,
	biome_at = function() return "grug_meadows" end}
_G.grug_mapgen = nil
_G.grug_mobs = {spawn_regions = {fallback_palettes = function() return {}, {}, {} end}}
dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")
grug_mobs.in_start_footprint = function() return false end
local allows = grug_mobs.spawn_policy_allows
local field_pos = {x = 8000, y = -60, z = 0}
check(allows("grug_mobs:zombie", field_pos) == true, "B no field set: an underground row passes")
check(allows("grug_mobs:kraken", {x = 8000, y = 2, z = 0}) == true, "B no field set: the Kraken")

-- ---- C. guard.lua ---------------------------------------------------------------
local run = {id = 7, slot = 1, expedition = "test_vault", state = "running", minp = minp,
	maxp = maxp, entered = {ann = true}, places = {arrival = {x = 8, y = 5, z = 8}}}
local at_run, members = nil, {ann = true, bob = true}
local nodes = {}
local exception, summon_guard, respawn_row
_G.grug_expeditions = {slot_box = C.slot_box, slot_at = C.slot_at, catalogue = C,
	run_at = function(pos) return C.slot_at(pos) and at_run or nil end,
	belongs = function(_, who)
		return members[type(who) == "string" and who or who:get_player_name()] == true
	end,
	definition = C.definition,
	start_arrival = function() return {x = 8, y = 4.51, z = 8} end,
	templates = {test_vault = {dig = {["default:stone_with_tin"] = true}}}}
-- The run's tier's marks (init.lua written): the test row's tier writes the file's.
grug_expeditions.written = function() return grug_expeditions.templates.test_vault end
_G.core.get_node_or_nil = function(pos) return nodes[pos] end
_G.core.register_on_dieplayer = function() end
_G.core.register_on_leaveplayer = function() end
_G.grug_mounts = {register_summon_guard = function(fn) summon_guard = fn end}
-- Round 72 (MINT): guard.lua also registers the lava hold and the Return Home refusal in
-- lava; tools/r72_mint tests both.
_G.grug_home = {register_respawn_home = function(fn) respawn_row = fn end,
	register_return_guard = function() end}
_G.grug_core.register_world_exception = function(fn) exception = fn end
_G.grug_core.register_lava_hold = function() end
dofile(repo .. "/mods/PLAYER/grug_expeditions/guard.lua")

-- the field: the slots and the margin, at any y, every row
local _, last = C.slot_box(C.SLOTS)
local function field_refuses(mob, x, y, z) return allows(mob, {x = x, y = y, z = z}) == false end
for _, mob in ipairs({"grug_mobs:kraken", "grug_mobs:bay_shark", "grug_mobs:abyssal_shark",
		"grug_mobs:goby", "grug_mobs:reed_angelfish", "grug_mobs:zombie", "grug_mobs:cave_bat"}) do
	for _, y in ipairs({-80, -49, -23, 2, 30}) do
		check(field_refuses(mob, minp.x, y, minp.z), "B " .. mob .. " in the first box at " .. y)
		check(field_refuses(mob, last.x + 320, y, last.z + 320), "B " .. mob .. " at the far corner")
		check(field_refuses(mob, minp.x - 320, y, minp.z - 320), "B " .. mob .. " at the near corner")
	end
end
check(allows("grug_mobs:kraken", {x = minp.x - 321, y = 2, z = minp.z}) == true,
	"B the Kraken one node west of the field")
check(allows("grug_mobs:kraken", {x = last.x + 321, y = 2, z = minp.z}) == true,
	"B the Kraken one node east of the field")
check(allows("grug_mobs:kraken", {x = minp.x, y = 2, z = last.z + 321}) == true,
	"B the Kraken one node north of the field")
check(allows("grug_mobs:kraken", {x = 4100, y = 2, z = 0}) == true, "B the open sea on the map side")
check(allows("grug_mobs:zombie", {x = 4100, y = -60, z = 0}) == true, "B the rock on the map side")
check(allows("grug_mobs:zombie", {x = 0, y = -60, z = 0}) == true, "B the map")

-- digging
local function dig(pos, node, who, state)
	nodes[pos] = {name = node}
	run.state = state or "running"
	at_run = run
	return exception(pos, who)
end
local HINT = "Expedition – protected"
local ore = {x = minp.x + 3, y = minp.y + 3, z = minp.z + 3}
check(dig(ore, "default:stone_with_tin", "ann") == true, "C a member digs a marked node")
check(dig(ore, "default:stone_with_tin", "bob") == true, "C any member, entered or not")
local allowed, why = dig(ore, "default:stonebrick", "ann")
check(allowed == false and why == HINT, "C the hull stays refused, with the Expedition's hint")
allowed, why = dig(ore, "air", "ann")
check(allowed == false and why == HINT, "C the dug cell takes no placement")
allowed, why = dig(ore, "default:stone_with_tin", "eve")
check(allowed == false and why == HINT, "C a stranger is refused")
for _, state in ipairs({"preparing", "ready", "ended"}) do
	check(dig(ore, "default:stone_with_tin", "ann", state) == false, "C refused in state " .. state)
end
at_run = nil
nodes[ore] = {name = "default:stone_with_tin"}
allowed, why = exception(ore, "ann")
check(allowed == false and why == HINT, "C a box without a run: refused, the same hint")
nodes[ore] = nil
at_run = run
run.state = "running"
check(exception(ore, "ann") == false, "C an unloaded node is refused")
check(exception({x = 0, y = -60, z = 0}, "ann") == nil, "C the map is not the guard's")
check(exception({x = minp.x - 1, y = minp.y, z = minp.z}, "ann") == nil, "C beside the box neither")

-- mounts
check(type(summon_guard(nil, inside)) == "string", "C no mount in a box")
check(type(summon_guard(nil, maxp)) == "string", "C no mount at the far corner")
check(summon_guard(nil, {x = maxp.x + 1, y = maxp.y, z = maxp.z}) == nil, "C beside the box")
check(summon_guard(nil, {x = 0, y = 2, z = 0}) == nil, "C mounts on the map")

-- the respawn row
local function player(name, pos)
	return {get_player_name = function() return name end, get_pos = function() return pos end}
end
vector = {add = function(a) return a end, subtract = function(a) return a end,
	distance = function() return 100 end} -- the look on arrival: tools/r69_home section G
local saved = {}
grug_expeditions.saved_origin = function(p) return saved[p:get_player_name()] end
local CAPITAL = {x = 100, y = 10, z = 100}
core.load_area = function() end
grug_home.waystone_pos = function(id) return id == "highcourt" and CAPITAL or nil end
grug_home.waystone_arrival = function(id) return id == "highcourt" and {x = 101, y = 9.51, z = 100} or nil end
at_run = run
local row = respawn_row(player("ann", inside))
check(row and row.id == "expedition:7" and row.arrival.y == 4.51 and row.pos == run.places.arrival,
	"C a death in the run")
check(respawn_row(player("bob", inside)) == nil, "C a member who never entered")
check(respawn_row(player("ann", {x = 0, y = 2, z = 0})) == nil, "C a death outside the box")
members.ann = nil
check(respawn_row(player("ann", inside)) == nil, "C someone who no longer belongs")
members.ann = true
at_run = nil
check(respawn_row(player("ann", inside)) == nil, "C the run ended meanwhile, nothing saved: the home")
saved.ann = "highcourt"
local origin = respawn_row(player("ann", inside))
check(origin and origin.id == "expedition_origin:highcourt" and origin.pos == CAPITAL and
	origin.arrival.x == 101, "C the run gone: the capital they came from")
check(respawn_row(player("ann", {x = 0, y = 2, z = 0})) == nil, "C outside a box the home as ever")
saved.ann = "gone"
check(respawn_row(player("ann", inside)) == nil, "C a capital without a stone: the home")

-- ---- D. The template's dig line --------------------------------------------------
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")
local function head(dig_line)
	return "grudgelands-expedition-template 1\nname t\nsize 16 16 16\nnode default:stone\n" ..
		"node default:stone_with_tin\n" .. dig_line .. "data 1\nx"
end
local function inflate() return string.rep("\0", 2 * 16 * 16 * 16) end
check(T.parse(head("dig default:stone_with_tin\n"), inflate, "t").dig["default:stone_with_tin"],
	"D the mark is read")
check(next(T.parse(head(""), inflate, "t").dig) == nil, "D no line, no mark")
check(not pcall(T.parse, head("dig default:coalblock\n"), inflate, "t"), "D a node off the palette")
check(not pcall(T.parse, head("dig\n"), inflate, "t"), "D an empty mark")

print("R71 GUARD PORTABLE PASS checks=" .. checks)
