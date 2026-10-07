-- Round 35 Lane C portable test: character creation in one window
-- (round35-plan.md §2.9). Loads the REAL mods/BASE/sfinv/api.lua,
-- grug_core/hud_layout.lua, grug_factions/init.lua, grug_classes/init.lua +
-- selection.lua and grug_visuals' looks.lua + creation.lua (the look panel)
-- under a minimal `core` stub; the other grug_classes sub-files are skipped
-- and grug_visuals' compose/set_look are stubbed.
--
--   A. the wait for world preparation, Esc and I, failure and retry;
--   B. the draft rules: a faction change clears race and look (the class
--      stays), a race change rolls a new look, forged fields are refused,
--      Create is refused until faction, race and class are chosen, and
--      NOTHING is written to the player (meta, inventory) before Create;
--   C. a disconnect before Create starts over;
--   D. Create stores everything at once, a second Create does nothing, a
--      reconnect during the arrival wait resumes it, the arrival releases;
--   E. an existing character during preparation (kept behaviour);
--   F. the window's geometry: every element inside size[], no two clickable
--      elements overlap, mouse rotation on and auto-rotation off.
--
-- Usage (repo root): luajit tools/r35_c/portable_test.lua [repo]
-- Prints "R35 C PORTABLE PASS checks=<n>" or the failures.

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
local function has(text, needle)
	return (text or ""):find(needle, 1, true) ~= nil
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
	grug_visuals = repo .. "/mods/PLAYER/grug_visuals",
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
	register_on_dieplayer = noop,
}
minetest = core
function dump(v) return tostring(v) end
vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end}

-- A deterministic math.random for the look rolls.
local random_state = 7
math.random = function(n)
	random_state = (random_state * 48271) % 2147483647
	return n and (random_state % n) + 1 or random_state / 2147483647
end

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
	faction_ids = {"accord", "throng"},
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
	-- Round 41: the platform's map reset (grug_core/map_reset.lua), idle
	-- here; tools/r41_up covers the relocation.
	map_reset = {needs_relocation = function() return false end, record = noop},
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
-- Fake players. Their meta is a plain table that survives leave/join.
--
local Player = {}
Player.__index = Player
local meta_writes = 0
local function new_meta(store)
	return {
		get_string = function(_, k) return store[k] or "" end,
		set_string = function(_, k, v)
			meta_writes = meta_writes + 1
			store[k] = (v ~= "" and v) or nil
		end,
		get_int = function(_, k) return tonumber(store[k]) or 0 end,
		set_int = function(_, k, v)
			meta_writes = meta_writes + 1
			store[k] = tostring(v)
		end,
	}
end
local saved_meta = {} -- name -> persisted meta table
local inventory_adds = 0
local function make_player(name)
	saved_meta[name] = saved_meta[name] or {}
	return setmetatable({name = name, meta = new_meta(saved_meta[name]),
		armor = {fleshy = 100}, pos = {x = 0, y = 0, z = 0}, hp = 20,
		huds = {}, hud_next = 0, inventory_formspec = "",
		inventory_writes = 0}, Player)
end
function Player:get_player_name() return self.name end
function Player:get_meta() return self.meta end
function Player:get_inventory()
	return {add_item = function() inventory_adds = inventory_adds + 1 end}
end
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

local function join(name, is_new, defer)
	local p = make_player(name)
	players[name] = p
	if is_new then
		for _, fn in ipairs(callbacks.newplayer) do fn(p) end
	end
	for _, fn in ipairs(callbacks.join) do fn(p) end
	if not defer then run_after() end
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

local function last_shown(name)
	for i = #shown, 1, -1 do
		if shown[i].name == name then return shown[i] end
	end
end

local function stored(name)
	local n = 0
	for _ in pairs(saved_meta[name] or {}) do n = n + 1 end
	return n
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
		if path:match("/scout%.lua$") or path:match("/selection%.lua$") then
			if path:match("/selection%.lua$") then
				-- The skipped sub-files provide these for set_class/finish.
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
-- scout.lua registers a few runtime hooks the stub does not know; the class
-- itself is what matters here.
check(grug_classes.registered_classes.scout ~= nil, "the Scout is a registered class")

