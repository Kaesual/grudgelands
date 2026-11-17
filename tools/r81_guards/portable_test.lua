-- Round 81 lane GUARDS portable test (LuaJIT; round81-plan.md §4 GUARDS,
-- audit X2-02, X6-03, E1-04, X2-01, C3-03).
--
--   luajit tools/r81_guards/portable_test.lua [REPO]
--
--   N  the REAL grug_core/npc_window.lua: a live player with HP, the live
--      entity (get_luaentity is the entity), the role, the faction (nil
--      refuses), reach 8 (or opts.reach) to the NPC, the NPC within 2 of its
--      registry socket (role and, when given, profession) or of
--      opts.socket_pos; each edge on both sides;
--   C  the REAL grug_traders/crown.lua (E1-04): a refused click closes the
--      window with one line (walked away, the faction's refusal, none for a
--      dead player) and ends the session; Close and a permitted click do not;
--   R  the REAL grug_expeditions/registrar.lua (fix round, the user's
--      2026-11-17 ruling): the registrar checks its socket like every service
--      window: it opens on its socket and refuses 2.01 off it, and a click
--      after it left its socket closes the window;
--   J  the REAL grug_jobs/trainers.lua (fix round, review Low 1): a refused
--      click closes the window without a line and ends the session; Close and
--      a permitted click do not;
--   B  the REAL grug_inventory/bound.lua with the REAL rules of
--      grug_housing/soulbound.lua and grug_skills/bound_items.lua: the
--      player-inventory answers of both rules, the catalog's swap undo left
--      to the engine (nil); node inventories refuse both groups and ask the
--      node's own callback otherwise; detached inventories: a put of either
--      group refused, the skills exempt only in `grug_skills_*`, a move
--      refused only for soulbound; an inventory created after load, after a
--      join, wrapped at creation (C3-03); a station whose callbacks a later
--      mods-loaded step replaces is wrapped again by the second walk; a
--      walk never wraps twice; a wrapper put around a box after its creation
--      (the trash hint) sees the refusal; no join hook and no node walk at a
--      join.
-- Prints "R81 GUARDS PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local checks, failures = 0, 0
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
-- Stub engine.
------------------------------------------------------------------------------
local callbacks = {allow = {}, loaded = {}, join = {}, fields = {}, leave = {}, die = {}}
local items = {
	["t:stone"] = {groups = {grug_soulbound = 1}},
	["grug_abilities:strike"] = {groups = {grug_ability = 1, grug_bound_skill = 1}},
	["grug_abilities:locked"] = {groups = {grug_ability = 1, grug_bound_skill = 1}},
	["t:mount"] = {groups = {grug_bound_skill = 1}, _grug_mount_tier = 1},
	["t:ore"] = {groups = {}},
}
function ItemStack(spec)
	if type(spec) == "table" then return ItemStack(spec.name .. " " .. spec.count) end
	local name, count = (spec or ""):match("^(%S*)%s*(%d*)$")
	local stack = {name = name or "", count = tonumber(count) or (name ~= "" and 1 or 0)}
	function stack:is_empty() return self.name == "" or self.count == 0 end
	function stack:get_name() return self.name end
	function stack:get_count() return self.count end
	-- Every mount item here is the player's ("hero") own.
	function stack:get_meta()
		return {get_string = function(_, key) return key == "grug_mounts:owner" and "hero" or "" end}
	end
	return stack
