-- Every ore registration of this game. default's own register_ores() is
-- deliberately not called (tail of mods/BASE/default/mapgen.lua), so this file
-- is the single owner.
--
-- Origin: the blob ores and the general shape are minetest_game's
-- default.register_ores(), minus the desert stratum ores (we have no desert
-- biomes) and with the blob biome lists mapped to our biome names. The scatter
-- VALUES are no longer minetest_game's: Gold and the resources now called
-- Emberglass and Diamond were pushed deeper early on, Iron and Copper were
-- retuned, and WP25 re-cut the deep half of the table. WP43 keeps that useful
-- scatter geometry only as the pre-WP40 migration baseline. Canonical IDs,
-- tiers and placement data come from grug_materials; do not restore legacy
-- names or treat these bands as the final regional supply map.
--
-- REGISTRATION ORDER IS THE MECHANISM OF THIS FILE. Read this before moving
-- anything:
--
-- In mgv7 a mapchunk is built caves first (mapgen_v7.cpp:335), then ores
-- (:355, placeAllOres), then dungeons (:359). Within placeAllOres the ores run
-- in REGISTRATION order, and every ore here only converts nodes matching its
-- `wherein`. Three consequences we rely on:
--
--  1. The strata (bottom of this file) are registered LAST, `wherein =
--     "default:stone"`. By the time they run, every scatter and blob ore has
--     already replaced its nodes and is no longer `default:stone`, so the
--     strata flow around the veins and leave them intact. That is why NOT ONE
--     `wherein` in this file had to be touched for the strata, and why an ore
--     added below the loop would silently be swallowed by them.
--  2. Ores run AFTER the caves, so a cave wall dug out at −600 is stone that
--     the granite stratum then converts: cave walls inherit their stratum for
--     free. Natural access is still decided from the exact target y by the
--     WP43 mining transaction; the inherited stratum is visual language and
--     makes the generated cave wall part of the explicit natural taxonomy.
--  3. Dungeons run after the ores, so dungeon walls are NOT stratum rock.
--     Accepted: dungeon rooms are loot, not a mining shortcut.
--
-- Blob ores first so scatter ores don't end up inside blobs.

core.register_ore({
	ore_type = "blob",
	ore = "default:clay",
	wherein = {"default:sand"},
	clust_scarcity = 16 * 16 * 16,
	clust_size = 5,
	y_max = 0,
	y_min = -15,
	noise_threshold = 0.0,
	noise_params = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = -316,
		octaves = 1,
		persist = 0.0
	},
})

core.register_ore({
	ore_type = "blob",
	ore = "default:silver_sand",
	wherein = {"default:stone"},
	clust_scarcity = 16 * 16 * 16,
	clust_size = 5,
	y_max = 31000,
	y_min = -31000,
	noise_threshold = 0.0,
	noise_params = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = 2316,
		octaves = 1,
		persist = 0.0
	},
})

core.register_ore({
	ore_type = "blob",
	ore = "default:dirt",
	wherein = {"default:stone"},
	clust_scarcity = 16 * 16 * 16,
	clust_size = 5,
	y_max = 31000,
	y_min = -31,
	noise_threshold = 0.0,
	noise_params = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = 17676,
		octaves = 1,
		persist = 0.0
	},
	-- Only in the biomes whose ground is dirt (node_top of the dirt family
	-- over a default:dirt filler, biomes.lua). Left out on purpose: savanna
	-- (dry dirt, as in minetest_game), badlands AND its WP36 east wing
	-- grug_badlands_east (both mesa clay top over a mesa clay filler), crags
	-- (gravel), swamp (mud), beach/ocean (sand).
	-- LANDMINE (biomes.lua, 2026-08-08): grug_deep_forest ships as SEVERAL
	-- registrations since the capital-guarantee carve, and a sibling is a
	-- separate biome NAME. All of them belong here — a missing sibling
	-- silently loses its dirt blobs, because the names that ARE listed
	-- resolve and the def stays biome-restricted. Keep the list tight in the
	-- other direction too: grug_meadows_front/_back disappeared again when the
	-- centre band collapsed back to one cuboid, and a stale name only earns a
	-- log warning — it is the kind of dead entry that survives for years.
	-- grug_deep_jungle stays listed although WP36 gave it its own node_top:
	-- the TOP changed, the `default:dirt` FILLER did not, which is what this
	-- blob replaces.
	biomes = {"grug_meadows", "grug_pine_hills", "grug_elf_forest",
		"grug_deep_forest", "grug_deep_forest_front", "grug_deep_forest_east",
		"grug_blight", "grug_bone_forest",
		"grug_jungle_edge", "grug_deep_jungle", "grug_jungle_fringe"},
})

