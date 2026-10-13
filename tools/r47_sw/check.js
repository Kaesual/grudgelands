// Round 47 lane SW, concept: checks for the swamp patch, the swamp tree's
// own rules and the page.
//
//   node tools/r47_sw/check.js [patch seeds] [tree seeds]   (default 200, 500)
//
// Patch, every seed: the same seed gives the same patch; the border is land;
// a pool is 1 or 2 deep, never beside a lower column (all eight neighbours
// flat land or water), 2 deep only with water on all four sides; a waterlily
// floats on an inner pool column at y = 1; rooted reeds stand in a bank pool
// column's bed and reach above the water; land plants stand at h + 1 on
// land (a 2-high reed: its second node on the first), one per column, never
// in a tree's cell; cattails and bank reeds only beside water; trees stand
// with flat land 2 round their trunk and 8 apart.
// Swamp tree, every seed: the stem's foot stands 1-2 up; the only wood on
// y = 0 is the stilts' twigs, each with a branch or base above; at least
// one stilt; hanging moss hangs under leaves, wood or moss and lies within
// the leaf decay reach (3) of wood; the wood at most 15 wide (leaves 16). (check.js of the tree
// concept covers the rules every species shares.)
// Page: swamp.html's inline scripts parse, three.js is pinned, swamp.html
// is not stale (build.py --check is the authority; this only parses).
'use strict';
var fs = require('fs');
var path = require('path');
var vm = require('vm');
var G = require('../r46_tree/concept/treegen.js');
var P = require('./patch.js');

var NP = parseInt(process.argv[2] || '200', 10);
var NT = parseInt(process.argv[3] || '500', 10);
var failures = 0;
function fail(msg) { failures++; if (failures < 30) { console.log('FAIL ' + msg); } }

var LAND_PLANTS = {reeds: 1, cattail: 1, moss_carpet: 1, fern_1: 1, fern_2: 1, fern_3: 1, grass_3: 1,
	grass_4: 1, grass_5: 1, junglegrass: 1, dry_shrub: 1};
var agg = {water: 0, deep: 0, trees: 0, nodes: 0, lilies: 0};

for (var seed = 1; seed <= NP; seed++) {
	var p = P.generatePatch(seed, 48);
	if (JSON.stringify(p) !== JSON.stringify(P.generatePatch(seed, 48))) { fail('patch ' + seed + ' not deterministic'); }
	var S = p.size, x, z;
	var col = function (cx, cz) { return (cx < 0 || cz < 0 || cx >= S || cz >= S) ? null : p.cols[cx][cz]; };
	var nearWater = function (cx, cz) {
		return [[1, 0], [-1, 0], [0, 1], [0, -1]].some(function (d) { var c = col(cx + d[0], cz + d[1]); return c && c.pool > 0; });
	};
	for (x = 0; x < S; x++) {
		for (z = 0; z < S; z++) {
			var c = p.cols[x][z];
			if (!c.pool) { continue; }
			agg.water++;
			if (c.pool === 2) { agg.deep++; }
			if (x === 0 || z === 0 || x === S - 1 || z === S - 1) { fail('patch ' + seed + ' pool on the border'); }
			if (c.pool !== 1 && c.pool !== 2) { fail('patch ' + seed + ' pool depth ' + c.pool); }
			if (c.h !== 0) { fail('patch ' + seed + ' pool on a hummock'); }
			for (var dx = -1; dx <= 1; dx++) {
				for (var dz = -1; dz <= 1; dz++) {
					var n = col(x + dx, z + dz);
					if (!n || (!n.pool && n.h !== 0)) { fail('patch ' + seed + ' pool beside uneven ground at ' + x + ',' + z); }
					if (c.pool === 2 && dx * dz === 0 && (dx || dz) && !n.pool) { fail('patch ' + seed + ' 2-deep pool on the bank'); }
				}
			}
		}
	}
	// plants
	var taken = {};
	p.trees.forEach(function (t) {
		t.tree.nodes.forEach(function (nd) { taken[(t.x + nd.x) + ',' + (p.cols[t.x][t.z].h + 1 + nd.y) + ',' + (t.z + nd.z)] = true; });
	});
	var used = {};
	p.nodes.forEach(function (nd) {
		agg.nodes++;
		var c = p.cols[nd.x][nd.z], k = nd.x + ',' + nd.y + ',' + nd.z;
		if (nd.name === 'waterlily') {
			agg.lilies++;
			if (!c.pool || c.edge || nd.y !== 1 || nd.p2 < 0 || nd.p2 > 3) { fail('patch ' + seed + ' waterlily misplaced'); }
		} else if (nd.name === 'reeds_rooted') {
			if (!c.pool || !c.edge || nd.y !== -c.pool || nd.p2 % 16 !== 0 || nd.p2 / 16 <= c.pool) { fail('patch ' + seed + ' rooted reeds misplaced'); }
		} else if (LAND_PLANTS[nd.name]) {
			if (c.pool) { fail('patch ' + seed + ' ' + nd.name + ' in water'); }
			var second = nd.name === 'reeds' && nd.y === c.h + 2;
			if (nd.y !== c.h + 1 && !second) { fail('patch ' + seed + ' ' + nd.name + ' at the wrong height'); }
			if (second && !p.nodes.some(function (m) { return m.name === 'reeds' && m.x === nd.x && m.z === nd.z && m.y === c.h + 1; })) {
				fail('patch ' + seed + ' a floating reed');
			}
			if ((nd.name === 'reeds' || nd.name === 'cattail') && !nearWater(nd.x, nd.z)) { fail('patch ' + seed + ' ' + nd.name + ' away from water'); }
			if (taken[k]) { fail('patch ' + seed + ' ' + nd.name + ' inside a tree'); }
		} else {
			fail('patch ' + seed + ' unknown node ' + nd.name);
		}
		if (used[k]) { fail('patch ' + seed + ' two nodes in ' + k); }
		used[k] = true;
		if (!second && (nd.name !== 'reeds_rooted') && used[nd.x + ',col,' + nd.z]) { fail('patch ' + seed + ' two plants in a column'); }
		if (!second) { used[nd.x + ',col,' + nd.z] = true; }
	});
	// trees
	p.trees.forEach(function (t, i) {
		agg.trees++;
		var h = p.cols[t.x][t.z].h;
		for (var ax = -2; ax <= 2; ax++) {
			for (var az = -2; az <= 2; az++) {
				var fc = col(t.x + ax, t.z + az);
				if (!fc || fc.pool || fc.h !== h) { fail('patch ' + seed + ' tree without flat land round it'); }
			}
		}
		for (var j = 0; j < i; j++) {
			var o = p.trees[j];
			if ((o.x - t.x) * (o.x - t.x) + (o.z - t.z) * (o.z - t.z) < 64) { fail('patch ' + seed + ' trees too close'); }
		}
	});
}

