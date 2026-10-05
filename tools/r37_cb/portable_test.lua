-- Round 37 lane CB portable test (LuaJIT): the combat hot path of
-- round37-plan.md §4.1.
--
--   luajit tools/r37_cb/portable_test.lua [repo]
--
-- Loads the REAL grug_core combat.lua and environment_damage.lua, the REAL
-- grug_repair (service, presentation, runtime) and, cut out of their files,
-- the real equipment seam (grug_inventory.equipment_changed, the slot cache,
-- grug_quality's cache wrapper), every equipment-change consumer, the mount
-- and quest-hold hp handlers, apply_stats, the PvP melee handler with the
-- authoritative prepare/finish pair, and the knockback wrappers of
-- player_api and the dragon slam. Checks:
--   D  durability as its own cheap event (ruling 2.1.2): over a weapon's whole
--      life the tooltip line "Durability: N / M" is exact after every use and
--      written once per use, with no full tooltip rebuild; the armour,
--      affix and other slot caches stay, the worn slot's copy follows; the
--      stat, look, Character page, ability (mana, HUD, descriptions, skins),
--      gear and trinket consumers do not run, the swing clock's snapshot
--      follows the worn stack without restarting; armour worn by a taken hit
--      the same; the breaking use, a repair and a swap fire the full change
--      (every consumer, caches dropped, the full tooltip); a tool's dig
--      rewrites only its line (ITM-14);
--   K  the max-HP clamp is no damage (PLY-02, CMB-06): one predicate; an
--      engine clamp or apply_stats' join clamp leaves the rider mounted and
--      the use-hold running and keeps the shield's points; a punch, a fall
--      and a mod set_hp dismount, interrupt and are soaked; apply_stats
--      lowering hp_max through the engine clamp keeps the rider up;
--   F  the PvP Strike fallback (CMB-01): with Loose or a cast skill wielded
--      the claimed swing lands the transaction's scaled damage (with
--      melee_damage_add), settles one outgoing action (weapon wear), one
--      trinket proc and the rage; an unclaimed packet lands nothing;
--   N  knockback per source (ruling 2.1.3): refused punch, ally, unflagged
--      player, nested punch, PvP cast, arrow, nil hitter push 0; PvP melee
--      and a mob hit push; a rider and the dragon slam push 0;
--   R  the unreachable WP38 tool/fist accumulator, wear accumulator and
--      ordinary-input seam are gone (CMB-03), with no caller left.
-- Prints "R37 CB PORTABLE PASS checks=<n>" or the failures.

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
	assert(loadstring(block, "=" .. name))()
end
local function has_line(text, line)
	return ("\n" .. text .. "\n"):find("\n" .. line .. "\n", 1, true) ~= nil
end
local function copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = copy(v) end
	return out
end
table.copy = copy

------------------------------------------------------------------------------
-- Fake engine: item stacks, inventories, players, the hp-change chain.
------------------------------------------------------------------------------
local registered_items = {}
local description_writes = 0
local function new_meta(store)
	store = store or {}
	local meta = {store = store}
	function meta:get_string(k) return store[k] or "" end
	function meta:set_string(k, v)
		if k == "description" then description_writes = description_writes + 1 end
		v = tostring(v or "")
		store[k] = v ~= "" and v or nil
	end
	function meta:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function meta:set_int(k, v) store[k] = tostring(math.floor(v)) end
	function meta:set_tool_capabilities(caps) store._caps = caps end
	return meta