core.register_ore({
	ore_type = "blob",
	ore = "default:gravel",
	wherein = {"default:stone"},
	clust_scarcity = 16 * 16 * 16,
	clust_size = 5,
	y_max = 31000,
	y_min = -31000,
	noise_threshold = 0.0,
	noise_params = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = 766,
		octaves = 1,
		persist = 0.0
	},
})

-- Scatter ores: {ore, {clust_scarcity, clust_num_ores, clust_size, y_max, y_min}, ...}
--
-- TRANSITIONAL PLACEMENT (WP43): these are the surviving WP25 scatter bands,
-- not an access rule and not WP40's final universal/regional distribution.
-- Exact target y controls natural pick access, while each resource registry
-- row independently controls the minimum harvest tier. WP40 replaces this
-- geometry from RACE_REGIONS/DENSITY; until then mapgen resolves every node
-- through resource_node() so no second itemstring inventory can drift.
--
-- GEM DENSITY ("reagent calibration", decided 2026-08-08): quartz sits at iron
-- density, garnet at copper density, silver denser than garnet. That looks
-- generous for "gems" on purpose — items_crafting.md §6.4 makes one cut gem a
-- cost of EVERY fine recipe, which turns a gem into a reagent, not a rarity.
-- Re-tune against §2.4 after the first runtime test.

local function resource_node(key)
	local node = grug_materials.resource_node(key)
	if not node then
		error("grug_mapgen: unknown material resource " .. key)
	end
	return node
end

