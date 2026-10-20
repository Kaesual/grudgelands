-- The Priest's talent graph (Round 53, round K): its vocabulary and its two
-- trees, Mercy and Reckoning, from docs/planning/class-redesign/node-list.md
-- under the user's decisions of 2026-10-20 (round53-plan.md §2 and §8 Q1).
-- One such file per class; talents.lua loads the four and audits them
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
-- Mercy: M12 Shelter is cut and folded into Warding Faith (M5), which has 5
-- ranks (+2/4/6/8/10 points of the pool on Shield), so the tree holds 33
-- ranks. Gentle Hand, Warding Faith and Patient Care are increments on the
-- new bases (Heal 25 %, Shield 24 %, Mend 7 % of the pool). The sample build
-- is the candidate's pure Mercy order with Shelter's three points moved to
-- Warding Faith's ranks 4-5 and Lasting Haven's third rank; Quiet Care stays
-- unbought (threat only).

local graph = grug_classes.graph

graph.register_class_vocabulary("priest", {
	keys = {heal_threat_factor_sub = "grug_core/combat.lua add_heal_threat"},
	params = {"support", "paid", "smite", "heal", "shield_spell", "mend", "hearten",
		"haven", "rebuke", "word_of_ruin", "censure", "final_word"},
})

graph.register_tree({
	id = "mercy", class = "priest", name = "Mercy", ranks = 33,
	description = "Support: Shield, Mend, Hearten and the Haven ultimate. Healing and " ..
		"shields grow with your healing power.",
	example = "M1x3 M3 M2x2 M6 M4x3 M5x3 M10 M8x3 M9x3 M13 M7x3 M5x2 M2 M14x3",
	nodes = {
		{id = "mercy_steady_word", code = "M1", name = "Steady Word", type = "modifier",
			ranks = 3, gate = 0, col = 2,
			description = "Smite +5/10/15 % of a base hit; with Sharpened Word only the " ..
				"higher counts."},
		{id = "mercy_measured_care", code = "M2", name = "Measured Care", type = "modifier",
			ranks = 3, gate = 0, col = 4, effects = {["cost_pct:support"] = {-4, -8, -12}},
			description = "Heal, Shield, Mend, Hearten and Haven cost 4/8/12 % less."},
		{id = "mercy_shield", code = "M3", name = "Shield", type = "unlock",
			ability = "shield_spell", ranks = 1, gate = 2, col = 2,
			description = "Unlocks Shield: you or the ally under your crosshair gets a " ..
				"shield of 24 % of a base health pool for 10 s; 12 s cooldown; a new cast " ..
				"replaces it."},
		{id = "mercy_gentle_hand", code = "M4", name = "Gentle Hand", type = "modifier",
			ranks = 3, gate = 2, col = 4,
			description = "Heal +2/4/6 % of a base health pool."},
		{id = "mercy_warding_faith", code = "M5", name = "Warding Faith", type = "modifier",
			ranks = 5, gate = 6, col = 2, requires = {"mercy_shield"},
			description = "Shield +2/4/6/8/10 % of a base health pool."},
		{id = "mercy_mend", code = "M6", name = "Mend", type = "unlock", ability = "mend",
			ranks = 1, gate = 6, col = 4,
			description = "Unlocks Mend: heals the target 4 times, 7 % of a base health " ..
				"pool every 3 s; the newest cast replaces it."},
		{id = "mercy_patient_care", code = "M7", name = "Patient Care", type = "modifier",
			ranks = 3, gate = 10, col = 4, requires = {"mercy_mend"},
			description = "Mend's ticks +0.5/1.0/1.5 % of a base health pool."},
		{id = "mercy_clear_conscience", code = "M8", name = "Clear Conscience",
			type = "window", ranks = 3, gate = 10, col = 2,
			description = "After Heal, Shield or Mend your next Smite within 5 s deals " ..
				"+10/20/30 % of a base hit; 8 s internal cooldown."},
		{id = "mercy_deep_reserve", code = "M9", name = "Deep Reserve", type = "modifier",
			ranks = 3, gate = 12, col = 2, effects = {max_mana_percent_add = {4, 8, 12}},
			description = "Max mana +4/8/12 %."},
		{id = "mercy_hearten", code = "M10", name = "Hearten", type = "unlock",
			ability = "hearten", ranks = 1, gate = 12, col = 3,
			description = "Unlocks Hearten: you and up to 3 allies within 6 m, lowest " ..
				"health first, heal 15 % of a base health pool each; 20 s cooldown, 14 % " ..
				"mana, 1.5 s recovery."},
		{id = "mercy_quiet_care", code = "M11", name = "Quiet Care", type = "modifier",
			ranks = 3, gate = 12, col = 4,
			effects = {heal_threat_factor_sub = {0.05, 0.1, 0.15}},
			description = "Your healing draws 45/40/35 % threat instead of 50 %."},
		{id = "mercy_haven", code = "M13", name = "Haven", type = "ultimate", ability = "haven",
			ranks = 1, gate = 20, col = 3, requires = {"mercy_hearten"},
			description = "Unlocks Haven: you and up to 4 allies within 8 m heal 6 times, " ..
				"7 % of a base health pool every 2 s; 60 s cooldown, 1.5 s recovery."},
		{id = "mercy_lasting_haven", code = "M14", name = "Lasting Haven", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"mercy_haven"},
			description = "Haven heals 1/2/3 more times."},
	},
})

