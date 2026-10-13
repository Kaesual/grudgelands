-- Basic recipes changed after the Round 45 conversion, each with its round
-- and ruling. gen_basic_recipes.lua applies them to the converted rows (so
-- --check still compares the whole file) and portable_test.lua accepts them
-- in its conversion check. An edit names a converted row by output and
-- signature (gen_basic_recipes.lua signature_of: "token*n" sorted, joined
-- by "+") and gives its new count, asserting the old one (`was`), or
-- `removed = true` to drop it (asserting `was` too); a row that no grid
-- route made is `added` with its ingredient list.
return {
	-- Round 46 ruling 4: 10 torches per coal or charcoal (4 per coal before);
	-- the coal supply is solved by torches, not by more coal. One recipe for
	-- both (lane ID, the user's request of 2026-10-12): the coal row goes,
	-- the coal group (coal lump and charcoal) takes its place.
	{output = "default:torch", signature = "default:coal_lump*1+group:stick*1",
		was = 4, removed = true},
	{output = "default:torch", count = 10, added = {
		{group = "coal", n = 1}, {group = "stick", n = 1}}},
	-- Round 47 ruling 10: the Anthracite torch (light 14), 10 from 1
	-- Anthracite and 1 stick. Anthracite is not in the coal group (ruling 9).
	{output = "grug_materials:anthracite_torch", count = 10, added = {
		{item = "grug_materials:anthracite", n = 1}, {group = "stick", n = 1}}},
}
