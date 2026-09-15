-- WP13 settlement palette: role to node name, one table per race.
--
-- Every generator in this library addresses nodes only through roles, so one
-- generator can serve six races (docs/research/wp13-settlement-pipeline.md
-- section 4). Plain Lua 5.1, no engine calls, no globals.

local M = {}

-- Roles a generator may rely on unconditionally.
M.required = {
	"beam", "bed", "ceiling", "chimney", "chimney_cap", "door", "door_hidden",
	"fence", "fence_rail", "fern", "floor", "foundation", "grass_tuft",
	"ground", "ground_bare", "ground_patch", "hearth", "light_indoor",
	"light_post", "light_wall", "low_wall", "path", "planter", "planter_soil",
	"plaza", "plaza_edge", "post", "railing", "roof_ridge", "roof_slab",
	"roof_stair", "roof_stair_inner", "roof_stair_outer", "rubble", "rug",
	"rug_accent", "seat", "shelf", "shelf_vessels", "storage", "subsoil",
	"table_leg", "table_top", "tree_leaves", "tree_log", "undergrowth",
	"wall", "wall_accent", "window", "window_frame", "workbench",
}

-- Roles a generator must degrade gracefully without. Everything a race can
-- do without lives here, so a palette that has no half timbering, no straw
-- and no flower pots still builds; `palette.maybe(role)` answers nil and the
-- part that wanted it writes nothing.
M.optional = {"bale", "bed_fancy", "bench_seat", "board_table", "cargo",
	"castle_paving", "castle_rubble", "castle_slit", "castle_wall",
	"castle_wall_slab", "castle_wall_stair", "cobweb", "crop", "crop_soil",
	"fence_gate", "flower", "flower_alt", "ground_straw", "hedge",
	"hedge_stem", "ivy", "lantern", "light_beacon", "light_hanging", "mat",
	"pillar", "rope", "shutter", "signature", "signature_slab",
	"signature_stair", "stake_cap", "stepping", "throne", "wall_infill",
	"water", "wheel"}

-- The capital vocabulary (docs/research/wp13-capitals-pois-contract.md
-- section 2.4): the castle kit for the walls, pillars, arrowslits, paving and
-- rubble of a citadel, and one SIGNATURE material per race -- stone block,
-- brick, marble, obsidian brick, adobe, basalt. Everything here is optional,
-- for two reasons. A start composition must keep building without it, which
-- is what keeps the six shipped start blueprints byte-identical; and a part
-- that wants a signature stair for a race whose signature material ships no
-- stair shape has to degrade rather than name a node that is not registered.
--
-- `pillar` was already the undead vocabulary and keeps its binding exactly;
-- the other five races bind the castle pillar of their own masonry, so the
-- three-node `_bottom`/`_middle`/`_top` stack of `prefix_roles` reaches every
-- capital. Nothing in the six start compositions but Stillgrave's gate reads
-- the role, so the five new bindings move no shipped cell.
--
-- `signature_stair`/`signature_slab` are NOT always the shape family of
-- `signature`: `grug_decor:darkage_adobe` ships no stair or slab shape at
-- all (mods/ITEMS/grug_decor/darkage.lua, the `shaped` roster), so the orc
-- pair is the Old Red Sandstone brick the same palette already builds its
-- base courses out of.

-- Two optional light roles for races whose lamps are not wallmounted.
-- `light_hanging` is a lamp in `group:attached_node = 4`, which the engine
-- keeps only while the node ABOVE it is walkable, so `parts.hanging_light`
-- is the only emitter and it refuses any other support. `light_beacon` is a
-- full glowing cube that carries itself and is built into masonry. Neither
-- has a paramtype2, so both are written at param2 0; the required
-- `light_wall` / `light_post` / `light_indoor` trio stays wallmounted,
-- because that is what `parts.wall_torch` and `parts.floor_torch` write.
--
-- `lantern` and `rope` are the troll vocabulary: `lantern` binds
-- `grug_decor:xdecor_lantern_hanging` (`attached_node = 4`, the engine's
-- "attach to ceiling"; rating 3 would mean floor), and `xdecor_rope`, which
-- has no attachment group, falls from the underside of a stilt deck by
-- authoring convention. The four start
-- lanes each added their own roles here; the integration folded them into the
-- one sorted literal above.

-- Three roles do not name a node at all: they name the BASE of a family the
-- engine registers under several suffixes, and only the part that knows the
-- family may put one together. The suffix set lives here so that a typo in a
-- part fails at construction time instead of writing an unregistered name.
M.prefix_roles = {
	door = {"_a", "_b"},
	bed = {"_bottom", "_top"},
	bed_fancy = {"_bottom", "_top"},
	-- A dressed stone column is three registered nodes, not one: the castle
	-- kit ships `_bottom`, `_middle` and `_top` shapes that only read as a
	-- pillar when they are stacked in that order.
	pillar = {"_bottom", "_middle", "_top"},
}

-- Roles that must be bound to a node with no metadata behaviour at all.
-- WP13 writes its cells through VoxelManip, and `on_construct` is never run
-- for bulk placement (lua_api.md), so a chest, a furnace, a bookshelf or a
-- vessel shelf written this way has no inventory and no formspec: it is a
-- dead prop that a player can open into nothing. Every furnishing role is
-- therefore bound to a static decor node. `tools/wp13/library_kat.lua`
-- proves this for EVERY palette name against the real registrations, so
-- no role list is kept here.

