// Round 46 lane TREE, step 2: the seeded tree generator of the concept viewer.
//
// generate(species, seed) returns one tree as data: a sorted list of nodes
// {x, y, z, kind, rot} plus a few facts for the page. y = 0 is the first node
// above the ground; the trunk axis stands at x = 0, z = 0 (a 1 x 1 or 3 x 3
// trunk is centred on cell 0, a 2 x 2 trunk on the corner between cells -1
// and 0). Kinds: trunk (the plain log cube), quarter (the faceted trunk
// piece), branch, twig (connected node boxes), leaves, fruit. `rot` is the
// facedir param2: for a quarter the corner it rounds, for trunk / branch /
// twig the axis its bark grain runs along (0 = y, 4 = z, 12 = x).
//
// Port target: this file is written to be ported to Lua 5.1 line by line.
// Only integer arithmetic on doubles below 2^53 (+, -, *, and floor of a
// quotient via idiv), no trigonometry (directions come from the integer
// table DIR16), no Math.round, no object-key iteration reaching the output
// (cells are kept in an explicit insertion list and the result is sorted by
// a unique integer key). Positions inside a node are kept in sixteenths
// ("p16"), the grid the node boxes use.
//
// The growth concept per species is written down in DESIGN.md next to this
// file; each species function below follows that text step by step.

