// Round 47 lane SW, concept: the three.js side of the swamp page.
//
// Draws a SwampPatch the way the Luanti client meshes its nodes: ground
// cubes with the faces against other ground culled, liquid sources with
// their top at the node border, plantlike nodes as two crossed quads
// (visual_scale, and a leveled plantlike_rooted plant tiled once per node
// of height), the waterlily's thin box, the moss carpet's 1/16 box, and the
// trees with the shapes of tools/r46_tree/concept (log cubes and connected
// node boxes, grain by facedir). The cuboid texture coordinates and the
// facedir tile table are copied from tools/r46_tree/concept/viewer.js
// (keep them in step). Luanti's z axis points the other way to three.js's,
// so z is mirrored and the winding fixed.
/* global THREE, TreeGen, TreeShapes, SwampPatch, TEXTURES, ART_SET */
(function () {
	'use strict';

	var BOXES = TreeShapes.BOXES, CONNECTS = TreeShapes.CONNECTS;

	// mapblock_mesh.cpp getNodeTile rows for facedir 0, 4 and 12 (the grain
	// turns the swamp tree uses): [dir_i] -> tile index, rotation
	var DIR_TO_TILE = {
		0: [[0, 0], [2, 0], [0, 0], [4, 0], [0, 0], [5, 0], [1, 0], [3, 0]],
		4: [[0, 0], [2, 3], [5, 0], [0, 2], [0, 0], [1, 0], [4, 2], [3, 1]],
		12: [[0, 0], [0, 3], [3, 3], [4, 1], [0, 0], [5, 3], [2, 3], [1, 3]]
	};
	// face order of a cuboid: top, bottom, right, left, back, front
	var FACE_DIRS = [[0, 1, 0], [0, -1, 0], [1, 0, 0], [-1, 0, 0], [0, 0, 1], [0, 0, -1]];
	function faceTiles(tiles, facedir) {
		var out = [];
		for (var f = 0; f < 6; f++) {
			var d = FACE_DIRS[f];
			var e = DIR_TO_TILE[facedir][(d[0] + 2 * d[1] + 3 * d[2]) & 7];
			out.push({tex: tiles[e[0]], rot: e[1]});
		}
		return out;
	}
	var SIDE_DIRS = {top: [0, 1, 0], bottom: [0, -1, 0], right: [1, 0, 0], left: [-1, 0, 0],
		back: [0, 0, 1], front: [0, 0, -1]};
	var SIDE_ORDER = ['top', 'bottom', 'front', 'left', 'back', 'right'];

	// ----------------------------------------------------------- textures

	// Texture slots: the ART proposal where it exists, else the stand-in.
	// A stand-in is a list of steps on a 16 x 16 canvas, as a Luanti texture
	// modifier would do it: {img} draws a texture over what is there
	// (^), {colorize: [colour, ratio]} is ^[colorize, {flipY} ^[transformFY.
	var STANDIN = {
		mud: [{img: 'grug_nodes_mud'}],
		mud_light: [{img: 'grug_nodes_mud'}, {colorize: ['#8a7650', 100]}],
		mud_mottled: [{img: 'grug_nodes_mud'}, {colorize: ['#26352a', 80]}],
		wet_grass: [{img: 'default_grass'}, {colorize: ['#2d4a24', 110]}],
		wet_grass_side: [{img: 'grug_nodes_mud'}, {img: 'default_grass_side'}, {colorize: ['#2d4a24', 60]}],
		moss_top: [{img: 'default_moss'}],
		moss_side: [{img: 'default_dirt'}, {img: 'default_moss_side'}],
		dirt: [{img: 'default_dirt'}],
		moss_carpet: [{img: 'default_moss'}],
		reeds: [{img: 'default_papyrus'}],
		cattail: [{img: 'default_marram_grass_3'}, {colorize: ['#6b5a34', 90]}],
		hanging_moss: [{img: 'default_junglegrass'}, {flipY: true}, {colorize: ['#8d9a7a', 150]}],
		leaves_olive: [{img: 'default_jungleleaves'}, {colorize: ['#5d6b3a', 110]}],
		leaves_grey: [{img: 'default_leaves'}, {colorize: ['#858585', 210]}],
		bark: [{img: 'grug_trees_gravewood_tree'}],
		bark_top: [{img: 'grug_trees_gravewood_tree_top'}],
		water: [{img: 'default_water'}],
		waterlily: [{img: 'grug_mapgen_waterlily'}],
		fern_1: [{img: 'default_fern_1'}], fern_2: [{img: 'default_fern_2'}], fern_3: [{img: 'default_fern_3'}],
		grass_3: [{img: 'default_grass_3'}], grass_4: [{img: 'default_grass_4'}], grass_5: [{img: 'default_grass_5'}],
		junglegrass: [{img: 'default_junglegrass'}],
		dry_shrub: [{img: 'default_dry_shrub'}],
		character: [{img: 'character'}]
	};
	// slot -> ART file (tools/r47_art/swamp), when ART_SET has it
	var ART = {
		mud_light: 'mud_dry_top', mud_light_side: 'mud_dry_side',
		mud_mottled: 'mud_mottled_top', mud_mottled_side: 'mud_mottled_side',
		wet_grass: 'wet_grass_top', wet_grass_side: 'wet_grass_side',
		moss_carpet: 'moss_carpet_top', reeds: 'reeds', cattail: 'cattails', hanging_moss: 'hanging_moss',
		leaves_olive: 'swamp_leaves'
	};
	// slots without a texture of their own
	var SAME = {mud_light_side: 'mud_light', mud_mottled_side: 'mud_mottled'};

	// Texture lab (Round 51 concept): per slot the textures to compare with
	// today's, as [label, TEXTURES key]; build.py inlines tools/r51_land/swamp
	// as lab_<file>, a PNG uploaded on the page is added as up_<n>. A texture
	// wider than 16 px is drawn world-aligned over 2 x 2 (32 px) or 4 x 4
	// (64 px) nodes, as Luanti's align_style = "world" with that scale.
	// hanging_moss_mid is the moss node with more moss below it.
	var LAB = {
		wet_grass: [['calm', 'lab_wet_grass_top_calm'], ['calm, 2 × 2 nodes', 'lab_wet_grass_top_calm32']],
		wet_grass_side: [['calm', 'lab_wet_grass_side_calm']],
		mud_mottled: [['calm', 'lab_mud_mottled_top_calm'], ['calm, 2 × 2 nodes', 'lab_mud_mottled_top_calm32']],
		mud_mottled_side: [['calm', 'lab_mud_mottled_side_calm']],
		mud_light: [['2 × 2 nodes (Astra)', 'lab_mud_dry_top_32']], mud_light_side: [],
		mud: [['2 × 2 nodes (Astra)', 'lab_mud_top_32']],
		moss_top: [['muted, 2 × 2 nodes (Astra)', 'lab_moss_soil_top_32']],
		moss_side: [['muted (Astra)', 'lab_moss_soil_side']], moss_carpet: [],
		hanging_moss: [], hanging_moss_mid: [['continuous strand', 'lab_hanging_moss_strand']]
	};
	var LAB_NAMES = {
		wet_grass: 'wet grass, top', wet_grass_side: 'wet grass, side', mud_mottled: 'wet (mottled) mud, top',
		mud_mottled_side: 'wet mud, side', mud_light: 'dry mud, top', mud_light_side: 'dry mud, side',
		mud: 'mud (all faces)', moss_top: 'moss soil, top', moss_side: 'moss soil, side', moss_carpet: 'moss carpet',
		hanging_moss: 'hanging moss, lowest node', hanging_moss_mid: 'hanging moss, nodes above'
	};
	Object.keys(LAB).forEach(function (slot) {
		LAB[slot] = LAB[slot].filter(function (o) { return TEXTURES[o[1]] !== undefined; });
	});

	function labKey(slot) { return state.lab[slot] || ''; }

	// tiles per texture side: 1, or 2 / 4 for a world-aligned 32 / 64 px one
	function slotScale(slot) {
		var src = slotSource(slot);
		if (src.indexOf('lab:') !== 0) { return 1; }
		var im = images[src.slice(4)];
		return im && im.naturalWidth >= 32 ? Math.round(im.naturalWidth / 16) : 1;
	}

	function slotSource(slot) {
		if (labKey(slot)) { return 'lab:' + labKey(slot); }
		if (slot === 'hanging_moss_mid') { return slotSource('hanging_moss'); }
		if (state.tex === 'art' && ART[slot] && ART_SET.indexOf(ART[slot]) >= 0) { return 'art:' + ART[slot]; }
		if (STANDIN[slot]) { return 'std:' + slot; }
		return 'std:' + SAME[slot];
	}

	var texCache = {};
	function nearest(t) {
		t.magFilter = THREE.NearestFilter;
		t.minFilter = THREE.NearestFilter;
		t.generateMipmaps = false;
		t.wrapS = t.wrapT = THREE.RepeatWrapping;
		t.encoding = THREE.sRGBEncoding;
		return t;
	}
	var images = {};
	function image(name, done) {
		if (images[name] && images[name].complete) { done(images[name]); return; }
		if (!images[name]) {
			images[name] = new Image();
			images[name].waiting = [];
			images[name].onload = function () {
				var w = images[name].waiting;
				images[name].waiting = [];
				w.forEach(function (f) { f(images[name]); });
			};
			images[name].src = TEXTURES[name];
		}
		images[name].waiting.push(done);
	}
	function texture(src) {
		if (texCache[src]) { return texCache[src]; }
		var canvas = document.createElement('canvas');
		var lab = src.indexOf('lab:') === 0;
		// a lab texture is loaded before it can be picked: its size is known
		var size = lab ? images[src.slice(4)].naturalWidth : 16;
		canvas.width = size; canvas.height = size;
		var t = nearest(new THREE.CanvasTexture(canvas));
		var g = canvas.getContext('2d');
		var steps = lab ? [{img: src.slice(4)}] :
			src.indexOf('art:') === 0 ? [{img: 'art_' + src.slice(4)}] : STANDIN[src.slice(4)];
		var i = 0;
		(function next() {
			if (i >= steps.length) { t.needsUpdate = true; return; }
			var st = steps[i++];
			if (st.img) {
				// the top square (an animated strip shows its first frame)
				image(st.img, function (img) {
					g.drawImage(img, 0, 0, img.naturalWidth, img.naturalWidth, 0, 0, size, size);
					next();
				});
				return;
			}
			var d = g.getImageData(0, 0, 16, 16), p = d.data, k;
			if (st.colorize) {
				var c = parseInt(st.colorize[0].slice(1), 16), a = st.colorize[1] / 255;
				for (k = 0; k < p.length; k += 4) {
					p[k] = p[k] * (1 - a) + (c >> 16) * a;
					p[k + 1] = p[k + 1] * (1 - a) + ((c >> 8) & 255) * a;
					p[k + 2] = p[k + 2] * (1 - a) + (c & 255) * a;
				}
			} else if (st.flipY) {
				var q = new Uint8ClampedArray(p);
				for (var y = 0; y < 16; y++) {
					for (k = 0; k < 64; k++) { p[y * 64 + k] = q[(15 - y) * 64 + k]; }
				}
			}
			g.putImageData(d, 0, 0);
			next();
		})();
		texCache[src] = t;
		return t;
	}

	var matCache = {};
	function material(src, kind) {
		var k = src + '|' + kind;
		if (matCache[k]) { return matCache[k]; }
		var opts = {map: texture(src)};
		if (kind === 'cutout' || kind === 'leaves') {
			opts.alphaTest = 0.5;
			opts.side = kind === 'cutout' ? THREE.DoubleSide : THREE.FrontSide;
		}
		if (kind === 'water') {
			opts.transparent = true;
			opts.opacity = 0.78;
			opts.depthWrite = false;
		}
		var m = new THREE.MeshLambertMaterial(opts);
		if (kind === 'cutout' || kind === 'leaves') {
			m.userData.depth = new THREE.MeshDepthMaterial({depthPacking: THREE.RGBADepthPacking,
				map: opts.map, alphaTest: 0.5});
		}
		matCache[k] = m;
		return m;
	}

	// ----------------------------------------------------------- meshing

	function Buckets() { this.map = {}; }
	Buckets.prototype.get = function (slot, kind) {
		var src = slotSource(slot);
		var k = src + '|' + kind;
		if (!this.map[k]) { this.map[k] = {src: src, kind: kind, pos: [], nor: [], uv: [], idx: []}; }
		return this.map[k];
	};
	Buckets.prototype.build = function (group, layer) {
		var self = this;
		Object.keys(this.map).forEach(function (k) {
			var bk = self.map[k];
			if (!bk.idx.length) { return; }
			var g = new THREE.BufferGeometry();
			g.setAttribute('position', new THREE.Float32BufferAttribute(bk.pos, 3));
			g.setAttribute('normal', new THREE.Float32BufferAttribute(bk.nor, 3));
			g.setAttribute('uv', new THREE.Float32BufferAttribute(bk.uv, 2));
			g.setIndex(bk.idx);
			var m = material(bk.src, bk.kind);
			var mesh = new THREE.Mesh(g, m);
			mesh.castShadow = bk.kind !== 'water';
			mesh.receiveShadow = true;
			if (m.userData.depth) { mesh.customDepthMaterial = m.userData.depth; }
			mesh.userData.layer = layer;
			if (bk.kind === 'water') { mesh.renderOrder = 2; }
			group.add(mesh);
		});
	};

	// Luanti cuboid faces and texture coordinates for one box (sixteenths,
	// relative to the node centre at ox, oy, oz).
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
		var ix = Math.round(ox), iy = Math.floor(oy), iz = Math.round(oz);
		for (var f = 0; f < 6; f++) {
			if (skip && skip[f]) { continue; }
			var tile = tiles[f];
			var bk = buckets.get(tile.tex, kind);
			// world-aligned: this node's cell of the sc x sc texture, along the
			// face's u (right) and w (down) directions
			var sc = slotScale(tile.tex), cu = 0, cw = 0;
			if (sc > 1) {
				var fa = [[ix, -iz], [ix, iz], [iz, -iy], [-iz, -iy], [-ix, -iy], [ix, -iy]][f];
				cu = ((fa[0] % sc) + sc) % sc;
				cw = ((fa[1] % sc) + sc) % sc;
			}
			var base = bk.pos.length / 3;
			var n = FACE_DIRS[f];
			var pts = [];
			for (var j = 0; j < 4; j++) {
				var v = V[f][j];
				var u = txc[v[3]], w = txc[v[4]], t;
				if (tile.rot === 1) { t = 1 - w; w = u; u = t; }
				else if (tile.rot === 2) { u = 1 - u; w = 1 - w; }
				else if (tile.rot === 3) { t = w; w = 1 - u; u = t; }
				if (sc > 1) { u = (u + cu) / sc; w = (w + cw) / sc; }
				var p = [ox + v[0], oy + v[1], -(oz + v[2])];
				pts.push(p);
				bk.pos.push(p[0], p[1], p[2]);
				bk.nor.push(n[0], n[1], -n[2]);
				bk.uv.push(u, 1 - w);
			}
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

	function uniform(slot) { return faceTiles([slot, slot, slot, slot, slot, slot], 0); }

	// A plantlike node: two crossed quads, visual_scale wide and high from
	// the node's bottom (drawPlantlikeQuad), the texture tiled once per node
	// of `height` (a leveled plantlike_rooted plant), the top of the texture
	// at the top of the plant.
	function addPlant(buckets, slot, ox, oy, oz, scale, height) {
		var bk = buckets.get(slot, 'cutout');
		var s = 0.5 * scale * 0.7071, h = scale * height, y0 = oy - 0.5;
		var quads = [[[-s, -s], [s, s]], [[-s, s], [s, -s]]];
		for (var q = 0; q < 2; q++) {
			var a = quads[q][0], b = quads[q][1];
			var base = bk.pos.length / 3;
			var c = [[a[0], y0 + h, a[1], 0, 0], [b[0], y0 + h, b[1], 1, 0],
				[b[0], y0, b[1], 1, height], [a[0], y0, a[1], 0, height]];
			for (var j = 0; j < 4; j++) {
				bk.pos.push(ox + c[j][0], c[j][1], -(oz + c[j][2]));
				bk.nor.push(0, 1, 0);
				bk.uv.push(c[j][3], 1 - c[j][4]);
			}
			bk.idx.push(base, base + 2, base + 1, base, base + 3, base + 2);
		}
	}

	var PLANT_SCALE = {fern_1: 2, fern_2: 2, fern_3: 2, junglegrass: 1.69, reeds: 1, cattail: 1,
		grass_3: 1, grass_4: 1, grass_5: 1, dry_shrub: 1};

	// ----------------------------------------------------------- the patch

	// Ground and filler: the top node's top and side slots.
	var GROUND = {
		mud: ['mud', 'mud'], mud_light: ['mud_light', 'mud_light_side'],
		mud_mottled: ['mud_mottled', 'mud_mottled_side'], wet_grass: ['wet_grass', 'wet_grass_side'],
		dirt_with_moss: ['moss_top', 'moss_side']
	};
	var FLOOR = -3;   // the lowest layer drawn (the cut through the patch)

	function solidTop(p, x, z) {
		if (x < 0 || z < 0 || x >= p.size || z >= p.size) { return FLOOR - 1; }
		var c = p.cols[x][z];
		if (c.void) { return FLOOR - 1; }
		return c.pool ? -c.pool : c.h;
	}

	function buildPatch(p, groups) {
		var off = -p.size / 2;
		var gb = new Buckets(), wb = new Buckets(), pb = new Buckets();
		var x, z, y;
		for (x = 0; x < p.size; x++) {
			for (z = 0; z < p.size; z++) {
				var c = p.cols[x][z], top = solidTop(p, x, z);
				if (c.void) { continue; }
				var g = c.pool ? GROUND.mud : GROUND[state.ground || c.top];
				var topTiles = faceTiles([g[0], g[1], g[1], g[1], g[1], g[1]], 0);
				var fill = uniform('mud');
				for (y = FLOOR; y <= top; y++) {
					var skip = [y !== top, true, false, false, false, false];
					for (var f = 2; f < 6; f++) {
						var d = FACE_DIRS[f];
						skip[f] = solidTop(p, x + d[0], z + d[2]) >= y;
					}
					addCuboid(gb, 'solid', x + off, y + 0.5, z + off, [-8, -8, -8, 8, 8, 8], y === top ? topTiles : fill, skip);
				}
				if (c.pool) {
					// a liquid source: full height, faces against ground culled
					var wt = uniform('water');
					addCuboid(wb, 'water', x + off, 0.5, z + off, [-8, -8, -8, 8, 8, 8], wt,
						[false, true, true, true, true, true]);
				}
			}
		}
		p.nodes.forEach(function (n) {
			var ox = n.x + off, oy = n.y + 0.5, oz = n.z + off;
			if (n.name === 'waterlily') {
				var lily = [];
				for (var i = 0; i < 6; i++) { lily.push({tex: 'waterlily', rot: i === 0 ? n.p2 : 0}); }
				addCuboid(pb, 'cutout', ox, oy, oz, [-8, -8, -8, 8, -7.5, 8], lily, [false, false, true, true, true, true]);
			} else if (n.name === 'moss_carpet') {
				addCuboid(pb, 'cutout', ox, oy, oz, [-8, -8, -8, 8, -7, 8], uniform('moss_carpet'), [false, true, false, false, false, false]);
			} else if (n.name === 'reeds_rooted') {
				// drawn from the bed's top up through the water
				addPlant(pb, 'reeds', ox, oy + 1, oz, 1, n.p2 / 16);
			} else {
				addPlant(pb, n.name, ox, oy, oz, PLANT_SCALE[n.name] || 1, 1);
			}
		});
		gb.build(groups.ground, 'ground');
		wb.build(groups.ground, 'water');
		pb.build(groups.plants, 'plants');
		p.trees.forEach(function (t) {
			var foot = p.cols[t.x][t.z].h + 1;
			buildTree(groups.trees, t.tree, t.x + off, foot, t.z + off, function (tx, ty, tz) {
				return solidTop(p, t.x + tx, t.z + tz) >= foot + ty;
			});
		});
	}

	// One tree: log cubes, connected node boxes, leaves, hanging moss.
	function buildTree(group, tree, ox0, oy0, oz0, isGround) {
		var map = {};
		tree.nodes.forEach(function (n) { map[n.x + ',' + n.y + ',' + n.z] = n; });
		function at(x, y, z) { return map[x + ',' + y + ',' + z]; }
		var wb = new Buckets(), lb = new Buckets();
		var woodTiles = ['bark_top', 'bark_top', 'bark', 'bark', 'bark', 'bark'];
		var barkTiles = ['bark', 'bark', 'bark', 'bark', 'bark', 'bark'];
		var leafSlot = state.leaves === 'grey' ? 'leaves_grey' : 'leaves_olive';
		tree.nodes.forEach(function (nd) {
			var ox = nd.x + ox0, oy = nd.y + oy0 + 0.5, oz = nd.z + oz0;
			if (nd.kind === 'trunk') {
				var skip = [];
				for (var f = 0; f < 6; f++) {
					var d = FACE_DIRS[f], nb = at(nd.x + d[0], nd.y + d[1], nd.z + d[2]);
					skip.push(nb !== undefined && nb.kind === 'trunk');
				}
				addCuboid(wb, 'solid', ox, oy, oz, [-8, -8, -8, 8, 8, 8], faceTiles(woodTiles, nd.rot), skip);
			} else if (BOXES[nd.kind]) {
				var shape = BOXES[nd.kind], joins = CONNECTS[nd.kind];
				var bt = faceTiles(barkTiles, nd.rot);
				addCuboid(wb, 'solid', ox, oy, oz, shape.core, bt, null);
				SIDE_ORDER.forEach(function (side) {
					var sd = SIDE_DIRS[side];
					var nb2 = at(nd.x + sd[0], nd.y + sd[1], nd.z + sd[2]);
					var join = nb2 !== undefined ?
						(joins[nb2.kind] === true && !(nb2.kind === 'leaves' && TreeShapes.LEAF_SIDES[side] !== true)) :
						(TreeShapes.GROUND_KINDS[nd.kind] === true && TreeShapes.GROUND_SIDES[side] === true &&
							isGround(nd.x + sd[0], nd.y + sd[1], nd.z + sd[2]));
					if (join) { addCuboid(wb, 'solid', ox, oy, oz, shape[side], bt, null); }
				});
			} else if (nd.kind === 'leaves') {
				addCuboid(lb, 'leaves', ox, oy, oz, [-8, -8, -8, 8, 8, 8], uniform(leafSlot), null);
			} else if (nd.kind === 'moss') {
				var below = at(nd.x, nd.y - 1, nd.z);
				addPlant(lb, below !== undefined && below.kind === 'moss' ? 'hanging_moss_mid' : 'hanging_moss',
					ox, oy, oz, 1, 1);
			}
		});
		wb.build(group, 'wood');
		lb.build(group, 'leaves');
	}

	// A 2-node player for scale (the classic 64 x 32 skin layout).
	function playerFigure() {
		var group = new THREE.Group();
		var mat = new THREE.MeshLambertMaterial({map: texture('std:character'), alphaTest: 0.5});
		function part(w, h, d, u, v, x, y) {
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
				uv.setXY(f * 4 + 0, u0, v0); uv.setXY(f * 4 + 1, u1, v0);
				uv.setXY(f * 4 + 2, u0, v1); uv.setXY(f * 4 + 3, u1, v1);
			}
			var m = new THREE.Mesh(g, mat);
			m.position.set(x / 16, y / 16, 0);
			m.castShadow = true;
			group.add(m);
		}
		part(8, 8, 8, 0, 0, 0, 28);
		part(8, 12, 4, 16, 16, 0, 18);
		part(4, 12, 4, 40, 16, -6, 18);
		part(4, 12, 4, 40, 16, 6, 18);
		part(4, 12, 4, 0, 16, -2, 6);
		part(4, 12, 4, 0, 16, 2, 6);
		return group;
	}

	// -------------------------------------------------------------- scene

	var view = document.getElementById('view');
	var renderer = new THREE.WebGLRenderer({antialias: true, preserveDrawingBuffer: true});
	renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
	renderer.shadowMap.enabled = true;
	renderer.shadowMap.type = THREE.PCFSoftShadowMap;
	renderer.outputEncoding = THREE.sRGBEncoding;
	view.appendChild(renderer.domElement);

	var scene = new THREE.Scene();
	var SKY = 0xb4c6c4;
	scene.background = new THREE.Color(SKY);
	scene.fog = new THREE.Fog(SKY, 90, 240);
	var persp = new THREE.PerspectiveCamera(45, 1, 0.1, 600);
	var ortho = new THREE.OrthographicCamera(-30, 30, 30, -30, 0.1, 400);
	ortho.up.set(0, 0, -1);
	var orbit = new THREE.OrbitControls(persp, renderer.domElement);
	orbit.enableDamping = true;
	orbit.maxPolarAngle = Math.PI * 0.495;
	var topControls = new THREE.OrbitControls(ortho, renderer.domElement);
	topControls.enableRotate = false;
	topControls.screenSpacePanning = true;

	scene.add(new THREE.HemisphereLight(0xe6efe8, 0x5f5a40, 0.85));
	var sun = new THREE.DirectionalLight(0xfff1dc, 1.0);
	sun.castShadow = true;
	sun.shadow.mapSize.set(4096, 4096);
	sun.shadow.bias = -0.0004;
	sun.shadow.normalBias = 0.02;
	sun.shadow.radius = 3;
	scene.add(sun);
	scene.add(sun.target);

	var content = new THREE.Group();
	scene.add(content);
	var grid = new THREE.Group();
	scene.add(grid);

	// -------------------------------------------------------------- state

	var params = new URLSearchParams(location.search);
	var state = {
		seed: parseInt(params.get('seed'), 10) || 1,
		mode: params.get('mode') === 'trees' ? 'trees' : 'patch',
		view: params.get('view') === 'top' ? 'top' : 'orbit',
		tex: params.get('tex') === 'std' || !ART_SET.length ? 'std' : 'art',
		leaves: params.get('leaves') === 'grey' ? 'grey' : 'olive',
		ground: GROUND[params.get('ground')] ? params.get('ground') : '',
		lab: {},
		show: {trees: params.get('trees') !== '0', plants: params.get('plants') !== '0',
			leaves: params.get('leafs') !== '0', grid: params.get('grid') === '1'},
		patch: null
	};
	if (params.get('bare') === '1') { document.body.classList.add('bare'); }

	function groupsOf() {
		return {ground: new THREE.Group(), plants: new THREE.Group(), trees: new THREE.Group()};
	}
	var groups = groupsOf();

	function dispose() {
		content.children.slice().forEach(function (c) {
			content.remove(c);
			c.traverse(function (o) { if (o.geometry) { o.geometry.dispose(); } });
		});
	}

	function build() {
		dispose();
		resize();
		groups = groupsOf();
		Object.keys(groups).forEach(function (k) { content.add(groups[k]); });
		var box;
		if (state.mode === 'patch') {
			state.patch = SwampPatch.generatePatch(state.seed, 48);
			buildPatch(state.patch, groups);
			var fig = playerFigure();
			var spot = figureSpot(state.patch);
			fig.position.set(spot[0], spot[1], -spot[2]);
			groups.trees.add(fig);
			box = new THREE.Box3(new THREE.Vector3(-24, FLOOR, -24), new THREE.Vector3(24, 12, 24));
		} else {
			state.patch = treeRow(state.seed);
			buildPatch(state.patch, groups);
			var fig2 = playerFigure();
			fig2.position.set(-state.patch.size / 2 + 2.5, 1, -(-state.patch.size / 2 + state.patch.trees[0].z + 4));
			groups.trees.add(fig2);
			box = new THREE.Box3(new THREE.Vector3(-state.patch.size / 2 + 2, 0, -7), new THREE.Vector3(state.patch.size / 2 - 2, 11, 7));
		}
		buildGrid(box);
		frame(box);
		applyToggles();
		readout();
	}

	// A flat land column near the patch centre for the player figure.
	function figureSpot(p) {
		var off = -p.size / 2, best = null;
		for (var r = 0; r < 20 && !best; r++) {
			for (var dx = -r; dx <= r && !best; dx++) {
				var x = 24 + dx - 6, z = 24 + r - 6;
				if (x >= 0 && z >= 0 && x < p.size && z < p.size && !p.cols[x][z].pool) { best = [x + off, p.cols[x][z].h + 1, z + off]; }
			}
		}
		return best || [0, 1, 0];
	}

	// The Trees view: four swamp trees side by side on bare mud.
	function treeRow(seed) {
		// a strip of mud 56 x 16 in a 56 x 56 frame
		var size = 56;
		var cols = [];
		for (var x = 0; x < size; x++) {
			cols.push([]);
			for (var z = 0; z < size; z++) {
				cols[x].push({h: 0, top: 'mud', pool: 0, edge: false, void: Math.abs(z - size / 2) > 8});
			}
		}
		var trees = [];
		for (var i = 0; i < 4; i++) {
			trees.push({x: 7 + i * 14, z: size / 2, seed: seed + i, tree: TreeGen.generate('swamp', seed + i)});
		}
		return {seed: seed, size: size, cols: cols, nodes: [], trees: trees, row: true};
	}

	function buildGrid(box) {
		grid.children.slice().forEach(function (c) { grid.remove(c); c.geometry.dispose(); });
		var pts = [], k;
		var x0 = Math.floor(box.min.x), x1 = Math.ceil(box.max.x), z0 = Math.floor(box.min.z), z1 = Math.ceil(box.max.z);
		for (k = x0; k <= x1; k++) { pts.push(k - 0.5, 1.02, -(z0 - 0.5), k - 0.5, 1.02, -(z1 - 0.5)); }
		for (k = z0; k <= z1; k++) { pts.push(x0 - 0.5, 1.02, -(k - 0.5), x1 - 0.5, 1.02, -(k - 0.5)); }
		var g = new THREE.BufferGeometry();
		g.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
		grid.add(new THREE.LineSegments(g, new THREE.LineBasicMaterial({color: 0x1d2a33, transparent: true, opacity: 0.3})));
	}

	var lastBox = null;
	function frame(box) {
		lastBox = box;
		var c = new THREE.Vector3(), size = new THREE.Vector3();
		box.getCenter(c);
		box.getSize(size);
		// three.js z is mirrored: the box was given in Luanti z
		c.z = -c.z;
		var cam = (params.get('cam') || '').split(',').map(parseFloat);
		var row = state.mode !== 'patch';
		var yaw = isFinite(cam[0]) ? cam[0] : (row ? 0 : 28), pitch = isFinite(cam[1]) ? cam[1] : (row ? 12 : 34);
		var zoom = isFinite(cam[2]) ? cam[2] : 1;
		var dist = Math.max(size.x, size.z) * 1.15;
		if (row) {
			// the row fills the view's width
			var vt = Math.tan(persp.fov * Math.PI / 360), ht = vt * persp.aspect;
			dist = Math.max(size.x / 2 / ht, size.y / 2 / vt) * 0.95 + size.z / 2;
		}
		dist = dist * zoom;
		orbit.target.set(c.x, row ? 4 : 0, c.z);
		var yr = yaw * Math.PI / 180, pr = pitch * Math.PI / 180;
		persp.position.set(c.x + Math.sin(yr) * Math.cos(pr) * dist, Math.sin(pr) * dist, c.z + Math.cos(yr) * Math.cos(pr) * dist);
		orbit.update();
		topControls.target.set(c.x, 0, c.z);
		ortho.position.set(c.x, 120, c.z);
		ortho.zoom = 1 / zoom;
		ortho.lookAt(c.x, 0, c.z);
		topControls.update();
		fitOrtho(size);
		var s = Math.max(size.x, size.z) * 0.75 + 6;
		sun.position.set(c.x - s * 0.6, s * 1.6, c.z + s * 0.9);
		sun.target.position.copy(c);
		var sc = sun.shadow.camera;
		sc.left = -s * 1.3; sc.right = s * 1.3; sc.top = s * 1.3; sc.bottom = -s * 1.3;
		sc.near = 0.5; sc.far = s * 5;
		sc.updateProjectionMatrix();
	}
	function fitOrtho(size) {
		var w = view.clientWidth || 1, h = view.clientHeight || 1;
		var half = Math.max(size.x, size.z) / 2 + 1;
		var a = w / h;
		if (a >= 1) { ortho.left = -half * a; ortho.right = half * a; ortho.top = half; ortho.bottom = -half; }
		else { ortho.left = -half; ortho.right = half; ortho.top = half / a; ortho.bottom = -half / a; }
		ortho.updateProjectionMatrix();
	}

	function applyToggles() {
		groups.plants.visible = state.show.plants;
		groups.trees.visible = state.show.trees;
		groups.trees.traverse(function (o) {
			if (o.userData.layer === 'leaves') { o.visible = state.show.leaves; }
		});
		grid.visible = state.show.grid;
		orbit.enabled = state.view === 'orbit';
		topControls.enabled = state.view === 'top';
	}

	// ------------------------------------------------------------ readout

	var NAMES = {
		mud: 'mud (today)', mud_light: 'lighter mud (new)', mud_mottled: 'mottled mud (new)',
		wet_grass: 'wet grass (new)', dirt_with_moss: 'moss soil (exists)'
	};
	function pct(n, all) { return all ? Math.round(n * 100 / all) + ' %' : '–'; }
	function readout() {
		var el = document.getElementById('readout');
		var p = state.patch;
		if (p.row) {
			var rows = p.trees.map(function (t) {
				var c = t.tree.count, f = t.tree.facts;
				return '<tr><th>' + t.seed + '</th><td>' + t.tree.height + '</td><td>' + t.tree.width + '×' + t.tree.depth +
					'</td><td>' + t.tree.wood + '</td><td>' + c.leaves + '</td><td>' + (c.moss || 0) + '</td><td>' + f.stilts +
					'</td><td>' + f.limbs + '</td></tr>';
			}).join('');
			el.innerHTML = '<h2>Swamp trees, seeds ' + p.trees[0].seed + '–' + p.trees[3].seed + '</h2>' +
				'<div class="tablewrap"><table><thead><tr><th>seed</th><th>h</th><th>w×d</th><th>wood</th><th>leaf</th>' +
				'<th>moss</th><th>stilts</th><th>limbs</th></tr></thead><tbody>' + rows + '</tbody></table></div>';
			return;
		}
		var f = p.facts, all = p.size * p.size, land = f.columns.land;
		var html = '<h2>This patch (seed ' + p.seed + ', ' + p.size + ' × ' + p.size + ')</h2>';
		html += '<div class="tablewrap"><table><tbody>' +
			'<tr><th>land</th><td>' + land + '</td><td>' + pct(land, all) + '</td></tr>' +
			'<tr><th>pools 1 deep</th><td>' + f.columns.pool1 + '</td><td>' + pct(f.columns.pool1, all) + '</td></tr>' +
			'<tr><th>pools 2 deep</th><td>' + f.columns.pool2 + '</td><td>' + pct(f.columns.pool2, all) + '</td></tr>' +
			'<tr><th>hummocks (1 up)</th><td>' + f.columns.hummock + '</td><td>' + pct(f.columns.hummock, all) + '</td></tr>' +
			'<tr><th>swamp trees</th><td>' + f.trees + '</td><td></td></tr></tbody></table></div>';
		html += '<h2>Ground (share of land)</h2><div class="tablewrap"><table><tbody>';
		Object.keys(NAMES).forEach(function (k) {
			html += '<tr><th>' + NAMES[k] + '</th><td>' + (f.ground[k] || 0) + '</td><td>' + pct(f.ground[k] || 0, land) + '</td></tr>';
		});
		html += '</tbody></table></div><h2>Plants</h2><div class="tablewrap"><table><tbody>';
		var groupsP = [['waterlilies', ['waterlily']], ['reeds in the pools (rooted)', ['reeds_rooted']],
			['reeds on the bank (nodes)', ['reeds']], ['cattails', ['cattail']], ['moss carpets', ['moss_carpet']],
			['ferns', ['fern_1', 'fern_2', 'fern_3']], ['tall grass', ['grass_3', 'grass_4', 'grass_5', 'junglegrass']],
			['dry shrubs', ['dry_shrub']]];
		groupsP.forEach(function (g) {
			var n = 0;
			g[1].forEach(function (k) { n += f.plants[k] || 0; });
			html += '<tr><th>' + g[0] + '</th><td>' + n + '</td></tr>';
		});
		html += '</tbody></table></div>';
		el.innerHTML = html;
	}

	// ----------------------------------------------------------------- ui

	var seedField = document.getElementById('seed');
	function syncUi() {
		seedField.value = state.seed;
		Array.prototype.forEach.call(document.querySelectorAll('[data-view]'), function (b) {
			b.classList.toggle('on', b.dataset.view === state.view);
		});
		Array.prototype.forEach.call(document.querySelectorAll('[data-mode]'), function (b) {
			b.classList.toggle('on', b.dataset.mode === state.mode);
		});
		['trees', 'plants', 'leaves', 'grid'].forEach(function (k) { document.getElementById('show-' + k).checked = state.show[k]; });
		var texSel = document.getElementById('tex');
		texSel.value = state.tex;
		texSel.disabled = !ART_SET.length;
		document.getElementById('leafsel').value = state.leaves;
		document.getElementById('groundsel').value = state.ground;
	}

	// One row per slot: today's texture or a lab one, a thumbnail, and an
	// upload of an own PNG (16 px, or 32 / 64 px for 2 x 2 / 4 x 4 nodes).
	var uploads = 0;
	function thumb(slot) {
		var src = slotSource(slot), key = null;
		if (src.indexOf('lab:') === 0) { key = src.slice(4); }
		else if (src.indexOf('art:') === 0) { key = 'art_' + src.slice(4); }
		else { var st = STANDIN[src.slice(4)]; key = st && st.length === 1 ? st[0].img : null; }
		return key ? TEXTURES[key] : '';
	}
	function labUi() {
		var el = document.getElementById('lab');
		el.innerHTML = '';
		Object.keys(LAB).forEach(function (slot) {
			var row = document.createElement('div');
			row.className = 'labrow';
			var img = document.createElement('img');
			img.className = 'thumb';
			img.alt = '';
			var src = thumb(slot);
			if (src) { img.src = src; } else { img.style.visibility = 'hidden'; }
			var name = document.createElement('span');
			name.className = 'labname';
			name.textContent = LAB_NAMES[slot];
			var sel = document.createElement('select');
			sel.setAttribute('aria-label', LAB_NAMES[slot]);
			var def = document.createElement('option');
			def.value = '';
			def.textContent = slot === 'hanging_moss_mid' ? 'same as lowest (today)' : 'today';
			sel.appendChild(def);
			LAB[slot].forEach(function (o) {
				var op = document.createElement('option');
				op.value = o[1];
				op.textContent = o[0];
				sel.appendChild(op);
			});
			sel.value = labKey(slot);
			sel.onchange = function () { state.lab[slot] = sel.value; labUi(); build(); };
			var file = document.createElement('input');
			file.type = 'file';
			file.accept = 'image/png';
			file.hidden = true;
			file.onchange = function () {
				var f = file.files[0];
				if (!f) { return; }
				var reader = new FileReader();
				reader.onload = function () {
					uploads = uploads + 1;
					var key = 'up_' + uploads;
					TEXTURES[key] = reader.result;
					image(key, function (im) {
						var w = im.naturalWidth;
						if (w !== 16 && w !== 32 && w !== 64) {
							document.getElementById('labmsg').textContent =
								f.name + ' is ' + w + ' px wide. Use a 16, 32 or 64 px wide PNG.';
							return;
						}
						document.getElementById('labmsg').textContent = '';
						LAB[slot].push([f.name + (w > 16 ? ' (' + w / 16 + ' × ' + w / 16 + ' nodes)' : ''), key]);
						state.lab[slot] = key;
						labUi();
						build();
					});
				};
				reader.readAsDataURL(f);
			};
			var up = document.createElement('button');
			up.textContent = 'PNG…';
			up.title = 'Try an own PNG here (16, 32 or 64 px)';
			up.onclick = function () { file.click(); };
			row.appendChild(img);
			row.appendChild(name);
			row.appendChild(sel);
			row.appendChild(up);
			row.appendChild(file);
			el.appendChild(row);
		});
	}
	function allCalm() {
		Object.keys(LAB).forEach(function (slot) {
			var calm = LAB[slot].filter(function (o) { return o[1].indexOf('lab_') === 0; });
			if (calm.length) { state.lab[slot] = calm[calm.length - 1][1]; }
		});
	}
	document.getElementById('lab-calm').onclick = function () { allCalm(); labUi(); build(); };
	document.getElementById('lab-today').onclick = function () { state.lab = {}; labUi(); build(); };
	Array.prototype.forEach.call(document.querySelectorAll('[data-view]'), function (b) {
		b.onclick = function () { state.view = b.dataset.view; syncUi(); applyToggles(); };
	});
	Array.prototype.forEach.call(document.querySelectorAll('[data-mode]'), function (b) {
		b.onclick = function () { state.mode = b.dataset.mode; syncUi(); build(); };
	});
	document.getElementById('regen').onclick = function () {
		state.seed = 1 + Math.floor(Math.random() * 99999); syncUi(); build();
	};
	document.getElementById('prev').onclick = function () { state.seed = Math.max(1, state.seed - 1); syncUi(); build(); };
	document.getElementById('next').onclick = function () { state.seed = state.seed + 1; syncUi(); build(); };
	seedField.onchange = function () {
		var v = parseInt(seedField.value, 10);
		if (v >= 1) { state.seed = v; build(); }
		syncUi();
	};
	['trees', 'plants', 'leaves', 'grid'].forEach(function (k) {
		document.getElementById('show-' + k).onchange = function (e) { state.show[k] = e.target.checked; applyToggles(); };
	});
	document.getElementById('tex').onchange = function (e) { state.tex = e.target.value; build(); };
	document.getElementById('leafsel').onchange = function (e) { state.leaves = e.target.value; build(); };
	document.getElementById('groundsel').onchange = function (e) { state.ground = e.target.value; build(); };

	function resize() {
		var w = view.clientWidth, h = view.clientHeight;
		renderer.setSize(w, h);
		persp.aspect = w / h;
		persp.updateProjectionMatrix();
		if (lastBox) { var s = new THREE.Vector3(); lastBox.getSize(s); fitOrtho(s); }
	}
	window.addEventListener('resize', resize);

	function loop() {
		requestAnimationFrame(loop);
		if (state.view === 'orbit') { orbit.update(); } else { topControls.update(); }
		renderer.render(scene, state.view === 'orbit' ? persp : ortho);
	}

	// the lab textures are loaded first: their size decides the scale
	var labKeys = [];
	Object.keys(LAB).forEach(function (slot) { LAB[slot].forEach(function (o) { labKeys.push(o[1]); }); });
	var waiting = labKeys.length;
	function start() {
		if (params.get('lab') === 'calm') { allCalm(); }
		resize();
		syncUi();
		labUi();
		build();
		loop();
		window.__swampReady = true;
	}
	if (!waiting) { start(); }
	labKeys.forEach(function (k) { image(k, function () { waiting = waiting - 1; if (!waiting) { start(); } }); });
})();
