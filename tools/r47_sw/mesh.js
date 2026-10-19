// Round 47 lane SW / Round 51 lane VIEW: the client-like mesher shared by the
// swamp page (view.js) and the land viewer (land_view.js).
//
// Builds three.js geometry the way the Luanti client meshes nodes: cuboid
// faces with Luanti's texture coordinates (content_mapblock.cpp, a node box
// face shows the part of its tile that lies under it), world-aligned tiles
// wider than 16 px (align_style = "world", scale = width / 16), plantlike
// nodes as two crossed quads (drawPlantlikeQuad: visual_scale, a leveled
// plantlike_rooted plant tiled once per node of height) and the trunk
// quarter mesh of the tree concept turned by facedir. The cuboid texture
// coordinates and the facedir tile table are copied from
// tools/r46_tree/concept/viewer.js (keep them in step). Luanti's z axis
// points the other way to three.js's, so z is mirrored and the winding
// fixed.
//
// A page hands Buckets three functions: source(tex) -> the texture key the
// bucket is grouped by, scale(tex) -> 1, 2 or 4 (world-aligned tiles per
// texture side), and at build time material(source, kind).
/* global THREE, TreeShapes */
(function (root) {
	'use strict';

	// mapblock_mesh.cpp getNodeTile rows for facedir 0, 4 and 12 (the grain
	// turns the trees use): [dir_i] -> tile index, rotation
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

	function Buckets(source, scale) {
		this.map = {};
		this.source = source;
		this.scale = scale;
	}
	Buckets.prototype.get = function (tex, kind) {
		var src = this.source(tex);
		var k = src + '|' + kind;
		if (!this.map[k]) { this.map[k] = {src: src, kind: kind, pos: [], nor: [], uv: [], idx: []}; }
		return this.map[k];
	};
	Buckets.prototype.build = function (group, layer, material) {
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
	// relative to the node centre at ox, oy, oz). skip[f] leaves face f out.
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
			var sc = buckets.scale(tile.tex), cu = 0, cw = 0;
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

	function uniform(tex) { return faceTiles([tex, tex, tex, tex, tex, tex], 0); }

	// A plantlike node: two crossed quads, visual_scale wide and high from
	// the node's bottom (drawPlantlikeQuad), the texture tiled once per node
	// of `height` (a leveled plantlike_rooted plant), the top of the texture
	// at the top of the plant.
	function addPlant(buckets, tex, ox, oy, oz, scale, height) {
		var bk = buckets.get(tex, 'cutout');
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

	// The trunk quarter mesh turned by facedir like rotateMeshBy6dFacedir
	// does for 0..3 (the same turn as a node box: (x, z) -> (z, -x) per
	// step), cached; polygons {tile: 'top' | 'bark', verts}.
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
		var out = m.caps.concat(m.inner).map(function (p) { return conv(p, 'top'); })
			.concat(m.sides.map(function (p) { return conv(p, 'bark'); }));
		meshCache[k] = out;
		return out;
	}

	// One mesh polygon (Luanti coordinates, node units) into a bucket.
	function addPoly(buckets, tex, kind, ox, oy, oz, poly) {
		var bk = buckets.get(tex, kind);
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

	root.Mesh = {FACE_DIRS: FACE_DIRS, SIDE_DIRS: SIDE_DIRS, SIDE_ORDER: SIDE_ORDER, faceTiles: faceTiles,
		Buckets: Buckets, addCuboid: addCuboid, uniform: uniform, addPlant: addPlant,
		quarterPolys: quarterPolys, addPoly: addPoly};
})(typeof window !== 'undefined' ? window : this);
