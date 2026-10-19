-- The eight new talent trees as preview data (Round 52 D3): nodes, ranks,
-- gates, prerequisites, types, abilities and layout columns from
-- docs/planning/class-redesign/node-list.md, effects only where a key of the
-- graph vocabulary fits, and one worked 30-point sample build per tree.
-- Nothing live reads this file: only the admin preview (/talent_preview) and
-- the fixtures. Round K replaces it with one data file per class.
--
-- Node ids are the node names in snake_case; `code` is the node list's id
-- (Reckoning RK1-RK14, Mercy without M12). Icons: a talent node shows
-- grug_classes_talent_<id>.png, a granting node its skill's
-- grug_abilities_skill_<ability>.png, a tree grug_classes_tree_<id>.png as
-- its background -- each only once the file ships (D7); text and a plain
-- background otherwise. Descriptions keep the node list's notation: D, S, R,
-- M and B are the class's base hits, P the pool, K the armor constant, Q and
-- F the support factors.
--
-- The sample builds are the candidates' pure 30-point orders (mage: the
-- class-redesign handoff §5.6; warrior.md, priest.md and scout.md §5/§7),
-- adapted to the node list: Mercy's 3 points in the cut M12 Shelter go to
-- M11 Quiet Care, and priest.md's Reckoning codes R1-R14 read RK1-RK14.

local graph = grug_classes.graph

graph.register_class_vocabulary("mage", {
	params = {"fire", "frost", "fiery_spark", "ice_wave", "fireball", "flame_lance",
		"meteor", "fire_rain", "cold_spark", "blink", "rime_mantle", "ice_nova",
		"winter_field"},
})
graph.register_class_vocabulary("warrior", {
	keys = {rage_per_swing_add = "grug_abilities/init.lua the swing rage sites"},
	params = {"strike", "charge", "retort", "hold_ground", "taunt", "bellow",
		"unbroken", "mighty_blow", "hamstring", "broadstroke", "ruination"},
})
graph.register_class_vocabulary("priest", {
	keys = {heal_threat_factor_sub = "grug_core/combat.lua add_heal_threat"},
	params = {"support", "paid", "smite", "heal", "shield_spell", "mend", "hearten",
		"haven", "rebuke", "word_of_ruin", "censure", "final_word"},
})
graph.register_class_vocabulary("scout", {
	keys = {arrow_refund_chance = "grug_abilities/scout.lua Loose settlement"},
	params = {"bow", "blade", "loose", "sidestep", "sprint", "true_draw", "snare_shot",
		"split_shot", "arrowfall", "bladecraft", "opening", "parry", "flourish",
		"close_dance"},
})

