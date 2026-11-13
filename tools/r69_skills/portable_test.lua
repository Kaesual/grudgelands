-- Round 69 lane SKILLS portable test (LuaJIT; round69-plan.md ruling 9, §4
-- SKILLS): the exact numbers in the skill tooltips.
--
--   luajit tools/r69_skills/portable_test.lua [repo]
--
--   A  the REAL grug_abilities/init.lua with its whole dofile chain, the REAL
--      talent_windows.lua, grug_core/area.lua and combat.lua's curves in a
--      sandbox (the tools/r53_hooks pattern), the talents answered from the
--      REAL graph: for every damaging skill of every class at levels 10, 30
--      and 60, with no talents and with every node at full rank, each
--      "N damage" of its text against what a hit computes: a real swing's
--      transaction, a real cast's projectile data or damage call, or its
--      values() where a ground area or a dash stands between (their casts
--      pass exactly that);
--   B  the fallbacks hold no number, a Strike reads the fists and a classless
--      character works, and no damage text keeps a bare number;
--   C  the refresh: a level, talent, equipment or status change rewrites the
--      hotbar stack; pure wear writes nothing;
--   D  the REAL talent_graph_ui.lua: every granting node ends in its skill's
--      text, the very string of its stack, learned or not; modifier nodes and
--      skills without a player-specific text stay as they are; the tooltip's
--      wrap and its largest size (printed, a comparison);
--   E  through tools/r44_ts: the tooltip and the strip on the rendered page,
--      the strip's status before the numbers, and an equipment or status
--      change re-rendering the open page, and only that page.
-- Prints "R69 SKILLS PORTABLE PASS checks=<n>" or the failures (exit 1).

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
	function p:get_properties() return {hp_max = 100, eye_height = 1.5} end
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
})

local log = {damage = {}, shots = {}}
local melee_prepare, melee_finish
local transactions = {}
local current_target
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
	add_absorb = function(_, _, amount) return amount end,
	heal_player = function(_, _, amount) return amount end,
	combat_eye_pos = function(p) return V.offset(p.pos, 0, 1.5, 0) end,
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
check(G and R.retort and input_api and melee_prepare and C.open_window and graph.node_text,
	"the real kit, the windows and the real tree text load")
local function scaled(p, amount)
	return fake_grug_core.scale_player_damage(p, nil, amount)
end

local function text_of(p, id)
	return G.skill_text(p, R[id])