M.races = {}

-- Dwarf (Hearthpine Vale): stone footings, pine timber, warm torchlight.
M.races.dwarf = {
	ground = "default:dirt_with_coniferous_litter",
	ground_patch = "default:dirt_with_grass",
	ground_bare = "default:dirt",
	subsoil = "default:dirt",
	path = "default:cobble",
	plaza = "default:stone_block",
	plaza_edge = "default:stonebrick",
	rubble = "default:gravel",

	foundation = "default:stone_block",
	wall = "default:pine_wood",
	wall_accent = "default:stonebrick",
	post = "default:pine_tree",
	beam = "default:pine_tree",
	floor = "default:pine_wood",
	ceiling = "default:pine_wood",

	roof_stair = "stairs:stair_pine_wood",
	roof_stair_outer = "stairs:stair_outer_pine_wood",
	roof_stair_inner = "stairs:stair_inner_pine_wood",
	roof_slab = "stairs:slab_pine_wood",
	roof_ridge = "default:pine_wood",

	window = "xpanes:pane_flat",
	window_frame = "default:pine_tree",
	door = "doors:door_wood",
	door_hidden = "doors:hidden",

	fence = "default:fence_pine_wood",
	fence_rail = "default:fence_rail_pine_wood",
	low_wall = "walls:cobble",
	railing = "default:fence_pine_wood",

	light_wall = "default:torch_wall",
	light_post = "default:torch",
	light_indoor = "default:torch_wall",

	bed = "beds:bed",
	bed_fancy = "beds:fancy_bed",
	table_top = "stairs:slab_pine_wood",
	table_leg = "default:fence_pine_wood",
	seat = "stairs:stair_pine_wood",
	-- Furnishing: static decor only. A `default:chest`, `default:bookshelf`,
	-- `vessels:shelf` or `default:furnace` placed by VoxelManip never gets
	-- its `on_construct`, so it carries no inventory and no formspec; the
	-- barrel, the plain shelf, the crock shelf and the cauldron are pure
	-- geometry and look the part without pretending to a service the
	-- settlement design explicitly does not offer.
	shelf = "grug_decor:xdecor_empty_shelf",
	shelf_vessels = "grug_decor:cottages_shelf",
	storage = "grug_decor:xdecor_barrel",
	workbench = "grug_materials:iron_block",
	hearth = "grug_decor:xdecor_cauldron",
	chimney = "default:stonebrick",
	chimney_cap = "stairs:slab_stonebrick",
	rug = "wool:brown",
	rug_accent = "wool:red",

	-- Capital vocabulary: Dur Brannoc's citadel. Stone block is the dwarf
	-- signature of the capitals contract, and it is the one signature
	-- material that carries the `stone` group, so a pane set in a signature
	-- course connects to it (`parts.pane_connects`).
	castle_wall = "grug_decor:castle_stonewall",
	castle_wall_stair = "grug_decor:castle_stonewall_stair",
	castle_wall_slab = "grug_decor:castle_stonewall_slab",
	castle_paving = "grug_decor:castle_pavement_brick",
	castle_rubble = "grug_decor:castle_rubble",
	castle_slit = "grug_decor:castle_arrowslit_stone_block",
	pillar = "grug_decor:castle_pillar_stone_block",
	signature = "default:stone_block",
	signature_stair = "stairs:stair_stone_block",
	signature_slab = "stairs:slab_stone_block",
	throne = "grug_decor:xdecor_chair",

	planter = "default:stonebrick",
	planter_soil = "default:dirt_with_grass",
	tree_log = "default:pine_tree",
	tree_leaves = "default:pine_needles",
	undergrowth = "default:fern_1",
	grass_tuft = "default:grass_1",
	fern = "default:fern_2",
}

