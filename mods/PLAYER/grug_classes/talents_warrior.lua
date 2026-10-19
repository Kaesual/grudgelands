-- Warrior talent trees (docs/design/skill_trees.md sections 2.1 and 2.2).

grug_classes.register_tree({
	id = "bulwark", class = "warrior", name = "Bulwark",
	description = "Take hits and hold attention.",
	chains = {"wall", "anvil"},
	capstone_chain = "wall",
})

grug_classes.register_talent({
	id = "ironbound", tree = "bulwark", chain = "wall", tier = 1,
	name = "Ironbound",
	description = "Armor rating +3% of the armor constant per rank " ..
		"(it grows with your level).",
	effects = {armor_percent_add = {3, 6, 9, 12, 15}},
})
grug_classes.register_talent({
	id = "weathered", tree = "bulwark", chain = "wall", tier = 2,
	name = "Weathered",
	description = "Maximum health +2.5% of your class base pool per rank.",
	effects = {max_hp_percent_add = {2.5, 5, 7.5, 10}},
})
grug_classes.register_talent({
	id = "hold_ground", tree = "bulwark", chain = "wall", tier = 3,
	keystone = true, ability = "hold_ground",
	name = "Hold Ground",
	description = "New skill: 25 rage, absorbs 20/30/40% of the neutral " ..
		"base pool for 8 s, and for those 8 s you cannot be rooted or slowed. " ..
		"60 s cooldown.",
	-- NOT `window = true`, deliberately. skill_trees.md §3.2 counts Hold
	-- Ground among the timed windows, but only its root/slow IMMUNITY is
	-- windowed; the absorb amount below is read once at cast time and must
	-- answer whenever X3 asks. Marking the def windowed would make
	-- get_talent_bonus return 0 for the amount outside the window, which is
	-- the opposite of what the cast needs. X3 owns the immunity, and it
	-- belongs on the §3.9 movement aggregator's own immunity flag rather
	-- than on a talent effect key.
	effects = {hold_ground_absorb = {20, 30, 40}},
})
grug_classes.register_talent({
	id = "unbroken", tree = "bulwark", chain = "wall", tier = 4,
	capstone = true, window = true,
	name = "Unbroken",
	description = "+65% total armor rating, which counts most against " ..
		"stronger foes (the 70% reduction cap holds). Once every 180 s, a hit that " ..
		"would take you below 20% health grants armor rating +33% of the " ..
		"armor constant for 8 s.",
	effects = {armor_rating_add_low_hp = {33}},
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
		"x1.6 / 1.7 / 1.8 / 1.9 / 2.0.",
	effects = {mighty_blow_multiplier_add = {0.1, 0.2, 0.3, 0.4, 0.5}},
})
grug_classes.register_talent({
	id = "stoke", tree = "ruin", chain = "hammer", tier = 2,
	name = "Stoke",
	description = "+1 rage per landed swing, per rank (base 8), " ..
		"on a 1.0 s weapon; it scales with the weapon's swing time.",
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
	description = "Once every 60 s, a landed Mighty Blow grants 15 s of " ..
		"+20 crit chance with the cap raised to 50%.",
	effects = {crit_chance_add_window = {20}, crit_cap_override = {50}},
})
grug_classes.register_talent({
	id = "keen_edge", tree = "ruin", chain = "lash", tier = 1,
	name = "Keen Edge",
	description = "+2 percentage points crit chance per rank (30% cap holds).",
	effects = {crit_chance_add = {2, 4, 6, 8, 10}},
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