current_mod = "grug_visuals"
grug_visuals = {}
dofile(repo .. "/mods/PLAYER/grug_visuals/looks.lua")
grug_visuals.compose = function(spec)
	return {textures = {"skin_" .. spec.race .. "_" .. grug_visuals.look_string(spec.look)}}
end
grug_visuals.set_look = function(player, look)
	local meta = player:get_meta()
	if meta:get_string("grug_visuals:look") ~= "" then return false end
	local race = grug_classes.get_race(player)
	local normal = race and grug_visuals.normalize_look(race, look)
	if not normal then return false end
	meta:set_string("grug_visuals:look", grug_visuals.look_string(normal))
	return true
end
dofile(repo .. "/mods/PLAYER/grug_visuals/creation.lua")
check(grug_visuals.creation_panel ~= nil, "the look panel is registered")

-- Count the look rolls and the class callbacks.
local rolls = 0
local real_roll = grug_visuals.roll_look
grug_visuals.roll_look = function(race, random)
	rolls = rolls + 1
	return real_roll(race, random)
end
local class_chosen = {}
grug_classes.register_on_class_chosen(function(p, id)
	class_chosen[#class_chosen + 1] = p:get_player_name() .. ":" .. id
end)

local CREATE_FORM, LOADING_FORM = "grug_classes:create", "grug_classes:loading"
local PAUSED = "Character creation paused \226\128\147 press I to continue"
local READY = "World ready \226\128\147 press I to continue"
local FAILED = "The area could not be loaded \226\128\147 press I to try again"
local WAITING = "Preparing the world \226\128\147 press I to see progress"
local BACKDROP = "bgcolor[#080808FF;both;#000000FF]"

-- The look a window shows, from the preview's texture.
local function preview_look(form)
	return (form or ""):match("character%.b3d;skin_%a+_([%d\\,]+);") and
		form:match("character%.b3d;skin_%a+_([%d\\,]+);"):gsub("\\", "")
end
local function preview_race(form)
	return (form or ""):match("character%.b3d;skin_(%a+)_")
end

--
-- A. A new player during preparation: waiting dialog; Esc really closes it.
--
local mark = #shown
local a = join("alice", true)
local s = shown_since(mark, "alice")
eq(#s, 1, "A join during preparation shows one dialog")
eq(s[1] and s[1].formname, LOADING_FORM, "A join during preparation shows the waiting screen")
check(has(s[1] and s[1].form, BACKDROP), "A the waiting screen has the dark backdrop")
eq(a.inventory_formspec, s[1] and s[1].form, "A inventory formspec = waiting screen")
eq(a.armor.immortal, 1, "A stasis: immortal")
eq(holds.alice, "class_creation", "A stasis: movement hold")
check(sfinv.inventory_suspended(a), "A sfinv suspended during creation")

eq(submit(a, LOADING_FORM, {quit = "true"}), "grug_classes", "A Esc on the waiting screen handled")
eq(hint(a), PAUSED, "A hint after dismissing the waiting screen")
prep.completed, prep.percent = 5, 50
mark = #shown
notify_progress()
run_after()
eq(#shown_since(mark, "alice"), 0, "A progress does not re-open a dismissed waiting screen")
check(has(a.inventory_formspec, "50%"), "A progress updates the inventory formspec")

-- Forged window fields before preparation is ready: nothing at all.
submit(a, "", {faction_accord = "x"})
submit(a, "", {create_character = "x"})
eq(stored("alice"), 0, "A nothing stored from forged fields before readiness")

-- A failure while dismissed: hint only; retry from the inventory.
mark = #shown
prep.failed = true
notify_progress()
eq(#shown_since(mark, "alice"), 0, "A failure does not force the dialog open")
eq(hint(a), FAILED, "A failure hint while dismissed")
eq(submit(a, "", {retry_spawn = "Try again"}), "grug_classes", "A inventory retry handled")
eq(retry_requests, 1, "A retry requested the preparation unit again")
eq(last_shown("alice").formname, LOADING_FORM, "A retry opens the waiting dialog again")
submit(a, LOADING_FORM, {quit = "true"})

-- Readiness while dismissed changes only the hint; while open it replaces.
local b = join("bob", true)
mark = #shown
prep.ready, prep.completed, prep.percent = true, 10, 100
notify_progress()
run_after()
eq(#shown_since(mark, "alice"), 0, "A ready while dismissed: no dialog")
eq(hint(a), READY, "A ready while dismissed: hint changes")
check(has(a.inventory_formspec, "faction_accord"), "A ready: the inventory is the window")
eq(last_shown("bob").formname, CREATE_FORM, "A ready while open: the window replaces the waiting screen")
check(has(last_shown("bob").form, BACKDROP), "A the window has the dark backdrop")

--
-- B. The draft (alice, through the inventory key: formname "").
--
local writes_before, adds_before = meta_writes, inventory_adds
local sfinv_writes = a.inventory_writes
sfinv.set_player_inventory_formspec(a)
eq(a.inventory_writes, sfinv_writes, "B sfinv writes nothing while creation owns the inventory")
check(has(a.inventory_formspec, "Choose your faction"), "B empty state before a faction")
check(not has(a.inventory_formspec, "race_human"), "B no races before a faction")
check(not has(a.inventory_formspec, "create_character"), "B no Create before a faction")

-- Race and class before a faction are refused.
submit(a, "", {race_human = "Human"})
submit(a, "", {class_mage = "Mage"})
check(not has(a.inventory_formspec, "race_human"), "B race before faction refused")

mark = #shown
eq(submit(a, "", {faction_accord = "The Accord"}), "grug_classes", "B faction from the inventory handled")
eq(last_shown("alice").formname, CREATE_FORM, "B the acting player sees the window again")
eq(hint(a), "", "B hint gone while the window is open")
local form = a.inventory_formspec
check(has(form, "race_human") and has(form, "race_dwarf") and has(form, "race_elf"),
	"B the Accord's races are offered")
check(not has(form, "race_orc"), "B no Throng race for the Accord")
check(not has(form, "model["), "B no model before a race")
check(has(form, "Choose your race to see your character"), "B hint before a race")
check(not has(form, "class_mage"), "B no class row before a race")
check(not has(form, "create_character"), "B Create inactive before a race")
check(has(form, "style[faction_accord;bgcolor=#3f6fce;font=bold]"), "B the chosen faction is highlighted")
check(has(form, "style[faction_throng;bgcolor=#4e0c17]"), "B the other faction is dimmed")

-- A race of the other faction is refused.
submit(a, "", {race_orc = "Orc"})
check(not has(a.inventory_formspec, "model["), "B a Throng race is refused for the Accord")

local rolls_before = rolls
submit(a, "", {race_human = "Human"})
eq(rolls, rolls_before + 1, "B choosing a race rolls a look")
form = a.inventory_formspec
eq(preview_race(form), "human", "B the preview shows the human")
check(has(form, "0,160;false;true;0,79;30]"), "B mouse rotation on, auto-rotation off")
check(has(form, "style[race_human;bgcolor=#8a6a1e;font=bold]"), "B the chosen race is highlighted")
check(has(form, "class_warrior") and has(form, "class_scout"), "B the class row appears")
check(not has(form, "create_character"), "B Create inactive without a class")
local look_human = preview_look(form)
check(look_human ~= nil, "B the drafted look is drawn: " .. tostring(look_human))

-- Create without a class is refused.
submit(a, "", {create_character = "Create character"})
eq(stored("alice"), 0, "B Create refused without a class")

-- The same race again does not reroll; a look button changes the draft.
submit(a, "", {race_human = "Human"})
eq(rolls, rolls_before + 1, "B the same race does not reroll")
submit(a, "", {look_next_style = ">"})
local look_next = preview_look(a.inventory_formspec)
check(look_next ~= look_human, "B a look button changes the drafted look")
submit(a, "", {look_bogus = "x", look_next_nothing = ">"})
eq(preview_look(a.inventory_formspec), look_next, "B unknown look fields change nothing")

submit(a, "", {class_bogus = "x"})
check(has(a.inventory_formspec, "Choose your class."), "B an unknown class is refused")
submit(a, "", {class_mage = "Mage"})
form = a.inventory_formspec
check(has(form, "style[class_mage;bgcolor=#8a6a1e;font=bold]"), "B the chosen class is highlighted")
check(has(form, "Ranged spell damage."), "B the class description under the row")
check(has(form, "create_character"), "B Create active with faction, race and class")

-- A race change rolls a new look.
rolls_before = rolls
submit(a, "", {race_dwarf = "Dwarf"})
eq(rolls, rolls_before + 1, "B a race change rolls a new look")
eq(preview_race(a.inventory_formspec), "dwarf", "B the preview follows the race")

-- A faction change clears race and look; the class stays.
submit(a, "", {faction_throng = "The Throng"})
form = a.inventory_formspec
check(not has(form, "model["), "B a faction change clears the look")
check(has(form, "race_orc") and not has(form, "race_dwarf"), "B the Throng's races")
check(not has(form, "style[race_"), "B a faction change clears the race")
check(not has(form, "create_character"), "B Create inactive after a faction change")
submit(a, "", {create_character = "Create character"})
eq(stored("alice"), 0, "B Create refused after the race was cleared")
submit(a, "", {race_troll = "Troll"})
form = a.inventory_formspec
check(has(form, "style[class_mage;bgcolor=#8a6a1e;font=bold]"), "B the class stayed through the faction change")
eq(preview_race(form), "troll", "B the troll preview")
check(has(form, "create_character"), "B Create active again")

-- Esc keeps the draft; I resumes it.
mark = #shown
submit(a, CREATE_FORM, {quit = "true"})
eq(#after_queue, 0, "B Esc on the window schedules nothing")
eq(#shown_since(mark, "alice"), 0, "B the window is not re-shown after Esc")
eq(hint(a), PAUSED, "B paused hint on the window")
check(has(a.inventory_formspec, "style[race_troll;bgcolor=#8a6a1e;font=bold]"),
	"B the draft survives Esc in the inventory")

eq(meta_writes, writes_before, "B no meta write before Create")
eq(stored("alice"), 0, "B nothing stored before Create")
eq(inventory_adds, adds_before, "B no item granted before Create")
eq(#class_chosen, 0, "B no class callback before Create")

--
-- C. A disconnect before Create starts over.
--
leave(a)
mark = #shown
a = join("alice", false)
eq(a.armor.immortal, 1, "C reconnect: back in stasis")
eq(last_shown("alice").formname, CREATE_FORM, "C reconnect: the window")
check(has(a.inventory_formspec, "Choose your faction"), "C reconnect: the draft starts over")
eq(stored("alice"), 0, "C still nothing stored")

--
-- D. Create, a second Create, a disconnect during the arrival wait.
--
submit(a, CREATE_FORM, {faction_accord = "The Accord"})
submit(a, CREATE_FORM, {race_elf = "Elf"})
submit(a, CREATE_FORM, {class_priest = "Priest"})
local look_elf = preview_look(a.inventory_formspec)
-- A forged mix: a Create together with a race of the other faction.
submit(a, CREATE_FORM, {race_orc = "Orc"})
eq(preview_race(a.inventory_formspec), "elf", "D a forged race leaves the draft alone")
local emerges_before = #emerges
mark = #shown
eq(submit(a, CREATE_FORM, {create_character = "Create character"}), "grug_classes", "D Create handled")
eq(saved_meta.alice["grug_factions:faction"], "accord", "D faction stored at Create")
eq(saved_meta.alice["grug_classes:race"], "elf", "D race stored at Create")
eq(saved_meta.alice["grug_classes:class"], "priest", "D class stored at Create")
eq(saved_meta.alice["grug_visuals:look"], look_elf, "D the drafted look stored at Create")
eq(saved_meta.alice["grug_classes:arriving"], "1", "D the character is marked arriving")
eq(#class_chosen, 1, "D one class callback")
eq(#emerges, emerges_before + 1, "D the arrival load starts after Create")
eq(last_shown("alice").formname, LOADING_FORM, "D the waiting screen after Create")
eq(a.armor.immortal, 1, "D still in stasis while the arrival loads")

-- A second Create (a double click, or the stale window) does nothing.
local chat_before = #chat
submit(a, CREATE_FORM, {create_character = "Create character"})
submit(a, "", {create_character = "Create character"})
submit(a, "", {faction_throng = "The Throng"})
eq(#class_chosen, 1, "D a second Create stores nothing")
eq(#emerges, emerges_before + 1, "D a second Create starts no second load")
eq(#chat, chat_before, "D a second Create says nothing")
eq(saved_meta.alice["grug_factions:faction"], "accord", "D a late faction click changes nothing")

-- Disconnect before the arrival load completes, then reconnect.
local pending_emerge = emerges[#emerges]
leave(a)
pending_emerge(nil, core.EMERGE_GENERATED, 0)
run_after()
eq(saved_meta.alice["grug_classes:arriving"], "1", "D still arriving after a disconnect mid-load")
mark = #shown
emerges_before = #emerges
a = join("alice", false)
eq(a.armor.immortal, 1, "D reconnect while arriving: stasis")
local sa = shown_since(mark, "alice")
eq(sa[1] and sa[1].formname, LOADING_FORM, "D reconnect resumes at the arrival wait")
eq(#emerges, emerges_before + 1, "D reconnect starts the arrival load")
eq(#class_chosen, 1, "D reconnect does not choose the class again")
local closed_before = #closed
emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
run_after()
eq(a.pos.x, 100, "D arrival teleport to the Accord start")
eq(a.pos.z, #"elf", "D arrival teleport to the elf start")
eq(saved_meta.alice["grug_classes:arriving"], nil, "D the arriving mark cleared")
eq(a.armor.immortal, nil, "D stasis released")
eq(holds.alice, nil, "D movement hold released")
eq(hint(a), "", "D hint removed")
check(not sfinv.inventory_suspended(a), "D sfinv no longer suspended")
eq(a.inventory_formspec, "SFINV_HOME", "D normal inventory restored")
local closed_window = false
for i = closed_before + 1, #closed do
	if closed[i].name == "alice" and closed[i].formname == CREATE_FORM then closed_window = true end
end
check(closed_window, "D completion closes the window")
eq(submit(a, "", {create_character = "x"}), nil, "D \"\" submissions go back to sfinv")
eq(submit(a, CREATE_FORM, {create_character = "x"}), "grug_classes", "D a stale window click is swallowed")
eq(#class_chosen, 1, "D ... and stores nothing")

-- Bob: the named dialog through to an arrival that is already loaded.
submit(b, CREATE_FORM, {faction_throng = "The Throng"})
submit(b, CREATE_FORM, {race_orc = "Orc"})
submit(b, CREATE_FORM, {class_warrior = "Warrior"})
submit(b, CREATE_FORM, {create_character = "Create character"})
emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
run_after()
eq(grug_classes.get_class(b), "warrior", "D bob is a warrior")
eq(b.pos.x, -100, "D bob at the Throng start")
check(saved_meta.bob["grug_visuals:look"] ~= nil, "D bob's rolled look stored")
eq(b.inventory_formspec, "SFINV_HOME", "D bob's inventory restored")

-- A failed arrival load stays safe and retries.
local c = join("carol", true)
submit(c, "", {faction_throng = "The Throng"})
submit(c, "", {race_undead = "Undead"})
submit(c, "", {class_scout = "Scout"})
submit(c, "", {create_character = "Create character"})
emerges[#emerges](nil, core.EMERGE_ERRORED, 0)
run_after()
check(has(c.inventory_formspec, "retry_spawn"), "D a failed arrival offers a retry")
eq(c.armor.immortal, 1, "D a failed arrival stays in stasis")
emerges_before = #emerges
submit(c, "", {retry_spawn = "Try again"})
eq(#emerges, emerges_before + 1, "D the retry loads the arrival again")
emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
run_after()
eq(c.armor.immortal, nil, "D the retried arrival completes")

--
-- E. An existing character reconnecting during preparation.
--
prep.ready, prep.completed, prep.percent = false, 3, 30
leave(b)
mark = #shown
b = join("bob", false)
eq(last_shown("bob").formname, LOADING_FORM, "E a complete character waits during preparation")
eq(b.armor.immortal, 1, "E stasis during preparation")
submit(b, LOADING_FORM, {quit = "true"})
eq(hint(b), WAITING, "E preparation-only hint")
mark = #shown
prep.ready = true
notify_progress()
run_after()
eq(#shown_since(mark, "bob"), 0, "E release opens no dialog")
eq(b.armor.immortal, nil, "E released at readiness")
eq(b.pos.x, 0, "E not teleported")

-- The window is the inventory synchronously, inside the join callbacks.
local d = join("dave", true, true)
check(has(d.inventory_formspec, "faction_accord"), "E the window is the inventory before the first step")
run_after()

--
-- F. The window's geometry for a full draft (the largest state).
--
submit(d, "", {faction_accord = "The Accord"})
submit(d, "", {race_dwarf = "Dwarf"})
submit(d, "", {class_scout = "Scout"})
form = d.inventory_formspec
local W, H = form:match("size%[([%d.]+),([%d.]+)%]")
W, H = tonumber(W), tonumber(H)
check(W and H and W <= 15 and H <= 11.1, "F the window fits the inventory's height: " ..
	tostring(W) .. "x" .. tostring(H))
local boxes, outside = {}, {}
for kind, x, y, w, h, rest in form:gmatch("(%a+)%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);([^%]]*)") do
	x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
	if x < 0 or y < 0 or x + w > W + 1e-6 or y + h > H + 1e-6 then
		outside[#outside + 1] = kind .. "@" .. x .. "," .. y
	end
	if kind == "button" or kind == "model" or kind == "textarea" then
		boxes[#boxes + 1] = {kind = kind, x = x, y = y, w = w, h = h, name = rest:match("^([^;]*)")}
	end
end
for kind, x, y in form:gmatch("(label)%[([%d.]+),([%d.]+);") do
	x, y = tonumber(x), tonumber(y)
	if x < 0 or y < 0 or x > W or y > H then outside[#outside + 1] = "label@" .. x .. "," .. y end
end
eq(#outside, 0, "F every element inside the window: " .. table.concat(outside, " "))
check(#boxes >= 20, "F the full window has its elements (" .. #boxes .. ")")
local overlaps = {}
for i = 1, #boxes do
	for j = i + 1, #boxes do
		local p, q = boxes[i], boxes[j]
		if p.x < q.x + q.w - 1e-6 and q.x < p.x + p.w - 1e-6 and
				p.y < q.y + q.h - 1e-6 and q.y < p.y + p.h - 1e-6 then
			overlaps[#overlaps + 1] = p.name .. "/" .. q.name
		end
	end
end
eq(#overlaps, 0, "F no two clickable elements overlap: " .. table.concat(overlaps, " "))
local tooltips = {}
for name in form:gmatch("tooltip%[([%a_]+);") do tooltips[name] = true end
local untipped = {}
for _, box in ipairs(boxes) do
	if box.kind == "button" and not tooltips[box.name] then untipped[#untipped + 1] = box.name end
end
eq(#untipped, 0, "F every button has a tooltip: " .. table.concat(untipped, " "))
check(not has(form, "wield") and not has(form, "grug_gear"), "F no weapon in the preview")

if failures > 0 then
	error(("R35 C PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
print(("R35 C PORTABLE PASS checks=%d"):format(checks))
