-- Round 30 Lane C portable test (LuaJIT): the start NPC duplication.
--
-- `core.add_entity` stores an entity's staticdata in its mapblock as soon as
-- it activates, i.e. BEFORE start_npcs.lua's `install` writes the settlement
-- key. When that block is saved and unloaded before the next deactivation
-- pass, the pass keeps the reloaded copy and stores a second one, so every
-- NPC came back twice (the perf review's Dawnmere box: 53 objects for 13
-- placements; reproduced in lane C's engine run, where every Dawnmere block
-- held each NPC twice, once without `_grug_start`).
--
-- Loads the REAL grug_mobs/start_npcs.lua under a minimal engine model (the
-- add-time snapshot is taken like ServerEnvironment::addActiveObjectRaw) with
-- one start of three sockets and stand-ins for the three ways the families
-- claim (quest shell on activation, guard and villager on their first tick):
--   A. placement: every NPC installed, none removed while being placed; the
--      first snapshot carries `_grug_unplaced` and the key, the NPC does not;
--   B. the race: each block holds the first snapshot and the real NPC; on
--      reactivation the snapshot removes itself and the real NPC keeps its
--      socket, in either activation order; the heartbeat places nothing;
--   C. an ordinary reload (real NPCs only) removes nothing; an NPC without a
--      settlement key (an outpost guard) is not touched.
--
--   luajit tools/r30_c/portable_test.lua [REPO]
-- Prints "R30 C PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

------------------------------------------------------------------------------
-- Engine model.
------------------------------------------------------------------------------
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end