graph.register_tree({
	id = "ember", class = "mage", name = "Ember", ranks = 32,
	description = "Fire damage: Fireball, Flame Lance, Meteor and the Fire Rain ultimate.",
	example = "F1x4 F4 F2x3 F3x2 F5 F6x3 F7x3 F8 F9x3 F10x3 F11x3 F12 F13x2",
	nodes = {
		{id = "fire_mastery", code = "F1", name = "Fire Mastery", type = "modifier",
			ranks = 4, gate = 0, col = 3, effects = {["damage_pct:fire"] = {5, 10, 15, 20}},
			description = "All fire damage +5/10/15/20 % (added once)."},
		{id = "measured_fuel", code = "F2", name = "Measured Fuel", type = "modifier",
			ranks = 3, gate = 0, col = 2, effects = {["cost_pct:fire"] = {-4, -8, -12}},
			description = "Paid fire spells cost 4/8/12 % less."},
		{id = "far_cast", code = "F3", name = "Far Cast", type = "modifier",
			ranks = 3, gate = 0, col = 4,
			effects = {["range_add:fiery_spark"] = {1, 2, 3}, ["range_add:cold_spark"] = {1, 2, 3}},
			description = "Spark and Cold Spark range +1/2/3 m."},
		{id = "fireball", code = "F4", name = "Fireball", type = "unlock", ability = "fireball",
			ranks = 1, gate = 2, col = 3, requires = {"fire_mastery"},
			description = "Unlocks Fireball: 1.60D and 0.15D splash in 2 m, 5 s cooldown, " ..
				"6 % P, 1 s occupied."},
		{id = "flame_lance", code = "F5", name = "Flame Lance", type = "unlock",
			ability = "flame_lance", ranks = 1, gate = 6, col = 4,
			description = "Unlocks Flame Lance: an instant heavy projectile, 2.20D, 8 s " ..
				"cooldown, 10 % P, 1.5 s occupied."},
		{id = "heat_focus", code = "F6", name = "Heat Focus", type = "modifier",
			ranks = 3, gate = 6, col = 5, requires = {"flame_lance"},
			effects = {["damage_pct:flame_lance"] = {5, 10, 15}},
			description = "Flame Lance +5/10/15 % of its untalented damage."},
		{id = "afterglow", code = "F7", name = "Afterglow", type = "modifier",
			ranks = 3, gate = 6, col = 2, requires = {"fireball"},
			description = "Fireball's primary hit +0.05/0.10/0.15D."},
		{id = "meteor", code = "F8", name = "Meteor", type = "unlock", ability = "meteor",
			ranks = 1, gate = 12, col = 3, requires = {"fireball"},
			description = "Unlocks Meteor: on the ground up to 20 m away, after 1.5 s with " ..
				"a warning, 1.4D in 3 m; 18 s cooldown, 14 % P."},
		{id = "wide_ember", code = "F9", name = "Wide Ember", type = "modifier",
			ranks = 3, gate = 12, col = 2, requires = {"fireball"},
			description = "Fireball splash 0.20/0.25/0.30D."},
		{id = "broad_impact", code = "F10", name = "Broad Impact", type = "modifier",
			ranks = 3, gate = 12, col = 4, requires = {"meteor"},
			effects = {["radius_add:meteor"] = {0.25, 0.5, 0.75}},
			description = "Meteor radius +0.25/0.50/0.75 m."},
		{id = "controlled_burn", code = "F11", name = "Controlled Burn", type = "modifier",
			ranks = 3, gate = 16, col = 5, requires = {"meteor"},
			effects = {["cost_pct:meteor"] = {-5, -10, -15}, ["cost_pct:fire_rain"] = {-5, -10, -15}},
			description = "Meteor and Fire Rain cost 5/10/15 % less (adds to Measured Fuel)."},
		{id = "fire_rain", code = "F12", name = "Fire Rain", type = "ultimate",
			ability = "fire_rain", ranks = 1, gate = 20, col = 3, requires = {"meteor"},
			description = "Unlocks Fire Rain: on the ground up to 20 m away, after 1.5 s " ..
				"one shower of about 2.5D in 5 m; 60 s cooldown, 22 % P, 1.5 s occupied."},
		{id = "spreading_rain", code = "F13", name = "Spreading Rain", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"fire_rain"},
			effects = {["radius_add:fire_rain"] = {0.25, 0.5, 0.75}},
			description = "Fire Rain radius +0.25/0.50/0.75 m."},
	},
})

