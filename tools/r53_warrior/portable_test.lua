-- Round 53 lane WARRIOR portable test (LuaJIT; round53-plan.md §4 WARRIOR,
-- §6 class fixtures): the Warrior's new kit and its talent data.
--
--   luajit tools/r53_warrior/portable_test.lua [repo]
--
--   G  the REAL talent_graph.lua with talent_graph_warrior.lua: the audit
--      passes, every effect key is in the class vocabulary, every granting
--      node names a registered ability whose `talent` is that node, and the
--      full-rank values reach the calculator's frozen build totals
--      (r52/calc data-warrior.json: Retort 0.40 S, Recover 2 % P, Hold
--      Ground 0.21 P and 21 s, Unbroken 9.5 s, Mighty Blow 1.65 S, 22 rage,
--      Finisher +0.24 S, Broadstroke's others 0.50 S, Hamstring 4.5 s,
--      Charge 8.5 s and 20 rage, Halt 30 %);
--   K  the REAL grug_abilities/init.lua with its whole dofile chain, the
--      REAL talent_windows.lua and the REAL grug_core/area.lua in a sandbox
--      (the tools/r53_hooks pattern), the talents answered from G's graph:
--      the kit's shape (starters, gates, transforms, costs, cooldowns, the
--      action clock), the transforms on both layouts, the damage and the
--      amounts at levels 10, 30 and 60 against the calculator (S = P/8 with
--      an own-level sword), each talent at rank 1 and full, Retort's window
--      (opened by a hit that took health, consumed by a landed Retort,
--      4 s, 6 s ICD, Recover's heal without crit; never a charge or cost:
--      K8), Ruination's window on every swing and Broadstroke's others,
--      Hold Ground's and Unbroken's shields and armor, Hamstring's slow,
--      Bellow's circle, and the area refusals: an unflagged or same-faction
--      player, a friendly mob, one behind or out of range is never an area
--      target.
-- Prints "R53 WARRIOR PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function near(actual, expected, label, tolerance)
	return check(type(actual) == "number" and math.abs(actual - expected) < (tolerance or 1e-6),
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

-- The game's level curves (grug_core/combat.lua), the calculator's units.
local function base_pool(level)
	level = math.max(1, math.min(60, math.floor(level)))
	return math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
end
local function sword(level) return math.floor(4 + 0.35 * level + 0.5) end
local function strength(level) return 10 + 3 * (level - 1) end
local function base_hit(level) return sword(level) + strength(level) / 10 end
local function level_scale(level) return base_pool(level) / (8 * base_hit(level)) end
local function armor_k(level) return 20 + 0.5 * math.min(level, 60) end

------------------------------------------------------------------------------
-- G: the graph data.
------------------------------------------------------------------------------
local graph
do
	local saved = grug_classes
	grug_classes = {registered_classes = {warrior = {name = "Warrior"}}}
	dofile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph.lua")
	dofile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph_warrior.lua")
	graph = grug_classes.graph
	grug_classes = saved
	local ok, err = pcall(graph.audit)
	check(ok, "G the warrior trees pass the audit: " .. tostring(err))
	for _, id in ipairs(graph.node_ids) do
		local node = graph.nodes[id]
		for key in pairs(node.effects) do
			check(graph.valid_key("warrior", key), "G " .. id .. "'s key " .. key .. " is in the vocabulary")
		end
	end
end

-- The bonus a ranks table gives, summed as talents.lua does.
local function sums_of(ranks)
	local sums = {}
	for id, rank in pairs(ranks) do
		local node = assert(graph.nodes[id], "no node " .. id)
		for key, values in pairs(node.effects) do
			sums[key] = (sums[key] or 0) + values[rank]
		end
	end
	return sums
end
local function full(id) return graph.nodes[id].ranks end

do
	local function at(id, rank, key)
		return sums_of({[id] = rank})[key] or 0
	end
	near(0.25 + at("bulwark_measured_answer", 3, "retort_bonus_add"), 0.40, "G Measured Answer 3: Retort 0.40 S")
	near(at("bulwark_measured_answer", 1, "retort_bonus_add"), 0.05, "G Measured Answer 1: +0.05 S")
	near(at("bulwark_recover", 3, "retort_heal_percent"), 2, "G Recover 3: 2 % P")
	near(at("bulwark_recover", 1, "retort_heal_percent"), 0.7, "G Recover 1: 0.7 % P")
	near(12 + at("bulwark_layered_guard", 3, "hold_ground_absorb_add"), 21, "G Layered Guard 3: 0.21 P")
	near(24 - at("bulwark_gather_yourself", 3, "cooldown_sub:hold_ground"), 21, "G Gather Yourself 3: 21 s")
	near(8 + at("bulwark_enduring_stand", 3, "duration_add:unbroken"), 9.5, "G Enduring Stand 3: 9.5 s")
	near(at("bulwark_halt", 3, "charge_slow_percent"), 30, "G Halt 3: 30 %")
	near(at("bulwark_halt", 1, "charge_slow_percent"), 20, "G Halt 1: 20 %")
	near(at("bulwark_ironbound", 4, "armor_percent_add"), 16, "G Ironbound 4: 0.16 K")
	near(at("bulwark_weathered", 3, "max_hp_percent_add"), 9, "G Weathered 3: +9 %")
	near(at("bulwark_turn_the_edge", 3, "dodge_chance_add"), 6, "G Turn the Edge 3: +6")
	near(1.45 + at("ruin_heavy_hand", 4, "mighty_blow_unit_add"), 1.65, "G Heavy Hand 4: 1.65 S")
	near(at("ruin_finisher", 3, "finisher_unit_add"), 0.24, "G Finisher 3: +0.24 S")
	near(25 - at("ruin_relentless", 3, "mighty_blow_cost_sub"), 22, "G Relentless 3: 22 rage")
	near(0.35 + at("ruin_follow_through", 3, "broadstroke_secondary_add"), 0.50, "G Follow Through 3: 0.50 S")
	near(3 + at("ruin_clean_cut", 3, "duration_add:hamstring"), 4.5, "G Clean Cut 3: 4.5 s")
	near(10 - at("ruin_onset", 3, "cooldown_sub:charge"), 8.5, "G Onset 3: 8.5 s")
	near(15 + at("ruin_reach_the_fight", 1, "charge_rage_add"), 20, "G Reach the Fight: 20 rage")
	near(at("ruin_stoke", 3, "rage_per_swing_add"), 3, "G Stoke 3: +3 rage")
	near(at("ruin_keen_edge", 3, "crit_chance_add"), 6, "G Keen Edge 3: +6")
	near(8 + at("ruin_long_fury", 3, "duration_add:ruination"), 9.5, "G Long Fury 3: 9.5 s")
end

------------------------------------------------------------------------------
-- K: the real init.lua in a sandbox (the tools/r53_hooks pattern).
------------------------------------------------------------------------------
local now_us = 1e9
local function wait(s) now_us = now_us + s * 1e6 end
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
end

local V = {}
function V.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
V.copy = V.new
function V.offset(p, x, y, z) return V.new(p.x + x, p.y + y, p.z + z) end
function V.add(a, b) return V.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function V.subtract(a, b) return V.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function V.multiply(a, s) return V.new(a.x * s, a.y * s, a.z * s) end
function V.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function V.distance(a, b) return V.length(V.subtract(a, b)) end
function V.direction(a, b)
	local d = V.subtract(b, a)
	local l = V.length(d)
	return l > 0 and V.multiply(d, 1 / l) or V.new(0, 0, 0)
end
function V.equals(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end

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
		set_tool_capabilities = function() end,
	}
end
function Stack:get_tool_capabilities() return {full_punch_interval = 1} end

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

-- The scene: every object an area may see.
local scene = {}
local players = {}
local function new_player(name, opts)
	opts = opts or {}
	local p = {name = name, class = opts.class or "warrior", ranks = {}, hp = 100,
		level = opts.level or 30, faction = opts.faction or "accord", flagged = opts.flagged,
		pos = V.new(opts.x or 0, 0, opts.z or 0), inv = new_inventory(), wield = 1}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:set_hp(hp) self.hp = hp end
	function p:get_pos() return V.copy(self.pos) end
	function p:get_look_horizontal() return 0 end -- facing +z
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:get_wield_index() return self.wield end
	function p:get_meta() return ItemStack("x"):get_meta() end
	function p:get_properties() return {hp_max = 100} end
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add() return 1 end
	function p:hud_change() end
	function p:hud_remove() end
	function p:punch() end
	players[name] = p
	scene[#scene + 1] = p
	return p
end
local function new_mob(name, x, z, opts)
	opts = opts or {}
	local ent = {name = name, _cmi_is_mob = true, health = opts.health or 10,
		attack_type = "dogfight", _grug_faction = opts.faction,
		noncombatant = opts.noncombatant, temp = {}, attacked = 0}
	function ent:do_attack() self.attacked = self.attacked + 1 end
	local mob = {name = name, ent = ent, pos = V.new(x, 0, z), punches = 0}
	ent.object = mob
	function mob:get_pos() return V.copy(self.pos) end
	function mob:is_player() return false end
	function mob:get_luaentity() return self.ent end
	function mob:get_hp() return self.ent.health end
	function mob:get_properties() return {hp_max = 10} end
	function mob:punch() self.punches = self.punches + 1 end
	scene[#scene + 1] = mob
	return mob
end
local function clear_scene()
	for k in pairs(scene) do scene[k] = nil end
	for k in pairs(players) do players[k] = nil end
end

local tools, input_api = {}, nil
local registered_classes = {warrior = {name = "Warrior", resource = "rage"},
	mage = {name = "Mage", resource = "mana"}, priest = {name = "Priest", resource = "mana"},
	scout = {name = "Scout"}}
local callbacks = {}
local function capture(kind)
	return function(fn)
		callbacks[kind] = callbacks[kind] or {}
		table.insert(callbacks[kind], fn)
	end
end

local fake_core = with_any({
	register_on_dieplayer = capture("die"),
	register_on_leaveplayer = capture("leave"),
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_abilities" end,
	get_current_modname = function() return "grug_abilities" end,
	get_us_time = function() return now_us end,
	global_exists = function(n) return n == "grug_inventory" end,
	register_tool = function(name, def) tools[name] = def end,
	registered_items = {},
	registered_nodes = {air = {walkable = false}},
	get_node_or_nil = function() return {name = "air"} end,
	raycast = function() return function() return nil end end,
	get_objects_in_area = function(minp, maxp)
		local out = {}
		for _, o in ipairs(scene) do
			local p = o:get_pos()
			if p.x >= minp.x and p.x <= maxp.x and p.y >= minp.y and p.y <= maxp.y and
					p.z >= minp.z and p.z <= maxp.z then
				out[#out + 1] = o
			end
		end
		return out
	end,
	yaw_to_dir = function(yaw) return V.new(-math.sin(yaw), 0, math.cos(yaw)) end,
	get_item_group = function(name, group)
		return (group == "grug_ability" and name:find("^grug_abilities:")) and 1 or 0
	end,
	get_player_by_name = function(name) return players[name] end,
	log = function() end,
})

-- What the kit did: effects, damage, heals, shields, statuses, slows, taunts.
local log
local function reset_log()
	log = {fx = {}, damage = {}, heals = {}, absorbs = {}, statuses = {}, slows = {},
		mods = {}, taunts = {}, procs = {}, immunity = 0}
end
reset_log()
local melee_prepare, melee_finish
local transactions = {}
local current_target
local fake_grug_core = with_any({
	get_melee_weapon = function() return ItemStack("") end,
	is_stunned = function() return false end,
	base_pool = base_pool,
	armor_k = armor_k,
	baseline_melee_total = base_hit,
	get_player_level = function(p) return p.level end,
	scale_player_damage = function(p, _, amount)
		if amount <= 0 then return 0 end
		return math.max(1, math.floor(amount * level_scale(p.level)))
	end,
	register_native_melee_handler = function(prepare, finish)
		melee_prepare, melee_finish = prepare, finish
	end,
	register_on_settled_incoming_hit = capture("settled_hit"),
	particles = {play = function(id, frame) log.fx[#log.fx + 1] = {id = id, frame = frame} end,
		facing = function() return V.new(0, 0, 1) end},
	proc_flash = function(_, proc) log.procs[#log.procs + 1] = proc end,
	deal_ability_damage = function(user, target, amount, opts)
		log.damage[#log.damage + 1] = {target = target, amount = amount, opts = opts}
		return amount
	end,
	heal_player = function(healer, target, amount, opts)
		log.heals[#log.heals + 1] = {target = target, amount = amount, opts = opts or {}}
		return amount
	end,
	add_absorb = function(player, id, amount, duration, source)
		log.absorbs[#log.absorbs + 1] = {player = player, id = id, amount = amount,
			duration = duration, source = source}
		return amount
	end,
	set_status = function(player, id, def)
		log.statuses[#log.statuses + 1] = {player = player, id = id, def = def}
		return def
	end,
	clear_status = function() end,
	set_move_modifier = function(target, name, effect, d)
		log.mods[#log.mods + 1] = {target = target, name = name, speed = effect.speed, d = d}
	end,
	set_move_immunity = function() log.immunity = log.immunity + 1 end,
	taunt = function(ent, user)
		log.taunts[#log.taunts + 1] = ent.name
		return true
	end,
	combat_ray = function()
		return {status = current_target and "target" or "miss", reason = "target",
			target = current_target}
	end,
	begin_authoritative_swing = function(_, _, t)
		transactions[#transactions + 1] = t
		return t
	end,
	end_authoritative_swing = function() end,
	valid_authoritative_swing = function() return true end,
	get_authoritative_swing_context = function(token) return token end,
})

local graph_cache = {}
local fake_classes = with_any({
	registered_classes = registered_classes,
	registered_talents = {mend = {name = "Mend"}}, -- kits_priest.lua reads it at load until PRIEST
	get_class = function(p) return p.class end,
	get_class_def = function(p) return registered_classes[p.class] end,
	talent_rank = function(p, id) return p.ranks[id] or 0 end,
	get_talent_bonus = function(p, key)
		if not p or not p.ranks then return 0 end
		local cached = graph_cache[p]
		if not cached or cached.ranks ~= p.ranks then
			cached = {ranks = p.ranks, sums = sums_of(p.ranks)}
			graph_cache[p] = cached
		end
		return cached.sums[key] or 0
	end,
	get_melee_bonus = function(p) return strength(p.level) / 10 end,
	get_support_factor = function() return 1 end,
	get_race_perk = function() return nil end,
	get_max_mana = function() return 100 end,
	talent_window_active = function() return false end,
	register_on_class_chosen = capture("class_chosen"),
})
local fake_inventory = with_any({
	HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
	content_list = function(i) return "grug_bag" .. i end,
	get_cosmetic_hand = function() return nil end,
	hand_list = function() return "grug_weapon" end,
	melee_list = function() return "grug_weapon" end,
	equipment_changed = function() end,
})
local fake_mobs = with_any({
	is_noncombatant = function(ent) return ent.noncombatant == true end,
	slow = function(ent, d, factor) log.slows[#log.slows + 1] = {ent = ent, d = d, factor = factor} end,
	stun = function() return true end,
})
local fake_factions = with_any({
	get_faction = function(p) return p.faction end,
	same_faction = function(a, b) return a.faction == b.faction end,
	hostile = function(a, b) return a.faction ~= b.faction end,
})
local fake_pvp = with_any({
	can_harm = function(a, b) return a.flagged == true and b.flagged == true end,
	can_support = function() return true end,
})
local env = setmetatable({
	core = fake_core, ItemStack = ItemStack, vector = V,
	grug_core = fake_grug_core, grug_classes = fake_classes,
	grug_inventory = fake_inventory, grug_mobs = fake_mobs,
	grug_factions = fake_factions, grug_pvp = fake_pvp,
}, {__index = function(_, k)
	local g = rawget(_G, k)
	if g ~= nil and k ~= "core" and k ~= "minetest" and k ~= "grug_core" and
			k ~= "vector" and k ~= "ItemStack" and k ~= "grug_classes" then return g end
	return any()
end})
env.dofile = function(path)
	local chunk = setfenv(assert(loadfile(path)), env)
	local result = chunk()
	if path:find("/input%.lua$") then
		local real = result
		return function(api)
			input_api = api
			return real(api)
		end
	end
	return result
end
env._G = env
env.dofile(ROOT .. "/mods/CORE/grug_core/status_icons.lua")
env.dofile(ROOT .. "/mods/CORE/grug_core/area.lua")
env.dofile(ROOT .. "/mods/PLAYER/grug_abilities/init.lua")
env.dofile(ROOT .. "/mods/PLAYER/grug_classes/talent_windows.lua")
local G = env.grug_abilities
local C = fake_classes
check(G and G.registered.retort and input_api and melee_prepare and C.open_window,
	"K the real init.lua loads with the kit, input, the melee handlers and the windows")
G.swing_stats = function(p) return sword(p.level), 1.0 end
G.base_swing_interval = function() return 1.0 end

local function rank(p, ranks)
	p.ranks = ranks
	graph_cache[p] = nil
end
local function all_ranks(...)
	local ranks = {}
	for _, id in ipairs({...}) do ranks[id] = full(id) end
	return ranks
end

------------------------------------------------------------------------------
-- K1: the kit's shape.
------------------------------------------------------------------------------
local R = G.registered
do
	local order = {}
	for _, def in ipairs(G.by_class.warrior) do order[#order + 1] = def.id end
	eq(table.concat(order, ","), "charge,retort,hold_ground,taunt,bellow,unbroken," ..
		"mighty_blow,broadstroke,hamstring,ruination", "K1 the Warrior's abilities in file order")
	local TALENT = {retort = "bulwark_retort", hold_ground = "bulwark_hold_ground",
		taunt = "bulwark_taunt", bellow = "bulwark_bellow", unbroken = "bulwark_unbroken",
		mighty_blow = "ruin_mighty_blow", broadstroke = "ruin_broadstroke",
		hamstring = "ruin_hamstring", ruination = "ruin_ruination"}
	for id, node_id in pairs(TALENT) do
		local def, node = R[id], graph.nodes[node_id]
		check(def.talent_gated == true and def.talent == node_id,
			"K1 " .. id .. " is gated by " .. node_id)
		check(node and node.ability == id, "K1 node " .. node_id .. " grants " .. id)
	end
	for _, node_id in ipairs(graph.node_ids) do
		local node = graph.nodes[node_id]
		if node.ability then
			check(R[node.ability] and R[node.ability].talent == node_id,
				"K1 " .. node_id .. "'s ability is registered with it as its talent")
		end
	end
	check(not R.charge.talent_gated and R.charge.talent == nil, "K1 Charge is a starter")
	eq(R.retort.transforms, "strike", "K1 Retort transforms Strike")
	eq(R.bellow.transforms, "taunt", "K1 Bellow transforms Taunt")
	eq(R.broadstroke.transforms, "mighty_blow", "K1 Broadstroke transforms Mighty Blow")
	eq(R.bellow.cooldown_key, "taunt", "K1 Bellow shares Taunt's cooldown")
	-- K8 (hooks review F2): a refused basic attack has no fallback, so Retort
	-- has neither a charge nor a cost nor a proc.
	check(R.retort.charge == nil and next(R.retort.cost) == nil and R.retort.proc_swing == nil,
		"K1 Retort's readiness is no charge, no cost and no proc")
	local p = new_player("k1", {level = 30})
	G.add_rage(p, 0)
	eq(input_api.swing_refusal(p, R.retort), nil, "K1 at 0 rage a Retort is never refused")
	-- Costs, cooldowns, charges and the action clock (calculator / node list).
	local SHAPE = {
		charge = {nil, 10, 0.75, 0.75}, hold_ground = {25, 24, 0.35, 0.35},
		taunt = {nil, 8, 0.35, 0.35}, bellow = {nil, 8, 0.35, 0.35},
		unbroken = {25, 60, 0.35, 0.35}, ruination = {20, 60, 0.35, 0.35},
	}
	for id, s in pairs(SHAPE) do
		local def = R[id]
		eq(def.cost.rage, s[1], "K1 " .. id .. "'s rage cost")
		eq(def.cooldown, s[2], "K1 " .. id .. "'s cooldown")
		eq(def.occupied_cast, s[3], "K1 " .. id .. " occupies casts")
		eq(def.occupied_swing, s[4], "K1 " .. id .. " occupies the swing")
		check(def.cooldown_talent == nil, "K1 " .. id .. " reads no old cooldown talent")
	end
	for _, id in ipairs({"retort", "mighty_blow", "broadstroke", "hamstring"}) do
		eq(R[id].occupied_cast, "weapon", "K1 " .. id .. " holds casts one weapon interval (K9)")
		eq(R[id].range, 3, "K1 " .. id .. " is melee at 3 m")
	end
	eq(R.mighty_blow.cost.rage, 25, "K1 Mighty Blow costs 25 rage")
	eq(R.broadstroke.cost.rage, 25, "K1 Broadstroke costs 25 rage")
	eq(R.hamstring.cost.rage, 10, "K1 Hamstring costs 10 rage")
	eq(R.hamstring.charge, 8, "K1 Hamstring charges over 8 s")
	eq(R.mighty_blow.charge, nil, "K1 Mighty Blow has no charge")
	-- Starters and unlocks.
	eq(table.concat(G.unlocked_ids(p), ","), "strike,charge", "K1 a fresh Warrior: Strike, Charge")
	rank(p, all_ranks("bulwark_retort", "bulwark_hold_ground", "bulwark_taunt",
		"bulwark_bellow", "ruin_mighty_blow", "ruin_broadstroke"))
	eq(table.concat(G.unlocked_ids(p), ","), "charge,retort,hold_ground,bellow,broadstroke",
		"K1 the transforms replace their bases")
	eq(G.current_form(p, R.strike).id, "retort", "K1 Strike's current form is Retort")
	eq(G.current_form(p, R.taunt).id, "bellow", "K1 Taunt's is Bellow")
	eq(G.current_form(p, R.mighty_blow).id, "broadstroke", "K1 Mighty Blow's is Broadstroke")
	-- On both layouts (normalize_kit).
	for _, list in ipairs({"main", "grug_hotbar_store"}) do
		p.inv.lists[list][1] = ItemStack("grug_abilities:strike")
		p.inv.lists[list][2] = ItemStack("grug_abilities:taunt")
		p.inv.lists[list][3] = ItemStack("grug_abilities:mighty_blow")
	end
	G.normalize_kit(p)
	for _, list in ipairs({"main", "grug_hotbar_store"}) do
		local l = p.inv.lists[list]
		eq(l[1].name .. "," .. l[2].name .. "," .. l[3].name,
			"grug_abilities:retort,grug_abilities:bellow,grug_abilities:broadstroke",
			"K1 the transforms in place on " .. list)
	end
	rank(p, {})
	G.normalize_kit(p)
	eq(p.inv.lists.main[1].name, "grug_abilities:strike", "K1 a respec swaps Retort back to Strike")
	eq(p.inv.lists.main[2].name, "", "K1 ...and Taunt is locked again")
	eq(select(2, input_api.cast_refusal(p, R.taunt)), "locked", "K1 Taunt is talent-gated")
	clear_scene()
end

------------------------------------------------------------------------------
-- K2: the swings at levels 10, 30, 60 against the calculator (S = P / 8).
------------------------------------------------------------------------------
local function swing(p, def, target)
	current_target = target
	wait(1.1) -- past the weapon's 1 s interval
	local before = #transactions
	input_api.swing(p, def)
	return transactions[before + 1]
end
local function land(p, t, target, result)
	local context = melee_prepare(p, target, t)
	melee_finish(context, result or {landed = true, grant_rage = true})
end
local LEVELS = {10, 30, 60}
do
	for _, level in ipairs(LEVELS) do
		local S = base_pool(level) / 8
		local p = new_player("k2_" .. level, {level = level, faction = "accord"})
		local mob = new_mob("wolf", 0, 2)
		local function proc_damage(def, ranks, health)
			rank(p, ranks)
			mob.ent.health = health or 10
			G.add_rage(p, 100)
			local t = swing(p, def, mob)
			return t and t.proc == def and t.scaled_damage
		end
		local L = " at level " .. level
		near(proc_damage(R.mighty_blow, {ruin_mighty_blow = 1}), 1.45 * S,
			"K2 Mighty Blow 1.45 S" .. L, 1)
		near(proc_damage(R.mighty_blow, {ruin_mighty_blow = 1, ruin_heavy_hand = 1}), 1.50 * S,
			"K2 Heavy Hand 1: 1.50 S" .. L, 1)
		near(proc_damage(R.mighty_blow, {ruin_mighty_blow = 1, ruin_heavy_hand = 4}), 1.65 * S,
			"K2 Heavy Hand 4: 1.65 S" .. L, 1)
		near(proc_damage(R.mighty_blow, {ruin_mighty_blow = 1, ruin_heavy_hand = 4,
			ruin_finisher = 3}, 2), 1.89 * S, "K2 Finisher 3 below 30 %: 1.89 S" .. L, 1)
		near(proc_damage(R.mighty_blow, {ruin_mighty_blow = 1, ruin_finisher = 1}, 2), 1.53 * S,
			"K2 Finisher 1 below 30 %: 1.53 S" .. L, 1)
		near(proc_damage(R.mighty_blow, {ruin_mighty_blow = 1, ruin_finisher = 3}, 3), 1.45 * S,
			"K2 Finisher: nothing at 30 %" .. L, 1)
		near(proc_damage(R.broadstroke, {ruin_mighty_blow = 1, ruin_broadstroke = 1,
			ruin_heavy_hand = 4}), 1.65 * S, "K2 Broadstroke's primary: Mighty Blow's" .. L, 1)
		near(proc_damage(R.hamstring, {ruin_hamstring = 1}), S, "K2 Hamstring: S" .. L, 1)
		-- The plain swing is S; the costs with Relentless.
		rank(p, {})
		near(swing(p, R.strike, mob).scaled_damage, S, "K2 Strike: S" .. L, 1)
		rank(p, {ruin_mighty_blow = 1, ruin_broadstroke = 1, ruin_relentless = 1})
		eq(G.effective_cost(p, R.mighty_blow).rage, 24, "K2 Relentless 1: 24 rage" .. L)
		rank(p, {ruin_mighty_blow = 1, ruin_broadstroke = 1, ruin_relentless = 3})
		eq(G.effective_cost(p, R.mighty_blow).rage, 22, "K2 Relentless 3: Mighty Blow 22" .. L)
		eq(G.effective_cost(p, R.broadstroke).rage, 22, "K2 Relentless 3: Broadstroke 22" .. L)
		-- Charge: 0.12 of the base hit before the scalar.
		near(R.charge.values(p).damage * level_scale(level), 0.12 * S, "K2 Charge 0.12 S" .. L)
		clear_scene()
	end
end

-- A proc's rage: paid before the swing, the landed swing's 8 after it.
do
	local p = new_player("k2_rage", {level = 30})
	local mob = new_mob("wolf", 0, 2)
	rank(p, {ruin_mighty_blow = 1})
	G.add_rage(p, 30)
	local t = swing(p, R.mighty_blow, mob)
	land(p, t, mob)
	eq(G.get_rage(p), 13, "K2 Mighty Blow: 30 - 25 + 8")
	local t2 = swing(p, R.mighty_blow, mob)
	check(t2 and t2.proc == nil, "K2 at 13 rage a plain swing")
	clear_scene()
end

------------------------------------------------------------------------------
-- K3: Retort's window.
------------------------------------------------------------------------------
local function hit(p, from)
	for _, fn in ipairs(callbacks.settled_hit or {}) do
		fn(p, 5, {type = "punch", object = from})
	end
end
do
	local p = new_player("k3", {level = 60})
	local mob = new_mob("wolf", 0, 2)
	local S = base_pool(60) / 8
	hit(p, mob)
	check(not C.get_window(p, "retort"), "K3 no Retort rank: a hit readies nothing")
	rank(p, {bulwark_retort = 1})
	near(swing(p, R.retort, mob).scaled_damage, S, "K3 an unready Retort swings S")
	reset_log()
	hit(p, mob)
	check(C.get_window(p, "retort") ~= nil, "K3 a hit that took health readies Retort")
	eq(log.procs[1], "retort", "K3 ...with the Retort proc flash")
	check(log.statuses[1] and log.statuses[1].id == "retort", "K3 ...and its status icon")
	local t = swing(p, R.retort, mob)
	near(t.scaled_damage, 1.25 * S, "K3 a readied Retort: 1.25 S", 1)
	land(p, t, mob, {landed = false})
	check(C.get_window(p, "retort") ~= nil, "K3 a missed Retort keeps the window")
	reset_log()
	t = swing(p, R.retort, mob)
	land(p, t, mob)
	check(C.get_window(p, "retort") == nil, "K3 a landed Retort consumes it")
	eq(#log.heals, 0, "K3 no Recover rank: no heal")
	local ids = {}
	for _, e in ipairs(log.fx) do ids[#ids + 1] = e.id end
	check(table.concat(ids, ","):find("retort_hit", 1, true) ~= nil, "K3 the Retort hit effect")
	near(swing(p, R.retort, mob).scaled_damage, S, "K3 the next Retort is plain again", 1)
	-- The ICD: 6 s from the opening.
	hit(p, mob)
	check(C.get_window(p, "retort") == nil, "K3 the 6 s ICD holds a second readiness")
	-- The window and the ICD on a fresh player, the clock in hand.
	local q = new_player("k3b", {level = 60})
	rank(q, {bulwark_retort = 1, bulwark_measured_answer = 3, bulwark_recover = 3})
	hit(q, mob)
	wait(3.9)
	check(C.get_window(q, "retort") ~= nil, "K3 the window lasts 4 s")
	wait(0.2)
	check(C.get_window(q, "retort") == nil, "K3 ...and runs out after 4 s")
	wait(1.0)
	hit(q, mob)
	check(C.get_window(q, "retort") == nil, "K3 5.1 s after: still in the ICD")
	wait(1.0)
	hit(q, mob)
	check(C.get_window(q, "retort") ~= nil, "K3 6.1 s after: ready again")
	current_target = mob
	local before = #transactions
	input_api.swing(q, R.retort)
	t = transactions[before + 1]
	near(t.scaled_damage, 1.40 * S, "K3 Measured Answer 3: 1.40 S", 1)
	reset_log()
	land(q, t, mob)
	check(log.heals[1] and log.heals[1].target == q and log.heals[1].opts.no_crit == true,
		"K3 Recover heals the warrior, never critical")
	near(log.heals[1] and log.heals[1].amount, 0.02 * base_pool(60), "K3 Recover 3: 2 % P")
	rank(q, {bulwark_retort = 1, bulwark_measured_answer = 1, bulwark_recover = 1})
	near(R.retort.values(q).bonus, 0.30, "K3 Measured Answer 1: 0.30 S")
	near(R.retort.values(q).heal, 0.007 * base_pool(60), "K3 Recover 1: 0.7 % P")
	-- Only a Retort swing cashes it in: Mighty Blow neither consumes nor gains.
	local w = new_player("k3c", {level = 60})
	rank(w, {bulwark_retort = 1, ruin_mighty_blow = 1})
	hit(w, mob)
	G.add_rage(w, 100)
	current_target = mob
	before = #transactions
	input_api.swing(w, R.mighty_blow)
	t = transactions[before + 1]
	near(t.scaled_damage, 1.45 * S, "K3 a Mighty Blow takes no Retort bonus", 1)
	land(w, t, mob)
	check(C.get_window(w, "retort") ~= nil, "K3 ...and leaves the window open")
	-- A self-inflicted punch does not count.
	local z = new_player("k3d", {level = 60})
	rank(z, {bulwark_retort = 1})
	hit(z, z)
	check(C.get_window(z, "retort") == nil, "K3 a punch from oneself readies nothing")
	clear_scene()
end

------------------------------------------------------------------------------
-- K4: Ruination.
------------------------------------------------------------------------------
do
	local p = new_player("k4", {level = 60})
	local mob = new_mob("wolf", 0, 2)
	local S = base_pool(60) / 8
	rank(p, {ruin_mighty_blow = 1, ruin_ruination = 1})
	G.add_rage(p, 20)
	reset_log()
	check(G.try_cast(p, R.ruination, nil, function() end), "K4 Ruination casts")
	eq(G.get_rage(p), 0, "K4 ...for 20 rage")
	check(not G.ready(p, "ruination"), "K4 ...and its 60 s cooldown")
	local window = C.get_window(p, "ruination")
	near(window and (window.expiry_us - now_us) / 1e6, 8, "K4 the window lasts 8 s")
	eq(log.fx[1] and log.fx[1].id, "ruination", "K4 the cast effect")
	eq(select(2, input_api.cast_refusal(p, R.charge)), "busy", "K4 a cast right after waits")
	wait(0.36)
	eq(input_api.cast_refusal(p, R.charge), nil, "K4 ...0.35 s")
	current_target = mob
	local before = #transactions
	input_api.swing(p, R.strike)
	local t = transactions[before + 1]
	near(t.scaled_damage, 1.15 * S, "K4 a swing in the window: x1.15", 1)
	reset_log()
	land(p, t, mob)
	eq(G.get_rage(p), 10, "K4 a landed swing: 8 + 2 rage")
	eq(log.fx[#log.fx].id, "ruination_swing", "K4 ...with the swing effect")
	t = swing(p, R.strike, mob)
	land(p, t, mob, {landed = false})
	eq(G.get_rage(p), 10, "K4 a missed swing gains nothing")
	G.add_rage(p, 90)
	-- A proc in the window: Mighty Blow 1.45 S x 1.15.
	local q = new_player("k4b", {level = 60})
	rank(q, {ruin_mighty_blow = 1, ruin_ruination = 1, ruin_long_fury = 3})
	G.add_rage(q, 100)
	G.try_cast(q, R.ruination, nil, function() end)
	window = C.get_window(q, "ruination")
	near(window and (window.expiry_us - now_us) / 1e6, 9.5, "K4 Long Fury 3: 9.5 s")
	current_target = mob
	before = #transactions
	input_api.swing(q, R.mighty_blow)
	t = transactions[before + 1]
	near(t.scaled_damage, 1.45 * 1.15 * S, "K4 Mighty Blow in the window: 1.45 S x 1.15", 1)
	-- Review F1 (Round 46 ruling 9): Ruination's +2 scales with the base
	-- interval, so a dagger (0.7 s) and a battle axe (1.4 s) gain the same
	-- rage per second in the window.
	local per_second = {}
	for _, weapon in ipairs({{"dagger", 0.7}, {"axe", 1.4}}) do
		local w = new_player("k4_" .. weapon[1], {level = 60})
		rank(w, {ruin_ruination = 1})
		G.add_rage(w, 20)
		G.try_cast(w, R.ruination, nil, function() end)
		G.base_swing_interval = function() return weapon[2] end
		local tr = swing(w, R.strike, mob)
		land(w, tr, mob)
		per_second[#per_second + 1] = G.get_rage(w) / weapon[2]
		near(G.get_rage(w), (8 + 2) * weapon[2], "K4 Ruination with a " .. weapon[1] ..
			": (8 + 2) x " .. weapon[2] .. " rage per landed swing")
		G.base_swing_interval = function() return 1.0 end
	end
	near(per_second[1], per_second[2], "K4 ...the same rage per second with a dagger and a battle axe")
	rank(q, {ruin_mighty_blow = 1, ruin_ruination = 1, ruin_long_fury = 1})
	near(8 + G.family_bonus(q, R.ruination, "duration_add"), 8.5, "K4 Long Fury 1: 8.5 s")
	wait(10)
	check(C.get_window(q, "ruination") == nil, "K4 the window ends")
	clear_scene()
end

------------------------------------------------------------------------------
-- K5: Broadstroke's others (the cone, the cap, valid_target).
------------------------------------------------------------------------------
do
	local p = new_player("k5", {level = 60, faction = "accord", flagged = true})
	local S = base_pool(60) / 8
	local unit = base_hit(60)
	local primary = new_mob("primary", 0, 1.5)
	local a = new_mob("a", 0.5, 2)
	local b = new_mob("b", -1, 2)
	local c = new_mob("c", 1, 2.5)
	local behind = new_mob("behind", 0, -2)
	local far = new_mob("far", 0, 3.5)
	local friendly = new_mob("friendly", 0.2, 1, {faction = "accord"})
	local unflagged = new_player("unflagged", {faction = "throng", z = 1.2, x = -0.2})
	local ally = new_player("ally", {faction = "accord", flagged = true, z = 1.1})
	rank(p, {ruin_mighty_blow = 1, ruin_broadstroke = 1})
	G.add_rage(p, 100)
	local t = swing(p, R.broadstroke, primary)
	reset_log()
	land(p, t, primary)
	local hits = {}
	for _, d in ipairs(log.damage) do hits[#hits + 1] = d.target.name end
	eq(table.concat(hits, ","), "a,b", "K5 the two nearest others in the arc, never the primary, " ..
		"one behind, out of range, a friendly mob, an unflagged or same-faction player")
	near(log.damage[1] and log.damage[1].amount, 0.35 * unit, "K5 others take 0.35 S (raw)")
	near(log.damage[1] and log.damage[1].amount * level_scale(60), 0.35 * S, "K5 ...0.35 S scaled")
	eq(log.damage[1] and log.damage[1].opts.threat_mult, 3, "K5 ...with the tank threat")
	eq(log.fx[1] and log.fx[1].id, "broadstroke", "K5 the Broadstroke effect")
	local _ = {c, behind, far, friendly, unflagged, ally}
	-- Follow Through and Ruination; a flagged enemy player is a target.
	clear_scene()
	p = new_player("k5b", {level = 60, faction = "accord", flagged = true})
	primary = new_mob("primary", 0, 1.5)
	local foe = new_player("foe", {faction = "throng", flagged = true, z = 2})
	rank(p, {ruin_mighty_blow = 1, ruin_broadstroke = 1, ruin_follow_through = 3,
		ruin_ruination = 1})
	G.add_rage(p, 100)
	C.open_window(p, "ruination", {duration = 8})
	t = swing(p, R.broadstroke, primary)
	reset_log()
	land(p, t, primary)
	eq(log.damage[1] and log.damage[1].target, foe, "K5 a flagged enemy player is a target")
	near(log.damage[1] and log.damage[1].amount, 0.50 * unit * 1.15,
		"K5 Follow Through 3 and Ruination: 0.50 S x 1.15")
	rank(p, {ruin_mighty_blow = 1, ruin_broadstroke = 1, ruin_follow_through = 1})
	C.consume_window(p, "ruination")
	t = swing(p, R.broadstroke, primary)
	reset_log()
	land(p, t, primary)
	near(log.damage[1] and log.damage[1].amount, 0.40 * unit, "K5 Follow Through 1: 0.40 S")
	-- Nobody else around: the primary alone.
	clear_scene()
	p = new_player("k5c", {level = 60})
	primary = new_mob("primary", 0, 1.5)
	rank(p, {ruin_mighty_blow = 1, ruin_broadstroke = 1})
	G.add_rage(p, 100)
	t = swing(p, R.broadstroke, primary)
	reset_log()
	land(p, t, primary)
	eq(#log.damage, 0, "K5 alone: no other target")
	clear_scene()
end

------------------------------------------------------------------------------
-- K6: Hamstring.
------------------------------------------------------------------------------
do
	local p = new_player("k6", {level = 30, faction = "accord", flagged = true})
	local mob = new_mob("wolf", 0, 2)
	rank(p, {ruin_hamstring = 1})
	G.add_rage(p, 100)
	local t = swing(p, R.hamstring, mob)
	check(t.proc == R.hamstring, "K6 Hamstring fires")
	reset_log()
	land(p, t, mob)
	local s = log.slows[1]
	check(s and s.ent == mob.ent and math.abs(s.d - 3) < 1e-9 and math.abs(s.factor - 0.65) < 1e-9,
		"K6 a 35 % slow for 3 s, no root")
	eq(G.get_rage(p), 98, "K6 10 rage paid, 8 gained")
	check(not G.charge_ready(p, R.hamstring), "K6 the 8 s charge runs")
	wait(7.9)
	check(not G.charge_ready(p, R.hamstring), "K6 ...still at 7.9 s")
	wait(0.2)
	check(G.charge_ready(p, R.hamstring), "K6 ...ready at 8 s")
	rank(p, {ruin_hamstring = 1, ruin_clean_cut = 3})
	local foe = new_player("foe6", {faction = "throng", flagged = true, z = 2})
	t = swing(p, R.hamstring, foe)
	reset_log()
	land(p, t, foe)
	local m = log.mods[1]
	check(m and m.target == foe and m.name == "hamstring" and math.abs(m.speed + 0.35) < 1e-9 and
		math.abs(m.d - 4.5) < 1e-9, "K6 Clean Cut 3 on a player: -35 % for 4.5 s")
	clear_scene()
end

------------------------------------------------------------------------------
-- K7: Hold Ground, Unbroken (levels 10, 30, 60).
------------------------------------------------------------------------------
do
	for _, level in ipairs(LEVELS) do
		local P = base_pool(level)
		local L = " at level " .. level
		local p = new_player("k7_" .. level, {level = level})
		rank(p, {bulwark_hold_ground = 1, bulwark_unbroken = 1})
		G.add_rage(p, 100)
		reset_log()
		check(G.try_cast(p, R.hold_ground, nil, function() end), "K7 Hold Ground casts" .. L)
		local a = log.absorbs[1]
		check(a and a.id == "hold_ground" and a.duration == 5, "K7 a 5 s shield" .. L)
		near(a and a.amount, 0.12 * P, "K7 Hold Ground 0.12 P" .. L)
		eq(log.immunity, 0, "K7 no immunity" .. L)
		eq(G.get_rage(p), 75, "K7 25 rage" .. L)
		wait(0.36)
		reset_log()
		check(G.try_cast(p, R.unbroken, nil, function() end), "K7 Unbroken casts" .. L)
		local st, ab
		for _, s in ipairs(log.statuses) do if s.id == "unbroken" then st = s end end
		for _, x in ipairs(log.absorbs) do if x.id == "unbroken" then ab = x end end
		near(st and st.def.modifiers.armor, 0.5 * armor_k(level), "K7 Unbroken +0.50 K armor" .. L)
		near(st and st.def.duration, 8, "K7 ...for 8 s" .. L)
		near(ab and ab.amount, 0.15 * P, "K7 a 0.15 P shield" .. L)
		near(ab and ab.duration, 8, "K7 ...expiring with it" .. L)
		eq(G.get_rage(p), 50, "K7 25 rage again" .. L)
		clear_scene()
	end
	local p = new_player("k7_talents", {level = 60})
	local P = base_pool(60)
	rank(p, {bulwark_hold_ground = 1, bulwark_layered_guard = 1, bulwark_gather_yourself = 1,
		bulwark_unbroken = 1, bulwark_enduring_stand = 1})
	near(R.hold_ground.values(p).absorb, 0.15 * P, "K7 Layered Guard 1: 0.15 P")
	eq(G.effective_cooldown(p, R.hold_ground), 23, "K7 Gather Yourself 1: 23 s")
	near(R.unbroken.values(p).duration, 8.5, "K7 Enduring Stand 1: 8.5 s")
	rank(p, {bulwark_hold_ground = 1, bulwark_layered_guard = 3, bulwark_gather_yourself = 3,
		bulwark_unbroken = 1, bulwark_enduring_stand = 3})
	near(R.hold_ground.values(p).absorb, 0.21 * P, "K7 Layered Guard 3: 0.21 P")
	eq(G.effective_cooldown(p, R.hold_ground), 21, "K7 Gather Yourself 3: 21 s")
	near(R.unbroken.values(p).duration, 9.5, "K7 Enduring Stand 3: 9.5 s")
	check(R.hold_ground.description_for(p, R.hold_ground):find(tostring(math.floor(0.21 * P)), 1, true),
		"K7 Hold Ground's tooltip shows the current shield")
	rank(p, {ruin_onset = 1})
	eq(G.effective_cooldown(p, R.charge), 9.5, "K7 Onset 1: Charge 9.5 s")
	rank(p, {ruin_onset = 3})
	eq(G.effective_cooldown(p, R.charge), 8.5, "K7 Onset 3: Charge 8.5 s")
	rank(p, {ruin_stoke = 1})
	near(G.swing_rage(p, 1.0), 9, "K7 Stoke 1: 9 rage per swing")
	clear_scene()
end

------------------------------------------------------------------------------
-- K8: Taunt and Bellow.
------------------------------------------------------------------------------
do
	local p = new_player("k8", {level = 30, faction = "accord", flagged = true})
	local near_mob = new_mob("near", 2, 2)
	local behind = new_mob("behind", -3, -3)
	local out = new_mob("out", 0, 6.5)
	local friendly = new_mob("friendly", 1, 0, {faction = "accord"})
	local calm = new_mob("calm", 0, 1, {noncombatant = true})
	local foe = new_player("foe8", {faction = "throng", flagged = true, z = 1})
	rank(p, {bulwark_taunt = 1, bulwark_bellow = 1})
	reset_log()
	check(G.try_cast(p, R.bellow, nil, function() end), "K8 Bellow casts")
	table.sort(log.taunts)
	eq(table.concat(log.taunts, ","), "behind,near",
		"K8 every hostile mob within 6 m around, never a friendly or calm mob or a player")
	eq(near_mob.ent.attacked + behind.ent.attacked, 2, "K8 ...each turns on the warrior")
	eq(log.fx[1] and log.fx[1].id, "bellow", "K8 the Bellow ring")
	near(log.fx[1] and log.fx[1].frame.reach, 6, "K8 ...to 6 m")
	check(not G.ready(p, "taunt"), "K8 Bellow arms Taunt's cooldown key")
	local _ = {out, friendly, calm, foe}
	clear_scene()
	p = new_player("k8b", {level = 30})
	new_mob("out", 0, 7)
	rank(p, {bulwark_taunt = 1, bulwark_bellow = 1})
	local said
	check(not G.try_cast(p, R.bellow, nil, function(m) said = m end), "K8 nobody in range: refused")
	eq(said, "No hostile target in range.", "K8 ...with the reason")
	check(G.ready(p, "taunt"), "K8 ...and no cooldown spent")
	-- Taunt on its own: one mob in the crosshair.
	rank(p, {bulwark_taunt = 1})
	local mob = new_mob("target", 0, 4)
	current_target = mob
	reset_log()
	check(G.try_cast(p, R.taunt, nil, function() end), "K8 Taunt casts at its target")
	eq(table.concat(log.taunts, ","), "target", "K8 ...on that one mob")
	clear_scene()
end

------------------------------------------------------------------------------
-- K9: tooltips name the current numbers.
------------------------------------------------------------------------------
do
	local p = new_player("k9", {level = 60})
	rank(p, all_ranks("bulwark_retort", "bulwark_measured_answer", "bulwark_recover",
		"ruin_mighty_blow", "ruin_broadstroke", "ruin_follow_through", "ruin_ruination",
		"ruin_long_fury", "ruin_hamstring", "ruin_clean_cut", "ruin_reach_the_fight",
		"bulwark_halt"))
	local S = base_pool(60) / 8
	local text = R.retort.description_for(p, R.retort)
	check(text:find("+40%", 1, true) and text:find(tostring(math.floor(0.4 * S)), 1, true) and
		text:find(tostring(math.floor(0.02 * base_pool(60))), 1, true),
		"K9 Retort's tooltip: +40 %, its damage and the heal (" .. text .. ")")
	text = R.broadstroke.description_for(p, R.broadstroke)
	check(text:find("145%", 1, true) and text:find("50%", 1, true),
		"K9 Broadstroke's tooltip: 145 % and the others' 50 % (" .. text .. ")")
	check(R.ruination.description_for(p, R.ruination):find("9.5 s", 1, true),
		"K9 Ruination's tooltip: 9.5 s")
	check(R.hamstring.description_for(p, R.hamstring):find("4.5 s", 1, true),
		"K9 Hamstring's tooltip: 4.5 s")
	text = R.charge.description_for(p, R.charge)
	check(text:find("20 rage", 1, true) and text:find("0.75 s", 1, true) and
		text:find("30%", 1, true), "K9 Charge's tooltip: 20 rage, 0.75 s, Halt 30 % (" .. text .. ")")
	clear_scene()
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error(("R53 WARRIOR PORTABLE FAIL %d of %d checks"):format(failures, checks))
end
print("R53 WARRIOR PORTABLE PASS checks=" .. checks)
