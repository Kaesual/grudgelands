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
--   mods/PLAYER/grug_inventory/equipment.lua the armor percent and its cap
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
--   4  PERSISTENCE    serialize -> parse -> identical, and four forged meta
--                     strings that the validating read path must defuse.
--   5  KEY COVERAGE   every talent effect key is in the closed vocabulary,
--                     every vocabulary key belongs to a talent, and every key
--                     THIS LANE owns is read by a real consumer source file.
--                     Lane X3's keys are counted and named, not required.
--   6  CAP INVARIANTS crit and dodge stay <= 30% and armor <= 60% with every
--                     shipped numeric talent maxed and no window running.
--   7  WINDOWS        a timed window contributes 0 before it starts and after
--                     it expires, and respec / death / leave clear it.
--   8  NEUTRAL SEAMS  with NO talent ranked, the four central per-player
--                     seams reproduce today's numbers exactly -- Taunt 8 s,
--                     Charge 10 s, Blink 15 s, Smite 2 s, Hamstring's 6 s
--                     charge, Fireball 8 mana / 20 m, and an elf's 25 m --
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
	stats = "mods/PLAYER/grug_classes/stats.lua",
	talents = "mods/PLAYER/grug_classes/talents.lua",
	abilities = "mods/PLAYER/grug_abilities/init.lua",
	kits = "mods/PLAYER/grug_abilities/kits.lua",
	equipment = "mods/PLAYER/grug_inventory/equipment.lua",
	combat = "mods/CORE/grug_core/combat.lua",
}

-- Files a lane-X2 effect key may be read from. talents.lua is deliberately
-- NOT here: it is where the key is DECLARED, so finding it there would prove
-- nothing about a consumer.
local CONSUMER_SOURCES = {"stats", "abilities", "kits", "equipment", "combat"}

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
	function core_stub.register_chatcommand(name, def)
		clock.commands[name] = def
	end
	setmetatable(core_stub, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})

	local vector_stub = {}
	function vector_stub.new(x, y, z)
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
	function vector_stub.round(a)
		return a
	end

	local grug_core = stub_table({})
	function grug_core.combat_eye_pos(player)
		return vector_stub.new(0, 1.5, 0)
	end
	function grug_core.get_absorb(player)
		return clock.absorb or 0
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
	function grug_classes.get_class(player)
		return player._class
	end
	function grug_classes.get_class_def(player)
		return player._class
			and grug_classes.registered_classes[player._class] or nil
	end
	function grug_classes.get_race_perk(player, key)
		return player._perks and player._perks[key] or nil
	end
	function grug_classes.register_on_class_chosen(func) end
	function grug_classes.register_on_race_chosen(func) end

	local grug_xp = stub_table({})
	function grug_xp.get_level(player)
		return player._level or 1
	end

	local grug_projectiles = stub_table({})
	function grug_projectiles.spawn(id, params)
		clock.spawned = params
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
		grug_inventory = stub_table(),
		grug_projectiles = grug_projectiles,
		grug_gear = stub_table({BRACKETS = {}}),
		sfinv = stub_table(),
		dofile = noop,
		ItemStack = function() return stub_table() end,
		math = math, table = table, string = string, os = os, io = io,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber, select = select,
		unpack = unpack, error = error, assert = assert, pcall = pcall,
		setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal,
	}
	env._G = env
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

local function make_player(name, class, level, perks)
	local meta = make_meta()
	local player = {_class = class, _level = level, _perks = perks or {}}
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
		return {x = 0, y = 0, z = 0}
	end
	function player:get_look_dir()
		return {x = 0, y = 0, z = 1}
	end
	function player:get_properties()
		return {eye_height = 1.5, hp_max = 20}
	end
	function player:get_hp()
		return 20
	end
	return player
end

