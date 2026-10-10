-- Release 0.45.1 lane NQ portable test (LuaJIT).
--
--   Q. The quest giver's preselection (grug_quests/npc.lua): the dialog opens
--      on the first quest ready to complete, else the first available one,
--      else the first row; after a Complete or an Accept it preselects again
--      (after an Accept with nothing ready or acceptable left it stays on the
--      accepted quest); a failed Accept or Complete stays on that quest; a
--      click in the list shows the clicked row; the cue plays on
--      the first open only; the Close button holds the focus.
--   P. Placement into standing room (grug_mobs/start_npcs.lua `serve`): a
--      socket with its floor under it is placed at the socket; one whose feet
--      cell is a stair is lifted onto it; one over the unfinished shell (air
--      under it) waits until its floor exists; one over air for good is placed
--      at the socket after PLACE_PATIENCE passes, with a warning.
--   R. The activation re-seat (`start_npc_claim`): an NPC whose shins are
--      inside a solid full node goes back to its socket's standing cell; one
--      on a stair, in a door, standing normally away from its socket, sunk at
--      a socket without standing room, or a capital display, stays put.
--
--   luajit tools/r451_nq/portable_test.lua [REPO]
-- Prints "R451 NQ PORTABLE PASS checks=<n>" or the failures.

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
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end

