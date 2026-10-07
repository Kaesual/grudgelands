-- Round 41 lane UP portable test: the hosting platform's upgrade contract
-- (round41-plan.md §4.6, docs/technical/upgrade-contract.md). Loads the REAL
-- files under minimal `core` stubs:
--
--   A. the records and the trigger (grug_core/map_reset.lua): a setting
--      above the world's record clears, the record follows after every mod,
--      a missing record is 0, a failing clear stops the load;
--   B. the clears are idempotent: the world preparation keeps only its mode
--      (starts_preload.lua), grug_mobs keeps only its liveness generations
--      (map_reset.lua), the housing claims go and placed stones need a new
--      one while the id counter stays (registry.lua);
--   C. the relocation (grug_classes/selection.lua): an existing character is
--      held until the preparation is ready and its race start has loaded,
--      then moved there without the arrival flow, its home claim cleared and
--      its record written; nothing else changes; a failed load disconnects
--      it without a record and the next join retries;
--   D. new characters (on_newplayer, no stored race) record the world's
--      value and are never moved; an arrival records it too; the creation
--      stasis decides nothing;
--   E. unknown ids in saved state: quests (state.lua), waypoints
--      (waypoints_core.lua), achievements and cloaks (achievements core.lua);
--   F. the declaration as committed; its rules are tools/check_upgrade.py's
--      own self-test (run by every check, and by --self-test).
--
-- Usage (repo root): luajit tools/r41_up/portable_test.lua [repo]
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local repo = arg and arg[1] or "."
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
local function read(path)
	local f = assert(io.open(path, "rb"), "cannot read " .. path)
	local text = f:read("*a")
	f:close()
	return text
end
local function noop() end

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy

