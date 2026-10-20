-- Round 53 lane SCOUT portable test (LuaJIT; round53-plan.md §4 "SCOUT",
-- §6 class fixtures, K7, K12): the Scout's new kit and the deleted bow draw.
--
--   luajit tools/r53_scout/portable_test.lua [repo]
--
--   D  the draw is gone: no draw code in scout.lua or input.lua (no
--      globalstep, stance, pose hook or exports), no draw-stage textures or
--      strips (K12), no Pinning Shot or Untouchable;
--   G  the graph data (the REAL talent_graph.lua and talent_graph_scout.lua):
--      every node's effects per rank as the node list gives them, the class
--      keys in the vocabulary, each read by the kit;
--   K  the REAL grug_abilities/init.lua with its whole dofile chain, the REAL
--      grug_classes/scout.lua and talent_windows.lua and the graph in a
--      sandbox (the tools/r53_hooks pattern) over a fake engine:
--        the registrations (order, basic attack, talents, tags, Strike after
--        the starters on a new character: K7);
--        per skill at levels 10, 30 and 60: damage (a share of R or M),
--        cost, cooldown and occupied time against the balance calculator
--        (r52/calc data-scout.json, quoted below), untalented and with the
--        two sample builds; each talent at rank 1 and full;
--        Loose's cadence (the bow's own affix, the 0.65 s floor) and its
--        timing line;
--        Bladecraft in place of Loose on both layouts, its right-click shot
--        sharing Loose's interval and the action clock;
--        the windows (Follow the Line, Parry, Close Dance): open, consume,
--        expiry, the swing callback on blade swings only;
--        refusals that pay nothing (no bow, no target, Arrowfall below four
--        arrows); Split Shot's splash and Flourish's cone through the PvP
--        target check (an unflagged player and an ally are never targets);
--        Snare Shot's slow on a landed hit only; Sidestep's 3 s and Shake
--        Loose; the Arrowfall sounds (one cast cue, an impact per arrow);
--   I  the REAL input.lua in the same sandbox: Loose shoots on LMB and
--      holds its cadence, an empty quiver swings Strike at a foe in reach
--      (K8), Bladecraft swings on LMB and shoots on RMB.
-- Prints "R53 SCOUT PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function exists(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end

local ABIL = "mods/PLAYER/grug_abilities/"
local scout_src = assert(read(ABIL .. "scout.lua"))
local input_src = assert(read(ABIL .. "input.lua"))
local class_src = assert(read("mods/PLAYER/grug_classes/scout.lua"))

------------------------------------------------------------------------------
-- D: the draw is gone.
------------------------------------------------------------------------------
do
	for _, needle in ipairs({"register_globalstep", "start_draw", "release_draw", "renew_draw",
			"DRAW_STANCE", "set_move_stance", "register_control_animation_override",
			"start_bow_draw", "cancel_bow_draw", "renew_bow_draw", "scout_draw_active",
			"draw_multiplier", "pinning_shot", "set_ring"}) do
		check(not scout_src:find(needle, 1, true), "D scout.lua has no " .. needle)
	end
	for _, needle in ipairs({"bow_draw", "\"loose\"", "\"bow\"", "scout_draw_active"}) do
		check(not input_src:find(needle, 1, true), "D input.lua has no " .. needle)
	end
	check(not class_src:find("untouchable", 1, true) and
		not class_src:find("set_move_immunity", 1, true),
		"D grug_classes/scout.lua: Untouchable and the old immunity are gone")
	for stage = 0, 2 do
		check(not exists(ABIL .. "textures/grug_abilities_bow_draw_" .. stage .. ".png"),
			"D the draw-stage sprite " .. stage .. " is deleted")
		for _, family in ipairs({"quarry", "veil"}) do
			check(not exists(ABIL .. "textures/grug_abilities_fx_" .. family .. "_bow_draw" ..
				stage .. ".png"), "D the strip " .. family .. " draw " .. stage .. " is deleted (K12)")
		end
	end
	check(exists(ABIL .. "textures/grug_abilities_fx_quarry_sword.png") and
		exists(ABIL .. "textures/grug_abilities_fx_quarry_dagger.png"),
		"D quarry_sword and quarry_dagger stay shipped (K12)")
	local license = assert(read(ABIL .. "LICENSE-media.md"))
	check(not license:find("bow_draw", 1, true), "D no licence row for a deleted file")
end

------------------------------------------------------------------------------
-- The sandbox: vector, stacks, players.
------------------------------------------------------------------------------
vector = {}
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

local Stack = {}
Stack.__index = Stack
local function ItemStack(spec)
	if type(spec) == "table" and getmetatable(spec) == Stack then
		local copy = setmetatable({name = spec.name, count = spec.count, fields = {},
			caps = spec.caps, affixes = spec.affixes}, Stack)
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
function Stack:get_definition() return {} end
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
local function weapon(name, damage, interval, affixes)
	local s = ItemStack(name)
	s.caps = {full_punch_interval = interval or 1, damage_groups = {fleshy = damage}}
	s.affixes = affixes
	return s
end

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
	for i = 1, n do out[i] = (inv.lists[l][i].name:gsub("^grug_abilities:", "")) end
	return table.concat(out, ",")
end

-- An own-level weapon (grug_core.baseline_weapon_damage) and the Scout's
-- natural Dexterity (10 + 2 per level after the first).
local function own_weapon_damage(level) return math.floor(4 + 0.35 * level + 0.5) end
local function natural_dex(level) return 10 + 2 * (level - 1) end

local players = {}
local function new_player(name, opts)
	opts = opts or {}
	local level = opts.level or 30
	local p = {name = name, class = opts.class or "scout", ranks = {}, hp = 100,
		level = level, dex = natural_dex(level), faction = opts.faction or "accord",
		flagged = opts.flagged, inv = new_inventory(), wield = 1, ammo = opts.ammo or 200,
		pos = opts.pos or vector.new(0, 0, 0), yaw = opts.yaw or 0, controls = {},
		bow = opts.bow == nil and weapon("grug_gear:bow_wood", own_weapon_damage(level), 1) or
			opts.bow or nil,
		melee = opts.melee or weapon("grug_gear:sword_iron", own_weapon_damage(level), 1),
		meta = {}}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return vector.new(self.pos) end
	function p:get_look_dir() return {x = -math.sin(self.yaw), y = 0, z = math.cos(self.yaw)} end
	function p:get_look_horizontal() return self.yaw end
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:set_wielded_item(s) self.inv:set_stack("main", self.wield, s); return true end
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