// the swamp tree's own rules
var WOOD = G.WOOD;
var tree = {legs: 0, moss: 0, width: 0, minH: 99, maxH: 0};
for (var ts = 1; ts <= NT; ts++) {
	var t = G.generate('swamp', ts);
	var map = {};
	t.nodes.forEach(function (n) { map[n.x + ',' + n.y + ',' + n.z] = n; });
	var at = function (a, b, c) { return map[a + ',' + b + ',' + c]; };
	var stem = at(0, 1, 0) || at(0, 2, 0);
	if (!stem || stem.kind !== 'trunk' || at(0, 0, 0)) { fail('swamp ' + ts + ' stem foot not 1-2 up'); }
	var legs = 0;
	t.nodes.forEach(function (n) {
		if (n.y === 0 && WOOD[n.kind]) {
			var up = at(n.x, 1, n.z);
			if (n.kind !== 'twig' || !up || !(up.kind === 'branch' || up.kind === 'base')) { fail('swamp ' + ts + ' wood on the ground that is no stilt'); }
			legs++;
		}
		if (n.kind === 'moss') {
			tree.moss++;
			var above = at(n.x, n.y + 1, n.z);
			if (!above || !(above.kind === 'leaves' || above.kind === 'moss' || WOOD[above.kind])) { fail('swamp ' + ts + ' moss hangs from nothing'); }
			var near = false;
			for (var dx = -3; dx <= 3 && !near; dx++) {
				for (var dy = -3; dy <= 3 && !near; dy++) {
					for (var dz = -3; dz <= 3 && !near; dz++) {
						var w = at(n.x + dx, n.y + dy, n.z + dz);
						if (w && WOOD[w.kind]) { near = true; }
					}
				}
			}
			if (!near) { fail('swamp ' + ts + ' moss out of decay reach'); }
		}
	});
	if (legs < 1) { fail('swamp ' + ts + ' no stilt'); }
	var wx = t.nodes.filter(function (n) { return WOOD[n.kind]; });
	var span = function (k) { var v = wx.map(function (n) { return n[k]; }); return Math.max.apply(null, v) - Math.min.apply(null, v) + 1; };
	if (span('x') > 15 || span('z') > 15) { fail('swamp ' + ts + ' wood wider than 15'); }
	tree.legs += legs;
	tree.width += Math.max(t.width, t.depth);
	tree.minH = Math.min(tree.minH, t.height); tree.maxH = Math.max(tree.maxH, t.height);
}

// the page
var html = fs.readFileSync(path.join(__dirname, 'swamp.html'), 'utf8');
var re = /<script>([\s\S]*?)<\/script>/g, m, count = 0;
while ((m = re.exec(html)) !== null) {
	try { new vm.Script(m[1]); count++; } catch (e) { fail('inline script ' + count + ' does not parse: ' + e.message); }
}
if (!/three@0\.147\.0\/build\/three\.min\.js/.test(html)) { fail('three.js is not pinned to 0.147.0'); }
var art = /var ART_SET = (\[[^\]]*\])/.exec(html);

console.log('patches: ' + NP + ', water ' + (agg.water * 100 / (NP * 48 * 48)).toFixed(1) + ' % of columns (' +
	(agg.deep * 100 / Math.max(1, agg.water)).toFixed(0) + ' % of it 2 deep), ' + (agg.trees / NP).toFixed(1) +
	' trees, ' + (agg.nodes / NP).toFixed(0) + ' plant nodes per patch');
console.log('swamp trees: ' + NT + ', stilts ' + (tree.legs / NT).toFixed(2) + ', moss ' + (tree.moss / NT).toFixed(1) +
	', height ' + tree.minH + '-' + tree.maxH + ', mean width ' + (tree.width / NT).toFixed(1));
console.log(count + ' inline scripts parse; ART textures in the page: ' + (art ? JSON.parse(art[1]).length : 0));
console.log(failures ? failures + ' FAILURES' : 'PASS');
process.exit(failures ? 1 : 0);