graph.register_tree({
	id = "rime", class = "mage", name = "Rime", ranks = 33,
	description = "Frost control: Cold Spark, Blink, Rime Mantle, Ice Nova and the " ..
		"Winter Field ultimate.",
	example = "R1 R2x4 R3x3 R4 R5x3 R6x3 R7 R8x3 R9 R10x3 R13 R11x3 R14x3",
	nodes = {
		{id = "cold_spark", code = "R1", name = "Cold Spark", type = "transform",
			ability = "cold_spark", ranks = 1, gate = 0, col = 2,
			description = "Fiery Spark becomes Cold Spark: a free frost projectile, D, " ..
				"12 % slow for 1.5 s; no fire bonuses."},
		{id = "mana_reserve", code = "R2", name = "Mana Reserve", type = "modifier",
			ranks = 4, gate = 0, col = 4, effects = {max_mana_percent_add = {5, 10, 15, 20}},
			description = "Max mana +5/10/15/20 % P."},
		{id = "keen_cold", code = "R3", name = "Keen Cold", type = "modifier",
			ranks = 3, gate = 0, col = 3, requires = {"cold_spark"},
			description = "Cold Spark +0.03/0.06/0.09D; the slow stays 12 %."},
		{id = "blink", code = "R4", name = "Blink", type = "unlock", ability = "blink",
			ranks = 1, gate = 2, col = 3,
			description = "Unlocks Blink: a 10 m teleport, 20 s cooldown, 8 % P."},
		{id = "clear_thought", code = "R5", name = "Clear Thought", type = "modifier",
			ranks = 3, gate = 2, col = 4, effects = {["cost_pct:frost"] = {-4, -8, -12}},
			description = "Paid frost and utility spells cost 4/8/12 % less."},
		{id = "quick_step", code = "R6", name = "Quick Step", type = "modifier",
			ranks = 3, gate = 6, col = 3, requires = {"blink"},
			effects = {["cooldown_sub:blink"] = {1, 2, 3}},
			description = "Blink cooldown -1/2/3 s."},
		{id = "rime_mantle", code = "R7", name = "Rime Mantle", type = "unlock",
			ability = "rime_mantle", ranks = 1, gate = 6, col = 5,
			description = "Unlocks Rime Mantle: armor +0.20K on yourself for 6 s, 24 s " ..
				"cooldown, 10 % P."},
		{id = "thick_ice", code = "R8", name = "Thick Ice", type = "modifier",
			ranks = 3, gate = 10, col = 4, requires = {"rime_mantle"},
			description = "Rime Mantle armor +0.04/0.08/0.12K."},
		{id = "ice_nova", code = "R9", name = "Ice Nova", type = "transform",
			ability = "ice_nova", ranks = 1, gate = 12, col = 3,
			description = "Ice Wave becomes Ice Nova: 0.65D in 5 m and a 1.75 s root, " ..
				"18 s cooldown, 10 % P; the cooldown is shared."},
		{id = "cold_shock", code = "R10", name = "Cold Shock", type = "window",
			ranks = 3, gate = 12, col = 2, requires = {"ice_nova", "cold_spark"},
			description = "Ice Nova hitting an enemy readies the next Cold Spark within " ..
				"4 s: +0.25/0.50/0.75D, one charge."},
		{id = "returning_cold", code = "R11", name = "Returning Cold", type = "modifier",
			ranks = 3, gate = 12, col = 1,
			effects = {["cooldown_sub:ice_wave"] = {1, 2, 3}, ["cooldown_sub:ice_nova"] = {1, 2, 3}},
			description = "Ice Wave and Ice Nova cooldown -1/2/3 s."},
		{id = "far_frost", code = "R12", name = "Far Frost", type = "modifier",
			ranks = 3, gate = 16, col = 4, requires = {"ice_nova"},
			effects = {["radius_add:ice_nova"] = {0.25, 0.5, 0.75}},
			description = "Ice Nova radius +0.25/0.50/0.75 m."},
		{id = "winter_field", code = "R13", name = "Winter Field", type = "ultimate",
			ability = "winter_field", ranks = 1, gate = 20, col = 3, requires = {"ice_nova"},
			description = "Unlocks Winter Field: on the ground up to 15 m away, after 1 s " ..
				"one hit of about 1.0D and a 40 % slow for 5 s in 4 m; 60 s cooldown, 18 % P."},
		{id = "lasting_armor", code = "R14", name = "Lasting Armor", type = "modifier",
			ranks = 3, gate = 16, col = 5, requires = {"rime_mantle"},
			effects = {["duration_add:rime_mantle"] = {0.5, 1, 1.5}},
			description = "Rime Mantle lasts +0.5/1.0/1.5 s."},
	},
})

graph.register_tree({
	id = "bulwark", class = "warrior", name = "Bulwark", ranks = 33,
	description = "Guard: Retort, Hold Ground, Taunt, Bellow and the Unbroken ultimate.",
	example = "B1 B2x2 B4 B2x2 B5x3 B3x3 B8x3 B6x3 B10x2 B12 B10 B14x3 B7 B9 B13x3",
	nodes = {
		{id = "retort", code = "B1", name = "Retort", type = "transform", ability = "retort",
			ranks = 1, gate = 0, col = 2,
			description = "Strike becomes Retort: a hostile hit that took HP readies the " ..
				"next swing, +0.25S within 4 s; 6 s internal cooldown."},
		{id = "ironbound", code = "B2", name = "Ironbound", type = "modifier",
			ranks = 4, gate = 0, col = 3, effects = {armor_percent_add = {4, 8, 12, 16}},
			description = "Armor +0.04/0.08/0.12/0.16K."},
		{id = "weathered", code = "B3", name = "Weathered", type = "modifier",
			ranks = 3, gate = 0, col = 4, effects = {max_hp_percent_add = {3, 6, 9}},
			description = "Max HP +3/6/9 % of the class pool."},
		{id = "hold_ground", code = "B4", name = "Hold Ground", type = "unlock",
			ability = "hold_ground", ranks = 1, gate = 2, col = 3,
			description = "Unlocks Hold Ground: 25 rage, 24 s cooldown, absorbs 0.12P for 5 s."},
		{id = "measured_answer", code = "B5", name = "Measured Answer", type = "modifier",
			ranks = 3, gate = 6, col = 1, requires = {"retort"},
			description = "Retort's bonus 0.30/0.35/0.40S."},
		{id = "turn_the_edge", code = "B6", name = "Turn the Edge", type = "modifier",
			ranks = 3, gate = 6, col = 4, effects = {dodge_chance_add = {2, 4, 6}},
			description = "Dodge +2/4/6 percentage points (normal cap)."},
		{id = "taunt", code = "B7", name = "Taunt", type = "unlock", ability = "taunt",
			ranks = 1, gate = 6, col = 5,
			description = "Unlocks Taunt: one mob within 8 m, free, 8 s cooldown, 3 s of " ..
				"its attention."},
		{id = "recover", code = "B8", name = "Recover", type = "modifier",
			ranks = 3, gate = 10, col = 2, requires = {"retort"},
			description = "A landed Retort heals 0.007/0.013/0.02P x F; no crit."},
		{id = "bellow", code = "B9", name = "Bellow", type = "transform", ability = "bellow",
			ranks = 1, gate = 12, col = 5, requires = {"taunt"},
			description = "Taunt becomes Bellow: a 6 m area taunt around you, same cooldown."},
		{id = "layered_guard", code = "B10", name = "Layered Guard", type = "modifier",
			ranks = 3, gate = 12, col = 4, requires = {"hold_ground"},
			description = "Hold Ground absorbs +0.03/0.06/0.09P."},
		{id = "halt", code = "B11", name = "Halt", type = "modifier",
			ranks = 3, gate = 12, col = 1,
			description = "Charge's arrival also slows by 20/25/30 % for the stun + 2 s."},
		{id = "unbroken", code = "B12", name = "Unbroken", type = "ultimate",
			ability = "unbroken", ranks = 1, gate = 20, col = 3, requires = {"hold_ground"},
			description = "Unlocks Unbroken: 25 rage, 60 s cooldown, +0.50K armor and " ..
				"0.15P absorb for 8 s."},
		{id = "enduring_stand", code = "B13", name = "Enduring Stand", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"unbroken"},
			effects = {["duration_add:unbroken"] = {0.5, 1, 1.5}},
			description = "Unbroken lasts +0.5/1.0/1.5 s."},
		{id = "gather_yourself", code = "B14", name = "Gather Yourself", type = "modifier",
			ranks = 3, gate = 16, col = 2, requires = {"hold_ground"},
			effects = {["cooldown_sub:hold_ground"] = {1, 2, 3}},
			description = "Hold Ground cooldown -1/2/3 s."},
	},
})

