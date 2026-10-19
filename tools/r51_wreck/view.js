// Round 51 lane WRECK, design step: the three.js side of the wreck page.
//
// Draws a shape file (tools/r51_wreck/shapes) on a sand seabed under a chosen
// depth of water the way the Luanti client meshes it: full cubes with the
// faces against other full cubes culled, the logs' grain by facedir, rooted
// plants as a base cube plus two crossed quads above it (drawPlantlike: the
// quads visual_scale wide and visual_scale * param2 / 16 high, the texture
// tiled once per param2 / 16 with its top at the top). The cuboid texture
// coordinates, the facedir tile table and the crossed quads are copied from
// tools/r47_sw/view.js (which copied them from tools/r46_tree/concept). Luanti's
// z axis points the other way to three.js's, so z is mirrored.
//
// "Luanti light" lights each face with the light of the node it faces, as the
// client does without smooth lighting (content_mapblock.cpp), the light
// spread one level less per node from the sunlit air (voxelalgorithms.cpp),
// through the default light curve (light.cpp set_light_curve with the
// defaults of builtin/settingtypes.txt) and the face shading of
// mesh.cpp applyFacesShading. A rooted extension takes the light of the node
// above its base (drawPlantlikeRootedNode), over its whole height.
/* global THREE, WRECK, WreckNotes */
(function () {
	'use strict';

	// ------------------------------------------------------------ light

	var LUT = (function () {
		var alpha = 0.0, beta = 1.5, boost = 0.2, center = 0.5, sigma = 0.2;
		var a = alpha + beta - 2, b = 3 - 2 * alpha - beta, c = alpha;
		var lut = [0];
		for (var i = 1; i < 15; i++) {
			var x = i / 15;
			var br = ((a * x + b) * x + c) * x + boost * Math.exp(-0.5 * Math.pow((x - center) / sigma, 2));
			br = Math.max(0, Math.min(1, br));
			var v = Math.floor(255 * br);
			if (v <= lut[i - 1]) { v = Math.min(254, lut[i - 1]) + 1; }
			lut.push(v);
		}
		lut.push(255);
		return lut;
	})();
	// face order of a cuboid: top, bottom, right (+x), left (-x), back (+z), front (-z)
	var FACE_DIRS = [[0, 1, 0], [0, -1, 0], [1, 0, 0], [-1, 0, 0], [0, 0, 1], [0, 0, -1]];
	var SHADE = [1.0, 0.447213, 0.670820, 0.670820, 0.836660, 0.836660];

	// mapblock_mesh.cpp getNodeTile rows for facedir 0, 4 and 12: [dir_i] -> tile, rotation
	var DIR_TO_TILE = {
		0: [[0, 0], [2, 0], [0, 0], [4, 0], [0, 0], [5, 0], [1, 0], [3, 0]],
		4: [[0, 0], [2, 3], [5, 0], [0, 2], [0, 0], [1, 0], [4, 2], [3, 1]],
		12: [[0, 0], [0, 3], [3, 3], [4, 1], [0, 0], [5, 3], [2, 3], [1, 3]]
	};
	function faceTiles(tiles, facedir) {
		var out = [];
		for (var f = 0; f < 6; f++) {
			var d = FACE_DIRS[f];
			var e = (DIR_TO_TILE[facedir] || DIR_TO_TILE[0])[(d[0] + 2 * d[1] + 3 * d[2]) & 7];
			out.push({tex: tiles[e[0]], rot: e[1]});
		}
		return out;
	}

	// ------------------------------------------------------------ nodes

	var NODES = {};
	WRECK.nodes.forEach(function (n) { NODES[n.name] = n; });
	var SAND = {name: 'default:sand', drawtype: 'normal', tiles: ['default_sand', 'default_sand', 'default_sand']};
	// six tiles (top, bottom, +x, -x, +z, -z) from a node's [top, bottom, side]
	function sixTiles(n) { var t = n.tiles; return [t[0], t[1], t[2], t[2], t[2], t[2]]; }

	// ------------------------------------------------------------ textures

	var texCache = {};
	function texture(name) {
		if (texCache[name]) { return texCache[name]; }
		var img = new Image();
		var t = new THREE.Texture(img);
		img.onload = function () { t.needsUpdate = true; };
		img.src = WRECK.textures[name];
		t.magFilter = THREE.NearestFilter;
		t.minFilter = THREE.NearestFilter;
		t.generateMipmaps = false;
		t.wrapS = t.wrapT = THREE.RepeatWrapping;
		texCache[name] = t;
		return t;
	}
	var matCache = {};
	function material(name, kind) {
		var k = name + '|' + kind;
		if (matCache[k]) { return matCache[k]; }
		var opts = {map: texture(name), vertexColors: true};
		if (kind === 'cutout') { opts.alphaTest = 0.5; opts.side = THREE.DoubleSide; }
		if (kind === 'water') { opts.transparent = true; opts.opacity = 0.72; opts.depthWrite = false; opts.side = THREE.DoubleSide; }
		if (kind === 'wall') { opts.transparent = true; opts.opacity = 0.45; opts.depthWrite = false; opts.side = THREE.DoubleSide; }
		matCache[k] = new THREE.MeshBasicMaterial(opts);
		return matCache[k];
	}

	// ------------------------------------------------------------ meshing

	function Buckets() { this.map = {}; }
	Buckets.prototype.get = function (tex, kind) {
		var k = tex + '|' + kind;
		if (!this.map[k]) { this.map[k] = {tex: tex, kind: kind, pos: [], col: [], uv: [], idx: []}; }
		return this.map[k];
	};
	Buckets.prototype.build = function (group) {
		var self = this;
		Object.keys(this.map).forEach(function (k) {
			var bk = self.map[k];
			if (!bk.idx.length) { return; }
			var g = new THREE.BufferGeometry();
			g.setAttribute('position', new THREE.Float32BufferAttribute(bk.pos, 3));
			g.setAttribute('color', new THREE.Float32BufferAttribute(bk.col, 3));
			g.setAttribute('uv', new THREE.Float32BufferAttribute(bk.uv, 2));
			g.setIndex(bk.idx);
			var mesh = new THREE.Mesh(g, material(bk.tex, bk.kind));
			if (bk.kind === 'water' || bk.kind === 'wall') { mesh.renderOrder = 2; }
			group.add(mesh);
		});
	};

	// Luanti cuboid faces and texture coordinates for a full node at ox, oy, oz;
	// bright(f) is the face's brightness, skip[f] culls a face.
	function addCube(buckets, ox, oy, oz, tiles, skip, bright) {
		var x1 = -0.5, y1 = -0.5, z1 = -0.5, x2 = 0.5, y2 = 0.5, z2 = 0.5;
		var tx1 = 0, ty1 = 0, tz1 = 0, tx2 = 1, ty2 = 1, tz2 = 1;
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
			if (skip[f]) { continue; }
			var tile = tiles[f];
			var bk = buckets.get(tile.tex, 'solid');
			var base = bk.pos.length / 3;
			var n = FACE_DIRS[f], br = bright(f), pts = [];
			for (var j = 0; j < 4; j++) {
				var v = V[f][j];
				var u = txc[v[3]], w = txc[v[4]], t;
				if (tile.rot === 1) { t = 1 - w; w = u; u = t; }
				else if (tile.rot === 2) { u = 1 - u; w = 1 - w; }
				else if (tile.rot === 3) { t = w; w = 1 - u; u = t; }
				var p = [ox + v[0], oy + v[1], -(oz + v[2])];
				pts.push(p);
				bk.pos.push(p[0], p[1], p[2]);
				bk.col.push(br, br, br);
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

	// A rooted extension above the base at ox, oy, oz: two crossed quads at
	// 46 and -44 degrees, `scale` (visual_scale) wide, scale * height high from
	// the base's top, the texture tiled `height` times with its top at the top.
	function addRooted(buckets, tex, ox, oy, oz, scale, height, br) {
		var bk = buckets.get(tex, 'cutout');
		var h = scale * height, y0 = oy + 0.5;
		[46, -44].forEach(function (deg) {
			var r = deg * Math.PI / 180, s = 0.5 * scale;
			var dx = Math.cos(r) * s, dz = Math.sin(r) * s;
			var base = bk.pos.length / 3;
			var c = [[-dx, y0 + h, -dz, 0, 0], [dx, y0 + h, dz, 1, 0], [dx, y0, dz, 1, height], [-dx, y0, -dz, 0, height]];
			for (var j = 0; j < 4; j++) {
				bk.pos.push(ox + c[j][0], c[j][1], -(oz + c[j][2]));
				bk.col.push(br, br, br);
				bk.uv.push(c[j][3], 1 - c[j][4]);
			}
			bk.idx.push(base, base + 2, base + 1, base, base + 3, base + 2);
		});
	}

	// A flat quad set (the water's surface and its cut walls).
	function addQuad(buckets, tex, kind, pts, uvs, br) {
		var bk = buckets.get(tex, kind);
		var base = bk.pos.length / 3;
		for (var j = 0; j < 4; j++) {
			bk.pos.push(pts[j][0], pts[j][1], -pts[j][2]);
			bk.col.push(br[0], br[1], br[2]);
			bk.uv.push(uvs[j][0], uvs[j][1]);
		}
		bk.idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
	}

	// ------------------------------------------------------------ the world

	function hash(x, z, salt) {
		var h = (x * 374761393 + z * 668265263 + salt * 2246822519) | 0;
		h = Math.imul(h ^ (h >>> 13), 1274126177);
		return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
	}

	// The shape's cells in node coordinates: the layer `seabed` at y = 0 (the
	// first node above the sand), the shape centred on x and z.
	function decode(shape) {
		var cells = [], sx = shape.size.x, sz = shape.size.z;
		var ox = -Math.floor(sx / 2), oz = -Math.floor(sz / 2);
		shape.layers.forEach(function (rows, ly) {
			rows.forEach(function (row, z) {
				for (var x = 0; x < row.length; x++) {
					var ch = row.charAt(x);
					if (ch === '.') { continue; }
					var p = shape.palette[ch];
					cells.push({ch: ch, node: NODES[p.name], param2: p.param2, x: x + ox, y: ly - shape.seabed, z: z + oz});
				}
			});
		});
		return cells;
	}

	// param2 of a mast cell under the page's mast rule (stumps keep theirs)
	function mastParam2(cell, depth) {
		if (cell.ch !== 'M' || state.mastRule !== 'depth') { return cell.param2; }
		var h = (depth - 0.5 + 2) - (cell.y + 0.5);
		return Math.max(16, Math.min(255, Math.round(16 * h / state.mastScale)));
	}
	function extension(cell, depth) {
		var n = cell.node;
		if (n.drawtype !== 'plantlike_rooted') { return null; }
		var scale = n.name === MAST ? state.mastScale : 1;
		var height = n.paramtype2 === 'leveled' ? mastParam2(cell, depth) / 16 : 1;
		return {scale: scale, height: height, top: cell.y + 0.5 + scale * height};
	}
	var MAST = 'grug_nodes:wreck_mast';

	function buildWorld(shape, depth, group) {
		var cells = decode(shape);
		var minX = 0, maxX = 0, minZ = 0, maxZ = 0, maxY = 0;
		cells.forEach(function (c) {
			minX = Math.min(minX, c.x); maxX = Math.max(maxX, c.x);
			minZ = Math.min(minZ, c.z); maxZ = Math.max(maxZ, c.z);
			maxY = Math.max(maxY, c.y);
		});
		var M = 9;
		var X0 = minX - M, X1 = maxX + M, Z0 = minZ - M, Z1 = maxZ + M, Y0 = -3, Y1 = Math.max(depth, maxY + 1) + 2;
		var NX = X1 - X0 + 1, NY = Y1 - Y0 + 1, NZ = Z1 - Z0 + 1;
		function idx(x, y, z) { return ((x - X0) * NY + (y - Y0)) * NZ + (z - Z0); }
		function inside(x, y, z) { return x >= X0 && x <= X1 && y >= Y0 && y <= Y1 && z >= Z0 && z <= Z1; }
		// kinds: 0 air, 1 water, 2 sand, 3 wreck
		var kind = new Uint8Array(NX * NY * NZ), light = new Uint8Array(NX * NY * NZ);
		var x, y, z;
		for (x = X0; x <= X1; x++) {
			for (y = Y0; y <= Y1; y++) {
				for (z = Z0; z <= Z1; z++) { kind[idx(x, y, z)] = y < 0 ? 2 : (y < depth ? 1 : 0); }
			}
		}
		var at = {};
		cells.forEach(function (c) { kind[idx(c.x, c.y, c.z)] = 3; at[c.x + ',' + c.y + ',' + c.z] = c; });
		// light: sunlight down through air, then one level less per node
		var queue = [];
		for (var l = 0; l <= 15; l++) { queue.push([]); }
		for (x = X0; x <= X1; x++) {
			for (z = Z0; z <= Z1; z++) {
				for (y = Y1; y >= Y0 && kind[idx(x, y, z)] === 0; y--) {
					light[idx(x, y, z)] = 15;
					queue[15].push(idx(x, y, z));
				}
			}
		}
		var strideX = NY * NZ, strideY = NZ;
		for (l = 15; l > 1; l--) {
			var q = queue[l];
			for (var qi = 0; qi < q.length; qi++) {
				var i = q[qi];
				if (light[i] !== l) { continue; }
				var ix = Math.floor(i / strideX), iy = Math.floor((i % strideX) / strideY), iz = i % strideY;
				var nb = [[ix + 1, iy, iz], [ix - 1, iy, iz], [ix, iy + 1, iz], [ix, iy - 1, iz], [ix, iy, iz + 1], [ix, iy, iz - 1]];
				for (var k = 0; k < 6; k++) {
					var a = nb[k];
					if (a[0] < 0 || a[0] >= NX || a[1] < 0 || a[1] >= NY || a[2] < 0 || a[2] >= NZ) { continue; }
					var j = a[0] * strideX + a[1] * strideY + a[2];
					if (kind[j] >= 2 || light[j] >= l - 1) { continue; }
					light[j] = l - 1;
					queue[l - 1].push(j);
				}
			}
		}
		function lightAt(x, y, z) {
			if (!inside(x, y, z)) { return y >= depth ? 15 : Math.max(0, 15 - (depth - y)); }
			return light[idx(x, y, z)];
		}
		function opaque(x, y, z) {
			if (!inside(x, y, z)) { return y < Y0; }
			return kind[idx(x, y, z)] >= 2;
		}
		function bright(lv, f) { return (state.light ? LUT[lv] / 255 : 1) * SHADE[f]; }

		var solid = new Buckets(), plants = new Buckets(), water = new Buckets();
		function cube(x, y, z, tiles) {
			addCube(solid, x, y, z, tiles, FACE_DIRS.map(function (d) { return opaque(x + d[0], y + d[1], z + d[2]); }),
				function (f) { var d = FACE_DIRS[f]; return bright(lightAt(x + d[0], y + d[1], z + d[2]), f); });
		}
		// sand, and seagrass on it (context: lane TERRAIN's node)
		var sandTiles = faceTiles(sixTiles(SAND), 0);
		for (x = X0; x <= X1; x++) {
			for (z = Z0; z <= Z1; z++) {
				for (y = Y0; y < 0; y++) {
					if (kind[idx(x, y, z)] === 2) { cube(x, y, z, sandTiles); }
				}
				if (state.seagrass && depth >= 2 && kind[idx(x, 0, z)] === 1 && kind[idx(x, -1, z)] === 2) {
					var patch = hash(Math.floor(x / 5), Math.floor(z / 5), 3);
					var r = hash(x, z, 7);
					if (r < patch * 0.55 - 0.08) {
						var g = 1 + Math.floor(hash(x, z, 11) * 3);
						addRooted(plants, 'seagrass_' + g, x, -1, z, 1, 1, state.light ? LUT[lightAt(x, 0, z)] / 255 : 1);
					}
				}
			}
		}
		// the wreck
		var stats = {masts: []};
		cells.forEach(function (c) {
			var facedir = c.node.paramtype2 === 'facedir' ? c.param2 : 0;
			cube(c.x, c.y, c.z, faceTiles(sixTiles(c.node), facedir));
			var ext = extension(c, depth);
			if (ext) {
				addRooted(plants, c.node.special, c.x, c.y, c.z, ext.scale, ext.height,
					state.light ? LUT[lightAt(c.x, c.y + 1, c.z)] / 255 : 1);
				if (c.node.name === MAST) {
					stats.masts.push({cell: c, ext: ext, param2: mastParam2(c, depth), light: lightAt(c.x, c.y + 1, c.z)});
				}
			}
		});
		// water: the surface and the cut through the volume at the edge
		if (depth > 0 && state.water) {
			var s = depth - 0.5, xa = X0 - 0.5, xb = X1 + 0.5, za = Z0 - 0.5, zb = Z1 + 0.5;
			var top = state.light ? LUT[14] / 255 : 1;
			addQuad(water, 'default_water', 'water', [[xa, s, za], [xb, s, za], [xb, s, zb], [xa, s, zb]],
				[[0, 0], [NX, 0], [NX, NZ], [0, NZ]], [top, top, top]);
			var wall = [0.55, 0.75, 0.95];
			var b0 = -0.5;
			[[[xa, b0, za], [xb, b0, za], [xb, s, za], [xa, s, za], NX], [[xa, b0, zb], [xb, b0, zb], [xb, s, zb], [xa, s, zb], NX],
				[[xa, b0, za], [xa, b0, zb], [xa, s, zb], [xa, s, za], NZ], [[xb, b0, za], [xb, b0, zb], [xb, s, zb], [xb, s, za], NZ]]
				.forEach(function (w) {
					addQuad(water, 'default_water', 'wall', w.slice(0, 4), [[0, 0], [w[4], 0], [w[4], depth], [0, depth]], wall);
				});
		}
		solid.build(group);
		plants.build(group);
		water.build(group);
		stats.box = {minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, maxY: maxY, X0: X0, X1: X1, Z0: Z0, Z1: Z1};
		stats.lightAt = lightAt;
		stats.cells = cells;
		return stats;
	}

	// A 2-node player for scale (the classic 64 x 32 skin layout), from r47_sw.
	function playerFigure(br) {
		var group = new THREE.Group();
		var mat = new THREE.MeshBasicMaterial({map: texture('character'), alphaTest: 0.5, color: new THREE.Color(br, br, br)});
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

	// ------------------------------------------------------------ scene

	var view = document.getElementById('view');
	var renderer = new THREE.WebGLRenderer({antialias: true, preserveDrawingBuffer: true});
	renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
	view.insertBefore(renderer.domElement, view.firstChild);
	var scene = new THREE.Scene();
	scene.background = new THREE.Color(0x9ec3d6);
	var persp = new THREE.PerspectiveCamera(55, 1, 0.1, 800);
	var ortho = new THREE.OrthographicCamera(-30, 30, 30, -30, 0.1, 400);
	ortho.up.set(0, 0, -1);
	var orbit = new THREE.OrbitControls(persp, renderer.domElement);
	orbit.enableDamping = true;
	var topControls = new THREE.OrbitControls(ortho, renderer.domElement);
	topControls.enableRotate = false;
	topControls.screenSpacePanning = true;
	var content = new THREE.Group();
	scene.add(content);

	// ------------------------------------------------------------ state

	var params = new URLSearchParams(location.search);
	var stored = {};
	try { stored = JSON.parse(localStorage.getItem('r51-wreck-view') || '{}') || {}; } catch (e) { stored = {}; }
	function pick(name, ok, fallback) {
		var v = params.get(name);
		if (v !== null && ok(v)) { return v; }
		if (stored[name] !== undefined && ok(String(stored[name]))) { return String(stored[name]); }
		return fallback;
	}
	var SHAPES = WRECK.shapes;
	var shapeNames = SHAPES.map(function (s) { return s.key.split('.')[1]; });
	function isDepth(v) { var n = parseInt(v, 10); return n >= 3 && n <= 26; }
	var state = {
		shape: pick('shape', function (v) { return shapeNames.indexOf(v) >= 0; }, 'hull'),
		depth: parseInt(pick('depth', isDepth, '14'), 10),
		view: pick('view', function (v) { return v === 'orbit' || v === 'top' || v === 'swim'; }, 'orbit'),
		light: pick('light', function (v) { return v === '0' || v === '1'; }, '1') === '1',
		seagrass: params.get('seagrass') !== '0',
		figure: params.get('figure') !== '0',
		water: params.get('water') !== '0',
		mastRule: params.get('mast') === 'depth' ? 'depth' : 'fixed',
		mastScale: parseFloat(params.get('scale')) === 1.5 || parseFloat(params.get('scale')) === 2 ? parseFloat(params.get('scale')) : 1
	};
	if (params.get('bare') === '1') {
		document.querySelector('.wk-header').style.display = 'none';
		document.querySelector('.wk-aside').style.display = 'none';
		view.style.height = '100vh';
	}
	function remember() {
		try {
			localStorage.setItem('r51-wreck-view', JSON.stringify({shape: state.shape, depth: state.depth,
				view: state.view, light: state.light ? 1 : 0}));
		} catch (e) { /* a convenience only */ }
	}
	function currentShape() { return SHAPES[shapeNames.indexOf(state.shape)]; }

	var last = null;
	function build() {
		content.children.slice().forEach(function (c) {
			content.remove(c);
			c.traverse(function (o) { if (o.geometry) { o.geometry.dispose(); } });
		});
		var shape = currentShape();
		last = buildWorld(shape, state.depth, content);
		if (state.figure) {
			var b = last.box;
			var fx = b.minX - 3, fz = b.maxZ + 2;
			var fig = playerFigure(state.light ? LUT[last.lightAt(fx, 0, fz)] / 255 : 1);
			fig.position.set(fx, -0.5, -fz);
			content.add(fig);
		}
		frame();
		readout(shape);
		document.getElementById('tag').textContent = shape.title + ' · ' + state.depth + ' nodes of water' +
			(state.light ? ' · Luanti light (day)' : ' · even light');
	}

	function frame() {
		var b = last.box;
		var cx = (b.minX + b.maxX) / 2, cz = -(b.minZ + b.maxZ) / 2;
		var size = Math.max(b.maxX - b.minX, b.maxZ - b.minZ) + 1;
		var cy = Math.min(b.maxY, 6) / 2;
		if (state.view === 'swim') {
			var eye = Math.min(state.depth - 1.5, 3.2);
			persp.position.set(cx - size * 0.25, eye, cz - (b.maxZ - b.minZ) / 2 - size * 0.55 - 4);
			orbit.target.set(cx, Math.min(eye, 2.5), cz);
		} else {
			var dist = (size * 0.95 + 6) / Math.min(1, Math.pow(persp.aspect || 1, 0.8));
			var yaw = 35 * Math.PI / 180, pitch = 32 * Math.PI / 180;
			persp.position.set(cx + Math.sin(yaw) * Math.cos(pitch) * dist, cy + Math.sin(pitch) * dist,
				cz + Math.cos(yaw) * Math.cos(pitch) * dist);
			orbit.target.set(cx, cy, cz);
		}
		orbit.update();
		topControls.target.set(cx, 0, cz);
		ortho.position.set(cx, 120, cz);
		ortho.lookAt(cx, 0, cz);
		ortho.zoom = 1;
		topControls.update();
		fitOrtho();
		orbit.enabled = state.view !== 'top';
		topControls.enabled = state.view === 'top';
	}
	function fitOrtho() {
		if (!last) { return; }
		var b = last.box;
		var half = Math.max(b.maxX - b.minX, b.maxZ - b.minZ) / 2 + 5;
		var w = view.clientWidth || 1, h = view.clientHeight || 1, a = w / h;
		if (a >= 1) { ortho.left = -half * a; ortho.right = half * a; ortho.top = half; ortho.bottom = -half; }
		else { ortho.left = -half; ortho.right = half; ortho.top = half / a; ortho.bottom = -half / a; }
		ortho.updateProjectionMatrix();
	}

	// ------------------------------------------------------------ readout

	function el(tag, cls, text) {
		var e = document.createElement(tag);
		if (cls) { e.className = cls; }
		if (text !== undefined) { e.textContent = text; }
		return e;
	}
	function keyTag(key) { return el('span', 'wk-key', key); }
	function pct(lv) { return Math.round(LUT[Math.max(0, Math.min(15, lv))] / 2.55) + ' %'; }
	function reachDepth(top) { return Math.ceil(top + 0.5) - 1; }
	var MAST_NAMES = {M: 'main mast', m: 'foremast stump', k: 'foremast stump', n: 'main mast stump'};

	function readout(shape) {
		var box = document.getElementById('reach');
		box.textContent = '';
		var s = shape.size;
		var p = el('p', 'wk-meta', s.x + ' long × ' + s.z + ' wide × ' + s.y + ' high nodes, ' + shape.seabed +
			(shape.seabed === 1 ? ' layer' : ' layers') + ' in the sand; ' + last.cells.length + ' blocks.');
		box.appendChild(p);
		if (s.x > 16 || s.z > 16) {
			box.appendChild(el('p', 'wk-warn', 'Longer than 16 nodes: the mapgen templates take at most 16 × 64 × 16 today (r6_templates.lua read_source); the build step raises that bound for wrecks or this shape gets shorter (DESIGN.md, Questions).'));
		}
		var masts = lastMasts();
		if (!masts.length) {
			box.appendChild(el('p', 'wk-note', 'No mast: the debris field lies flat (its mast is the fallen log row).'));
			return;
		}
		var t = el('table');
		t.innerHTML = '<thead><tr><th>mast</th><th>param2</th><th>long</th><th>top over sand</th><th>here</th><th>reaches the surface</th></tr></thead>';
		var tb = el('tbody');
		masts.forEach(function (m) {
			var tr = el('tr');
			var top = m.ext.top + 0.5;      // over the sand's top (y = -0.5)
			var over = m.ext.top - (state.depth - 0.5);
			[MAST_NAMES[m.cell.ch] || 'mast', String(m.param2), (m.ext.scale * m.ext.height).toFixed(1),
				top.toFixed(1), over > 0 ? over.toFixed(1) + ' above the water' : (-over).toFixed(1) + ' below the surface',
				'at depths up to ' + reachDepth(m.ext.top)].forEach(function (v) { tr.appendChild(el('td', '', v)); });
			tb.appendChild(tr);
		});
		t.appendChild(tb);
		var wrap = el('div', 'wk-tablewrap');
		wrap.appendChild(t);
		box.appendChild(wrap);
		var main = masts[0];
		box.appendChild(el('p', 'wk-note', 'Light here: the sand ' + pct(15 - state.depth) + ', the deck at the mast ' +
			pct(main.light) + ' (light ' + main.light + '), so the whole mast is drawn at ' + pct(main.light) +
			', also where it stands in the air.'));
	}
	function lastMasts() {
		var out = [];
		last.cells.forEach(function (c) {
			if (c.node.name === MAST) {
				out.push({cell: c, ext: extension(c, state.depth), param2: mastParam2(c, state.depth),
					light: last.lightAt(c.x, c.y + 1, c.z)});
			}
		});
		out.sort(function (a, b) { return b.ext.top - a.ext.top; });
		return out;
	}

	// The band table: every shape's tallest mast at visual_scale 1, 1.5 and 2,
	// and the light of sand and deck at 8, 14 and 20 nodes of water.
	function bandTable() {
		var box = document.getElementById('band');
		var t = el('table');
		t.innerHTML = '<thead><tr><th>shape</th><th>mast</th><th>deck over sand</th><th colspan="3">reaches the surface at depths up to (visual_scale 1 / 1.5 / 2)</th></tr></thead>';
		var tb = el('tbody');
		SHAPES.forEach(function (shape) {
			var masts = decode(shape).filter(function (c) { return c.node.name === MAST; });
			masts.sort(function (a, b) { return b.param2 - a.param2; });
			if (!masts.length) { return; }
			var c = masts[0], h = c.param2 / 16;
			var tr = el('tr');
			[shape.title, (MAST_NAMES[c.ch] || 'mast') + ', ' + h.toFixed(1), String(c.y + 1)].forEach(function (v) {
				tr.appendChild(el('td', '', v));
			});
			[1, 1.5, 2].forEach(function (sc) { tr.appendChild(el('td', '', String(reachDepth(c.y + 0.5 + sc * h)))); });
			tb.appendChild(tr);
		});
		t.appendChild(tb);
		var wrap = el('div', 'wk-tablewrap');
		wrap.appendChild(t);
		box.appendChild(wrap);
		var lt = el('table');
		lt.innerHTML = '<thead><tr><th>water depth</th><th>sand</th><th>the whole hull\'s deck at the mast (3 over the sand)</th></tr></thead>';
		var lb = el('tbody');
		[6, 8, 10, 12, 14, 17, 20].forEach(function (d) {
			var tr = el('tr');
			[String(d), 'light ' + Math.max(0, 15 - d) + ' · ' + pct(15 - d),
				'light ' + Math.max(0, 15 - d + 3) + ' · ' + pct(15 - d + 3)].forEach(function (v) { tr.appendChild(el('td', '', v)); });
			lb.appendChild(tr);
		});
		lt.appendChild(lb);
		var wrap2 = el('div', 'wk-tablewrap');
		wrap2.appendChild(lt);
		box.appendChild(el('p', 'wk-note', 'Daylight under water, by day, open water above (Luanti: one level less per node; brightness by the default light curve):'));
		box.appendChild(wrap2);
		box.appendChild(el('p', '', 'The band the design needs: a seabed 8 to 14 nodes deep (bow 6, debris 4 and deeper), 8 to 12 at its best. ' +
			'At 8 the whole hull (8 nodes over the sand) is just under the surface; below about 12 the sand is nearly black and the wreck hard to see. ' +
			'The main mast (15.9 nodes on a deck 3 over the sand) reaches the surface down to 18, so across the band it always stands ' +
			'5 to 11 nodes into the air; the stumps of the bow and stern stay under water.'));
	}

	function legend() {
		var box = document.getElementById('legend');
		var all = [];
		WRECK.nodes.forEach(function (n) { all.push(n); });
		all.forEach(function (n) {
			var item = el('div', 'wk-item');
			var head = el('div', 'wk-item-head');
			var thumbs = el('span', 'wk-thumbs');
			var seen = {};
			n.tiles.concat(n.special ? [n.special] : []).forEach(function (tx) {
				if (seen[tx]) { return; }
				seen[tx] = true;
				var img = el('img');
				img.src = WRECK.textures[tx];
				img.alt = '';
				img.title = tx + '.png';
				thumbs.appendChild(img);
			});
			head.appendChild(thumbs);
			head.appendChild(el('b', '', n.description));
			head.appendChild(keyTag(n.key));
			item.appendChild(head);
			item.appendChild(el('div', 'wk-meta', n.name + ' · ' + n.drawtype +
				(n.paramtype2 !== 'none' ? ', paramtype2 ' + n.paramtype2 : '') +
				(n.drawtype === 'plantlike_rooted' ? ', waving ' + n.waving : '') +
				' · drops ' + n.drop + (n.new ? ' · new node' : ' · exists')));
			item.appendChild(el('div', 'wk-meta', n.use + '.'));
			WreckNotes.attach(item, n.key);
			box.appendChild(item);
		});
		var ctx = el('div', 'wk-item');
		var h2 = el('div', 'wk-item-head');
		var th = el('span', 'wk-thumbs');
		['default_sand', 'seagrass_1', 'seagrass_2', 'seagrass_3'].forEach(function (tx) {
			var img = el('img');
			img.src = WRECK.textures[tx];
			img.alt = '';
			img.title = tx + '.png';
			th.appendChild(img);
		});
		h2.appendChild(th);
		h2.appendChild(el('b', '', 'Context: sand and seagrass'));
		ctx.appendChild(h2);
		ctx.appendChild(el('div', 'wk-meta', 'default:sand (exists); seagrass is lane TERRAIN\'s node with ARTS\'s three textures (picked on the ARTS page), drawn here in loose patches for context only.'));
		box.appendChild(ctx);
	}

	function shapeNote() {
		var box = document.getElementById('shape-note');
		SHAPES.forEach(function (shape) {
			var item = el('div', 'wk-item');
			item.dataset.shape = shape.key.split('.')[1];
			var head = el('div', 'wk-item-head');
			head.appendChild(el('b', '', shape.title));
			head.appendChild(keyTag(shape.key));
			item.appendChild(head);
			item.appendChild(el('div', 'wk-meta', shape.note));
			WreckNotes.attach(item, shape.key);
			box.appendChild(item);
		});
	}
	function showShapeNote() {
		Array.prototype.forEach.call(document.querySelectorAll('#shape-note .wk-item'), function (it) {
			it.style.display = it.dataset.shape === state.shape ? '' : 'none';
		});
	}

	function mastQuestion() {
		var box = document.getElementById('mast-question');
		var item = el('div', 'wk-item');
		var head = el('div', 'wk-item-head');
		head.appendChild(el('b', '', 'How high the main mast stands'));
		head.appendChild(keyTag('wreck.mast_height'));
		item.appendChild(head);
		var ul = el('ul');
		['As in the file: 15.9 nodes (param2 255, the most leveled allows), at every depth the same.',
			'visual_scale 1.5 or 2: the engine scales the crossed quads in width and height, so the same param2 gives 23.9 or 31.9 nodes; the pole is drawn 1.5 or 2 times thicker.',
			'“2 nodes above the water”: the build step sets the mast\'s param2 from the depth at placement, so a mast pokes 2 nodes out of the water wherever it can reach (header: mast).'].forEach(function (t) {
			ul.appendChild(el('li', '', t));
		});
		item.appendChild(ul);
		WreckNotes.attach(item, 'wreck.mast_height');
		box.appendChild(item);
	}

	// ------------------------------------------------------------ ui

	function syncUi() {
		Array.prototype.forEach.call(document.querySelectorAll('[data-shape-btn]'), function (b) {
			b.setAttribute('aria-pressed', b.dataset.shapeBtn === state.shape ? 'true' : 'false');
		});
		Array.prototype.forEach.call(document.querySelectorAll('[data-depth]'), function (b) {
			b.setAttribute('aria-pressed', parseInt(b.dataset.depth, 10) === state.depth ? 'true' : 'false');
		});
		Array.prototype.forEach.call(document.querySelectorAll('[data-view]'), function (b) {
			b.setAttribute('aria-pressed', b.dataset.view === state.view ? 'true' : 'false');
		});
		document.getElementById('depth').value = state.depth;
		document.getElementById('depth-value').textContent = state.depth + ' nodes';
		document.getElementById('light').checked = state.light;
		document.getElementById('seagrass').checked = state.seagrass;
		document.getElementById('figure').checked = state.figure;
		document.getElementById('water').checked = state.water;
		document.getElementById('mast-rule').value = state.mastRule;
		document.getElementById('mast-scale').value = String(state.mastScale);
		showShapeNote();
	}
	function change(fn) { return function (e) { fn(e); syncUi(); remember(); build(); }; }

	var bar = document.getElementById('shape-buttons');
	SHAPES.forEach(function (shape, i) {
		var b = el('button', '', shape.title);
		b.type = 'button';
		b.id = 'shape-' + shapeNames[i];
		b.dataset.shapeBtn = shapeNames[i];
		b.onclick = change(function () { state.shape = shapeNames[i]; });
		bar.appendChild(b);
	});
	Array.prototype.forEach.call(document.querySelectorAll('[data-depth]'), function (b) {
		b.onclick = change(function () { state.depth = parseInt(b.dataset.depth, 10); });
	});
	document.getElementById('depth').oninput = change(function (e) { state.depth = parseInt(e.target.value, 10); });
	Array.prototype.forEach.call(document.querySelectorAll('[data-view]'), function (b) {
		b.onclick = change(function () { state.view = b.dataset.view; });
	});
	document.getElementById('light').onchange = change(function (e) { state.light = e.target.checked; });
	document.getElementById('seagrass').onchange = change(function (e) { state.seagrass = e.target.checked; });
	document.getElementById('figure').onchange = change(function (e) { state.figure = e.target.checked; });
	document.getElementById('water').onchange = change(function (e) { state.water = e.target.checked; });
	document.getElementById('mast-rule').onchange = change(function (e) { state.mastRule = e.target.value; });
	document.getElementById('mast-scale').onchange = change(function (e) { state.mastScale = parseFloat(e.target.value); });

	function resize() {
		var w = view.clientWidth, h = view.clientHeight;
		renderer.setSize(w, h);
		persp.aspect = w / h;
		persp.updateProjectionMatrix();
		fitOrtho();
	}
	if (window.ResizeObserver) { new ResizeObserver(resize).observe(view); } else { window.addEventListener('resize', resize); }

	var under = document.getElementById('under');
	function loop() {
		requestAnimationFrame(loop);
		if (state.view === 'top') { topControls.update(); } else { orbit.update(); }
		under.style.display = state.view !== 'top' && state.water && persp.position.y < state.depth - 0.5 ? 'block' : 'none';
		renderer.render(scene, state.view === 'top' ? ortho : persp);
	}

	shapeNote();
	legend();
	mastQuestion();
	bandTable();
	resize();
	syncUi();
	build();
	loop();
	WreckNotes.start();
	window.__wreckReady = true;
})();
