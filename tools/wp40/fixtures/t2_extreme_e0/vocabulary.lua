-- Closed normalized WP43 vocabulary projection consumed by the E0 authority.
-- Its canonical digest is also pinned by t2_extreme_authority.lua.
return {
	resource_keys = {
		"coal", "copper", "tin", "iron", "quartz", "gold", "citrine",
		"garnet", "jade", "silver", "emberglass", "diamond", "sapphire",
		"ruby", "abyssal_crystal",
	},
	resource_rows = {
		{key = "coal", scope = "universal"},
		{key = "copper", scope = "universal"},
		{key = "tin", scope = "universal"},
		{key = "iron", scope = "universal"},
		{key = "quartz", scope = "universal"},
		{key = "gold", scope = "universal"},
		{key = "citrine", scope = "regional", grade = "G1"},
		{key = "garnet", scope = "regional", grade = "G1"},
		{key = "jade", scope = "regional", grade = "G1"},
		{key = "silver", scope = "universal"},
		{key = "emberglass", scope = "universal"},
		{key = "diamond", scope = "regional", grade = "G2"},
		{key = "sapphire", scope = "regional", grade = "G2"},
		{key = "ruby", scope = "regional", grade = "G2"},
		{key = "abyssal_crystal", scope = "universal"},
	},
	cultural_keys = {
		"gravesalt", "moonresin", "red_ochre", "runeslate", "spirit_resin",
		"sunwax",
	},
	wood_keys = {
		"gravewood", "kapok", "mountain_pine", "oak", "silverwood",
		"spikethorn_acacia",
	},
}
