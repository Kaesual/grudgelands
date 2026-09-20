-- Known-answer test for the WP11 TALENT MODEL and its numeric consumers
-- (docs/design/skill_trees.md §3.7, lanes X1 + X2, 2026-09-16).
--
-- It loads FIVE REAL SOURCE FILES under a stub engine and drives the shipped
-- functions, rather than re-implementing the rules next to them:
--
--   mods/PLAYER/grug_classes/stats.lua      crit/dodge/HP/mana, the caps
--   mods/PLAYER/grug_classes/talents.lua    the registry, gates, persistence
--   mods/PLAYER/grug_abilities/init.lua     the central per-player seams
--   mods/PLAYER/grug_abilities/kits.lua     the shipped ability catalog
--   mods/PLAYER/grug_inventory/equipment.lua the raw armor-rating fallback
--
-- Groups, each able to go red on its own (§3.7):
--
--   1  SHAPE          48 talents, 6 trees, 8 per tree in two chains of four,
--                     ranks 5/4/3 with a ONE-rank capstone, one keystone per
--                     chain in tier 3, 28 ranks per tree and 56 per class.
--   2  ARITHMETIC     floor(60/2) = 30 points; a tree costs 28; the milestone
--                     table of §1.3 reproduced by REAL spends; a capstone
--                     costs 21 and two cost 42 > 30 (ruling 18 as an
--                     assertion instead of a rule).
--   3  SPEND RULES    the case table of §3.7 group 3, driven through the real
--                     can_spend_talent / spend_talent.
--   4  PERSISTENCE    serialize -> parse -> identical, forged meta strings
--                     that the validating read path must defuse, and ruling
--                     20's free full reset on an admin level drop.
--   5  KEY COVERAGE   every talent effect key is in the closed vocabulary,
--                     every vocabulary key belongs to a talent, and every key
--                     THIS LANE owns is read by a real consumer source file.
--                     Lane X3's keys are counted and named, not required.
--   6  CAP INVARIANTS crit and dodge stay <= 30% and armor <= 60% with every
--                     shipped numeric talent maxed and no window running, and
--                     a talent change re-applies derived stats -- the APPLIED
--                     hp_max moves, and a respec takes it back.
--   7  WINDOWS        a timed window contributes 0 before it starts and after
--                     it expires, and respec / death / leave clear it.
--   8  NEUTRAL SEAMS  with NO talent ranked, the four central per-player
--                     seams reproduce today's numbers exactly -- Taunt 8 s,
--                     Charge 10 s, Blink 15 s, Smite 2 s, Hamstring's 6 s
--                     charge, Fireball 6% base mana / 20 m, and an elf's 25 m --
--                     and move by the documented amount when they are ranked.
--   9  RAGE LEDGER    ruling 25 (option b): 8 per landed swing at all five
--                     sites, 3 per hit taken, 5 rage/s decay out of combat,
--                     with swings-to-full and seconds-to-empty computed from
--                     the constants the shipped file actually carries.
--
-- Plain Lua 5.1, no engine.
--
-- Usage (from the repository root):
--   luajit          -e 'io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))'

local M = {}

local SOURCES = {
	scout_class = "mods/PLAYER/grug_classes/scout.lua",
	scout_talents = "mods/PLAYER/grug_classes/scout_talents.lua",
	stats = "mods/PLAYER/grug_classes/stats.lua",
	talents = "mods/PLAYER/grug_classes/talents.lua",
	abilities = "mods/PLAYER/grug_abilities/init.lua",
	kits = "mods/PLAYER/grug_abilities/kits.lua",
	equipment = "mods/PLAYER/grug_inventory/equipment.lua",
	combat = "mods/CORE/grug_core/combat.lua",
	scout_abilities = "mods/PLAYER/grug_abilities/scout.lua",
}

-- Files a lane-X2 effect key may be read from. talents.lua is deliberately
-- NOT here: it is where the key is DECLARED, so finding it there would prove
-- nothing about a consumer.
local CONSUMER_SOURCES = {"scout_class", "stats", "abilities", "kits",
	"scout_abilities", "equipment", "combat"}

--
-- Deterministic number formatting. Both interpreters print through C printf,
-- but "%g" on an integral double still differs from "%d" in enough corners to
-- be worth pinning down once.
--
local function num(value)
	if value == math.floor(value) and math.abs(value) < 1e15 then
		return string.format("%d", value)
	end
	local text = string.format("%.6f", value)
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")
	return text
end

local function read_file(path)
	local handle = io.open(path, "rb")
	if not handle then
		return nil
	end
	local text = handle:read("*a")
	handle:close()
	return text
end

--
-- The stub engine. One environment for all five files, because the real
-- dependency direction is one environment too: talents.lua publishes
-- grug_core.get_talent_bonus and the consumers read grug_classes directly.
--