-- Human (Dawnmere Fields): cobble footings, plank and half-timbered walls,
-- brick accents and chimneys, oak framing, and the straw, barrels, bales and
-- flower pots of a working farm. Contract section 4's human column, plus the
-- kit nodes that fit it; the roof stays the `stairs:` family because the
-- cottages roof nodes ship no corner shapes (see the increment-3 evidence).
M.races.human = {
	ground = "default:dirt_with_grass",
	ground_patch = "default:dirt",
	ground_bare = "default:gravel",
	ground_straw = "grug_decor:cottages_straw_ground",
	subsoil = "default:dirt",
	path = "default:cobble",
	plaza = "default:cobble",
	plaza_edge = "default:brick",
	stepping = "grug_decor:xdecor_stonepath",
	rubble = "default:gravel",

	foundation = "default:cobble",
	wall = "default:wood",
	wall_infill = "grug_decor:cottages_loam",
	wall_accent = "default:brick",
	post = "default:tree",
	beam = "default:tree",
	floor = "default:wood",
	ceiling = "default:wood",

	roof_stair = "stairs:stair_wood",
	roof_stair_outer = "stairs:stair_outer_wood",
	roof_stair_inner = "stairs:stair_inner_wood",
	roof_slab = "stairs:slab_wood",
	roof_ridge = "default:wood",

	window = "xpanes:pane_flat",
	window_frame = "default:tree",
	shutter = "grug_decor:cottages_window_shutter_closed",
	door = "doors:door_wood",
	door_hidden = "doors:hidden",

	fence = "default:fence_wood",
	fence_rail = "default:fence_rail_wood",
	fence_gate = "doors:gate_wood_closed",
	low_wall = "walls:cobble",
	railing = "default:fence_wood",

	light_wall = "default:torch_wall",
	light_post = "default:torch",
	light_indoor = "default:torch_wall",

	bed = "beds:bed",
	bed_fancy = "beds:fancy_bed",
	table_top = "stairs:slab_wood",
	table_leg = "default:fence_wood",
	seat = "stairs:stair_wood",
	bench_seat = "grug_decor:cottages_bench",
	board_table = "grug_decor:cottages_table",
	mat = "grug_decor:cottages_straw_mat",
	bale = "grug_decor:cottages_straw_bale",
	wheel = "grug_decor:cottages_wagon_wheel",
	-- Furnishing: static decor only, for the reason written above the dwarf
	-- palette. The anvil is the human workbench; it is geometry, not a
	-- crafting service.
	shelf = "grug_decor:xdecor_empty_shelf",
	shelf_vessels = "grug_decor:cottages_shelf",
	storage = "grug_decor:xdecor_barrel",
	workbench = "grug_decor:cottages_anvil",
	hearth = "grug_decor:xdecor_cauldron",
	chimney = "default:brick",
	chimney_cap = "stairs:slab_brick",
	rug = "wool:white",
	rug_accent = "wool:red",

	-- Capital vocabulary: Highcourt. Brick is the human signature of the
	-- capitals contract and the palette already builds its accents and
	-- chimneys out of it, so the citadel courses read as the same city.
	castle_wall = "grug_decor:castle_stonewall",
	castle_wall_stair = "grug_decor:castle_stonewall_stair",
	castle_wall_slab = "grug_decor:castle_stonewall_slab",
	castle_paving = "grug_decor:castle_pavement_brick",
	castle_rubble = "grug_decor:castle_rubble",
	castle_slit = "grug_decor:castle_arrowslit_stonebrick",
	pillar = "grug_decor:castle_pillar_stonebrick",
	signature = "default:brick",
	signature_stair = "stairs:stair_brick",
	signature_slab = "stairs:slab_brick",
	throne = "grug_decor:xdecor_chair",

	planter = "default:brick",
	planter_soil = "default:dirt_with_grass",
	flower = "grug_decor:xdecor_potted_geranium",
	flower_alt = "grug_decor:xdecor_potted_dandelion_yellow",
	crop = "default:junglegrass",
	-- The furrow the hamlet's fields are ploughed out of. It is NOT
	-- `ground_patch` (`default:dirt`): default's "Grass spread" ABM names
	-- exactly `default:dirt` and nothing else, so a field written out of the
	-- worn-earth role greened over row by row while the player watched.
	-- `grug_nodes:tilled_soil` is outside that ABM's `nodenames` and carries
	-- no `spreading_dirt_type`, so it is neither a target nor a source of
	-- grass spread and a field stays a field. Only this race ploughs, so only
	-- this palette binds the role; `dressing.crop_rows` falls back to the old
	-- pair for a race that does not.
	crop_soil = "grug_nodes:tilled_soil",
	-- The town pond of playtest round 3, and the only water any WP13
	-- composition writes. RIVER water and not ordinary water: it is
	-- `liquid_renewable = false` with `liquid_range = 2` (default/nodes.lua),
	-- which is default's own answer to "a pool on sloping ground must not
	-- flood the bank". A pond lined on five sides cannot leak, and if a player
	-- digs the liner out, river water spreads two nodes and stops instead of
	-- running down the terrace.
	water = "default:river_water_source",
	tree_log = "default:tree",
	tree_leaves = "default:leaves",
	hedge = "default:bush_leaves",
	hedge_stem = "default:bush_stem",
	undergrowth = "default:grass_4",
	grass_tuft = "default:grass_3",
	fern = "default:fern_1",
}