local scatter_ores = {
	{resource_node("coal"),
		{8 * 8 * 8, 9, 3, 31000, 1025},
		{8 * 8 * 8, 8, 3, 64, -127},
		{12 * 12 * 12, 30, 5, -128, -31000}},
	{resource_node("tin"),
		{10 * 10 * 10, 5, 3, 31000, 1025},
		{13 * 13 * 13, 4, 3, -64, -127},
		{10 * 10 * 10, 5, 3, -128, -31000}},
	{resource_node("copper"),
		{9 * 9 * 9, 5, 3, 31000, 1025},
		{12 * 12 * 12, 4, 3, -64, -127},
		{9 * 9 * 9, 5, 3, -128, -31000}},
	-- The WP25 Iron bands remain as running scatter geometry. Iron is a T1
	-- harvest resource; natural-depth access still follows the exact target y.
	{resource_node("iron"),
		{9 * 9 * 9, 12, 3, 31000, 1025},
		{10 * 10 * 10, 5, 3, -1, -100},
		{7 * 7 * 7, 5, 3, -101, -255},
		{12 * 12 * 12, 29, 5, -256, -31000}},
	{resource_node("gold"),
		{13 * 13 * 13, 5, 3, 31000, 1025},
		{15 * 15 * 15, 3, 2, -256, -511},
		{13 * 13 * 13, 5, 3, -512, -31000}},
	-- Emberglass currently starts in the T4 depth band (−501 … −700) and stays
	-- available below it. Its independent minimum harvest tier is T4.
	-- The old mountain band (y >= 1025) is dropped, not moved: no terrain in
	-- this game reaches it. Our base terrain (init.lua, mgv7_np_terrain_base
	-- offset 14 / scale 70, 5 octaves, persist 0.6) tops out around y 175, and
	-- mgv7's mountain layer -- which IS on, MGV7_MOUNTAINS is in the default
	-- spflags -- adds at most mount_zero_level + max(np_mountain) *
	-- max(np_mount_height) ~= 0 + 1.83 * 475 ~= y 870 in the theoretical case
	-- where both noises peak together (mapgen_v7.cpp:143/145, :423-428). Still
	-- below 1025, so the band was dead code inherited from minetest_game. Same
	-- reason it is absent from every new row below.
	-- HONEST NOTE: coal, tin, copper, iron and gold above still carry their
	-- y >= 1025 bands, which are dead for exactly the same reason. They are
	-- left standing because WP25 only re-cuts the bands the material ladder
	-- depends on; sweeping the rest is a separate, purely cosmetic pass.
	{resource_node("emberglass"),
		{12 * 12 * 12, 4, 3, -501, -700},
		{14 * 14 * 14, 5, 3, -701, -31000}},
	-- Diamond is a regional G2 resource with harvest tier T4. Its current global
	-- deep placement is transitional; WP40 replaces it with race-region supply.
	{resource_node("diamond"),
		{15 * 15 * 15, 4, 3, -1001, -31000}},
	-- Quartz, Silver and Garnet retain their current bands until WP40. Their
	-- harvest tiers are T1, T3 and T2 respectively, owned by the registry.
	{resource_node("quartz"),
		{8 * 8 * 8, 6, 3, -101, -300}},
	{resource_node("silver"),
		{9 * 9 * 9, 5, 3, -301, -500}},
	{resource_node("garnet"),
		{10 * 10 * 10, 4, 3, -501, -700}},
	-- Storage blocks are deliberately absent: mapgen places natural resource
	-- nodes only. A nine-unit block is player-built, drops itself and never
	-- participates in natural depth or harvest checks.
}

for _, entry in ipairs(scatter_ores) do
	for i = 2, #entry do
		local p = entry[i]
		core.register_ore({
			ore_type = "scatter",
			ore = entry[1],
			wherein = "default:stone",
			clust_scarcity = p[1],
			clust_num_ores = p[2],
			clust_size = p[3],
			y_max = p[4],
			y_min = p[5],
		})
	end
end

-- The six rock strata (world.md §2 R6, items_crafting.md §3.0.1/§3.0.4).
--
-- REGISTERED LAST, ON PURPOSE — see the ordering note at the top of the file:
-- every vein above is already placed and is no longer `default:stone`, so the
-- strata cannot eat it.
--
-- Tier 1 gets NO registration at all: `default:stone` IS the T1 stratum and
-- carries the explicit natural/stratum groups. Registering a second T1 stone
-- would rewrite the whole surface layer for nothing and would break every
-- `wherein = "default:stone"` above it.
--
-- No `noise_params` and no `np_stratum_thickness`: per lua_api.md:5244-5245 an
-- omitted `noise_params` gives exactly the flat horizontal stratum from y_min
-- to y_max that R6's hard boundaries call for, and per lua_api.md:5250-5251
-- leaving both noises out makes generation markedly cheaper — which is what we
-- want when adding five of them. `clust_scarcity = 1` is the documented value
-- for a solid (gapless) stratum, lua_api.md:5257-5258.
--
-- No `biomes` field, ALSO on purpose: the strata are meant to be world-wide,
-- identical on the continent and under the housing isles (world.md §2 R6).
-- This is NOT the known landmine of a mistyped biome name silently going
-- world-wide (AGENTS.md, "Mapgen/biomes") — there is no list to mistype here.
for i = 2, #grug_materials.TIERS do
	local tier = grug_materials.TIERS[i]
	core.register_ore({
		ore_type = "stratum",
		ore = tier.node,
		wherein = "default:stone",
		clust_scarcity = 1,
		y_max = tier.y_max,
		y_min = tier.y_min,
	})
end
