-- Round 46 lane WT portable test: the waiting point for players in creation
-- stasis (round46-plan.md §4.3; docs/design/world_preparation.md "The
-- waiting point"). Loads the REAL mods/BASE/sfinv/api.lua,
-- grug_core/hud_layout.lua and map_reset.lua, grug_factions/init.lua and
-- grug_classes/init.lua + selection.lua under a minimal `core` stub (the
-- tools/r41_up harness), with a world whose map reset applied value is 1.
--
--   M. the rule matrix at the start of a session: a new player, a mid-draft
--      reconnect, a created character that has not arrived and a character
--      with a map-reset backlog are moved to (0, 31000, 0), once, before
--      anything else of the session; a complete character without a backlog
--      during preparation is held where it stands; a complete one with the
--      preparation ready gets no session; after the preparation a new player
--      is still moved;
--   T. the waits still end in their teleports: the arrival to the race start
--      (with the arrival callbacks) and the relocation (without them);
--   D. a disconnect at the waiting point is safe: the backlog record and the
--      arriving mark stay, and the next join comes back to the same flow;
--   S. the source: one named constant, one helper, called once in
--      lock_player's session creation.
--
-- Usage (repo root): luajit tools/r46_wt/portable_test.lua [repo]
-- Prints "R46 WT PORTABLE PASS checks=<n>" or the failures.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
grug_inventory = {give = function(player, stack)
	return player:get_inventory():add_item("main", stack)
end}
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

-- A mod storage / meta on a plain table ("" deletes, like the engine).
local function new_store(t)
	local s = {}
	function s.get_string(_, k) return t[k] or "" end
	function s.set_string(_, k, v)
		if v == "" then t[k] = nil else t[k] = v end
	end
	function s.get_int(_, k) return math.floor(tonumber(t[k]) or 0) end
	function s.set_int(_, k, v) t[k] = tostring(v) end
	return s
end

--
-- Engine stub.
--
local after_queue, emerges, chat, disconnects = {}, {}, {}, {}
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
	log = noop,
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
		return {x = faction == "accord" and 100 or -100, y = 10, z = race and #race or 0}
	end,
}
local function set_ready(ready)
	prep.ready = ready
	prep.completed = ready and prep.total or 0
	prep.percent = ready and 100 or 0
	for _, fn in ipairs(progress_listeners) do fn(grug_core.world_preparation_status()) end
	run_after()
end

-- Fake players: their meta and position survive leave and join (the
-- engine's player row); every set_pos is recorded with what was happening.
local Player = {}
Player.__index = Player
local saved_meta, saved_pos = {}, {}
local phase = "?"
local function make_player(name)
	saved_meta[name] = saved_meta[name] or {}
	return setmetatable({name = name, meta = new_store(saved_meta[name]),
		armor = {fleshy = 100}, pos = deep_copy(saved_pos[name] or {x = 7, y = -50, z = 7}),
		hp = 20, moves = {}, huds = {}, hud_next = 0, inventory_formspec = ""}, Player)
end
function Player:get_player_name() return self.name end
function Player:get_meta() return self.meta end
-- Round 49: the starter kit goes onto hotbar slots 7 and 8 (grug_factions):
-- every slot reads empty, nothing is kept.
local empty_slot = {is_empty = function() return true end}
function Player:get_inventory()
	return {add_item = noop, set_stack = noop, get_stack = function() return empty_slot end}
end
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
function Player:set_pos(p)
	self.pos = deep_copy(p)
	self.moves[#self.moves + 1] = {pos = deep_copy(p), phase = phase}
end
function Player:get_pos() return deep_copy(self.pos) end
function Player:get_hp() return self.hp end
function Player:set_hp(hp) self.hp = hp end
function Player:get_properties() return {hp_max = 20} end
function Player:set_nametag_attributes() end

-- The engine's join: on_newplayer (a new player only), then on_joinplayer,
-- then the deferred work.
local function join(name, is_new)
	local p = make_player(name)
	players[name] = p
	if is_new then
		phase = "newplayer"
		for _, fn in ipairs(callbacks.newplayer) do fn(p) end
	end
	phase = "joinplayer"
	for _, fn in ipairs(callbacks.join) do fn(p) end
	phase = "later"
	run_after()
	return p
end
local function leave(p)
	for _, fn in ipairs(callbacks.leave) do fn(p, false) end
	saved_pos[p.name] = deep_copy(p.pos)
	players[p.name] = nil
end
local function submit(p, fields)
	for _, entry in ipairs(callbacks.fields) do
		if entry.fn(p, "", fields) then return entry.mod end
	end
end
local function create(p, faction, race)
	submit(p, {["faction_" .. faction] = "x"})
	submit(p, {["race_" .. race] = "x"})
	submit(p, {class_warrior = "Warrior"})
	submit(p, {create_character = "Create character"})
	run_after()
end
local function finish_emerge()
	emerges[#emerges](nil, core.EMERGE_GENERATED, 0)
	run_after()
end
local function at(pos, x, y, z)
	return pos.x == x and pos.y == y and pos.z == z
end
local function at_waiting_point(pos) return at(pos, 0, 31000, 0) end

--
-- Load the real files in dependency order; the world applies reset 1.
--
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
eq(grug_core.map_reset.applied, 1, "setup the world applies reset 1")
local arrivals = {}
grug_classes.register_on_arrival(function(p) arrivals[#arrivals + 1] = p.name end)

-- Saved characters: complete (faction, race, class), a record, extra keys.
local function character(name, faction, race, record, extra)
	local t = {["grug_factions:faction"] = faction, ["grug_classes:race"] = race,
		["grug_classes:class"] = "warrior"}
	if record then t["grug_core:reset_world"] = tostring(record) end
	for k, v in pairs(extra or {}) do t[k] = v end
	saved_meta[name] = t
	saved_pos[name] = {x = 1200, y = 40, z = -800}
end

--
-- M. The rule matrix, during preparation.
--
-- A new player: moved in on_newplayer, before the engine sends the first
-- position, and only there.
local new = join("newbie", true)
check(at_waiting_point(new.pos), "M a new player waits at (0, 31000, 0)")
eq(#new.moves, 1, "M ...moved once")
eq(new.moves[1] and new.moves[1].phase, "newplayer", "M ...in on_newplayer")
eq(holds.newbie, "class_creation", "M ...and held")
-- The session's other paths never move again: the join's deferred dialog,
-- progress, a dismissed dialog, the inventory key.
for _, fn in ipairs(progress_listeners) do fn(grug_core.world_preparation_status()) end
submit(new, {quit = "true"})
submit(new, {})
run_after()
eq(#new.moves, 1, "M progress and window actions do not move again")

-- A mid-draft reconnect: the draft was never stored, so nothing about the
-- character exists; the join (not new) moves it.
saved_meta.drafter, saved_pos.drafter = {}, {x = -300, y = 12, z = 450}
local drafter = join("drafter", false)
check(at_waiting_point(drafter.pos), "M a mid-draft reconnect waits at the waiting point")
eq(#drafter.moves, 1, "M ...moved once")
eq(drafter.moves[1] and drafter.moves[1].phase, "joinplayer", "M ...in on_joinplayer")

-- Created but not arrived (record current: no backlog).
character("arriver", "accord", "elf", 1, {["grug_classes:arriving"] = "1"})
local arriver = join("arriver", false)
check(at_waiting_point(arriver.pos), "M a created, not arrived character waits at the waiting point")
eq(#arriver.moves, 1, "M ...moved once")

-- A map-reset backlog (record 0 below the applied 1).
character("oldhero", "accord", "human", nil, {["grug_home:claim"] = "3"})
eq(grug_core.map_reset.needs_relocation(make_player("oldhero")), true, "setup oldhero has a backlog")
local oldhero = join("oldhero", false)
check(at_waiting_point(oldhero.pos), "M a character with a reset backlog waits at the waiting point")
eq(#oldhero.moves, 1, "M ...moved once")
eq(holds.oldhero, "class_creation", "M ...and held")

-- Complete without a backlog, during preparation: held where it stands.
character("steady", "throng", "orc", 1)
local steady = join("steady", false)
eq(holds.steady, "class_creation", "M a complete character without a backlog is held during preparation")
eq(#steady.moves, 0, "M ...and not moved")
check(at(steady.pos, 1200, 40, -800), "M ...it keeps its position")
eq(#emerges, 0, "M nothing loads while the preparation runs")

--
-- T. Readiness: the waits end in their teleports.
--
set_ready(true)
eq(holds.steady, nil, "T the complete character is released at readiness")
eq(#steady.moves, 0, "T ...without a move")
-- The relocation and the arrival load their race starts (prepare_spawn).
eq(#emerges, 2, "T the relocation and the arrival load their starts")
emerges[1](nil, core.EMERGE_GENERATED, 0)
emerges[2](nil, core.EMERGE_GENERATED, 0)
run_after()
check(at(oldhero.pos, 100, 10, #"human"), "T the relocation moves oldhero to the human start")
eq(#oldhero.moves, 2, "T ...its second move")
eq(holds.oldhero, nil, "T ...released")
eq(saved_meta.oldhero["grug_core:reset_world"], "1", "T ...the record written")
eq(saved_meta.oldhero["grug_home:claim"], "3", "T ...(no relocate callback registered here)")
check(at(arriver.pos, 100, 10, #"elf"), "T the arrival moves the arriver to the elf start")
eq(saved_meta.arriver["grug_classes:arriving"], nil, "T ...the arriving mark cleared")
eq(table.concat(arrivals, ","), "arriver", "T only the arrival runs the arrival callbacks")
-- The new player creates its character after readiness and arrives.
create(new, "throng", "troll")
finish_emerge()
check(at(new.pos, -100, 10, #"troll"), "T the new character arrives at the troll start")
eq(#new.moves, 2, "T ...its second move")
eq(holds.newbie, nil, "T ...released")

-- After the preparation: a complete character without a backlog gets no
-- session and no move; a new player is moved all the same.
leave(steady)
steady = join("steady", false)
eq(grug_core.player_in_creation_stasis("steady"), false,
	"M a complete character without a backlog gets no session when the world is ready")
eq(#steady.moves, 0, "M ...and no move")
local late = join("latecomer", true)
check(at_waiting_point(late.pos), "M a new player after the preparation waits at the waiting point")
eq(late.moves[1] and late.moves[1].phase, "newplayer", "M ...moved in on_newplayer")

--
-- D. A disconnect at the waiting point is safe.
--
set_ready(false)
character("leaver", "throng", "orc", nil)
local leaver = join("leaver", false)
check(at_waiting_point(leaver.pos), "D a backlog character waits at the waiting point")
leave(leaver)
eq(saved_meta.leaver["grug_core:reset_world"], nil, "D after a disconnect the backlog stays")
check(at_waiting_point(saved_pos.leaver), "D ...its saved position is the waiting point")
leaver = join("leaver", false)
eq(holds.leaver, "class_creation", "D the next join is held again")
check(at_waiting_point(leaver.pos), "D ...at the waiting point")
character("drifter", "accord", "dwarf", 1, {["grug_classes:arriving"] = "1"})
local drifter = join("drifter", false)
leave(drifter)
eq(saved_meta.drifter["grug_classes:arriving"], "1", "D after a disconnect the arriving mark stays")
check(at_waiting_point(saved_pos.drifter), "D ...its saved position is the waiting point")
local emerges_before = #emerges
set_ready(true)
drifter = join("drifter", false)
check(#emerges > emerges_before, "D the next join after readiness loads the arrival")
finish_emerge()
check(at(drifter.pos, 100, 10, #"dwarf"), "D ...and arrives at the dwarf start")
-- The leaver's relocation: the session from its second join.
emerges[#emerges - 1](nil, core.EMERGE_GENERATED, 0)
run_after()
check(at(leaver.pos, -100, 10, #"orc"), "D the leaver is relocated to the orc start")
eq(saved_meta.leaver["grug_core:reset_world"], "1", "D ...and its record written")
eq(#disconnects, 0, "no player was disconnected")

--
-- S. The source.
--
do
	local source = read(repo .. "/mods/PLAYER/grug_classes/selection.lua")
	check(source:find("local WAITING_POINT = {x = 0, y = 31000, z = 0}", 1, true) ~= nil,
		"S the waiting point is one named constant")
	local _, uses = source:gsub("WAITING_POINT", "")
	eq(uses, 2, "S ...defined once and used once")
	local _, calls = source:gsub("move_to_waiting_point%(", "")
	eq(calls, 2, "S one helper, called once")
	local lock = source:match("local function lock_player%(player%)(.-)\nend\n")
	check(lock and lock:find("if not session then%s+move_to_waiting_point%(player, relocate%)") ~= nil,
		"S ...first thing when lock_player creates the session")
	-- No static spawn point (its respawn hook would move every death there).
	check(not read(repo .. "/minetest.conf"):find("static_spawnpoint", 1, true),
		"S minetest.conf sets no static_spawnpoint")
	-- The point lies above the outermost generatable chunk and inside the
	-- object limit (get_mapgen_edges with the game's mapgen_limit and
	-- chunksize: the central chunk starts at block -2).
	local conf = read(repo .. "/minetest.conf")
	local limit = tonumber(conf:match("\nmapgen_limit = (%d+)"))
	local chunk = tonumber(conf:match("\nchunksize = (%d+)"))
	local limit_b = math.floor(limit / 16)
	local max_n = (limit_b + 1) * 16 - 1
	local cc_max = -2 * 16 + chunk * 16 - 1
	local edge = cc_max + math.floor((max_n - (cc_max + 16)) / (chunk * 16)) * chunk * 16
	eq(edge, 30927, "S the outermost generatable chunk ends at y = 30927")
	local block = math.floor(31000 / 16)
	check((block - 4) * 16 > edge, "S the whole active block sphere (range 4) lies above it")
	check(31000 < limit + 0.5, "S the point is inside the object limit")
end

if failures > 0 then
	error(("R46 WT PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R46 WT PORTABLE PASS checks=%d"):format(checks))
