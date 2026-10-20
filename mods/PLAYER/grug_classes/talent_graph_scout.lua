-- The Scout's talent graph (Round 53, round K): its vocabulary and its two
-- trees, Quarry and Veil, from docs/planning/class-redesign/node-list.md
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

local graph = grug_classes.graph

graph.register_class_vocabulary("scout", {
	keys = {arrow_refund_chance = "grug_abilities/scout.lua Loose settlement"},
	params = {"bow", "blade", "loose", "sidestep", "sprint", "true_draw", "snare_shot",
		"split_shot", "arrowfall", "bladecraft", "opening", "parry", "flourish",
		"close_dance"},
})

graph.register_tree({
	id = "quarry", class = "scout", name = "Quarry", ranks = 32,
	description = "Bow: True Draw, Snare Shot, Split Shot and the Arrowfall ultimate.",
	example = "Q1x4 Q4 Q2x3 Q5x3 Q6 Q8 Q9x3 Q7x3 Q11 Q12 Q3x3 Q10x3 Q13x3",
	nodes = {
		{id = "quarry_bowcraft", code = "Q1", name = "Bowcraft", type = "modifier",
			ranks = 4, gate = 0, col = 3, effects = {["damage_pct:bow"] = {5, 10, 15, 20}},
			description = "Bow attacks deal +5/10/15/20 % damage, Arrowfall included."},
		{id = "quarry_quiver", code = "Q2", name = "Quiver", type = "modifier",
			ranks = 3, gate = 0, col = 2, effects = {arrow_refund_chance = {10, 20, 30}},
			description = "Loose has a 10/20/30 % chance to keep its arrow."},
		{id = "quarry_measured_breath", code = "Q3", name = "Measured Breath",
			type = "modifier", ranks = 3, gate = 0, col = 4,
			effects = {["cost_pct:bow"] = {-5, -10, -15}},
			description = "Paid bow skills cost 5/10/15 % less."},
		{id = "quarry_true_draw", code = "Q4", name = "True Draw", type = "unlock",
			ability = "true_draw", ranks = 1, gate = 2, col = 3,
			description = "Unlocks True Draw: an instant shot for 220 % of a base bow hit; " ..
				"6 s cooldown, 6 % mana and 1 arrow, 1.35 s recovery."},
		{id = "quarry_firm_aim", code = "Q5", name = "Firm Aim", type = "modifier",
			ranks = 3, gate = 6, col = 2, requires = {"quarry_true_draw"},
			description = "True Draw +10/20/30 % of a base bow hit."},
		{id = "quarry_snare_shot", code = "Q6", name = "Snare Shot", type = "unlock",
			ability = "snare_shot", ranks = 1, gate = 6, col = 4,
			description = "Unlocks Snare Shot: an instant shot for 45 % of a base bow hit " ..
				"that slows by 35 % for 3 s; 14 s cooldown, 5 % mana and 1 arrow, 0.85 s " ..
				"recovery."},
		{id = "quarry_long_view", code = "Q7", name = "Long View", type = "modifier",
			ranks = 3, gate = 10, col = 4, effects = {["range_add:bow"] = {1, 2, 3}},
			description = "Bow skills reach 1/2/3 m farther."},
		{id = "quarry_split_shot", code = "Q8", name = "Split Shot", type = "unlock",
			ability = "split_shot", ranks = 1, gate = 12, col = 2,
			description = "Unlocks Split Shot: one arrow for 90 % of a base bow hit; up to " ..
				"2 others within 3 m of the target take 55 %; 10 s cooldown, 8 % mana and " ..
				"1 arrow."},
		{id = "quarry_broad_shot", code = "Q9", name = "Broad Shot", type = "modifier",
			ranks = 3, gate = 12, col = 1, requires = {"quarry_split_shot"},
			description = "Split Shot's other hits +5/10/15 % of a base bow hit."},
		{id = "quarry_light_recovery", code = "Q10", name = "Light Recovery",
			type = "modifier", ranks = 3, gate = 16, col = 2,
			effects = {["cost_pct:sidestep"] = {-10, -20, -30}},
			description = "Sidestep costs 10/20/30 % less."},
		{id = "quarry_follow_the_line", code = "Q11", name = "Follow the Line",
			type = "window", ranks = 3, gate = 16, col = 4, requires = {"quarry_true_draw"},
			description = "A landed True Draw readies your next Loose within 3 s, at any " ..
				"target: +10/20/30 % of a base bow hit."},
		{id = "quarry_arrowfall", code = "Q12", name = "Arrowfall", type = "ultimate",
			ability = "arrowfall", ranks = 1, gate = 20, col = 3, requires = {"quarry_true_draw"},
			description = "Unlocks Arrowfall: 4 arrows at once at the target under your " ..
				"crosshair, each 140 % of a base bow hit, critical hits allowed; 60 s " ..
				"cooldown, 16 % mana and 4 arrows, 2.5 s recovery."},
		{id = "quarry_iron_hail", code = "Q13", name = "Iron Hail", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"quarry_arrowfall"},
			description = "Each Arrowfall arrow +4/8/12 % of a base bow hit."},
	},
})

