-- Priest talent trees (docs/design/skill_trees.md sections 2.5 and 2.6).

grug_classes.register_tree({
	id = "mercy", class = "priest", name = "Mercy",
	description = "Keeping others up.",
	chains = {"balm", "aegis"},
	capstone_chain = "balm",
})

grug_classes.register_talent({
	id = "gentle_hand", tree = "mercy", chain = "balm", tier = 1,
	name = "Gentle Hand",
	description = "Heal gains +1 base-pool percentage point per rank.",
	effects = {heal_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "quiet_steps", tree = "mercy", chain = "balm", tier = 2,
	name = "Quiet Steps",
	description = "Heal threat factor 0.5 becomes 0.45 / 0.4 / 0.35 / 0.3.",
	effects = {heal_threat_factor_sub = {0.05, 0.1, 0.15, 0.2}},
})
grug_classes.register_talent({
	id = "mend", tree = "mercy", chain = "balm", tier = 3,
	keystone = true, ability = "mend",
	-- The skill's only display name: kits.lua's Mend ability reads it.
	name = "Mend",
	description = "New skill: 6% base mana, 8 s cooldown, healing 8% " ..
		"of the base pool every 3 s for 12 s. Ranks 2 and 3 raise the " ..
		"tick to 9% and 10%.",
	effects = {mend_tick_add = {0, 1, 2}},
})
grug_classes.register_talent({
	id = "hearten", tree = "mercy", chain = "balm", tier = 4,
	capstone = true, replaces = "heal",
	name = "Hearten",
	description = "Heal also heals every other ally within 8 m for " ..
		"65% of the amount.",
	effects = {heal_splash = {65}},
})
grug_classes.register_talent({
	id = "warding_faith", tree = "mercy", chain = "aegis", tier = 1,
	name = "Warding Faith",
	description = "The Shield spell gains +1 base-pool percentage point per rank.",
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
	keystone = true, replaces = "shield_spell", window = true,
	name = "Turn Aside",
	description = "While the shield holds, its target's dodge chance is " ..
		"+10 / 15 / 20 percentage points, inside the 30% cap.",
	effects = {dodge_chance_window = {10, 15, 20}},
})
grug_classes.register_talent({
	id = "second_skin", tree = "mercy", chain = "aegis", tier = 4,
	name = "Second Skin",
	description = "The Shield spell's cooldown 10 s becomes 9 / 8 / 7 s.",
	effects = {shield_cooldown_sub = {1, 2, 3}},
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
	description = "Smite damage +4% of a spell base hit per rank.",
	effects = {smite_damage_add = {4, 8, 12, 16, 20}},
})
grug_classes.register_talent({
	id = "swift_word", tree = "reckoning", chain = "word", tier = 2,
	name = "Swift Word",
	description = "Smite cooldown 2 s becomes 1.9 / 1.8 / 1.7 / 1.6 s.",
	effects = {smite_cooldown_sub = {0.1, 0.2, 0.3, 0.4}},
})
grug_classes.register_talent({
	id = "word_of_ruin", tree = "reckoning", chain = "word", tier = 3,
	keystone = true, ability = "word_of_ruin",
	name = "Word of Ruin",
	description = "New skill: 8% base mana, 12 s cooldown, 20 m; " ..
		"18 / 24 / 30% of a spell base hit plus spell power damage, healing you " ..
		"for 50% of it.",
	effects = {word_of_ruin_damage = {18, 24, 30}},
})
grug_classes.register_talent({
	id = "last_word", tree = "reckoning", chain = "word", tier = 4,
	capstone = true, window = true,
	name = "Last Word",
	description = "Below 25% health, Word of Ruin's cooldown resets and its " ..
		"drain heals for 150% of the damage dealt. 12 s per trigger, 180 s " ..
		"cooldown.",
	effects = {drain_ratio_override = {150}},
})
grug_classes.register_talent({
	id = "hard_faith", tree = "reckoning", chain = "wrath", tier = 1,
	name = "Hard Faith",
	description = "+2 percentage points crit chance per rank (30% cap holds).",
	effects = {crit_chance_add = {2, 4, 6, 8, 10}},
})
grug_classes.register_talent({
	id = "warded_wrath", tree = "reckoning", chain = "wrath", tier = 2,
	name = "Warded Wrath",
	description = "While you carry an absorb shield, Smite deals " ..
		"+4 / 8 / 12 / 16% of a spell base hit.",
	effects = {smite_damage_while_shielded_add = {4, 8, 12, 16}},
})
grug_classes.register_talent({
	id = "recompense", tree = "reckoning", chain = "wrath", tier = 3,
	keystone = true, replaces = "smite",
	name = "Recompense",
	description = "Smite costs 6% instead of 5% base mana and, at most once " ..
		"every 6 s, grants an absorb of 6% / 9% / 12% of the base pool, " ..
		"raised by Intelligence from gear.",
	effects = {smite_absorb = {6, 9, 12}},
})
grug_classes.register_talent({
	id = "hardened", tree = "reckoning", chain = "wrath", tier = 4,
	name = "Hardened",
	description = "Maximum health +2% of your class base pool per rank.",
	effects = {max_hp_percent_add = {2, 4, 6}},
})
