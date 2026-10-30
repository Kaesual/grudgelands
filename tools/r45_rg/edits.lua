-- Basic recipes changed after the Round 45 conversion, each with its round
-- and ruling. gen_basic_recipes.lua applies them to the converted rows (so
-- --check still compares the whole file) and portable_test.lua accepts them
-- in its conversion check. An edit names a converted row by output and
-- signature (gen_basic_recipes.lua signature_of: "token*n" sorted, joined
-- by "+") and gives its new count, asserting the old one (`was`), or
-- `removed = true` to drop it (asserting `was` too); a row that no grid
-- route made is `added` with its ingredient list. The file is Lua: a loop
-- may add a family of edits.
local edits = {
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
	-- Round 48 (plant-growth-plan.md §2.6-§2.7, §2.15-§2.16, §3.11): Melon and
	-- Mushroom are crops, each harvest makes two seeds or spores; Salt Crust
	-- is no crop (its seed row goes) and comes from the Salt Pan: 3 Embersteel
	-- Bars, a filled Water Bucket (used up) and 1 Salt Crust.
	{output = "grug_farming:seed_melon", count = 2, added = {
		{item = "grug_gathering:melon", n = 1}}},
	{output = "grug_farming:seed_mushroom", count = 2, added = {
		{item = "grug_gathering:mushroom", n = 1}}},
	{output = "grug_farming:seed_salt_crust", signature = "grug_cooking:salt_crust*1",
		was = 2, removed = true},
	{output = "grug_farming:salt_pan", count = 1, added = {
		{item = "grug_materials:embersteel_bar", n = 3},
		{item = "grug_farming:water_bucket", n = 1},
		{item = "grug_cooking:salt_crust", n = 1}}},
	-- Round 57 lane ALLOY (the user's ruling 2 of 2026-10-23): the graded
	-- wood is flat like the alloys. Each grade from Polished up is 2 planks
	-- plus one unit of its tier's own ingredient (T2 Iron Bar, T3
	-- Anthracite, T4 Silver Bar, T5 Emberglass, T6 Abyssal Crystal), no
	-- longer the grade below plus a plank; Seasoned stays 2 planks.
	{output = "grug_artisans:polished_wood", was = 1, removed = true,
		signature = "group:wood*1+grug_artisans:seasoned_wood*1"},
	{output = "grug_artisans:hardened_wood", was = 1, removed = true,
		signature = "group:wood*1+grug_artisans:polished_wood*1"},
	{output = "grug_artisans:inlaid_wood", was = 1, removed = true,
		signature = "group:wood*1+grug_artisans:hardened_wood*1"},
	{output = "grug_artisans:lacquered_wood", was = 1, removed = true,
		signature = "group:wood*1+grug_artisans:inlaid_wood*1"},
	{output = "grug_artisans:heartwood_wood", was = 1, removed = true,
		signature = "group:wood*1+grug_artisans:lacquered_wood*1"},
	{output = "grug_artisans:polished_wood", count = 1, added = {
		{group = "wood", n = 2}, {item = "grug_materials:iron_bar", n = 1}}},
	{output = "grug_artisans:hardened_wood", count = 1, added = {
		{group = "wood", n = 2}, {item = "grug_materials:anthracite", n = 1}}},
	{output = "grug_artisans:inlaid_wood", count = 1, added = {
		{group = "wood", n = 2}, {item = "grug_materials:silver_bar", n = 1}}},
	{output = "grug_artisans:lacquered_wood", count = 1, added = {
		{group = "wood", n = 2}, {item = "grug_materials:emberglass", n = 1}}},
	{output = "grug_artisans:heartwood_wood", count = 1, added = {
		{group = "wood", n = 2}, {item = "grug_materials:abyssal_crystal", n = 1}}},
	-- Round 57 lane ALLOY (ruling 3): Steel Bars, the Steel Bar Door's and
	-- Trapdoor's input, lost their recipe with default:steel_ingot; they come
	-- back as the panes' pattern (6 glass -> 16 panes) with the Steel Bar:
	-- 6 Steel Bars -> 16 Steel Bars (minetest_game xpanes, 3x2 steel ingots).
	{output = "xpanes:bar_flat", count = 16, added = {
		{item = "grug_materials:steel_bar", n = 6}}},
	-- Round 57 lane DYES (ruling 29): every dye reachable from what anyone
	-- gathers. The flower recipes went with the flowers mod, so only Black
	-- (coal) and Violet (blueberries) had a source, and the mixes hold two
	-- loops (Red, Magenta, Pink; Blue, Cyan, Green). One plain plant or
	-- mob drop each, after Blueberries -> 2 Violet: White, Yellow, and one
	-- dye in each loop (Red, Cyan); the mixes make the other nine. The user
	-- picked Bone for White and Apple for Red (no new items or mechanics).
	{output = "dye:white", count = 2, added = {{item = "grug_mobs:bone", n = 1}}},
	{output = "dye:yellow", count = 2, added = {{item = "grug_gathering:sunleaf", n = 1}}},
	{output = "dye:red", count = 2, added = {{item = "default:apple", n = 1}}},
	{output = "dye:cyan", count = 2, added = {{item = "grug_gathering:marshbloom", n = 1}}},
	-- Round 67 ruling 12: bush stems drop one plank of their wood when dug
	-- (default/nodes.lua), so the stem-to-plank rows go.
	{output = "default:wood", signature = "default:bush_stem*1", was = 1, removed = true},
	{output = "default:acacia_wood", signature = "default:acacia_bush_stem*1", was = 1,
		removed = true},
	{output = "default:pine_wood", signature = "default:pine_bush_stem*1", was = 1,
		removed = true},
	-- Round 67 lane CONTAINERS (rulings 29 and 31, the locked-chest default):
	-- one recipe per container and tier. The locked chest is the open
	-- chest's ingredients plus 1 Iron Bar (the "chest + Iron Bar" row goes);
	-- Steel-Reinforced adds 8 Steel Bars to the wooden tier's recipe,
	-- Abyssal 8 more Abyssal Steel Bars; the shelves follow the same pattern
	-- from their own base recipe.
	{output = "default:chest_locked", signature = "default:chest*1+grug_materials:iron_bar*1",
		was = 1, removed = true},
	{output = "default:chest_steel", count = 1, added = {
		{group = "wood", n = 8}, {item = "grug_materials:steel_bar", n = 8}}},
	{output = "default:chest_abyssal", count = 1, added = {
		{group = "wood", n = 8}, {item = "grug_materials:steel_bar", n = 8},
		{item = "grug_materials:abyssal_steel_bar", n = 8}}},
	{output = "default:chest_locked_steel", count = 1, added = {
		{group = "wood", n = 8}, {item = "grug_materials:steel_bar", n = 8},
		{item = "grug_materials:iron_bar", n = 1}}},
	{output = "default:chest_locked_abyssal", count = 1, added = {
		{group = "wood", n = 8}, {item = "grug_materials:steel_bar", n = 8},
		{item = "grug_materials:abyssal_steel_bar", n = 8}, {item = "grug_materials:iron_bar", n = 1}}},
	{output = "default:bookshelf_steel", count = 1, added = {
		{group = "wood", n = 6}, {item = "default:book", n = 3},
		{item = "grug_materials:steel_bar", n = 8}}},
	{output = "default:bookshelf_abyssal", count = 1, added = {
		{group = "wood", n = 6}, {item = "default:book", n = 3},
		{item = "grug_materials:steel_bar", n = 8}, {item = "grug_materials:abyssal_steel_bar", n = 8}}},
	{output = "vessels:shelf_steel", count = 1, added = {
		{group = "wood", n = 6}, {group = "vessel", n = 3},
		{item = "grug_materials:steel_bar", n = 8}}},
	{output = "vessels:shelf_abyssal", count = 1, added = {
		{group = "wood", n = 6}, {group = "vessel", n = 3},
		{item = "grug_materials:steel_bar", n = 8}, {item = "grug_materials:abyssal_steel_bar", n = 8}}},
}

