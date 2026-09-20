-- Scout talent trees (docs/design/skill_trees.md sections 2.7 and 2.8).

grug_classes.register_tree({
	id = "quarry", class = "scout", name = "Quarry",
	description = "Draw strength, range and ammunition control.",
	chains = {"draw", "ranging"},
	capstone_chain = "draw",
})

grug_classes.register_talent({
	id = "strong_draw", tree = "quarry", chain = "draw", tier = 1,
	name = "Strong Draw",
	description = "Loose damage +1 per rank.",
	effects = {loose_damage_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "cold_eye", tree = "quarry", chain = "draw", tier = 2,
	name = "Cold Eye",
	description = "+1 percentage point crit chance per rank.",
	effects = {crit_chance_add = {1, 2, 3, 4}},
})
grug_classes.register_talent({
	id = "twin_shot", tree = "quarry", chain = "draw", tier = 3,
	keystone = true, replaces = "loose",
	name = "Twin Shot",
	description = "A full Loose draw fires two arrows. The second deals " ..
		"50 / 60 / 70% damage and the action costs two arrows.",
	effects = {loose_second_arrow = {50, 60, 70}},
})
grug_classes.register_talent({
	id = "longshot", tree = "quarry", chain = "draw", tier = 4,
	capstone = true, replaces = "loose",
	name = "Longshot",
	description = "Loose reaches 33 m; a hit beyond 25 m deals +4 damage.",
	effects = {loose_range_add = {8}},
})
grug_classes.register_talent({
	id = "quiver", tree = "quarry", chain = "ranging", tier = 1,
	name = "Quiver",
	description = "A successful Loose refunds its arrows 10 / 20 / 30 / " ..
		"40 / 50% of the time.",
	effects = {arrow_refund_chance = {10, 20, 30, 40, 50}},
})
grug_classes.register_talent({
	id = "fletching", tree = "quarry", chain = "ranging", tier = 2,
	name = "Fletching",
	description = "Loose reaches full draw in 0.45 / 0.40 / 0.35 / 0.30 s.",
	effects = {draw_time_sub = {0.05, 0.10, 0.15, 0.20}},
})
grug_classes.register_talent({
	id = "pinning_shot", tree = "quarry", chain = "ranging", tier = 3,
	keystone = true, ability = "pinning_shot",
	name = "Pinning Shot",
	description = "New skill: 12% base mana and one arrow, 30 s cooldown, " ..
		"25 m; roots the target for 2 / 2.5 / 3 s.",
	effects = {pinning_root = {2, 2.5, 3}},
})
grug_classes.register_talent({
	id = "shifting_weight", tree = "quarry", chain = "ranging", tier = 4,
	name = "Shifting Weight",
	description = "+1 percentage point dodge chance per rank.",
	effects = {dodge_chance_add = {1, 2, 3}},
})

grug_classes.register_tree({
	id = "veil", class = "scout", name = "Veil",
	description = "Main-hand blade damage and avoidance.",
	chains = {"blade", "shadow"},
	capstone_chain = "shadow",
})

grug_classes.register_talent({
	id = "fine_edge", tree = "veil", chain = "blade", tier = 1,
	name = "Fine Edge",
	description = "+1 damage per rank on a landed authoritative swing.",
	effects = {melee_damage_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "deep_focus", tree = "veil", chain = "blade", tier = 2,
	name = "Deep Focus",
	description = "Maximum mana +3% per rank.",
	effects = {max_mana_percent_add = {3, 6, 9, 12}},
})
grug_classes.register_talent({
	id = "opening", tree = "veil", chain = "blade", tier = 3,
	keystone = true, ability = "opening",
	name = "Opening",
	description = "New skill: a 15% base-mana swing from behind for " ..
		"220 / 250 / 280% main-hand damage plus melee bonus; 12 s charge.",
	effects = {opening_multiplier = {220, 250, 280}},
})
grug_classes.register_talent({
	id = "follow_through", tree = "veil", chain = "blade", tier = 4,
	name = "Follow Through",
	description = "Opening's charge becomes 10 / 8 / 6 s.",
	effects = {opening_charge_sub = {2, 4, 6}},
})
grug_classes.register_talent({
	id = "light_step", tree = "veil", chain = "shadow", tier = 1,
	name = "Light Step",
	description = "+1 percentage point dodge chance per rank.",
	effects = {dodge_chance_add = {1, 2, 3, 4, 5}},
})
grug_classes.register_talent({
	id = "slip_away", tree = "veil", chain = "shadow", tier = 2,
	name = "Slip Away",
	description = "Sidestep's cooldown becomes 26 / 22 / 18 / 14 s.",
	effects = {sidestep_cooldown_sub = {4, 8, 12, 16}},
})
grug_classes.register_talent({
	id = "shake_loose", tree = "veil", chain = "shadow", tier = 3,
	keystone = true, replaces = "sidestep",
	name = "Shake Loose",
	description = "Sidestep also clears roots and slows and prevents them " ..
		"for its four-second window.",
	effects = {root_slow_immunity = {1, 1, 1}},
})
grug_classes.register_talent({
	id = "untouchable", tree = "veil", chain = "shadow", tier = 4,
	capstone = true, window = true,
	name = "Untouchable",
	description = "Below 30% health, gain 25 dodge chance and raise its cap " ..
		"to 55% for 6 s. 180 s cooldown.",
	effects = {dodge_chance_window = {25}, dodge_cap_override = {55}},
})