graph.register_tree({
	id = "reckoning", class = "priest", name = "Reckoning", ranks = 34,
	description = "Judgment: Rebuke, Word of Ruin, Censure and the Final Word ultimate.",
	example = "RK1x3 RK3 RK2x2 RK6 RK4x3 RK8x3 RK9 RK7x3 RK11x3 RK13 RK12x3 RK14x3 RK2 RK5x2",
	nodes = {
		{id = "reckoning_sharpened_word", code = "RK1", name = "Sharpened Word",
			type = "modifier", ranks = 3, gate = 0, col = 2,
			description = "Smite +5/10/15 % of a base hit; with Steady Word only the " ..
				"higher counts."},
		{id = "reckoning_measured_judgment", code = "RK2", name = "Measured Judgment",
			type = "modifier", ranks = 3, gate = 0, col = 4,
			effects = {["cost_pct:paid"] = {-4, -8, -12}},
			description = "Rebuke, Word of Ruin, Censure and Final Word cost 4/8/12 % less."},
		{id = "reckoning_rebuke", code = "RK3", name = "Rebuke", type = "unlock",
			ability = "rebuke", ranks = 1, gate = 2, col = 3,
			description = "Unlocks Rebuke: an instant hit up to 20 m away for 180 % of a " ..
				"Smite hit; 6 s cooldown, 6 % mana."},
		{id = "reckoning_firm_rebuke", code = "RK4", name = "Firm Rebuke", type = "modifier",
			ranks = 3, gate = 2, col = 4, requires = {"reckoning_rebuke"},
			description = "Rebuke +10/20/30 % of a base hit."},
		{id = "reckoning_long_reach", code = "RK5", name = "Long Reach", type = "modifier",
			ranks = 3, gate = 6, col = 2,
			effects = {["range_add:smite"] = {1, 2, 3}, ["range_add:rebuke"] = {1, 2, 3},
				["range_add:word_of_ruin"] = {1, 2, 3}, ["range_add:final_word"] = {1, 2, 3}},
			description = "Smite, Rebuke, Word of Ruin and Final Word reach 1/2/3 m farther."},
		{id = "reckoning_word_of_ruin", code = "RK6", name = "Word of Ruin", type = "unlock",
			ability = "word_of_ruin", ranks = 1, gate = 6, col = 4,
			description = "Unlocks Word of Ruin: an instant hit for 160 % of a Smite hit " ..
				"that heals you for half the damage, at most 6 % of a base health pool; " ..
				"16 s cooldown, 10 % mana."},
		{id = "reckoning_resolute_word", code = "RK7", name = "Resolute Word",
			type = "modifier", ranks = 3, gate = 10, col = 4, requires = {"reckoning_word_of_ruin"},
			description = "Word of Ruin heals at most 7/8/9 % of a base health pool."},
		{id = "reckoning_hard_faith", code = "RK8", name = "Hard Faith", type = "modifier",
			ranks = 3, gate = 10, col = 2, effects = {["damage_pct:paid"] = {3, 6, 9}},
			description = "Paid attack spells deal +3/6/9 % damage; Smite is unchanged."},
		{id = "reckoning_censure", code = "RK9", name = "Censure", type = "unlock",
			ability = "censure", ranks = 1, gate = 12, col = 4,
			description = "Unlocks Censure: strikes the ground up to 16 m away after " ..
				"0.75 s with a warning, 120 % of a Smite hit to the 4 nearest within 3 m; " ..
				"18 s cooldown, 12 % mana."},
		{id = "reckoning_broad_judgment", code = "RK10", name = "Broad Judgment",
			type = "modifier", ranks = 3, gate = 12, col = 5, requires = {"reckoning_censure"},
			effects = {["radius_add:censure"] = {0.25, 0.5, 0.75}},
			description = "Censure's radius +0.25/0.50/0.75 m."},
		{id = "reckoning_deep_resolve", code = "RK11", name = "Deep Resolve", type = "modifier",
			ranks = 3, gate = 12, col = 1, effects = {max_mana_percent_add = {4, 8, 12}},
			description = "Max mana +4/8/12 %."},
		{id = "reckoning_press_the_verdict", code = "RK12", name = "Press the Verdict",
			type = "modifier", ranks = 3, gate = 16, col = 2, requires = {"reckoning_rebuke"},
			effects = {["cooldown_sub:rebuke"] = {0.5, 1, 1.5}},
			description = "Rebuke's cooldown -0.5/1.0/1.5 s."},
		{id = "reckoning_final_word", code = "RK13", name = "Final Word", type = "ultimate",
			ability = "final_word", ranks = 1, gate = 20, col = 3, requires = {"reckoning_rebuke"},
			description = "Unlocks Final Word: an instant hit up to 20 m away for 280 % of " ..
				"a Smite hit; 60 s cooldown, 20 % mana, 1.5 s recovery."},
		{id = "reckoning_unfinished_sentence", code = "RK14", name = "Unfinished Sentence",
			type = "modifier", ranks = 3, gate = 20, col = 4,
			requires = {"reckoning_final_word"},
			description = "Final Word +10/20/30 % of a base hit."},
	},
})
