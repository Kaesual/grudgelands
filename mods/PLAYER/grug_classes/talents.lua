-- Talent trees (docs/design/skill_trees.md, WP11 lane X1: "the model").
--
-- This file is the registry, the 48 talents of the three shipped classes as
-- DATA, the point budget, the two gate kinds, the spend/respec rules, the
-- validating persistence path, the timed-window table and the two accessors
-- every consumer reads. Lane X1 ships INERT: registering a talent changes no
-- number by itself; the consumers are the one-line reads lane X2 puts at the
-- sites skill_trees.md §3.8 names.
--
-- Shape (§1.1/§1.2): two trees per class, two chains per tree, four tiers per
-- chain. Ranks run 5 / 4 / 3 down a chain, and the capstone has exactly ONE
-- rank (ruling 17), so the capstone's chain is 5+4+3+1 = 13 and the other
-- 5+4+3+3 = 15 -- 28 ranks per tree, 56 per class.
--
-- Points (§1.3, ruling 1): one every two levels, the first at level 2, so
-- floor(level / 2) and 30 at level 60. Never persisted -- deriving it is what
-- makes "points available" and "level" incapable of disagreeing.
--
-- Gates (§1.2), and both are needed:
--   * a TIER GATE is points already spent IN THAT TREE -- 0 / 5 / 12 / 20;
--   * a HARD CHAIN is "all ranks of the talent above it, in the same chain".
-- A capstone therefore costs 21 points in its tree (its chain to 12, eight
-- more anywhere in the tree to open the gate, and the capstone itself), which
-- is level 42, and two capstones would cost 42 of the 30 points a character
-- ever sees. Ruling 18's "exactly one capstone" is arithmetic here, not a rule.

local META_TALENTS = "grug_classes:talents"

-- Points in the tree required BEFORE the first rank of a talent of this tier.
grug_classes.TALENT_TIER_GATES = {0, 5, 12, 20}
-- Ranks by tier; a capstone overrides its tier-4 entry with one rank.
grug_classes.TALENT_TIER_RANKS = {5, 4, 3, 3}
grug_classes.TALENT_CAPSTONE_RANKS = 1
grug_classes.TALENT_LEVELS_PER_POINT = 2

grug_classes.registered_trees = {}
grug_classes.tree_ids = {} -- registration order
grug_classes.registered_talents = {}
grug_classes.talent_ids = {} -- registration order

--
-- The closed effect vocabulary (§3.1: "every effect key present in the closed
-- vocabulary table"). A typo is a startup failure, never a silently inert
-- talent, and skill_trees.md §3.7 group 5 walks this table against the real
-- consumer sources. The comment on each key is the site that reads it; `X3`
-- marks a key whose consumer belongs to lane X3 (keystones, capstones and the
-- two talents that re-tune an ability X3 still has to register).
--

local EFFECT_KEYS = {
	-- Lane X2 consumers (the reads this lane wrote).
	armor_percent_add = "grug_inventory/equipment.lua get_armor_percent",
	max_hp_add = "grug_classes/stats.lua get_max_hp",
	max_mana_percent_add = "grug_classes/stats.lua get_max_mana",
	crit_chance_add = "grug_classes/stats.lua get_crit_chance",
	rage_per_hit_taken_add = "grug_abilities/init.lua hit-taken rage",
	rage_per_swing_add = "grug_abilities/init.lua the five swing rage sites",
	threat_mult_add = "grug_core/combat.lua casts, grug_abilities/init.lua swings",
	heal_threat_factor_sub = "grug_core/combat.lua add_heal_threat",
	taunt_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	charge_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	blink_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	smite_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	mighty_blow_multiplier_add = "grug_abilities/kits.lua Mighty Blow",
	fireball_damage_add = "grug_abilities/kits.lua Fireball",
	fireball_range_add = "grug_abilities/kits.lua spawn, init.lua get_range",
	frost_nova_root_add = "grug_abilities/kits.lua Frost Nova",
	frost_nova_slow_add = "grug_abilities/kits.lua Frost Nova",
	blink_distance_add = "grug_abilities/kits.lua Blink",
	flash_heal_add = "grug_abilities/kits.lua Flash Heal",
	shield_absorb_add = "grug_abilities/kits.lua Power Word: Shield",
	shield_duration_add = "grug_abilities/kits.lua Power Word: Shield",
	smite_damage_add = "grug_abilities/kits.lua Smite",
	smite_damage_while_shielded_add = "grug_abilities/kits.lua Smite",
	combat_mana_regen_add = "grug_abilities/init.lua in-combat mana regen",
	-- Lane X3 consumers (keystones, capstones, and the two finishers whose
	-- ability X3 still has to register or un-gate).
	hold_ground_absorb = "X3",
	armor_percent_add_low_hp = "X3",
	armor_cap_override = "X3",
	taunt_radius = "X3",
	mighty_blow_cleave = "X3",
	crit_chance_add_window = "X3",
	crit_cap_override = "X3",
	hamstring_slow_add = "X3",
	hamstring_root = "X3",
	fireball_splash = "X3",
	whitehot_window = "X3",
	cinderfall_damage = "X3",
	cinderfall_radius_add = "X3",
	frost_nova_ranged = "X3",
	control_damage_add = "X3",
	glacial_ward_absorb = "X3",
	renew_tick_add = "X3",
	flash_heal_splash = "X3",
	dodge_chance_window = "X3",
	word_of_ruin_damage = "X3",
	drain_ratio_override = "X3",
	smite_absorb = "X3",
}

grug_classes.TALENT_EFFECT_KEYS = EFFECT_KEYS

-- Keys that only count while the talent's own timed window runs (§3.2: the
-- one new shape revision 2 adds). get_talent_bonus returns 0 for them when no
-- window is running, so a consumer needs no second accessor.
local WINDOW_KEYS = {
	armor_percent_add_low_hp = true,
	armor_cap_override = true,
	crit_chance_add_window = true,
	crit_cap_override = true,
	whitehot_window = true,
	dodge_chance_window = true,
	drain_ratio_override = true,
}

