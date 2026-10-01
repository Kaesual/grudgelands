-- Round 28 Lane B4 content migration, step 1 (one-off; ran on main 7af1aaf2,
-- before the Lua content generators were deleted). Loads the REAL
-- grug_quests registry and the four content files under a minimal `core`
-- stub and writes, into OUT_DIR:
--   legacy_raw.json       every register_npc / register_quest call in
--                         registration order, with the arguments as written
--                         (the input of split_quests.py);
--   legacy_registry.json  the registry those calls produced, in the canonical
--                         form `canonical.lua` defines (the equivalence oracle
--                         the portable test and the engine probe compare
--                         against).
--
-- Usage (repo root): luajit tools/r28_b4_quests/migrate/dump_legacy.lua OUT_DIR [OLD_ROOT]
--   OLD_ROOT: a tree that still has content*.lua (main 7af1aaf2 extracted to a
--   scratch directory); default this checkout.
local OUT = assert(arg and arg[1], "usage: dump_legacy.lua OUT_DIR [OLD_ROOT]")
local OLD = arg[2] or "."
local json = dofile("tools/r28_b4_quests/json.lua")
local canonical = dofile("tools/r28_b4_quests/canonical.lua")

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy
core = {register_on_mods_loaded = function() end}
function ItemStack(item) return item end

grug_quests = {}
local Q = grug_quests
dofile(OLD .. "/mods/PLAYER/grug_quests/registry.lua")
local calls = {}
local register_npc, register_quest = Q.register_npc, Q.register_quest
function Q.register_npc(id, def)
	calls[#calls + 1] = {kind = "npc", id = id, def = deep_copy(def)}
	return register_npc(id, def)
end
function Q.register_quest(id, def)
	calls[#calls + 1] = {kind = "quest", id = id, def = deep_copy(def)}
	return register_quest(id, def)
end
for _, file in ipairs({"content_npcs", "content", "content_regions", "content_civic"}) do
	dofile(OLD .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end

local function write(name, value)
	local f = assert(io.open(OUT .. "/" .. name, "w"))
	f:write(json.encode(value, 1), "\n")
	f:close()
end
write("legacy_raw.json", calls)
write("legacy_registry.json", canonical.registry(Q.registered_quests, Q.registered_npcs))
local quests, npcs = 0, 0
for _, call in ipairs(calls) do
	if call.kind == "quest" then quests = quests + 1 else npcs = npcs + 1 end
end
print(("dumped %d quests, %d NPCs"):format(quests, npcs))