function M.run(repo)
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
		return table.concat(out, "\n") .. "\n"
	end

	local clock = {us = 0, chat = {}, commands = {}, absorb = 0}
	local env = build_env(repo, clock)
	for _, key in ipairs({"stats", "talents", "abilities", "kits", "equipment"}) do
		local err = load_into(env, repo, SOURCES[key])
		if err then
			check(false, err)
			return finish()
		end
	end
	local classes = env.grug_classes
	local abilities = env.grug_abilities

	--
	-- 1. Shape.
	--
	local trees, talents = classes.registered_trees, classes.registered_talents
	equal(#classes.talent_ids, 48, "talent registrations")
	equal(#classes.tree_ids, 6, "tree registrations")
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
	equal(new_skills, 6, "new-skill keystones across the three shipped classes")
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
	-- 6. Cap invariants, with every shipped numeric talent maxed and no
	--    window running. The two cap OVERRIDES (Ruination, Unbroken) are lane
	--    X3's, so crit and armor must be hard-capped here.
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
	-- Armor: the real get_armor_percent, fed a full-plate 60.
	env.grug_inventory.get_equipped_armor = function(player)
		return player._armor or 0
	end
	local plate = forged("plate", "warrior", 60, "ironbound=5")
	plate._armor = 60
	equal(env.grug_core.get_armor_percent(plate), 60,
		"Ironbound on 60% gear must stay at the 60% cap")
	local light = forged("light", "warrior", 60, "ironbound=5")
	light._armor = 10
	equal(env.grug_core.get_armor_percent(light), 15,
		"Ironbound 5/5 on 10% gear")
	local bare = make_player("bare", "warrior", 60)
	bare._armor = 10
	equal(env.grug_core.get_armor_percent(bare), 10,
		"no talent, no change to armor")
	-- Max HP and max mana move by the documented amount and by nothing else.
	local hp_none = make_player("hpnone", "warrior", 60)
	local hp_maxed = forged("hpmax", "warrior", 60, "ironbound=5,weathered=4")
	equal(classes.get_max_hp(hp_maxed) - classes.get_max_hp(hp_none), 12,
		"Weathered 4/4 grants exactly +12 max HP")
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
	equal(classes.get_talent_bonus(window, "armor_cap_override"), 0,
		"a window key is 0 before its window starts")
	classes.start_talent_window(window, "unbroken", 8)
	equal(classes.get_talent_bonus(window, "armor_cap_override"), 75,
		"a window key contributes while its window runs")
	equal(classes.get_talent_bonus(window, "armor_percent_add_low_hp"), 15,
		"both keys of one windowed talent run together")
	clock.us = 1000000 + 9 * 1000000
	equal(classes.get_talent_bonus(window, "armor_cap_override"), 0,
		"a window key is 0 after its window expires")
	classes.start_talent_window(window, "unbroken", 8)
	equal(classes.get_talent_bonus(window, "armor_cap_override"), 75,
		"a window can be restarted")
	classes.clear_talent_windows(window)
	equal(classes.get_talent_bonus(window, "armor_cap_override"), 0,
		"death and leave clear a running window")
	classes.start_talent_window(window, "unbroken", 8)
	classes.respec(window)
	equal(classes.get_talent_bonus(window, "armor_cap_override"), 0,
		"a respec clears a running window")
	equal(classes.talent_points_spent(window), 0, "a respec is a FULL reset")
	equal(window:get_meta():get_string("grug_classes:talents"), "",
		"a respec empties the stored string")
	-- A window key never leaks into the cached static sum.
	local nowindow = forged("nowindow", "warrior", 60, "ironbound=5")
	equal(classes.get_talent_bonus(nowindow, "armor_cap_override"), 0,
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
	equal(num(registered.fireball.cost.mana), num(8), "Fireball costs 8 mana")
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
		equal(num(clock.spawned.data.damage), num(6 + power),
			"Fireball deals 6 + spell power without a talent")
	end
	clock.spawned = nil
	local tinder = forged("tinder", "mage", 60, "tinder=5,far_cast=0")
	local tinder_far = forged("tinderfar", "mage", 60, "tinder=5,firebrand=4")
	registered.fireball.cast(tinder, nil, registered.fireball)
	if clock.spawned then
		equal(num(clock.spawned.data.damage), num(6 + power + 5),
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
	check(tinder_far ~= nil, "fixture guard")
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
	-- The interim chat interface exists and is player-reachable.
	--
	for _, name in ipairs({"talents", "talent", "respec"}) do
		check(clock.commands[name] ~= nil,
			"interim chat command /" .. name .. " is not registered")
		if clock.commands[name] then
			check(clock.commands[name].privs == nil,
				"/" .. name .. " must not be admin-only while it is the " ..
				"only talent interface")
		end
	end

	return finish()
end

return function(repo)
	return M.run(repo)
end