grug_classes.TALENT_WINDOW_KEYS = WINDOW_KEYS

--
-- Registration. Mirrors register_class/register_ability: the shape is
-- asserted at load time, so a malformed talent stops the server instead of
-- quietly doing nothing.
--

function grug_classes.register_tree(def)
	assert(type(def) == "table", "tree definition must be a table")
	assert(def.id and def.class and def.name,
		"incomplete tree definition: " .. tostring(def.id))
	assert(not grug_classes.registered_trees[def.id],
		"duplicate tree id " .. tostring(def.id))
	assert(grug_classes.registered_classes[def.class],
		"tree " .. def.id .. " names an unknown class " .. tostring(def.class))
	assert(type(def.chains) == "table" and #def.chains == 2,
		"tree " .. def.id .. " needs exactly two chains (ruling 2)")
	assert(def.chains[1] ~= def.chains[2],
		"tree " .. def.id .. " has the same chain twice")
	assert(def.capstone_chain == def.chains[1]
		or def.capstone_chain == def.chains[2],
		"tree " .. def.id .. " has no capstone_chain among its chains")
	def.talents = {} -- registration order, filled by register_talent
	grug_classes.registered_trees[def.id] = def
	table.insert(grug_classes.tree_ids, def.id)
	return def
end

local function ranks_for(tree, def)
	if def.capstone then
		return grug_classes.TALENT_CAPSTONE_RANKS
	end
	return grug_classes.TALENT_TIER_RANKS[def.tier]
end

function grug_classes.register_talent(def)
	assert(type(def) == "table", "talent definition must be a table")
	assert(def.id and def.tree and def.chain and def.name,
		"incomplete talent definition: " .. tostring(def.id))
	assert(not grug_classes.registered_talents[def.id],
		"duplicate talent id " .. def.id)
	local tree = grug_classes.registered_trees[def.tree]
	assert(tree, "talent " .. def.id .. " names an unknown tree " ..
		tostring(def.tree))
	assert(def.chain == tree.chains[1] or def.chain == tree.chains[2],
		"talent " .. def.id .. " names a chain outside its tree")
	assert(type(def.tier) == "number" and def.tier >= 1 and def.tier <= 4
		and def.tier == math.floor(def.tier),
		"talent " .. def.id .. " has no tier in 1..4")
	assert(not def.keystone or def.tier == 3,
		"talent " .. def.id .. " is a keystone outside tier 3")
	assert(not def.capstone or def.tier == 4,
		"talent " .. def.id .. " is a capstone outside tier 4")
	assert(not def.capstone or def.chain == tree.capstone_chain,
		"talent " .. def.id .. " is a capstone off its tree's capstone chain")
	assert(not (def.keystone and def.capstone),
		"talent " .. def.id .. " is both keystone and capstone")
	def.ranks = ranks_for(tree, def)
	def.class = tree.class
	assert(type(def.effects) == "table", "talent " .. def.id .. " has no effects")
	local keys = 0
	for key, values in pairs(def.effects) do
		assert(EFFECT_KEYS[key], "talent " .. def.id ..
			" uses effect key '" .. tostring(key) ..
			"', which is not in the closed vocabulary")
		assert(type(values) == "table" and #values == def.ranks,
			"talent " .. def.id .. " effect '" .. key .. "' needs exactly " ..
			def.ranks .. " values, one per rank")
		for _, value in ipairs(values) do
			assert(type(value) == "number",
				"talent " .. def.id .. " effect '" .. key ..
				"' has a non-numeric rank value")
		end
		keys = keys + 1
	end
	assert(keys > 0, "talent " .. def.id .. " declares no effect at all")
	grug_classes.registered_talents[def.id] = def
	table.insert(grug_classes.talent_ids, def.id)
	table.insert(tree.talents, def)
	return def
end

-- The talent one tier above this one in the SAME chain (the hard chain).
-- Built by the audit below, so a lookup is a table index on the hot paths.
local function talent_above(def)
	return def.above
end

--
-- Load-time audit (§3.1). Everything that cannot be checked while a single
-- talent registers -- counts per chain, per tree and per class -- is checked
-- once, here, after the data below has run.
--

