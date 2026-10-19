-- Round 52 lane SPLIT portable test (round52-class-plan.md §3 "SPLIT", D6):
-- the per-class kit and talent files register exactly what the two single
-- files did. Loads the REAL grug_classes/talents.lua (which dofiles the
-- per-class talent files, scout_talents.lua and talent_windows.lua) and the
-- REAL grug_abilities/kits.lua (which dofiles the per-class kit files) plus
-- the unchanged grug_abilities/scout.lua under permissive stubs, and checks:
--   A. a deterministic dump -- every registered ability (non-function fields,
--      function fields as <fn>), the by_class and universal id order, the
--      Fireball projectile, talent_ids and tree_ids order, every tree and
--      talent definition (tier, chain, ranks, effects, flags, window, the
--      hard-chain parent), the effect vocabulary tables, the order of the
--      engine callbacks the files register and the names they export -- is
--      identical to expected.txt, the dump of main 7813165e before the split
--      (CORE-B adds the window API to the grug_classes export line,
--      CORE-A drops Mend's globalstep and die handler from the callback line);
--   B. no file adds a global;
--   C. the window glue (D6): a window started before a leave is gone after
--      the leave callbacks ran, its status icon cleared.
--
-- Usage (repo root): luajit tools/r52_split/portable_test.lua [REPO]
--   luajit tools/r52_split/portable_test.lua REPO --dump ROOT
--     prints the dump of the class files under ROOT instead (no checks).
-- Regenerate expected.txt (only for a deliberate registration change):
--   bash tools/r52_split/regen.sh [COMMIT]   (git show into a scratch dir)
local REPO = arg[1] or "."
local ROOT = REPO
local dump_only = arg[2] == "--dump"
if dump_only then ROOT = assert(arg[3], "--dump needs a ROOT") end

local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- A value that answers every index and call: what load time may touch
-- without the dump caring.
local any = {}
setmetatable(any, {
	__index = function() return any end,
	__call = function() return nil end,
})
local function permissive(t)
	return setmetatable(t, {__index = function() return any end})
end

-- Every engine or neighbour callback the files register, in order.
local events, callbacks = {}, {}
local function recorder(name)
	return function(...)
		events[#events + 1] = name
		callbacks[name] = callbacks[name] or {}
		local fn = select(select("#", ...), ...)
		if type(fn) == "function" then
			table.insert(callbacks[name], fn)
		end
	end
end

local current = "grug_classes"
local now_us = 1000000
core = setmetatable({
	get_modpath = function(mod) return ROOT .. "/mods/PLAYER/" .. mod end,
	get_current_modname = function() return current end,
	get_us_time = function() return now_us end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then
		return recorder("core." .. key)
	end
	return any
end})
vector, ItemStack, player_api = any, any, any
grug_core, grug_factions, grug_pvp, grug_mobs, grug_inventory =
	permissive({}), any, any, any, any
grug_xp = permissive({get_level = function(player) return player.level end})
grug_projectiles = permissive({register = function(name, def)
	events[#events + 1] = "grug_projectiles.register:" .. name
	grug_projectiles.defs = grug_projectiles.defs or {}
	grug_projectiles.defs[name] = def
end})
grug_classes = permissive({
	registered_classes = {warrior = {}, mage = {}, priest = {}, scout = {}},
	register_on_class_chosen = recorder("grug_classes.register_on_class_chosen"),
	get_class = function(player) return player.class end,
	apply_stats = function() end,
})
grug_abilities = permissive({registered = {}, by_class = {}, universal = {}})
function grug_abilities.register_ability(def)
	grug_abilities.registered[def.id] = def
	if def.universal then
		table.insert(grug_abilities.universal, def)
	else
		grug_abilities.by_class[def.class] = grug_abilities.by_class[def.class] or {}
		table.insert(grug_abilities.by_class[def.class], def)
	end
end

local globals_before = {}
for key in pairs(_G) do globals_before[key] = true end

current = "grug_classes"
dofile(ROOT .. "/mods/PLAYER/grug_classes/talents.lua")
current = "grug_abilities"
dofile(ROOT .. "/mods/PLAYER/grug_abilities/kits.lua")
dofile(ROOT .. "/mods/PLAYER/grug_abilities/scout.lua")

--
-- The dump.
--

local refs = {}
for _, def in pairs(grug_classes.registered_talents) do refs[def] = true end
for _, def in pairs(grug_classes.registered_trees) do refs[def] = true end
for _, def in pairs(grug_abilities.registered) do refs[def] = true end

local function sorted_keys(t)
	local keys = {}
	for key in pairs(t) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then return ta < tb end
		return a < b
	end)
	return keys
end

local function ser(value, depth)
	local kind = type(value)
	if kind == "function" then return "<fn>" end
	if kind == "string" then return (("%q"):format(value):gsub("\\\n", "\\n")) end
	if kind == "number" then return ("%.17g"):format(value) end
	if kind ~= "table" then return tostring(value) end
	if value == any then return "<any>" end
	-- A registered definition inside another one (a tree's talents, a
	-- talent's hard-chain parent) is named, not repeated.
	if depth > 0 and refs[value] then return "@" .. value.id end
	local parts = {}
	for _, key in ipairs(sorted_keys(value)) do
		parts[#parts + 1] = tostring(key) .. "=" .. ser(value[key], depth + 1)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function ids(list)
	local out = {}
	for i, def in ipairs(list) do out[i] = def.id end
	return table.concat(out, ",")
end

local lines = {}
local function add(line) lines[#lines + 1] = line end

add("universal " .. ids(grug_abilities.universal))
for _, class in ipairs(sorted_keys(grug_abilities.by_class)) do
	add("by_class." .. class .. " " .. ids(grug_abilities.by_class[class]))
end
for _, id in ipairs(sorted_keys(grug_abilities.registered)) do
	add("ability " .. id .. " " .. ser(grug_abilities.registered[id], 0))
end
for _, name in ipairs(sorted_keys(grug_projectiles.defs or {})) do
	add("projectile " .. name .. " " .. ser(grug_projectiles.defs[name], 0))
end
add("talent_ids " .. table.concat(grug_classes.talent_ids, ","))
add("tree_ids " .. table.concat(grug_classes.tree_ids, ","))
for _, id in ipairs(grug_classes.tree_ids) do
	add("tree " .. id .. " " .. ser(grug_classes.registered_trees[id], 0))
end
for _, id in ipairs(grug_classes.talent_ids) do
	add("talent " .. id .. " " .. ser(grug_classes.registered_talents[id], 0))
end
for _, name in ipairs({"TALENT_TIER_GATES", "TALENT_TIER_RANKS",
		"TALENT_CAPSTONE_RANKS", "TALENT_LEVELS_PER_POINT", "TALENT_EFFECT_KEYS",
		"TALENT_WINDOW_KEYS", "TALENT_LEVEL_SCALED_KEYS", "TALENT_SPELL_KEYS"}) do
	add("const " .. name .. " " .. ser(rawget(grug_classes, name), 0))
end
add("callbacks " .. table.concat(events, ","))
for _, name in ipairs({"grug_abilities", "grug_classes", "grug_core"}) do
	add("exports " .. name .. " " .. table.concat(sorted_keys(_G[name]), ","))
end
local dump = table.concat(lines, "\n") .. "\n"

if dump_only then
	io.write(dump)
	return
end

--
-- A. The dump against main's.
--

local handle = assert(io.open(REPO .. "/tools/r52_split/expected.txt", "rb"))
local expected = handle:read("*a")
handle:close()
if dump ~= expected then
	local want = {}
	for line in expected:gmatch("([^\n]*)\n") do want[#want + 1] = line end
	for i = 1, math.max(#want, #lines) do
		if want[i] ~= lines[i] then
			print("first difference at dump line " .. i)
			print("  expected: " .. tostring(want[i]))
			print("  got:      " .. tostring(lines[i]))
			break
		end
	end
end
check(dump == expected, "A the registration dump equals main's (expected.txt)")
check(ids(grug_abilities.by_class.warrior) ==
	"charge,mighty_blow,hamstring,taunt,hold_ground", "A the Warrior's ability order")
check(ids(grug_abilities.by_class.mage) ==
	"fireball,ice_nova,blink,cinderfall,glacial_ward", "A the Mage's ability order")
check(ids(grug_abilities.by_class.priest) ==
	"smite,heal,shield_spell,mend,word_of_ruin", "A the Priest's ability order")
check(table.concat(grug_classes.tree_ids, ",") ==
	"bulwark,ruin,ember,rime,mercy,reckoning,quarry,veil", "A the tree order")
check(#grug_classes.talent_ids == 64, "A 64 talents")

--
-- B. No new globals.
--

for key in pairs(_G) do
	check(globals_before[key], "B no file adds the global " .. tostring(key))
end

--
-- C. The window runtime (talent_windows.lua) and the leave glue.
--

local statuses = {}
grug_core.status_icons = {TALENT_WINDOWS = {hold_ground = "talent_hold_ground"}}
grug_core.set_status = function(player, id) statuses[player.name .. ":" .. id] = true end
grug_core.clear_status = function(player, id) statuses[player.name .. ":" .. id] = nil end
grug_core.clear_move_immunity = function() end
grug_core.clear_absorb_modifiers = function() end
local meta = {}
local player = {name = "w1", class = "warrior", level = 60}
function player.is_player() return true end
function player.get_player_name() return player.name end
function player.get_meta()
	return {
		get_string = function(_, key) return meta[key] or "" end,
		set_string = function(_, key, value) meta[key] = value end,
	}
end
check(grug_classes.start_talent_window(player, "hold_ground", 8),
	"C a window starts")
check(grug_classes.talent_window_active(player, "hold_ground"), "C it is active")
check(statuses["w1:talent_hold_ground"], "C its status icon is set")
for _, fn in ipairs(callbacks["core.register_on_leaveplayer"] or {}) do
	pcall(fn, player) -- the kit and scout leave handlers meet the permissive stubs
end
check(not grug_classes.talent_window_active(player, "hold_ground"),
	"C the leave handlers end the window")
check(not statuses["w1:talent_hold_ground"], "C and clear its status icon")
check(grug_classes.start_talent_window(player, "hold_ground", 8),
	"C a window starts again")
now_us = now_us + 9 * 1e6
check(not grug_classes.talent_window_active(player, "hold_ground"),
	"C a window ends at its expiry")

print(("r52_split portable test: %d checks passed"):format(checks))
