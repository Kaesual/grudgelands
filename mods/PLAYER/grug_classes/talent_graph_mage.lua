-- The Mage's talent graph (Round 53, round K): its vocabulary and its two
-- trees, Ember and Rime, from docs/planning/class-redesign/node-list.md under
-- the user's decisions of 2026-10-20 (round53-plan.md §2). One such file per
-- class; talents.lua loads the four and audits them (talent_graph.lua).
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

graph.register_class_vocabulary("mage", {
	-- Coefficients of D, the untalented Spark hit (kits_mage.lua), and of
	-- the level's armor constant K for Rime Mantle's armor.
	keys = {
		fireball_unit_add = "grug_abilities/kits_mage.lua Fireball's hit",
		fireball_splash_unit_add = "grug_abilities/kits_mage.lua Fireball's splash",
		cold_spark_unit_add = "grug_abilities/kits_mage.lua Cold Spark",
		cold_shock_unit_add = "grug_abilities/kits_mage.lua Ice Nova (the window's value)",
		rime_mantle_armor_add = "grug_abilities/kits_mage.lua Rime Mantle (K)",
	},
	params = {"fire", "frost", "fiery_spark", "ice_wave", "fireball", "flame_lance",
		"meteor", "fire_rain", "cold_spark", "blink", "rime_mantle", "ice_nova",
		"winter_field"},
})

graph.register_tree({
	id = "ember", class = "mage", name = "Ember", ranks = 32,
	description = "Fire damage: Fireball, Flame Lance, Meteor and the Fire Rain ultimate.",
	example = "F1x4 F4 F2x3 F3x2 F5 F6x3 F7x3 F8 F9x3 F10x3 F11x3 F12 F13x2",
	nodes = {
		{id = "ember_fire_mastery", code = "F1", name = "Fire Mastery", type = "modifier",
			ranks = 4, gate = 0, col = 3, effects = {["damage_pct:fire"] = {5, 10, 15, 20}},
			description = "All fire damage +5/10/15/20 %."},
		{id = "ember_measured_fuel", code = "F2", name = "Measured Fuel", type = "modifier",
			ranks = 3, gate = 0, col = 2, effects = {["cost_pct:fire"] = {-4, -8, -12}},
			description = "Paid fire spells cost 4/8/12 % less."},
		{id = "ember_far_cast", code = "F3", name = "Far Cast", type = "modifier",
			ranks = 3, gate = 0, col = 4,
			effects = {["range_add:fiery_spark"] = {1, 2, 3}, ["range_add:cold_spark"] = {1, 2, 3}},
			description = "Fiery Spark and Cold Spark reach 1/2/3 m farther."},
		{id = "ember_fireball", code = "F4", name = "Fireball", type = "unlock",
			ability = "fireball", ranks = 1, gate = 2, col = 3, requires = {"ember_fire_mastery"},
			description = "Unlocks Fireball: 160 % of a Spark hit, and 15 % to others " ..
				"within 2 m; 5 s cooldown, 6 % mana, 1 s recovery."},
		{id = "ember_flame_lance", code = "F5", name = "Flame Lance", type = "unlock",
			ability = "flame_lance", ranks = 1, gate = 6, col = 4,
			description = "Unlocks Flame Lance: an instant heavy bolt for 220 % of a Spark " ..
				"hit; 8 s cooldown, 10 % mana, 1.5 s recovery."},
		{id = "ember_heat_focus", code = "F6", name = "Heat Focus", type = "modifier",
			ranks = 3, gate = 6, col = 5, requires = {"ember_flame_lance"},
			effects = {["damage_pct:flame_lance"] = {5, 10, 15}},
			description = "Flame Lance deals +5/10/15 % damage."},
		{id = "ember_afterglow", code = "F7", name = "Afterglow", type = "modifier",
			ranks = 3, gate = 6, col = 2, requires = {"ember_fireball"},
			effects = {fireball_unit_add = {0.05, 0.10, 0.15}},
			description = "Fireball's hit +5/10/15 % of a Spark hit."},
		{id = "ember_meteor", code = "F8", name = "Meteor", type = "unlock", ability = "meteor",
			ranks = 1, gate = 12, col = 3, requires = {"ember_fireball"},
			description = "Unlocks Meteor: strikes the ground in your crosshair after 1.5 s " ..
				"with a warning, 140 % of a Spark hit within 3 m; 18 s cooldown, 14 % mana."},
		{id = "ember_wide_ember", code = "F9", name = "Wide Ember", type = "modifier",
			ranks = 3, gate = 12, col = 2, requires = {"ember_fireball"},
			effects = {fireball_splash_unit_add = {0.05, 0.10, 0.15}},
			description = "Fireball's splash rises to 20/25/30 % of a Spark hit."},
		{id = "ember_broad_impact", code = "F10", name = "Broad Impact", type = "modifier",
			ranks = 3, gate = 12, col = 4, requires = {"ember_meteor"},
			effects = {["radius_add:meteor"] = {0.25, 0.5, 0.75}},
			description = "Meteor's radius +0.25/0.50/0.75 m."},
		{id = "ember_controlled_burn", code = "F11", name = "Controlled Burn",
			type = "modifier", ranks = 3, gate = 16, col = 5, requires = {"ember_meteor"},
			effects = {["cost_pct:meteor"] = {-5, -10, -15}, ["cost_pct:fire_rain"] = {-5, -10, -15}},
			description = "Meteor and Fire Rain cost 5/10/15 % less, on top of Measured Fuel."},
		{id = "ember_fire_rain", code = "F12", name = "Fire Rain", type = "ultimate",
			ability = "fire_rain", ranks = 1, gate = 20, col = 3, requires = {"ember_meteor"},
			description = "Unlocks Fire Rain: one shower on the ground in your crosshair " ..
				"after 1.5 s, about 250 % of a Spark hit within 5 m; 60 s cooldown, 22 % " ..
				"mana, 1.5 s recovery."},
		{id = "ember_spreading_rain", code = "F13", name = "Spreading Rain", type = "modifier",
			ranks = 3, gate = 20, col = 4, requires = {"ember_fire_rain"},
			effects = {["radius_add:fire_rain"] = {0.25, 0.5, 0.75}},
			description = "Fire Rain's radius +0.25/0.50/0.75 m."},
	},
})