graph.register_tree({
	id = "veil", class = "scout", name = "Veil", ranks = 33,
	description = "Blade: Bladecraft, Opening, Parry, Flourish and the Close Dance ultimate.",
	example = "V1 V2x4 V4 V6 V7x3 V3x2 V8 V9x3 V10x3 V3 V12 V5x3 V11x3 V13x3",
	nodes = {
		{id = "veil_bladecraft", code = "V1", name = "Bladecraft", type = "transform",
			ability = "bladecraft", ranks = 1, gate = 0, col = 2,
			description = "Loose becomes Bladecraft: left click swings your blade, right " ..
				"click looses an instant shot at an enemy; both share one clock."},
		{id = "veil_fine_edge", code = "V2", name = "Fine Edge", type = "modifier",
			ranks = 4, gate = 0, col = 4, effects = {["damage_pct:blade"] = {8, 16, 24, 32}},
			description = "Blade attacks deal +8/16/24/32 % damage."},
		{id = "veil_light_step", code = "V3", name = "Light Step", type = "modifier",
			ranks = 3, gate = 0, col = 1, effects = {dodge_chance_add = {1, 2, 3}},
			description = "Dodge chance +1/2/3 %."},
		{id = "veil_opening", code = "V4", name = "Opening", type = "unlock",
			ability = "opening", ranks = 1, gate = 2, col = 3, requires = {"veil_bladecraft"},
			description = "Unlocks Opening: your next swing deals 135 % of a base blade hit, " ..
				"180 % from behind or in Parry's window; 8 s cooldown, 5 % mana."},
		{id = "veil_deep_focus", code = "V5", name = "Deep Focus", type = "modifier",
			ranks = 3, gate = 2, col = 5, effects = {["cost_pct:blade"] = {-5, -10, -15}},
			description = "Paid blade skills, Parry and Close Dance cost 5/10/15 % less."},
		{id = "veil_parry", code = "V6", name = "Parry", type = "unlock", ability = "parry",
			ranks = 1, gate = 6, col = 4,
			description = "Unlocks Parry: a shield of about 10 % of your max health for 2 s, " ..
				"and Opening's window opens for 3 s; 12 s cooldown, 4 % mana, 0.5 s recovery."},
		{id = "veil_held_guard", code = "V7", name = "Held Guard", type = "modifier",
			ranks = 3, gate = 6, col = 5, requires = {"veil_parry"},
			effects = {["duration_add:parry"] = {0.25, 0.5, 0.75}},
			description = "Parry's window and shield last +0.25/0.50/0.75 s."},
		{id = "veil_flourish", code = "V8", name = "Flourish", type = "unlock",
			ability = "flourish", ranks = 1, gate = 12, col = 2, requires = {"veil_bladecraft"},
			description = "Unlocks Flourish: an instant 90 degree, 3 m sweep; the 3 nearest " ..
				"take 80 % of a base blade hit each; 12 s cooldown, 8 % mana."},
		{id = "veil_wide_edge", code = "V9", name = "Wide Edge", type = "modifier",
			ranks = 3, gate = 12, col = 1, requires = {"veil_flourish"},
			description = "Flourish +5/10/15 % of a base blade hit per target."},
		{id = "veil_turn_the_blade", code = "V10", name = "Turn the Blade", type = "modifier",
			ranks = 3, gate = 12, col = 5, requires = {"veil_opening", "veil_parry"},
			description = "Opening in Parry's window +10/20/30 % of a base blade hit."},
		{id = "veil_shake_loose", code = "V11", name = "Shake Loose", type = "modifier",
			ranks = 3, gate = 16, col = 2, effects = {["cooldown_sub:sidestep"] = {1, 2, 3}},
			description = "Sidestep also frees you from slows and roots; its cooldown " ..
				"-1/2/3 s."},
		{id = "veil_close_dance", code = "V12", name = "Close Dance", type = "ultimate",
			ability = "close_dance", ranks = 1, gate = 20, col = 4,
			requires = {"veil_opening", "veil_parry"},
			description = "Unlocks Close Dance: for 6 s your blade swings deal +35 % of a " ..
				"base blade hit, and a shield of about 15 % of your max health; 60 s " ..
				"cooldown, 14 % mana, 0.25 s recovery."},
		{id = "veil_cutting_rhythm", code = "V13", name = "Cutting Rhythm", type = "modifier",
			ranks = 3, gate = 20, col = 5, requires = {"veil_close_dance"},
			description = "Close Dance's swing bonus +5/10/15 % of a base blade hit."},
		{id = "veil_travel_worn", code = "V14", name = "Travel Worn", type = "modifier",
			ranks = 3, gate = 6, col = 1, effects = {max_hp_percent_add = {3, 6, 9}},
			description = "Max health +3/6/9 %."},
	},
})
