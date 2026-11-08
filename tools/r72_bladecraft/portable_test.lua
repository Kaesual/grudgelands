-- Round 72 lane BLADECRAFT portable test (LuaJIT; round72-plan.md §2.6, §4
-- BLADECRAFT, §6): the hand shows the weapon of Bladecraft's last real attack.
--
--   luajit tools/r72_bladecraft/portable_test.lua [repo]
--
-- The REAL grug_abilities/init.lua with its kits and input.lua in a sandbox
-- (tools/r53_scout's pattern) over a fake engine, and the REAL display state
-- of grug_visuals (cut from apply.lua: show_shot, hand_slot and its leave
-- hook). The third-person hand and the back card through the real apply.lua
-- are tools/r55_game's section S.
--   L1 a shot that flew shows the bow: both hotbar layouts re-skinned (the
--      held stack through set_wielded_item with skip_anim, the other copy
--      through set_stack), the Veil bow overlay, apply called once; a second
--      shot writes nothing;
--   L2 a refused shot (no target, no arrow, no bow) switches nothing;
--   L3 an air click (and so digging: no hostile under the crosshair) swings
--      nothing and switches nothing;
--   L4 a swing at a foe shows the blade again;
--   L5 only Bladecraft switches: True Draw's held fallback swings Strike and
--      switches nothing; the Strike stack is never rewritten by a switch;
--   L6 damage and both clocks unchanged: `slot` stays melee, the swing's raw
--      damage is the plain 1 M with the bow shown, the shot's is Loose's;
--      the swing after a shot still waits for the blade's interval;
--   L7 the state outlives hotbar switches and has no timeout, but not a
--      relog: after the leave hook the skin pass shows the blade;
--   L8 the bow changed while the bow shows: the equipment hook re-skins
--      Bladecraft from the Ranged slot (sync_skins follows the shown slot).
-- Prints "R72 BLADECRAFT PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) <=
		1e-9 * math.max(1, math.abs(expected)),
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

local ABIL = "mods/PLAYER/grug_abilities/"

------------------------------------------------------------------------------
-- The sandbox (tools/r53_scout's, trimmed): vector, stacks, players.
------------------------------------------------------------------------------
local vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x or 0, y = y or 0, z = z or 0}
end
vector.copy = vector.new
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(a, s) return vector.new(a.x * s, a.y * s, a.z * s) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.normalize(v)
	local l = vector.length(v)
	return l > 0 and vector.multiply(v, 1 / l) or vector.new(0, 0, 0)
end
function vector.direction(a, b) return vector.normalize(vector.subtract(b, a)) end
function vector.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

local now_us = 1e9
local function wait(s) now_us = now_us + s * 1e6 end
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
end

local registered_items = {
	["grug_gear:bow_wood"] = {inventory_image = "grug_gear_bow_wood.png",
		groups = {grug_equip_weapon = 1, bow = 1}},
	["grug_gear:bow_ash"] = {inventory_image = "grug_gear_bow_ash.png",
		groups = {grug_equip_weapon = 1, bow = 1}},
	["grug_gear:sword_iron"] = {inventory_image = "grug_gear_sword_iron.png",
		groups = {grug_equip_weapon = 1, sword = 1}},
}

local Stack = {}
Stack.__index = Stack
local function ItemStack(spec)
	if type(spec) == "table" and getmetatable(spec) == Stack then
		local copy = setmetatable({name = spec.name, count = spec.count, fields = {},
			caps = spec.caps}, Stack)
		for k, v in pairs(spec.fields) do copy.fields[k] = v end
		return copy
	end
	local name = type(spec) == "string" and spec:match("^(%S*)") or ""
	return setmetatable({name = name, count = name == "" and 0 or 1, fields = {}}, Stack)
end
function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:get_count() return self.count end
function Stack:get_wear() return 0 end
function Stack:get_definition() return registered_items[self.name] or {} end
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
		set_tool_capabilities = function() end,
	}
