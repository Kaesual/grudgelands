-- Mage talent trees (docs/design/skill_trees.md sections 2.3 and 2.4).

grug_classes.register_tree({
	id = "ember", class = "mage", name = "Ember",
	description = "Fire damage.",
	chains = {"blaze", "cinder"},
	capstone_chain = "blaze",
})

grug_classes.register_talent({
	id = "tinder", tree = "ember", chain = "blaze", tier = 1,
	name = "Tinder",
	description = "Fireball damage +4% of a spell base hit per rank.",
	effects = {fireball_damage_add = {4, 8, 12, 16, 20}},
})
grug_classes.register_talent({
	id = "firebrand", tree = "ember", chain = "blaze", tier = 2,
	name = "Firebrand",
	description = "+2 percentage points crit chance per rank (30% cap holds).",
	effects = {crit_chance_add = {2, 4, 6, 8}},
})
grug_classes.register_talent({
	id = "brand", tree = "ember", chain = "blaze", tier = 3,
	keystone = true, replaces = "fireball",
	name = "Brand",
	description = "Fireball's impact splashes 6 / 9 / 12% of a spell base hit " ..
		"plus half your spell power to every other hostile within 2 m.",
	effects = {fireball_splash = {6, 9, 12}},
})
grug_classes.register_talent({
	id = "whitehot", tree = "ember", chain = "blaze", tier = 4,
	capstone = true, window = true,
	name = "Whitehot",
	description = "Once every 60 s, the first Fireball that crits starts " ..
		"8 s in which Fireball costs 3% instead of 6% base mana and deals " ..
		"+30% of a spell base hit.",
	effects = {whitehot_window = {8}, whitehot_damage = {30}},
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
	description = "New skill: 12% base mana, 10 s cooldown, 20 m; a burst dealing " ..
		"15 / 20 / 25% of a spell base hit plus spell power to every hostile " ..
		"within 3 m of it.",
	effects = {cinderfall_damage = {15, 20, 25}},
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
	description = "Ice Nova's root 4 s becomes 4.2 / 4.4 / 4.6 / 4.8 / 5 s.",
	effects = {ice_nova_root_add = {0.2, 0.4, 0.6, 0.8, 1.0}},
})
grug_classes.register_talent({
	id = "hoarfrost", tree = "rime", chain = "frost", tier = 2,
	name = "Hoarfrost",
	description = "Ice Nova's follow-up slow 3 s becomes 4 / 5 / 6 / 7 s.",
	effects = {ice_nova_slow_add = {1, 2, 3, 4}},
})
grug_classes.register_talent({
	id = "frostbind", tree = "rime", chain = "frost", tier = 3,
	keystone = true, replaces = "ice_nova",
	name = "Frostbind",
	description = "Ice Nova is cast at the pointed hostile up to 20 m " ..
		"away and roots everything within 3 / 4 / 5 m of the target.",
	effects = {ice_nova_ranged = {3, 4, 5}},
})
grug_classes.register_talent({
	id = "rimebite", tree = "rime", chain = "frost", tier = 4,
	capstone = true,
	name = "Rimebite",
	description = "Every root Ice Nova applies also deals 25% of a spell " ..
		"base hit plus half your spell power on application.",
	effects = {control_damage_add = {25}},
})
grug_classes.register_talent({
	id = "cold_focus", tree = "rime", chain = "ward", tier = 1,
	name = "Cold Focus",
	description = "In-combat mana regeneration is increased by " ..
		"40 / 80 / 120 / 160 / 200%.",
	effects = {combat_mana_regen_add = {0.2, 0.4, 0.6, 0.8, 1.0}},
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
	description = "New skill: 10% base mana, 30 s cooldown, self; absorbs " ..
		"10% / 15% / 20% of the base pool, raised by Intelligence from gear, " ..
		"for 10 s.",
	effects = {glacial_ward_absorb = {10, 15, 20}},
})
grug_classes.register_talent({
	id = "far_step", tree = "rime", chain = "ward", tier = 4,
	name = "Far Step",
	description = "Blink's distance 10 m becomes 12 / 14 / 16 m.",
	effects = {blink_distance_add = {2, 4, 6}},
})
