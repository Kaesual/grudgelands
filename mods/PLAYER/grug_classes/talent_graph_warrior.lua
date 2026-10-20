-- The Warrior's talent graph (Round 53, round K): its vocabulary and its two
-- trees, Bulwark and Ruin, from docs/planning/class-redesign/node-list.md
-- under the user's decisions of 2026-10-20 (round53-plan.md §2). One such
-- file per class; talents.lua loads the four and audits them
-- (talent_graph.lua).
--
-- The structure, checked field by field at load:
--   register_class_vocabulary(class, {keys, params}): `keys` are the class's
--     own effect keys, {key = "the code that reads it"}; `params` the tags
--     and ability ids its family keys ("<family>:<param>",
--     graph.KEY_FAMILIES) may name. Shared keys (graph.SHARED_KEYS) need no
--     entry.
--   register_tree{id, class, name, ranks (the sum of its nodes' ranks),
--     description (the tab's tooltip), example (a legal 30-point order in
--     node codes, which the audit buys), nodes}. A node:
--       id          "<tree>_<name>"; its icon is grug_classes_talent_<name>.png
--                   (a granting node shows its skill's icon instead);
--       code        the node list's id (the docs' name, never read by code);
--       type        modifier, window, unlock, transform or ultimate;
--       ability     the ability an unlock, transform or ultimate grants; the
--                   ability sets `talent = "<node id>"` (round53-plan.md §3);
--       ranks, gate (points in the tree before its first rank), col (1-5),
--       requires    node ids that each need one rank;
--       effects     {key = {value per rank}}, read by get_talent_bonus;
--       description player text: no unit letters, directions or places.
--
-- The id bulwark_unbroken keeps the old Unbroken passive
-- (grug_quality/init.lua, talent_rank(player, "unbroken")) inert because of
-- its prefix; round53-plan.md §3: do not rename it.

local graph = grug_classes.graph

-- The class keys hold a node's per-rank value in the unit its consumer
-- multiplies: S (a Strike hit, the weapon's damage plus the melee bonus,
-- before the one scaling pass), % of the base pool (times the support
-- factor), percent or rage.
graph.register_class_vocabulary("warrior", {
	keys = {
		rage_per_swing_add = "grug_abilities/init.lua the swing rage sites",
		retort_bonus_add = "kits_warrior.lua Retort: S on its readied swing",
		retort_heal_percent = "kits_warrior.lua Retort: % of the base pool healed",
		hold_ground_absorb_add = "kits_warrior.lua Hold Ground: % of the base pool",
		charge_slow_percent = "charge.lua arrival: the slow after the stun",
		charge_rage_add = "charge.lua arrival: rage",
		mighty_blow_unit_add = "kits_warrior.lua Mighty Blow and Broadstroke: S",
		finisher_unit_add = "kits_warrior.lua Mighty Blow and Broadstroke: S below 30 % health",
		mighty_blow_cost_sub = "kits_warrior.lua Mighty Blow and Broadstroke: rage off",
		broadstroke_secondary_add = "kits_warrior.lua Broadstroke: S on each other target",
	},
	params = {"strike", "charge", "retort", "hold_ground", "taunt", "bellow",
		"unbroken", "mighty_blow", "hamstring", "broadstroke", "ruination"},
})

graph.register_tree({
	id = "bulwark", class = "warrior", name = "Bulwark", ranks = 33,
	description = "Guard: Retort, Hold Ground, Taunt, Bellow and the Unbroken ultimate.",
	example = "B1 B2x2 B4 B2x2 B5x3 B3x3 B8x3 B6x3 B10x2 B12 B10 B14x3 B7 B9 B13x3",
	nodes = {
		{id = "bulwark_retort", code = "B1", name = "Retort", type = "transform",
			ability = "retort", ranks = 1, gate = 0, col = 2,
			description = "Strike becomes Retort: when a hostile hit takes your health, your " ..
				"next swing within 4 s deals +25 % of a Strike hit; 6 s internal cooldown."},
		{id = "bulwark_ironbound", code = "B2", name = "Ironbound", type = "modifier",
			ranks = 4, gate = 0, col = 3, effects = {armor_percent_add = {4, 8, 12, 16}},
			description = "Armor +4/8/12/16 % of the level's armor constant."},
		{id = "bulwark_weathered", code = "B3", name = "Weathered", type = "modifier",
			ranks = 3, gate = 0, col = 4, effects = {max_hp_percent_add = {3, 6, 9}},
			description = "Max health +3/6/9 %."},
		{id = "bulwark_hold_ground", code = "B4", name = "Hold Ground", type = "unlock",
			ability = "hold_ground", ranks = 1, gate = 2, col = 3,
			description = "Unlocks Hold Ground: a shield of 12 % of a base health pool for " ..
				"5 s; 25 rage, 24 s cooldown."},
		{id = "bulwark_measured_answer", code = "B5", name = "Measured Answer",
			type = "modifier", ranks = 3, gate = 6, col = 1, requires = {"bulwark_retort"},
			effects = {retort_bonus_add = {0.05, 0.1, 0.15}},
			description = "Retort's bonus rises to 30/35/40 % of a Strike hit."},
		{id = "bulwark_turn_the_edge", code = "B6", name = "Turn the Edge", type = "modifier",
			ranks = 3, gate = 6, col = 4, effects = {dodge_chance_add = {2, 4, 6}},
			description = "Dodge chance +2/4/6 %."},
		{id = "bulwark_taunt", code = "B7", name = "Taunt", type = "unlock", ability = "taunt",
			ranks = 1, gate = 6, col = 5,
			description = "Unlocks Taunt: one enemy within 8 m attacks you for 3 s; free, " ..
				"8 s cooldown."},
		{id = "bulwark_recover", code = "B8", name = "Recover", type = "modifier",
			ranks = 3, gate = 10, col = 2, requires = {"bulwark_retort"},
			effects = {retort_heal_percent = {0.7, 1.3, 2}},
			description = "A landed Retort heals 0.7/1.3/2.0 % of a base health pool; " ..
				"never critical."},
		{id = "bulwark_bellow", code = "B9", name = "Bellow", type = "transform",
			ability = "bellow", ranks = 1, gate = 12, col = 5, requires = {"bulwark_taunt"},
			description = "Taunt becomes Bellow: every enemy within 6 m around you; the " ..
				"same cooldown."},
		{id = "bulwark_layered_guard", code = "B10", name = "Layered Guard", type = "modifier",
			ranks = 3, gate = 12, col = 4, requires = {"bulwark_hold_ground"},
			effects = {hold_ground_absorb_add = {3, 6, 9}},
			description = "Hold Ground's shield +3/6/9 % of a base health pool."},
		{id = "bulwark_halt", code = "B11", name = "Halt", type = "modifier",
			ranks = 3, gate = 12, col = 1, effects = {charge_slow_percent = {20, 25, 30}},
			description = "Charge's arrival also slows by 20/25/30 % for the stun and 2 s more."},
		{id = "bulwark_unbroken", code = "B12", name = "Unbroken", type = "ultimate",
			ability = "unbroken", ranks = 1, gate = 20, col = 3, requires = {"bulwark_hold_ground"},
			description = "Unlocks Unbroken: for 8 s, armor +50 % of the level's armor " ..
				"constant and a shield of 15 % of a base health pool; 25 rage, 60 s cooldown."},
		{id = "bulwark_enduring_stand", code = "B13", name = "Enduring Stand",
			type = "modifier", ranks = 3, gate = 20, col = 4, requires = {"bulwark_unbroken"},
			effects = {["duration_add:unbroken"] = {0.5, 1, 1.5}},
			description = "Unbroken lasts +0.5/1.0/1.5 s."},
		{id = "bulwark_gather_yourself", code = "B14", name = "Gather Yourself",
			type = "modifier", ranks = 3, gate = 16, col = 2, requires = {"bulwark_hold_ground"},
			effects = {["cooldown_sub:hold_ground"] = {1, 2, 3}},
			description = "Hold Ground's cooldown -1/2/3 s."},
	},
})

graph.register_tree({
	id = "ruin", class = "warrior", name = "Ruin", ranks = 33,
	description = "Rage damage: Mighty Blow, Hamstring, Broadstroke and the Ruination " ..
		"ultimate.",
	example = "U1 U2x4 U3 U7 U5x3 U8x3 U10x3 U11x3 U4 U12 U3x2 U6x3 U9x3 U14",
	nodes = {
		{id = "ruin_mighty_blow", code = "U1", name = "Mighty Blow", type = "unlock",
			ability = "mighty_blow", ranks = 1, gate = 0, col = 3,
			description = "Unlocks Mighty Blow: a swing for 145 % of a Strike hit when you " ..
				"have 25 rage, else a plain swing; no cooldown of its own."},
		{id = "ruin_heavy_hand", code = "U2", name = "Heavy Hand", type = "modifier",
			ranks = 4, gate = 0, col = 4, requires = {"ruin_mighty_blow"},
			effects = {mighty_blow_unit_add = {0.05, 0.1, 0.15, 0.2}},
			description = "Mighty Blow and Broadstroke hit +5/10/15/20 % of a Strike hit."},
		{id = "ruin_stoke", code = "U3", name = "Stoke", type = "modifier",
			ranks = 3, gate = 0, col = 2, effects = {rage_per_swing_add = {1, 2, 3}},
			description = "+1/2/3 rage per full swing."},
		{id = "ruin_hamstring", code = "U4", name = "Hamstring", type = "unlock",
			ability = "hamstring", ranks = 1, gate = 2, col = 5,
			description = "Unlocks Hamstring: a swing for a full Strike hit that slows by " ..
				"35 % for 3 s; 10 rage, recharges in 8 s."},
		{id = "ruin_keen_edge", code = "U5", name = "Keen Edge", type = "modifier",
			ranks = 3, gate = 6, col = 1, effects = {crit_chance_add = {2, 4, 6}},
			description = "Critical chance +2/4/6 %."},
		{id = "ruin_onset", code = "U6", name = "Onset", type = "modifier",
			ranks = 3, gate = 6, col = 4, effects = {["cooldown_sub:charge"] = {0.5, 1, 1.5}},
			description = "Charge's cooldown -0.5/1.0/1.5 s."},
		{id = "ruin_broadstroke", code = "U7", name = "Broadstroke", type = "transform",
			ability = "broadstroke", ranks = 1, gate = 6, col = 2, requires = {"ruin_mighty_blow"},
			description = "Mighty Blow becomes Broadstroke: the same hit, and up to 2 others " ..
				"in a 100 degree, 3 m arc take 35 % of a Strike hit, critical hits allowed."},
		{id = "ruin_follow_through", code = "U8", name = "Follow Through", type = "modifier",
			ranks = 3, gate = 10, col = 2, requires = {"ruin_broadstroke"},
			effects = {broadstroke_secondary_add = {0.05, 0.1, 0.15}},
			description = "Broadstroke's other targets take 40/45/50 % of a Strike hit."},
		{id = "ruin_clean_cut", code = "U9", name = "Clean Cut", type = "modifier",
			ranks = 3, gate = 10, col = 5, requires = {"ruin_hamstring"},
			effects = {["duration_add:hamstring"] = {0.5, 1, 1.5}},
			description = "Hamstring's slow lasts +0.5/1.0/1.5 s."},
		{id = "ruin_finisher", code = "U10", name = "Finisher", type = "modifier",
			ranks = 3, gate = 12, col = 4, requires = {"ruin_mighty_blow"},
			effects = {finisher_unit_add = {0.08, 0.16, 0.24}},
			description = "Mighty Blow and Broadstroke hit +8/16/24 % of a Strike hit " ..
				"against a target below 30 % health."},
		{id = "ruin_relentless", code = "U11", name = "Relentless", type = "modifier",
			ranks = 3, gate = 16, col = 2, requires = {"ruin_mighty_blow"},
			effects = {mighty_blow_cost_sub = {1, 2, 3}},
			description = "Mighty Blow and Broadstroke cost 1/2/3 rage less."},
		{id = "ruin_ruination", code = "U12", name = "Ruination", type = "ultimate",
			ability = "ruination", ranks = 1, gate = 20, col = 3, requires = {"ruin_mighty_blow"},
			description = "Unlocks Ruination: for 8 s your swings deal +15 % damage and each " ..
				"landed swing gives 2 more rage; 20 rage, 60 s cooldown."},
		{id = "ruin_long_fury", code = "U13", name = "Long Fury", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"ruin_ruination"},
			effects = {["duration_add:ruination"] = {0.5, 1, 1.5}},
			description = "Ruination lasts +0.5/1.0/1.5 s."},
		{id = "ruin_reach_the_fight", code = "U14", name = "Reach the Fight", type = "modifier",
			ranks = 1, gate = 12, col = 1, effects = {charge_rage_add = {5}},
			description = "Charge's arrival gives 5 more rage."},
	},
})
