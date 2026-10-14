-- Decided Round 12 cultivated crop families. This table owns lifecycle shape;
-- wild source geography and renewal remain independent. Round 48: Melon and
-- Mushroom join, Salt Crust leaves (the salt pan, salt_pan.lua); `dark`
-- marks the fungi and cave plants that grow without light (their seeds are
-- spores).
return {
	wild_grain = {kind = "annual_low", shape = "grain"},
	carrot = {kind = "annual_low", shape = "root"},
	cassava = {kind = "annual_low", shape = "tall_bush"},
	wild_onion = {kind = "annual_low", shape = "root"},
	fire_pepper = {kind = "regrow_bush", shape = "bush", regrow_stage = 2},
	pumpkin = {kind = "regrow_ground_fruit", shape = "ground_fruit", regrow_stage = 2},
	blightberry = {kind = "regrow_bush", shape = "bush", regrow_stage = 2},
	sunberry = {kind = "regrow_bush", shape = "bush", regrow_stage = 2},
	jungle_berry = {kind = "regrow_bush", shape = "wide_bush", regrow_stage = 2},
	frost_melon = {kind = "regrow_ground_fruit", shape = "ground_fruit", regrow_stage = 2},
	sugar_cane = {kind = "vertical_retained", shape = "cane", regrow_stage = 1,
		heights = {1, 2, 3, 4}},
	bamboo_shoot = {kind = "vertical_retained", shape = "bamboo", regrow_stage = 1,
		heights = {1, 1, 2, 3}},
	cave_cap = {kind = "regrow_bush", shape = "mushroom", regrow_stage = 2, dark = true},
	ember_moss = {kind = "regrow_bush", shape = "mat", regrow_stage = 2, dark = true},
	potato = {kind = "annual_low", shape = "root"},
	corn = {kind = "vertical_annual", shape = "corn", heights = {1, 1, 2, 3}},
	melon = {kind = "regrow_ground_fruit", shape = "ground_fruit", regrow_stage = 2},
	mushroom = {kind = "regrow_bush", shape = "mushroom", regrow_stage = 2, dark = true},
}