graph.register_tree({
	id = "ruin", class = "warrior", name = "Ruin", ranks = 33,
	description = "Rage damage: Mighty Blow, Hamstring, Broadstroke and the Ruination " ..
		"ultimate.",
	example = "U1 U2x4 U3 U7 U5x3 U8x3 U10x3 U11x3 U4 U12 U3x2 U6x3 U9x3 U14",
	nodes = {
		{id = "mighty_blow", code = "U1", name = "Mighty Blow", type = "unlock",
			ability = "mighty_blow", ranks = 1, gate = 0, col = 3,
			description = "Unlocks Mighty Blow: a 25-rage swing proc, 1.45S, no cooldown " ..
				"of its own; a plain swing when unaffordable."},
		{id = "heavy_hand", code = "U2", name = "Heavy Hand", type = "modifier",
			ranks = 4, gate = 0, col = 4, requires = {"mighty_blow"},
			description = "Mighty Blow and Broadstroke primary +0.05/0.10/0.15/0.20S."},
		{id = "stoke", code = "U3", name = "Stoke", type = "modifier",
			ranks = 3, gate = 0, col = 2, effects = {rage_per_swing_add = {1, 2, 3}},
			description = "Rage per full swing +1/2/3."},
		{id = "hamstring", code = "U4", name = "Hamstring", type = "unlock",
			ability = "hamstring", ranks = 1, gate = 2, col = 5,
			description = "Unlocks Hamstring: a 10-rage swing proc, S, 8 s proc cooldown, " ..
				"35 % slow for 3 s."},
		{id = "keen_edge", code = "U5", name = "Keen Edge", type = "modifier",
			ranks = 3, gate = 6, col = 1, effects = {crit_chance_add = {2, 4, 6}},
			description = "Crit +2/4/6 percentage points."},
		{id = "onset", code = "U6", name = "Onset", type = "modifier",
			ranks = 3, gate = 6, col = 4, effects = {["cooldown_sub:charge"] = {0.5, 1, 1.5}},
			description = "Charge cooldown -0.5/1.0/1.5 s."},
		{id = "broadstroke", code = "U7", name = "Broadstroke", type = "transform",
			ability = "broadstroke", ranks = 1, gate = 6, col = 2, requires = {"mighty_blow"},
			description = "Mighty Blow becomes Broadstroke: the same primary hit, and up " ..
				"to 2 others in a 100 degree, 3 m arc take 0.35S (may crit)."},
		{id = "follow_through", code = "U8", name = "Follow Through", type = "modifier",
			ranks = 3, gate = 10, col = 2, requires = {"broadstroke"},
			description = "Broadstroke's other targets take 0.40/0.45/0.50S."},
		{id = "clean_cut", code = "U9", name = "Clean Cut", type = "modifier",
			ranks = 3, gate = 10, col = 5, requires = {"hamstring"},
			effects = {["duration_add:hamstring"] = {0.5, 1, 1.5}},
			description = "Hamstring's slow lasts +0.5/1.0/1.5 s; no root."},
		{id = "finisher", code = "U10", name = "Finisher", type = "modifier",
			ranks = 3, gate = 12, col = 4, requires = {"mighty_blow"},
			description = "Mighty Blow and Broadstroke primary +0.08/0.16/0.24S against a " ..
				"target below 30 % HP."},
		{id = "relentless", code = "U11", name = "Relentless", type = "modifier",
			ranks = 3, gate = 16, col = 2, requires = {"mighty_blow"},
			description = "Mighty Blow and Broadstroke cost 1/2/3 rage less."},
		{id = "ruination", code = "U12", name = "Ruination", type = "ultimate",
			ability = "ruination", ranks = 1, gate = 20, col = 3, requires = {"mighty_blow"},
			description = "Unlocks Ruination: 20 rage, 60 s cooldown, 8 s window: swing " ..
				"damage +15 %, +2 rage per landed swing."},
		{id = "long_fury", code = "U13", name = "Long Fury", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"ruination"},
			effects = {["duration_add:ruination"] = {0.5, 1, 1.5}},
			description = "Ruination lasts +0.5/1.0/1.5 s."},
		{id = "reach_the_fight", code = "U14", name = "Reach the Fight", type = "modifier",
			ranks = 1, gate = 12, col = 1,
			description = "Charge's arrival gives +5 rage."},
	},
})