end
local overrides, closed, chat, shown = 0, {}, {}, {}
local node_stacks = {}
core = {
	registered_items = items, registered_nodes = {}, detached_inventories = {},
	get_item_group = function(name, group)
		local def = items[name]
		return def and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(f) callbacks.allow[#callbacks.allow + 1] = f end,
	register_on_mods_loaded = function(f) callbacks.loaded[#callbacks.loaded + 1] = f end,
	register_on_joinplayer = function(f) callbacks.join[#callbacks.join + 1] = f end,
	register_on_leaveplayer = function(f) callbacks.leave[#callbacks.leave + 1] = f end,
	register_on_dieplayer = function(f) callbacks.die[#callbacks.die + 1] = f end,
	register_on_player_receive_fields = function(f) callbacks.fields[#callbacks.fields + 1] = f end,
	override_item = function(name, redefinition)
		overrides = overrides + 1
		for key, value in pairs(redefinition) do rawset(core.registered_nodes[name], key, value) end
	end,
	get_meta = function(pos)
		return {get_inventory = function()
			return {get_stack = function(_, list, i)
				return node_stacks[list .. i] or ItemStack("")
			end}
		end}
	end,
	close_formspec = function(name, formname) closed[#closed + 1] = {name, formname} end,
	chat_send_player = function(name, text) chat[#chat + 1] = {name, text} end,
	show_formspec = function(name, formname, spec) shown[#shown + 1] = {name, formname, spec} end,
	formspec_escape = function(text) return text end,
	colorize = function(_, text) return text end,
	get_us_time = function() return 0 end,
}
-- builtin/game/detached_inventory.lua: the callbacks go into a table of its own.
function core.create_detached_inventory(name, cbs)
	local stuff = {name = name}
	if cbs then
		for _, key in ipairs({"allow_move", "allow_put", "allow_take", "on_move", "on_put", "on_take"}) do
			stuff[key] = cbs[key]
		end
	end
	core.detached_inventories[name] = stuff
	return {}
end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	distance = function(a, b)
		return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
	end,
}

------------------------------------------------------------------------------
-- N. The shared NPC-window check.
------------------------------------------------------------------------------
local sockets = {
	town = {
		{id = "s_ride", role = "riding_trainer", pos = {x = 0, y = 0, z = 0}},
		{id = "s_train", role = "trainer", profession = "tailor", pos = {x = 0, y = 0, z = 0}},
	},
}
grug_core = {settlement_sockets_at = function(key) return sockets[key] or {} end}
grug_core.get_player_object_faction = function(player) return player.faction end
dofile(ROOT .. "/mods/CORE/grug_core/npc_window.lua")
local permitted = grug_core.npc_window_permitted

local function player(faction, x)
	return {faction = faction, pos = {x = x or 0, y = 0, z = 0}, hp = 20,
		is_player = function() return true end,
		get_hp = function(self) return self.hp end,
		get_pos = function(self) return self.pos end,
		get_player_name = function() return "hero" end}
end
local function npc(role, socket, y, profession)
	local entity = {_grug_socket_role = role, _grug_start = "town", _grug_socket = socket,
		_grug_profession = profession}
	entity.object = {pos = {x = 0, y = y or 0, z = 0}, alive = true,
		get_pos = function(self) return self.alive and self.pos or nil end,
		get_luaentity = function(self) return self.alive and entity or nil end}
	return entity
end
do
	local p, ride = player("accord"), npc("riding_trainer", "s_ride")
	eq(permitted(p, ride, "riding_trainer", "accord"), true, "N a live player at the live NPC on its socket")
	eq(permitted(nil, ride, "riding_trainer", "accord"), false, "N no player")
	eq(permitted({is_player = function() return false end}, ride, "riding_trainer", "accord"), false,
		"N not a player")
	p.hp = 0
	eq(permitted(p, ride, "riding_trainer", "accord"), false, "N a dead player")
	p.hp = 20
	eq(permitted(p, nil, "riding_trainer", "accord"), false, "N no entity")
	eq(permitted(p, "x", "riding_trainer", "accord"), false, "N an entity that is no table")
	local bare = npc("riding_trainer", "s_ride")
	bare.object = nil
	eq(permitted(p, bare, "riding_trainer", "accord"), false, "N an entity without object")
	ride.object.alive = false
	eq(permitted(p, ride, "riding_trainer", "accord"), false, "N a removed object")
	ride.object.alive = true
	local other = npc("riding_trainer", "s_ride")
	ride.object.get_luaentity = function() return other end
	eq(permitted(p, ride, "riding_trainer", "accord"), false, "N an object of another entity")
	ride = npc("riding_trainer", "s_ride")
	eq(permitted(p, ride, "shipwright", "accord"), false, "N another role")
	eq(permitted(p, ride, "riding_trainer", nil), false, "N an NPC of no faction refuses")
	eq(permitted(p, ride, "riding_trainer", "throng"), false, "N the other faction")
	eq(permitted(player(nil), ride, "riding_trainer", "accord"), false, "N a player of no faction")
	p.pos = {x = 8, y = 0, z = 0}
	eq(permitted(p, ride, "riding_trainer", "accord"), true, "N 8 nodes away")
	p.pos = {x = 8.01, y = 0, z = 0}
	eq(permitted(p, ride, "riding_trainer", "accord"), false, "N 8.01 nodes away")
	eq(permitted(p, ride, "riding_trainer", "accord", {reach = 9}), true, "N opts.reach")
	p.pos = nil
	eq(permitted(p, ride, "riding_trainer", "accord"), false, "N a player without position")
	p.pos = {x = 0, y = 0, z = 0}
	ride.object.pos = {x = 0, y = 2, z = 0}
	eq(permitted(p, ride, "riding_trainer", "accord"), true, "N the NPC 2 nodes off its socket")
	ride.object.pos = {x = 0, y = 2.01, z = 0}
	eq(permitted(p, ride, "riding_trainer", "accord"), false, "N 2.01 nodes off its socket")
	eq(permitted(p, ride, "riding_trainer", "accord", {socket_pos = {x = 0, y = 2, z = 0}}), true,
		"N opts.socket_pos replaces the registry's socket")
	ride.object.pos = {x = 0, y = 0, z = 0}
	ride._grug_socket = "s_train"
	eq(permitted(p, ride, "riding_trainer", "accord"), false, "N a socket of another role")
	ride._grug_socket = "s_gone"
	eq(permitted(p, ride, "riding_trainer", "accord"), false, "N a socket the registry lacks")
	local tailor = npc("trainer", "s_train", 0, "tailor")
	eq(permitted(p, tailor, "trainer", "accord", {profession = "tailor"}), true, "N the trainer's profession")
	eq(permitted(p, tailor, "trainer", "accord", {profession = "smith"}), false,
		"N a socket of another profession")
end

------------------------------------------------------------------------------
-- C. The Crownbinder's window closes when the player may no longer use it.
------------------------------------------------------------------------------
do
	grug_traders = {}
	grug_inventory = {equipment_slots = {}, BAG_COUNT = 0}
	grug_factions = {get_faction = function(p) return p.faction end,
		display_name = function(id) return id == "accord" and "The Accord" or "The Throng" end}
	grug_factions.serves = function(f, p) return f == nil or grug_factions.get_faction(p) == f end
	grug_factions.refusal = function(subject, f)
		return "<" .. subject .. "> I serve only " .. grug_factions.display_name(f) .. "."
	end
	grug_sounds = {play = function() end}
	grug_core.feed = function() end
	grug_money = {format = function(c) return c .. "c" end, get = function() return 0 end}
	-- The window's drawing is not under test here (tools/r33_c5 draws it).
	grug_core.ui = setmetatable({}, {__index = function() return function() return "" end end})
	dofile(ROOT .. "/mods/ENTITIES/grug_traders/crown.lua")
	local receive = callbacks.fields[#callbacks.fields]
	local p = player("accord")
	p.get_inventory = function() return {get_stack = function() return ItemStack("") end,
		get_size = function() return 0 end, get_list = function() return {} end} end
	local function open()
		grug_traders.open_crownbinder(p, "Crownbinder", {x = 0, y = 0, z = 0}, "accord")
		return shown[#shown][2]
	end
	local function click(formname, fields)
		closed, chat = {}, {}
		local before = #shown
		receive(p, formname, fields)
		return #shown - before
	end
	local formname = open()
	eq(click(formname, {next = "true"}), 1, "C a permitted click redraws")
	eq(#closed, 0, "C ...and closes nothing")
	p.pos = {x = 6.5, y = 0, z = 0}
	click(formname, {next = "true"})
	eq(#closed == 1 and closed[1][2], formname, "C walked away: the window closes")
	eq(chat[1] and chat[1][2], "You walked away from the Crownbinder.", "C ...with one line")
	eq(click(formname, {next = "true"}), 0, "C ...and the session is gone")
	eq(#closed + #chat, 0, "C ...a later click says nothing")
	p.pos = {x = 0, y = 0, z = 0}
	formname = open()
	p.faction = "throng"
	click(formname, {next = "true"})
	eq(#closed, 1, "C a faction change closes the window")
	eq(chat[1] and chat[1][2], "<Crownbinder> I serve only The Accord.", "C ...with the refusal line")
	p.faction = "accord"
	formname = open()
	p.hp = 0
	click(formname, {next = "true"})
	eq(#closed == 1 and #chat, 0, "C a dead player's window closes without a line")
	p.hp = 20
	formname = open()
	p.pos = {x = 20, y = 0, z = 0}
	click(formname, {quit = "true"})
	eq(#closed + #chat, 0, "C Close only ends the session")
	eq(click(formname, {next = "true"}), 0, "C ...which is gone")
end

------------------------------------------------------------------------------
-- R. The Expedition Registrar checks its socket too.
------------------------------------------------------------------------------
do
	sockets.highcourt = {{id = "expedition_registrar", role = "expedition_registrar",
		pos = {x = 0, y = 0, z = 0}}}
	core.get_modpath = function(mod) return ROOT .. "/mods/MAPGEN/" .. mod end
	core.register_on_dieplayer = function() end
	grug_core.assign_service_socket = function() end
	grug_core.register_status_source = function() end
	grug_mobs = {register_start_socket_role = function() end}
	grug_home = {location = function(key) return key == "highcourt" and {faction = "accord"} or nil end}
	local hook = function() end
	-- No run and no Expedition on offer: the window's plain list.
	grug_expeditions = {catalogue = {RESERVE_SECONDS = 600}, state_text = hook,
		register_on_ready = hook, register_on_end = hook, register_on_close = hook,
		register_on_leave = hook, register_on_enter = hook,
		run_of = function() return nil end, list = function() return {} end}
	dofile(ROOT .. "/mods/PLAYER/grug_expeditions/registrar.lua")
	local receive = callbacks.fields[#callbacks.fields]
	local R = grug_expeditions.registrar
	local p = player("accord")
	local registrar = npc("expedition_registrar", "expedition_registrar")
	registrar._grug_start = "highcourt"
	local function click(fields)
		closed, chat = {}, {}
		receive(p, R.FORMNAME, fields)
	end
	eq(grug_expeditions.open_registrar(p, registrar), true, "R the registrar on its socket opens")
	click({level = "1"})
	eq(#closed, 0, "R ...a permitted click closes nothing")
	eq(R.sessions.hero ~= nil, true, "R ...and keeps the session")
	registrar.object.pos = {x = 0, y = 2, z = 0}
	eq(grug_expeditions.open_registrar(p, registrar), true, "R 2 nodes off its socket it still opens")
	registrar.object.pos = {x = 0, y = 2.01, z = 0}
	eq(grug_expeditions.open_registrar(p, registrar), false, "R 2.01 nodes off its socket it refuses")
	click({level = "1"})
	eq(#closed == 1 and closed[1][2], R.FORMNAME, "R a click after it left its socket closes the window")
	eq(#chat, 0, "R ...without a line")
	eq(R.sessions.hero, nil, "R ...and ends the session")
	registrar.object.pos = {x = 0, y = 0, z = 0}
	registrar._grug_socket = "elsewhere"
	eq(grug_expeditions.open_registrar(p, registrar), false, "R a registrar without its socket refuses")
end

------------------------------------------------------------------------------
-- J. A refused click at a profession trainer closes its window.
------------------------------------------------------------------------------
do
	core.log = function() end
	grug_core.settlement_socket_settlements = function()
		return {{key = "town", race_id = "human"}}
	end
	grug_classes = {registered_races = {human = {faction = "accord"}}}
	grug_inventory = {wrap_text = function(text) return text end}
	local known = {}
	grug_jobs = {
		PROFESSIONS = {tailor = {name = "Tailoring", class = "primary"}},
		PROFESSION_STATIONS = {}, station_info = function() return nil end,
		has = function(_, id) return known[id] == true end,
		primary_at = function() return nil end,
		profession_level = function() return 1 end,
		crafts_in_tier = function() return 0 end,
		learn = function(_, id) known[id] = true return true end,
	}
	dofile(ROOT .. "/mods/PLAYER/grug_jobs/trainers.lua")
	local receive = callbacks.fields[#callbacks.fields]
	local p = player("accord")
	local tailor = npc("trainer", "s_train", 0, "tailor")
	local function click(fields)
		closed, chat = {}, {}
		local before = #shown
		receive(p, "grug_jobs:trainer", fields)
		return #shown - before
	end
	local function open()
		check(grug_jobs.open_trainer(p, "tailor", nil, tailor), "J the trainer opens")
	end
	open()
	eq(click({grug_jobs_learn = "Learn"}), 1, "J a permitted click redraws")
	eq(#closed, 0, "J ...and closes nothing")
	eq(known.tailor, true, "J ...and teaches")
	known.tailor = nil
	p.pos = {x = 8.01, y = 0, z = 0}
	eq(click({grug_jobs_learn = "Learn"}), 0, "J walked away: no redraw")
	eq(#closed == 1 and closed[1][2], "grug_jobs:trainer", "J ...the window closes")
	eq(#chat, 0, "J ...without a line")
	eq(known.tailor, nil, "J ...and teaches nothing")
	p.pos = {x = 0, y = 0, z = 0}
	click({grug_jobs_learn = "Learn"})
	eq(#closed, 0, "J ...the session is gone: a later click closes nothing")
	eq(known.tailor, nil, "J ...and teaches nothing")
	open()
	tailor.object.pos = {x = 0, y = 2.01, z = 0}
	click({grug_jobs_learn = "Learn"})
	eq(#closed, 1, "J the trainer off its socket: the window closes")
	tailor.object.pos = {x = 0, y = 0, z = 0}
	open()
	p.pos = {x = 20, y = 0, z = 0}
	click({quit = "true"})
	eq(#closed, 0, "J Close only ends the session")
	p.pos = {x = 0, y = 0, z = 0}
	click({grug_jobs_learn = "Learn"})
	eq(known.tailor, nil, "J ...which is gone")
end

------------------------------------------------------------------------------
-- B. The bound-item seam.
------------------------------------------------------------------------------
-- Nodes: one without callbacks, one with its own, a station whose callbacks a
-- later mods-loaded step replaces without chaining (grug_jobs/workspaces.lua).
core.registered_nodes["n:plain"] = {}
core.registered_nodes["n:own"] = {
	allow_metadata_inventory_put = function() return 7 end,
	allow_metadata_inventory_move = function() return 5 end,
}
core.registered_nodes["n:station"] = {}
core.create_detached_inventory("creative_trash", {})
grug_inventory = {HOTBAR_SIZE = 8, BAG_COUNT = 4, HOTBAR_STORE = "grug_hotbar_store",
	content_list = function(i) return "grug_bag" .. i .. "_content" end}
grug_abilities = {is_unlocked = function(_, id) return id == "strike" end}
grug_mounts = {owns_tier = function() return true end}
grug_housing, grug_skills = {}, {}
local allow_before = #callbacks.allow
dofile(ROOT .. "/mods/PLAYER/grug_housing/soulbound.lua")
dofile(ROOT .. "/mods/PLAYER/grug_inventory/bound.lua")
core.register_on_mods_loaded(function()
	core.override_item("n:station", {
		allow_metadata_inventory_put = function(_, _, _, stack) return stack:get_count() end,
		allow_metadata_inventory_move = function(_, _, _, _, _, count) return count end,
	})
end)
local joins_before = #callbacks.join
dofile(ROOT .. "/mods/PLAYER/grug_skills/bound_items.lua")
eq(#callbacks.allow - allow_before, 1, "B one player-inventory allow callback for both rules")
eq(#callbacks.join, joins_before, "B no join hook")
overrides = 0
for _, f in ipairs(callbacks.loaded) do f() end
-- Three nodes wrapped (put and move in one override each), the stand-in
-- grug_jobs' replacement, the station wrapped again by grug_skills' walk.
eq(overrides, 5, "B mods-loaded: every node once, the replaced station once more")
overrides = 0
grug_inventory.guard_bound_destinations()
eq(overrides, 0, "B a further walk wraps nothing twice")

local function allow(action, inv, info)
	for _, f in ipairs(callbacks.allow) do
		local answer = f({get_player_name = function() return "hero" end}, action, inv, info)
		if answer then return answer end
	end
	return nil
end
local function inventory(owner, slots)
	local inv = {}
	function inv:get_stack(list, i) return ItemStack(slots[list .. i] or "") end
	function inv:get_location() return {type = "player", name = owner} end
	function inv:contains_item(list, name)
		for key, value in pairs(slots) do
			if key:match("^(.-)%d+$") == list and value == name then return true end
		end
		return false
	end
	return inv
end
local function move(stack, from_list, from_index, to_list, to_index)
	return allow("move", inventory("hero", {[from_list .. from_index] = stack}),
		{from_list = from_list, from_index = from_index, to_list = to_list, to_index = to_index, count = 1})
end
local function put(stack, list, index, owner, slots)
	return allow("put", inventory(owner or "hero", slots or {}),
		{listname = list, index = index, stack = ItemStack(stack)})
end
-- The soulbound rule: only into carried lists.
eq(move("t:stone", "main", 9, "grug_bag2_content", 1), nil, "B soulbound main -> a bag")
eq(move("t:stone", "main", 9, "grug_hotbar_store", 1), nil, "B soulbound main -> the hidden layout")
eq(move("t:stone", "main", 9, "craft", 1), 0, "B soulbound main -> craft refused")
eq(move("t:stone", "main", 9, "grug_mail_out", 1), 0, "B soulbound main -> the letter refused")
eq(put("t:stone", "main", 3), nil, "B soulbound put into main")
eq(put("t:stone", "grug_weapon", 1), 0, "B soulbound put into equipment refused")
-- The skills rule: abilities onto the hotbar only, one copy, entitled.
eq(move("grug_abilities:strike", "main", 9, "main", 2), nil, "B a skill onto the hotbar")
eq(move("grug_abilities:strike", "main", 2, "main", 9), 0, "B a skill off the hotbar refused")
eq(move("grug_abilities:locked", "main", 2, "main", 3), 0, "B a locked skill refused")
eq(move("grug_abilities:strike", "craft", 1, "main", 2), 0, "B a skill from a list not owned refused")
eq(put("grug_abilities:strike", "main", 2), nil, "B a catalog put onto a free hotbar slot")
eq(put("grug_abilities:strike", "main", 2, "hero", {main5 = "grug_abilities:strike"}), 0,
	"B a second copy refused")
eq(put("grug_abilities:strike", "main", 2, "hero", {main2 = "grug_abilities:strike"}), nil,
	"B the catalog's swap undo left to the engine")
eq(put("grug_abilities:strike", "main", 2, "other"), 0, "B a put into another player's inventory refused")
eq(put("grug_abilities:strike", "main", 12), 0, "B a skill put off the hotbar refused")
-- Round 81 (DEAD, ruling 10): the mount items are aliases of "", so a bound
-- item that is no skill is never entitled and goes nowhere.
eq(move("t:mount", "main", 12, "grug_bag1_content", 3), 0, "B a bound non-skill item into a bag refused")
eq(move("t:mount", "main", 12, "craft", 1), 0, "B a bound non-skill item into craft refused")
eq(move("t:ore", "main", 1, "craft", 1), nil, "B anything else is left alone")
eq(allow("take", inventory("hero", {main1 = "t:stone"}), {listname = "main", index = 1,
	stack = ItemStack("t:stone")}), nil, "B a take is left to the destination's guard")

-- Node inventories.
local function node_put(node, stack)
	local f = core.registered_nodes[node].allow_metadata_inventory_put
	return f({}, "src", 1, ItemStack(stack), nil)
end
local function node_move(node, stack)
	node_stacks.src1 = ItemStack(stack)
	local f = core.registered_nodes[node].allow_metadata_inventory_move
	return f({}, "src", 1, "dst", 1, 1, nil)
end
for _, node in ipairs({"n:plain", "n:own", "n:station"}) do
	eq(node_put(node, "t:stone"), 0, "B " .. node .. " refuses a soulbound put")
	eq(node_put(node, "grug_abilities:strike"), 0, "B " .. node .. " refuses a skill put")
	eq(node_put(node, "t:mount"), 0, "B " .. node .. " refuses a mount item put")
	eq(node_move(node, "t:stone"), 0, "B " .. node .. " refuses a soulbound move")
	eq(node_move(node, "grug_abilities:strike"), 0, "B " .. node .. " refuses a skill move")
end
eq(node_put("n:plain", "t:ore 5"), 5, "B a node without callbacks takes the stack")
eq(node_move("n:plain", "t:ore"), 1, "B ...and moves the count")
eq(node_put("n:own", "t:ore"), 7, "B a node's own put answers")
eq(node_move("n:own", "t:ore"), 5, "B a node's own move answers")

-- Detached inventories.
local function det_put(name, stack)
	return core.detached_inventories[name].allow_put({}, "x", 1, ItemStack(stack), nil)
end
local function det_move(name, stack)
	local inv = {get_stack = function() return ItemStack(stack) end}
	return core.detached_inventories[name].allow_move(inv, "x", 1, "x", 2, 1, nil)
end
for _, f in ipairs(callbacks.join) do f({}) end
core.create_detached_inventory("grug_workspace_hero_1", {
	allow_put = function(_, _, _, stack) return stack:get_count() end})
core.create_detached_inventory("grug_skills_hero", {})
for _, name in ipairs({"creative_trash", "grug_workspace_hero_1"}) do
	eq(det_put(name, "t:stone"), 0, "B " .. name .. " refuses a soulbound put")
	eq(det_put(name, "grug_abilities:strike"), 0, "B " .. name .. " refuses a skill put")
	eq(det_put(name, "t:mount"), 0, "B " .. name .. " refuses a mount item put")
	eq(det_move(name, "t:stone"), 0, "B " .. name .. " refuses a soulbound move")
	eq(det_move(name, "grug_abilities:strike"), 1, "B " .. name .. " leaves a skill move alone")
	eq(det_put(name, "t:ore 3"), 3, "B " .. name .. " takes anything else")
end
eq(det_put("grug_skills_hero", "grug_abilities:strike"), 1, "B the own catalog takes a skill back")
eq(det_put("grug_skills_hero", "t:stone"), 0, "B ...but no soulbound item")
-- The trash box's hint wraps the box after its creation and sees refusals.
core.create_detached_inventory("grug_trash_hero", {allow_put = function(_, _, _, s) return s:get_count() end})
local box = core.detached_inventories.grug_trash_hero
local guarded, seen = box.allow_put, nil
box.allow_put = function(...)
	local count = guarded(...)
	seen = count
	return count
end
eq(det_put("grug_trash_hero", "grug_abilities:strike"), 0, "B the trash refuses a skill")
eq(seen, 0, "B ...and an outer wrapper sees the refusal")

if failures > 0 then
	print(("R81 GUARDS PORTABLE FAIL %d of %d"):format(failures, checks))
	os.exit(1)
end
print(("R81 GUARDS PORTABLE PASS checks=%d"):format(checks))