local serial, logs, steps, loaded, after = {}, {}, {}, {}, {}
local entity_defs = {}
local clock = 1000
core = {
	registered_entities = entity_defs,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	after = function(_, fn) after[#after + 1] = fn end,
	get_gametime = function() return clock end,
	pos_to_string = function(p) return ("(%d,%d,%d)"):format(p.x, p.y, p.z) end,
	get_node_or_nil = function() return {name = "default:dirt_with_grass"} end,
	-- Loaded but nobody near: the start-ready situation (no strikes).
	compare_block_status = function() return false end,
}

local live = {} -- the active objects, in activation order
local first_snapshot = {} -- entity -> what add_entity stored in the block
-- What the engine stores for an entity: its plain fields (mobs_redo's
-- clean_staticdata keeps no functions, no object and no `temp`).
local function snapshot(entity)
	local out = {}
	for k, v in pairs(entity) do
		if type(v) ~= "function" and k ~= "object" and k ~= "temp" and k ~= "name" then out[k] = copy(v) end
	end
	return out
end
-- Activation as mobs_redo's mob_activate: staticdata fields onto self, then
-- the family's after_activate.
local function activate(name, staticdata, pos)
	local def = assert(entity_defs[name], name)
	local object = {pos = copy(pos or {x = 0, y = 37, z = -2530}), valid = true}
	local entity = setmetatable({name = name, object = object}, {__index = def})
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	function object:set_yaw(y) self.yaw = y end
	local data = core.deserialize(staticdata)
	for k, v in pairs(data or {}) do entity[k] = v end
	live[#live + 1] = entity
	if def.after_activate then def.after_activate(entity) end
	return object, entity
end
core.add_entity = function(pos, name, staticdata)
	local object, entity = activate(name, staticdata, pos)
	-- ServerEnvironment::addActiveObjectRaw stores the staticdata now.
	if object.valid then first_snapshot[entity] = snapshot(entity) end
	return object
end
core.get_objects_inside_radius = function()
	local out = {}
	for _, entity in ipairs(live) do
		if entity.object.valid then out[#out + 1] = entity.object end
	end
	return out
end
-- A pass of the families' ticks (guard.lua and start_villagers.lua claim on
-- their first tick).
local function tick_all()
	for _, entity in ipairs(live) do
		if entity.object.valid and entity.on_tick then entity:on_tick() end
	end
end
-- The engine deactivates the objects of an unloaded area (on_deactivate with
-- removal = false) and forgets them.
local function deactivate_all()
	for _, entity in ipairs(live) do
		if entity.object.valid then
			mobs.mob_class.on_deactivate(entity, false)
			entity.object.valid = false
		end
	end
	live = {}
end
local function live_settlers()
	local out = {}
	for _, entity in ipairs(live) do
		if entity.object.valid then out[#out + 1] = entity end
	end
	return out
end

------------------------------------------------------------------------------
-- Mods: grug_core's start registry and stand-in families.
------------------------------------------------------------------------------
local ANCHOR = {x = 0, y = 37, z = -2530}
local SOCKETS = {
	{id = "gate_west", role = "guard_post", pos = {x = -4, y = 37, z = -2493}, yaw = 0},
	{id = "hall_quest", role = "quest", pos = {x = -11, y = 37, z = -2542}, yaw = 0},
	{id = "idle_green_bench", role = "idle", pos = {x = -6, y = 37, z = -2543}, yaw = 0},
}
local progress
grug_core = {
	start_identities = function() return {{race_id = "human", faction_id = "accord"}} end,
	settlement_socket_settlements = function()
		return {{key = "dawnmere", race_id = "human", anchor = ANCHOR}}
	end,
	settlement_sockets_at = function() return copy(SOCKETS) end,
	start_anchor = function() return ANCHOR end,
	capital_anchor = function() return nil end,
	start_ready = function() return true end,
	register_on_starts_progress = function(fn) progress = fn end,
}
local store = {}
mobs = {mob_class = {}}
function mobs:remove(entity) entity.object:remove() end
grug_mobs = {
	storage = {
		get_string = function(_, k) return store[k] or "" end,
		set_string = function(_, k, v) store[k] = v end,
	},
	place_on_ground = function() end,
	face_yaw = function(entity, yaw) entity._grug_face = yaw end,
}
-- The quest shell claims in after_activate (start_villagers.lua); the guard
-- claims on its first tick when it carries a key (guard.lua); a villager
-- claims on its first tick (start_villagers.lua amble/work tick).
local function claim_once(self, keyed_only)
	self.temp = self.temp or {}
	if (not keyed_only or self._grug_start) and not self.temp.claimed then
		self.temp.claimed = true
		grug_mobs.start_npc_claim(self)
	end
end
entity_defs["grug_mobs:elder_human"] = {after_activate = function(self) grug_mobs.start_npc_claim(self) end}
entity_defs["grug_mobs:guard_accord"] = {on_tick = function(self) claim_once(self, true) end}
entity_defs["grug_mobs:villager_human"] = {on_tick = function(self) claim_once(self, false) end}

dofile(ROOT .. "/mods/ENTITIES/grug_mobs/start_npcs.lua")
for _, fn in ipairs(loaded) do fn() end
local function heartbeat()
	clock = clock + 5
	for _, fn in ipairs(steps) do fn(5) end
end
local function count_logs(pattern)
	local n = 0
	for _, line in ipairs(logs) do if line:find(pattern, 1, true) then n = n + 1 end end
	return n
end
local function by_socket()
	local out, n = {}, 0
	for _, entity in ipairs(live_settlers()) do
		if entity._grug_socket then
			out[entity._grug_socket] = (out[entity._grug_socket] or 0) + 1
		end
		n = n + 1
	end
	return out, n
end

------------------------------------------------------------------------------
-- A. Placement at start-ready.
------------------------------------------------------------------------------
for _, fn in ipairs(after) do fn() end
tick_all()
local placed = live_settlers()
eq(#placed, 3, "A: three NPCs placed")
eq(count_logs("placed at socket"), 3, "A: three placement lines")
eq(count_logs("removed itself"), 0, "A: nothing removed while placing")
for _, entity in ipairs(placed) do
	local name = entity.name
	eq(entity._grug_start, "dawnmere", "A: " .. name .. " installed with its settlement key")
	check(type(entity._grug_socket) == "string", "A: " .. name .. " booked on a socket")
	eq(entity._grug_unplaced, nil, "A: " .. name .. " carries no unplaced marker")
	local first = first_snapshot[entity]
	check(first ~= nil, "A: " .. name .. " has an add-time snapshot")
	eq(first and first._grug_unplaced, true, "A: the add-time snapshot carries the marker")
	eq(first and first._grug_start, "dawnmere", "A: the add-time snapshot carries the key")
	eq(first and first._grug_socket, nil, "A: the add-time snapshot predates the install")
end
local census = grug_mobs.start_npc_census()[1]
eq(census.live, 3, "A: census live")
eq(census.marked, 3, "A: census marked")

------------------------------------------------------------------------------
-- B. The block unload before the deactivation pass: each block holds the
--    first snapshot and the real NPC; both come back.
------------------------------------------------------------------------------
local stored = {}
for _, entity in ipairs(placed) do
	stored[#stored + 1] = {name = entity.name, first = first_snapshot[entity], real = snapshot(entity),
		pos = entity.object:get_pos()}
end
for _, order in ipairs({"first snapshot first", "real NPC first"}) do
	deactivate_all()
	logs = {}
	for _, row in ipairs(stored) do
		local a, b = row.first, row.real
		if order == "real NPC first" then a, b = b, a end
		activate(row.name, core.serialize(a), row.pos)
		activate(row.name, core.serialize(b), row.pos)
	end
	tick_all()
	tick_all()
	local sockets, n = by_socket()
	eq(n, 3, "B (" .. order .. "): three NPCs remain")
	for _, socket in ipairs(SOCKETS) do
		eq(sockets[socket.id], 1, "B (" .. order .. "): one NPC on " .. socket.id)
	end
	for _, entity in ipairs(live_settlers()) do
		eq(entity._grug_unplaced, nil, "B (" .. order .. "): the survivor is the real " .. entity.name)
	end
	eq(count_logs("first snapshot"), 3, "B (" .. order .. "): three snapshots removed themselves")
	heartbeat()
	eq(count_logs("placed at socket"), 0, "B (" .. order .. "): the heartbeat places nothing")
	eq(#live_settlers(), 3, "B (" .. order .. "): the heartbeat removes nothing")
	eq(grug_mobs.start_npc_census()[1].live, 3, "B (" .. order .. "): census live")
end

------------------------------------------------------------------------------
-- C. An ordinary reload, and an NPC without a settlement key.
------------------------------------------------------------------------------
deactivate_all()
logs = {}
for _, row in ipairs(stored) do activate(row.name, core.serialize(row.real), row.pos) end
tick_all()
eq(#live_settlers(), 3, "C: an ordinary reload keeps all three")
eq(count_logs("removed itself"), 0, "C: nothing removed on an ordinary reload")
local _, outpost = activate("grug_mobs:villager_human", core.serialize({_grug_camp = "x"}))
eq(grug_mobs.start_npc_claim(outpost), true, "C: a keyless NPC is no settlement NPC")
check(outpost.object.valid, "C: a keyless NPC stays")

if failures > 0 then
	print(("%d checks, %d failures"):format(checks, failures))
	os.exit(1)
end
print(("R30 C PORTABLE PASS checks=%d"):format(checks))