-- A mob in the scene.
local function new_mob(name, pos, opts)
	opts = opts or {}
	local ent = {name = "test:" .. name, health = 20, _cmi_is_mob = true, temp = {}}
	local m = {kind = "mob", name = name, pos = pos, ent = ent, yaw = opts.yaw or 0,
		accept = opts.accept ~= false}
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
local tools = {}
local log = {}
local function reset_log()
	log = {launches = {}, damage = {}, sounds = {}, fx = {}, flashes = {}, absorbs = {},
		slows = {}, cleared = {}, procs = {}, swings = {}, areas = {}}
end
reset_log()
local scene = {aim = nil, spawn_fail = false, cone = {}, query = {}}

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
	register_on_joinplayer = capture("join"),
	register_globalstep = capture("globalstep"),
	register_on_mods_loaded = capture("mods_loaded"),
	register_on_player_hpchange = capture("hpchange"),
	get_modpath = function(mod)
		if mod == "grug_classes" then return ROOT .. "/mods/PLAYER/grug_classes" end
		return ROOT .. "/mods/PLAYER/grug_abilities"
	end,
	get_current_modname = function() return "grug_abilities" end,
	get_dir_list = function() return {} end,
	get_us_time = function() return now_us end,
	global_exists = function(n) return n == "grug_inventory" end,
	register_tool = function(name, def) tools[name] = def end,
	registered_items = {},
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

-- base_pool, cut from grug_core/combat.lua (the one shared curve).
local combat_src = assert(read("mods/CORE/grug_core/combat.lua"))
local pool_src = combat_src:match("\n(function grug_core%.base_pool%(level%).-\nend)\n")
check(pool_src ~= nil, "K base_pool found in grug_core/combat.lua")

