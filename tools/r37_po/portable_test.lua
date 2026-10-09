-- Round 37 lane PO portable test (LuaJIT): per-player polling (audit P5;
-- round37-plan.md §4.5, §2.4).
--
--   luajit tools/r37_po/portable_test.lua [repo]
--
-- Loads the REAL grug_quests registry, state, labels, npc and hud files, the
-- REAL grug_core hud_layout and item_names, the REAL grug_map atlas, base,
-- minimap_view, minimap and providers and the REAL (pure) grug_housing
-- registry on a fake engine. Checks:
--   M  minimap (CORE-04): a still player with a still party places nothing
--      and sends nothing; a move places the map again exactly when the map
--      corner moves by a whole screen pixel (the real geometry decides);
--      a party member's move or a turn to another heading frame places only
--      the party arrows; a turn inside one frame places nothing; a marker
--      change and a window (zoom) change place the map again; after every
--      step a full redraw (M.refresh) would send nothing, so the cheap path
--      left the HUD exactly as a full update would; the 5 s check asks the
--      providers only when the markers' key (quest version, home,
--      waystones, faction) changed;
--   K  quest markers (PLY-06): marker_states is recomputed on an accept, a
--      turn-in, a level-up, a held objective item (the tracker's poll) and
--      a repeatable's cooldown ending, and not otherwise (the level is read
--      once per recompute, which counts them); after every operation of a
--      long scripted sequence the memo equals a full recompute (the most
--      urgent Q.npc_quests row per NPC);
--   T  tracker (PLY-05): without an active item objective a poll reads no
--      inventory list and the tracker line still follows kills; with one it
--      reads them and the line follows held items as before;
--   D  retired in Round 45 (the recipe discovery is gone);
--   C  Claim Stone (PLY-04): a placement that fails several rules shows the
--      first in the order depth, faction, one claim, overlap, settlement,
--      zone scan, cube (every combination); a held click on one spot runs
--      the 10,201-column scan once (also at another height), a new column
--      scans again, a world that is not `fixed` scans every time, and the
--      cache stays bounded.
-- Prints "R37 PO PORTABLE PASS checks=<n>" or the failures.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local out = {}
	seen[value] = out
	for k, v in pairs(value) do out[deep_copy(k, seen)] = deep_copy(v, seen) end
	return out
end
table.copy = function(value) return deep_copy(value) end
function table.indexof(list, value)
	for i, v in ipairs(list) do if v == value then return i end end
	return -1
end
local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local keys, parts = {}, {}
		for k in pairs(value) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		for _, k in ipairs(keys) do parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k]) end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end
local function deserialize(text)
	if text == "" then return nil end
	return assert(loadstring("return " .. text))()
end

-- ---------------------------------------------------------------------------
-- Fake engine
-- ---------------------------------------------------------------------------
local Stack = {}
Stack.__index = Stack
function ItemStack(value)
	if getmetatable(value) == Stack then return setmetatable({name = value.name, count = value.count}, Stack) end
	local name, count = "", 0
	if type(value) == "string" and value ~= "" then
		local n, c = value:match("^(%S+)%s*(%d*)$")
		name, count = n, tonumber(c) or 1
	end
	return setmetatable({name = name, count = count}, Stack)
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count == 0 end
function Stack:equals(other) return self:get_name() == other:get_name() and self.count == other.count end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	self.count = self.count - n
	local name = self.name
	if self.count == 0 then self.name = "" end
	return ItemStack(name .. " " .. n)
end
function Stack:add_item(item)
	item = ItemStack(item)
	if item:is_empty() then return item end
	if self:is_empty() then self.name, self.count = item.name, item.count; return ItemStack("") end
	if self.name ~= item.name then return item end
	local moved = math.min(99 - self.count, item.count)
	self.count, item.count = self.count + moved, item.count - moved
	if item.count == 0 then item.name = "" end
	return item
end

