-- Round 24 Lane H portable test: pausable character creation (ruling 32).
-- Loads the REAL mods/BASE/sfinv/api.lua, grug_core/hud_layout.lua,
-- grug_factions/init.lua and grug_classes/init.lua + selection.lua under a
-- minimal `core` stub (the other grug_classes sub-files are skipped; the two
-- functions set_class needs from them are stubbed).
--
-- Usage (repo root): luajit tools/r24_creation_pause/portable_test.lua [repo]
-- Prints "R24 CREATION PAUSE PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

--
-- Engine stub.
--
local after_queue = {}
local callbacks = {join = {}, newplayer = {}, leave = {}, fields = {}}
local shown, closed, chat = {}, {}, {}
local emerges = {}
local players = {}
local current_mod = "sfinv"
local modpaths = {
	sfinv = repo .. "/mods/BASE/sfinv",
	grug_core = repo .. "/mods/CORE/grug_core",
	grug_factions = repo .. "/mods/PLAYER/grug_factions",
	grug_classes = repo .. "/mods/PLAYER/grug_classes",
}

local function noop() end
core = {
	EMERGE_CANCELLED = 0, EMERGE_ERRORED = 1, EMERGE_FROM_MEMORY = 2,
	EMERGE_FROM_DISK = 3, EMERGE_GENERATED = 4,
	log = noop,
	get_modpath = function(name) return modpaths[name] end,
	get_current_modname = function() return current_mod end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	formspec_escape = function(s) return (s:gsub("[%[%];,\\]", "\\%0")) end,
	colorize = function(_, s) return s end,
	chat_send_player = function(name, msg) chat[#chat + 1] = {name, msg} end,
	after = function(delay, fn) after_queue[#after_queue + 1] = fn end,
	get_player_by_name = function(name) return players[name] end,
	show_formspec = function(name, formname, form)
		shown[#shown + 1] = {name = name, formname = formname, form = form}
	end,
	close_formspec = function(name, formname)
		closed[#closed + 1] = {name = name, formname = formname}
	end,
	emerge_area = function(p1, p2, cb)
		emerges[#emerges + 1] = cb
	end,
	check_player_privs = function() return true end,
	register_on_joinplayer = function(fn) table.insert(callbacks.join, fn) end,
	register_on_newplayer = function(fn) table.insert(callbacks.newplayer, fn) end,
	register_on_leaveplayer = function(fn) table.insert(callbacks.leave, fn) end,
	register_on_player_receive_fields = function(fn)
		table.insert(callbacks.fields, {fn = fn, mod = current_mod})
	end,
	register_globalstep = noop,
	register_chatcommand = noop,
	register_on_player_hpchange = noop,
	register_on_mods_loaded = noop,
	register_on_respawnplayer = noop,
	register_on_punchplayer = noop,
}
minetest = core
function dump(v) return tostring(v) end
vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end}

local function run_after()
	local n = 0
	while #after_queue > 0 do
		local queue = after_queue
		after_queue = {}
		for _, fn in ipairs(queue) do fn(); n = n + 1 end
	end
	return n
end

--
-- grug_core stub: only the surface these files call. Preparation status is
-- driven by the test.
--
local prep = {mode = "starts", completed = 0, total = 10, percent = 0,
	ready = false, failed = false}
local progress_listeners = {}
local holds, retry_requests = {}, 0
grug_core = {
	factions = {
		accord = {id = "accord", name = "Accord", color = "#3f6fce"},
		throng = {id = "throng", name = "Throng", color = "#c41e3a"},
	},
	FLASH_COLOR = {error = 0xff4444, notice = 0xf0e6c8},
	zone_authority_installed = function() return true end,
	world_preparation_status = function()
		local copy = {}
		for k, v in pairs(prep) do copy[k] = v end
		return copy
	end,
	register_on_preparation_progress = function(fn)
		progress_listeners[#progress_listeners + 1] = fn
	end,
	starts_ready = function() return prep.ready and 6 or 0, 6 end,
	starts_preload_failed = function() return prep.failed end,
	request_starts_preload = function()
		retry_requests = retry_requests + 1
		prep.failed = false
		return true
	end,
	hold_movement = function(p, name) holds[p:get_player_name()] = name end,
	release_movement = function(p, name)
		if holds[p:get_player_name()] == name then holds[p:get_player_name()] = nil end
	end,
	invalidate_combat_identity = noop,
	create_tag_carrier = function() return {} end,
	set_tag_carrier_text = noop,
	remove_tag_carrier = noop,
	start_position = function(faction, race)
		return {x = faction == "accord" and 100 or -100, y = 10, z = race and #race or 0}
	end,
}
local function notify_progress()
	for _, fn in ipairs(progress_listeners) do fn(grug_core.world_preparation_status()) end
end

--
-- Fake players.
--
local Player = {}
Player.__index = Player
local function new_meta(store)
	return {
		get_string = function(_, k) return store[k] or "" end,
		set_string = function(_, k, v) store[k] = (v ~= "" and v) or nil end,
		get_int = function(_, k) return tonumber(store[k]) or 0 end,
		set_int = function(_, k, v) store[k] = tostring(v) end,
	}
end
local saved_meta = {} -- name -> persisted meta table (survives leave/join)
local function make_player(name)
	saved_meta[name] = saved_meta[name] or {}
	local p = setmetatable({name = name, meta = new_meta(saved_meta[name]),
		armor = {fleshy = 100}, pos = {x = 0, y = 0, z = 0}, hp = 20,
		huds = {}, hud_next = 0, inventory_formspec = "",
		inventory_writes = 0}, Player)
	return p
end
function Player:get_player_name() return self.name end
function Player:get_meta() return self.meta end
function Player:get_inventory() return {add_item = noop} end
function Player:get_velocity() return {x = 0, y = 0, z = 0} end
function Player:add_velocity() end
function Player:get_armor_groups()
	local c = {}
	for k, v in pairs(self.armor) do c[k] = v end
	return c
end
function Player:set_armor_groups(g) self.armor = g end
function Player:set_inventory_formspec(fs)
	self.inventory_formspec = fs
	self.inventory_writes = self.inventory_writes + 1
end
function Player:hud_add(def)
	self.hud_next = self.hud_next + 1
	local copy = {}
	for k, v in pairs(def) do copy[k] = v end
	self.huds[self.hud_next] = copy
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

local function hint(p)
	local texts = {}
	for _, def in pairs(p.huds) do
		if def.text and def.text ~= "" then texts[#texts + 1] = def.text end
	end
	return table.concat(texts, " | ")
end

-- The engine's receive-fields dispatch: registration order, stop at true.
local function submit(p, formname, fields)
	for _, entry in ipairs(callbacks.fields) do
		if entry.fn(p, formname, fields) then
			return entry.mod
		end
	end
	return nil
end

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

local function shown_since(mark, name)
	local out = {}
	for i = mark + 1, #shown do
		if not name or shown[i].name == name then out[#out + 1] = shown[i] end
	end
	return out
end

--
-- Load the real files in dependency order.
--
current_mod = "sfinv"
dofile(repo .. "/mods/BASE/sfinv/api.lua")
sfinv.register_page("sfinv:crafting", {title = "Home",
	get = function() return "SFINV_HOME" end})
current_mod = "grug_core"
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
current_mod = "grug_factions"
dofile(repo .. "/mods/PLAYER/grug_factions/init.lua")
current_mod = "grug_classes"
do
	local real_dofile = dofile
	dofile = function(path)
		if path:match("/selection%.lua$") then
			-- The skipped sub-files provide these for set_class/finish.
			grug_classes.apply_stats = noop
			grug_classes.get_max_hp = function() return 20 end
			return real_dofile(path)
		end
		return nil
	end
	real_dofile(repo .. "/mods/PLAYER/grug_classes/init.lua")
	dofile = real_dofile
end

local RACE_FORM, CLASS_FORM = "grug_classes:race", "grug_classes:class"
local LOADING_FORM, FACTION_FORM = "grug_classes:loading", "grug_factions:select"
local PAUSED = "Character creation paused \226\128\147 press I to continue"
local READY = "World ready \226\128\147 press I to continue"
local FAILED = "The area could not be loaded \226\128\147 press I to try again"
local WAITING = "Preparing the world \226\128\147 press I to see progress"

--
-- 1. A new player during preparation: waiting dialog; Esc really closes it.
--
local mark = #shown
local a = join("alice", true)
local s = shown_since(mark, "alice")
eq(#s, 1, "join during preparation shows one dialog")
eq(s[1] and s[1].formname, LOADING_FORM, "join during preparation shows the waiting screen")
eq(a.inventory_formspec, s[1] and s[1].form, "inventory formspec = waiting screen")
eq(a.armor.immortal, 1, "stasis: immortal")
eq(holds.alice, "class_creation", "stasis: movement hold")
eq(hint(a), "", "no hint while the dialog is open")
check(sfinv.inventory_suspended(a), "sfinv suspended during creation")

mark = #shown
eq(submit(a, LOADING_FORM, {quit = "true"}), "grug_classes", "Esc on waiting screen handled by grug_classes")
eq(#after_queue, 0, "Esc on waiting screen schedules nothing")
eq(hint(a), PAUSED, "hint after dismissing the waiting screen")
prep.completed, prep.percent = 5, 50
notify_progress()
run_after()
eq(#shown_since(mark, "alice"), 0, "progress does not re-open a dismissed waiting screen")
check(a.inventory_formspec:find("50%%", 1) ~= nil, "progress updates the inventory formspec")

-- Forged choice before preparation is ready: nothing committed.
submit(a, "", {choose_accord = "x"})
eq(grug_factions.get_faction(a), nil, "no faction commit before preparation is ready")

-- A failure while dismissed: hint only, never a forced dialog.
mark = #shown
prep.failed = true
notify_progress()
eq(#shown_since(mark, "alice"), 0, "failure does not force the dialog open")
eq(hint(a), FAILED, "failure hint while dismissed")
check(a.inventory_formspec:find("retry_spawn", 1, true) ~= nil, "inventory formspec offers retry")
-- Retry through the inventory formspec (formname "").
eq(submit(a, "", {retry_spawn = "Try again"}), "grug_classes", "inventory retry handled")
eq(retry_requests, 1, "retry requested the preparation unit again")
local r = shown_since(mark, "alice")
eq(r[#r] and r[#r].formname, LOADING_FORM, "retry opens the waiting dialog again")
eq(hint(a), "", "no hint while the dialog is open")
mark = #shown
submit(a, LOADING_FORM, {quit = "true"})
eq(hint(a), PAUSED, "dismissed again")

--
-- 2. Readiness while dismissed changes only the hint; while open it replaces.
--
local b = join("bob", true) -- bob keeps his waiting dialog open
mark = #shown
prep.ready, prep.completed, prep.percent = true, 10, 100
notify_progress()
run_after()
local sa, sb = shown_since(mark, "alice"), shown_since(mark, "bob")
eq(#sa, 0, "ready while dismissed: no dialog")
eq(hint(a), READY, "ready while dismissed: hint changes")
check(a.inventory_formspec:find("choose_accord", 1, true) ~= nil, "ready: inventory formspec = faction step")
eq(#sb, 1, "ready while open: one dialog")
eq(sb[1] and sb[1].formname, FACTION_FORM, "ready while open: faction step replaces waiting screen")
eq(hint(b), "", "ready while open: no hint")

--
-- 3. The inventory key continues: submissions with formname "".
--
local sfinv_writes = a.inventory_writes
sfinv.set_player_inventory_formspec(a)
eq(a.inventory_writes, sfinv_writes, "sfinv writes nothing while creation owns the inventory")
mark = #shown
eq(submit(a, "", {choose_accord = "The Accord"}), "grug_classes", "inventory faction choice routed to creation")
eq(grug_factions.get_faction(a), "accord", "faction persisted at once")
sa = shown_since(mark, "alice")
eq(sa[#sa] and sa[#sa].formname, RACE_FORM, "next step (race) opens as a dialog")
eq(hint(a), "", "hint gone while the race dialog is open")

-- Esc on race: nothing re-opens.
mark = #shown
submit(a, RACE_FORM, {quit = "true"})
eq(#after_queue, 0, "Esc on race schedules nothing")
run_after()
eq(#shown_since(mark, "alice"), 0, "race dialog not re-shown")
eq(hint(a), PAUSED, "paused hint on race step")
check(a.inventory_formspec:find("choose_human", 1, true) ~= nil, "inventory formspec = race step")

-- Continue from the inventory.
submit(a, "", {choose_human = "Human"})
eq(grug_classes.get_race(a), "human", "race persisted at once")
sa = shown_since(mark, "alice")
eq(sa[#sa] and sa[#sa].formname, CLASS_FORM, "class dialog after race")
-- The arrival load starts behind the class step.
eq(#emerges, 1, "arrival load started after the race choice")

-- Esc on class: nothing re-opens.
mark = #shown
submit(a, CLASS_FORM, {quit = "true"})
eq(#after_queue, 0, "Esc on class schedules nothing")
eq(#shown_since(mark, "alice"), 0, "class dialog not re-shown")
check(a.inventory_formspec:find("choose_mage", 1, true) ~= nil, "inventory formspec = class step")

-- Stale named click from a replaced dialog is ignored.
submit(a, RACE_FORM, {choose_warrior = "Warrior"})
eq(a.meta:get_string("grug_classes:pending_class"), "", "stale race-form click commits nothing")

-- Choose the class from the inventory; the arrival area is still loading.
submit(a, "", {choose_mage = "Mage"})
eq(a.meta:get_string("grug_classes:pending_class"), "mage", "pending class persisted at once")
eq(grug_classes.get_class(a), nil, "class not applied before the arrival teleport")
sa = shown_since(mark, "alice")
eq(sa[#sa] and sa[#sa].formname, LOADING_FORM, "arrival waiting screen after the class choice")

--
-- 4. Disconnect before the arrival load completes, then reconnect.
--
local pending_emerge = emerges[1]
leave(a)
pending_emerge(nil, core.EMERGE_GENERATED, 0) -- completes after the leave
run_after()
eq(saved_meta.alice["grug_classes:class"], nil, "no class after a disconnect mid-load")
eq(saved_meta.alice["grug_classes:pending_class"], "mage", "pending class survives the disconnect")

mark = #shown
local emerges_before = #emerges
a = join("alice", false)
eq(a.armor.immortal, 1, "reconnect with a pending class is back in stasis")
check(sfinv.inventory_suspended(a), "reconnect: sfinv suspended again")
sa = shown_since(mark, "alice")
eq(sa[1] and sa[1].formname, LOADING_FORM, "reconnect continues at the arrival wait, not the class step")
eq(#emerges, emerges_before + 1, "reconnect starts the arrival load")
emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
run_after()
eq(grug_classes.get_class(a), "mage", "persisted pending class applied at arrival")
eq(a.pos.x, 100, "arrival teleport to the accord start")
eq(a.pos.z, #"human", "arrival teleport to the human start")
eq(a.meta:get_string("grug_classes:pending_class"), "", "pending class cleared")
eq(a.armor.immortal, nil, "stasis released")
eq(holds.alice, nil, "movement hold released")
eq(hint(a), "", "hint removed at completion")
check(not sfinv.inventory_suspended(a), "sfinv no longer suspended")
eq(a.inventory_formspec, "SFINV_HOME", "normal inventory restored at completion")
eq(submit(a, "", {some_field = "x"}), nil, "\"\" submissions go back to sfinv")

--
-- 5. Esc on the faction dialog (named) re-opens nothing; admin-free path to
--    completion with the arrival already loaded (no disconnect).
--
mark = #shown
submit(b, FACTION_FORM, {quit = "true"})
eq(#after_queue, 0, "Esc on faction schedules nothing")
eq(#shown_since(mark, "bob"), 0, "faction dialog not re-shown")
eq(hint(b), PAUSED, "paused hint on faction step (ready before dismissal)")
submit(b, "", {choose_throng = "The Throng"})
submit(b, RACE_FORM, {choose_orc = "Orc"})
emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
run_after()
submit(b, CLASS_FORM, {choose_warrior = "Warrior"})
eq(grug_classes.get_class(b), "warrior", "class applied at once when the arrival is already loaded")
eq(b.pos.x, -100, "bob at the throng start")
eq(b.inventory_formspec, "SFINV_HOME", "bob's inventory restored")
eq(hint(b), "", "bob has no hint")

--
-- 6. An existing character reconnecting during preparation.
--
prep.ready, prep.completed, prep.percent = false, 3, 30
mark = #shown
b = join("bob", false)
sb = shown_since(mark, "bob")
eq(sb[1] and sb[1].formname, LOADING_FORM, "complete character waits during preparation")
eq(b.armor.immortal, 1, "complete character in stasis during preparation")
submit(b, LOADING_FORM, {quit = "true"})
eq(hint(b), WAITING, "preparation-only hint")
mark = #shown
prep.ready = true
notify_progress()
run_after()
eq(#shown_since(mark, "bob"), 0, "release opens no dialog")
eq(b.armor.immortal, nil, "complete character released at readiness")
eq(b.inventory_formspec, "SFINV_HOME", "complete character's inventory restored")
eq(b.pos.x, 0, "complete character not teleported")

if failures > 0 then
	error(("R24 CREATION PAUSE PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
print(("R24 CREATION PAUSE PORTABLE PASS checks=%d"):format(checks))
