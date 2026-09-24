-- The WP13 settlements. One pure successor per settlement clips its
-- blueprints to the current mapchunk owner and mutates bytes only through
-- R7's private writer.
--
-- The first increment hard-wired Hearthpine Vale into this file. From the
-- fourth increment on the same code served every START: a settlement was a
-- profile in `M.roster` plus one blueprint. This increment generalises that
-- seam to the capitals of `docs/research/wp13-capitals-pois-contract.md`
-- section 2.2, and the four things it adds are the whole of that section:
--
--   1. A profile carries its `slot` (the anchor slot the zone session
--      resolves) and its BOUNDS, so the literal +-63 / y -2..24 of the start
--      is now the start profile's own value in `M.BOUNDS` and a capital core
--      or district plot carries its own. The three places that literal used
--      to be typed -- the bounds check, the per-cell range and the manifest's
--      identity row -- all read it from here now.
--   2. A settlement may own SEVERAL BLUEPRINTS. `M.prepare` turns whatever
--      the profile's blueprint file returns into an ordered list of blueprint
--      descriptors, each with its own identity SHA-256, and the manifest
--      publishes one identity block per descriptor in that order.
--   3. A blueprint is one of three KINDS, and the kind is what decides how
--      its cells reach the world:
--        "anchor"    -- anchor-relative, exactly like a start: the cell at
--                       local y = 0 lands on the settlement's fitted anchor.
--        "reference" -- terrain-relative: the descriptor carries the plot's
--                       offset from the anchor and the plot carries its own
--                       REFERENCE COLUMN, whose pure final height is asked
--                       ONCE per session and cached. A capital's district
--                       plots stand on terraced ground and cannot be
--                       anchor-relative.
--        "overlay"   -- no cells at all until a surface is handed to it: the
--                       avenues are a pure function of the plan's own column
--                       surface, evaluated per mapchunk (`wp13/avenue.lua`).
--      An overlay's identity is therefore its SPECIFICATION -- the runs, the
--      carriageway width, the lamp rhythm, the look-around and the exact set
--      of node names it may write -- because it has no cells to hash.
--   4. LAZY CONSTRUCTION. A profile marked `lazy` keeps no cells at all until
--      the first `bind_plan` whose mapchunk touches the blueprint's envelope,
--      and drops them again once `IDLE_RELEASE` consecutive plans have
--      touched nothing of it. Identity is NOT lazy: the manifest is a closed
--      document, so every blueprint is built once at load, hashed, and its
--      cells released. What lazy construction hides is the 100,000-cell
--      buffer, not the digest. Starts stay eager: they are small and the
--      spawn depends on them.
--
-- Hearthpine keeps every schema string and every identity byte it had, so its
-- blueprint identity SHA-256 -- and every other start's -- is unchanged by the
-- generalisation.
--
-- `content` is the ONE shared opcode-37 settlement content channel
-- (`r7_content.lua`): a cell's `content_ref` indexes the sorted union of
-- every settlement's palette, not this blueprint's own palette.
--
-- Plain Lua 5.1, no globals.

local M = {}
local module_info = debug and debug.getinfo and debug.getinfo(1, "S")
local module_dir = type(module_info)=="table" and type(module_info.source)=="string" and
	module_info.source:sub(1,1)=="@" and module_info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
if not module_dir or module_dir=="" then module_dir=core.get_modpath("grug_mapgen").."/wp40" end
local round20_catalog = dofile(module_dir.."/r20_poi_catalog.lua")
local plot_approach = dofile(module_dir.."/../wp13/plot_approach.lua")
local approach_palettes = dofile(module_dir.."/../wp13/palette.lua")

-- The authorized volume per blueprint kind (contract sections 2.1 and 2.2).
-- The start's numbers are the literal the first four increments typed in
-- three places; they are data now and nothing else changed about them.
M.BOUNDS = {
	start = {min = {x = -63, y = -2, z = -63}, max = {x = 63, y = 24, z = 63}},
	capital_core = {min = {x = -49, y = -2, z = -49}, max = {x = 49, y = 40, z = 49}},
	capital_plot = {min = {x = -15, y = -6, z = -15}, max = {x = 15, y = 24, z = 15}},
	-- The avenues are the one blueprint that legitimately leaves the civic
	-- core: they run to the gate stations at +-256. Their authorized volume is
	-- therefore the capital's own HARD PROTECTION -- the 532-node square of
	-- `source/simple_map.lua`'s `hard_capital_build_plus_apron_v1`, 266 either
	-- side of the anchor. A road outside it would write mutable world, which is
	-- what that protection exists to prevent, so the envelope and the
	-- protection are deliberately the same number in one place.
	capital_overlay = {min = {x = -266, y = -2, z = -266},
		max = {x = 266, y = 40, z = 266}},
	-- Authored POIs stay inside the exact half-open flat terrain cores.
	poi = {min = {x = -12, y = 0, z = -12}, max = {x = 11, y = 8, z = 11}},
	poi_outpost = {min = {x = -8, y = 0, z = -8}, max = {x = 7, y = 8, z = 7}},
}

-- How many consecutive plans may miss a lazy settlement before its cells are
-- released. A mapchunk is 80 nodes, so 64 plans is the emerge thread walking
-- well clear of a 512-node capital envelope and not coming back; a player
-- walking up and down one avenue never pays a rebuild.
M.IDLE_RELEASE = 64

-- Starts carry Cooking at a core landmark. Capital services are authored in
-- their themed outer plots, including explicit public-station node sockets.
local START_TRAINERS = {
	hearthpine = {x = 2, y = 1, z = 10, dir = {x = -1, z = 0}},
	dawnmere = {x = 2, y = 1, z = 10, dir = {x = -1, z = 0}},
	silverleaf = {x = 2, y = 1, z = 10, dir = {x = -1, z = 0}},
	stillgrave = {x = 2, y = 1, z = -10, dir = {x = -1, z = 0}},
	sunscar = {x = 2, y = 1, z = -10, dir = {x = -1, z = 0}},
	kapok = {x = 2, y = 1, z = -10, dir = {x = -1, z = 0}},
}