local melee_prepare
local fake_grug_core = with_any({
	get_melee_weapon = function(p) return p.melee and ItemStack(p.melee) or ItemStack("") end,
	get_equipped_weapon = function(p) return p.bow and ItemStack(p.bow) or nil end,
	equipment_is_broken = function() return false end,
	is_stunned = function() return false end,
	refuse_mounted_attack = function() return false end,
	combat_eye_pos = function(p) return vector.offset(p:get_pos(), 0, 1.5, 0) end,
	combat_actor = function(ref) return ref end,
	-- Identity: the fixture checks the raw amounts (R and M shares); the
	-- tooltip number floors once like the real scalar.
	scale_player_damage = function(_, _, amount) return math.floor(amount) end,
	scale_player_value = function(_, amount) return amount end,
	get_player_level = function(p) return p.level end,
	register_native_melee_handler = function(prepare) melee_prepare = prepare end,
	begin_authoritative_swing = function(player, target, transaction)
		log.swings[#log.swings + 1] = {player = player, target = target, raw = transaction.raw_damage,
			proc = transaction.proc and transaction.proc.id or nil, gains = transaction.gains}
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
	deal_ability_damage = function(attacker, target, amount, opts)
		log.damage[#log.damage + 1] = {attacker = attacker, target = target, amount = amount}
		if target.accept ~= false and opts and opts.on_accepted then
			opts.on_accepted(amount, false, opts.action_id)
		end
		return amount
	end,
	add_absorb = function(player, id, amount, duration, source)
		log.absorbs[#log.absorbs + 1] = {player = player, id = id, amount = amount,
			duration = duration, source = source}
		return amount
	end,
	set_move_modifier = function(p, name, effect, duration)
		log.slows[#log.slows + 1] = {target = p, name = name, speed = effect.speed, duration = duration}
	end,
	clear_negative_move_modifiers = function(p) log.cleared[#log.cleared + 1] = p end,
	proc_flash = function(p, proc) log.procs[#log.procs + 1] = proc end,
	set_status = function() end,
	clear_status = function() end,
	particles = {
		play = function(id, frame) log.fx[#log.fx + 1] = {id = id, frame = frame} end,
		facing = function() return {x = 0, y = 0, z = 1} end,
	},
	area = {
		cone = function(caster, opts)
			log.areas[#log.areas + 1] = {kind = "cone", opts = opts}
			local hits = {}
			for _, obj in ipairs(scene.cone) do
				if (not opts.cap or #hits < opts.cap) and opts.filter(obj) then hits[#hits + 1] = obj end
			end
			return hits
		end,
		query = function(anchor, opts)
			log.areas[#log.areas + 1] = {kind = "query", anchor = anchor, opts = opts}
			local hits = {}
			for _, obj in ipairs(scene.query) do
				if (not opts.cap or #hits < opts.cap) and opts.filter(obj) then hits[#hits + 1] = obj end
			end
			return hits
		end,
	},
	status_icons = {WINDOWS = {follow_the_line = "follow_the_line", parry = "parry",
		close_dance = "close_dance"}},
})
setfenv(assert(loadstring(pool_src or "")), setmetatable({grug_core = fake_grug_core},
	{__index = _G}))()

local registered_classes = {warrior = {name = "Warrior", resource = "rage"},
	mage = {name = "Mage", resource = "mana"}, priest = {name = "Priest", resource = "mana"},
	scout = {name = "Scout", resource = "mana"}}
local GC = with_any({
	registered_classes = registered_classes,
	registered_talents = {mend = {name = "Mend"}},
	get_class = function(p) return p.class end,
	get_class_def = function(p) return registered_classes[p.class] end,
	talent_rank = function(p, id) return p.ranks and p.ranks[id] or 0 end,
	get_melee_bonus = function(p) return p.dex / 10 end,
	get_ranged_bonus = function(p) return p.dex / 10 end,
	get_race_perk = function() return nil end,
	get_max_mana = function() return 1e6 end,
	talent_window_active = function() return false end,
	register_on_class_chosen = capture("class_chosen"),
	register_class = function() end,
})
-- The graph's accessor as talents.lua answers it: the rank values summed.
function GC.get_talent_bonus(p, key)
	local graph = GC.graph
	local total = 0
	for id, rank in pairs(p.ranks or {}) do
		local node = graph and graph.nodes[id]
		local values = node and node.effects[key]
		if values and rank > 0 then total = total + values[rank] end
	end
	return total
end

local sounds = {}
local fake_sounds = with_any({
	play = function(event, target)
		log.sounds[#log.sounds + 1] = {event = event, target = target}
		return true
	end,
	item_sound = function() return nil end,
})
local projectiles = {}
local fake_projectiles = with_any({
	register = function(id, def) projectiles[id] = def end,
	spawn_batch = function(id, launches, commit)
		if scene.spawn_fail then return false end
		if commit and commit() ~= true then return false end
		for _, l in ipairs(launches) do
			l.projectile = id
			log.launches[#log.launches + 1] = l
		end
		return true
	end,
})
local fake_inventory = with_any({
	HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
	content_list = function(i) return "grug_bag" .. i end,
	get_cosmetic_hand = function() return nil end,
	hand_list = function() return "grug_weapon" end,
	melee_list = function() return "grug_weapon" end,
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
local fake_mobs = with_any({
	is_noncombatant = function() return false end,
	slow = function(ent, duration, factor)
		log.slows[#log.slows + 1] = {target = ent, duration = duration, factor = factor}
	end,
})
local env = setmetatable({
	core = fake_core, ItemStack = ItemStack, vector = vector,
	grug_core = fake_grug_core, grug_classes = GC,
	grug_inventory = fake_inventory, grug_sounds = fake_sounds,
	grug_projectiles = fake_projectiles, grug_mobs = fake_mobs,
	grug_items = {get_affixes = function(s) return s and s.affixes or {} end},
	grug_factions = {
		get_faction = function(p) return p.faction end,
		hostile = function(a, b) return a.faction ~= b.faction end,
		same_faction = function(a, b) return a.faction == b.faction end,
	},
	grug_pvp = {can_harm = function(a, b) return a.flagged and b.flagged end,
		can_support = function() return true end},
}, {__index = function(_, k)
	local g = rawget(_G, k)
	if g ~= nil and k ~= "core" and k ~= "minetest" then return g end
	return any()
end})
local swing_callbacks = {}
env.dofile = function(path)
	local chunk = setfenv(assert(loadfile(path)), env)
	if path:find("/scout%.lua$") then
		-- Keep a handle on the swing callback the kit registers.
		local real = env.grug_abilities.register_on_swing
		env.grug_abilities.register_on_swing = function(fn)
			swing_callbacks[#swing_callbacks + 1] = fn
			return real(fn)
		end
		local result = chunk()
		env.grug_abilities.register_on_swing = real
		return result
	end
	return chunk()
end
env._G = env
local GCD = ROOT .. "/mods/PLAYER/grug_classes/"
for _, file in ipairs({"talent_graph.lua", "talent_graph_scout.lua", "talent_windows.lua",
		"scout.lua"}) do
	setfenv(assert(loadfile(GCD .. file)), env)()
end
local graph = GC.graph
setfenv(assert(loadfile(ROOT .. "/" .. ABIL .. "init.lua")), env)()
local G = env.grug_abilities
local R = G.registered
check(G and R.loose and R.bladecraft and G.input, "K the real init.lua loads with the kit and input")
eq(#swing_callbacks, 1, "K the kit registers one swing callback (Close Dance)")

------------------------------------------------------------------------------
-- G: the graph data.
------------------------------------------------------------------------------
do
	-- node code -> {key = per-rank values} (class-redesign/node-list.md).
	local EXPECT = {
		Q1 = {["damage_pct:bow"] = {5, 10, 15, 20}},
		Q2 = {arrow_refund_chance = {10, 20, 30}},
		Q3 = {["cost_pct:bow"] = {-5, -10, -15}},
		Q5 = {true_draw_add = {0.10, 0.20, 0.30}},
		Q7 = {["range_add:bow"] = {1, 2, 3}},
		Q9 = {split_shot_add = {0.05, 0.10, 0.15}},
		Q10 = {["cost_pct:sidestep"] = {-10, -20, -30}},
		Q11 = {follow_the_line_add = {0.10, 0.20, 0.30}},
		Q13 = {arrowfall_add = {0.04, 0.08, 0.12}},
		V2 = {["damage_pct:blade"] = {8, 16, 24, 32}},
		V3 = {dodge_chance_add = {1, 2, 3}},
		V5 = {["cost_pct:blade"] = {-5, -10, -15}},
		V7 = {["duration_add:parry"] = {0.25, 0.5, 0.75}},
		V9 = {flourish_add = {0.05, 0.10, 0.15}},
		V10 = {opening_parry_add = {0.10, 0.20, 0.30}},
		V11 = {["cooldown_sub:sidestep"] = {1, 2, 3}, sidestep_frees = {1, 1, 1}},
		V13 = {close_dance_add = {0.05, 0.10, 0.15}},
		V14 = {max_hp_percent_add = {3, 6, 9}},
	}
	local GRANTS = {Q4 = "true_draw", Q6 = "snare_shot", Q8 = "split_shot", Q12 = "arrowfall",
		V1 = "bladecraft", V4 = "opening", V6 = "parry", V8 = "flourish", V12 = "close_dance"}
	local kit = scout_src .. class_src
	for code, effects in pairs(EXPECT) do
		local node = graph.codes[code]
		check(node ~= nil, "G node " .. code)
		if node then
			local n = 0
			for key, values in pairs(node.effects) do
				n = n + 1
				local want = effects[key]
				check(want ~= nil, "G " .. code .. " has the effect " .. key)
				for rank = 1, node.ranks do
					near(values[rank], want and want[rank], "G " .. code .. " " .. key .. " rank " .. rank)
				end
				check(graph.valid_key("scout", key), "G " .. key .. " is in the Scout's vocabulary")
				if not key:find(":", 1, true) and not graph.SHARED_KEYS[key] then
					check(kit:find('"' .. key .. '"', 1, true) ~= nil, "G the kit reads " .. key)
				end
			end
			local w = 0
			for _ in pairs(effects) do w = w + 1 end
			eq(n, w, "G " .. code .. ": its effects and no other")
		end
	end
	for code, ability in pairs(GRANTS) do
		local node = graph.codes[code]
		eq(node and node.ability, ability, "G " .. code .. " grants " .. ability)
		eq(R[ability] and R[ability].talent, node and node.id, "G " .. ability .. " is gated by " .. code)
		check(R[ability] and R[ability].talent_gated, "G " .. ability .. " is talent-gated")
	end
end

------------------------------------------------------------------------------
-- K: the kit.
------------------------------------------------------------------------------
local function ranks_of(order)
	local ranks, why = graph.apply_order("scout", order, 30)
	check(ranks ~= nil, "K the build buys legally: " .. order .. " " .. tostring(why))
	return ranks or {}
end
local QUARRY = ranks_of(graph.trees.quarry.example)
local VEIL = ranks_of(graph.trees.veil.example)

local MOB_POS = vector.new(0, 1, 10)
local serial = 0
local function scout(name, opts)
	-- Unique names: cooldowns and clocks are kept per player name.
	serial = serial + 1
	local p = new_player(name .. "#" .. serial, opts)
	G.restore_mana(p, 1e6)
	return p
end
local function unit_r(p) return own_weapon_damage(p.level) + p.dex / 10 end
local function unit_m(p) return own_weapon_damage(p.level) + p.dex / 10 end
local function cast(p, id)
	return G.try_cast(p, R[id], nil, function(m) log.flashes[#log.flashes + 1] = m end)
end

-- K1: the registrations.
do
	local ids = {}
	for _, def in ipairs(G.by_class.scout or {}) do ids[#ids + 1] = def.id end
	eq(table.concat(ids, ","), "loose,sidestep,sprint,true_draw,snare_shot,split_shot,arrowfall," ..
		"bladecraft,opening,parry,flourish,close_dance", "K1 the Scout's abilities in file order")
	check(R.loose.basic_attack == true and not R.loose.talent_gated, "K1 Loose is the basic attack")
	check(R.pinning_shot == nil, "K1 Pinning Shot is retired")
	eq(R.bladecraft.transforms, "loose", "K1 Bladecraft transforms Loose")
	eq(R.bladecraft.cooldown_key, "loose", "K1 ... and shares its cooldown key")
	for _, id in ipairs({"loose", "true_draw", "snare_shot", "split_shot", "arrowfall"}) do
		eq(table.concat(R[id].tags or {}, ","), "bow", "K1 " .. id .. " is a bow skill")
	end
	for _, id in ipairs({"bladecraft", "opening", "parry", "flourish", "close_dance"}) do
		eq(table.concat(R[id].tags or {}, ","), "blade", "K1 " .. id .. " is a blade skill")
	end
	eq(R.loose._grug_timing_line, "0.85 s cast interval", "K1 Loose's timing line shows the base")
	-- K7: a new Scout's hotbar.
	local fresh = scout("k1_fresh")
	fire("class_chosen", fresh, "scout")
	eq(row(fresh.inv, "main", 5), "loose,sidestep,sprint,strike,",
		"K7 Loose in slot 1, the starters, then Strike")
end

-- The calculator (r52/calc/data/data-scout.json, the frozen defaults;
-- round53-plan.md §3): untalented coefficient, the sample build's total
-- coefficient, cost % of P untalented and with the build, cooldown and
-- occupied time; nil occupied: the swing's weapon interval.
local CALC = {
	loose = {coef = 0.95, full = 0.95 + 0.19, cost = 0, cd = 0, occ = 0, build = QUARRY},
	true_draw = {coef = 2.2, full = 2.2 + 0.44 + 0.30, cost = 6, cost_full = 5.1, cd = 6,
		occ = 1.35, build = QUARRY},
	snare_shot = {coef = 0.45, full = 0.45 + 0.09, cost = 5, cost_full = 4.25, cd = 14,
		occ = 0.85, build = QUARRY},
	split_shot = {coef = 0.90, full = 0.90 + 0.18, splash = 0.55, splash_full = 0.55 + 0.26,
		cost = 8, cost_full = 6.8, cd = 10, occ = 1.0, build = QUARRY},
	arrowfall = {coef = 1.4, full = 1.4 + 0.28 + 0.12, cost = 16, cost_full = 13.6, cd = 60,
		occ = 2.5, build = QUARRY},
	flourish = {coef = 0.80, full = 0.80 + 0.256 + 0.15, cost = 8, cost_full = 6.8, cd = 12,
		occ = 1.0, build = VEIL},
	parry = {cost = 4, cost_full = 3.4, cd = 12, occ = 0.5, build = VEIL},
	close_dance = {cost = 14, cost_full = 11.9, cd = 60, occ = 0.25, build = VEIL},
	sidestep = {cost = 6, cost_full = 4.2, cd = 18, cd_full = 18, occ = 0.25, build = QUARRY},
}
local function mana_of(level, percent)
	return math.max(1, math.floor(fake_grug_core.base_pool(level) * percent / 100 + 0.5))
end

-- K2: damage, cost, cooldown and occupied time at levels 10, 30 and 60.
for _, level in ipairs({10, 30, 60}) do
	for id, c in pairs(CALC) do
		local def = R[id]
		for _, build in ipairs({false, true}) do
			local p = scout("k2_" .. id .. level .. tostring(build), {level = level})
			local tag = ("K2 %s L%d %s: "):format(id, level, build and "built" or "untalented")
			-- Unlock the skill itself; the build adds every talent.
			p.ranks = build and c.build or {[def.talent or ""] = def.talent and 1 or nil}
			if def.talent then p.ranks[def.talent] = 1 end
			local cost = G.effective_cost(p, def)
			eq(cost.mana, c.cost > 0 and mana_of(level, build and c.cost_full or c.cost) or nil,
				tag .. "cost")
			eq(G.effective_cooldown(p, def), build and c.cd_full or c.cd, tag .. "cooldown")
			eq(G.clock_seconds(def.occupied_cast, p, def), c.occ, tag .. "occupied (casts)")
			if c.occ > 0 then
				eq(G.clock_seconds(def.occupied_swing, p, def), c.occ, tag .. "occupied (swings)")
			end
			if c.coef then
				reset_log()
				local mob = new_mob("k2", MOB_POS)
				scene.aim = mob
				scene.query = {}
				scene.cone = {mob}
				check(cast(p, id), tag .. "the cast fires")
				local unit = (def.tags[1] == "bow") and unit_r(p) or unit_m(p)
				local hit
				if def.tags[1] == "bow" then
					hit = log.launches[1] and log.launches[1].data.damage
				else
					hit = log.damage[1] and log.damage[1].amount
				end
				near(hit, unit * (build and c.full or c.coef), tag .. "damage")
				if c.splash then
					near(log.launches[1] and log.launches[1].data.splash,
						unit * (build and c.splash_full or c.splash), tag .. "the other hits")
				end
			end
		end
	end
end
scene.aim = nil

-- K3: each talent at rank 1 and full (the shares the kit adds).
do
	local function damage_with(id, ranks, prepare)
		reset_log()
		local p = scout("k3_" .. id)
		p.ranks = ranks
		if prepare then prepare(p) end
		scene.aim = new_mob("k3", MOB_POS)
		check(cast(p, id), "K3 " .. id .. " fires")
		return log.launches[1] and log.launches[1].data, unit_r(p), p
	end
	for rank, add in ipairs({0.10, 0.20, 0.30}) do
		local data, unit = damage_with("true_draw", {quarry_true_draw = 1, quarry_firm_aim = rank})
		near(data and data.damage, unit * (2.2 + add), "K3 Firm Aim rank " .. rank)
	end
	for rank, add in ipairs({0.04, 0.08, 0.12}) do
		local data, unit = damage_with("arrowfall", {quarry_true_draw = 1, quarry_arrowfall = 1,
			quarry_iron_hail = rank})
		near(data and data.damage, unit * (1.4 + add), "K3 Iron Hail rank " .. rank)
	end
	for rank, add in ipairs({0.05, 0.10, 0.15}) do
		local data, unit = damage_with("split_shot", {quarry_split_shot = 1, quarry_broad_shot = rank})
		near(data and data.splash, unit * (0.55 + add), "K3 Broad Shot rank " .. rank)
		near(data and data.damage, unit * 0.90, "K3 ... the primary hit stays")
	end
	for rank, pct in ipairs({5, 10, 15, 20}) do
		local data, unit = damage_with("loose", {quarry_bowcraft = rank})
		near(data and data.damage, unit * 0.95 * (1 + pct / 100), "K3 Bowcraft rank " .. rank)
	end
	for rank, add in ipairs({1, 2, 3}) do
		local p = scout("k3_range")
		p.ranks = {quarry_long_view = rank}
		eq(G.get_range(p, R.loose), 25 + add, "K3 Long View rank " .. rank .. " on Loose")
		eq(G.get_range(p, R.arrowfall), 25 + add, "K3 ... and every bow skill")
	end
	-- Quiver: the refund chance (math.random pinned).
	local random = math.random
	math.random = function() return 30 end
	local data, _, p = damage_with("loose", {quarry_quiver = 3})
	eq(p.ammo, 200, "K3 Quiver rank 3 (30 %): a roll of 30 keeps the arrow")
	_, _, p = damage_with("loose", {quarry_quiver = 2})
	eq(p.ammo, 199, "K3 Quiver rank 2 (20 %): a roll of 30 spends it")
	_, _, p = damage_with("true_draw", {quarry_true_draw = 1, quarry_quiver = 3})
	eq(p.ammo, 199, "K3 Quiver saves only Loose's arrow")
	math.random = random
	local _ = data
	-- Wide Edge and Turn the Blade, Cutting Rhythm: below with their windows.
	for rank, add in ipairs({0.05, 0.10, 0.15}) do
		reset_log()
		local p2 = scout("k3_flourish")
		p2.ranks = {veil_bladecraft = 1, veil_flourish = 1, veil_wide_edge = rank}
		local mob = new_mob("k3f", vector.new(0, 0, 2))
		scene.cone = {mob}
		check(cast(p2, "flourish"), "K3 Flourish fires")
		near(log.damage[1] and log.damage[1].amount, unit_m(p2) * (0.80 + add),
			"K3 Wide Edge rank " .. rank)
	end
	for rank, sub in ipairs({1, 2, 3}) do
		local p3 = scout("k3_shake")
		p3.ranks = {veil_shake_loose = rank}
		eq(G.effective_cooldown(p3, R.sidestep), 18 - sub, "K3 Shake Loose rank " .. rank .. ": cooldown")
	end
	for rank, pct in ipairs({-5, -10, -15}) do
		local p4 = scout("k3_focus", {level = 60})
		p4.ranks = {veil_deep_focus = rank, veil_parry = 1, veil_close_dance = 1, veil_opening = 1,
			veil_flourish = 1, veil_bladecraft = 1}
		for id, base in pairs({parry = 4, close_dance = 14, opening = 5, flourish = 8}) do
			eq(G.effective_cost(p4, R[id]).mana, mana_of(60, base * (1 + pct / 100)),
				"K3 Deep Focus rank " .. rank .. " on " .. id)
		end
		eq(G.effective_cost(p4, R.sidestep).mana, mana_of(60, 6), "K3 ... never on Sidestep")
	end
	scene.aim, scene.cone = nil, {}
end

-- K4: Loose's cadence, the bow's own attack-speed affix and the floor.
do
	local p = scout("k4")
	local function interval() return G.clock_seconds(R.loose.cast_interval, p, R.loose) end
	near(interval(), 0.85, "K4 Loose every 0.85 s")
	p.bow.affixes = {{stat = "attack_speed_percent", value = 20}}
	near(interval(), 0.85 / 1.2, "K4 a 20 % bow affix divides it")
	p.bow.affixes = {{stat = "attack_speed_percent", value = 50}}
	near(interval(), 0.65, "K4 never below 0.65 s")
	p.melee.affixes = {{stat = "attack_speed_percent", value = 50}}
	p.bow.affixes = nil
	near(interval(), 0.85, "K4 the blade's affix is not the bow's")
	near(R.loose.cast_interval(nil, R.loose), 0.85, "K4 without a player: the base")
	-- The interval holds a second shot; the action clock does not (occupied 0).
	scene.aim = new_mob("k4", MOB_POS)
	check(cast(p, "loose"), "K4 a shot")
	check(not cast(p, "loose"), "K4 ... the next waits for the interval")
	wait(0.86)
	check(cast(p, "loose"), "K4 ... and fires after it")
	scene.aim = nil
end

-- K5: Bladecraft in place of Loose on both layouts; its right-click shot.
do
	local p = scout("k5")
	p.inv.lists.main[1] = ItemStack("grug_abilities:loose")
	p.inv.lists.grug_hotbar_store[3] = ItemStack("grug_abilities:loose")
	p.ranks = {veil_bladecraft = 1}
	check(G.current_form(p, R.loose) == R.bladecraft, "K5 Bladecraft is Loose's current form")
	check(not G.is_unlocked(p, "loose"), "K5 Loose itself is replaced")
	G.normalize_kit(p)
	eq(p.inv.lists.main[1].name, "grug_abilities:bladecraft", "K5 layout A: in place")
	eq(p.inv.lists.grug_hotbar_store[3].name, "grug_abilities:bladecraft", "K5 layout B: in place")
	local shot = R.bladecraft.secondary_cast
	check(shot and shot.kind == "cast" and shot.cooldown_key == "loose",
		"K5 the right-click shot shares Loose's cooldown key")
	reset_log()
	scene.aim = new_mob("k5", MOB_POS)
	check(G.try_cast(p, shot, nil, function() end), "K5 the right-click shot fires")
	near(log.launches[1] and log.launches[1].data.damage, unit_r(p) * 0.95, "K5 ... a Loose shot")
	check(not G.try_cast(p, shot, nil, function() end), "K5 ... on Loose's interval")
	-- Fine Edge reaches the blade swing, Bowcraft the shot.
	p.ranks = {veil_bladecraft = 1, veil_fine_edge = 4, quarry_bowcraft = 4}
	wait(1)
	reset_log()
	check(G.try_cast(p, shot, nil, function() end), "K5 the shot again")
	near(log.launches[1] and log.launches[1].data.damage, unit_r(p) * 0.95 * 1.2,
		"K5 Bowcraft on the right-click shot")
	near(G.family_bonus(p, R.bladecraft, "damage_pct"), 32, "K5 Fine Edge on Bladecraft's swing")
	scene.aim = nil
end

-- K6: the windows.
do
	-- Follow the Line: a landed True Draw opens it; the next Loose spends it.
	local p = scout("k6_line")
	p.ranks = {quarry_true_draw = 1, quarry_follow_the_line = 2}
	local mob = new_mob("k6", MOB_POS)
	scene.aim = mob
	reset_log()
	check(cast(p, "true_draw"), "K6 True Draw fires")
	local data = log.launches[1].data
	near(data.follow, 0.20, "K6 the window's value is Follow the Line's share")
	check(GC.get_window(p, "follow_the_line") == nil, "K6 nothing opens before it lands")
	projectiles.scout_arrow.on_hit(p, mob, data, MOB_POS, 30)
	check(GC.get_window(p, "follow_the_line") ~= nil, "K6 a landed True Draw opens it")
	eq(log.procs[1], "follow_the_line", "K6 ... with its proc flash")
	wait(1.36)
	reset_log()
	check(cast(p, "loose"), "K6 the next Loose")
	near(log.launches[1].data.damage, unit_r(p) * (0.95 + 0.20), "K6 ... gains the share")
	check(GC.get_window(p, "follow_the_line") == nil, "K6 ... and spends the window")
	wait(1)
	reset_log()
	cast(p, "loose")
	near(log.launches[1].data.damage, unit_r(p) * 0.95, "K6 the one after is plain")
	-- A dodged True Draw opens nothing; the window runs out after 3 s.
	wait(10)
	local dodger = new_mob("k6d", MOB_POS, {accept = false})
	scene.aim = dodger
	reset_log()
	cast(p, "true_draw")
	projectiles.scout_arrow.on_hit(p, dodger, log.launches[1].data, MOB_POS, 30)
	check(GC.get_window(p, "follow_the_line") == nil, "K6 a dodged True Draw opens nothing")
	scene.aim = mob
	wait(10)
	reset_log()
	cast(p, "true_draw")
	projectiles.scout_arrow.on_hit(p, mob, log.launches[1].data, MOB_POS, 30)
	wait(3.01)
	check(GC.get_window(p, "follow_the_line") == nil, "K6 the window runs out after 3 s")
	local plain = scout("k6_plain")
	plain.ranks = {quarry_true_draw = 1}
	reset_log()
	cast(plain, "true_draw")
	projectiles.scout_arrow.on_hit(plain, mob, log.launches[1].data, MOB_POS, 30)
	check(GC.get_window(plain, "follow_the_line") == nil, "K6 without Follow the Line, no window")

	-- Parry: the shield and the window at the cast, longer by Held Guard.
	for rank, extra in pairs({[0] = 0, [1] = 0.25, [3] = 0.75}) do
		local q = scout("k6_parry" .. rank, {level = 30})
		q.ranks = {veil_parry = 1, veil_held_guard = rank > 0 and rank or nil}
		reset_log()
		check(cast(q, "parry"), "K6 Parry fires (Held Guard " .. rank .. ")")
		local a = log.absorbs[1]
		near(a and a.amount, fake_grug_core.base_pool(30) * 0.10, "K6 Parry's shield: 10 % of P")
		near(a and a.duration, 2 + extra, "K6 ... for 2 s plus Held Guard")
		local w = GC.get_window(q, "parry")
		near(w and (w.expiry_us - now_us) / 1e6, 3 + extra, "K6 the window for 3 s plus Held Guard")
	end
	-- Opening: front, behind, in Parry's window (Turn the Blade), and the
	-- window spent by the landed proc only.
	local o = scout("k6_open")
	o.ranks = {veil_bladecraft = 1, veil_opening = 1, veil_parry = 1, veil_turn_the_blade = 2}
	local m = unit_m(o)
	local ctx = {weapon_damage = own_weapon_damage(30), melee_bonus = o.dex / 10, fpi = 1}
	local front = new_mob("front", vector.new(0, 0, 2), {yaw = math.pi}) -- faces the Scout
	local back = new_mob("back", vector.new(0, 0, 2), {yaw = 0}) -- faces away
	local dmg = R.opening.proc_swing(o, front, ctx)
	near(dmg, m * 1.35, "K6 Opening from the front: 1.35 M")
	dmg = R.opening.proc_swing(o, back, ctx)
	near(dmg, m * 1.80, "K6 from behind: 1.80 M, no Turn the Blade")
	cast(o, "parry")
	local post
	dmg, _, post = R.opening.proc_swing(o, front, ctx)
	near(dmg, m * (1.80 + 0.20), "K6 in Parry's window: 1.80 M plus Turn the Blade")
	check(GC.get_window(o, "parry") ~= nil, "K6 ... the preparation spends nothing")
	post()
	check(GC.get_window(o, "parry") == nil, "K6 ... the landed proc spends the window")
	o.ranks.veil_fine_edge = 4
	near(R.opening.proc_swing(o, front, ctx), m * 1.35 * 1.32, "K6 Fine Edge on Opening")
	eq(R.opening.charge, 8, "K6 Opening charges 8 s")
	eq(R.opening.cost.mana_percent, 5, "K6 ... for 5 % of P")

	-- Close Dance: the shield, the window and the swing callback.
	local c = scout("k6_dance")
	c.ranks = {veil_close_dance = 1, veil_cutting_rhythm = 3, veil_bladecraft = 1}
	local callback = swing_callbacks[1]
	eq(callback(c, {def = R.bladecraft, weapon_damage = ctx.weapon_damage}), nil,
		"K6 no bonus before Close Dance")
	reset_log()
	check(cast(c, "close_dance"), "K6 Close Dance fires")
	near(log.absorbs[1] and log.absorbs[1].amount, fake_grug_core.base_pool(30) * 0.15,
		"K6 its shield: 15 % of P")
	near(log.absorbs[1] and log.absorbs[1].duration, 6, "K6 ... for 6 s")
	local gain = callback(c, {def = R.bladecraft, weapon_damage = ctx.weapon_damage, target = front})
	near(gain and gain.damage_add, unit_m(c) * (0.35 + 0.15), "K6 a blade swing gains 0.35 M plus Cutting Rhythm")
	gain.on_landed(c, {target = front})
	eq(log.fx[#log.fx].id, "close_dance_swing", "K6 ... and flashes when it lands")
	check(callback(c, {def = R.strike, weapon_damage = 1}) ~= nil, "K6 Strike is a blade swing too")
	eq(callback(c, {def = R.opening, proc = R.opening, weapon_damage = 1}), nil,
		"K6 a proc swing (Opening) gains nothing")
	eq(callback(c, {def = R.charge or {id = "x"}, weapon_damage = 1}), nil, "K6 a non-blade swing gains nothing")
	wait(6.01)
	eq(callback(c, {def = R.bladecraft, weapon_damage = 1}), nil, "K6 the window runs out after 6 s")
	scene.aim = nil
end

-- K7: refusals pay nothing; the PvP target check on splash and cone.
do
	local p = scout("k7")
	p.ranks = {quarry_true_draw = 1, quarry_arrowfall = 1, quarry_split_shot = 1}
	local mob = new_mob("k7", MOB_POS)
	scene.aim = mob
	local mana = G.get_mana(p)
	p.ammo = 3
	reset_log()
	check(not cast(p, "arrowfall"), "K7 Arrowfall with 3 arrows is refused")
	eq(log.flashes[1], "Arrowfall needs 4 arrows.", "K7 ... and says so")
	check(G.get_mana(p) == mana and G.ready(p, "arrowfall") and p.ammo == 3 and #log.launches == 0,
		"K7 ... nothing paid, no cooldown, no arrow")
	p.ammo = 0
	reset_log()
	check(not cast(p, "loose"), "K7 Loose without an arrow is refused")
	eq(log.flashes[1], "You need an arrow.", "K7 ... and says so")
	p.ammo = 10
	scene.aim = nil
	reset_log()
	check(not cast(p, "loose"), "K7 no target, no shot")
	eq(log.flashes[1], "No hostile target in your crosshair.", "K7 ... and says so")
	scene.aim = mob
	p.bow = nil
	reset_log()
	check(not cast(p, "true_draw"), "K7 no bow, no shot")
	check(G.get_mana(p) == mana and G.ready(p, "true_draw"), "K7 ... nothing paid")
	p.bow = weapon("grug_gear:bow_wood", 15, 1)
	scene.spawn_fail = true
	reset_log()
	check(not cast(p, "loose") and p.ammo == 10, "K7 a failed launch spends no arrow")
	scene.spawn_fail = false
	-- Arrowfall: four arrows, one trail, one cast cue, an impact per arrow.
	reset_log()
	check(cast(p, "arrowfall"), "K7 Arrowfall fires")
	eq(#log.launches, 4, "K7 ... four arrows")
	eq(p.ammo, 6, "K7 ... four arrows spent")
	local trails = 0
	for _, l in ipairs(log.launches) do
		if l.trail then trails = trails + 1 end
		eq(l.sound_launch, "cast_arrowfall", "K7 the volley sounds through its cast cue")
	end
	eq(trails, 1, "K7 one trail for the volley")
	eq(log.launches[1].trail and log.launches[1].trail.effect, "arrowfall_trail", "K7 ... the volley's own")
	local impacts = 0
	local before = #log.sounds
	for _, l in ipairs(log.launches) do projectiles.scout_arrow.on_hit(p, mob, l.data, MOB_POS, 30) end
	for i = before + 1, #log.sounds do
		if log.sounds[i].event == "arrowfall_impact" then impacts = impacts + 1 end
	end
	eq(impacts, 4, "K7 an impact cue per arriving arrow")
	local bursts = 0
	for _, f in ipairs(log.fx) do if f.id == "arrowfall_impact" then bursts = bursts + 1 end end
	eq(bursts, 1, "K7 one impact burst (the first arrow)")
	wait(3)
	reset_log()
	cast(p, "true_draw")
	eq(log.launches[1].sound_launch, nil, "K7 a single shot keeps the bow's own launch cue")
	eq(log.launches[1].trail and log.launches[1].trail.effect, "skill_arrow", "K7 ... and its trail")
	-- Split Shot: the splash through the shared target check, at most 2,
	-- never the primary.
	local enemy_flagged = new_player("k7_enemy", {faction = "throng", flagged = true})
	local enemy_unflagged = new_player("k7_enemy2", {faction = "throng"})
	local ally = new_player("k7_ally", {faction = "accord", flagged = true})
	p.flagged = true
	local m2, m3 = new_mob("m2", vector.new(1, 1, 10)), new_mob("m3", vector.new(2, 1, 10))
	scene.query = {mob, enemy_unflagged, ally, enemy_flagged, m2, m3}
	wait(3)
	reset_log()
	check(cast(p, "split_shot"), "K7 Split Shot fires")
	local data = log.launches[1].data
	reset_log()
	projectiles.scout_arrow.on_hit(p, mob, data, MOB_POS, 30)
	local hit = {}
	for _, d in ipairs(log.damage) do hit[#hit + 1] = d.target.name end
	eq(table.concat(hit, ","), "k7,k7_enemy,m2", "K7 the primary, then 2 others: never the primary " ..
		"again, an unflagged player or an ally")
	eq(log.areas[1] and log.areas[1].opts.radius, 3, "K7 within 3 m of the target")
	eq(log.areas[1] and log.areas[1].opts.cap, 2, "K7 ... at most 2")
	local splinters = 0
	for _, f in ipairs(log.fx) do if f.id == "split_shot_splinter" then splinters = splinters + 1 end end
	eq(splinters, 2, "K7 a splinter per other hit")
	-- Flourish: the cone through the same check.
	local f = scout("k7_flourish")
	f.flagged = true
	f.ranks = {veil_bladecraft = 1, veil_flourish = 1}
	scene.cone = {enemy_unflagged, ally, mob, enemy_flagged, m2, m3}
	reset_log()
	check(cast(f, "flourish"), "K7 Flourish fires")
	hit = {}
	for _, d in ipairs(log.damage) do hit[#hit + 1] = d.target.name end
	eq(table.concat(hit, ","), "k7,k7_enemy,m2", "K7 Flourish: the 3 nearest legal hostiles")
	local cone = log.areas[1] and log.areas[1].opts
	check(cone and cone.radius == 3 and cone.angle == 90 and cone.cap == 3, "K7 a 90 degree, 3 m cone")
	eq(log.fx[1] and log.fx[1].id, "flourish", "K7 ... and its sweep")
	scene.query, scene.cone, scene.aim = {}, {}, nil
end

-- K8: Snare Shot's slow, Sidestep and Shake Loose.
do
	local p = scout("k8")
	p.ranks = {quarry_snare_shot = 1}
	local mob = new_mob("k8", MOB_POS)
	scene.aim = mob
	reset_log()
	check(cast(p, "snare_shot"), "K8 Snare Shot fires")
	local data = log.launches[1].data
	reset_log()
	projectiles.scout_arrow.on_hit(p, mob, data, MOB_POS, 30)
	local s = log.slows[1]
	check(s and s.target == mob.ent and s.duration == 3 and math.abs(s.factor - 0.65) < 1e-9,
		"K8 a landed Snare Shot slows by 35 % for 3 s")
	eq(log.fx[1] and log.fx[1].id, "snare_hit", "K8 ... with its ring")
	local dodger = new_mob("k8d", MOB_POS, {accept = false})
	reset_log()
	projectiles.scout_arrow.on_hit(p, dodger, data, MOB_POS, 30)
	eq(#log.slows, 0, "K8 a dodged one slows nothing")
	local target = new_player("k8_target", {faction = "throng"})
	reset_log()
	projectiles.scout_arrow.on_hit(p, target, data, MOB_POS, 30)
	check(log.slows[1] and log.slows[1].name == "scout_snare" and
		math.abs(log.slows[1].speed + 0.35) < 1e-9, "K8 a player is slowed through the movement modifier")
	-- Sidestep: +15 dodge for 3 s; Shake Loose clears slows and roots.
	local q = scout("k8_step")
	reset_log()
	check(cast(q, "sidestep"), "K8 Sidestep fires")
	eq(GC.get_scout_dodge_add(q), 15, "K8 +15 dodge")
	eq(#log.cleared, 0, "K8 ... without Shake Loose nothing is cleared")
	wait(2.99)
	eq(GC.get_scout_dodge_add(q), 15, "K8 ... still at 2.99 s")
	wait(0.02)
	eq(GC.get_scout_dodge_add(q), 0, "K8 ... gone after 3 s")
	eq(GC.get_scout_dodge_cap(q), 30, "K8 the ordinary 30 % cap")
	q.ranks = {veil_shake_loose = 1}
	wait(20)
	reset_log()
	check(cast(q, "sidestep"), "K8 Sidestep with Shake Loose")
	check(log.cleared[1] == q, "K8 Shake Loose clears slows and roots")
	scene.aim = nil
end

-- K9: tooltips show current-level numbers.
do
	local p = scout("k9", {level = 30})
	p.ranks = {quarry_true_draw = 1}
	local text = R.true_draw.description_for(p, R.true_draw)
	check(text:find(tostring(math.floor(unit_r(p) * 2.2)) .. " damage", 1, true) ~= nil,
		"K9 True Draw's tooltip: its damage at the level (" .. text .. ")")
	text = R.loose.description_for(p, R.loose)
	check(text:find(tostring(math.floor(unit_r(p) * 0.95)) .. " damage", 1, true) ~= nil and
		text:find("0.85 s", 1, true) ~= nil, "K9 Loose's tooltip: damage and cadence (" .. text .. ")")
	for _, def in ipairs(G.by_class.scout) do
		if def.description_for then
			local ok, out = pcall(def.description_for, p, def)
			check(ok and type(out) == "string" and not out:find("nil", 1, true),
				"K9 " .. def.id .. "'s tooltip renders (" .. tostring(out) .. ")")
		end
	end
end

------------------------------------------------------------------------------
-- I: the real input.lua.
------------------------------------------------------------------------------
do
	local input = G.input
	local p = scout("i_scout")
	p.inv.lists.main[1] = ItemStack("grug_abilities:loose")
	local mob = new_mob("i", vector.new(0, 1.5, 2))
	scene.aim = mob
	local function step(controls)
		p.controls = controls
		wait(0.05)
		input.step(p)
	end
	-- Loose: LMB shoots, held repeats on the cadence.
	reset_log()
	step({dig = true})
	eq(#log.launches, 1, "I Loose: LMB shoots")
	for _ = 1, 16 do step({dig = true}) end -- 0.8 s
	eq(#log.launches, 1, "I ... held, the next shot waits for 0.85 s")
	step({dig = true})
	step({dig = true})
	eq(#log.launches, 2, "I ... then shoots again")
	eq(#log.swings, 0, "I ... and never swings")
	step({})
	step({})
	-- An empty quiver: a foe in reach gets Strike (K8).
	p.ammo = 0
	wait(2)
	reset_log()
	step({dig = true})
	eq(#log.launches, 0, "I no arrow, no shot")
	eq(log.swings[1] and log.swings[1].raw ~= nil and #log.swings, 1, "I ... Strike swings at the foe")
	step({})
	step({})
	p.ammo = 50
	-- Bladecraft: LMB swings the blade, RMB shoots.
	p.ranks = {veil_bladecraft = 1}
	p.inv.lists.main[1] = ItemStack("grug_abilities:bladecraft")
	wait(2)
	reset_log()
	step({dig = true})
	eq(#log.swings, 1, "I Bladecraft: LMB swings")
	eq(#log.launches, 0, "I ... and shoots nothing")
	near(log.swings[1] and log.swings[1].raw, unit_m(p), "I ... a plain blade swing (1 M)")
	step({})
	step({})
	wait(2)
	reset_log()
	step({place = true})
	eq(#log.launches, 1, "I Bladecraft: RMB shoots")
	eq(#log.swings, 0, "I ... and swings nothing")
	-- The shot pushes the next swing (the action clock): LMB right after
	-- swings nothing until the weapon interval has passed.
	step({})
	step({dig = true})
	eq(#log.swings, 0, "I a swing right after the shot waits (the shared clock)")
	for _ = 1, 20 do step({dig = true}) end
	eq(#log.swings, 1, "I ... and lands after the blade's interval")
	step({})
	scene.aim = nil
end

if failures > 0 then
	print(("R53 SCOUT PORTABLE FAIL %d of %d checks"):format(failures, checks))
	os.exit(1)
end
print("R53 SCOUT PORTABLE PASS checks=" .. checks)