function grug_classes.audit_talents()
	local trees_of_class = {}
	for _, tree_id in ipairs(grug_classes.tree_ids) do
		local tree = grug_classes.registered_trees[tree_id]
		trees_of_class[tree.class] = (trees_of_class[tree.class] or 0) + 1
		local by_slot, keystones, capstones, ranks = {}, {}, 0, 0
		for _, def in ipairs(tree.talents) do
			local slot = def.chain .. ":" .. def.tier
			assert(not by_slot[slot], "tree " .. tree_id ..
				" has two talents at " .. slot)
			by_slot[slot] = def
			ranks = ranks + def.ranks
			if def.keystone then
				keystones[def.chain] = (keystones[def.chain] or 0) + 1
			end
			if def.capstone then
				capstones = capstones + 1
			end
		end
		assert(#tree.talents == 8,
			"tree " .. tree_id .. " holds " .. #tree.talents ..
			" talents instead of 8")
		assert(capstones == 1,
			"tree " .. tree_id .. " holds " .. capstones ..
			" capstones instead of 1")
		for _, chain in ipairs(tree.chains) do
			assert(keystones[chain] == 1, "tree " .. tree_id .. " chain " ..
				chain .. " holds " .. tostring(keystones[chain]) ..
				" keystones instead of 1")
			for tier = 1, 4 do
				assert(by_slot[chain .. ":" .. tier], "tree " .. tree_id ..
					" chain " .. chain .. " has no tier-" .. tier .. " talent")
			end
			for tier = 2, 4 do
				by_slot[chain .. ":" .. tier].above =
					by_slot[chain .. ":" .. (tier - 1)]
			end
		end
		assert(ranks == 28, "tree " .. tree_id .. " holds " .. ranks ..
			" ranks instead of the 28 of skill_trees.md §1.2")
		tree.ranks = ranks
	end
	for class_id, count in pairs(trees_of_class) do
		assert(count == 2, "class " .. class_id .. " holds " .. count ..
			" trees instead of 2")
	end
end

--
-- The 48 talents of the three shipped classes (skill_trees.md §§2.1-2.6).
-- DATA ONLY: every "Modifies" cell of those tables is a consumer elsewhere.
-- Descriptions are the player-facing text the interim chat commands print and
-- lane X4's sfinv page will reuse.
--

grug_classes.register_tree({
	id = "bulwark", class = "warrior", name = "Bulwark",
	description = "Take hits and hold attention.",
	chains = {"wall", "anvil"},
	capstone_chain = "wall",
})

