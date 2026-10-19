// Round 51 lane VIEW: the three.js side and the controls of the land viewer.
//
// Draws a LandGen patch, kit or plant row the way the Luanti client meshes
// its nodes (mesh.js): ground cubes with faces against other ground culled,
// world-aligned 32 px tiles over 2 x 2 nodes on every solid face, plantlike
// nodes per node, liquid sources with their top at the node border, node
// boxes (props, fences, walls, the snow layer, carpets), and the trees of
// the tree concept (log cubes, quarter meshes, connected node boxes,
// leaves, fruit, hanging moss). Textures are Luanti texture strings
// (images joined by "^", "^[colorize:#rrggbb:ratio", "^[transformFY")
// composed on a canvas; tools/r51_land art is named by its folder
// ("grounds/sand_32" plus the extension). build.py inlines every texture
// these files name.
//
// Notes (the user's verdicts) follow the storage contract of the
// orchestration brief: claude.use("db"), collection "notes", one document
// per item key; read-only without it. localStorage only remembers the zone
// and mode.
/* global THREE, TreeShapes, LandGen, Mesh, TEXTURES */
(function () {
	'use strict';

	var BOXES = TreeShapes.BOXES, CONNECTS = TreeShapes.CONNECTS;
	var FACE_DIRS = Mesh.FACE_DIRS, SIDE_DIRS = Mesh.SIDE_DIRS, SIDE_ORDER = Mesh.SIDE_ORDER;
	var faceTiles = Mesh.faceTiles, addCuboid = Mesh.addCuboid, addPlant = Mesh.addPlant;
	var L = LandGen;

	// ----------------------------------------------------------- textures

	var images = {};
	function imageKey(token) { return token.replace(/\.png$/, ''); }
	function preload(done) {
		var keys = Object.keys(TEXTURES), left = keys.length;
		keys.forEach(function (k) {
			var im = new Image();
			im.onload = im.onerror = function () { left = left - 1; if (!left) { done(); } };
			im.src = TEXTURES[k];
			images[k] = im;
		});
	}

	// The size of a composed texture: the widest square of its images.
	function texSize(str) {
		var size = 16;
		str.split('^').forEach(function (t) {
			var im = t.charAt(0) !== '[' ? images[imageKey(t)] : null;
			if (im && im.naturalWidth) { size = Math.max(size, im.naturalWidth); }
		});
		return size;
	}
	// world-aligned tiles per texture side (1, 2 or 4)
	function texScale(str) { return Math.max(1, Math.round(texSize(str) / 16)); }

	var texCache = {};
	function texture(str) {
		if (texCache[str]) { return texCache[str]; }
		var size = texSize(str);
		var canvas = document.createElement('canvas');
		canvas.width = size; canvas.height = size;
		var g = canvas.getContext('2d');
		g.imageSmoothingEnabled = false;
		str.split('^').forEach(function (t) {
			if (t.charAt(0) !== '[') {
				var im = images[imageKey(t)];
				// the top square (an animated strip shows its first frame)
				if (im && im.naturalWidth) { g.drawImage(im, 0, 0, im.naturalWidth, im.naturalWidth, 0, 0, size, size); }
				return;
			}
			var d = g.getImageData(0, 0, size, size), p = d.data, k;
			var m = /^\[colorize:#([0-9a-fA-F]{6}):(\d+)$/.exec(t);
			if (m) {
				var c = parseInt(m[1], 16), a = parseInt(m[2], 10) / 255;
				for (k = 0; k < p.length; k += 4) {
					p[k] = Math.round(p[k] * (1 - a) + (c >> 16) * a);
					p[k + 1] = Math.round(p[k + 1] * (1 - a) + ((c >> 8) & 255) * a);
					p[k + 2] = Math.round(p[k + 2] * (1 - a) + (c & 255) * a);
				}
			} else if (t === '[transformFY') {
				var q = new Uint8ClampedArray(p), row = size * 4;
				for (var y = 0; y < size; y++) {
					for (k = 0; k < row; k++) { p[y * row + k] = q[(size - 1 - y) * row + k]; }
				}
			}
			g.putImageData(d, 0, 0);
		});
		var t = new THREE.CanvasTexture(canvas);
		t.magFilter = THREE.NearestFilter;
		t.minFilter = THREE.NearestFilter;
		t.generateMipmaps = false;
		t.wrapS = t.wrapT = THREE.RepeatWrapping;
		t.encoding = THREE.sRGBEncoding;
		texCache[str] = t;
		return t;
	}
	function dataUrl(str) { texture(str); return texCache[str].image.toDataURL(); }

	var matCache = {};
	function material(str, kind) {
		var k = str + '|' + kind;
		if (matCache[k]) { return matCache[k]; }
		var opts = {map: texture(str)};
		if (kind === 'cutout' || kind === 'leaves' || kind === 'clip') {
			opts.alphaTest = 0.5;
			opts.side = kind === 'cutout' ? THREE.DoubleSide : THREE.FrontSide;
		}
		if (kind === 'water') {
			opts.transparent = true;
			opts.opacity = 0.72;
			opts.depthWrite = false;
		}
		var m = new THREE.MeshLambertMaterial(opts);
		if (opts.alphaTest) {
			m.userData.depth = new THREE.MeshDepthMaterial({depthPacking: THREE.RGBADepthPacking, map: opts.map, alphaTest: 0.5});
		}
		matCache[k] = m;
		return m;
	}

	function Buckets() { Mesh.Buckets.call(this, function (t) { return t; }, texScale); }
	Buckets.prototype = Object.create(Mesh.Buckets.prototype);
	Buckets.prototype.build = function (group, layer) { Mesh.Buckets.prototype.build.call(this, group, layer, material); };

	// ------------------------------------------------------ tiles per node

	function six(tiles) {
		var out = [];
		for (var i = 0; i < 6; i++) { out.push(tiles[Math.min(i, tiles.length - 1)]); }
		return out;
	}
	// A node's six tiles (+Y, -Y, +X, -X, +Z, -Z) on one side of the view:
	// the proposal's texture items and the lab apply to the proposal side.
	function tilesOf(name, proposal) {
		var def = L.def(name);
		var t = six(def ? def.tiles : ['default_stone.png']);
		if (!proposal) { return t; }
		L.ITEMS.forEach(function (it) {
			if (it.tex && it.tex[name] && state.on[it.key] !== false) { t = six(it.tex[name]); }
		});
		var lab = state.lab[name];
		if (lab) {
			if (lab.top) { t[0] = lab.top; }
			if (lab.side) { t[2] = t[3] = t[4] = t[5] = lab.side; }
			if (lab.all) { t = six([lab.all]); }
		}
		return t;
	}
	// the Luanti face order of mesh.js (top, bottom, right, left, back, front)
	// is the tile order; faceTiles turns the grain of a log
	function tileList(name, proposal, rot) { return faceTiles(tilesOf(name, proposal), rot || 0); }

	// A node box turned by facedir 0..3 round +Y ((x, z) -> (z, -x) per
	// step); its side tiles move with it.
	function turnBox(b, rot) {
		var x1 = b[0], z1 = b[2], x2 = b[3], z2 = b[5];
		for (var i = 0; i < rot; i++) {
			var nx1 = z1, nx2 = z2, nz1 = -x2, nz2 = -x1;
			x1 = nx1; x2 = nx2; z1 = nz1; z2 = nz2;
		}
		return [x1, b[1], z1, x2, b[4], z2];
	}
	function turnTiles(t, rot) {
		// sides in mesh order: right (+X), left (-X), back (+Z), front (-Z)
		var out = t.slice();
		for (var i = 0; i < rot; i++) {
			var r = out[2], l = out[3], bk = out[4], f = out[5];
			// a quarter turn takes +Z to +X: what faced back now faces right
			out[2] = {tex: bk.tex, rot: 0}; out[5] = {tex: r.tex, rot: 0}; out[3] = {tex: f.tex, rot: 0}; out[4] = {tex: l.tex, rot: 0};
			out[0] = {tex: out[0].tex, rot: (out[0].rot + 1) % 4};
		}
		return out;
	}

	// ----------------------------------------------------------- the world

	var FENCE_POST = [-2, -8, -2, 2, 8, 2];
	var FENCE_RAILS = {front: [[-1, 3, -8, 1, 5, -2], [-1, -5, -8, 1, -3, -2]], back: [[-1, 3, 2, 1, 5, 8], [-1, -5, 2, 1, -3, 8]],
		left: [[-8, 3, -1, -2, 5, 1], [-8, -5, -1, -2, -3, 1]], right: [[2, 3, -1, 8, 5, 1], [2, -5, -1, 8, -3, 1]]};
	var WALL_POST = [-4, -8, -4, 4, 8, 4];
	var WALL_ARMS = {front: [[-3, -8, -8, 3, 6, -4]], back: [[-3, -8, 4, 3, 6, 8]], left: [[-8, -8, -3, -4, 6, 3]],
		right: [[4, -8, -3, 8, 6, 3]]};

	// p: a LandGen patch; ox: its x offset in the scene; proposal: whether
	// it takes the proposal's textures.
	function buildPatch(p, groups, ox, proposal) {
		var off = -p.size / 2;
		var gb = new Buckets(), wb = new Buckets(), pb = new Buckets(), sb = new Buckets();
		var x, z, y;
		var minH = 99;
		p.cols.forEach(function (row) { row.forEach(function (c) { if (!c.void) { minH = Math.min(minH, c.h); } }); });
		var floor = Math.min(-3, minH - 2);
		function column(cx, cz) {
			if (cx < 0 || cz < 0 || cx >= p.size || cz >= p.size) { return null; }
			var c = p.cols[cx][cz];
			return c.void ? null : c;
		}
		function groundTop(cx, cz) { var c = column(cx, cz); return c ? c.h : floor - 1; }
		var nodeAt = {};
		p.nodes.forEach(function (n) { nodeAt[n.x + ',' + n.y + ',' + n.z] = n; });
		for (x = 0; x < p.size; x++) {
			for (z = 0; z < p.size; z++) {
				var c = column(x, z);
				if (!c) { continue; }
				var top = (state.ground && c.water === null && !p.kit && !p.plants) ? state.ground : c.top;
				for (y = floor; y <= c.h; y++) {
					var name = y === c.h ? top : (c.layers && c.layers[y]) || (y >= c.h - c.depth ? c.filler : 'default:stone');
					var skip = [y !== c.h, y !== floor, false, false, false, false];
					for (var f = 2; f < 6; f++) {
						var d = FACE_DIRS[f];
						skip[f] = groundTop(x + d[0], z + d[2]) >= y;
					}
					addCuboid(gb, 'solid', x + off + ox, y + 0.5, z + off, [-8, -8, -8, 8, 8, 8], tileList(name, proposal), skip);
				}
				if (c.water !== null) {
					var wt = tileList('default:water_source', proposal);
					for (y = c.h + 1; y <= c.water; y++) {
						var ws = [y !== c.water, true, false, false, false, false];
						for (var g = 2; g < 6; g++) {
							var e = FACE_DIRS[g], nb = column(x + e[0], z + e[2]);
							ws[g] = nb !== null && (nb.h >= y || (nb.water !== null && nb.water >= y));
						}
						addCuboid(wb, 'water', x + off + ox, y + 0.5, z + off, [-8, -8, -8, 8, 8, 8], wt, ws);
					}
				}
			}
		}
		p.nodes.forEach(function (n) {
			var def = L.def(n.name);
			if (!def) { return; }
			var px = n.x + off + ox, py = n.y + 0.5, pz = n.z + off;
			var t = tilesOf(n.name, proposal);
			if (def.draw === 'cube' || def.draw === 'log') {
				addCuboid(gb, 'solid', px, py, pz, [-8, -8, -8, 8, 8, 8], faceTiles(t, def.draw === 'log' ? n.p2 : 0), null);
			} else if (def.draw === 'plant') {
				addPlant(pb, t[0], px, py, pz, def.scale || 1, 1);
			} else if (def.draw === 'hanging') {
				var below = nodeAt[n.x + ',' + (n.y - 1) + ',' + n.z];
				addPlant(pb, below && below.name === n.name ? def.strand : t[0], px, py, pz, 1, 1);
			} else if (def.draw === 'leaves') {
				addCuboid(pb, 'leaves', px, py, pz, [-8, -8, -8, 8, 8, 8], faceTiles(t, 0), null);
			} else if (def.draw === 'carpet') {
				addCuboid(pb, 'clip', px, py, pz, [-8, -8, -8, 8, -7, 8], faceTiles(t, 0), [false, true, false, false, false, false]);
			} else if (def.draw === 'lily') {
				var lily = [];
				for (var i = 0; i < 6; i++) { lily.push({tex: t[0], rot: i === 0 ? n.p2 : 0}); }
				addCuboid(pb, 'clip', px, py, pz, [-8, -8, -8, 8, -7.5, 8], lily, [false, false, true, true, true, true]);
			} else if (def.draw === 'rooted') {
				addPlant(pb, def.special, px, py + 1, pz, 1, n.p2 / 16);
			} else if (def.draw === 'box') {
				var bt = turnTiles(faceTiles(t, 0), n.p2 % 4);
				def.boxes.forEach(function (b) {
					addCuboid(sb, def.alpha === 'clip' ? 'clip' : 'solid', px, py, pz, turnBox(b, n.p2 % 4), bt, null);
				});
			} else if (def.draw === 'fence' || def.draw === 'wall') {
				var fence = def.draw === 'fence';
				var ft = faceTiles(t, 0);
				addCuboid(sb, 'solid', px, py, pz, fence ? FENCE_POST : WALL_POST, ft, null);
				['front', 'back', 'left', 'right'].forEach(function (side) {
					var sd = SIDE_DIRS[side], nb = nodeAt[(n.x + sd[0]) + ',' + n.y + ',' + (n.z + sd[2])];
					if (nb && nb.name === n.name) {
						(fence ? FENCE_RAILS : WALL_ARMS)[side].forEach(function (b) { addCuboid(sb, 'solid', px, py, pz, b, ft, null); });
					}
				});
			} else if (def.draw === 'shape') {
				var shape = BOXES[def.shape], st = faceTiles(t, 0);
				addCuboid(sb, 'solid', px, py, pz, shape.core, st, null);
				SIDE_ORDER.forEach(function (side) {
					var sd = SIDE_DIRS[side], nb = nodeAt[(n.x + sd[0]) + ',' + (n.y + sd[1]) + ',' + (n.z + sd[2])];
					var join = nb ? nb.name.indexOf('cairn:') === 0 :
						(TreeShapes.GROUND_KINDS[def.shape] === true && side === 'bottom' && groundTop(n.x, n.z) >= n.y - 1);
					if (join) { addCuboid(sb, 'solid', px, py, pz, shape[side], st, null); }
				});
			}
		});
		gb.build(groups.ground, 'ground');
		sb.build(groups.ground, 'ground');
		wb.build(groups.ground, 'water');
		pb.build(groups.plants, 'plants');
		p.trees.forEach(function (t) {
			buildTree(groups.trees, t, t.x + off + ox, t.y, t.z + off, proposal, function (tx, ty, tz) {
				return groundTop(t.x + tx, t.z + tz) >= t.y + ty;
			});
		});
	}

	// One tree: log cubes, quarter meshes, connected node boxes, leaves,
	// fruit, hanging moss (the lowest node the end piece, the strand above
	// it on the proposal side when picked), the dead pine's snow layer.
	function buildTree(group, tree, ox0, oy0, oz0, proposal, isGround) {
		var w = L.WOODS[tree.species], map = {};
		tree.nodes.forEach(function (n) { map[n.x + ',' + n.y + ',' + n.z] = n; });
		function at(x, y, z) { return map[x + ',' + y + ',' + z]; }
		var wb = new Buckets(), lb = new Buckets();
		var woodTiles = [w.top, w.top, w.bark, w.bark, w.bark, w.bark];
		var barkTiles = [w.bark, w.bark, w.bark, w.bark, w.bark, w.bark];
		var strand = proposal && state.on['swamp.hanging_moss'] !== false ? 'swamp/hanging_moss_strand.png' : w.moss;
		tree.nodes.forEach(function (nd) {
			var ox = nd.x + ox0, oy = nd.y + oy0 + 0.5, oz = nd.z + oz0;
			if (nd.kind === 'trunk') {
				var skip = [];
				for (var f = 0; f < 6; f++) {
					var d = FACE_DIRS[f], nb = at(nd.x + d[0], nd.y + d[1], nd.z + d[2]);
					skip.push(nb !== undefined && nb.kind === 'trunk');
				}
				addCuboid(wb, 'solid', ox, oy, oz, [-8, -8, -8, 8, 8, 8], faceTiles(woodTiles, nd.rot), skip);
			} else if (nd.kind === 'quarter') {
				Mesh.quarterPolys('oct', nd.rot).forEach(function (poly) {
					Mesh.addPoly(wb, poly.tile === 'top' ? w.top : w.bark, 'solid', ox, oy, oz, poly);
				});
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
				addCuboid(lb, 'leaves', ox, oy, oz, [-8, -8, -8, 8, 8, 8], Mesh.uniform(w.leaves), null);
			} else if (nd.kind === 'fruit') {
				addPlant(lb, w.fruit || 'default_apple.png', ox, oy, oz, 1, 1);
			} else if (nd.kind === 'moss') {
				var below = at(nd.x, nd.y - 1, nd.z);
				addPlant(lb, below !== undefined && below.kind === 'moss' ? strand : w.moss, ox, oy, oz, 1, 1);
			}
			// the dead pine: a snow layer on wood with open sky above
			if (tree.snow && G_WOOD[nd.kind]) {
				var clear = true;
				for (var up = 1; up < 30 && clear; up++) { if (at(nd.x, nd.y + up, nd.z)) { clear = false; } }
				if (clear) {
					addCuboid(wb, 'solid', ox, oy + 1, oz, [-8, -8, -8, 8, -4, 8], Mesh.uniform('default_snow.png'), [false, true, false, false, false, false]);
				}
			}
		});
		wb.build(group, 'wood');
		lb.build(group, 'leaves');
	}
	var G_WOOD = {trunk: true, quarter: true, base: true, branch: true, twig: true};

	// A 2-node player for scale (the classic 64 x 32 skin layout).
	function playerFigure() {
		var group = new THREE.Group();
		var mat = new THREE.MeshLambertMaterial({map: texture('character.png'), alphaTest: 0.5});
		function part(w, h, d, u, v, x, y) {
			var g = new THREE.BoxGeometry(w / 16, h / 16, d / 16);
			var rects = {px: [u, v + d, d, h], nx: [u + d + w, v + d, d, h], py: [u + d, v, w, d], ny: [u + d + w, v, w, d],
				pz: [u + d, v + d, w, h], nz: [u + d + w + d, v + d, w, h]};
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

	// A text label facing the camera.
	function label(text, x, y, z, strong, size) {
		size = size || 0.75;
		var canvas = document.createElement('canvas'), g = canvas.getContext('2d');
		var font = '600 28px system-ui, sans-serif';
		g.font = font;
		var w = Math.ceil(g.measureText(text).width) + 20;
		canvas.width = w; canvas.height = 42;
		g.font = font;
		g.fillStyle = strong ? 'rgba(20, 40, 24, 0.82)' : 'rgba(70, 30, 12, 0.85)';
		g.fillRect(0, 0, w, 42);
		g.fillStyle = '#ffffff';
		g.textBaseline = 'middle';
		g.fillText(text, 10, 22);
		var t = new THREE.CanvasTexture(canvas);
		t.encoding = THREE.sRGBEncoding;
		var s = new THREE.Sprite(new THREE.SpriteMaterial({map: t, depthTest: false}));
		s.scale.set(w / 42 * size, size, 1);
		s.position.set(x, y, -z);
		s.renderOrder = 5;
		return s;
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
	scene.fog = new THREE.Fog(SKY, 140, 320);
	var persp = new THREE.PerspectiveCamera(45, 1, 0.1, 800);
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
	scene.add(sun);
	scene.add(sun.target);
	var content = new THREE.Group();
	scene.add(content);
	var grid = new THREE.Group();
	scene.add(grid);

	// -------------------------------------------------------------- state

	var params = new URLSearchParams(location.search);
	function stored(k) { try { return window.localStorage.getItem('r51land.' + k); } catch (e) { return null; } }
	function store(k, v) { try { window.localStorage.setItem('r51land.' + k, v); } catch (e) { /* per-viewer convenience only */ } }
	var MULTS = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4];
	var startZone = params.get('zone') || stored('zone');
	var startMode = params.get('mode') || stored('mode');
	var state = {
		zone: L.ZONES[startZone] ? startZone : 'jungle',
		mode: ['patch', 'kit', 'plants', 'notes'].indexOf(startMode) >= 0 ? startMode : 'patch',
		variant: ['today', 'proposal', 'both'].indexOf(params.get('variant')) >= 0 ? params.get('variant') : 'proposal',
		biome: params.get('biome') || '',
		seed: parseInt(params.get('seed'), 10) || 1,
		view: params.get('view') === 'top' ? 'top' : 'orbit',
		ground: '',
		on: {}, mult: {}, lab: {},
		show: {trees: params.get('trees') !== '0', plants: params.get('plants') !== '0', leaves: params.get('leafs') !== '0',
			labels: params.get('labels') === '1', grid: params.get('grid') === '1'},
		pedestal: false,
		shown: []
	};
	if (params.get('bare') === '1') { document.body.classList.add('bare'); }
	(params.get('off') || '').split(',').forEach(function (k) { if (k) { state.on[k] = false; } });
	function multOf(key) { return state.mult[key] === undefined ? 1 : MULTS[state.mult[key]]; }

	function groupsOf() { return {ground: new THREE.Group(), plants: new THREE.Group(), trees: new THREE.Group(), labels: new THREE.Group()}; }
	var groups = groupsOf();
	function dispose() {
		content.children.slice().forEach(function (c) {
			content.remove(c);
			c.traverse(function (o) {
				if (o.geometry) { o.geometry.dispose(); }
				if (o.isSprite) { o.material.map.dispose(); o.material.dispose(); }
			});
		});
	}

	function genOpts(variant) {
		var mult = {};
		L.ITEMS.forEach(function (it) { mult[it.key] = multOf(it.key); });
		return {seed: state.seed, biome: state.biome, variant: variant, on: state.on, mult: mult, size: 48, pedestal: state.pedestal};
	}

	function build() {
		dispose();
		resize();
		groups = groupsOf();
		Object.keys(groups).forEach(function (k) { content.add(groups[k]); });
		var box, p;
		state.shown = [];
		if (state.mode === 'kit' || state.mode === 'plants') {
			p = state.mode === 'kit' ? L.kit(state.zone, state.seed) : L.plants(state.zone);
			buildPatch(p, groups, 0, true);
			var off = -p.size / 2;
			var kitMode = state.mode === 'kit';
			p.labels.forEach(function (lb, i) {
				groups.labels.add(label(lb.text, lb.x + off, kitMode ? 5.5 : 4.2, lb.z + off, !lb.gather, 1));
			});
			state.shown = [p];
			var used = {lo: p.size, hi: 0};
			p.cols.forEach(function (row) { row.forEach(function (c, z) { if (!c.void) { used.lo = Math.min(used.lo, z); used.hi = Math.max(used.hi, z); } }); });
			var fig = playerFigure();
			fig.position.set(off + 0.5, 1, -(off + used.hi - 1));
			groups.trees.add(fig);
			box = new THREE.Box3(new THREE.Vector3(off, -1, off + used.lo), new THREE.Vector3(off + p.size, 6, off + used.hi + 1));
		} else {
			var both = state.variant === 'both';
			var variants = both ? ['today', 'proposal'] : [state.variant];
			var gap = 6, n = variants.length;
			variants.forEach(function (v, i) {
				p = L.generate(state.zone, genOpts(v));
				var ox = n === 1 ? 0 : (i === 0 ? -(p.size + gap) / 2 : (p.size + gap) / 2);
				buildPatch(p, groups, ox, v === 'proposal');
				if (both) { groups.labels.add(label(v === 'today' ? 'Today' : 'Proposal', ox, 16, -p.size / 2 - 2, true, 3)); }
				if (v === 'proposal' && state.show.labels) {
					p.marks.forEach(function (m) {
						groups.labels.add(label(m.item, m.x - p.size / 2 + ox, m.y + 4, m.z - p.size / 2, false, 1.4));
					});
				}
				var fig2 = playerFigure(), spot = figureSpot(p);
				fig2.position.set(spot[0] + ox, spot[1], -spot[2]);
				groups.trees.add(fig2);
				state.shown.push(p);
			});
			var half = (p.size * n + gap * (n - 1)) / 2;
			box = new THREE.Box3(new THREE.Vector3(-half, -2, -p.size / 2), new THREE.Vector3(half, 12, p.size / 2));
		}
		buildGrid(box);
		frame(box);
		applyToggles();
		panel();
		readout();
		groundSelect();
	}

	function figureSpot(p) {
		var off = -p.size / 2;
		for (var r = 0; r < 20; r++) {
			for (var dx = -r; dx <= r; dx++) {
				var x = 18 + dx, z = 18 + r;
				if (x >= 0 && z >= 0 && x < p.size && z < p.size && p.cols[x][z].water === null) {
					return [x + off, p.cols[x][z].h + 1, z + off];
				}
			}
		}
		return [0, 1, 0];
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
		c.z = -c.z;
		var cam = (params.get('cam') || '').split(',').map(parseFloat);
		var strip = state.mode === 'kit' || state.mode === 'plants';
		var kitMode = state.mode === 'kit';
		var yaw = isFinite(cam[0]) ? cam[0] : (strip ? 8 : 28), pitch = isFinite(cam[1]) ? cam[1] : (kitMode ? 40 : strip ? 22 : 34);
		var zoom = isFinite(cam[2]) ? cam[2] : 1;
		var dist = Math.max(size.x, size.z) * 1.35;
		if (kitMode) {
			dist = Math.max(size.x, size.z) * 1.15;
		} else if (strip || (state.variant === 'both' && state.mode === 'patch')) {
			var vt = Math.tan(persp.fov * Math.PI / 360), ht = vt * persp.aspect;
			dist = Math.max(size.x / 2 / ht, size.y / 2 / vt) * (strip ? 0.95 : 1.0) + size.z / 2;
		}
		// a portrait view (a phone) fits the width, not the height
		if (persp.aspect < 1) { dist = dist / Math.max(0.45, persp.aspect); }
		dist = dist * zoom;
		orbit.target.set(c.x, strip && !kitMode ? 2 : 0, c.z);
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
		var half = Math.max(size.x, size.z) / 2 + 1, a = w / h;
		if (a >= 1) { ortho.left = -half * a; ortho.right = half * a; ortho.top = half; ortho.bottom = -half; }
		else { ortho.left = -half; ortho.right = half; ortho.top = half / a; ortho.bottom = -half / a; }
		ortho.updateProjectionMatrix();
	}

	function applyToggles() {
		groups.plants.visible = state.show.plants;
		groups.trees.visible = state.show.trees;
		groups.trees.traverse(function (o) { if (o.userData.layer === 'leaves') { o.visible = state.show.leaves; } });
		groups.labels.visible = state.show.labels || state.mode !== 'patch';
		grid.visible = state.show.grid;
		orbit.enabled = state.view === 'orbit';
		topControls.enabled = state.view === 'top';
	}

	// -------------------------------------------------------------- notes
	//
	// One document per key in "notes": {key, verdict, text, updatedAt}. The
	// key is the document id; characters a document id may not hold (only
	// letters, digits and _ - . ~ : @ + may stand there) become ~hex~ (no
	// key uses any today). Writes go one at a time per document and only
	// when something changed; an empty note without a verdict is deleted.

	var db = null, dbState = 'pending', dbError = '';
	var notes = {};       // key -> {verdict, text} as stored
	var queue = {};       // key -> the pending write
	var statusOf = {};    // key -> the last write's message
	function docId(key) {
		return key.replace(/[^A-Za-z0-9_\-.:@+]/g, function (ch) { return '~' + ch.charCodeAt(0).toString(16) + '~'; });
	}
	function canWrite() { return dbState === 'on'; }

	function dbLine() {
		var el = document.getElementById('dbline');
		if (dbState === 'on') { el.textContent = 'Notes and verdicts are saved for the coordinator as you leave a field or click a verdict.'; }
		else if (dbState === 'pending') { el.textContent = 'Notes: connecting…'; }
		else { el.textContent = 'Notes can be left on the published page.' + (dbError ? ' (' + dbError + ')' : ''); }
	}

	function startDb() {
		if (!window.claude || typeof window.claude.use !== 'function') { dbState = 'off'; dbLine(); panel(); return; }
		window.claude.use('db').then(function (d) {
			if (!d) { dbState = 'off'; dbLine(); panel(); return; }
			db = d;
			db.collection('notes').onSnapshot(function (snap) {
				var next = {};
				snap.docs.forEach(function (doc) {
					var v = doc.data();
					if (v && typeof v.key === 'string') {
						next[v.key] = {verdict: typeof v.verdict === 'string' ? v.verdict : '', text: typeof v.text === 'string' ? v.text : ''};
					}
				});
				notes = next;
				if (dbState !== 'on') { dbState = 'on'; dbLine(); panel(); } else { refreshNotes(); }
			}, function (e) {
				dbState = 'off';
				dbError = 'the notes could not be read: ' + (e && e.code ? e.code : 'unavailable');
				dbLine(); panel();
			});
		}, function () { dbState = 'off'; dbLine(); panel(); });
	}

	function save(key, verdict, text) {
		if (!canWrite()) { return; }
		var prev = queue[key] || Promise.resolve();
		queue[key] = prev.then(function () {
			var cur = notes[key] || {verdict: '', text: ''};
			if (cur.verdict === verdict && cur.text === text) { return null; }
			var ref = db.collection('notes').doc(docId(key));
			var job = verdict || text ? ref.set({key: key, verdict: verdict, text: text, updatedAt: new Date().toISOString()}) : ref.delete();
			return job.then(function () {
				notes[key] = {verdict: verdict, text: text};
				statusOf[key] = {ok: true, text: 'Saved'};
				showStatus(key);
			}, function (e) {
				var code = e && e.code ? e.code : 'unavailable';
				statusOf[key] = {ok: false, text: code === 'invalid_argument' ?
					'Not saved: this view may not write notes (read-only).' :
					code === 'quota_exceeded' ? 'Not saved: the notes store is full.' :
					'Not saved (' + code + '); try again in a moment.'};
				if (code === 'invalid_argument') { dbState = 'off'; dbError = 'read-only here'; dbLine(); }
				showStatus(key);
			});
		});
	}
	function showStatus(key) {
		var el = document.getElementById('status-' + key);
		var st = statusOf[key];
		if (el && st) { el.textContent = st.text; el.className = 'status' + (st.ok ? '' : ' err'); }
	}
	// put stored notes into the widgets, leaving a field being edited alone
	function refreshNotes() {
		Object.keys(widgets).forEach(function (key) {
			var wdg = widgets[key], n = notes[key] || {verdict: '', text: ''};
			if (document.activeElement !== wdg.area) { wdg.area.value = n.text; }
			wdg.buttons.forEach(function (b) { b.classList.toggle('on', b.dataset.v === n.verdict); b.setAttribute('aria-pressed', b.dataset.v === n.verdict ? 'true' : 'false'); });
		});
		if (state.mode === 'notes') { panel(); }
	}

	// The verdict buttons and note field of one key.
	var widgets = {};
	function noteWidget(parent, key) {
		var box = document.createElement('div');
		var row = document.createElement('div');
		row.className = 'verdict';
		row.setAttribute('role', 'group');
		row.setAttribute('aria-label', 'Verdict for ' + key);
		var n = notes[key] || {verdict: '', text: ''};
		var area = document.createElement('textarea');
		var buttons = [['pick', 'Pick'], ['rework', 'Rework'], ['drop', 'Drop']].map(function (v) {
			var b = document.createElement('button');
			b.type = 'button';
			b.id = 'verdict-' + v[0] + '-' + key;
			b.dataset.v = v[0];
			b.className = 'v-' + v[0] + (n.verdict === v[0] ? ' on' : '');
			b.setAttribute('aria-pressed', n.verdict === v[0] ? 'true' : 'false');
			b.textContent = v[1];
			b.disabled = !canWrite();
			b.onclick = function () {
				var cur = notes[key] || {verdict: '', text: ''};
				var verdict = cur.verdict === v[0] ? '' : v[0];
				buttons.forEach(function (o) { o.classList.toggle('on', o.dataset.v === verdict); o.setAttribute('aria-pressed', o.dataset.v === verdict ? 'true' : 'false'); });
				save(key, verdict, area.value);
			};
			row.appendChild(b);
			return b;
		});
		var status = document.createElement('span');
		status.className = 'status';
		status.id = 'status-' + key;
		status.setAttribute('role', 'status');
		row.appendChild(status);
		area.id = 'note-' + key;
		area.rows = 1;
		area.placeholder = canWrite() ? 'Note (saved when you leave the field)' : 'Notes can be left on the published page.';
		area.setAttribute('aria-label', 'Note for ' + key);
		area.value = n.text;
		area.readOnly = !canWrite();
		area.onblur = function () {
			var cur = notes[key] || {verdict: '', text: ''};
			var verdict = '';
			buttons.forEach(function (b) { if (b.classList.contains('on')) { verdict = b.dataset.v; } });
			if (area.value !== cur.text) { save(key, verdict, area.value); }
		};
		box.appendChild(row);
		box.appendChild(area);
		parent.appendChild(box);
		widgets[key] = {area: area, buttons: buttons};
		showStatus(key);
		return area;
	}

	// ------------------------------------------------------------ the panel

	function zoneItems(zone) { return L.ITEMS.filter(function (it) { return it.zones.indexOf(zone) >= 0; }); }

	function itemCard(parent, it, opts) {
		var card = document.createElement('div');
		card.className = 'item' + (state.on[it.key] === false ? ' off' : '');
		var head = document.createElement('div');
		head.className = 'itemhead';
		var lab = document.createElement('label');
		if (opts.toggle && !it.reference && !it.kitOnly) {
			var cb = document.createElement('input');
			cb.type = 'checkbox';
			cb.id = 'on-' + it.key;
			cb.checked = state.on[it.key] !== false;
			cb.onchange = function () { state.on[it.key] = cb.checked; build(); };
			lab.appendChild(cb);
		}
		var nm = document.createElement('span');
		nm.textContent = opts.title || it.name;
		lab.appendChild(nm);
		head.appendChild(lab);
		var key = document.createElement('code');
		key.className = 'key';
		key.textContent = it.key;
		head.appendChild(key);
		var badge = standinBadge(it);
		if (badge) { head.appendChild(badge); }
		card.appendChild(head);
		if (it.text) {
			var tx = document.createElement('div');
			tx.className = 'note';
			tx.textContent = it.text;
			card.appendChild(tx);
		}
		if (it.biomes && opts.toggle) {
			var bi = document.createElement('div');
			bi.className = 'note';
			bi.textContent = 'In: ' + it.biomes.join(', ');
			card.appendChild(bi);
		}
		if (opts.toggle && (it.den || it.share)) { densityRow(card, it); }
		if (it.key === 'beach.papyrus' && opts.toggle) {
			var pl = document.createElement('label');
			var pc = document.createElement('input');
			pc.type = 'checkbox';
			pc.id = 'papyrus-pedestal';
			pc.checked = state.pedestal;
			pc.onchange = function () { state.pedestal = pc.checked; build(); };
			pl.appendChild(pc);
			pl.appendChild(document.createTextNode(' compare: today\'s pedestal form'));
			card.appendChild(pl);
		}
		if (opts.drops) {
			var ul = document.createElement('ul');
			ul.className = 'drops';
			opts.drops.forEach(function (d) {
				var li = document.createElement('li');
				li.textContent = d.label + ' → ' + d.drop + (d.standin ? ' (stand-in block)' : '');
				ul.appendChild(li);
			});
			card.appendChild(ul);
		}
		noteWidget(card, it.key);
		parent.appendChild(card);
	}

	function standinBadge(it) {
		if (!it.standin) { return null; }
		var b = document.createElement('span');
		// a prop ARTL has delivered under the same id replaces its stand-in
		if (it.piece && L.propDef(it.piece).art) { b.className = 'badge art'; b.textContent = 'ARTL art'; return b; }
		b.className = 'badge';
		b.textContent = 'stand-in: ' + it.standin;
		b.title = 'Made of today\'s textures until ARTL\'s props arrive';
		return b;
	}

	function densityRow(card, it) {
		var row = document.createElement('div');
		row.className = 'density';
		var lab = document.createElement('label');
		lab.htmlFor = 'mult-' + it.key;
		lab.textContent = 'density';
		var r = document.createElement('input');
		r.type = 'range';
		r.min = 0; r.max = MULTS.length - 1; r.step = 1;
		r.id = 'mult-' + it.key;
		r.value = state.mult[it.key] === undefined ? 3 : state.mult[it.key];
		var out = document.createElement('span');
		function text() {
			var m = MULTS[r.value];
			if (it.share) { return '× ' + m + ' (≈ ' + Math.round(it.share * m * 100) + ' % of the ground)'; }
			var n = Math.round(it.den / m), size = 48 * 48;
			var unit = it.unit || 'columns';
			var here = (state.shown.filter(function (p) { return p.variant === 'proposal'; })[0] || {facts: {items: {}}}).facts.items[it.key] || 0;
			return '× ' + m + ': ≈ 1 in ' + n + ' ' + unit + (it.unit ? '' : ' (≈ ' + (size / n).toFixed(1) + ' per patch)') + ', here ' + here;
		}
		out.textContent = text();
		r.oninput = function () { out.textContent = text(); };
		r.onchange = function () { state.mult[it.key] = parseInt(r.value, 10); build(); };
		var add = document.createElement('button');
		add.type = 'button';
		add.id = 'note-density-' + it.key;
		add.textContent = 'Note this density';
		add.disabled = !canWrite();
		add.onclick = function () {
			var area = document.getElementById('note-' + it.key);
			var m = MULTS[r.value];
			var line = it.share ? 'density ≈ ' + Math.round(it.share * m * 100) + ' %' : 'density ≈ 1 in ' + Math.round(it.den / m);
			area.value = (area.value ? area.value + '\n' : '') + line;
			area.focus();
		};
		row.appendChild(lab); row.appendChild(r); row.appendChild(out); row.appendChild(add);
		card.appendChild(row);
	}

	function panel() {
		widgets = {};
		var z = L.ZONES[state.zone];
		document.getElementById('zonetitle').textContent = state.mode === 'notes' ? 'All notes' : z.name;
		document.getElementById('zonetext').textContent = state.mode === 'notes' ? '' : z.text;
		var el = document.getElementById('panel');
		el.innerHTML = '';
		dbLine();
		if (state.mode === 'notes') { notesList(el); return; }
		if (state.mode === 'patch') {
			var h = document.createElement('h2');
			h.textContent = state.variant === 'today' ? 'Proposal (switch to Proposal to see it)' : 'Proposal';
			el.appendChild(h);
			zoneItems(state.zone).forEach(function (it) {
				if (!it.kitOnly) { itemCard(el, it, {toggle: true}); }
			});
			var kh = document.createElement('p');
			kh.className = 'note';
			kh.textContent = 'Single blocks and the towns\' graveyard: see Kit.';
			if (zoneItems(state.zone).some(function (it) { return it.kitOnly; })) { el.appendChild(kh); }
		} else if (state.mode === 'kit') {
			var p = state.shown[0];
			var h2 = document.createElement('h2');
			h2.textContent = 'Kit, left to right (numbers in the view)';
			el.appendChild(h2);
			if (!p.list.length) {
				var none = document.createElement('p');
				none.textContent = 'Nothing to build here.';
				el.appendChild(none);
			}
			var done = {};
			p.list.forEach(function (e, i) {
				var it = L.ITEM[e.item];
				var drops = p.blocks.filter(function (b) { return b.item === e.item; });
				if (done[e.item]) {
					var again = document.createElement('p');
					again.className = 'note';
					again.textContent = (i + 1) + ': ' + e.label + ' (' + e.item + ', as above)';
					el.appendChild(again);
					return;
				}
				done[e.item] = true;
				itemCard(el, it, {title: (i + 1) + ': ' + e.label, drops: drops});
			});
		} else {
			var pp = state.shown[0];
			var h3 = document.createElement('h2');
			h3.textContent = 'Plants, left to right (numbers in the view; brown labels: gathering sources)';
			el.appendChild(h3);
			var ol = document.createElement('ol');
			pp.row.forEach(function (e) {
				var li = document.createElement('li');
				li.textContent = e.label + (e.gather ? '' : (e.item ? ' (' + e.item + ', drops nothing)' : ''));
				ol.appendChild(li);
			});
			el.appendChild(ol);
			var seen = {};
			pp.row.forEach(function (e) {
				if (e.item && !seen[e.item]) { seen[e.item] = true; itemCard(el, L.ITEM[e.item], {}); }
			});
		}
	}

	function notesList(el) {
		var keys = Object.keys(notes);
		if (!keys.length) {
			var p = document.createElement('p');
			p.textContent = dbState === 'on' ? 'No notes yet.' : 'Notes can be left on the published page.';
			el.appendChild(p);
			return;
		}
		var known = {};
		L.ZONE_ORDER.forEach(function (zone) {
			var its = zoneItems(zone).filter(function (it) { return notes[it.key]; });
			if (!its.length) { return; }
			var h = document.createElement('h3');
			h.textContent = L.ZONES[zone].name;
			el.appendChild(h);
			el.appendChild(noteRows(its.map(function (it) { known[it.key] = true; return {key: it.key, name: it.name}; })));
		});
		var other = keys.filter(function (k) { return !known[k]; });
		if (other.length) {
			var h2 = document.createElement('h3');
			h2.textContent = 'Other keys';
			el.appendChild(h2);
			el.appendChild(noteRows(other.map(function (k) { return {key: k, name: ''}; })));
		}
	}
	function noteRows(rows) {
		var dl = document.createElement('dl');
		dl.className = 'notelist';
		rows.forEach(function (r) {
			var n = notes[r.key];
			var dt = document.createElement('dt');
			var b = document.createElement('b');
			b.textContent = n.verdict ? n.verdict.toUpperCase() + ' ' : '— ';
			dt.appendChild(b);
			dt.appendChild(document.createTextNode(r.name + ' '));
			var c = document.createElement('code');
			c.textContent = r.key;
			dt.appendChild(c);
			dl.appendChild(dt);
			if (n.text) {
				var dd = document.createElement('dd');
				dd.textContent = n.text;
				dl.appendChild(dd);
			}
		});
		return dl;
	}

	// ----------------------------------------------------------- readout

	function readout() {
		var el = document.getElementById('readout');
		el.innerHTML = '';
		if (state.mode !== 'patch') { return; }
		state.shown.forEach(function (p) {
			var h = document.createElement('h2');
			h.textContent = (p.variant === 'today' ? 'Today' : 'Proposal') + ': ' + p.biome + ', seed ' + p.seed;
			el.appendChild(h);
			var land = 0, water = 0, tops = {};
			p.cols.forEach(function (row) {
				row.forEach(function (c) {
					if (c.water !== null) { water++; } else { land++; tops[c.top] = (tops[c.top] || 0) + 1; }
				});
			});
			var rows = [['dry land', land, ''], ['water', water, '']];
			Object.keys(tops).sort(function (a, b) { return tops[b] - tops[a]; }).forEach(function (t) {
				rows.push(['  ' + t, tops[t], Math.round(tops[t] * 100 / land) + ' %']);
			});
			Object.keys(p.facts.rows).sort().forEach(function (r) { rows.push(['row ' + r, p.facts.rows[r], '']); });
			Object.keys(p.facts.items).sort().forEach(function (r) { rows.push([r, p.facts.items[r], '']); });
			var wrap = document.createElement('div');
			wrap.className = 'tablewrap';
			var table = document.createElement('table');
			var body = document.createElement('tbody');
			rows.forEach(function (r) {
				var tr = document.createElement('tr');
				var th = document.createElement('th');
				th.textContent = r[0];
				tr.appendChild(th);
				[r[1], r[2]].forEach(function (v) { var td = document.createElement('td'); td.textContent = v; tr.appendChild(td); });
				body.appendChild(tr);
			});
			table.appendChild(body);
			wrap.appendChild(table);
			el.appendChild(wrap);
		});
	}

	// ------------------------------------------------------- texture lab

	// Ground slots per zone: a node and the face the choice replaces.
	var LAB_SLOTS = {
		swamp: [['grug_nodes:mud_with_wet_grass', 'top'], ['grug_nodes:mud_with_wet_grass', 'side'], ['grug_nodes:mud_mottled', 'top'],
			['grug_nodes:mud_mottled', 'side'], ['grug_nodes:mud_dry', 'top'], ['grug_nodes:mud', 'all'], ['new:swamp_moss', 'top'],
			['new:swamp_moss', 'side'], ['grug_nodes:dirt_with_moss', 'top'], ['grug_nodes:dirt_with_moss', 'side']],
		jungle: [['grug_nodes:dirt_with_canopy_litter', 'top'], ['default:dirt_with_rainforest_litter', 'top'], ['grug_nodes:mud', 'all']],
		undead: [['grug_nodes:dirt_with_bone_litter', 'top'], ['grug_nodes:blight_dirt', 'all'], ['grug_nodes:ash_ground', 'all']],
		dwarf: [['default:gravel', 'all'], ['default:stone', 'all'], ['default:snowblock', 'all'], ['default:dirt_with_coniferous_litter', 'top']],
		orc: [['grug_nodes:mesa_clay', 'all'], ['default:dry_dirt', 'all']],
		elves: [['grug_nodes:dirt_with_silver_litter', 'top'], ['grug_nodes:dirt_with_moss', 'top'], ['grug_nodes:dirt_with_moss', 'side'],
			['grug_nodes:dirt_with_forest_litter', 'top']],
		savanna: [['default:dry_dirt_with_dry_grass', 'top'], ['default:dry_dirt', 'all'], ['grug_nodes:mesa_clay', 'all']],
		beach: [['default:sand', 'all'], ['default:gravel', 'all']]
	};
	var uploads = 0;
	function labOptions() {
		return Object.keys(TEXTURES).filter(function (k) {
			return k.indexOf('swamp/') === 0 || k.indexOf('grounds/') === 0 || k.indexOf('up/') === 0;
		}).sort();
	}
	function labUi() {
		var el = document.getElementById('lab');
		el.innerHTML = '';
		(LAB_SLOTS[state.zone] || []).forEach(function (slot, i) {
			var node = slot[0], face = slot[1];
			var row = document.createElement('div');
			row.className = 'labrow';
			var img = document.createElement('img');
			img.className = 'thumb';
			img.alt = '';
			var t = tilesOf(node, true);
			img.src = dataUrl(face === 'side' ? t[2] : t[0]);
			var name = document.createElement('span');
			name.className = 'labname';
			name.textContent = node.replace(/^[a-z_]+:/, '') + ', ' + face;
			var sel = document.createElement('select');
			sel.id = 'lab-' + state.zone + '-' + i;
			sel.setAttribute('aria-label', node + ' ' + face);
			var def = document.createElement('option');
			def.value = '';
			def.textContent = 'as proposed';
			sel.appendChild(def);
			labOptions().forEach(function (k) {
				var op = document.createElement('option');
				op.value = k + '.png';
				op.textContent = k + (images[k] && images[k].naturalWidth > 16 ? ' (' + images[k].naturalWidth / 16 + ' × ' + images[k].naturalWidth / 16 + ')' : '');
				sel.appendChild(op);
			});
			var cur = state.lab[node] || {};
			sel.value = cur[face] || '';
			sel.onchange = function () {
				var l = state.lab[node] || {};
				l[face] = sel.value;
				state.lab[node] = l;
				labUi();
				build();
			};
			var file = document.createElement('input');
			file.type = 'file';
			file.accept = 'image/png';
			file.hidden = true;
			file.id = 'labfile-' + state.zone + '-' + i;
			file.onchange = function () {
				var f = file.files[0];
				if (!f) { return; }
				var reader = new FileReader();
				reader.onload = function () {
					uploads = uploads + 1;
					var key = 'up/' + uploads + '_' + f.name.replace(/[^A-Za-z0-9_]/g, '_').replace(/_png$/, '');
					var im = new Image();
					im.onload = function () {
						var w = im.naturalWidth;
						if (w !== 16 && w !== 32 && w !== 64) {
							document.getElementById('labmsg').textContent = f.name + ' is ' + w + ' px wide. Use a 16, 32 or 64 px wide PNG.';
							return;
						}
						document.getElementById('labmsg').textContent = '';
						TEXTURES[key] = reader.result;
						images[key] = im;
						var l = state.lab[node] || {};
						l[face] = key + '.png';
						state.lab[node] = l;
						labUi();
						build();
					};
					im.src = reader.result;
				};
				reader.readAsDataURL(f);
			};
			var up = document.createElement('button');
			up.type = 'button';
			up.id = 'labup-' + state.zone + '-' + i;
			up.textContent = 'PNG…';
			up.title = 'Try an own PNG here (16, 32 or 64 px)';
			up.onclick = function () { file.click(); };
			row.appendChild(img); row.appendChild(name); row.appendChild(sel); row.appendChild(up); row.appendChild(file);
			el.appendChild(row);
		});
	}

	// "one ground everywhere": the grounds of the patch on view
	function groundSelect() {
		var sel = document.getElementById('groundsel');
		var tops = {};
		state.shown.forEach(function (p) { p.cols.forEach(function (row) { row.forEach(function (c) { if (c.water === null) { tops[c.top] = 1; } }); }); });
		sel.innerHTML = '';
		var mixed = document.createElement('option');
		mixed.value = '';
		mixed.textContent = 'mix (as generated)';
		sel.appendChild(mixed);
		Object.keys(tops).sort().forEach(function (t) {
			var op = document.createElement('option');
			op.value = t;
			op.textContent = 'all ' + t.replace(/^[a-z_]+:/, '');
			sel.appendChild(op);
		});
		if (state.ground && !tops[state.ground]) {
			var op2 = document.createElement('option');
			op2.value = state.ground;
			op2.textContent = 'all ' + state.ground.replace(/^[a-z_]+:/, '');
			sel.appendChild(op2);
		}
		sel.value = state.ground;
		sel.disabled = state.mode !== 'patch';
	}

	// ----------------------------------------------------------------- ui

	var seedField = document.getElementById('seed');
	function syncUi() {
		seedField.value = state.seed;
		var zb = document.getElementById('zones');
		if (!zb.children.length) {
			L.ZONE_ORDER.forEach(function (z) {
				var b = document.createElement('button');
				b.type = 'button';
				b.id = 'zone-' + z;
				b.dataset.zone = z;
				b.textContent = L.ZONES[z].name.replace(/ \(.*\)$/, '');
				b.onclick = function () {
					state.zone = z; state.biome = ''; state.ground = '';
					store('zone', z);
					syncUi(); labUi(); build();
				};
				zb.appendChild(b);
			});
		}
		Array.prototype.forEach.call(zb.children, function (b) {
			b.classList.toggle('on', b.dataset.zone === state.zone);
			b.setAttribute('aria-pressed', b.dataset.zone === state.zone ? 'true' : 'false');
		});
		[['data-view', 'view'], ['data-mode', 'mode'], ['data-variant', 'variant']].forEach(function (a) {
			Array.prototype.forEach.call(document.querySelectorAll('[' + a[0] + ']'), function (b) {
				var on = b.getAttribute(a[0]) === state[a[1]];
				b.classList.toggle('on', on);
				b.setAttribute('aria-pressed', on ? 'true' : 'false');
				if (a[1] === 'variant') { b.disabled = state.mode !== 'patch'; }
			});
		});
		['trees', 'plants', 'leaves', 'labels', 'grid'].forEach(function (k) { document.getElementById('show-' + k).checked = state.show[k]; });
		var bs = document.getElementById('biome');
		bs.innerHTML = '';
		L.ZONES[state.zone].biomes.forEach(function (b) {
			var op = document.createElement('option');
			op.value = b;
			op.textContent = b.replace(/^grug_/, '');
			bs.appendChild(op);
		});
		bs.value = state.biome || L.ZONES[state.zone].biomes[0];
		bs.disabled = state.mode !== 'patch';
	}

	Array.prototype.forEach.call(document.querySelectorAll('[data-view]'), function (b) {
		b.onclick = function () { state.view = b.dataset.view; syncUi(); applyToggles(); };
	});
	Array.prototype.forEach.call(document.querySelectorAll('[data-mode]'), function (b) {
		b.onclick = function () {
			state.mode = b.dataset.mode;
			store('mode', state.mode);
			syncUi();
			// the notes list leaves the view as it is
			if (state.mode === 'notes') { panel(); readout(); } else { build(); }
		};
	});
	Array.prototype.forEach.call(document.querySelectorAll('[data-variant]'), function (b) {
		b.onclick = function () { state.variant = b.dataset.variant; syncUi(); build(); };
	});
	document.getElementById('biome').onchange = function (e) { state.biome = e.target.value; state.ground = ''; build(); };
	document.getElementById('regen').onclick = function () { state.seed = 1 + Math.floor(Math.random() * 99999); syncUi(); build(); };
	document.getElementById('prev').onclick = function () { state.seed = Math.max(1, state.seed - 1); syncUi(); build(); };
	document.getElementById('next').onclick = function () { state.seed = state.seed + 1; syncUi(); build(); };
	seedField.onchange = function () {
		var v = parseInt(seedField.value, 10);
		if (v >= 1) { state.seed = v; build(); }
		syncUi();
	};
	['trees', 'plants', 'leaves', 'labels', 'grid'].forEach(function (k) {
		document.getElementById('show-' + k).onchange = function (e) {
			state.show[k] = e.target.checked;
			if (k === 'labels') { build(); } else { applyToggles(); }
		};
	});
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

	preload(function () {
		resize();
		syncUi();
		labUi();
		if (state.mode === 'notes') { state.mode = 'patch'; build(); state.mode = 'notes'; syncUi(); panel(); readout(); } else { build(); }
		loop();
		window.__landReady = true;
		startDb();
	});
})();
