-- Round 81 lane BUGS portable test (LuaJIT): the player-visible bugs of
-- docs/planning/round81-plan.md §4 BUGS (audit 2026-11).
--
--   luajit tools/r81_bugs/portable_test.lua [repo]
--
-- Loads the REAL grug_mounts/restore.lua under a small `core` stub with a
-- clock, and cuts out of their files the real farming growth path
-- (protection_ok .. crop_timer and the geometry LBM), the real equipment
-- seam (grug_core.notify_equipment_change, grug_inventory.equipment_changed),
-- grug_abilities' swing-clock consumer and grug_gear's weapon line with its
-- two hooks, and the once-ever weapon hint. Checks:
--   M  P4-01: an undisturbed set-down lands the rider in the logout column;
--      a rider teleported off it meanwhile (/home), attached, or dead and
--      respawned is released where they are and never set back; a drift
--      under a node still lands; a death before the first poll ends the
--      restore;
--   F  I1-01: a growth refused by protection (crop timer, geometry LBM)
--      records no violation, retries on the timer and changes nothing; an
--      unprotected crop grows; the player paths still record;
--   G  I2-01: a level-up rewrites the weapon lines with one narrow
--      notification (no full consumer pass) and keeps the swing clock; a
--      Str/Dex equip runs one full pass plus the narrow nested one and keeps
--      the clock; a look change stays a full change; both hands at once
--      name no list; the line text itself is unchanged;
--   H  P3-06: the weapon hint is not spent on a weapon the empty slot refuses
--      (another hand's family, a level too high) nor while the slot holds a
--      broken weapon; it goes out for one the slot takes;
--   T  DD4-01: no player text sends anyone to the waystone plaza.
-- Prints "R81 BUGS PORTABLE PASS checks=<n>" or the failures; the G counts
-- are printed as "G counts ..." lines (the before/after comparison).

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
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(path, pattern, label)
	local block = read(path):match(pattern)
	assert(block, label .. " not found in " .. path)
	return block
end
local function run(block, name)
	return assert(loadstring(block, "=" .. name))()
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy

-- A clock for core.after.
local now, timers = 0, {}
local function advance(dt)
	local target = now + dt
	while true do
		local best
		for index, timer in ipairs(timers) do
			if timer.at <= target and (not best or timer.at < timers[best].at) then best = index end
		end
		if not best then break end
		local timer = table.remove(timers, best)
		now = timer.at
		timer.fn()
	end
	now = target
end

local function new_meta(store)
	store = store or {}
	local meta = {store = store}
	function meta:get_string(k) return store[k] or "" end
	function meta:set_string(k, v)
		v = tostring(v or "")
		store[k] = v ~= "" and v or nil
	end
	function meta:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function meta:set_int(k, v) store[k] = tostring(math.floor(v)) end
	function meta:get_float(k) return tonumber(store[k]) or 0 end
	function meta:set_float(k, v) store[k] = tostring(v) end
	return meta
end

------------------------------------------------------------------------------
-- M. The ride restored at login: the flyer's set-down (P4-01).
------------------------------------------------------------------------------
do
	local callbacks = {join = {}, leave = {}, die = {}}
	local players, holds, feeds, emerges = {}, {}, {}, 0
	core = {
		registered_nodes = {
			air = {walkable = false, liquidtype = "none"},
			floor = {walkable = true, liquidtype = "none"},
		},
		-- Ground everywhere: the floor node at y -1, air above.
		get_node_or_nil = function(pos)
			return {name = math.floor(pos.y + 0.5) == -1 and "floor" or "air"}
		end,
		register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
		register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
		register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
		register_on_shutdown = function() end,
		after = function(delay, fn) timers[#timers + 1] = {at = now + delay, fn = fn} end,
		get_us_time = function() return now * 1e6 end,
		compare_block_status = function() return true end,
		-- The emerge answers 0.5 s later.
		emerge_area = function(_, _, fn)
			emerges = emerges + 1
			core.after(0.5, function() fn({x = 0, y = 0, z = 0}, 0, 0) end)
		end,
		get_player_by_name = function(name) return players[name] end,
		get_connected_players = function() return {} end,
	}
	grug_core = {
		hold_movement = function(player, key) holds[player:get_player_name()] = key end,
		release_movement = function(player, key)
			if holds[player:get_player_name()] == key then holds[player:get_player_name()] = nil end
		end,
		feed = function(player, _, text) feeds[#feeds + 1] = text end,
	}
	grug_mounts = {
		LOGOUT_RIDE_KEY = "grug_mounts:logout_ride",
		TIERS = {[3] = {mode = "flight"}},
		owns_tier = function() return true end,
		is_mounted = function() return false end,
		-- Refused (an enemy's land): the flyer is set down.
		mount_saved = function() return false, "Your mount could not be summoned here." end,
	}
	assert(loadfile(ROOT .. "/mods/PLAYER/grug_mounts/restore.lua"))()

	local function make_player(name, pos)
		local player = {name = name, pos = copy(pos), hp = 100, meta = new_meta(), moves = 0}
		function player:get_player_name() return self.name end
		function player:get_pos() return copy(self.pos) end
		function player:set_pos(p)
			self.moves = self.moves + 1
			self.pos = copy(p)
		end
		function player:get_hp() return self.hp end
		function player:get_meta() return self.meta end
		function player:get_attach() return self.parent end
		player.meta:set_int(grug_mounts.LOGOUT_RIDE_KEY, 3)
		players[name] = player
		return player
	end
	local function join(player)
		for _, fn in ipairs(callbacks.join) do fn(player) end
	end
	local function die(player)
		player.hp = 0
		holds[player.name] = nil -- grug_core.clear_movement on death
		for _, fn in ipairs(callbacks.die) do fn(player) end
	end

	-- Undisturbed: the logout column's ground.
	local ada = make_player("ada", {x = 10.2, y = 40, z = -3.4})
	join(ada)
	eq(holds.ada, "grug_mounts:restore", "M held at the join")
	advance(0.3)
	eq(#feeds, 1, "M the refused summon: one feed line")
	eq(emerges, 1, "M the set-down emerges the column")
	advance(1)
	eq(ada.pos.y, -0.5, "M undisturbed: set on the ground below")
	check(ada.pos.x == 10.2 and ada.pos.z == -3.4, "M undisturbed: in the logout column")
	eq(holds.ada, nil, "M undisturbed: released")

	-- A drift under a node still lands in the column.
	local bea = make_player("bea", {x = 0, y = 30, z = 0})
	join(bea)
	advance(0.3)
	bea.pos = {x = 0.6, y = 30, z = 0.4}
	advance(1)
	eq(bea.pos.y, -0.5, "M a drift under a node: still set down")
	eq(holds.bea, nil, "M a drift under a node: released")

	-- /home during the set-down: released at home, never set back.
	local cal = make_player("cal", {x = 100, y = 60, z = 100})
	join(cal)
	advance(0.3)
	cal.pos = {x = -500, y = 8.5, z = 240}
	cal.moves = 0
	advance(1)
	check(cal.pos.x == -500 and cal.pos.y == 8.5 and cal.pos.z == 240,
		"M /home meanwhile: the player stays at home")
	eq(cal.moves, 0, "M /home meanwhile: no set_pos")
	eq(holds.cal, nil, "M /home meanwhile: the restore hold is released")
	advance(40)
	eq(cal.moves, 0, "M /home meanwhile: nothing moves them later either")

	-- A death and a quick respawn during the set-down.
	local dan = make_player("dan", {x = 50, y = 70, z = 50})
	join(dan)
	advance(0.3)
	die(dan)
	advance(0.1)
	dan.hp, dan.pos, dan.moves = 100, {x = 300, y = 4.5, z = -20}, 0
	advance(40)
	eq(dan.moves, 0, "M death and respawn: the respawned player is never set back")
	eq(holds.dan, nil, "M death and respawn: no hold is left")

	-- A death before the first poll ends the restore at once.
	local eve = make_player("eve", {x = -50, y = 70, z = 50})
	local feeds_before, emerges_before = #feeds, emerges
	join(eve)
	advance(0.1)
	die(eve)
	advance(0.1)
	eve.hp, eve.pos, eve.moves = 100, {x = 7, y = 3.5, z = 7}, 0
	advance(40)
	eq(#feeds, feeds_before, "M death before the poll: no summon tried")
	eq(emerges, emerges_before, "M death before the poll: no set-down")
	eq(eve.moves, 0, "M death before the poll: not moved")

	-- Attached meanwhile (seated on something): released, not moved.
	local fay = make_player("fay", {x = 20, y = 50, z = 20})
	join(fay)
	advance(0.3)
	fay.parent = {}
	advance(1)
	eq(fay.moves, 0, "M attached meanwhile: not moved")
	eq(holds.fay, nil, "M attached meanwhile: released")
	advance(40)
end

------------------------------------------------------------------------------
-- F. Crop growth refused by protection (I1-01).
------------------------------------------------------------------------------
do
	local FILE = "mods/ITEMS/grug_farming/init.lua"
	local growth = cut(FILE, "\n(local function protection_ok%(.-\nlocal function crop_timer%(.-\nend)\n",
		"growth path")
	local lbm = cut(FILE, "\n(core%.register_lbm%(%{\n\tlabel = \"Activate current cultivated crop geometry\".-\n%}%))\n",
		"geometry LBM")
	local nodes, metas, timers_by, protected = {}, {}, {}, {}
	local violations = 0
	local lbm_def
	local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
	core = {
		registered_nodes = {air = {buildable_to = true}},
		get_node = function(p) return {name = nodes[key(p)] or "air"} end,
		get_node_or_nil = function(p) return {name = nodes[key(p)] or "air"} end,
		swap_node = function(p, n) nodes[key(p)] = n.name end,
		set_node = function(p, n) nodes[key(p)] = n.name end,
		remove_node = function(p) nodes[key(p)] = nil end,
		get_meta = function(p)
			metas[key(p)] = metas[key(p)] or new_meta()
			return metas[key(p)]
		end,
		get_node_timer = function(p)
			local timer = timers_by[key(p)] or {}
			timers_by[key(p)] = timer
			function timer:set(timeout, elapsed) self.timeout, self.elapsed = timeout, elapsed end
			return timer
		end,
		is_protected = function(p) return protected[key(p)] == true end,
		record_protection_violation = function() violations = violations + 1 end,
		register_lbm = function(def) lbm_def = def end,
	}
	STAGES, SOIL_WET, SOIL_INTERVAL = 4, "soil_wet", 15
	CROP_PROGRESS_META, CROP_PLANTER_META = "progress", "planter"
	local short = {key = "carrot", stages = {"carrot_1", "carrot_2", "carrot_3", "carrot_4"},
		profile = {}}
	local tall = {key = "cane", stages = {"cane_1", "cane_2", "cane_3", "cane_4"},
		profile = {heights = {1, 1, 2, 2}}}
	crop_by_node = {}
	for _, row in ipairs({short, tall}) do
		for stage = 1, 4 do crop_by_node[row.stages[stage]] = {crop = row, stage = stage} end
	end
	function height_for(row, stage) return row.profile.heights and row.profile.heights[stage] or 1 end
	function copy_pos(p, level) return {x = p.x, y = p.y + level, z = p.z} end
	function owned_helper() return false end
	function helper_name(row, stage, level) return row.key .. "_" .. stage .. "_upper_" .. level end
	function stage_seconds() return 100 end
	function crop_lit() return true end
	function whole_crop_positions() return nil end
	local transition_crop, crop_timer = run(growth .. "\n" .. lbm ..
		"\nreturn transition_crop, crop_timer", "farming growth")

	local function plant(p, name, planter)
		nodes[key(p)] = name
		nodes[key({x = p.x, y = p.y - 1, z = p.z})] = SOIL_WET
		core.get_meta(p):set_string(CROP_PLANTER_META, planter)
	end
	-- A carrot whose planter lost the right: refused silently, retried.
	local root = {x = 0, y = 1, z = 0}
	plant(root, "carrot_2", "Ann")
	protected[key(root)] = true
	crop_timer(root, 100)
	eq(nodes[key(root)], "carrot_2", "F a protected carrot does not grow")
	eq(violations, 0, "F the timer's refusal records no violation")
	eq(timers_by[key(root)].elapsed, 100 - SOIL_INTERVAL, "F it retries on its timer")
	crop_timer(root, 100)
	eq(violations, 0, "F nor does the retry")
	-- The geometry LBM over a tall crop whose helper is protected.
	local cane = {x = 5, y = 1, z = 0}
	plant(cane, "cane_3", "Ann")
	protected[key({x = 5, y = 2, z = 0})] = true
	lbm_def.action(cane, {name = "cane_3"})
	eq(nodes["5,2,0"], nil, "F the LBM places no helper on protected ground")
	eq(violations, 0, "F the LBM's refusal records no violation")
	-- Unprotected: it grows as before.
	protected[key(root)] = nil
	crop_timer(root, 100)
	eq(nodes[key(root)], "carrot_3", "F an unprotected carrot grows")
	-- The player paths (harvest_crop, dig) call it without `silent`.
	protected[key(root)] = true
	check(not transition_crop(root, crop_by_node.carrot_3, 4, "Ann"), "F a player's refusal")
	eq(violations, 1, "F a player's refusal still records the violation")
	local source = read(FILE)
	check(source:find("transition_crop(root, state, next_stage, name)", 1, true) ~= nil,
		"F harvest_crop calls the recording path")
end

------------------------------------------------------------------------------
-- G. The weapon line's refresh (I2-01).
------------------------------------------------------------------------------
do
	local registered = {
		["test:sword"] = {description = "Sword", groups = {grug_equip_weapon = 1}},
		["test:dagger"] = {description = "Dagger", groups = {grug_equip_weapon = 1}},
		["test:ring"] = {description = "Ring", groups = {grug_trinket = 1}},
	}
	function ItemStack(item)
		local stack
		if type(item) == "table" then
			stack = {name = item.name, meta = new_meta(copy(item.meta.store))}
		else
			stack = {name = item or "", meta = new_meta()}
		end
		function stack:get_name() return self.name end
		function stack:is_empty() return self.name == "" end
		function stack:get_meta() return self.meta end
		function stack:get_definition() return registered[self.name] end
		function stack:get_tool_capabilities() return {damage_groups = {fleshy = 10}} end
		function stack:to_string()
			local keys = {}
			for k in pairs(self.meta.store) do keys[#keys + 1] = k end
			table.sort(keys)
			local parts = {self.name}
			for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. self.meta.store[k] end
			return table.concat(parts, "|")
		end
		function stack:equals(other) return self:to_string() == other:to_string() end
		return stack
	end
	local mods_loaded, level_hooks = {}, {}
	core = {
		get_us_time = function() return now * 1e6 end,
		register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
		log = function() end,
	}
	grug_core = {level_scale = function(level) return level / 10 end}
	equipment_change_callbacks = {}
	function grug_core.register_on_equipment_change(fn)
		equipment_change_callbacks[#equipment_change_callbacks + 1] = fn
	end
	run(cut("mods/CORE/grug_core/combat.lua",
		"\n(local notifying = %{%}.-\nfunction grug_core%.notify_equipment_change%(.-\nend)\n",
		"notify_equipment_change"), "notify_equipment_change")
	grug_inventory = {melee_list = function() return "grug_weapon" end}
	armor_cache, slot_cache = {}, {}
	run(cut("mods/PLAYER/grug_inventory/equipment.lua",
		"\n(function grug_inventory%.equipment_changed%(.-\nend)\n", "equipment_changed"),
		"equipment_changed")
	function grug_core.get_melee_weapon(player)
		local stack = player:get_inventory():get_stack("grug_weapon", 1)
		return not stack:is_empty() and stack or nil
	end
	grug_classes = {get_melee_bonus = function(player) return player._bonus end}
	grug_xp = {get_level = function(player) return player._level end,
		register_on_level_change = function(fn) level_hooks[#level_hooks + 1] = fn end}

	-- The first consumer counts the passes: full (reason nil) or narrow.
	local passes = {}
	grug_core.register_on_equipment_change(function(_, listname, reason)
		passes[#passes + 1] = {listname = listname, reason = reason}
	end)
	-- grug_abilities' consumer (the swing clock), cut out of its file.
	swing_progress, swing_input_latch = {}, {}
	grug_abilities = {swing_stats = function() return 10, 1.5 end}
	clamp_mana, hud_update, sync_descriptions, sync_skins, set_ready_reticle =
		function() end, function() end, function() end, function() end, function() end
	SLOT_OF_LIST = {grug_weapon = "weapon", grug_offhand = "offhand"}
	SKIN_IRRELEVANT_LIST = {grug_trinket1 = true, grug_trinket2 = true}
	run(cut("mods/PLAYER/grug_abilities/init.lua",
		"\n(grug_core%.register_on_equipment_change%(function.-\nend%))\n", "abilities consumer"),
		"abilities consumer")
	-- grug_gear: the weapon line and its two hooks (to the end of the file).
	grug_gear = {}
	run(cut("mods/ITEMS/grug_gear/init.lua",
		"\n(function grug_gear%.initialize_weapon_tooltip%(.*)$", "weapon line"), "grug_gear weapon line")
	grug_repair = {
		eligible = function() return false end,
		-- A broken stack's look: its image redrawn once.
		refresh_appearance = function(stack)
			local meta = stack:get_meta()
			if meta:get_string("broken") == "1" and meta:get_string("inventory_image") ~= "broken.png" then
				meta:set_string("inventory_image", "broken.png")
				return true
			end
			return false
		end,
	}
	for _, fn in ipairs(mods_loaded) do fn() end

	local lists = {main = {ItemStack("test:sword"), ItemStack("")},
		grug_weapon = {ItemStack("test:sword")}, grug_offhand = {ItemStack("")},
		grug_trinket1 = {ItemStack("")}}
	local inv, walks = {}, 0
	function inv:get_lists()
		walks = walks + 1
		local out = {}
		for name, list in pairs(lists) do
			out[name] = {}
			for index, stack in ipairs(list) do out[name][index] = ItemStack(stack) end
		end
		return out
	end
	function inv:get_stack(list, index) return ItemStack(lists[list][index]) end
	function inv:set_stack(list, index, stack) lists[list][index] = ItemStack(stack) end
	local ann = {_level = 10, _bonus = 0}
	function ann:get_player_name() return "ann" end
	function ann:get_inventory() return inv end
	function ann:is_player() return true end
	local function level_up(to)
		local from = ann._level
		ann._level = to
		for _, fn in ipairs(level_hooks) do fn(ann, from, to) end
	end
	local function count()
		local full, narrow = 0, 0
		for _, pass in ipairs(passes) do
			if pass.reason == "durability_metadata" then narrow = narrow + 1 else full = full + 1 end
		end
		return full, narrow
	end
	local function line(list, index)
		return lists[list][index or 1]:get_meta():get_string("description")
	end

	-- The join's full notification writes every line.
	grug_inventory.equipment_changed(ann)
	eq(line("grug_weapon"), "Sword\nEffective at level 10: 10 damage per swing",
		"G the line text is unchanged")
	eq(line("main"), "Sword\nEffective at level 10: 10 damage per swing", "G a carried weapon's line")

	-- A level-up mid-fight.
	now = 50
	swing_progress.ann = {weapon = ItemStack(lists.grug_weapon[1]), next_due = 777}
	local clock = swing_progress.ann
	passes, walks = {}, 0
	level_up(11)
	local full, narrow = count()
	print(("G counts level-up: full passes %d, narrow passes %d, inventory walks %d, next_due %s"):format(
		full, narrow, walks, tostring(swing_progress.ann.next_due)))
	eq(line("grug_weapon"), "Sword\nEffective at level 11: 11 damage per swing", "G level-up: the new line")
	eq(line("main"), "Sword\nEffective at level 11: 11 damage per swing", "G level-up: the carried line")
	eq(full, 0, "G level-up: no full consumer pass")
	eq(narrow, 1, "G level-up: one narrow notification")
	eq(passes[1] and passes[1].listname, "grug_weapon", "G level-up: it names the hand")
	check(swing_progress.ann == clock and clock.next_due == 777, "G level-up: the swing clock is kept")
	check(clock.weapon:equals(lists.grug_weapon[1]), "G level-up: the snapshot follows the new line")

	-- A Str ring equipped: the bonus rises, the hand's line follows.
	passes, walks = {}, 0
	ann._bonus = 2
	lists.grug_trinket1[1] = ItemStack("test:ring")
	grug_inventory.equipment_changed(ann, "grug_trinket1")
	full, narrow = count()
	print(("G counts Str equip: full passes %d, narrow passes %d, inventory walks %d, next_due %s"):format(
		full, narrow, walks, tostring(swing_progress.ann.next_due)))
	eq(line("grug_weapon"), "Sword\nEffective at level 11: 13 damage per swing", "G Str equip: the new line")
	eq(full, 1, "G Str equip: one full pass (the ring's own)")
	eq(narrow, 1, "G Str equip: the nested weapon line is the narrow pass")
	check(swing_progress.ann == clock and clock.next_due == 777, "G Str equip: the swing clock is kept")
	check(clock.weapon:equals(lists.grug_weapon[1]), "G Str equip: the snapshot follows")

	-- A look change (a broken weapon's image) stays a full change.
	passes = {}
	lists.grug_weapon[1]:get_meta():set_string("broken", "1")
	level_up(12)
	full, narrow = count()
	eq(full, 1, "G a look change: a full notification")
	eq(passes[1] and passes[1].listname, "grug_weapon", "G a look change: it names the hand")

	-- Both hands rewritten at once: one narrow notification for both.
	lists.grug_offhand[1] = ItemStack("test:dagger")
	grug_inventory.equipment_changed(ann, "grug_offhand")
	passes = {}
	level_up(13)
	full, narrow = count()
	eq(full, 0, "G both hands: no full pass")
	eq(narrow, 1, "G both hands: one narrow notification")
	eq(passes[1] and passes[1].listname, nil, "G both hands: no list named")
	check(swing_progress.ann.weapon:equals(lists.grug_weapon[1]), "G both hands: the snapshot follows")
end

------------------------------------------------------------------------------
-- H. The once-ever weapon hint (P3-06).
------------------------------------------------------------------------------
do
	local chats = {}
	local players = {}
	local registered = {
		["test:sword"] = {groups = {grug_equip_weapon = 1}},
		["test:bow"] = {groups = {grug_equip_weapon = 1}},
		["test:great_sword"] = {groups = {grug_equip_weapon = 1}, _grug_req_level = 30},
	}
	core = {
		registered_items = registered,
		get_player_by_name = function(name) return players[name] end,
		chat_send_player = function(name, text) chats[#chats + 1] = {name = name, text = text} end,
		colorize = function(_, text) return text end,
		get_item_group = function(name, group)
			local def = registered[name]
			return def and def.groups and def.groups[group] or 0
		end,
	}
	WEAPON_LIST, WEAPON_HINT_KEY = "grug_weapon", "grug_weapon_hint"
	slot_group = {grug_weapon = "grug_equip_weapon"}
	-- The hand rule: a Scout's weapon slot (Ranged) takes bows, a Warrior's swords.
	local TAKES = {scout = {["test:bow"] = true},
		warrior = {["test:sword"] = true, ["test:great_sword"] = true}}
	grug_classes = {get_class = function(player) return player.class end}
	grug_core = {
		get_player_level = function(player) return player.level end,
	}
	run(cut("mods/CORE/grug_core/combat.lua",
		"\n(function grug_core%.can_use_item_level%(.-\nend)\n", "can_use_item_level"),
		"can_use_item_level")
	grug_inventory = {
		carried_lists = function() return {"main"} end,
		hand_accepts = function(class_id, list, stack)
			return list == WEAPON_LIST and not stack:is_empty() and
				(TAKES[class_id] or {})[stack:get_name()] == true
		end,
		get_cosmetic_weapon = function(player) return player.slot end,
		-- Broken or another class's: no equipped weapon (equipment.lua).
		get_equipped_weapon = function(player)
			return player.slot and not player.slot_broken and player.slot or nil
		end,
		slot_label = function(class_id) return class_id == "scout" and "Ranged" or "Weapon" end,
	}
	local function stack(name)
		return {get_name = function() return name end, is_empty = function() return name == "" end}
	end
	local try = run(cut("mods/PLAYER/grug_inventory/equipment.lua",
		"\n(local function owns_slot_eligible_weapon%(.-\nlocal function try_weapon_hint%(.-\nend)\n",
		"weapon hint") .. "\nreturn try_weapon_hint", "weapon hint")
	local function make(name, class, level, carried, slot, broken)
		local list = {}
		for _, item in ipairs(carried) do list[#list + 1] = stack(item) end
		local player = {name = name, class = class, level = level, meta = new_meta(),
			slot = slot and stack(slot) or nil, slot_broken = broken}
		function player:get_meta() return self.meta end
		function player:get_inventory()
			return {get_list = function(_, listname) return listname == "main" and list or nil end}
		end
		players[name] = player
		return player
	end
	local function hinted(player)
		local before = #chats
		try(player.name)
		return #chats > before, player.meta:get_int(WEAPON_HINT_KEY) == 1
	end
	local sent, spent = hinted(make("scout", "scout", 20, {"test:sword"}))
	check(not sent and not spent, "H a Scout with only a sword: no hint, the flag kept")
	sent, spent = hinted(make("archer", "scout", 20, {"test:sword", "test:bow"}))
	check(sent and spent, "H a Scout with a bow: the hint, the flag spent")
	sent, spent = hinted(make("young", "warrior", 10, {"test:great_sword"}))
	check(not sent and not spent, "H a weapon above the level: no hint, the flag kept")
	sent, spent = hinted(make("broken", "warrior", 20, {"test:sword"}, "test:sword", true))
	check(not sent and not spent, "H a broken weapon in the slot: no hint, the flag kept")
	sent, spent = hinted(make("bare", "warrior", 20, {"test:sword"}))
	check(sent and spent, "H an empty slot and a usable sword: the hint, the flag spent")
	check(chats[#chats] and chats[#chats].text:find("into the Weapon slot", 1, true) ~= nil,
		"H the hint names the slot")
end

------------------------------------------------------------------------------
-- T. The Registrar's place in player texts (DD4-01).
------------------------------------------------------------------------------
do
	for _, path in ipairs({"mods/PLAYER/grug_expeditions/entry.lua", "mods/PLAYER/grug_mail/texts.lua"}) do
		local text = read(path)
		check(not text:find("waystone plaza", 1, true), "T " .. path .. " names no waystone plaza")
		check(text:find("great hall", 1, true) ~= nil, "T " .. path .. " names the great hall")
	end
end

if failures > 0 then
	error("R81 BUGS PORTABLE FAIL failures=" .. failures .. " checks=" .. checks)
end
print("R81 BUGS PORTABLE PASS checks=" .. checks)