-- Elf (Silverleaf Glades): a glade settlement, pale and vertical. Silver
-- sandstone footings and roofs, silverwood plank walls on silverwood posts,
-- marble paving, aspen-pale fences and candlelight. Contract section 4's elf
-- column with three corrections the registry forced:
--
--   * `grug_trees` registers no stair, slab or fence shape, so the roofs come
--     out of a stone family and the railings are `default:fence_aspen_wood`
--     -- silverwood IS default's aspen retinted
--     (mods/ITEMS/grug_trees/init.lua), so the pale fence and the pale plank
--     agree. Silverwood plank, silver sandstone and silver litter all sit
--     between luminance 187 and 202, so a settlement built only out of them
--     is invisible against its own ground, which is what the first review
--     render showed. The DOMESTIC roof is therefore darkage slate tile
--     (#6d818d), and the contract's `stairs:*_silver_sandstone_brick` family
--     stays as the composition's civic roof, where the pale cut now reads
--     against the slate instead of against the litter;
--   * the contract's `default:glass` is a cube, not a pane, and the whole
--     window vocabulary of this library (framing, rhythm, `update_pane`) is
--     the `xpanes` one, so the ordinary windows are clear flat panes in
--     silverwood frames and the glass cubes appear only as gable lights;
--   * `walls:` ships nothing pale, so the low wall is a silver sandstone
--     brick slab: a marble kerb, not a rubble parapet.
M.races.elf = {
	ground = "grug_nodes:dirt_with_silver_litter",
	ground_patch = "default:dirt_with_grass",
	ground_bare = "default:dirt",
	subsoil = "default:dirt",
	path = "grug_decor:darkage_slate_tile",
	plaza = "grug_decor:darkage_marble",
	plaza_edge = "grug_decor:darkage_serpentine",
	stepping = "grug_decor:xdecor_stonepath",
	rubble = "default:silver_sandstone",

	foundation = "grug_decor:darkage_marble_tile",
	wall = "grug_trees:silverwood_wood",
	wall_accent = "grug_decor:darkage_slate_brick",
	post = "grug_trees:silverwood_tree",
	beam = "grug_trees:silverwood_tree",
	floor = "grug_trees:silverwood_wood",
	ceiling = "grug_trees:silverwood_wood",

	roof_stair = "grug_decor:darkage_slate_tile_stair",
	roof_stair_outer = "grug_decor:darkage_slate_tile_stair_outer",
	roof_stair_inner = "grug_decor:darkage_slate_tile_stair_inner",
	roof_slab = "grug_decor:darkage_slate_tile_slab",
	roof_ridge = "grug_decor:darkage_slate_tile",

	window = "xpanes:pane_flat",
	window_frame = "grug_trees:silverwood_tree",
	door = "doors:door_wood",
	door_hidden = "doors:hidden",

	fence = "default:fence_aspen_wood",
	fence_rail = "default:fence_rail_aspen_wood",
	low_wall = "grug_decor:darkage_serpentine_slab",
	railing = "default:fence_aspen_wood",

	light_wall = "grug_decor:xdecor_candle",
	light_post = "grug_decor:xdecor_candle",
	light_indoor = "grug_decor:xdecor_candle",
	light_hanging = "grug_decor:xdecor_lantern_hanging",
	light_beacon = "grug_materials:emberglass_lamp",

	bed = "beds:bed",
	bed_fancy = "beds:fancy_bed",
	table_top = "stairs:slab_silver_sandstone",
	table_leg = "default:fence_aspen_wood",
	seat = "stairs:stair_silver_sandstone",
	-- Furnishing: static decor only, for the reason written above the dwarf
	-- palette. The bowyer's bench is xdecor's plain work top, which is
	-- geometry and not a crafting service.
	shelf = "grug_decor:xdecor_empty_shelf",
	shelf_vessels = "grug_decor:cottages_shelf",
	storage = "grug_decor:xdecor_barrel",
	workbench = "grug_decor:xdecor_workbench",
	hearth = "grug_decor:xdecor_cauldron",
	chimney = "grug_decor:darkage_slate_brick",
	chimney_cap = "grug_decor:darkage_slate_brick_slab",
	rug = "wool:white",
	rug_accent = "wool:green",

	-- Capital vocabulary: Lethariel. Marble is the elf signature of the
	-- capitals contract; the silver sandstone brick arrowslit and pillar are
	-- the pale cut stone the composition's civic roof already uses, so the
	-- colonnades agree with the halls they stand in front of. Lethariel
	-- carries no curtain wall (the user's 2026-09-14 ruling), but the roles
	-- are bound anyway: a king's hall, a gatehouse over an avenue and a
	-- watch tower are built from the same masonry.
	castle_wall = "grug_decor:castle_stonewall",
	castle_wall_stair = "grug_decor:castle_stonewall_stair",
	castle_wall_slab = "grug_decor:castle_stonewall_slab",
	castle_paving = "grug_decor:castle_pavement_brick",
	castle_rubble = "grug_decor:castle_rubble",
	castle_slit = "grug_decor:castle_arrowslit_silver_sandstone_brick",
	pillar = "grug_decor:castle_pillar_silver_sandstone_brick",
	signature = "grug_decor:darkage_marble",
	signature_stair = "grug_decor:darkage_marble_stair",
	signature_slab = "grug_decor:darkage_marble_slab",
	throne = "grug_decor:xdecor_chair",

	planter = "grug_decor:darkage_serpentine",
	planter_soil = "default:dirt_with_grass",
	flower = "grug_decor:xdecor_potted_viola",
	flower_alt = "grug_decor:xdecor_potted_dandelion_white",
	tree_log = "grug_trees:silverwood_tree",
	tree_leaves = "grug_trees:silverwood_leaves",
	undergrowth = "default:fern_2",
	grass_tuft = "default:grass_2",
	fern = "default:fern_3",
}

-- Undead (Stillgrave Hollow): blight dirt and bone litter underfoot,
-- gravewood boards on black dungeon-stone footings, obsidian-brick roofs,
-- iron bars instead of glass, steel doors, and candlelight instead of
-- hearthfire. Contract section 4's undead column with three amendments the
-- renders made: the roof family is `obsidianbrick` rather than `stonebrick`
-- (the whole hamlet wears one black roof, and the composition gives the
-- crypt-chapel pale stone WALLS instead, so the civic building is the one
-- that reads light), the wall accent is `default:mossycobble` rather than
-- `default:stonebrick` or the near-black `castle_dungeon_stone`, and the
-- ground flora is `default:dry_shrub` and
-- `grug_nodes:bone_pile` -- a blight basin has no grass.
--
-- `default:dry_shrub` is the one palette name whose param2 is not zero: its
-- definition pins `place_param2 = 4`, and `parts.place_param2` writes that.
M.races.undead = {
	ground = "grug_nodes:blight_dirt",
	ground_patch = "grug_nodes:dirt_with_bone_litter",
	ground_bare = "default:gravel",
	subsoil = "default:dirt",
	path = "default:mossycobble",
	plaza = "grug_decor:castle_pavement_brick",
	plaza_edge = "default:obsidianbrick",
	stepping = "grug_decor:xdecor_stonepath",
	rubble = "grug_decor:castle_rubble",

	foundation = "default:obsidianbrick",
	wall = "grug_trees:gravewood_wood",
	-- The one pale course in the hamlet. `castle_dungeon_stone` was here
	-- first and the render threw it out: near-black masonry under near-black
	-- boards under a black roof left every building a single silhouette. The
	-- mossy cobble plinth is what lets a wall read as a wall.
	wall_accent = "default:mossycobble",
	post = "grug_trees:gravewood_tree",
	beam = "grug_trees:gravewood_tree",
	floor = "grug_trees:gravewood_wood",
	ceiling = "grug_trees:gravewood_wood",

	roof_stair = "stairs:stair_obsidianbrick",
	roof_stair_outer = "stairs:stair_outer_obsidianbrick",
	roof_stair_inner = "stairs:stair_inner_obsidianbrick",
	roof_slab = "stairs:slab_obsidianbrick",
	roof_ridge = "default:obsidianbrick",

	-- No glass in the Hollow: every opening is barred.
	window = "xpanes:bar_flat",
	window_frame = "grug_trees:gravewood_tree",
	door = "doors:door_steel",
	door_hidden = "doors:hidden",

	fence = "default:fence_junglewood",
	fence_rail = "default:fence_rail_junglewood",
	low_wall = "walls:mossycobble",
	-- A rail, not a wall of bars. `grug_decor:darkage_iron_bars` stood here
	-- first and the review threw it out: it is a `glasslike` FULL cube, so the
	-- twelve cells meant to be a waist-high rail along the works gallery were
	-- a solid barred screen a player can neither see over nor step past.
	-- `grug_decor` registers no fence at all and no vendored fence is black,
	-- so the Hollow's railing is the Hollow's own fence: the darkest vendored
	-- timber, which this palette already names for `fence` and `fence_rail`.
	railing = "default:fence_junglewood",

	-- Sparse light: a wallmounted candle (`light_source = 12`) indoors and
	-- on the buildings, and the road lamps that the lit-route invariant
	-- needs carry a plain torch on a gravewood standard.
	light_wall = "grug_decor:xdecor_candle",
	light_post = "default:torch",
	light_indoor = "grug_decor:xdecor_candle",

	bed = "beds:bed",
	table_top = "stairs:slab_obsidianbrick",
	table_leg = "default:fence_junglewood",
	seat = "stairs:stair_obsidianbrick",
	board_table = "grug_decor:xdecor_table",
	-- Furnishing: static decor only, for the reason written above the dwarf
	-- palette. The xdecor workbench in this kit is a plain textured cube --
	-- the curated `grug_decor` copy carries no formspec and no inventory --
	-- and it is the bone-carver's bench, not a crafting service.
	shelf = "grug_decor:xdecor_empty_shelf",
	shelf_vessels = "grug_decor:cottages_shelf",
	storage = "grug_decor:xdecor_barrel",
	workbench = "grug_decor:xdecor_workbench",
	hearth = "grug_decor:xdecor_cauldron",
	chimney = "grug_decor:castle_dungeon_stone",
	chimney_cap = "stairs:slab_obsidianbrick",
	rug = "wool:dark_grey",
	rug_accent = "wool:black",

	-- Capital vocabulary: Nhal Veyr. Obsidian brick is the undead signature
	-- of the capitals contract and is already the hamlet's footing and roof,
	-- and dungeon stone -- which the hamlet's render threw out as a WALL,
	-- because near-black boards over near-black masonry left one silhouette
	-- -- is exactly right for a curtain wall that is supposed to read as a
	-- single black mass. `pillar` keeps the binding Stillgrave's gate
	-- already uses.
	castle_wall = "grug_decor:castle_dungeon_stone",
	castle_wall_stair = "grug_decor:castle_dungeon_stone_stair",
	castle_wall_slab = "grug_decor:castle_dungeon_stone_slab",
	castle_paving = "grug_decor:castle_pavement_brick",
	castle_rubble = "grug_decor:castle_rubble",
	castle_slit = "grug_decor:castle_arrowslit_obsidianbrick",
	signature = "default:obsidianbrick",
	signature_stair = "stairs:stair_obsidianbrick",
	signature_slab = "stairs:slab_obsidianbrick",
	throne = "grug_decor:xdecor_chair",

	planter = "default:obsidianbrick",
	planter_soil = "grug_nodes:blight_dirt",
	cobweb = "grug_decor:xdecor_cobweb",
	pillar = "grug_decor:castle_pillar_obsidianbrick",
	ivy = "grug_decor:xdecor_ivy",
	tree_log = "grug_trees:gravewood_tree",
	tree_leaves = "grug_trees:gravewood_leaves",
	undergrowth = "grug_nodes:bone_pile",
	grass_tuft = "default:dry_shrub",
	fern = "default:dry_shrub",
}

-- Orc (Sunscar Flats): adobe over a desert-stone base course, acacia framing,
-- a flat desert-stonebrick roof deck behind a crenellated breastwork, barred
-- slit windows instead of panes, and the straw, barrels and wagon gear of a
-- camp that moved here and stayed. Contract section 4's orc column with two
-- substitutions the licence-cleared kit made available: `darkage_adobe` is
-- the real mud brick the column only described, and `ors_block` is the
-- banded course between the footing and the adobe. The ground is the ochre
-- grass, dry dirt and desert sand of world_zones.md section 10.
M.races.orc = {
	ground = "default:dirt_with_dry_grass",
	-- The flats are all one ochre, so the wear carries the contrast: brown
	-- trodden earth and pale blown sand. Binding these to two more shades of
	-- dry grass left the whole pad reading as one flat colour; binding the
	-- bare role to `default:gravel` swung the other way and scattered grey
	-- litter across a warm landscape. Both patch materials stay warm.
	ground_patch = "default:dry_dirt",
	ground_bare = "default:desert_sand",
	ground_straw = "grug_decor:cottages_straw_ground",
	subsoil = "default:dry_dirt",
	path = "default:desert_cobble",
	plaza = "default:desert_sand",
	plaza_edge = "default:desert_stone_block",
	rubble = "default:gravel",

	foundation = "default:desert_stone_block",
	wall = "grug_decor:darkage_adobe",
	wall_infill = "grug_decor:darkage_ors_block",
	wall_accent = "default:desert_stonebrick",
	post = "default:acacia_tree",
	beam = "default:acacia_tree",
	floor = "default:acacia_wood",
	ceiling = "default:acacia_wood",

	roof_stair = "stairs:stair_desert_stonebrick",
	roof_stair_outer = "stairs:stair_outer_desert_stonebrick",
	roof_stair_inner = "stairs:stair_inner_desert_stonebrick",
	roof_slab = "stairs:slab_desert_stonebrick",
	roof_ridge = "default:desert_stonebrick",

	window = "xpanes:bar_flat",
	window_frame = "default:acacia_tree",
	door = "doors:door_wood",
	door_hidden = "doors:hidden",

	fence = "default:fence_acacia_wood",
	fence_rail = "default:fence_rail_acacia_wood",
	fence_gate = "doors:gate_acacia_wood_closed",
	low_wall = "walls:desertcobble",
	railing = "default:fence_acacia_wood",
	-- The point on a palisade stake. Acacia, like the stakes themselves: the
	-- roof family here is desert stonebrick, and a stone point balanced on a
	-- log is what the review threw out.
	stake_cap = "stairs:stair_outer_acacia_wood",

	light_wall = "default:torch_wall",
	light_post = "default:torch",
	light_indoor = "default:torch_wall",

	bed = "beds:bed",
	bed_fancy = "beds:fancy_bed",
	table_top = "stairs:slab_acacia_wood",
	table_leg = "default:fence_acacia_wood",
	seat = "stairs:stair_acacia_wood",
	bench_seat = "grug_decor:cottages_bench",
	board_table = "grug_decor:cottages_table",
	mat = "grug_decor:cottages_straw_mat",
	bale = "grug_decor:cottages_straw_bale",
	wheel = "grug_decor:cottages_wagon_wheel",
	-- The load riding on a wain's bearers. `grug_decor:cottages_wagon_load`
	-- was the obvious-looking binding and is the wrong SHAPE for this job:
	-- its nodebox runs from y = 0 to y = 0.5, the TOP half of its own node
	-- (mods/ITEMS/grug_decor/cottages.lua, `wagon_load_box`), so a load
	-- written one course above a bearer log stood half a node clear of the
	-- cart it was meant to be sitting on. That is what the user's playtest
	-- saw on all five wains, and no arrangement of full-node bearers can
	-- close it -- the node below would have to be one and a half nodes tall.
	-- A sawn-acacia slab fills the BOTTOM half of its node instead, so it
	-- rests on the bearer, and a half-height stack of boards is what a loaded
	-- flatbed looks like. Nothing rides on the load, so a bottom slab is the
	-- right shape here.
	cargo = "stairs:slab_acacia_wood",
	-- Furnishing: static decor only, for the reason written above the dwarf
	-- palette. The anvil is the armourer's bench and the cauldron the fire
	-- pit; both are geometry, and neither is a spawner node.
	shelf = "grug_decor:xdecor_empty_shelf",
	shelf_vessels = "grug_decor:cottages_shelf",
	storage = "grug_decor:xdecor_barrel",
	workbench = "grug_decor:cottages_anvil",
	hearth = "grug_decor:xdecor_cauldron",
	chimney = "default:desert_stonebrick",
	chimney_cap = "stairs:slab_desert_stonebrick",
	rug = "wool:brown",
	rug_accent = "wool:red",

	-- Capital vocabulary: Gor Drazhak. Adobe is the orc signature of the
	-- capitals contract, and it is the one signature material with NO stair
	-- or slab shape in the tree (darkage.lua's `shaped` roster), so the
	-- signature stair and slab are the Old Red Sandstone brick this palette
	-- already bands its walls with -- the banded base course of the contract
	-- section 2.4 orc line, in the shape family adobe does not have.
	castle_wall = "grug_decor:castle_stonewall",
	castle_wall_stair = "grug_decor:castle_stonewall_stair",
	castle_wall_slab = "grug_decor:castle_stonewall_slab",
	castle_paving = "grug_decor:castle_pavement_brick",
	castle_rubble = "grug_decor:castle_rubble",
	castle_slit = "grug_decor:castle_arrowslit_desert_stonebrick",
	pillar = "grug_decor:castle_pillar_desert_stonebrick",
	signature = "grug_decor:darkage_adobe",
	signature_stair = "grug_decor:darkage_ors_brick_stair",
	signature_slab = "grug_decor:darkage_ors_brick_slab",
	throne = "grug_decor:xdecor_chair",

	planter = "default:desert_stone_block",
	planter_soil = "default:dry_dirt_with_dry_grass",
	tree_log = "default:acacia_tree",
	tree_leaves = "default:acacia_leaves",
	undergrowth = "default:dry_shrub",
	grass_tuft = "default:dry_grass_3",
	fern = "default:dry_grass_5",
}

-- Troll (Kapok Cradle): a stilt village on the floor of a kapok basin.
-- Contract section 4's troll column -- mossy and basalt footings, junglewood
-- walls, jungletree posts, the `stairs:*_junglewood` roof family, open
-- windows instead of glass, junglewood fences and wooden doors -- plus the
-- kit nodes the basin asks for: `darkage_basalt_brick` platforms and wall
-- bases, `darkage_reinforced_wood` beams, `darkage_serpentine` accents,
-- `darkage_wood_bars` window bars, the `xdecor_lantern_hanging` and the
-- `xdecor_rope` that falls from the underside of every stilt deck.
--
-- The ground is rainforest litter over swamp `grug_nodes:mud`, and `path` is
-- junglewood: in a basin that floods, a settlement walks on boardwalks, not
-- on stone. That single binding is what makes the road, the lanes, the
-- building aprons and the raised walkways one continuous timber deck.
M.races.troll = {
	ground = "default:dirt_with_rainforest_litter",
	ground_patch = "grug_nodes:mud",
	ground_bare = "default:dirt",
	ground_straw = "grug_decor:cottages_straw_ground",
	subsoil = "default:dirt",
	path = "default:junglewood",
	plaza = "grug_decor:darkage_basalt_brick",
	plaza_edge = "grug_decor:darkage_serpentine",
	stepping = "grug_decor:xdecor_stonepath",
	rubble = "default:gravel",

	foundation = "grug_decor:darkage_basalt_brick",
	wall = "default:junglewood",
	wall_accent = "default:mossycobble",
	post = "default:jungletree",
	beam = "grug_decor:darkage_reinforced_wood",
	floor = "default:junglewood",
	ceiling = "default:junglewood",

	roof_stair = "stairs:stair_junglewood",
	roof_stair_outer = "stairs:stair_outer_junglewood",
	roof_stair_inner = "stairs:stair_inner_junglewood",
	roof_slab = "stairs:slab_junglewood",
	roof_ridge = "default:junglewood",

	-- Open windows: a bar node, not a pane. `parts.pane` writes it at param2
	-- 0 and `parts.resolve_panes` leaves it alone, because it carries no
	-- `group:pane` and the `xpanes` update rule does not apply to it.
	window = "grug_decor:darkage_wood_bars",
	window_frame = "default:jungletree",
	door = "doors:door_wood",
	door_hidden = "doors:hidden",

	fence = "default:fence_junglewood",
	fence_rail = "default:fence_rail_junglewood",
	low_wall = "walls:mossycobble",
	railing = "default:fence_junglewood",

	light_wall = "default:torch_wall",
	light_post = "default:torch",
	light_indoor = "default:torch_wall",
	-- The HANGING lantern, not the floor one. `grug_decor:xdecor_lantern` is
	-- in `group:attached_node = 3` and rating 3 is "always attach to floor"
	-- (reference_projects/luanti/builtin/game/falling.lua:391-399), so every
	-- one of the sixteen lanterns this village hangs under a deck would have
	-- been dropped as an item the first time anything near it updated.
	-- `xdecor_lantern_hanging` is rating 4, "always attach to ceiling", which
	-- is what a lantern under a bridge needs.
	lantern = "grug_decor:xdecor_lantern_hanging",
	rope = "grug_decor:xdecor_rope",

	bed = "beds:bed",
	bed_fancy = "beds:fancy_bed",
	table_top = "stairs:slab_junglewood",
	table_leg = "default:fence_junglewood",
	seat = "stairs:stair_junglewood",
	mat = "grug_decor:cottages_straw_mat",
	-- Furnishing: static decor only, for the reason written above the dwarf
	-- palette. The tub is the troll workbench: a fish-smoker's soaking tub,
	-- geometry and nothing else.
	shelf = "grug_decor:xdecor_empty_shelf",
	shelf_vessels = "grug_decor:cottages_shelf",
	storage = "grug_decor:xdecor_barrel",
	workbench = "grug_decor:cottages_tub",
	hearth = "grug_decor:xdecor_cauldron",
	chimney = "default:mossycobble",
	chimney_cap = "stairs:slab_mossycobble",
	-- A rug is written INTO the floor course, so it has to be a full node; a
	-- straw mat is not, and lives on the optional `mat` role instead.
	rug = "grug_decor:cottages_straw",
	rug_accent = "wool:green",

	-- Capital vocabulary: Kezamba. Basalt is the troll signature of the
	-- capitals contract, and this palette already builds its platforms and
	-- footings out of basalt brick, so the signature course is the same rock
	-- uncut. Kezamba carries no curtain wall either (stilts and water are
	-- its edge); the roles are bound for the hall, the gatehouse and the
	-- tower the same way Lethariel's are.
	castle_wall = "grug_decor:castle_stonewall",
	castle_wall_stair = "grug_decor:castle_stonewall_stair",
	castle_wall_slab = "grug_decor:castle_stonewall_slab",
	castle_paving = "grug_decor:castle_pavement_brick",
	castle_rubble = "grug_decor:castle_rubble",
	castle_slit = "grug_decor:castle_arrowslit_mossycobble",
	pillar = "grug_decor:castle_pillar_mossycobble",
	signature = "grug_decor:darkage_basalt",
	signature_stair = "grug_decor:darkage_basalt_stair",
	signature_slab = "grug_decor:darkage_basalt_slab",
	throne = "grug_decor:xdecor_chair",

	planter = "default:mossycobble",
	planter_soil = "grug_nodes:mud",
	tree_log = "default:jungletree",
	tree_leaves = "default:jungleleaves",
	undergrowth = "default:junglegrass",
	grass_tuft = "default:grass_1",
	fern = "default:fern_1",
}

local function contains(list, value)
	for index = 1, #list do
		if list[index] == value then return true end
	end
	return false
end

-- Build a validated palette handle.
--
-- `node(role)` returns the node name a role is bound to, and refuses an
-- unbound or misspelled role. It does NOT prove the result is registered:
-- the palette is a plain table of strings, and only the engine knows what
-- exists. What proves that is `tools/wp13/library_kat.lua`, which loads the
-- real registrations under a stub `core` and checks every name the blueprint
-- emits, and the engine run itself, where R7's content manifest hard-fails
-- on an unregistered Hearthpine palette name.
--
-- Three roles -- `door`, `bed` and `bed_fancy` -- are not node names but
-- family bases, and `node` refuses them outright. Their members come from
-- `variant(role, suffix)`, whose suffix must be one the family declares, so
-- `parts.door` and `parts.bed` are the only way to emit them and a typo
-- cannot reach the cell list. `names(role)` is the whole family, for callers
-- that need to recognise the emitted names again.
--
-- `overrides` rebinds individual roles on top of the race, so a composition
-- can give one building a roof of another material without a second race or
-- a second generator. An override still has to name a declared role.
function M.new(race, overrides)
	local base = M.races[race]
	if type(base) ~= "table" then
		error("wp13 palette: unknown race " .. tostring(race), 0)
	end
	local source = base
	if overrides ~= nil then
		if type(overrides) ~= "table" then
			error("wp13 palette: overrides is not a table", 0)
		end
		source = {}
		for role, name in pairs(base) do source[role] = name end
		for role, name in pairs(overrides) do
			if not contains(M.required, role) and
					not contains(M.optional, role) then
				error("wp13 palette: override role " .. tostring(role) ..
					" is not declared", 0)
			end
			source[role] = name
		end
	end
	local bound = {}
	for _, role in ipairs(M.required) do
		local name = source[role]
		if type(name) ~= "string" or name == "" then
			error("wp13 palette: role " .. role .. " is unbound for " .. race, 0)
		end
		bound[role] = name
	end
	for _, role in ipairs(M.optional) do
		local name = source[role]
		if name ~= nil and (type(name) ~= "string" or name == "") then
			error("wp13 palette: optional role " .. role .. " is not a name", 0)
		end
		bound[role] = name
	end
	for role in pairs(source) do
		if not contains(M.required, role) and not contains(M.optional, role) then
			error("wp13 palette: role " .. tostring(role) .. " is not declared", 0)
		end
	end
	local handle = {race = race}
	function handle.node(role)
		if M.prefix_roles[role] then
			error("wp13 palette: role " .. role ..
				" is a family base; use variant()", 0)
		end
		local name = bound[role]
		if name == nil then
			error("wp13 palette: role " .. tostring(role) .. " is not bound", 0)
		end
		return name
	end
	function handle.maybe(role)
		if M.prefix_roles[role] then
			error("wp13 palette: role " .. role ..
				" is a family base; use variant()", 0)
		end
		if not contains(M.required, role) and not contains(M.optional, role) then
			error("wp13 palette: role " .. tostring(role) .. " is not declared", 0)
		end
		return bound[role]
	end
	-- One member of a family role. Returns nil when an optional family is
	-- unbound, so a generator can degrade; an undeclared suffix is an error.
	function handle.variant(role, suffix)
		local suffixes = M.prefix_roles[role]
		if not suffixes then
			error("wp13 palette: role " .. tostring(role) ..
				" is not a family base", 0)
		end
		if not contains(suffixes, suffix) then
			error("wp13 palette: " .. role .. " has no variant " ..
				tostring(suffix), 0)
		end
		local base = bound[role]
		if base == nil then return nil end
		return base .. suffix
	end
	-- Every node name a family role can emit, in declaration order.
	function handle.names(role)
		local suffixes = M.prefix_roles[role]
		if not suffixes then
			error("wp13 palette: role " .. tostring(role) ..
				" is not a family base", 0)
		end
		local base = bound[role]
		if base == nil then return {} end
		local out = {}
		for index = 1, #suffixes do out[index] = base .. suffixes[index] end
		return out
	end
	return handle
end

return M
