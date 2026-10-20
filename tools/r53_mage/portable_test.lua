-- Round 53 lane MAGE portable test (LuaJIT; round53-plan.md §4 MAGE, §6
-- "Class fixtures"): the new Mage kit (grug_abilities/kits_mage.lua) on the
-- REAL grug_abilities/init.lua with its whole dofile chain in a sandbox (the
-- tools/r53_hooks pattern), and the Mage's REAL talent graph
-- (grug_classes/talent_graph.lua + talent_graph_mage.lua) answering the
-- talent bonuses as talents.lua sums them.
--
--   luajit tools/r53_mage/portable_test.lua [repo]
--
--   R  registration: the eleven skills in file order (Fiery Spark first),
--      gates and talent ids against the graph's granting nodes, the two
--      transforms and their shared keys, tags, clocks, the K6 rows, the four
--      projectiles with their sounds; Cinderfall and Glacial Ward are gone;
--   N  numbers against the calculator (r52/calc data-mage.json plus the
--      stored change tuning/mage_rime): untalented damage (raw D before the
--      level scalar), cost, cooldown and occupied time at levels 10, 30 and
--      60, and the full Ember and Rime builds (the trees' example orders) at
--      level 60;
--   T  every talent at rank 1 and at full rank;
--   C  casts through try_cast: launch data, refusals cost nothing, mana,
--      cooldowns, the shared cast interval of the two sparks, the action
--      clock, Flame Lance's trail;
--   P  the projectiles' hits: Fireball's splash (never the primary target),
--      Cold Spark's slow;
--   A  the areas: Meteor, Fire Rain and Winter Field refuse "No ground
--      found." before cost and cooldown, then land once through
--      area.delayed with their cards and impact cue at the anchor; Ice Wave's
--      cone and slow; Ice Nova's circle and root; the filter never takes an
--      unflagged or a same-faction player, nor an evading mob;
--   W  Cold Shock: Nova opens the window once (proc flash), the next Cold
--      Spark spends it, it runs out after 4 s, no window without the talent;
--   M  Rime Mantle: the armor status and the shield;
--   L  the transforms in place on layouts A and B and the new character's
--      hotbar (K7); tooltips show the current numbers.
-- Prints "R53 MAGE PORTABLE PASS checks=<n>" or the failures (exit 1).

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

------------------------------------------------------------------------------
-- Formulas (grug_core/combat.lua, the calculator's unit note).
------------------------------------------------------------------------------
local function base_pool(level)
	level = math.max(1, math.min(60, math.floor(level)))
	return math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
end
local function armor_k(level)
	return 20 + 0.5 * math.min(level, 60) + 8.5 * math.max(level - 60, 0)
end
-- D before the level scalar with an own-level caster weapon and no gear:
-- spell_base = round(4 + 0.35 L), Int = 10 + 3 (L - 1).
local function own_spell_base(level) return math.floor(4 + 0.35 * level + 0.5) end
local function int_of(level) return 10 + 3 * (level - 1) end
local function D(level) return own_spell_base(level) + int_of(level) / 10 end
local function mana_cost(level, percent)
	return math.max(1, math.floor(base_pool(level) * percent / 100 + 0.5))
end

------------------------------------------------------------------------------
-- The real talent graph with the Mage's data.
------------------------------------------------------------------------------
local graph
do
	local genv = setmetatable({
		grug_classes = {registered_classes = {mage = {name = "Mage"}}},
		grug_core = {armor_k = armor_k},
	}, {__index = _G})
	setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph.lua")), genv)()
	setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_classes/talent_graph_mage.lua")), genv)()
	graph = genv.grug_classes.graph
end
check(graph and graph.trees.ember and graph.trees.rime, "G the Mage's graph loads")

-- talents.lua's sums: each ranked node's effect values at its rank.
local function sums_of(ranks)
	local sums = {}
	for id, rank in pairs(ranks) do
		local def = graph.nodes[id]
		assert(def, "unknown node " .. id)
		for key, values in pairs(def.effects or {}) do
			sums[key] = (sums[key] or 0) + values[rank]
		end
	end
	return sums
end

------------------------------------------------------------------------------
-- The sandbox: the real init.lua and its dofile chain (tools/r53_hooks K).
------------------------------------------------------------------------------
local now_us = 1e9
local function wait(s) now_us = now_us + s * 1e6 end
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end
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
local function row(inv, l, n)
	local out = {}
	for i = 1, n do out[i] = inv.lists[l][i].name:gsub("^grug_abilities:", "") end
	return table.concat(out, ",")
end

local players = {}
local function new_player(name, opts)
	opts = opts or {}
	local p = {name = name, class = opts.class or "mage", level = opts.level or 60,
		ranks = opts.ranks or {}, hp = 100, inv = new_inventory(), wield = 1,
		pos = opts.pos or {x = 0, y = 0, z = 0}, faction = opts.faction or "accord",
		flagged = opts.flagged, meta = {}}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return self.pos end
	function p:set_pos(pos) self.pos = pos end
	function p:get_look_dir() return {x = 0, y = 0, z = 1} end
	function p:get_look_horizontal() return 0 end
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:get_wield_index() return self.wield end
	function p:get_meta() return ItemStack("x"):get_meta() end
	function p:get_properties() return {hp_max = 1000, eye_height = 1.47} end
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add() return 1 end
	function p:hud_change() end
	function p:hud_remove() end
	players[name] = p
	return p
end

-- A mob: a live hostile unless told otherwise.
local function new_mob(opts)
	opts = opts or {}
	local ent = {name = "test:mob", _cmi_is_mob = true, health = opts.health or 100,
		_grug_faction = opts.faction, temp = opts.evading and {grug_evading = true} or {}}
	local mob = {ent = ent, pos = opts.pos or {x = 0, y = 0, z = 3}}
	function mob:is_player() return false end
	function mob:get_luaentity() return self.ent end
	function mob:get_pos() return self.pos end
	ent.object = mob
	return mob
end

-- Recorders.
local log = {}
local function reset_log()
	log = {damage = {}, fx = {}, sounds = {}, spawns = {}, status = {}, absorb = {},
		move = {}, root = {}, mob_slow = {}, mob_root = {}, flash = {}, delayed = {},
		query = {}, cone = {}, anchor = {}}
end
reset_log()

local scene = {} -- the objects the area fakes see
local function filtered(opts)
	local out = {}
	for _, obj in ipairs(scene) do
		if not opts.filter or opts.filter(obj) then out[#out + 1] = obj end
	end
	return out
end
local fake_area = {
	H = 3, NO_GROUND = "No ground found.",
	anchor = function(p, range, opts)
		log.anchor[#log.anchor + 1] = {range = range, opts = opts}
		if p.ground then return p.ground, nil end
		return nil, "No ground found."
	end,
	query = function(at, opts)
		log.query[#log.query + 1] = {at = at, opts = opts}
		return filtered(opts)
	end,
	cone = function(caster, opts)
		log.cone[#log.cone + 1] = {caster = caster, opts = opts}
		return filtered(opts)
	end,
	delayed = function(caster, spec)
		log.delayed[#log.delayed + 1] = {caster = caster, spec = spec}
		return true
	end,
}

local projectiles = {}
local tools, input_api = {}, nil
local registered_classes = {warrior = {name = "Warrior", resource = "rage"},
	mage = {name = "Mage", resource = "mana"}, priest = {name = "Priest", resource = "mana"},
	scout = {name = "Scout"}}
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
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
	get_equipped_weapon = function() return nil end,
	is_stunned = function() return false end,
	refuse_mounted_attack = function() return false end,
	-- The tooltip number: the raw value floored (the level scalar is
	-- combat.lua's and not under test here).
	scale_player_damage = function(_, _, amount) return math.floor(amount) end,
	base_pool = base_pool,
	armor_k = armor_k,
	get_player_level = function(p) return p.level end,
	spell_base = function(level) return own_spell_base(level) end,
	area = fake_area,
	particles = {
		play = function(id, frame) log.fx[#log.fx + 1] = {id = id, frame = frame} end,
		facing = function() return {x = 0, y = 0, z = 1} end,
	},
	combat_eye_pos = function(p) return {x = p.pos.x, y = p.pos.y + 1.47, z = p.pos.z} end,
	deal_ability_damage = function(attacker, target, amount, opts)
		log.damage[#log.damage + 1] = {attacker = attacker, target = target, amount = amount,
			opts = opts}
		if target.dodges then return 0 end
		if opts and opts.on_accepted then opts.on_accepted(amount, false, opts.action_id) end
		return amount
	end,
	set_status = function(p, id, def)
		log.status[#log.status + 1] = {player = p, id = id, def = def}
		return def
	end,
	clear_status = function() return true end,
	add_absorb = function(p, id, amount, duration, source)
		log.absorb[#log.absorb + 1] = {player = p, id = id, amount = amount,
			duration = duration, source = source}
		return amount
	end,
	set_move_modifier = function(p, name, effect, duration)
		log.move[#log.move + 1] = {player = p, name = name, speed = effect.speed,
			duration = duration}
	end,
	set_root = function(p, duration)
		log.root[#log.root + 1] = {player = p, duration = duration}
		return true
	end,
	mark_nova_root = function() end,
	proc_flash = function(p, proc) log.flash[#log.flash + 1] = proc end,
	invalidate_combat_identity = function() end,
	register_native_melee_handler = function() end,
})
local fake_classes = with_any({
	registered_classes = registered_classes,
	-- kits_priest.lua reads the old registry at load until PRIEST rebuilds it.
	registered_talents = {mend = {name = "Mend"}},
	get_class = function(p) return p.class end,
	get_class_def = function(p) return registered_classes[p.class] end,
	talent_rank = function(p, id) return p.ranks[id] or 0 end,
	get_talent_bonus = function(p, key)
		local total = sums_of(p.ranks)[key] or 0
		if total ~= 0 and graph.LEVEL_SCALED_KEYS[key] then
			return graph.level_amount(key, total, p.level)
		end
		return total
	end,
	get_spell_power_bonus = function(p) return int_of(p.level) / 10 end,
	get_spell_damage_percent = function() return 0 end,
	get_melee_bonus = function() return 0 end,
	get_race_perk = function() return nil end,
	get_max_mana = function() return 100000 end,
	talent_window_active = function() return false end,
	register_on_class_chosen = capture("class_chosen"),
})
-- The real readiness windows (talent_windows.lua) on the fake classes.
do
	local wenv = setmetatable({grug_classes = fake_classes, grug_core = fake_grug_core,
		core = fake_core}, {__index = _G})
	setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_classes/talent_windows.lua")), wenv)()
end
local fake_inventory = with_any({
	HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
	content_list = function(i) return "grug_bag" .. i end,
	get_cosmetic_hand = function() return nil end,
	hand_list = function() return "grug_weapon" end,
	melee_list = function() return "grug_weapon" end,
	equipment_changed = function() end,
})
local spawn_ok = true
local fake_projectiles = {
	register = function(id, def) projectiles[id] = def end,
	spawn = function(id, params)
		log.spawns[#log.spawns + 1] = {id = id, params = params}
		return spawn_ok
	end,
}
local fake_mobs = with_any({
	is_noncombatant = function() return false end,
	slow = function(ent, duration, factor)
		log.mob_slow[#log.mob_slow + 1] = {ent = ent, duration = duration, factor = factor}
	end,
	root = function(ent, duration)
		log.mob_root[#log.mob_root + 1] = {ent = ent, duration = duration}
	end,
})
-- Factions and the PvP flag: an enemy player only while both are flagged.
local fake_factions = with_any({
	get_faction = function(p) return p.faction end,
	hostile = function(a, b) return a.faction ~= b.faction end,
	same_faction = function(a, b) return a.faction == b.faction end,
})
local fake_pvp = with_any({
	can_harm = function(a, b) return a.flagged == true and b.flagged == true end,
	can_support = function() return true end,
})
local fake_sounds = with_any({
	play = function(event, target) log.sounds[#log.sounds + 1] = {event = event, target = target} end,
	item_sound = function() return nil end,
})
local env = setmetatable({
	core = fake_core, ItemStack = ItemStack,
	grug_core = fake_grug_core, grug_classes = fake_classes,
	grug_inventory = fake_inventory, grug_projectiles = fake_projectiles,
	grug_mobs = fake_mobs, grug_factions = fake_factions, grug_pvp = fake_pvp,
	grug_sounds = fake_sounds,
	vector = with_any({
		offset = function(v, x, y, z) return {x = v.x + x, y = v.y + y, z = v.z + z} end,
		direction = function() return {x = 0, y = 0, z = 1} end,
	}),
}, {__index = function(_, k)
	local g = rawget(_G, k)
	if g ~= nil and k ~= "core" and k ~= "minetest" and k ~= "grug_core" and
			k ~= "vector" and k ~= "ItemStack" then return g end
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
setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_abilities/init.lua")), env)()
local G = env.grug_abilities
check(G and G.registered.strike and input_api, "K the real init.lua loads with its kits and input")
local R = G.registered

-- A cast through the real dispatcher; returns ok and the refusal shown.
local function cast(p, id)
	local shown
	local ok = G.try_cast(p, R[id], nil, function(message) shown = message end)
	return ok, shown
end
local function fill_mana(p) G.restore_mana(p, 100000) end
local function fresh_clock() wait(100) end
local function last(list) return list[#list] end

------------------------------------------------------------------------------
-- R: registration.
------------------------------------------------------------------------------
local ORDER = {"fiery_spark", "ice_wave", "fireball", "flame_lance", "meteor", "fire_rain",
	"cold_spark", "blink", "rime_mantle", "ice_nova", "winter_field"}
do
	local ids = {}
	for _, def in ipairs(G.by_class.mage or {}) do ids[#ids + 1] = def.id end
	eq(table.concat(ids, ","), table.concat(ORDER, ","),
		"R the Mage's skills in file order: the starters, then the gated ones")
	check(R.cinderfall == nil and R.glacial_ward == nil, "R Cinderfall and Glacial Ward are retired")
	-- Every granting node names an ability whose talent is that node.
	local granted = {}
	for _, tree in ipairs({"ember", "rime"}) do
		for _, node in ipairs(graph.trees[tree].nodes) do
			if node.ability then
				local def = R[node.ability]
				granted[node.ability] = true
				check(def and def.class == "mage" and def.talent_gated and def.talent == node.id,
					"R " .. node.id .. " grants " .. node.ability .. " (talent_gated, talent = the node)")
			end
		end
	end
	for _, id in ipairs({"fiery_spark", "ice_wave"}) do
		check(not R[id].talent_gated and R[id].talent == nil and not granted[id],
			"R " .. id .. " is an ungated starter")
	end
	eq(R.fiery_spark.transforms, "strike", "R Fiery Spark replaces Strike")
	eq(R.cold_spark.transforms, "fiery_spark", "R Cold Spark replaces Fiery Spark")
	eq(R.ice_nova.transforms, "ice_wave", "R Ice Nova replaces Ice Wave")
	eq(R.fiery_spark.cooldown_key .. "," .. R.cold_spark.cooldown_key, "strike,strike",
		"R the sparks share Strike's key (the cast interval)")
	eq(R.ice_nova.cooldown_key, "ice_wave", "R Nova shares Wave's cooldown")
	check(not R.fiery_spark.basic_attack, "R the basic attack is a Strike transform, not a mark")
	local FIRE = {fiery_spark = true, fireball = true, flame_lance = true, meteor = true,
		fire_rain = true}
	for _, id in ipairs(ORDER) do
		local def = R[id]
		eq(def.tags and def.tags[1], FIRE[id] and "fire" or "frost", "R " .. id .. "'s tag")
		eq(G.WEAPON_FX[id], FIRE[id] and "ember" or "rime", "R " .. id .. "'s overlay family")
		check(G.CAST_SOUNDS[id] ~= nil, "R " .. id .. " has a cue")
	end
	-- Offensive self casts fire at terrain and around the caster.
	for _, id in ipairs({"ice_wave", "ice_nova", "meteor", "fire_rain", "winter_field"}) do
		check(R[id].target_kind == "self" and R[id].offensive, "R " .. id .. " is an offensive self cast")
	end
	for _, id in ipairs({"fiery_spark", "cold_spark", "fireball", "flame_lance"}) do
		eq(R[id].target_kind, "hostile", "R " .. id .. " needs a hostile")
		eq(G.CAST_SOUNDS[id], "projectile", "R " .. id .. " sounds through its projectile")
	end
	-- The projectiles and their cues (K6: the fireball pair unless picked).
	local WANT = {fiery_spark = {"fireball_launch", 20}, cold_spark = {"cold_spark_launch", 20},
		fireball = {"fireball_launch", 20}, flame_lance = {"flame_lance_launch", 35}}
	for id, want in pairs(WANT) do
		local def = projectiles[id]
		check(def and def.sound_launch == want[1] and def.sound_hit == "fireball_hit",
			"R projectile " .. id .. ": " .. want[1] .. " / fireball_hit")
		eq(def and def.speed, want[2], "R projectile " .. id .. "'s speed")
	end
	near(projectiles.fiery_spark.properties.visual_size.x, 0.45, "R Fiery Spark's sprite (the card)")
	near(projectiles.flame_lance.properties.visual_size.x, 0.6, "R Flame Lance's sprite (the card)")
end

------------------------------------------------------------------------------
-- N: numbers against the calculator. Raw D before the level scalar.
------------------------------------------------------------------------------
-- Untalented: {coef in D, cost % P, cooldown, occupied, cast interval}.
local BASE = {
	fiery_spark = {1.0, 0, 0, 1, 1},
	ice_wave = {0.25, 8, 12, 1},
	fireball = {1.60, 6, 5, 1},
	flame_lance = {2.20, 10, 8, 1.5},
	meteor = {1.40, 14, 18, 1},
	fire_rain = {2.50, 22, 60, 1.5},
	cold_spark = {1.0, 0, 0, 1, 1},
	blink = {nil, 8, 20, 0},
	rime_mantle = {nil, 10, 24, 0.3},
	ice_nova = {0.65, 10, 18, 1},
	winter_field = {1.0, 18, 60, 1.5},
}
for _, level in ipairs({10, 30, 60}) do
	local p = new_player("n_" .. level, {level = level})
	for _, id in ipairs(ORDER) do
		local def, want = R[id], BASE[id]
		if want[1] then
			near(def.values(p, def).damage, want[1] * D(level),
				("N L%d %s: %.2fD"):format(level, id, want[1]), 1e-9)
		end
		local cost = G.effective_cost(p, def)
		eq(cost.mana, want[2] > 0 and mana_cost(level, want[2]) or nil,
			("N L%d %s: %g %% P"):format(level, id, want[2]))
		eq(G.effective_cooldown(p, def), want[3], ("N L%d %s: cooldown"):format(level, id))
		eq(G.clock_seconds(def.occupied_cast, p, def), want[4], ("N L%d %s: occupied"):format(level, id))
		eq(def.cast_interval, want[5], ("N L%d %s: cast interval"):format(level, id))
	end
	near(R.fireball.values(p, R.fireball).splash, 0.15 * D(level), "N L" .. level .. " Fireball splash 0.15D")
	local mantle = R.rime_mantle.values(p, R.rime_mantle)
	near(mantle.armor, 0.20 * armor_k(level), "N L" .. level .. " Rime Mantle armor 0.20K")
	near(mantle.absorb, 0.12 * base_pool(level), "N L" .. level .. " Rime Mantle shield 12 % P")
	eq(mantle.duration, 6, "N L" .. level .. " Rime Mantle 6 s")
end
do
	local p = new_player("n_range")
	eq(G.get_range(p, R.fiery_spark), 20, "N Fiery Spark 20 m")
	eq(G.get_range(p, R.winter_field), 15, "N Winter Field 15 m")
	eq(G.get_range(p, R.meteor), 20, "N Meteor 20 m")
end

-- The full builds at level 60 (the trees' example orders, the calculator's
-- builds mage_ember and mage_rime).
local function build(name, tree)
	local ranks = graph.apply_order("mage", graph.trees[tree].example, 30)
	return new_player(name, {ranks = ranks})
end
do
	local L = 60
	local ember = build("n_ember", "ember")
	local spent = 0
	for _, r in pairs(ember.ranks) do spent = spent + r end
	eq(spent, 30, "N the Ember build spends 30")
	-- {damage D, cost % P, cooldown, occupied}
	local FULL = {
		fiery_spark = {1.2, nil, 0, 1},
		fireball = {2.10, 5.28, 5, 1},
		flame_lance = {2.97, 8.8, 8, 1.5},
		meteor = {1.68, 10.22, 18, 1},
		fire_rain = {3.0, 16.06, 60, 1.5},
		ice_wave = {0.25, 8, 12, 1},
	}
	for id, want in pairs(FULL) do
		local def = R[id]
		near(def.values(ember, def).damage, want[1] * D(L), ("N Ember %s %.2fD"):format(id, want[1]), 1e-9)
		eq(G.effective_cost(ember, def).mana, want[2] and mana_cost(L, want[2]) or nil,
			("N Ember %s %s %% P"):format(id, tostring(want[2])))
		eq(G.effective_cooldown(ember, def), want[3], "N Ember " .. id .. " cooldown")
		eq(G.clock_seconds(def.occupied_cast, ember, def), want[4], "N Ember " .. id .. " occupied")
	end
	near(R.fireball.values(ember, R.fireball).splash, 0.36 * D(L), "N Ember Fireball splash 0.36D", 1e-9)
	eq(G.get_range(ember, R.fiery_spark), 22, "N Ember Fiery Spark 22 m (Far Cast 2/3)")
	eq(G.get_range(ember, R.cold_spark), 22, "N ...Cold Spark too")

	local rime = build("n_rime", "rime")
	local FULL_RIME = {
		cold_spark = {1.09, nil, 0, 1},
		ice_nova = {0.65, 8.8, 15, 1},
		winter_field = {1.0, 15.84, 60, 1.5},
		blink = {nil, 7.04, 17, 0},
		rime_mantle = {nil, 8.8, 24, 0.3},
	}
	for id, want in pairs(FULL_RIME) do
		local def = R[id]
		if want[1] then
			near(def.values(rime, def).damage, want[1] * D(L), ("N Rime %s %.2fD"):format(id, want[1]), 1e-9)
		end
		eq(G.effective_cost(rime, def).mana, want[2] and mana_cost(L, want[2]) or nil,
			("N Rime %s %s %% P"):format(id, tostring(want[2])))
		eq(G.effective_cooldown(rime, def), want[3], "N Rime " .. id .. " cooldown")
		eq(G.clock_seconds(def.occupied_cast, rime, def), want[4], "N Rime " .. id .. " occupied")
	end
	local mantle = R.rime_mantle.values(rime, R.rime_mantle)
	near(mantle.armor, 0.32 * armor_k(L), "N Rime Mantle full: 0.32K")
	eq(mantle.duration, 7.5, "N Rime Mantle full: 7.5 s")
	eq(G.effective_cooldown(rime, R.ice_wave), 9, "N Returning Cold on Ice Wave too (12 - 3)")
	near(fake_classes.get_talent_bonus(rime, "cold_shock_unit_add"), 0.75, "N Cold Shock full: +0.75D")
	eq(fake_classes.get_talent_bonus(rime, "max_mana_percent_add"), 20, "N Mana Reserve full: +20 %")
end

------------------------------------------------------------------------------
-- T: every talent at rank 1 and at full rank (ranks set directly).
------------------------------------------------------------------------------
do
	local L = 60
	local d = D(L)
	-- node id -> function(player) returning the measured value, and the
	-- values at rank 1 and at full rank.
	local CASES = {
		ember_fire_mastery = {function(p) return R.fireball.values(p, R.fireball).damage / d end,
			1.60 * 1.05, 1.60 * 1.20},
		ember_measured_fuel = {function(p) return G.effective_cost(p, R.fireball).mana end,
			mana_cost(L, 6 * 0.96), mana_cost(L, 6 * 0.88)},
		ember_far_cast = {function(p) return G.get_range(p, R.fiery_spark) end, 21, 23},
		ember_heat_focus = {function(p) return R.flame_lance.values(p, R.flame_lance).damage / d end,
			2.20 * 1.05, 2.20 * 1.15},
		ember_afterglow = {function(p) return R.fireball.values(p, R.fireball).damage / d end,
			1.65, 1.75},
		ember_wide_ember = {function(p) return R.fireball.values(p, R.fireball).splash / d end,
			0.20, 0.30},
		ember_broad_impact = {function(p)
			return G.family_bonus(p, R.meteor, "radius_add") + 3 end, 3.25, 3.75},
		ember_controlled_burn = {function(p) return G.effective_cost(p, R.fire_rain).mana end,
			mana_cost(L, 22 * 0.95), mana_cost(L, 22 * 0.85)},
		ember_spreading_rain = {function(p)
			return G.family_bonus(p, R.fire_rain, "radius_add") + 5 end, 5.25, 5.75},
		rime_mana_reserve = {function(p)
			return fake_classes.get_talent_bonus(p, "max_mana_percent_add") end, 5, 20},
		rime_keen_cold = {function(p) return R.cold_spark.values(p, R.cold_spark).damage / d end,
			1.03, 1.09},
		rime_clear_thought = {function(p) return G.effective_cost(p, R.winter_field).mana end,
			mana_cost(L, 18 * 0.96), mana_cost(L, 18 * 0.88)},
		rime_quick_step = {function(p) return G.effective_cooldown(p, R.blink) end, 19, 17},
		rime_thick_ice = {function(p)
			return R.rime_mantle.values(p, R.rime_mantle).armor / armor_k(L) end, 0.24, 0.32},
		rime_cold_shock = {function(p)
			return fake_classes.get_talent_bonus(p, "cold_shock_unit_add") end, 0.25, 0.75},
		rime_returning_cold = {function(p) return G.effective_cooldown(p, R.ice_nova) end, 17, 15},
		rime_far_frost = {function(p)
			return G.family_bonus(p, R.ice_nova, "radius_add") + 5 end, 5.25, 5.75},
		rime_lasting_armor = {function(p)
			return R.rime_mantle.values(p, R.rime_mantle).duration end, 6.5, 7.5},
	}
	local seen = 0
	for _, tree in ipairs({"ember", "rime"}) do
		for _, node in ipairs(graph.trees[tree].nodes) do
			if not node.ability then
				local case = CASES[node.id]
				if check(case ~= nil, "T " .. node.id .. " has a case") then
					seen = seen + 1
					local one = new_player("t1_" .. node.id, {ranks = {[node.id] = 1}})
					local full = new_player("tf_" .. node.id, {ranks = {[node.id] = node.ranks}})
					near(case[1](one), case[2], "T " .. node.id .. " at rank 1", 1e-9)
					near(case[1](full), case[3], "T " .. node.id .. " at rank " .. node.ranks, 1e-9)
				end
			end
		end
	end
	eq(seen, 18, "T the 18 modifier and window nodes")
	-- Fire Mastery is fire only: Ice Wave and Cold Spark keep their damage.
	local fm = new_player("t_fm", {ranks = {ember_fire_mastery = 4}})
	near(R.ice_wave.values(fm, R.ice_wave).damage, 0.25 * d, "T Fire Mastery leaves Ice Wave", 1e-9)
	near(R.cold_spark.values(fm, R.cold_spark).damage, 1.0 * d, "T ...and Cold Spark", 1e-9)
	near(R.meteor.values(fm, R.meteor).damage, 1.68 * d, "T ...but raises Meteor", 1e-9)
	near(R.fiery_spark.values(fm, R.fiery_spark).damage, 1.2 * d, "T ...and Fiery Spark", 1e-9)
end

------------------------------------------------------------------------------
-- C: casts through try_cast.
------------------------------------------------------------------------------
local mob = new_mob()
do
	reset_log()
	local p = new_player("c_mage", {ranks = {ember_fire_mastery = 1, ember_fireball = 1,
		ember_flame_lance = 1, rime_cold_spark = 1}})
	fill_mana(p)
	local before = G.get_mana(p)
	-- Fiery Spark is replaced by Cold Spark for this player: the base is locked.
	local ok, shown = cast(p, "fiery_spark")
	check(not ok and shown == "This skill is not unlocked.", "C a replaced base does not cast")
	ok = cast(p, "cold_spark")
	check(ok, "C Cold Spark casts")
	local spawn = last(log.spawns)
	eq(spawn and spawn.id, "cold_spark", "C ...its projectile")
	near(spawn.params.data.damage, 1.0 * D(60), "C ...the damage snapshotted at launch", 1e-9)
	eq(spawn.params.max_distance, 20, "C ...its range")
	eq(G.get_mana(p), before, "C a free basic attack costs nothing")
	-- The shared interval and the action clock.
	eq(select(2, input_api.cast_refusal(p, R.cold_spark)), "interval", "C the interval holds the spark")
	eq(select(2, input_api.cast_refusal(p, R.fireball)), "busy", "C the 1 s occupied holds other casts")
	wait(1.01)
	eq(input_api.cast_refusal(p, R.fireball), nil, "C ...for one second")
	ok = cast(p, "fireball")
	check(ok, "C Fireball casts")
	spawn = last(log.spawns)
	eq(spawn.id, "fireball", "C ...its projectile")
	near(spawn.params.data.damage, 1.60 * 1.05 * D(60), "C ...1.60D with Fire Mastery 1/4", 1e-9)
	near(spawn.params.data.splash_damage, 0.15 * 1.05 * D(60), "C ...its splash", 1e-9)
	eq(G.get_mana(p), before - mana_cost(60, 6), "C ...costs 6 % P")
	check(not G.ready(p, "fireball"), "C ...arms its cooldown")
	wait(1.01)
	ok = cast(p, "flame_lance")
	check(ok, "C Flame Lance casts")
	spawn = last(log.spawns)
	eq(spawn.id .. "|" .. tostring(spawn.params.trail and spawn.params.trail.effect),
		"flame_lance|flame_lance_trail", "C ...with its trail card")
	eq(select(2, input_api.cast_refusal(p, R.cold_spark)), "busy", "C ...1.5 s occupied")
	wait(1.49)
	eq(select(2, input_api.cast_refusal(p, R.cold_spark)), "busy", "C ...not before")
	wait(0.02)
	eq(input_api.cast_refusal(p, R.cold_spark), nil, "C ...then free")
	-- No target: nothing launches, nothing is paid, no cooldown.
	fresh_clock()
	spawn_ok = false
	local mana_before = G.get_mana(p)
	ok, shown = cast(p, "fireball")
	check(not ok and shown == "No hostile target in your crosshair.", "C no target: refused")
	eq(G.get_mana(p), mana_before, "C ...nothing paid")
	check(G.ready(p, "fireball"), "C ...no cooldown")
	eq(select(2, input_api.cast_refusal(p, R.flame_lance)), nil, "C ...and no occupied time")
	spawn_ok = true
	-- A Mage without the talents: the gated skills are locked.
	local plain = new_player("c_plain")
	fill_mana(plain)
	for _, id in ipairs({"fireball", "flame_lance", "meteor", "fire_rain", "cold_spark", "blink",
			"rime_mantle", "ice_nova", "winter_field"}) do
		eq(select(2, input_api.cast_refusal(plain, R[id])), "locked", "C untalented: " .. id .. " is locked")
	end
	eq(input_api.cast_refusal(plain, R.fiery_spark), nil, "C untalented: Fiery Spark is ready")
	eq(input_api.cast_refusal(plain, R.ice_wave), nil, "C untalented: Ice Wave is ready")
	eq(select(2, input_api.cast_refusal(new_player("c_war", {class = "warrior"}), R.fiery_spark)),
		"class", "C another class")
end

------------------------------------------------------------------------------
-- P: the projectiles' hits.
------------------------------------------------------------------------------
do
	reset_log()
	local p = new_player("p_mage", {flagged = true})
	local other = new_mob({pos = {x = 1, y = 0, z = 3}})
	local evading = new_mob({evading = true})
	local friend = new_player("p_friend", {faction = "accord", flagged = true})
	scene = {mob, other, evading, friend, p}
	projectiles.fireball.on_hit(p, mob, {damage = 50, splash_damage = 7, action_id = "a"},
		{x = 0, y = 1, z = 3}, 60)
	eq(#log.damage, 2, "P Fireball: the hit and one splash")
	check(log.damage[1].target == mob and log.damage[1].amount == 50, "P ...the primary hit")
	check(log.damage[2].target == other and log.damage[2].amount == 7,
		"P ...the splash on the other enemy only (never the primary, an evading mob, a friend or the caster)")
	eq(log.query[1].opts.radius, 2, "P ...within 2 m of the impact")
	eq(log.fx[1].id, "fireball", "P ...the impact card")
	-- No splash talent needed: 0.15D always splashes; none when 0.
	reset_log()
	projectiles.fireball.on_hit(p, mob, {damage = 50, splash_damage = 0, action_id = "a"},
		{x = 0, y = 1, z = 3}, 60)
	eq(#log.damage, 1, "P no splash without splash damage")
	-- Cold Spark: the slow on an accepted hit, mob and player.
	reset_log()
	projectiles.cold_spark.on_hit(p, mob, {damage = 40, action_id = "b"}, {x = 0, y = 1, z = 3}, 60)
	local s = last(log.mob_slow)
	check(s and s.ent == mob.ent and math.abs(s.factor - 0.88) < 1e-9 and s.duration == 1.5,
		"P Cold Spark slows a mob by 12 % for 1.5 s")
	eq(log.fx[1].id, "cold_spark_hit", "P ...its impact card")
	local enemy = new_player("p_enemy", {faction = "throng", flagged = true})
	projectiles.cold_spark.on_hit(p, enemy, {damage = 40, action_id = "c"}, {x = 0, y = 1, z = 3}, 60)
	local m = last(log.move)
	check(m and m.player == enemy and m.name == "cold_spark_slow" and math.abs(m.speed + 0.12) < 1e-9
		and m.duration == 1.5, "P ...a player by a named modifier (refreshed, not stacked)")
	enemy.dodges = true
	local moves = #log.move
	projectiles.cold_spark.on_hit(p, enemy, {damage = 40, action_id = "d"}, {x = 0, y = 1, z = 3}, 60)
	eq(#log.move, moves, "P ...no slow on a dodged hit")
	reset_log()
	projectiles.fiery_spark.on_hit(p, mob, {damage = 30, action_id = "e"}, {x = 0, y = 1, z = 3}, 60)
	check(log.fx[1].id == "spark_hit" and log.damage[1].amount == 30, "P Fiery Spark: its card and hit")
	projectiles.flame_lance.on_hit(p, mob, {damage = 90, action_id = "f"}, {x = 0, y = 1, z = 3}, 60)
	check(log.fx[2].id == "flame_lance_hit" and log.damage[2].amount == 90, "P Flame Lance: its card and hit")
end

------------------------------------------------------------------------------
-- A: the areas.
------------------------------------------------------------------------------
-- The scene for areas: a hostile mob, an evading mob, an unflagged enemy, a
-- flagged enemy (the caster flagged too), a same-faction player, the caster.
local function area_scene(caster)
	local hostile = new_mob({pos = {x = 0, y = 0, z = 2}})
	local evading = new_mob({evading = true})
	local unflagged = new_player("a_unflagged_" .. caster.name, {faction = "throng"})
	local flagged = new_player("a_flagged_" .. caster.name, {faction = "throng", flagged = true})
	local ally = new_player("a_ally_" .. caster.name, {faction = "accord", flagged = true})
	scene = {hostile, evading, unflagged, flagged, ally, caster}
	return hostile, flagged
end
local function targets()
	local out = {}
	for _, hit in ipairs(log.damage) do
		local t = hit.target
		out[#out + 1] = t:is_player() and t:get_player_name() or "mob"
	end
	return table.concat(out, ",")
end
do
	local ranks = {ember_fireball = 1, ember_meteor = 1, ember_fire_rain = 1,
		ember_fire_mastery = 4, ember_broad_impact = 3, ember_spreading_rain = 3,
		rime_ice_nova = 1, rime_winter_field = 1}
	local p = new_player("a_mage", {ranks = ranks, flagged = true})
	fill_mana(p)
	local ground = {x = 5, y = 1, z = 9}
	for _, case in ipairs({
		{"meteor", 1.5, 3.75, nil, "meteor_fall", "meteor_impact", "meteor_impact", 1.68, 14 * 1},
		{"fire_rain", 1.5, 5.75, nil, "fire_rain_fall", "fire_rain_impact", "fire_rain_impact", 3.0, 22},
		{"winter_field", 1, 4, "winter_field_warning", "winter_field_fall", "winter_field_impact",
			"winter_field_impact", 1.0, 18},
	}) do
		local id = case[1]
		fresh_clock()
		reset_log()
		p.ground = nil
		local mana = G.get_mana(p)
		local ok, shown = cast(p, id)
		check(not ok and shown == "No ground found.", "A " .. id .. ": no ground, refused")
		eq(G.get_mana(p), mana, "A " .. id .. ": ...before the cost")
		check(G.ready(p, id), "A " .. id .. ": ...and the cooldown")
		eq(input_api.cast_refusal(p, R.ice_nova), nil, "A " .. id .. ": ...and the occupied time")
		eq(log.anchor[1].range, G.get_range(p, R[id]), "A " .. id .. ": the anchor searches the skill's range")
		local hostile = area_scene(p)
		check(log.anchor[1].opts.is_enemy(hostile) and not log.anchor[1].opts.is_enemy(scene[3]),
			"A " .. id .. ": the anchor's enemy is a valid hostile (an unflagged player is none)")
		p.ground = ground
		ok = cast(p, id)
		check(ok, "A " .. id .. ": with ground it casts")
		eq(G.get_mana(p), mana - mana_cost(60, case[9]), "A " .. id .. ": ...and pays")
		local d = last(log.delayed)
		local spec = d and d.spec
		if check(spec ~= nil, "A " .. id .. ": one delayed impact") then
			eq(spec.anchor, ground, "A " .. id .. ": at the anchor")
			eq(spec.delay, case[2], "A " .. id .. ": delay")
			eq(spec.radius, case[3], "A " .. id .. ": radius with its talent")
			eq(spec.warning, case[4], "A " .. id .. ": the warning card")
			eq(spec.fall, case[5], "A " .. id .. ": the fall card")
			eq(spec.burst, case[6], "A " .. id .. ": the impact card")
			eq(#log.damage, 0, "A " .. id .. ": nothing lands at the cast")
			spec.impact(p, ground)
			eq(#log.sounds >= 1 and log.sounds[#log.sounds].event, case[7], "A " .. id .. ": the impact cue")
			eq(log.sounds[#log.sounds].target, ground, "A " .. id .. ": ...once, at the anchor")
			eq(log.query[1].at, ground, "A " .. id .. ": the query at the anchor")
			eq(log.query[1].opts.radius, case[3], "A " .. id .. ": ...with the radius")
			eq(targets(), "mob,a_flagged_a_mage", "A " .. id ..
				": hits the mob and the flagged enemy only")
			near(log.damage[1].amount, case[8] * D(60), "A " .. id .. ": the damage", 1e-9)
		end
	end
	-- Winter Field's slow on each hit.
	local m = last(log.move)
	check(m and m.name == "winter_field_slow" and math.abs(m.speed + 0.4) < 1e-9 and m.duration == 5,
		"A Winter Field slows a player by 40 % for 5 s")
	local s = last(log.mob_slow)
	check(s and math.abs(s.factor - 0.6) < 1e-9 and s.duration == 5, "A ...and a mob")
	-- The caster unflagged: no player is a target at all.
	p.flagged = false
	reset_log()
	fresh_clock()
	check(cast(p, "meteor"), "A an unflagged caster casts")
	last(log.delayed).spec.impact(p, ground)
	eq(targets(), "mob", "A ...and hits no player")
	p.flagged = true

	-- Ice Wave (no Nova yet): the cone in front, the slow.
	p = new_player("a_wave", {flagged = true})
	fill_mana(p)
	reset_log()
	area_scene(p)
	check(cast(p, "ice_wave"), "A Ice Wave casts")
	local cone = log.cone[1]
	check(cone and cone.caster == p and cone.opts.radius == 5 and cone.opts.angle == 70,
		"A Ice Wave: a 70 degree cone of 5 m")
	eq(targets(), "mob,a_flagged_a_wave", "A ...the valid hostiles only")
	near(log.damage[1].amount, 0.25 * D(60), "A ...0.25D", 1e-9)
	s = last(log.mob_slow)
	check(s and math.abs(s.factor - 0.5) < 1e-9 and s.duration == 3, "A ...a 50 % slow for 3 s (mob)")
	m = last(log.move)
	check(m and m.name == "ice_wave_slow" and math.abs(m.speed + 0.5) < 1e-9 and m.duration == 3,
		"A ...and player")
	eq(last(log.fx).id, "ice_wave", "A ...its card")
	check(not G.ready(p, "ice_wave"), "A ...its cooldown runs")
	-- Ice Nova bought now: it replaces Wave and shares its cooldown.
	p.ranks.rime_ice_nova = 1
	eq(select(2, input_api.cast_refusal(p, R.ice_nova)), "cooldown", "A Wave's cooldown holds Nova")
	wait(12)
	eq(input_api.cast_refusal(p, R.ice_nova), nil, "A ...for Wave's 12 s")
end

------------------------------------------------------------------------------
-- W: Ice Nova's root and Cold Shock.
------------------------------------------------------------------------------
do
	local p = new_player("w_mage", {ranks = {rime_cold_spark = 1, rime_ice_nova = 1,
		rime_cold_shock = 2, rime_far_frost = 3}, flagged = true})
	fill_mana(p)
	reset_log()
	local hostile = area_scene(p)
	check(cast(p, "ice_nova"), "W Ice Nova casts")
	local q = log.query[1]
	check(q and q.at == p.pos and q.opts.radius == 5.75, "W a circle around the caster (Far Frost 3/3)")
	eq(targets(), "mob,a_flagged_w_mage", "W ...the valid hostiles only")
	near(log.damage[1].amount, 0.65 * D(60), "W ...0.65D", 1e-9)
	local r = last(log.mob_root)
	check(r and r.ent == hostile.ent and r.duration == 2.5, "W ...a 2.5 s root on the mob")
	check(last(log.root) and last(log.root).duration == 2.5, "W ...and on the player")
	eq(#log.mob_slow, 0, "W ...and no slow after it")
	eq(table.concat(log.flash, ","), "cold_shock", "W Cold Shock opens once (one flash for two hits)")
	local window = env.grug_classes.get_window(p, "cold_shock")
	check(window and window.value == 0.5, "W ...with its rank's value (+0.50D)")
	-- The next Cold Spark spends it.
	wait(1.01)
	reset_log()
	check(cast(p, "cold_spark"), "W Cold Spark casts")
	near(last(log.spawns).params.data.damage, 1.5 * D(60), "W ...for 1.0D + 0.50D", 1e-9)
	check(env.grug_classes.get_window(p, "cold_shock") == nil, "W ...and spends the window")
	wait(1.01)
	check(cast(p, "cold_spark"), "W the next Cold Spark")
	near(last(log.spawns).params.data.damage, 1.0 * D(60), "W ...is plain again", 1e-9)
	-- A failed launch keeps the window.
	fresh_clock()
	env.grug_classes.open_window(p, "cold_shock", {duration = 4, value = 0.5})
	spawn_ok = false
	check(not cast(p, "cold_spark"), "W a spark that does not launch")
	check(env.grug_classes.get_window(p, "cold_shock") ~= nil, "W ...keeps the window")
	spawn_ok = true
	-- It runs out after 4 s.
	wait(4.01)
	check(env.grug_classes.get_window(p, "cold_shock") == nil, "W the window lasts 4 s")
	-- A Nova that hits nothing opens nothing; no talent, no window.
	fresh_clock()
	reset_log()
	scene = {p}
	check(cast(p, "ice_nova"), "W a Nova on nothing")
	check(env.grug_classes.get_window(p, "cold_shock") == nil and #log.flash == 0,
		"W ...opens no window")
	local plain = new_player("w_plain", {ranks = {rime_cold_spark = 1, rime_ice_nova = 1}})
	fill_mana(plain)
	reset_log()
	area_scene(plain)
	check(cast(plain, "ice_nova"), "W a Nova without Cold Shock")
	check(env.grug_classes.get_window(plain, "cold_shock") == nil and #log.flash == 0,
		"W ...opens no window")
end

------------------------------------------------------------------------------
-- M: Rime Mantle.
------------------------------------------------------------------------------
do
	local p = new_player("m_mage", {ranks = {rime_rime_mantle = 1, rime_thick_ice = 3,
		rime_lasting_armor = 3}})
	fill_mana(p)
	reset_log()
	check(cast(p, "rime_mantle"), "M Rime Mantle casts")
	local st = last(log.status)
	check(st and st.id == "rime_mantle" and st.def.duration == 7.5 and
		math.abs(st.def.modifiers.armor - 0.32 * armor_k(60)) < 1e-9,
		"M the rime_mantle status: armor 0.32K for 7.5 s")
	local ab = last(log.absorb)
	check(ab and ab.id == "rime_mantle" and math.abs(ab.amount - 0.12 * base_pool(60)) < 1e-9
		and ab.duration == 7.5 and ab.source == p, "M ...and a shield of 12 % P for as long")
	eq(last(log.fx).id, "glacial_ward", "M ...the picked card (Glacial Ward's effect)")
	eq(select(2, input_api.cast_refusal(p, R.rime_mantle)), "cooldown", "M ...24 s cooldown")
	eq(G.CAST_SOUNDS.rime_mantle, "cast_rime_mantle", "M ...its cue")
end

------------------------------------------------------------------------------
-- L: the layouts, the new character, the tooltips.
------------------------------------------------------------------------------
do
	-- A 0.52 Mage's hotbars: Strike and Ice Nova on A and B.
	local p = new_player("l_mage")
	local inv = p.inv
	inv.lists.main[1] = ItemStack("grug_abilities:strike")
	inv.lists.main[2] = ItemStack("grug_abilities:ice_nova")
	inv.lists.main[3] = ItemStack("grug_abilities:fireball")
	inv.lists.grug_hotbar_store[4] = ItemStack("grug_abilities:strike")
	inv.lists.grug_hotbar_store[5] = ItemStack("grug_abilities:ice_nova")
	G.normalize_kit(p)
	eq(row(inv, "main", 3), "fiery_spark,ice_wave,", "L A: Strike -> Fiery Spark, Ice Nova -> Ice Wave, locked Fireball gone")
	eq(row(inv, "grug_hotbar_store", 5), ",,,fiery_spark,ice_wave", "L B: the same, in place")
	p.ranks = {rime_cold_spark = 1, rime_ice_nova = 1}
	G.normalize_kit(p)
	eq(row(inv, "main", 2), "cold_spark,ice_nova", "L the transforms in place on A")
	eq(row(inv, "grug_hotbar_store", 5), ",,,cold_spark,ice_nova", "L ...and on B")
	p.ranks = {}
	G.normalize_kit(p)
	eq(row(inv, "main", 2), "fiery_spark,ice_wave", "L a respec swaps them back")
	-- K7: a new Mage gets the basic attack in slot 1, then Ice Wave.
	local new = new_player("l_new")
	fire("class_chosen", new, "mage")
	eq(row(new.inv, "main", 3), "fiery_spark,ice_wave,", "L the new Mage's hotbar: Fiery Spark, Ice Wave")
	check(G.current_form(new, R.strike) == R.fiery_spark, "L the Mage's basic attack (K8's fallback)")
	-- Tooltips: the current numbers.
	local t = new_player("l_tip", {ranks = {ember_fireball = 1, ember_fire_mastery = 4,
		ember_far_cast = 3, ember_meteor = 1, ember_broad_impact = 3, rime_rime_mantle = 1}})
	local text = R.fireball.description_for(t, R.fireball)
	check(text:find(tostring(math.floor(1.92 * D(60))), 1, true) and
		text:find(tostring(math.floor(0.18 * D(60))), 1, true),
		"L Fireball's tooltip shows its hit and splash at this level")
	check(R.fiery_spark.description_for(t, R.fiery_spark):find("up to 23 m", 1, true),
		"L Fiery Spark's tooltip shows the range with Far Cast")
	check(R.meteor.description_for(t, R.meteor):find("within 3.75 m", 1, true),
		"L Meteor's tooltip shows the radius with Broad Impact")
	local mantle = R.rime_mantle.description_for(t, R.rime_mantle)
	check(mantle:find("+" .. math.floor(0.2 * armor_k(60) + 0.5) .. " armor", 1, true) and
		mantle:find("shield of " .. math.floor(0.12 * base_pool(60)), 1, true),
		"L Rime Mantle's tooltip shows armor and shield")
	eq(G.description_prefix(t, R.blink), "Blink (Mage)\n8% base mana (" .. mana_cost(60, 8) ..
		" mana), 20 s cooldown\n", "L Blink's head: 8 %, 20 s")
	eq(R.fiery_spark._grug_timing_line, "1 s cast interval", "L Fiery Spark's timing line")
end

if failures > 0 then
	error("R53 MAGE PORTABLE FAIL " .. failures .. " of " .. checks .. " checks")
end
print("R53 MAGE PORTABLE PASS checks=" .. checks)
