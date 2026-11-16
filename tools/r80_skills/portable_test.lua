-- Round 80 lane SKILLS portable test (LuaJIT; round80-plan.md rulings 10 and
-- 12, §4 SKILLS):
--
--   luajit tools/r80_skills/portable_test.lua [repo]
--
-- The sandbox is tools/r69_skills' (the REAL grug_abilities/init.lua with its
-- whole dofile chain, talent_windows.lua, grug_core/area.lua, the REAL talent
-- graph and talent_graph_ui.lua), with an aimable crosshair and logged heals.
--   H  instant heals refuse full health through the real try_cast: Heal on
--      yourself and on an aimed ally at full health is refused with its
--      message, no mana, no cooldown, no Clear Conscience window; one missing
--      hit point casts; Hearten is refused only when everyone it would heal
--      is full; Mend, Haven and Shield cast at full health;
--   K  every skill of every class states its cost through the one
--      function, grug_abilities.cost_text, at levels 10, 30 and 60,
--      untalented and at full ranks: "N% base mana (M mana)" with M the
--      whole mana the cast charges, "N rage" or "free"; in the tooltip head,
--      the hotbar and catalogue stack, every granting talent node's tooltip
--      text and the strip under the tree; the node descriptions and the skill
--      texts state no cost of their own.
-- Prints "R80 SKILLS PORTABLE PASS checks=<n>" or the failures (exit 1).

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

local function slurp(path)
	local f = assert(io.open(path, "rb"))
	local data = f:read("*a")
	f:close()
	return data
end
local function cut(text, pattern, what)
	return assert(text:match(pattern), "no " .. what .. " in the source")
end

------------------------------------------------------------------------------
-- The graph: all four classes.
------------------------------------------------------------------------------
local CLASSES = {warrior = {name = "Warrior", resource = "rage"},
	mage = {name = "Mage", resource = "mana"}, priest = {name = "Priest", resource = "mana"},
	scout = {name = "Scout", resource = "mana"}}
local graph
do
	local saved = grug_classes
	grug_classes = {registered_classes = CLASSES}
	dofile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph.lua")
	for class in pairs(CLASSES) do
		dofile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph_" .. class .. ".lua")
	end
	graph = grug_classes.graph
	grug_classes = saved
end
local function sums_of(ranks)
	local sums = {}
	for id, rank in pairs(ranks) do
		for key, values in pairs(graph.nodes[id].effects) do
			sums[key] = (sums[key] or 0) + values[rank]
		end
	end
	return sums
end
local function full_ranks(class)
	local ranks = {}
	for _, id in ipairs(graph.node_ids) do
		if graph.nodes[id].class == class then ranks[id] = graph.nodes[id].ranks end
	end
	return ranks
end

------------------------------------------------------------------------------
-- The sandbox.
------------------------------------------------------------------------------
local now_us = 1e9
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
function V.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
function V.normalize(v)
	local l = V.length(v)
	return l > 0 and V.multiply(v, 1 / l) or V.new(0, 0, 0)