graph.register_tree({
	id = "mercy", class = "priest", name = "Mercy", ranks = 31,
	description = "Support: Shield, Mend, Hearten and the Haven ultimate.",
	example = "M1x3 M3 M2x2 M6 M4x3 M5x3 M10 M8x3 M9x3 M13 M7x3 M11x3 M2 M14x2",
	nodes = {
		{id = "steady_word", code = "M1", name = "Steady Word", type = "modifier",
			ranks = 3, gate = 0, col = 2,
			description = "Smite +0.05/0.10/0.15B; does not stack with Sharpened Word " ..
				"(the higher counts)."},
		{id = "measured_care", code = "M2", name = "Measured Care", type = "modifier",
			ranks = 3, gate = 0, col = 4, effects = {["cost_pct:support"] = {-4, -8, -12}},
			description = "Heal, Shield, Mend, Hearten and Haven cost 4/8/12 % less."},
		{id = "shield", code = "M3", name = "Shield", type = "unlock", ability = "shield_spell",
			ranks = 1, gate = 2, col = 2,
			description = "Unlocks Shield: an ally under the crosshair or yourself absorbs " ..
				"about 22-25 % P x Q for about 10 s; cooldown about 12 s; a recast replaces it."},
		{id = "gentle_hand", code = "M4", name = "Gentle Hand", type = "modifier",
			ranks = 3, gate = 2, col = 4,
			description = "Heal +2/4/6 percentage points of P."},
		{id = "warding_faith", code = "M5", name = "Warding Faith", type = "modifier",
			ranks = 3, gate = 6, col = 2, requires = {"shield"},
			description = "Shield absorbs +2/4/6 percentage points of P (with Shelter's " ..
				"folded value, still to be set)."},
		{id = "mend", code = "M6", name = "Mend", type = "unlock", ability = "mend",
			ranks = 1, gate = 6, col = 4,
			description = "Unlocks Mend: a status on the target, 4 ticks of about 6-8 % " ..
				"P x Q every 3 s; the newest cast replaces it."},
		{id = "patient_care", code = "M7", name = "Patient Care", type = "modifier",
			ranks = 3, gate = 10, col = 4, requires = {"mend"},
			description = "Mend ticks +0.5/1.0/1.5 percentage points of P."},
		{id = "clear_conscience", code = "M8", name = "Clear Conscience", type = "window",
			ranks = 3, gate = 10, col = 2,
			description = "After Heal, Shield or Mend the next Smite within 5 s deals " ..
				"+0.10/0.20/0.30B; 8 s internal cooldown."},
		{id = "deep_reserve", code = "M9", name = "Deep Reserve", type = "modifier",
			ranks = 3, gate = 12, col = 2, effects = {max_mana_percent_add = {4, 8, 12}},
			description = "Max mana +4/8/12 % P."},
		{id = "hearten", code = "M10", name = "Hearten", type = "unlock", ability = "hearten",
			ranks = 1, gate = 12, col = 3,
			description = "Unlocks Hearten: you and up to 3 friendly players within 6 m, " ..
				"lowest HP first, heal about 15 % P x Q each; 1.5 s occupied."},
		{id = "quiet_care", code = "M11", name = "Quiet Care", type = "modifier",
			ranks = 3, gate = 12, col = 4,
			effects = {heal_threat_factor_sub = {0.05, 0.1, 0.15}},
			description = "Healing threat factor 0.50 becomes 0.45/0.40/0.35."},
		{id = "haven", code = "M13", name = "Haven", type = "ultimate", ability = "haven",
			ranks = 1, gate = 20, col = 3, requires = {"hearten"},
			description = "Unlocks Haven: up to 5 friendly players within 8 m, you " ..
				"included, heal 6 ticks of about 7 % P x Q every 2 s; 60 s cooldown, " ..
				"1.5 s occupied."},
		{id = "lasting_haven", code = "M14", name = "Lasting Haven", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"haven"},
			description = "Haven heals +1/2/3 ticks."},
	},
})