local function build_env(repo, clock)
	local noop = function() end
	local function stub_table(fields)
		return setmetatable(fields or {}, {__index = function(t, key)
			rawset(t, key, noop)
			return noop
		end})
	end

	local core_stub = {
		registered_nodes = {}, registered_items = {}, registered_tools = {},
		registered_entities = {}, registered_craftitems = {},
	}
	function core_stub.register_tool(name, def)
		core_stub.registered_tools[name] = def
	end
	function core_stub.get_us_time()
		return clock.us
	end
	function core_stub.get_modpath()
		return repo .. "/mods/PLAYER/grug_abilities"
	end
	function core_stub.get_current_modname()
		return "grug_abilities"
	end
	function core_stub.colorize(color, text)
		return text
	end
	function core_stub.chat_send_player(name, text)
		clock.chat[#clock.chat + 1] = name .. ": " .. text
	end
	function core_stub.get_connected_players()
		return {}
	end
	function core_stub.get_objects_inside_radius(pos, radius)
		return {}
	end
	function core_stub.get_item_group(name, group)
		if group == "grug_equip_weapon" and name:find("bow", 1, true) then
			return 1
		end
		if group == "grug_hands" and name:find("bow", 1, true) then
			return 2
		end
		return 0
	end
	function core_stub.register_chatcommand(name, def)
		clock.commands[name] = def
	end
	function core_stub.register_globalstep(func)
		clock.globalsteps[#clock.globalsteps + 1] = func
	end
	function core_stub.register_on_dieplayer(func)
		clock.die_callbacks[#clock.die_callbacks + 1] = func
	end
	function core_stub.register_on_leaveplayer(func)
		clock.leave_callbacks[#clock.leave_callbacks + 1] = func
	end
	function core_stub.register_on_player_hpchange(func)
		clock.hp_callbacks[#clock.hp_callbacks + 1] = func
	end
	function core_stub.get_player_by_name(name)
		return clock.players[name]
	end
	setmetatable(core_stub, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})

	local vector_stub = {}
	function vector_stub.new(x, y, z)
		if type(x) == "table" then
			return {x = x.x or 0, y = x.y or 0, z = x.z or 0}
		end
		return {x = x or 0, y = y or 0, z = z or 0}
	end
	function vector_stub.add(a, b)
		return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
	end
	function vector_stub.subtract(a, b)
		return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
	end
	function vector_stub.multiply(a, s)
		return {x = a.x * s, y = a.y * s, z = a.z * s}
	end
	function vector_stub.offset(a, x, y, z)
		return {x = a.x + x, y = a.y + y, z = a.z + z}
	end
	function vector_stub.distance(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	function vector_stub.direction(a, b)
		return vector_stub.new(b.x - a.x, b.y - a.y, b.z - a.z)
	end
	function vector_stub.length(a)
		return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
	end
	function vector_stub.normalize(a)
		local length = vector_stub.length(a)
		if length == 0 then return vector_stub.new() end
		return vector_stub.new(a.x / length, a.y / length, a.z / length)
	end
	function vector_stub.dot(a, b)
		return a.x * b.x + a.y * b.y + a.z * b.z
	end
	function vector_stub.round(a)
		return a
	end

	local grug_core = stub_table({})
	function grug_core.register_on_equipment_change(func)
		clock.equipment_callbacks[#clock.equipment_callbacks + 1] = func
	end
	function grug_core.register_on_settled_outgoing_action(func)
		clock.settled_callbacks[#clock.settled_callbacks + 1] = func
	end
	function grug_core.notify_equipment_change(player, listname, reason)
		for _, callback in ipairs(clock.equipment_callbacks) do
			callback(player, listname, reason)
		end
	end
	function grug_core.base_pool(level)
		return math.floor(20 + 5 * level + 0.66 * level * level + 0.5)
	end
	function grug_core.baseline_weapon_damage(level)
		return math.floor(4 + 0.35 * level + 0.5)
	end
	function grug_core.get_player_level(player)
		return player._level or 1
	end
	function grug_core.status_modifier_sum()
		return 0
	end
	function grug_core.combat_eye_pos(player)
		return vector_stub.new(0, 1.5, 0)
	end
	function grug_core.get_absorb(player)
		return clock.absorb or 0
	end
	function grug_core.get_equipped_weapon(player)
		return player:get_inventory():get_stack("grug_weapon", 1)
	end
	function grug_core.equipment_is_broken(stack)
		return stack._broken == true
	end
	function grug_core.set_move_modifier(player, id, modifier, duration)
		clock.move_effect = {id = id, modifier = modifier, duration = duration}
	end
	function grug_core.set_move_immunity(player, duration)
		clock.move_immunity = duration
	end
	function grug_core.clear_negative_move_modifiers()
		clock.cleared_negative = (clock.cleared_negative or 0) + 1
	end
	function grug_core.set_root(player, duration)
		clock.root_effect = duration
	end
	function grug_core.refuse_mounted_attack()
		return clock.mounted == true
	end
	function grug_core.deal_ability_damage(owner, target, amount, opts)
		clock.damage = {amount = amount, opts = opts}
		if clock.damage_accept ~= false then
			for _, callback in ipairs(clock.settled_callbacks) do
				callback(owner, opts.action_id, "damage")
			end
		end
		return amount
	end
	function grug_core.scale_player_value(player, amount)
		return math.max(0, amount or 0)
	end
	function grug_core.scale_player_damage(player, target, amount)
		return math.floor(grug_core.scale_player_value(player, amount))
	end

	local grug_classes = {
		registered_classes = {
			warrior = {id = "warrior", name = "Warrior", resource = "rage",
				armor_rank = 3, growth = {str = 3, int = 0, dex = 1}},
			mage = {id = "mage", name = "Mage", resource = "mana",
				armor_rank = 1, growth = {str = 0, int = 3, dex = 1}},
			priest = {id = "priest", name = "Priest", resource = "mana",
				armor_rank = 1, growth = {str = 1, int = 2, dex = 1}},
		},
		registered_races = {},
		class_ids = {"warrior", "mage", "priest"},
	}
	function grug_classes.register_class(def)
		grug_classes.registered_classes[def.id] = def
		grug_classes.class_ids[#grug_classes.class_ids + 1] = def.id
	end
	function grug_classes.get_class(player)
		return player._class
	end
	function grug_classes.get_class_def(player)
		return player._class
			and grug_classes.registered_classes[player._class] or nil
	end
	function grug_classes.get_armor_rank(player)
		local def = grug_classes.get_class_def(player)
		return def and def.armor_rank or 0
	end
	function grug_classes.get_race_perk(player, key)
		return player._perks and player._perks[key] or nil
	end
	function grug_classes.register_on_class_chosen(func)
		clock.class_callbacks[#clock.class_callbacks + 1] = func
	end
	function grug_classes.register_on_race_chosen(func) end

	local grug_xp = stub_table({})
	function grug_xp.get_level(player)
		return player._level or 1
	end

	local grug_projectiles = stub_table({registered = {}})
	function grug_projectiles.register(id, def)
		grug_projectiles.registered[id] = def
	end
	function grug_projectiles.spawn(id, params)
		clock.spawned = params
		return true
	end
	function grug_projectiles.spawn_batch(id, launches, commit)
		clock.spawn_batches[#clock.spawn_batches + 1] = launches
		if clock.spawn_failure then return false end
		if not commit() then return false end
		return true
	end

	local grug_inventory = stub_table({equipment_slots = false})
	function grug_inventory.is_bow(stack)
		return stack and stack:get_name():find("bow", 1, true) ~= nil
	end
	function grug_inventory.ammo_count()
		return clock.ammo
	end
	function grug_inventory.consume_ammo(player, count)
		if clock.ammo < count then return false end
		clock.ammo = clock.ammo - count
		clock.consumed = clock.consumed + count
		return true
	end
	function grug_inventory.refund_ammo(player, count)
		clock.ammo = clock.ammo + count
		clock.refunded = clock.refunded + count
		return true
	end

	local env = {
		core = core_stub, minetest = core_stub,
		vector = vector_stub,
		grug_core = grug_core,
		grug_classes = grug_classes,
		grug_xp = grug_xp,
		grug_factions = stub_table(),
		grug_mobs = stub_table(),
		grug_inventory = grug_inventory,
		grug_projectiles = grug_projectiles,
		grug_repair = {
			capture_action = function(player, id)
				clock.captured = clock.captured + 1
				local stack = player:get_inventory():get_stack("grug_weapon", 1)
				stack:get_meta():set_string("_grug_repair_item_id", "bow-1")
				return "receipt:" .. id
			end,
			cancel_action = function(player, id)
				clock.cancelled[#clock.cancelled + 1] = id
			end,
		},
		grug_items = {get_equipment_affix_totals = function()
			return {attack_speed_percent = clock.attack_speed or 0}
		end},
		grug_gear = stub_table({BRACKETS = {}, STARTER_BOW = "grug_gear:bow_wood",
			STARTER_SWORD = "default:sword_stone",
			STARTER_STAFF = "grug_gear:staff_wood"}),
		sfinv = stub_table(),
		dofile = noop,
		ItemStack = function(value)
			if type(value) == "table" then return value end
			local itemname = (value or ""):match("^%S+") or ""
			local count = tonumber((value or ""):match("%s+(%d+)$")) or
				(itemname == "" and 0 or 1)
			local strings, wear = {}, 0
			return stub_table({
				get_name = function() return itemname end,
				get_count = function() return count end,
				get_wear = function() return wear end,
				set_wear = function(_, value) wear = value end,
				set_tool_capabilities = noop,
				get_meta = function()
					return {get_string = function(_, key) return strings[key] or "" end,
						set_string = function(_, key, text) strings[key] = text end,
						set_int = function(_, key, number) strings[key] = tostring(number) end,
						set_tool_capabilities = function() end}
				end,
				is_empty = function() return itemname == "" end,
				equals = function(_, other)
					return other and itemname == other:get_name()
				end,
			})
		end,
		math = math, table = table, string = string, os = os, io = io,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber, select = select,
		unpack = unpack, error = error, assert = assert, pcall = pcall,
		setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal,
	}
	function core_stub.yaw_to_dir(yaw)
		return {x = -math.sin(yaw), y = 0, z = math.cos(yaw)}
	end
	env._G = env
	env.dofile = function(path)
		if not path:find("/scout_talents.lua$", 1, false) then return end
		local chunk = assert(loadfile(repo .. "/" .. SOURCES.scout_talents))
		setfenv(chunk, env)
		return chunk()
	end
	return env
end

local function load_into(env, repo, path)
	local chunk, load_error = loadfile(repo .. "/" .. path)
	if not chunk then
		return "cannot load " .. path .. ": " .. tostring(load_error)
	end
	setfenv(chunk, env)
	local ok, run_error = pcall(chunk)
	if not ok then
		return "loading " .. path .. " failed: " .. tostring(run_error)
	end
	return nil
end

--
-- Stub player. A real PlayerMetaRef is a string store, and that is the whole
-- surface the persistence path uses.
--

local function make_meta()
	local values = {}
	local meta = {}
	function meta:get_string(key)
		return values[key] or ""
	end
	function meta:set_string(key, value)
		values[key] = value
	end
	function meta:get_int(key)
		return tonumber(values[key]) or 0
	end
	function meta:set_int(key, value)
		values[key] = tostring(value)
	end
	function meta:get_float(key)
		return tonumber(values[key]) or 0
	end
	function meta:set_float(key, value)
		values[key] = tostring(value)
	end
	return meta
end

local function make_stack(name)
	local strings = {}
	local wear = 0
	local stack = {}
	function stack:get_name()
		return name
	end
	function stack:get_meta()
		return {
			get_string = function(_, key) return strings[key] or "" end,
			set_string = function(_, key, value) strings[key] = value end,
			set_tool_capabilities = function() end,
		}
	end
	function stack:is_empty() return name == "" end
	function stack:get_wear() return wear end
	function stack:set_wear(value) wear = value end
	function stack:get_tool_capabilities()
		return {full_punch_interval = 1, damage_groups = {fleshy = 10}}
	end
	function stack:set_tool_capabilities() end
	function stack:equals(other)
		return other and name == other:get_name()
	end
	return stack
end

local function make_inventory()
	local inventory = {main = {}, writes = 0, grug_weapon = {make_stack("")},
		grug_offhand = {make_stack("")}, _added = {}}
	function inventory:get_list(name)
		return self[name]
	end
	function inventory:get_lists()
		return {main = self.main, grug_weapon = self.grug_weapon,
			grug_offhand = self.grug_offhand}
	end
	function inventory:set_stack(name, index, stack)
		self[name][index] = stack
		self.writes = self.writes + 1
	end
	function inventory:get_stack(name, index)
		return self[name] and self[name][index] or make_stack("")
	end
	function inventory:set_size(name, size)
		self[name] = self[name] or {}
	end
	function inventory:get_size(name)
		return #(self[name] or {})
	end
	function inventory:room_for_item() return true end
	function inventory:add_item(name, stack)
		self._added[#self._added + 1] = {name = stack:get_name(),
			count = stack.get_count and stack:get_count() or 1}
		return make_stack("")
	end
	return inventory
end

-- The four properties/HP accessors are not decoration: grug_classes.apply_stats
-- is the only writer of a player's hp_max, it now runs on every talent change,
-- and the APPLIED ceiling -- not get_max_hp -- is what a player feels.
local function make_player(name, class, level, perks)
	local meta = make_meta()
	local properties = {eye_height = 1.5, hp_max = 20}
	local hp = 20
	local inventory = make_inventory()
	local player = {_class = class, _level = level, _perks = perks or {},
		_control = {dig = false}, _wield = make_stack("")}
	player._pos, player._look = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 1}
	function player:get_player_name()
		return name
	end
	function player:is_player()
		return true
	end
	function player:get_meta()
		return meta
	end
	function player:get_pos()
		return self._pos
	end
	function player:get_look_dir()
		return self._look
	end
	function player:get_look_horizontal() return self._yaw or 0 end
	function player:get_wielded_item() return self._wield end
	function player:get_wield_index() return 1 end
	function player:get_player_control() return self._control end
	function player:get_properties()
		-- A copy, like the engine's: a caller that mutates the table it got
		-- back must not change the object.
		local copy = {}
		for key, value in pairs(properties) do
			copy[key] = value
		end
		return copy
	end
	function player:set_properties(fields)
		for key, value in pairs(fields) do
			properties[key] = value
		end
	end
	function player:get_hp()
		return hp
	end
	function player:set_hp(value)
		hp = value
	end
	function player:get_inventory()
		return inventory
	end
	function player:set_ability_stacks(ids)
		inventory.main = {}
		for index, id in ipairs(ids) do
			inventory.main[index] = make_stack("grug_abilities:" .. id)
		end
	end
	function player:inventory_write_count()
		return inventory.writes
	end
	return player
end

local function run_checks(repo)
	repo = repo or "."
	local out, failures = {}, {}
	local function row(...)
		local parts = {}
		for index = 1, select("#", ...) do
			parts[index] = tostring((select(index, ...)))
		end
		out[#out + 1] = table.concat(parts, "\t")
	end
	local function check(condition, message)
		if not condition then
			failures[#failures + 1] = message
		end
	end
	local function equal(got, want, message)
		check(got == want, message .. " -- got " .. tostring(got) ..
			", expected " .. tostring(want))
	end
	local function finish()
		table.sort(failures)
		row("wp11_talents_result", #failures == 0 and "PASS" or "FAIL", #failures)
		for _, message in ipairs(failures) do
			row("wp11_talents_failure", message)
		end
		return table.concat(out, "\n") .. "\n", #failures == 0
	end

	local clock = {us = 0, chat = {}, commands = {}, absorb = 0,
		globalsteps = {}, die_callbacks = {}, leave_callbacks = {}, hp_callbacks = {},
		class_callbacks = {}, settled_callbacks = {},
		equipment_callbacks = {}, players = {}, spawn_batches = {}, ammo = 20,
		consumed = 0, refunded = 0}
	clock.captured, clock.cancelled = 0, {}
	local env = build_env(repo, clock)
	for _, itemname in ipairs({"grug_gear:bow_wood", "default:sword_stone",
			"grug_gear:staff_wood", "grug_gear:arrow"}) do
		env.core.registered_items[itemname] = {description = itemname}
	end
	for _, key in ipairs({"scout_class", "stats", "talents", "abilities",
			"kits", "scout_abilities", "equipment"}) do
		local equipment_before = #clock.equipment_callbacks
		local err = load_into(env, repo, SOURCES[key])
		if err then
			check(false, err)
			return finish()
		end
		if key == "scout_abilities" then
			clock.scout_equipment_callback =
				clock.equipment_callbacks[equipment_before + 1]
			clock.scout_globalstep = clock.globalsteps[#clock.globalsteps]
		end
	end
	local classes = env.grug_classes
	local abilities = env.grug_abilities

	--
	-- 1. Shape.
	--
	local trees, talents = classes.registered_trees, classes.registered_talents
	equal(#classes.talent_ids, 64, "talent registrations")
	equal(#classes.tree_ids, 8, "tree registrations")
	local ranks_per_class, trees_per_class = {}, {}
	for _, tree_id in ipairs(classes.tree_ids) do
		local tree = trees[tree_id]
		trees_per_class[tree.class] = (trees_per_class[tree.class] or 0) + 1
		local per_chain, ranks, keystones, capstones = {}, 0, 0, 0
		for _, def in ipairs(tree.talents) do
			per_chain[def.chain] = (per_chain[def.chain] or 0) + 1
			ranks = ranks + def.ranks
			local want
			if def.capstone then
				want = 1
			else
				want = classes.TALENT_TIER_RANKS[def.tier]
			end
			equal(def.ranks, want, "talent " .. def.id .. " rank count")
			if def.keystone then
				keystones = keystones + 1
				equal(def.tier, 3, "keystone " .. def.id .. " tier")
			end
			if def.capstone then
				capstones = capstones + 1
				equal(def.tier, 4, "capstone " .. def.id .. " tier")
				equal(def.chain, tree.capstone_chain,
					"capstone " .. def.id .. " chain")
			end
		end
		equal(#tree.talents, 8, "tree " .. tree_id .. " talent count")
		equal(keystones, 2, "tree " .. tree_id .. " keystone count")
		equal(capstones, 1, "tree " .. tree_id .. " capstone count")
		equal(ranks, 28, "tree " .. tree_id .. " rank sum")
		for _, chain in ipairs(tree.chains) do
			equal(per_chain[chain], 4, "tree " .. tree_id .. " chain " ..
				chain .. " talent count")
		end
		ranks_per_class[tree.class] = (ranks_per_class[tree.class] or 0) + ranks
		row("wp11_tree", tree_id, tree.class, ranks, #tree.talents)
	end
	for class_id in pairs(classes.registered_classes) do
		equal(trees_per_class[class_id], 2, "class " .. class_id .. " tree count")
		equal(ranks_per_class[class_id], 56, "class " .. class_id .. " rank sum")
	end

	--
	-- 2. Arithmetic, driven through real spends rather than restated.
	--
	local GATES = classes.TALENT_TIER_GATES
	row("wp11_gates", GATES[1], GATES[2], GATES[3], GATES[4])
	local sixty = make_player("arith", "warrior", 60)
	equal(classes.talent_points_total(sixty), 30, "points at level 60")
	equal(classes.talent_points_total(make_player("l1", "warrior", 1)), 0,
		"points at level 1")
	equal(classes.talent_points_total(make_player("l2", "warrior", 2)), 1,
		"points at level 2 (the first point, ruling 1)")
	equal(classes.talent_points_total(make_player("l3", "warrior", 3)), 1,
		"points at level 3")

	-- Spend a whole tree in a legal order and record the level each milestone
	-- of §1.3 lands on. The order is the cheapest one: the capstone's chain
	-- first, then whatever the next gate needs.
	local function spend_times(player, id, times)
		for _ = 1, times do
			local ok, reason = classes.spend_talent(player, id)
			if not ok then
				return false, reason
			end
		end
		return true
	end
	local function level_for(points)
		return points * classes.TALENT_LEVELS_PER_POINT
	end

	local walker = make_player("walk", "warrior", 60)
	equal(select(1, spend_times(walker, "ironbound", 5)), true,
		"maxing a tier-1 talent")
	equal(classes.tree_points(walker, "bulwark"), 5, "tier-1 maxed cost")
	equal(level_for(5), 10, "tier-1 maxed level")
	equal(select(1, spend_times(walker, "weathered", 4)), true,
		"maxing a tier-2 talent")
	equal(classes.tree_points(walker, "bulwark"), 9, "tier-2 maxed cost")
	equal(level_for(9), 18, "tier-2 maxed level")
	-- The first keystone needs three points in the OTHER chain: 9 on the
	-- chain is not 12 in the tree, which is what makes a tree a tree.
	local ok_gate, gate_reason = classes.can_spend_talent(walker, "hold_ground")
	equal(ok_gate, false, "keystone at 9 in-tree points is refused")
	row("wp11_gate_reason", gate_reason)
	equal(select(1, spend_times(walker, "spite", 3)), true, "three in the other chain")
	equal(select(1, spend_times(walker, "hold_ground", 1)), true,
		"the first keystone rank at 12 in-tree points")
	equal(classes.tree_points(walker, "bulwark"), 13, "first keystone cost")
	equal(level_for(13), 26, "first keystone level")
	equal(select(1, spend_times(walker, "hold_ground", 2)), true,
		"maxing the first keystone")
	equal(classes.tree_points(walker, "bulwark"), 15, "keystone maxed cost")
	equal(level_for(15), 30, "keystone maxed level")
	-- The second keystone of the same tree: both chains through tier 2.
	equal(select(1, spend_times(walker, "spite", 2)), true, "spite to 5/5")
	equal(select(1, spend_times(walker, "affront", 4)), true, "affront to 4/4")
	equal(classes.tree_points(walker, "bulwark"), 21, "both chains through tier 2")
	-- ... which means the SECOND keystone's first rank sits at 20 spent when
	-- the capstone chain is not maxed. Rebuild the §1.3 row on a clean player.
	local second = make_player("second", "warrior", 60)
	equal(select(1, spend_times(second, "ironbound", 5)), true, "s ironbound")
	equal(select(1, spend_times(second, "weathered", 4)), true, "s weathered")
	equal(select(1, spend_times(second, "spite", 5)), true, "s spite")
	equal(select(1, spend_times(second, "affront", 4)), true, "s affront")
	equal(classes.tree_points(second, "bulwark"), 18, "both chains to tier 2")
	equal(select(1, spend_times(second, "hold_ground", 1)), true, "s keystone A")
	equal(select(1, spend_times(second, "bellow", 1)), true, "s keystone B")
	equal(classes.tree_points(second, "bulwark"), 20, "both keystones at rank 1")
	equal(level_for(20), 40, "both keystones level")
	equal(select(1, classes.can_spend_talent(second, "unbroken")), false,
		"20/10 build cannot also take the capstone (one point short)")

	-- The capstone: 21 points in its tree, level 42, and two are out of reach.
	local cap = make_player("cap", "warrior", 60)
	-- The cheapest legal ORDER, and it is not the chain in one go: the
	-- keystone's tier-3 gate wants 12 in the tree, which nine on one chain
	-- cannot reach. That is §1.2's "a tree reads as a tree" made concrete.
	spend_times(cap, "ironbound", 5)
	spend_times(cap, "weathered", 4)
	spend_times(cap, "spite", 5)
	spend_times(cap, "hold_ground", 3)
	spend_times(cap, "affront", 2)
	equal(classes.tree_points(cap, "bulwark"), 19, "one short of the tier-4 gate")
	equal(select(1, classes.can_spend_talent(cap, "unbroken")), false,
		"the capstone at 19 in-tree points is refused")
	spend_times(cap, "affront", 1)
	equal(classes.tree_points(cap, "bulwark"), 20, "the tier-4 gate is open")
	equal(select(1, classes.can_spend_talent(cap, "unbroken")), true,
		"the capstone at 20 in-tree points is allowed (it is the 21st point)")
	equal(select(1, spend_times(cap, "unbroken", 1)), true, "taking the capstone")
	equal(classes.tree_points(cap, "bulwark"), 21, "a capstone costs 21 in-tree")
	equal(level_for(21), 42, "the first capstone lands at level 42")
	equal(classes.talent_points_available(cap), 9, "points left after a capstone")
	equal(select(1, classes.can_spend_talent(cap, "unbroken")), false,
		"a capstone has exactly one rank (ruling 17)")
	equal(select(1, classes.can_spend_talent(cap, "ruination")), false,
		"the second tree's capstone is out of reach with 9 points")
	check(21 + 21 > classes.talent_points_total(cap),
		"two capstones (42) must exceed the 30 points a character ever sees")
	check(28 + 28 > classes.talent_points_total(cap),
		"two full trees (56) must exceed 30 points")
	row("wp11_capstone", 21, level_for(21), "second", 42, "budget", 30)

	-- A full tree costs 28 and leaves two points.
	local full = make_player("full", "warrior", 60)
	spend_times(full, "ironbound", 5)
	spend_times(full, "weathered", 4)
	spend_times(full, "spite", 5)
	spend_times(full, "affront", 4)
	spend_times(full, "hold_ground", 3)
	spend_times(full, "bellow", 3)
	spend_times(full, "unbroken", 1)
	spend_times(full, "grudge", 3)
	equal(classes.tree_points(full, "bulwark"), 28, "a whole tree costs 28")
	equal(classes.talent_points_available(full), 2, "two points left over")
	equal(level_for(28), 56, "a whole tree is finished at level 56")

	-- No build holds more than two new-skill keystones: one per tree, and a
	-- second tree's keystone costs 13.
	local new_skills = 0
	for _, def in pairs(talents) do
		if def.ability then
			new_skills = new_skills + 1
		end
	end
	equal(new_skills, 8, "new-skill keystones across the four shipped classes")
	for _, tree_id in ipairs(classes.tree_ids) do
		local per_tree = 0
		for _, def in ipairs(trees[tree_id].talents) do
			if def.ability then
				per_tree = per_tree + 1
			end
		end
		equal(per_tree, 1, "tree " .. tree_id .. " new-skill keystone count")
	end

	--
	-- 3. Spend rules (§3.7 group 3).
	--
	local function forged(name, class, level, pairs_text)
		local player = make_player(name, class, level)
		player:get_meta():set_string("grug_classes:talents", pairs_text)
		classes.invalidate_talents(player)
		return player
	end

	local cases = {
		{"tier2_at_4", "ironbound=4", "weathered", false},
		{"tier2_at_5", "ironbound=5", "weathered", true},
		{"tier3_at_11", "ironbound=5,weathered=4,spite=2", "hold_ground", false},
		{"tier3_at_12", "ironbound=5,weathered=4,spite=3", "hold_ground", true},
		{"tier4_at_19", "ironbound=5,weathered=4,hold_ground=3,spite=5,affront=2",
			"unbroken", false},
		{"tier4_at_20", "ironbound=5,weathered=4,hold_ground=3,spite=5,affront=3",
			"unbroken", true},
		{"chain_broken", "ironbound=4,spite=5,affront=4,bellow=3", "weathered", false},
		{"chain_whole", "ironbound=5,spite=5,affront=4,bellow=3", "weathered", true},
		{"sixth_rank", "ironbound=5", "ironbound", false},
		{"keystone_at_2of3_capstone",
			"ironbound=5,weathered=4,hold_ground=2,spite=5,affront=4,bellow=1",
			"unbroken", false},
		{"foreign_class", "", "tinder", false},
	}
	for _, case in ipairs(cases) do
		local player = forged("case_" .. case[1], "warrior", 60, case[2])
		local ok, reason = classes.can_spend_talent(player, case[3])
		equal(ok == true, case[4], "spend case " .. case[1])
		row("wp11_case", case[1], tostring(ok == true), reason or "-")
	end
	-- Points, not gates: a level-1 character and an exhausted budget.
	equal(select(1, classes.can_spend_talent(
		make_player("lvl1", "warrior", 1), "ironbound")), false,
		"a spend at level 1 is refused")
	local broke = forged("broke", "warrior", 10, "ironbound=5")
	equal(classes.talent_points_available(broke), 0, "level 10 budget")
	equal(select(1, classes.can_spend_talent(broke, "spite")), false,
		"a spend with 0 points left is refused")
	equal(select(1, classes.can_spend_talent(
		make_player("classless", nil, 60), "ironbound")), false,
		"a character without a class cannot spend")

	--
	-- 4. Persistence round trip, and four forged strings.
	--
	local round = make_player("round", "warrior", 60)
	spend_times(round, "ironbound", 5)
	spend_times(round, "weathered", 2)
	spend_times(round, "spite", 3)
	local text = round:get_meta():get_string("grug_classes:talents")
	row("wp11_serialized", text)
	classes.invalidate_talents(round)
	equal(round:get_meta():get_string("grug_classes:talents"), text,
		"a re-parse must not rewrite the stored string")
	equal(classes.talent_rank(round, "ironbound"), 5, "round trip ironbound")
	equal(classes.talent_rank(round, "weathered"), 2, "round trip weathered")
	equal(classes.talent_rank(round, "spite"), 3, "round trip spite")
	equal(classes.talent_points_spent(round), 10, "round trip total")

	local unknown = forged("unknown", "warrior", 60, "unknown_id=2,ironbound=3")
	equal(classes.talent_rank(unknown, "unknown_id"), 0,
		"an unknown talent id is dropped")
	equal(classes.talent_points_spent(unknown), 3,
		"an unknown talent id costs no points")
	-- The same forgery with NO real id beside it: an unknown id must not be
	-- quietly attached to some other talent either, which is the failure mode
	-- a lookup with a fallback would have.
	local unknown_only = forged("unknownonly", "warrior", 60, "not_a_talent=4")
	equal(classes.talent_points_spent(unknown_only), 0,
		"a meta string of nothing but an unknown id spends nothing")
	for _, id in ipairs(classes.talent_ids) do
		equal(classes.talent_rank(unknown_only, id), 0,
			"an unknown id must not land on talent " .. id)
	end
	local over = forged("over", "warrior", 60,
		"ironbound=5,weathered=4,hold_ground=3,spite=5,affront=3,ruination=9")
	equal(classes.talent_rank(over, "ruination"), 0,
		"a capstone of the WRONG tree is dropped with its gate")
	local clamped = forged("clamped", "warrior", 60,
		"ironbound=5,weathered=4,hold_ground=3,spite=5,affront=3,unbroken=9")
	equal(classes.talent_rank(clamped, "unbroken"), 1,
		"a forged capstone rank is clamped to its one rank")
	local midchain = forged("midchain", "warrior", 60,
		"ironbound=3,weathered=4,spite=5,affront=4")
	equal(classes.talent_rank(midchain, "weathered"), 0,
		"a forged mid-chain rank drops everything below it in its chain")
	equal(classes.talent_rank(midchain, "ironbound"), 3,
		"and leaves what was legal above it alone")
	local rich = forged("rich", "warrior", 4,
		"ironbound=5,weathered=4,hold_ground=3,spite=5,affront=3,unbroken=1")
	equal(classes.talent_points_total(rich), 2, "a level-4 budget is 2")
	check(classes.talent_points_spent(rich) <= 2,
		"a hand-edited meta string cannot buy a capstone at level 4 -- spent " ..
		classes.talent_points_spent(rich))
	equal(classes.talent_rank(rich, "unbroken"), 0,
		"the forged capstone is gone at level 4")
	local foreign = forged("foreign", "warrior", 60, "tinder=5")
	equal(classes.talent_rank(foreign, "tinder"), 0,
		"another class's talent is dropped")

	-- Ruling 20's last bullet: an admin level drop wipes the talents and
	-- returns every point, free. /xp can lower a level, which would otherwise
	-- leave more ranks spent than floor(level / 2) allows.
	local dropped = make_player("dropped", "warrior", 60)
	spend_times(dropped, "ironbound", 5)
	spend_times(dropped, "weathered", 4)
	spend_times(dropped, "spite", 5)
	equal(classes.talent_points_spent(dropped), 14, "fourteen points spent")
	local chat_before = #clock.chat
	dropped._level = 4
	classes.on_level_change_talents(dropped, 60, 4)
	equal(classes.talent_points_spent(dropped), 0,
		"an admin level drop wipes every rank")
	equal(dropped:get_meta():get_string("grug_classes:talents"), "",
		"and empties the stored string")
	equal(classes.talent_points_total(dropped), 2, "the level-4 budget is 2")
	equal(classes.talent_points_available(dropped), 2,
		"every point is available again, free")
	check(#clock.chat > chat_before, "the level drop said nothing at all")
	local line = clock.chat[#clock.chat] or ""
	check(line:find("14", 1, true) ~= nil,
		"the level-drop line must report the 14 ranks it wiped, not the " ..
		"post-clamp count -- got: " .. line)
	-- Going UP says nothing about a reset and keeps what is spent.
	local levelled = make_player("levelled", "warrior", 60)
	spend_times(levelled, "ironbound", 3)
	classes.on_level_change_talents(levelled, 58, 60)
	equal(classes.talent_points_spent(levelled), 3,
		"levelling up must not reset anything")
	-- And join (old_level nil) must not do arithmetic on nil.
	classes.on_level_change_talents(levelled, nil, 60)
	equal(classes.talent_points_spent(levelled), 3,
		"the join call (old_level nil) is a no-op for talents")
	row("wp11_level_drop", "spent_before", 14, "spent_after", 0,
		"points_available", classes.talent_points_available(dropped))

	--
	-- 5. Effect-key coverage.
	--
	local vocabulary = classes.TALENT_EFFECT_KEYS
	local used, mine, theirs = {}, {}, {}
	for _, id in ipairs(classes.talent_ids) do
		for key in pairs(talents[id].effects) do
			check(vocabulary[key] ~= nil, "talent " .. id .. " uses key '" ..
				key .. "' outside the closed vocabulary")
			used[key] = true
		end
	end
	local source_text = {}
	for _, key in ipairs(CONSUMER_SOURCES) do
		local text_of = read_file(repo .. "/" .. SOURCES[key])
		check(text_of ~= nil, "cannot read consumer source " .. SOURCES[key])
		source_text[key] = text_of or ""
	end
	local vocabulary_size = 0
	for key, owner in pairs(vocabulary) do
		vocabulary_size = vocabulary_size + 1
		check(used[key], "vocabulary key '" .. key ..
			"' belongs to no talent at all")
		if owner == "X3" then
			theirs[#theirs + 1] = key
		else
			mine[#mine + 1] = key
			local found = false
			for _, name in ipairs(CONSUMER_SOURCES) do
				if source_text[name]:find('"' .. key .. '"', 1, true) then
					found = true
				end
			end
			check(found, "effect key '" .. key ..
				"' is declared but no consumer source reads it")
		end
	end
	table.sort(mine)
	table.sort(theirs)
	row("wp11_keys", vocabulary_size, "consumed", #mine, "pending_x3", #theirs)
	row("wp11_keys_pending", table.concat(theirs, " "))

	--
	-- 6. Cap/rating invariants, with every shipped numeric talent maxed and no
	--    window running. Crit/dodge cap here; raw armor deliberately does not.
	--
	local capped = forged("capped", "warrior", 60,
		"ironbound=5,weathered=4,hold_ground=3,spite=5,affront=4,bellow=3," ..
		"unbroken=1")
	equal(classes.talent_rank(capped, "ironbound"), 5, "capped ironbound rank")
	check(classes.get_crit_chance(capped) <= 0.30,
		"crit chance must stay at or below the 30% cap")
	check(classes.get_dodge_chance(capped) <= 0.30,
		"dodge chance must stay at or below the 30% cap")
	local crit_maxed = forged("critmax", "warrior", 60, "keen_edge=5")
	local crit_none = make_player("critnone", "warrior", 60)
	equal(num(classes.get_crit_chance(crit_maxed)
		- classes.get_crit_chance(crit_none)), num(0.05),
		"five ranks of Keen Edge add exactly five percentage points")
	-- A level no character reaches, purely to show the clamp is live rather
	-- than merely never approached: at level 400 the Dexterity term alone
	-- exceeds the cap, and the talent must not push it past 30% either.
	local over_cap = forged("overcap", "warrior", 400, "keen_edge=5")
	equal(num(classes.get_crit_chance(over_cap)), num(0.30),
		"the 30% crit cap binds with a ranked crit talent")
	row("wp11_crit", num(classes.get_crit_chance(crit_none)),
		num(classes.get_crit_chance(crit_maxed)))
	check(classes.get_crit_chance(crit_maxed) > classes.get_crit_chance(crit_none),
		"Keen Edge must actually raise crit chance")
	-- Armor: the real raw-rating accessor has no pre-formula cap.
	env.grug_inventory.get_equipped_armor = function(player)
		return player._armor or 0
	end
	local plate = forged("plate", "warrior", 60, "ironbound=5")
	plate._armor = 60
	equal(env.grug_core.get_armor_rating(plate), 65,
		"Ironbound remains raw rating above the old cap")
	local light = forged("light", "warrior", 60, "ironbound=5")
	light._armor = 10
	equal(env.grug_core.get_armor_rating(light), 15,
		"Ironbound 5/5 on 10% gear")
	local bare = make_player("bare", "warrior", 60)
	bare._armor = 10
	equal(env.grug_core.get_armor_rating(bare), 10,
		"no talent, no change to armor")
	-- Max HP and max mana move by the documented amount and by nothing else.
	local hp_none = make_player("hpnone", "warrior", 60)
	local hp_maxed = forged("hpmax", "warrior", 60, "ironbound=5,weathered=4")
	equal(classes.get_max_hp(hp_maxed) - classes.get_max_hp(hp_none), 194,
		"Weathered 4/4 grants exactly +6% class-base max HP")

	-- ... and the same thing where the player can feel it. apply_stats is the
	-- only writer of hp_max, and a talent change has to reach it: spending
	-- Weathered through the real API must move the APPLIED ceiling, and a
	-- respec must take it back. Asserting get_max_hp alone is what let the
	-- gap through the first time.
	local applied = make_player("applied", "warrior", 60)
	classes.apply_stats(applied)
	local ceiling_before = applied:get_properties().hp_max
	equal(ceiling_before, classes.get_max_hp(applied),
		"the applied ceiling starts where the accessor says")
	equal(select(1, spend_times(applied, "ironbound", 5)), true, "a ironbound")
	equal(select(1, spend_times(applied, "weathered", 4)), true, "a weathered")
	equal(applied:get_properties().hp_max, ceiling_before + 194,
		"spending Weathered 4/4 must raise the APPLIED hp_max, not only " ..
		"grug_classes.get_max_hp")
	equal(classes.respec(applied), 9, "the respec returns nine points")
	equal(applied:get_properties().hp_max, ceiling_before,
		"a respec must take the raised ceiling back")
	-- And it must not hand out health on the way up: apply_stats is called
	-- without heal_gain, so current HP is untouched by a spend.
	local hp_before = applied:get_hp()
	spend_times(applied, "ironbound", 5)
	spend_times(applied, "weathered", 4)
	equal(applied:get_hp(), hp_before,
		"spending a point must not heal the character")
	classes.respec(applied)
	row("wp11_applied_hp", ceiling_before, ceiling_before + 194,
		"heal_on_spend", 0)

	-- The abilities talent callback walks the real main inventory. A ranked
	-- Smite and its respec must each rewrite exactly one stack; unrelated
	-- fixtures retain an empty but engine-shaped inventory.
	local tooltip_sync = make_player("tooltip_sync", "priest", 60)
	tooltip_sync:set_ability_stacks({"smite"})
	equal(tooltip_sync:inventory_write_count(), 0,
		"the tooltip fixture starts without inventory writes")
	equal(select(1, spend_times(tooltip_sync, "sharpened_word", 1)), true,
		"ranking Sharpened Word for tooltip sync")
	equal(tooltip_sync:inventory_write_count(), 1,
		"a talent spend rewrites its changed Smite stack once")
	equal(classes.respec(tooltip_sync), 1,
		"the tooltip sync respec returns its one point")
	equal(tooltip_sync:inventory_write_count(), 2,
		"a respec rewrites its changed Smite stack once")
	row("wp11_tooltip_inventory_writes", 2)

	local mana_none = make_player("mananone", "mage", 60)
	local mana_maxed = forged("manamax", "mage", 60, "deep_well=5")
	equal(classes.get_max_mana(mana_maxed),
		math.floor(classes.get_max_mana(mana_none) * 1.15),
		"Deep Well 5/5 grants exactly +15% max mana")
	row("wp11_stats", classes.get_max_hp(hp_none), classes.get_max_hp(hp_maxed),
		classes.get_max_mana(mana_none), classes.get_max_mana(mana_maxed))

	--
	-- 7. Window lifecycle.
	--
	local window = forged("window", "warrior", 60,
		"ironbound=5,weathered=4,hold_ground=3,spite=5,affront=3,unbroken=1")
	equal(classes.talent_rank(window, "unbroken"), 1, "the capstone is ranked")
	clock.us = 1000000
	equal(classes.get_talent_bonus(window, "armor_rating_add_low_hp"), 0,
		"a window key is 0 before its window starts")
	classes.start_talent_window(window, "unbroken", 8)
	equal(classes.get_talent_bonus(window, "armor_rating_add_low_hp"), 15,
		"a window key contributes while its window runs")
	clock.us = 1000000 + 9 * 1000000
	equal(classes.get_talent_bonus(window, "armor_rating_add_low_hp"), 0,
		"a window key is 0 after its window expires")
	classes.start_talent_window(window, "unbroken", 8)
	equal(classes.get_talent_bonus(window, "armor_rating_add_low_hp"), 15,
		"a window can be restarted")
	classes.clear_talent_windows(window)
	equal(classes.get_talent_bonus(window, "armor_rating_add_low_hp"), 0,
		"death and leave clear a running window")
	classes.start_talent_window(window, "unbroken", 8)
	classes.respec(window)
	equal(classes.get_talent_bonus(window, "armor_rating_add_low_hp"), 0,
		"a respec clears a running window")
	equal(classes.talent_points_spent(window), 0, "a respec is a FULL reset")
	equal(window:get_meta():get_string("grug_classes:talents"), "",
		"a respec empties the stored string")
	-- A window key never leaks into the cached static sum.
	local nowindow = forged("nowindow", "warrior", 60, "ironbound=5")
	equal(classes.get_talent_bonus(nowindow, "armor_rating_add_low_hp"), 0,
		"an unranked window key is 0")

	--
	-- 8. The shared central seams stay neutral without talents.
	--
	local registered = abilities.registered
	local plain = make_player("plain", "warrior", 60)
	local seams = {
		{"taunt", 8, "grudge", 3, 5},
		{"charge", 10, "onset", 4, 6},
	}
	for _, seam in ipairs(seams) do
		local def = registered[seam[1]]
		check(def ~= nil, "ability " .. seam[1] .. " is not registered")
		if def then
			equal(num(abilities.effective_cooldown(plain, def)), num(seam[2]),
				seam[1] .. " cooldown without a talent")
		end
	end
	local mage = make_player("mageseam", "mage", 60)
	local priest = make_player("priestseam", "priest", 60)
	equal(num(abilities.effective_cooldown(mage, registered.blink)), num(15),
		"Blink cooldown without a talent")
	equal(num(abilities.effective_cooldown(priest, registered.smite)), num(2),
		"Smite cooldown without a talent")
	equal(num(registered.hamstring.charge), num(6),
		"Hamstring's charge is untouched by any X2 talent")
	equal(registered.hamstring.talent_gated, true,
		"ruling 19: Hamstring is talent-gated and leaves the base kit")
	equal(registered.renew.talent_gated, true, "Renew stays talent-gated")
	equal(num(registered.fireball.cost.mana_percent), num(6),
		"Fireball costs 6% base mana")
	equal(num(abilities.mana_cost(mage, 6)), num(162),
		"Fireball costs 162 mana at L60")
	equal(num(abilities.get_range(mage, registered.fireball)), num(20),
		"Fireball's targeting reach without a talent")
	local elf = make_player("elf", "mage", 60, {ability_range_bonus = 5})
	equal(num(abilities.get_range(elf, registered.fireball)), num(25),
		"an elf's Fireball still reaches 25 m")
	-- ... and with the talents ranked, each seam moves by exactly the
	-- documented amount.
	local warrior_t = forged("warriorseam", "warrior", 60,
		"ironbound=5,weathered=4,spite=5,affront=4,hold_ground=3,bellow=3," ..
		"unbroken=1,grudge=3")
	equal(classes.talent_rank(warrior_t, "grudge"), 3, "Grudge is at 3/3")
	equal(num(abilities.effective_cooldown(warrior_t, registered.taunt)), num(5),
		"Grudge 3/3 takes Taunt to 5 s")
	local onset = forged("onsetseam", "warrior", 60,
		"keen_edge=5,onset=4")
	equal(num(abilities.effective_cooldown(onset, registered.charge)), num(6),
		"Onset 4/4 takes Charge to 6 s")
	local step = forged("stepseam", "mage", 60, "cold_focus=5,quick_step=4")
	equal(num(abilities.effective_cooldown(step, registered.blink)), num(9),
		"Quick Step 4/4 takes Blink to 9 s")
	local swift = forged("swiftseam", "priest", 60, "sharpened_word=5,swift_word=4")
	equal(num(abilities.effective_cooldown(swift, registered.smite)), num(1.4),
		"Swift Word 4/4 takes Smite to 1.4 s")
	local farcast = forged("farcast", "mage", 60, "deep_well=5,far_cast=4")
	equal(num(abilities.get_range(farcast, registered.fireball)), num(26),
		"Far Cast 4/4 takes Fireball's reach to 26 m")
	-- The projectile half of Far Cast, and Tinder, through the real cast body.
	local power = classes.get_spell_power_bonus(mage)
	clock.spawned = nil
	registered.fireball.cast(mage, nil, registered.fireball)
	check(clock.spawned ~= nil, "the Fireball cast spawned no projectile")
	if clock.spawned then
		equal(num(clock.spawned.max_distance), num(20),
			"Fireball flies 20 m without a talent")
		equal(num(clock.spawned.data.damage),
			num(env.grug_core.baseline_weapon_damage(60) + power),
			"Fireball uses baseline weapon plus spell power")
	end
	clock.spawned = nil
	local tinder = forged("tinder", "mage", 60, "tinder=5")
	registered.fireball.cast(tinder, nil, registered.fireball)
	if clock.spawned then
		equal(num(clock.spawned.data.damage),
			num(env.grug_core.baseline_weapon_damage(60) + power + 5),
			"Tinder 5/5 adds exactly 5 to Fireball")
		equal(num(clock.spawned.max_distance), num(20),
			"Tinder does not move the flight distance")
	end
	clock.spawned = nil
	registered.fireball.cast(farcast, nil, registered.fireball)
	if clock.spawned then
		equal(num(clock.spawned.max_distance), num(26),
			"Far Cast 4/4 takes Fireball's flight to 26 m")
	end
	row("wp11_seams", "taunt", 8, 5, "charge", 10, 6, "blink", 15, 9,
		"smite", 2, "1.4", "fireball", 20, 26)

	--
	-- 9. The rage ledger (ruling 25, option b).
	--
	local ability_source = read_file(repo .. "/" .. SOURCES.abilities) or ""
	equal(abilities.RAGE_PER_SWING, 8,
		"ruling 25: a landed full swing grants 8 rage")
	equal(abilities.RAGE_PER_HIT_TAKEN, 3,
		"ruling 25: a hit taken grants 3 rage")
	equal(abilities.RAGE_DECAY_PER_SECOND, 5,
		"ruling 25: rage decays 5/s out of combat")
	check(ability_source:find("RAGE_DECAY_PER_SECOND * elapsed", 1, true) ~= nil,
		"the out-of-combat decay does not use the named constant")
	local swing_sites = 0
	for _ in ability_source:gmatch("add_rage%([^\n]-swing_rage%(") do
		swing_sites = swing_sites + 1
	end
	equal(swing_sites, 5,
		"all five add_rage swing sites must feed from the one swing-rage value")
	local literal_sites = 0
	for _ in ability_source:gmatch("add_rage%([^\n]-12") do
		literal_sites = literal_sites + 1
	end
	equal(literal_sites, 0, "an add_rage site is still on the retired 12")
	local function ceil_div(a, b)
		return math.ceil(a / b)
	end
	local swings_to_full = ceil_div(100, abilities.RAGE_PER_SWING)
	local seconds_to_empty = 100 / abilities.RAGE_DECAY_PER_SECOND
	local swings_per_mighty_blow = ceil_div(25, abilities.RAGE_PER_SWING)
	local hits_to_full = ceil_div(100, abilities.RAGE_PER_HIT_TAKEN)
	row("wp11_rage_now", "per_swing", abilities.RAGE_PER_SWING,
		"per_hit_taken", abilities.RAGE_PER_HIT_TAKEN,
		"decay_per_s", abilities.RAGE_DECAY_PER_SECOND,
		"swings_to_full", swings_to_full,
		"seconds_to_empty", num(seconds_to_empty),
		"swings_per_mighty_blow", swings_per_mighty_blow,
		"hits_to_full", hits_to_full)
	-- The pre-ruling-25 baseline, as literals: this is what the shipped code
	-- did before this lane, and it is what the user's "in combat the resource
	-- is effectively unlimited" finding was measured against.
	row("wp11_rage_before", "per_swing", 12, "per_hit_taken", 4,
		"decay_per_s", 2, "swings_to_full", 9, "seconds_to_empty", 50,
		"swings_per_mighty_blow", 3, "hits_to_full", 25)
	equal(swings_to_full, 13, "swings to a full rage bar from 0")
	equal(num(seconds_to_empty), num(20), "seconds to empty from 100, no combat")
	equal(swings_per_mighty_blow, 4, "landed swings per Mighty Blow")
	-- Stoke and Spite add on top of the lowered income.
	local stoked = forged("stoked", "warrior", 60, "heavy_hand=5,stoke=4")
	equal(classes.talent_rank(stoked, "stoke"), 4, "Stoke is at 4/4")
	equal(abilities.RAGE_PER_SWING
		+ classes.get_talent_bonus(stoked, "rage_per_swing_add"), 12,
		"Stoke 4/4 restores the pre-ruling-25 income exactly")
	local spited = forged("spited", "warrior", 60, "spite=5")
	equal(abilities.RAGE_PER_HIT_TAKEN
		+ classes.get_talent_bonus(spited, "rage_per_hit_taken_add"), 8,
		"Spite 5/5 takes rage per hit taken to 8")

	--
	-- 10. Scout gameplay consumers and authoritative draw transaction.
	--
	local scout_def = classes.registered_classes.scout
	equal(scout_def.resource, "mana", "Scout uses mana")
	equal(scout_def.armor_rank, 2, "Scout wears leather")
	equal(scout_def.growth.str, 1, "Scout Strength growth")
	equal(scout_def.growth.int, 1, "Scout Intelligence growth")
	equal(scout_def.growth.dex, 2, "Scout Dexterity growth")
	for _, id in ipairs({"loose", "snare_shot", "sidestep", "sprint",
			"pinning_shot", "opening"}) do
		check(registered[id] ~= nil, "Scout ability " .. id .. " is registered")
	end

	local quarry = forged("quarry_gameplay", "scout", 60,
		"strong_draw=5,cold_eye=4,twin_shot=3,longshot=1,quiver=5," ..
		"fletching=4,pinning_shot=3,shifting_weight=3")
	local veil = forged("veil_gameplay", "scout", 60,
		"fine_edge=5,deep_focus=4,opening=3,follow_through=3,light_step=5," ..
		"slip_away=4,shake_loose=3,untouchable=1")
	local expected = {
		loose_damage_add = 5, crit_chance_add = 4, loose_second_arrow = 70,
		loose_range_add = 8, arrow_refund_chance = 50, draw_time_sub = 0.20,
		pinning_root = 3, melee_damage_add = 5, max_mana_percent_add = 12,
		opening_multiplier = 280, opening_charge_sub = 6,
		sidestep_cooldown_sub = 16, root_slow_immunity = 1,
	}
	for key, want in pairs(expected) do
		local veil_key = key == "melee_damage_add" or key == "max_mana_percent_add"
			or key == "opening_multiplier" or key == "opening_charge_sub"
			or key == "sidestep_cooldown_sub" or key == "root_slow_immunity"
		local player = veil_key and veil or quarry
		equal(num(classes.get_talent_bonus(player, key)), num(want),
			"Scout consumer value " .. key)
	end
	local scout_plain = make_player("scout_plain", "scout", 60)
	equal(num(classes.get_crit_chance(quarry) -
		classes.get_crit_chance(scout_plain)), num(0.04),
		"Cold Eye adds four crit percentage points")
	equal(num(classes.get_dodge_chance(quarry) -
		classes.get_dodge_chance(scout_plain)), num(0.03),
		"Shifting Weight adds three dodge percentage points")
	equal(num(classes.get_dodge_chance(veil) -
		classes.get_dodge_chance(scout_plain)), num(0.05),
		"Light Step adds five dodge percentage points")
	equal(classes.get_max_mana(veil),
		math.floor(classes.get_max_mana(scout_plain) * 1.12 + 0.5),
		"Deep Focus adds twelve percent maximum mana")
	equal(num(abilities.effective_cooldown(veil, registered.sidestep)), num(14),
		"Slip Away shortens Sidestep")
	equal(num(abilities.effective_charge(veil, registered.opening)), num(6),
		"Follow Through shortens Opening")

	-- Drive self skills through the real dispatcher so payment/cooldown and
	-- its self-target authority are covered together with their cast bodies.
	abilities.restore_mana(veil, 100000)
	abilities.try_cast(veil, registered.sidestep, {type = "object"})
	equal(classes.get_scout_dodge_add(veil), 15,
		"Sidestep dispatcher starts its dodge window")
	equal(clock.move_immunity, 4,
		"Shake Loose clears and blocks movement control for four seconds")
	equal(clock.cleared_negative, 1,
		"Shake Loose calls the central negative-movement dispel")
	local sprint_user = make_player("sprint_gameplay", "scout", 60)
	abilities.restore_mana(sprint_user, 100000)
	abilities.try_cast(sprint_user, registered.sprint, {type = "object"})
	equal(clock.move_effect and clock.move_effect.id, "scout_sprint",
		"Sprint dispatcher installs its movement modifier")
	equal(clock.move_effect and clock.move_effect.duration, 10,
		"Sprint lasts ten seconds")

	-- Loose starts through try_cast, then releases on the server-observed
	-- control edge and the current look vector. Fletching (0.30 s) and +20%
	-- bow attack speed make this exact full-draw boundary 0.25 s.
	clock.attack_speed = 20
	clock.players[quarry:get_player_name()] = quarry
	quarry:get_inventory().grug_weapon[1] = make_stack("grug_gear:bow_wood")
	quarry._wield = make_stack("grug_abilities:loose")
	quarry._control.dig = true
	local old_random = math.random
	math.random = function() return 1 end
	abilities.try_cast(quarry, registered.loose, nil)
	check(abilities.scout_draw_active(quarry),
		"Loose dispatcher did not start the held draw")
	-- First REPAIR capture adds persistent identity metadata. Its reason-aware
	-- equipment notification refreshes the snapshot without dropping the draw.
	env.grug_inventory.equipment_changed(quarry, "grug_weapon",
		"durability_metadata")
	check(abilities.scout_draw_active(quarry),
		"durability metadata cancelled a same-bow draw")
	clock.us = clock.us + 250000
	quarry._look = {x = 1, y = 0, z = 0}
	quarry._control.dig = false
	clock.scout_globalstep(0.25)
	math.random = old_random
	local twin = clock.spawn_batches[#clock.spawn_batches]
	equal(twin and #twin, 2, "Twin Shot spawns two siblings at full draw")
	equal(clock.consumed, 2, "Twin Shot atomically consumes two arrows")
	equal(clock.refunded, 2, "Quiver refunds both arrows after successful spawn")
	if twin then
		equal(twin[1].max_distance, 33, "Longshot raises projectile range")
		equal(twin[1].direction.x, 1, "Loose release reads current server aim")
		equal(twin[1].data.action_id, twin[2].data.action_id,
			"Twin Shot siblings share one repair receipt")
		equal(twin[2].data.damage,
			math.floor(twin[1].data.damage * 70 / 100),
			"Twin Shot second-arrow damage")
		clock.damage = nil
		env.grug_projectiles.registered.scout_arrow.on_hit(quarry,
			make_player("arrow_target", "warrior", 60), twin[1].data,
			{x = 30, y = 1.5, z = 0}, 60)
		equal(clock.damage and clock.damage.amount, twin[1].data.damage + 4,
			"Longshot adds four damage only beyond 25 metres")
	end

	-- The two aimed base/keystone shots also enter through try_cast and apply
	-- their landed control only after shared damage accepted the hit.
	local shot_user = forged("shot_gameplay", "scout", 60,
		"quiver=5,fletching=4,pinning_shot=3,strong_draw=5,cold_eye=4")
	shot_user:get_inventory().grug_weapon[1] = make_stack("grug_gear:bow_wood")
	abilities.restore_mana(shot_user, 100000)
	local mana_before_shot = abilities.get_mana(shot_user)
	abilities.try_cast(shot_user, registered.snare_shot, nil)
	equal(abilities.get_mana(shot_user), mana_before_shot -
		abilities.mana_cost(shot_user, 8),
		"Snare Shot dispatcher charges eight percent base mana")
	local snare = clock.spawn_batches[#clock.spawn_batches][1]
	local control_target = make_player("control_target", "warrior", 60)
	env.grug_projectiles.registered.scout_arrow.on_hit(shot_user,
		control_target, snare.data, {x = 5, y = 0, z = 0}, 60)
	equal(clock.move_effect and clock.move_effect.id, "scout_snare",
		"Snare Shot landed hit applies its slow")
	abilities.try_cast(shot_user, registered.pinning_shot, nil)
	local pin = clock.spawn_batches[#clock.spawn_batches][1]
	env.grug_projectiles.registered.scout_arrow.on_hit(shot_user,
		control_target, pin.data, {x = 5, y = 0, z = 0}, 60)
	equal(clock.root_effect, 3, "Pinning Shot rank three roots for three seconds")
	clock.root_effect = nil
	clock.damage_accept = false
	env.grug_projectiles.registered.scout_arrow.on_hit(shot_user,
		control_target, pin.data, {x = 5, y = 0, z = 0}, 60)
	clock.damage_accept = true
	equal(clock.root_effect, nil,
		"absorbed or callback-refused Pinning Shot applies no root")

	-- Spawn refusal rolls back the batch before ammo payment and refund.
	local fail_user = forged("draw_failure", "scout", 60, "strong_draw=1")
	clock.players[fail_user:get_player_name()] = fail_user
	fail_user:get_inventory().grug_weapon[1] = make_stack("grug_gear:bow_wood")
	fail_user._wield = make_stack("grug_abilities:loose")
	fail_user._control.dig = true
	local ammo_before, consumed_before = clock.ammo, clock.consumed
	clock.spawn_failure = true
	abilities.try_cast(fail_user, registered.loose, nil)
	clock.us = clock.us + 500000
	fail_user._control.dig = false
	clock.scout_globalstep(0.5)
	clock.spawn_failure = false
	equal(clock.ammo, ammo_before, "failed spawn consumes no arrow")
	equal(clock.consumed, consumed_before, "failed spawn records no payment")

	local partial_user = make_player("draw_partial", "scout", 60)
	clock.attack_speed = 0
	clock.players[partial_user:get_player_name()] = partial_user
	partial_user:get_inventory().grug_weapon[1] = make_stack("grug_gear:bow_wood")
	partial_user._wield = make_stack("grug_abilities:loose")
	partial_user._control.dig = true
	abilities.try_cast(partial_user, registered.loose, nil)
	clock.us = clock.us + 250000
	partial_user._control.dig = false
	clock.scout_globalstep(0.25)
	local partial = clock.spawn_batches[#clock.spawn_batches][1]
	equal(partial.speed, 20, "half draw scales arrow impulse linearly")
	equal(partial.data.damage, 11,
		"half draw scales bow plus ranged damage linearly")

	-- True weapon changes and lifecycle exits cancel the held action.
	fail_user._control.dig = true
	abilities.try_cast(fail_user, registered.loose, nil)
	fail_user:get_inventory().grug_weapon[1] = make_stack("grug_gear:bow_t1")
	env.grug_inventory.equipment_changed(fail_user, "grug_weapon")
	check(not abilities.scout_draw_active(fail_user),
		"a true bow swap did not cancel the held draw")
	fail_user:get_inventory().grug_weapon[1] = make_stack("grug_gear:bow_wood")
	abilities.try_cast(fail_user, registered.loose, nil)
	for _, callback in ipairs(clock.die_callbacks) do callback(fail_user) end
	check(not abilities.scout_draw_active(fail_user),
		"death did not cancel the held draw")
	fail_user._control.dig = true
	abilities.try_cast(fail_user, registered.loose, nil)
	fail_user._wield = make_stack("grug_abilities:sprint")
	clock.scout_globalstep(0.05)
	check(not abilities.scout_draw_active(fail_user),
		"wield change did not cancel the held draw")
	fail_user._wield = make_stack("grug_abilities:loose")
	fail_user._control.dig = true
	abilities.try_cast(fail_user, registered.loose, nil)
	local mounted_ammo = clock.ammo
	clock.mounted = true
	fail_user._control.dig = false
	clock.scout_globalstep(0.5)
	clock.mounted = false
	equal(clock.ammo, mounted_ammo,
		"mounting during a held draw refuses release without ammunition cost")
	check(not abilities.scout_draw_active(fail_user),
		"mounted release did not clear the held draw")

	-- Opening pays only for the target's rear hemisphere. The proc consumes
	-- the authoritative main-hand context and includes Fine Edge exactly once.
	local target = make_player("opening_target", "warrior", 60)
	target._pos, target._yaw = {x = 0, y = 0, z = 0}, 0
	veil._pos = {x = 0, y = 0, z = -1}
	local rear = registered.opening.proc_swing(veil, target,
		{weapon_damage = 10, melee_bonus = 2, melee_damage_add = 5})
	equal(rear, 35, "Opening rear hit uses 280% weapon plus melee and Fine Edge")
	veil._pos = {x = 0, y = 0, z = 1}
	equal(registered.opening.proc_swing(veil, target,
		{weapon_damage = 10, melee_bonus = 2, melee_damage_add = 5}), nil,
		"Opening front hit remains an ordinary uncharged swing")

	-- Untouchable is driven by the registered post-mitigation HP callback. Its
	-- window raises both dodge and cap, while the persisted timestamp prevents
	-- a second trigger during the 180-second cooldown.
	veil:set_hp(10)
	for _, callback in ipairs(clock.hp_callbacks) do
		callback(veil, -5, {type = "punch"})
	end
	equal(classes.get_talent_bonus(veil, "dodge_chance_window"), 25,
		"Untouchable starts its 25-point dodge window below 30 percent HP")
	equal(classes.get_scout_dodge_cap(veil), 55,
		"Untouchable raises the dodge cap to 55 percent")
	local ready_at = veil:get_meta():get_string("grug_classes:untouchable_ready")
	for _, callback in ipairs(clock.hp_callbacks) do
		callback(veil, -5, {type = "punch"})
	end
	equal(veil:get_meta():get_string("grug_classes:untouchable_ready"), ready_at,
		"Untouchable persistent cooldown blocks immediate retrigger")

	local starter = make_player("starter_scout", "scout", 1)
	for _, callback in ipairs(clock.class_callbacks) do
		callback(starter, "scout")
	end
	equal(starter:get_inventory():get_stack("grug_weapon", 1):get_name(),
		"grug_gear:bow_wood", "Scout starter bow is equipped")
	local starter_items = {}
	for _, item in ipairs(starter:get_inventory()._added) do
		starter_items[item.name] = item.count
	end
	equal(starter_items["default:sword_stone"], 1,
		"Scout starter stone sword is in main")
	equal(starter_items["grug_gear:arrow"], 20,
		"Scout starter receives twenty arrows")
	row("wp11_scout_gameplay", "talents", 16, "twin", 2,
		"range", twin and twin[1].max_distance or 0,
		"ammo_after_refund", clock.ammo)

	--
	-- X4 keeps only the read-only summary command. Spending and resetting are
	-- page actions, so the two interim mutation commands must be absent.
	--
	check(clock.commands.talents ~= nil,
		"read-only chat command /talents is not registered")
	check(clock.commands.talent == nil,
		"interim mutation command /talent is still registered")
	check(clock.commands.respec == nil,
		"interim mutation command /respec is still registered")

	return finish()
end

-- A fixture that RAISES has not passed. PASS preserves the historical single
-- string result used by timings/mutation consumers. FAIL returns false plus
-- its diagnostic string, so an old io.write(kat()) consumer exits non-zero
-- and an aware consumer can still print the ordinary failure row.
function M.run(repo)
	local ok, result, passed = pcall(run_checks, repo)
	if ok and passed then
		return result
	end
	if ok then
		return false, result
	end
	return false, "wp11_talents_failure\tthe fixture raised: " ..
		tostring(result) .. "\nwp11_talents_result\tFAIL\t1\n"
end

return function(repo)
	return M.run(repo)
end
