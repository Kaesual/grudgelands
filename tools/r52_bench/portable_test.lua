-- Round 52 lane CORE-A portable test (LuaJIT; round52-class-plan.md §3
-- CORE-A, D1, D2, D8). Loads the REAL grug_abilities/init.lua with its whole
-- dofile chain (strike_delay.lua, cooldown_hud.lua, kits.lua and the class
-- files, scout.lua, input.lua) in a sandbox over a small fake engine, and the
-- REAL grug_core/status.lua for Mend. Checks:
--   N  normalize_kit, is_unlocked and unlocked_ids give exactly what main's
--      code gave (a frozen copy of 5e54f1cc's three functions, below) for
--      every shipped kit (warrior, mage, priest, scout, classless), with no
--      talent, each talent-gated skill's talent and all of them, over an
--      inventory holding every skill on both hotbar layouts, in a bag, as a
--      second copy and in a list skills may not live in;
--   T  the transformation (D8) with probe definitions only this test
--      registers: a class basic attack replaces Strike for its class only; a
--      talent-gated transformation replaces its base on main and on the
--      hidden layout at the same index and swaps back on a refund; a copy the
--      player already holds wins over a swapped one; a stack of another class
--      still goes; transform and base share one cooldown key for the
--      cooldown, the cast interval, the charge and the overlay; the
--      registration refuses a bad transformation;
--   C  the action clock (D2): every shipped skill gets the defaults
--      (occupied_cast 0, a cast's occupied_swing "weapon", none on a swing);
--      with them a cast blocks no cast and pushes the next swing by one weapon
--      interval, and a swing blocks no cast; a probe cast's occupied_cast
--      refuses other casts ("You are still busy.") through the one
--      cast_refusal the input gate and try_cast share, its occupied_swing
--      sets the swing delay, and a probe swing's occupied_cast holds casts;
--   M  Mend on set_status (D1): the real status pass ticks it 3, 6, 9 and 12 s
--      after the cast (4 heals of the cast's snapshot), an offline healer's
--      ticks heal as the target, a re-cast restarts the phase, death and
--      leave end it; Mend's own globalstep is gone.
--
-- Usage (repo root): luajit tools/r52_bench/portable_test.lua [repo]
-- Prints "R52 CORE-A PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local MOD = ROOT .. "/mods/PLAYER/grug_abilities/"
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

------------------------------------------------------------------------------
-- The fake engine.
------------------------------------------------------------------------------
local now_us = 1e9
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end

-- Item stacks: name, count and a metadata map; to_string covers both, so a
-- refreshed stack compares unequal only when something really changed.
local Stack = {}
Stack.__index = Stack
local function ItemStack(spec)
	if type(spec) == "table" and getmetatable(spec) == Stack then
		local copy = setmetatable({name = spec.name, count = spec.count, fields = {}}, Stack)
		for k, v in pairs(spec.fields) do copy.fields[k] = v end
		return copy
	end
	local name = type(spec) == "string" and spec:match("^(%S*)") or ""
	return setmetatable({name = name, count = name == "" and 0 or 1, fields = {}}, Stack)
end
function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:get_count() return self.count end
function Stack:equals(other) return self:to_string() == other:to_string() end
function Stack:to_string()
	local keys = {}
	for k in pairs(self.fields) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {self.name}
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(self.fields[k]) end
	return table.concat(parts, "|")
end
function Stack:get_meta()
	local fields = self.fields
	return {
		get_string = function(_, k) return fields[k] or "" end,
		set_string = function(_, k, v) fields[k] = v ~= "" and v or nil end,
		get_int = function(_, k) return tonumber(fields[k]) or 0 end,
		set_int = function(_, k, v) fields[k] = tostring(v) end,
		set_tool_capabilities = function(_, caps)
			fields.caps = caps and tostring(caps.full_punch_interval) or nil
		end,
	}
end
function Stack:get_tool_capabilities() return {full_punch_interval = 1} end

-- Inventories: lists in a fixed order, so the old and the new code visit
-- them alike (normalize_kit walks pairs(get_lists())).
local LISTS = {"main", "grug_hotbar_store", "grug_bag1", "craft", "grug_weapon"}
local function new_inventory()
	local inv = {lists = {}}
	for _, l in ipairs(LISTS) do
		local list = {}
		for i = 1, 32 do list[i] = ItemStack("") end
		inv.lists[l] = list
	end
	function inv:get_size(l) return self.lists[l] and #self.lists[l] or 0 end
	function inv:get_stack(l, i) return ItemStack(self.lists[l][i]) end
	function inv:set_stack(l, i, s) self.lists[l][i] = ItemStack(s) end
	function inv:get_list(l)
		local out = {}
		for i, s in ipairs(self.lists[l] or {}) do out[i] = ItemStack(s) end
		return out
	end
	function inv:get_lists()
		local out = {}
		for _, l in ipairs(LISTS) do out[l] = self:get_list(l) end
		return out
	end
	function inv:contains_item(l, name)
		for _, s in ipairs(self.lists[l] or {}) do
			if s.name == name then return true end
		end
		return false
	end
	return inv
end
local function row(inv, l)
	local out = {}
	for i, s in ipairs(inv.lists[l]) do out[i] = s.name:gsub("^grug_abilities:", "") end
	return table.concat(out, ",")
end

-- Players: class, talent ranks, hp, an inventory.
local players = {}
local function new_player(name, class, ranks)
	local p = {name = name, class = class, ranks = ranks or {}, hp = 100,
		inv = new_inventory(), wield = 1}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:set_hp(v) self.hp = v end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:get_wield_index() return self.wield end
	function p:get_meta() return ItemStack("x"):get_meta() end
	function p:get_properties() return {hp_max = 100} end
	-- The cooldown overlay's HUD (cooldown_hud.lua).
	p.huds = {}
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add(def)
		self.huds[#self.huds + 1] = def
		return #self.huds
	end
	function p:hud_change(id, stat, value) self.huds[id][stat] = value end
	function p:hud_remove(id) self.huds[id] = false end
	players[name] = p
	return p
end

------------------------------------------------------------------------------
-- The sandbox: the real init.lua and its dofile chain.
------------------------------------------------------------------------------
local tools, input_api = {}, nil
local registered_classes = {warrior = {name = "Warrior"}, mage = {name = "Mage"},
	priest = {name = "Priest"}, scout = {name = "Scout"}}
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
end
local env
-- Engine callbacks by kind, so a test can fire death, respawn and leave.
local callbacks = {}
local function capture(kind)
	return function(fn)
		callbacks[kind] = callbacks[kind] or {}
		table.insert(callbacks[kind], fn)
	end
end
local function fire(kind, ...)
	for _, fn in ipairs(callbacks[kind] or {}) do fn(...) end
end
local WINDOW = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
local fake_core = with_any({
	register_on_dieplayer = capture("die"),
	register_on_respawnplayer = capture("respawn"),
	register_on_leaveplayer = capture("leave"),
	register_globalstep = capture("globalstep"),
	get_player_window_information = function() return WINDOW end,
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_abilities" end,
	get_current_modname = function() return "grug_abilities" end,
	get_us_time = function() return now_us end,
	global_exists = function(n) return n == "grug_inventory" end,
	register_tool = function(name, def) tools[name] = def end,
	registered_items = {},
	get_item_group = function(name, group)
		return (group == "grug_ability" and name:find("^grug_abilities:")) and 1 or 0
	end,
	get_player_by_name = function(name) return players[name] end,
	log = function() end,
})
local fake_grug_core = with_any({
	get_melee_weapon = function() return ItemStack("") end,
	is_stunned = function() return false end,
	-- Read by the unlocked skills' descriptions (update_stack_description).
	scale_player_damage = false,
})
local fake_classes = with_any({
	registered_classes = registered_classes,
	registered_talents = {mend = {name = "Mend"}},
	get_class = function(p) return p.class end,
	get_class_def = function(p) return registered_classes[p.class] end,
	talent_rank = function(p, id) return p.ranks[id] or 0 end,
	get_talent_bonus = function() return 0 end,
	get_melee_bonus = function() return 0 end,
	get_race_perk = function() return nil end,
	get_max_mana = function() return 1000 end,
	talent_window_active = function() return false end,
})
local fake_inventory = with_any({
	HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
	content_list = function(i) return "grug_bag" .. i end,
	get_cosmetic_hand = function() return nil end,
	hand_list = function() return "grug_weapon" end,
	melee_list = function() return "grug_weapon" end,
	equipment_changed = function() end,
})
env = setmetatable({
	core = fake_core, ItemStack = ItemStack,
	grug_core = fake_grug_core, grug_classes = fake_classes,
	grug_inventory = fake_inventory,
	vector = with_any({}),
}, {__index = function(_, k)
	local g = rawget(_G, k)
	if g ~= nil and k ~= "core" and k ~= "minetest" then return g end
	return any()
end})
env.dofile = function(path)
	local chunk = setfenv(assert(loadfile(path)), env)
	local result = chunk()
	if path:find("/input%.lua$") then
		-- Keep the api table init.lua hands the input machine: its
		-- cast_refusal is the one the input gate and try_cast share.
		local real = result
		return function(api)
			input_api = api
			return real(api)
		end
	end
	return result
end
env._G = env
setfenv(assert(loadfile(MOD .. "init.lua")), env)()
local G = env.grug_abilities
check(G and G.registered.strike and G.registered.mend and G.registered.loose,
	"the real init.lua loads with its kits")
check(input_api and input_api.cast_refusal and input_api.delay_strike,
	"the input api carries cast_refusal and delay_strike")

------------------------------------------------------------------------------
-- N: normalize_kit, is_unlocked and unlocked_ids as on main.
------------------------------------------------------------------------------
-- Main's (5e54f1cc) three functions, frozen: the oracle. Their only inputs
-- are the registry, the class, the talent ranks and the list policy, so the
-- copy runs on the same registry and inventory as the real code.
local old = {}
do
	local function in_kit(def, class)
		return def.universal or def.class == class
	end
	function old.is_unlocked(player, ability_id)
		local def = G.registered[ability_id]
		if not def or not in_kit(def, fake_classes.get_class(player)) then
			return false
		end
		if def.talent_gated then
			return fake_classes.talent_rank(player, def.talent or def.id) > 0
		end
		return true
	end
	function old.unlocked_ids(player)
		local result = {}
		local function append(def)
			if old.is_unlocked(player, def.id) then
				result[#result + 1] = def.id
			end
		end
		for _, def in ipairs(G.universal) do append(def) end
		for _, def in ipairs(G.by_class[fake_classes.get_class(player)] or {}) do
			append(def)
		end
		return result
	end
	-- representation_lists() of init.lua, for this engine.
	local allowed = {main = true, grug_bag1 = true, grug_hotbar_store = true}
	function old.normalize_kit(player)
		local inv = player:get_inventory()
		local hidden = "grug_hotbar_store"
		local seen = {shown = {}, hidden = {}}
		for listname, list in pairs(inv:get_lists()) do
			local have = listname == hidden and seen.hidden or seen.shown
			for i, stack in ipairs(list) do
				local def = G.registered[(stack:get_name():match("^grug_abilities:(.+)$"))]
				if def then
					if not allowed[listname] or
							not old.is_unlocked(player, def.id) or have[def.id] then
						inv:set_stack(listname, i, ItemStack(""))
					else
						have[def.id] = true
						local fresh = G.stack_for(player, def.id)
						if fresh and fresh:to_string() ~= stack:to_string() then
							inv:set_stack(listname, i, fresh)
						end
					end
				end
			end
		end
	end
end

local ids = {}
for id in pairs(G.registered) do ids[#ids + 1] = id end
table.sort(ids)
local gated = {} -- class -> talent ids of its talent-gated skills
for _, id in ipairs(ids) do
	local def = G.registered[id]
	if def.talent_gated then
		gated[def.class] = gated[def.class] or {}
		table.insert(gated[def.class], def.talent or def.id)
	end
end
eq(#ids, 22, "N every shipped skill is registered: Strike, 5 + 5 + 5 + 6 class skills")

-- Every skill on A and (reversed) on B, Strike twice on A, some in a bag,
-- one in a list skills may not live in (craft) and one in an equipment list.
local function fill(p)
	local inv = p.inv
	for _, l in ipairs(LISTS) do
		for i = 1, 32 do inv.lists[l][i] = ItemStack("") end
	end
	for i, id in ipairs(ids) do
		inv.lists.main[i] = ItemStack("grug_abilities:" .. id)
		inv.lists.grug_hotbar_store[#ids + 1 - i] = ItemStack("grug_abilities:" .. id)
	end
	inv.lists.main[#ids + 1] = ItemStack("grug_abilities:strike")
	inv.lists.main[#ids + 2] = ItemStack("default:apple")
	inv.lists.grug_bag1[1] = ItemStack("grug_abilities:mend")
	inv.lists.grug_bag1[2] = ItemStack("grug_abilities:loose")
	inv.lists.grug_bag1[3] = ItemStack("grug_abilities:charge")
	inv.lists.craft[1] = ItemStack("grug_abilities:strike")
	inv.lists.grug_weapon[1] = ItemStack("grug_abilities:smite")
end
local function snapshot(p)
	local parts = {}
	for _, l in ipairs(LISTS) do
		local list = {}
		for i, s in ipairs(p.inv.lists[l]) do list[i] = s:to_string() end
		parts[#parts + 1] = l .. ":" .. table.concat(list, ",")
	end
	return table.concat(parts, "\n")
end

local scenarios = 0
for _, class in ipairs({"warrior", "mage", "priest", "scout", ""}) do
	local states = {{}}
	local all = {}
	for _, talent in ipairs(gated[class] or {}) do
		states[#states + 1] = {[talent] = 1}
		all[talent] = 2
	end
	states[#states + 1] = all
	-- Another class's talents change nothing for this one.
	for other, talents in pairs(gated) do
		if other ~= class then
			local foreign = {}
			for _, t in ipairs(talents) do foreign[t] = 1 end
			states[#states + 1] = foreign
		end
	end
	for s, ranks in ipairs(states) do
		local label = ("N %s state %d"):format(class == "" and "classless" or class, s)
		local p_new = new_player("n_new", class ~= "" and class or nil, ranks)
		local p_old = new_player("n_old", class ~= "" and class or nil, ranks)
		local same = true
		for _, id in ipairs(ids) do
			if G.is_unlocked(p_new, id) ~= old.is_unlocked(p_old, id) then
				same = false
				print("  is_unlocked differs: " .. id)
			end
		end
		check(same, label .. ": is_unlocked as on main for every skill")
		eq(table.concat(G.unlocked_ids(p_new), ","), table.concat(old.unlocked_ids(p_old), ","),
			label .. ": unlocked_ids as on main")
		fill(p_new)
		fill(p_old)
		G.normalize_kit(p_new)
		old.normalize_kit(p_old)
		local got, want = snapshot(p_new), snapshot(p_old)
		check(got == want, label .. ": normalize_kit leaves the inventory as main did")
		if got ~= want then print(got .. "\n--- main:\n" .. want) end
		-- A second pass changes nothing (idempotent, as before).
		G.normalize_kit(p_new)
		eq(snapshot(p_new), got, label .. ": a second normalize_kit changes nothing")
		scenarios = scenarios + 1
	end
end
check(scenarios >= 20, "N scenarios run: " .. scenarios)

------------------------------------------------------------------------------
-- T: the transformation (D8), with probe definitions only this test has.
------------------------------------------------------------------------------
local cast_log = {}
local function probe(def)
	def.name = def.name or def.id
	def.description = def.description or def.id
	def.color = def.color or "#ffffff"
	def.target_kind = def.target_kind or "hostile"
	if def.kind == "cast" then
		def.cooldown = def.cooldown or 0
		def.cast = def.cast or function(user)
			cast_log[#cast_log + 1] = def.id
			return true
		end
	end
	G.register_ability(def)
	return G.registered[def.id]
end
local function refused(def, label)
	local ok = pcall(probe, def)
	check(not ok and G.registered[def.id] == nil, "T refused at registration: " .. label)
end
refused({id = "probe_bad1", class = "mage", kind = "cast", talent_gated = true,
	transforms = "no_such_skill"}, "an unknown base")
refused({id = "probe_bad2", class = "warrior", kind = "cast", talent_gated = true,
	transforms = "fireball"}, "another class's base")
refused({id = "probe_bad3", class = "warrior", kind = "cast", transforms = "taunt"},
	"a class skill replaced without a talent")
refused({id = "probe_bad4", class = "mage", kind = "cast", cooldown_key = "x"},
	"a declared cooldown key")
refused({id = "probe_bad5", class = "warrior", kind = "swing", occupied_swing = 1},
	"occupied_swing on a swing")
refused({id = "probe_bad6", class = "mage", kind = "cast", occupied_cast = -1},
	"a negative occupied_cast")

-- The Mage's basic attack in place of Strike, its talent transformation, a
-- Warrior's talent swing in place of Strike and a talent transformation of
-- Taunt (one cooldown key with it).
local spark = probe({id = "probe_spark", class = "mage", kind = "cast",
	transforms = "strike", cast_interval = 1})
local cold = probe({id = "probe_cold_spark", class = "mage", kind = "cast",
	talent_gated = true, transforms = "probe_spark", cast_interval = 1})
local retort = probe({id = "probe_retort", class = "warrior", kind = "swing",
	talent_gated = true, transforms = "strike", charge = 6})
local bellow = probe({id = "probe_bellow", class = "warrior", kind = "cast",
	talent_gated = true, transforms = "taunt"})
eq(spark.cooldown_key .. "," .. cold.cooldown_key .. "," .. retort.cooldown_key ..
	"," .. bellow.cooldown_key, "strike,strike,strike,taunt",
	"T a transformation shares its base's cooldown key, down the chain")
eq(G.registered.taunt.cooldown_key, "taunt", "T a shipped skill's key is its id")

do
	local mage = new_player("t_mage", "mage", {})
	local warrior = new_player("t_warrior", "warrior", {})
	check(not G.is_unlocked(mage, "strike") and G.is_unlocked(mage, "probe_spark") and
		not G.is_unlocked(mage, "probe_cold_spark"),
		"T the Mage's basic attack replaces Strike for the Mage")
	check(G.is_unlocked(warrior, "strike") and not G.is_unlocked(warrior, "probe_spark"),
		"T ...and only for the Mage")
	eq(table.concat(G.unlocked_ids(mage), ","), "fireball,ice_nova,blink,probe_spark",
		"T the Mage's skill list: no Strike, the basic attack in its place in the kit")
	mage.ranks.probe_cold_spark = 1
	eq(table.concat(G.unlocked_ids(mage), ","), "fireball,ice_nova,blink,probe_cold_spark",
		"T a ranked transformation replaces its base in the list")
	mage.ranks.probe_cold_spark = nil

	-- In place on A and on the hidden layout B, both ways.
	local inv = mage.inv
	for _, l in ipairs(LISTS) do for i = 1, 32 do inv.lists[l][i] = ItemStack("") end end
	inv.lists.main[1] = ItemStack("grug_abilities:strike")
	inv.lists.main[2] = ItemStack("grug_abilities:fireball")
	inv.lists.grug_hotbar_store[3] = ItemStack("grug_abilities:strike")
	inv.lists.grug_bag1[4] = ItemStack("grug_abilities:strike")
	G.normalize_kit(mage)
	eq(row(inv, "main"):sub(1, 22), "probe_spark,fireball,,", "T class pick: Strike becomes the basic attack in its slot on A")
	eq(inv.lists.grug_hotbar_store[3].name, "grug_abilities:probe_spark", "T ...and on B, same index")
	eq(inv.lists.grug_bag1[4].name, "", "T ...a stray copy in a bag goes as a second copy")
	mage.ranks.probe_cold_spark = 1
	G.normalize_kit(mage)
	eq(inv.lists.main[1].name .. "|" .. inv.lists.grug_hotbar_store[3].name,
		"grug_abilities:probe_cold_spark|grug_abilities:probe_cold_spark",
		"T a talent rank swaps the base in place on A and B")
	eq(inv.lists.main[2].name, "grug_abilities:fireball", "T ...the other skills stay")
	mage.ranks.probe_cold_spark = nil
	G.normalize_kit(mage)
	eq(inv.lists.main[1].name .. "|" .. inv.lists.grug_hotbar_store[3].name,
		"grug_abilities:probe_spark|grug_abilities:probe_spark",
		"T a refund swaps it back in place")
	check(inv.lists.main[1]:get_meta():get_string("grug_skin") ~= "",
		"T the swapped stack is a fresh, skinned representation")

	-- A copy the player holds wins; the swapped stack goes as a second copy,
	-- whichever list the pass visits first.
	mage.ranks.probe_cold_spark = 1
	inv.lists.main[1] = ItemStack("grug_abilities:strike")
	inv.lists.main[5] = ItemStack("grug_abilities:probe_cold_spark")
	inv.lists.grug_hotbar_store[1] = ItemStack("grug_abilities:probe_cold_spark")
	inv.lists.grug_hotbar_store[3] = ItemStack("grug_abilities:probe_spark")
	G.normalize_kit(mage)
	eq(inv.lists.main[1].name .. "|" .. inv.lists.main[5].name,
		"|grug_abilities:probe_cold_spark", "T A: the held copy stays, the swapped base goes")
	eq(inv.lists.grug_hotbar_store[1].name .. "|" .. inv.lists.grug_hotbar_store[3].name,
		"grug_abilities:probe_cold_spark|", "T B: the same, per layout")

	-- Another class's stacks still go; the Warrior's own swing swaps Strike.
	inv = warrior.inv
	for _, l in ipairs(LISTS) do for i = 1, 32 do inv.lists[l][i] = ItemStack("") end end
	inv.lists.main[1] = ItemStack("grug_abilities:strike")
	inv.lists.main[2] = ItemStack("grug_abilities:probe_cold_spark")
	inv.lists.main[3] = ItemStack("grug_abilities:taunt")
	G.normalize_kit(warrior)
	eq(row(inv, "main"):sub(1, 14), "strike,,taunt,", "T a Mage stack on a Warrior goes, as before")
	warrior.ranks.probe_retort, warrior.ranks.probe_bellow = 1, 1
	G.normalize_kit(warrior)
	eq(row(inv, "main"):sub(1, 27), "probe_retort,,probe_bellow,",
		"T a talent swing replaces Strike, a talent cast Taunt, in place")
	warrior.ranks.probe_retort, warrior.ranks.probe_bellow = nil, nil
	G.normalize_kit(warrior)
	eq(row(inv, "main"):sub(1, 14), "strike,,taunt,", "T a respec swaps both back")

	-- One cooldown key: the cooldown, the overlay, the cast interval, the charge.
	warrior.ranks.probe_bellow = 1
	inv.lists.main[3] = ItemStack("grug_abilities:probe_bellow")
	G.arm_cooldown(warrior, G.registered.taunt, 8)
	check(not G.ready(warrior, "probe_bellow") and not G.ready(warrior, "taunt"),
		"T Taunt's cooldown holds its transformation too (no reset when bought mid-cooldown)")
	eq(input_api.cast_refusal(warrior, bellow), "probe_bellow is not ready.",
		"T ...and the cast gate says so")
	local st = G.cooldown_hud.state("t_warrior")
	check(st and st.timers.taunt and st.slots[3] == "taunt" and st.shown[3] ~= nil,
		"T the overlay covers the transformation's slot with the shared timer")
	G.clear_cooldown(warrior, "probe_bellow")
	check(G.ready(warrior, "taunt"), "T clearing the transformation's cooldown clears the key")
	G.arm_cooldown(warrior, bellow, 8)
	check(not G.ready(warrior, "taunt") and st.timers.taunt and st.timers.probe_bellow == nil,
		"T the transformation's own cooldown runs under the base's key")
	G.clear_cooldown(warrior, "taunt")
	G.reset_charge(warrior, retort)
	check(not G.charge_ready(warrior, retort) and st.timers.strike ~= nil,
		"T a charge runs under the key too")
	now_us = now_us + 7e6
	check(G.charge_ready(warrior, retort), "T ...and ends")

	mage.ranks.probe_cold_spark = 1
	check(G.try_cast(mage, cold, nil, function() end), "T the transformation casts")
	mage.ranks.probe_cold_spark = nil
	eq(input_api.cast_refusal(mage, spark), "probe_spark cast interval is not ready.",
		"T ...and its cast interval holds the base after a respec (one key)")
	now_us = now_us + 1e6
	eq(input_api.cast_refusal(mage, spark), nil, "T ...for the interval only")
end

------------------------------------------------------------------------------
-- C: the action clock (D2).
------------------------------------------------------------------------------
do
	local defaults = true
	for _, id in ipairs(ids) do
		local def = G.registered[id]
		if def.occupied_cast ~= 0 or (def.kind == "cast" and def.occupied_swing ~= "weapon") or
				(def.kind == "swing" and def.occupied_swing ~= nil) then
			defaults = false
			print("  not the default clock: " .. id)
		end
	end
	check(defaults, "C every shipped skill has the default clock (0; a cast's swing: \"weapon\")")

	-- The swing path under a small fake: a 1.0 s weapon, one hostile in the
	-- ray that takes the punch.
	local mob = {get_pos = function() return {x = 0, y = 0, z = 2} end,
		is_player = function() return false end, punches = 0}
	function mob.punch(self) self.punches = self.punches + 1 end
	G.swing_stats = function() return 5, 1.0 end
	G.base_swing_interval = function() return 1.0 end
	G.valid_target = function() return true end
	fake_grug_core.combat_ray = function()
		return {status = "target", reason = "target", target = mob}
	end
	fake_grug_core.scale_player_damage = function(_, _, d) return d end
	fake_grug_core.begin_authoritative_swing = function() return "token" end
	fake_grug_core.end_authoritative_swing = function() end
	local strike = G.registered.strike
	local p = new_player("c_mage", "mage", {})
	local function swings(def) return input_api.swing(p, def or strike) == true end
	local function wait(s) now_us = now_us + s * 1e6 end
	local bolt = probe({id = "probe_bolt", class = "mage", kind = "cast"})
	local lance = probe({id = "probe_lance", class = "mage", kind = "cast",
		occupied_cast = 1.5, occupied_swing = 0.5})
	local bash = probe({id = "probe_bash", class = "mage", kind = "swing", occupied_cast = 0.8})

	check(swings(), "C a swing lands")
	check(not swings(), "C ...the next waits for the weapon")
	eq(input_api.cast_refusal(p, bolt), nil, "C a swing (Strike, default 0) blocks no cast")
	check(G.try_cast(p, bolt, nil, function() end), "C a default cast casts")
	eq(input_api.cast_refusal(p, bolt), nil, "C ...and blocks no other cast")
	wait(2)
	input_api.delay_strike(p, bolt)
	wait(0.9)
	check(not swings(), "C a default cast pushes the next swing by one weapon interval")
	wait(0.1)
	check(swings(), "C ...and no longer")
	wait(2)
	input_api.delay_strike(p)
	wait(0.9)
	check(not swings(), "C the bow release (no def) pushes by one weapon interval too")
	wait(0.1)
	check(swings(), "C ...and no longer")

	-- A skill that occupies: the one cast_refusal of the input gate and try_cast.
	wait(2)
	local refusals = {}
	check(G.try_cast(p, lance, nil, function(m) refusals[#refusals + 1] = m end),
		"C an occupying cast casts")
	input_api.delay_strike(p, lance)
	eq(input_api.cast_refusal(p, bolt), "You are still busy.", "C cast -> cast: refused while occupied")
	cast_log = {}
	check(not G.try_cast(p, bolt, nil, function(m) refusals[#refusals + 1] = m end) and
		#cast_log == 0 and refusals[1] == "You are still busy.",
		"C ...try_cast refuses with the same words before casting")
	wait(0.4)
	check(not swings(), "C cast -> swing: occupied_swing 0.5 s holds the swing")
	wait(0.1)
	check(swings(), "C ...then it swings (shorter than the weapon interval)")
	wait(0.9)
	eq(input_api.cast_refusal(p, bolt), "You are still busy.", "C ...casts still wait at 1.4 s")
	wait(0.1)
	eq(input_api.cast_refusal(p, bolt), nil, "C ...and go at 1.5 s")
	-- Swing -> cast.
	wait(2)
	check(swings(bash), "C an occupying swing skill swings")
	eq(input_api.cast_refusal(p, bolt), "You are still busy.", "C swing -> cast: refused")
	wait(0.8)
	eq(input_api.cast_refusal(p, bolt), nil, "C ...for occupied_cast only")
	-- The clock is per player and ends with a death, a respawn and a leave.
	check(G.try_cast(p, lance, nil, function() end), "C occupied again")
	fire("die", p)
	eq(input_api.cast_refusal(p, bolt), nil, "C death clears the clock")
	check(G.try_cast(p, lance, nil, function() end), "C occupied again")
	fire("leave", p)
	eq(input_api.cast_refusal(p, bolt), nil, "C leaving clears the clock")
	fake_grug_core.scale_player_damage = false
end

------------------------------------------------------------------------------
-- M: Mend on set_status (D1), through the REAL grug_core/status.lua.
------------------------------------------------------------------------------
do
	local s_callbacks = {}
	local function s_capture(kind)
		return function(fn) s_callbacks[kind] = fn end
	end
	local online = {}
	local status_env = setmetatable({
		grug_core = fake_grug_core,
		core = with_any({
			get_us_time = function() return now_us end,
			register_globalstep = s_capture("globalstep"),
			register_on_dieplayer = s_capture("die"),
			register_on_leaveplayer = s_capture("leave"),
			get_connected_players = function() return online end,
		}),
	}, {__index = _G})
	setfenv(assert(loadfile(ROOT .. "/mods/CORE/grug_core/status_icons.lua")), status_env)()
	fake_grug_core.hud_layout = {STATUS_ICON = 64, STATUS_LIMIT = 8,
		anchors = {status_row = {position = {x = 0, y = 0}}},
		status_slot = function() return {x = 0, y = 0}, {x = 0, y = 0} end}
	setfenv(assert(loadfile(ROOT .. "/mods/CORE/grug_core/status.lua")), status_env)()
	check(fake_grug_core.set_status ~= nil and s_callbacks.globalstep ~= nil,
		"M the real status.lua loads")

	local heals = {}
	fake_grug_core.heal_player = function(healer, target, amount, opts)
		heals[#heals + 1] = {healer = healer:get_player_name(), target = target:get_player_name(),
			amount = amount, at = now_us, action = opts and opts.action_id}
	end
	local healer, target = new_player("m_priest", "priest", {mend = 1}), new_player("m_ally", "priest")
	online = {healer, target}
	local mend = G.registered.mend
	local values = mend.values
	mend.values = function() return {heal = 7} end
	G.resolve_friendly_target = function() return target end
	local cast_at
	local function cast()
		cast_at = now_us
		return mend.cast(healer, nil, mend)
	end
	-- The status pass every server step of 0.1 s.
	local function run(seconds)
		for _ = 1, math.floor(seconds * 10 + 0.5) do
			now_us = now_us + 1e5
			s_callbacks.globalstep(0.1)
		end
	end
	local function ticks()
		local out = {}
		for i, h in ipairs(heals) do
			out[i] = ("%.1f"):format((h.at - cast_at) / 1e6)
		end
		return table.concat(out, ",")
	end
	check(cast(), "M Mend casts")
	local rec = fake_grug_core.get_status(target, "mend")
	check(rec and rec.interval == 3 and rec.label == "Mend" and rec.kind == "buff" and
		(rec.expiry_us - cast_at) == 12e6, "M one status record: 12 s, a 3 s interval, the icon's id")
	run(14)
	eq(ticks(), "3.0,6.0,9.0,12.0", "M four ticks, 3 s after the cast and every 3 s (D1's phase)")
	local same = #heals == 4
	for _, h in ipairs(heals) do
		same = same and h.amount == 7 and h.healer == "m_priest" and h.target == "m_ally" and
			h.action == heals[1].action
	end
	check(same, "M each tick heals the cast's amount, from the healer, one action id")
	eq(fake_grug_core.get_status(target, "mend"), nil, "M the status ends after the last tick")

	-- An offline healer: the target heals itself (today's rule).
	heals = {}
	check(cast(), "M cast again")
	players.m_priest = nil
	run(3)
	players.m_priest = healer
	eq(#heals == 1 and heals[1].healer, "m_ally", "M an offline healer's tick heals as the target")
	-- A re-cast restarts the phase: next tick 3 s after it, four in all.
	heals = {}
	run(1)
	check(cast(), "M re-cast mid-way")
	run(13)
	eq(ticks(), "3.0,6.0,9.0,12.0", "M a re-cast restarts duration and phase")
	-- Death and leave end it.
	heals = {}
	check(cast(), "M cast before a death")
	run(3.5)
	target.hp = 0
	s_callbacks.die(target)
	target.hp = 100
	run(10)
	eq(#heals, 1, "M death ends Mend (the status system clears it)")
	heals = {}
	check(cast(), "M cast before a leave")
	s_callbacks.leave(target)
	run(13)
	eq(#heals, 0, "M leaving ends Mend")
	mend.values = values

	local src = assert(io.open(MOD .. "kits_priest.lua")):read("*a")
	check(not src:find("register_globalstep", 1, true) and not src:find("mends", 1, true),
		"M Mend's own globalstep and its mends table are gone")
end

if failures > 0 then
	error(("R52 CORE-A PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R52 CORE-A PORTABLE PASS checks=%d"):format(checks))