graph.register_tree({
	id = "reckoning", class = "priest", name = "Reckoning", ranks = 34,
	description = "Judgment: Rebuke, Word of Ruin, Censure and the Final Word ultimate.",
	example = "RK1x3 RK3 RK2x2 RK6 RK4x3 RK8x3 RK9 RK7x3 RK11x3 RK13 RK12x3 RK14x3 RK2 RK5x2",
	nodes = {
		{id = "sharpened_word", code = "RK1", name = "Sharpened Word", type = "modifier",
			ranks = 3, gate = 0, col = 2,
			description = "Smite +0.05/0.10/0.15B; does not stack with Steady Word " ..
				"(the higher counts)."},
		{id = "measured_judgment", code = "RK2", name = "Measured Judgment", type = "modifier",
			ranks = 3, gate = 0, col = 4, effects = {["cost_pct:paid"] = {-4, -8, -12}},
			description = "Rebuke, Word of Ruin, Censure and Final Word cost 4/8/12 % less."},
		{id = "rebuke", code = "RK3", name = "Rebuke", type = "unlock", ability = "rebuke",
			ranks = 1, gate = 2, col = 3,
			description = "Unlocks Rebuke: an instant hit up to 20 m, 1.8(W+I), 6 % P, " ..
				"6 s cooldown."},
		{id = "firm_rebuke", code = "RK4", name = "Firm Rebuke", type = "modifier",
			ranks = 3, gate = 2, col = 4, requires = {"rebuke"},
			description = "Rebuke +0.10/0.20/0.30B."},
		{id = "long_reach", code = "RK5", name = "Long Reach", type = "modifier",
			ranks = 3, gate = 6, col = 2,
			effects = {["range_add:smite"] = {1, 2, 3}, ["range_add:rebuke"] = {1, 2, 3},
				["range_add:word_of_ruin"] = {1, 2, 3}, ["range_add:final_word"] = {1, 2, 3}},
			description = "Smite, Rebuke, Word of Ruin and Final Word range +1/2/3 m."},
		{id = "word_of_ruin", code = "RK6", name = "Word of Ruin", type = "unlock",
			ability = "word_of_ruin", ranks = 1, gate = 6, col = 4,
			description = "Unlocks Word of Ruin: an instant 1.6(W+I), 16 s cooldown, " ..
				"10 % P; heals you for half the damage, at most 6 % P x Q."},
		{id = "resolute_word", code = "RK7", name = "Resolute Word", type = "modifier",
			ranks = 3, gate = 10, col = 4, requires = {"word_of_ruin"},
			description = "Word of Ruin heals at most 7/8/9 % P."},
		{id = "hard_faith", code = "RK8", name = "Hard Faith", type = "modifier",
			ranks = 3, gate = 10, col = 2, effects = {["damage_pct:paid"] = {3, 6, 9}},
			description = "Paid attack spells deal +3/6/9 % damage; Smite is untouched."},
		{id = "censure", code = "RK9", name = "Censure", type = "unlock", ability = "censure",
			ranks = 1, gate = 12, col = 4,
			description = "Unlocks Censure: on the ground up to 16 m away, after about " ..
				"0.75 s with a warning, one hit of 1.2(W+I) in 3 m on the 4 nearest; " ..
				"12 % P, 18 s cooldown."},
		{id = "broad_judgment", code = "RK10", name = "Broad Judgment", type = "modifier",
			ranks = 3, gate = 12, col = 5, requires = {"censure"},
			effects = {["radius_add:censure"] = {0.25, 0.5, 0.75}},
			description = "Censure radius 3.25/3.50/3.75 m."},
		{id = "deep_resolve", code = "RK11", name = "Deep Resolve", type = "modifier",
			ranks = 3, gate = 12, col = 1, effects = {max_mana_percent_add = {4, 8, 12}},
			description = "Max mana +4/8/12 % P."},
		{id = "press_the_verdict", code = "RK12", name = "Press the Verdict", type = "modifier",
			ranks = 3, gate = 16, col = 2, requires = {"rebuke"},
			effects = {["cooldown_sub:rebuke"] = {0.5, 1, 1.5}},
			description = "Rebuke cooldown 5.5/5.0/4.5 s."},
		{id = "final_word", code = "RK13", name = "Final Word", type = "ultimate",
			ability = "final_word", ranks = 1, gate = 20, col = 3, requires = {"rebuke"},
			description = "Unlocks Final Word: an instant hit up to 20 m, 2.8(W+I), " ..
				"20 % P, 60 s cooldown, 1.5 s occupied."},
		{id = "unfinished_sentence", code = "RK14", name = "Unfinished Sentence",
			type = "modifier", ranks = 3, gate = 20, col = 4, requires = {"final_word"},
			description = "Final Word +0.10/0.20/0.30B."},
	},
})