-- Round 67 ruling 13: the metal rods leave the game (their items and the
-- rod variants of sword, dagger and greataxe go in grug_professions); four
-- rods from two bars of each metal.
for _, metal in ipairs({"bronze", "iron", "steel", "silversteel", "embersteel",
		"abyssal_steel"}) do
	edits[#edits + 1] = {output = "grug_professions:metal_rod_" .. metal,
		signature = "grug_materials:" .. metal .. "_bar*2", was = 4, removed = true}
end

-- Round 67 ruling 11: stairs and slabs are end products. The family's
-- routes back to the block (3 blocks from 4 stairs, 1 from 2 slabs) go for
-- every stairs material; gen_basic_recipes.lua asserts that each material
-- of the family lists both here, and registry.lua makes only the four
-- forward shapes.
for _, sub in ipairs({"acacia_wood", "aspen_wood", "brick", "cobble", "desert_cobble",
		"desert_sandstone", "desert_sandstone_block", "desert_sandstone_brick",
		"desert_stone", "desert_stone_block", "desert_stonebrick", "glass", "ice",
		"junglewood", "mossycobble", "obsidian", "obsidian_block", "obsidian_glass",
		"obsidianbrick", "pine_wood", "sandstone", "sandstone_block", "sandstonebrick",
		"snowblock", "stone", "stone_block", "stonebrick", "wood"}) do
	local block = "default:" .. sub
	edits[#edits + 1] = {output = block, signature = "stairs:stair_" .. sub .. "*4",
		was = 3, removed = true}
	edits[#edits + 1] = {output = block, signature = "stairs:slab_" .. sub .. "*2",
		was = 1, removed = true}
end

return edits