local registered = {}
local us = 1000000
local players, windows = {}, {}
local item_groups = {["default:tree"] = {log = 1}}
core = {
	registered_items = {["grug_food:raw_meat"] = {description = "Raw Meat"},
		["default:tree"] = {description = "Tree"}, ["default:dirt"] = {description = "Dirt"},
		["default:copper_ingot"] = {description = "Copper Ingot"}},
	registered_entities = {["grug_mobs:boar"] = {description = "Boar"}},
	get_translated_string = function(_, text) return text end,
	get_us_time = function() return us end,
	get_item_group = function(name, group) return (item_groups[name] or {})[group] or 0 end,
	serialize = serialize,
	deserialize = deserialize,
	log = function() end,
	get_player_by_name = function(name) return players[name] end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		table.sort(list, function(a, b) return a.name < b.name end)
		return list
	end,
	get_player_window_information = function(name) return windows[name] end,
	formspec_escape = function(text)
		return (text:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_modnames = function() return {"grug_map"} end,
	get_worldpath = function() return "/nonexistent-world" end,
	settings = {get = function() return nil end},
	encode_png = function(_, _, data) return data end,
	safe_file_write = function() return true end,
	dynamic_add_media = function() return true end,
	add_item = function() end,
	chat_send_player = function() end,
	show_formspec = function() end,
	close_formspec = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then
		return function(fn)
			registered[key] = registered[key] or {}
			registered[key][#registered[key] + 1] = fn
		end
	end
end})
local function each(kind, ...)
	for _, fn in ipairs(registered[kind] or {}) do fn(...) end
end
vector = {distance = function(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end, new = function(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end}

local hud_changes = 0
local list_reads = 0 -- every get_list / get_lists of any player
local function new_player(name, pos)
	local p = {name = name, pos = pos, yaw = 0, meta = {}, huds = {}, next_hud = 0,
		lists = {main = {}, craft = {}}}
	for i = 1, 16 do p.lists.main[i] = ItemStack("") end
	for i = 1, 9 do p.lists.craft[i] = ItemStack("") end
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_look_horizontal() return self.yaw end
	function p:get_hp() return 20 end
	function p:is_player() return true end
	function p:get_meta()
		local m = self.meta
		return {get_string = function(_, k) return m[k] or "" end,
			set_string = function(_, k, v) m[k] = v ~= "" and v or nil end}
	end
	function p:get_inventory()
		local lists = self.lists
		return {
			get_list = function(_, list)
				list_reads = list_reads + 1
				local out = {}
				for i, s in ipairs(lists[list] or {}) do out[i] = ItemStack(s) end
				return out
			end,
			get_lists = function()
				list_reads = list_reads + 1
				local out = {}
				for listname, list in pairs(lists) do
					out[listname] = {}
					for i, s in ipairs(list) do out[listname][i] = ItemStack(s) end
				end
				return out
			end,
			get_stack = function(_, list, i) return ItemStack(lists[list][i]) end,
			set_stack = function(_, list, i, s) lists[list][i] = ItemStack(s); return true end,
			add_item = function(_, list, s)
				local rest = ItemStack(s)
				for _, slot in ipairs(lists[list]) do
					if rest:is_empty() then break end
					rest = slot:add_item(rest)
				end
				return rest
			end,
		}
	end
	function p:give(item) return self:get_inventory():add_item("main", item) end
	function p:take(name)
		for i, stack in ipairs(self.lists.main) do
			if stack:get_name() == name then self.lists.main[i] = ItemStack("") end
		end
	end
	function p:hud_add(def) self.next_hud = self.next_hud + 1; self.huds[self.next_hud] = deep_copy(def); return self.next_hud end
	function p:hud_change(id, stat, value) hud_changes = hud_changes + 1; self.huds[id][stat] = value end
	function p:hud_remove(id) self.huds[id] = nil end
	function p:hud_set_flags() end
	function p:set_minimap_modes() end
	return p
end
local function join(p)
	players[p.name] = p
	windows[p.name] = windows[p.name] or {size = {x = 1920, y = 1080}, real_hud_scaling = 1,
		real_gui_scaling = 1}
	each("register_on_joinplayer", p)
end

-- ---------------------------------------------------------------------------
-- The game around the files
-- ---------------------------------------------------------------------------
local level_reads, levels = 0, {}
local sockets = {
	{id = "a", role = "quest", pos = {x = 100, y = 10, z = -200}},
	{id = "b", role = "quest", pos = {x = 140, y = 10, z = -230}},
	{id = "c", role = "quest", pos = {x = 60, y = 10, z = -260}},
}
grug_core = {
	register_tag_visibility = function() end,
	feed_item = function() end,
	feed = function() return true end,
	settlement_socket_settlements = function()
		return {{key = "s", race_id = "human", anchor = {x = 90, z = -220}}}
	end,
	settlement_sockets_at = function(key) return key == "s" and sockets or {} end,
	zone_authority_installed = function() return false end,
	faction_ids = {"accord", "throng"},
	start_identities = function() return {{race_id = "human", faction_id = "accord"}} end,
}
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
grug_inventory = {BAG_COUNT = 0, wrap_text = function(text) return text end,
	UI = {width = 10.4, height = 11.1}}
local factions = {}
grug_factions = {get_faction = function(p) return factions[p:get_player_name()] or "accord" end,
	same_faction = function() return false end,
	register_on_faction_chosen = function() end,
	display_name = function(id) return "The " .. id end}
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")
grug_classes = {get_race = function() return "human" end}
local level_changes = {}
grug_xp = {get_level = function(p)
	level_reads = level_reads + 1
	return levels[p:get_player_name()] or 1
end, add_xp = function() end, quest_reward = function() return 10 end,
	register_on_level_change = function(fn) level_changes[#level_changes + 1] = fn end}
local function level_up(player, new_level)
	local old = levels[player:get_player_name()] or 1
	levels[player:get_player_name()] = new_level
	for _, fn in ipairs(level_changes) do fn(player, old, new_level) end
end
grug_money = {MAX = 1e9, get = function() return 0 end, add = function() end,
	format = function(c) return c .. "c" end}
grug_mobs = {register_on_eligible_kill = function() end, register_participant_drop_hook = function() end,
	dragon_map_markers = function() return {} end}
grug_zones = {id_at = function() return "z" end, at = function() return nil end}
grug_quests = {}
for _, file in ipairs({"registry", "state", "labels", "npc", "hud"}) do
	dofile(repo .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
local Q = grug_quests
local hud_step = registered.register_globalstep[1]
local function hud_steps(seconds)
	for _ = 1, math.floor(seconds / 0.1 + 0.5) do hud_step(0.1) end
end

Q.register_npc("elder", {settlement = "s", socket = "a", title = "Elder Maren"})
Q.register_npc("hunter", {settlement = "s", socket = "b", title = "Hunter Brosk"})
Q.register_npc("envoy", {settlement = "s", socket = "c", title = "Envoy Lysa"})
local function quest(id, def)
	def.title, def.description = def.title or id, def.description or "Text of " .. id
	def.rewards = def.rewards or {weight = 1, copper = 5}
	Q.register_quest(id, def)
end
quest("hunt", {npc = "elder", objectives = {{type = "kill", mobs = {"grug_mobs:boar"}, names = {{"Boar"}}, name_set = {Boar = true}, count = 2}}})
quest("meat", {npc = "elder", prerequisites = {"hunt"},
	objectives = {{type = "item", item = "grug_food:raw_meat", count = 2}}})
quest("logs", {npc = "hunter", objectives = {{type = "item", group = "log", count = 2}}})
quest("bounty", {npc = "hunter", repeatable = {cooldown = 60},
	objectives = {{type = "kill", mobs = {"grug_mobs:boar"}, names = {{"Boar"}}, name_set = {Boar = true}, count = 1}}})
quest("veteran", {npc = "envoy", min_level = 5, objectives = {{type = "kill", mobs = {"grug_mobs:boar"}, names = {{"Boar"}}, name_set = {Boar = true}, count = 1}}})
local clock = 1000
Q.clock = function() return clock end
local boar = {name = "grug_mobs:boar", description = "Boar", object = {}}

-- ---------------------------------------------------------------------------
-- K: quest markers
-- ---------------------------------------------------------------------------
local priority = {ready = 1, available = 2, active = 3, locked = 4}
-- A full recompute: the most urgent npc_quests row per NPC (no memo).
local function full(player)
	local result = {}
	for _, npc in ipairs({"elder", "hunter", "envoy"}) do
		local best
		for _, row in ipairs(Q.npc_quests(player, npc)) do
			if not best or priority[row.status] < priority[best] then best = row.status end
		end
		result[npc] = best
	end
	return result
end
local function agrees(player, label)
	local states = Q.marker_states(player)
	local expected, same = full(player), true
	for _, npc in ipairs({"elder", "hunter", "envoy"}) do
		if states[npc] ~= expected[npc] then same = false end
	end
	check(same, "K the memo equals a full recompute: " .. label)
end
-- Whether the next marker_states call recomputes (one level read each).
local function recomputes(player)
	local before = level_reads
	Q.marker_states(player)
	return level_reads > before
end

local ann = new_player("ann", {x = 100, y = 10, z = -205})
join(ann)
check(recomputes(ann), "K the first call computes")
check(not recomputes(ann), "K a second call is the memo")
us = us + 5000000
check(not recomputes(ann), "K the memo outlives a second (Round 37)")
hud_steps(2.0)
check(not recomputes(ann), "K quiet tracker polls keep the memo")
Q.accept(ann, "hunt")
check(recomputes(ann), "K an accept recomputes")
agrees(ann, "after accept")
eq(Q.marker_states(ann).elder, "active", "K the accepted quest is active at the elder")
Q.credit_kill(ann, boar, {x = 0, y = 0, z = 0})
Q.credit_kill(ann, boar, {x = 0, y = 0, z = 0})
check(recomputes(ann), "K a kill credit recomputes")
eq(Q.marker_states(ann).elder, "ready", "K two kills: ready")
Q.turn_in(ann, "hunt")
check(recomputes(ann), "K a turn-in recomputes")
agrees(ann, "after turn-in")
eq(Q.marker_states(ann).elder, "available", "K the follow-up unlocks")
eq(Q.marker_states(ann).envoy, "locked", "K level 1: the veteran quest is locked")
level_up(ann, 5)
check(recomputes(ann), "K a level-up recomputes")
eq(Q.marker_states(ann).envoy, "available", "K level 5: the veteran quest is available")
-- held objective items: the tracker's poll tells the memo
Q.accept(ann, "logs")
Q.marker_states(ann)
hud_steps(0.5)
check(not recomputes(ann), "K a quiet poll with an item objective keeps the memo")
ann:give("default:tree 2")
check(not recomputes(ann), "K an item change waits for the tracker's poll")
hud_steps(0.5)
check(recomputes(ann), "K the poll's held-item change recomputes")
eq(Q.marker_states(ann).hunter, "ready", "K two logs: ready at the hunter")
ann:give("default:dirt 5")
hud_steps(0.5)
check(not recomputes(ann), "K a non-objective item keeps the memo")
-- a repeatable's cooldown
Q.turn_in(ann, "logs")
Q.accept(ann, "bounty")
Q.credit_kill(ann, boar, {x = 0, y = 0, z = 0})
Q.turn_in(ann, "bounty")
agrees(ann, "bounty cooling down")
check(not recomputes(ann), "K during the cooldown the memo holds")
clock = clock + 59
check(not recomputes(ann), "K ...a second before its end too")
clock = clock + 1
check(recomputes(ann), "K the cooldown's end recomputes")
eq(Q.marker_states(ann).hunter, "available", "K the bounty is available again")
check(not recomputes(ann), "K ...and then the memo holds again")
-- a long scripted sequence: after every step (and the tracker's poll) the
-- memo equals a full recompute
do
	local bob = new_player("bob", {x = 0, y = 10, z = 0})
	join(bob)
	local ops = {
		function() Q.accept(bob, "hunt") end,
		function() Q.credit_kill(bob, boar, {x = 0, y = 0, z = 0}) end,
		function() bob:give("grug_food:raw_meat 1") end,
		function() Q.turn_in(bob, "hunt") end,
		function() Q.accept(bob, "meat") end,
		function() bob:give("grug_food:raw_meat 1") end,
		function() bob:take("grug_food:raw_meat") end,
		function() level_up(bob, 6) end,
		function() Q.accept(bob, "bounty") end,
		function() Q.abandon(bob, "bounty") end,
		function() bob:give("grug_food:raw_meat 3") end,
		function() Q.turn_in(bob, "meat") end,
		function() Q.accept(bob, "logs") end,
		function() bob:give("default:tree 1") end,
		function() level_up(bob, 2) end,
		function() bob:give("default:tree 1") end,
		function() Q.turn_in(bob, "logs") end,
		function() clock = clock + 30 end,
		function() Q.accept(bob, "bounty"); Q.credit_kill(bob, boar, {x = 0, y = 0, z = 0}); Q.turn_in(bob, "bounty") end,
		function() clock = clock + 61 end,
	}
	for i, op in ipairs(ops) do
		op()
		hud_steps(0.5)
		agrees(bob, "sequence step " .. i)
	end
	players.bob = nil
	each("register_on_leaveplayer", bob, false)
end

-- ---------------------------------------------------------------------------
-- T: tracker without and with item objectives
-- ---------------------------------------------------------------------------
do
	local cy = new_player("cy", {x = 0, y = 10, z = 0})
	join(cy)
	Q.accept(cy, "hunt")
	hud_steps(0.5)
	local reads = list_reads
	hud_steps(2.0)
	eq(list_reads - reads, 0, "T kill objectives only: a poll reads no inventory list")
	local line = function()
		for _, hud in pairs(cy.huds) do if hud.number == 0xffe080 then return hud.text end end
	end
	Q.credit_kill(cy, boar, {x = 0, y = 0, z = 0})
	check((line() or ""):find("1/2", 1, true) ~= nil, "T ...and the line follows a kill (" .. tostring(line()) .. ")")
	Q.accept(cy, "logs")
	hud_steps(0.5)
	reads = list_reads
	hud_steps(0.5)
	check(list_reads - reads >= 1, "T with an item objective the poll reads the inventory")
	cy:give("default:tree 1")
	hud_steps(0.5)
	check((line() or ""):find("1/2 Bring Any Log", 1, true) ~= nil,
		"T ...and the line follows a held item (" .. tostring(line()) .. ")")
	local raw, held, counts = Q.journal_key(cy)
	check(held ~= "" and counts["default:tree"] == 1, "T the key carries the held item")
	Q.abandon(cy, "logs")
	local _, held2, counts2 = Q.journal_key(cy)
	check(held2 == "" and type(counts2) == "table" and next(counts2) == nil,
		"T no item objective: empty key part and an empty snapshot")
	players.cy = nil
	each("register_on_leaveplayer", cy, false)
end

-- ---------------------------------------------------------------------------
-- M: the minimap
-- ---------------------------------------------------------------------------
local party = {}
local party_changed = {}
grug_parties = {view = function(player)
	if #party == 0 then return nil end
	local members = {{name = player:get_player_name()}}
	for _, name in ipairs(party) do members[#members + 1] = {name = name} end
	return {members = members}
end, register_on_change = function(fn) party_changed[#party_changed + 1] = fn end}
local home_id = "inn"
grug_home = {get = function() return home_id and {id = home_id, label = "Inn"} or nil end,
	locations = function() return {{id = "inn", label = "Inn", pos = {x = 80, y = 10, z = -210}},
		{id = "inn2", label = "Inn 2", pos = {x = 160, y = 10, z = -190}}} end,
	known_waypoints = function() return {} end,
	claim_waypoint = function() return nil end}
grug_jobs = {PROFESSIONS = {}}
grug_map = {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")}
local atlas = grug_map.atlas
grug_map.base = dofile(repo .. "/mods/PLAYER/grug_map/base.lua")
local installed = {quality = "normal", width = 1080, height = 960,
	tiles = grug_map.base.tiles(1080, 960)}
installed.texture = grug_map.base.combined_texture(1080, 960, installed.tiles)
installed.minimap = installed -- normal quality: the minimap shows the base itself
atlas.set_base_texture(installed.texture)
grug_map.location = {text_of = function() return "Dawnmere Fields" end}
local steps_before = #registered.register_globalstep
dofile(repo .. "/mods/PLAYER/grug_map/minimap.lua")
local minimap = grug_map.minimap
minimap.install(installed)
local minimap_step = registered.register_globalstep[steps_before + 1]
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
each("register_on_mods_loaded")
local collected = 0
do
	local real = atlas.collect_markers
	atlas.collect_markers = function(...)
		collected = collected + 1
		return real(...)
	end
end
local V = minimap.view
local view = minimap.geometry()
local function corner(player)
	local frame = V.frame(view, grug_core.hud_layout.minimap_box(windows[player.name]))
	local cx, cy = V.cell(view, player.pos.x, player.pos.z)
	local px, py = V.base_pixel(view, player.pos.x, player.pos.z)
	return V.map_corner(view, frame, cx, cy, px, py)
end
local walker = new_player("walker", {x = 100, y = 10, z = -220})
local mate = new_player("mate", {x = 110, y = 10, z = -228})
join(walker)
join(mate)
party = {"mate"}
for _, fn in ipairs(party_changed) do fn("walker") end
local function stats() return minimap.stats.drawn, minimap.stats.party end
local function step(n)
	for _ = 1, n or 1 do us = us + 90000; minimap_step(0.09) end
end
-- After a step, a full redraw would change nothing: the markers' signal
-- makes the next update ask the providers again and place everything.
local function exact(label)
	local before, drawn = hud_changes, minimap.stats.drawn
	Q.markers_changed(walker)
	minimap.refresh(walker)
	check(minimap.stats.drawn == drawn + 1, "M (the redraw placed everything): " .. label)
	eq(hud_changes - before, 0, "M a full redraw would send nothing: " .. label)
end
step(12) -- settle: window, markers, party
do
	local drawn, partied = stats()
	local changes = hud_changes
	step(40)
	local d2, p2 = stats()
	eq(d2 - drawn, 0, "M still: the map is not placed again")
	-- the mate's own minimap draws its party too (walker is its member)
	eq(p2 - partied, 0, "M still: no party arrows placed again")
	eq(hud_changes - changes, 0, "M still: nothing sent")
	exact("still")
end
-- moves under and over the threshold, decided by the real geometry
do
	local moved, placed, tried = 0, 0, 0
	local wrong = 0
	for i = 1, 200 do
		local before = {corner(walker)}
		-- a slow walk east with a wobble (0.13-0.21 nodes per step)
		local dx = 0.13 + (i % 5) * 0.02
		local dz = (i % 3 - 1) * 0.07
		walker.pos.x, walker.pos.z = walker.pos.x + dx, walker.pos.z + dz
		local after = {corner(walker)}
		local expect = before[1] ~= after[1] or before[2] ~= after[2]
		local drawn = minimap.stats.drawn
		step(1)
		local did = minimap.stats.drawn > drawn
		tried = tried + 1
		if expect then moved = moved + 1 end
		if did then placed = placed + 1 end
		-- a cell change also draws (its corner moves by whole cells anyway)
		if did ~= expect then wrong = wrong + 1 end
	end
	eq(wrong, 0, ("M small moves: placed exactly when the corner moved (%d of %d moved)"):format(moved, tried))
	check(moved > 10 and moved < tried, ("M the walk mixes moves under and over the threshold (%d of %d)"):format(moved, tried))
	exact("after small moves")
	local drawn = minimap.stats.drawn
	walker.pos.x = walker.pos.x + 7
	step(1)
	eq(minimap.stats.drawn - drawn, 1, "M a move of 7 nodes places the map once")
	exact("after a long move")
end
-- the party member moves and turns
do
	local drawn, partied = stats()
	mate.pos.z = mate.pos.z + 4
	step(1)
	local d2, p2 = stats()
	-- walker's minimap places the arrow; mate's own minimap moved its map
	check(p2 > partied, "M a member's move places the party arrows")
	exact("after a member moved")
	drawn, partied = stats()
	local frame_of = atlas.heading_frame
	local yaw = mate.yaw
	mate.yaw = yaw + 0.05
	check(frame_of(mate.yaw) == frame_of(yaw), "M (a turn inside one heading frame)")
	step(1)
	d2, p2 = stats()
	eq(p2 - partied, 0, "M a turn inside one heading frame places nothing")
	mate.yaw = yaw + math.pi / 2
	step(1)
	local d3, p3 = stats()
	eq(p3 - p2, 1, "M a turn to another frame places the party arrows once")
	eq(d3 - drawn, 0, "M ...and not the map")
	exact("after a turn")
	-- the member leaves the party
	party = {}
	for _, fn in ipairs(party_changed) do fn("walker") end
	step(1)
	exact("after the party changed")
	local slots = 0
	for _, hud in pairs(walker.huds) do
		if type(hud.text) == "string" and hud.text:find("_cyan_", 1, true) then slots = slots + 1 end
	end
	eq(slots, 0, "M a member who left has no arrow")
	party = {"mate"}
	for _, fn in ipairs(party_changed) do fn("walker") end
	step(1)
	exact("after the member came back")
end
-- a marker change, the window (zoom), the 5 s key
do
	local drawn = minimap.stats.drawn
	Q.markers_changed(walker)
	step(1)
	eq(minimap.stats.drawn - drawn, 1, "M a marker change places the map and markers")
	exact("after a marker change")
	drawn = minimap.stats.drawn
	windows.walker = {size = {x = 1280, y = 720}, real_hud_scaling = 1, real_gui_scaling = 1}
	step(6)
	eq(minimap.stats.drawn - drawn, 1, "M a window change places the map once (within 0.5 s)")
	exact("after a window change")
	-- the 5 s check: nothing changed, the providers are not asked
	collected = 0
	step(60)
	eq(collected, 0, "M the 5 s check with an unchanged key asks no provider")
	home_id = "inn2"
	step(60)
	eq(collected, 2, "M a new home is seen at the next 5 s check (both players)")
	exact("after a new home")
	collected = 0
	step(60)
	eq(collected, 0, "M ...and then the key holds again")
end

-- D (discovery) was retired in Round 45: every area shows all its recipes,
-- so no inventory scan remains (round45-plan.md §4.2).

-- ---------------------------------------------------------------------------
-- C: Claim Stone placement (the pure registry)
-- ---------------------------------------------------------------------------
do
	local store = {}
	local storage = {get_string = function(k) return store[k] or "" end,
		set_string = function(k, v) store[k] = v ~= "" and v or nil end,
		keys = function() local r = {} for k in pairs(store) do r[#r + 1] = k end return r end}
	local M = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({storage = storage,
		now = function() return 1000 end})
	local ZONE = {faction = "accord", territory_rule = "accord_home", level_min = 11, level_max = 20}
	local LOW = {faction = "accord", territory_rule = "accord_home", level_min = 1, level_max = 10}
	-- rules per test: `low` a column x >= low_from is a level 1-10 zone,
	-- `feature` the square meets a site, `cube` the cube is blocked
	local rule = {}
	local zone_calls = 0
	local function make_world(fixed)
		return {fixed = fixed,
			water_class_at = function() return "land" end,
			zone_at = function(x)
				zone_calls = zone_calls + 1
				if rule.low_from and x >= rule.low_from then return LOW end
				return ZONE
			end,
			territory_at = function() return "accord_home" end,
			feature_in = function() return rule.feature end,
			cube_clear = function() return not rule.cube end}
	end
	local fixed, loose = make_world(true), make_world(false)
	local ORDER = {"too_deep", "no_faction", "already_placed", "overlap", "site", "low_level", "cube"}
	-- every combination of the failing rules shows the first in ORDER
	local wrong, combos = 0, 0
	for mask = 0, 127 do
		local fails = {}
		for i, code in ipairs(ORDER) do fails[code] = math.floor(mask / 2 ^ (i - 1)) % 2 == 1 end
		-- a fresh registry for the one-claim and overlap rules
		for k in pairs(store) do store[k] = nil end
		local R = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({storage = storage,
			now = function() return 1000 end})
		local x = 1000 + mask * 300 -- a new column each time
		if fails.already_placed then R.create("ann", {x = x + 50000, y = 10, z = 0}) end
		if fails.overlap then R.create("other", {x = x + 60, y = 10, z = 0}) end
		rule = {feature = fails.site and "site" or nil, cube = fails.cube,
			low_from = fails.low_level and x or nil}
		local ok, code = R.validate("ann", fails.no_faction and "none" or "accord",
			{x = x, y = fails.too_deep and -200 or 10, z = 0}, fixed)
		local expect = "ok"
		for _, c in ipairs(ORDER) do if fails[c] then expect = c; break end end
		combos = combos + 1
		if (ok and "ok" or code) ~= expect then wrong = wrong + 1 end
	end
	eq(wrong, 0, ("C every combination of failing rules shows the first in the old order (%d combinations)"):format(combos))
	rule = {cube = true}
	zone_calls = 0
	local ok, code = M.validate("ann", "accord", {x = 300, y = 10, z = 0}, fixed)
	check(not ok and code == "cube", "C a passing scan with a blocked cube: the cube refusal")
	eq(zone_calls, M.SAMPLE_COUNT, "C the first check scans every column (10,201)")
	eq(M.SAMPLE_COUNT, 10201, "C (101 x 101 columns)")
	zone_calls = 0
	for _ = 1, 4 do M.validate("ann", "accord", {x = 300, y = 10, z = 0}, fixed) end
	eq(zone_calls, 0, "C a held click on the same spot scans no more")
	M.validate("ann", "accord", {x = 300, y = 14, z = 0}, fixed)
	eq(zone_calls, 0, "C another height on the same column shares the scan")
	rule = {}
	ok = M.validate("ann", "accord", {x = 300, y = 10, z = 0}, fixed)
	check(ok == true and zone_calls == 0, "C the cube cleared: accepted from the kept scan")
	M.validate("ann", "accord", {x = 301, y = 10, z = 0}, fixed)
	eq(zone_calls, M.SAMPLE_COUNT, "C a new column scans again")
	M.validate("ann", "throng", {x = 300, y = 10, z = 0}, fixed)
	check(zone_calls > M.SAMPLE_COUNT, "C another faction scans again")
	zone_calls = 0
	for _ = 1, 3 do M.validate("ann", "accord", {x = 300, y = 10, z = 0}, loose) end
	eq(zone_calls, 3 * M.SAMPLE_COUNT, "C a world that is not fixed scans every time")
	-- bounded: SCAN_CACHE + 1 new columns push the first one out
	for i = 1, M.SCAN_CACHE + 1 do M.validate("ann", "accord", {x = 5000 + i, y = 10, z = 0}, fixed) end
	zone_calls = 0
	M.validate("ann", "accord", {x = 5001, y = 10, z = 0}, fixed)
	eq(zone_calls, M.SAMPLE_COUNT, "C the cache stays bounded (an old column is scanned again)")
	-- a refusal from the scan is kept too
	rule = {low_from = 7000}
	zone_calls = 0
	local _, first = M.validate("ann", "accord", {x = 7000, y = 10, z = 0}, fixed)
	local calls = zone_calls
	local _, again = M.validate("ann", "accord", {x = 7000, y = 10, z = 0}, fixed)
	check(first == "low_level" and again == "low_level" and zone_calls == calls,
		"C a scan refusal is kept and shown again")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	print(("R37 PO PORTABLE FAIL checks=%d failures=%d"):format(checks, #failures))
	os.exit(1)
end
print(("R37 PO PORTABLE PASS checks=%d"):format(checks))