end
function ItemStack(item)
	local stack
	if type(item) == "table" then
		stack = {name = item.name, wear = item.wear, meta = new_meta(copy(item.meta.store))}
	else
		stack = {name = item or "", wear = 0, meta = new_meta()}
	end
	function stack:get_name() return self.name end
	function stack:is_empty() return self.name == "" end
	function stack:get_wear() return self.wear end
	function stack:set_wear(w) self.wear = w end
	function stack:get_meta() return self.meta end
	function stack:get_definition() return registered_items[self.name] or {} end
	function stack:get_tool_capabilities() return {} end
	function stack:to_string()
		local keys = {}
		for k in pairs(self.meta.store) do keys[#keys + 1] = k end
		table.sort(keys)
		local parts = {self.name, tostring(self.wear)}
		for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(self.meta.store[k]) end
		return table.concat(parts, "|")
	end
	function stack:equals(other) return self:to_string() == other:to_string() end
	return stack
end

local hp_modifiers, hp_loggers = {}, {}
local function engine_set_hp(player, target, reason)
	reason = reason or {}
	reason.type = reason.type or "set_hp"
	reason.from = reason.from or "mod"
	local change = math.floor(target) - player._hp
	if change == 0 then return end
	for _, fn in ipairs(hp_modifiers) do change = fn(player, change, reason) end
	for _, fn in ipairs(hp_loggers) do fn(player, change, reason) end
	player._hp = math.max(0, math.min(player._props.hp_max, player._hp + change))
end

local function new_player(name, faction)
	local lists = {}
	local inv = {}
	function inv:get_stack(list, i) return ItemStack(lists[list] and lists[list][i] or ItemStack("")) end
	function inv:set_stack(list, i, stack)
		lists[list] = lists[list] or {}
		lists[list][i] = ItemStack(stack)
	end
	function inv:get_list(list)
		local out = {}
		for i, s in ipairs(lists[list] or {}) do out[i] = ItemStack(s) end
		return out
	end
	function inv:get_size(list) return #(lists[list] or {}) end
	local p = {_name = name, _hp = 100, _props = {hp_max = 100}, _faction = faction,
		_wield = ItemStack(""), _attach = nil, _inv = inv, _lists = lists,
		_pos = {x = 0, y = 0, z = 0}}
	function p:is_player() return true end
	function p:get_player_name() return self._name end
	function p:get_inventory() return self._inv end
	function p:get_hp() return self._hp end
	function p:set_hp(hp, reason) engine_set_hp(self, hp, reason) end
	function p:get_properties() return copy(self._props) end
	function p:set_properties(t)
		for k, v in pairs(t) do self._props[k] = v end
		-- The engine's own clamp (read_object_properties): an engine set_hp.
		if t.hp_max and t.hp_max < self._hp then
			engine_set_hp(self, t.hp_max, {type = "set_hp", from = "engine"})
		end
	end
	function p:get_wielded_item() return ItemStack(self._wield) end
	function p:get_pos() return copy(self._pos) end
	function p:get_luaentity() return nil end
	function p:get_attach() return self._attach end
	function p:get_armor_groups() return {fleshy = 100} end
	return p
end

local plays = {}
grug_sounds = {play = function(event) plays[#plays + 1] = event; return true end}
local mods_loaded = {}
local creative = false
local us = 1000000
core = {
	registered_items = registered_items,
	get_us_time = function() return us end,
	get_item_group = function(name, group)
		local def = registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and obj:is_player() end,
	is_creative_enabled = function() return creative end,
	get_mod_storage = function()
		local store = {}
		return {get_string = function(_, k) return store[k] or "" end,
			set_string = function(_, k, v) store[k] = v end}
	end,
	register_on_player_hpchange = function(fn, modifier)
		if modifier then hp_modifiers[#hp_modifiers + 1] = fn else hp_loggers[#hp_loggers + 1] = fn end
	end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	override_item = function(name, redef)
		for k, v in pairs(redef) do registered_items[name][k] = v end
	end,
	serialize = function() return "caps" end,
	deserialize = function() return nil end,
	add_particlespawner = function() end,
	log = function() end,
	-- The builtin formula stand-in: 5 m/s for any damaging punch.
	calculate_knockback = function(_, _, _, _, _, _, damage)
		return (damage or 0) > 0 and 5 or 0
	end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
minetest = core
vector = {
	new = function(x, y, z) return {x = x, y = y, z = z} end,
	direction = function() return {x = 1, y = 0, z = 0} end,
	offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
}

grug_core = {}
assert(loadfile(ROOT .. "/mods/CORE/grug_core/combat.lua"))()
assert(loadfile(ROOT .. "/mods/CORE/grug_core/environment_damage.lua"))()
function grug_core.is_stunned() return false end
function grug_core.feed() return true end
eq(#hp_modifiers, 1, "setup: one central hp-change modifier")

------------------------------------------------------------------------------
-- D: durability as its own cheap event.
------------------------------------------------------------------------------
do
	-- The equipment seam, cut out of its files.
	grug_inventory = {BAG_COUNT = 0,
		content_list = function() return "bag" end,
		melee_list = function() return "grug_weapon" end,
		equipment_slots = {{list = "grug_weapon"}, {list = "grug_offhand"}, {list = "grug_head"},
			{list = "grug_chest"}, {list = "grug_legs"}, {list = "grug_feet"}},
	}
	local equipment = {grug_weapon = true, grug_offhand = true, grug_head = true,
		grug_chest = true, grug_legs = true, grug_feet = true}
	function grug_inventory.is_equipment_list(list) return equipment[list] == true end
	armor_cache, slot_cache, aggregate_cache = {}, {}, {}
	WEAPON_LIST, OFFHAND_LIST = "grug_weapon", "grug_offhand"
	run(cut("mods/PLAYER/grug_inventory/equipment.lua",
		"\n(function grug_inventory%.equipment_changed%(.-\nend)\n", "equipment_changed"),
		"equipment_changed")
	run(cut("mods/PLAYER/grug_inventory/equipment.lua",
		"\n(local function cached_slot_item%(.-\nend)\n", "cached_slot_item") ..
		"\n" .. cut("mods/PLAYER/grug_inventory/equipment.lua",
		"\n(function grug_inventory%.get_melee_weapon%(.-\nend)\n", "get_melee_weapon"),
		"slot cache")
	run(cut("mods/ITEMS/grug_quality/init.lua",
		"\n(local original_equipment_changed = .-\ngrug_inventory%.invalidate_armor = grug_inventory%.equipment_changed)\n",
		"quality wrapper"), "quality wrapper")
	function grug_core.get_melee_weapon(player) return grug_inventory.get_melee_weapon(player) end

	-- grug_gear / grug_items stand-ins: the full tooltip builder writes the
	-- description from scratch (counted), the way initialize_weapon_tooltip
	-- regenerates it.
	local full_builds = 0
	grug_gear = {
		reference_purchase_price = function() return 100 end,
		usable_by = function() return "Usable by: Warrior" end,
		broken_image = function(image) return image .. "^broken" end,
		can_equip_weapon = function() return true end,
		initialize_weapon_tooltip = function(stack)
			full_builds = full_builds + 1
			stack:get_meta():set_string("description", "Sword\nRequires level 1\n" ..
				"Usable by: Warrior\n" .. grug_repair.durability_line(stack) ..
				"\nEffective at level 1: 12 damage per swing")
		end,
	}
	grug_items = {regenerate_description = function(stack) full_builds = full_builds + 1 end}
	grug_repair = {}
	for _, file in ipairs({"service", "presentation", "runtime"}) do
		assert(loadfile(ROOT .. "/mods/ITEMS/grug_repair/" .. file .. ".lua"))()
	end
	registered_items["test:sword"] = {description = "Sword", type = "craft",
		groups = {grug_equip_weapon = 1}, _grug_tier = 1}
	registered_items["test:chest"] = {description = "Chest", type = "craft",
		groups = {grug_equip_chest = 1}, _grug_tier = 1}
	registered_items["test:pick"] = {description = "Pick", type = "tool",
		groups = {pickaxe = 1}, _grug_tool_uses = 3}
	for _, fn in ipairs(mods_loaded) do fn() end

	-- Every consumer of the seam, cut out of its file, with counters.
	local calls = {}
	local function count(key) return function() calls[key] = (calls[key] or 0) + 1 end end
	local function reset() calls = {} end
	grug_classes = {apply_stats = count("apply_stats")}
	grug_visuals = {apply = count("visuals")}
	grug_inventory.refresh = count("character_page")
	IRRELEVANT_LIST = {grug_trinket1 = true, grug_trinket2 = true}
	TRINKET_LISTS = {"grug_trinket1", "grug_trinket2"}
	rebuild = count("trinkets")
	refresh_weapon_descriptions = count("gear")
	clamp_mana, hud_update = count("mana"), count("hud")
	sync_descriptions, sync_skins = count("descriptions"), count("skins")
	set_ready_reticle = function() end
	SLOT_OF_LIST = {grug_weapon = "weapon", grug_offhand = "offhand"}
	SKIN_IRRELEVANT_LIST = {grug_head = true, grug_chest = true, grug_legs = true,
		grug_feet = true, grug_trinket1 = true, grug_trinket2 = true}
	swing_progress, swing_input_latch = {}, {}
	grug_abilities = {swing_stats = function() return 10, 1.0 end}
	local consumer = "\n(grug_core%.register_on_equipment_change%(function.-\nend%))\n"
	for _, file in ipairs({"mods/PLAYER/grug_classes/stats.lua",
			"mods/PLAYER/grug_visuals/apply.lua", "mods/PLAYER/grug_inventory/pages.lua",
			"mods/PLAYER/grug_trinkets/init.lua", "mods/PLAYER/grug_abilities/init.lua"}) do
		run(cut(file, consumer, "equipment consumer"), file)
	end
	run(cut("mods/ITEMS/grug_gear/init.lua",
		"\n\t(grug_core%.register_on_equipment_change%(function.-\n\tend%))\n", "gear consumer"),
		"grug_gear consumer")
	local heavy = {"apply_stats", "visuals", "character_page", "trinkets", "gear",
		"mana", "hud", "descriptions", "skins"}
	local function heavy_calls()
		local n = 0
		for _, key in ipairs(heavy) do n = n + (calls[key] or 0) end
		return n
	end

	local ann = new_player("ann", "accord")
	local inv = ann:get_inventory()
	local sword = ItemStack("test:sword")
	grug_repair.refresh_stack(sword, ann) -- as a pickup or purchase initializes it
	inv:set_stack("grug_weapon", 1, sword)
	inv:set_stack("grug_chest", 1, ItemStack(""))
	grug_inventory.equipment_changed(ann)
	local weapon = grug_core.get_melee_weapon(ann)
	swing_progress.ann = {weapon = ItemStack(weapon), next_due = 777}
	local clock = swing_progress.ann
	reset()
	full_builds, description_writes = 0, 0
	armor_cache.ann, aggregate_cache.ann = 42, {crit_percent = 1}
	slot_cache.ann.grug_chest = false

	local M = grug_repair.maximum_durability(sword)
	eq(M, 1000, "D a T1 weapon lasts 1000 uses")
	local action, exact, once = 0, true, true
	local function act()
		action = action + 1
		local before = description_writes
		grug_core.run_settled_outgoing_action(ann, {id = "a" .. action}, "damage")
		return description_writes - before
	end
	for k = 1, M - 1 do
		local writes = act()
		local desc = inv:get_stack("grug_weapon", 1):get_meta():get_string("description")
		local want = ("Durability: %d / %d"):format(M - k, M)
		if not has_line(desc, want) then
			if exact then print("  at use " .. k .. ": " .. desc:gsub("\n", " | ")) end
			exact = false
		end
		if writes ~= 1 then once = false end
	end
	check(exact, "D the durability line is exact after every one of 999 uses")
	check(once, "D the tooltip is written once per use")
	eq(full_builds, 0, "D no full tooltip rebuild on pure wear")
	local desc = inv:get_stack("grug_weapon", 1):get_meta():get_string("description")
	check(desc:find("Effective at level 1: 12 damage per swing", 1, true) ~= nil and
		desc:find("Usable by: Warrior", 1, true) ~= nil, "D the other tooltip lines stay")
	eq(heavy_calls(), 0, "D no stat, look, page, ability, gear or trinket consumer ran on pure wear")
	eq(armor_cache.ann, 42, "D the armour total stays cached on pure wear")
	check(aggregate_cache.ann ~= nil, "D the affix totals stay cached on pure wear")
	eq(slot_cache.ann and slot_cache.ann.grug_chest, false, "D the other slots stay cached")
	eq(grug_core.get_melee_weapon(ann):get_wear(), inv:get_stack("grug_weapon", 1):get_wear(),
		"D the worn slot's cached copy follows the stack")
	check(swing_progress.ann == clock and clock.next_due == 777,
		"D the swing clock is not restarted by wear")
	check(clock.weapon:equals(inv:get_stack("grug_weapon", 1)),
		"D the swing clock's snapshot is the worn stack")
	eq(#plays, 0, "D no break cue while the weapon holds")

	-- The breaking use: the full change.
	act()
	local broken = inv:get_stack("grug_weapon", 1)
	eq(broken:get_wear(), 65535, "D the 1000th use breaks the weapon")
	check(broken:get_meta():get_string("description"):find("Durability: 0 / 1000 — Broken", 1, true) ~= nil,
		"D the broken line")
	eq(full_builds, 1, "D the break rebuilds the full tooltip (look and line)")
	for _, key in ipairs(heavy) do
		if key ~= "trinkets" and key ~= "gear" then
			eq(calls[key], 1, "D the break runs consumer " .. key)
		end
	end
	eq(calls.gear, 1, "D the break refreshes the weapon descriptions")
	eq(armor_cache.ann, nil, "D the break drops the armour total")
	eq(aggregate_cache.ann, nil, "D the break drops the affix totals")
	eq(slot_cache.ann and slot_cache.ann.grug_chest, nil, "D the break drops the slot cache")
	check(swing_progress.ann ~= clock, "D the break restarts the swing clock (bare hand)")
	eq(plays[#plays], "gear_break", "D the break cue")

	-- A repair: the full change and the full tooltip.
	grug_money = {take_with_inventory = function(player, _, changes)
		for _, row in ipairs(changes) do player:get_inventory():set_stack(row.list, row.index, row.replacement) end
		return true
	end, format = function(n) return tostring(n) end}
	grug_repair.register_provider("test", function() return true end)
	reset(); full_builds = 0
	armor_cache.ann, aggregate_cache.ann = 42, {}
	local quote = assert(grug_repair.quote(ann, {kind = "test"}))
	check(grug_repair.apply(ann, quote), "D the repair applies")
	eq(inv:get_stack("grug_weapon", 1):get_wear(), 0, "D the repair restores the weapon")
	check(has_line(inv:get_stack("grug_weapon", 1):get_meta():get_string("description"),
		"Durability: 1000 / 1000"), "D the repaired line")
	eq(full_builds, 1, "D the repair rebuilds the full tooltip")
	eq(calls.apply_stats, 1, "D the repair is a full change (stats)")
	eq(calls.character_page, 1, "D the repair is a full change (Character page)")
	eq(armor_cache.ann, nil, "D the repair drops the caches")

	-- A swap: the full change.
	reset()
	armor_cache.ann = 42
	inv:set_stack("grug_weapon", 1, ItemStack("test:sword"))
	grug_inventory.equipment_changed(ann, "grug_weapon")
	eq(calls.apply_stats, 1, "D a swap runs the stats")
	eq(calls.visuals, 1, "D a swap runs the look")
	eq(calls.skins, 1, "D a swap syncs the skins")
	eq(armor_cache.ann, nil, "D a swap drops the armour total")

	-- Armour worn by a taken hit (the settled-incoming hook).
	local chest = ItemStack("test:chest")
	grug_repair.refresh_stack(chest, ann)
	inv:set_stack("grug_chest", 1, chest)
	grug_inventory.equipment_changed(ann, "grug_chest")
	reset(); full_builds = 0
	armor_cache.ann, aggregate_cache.ann = 42, {}
	ann._hp = 100
	for _ = 1, 5 do engine_set_hp(ann, ann._hp - 1, {type = "punch"}) end
	local worn = inv:get_stack("grug_chest", 1)
	check(has_line(worn:get_meta():get_string("description"), "Durability: 995 / 1000"),
		"D five taken hits: the chest's line is exact")
	eq(full_builds, 0, "D armour wear rebuilds no tooltip")
	eq(heavy_calls(), 0, "D armour wear runs no stat, look, page or ability consumer")
	eq(armor_cache.ann, 42, "D armour wear keeps the armour total")
	check(aggregate_cache.ann ~= nil, "D armour wear keeps the affix totals")

	-- A tool's dig (ITM-14): only the line, the break in full.
	local pick = ItemStack("test:pick")
	grug_repair.refresh_stack(pick, ann)
	full_builds = 0
	local after_use = registered_items["test:pick"].after_use
	pick = after_use(pick, ann, nil, {wear = 100})
	check(has_line(pick:get_meta():get_string("description"), "Durability: 2 / 3"),
		"D a dig rewrites the pick's line")
	eq(full_builds, 0, "D a dig rebuilds no tooltip")
	pick = after_use(pick, ann, nil, {wear = 100})
	pick = after_use(pick, ann, nil, {wear = 100})
	eq(pick:get_wear(), 65535, "D the third dig breaks the pick")
	eq(full_builds, 1, "D the pick's break rebuilds the tooltip")

	-- The predicate the consumers rely on is the one reason in the source.
	for _, file in ipairs({"mods/PLAYER/grug_classes/stats.lua", "mods/PLAYER/grug_visuals/apply.lua",
			"mods/PLAYER/grug_inventory/pages.lua", "mods/PLAYER/grug_abilities/init.lua",
			"mods/ITEMS/grug_gear/init.lua"}) do
		check(cut(file, consumer:gsub("^\n", "\n\t?"), "consumer"):find('reason == "durability_metadata"', 1, true) ~= nil,
			"D " .. file .. " returns on pure wear")
	end
	_G.grug_classes, _G.grug_visuals, _G.grug_abilities = nil, nil, nil
end

------------------------------------------------------------------------------
-- K: the max-HP clamp is no damage.
------------------------------------------------------------------------------
do
	local clamp = {type = "set_hp", from = "engine"}
	check(grug_core.is_max_hp_clamp(clamp), "K the engine's set_hp is the clamp")
	check(grug_core.is_max_hp_clamp({type = "set_hp", from = "mod",
		custom_type = grug_core.MAX_HP_CLAMP_CUSTOM_TYPE}), "K apply_stats' marked clamp")
	for _, reason in ipairs({{type = "set_hp", from = "mod"}, {type = "punch", from = "engine"},
			{type = "fall", from = "engine"}, {type = "node_damage", from = "engine"},
			{type = "set_hp", from = "mod", custom_type = grug_core.DRAGON_WRATH_CUSTOM_TYPE}}) do
		check(not grug_core.is_max_hp_clamp(reason), "K not a clamp: " .. reason.type .. "/" ..
			reason.from .. "/" .. tostring(reason.custom_type))
	end
	check(not grug_core.is_max_hp_clamp(nil), "K no reason is no clamp")

	-- The mount and quest-hold handlers, cut out of their files.
	local saved_modifiers, saved_loggers = hp_modifiers, hp_loggers
	hp_modifiers, hp_loggers = saved_modifiers, {}
	active, holds = {}, {}
	local dismounts, stops = 0, 0
	grug_mounts = {dismount = function(player) dismounts = dismounts + 1; active[player:get_player_name()] = nil end}
	stop = function(name) stops = stops + 1; holds[name] = nil end
	run(cut("mods/PLAYER/grug_mounts/entity.lua", "\n(%-%- Any damage dismounts.-\nend, false%))\n",
		"mount hp handler"), "mount hp handler")
	run(cut("mods/PLAYER/grug_quests/use.lua", "\n(%-%- Any damage interrupts a hold.-\nend%))\n",
		"use-hold hp handler"), "use-hold hp handler")
	eq(#hp_loggers, 2, "K both handlers registered")
	local function ride(p) active[p:get_player_name()] = {mode = "flight"}; holds[p:get_player_name()] = {} end
	local cid = new_player("cid", "accord")
	local function hit(reason, amount)
		dismounts, stops = 0, 0
		ride(cid)
		cid._hp = 100
		engine_set_hp(cid, 100 - (amount or 30), reason)
	end
	hit({type = "set_hp", from = "engine"})
	eq(dismounts, 0, "K the engine clamp leaves the flying rider mounted")
	eq(stops, 0, "K the engine clamp keeps the use-hold")
	hit({type = "set_hp", custom_type = grug_core.MAX_HP_CLAMP_CUSTOM_TYPE})
	eq(dismounts + stops, 0, "K apply_stats' clamp neither dismounts nor interrupts")
	for _, reason in ipairs({{type = "punch"}, {type = "fall", from = "engine"}, {type = "set_hp"}}) do
		hit(reason)
		eq(dismounts, 1, "K real damage (" .. reason.type .. ") dismounts")
		eq(stops, 1, "K real damage (" .. reason.type .. ") interrupts the hold")
	end

	-- The shield (CMB-06): the real modifier.
	cid._hp = 100
	grug_core.add_absorb(cid, "test_shield", 40, 30)
	eq(grug_core.get_absorb(cid), 40, "K a 40-point shield")
	local before_plays = #plays
	hit({type = "set_hp", from = "engine"})
	eq(cid._hp, 70, "K the clamp lowers HP in full")
	eq(grug_core.get_absorb(cid), 40, "K the clamp eats no shield points")
	eq(#plays, before_plays, "K no shield cue on the clamp")
	hit({type = "punch"})
	eq(grug_core.get_absorb(cid), 10, "K a real hit is soaked")
	eq(cid._hp, 100, "K the soaked hit costs no HP")

	-- apply_stats: an expiring buff lowers hp_max; the engine clamps.
	grug_classes = {}
	local max_hp = 80
	grug_classes.get_max_hp = function() return max_hp end
	run(cut("mods/PLAYER/grug_classes/stats.lua", "\n(function grug_classes%.apply_stats%(.-\nend)\n",
		"apply_stats"), "apply_stats")
	cid._hp, cid._props.hp_max = 100, 100
	ride(cid); dismounts, stops = 0, 0
	grug_classes.apply_stats(cid)
	eq(cid._props.hp_max, 80, "K apply_stats lowers hp_max")
	eq(cid._hp, 80, "K HP follows the clamp")
	eq(dismounts + stops, 0, "K an expiring buff keeps the rider and the hold")
	-- A join: the stored HP loads raw above the unchanged maximum.
	cid._hp, cid._props.hp_max, max_hp = 90, 80, 80
	ride(cid); dismounts, stops = 0, 0
	grug_classes.apply_stats(cid)
	eq(cid._hp, 80, "K the join clamp")
	eq(dismounts + stops, 0, "K the join clamp is no damage")
	hp_loggers = saved_loggers
	_G.grug_classes, _G.grug_mounts = nil, nil
end

------------------------------------------------------------------------------
-- F: the PvP Strike fallback (CMB-01).
------------------------------------------------------------------------------
do
	local settled, procs, rage = 0, 0, 0
	grug_core.register_on_settled_outgoing_action(function(_, _, kind)
		if kind == "damage" then settled = settled + 1 end
	end)
	grug_core.trinket_weapon_hit = function() procs = procs + 1 end
	grug_abilities = {add_rage = function(_, amount) rage = rage + amount end,
		set_target = function() end, reset_charge = function() end}
	spend = function() return true end
	swing_rage = function() return 12 end
	-- Before CMB-01 the handler re-derived the swing from the wielded item:
	-- Loose or a cast skill selects nothing.
	selected_swing_def = function() return nil end
	grug_factions = {
		same_faction = function(a, b) return a._faction == b._faction end,
		hostile = function(a, b) return a._faction ~= b._faction end,
	}
	grug_pvp = {can_harm = function() return true end}
	grug_core.get_melee_bonus = function() return 2 end
	run(cut("mods/PLAYER/grug_abilities/init.lua",
		"\n(local function prepare_authoritative_swing%(.-\ngrug_core%.register_native_melee_handler%(prepare_authoritative_swing,\n\tfinish_authoritative_swing%))\n",
		"prepare/finish"), "prepare/finish")
	local punch_handlers = {}
	local saved = core.register_on_punchplayer
	rawset(core, "register_on_punchplayer", function(fn) punch_handlers[#punch_handlers + 1] = fn end)
	run(cut("mods/PLAYER/grug_abilities/init.lua",
		"\n(core%.register_on_punchplayer%(function%(player, hitter.-\nend%))\n", "PvP handler"),
		"PvP handler")
	rawset(core, "register_on_punchplayer", saved)
	local handler = assert(punch_handlers[1], "PvP handler registered")

	local scout = new_player("scout", "accord")
	local enemy = new_player("enemy", "throng")
	scout._wield = ItemStack("grug_abilities:loose")
	-- attempt_swing's transaction: weapon 10, Strength 2, Fine Edge +3,
	-- scaled once to 15 (level scalar 1).
	local transaction = {weapon_damage = 10, fpi = 1.0, melee_bonus = 2,
		raw_damage = 15, scaled_damage = 15, threat_mult = 1}
	local caps = {full_punch_interval = 1.0, damage_groups = {fleshy = 10}}
	enemy._hp = 100
	local token = grug_core.begin_authoritative_swing(scout, enemy, transaction)
	local handled = handler(enemy, scout, 1.0, caps, nil, 10)
	grug_core.end_authoritative_swing(token)
	check(handled == true, "F the claimed fallback swing is handled")
	eq(100 - enemy._hp, 15, "F it lands the transaction's 15 (melee_damage_add included)")
	eq(settled, 1, "F one settled outgoing action: the weapon wears")
	eq(procs, 1, "F the trinket proc (Battlebeat) fires")
	eq(rage, 12, "F the swing's rage")
	-- An unclaimed packet (the native input with Loose) lands nothing.
	enemy._hp, settled = 100, 0
	check(handler(enemy, scout, 1.0, caps, nil, 10) == true, "F a native packet is suppressed")
	eq(enemy._hp, 100, "F a native packet deals nothing")
	eq(settled, 0, "F a native packet wears nothing")
	_G.grug_abilities, _G.grug_factions, _G.grug_pvp = nil, nil, nil
end

------------------------------------------------------------------------------
-- N: knockback per source.
------------------------------------------------------------------------------
do
	-- The two existing wrappers stack on ours, as at runtime.
	player_attached = {}
	run(cut("mods/BASE/player_api/api.lua",
		"\n(local old_calculate_knockback = minetest%.calculate_knockback\n.-\nend)\n",
		"player_api knockback"), "player_api knockback")
	slam_hit = false
	run(cut("mods/ENTITIES/grug_mobs/boss_dragons.lua",
		"\n(local engine_knockback = core%.calculate_knockback\nif engine_knockback then.-\n\tend\nend)\n",
		"slam knockback"), "slam knockback")
	local harm = true
	grug_core.pvp_can_harm = function() return harm end
	local a, b = new_player("a", "accord"), new_player("b", "throng")
	local function push(player, hitter)
		return core.calculate_knockback(player, hitter, 1, {}, {x = 1, y = 0, z = 0}, 1.5, 6)
	end
	local function mob(fields)
		local ent = fields
		return {is_player = function() return false end, get_luaentity = function() return ent end}
	end
	eq(push(b, a), 0, "N a refused punch (no swing) pushes 0")
	local token = grug_core.begin_authoritative_swing(a, b, {})
	eq(push(b, a), 5, "N PvP melee (the authoritative swing) pushes")
	harm = false
	eq(push(b, a), 0, "N an ally or an unflagged player is not pushed")
	harm = true
	grug_core.claim_authoritative_swing(a, b)
	eq(push(b, a), 0, "N a nested punch after the claim pushes 0")
	grug_core.end_authoritative_swing(token)
	token = grug_core.begin_authoritative_swing(a, new_player("c", "throng"), {})
	eq(push(b, a), 0, "N a swing at another target does not push this one")
	grug_core.end_authoritative_swing(token)
	grug_core.in_ability_punch = true
	eq(push(b, a), 0, "N a PvP cast or arrow (ability punch) pushes 0")
	eq(push(b, mob({_cmi_is_mob = true})), 0, "N ability damage never pushes")
	grug_core.in_ability_punch = false
	eq(push(b, mob({_cmi_is_mob = true})), 5, "N a mob hit pushes")
	eq(push(b, mob({name = "grug_mobs:arrow"})), 0, "N a mob arrow pushes 0")
	eq(push(b, nil), 0, "N a punch without hitter pushes 0")
	player_attached.b = true
	eq(push(b, mob({_cmi_is_mob = true})), 0, "N a rider is not pushed")
	player_attached.b = nil
	slam_hit = true
	eq(push(b, mob({_cmi_is_mob = true})), 0, "N the dragon slam pushes 0")
	slam_hit = false
end

------------------------------------------------------------------------------
-- R: the WP38 tool/fist machinery is gone (CMB-03).
------------------------------------------------------------------------------
do
	for _, name in ipairs({"prepare_accumulated_melee", "commit_accumulated_melee",
			"apply_accumulated_melee", "reset_accumulated_melee", "invalidate_melee_target",
			"register_ordinary_melee_input_handler", "handle_ordinary_melee_input",
			"melee_wear_due", "forget_melee_wear"}) do
		eq(grug_core[name], nil, "R grug_core." .. name .. " is gone")
	end
	for _, file in ipairs({"mods/ENTITIES/mobs/api.lua", "mods/PLAYER/grug_abilities/init.lua",
			"mods/CORE/grug_core/combat.lua", "mods/ENTITIES/grug_mobs/init.lua"}) do
		local text = read(file)
		for _, word in ipairs({"accumulated_melee", "melee_wear", "ordinary_melee",
				"invalidate_melee_target", "grug_fraction"}) do
			check(not text:find(word, 1, true), "R no " .. word .. " left in " .. file)
		end
	end
end

if failures > 0 then
	print(("R37 CB PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R37 CB PORTABLE PASS checks=%d"):format(checks))