------------------------------------------------------------------------------
-- Q. The quest giver's preselection.
------------------------------------------------------------------------------
do
	local shown, sounds, handler = nil, {}, nil
	core = {
		formspec_escape = function(s) return (s:gsub("[%[%];,\\]", "\\%0")) end,
		colorize = function(color, text) return color .. text end,
		show_formspec = function(_, _, form) shown = form end,
		close_formspec = function() shown = "closed" end,
		register_on_player_receive_fields = function(fn) handler = fn end,
		register_on_leaveplayer = function() end,
		register_entity = function() end,
		explode_textlist_event = function(text)
			local kind, index = text:match("^(%u+):(%d+)$")
			return {type = kind, index = tonumber(index)}
		end,
	}
	grug_sounds = {play = function(event) sounds[#sounds + 1] = event end}
	grug_factions = {serves = function() return true end, refuse = function() end}
	grug_money = {format = function(c) return c .. "c" end}
	grug_core = {item_name = function() return "" end, register_tag_visibility = function() end}
	ItemStack = function() return {get_count = function() return 1 end} end
	vector = {distance = function() return 0 end}
	local rows
	grug_quests = {
		npc_by_socket = {["s/1"] = "giver"},
		registered_npcs = {giver = {faction = "accord", title = "Giver"}},
		registered_quests = {},
		quest_text = function(def) return "Text " .. def.id end,
		cooldown_text = function() return "1 h" end,
		objective_action = function() return "Defeat" end,
		objective_levels_text = function() return "" end,
		reward_xp = function() return 10 end,
		npc_quests = function() return copy(rows) end,
	}
	for _, id in ipairs({"q1", "q2", "q3", "q4", "q5"}) do
		grug_quests.registered_quests[id] = {id = id, npc = "giver", turnin_npc = "giver",
			objectives = {}, rewards = {copper = 5, items = {}}}
	end
	assert(loadfile(ROOT .. "/mods/PLAYER/grug_quests/npc.lua"))()
	local Q = grug_quests
	local player = {get_player_name = function() return "alice" end, is_player = function() return true end,
		get_hp = function() return 20 end, get_pos = function() return {x = 0, y = 0, z = 0} end}
	local entity = {_grug_start = "s", _grug_socket = "1", object = {is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 0, z = 0} end}}
	local function on_row()
		return tonumber(shown:match("textlist%[[^%]]-;quests;[^%]]-;(%d+);false%]"))
	end
	local function shows(id) return shown:find("Text " .. id, 1, true) ~= nil end
	local function row(id, status) return {id = id, title = "T " .. id, status = status} end

	-- The rule over the statuses.
	eq(Q.npc_preselect({row("q1", "available"), row("q2", "active"), row("q3", "ready"),
		row("q4", "ready")}), 3, "Q ready first, the first of them")
	eq(Q.npc_preselect({row("q1", "locked"), row("q2", "active"), row("q3", "available"),
		row("q4", "available")}), 3, "Q else the first available")
	eq(Q.npc_preselect({row("q1", "active"), row("q2", "locked")}), 1, "Q else the first row")

	-- The first open: the first ready quest, its Complete button, the cue.
	rows = {row("q1", "available"), row("q2", "active"), row("q3", "ready"), row("q4", "ready"),
		row("q5", "locked")}
	eq(Q.open_npc(player, entity), true, "Q the dialog opens")
	eq(on_row(), 3, "Q the dialog opens on the first ready quest")
	check(shows("q3"), "Q ...and shows its text")
	check(shown:find("turnin;Complete]", 1, true) ~= nil, "Q ...with Complete")
	eq(#sounds, 1, "Q the first open plays its cue")
	eq(sounds[1], "npc_quest", "Q ...the quest giver's cue")
	local focus = shown:find("set_focus[close;true]", 1, true)
	local close = shown:find("button_exit[13.3,8.4;2.3,0.7;close;Close]", 1, true)
	check(focus ~= nil and close ~= nil and focus < close, "Q Close holds the focus (set before it)")

	-- A click in the list shows the clicked row, without the open cue.
	handler(player, "grug_quests:dialogue", {quests = "CHG:1"})
	eq(on_row(), 1, "Q a click shows the clicked row")
	check(shown:find("accept;Accept]", 1, true) ~= nil, "Q ...an available quest with Accept")
	eq(#sounds, 2, "Q a click plays the page cue only")
	eq(sounds[2], "quest_page", "Q ...the page cue")

	-- Complete: the quest leaves the list; the next ready quest is preselected.
	handler(player, "grug_quests:dialogue", {quests = "CHG:3"})
	Q.turn_in = function(_, id)
		for index, r in ipairs(rows) do if r.id == id then table.remove(rows, index) end end
		return true, "Quest completed."
	end
	handler(player, "grug_quests:dialogue", {turnin = "Complete"})
	eq(on_row(), 3, "Q after Complete the next ready quest is preselected")
	check(shows("q4"), "Q ...q4, now row 3")
	check(shown:find("Quest completed.", 1, true) ~= nil, "Q ...with the notice")
	handler(player, "grug_quests:dialogue", {turnin = "Complete"})
	eq(on_row(), 1, "Q after the last Complete the first available quest is preselected")
	check(shows("q1"), "Q ...q1")
	local cues = 0
	for _, s in ipairs(sounds) do if s == "npc_quest" then cues = cues + 1 end end
	eq(cues, 1, "Q no open cue on a redraw after Complete")

	-- A failed Complete stays on its quest.
	rows = {row("q1", "available"), row("q2", "ready"), row("q3", "ready")}
	Q.open_npc(player, entity)
	handler(player, "grug_quests:dialogue", {quests = "CHG:3"})
	Q.turn_in = function() return false, "Your coin purse cannot hold the reward." end
	handler(player, "grug_quests:dialogue", {turnin = "Complete"})
	eq(on_row(), 3, "Q a failed Complete stays on its quest")

	-- A successful Accept preselects: the next ready, else acceptable quest;
	-- only when there is none it stays on the accepted quest (the user,
	-- 2026-10-10).
	local function accept_marks_active()
		Q.accept = function(_, id)
			for _, r in ipairs(rows) do if r.id == id then r.status = "active" end end
			return true, "Quest accepted."
		end
	end
	accept_marks_active()
	rows = {row("q1", "available"), row("q2", "available"), row("q3", "available")}
	Q.open_npc(player, entity)
	eq(on_row(), 1, "Q opens on the first acceptable quest")
	handler(player, "grug_quests:dialogue", {accept = "Accept"})
	eq(on_row(), 2, "Q after Accept the next acceptable quest is preselected")
	check(shown:find("Quest accepted.", 1, true) ~= nil, "Q ...with the notice")
	handler(player, "grug_quests:dialogue", {accept = "Accept"})
	eq(on_row(), 3, "Q ...and again")
	handler(player, "grug_quests:dialogue", {accept = "Accept"})
	eq(on_row(), 3, "Q after the last Accept it stays on the accepted quest")
	check(shows("q3"), "Q ...q3, now in progress")
	rows = {row("q1", "active"), row("q2", "available"), row("q3", "ready")}
	Q.open_npc(player, entity, 2)
	handler(player, "grug_quests:dialogue", {accept = "Accept"})
	eq(on_row(), 3, "Q after Accept a ready quest comes first")
	-- A failed Accept stays on its quest.
	rows = {row("q1", "available"), row("q2", "available")}
	Q.open_npc(player, entity, 2)
	Q.accept = function() return false, "Your quest log is full (20 quests)." end
	handler(player, "grug_quests:dialogue", {accept = "Accept"})
	eq(on_row(), 2, "Q a failed Accept stays on its quest")
	-- An accepted quest handed in elsewhere leaves this list: preselection.
	rows = {row("q1", "available"), row("q2", "active")}
	Q.open_npc(player, entity, 1)
	Q.accept = function(_, id)
		for index, r in ipairs(rows) do if r.id == id then table.remove(rows, index) end end
		return true, "Quest accepted."
	end
	handler(player, "grug_quests:dialogue", {accept = "Accept"})
	eq(on_row(), 1, "Q after Accept of a quest handed in elsewhere: the first row")
	check(shows("q2"), "Q ...q2")
	core, grug_sounds, grug_factions, grug_money, grug_core, ItemStack, vector, grug_quests =
		nil, nil, nil, nil, nil, nil, nil, nil
end

------------------------------------------------------------------------------
-- P and R. The real start_npcs.lua under an engine model (tools/r30_c's).
------------------------------------------------------------------------------
local serial, logs, steps, loaded, after = {}, {}, {}, {}, {}
local entity_defs = {}
local clock = 1000
-- The world: unset cells are air; `world` holds the rest.
local world = {}
local function key3(x, y, z) return x .. "," .. y .. "," .. z end
local function set(x, y, z, name) world[key3(x, y, z)] = name end
core = {
	registered_entities = entity_defs,
	registered_nodes = {
		air = {walkable = false, drawtype = "airlike"},
		["default:dirt"] = {walkable = true},
		["stairs:stair_stone"] = {walkable = true, drawtype = "nodebox"},
		["doors:door_wood_a"] = {walkable = true, drawtype = "mesh"},
	},
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
	pos_to_string = function(p) return ("(%s,%s,%s)"):format(p.x, p.y, p.z) end,
	get_node_or_nil = function(p)
		local x, y, z = math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5)
		return {name = world[key3(x, y, z)] or "air"}
	end,
	compare_block_status = function() return false end,
}

local live = {}
local function activate(name, staticdata, pos)
	local def = assert(entity_defs[name], name)
	local object = {pos = copy(pos), valid = true}
	local entity = setmetatable({name = name, object = object}, {__index = def})
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	function object:set_yaw(y) self.yaw = y end
	for k, v in pairs(core.deserialize(staticdata) or {}) do entity[k] = v end
	live[#live + 1] = entity
	if def.after_activate then def.after_activate(entity) end
	return object, entity
end
core.add_entity = function(pos, name, staticdata) return (activate(name, staticdata, pos)) end
core.get_objects_inside_radius = function()
	local out = {}
	for _, entity in ipairs(live) do
		if entity.object.valid then out[#out + 1] = entity.object end
	end
	return out
end
local function holder(socket_id)
	for _, entity in ipairs(live) do
		if entity.object.valid and entity._grug_socket == socket_id then return entity end
	end
end

-- One start; every socket at y 11 over ground at y 10 unless set otherwise.
local ANCHOR = {x = 0, y = 10, z = 0}
local SOCKETS = {
	{id = "ok", role = "idle", pos = {x = 0, y = 11, z = 0}, yaw = 0},
	{id = "stair", role = "work", activity = "pray", pos = {x = 4, y = 11, z = 0}, yaw = 0},
	{id = "shell", role = "quest", pos = {x = 8, y = 11, z = 0}, yaw = 0},
	{id = "floating", role = "guard_post", pos = {x = 12, y = 11, z = 0}, yaw = 0},
}
for x = -2, 14 do
	for z = -2, 2 do
		for y = 0, 10 do set(x, y, z, "default:dirt") end
	end
end
set(4, 11, 0, "stairs:stair_stone") -- the stair under the work socket
world[key3(8, 10, 0)] = nil -- the shell: no floor yet
world[key3(12, 10, 0)] = nil -- over air for good
grug_core = {
	start_identities = function() return {{race_id = "human", faction_id = "accord"}} end,
	settlement_socket_settlements = function()
		return {{key = "dawnmere", race_id = "human", anchor = ANCHOR}}
	end,
	settlement_sockets_at = function() return copy(SOCKETS) end,
	start_anchor = function() return ANCHOR end,
	capital_anchor = function() return nil end,
	start_ready = function() return true end,
	register_on_starts_progress = function() end,
}
local store = {}
mobs = {mob_class = {}}
function mobs:remove(entity) entity.object:remove() end
grug_mobs = {
	storage = {
		get_string = function(_, k) return store[k] or "" end,
		set_string = function(_, k, v) store[k] = v end,
	},
	-- init.lua's: the collision-box lift (town NPCs have min y 0).
	place_on_ground = function(object, pos) object.pos = copy(pos) end,
	face_yaw = function() end,
	refresh_visual = function() end,
	route_settlement = function() end,
}
do
	local handle = assert(io.open(ROOT .. "/mods/ENTITIES/grug_mobs/data/pvp_names.json", "rb"))
	local names = dofile(ROOT .. "/tools/r28_b1/json.lua").parse(handle:read("*a"))
	handle:close()
	grug_mobs.pvp_garrison = dofile(ROOT .. "/mods/ENTITIES/grug_mobs/pvp_garrison.lua").new(
		dofile(ROOT .. "/mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua"), names)
end
local BOX = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}
for _, name in ipairs({"grug_mobs:villager_human", "grug_mobs:elder_human", "grug_mobs:guard_accord"}) do
	entity_defs[name] = {collisionbox = BOX,
		after_activate = function(self) grug_mobs.start_npc_claim(self) end}
end
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

-- P. The ready pass.
for _, fn in ipairs(after) do fn() end
local ok, stair = holder("ok"), holder("stair")
check(ok ~= nil, "P a socket with its floor is placed")
eq(ok and ok.object.pos.y, 11, "P ...at the socket")
check(stair ~= nil, "P a socket on a stair is placed")
eq(stair and stair.object.pos.y, 12, "P ...lifted onto the stair")
eq(count_logs("(standing at y 12)"), 1, "P ...and the placement line says so")
eq(holder("shell"), nil, "P a socket over the shell waits")
eq(holder("floating"), nil, "P a socket over air waits")
-- The shell's chunk is written: the floor exists.
set(8, 10, 0, "default:dirt")
heartbeat()
local shell = holder("shell")
check(shell ~= nil, "P the waiting socket is placed once its floor exists")
eq(shell and shell.object.pos.y, 11, "P ...at the socket")
eq(holder("floating"), nil, "P the socket over air still waits")
for _ = 1, 9 do heartbeat() end
eq(holder("floating"), nil, "P ...for eleven passes")
heartbeat()
local floating = holder("floating")
check(floating ~= nil, "P after PLACE_PATIENCE passes it is placed")
eq(floating and floating.object.pos.y, 11, "P ...at the socket, as before 0.45.1")
eq(count_logs("has no standing room after 12 passes"), 1, "P ...with one warning")
eq(count_logs("placed at socket"), 4, "P four placements")
eq(count_logs("re-seated"), 0, "P a fresh placement is never re-seated")

-- R. The activation re-seat: every NPC goes out of memory with a position
-- and comes back with it.
local stored = {}
local function save(entity, pos)
	local fields = {}
	for k, v in pairs(entity) do
		if type(v) ~= "function" and k ~= "object" and k ~= "name" then fields[k] = copy(v) end
	end
	stored[#stored + 1] = {name = entity.name, data = fields, pos = pos}
	entity.object.valid = false
end
local function reload()
	live = {}
	local out = {}
	for _, row in ipairs(stored) do
		local _, entity = activate(row.name, core.serialize(row.data), row.pos)
		out[row.data._grug_socket] = entity
	end
	stored = {}
	return out
end
logs = {}
save(ok, {x = 0, y = 9.5, z = 0}) -- sunk one node: shins in the dirt at y 10
save(stair, {x = 4, y = 11, z = 0.2}) -- on the stair's lower step: shins in the stair
save(shell, {x = 3, y = 10.5, z = 1}) -- away from its socket, standing on the ground
save(floating, {x = 12, y = 9.5, z = 0}) -- sunk, but its socket has no standing room
local back = reload()
eq(back.ok.object.pos.y, 11, "R a sunk NPC is re-seated at its socket")
eq(back.ok.object.pos.x, 0, "R ...on its socket's column")
eq(count_logs("of socket ok stood inside default:dirt"), 1, "R ...with one log line")
eq(back.stair.object.pos.y, 11, "R an NPC on a stair stays")
eq(back.shell.object.pos.x, 3, "R an NPC standing away from its socket stays")
eq(back.floating.object.pos.y, 9.5, "R a sunk NPC at a socket without standing room stays")
eq(count_logs("re-seated"), 1, "R one re-seat")
-- A door is no ground: an NPC passing one is not moved.
set(1, 11, 0, "doors:door_wood_a")
logs = {}
save(back.ok, {x = 1, y = 10.5, z = 0})
back = reload()
eq(back.ok.object.pos.x, 1, "R an NPC in a doorway stays")
eq(count_logs("re-seated"), 0, "R ...no re-seat")
-- A capital display sets its own height and is never re-seated.
local display = {_grug_capital_display = true, _grug_start = "dawnmere", _grug_socket = "ok",
	object = {pos = {x = 0, y = 9.5, z = 0}, get_pos = function(self) return copy(self.pos) end}}
grug_mobs.start_npc_reseat_sunk(display)
eq(display.object.pos.y, 9.5, "R a capital display is not re-seated")
-- The standing cell itself.
local cell = grug_mobs.start_npc_standing_cell({x = 4, y = 11, z = 0})
eq(cell and cell.y, 12, "R the standing cell over a stair is one up")
eq(grug_mobs.start_npc_standing_cell({x = 12, y = 11, z = 0}), nil, "R none over air")
set(0, 12, 0, "default:dirt")
set(0, 13, 0, "default:dirt")
set(0, 14, 0, "default:dirt")
eq(grug_mobs.start_npc_standing_cell({x = 0, y = 11, z = 0}), nil, "R none within the lift of two")

if failures > 0 then
	print(("%d checks, %d failures"):format(checks, failures))
	os.exit(1)
end
print(("R451 NQ PORTABLE PASS checks=%d"):format(checks))
