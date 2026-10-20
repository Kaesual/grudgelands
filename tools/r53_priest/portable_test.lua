-- Round 53 lane PRIEST portable test (LuaJIT; round53-plan.md §4 PRIEST and
-- §6 "Class fixtures"). Loads the REAL grug_abilities/init.lua with its whole
-- dofile chain in a sandbox (the tools/r52_bench and r53_hooks pattern), the
-- REAL priest talent graph (talent_graph.lua, talent_graph_priest.lua), the
-- REAL readiness windows (talent_windows.lua) and the REAL area helpers
-- (grug_core/area.lua) on a small node map, with the REAL level formulas cut
-- from grug_core/combat.lua. The oracle is the balance calculator's frozen
-- formulas (P, W, B, the spell unit W + I, the scalar S = P / 8B) written out
-- here independently, and its priest_mercy / priest_reckoning builds.
--
--   luajit tools/r53_priest/portable_test.lua [repo]
--
--   R  the kit: the ten Priest skills in their catalogue order; Smite the
--      class basic attack in Strike's place (no talent); every other granting
--      node's ability names that node as its `talent`, and back;
--   N  numbers at levels 10, 30 and 60, untalented and in each tree's sample
--      build: damage, heal, absorb, cost, cooldown, occupied time, range and
--      ticks against the calculator; its full-build rows at level 60;
--   T  each talent at rank 1 and full on its skills (Steady Word and
--      Sharpened Word max-combined, never summed);
--   X  the transform on both layouts, the starter hotbar (Smite, Heal), the
--      held fallback's basic attack (K8);
--   C  the clock: Smite's 1 s interval, the occupied times through the one
--      cast_refusal;
--   W  Clear Conscience: opened by Heal, Shield and Mend, spent by the next
--      Smite, its 5 s window and 8 s internal cooldown, none without ranks;
--   A  the areas: Censure's "No ground found." before cost and cooldown, its
--      ground anchor on flat ground, a stair and in a cave (the falling seal
--      under the ceiling), its 4 nearest in sight within the radius and band,
--      the impact cue once; Hearten and Haven pick you plus the neediest
--      allies in sight within their radius; an unflagged enemy player and a
--      same-faction player are never area targets, a flagged ally never
--      healed by an unflagged priest; Haven's ticks;
--   D  Word of Ruin heals half the damage up to its pool cap, never a crit;
--      the old talent API is gone from the kit.
-- Prints "R53 PRIEST PORTABLE PASS checks=<n>" or the failures (exit 1).

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
	return check(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-9),
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

------------------------------------------------------------------------------
-- The calculator's formulas (combat_stats.md §2, priest.md §2), independent
-- of the game's code: own-level staff, natural Intelligence 10 + 2(L - 1).
------------------------------------------------------------------------------
local function P(L) return math.floor(20 + 5 * L + 0.66 * L * L + 0.5) end
local function W(L) return math.floor(4 + 0.35 * L + 0.5) end
local function B(L) return W(L) + (10 + 3 * (L - 1)) / 10 end
local function U(L) return W(L) + (10 + 2 * (L - 1)) / 10 end
local function S(L) return P(L) / (8 * B(L)) end
-- One hit after the scalar: `coef` units with `pct` % on them, `add` base hits.
local function hit(L, coef, pct, add)
	return math.max(1, math.floor((coef * U(L) * (1 + pct / 100) + add * B(L)) * S(L)))
end
local function share(L, pct) return P(L) * pct / 100 end
local function mana(L, pct) return math.max(1, math.floor(P(L) * pct / 100 + 0.5)) end

------------------------------------------------------------------------------
-- A small world: stone below y = 0 (ground tops at y = -0.5), air above,
-- optional extra stone; objects with positions.
------------------------------------------------------------------------------
local vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x or 0, y = y or 0, z = z or 0}
end
function vector.copy(v) return vector.new(v) end
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(a, s) return vector.new(a.x * s, a.y * s, a.z * s) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.direction(a, b)
	local d = vector.subtract(b, a)
	local l = vector.length(d)
	return l > 0 and vector.multiply(d, 1 / l) or vector.new(0, 0, 0)
end

local extra_nodes = {}
local function nkey(x, y, z) return x .. "," .. y .. "," .. z end
local function node_at(x, y, z)
	if y < -40 then return nil end
	return extra_nodes[nkey(x, y, z)] or (y < 0 and "stone" or "air")
end
local REGISTERED = {air = {walkable = false, pointable = false}, stone = {walkable = true}}
local function raycast(from, to)
	local hits = {}
	local d = vector.subtract(to, from)
	local steps = math.max(1, math.ceil(vector.length(d) / 0.02))
	local function cell(p) return math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5) end
	local px, py, pz = cell(from)
	for i = 1, steps do
		local p = vector.add(from, vector.multiply(d, i / steps))
		local x, y, z = cell(p)
		if x ~= px or y ~= py or z ~= pz then
			local def = REGISTERED[node_at(x, y, z) or "stone"]
			if def.pointable ~= false then
				hits[#hits + 1] = {type = "node", under = {x = x, y = y, z = z},
					above = {x = px, y = py, z = pz}, intersection_point = p}
			end
			px, py, pz = x, y, z
		end
	end
	local index = 0
	return function() index = index + 1; return hits[index] end
end

local objects = {}
local now_us = 1e9
local function wait(s) now_us = now_us + s * 1e6 end
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
end

-- Item stacks and inventories (the r53_hooks shapes).
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
function Stack:get_definition() return {} end

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
local function row(inv, l, n)
	local out = {}
	for i = 1, n do out[i] = inv.lists[l][i].name:gsub("^grug_abilities:", "") end
	return table.concat(out, ",")
end

