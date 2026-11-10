-- Round 71 lane MOBS portable test (LuaJIT): encounters, the boss, the door, the
-- chest and the Expedition's drop filter, on stubs of the engine and the game; the
-- engine half is tools/r71_mobs/run.sh. Item levels above 60: tools/r33_c1.
-- Prints "R71 MOBS PORTABLE PASS checks=<n>".
--
--   luajit tools/r71_mobs/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---- The stubs ---------------------------------------------------------------
local timers, on_loaded, entities, ready, ended, entered = {}, {}, {}, {}, {}, {}
local refuse = {} -- mob names add_entity refuses, for now
local world = {}  -- "x,y,z" -> node name; everything else is air
local detached, removed_boxes = {}, {}
local players = {}

local function key(p) return p.x .. "," .. p.y .. "," .. p.z end

vector = {
	add = function(a, n) return {x = a.x + n, y = a.y + n, z = a.z + n} end,
	subtract = function(a, n) return {x = a.x - n, y = a.y - n, z = a.z - n} end,
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
	zero = function() return {x = 0, y = 0, z = 0} end,
}

function ItemStack(text)
	local stack = {text = text}
	function stack.get_name() return text end
	return stack
end

core = {
	registered_nodes = {air = {walkable = false}, ["default:stone"] = {walkable = true}},
	registered_entities = {["grug_mobs:spider"] = {}, ["grug_mobs:golem"] = {}},
	get_modpath = function() return repo .. "/mods/PLAYER/grug_expeditions" end,
	get_current_modname = function() return "grug_expeditions" end,
	log = function() end,
	serialize = function(t) return t end,
	after = function(_, fn) timers[#timers + 1] = fn end,
	register_on_mods_loaded = function(fn) on_loaded[#on_loaded + 1] = fn end,
	-- packs.lua's: tools/r71_pack
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_joinplayer = function() end,
	register_on_shutdown = function() end,
	register_node = function(name, def) core.registered_nodes[name] = def end,
	load_area = function() end,
	objects_in_area = function()
		local function remove() core.objects_removed = (core.objects_removed or 0) + 1 end
		local gone = {is_player = function() return false end, get_attach = function() end,
			remove = remove}
		-- A player's name tag stays on its player.
		local player = {is_player = function() return true end}
		local tag = {is_player = function() return false end,
			get_attach = function() return player end, remove = remove}
		local list, at = {player, tag, gone}, 0
		return function()
			at = at + 1
			return list[at]
		end
	end,
	-- Round 73 GAME: a spread spot needs a floor (encounters.lua spot), stone below y 5.
	get_node_or_nil = function(pos) return {name = world[key(pos)] or (pos.y < 5 and "default:stone" or "air")} end,
	get_player_by_name = function(name) return players[name] end,
	add_entity = function(pos, name, data)
		if refuse[name] then return nil end
		local ent = {name = name}
		for field, value in pairs(data) do ent[field] = value end
		local object = {get_luaentity = function() return ent end,
			get_pos = function() return ent.pos end}
		ent.object, ent.pos = object, pos
		entities[#entities + 1] = ent
		return object
	end,
	find_nodes_in_area = function(_, _, name)
		local out = {}
		for at, node in pairs(world) do
			if node == name then
				local x, y, z = at:match("(-?%d+),(-?%d+),(-?%d+)")
				out[#out + 1] = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
			end
		end
		return out
	end,
	remove_node = function(pos) world[key(pos)] = nil end,
	get_meta = function() return {set_string = function() end} end,
	formspec_escape = function(text) return text end,
	colorize = function(_, text) return text end,
	close_formspec = function() end,
	create_detached_inventory = function(name, callbacks, player)
		local inv = {callbacks = callbacks, player = player, stacks = {}}
		function inv.set_size(_, _, size) inv.size = size end
		function inv.set_stack(_, _, index, stack) inv.stacks[index] = stack end
		detached[name] = inv
		return inv
	end,
	remove_detached_inventory = function(name)
		detached[name] = nil
		removed_boxes[#removed_boxes + 1] = name
	end,
}

local function flush()
	local queue = timers
	timers = {}
	for _, fn in ipairs(queue) do fn() end
end

local shown
default = {node_sound_wood_defaults = function() return {} end, node_formspec = {
	formname = "form", session_pos = function() end,
	show = function(player, pos, build) shown = build(pos, player, {}) end}}

-- Every ore and gem from the shipped registry's own lines.
local resources = {}
do
	local file = assert(io.open(repo .. "/mods/ITEMS/grug_materials/registry.lua"))
	local text = file:read("*a")
	file:close()
	for item in text:gmatch('raw_item = "([^"]+)"') do resources[#resources + 1] = {raw_item = item} end
	for item in text:gmatch('cut_item = "([^"]+)"') do resources[#resources + 1] = {raw_item = item} end
end
grug_materials = {RESOURCES = resources}

local settled, tiers, resets = {}, {}, {}
grug_mobs = {
	rift_rules = {SPAWN_RANGE = 48},
	place_on_ground = function() end,
	set_tier = function(ent, tier) tiers[ent] = tier end,
	settle_mob_death = function() return true end,
	live_claim = function() return true end,
	_item_drop_filter = function(_, drops) return drops end,
	boss_settle = function(id, _, _, credit_as) settled[#settled + 1] = {id, credit_as} end,
	boss_attempt_reset = function(id) resets[#resets + 1] = id end,
	coin_bag_range = function() return {13, 39} end,
	level_band = function() return 3 end,
}
grug_money = {make_bag = function(copper)
	local bag = ItemStack("grug_money:bag")
	bag.copper = copper
	return bag
end}
grug_items = {roll_gear_item = function(level, quality)
	local stack = ItemStack("gear")
	stack.level, stack.quality = level, quality
	return stack
end}
grug_gear = {initialize_weapon_tooltip = function() end}
grug_inventory = {
	STATION = {x = 0, y = 0, pitch = 1},
	station_box = function() return "box", 1 end,
	station_list = function(location) return location end,
	station_formspec = function(_, content) return content end,
}
local feeds = {}
grug_core = {feed = function(_, _, text) feeds[#feeds + 1] = text end,
	engage_mob = function() end,
	ui = {text_growth = function() return 1 end, colors = {muted = "#fff"}}}

local runs_at = {}
grug_expeditions = {
	templates = {},
	catalogue = {EXPEDITIONS = {{id = "test_vault"}}},
	register_on_ready = function(fn) ready[#ready + 1] = fn end,
	register_on_end = function(fn) ended[#ended + 1] = fn end,
	register_on_enter = function(fn) entered[#entered + 1] = fn end,
	register_on_leave = function() end,
	encounters = function(run) return run.encounters end,
	places = function(run) return run.places end,
	run_at = function(pos) return runs_at[pos.z] end,
	belongs = function(run, name) return run.owners[name] == true end,
	-- Round 72 SHIFT: the catalogue row's wall signs (none for the test vault).
	definition = function() return {} end,
}
local M = grug_expeditions

local real_settle_filter = grug_mobs._item_drop_filter
dofile(repo .. "/mods/PLAYER/grug_expeditions/encounters.lua")
check(grug_mobs._item_drop_filter ~= real_settle_filter, "the drop filter is wrapped")

local function fake_player(name, x, z)
	local player = {name = name, hp = 20, at = {x = x, y = 5, z = z}}
	function player.get_player_name() return name end
	function player.is_player() return true end
	function player.get_hp() return player.hp end
	function player.get_pos() return player.at end
	players[name] = player
	return player
end

local next_id, runs = 0, {}
local function new_run(z, rows, level)
	next_id = next_id + 1
	local run = {id = next_id, expedition = "test_vault", level = level or 29, encounters = rows,
		inside = {}, entered = {}, owners = {}, state = "running",
		places = {door = {x = 0, y = 5, z = z}, chest = {x = 2, y = 5, z = z}}}
	for _, fn in ipairs(ready) do fn(run) end
	runs_at[z] = run
	runs[#runs + 1] = run
	return run
end
local function step_in(run, player)
	run.inside[player.name], run.entered[player.name], run.owners[player.name] = true, true, true
	for _, fn in ipairs(entered) do fn(run, player.name) end
	flush()
end
local function mobs_of(run)
	local out = {}
	for _, ent in ipairs(entities) do
		if ent._grug_expedition == run.id then out[#out + 1] = ent end
	end
	return out
end

-- ---- A. Rooms ------------------------------------------------------------------
local run = new_run(1000, {
	{room = "near", mob = "grug_mobs:spider", count = 3, tier = "normal", pos = {x = 10, y = 5, z = 1000}},
	{room = "near", mob = "grug_mobs:golem", count = 1, tier = "elite", pos = {x = 20, y = 5, z = 1000}},
	{room = "far", mob = "grug_mobs:spider", count = 1, tier = "normal", pos = {x = 100, y = 5, z = 1000}},
	{room = "boss", mob = "grug_mobs:golem", count = 1, tier = "boss", pos = {x = 200, y = 5, z = 1000}},
})
local ana = fake_player("ana", 0, 1000)
check(#timers == 0, "A an idle server has no pass")
step_in(run, ana)
check(#mobs_of(run) == 4, "A only the near room spawned: " .. #mobs_of(run))
for _, ent in ipairs(mobs_of(run)) do
	check(ent._grug_spawn_level == 29 and ent._grug_authored == true and ent.lifetimer >= 20000,
		"A the first staticdata carries level, the limit's mark and the far despawn's")
	check(ent.static_save == nil and ent._grug_boss_id == nil, "A a plain mob stays saved, no boss")
	check(ent._grug_pack ~= nil, "A every mob is a body of its room's pack (tools/r71_pack)")
end
local first = mobs_of(run)
check(first[1].pos.x ~= first[2].pos.x or first[1].pos.z ~= first[2].pos.z, "A a pack spreads")
check(tiers[first[1]] == "normal" and tiers[first[4]] == "elite", "A the marker's tier")

flush()
check(#mobs_of(run) == 4, "A a pass places nothing twice")
-- What dies stays dead, a player back in range changes nothing.
table.remove(entities, 1)
ana.at = {x = 500, y = 5, z = 1000}
flush()
ana.at = {x = 0, y = 5, z = 1000}
flush()
check(#mobs_of(run) == 3, "A a dead mob does not come back")

-- A mob out of range in y stays waiting; a dead player calls nothing up.
ana.at = {x = 100, y = 80, z = 1000}
flush()
check(#mobs_of(run) == 3, "A the height counts")
ana.at, ana.hp = {x = 100, y = 5, z = 1000}, 0
flush()
check(#mobs_of(run) == 3, "A a dead player calls no room")
ana.hp = 20
refuse["grug_mobs:spider"] = true
flush()
check(#mobs_of(run) == 3, "A the engine refused the mob")
refuse["grug_mobs:spider"] = nil
flush()
check(#mobs_of(run) == 4, "A the refused mob is tried again")

-- ---- B. The boss ---------------------------------------------------------------
check(not M.rewards_open(run), "B rewards shut while the boss lives")
ana.at = {x = 190, y = 5, z = 1000}
flush()
local boss = mobs_of(run)[5]
check(boss and boss._grug_boss_id == "expedition:test_vault:1", "B the ledger id is the run's")
check(tiers[boss] == "elite", "B the boss is an elite, never the flat tier")
flush()
check(#timers == 0, "B no room left, the pass stops")

-- The boss drops nothing, an Expedition mob no ore or gem, every other mob all.
local rows = {{name = "default:iron_lump"}, {name = "grug_materials:rough_citrine"},
	{name = "grug_mobs:spider_silk"}, {name = "grug_materials:emberglass_shard"},
	{name = "grug_materials:cut_jade"}}
check(grug_mobs._item_drop_filter(boss, rows) == nil, "B the boss drops nothing")
local kept = grug_mobs._item_drop_filter(mobs_of(run)[1], rows)
check(#kept == 1 and kept[1].name == "grug_mobs:spider_silk", "C no ore or gem, the rest stays")
check(#grug_mobs._item_drop_filter({name = "wolf"}, rows) == 5, "C another mob keeps its drops")

-- The door: of this run only, and only for this boss.
local other = new_run(2000, {
	{room = "boss", mob = "grug_mobs:golem", count = 1, tier = "boss", pos = {x = 5, y = 5, z = 2000}},
})
local door_cell = key({x = 1, y = 5, z = 1000})
world[door_cell] = "grug_expeditions:reward_door"
local stale = {_grug_expedition = 99, _grug_boss_id = "expedition:test_vault:99",
	object = {get_pos = function() return {x = 0, y = 5, z = 1000} end}}
grug_mobs.settle_mob_death(stale)
check(#settled == 0 and world[door_cell] ~= nil, "B a stale boss opens nothing")
grug_mobs.settle_mob_death({name = "wolf", object = boss.object})
check(#settled == 0, "B an ordinary death settles nothing")

ana.at = {x = 2, y = 5, z = 1000}
local function open(player, at)
	shown = nil
	core.registered_nodes["grug_expeditions:reward_chest"].on_rightclick(at, nil, player)
	return shown
end
check(not open(ana, run.places.chest) and feeds[#feeds] == "The chest is sealed.", "D sealed before the kill")

boss.pos = {x = 1, y = 5, z = 1000}
grug_mobs.settle_mob_death(boss)
check(#settled == 1 and settled[1][1] == boss._grug_boss_id and
	settled[1][2] == "expedition:test_vault", "B settled on the run's ledger, credited stably")
check(world[door_cell] == nil and M.rewards_open(run), "B the door opened")
check(not M.rewards_open(other), "B the other run's boss still stands")
grug_mobs.settle_mob_death(boss)
check(#settled == 1, "B settled once")

-- ---- D. The chest --------------------------------------------------------------
local late = fake_player("late", 2, 1000)
local stranger = fake_player("eve", 2, 1000)
check(open(ana, run.places.chest) ~= nil, "D the first opening")
local box = detached["grug_expedition_chest_1_ana"]
check(box and box.player == "ana" and box.size == 8, "D a list of ana's own")
check(box.stacks[1].quality == 2 and box.stacks[1].level == 29, "D gear at the run's level")
check(box.callbacks.allow_put() == 0 and box.callbacks.allow_move() == 0, "D nothing goes in")
check(box.callbacks.allow_take(nil, nil, nil, {get_count = function() return 3 end}, ana) == 3,
	"D the owner takes")
check(box.callbacks.allow_take(nil, nil, nil, {get_count = function() return 3 end}, stranger) == 0,
	"D a stranger does not")
local first_stack = box.stacks[1]
open(ana, run.places.chest)
check(detached["grug_expedition_chest_1_ana"].stacks[1] == first_stack, "D one roll per player")
check(not open(stranger, run.places.chest), "D a stranger is refused")
run.owners.late = true
check(not open(late, run.places.chest), "D a member who has not entered is refused")
run.entered.late = true
check(open(late, run.places.chest) ~= nil and detached["grug_expedition_chest_1_late"] ~= nil,
	"D entering after the kill still opens one's own")
check(detached["grug_expedition_chest_1_late"] ~= box, "D a separate inventory")

for _, fn in ipairs(ended) do fn(run, "released") end
runs_at[1000] = nil
check(#removed_boxes == 2 and next(detached) == nil, "D the run's lists end with it")
check(resets[1] == boss._grug_boss_id, "B a run's end clears its ledger")
check(core.objects_removed == 1, "B a run's end takes its live objects, no player, nothing attached")
check(not open(ana, run.places.chest) and feeds[#feeds] == "This Expedition has ended.",
	"D an ended run opens nothing")

-- A template without a boss has an open chest.
local plain = new_run(3000, {})
check(M.rewards_open(plain), "D no boss, no seal")

-- ---- E. The loot table ---------------------------------------------------------
local L = dofile(repo .. "/mods/PLAYER/grug_expeditions/loot.lua")
local function top(_, hi) return hi end
local function low(lo) return lo end
local tbl = L.TABLES.test_vault
local plan = L.plan(tbl, 29, top, {13, 39})
check(#plan == 4, "E the chance 25 row misses at the top of the dice: " .. #plan)
local rolled = L.plan(tbl, 29, low, {13, 39})
check(#rolled == 5 and rolled[3].copper == 26 and rolled[4].count == 2, "E every row at the bottom of the dice")
check(#L.plan(tbl, 40, low, {13, 39}) == 4, "E a level row holds in its levels only")
check(L.slots(rolled) == 8 and L.slots({1, 2, 3, 4, 5, 6, 7, 8, 9}) == 16, "E full rows")
local ores = L.ore_items(resources)
check(ores["default:gold_lump"] and ores["grug_materials:rough_jade"] and
	ores["grug_materials:cut_jade"] and ores["grug_materials:emberglass_shard"], "E the ore set")
check(not ores["grug_materials:iron_bar"], "E a bar is no ore")
L.check(ores)
L.TABLES.bad = {materials = {{item = "default:gold_lump", min = 1, max = 1}}}
check(not pcall(L.check, ores), "E a table with ore stops the load")
L.TABLES.bad = nil

-- ---- F. Load checks ------------------------------------------------------------
local function load_fails(rows)
	M.templates = {t = {encounters = rows}}
	return not pcall(on_loaded[1])
end
check(not load_fails({{mob = "grug_mobs:spider", tier = "elite", count = 1}}), "F a good marker loads")
check(load_fails({{mob = "grug_mobs:none", tier = "elite", count = 1}}), "F an unknown mob stops the load")
check(load_fails({{mob = "grug_mobs:spider", tier = "king", count = 1}}), "F an unknown tier stops it")
check(load_fails({{mob = "grug_mobs:golem", tier = "boss", count = 2}}), "F two bosses stop it")
M.catalogue.EXPEDITIONS[2] = {id = "no_table"}
check(load_fails({}), "F an Expedition without a loot table stops it")

-- ---- G. A boss's fixed name ----------------------------------------------------
local NC = dofile(repo .. "/mods/ENTITIES/grug_mobs/names_core.lua")
local index = NC.build({["world/flintback/L20-69"] = "Flintback"})
for _, level in ipairs({20, 29, 47, 69}) do
	check(NC.lookup(index, "flintback", nil, level) == "Flintback", "G a world slot names it off the map")
end

print("R71 MOBS PORTABLE PASS checks=" .. checks)