graph.register_tree({
	id = "quarry", class = "scout", name = "Quarry", ranks = 32,
	description = "Bow: True Draw, Snare Shot, Split Shot and the Arrowfall ultimate.",
	example = "Q1x4 Q4 Q2x3 Q5x3 Q6 Q8 Q9x3 Q7x3 Q11 Q12 Q3x3 Q10x3 Q13x3",
	nodes = {
		{id = "bowcraft", code = "Q1", name = "Bowcraft", type = "modifier",
			ranks = 4, gate = 0, col = 3, effects = {["damage_pct:bow"] = {5, 10, 15, 20}},
			description = "Bow attacks +5/10/15/20 % of their untalented damage, " ..
				"Arrowfall included."},
		{id = "quiver", code = "Q2", name = "Quiver", type = "modifier",
			ranks = 3, gate = 0, col = 2, effects = {arrow_refund_chance = {10, 20, 30}},
			description = "Loose has a 10/20/30 % chance to save its arrow."},
		{id = "measured_breath", code = "Q3", name = "Measured Breath", type = "modifier",
			ranks = 3, gate = 0, col = 4, effects = {["cost_pct:bow"] = {-5, -10, -15}},
			description = "Paid bow skills cost 5/10/15 % less mana."},
		{id = "true_draw", code = "Q4", name = "True Draw", type = "unlock",
			ability = "true_draw", ranks = 1, gate = 2, col = 3,
			description = "Unlocks True Draw: an instant 2.2R, 6 s cooldown, 6 % P and " ..
				"1 arrow, 1.35 s occupied."},
		{id = "firm_aim", code = "Q5", name = "Firm Aim", type = "modifier",
			ranks = 3, gate = 6, col = 2, requires = {"true_draw"},
			description = "True Draw +0.10/0.20/0.30R."},
		{id = "snare_shot", code = "Q6", name = "Snare Shot", type = "unlock",
			ability = "snare_shot", ranks = 1, gate = 6, col = 4,
			description = "Unlocks Snare Shot: an instant 0.45R and a 35 % slow for 3 s, " ..
				"14 s cooldown, 5 % P and 1 arrow, 0.85 s occupied."},
		{id = "long_view", code = "Q7", name = "Long View", type = "modifier",
			ranks = 3, gate = 10, col = 4, effects = {["range_add:bow"] = {1, 2, 3}},
			description = "Bow ranges +1/2/3 m."},
		{id = "split_shot", code = "Q8", name = "Split Shot", type = "unlock",
			ability = "split_shot", ranks = 1, gate = 12, col = 2,
			description = "Unlocks Split Shot: one arrow, 0.90R; on impact up to 2 others " ..
				"within 3 m take 0.55R; 8 % P and 1 arrow, 10 s cooldown."},
		{id = "broad_shot", code = "Q9", name = "Broad Shot", type = "modifier",
			ranks = 3, gate = 12, col = 1, requires = {"split_shot"},
			description = "Split Shot's other hits +0.05/0.10/0.15R."},
		{id = "light_recovery", code = "Q10", name = "Light Recovery", type = "modifier",
			ranks = 3, gate = 16, col = 2, effects = {["cost_pct:sidestep"] = {-10, -20, -30}},
			description = "Sidestep costs 10/20/30 % less mana."},
		{id = "follow_the_line", code = "Q11", name = "Follow the Line", type = "window",
			ranks = 3, gate = 16, col = 4, requires = {"true_draw"},
			description = "A landed True Draw opens 3 s: the next Loose, at any target, " ..
				"+0.10/0.20/0.30R."},
		{id = "arrowfall", code = "Q12", name = "Arrowfall", type = "ultimate",
			ability = "arrowfall", ranks = 1, gate = 20, col = 3, requires = {"true_draw"},
			description = "Unlocks Arrowfall: 4 arrows together at the target under the " ..
				"crosshair, 4 x 1.4R, crits allowed; 16 % P and 4 arrows, 2.5 s occupied, " ..
				"60 s cooldown."},
		{id = "iron_hail", code = "Q13", name = "Iron Hail", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"arrowfall"},
			description = "Each Arrowfall arrow +0.04/0.08/0.12R."},
	},
})