-- Actors. A player: class, level, ranks, faction, PvP flag, hp; a mob.
local players = {}
local function new_player(name, opts)
	opts = opts or {}
	local p = {name = name, class = opts.class or "priest", level = opts.level or 60,
		ranks = {}, sums = {}, hp = opts.hp or 100, hp_max = 100,
		faction = opts.faction or "accord", flagged = opts.flagged or false,
		pos = opts.pos or vector.new(0, 0, 0), inv = new_inventory(), wield = 1,
		player = true, q = 1}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:set_hp(v) self.hp = v end
	function p:get_pos() return vector.copy(self.pos) end
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:get_wield_index() return self.wield end
	function p:get_meta() return ItemStack("x"):get_meta() end
	function p:get_properties() return {hp_max = self.hp_max, eye_height = 1.47} end
	function p:get_look_horizontal() return 0 end
	function p:get_luaentity() return nil end
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add() return 1 end
	function p:hud_change() end
	function p:hud_remove() end
	players[name] = p
	objects[#objects + 1] = p
	return p
end
local function new_mob(name, pos)
	local m = {name = name, pos = pos, health = 100}
	function m:is_player() return false end
	function m:get_pos() return vector.copy(self.pos) end
	function m:get_hp() return self.health end
	function m:get_luaentity()
		return {name = "test:" .. self.name, _cmi_is_mob = true, health = self.health,
			temp = {}, _grug_cbox = {-0.4, 0, -0.4, 0.4, 1, 0.4}}
	end
	objects[#objects + 1] = m
	return m
end

------------------------------------------------------------------------------
-- The sandbox.
------------------------------------------------------------------------------
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
local function fire(kind, ...)
	for _, fn in ipairs(callbacks[kind] or {}) do fn(...) end
end
local jobs = {}
local fake_core = with_any({
	register_on_dieplayer = capture("die"),
	register_on_leaveplayer = capture("leave"),
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_abilities" end,
	get_current_modname = function() return "grug_abilities" end,
	get_us_time = function() return now_us end,
	global_exists = function(n) return n == "grug_inventory" end,
	register_tool = function() end,
	registered_items = {},
	registered_nodes = REGISTERED,
	get_item_group = function(name, group)
		return (group == "grug_ability" and name:find("^grug_abilities:")) and 1 or 0
	end,
	get_player_by_name = function(name) return players[name] end,
	log = function() end,
	get_node_or_nil = function(pos)
		local name = node_at(pos.x, pos.y, pos.z)
		return name and {name = name} or nil
	end,
	raycast = raycast,
	get_objects_in_area = function(minp, maxp)
		local out = {}
		for _, o in ipairs(objects) do
			local p = o.pos
			if p.x >= minp.x and p.x <= maxp.x and p.y >= minp.y and p.y <= maxp.y and
					p.z >= minp.z and p.z <= maxp.z then
				out[#out + 1] = o
			end
		end
		return out
	end,
	get_objects_inside_radius = function(centre, radius)
		local out = {}
		for _, o in ipairs(objects) do
			if vector.distance(o.pos, centre) <= radius then out[#out + 1] = o end
		end
		return out
	end,
	after = function(delay, fn)
		local job = {delay = delay, fn = fn}
		function job.cancel() job.cancelled = true end
		jobs[#jobs + 1] = job
		return job
	end,
	yaw_to_dir = function(yaw) return vector.new(-math.sin(yaw), 0, math.cos(yaw)) end,
})
local function run_jobs()
	local list = jobs
	jobs = {}
	for _, job in ipairs(list) do
		if not job.cancelled then job.fn() end
	end
	return #list
end

-- What the casts touched.
local log = {}
local function reset_log()
	log = {damage = {}, heals = {}, absorbs = {}, statuses = {}, fx = {}, sounds = {},
		flashes = {}, procs = {}, contacts = {}}
end
reset_log()

local aim -- the combat ray the next cast sees
local scale_damage -- the real scale_player_damage, cut from combat.lua below
local fake_grug_core = with_any({
	get_melee_weapon = function() return ItemStack("") end,
	is_stunned = function() return false end,
	get_player_level = function(p) return p.level or 60 end,
	combat_ray = function() return aim end,
	combat_debug_enabled = function() return false end,
	get_absorb = function() return 0 end,
	deal_ability_damage = function(attacker, target, amount, opts)
		local scaled = scale_damage(attacker, target, amount)
		log.damage[#log.damage + 1] = {target = target, amount = scaled, raw = amount,
			no_crit = opts and opts.no_crit}
		if opts and opts.on_accepted then opts.on_accepted(scaled, false, opts.action_id or {}) end
		return scaled
	end,
	heal_player = function(healer, target, amount, opts)
		log.heals[#log.heals + 1] = {healer = healer, target = target, amount = amount,
			no_crit = opts and opts.no_crit}
		return amount
	end,
	add_absorb = function(target, id, amount, duration, source)
		log.absorbs[#log.absorbs + 1] = {target = target, id = id, amount = amount,
			duration = duration, source = source}
		return amount
	end,
	set_status = function(target, id, def)
		log.statuses[#log.statuses + 1] = {target = target, id = id, def = def}
		return true
	end,
	clear_status = function() end,
	proc_flash = function(_, proc) log.procs[#log.procs + 1] = proc end,
	particles = {
		play = function(id, frame) log.fx[#log.fx + 1] = {id = id, frame = frame} end,
		facing = function() return vector.new(0, 0, 1) end,
	},
	status_icons = {WINDOWS = {clear_conscience = "clear_conscience"}},
	register_native_melee_handler = function() end,
})
-- The level formulas, cut from the real combat.lua (base_pool ...
-- scale_player_damage), so the game's own bytes are under test.
do
	local text = read("mods/CORE/grug_core/combat.lua")
	local from = assert(text:find("function grug_core.base_pool", 1, true))
	local to = assert(text:find("-- Same-level raw mob pressure", 1, true))
	local chunk = assert(loadstring(text:sub(from, to - 1)))
	setfenv(chunk, setmetatable({grug_core = fake_grug_core}, {__index = _G}))()
end
scale_damage = fake_grug_core.scale_player_damage

-- The priest graph: the real registry and data file.
local graph
do
	local gc = {registered_classes = registered_classes}
	local genv = setmetatable({grug_classes = gc,
		grug_core = {armor_k = function(level) return 20 + 0.5 * level end}}, {__index = _G})
	setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph.lua")), genv)()
	setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph_priest.lua")), genv)()
	graph = gc.graph
end
local function set_ranks(p, ranks)
	p.ranks, p.sums = {}, {}
	for _, id in ipairs(graph.node_ids) do
		local rank = ranks[id]
		if rank and rank > 0 then
			local def = assert(graph.nodes[id], id)
			p.ranks[id] = rank
			for key, values in pairs(def.effects) do
				p.sums[key] = (p.sums[key] or 0) + values[rank]
			end
		end
	end
end

local fake_classes = with_any({
	registered_classes = registered_classes,
	registered_talents = {},
	get_class = function(p) return p.class end,
	get_class_def = function(p) return registered_classes[p.class] end,
	talent_rank = function(p, id) return p.ranks[id] or 0 end,
	get_talent_bonus = function(p, key) return p.sums and p.sums[key] or 0 end,
	get_spell_power_bonus = function(p) return (10 + 2 * ((p.level or 60) - 1)) / 10 end,
	get_support_factor = function(p) return p.q or 1 end,
	get_spell_damage_percent = function() return 0 end,
	get_melee_bonus = function() return 0 end,
	get_race_perk = function() return nil end,
	get_max_mana = function() return 1e6 end,
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
local fake_pvp = {
	can_harm = function(a, b) return a.flagged and b.flagged end,
	can_support = function(h, t) return h.flagged or not t.flagged end,
	support_contact = function(h, t)
		if h ~= t then log.contacts[#log.contacts + 1] = t.name end
	end,
}
local fake_factions = {
	same_faction = function(a, b) return a.faction ~= nil and a.faction == b.faction end,
	hostile = function(a, b) return a.faction ~= b.faction end,
	get_faction = function(p) return p.faction end,
}
local fake_sounds = with_any({
	play = function(event, target) log.sounds[#log.sounds + 1] = {event = event, target = target} end,
})
local env = setmetatable({
	core = fake_core, ItemStack = ItemStack, vector = vector,
	grug_core = fake_grug_core, grug_classes = fake_classes,
	grug_inventory = fake_inventory, grug_pvp = fake_pvp, grug_factions = fake_factions,
	grug_sounds = fake_sounds, grug_mobs = with_any({is_noncombatant = function() return false end}),
}, {__index = function(_, k)
	local g = rawget(_G, k)
	if g ~= nil and k ~= "core" and k ~= "minetest" then return g end
	return any()
end})
env.dofile = function(path)
	return setfenv(assert(loadfile(path)), env)()
end
env._G = env
-- The real windows and areas.
setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_classes/talent_windows.lua")), env)()
setfenv(assert(loadfile(ROOT .. "/mods/CORE/grug_core/area.lua")), env)()
setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_abilities/init.lua")), env)()
local G = env.grug_abilities
check(G and G.registered.strike and G.registered.smite, "the real init.lua loads with the Priest kit")
-- The caster weapon: an own-level staff (spell base = W, Round 46).
G.spell_base = function(p) return fake_grug_core.spell_base(p.level, p.level) end
local area = fake_grug_core.area

------------------------------------------------------------------------------
-- R: the kit.
------------------------------------------------------------------------------
local KIT = {"smite", "heal", "shield_spell", "mend", "hearten", "haven", "rebuke",
	"word_of_ruin", "censure", "final_word"}
do
	local order = {}
	for _, def in ipairs(G.by_class.priest or {}) do order[#order + 1] = def.id end
	eq(table.concat(order, ","), table.concat(KIT, ","), "R the Priest's catalogue order")
	local smite = G.registered.smite
	check(smite.transforms == "strike" and not smite.talent_gated and not smite.talent and
		not smite.basic_attack, "R Smite replaces Strike, ungated (round53-plan.md §3)")
	eq(smite.cooldown_key, "strike", "R Smite shares Strike's key")
	check(not G.registered.heal.talent_gated, "R Heal is a starter")
	local granted = {}
	for _, id in ipairs(graph.node_ids) do
		local node = graph.nodes[id]
		if node.ability then
			granted[node.ability] = id
			local def = G.registered[node.ability]
			check(def and def.talent_gated and def.talent == id,
				"R node " .. id .. " grants " .. node.ability .. ", which names it")
		end
	end
	for _, id in ipairs(KIT) do
		local def = G.registered[id]
		if def.talent_gated then
			eq(granted[id], def.talent, "R " .. id .. "'s talent is a priest node that grants it")
		end
		check(G.CAST_SOUNDS[id] and G.SKILL_POSES[id] and G.WEAPON_FX[id],
			"R " .. id .. " has its K6 rows")
	end
	-- Every class key the graph names is read by the kit or a shared consumer.
	local kit = read("mods/PLAYER/grug_abilities/kits_priest.lua")
	for _, id in ipairs(graph.node_ids) do
		for key in pairs(graph.nodes[id].effects) do
			if not key:find(":", 1, true) and key ~= "max_mana_percent_add" and
					key ~= "heal_threat_factor_sub" then
				check(kit:find('"' .. key .. '"', 1, true) ~= nil, "R the kit reads " .. key)
			end
		end
	end
end

------------------------------------------------------------------------------
-- N: numbers at levels 10, 30 and 60 against the calculator.
------------------------------------------------------------------------------
local function priest(name, level, ranks, opts)
	opts = opts or {}
	opts.level = level
	local p = players[name] or new_player(name, opts)
	p.level = level
	set_ranks(p, ranks or {})
	return p
end
local function build(tree)
	local ranks = assert(graph.apply_order("priest", graph.trees[tree].example, 30))
	return ranks
end
local MERCY, RECKONING = build("mercy"), build("reckoning")
local function cost_of(p, id) return G.effective_cost(p, G.registered[id]).mana end
local function v(p, id, ...) return G.registered[id].values(p, ...) end
local function dmg(p, amount) return fake_grug_core.scale_player_damage(p, nil, amount) end

-- id -> {coef, cost %, cooldown, occupied, range}: the untalented row.
local ROWS = {
	smite = {1.0, 0, 0, 1, 20}, rebuke = {1.8, 6, 6, 1, 20},
	word_of_ruin = {1.6, 10, 16, 1, 20}, censure = {1.2, 12, 18, 1, 16},
	final_word = {2.8, 20, 60, 1.5, 20},
	heal = {25, 10, 5, 1.5, 15}, shield_spell = {24, 9, 12, 1, 15},
	mend = {7, 8, 12, 1, 15}, hearten = {15, 14, 20, 1.5, 6}, haven = {7, 22, 60, 1.5, 8},
}
for _, L in ipairs({10, 30, 60}) do
	local p = priest("n" .. L, L)
	for _, id in ipairs({"smite", "rebuke", "word_of_ruin", "censure", "final_word"}) do
		local r = ROWS[id]
		eq(dmg(p, v(p, id).damage), hit(L, r[1], 0, 0), ("N L%d %s damage"):format(L, id))
	end
	near(v(p, "heal").heal, share(L, 25), ("N L%d Heal 25 %% P"):format(L))
	near(v(p, "shield_spell").absorb, share(L, 24), ("N L%d Shield 24 %% P"):format(L))
	near(v(p, "mend").heal, share(L, 7), ("N L%d Mend 7 %% P a tick"):format(L))
	near(v(p, "hearten").heal, share(L, 15), ("N L%d Hearten 15 %% P"):format(L))
	near(v(p, "haven").heal, share(L, 7), ("N L%d Haven 7 %% P a tick"):format(L))
	eq(v(p, "haven").ticks, 6, ("N L%d Haven 6 ticks"):format(L))
	near(v(p, "word_of_ruin").cap, share(L, 6), ("N L%d Word of Ruin cap 6 %% P"):format(L))
	eq(v(p, "censure").radius, 3, ("N L%d Censure radius 3"):format(L))
	for id, r in pairs(ROWS) do
		local def = G.registered[id]
		eq(cost_of(p, id), r[2] > 0 and mana(L, r[2]) or nil, ("N L%d %s cost"):format(L, id))
		eq(G.effective_cooldown(p, def), r[3], ("N L%d %s cooldown"):format(L, id))
		eq(def.occupied_cast, r[4], ("N L%d %s occupied"):format(L, id))
		eq(G.get_range(p, def), r[5], ("N L%d %s range"):format(L, id))
	end
	eq(G.registered.smite.cast_interval, 1, "N Smite's 1 s interval")

	-- The two sample builds (the calculator's full builds; Warding Faith
	-- 5/5 per §8 Q1).
	local m = priest("nm" .. L, L, MERCY)
	near(v(m, "heal").heal, share(L, 31), ("N L%d Mercy Heal 31 %%"):format(L))
	near(v(m, "shield_spell").absorb, share(L, 34), ("N L%d Mercy Shield 34 %%"):format(L))
	near(v(m, "mend").heal, share(L, 8.5), ("N L%d Mercy Mend 8.5 %%"):format(L))
	eq(v(m, "haven").ticks, 9, ("N L%d Mercy Haven 9 ticks"):format(L))
	eq(cost_of(m, "heal"), mana(L, 8.8), ("N L%d Mercy Heal cost 8.8 %%"):format(L))
	eq(cost_of(m, "shield_spell"), mana(L, 7.92), ("N L%d Mercy Shield cost 7.92 %%"):format(L))
	eq(cost_of(m, "mend"), mana(L, 7.04), ("N L%d Mercy Mend cost 7.04 %%"):format(L))
	eq(cost_of(m, "hearten"), mana(L, 12.32), ("N L%d Mercy Hearten cost 12.32 %%"):format(L))
	eq(cost_of(m, "haven"), mana(L, 19.36), ("N L%d Mercy Haven cost 19.36 %%"):format(L))
	eq(dmg(m, v(m, "smite").damage), hit(L, 1, 0, 0.15), ("N L%d Mercy Smite +0.15 B"):format(L))
	local r = priest("nr" .. L, L, RECKONING)
	eq(dmg(r, v(r, "smite").damage), hit(L, 1, 0, 0.15), ("N L%d Reckoning Smite +0.15 B"):format(L))
	eq(dmg(r, v(r, "rebuke").damage), hit(L, 1.8, 9, 0.3), ("N L%d Reckoning Rebuke"):format(L))
	eq(dmg(r, v(r, "word_of_ruin").damage), hit(L, 1.6, 9, 0), ("N L%d Reckoning Word of Ruin"):format(L))
	eq(dmg(r, v(r, "final_word").damage), hit(L, 2.8, 9, 0.3), ("N L%d Reckoning Final Word"):format(L))
	eq(dmg(r, v(r, "censure").damage), hit(L, 1.2, 0, 0), ("N L%d Reckoning Censure (no Hard Faith)"):format(L))
	near(v(r, "word_of_ruin").cap, share(L, 9), ("N L%d Reckoning Word of Ruin cap 9 %%"):format(L))
	eq(G.effective_cooldown(r, G.registered.rebuke), 4.5, ("N L%d Reckoning Rebuke cd 4.5"):format(L))
	for id, pct in pairs({rebuke = 5.28, word_of_ruin = 8.8, censure = 10.56, final_word = 17.6, heal = 10}) do
		eq(cost_of(r, id), mana(L, pct), ("N L%d Reckoning %s cost %g %%"):format(L, id, pct))
	end
	for _, id in ipairs({"smite", "rebuke", "word_of_ruin", "final_word"}) do
		eq(G.get_range(r, G.registered[id]), 22, ("N L%d Reckoning %s range 22 (Long Reach 2)"):format(L, id))
	end
	eq(G.get_range(r, G.registered.censure), 16, ("N L%d Censure keeps 16 m"):format(L))
end
-- The calculator's level-60 rows in its unit (W + I = 37.8): Smite 1.1734;
-- Word of Ruin 1.744. Rebuke and Final Word are 2.340 and 3.430 there,
-- which multiply the talent adds by Hard Faith too; the code takes
-- damage_pct of the untalented part (round53-plan.md §3), 1.3 % and 0.9 %
-- below. Reported, held within 1.5 %.
do
	local r = priest("calc60", 60, RECKONING)
	local unit = U(60)
	local function coef(id) return v(r, id).damage / unit end
	near(coef("smite"), 1.1734, "N calc Smite 1.1734", 5e-4)
	near(coef("word_of_ruin"), 1.744, "N calc Word of Ruin 1.744", 5e-4)
	near(coef("censure"), 1.2, "N calc Censure 1.2", 1e-9)
	check(math.abs(coef("rebuke") / 2.340 - 1) < 0.015, ("N calc Rebuke %.4f within 1.5 %% of 2.340"):format(coef("rebuke")))
	check(math.abs(coef("final_word") / 3.430 - 1) < 0.015, ("N calc Final Word %.4f within 1.5 %% of 3.430"):format(coef("final_word")))
	print(("calculator L60 (unit 37.8): Smite %.4f (1.1734)  Rebuke %.4f (2.340)  Word of Ruin %.4f (1.744)  " ..
		"Censure %.4f (1.2)  Final Word %.4f (3.430)"):format(coef("smite"), coef("rebuke"),
		coef("word_of_ruin"), coef("censure"), coef("final_word")))
	-- A support factor Q multiplies support once, never damage.
	r.q = 1.2
	near(v(r, "heal").heal, share(60, 25) * 1.2, "N Q multiplies Heal")
	near(v(r, "word_of_ruin").cap, share(60, 9) * 1.2, "N Q multiplies Word of Ruin's cap")
	eq(dmg(r, v(r, "rebuke").damage), hit(60, 1.8, 9, 0.3), "N Q leaves damage alone")
	r.q = 1
end

------------------------------------------------------------------------------
-- T: each talent at rank 1 and full.
------------------------------------------------------------------------------
do
	local L = 30
	local base = priest("t_base", L)
	local function with(ranks) return priest("t_probe", L, ranks) end
	local function node(name) return graph.nodes[name] end
	-- Smite: Steady Word and Sharpened Word, one max-combined bonus.
	for _, id in ipairs({"mercy_steady_word", "reckoning_sharpened_word"}) do
		eq(dmg(with({[id] = 1}), v(with({[id] = 1}), "smite").damage), hit(L, 1, 0, 0.05), "T " .. id .. " 1")
		local p = with({[id] = 3})
		eq(dmg(p, v(p, "smite").damage), hit(L, 1, 0, 0.15), "T " .. id .. " full")
	end
	local both = with({mercy_steady_word = 3, reckoning_sharpened_word = 1})
	eq(dmg(both, v(both, "smite").damage), hit(L, 1, 0, 0.15), "T both Smite words: the higher, not the sum")
	both = with({mercy_steady_word = 3, reckoning_sharpened_word = 3})
	eq(dmg(both, v(both, "smite").damage), hit(L, 1, 0, 0.15), "T both full: still +0.15")
	-- Without a caster weapon the spell base and the base-hit add both halve
	-- (Round 46: the talent part follows the caster weapon like the spell).
	local spell_base = G.spell_base
	G.spell_base = function(p) return fake_grug_core.spell_base(p.level, nil) end
	local bare = with({mercy_steady_word = 3})
	eq(dmg(bare, v(bare, "smite").damage),
		math.max(1, math.floor((W(L) / 2 + (10 + 2 * (L - 1)) / 10 + 0.15 * B(L) / 2) * S(L))),
		"T no caster weapon: Steady Word's add halves with the spell base")
	G.spell_base = spell_base
	-- Measured Care and Measured Judgment.
	for rank, pct in pairs({[1] = -4, [3] = -12}) do
		local care = with({mercy_measured_care = rank})
		for _, id in ipairs({"heal", "shield_spell", "mend", "hearten", "haven"}) do
			eq(cost_of(care, id), mana(L, ROWS[id][2] * (1 + pct / 100)),
				("T Measured Care %d: %s"):format(rank, id))
		end
		for _, id in ipairs({"rebuke", "word_of_ruin", "censure", "final_word"}) do
			eq(cost_of(care, id), mana(L, ROWS[id][2]), ("T Measured Care %d leaves %s"):format(rank, id))
		end
		local judgment = with({reckoning_measured_judgment = rank})
		for _, id in ipairs({"rebuke", "word_of_ruin", "censure", "final_word"}) do
			eq(cost_of(judgment, id), mana(L, ROWS[id][2] * (1 + pct / 100)),
				("T Measured Judgment %d: %s"):format(rank, id))
		end
		eq(cost_of(judgment, "heal"), mana(L, 10), ("T Measured Judgment %d leaves Heal"):format(rank))
	end
	-- The shares.
	for _, case in ipairs({
			{"mercy_gentle_hand", "heal", "heal", 25, {2, 6}},
			{"mercy_warding_faith", "shield_spell", "absorb", 24, {2, 10}},
			{"mercy_patient_care", "mend", "heal", 7, {0.5, 1.5}},
			{"reckoning_resolute_word", "word_of_ruin", "cap", 6, {1, 3}}}) do
		local id, skill, field, at, adds = case[1], case[2], case[3], case[4], case[5]
		local full = node(id).ranks
		near(v(with({[id] = 1}), skill)[field], share(L, at + adds[1]), "T " .. id .. " 1")
		near(v(with({[id] = full}), skill)[field], share(L, at + adds[2]), "T " .. id .. " full")
	end
	-- The base-hit adds.
	for _, case in ipairs({{"reckoning_firm_rebuke", "rebuke", 1.8},
			{"reckoning_unfinished_sentence", "final_word", 2.8}}) do
		local id, skill, coef = case[1], case[2], case[3]
		local p1 = with({[id] = 1})
		eq(dmg(p1, v(p1, skill).damage), hit(L, coef, 0, 0.1), "T " .. id .. " 1")
		local p3 = with({[id] = 3})
		eq(dmg(p3, v(p3, skill).damage), hit(L, coef, 0, 0.3), "T " .. id .. " full")
	end
	-- Hard Faith: Rebuke, Word of Ruin and Final Word; not Censure, not Smite.
	for rank, pct in pairs({[1] = 3, [3] = 9}) do
		local p = with({reckoning_hard_faith = rank})
		for id, coef in pairs({rebuke = 1.8, word_of_ruin = 1.6, final_word = 2.8}) do
			eq(dmg(p, v(p, id).damage), hit(L, coef, pct, 0), ("T Hard Faith %d: %s"):format(rank, id))
		end
		eq(dmg(p, v(p, "censure").damage), hit(L, 1.2, 0, 0), ("T Hard Faith %d leaves Censure"):format(rank))
		eq(dmg(p, v(p, "smite").damage), hit(L, 1, 0, 0), ("T Hard Faith %d leaves Smite"):format(rank))
	end
	-- Long Reach, Press the Verdict, Broad Judgment, Lasting Haven.
	for rank, add in pairs({[1] = 1, [3] = 3}) do
		local p = with({reckoning_long_reach = rank})
		for _, id in ipairs({"smite", "rebuke", "word_of_ruin", "final_word"}) do
			eq(G.get_range(p, G.registered[id]), 20 + add, ("T Long Reach %d: %s"):format(rank, id))
		end
		eq(G.get_range(p, G.registered.censure), 16, ("T Long Reach %d leaves Censure"):format(rank))
	end
	eq(G.effective_cooldown(with({reckoning_press_the_verdict = 1}), G.registered.rebuke), 5.5, "T Press the Verdict 1")
	eq(G.effective_cooldown(with({reckoning_press_the_verdict = 3}), G.registered.rebuke), 4.5, "T Press the Verdict full")
	eq(v(with({reckoning_broad_judgment = 1}), "censure").radius, 3.25, "T Broad Judgment 1")
	eq(v(with({reckoning_broad_judgment = 3}), "censure").radius, 3.75, "T Broad Judgment full")
	eq(v(with({mercy_lasting_haven = 1}), "haven").ticks, 7, "T Lasting Haven 1")
	eq(v(with({mercy_lasting_haven = 3}), "haven").ticks, 9, "T Lasting Haven full")
	-- The shared keys (stats.lua, combat.lua read them by name).
	for _, case in ipairs({{"mercy_deep_reserve", "max_mana_percent_add", 4, 12},
			{"reckoning_deep_resolve", "max_mana_percent_add", 4, 12},
			{"mercy_quiet_care", "heal_threat_factor_sub", 0.05, 0.15}}) do
		near(with({[case[1]] = 1}).sums[case[2]], case[3], "T " .. case[1] .. " 1")
		near(with({[case[1]] = 3}).sums[case[2]], case[4], "T " .. case[1] .. " full")
	end
	-- The unlocks.
	for _, id in ipairs(KIT) do
		local def = G.registered[id]
		if def.talent_gated then
			check(not G.is_unlocked(base, id), "T " .. id .. " locked without its node")
			check(G.is_unlocked(with({[def.talent] = 1}), id), "T " .. id .. " unlocked by " .. def.talent)
		end
	end
	check(G.is_unlocked(base, "smite") and G.is_unlocked(base, "heal") and not G.is_unlocked(base, "strike"),
		"T a Priest has Smite and Heal, Strike replaced")
end

------------------------------------------------------------------------------
-- X: the transform, the starter hotbar, the fallback's basic attack.
------------------------------------------------------------------------------
do
	local p = priest("x_new", 20)
	fire("class_chosen", p, "priest")
	eq(row(p.inv, "main", 3), "smite,heal,", "X a new Priest: Smite in slot 1, then Heal")
	check(G.current_form(p, G.registered.strike) == G.registered.smite,
		"X the held fallback's basic attack is Smite (K8)")
	local q = priest("x_old", 20)
	q.inv.lists.main[1] = ItemStack("grug_abilities:strike")
	q.inv.lists.main[2] = ItemStack("grug_abilities:heal")
	q.inv.lists.grug_hotbar_store[4] = ItemStack("grug_abilities:strike")
	G.normalize_kit(q)
	eq(row(q.inv, "main", 2), "smite,heal", "X Strike becomes Smite in place on layout A")
	eq(q.inv.lists.grug_hotbar_store[4].name, "grug_abilities:smite", "X ... and on layout B")
	local held = priest("x_held", 20)
	held.inv.lists.main[1] = ItemStack("grug_abilities:strike")
	held.inv.lists.main[5] = ItemStack("grug_abilities:smite")
	G.normalize_kit(held)
	eq(row(held.inv, "main", 5), ",,,,smite", "X a Priest holding Smite: Strike's slot empties (§8 Q4)")
end

------------------------------------------------------------------------------
-- Cast helpers.
------------------------------------------------------------------------------
local function cast(p, id, ray)
	aim = ray or {status = "miss", reason = "empty"}
	local flashed
	local ok = G.try_cast(p, G.registered[id], nil, function(message) flashed = message end)
	return ok, flashed
end
local function at_mob(m)
	return {status = "target", reason = "hostile", target = m, distance = 5, range = 20,
		origin = vector.new(0, 1.47, 0), destination = m.pos}
end
local function full_mana(p) G.restore_mana(p, 1e6) end

------------------------------------------------------------------------------
-- C: the clock.
------------------------------------------------------------------------------
do
	local p = priest("c_clock", 30, {mercy_shield = 1})
	full_mana(p)
	local m = new_mob("c_mob", vector.new(0, 0, 5))
	check(cast(p, "smite", at_mob(m)), "C Smite casts, free")
	eq(G.get_mana(p), 1e6, "C Smite costs nothing")
	local ok, why = cast(p, "smite", at_mob(m))
	check(not ok and why == "Smite cast interval is not ready.", "C Smite again at once: its interval")
	ok, why = cast(p, "heal")
	check(not ok and why == "You are still busy.", "C Heal right after Smite: occupied 1 s")
	wait(1)
	check(cast(p, "heal"), "C Heal 1 s after Smite")
	wait(1)
	ok, why = cast(p, "smite", at_mob(m))
	check(not ok and why == "You are still busy.", "C Smite 1 s after Heal: occupied 1.5 s")
	wait(0.5)
	check(cast(p, "smite", at_mob(m)), "C Smite 1.5 s after Heal")
	wait(1)
	check(cast(p, "shield_spell"), "C Shield")
	wait(0.99)
	ok, why = cast(p, "smite", at_mob(m))
	check(not ok and why == "You are still busy.", "C Shield occupies 1 s")
	wait(0.01)
	check(cast(p, "smite", at_mob(m)), "C Smite 1 s after Shield")
	wait(5)
	m.pos = vector.new(0, 0, 50)
end

------------------------------------------------------------------------------
-- W: Clear Conscience.
------------------------------------------------------------------------------
do
	local L = 40
	local m = new_mob("w_mob", vector.new(0, 0, 6))
	local p = priest("w_cc", L, {mercy_clear_conscience = 3, mercy_shield = 1, mercy_mend = 1})
	full_mana(p)
	local function smite_damage()
		reset_log()
		wait(2)
		assert(cast(p, "smite", at_mob(m)))
		return log.damage[1].amount
	end
	eq(smite_damage(), hit(L, 1, 0, 0), "W a plain Smite")
	for _, id in ipairs({"heal", "shield_spell", "mend"}) do
		wait(10)
		reset_log()
		check(cast(p, id), "W " .. id .. " casts")
		eq(log.procs[1], "clear_conscience", "W " .. id .. " opens the window with its flash")
		check(fake_classes.get_window(p, "clear_conscience") ~= nil, "W the window is open after " .. id)
		eq(smite_damage(), hit(L, 1, 0, 0.3), "W the next Smite after " .. id .. " +0.30 B")
		eq(smite_damage(), hit(L, 1, 0, 0), "W one charge: the Smite after it is plain")
	end
	-- The internal cooldown: 8 s from the opening.
	wait(20)
	assert(cast(p, "heal"))
	wait(2)
	reset_log()
	assert(cast(p, "shield_spell"))
	eq(#log.procs, 0, "W a second opener within 8 s opens nothing")
	wait(4.1)
	eq(fake_classes.get_window(p, "clear_conscience"), nil, "W the window runs out after 5 s")
	reset_log()
	wait(2)
	assert(cast(p, "heal"))
	eq(log.procs[1], "clear_conscience", "W 8 s after the opening it opens again")
	-- Rank 1; and none without the node.
	local r1 = priest("w_r1", L, {mercy_clear_conscience = 1})
	full_mana(r1)
	assert(cast(r1, "heal"))
	wait(2)
	reset_log()
	assert(cast(r1, "smite", at_mob(m)))
	eq(log.damage[1].amount, hit(L, 1, 0, 0.1), "W rank 1: +0.10 B")
	local none = priest("w_none", L)
	full_mana(none)
	reset_log()
	assert(cast(none, "heal"))
	eq(#log.procs, 0, "W no window without Clear Conscience")
	m.pos = vector.new(0, 0, 60)
end

------------------------------------------------------------------------------
-- A: the areas.
------------------------------------------------------------------------------
local function clear_world()
	for i = #objects, 1, -1 do objects[i] = nil end
	for k in pairs(extra_nodes) do extra_nodes[k] = nil end
	jobs = {}
end
do
	local L = 50
	-- Censure at the sky: refused before cost and cooldown.
	clear_world()
	local p = priest("a_censure", L, {reckoning_censure = 1}, {flagged = true})
	full_mana(p)
	local before = G.get_mana(p)
	local ok, why = cast(p, "censure", {status = "miss", reason = "empty",
		origin = vector.new(0, 21.47, 0), destination = vector.new(0, 21.47, 16)})
	check(not ok and why == "No ground found.", "A Censure at the sky: No ground found.")
	eq(G.get_mana(p), before, "A ... nothing paid")
	check(G.ready(p, "censure"), "A ... no cooldown armed")
	eq(#jobs, 0, "A ... nothing pending")

	-- Flat ground, a hostile under the crosshair: the anchor below it.
	local centre = new_mob("a_centre", vector.new(0, 0, 8))
	local near1 = new_mob("a_near1", vector.new(1, 0, 8))
	local near2 = new_mob("a_near2", vector.new(0, 0, 10))
	local near3 = new_mob("a_near3", vector.new(2.5, 0, 8))
	local far = new_mob("a_far", vector.new(2.9, 0, 8))
	local outside = new_mob("a_outside", vector.new(3.5, 0, 8))
	local high = new_mob("a_high", vector.new(0, 4, 9))
	local hidden = new_mob("a_hidden", vector.new(-2, 0, 8))
	extra_nodes[nkey(-1, 0, 8)], extra_nodes[nkey(-1, 1, 8)] = "stone", "stone"
	local enemy_unflagged = new_player("a_enemy_calm", {faction = "throng", pos = vector.new(0.5, 0, 8)})
	local friend = new_player("a_friend", {faction = "accord", flagged = true, pos = vector.new(0, 0, 8.5)})
	reset_log()
	check(cast(p, "censure", at_mob(centre)), "A Censure at a mob casts")
	check(G.get_mana(p) < before and not G.ready(p, "censure"), "A ... paid and on cooldown")
	eq(#log.damage, 0, "A ... nothing hit before the delay")
	local warn, fall
	for _, e in ipairs(log.fx) do
		if e.id == "censure_warning" then warn = e.frame end
		if e.id == "censure_fall" then fall = e.frame end
	end
	check(warn and warn.reach == 3 and warn.time == 0.75 and warn.target.y == -0.5,
		"A the warning on the ground under the mob, radius 3, for 0.75 s")
	check(fall and fall.height == area.CEILING_CAP, "A the seal falls from the cap under open sky")
	eq(#jobs, 1, "A one impact pending")
	eq(jobs[1].delay, 0.75, "A ... after 0.75 s")
	run_jobs()
	local hit_names = {}
	for _, d in ipairs(log.damage) do hit_names[#hit_names + 1] = d.target.name end
	eq(table.concat(hit_names, ","), "a_centre,a_near1,a_near2,a_near3",
		"A the 4 nearest hostiles in sight within 3 m and the band (not the far 5th, " ..
		"the one outside, the one too high, the one behind stone)")
	for _, d in ipairs(log.damage) do
		eq(d.amount, hit(L, 1.2, 0, 0), "A Censure's hit on " .. d.target.name)
		check(d.no_crit, "A Censure's hit asks for no crit on " .. d.target.name)
	end
	check(#log.sounds >= 1, "A sounds played")
	local impacts = 0
	for _, s in ipairs(log.sounds) do
		if s.event == "censure_impact" then
			impacts = impacts + 1
			check(type(s.target) == "table" and s.target.y == -0.5 and not s.target.get_pos,
				"A the impact cue at the anchor")
		end
	end
	eq(impacts, 1, "A the impact cue once")
	local burst
	for _, e in ipairs(log.fx) do if e.id == "censure_impact" then burst = e.frame end end
	check(burst and burst.reach == 3, "A the impact ring to the radius")
	-- PvP: an unflagged enemy player and a same-faction player are never hit;
	-- a flagged enemy player is when the priest is flagged.
	clear_world()
	objects[#objects + 1] = p
	local foe = new_player("a_foe", {faction = "throng", flagged = true, pos = vector.new(0, 0, 8)})
	enemy_unflagged = new_player("a_calm", {faction = "throng", pos = vector.new(0.5, 0, 8)})
	friend = new_player("a_ally", {faction = "accord", flagged = true, pos = vector.new(0, 0, 8.5)})
	wait(30)
	reset_log()
	check(cast(p, "censure", at_mob(foe)), "A Censure at a flagged enemy player")
	run_jobs()
	hit_names = {}
	for _, d in ipairs(log.damage) do hit_names[#hit_names + 1] = d.target.name end
	eq(table.concat(hit_names, ","), "a_foe", "A only the flagged enemy: never the unflagged one or an ally")
	p.flagged = false
	wait(30)
	reset_log()
	check(cast(p, "censure", {status = "miss", reason = "protected",
		origin = vector.new(0, 1.47, 0), destination = vector.new(0, -1, 8)}), "A unflagged: at the ground")
	run_jobs()
	eq(#log.damage, 0, "A an unflagged priest hits no player")
	p.flagged = true

	-- A stair: the mob on a step one node up, another below it.
	clear_world()
	objects[#objects + 1] = p
	for x = -3, 3 do for z = 10, 14 do extra_nodes[nkey(x, 0, z)] = "stone" end end
	local step = new_mob("a_step", vector.new(0, 1, 10.2))
	local below = new_mob("a_below", vector.new(0, 0, 9.2))
	wait(30)
	reset_log()
	check(cast(p, "censure", at_mob(step)), "A Censure at a mob on a stair")
	eq(log.fx[1] and log.fx[1].frame.target.y, 0.5, "A the anchor is the step's top")
	run_jobs()
	eq(#log.damage, 2, "A both mobs on the stair are hit (band 3)")

	-- A cave: a ceiling 4 nodes above the floor; the seal falls below it.
	clear_world()
	objects[#objects + 1] = p
	for x = -6, 6 do for z = 0, 14 do extra_nodes[nkey(x, 4, z)] = "stone" end end
	local cave = new_mob("a_cave", vector.new(0, 0, 8))
	wait(30)
	reset_log()
	check(cast(p, "censure", at_mob(cave)), "A Censure in a cave")
	fall = nil
	for _, e in ipairs(log.fx) do if e.id == "censure_fall" then fall = e.frame end end
	check(fall and fall.height == 3.5, "A the seal starts half a node below the cave ceiling (" ..
		tostring(fall and fall.height) .. ")")
	run_jobs()
	eq(#log.damage, 1, "A the cave mob is hit")
	-- Leaving cancels the pending impact (area.delayed, D9).
	wait(30)
	reset_log()
	check(cast(p, "censure", at_mob(cave)), "A Censure before a leave")
	for _, fn in ipairs(callbacks.leave or {}) do fn(p) end
	run_jobs()
	eq(#log.damage, 0, "A a caster leaving cancels the impact")
end

-- Hearten and Haven: you plus the neediest allies in sight within reach.
do
	local L = 40
	clear_world()
	local p = priest("g_priest", L, {mercy_hearten = 1, mercy_haven = 1})
	p.hp = 50
	full_mana(p)
	local function ally(name, hp, pos, opts)
		opts = opts or {}
		opts.pos, opts.faction = pos, opts.faction or "accord"
		local a = new_player(name, opts)
		a.hp = hp
		return a
	end
	ally("g_low", 20, vector.new(2, 0, 0))
	ally("g_mid", 60, vector.new(0, 0, 3))
	ally("g_high", 90, vector.new(-2, 0, 0))
	ally("g_lower", 40, vector.new(0, 0, -3))
	ally("g_far", 5, vector.new(0, 0, 9))
	ally("g_enemy", 5, vector.new(1, 0, 1), {faction = "throng"})
	ally("g_flagged", 5, vector.new(-1, 0, 1), {flagged = true})
	ally("g_hidden", 5, vector.new(4, 0, 0))
	extra_nodes[nkey(3, 0, 0)], extra_nodes[nkey(3, 1, 0)] = "stone", "stone"
	reset_log()
	check(cast(p, "hearten"), "A Hearten casts")
	local names = {}
	for _, h in ipairs(log.heals) do
		names[#names + 1] = h.target.name
		near(h.amount, share(L, 15), "A Hearten heals 15 % P " .. h.target.name)
		check(h.no_crit, "A Hearten never crits")
	end
	eq(table.concat(names, ","), "g_low,g_lower,g_priest,g_mid",
		"A Hearten: you and the 3 neediest allies in sight within 6 m, lowest health first " ..
		"(never the far one, an enemy, a flagged ally of an unflagged priest, one behind stone)")
	eq(#log.contacts, 3, "A Hearten reports support contact per ally")
	wait(1.5)
	reset_log()
	check(cast(p, "haven"), "A Haven casts (1.5 s after Hearten)")
	names = {}
	for _, s in ipairs(log.statuses) do
		names[#names + 1] = s.target.name
		check(s.id == "haven" and s.def.interval == 2 and s.def.duration == 12,
			"A Haven: a haven status, every 2 s for 12 s, on " .. s.target.name)
	end
	eq(table.concat(names, ","), "g_low,g_lower,g_priest,g_mid,g_high",
		"A Haven: you and 4 allies within 8 m")
	local rec = log.statuses[1]
	reset_log()
	rec.def.on_tick(rec.target)
	check(#log.heals == 1 and log.heals[1].no_crit, "A a Haven tick heals once, no crit")
	near(log.heals[1].amount, share(L, 7), "A a Haven tick is 7 % P")
	eq(log.heals[1].healer, p, "A ... from the priest")
	local fxs = {}
	for _, e in ipairs(log.fx) do fxs[#fxs + 1] = e.id end
	eq(table.concat(fxs, ","), "haven_tick", "A ... with its tick effect")
	-- Mend: its status, 4 ticks of the snapshot.
	local m = priest("g_mender", L, {mercy_mend = 1, mercy_patient_care = 3})
	full_mana(m)
	reset_log()
	check(cast(m, "mend"), "A Mend on yourself")
	rec = log.statuses[1]
	check(rec and rec.id == "mend" and rec.def.interval == 3 and rec.def.duration == 12 and rec.target == m,
		"A Mend: a mend status every 3 s for 12 s")
	reset_log()
	rec.def.on_tick(m)
	near(log.heals[1].amount, share(L, 8.5), "A a Mend tick is 8.5 % P with Patient Care 3")
	check(log.heals[1].no_crit, "A Mend never crits")
end

------------------------------------------------------------------------------
-- D: Word of Ruin, Heal, Shield, Rebuke and Final Word land; the old API is gone.
------------------------------------------------------------------------------
do
	local L = 60
	clear_world()
	local p = priest("d_priest", L, {reckoning_word_of_ruin = 1, reckoning_rebuke = 1,
		reckoning_final_word = 1, mercy_shield = 1})
	full_mana(p)
	local m = new_mob("d_mob", vector.new(0, 0, 6))
	reset_log()
	check(cast(p, "word_of_ruin", at_mob(m)), "D Word of Ruin casts")
	local dealt = log.damage[1].amount
	eq(dealt, hit(L, 1.6, 0, 0), "D Word of Ruin's hit")
	eq(log.heals[1].target, p, "D it heals the priest")
	eq(log.heals[1].amount, math.min(math.floor(dealt * 0.5), math.floor(share(L, 6))),
		"D half the damage, at most 6 % P")
	check(log.heals[1].no_crit, "D the heal never crits")
	-- A small hit heals half of it (the cap does not bind).
	local real = fake_grug_core.deal_ability_damage
	fake_grug_core.deal_ability_damage = function(a, t, amount, opts)
		opts.on_accepted(30, false, {})
		return 30
	end
	wait(20)
	reset_log()
	assert(cast(p, "word_of_ruin", at_mob(m)))
	eq(log.heals[1].amount, 15, "D a 30 hit heals 15")
	fake_grug_core.deal_ability_damage = real
	-- Rebuke's line and Final Word's column.
	wait(5)
	reset_log()
	assert(cast(p, "rebuke", at_mob(m)))
	check(log.fx[1].id == "rebuke" and log.fx[1].frame.from and log.fx[1].frame.to and
		log.fx[1].frame.to.z == 6, "D Rebuke draws its line from the hand to the target")
	eq(log.damage[1].amount, hit(L, 1.8, 0, 0), "D Rebuke's hit")
	wait(5)
	reset_log()
	assert(cast(p, "final_word", at_mob(m)))
	eq(log.fx[1].id, "final_word", "D Final Word's effect")
	eq(log.damage[1].amount, hit(L, 2.8, 0, 0), "D Final Word's hit")
	-- Heal and Shield on yourself (no ally aimed), no crit.
	wait(5)
	reset_log()
	assert(cast(p, "heal"))
	check(log.heals[1].target == p and log.heals[1].no_crit, "D Heal on yourself, no crit")
	wait(5)
	reset_log()
	assert(cast(p, "shield_spell"))
	check(log.absorbs[1].target == p and log.absorbs[1].duration == 10 and
		log.absorbs[1].id == "shield_spell", "D Shield: 10 s on yourself")
	near(log.absorbs[1].amount, share(L, 24), "D Shield absorbs 24 % P")
	-- No target, no cast, nothing paid.
	local before = G.get_mana(p)
	wait(20)
	local ok, why = cast(p, "rebuke")
	check(not ok and why == "No hostile target in your crosshair." and G.get_mana(p) == before,
		"D Rebuke at nothing refuses and pays nothing")

	local kit = read("mods/PLAYER/grug_abilities/kits_priest.lua")
	for _, old in ipairs({"registered_talents", "talent_rank_value", "try_trigger_talent_window",
			"smite_absorb", "heal_splash", "last_word", "recompense", "drain_ratio_override",
			"get_objects_inside_radius", "core.raycast"}) do
		check(not kit:find(old, 1, true), "D the kit no longer uses " .. old)
	end
end

if failures > 0 then
	error(("R53 PRIEST PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R53 PRIEST PORTABLE PASS checks=%d"):format(checks))
