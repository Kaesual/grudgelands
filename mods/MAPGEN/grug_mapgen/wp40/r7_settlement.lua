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
--        "reference" -- a placed capital plot: the descriptor carries the
--                       plot's offset from the anchor, its quarter TURNS and
--                       its BASE height, all from the world's capital layout
--                       (`capital_planner.lua`); the cells are turned at
--                       projection time, the identity stays the unturned
--                       cells.
--        "overlay"   -- no cells at all until a mapchunk asks for its columns:
--                       a capital's city edge (walls, gatehouses, the open
--                       capitals' belt) is a pure function of the capital
--                       layout and the column surface (`wp13/city_edge.lua`).
--      An overlay's identity is therefore its SPECIFICATION -- the edge
--      geometry, its reach and the exact set of node names it may write --
--      because it has no cells to hash.
--   4. LAZY CONSTRUCTION. A profile marked `lazy` keeps no cells at all until
--      the first `bind_plan` whose mapchunk touches the blueprint's envelope,
--      and drops them again once `IDLE_RELEASE` consecutive plans have
--      touched nothing of it. Identity is NOT lazy: the manifest is a closed
--      document, so main builds every blueprint once at load, hashes it, and
--      releases its cells. What lazy construction hides is the 100,000-cell
--      buffer, not the digest. Emerge takes main's preparations of the lazy
--      blueprints (`M.handover`) instead of building them all again, and
--      every lazy rebuild is checked against that identity and those
--      landmarks. Starts stay eager: they are small and the spawn depends on
--      them.
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
local parts = dofile(module_dir.."/../wp13/parts.lua")
local rot = plot_approach.rot

-- The authorized volume per blueprint kind (contract sections 2.1 and 2.2).
-- The start's numbers are the literal the first four increments typed in
-- three places; they are data now and nothing else changed about them.
M.BOUNDS = {
	start = {min = {x = -63, y = -2, z = -63}, max = {x = 63, y = 24, z = 63}},
	capital_core = {min = {x = -49, y = -2, z = -49}, max = {x = 49, y = 40, z = 49}},
	capital_plot = {min = {x = -15, y = -6, z = -15}, max = {x = 15, y = 24, z = 15}},
	-- Authored POIs stay inside the exact half-open flat terrain cores.
	poi = {min = {x = -12, y = 0, z = -12}, max = {x = 11, y = 8, z = 11}},
	poi_outpost = {min = {x = -8, y = 0, z = -8}, max = {x = 7, y = 8, z = 7}},
}

-- The city edge (walls, gatehouses, turrets, the open capitals' planted
-- belt) is the one blueprint that legitimately leaves the civic core: it
-- stands on the capital planner's outline. (The streets and connectors are
-- roads, `road_layout.lua`, not blueprints.) It has no cells, so its
-- authorized volume is not an anchor-relative box like the entries of
-- `M.BOUNDS`: it has two parts in two different frames, kept apart.
M.CAPITAL_OVERLAY = {
	-- HORIZONTAL, anchor-relative x and z: the capital's reserved square, 266
	-- either side of the anchor, the `bound_width` of `source/simple_map.lua`'s
	-- `hard_capital_city_v1`. The capital's protection (plan D76,
	-- `capital_protection.lua`) is built from the same wall line with the
	-- edge's reach and a band beyond it, so the edge always lies inside the
	-- protected city, and the city inside this square.
	square = {min_x = -266, max_x = 266, min_z = -266, max_z = 266},
	-- VERTICAL, absolute world y: the protection's own (y_min -700, upward
	-- unbounded). The edge publishes its actual absolute y range
	-- (`r7_capital_blueprint.lua`) and is held to this.
	world_y = {min = -700, max = 31000},
}

-- The box an overlay's identity publishes and the manifest checks it
-- against (`r7_manifest.lua`), in the identity's own mixed frame: x and z
-- from the anchor-relative square, y from the absolute world range.
local function overlay_identity_envelope()
	local square, world_y = M.CAPITAL_OVERLAY.square, M.CAPITAL_OVERLAY.world_y
	return {min = {x = square.min_x, y = world_y.min, z = square.min_z},
		max = {x = square.max_x, y = world_y.max, z = square.max_z}}