end
function Stack:get_tool_capabilities() return self.caps or {full_punch_interval = 1} end
local function weapon(name, damage, interval)
	local s = ItemStack(name)
	s.caps = {full_punch_interval = interval or 1, damage_groups = {fleshy = damage}}
	return s
end

-- Every inventory write, by list and kind: set_stack, and set_wielded_item
-- with its skip_anim flag.
local writes = {}
local function reset_writes() writes = {} end

local LISTS = {"main", "grug_hotbar_store", "grug_bag1", "craft", "grug_weapon"}
local function new_inventory()
	local inv = {lists = {}}
	for _, l in ipairs(LISTS) do
		local list = {}
		for i = 1, (l == "main" or l == "grug_hotbar_store") and 8 or 4 do list[i] = ItemStack("") end
		inv.lists[l] = list
	end
	function inv:get_size(l) return self.lists[l] and #self.lists[l] or 0 end
	function inv:get_stack(l, i) return ItemStack(self.lists[l][i]) end
	function inv:set_stack(l, i, s)
		writes[#writes + 1] = {kind = "set_stack", list = l, index = i, name = s:get_name()}
		self.lists[l][i] = ItemStack(s)
	end
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

-- An own-level weapon (grug_core.baseline_weapon_damage) and the Scout's
-- natural Dexterity (10 + 2 per level after the first).
local function own_weapon_damage(level) return math.floor(4 + 0.35 * level + 0.5) end
local function natural_dex(level) return 10 + 2 * (level - 1) end

local players = {}
local function new_player(name, opts)
	opts = opts or {}
	local level = opts.level or 30
	local p = {name = name, class = "scout", ranks = {}, hp = 100,
		level = level, dex = natural_dex(level), faction = "accord",
		inv = new_inventory(), wield = 1, ammo = opts.ammo or 200,
		pos = vector.new(0, 0, 0), yaw = 0, controls = {},
		bow = weapon("grug_gear:bow_wood", own_weapon_damage(level), 1),
		melee = weapon("grug_gear:sword_iron", own_weapon_damage(level), 1),
		meta = {}}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return vector.new(self.pos) end
	function p:get_look_dir() return {x = -math.sin(self.yaw), y = 0, z = math.cos(self.yaw)} end
	function p:get_look_horizontal() return self.yaw end
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:set_wielded_item(s, skip_anim)
		writes[#writes + 1] = {kind = "set_wielded_item", list = "main", index = self.wield,
			name = s:get_name(), skip_anim = skip_anim}
		self.inv.lists.main[self.wield] = ItemStack(s)
		return true
	end
	function p:get_wield_index() return self.wield end
	function p:get_wield_list() return "main" end
	function p:get_player_control() return self.controls end
	function p:get_meta()
		local m = self.meta
		return {get_string = function(_, k) return m[k] or "" end,
			set_string = function(_, k, v) m[k] = v ~= "" and v or nil end,
			get_int = function(_, k) return tonumber(m[k]) or 0 end,
			set_int = function(_, k, v) m[k] = tostring(v) end}
	end
	function p:get_properties() return {hp_max = 100} end
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add() return 1 end
	function p:hud_change() end
	function p:hud_remove() end
	players[name] = p
	return p
end

local function new_mob(name, pos)
	local ent = {name = "test:" .. name, health = 20, _cmi_is_mob = true, temp = {}}
	local m = {kind = "mob", name = name, pos = pos, ent = ent, yaw = 0, accept = true}
	function m:get_pos() return vector.new(self.pos) end
	function m:is_player() return false end
	function m:get_luaentity() return self.ent end
	function m:get_yaw() return self.yaw end
	function m:get_hp() return self.ent.health end
	return m
end

------------------------------------------------------------------------------
-- The fake engine and the recorders.
------------------------------------------------------------------------------
local log
local function reset_log() log = {launches = {}, swings = {}, damage = {}} end
reset_log()
local scene = {aim = nil}

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

-- Every shipped Veil and Quarry strip the skins may name.
local STRIPS = {"grug_abilities_fx_veil_bow.png", "grug_abilities_fx_veil_sword.png",
	"grug_abilities_fx_quarry_bow.png", "grug_abilities_fx_quarry_sword.png"}
local fake_core = with_any({
	register_on_dieplayer = capture("die"),
	register_on_leaveplayer = capture("leave"),
	register_on_joinplayer = capture("join"),
	register_globalstep = capture("globalstep"),
	register_on_mods_loaded = capture("mods_loaded"),
	register_on_player_hpchange = capture("hpchange"),
	get_modpath = function(mod)
		if mod == "grug_classes" then return ROOT .. "/mods/PLAYER/grug_classes" end
		return ROOT .. "/mods/PLAYER/grug_abilities"
	end,
	get_current_modname = function() return "grug_abilities" end,
	get_dir_list = function() return STRIPS end,
	get_us_time = function() return now_us end,
	global_exists = function(n) return n == "grug_inventory" end,
	register_tool = function(name, def) registered_items[name] = def end,
	registered_items = registered_items,
	registered_nodes = {},
	registered_entities = {["__builtin:item"] = {on_punch = function() end}},
	get_item_group = function(name, group)
		return (group == "grug_ability" and name:find("^grug_abilities:")) and 1 or 0
	end,
	get_player_by_name = function(name) return players[name] end,
	get_connected_players = function() return {} end,
	check_player_privs = function() return true end,
	get_node_or_nil = function() return {name = "air"} end,
	is_protected = function() return false end,
	yaw_to_dir = function(yaw) return {x = -math.sin(yaw), y = 0, z = math.cos(yaw)} end,
	log = function() end,
})

local fake_grug_core = with_any({
	get_melee_weapon = function(p) return p.melee and ItemStack(p.melee) or ItemStack("") end,
	get_equipped_weapon = function(p) return p.bow and ItemStack(p.bow) or nil end,
	equipment_is_broken = function() return false end,
	is_stunned = function() return false end,
	refuse_mounted_attack = function() return false end,
	combat_eye_pos = function(p) return vector.offset(p:get_pos(), 0, 1.5, 0) end,
	combat_actor = function(ref) return ref end,
	scale_player_damage = function(_, _, amount) return math.floor(amount) end,
	scale_player_value = function(_, amount) return amount end,
	get_player_level = function(p) return p.level end,
	base_pool = function() return 1000 end,
	register_on_equipment_change = capture("equipment"),
	begin_authoritative_swing = function(player, target, transaction)
		log.swings[#log.swings + 1] = {player = player, target = target,
			raw = transaction.raw_damage, fpi = transaction.fpi}
		return nil -- the fixture stops at the transaction
	end,
	combat_ray = function(user, range)
		local target = scene.aim
		if not target then return {status = "none", reason = "nothing"} end
		local d = vector.distance(vector.offset(user:get_pos(), 0, 1.5, 0), target:get_pos())
		if d > range then
			return {status = "none", reason = "out_of_range", target = target, distance = d}
		end
		return {status = "target", reason = "hostile", target = target, distance = d, range = range}
	end,
	aim_raycast = function()
		local done = false
		return function()
			if done or not scene.aim then return nil end
			done = true
			return {type = "object", ref = scene.aim, intersection_point = scene.aim:get_pos()}
		end
	end,
	deal_ability_damage = function(attacker, target, amount)
		log.damage[#log.damage + 1] = {attacker = attacker, target = target, amount = amount}
		return amount
	end,
	particles = {play = function() end, facing = function() return {x = 0, y = 0, z = 1} end},
})

local registered_classes = {warrior = {name = "Warrior", resource = "rage"},
	mage = {name = "Mage", resource = "mana"}, priest = {name = "Priest", resource = "mana"},
	scout = {name = "Scout", resource = "mana"}}
local GC = with_any({
	registered_classes = registered_classes,
	registered_talents = {mend = {name = "Mend"}},
	get_class = function(p) return p.class end,
	get_class_def = function(p) return registered_classes[p.class] end,
	talent_rank = function(p, id) return p.ranks and p.ranks[id] or 0 end,
	get_talent_bonus = function() return 0 end,
	get_melee_bonus = function(p) return p.dex / 10 end,
	get_ranged_bonus = function(p) return p.dex / 10 end,
	get_race_perk = function() return nil end,
	get_max_mana = function() return 1e6 end,
	get_window = function() return nil end,
	talent_window_active = function() return false end,
	register_on_class_chosen = capture("class_chosen"),
	register_class = function() end,
})

-- The Scout's hand lists (grug_inventory HAND_RULES): bow skills read the
-- Ranged slot (grug_weapon), Strike and every melee skill the Melee slot
-- (the offhand list).
local function hand_list(_, slot)
	return slot == "weapon" and "grug_weapon" or "grug_offhand"
end
local fake_inventory = with_any({
	HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
	content_list = function(i) return "grug_bag" .. i end,
	get_cosmetic_hand = function(p, slot)
		local stack = hand_list(p, slot) == "grug_weapon" and p.bow or p.melee
		return stack and ItemStack(stack) or nil
	end,
	hand_list = hand_list,
	melee_list = function() return "grug_offhand" end,
	equipment_changed = function() end,
	is_bow = function(s) return s ~= nil and s:get_name():find("bow", 1, true) ~= nil end,
	ammo_count = function(p) return p.ammo end,
	consume_ammo = function(p, n)
		if p.ammo < n then return false end
		p.ammo = p.ammo - n
		return true
	end,
	refund_ammo = function(p, n) p.ammo = p.ammo + n end,
})
local fake_projectiles = with_any({
	register = function() end,
	spawn_batch = function(id, launches, commit)
		if commit and commit() ~= true then return false end
		for _, l in ipairs(launches) do log.launches[#log.launches + 1] = l end
		return true
	end,
})

-- grug_gear's real weapon_family (permissions.lua).
local gear = {}
setfenv(assert(loadfile(ROOT .. "/mods/ITEMS/grug_gear/permissions.lua")),
	setmetatable({grug_gear = gear}, {__index = _G}))()

-- grug_visuals: the REAL display state cut from apply.lua, and apply counted.
local apply_src = assert(read("mods/PLAYER/grug_visuals/apply.lua"))
local state_src = apply_src:match("\n(local shot_shown = {}.-\nfunction grug_visuals%.hand_slot%(.-\nend)\n")
local leave_src = apply_src:match("\n(core%.register_on_leaveplayer%(function%(player%)\n\tshot_shown%[.-\nend%))\n")
check(state_src ~= nil and leave_src ~= nil,
	"V the display state (show_shot, hand_slot, its leave hook) found in apply.lua")
local visuals = {applies = 0}
function visuals.apply() visuals.applies = visuals.applies + 1 end
visuals.play_pose = function() end
setfenv(assert(loadstring((state_src or "") .. "\n" .. (leave_src or ""), "=apply.lua state")),
	setmetatable({grug_visuals = visuals, core = fake_core}, {__index = _G}))()

local env = setmetatable({
	core = fake_core, ItemStack = ItemStack, vector = vector,
	grug_core = fake_grug_core, grug_classes = GC,
	grug_inventory = fake_inventory, grug_gear = gear,
	grug_visuals = visuals,
	grug_sounds = with_any({play = function() return true end, item_sound = function() return nil end}),
	grug_projectiles = fake_projectiles,
	grug_mobs = with_any({is_noncombatant = function() return false end}),
	grug_items = {get_affixes = function() return {} end},
	grug_factions = {
		get_faction = function(p) return p.faction end,
		hostile = function(a, b) return a.faction ~= b.faction end,
		same_faction = function(a, b) return a.faction == b.faction end,
	},
	grug_pvp = {can_harm = function() return false end, can_support = function() return true end},
}, {__index = function(_, k)
	local g = rawget(_G, k)
	if g ~= nil and k ~= "core" and k ~= "minetest" then return g end
	return any()
end})
env.dofile = function(path) return setfenv(assert(loadfile(path)), env)() end
env._G = env
setfenv(assert(loadfile(ROOT .. "/" .. ABIL .. "init.lua")), env)()
local G = env.grug_abilities
local R = G.registered
check(G and R.bladecraft and R.strike and R.true_draw and G.input and G.show_last_attack,
	"K the real init.lua loads with the kit, input and show_last_attack")

------------------------------------------------------------------------------
-- Helpers.
------------------------------------------------------------------------------
local MOB_POS = vector.new(0, 1, 2) -- in blade reach and bow range
local serial = 0
local BOW_IMG, SWORD_IMG = "grug_gear_bow_wood.png", "grug_gear_sword_iron.png"
-- A Bladecraft Scout: Bladecraft on slot 1 of layout A and slot 3 of layout
-- B, Strike on slot 2.
local function scout(opts)
	serial = serial + 1
	local p = new_player("s" .. serial, opts)
	p.ranks = {veil_bladecraft = 1, quarry_true_draw = 1}
	p.inv.lists.main[1] = G.stack_for(p, "bladecraft")
	p.inv.lists.main[2] = G.stack_for(p, "strike")
	p.inv.lists.grug_hotbar_store[3] = G.stack_for(p, "bladecraft")
	G.restore_mana(p, 1e6)
	return p
end
local function wield_image(p, list, index)
	return p.inv.lists[list][index].fields.wield_image
end
local function shows_bow(p)
	return visuals.hand_slot(p, "melee", "weapon") == "weapon"
end
local function step(p, controls)
	p.controls = controls
	wait(0.05)
	G.input.step(p)
end
local function release(p)
	step(p, {})
	step(p, {})
end
local function shoot(p)
	return G.try_cast(p, R.bladecraft.secondary_cast, nil, function() end)
end

------------------------------------------------------------------------------
-- L1: a shot that flew shows the bow.
------------------------------------------------------------------------------
local LOOSE_DAMAGE, SWING_RAW
do
	eq(R.bladecraft.slot, "melee", "L1 Bladecraft keeps its Melee slot (damage and clocks)")
	eq(R.bladecraft.shot_slot, "weapon", "L1 ... and shows the Ranged slot after a shot")
	eq(registered_items["grug_abilities:bladecraft"]._grug_ability_shot_slot, "weapon",
		"L1 the item carries the shot slot for grug_visuals")
	eq(registered_items["grug_abilities:strike"]._grug_ability_shot_slot, nil,
		"L1 Strike carries none")
	local count = 0
	for _, def in pairs(R) do
		if def.shot_slot then count = count + 1 end
	end
	eq(count, 1, "L1 only Bladecraft has a shot slot")
	local p = scout()
	eq(wield_image(p, "main", 1), SWORD_IMG, "L1 a fresh Bladecraft shows the blade")
	eq(p.inv.lists.main[1].fields.wield_overlay, "grug_abilities_fx_veil_sword.png",
		"L1 ... under the Veil sword strip")
	scene.aim = new_mob("l1", MOB_POS)
	reset_writes()
	reset_log()
	visuals.applies = 0
	step(p, {place = true})
	eq(#log.launches, 1, "L1 RMB: the shot flies")
	LOOSE_DAMAGE = log.launches[1] and log.launches[1].data.damage
	check(shows_bow(p), "L1 ... and the state says shot")
	eq(wield_image(p, "main", 1), BOW_IMG, "L1 the held Bladecraft shows the bow")
	eq(p.inv.lists.main[1].fields.wield_overlay, "grug_abilities_fx_veil_bow.png",
		"L1 ... under the Veil bow strip")
	eq(wield_image(p, "grug_hotbar_store", 3), BOW_IMG, "L1 the copy on layout B too")
	eq(wield_image(p, "main", 2), SWORD_IMG, "L1 Strike still shows the blade")
	local held, other, strays = 0, 0, 0
	for _, w in ipairs(writes) do
		if w.kind == "set_wielded_item" and w.index == 1 and w.skip_anim == true then
			held = held + 1
		elseif w.kind == "set_stack" and w.list == "grug_hotbar_store" and w.index == 3 then
			other = other + 1
		else
			strays = strays + 1
		end
	end
	eq(held, 1, "L1 the held stack: one set_wielded_item with skip_anim")
	eq(other, 1, "L1 the other layout: one set_stack")
	eq(strays, 0, "L1 no other inventory write")
	eq(visuals.applies, 1, "L1 grug_visuals.apply once, at once")
	release(p)
	wait(2)
	reset_writes()
	visuals.applies = 0
	step(p, {place = true})
	eq(#log.launches, 2, "L1 a second shot flies")
	eq(#writes, 0, "L1 ... and writes nothing (no change)")
	eq(visuals.applies, 0, "L1 ... and applies nothing")
	release(p)
	scene.aim = nil
end

------------------------------------------------------------------------------
-- L2: a refused shot switches nothing.
------------------------------------------------------------------------------
do
	local p = scout()
	reset_writes()
	visuals.applies = 0
	scene.aim = nil
	check(not shoot(p), "L2 no target: refused")
	scene.aim = new_mob("l2", MOB_POS)
	p.ammo = 0
	check(not shoot(p), "L2 no arrow: refused")
	p.ammo, p.bow = 50, nil
	check(not shoot(p), "L2 no bow: refused")
	check(not shows_bow(p), "L2 ... the blade stays")
	eq(#writes, 0, "L2 ... no inventory write")
	eq(visuals.applies, 0, "L2 ... no apply")
	scene.aim = nil
end

------------------------------------------------------------------------------
-- L3, L4: an air click switches nothing, a swing at a foe shows the blade.
------------------------------------------------------------------------------
do
	local p = scout()
	scene.aim = new_mob("l3", MOB_POS)
	check(shoot(p), "L3 a shot")
	check(shows_bow(p), "L3 ... shows the bow")
	scene.aim = nil
	wait(2)
	reset_writes()
	reset_log()
	visuals.applies = 0
	step(p, {dig = true})
	for _ = 1, 30 do step(p, {dig = true}) end
	release(p)
	eq(#log.swings, 0, "L3 LMB held at the air (or at a node: digging): no swing")
	check(shows_bow(p), "L3 ... the bow stays")
	eq(#writes, 0, "L3 ... no inventory write")
	eq(visuals.applies, 0, "L3 ... no apply")
	scene.aim = new_mob("l4", MOB_POS)
	wait(2)
	reset_log()
	step(p, {dig = true})
	eq(#log.swings, 1, "L4 LMB at a foe: Bladecraft swings")
	SWING_RAW = log.swings[1] and log.swings[1].raw
	check(not shows_bow(p), "L4 ... and shows the blade again")
	eq(wield_image(p, "main", 1), SWORD_IMG, "L4 the held stack shows the blade")
	eq(wield_image(p, "grug_hotbar_store", 3), SWORD_IMG, "L4 ... and the copy on layout B")
	local skipped = false
	for _, w in ipairs(writes) do
		if w.kind == "set_wielded_item" and w.skip_anim == true then skipped = true end
	end
	check(skipped, "L4 the held stack through set_wielded_item with skip_anim")
	release(p)
	scene.aim = nil
end

------------------------------------------------------------------------------
-- L5: only Bladecraft switches.
------------------------------------------------------------------------------
do
	local p = scout()
	p.inv.lists.main[4] = G.stack_for(p, "true_draw")
	scene.aim = new_mob("l5", MOB_POS)
	check(shoot(p), "L5 a Bladecraft shot shows the bow")
	-- True Draw with an empty quiver at a foe in reach: the held fallback
	-- swings Strike (round53-plan.md K8).
	p.ammo = 0
	p.wield = 4
	wait(3)
	reset_log()
	reset_writes()
	step(p, {dig = true})
	release(p)
	eq(#log.swings, 1, "L5 True Draw without arrows: the fallback swings Strike")
	check(shows_bow(p), "L5 ... and Bladecraft still shows the bow")
	-- (The combat hold's pointing range on the held True Draw is input.lua's
	-- own write.)
	local bladecraft_writes = 0
	for _, w in ipairs(writes) do
		if w.name == "grug_abilities:bladecraft" then bladecraft_writes = bladecraft_writes + 1 end
	end
	eq(bladecraft_writes, 0, "L5 ... no write to a Bladecraft stack")
	-- Strike itself, selected: a swing at a foe switches nothing either.
	p.wield = 2
	wait(3)
	reset_log()
	step(p, {dig = true})
	release(p)
	eq(#log.swings, 1, "L5 Strike swings")
	check(shows_bow(p), "L5 ... and Bladecraft still shows the bow")
	eq(wield_image(p, "main", 2), SWORD_IMG, "L5 Strike's stack shows the blade throughout")
	scene.aim = nil
end

------------------------------------------------------------------------------
-- L6: damage and both clocks unchanged.
------------------------------------------------------------------------------
do
	local p = scout()
	local unit = own_weapon_damage(p.level) + p.dex / 10
	near(SWING_RAW, unit, "L6 Bladecraft's swing (after a shot) is the plain 1 M")
	near(LOOSE_DAMAGE, unit * 0.95, "L6 the shot is Loose's 0.95 R")
	scene.aim = new_mob("l6", MOB_POS)
	-- A swing while the bow shows: the same raw damage and the blade's interval.
	check(shoot(p), "L6 a shot")
	wait(3)
	reset_log()
	step(p, {dig = true})
	near(log.swings[1] and log.swings[1].raw, unit, "L6 the swing with the bow shown: 1 M")
	eq(log.swings[1] and log.swings[1].fpi, 1, "L6 ... at the blade's interval")
	release(p)
	-- The shot pushes the next swing (the action clock), as before.
	wait(3)
	reset_log()
	step(p, {place = true})
	eq(#log.launches, 1, "L6 a shot")
	step(p, {})
	step(p, {dig = true})
	eq(#log.swings, 0, "L6 the swing right after it waits (the shared clock)")
	for _ = 1, 20 do step(p, {dig = true}) end
	eq(#log.swings, 1, "L6 ... and lands after the blade's interval")
	release(p)
	scene.aim = nil
end

------------------------------------------------------------------------------
-- L7: no timeout, hotbar switches, a relog.
------------------------------------------------------------------------------
do
	local p = scout()
	scene.aim = new_mob("l7", MOB_POS)
	check(shoot(p), "L7 a shot")
	scene.aim = nil
	p.wield = 2
	step(p, {})
	wait(600)
	p.wield = 1
	step(p, {})
	check(shows_bow(p), "L7 ten minutes and two hotbar switches later: still the bow")
	eq(wield_image(p, "main", 1), BOW_IMG, "L7 ... on the held stack")
	-- An equipment change in between (any skin pass) keeps it.
	reset_writes()
	fire("equipment", p, nil)
	eq(wield_image(p, "main", 1), BOW_IMG, "L7 a full skin pass keeps the bow")
	fire("leave", p)
	check(not shows_bow(p), "L7 a relog: the state is gone")
	local fresh = G.stack_for(p, "bladecraft")
	eq(fresh and fresh:get_meta():get_string("wield_image"), SWORD_IMG,
		"L7 ... and the next skin shows the blade")
end

------------------------------------------------------------------------------
-- L8: the bow changed while the bow shows.
------------------------------------------------------------------------------
do
	local p = scout()
	scene.aim = new_mob("l8", MOB_POS)
	check(shoot(p), "L8 a shot")
	scene.aim = nil
	p.bow = weapon("grug_gear:bow_ash", 10, 1)
	fire("equipment", p, "grug_weapon")
	eq(wield_image(p, "main", 1), "grug_gear_bow_ash.png", "L8 the Ranged slot's change re-skins Bladecraft")
	eq(wield_image(p, "grug_hotbar_store", 3), "grug_gear_bow_ash.png", "L8 ... on both layouts")
	p.melee = weapon("grug_gear:sword_iron", 10, 1.2)
	reset_writes()
	fire("equipment", p, "grug_offhand")
	eq(wield_image(p, "main", 1), "grug_gear_bow_ash.png", "L8 a Melee slot change leaves the bow shown")
end

if failures > 0 then
	error(("R72 BLADECRAFT PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print("R72 BLADECRAFT PORTABLE PASS checks=" .. checks)