end
function V.direction(a, b) return V.normalize(V.subtract(b, a)) end
function V.equals(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end

-- A stack: a name, its meta fields and, for a weapon, `spec`.
local Stack = {}
Stack.__index = Stack
local function ItemStack(value)
	if type(value) == "table" and getmetatable(value) == Stack then
		local copy = setmetatable({name = value.name, spec = value.spec, fields = {}}, Stack)
		for k, v in pairs(value.fields) do copy.fields[k] = v end
		return copy
	end
	local name = type(value) == "string" and value:match("^(%S*)") or ""
	return setmetatable({name = name, fields = {}}, Stack)
end
function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:get_count() return self.name == "" and 0 or 1 end
function Stack:to_string() return self.name end
function Stack:equals(other) return self.name == other.name and self.spec == other.spec end
function Stack:get_definition()
	local spec = self.spec or {}
	return {groups = spec.groups or {}, _grug_ilvl = spec.ilvl,
		tool_capabilities = {full_punch_interval = spec.fpi}}
end
function Stack:get_tool_capabilities()
	local spec = self.spec or {}
	return {full_punch_interval = spec.fpi, damage_groups = {fleshy = spec.damage}}
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
local function weapon(name, damage, fpi, groups, ilvl)
	local stack = ItemStack(name)
	stack.spec = {damage = damage, fpi = fpi, groups = groups, ilvl = ilvl}
	return stack
end

local LISTS = {"main", "grug_hotbar_store", "grug_bag1", "craft", "grug_weapon"}
local function new_inventory()
	local inv = {lists = {}}
	for _, l in ipairs(LISTS) do
		local list = {}
		for i = 1, 16 do list[i] = ItemStack("") end
		inv.lists[l] = list
	end
	function inv:get_size(l) return self.lists[l] and #self.lists[l] or 0 end
	function inv:get_stack(l, i) return ItemStack(self.lists[l][i]) end
	function inv:set_stack(l, i, s)
		self.writes = (self.writes or 0) + 1
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

local scene, players, serial = {}, {}, 0
local function new_player(class, level, opts)
	opts = opts or {}
	serial = serial + 1
	local p = {name = "p" .. serial, class = class, ranks = opts.ranks or {}, hp = 100,
		level = level, str = opts.str or 40, dex = opts.dex or 50, int = opts.int or 60,
		melee = opts.melee, weapon = opts.weapon, faction = "accord",
		pos = V.new(0, 0, 0), inv = new_inventory(), wield = 1}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return V.copy(self.pos) end
	function p:get_look_horizontal() return 0 end -- facing +z
	function p:get_look_dir() return V.new(0, 0, 1) end
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:get_wield_index() return self.wield end
	function p:get_meta() return ItemStack("x"):get_meta() end
	function p:get_properties() return {hp_max = self.hp_max or 100, eye_height = 1.5} end
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add() return 1 end
	function p:hud_change() end
	function p:hud_remove() end
	function p:punch() end
	players[p.name] = p
	scene[#scene + 1] = p
	return p
end
local function new_mob(x, z, yaw)
	local ent = {name = "wolf", _cmi_is_mob = true, health = 10, attack_type = "dogfight",
		temp = {}}
	function ent:do_attack() end
	local mob = {ent = ent, pos = V.new(x, 0, z), yaw = yaw or 0}
	ent.object = mob
	function mob:get_pos() return V.copy(self.pos) end
	function mob:is_player() return false end
	function mob:get_luaentity() return self.ent end
	function mob:get_hp() return self.ent.health end
	function mob:get_yaw() return self.yaw end
	function mob:get_properties() return {hp_max = 10} end
	function mob:punch() end
	scene[#scene + 1] = mob
	return mob
end
local function clear_scene()
	for k in pairs(scene) do scene[k] = nil end
end

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

local fake_core = with_any({
	register_on_dieplayer = capture("die"),
	register_on_leaveplayer = capture("leave"),
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_abilities" end,
	get_current_modname = function() return "grug_abilities" end,
	get_us_time = function() return now_us end,
	global_exists = function(n) return n == "grug_inventory" end,
	register_tool = function() end,
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
	formspec_escape = function(text)
		return (tostring(text):gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	colorize = function(_, text) return text end,
})

local log = {damage = {}, shots = {}, heals = {}, absorbs = {}, statuses = {}}
local melee_prepare, melee_finish
local transactions = {}
-- The crosshair: nil aims at nothing (a support skill resolves to the caster).
local aim
local fake_grug_core = with_any({
	get_melee_weapon = function(p) return p.melee and ItemStack(p.melee) or nil end,
	get_equipped_weapon = function(p) return p.weapon and ItemStack(p.weapon) or nil end,
	equipment_is_broken = function() return false end,
	is_stunned = function() return false end,
	get_player_level = function(p) return p.level end,
	register_native_melee_handler = function(prepare, finish)
		melee_prepare, melee_finish = prepare, finish
	end,
	register_on_settled_incoming_hit = capture("settled_hit"),
	register_on_equipment_change = capture("equipment"),
	register_on_status_modifiers_changed = capture("status"),
	particles = {play = function() end, facing = function() return V.new(0, 0, 1) end},
	proc_flash = function() end,
	deal_ability_damage = function(_, _, amount, opts)
		log.damage[#log.damage + 1] = amount
		return amount
	end,
	add_absorb = function(target, id, amount)
		log.absorbs[#log.absorbs + 1] = {target = target, id = id, amount = amount}
		return amount
	end,
	heal_player = function(_, target, amount)
		log.heals[#log.heals + 1] = {target = target, amount = amount}
		return amount
	end,
	set_status = function(target, id)
		log.statuses[#log.statuses + 1] = {target = target, id = id}
	end,
	combat_eye_pos = function(p) return V.offset(p.pos, 0, 1.5, 0) end,
	combat_ray = function()
		return aim or {status = "miss", reason = "empty"}
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
	graph = graph,
	registered_classes = CLASSES,
	get_class = function(p) return p.class end,
	get_class_def = function(p) return CLASSES[p.class] end,
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
	get_melee_bonus = function(p) return (p.class == "scout" and p.dex or p.str) / 10 end,
	get_ranged_bonus = function(p) return p.dex / 10 end,
	get_spell_power_bonus = function(p) return p.int / 10 end,
	get_support_factor = function(p) return p.support or 1 end,
	get_spell_damage_percent = function(p) return p.spell_percent or 0 end,
	get_race_perk = function() return nil end,
	get_max_mana = function() return 1e6 end,
	register_on_class_chosen = capture("class_chosen"),
	register_on_talents_changed = capture("talents"),
	pool_percent_amount = function(_, _, percent) return percent end,
})
local fake_inventory = with_any({
	HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
	content_list = function(i) return "grug_bag" .. i end,
	get_cosmetic_hand = function() return nil end,
	hand_list = function() return "grug_weapon" end,
	melee_list = function() return "grug_weapon" end,
	equipment_changed = function() end,
	is_bow = function(stack) return (stack:get_definition().groups.bow or 0) > 0 end,
	ammo_count = function() return 99 end,
	consume_ammo = function() return true end,
})
local fake_projectiles = with_any({
	register = function() end,
	spawn = function(_, spec)
		log.shots[#log.shots + 1] = spec.data
		return true
	end,
	spawn_batch = function(_, launches, take)
		take()
		log.shots[#log.shots + 1] = launches[1].data
		return true
	end,
})
local env = setmetatable({
	core = fake_core, ItemStack = ItemStack, vector = V,
	grug_core = fake_grug_core, grug_classes = fake_classes,
	grug_inventory = fake_inventory, grug_projectiles = fake_projectiles,
	grug_mobs = with_any({is_noncombatant = function() return false end}),
	grug_xp = with_any({get_level = function(p) return p.level end,
		register_on_level_change = capture("level")}),
	grug_factions = with_any({
		get_faction = function(p) return p.faction end,
		same_faction = function(a, b) return a.faction == b.faction end,
		hostile = function(a, b) return a.faction ~= b.faction end,
	}),
	grug_pvp = with_any({can_harm = function() return false end,
		can_support = function() return true end}),
}, {__index = function(_, k)
	local g = rawget(_G, k)
	if g ~= nil and k ~= "core" and k ~= "minetest" and k ~= "grug_core" and
			k ~= "vector" and k ~= "ItemStack" and k ~= "grug_classes" then return g end
	return any()
end})
local input_api
env.dofile = function(path)
	local result = setfenv(assert(loadfile(path)), env)()
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
-- The game's curves and the one scaling pass, from their own source.
setfenv(assert(loadstring(cut(slurp(ROOT .. "/mods/CORE/grug_core/combat.lua"),
	"(function grug_core%.base_pool%(level%).-\nfunction grug_core%.scale_player_damage.-\nend)\n",
	"the curves") .. "\n" .. cut(slurp(ROOT .. "/mods/CORE/grug_core/combat.lua"),
	"(function grug_core%.armor_k%(attacker_level%).-\nend)\n", "armor_k"))), env)()
-- wrap_text, from grug_inventory/ui.lua.
setfenv(assert(loadstring(cut(slurp(ROOT .. "/mods/PLAYER/grug_inventory/ui.lua"),
	"(function grug_inventory%.wrap_text%(value, width%).-\nend)\n", "wrap_text"))), env)()
env.dofile(ROOT .. "/mods/CORE/grug_core/status_icons.lua")
env.dofile(ROOT .. "/mods/CORE/grug_core/area.lua")
env.dofile(ROOT .. "/mods/PLAYER/grug_abilities/init.lua")
env.dofile(ROOT .. "/mods/PLAYER/grug_classes/talent_windows.lua")
dofile(ROOT .. "/tools/r78_armor/format_armor.lua")(ROOT) -- Round 78: ratings shown x10
env.dofile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph_ui.lua")
setfenv(graph.level_amount, env) -- the graph loaded before the sandbox existed
local G, C = env.grug_abilities, fake_classes
local R = G.registered
check(G and R.heal and R.hearten and G.cost_text and graph.node_text and C.open_window,
	"setup: the real kit, the windows and the real tree text load")
local function wait(seconds) now_us = now_us + seconds * 1e6 end
local function cast(p, id)
	local said
	local ok = G.try_cast(p, R[id], nil, function(message) said = message end)
	return ok, said
end
local function reset_log()
	for _, list in pairs(log) do
		for i = #list, 1, -1 do list[i] = nil end
	end
end

------------------------------------------------------------------------------
-- H: instant heals at full health (ruling 10).
------------------------------------------------------------------------------
do
	clear_scene()
	local p = new_player("priest", 30, {ranks = {mercy_clear_conscience = 3, mercy_shield = 1,
		mercy_mend = 1, mercy_hearten = 1, mercy_haven = 1}})
	G.restore_mana(p, 1e6)
	local full = G.get_mana(p)
	aim = nil
	reset_log()
	local ok, said = cast(p, "heal")
	check(not ok, "H Heal on yourself at full health is refused")
	eq(said, "Target is at full health.", "H ... with its message")
	eq(G.get_mana(p), full, "H ... no mana spent")
	check(G.ready(p, "heal"), "H ... no cooldown")
	eq(#log.heals, 0, "H ... nobody healed")
	eq(C.get_window(p, "clear_conscience"), nil, "H ... no Clear Conscience window")
	-- One missing hit point casts.
	p.hp = 99
	ok = cast(p, "heal")
	check(ok, "H one missing hit point: Heal casts")
	eq(full - G.get_mana(p), G.effective_cost(p, R.heal).mana, "H ... and costs its mana")
	check(not G.ready(p, "heal"), "H ... and starts its cooldown")
	check(#log.heals == 1 and log.heals[1].target == p, "H ... on the caster")
	check(C.get_window(p, "clear_conscience") ~= nil, "H ... and opens Clear Conscience")
	-- An aimed ally at full health: refused, never the hurt caster instead.
	wait(20)
	local ally = new_player("warrior", 30)
	ally.pos = V.new(0, 0, 3)
	aim = {status = "target", reason = "friendly", target = ally}
	reset_log()
	local before = G.get_mana(p)
	ok, said = cast(p, "heal")
	check(not ok and said == "Target is at full health.", "H Heal at a full ally is refused (" ..
		tostring(said) .. ")")
	check(G.get_mana(p) == before and G.ready(p, "heal") and #log.heals == 0,
		"H ... no mana, no cooldown, nobody healed (the hurt caster neither)")
	ally.hp = 99
	ok = cast(p, "heal")
	check(ok and #log.heals == 1 and log.heals[1].target == ally, "H a hurt ally is healed")
	-- Hearten: refused only when everyone it would heal is at full health.
	wait(20)
	aim = nil
	p.hp, ally.hp = 100, 100
	ally.pos = V.new(2, 0, 0)
	reset_log()
	before = G.get_mana(p)
	ok, said = cast(p, "hearten")
	check(not ok and said == "Everyone is at full health.", "H Hearten, everyone full: refused (" ..
		tostring(said) .. ")")
	check(G.get_mana(p) == before and G.ready(p, "hearten") and #log.heals == 0,
		"H ... no mana, no cooldown, nobody healed")
	ally.hp = 99
	ok = cast(p, "hearten")
	check(ok and #log.heals == 2, "H one hurt ally: Hearten casts on both")
	check(not G.ready(p, "hearten"), "H ... and starts its cooldown")
	wait(30)
	ally.hp, p.hp = 100, 99
	reset_log()
	check(cast(p, "hearten"), "H the hurt caster alone: Hearten casts")
	-- An ally out of reach does not count.
	wait(30)
	p.hp, ally.hp = 100, 50
	ally.pos = V.new(0, 0, 20)
	ok, said = cast(p, "hearten")
	check(not ok and said == "Everyone is at full health.", "H a hurt ally out of reach does not count")
	-- Heal over time and the absorb cast at full health.
	p.hp, ally.hp = 100, 100
	for _, id in ipairs({"mend", "haven", "shield_spell"}) do
		wait(70)
		reset_log()
		check(cast(p, id), "H " .. id .. " casts at full health")
	end
	clear_scene()
end

------------------------------------------------------------------------------
-- K: every skill states its cost through one function (ruling 12).
------------------------------------------------------------------------------
-- The oracle: the definition's cost, the family key cost_pct, the
-- definition's own adjustment, and the charge's own rounding.
local function expected_cost(p, def)
	local cost = G.effective_cost(p, def)
	if def.cost.mana_percent then
		local pct = def.cost.mana_percent * (1 + G.family_bonus(p, def, "cost_pct") / 100)
		local base = fake_grug_core.base_pool(p.level)
		local charge = math.max(1, math.floor(base * pct / 100 + 0.5))
		eq(cost.mana, charge, "K " .. def.id .. " the cast charges the share of the base pool")
		return ("%g%% base mana (%d mana)"):format(pct, charge)
	elseif def.cost.rage then
		return cost.rage .. " rage"
	end
	check(not def.cost.mana, "K " .. def.id .. " no flat mana cost is shipped")
	return "free"
end

-- The talent page's strip, as page_content draws it for a selected node.
fake_grug_core.ui = {
	panel = function() return "" end,
	navigation_style = function() return "" end,
	text_scale = function() return 1 end,
	text_growth = function() return 1 end,
	font_size = function() return 16 end,
}
fake_inventory.selected_button_style = function() return "" end
fake_classes.TALENT_NODE_STYLES = {buyable = "", maxed = "", ranked = "", locked = ""}
fake_classes.TALENT_CONNECTOR_COLORS = {met = "#fff", open = "#888"}
local function strip_of(p, node)
	local fs = graph.page_content(p, {trees = {graph.trees[node.tree]}, tab = 1, ranks = p.ranks,
		budget = 0, selected = node.id})
	return fs:match("textarea%[[%d%.,;]-;;;(.-[^\\])%]")
end

local shown = {} -- ability id -> true once its cost text was seen
local granting = 0
for _, level in ipairs({10, 30, 60}) do
	for _, tier in ipairs({"bare", "full"}) do
		for _, class in ipairs({"warrior", "mage", "priest", "scout"}) do
			local p = new_player(class, level, {ranks = tier == "full" and full_ranks(class) or {}})
			local L = ("L%d %s %s"):format(level, tier, class)
			for id, def in pairs(R) do
				if def.class == class or def.universal then
					local text = expected_cost(p, def)
					eq(G.cost_text(p, def), text, "K " .. L .. " " .. id .. " cost")
					check(not text:find("%.%d+ mana%)"), "K " .. L .. " " .. id .. " a whole mana number")
					local head = G.description_prefix(p, def)
					eq(head:match("^[^\n]*\n([^\n]*)"):sub(1, #text + 2), text .. ", ",
						"K " .. L .. " " .. id .. " the tooltip head starts its second line with it")
					local stack = ItemStack("grug_abilities:" .. id)
					G.update_stack_description(stack, def, p)
					check(stack:get_meta():get_string("description"):find("\n" .. text .. ", ", 1, true),
						"K " .. L .. " " .. id .. " the hotbar and catalogue stack")
					shown[id] = true
				end
			end
			for _, node_id in ipairs(graph.node_ids) do
				local node = graph.nodes[node_id]
				if node.class == class and node.ability then
					granting = granting + 1
					local cost = " Cost: " .. G.cost_text(p, R[node.ability]) .. "."
					local text = graph.node_text(p, node)
					local _, count = text:gsub("Cost: ", "")
					check(count == 1 and text:find(cost, 1, true),
						"K " .. L .. " node " .. node_id .. " states its cost once (" .. text .. ")")
					check(text:sub(1, #node.description + #cost) == node.description .. cost,
						"K " .. L .. " node " .. node_id .. " the cost follows its description")
					if level == 60 then
						local strip = strip_of(p, node)
						check(strip and strip:find(fake_core.formspec_escape(cost), 1, true),
							"K " .. L .. " node " .. node_id .. " the strip states it (" ..
							tostring(strip) .. ")")
					end
				end
			end
		end
	end
end
clear_scene()
for id, def in pairs(R) do
	check(shown[id], "K " .. id .. " was checked")
end
check(granting >= 6 * 30, "K every granting node checked (" .. granting .. ")")
-- Without a player: the definition's cost, a share without its number.
eq(G.cost_text(nil, R.heal), "10% base mana", "K Heal's static cost")
eq(G.cost_text(nil, R.hold_ground), "25 rage", "K Hold Ground's static cost")
eq(G.cost_text(nil, R.smite), "free", "K Smite's static cost")
-- A talent's discount shows in the share and the number (Measured Care 3: 12 %).
do
	local p = new_player("priest", 60, {ranks = {mercy_measured_care = 3}})
	local pct = 10 * 0.88
	eq(G.cost_text(p, R.heal), ("%g%% base mana (%d mana)"):format(pct,
		math.floor(fake_grug_core.base_pool(60) * pct / 100 + 0.5)), "K Measured Care in the share and the number")
	clear_scene()
end
-- No skill text and no node description says a cost of its own.
local function own_cost(text)
	return text:find("%d+ ?%% mana") or text:find("%d+ rage[,.;]") or text:find("[Ff]ree[ ,.;]") or
		text:find("Spend ")
end
for id, def in pairs(R) do
	check(not own_cost(def.description), "K " .. id .. "'s description states no cost: " .. def.description)
	if def.description_for then
		local p = new_player(def.class or "warrior", 60, {ranks = def.class and full_ranks(def.class) or {}})
		local text = def.description_for(p, def)
		check(not own_cost(text), "K " .. id .. "'s text states no cost: " .. text)
		clear_scene()
	end
end
for _, node_id in ipairs(graph.node_ids) do
	local node = graph.nodes[node_id]
	if node.ability then
		check(not own_cost(node.description), "K node " .. node_id .. " states no cost: " .. node.description)
	end
end

if failures > 0 then
	error(("R80 SKILLS PORTABLE FAIL %d of %d checks"):format(failures, checks))
end
print("R80 SKILLS PORTABLE PASS checks=" .. checks)