-- Fixed order. The successor settles the roster in this order, and the
-- manifest publishes one identity block per blueprint of each row in the same
-- order.
--
-- `race` names the `palette.races` entry the composition builds from. It is
-- the ONE place a settlement is tied to a race, and `tools/wp13/library_kat.lua`
-- reads it to check a start's window vocabulary and its ground cover against
-- that race's palette alone instead of guessing from the node names, which
-- can match two races at once.
--
-- `slot` is the anchor slot the zone session answers under, and `bounds` names
-- the `M.BOUNDS` entry the settlement's primary blueprint is held to.
M.roster = {
	{
		key = "hearthpine", label = "Hearthpine", race = "dwarf",
		slot = "start", bounds = "start",
		zone_id = "elandor_hearthpine_vale",
		anchor_id = "anchor_001", numeric_id = 1, x = -1800, z = -2550,
		blueprint_file = "r7_hearthpine_blueprint.lua",
		blueprint_schema = "grug_wp13_hearthpine_blueprint_v1",
		identity_schema = "grug_wp13_hearthpine_blueprint_identity_v1",
		config_schema = "grug_wp13_hearthpine_config_v1",
		ledger_schema = "grug_wp13_hearthpine_ledger_v1",
		metrics_schema = "grug_wp13_hearthpine_metrics_v1",
		delta_schema = "grug_wp13_hearthpine_delta_v1",
	},
	{
		key = "dawnmere", label = "Dawnmere", race = "human",
		slot = "start", bounds = "start",
		zone_id = "elandor_dawnmere_fields",
		anchor_id = "anchor_002", numeric_id = 2, x = 0, z = -2550,
		blueprint_file = "r7_dawnmere_blueprint.lua",
		blueprint_schema = "grug_wp13_dawnmere_blueprint_v1",
		identity_schema = "grug_wp13_dawnmere_blueprint_identity_v1",
		config_schema = "grug_wp13_dawnmere_config_v1",
		ledger_schema = "grug_wp13_dawnmere_ledger_v1",
		metrics_schema = "grug_wp13_dawnmere_metrics_v1",
		delta_schema = "grug_wp13_dawnmere_delta_v1",
	},
	{
		key = "silverleaf", label = "Silverleaf", race = "elf",
		slot = "start", bounds = "start",
		zone_id = "elandor_silverleaf_glades",
		anchor_id = "anchor_003", numeric_id = 3, x = 1800, z = -2550,
		blueprint_file = "r7_silverleaf_blueprint.lua",
		blueprint_schema = "grug_wp13_silverleaf_blueprint_v1",
		identity_schema = "grug_wp13_silverleaf_blueprint_identity_v1",
		config_schema = "grug_wp13_silverleaf_config_v1",
		ledger_schema = "grug_wp13_silverleaf_ledger_v1",
		metrics_schema = "grug_wp13_silverleaf_metrics_v1",
		delta_schema = "grug_wp13_silverleaf_delta_v1",
	},
	{
		key = "stillgrave", label = "Stillgrave", race = "undead",
		slot = "start", bounds = "start",
		zone_id = "kragmar_stillgrave_hollow",
		anchor_id = "anchor_004", numeric_id = 4, x = -1800, z = 2550,
		blueprint_file = "r7_stillgrave_blueprint.lua",
		blueprint_schema = "grug_wp13_stillgrave_blueprint_v1",
		identity_schema = "grug_wp13_stillgrave_blueprint_identity_v1",
		config_schema = "grug_wp13_stillgrave_config_v1",
		ledger_schema = "grug_wp13_stillgrave_ledger_v1",
		metrics_schema = "grug_wp13_stillgrave_metrics_v1",
		delta_schema = "grug_wp13_stillgrave_delta_v1",
	},
	{
		key = "sunscar", label = "Sunscar", race = "orc",
		slot = "start", bounds = "start",
		zone_id = "kragmar_sunscar_flats",
		anchor_id = "anchor_005", numeric_id = 5, x = 0, z = 2550,
		blueprint_file = "r7_sunscar_blueprint.lua",
		blueprint_schema = "grug_wp13_sunscar_blueprint_v1",
		identity_schema = "grug_wp13_sunscar_blueprint_identity_v1",
		config_schema = "grug_wp13_sunscar_config_v1",
		ledger_schema = "grug_wp13_sunscar_ledger_v1",
		metrics_schema = "grug_wp13_sunscar_metrics_v1",
		delta_schema = "grug_wp13_sunscar_delta_v1",
	},
	{
		key = "kapok", label = "Kapok", race = "troll",
		slot = "start", bounds = "start",
		zone_id = "kragmar_kapok_cradle",
		anchor_id = "anchor_006", numeric_id = 6, x = 1800, z = 2550,
		blueprint_file = "r7_kapok_blueprint.lua",
		blueprint_schema = "grug_wp13_kapok_blueprint_v1",
		identity_schema = "grug_wp13_kapok_blueprint_identity_v1",
		config_schema = "grug_wp13_kapok_config_v1",
		ledger_schema = "grug_wp13_kapok_ledger_v1",
		metrics_schema = "grug_wp13_kapok_metrics_v1",
		delta_schema = "grug_wp13_kapok_delta_v1",
	},
	-- The first capital (contract section 3, third increment): a core in the
	-- start's shape, 36 terrain-relative district plots -- four districts of
	-- nine, one per quadrant -- and the avenue overlay, built lazily.
	-- `plot_bounds` is the envelope every "reference" blueprint of this
	-- settlement is held to.
	{
		key = "highcourt", label = "Highcourt", race = "human",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "elandor_highcourt",
		anchor_id = "anchor_008", numeric_id = 8, x = 0, z = -1500,
		blueprint_file = "r7_highcourt_blueprint.lua",
		blueprint_schema = "grug_wp13_highcourt_core_v1",
		identity_schema = "grug_wp13_highcourt_core_identity_v1",
		config_schema = "grug_wp13_highcourt_config_v1",
		ledger_schema = "grug_wp13_highcourt_ledger_v1",
		metrics_schema = "grug_wp13_highcourt_metrics_v1",
		delta_schema = "grug_wp13_highcourt_delta_v1",
		-- The guard banner the anchor writer puts at (x, y + 1, z) of every
		-- capital anchor stands on this core's own paving, and the composition
		-- has nothing but air in that cell, so the writer RESERVES it instead
		-- of overwriting the banner with that air. See the settle loop for the
		-- whole argument.
		reserve_anchor_root = true,
	},
	-- The second capital, and the first WALLED one (the user's ruling of
	-- 2026-09-14: walls for Dur Brannoc, Nhal Veyr and Gor Drazhak). Its
	-- overlay carries twenty runs -- four avenues, four sides of the ring
	-- street, eight district lanes and the four sides of the curtain wall --
	-- because the wall follows the terraced ground exactly the way the road
	-- does and belongs to the same kind of blueprint
	-- (`r7_dur_brannoc_blueprint.lua`). Since the wave-2 upgrade of 2026-09-15
	-- it carries four districts of nine plots and four dressings each, exactly
	-- like Highcourt, with the quadrant permutation of
	-- `wp13/dur_brannoc_quadrants.lua`.
	{
		key = "dur_brannoc", label = "Dur Brannoc", race = "dwarf",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "elandor_dur_brannoc",
		anchor_id = "anchor_007", numeric_id = 7, x = -1800, z = -1500,
		blueprint_file = "r7_dur_brannoc_blueprint.lua",
		blueprint_schema = "grug_wp13_dur_brannoc_core_v1",
		identity_schema = "grug_wp13_dur_brannoc_core_identity_v1",
		config_schema = "grug_wp13_dur_brannoc_config_v1",
		ledger_schema = "grug_wp13_dur_brannoc_ledger_v1",
		metrics_schema = "grug_wp13_dur_brannoc_metrics_v1",
		delta_schema = "grug_wp13_dur_brannoc_delta_v1",
		-- Same reservation as Highcourt's, for the same reason: the anchor
		-- writer puts one `grug_nodes:guard_banner` at (x, y + 1, z) of every
		-- capital anchor and runs BEFORE the settlement writer, and this core
		-- has air at exactly that cell -- the crossing of the two great
		-- avenues. The banner is `walkable = false`, so a five-wide gate road
		-- crossing stays five wide.
		reserve_anchor_root = true,
	},
	-- The third capital, and the second WALLED one. Its city wall is not a
	-- curtain: the capitals contract's section 2.4 orc line is "palisade and
	-- earthworks", so the four rampart runs are `wp13/orc_palisade.lua` -- a
	-- stake stockade on a dug bank -- in the same overlay as the roads, on the
	-- same seam and the same constants `wp13/wall.lua` uses. Twenty runs: four
	-- avenues, four sides of the ring street, eight district lanes and the four
	-- sides of the rampart.
	{
		key = "gor_drazhak", label = "Gor Drazhak", race = "orc",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "kragmar_gor_drazhak",
		anchor_id = "anchor_011", numeric_id = 11, x = 0, z = 1500,
		blueprint_file = "r7_gor_drazhak_blueprint.lua",
		blueprint_schema = "grug_wp13_gor_drazhak_core_v1",
		identity_schema = "grug_wp13_gor_drazhak_core_identity_v1",
		config_schema = "grug_wp13_gor_drazhak_config_v1",
		ledger_schema = "grug_wp13_gor_drazhak_ledger_v1",
		metrics_schema = "grug_wp13_gor_drazhak_metrics_v1",
		delta_schema = "grug_wp13_gor_drazhak_delta_v1",
		-- Same reservation as Highcourt's and Dur Brannoc's, for the same
		-- reason: the anchor writer puts one `grug_nodes:guard_banner` at
		-- (x, y + 1, z) of every capital anchor and runs BEFORE the settlement
		-- writer, and this core has air at exactly that cell -- the crossing of
		-- the two great avenues. The banner is `walkable = false`, so a
		-- five-wide gate road crossing stays five wide.
		reserve_anchor_root = true,
	},
	-- The fourth capital, and the second OPEN one (the user's ruling of
	-- 2026-09-14: open edges for Highcourt, Lethariel and Kezamba; the
	-- round-3 plan later moved Highcourt to the walled side and left Lethariel
	-- and Kezamba open). Its overlay carries nineteen runs -- four avenues,
	-- four sides of the ring street, seven district lanes and the four sides of
	-- the GROVE EDGE, which is what an open capital has where a walled one has
	-- a curtain (`r7_lethariel_blueprint.lua`).
	--
	-- It is also the only capital whose 96 x 96 civic core is not a full pad:
	-- WP40 leaves a planned lake inside it, and the composition writes nothing
	-- over the water rather than hanging a slab of turf thirteen nodes above
	-- it. See `wp13/lethariel.lua`.
	{
		key = "lethariel", label = "Lethariel", race = "elf",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "elandor_lethariel",
		anchor_id = "anchor_009", numeric_id = 9, x = 1800, z = -1500,
		blueprint_file = "r7_lethariel_blueprint.lua",
		blueprint_schema = "grug_wp13_lethariel_core_v1",
		identity_schema = "grug_wp13_lethariel_core_identity_v1",
		config_schema = "grug_wp13_lethariel_config_v1",
		ledger_schema = "grug_wp13_lethariel_ledger_v1",
		metrics_schema = "grug_wp13_lethariel_metrics_v1",
		delta_schema = "grug_wp13_lethariel_delta_v1",
		-- Same reservation as Highcourt's and Dur Brannoc's, for the same
		-- reason: the anchor writer puts one `grug_nodes:guard_banner` at
		-- (x, y + 1, z) of every capital anchor and runs BEFORE the settlement
		-- writer, and this core has air at exactly that cell -- the crossing of
		-- the two great avenues.
		reserve_anchor_root = true,
	},
	-- The fifth capital: the troll one, and the only
	-- capital of the six whose 512 envelope carries an AUTHORED LAKE. WP40's
	-- `hydro_kezamba_cenote` fills 11.5 per cent of it -- essentially the whole
	-- north-east quadrant and a wedge of the civic core itself -- in the same
	-- columns on all nine seeds of `tools/wp13/capital_anchor_fixture.lua`, with
	-- its surface one node below the fitted civic reference. The composition
	-- therefore builds ROUND the water rather than over it, and the roster row
	-- is otherwise an ordinary capital's.
	--
	-- Kezamba is OPEN (the user's ruling of 2026-09-14, unchanged by the round-3
	-- plan that walled Highcourt), so its overlay carries twelve runs and none
	-- of them is a curtain: four avenues, four sides of the ring street and the
	-- four gate thresholds of `wp13/kezamba_gate.lua`.
	{
		key = "kezamba", label = "Kezamba", race = "troll",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "kragmar_kezamba",
		anchor_id = "anchor_012", numeric_id = 12, x = 1800, z = 1500,
		blueprint_file = "r7_kezamba_blueprint.lua",
		blueprint_schema = "grug_wp13_kezamba_core_v1",
		identity_schema = "grug_wp13_kezamba_core_identity_v1",
		config_schema = "grug_wp13_kezamba_config_v1",
		ledger_schema = "grug_wp13_kezamba_ledger_v1",
		metrics_schema = "grug_wp13_kezamba_metrics_v1",
		delta_schema = "grug_wp13_kezamba_delta_v1",
		-- Same reservation as Highcourt's and Dur Brannoc's, for the same
		-- reason: the anchor writer puts one `grug_nodes:guard_banner` at
		-- (x, y + 1, z) of every capital anchor and runs BEFORE the settlement
		-- writer, and this core has air at exactly that cell -- the crossing of
		-- the two great avenues, on the dry side of the cenote. The banner is
		-- `walkable = false`, so a five-wide gate road crossing stays five wide.
		reserve_anchor_root = true,
	},
	-- The third capital, and the second WALLED one (the same user ruling of
	-- 2026-09-14). Nhal Veyr is the undead raised necropolis: four districts of
	-- nine building lots and four fill dressings, assigned to the quadrants by
	-- the world seed exactly as Highcourt's are, and ONE overlay of twenty runs
	-- -- four avenues, four sides of the ring street, eight district lanes and
	-- the four sides of the curtain wall (`r7_nhal_veyr_blueprint.lua`).
	--
	-- LAST in the roster, by the coordinator's ruling at merge. Dur Brannoc,
	-- Gor Drazhak, Lethariel and Kezamba landed on `main` before this lane and
	-- their rows are frozen where they are; appending rather than inserting is
	-- what keeps every one of those capitals' numeric ids, anchor ids and frozen
	-- digests exactly where they were.
	{
		key = "nhal_veyr", label = "Nhal Veyr", race = "undead",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "kragmar_nhal_veyr",
		anchor_id = "anchor_010", numeric_id = 10, x = -1800, z = 1500,
		blueprint_file = "r7_nhal_veyr_blueprint.lua",
		blueprint_schema = "grug_wp13_nhal_veyr_core_v1",
		identity_schema = "grug_wp13_nhal_veyr_core_identity_v1",
		config_schema = "grug_wp13_nhal_veyr_config_v1",
		ledger_schema = "grug_wp13_nhal_veyr_ledger_v1",
		metrics_schema = "grug_wp13_nhal_veyr_metrics_v1",
		delta_schema = "grug_wp13_nhal_veyr_delta_v1",
		-- Same reservation as Highcourt's and Dur Brannoc's, for the same
		-- reason: the anchor writer puts one `grug_nodes:guard_banner` at
		-- (x, y + 1, z) of every capital anchor and runs BEFORE the settlement
		-- writer, and this core has air at exactly that cell -- the crossing of
		-- the two great avenues. The banner is `walkable = false`, so a
		-- five-wide gate road crossing stays five wide.
		reserve_anchor_root = true,
	},
	-- Round 14 starter-story POIs. Appended so every shipped settlement keeps
	-- its roster position. The home villages, corresponding first outposts and
	-- inner bandit camps are the exact stable anchors named by the story catalog.
	{
		key="copperfell_village",label="Copperfell Village",race="dwarf",slot="village_1",bounds="poi",lazy=true,zone_id="elandor_copperfell_foothills",anchor_id="anchor_013",numeric_id=13,x=-1868,z=-2036,blueprint_file="r7_copperfell_village_blueprint.lua",blueprint_schema="grug_r14_copperfell_village_v1",identity_schema="grug_r14_copperfell_village_identity_v1",config_schema="grug_r14_copperfell_village_config_v1",ledger_schema="grug_r14_copperfell_village_ledger_v1",metrics_schema="grug_r14_copperfell_village_metrics_v1",delta_schema="grug_r14_copperfell_village_delta_v1"},
	{
		key="goldmead_village",label="Goldmead Village",race="human",slot="village_1",bounds="poi",lazy=true,zone_id="elandor_goldmead_vale",anchor_id="anchor_015",numeric_id=15,x=-120,z=-2020,blueprint_file="r7_goldmead_village_blueprint.lua",blueprint_schema="grug_r14_goldmead_village_v1",identity_schema="grug_r14_goldmead_village_identity_v1",config_schema="grug_r14_goldmead_village_config_v1",ledger_schema="grug_r14_goldmead_village_ledger_v1",metrics_schema="grug_r14_goldmead_village_metrics_v1",delta_schema="grug_r14_goldmead_village_delta_v1"},
	{
		key="starbough_village",label="Starbough Village",race="elf",slot="village_1",bounds="poi",lazy=true,zone_id="elandor_starbough_vale",anchor_id="anchor_017",numeric_id=17,x=1900,z=-2020,blueprint_file="r7_starbough_village_blueprint.lua",blueprint_schema="grug_r14_starbough_village_v1",identity_schema="grug_r14_starbough_village_identity_v1",config_schema="grug_r14_starbough_village_config_v1",ledger_schema="grug_r14_starbough_village_ledger_v1",metrics_schema="grug_r14_starbough_village_metrics_v1",delta_schema="grug_r14_starbough_village_delta_v1"},
	{
		key="mournfen_village",label="Mournfen Village",race="undead",slot="village_1",bounds="poi",lazy=true,zone_id="kragmar_mournfen",anchor_id="anchor_019",numeric_id=19,x=-1900,z=2020,blueprint_file="r7_mournfen_village_blueprint.lua",blueprint_schema="grug_r14_mournfen_village_v1",identity_schema="grug_r14_mournfen_village_identity_v1",config_schema="grug_r14_mournfen_village_config_v1",ledger_schema="grug_r14_mournfen_village_ledger_v1",metrics_schema="grug_r14_mournfen_village_metrics_v1",delta_schema="grug_r14_mournfen_village_delta_v1"},
	{
		key="redtusk_village",label="Redtusk Village",race="orc",slot="village_1",bounds="poi",lazy=true,zone_id="kragmar_redtusk_savanna",anchor_id="anchor_021",numeric_id=21,x=-88,z=2004,blueprint_file="r7_redtusk_village_blueprint.lua",blueprint_schema="grug_r14_redtusk_village_v1",identity_schema="grug_r14_redtusk_village_identity_v1",config_schema="grug_r14_redtusk_village_config_v1",ledger_schema="grug_r14_redtusk_village_ledger_v1",metrics_schema="grug_r14_redtusk_village_metrics_v1",delta_schema="grug_r14_redtusk_village_delta_v1"},
	{
		key="raincall_village",label="Raincall Village",race="troll",slot="village_1",bounds="poi",lazy=true,zone_id="kragmar_raincall_basin",anchor_id="anchor_023",numeric_id=23,x=1876,z=2044,blueprint_file="r7_raincall_village_blueprint.lua",blueprint_schema="grug_r14_raincall_village_v1",identity_schema="grug_r14_raincall_village_identity_v1",config_schema="grug_r14_raincall_village_config_v1",ledger_schema="grug_r14_raincall_village_ledger_v1",metrics_schema="grug_r14_raincall_village_metrics_v1",delta_schema="grug_r14_raincall_village_delta_v1"},
	{
		key="copperfell_outpost",label="Copperfell Outpost",race="dwarf",slot="outpost_1",bounds="poi_outpost",lazy=true,zone_id="elandor_copperfell_foothills",anchor_id="anchor_025",numeric_id=25,x=-2100,z=-2100,blueprint_file="r7_copperfell_outpost_blueprint.lua",blueprint_schema="grug_r14_copperfell_outpost_v1",identity_schema="grug_r14_copperfell_outpost_identity_v1",config_schema="grug_r14_copperfell_outpost_config_v1",ledger_schema="grug_r14_copperfell_outpost_ledger_v1",metrics_schema="grug_r14_copperfell_outpost_metrics_v1",delta_schema="grug_r14_copperfell_outpost_delta_v1",reserve_anchor_root=true},
	{
		key="goldmead_outpost",label="Goldmead Outpost",race="human",slot="outpost_1",bounds="poi_outpost",lazy=true,zone_id="elandor_goldmead_vale",anchor_id="anchor_029",numeric_id=29,x=176,z=-2026,blueprint_file="r7_goldmead_outpost_blueprint.lua",blueprint_schema="grug_r14_goldmead_outpost_v1",identity_schema="grug_r14_goldmead_outpost_identity_v1",config_schema="grug_r14_goldmead_outpost_config_v1",ledger_schema="grug_r14_goldmead_outpost_ledger_v1",metrics_schema="grug_r14_goldmead_outpost_metrics_v1",delta_schema="grug_r14_goldmead_outpost_delta_v1",reserve_anchor_root=true},
	{
		key="starbough_outpost",label="Starbough Outpost",race="elf",slot="outpost_1",bounds="poi_outpost",lazy=true,zone_id="elandor_starbough_vale",anchor_id="anchor_033",numeric_id=33,x=2100,z=-2100,blueprint_file="r7_starbough_outpost_blueprint.lua",blueprint_schema="grug_r14_starbough_outpost_v1",identity_schema="grug_r14_starbough_outpost_identity_v1",config_schema="grug_r14_starbough_outpost_config_v1",ledger_schema="grug_r14_starbough_outpost_ledger_v1",metrics_schema="grug_r14_starbough_outpost_metrics_v1",delta_schema="grug_r14_starbough_outpost_delta_v1",reserve_anchor_root=true},
	{
		key="mournfen_outpost",label="Mournfen Outpost",race="undead",slot="outpost_1",bounds="poi_outpost",lazy=true,zone_id="kragmar_mournfen",anchor_id="anchor_037",numeric_id=37,x=-2100,z=2100,blueprint_file="r7_mournfen_outpost_blueprint.lua",blueprint_schema="grug_r14_mournfen_outpost_v1",identity_schema="grug_r14_mournfen_outpost_identity_v1",config_schema="grug_r14_mournfen_outpost_config_v1",ledger_schema="grug_r14_mournfen_outpost_ledger_v1",metrics_schema="grug_r14_mournfen_outpost_metrics_v1",delta_schema="grug_r14_mournfen_outpost_delta_v1",reserve_anchor_root=true},
	{
		key="redtusk_outpost",label="Redtusk Outpost",race="orc",slot="outpost_1",bounds="poi_outpost",lazy=true,zone_id="kragmar_redtusk_savanna",anchor_id="anchor_041",numeric_id=41,x=176,z=2074,blueprint_file="r7_redtusk_outpost_blueprint.lua",blueprint_schema="grug_r14_redtusk_outpost_v1",identity_schema="grug_r14_redtusk_outpost_identity_v1",config_schema="grug_r14_redtusk_outpost_config_v1",ledger_schema="grug_r14_redtusk_outpost_ledger_v1",metrics_schema="grug_r14_redtusk_outpost_metrics_v1",delta_schema="grug_r14_redtusk_outpost_delta_v1",reserve_anchor_root=true},
	{
		key="raincall_outpost",label="Raincall Outpost",race="troll",slot="outpost_1",bounds="poi_outpost",lazy=true,zone_id="kragmar_raincall_basin",anchor_id="anchor_045",numeric_id=45,x=2132,z=2084,blueprint_file="r7_raincall_outpost_blueprint.lua",blueprint_schema="grug_r14_raincall_outpost_v1",identity_schema="grug_r14_raincall_outpost_identity_v1",config_schema="grug_r14_raincall_outpost_config_v1",ledger_schema="grug_r14_raincall_outpost_ledger_v1",metrics_schema="grug_r14_raincall_outpost_metrics_v1",delta_schema="grug_r14_raincall_outpost_delta_v1",reserve_anchor_root=true},
	{
		key="copperfell_bandit_camp",label="Copperfell Bandit Camp",race="dwarf",slot="bandit_1",bounds="poi",lazy=true,zone_id="elandor_copperfell_foothills",anchor_id="anchor_049",numeric_id=49,x=-1568,z=-2066,blueprint_file="r7_copperfell_bandit_camp_blueprint.lua",blueprint_schema="grug_r14_copperfell_bandit_camp_v1",identity_schema="grug_r14_copperfell_bandit_camp_identity_v1",config_schema="grug_r14_copperfell_bandit_camp_config_v1",ledger_schema="grug_r14_copperfell_bandit_camp_ledger_v1",metrics_schema="grug_r14_copperfell_bandit_camp_metrics_v1",delta_schema="grug_r14_copperfell_bandit_camp_delta_v1",reserve_anchor_root=true},
	{
		key="goldmead_bandit_camp",label="Goldmead Bandit Camp",race="human",slot="bandit_1",bounds="poi",lazy=true,zone_id="elandor_goldmead_vale",anchor_id="anchor_051",numeric_id=51,x=320,z=-1980,blueprint_file="r7_goldmead_bandit_camp_blueprint.lua",blueprint_schema="grug_r14_goldmead_bandit_camp_v1",identity_schema="grug_r14_goldmead_bandit_camp_identity_v1",config_schema="grug_r14_goldmead_bandit_camp_config_v1",ledger_schema="grug_r14_goldmead_bandit_camp_ledger_v1",metrics_schema="grug_r14_goldmead_bandit_camp_metrics_v1",delta_schema="grug_r14_goldmead_bandit_camp_delta_v1",reserve_anchor_root=true},
	{
		key="starbough_bandit_camp",label="Starbough Bandit Camp",race="elf",slot="bandit_1",bounds="poi",lazy=true,zone_id="elandor_starbough_vale",anchor_id="anchor_053",numeric_id=53,x=1632,z=-2066,blueprint_file="r7_starbough_bandit_camp_blueprint.lua",blueprint_schema="grug_r14_starbough_bandit_camp_v1",identity_schema="grug_r14_starbough_bandit_camp_identity_v1",config_schema="grug_r14_starbough_bandit_camp_config_v1",ledger_schema="grug_r14_starbough_bandit_camp_ledger_v1",metrics_schema="grug_r14_starbough_bandit_camp_metrics_v1",delta_schema="grug_r14_starbough_bandit_camp_delta_v1",reserve_anchor_root=true},
	{
		key="mournfen_bandit_camp",label="Mournfen Bandit Camp",race="undead",slot="bandit_1",bounds="poi",lazy=true,zone_id="kragmar_mournfen",anchor_id="anchor_055",numeric_id=55,x=-1600,z=2050,blueprint_file="r7_mournfen_bandit_camp_blueprint.lua",blueprint_schema="grug_r14_mournfen_bandit_camp_v1",identity_schema="grug_r14_mournfen_bandit_camp_identity_v1",config_schema="grug_r14_mournfen_bandit_camp_config_v1",ledger_schema="grug_r14_mournfen_bandit_camp_ledger_v1",metrics_schema="grug_r14_mournfen_bandit_camp_metrics_v1",delta_schema="grug_r14_mournfen_bandit_camp_delta_v1",reserve_anchor_root=true},
	{
		key="redtusk_bandit_camp",label="Redtusk Bandit Camp",race="orc",slot="bandit_1",bounds="poi",lazy=true,zone_id="kragmar_redtusk_savanna",anchor_id="anchor_057",numeric_id=57,x=320,z=1980,blueprint_file="r7_redtusk_bandit_camp_blueprint.lua",blueprint_schema="grug_r14_redtusk_bandit_camp_v1",identity_schema="grug_r14_redtusk_bandit_camp_identity_v1",config_schema="grug_r14_redtusk_bandit_camp_config_v1",ledger_schema="grug_r14_redtusk_bandit_camp_ledger_v1",metrics_schema="grug_r14_redtusk_bandit_camp_metrics_v1",delta_schema="grug_r14_redtusk_bandit_camp_delta_v1",reserve_anchor_root=true},
	{
		key="raincall_bandit_camp",label="Raincall Bandit Camp",race="troll",slot="bandit_1",bounds="poi",lazy=true,zone_id="kragmar_raincall_basin",anchor_id="anchor_059",numeric_id=59,x=1632,z=2034,blueprint_file="r7_raincall_bandit_camp_blueprint.lua",blueprint_schema="grug_r14_raincall_bandit_camp_v1",identity_schema="grug_r14_raincall_bandit_camp_identity_v1",config_schema="grug_r14_raincall_bandit_camp_config_v1",ledger_schema="grug_r14_raincall_bandit_camp_ledger_v1",metrics_schema="grug_r14_raincall_bandit_camp_metrics_v1",delta_schema="grug_r14_raincall_bandit_camp_delta_v1",reserve_anchor_root=true},
}