end
local function numbers(text)
	local out = {}
	for n in text:gmatch("(%d+) damage") do out[#out + 1] = n end
	return table.concat(out, ",")
end
local function pins(p, id, label, ...)
	eq(numbers(text_of(p, id)), table.concat({...}, ","), label .. " " .. id ..
		" [" .. text_of(p, id) .. "]")
end

-- One swing of `def` on the clock: its transaction. `ready` opens a window
-- after the wait.
local function swing(p, def, target, ready)
	current_target = target
	now_us = now_us + 10 * 1e6 -- past the interval and an 8 s charge
	if ready then ready() end
	local before = #transactions
	input_api.swing(p, def)
	current_target = nil
	return transactions[before + 1]
end

-- The last raw damage a cast passed on, after clearing the log.
local function cast_amount(p, id, target)
	log.damage = {}
	current_target = target
	check(R[id].cast(p, nil, R[id]) == true, id .. " casts")
	current_target = nil
	return log.damage[#log.damage]
end
local function cast_shot(p, id, target)
	log.shots = {}
	current_target = target
	check(R[id].cast(p, nil, R[id]) == true, id .. " shoots")
	current_target = nil
	return log.shots[#log.shots]
end

------------------------------------------------------------------------------
-- A: every number against its hit.
------------------------------------------------------------------------------
local function own_sword(level) return weapon("sword", 4 + math.floor(0.35 * level + 0.5), 1) end
local function own_staff(level)
	return weapon("staff", 3, 1.5, {staff = 1}, level)
end
local function own_bow(level)
	return weapon("bow", 5 + math.floor(0.4 * level + 0.5), 1, {bow = 1})
end

for _, level in ipairs({10, 30, 60}) do
	for _, tier in ipairs({"none", "full"}) do
		local L = "A L" .. level .. " " .. tier .. ":"
		local function ranks(class) return tier == "full" and full_ranks(class) or {} end

		-- The Warrior.
		do
			clear_scene()
			local p = new_player("warrior", level, {ranks = ranks("warrior"), melee = own_sword(level)})
			G.add_rage(p, 100)
			local mob = new_mob(0, 2)
			local plain = swing(p, R.strike, mob)
			pins(p, "strike", L, plain.scaled_damage)
			local swing_plain = swing(p, R.retort, mob)
			local readied = swing(p, R.retort, mob, function()
				C.open_window(p, "retort", {duration = 4, icd = 6, label = "Retort"})
			end)
			pins(p, "retort", L, swing_plain.scaled_damage, readied.scaled_damage)
			check(readied.scaled_damage > swing_plain.scaled_damage, L .. " a readied Retort hits harder")
			G.add_rage(p, 100)
			pins(p, "mighty_blow", L, swing(p, R.mighty_blow, mob).scaled_damage)
			G.add_rage(p, 100)
			local other = new_mob(0.3, 2)
			local blow = swing(p, R.broadstroke, mob)
			check(blow.proc == R.broadstroke, L .. " the Broadstroke proc fires")
			log.damage = {}
			melee_finish(melee_prepare(p, mob, blow), {landed = true, grant_rage = true})
			check(log.damage[1] ~= nil, L .. " Broadstroke reaches the other")
			pins(p, "broadstroke", L, blow.scaled_damage, scaled(p, log.damage[1] or 0))
			other.ent.health = 0
			G.add_rage(p, 100)
			local cripple = swing(p, R.hamstring, mob)
			check(cripple.proc == R.hamstring, L .. " the Hamstring proc fires")
			pins(p, "hamstring", L, cripple.scaled_damage)
			pins(p, "charge", L, scaled(p, R.charge.values(p).damage))
		end

		-- The Mage.
		do
			clear_scene()
			local p = new_player("mage", level, {ranks = ranks("mage"), weapon = own_staff(level)})
			local mob = new_mob(0, 2)
			for _, id in ipairs({"fiery_spark", "cold_spark", "flame_lance"}) do
				pins(p, id, L, scaled(p, cast_shot(p, id, mob).damage))
			end
			local ball = cast_shot(p, "fireball", mob)
			pins(p, "fireball", L, scaled(p, ball.damage), scaled(p, ball.splash_damage))
			pins(p, "ice_wave", L, scaled(p, cast_amount(p, "ice_wave")))
			pins(p, "ice_nova", L, scaled(p, cast_amount(p, "ice_nova")))
			for _, id in ipairs({"meteor", "fire_rain", "winter_field"}) do
				pins(p, id, L, scaled(p, R[id].values(p, R[id]).damage))
			end
		end

		-- The Priest.
		do
			clear_scene()
			local p = new_player("priest", level, {ranks = ranks("priest"), weapon = own_staff(level)})
			local mob = new_mob(0, 2)
			for _, id in ipairs({"smite", "rebuke", "word_of_ruin", "final_word"}) do
				pins(p, id, L, scaled(p, cast_amount(p, id, mob)))
			end
			pins(p, "censure", L, scaled(p, R.censure.values(p).damage))
		end

		-- The Scout: the Melee slot's blade, the Weapon slot's bow.
		do
			clear_scene()
			local p = new_player("scout", level, {ranks = ranks("scout"),
				melee = own_sword(level), weapon = own_bow(level)})
			G.restore_mana(p, 1e6)
			local mob = new_mob(0, 2) -- faces +z: the Scout stands behind it
			for _, id in ipairs({"loose", "true_draw", "snare_shot", "arrowfall"}) do
				pins(p, id, L, scaled(p, cast_shot(p, id, mob).damage))
			end
			local split = cast_shot(p, "split_shot", mob)
			pins(p, "split_shot", L, scaled(p, split.damage), scaled(p, split.splash))
			pins(p, "strike", L, swing(p, R.strike, mob).scaled_damage)
			pins(p, "bladecraft", L, swing(p, R.bladecraft, mob).scaled_damage,
				scaled(p, cast_shot(p, "loose", mob).damage))
			pins(p, "flourish", L, scaled(p, cast_amount(p, "flourish")))
			local rear = swing(p, R.opening, mob)
			check(rear.proc == R.opening, L .. " the Opening proc fires")
			mob.yaw = math.pi -- now it faces the Scout
			local front = swing(p, R.opening, mob)
			local parried = swing(p, R.opening, mob, function()
				C.open_window(p, "parry", {duration = 3, label = "Parry"})
			end)
			if tier == "full" then
				check(parried.scaled_damage > rear.scaled_damage, L .. " Turn the Blade raises the window's hit")
				pins(p, "opening", L, front.scaled_damage, rear.scaled_damage, parried.scaled_damage)
			else
				eq(parried.scaled_damage, rear.scaled_damage, L .. " behind equals the window untalented")
				pins(p, "opening", L, front.scaled_damage, rear.scaled_damage)
			end
			-- Close Dance adds to a plain blade swing.
			local before = swing(p, R.strike, mob).raw_damage
			local danced = swing(p, R.strike, mob, function()
				C.open_window(p, "close_dance", {duration = 6, label = "Close Dance"})
			end).raw_damage
			pins(p, "close_dance", L, scaled(p, danced - before))
		end
	end
end
clear_scene()

------------------------------------------------------------------------------
-- B: the fallbacks, the fists, the classless character, the wording.
------------------------------------------------------------------------------
do
	for id, def in pairs(R) do
		eq(numbers(def.description), "", "B " .. id .. "'s fallback holds no damage number")
	end
	-- A warrior without a weapon: the bare hand plus the melee bonus.
	local p = new_player("warrior", 30, {str = 40})
	local mob = new_mob(0, 2)
	pins(p, "strike", "B fists:", swing(p, R.strike, mob).scaled_damage)
	eq(numbers(text_of(p, "strike")), tostring(scaled(p, 5)), "B the fists are hand 1 + Str/10")
	check(text_of(p, "strike"):find("Generates", 1, true), "B Strike keeps its rage line")
	-- Another weapon changes the number.
	p.melee = weapon("axe", 30, 1.4)
	swing(p, R.strike, mob) -- a slot swap starts its interval, no instant attack
	pins(p, "strike", "B an axe:", swing(p, R.strike, mob).scaled_damage)
	-- Without a class.
	local nobody = new_player(nil, 5, {str = 10})
	eq(numbers(text_of(nobody, "strike")), tostring(scaled(nobody, 2)), "B no class: the fists")
	check(not text_of(nobody, "strike"):find("rage", 1, true), "B no class: no rage line")
	-- A status's spell damage: the hit and the text move together.
	local mage = new_player("mage", 30, {weapon = own_staff(30)})
	mage.spell_percent = 10
	pins(mage, "fiery_spark", "B a status:", scaled(mage, cast_shot(mage, "fiery_spark", mob).damage))
	-- Gear Intelligence enters the Priest's support numbers on both.
	local priest = new_player("priest", 30, {weapon = own_staff(30)})
	priest.support = 1.5
	check(text_of(priest, "heal"):find(tostring(math.floor(R.heal.values(priest).heal)), 1, true),
		"B Heal shows its amount")
	-- Exactly these wordings, the form the ruling asks for.
	local nova = text_of(mage, "ice_nova")
	check(nova:find("%d+ damage\nand roots them for 2%.5 s%."), "B Ice Nova's form: " .. nova)
	check(not nova:find("you for %d+\n"), "B Ice Nova's old wording is gone")
	clear_scene()
end

------------------------------------------------------------------------------
-- C: the refresh.
------------------------------------------------------------------------------
do
	local p = new_player("warrior", 30, {melee = own_sword(30)})
	local mage = new_player("mage", 30, {weapon = own_staff(30)})
	p.inv.lists.main[1] = G.stack_for(p, "strike")
	mage.inv.lists.main[1] = G.stack_for(mage, "fiery_spark")
	local function shown(q) return q.inv.lists.main[1].fields.description end
	local function follows(q, change, kind, ...)
		local before = shown(q)
		change()
		eq(shown(q), before, "C nothing moves before the event: " .. kind)
		fire(kind, q, ...)
		check(shown(q) ~= before, "C " .. kind .. " rewrites the stack")
		eq(numbers(shown(q)), numbers(text_of(q, q == p and "strike" or "fiery_spark")),
			"C and it shows the current number: " .. kind)
	end
	follows(p, function() p.melee = weapon("axe", 30, 1.4) end, "equipment", "grug_weapon", "swap")
	follows(p, function() p.level = 40 end, "level", 30, 40)
	follows(p, function() p.str = 90 end, "equipment", "grug_ring", "swap")
	follows(mage, function() mage.spell_percent = 10 end, "status")
	-- Pure wear: no write, whatever changed.
	local writes = p.inv.writes or 0
	p.melee = weapon("axe", 31, 1.4)
	fire("equipment", p, "grug_weapon", "durability_metadata")
	eq(p.inv.writes or 0, writes, "C pure wear writes nothing")
	-- A second identical event writes nothing either: compare first.
	p.melee = weapon("axe", 30, 1.4)
	fire("equipment", p, "grug_weapon", "swap")
	writes = p.inv.writes or 0
	fire("status", p)
	fire("equipment", p, "grug_weapon", "swap")
	eq(p.inv.writes or 0, writes, "C an unchanged refresh writes nothing")
	-- A talent change.
	local q = new_player("mage", 60, {weapon = own_staff(60)})
	q.inv.lists.main[1] = G.stack_for(q, "fiery_spark")
	local before = shown(q)
	q.ranks = {ember_fire_mastery = 4}
	fire("talents", q)
	check(shown(q) ~= before, "C a talent change rewrites the stack")
	clear_scene()
end

------------------------------------------------------------------------------
-- D: the tree's text.
------------------------------------------------------------------------------
do
	local STATIC = {taunt = true, bellow = true, blink = true}
	local worst, worst_id = 0, nil
	for _, id in ipairs(graph.node_ids) do
		local node = graph.nodes[id]
		for _, ranks in ipairs({{}, full_ranks(node.class)}) do
			local p = new_player(node.class, 60, {ranks = ranks, melee = own_sword(60),
				weapon = node.class == "scout" and own_bow(60) or own_staff(60)})
			local text = graph.node_text(p, node)
			if node.ability and not STATIC[node.ability] then
				local skill = G.skill_text(p, R[node.ability]):gsub("%s*\n%s*", " ")
				eq(text, node.description .. " At your level: " .. skill,
					"D " .. id .. " ends in its skill's text")
				check(not text:find("\n", 1, true), "D " .. id .. " is one paragraph")
			elseif not next(node.effects) or node.ability then
				eq(text, node.description, "D " .. id .. " stays its description")
			else
				local _, count = text:gsub("At your level", "")
				check(count <= 1, "D " .. id .. " keeps at most its own amounts")
			end
			local tooltip = ("%s (%d/%d) — %s Locked: %s"):format(node.name, 0, node.ranks, text,
				"Needs 20 points in this tree and a rank in Far Frost.")
			local wrapped = fake_inventory.wrap_text(tooltip, 58)
			local lines = 0
			for line in (wrapped .. "\n"):gmatch("(.-)\n") do
				lines = lines + 1
				check(#line <= 60, "D " .. id .. "'s tooltip wraps: " .. line)
			end
			if lines > worst then worst, worst_id = lines, id end
		end
	end
	check(worst <= 10, "D the longest tooltip stays at 10 lines, got " .. worst)
	print(("D the longest node tooltip: %d lines at width 58 (%s, locked)"):format(worst, worst_id))
	-- Learned or not, the same number; a talent the player has counts.
	local bare = new_player("mage", 60, {weapon = own_staff(60)})
	local fire_mastery = new_player("mage", 60, {weapon = own_staff(60),
		ranks = {ember_fire_mastery = 4}})
	local node = graph.nodes.ember_fireball
	eq(graph.node_text(bare, node):match("(%d+) damage,"), numbers(text_of(bare, "fireball")):match("^%d+"),
		"D an unlearned Fireball shows its number")
	check(graph.node_text(fire_mastery, node) ~= graph.node_text(bare, node),
		"D and Fire Mastery's ranks move it before Fireball is learned")
	clear_scene()
end

------------------------------------------------------------------------------
-- E: the rendered page, through the talent page harness.
------------------------------------------------------------------------------
do
	local H = dofile(ROOT .. "/tools/r44_ts/harness.lua")(ROOT)
	local real_graph = grug_classes.graph
	local fireball = real_graph.nodes.ember_fireball
	local amount = 42
	grug_abilities.registered.fireball = {description_for = function()
		return "Line one:\n" .. amount .. " damage."
	end}
	grug_abilities.skill_text = function(p, def) return def.description_for(p, def) end
	local mage = H.make_player("e_mage", "mage", 60, "")
	H.join(mage)
	local fs = H.render(mage, "grug_classes:talents")
	check(fs:find("At your level: Line one: 42 damage.", 1, true) or
		fs:find("At your level: Line one: 42\ndamage.", 1, true), "E the tooltip carries the text")
	local page = sfinv.pages["grug_classes:talents"]
	local ctx = sfinv.get_or_create_context(mage)
	-- A refused click selects the node; the strip keeps the reason in view.
	mage.level = 1
	page:on_player_receive_fields(mage, ctx, {[real_graph.node_field(fireball.id)] = "x"})
	local strip = mage.formspec:match("textarea%[[^;]*;[^;]*;;;(.-)%]")
	local reason, numbers_at = strip and strip:find("  ", 1, true), strip and strip:find("At your level", 1, true)
	check(strip and reason and numbers_at and reason < numbers_at, "E the strip: its status before the numbers")
	check(strip and not strip:find("\n", 1, true), "E and one paragraph")
	mage.level = 60
	-- An equipment or status change re-renders the open page.
	amount = 43
	for _, fn in ipairs(H.registered.equipment_change) do fn(mage, "grug_weapon", "durability_metadata") end
	check(mage.formspec:find("42", 1, true) ~= nil, "E pure wear re-renders nothing")
	for _, fn in ipairs(H.registered.equipment_change) do fn(mage, "grug_weapon", "swap") end
	check(mage.formspec:find("Line one: 43", 1, true) ~= nil, "E an equipment change re-renders the page")
	amount = 44
	for _, fn in ipairs(H.registered.status_modifiers) do fn(mage) end
	check(mage.formspec:find("Line one: 44", 1, true) ~= nil, "E a status change re-renders the page")
	-- On another page nothing is sent.
	sfinv.register_page("r69:other", {title = "Other", get = function() return "other" end})
	sfinv.set_page(mage, "r69:other")
	local shown = mage.formspec
	amount = 45
	for _, fn in ipairs(H.registered.status_modifiers) do fn(mage) end
	eq(mage.formspec, shown, "E another page is not re-sent")
end

if failures > 0 then
	error(("R69 SKILLS PORTABLE FAIL %d of %d checks"):format(failures, checks))
end
print("R69 SKILLS PORTABLE PASS checks=" .. checks)
