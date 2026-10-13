// Round 47 lane SW, concept: the seeded swamp patch generator.
//
// generatePatch(seed, size) returns one swamp patch as data, in Luanti node
// terms, for the page (and check.js) to draw and test:
//   cols[x][z] = {h, top, pool, edge}  ground top at y = h (0 or 1 on a
//                hummock); a pool column has its water at y = 0 down to
//                y = 1 - pool (pool 1 or 2 deep) on a mud bed below;
//   nodes      = [{x, y, z, name, p2}] everything above the ground: plants,
//                carpets, waterlilies, rooted reeds (y = the bed, p2 = the
//                leveled height in sixteenths, as plantlike_rooted takes it);
//   trees      = [{x, z, seed, tree}] swamp trees (TreeGen) standing on the
//                ground of (x, z), foot on y = h + 1.
// The rules are written down in DESIGN.md next to this file; each step below
// follows that text. The noise is integer value noise on a hash lattice, the
// same kind world_content.lua's reef_noise uses, so the build can follow it.
/* global TreeGen */
(function (root) {
	'use strict';

	var G = root.TreeGen || (typeof require !== 'undefined' ? require('../r46_tree/concept/treegen.js') : null);

	// ------------------------------------------------------------- noise

	function hash(x, z, salt) {
		var v = ((x + 4096) * 374761 + (z + 4096) * 668265 + salt * 83491) % 16777213;
		v = (v * 48271) % 16777213;
		v = (v * 48271) % 16777213;
		return v;
	}

	// A mixed hash: the plain linear one above makes visible axis-aligned
	// runs (world_content.lua notes the same for its plants), so a second
	// round on a folded value breaks them.
	function mix(x, z, salt) {
		var a = hash(x * 37 + z * 11, x * 7 - z * 29, salt);
		return hash(a % 4093, idiv(a, 4093) % 4093 + x * 53 - z * 17, salt + 157);
	}

	// Smooth value noise in [0, 1024) with the given period (nodes).
	function noise(x, z, period, salt) {
		var ix = Math.floor(x / period), iz = Math.floor(z / period);
		var tx = (x - ix * period) / period, tz = (z - iz * period) / period;
		tx = tx * tx * (3 - 2 * tx); tz = tz * tz * (3 - 2 * tz);
		var a = mix(ix, iz, salt) % 1024, b = mix(ix + 1, iz, salt) % 1024;
		var c = mix(ix, iz + 1, salt) % 1024, d = mix(ix + 1, iz + 1, salt) % 1024;
		return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz;
	}

	// Two octaves: a broad shape and a finer edge.
	function noise2(x, z, period, salt) {
		return idiv(noise(x, z, period, salt) * 2 + noise(x, z, idiv(period, 2) + 1, salt + 7), 3);
	}

	function idiv(a, b) { return Math.floor(a / b); }

	// A per-column roll in [0, 100) for a named use.
	function roll(x, z, salt) { return mix(x, z, salt) % 100; }

	// ----------------------------------------------------------- the rules

	var RULES = {
		hummock: 700,        // noise above: the column is a hummock, 1 up
		pool: 370,           // noise below: open water (on flat ground only)
		deep: 290,           // noise below, and every side neighbour water: 2 deep
		mudLight: 360,       // ground noise below: the lighter mud
		wetGrass: 680,       // ground noise above: wet grass
		mottled: 2,          // within this of a pool: the mottled mud
		treeSpacing: 8,      // nodes between trunks at least
		treeTries: 40,       // tree spots tried per patch
		treeClear: 2         // the stilts reach 2: this much flat land round a trunk
	};

	// Plant chances in percent per column (the build's decoration rows).
	var PLANTS = {
		lily: 22,            // a pool column away from the bank: a waterlily
		rootedReed: 30,      // a pool column on the bank: reeds rooted in the bed
		bankReed: 32,        // a land column beside water: reeds (1-2 high)
		bankCattail: 18,     // ... else cattails
		grassWet: 34,        // wet grass: tall grass
		grassMud: 9,         // mud: tall grass
		fernShade: 30,       // within 3 of a trunk: a fern
		fernMoss: 22,        // mossy dirt: a fern
		carpetShade: 40,     // mud within 3 of a trunk: a moss carpet
		carpetBank: 12,      // mud beside water: a moss carpet
		carpet: 4,           // mud elsewhere: a moss carpet
		shrub: 1             // a dry shrub anywhere on land
	};

	function generatePatch(seed, size) {
		size = size || 48;
		var s = seed * 7;
		var cols = [];
		var x, z, i;
		function col(cx, cz) { return (cx < 0 || cz < 0 || cx >= size || cz >= size) ? null : cols[cx][cz]; }
		// 1. terrain: flat mud, low hummocks
		for (x = 0; x < size; x++) {
			cols.push([]);
			for (z = 0; z < size; z++) {
				var hn = noise2(x, z, 9, s + 1);
				cols[x].push({h: hn > RULES.hummock ? 1 : 0, top: 'mud', pool: 0, edge: false,
					wn: noise2(x, z, 11, s + 2), gn: noise2(x, z, 6, s + 3)});
			}
		}
		// 2. pools: low water noise on flat ground whose eight neighbours are
		// flat too (no water ever stands beside a lower column), the patch
		// border stays land; 2 deep where the noise is lower still and every
		// side neighbour is water
		for (x = 1; x < size - 1; x++) {
			for (z = 1; z < size - 1; z++) {
				var c = cols[x][z];
				if (c.wn < RULES.pool) {
					var flat = true;
					for (var dx = -1; dx <= 1; dx++) {
						for (var dz = -1; dz <= 1; dz++) {
							if (cols[x + dx][z + dz].h !== 0) { flat = false; }
						}
					}
					if (flat) { c.pool = 1; }
				}
			}
		}
		var SIDES = [[1, 0], [-1, 0], [0, 1], [0, -1]];
		for (x = 0; x < size; x++) {
			for (z = 0; z < size; z++) {
				var pc = cols[x][z];
				if (pc.pool) {
					var inner = true;
					for (i = 0; i < 4; i++) {
						var nb = col(x + SIDES[i][0], z + SIDES[i][1]);
						if (!nb || !nb.pool) { inner = false; }
					}
					pc.edge = !inner;
					if (inner && pc.wn < RULES.deep) { pc.deep = true; }
				}
			}
		}
		for (x = 0; x < size; x++) {
			for (z = 0; z < size; z++) { if (cols[x][z].deep) { cols[x][z].pool = 2; } }
		}
		// distance of every land column to water (4-neighbour steps, up to 4)
		var wet = [];
		for (x = 0; x < size; x++) {
			wet.push([]);
			for (z = 0; z < size; z++) { wet[x].push(cols[x][z].pool ? 0 : 99); }
		}
		for (var pass = 1; pass <= 4; pass++) {
			for (x = 0; x < size; x++) {
				for (z = 0; z < size; z++) {
					if (wet[x][z] === 99) {
						for (i = 0; i < 4; i++) {
							var wx = x + SIDES[i][0], wz = z + SIDES[i][1];
							if (wx >= 0 && wz >= 0 && wx < size && wz < size && wet[wx][wz] === pass - 1) { wet[x][z] = pass; }
						}
					}
				}
			}
		}
		// 3. trees: spots in seeded order on flat land with flat land round
		// them (the stilts), at least treeSpacing apart
		var rng = G.newRng(seed, 47);
		var trees = [];
		for (var t = 0; t < RULES.treeTries; t++) {
			var tx = G.rint(rng, 2, size - 3), tz = G.rint(rng, 2, size - 3);
			var ok = true;
			for (var ax = -RULES.treeClear; ax <= RULES.treeClear && ok; ax++) {
				for (var az = -RULES.treeClear; az <= RULES.treeClear && ok; az++) {
					var fc = col(tx + ax, tz + az);
					if (!fc || fc.pool || fc.h !== cols[tx][tz].h) { ok = false; }
				}
			}
			for (i = 0; i < trees.length && ok; i++) {
				var ddx = trees[i].x - tx, ddz = trees[i].z - tz;
				if (ddx * ddx + ddz * ddz < RULES.treeSpacing * RULES.treeSpacing) { ok = false; }
			}
			if (ok) {
				var ts = seed * 1000 + t;
				trees.push({x: tx, z: tz, seed: ts, tree: G.generate('swamp', ts)});
			}
		}
		var shade = [];
		for (x = 0; x < size; x++) {
			shade.push([]);
			for (z = 0; z < size; z++) {
				var near = false;
				for (i = 0; i < trees.length; i++) {
					if (Math.abs(trees[i].x - x) <= 3 && Math.abs(trees[i].z - z) <= 3) { near = true; }
				}
				shade[x].push(near);
			}
		}
		// the cells the trees take (no plant may stand in them)
		var taken = {};
		trees.forEach(function (tr) {
			tr.tree.nodes.forEach(function (n) {
				taken[(tr.x + n.x) + ',' + (cols[tr.x][tr.z].h + 1 + n.y) + ',' + (tr.z + n.z)] = true;
			});
		});
		// 4. the ground mix
		for (x = 0; x < size; x++) {
			for (z = 0; z < size; z++) {
				var g = cols[x][z];
				if (g.pool) { g.top = 'mud'; continue; }
				if (g.h === 1) {
					g.top = g.gn > 600 ? 'dirt_with_moss' : 'wet_grass';
				} else if (wet[x][z] <= RULES.mottled) {
					g.top = 'mud_mottled';
				} else if (shade[x][z] && g.gn > 560) {
					g.top = 'dirt_with_moss';
				} else if (g.gn > RULES.wetGrass) {
					g.top = 'wet_grass';
				} else if (g.gn < RULES.mudLight) {
					g.top = 'mud_light';
				} else {
					g.top = 'mud';
				}
			}
		}
		// 5. plants, one per column at most, in the cell above the ground
		// (rooted reeds: in the bed under the water)
		var nodes = [];
		function put(px, py, pz, name, p2) { nodes.push({x: px, y: py, z: pz, name: name, p2: p2 || 0}); }
		for (x = 0; x < size; x++) {
			for (z = 0; z < size; z++) {
				var k = cols[x][z];
				var r = roll(x, z, s + 11), r2 = roll(x, z, s + 13), r3 = roll(x, z, s + 17);
				if (k.pool) {
					if (k.edge && r < PLANTS.rootedReed) {
						// in the bed, up to 1-2 nodes above the water
						put(x, -k.pool, z, 'reeds_rooted', (k.pool + 1 + (r2 < 50 ? 1 : 0)) * 16);
					} else if (!k.edge && r < PLANTS.lily) {
						put(x, 1, z, 'waterlily', r2 % 4);
					}
					continue;
				}
				var y = k.h + 1;
				if (taken[x + ',' + y + ',' + z]) { continue; }
				var mudTop = k.top === 'mud' || k.top === 'mud_light' || k.top === 'mud_mottled';
				if (wet[x][z] === 1 && r < PLANTS.bankReed) {
					var tall = r2 < 45 && !taken[x + ',' + (y + 1) + ',' + z];
					put(x, y, z, 'reeds');
					if (tall) { put(x, y + 1, z, 'reeds'); }
				} else if (wet[x][z] === 1 && r < PLANTS.bankReed + PLANTS.bankCattail) {
					put(x, y, z, 'cattail');
				} else if (mudTop && shade[x][z] && r < PLANTS.carpetShade) {
					put(x, y, z, 'moss_carpet');
				} else if (mudTop && wet[x][z] === 1 && r < PLANTS.bankReed + PLANTS.bankCattail + PLANTS.carpetBank) {
					put(x, y, z, 'moss_carpet');
				} else if (shade[x][z] && r2 < PLANTS.fernShade) {
					put(x, y, z, 'fern_' + (1 + r3 % 3));
				} else if (k.top === 'dirt_with_moss' && r2 < PLANTS.fernMoss) {
					put(x, y, z, 'fern_' + (1 + r3 % 3));
				} else if (k.top === 'wet_grass' && r < PLANTS.grassWet) {
					put(x, y, z, r3 < 25 ? 'junglegrass' : 'grass_' + (3 + r3 % 3));
				} else if (mudTop && r < PLANTS.grassMud) {
					put(x, y, z, r3 < 30 ? 'junglegrass' : 'grass_' + (3 + r3 % 3));
				} else if (mudTop && r3 < PLANTS.carpet) {
					put(x, y, z, 'moss_carpet');
				} else if (r2 >= 100 - PLANTS.shrub) {
					put(x, y, z, 'dry_shrub');
				}
			}
		}
		// the facts the page shows
		var count = {land: 0, pool1: 0, pool2: 0, hummock: 0};
		var tops = {};
		for (x = 0; x < size; x++) {
			for (z = 0; z < size; z++) {
				var q = cols[x][z];
				if (q.pool === 1) { count.pool1++; } else if (q.pool === 2) { count.pool2++; } else { count.land++; }
				if (q.h === 1) { count.hummock++; }
				if (!q.pool) { tops[q.top] = (tops[q.top] || 0) + 1; }
				delete q.wn; delete q.gn; delete q.deep;
			}
		}
		var plants = {};
		nodes.forEach(function (n) { plants[n.name] = (plants[n.name] || 0) + 1; });
		return {seed: seed, size: size, cols: cols, nodes: nodes, trees: trees,
			facts: {columns: count, ground: tops, plants: plants, trees: trees.length}};
	}

	var api = {generatePatch: generatePatch, RULES: RULES, PLANTS: PLANTS};
	if (typeof module !== 'undefined' && module.exports) { module.exports = api; }
	root.SwampPatch = api;
})(typeof window !== 'undefined' ? window : this);
