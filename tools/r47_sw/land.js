// Round 51 lane VIEW: the land viewer's zone patches, nodes and proposal
// items (tools/r47_sw/DESIGN.md, "Round 51: the land viewer").
//
// LandGen.generate(zone, opts) returns one seeded patch of a zone as data:
//   cols[x][z] = {h, top, filler, water, layers}  the ground top at y = h;
//       a water source from h + 1 up to y = water when water is a number;
//       layers[y] a node name in place of the filler (the clay bands)
//   nodes = [{x, y, z, name, p2, item}]  everything above the ground (a
//       rooted reed sits in its bed at y = h)
//   trees = [{x, y, z, species, nodes, item, snow}]  y = the foot
//   marks = [{x, y, z, item}]  where a proposal structure stands
//   facts = {rows: {row id: count}, items: {key: count}, ...}
// opts: {seed, biome, variant: 'today' | 'proposal', on: {key: bool},
//        mult: {key: number}, size}.
// Today's patch reads the zone's rows and shares (DECORATION_ROWS, the
// surface rows and the fertile palettes, inlined by build.py as LAND_DATA)
// rather than porting the mapgen; the proposal adds the land plan's items
// (ITEMS below) on top of it. LandGen.kit(zone) and LandGen.plants(zone)
// lay out the kit and the plant row of a zone with the same builders.
/* global TreeGen, SwampPatch, TreeShapes, LAND_DATA */
(function (root) {
	'use strict';

	var G = root.TreeGen || (typeof require !== 'undefined' ? require('../r46_tree/concept/treegen.js') : null);
	var SP = root.SwampPatch || (typeof require !== 'undefined' ? require('./patch.js') : null);
	var D = root.LAND_DATA || null;
	var noise = SP.noise, noise2 = SP.noise2, mix = SP.mix;

	// A per-column chance in [0, 1) for a named use.
	function chance(x, z, salt) { return (mix(x, z, salt) % 1000003) / 1000003; }

	// ------------------------------------------------------------- nodes
	//
	// How each node is drawn, with the engine's tiles (texture strings in
	// Luanti's notation, +Y, -Y, sides; a shorter list repeats its last).
	// "new:" nodes are proposals: ARTL's art where it exists (grounds/,
	// plants/ under tools/r51_land), else a stand-in made of today's
	// textures (STANDIN marks them). "prop:" nodes are the kit's props in
	// the prop format of tools/r51_land/README.md.

	var DIRT = 'default_dirt.png';
	function cube(t) { return {draw: 'cube', tiles: [t]}; }
	function litter(top, side, under) {
		under = under || DIRT;
		return {draw: 'cube', tiles: [top, under, under + '^' + side]};
	}
	function plant(t, scale) { return {draw: 'plant', tiles: [t], scale: scale || 1}; }
	function leaves(t) { return {draw: 'leaves', tiles: [t]}; }
	var NODES = {
		'default:dirt': cube(DIRT),
		'default:dirt_with_grass': litter('default_grass.png', 'default_grass_side.png'),
		'default:dirt_with_rainforest_litter': litter('default_rainforest_litter.png', 'default_rainforest_litter_side.png'),
		'default:dirt_with_coniferous_litter': litter('default_coniferous_litter.png', 'default_coniferous_litter_side.png'),
		'default:dry_dirt_with_dry_grass': litter('default_dry_grass.png', 'default_dry_grass_side.png', 'default_dry_dirt.png'),
		'default:dry_dirt': cube('default_dry_dirt.png'),
		'default:gravel': cube('default_gravel.png'),
		'default:stone': cube('default_stone.png'),
		'default:cobble': cube('default_cobble.png'),
		'default:mossycobble': cube('default_mossycobble.png'),
		'default:stone_block': cube('default_stone_block.png'),
		'default:stonebrick': cube('default_stone_brick.png'),
		'default:silver_sandstone': cube('default_silver_sandstone.png'),
		'default:silver_sandstone_brick': cube('default_silver_sandstone_brick.png'),
		'default:silver_sandstone_block': cube('default_silver_sandstone_block.png'),
		'default:sand': cube('default_sand.png'),
		'default:snowblock': cube('default_snow.png'),
		'default:ice': cube('default_ice.png'),
		'default:cactus': {draw: 'cube', tiles: ['default_cactus_top.png', 'default_cactus_top.png', 'default_cactus_side.png']},
		'default:tree': {draw: 'log', tiles: ['default_tree_top.png', 'default_tree_top.png', 'default_tree.png']},
		'default:jungletree': {draw: 'log', tiles: ['grug_trees_jungle_bark_top.png', 'grug_trees_jungle_bark_top.png', 'grug_trees_jungle_bark.png']},
		'grug_trees:silverwood_tree': {draw: 'log', tiles: ['grug_trees_silverwood_tree_top.png', 'grug_trees_silverwood_tree_top.png', 'grug_trees_silverwood_tree.png']},
		'grug_nodes:dirt_with_canopy_litter': litter('grug_nodes_canopy_litter.png', 'grug_nodes_canopy_litter_side.png'),
		'grug_nodes:dirt_with_silver_litter': litter('grug_nodes_silver_litter.png', 'grug_nodes_silver_litter_side.png'),
		'grug_nodes:dirt_with_forest_litter': litter('grug_nodes_forest_litter.png', 'grug_nodes_forest_litter_side.png'),
		'grug_nodes:dirt_with_bone_litter': litter('grug_nodes_bone_litter.png', 'grug_nodes_bone_litter_side.png'),
		'grug_nodes:dirt_with_moss': litter('default_moss.png', 'default_moss_side.png'),
		'grug_nodes:blight_dirt': cube('grug_nodes_blight_dirt.png'),
		'grug_nodes:ash_ground': cube('default_gravel.png^[colorize:#45403e:145'),
		'grug_nodes:mesa_clay': cube('grug_nodes_mesa_clay.png'),
		'grug_nodes:mud': cube('grug_nodes_mud.png'),
		'grug_nodes:mud_dry': {draw: 'cube', tiles: ['grug_nodes_mud_dry_top.png', 'grug_nodes_mud_dry_side.png']},
		'grug_nodes:mud_mottled': {draw: 'cube', tiles: ['grug_nodes_mud_mottled_top.png', 'grug_nodes_mud_mottled_side.png']},
		'grug_nodes:mud_with_wet_grass': {draw: 'cube', tiles: ['grug_nodes_wet_grass_top.png', 'grug_nodes_mud_mottled_side.png', 'grug_nodes_wet_grass_side.png']},
		'default:water_source': {draw: 'liquid', tiles: ['default_water.png']},
		'default:junglegrass': plant('default_junglegrass.png', 1.69),
		'default:fern_1': plant('default_fern_1.png'), 'default:fern_2': plant('default_fern_2.png', 2),
		'default:fern_3': plant('default_fern_3.png', 2),
		'default:dry_shrub': plant('default_dry_shrub.png'),
		'default:papyrus': plant('default_papyrus.png'),
		'default:bush_stem': plant('default_bush_stem.png', 1.41),
		'default:acacia_bush_stem': plant('default_acacia_bush_stem.png', 1.41),
		'default:pine_bush_stem': plant('default_pine_bush_stem.png', 1.41),
		'default:bush_leaves': leaves('default_leaves_simple.png'),
		'default:acacia_bush_leaves': leaves('default_acacia_leaves_simple.png'),
		'default:pine_bush_needles': leaves('default_pine_needles.png'),
		'default:blueberry_bush_leaves_with_berries': leaves('default_blueberry_bush_leaves.png^default_blueberry_overlay.png'),
		'default:jungleleaves': leaves('default_jungleleaves.png'),
		'grug_nodes:bone_pile': plant('grug_nodes_bone_pile.png'),
		'grug_nodes:reeds': plant('grug_nodes_reeds.png'),
		'grug_nodes:cattails': plant('grug_nodes_cattails.png'),
		'grug_nodes:moss_carpet': {draw: 'carpet', tiles: ['grug_nodes_moss_carpet_top.png']},
		'grug_nodes:mud_with_reeds': {draw: 'rooted', tiles: ['grug_nodes_mud.png'], special: 'grug_nodes_reeds.png'},
		'grug_mapgen:freshwater_waterlily': {draw: 'lily', tiles: ['grug_mapgen_waterlily.png']},
		'default:snow': {draw: 'box', boxes: [[-8, -8, -8, 8, -4, 8]], tiles: ['default_snow.png']},
		'default:fence_junglewood': {draw: 'fence', tiles: ['default_fence_junglewood.png']},
		'walls:mossycobble': {draw: 'wall', tiles: ['default_mossycobble.png']},
		// proposals: ARTL's art (Round 51, pass 1)
		'new:swamp_moss': {draw: 'cube', tiles: ['grounds/swamp_moss_top_32.png', 'grug_nodes_mud.png', 'grounds/swamp_moss_side.png']},
		'new:clay_band_ochre': cube('grounds/clay_band_ochre_32.png'),
		'new:clay_band_sienna': cube('grounds/clay_band_sienna_32.png'),
		'new:clay_band_chalk': cube('grounds/clay_band_chalk_32.png'),
		'new:clay_band_umber': cube('grounds/clay_band_umber_32.png'),
		'new:liana': {draw: 'hanging', tiles: ['plants/liana_end.png'], strand: 'plants/liana_strand.png'},
		'new:flower_ruby_fan': plant('plants/flower_ruby_fan.png'),
		'new:flower_ember_star': plant('plants/flower_ember_star.png'),
		'new:flower_violet_fan': plant('plants/flower_violet_fan.png'),
		'new:flower_blush_star': plant('plants/flower_blush_star.png'),
		'new:flower_lilac_bells': plant('plants/flower_lilac_bells.png'),
		'new:flower_cream_cups': plant('plants/flower_cream_cups.png'),
		'new:jungle_bush_leaves': leaves('plants/jungle_bush_leaves.png'),
		'new:withered_bush_leaves': leaves('plants/withered_bush_leaves.png'),
		'new:lichen': {draw: 'carpet', tiles: ['plants/lichen_carpet_top.png']},
		'new:lichen_b': {draw: 'carpet', tiles: ['plants/lichen_carpet_top_b.png']},
		'new:alpine_cushion': plant('plants/alpine_cushion.png'),
		'new:alpine_windshrub': plant('plants/alpine_windshrub.png'),
		// the cairn of tree shapes (ruling 13): the tree concept's connected
		// node boxes (tools/r46_tree/concept/shapes.js) in stone
		'cairn:base': {draw: 'shape', shape: 'base', family: 'cairn', tiles: ['default_stone.png']},
		'cairn:branch': {draw: 'shape', shape: 'branch', family: 'cairn', tiles: ['default_stone.png']},
		'cairn:twig': {draw: 'shape', shape: 'twig', family: 'cairn', tiles: ['default_stone.png']},
		// gravewood's own shape pieces (grug_trees, Round 46/47) for stumps
		'grug_trees:gravewood_tree': {draw: 'log', family: 'gravewood',
			tiles: ['grug_trees_gravewood_tree_top.png', 'grug_trees_gravewood_tree_top.png', 'grug_trees_gravewood_tree.png']},
		'grug_trees:gravewood_base': {draw: 'shape', shape: 'base', family: 'gravewood', tiles: ['grug_trees_gravewood_tree.png']},
		'grug_trees:gravewood_branch': {draw: 'shape', shape: 'branch', family: 'gravewood', tiles: ['grug_trees_gravewood_tree.png']},
		'grug_trees:gravewood_twig': {draw: 'shape', shape: 'twig', family: 'gravewood', tiles: ['grug_trees_gravewood_tree.png']}
	};
	// What digging gives (the kit lists it per block, ruling 7 and round
	// plan section 3.6): default nodes drop themselves (litters, mud
	// variants and moss soil their plain ground), plants nothing.
	var DROPS = {
		'grug_nodes:mesa_clay': 'itself (mesa clay)', 'new:swamp_moss': 'grug_nodes:mud (proposed, as the mud variants)',
		'cairn:base': 'default:cobble', 'cairn:branch': 'default:cobble', 'cairn:twig': 'default:cobble',
		'grug_trees:gravewood_tree': 'itself (gravewood log)', 'grug_trees:gravewood_base': 'as today\'s gravewood shapes',
		'grug_trees:gravewood_branch': 'as today\'s gravewood shapes', 'grug_trees:gravewood_twig': 'as today\'s gravewood shapes',
		'default:dirt': 'itself (default:dirt)', 'default:gravel': 'itself (default:gravel)',
		'new:clay_band_ochre': 'grug_nodes:mesa_clay (proposed)', 'new:clay_band_sienna': 'grug_nodes:mesa_clay (proposed)',
		'new:clay_band_chalk': 'grug_nodes:mesa_clay (proposed)', 'new:clay_band_umber': 'grug_nodes:mesa_clay (proposed)',
		'default:stone': 'default:cobble', 'default:jungletree': 'itself (jungle log)',
		'grug_trees:silverwood_tree': 'itself (silverwood log)', 'walls:mossycobble': 'itself (a default wall)',
		'default:fence_junglewood': 'itself (a default fence)', 'grug_nodes:bone_pile': 'nothing'
	};
	function dropOf(name) {
		if (DROPS[name]) { return DROPS[name]; }
		var def = nodeDef(name);
		if (def && def.drop !== undefined) { return def.drop || 'nothing'; }
		if (def && (def.draw === 'plant' || def.draw === 'carpet' || def.draw === 'hanging' || def.draw === 'leaves')) {
			return 'nothing';
		}
		return 'itself (' + name + ')';
	}

	// Stand-in props in the prop format (tools/r51_land/README.md), tiles as
	// texture strings of today's textures, for a prop ARTL has not drawn
	// (none at present). A prop under tools/r51_land/props/<id>/ with the
	// same id takes its place.
	var STANDIN_PROPS = {};
	// The props ARTL delivers (build.py inlines tools/r51_land/props).
	var ART_PROPS = (D && D.props) || {};
	function propDef(id) {
		var a = ART_PROPS[id];
		if (a) { return {name: a.name, drop: a.drop, tiles: a.tiles, boxes: a.boxes, alpha: a.alpha, art: true}; }
		return STANDIN_PROPS[id] || null;
	}
	function nodeDef(name) {
		if (name.indexOf('prop:') === 0) {
			var p = propDef(name.slice(5));
			return p ? {draw: 'box', tiles: p.tiles, boxes: p.boxes, alpha: p.alpha, drop: p.drop, name: p.name, art: p.art} : null;
		}
		return NODES[name] || null;
	}

	// The tree species' wood and leaves (tree_templates.lua M.SPECIES, the
	// jungle bark override of grug_trees/shapes.lua).
	var WOODS = {
		apple: {bark: 'default_tree.png', top: 'default_tree_top.png', leaves: 'default_leaves.png', fruit: 'default_apple.png'},
		jungle: {bark: 'grug_trees_jungle_bark.png', top: 'grug_trees_jungle_bark_top.png', leaves: 'default_jungleleaves.png'},
		kapok: {bark: 'grug_trees_jungle_bark.png', top: 'grug_trees_jungle_bark_top.png', leaves: 'default_jungleleaves.png'},
		acacia: {bark: 'default_acacia_tree.png', top: 'default_acacia_tree_top.png', leaves: 'default_acacia_leaves.png'},
		pine: {bark: 'default_pine_tree.png', top: 'default_pine_tree_top.png', leaves: 'default_pine_needles.png'},
		aspen: {bark: 'default_aspen_tree.png', top: 'default_aspen_tree_top.png', leaves: 'default_aspen_leaves.png'},
		silverwood: {bark: 'grug_trees_silverwood_tree.png', top: 'grug_trees_silverwood_tree_top.png', leaves: 'grug_trees_silverwood_leaves.png'},
		gravewood: {bark: 'grug_trees_gravewood_tree.png', top: 'grug_trees_gravewood_tree_top.png', leaves: 'default_leaves.png^[colorize:#858585:210'},
		swamp: {bark: 'grug_trees_gravewood_tree.png', top: 'grug_trees_gravewood_tree_top.png', leaves: 'grug_trees_swamp_leaves.png',
			moss: 'grug_trees_swamp_hanging_moss.png'}
	};

	// --------------------------------------------------------- the zones

	var ZONES = {
		swamp: {name: 'Swamp', biomes: ['grug_swamp'],
			text: 'Round 47\'s swamp: mud, pools, reeds, swamp trees. Today\'s papyrus stands on two mud blocks (the pedestal of papyrus_on_dirt.mts).'},
		jungle: {name: 'Jungle (troll)', biomes: ['grug_deep_jungle', 'grug_jungle_fringe', 'grug_jungle_edge'],
			text: 'Jungle and kapok trees on canopy or rainforest litter with patches of mud; jungle grass, nothing else today.'},
		undead: {name: 'Undead', biomes: ['grug_bone_forest', 'grug_blight'],
			text: 'Bone litter or blight dirt, gravewood, dry shrubs and today\'s bone pile (a retinted coral sprite).'},
		dwarf: {name: 'Dwarf', biomes: ['grug_crags', 'grug_crags_snowy', 'grug_pine_hills'],
			text: 'Crags: gravel and stone outcrops, rare pine bushes. Snowy crags: snow, nothing else. Pine hills: litter, pines, ferns.'},
		orc: {name: 'Orc badlands', biomes: ['grug_badlands'],
			text: 'Mesa clay with patches of dry dirt, dry shrubs and a rare large cactus; steep mesa faces.'},
		elves: {name: 'Elves', biomes: ['grug_elf_forest', 'grug_deep_forest'],
			text: 'Elf forest: silver litter with moss soil and grass, silverwood and apple trees, bushes, grass.'},
		savanna: {name: 'Savanna', biomes: ['grug_savanna'],
			text: 'Dry grass, dry dirt and mesa clay, acacias and acacia bushes. Ruling 15: nothing needed, a reference only.'},
		beach: {name: 'Beach', biomes: ['grug_beach'],
			text: 'Sand along the water (the coast rule), shingle and rock further up; sand under the water and in a small pool.'}
	};
	var ZONE_ORDER = ['swamp', 'jungle', 'undead', 'dwarf', 'orc', 'elves', 'savanna', 'beach'];

	// Relief per biome: heights amp * noise (period), a plateau step
	// (period, threshold, rise) for the mesas. Rough, for the look only.
	var RELIEF = {
		grug_deep_jungle: {amp: 4, period: 16}, grug_jungle_fringe: {amp: 3, period: 14},
		grug_jungle_edge: {amp: 3, period: 14}, grug_bone_forest: {amp: 3, period: 14},
		grug_blight: {amp: 2, period: 16}, grug_crags: {amp: 10, period: 13},
		grug_crags_snowy: {amp: 10, period: 13}, grug_pine_hills: {amp: 6, period: 15},
		grug_badlands: {amp: 2, period: 16, plateau: [14, 610, 4], terrace: [9, 700, 3]},
		grug_elf_forest: {amp: 3, period: 16}, grug_deep_forest: {amp: 3, period: 16},
		grug_savanna: {amp: 2, period: 18}
	};

	// --------------------------------------------------------- the items
	//
	// The proposal per zone (land plan section 4), each a toggle with a
	// stable key. den: a guide density, 1 in den columns (for lianas: 1 in
	// den free leaf undersides); share: a share of the ground. tex: tile
	// overrides when on. kit: the kit's builder. pending: art not yet there.
	// standin: today's textures stand in for art still to come.
	var ITEMS = [
		{key: 'swamp.ground.calm', zones: ['swamp'], name: 'Calm 2 × 2 wet grass and wet mud, calm sides (picked, L4)',
			tex: {'grug_nodes:mud_with_wet_grass': ['swamp/wet_grass_top_calm32.png', 'swamp/mud_mottled_side_calm.png', 'swamp/wet_grass_side_calm.png'],
				'grug_nodes:mud_mottled': ['swamp/mud_mottled_top_calm32.png', 'swamp/mud_mottled_side_calm.png']}},
		{key: 'swamp.ground.mud32', zones: ['swamp'], name: 'Plain mud and dry mud, 2 × 2 (Astra, L4)',
			tex: {'grug_nodes:mud': ['swamp/mud_top_32.png'],
				'grug_nodes:mud_dry': ['swamp/mud_dry_top_32.png', 'grug_nodes_mud_dry_side.png']}},
		{key: 'swamp.moss', zones: ['swamp'], name: 'The swamp\'s own moss ground, a new node (ARTL, L5)',
			text: 'Takes the moss hummocks of today\'s moss soil.'},
		{key: 'moss.forest', zones: ['swamp', 'elves'], name: 'Muted moss soil replaces today\'s neon forest moss (Astra, L5)',
			tex: {'grug_nodes:dirt_with_moss': ['swamp/moss_soil_top_32.png', DIRT, 'swamp/moss_soil_side.png']},
			text: 'grug_nodes:dirt_with_moss: in the elf forest\'s ground mix; in the swamp only where its own moss is off.'},
		{key: 'swamp.hanging_moss', zones: ['swamp'], name: 'Hanging moss: a continuous strand above today\'s end piece (picked, L4)'},
		{key: 'swamp.papyrus', zones: ['swamp'], name: 'No papyrus pedestals in the swamp (reeds and cattails do that job, L16)'},

		{key: 'jungle.ground.canopy32', zones: ['jungle'], name: 'Canopy litter, 2 × 2 (ARTL, L6)',
			tex: {'grug_nodes:dirt_with_canopy_litter': ['grounds/canopy_litter_top_32.png', DIRT, DIRT + '^grug_nodes_canopy_litter_side.png']}},
		{key: 'jungle.liana', zones: ['jungle'], name: 'Lianas from jungle leaves (strand above an end piece)', den: 8,
			unit: 'free leaf undersides', kit: 'liana', plant: 'new:liana'},
		{key: 'jungle.flower.ruby_fan', zones: ['jungle'], name: 'Flower: ruby fan (strong)', den: 300, plant: 'new:flower_ruby_fan'},
		{key: 'jungle.flower.ember_star', zones: ['jungle'], name: 'Flower: ember star (strong)', den: 300, plant: 'new:flower_ember_star'},
		{key: 'jungle.flower.violet_fan', zones: ['jungle'], name: 'Flower: violet fan (strong)', den: 300, plant: 'new:flower_violet_fan'},
		{key: 'jungle.fern', zones: ['jungle'], name: 'Ferns on the jungle floor (today\'s ferns)', den: 25, plant: 'default:fern_2'},
		{key: 'jungle.bush', zones: ['jungle'], name: 'Large-leaved bush (jungle bush leaves)', den: 250, kit: 'jungleBush'},
		{key: 'jungle.log', zones: ['jungle'], name: 'Fallen kapok log, now and then', den: 2500, kit: 'kapokLog'},

		{key: 'undead.ground.blight32', zones: ['undead'], name: 'Blight dirt, 2 × 2 (ARTL, L6)',
			tex: {'grug_nodes:blight_dirt': ['grounds/blight_dirt_32.png']}},
		{key: 'undead.ground.bone_litter32', zones: ['undead'], name: 'Bone litter, 2 × 2 (ARTL, L6)',
			tex: {'grug_nodes:dirt_with_bone_litter': ['grounds/bone_litter_top_32.png', DIRT, DIRT + '^grug_nodes_bone_litter_side.png']}},
		{key: 'undead.graveyard', zones: ['undead'], name: 'Small wild graveyard: 2–6 crooked gravestones, fence remnants or none (varies per seed)', den: 5000,
			kit: 'graveyard'},
		{key: 'undead.ruin', zones: ['undead'], name: 'Mossy ruin remnants (two or three wall pieces)', den: 8000, kit: 'ruinUndead'},
		{key: 'undead.ruin.arch', zones: ['undead'], name: 'Ruin: a broken arch of stone brick', den: 14000, kit: 'ruinArch'},
		{key: 'undead.ruin.column', zones: ['undead'], name: 'Ruin: a column stub with a fallen drum', den: 12000, kit: 'ruinColumn'},
		{key: 'undead.ruin.corner', zones: ['undead'], name: 'Ruin: a sunken wall corner, half in the ground', den: 12000, kit: 'ruinCorner'},
		{key: 'undead.crypt', zones: ['undead'], name: 'A collapsed crypt entrance (stone brick, rubble in a sunken step)', den: 16000,
			kit: 'crypt'},
		{key: 'undead.log', zones: ['undead'], name: 'Fallen gravewood log', den: 5000, kit: 'gravewoodLog'},
		{key: 'undead.stump', zones: ['undead'], name: 'Gravewood stump (log and broken branch shapes)', den: 4000, kit: 'gravewoodStump'},
		{key: 'undead.grave_mound', zones: ['undead'], name: 'Earth grave mound (default dirt), now and then with a cross', den: 8000,
			kit: 'graveMound'},
		{key: 'undead.statue', zones: ['undead'], name: 'Weathered statue, rarely: a kneeling mourner, or its bust or base alone', den: 10000,
			kit: 'statueUndead'},
		{key: 'undead.obelisk', zones: ['undead'], name: 'Weathered obelisk, rarely (a broken tip on a stone shaft)', den: 10000, kit: 'obelisk'},
		{key: 'undead.bones', zones: ['undead'], name: 'Skeleton pieces, singly or a pair; replace the bone pile (L8, L9)', den: 2000,
			kit: 'bones'},
		{key: 'undead.town_graveyard', zones: ['undead'], name: 'The towns\' graveyards from the new gravestone blocks (kit view)',
			kit: 'townGraveyard', kitOnly: true},
		{key: 'gravestone.slab', zones: ['undead'], name: 'Gravestone block: weathered stele (L12)', piece: 'gravestone_slab', kitOnly: true},
		{key: 'gravestone.cross', zones: ['undead'], name: 'Gravestone block: cross, alone or as the crown on a stele (L12)',
			piece: 'gravestone_cross', kitOnly: true},
		{key: 'gravestone.fallen', zones: ['undead'], name: 'Gravestone block: a fallen, split stele (wild graveyards)',
			piece: 'gravestone_fallen', kitOnly: true},
		{key: 'gravestone.sunken', zones: ['undead'], name: 'Gravestone block: a sunken, leaning stele (wild graveyards)',
			piece: 'gravestone_sunken', kitOnly: true},
		{key: 'bones.skull_human', zones: ['undead', 'orc'], name: 'Bone find: skull, humanoid', piece: 'skull_human', kitOnly: true},
		{key: 'bones.skull_horned', zones: ['undead', 'orc'], name: 'Bone find: skull, horned animal', piece: 'skull_horned', kitOnly: true},
		{key: 'bones.ribcage_human', zones: ['undead', 'orc'], name: 'Bone find: ribcage, humanoid', piece: 'ribcage_human', kitOnly: true},
		{key: 'bones.spine_animal', zones: ['undead', 'orc'], name: 'Bone find: spine, small animal', piece: 'spine_animal', kitOnly: true},
		{key: 'bones.scattered', zones: ['undead', 'orc'], name: 'Bone find: scattered long bones (the bone pile\'s successor)',
			piece: 'bones_scattered', kitOnly: true},
		{key: 'bones.fragments', zones: ['undead', 'orc'], name: 'Bone find: broken jaw and splinters', piece: 'bones_fragments', kitOnly: true},

		{key: 'dwarf.boulder', zones: ['dwarf'], name: 'Boulders of 2–4 nodes, stone and mossy cobble', den: 500,
			biomes: ['grug_crags', 'grug_crags_snowy', 'grug_pine_hills'], kit: 'boulder'},
		{key: 'dwarf.lichen', zones: ['dwarf'], name: 'Lichen: small scattered patches on gravel and stone (grey crusts, ochre flecks)', den: 450,
			unit: 'columns, one patch of 2–5', biomes: ['grug_crags', 'grug_pine_hills'], plant: 'new:lichen'},
		{key: 'dwarf.alpine', zones: ['dwarf'], name: 'Small alpine plants (cushion, windshrub)', den: 40,
			biomes: ['grug_crags', 'grug_pine_hills'], plant: 'new:alpine_cushion'},
		{key: 'dwarf.cairn.blocks', zones: ['dwarf'], name: 'Cairn from cairn stone blocks (L13, variant A)', den: 4000,
			kit: 'cairnBlocks'},
		{key: 'dwarf.cairn.branches', zones: ['dwarf'], name: 'Cairn from the trees\' branch and twig shapes in stone (L13, variant B)', den: 4000,
			kit: 'cairnBranches'},
		{key: 'dwarf.ice', zones: ['dwarf'], name: 'Ice patches high up (default ice)', share: 0.1, biomes: ['grug_crags_snowy']},
		{key: 'dwarf.dead_pine', zones: ['dwarf'], name: 'Dead snow-covered pines high up', den: 400, biomes: ['grug_crags_snowy'],
			kit: 'deadPine'},

		{key: 'orc.ground.mesa32', zones: ['orc', 'savanna'], name: 'Mesa clay, 2 × 2 (ARTL, L6)',
			tex: {'grug_nodes:mesa_clay': ['grounds/mesa_clay_32.png']}},
		{key: 'orc.bones', zones: ['orc'], name: 'Skeleton pieces, humanoid and animal (L14)', den: 1500, kit: 'bones'},
		{key: 'orc.withered_bush', zones: ['orc'], name: 'Yellow withered bush (an acacia bush with withered foliage)', den: 150,
			kit: 'witheredBush'},
		{key: 'orc.clay_bands', zones: ['orc'], name: 'Coloured clay bands on steep slopes (ochre, sienna, chalk, umber)'},

		{key: 'elves.ground.silver32', zones: ['elves'], name: 'Structured silver litter, 2 × 2 (ARTL, L6)',
			tex: {'grug_nodes:dirt_with_silver_litter': ['grounds/silver_litter_top_32.png', DIRT, DIRT + '^grug_nodes_silver_litter_side.png']}},
		{key: 'elves.ruin', zones: ['elves'], name: 'Small ruin pieces', den: 6000, kit: 'ruinElves'},
		{key: 'elves.statue', zones: ['elves'], name: 'Mysterious decayed statue (veiled head, broken torso)', den: 10000, kit: 'statueElves'},
		{key: 'elves.flower.blush_star', zones: ['elves'], name: 'Flower: blush star (pastel)', den: 300, plant: 'new:flower_blush_star'},
		{key: 'elves.flower.lilac_bells', zones: ['elves'], name: 'Flower: lilac bells (pastel)', den: 300, plant: 'new:flower_lilac_bells'},
		{key: 'elves.flower.cream_cups', zones: ['elves'], name: 'Flower: cream cups (pastel)', den: 300, plant: 'new:flower_cream_cups'},
		{key: 'elves.log', zones: ['elves'], name: 'Fallen silverwood log', den: 3000, kit: 'silverLog'},

		{key: 'savanna.today', zones: ['savanna'], name: 'Savanna as it is (L15: the acacias carry it)', reference: true},

		{key: 'beach.sand32', zones: ['beach'], name: 'Sand, 2 × 2 (ARTL): on the beach and as the bed under water',
			tex: {'default:sand': ['grounds/sand_32.png']}},
		{key: 'beach.papyrus', zones: ['beach'], name: 'Papyrus as a plain stack of 2–4 on sand at the water\'s edge (L16)', den: 5,
			unit: 'sand columns at the water', kit: 'papyrus', plant: 'default:papyrus'},
		{key: 'beach.marram', zones: ['beach'], name: 'Marram tufts on dry sand away from the water', den: 9, plant: 'default:marram_grass_2'},
		{key: 'beach.driftwood', zones: ['beach'], name: 'Driftwood now and then (a log drops wood, a fork sticks)', den: 120,
			unit: 'sand columns near the water', kit: 'driftwood'},
		{key: 'beach.pebbles', zones: ['beach'], name: 'Small gravel pebble patches in the sand', share: 0.1}
	];
	var ITEM = {};
	ITEMS.forEach(function (it) { ITEM[it.key] = it; });
	// (written out: build.py inlines the textures it finds named in this file)
	NODES['default:marram_grass_1'] = plant('default_marram_grass_1.png');
	NODES['default:marram_grass_2'] = plant('default_marram_grass_2.png');
	NODES['default:marram_grass_3'] = plant('default_marram_grass_3.png');
	NODES['default:grass_1'] = plant('default_grass_1.png');
	NODES['default:grass_2'] = plant('default_grass_2.png');
	NODES['default:grass_3'] = plant('default_grass_3.png');
	NODES['default:grass_4'] = plant('default_grass_4.png');
	NODES['default:grass_5'] = plant('default_grass_5.png');
	NODES['default:dry_grass_1'] = plant('default_dry_grass_1.png');
	NODES['default:dry_grass_2'] = plant('default_dry_grass_2.png');
	NODES['default:dry_grass_3'] = plant('default_dry_grass_3.png');
	NODES['default:dry_grass_4'] = plant('default_dry_grass_4.png');
	NODES['default:dry_grass_5'] = plant('default_dry_grass_5.png');

	// ------------------------------------------------------------- world

	function World(size) {
		this.size = size;
		this.cols = [];
		this.cells = {};
		this.nodes = [];
		this.trees = [];
		this.marks = [];
		this.facts = {rows: {}, items: {}};
	}
	World.prototype.col = function (x, z) {
		return (x < 0 || z < 0 || x >= this.size || z >= this.size) ? null : this.cols[x][z];
	};
	World.prototype.free = function (x, y, z) {
		var c = this.col(x, z);
		if (!c || y <= c.h || (c.water !== null && y <= c.water)) { return false; }
		return this.cells[x + ',' + y + ',' + z] === undefined;
	};
	World.prototype.put = function (x, y, z, name, p2, item) {
		if (!this.free(x, y, z)) { return false; }
		this.cells[x + ',' + y + ',' + z] = name;
		this.nodes.push({x: x, y: y, z: z, name: name, p2: p2 || 0, item: item || ''});
		return true;
	};
	World.prototype.at = function (x, y, z) { return this.cells[x + ',' + y + ',' + z]; };
	World.prototype.count = function (item) { this.facts.items[item] = (this.facts.items[item] || 0) + 1; };
	// dry land with nothing standing on it
	World.prototype.open = function (x, z) {
		var c = this.col(x, z);
		return c !== null && c.water === null && this.free(x, c.h + 1, z);
	};
	// the columns of a w x d footprint are open and within `rise` of each other
	World.prototype.flat = function (x, z, w, d, rise) {
		var lo = 999, hi = -999;
		for (var dx = 0; dx < w; dx++) {
			for (var dz = 0; dz < d; dz++) {
				if (!this.open(x + dx, z + dz)) { return false; }
				var h = this.cols[x + dx][z + dz].h;
				lo = Math.min(lo, h); hi = Math.max(hi, h);
			}
		}
		return hi - lo <= rise;
	};
	// a tree of TreeGen with its foot on (x, z); its wood must be free, its
	// leaves are left out where the ground or something else is
	World.prototype.tree = function (x, z, species, seed, item, opts) {
		var self = this, c = this.col(x, z);
		if (!c || !this.open(x, z)) { return null; }
		var foot = c.h + 1;
		var t = G.generate(species, seed, function (tx, ty, tz) {
			var g = self.col(x + tx, z + tz);
			return g !== null && foot + ty <= g.h;
		});
		var wood = G.WOOD, keep = [];
		for (var i = 0; i < t.nodes.length; i++) {
			var n = t.nodes[i];
			var free = this.free(x + n.x, foot + n.y, z + n.z);
			if (wood[n.kind] && !free) { return null; }
			if (opts && opts.dead && (n.kind === 'leaves' || n.kind === 'fruit' || n.y > t.height * 0.6)) { continue; }
			if (free) { keep.push(n); }
		}
		keep.forEach(function (n) { self.cells[(x + n.x) + ',' + (foot + n.y) + ',' + (z + n.z)] = 'tree:' + n.kind; });
		var entry = {x: x, y: foot, z: z, species: species, seed: seed, nodes: keep, item: item || '',
			snow: !!(opts && opts.snow)};
		this.trees.push(entry);
		return entry;
	};
	// a schematic of LAND_DATA (lowest occupied slice on the first free
	// node above the ground, centred, turned by quarter turns), all or nothing
	World.prototype.schematic = function (x, z, name, rot, rng, swap, item) {
		var s = D.schematics[name], c = this.col(x, z);
		if (!s || !c) { return false; }
		var cells = [], i;
		var cx = Math.floor((s.size[0] - 1) / 2), cz = Math.floor((s.size[2] - 1) / 2);
		for (i = 0; i < s.cells.length; i++) {
			var e = s.cells[i];
			if (e.prob < 127 && G.rint(rng, 0, 126) >= e.prob) { continue; }
			var nm = (swap && swap[e.name] !== undefined) ? swap[e.name] : e.name;
			if (!nm) { continue; }
			var dx = e.x - cx, dz = e.z - cz;
			for (var r = 0; r < rot; r++) { var a = dx; dx = dz; dz = -a; }
			// a log's grain (facedir axis): y 0, z 4, x 12; a quarter turn swaps x and z
			var axis = [0, 4, 4, 12, 12, 0][Math.floor((e.param2 % 24) / 4)];
			if (rot % 2 === 1 && axis !== 0) { axis = axis === 4 ? 12 : 4; }
			cells.push([x + dx, c.h + 1 + e.y - s.base, z + dz, nm, axis]);
		}
		for (i = 0; i < cells.length; i++) { if (!this.free(cells[i][0], cells[i][1], cells[i][2])) { return false; } }
		for (i = 0; i < cells.length; i++) { this.put(cells[i][0], cells[i][1], cells[i][2], cells[i][3], cells[i][4], item); }
		return true;
	};

	// ------------------------------------------------------------ terrain

	function heightAt(biome, x, z, s) {
		var r = RELIEF[biome] || {amp: 2, period: 16};
		var h = Math.floor(r.amp * noise2(x, z, r.period, s + 1) / 1024);
		if (r.plateau && noise2(x, z, r.plateau[0], s + 5) > r.plateau[1]) { h += r.plateau[2]; }
		if (r.terrace && r.plateau && noise2(x, z, r.plateau[0], s + 5) > r.plateau[1] &&
			noise(x, z, r.terrace[0], s + 6) > r.terrace[1]) { h += r.terrace[2]; }
		return h;
	}

	// The beach: land falls to the water on the high-x side; a small pool
	// inland shows the sand as a pool bed.
	function beachHeight(x, z, s, size) {
		var shore = Math.floor(size * 0.62) + Math.floor(noise(0, z, 12, s + 3) * 7 / 1024) - 3;
		var h = Math.floor((shore - x) / 3);
		if (h > 0) { h = Math.min(4, h) + (noise(x, z, 7, s + 4) > 640 ? 1 : 0); }
		h = Math.max(h, -6);
		var px = Math.floor(size * 0.22), pz = Math.floor(size * 0.7);
		var d2 = (x - px) * (x - px) + (z - pz) * (z - pz);
		if (d2 <= 6) { h = d2 <= 2 ? -2 : -1; }
		return h;
	}

	// The patch mix of r6_content.lua (dry_row): palette 1 most, palette 2
	// below 300, palette 3 from 300 to 440, gravel and stone outcrops above
	// 780 and 880 (crags: stone above 650, gravel below 300); steep faces
	// stone (a drop of 3 or more) or gravel (2), the badlands keep clay.
	function groundTop(biome, x, z, h, steep, s, wetDist) {
		var pal = D.palettes[biome] || [D.surfaces[biome].top, D.surfaces[biome].top, D.surfaces[biome].top];
		if (biome === 'grug_beach') {
			if (h < 0 || wetDist <= 9) { return 'default:sand'; }
			return noise(x, z, 9, s + 9) < 512 ? 'default:gravel' : 'default:stone';
		}
		var detail = noise(x, z, 8, s + 7);
		var patch = Math.floor((3 * noise(x, z, 32, s + 8) + detail) / 4);
		var kind = 1;
		if (patch > 880) { kind = 4; } else if (patch > 780) { kind = 3; } else if (patch < 300) { kind = 2; } else if (patch < 440) { kind = 5; }
		if (biome === 'grug_crags' || biome === 'grug_crags_snowy') {
			if (patch > 650) { kind = 4; } else if (patch < 300) { kind = 3; }
		}
		if (biome !== 'grug_badlands' && biome !== 'grug_badlands_east') {
			if (steep >= 3) { return 'default:stone'; }
			if (steep === 2) { return 'default:gravel'; }
		}
		return [null, pal[0], pal[1], 'default:gravel', 'default:stone', pal[2]][kind];
	}

	function terrain(w, biome, s) {
		var size = w.size, x, z;
		var hs = [];
		for (x = 0; x < size; x++) {
			hs.push([]);
			for (z = 0; z < size; z++) {
				hs[x].push(biome === 'grug_beach' ? beachHeight(x, z, s, size) : heightAt(biome, x, z, s));
			}
		}
		function hAt(cx, cz) { return hs[Math.max(0, Math.min(size - 1, cx))][Math.max(0, Math.min(size - 1, cz))]; }
		// distance to water (beach)
		var wet = [];
		for (x = 0; x < size; x++) {
			wet.push([]);
			for (z = 0; z < size; z++) { wet[x].push(hs[x][z] < 0 ? 0 : 99); }
		}
		for (var pass = 1; pass < 12; pass++) {
			for (x = 0; x < size; x++) {
				for (z = 0; z < size; z++) {
					if (wet[x][z] === 99 && [[1, 0], [-1, 0], [0, 1], [0, -1]].some(function (d) {
						var a = x + d[0], b = z + d[1];
						return a >= 0 && b >= 0 && a < size && b < size && wet[a][b] === pass - 1;
					})) { wet[x][z] = pass; }
				}
			}
		}
		var surf = D.surfaces[biome];
		for (x = 0; x < size; x++) {
			w.cols.push([]);
			for (z = 0; z < size; z++) {
				var h = hs[x][z];
				var steep = Math.max(h - hAt(x + 1, z), h - hAt(x - 1, z), h - hAt(x, z + 1), h - hAt(x, z - 1), 0);
				var top = groundTop(biome, x, z, h, steep, s, wet[x][z]);
				var filler = surf.filler;
				if (top === 'default:gravel' || top === 'default:stone') { filler = top; }
				w.cols[x].push({h: h, top: top, filler: filler, depth: surf.filler_depth, water: h < 0 ? 0 : null,
					steep: steep, wet: wet[x][z], layers: null});
			}
		}
		// the snowy crags' dust: a snow layer on every snow top
		if (surf.dust === 'default:snow') {
			for (x = 0; x < size; x++) {
				for (z = 0; z < size; z++) {
					if (w.cols[x][z].top === 'default:snowblock') { w.put(x, w.cols[x][z].h + 1, z, 'default:snow'); }
				}
			}
		}
	}

	// ------------------------------------------------- today's decorations

	// The rows of a biome; a row's hosts are its own host and the biome's
	// fertile palette (r6_content.lua decoration_cover), gravel at a quarter
	// for low vegetation (settlement class 4).
	function hostDivisor(row, biome, top) {
		if (top === row.host) { return 1; }
		var pal = D.palettes[biome] || [];
		if (pal.indexOf(top) >= 0) { return 1; }
		if (row.settlement === '4' && top === 'default:gravel') { return 4; }
		return 0;
	}

	function todayRows(w, biome, seed, s) {
		var rows = D.rows.filter(function (r) { return r.biomes.indexOf(biome) >= 0; });
		var size = w.size, order = [], i, x, z;
		for (x = 0; x < size; x++) { for (z = 0; z < size; z++) { order.push([x, z]); } }
		// a seeded column order, so trees do not all grow from one corner
		order.sort(function (a, b) { return mix(a[0], a[1], s + 31) - mix(b[0], b[1], s + 31); });
		var rng = G.newRng(seed, 51);
		function place(row, x, z) {
			var c = w.col(x, z);
			if (row.rules.indexOf('surface_y_at_least_60') >= 0) { return false; }
			var div = hostDivisor(row, biome, c.top);
			if (!div || c.water !== null) { return false; }
			if (chance(x, z, s + row.salt) * div >= row.num / row.den) { return false; }
			if (row.kind === 'simple') {
				return w.put(x, c.h + 1, z, row.asset, 0, 'row:' + row.id);
			}
			if (row.asset.indexOf('treegen:') === 0) {
				return w.tree(x, z, row.asset.slice(8), seed * 1000 + x * 64 + z, 'row:' + row.id) !== null;
			}
			var swap = row.rules.indexOf('replace_mushroom_with_air') >= 0 ? {'flowers:mushroom_brown': ''} : null;
			return w.schematic(x, z, row.asset.replace('.mts', ''), G.rint(rng, 0, 3), rng, swap, 'row:' + row.id);
		}
		// templates first, then the simple rows, one decoration per column
		['template', 'simple'].forEach(function (kind) {
			for (i = 0; i < order.length; i++) {
				for (var r = 0; r < rows.length; r++) {
					if (rows[r].kind === kind && place(rows[r], order[i][0], order[i][1])) {
						w.facts.rows[rows[r].id] = (w.facts.rows[rows[r].id] || 0) + 1;
						break;
					}
				}
			}
		});
	}

	// The swamp is Round 47's patch (patch.js) in this world's terms.
	var SWAMP_TOPS = {mud: 'grug_nodes:mud', mud_light: 'grug_nodes:mud_dry', mud_mottled: 'grug_nodes:mud_mottled',
		wet_grass: 'grug_nodes:mud_with_wet_grass', dirt_with_moss: 'grug_nodes:dirt_with_moss'};
	var SWAMP_NODES = {waterlily: 'grug_mapgen:freshwater_waterlily', reeds: 'grug_nodes:reeds', cattail: 'grug_nodes:cattails',
		moss_carpet: 'grug_nodes:moss_carpet', fern_1: 'default:fern_1', fern_2: 'default:fern_2', fern_3: 'default:fern_3',
		grass_3: 'default:grass_3', grass_4: 'default:grass_4', grass_5: 'default:grass_5', junglegrass: 'default:junglegrass',
		dry_shrub: 'default:dry_shrub'};
	function swampWorld(w, seed, s, papyrus) {
		var p = SP.generatePatch(seed, w.size), x, z;
		for (x = 0; x < w.size; x++) {
			w.cols.push([]);
			for (z = 0; z < w.size; z++) {
				var c = p.cols[x][z];
				w.cols[x].push({h: c.pool ? -c.pool : c.h, top: SWAMP_TOPS[c.top], filler: 'grug_nodes:mud', depth: 2,
					water: c.pool ? 0 : null, steep: 0, wet: c.pool ? 0 : 9, layers: null});
			}
		}
		p.nodes.forEach(function (n) {
			if (n.name === 'reeds_rooted') {
				w.nodes.push({x: n.x, y: n.y, z: n.z, name: 'grug_nodes:mud_with_reeds', p2: n.p2, item: ''});
			} else if (n.name === 'waterlily') {
				w.nodes.push({x: n.x, y: n.y, z: n.z, name: SWAMP_NODES.waterlily, p2: n.p2, item: ''});
				w.cells[n.x + ',' + n.y + ',' + n.z] = SWAMP_NODES.waterlily;
			} else {
				w.put(n.x, n.y, n.z, SWAMP_NODES[n.name], 0, '');
			}
		});
		p.trees.forEach(function (t) {
			var foot = w.cols[t.x][t.z].h + 1;
			t.tree.nodes.forEach(function (n) { w.cells[(t.x + n.x) + ',' + (foot + n.y) + ',' + (t.z + n.z)] = 'tree:' + n.kind; });
			w.trees.push({x: t.x, y: foot, z: t.z, species: 'swamp', seed: t.seed, nodes: t.tree.nodes, item: ''});
		});
		w.facts.rows.swamp_tree = p.trees.length;
		// today's papyrus row (swamp_papyrus, 1/50, at the water): the
		// two-dirt pedestal of papyrus_on_dirt.mts, turned to mud
		if (papyrus) {
			var rng = G.newRng(seed, 52), n = 0;
			for (x = 0; x < w.size; x++) {
				for (z = 0; z < w.size; z++) {
					var k = p.cols[x][z];
					if (!k.pool && nearWater(w, x, z, 1) && chance(x, z, s + 41) < 1 / 50 &&
						w.schematic(x, z, 'papyrus_on_dirt', 0, rng, {'default:dirt': 'grug_nodes:mud'}, 'row:swamp_papyrus')) { n++; }
				}
			}
			w.facts.rows.swamp_papyrus = n;
		}
	}

	function nearWater(w, x, z, r) {
		for (var dx = -r; dx <= r; dx++) {
			for (var dz = -r; dz <= r; dz++) {
				var c = w.col(x + dx, z + dz);
				if (c && c.water !== null && Math.abs(dx) + Math.abs(dz) <= r) { return true; }
			}
		}
		return false;
	}

	// ------------------------------------------------------- the builders
	//
	// Each builds one structure with its corner or centre on (x, z) of a
	// world and returns whether it stood. They serve the patch (at seeded
	// spots, each spot tried once) and the kit (on a flat strip).

	function pick(rng, list) { return list[G.rint(rng, 0, list.length - 1)]; }
	function top1(w, x, z) { return w.col(x, z).h + 1; }

	var BUILD = {
		// a small plot that differs per seed: 2-6 stones in rough rows 2 or 3
		// apart, a fifth fallen and a fifth sunken, the rest a mix leaning to
		// steles or to crosses (a stele, a low cross, a stele crowned by the
		// cross; one quarter-turn per stack, turned about), and a fence
		// remnant on 0-2 sides
		graveyard: function (w, x, z, rng, item) {
			var gap = G.rint(rng, 2, 3), cols = G.rint(rng, 2, 3), rows = G.rint(rng, 1, 2);
			var wide = (cols - 1) * gap + 2, deep = (rows - 1) * gap + 2;
			if (!w.flat(x - 1, z - 1, wide + 2, deep + 2, 1)) { return false; }
			var lean = G.rint(rng, 0, 2);   // 0 steles, 1 mixed, 2 crosses
			var spots = [];
			for (var gz = 0; gz < rows; gz++) {
				for (var gx = 0; gx < cols; gx++) { spots.push([x + gx * gap + G.rint(rng, 0, 1), z + gz * gap + G.rint(rng, 0, 1)]); }
			}
			var n = Math.min(spots.length, G.rint(rng, 2, 6)), placed = 0;
			for (var i = 0; i < spots.length && placed < n; i++) {
				var sp = spots[(i * 5 + G.rint(rng, 0, spots.length - 1)) % spots.length];
				var y = top1(w, sp[0], sp[1]);
				if (!w.free(sp[0], y, sp[1])) { continue; }
				var form = G.rint(rng, 0, 9) + (lean - 1) * 3, turn = pick(rng, [0, 0, 0, 1, 3, 2]);
				var ruin = G.rint(rng, 0, 9);
				if (ruin < 2) {
					w.put(sp[0], y, sp[1], 'prop:gravestone_fallen', G.rint(rng, 0, 3), item);
				} else if (ruin < 4) {
					w.put(sp[0], y, sp[1], 'prop:gravestone_sunken', turn, item);
				} else if (form >= 7) {
					w.put(sp[0], y, sp[1], 'prop:gravestone_cross', turn, item);
				} else if (form <= 2) {
					w.put(sp[0], y, sp[1], 'prop:gravestone_slab', turn, item);
				} else {
					w.put(sp[0], y, sp[1], 'prop:gravestone_slab', turn, item);
					w.put(sp[0], y + 1, sp[1], 'prop:gravestone_cross', turn, item);
				}
				placed++;
			}
			var sides = G.rint(rng, 0, 2);
			if (sides >= 1) {
				for (var fx = x - 1; fx <= x + wide; fx++) {
					if (G.rint(rng, 0, 9) < 6) { w.put(fx, top1(w, fx, z - 1), z - 1, 'default:fence_junglewood', 0, item); }
				}
			}
			if (sides >= 2) {
				for (var fz = z; fz <= z + deep; fz++) {
					if (G.rint(rng, 0, 9) < 5) { w.put(x - 1, top1(w, x - 1, fz), fz, 'default:fence_junglewood', 0, item); }
				}
			}
			return placed > 0;
		},
		// a town graveyard as wp13/dressing.lua lays it: graves two apart,
		// a mossy cobble flagstone with a marker (a wall post, a second one
		// where (x * 29 + z * 61) % 11 is divisible by 4), plot 7 a bone pile,
		// plot 3 left open; `fresh`: the markers from the new blocks (a
		// stele, crowned by the cross where today's stands two high) and the
		// bone pile's successor
		townGraveyard: function (w, x, z, rng, item, fresh) {
			for (var gz = 0; gz < 3; gz++) {
				for (var gx = 0; gx < 4; gx++) {
					var px = x + gx * 2, pz = z + gz * 2, hash = ((px + 7) * 29 + (pz + 3) * 61) % 11;
					var c = w.col(px, pz);
					if (!c || hash === 3) { continue; }
					var y = c.h + 1;
					if (hash === 7) {
						w.put(px, y, pz, fresh ? 'prop:bones_scattered' : 'grug_nodes:bone_pile', 0, item);
						continue;
					}
					c.top = 'default:mossycobble';
					if (fresh) {
						if (hash % 4 === 0) {
							w.put(px, y, pz, 'prop:gravestone_slab', 0, item);
							w.put(px, y + 1, pz, 'prop:gravestone_cross', 0, item);
						} else {
							w.put(px, y, pz, 'prop:gravestone_slab', 0, item);
						}
					} else {
						w.put(px, y, pz, 'walls:mossycobble', 0, item);
						if (hash % 4 === 0) { w.put(px, y + 1, pz, 'walls:mossycobble', 0, item); }
					}
				}
			}
			return true;
		},
		// an L of two wall pieces falling off in height, a third piece apart,
		// a fallen block or two
		ruin: function (w, x, z, rng, item, mats) {
			if (!w.flat(x, z, 6, 6, 1)) { return false; }
			var y0 = Math.min(top1(w, x, z), top1(w, x + 5, z + 5));
			function wall(px, pz, hgt) {
				var c = w.col(px, pz), y = c.h + 1;
				for (var k = 0; k < hgt; k++) { w.put(px, y + k, pz, pick(rng, mats), 0, item); }
			}
			var la = G.rint(rng, 3, 5), lb = G.rint(rng, 2, 4);
			for (var i = 0; i < la; i++) { wall(x + i, z, Math.max(1, 3 - Math.floor(i * 3 / la) - G.rint(rng, 0, 1))); }
			for (var j = 1; j < lb; j++) { wall(x, z + j, Math.max(1, 2 - Math.floor(j * 2 / lb) + G.rint(rng, 0, 1))); }
			var ox = x + G.rint(rng, 3, 5), oz = z + G.rint(rng, 3, 5);
			wall(ox, oz, G.rint(rng, 1, 2));
			if (G.rint(rng, 0, 1)) { wall(ox + 1, oz, 1); }
			for (var f = 0; f < 2; f++) {
				var fx = x + G.rint(rng, 1, 4), fz = z + G.rint(rng, 1, 4);
				if (w.open(fx, fz)) { w.put(fx, top1(w, fx, fz), fz, pick(rng, mats), 0, item); }
			}
			return y0 > -99;
		},
		ruinUndead: function (w, x, z, rng, item) {
			return BUILD.ruin(w, x, z, rng, item, ['default:mossycobble', 'default:mossycobble', 'default:cobble', 'default:stonebrick']);
		},
		ruinElves: function (w, x, z, rng, item) {
			return BUILD.ruin(w, x, z, rng, item, ['default:silver_sandstone_brick', 'default:silver_sandstone_brick',
				'default:silver_sandstone_block', 'default:mossycobble']);
		},
		// the kneeling mourner (base, upper with the same quarter-turn) on a
		// stone block; now and then only the bust, or only the broken base
		statueUndead: function (w, x, z, rng, item) {
			if (!w.flat(x - 1, z - 1, 3, 3, 0)) { return false; }
			var y = top1(w, x, z), turn = G.rint(rng, 0, 3), form = G.rint(rng, 0, 5);
			w.put(x, y, z, 'default:stone_block', 0, item);
			if (form === 0) {
				w.put(x, y + 1, z, 'prop:statue_mourner_upper', turn, item);
			} else {
				w.put(x, y + 1, z, 'prop:statue_mourner_base', turn, item);
				if (form !== 1) { w.put(x, y + 2, z, 'prop:statue_mourner_upper', turn, item); }
			}
			w.put(x + 1, top1(w, x + 1, z), z, 'grug_nodes:moss_carpet', 0, item);
			return true;
		},
		// the broken torso on a silver sandstone plinth, the veiled head on
		// it (same quarter-turn) or, decayed, fallen beside it
		statueElves: function (w, x, z, rng, item) {
			if (!w.flat(x - 1, z - 1, 3, 3, 0)) { return false; }
			var y = top1(w, x, z), turn = G.rint(rng, 0, 3);
			w.put(x, y, z, 'default:silver_sandstone', 0, item);
			w.put(x, y + 1, z, 'prop:statue_broken_torso', turn, item);
			if (G.rint(rng, 0, 2) > 0) {
				w.put(x, y + 2, z, 'prop:statue_veiled_head', turn, item);
			} else {
				w.put(x + 1, top1(w, x + 1, z), z, 'prop:statue_veiled_head', G.rint(rng, 0, 3), item);
			}
			w.put(x - 1, top1(w, x - 1, z + 1), z + 1, 'grug_nodes:moss_carpet', 0, item);
			return true;
		},
		// a stone block plinth, a shaft of 1-2 plain stone, the broken tip
		obelisk: function (w, x, z, rng, item) {
			if (!w.flat(x - 1, z - 1, 3, 3, 0)) { return false; }
			var y = top1(w, x, z);
			w.put(x, y, z, 'default:stone_block', 0, item);
			w.put(x, y + 1, z, 'default:stone', 0, item);
			if (G.rint(rng, 0, 1)) { w.put(x, y + 2, z, 'default:stone', 0, item); y++; }
			w.put(x, y + 2, z, 'prop:obelisk_broken_tip', G.rint(rng, 0, 3), item);
			return true;
		},
		// one piece, sometimes a pair (a skull beside its ribcage or spine);
		// `pair` 'human' / 'animal' forces that pair (the kit)
		bones: function (w, x, z, rng, item, pair) {
			if (!w.open(x, z)) { return false; }
			if (!pair && G.rint(rng, 0, 3) === 0) { pair = G.rint(rng, 0, 1) ? 'human' : 'animal'; }
			if (pair && w.open(x + 1, z)) {
				var turn = G.rint(rng, 0, 3);
				w.put(x, top1(w, x, z), z, pair === 'human' ? 'prop:skull_human' : 'prop:skull_horned', turn, item);
				w.put(x + 1, top1(w, x + 1, z), z, pair === 'human' ? 'prop:ribcage_human' : 'prop:spine_animal', turn, item);
			} else {
				w.put(x, top1(w, x, z), z, pick(rng, ['prop:skull_human', 'prop:skull_horned', 'prop:ribcage_human', 'prop:spine_animal',
					'prop:bones_scattered', 'prop:bones_fragments']), G.rint(rng, 0, 3), item);
			}
			return true;
		},
		// two stone brick piers, one carrying a broken lintel (the other
		// fallen short), a block lying below
		ruinArch: function (w, x, z, rng, item) {
			if (!w.flat(x, z, 4, 2, 0)) { return false; }
			var y = top1(w, x, z), alongX = G.rint(rng, 0, 1) === 1;
			var dx = alongX ? 1 : 0, dz = alongX ? 0 : 1, high = G.rint(rng, 3, 4);
			var mat = function () { return G.rint(rng, 0, 9) < 7 ? 'default:stonebrick' : 'default:mossycobble'; };
			for (var k = 0; k < high; k++) { w.put(x, y + k, z, mat(), 0, item); }
			var other = G.rint(rng, 1, high - 1);
			for (var j = 0; j < other; j++) { w.put(x + 3 * dx, y + j, z + 3 * dz, mat(), 0, item); }
			w.put(x + dx, y + high - 1, z + dz, mat(), 0, item);
			w.put(x + 2 * dx, y, z + 2 * dz, mat(), 0, item);
			return true;
		},
		// a stone brick column 1-2 high on a stone block, a drum fallen beside
		ruinColumn: function (w, x, z, rng, item) {
			if (!w.flat(x - 1, z - 1, 3, 3, 0)) { return false; }
			var y = top1(w, x, z);
			w.put(x, y, z, 'default:stone_block', 0, item);
			w.put(x, y + 1, z, 'default:stonebrick', 0, item);
			if (G.rint(rng, 0, 1)) { w.put(x, y + 2, z, 'default:stonebrick', 0, item); }
			var side = pick(rng, [[1, 0], [-1, 0], [0, 1], [0, -1]]);
			w.put(x + side[0], top1(w, x + side[0], z + side[1]), z + side[1], 'default:stonebrick', 0, item);
			w.put(x - side[1], top1(w, x - side[1], z + side[0]), z + side[0], 'grug_nodes:moss_carpet', 0, item);
			return true;
		},
		// an L of mossy wall whose lowest course sits in the ground (the
		// ground's top turned to wall), 1-2 courses showing
		ruinCorner: function (w, x, z, rng, item) {
			if (!w.flat(x, z, 4, 4, 0)) { return false; }
			var la = G.rint(rng, 3, 4), lb = G.rint(rng, 2, 3);
			var mat = function () { return G.rint(rng, 0, 9) < 6 ? 'default:mossycobble' : 'default:stonebrick'; };
			function wall(px, pz, up) {
				var c = w.col(px, pz);
				c.top = mat();
				for (var k = 1; k <= up; k++) { w.put(px, c.h + k, pz, mat(), 0, item); }
			}
			for (var i = 0; i < la; i++) { wall(x + i, z, i === 0 ? 2 : G.rint(rng, 0, 1)); }
			for (var j = 1; j < lb; j++) { wall(x, z + j, G.rint(rng, 0, 1)); }
			return true;
		},
		// a stone brick doorway (two posts, a lintel, a broken end) over a
		// step sunk one node into the ground, choked with gravel and cobble
		crypt: function (w, x, z, rng, item) {
			if (!w.flat(x - 1, z - 1, 5, 4, 0)) { return false; }
			var y = top1(w, x, z);
			for (var k = 0; k < 2; k++) {
				w.put(x - 1, y + k, z, 'default:stonebrick', 0, item);
				w.put(x + 1, y + k, z, 'default:stonebrick', 0, item);
			}
			w.put(x - 1, y + 2, z, 'default:stonebrick', 0, item);
			w.put(x, y + 2, z, 'default:stonebrick', 0, item);
			if (G.rint(rng, 0, 1)) { w.put(x + 1, y + 2, z, 'default:stonebrick', 0, item); }
			// the sunken step in front, and behind the door the rubble
			var step = w.col(x, z - 1);
			step.h = step.h - 1;
			step.top = 'default:gravel';
			w.col(x, z).top = 'default:stonebrick';
			w.put(x, y, z, pick(rng, ['default:gravel', 'default:cobble']), 0, item);
			w.put(x, y, z + 1, 'default:cobble', 0, item);
			w.put(x - 1, y, z + 1, 'default:stonebrick', 0, item);
			w.put(x + 1, y, z + 1, 'default:stonebrick', 0, item);
			return true;
		},
		gravewoodLog: function (w, x, z, rng, item) { return BUILD.log(w, x, z, rng, item, 'grug_trees:gravewood_tree', 3, 5); },
		// a log 1-2 high, its broken top a branch (or twig) shape, a root
		// base on one side
		gravewoodStump: function (w, x, z, rng, item) {
			if (!w.flat(x - 1, z - 1, 3, 3, 0)) { return false; }
			var y = top1(w, x, z), high = G.rint(rng, 1, 2);
			for (var k = 0; k < high; k++) { w.put(x, y + k, z, 'grug_trees:gravewood_tree', 0, item); }
			w.put(x, y + high, z, G.rint(rng, 0, 1) ? 'grug_trees:gravewood_branch' : 'grug_trees:gravewood_twig', 0, item);
			var side = pick(rng, [[1, 0], [-1, 0], [0, 1], [0, -1]]);
			w.put(x + side[0], y, z + side[1], 'grug_trees:gravewood_base', 0, item);
			return true;
		},
		// two dirt nodes in a row, a low cross at the head now and then
		graveMound: function (w, x, z, rng, item) {
			var alongX = G.rint(rng, 0, 1) === 1, dx = alongX ? 1 : 0, dz = alongX ? 0 : 1;
			if (!w.flat(x, z, 1 + dx * 2, 1 + dz * 2, 0)) { return false; }
			w.put(x, top1(w, x, z), z, 'default:dirt', 0, item);
			w.put(x + dx, top1(w, x + dx, z + dz), z + dz, 'default:dirt', 0, item);
			if (G.rint(rng, 0, 1)) { w.put(x + 2 * dx, top1(w, x + 2 * dx, z + 2 * dz), z + 2 * dz, 'prop:gravestone_cross', alongX ? 1 : 0, item); }
			return true;
		},
		// 2-4 nodes: two side by side, maybe a third, maybe one on top
		boulder: function (w, x, z, rng, item) {
			if (!w.flat(x, z, 2, 2, 1)) { return false; }
			var mat = function () { return G.rint(rng, 0, 9) < 6 ? 'default:stone' : 'default:mossycobble'; };
			var dz = G.rint(rng, 0, 1);
			w.put(x, top1(w, x, z), z, mat(), 0, item);
			w.put(x + 1 - dz, top1(w, x + 1 - dz, z + dz), z + dz, mat(), 0, item);
			if (G.rint(rng, 0, 1)) { w.put(x + 1, top1(w, x + 1, z + 1), z + 1, mat(), 0, item); }
			if (G.rint(rng, 0, 2) === 0) { w.put(x, top1(w, x, z) + 1, z, mat(), 0, item); }
			return true;
		},
		cairnBlocks: function (w, x, z, rng, item) {
			if (!w.open(x, z)) { return false; }
			var y = top1(w, x, z);
			// one or two courses, then the cap (ARTL's notes)
			w.put(x, y, z, 'prop:cairn_course', G.rint(rng, 0, 3), item);
			if (G.rint(rng, 0, 1)) { w.put(x, y + 1, z, 'prop:cairn_course', G.rint(rng, 0, 3), item); y++; }
			w.put(x, y + 1, z, 'prop:cairn_cap', G.rint(rng, 0, 3), item);
			return true;
		},
		// a base on the ground, a branch, a twig on top: a rough tapering
		// column; sometimes a twig leaning on its foot
		cairnBranches: function (w, x, z, rng, item) {
			if (!w.open(x, z)) { return false; }
			var y = top1(w, x, z);
			w.put(x, y, z, 'cairn:base', 0, item);
			w.put(x, y + 1, z, 'cairn:branch', 0, item);
			if (G.rint(rng, 0, 1)) { w.put(x, y + 2, z, 'cairn:twig', 0, item); }
			if (G.rint(rng, 0, 1) && w.open(x + 1, z) && top1(w, x + 1, z) === y) { w.put(x + 1, y, z, 'cairn:twig', 0, item); }
			return true;
		},
		// a pine without needles, its top broken off at 60 % of its height
		deadPine: function (w, x, z, rng, item) {
			return w.tree(x, z, 'pine', G.rint(rng, 1, 99999), item, {dead: true, snow: true}) !== null;
		},
		// a log lying along x or z, 4-6 (kapok 5-7) long, grain along it
		log: function (w, x, z, rng, item, name, lo, hi) {
			var len = G.rint(rng, lo, hi), alongX = G.rint(rng, 0, 1) === 1;
			var dx = alongX ? 1 : 0, dz = alongX ? 0 : 1;
			var y = top1(w, x, z);
			for (var i = 0; i < len; i++) {
				var c = w.col(x + dx * i, z + dz * i);
				if (!c || !w.open(x + dx * i, z + dz * i) || c.h + 1 !== y) { return false; }
			}
			for (var j = 0; j < len; j++) { w.put(x + dx * j, y, z + dz * j, name, alongX ? 12 : 4, item); }
			if (G.rint(rng, 0, 1)) { w.put(x + dx * 2, y + 1, z + dz * 2, 'grug_nodes:moss_carpet', 0, item); }
			return true;
		},
		kapokLog: function (w, x, z, rng, item) { return BUILD.log(w, x, z, rng, item, 'default:jungletree', 5, 7); },
		silverLog: function (w, x, z, rng, item) { return BUILD.log(w, x, z, rng, item, 'grug_trees:silverwood_tree', 3, 5); },
		jungleBush: function (w, x, z, rng, item) {
			return w.schematic(x, z, 'bush', G.rint(rng, 0, 3), rng, {'default:bush_leaves': 'new:jungle_bush_leaves'}, item);
		},
		witheredBush: function (w, x, z, rng, item) {
			return w.schematic(x, z, 'acacia_bush', G.rint(rng, 0, 3), rng,
				{'default:acacia_bush_leaves': 'new:withered_bush_leaves'}, item);
		},
		// a plain stack of 2-4 on its host (the fix); `pedestal`: today's
		// papyrus_on_dirt.mts (two dirt nodes turned to mud, papyrus on top)
		papyrus: function (w, x, z, rng, item, pedestal) {
			if (!w.open(x, z)) { return false; }
			if (pedestal) { return w.schematic(x, z, 'papyrus_on_dirt', 0, rng, {'default:dirt': 'grug_nodes:mud'}, item); }
			var y = top1(w, x, z), n = G.rint(rng, 2, 4);
			for (var i = 0; i < n; i++) { if (!w.free(x, y + i, z)) { return i > 0; } }
			for (var j = 0; j < n; j++) { w.put(x, y + j, z, 'default:papyrus', 0, item); }
			return true;
		},
		// a log (drops wood), now and then the forked branch (sticks) beside it
		driftwood: function (w, x, z, rng, item) {
			if (!w.open(x, z)) { return false; }
			w.put(x, top1(w, x, z), z, 'prop:driftwood_log', G.rint(rng, 0, 3), item);
			if (G.rint(rng, 0, 2) === 0 && w.open(x + 1, z)) {
				w.put(x + 1, top1(w, x + 1, z), z, 'prop:driftwood_fork', G.rint(rng, 0, 3), item);
			}
			return true;
		},
		// a strand of n hanging from (x, y + 1, z) down to y - n + 1
		liana: function (w, x, y, z, n, item) {
			for (var i = 0; i < n; i++) {
				if (!w.free(x, y - i, z) || !w.free(x, y - i - 1, z)) { n = i; break; }
			}
			if (n < 2) { return false; }
			for (var j = 0; j < n; j++) { w.put(x, y - j, z, 'new:liana', 0, item); }
			return true;
		}
	};

	// ----------------------------------------------------- the proposal

	function isOn(opts, key) { return opts.variant === 'proposal' && opts.on[key] !== false; }
	function mult(opts, key) { return opts.mult && opts.mult[key] !== undefined ? opts.mult[key] : 1; }
	function applies(it, biome) { return !it.biomes || it.biomes.indexOf(biome) >= 0; }

	// Structures at seeded spots: the expected count (columns / den x
	// multiplier) rounded by chance, each spot tried once.
	function scatter(w, it, opts, rng, build) {
		var size = w.size, e = size * size / it.den * mult(opts, it.key);
		var n = Math.floor(e) + (G.rint(rng, 0, 999) < (e - Math.floor(e)) * 1000 ? 1 : 0);
		var tries = n * 4;
		for (var t = 0; t < tries && n > 0; t++) {
			var x = G.rint(rng, 2, size - 8), z = G.rint(rng, 2, size - 8);
			var before = w.nodes.length + w.trees.length;
			if (build(w, x, z, rng, it.key) && w.nodes.length + w.trees.length > before) {
				w.marks.push({x: x, y: w.col(x, z).h + 1, z: z, item: it.key});
				w.count(it.key);
				n--;
			}
		}
	}

	// Plants per column on the zone's ground: 1 in den x multiplier.
	function sprinkle(w, it, opts, s, salt, name, ok) {
		var p = mult(opts, it.key) / it.den;
		for (var x = 0; x < w.size; x++) {
			for (var z = 0; z < w.size; z++) {
				var c = w.cols[x][z];
				if (w.open(x, z) && ok(c, x, z) && chance(x, z, s + salt) < p) {
					var nm = typeof name === 'function' ? name(x, z) : name;
					if (w.put(x, c.h + 1, z, nm, 0, it.key)) { w.count(it.key); }
				}
			}
		}
	}

	var SOIL_LIKE = {'default:gravel': false, 'default:stone': false, 'default:sand': false, 'default:snowblock': false,
		'default:ice': false};
	function soil(c) { return SOIL_LIKE[c.top] === undefined; }
	// the lichen's texture variants, alternated
	var LICHEN = ['new:lichen', 'new:lichen_b'];

	function proposal(zone, biome, w, opts, seed, s) {
		var rng = G.newRng(seed, 53), its = ITEMS.filter(function (it) {
			return it.zones.indexOf(zone) >= 0 && !it.kitOnly && !it.reference && isOn(opts, it.key) && applies(it, biome);
		});
		var on = {};
		its.forEach(function (it) { on[it.key] = it; });
		var x, z;
		// remove what the proposal replaces
		if (on['undead.bones']) {
			delete w.facts.rows.blight_bone_pile;
			delete w.facts.rows.bone_forest_bone_pile;
			w.nodes = w.nodes.filter(function (n) {
				if (n.name !== 'grug_nodes:bone_pile') { return true; }
				delete w.cells[n.x + ',' + n.y + ',' + n.z];
				return false;
			});
		}
		// ground changes
		for (x = 0; x < w.size; x++) {
			for (z = 0; z < w.size; z++) {
				var c = w.cols[x][z];
				if (on['swamp.moss'] && c.top === 'grug_nodes:dirt_with_moss') { c.top = 'new:swamp_moss'; }
				if (on['dwarf.ice'] && c.top === 'default:snowblock' && noise2(x, z, 7, s + 61) < 1024 * on['dwarf.ice'].share * 2.6 *
					mult(opts, 'dwarf.ice')) {
					c.top = 'default:ice';
					var snow = w.at(x, c.h + 1, z);
					if (snow === 'default:snow') {
						delete w.cells[x + ',' + (c.h + 1) + ',' + z];
						w.nodes = w.nodes.filter(function (n) { return !(n.x === x && n.z === z && n.name === 'default:snow'); });
					}
				}
				if (on['beach.pebbles'] && c.top === 'default:sand' && c.water === null &&
					noise2(x, z, 5, s + 62) > 1024 * (1 - on['beach.pebbles'].share * 2.2 * mult(opts, 'beach.pebbles'))) {
					c.top = 'default:gravel';
				}
				// the strata: on a face three or more high, bands by height
				if (on['orc.clay_bands'] && c.steep >= 2) {
					c.layers = {};
					for (var y = c.h - Math.max(c.steep, 3) + 1; y <= c.h; y++) {
						var band = ((y % 7) + 7) % 7;
						var nm = ['new:clay_band_ochre', null, 'new:clay_band_sienna', 'new:clay_band_chalk', null,
							'new:clay_band_umber', 'new:clay_band_sienna'][band];
						if (nm) { c.layers[y] = nm; }
					}
					if (c.layers[c.h]) { c.top = c.layers[c.h]; }
					w.count('orc.clay_bands');
				}
			}
		}
		// structures first, then bushes, logs and plants
		var STRUCT = ['undead.graveyard', 'undead.ruin', 'undead.ruin.arch', 'undead.ruin.column', 'undead.ruin.corner', 'undead.crypt',
			'undead.statue', 'undead.obelisk', 'undead.grave_mound', 'undead.log', 'undead.stump', 'elves.ruin', 'elves.statue',
			'dwarf.cairn.blocks', 'dwarf.cairn.branches', 'dwarf.boulder', 'dwarf.dead_pine', 'jungle.log', 'elves.log',
			'undead.bones', 'orc.bones', 'jungle.bush', 'orc.withered_bush'];
		STRUCT.forEach(function (key) {
			if (on[key]) { scatter(w, on[key], opts, rng, BUILD[on[key].kit]); }
		});
		if (on['jungle.fern']) {
			sprinkle(w, on['jungle.fern'], opts, s, 71, function (px, pz) { return 'default:fern_' + (1 + mix(px, pz, s + 72) % 3); }, soil);
		}
		['jungle.flower.ruby_fan', 'jungle.flower.ember_star', 'jungle.flower.violet_fan', 'elves.flower.blush_star',
			'elves.flower.lilac_bells', 'elves.flower.cream_cups'].forEach(function (key, i) {
			if (on[key]) { sprinkle(w, on[key], opts, s, 80 + i, on[key].plant, soil); }
		});
		if (on['dwarf.alpine']) {
			sprinkle(w, on['dwarf.alpine'], opts, s, 90, function (px, pz) {
				return mix(px, pz, s + 91) % 2 ? 'new:alpine_cushion' : 'new:alpine_windshrub';
			}, function (c) { return c.top !== 'default:stone'; });
		}
		// lichen in small patches: a patch centre in 1 of den columns, 2-5
		// carpets within 2 of it, only on gravel and stone, never a carpet
		if (on['dwarf.lichen']) {
			var lp = mult(opts, 'dwarf.lichen') / on['dwarf.lichen'].den;
			var rocky = function (c) { return c.top === 'default:stone' || c.top === 'default:gravel'; };
			for (x = 0; x < w.size; x++) {
				for (z = 0; z < w.size; z++) {
					if (!rocky(w.cols[x][z]) || chance(x, z, s + 92) >= lp) { continue; }
					var many = 2 + mix(x, z, s + 93) % 4, got = 0;
					for (var t = 0; t < 12 && got < many; t++) {
						var lx = x + G.rint(rng, -2, 2), lz = z + G.rint(rng, -2, 2), lc = w.col(lx, lz);
						if (lc && rocky(lc) && w.open(lx, lz) && w.put(lx, lc.h + 1, lz, LICHEN[(lx + lz) % LICHEN.length], 0, 'dwarf.lichen')) {
							got++;
						}
					}
					if (got) { w.count('dwarf.lichen'); }
				}
			}
		}
		// the beach: papyrus right at the water, driftwood near it, marram
		// on the dry sand further up
		if (on['beach.papyrus'] || on['beach.driftwood'] || on['beach.marram']) {
			for (x = 0; x < w.size; x++) {
				for (z = 0; z < w.size; z++) {
					var b = w.cols[x][z];
					if (b.top !== 'default:sand' || !w.open(x, z)) { continue; }
					var edge = nearWater(w, x, z, 1);
					if (on['beach.papyrus'] && edge && chance(x, z, s + 93) < mult(opts, 'beach.papyrus') / on['beach.papyrus'].den) {
						if (BUILD.papyrus(w, x, z, rng, 'beach.papyrus', opts.pedestal)) { w.count('beach.papyrus'); }
					} else if (on['beach.driftwood'] && b.wet >= 1 && b.wet <= 3 &&
						chance(x, z, s + 94) < mult(opts, 'beach.driftwood') / on['beach.driftwood'].den) {
						if (BUILD.driftwood(w, x, z, rng, 'beach.driftwood')) {
							w.count('beach.driftwood');
							w.marks.push({x: x, y: b.h + 1, z: z, item: 'beach.driftwood'});
						}
					} else if (on['beach.marram'] && b.wet >= 4 &&
						chance(x, z, s + 95) < mult(opts, 'beach.marram') / on['beach.marram'].den) {
						if (w.put(x, b.h + 1, z, 'default:marram_grass_' + (1 + mix(x, z, s + 96) % 3), 0, 'beach.marram')) {
							w.count('beach.marram');
						}
					}
				}
			}
		}
		// lianas last: under jungle leaves with open air below
		if (on['jungle.liana']) {
			var p = mult(opts, 'jungle.liana') / on['jungle.liana'].den;
			w.trees.forEach(function (t) {
				if (t.species !== 'jungle' && t.species !== 'kapok') { return; }
				t.nodes.forEach(function (n) {
					var lx = t.x + n.x, ly = t.y + n.y, lz = t.z + n.z;
					if (n.kind !== 'leaves' || !w.free(lx, ly - 1, lz) || chance(lx, lz * 7 + ly, s + 97) >= p) { return; }
					var c = w.col(lx, lz);
					var room = c ? ly - 1 - (c.h + 2) : 0;
					if (room >= 2 && BUILD.liana(w, lx, ly - 1, lz, Math.min(room, 2 + mix(lx, ly, s + 98) % 5), 'jungle.liana')) {
						w.count('jungle.liana');
					}
				});
			});
		}
	}

	// ----------------------------------------------------------- generate

	function generate(zone, opts) {
		var size = opts.size || 48, seed = opts.seed || 1;
		var biome = opts.biome && ZONES[zone].biomes.indexOf(opts.biome) >= 0 ? opts.biome : ZONES[zone].biomes[0];
		var s = seed * 13 + ZONES[zone].biomes.indexOf(biome) * 101;
		var w = new World(size);
		if (zone === 'swamp') {
			swampWorld(w, seed, s, !isOn(opts, 'swamp.papyrus'));
		} else {
			terrain(w, biome, s);
			todayRows(w, biome, seed, s);
		}
		if (opts.variant === 'proposal') { proposal(zone, biome, w, opts, seed, s); }
		return {zone: zone, biome: biome, seed: seed, size: size, variant: opts.variant, cols: w.cols, nodes: w.nodes,
			trees: w.trees, marks: w.marks, facts: w.facts};
	}

	// ---------------------------------------------------------- kit, plants

	// A flat strip of the zone's ground, size x 9 (the plants: x 5).
	function strip(zone, size, depth) {
		var biome = ZONES[zone].biomes[0], w = new World(size);
		depth = Math.min(depth, size);
		var top = zone === 'beach' ? 'default:sand' : (D.palettes[biome] || [D.surfaces[biome].top])[0];
		if (zone === 'swamp') { top = 'grug_nodes:mud'; }
		for (var x = 0; x < size; x++) {
			w.cols.push([]);
			for (var z = 0; z < size; z++) {
				w.cols[x].push({h: 0, top: top, filler: D.surfaces[biome].filler, depth: 2, water: null, steep: 0, wet: 9,
					layers: null, void: Math.abs(z - Math.floor(size / 2)) > Math.floor(depth / 2)});
			}
		}
		return w;
	}

	// The kit of a zone: every structure of its items (and today's town
	// graveyard beside the new one), left to right, each with a label.
	function kit(zone, seed) {
		var list = [];
		ITEMS.forEach(function (it) {
			if (it.zones.indexOf(zone) < 0) { return; }
			if (it.piece) {
				list.push({item: it.key, label: it.name.replace(/^[^:]*: /, ''), prop: it.piece, w: 2});
			} else if (it.kit === 'townGraveyard') {
				list.push({item: it.key, label: 'town graveyard, today', build: 'townGraveyard', fresh: false, w: 8});
				list.push({item: it.key, label: 'town graveyard, new blocks', build: 'townGraveyard', fresh: true, w: 8});
			} else if (it.kit === 'papyrus') {
				list.push({item: it.key, label: 'papyrus, today (pedestal)', build: 'papyrus', fresh: true, w: 2});
				list.push({item: it.key, label: 'papyrus, the fix', build: 'papyrus', fresh: false, w: 2});
			} else if (it.kit === 'bones') {
				list.push({item: it.key, label: 'bone find, a humanoid pair', build: 'bones', fresh: 'human', w: 3});
				list.push({item: it.key, label: 'bone find, an animal pair', build: 'bones', fresh: 'animal', w: 3});
			} else if (it.kit === 'graveyard') {
				// three of them: the plot differs per seed
				for (var g = 1; g <= 3; g++) { list.push({item: it.key, label: 'wild graveyard ' + g, build: 'graveyard', w: 9}); }
			} else if (it.kit === 'driftwood') {
				list.push({item: it.key, label: 'driftwood log', prop: 'driftwood_log', w: 2});
				list.push({item: it.key, label: 'driftwood fork', prop: 'driftwood_fork', w: 2});
			} else if (it.kit && it.kit !== 'liana') {
				list.push({item: it.key, label: it.name, build: it.kit, w: {graveyard: 9, ruinUndead: 7, ruinElves: 7, kapokLog: 8,
					silverLog: 6, deadPine: 8, jungleBush: 4, witheredBush: 4, boulder: 3, bones: 3, ruinArch: 5, ruinCorner: 5,
					crypt: 5, gravewoodLog: 6, gravewoodStump: 4, graveMound: 4}[it.kit] || 3});
			}
		});
		// rows of at most ROW nodes, ROW_DEPTH apart (front to back)
		var ROW = 26, ROW_DEPTH = 9, rows = [[]], used = 0;
		list.forEach(function (e) {
			if (used + e.w + 1 > ROW && rows[rows.length - 1].length) { rows.push([]); used = 0; }
			rows[rows.length - 1].push(e);
			used += e.w + 1;
		});
		var size = Math.max(ROW + 2, rows.length * ROW_DEPTH + 2), w = strip(zone, size, size);
		var rng = G.newRng(seed, 54), labels = [], n = 0;
		rows.forEach(function (row, r) {
			var x = 2, z0 = size - 2 - (r + 1) * ROW_DEPTH;
			row.forEach(function (e) {
				var cz = z0 + 3;
				var bx = e.build === 'deadPine' ? x + 3 : x;
				if (e.prop) {
					w.put(bx, 1, cz, 'prop:' + e.prop, 0, e.item);
				} else {
					for (var tr = 0; tr < 6; tr++) {
						if (BUILD[e.build](w, bx, cz, rng, e.item, e.fresh)) { break; }
					}
				}
				n++;
				labels.push({x: x + e.w / 2 - 0.5, z: z0 + 1, text: String(n), item: e.item});
				x += e.w + 1;
			});
		});
		// the unused part of the square stays empty
		for (var vx = 0; vx < size; vx++) {
			for (var vz = 0; vz < size; vz++) {
				if (vz < size - 1 - rows.length * ROW_DEPTH) { w.cols[vx][vz].void = true; }
			}
		}
		return {zone: zone, size: size, cols: w.cols, nodes: w.nodes, trees: w.trees, marks: [], labels: labels, facts: w.facts,
			kit: true, list: list.map(function (e) { return {item: e.item, label: e.label}; }), blocks: kitBlocks(w)};
	}

	// Every distinct block of a kit with what digging it gives.
	function kitBlocks(w) {
		var seen = {}, out = [];
		w.nodes.forEach(function (n) {
			if (seen[n.item + '|' + n.name]) { return; }
			seen[n.item + '|' + n.name] = true;
			var def = nodeDef(n.name);
			out.push({item: n.item, name: n.name, label: def && def.name ? def.name : n.name, drop: dropOf(n.name),
				standin: n.name.indexOf('prop:') === 0 && !(def && def.art)});
		});
		w.trees.forEach(function (t) {
			if (!seen[t.item + '|tree']) {
				seen[t.item + '|tree'] = true;
				out.push({item: t.item, name: 'pine wood (dead pine)', label: 'pine log and shapes', drop: 'itself (pine log)', standin: false});
			}
		});
		return out;
	}

	// The gathering sources of the zone's biomes next to its new plants.
	function plants(zone) {
		var biomes = ZONES[zone].biomes, row = [];
		(D.gathering || []).forEach(function (g) {
			if (g.biomes.some(function (b) { return biomes.indexOf(b) >= 0; })) {
				row.push({name: 'gather:' + g.key, label: 'gathering: ' + g.name, tex: g.image, scale: g.scale, gather: true});
			}
		});
		ITEMS.forEach(function (it) {
			if (it.zones.indexOf(zone) >= 0 && it.plant) {
				row.push({name: it.plant, label: it.name.replace(/^Flower: /, ''), item: it.key});
				if (it.key === 'dwarf.alpine') { row.push({name: 'new:alpine_windshrub', label: 'alpine windshrub', item: it.key}); }
			}
		});
		if (zone === 'swamp') {
			row.push({name: 'grug_nodes:reeds', label: 'reeds (today)'}, {name: 'grug_nodes:cattails', label: 'cattails (today)'});
		}
		var size = Math.max(16, row.length * 3 + 2), w = strip(zone, size, 6), labels = [], mid = Math.floor(size / 2);
		row.forEach(function (e, i) {
			var x = 2 + i * 3;
			if (e.name === 'new:liana') {
				w.put(x, 4, mid, 'default:jungleleaves', 0, e.item);
				BUILD.liana(w, x, 3, mid, 3, e.item);
			} else if (e.name === 'default:papyrus') {
				for (var k = 1; k <= 3; k++) { w.put(x, k, mid, 'default:papyrus', 0, e.item); }
			} else {
				w.put(x, 1, mid, e.name, 0, e.item || '');
			}
			labels.push({x: x, z: mid - 2, text: String(i + 1), item: e.item || '', gather: !!e.gather});
		});
		return {zone: zone, size: size, cols: w.cols, nodes: w.nodes, trees: [], marks: [], labels: labels, facts: w.facts,
			plants: true, row: row};
	}

	function gatherDef(name) {
		var key = name.slice(7);
		var g = (D.gathering || []).filter(function (r) { return r.key === key; })[0];
		return g ? {draw: 'plant', tiles: [g.image], scale: g.scale || 1, name: g.name} : null;
	}

	function def(name) {
		if (name.indexOf('gather:') === 0) { return gatherDef(name); }
		return nodeDef(name);
	}

	var api = {generate: generate, kit: kit, plants: plants, ZONES: ZONES, ZONE_ORDER: ZONE_ORDER, ITEMS: ITEMS, ITEM: ITEM,
		NODES: NODES, WOODS: WOODS, STANDIN_PROPS: STANDIN_PROPS, def: def, dropOf: dropOf, propDef: propDef,
		setData: function (d) { D = d; ART_PROPS = d.props || {}; }};
	if (typeof module !== 'undefined' && module.exports) { module.exports = api; }
	root.LandGen = api;
})(typeof window !== 'undefined' ? window : this);