graph.register_tree({
	id = "rime", class = "mage", name = "Rime", ranks = 33,
	description = "Frost control: Cold Spark, Blink, Rime Mantle, Ice Nova and the " ..
		"Winter Field ultimate.",
	example = "R1 R2x4 R3x3 R4 R5x3 R6x3 R7 R8x3 R9 R10x3 R13 R11x3 R14x3",
	nodes = {
		{id = "rime_cold_spark", code = "R1", name = "Cold Spark", type = "transform",
			ability = "cold_spark", ranks = 1, gate = 0, col = 2,
			description = "Fiery Spark becomes Cold Spark: a free frost bolt for a full " ..
				"Spark hit that slows by 12 % for 1.5 s; fire bonuses do not apply."},
		{id = "rime_mana_reserve", code = "R2", name = "Mana Reserve", type = "modifier",
			ranks = 4, gate = 0, col = 4, effects = {max_mana_percent_add = {5, 10, 15, 20}},
			description = "Max mana +5/10/15/20 %."},
		{id = "rime_keen_cold", code = "R3", name = "Keen Cold", type = "modifier",
			ranks = 3, gate = 0, col = 3, requires = {"rime_cold_spark"},
			effects = {cold_spark_unit_add = {0.03, 0.06, 0.09}},
			description = "Cold Spark +3/6/9 % of a Spark hit; the slow stays 12 %."},
		{id = "rime_blink", code = "R4", name = "Blink", type = "unlock", ability = "blink",
			ranks = 1, gate = 2, col = 3,
			description = "Unlocks Blink: a 10 m teleport; 20 s cooldown, 8 % mana."},
		{id = "rime_clear_thought", code = "R5", name = "Clear Thought", type = "modifier",
			ranks = 3, gate = 2, col = 4, effects = {["cost_pct:frost"] = {-4, -8, -12}},
			description = "Paid frost and utility spells cost 4/8/12 % less."},
		{id = "rime_quick_step", code = "R6", name = "Quick Step", type = "modifier",
			ranks = 3, gate = 6, col = 3, requires = {"rime_blink"},
			effects = {["cooldown_sub:blink"] = {1, 2, 3}},
			description = "Blink's cooldown -1/2/3 s."},
		{id = "rime_rime_mantle", code = "R7", name = "Rime Mantle", type = "unlock",
			ability = "rime_mantle", ranks = 1, gate = 6, col = 5,
			description = "Unlocks Rime Mantle: for 6 s, armor +20 % of the level's armor " ..
				"constant and a shield of 12 % of a base health pool; 24 s cooldown, 10 % mana."},
		{id = "rime_thick_ice", code = "R8", name = "Thick Ice", type = "modifier",
			ranks = 3, gate = 10, col = 4, requires = {"rime_rime_mantle"},
			effects = {rime_mantle_armor_add = {0.04, 0.08, 0.12}},
			description = "Rime Mantle's armor +4/8/12 % of the level's armor constant."},
		{id = "rime_ice_nova", code = "R9", name = "Ice Nova", type = "transform",
			ability = "ice_nova", ranks = 1, gate = 12, col = 3,
			description = "Ice Wave becomes Ice Nova: 65 % of a Spark hit within 5 m around " ..
				"you and a 2.5 s root; 18 s cooldown, 10 % mana; the cooldown is shared."},
		{id = "rime_cold_shock", code = "R10", name = "Cold Shock", type = "window",
			ranks = 3, gate = 12, col = 2, requires = {"rime_ice_nova", "rime_cold_spark"},
			effects = {cold_shock_unit_add = {0.25, 0.50, 0.75}},
			description = "When Ice Nova hits an enemy, your next Cold Spark within 4 s " ..
				"deals +25/50/75 % of a Spark hit; one charge."},
		{id = "rime_returning_cold", code = "R11", name = "Returning Cold", type = "modifier",
			ranks = 3, gate = 12, col = 1,
			effects = {["cooldown_sub:ice_wave"] = {1, 2, 3}, ["cooldown_sub:ice_nova"] = {1, 2, 3}},
			description = "Ice Wave's and Ice Nova's cooldown -1/2/3 s."},
		{id = "rime_far_frost", code = "R12", name = "Far Frost", type = "modifier",
			ranks = 3, gate = 16, col = 4, requires = {"rime_ice_nova"},
			effects = {["radius_add:ice_nova"] = {0.25, 0.5, 0.75}},
			description = "Ice Nova's radius +0.25/0.50/0.75 m."},
		{id = "rime_winter_field", code = "R13", name = "Winter Field", type = "ultimate",
			ability = "winter_field", ranks = 1, gate = 20, col = 3, requires = {"rime_ice_nova"},
			description = "Unlocks Winter Field: one blast on the ground in your crosshair " ..
				"after 1 s, about 100 % of a Spark hit and a 40 % slow for 5 s within 4 m; " ..
				"60 s cooldown, 18 % mana."},
		{id = "rime_lasting_armor", code = "R14", name = "Lasting Armor", type = "modifier",
			ranks = 3, gate = 16, col = 5, requires = {"rime_rime_mantle"},
			effects = {["duration_add:rime_mantle"] = {0.5, 1, 1.5}},
			description = "Rime Mantle lasts +0.5/1.0/1.5 s."},
	},
})
