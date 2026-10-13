// Round 46 lane TREE, step 2: the three.js side of the concept viewer.
//
// Builds every node exactly the way the Luanti client meshes it
// (src/client/content_mapblock.cpp): node boxes from the shape table,
// quarter pieces turned by facedir (transformNodeBox), connected arms from
// the six face neighbours, texture coordinates from each box's position in
// its node (generateCuboidTextureCoords) and tile choice and rotation from
// the facedir table (mapblock_mesh.cpp getNodeTile). Luanti's z axis points
// the other way to three.js's, so z is mirrored and the winding fixed.
/* global THREE, TreeGen, TEXTURES, TODAY */
(function () {
	'use strict';

	// ------------------------------------------------------------- shapes

	// The shapes live in shapes.js (TreeShapes): the quarter is a mesh, the
	// others are connected node boxes in sixteenths, x1 y1 z1 x2 y2 z2.
	var BOXES = TreeShapes.BOXES, CONNECTS = TreeShapes.CONNECTS;
	// Leaves declare connect_sides = {"bottom"}: a twig joins a leaf only
	// above it (nodeboxConnects checks the target's connect_sides).
	function leafJoin(side) { return state.twigLeaves && TreeShapes.LEAF_SIDES[side] === true; }
	var SIDE_DIRS = {top: [0, 1, 0], bottom: [0, -1, 0], right: [1, 0, 0], left: [-1, 0, 0],
		back: [0, 0, 1], front: [0, 0, -1]};
	var SIDE_ORDER = ['top', 'bottom', 'front', 'left', 'back', 'right'];

	// facedir 0..3 turn of a box: rotateXZBy(-90) per step, (x, z) -> (z, -x)
	function rotateBox(b, r) {
		var x1 = b[0], z1 = b[2], x2 = b[3], z2 = b[5];
		for (var i = 0; i < r % 4; i++) {
			var a = x1, c = x2;
			x1 = z1; z1 = -a; x2 = z2; z2 = -c;
		}
		return [Math.min(x1, x2), b[1], Math.min(z1, z2), Math.max(x1, x2), b[4], Math.max(z1, z2)];
	}

	// mapblock_mesh.cpp getNodeTile: [facedir][dir_i] -> tile index, rotation
	var R0 = 0, R1 = 1, R2 = 2, R3 = 3;
	var DIR_TO_TILE = [
		[[0, R0], [2, R0], [0, R0], [4, R0], [0, R0], [5, R0], [1, R0], [3, R0]],
		[[0, R0], [4, R0], [0, R3], [3, R0], [0, R0], [2, R0], [1, R1], [5, R0]],
		[[0, R0], [3, R0], [0, R2], [5, R0], [0, R0], [4, R0], [1, R2], [2, R0]],
		[[0, R0], [5, R0], [0, R1], [2, R0], [0, R0], [3, R0], [1, R3], [4, R0]],
		[[0, R0], [2, R3], [5, R0], [0, R2], [0, R0], [1, R0], [4, R2], [3, R1]],
		[[0, R0], [4, R3], [2, R0], [0, R1], [0, R0], [1, R1], [3, R2], [5, R1]],
		[[0, R0], [3, R3], [4, R0], [0, R0], [0, R0], [1, R2], [5, R2], [2, R1]],
		[[0, R0], [5, R3], [3, R0], [0, R3], [0, R0], [1, R3], [2, R2], [4, R1]],
		[[0, R0], [2, R1], [4, R2], [1, R2], [0, R0], [0, R0], [5, R0], [3, R3]],
		[[0, R0], [4, R1], [3, R2], [1, R3], [0, R0], [0, R3], [2, R0], [5, R3]],
		[[0, R0], [3, R1], [5, R2], [1, R0], [0, R0], [0, R2], [4, R0], [2, R3]],
		[[0, R0], [5, R1], [2, R2], [1, R1], [0, R0], [0, R1], [3, R0], [4, R3]],
		[[0, R0], [0, R3], [3, R3], [4, R1], [0, R0], [5, R3], [2, R3], [1, R3]],
		[[0, R0], [0, R2], [5, R3], [3, R1], [0, R0], [2, R3], [4, R3], [1, R0]],
		[[0, R0], [0, R1], [2, R3], [5, R1], [0, R0], [4, R3], [3, R3], [1, R1]],
		[[0, R0], [0, R0], [4, R3], [2, R1], [0, R0], [3, R3], [5, R3], [1, R2]],
		[[0, R0], [1, R1], [2, R1], [4, R3], [0, R0], [5, R1], [3, R1], [0, R1]],
		[[0, R0], [1, R2], [4, R1], [3, R3], [0, R0], [2, R1], [5, R1], [0, R0]],
		[[0, R0], [1, R3], [3, R1], [5, R3], [0, R0], [4, R1], [2, R1], [0, R3]],
		[[0, R0], [1, R0], [5, R1], [2, R3], [0, R0], [3, R1], [4, R1], [0, R2]],
		[[0, R0], [3, R2], [1, R2], [4, R2], [0, R0], [5, R2], [0, R2], [2, R2]],
		[[0, R0], [5, R2], [1, R3], [3, R2], [0, R0], [2, R2], [0, R1], [4, R2]],
		[[0, R0], [2, R2], [1, R0], [5, R2], [0, R0], [4, R2], [0, R0], [3, R2]],
		[[0, R0], [4, R2], [1, R1], [2, R2], [0, R0], [3, R2], [0, R3], [5, R2]]
	];
	// face order of a cuboid: top, bottom, right, left, back, front
	var FACE_DIRS = [[0, 1, 0], [0, -1, 0], [1, 0, 0], [-1, 0, 0], [0, 0, 1], [0, 0, -1]];

	function faceTiles(tiles, facedir) {
		var out = [];
		for (var f = 0; f < 6; f++) {
			var d = FACE_DIRS[f];
			var di = (d[0] + 2 * d[1] + 3 * d[2]) & 7;
			var e = DIR_TO_TILE[facedir % 24][di];
			out.push({tex: tiles[e[0]], rot: e[1]});
		}
		return out;
	}

	// ---------------------------------------------------------- textures

	var loader = new THREE.TextureLoader();
	var texCache = {};
	// Textures the page derives from repo textures as the nodes would:
	// gravewood leaves as the node registers them; the swamp tree's leaves
	// and hanging moss as stand-ins (Round 47 lane SW, placeholders).
	var DERIVED = {
		gravewood_leaves: {src: 'default_leaves', colour: 0x858585, ratio: 210},
		swamp_leaves: {src: 'default_jungleleaves', colour: 0x5d6b3a, ratio: 110},
		swamp_moss: {src: 'default_junglegrass', colour: 0x8d9a7a, ratio: 150, flipY: true}
	};
	function nearest(t) {
		t.magFilter = THREE.NearestFilter;
		t.minFilter = THREE.NearestFilter;
		t.generateMipmaps = false;
		t.wrapS = t.wrapT = THREE.RepeatWrapping;   // box faces past the node border wrap
		t.encoding = THREE.sRGBEncoding;
		return t;
	}
	function texture(name) {
		if (texCache[name]) { return texCache[name]; }
		var t;
		var der = DERIVED[name];
		if (der) {
			// a texture modifier on a repo texture: ^[transformFY, ^[colorize
			var canvas = document.createElement('canvas');
			canvas.width = 16; canvas.height = 16;
			t = nearest(new THREE.CanvasTexture(canvas));
			var img = new Image();
			img.onload = function () {
				var g = canvas.getContext('2d');
				if (der.flipY) { g.translate(0, 16); g.scale(1, -1); }
				g.drawImage(img, 0, 0);
				var d = g.getImageData(0, 0, 16, 16);
				var a = der.ratio / 255, c = der.colour;
				for (var i = 0; i < d.data.length; i += 4) {
					d.data[i] = d.data[i] * (1 - a) + (c >> 16) * a;
					d.data[i + 1] = d.data[i + 1] * (1 - a) + ((c >> 8) & 255) * a;
					d.data[i + 2] = d.data[i + 2] * (1 - a) + (c & 255) * a;
				}
				g.putImageData(d, 0, 0);
				t.needsUpdate = true;
			};
			img.src = TEXTURES[der.src];
		} else {
			t = nearest(loader.load(TEXTURES[name]));
		}
		texCache[name] = t;
		return t;
	}

	var matCache = {};
	function material(name, kind) {
		var k = name + '|' + kind;
		if (matCache[k]) { return matCache[k]; }
		var opts = {map: texture(name)};
		if (kind === 'leaves' || kind === 'fruit') {
			opts.alphaTest = 0.5;
			opts.side = kind === 'fruit' ? THREE.DoubleSide : THREE.FrontSide;
		}
		var m = new THREE.MeshLambertMaterial(opts);
		if (kind === 'leaves' || kind === 'fruit') {
			m.userData.depth = new THREE.MeshDepthMaterial({depthPacking: THREE.RGBADepthPacking,
				map: opts.map, alphaTest: 0.5});
		}
		matCache[k] = m;
		return m;
	}

	// ------------------------------------------------------------ species

	var WOODS = {
		apple: {bark: 'default_tree', top: 'default_tree_top', leaves: 'default_leaves', ground: 'default_grass'},
		jungle: {bark: 'default_jungletree', top: 'default_jungletree_top', leaves: 'default_jungleleaves', ground: 'grug_nodes_canopy_litter'},
		kapok: {bark: 'default_jungletree', top: 'default_jungletree_top', leaves: 'default_jungleleaves', ground: 'grug_nodes_canopy_litter'},
		acacia: {bark: 'default_acacia_tree', top: 'default_acacia_tree_top', leaves: 'default_acacia_leaves', ground: 'default_dry_grass'},
		pine: {bark: 'default_pine_tree', top: 'default_pine_tree_top', leaves: 'default_pine_needles', ground: 'default_coniferous_litter'},
		aspen: {bark: 'default_aspen_tree', top: 'default_aspen_tree_top', leaves: 'default_aspen_leaves', ground: 'grug_nodes_forest_litter'},
		silverwood: {bark: 'grug_trees_silverwood_tree', top: 'grug_trees_silverwood_tree_top', leaves: 'grug_trees_silverwood_leaves', ground: 'grug_nodes_silver_litter'},
		gravewood: {bark: 'grug_trees_gravewood_tree', top: 'grug_trees_gravewood_tree_top', leaves: 'gravewood_leaves', ground: 'grug_nodes_blight_dirt'},
		swamp: {bark: 'grug_trees_gravewood_tree', top: 'grug_trees_gravewood_tree_top', leaves: 'swamp_leaves', ground: 'grug_nodes_mud'}
	};

	// Jungle bark candidates found by build.py (JUNGLE_BARKS: ids whose
	// side and top textures are in TEXTURES as jungle_bark_<id>[_top]).
	function woodsOf(sp) {
		var w = WOODS[sp];
		if ((sp === 'jungle' || sp === 'kapok') && state.bark !== 'today' &&
			JUNGLE_BARKS.indexOf(state.bark) >= 0) {
			var top = TEXTURES['jungle_bark_' + state.bark + '_top'] ? 'jungle_bark_' + state.bark + '_top' : w.top;
			return {bark: 'jungle_bark_' + state.bark, top: top, leaves: w.leaves, ground: w.ground};
		}
		return w;
	}

	var CONCEPT = {
		apple: 'A short stout bole (2×2 in 40 %) opens into 3–4 scaffold limbs that climb at about 45° in upright planes and fork at the rim, up-and-in and sideways; the round crown sits on their ends, lumpy where twigs end. Apples hang under it.',
		jungle: 'A tall stem that wanders (one or two side-steps), sheds its lower limbs and carries its crown as separate clumps at the ends of long limbs, the highest on the leader.',
		kapok: 'The giant: a long clear 3×3 or 2×2 column, rooted with surface roots that taper into the ground; a 3×3 steps in to the 2×2 leader only inside the crown. At 60 % height 4–6 wide limbs leave through limb bases, rise gently and fork, a second shorter tier above, a dome joining the clumps: a broad high crown.',
		acacia: 'A short trunk forks into a wide V of thick limbs; every limb end climbs to one common level and spreads into pads that start on the twigs and merge into an umbrella.',
		pine: 'A straight stem thinning from log to branch to twig, a whorl of short twigs every 2–3 nodes; each whorl carries a needle skirt, wide below, narrow above: a layered cone.',
		aspen: 'A slender stem with a long bare bole, then a tall oval crown on short twigs that spiral up the leader (5/16 turn each); some tops bend a little.',
		silverwood: 'Tall and elegant: a long clear slender bole, then 3–5 limbs that step out 2–3 and rise parallel to the leader, each in a leaf column reaching down to where it turns upright: a flame.',
		gravewood: 'Dead: the stem bends as it climbs, 3–5 bare limbs reach out level or rising and end in two-pronged claws (a quarter hooked up, a few drooping); a few grey tufts.',
		swamp: 'Round 47 concept (tools/r47_sw): gravewood wood, low and crooked. The stem stands 1–2 up on 3–4 short stilt roots that run out 1–2 and drop into the mud; it zigzags as it climbs. 3–5 long, almost level limbs (a third drooping) end in short forks under flat sparse pads; hanging moss trails below. Leaves and moss here are tinted stand-ins.'
	};

	// ----------------------------------------------------------- meshing

	function Buckets() { this.map = {}; }
	Buckets.prototype.get = function (texName, kind) {
		var k = texName + '|' + kind;
		if (!this.map[k]) { this.map[k] = {tex: texName, kind: kind, pos: [], nor: [], uv: [], idx: []}; }
		return this.map[k];
	};

	// Luanti cuboid face corners and texture coordinates for one box (in
	// node units relative to the node centre).
	function addCuboid(buckets, kind, ox, oy, oz, b, tiles, skip) {
		var x1 = b[0] / 16, y1 = b[1] / 16, z1 = b[2] / 16, x2 = b[3] / 16, y2 = b[4] / 16, z2 = b[5] / 16;
		var tx1 = x1 + 0.5, ty1 = y1 + 0.5, tz1 = z1 + 0.5, tx2 = x2 + 0.5, ty2 = y2 + 0.5, tz2 = z2 + 0.5;
		var txc = [
			tx1, 1 - tz2, tx2, 1 - tz1,
			tx1, tz1, tx2, tz2,
			tz1, 1 - ty2, tz2, 1 - ty1,
			1 - tz2, 1 - ty2, 1 - tz1, 1 - ty1,
			1 - tx2, 1 - ty2, 1 - tx1, 1 - ty1,
			tx1, 1 - ty2, tx2, 1 - ty1
		];
		var V = [
			[[x1, y2, z2, 0, 1], [x2, y2, z2, 2, 1], [x2, y2, z1, 2, 3], [x1, y2, z1, 0, 3]],
			[[x1, y1, z1, 4, 5], [x2, y1, z1, 6, 5], [x2, y1, z2, 6, 7], [x1, y1, z2, 4, 7]],
			[[x2, y2, z1, 8, 9], [x2, y2, z2, 10, 9], [x2, y1, z2, 10, 11], [x2, y1, z1, 8, 11]],
			[[x1, y2, z2, 12, 13], [x1, y2, z1, 14, 13], [x1, y1, z1, 14, 15], [x1, y1, z2, 12, 15]],
			[[x2, y2, z2, 16, 17], [x1, y2, z2, 18, 17], [x1, y1, z2, 18, 19], [x2, y1, z2, 16, 19]],
			[[x1, y2, z1, 20, 21], [x2, y2, z1, 22, 21], [x2, y1, z1, 22, 23], [x1, y1, z1, 20, 23]]
		];
		for (var f = 0; f < 6; f++) {
			if (skip && skip[f]) { continue; }
			var tile = tiles[f];
			var bk = buckets.get(tile.tex, kind);
			var base = bk.pos.length / 3;
			var n = FACE_DIRS[f];
			var pts = [];
			for (var j = 0; j < 4; j++) {
				var v = V[f][j];
				var u = txc[v[3]], w = txc[v[4]], t;
				if (tile.rot === 1) { t = 1 - w; w = u; u = t; }
				else if (tile.rot === 2) { u = 1 - u; w = 1 - w; }
				else if (tile.rot === 3) { t = w; w = 1 - u; u = t; }
				var p = [ox + v[0], oy + v[1], -(oz + v[2])];
				pts.push(p);
				bk.pos.push(p[0], p[1], p[2]);
				bk.nor.push(n[0], n[1], -n[2]);
				bk.uv.push(u, 1 - w);
			}
			// winding: the triangle normal must point along the face normal
			var e1 = [pts[1][0] - pts[0][0], pts[1][1] - pts[0][1], pts[1][2] - pts[0][2]];
			var e2 = [pts[2][0] - pts[0][0], pts[2][1] - pts[0][1], pts[2][2] - pts[0][2]];
			var cx = e1[1] * e2[2] - e1[2] * e2[1], cy = e1[2] * e2[0] - e1[0] * e2[2], cz = e1[0] * e2[1] - e1[1] * e2[0];
			if (cx * n[0] + cy * n[1] - cz * n[2] >= 0) {
				bk.idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
			} else {
				bk.idx.push(base, base + 2, base + 1, base, base + 3, base + 2);
			}
		}
	}

	function addPlantlike(buckets, texName, ox, oy, oz) {
		var bk = buckets.get(texName, 'fruit');
		var s = 0.5;
		var quads = [[[-s, -s], [s, s]], [[-s, s], [s, -s]]];
		for (var q = 0; q < 2; q++) {
			var a = quads[q][0], b = quads[q][1];
			// a quad of width 1 turned 45 degrees: scale the diagonal
			var k = 0.7071;
			var base = bk.pos.length / 3;
			var c = [[a[0] * k, 0.5, a[1] * k, 0, 0], [b[0] * k, 0.5, b[1] * k, 1, 0],
				[b[0] * k, -0.5, b[1] * k, 1, 1], [a[0] * k, -0.5, a[1] * k, 0, 1]];
			for (var j = 0; j < 4; j++) {
				bk.pos.push(ox + c[j][0], oy + c[j][1], -(oz + c[j][2]));
				bk.nor.push(0, 1, 0);
				bk.uv.push(c[j][3], 1 - c[j][4]);
			}
			bk.idx.push(base, base + 2, base + 1, base, base + 3, base + 2);
		}
	}

	var WOODKIND = {trunk: true, quarter: true, base: true, branch: true, twig: true};

	// The quarter mesh turned by facedir like rotateMeshBy6dFacedir does for
	// 0..3 (the same turn as a node box: (x, z) -> (z, -x) per step), cached.
	var meshCache = {};
	function quarterPolys(profile, rot) {
		var k = profile + rot;
		if (meshCache[k]) { return meshCache[k]; }
		var m = TreeShapes.quarterMesh(profile);
		function turn(v) {
			var x = v[0], z = v[2];
			for (var i = 0; i < rot % 4; i++) { var a = x; x = z; z = -a; }
			return [x, v[1], z];
		}
		function conv(poly, tile) {
			return {tile: tile, verts: poly.map(function (v) { return {p: turn(v.p), n: turn(v.n), uv: v.uv}; })};
		}
		var out = m.caps.concat(m.inner).map(function (p) { return conv(p, 'top'); }).concat(m.sides.map(function (p) { return conv(p, 'bark'); }));
		meshCache[k] = out;
		return out;
	}

	// One mesh polygon (Luanti coordinates, node units) into a bucket.
	function addPoly(buckets, tex, ox, oy, oz, poly) {
		var bk = buckets.get(tex, 'wood');
		var base = bk.pos.length / 3;
		var pts = [];
		poly.verts.forEach(function (v) {
			var p = [ox + v.p[0], oy + v.p[1], -(oz + v.p[2])];
			pts.push(p);
			bk.pos.push(p[0], p[1], p[2]);
			bk.nor.push(v.n[0], v.n[1], -v.n[2]);
			bk.uv.push(v.uv[0], v.uv[1]);
		});
		var n = poly.verts[0].n;
		var e1 = [pts[1][0] - pts[0][0], pts[1][1] - pts[0][1], pts[1][2] - pts[0][2]];
		var e2 = [pts[2][0] - pts[0][0], pts[2][1] - pts[0][1], pts[2][2] - pts[0][2]];
		var cx = e1[1] * e2[2] - e1[2] * e2[1], cy = e1[2] * e2[0] - e1[0] * e2[2], cz = e1[0] * e2[1] - e1[1] * e2[0];
		var fwd = cx * n[0] + cy * n[1] - cz * n[2] >= 0;
		for (var j = 1; j + 1 < pts.length; j++) {
			if (fwd) { bk.idx.push(base, base + j, base + j + 1); } else { bk.idx.push(base, base + j + 1, base + j); }
		}
	}

	// One tree (node list) into meshes added to `group`, offset by (dx, dz)
	// in Luanti coordinates.
	function flatGround(x, y) { return y < 0; }

	// isGround(x, y, z) in the tree's coordinates (default: flat ground),
	// dy lifts the tree (its foot on a raised terrain).
	function buildTree(group, tree, woods, dx, dz, isGround, dy) {
		isGround = isGround || flatGround;
		dy = dy || 0;
		var map = {};
		var nodes = tree.nodes;
		var i;
		for (i = 0; i < nodes.length; i++) {
			var n = nodes[i];
			map[n.x + ',' + n.y + ',' + n.z] = n;
		}
		function at(x, y, z) { return map[x + ',' + y + ',' + z]; }
		var buckets = new Buckets();
		var woodTiles = [woods.top, woods.top, woods.bark, woods.bark, woods.bark, woods.bark];
		var barkTiles = [woods.bark, woods.bark, woods.bark, woods.bark, woods.bark, woods.bark];
		var leafTiles = faceTiles([woods.leaves, woods.leaves, woods.leaves, woods.leaves, woods.leaves, woods.leaves], 0);
		for (i = 0; i < nodes.length; i++) {
			var nd = nodes[i];
			var ox = nd.x + dx, oy = nd.y + 0.5 + dy, oz = nd.z + dz;
			if (nd.kind === 'trunk') {
				// a full cube: faces against another full cube are culled
				var skip = [];
				for (var f = 0; f < 6; f++) {
					var d = FACE_DIRS[f];
					var nb = at(nd.x + d[0], nd.y + d[1], nd.z + d[2]);
					skip.push(nb !== undefined && nb.kind === 'trunk');
				}
				addCuboid(buckets, 'wood', ox, oy, oz, [-8, -8, -8, 8, 8, 8], faceTiles(woodTiles, nd.rot), skip);
			} else if (nd.kind === 'quarter') {
				// a mesh node: tiles {top, bark}, no face culling either way
				quarterPolys(state.profile, nd.rot).forEach(function (poly) {
					addPoly(buckets, poly.tile === 'top' ? woods.top : woods.bark, ox, oy, oz, poly);
				});
			} else if (BOXES[nd.kind]) {
				var shape = BOXES[nd.kind], joins = CONNECTS[nd.kind];
				var bt = faceTiles(barkTiles, nd.rot);
				addCuboid(buckets, 'wood', ox, oy, oz, shape.core, bt, null);
				for (var s = 0; s < SIDE_ORDER.length; s++) {
					var side = SIDE_ORDER[s], sd = SIDE_DIRS[side];
					var nb2 = at(nd.x + sd[0], nd.y + sd[1], nd.z + sd[2]);
					var join = nb2 !== undefined ? (joins[nb2.kind] && !(nb2.kind === 'leaves' && !leafJoin(side))) :
						(TreeShapes.GROUND_KINDS[nd.kind] === true && TreeShapes.GROUND_SIDES[side] === true &&
							isGround(nd.x + sd[0], nd.y + sd[1], nd.z + sd[2]));
					if (join) {
						addCuboid(buckets, 'wood', ox, oy, oz, shape[side], bt, null);
					}
				}
			} else if (nd.kind === 'leaves') {
				addCuboid(buckets, 'leaves', ox, oy, oz, [-8, -8, -8, 8, 8, 8], leafTiles, null);
			} else if (nd.kind === 'fruit') {
				addPlantlike(buckets, 'default_apple', ox, oy, oz);
			} else if (nd.kind === 'moss') {
				addPlantlike(buckets, 'swamp_moss', ox, oy, oz);
			}
		}
		var meshes = {wood: [], leaves: []};
		Object.keys(buckets.map).forEach(function (k) {
			var bk = buckets.map[k];
			var g = new THREE.BufferGeometry();
			g.setAttribute('position', new THREE.Float32BufferAttribute(bk.pos, 3));
			g.setAttribute('normal', new THREE.Float32BufferAttribute(bk.nor, 3));
			g.setAttribute('uv', new THREE.Float32BufferAttribute(bk.uv, 2));
			g.setIndex(bk.idx);
			var m = material(bk.tex, bk.kind);
			var mesh = new THREE.Mesh(g, m);
			mesh.castShadow = true;
			mesh.receiveShadow = true;
			if (m.userData.depth) { mesh.customDepthMaterial = m.userData.depth; }
			group.add(mesh);
			(bk.kind === 'wood' ? meshes.wood : meshes.leaves).push(mesh);
		});
		return meshes;
	}

	// Approximate quads the client draws: leaves 6 each (fancy leaves draw
	// all faces), a log cube's faces against other logs culled, node box
	// faces lying on the node border culled against a log cube.
	function quads(tree) {
		var map = {};
		tree.nodes.forEach(function (n) { map[n.x + ',' + n.y + ',' + n.z] = n; });
		function at(x, y, z) { return map[x + ',' + y + ',' + z]; }
		var total = 0;
		tree.nodes.forEach(function (n) {
			if (n.kind === 'leaves') { total += 6; return; }
			if (n.kind === 'fruit' || n.kind === 'moss') { total += 4; return; }
			var boxes = [];
			if (n.kind === 'trunk') {
				boxes = [[-8, -8, -8, 8, 8, 8]];
			} else if (n.kind === 'quarter') {
				// mesh: side and axis-side quads plus cap triangles (two per quad)
				var qm = TreeShapes.quarterMesh(state.profile);
				total += qm.sides.length + qm.inner.length + qm.caps.length / 2;
				return;
			} else {
				var sh = BOXES[n.kind], joins = CONNECTS[n.kind];
				boxes = [sh.core];
				SIDE_ORDER.forEach(function (side) {
					var sd = SIDE_DIRS[side], nb = at(n.x + sd[0], n.y + sd[1], n.z + sd[2]);
					if (nb && joins[nb.kind] && !(nb.kind === 'leaves' && !leafJoin(side))) { boxes.push(sh[side]); }
					if (!nb && TreeShapes.GROUND_KINDS[n.kind] && side === 'bottom' && n.y === 0) { boxes.push(sh[side]); }
				});
			}
			boxes.forEach(function (b) {
				var lim = [b[3], b[0], b[4], b[1], b[5], b[2]];
				var dirs = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
				for (var f = 0; f < 6; f++) {
					var onBorder = Math.abs(lim[f]) === 8;
					var nb = at(n.x + dirs[f][0], n.y + dirs[f][1], n.z + dirs[f][2]);
					if (!(onBorder && nb && nb.kind === 'trunk')) { total += 1; }
				}
			});
		});
		return total;
	}

	// ------------------------------------------------------------- figure

	// A 2-node player for scale, skinned with the repo's character.png
	// (64 x 32: the classic layout).
	function playerFigure() {
		var group = new THREE.Group();
		var tex = texture('character');
		var mat = new THREE.MeshLambertMaterial({map: tex, alphaTest: 0.5});
		function part(w, h, d, u, v, x, y) {
			// u, v: top-left of the part's net in the skin; faces as in the
			// classic layout: right, front, left, back in a row, top and
			// bottom above
			var g = new THREE.BoxGeometry(w / 16, h / 16, d / 16);
			var rects = {
				px: [u, v + d, d, h], nx: [u + d + w, v + d, d, h],
				py: [u + d, v, w, d], ny: [u + d + w, v, w, d],
				pz: [u + d, v + d, w, h], nz: [u + d + w + d, v + d, w, h]
			};
			var order = ['nx', 'px', 'py', 'ny', 'pz', 'nz'];
			var uv = g.attributes.uv;
			for (var f = 0; f < 6; f++) {
				var r = rects[order[f]];
				var u0 = r[0] / 64, u1 = (r[0] + r[2]) / 64, v0 = 1 - r[1] / 32, v1 = 1 - (r[1] + r[3]) / 32;
				uv.setXY(f * 4 + 0, u0, v0);
				uv.setXY(f * 4 + 1, u1, v0);
				uv.setXY(f * 4 + 2, u0, v1);
				uv.setXY(f * 4 + 3, u1, v1);
			}
			var m = new THREE.Mesh(g, mat);
			m.position.set(x / 16, y / 16, 0);
			m.castShadow = true;
			group.add(m);
		}
		part(8, 8, 8, 0, 0, 0, 28);      // head
		part(8, 12, 4, 16, 16, 0, 18);   // body
		part(4, 12, 4, 40, 16, -6, 18);  // arms
		part(4, 12, 4, 40, 16, 6, 18);
		part(4, 12, 4, 0, 16, -2, 6);    // legs
		part(4, 12, 4, 0, 16, 2, 6);
		return group;
	}

	// ------------------------------------------------------------- scene

	var view = document.getElementById('view');
	var renderer = new THREE.WebGLRenderer({antialias: true, preserveDrawingBuffer: true});
	renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
	renderer.shadowMap.enabled = true;
	renderer.shadowMap.type = THREE.PCFSoftShadowMap;
	renderer.outputEncoding = THREE.sRGBEncoding;
	view.appendChild(renderer.domElement);

	var scene = new THREE.Scene();
	scene.background = new THREE.Color(0x9cc8ef);
	scene.fog = new THREE.Fog(0x9cc8ef, 90, 220);
	var camera = new THREE.PerspectiveCamera(45, 1, 0.1, 600);
	var controls = new THREE.OrbitControls(camera, renderer.domElement);
	controls.enableDamping = true;
	controls.maxPolarAngle = Math.PI * 0.495;

	scene.add(new THREE.HemisphereLight(0xe8f2ff, 0x7a6a48, 0.85));
	var sun = new THREE.DirectionalLight(0xfff4e0, 1.05);
	sun.castShadow = true;
	sun.shadow.mapSize.set(4096, 4096);
	sun.shadow.bias = -0.0004;
	sun.shadow.normalBias = 0.02;
	sun.shadow.radius = 3;
	scene.add(sun);
	scene.add(sun.target);

	var groundTex = {};
	var ground = new THREE.Mesh(new THREE.PlaneGeometry(240, 240), new THREE.MeshLambertMaterial());
	ground.rotation.x = -Math.PI / 2;
	ground.receiveShadow = true;
	scene.add(ground);
	function setGround(name) {
		if (!groundTex[name]) {
			var t = nearest(loader.load(TEXTURES[name]));
			t.wrapS = t.wrapT = THREE.RepeatWrapping;
			t.repeat.set(240, 240);
			t.offset.set(0.5, 0.5);
			groundTex[name] = t;
		}
		ground.material.map = groundTex[name];
		ground.material.needsUpdate = true;
	}

	var grid = new THREE.Group();
	scene.add(grid);

	var content = new THREE.Group();
	scene.add(content);
	var leafMeshes = [];

	// ------------------------------------------------------------ state

	var params = new URLSearchParams(location.search);
	var state = {
		species: params.get('species') || 'apple',
		mode: params.get('mode') || 'four',
		seeds: [],
		grove: 1,
		leaves: params.get('leaves') !== '0',
		grid: params.get('grid') === '1',
		today: params.get('today') !== '0',
		profile: 'oct',
		twigLeaves: params.get('tl') !== '0',
		bark: params.get('bark') || DEFAULT_BARK,
		trees: []
	};
	if (TreeGen.ORDER.indexOf(state.species) < 0) { state.species = 'apple'; }
	if (params.get('bare') === '1') { document.body.classList.add('bare'); }

	function randomSeed() { return 1 + Math.floor(Math.random() * 99999); }
	function newSeeds() {
		state.seeds = [randomSeed(), randomSeed(), randomSeed(), randomSeed()];
		state.grove = randomSeed();
	}
	if (params.get('seeds')) {
		state.seeds = params.get('seeds').split(',').map(function (s) { return parseInt(s, 10) || 1; }).slice(0, 4);
		state.grove = state.seeds[0];
	} else {
		state.seeds = [1, 2, 3, 4];
		state.grove = 1;
	}

	// ------------------------------------------------------------ labels

	var labels = [];
	function clearLabels() {
		labels.forEach(function (l) { l.el.remove(); });
		labels = [];
	}
	function label(text, x, y, z, cls) {
		var el = document.createElement('div');
		el.className = 'tag' + (cls ? ' ' + cls : '');
		el.textContent = text;
		view.appendChild(el);
		labels.push({el: el, pos: new THREE.Vector3(x, y, -z)});
	}
	function placeLabels() {
		var w = view.clientWidth, h = view.clientHeight;
		labels.forEach(function (l) {
			var p = l.pos.clone().project(camera);
			var vis = p.z < 1 && p.x > -1.1 && p.x < 1.1 && p.y > -1.1 && p.y < 1.1;
			l.el.style.display = vis ? 'block' : 'none';
			l.el.style.transform = 'translate(' + ((p.x + 1) / 2 * w) + 'px,' + ((1 - p.y) / 2 * h) + 'px) translate(-50%,-100%)';
		});
	}

	// ------------------------------------------------------------- build

	var SPACING = {apple: 10, jungle: 9, kapok: 15, acacia: 13, pine: 6, aspen: 5, silverwood: 7, gravewood: 7, swamp: 12};

	function todayTree(species) {
		var t = TODAY[species];
		return t ? {species: species, seed: 'today', nodes: t.nodes, today: true, count: t.count,
			wood: t.wood, shapes: 0, height: t.height, width: t.width, depth: t.depth, min: t.min, max: t.max,
			note: t.note} : null;
	}

	function dispose() {
		content.children.slice().forEach(function (c) {
			content.remove(c);
			c.traverse(function (o) { if (o.geometry) { o.geometry.dispose(); } });
		});
		leafMeshes = [];
		clearLabels();
	}

	function build() {
		dispose();
		resize();
		var woods = woodsOf(state.species);
		setGround(woods.ground);
		var placed = [];
		var trees = [];
		if (state.mode === 'four') {
			var x = 0;
			var row = [];
			if (state.today) {
				var tt = todayTree(state.species);
				if (tt) { row.push(tt); }
			}
			state.seeds.forEach(function (s) { row.push(TreeGen.generate(state.species, s)); });
			var maxW = 0;
			row.forEach(function (t) { maxW = Math.max(maxW, t.width, t.depth); });
			var gap = Math.max(maxW + 3, 8);
			x = -((row.length - 1) * gap) / 2;
			row.forEach(function (t, i) {
				var ox = Math.round(x + i * gap + (t.today ? -2 : 0));
				placed.push({tree: t, dx: ox, dz: 0});
			});
		} else if (state.mode === 'grove') {
			var rng = TreeGen.newRng(state.grove, 99);
			var sp = SPACING[state.species];
			var want = 12, tries = 0;
			var size = Math.ceil(Math.sqrt(want) * sp * 1.25);
			var spots = [];
			while (spots.length < want && tries < 4000) {
				tries++;
				var px = TreeGen.rint(rng, 0, size) - Math.floor(size / 2);
				var pz = TreeGen.rint(rng, 0, size) - Math.floor(size / 2);
				var ok = spots.every(function (s) { return (s[0] - px) * (s[0] - px) + (s[1] - pz) * (s[1] - pz) >= sp * sp; });
				if (ok) { spots.push([px, pz]); }
			}
			spots.forEach(function (s, i) {
				placed.push({tree: TreeGen.generate(state.species, state.grove * 100 + i), dx: s[0], dz: s[1]});
			});
		} else {
			shapeStudy(woods);
			return;
		}
		var box = new THREE.Box3();
		placed.forEach(function (p) {
			var g = new THREE.Group();
			var meshes = buildTree(g, p.tree, woods, p.dx, p.dz);
			leafMeshes = leafMeshes.concat(meshes.leaves);
			content.add(g);
			trees.push(p);
			box.expandByPoint(new THREE.Vector3(p.dx + p.tree.min[0] - 1, 0, -(p.dz + p.tree.min[2] - 1)));
			box.expandByPoint(new THREE.Vector3(p.dx + p.tree.max[0] + 1, p.tree.height, -(p.dz + p.tree.max[2] + 1)));
			if (state.mode === 'four') {
				label(p.tree.today ? 'today' : 'seed ' + p.tree.seed, p.dx, p.tree.height + 1.2, p.dz, p.tree.today ? 'today' : '');
			}
		});
		// the player stands in front of the row
		var fig = playerFigure();
		fig.position.set(box.min.x + 1.5, 0, box.max.z + 1.5);
		if (state.mode === 'four') { fig.position.set(placed[placed.length > 1 ? 1 : 0].dx + 3.5, 0, -2.5); }
		content.add(fig);
		state.trees = trees;
		applyToggles();
		buildGrid(box);
		frame(box);
		readout();
	}

	// A close look at the shapes: a 2 x 2 and a 3 x 3 trunk section with a
	// limb leaving, a branch staircase with a fork, twigs.
	function shapeStudy(woods) {
		var nodes = [];
		function add(x, y, z, kind, rot) { nodes.push({x: x, y: y, z: z, kind: kind, rot: rot || 0}); }
		var y;
		// a 2 x 2 trunk (axis at x = -6, z = 0) with a limb to +x and one
		// towards the viewer (-z), both through a limb base
		for (y = 0; y < 5; y++) {
			[[-7, -1], [-6, -1], [-7, 0], [-6, 0]].forEach(function (c) {
				add(c[0], y, c[1], 'quarter', TreeGen.quarterRot(c[0] === -7 ? 1 : -1, c[1] === -1 ? 1 : -1));
			});
		}
		add(-5, 2, 0, 'base', 12); add(-4, 2, 0, 'branch', 12); add(-4, 3, 0, 'branch', 0);
		add(-3, 3, 0, 'twig', 12); add(-3, 4, 0, 'twig', 0);
		add(-7, 1, -2, 'base', 4); add(-7, 1, -3, 'branch', 4); add(-7, 2, -3, 'twig', 0);
		// a 3 x 3 trunk (centre x = 2): limbs from a corner piece and an edge log
		for (y = 0; y < 5; y++) {
			for (var i = -1; i <= 1; i++) {
				for (var j = -1; j <= 1; j++) {
					var corner = i !== 0 && j !== 0;
					add(i + 2, y, j, corner ? 'quarter' : 'trunk', TreeGen.quarterRot(-i, -j));
				}
			}
		}
		add(4, 3, 1, 'base', 12); add(5, 3, 1, 'branch', 12); add(5, 4, 1, 'twig', 0);
		add(2, 2, -2, 'base', 4); add(2, 2, -3, 'branch', 4); add(2, 3, -3, 'twig', 0);
		// a 1 x 1 log: base, branch, twig, into leaves
		add(8, 0, 0, 'trunk', 0); add(8, 1, 0, 'trunk', 0); add(8, 2, 0, 'trunk', 0); add(8, 3, 0, 'twig', 0);
		add(9, 2, 0, 'base', 12); add(10, 2, 0, 'branch', 12); add(10, 3, 0, 'branch', 0);
		add(11, 3, 0, 'twig', 12); add(11, 4, 0, 'twig', 0);
		[[11, 5, 0], [12, 4, 0], [12, 5, 0], [11, 4, 1], [11, 4, -1], [11, 5, 1], [8, 4, 0], [10, 4, 0]].forEach(function (c) {
			add(c[0], c[1], c[2], 'leaves', 0);
		});
		var tree = {nodes: nodes, min: [-8, 0, -3], max: [12, 5, 1], height: 6};
		var meshes = buildTree(content, tree, woods, 0, 0);
		leafMeshes = meshes.leaves;
		label('2×2, limb bases', -6.5, 6.2, 0, '');
		label('3×3', 2, 6.2, 0, '');
		label('log → base → branch → twig → leaves', 10, 6.2, 0, '');
		// roots on flat ground, [h, reach, fork] per side (+x, +z, -x, -z):
		// kapok feet (3 x 3, 2 x 2), a jungle with one raised root, an apple
		// with two one-cell roots
		buildTree(content, TreeGen.rootStudy(flatGround, 3, [[3, 3, 1], [2, 2, 0], [0, 3, -1], [2, 3, 1]]), woods, -9, -10);
		buildTree(content, TreeGen.rootStudy(flatGround, 2, [[2, 2, 1], [3, 3, 0], [0, 2, 0], [2, 3, -1]]), woods, -2, -10);
		buildTree(content, TreeGen.rootStudy(flatGround, 2, [[2, 2, 0], null, [0, 2, 0], null]), woods, 4, -10);
		buildTree(content, TreeGen.rootStudy(flatGround, 2, [[0, 1, 0], null, [0, 1, 0], null]), woods, 9, -10);
		label('kapok 3×3 foot', -8, 6.2, -10, '');
		label('kapok 2×2 foot', -2.5, 6.2, -10, '');
		label('jungle, a raised root', 3.5, 6.2, -10, '');
		label('apple, 1-long roots', 8.5, 6.2, -10, '');
		// a hillside: the foot stands 2 up; west of the trunk the ground
		// falls away, east of it it rises: no root there
		var hx = 16, hz = -10, lift = 2;
		function height(x, z) {
			if (x <= hx - 2 || x > hx + 4 || z < hz - 4 || z > hz + 3) { return 0; }
			return x >= hx + 2 ? 3 : 2;
		}
		var terrain = [];
		for (var tx = hx - 3; tx <= hx + 4; tx++) {
			for (var tz = hz - 4; tz <= hz + 3; tz++) {
				for (var ty = 0; ty < height(tx, tz); ty++) { terrain.push([tx, ty, tz, ty === height(tx, tz) - 1]); }
			}
		}
		addTerrain(content, terrain);
		var hill = function (x, y, z) { return y + lift < height(x + hx, z + hz); };
		buildTree(content, TreeGen.rootStudy(hill, 2, [[2, 2, 0], [2, 3, 1], [2, 2, 0], [2, 3, -1]]), woods, hx, hz, hill, lift);
		label('hillside: falls away west, rises east', hx, 7.2, hz, '');
		var fig = playerFigure();
		fig.position.set(-1, 0, 3);
		content.add(fig);
		state.trees = [];
		var box = new THREE.Box3(new THREE.Vector3(-12, 0, -4), new THREE.Vector3(21, 7, 14));
		applyToggles();
		buildGrid(box);
		frame(box, 0.7);
		readout();
	}

	// Terrain cubes [x, y, z, isTop] for the hillside: grass on top, dirt
	// below, faces between terrain cubes culled.
	function addTerrain(group, cells) {
		var set = {};
		cells.forEach(function (c) { set[c[0] + ',' + c[1] + ',' + c[2]] = true; });
		var buckets = new Buckets();
		var top = faceTiles(['default_grass', 'default_dirt', 'default_grass_side', 'default_grass_side',
			'default_grass_side', 'default_grass_side'], 0);
		var dirt = faceTiles(['default_dirt', 'default_dirt', 'default_dirt', 'default_dirt', 'default_dirt',
			'default_dirt'], 0);
		cells.forEach(function (c) {
			var skip = FACE_DIRS.map(function (d) {
				return set[(c[0] + d[0]) + ',' + (c[1] + d[1]) + ',' + (c[2] + d[2])] === true || (c[1] === 0 && d[1] < 0);
			});
			addCuboid(buckets, 'wood', c[0], c[1] + 0.5, c[2], [-8, -8, -8, 8, 8, 8], c[3] ? top : dirt, skip);
		});
		Object.keys(buckets.map).forEach(function (k) {
			var bk = buckets.map[k];
			var g = new THREE.BufferGeometry();
			g.setAttribute('position', new THREE.Float32BufferAttribute(bk.pos, 3));
			g.setAttribute('normal', new THREE.Float32BufferAttribute(bk.nor, 3));
			g.setAttribute('uv', new THREE.Float32BufferAttribute(bk.uv, 2));
			g.setIndex(bk.idx);
			var mesh = new THREE.Mesh(g, material(bk.tex, 'wood'));
			mesh.castShadow = true;
			mesh.receiveShadow = true;
			group.add(mesh);
		});
	}

	function buildGrid(box) {
		grid.children.slice().forEach(function (c) { grid.remove(c); c.geometry.dispose(); });
		var x0 = Math.floor(box.min.x) - 4, x1 = Math.ceil(box.max.x) + 4;
		var z0 = Math.floor(box.min.z) - 4, z1 = Math.ceil(box.max.z) + 4;
		var top = Math.ceil(box.max.y) + 2;
		var pts = [];
		var k;
		for (k = x0; k <= x1; k++) { pts.push(k + 0.5, 0.01, z0 + 0.5, k + 0.5, 0.01, z1 + 0.5); }
		for (k = z0; k <= z1; k++) { pts.push(x0 + 0.5, 0.01, k + 0.5, x1 + 0.5, 0.01, k + 0.5); }
		// a wall behind the row for counting heights
		var zb = z0 + 0.5;
		for (k = x0; k <= x1; k++) { pts.push(k + 0.5, 0, zb, k + 0.5, top, zb); }
		for (k = 0; k <= top; k++) { pts.push(x0 + 0.5, k, zb, x1 + 0.5, k, zb); }
		var g = new THREE.BufferGeometry();
		g.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
		var lines = new THREE.LineSegments(g, new THREE.LineBasicMaterial({color: 0x1d2a33, transparent: true, opacity: 0.35}));
		grid.add(lines);
		grid.visible = state.grid;
	}

	var lastBox = null;
	function frame(box, zoom) {
		lastBox = box;
		var c = new THREE.Vector3();
		box.getCenter(c);
		var size = new THREE.Vector3();
		box.getSize(size);
		var cam = (params.get('cam') || '').split(',').map(parseFloat);
		var yaw = isFinite(cam[0]) ? cam[0] : 0;
		var pitch = isFinite(cam[1]) ? cam[1] : 12;
		var vt = Math.tan(camera.fov * Math.PI / 360), ht = vt * camera.aspect;
		var dist = Math.max(size.x / 2 / ht, size.y / 2 / vt) * 1.15 + size.z / 2;
		dist = dist * (zoom || 1) * (isFinite(cam[2]) ? cam[2] : 1);
		dist = Math.max(dist, 12);
		controls.target.set(c.x, size.y * 0.42, c.z);
		var yr = yaw * Math.PI / 180, pr = pitch * Math.PI / 180;
		camera.position.set(c.x + Math.sin(yr) * Math.cos(pr) * dist, size.y * 0.42 + Math.sin(pr) * dist,
			c.z + Math.cos(yr) * Math.cos(pr) * dist);
		controls.update();
		// the sun's shadow box follows the scene
		var r = Math.max(size.x, size.z, size.y) * 0.75 + 6;
		sun.position.set(c.x - r * 0.6, r * 1.6, c.z + r * 0.9);
		sun.target.position.copy(c);
		var sc = sun.shadow.camera;
		sc.left = -r * 1.3; sc.right = r * 1.3; sc.top = r * 1.3; sc.bottom = -r * 1.3;
		sc.near = 0.5; sc.far = r * 5;
		sc.updateProjectionMatrix();
	}

	function applyToggles() {
		leafMeshes.forEach(function (m) { m.visible = state.leaves; });
		grid.visible = state.grid;
	}

	// ------------------------------------------------------------ readout

	var TODAY_NOTE = {};
	function fmtRow(t) {
		var c = t.count;
		var q = quads(t);
		return '<tr' + (t.today ? ' class="today"' : '') + '><th>' + (t.today ? 'today' : t.seed) + '</th>' +
			'<td>' + t.height + '</td><td>' + t.width + '×' + t.depth + '</td>' +
			'<td>' + t.wood + '</td><td>' + c.trunk + '</td><td>' + (c.quarter || 0) + '</td><td>' + (c.branch || 0) +
			'</td><td>' + (c.twig || 0) + '</td><td>' + c.leaves + '</td><td>' + (c.fruit || 0) + '</td><td>' + q + '</td></tr>';
	}

	function readout() {
		var el = document.getElementById('readout');
		var sp = state.species;
		var html = '<p class="concept">' + CONCEPT[sp] + '</p>';
		if (state.mode === 'shapes') {
			el.innerHTML = html;
			return;
		}
		var rows = state.trees.map(function (p) { return p.tree; });
		var tt = todayTree(sp);
		if (tt && !(state.mode === 'four' && state.today)) { rows.unshift(tt); }
		html += '<div class="tablewrap"><table><thead><tr><th>seed</th><th>h</th><th>w×d</th><th>wood</th><th>log</th><th>qtr</th><th>br</th><th>twig</th><th>leaf</th><th>fruit</th><th title="approximate quads the client draws">≈quads</th></tr></thead><tbody>';
		rows.forEach(function (t) { html += fmtRow(t); });
		html += '</tbody></table></div>';
		if (tt && tt.note) { html += '<p class="note">Today: ' + tt.note + '</p>'; }
		var facts = rows.filter(function (t) { return !t.today; }).slice(0, 4).map(function (t) {
			var f = t.facts || {};
			return '<li><b>' + t.seed + '</b>: ' + Object.keys(f).map(function (k) { return k + ' ' + f[k]; }).join(', ') + '</li>';
		}).join('');
		if (state.mode === 'four') { html += '<ul class="facts">' + facts + '</ul>'; }
		el.innerHTML = html;
	}

	// ----------------------------------------------------------------- ui

	var pick = document.getElementById('species');
	TreeGen.ORDER.forEach(function (sp) {
		var b = document.createElement('button');
		b.textContent = sp;
		b.dataset.sp = sp;
		b.onclick = function () { state.species = sp; syncUi(); build(); };
		pick.appendChild(b);
	});
	var seedField = document.getElementById('seed');
	function syncUi() {
		Array.prototype.forEach.call(pick.children, function (b) { b.classList.toggle('on', b.dataset.sp === state.species); });
		Array.prototype.forEach.call(document.querySelectorAll('[data-mode]'), function (b) {
			b.classList.toggle('on', b.dataset.mode === state.mode);
		});
		seedField.value = state.mode === 'grove' ? state.grove : state.seeds.join(',');
		document.getElementById('leaves').checked = state.leaves;
		document.getElementById('grid').checked = state.grid;
		document.getElementById('today').checked = state.today;
		document.getElementById('tl').checked = state.twigLeaves;
		document.getElementById('bark').value = JUNGLE_BARKS.indexOf(state.bark) >= 0 ? state.bark : 'today';
	}
	Array.prototype.forEach.call(document.querySelectorAll('[data-mode]'), function (b) {
		b.onclick = function () { state.mode = b.dataset.mode; syncUi(); build(); };
	});
	document.getElementById('reseed').onclick = function () { newSeeds(); syncUi(); build(); };
	seedField.onchange = function () {
		var v = seedField.value.split(/[ ,;]+/).map(function (s) { return parseInt(s, 10); }).filter(function (n) { return n >= 0; });
		if (!v.length) { return; }
		if (state.mode === 'grove') {
			state.grove = v[0];
		} else {
			var base = v[0];
			state.seeds = v.length >= 4 ? v.slice(0, 4) : [base, base + 1, base + 2, base + 3].map(function (s, i) { return v[i] !== undefined ? v[i] : s; });
		}
		syncUi();
		build();
	};
	document.getElementById('leaves').onchange = function (e) { state.leaves = e.target.checked; applyToggles(); };
	document.getElementById('grid').onchange = function (e) { state.grid = e.target.checked; applyToggles(); };
	document.getElementById('today').onchange = function (e) { state.today = e.target.checked; build(); };
	document.getElementById('tl').onchange = function (e) { state.twigLeaves = e.target.checked; build(); };
	var barkSel = document.getElementById('bark');
	['today'].concat(JUNGLE_BARKS).forEach(function (id) {
		var o = document.createElement('option');
		o.value = id;
		o.textContent = id === 'today' ? 'today' : id;
		barkSel.appendChild(o);
	});
	barkSel.onchange = function () { state.bark = barkSel.value; build(); };
	document.getElementById('copy').onclick = function () {
		var out = state.trees.map(function (p) {
			return {species: p.tree.species, seed: p.tree.seed, at: [p.dx, 0, p.dz], nodes: p.tree.nodes};
		});
		var text = JSON.stringify(out);
		var done = function () {
			var b = document.getElementById('copy');
			b.textContent = 'Copied';
			setTimeout(function () { b.textContent = 'Copy node list (JSON)'; }, 1400);
		};
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text); done(); });
		} else {
			fallbackCopy(text);
			done();
		}
	};
	function fallbackCopy(text) {
		var ta = document.createElement('textarea');
		ta.value = text;
		document.body.appendChild(ta);
		ta.select();
		try { document.execCommand('copy'); } catch (e) { /* nothing more to try */ }
		ta.remove();
	}

	function resize() {
		var w = view.clientWidth, h = view.clientHeight;
		renderer.setSize(w, h);
		camera.aspect = w / h;
		camera.updateProjectionMatrix();
		if (lastBox) { frame(lastBox, state.mode === 'shapes' ? 0.7 : 1); }
	}
	window.addEventListener('resize', resize);

	function loop() {
		requestAnimationFrame(loop);
		controls.update();
		renderer.render(scene, camera);
		placeLabels();
	}

	resize();
	syncUi();
	build();
	loop();
	window.__treeViewerReady = true;
})();
