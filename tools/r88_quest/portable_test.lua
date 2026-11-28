-- Round 88 lane QUEST portable test (LuaJIT): the quest markers of ruling 5
-- (round88-plan.md §2.5, §4 QUEST, §6).
--
--   luajit tools/r88_quest/portable_test.lua [repo]
--
-- Loads the REAL grug_quests registry, state, labels and npc files and the
-- REAL grug_map markers.lua on a fake engine (the harness of r65_quest).
-- Checks, for a level-30 player unless named:
--   M  Q.marker_states: a giver whose quests are all 10 or more levels below
--      (the quest level, not the acceptance level) is "low", the boundary at
--      exactly 10 and 9; one current quest keeps "available" (a mixed
--      giver); a quest above the player's level stays "available"; story
--      quests never low ("story_available", also beside a low side quest);
--      a quest not yet acceptable gives no marker, also beside a low one (low)
--      and the dialog keeps its hint; "ready" and "active" outrank "low",
--      also for a story quest in progress; a level-up turns a giver low and
--      opens the next one (memo refreshed); no "soon" state is left;
--   H  the head marker (npc.lua's tag callback): the grey "!" for a low
--      giver, the story "!" for a story giver, nothing for a not-yet giver;
--   P  the maps (markers.lua): every value marker_states can give has a
--      texture file, "low" the grey "!" of Round 65; "low" ranks lowest;
--   F  Help -> Quests names the silver "!" as far-below quests.
-- Prints "R88 QUEST PORTABLE PASS checks=<n>" or the failures.
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
-- The head markers' children (npc.lua): each records its mesh, texture and
-- observers.
local children = {}
local function add_child()
	local child = {valid = true}
	function child:set_attach() end
	function child:set_properties(props) self.mesh, self.texture = props.mesh, props.textures[1] end
	function child:set_observers(set) self.observers = set end
	function child:is_valid() return self.valid end
	function child:remove() self.valid = false end
	children[#children + 1] = child
	return child
end
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
	add_entity = function() return add_child() end,
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
local visibility
grug_core = {register_tag_visibility = function(fn) visibility = fn end, feed_item = function() end,
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
for _, file in ipairs({"registry", "state", "labels", "npc"}) do
	dofile(repo .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
local Q = grug_quests

local function npc(id)
	Q.register_npc(id, {settlement = "s", socket = id, title = "Giver " .. id})
end
local function quest(id, def)
	def.title, def.description = def.title or id, def.description or "Text of " .. id
	def.rewards = def.rewards or {weight = 1, copper = 5}
	def.objectives = def.objectives or {{type = "kill", mobs = {"grug_mobs:boar"}, names = {{"Boar"}},
		name_set = {Boar = true}, count = 1}}
	Q.register_quest(id, def)
end
local DIRT = {{type = "item", item = "default:dirt", count = 1}}

npc("low10"); quest("low10_q", {npc = "low10", level = 20})
npc("edge9"); quest("edge9_q", {npc = "edge9", level = 21})
npc("deep"); quest("deep_a", {npc = "deep", level = 3}); quest("deep_b", {npc = "deep", level = 12})
npc("mixed"); quest("mixed_low", {npc = "mixed", level = 10}); quest("mixed_now", {npc = "mixed", level = 25})
npc("above"); quest("above_q", {npc = "above", level = 32})
npc("future"); quest("future_q", {npc = "future", level = 33})
npc("future_low"); quest("fl_low", {npc = "future_low", level = 5}); quest("fl_later", {npc = "future_low", level = 40})
npc("story"); quest("story_q", {npc = "story", level = 5, story = true})
npc("story_mix"); quest("sm_story", {npc = "story_mix", level = 5, story = true})
quest("sm_side", {npc = "story_mix", level = 5})
npc("ready"); quest("ready_q", {npc = "ready", level = 5, objectives = DIRT}); quest("ready_low", {npc = "ready", level = 4})
npc("active"); quest("active_q", {npc = "active", level = 5}); quest("active_low", {npc = "active", level = 4})
npc("story_active"); quest("sa_story", {npc = "story_active", level = 5, story = true})
quest("sa_low", {npc = "story_active", level = 4})

local ann = new_player("ann")
set_level(ann, 30)
check(Q.accept(ann, "ready_q", "ready"), "M setup: the ready giver's quest accepted")
check(Q.accept(ann, "active_q", "active"), "M setup: the active giver's quest accepted")
check(Q.accept(ann, "sa_story", "story_active"), "M setup: the story quest accepted")
ann.lists.main[1] = ItemStack("default:dirt 1")
Q.markers_changed(ann) -- the held item (the tracker's poll in the game)
local marks = Q.marker_states(ann)
eq(marks.low10, "low", "M exactly 10 levels below: low")
eq(marks.edge9, "available", "M 9 levels below: still the gold !")
eq(marks.deep, "low", "M every quest far below: low")
eq(marks.mixed, "available", "M one low and one current quest: the gold !")
eq(marks.above, "available", "M an acceptable quest above the player's level: the gold !")
eq(marks.future, nil, "M a quest not yet acceptable: no marker")
eq(select(2, Q.npc_quests(ann, "future")), 31, "M ...the dialog keeps its hint level")
eq(marks.future_low, "low", "M a low quest beside a not-yet one: low")
eq(marks.story, "story_available", "M a story quest far below is never low")
eq(marks.story_mix, "story_available", "M a story offer beside a low side quest: the story marker")
eq(marks.ready, "ready", "M ready outranks low")
eq(marks.active, "active", "M in progress outranks low")
eq(marks.story_active, "story_active", "M a story quest in progress outranks low")
for npc_id, value in pairs(marks) do
	check(value ~= "locked" and value ~= "story_locked" and value ~= "story_low",
		"M no soon or story-low value: " .. npc_id .. "=" .. tostring(value))
end
eq(Q.SOON_LEVELS, nil, "M the soon window is gone")
eq(table.concat(Q.MARKER_STATUSES, " "), "ready available active low", "M the marker statuses")
-- A level-up moves both edges without a quest change.
set_level(ann, 31)
marks = Q.marker_states(ann)
eq(marks.edge9, "low", "M level 31: the level-21 quest is 10 below now")
eq(marks.future, "available", "M level 31: the level-33 quest is acceptable now")
set_level(ann, 30)
marks = Q.marker_states(ann)
eq(marks.edge9, "available", "M back at 30: the gold ! again")
eq(marks.future, nil, "M back at 30: no marker again")
-- Low needs ten levels: nothing is low for a level-10 player.
local bo = new_player("bo")
set_level(bo, 10)
local early = Q.marker_states(bo)
eq(early.deep, "available", "M level 10: quests of level 3 and 12 are not low")
set_level(bo, 13)
eq(Q.marker_states(bo).deep, "available", "M level 13: the level-12 quest keeps the gold !")
set_level(bo, 22)
eq(Q.marker_states(bo).deep, "low", "M level 22: both far below")

-- ---------------------------------------------------------------------------
-- H: the head marker
-- ---------------------------------------------------------------------------
check(type(visibility) == "function", "H npc.lua registered its tag callback")
local function head(id)
	local start = #children
	local parent = {object = nil}
	local entity = {_grug_start = "s", _grug_socket = id}
	parent.object = {is_valid = function() return true end}
	entity.object = parent.object
	function parent:get_luaentity() return entity end
	function parent:get_pos() return {x = 0, y = 0, z = 0} end
	visibility(parent, {ann = true}, false)
	local made = {}
	for i = start + 1, #children do
		local child = children[i]
		if child.observers and child.observers.ann then made[#made + 1] = child end
	end
	return made
end
local low_head = head("low10")
eq(#low_head, 1, "H a low giver: one marker")
eq(low_head[1] and low_head[1].mesh, "grug_quests_exclamation.obj", "H ...an exclamation mark")
eq(low_head[1] and low_head[1].texture, "[fill:16x16:#c0c0c0", "H ...in grey")
local gold = head("mixed")
eq(gold[1] and gold[1].texture, "[fill:16x16:#ffd700", "H a current giver: the gold !")
local story = head("story")
eq(story[1] and story[1].mesh, "grug_quests_exclamation.obj", "H a story giver: an exclamation mark")
eq(story[1] and story[1].texture, "[fill:16x16:#b46bff", "H ...in the story colour")
eq(#head("future"), 0, "H a giver with only future quests: no marker")

-- ---------------------------------------------------------------------------
-- P: the maps' textures and order
-- ---------------------------------------------------------------------------
grug_map = {}
local M = dofile(repo .. "/mods/PLAYER/grug_map/markers.lua")
eq(M.quest_texture("low"), "grug_map_quest_locked.png", "P low: the grey ! file of Round 65")
local values = {"low"}
for _, status in ipairs({"ready", "available", "active"}) do
	values[#values + 1] = status
	values[#values + 1] = "story_" .. status
end
for _, value in ipairs(values) do
	local texture = M.texture({kind = "quest", status = value})
	local handle = io.open(repo .. "/mods/PLAYER/grug_map/textures/" .. texture, "rb")
	check(handle ~= nil, "P the map texture of " .. value .. " (" .. texture .. ")")
	if handle then handle:close() end
end
local function rank(status) return M.rank({kind = "quest", status = status}) end
check(rank("low") < rank("active") and rank("active") < rank("story_active") and
	rank("story_active") < rank("available"), "P low draws lowest, below in progress")
local window = read("mods/PLAYER/grug_map/window.lua")
has(window, 'QUEST_TEXTURE = {low = marker_art.quest_texture("low")}', "P the map window maps low like the minimap")

-- ---------------------------------------------------------------------------
-- F: Help -> Quests
-- ---------------------------------------------------------------------------
local help = read("mods/PLAYER/grug_inventory/help.lua")
has(help, "silver ! = only quests far below your level", "F Help names the silver ! as far-below quests")
lacks(help, "in one or two levels", "F ...no longer as a quest in one or two levels")
has(help, "A quest you cannot take yet shows no symbol.", "F ...and says a quest not yet acceptable shows none")

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	print(("R88 QUEST PORTABLE FAIL %d of %d"):format(#failures, checks))
	os.exit(1)
end
print("R88 QUEST PORTABLE PASS checks=" .. checks)