(function (root) {
	'use strict';

	var MODULUS = 2147483647;

	function idiv(a, b) { return Math.floor(a / b); }
	function iabs(a) { return a < 0 ? -a : a; }
	function imin(a, b) { return a < b ? a : b; }
	function imax(a, b) { return a > b ? a : b; }

	// ---------------------------------------------------------------- random

	// a * b mod 2^31 - 1 with every product below 2^47.
	function mulmod(a, b) {
		var high = idiv(b, 65536), low = b % 65536;
		return ((a * high) % MODULUS * 65536 + a * low) % MODULUS;
	}

	function powmod(base, exponent) {
		var result = 1;
		while (exponent > 0) {
			if (exponent % 2 === 1) { result = mulmod(result, base); }
			base = mulmod(base, base);
			exponent = idiv(exponent, 2);
		}
		return result;
	}

	// Park-Miller minimal standard generator (16807). The start state is the
	// species salt times 48271^(seed + 1), so neighbouring seeds start at
	// unrelated points of the sequence.
	function newRng(seed, salt) {
		var rng = {state: mulmod((salt * 104729) % (MODULUS - 1) + 1,
			powmod(48271, seed + 1))};
		for (var i = 0; i < 4; i++) { rngNext(rng); }
		return rng;
	}

	function rngNext(rng) {
		rng.state = (rng.state * 16807) % MODULUS;
		return rng.state;
	}

	// An integer in [low, high], both ends included.
	function rint(rng, low, high) {
		return low + rngNext(rng) % (high - low + 1);
	}

	// True with `percent` in 100.
	function chance(rng, percent) {
		return rngNext(rng) % 100 < percent;
	}

	// A position hash in [0, 99] for leaf-edge roughness: the same cell gives
	// the same answer for every cluster that covers it.
	function hash100(salt, x, y, z) {
		var h = ((x + 1000) * 7919 + (y + 1000) * 104729 + (z + 1000) * 1299709 +
			salt * 15485863) % MODULUS;
		h = (h * 48271) % MODULUS;
		h = (h * 48271) % MODULUS;
		return h % 100;
	}

	// ----------------------------------------------------------- directions

	// Sixteen compass directions as integer (dx, dz) of length ~16: k * 22.5
	// degrees from +x towards +z.
	var DIR16 = [
		[16, 0], [15, 6], [11, 11], [6, 15], [0, 16], [-6, 15], [-11, 11], [-15, 6],
		[-16, 0], [-15, -6], [-11, -11], [-6, -15], [0, -16], [6, -15], [11, -11], [15, -6]
	];

	function dirX(k) { return DIR16[((k % 16) + 16) % 16][0]; }
	function dirZ(k) { return DIR16[((k % 16) + 16) % 16][1]; }

	// A point `d16` sixteenths from (x16, z16) along direction k.
	function offX(x16, k, d16) { return x16 + idiv(dirX(k) * d16, 16); }
	function offZ(z16, k, d16) { return z16 + idiv(dirZ(k) * d16, 16); }

	// The cell holding a p16 coordinate, and the centre of a cell in p16.
	function cellOf(v16) { return idiv(v16, 16); }
	function mid(c) { return c * 16 + 8; }

	// ---------------------------------------------------------------- cells

	var RANK = {leaves: 1, fruit: 2, twig: 3, branch: 4, base: 5, trunk: 6, quarter: 6};
	var WOOD = {trunk: true, quarter: true, base: true, branch: true, twig: true};

	function key(x, y, z) { return ((y + 64) * 256 + (x + 128)) * 256 + (z + 128); }

	function newTree(species, seed) {
		return {species: species, seed: seed, cells: {}, order: [], stemList: [], stemSet: {}, clusters: [],
			path: [], facts: {}};
	}

	function getCell(t, x, y, z) { return t.cells[key(x, y, z)]; }

	function isWood(t, x, y, z) {
		var c = t.cells[key(x, y, z)];
		return c !== undefined && WOOD[c.kind] === true;
	}

	function putCell(t, x, y, z, kind, rot) {
		var k = key(x, y, z);
		var c = t.cells[k];
		if (c === undefined) {
			t.cells[k] = {x: x, y: y, z: z, kind: kind, rot: rot};
			t.order.push(k);
			return;
		}
		if (RANK[kind] > RANK[c.kind]) { c.kind = kind; c.rot = rot; }
	}

	// A cell of the stem itself (trunk layers, leader): limbs look for
	// their starting cell among these.
	function stemCell(t, x, y, z, kind, rot) {
		var k = key(x, y, z);
		var known = t.cells[k] !== undefined;
		putCell(t, x, y, z, kind, rot);
		if (!known) { t.stemList.push(k); t.stemSet[k] = true; }
	}

	// facedir of a quarter piece whose inner corner (the trunk axis) lies
	// towards (sx, sz), each -1 or 1 (shapes: inner corner +x +z at 0).
	function quarterRot(sx, sz) {
		if (sx > 0) { return sz > 0 ? 0 : 1; }
		return sz < 0 ? 2 : 3;
	}

	// ---------------------------------------------------------------- trunk

	// One trunk layer of width w around the axis (ax2, az2) given in half
	// nodes: cell c has its centre at 2c + 1. Odd widths have an odd axis.
	function trunkLayer(t, y, ax2, az2, w) {
		var x0 = idiv(ax2 - w, 2), z0 = idiv(az2 - w, 2);
		for (var i = 0; i < w; i++) {
			for (var j = 0; j < w; j++) {
				var x = x0 + i, z = z0 + j;
				var edgeX = (i === 0 || i === w - 1), edgeZ = (j === 0 || j === w - 1);
				if (w >= 2 && edgeX && edgeZ) {
					stemCell(t, x, y, z, 'quarter',
						quarterRot(i === 0 ? 1 : -1, j === 0 ? 1 : -1));
				} else {
					stemCell(t, x, y, z, 'trunk', 0);
				}
			}
		}
	}

	// A 1 x 1 trunk column from (x, y0, z) up to y1 inclusive.
	function column(t, x, y0, y1, z, kind) {
		for (var y = y0; y <= y1; y++) { stemCell(t, x, y, z, kind, 0); }
	}

	// ----------------------------------------------------------------- limbs

	// Kind of step `i` (1-based) of an n-step limb whose first `cubes` steps
	// are logs and whose first `thick` percent are branch, the rest twig.
	function stepKind(i, n, cubes, thick) {
		if (i <= cubes) { return 'trunk'; }
		if (i * 100 <= n * thick) { return 'branch'; }
		return 'twig';
	}

	var AXIS_ROT = [12, 0, 4];  // grain along x, y, z

	// Grow a limb from the wood cell (x, y, z) to the cell (tx, ty, tz) as a
	// staircase of face-connected cells. With `prefer` OUT_FIRST the first
	// step is level (the limb leaves its parent sideways). Each step advances
	// the axis that lags most behind the straight line (integer cross-multiplication), so
	// the staircase follows the line; on a tie the order in `prefer` wins
	// (0 = x, 1 = y, 2 = z). A step that would touch other wood sideways (and
	// so fuse into a ladder, connected boxes join every face neighbour) takes
	// another lagging axis instead when one is free. Returns the end cell;
	// t.path keeps the cells of the last limb.
	function limb(t, x, y, z, tx, ty, tz, cubes, thick, prefer) {
		if (ty < 1) { ty = imin(1, y); }        // never into the ground
		var d = [tx - x, ty - y, tz - z];
		var a = [iabs(d[0]), iabs(d[1]), iabs(d[2])];
		var s = [d[0] < 0 ? -1 : 1, d[1] < 0 ? -1 : 1, d[2] < 0 ? -1 : 1];
		var m = [0, 0, 0];
		var n = a[0] + a[1] + a[2];
		var p = [x, y, z];
		t.path = [];
		for (var i = 1; i <= n; i++) {
			// candidate axes, most lagging first
			var cand = [];
			for (var q = 0; q < 3; q++) {
				var ax = prefer[q];
				// a limb leaving its parent sideways takes a level first step
				var level = i === 1 && prefer[0] !== 1 && (m[0] < a[0] || m[2] < a[2]);
				if (m[ax] < a[ax] && !(level && ax === 1)) {
					var at = cand.length;
					while (at > 0) {
						var other = cand[at - 1];
						// is ax more behind than other? (2m+1)/a smaller
						if ((2 * m[ax] + 1) * a[other] < (2 * m[other] + 1) * a[ax]) {
							at = at - 1;
						} else {
							break;
						}
					}
					cand.splice(at, 0, ax);
				}
			}
			var pick = cand[0];
			for (var c = 0; c < cand.length; c++) {
				var axc = cand[c];
				var np = [p[0], p[1], p[2]];
				np[axc] = np[axc] + s[axc];
				if (cleanStep(t, np[0], np[1], np[2], p[0], p[1], p[2])) {
					pick = axc;
					break;
				}
			}
			p[pick] = p[pick] + s[pick];
			m[pick] = m[pick] + 1;
			putCell(t, p[0], p[1], p[2], stepKind(i, n, cubes, thick), AXIS_ROT[pick]);
			t.path.push([p[0], p[1], p[2]]);
		}
		return p;
	}

	var NEIGHBOURS = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];

	// May a limb step into (x, y, z) coming from (px, py, pz)? Yes when the
	// cell is already wood (limbs merge) or none of its other face
	// neighbours is wood.
	function cleanStep(t, x, y, z, px, py, pz) {
		if (isWood(t, x, y, z)) { return true; }
		for (var i = 0; i < 6; i++) {
			var nx = x + NEIGHBOURS[i][0], ny = y + NEIGHBOURS[i][1], nz = z + NEIGHBOURS[i][2];
			if (!(nx === px && ny === py && nz === pz) && isWood(t, nx, ny, nz)) {
				return false;
			}
		}
		return true;
	}

	var OUT_FIRST = [0, 2, 1];   // leave sideways, then rise
	var UP_FIRST = [1, 0, 2];

	// --------------------------------------------------------------- leaves

	// A leaf cluster: an ellipsoid centred at (x16, y16, z16) with radii in
	// sixteenths. `floor` (in nodes, relative to the centre cell) cuts it off
	// below, for flat-bottomed pads; -99 keeps the whole ellipsoid.
	function cluster(t, x16, y16, z16, rx, ry, rz, floor) {
		t.clusters.push({x: x16, y: y16, z: z16, rx: rx, ry: ry, rz: rz, floor: floor});
	}

	// Fill the clusters: a cell is leaves when its centre lies inside one;
	// cells in the outer band of every cluster covering them (depth above
	// `edge` percent) are dropped where the position hash is below `rough`.
	// Then drop leaves out of the leaf decay reach of wood, and loose ones.
	function fillLeaves(t, edge, rough, salt, reach) {
		var depth = {};
		var list = [];
		for (var ci = 0; ci < t.clusters.length; ci++) {
			var k = t.clusters[ci];
			var rx2 = k.rx * k.rx, ry2 = k.ry * k.ry, rz2 = k.rz * k.rz;
			var whole = rx2 * ry2 * rz2;
			var cx = cellOf(k.x), cy = cellOf(k.y), cz = cellOf(k.z);
			var ex = idiv(k.rx, 16) + 1, ey = idiv(k.ry, 16) + 1, ez = idiv(k.rz, 16) + 1;
			for (var y = cy - ey; y <= cy + ey; y++) {
				if (y - cy >= k.floor && y >= 0) {
					for (var x = cx - ex; x <= cx + ex; x++) {
						for (var z = cz - ez; z <= cz + ez; z++) {
							var dx = mid(x) - k.x, dy = mid(y) - k.y, dz = mid(z) - k.z;
							var v = dx * dx * ry2 * rz2 + dy * dy * rx2 * rz2 + dz * dz * rx2 * ry2;
							if (v <= whole && x >= -8 && x <= 7 && z >= -8 && z <= 7) {
								var q = idiv(v * 100, whole);
								var kk = key(x, y, z);
								if (depth[kk] === undefined) {
									depth[kk] = q;
									list.push(kk);
								} else if (q < depth[kk]) {
									depth[kk] = q;
								}
							}
						}
					}
				}
			}
		}
		for (var li = 0; li < list.length; li++) {
			var kk2 = list[li];
			var y2 = idiv(kk2, 65536) - 64;
			var x2 = idiv(kk2 % 65536, 256) - 128;
			var z2 = (kk2 % 256) - 128;
			if (depth[kk2] <= edge || hash100(salt, x2, y2, z2) >= rough) {
				if (getCell(t, x2, y2, z2) === undefined) {
					putCell(t, x2, y2, z2, 'leaves', 0);
				}
			}
		}
		pruneLeaves(t, reach);
	}

	// Leaves farther than `reach` (in the engine's cube search) from every
	// wood cell would decay: drop them. A leaf with no leaf or wood face
	// neighbour floats: drop it too.
	function pruneLeaves(t, reach) {
		var dist = {};
		var frontier = [];
		for (var i = 0; i < t.order.length; i++) {
			var c = t.cells[t.order[i]];
			if (WOOD[c.kind] === true) {
				dist[t.order[i]] = 0;
				frontier.push(c);
			}
		}
		for (var step = 1; step <= reach; step++) {
			var next = [];
			for (var f = 0; f < frontier.length; f++) {
				var fc = frontier[f];
				for (var dx = -1; dx <= 1; dx++) {
					for (var dy = -1; dy <= 1; dy++) {
						for (var dz = -1; dz <= 1; dz++) {
							var nk = key(fc.x + dx, fc.y + dy, fc.z + dz);
							if (dist[nk] === undefined) {
								dist[nk] = step;
								next.push({x: fc.x + dx, y: fc.y + dy, z: fc.z + dz});
							}
						}
					}
				}
			}
			frontier = next;
		}
		for (var j = 0; j < t.order.length; j++) {
			var lc = t.cells[t.order[j]];
			if (lc.kind === 'leaves' && dist[t.order[j]] === undefined) {
				lc.kind = 'gone';
			}
		}
		for (var j2 = 0; j2 < t.order.length; j2++) {
			var c2 = t.cells[t.order[j2]];
			if (c2.kind === 'leaves') {
				var held = false;
				for (var n = 0; n < 6; n++) {
					var nb = getCell(t, c2.x + NEIGHBOURS[n][0], c2.y + NEIGHBOURS[n][1],
						c2.z + NEIGHBOURS[n][2]);
					if (nb !== undefined && nb.kind !== 'gone') { held = true; }
				}
				if (!held) { c2.kind = 'gone'; }
			}
		}
	}

	// Hang `count` fruit on the crown: leaves with open air below, picked
	// in key order by the generator.
	function hangFruit(t, rng, count) {
		var cand = [];
		for (var i = 0; i < t.order.length; i++) {
			var c = t.cells[t.order[i]];
			if (c.kind === 'leaves') {
				var below = getCell(t, c.x, c.y - 1, c.z);
				if (below === undefined || below.kind === 'gone') { cand.push(t.order[i]); }
			}
		}
		cand.sort(function (a, b) { return a - b; });
		for (var n = 0; n < count && cand.length > 0; n++) {
			var at = rint(rng, 0, cand.length - 1);
			t.cells[cand[at]].kind = 'fruit';
			cand.splice(at, 1);
		}
	}

	// ---------------------------------------------------------------- finish

	// Limb bases: where a limb leaves the trunk sideways, its first cell is
	// the thicker base piece, whose level arms reach half a node into the
	// trunk cell and so close the gap to a slanted trunk face. A branch or a
	// lying log beside a stem log or quarter becomes a base; so does a twig
	// beside a quarter (it would leave a gap); a twig beside a log meets its
	// flat face and stays.
	function limbBases(t) {
		var turn = [];
		for (var i = 0; i < t.order.length; i++) {
			var k = t.order[i];
			var c = t.cells[k];
			if (t.stemSet[k] !== true && (c.kind === 'branch' || c.kind === 'twig' || c.kind === 'trunk')) {
				for (var n = 0; n < 6; n++) {
					var d = NEIGHBOURS[n];
					var nk = key(c.x + d[0], c.y, c.z + d[2]);
					var nb = t.cells[nk];
					if (d[1] === 0 && nb !== undefined && t.stemSet[nk] === true &&
						(nb.kind === 'quarter' || (nb.kind === 'trunk' && c.kind !== 'twig'))) {
						turn.push(c);
						break;
					}
				}
			}
		}
		for (var j = 0; j < turn.length; j++) { turn[j].kind = 'base'; }
	}

	function finish(t) {
		var nodes = [];
		var count = {trunk: 0, quarter: 0, base: 0, branch: 0, twig: 0, leaves: 0, fruit: 0};
		var minX = 999, maxX = -999, minZ = 999, maxZ = -999, maxY = -999;
		for (var i = 0; i < t.order.length; i++) {
			var c = t.cells[t.order[i]];
			if (c.kind !== 'gone') {
				nodes.push({k: t.order[i], x: c.x, y: c.y, z: c.z, kind: c.kind, rot: c.rot});
				count[c.kind] = count[c.kind] + 1;
				minX = imin(minX, c.x); maxX = imax(maxX, c.x);
				minZ = imin(minZ, c.z); maxZ = imax(maxZ, c.z);
				maxY = imax(maxY, c.y);
			}
		}
		nodes.sort(function (a, b) { return a.k - b.k; });
		for (var j = 0; j < nodes.length; j++) {
			var nd = nodes[j];
			nodes[j] = {x: nd.x, y: nd.y, z: nd.z, kind: nd.kind, rot: nd.rot};
		}
		return {
			species: t.species, seed: t.seed, nodes: nodes, count: count,
			wood: count.trunk + count.quarter + count.base + count.branch + count.twig,
			shapes: count.quarter + count.base + count.branch + count.twig,
			height: maxY + 1, width: maxX - minX + 1, depth: maxZ - minZ + 1,
			min: [minX, 0, minZ], max: [maxX, maxY, maxZ], facts: t.facts
		};
	}

	// ================================================================ species

	// The stem cell of layer y that lies furthest towards direction k: the
	// cell a limb growing that way leaves from.
	function trunkEdge(t, y, k) {
		var best = null, bestDot = -999999;
		for (var i = 0; i < t.stemList.length; i++) {
			var c = t.cells[t.stemList[i]];
			if (c.y === y && WOOD[c.kind] === true) {
				var dot = dirX(k) * c.x + dirZ(k) * c.z;
				if (dot > bestDot) { bestDot = dot; best = [c.x, c.z]; }
			}
		}
		return best;
	}

	// The first stem cell of layer y.
	function stemAt(t, y) {
		for (var i = 0; i < t.stemList.length; i++) {
			var c = t.cells[t.stemList[i]];
			if (c.y === y) { return [c.x, c.z]; }
		}
		return null;
	}

	// A branch from cell p in direction k: `out` nodes away, `up` nodes up.
	function shoot(t, p, k, out, up, cubes, thick) {
		return limb(t, p[0], p[1], p[2], p[0] + idiv(dirX(k) * out, 16), p[1] + up,
			p[2] + idiv(dirZ(k) * out, 16), cubes, thick, OUT_FIRST);
	}

	// APPLE: a short stout bole that opens into a ball. Three or four
	// scaffold limbs leave the top of the bole sideways and climb outwards
	// at about 45 degrees to the crown's rim, each in one upright plane (a
	// cardinal direction: a limb between two would zigzag in three axes).
	// At the rim each limb forks: one twig curves back up and in towards
	// the top of the ball, one runs sideways along the rim. The crown is a
	// round core with a cluster on every twig end: round, lumpy where the
	// twigs end.
	function apple(t, rng) {
		var w = chance(rng, 40) ? 2 : 1;
		var bole = w === 2 ? rint(rng, 3, 4) : rint(rng, 3, 5);
		var y;
		for (y = 0; y < bole; y++) {
			if (w === 2) { trunkLayer(t, y, 0, 0, 2); } else { stemCell(t, 0, y, 0, 'trunk', 0); }
		}
		var top = bole - 1;
		var rx = rint(rng, 60, 74);              // crown radius, 3.75..4.6 nodes
		var ry = rint(rng, 46, 54);              // crown half height
		var ax16 = w === 2 ? 0 : 8;              // trunk axis in p16
		var lean = chance(rng, 45) ? rint(rng, 0, 3) : -1;
		var cx = ax16, cz = ax16;
		if (lean >= 0) { cx = cx + CARD[lean][0] * 12; cz = cz + CARD[lean][1] * 12; }
		var cy = bole * 16 + ry - 12;
		cluster(t, cx, cy, cz, rx, ry, rx, -99);
		var limbs = w === 2 ? 4 : rint(rng, 3, 4);
		var c0 = rint(rng, 0, 3);
		var skip = rint(rng, 0, 3);
		for (var i = 0; i < 4; i++) {
			if (limbs === 4 || i !== skip) {
				var d = ((c0 + i) % 4) * 4;
				// a 2 x 2 bole: each limb leaves from the quarter beside it,
				// so the four turn like a pinwheel
				var st = trunkEdge(t, top, d + (w === 2 ? 2 : 0));
				var reach = idiv(rx * rint(rng, 64, 80), 100);
				var e1 = limb(t, st[0], top, st[1], cellOf(offX(cx, d, reach)), cellOf(cy + rint(rng, -6, 6)),
					cellOf(offZ(cz, d, reach)), 0, 70, OUT_FIRST);
				var path = t.path;
				cluster(t, mid(e1[0]), mid(e1[1]) + 2, mid(e1[2]), rint(rng, 30, 38), rint(rng, 26, 30),
					rint(rng, 30, 38), -99);
				// the fork: up and in, and sideways along the rim
				var ur = idiv(rx * rint(rng, 50, 70), 100);
				var e2 = limb(t, e1[0], e1[1], e1[2], cellOf(offX(cx, d, ur)), cellOf(cy + idiv(ry * rint(rng, 55, 75), 100)),
					cellOf(offZ(cz, d, ur)), 0, 0, UP_FIRST);
				cluster(t, mid(e2[0]), mid(e2[1]), mid(e2[2]), rint(rng, 26, 32), rint(rng, 24, 28),
					rint(rng, 26, 32), -99);
				if (path.length >= 3) {
					var mp = path[idiv(path.length * 2, 3)];
					var side = d + (chance(rng, 50) ? 3 : -3);
					var sr = idiv(rx * rint(rng, 70, 85), 100);
					var e3 = limb(t, mp[0], mp[1], mp[2], cellOf(offX(cx, side, sr)), mp[1] + 1,
						cellOf(offZ(cz, side, sr)), 0, 0, OUT_FIRST);
					cluster(t, mid(e3[0]), mid(e3[1]), mid(e3[2]), rint(rng, 24, 30), rint(rng, 22, 26),
						rint(rng, 24, 30), -99);
				}
			}
		}
		limbBases(t);
		fillLeaves(t, 62, 38, rint(rng, 1, 99999), 3);
		hangFruit(t, rng, rint(rng, 3, 7));
		t.facts = {trunk: w + 'x' + w, bole: bole, limbs: limbs,
			crown: (idiv(rx * 2, 16) + 1) + ' wide', lean: lean >= 0 ? ['+x', '+z', '-x', '-z'][lean] : 'none'};
	}

	// The cardinal step (dx, dz) of direction index 0..3 (DIR16 index 4 d).
	var CARD = [[1, 0], [0, 1], [-1, 0], [0, -1]];

	// JUNGLE: a tall stem that wanders, sheds its lower limbs and carries
	// its crown as separate clumps at the ends of rising limbs.
	function jungle(t, rng) {
		var h = rint(rng, 12, 15);              // total height target
		var top = h - 4;                         // last trunk layer
		var w = chance(rng, 30) ? 2 : 1;
		var wide = w === 2 ? top + 1 : 0;      // a 2 x 2 stem stays straight
		var x = 0, z = 0;
		// the stem wanders: one side-step low, often a second one higher up
		// that turns back or aside, so the stem swings round its foot
		// instead of leaning away
		var k1 = imax(wide + 1, rint(rng, 3, idiv(top, 2) - 1));
		var k2 = imax(k1 + 4, rint(rng, idiv(top, 2) + 2, top - 2));
		var d1 = rint(rng, 0, 3);
		var d2 = (d1 + rint(rng, 1, 3)) % 4;
		var kinks = w === 2 ? 0 : ((chance(rng, 60) && k2 <= top - 1) ? 2 : 1);
		var y;
		for (y = 0; y <= top; y++) {
			if ((kinks >= 1 && y === k1) || (kinks === 2 && y === k2)) {
				// the 1 x 1 stem steps aside: for one layer it stands on
				// two logs, a knee
				var d = y === k1 ? d1 : d2;
				stemCell(t, x + CARD[d][0], y - 1, z + CARD[d][1], 'trunk', 0);
				x = x + CARD[d][0]; z = z + CARD[d][1];
			}
			if (y < wide) {
				trunkLayer(t, y, 0, 0, 2);
			} else {
				stemCell(t, x, y, z, 'trunk', 0);
			}
		}
		var limbs = rint(rng, 3, 5);
		var a0 = rint(rng, 0, 15);
		var ly = top - 1;
		var low = idiv(top * 55, 100);
		var made = 0;
		for (var i = 0; i < limbs && ly >= low; i++) {
			var az = a0 + i * rint(rng, 5, 7);
			var st = trunkEdge(t, ly, az);
			var reach = rint(rng, 38, 58);
			var rise = rint(rng, 16, 36);
			var end = limb(t, st[0], ly, st[1], cellOf(offX(mid(st[0]), az, reach)), ly + cellOf(rise + 8),
				cellOf(offZ(mid(st[1]), az, reach)), 0, 50, OUT_FIRST);
			var crx = rint(rng, 34, 42);
			if (chance(rng, 40)) {
				// the limb forks into two twigs, a clump on each
				for (var f = -1; f <= 1; f += 2) {
					var fa = az + 3 * f;
					var fend = limb(t, end[0], end[1], end[2], end[0] + cellOf(dirX(fa) * 2 + 8),
						end[1] + 1, end[2] + cellOf(dirZ(fa) * 2 + 8), 0, 0, OUT_FIRST);
					cluster(t, mid(fend[0]), mid(fend[1]) + 10, mid(fend[2]), crx - 6, rint(rng, 26, 30), crx - 6, -99);
				}
			} else {
				cluster(t, mid(end[0]), mid(end[1]) + 10, mid(end[2]), crx, rint(rng, 28, 34), crx, -99);
			}
			made = made + 1;
			ly = ly - rint(rng, 2, 3);
		}
		// the leader ends in the highest clump
		var lead = rint(rng, 1, 2);
		var lx16 = mid(x), lz16 = mid(z);
		if (w === 2) {
			for (y = top + 1; y <= top + lead; y++) { trunkLayer(t, y, 0, 0, 2); }
			lx16 = 0; lz16 = 0;
		} else {
			column(t, x, top + 1, top + lead, z, 'branch');
		}
		cluster(t, lx16, mid(top + lead) + 8, lz16, rint(rng, 40, 48), rint(rng, 30, 36),
			rint(rng, 40, 48), -99);
		// small clumps low on the stem where a dormant bud broke out
		var buds = rint(rng, 0, 2);
		for (var j = 0; j < buds; j++) {
			var by = rint(rng, 3, idiv(top, 2));
			var bd = rint(rng, 0, 3);
			var bc = trunkEdge(t, by, bd * 4);
			if (bc !== null) {
				var bx = bc[0] + CARD[bd][0], bz = bc[1] + CARD[bd][1];
				if (getCell(t, bx, by, bz) === undefined && cleanStep(t, bx, by, bz, bc[0], by, bc[1])) {
					putCell(t, bx, by, bz, 'twig', CARD[bd][0] !== 0 ? 12 : 4);
					cluster(t, mid(bx + CARD[bd][0]), mid(by) + 6, mid(bz + CARD[bd][1]), 22, 18, 22, 0);
				}
			}
		}
		limbBases(t);
		fillLeaves(t, 58, 45, rint(rng, 1, 99999), 3);
		t.facts = {trunk: w + 'x' + w + ' wandering', kinks: kinks, clumps: made + 1};
	}

	// KAPOK: the emergent giant. A long clear column that steps in from
	// 3 x 3 to 2 x 2, then a broad high crown on wide, gently rising limbs.
	function kapok(t, rng) {
		var h = rint(rng, 22, 27);
		var w = chance(rng, 60) ? 3 : 2;
		var base = idiv(h * 60, 100) + rint(rng, -1, 1);   // crown base
		var ax2 = w === 3 ? 1 : 0, az2 = ax2;
		var narrow = w === 3 ? rint(rng, 6, 9) : base + 1;   // 3x3 -> 2x2
		var lean = rint(rng, 0, 3);
		var y;
		for (y = 0; y <= base; y++) {
			if (w === 3 && y === narrow) {
				ax2 = ax2 + (CARD[lean][0] + CARD[(lean + 1) % 4][0] < 0 ? -1 : 1);
				az2 = az2 + (CARD[lean][1] + CARD[(lean + 1) % 4][1] < 0 ? -1 : 1);
			}
			trunkLayer(t, y, ax2, az2, (w === 3 && y < narrow) ? 3 : 2);
		}
		// above the crown base the 2 x 2 column goes on as the leader
		var top = h - 4;
		for (y = base + 1; y <= top; y++) { trunkLayer(t, y, ax2, az2, 2); }
		var cx16 = ax2 * 8, cz16 = az2 * 8;
		var n1 = rint(rng, 4, 6);
		var a0 = rint(rng, 0, 15);
		for (var i = 0; i < n1; i++) {
			var az = a0 + idiv(16 * i, n1) + rint(rng, -1, 1);
			var sy = base - (i % 2);
			var st = trunkEdge(t, sy, az);
			var reach = rint(rng, 54, 70);
			var rise = rint(rng, 24, 56);
			var end = limb(t, st[0], sy, st[1], cellOf(offX(cx16, az, reach)), sy + cellOf(rise + 8),
				cellOf(offZ(cz16, az, reach)), 0, 70, OUT_FIRST);
			if (chance(rng, 50) && t.path.length >= 4) {
				// a clump hangs under the middle of the limb
				var hp = t.path[idiv(t.path.length, 2)];
				cluster(t, mid(hp[0]), mid(hp[1]), mid(hp[2]), rint(rng, 26, 32), rint(rng, 22, 26),
					rint(rng, 26, 32), -2);
			}
			for (var f = -1; f <= 1; f += 2) {
				var fa = az + 3 * f;
				var fend = limb(t, end[0], end[1], end[2], end[0] + cellOf(dirX(fa) + 8),
					end[1] + 1, end[2] + cellOf(dirZ(fa) + 8), 0, 0, UP_FIRST);
				cluster(t, mid(fend[0]), mid(fend[1]) + 10, mid(fend[2]), rint(rng, 36, 42),
					rint(rng, 24, 28), rint(rng, 36, 42), -2);
			}
		}
		// a second, shorter tier between the first tier's limbs
		var n2 = rint(rng, 2, 4);
		var y2 = base + rint(rng, 3, 4);
		for (var j = 0; j < n2; j++) {
			var bz = a0 + idiv(8, n1) + idiv(16 * j, n2) + rint(rng, -1, 1);
			var r2 = rint(rng, 32, 48);
			var s2 = trunkEdge(t, y2, bz);
			var e2 = limb(t, s2[0], y2, s2[1], cellOf(offX(cx16, bz, r2 + 8)), y2 + rint(rng, 1, 2),
				cellOf(offZ(cz16, bz, r2 + 8)), 0, 50, OUT_FIRST);
			cluster(t, mid(e2[0]), mid(e2[1]) + 10, mid(e2[2]), rint(rng, 36, 44), rint(rng, 24, 28),
				rint(rng, 36, 44), -2);
		}
		// the dome that joins the clumps, and the top
		cluster(t, cx16, mid(base + 5), cz16, rint(rng, 60, 72), rint(rng, 44, 52), rint(rng, 60, 72), -2);
		cluster(t, cx16, mid(top) + 6, cz16, rint(rng, 44, 52), rint(rng, 28, 32), rint(rng, 44, 52), -1);
		limbBases(t);
		fillLeaves(t, 60, 40, rint(rng, 1, 99999), 3);
		t.facts = {trunk: w + 'x' + w + (w === 3 ? ' to 2x2' : ''), crownBase: base, limbs: n1 + n2};
	}

	// ACACIA: a short trunk that forks into a wide V of thick limbs; every
	// limb end climbs to one common level and spreads into a flat pad: the
	// pads merge into an umbrella.
	function acacia(t, rng) {
		var h = rint(rng, 2, 4);
		var y;
		for (y = 0; y < h; y++) { stemCell(t, 0, y, 0, 'trunk', 0); }
		var limbs = chance(rng, 50) ? 2 : 3;
		var a0 = rint(rng, 0, 15);
		var tips = [];
		var top = 0;
		for (var i = 0; i < limbs; i++) {
			var az = a0 + (limbs === 2 ? i * rint(rng, 6, 8) : idiv(16 * i, 3) + rint(rng, -1, 1));
			var reach = rint(rng, 46, 64);
			var rise = rint(rng, 30, 44);
			var end = limb(t, 0, h - 1, 0, cellOf(offX(8, az, reach)), h - 1 + cellOf(rise + 8),
				cellOf(offZ(8, az, reach)), 0, 80, UP_FIRST);
			tips.push([end[0], end[1], end[2], az]);
			top = imax(top, end[1]);
		}
		var level = top + 1;
		var pads = [];
		for (var j = 0; j < tips.length; j++) {
			var tp = tips[j];
			// twigs climb from the limb end to the canopy level
			var up = limb(t, tp[0], tp[1], tp[2], tp[0], level - 1, tp[2], 0, 0, UP_FIRST);
			if (chance(rng, 55)) {
				for (var f = -1; f <= 1; f += 2) {
					var fa = tp[3] + 3 * f;
					var fe = limb(t, up[0], up[1], up[2], up[0] + cellOf(dirX(fa) * 2 + 8), up[1],
						up[2] + cellOf(dirZ(fa) * 2 + 8), 0, 0, OUT_FIRST);
					pads.push(fe);
				}
			} else {
				pads.push(up);
			}
		}
		for (var p = 0; p < pads.length; p++) {
			var r = rint(rng, 42, 52);
			cluster(t, mid(pads[p][0]), mid(level), mid(pads[p][2]), r, rint(rng, 20, 24), r, -1);
		}
		limbBases(t);
		fillLeaves(t, 55, 40, rint(rng, 1, 99999), 3);
		t.facts = {trunk: '1x1, ' + h + ' high', fork: limbs + ' limbs', canopy: 'at ' + level};
	}

	// PINE: a straight stem that thins from log to branch to twig, with a
	// whorl of short twigs every two (sometimes three) nodes; every whorl
	// carries a needle skirt, wide below, narrow above: a layered cone.
	function pine(t, rng) {
		var h = rint(rng, 12, 17);
		var bole = rint(rng, 2, 4);
		var apex = h - 1;
		var thick = idiv(h * 55, 100);
		column(t, 0, 0, thick, 0, 'trunk');
		column(t, 0, thick + 1, apex - 2, 0, 'branch');
		column(t, 0, apex - 1, apex - 1, 0, 'twig');
		var rbase = rint(rng, 50, 62);
		var turn = rint(rng, 0, 1);
		var y = bole;
		var whorls = 0;
		while (y <= apex - 3) {
			var r = idiv(rbase * (apex + 1 - y), apex + 1 - bole);
			var len = cellOf(r) - 1;
			var diag = (whorls + turn) % 2;
			for (var i = 0; i < 4 && len >= 1; i++) {
				var az = i * 4 + diag * 2;
				limb(t, 0, y, 0, cellOf(offX(8, az, len * 16)), y, cellOf(offZ(8, az, len * 16)), 0, 0, OUT_FIRST);
			}
			cluster(t, 8, mid(y), 8, r, 22, r, 0);
			whorls = whorls + 1;
			y = y + (chance(rng, 15) ? 3 : 2);
		}
		cluster(t, 8, mid(apex - 1), 8, 18, 30, 18, -1);
		putCell(t, 0, apex, 0, 'leaves', 0);
		limbBases(t);
		fillLeaves(t, 70, 22, rint(rng, 1, 99999), 3);
		t.facts = {trunk: '1x1 tapering', whorls: whorls, base: (idiv(rbase * 2, 16) + 1) + ' wide'};
	}

	// ASPEN: a slender pale stem, a long bare bole, then a narrow tall oval
	// crown on short twigs that spiral up the leader.
	function aspen(t, rng) {
		var h = rint(rng, 11, 15);
		var bole = rint(rng, 4, 6);
		var apex = h - 1;
		var bend = chance(rng, 40) ? rint(rng, 0, 3) : -1;
		var bendY = bole + idiv((apex - bole) * 2, 3);
		column(t, 0, 0, bole + 1, 0, 'trunk');
		var x = 0, z = 0;
		for (var y = bole + 2; y <= apex - 1; y++) {
			if (y === bendY && bend >= 0) {
				stemCell(t, x + CARD[bend][0], y - 1, z + CARD[bend][1], 'branch', 0);
				x = x + CARD[bend][0]; z = z + CARD[bend][1];
			}
			stemCell(t, x, y, z, y >= apex - 2 ? 'twig' : 'branch', 0);
		}
		var rx = rint(rng, 42, 52);
		var cy = idiv((bole + 1 + apex + 1) * 16, 2);
		var ry = (apex + 1 - bole) * 8 + 2;
		cluster(t, 8 + x * 8, cy, 8 + z * 8, rx, ry, rx, -99);
		var az = rint(rng, 0, 15);
		var y2 = bole + 1;
		while (y2 <= apex - 2) {
			var len = rint(rng, 1, 2);
			var c = stemAt(t, y2);
			var e = limb(t, c[0], y2, c[1], cellOf(offX(mid(c[0]), az, len * 16)), y2 + rint(rng, 0, 1),
				cellOf(offZ(mid(c[1]), az, len * 16)), 0, 0, OUT_FIRST);
			cluster(t, mid(e[0]), mid(e[1]) + 4, mid(e[2]), rint(rng, 20, 26), rint(rng, 18, 24),
				rint(rng, 20, 26), -99);
			az = az + 5;
			y2 = y2 + rint(rng, 1, 2);
		}
		limbBases(t);
		fillLeaves(t, 60, 35, rint(rng, 1, 99999), 3);
		t.facts = {trunk: '1x1 slender', bole: bole, crown: (idiv(rx * 2, 16) + 1) + ' wide'};
	}

	// SILVERWOOD: tall and elegant. A long clear slender bole (taller in
	// old trees), then a few limbs that step out once and rise parallel to the
	// leader; each carries a slim leaf column, together a flame.
	function silverwood(t, rng) {
		var old = chance(rng, 35);
		var h = old ? rint(rng, 19, 22) : rint(rng, 15, 18);
		var bole = rint(rng, 6, 8);
		var apex = h - 1;
		var x = 0, z = 0;
		column(t, x, 0, bole + 2, z, 'trunk');
		column(t, x, bole + 3, apex - 3, z, 'branch');
		column(t, x, apex - 2, apex - 1, z, 'twig');
		var limbs = old ? rint(rng, 4, 5) : rint(rng, 3, 4);
		var a0 = rint(rng, 0, 15);
		for (var i = 0; i < limbs; i++) {
			var az = a0 + idiv(16 * i, limbs) + rint(rng, -1, 1);
			var sy = bole + (i % 3);
			var so = rint(rng, 32, 44);
			var e1 = limb(t, x, sy, z, cellOf(offX(mid(x), az, so)), sy + 1, cellOf(offZ(mid(z), az, so)),
				0, 100, OUT_FIRST);
			var lt = apex - rint(rng, 3, 5);
			var e2 = limb(t, e1[0], e1[1], e1[2], e1[0], lt, e1[2], 0, 45, UP_FIRST);
			// the column reaches 2-3 below where the limb turns upright
			var rr = rint(rng, 28, 36);
			cluster(t, mid(e2[0]), idiv((e1[1] + lt + 2) * 16, 2) - 12, mid(e2[2]), rr,
				(lt - e1[1]) * 8 + 34, rr, -99);
		}
		cluster(t, mid(x), idiv((bole + 2 + apex + 1) * 16, 2), mid(z), rint(rng, 30, 36),
			(apex - bole) * 8 + 8, rint(rng, 30, 36), -99);
		limbBases(t);
		fillLeaves(t, 62, 32, rint(rng, 1, 99999), 3);
		t.facts = {trunk: '1x1', age: old ? 'old' : 'young', bole: bole, limbs: limbs};
	}

	// GRAVEWOOD: a dead tree. The stem bends one way as it climbs, a few
	// bare limbs reach out level or rising and end in two-pronged claws, a
	// quarter hooked up, a few drooping; a few grey tufts.
	function gravewood(t, rng) {
		var h = rint(rng, 6, 10);
		var top = h - 2;
		var lean = rint(rng, 0, 3);
		var k1 = rint(rng, 2, 3), k2 = chance(rng, 55) ? rint(rng, k1 + 2, imax(k1 + 2, top - 1)) : -1;
		var d2 = chance(rng, 60) ? lean : (lean + (chance(rng, 50) ? 1 : 3)) % 4;
		var x = 0, z = 0;
		for (var y = 0; y <= top; y++) {
			if (y === k1 || y === k2) {
				var d = y === k1 ? lean : d2;
				stemCell(t, x + CARD[d][0], y - 1, z + CARD[d][1], 'trunk', 0);
				x = x + CARD[d][0]; z = z + CARD[d][1];
			}
			stemCell(t, x, y, z, 'trunk', 0);
		}
		// a broken stub or a small fork at the top
		var sa = rint(rng, 0, 15);
		limb(t, x, top, z, x + cellOf(dirX(sa) + 8), top + 1, z + cellOf(dirZ(sa) + 8), 0, 50, UP_FIRST);
		var limbs = rint(rng, 3, 5);
		var a0 = lean * 4 + 8 + rint(rng, -2, 2);   // the limbs balance the lean
		var tips = [];
		for (var i = 0; i < limbs; i++) {
			var az = a0 + idiv(16 * i, limbs) + rint(rng, -1, 1);
			var ly = rint(rng, idiv(h * 45, 100), top);
			var c = trunkEdge(t, ly, az);
			var reach = rint(rng, 44, 70);
			var rise = rint(rng, -4, 16);
			var e = limb(t, c[0], ly, c[1], cellOf(offX(mid(c[0]), az, reach)), ly + cellOf(rise + 8),
				cellOf(offZ(mid(c[1]), az, reach)), 0, 55, OUT_FIRST);
			var end = rint(rng, 0, 19);          // 25 % hooked, 15 % drooping
			var prong = rint(rng, 0, 1);
			if (end < 5) {
				e = limb(t, e[0], e[1], e[2], e[0], e[1] + 1, e[2], 0, 0, UP_FIRST);
				prong = 1;
			} else if (end < 8) {
				e = limb(t, e[0], e[1], e[2], e[0] + cellOf(dirX(az) + 8), e[1] - 1,
					e[2] + cellOf(dirZ(az) + 8), 0, 0, OUT_FIRST);
				prong = -1;
			}
			// the claw: two prongs
			for (var f = -1; f <= 1; f += 2) {
				var fa = az + 3 * f;
				limb(t, e[0], e[1], e[2], e[0] + cellOf(dirX(fa) + 8), e[1] + prong,
					e[2] + cellOf(dirZ(fa) + 8), 0, 0, OUT_FIRST);
			}
			tips.push(e);
		}
		var tufts = rint(rng, 1, 4);
		for (var j = 0; j < tufts && j < tips.length; j++) {
			var tp = tips[rint(rng, 0, tips.length - 1)];
			cluster(t, mid(tp[0]), mid(tp[1]) + 8, mid(tp[2]), rint(rng, 18, 26), rint(rng, 14, 18),
				rint(rng, 18, 26), -1);
		}
		limbBases(t);
		fillLeaves(t, 50, 40, rint(rng, 1, 99999), 3);
		t.facts = {trunk: '1x1 bent', limbs: limbs, tufts: tufts};
	}

	// ================================================================ table

	var SPECIES = {
		apple: {salt: 1, grow: apple},
		jungle: {salt: 2, grow: jungle},
		kapok: {salt: 3, grow: kapok},
		acacia: {salt: 4, grow: acacia},
		pine: {salt: 5, grow: pine},
		aspen: {salt: 6, grow: aspen},
		silverwood: {salt: 7, grow: silverwood},
		gravewood: {salt: 8, grow: gravewood}
	};
	var ORDER = ['apple', 'jungle', 'kapok', 'acacia', 'pine', 'aspen', 'silverwood', 'gravewood'];

	function generate(species, seed) {
		var row = SPECIES[species];
		var t = newTree(species, seed);
		var rng = newRng(seed, row.salt);
		row.grow(t, rng);
		return finish(t);
	}

	var api = {generate: generate, ORDER: ORDER, WOOD: WOOD, quarterRot: quarterRot,
		newRng: newRng, rint: rint};
	if (typeof module !== 'undefined' && module.exports) { module.exports = api; }
	root.TreeGen = api;
})(typeof window !== 'undefined' ? window : this);
