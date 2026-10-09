-- Round 30 Lane P1 portable test (LuaJIT): quest state cache and map UI
-- (round30-plan.md, perf review #1, #3, #5, #10, #12).
--
--   luajit tools/r30_p1/portable_test.lua [repo]
--
-- Loads the REAL grug_quests registry, state, labels, npc and hud files, the
-- REAL grug_core hud_layout and item_names, and the REAL grug_map atlas,
-- base, minimap_view, minimap and providers on a fake engine.
-- Checks:
--   C  the decoded-state cache: every read path shares one decoded table per
--      raw meta string (no deserialization while it is unchanged); accept,
--      kill credit, a quest drop, turn-in, a repeatable's cooldown, abandon,
--      tracking and the HUD switch each refresh it; leave clears it and a
--      rejoin decodes once. After EVERY operation no cached table has
--      changed (deep comparison with a copy taken when it entered the
--      cache) and every cache entry equals a fresh decode of its raw string;
--   M  Q.marker_states: one table for all NPCs, equal to the most urgent
--      row of Q.npc_quests for each; memoized (same table, same version, no
--      holdings scan) until a state change, a quest change callback, the
--      tracker's held-item signal, a level change or a cooldown's end
--      (Round 37: no longer for a second only); the version rises only when
--      a marker differs;
--   T  NPC tag callback: a parent that is no quest NPC allocates nothing
--      and asks nothing; a quest NPC asks marker_states once per observer;
--   H  tracker HUD: the journal is built only when Q.journal_key changes
--      (not for an unchanged state or a non-objective item; yes for an
--      objective item, which also posts the feed line); players are spread
--      over five 0.1 s slots and each is polled once per 0.5 s;
--   I  markers without a quest change (Round 30 lane P1b): picking up the
--      last objective item shows the ready marker after the next HUD slot
--      and dropping it takes it back; a level-up
--      unlocks at once; a quiet HUD poll or a non-objective item keeps the
--      memo (no deserialization, no inventory scan beyond the poll's own);
--      both tell the minimap to ask its static markers again;
--   P  (the Map tab's 2 s poll; gone in Round 44: the map window's refresh
--      rule is checked by tools/r44_mq, section R);
--   W  minimap: the window information and the location line are read every
--      0.5 s, not every step; held objective items and a level-up re-ask
--      its static markers on the next step.
-- Prints "R30 P1 PORTABLE PASS checks=<n>" or the failures.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
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
local function deep_equal(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if not deep_equal(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
table.copy = function(value) return deep_copy(value) end
function table.indexof(list, value)
	for i, v in ipairs(list) do if v == value then return i end end
	return -1
end

-- A round-trippable serializer with sorted keys (core.serialize's role).
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
local deserializations = 0
local function deserialize(text)
	deserializations = deserializations + 1
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
local window_reads = 0
local item_groups = {["default:tree"] = {log = 1}, ["default:pine_tree"] = {log = 1}}
core = {
	registered_items = {["grug_food:raw_meat"] = {description = "Raw Meat"},
		["default:tree"] = {description = "Tree"}, ["default:pine_tree"] = {description = "Pine Tree"},
		["default:dirt"] = {description = "Dirt"}, ["grug_mobs:tusk"] = {description = "Boar Tusk"}},
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
	get_player_window_information = function(name)
		window_reads = window_reads + 1
		return windows[name]
	end,
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
local function new_player(name, pos)
	local p = {name = name, pos = pos, yaw = 0, meta = {}, huds = {}, next_hud = 0,
		lists = {main = {}}, sends = 0}
	for i = 1, 16 do p.lists.main[i] = ItemStack("") end
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
				local out = {}
				for i, s in ipairs(lists[list] or {}) do out[i] = ItemStack(s) end
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
	function p:hud_add(def) self.next_hud = self.next_hud + 1; self.huds[self.next_hud] = deep_copy(def); return self.next_hud end
	function p:hud_change(id, stat, value) hud_changes = hud_changes + 1; self.huds[id][stat] = value end
	function p:hud_remove(id) self.huds[id] = nil end
	function p:hud_set_flags() end
	function p:set_minimap_modes() end
	function p:set_inventory_formspec(fs) self.form = fs; self.sends = self.sends + 1 end
	return p
end
local function join(p)
	players[p.name] = p
	windows[p.name] = windows[p.name] or {size = {x = 1920, y = 1080}, real_hud_scaling = 1,
		real_gui_scaling = 1}
	each("register_on_joinplayer", p)
end
local function leave(p)
	each("register_on_leaveplayer", p, false)
	players[p.name] = nil
end

-- ---------------------------------------------------------------------------
-- The game around the quest files
-- ---------------------------------------------------------------------------
local level, faction = 1, "accord"
local fed = {}
local visibility
local sockets = {
	{id = "a", role = "quest", pos = {x = 100, y = 10, z = -200}},
	{id = "b", role = "quest", pos = {x = 140, y = 10, z = -230}},
	{id = "c", role = "quest", pos = {x = 60, y = 10, z = -260}},
	{id = "d", role = "quest", pos = {x = 20, y = 10, z = -180}},
}
grug_core = {
	register_tag_visibility = function(fn) visibility = fn end,
	feed_item = function() end,
	feed = function(_, kind, text, key) fed[#fed + 1] = {kind = kind, text = text, key = key}; return true end,
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
	BOX_COLOR = "#00000040", -- ui.lua's (Round 45 playtest)
	UI = {width = 10.4, height = 11.1},
	-- Round 44: quest drops go through grug_inventory.give (main-only here).
	give = function(player, stack) return player:get_inventory():add_item("main", stack) end}
local faction_chosen = {}
grug_factions = {get_faction = function() return faction end, same_faction = function() return false end,
	register_on_faction_chosen = function(fn) faction_chosen[#faction_chosen + 1] = fn end,
	display_name = function(id) return "The " .. id end}
-- Round 31: which NPCs serve whom (the real rule on the fake faction table).
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")
grug_classes = {get_race = function() return "human" end}
local level_changes = {}
grug_xp = {get_level = function() return level end, add_xp = function() end,
	quest_reward = function() return 10 end,
	register_on_level_change = function(fn) level_changes[#level_changes + 1] = fn end}
-- grug_xp's level-up: the level rises, then the callbacks run.
local function level_up(player, new_level)
	local old = level
	level = new_level
	for _, fn in ipairs(level_changes) do fn(player, old, new_level) end
end
grug_money = {MAX = 1e9, get = function() return 0 end, add = function() end,
	format = function(c) return c .. "c" end,
	deposit_location = function() return "detached:grug_money_deposit_x", "deposit" end}
grug_mobs = {register_on_eligible_kill = function() end, register_participant_drop_hook = function() end,
	dragon_map_markers = function() return {} end}
grug_zones = {id_at = function() return "z" end, at = function() return nil end}
grug_quests = {}
for _, file in ipairs({"registry", "state", "labels", "npc", "hud"}) do
	dofile(repo .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
local Q = grug_quests

Q.register_npc("elder", {settlement = "s", socket = "a", title = "Elder Maren"})
Q.register_npc("hunter", {settlement = "s", socket = "b", title = "Hunter Brosk"})
Q.register_npc("envoy", {settlement = "s", socket = "c", title = "Envoy Lysa"})
Q.register_npc("smith", {settlement = "s", socket = "d", title = "Smith Orrin"})
local function quest(id, def)
	def.title, def.description = def.title or id, def.description or "Text of " .. id
	def.rewards = def.rewards or {weight = 1, copper = 5}
	Q.register_quest(id, def)
end
quest("intro", {npc = "elder", objectives = {{type = "item", item = "grug_food:raw_meat", count = 2}}})
quest("next", {npc = "elder", turnin_npc = "hunter", prerequisites = {"intro"},
	objectives = {{type = "kill", mobs = {"grug_mobs:boar"}, names = {{"Boar"}}, name_set = {Boar = true}, count = 2}}})
quest("logs", {npc = "hunter", objectives = {{type = "item", group = "log", count = 3}}})
quest("bounty", {npc = "hunter", repeatable = {cooldown = 60},
	objectives = {{type = "kill", mobs = {"grug_mobs:boar"}, names = {{"Boar"}}, name_set = {Boar = true}, count = 1}}})
quest("tusk", {npc = "envoy", objectives = {{type = "item", item = "grug_mobs:tusk", count = 1}},
	quest_drops = {{item = "grug_mobs:tusk", mobs = {"grug_mobs:boar"}, names = {{"Boar"}}, name_set = {Boar = true}, chance = 1}}})
quest("veteran", {npc = "envoy", min_level = 5, objectives = {{type = "kill", mobs = {"grug_mobs:boar"}, names = {{"Boar"}}, name_set = {Boar = true}, count = 1}}})
local clock = 1000
Q.clock = function() return clock end

-- ---------------------------------------------------------------------------
-- C: the cache never changes under its readers
-- ---------------------------------------------------------------------------
local cache = Q._state_cache
check(type(cache) == "table", "C the cache is visible to fixtures")
local watched = {}
local function watch()
	for _, entry in pairs(cache) do
		if not watched[entry.state] then watched[entry.state] = deep_copy(entry.state) end
	end
end
-- Whether every watched table is unchanged and every entry equals a fresh
-- decode of its raw string.
local function audit()
	local intact, consistent = true, true
	for table_, copy in pairs(watched) do
		if not deep_equal(table_, copy) then intact = false end
	end
	for _, entry in pairs(cache) do
		local decoded = entry.raw ~= "" and assert(loadstring("return " .. entry.raw))() or
			{active = {}, completed = {}, tracked = {}, hud = true}
		decoded.cooldowns = decoded.cooldowns or {}
		if not deep_equal(entry.state, decoded) then consistent = false end
	end
	return intact, consistent
end
local function verify(label)
	local intact, consistent = audit()
	check(intact, "C no cached table changed: " .. label)
	check(consistent, "C the cache equals its raw strings: " .. label)
	watch()
end
local function op(label, fn, ...)
	watch()
	local a, b, c = fn(...)
	verify(label)
	return a, b, c
end

local ann = new_player("ann", {x = 100, y = 10, z = -205})
join(ann)
verify("join")

local priority = {ready = 1, available = 2, active = 3, locked = 4}
local function best_row(player, npc)
	local best
	for _, row in ipairs(Q.npc_quests(player, npc)) do
		if not best or priority[row.status] < priority[best] then best = row.status end
	end
	return best
end
-- marker_states equals the most urgent npc_quests row for every NPC.
local function markers_agree(label)
	us = us + 1100000 -- the memo outlives a second (Round 37)
	local states = op("marker_states " .. label, Q.marker_states, ann)
	local agree = true
	for _, npc in ipairs({"elder", "hunter", "envoy", "smith"}) do
		if states[npc] ~= best_row(ann, npc) then agree = false end
	end
	check(agree, "M marker_states equals the npc_quests rows: " .. label)
	return states
end

local states = markers_agree("fresh")
eq(states.elder, "available", "M fresh: elder offers the intro")
eq(states.hunter, "available", "M fresh: hunter offers logs and the bounty")
eq(states.envoy, "available", "M fresh: envoy offers the tusk quest")
eq(states.smith, nil, "M an NPC without quests has no marker")

-- Unchanged raw string: no deserialization on any read path.
do
	op("prime", Q.journal, ann)
	local before = deserializations
	for _ = 1, 20 do
		op("npc_quests", Q.npc_quests, ann, "elder")
		op("status", Q.status, ann, "intro")
		op("journal", Q.journal, ann)
		op("journal_key", Q.journal_key, ann)
		us = us + 1100000
		op("marker_states", Q.marker_states, ann)
	end
	eq(deserializations - before, 0, "C no deserialization while the state is unchanged")
end

-- accept, progress, turn-in, kill credit, drops, cooldown, abandon, tracking.
check(op("accept intro", Q.accept, ann, "intro"), "C accept intro")
eq(Q.status(ann, "intro"), "active", "C status follows the accept at once")
eq(Q.marker_states(ann).elder, "active", "M accept shows at once (state changed)")
states = markers_agree("after accept")
ann:give("grug_food:raw_meat 2")
eq(Q.marker_states(ann).elder, "active", "M an inventory change waits for the memo")
us = us + 1100000
eq(Q.marker_states(ann).elder, "active", "M ...also after a second (Round 37)")
-- the tracker's next poll (hud.lua, five 0.1 s slots) sees the held item
for _ = 1, 5 do registered.register_globalstep[1](0.1) end
eq(Q.marker_states(ann).elder, "ready", "M ...and shows after the tracker's poll")
check(op("turn in intro", Q.turn_in, ann, "intro"), "C turn in intro")
eq(Q.status(ann, "intro"), "completed", "C completed after the turn-in")
states = markers_agree("after turn-in")
eq(states.elder, "available", "M the follow-up quest unlocks at the elder")
check(op("accept next", Q.accept, ann, "next"), "C accept next")
local boar = {name = "grug_mobs:boar", description = "Boar", object = {}}
op("kill credit", Q.credit_kill, ann, boar, {x = 0, y = 0, z = 0})
local function row_of(id)
	for _, row in ipairs(Q.journal(ann).quests) do if row.id == id then return row end end
end
eq(row_of("next").objectives[1].count, 1, "C a kill credit shows in the journal")
op("kill credit 2", Q.credit_kill, ann, boar, {x = 0, y = 0, z = 0})
eq(Q.marker_states(ann).hunter, "ready", "M the second kill readies the turn-in at once")
do
	local raw = ann.meta["grug_quests:state"]
	op("kill credit at the cap", Q.credit_kill, ann, boar, {x = 0, y = 0, z = 0})
	eq(ann.meta["grug_quests:state"], raw, "C a kill that changes no counter saves nothing")
	local wolf = {name = "grug_mobs:wolf", description = "Wolf", object = {}}
	op("kill credit no match", Q.credit_kill, ann, wolf, {x = 0, y = 0, z = 0})
	eq(ann.meta["grug_quests:state"], raw, "C a kill matching nothing saves nothing")
end
check(op("turn in next", Q.turn_in, ann, "next"), "C turn in next")
markers_agree("after next")
check(op("accept tusk", Q.accept, ann, "tusk"), "C accept tusk")
do
	us = us + 1100000
	local _, version = Q.marker_states(ann)
	local again, same = Q.marker_states(ann)
	eq(same, version, "M within the memo the version holds")
	check(again == Q.marker_states(ann), "M within the memo the same table comes back")
	op("quest drop", Q.roll_quest_drops, boar, {"ann"}, {x = 0, y = 0, z = 0})
	eq(Q.marker_states(ann).envoy, "ready", "M a quest drop (changed callback) shows at once")
	local _, after = Q.marker_states(ann)
	check(after > version, "M the version rose with the change")
	Q.markers_changed(ann)
	local _, later = Q.marker_states(ann)
	eq(later, after, "M a recompute without a change keeps the version")
end
check(op("turn in tusk", Q.turn_in, ann, "tusk"), "C turn in tusk")
check(op("accept bounty", Q.accept, ann, "bounty"), "C accept bounty")
op("bounty kill", Q.credit_kill, ann, boar, {x = 0, y = 0, z = 0})
check(op("turn in bounty", Q.turn_in, ann, "bounty"), "C turn in bounty")
states = markers_agree("bounty cooling down")
local cooling = false
for _, row in ipairs(Q.npc_quests(ann, "hunter")) do
	if row.id == "bounty" then cooling = row.status == "locked" and row.reason:find("Repeatable again") ~= nil end
end
check(cooling, "C the bounty cools down after its turn-in")
clock = clock + 61
markers_agree("bounty ready again")
check(op("accept logs", Q.accept, ann, "logs"), "C accept logs")
check(op("untrack logs", Q.set_tracked, ann, "logs", false), "C untrack")
eq(#Q.journal(ann).tracked, 0, "C untracked in the journal")
check(op("track logs", Q.set_tracked, ann, "logs", true), "C track")
op("hud off", Q.set_hud_enabled, ann, false)
eq(Q.journal(ann).hud_enabled, false, "C the HUD switch shows")
op("hud on", Q.set_hud_enabled, ann, true)
do
	local journal = Q.journal(ann)
	journal.tracked[1] = "tampered"
	journal.quests[1].objectives[1].count = 99
	verify("a caller writing into its journal")
	eq(Q.journal(ann).tracked[1], "logs", "C a journal is the caller's own copy")
end
check(op("abandon logs", Q.abandon, ann, "logs"), "C abandon")
eq(Q.status(ann, "logs"), "available", "C available again after abandoning")
markers_agree("after abandon")
level_up(ann, 5)
markers_agree("level 5")
eq(Q.marker_states(ann).envoy, "available", "M a level-up unlocks at once")
level_up(ann, 1)

-- The audit itself notices a write into a cached table.
do
	local state = cache.ann.state
	state.active.tampered = {}
	local intact, consistent = audit()
	check(not intact and not consistent, "C the audit catches a write into a cached table")
	state.active.tampered = nil
end

-- leave and join
do
	leave(ann)
	eq(cache.ann, nil, "C leave clears the cache")
	local before = deserializations
	join(ann)
	for _ = 1, 5 do Q.journal(ann); Q.npc_quests(ann, "hunter") end
	eq(deserializations - before, 1, "C a rejoin decodes once")
	verify("rejoin")
	eq(Q.status(ann, "intro"), "completed", "C the state survives leave and join")
end

-- ---------------------------------------------------------------------------
-- T: the NPC tag callback
-- ---------------------------------------------------------------------------
do
	check(type(visibility) == "function", "T tag visibility callback registered")
	local asked = 0
	local real = Q.marker_states
	Q.marker_states = function(player)
		asked = asked + 1
		return real(player)
	end
	local mob = {object = {is_valid = function() return true end}}
	local parent = {get_luaentity = function() return mob end, get_pos = function() return {x = 0, y = 0, z = 0} end}
	local observers = {ann = true}
	visibility(parent, observers, false) -- warm
	-- Interpreted, so trace recording does not count as an allocation.
	if jit then jit.off() end
	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	for _ = 1, 2000 do visibility(parent, observers, false) end
	local grown = collectgarbage("count") - before
	collectgarbage("restart")
	if jit then jit.on() end
	check(grown == 0, ("T a mob parent allocates nothing (%.2f KB for 2000 calls)"):format(grown))
	-- control: the same measurement sees one small table per call
	if jit then jit.off() end
	collectgarbage("collect")
	collectgarbage("stop")
	before = collectgarbage("count")
	local sink
	for _ = 1, 2000 do sink = {} end
	local control = collectgarbage("count") - before
	collectgarbage("restart")
	if jit then jit.on() end
	check(sink and control > 10, ("T the allocation measurement works (%.1f KB control)"):format(control))
	eq(asked, 0, "T a mob parent asks no marker state")
	local children = {}
	core.add_entity = function()
		local child = {observers = nil, valid = true}
		function child:is_valid() return self.valid end
		function child:set_attach() end
		function child:set_properties(p) self.props = p end
		function child:set_observers(o) self.observers = o end
		function child:remove() self.valid = false end
		children[#children + 1] = child
		return child
	end
	local npc = {_grug_start = "s", _grug_socket = "b", object = mob.object}
	local npc_parent = {get_luaentity = function() return npc end, get_pos = function() return {x = 0, y = 0, z = 0} end}
	local bob = new_player("bob", {x = 0, y = 10, z = 0})
	join(bob)
	visibility(npc_parent, {ann = true, bob = true}, false)
	eq(asked, 2, "T a quest NPC asks marker_states once per observer")
	local shown = {}
	for _, child in ipairs(children) do
		for name in pairs(child.observers or {}) do shown[name] = (shown[name] or 0) + 1 end
	end
	check(shown.ann == 1 and shown.bob == 1, "T each observer sees exactly one marker")
	visibility(npc_parent, {}, true)
	local removed = true
	for _, child in ipairs(children) do removed = removed and not child.valid end
	check(removed, "T removing the parent removes its markers")
	Q.marker_states = real
	leave(bob)
end

-- ---------------------------------------------------------------------------
-- H: tracker HUD
-- ---------------------------------------------------------------------------
local journals = 0
do
	local real = Q.journal
	Q.journal = function(...)
		journals = journals + 1
		return real(...)
	end
end
local hud_step = registered.register_globalstep[1]
local function hud_steps(seconds)
	for _ = 1, math.floor(seconds / 0.1 + 0.5) do hud_step(0.1) end
end
do
	Q.accept(ann, "logs")
	hud_steps(0.5)
	journals = 0
	hud_steps(2.0)
	eq(journals, 0, "H an unchanged state and inventory build no journal")
	ann:give("default:dirt 5")
	hud_steps(0.5)
	eq(journals, 0, "H a non-objective item builds no journal")
	local raw, held = Q.journal_key(ann)
	ann:give("default:tree 1")
	local raw2, held2 = Q.journal_key(ann)
	check(raw == raw2 and held ~= held2, "H an objective item changes the key's item part")
	fed = {}
	hud_steps(0.5)
	eq(journals, 1, "H an objective item builds the journal once")
	check(fed[1] and fed[1].text:find("1/3", 1, true), "H ...and posts the progress line")
	ann:give("default:pine_tree 1")
	hud_steps(0.5)
	eq(journals, 2, "H a second group member counts too")
	-- several players: five slots, each polled once per 0.5 s
	local polled, real_key = {}, Q.journal_key
	Q.journal_key = function(player)
		polled[player:get_player_name()] = (polled[player:get_player_name()] or 0) + 1
		return real_key(player)
	end
	local crowd = {}
	for i = 1, 10 do crowd[i] = new_player(("p%02d"):format(i), {x = i, y = 10, z = 0}); join(crowd[i]) end
	polled = {}
	local most = 0
	for _ = 1, 5 do
		local before = 0
		for _, n in pairs(polled) do before = before + n end
		hud_step(0.1)
		local after = 0
		for _, n in pairs(polled) do after = after + n end
		most = math.max(most, after - before)
	end
	local once = true
	for _, p in pairs(players) do once = once and polled[p.name] == 1 end
	check(once, "H every player is polled once per 0.5 s")
	check(most <= 3, "H at most a fifth of the players (rounded up) per step (" .. most .. ")")
	Q.journal_key = real_key
	for _, p in ipairs(crowd) do leave(p) end
end

-- ---------------------------------------------------------------------------
-- I: markers follow held items and the level without a quest change
-- ---------------------------------------------------------------------------
do
	-- ann: logs active with 2 of 3 logs; the bounty is available again.
	local scans, real_inventory = 0, ann.get_inventory
	function ann:get_inventory()
		local inv = real_inventory(self)
		local get_list = inv.get_list
		inv.get_list = function(...) scans = scans + 1; return get_list(...) end
		return inv
	end
	us = us + 1100000
	hud_steps(0.5)
	local states, version = Q.marker_states(ann)
	eq(states.hunter, "available", "I two of three logs: the hunter offers the bounty")
	eq(states.envoy, "locked", "I level 1: the envoy's veteran quest is locked")
	-- quiet HUD polls and a non-objective item keep the memo
	local decoded, polled = deserializations, scans
	hud_steps(2.0)
	eq(scans - polled, 4, "I a quiet HUD poll scans the inventory once (its own key)")
	ann:give("default:dirt 3")
	hud_steps(0.5)
	polled = scans
	local again, same = Q.marker_states(ann)
	check(again == states and same == version and scans == polled,
		"I quiet polls and a non-objective item keep the memo (no marker scan)")
	eq(deserializations - decoded, 0, "I quiet polls and markers decode nothing")
	-- the last log: ready after the next HUD slot, inside the memo's second
	ann:give("default:tree 1")
	eq(Q.marker_states(ann).hunter, "available", "I before the HUD slot the memo holds")
	hud_steps(0.5)
	local ready, risen = Q.marker_states(ann)
	eq(ready.hunter, "ready", "I the last objective item shows ready after the next HUD slot")
	check(risen > version, "I ...and the marker version rose")
	eq(deserializations - decoded, 0, "I the item change decodes nothing")
	-- dropped again: back to available on the next slot
	for i, stack in ipairs(ann.lists.main) do
		if stack:get_name() == "default:tree" then ann.lists.main[i] = ItemStack("") end
	end
	hud_steps(0.5)
	eq(Q.marker_states(ann).hunter, "available", "I a dropped objective item takes the ready back")
	-- a level-up unlocks at once
	level_up(ann, 5)
	eq(Q.marker_states(ann).envoy, "available", "I a level-up unlocks the envoy's quest at once")
	level_up(ann, 1)
	eq(Q.marker_states(ann).envoy, "locked", "I ...and a level-down locks it again")
	ann.get_inventory = real_inventory
end

-- ---------------------------------------------------------------------------
-- The map stubs (the minimap below)
-- ---------------------------------------------------------------------------
local party = {}
grug_parties = {view = function(player)
	if #party == 0 then return nil end
	local members = {{name = player:get_player_name()}}
	for _, name in ipairs(party) do members[#members + 1] = {name = name} end
	return {members = members}
end, register_on_change = function() end}
local home_left, home_pending, has_home, home_returns = 0, false, true, 0
grug_home = {get = function() return has_home and {id = "inn", label = "Inn"} or nil end,
	locations = function() return {{id = "inn", label = "Inn", pos = {x = 80, y = 10, z = -210}}} end,
	remaining = function() return home_left end, is_pending = function() return home_pending end,
	return_home = function() home_returns = home_returns + 1; home_pending = true; return true end,
	known_waypoints = function() return {} end}
grug_jobs = {PROFESSIONS = {}}
local inventory_sets = 0
local page
local pages = {}
sfinv = {contexts = {}, pages = pages, pages_unordered = {},
	register_page = function(name, def)
		def.name = name
		pages[name] = def
		sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def
		if name == "grug_map:atlas" then page = def end
	end,
	make_formspec = function(_, _, content) return content end,
	set_page = function() end, inventory_suspended = function() return false end}
function sfinv.set_player_inventory_formspec(player, context)
	inventory_sets = inventory_sets + 1
	local def = pages[context.page or "grug_map:atlas"]
	player:set_inventory_formspec(def.get(def, player, context))
end
grug_map = {atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")}
local atlas = grug_map.atlas
grug_map.base = dofile(repo .. "/mods/PLAYER/grug_map/base.lua")
local installed = {quality = "normal", width = 1080, height = 960,
	tiles = grug_map.base.tiles(1080, 960)}
installed.texture = grug_map.base.combined_texture(1080, 960, installed.tiles)
installed.minimap = installed -- normal quality: the minimap shows the base itself
atlas.set_base_texture(installed.texture)
local location_reads = 0
-- Round 32: the line's colour follows the territory status (nil: neutral).
local location_color = nil
grug_map.location = {text_of = function()
	location_reads = location_reads + 1
	return "Dawnmere Fields", location_color
end}
local steps_before = #registered.register_globalstep
dofile(repo .. "/mods/PLAYER/grug_map/minimap.lua")
grug_map.minimap.install(installed)
local minimap_step = registered.register_globalstep[steps_before + 1]
dofile(repo .. "/mods/PLAYER/grug_map/providers.lua")
each("register_on_mods_loaded")

-- The two players the minimap checks (W) walk with. The Map tab's 2 s poll
-- (Round 30 ruling, perf review #3) is gone since Round 44: the map window
-- refreshes on events only (tools/r44_mq, section R).
local walker = new_player("walker", {x = 100, y = 10, z = -220})
join(walker)
local mate = new_player("mate", {x = 120, y = 10, z = -240})
join(mate)
party = {"mate"}
-- An item objective for W's held-item signal (it was taken in the old P).
check(Q.accept(walker, "intro"), "W the walker accepts the intro")

-- ---------------------------------------------------------------------------
-- K: Return home on the Character page (Round 30 ruling)
-- ---------------------------------------------------------------------------
do
	grug_inventory.equipment_slots = {}
	grug_inventory.has_quiver = function() return false end
	-- Round 44: the gear box (Return home at its foot) in every mode.
	grug_inventory.BAG_COUNT = grug_inventory.BAG_COUNT or 0
	grug_inventory.SHIFT_LIST = "grug_shift"
	grug_inventory.wrap_text = grug_inventory.wrap_text or function(text) return text end
	grug_inventory.selected_button_style = function(field, selected)
		return "style[" .. field .. ";" .. tostring(selected) .. "]"
	end
	grug_core.status_effects = function() return {} end
	grug_classes.get_class_def = function() return {resource = "rage"} end
	grug_classes.get_pool_breakdown = function() return {final = 100} end
	grug_classes.get_crit_chance = function() return 0 end
	grug_classes.get_dodge_chance = function() return 0 end
	grug_classes.get_class = function() return "warrior" end
	grug_core.get_armor_rating = function() return 0 end
	grug_core.armor_reduction = function() return 0 end
	grug_core.get_player_level = function() return 1 end
	grug_core.register_on_equipment_change = function() end
	grug_core.register_on_status_modifiers_changed = function() end
	grug_xp.register_on_level_change = function() end
	grug_money.register_on_change = function() end
	local steps_before = #registered.register_globalstep
	dofile(repo .. "/mods/PLAYER/grug_inventory/pages.lua")
	local character_step = registered.register_globalstep[steps_before + 1]
	check(character_step ~= nil and #registered.register_globalstep == steps_before + 1,
		"K the Character page registers its one 1 s pass")
	local character = pages["grug_inventory:character"]
	local kay = new_player("kay", {x = 0, y = 10, z = 0})
	function kay:get_properties() return {visual = "mesh", mesh = "m.b3d", textures = {"t.png"}} end
	join(kay)
	local ctx = {page = "grug_inventory:character"}
	sfinv.contexts.kay = ctx
	home_left, home_pending, has_home = 0, false, true
	sfinv.set_player_inventory_formspec(kay, ctx)
	local button = "button[8.50,8.00;4.65,0.8;grug_character_home;"
	check(kay.form:find(button .. "Return home (Ready)]", 1, true) and
		kay.form:find("label[8.50,7.60;Home: Inn]", 1, true),
		"K the gear box shows Home: Inn and Return home (Ready)")
	local function second() character_step(1.0) end
	kay.sends = 0
	for _ = 1, 5 do second() end
	eq(kay.sends, 0, "K Ready: nothing re-sent")
	home_left = 90
	second()
	eq(kay.sends, 1, "K a cooldown starts: re-sent")
	check(kay.form:find(button .. "Return home (2 min)]", 1, true), "K ...in whole minutes")
	second()
	eq(kay.sends, 1, "K the same text is not re-sent")
	home_left = 89
	second()
	eq(kay.sends, 1, "K a new second in the same minute is not re-sent (Round 33)")
	home_left = 60
	second()
	eq(kay.sends, 2, "K a new minute is re-sent")
	check(kay.form:find("Return home (1 min)", 1, true), "K ...with the new value")
	character_step(0.5)
	home_left = 1
	character_step(0.4)
	eq(kay.sends, 2, "K at most once per second, and only on a new minute")
	home_left = 0
	second()
	eq(kay.sends, 3, "K once when it becomes Ready")
	check(kay.form:find("Return home (Ready)", 1, true), "K ...showing Ready")
	for _ = 1, 3 do second() end
	eq(kay.sends, 3, "K and then nothing")
	-- every mode shows the button (Round 44): the Effects mode is re-sent
	-- once for the new minute; another page is not re-sent
	ctx.grug_character_tab = "effects"
	sfinv.set_player_inventory_formspec(kay, ctx)
	kay.sends = 0
	home_left = 50
	for _ = 1, 3 do second(); home_left = home_left - 1 end
	eq(kay.sends, 1, "K the Effects mode is re-sent once for the countdown")
	ctx.grug_character_tab = nil
	ctx.page = "grug_inventory:inventory"
	for _ = 1, 3 do second(); home_left = home_left - 1 end
	eq(kay.sends, 1, "K another page is not re-sent")
	ctx.page = "grug_inventory:character"
	home_left = 0
	second()
	-- the click
	local sets = inventory_sets
	character:on_player_receive_fields(kay, ctx, {grug_character_home = "Return home"})
	eq(home_returns, 1, "K the button asks grug_home.return_home")
	eq(inventory_sets, sets + 1, "K ...and rebuilds the page at once")
	check(kay.form:find("Return home (Preparing arrival)", 1, true), "K Preparing arrival shows")
	home_pending = false
	-- no home, no button
	has_home = false
	sfinv.set_player_inventory_formspec(kay, ctx)
	check(not kay.form:find("grug_character_home", 1, true), "K without a home there is no button")
	kay.sends = 0
	for _ = 1, 3 do second() end
	eq(kay.sends, 0, "K without a home nothing is re-sent")
	has_home = true
	leave(kay)
end

-- ---------------------------------------------------------------------------
-- W: minimap window reads
-- ---------------------------------------------------------------------------
do
	minimap_step(0.09)
	window_reads, location_reads = 0, 0
	local steps = 0
	for _ = 1, 22 do
		walker.pos.z = walker.pos.z + 0.4
		minimap_step(0.09)
		steps = steps + 1
	end
	-- two minimap players (walker, mate; ann joined before the minimap was
	-- loaded) over 22 steps of 0.09 s: 3 or 4 reads each instead of 22
	check(window_reads <= 2 * 4 and window_reads >= 2 * 3,
		("W window read every 0.5 s: %d reads for 2 players over %d steps"):format(window_reads, steps))
	check(location_reads <= 2 * 4 and location_reads >= 2 * 3,
		("W location line read every 0.5 s: %d reads"):format(location_reads))
	-- the static markers: asked again on the next step after held objective
	-- items or the level changed (lane P1b), not in between
	local asked, real = {}, atlas.collect_markers
	atlas.collect_markers = function(player, only)
		if only then asked[player:get_player_name()] = (asked[player:get_player_name()] or 0) + 1 end
		return real(player, only)
	end
	minimap_step(0.09)
	asked = {}
	minimap_step(0.09)
	eq(asked.walker, nil, "W a quiet step asks no static markers")
	walker:give("grug_food:raw_meat 1")
	hud_steps(0.5)
	asked = {}
	minimap_step(0.09)
	eq(asked.walker, 1, "W an objective item re-asks the static markers on the next step")
	eq(asked.mate, nil, "W ...for that player only")
	asked = {}
	level_up(walker, 2)
	minimap_step(0.09)
	eq(asked.walker, 1, "W a level-up re-asks the static markers on the next step")
	level = 1
	-- Round 31 (ruling 13): a faction change (creation or admin) re-asks them.
	minimap_step(0.09)
	asked = {}
	faction = "throng"
	for _, fn in ipairs(faction_chosen) do fn(walker, "throng") end
	minimap_step(0.09)
	eq(asked.walker, 1, "W a faction change re-asks the static markers on the next step")
	eq(asked.mate, nil, "W ...for that player only")
	faction = "accord"
	atlas.collect_markers = real
	-- Round 32: the location line takes its status colour within 0.5 s and
	-- sends it only when it changes; no colour is the notice colour.
	local line
	for _, def in pairs(walker.huds) do
		if def.type == "text" and def.text == "Dawnmere Fields" then line = def end
	end
	check(line and line.number == 0xf0e6c8, "W the location line starts in the notice colour")
	location_color = 0xff5555
	for _ = 1, 6 do minimap_step(0.09) end
	eq(line and line.number, 0xff5555, "W the location line follows its status colour")
	local changes = hud_changes
	for _ = 1, 12 do minimap_step(0.09) end
	eq(hud_changes, changes, "W an unchanged colour sends nothing")
	location_color = nil
	for _ = 1, 6 do minimap_step(0.09) end
	eq(line and line.number, 0xf0e6c8, "W no status: back to the notice colour")
end

if #failures == 0 then
	print(("R30 P1 PORTABLE PASS checks=%d"):format(checks))
else
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R30 P1 PORTABLE FAIL %d/%d"):format(#failures, checks))
end
