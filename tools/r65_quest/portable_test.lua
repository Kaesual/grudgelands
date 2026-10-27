-- Round 65 lane QUEST portable test (LuaJIT): one acceptance rule, a giver
-- dialog without locked rows, the "soon" marker (round65-plan.md §2
-- rulings 1, 2, 3, 5; §6).
--
--   luajit tools/r65_quest/portable_test.lua [repo]
--
-- Loads the REAL grug_quests registry, state, labels, npc and validate files
-- and the REAL grug_core ui and ui_rows on a fake engine; the quests of the
-- Dawnmere elder are registered from the shipped quest file with their real
-- levels and prerequisites (simple objectives in place of the real ones).
-- Checks:
--   A  the acceptance level: max(1, level - 2) for 1, 2, 3, 4 and 60; the
--      Python rule (tools/r28_design/r28common.py, the ledger's) agrees for
--      every level 1..60; a registration naming min_level is refused; no
--      shipped quest file names min_level;
--   B  the Dawnmere elder at levels 1, 3 and 7: only acceptable, ready and
--      active rows, ordered ready, acceptable, in progress, then level and
--      title; the hint level (the lowest acceptance level held back by the
--      level only); the departure (its prerequisite unmet) in neither the
--      list nor the hint;
--   C  the dialog: the grey hint line below the list, no "Locked" anywhere;
--      a giver with only future quests opens with the hint, says when to
--      come back and offers no Accept; a giver with neither rows nor hint
--      does not open; the legend and tooltip drop "Locked";
--   D  the marker: the grey "!" ("locked") at next quest L+1 and L+2, none at
--      L+3; story_locked when that next quest is a story quest; anything
--      acceptable wins; a level-up moves it (memo refresh); a quest behind
--      an unmet prerequisite gives no marker;
--   E  validate.lua: a stale min_level is an [E-levels] error, its absence
--      none;
--   F  Help -> Quests names the silver "!" as a new quest in one or two levels.
-- Prints "R65 QUEST PORTABLE PASS checks=<n>" or the failures.
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil, label)
end
local function lacks(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) == nil, label)
end
local function read(path)
	local file = assert(io.open(repo .. "/" .. path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
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

local registered, players, shown = {}, {}, {}
core = {
	registered_items = {["default:dirt"] = {description = "Dirt"}},
	registered_entities = {["grug_mobs:boar"] = {description = "Boar"}},
	get_translated_string = function(_, text) return text end,
	get_item_group = function() return 0 end,
	serialize = serialize,
	deserialize = function(text)
		if text == "" then return nil end
		return assert(loadstring("return " .. text))()
	end,
	log = function() end,
	get_player_by_name = function(name) return players[name] end,
	get_player_window_information = function() return nil end,
	formspec_escape = function(text)
		return (text:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	colorize = function(color, text) return "(c@" .. color .. ")" .. text end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	show_formspec = function(name, formname, form) shown[name] = form end,
	close_formspec = function(name) shown[name] = "closed" end,
	chat_send_player = function() end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then
		return function(fn)
			registered[key] = registered[key] or {}
			registered[key][#registered[key] + 1] = fn
		end
	end
end})
vector = {distance = function() return 0 end}

local function new_player(name)
	local p = {name = name, meta = {}, lists = {main = {}}}
	for i = 1, 8 do p.lists.main[i] = ItemStack("") end
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
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
			get_stack = function(_, list, i) return ItemStack((lists[list] or {})[i]) end,
		}
	end
	players[name] = p
	return p
end

-- ---------------------------------------------------------------------------
-- The game around the files
-- ---------------------------------------------------------------------------
local levels, level_changes = {}, {}
grug_core = {register_tag_visibility = function() end, feed_item = function() end,
	feed = function() return true end, plain_text = function(text) return text end}
dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
dofile(repo .. "/mods/CORE/grug_core/ui_rows.lua")
grug_inventory = {BAG_COUNT = 0, HOTBAR_STORE = "hotbar_store"}
grug_factions = {serves = function() return true end, refuse = function() end,
	same_faction = function() return false end}
grug_xp = {get_level = function(p) return levels[p:get_player_name()] or 1 end,
	add_xp = function() end, quest_reward = function() return 10 end,
	register_on_level_change = function(fn) level_changes[#level_changes + 1] = fn end}
local function set_level(player, level)
	local old = levels[player:get_player_name()] or 1
	levels[player:get_player_name()] = level
	for _, fn in ipairs(level_changes) do fn(player, old, level) end
end
grug_money = {MAX = 1e9, get = function() return 0 end, add = function() end,
	format = function(c) return c .. "c" end}
grug_mobs = {register_on_eligible_kill = function() end, register_participant_drop_hook = function() end}
grug_zones = {id_at = function() return "z" end, get = function() return nil end}
grug_quests = {}
for _, file in ipairs({"registry", "state", "labels", "npc", "validate"}) do
	dofile(repo .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
local Q = grug_quests
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")

-- ---------------------------------------------------------------------------
-- A: the acceptance level
-- ---------------------------------------------------------------------------
eq(Q.acceptance_level(1), 1, "A level 1 is accepted from 1")
eq(Q.acceptance_level(2), 1, "A level 2 from 1 (never below 1)")
eq(Q.acceptance_level(3), 1, "A level 3 from 1")
eq(Q.acceptance_level(4), 2, "A level 4 from 2")
eq(Q.acceptance_level(60), 58, "A level 60 from 58")
do
	local command = ("cd '%s' && python3 -c \"import sys; sys.path.insert(0, 'tools/r28_design'); " ..
		"import r28common as C, ledger as L; " ..
		"print(' '.join('%%d:%%d' %% (C.acceptance_level(n), L.Ledger.acceptance({'level': n})) " ..
		"for n in range(1, 61)))\" 2>&1"):format(repo)
	local handle = io.popen(command)
	local out = handle:read("*a")
	handle:close()
	local lua, index = {}, 0
	for n = 1, 60 do lua[n] = Q.acceptance_level(n) .. ":" .. Q.acceptance_level(n) end
	local agree = true
	for pair in out:gmatch("%d+:%d+") do
		index = index + 1
		if pair ~= lua[index] then agree = false end
	end
	check(agree and index == 60, "A r28common.acceptance_level and the ledger agree with the game for 1..60 (" ..
		out:sub(1, 120) .. ")")
end
check(not pcall(Q.register_quest, "stale", {title = "Stale", description = "Text.", min_level = 3, level = 5,
	rewards = {weight = 1}}), "A a registration naming min_level is refused")
do
	local stale = {}
	local list = io.popen("ls '" .. repo .. "/mods/PLAYER/grug_quests/data/zones/'")
	for name in list:lines() do
		if name:match("%.json$") and read("mods/PLAYER/grug_quests/data/zones/" .. name):find('"min_level"', 1, true) then
			stale[#stale + 1] = name
		end
	end
	list:close()
	eq(table.concat(stale, ", "), "", "A no shipped quest file names min_level")
	lacks(read("mods/PLAYER/grug_mail/quest.lua"), "min_level", "A the mailbox quest names its level only")
end

-- ---------------------------------------------------------------------------
-- The Dawnmere elder's quests, from the shipped file
-- ---------------------------------------------------------------------------
local ELDER = "r14_human_elder"
local DAWNMERE = "elandor_dawnmere_fields.quests.json"
local dawnmere = json.decode(read("mods/PLAYER/grug_quests/data/zones/" .. DAWNMERE))
local sockets = {}
local function npc(id, title)
	sockets[id] = "s/" .. id
	Q.register_npc(id, {settlement = "s", socket = id, title = title})
end
npc(ELDER, "Elder")
local by_id, pending = {}, {}
local function gives(quest, giver)
	if quest.giver == giver then return true end
	for _, variant in ipairs(quest.variants or {}) do
		for _, name in ipairs(variant.givers or {}) do
			if name == giver then return true end
		end
	end
	return false
end
for _, quest in ipairs(dawnmere.quests) do
	if gives(quest, ELDER) then by_id[quest.id] = quest; pending[#pending + 1] = quest end
end
local function quest(id, def)
	def.title, def.description = def.title or id, def.description or "Text of " .. id
	def.rewards = def.rewards or {weight = 1, copper = 5}
	def.objectives = def.objectives or {{type = "kill", mobs = {"grug_mobs:boar"}, names = {{"Boar"}},
		name_set = {Boar = true}, count = 1}}
	Q.register_quest(id, def)
end
-- Prerequisites first (registry order).
while #pending > 0 do
	for i = #pending, 1, -1 do
		local row, ready = pending[i], true
		for _, prior in ipairs(row.requires or {}) do
			if not Q.registered_quests[prior] then ready = false end
		end
		if ready then
			quest(row.id, {npc = ELDER, title = row.title, level = row.level, story = row.story,
				prerequisites = row.requires,
				objectives = row.id == "start_stone" and {{type = "item", item = "default:dirt", count = 1}} or nil})
			table.remove(pending, i)
		end
	end
end
eq(Q.registered_quests.start_foxes.min_level, Q.acceptance_level(by_id.start_foxes.level),
	"A the registry derives the acceptance level from the quest level")

local function ids(rows)
	local out = {}
	for i, row in ipairs(rows) do out[i] = row.id .. "=" .. row.status end
	return table.concat(out, " ")
end
-- The expected rows: the elder's quests acceptable at `level` (prerequisites
-- met), by level then title.
local function expected(level)
	local rows, hint = {}, nil
	for id, row in pairs(by_id) do
		local open = #(row.requires or {}) == 0
		local accept = math.max(1, row.level - 2)
		if open and accept <= level then rows[#rows + 1] = row
		elseif open then hint = math.min(hint or accept, accept) end
	end
	table.sort(rows, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		return Q.registered_quests[a.id].title < Q.registered_quests[b.id].title
	end)
	local out = {}
	for i, row in ipairs(rows) do out[i] = row.id .. "=available" end
	return table.concat(out, " "), hint
end

-- ---------------------------------------------------------------------------
-- B: the Dawnmere elder at levels 1, 3 and 7
-- ---------------------------------------------------------------------------
local ann = new_player("ann")
for _, level in ipairs({1, 3, 7}) do
	set_level(ann, level)
	local rows, hint = Q.npc_quests(ann, ELDER)
	local want, want_hint = expected(level)
	eq(ids(rows), want, "B level " .. level .. ": only acceptable rows, by level then title")
	eq(hint, want_hint, "B level " .. level .. ": the hint level")
	for _, row in ipairs(rows) do
		check(row.status ~= "locked", "B level " .. level .. ": no locked row (" .. row.id .. ")")
		check(row.id ~= "dawnmere_departure", "B level " .. level .. ": the departure waits for its prerequisite")
	end
end
set_level(ann, 1)
local rows, hint = Q.npc_quests(ann, ELDER)
eq(#rows, 2, "B level 1: the start elder lists two quests")
eq(hint, 3, "B level 1: more quests at level 3")
set_level(ann, 7)
rows, hint = Q.npc_quests(ann, ELDER)
eq(hint, nil, "B level 7: every open quest is acceptable; the departure (behind dawnmere_hunt_05) gives no hint")
-- Status order: ready, acceptable, in progress (then level, title).
assert(Q.accept(ann, "start_boars", ELDER))
assert(Q.accept(ann, "start_stone", ELDER))
ann.lists.main[1] = ItemStack("default:dirt")
Q.markers_changed(ann)
rows = Q.npc_quests(ann, ELDER)
eq(rows[1].id .. "=" .. rows[1].status, "start_stone=ready", "B the ready quest comes first")
eq(rows[#rows].id .. "=" .. rows[#rows].status, "start_boars=active", "B the quest in progress comes last")
local order_ok = true
for i = 2, #rows - 1 do
	if rows[i].status ~= "available" then order_ok = false end
	if i > 2 and rows[i - 1].level > rows[i].level then order_ok = false end
end
check(order_ok, "B the acceptable quests sit between, by level: " .. ids(rows))
eq(Q.npc_preselect(rows), 1, "B the preselection is the first ready quest")

-- ---------------------------------------------------------------------------
-- C: the dialog
-- ---------------------------------------------------------------------------
local function entity(id)
	return {_grug_start = "s", _grug_socket = id, object = {is_valid = function() return true end,
		get_pos = function() return {x = 0, y = 0, z = 0} end}}
end
local bea = new_player("bea")
set_level(bea, 1)
check(Q.open_npc(bea, entity(ELDER)), "C the elder opens at level 1")
has(shown.bea, "More quests at level 3.", "C the hint line names level 3")
has(shown.bea, "(c@" .. grug_core.ui.colors.muted .. ")More quests at level 3.", "C ...in the muted grey")
lacks(shown.bea, "Locked", "C no row reads Locked")
lacks(shown.bea, "quests_row_3", "C two rows, the hint is no row")
has(shown.bea, "button[15.9,11.25;2.2,0.65;accept;Accept]", "C an acceptable quest is preselected")
lacks(Q.status_legend(), "Locked", "C the legend drops Locked")
lacks(Q.status_tooltip(), "Locked", "C the tooltip drops Locked")

-- A giver with only future quests, one with nothing.
npc("later", "Later Giver")
quest("later_one", {npc = "later", level = 9})
npc("done", "Done Giver")
quest("done_one", {npc = "done", level = 1})
check(Q.open_npc(bea, entity("later")), "C a giver with only future quests opens")
has(shown.bea, "More quests at level 7.", "C ...with the hint")
has(shown.bea, "Later Giver has more quests for you at level 7.", "C ...saying when to come back")
lacks(shown.bea, "accept;Accept", "C ...and no Accept")
lacks(shown.bea, "quests_row_1", "C ...and no row")
assert(Q.accept(bea, "done_one", "done"))
local state = core.deserialize(bea.meta["grug_quests:state"])
state.active.done_one, state.completed.done_one = nil, true
bea.meta["grug_quests:state"] = core.serialize(state)
shown.bea = nil
check(not Q.open_npc(bea, entity("done")), "C a giver with neither rows nor hint does not open")
eq(shown.bea, nil, "C ...and shows nothing")

-- ---------------------------------------------------------------------------
-- D: the marker
-- ---------------------------------------------------------------------------
npc("soon1", "Soon One")
quest("soon1_q", {npc = "soon1", level = 4}) -- opens at 2: L+1 at level 1
npc("soon2", "Soon Two")
quest("soon2_q", {npc = "soon2", level = 5}) -- opens at 3: L+2
npc("far", "Far")
quest("far_q", {npc = "far", level = 6}) -- opens at 4: L+3
npc("story", "Story")
quest("story_q", {npc = "story", level = 5, story = true})
quest("story_side", {npc = "story", level = 6})
npc("mixed", "Mixed")
quest("mixed_now", {npc = "mixed", level = 1})
quest("mixed_soon", {npc = "mixed", level = 4, story = true})
npc("gated", "Gated")
quest("gated_first", {npc = "far", level = 30})
quest("gated_q", {npc = "gated", level = 4, prerequisites = {"gated_first"}})
local cid = new_player("cid")
set_level(cid, 1)
local marks = Q.marker_states(cid)
eq(marks.soon1, "locked", "D next quest at L+1: the grey !")
eq(marks.soon2, "locked", "D next quest at L+2: the grey !")
eq(marks.far, nil, "D next quest at L+3: no marker")
eq(marks.story, "story_locked", "D the next quest is a story quest: the story's grey !")
eq(marks.mixed, "available", "D something acceptable wins over a soon quest")
eq(marks.gated, nil, "D a quest behind an unmet prerequisite gives no marker")
eq(marks.later, nil, "D the later giver (opens at 7) shows nothing at 1")
eq(select(2, Q.npc_quests(cid, "gated")), nil, "D ...and no hint")
set_level(cid, 2)
marks = Q.marker_states(cid)
eq(marks.far, "locked", "D a level-up brings the L+3 giver into reach (memo refreshed)")
set_level(cid, 3)
marks = Q.marker_states(cid)
eq(marks.soon1, "available", "D at its acceptance level the quest is acceptable")
eq(marks.story, "story_available", "D ...the story quest too")
set_level(cid, 1)
eq(Q.marker_states(cid).far, nil, "D a level-down hides it again")
-- The map window and the minimap read these values; their status lists
-- keep "locked" (the grey "!").
eq(table.concat(Q.MARKER_STATUSES, " "), "ready available active locked", "D the marker statuses are unchanged")

-- ---------------------------------------------------------------------------
-- E: validate.lua
-- ---------------------------------------------------------------------------
do
	local V = Q.validate
	local function errors(data)
		local list = V.structure({{name = DAWNMERE, zone = "elandor_dawnmere_fields", front = false, data = data}},
			Q.registered_npcs)
		return table.concat(list, "\n")
	end
	local clean = errors(json.decode(read("mods/PLAYER/grug_quests/data/zones/" .. DAWNMERE)))
	lacks(clean, "[E-levels]", "E the shipped file passes the level checks")
	local stale = json.decode(read("mods/PLAYER/grug_quests/data/zones/" .. DAWNMERE))
	stale.quests[1].min_level = 1
	has(errors(stale), "min_level is gone: a quest is accepted from its level - 2 (Round 65) [E-levels]",
		"E a stale min_level is an E-levels error")
	lacks(errors(stale), "missing required field 'min_level'", "E min_level is not required")
end

-- ---------------------------------------------------------------------------
-- F: Help -> Quests
-- ---------------------------------------------------------------------------
do
	local help = read("mods/PLAYER/grug_inventory/help.lua")
	has(help, "silver ! = a new quest in one or two levels", "F Help names the silver ! as a quest in one or two levels")
	lacks(help, "needs a higher level", "F ...not as \"needs a higher level\"")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	print(("R65 QUEST PORTABLE FAIL %d of %d"):format(#failures, checks))
	os.exit(1)
end
print("R65 QUEST PORTABLE PASS checks=" .. checks)