grug_classes.register_talent({
	id = "ironbound", tree = "bulwark", chain = "wall", tier = 1,
	name = "Ironbound",
	description = "Armor +1 percentage point per rank, under the 60% cap.",
	effects = {armor_percent_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "weathered", tree = "bulwark", chain = "wall", tier = 2,
	name = "Weathered",
	description = "Maximum health +3 per rank.",
	effects = {max_hp_add = {3, 6, 9, 12}},
})
grug_classes.register_talent({
	id = "hold_ground", tree = "bulwark", chain = "wall", tier = 3,
	keystone = true, ability = "hold_ground",
	name = "Hold Ground",
	description = "New skill: 25 rage, absorbs 20/30/40 + 2x floor(Str/10) " ..
		"for 8 s, and for those 8 s you cannot be rooted or slowed. " ..
		"60 s cooldown.",
	effects = {hold_ground_absorb = {20, 30, 40}},
})
grug_classes.register_talent({
	id = "unbroken", tree = "bulwark", chain = "wall", tier = 4,
	capstone = true, window = true,
	name = "Unbroken",
	description = "Once every 180 s, a hit that would take you below 20% " ..
		"health grants +15 armor with the cap raised to 75% for 8 s.",
	effects = {armor_percent_add_low_hp = {15}, armor_cap_override = {75}},
})
grug_classes.register_talent({
	id = "spite", tree = "bulwark", chain = "anvil", tier = 1,
	name = "Spite",
	description = "+1 rage per hit taken, per rank (base 3).",
	effects = {rage_per_hit_taken_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "affront", tree = "bulwark", chain = "anvil", tier = 2,
	name = "Affront",
	description = "Tank-ability threat x3 becomes x3.25 / 3.5 / 3.75 / 4.0.",
	effects = {threat_mult_add = {0.25, 0.5, 0.75, 1.0}},
})
grug_classes.register_talent({
	id = "bellow", tree = "bulwark", chain = "anvil", tier = 3,
	keystone = true, replaces = "taunt",
	name = "Bellow",
	description = "Taunt stops being single-target: every hostile mob " ..
		"within 6 / 8 / 10 m is forced onto you.",
	effects = {taunt_radius = {6, 8, 10}},
})
grug_classes.register_talent({
	id = "grudge", tree = "bulwark", chain = "anvil", tier = 4,
	name = "Grudge",
	description = "Taunt cooldown 8 s becomes 7 / 6 / 5 s.",
	effects = {taunt_cooldown_sub = {1, 2, 3}},
})

grug_classes.register_tree({
	id = "ruin", class = "warrior", name = "Ruin",
	description = "Spend rage for damage.",
	chains = {"hammer", "lash"},
	capstone_chain = "hammer",
})

grug_classes.register_talent({
	id = "heavy_hand", tree = "ruin", chain = "hammer", tier = 1,
	name = "Heavy Hand",
	description = "Mighty Blow x1.5 weapon damage becomes " ..
		"x1.55 / 1.60 / 1.65 / 1.70 / 1.75.",
	effects = {mighty_blow_multiplier_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "stoke", tree = "ruin", chain = "hammer", tier = 2,
	name = "Stoke",
	description = "+1 rage per landed swing, per rank (base 8).",
	effects = {rage_per_swing_add = {1, 2, 3, 4}},
})
grug_classes.register_talent({
	id = "broadstroke", tree = "ruin", chain = "hammer", tier = 3,
	keystone = true, replaces = "mighty_blow",
	name = "Broadstroke",
	description = "Mighty Blow also strikes every other hostile within 3 m " ..
		"for half its total, rounded down, at x3 threat.",
	effects = {mighty_blow_cleave = {3, 3, 3}},
})
grug_classes.register_talent({
	id = "ruination", tree = "ruin", chain = "hammer", tier = 4,
	capstone = true, window = true,
	name = "Ruination",
	description = "Once every 120 s, a landed Mighty Blow grants 10 s of " ..
		"+20 crit chance with the cap raised to 50%.",
	effects = {crit_chance_add_window = {20}, crit_cap_override = {50}},
})
grug_classes.register_talent({
	id = "keen_edge", tree = "ruin", chain = "lash", tier = 1,
	name = "Keen Edge",
	description = "+1 percentage point crit chance per rank (30% cap holds).",
	effects = {crit_chance_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "onset", tree = "ruin", chain = "lash", tier = 2,
	name = "Onset",
	description = "Charge cooldown 10 s becomes 9 / 8 / 7 / 6 s.",
	effects = {charge_cooldown_sub = {1, 2, 3, 4}},
})
grug_classes.register_talent({
	id = "hamstring", tree = "ruin", chain = "lash", tier = 3,
	keystone = true, ability = "hamstring",
	name = "Hamstring",
	description = "New skill: the shipped snare (10 rage, 6 s charge, 50% " ..
		"slow). Ranks 2 and 3 lengthen the slow to 6 / 7 s.",
	effects = {hamstring_slow_add = {0, 1, 2}},
})
grug_classes.register_talent({
	id = "tendon_cut", tree = "ruin", chain = "lash", tier = 4,
	name = "Tendon Cut",
	description = "Hamstring's charged proc roots for 2 / 2.5 / 3 s before " ..
		"its slow begins. 12 s internal cooldown.",
	effects = {hamstring_root = {2, 2.5, 3}},
})

grug_classes.register_tree({
	id = "ember", class = "mage", name = "Ember",
	description = "Fire damage.",
	chains = {"blaze", "cinder"},
	capstone_chain = "blaze",
})

grug_classes.register_talent({
	id = "tinder", tree = "ember", chain = "blaze", tier = 1,
	name = "Tinder",
	description = "Fireball damage +1 per rank.",
	effects = {fireball_damage_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "firebrand", tree = "ember", chain = "blaze", tier = 2,
	name = "Firebrand",
	description = "+1 percentage point crit chance per rank.",
	effects = {crit_chance_add = {1, 2, 3, 4}},
})
grug_classes.register_talent({
	id = "brand", tree = "ember", chain = "blaze", tier = 3,
	keystone = true, replaces = "fireball",
	name = "Brand",
	description = "Fireball's impact splashes 2 / 3 / 4 + floor(spell " ..
		"power / 2) to every other hostile within 2 m.",
	effects = {fireball_splash = {2, 3, 4}},
})
grug_classes.register_talent({
	id = "whitehot", tree = "ember", chain = "blaze", tier = 4,
	capstone = true, window = true,
	name = "Whitehot",
	description = "Once every 120 s, the first Fireball that crits starts " ..
		"8 s in which Fireball costs 4 mana instead of 8 and deals +6.",
	effects = {whitehot_window = {8}},
})
grug_classes.register_talent({
	id = "deep_well", tree = "ember", chain = "cinder", tier = 1,
	name = "Deep Well",
	description = "Maximum mana +3% per rank.",
	effects = {max_mana_percent_add = {3, 6, 9, 12, 15}},
})
grug_classes.register_talent({
	id = "far_cast", tree = "ember", chain = "cinder", tier = 2,
	name = "Far Cast",
	description = "Fireball's maximum distance 20 m becomes " ..
		"21.5 / 23 / 24.5 / 26 m.",
	effects = {fireball_range_add = {1.5, 3, 4.5, 6}},
})
grug_classes.register_talent({
	id = "cinderfall", tree = "ember", chain = "cinder", tier = 3,
	keystone = true, ability = "cinderfall",
	name = "Cinderfall",
	description = "New skill: 12 mana, 10 s cooldown, 20 m; a burst dealing " ..
		"5 / 7 / 9 + spell power to every hostile within 3 m of it.",
	effects = {cinderfall_damage = {5, 7, 9}},
})
grug_classes.register_talent({
	id = "ashfall", tree = "ember", chain = "cinder", tier = 4,
	name = "Ashfall",
	description = "Cinderfall's radius 3 m becomes 4 / 5 / 6 m.",
	effects = {cinderfall_radius_add = {1, 2, 3}},
})

grug_classes.register_tree({
	id = "rime", class = "mage", name = "Rime",
	description = "Control and survival.",
	chains = {"frost", "ward"},
	capstone_chain = "frost",
})

grug_classes.register_talent({
	id = "deep_chill", tree = "rime", chain = "frost", tier = 1,
	name = "Deep Chill",
	description = "Frost Nova's root 4 s becomes 4.2 / 4.4 / 4.6 / 4.8 / 5 s.",
	effects = {frost_nova_root_add = {0.2, 0.4, 0.6, 0.8, 1.0}},
})
grug_classes.register_talent({
	id = "hoarfrost", tree = "rime", chain = "frost", tier = 2,
	name = "Hoarfrost",
	description = "Frost Nova's follow-up slow 3 s becomes 4 / 5 / 6 / 7 s.",
	effects = {frost_nova_slow_add = {1, 2, 3, 4}},
})
grug_classes.register_talent({
	id = "frostbind", tree = "rime", chain = "frost", tier = 3,
	keystone = true, replaces = "frost_nova",
	name = "Frostbind",
	description = "Frost Nova is cast at the pointed hostile up to 20 m " ..
		"away and roots everything within 3 / 4 / 5 m of the target.",
	effects = {frost_nova_ranged = {3, 4, 5}},
})
grug_classes.register_talent({
	id = "rimebite", tree = "rime", chain = "frost", tier = 4,
	capstone = true,
	name = "Rimebite",
	description = "Every root Frost Nova applies also deals " ..
		"5 + floor(spell power / 2) on application.",
	effects = {control_damage_add = {5}},
})
grug_classes.register_talent({
	id = "cold_focus", tree = "rime", chain = "ward", tier = 1,
	name = "Cold Focus",
	description = "In-combat mana regeneration 0.5%/s becomes " ..
		"0.6 / 0.7 / 0.8 / 0.9 / 1.0 %/s.",
	effects = {combat_mana_regen_add = {0.1, 0.2, 0.3, 0.4, 0.5}},
})
grug_classes.register_talent({
	id = "quick_step", tree = "rime", chain = "ward", tier = 2,
	name = "Quick Step",
	description = "Blink cooldown 15 s becomes 13.5 / 12 / 10.5 / 9 s.",
	effects = {blink_cooldown_sub = {1.5, 3, 4.5, 6}},
})
grug_classes.register_talent({
	id = "glacial_ward", tree = "rime", chain = "ward", tier = 3,
	keystone = true, ability = "glacial_ward",
	name = "Glacial Ward",
	description = "New skill: 10 mana, 30 s cooldown, self; absorbs " ..
		"10 / 15 / 20 + 2x spell power for 10 s.",
	effects = {glacial_ward_absorb = {10, 15, 20}},
})
grug_classes.register_talent({
	id = "far_step", tree = "rime", chain = "ward", tier = 4,
	name = "Far Step",
	description = "Blink's distance 10 m becomes 12 / 14 / 16 m.",
	effects = {blink_distance_add = {2, 4, 6}},
})

grug_classes.register_tree({
	id = "mercy", class = "priest", name = "Mercy",
	description = "Keeping others up.",
	chains = {"balm", "aegis"},
	capstone_chain = "balm",
})

grug_classes.register_talent({
	id = "gentle_hand", tree = "mercy", chain = "balm", tier = 1,
	name = "Gentle Hand",
	description = "Flash Heal heals +1 per rank.",
	effects = {flash_heal_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "quiet_steps", tree = "mercy", chain = "balm", tier = 2,
	name = "Quiet Steps",
	description = "Heal threat factor 0.5 becomes 0.45 / 0.4 / 0.35 / 0.3.",
	effects = {heal_threat_factor_sub = {0.05, 0.1, 0.15, 0.2}},
})
grug_classes.register_talent({
	id = "renew", tree = "mercy", chain = "balm", tier = 3,
	keystone = true, ability = "renew",
	name = "Renew",
	description = "New skill: the shipped heal over time (6 mana, 8 s " ..
		"cooldown, 3 + spell power every 3 s for 12 s). Ranks 2 and 3 " ..
		"raise the tick to 4 and 5 + spell power.",
	effects = {renew_tick_add = {0, 1, 2}},
})
grug_classes.register_talent({
	id = "hearten", tree = "mercy", chain = "balm", tier = 4,
	capstone = true, replaces = "flash_heal",
	name = "Hearten",
	description = "Flash Heal also heals every other ally within 8 m for " ..
		"65% of the amount.",
	effects = {flash_heal_splash = {65}},
})
grug_classes.register_talent({
	id = "warding_faith", tree = "mercy", chain = "aegis", tier = 1,
	name = "Warding Faith",
	description = "Power Word: Shield absorbs +1 per rank.",
	effects = {shield_absorb_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "deep_reserve", tree = "mercy", chain = "aegis", tier = 2,
	name = "Deep Reserve",
	description = "Maximum mana +3% per rank.",
	effects = {max_mana_percent_add = {3, 6, 9, 12}},
})
grug_classes.register_talent({
	id = "turn_aside", tree = "mercy", chain = "aegis", tier = 3,
	keystone = true, replaces = "power_word_shield", window = true,
	name = "Turn Aside",
	description = "While the shield holds, its target's dodge chance is " ..
		"+10 / 15 / 20 percentage points, inside the 30% cap.",
	effects = {dodge_chance_window = {10, 15, 20}},
})
grug_classes.register_talent({
	id = "second_skin", tree = "mercy", chain = "aegis", tier = 4,
	name = "Second Skin",
	description = "Power Word: Shield lasts 15 s -> 18 / 21 / 24 s.",
	effects = {shield_duration_add = {3, 6, 9}},
})

grug_classes.register_tree({
	id = "reckoning", class = "priest", name = "Reckoning",
	description = "Solo damage and self-sufficiency.",
	chains = {"word", "wrath"},
	capstone_chain = "word",
})

grug_classes.register_talent({
	id = "sharpened_word", tree = "reckoning", chain = "word", tier = 1,
	name = "Sharpened Word",
	description = "Smite deals +1 per rank.",
	effects = {smite_damage_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "swift_word", tree = "reckoning", chain = "word", tier = 2,
	name = "Swift Word",
	description = "Smite cooldown 2 s becomes 1.85 / 1.7 / 1.55 / 1.4 s.",
	effects = {smite_cooldown_sub = {0.15, 0.3, 0.45, 0.6}},
})
grug_classes.register_talent({
	id = "word_of_ruin", tree = "reckoning", chain = "word", tier = 3,
	keystone = true, ability = "word_of_ruin",
	name = "Word of Ruin",
	description = "New skill: 8 mana, 12 s cooldown, 20 m; " ..
		"6 / 8 / 10 + spell power damage, healing you for 50% of it.",
	effects = {word_of_ruin_damage = {6, 8, 10}},
})
grug_classes.register_talent({
	id = "last_word", tree = "reckoning", chain = "word", tier = 4,
	capstone = true, window = true,
	name = "Last Word",
	description = "Below 25% health, Word of Ruin's drain heals for 150% " ..
		"of the damage dealt. 8 s per trigger, 180 s cooldown.",
	effects = {drain_ratio_override = {150}},
})
grug_classes.register_talent({
	id = "hard_faith", tree = "reckoning", chain = "wrath", tier = 1,
	name = "Hard Faith",
	description = "+1 percentage point crit chance per rank.",
	effects = {crit_chance_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "warded_wrath", tree = "reckoning", chain = "wrath", tier = 2,
	name = "Warded Wrath",
	description = "While you carry an absorb shield, Smite deals " ..
		"+1 / 2 / 3 / 4.",
	effects = {smite_damage_while_shielded_add = {1, 2, 3, 4}},
})
grug_classes.register_talent({
	id = "recompense", tree = "reckoning", chain = "wrath", tier = 3,
	keystone = true, replaces = "smite",
	name = "Recompense",
	description = "Smite costs 6 mana instead of 4 and grants an absorb of " ..
		"6 / 9 / 12 + spell power on every landed cast.",
	effects = {smite_absorb = {6, 9, 12}},
})
grug_classes.register_talent({
	id = "hardened", tree = "reckoning", chain = "wrath", tier = 4,
	name = "Hardened",
	description = "Maximum health +4 per rank.",
	effects = {max_hp_add = {4, 8, 12}},
})

grug_classes.audit_talents()

--
-- Runtime state. One parsed cache per online player (the pattern of
-- grug_abilities' runtime tables) plus the timed-window table of §3.2, which
-- is the single place a window lives. Both are cleared on leave; the windows
-- additionally on death and on respec (§3.7 group 7 -- and those are the only
-- three lifecycle events left, since ruling 20 removed the class change).
--

local cache = {} -- player name -> {ranks, tree_points, spent, static, windowed}
local windows = {} -- player name -> {talent id -> expiry in us}

function grug_classes.talent_points_total(player)
	return math.floor(grug_xp.get_level(player)
		/ grug_classes.TALENT_LEVELS_PER_POINT)
end

-- Trees of a class, in registration order. Nil class = no trees.
function grug_classes.trees_of_class(class_id)
	local list = {}
	for _, tree_id in ipairs(grug_classes.tree_ids) do
		local tree = grug_classes.registered_trees[tree_id]
		if tree.class == class_id then
			list[#list + 1] = tree
		end
	end
	return list
end

-- Does this talent belong to this class? A hand-edited meta string that gives
-- a Warrior a Mage talent is exactly as invalid as an unknown id.
local function talent_of_class(def, class_id)
	return class_id ~= nil and def.class == class_id
end

-- Drop every rank whose tier gate or hard chain is unsatisfied, together with
-- everything below it in its chain. Dropping only ever lowers a tree's point
-- total, so the loop shrinks monotonically and terminates.
--
-- The gate compares "points in the tree MINUS this talent's own ranks"
-- against the tier gate, which is the order-independent form of "the points
-- already spent when its first rank was bought": a legal build satisfies it
-- at every rank, and a forged one that skipped the gate does not.
local function enforce_gates(ranks)
	local talents = grug_classes.registered_talents
	local gates = grug_classes.TALENT_TIER_GATES
	while true do
		local points = {}
		for id, rank in pairs(ranks) do
			local def = talents[id]
			points[def.tree] = (points[def.tree] or 0) + rank
		end
		local drop = nil
		for _, id in ipairs(grug_classes.talent_ids) do
			local rank = ranks[id]
			if rank then
				local def = talents[id]
				local ok = (points[def.tree] or 0) - rank >= gates[def.tier]
				if ok and def.tier > 1 then
					local above = talent_above(def)
					ok = above ~= nil and (ranks[above.id] or 0) >= above.ranks
				end
				if not ok then
					drop = drop or {}
					drop[#drop + 1] = id
				end
			end
		end
		if not drop then
			return
		end
		for _, id in ipairs(drop) do
			ranks[id] = nil
		end
	end
end

-- Total spent, and the per-tree totals.
local function totals(ranks)
	local spent, tree_points = 0, {}
	for id, rank in pairs(ranks) do
		local def = grug_classes.registered_talents[id]
		spent = spent + rank
		tree_points[def.tree] = (tree_points[def.tree] or 0) + rank
	end
	return spent, tree_points
end

-- The read path VALIDATES, it does not trust (§3.3). Unknown ids are dropped,
-- ranks are clamped to the talent's own rank count, a rank whose gate or hard
-- chain is unsatisfied is dropped with everything below it in its chain, and
-- the total is clamped to floor(level / 2) by giving back the deepest ranks
-- first. A hand-edited meta string cannot buy a capstone at level 4.
local function parse(player)
	local class_id = grug_classes.get_class(player)
	local raw = player:get_meta():get_string(META_TALENTS) or ""
	local ranks = {}
	for id, value in raw:gmatch("(%a[%w_]*)=(%-?%d+)") do
		local def = grug_classes.registered_talents[id]
		if def and talent_of_class(def, class_id) then
			local rank = math.floor(tonumber(value) or 0)
			if rank > def.ranks then
				rank = def.ranks
			end
			if rank > 0 then
				ranks[id] = rank
			end
		end
	end
	enforce_gates(ranks)
	local budget = grug_classes.talent_points_total(player)
	local spent = totals(ranks)
	while spent > budget do
		-- Deepest tier first, latest registration first inside a tier: the
		-- refund order has to be a total order or two servers disagree about
		-- the same forged string.
		local worst = nil
		for _, id in ipairs(grug_classes.talent_ids) do
			if ranks[id] then
				local def = grug_classes.registered_talents[id]
				if not worst or def.tier >= worst.tier then
					worst = def
				end
			end
		end
		if not worst then
			break
		end
		ranks[worst.id] = ranks[worst.id] - 1
		if ranks[worst.id] <= 0 then
			ranks[worst.id] = nil
		end
		enforce_gates(ranks)
		spent = totals(ranks)
	end
	local total_spent, tree_points = totals(ranks)
	-- Pre-summed bonuses, so the consumers on the damage pipeline pay one
	-- table index. Windowed talents are kept apart: their contribution
	-- depends on a clock, so it cannot live in a cached sum.
	local static, windowed = {}, {}
	for id, rank in pairs(ranks) do
		local def = grug_classes.registered_talents[id]
		if def.window then
			windowed[#windowed + 1] = def
		else
			for key, values in pairs(def.effects) do
				static[key] = (static[key] or 0) + values[rank]
			end
		end
	end
	return {
		ranks = ranks,
		spent = total_spent,
		tree_points = tree_points,
		static = static,
		windowed = windowed,
	}
end

local function state(player)
	local name = player:get_player_name()
	local entry = cache[name]
	if not entry then
		entry = parse(player)
		cache[name] = entry
	end
	return entry
end

function grug_classes.invalidate_talents(player)
	cache[player:get_player_name()] = nil
end

local function serialize(ranks)
	local parts = {}
	for _, id in ipairs(grug_classes.talent_ids) do
		local rank = ranks[id]
		if rank and rank > 0 then
			parts[#parts + 1] = id .. "=" .. rank
		end
	end
	return table.concat(parts, ",")
end

grug_classes.serialize_talents = serialize

--
-- Timed windows (§3.2). A window key contributes only while its talent's
-- window runs; get_talent_bonus returns 0 for it otherwise, so a consumer
-- needs no second accessor and no new mechanism.
--

function grug_classes.start_talent_window(player, talent_id, duration)
	local def = grug_classes.registered_talents[talent_id]
	if not def or not duration or duration <= 0 then
		return false
	end
	local name = player:get_player_name()
	windows[name] = windows[name] or {}
	windows[name][talent_id] = core.get_us_time() + duration * 1e6
	return true
end

function grug_classes.talent_window_active(player, talent_id)
	local per_player = windows[player:get_player_name()]
	local expiry = per_player and per_player[talent_id]
	if not expiry then
		return false
	end
	if core.get_us_time() > expiry then
		per_player[talent_id] = nil
		return false
	end
	return true
end

function grug_classes.clear_talent_windows(player)
	windows[player:get_player_name()] = nil
end

--
-- The two accessors every consumer reads (§3.2). get_talent_bonus is the
-- deliberate twin of get_race_perk, down to the grug_core stub override at
-- the bottom of this file.
--

-- Summed bonus of this key over the player's ranked talents; 0 when none.
function grug_classes.get_talent_bonus(player, key)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	local entry = state(player)
	local total = entry.static[key] or 0
	if WINDOW_KEYS[key] then
		for _, def in ipairs(entry.windowed) do
			local values = def.effects[key]
			if values and grug_classes.talent_window_active(player, def.id) then
				total = total + values[entry.ranks[def.id]]
			end
		end
	end
	return total
end

-- 0..5; used by the kit grant, the gates and the UI, never by a numeric
-- consumer.
function grug_classes.talent_rank(player, talent_id)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	return state(player).ranks[talent_id] or 0
end

function grug_classes.talent_points_spent(player)
	return state(player).spent
end

function grug_classes.talent_points_available(player)
	return grug_classes.talent_points_total(player)
		- grug_classes.talent_points_spent(player)
end

function grug_classes.tree_points(player, tree_id)
	return state(player).tree_points[tree_id] or 0
end

local talents_changed_callbacks = {}

-- func(player) -- called after any change to a character's talents (a spend,
-- a respec, an admin level drop). The mirror of register_on_class_chosen;
-- grug_abilities re-syncs the kit here once lane X3 grants talent abilities.
function grug_classes.register_on_talents_changed(func)
	table.insert(talents_changed_callbacks, func)
end

local function commit(player, ranks)
	player:get_meta():set_string(META_TALENTS, serialize(ranks))
	cache[player:get_player_name()] = nil
	for _, func in ipairs(talents_changed_callbacks) do
		func(player)
	end
end

--
-- Spending, and the refusal reasons the UI shows.
--

-- Returns true, or false plus the reason a point cannot go here.
function grug_classes.can_spend_talent(player, talent_id)
	local def = grug_classes.registered_talents[talent_id]
	if not def then
		return false, "No such talent."
	end
	local class_id = grug_classes.get_class(player)
	if not class_id then
		return false, "You have no class yet."
	end
	if not talent_of_class(def, class_id) then
		return false, def.name .. " belongs to another class."
	end
	if grug_classes.talent_points_available(player) < 1 then
		return false, "No talent points left."
	end
	local rank = grug_classes.talent_rank(player, talent_id)
	if rank >= def.ranks then
		return false, def.name .. " is already at " .. def.ranks .. "/" ..
			def.ranks .. "."
	end
	local tree = grug_classes.registered_trees[def.tree]
	local gate = grug_classes.TALENT_TIER_GATES[def.tier]
	local in_tree = grug_classes.tree_points(player, def.tree) - rank
	if in_tree < gate then
		return false, def.name .. " needs " .. gate .. " points in " ..
			tree.name .. " (you have " .. in_tree .. ")."
	end
	local above = talent_above(def)
	if above and grug_classes.talent_rank(player, above.id) < above.ranks then
		return false, def.name .. " needs " .. above.name .. " at " ..
			above.ranks .. "/" .. above.ranks .. "."
	end
	return true
end

function grug_classes.spend_talent(player, talent_id)
	local ok, reason = grug_classes.can_spend_talent(player, talent_id)
	if not ok then
		return false, reason
	end
	local entry = state(player)
	local ranks = {}
	for id, rank in pairs(entry.ranks) do
		ranks[id] = rank
	end
	ranks[talent_id] = (ranks[talent_id] or 0) + 1
	commit(player, ranks)
	return true
end

-- A respec is a FULL reset (ruling 20): every rank to 0, all points back.
-- The price ledger is lane X4's; this function is the reset itself, and the
-- interim /respec below calls it free.
function grug_classes.respec(player)
	local spent = grug_classes.talent_points_spent(player)
	grug_classes.clear_talent_windows(player)
	commit(player, {})
	return spent
end

--
-- Level changes (§3.6 and ruling 20's last bullet). Called from the existing
-- grug_xp level-change registration in stats.lua, so the order against
-- apply_stats is fixed rather than incidental.
--
-- An admin level drop (/xp can lower a level) would otherwise leave more
-- ranks spent than floor(level / 2) allows. Rather than blocking spends or
-- refunding cheapest-first, the talent state is wiped and every point
-- returned -- free, because /xp is an admin command and the simplest correct
-- behaviour wins.
function grug_classes.on_level_change_talents(player, old_level, new_level)
	cache[player:get_player_name()] = nil
	if old_level == nil then
		return
	end
	if new_level < old_level then
		local spent = grug_classes.talent_points_spent(player)
		if spent > 0 then
			grug_classes.respec(player)
			core.chat_send_player(player:get_player_name(), core.colorize(
				"#ffd100", "Your level dropped: all " .. spent ..
				" talent points were returned."))
		end
		return
	end
	-- old_level is nil on join (grug_xp/init.lua:32-33). Arithmetic on nil
	-- here would error on every single join, which is why the guard above is
	-- not optional.
	local per = grug_classes.TALENT_LEVELS_PER_POINT
	if math.floor(new_level / per) > math.floor(old_level / per) then
		local left = grug_classes.talent_points_available(player)
		core.chat_send_player(player:get_player_name(), core.colorize("#7ae08a",
			"Talent point earned - " .. left ..
			" to spend. Type /talents to see your trees."))
	end
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	cache[name] = nil
	windows[name] = nil
end)

core.register_on_dieplayer(function(player)
	grug_classes.clear_talent_windows(player)
end)

--
-- INTERIM chat interface (lane X1/X2). Lane X4 ships the sfinv Talents page
-- of §3.5 and REMOVES these three commands; until then they are the only way
-- to play a talent, so they are player-reachable rather than admin-only and
-- act on the caller's own character alone.
--

local function tree_line(player, tree)
	return ("%s [%d]"):format(tree.name, grug_classes.tree_points(player, tree.id))
end

local function talent_line(player, def)
	local rank = grug_classes.talent_rank(player, def.id)
	local mark = " "
	if def.keystone then
		mark = "*"
	elseif def.capstone then
		mark = "!"
	end
	local line = ("  %s %-16s %d/%d  %s"):format(mark, def.id, rank,
		def.ranks, def.name)
	if rank < def.ranks then
		local ok, reason = grug_classes.can_spend_talent(player, def.id)
		if not ok then
			line = line .. "  (" .. reason .. ")"
		end
	end
	return line
end

core.register_chatcommand("talents", {
	params = "",
	description = "Show your talent trees (interim until the WP11 UI lands)",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "You must be online."
		end
		local class_id = grug_classes.get_class(player)
		if not class_id then
			return false, "You have no class yet."
		end
		local lines = {
			("%s - %d talent points, %d spent, %d left"):format(
				grug_classes.registered_classes[class_id].name,
				grug_classes.talent_points_total(player),
				grug_classes.talent_points_spent(player),
				grug_classes.talent_points_available(player)),
		}
		for _, tree in ipairs(grug_classes.trees_of_class(class_id)) do
			lines[#lines + 1] = tree_line(player, tree)
			for _, chain in ipairs(tree.chains) do
				for _, def in ipairs(tree.talents) do
					if def.chain == chain then
						lines[#lines + 1] = talent_line(player, def)
					end
				end
			end
		end
		lines[#lines + 1] =
			"* keystone, ! capstone. /talent <id> spends a point, /respec resets."
		return true, table.concat(lines, "\n")
	end,
})

core.register_chatcommand("talent", {
	params = "<id>",
	description = "Spend one talent point (interim until the WP11 UI lands)",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "You must be online."
		end
		local id = param:match("^%s*(%S+)%s*$")
		if not id then
			return false, "Usage: /talent <id> (see /talents)."
		end
		local ok, reason = grug_classes.spend_talent(player, id)
		if not ok then
			return false, reason
		end
		local def = grug_classes.registered_talents[id]
		return true, ("%s is now %d/%d. %d points left. %s"):format(def.name,
			grug_classes.talent_rank(player, id), def.ranks,
			grug_classes.talent_points_available(player), def.description)
	end,
})

core.register_chatcommand("respec", {
	params = "",
	description = "Reset every talent and take all points back (free for now)",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "You must be online."
		end
		local spent = grug_classes.respec(player)
		return true, ("Talents reset; %d points returned. " ..
			"(The respec price lands with the talent UI.)"):format(spent)
	end,
})

-- Stub override (same pattern as grug_core.get_race_perk): mods below
-- grug_classes in the dependency graph read talents through grug_core.
grug_core.get_talent_bonus = grug_classes.get_talent_bonus