-- core.serialize/deserialize as a registry: the text is an index.
local serial = {}
local function serialize(value)
	serial[#serial + 1] = deep_copy(value)
	return "#" .. #serial
end
local function deserialize(text)
	local index = tonumber((text or ""):match("^#(%d+)$"))
	return index and deep_copy(serial[index]) or nil
end

-- A mod storage / meta on a plain table ("" deletes, like the engine).
local function new_store(t)
	t = t or {}
	local s = {data = t}
	function s.get_string(_, k) return t[k] or "" end
	function s.set_string(_, k, v)
		if v == "" then t[k] = nil else t[k] = v end
	end
	function s.get_int(_, k) return math.floor(tonumber(t[k]) or 0) end
	function s.set_int(_, k, v) t[k] = tostring(v) end
	function s.get_keys()
		local keys = {}
		for k in pairs(t) do keys[#keys + 1] = k end
		table.sort(keys)
		return keys
	end
	return s
end
local function snapshot(t)
	local keys = {}
	for k, v in pairs(t) do keys[#keys + 1] = k .. "=" .. tostring(v) end
	table.sort(keys)
	return table.concat(keys, "\n")
end

-- Loads the real map_reset.lua into `game` (a grug_core table) with its own
-- storage table and setting; returns the module and its callbacks.
local function load_map_reset(game, setting, world)
	local cb = {mods_loaded = {}, newplayer = {}, join = {}}
	local logs = {}
	-- This stub stays the global `core`: the module logs through it later.
	core = {
		settings = {get = function(_, key)
			if key == "grug_reset_world" then return setting end
		end},
		get_mod_storage = function() return new_store(world) end,
		register_on_mods_loaded = function(fn) cb.mods_loaded[#cb.mods_loaded + 1] = fn end,
		register_on_newplayer = function(fn) cb.newplayer[#cb.newplayer + 1] = fn end,
		register_on_joinplayer = function(fn) cb.join[#cb.join + 1] = fn end,
		log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
	}
	local saved_game = rawget(_G, "grug_core")
	grug_core = game
	dofile(repo .. "/mods/CORE/grug_core/map_reset.lua")
	grug_core = saved_game
	cb.logs = logs
	return game.map_reset, cb
end
local function mods_loaded(cb)
	for _, fn in ipairs(cb.mods_loaded) do fn() end
end
local function meta_player(name, t)
	local meta = new_store(t)
	return {get_meta = function() return meta end,
		get_player_name = function() return name end}
end

--
-- A. Records and trigger.
--
do
	local world = {}
	local M, cb = load_map_reset({}, nil, world)
	eq(M.pending(), false, "A no setting: nothing pending")
	eq(M.applied, 0, "A no setting, no record: the applied value is 0")
	local ran = 0
	M.clear("x", function() ran = ran + 1 end)
	eq(ran, 0, "A no reset: a clear does not run")
	mods_loaded(cb)
	eq(world.reset_world, nil, "A no reset: no world record written")

	M, cb = load_map_reset({}, "1", world)
	eq(M.pending(), true, "A setting 1 above the missing record: pending")
	eq(M.applied, 1, "A ...applied value 1")
	M.clear("x", function() ran = ran + 1 end)
	eq(ran, 1, "A a pending reset runs the clear")
	eq(world.reset_world, nil, "A the world record waits for every mod")
	mods_loaded(cb)
	eq(world.reset_world, "1", "A the world record is written after every mod")

	M, cb = load_map_reset({}, "1", world)
	eq(M.pending(), false, "A the same setting again: nothing pending")
	eq(M.applied, 1, "A ...the world's applied value stays 1")
	M.clear("x", function() ran = ran + 1 end)
	eq(ran, 1, "A ...and no clear runs")

	M, cb = load_map_reset({}, "3", world)
	eq(M.pending() and M.applied, 3, "A a raised setting applies again")
	mods_loaded(cb)
	eq(world.reset_world, "3", "A ...and is recorded")
	M = load_map_reset({}, "2", world)
	eq(M.pending(), false, "A a setting below the record triggers nothing")
	eq(M.applied, 3, "A ...the record stays the applied value")
	M = load_map_reset({}, "junk", {})
	eq(M.pending(), false, "A a non-number setting reads as 0")

	M, cb = load_map_reset({}, "4", world)
	local ok, err = pcall(M.clear, "the test state", function() error("disk full") end)
	check(not ok and tostring(err):find("clearing the test state failed", 1, true) ~= nil and
		tostring(err):find("disk full", 1, true) ~= nil,
		"A a failing clear stops the load with a clear error: " .. tostring(err))

	-- Characters (world applied value 3).
	M, cb = load_map_reset({}, "3", world)
	local old = meta_player("old", {["grug_classes:race"] = "human"})
	eq(M.needs_relocation(old), true, "A a created character without a record is moved")
	old:get_meta():set_int("grug_core:reset_world", 3)
	eq(M.needs_relocation(old), false, "A ...one at the world's value is not")
	old:get_meta():set_int("grug_core:reset_world", 2)
	eq(M.needs_relocation(old), true, "A ...one below it is")
	local raceless = meta_player("raceless", {})
	eq(M.needs_relocation(raceless), false, "A a character without a race is never moved")
	for _, fn in ipairs(cb.join) do fn(raceless) end
	eq(raceless:get_meta():get_int("grug_core:reset_world"), 3,
		"A a join without a race records the world's value")
	local joined = meta_player("joined", {["grug_classes:race"] = "orc"})
	for _, fn in ipairs(cb.join) do fn(joined) end
	eq(joined:get_meta():get_string("grug_core:reset_world"), "",
		"A a join with a race writes no record by itself")
	local new = meta_player("new", {})
	for _, fn in ipairs(cb.newplayer) do fn(new) end
	eq(new:get_meta():get_int("grug_core:reset_world"), 3, "A on_newplayer records the world's value")
	local seen
	M.register_on_relocate(function(p) seen = p:get_meta():get_int("grug_core:reset_world") end)
	M.relocated(old)
	eq(seen, 2, "A the map-bound player state goes before the record is written")
	eq(old:get_meta():get_int("grug_core:reset_world"), 3, "A ...then the record follows")
	local source = read(repo .. "/mods/CORE/grug_core/map_reset.lua")
	local code = source:gsub("%-%-[^\n]*", "")
	check(not code:find("creation_stasis", 1, true),
		"A the new-character rule never asks the creation stasis")
end

--
-- B. The clears.
--
-- B1. The world preparation keeps only its mode.
do
	local world_core = {}
	local M = load_map_reset({}, "1", world_core)
	local function boot(store_table, game)
		local saved_core = rawget(_G, "core")
		core = {
			get_mod_storage = function() return new_store(store_table) end,
			settings = {get_bool = function() return false end, get = function() return nil end},
			serialize = serialize, deserialize = deserialize,
			log = noop, get_us_time = function() return 0 end,
			get_modpath = function() return repo .. "/mods/CORE/grug_core" end,
			register_on_mods_loaded = noop, register_on_shutdown = noop,
			register_globalstep = noop,
		}
		local saved_game = rawget(_G, "grug_core")
		grug_core = game
		dofile(repo .. "/mods/CORE/grug_core/starts_preload.lua")
		grug_core, core = saved_game, saved_core
	end
	local prep = {world_preparation = serialize({mode = "full", order = "z-x-column-v2",
		total = 900, cursor = 450, geometry = {x = 5, y = 5, z = 5}, reach = 176,
		authority = "old-digest", selection = {index = 451, inner = 0}})}
	local game = {map_reset = M}
	boot(prep, game)
	local state = deserialize(prep.world_preparation)
	eq(snapshot(state), "mode=full", "B1 a reset keeps only the full mode")
	local status = game.world_preparation_status()
	check(status.mode == "full" and status.total == 0 and status.completed == 0 and
		not status.ready, "B1 ...so the full plan starts again (not ready, 0 done)")
	boot(prep, {map_reset = M})
	eq(snapshot(deserialize(prep.world_preparation)), "mode=full",
		"B1 a second clear (no record written yet) changes nothing")
	local fresh = {}
	boot(fresh, {map_reset = M})
	eq(snapshot(deserialize(fresh.world_preparation)), "mode=starts",
		"B1 a world without a plan binds the configured mode as before")
	local idle = load_map_reset({}, "1", {reset_world = "1"})
	local running = {world_preparation = serialize({mode = "starts", order = "z-y-x",
		total = 10, cursor = 4, geometry = {x = 5, y = 5, z = 5}})}
	boot(running, {map_reset = idle})
	eq(deserialize(running.world_preparation).cursor, 4, "B1 without a reset the progress stays")
end

-- B2. grug_mobs keeps only the liveness generations.
do
	local M = load_map_reset({}, "1", {})
	local data = {
		["startnpc:hearthpine:idle_west_door"] = "1",
		["startnpcdue:highcourt:guard_1"] = "1234",
		["live_gen:rare:grimtusk"] = "7", ["live_pos:rare:grimtusk"] = "1 2 3",
		["live_absent:rare:grimtusk"] = "20",
		["live_gen:dragon:frost"] = "2", ["live_pos:dragon:frost"] = "4 5 6",
		["rare_alive:grimtusk"] = "1", ["rare_next:grimtusk"] = "999",
		["boss:dragon:frost:alive"] = "1", ["boss:dragon:frost:due"] = "5",
		["boss:dragon:frost:warned"] = "1",
		["leader_next:bandit_chief"] = "300",
		["rift_crack:site"] = "24", ["rift_boss_due:site"] = "77",
	}
	local saved_game = rawget(_G, "grug_core")
	grug_core = {map_reset = M}
	grug_mobs = {storage = new_store(data)}
	dofile(repo .. "/mods/ENTITIES/grug_mobs/map_reset.lua")
	eq(snapshot(data), "live_gen:dragon:frost=2\nlive_gen:rare:grimtusk=7",
		"B2 only the liveness generations stay")
	dofile(repo .. "/mods/ENTITIES/grug_mobs/map_reset.lua")
	eq(snapshot(data), "live_gen:dragon:frost=2\nlive_gen:rare:grimtusk=7",
		"B2 a second clear changes nothing")
	grug_core, grug_mobs = saved_game, nil
end

-- B3. Housing: the claims go, placed stones need a new one, the ids count on.
do
	local data = {
		next_id = "5",
		["claim:3"] = "v2|alice|100|10|100|900|950|99999|0|bob=interact",
		["claim:4"] = "v1|garbage",
		["player:alice"] = "v2|placed|3",
		["player:bob"] = "v2|carried|0",
		["player:carol"] = "v2|destroyed|0",
	}
	local function model()
		local store = new_store(data)
		local m = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({
			storage = {get_string = function(k) return store:get_string(k) end,
				set_string = function(k, v) store:set_string(k, v) end,
				keys = function() return store:get_keys() end},
			now = function() return 1000 end})
		m.load()
		return m
	end
	local m = model()
	eq(m.claim_count(), 1, "B3 the loaded world has its one claim")
	check(m.claim_at({x = 100, y = 10, z = 100}) ~= nil, "B3 ...protecting its square")
	m.map_reset()
	eq(m.claim_count(), 0, "B3 no claim after the reset")
	eq(m.claim_at({x = 100, y = 10, z = 100}), nil, "B3 ...and no protection")
	eq(data["claim:3"], nil, "B3 the stored claim is gone")
	eq(data["claim:4"], nil, "B3 ...so is a record that did not decode")
	eq(data.next_id, "5", "B3 the claim id counter stays")
	local claim, state = m.player_claim("alice")
	check(claim == nil and state == "needs_stone", "B3 a placed stone's owner needs a new one")
	eq(m.player_state("bob"), "carried", "B3 a carried stone stays carried")
	eq(m.player_state("carol"), "destroyed", "B3 other records stay")
	eq(m.can_issue("alice", 20, false), true, "B3 the Housing Steward hands out a new stone")
	local before = snapshot(data)
	m.map_reset()
	eq(snapshot(data), before, "B3 a second clear changes nothing")
	m = model()
	eq(m.claim_count(), 0, "B3 a later start loads no claim")
	m.create("alice", {x = 0, y = 5, z = 0})
	eq(data["claim:5"] ~= nil and data.next_id, "6", "B3 the next claim takes the next id")
end

--
-- C and D. The relocation and new characters, on the real character
-- creation (grug_classes/selection.lua) and grug_factions.prepare_spawn.
--
local after_queue, emerges, chat, disconnects, errors = {}, {}, {}, {}, {}
local callbacks = {join = {}, newplayer = {}, leave = {}, fields = {}, mods_loaded = {}}
local players, holds, progress_listeners = {}, {}, {}
local current_mod = "sfinv"
local modpaths = {
	sfinv = repo .. "/mods/BASE/sfinv",
	grug_core = repo .. "/mods/CORE/grug_core",
	grug_factions = repo .. "/mods/PLAYER/grug_factions",
	grug_classes = repo .. "/mods/PLAYER/grug_classes",
}
local world_storage = {}
core = {
	EMERGE_CANCELLED = 0, EMERGE_ERRORED = 1, EMERGE_FROM_MEMORY = 2,
	EMERGE_FROM_DISK = 3, EMERGE_GENERATED = 4,
	settings = {get = function(_, key) if key == "grug_reset_world" then return "1" end end},
	get_mod_storage = function() return new_store(world_storage) end,
	log = function(level, text) if level == "error" then errors[#errors + 1] = text end end,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	formspec_escape = function(s) return (s:gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(_, s) return s end,
	chat_send_player = function(name, msg) chat[#chat + 1] = name .. ": " .. msg end,
	after = function(_, fn) after_queue[#after_queue + 1] = fn end,
	get_player_by_name = function(name) return players[name] end,
	show_formspec = noop, close_formspec = noop,
	emerge_area = function(_, _, cb) emerges[#emerges + 1] = cb end,
	disconnect_player = function(name, reason)
		disconnects[#disconnects + 1] = name .. ": " .. reason
	end,
	check_player_privs = function() return true end,
	register_on_joinplayer = function(fn) table.insert(callbacks.join, fn) end,
	register_on_newplayer = function(fn) table.insert(callbacks.newplayer, fn) end,
	register_on_leaveplayer = function(fn) table.insert(callbacks.leave, fn) end,
	register_on_player_receive_fields = function(fn)
		table.insert(callbacks.fields, {fn = fn, mod = current_mod})
	end,
	register_on_mods_loaded = function(fn) table.insert(callbacks.mods_loaded, fn) end,
	register_globalstep = noop, register_chatcommand = noop,
	register_on_player_hpchange = noop, register_on_respawnplayer = noop,
	register_on_punchplayer = noop, register_on_dieplayer = noop,
}
minetest = core
function dump(v) return tostring(v) end
vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end}
local function run_after()
	while #after_queue > 0 do
		local queue = after_queue
		after_queue = {}
		for _, fn in ipairs(queue) do fn() end
	end
end

local prep = {mode = "starts", completed = 0, total = 10, percent = 0, ready = false, failed = false}
grug_core = {
	factions = {
		accord = {id = "accord", name = "Accord", color = "#3f6fce"},
		throng = {id = "throng", name = "Throng", color = "#c41e3a"},
	},
	faction_ids = {"accord", "throng"},
	FLASH_COLOR = {error = 0xff4444, notice = 0xf0e6c8},
	zone_authority_installed = function() return true end,
	world_preparation_status = function() return deep_copy(prep) end,
	register_on_preparation_progress = function(fn)
		progress_listeners[#progress_listeners + 1] = fn
	end,
	starts_ready = function() return prep.ready and 6 or 0, 6 end,
	starts_preload_failed = function() return prep.failed end,
	request_starts_preload = function() return true end,
	hold_movement = function(p, name) holds[p:get_player_name()] = name end,
	release_movement = function(p, name)
		if holds[p:get_player_name()] == name then holds[p:get_player_name()] = nil end
	end,
	invalidate_combat_identity = noop,
	create_tag_carrier = function() return {} end,
	set_tag_carrier_text = noop, remove_tag_carrier = noop,
	start_position = function(faction, race)
		if race == "dwarf" then return nil end
		return {x = faction == "accord" and 100 or -100, y = 10, z = race and #race or 0}
	end,
}
local function notify_progress()
	for _, fn in ipairs(progress_listeners) do fn(grug_core.world_preparation_status()) end
end

local Player = {}
Player.__index = Player
local saved_meta = {}
local function make_player(name)
	saved_meta[name] = saved_meta[name] or {}
	return setmetatable({name = name, meta = new_store(saved_meta[name]),
		armor = {fleshy = 100}, pos = {x = 7, y = -50, z = 7}, hp = 20,
		huds = {}, hud_next = 0, inventory_formspec = ""}, Player)
end
function Player:get_player_name() return self.name end
function Player:get_meta() return self.meta end
function Player:get_inventory() return {add_item = noop} end
function Player:get_armor_groups() return deep_copy(self.armor) end
function Player:set_armor_groups(g) self.armor = g end
function Player:set_inventory_formspec(fs) self.inventory_formspec = fs end
function Player:hud_add(def)
	self.hud_next = self.hud_next + 1
	self.huds[self.hud_next] = deep_copy(def)
	return self.hud_next
end
function Player:hud_change(id, stat, value) self.huds[id][stat] = value end
function Player:hud_remove(id) self.huds[id] = nil end
function Player:set_pos(p) self.pos = p end
function Player:get_pos() return self.pos end
function Player:get_hp() return self.hp end
function Player:set_hp(hp) self.hp = hp end
function Player:get_properties() return {hp_max = 20} end
function Player:set_nametag_attributes() end

local function join(name, is_new)
	local p = make_player(name)
	players[name] = p
	if is_new then
		for _, fn in ipairs(callbacks.newplayer) do fn(p) end
	end
	for _, fn in ipairs(callbacks.join) do fn(p) end
	run_after()
	return p
end
local function leave(p)
	for _, fn in ipairs(callbacks.leave) do fn(p, false) end
	players[p.name] = nil
end
local function submit(p, fields)
	for _, entry in ipairs(callbacks.fields) do
		if entry.fn(p, "", fields) then return entry.mod end
	end
end

-- The real files in dependency order; the world record follows "mod load".
current_mod = "sfinv"
dofile(repo .. "/mods/BASE/sfinv/api.lua")
sfinv.register_page("sfinv:crafting", {title = "Home", get = function() return "SFINV_HOME" end})
current_mod = "grug_core"
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/map_reset.lua")
current_mod = "grug_factions"
dofile(repo .. "/mods/PLAYER/grug_factions/init.lua")
current_mod = "grug_classes"
do
	local real_dofile = dofile
	dofile = function(path)
		if path:match("/scout%.lua$") or path:match("/selection%.lua$") then
			if path:match("/selection%.lua$") then
				grug_classes.apply_stats = noop
				grug_classes.get_max_hp = function() return 20 end
			end
			return real_dofile(path)
		end
		return nil
	end
	real_dofile(repo .. "/mods/PLAYER/grug_classes/init.lua")
	dofile = real_dofile
end
for _, fn in ipairs(callbacks.mods_loaded) do fn() end
eq(world_storage.reset_world, "1", "C the world applied the reset")
-- grug_home's one relocation clear (claim_home.lua) on a stand-in.
grug_core.map_reset.register_on_relocate(function(p)
	p:get_meta():set_string("grug_home:claim", "")
end)
local arrivals = 0
grug_classes.register_on_arrival(function() arrivals = arrivals + 1 end)

local function existing(name, race, extra)
	local t = {["grug_factions:faction"] = race == "orc" and "throng" or "accord",
		["grug_classes:race"] = race, ["grug_classes:class"] = "warrior",
		["grug_xp:xp"] = "123456", ["grug_quests:state"] = "#q",
		["grug_home:waypoints"] = "dawnmere highcourt", ["grug_money:copper"] = "777",
		["grug_home:claim"] = "3"}
	for k, v in pairs(extra or {}) do t[k] = v end
	saved_meta[name] = t
end

--
-- C. The relocation.
--
existing("old", "human")
local before = deep_copy(saved_meta.old)
local o = join("old", false)
eq(holds.old, "class_creation", "C held at join while the world is prepared")
eq(o.armor.immortal, 1, "C ...and safe")
eq(#emerges, 0, "C nothing loads before the preparation is ready")
eq(o.pos.x, 7, "C not moved yet")
prep.ready, prep.completed, prep.percent = true, 10, 100
notify_progress()
run_after()
eq(#emerges, 1, "C at readiness the race start loads")
eq(holds.old, "class_creation", "C ...still held while it loads")
eq(o.pos.x, 7, "C ...not moved yet")
emerges[1](nil, core.EMERGE_GENERATED, 0)
run_after()
check(o.pos.x == 100 and o.pos.y == 10 and o.pos.z == #"human", "C moved to the human start")
eq(holds.old, nil, "C released")
eq(o.armor.immortal, nil, "C no longer immortal")
eq(o.inventory_formspec, "SFINV_HOME", "C the inventory is back")
eq(saved_meta.old["grug_core:reset_world"], "1", "C the record is written")
eq(saved_meta.old["grug_home:claim"], nil, "C the home claim is cleared")
eq(arrivals, 0, "C no arrival flow (no welcome)")
eq(#chat, 0, "C no arrival message")
local changed = {}
for k, v in pairs(saved_meta.old) do
	if before[k] ~= v and k ~= "grug_core:reset_world" then changed[#changed + 1] = k end
end
for k in pairs(before) do
	if saved_meta.old[k] == nil and k ~= "grug_home:claim" then changed[#changed + 1] = k end
end
eq(table.concat(changed, ","), "", "C nothing else about the character changes")
leave(o)
o = join("old", false)
eq(holds.old, nil, "C the next join is an ordinary one")
eq(#emerges, 1, "C ...with no second move")

-- A failed load: logged, disconnected, no record; the next join retries.
existing("unlucky", "orc")
local u = join("unlucky", false)
eq(#emerges, 2, "C a held character's start loads at join when ready")
emerges[2](nil, core.EMERGE_ERRORED, 0)
run_after()
eq(#disconnects, 1, "C a failed load disconnects the player")
check(disconnects[1] and disconnects[1]:find("^unlucky: ") ~= nil, "C ...that player")
check(errors[#errors] and errors[#errors]:find("unlucky", 1, true) ~= nil, "C ...and logs it")
eq(saved_meta.unlucky["grug_core:reset_world"], nil, "C ...with the record unwritten")
eq(u.pos.x, 7, "C ...and no move")
leave(u)
u = join("unlucky", false)
eq(#emerges, 3, "C the next join tries again")
emerges[3](nil, core.EMERGE_GENERATED, 0)
run_after()
eq(u.pos.x, -100, "C the retry moves it to the Throng start")
eq(saved_meta.unlucky["grug_core:reset_world"], "1", "C ...and records it")
-- A start that cannot be resolved at all fails the same way at once.
existing("lost", "dwarf")
local disconnects_before = #disconnects
join("lost", false)
eq(#disconnects, disconnects_before + 1, "C an unresolvable start disconnects at once")
eq(saved_meta.lost["grug_core:reset_world"], nil, "C ...without a record")
-- Leaving during the load: no move, no record, the next join retries.
existing("quick", "human")
local q = join("quick", false)
local pending = emerges[#emerges]
leave(q)
pending(nil, core.EMERGE_GENERATED, 0)
run_after()
eq(saved_meta.quick["grug_core:reset_world"], nil, "C leaving mid-load leaves the record unwritten")
q = join("quick", false)
emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
run_after()
eq(saved_meta.quick["grug_core:reset_world"], "1", "C ...and the rejoin completes the move")

--
-- D. New characters.
--
local n = join("newbie", true)
eq(saved_meta.newbie["grug_core:reset_world"], "1", "D on_newplayer records the world's value")
submit(n, {faction_throng = "The Throng"})
submit(n, {race_troll = "Troll"})
submit(n, {class_warrior = "Warrior"})
submit(n, {create_character = "Create character"})
emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
run_after()
eq(arrivals, 1, "D the new character takes the arrival flow")
eq(n.pos.x, -100, "D ...to its start")
leave(n)
local emerges_before = #emerges
n = join("newbie", false)
eq(holds.newbie, nil, "D a new character is never moved again")
eq(#emerges, emerges_before, "D ...nothing loads for it")

-- A character without a stored race (an unfinished creation) records at join.
saved_meta.drafter = {["grug_factions:faction"] = "accord"}
join("drafter", false)
eq(saved_meta.drafter["grug_core:reset_world"], "1", "D no stored race: the world's value at join")

-- A created character that had not arrived before the reset: its arrival is
-- the move, and records the value.
existing("arriving", "elf", {["grug_classes:arriving"] = "1", ["grug_home:claim"] = nil})
local ar = join("arriving", false)
emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
run_after()
eq(ar.pos.z, #"elf", "D an arriving character arrives at its start")
eq(saved_meta.arriving["grug_core:reset_world"], "1", "D ...and the arrival records the value")
leave(ar)
emerges_before = #emerges
join("arriving", false)
eq(#emerges, emerges_before, "D ...so no relocation follows")

--
-- E. Unknown ids in saved state.
--
-- E1. Quests: a removed active or tracked quest is dropped, never a crash.
do
	core = {
		serialize = serialize, deserialize = deserialize,
		get_item_group = function() return 0 end,
		registered_items = {}, registered_entities = {},
		log = noop, chat_send_player = noop,
		register_on_leaveplayer = noop, register_on_joinplayer = noop,
	}
	setmetatable(core, {__index = function(_, key)
		if type(key) == "string" and key:match("^register_") then return noop end
	end})
	grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end}
	grug_factions = {get_faction = function() return "accord" end,
		same_faction = function() return false end}
	grug_classes = {get_race = function() return "human" end}
	grug_xp = {get_level = function() return 60 end, quest_reward = function() return 0 end,
		register_on_level_change = noop}
	grug_mobs = {register_on_eligible_kill = noop, register_participant_drop_hook = noop}
	grug_money = {}
	grug_quests = {}
	dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/registry.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/state.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/labels.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/hud.lua")
	local Q = grug_quests
	Q.register_npc("giver", {settlement = "s", socket = "a", title = "Giver"})
	Q.register_quest("kept", {title = "Kept", description = "d", npc = "giver",
		rewards = {weight = 1}, objectives = {{type = "item", item = "grug_food:raw_meat", count = 4}}})
	local meta = {["grug_quests:state"] = serialize({
		active = {kept = {0}, removed_quest = {2}},
		completed = {gone_quest = true}, cooldowns = {gone_quest = 5},
		tracked = {"removed_quest", "kept"}, hud = true})}
	local player = meta_player("quester", meta)
	player.get_inventory = function()
		return {get_list = function() return {} end, get_stack = function() return ItemStack and nil end}
	end
	local ok, journal = pcall(Q.journal, player)
	check(ok, "E1 the journal of a character with a removed quest: " .. tostring(journal))
	if ok then
		eq(#journal.quests, 1, "E1 ...lists the kept quest only")
		eq(table.concat(journal.tracked, ","), "kept", "E1 ...and tracks the kept quest only")
		local hud_ok, hud_err = pcall(Q.hud_text, journal, nil)
		check(hud_ok, "E1 the tracker draws: " .. tostring(hud_err))
	end
	eq(Q.status and select(2, pcall(Q.status, player, "kept")) ~= nil, true,
		"E1 the kept quest still has its status")
	check(pcall(Q.accept, player, "removed_quest") , "E1 accepting an unknown id does not crash")
end

-- E2. Waypoints: unknown ids are ignored and dropped on the next write.
do
	local rules = dofile(repo .. "/mods/PLAYER/grug_home/waypoints_core.lua")
	local rows = {
		{id = "dawnmere", faction = "accord", race = "human", start = true, pos = {x = 0, y = 0, z = 0}},
		{id = "highcourt", faction = "accord", race = "human", start = false, pos = {x = 50, y = 0, z = 0}},
	}
	local set = rules.decode("highcourt gone_stone")
	local entries = rules.entries(rows, "accord", set, "human", "dawnmere")
	eq(#entries, 2, "E2 the travel list lists the registered stones only")
	eq(entries[2].state, "travel", "E2 ...a known stone stays known")
	eq(rules.encode(set, rows), "highcourt", "E2 the next write drops the unknown id")
end

-- E3. Achievements and cloaks: unknown ids are ignored.
do
	local R = dofile(repo .. "/mods/PLAYER/grug_achievements/core.lua")
	local book = R.build({
		defaults = {"none"},
		cloaks = {{id = "none", name = "No cloak"}, {id = "red", name = "Red", texture = "red.png"}},
		achievements = {{id = "hunter", name = "Hunter", counter = "kill:animal",
			text = "Kill %d", tiers = {{at = 10, cloak = "red"}}}},
	})
	local meta = new_store({["grug_achievements:tier:gone"] = "2",
		["grug_achievements:cloaks"] = "gone_cloak,red", ["grug_achievements:cloak"] = "gone_cloak",
		["grug_achievements:n:kill:animal"] = "12"})
	eq(table.concat(R.unlocked(book, meta), ","), "none,red", "E3 an unknown cloak is ignored")
	eq(R.selected(book, meta), "none", "E3 an unknown selected cloak reads as No cloak")
	eq(R.cloak_texture(book, meta), nil, "E3 ...and draws nothing")
	eq(#R.settle(book, meta, book.achievement.hunter, 12), 1, "E3 a known achievement settles")
	eq(R.select(book, meta, "gone_cloak"), false, "E3 an unknown cloak cannot be selected")
end

--
-- F. The declaration.
--
do
	eq(read(repo .. "/tools/web_data/upgrade.json"),
		'{"schema": 1, "version": "0.41.0", "map_reset": ["0.40.1"], "new_server": []}\n',
		"F the first declaration as the contract gives it")
	local conf = read(repo .. "/game.conf"):match("\nversion = ([%d.]+)")
	eq(conf, "0.41.0", "F game.conf names the declared version")
	-- The rules themselves (lists, history, outcomes) are the check tool's own
	-- self-test, which every run of tools/check_upgrade.py runs first.
	check(read(repo .. "/tools/check_upgrade.py"):find("def self_test", 1, true) ~= nil,
		"F the check tool carries its self-test")
end

if failures > 0 then
	error(("R41 UP PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R41 UP PORTABLE PASS checks=%d"):format(checks))
