-- Round 36 lane E portable test (the quest engine for the main questline,
-- round36-plan.md §2.4, §2.5, §2.7). Loads the REAL grug_quests files (with
-- use.lua) and grug_achievements under small stubs and checks:
--   A. a "use at a place" objective's states and labels: dialogue, quest log,
--      HUD line, compact feed text; the place's canonical reference and name
--      (a clash site by its key, a recipe quest place by "zone/id");
--   B. visibility per player: the quest object exists while a player who
--      still needs it is within reach and is observed by exactly those
--      players; several players share one object; the last one leaving
--      removes it; it stands on walkable ground under open air;
--   C. the hold: a right-click within reach starts it, the feed counts the
--      seconds, the hold's end credits that player only and hides the object
--      from them; letting go, stepping away, taking damage and the object
--      vanishing interrupt it; a player without the quest cannot start one;
--   D. one use point credits every active quest that names it;
--   E. the turn-in hook fires exactly once per turn-in (again for each turn-in
--      of a repeatable), never for a refused one, and a failing observer
--      keeps neither the others nor the turn-in from completing;
--   F. grug_achievements counts quest:<id> and quest_tag:<tag> through the
--      hook (one test catalogue row each) and earns the tier;
--   G. the load-time validators accept good and refuse bad use objectives
--      and tags (the same rules in tools/r28_design/validate.py --self-test);
--   H. the combat ray passes an object the player cannot see.
--
-- Usage (repo root): luajit tools/r36_e/portable_test.lua [REPO]
local repo = arg[1] or "."
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")

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
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. " in " .. ("%q"):format(tostring(text)) .. ")")
end
local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy
local function count_keys(t)
	local n = 0
	for _ in pairs(t or {}) do n = n + 1 end
	return n
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
function ItemStack(item)
	local name, count = "", 0
	if type(item) == "table" and item.get_name then
		name, count = item:get_name(), item:get_count()
	elseif type(item) == "string" then
		local n, c = item:match("^(%S*)%s*(%d*)")
		name, count = n, tonumber(c) or (n == "" and 0 or 1)
	end
	local stack = {}
	function stack:get_name() return count > 0 and name or "" end
	function stack:get_count() return name ~= "" and count or 0 end
	function stack:is_empty() return name == "" or count <= 0 end
	function stack:add_item(other) return ItemStack(other) end
	function stack:equals(other) return self:get_name() == other:get_name() and self:get_count() == other:get_count() end
	function stack:to_string() return self:is_empty() and "" or (name .. " " .. count) end
	return stack
end

local MOD_PATHS = {grug_quests = repo .. "/mods/PLAYER/grug_quests",
	grug_achievements = repo .. "/mods/PLAYER/grug_achievements", grug_mobs = repo .. "/nowhere"}