-- The remaining authored roster uses the same projection/manifest authority.
-- All profiles bind existing anchors; the catalog introduces no world positions.
for _, art in ipairs(round20_catalog) do
	local bounds_key="r20_"..art.kind
	M.BOUNDS[bounds_key]={min={x=-art.width/2,y=0,z=-art.width/2},
		max={x=art.width/2-1,y=art.height,z=art.width/2-1}}
	local stem="grug_r20_"..art.key
	M.roster[#M.roster+1]={key=art.key,label=art.label,race=art.race,slot=art.slot,
		bounds=bounds_key,lazy=true,zone_id=art.zone_id,
		anchor_id=("anchor_%03d"):format(art.number),numeric_id=art.number,
		x=art.x,z=art.z,blueprint_file="r20_poi_blueprint.lua",art=art,
		blueprint_schema=stem.."_v1",identity_schema=stem.."_identity_v1",
		config_schema=stem.."_config_v1",ledger_schema=stem.."_ledger_v1",
		metrics_schema=stem.."_metrics_v1",delta_schema=stem.."_delta_v1",
		reserve_anchor_root=true}
end

-- ASCII byte order. Lua's `<` on strings is `strcoll`, so under a locale that
-- is not C it can order two node names differently from the byte order
-- `r7_content.lua` validates the ONE shared palette with -- and the engine's
-- locale is not this game's to choose. Every place that sorts or checks a
-- settlement palette uses this: the union sort in `r7_runtime.lua` and the
-- per-blueprint check below.
function M.less_bytes(left, right)
	if type(left) ~= "string" or type(right) ~= "string" then
		error("WP13 settlement: byte-order input is not bytes", 0)
	end
	local count = math.min(#left, #right)
	for index = 1, count do
		local left_byte = string.byte(left, index)
		local right_byte = string.byte(right, index)
		if left_byte ~= right_byte then return left_byte < right_byte end
	end
	return #left < #right
end

local PROFILE_FIELDS = {"key", "label", "race", "slot", "bounds", "zone_id",
	"anchor_id", "numeric_id", "x", "z", "blueprint_file", "blueprint_schema",
	"identity_schema", "config_schema", "ledger_schema", "metrics_schema",
	"delta_schema"}
local NUMBER_FIELDS = {numeric_id = true, x = true, z = true}

-- Packed cell key. The duplicate-cell check used to build one string per
-- cell; a 100,000-cell capital core would allocate 100,000 of them per
-- construction for nothing but a set membership test (contract section
-- 2.2.5: "buffers use packed integer keys, not string keys, for anything
-- above the start size" -- and the start size pays the same price, so this is
-- unconditional). Every blueprint bound is validated inside +-1023 first, so
-- the packed value stays below 2^33 and is exact in a double.
local PACK_BIAS, PACK_SPAN = 1024, 2048
local function packed_key(x, y, z)
	return ((x + PACK_BIAS) * PACK_SPAN + (y + PACK_BIAS)) * PACK_SPAN +
		(z + PACK_BIAS)
end

-- The same idea for a WORLD column, which the avenue ground memo is keyed by.
-- The map limit is 31007, so the biased coordinate stays below 65536 and the
-- product below 2^32.
local WORLD_BIAS, WORLD_SPAN = 31008, 65536
local function column_key(x, z)
	return (x + WORLD_BIAS) * WORLD_SPAN + (z + WORLD_BIAS)
end

-- And for a whole world cell: the column key times the vertical span plus the
-- biased y. The map limit keeps every factor below 65536, so the product stays
-- under 2^48 and is exact in a double.
local function cell_key(x, y, z)
	return column_key(x, z) * WORLD_SPAN + (y + WORLD_BIAS)
end

local function hex(bytes)
	return (bytes:gsub(".", function(char)
		return string.format("%02x", string.byte(char))
	end))
end

local function integer_or_fail(fail, value, label, minimum, maximum)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge or value % 1 ~= 0 or
			value < minimum or value > maximum then
		fail(label .. " differs")
	end
	return value
end

-- One blueprint of a settlement: validate the authored composition, write its
-- canonical identity bytes and return them together with the cells and the
-- landmarks. Nothing here knows about content refs, which is what lets the
-- identity be computed once at load and the cells be dropped again.
local function prepare_cells(fail, descriptor, blueprint)
	local bounds = descriptor.bounds
	local function integer(value, label, minimum, maximum)
		return integer_or_fail(fail, value, label, minimum, maximum)
	end
	if type(blueprint) ~= "table" or
			blueprint.schema ~= descriptor.blueprint_schema or
			type(blueprint.cells) ~= "table" or #blueprint.cells < 1 or
			type(blueprint.bounds) ~= "table" or
			type(blueprint.bounds.min) ~= "table" or
			type(blueprint.bounds.max) ~= "table" or
			type(blueprint.palette) ~= "table" or #blueprint.palette < 1 or
			type(blueprint.landmarks) ~= "table" then
		fail(descriptor.id .. ": construction seam differs")
	end
	local palette, palette_list = {}, {}
	for index = 1, #blueprint.palette do
		local name = blueprint.palette[index]
		if type(name) ~= "string" or name == "" or palette[name] or
				(index > 1 and
					not M.less_bytes(blueprint.palette[index - 1], name)) then
			fail(descriptor.id .. ": palette differs")
		end
		palette[name] = true
		palette_list[index] = name
	end
	local minimum, maximum = blueprint.bounds.min, blueprint.bounds.max
	for _, axis in ipairs({"x", "y", "z"}) do
		integer(minimum[axis], "minimum " .. axis, -1023, 1023)
		integer(maximum[axis], "maximum " .. axis, minimum[axis], 1023)
	end
	if minimum.x < bounds.min.x or maximum.x > bounds.max.x or
			minimum.z < bounds.min.z or maximum.z > bounds.max.z or
			minimum.y < bounds.min.y or maximum.y > bounds.max.y then
		fail(descriptor.id .. ": blueprint bounds escape the authorized volume")
	end
	local cells, prior, seen, actual_min, actual_max = {}, nil, {}, {}, {}
	local bytes = {"schema\t" .. descriptor.identity_schema .. "\n",
		table.concat({"bounds", minimum.x, minimum.y, minimum.z,
			maximum.x, maximum.y, maximum.z}, "\t") .. "\n"}
	for index = 1, #palette_list do
		bytes[#bytes + 1] = table.concat({"palette", index,
			palette_list[index]}, "\t") .. "\n"
	end
	for index = 1, #blueprint.cells do
		local cell = blueprint.cells[index]
		if type(cell) ~= "table" then
			fail(descriptor.id .. ": cell differs at " .. index)
		end
		local x = integer(cell.x, "cell x", bounds.min.x, bounds.max.x)
		local y = integer(cell.y, "cell y", bounds.min.y, bounds.max.y)
		local z = integer(cell.z, "cell z", bounds.min.z, bounds.max.z)
		local param2 = integer(cell.param2, "cell param2", 0, 255)
		if not palette[cell.name] then
			fail(descriptor.id .. ": cell name is outside palette")
		end
		if prior and (z < prior.z or (z == prior.z and
				(y < prior.y or (y == prior.y and x <= prior.x)))) then
			fail(descriptor.id .. ": cells are not canonical z/y/x unique")
		end
		local key = packed_key(x, y, z)
		if seen[key] then fail(descriptor.id .. ": duplicate cell") end
		seen[key], prior = true, {x = x, y = y, z = z}
		cells[index] = {x = x, y = y, z = z, param2 = param2, name = cell.name}
		for _, axis in ipairs({"x", "y", "z"}) do
			local value = cell[axis]
			if actual_min[axis] == nil or value < actual_min[axis] then
				actual_min[axis] = value
			end
			if actual_max[axis] == nil or value > actual_max[axis] then
				actual_max[axis] = value
			end
		end
		bytes[#bytes + 1] =
			table.concat({"cell", x, y, z, cell.name, param2}, "\t") .. "\n"
	end
	for _, axis in ipairs({"x", "y", "z"}) do
		if minimum[axis] ~= actual_min[axis] or maximum[axis] ~= actual_max[axis] then
			fail(descriptor.id .. ": declared bounds differ on " .. axis)
		end
	end
	local by_key = {}
	for index = 1, #cells do
		local cell = cells[index]
		by_key[packed_key(cell.x, cell.y, cell.z)] = cell
	end
	local function cell_at(x, y, z)
		return by_key[packed_key(x, y, z)]
	end
	-- An anchor-relative blueprint lands its local y = 0 on the fitted anchor
	-- and its local y = 1 is where an entity stands. The anchor writer of
	-- `r7_anchor_activation.lua` asserts exactly that -- solid support at the
	-- anchor, an empty root above it -- so the rule is the same for a start's
	-- spawn and for a capital core's arrival crossing.
	if descriptor.kind == "anchor" then
		local support = cell_at(0, 0, 0)
		if not support or support.name == "air" then
			fail(descriptor.id .. ": spawn support differs")
		end
		for y = 1, 3 do
			local cell = cell_at(0, y, 0)
			if not cell or cell.name ~= "air" then
				fail(descriptor.id .. ": spawn clearance differs")
			end
		end
	end
	-- A terrain-relative plot levels to the final height of ONE column, and
	-- that column has to be a column of the plot's own ground course, or the
	-- projection is measured against terrain the plot does not stand on.
	if descriptor.kind == "reference" then
		local reference = blueprint.reference
		if type(reference) ~= "table" then
			fail(descriptor.id .. ": reference column differs")
		end
		integer(reference.x, "reference x", bounds.min.x, bounds.max.x)
		integer(reference.z, "reference z", bounds.min.z, bounds.max.z)
		local ground = cell_at(reference.x, 0, reference.z)
		if not ground or ground.name == "air" then
			fail(descriptor.id .. ": reference column has no ground course")
		end
	end
	return {cells = cells, palette = palette_list, landmarks = blueprint.landmarks,
		identity_bytes = table.concat(bytes),
		bounds = {min = {x = minimum.x, y = minimum.y, z = minimum.z},
			max = {x = maximum.x, y = maximum.y, z = maximum.z}},
		reference = blueprint.reference,
		-- The airspace a terrain-relative composition actually CUT, which is
		-- not the top of its bounds: a lamp post or a fruit tree written after
		-- the clear reaches above it. `M.audit_terrain` holds a rise against
		-- this and falls back to the bounds where a composition does not
		-- publish one.
		clear_to = blueprint.clear_to}
end

-- The canonical identity bytes of an OVERLAY. An overlay has no cells until a
-- surface is handed to it, so what is frozen is its specification: the runs in
-- authored order, the carriageway, the lamp rhythm, the look-around and the
-- exact set of node names a run may write. A change to any of them changes the
-- road, and nothing else can.
local function prepare_overlay(fail, descriptor, overlay)
	if type(overlay) ~= "table" or overlay.schema ~= descriptor.blueprint_schema or
			type(overlay.runs) ~= "table" or #overlay.runs < 1 or
			type(overlay.run) ~= "function" or type(overlay.names) ~= "table" or
			#overlay.names < 1 then
		fail(descriptor.id .. ": overlay seam differs")
	end
	local function integer(value, label, minimum, maximum)
		return integer_or_fail(fail, value, label, minimum, maximum)
	end
	integer(overlay.width, "overlay width", 3, 15)
	integer(overlay.lamp_spacing, "overlay lamp spacing", 1, 64)
	integer(overlay.reach, "overlay reach", 0, 256)
	if overlay.width % 2 ~= 1 then
		fail(descriptor.id .. ": overlay width is not an odd carriageway")
	end
	local bytes = {"schema\t" .. descriptor.identity_schema .. "\n",
		table.concat({"carriageway", overlay.width, overlay.lamp_spacing,
			overlay.reach}, "\t") .. "\n"}
	local runs, seen = {}, {}
	local half = (overlay.width - 1) / 2 + 1
	local reach = {min = {x = 0, y = 0, z = 0}, max = {x = 0, y = 0, z = 0}}
	local function stretch(min_x, max_x, min_z, max_z)
		if min_x < reach.min.x then reach.min.x = min_x end
		if max_x > reach.max.x then reach.max.x = max_x end
		if min_z < reach.min.z then reach.min.z = min_z end
		if max_z > reach.max.z then reach.max.z = max_z end
	end
	for index = 1, #overlay.runs do
		local run = overlay.runs[index]
		if type(run) ~= "table" or type(run.id) ~= "string" or run.id == "" or
				seen[run.id] or (run.axis ~= "x" and run.axis ~= "z") then
			fail(descriptor.id .. ": overlay run differs at " .. index)
		end
		seen[run.id] = true
		integer(run.at, "run centre line", -1023, 1023)
		integer(run.from, "run start", -1023, 1023)
		integer(run.to, "run end", run.from, 1023)
		local lamp_phase = run.lamp_phase
		if lamp_phase == nil then lamp_phase = run.from end
		integer(lamp_phase, "run lamp phase", -1023, 1023)
		if run.axis == "x" then
			stretch(run.from, run.to, run.at - half, run.at + half)
		else
			stretch(run.at - half, run.at + half, run.from, run.to)
		end
		-- THE JUNCTION SQUARES, the spans where a street passes through an
		-- authored structure, and the verge lanes that stand inside another
		-- street's carriageway travel with the run and are NOT hashed -- which
		-- is exact rather than lax: `wp13/street_plan.lua` derives all three
		-- from the run rectangles and the carriageway width alone, and every one
		-- of those rectangles is in the identity bytes already. A change to any
		-- of them moves the identity; nothing else can move a junction, a
		-- passage or a verge clearance.
		runs[index] = {id = run.id, axis = run.axis, at = run.at,
			from = run.from, to = run.to, lamp_phase = lamp_phase, junctions = run.junctions,
			plain_verge = run.plain_verge, clear_verge = run.clear_verge}
		bytes[#bytes + 1] = table.concat({"run", index, run.id, run.axis,
			run.at, run.from, run.to, lamp_phase}, "\t") .. "\n"
	end
	-- THE OVERLAY'S REACH, and the protection it has to stay inside.
	--
	-- The manifest used to publish the settlement's PRIMARY bounds for the
	-- overlay -- the 96-node civic core -- while the road it describes runs out
	-- to the gate stations at +-256 and writes tens of thousands of cells there.
	-- That is not a box the identity row may claim. The real reach is computed
	-- from the runs, and it is checked against the hard capital footprint of
	-- `source/simple_map.lua` (`hard_capital_build_plus_apron_v1`, total width
	-- 532, i.e. 266 either side of the anchor): a road outside it would write
	-- mutable world, which is exactly what a capital's protection exists to
	-- prevent.
	if reach.min.x < descriptor.bounds.min.x or
			reach.max.x > descriptor.bounds.max.x or
			reach.min.z < descriptor.bounds.min.z or
			reach.max.z > descriptor.bounds.max.z then
		fail(descriptor.id ..
			": an overlay run leaves the 532-node protected capital footprint")
	end
	-- The vertical reach is the settlement's own authorized volume: the road
	-- follows the ground, and the ground of a capital envelope is inside it.
	reach.min.y, reach.max.y = descriptor.bounds.min.y, descriptor.bounds.max.y
	bytes[#bytes + 1] = table.concat({"reach", reach.min.x, reach.min.y,
		reach.min.z, reach.max.x, reach.max.y, reach.max.z}, "\t") .. "\n"
	local names = {}
	for index = 1, #overlay.names do
		local name = overlay.names[index]
		if type(name) ~= "string" or name == "" or
				(index > 1 and not M.less_bytes(overlay.names[index - 1], name)) then
			fail(descriptor.id .. ": overlay palette differs")
		end
		names[index] = name
		bytes[#bytes + 1] = table.concat({"palette", index, name}, "\t") .. "\n"
	end
	return {runs = runs, palette = names, identity_bytes = table.concat(bytes),
		run = overlay.run, half = (overlay.width - 1) / 2,
		lamp_spacing = overlay.lamp_spacing, reach = overlay.reach,
		width = overlay.width, bounds = reach,
		-- The count the identity is written from is a RUN count, not a cell
		-- count: an overlay has no cells until a surface arrives, and the
		-- manifest row says so rather than publishing an 8 that looks like one.
		run_count = #runs}
end

local CAPITAL_SOURCE_SCHEMA = "grug_wp13_capital_source_v1"
local function identity_schema_of(fail, blueprint_schema)
	if type(blueprint_schema) ~= "string" or
			not blueprint_schema:match("_v%d+$") then
		fail("blueprint schema differs: " .. tostring(blueprint_schema))
	end
	return (blueprint_schema:gsub("_v(%d+)$", "_identity_v%1"))
end

-- `source` is what `dofile(profile.blueprint_file)()` returned: a blueprint
-- table for a one-blueprint settlement, or a capital source declaring a core,
-- a plot list and the avenue overlay. Returns the ordered blueprint
-- descriptors; an identity schema is derived from the blueprint's own schema
-- string, which is what keeps Hearthpine's
-- `grug_wp13_hearthpine_blueprint_identity_v1` exactly where it was.
function M.descriptors(profile, source)
	local function fail(message)
		error("WP13 " .. tostring(profile and profile.label) .. ": " .. message, 0)
	end
	local primary = M.BOUNDS[profile.bounds]
	if type(primary) ~= "table" then fail("profile bounds differ") end
	if type(source) ~= "table" then fail("blueprint source differs") end
	local list, seen = {}, {}
	local function add(descriptor)
		if descriptor.identity_schema ~=
				identity_schema_of(fail, descriptor.blueprint_schema) then
			fail(descriptor.id .. ": identity schema differs")
		end
		if seen[descriptor.id] or seen[descriptor.prefix] then
			fail(descriptor.id .. ": blueprint id or manifest prefix is not unique")
		end
		seen[descriptor.id], seen[descriptor.prefix] = true, true
		list[#list + 1] = descriptor
	end
	if source.schema ~= CAPITAL_SOURCE_SCHEMA then
		-- One blueprint, anchor-relative, under the settlement's own schema
		-- strings and manifest field prefix. This is every start.
		add({id = "blueprint", prefix = profile.key, kind = "anchor",
			bounds = primary, blueprint_schema = profile.blueprint_schema,
			identity_schema = profile.identity_schema,
			build = function() return source end})
		return list
	end
	local plot_bounds = M.BOUNDS[profile.plot_bounds]
	if type(plot_bounds) ~= "table" then fail("profile plot bounds differ") end
	if type(source.core) ~= "table" or type(source.core.build) ~= "function" or
			source.core.schema ~= profile.blueprint_schema or
			type(source.plots) ~= "table" or #source.plots < 1 or
			type(source.overlay) ~= "table" then
		fail("capital source differs")
	end
	add({id = "core", prefix = profile.key .. "_core", kind = "anchor",
		bounds = primary, blueprint_schema = source.core.schema,
		identity_schema = profile.identity_schema,
		build = source.core.build})
	for index = 1, #source.plots do
		local plot = source.plots[index]
		if type(plot) ~= "table" or type(plot.id) ~= "string" or plot.id == "" or
				type(plot.build) ~= "function" or type(plot.schema) ~= "string" then
			fail("capital plot differs at " .. index)
		end
		integer_or_fail(fail, plot.x, "plot x", -1023, 1023)
		integer_or_fail(fail, plot.z, "plot z", -1023, 1023)
		add({id = "plot_" .. plot.id, plot_id = plot.id,
			prefix = profile.key .. "_" .. plot.id, kind = "reference",
			bounds = plot_bounds, blueprint_schema = plot.schema,
			identity_schema = identity_schema_of(fail, plot.schema),
			offset = {x = plot.x, z = plot.z}, build = plot.build})
	end
	local overlay_bounds = M.BOUNDS.capital_overlay
	add({id = "avenue", prefix = profile.key .. "_avenue", kind = "overlay",
		bounds = overlay_bounds, blueprint_schema = source.overlay.schema,
		identity_schema = identity_schema_of(fail, source.overlay.schema),
		overlay = source.overlay})
	return list
end

-- Build every blueprint of a settlement once, hash it, and keep what is not
-- a cell: the identity, the palette and the landmarks (the NPC sockets among
-- them). The cells of a LAZY settlement are dropped here and rebuilt on the
-- first mapchunk that touches the blueprint; an eager settlement keeps them.
function M.prepare(profile, source, raw_sha256)
	if type(profile) ~= "table" then
		error("WP13 settlement: profile differs", 0)
	end
	for _, field in ipairs(PROFILE_FIELDS) do
		local value = profile[field]
		local wanted = NUMBER_FIELDS[field] and "number" or "string"
		if type(value) ~= wanted or (wanted == "string" and value == "") then
			error("WP13 settlement: profile field " .. field .. " differs", 0)
		end
	end
	local function fail(message)
		error("WP13 " .. profile.label .. ": " .. message, 0)
	end
	if profile.lazy ~= nil and profile.lazy ~= true then fail("lazy flag differs") end
	if profile.reserve_anchor_root ~= nil and
			profile.reserve_anchor_root ~= true then
		fail("anchor-root reservation differs")
	end
	if type(raw_sha256) ~= "function" then fail("SHA-256 seam differs") end
	local descriptors = M.descriptors(profile, source)
	local blueprints, union, seen = {}, {}, {}
	for index = 1, #descriptors do
		local descriptor = descriptors[index]
		local prepared
		if descriptor.kind == "overlay" then
			prepared = prepare_overlay(fail, descriptor, descriptor.overlay)
		else
			prepared = prepare_cells(fail, descriptor, descriptor.build())
		end
		local digest = raw_sha256(prepared.identity_bytes)
		if type(digest) ~= "string" or #digest ~= 32 then
			fail(descriptor.id .. ": SHA-256 seam differs")
		end
		local box = prepared.bounds or descriptor.bounds
		prepared.identity = {schema = descriptor.identity_schema,
			sha256 = hex(digest),
			-- A blueprint with cells publishes its cell count; an OVERLAY has
			-- none until a surface arrives, so it publishes the size of its
			-- specification -- the number of runs -- under its own field name.
			cell_count = prepared.cells and #prepared.cells or nil,
			run_count = prepared.run_count,
			min_x = box.min.x, min_y = box.min.y, min_z = box.min.z,
			max_x = box.max.x, max_y = box.max.y, max_z = box.max.z}
		prepared.identity_bytes = nil
		prepared.descriptor = descriptor
		if profile.lazy then prepared.cells = nil end
		for palette_index = 1, #prepared.palette do
			local name = prepared.palette[palette_index]
			if not seen[name] then
				seen[name] = true
				union[#union + 1] = name
			end
		end
		blueprints[index] = prepared
	end
	table.sort(union, M.less_bytes)
	return {schema = "grug_wp13_settlement_prepared_v1", profile = profile,
		blueprints = blueprints, palette = union}
end

-- WHAT THE GROUND UNDER A TERRAIN-RELATIVE BLUEPRINT ACTUALLY LOOKS LIKE.
--
-- A `reference` blueprint is projected from one column's pure final height and
-- written without a single question about the ground it lands on: the writer
-- has no water test and no fall test, because the positions it is handed were
-- chosen against measured terrain (`tools/wp13/highcourt_plots.lua`). That
-- measurement covers the two gate seeds. A THIRD seed can put a plot in a
-- river or half-bury it, and today that failure is silent -- it is a building
-- standing in water in somebody's world and nothing in the log says so.
--
-- This is the diagnostic, and it is only a diagnostic: it logs, it changes no
-- cell, and it is called once per load from the main environment, where the
-- same `column_values_at` the sockets are projected with is already in hand.
--
-- WHAT IT SAMPLES, and why not everything. The PERIMETER is walked exactly,
-- because the perimeter is what the foundation skirt carries down and the fall
-- under it is the rule. The two-node margin ring is walked exactly, because a
-- plot whose skirt ends one node from the water is a building with a moat. The
-- interior is sampled on a stride of two: it costs a quarter of the queries and
-- a river or a terrace shoulder is never one column wide. Exhaustive would be
-- 36 000 height queries at every server start for a warning nobody reads on a
-- healthy world.
--
-- `column_at(x, z)` is `planner_source.column_values_at`: its first return is
-- the water class and its sixth the final terrain height, so one query answers
-- both questions.
function M.audit_terrain(prepared, anchor, column_at, tolerance)
	if type(prepared) ~= "table" or
			prepared.schema ~= "grug_wp13_settlement_prepared_v1" then
		error("WP13 settlement: prepared settlement differs", 0)
	end
	if type(column_at) ~= "function" then
		error("WP13 settlement: column authority differs", 0)
	end
	tolerance = tolerance or {}
	local margin = tolerance.margin or 2
	local fall_limit = tolerance.fall or 6
	local findings = {}
	for index = 1, #prepared.blueprints do
		local blueprint = prepared.blueprints[index]
		local descriptor = blueprint.descriptor
		if descriptor.kind == "reference" then
			local identity = blueprint.identity
			local reference = blueprint.reference
			local origin_x = anchor.x + descriptor.offset.x
			local origin_z = anchor.z + descriptor.offset.z
			local class, _, _, _, _, base =
				column_at(origin_x + reference.x, origin_z + reference.z)
			local wet = (class ~= "land") and 1 or 0
			local edge_low, high = base, base
			local function sample(x, z, edge)
				local column_class, _, _, _, _, y = column_at(x, z)
				if column_class ~= "land" then wet = wet + 1 end
				if type(y) == "number" then
					if y > high then high = y end
					if edge and y < edge_low then edge_low = y end
				end
			end
			for z = identity.min_z - margin, identity.max_z + margin do
				for x = identity.min_x - margin, identity.max_x + margin do
					local outside = x < identity.min_x or x > identity.max_x or
						z < identity.min_z or z > identity.max_z
					local edge = (not outside) and
						(x == identity.min_x or x == identity.max_x or
							z == identity.min_z or z == identity.max_z)
					local interior = (not outside) and (not edge)
					if outside or edge then
						sample(origin_x + x, origin_z + z, edge)
					elseif interior and x % 2 == 0 and z % 2 == 0 then
						sample(origin_x + x, origin_z + z, false)
					end
				end
			end
			local fall, rise = base - edge_low, high - base
			-- The airspace the plot cut, which is what a rise has to fit
			-- under. A composition that does not publish one is held to the
			-- top of its own bounds, which is the older and weaker rule.
			local clear = blueprint.clear_to or identity.max_y
			if wet > 0 or fall > fall_limit or rise > clear then
				findings[#findings + 1] = {id = descriptor.id,
					plot_id = descriptor.plot_id, x = descriptor.offset.x,
					z = descriptor.offset.z, submerged = wet, fall = fall,
					rise = rise, clear = clear, skirt = fall_limit}
			end
		end
	end
	return findings
end

-- The NPC sockets of a prepared settlement, in blueprint order, ready for
-- `grug_core.register_settlement_sockets`. A plot's sockets are
-- PLOT-relative and TERRAIN-relative, so both corrections happen here and
-- nowhere else: the plot's offset from the anchor, and the difference between
-- the plot's own reference height and the settlement's fitted anchor height.
-- `height_at(x, z)` is the pure final height of one column -- the same query
-- the writer projects the plot's cells with.
--
-- A socket id is unique only within its own composition (a plot knows nothing
-- of the plot next door), so a plot's ids are prefixed with the plot id.
function M.sockets(prepared, anchor, height_at)
	if type(prepared) ~= "table" or
			prepared.schema ~= "grug_wp13_settlement_prepared_v1" then
		error("WP13 settlement: prepared settlement differs", 0)
	end
	local profile = prepared.profile
	local function fail(message)
		error("WP13 " .. profile.label .. " sockets: " .. message, 0)
	end
	if type(anchor) ~= "table" or type(anchor.x) ~= "number" or
			type(anchor.y) ~= "number" or type(anchor.z) ~= "number" then
		fail("anchor differs")
	end
	local rows = {}
	for index = 1, #prepared.blueprints do
		local blueprint = prepared.blueprints[index]
		local descriptor = blueprint.descriptor
		local landmarks = blueprint.landmarks
		local sockets = type(landmarks) == "table" and landmarks.sockets or nil
		if type(sockets) == "table" then
			local dx, dy, dz, prefix = 0, 0, 0, ""
			if descriptor.kind == "reference" then
				if type(height_at) ~= "function" then fail("height seam differs") end
				local reference = blueprint.reference
				local base = height_at(anchor.x + descriptor.offset.x + reference.x,
					anchor.z + descriptor.offset.z + reference.z)
				if type(base) ~= "number" or base % 1 ~= 0 then
					fail(descriptor.id .. ": reference height differs")
				end
				dx, dy, dz = descriptor.offset.x, base - anchor.y, descriptor.offset.z
				prefix = descriptor.plot_id .. "/"
			end
			for socket_index = 1, #sockets do
				local socket = sockets[socket_index]
				if type(socket) ~= "table" or type(socket.id) ~= "string" then
					fail(descriptor.id .. ": socket differs")
				end
				local row = {}
				for key, value in pairs(socket) do row[key] = value end
				row.id = prefix .. socket.id
				row.x, row.y, row.z = socket.x + dx, socket.y + dy, socket.z + dz
				rows[#rows + 1] = row
			end
		end
	end
	if profile.slot == "start" then
		local position = START_TRAINERS[profile.key]
		if not position then fail("start trainer position differs") end
		rows[#rows + 1] = {id = "trainer_cooking", role = "trainer",
			profession = "cooking", x = position.x, y = position.y,
			z = position.z, dir = position.dir}
		local cook_z=position.z>0 and 13 or -13
		rows[#rows+1]={id="quest_cook",role="quest",x=2,y=1,z=cook_z,
			dir={x=-1,z=0}}
		rows[#rows+1]={id="cook_oven",role="public_station",x=4,y=1,z=cook_z,
			dir={x=-1,z=0},tags={"furnace"}}
	end
	return rows
end

-- The successor configuration of one prepared settlement.
function M.config(prepared, content, raw_sha256)
	if type(prepared) ~= "table" or
			prepared.schema ~= "grug_wp13_settlement_prepared_v1" then
		error("WP13 settlement: prepared settlement differs", 0)
	end
	local profile = prepared.profile
	local function fail(message)
		error("WP13 " .. profile.label .. ": " .. message, 0)
	end
	if type(content) ~= "table" or
			content.schema ~= "grug_wp13_settlement_content_v1" or
			type(content.content_names) ~= "table" or
			#content.content_names < #prepared.palette or
			type(content.resolve) ~= "function" or
			type(content.content_ref) ~= "function" or
			type(raw_sha256) ~= "function" then
		fail("construction seam differs")
	end
	-- Every blueprint name resolves to one ref in the shared channel. The refs
	-- are resolved ONCE per settlement here, not per build, so a lazy rebuild
	-- costs a composition and a digest and no channel work at all.
	local refs = {}
	for index = 1, #prepared.palette do
		local name = prepared.palette[index]
		local ref = content.content_ref(name)
		if type(ref) ~= "number" or ref % 1 ~= 0 or ref < 1 or
				content.content_names[ref] ~= name then
			fail("palette differs")
		end
		refs[name] = ref
	end

	local identities = {}
	for index = 1, #prepared.blueprints do
		local blueprint = prepared.blueprints[index]
		identities[index] = {id = blueprint.descriptor.id,
			prefix = blueprint.descriptor.prefix,
			kind = blueprint.descriptor.kind,
			identity = blueprint.identity}
	end

	local config = {schema = profile.config_schema,
		identity = prepared.blueprints[1].identity,
		identities = identities,
		key = profile.key, label = profile.label, slot = profile.slot,
		anchor_id = profile.anchor_id, delta_schema = profile.delta_schema,
		lazy = profile.lazy == true}

	function config.new(dependencies)
		if type(dependencies) ~= "table" or
				type(dependencies.zones_session) ~= "table" or
				type(dependencies.zones_session.anchor) ~= "function" then
			fail("successor dependencies differ")
		end
		local anchor = dependencies.zones_session.anchor(profile.zone_id, profile.slot)
		if type(anchor) ~= "table" or anchor.id ~= profile.anchor_id or
				anchor.numeric_id ~= profile.numeric_id or
				anchor.x ~= profile.x or anchor.z ~= profile.z or
				type(anchor.y) ~= "number" or anchor.y % 1 ~= 0 then
			fail("stable " .. profile.slot .. " anchor differs")
		end

		-- The pure final height of one column: the same query the capital
		-- reference rule of `height.lua` is authenticated through in
		-- `r7_anchor_roster.lua`, reached from the planner source the
		-- successor is constructed with. Only a settlement that owns a
		-- terrain-relative blueprint or an overlay needs it, so a start's
		-- dependencies are unchanged.
		local needs_height = false
		for index = 1, #prepared.blueprints do
			local kind = prepared.blueprints[index].descriptor.kind
			if kind == "reference" or kind == "overlay" then needs_height = true end
		end
		local column_values_at
		if needs_height then
			local planner_source = dependencies.planner_source
			if type(planner_source) ~= "table" or
					type(planner_source.column_values_at) ~= "function" then
				fail("planner source differs")
			end
			column_values_at = planner_source.column_values_at
		end
		local function final_height(x, z)
			local _, _, _, _, _, terrain_y = column_values_at(x, z)
			if type(terrain_y) ~= "number" or terrain_y % 1 ~= 0 then
				fail("final height at " .. x .. "," .. z .. " differs")
			end
			return terrain_y
		end

		-- THE WALKABLE SURFACE of a column, which is what a ROAD follows: the
		-- ground, or the water standing on it where there is any.
		--
		-- The first engine pass of this package ran the east avenue straight
		-- along a river bed. Highcourt is the contract's "river plateau" capital
		-- and WP40 leaves that river inside the 512 envelope, so between local
		-- x 128 and x 210 the ground under the avenue is nine nodes below the
		-- core and the water is one node above it: "pavement at surface" read as
		-- the GROUND surface paves a trench under the river. A road is walked on
		-- the surface a traveller stands on, so that is what the successor hands
		-- `avenue.lua` -- and because the settlement writer overwrites, the
		-- result is a solid causeway across the water and not paving floating on
		-- it. The overlay itself is unchanged: it still queries no height of its
		-- own and still knows nothing about water.
		--
		-- THE ROUTE OVER THE ROAD, which is the second half of the same
		-- query. WP40's long-distance routes cross the same rivers the
		-- capital's streets do, and where a route crosses on a BRIDGE its
		-- deck passes over the street in the air. The column query already in
		-- hand answers that too: a column the route spans reports the
		-- functional kind `bridge_deck` and the deck's own walking height,
		-- and every other functional kind (a land grade, a causeway, a ford)
		-- is written INTO the ground and is therefore already the surface
		-- this function returns.
		--
		-- So the overlay is handed two numbers per column instead of one, out
		-- of ONE `column_values_at`, and `wp13/avenue.lua` owns what to do
		-- with them (its "crossing rule"). The seam publishes geometry and
		-- decides nothing: the deck height is what WP40 built, not what WP13
		-- would like it to be.
		local function walkable_values(x, z)
			local water_class, _, _, _, _, terrain_y, water_y, _, _, functional_kind,
				functional_y, feature_id = column_values_at(x, z)
			if type(terrain_y) ~= "number" or terrain_y % 1 ~= 0 then
				fail("final height at " .. x .. "," .. z .. " differs")
			end
			local deck_y
			if functional_kind == "bridge_deck" then
				if type(functional_y) ~= "number" or functional_y % 1 ~= 0 then
					fail("bridge deck height at " .. x .. "," .. z .. " differs")
				end
				deck_y = functional_y
			end
			-- THE THIRD VALUE IS WHETHER THIS COLUMN IS WATER, and it is read
			-- off the same plan the first two are. An overlay run needs it
			-- because the surface it is handed over a river IS the river: a
			-- street that filled up to it would be a dam with a road on top,
			-- and the ruling of 2026-09-16 is that a water body stays one body
			-- and a street over water is a bridge on piers. Lethariel used to
			-- carry a hand-measured span table for exactly this; the plan knew
			-- all along, and one more return value is what it took to ask it.
			if type(water_y) == "number" and water_y % 1 == 0 and
					water_y > terrain_y then
				return water_y, deck_y, true, true
			end
			local engineered = water_class ~= "land" or (functional_kind ~= nil and
				not (functional_kind == "land_grade" and type(feature_id) == "string" and
					feature_id:match("^anchor_%d+$")))
			return terrain_y, deck_y, false, engineered
		end

		local metrics = {plan_calls = 0, settle_calls = 0, replay_calls = 0,
			written = 0, build_calls = 0, release_calls = 0, height_calls = 0,
			overlay_calls = 0}

		-- Per-session state of every blueprint: the world box it occupies, the
		-- cells with their content refs (nil while released) and, for a plot,
		-- the reference height that box was derived from.
		local states = {}
		for index = 1, #prepared.blueprints do
			local blueprint = prepared.blueprints[index]
			local descriptor = blueprint.descriptor
			local state = {blueprint = blueprint, descriptor = descriptor,
				active = false, idle = 0}
			if descriptor.kind == "overlay" then
				-- A run's ground is read once per session and shared by every
				-- mapchunk that clips it: the envelope of a column depends on the
				-- ground within `reach` columns of it, so the mapchunks stacked
				-- above and below one avenue must not re-read the same profile
				-- once each. The memo IS the plan's own column surface -- every
				-- value in it comes from `column_values_at` and from nothing else.
				-- `state.deck` is the same memo for the route surface that spans
				-- the column, filled by the same query and in the same pass, so
				-- the crossing rule costs no extra column.
				state.ground = {}
				state.deck = {}
				-- The same memo for "is this column water", filled by the same
				-- query and in the same pass, so a bridge costs no extra column.
				state.wet = {}
				state.runs = {}
				for run_index = 1, #blueprint.runs do
					local run = blueprint.runs[run_index]
					local half = blueprint.half + 1
					local min_x, max_x, min_z, max_z
					if run.axis == "x" then
						min_x, max_x = run.from, run.to
						min_z, max_z = run.at - half, run.at + half
					else
						min_z, max_z = run.from, run.to
						min_x, max_x = run.at - half, run.at + half
					end
					-- The CARRIAGEWAY rectangle, verges excluded, in the
					-- composition's own coordinates: this is what decides whether
					-- another run's lamp standard would stand in the middle of this
					-- road (see the arbitration in `settle`).
					local car_min_x, car_max_x, car_min_z, car_max_z
					if run.axis == "x" then
						car_min_x, car_max_x = run.from, run.to
						car_min_z, car_max_z = run.at - blueprint.half, run.at + blueprint.half
					else
						car_min_z, car_max_z = run.from, run.to
						car_min_x, car_max_x = run.at - blueprint.half, run.at + blueprint.half
					end
					state.runs[run_index] = {run = run, active = false,
						min_x = anchor.x + min_x, max_x = anchor.x + max_x,
						min_z = anchor.z + min_z, max_z = anchor.z + max_z,
						car_min_x = car_min_x, car_max_x = car_max_x,
						car_min_z = car_min_z, car_max_z = car_max_z}
				end
			end
			states[index] = state
		end

		-- The world box of a blueprint, and the base height its cells are
		-- projected from. For an anchor-relative blueprint that is the fitted
		-- anchor; for a plot it is the pure final height of its reference
		-- column, asked ONCE per session and cached here.
		local function base_of(state)
			if state.base then return state.base end
			local descriptor = state.descriptor
			local base
			if descriptor.kind == "anchor" then
				base = {x = anchor.x, y = anchor.y, z = anchor.z}
			else
				local reference = state.blueprint.reference
				local x = anchor.x + descriptor.offset.x
				local z = anchor.z + descriptor.offset.z
				metrics.height_calls = metrics.height_calls + 1
				base = {x = x, y = final_height(x + reference.x, z + reference.z),
					z = z}
			end
			local bounds = state.blueprint.bounds
			state.base = base
			state.box = {min_x = base.x + bounds.min.x, max_x = base.x + bounds.max.x,
				min_y = base.y + bounds.min.y, max_y = base.y + bounds.max.y,
				min_z = base.z + bounds.min.z, max_z = base.z + bounds.max.z}
			return base
		end

		-- The cells of a blueprint with their content refs. Built on demand:
		-- a lazy settlement holds none until a mapchunk touches it, and the
		-- rebuild is compared against the identity the manifest published, so
		-- a composition that is not a pure function of its own source is a
		-- loud failure and not a silently different capital.
		local function cells_of(state)
			if state.cells then return state.cells end
			local source_cells = state.blueprint.cells
			if not source_cells then
				metrics.build_calls = metrics.build_calls + 1
				local rebuilt = prepare_cells(fail, state.descriptor,
					state.descriptor.build())
				if hex(raw_sha256(rebuilt.identity_bytes)) ~=
						state.blueprint.identity.sha256 then
					fail(state.descriptor.id ..
						": the lazy rebuild differs from its published identity")
				end
				source_cells = rebuilt.cells
			end
			local cells = {}
			for index = 1, #source_cells do
				local cell = source_cells[index]
				local ref = refs[cell.name]
				if not ref then
					fail(state.descriptor.id .. ": cell name lost its content ref")
				end
				cells[index] = {x = cell.x, y = cell.y, z = cell.z,
					content_ref = ref, param2 = cell.param2}
			end
			state.cells = cells
			return cells
		end

		local function release(state)
			if state.cells and not state.blueprint.cells then
				state.cells = nil
				metrics.release_calls = metrics.release_calls + 1
			end
		end

		local approaches
		local approach_findings = {}
		local road_states = {}
		local function raw_road_values(state, x, z)
			local wx, wz = anchor.x + x, anchor.z + z
			local key = column_key(wx, wz)
			if state.ground[key] == nil then
				metrics.height_calls = metrics.height_calls + 1
				local y, deck, wet = walkable_values(wx, wz)
				state.ground[key], state.deck[key], state.wet[key] = y, deck or false, wet
			end
			return state.ground[key], state.deck[key] or nil, state.wet[key]
		end
		local function prepare_approach(record)
			if record.sampled then return end
			record.sampled = true
			if not record.road_id then
				local y, _, wet, engineered = walkable_values(anchor.x + record.entry_x, anchor.z + record.road_z)
				record.road_y = y
				if wet or engineered or math.abs(y - record.y) > plot_approach.COLLAR then
					record.unreachable = true
					approach_findings[#approach_findings + 1] = record.state.descriptor.id .. ": natural entrance cannot fit within collar"
				end
				return
			end
			local road = road_states[record.road_id]
			local state, run = road.state, road.run
			local blueprint = state.blueprint
			local function surface(x, z) return raw_road_values(state, x, z) end
			local function overhead(x, z) local _, deck = raw_road_values(state, x, z); return deck end
			local function wet(x, z) local _, _, value = raw_road_values(state, x, z); return value end
			local piece = blueprint.run({id = run.id, axis = run.axis, at = run.at,
				from = record.entry_x, to = record.entry_x, width = blueprint.width,
				lamp_spacing = blueprint.lamp_spacing, lamp_phase = run.lamp_phase,
				reach = blueprint.reach, anchor_y = anchor.y, junctions = run.junctions,
				plain_verge = run.plain_verge, clear_verge = run.clear_verge,
				overhead = overhead, wet = wet}, surface)
			for _, cell in ipairs(piece.cells) do
				if cell.x == record.entry_x and cell.z == run.at and cell.name ~= "air" then
					record.road_y = math.max(record.road_y or cell.y, cell.y)
				end
			end
			-- If another strip owns this junction, sample that owner at the
			-- same column rather than infer its built height from bare terrain.
			if record.road_y == nil then
				for _, joint in ipairs(run.junctions or {}) do
					if record.entry_x >= joint.low and record.entry_x <= joint.high then
						local owner = road_states[joint.owner]
						if owner then
							local os = owner.run
							local along = os.axis == "x" and record.entry_x or run.at
							local part = blueprint.run({id = os.id, axis = os.axis, at = os.at,
								from = along, to = along, width = blueprint.width,
								lamp_spacing = blueprint.lamp_spacing, lamp_phase = os.lamp_phase,
								reach = blueprint.reach, anchor_y = anchor.y, junctions = os.junctions,
								plain_verge = os.plain_verge, clear_verge = os.clear_verge,
								overhead = overhead, wet = wet}, surface)
							for _, cell in ipairs(part.cells) do
								if cell.x == record.entry_x and cell.z == run.at and cell.name ~= "air" then
									record.road_y = math.max(record.road_y or cell.y, cell.y)
								end
							end
						end
					end
				end
			end
			if record.road_y == nil or math.abs(record.road_y - record.y) > record.min_z - record.road_z then
				record.unreachable = true
				approach_findings[#approach_findings + 1] = record.state.descriptor.id .. ": approach exceeds one-node rise"
			end
		end
		local function prepare_approaches()
			if approaches then return approaches end
			local plots, runs = {}, {}
			for _, state in ipairs(states) do
				if state.descriptor.kind == "reference" then
					local base = base_of(state)
					local marks = state.blueprint.landmarks
					local plot = marks and marks.plot
					local entry = marks and marks.entry
					if plot and entry then
						plots[#plots + 1] = {state = state, y = base.y,
							min_x = base.x + plot.min.x - anchor.x,
							max_x = base.x + plot.max.x - anchor.x,
							min_z = base.z + plot.min.z - anchor.z,
							max_z = base.z + plot.max.z - anchor.z,
							entry_x = base.x + entry.x - anchor.x}
					end
				elseif state.descriptor.kind == "overlay" then
					for _, run in ipairs(state.blueprint.runs) do
						runs[#runs + 1] = run
						road_states[run.id] = {run = run, state = state}
					end
				end
			end
			approaches = plot_approach.new(plots, runs)
			return approaches
		end

		local bound_plan, bound_generation = false, 0
		local tail = {key = profile.key}

		function tail.bind_plan(self, minp, maxp, plan, generation)
			if not rawequal(self, tail) or type(minp) ~= "table" or
					type(maxp) ~= "table" or type(plan) ~= "table" then
				fail("plan binding differs")
			end
			for index = 1, #states do
				local state = states[index]
				if state.descriptor.kind == "overlay" then
					local active = false
					for run_index = 1, #state.runs do
						local entry = state.runs[run_index]
						entry.active = entry.max_x >= minp.x and entry.min_x <= maxp.x and
							entry.max_z >= minp.z and entry.min_z <= maxp.z
						if entry.active then active = true end
					end
					state.active = active
				else
					if not state.box then
						-- The height query that decides a plot's box is the one a plan
						-- cannot avoid: the box is what says whether this mapchunk
						-- touches the plot at all. It is asked once per session per
						-- plot and cached, which is the contract's "query the pure
						-- final height once per session".
						base_of(state)
					end
					local box = state.box
					state.active = box.max_x >= minp.x and box.min_x <= maxp.x and
						box.max_y >= minp.y and box.min_y <= maxp.y and
						box.max_z >= minp.z and box.min_z <= maxp.z
				end
				if state.active then
					state.idle = 0
				else
					state.idle = state.idle + 1
					if state.idle > M.IDLE_RELEASE then release(state) end
				end
			end
			bound_plan, bound_generation = plan, generation
			metrics.plan_calls = metrics.plan_calls + 1
		end

		function tail.settle(self, context)
			if not rawequal(self, tail) or type(context) ~= "table" or
					not rawequal(context.plan, bound_plan) or
					context.generation ~= bound_generation or
					type(context.inside_owner) ~= "function" or
					type(context.write_hearthpine) ~= "function" then
				fail("settlement plan binding differs")
			end
			local written = 0
			local reserved_x, reserved_y, reserved_z
			if profile.reserve_anchor_root then
				reserved_x, reserved_y, reserved_z = anchor.x, anchor.y + 1, anchor.z
			end
			-- Natural cut/fill precedes every authored plot and street. Work is
			-- clipped to this owner; neighbouring chunks ask the same pure field.
			local fittings = prepare_approaches()
			local fit_palette = approach_palettes.new(profile.race)
			local ground_ref, air_ref = refs[fit_palette.node("ground")], refs.air
			local fill_ref = refs[fit_palette.node("subsoil")] or ground_ref
			local path_ref = refs[fit_palette.maybe("castle_paving") or fit_palette.node("plaza")]
			local step_ref = refs[fit_palette.maybe("castle_wall_stair") or fit_palette.node("roof_stair")]
			local function fit_write(x, y, z, ref, face)
				if not ref then fail("plot approach material is outside settlement palette") end
				if context.inside_owner(x, y, z) then
					local cid, param2 = content.resolve(ref, face or 0)
					context.write_hearthpine(x, y, z, cid, param2, ref, 1)
					written = written + 1
				end
			end
			if #fittings.plots > 0 then
				for z = context.min_z, context.max_z do
					for x = context.min_x, context.max_x do
						local lx, lz = x - anchor.x, z - anchor.z
						if math.abs(lx) < 266 and math.abs(lz) < 266 then
							-- Probe membership cheaply before querying terrain.
							local _, record = fittings.surface(lx, lz, 0)
							if record then
								prepare_approach(record)
								local natural, _, wet, engineered = walkable_values(x, z)
								local top, _, access = fittings.surface(lx, lz, natural)
								if not wet and (not engineered or access) and (top ~= natural or access) then
									for y = natural, top - 1 do fit_write(x, y, z, fill_ref) end
									local before = access and plot_approach.path_height(record, lz - 1) or top
									local after = access and plot_approach.path_height(record, lz + 1) or top
									if access and (top > before or top > after) then
										fit_write(x, top, z, step_ref, after >= before and 0 or 2)
									else fit_write(x, top, z, access and path_ref or ground_ref) end
									for y = top + 1, math.max(natural, top + 3) do
										fit_write(x, y, z, air_ref)
									end
								end
							end
						end
					end
				end
			end
			-- Cells first, in blueprint order (the core, then the plots), and the
			-- overlay last: the contract's "a surface overlay written by the same
			-- successor, after the plots".
			for index = 1, #states do
				local state = states[index]
				if state.active and state.descriptor.kind ~= "overlay" then
					local base = base_of(state)
					local cells = cells_of(state)
					for cell_index = 1, #cells do
						local cell = cells[cell_index]
						local x, y, z = base.x + cell.x, base.y + cell.y, base.z + cell.z
						-- The one cell a capital core does not write: the guard banner
						-- the anchor writer already put on the anchor root. The
						-- composition has air there, so nothing of the city is lost,
						-- and the banner is `walkable = false`, so it blocks neither
						-- the crossing it stands on nor its own watch.
						if (x ~= reserved_x or y ~= reserved_y or z ~= reserved_z) and
								context.inside_owner(x, y, z) then
							local cid, param2 = content.resolve(cell.content_ref, cell.param2)
							-- `write_hearthpine` is R7's opcode-37 settlement writer.
							-- The name is the historical one from the first increment
							-- and belongs to the accepted R6 settlement contract; the
							-- channel carries every settlement, not only Hearthpine.
							context.write_hearthpine(x, y, z, cid, param2,
								cell.content_ref, 1)
							written = written + 1
						end
					end
				end
			end
			for index = 1, #states do
				local state = states[index]
				if state.active and state.descriptor.kind == "overlay" then
					local blueprint = state.blueprint
					local ground, decks, wets = state.ground, state.deck, state.wet
					-- One query fills both memos. `decks` distinguishes "not
					-- asked yet" (nil) from "nothing spans this column"
					-- (`false`), so a column with no bridge over it is still
					-- read exactly once.
					local function read(x, z)
						local key = column_key(x, z)
						local value = ground[key]
						if value == nil then
							metrics.height_calls = metrics.height_calls + 1
							local deck_y, soaked
							value, deck_y, soaked = walkable_values(x, z)
							ground[key] = value
							decks[key] = deck_y or false
							wets[key] = soaked and true or false
						end
						return key, value
					end
					local function surface(x, z)
						local _, value = read(x, z)
						return value
					end
					local function local_surface(x, z)
						return surface(anchor.x + x, anchor.z + z)
					end
					local function local_overhead(x, z)
						local key = read(anchor.x + x, anchor.z + z)
						local deck_y = decks[key]
						if deck_y == false then return nil end
						return deck_y
					end
					-- WHERE THE CAPITAL'S OWN WATER IS, for the run that has to
					-- bridge it. The same memo, the same pass and the same
					-- purity as the two queries above: a column, a yes or a no,
					-- and no state.
					local function local_wet(x, z)
						local key = read(anchor.x + x, anchor.z + z)
						return wets[key]
					end
					-- CROSS-RUN ARBITRATION, and the successor is the only thing that
					-- can do it: `avenue.run` is a pure function of ONE run and knows
					-- nothing of the road it crosses, while a capital's four avenues
					-- and its four ring-street sides meet at four corners.
					--
					-- Two rules, both a pure function of the run rectangles and the
					-- column, so a piece of a run is still exactly that stretch of the
					-- whole run and the union of the mapchunks is unchanged:
					--
					--   1. THE FIRST RUN WINS A SHARED CELL. The runs are authored
					--      avenues first, ring street second, so the great road runs
					--      through and the side street yields at the kerb, which is
					--      what a crossroads looks like. Every run that covers a cell
					--      produces it in every mapchunk that contains it, so which
					--      run wins does not depend on the mapchunk.
					--   2. NO LAMP STANDARD IN ANOTHER ROAD'S CARRIAGEWAY. A lamp
					--      stands on the verge, one node outside its own carriageway,
					--      and at a crossing that verge is the middle of the other
					--      road: Highcourt's lamp rhythm puts one pair exactly on each
					--      ring crossing, i.e. eight posts in the ring street. The
					--      three cells of such a standard are dropped. This is the
					--      same defect the core's own streets had, and the same fix.
					local written_here = {}
					for run_index = 1, #state.runs do
						local entry = state.runs[run_index]
						if entry.active then
							local run = entry.run
							-- The piece of the run this mapchunk owns, in the run's own
							-- coordinates, and nothing else: `avenue.lua`'s look-around
							-- reads the ground beyond the piece and the envelope of a
							-- column depends on nothing further away, so the union of the
							-- pieces is the whole run, cell for cell. The lamp phase is
							-- the WHOLE run's start, which is what keeps one lamp line
							-- across a mapchunk border.
							local low, high
							if run.axis == "x" then
								low, high = context.min_x - anchor.x, context.max_x - anchor.x
							else
								low, high = context.min_z - anchor.z, context.max_z - anchor.z
							end
							if low < run.from then low = run.from end
							if high > run.to then high = run.to end
							if low <= high then
								metrics.overlay_calls = metrics.overlay_calls + 1
								local clear_verge = {}
								for _, span in ipairs(run.clear_verge or {}) do clear_verge[#clear_verge + 1] = span end
								for _, record in ipairs(fittings.plots) do
									if record.road_id == run.id and record.entry_x + 1 >= low and record.entry_x - 1 <= high then
										prepare_approach(record)
										if not record.unreachable then
											clear_verge[#clear_verge + 1] = {record.entry_x - 1, record.entry_x + 1, 1}
										end
									end
								end
								local piece = blueprint.run({id = run.id, axis = run.axis,
									anchor_y = anchor.y,
									at = run.at, from = low, to = high,
									width = blueprint.width,
									lamp_spacing = blueprint.lamp_spacing,
									lamp_phase = run.lamp_phase, reach = blueprint.reach,
									-- The route geometry over this run's columns. A
									-- run built without it is the road this seam
									-- built before there was a crossing rule, which
									-- is what every engine-free fixture still asks
									-- for.
									overhead = local_overhead,
									-- The capital's own water, and the squares
									-- this run shares with another street; see
									-- `wp13/avenue.lua`.
									wet = local_wet,
									junctions = run.junctions,
									plain_verge = run.plain_verge,
									clear_verge = clear_verge},
									local_surface)
								-- Rule 2: the standards this run may not raise, by the
								-- three cells each of them occupies (post, post, torch,
								-- counted down from the lamp's own light cell).
								local dropped = {}
								for lamp_index = 1, #piece.lamps do
									local lamp = piece.lamps[lamp_index]
									local blocked = false
									for other_index = 1, #state.runs do
										if other_index ~= run_index then
											local other = state.runs[other_index]
											if lamp.x >= other.car_min_x and lamp.x <= other.car_max_x and
													lamp.z >= other.car_min_z and
													lamp.z <= other.car_max_z then
												blocked = true
												break
											end
										end
									end
									if blocked then
										for y = lamp.y - 2, lamp.y do
											dropped[cell_key(lamp.x, y, lamp.z)] = true
										end
										metrics.overlay_lamps_dropped =
											(metrics.overlay_lamps_dropped or 0) + 1
									end
								end
								for cell_index = 1, #piece.cells do
									local cell = piece.cells[cell_index]
									local x, y, z = anchor.x + cell.x, cell.y, anchor.z + cell.z
									local ref = refs[cell.name]
									if not ref then
										fail("avenue name outside the overlay palette: " ..
											tostring(cell.name))
									end
									local here = cell_key(x, y, z)
									if dropped[cell_key(cell.x, cell.y, cell.z)] then
										metrics.overlay_cells_dropped =
											(metrics.overlay_cells_dropped or 0) + 1
									elseif written_here[here] then
										-- Rule 1: an earlier run already owns this cell.
										metrics.overlay_overlaps =
											(metrics.overlay_overlaps or 0) + 1
									elseif context.inside_owner(x, y, z) then
										written_here[here] = true
										local cid, param2 = content.resolve(ref, cell.param2)
										context.write_hearthpine(x, y, z, cid, param2, ref, 1)
										written = written + 1
									else
										written_here[here] = true
									end
								end
							end
						end
					end
				end
			end
			if context.call_mode == "replay_fixture" then
				metrics.replay_calls = metrics.replay_calls + 1
			else
				metrics.settle_calls = metrics.settle_calls + 1
				metrics.written = metrics.written + written
			end
			return {schema = profile.ledger_schema,
				blueprint_sha256 = config.identity.sha256, written = written,
				approach_findings = approach_findings}
		end

		function tail.metrics(self)
			if not rawequal(self, tail) then fail("metrics receiver differs") end
			return {schema = profile.metrics_schema,
				plan_calls = metrics.plan_calls, settle_calls = metrics.settle_calls,
				replay_calls = metrics.replay_calls, written = metrics.written,
				build_calls = metrics.build_calls,
				release_calls = metrics.release_calls,
				height_calls = metrics.height_calls,
				overlay_calls = metrics.overlay_calls,
				-- The cross-run arbitration, counted so a measurement can say how
				-- much of the road two crossing runs actually argued about.
				overlay_overlaps = metrics.overlay_overlaps,
				overlay_lamps_dropped = metrics.overlay_lamps_dropped,
				overlay_cells_dropped = metrics.overlay_cells_dropped,
				blueprint_sha256 = config.identity.sha256, approach_findings = approach_findings}
		end
		return tail
	end
	return config
end

return M