end

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
-- the ONE place a settlement is tied to a race, and the WP13 library KAT
-- (retired in Round 22) read it to check a start's window vocabulary and
-- its ground cover against that race's palette alone instead of guessing
-- from the node names, which can match two races at once.
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
	-- The capitals (contract section 3; since Round 22 laid out per world by
	-- the capital planner, `r7_capital_blueprint.lua`): a core in the start's
	-- shape, the placed district plots and the city edge overlay, built
	-- lazily. `plot_bounds` is the envelope every "reference" blueprint of this
	-- settlement is held to.
	{
		key = "highcourt", label = "Highcourt", race = "human",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "elandor_highcourt",
		anchor_id = "anchor_008", numeric_id = 8, x = 0, z = -1500,
		blueprint_file = "r7_capital_blueprint.lua",
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
	-- The dwarf capital: a stone curtain on the planner's outline (the user's
	-- ruling of 2026-09-14: walls for Dur Brannoc, Nhal Veyr and Gor Drazhak).
	{
		key = "dur_brannoc", label = "Dur Brannoc", race = "dwarf",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "elandor_dur_brannoc",
		anchor_id = "anchor_007", numeric_id = 7, x = -1800, z = -1500,
		blueprint_file = "r7_capital_blueprint.lua",
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
	-- The orc capital: a palisade on its rampart along the planner's outline
	-- (contract section 2.4, "palisade and earthworks").
	{
		key = "gor_drazhak", label = "Gor Drazhak", race = "orc",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "kragmar_gor_drazhak",
		anchor_id = "anchor_011", numeric_id = 11, x = 0, z = 1500,
		blueprint_file = "r7_capital_blueprint.lua",
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
	-- The elf capital, OPEN (the user's ruling of 2026-09-14): a planted belt
	-- and four thresholds on the planner's outline. It is also the only
	-- capital whose 96 x 96 civic core is not a full pad: WP40's authored crown
	-- lake (`wp40/water_authored.lua`) reaches into it, and the composition
	-- writes nothing over the water. See `wp13/lethariel.lua`.
	{
		key = "lethariel", label = "Lethariel", race = "elf",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "elandor_lethariel",
		anchor_id = "anchor_009", numeric_id = 9, x = 1800, z = -1500,
		blueprint_file = "r7_capital_blueprint.lua",
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
	-- The troll capital, OPEN: the authored cenote (`kezamba_cenote` in
	-- `wp40/water_authored.lua`) cuts a wedge of the civic core, whose
	-- composition builds round the water; a planted belt and four thresholds
	-- on the planner's outline.
	{
		key = "kezamba", label = "Kezamba", race = "troll",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "kragmar_kezamba",
		anchor_id = "anchor_012", numeric_id = 12, x = 1800, z = 1500,
		blueprint_file = "r7_capital_blueprint.lua",
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
	-- The undead capital: a stone curtain on the planner's outline.
	--
	-- LAST in the roster, by the coordinator's ruling at merge: appending
	-- rather than inserting kept every earlier capital's numeric ids and
	-- anchor ids where they were.
	{
		key = "nhal_veyr", label = "Nhal Veyr", race = "undead",
		slot = "capital", bounds = "capital_core", plot_bounds = "capital_plot",
		lazy = true,
		zone_id = "kragmar_nhal_veyr",
		anchor_id = "anchor_010", numeric_id = 10, x = -1800, z = 1500,
		blueprint_file = "r7_capital_blueprint.lua",
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
	local cells, seen, actual_min, actual_max = {}, {}, {}, {}
	-- The previous cell and the running bounds as plain locals: this loop runs
	-- once per cell of every blueprint (hundreds of thousands per
	-- construction, in both environments), so it allocates nothing per cell
	-- beyond the cell row and its identity line.
	local prior_x, prior_y, prior_z
	local min_x, min_y, min_z, max_x, max_y, max_z
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
		if prior_x and (z < prior_z or (z == prior_z and
				(y < prior_y or (y == prior_y and x <= prior_x)))) then
			fail(descriptor.id .. ": cells are not canonical z/y/x unique")
		end
		local key = packed_key(x, y, z)
		if seen[key] then fail(descriptor.id .. ": duplicate cell") end
		seen[key], prior_x, prior_y, prior_z = true, x, y, z
		cells[index] = {x = x, y = y, z = z, param2 = param2, name = cell.name}
		if min_x == nil or x < min_x then min_x = x end
		if max_x == nil or x > max_x then max_x = x end
		if min_y == nil or y < min_y then min_y = y end
		if max_y == nil or y > max_y then max_y = y end
		if min_z == nil or z < min_z then min_z = z end
		if max_z == nil or z > max_z then max_z = z end
		bytes[#bytes + 1] = "cell\t" .. x .. "\t" .. y .. "\t" .. z .. "\t" ..
			cell.name .. "\t" .. param2 .. "\n"
	end
	actual_min.x, actual_min.y, actual_min.z = min_x, min_y, min_z
	actual_max.x, actual_max.y, actual_max.z = max_x, max_y, max_z
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

-- The canonical identity bytes of a capital's CITY EDGE overlay (Round 22
-- capital planner). An overlay has no cells until a mapchunk asks for its
-- columns, so what is frozen is its specification: the edge geometry of the
-- world's capital layout (`overlay.spec`, the payload lines of the edge kind,
-- the gates, the wall points and the turrets), its reach and the exact set of
-- node names it may write. Main and emerge build it from the same payload.
local function prepare_city(fail, descriptor, overlay)
	if type(overlay) ~= "table" or overlay.schema ~= descriptor.blueprint_schema or
			type(overlay.spec) ~= "string" or overlay.spec == "" or
			type(overlay.make) ~= "function" or type(overlay.names) ~= "table" or
			#overlay.names < 1 or type(overlay.reach) ~= "table" or
			type(overlay.count) ~= "number" or overlay.count < 1 then
		fail(descriptor.id .. ": city edge seam differs")
	end
	local reach = overlay.reach
	for _, key in ipairs({"min_x", "max_x", "min_z", "max_z"}) do
		integer_or_fail(fail, reach[key], "city edge " .. key, -1023, 1023)
	end
	-- the city stays inside the capital's reserved square (design question 4)
	local square = M.CAPITAL_OVERLAY.square
	if reach.min_x < square.min_x or reach.max_x > square.max_x or
			reach.min_z < square.min_z or reach.max_z > square.max_z then
		fail(descriptor.id ..
			": the city edge leaves the capital's 532-node reserved square")
	end
	local bytes = {"schema\t" .. descriptor.identity_schema .. "\n", overlay.spec}
	local names = {}
	for index = 1, #overlay.names do
		local name = overlay.names[index]
		if type(name) ~= "string" or name == "" or
				(index > 1 and not M.less_bytes(overlay.names[index - 1], name)) then
			fail(descriptor.id .. ": city edge palette differs")
		end
		names[index] = name
		bytes[#bytes + 1] = table.concat({"palette", index, name}, "\t") .. "\n"
	end
	-- the edge's own absolute y range (walk, gatehouses, piers), published in
	-- place of the anchor-relative y of a cell blueprint
	local world_y = M.CAPITAL_OVERLAY.world_y
	integer_or_fail(fail, overlay.y_min, "city edge y_min", world_y.min, world_y.max)
	integer_or_fail(fail, overlay.y_max, "city edge y_max", overlay.y_min, world_y.max)
	local bounds = {min = {x = reach.min_x, y = overlay.y_min, z = reach.min_z},
		max = {x = reach.max_x, y = overlay.y_max, z = reach.max_z}}
	bytes[#bytes + 1] = table.concat({"reach", bounds.min.x, bounds.min.y,
		bounds.min.z, bounds.max.x, bounds.max.y, bounds.max.z}, "\t") .. "\n"
	return {palette = names, identity_bytes = table.concat(bytes), city = overlay,
		bounds = bounds,
		-- An overlay publishes the size of its specification (the wall
		-- points) instead of a cell count.
		run_count = overlay.count}
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
-- the placed plots of this world's capital layout and the city edge overlay
-- (`r7_capital_blueprint.lua`). Returns the ordered blueprint descriptors; an
-- identity schema is derived from the blueprint's own schema string, which is
-- what keeps Hearthpine's `grug_wp13_hearthpine_blueprint_identity_v1`
-- exactly where it was.
--
-- A capital plot is placed by the planner: its offset from the anchor, its
-- quarter TURNS (the entry faces its street) and its base height `y` (the
-- plot origin's ground in the planner's sample). Its identity stays the
-- unrotated cells; the turn is applied where the cells are projected.
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
		integer_or_fail(fail, plot.turns, "plot turns", 0, 3)
		integer_or_fail(fail, plot.y, "plot base y", -31000, 31000)
		add({id = "plot_" .. plot.id, plot_id = plot.id,
			prefix = profile.key .. "_" .. plot.id, kind = "reference",
			bounds = plot_bounds, blueprint_schema = plot.schema,
			identity_schema = identity_schema_of(fail, plot.schema),
			offset = {x = plot.x, z = plot.z}, turns = plot.turns, base_y = plot.y,
			build = plot.build})
	end
	add({id = "city", prefix = profile.key .. "_city", kind = "overlay",
		bounds = overlay_identity_envelope(), blueprint_schema = source.overlay.schema,
		identity_schema = identity_schema_of(fail, source.overlay.schema),
		overlay = source.overlay})
	return list
end

-- Build one blueprint, hash it, and keep what is not a cell: the identity,
-- the palette and the landmarks (the NPC sockets among them). The cells of a
-- LAZY settlement are dropped here and rebuilt on the first mapchunk that
-- touches the blueprint; an eager settlement keeps them.
local function prepare_one(profile, descriptor, raw_sha256, fail)
	local prepared
	if descriptor.kind == "overlay" then
		prepared = prepare_city(fail, descriptor, descriptor.overlay)
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
		-- specification under its own field name.
		cell_count = prepared.cells and #prepared.cells or nil,
		run_count = prepared.run_count,
		min_x = box.min.x, min_y = box.min.y, min_z = box.min.z,
		max_x = box.max.x, max_y = box.max.y, max_z = box.max.z}
	prepared.identity_bytes = nil
	prepared.descriptor = descriptor
	if profile.lazy then prepared.cells = nil end
	return prepared
end

local function check_profile(profile)
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
	return fail
end

-- One capital plot prepared BEFORE the capital is laid out (main): the
-- planner needs the plot's bounds and cleared airspace, and `M.prepare`
-- later reuses this preparation (pass the table of these, keyed by manifest
-- prefix, as its `cache`), so every plot is built once. `plot` is the
-- district roster entry ({id, schema, build}).
function M.prepare_plot(profile, plot, raw_sha256)
	local fail = check_profile(profile)
	local plot_bounds = M.BOUNDS[profile.plot_bounds]
	if type(plot_bounds) ~= "table" then fail("profile plot bounds differ") end
	local descriptor = {id = "plot_" .. plot.id, plot_id = plot.id,
		prefix = profile.key .. "_" .. plot.id, kind = "reference",
		bounds = plot_bounds, blueprint_schema = plot.schema,
		identity_schema = identity_schema_of(fail, plot.schema), build = plot.build}
	return prepare_one(profile, descriptor, raw_sha256, fail)
end

-- Build every blueprint of a settlement once, hash it (or take its
-- preparation from `cache`, keyed by manifest prefix), and keep what is not a
-- cell.
function M.prepare(profile, source, raw_sha256, cache)
	local fail = check_profile(profile)
	if type(raw_sha256) ~= "function" then fail("SHA-256 seam differs") end
	local descriptors = M.descriptors(profile, source)
	local blueprints, union, seen = {}, {}, {}
	for index = 1, #descriptors do
		local descriptor = descriptors[index]
		local prepared = cache and cache[descriptor.prefix]
		if prepared then
			local identity = prepared.identity
			if descriptor.kind == "overlay" or type(identity) ~= "table" or
					identity.schema ~= descriptor.identity_schema or
					type(identity.sha256) ~= "string" or #identity.sha256 ~= 64 or
					identity.sha256:find("[^0-9a-f]") or type(prepared.palette) ~= "table" or
					#prepared.palette < 1 or type(prepared.bounds) ~= "table" then
				fail(descriptor.id .. ": cached preparation differs")
			end
			local copy = {}
			for key, value in pairs(prepared) do copy[key] = value end
			copy.descriptor = descriptor
			prepared = copy
		else
			prepared = prepare_one(profile, descriptor, raw_sha256, fail)
		end
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

-- Plain data only (numbers, strings, booleans, tables of them): what may
-- cross the main/emerge IPC boundary.
local function plain_copy(value, label)
	local kind = type(value)
	if kind == "table" then
		local copy = {}
		for key, entry in pairs(value) do
			local key_kind = type(key)
			if key_kind ~= "string" and key_kind ~= "number" then
				error("WP13 settlement handover: " .. label .. " key differs", 0)
			end
			copy[key] = plain_copy(entry, label)
		end
		return copy
	elseif kind == "number" or kind == "string" or kind == "boolean" then
		return value
	end
	error("WP13 settlement handover: " .. label .. " holds a " .. kind, 0)
end

-- MAIN HANDS EMERGE ITS LAZY PREPARATIONS (Round 22 cleanup). Every
-- blueprint of a LAZY settlement that has cells drops them after its
-- identity is hashed, so what main keeps is plain data: the identity, the
-- palette, the bounds, the landmarks, the reference column and the cleared
-- airspace. Emerge takes these (`M.prepare`'s `cache`, keyed by manifest
-- prefix) instead of building and hashing every blueprint a second time at
-- load, and `M.config` checks every lazy rebuild against them. Starts
-- (eager, their cells are kept) and city edge overlays (built from the
-- capital layout text emerge has) are never handed over. Adds the records
-- of `prepared` to `out` and returns it.
function M.handover(prepared, out)
	if type(prepared) ~= "table" or
			prepared.schema ~= "grug_wp13_settlement_prepared_v1" or type(out) ~= "table" then
		error("WP13 settlement handover: prepared settlement differs", 0)
	end
	if not prepared.profile.lazy then return out end
	for index = 1, #prepared.blueprints do
		local blueprint = prepared.blueprints[index]
		local descriptor = blueprint.descriptor
		if descriptor.kind ~= "overlay" then
			if blueprint.cells ~= nil or out[descriptor.prefix] ~= nil then
				error("WP13 settlement handover: " .. descriptor.prefix .. " differs", 0)
			end
			out[descriptor.prefix] = plain_copy({identity = blueprint.identity,
				palette = blueprint.palette, bounds = blueprint.bounds,
				landmarks = blueprint.landmarks, reference = blueprint.reference,
				clear_to = blueprint.clear_to, run_count = blueprint.run_count},
				descriptor.prefix)
		end
	end
	return out
end

-- Whether two plain values are equal throughout (the handover check).
local function same_plain(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for key, value in pairs(a) do
		if not same_plain(value, b[key]) then return false end
	end
	for key in pairs(b) do
		if a[key] == nil then return false end
	end
	return true
end

-- The world rectangle of a placed capital plot: its unrotated bounds turned
-- by the plot's quarter turns, at its offset from the anchor at (x, z).
function M.plot_rect(blueprint, x, z)
	local descriptor, b = blueprint.descriptor, blueprint.identity
	local turns = descriptor.turns or 0
	local ax, az = rot(b.min_x, b.min_z, turns)
	local bx, bz = rot(b.max_x, b.max_z, turns)
	local ox, oz = x + descriptor.offset.x, z + descriptor.offset.z
	return {min_x = ox + math.min(ax, bx), max_x = ox + math.max(ax, bx),
		min_z = oz + math.min(az, bz), max_z = oz + math.max(az, bz)}
end

-- WHAT THE GROUND UNDER A PLACED CAPITAL PLOT ACTUALLY LOOKS LIKE.
--
-- The capital planner places every plot on its own sample of the fitted
-- ground (dry with a margin, fall under the skirt, rise under the cleared
-- airspace), before its streets exist. The world then carries the streets'
-- cut and fill and the canal. This is the diagnostic that says where a plot
-- no longer stands on this world's final ground: it logs, it changes no
-- cell, and it is called once per load from the main environment.
--
-- The PERIMETER and the two-node margin ring are walked exactly, the interior
-- on a stride of two. `column_at(x, z)` is `planner_source.column_values_at`:
-- its first return is the water class and its sixth the final terrain height.
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
			local rect = M.plot_rect(blueprint, anchor.x, anchor.z)
			local base = descriptor.base_y
			local wet = 0
			local edge_low, high = base, base
			local function sample(x, z, edge)
				local column_class, _, _, _, _, y, water_y = column_at(x, z)
				if column_class ~= "land" or (type(water_y) == "number" and
						type(y) == "number" and water_y > y) then
					wet = wet + 1
				end
				if type(y) == "number" then
					if y > high then high = y end
					if edge and y < edge_low then edge_low = y end
				end
			end
			for z = rect.min_z - margin, rect.max_z + margin do
				for x = rect.min_x - margin, rect.max_x + margin do
					local outside = x < rect.min_x or x > rect.max_x or
						z < rect.min_z or z > rect.max_z
					local edge = (not outside) and
						(x == rect.min_x or x == rect.max_x or
							z == rect.min_z or z == rect.max_z)
					if outside or edge then
						sample(x, z, edge)
					elseif x % 2 == 0 and z % 2 == 0 then
						sample(x, z, false)
					end
				end
			end
			local fall, rise = base - edge_low, high - base
			local clear = blueprint.clear_to or blueprint.identity.max_y
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
-- `grug_core.register_settlement_sockets`. A plot's sockets are PLOT-relative
-- and turned with the plot, so every correction happens here and nowhere
-- else: the plot's quarter turns (position, facing and the inn arrival side),
-- its offset from the anchor, and the difference between the plot's base
-- height (the planner's, the same the writer projects the cells from) and the
-- settlement's fitted anchor height.
--
-- A socket id is unique only within its own composition (a plot knows nothing
-- of the plot next door), so a plot's ids are prefixed with the plot id.
function M.sockets(prepared, anchor)
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
			local dx, dy, dz, turns, prefix = 0, 0, 0, 0, ""
			local arrival
			if descriptor.kind == "reference" then
				local base = descriptor.base_y
				if type(base) ~= "number" or base % 1 ~= 0 then
					fail(descriptor.id .. ": base height differs")
				end
				dx, dy, dz = descriptor.offset.x, base - anchor.y, descriptor.offset.z
				turns = descriptor.turns or 0
				prefix = descriptor.plot_id .. "/"
				-- the plot's own +x: where an arrival beside a socket stands
				-- (grug_home's inn arrival), turned with the plot
				local ax, az = rot(1, 0, turns)
				arrival = {x = ax, z = az}
			end
			for socket_index = 1, #sockets do
				local socket = sockets[socket_index]
				if type(socket) ~= "table" or type(socket.id) ~= "string" then
					fail(descriptor.id .. ": socket differs")
				end
				local row = {}
				for key, value in pairs(socket) do row[key] = value end
				row.id = prefix .. socket.id
				local sx, sz = rot(socket.x, socket.z, turns)
				row.x, row.y, row.z = sx + dx, socket.y + dy, sz + dz
				if type(socket.face) == "number" then row.face = (socket.face + turns) % 4 end
				if type(socket.dir) == "table" then
					local fx, fz = rot(socket.dir.x, socket.dir.z, turns)
					row.dir = {x = fx, z = fz}
				end
				row.arrival = arrival
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

		-- The final column answers, reached from the planner source the
		-- successor is constructed with. Only a settlement that owns a placed
		-- plot or a city edge needs them, so a start's dependencies are
		-- unchanged.
		local needs_height = false
		for index = 1, #prepared.blueprints do
			local kind = prepared.blueprints[index].descriptor.kind
			if kind == "reference" or kind == "overlay" then needs_height = true end
		end
		local column_values_at, road_column_at
		if needs_height then
			local planner_source = dependencies.planner_source
			if type(planner_source) ~= "table" or
					type(planner_source.column_values_at) ~= "function" then
				fail("planner source differs")
			end
			column_values_at = planner_source.column_values_at
			road_column_at = planner_source.road_column_at
		end
		-- A column's final ground, the water surface standing on it (nil when
		-- dry) and whether a road, street or square surface covers it.
		local function column(x, z)
			local _, _, _, _, _, terrain_y, water_y = column_values_at(x, z)
			if type(terrain_y) ~= "number" or terrain_y % 1 ~= 0 then
				fail("final height at " .. x .. "," .. z .. " differs")
			end
			local road = false
			if road_column_at then road = road_column_at(x, z) == "surface" end
			if type(water_y) ~= "number" or water_y <= terrain_y then water_y = nil end
			return terrain_y, water_y, road
		end

		local metrics = {plan_calls = 0, settle_calls = 0, replay_calls = 0,
			written = 0, build_calls = 0, release_calls = 0,
			overlay_calls = 0}

		-- Y CULLING of the plot collars and the city edge. Both are pure
		-- functions of a column's x and z (its final ground, water and road
		-- surface) and write at heights that follow that ground, so which
		-- chunks of a vertical stack they reach is only known after one pass.
		-- The first chunk of a FOOTPRINT (the owner's x/z rectangle, the same
		-- for every chunk of the stack) runs them in full and records the y
		-- range of everything they would write, inside its owner or not; a
		-- later chunk of that footprint whose y range misses the recorded one
		-- skips both, since each of those writes would fall outside its owner.
		-- Keyed by footprint, bounded by the few dozen footprints over the
		-- capital's reserved square.
		local write_span = {}

		-- Per-session state of every blueprint: the world box it occupies, the
		-- cells with their content refs (nil while released) and, for a city
		-- edge, its geometry index.
		local states = {}
		for index = 1, #prepared.blueprints do
			local blueprint = prepared.blueprints[index]
			local descriptor = blueprint.descriptor
			local state = {blueprint = blueprint, descriptor = descriptor,
				active = false, idle = 0}
			if descriptor.kind == "overlay" then
				state.edge = blueprint.city.make({x = anchor.x, z = anchor.z})
				local b = blueprint.bounds
				state.box = {min_x = anchor.x + b.min.x, max_x = anchor.x + b.max.x,
					min_z = anchor.z + b.min.z, max_z = anchor.z + b.max.z}
			end
			states[index] = state
		end

		-- The world box of a blueprint, and the base its cells are projected
		-- from: the fitted anchor for an anchor-relative blueprint, the
		-- planner's base height at the plot's offset for a capital plot (its
		-- box turned with the plot).
		local function base_of(state)
			if state.base then return state.base end
			local descriptor = state.descriptor
			local base
			local bounds = state.blueprint.bounds
			local x0, x1, z0, z1 = bounds.min.x, bounds.max.x, bounds.min.z, bounds.max.z
			if descriptor.kind == "anchor" then
				base = {x = anchor.x, y = anchor.y, z = anchor.z}
			else
				base = {x = anchor.x + descriptor.offset.x, y = descriptor.base_y,
					z = anchor.z + descriptor.offset.z}
				local rect = M.plot_rect(state.blueprint, anchor.x, anchor.z)
				x0, x1 = rect.min_x - base.x, rect.max_x - base.x
				z0, z1 = rect.min_z - base.z, rect.max_z - base.z
			end
			state.base = base
			state.box = {min_x = base.x + x0, max_x = base.x + x1,
				min_y = base.y + bounds.min.y, max_y = base.y + bounds.max.y,
				min_z = base.z + z0, max_z = base.z + z1}
			return base
		end

		-- The cells of a blueprint with their content refs, turned with the
		-- plot. Built on demand: a lazy settlement holds none until a mapchunk
		-- touches it, and the rebuild is compared against the identity the
		-- manifest published (the UNROTATED cells), so a composition that is
		-- not a pure function of its own source is a loud failure and not a
		-- silently different capital. A turn rotates every position (0 - x,
		-- never -x: a signed zero would be another key), every oriented param2
		-- (`parts.rotate_param2`), and settles the panes again on the turned
		-- plot, which is what the engine would do for a placed pane.
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
				-- What the identity bytes do not cover and a preparation (in
				-- emerge: main's handover) still carries.
				if not same_plain(rebuilt.landmarks, state.blueprint.landmarks) or
						not same_plain(rebuilt.reference, state.blueprint.reference) or
						rebuilt.clear_to ~= state.blueprint.clear_to then
					fail(state.descriptor.id ..
						": the lazy rebuild differs from its preparation's landmarks")
				end
				source_cells = rebuilt.cells
			end
			local turns = state.descriptor.turns or 0
			if turns ~= 0 then
				local buf = parts.buffer()
				for index = 1, #source_cells do
					local cell = source_cells[index]
					local x, z = rot(cell.x, cell.z, turns)
					buf:put(x, cell.y, z, cell.name, parts.canonical_param2(cell.name,
						parts.rotate_param2(cell.param2, parts.param2_kind(cell.name), turns)))
				end
				parts.resolve_panes(buf)
				local order, count = buf:cells()
				local turned = {}
				for index = 1, count do turned[index] = order[index] end
				source_cells = turned
			end
			local cells = {}
			for index = 1, #source_cells do
				local cell = source_cells[index]
				local ref = refs[cell.name]
				if not ref then
					fail(state.descriptor.id .. ": cell name lost its content ref: " ..
						tostring(cell.name))
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

		-- The collars and approaches of the placed plots (`wp13/plot_approach.
		-- lua`): the path from a plot's entry runs straight along its front to
		-- the first street, road or square surface column, found once per
		-- session per plot from the pure road answer.
		local approaches
		local approach_findings = {}
		local function prepare_approach(record)
			if record.sampled then return end
			record.sampled = true
			for step = 1, plot_approach.MAX_APPROACH do
				local lx, lz = rot(record.entry_x, record.min_z - step, record.turns)
				local x, z = record.x + lx, record.z + lz
				if road_column_at then
					local kind, road_y = road_column_at(x, z)
					if kind == "surface" then
						if step > 1 then
							record.road_len, record.road_y = step - 1, road_y
						end
						return
					end
				end
			end
			approach_findings[#approach_findings + 1] = record.state.descriptor.id ..
				": no street within " .. plot_approach.MAX_APPROACH .. " of the entry"
		end
		local function prepare_approaches()
			if approaches then return approaches end
			local plots = {}
			for _, state in ipairs(states) do
				if state.descriptor.kind == "reference" then
					local base = base_of(state)
					local marks = state.blueprint.landmarks
					local plot = marks and marks.plot
					local entry = marks and marks.entry
					if plot and entry then
						local record = {state = state, y = base.y, x = base.x, z = base.z,
							turns = state.descriptor.turns or 0,
							min_x = plot.min.x, max_x = plot.max.x,
							min_z = plot.min.z, max_z = plot.max.z, entry_x = entry.x}
						prepare_approach(record)
						plots[#plots + 1] = record
					end
				end
			end
			approaches = plot_approach.new(plots)
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
					local box = state.box
					state.active = box.max_x >= minp.x and box.min_x <= maxp.x and
						box.max_z >= minp.z and box.min_z <= maxp.z
				else
					if not state.box then base_of(state) end
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
			-- The plots' collars and approaches precede every plot and the
			-- edge. Work is clipped to this owner; neighbouring chunks ask the
			-- same pure answers.
			local footprint = context.min_x .. ":" .. context.min_z .. ":" ..
				context.max_x .. ":" .. context.max_z
			local span = write_span[footprint]
			local edge_work = span == nil or (span.low ~= nil and
				span.low <= context.max_y and span.high >= context.min_y)
			local low, high
			local function reach(y)
				if low == nil or y < low then low = y end
				if high == nil or y > high then high = y end
			end
			-- the collars lie in the reserved square (|dx|, |dz| < 266), the
			-- civic core excepted
			local collar_work = edge_work and
				context.max_x > anchor.x - 266 and context.min_x < anchor.x + 266 and
				context.max_z > anchor.z - 266 and context.min_z < anchor.z + 266
			local recorded = false
			local fittings = prepare_approaches()
			local fit_palette = approach_palettes.new(profile.race)
			local ground_ref, air_ref = refs[fit_palette.node("ground")], refs.air
			local fill_ref = refs[fit_palette.node("subsoil")] or ground_ref
			local path_ref = refs[fit_palette.maybe("castle_paving") or fit_palette.node("plaza")]
			local step_ref = refs[fit_palette.maybe("castle_wall_stair") or fit_palette.node("roof_stair")]
			local function fit_write(x, y, z, ref, face)
				if not ref then fail("plot approach material is outside settlement palette") end
				reach(y)
				if context.inside_owner(x, y, z) then
					local cid, param2 = content.resolve(ref, face or 0)
					context.write_hearthpine(x, y, z, cid, param2, ref, 1)
					written = written + 1
				end
			end
			if collar_work and #fittings.plots > 0 then
				recorded = true
				for z = context.min_z, context.max_z do
					for x = context.min_x, context.max_x do
						local lx, lz = x - anchor.x, z - anchor.z
						-- (the civic core shapes its own ground)
						if math.abs(lx) < 266 and math.abs(lz) < 266 and
								(math.abs(lx) > 49 or math.abs(lz) > 49) then
							-- Probe membership cheaply before querying terrain.
							local _, record = fittings.surface(x, z, 0)
							if record then
								local natural, water, road = column(x, z)
								if not water and not road then
									local top, chosen, access, clx, clz =
										fittings.surface(x, z, natural)
									if chosen and (top ~= natural or access) then
										for y = natural, top - 1 do fit_write(x, y, z, fill_ref) end
										local before = access and plot_approach.path_height(chosen, clz - 1) or top
										local after = access and plot_approach.path_height(chosen, clz + 1) or top
										if access and (top > before or top > after) then
											-- a stair rising toward the higher side, turned
											-- with the plot (local +z is facedir 0)
											local face = (after >= before and 0 or 2)
											fit_write(x, top, z, step_ref, (face + chosen.turns) % 4)
										else
											fit_write(x, top, z, access and path_ref or ground_ref)
										end
										for y = top + 1, math.max(natural, top + 3) do
											fit_write(x, y, z, air_ref)
										end
									end
								end
							end
						end
					end
				end
			end
			-- Cells first, in blueprint order (the core, then the plots), and the
			-- city edge last.
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
				if edge_work and state.active and state.descriptor.kind == "overlay" then
					recorded = true
					metrics.overlay_calls = metrics.overlay_calls + 1
					local cells = state.edge.cells({min_x = context.min_x,
						max_x = context.max_x, min_z = context.min_z,
						max_z = context.max_z}, column)
					for cell_index = 1, #cells do
						local cell = cells[cell_index]
						local ref = refs[cell.name]
						if not ref then
							fail("city edge name outside the overlay palette: " ..
								tostring(cell.name))
						end
						reach(cell.y)
						if context.inside_owner(cell.x, cell.y, cell.z) then
							local cid, param2 = content.resolve(ref, cell.param2)
							context.write_hearthpine(cell.x, cell.y, cell.z, cid, param2, ref, 1)
							written = written + 1
						end
					end
				end
			end
			-- the first full pass over this footprint records its write range
			-- (low nil: nothing to write here at any height)
			if recorded and span == nil then
				write_span[footprint] = {low = low, high = high}
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
				overlay_calls = metrics.overlay_calls,
				blueprint_sha256 = config.identity.sha256, approach_findings = approach_findings}
		end
		return tail
	end
	return config
end

return M