local current_mod = "grug_quests"
local serial, players, entities, objects = {}, {}, {}, {}
local hp_callbacks, joins = {}, {}
local now_us = 0
local unloaded = false
local flood -- fn(pos) -> true where a column is under water (section I)
local logged = {}
local GROUND_Y = 10 -- every column: walkable dirt up to here, air above
core = {
	registered_items = {}, registered_aliases = {}, registered_entities = entities,
	registered_nodes = {["default:dirt"] = {walkable = true}, air = {walkable = false},
		["default:grass_1"] = {walkable = false},
		["default:water_source"] = {walkable = false, liquidtype = "source"}},
	get_us_time = function() return now_us end,
	get_modpath = function(name) return MOD_PATHS[name] end,
	get_current_modname = function() return current_mod end,
	-- No shipped zone quest file: the test's files are loaded by hand.
	get_dir_list = function() return {} end,
	parse_json = function(text) return (json.decode(text)) end,
	serialize = function(value) serial[#serial + 1] = deep_copy(value); return tostring(#serial) end,
	deserialize = function(text) return deep_copy(serial[tonumber(text)]) end,
	get_item_group = function() return 0 end,
	get_player_by_name = function(name) return players[name] end,
	formspec_escape = function(text) return text end,
	colorize = function(_, text) return text end,
	show_formspec = function() end,
	close_formspec = function() end,
	get_connected_players = function() return {} end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	log = function(level, text) logged[#logged + 1] = level .. " " .. text end,
	chat_send_player = function() end,
	get_player_window_information = function() return nil end,
	register_entity = function(name, def) entities[name] = def end,
	register_on_player_hpchange = function(fn) hp_callbacks[#hp_callbacks + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	-- Blocks high above the ground are not loaded (out of the active range);
	-- `unloaded` unloads everything.
	get_node_or_nil = function(pos)
		if unloaded or pos.y > GROUND_Y + 20 then return nil end
		if pos.y <= GROUND_Y then return {name = "default:dirt"} end
		if flood and pos.y <= GROUND_Y + 3 and flood(pos) then return {name = "default:water_source"} end
		if pos.y == GROUND_Y + 1 and pos.x % 2 == 1 then return {name = "default:grass_1"} end
		return {name = "air"}
	end,
	add_entity = function(pos, name)
		local def = entities[name]
		local object = {pos = {x = pos.x, y = pos.y, z = pos.z}, valid = true, props = {}}
		local ent = setmetatable({name = name, object = object}, {__index = def})
		function object:is_valid() return self.valid end
		function object:remove() self.valid = false end
		function object:get_pos() return self.valid and self.pos or nil end
		function object:get_luaentity() return self.valid and ent or nil end
		function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
		function object:set_armor_groups(g) self.armor = g end
		function object:set_observers(set) self.observers = deep_copy(set) end
		function object:get_observers() return self.observers end
		objects[#objects + 1] = object
		if def.on_activate then def.on_activate(ent) end
		return object
	end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {distance = function(a, b)
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(x * x + y * y + z * z)
end}

------------------------------------------------------------------------------
-- Game surface.
------------------------------------------------------------------------------
local fed = {}
grug_core = {register_tag_visibility = function() end,
	-- Mirrors grug_core.is_max_hp_clamp (environment_damage.lua; tools/r37_cb).
	is_max_hp_clamp = function(reason)
		return reason ~= nil and reason.type == "set_hp" and reason.from == "engine"
	end,
	get_player_faction = function() return nil end,
	settlement_socket_anchor = function() return nil end,
	hud_layout = {side_text_width = function() return 400 end, QUEST_WRAP = 400, anchors = {quest_list = {}}},
	feed_item = function() end,
	feed = function(player, kind, text, key)
		fed[#fed + 1] = {name = player:get_player_name(), kind = kind, text = text, key = key}
		return true
	end,
	plain_text = function(text) return text end,
	-- The giver's socket (a "from here" direction is measured from it).
	settlement_sockets_at = function() return {{id = "quest_host", pos = {x = -2074, y = 0, z = -826}}} end,
	item_name = function(item) return tostring(item) end}
local level_of = {}
grug_xp = {
	get_level = function(player) return level_of[player:get_player_name()] or 60 end,
	register_on_level_change = function() end,
	quest_reward = function(level, weight) return math.floor(weight * (25 + 5 * level) + 0.5) end,
	add_xp = function() end,
}
grug_money = {MAX = 1000000, format = function(copper) return copper .. " copper" end,
	get = function() return 0 end, add = function() end}
grug_factions = {get_faction = function() return "accord" end, same_faction = function() return false end,
	display_name = function(id) return id end}
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")
grug_classes = {get_race = function() return "human" end}
grug_inventory = {BAG_COUNT = 0}
grug_zones = {terrain_height_at = function() return GROUND_Y end,
	get = function(zone) return {display_name = zone, level_min = 31, level_max = 40} end,
	id_at = function() return "elandor_stormvault_heights" end}
sfinv = {register_page = function() end, make_formspec = function(_, _, c) return c end,
	get_page = function() return "" end, set_page = function() end, pages = {}, pages_unordered = {}}

-- The spawn-region seams a use place needs (spawn_regions.lua): one clash
-- site and one recipe quest place, each with its position on this "world".
local SALTGATE = {x = -2200, z = -80}
local CAIRN = {x = -1799, z = -700} -- an odd column: grass above the dirt
grug_mobs = {
	register_on_eligible_kill = function() end,
	register_participant_drop_hook = function() end,
	disposition = function() return "aggressive" end,
	spawn_regions = {
		LEADER_RANGE = 48,
		clash_site = function(key)
			return key == "r20_anchor_076" and
				{key = key, zone = "front_gravesalt_escarpment", name = "Saltgate Remnant"} or nil
		end,
		place = function(ref)
			return ref == "r20_anchor_076" and {x = SALTGATE.x, z = SALTGATE.z, name = "Saltgate Remnant"} or nil
		end,
		zone_place = function(zone, id)
			return zone == "elandor_stormvault_heights" and id == "brandscar_cairn" and
				{zone = zone, id = id, name = "Brandscar Cairn"} or nil
		end,
		place_spot = function(zone, id)
			return zone == "elandor_stormvault_heights" and id == "brandscar_cairn" and
				{x = CAIRN.x, z = CAIRN.z, name = "Brandscar Cairn"} or nil
		end,
		get_area = function() return nil end,
		area_roles = function() return nil end,
		zone_area_ids = function() return {} end,
		leader = function() return nil end,
		describe = function() return {phrase = "nearby"} end,
	},
}

------------------------------------------------------------------------------
-- grug_quests, the real files in init.lua's order.
------------------------------------------------------------------------------
grug_quests = {}
for _, file in ipairs({"registry", "state", "labels", "npc", "npcs", "use", "validate", "loader", "ui",
		"hud"}) do
	dofile(repo .. "/mods/PLAYER/grug_quests/" .. file .. ".lua")
end
local Q = grug_quests
check(Q.use_objects.toll_box and Q.use_objects.pledged_standard and Q.use_objects.rootmark,
	"the object kinds come from data/use_objects.json")

local GIVER = "r20_anchor_027_host" -- Splitbolt Station (npcs.lua)
local function use(place, label, extra)
	local row = {type = "use", place = place, object = "toll_box", label = label, hold = 3}
	for k, v in pairs(extra or {}) do row[k] = v end
	return row
end
local function quest(id, objectives, extra)
	local row = {id = id, line = "main", giver = GIVER, turnin = GIVER, min_level = 31, level = 35,
		title = id, text = "Go there. Come back.", objectives = objectives, rewards = {weight = 2}}
	for k, v in pairs(extra or {}) do row[k] = v end
	return row
end
local QUESTS = {
	quest("e_fire", {use("r20_anchor_076", "Light the signal fire")}, {tags = {"main_line"}}),
	quest("e_fire_too", {use("r20_anchor_076", "Light the signal fire")}),
	quest("e_flag", {use("r20_anchor_076", "Plant the banner", {object = "pledged_standard"})}),
	quest("e_cairn", {use("brandscar_cairn", "Plant the banner", {object = "pledged_standard", hold = 2})},
		{text = "The {name:brandscar_cairn} lies {dir_from_giver:brandscar_cairn}. The {name:r20_anchor_076} too."}),
	quest("e_bounty", {use("elandor_stormvault_heights/brandscar_cairn", "Burn the mark",
		{object = "rootmark", count = 1})}, {repeatable = {cooldown = 60}, tags = {"main_line", "bounties"}}),
}
local FILE = {name = "elandor_stormvault_heights.quests.json", zone = "elandor_stormvault_heights",
	front = false, data = {zone = "elandor_stormvault_heights",
		hubs = {{id = "splitbolt", givers = {{npc = GIVER, lines = {"main"}}}}}, quests = QUESTS}}
local files = {FILE}
local ok, err = pcall(Q.load_quest_files, deep_copy(files))
check(ok, "the use quests load: " .. tostring(err))
ok, err = pcall(Q.validate_quest_data, deep_copy(files))
check(ok, "the use quests pass the world checks: " .. tostring(err))

------------------------------------------------------------------------------
-- A. States and labels.
------------------------------------------------------------------------------
local fire = Q.registered_quests.e_fire.objectives[1]
eq(fire.place, "r20_anchor_076", "A a clash site keeps its key")
eq(fire.place_name, "Saltgate Remnant", "A the clash site's name")
local cairn = Q.registered_quests.e_cairn.objectives[1]
eq(cairn.place, "elandor_stormvault_heights/brandscar_cairn", "A a bare quest place is the file zone's")
eq(Q.registered_quests.e_bounty.objectives[1].place, cairn.place, "A a qualified place reads the same")
eq(Q.objective_action(fire), "Light the signal fire at Saltgate Remnant", "A the action names the place")
has(Q.quest_text(Q.registered_quests.e_cairn, true), "The Brandscar Cairn lies nearby. The Saltgate Remnant too.",
	"A placeholders name a quest place and a clash site")

local function make_player(name, pos)
	local meta, lists = {}, {main = {}}
	for i = 1, 4 do lists.main[i] = ItemStack("") end
	local p = {name = name, pos = pos, hp = 20, control = {place = false}}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_player_control() return {place = self.control.place} end
	function p:hud_add() return 1 end -- the quest tracker (hud.lua) joins too
	function p:hud_change() end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end, set_string = function(_, k, v) meta[k] = v end,
			get_int = function(_, k) return tonumber(meta[k]) or 0 end,
			set_int = function(_, k, v) meta[k] = tostring(v) end}
	end
	local inv = {}
	function inv:get_list(list) return lists[list] end
	function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
	function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack); return true end
	function p:get_inventory() return inv end
	players[name] = p
	for _, fn in ipairs(joins) do fn(p) end
	return p
end
local function row_of(player, id)
	for _, row in ipairs(Q.journal(player).quests) do if row.id == id then return row end end
end
local function at(place, dx, dz) return {x = place.x + (dx or 0), y = GROUND_Y + 1, z = place.z + (dz or 0)} end

local ann = make_player("ann", at(SALTGATE, 20, 0))
check(Q.accept(ann, "e_fire"), "A ann accepts the signal fire")
local row = row_of(ann, "e_fire")
eq(row.objectives[1].count .. "/" .. row.objectives[1].required, "0/1", "A the objective starts at 0/1")
eq(Q.status(ann, "e_fire"), "active", "A active until used")
eq(Q.hud_line(row, 400), "0/1 Light the signal fire at Saltgate Remnant", "A the HUD line")
eq(Q.compact_text(row), "Light the signal fire 0/1", "A the compact (feed) text")
local seen = Q.progress_changes(nil, Q.journal(ann))

------------------------------------------------------------------------------
-- B. Visibility per player.
------------------------------------------------------------------------------
local points = Q._use_points
local bob = make_player("bob", at(SALTGATE, 5, 5)) -- no quest
local cid = make_player("cid", at(SALTGATE, 200, 0)) -- the quest, far away
check(Q.accept(cid, "e_fire"), "B cid accepts the signal fire")
for _, p in ipairs({ann, bob, cid}) do Q.use_pass(p) end
local key = Q.use_key(fire)
local point = points[key]
check(point ~= nil, "B a needed place within reach gets its point")
eq(count_keys(points), 1, "B one point")
local object = point and point.object
check(object and object:is_valid(), "B the quest object exists")
eq(object and object.observers and object.observers.ann, true, "B ann observes it")
eq(count_keys(object and object.observers), 1, "B only ann: bob has no quest, cid is far away")
eq(object and object.pos.y, GROUND_Y + 1 - 0.5 + Q.use_objects.toll_box.size / 2,
	"B it stands on the ground (the kind's sprite size)")
eq(object and object.props.textures[1], Q.use_objects.toll_box.texture, "B its texture is the kind's")
eq(object and object.props.nametag, "Light the signal fire", "B its nametag is the act")
check(object and object.armor and object.armor.immortal == 1, "B it takes no damage")
cid.pos = at(SALTGATE, 30, 0)
Q.use_pass(cid)
eq(point.object, object, "B a second player shares the object")
check(object.observers.ann and object.observers.cid and not object.observers.bob, "B observers: ann and cid")
-- The same act at the same place from another quest is the same point; a
-- quest change re-checks at once.
local before = #objects
local gus = make_player("gus", at(SALTGATE, 10, 0))
check(Q.accept(gus, "e_fire_too"), "B gus accepts the other signal-fire quest")
check(point.observers.gus and #objects == before, "B the same act at the same place is the same point")
-- Another act at the same place stands beside it.
check(Q.accept(gus, "e_flag"), "B gus accepts the banner at the same place")
local fpoint = points[Q.use_key(Q.registered_quests.e_flag.objectives[1])]
check(fpoint and fpoint.object and fpoint ~= point, "B another act there is its own point")
local d = fpoint and vector.distance(fpoint.object.pos, {x = object.pos.x, y = fpoint.object.pos.y, z = object.pos.z})
check(d and d >= 1.5 and d <= 2.9, "B it stands about 2 nodes beside the first (" .. tostring(d) .. ")")
check(fpoint.object.observers.gus and not fpoint.object.observers.ann, "B seen by gus only")
Q.abandon(gus, "e_fire_too")
Q.abandon(gus, "e_flag")
check(not point.observers.gus, "B abandoning the quest leaves the point at once")
check(points[Q.use_key(Q.registered_quests.e_flag.objectives[1])] == nil and not fpoint.object:is_valid(),
	"B its last observer gone, the banner point and object are removed")

------------------------------------------------------------------------------
-- C. The hold.
------------------------------------------------------------------------------
local def = entities["grug_quests:use_object"]
local function click(player, obj)
	return def.on_rightclick(obj:get_luaentity(), player)
end
local function advance(seconds, step)
	step = step or 0.1
	for _ = 1, math.floor(seconds / step + 0.5) do
		now_us = now_us + step * 1000000
		Q.use_step(now_us)
	end
end
local function last_feed(name)
	for i = #fed, 1, -1 do if fed[i].name == name then return fed[i] end end
end
-- Out of reach: no hold.
eq(Q.start_use(ann, object), false, "C ann at 20 nodes cannot start")
ann.pos = at(SALTGATE, 2, 0)
cid.pos = at(SALTGATE, -2, 0)
bob.pos = at(SALTGATE, 0, 2)
eq(Q.start_use(bob, object), false, "C bob, without the quest, cannot start")
ann.control.place = true
click(ann, object)
check(Q._use_holds.ann ~= nil, "C a right-click within reach starts ann's hold")
eq(last_feed("ann").text, "Light the signal fire: 0/3 s", "C the feed shows the hold")
eq(last_feed("ann").key, "quest_use", "C one feed line for the hold")
advance(1.05)
eq(last_feed("ann").text, "Light the signal fire: 1/3 s", "C the feed counts the seconds")
-- cid takes damage during his own hold: interrupted, no credit.
cid.control.place = true
check(Q.start_use(cid, object), "C cid starts his hold")
for _, fn in ipairs(hp_callbacks) do fn(cid, -2, {type = "punch"}) end
check(Q._use_holds.cid == nil, "C damage interrupts")
eq(last_feed("cid").text, "Light the signal fire: interrupted.", "C the interruption is shown")
for _, fn in ipairs(hp_callbacks) do fn(ann, 3, {type = "set_hp"}) end
check(Q._use_holds.ann ~= nil, "C healing does not interrupt")
advance(2.0)
check(Q._use_holds.ann == nil, "C ann's hold ends after 3 s")
eq(row_of(ann, "e_fire").objectives[1].count, 1, "C ann is credited")
eq(Q.status(ann, "e_fire"), "ready", "C ann's quest is ready")
eq(row_of(cid, "e_fire").objectives[1].count, 0, "C cid is not credited by ann's hold")
check(not object.observers.ann and object.observers.cid, "C the object hides from ann, stays for cid")
local _, changed = Q.progress_changes(seen, Q.journal(ann))
eq(changed[1] and Q.feed_text(changed[1]), "Light the signal fire 1/1", "C the progress feed line")
-- Letting go, stepping away and the object vanishing stop a hold.
check(Q.start_use(cid, object), "C cid starts again")
cid.control.place = false
advance(0.1)
check(Q._use_holds.cid == nil, "C letting go stops it")
eq(last_feed("cid").text, "Light the signal fire: stopped.", "C letting go is shown")
cid.control.place = true
check(Q.start_use(cid, object), "C cid starts again")
advance(1.0)
cid.pos = at(SALTGATE, -7, 0)
advance(0.1)
check(Q._use_holds.cid == nil, "C stepping away stops it")
eq(last_feed("cid").text, "Light the signal fire: too far away.", "C stepping away is shown")
cid.pos = at(SALTGATE, -2, 0)
check(Q.start_use(cid, object), "C cid starts again")
object:remove()
advance(0.1)
check(Q._use_holds.cid == nil, "C a vanished object stops it")
eq(row_of(cid, "e_fire").objectives[1].count, 0, "C no interrupted hold credits anything")
-- The next pass adds the object again (an unloaded block dropped it).
Q.use_pass(cid)
local again = point.object
check(again and again ~= object and again:is_valid() and again.observers.cid, "C the next pass restores it")
object = again
check(Q.start_use(cid, object), "C cid holds once more")
check(not Q.start_use(cid, object), "C one hold at a time")
advance(3.0)
eq(row_of(cid, "e_fire").objectives[1].count, 1, "C cid is credited by his own hold")
-- The last observer gone: the object and its point are removed.
check(points[key] == nil and not object:is_valid(), "C the last credited player removes the object")

------------------------------------------------------------------------------
-- D. One point, every quest that names it; a rule-placed quest place.
------------------------------------------------------------------------------
local dan = make_player("dan", at(SALTGATE, 1, 1))
check(Q.accept(dan, "e_fire") and Q.accept(dan, "e_fire_too"), "D dan has both signal-fire quests")
check(Q.accept(dan, "e_cairn"), "D and the cairn quest")
Q.use_pass(dan)
eq(count_keys(points), 1, "D both quests share one point; the cairn is out of reach")
dan.control.place = true
check(Q.start_use(dan, points[key].object), "D dan starts")
advance(3.0)
eq(row_of(dan, "e_fire").objectives[1].count + row_of(dan, "e_fire_too").objectives[1].count, 2,
	"D one hold credits both quests")
dan.pos = at(CAIRN, 3, 0)
unloaded = true
Q.use_pass(dan)
local ckey = Q.use_key(cairn)
check(points[ckey] and not points[ckey].object, "D unloaded ground: the point waits without an object")
unloaded = false
Q.use_pass(dan)
local cpoint = points[ckey]
check(cpoint and cpoint.object and cpoint.object.observers.dan, "D the rule-placed place shows its object")
check(cpoint and math.abs(cpoint.object.pos.x - CAIRN.x) <= 3 and math.abs(cpoint.object.pos.z - CAIRN.z) <= 3,
	"D at the place's spot")
eq(cpoint and cpoint.object.pos.y, GROUND_Y + 1 - 0.5 + Q.use_objects.pledged_standard.size / 2,
	"D on the dirt under the grass (the pledged standard's size)")
eq(cpoint and cpoint.object.props.textures[1], Q.use_objects.pledged_standard.texture, "D the pledged standard kind's texture")
check(Q.start_use(dan, cpoint.object), "D dan plants the banner")
advance(2.0)
eq(Q.status(dan, "e_cairn"), "ready", "D credited after its own 2 s hold")
dan.pos = at(SALTGATE, 500, 0)
Q.use_pass(dan)
eq(count_keys(points), 0, "D nobody near: no point")

------------------------------------------------------------------------------
-- E. The turn-in hook.
------------------------------------------------------------------------------
local fired = {}
Q.register_on_turn_in(function(player, id, quest_def)
	fired[#fired + 1] = player:get_player_name() .. " " .. id .. " " .. tostring(quest_def.id == id)
end)
Q.register_on_turn_in(function() error("observer failure") end)
local seen_after_failure = 0
Q.register_on_turn_in(function() seen_after_failure = seen_after_failure + 1 end)
ok, err = pcall(Q.turn_in, ann, "e_fire")
check(not ok and tostring(err):find("observer failure", 1, true), "E a failing observer's error surfaces")
eq(#fired, 1, "E the hook fired once")
eq(fired[1], "ann e_fire true", "E with the player, the id and the definition")
eq(seen_after_failure, 1, "E the observer after the failing one ran")
eq(Q.status(ann, "e_fire"), "completed", "E the turn-in completed")
eq(Q.turn_in(ann, "e_fire"), false, "E a second turn-in is refused")
eq(#fired, 1, "E a refused turn-in fires nothing")
eq(Q.turn_in(bob, "e_fire"), false, "E no turn-in without the quest")
eq(#fired, 1, "E still once")

------------------------------------------------------------------------------
-- F. grug_achievements counts quests and quest tags.
------------------------------------------------------------------------------
local refreshed = 0
grug_visuals = {register_cloak_source = function() end, apply = function() end}
grug_inventory.refresh_character = function() refreshed = refreshed + 1 end
grug_inventory.refresh_character_tab = function() end
grug_mobs.register_on_boss_kill = function() end
current_mod = "grug_achievements"
dofile(repo .. "/mods/PLAYER/grug_achievements/init.lua")
current_mod = "grug_quests"
local A = grug_achievements
-- One test row per counter (the shipped rows come with the questline lanes).
for _, row in ipairs({
	{id = "test_fire", name = "Fire Watch", counter = "quest:e_fire_too", text_one = "Light it.",
		tiers = {{at = 1}}},
	{id = "test_line", name = "Main Line", counter = "quest_tag:main_line", text = "Finish %d.",
		tiers = {{at = 1}, {at = 2}}},
}) do
	A.book.achievements[#A.book.achievements + 1] = row
	A.book.achievement[row.id] = row
	A.book.by_counter[row.counter] = {row}
end
local clock = 1000
Q.clock = function() return clock end
local eve = make_player("eve", at(SALTGATE, 1, 0))
check(Q.accept(eve, "e_fire_too") and Q.accept(eve, "e_bounty"), "F eve takes two quests")
Q.use_pass(eve)
eve.control.place = true
check(Q.start_use(eve, points[key].object), "F eve lights the fire")
advance(3.0)
pcall(Q.turn_in, eve, "e_fire_too")
local R = A.rules
eq(R.count(eve:get_meta(), "quest:e_fire_too"), 1, "F quest:<id> counted")
eq(R.earned(eve:get_meta(), A.book.achievement.test_fire), 1, "F its tier is earned")
local announced
for _, line in ipairs(fed) do
	if line.name == "eve" and line.text:find("Achievement: Fire Watch", 1, true) then announced = true end
end
check(announced, "F the achievement is announced")
eq(R.count(eve:get_meta(), "quest_tag:main_line"), 0, "F an untagged quest counts no tag")
eve.pos = at(CAIRN, 0, 1)
Q.use_pass(eve)
check(Q.start_use(eve, points[Q.use_key(Q.registered_quests.e_bounty.objectives[1])].object),
	"F eve burns the mark")
advance(3.0)
pcall(Q.turn_in, eve, "e_bounty")
eq(R.count(eve:get_meta(), "quest_tag:main_line"), 1, "F a tagged quest counts its tag")
eq(R.count(eve:get_meta(), "quest_tag:bounties"), 0, "F a tag no achievement asks for is not stored")
eq(R.count(eve:get_meta(), "quest:e_bounty"), 0, "F neither is a quest no achievement asks for")
clock = clock + 61
check(Q.accept(eve, "e_bounty"), "F the bounty again after its cooldown")
Q.use_pass(eve)
check(Q.start_use(eve, points[Q.use_key(Q.registered_quests.e_bounty.objectives[1])].object), "F and again")
advance(3.0)
pcall(Q.turn_in, eve, "e_bounty")
eq(R.count(eve:get_meta(), "quest_tag:main_line"), 2, "F each turn-in of a repeatable counts")
eq(R.earned(eve:get_meta(), A.book.achievement.test_line), 2, "F the second tier")

------------------------------------------------------------------------------
-- G. The validators.
------------------------------------------------------------------------------
local V = Q.validate
local loader_world
do
	local real = V.world
	V.world = function(f, w) loader_world = w; return real(f, w) end
	Q.validate_quest_data(deep_copy(files))
	V.world = real
end
local npcs_before = {}
for id, npc in pairs(Q.registered_npcs) do npcs_before[id] = npc end
eq(#V.structure(deep_copy(files), npcs_before), 0, "G the test file's structure is clean")
eq(#V.world(deep_copy(files), loader_world), 0, "G its world checks are clean")
local function first(f) return f[1].data.quests[1] end
local cases = {
	{"unknown place", "E-use-place", function(f) first(f).objectives[1].place = "r20_anchor_014" end},
	{"a quest place of another zone, bare", "E-use-place", function(f)
		first(f).objectives[1].place = "front_gravesalt_escarpment/brandscar_cairn" end},
	{"unknown object kind", "E-use-object", function(f) first(f).objectives[1].object = "statue" end},
	{"no object kind", "E-use-object", function(f) first(f).objectives[1].object = nil end},
	{"hold 0", "E-objective", function(f) first(f).objectives[1].hold = 0 end},
	{"hold 16", "E-objective", function(f) first(f).objectives[1].hold = 16 end},
	{"hold 2.5", "E-objective", function(f) first(f).objectives[1].hold = 2.5 end},
	{"counted twice", "E-objective", function(f) first(f).objectives[1].count = 2 end},
	{"no label", "E-objective", function(f) first(f).objectives[1].label = " " end},
	{"no place", "E-objective", function(f) first(f).objectives[1].place = nil end},
	{"roles on a use", "E-objective", function(f) first(f).objectives[1].roles = {"wolf"} end},
	{"a use field on a kill", "E-objective", function(f)
		first(f).objectives[2] = {type = "kill", roles = {"wolf"}, count = 1, hold = 3} end},
	{"an unknown objective field", "E-unknown-key", function(f) first(f).objectives[1].radius = 5 end},
	{"an unknown type", "E-objective", function(f) first(f).objectives[1].type = "touch" end},
	{"tags not a list", "E-tags", function(f) first(f).tags = "main_line" end},
	{"a tag not snake_case", "E-tags", function(f) first(f).tags = {"Main Line"} end},
	{"a tag twice", "E-tags", function(f) first(f).tags = {"a", "a"} end},
	{"count 1 written out", nil, function(f) first(f).objectives[1].count = 1 end},
}
for _, case in ipairs(cases) do
	local name, code, mutate = case[1], case[2], case[3]
	local mutated = deep_copy(files)
	mutate(mutated)
	local found = V.structure(mutated, npcs_before)
	if #found == 0 then found = V.world(mutated, loader_world) end
	if code == nil then
		eq(#found, 0, "G " .. name .. ": accepted (" .. table.concat(found, " | ") .. ")")
	else
		local hit
		for _, message in ipairs(found) do
			if message:find("[" .. code .. "]", 1, true) then hit = message end
		end
		check(hit ~= nil and hit:find("quest e_fire", 1, true) ~= nil,
			"G " .. name .. ": " .. code .. " naming the quest, got: " .. table.concat(found, " | "))
	end
end
-- The registry refuses what the loader would never hand it.
ok = pcall(Q.register_quest, "e_raw", {title = "Raw", description = "Raw.", npc = GIVER,
	objectives = {{type = "use", place = "r20_anchor_076", object = "toll_box", label = "x", hold = 30,
		count = 1}}, rewards = {weight = 1}})
check(not ok, "G the registry refuses a hold of 30 s")

------------------------------------------------------------------------------
-- I. Placement: the stand is searched up to 6 nodes round the place; loaded
--    ground without one is warned about once and searched again only every
--    10 s, unloaded ground waits silently.
------------------------------------------------------------------------------
do
	local fay = make_player("fay", at(SALTGATE, 3, 0))
	-- Water within 5 nodes of the place: the stand is beyond the old 3-node
	-- search. (Taking
	-- a quest runs the pass at once.)
	flood = function(pos)
		local dx, dz = pos.x - SALTGATE.x, pos.z - SALTGATE.z
		return dx * dx + dz * dz <= 25
	end
	check(Q.accept(fay, "e_fire"), "I fay accepts the signal fire")
	local point = points[key]
	local d = point and point.object and math.sqrt((point.object.pos.x - SALTGATE.x) ^ 2 +
		(point.object.pos.z - SALTGATE.z) ^ 2)
	check(d and d > 5 and d < 6, "I the widened ring finds the nearest dry column, (4, 4) out (" ..
		tostring(d) .. ")")
	Q.abandon(fay, "e_fire")
	check(points[key] == nil, "I gone with its quest")
	-- Water everywhere: no stand at all.
	flood = function() return true end
	logged = {}
	check(Q.accept(fay, "e_fire"), "I fay takes it again")
	point = points[key]
	check(point and not point.object, "I flooded ground: no object")
	local warnings = 0
	for _, line in ipairs(logged) do
		if line:find("^warning %[grug_quests%] use place r20_anchor_076: no open walkable ground") then
			warnings = warnings + 1
		end
	end
	eq(warnings, 1, "I one warning names the place")
	local reads = 0
	local real_get = core.get_node_or_nil
	core.get_node_or_nil = function(pos) reads = reads + 1; return real_get(pos) end
	Q.use_pass(fay)
	eq(reads, 0, "I no new search before 10 s")
	now_us = now_us + 10000001
	Q.use_pass(fay)
	check(reads > 0, "I searched again after 10 s")
	eq(#logged, 1, "I and not warned again")
	core.get_node_or_nil = real_get
	flood = nil
	now_us = now_us + 10000001
	Q.use_pass(fay)
	check(points[key] and points[key].object and points[key].object:is_valid(), "I dry ground: the object appears")
	Q.abandon(fay, "e_fire")
	-- Unloaded ground: no warning.
	logged = {}
	unloaded = true
	check(Q.accept(fay, "e_fire"), "I fay takes it a third time")
	eq(#logged, 0, "I unloaded ground waits without a warning")
	unloaded = false
	Q.abandon(fay, "e_fire")
end

------------------------------------------------------------------------------
-- H. No server ray a player aims meets an object that player cannot see:
--    the shared helper (grug_core.unseen_by, combat_ray.lua), the hand ray
--    (grug_abilities/input.lua, the crosshair's interact colour and hand
--    clicks) and the skill item's right-click ray (grug_abilities/init.lua
--    ability_on_secondary_use): a door behind another player's quest object
--    still opens.
------------------------------------------------------------------------------
do
	local function source(path)
		local handle = assert(io.open(repo .. "/" .. path))
		local text = handle:read("*a")
		handle:close()
		return text
	end
	local helper = source("mods/CORE/grug_core/combat_ray.lua")
		:match("\n(function grug_core%.unseen_by%(ref, player%).-\nend)\n")
	check(helper ~= nil, "H the shared helper is in combat_ray.lua")
	assert(loadstring(helper))()
	local unseen = grug_core.unseen_by
	local hidden = {get_observers = function() return {ann = true} end}
	local open = {get_observers = function() return nil end}
	eq(unseen(hidden, bob), true, "H bob's ray passes ann's quest object")
	eq(unseen(hidden, ann), false, "H ann's ray meets it")
	eq(unseen(open, bob), false, "H an object everyone sees blocks as before")
	eq(unseen(hidden, nil), false, "H a ray without a player passes nothing")
	check(source("mods/CORE/grug_core/combat_ray.lua"):find("local unseen = grug_core.unseen_by", 1, true),
		"H the combat ray uses the helper")
	-- One ray along +x: the hidden object at 1 node, a door node at 2.
	local door = {type = "node", under = {x = 2, y = 0, z = 0}, intersection_point = {x = 2, y = 0, z = 0}}
	local function hits(object)
		return {{type = "object", ref = object, intersection_point = {x = 1, y = 0, z = 0}}, door}
	end
	local current
	grug_core.combat_eye_pos = function() return {x = 0, y = 0, z = 0} end
	grug_core.aim_raycast = function()
		local i = 0
		return function() i = i + 1; return current[i] end
	end
	vector.add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end
	vector.multiply = function(a, n) return {x = a.x * n, y = a.y * n, z = a.z * n} end
	vector.normalize = function(a) return a end
	for _, p in ipairs({ann, bob}) do p.get_look_dir = function() return {x = 1, y = 0, z = 0} end end
	-- The hand ray, cut out of input.lua.
	local ray_src = source("mods/PLAYER/grug_abilities/input.lua")
		:match("\n\t(local function ray%(player, range, origin%).-\n\tend)\n")
	check(ray_src ~= nil, "H the hand ray is in input.lua")
	local ray = assert(loadstring(ray_src .. "\nreturn ray"))()
	current = hits(hidden)
	eq(ray(bob, 4).type, "node", "H bob's hand ray reaches the door behind ann's object")
	eq(ray(ann, 4).type, "object", "H ann's hand ray meets her object")
	current = hits(open)
	eq(ray(bob, 4).type, "object", "H an object everyone sees still blocks the hand ray")
	-- The skill item's right-click, cut out of init.lua with its upvalues.
	local click_src = source("mods/PLAYER/grug_abilities/init.lua")
		:match("\n(local function ability_on_secondary_use%(.-\nend)\n")
	check(click_src ~= nil, "H ability_on_secondary_use is in init.lua")
	local env = "local NODE_INTERACT_RANGE = 4\nlocal function sneaking() return false end\n" ..
		"local function pass_to_node(pos) PASSED = pos end\n"
	local click = assert(loadstring(env .. click_src .. "\nreturn ability_on_secondary_use"))()
	grug_abilities = {}
	local clicked = 0
	hidden.get_luaentity = function() return {on_rightclick = function() clicked = clicked + 1 end} end
	current = hits(hidden)
	PASSED = nil
	click("stack", bob, {type = "nothing"})
	check(PASSED == door.under and clicked == 0, "H bob's right-click opens the door, not ann's object")
	PASSED = nil
	click("stack", ann, {type = "nothing"})
	check(PASSED == nil and clicked == 1, "H ann's right-click uses her object")
	grug_abilities, PASSED = nil, nil
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then os.exit(1) end
print("R36 E PORTABLE PASS checks=" .. checks)