graph.register_tree({
	id = "veil", class = "scout", name = "Veil", ranks = 33,
	description = "Blade: Bladecraft, Opening, Parry, Flourish and the Close Dance ultimate.",
	example = "V1 V2x4 V4 V6 V7x3 V3x2 V8 V9x3 V10x3 V3 V12 V5x3 V11x3 V13x3",
	nodes = {
		{id = "bladecraft", code = "V1", name = "Bladecraft", type = "transform",
			ability = "bladecraft", ranks = 1, gate = 0, col = 2,
			description = "Loose becomes Bladecraft: left click a blade swing, right " ..
				"click an instant Loose shot at a hostile; one shared clock."},
		{id = "fine_edge", code = "V2", name = "Fine Edge", type = "modifier",
			ranks = 4, gate = 0, col = 4, effects = {["damage_pct:blade"] = {8, 16, 24, 32}},
			description = "Blade attacks +8/16/24/32 % of their untalented damage."},
		{id = "light_step", code = "V3", name = "Light Step", type = "modifier",
			ranks = 3, gate = 0, col = 1, effects = {dodge_chance_add = {1, 2, 3}},
			description = "Dodge +1/2/3 percentage points."},
		{id = "opening", code = "V4", name = "Opening", type = "unlock", ability = "opening",
			ranks = 1, gate = 2, col = 3, requires = {"bladecraft"},
			description = "Unlocks Opening: a swing charge, 1.35M, 1.80M from behind or " ..
				"during Parry's window; 8 s cooldown, 5 % P."},
		{id = "deep_focus", code = "V5", name = "Deep Focus", type = "modifier",
			ranks = 3, gate = 2, col = 5, effects = {["cost_pct:blade"] = {-5, -10, -15}},
			description = "Paid blade skills, Parry and Close Dance cost 5/10/15 % less."},
		{id = "parry", code = "V6", name = "Parry", type = "unlock", ability = "parry",
			ranks = 1, gate = 6, col = 4,
			description = "Unlocks Parry: absorbs about 10 % of max HP for 2 s and opens " ..
				"Opening's window for 3 s; 12 s cooldown, 4 % P, 0.5 s occupied."},
		{id = "held_guard", code = "V7", name = "Held Guard", type = "modifier",
			ranks = 3, gate = 6, col = 5, requires = {"parry"},
			effects = {["duration_add:parry"] = {0.25, 0.5, 0.75}},
			description = "Parry's window and absorb last +0.25/0.50/0.75 s."},
		{id = "flourish", code = "V8", name = "Flourish", type = "unlock", ability = "flourish",
			ranks = 1, gate = 12, col = 2, requires = {"bladecraft"},
			description = "Unlocks Flourish: an instant 3 m, 90 degree cone, the 3 nearest " ..
				"take 0.80M each; 12 s cooldown, 8 % P."},
		{id = "wide_edge", code = "V9", name = "Wide Edge", type = "modifier",
			ranks = 3, gate = 12, col = 1, requires = {"flourish"},
			description = "Flourish +0.05/0.10/0.15M per target."},
		{id = "turn_the_blade", code = "V10", name = "Turn the Blade", type = "modifier",
			ranks = 3, gate = 12, col = 5, requires = {"opening", "parry"},
			description = "Opening during Parry's window +0.10/0.20/0.30M."},
		{id = "shake_loose", code = "V11", name = "Shake Loose", type = "modifier",
			ranks = 3, gate = 16, col = 2, effects = {["cooldown_sub:sidestep"] = {1, 2, 3}},
			description = "Sidestep clears your slows; Sidestep cooldown -1/2/3 s."},
		{id = "close_dance", code = "V12", name = "Close Dance", type = "ultimate",
			ability = "close_dance", ranks = 1, gate = 20, col = 4,
			requires = {"opening", "parry"},
			description = "Unlocks Close Dance: a 6 s window, blade swings +0.35M and an " ..
				"absorb of about 15 % of max HP; 60 s cooldown, 14 % P, 0.25 s occupied."},
		{id = "cutting_rhythm", code = "V13", name = "Cutting Rhythm", type = "modifier",
			ranks = 3, gate = 20, col = 5, requires = {"close_dance"},
			description = "Close Dance's swing bonus +0.05/0.10/0.15M."},
		{id = "travel_worn", code = "V14", name = "Travel Worn", type = "modifier",
			ranks = 3, gate = 6, col = 1, effects = {max_hp_percent_add = {3, 6, 9}},
			description = "Max HP +3/6/9 % P."},
	},
})

graph.audit()
