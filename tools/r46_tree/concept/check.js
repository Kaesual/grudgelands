// Round 46 lane TREE, step 2: checks for the concept generator and page.
//
//   node tools/r46_tree/concept/check.js [seeds]
//
// For every species and seeds 1..N (default 500): the same seed gives the
// same node list twice; the tree fits 16 x 16 nodes and 32 high; no node
// below the ground; all wood is one face-connected piece standing on the
// ground; every leaf has wood within the leaf decay reach (3, cube search);
// quarter pieces carry facedir 0..3, branch/twig/log grain 0, 4 or 12.
// Then the inline scripts of trees.html must parse.
'use strict';
var fs = require('fs');
var path = require('path');
var vm = require('vm');
var G = require('./treegen.js');

var N = parseInt(process.argv[2] || '500', 10);
var WOOD = {trunk: true, quarter: true, branch: true, twig: true};
var failures = 0;
function fail(msg) { failures++; if (failures < 30) { console.log('FAIL ' + msg); } }

var summary = [];
G.ORDER.forEach(function (sp) {
	var agg = {wood: 0, leaves: 0, shapes: 0, height: 0, maxH: 0, maxW: 0, minH: 99};
	for (var seed = 1; seed <= N; seed++) {
		var a = G.generate(sp, seed);
		var b = G.generate(sp, seed);
		if (JSON.stringify(a.nodes) !== JSON.stringify(b.nodes)) { fail(sp + ' ' + seed + ' not deterministic'); }
		var map = {};
		var minX = 99, maxX = -99, minZ = 99, maxZ = -99, maxY = -99;
		a.nodes.forEach(function (n) {
			var k = n.x + ',' + n.y + ',' + n.z;
			if (map[k]) { fail(sp + ' ' + seed + ' duplicate ' + k); }
			map[k] = n;
			minX = Math.min(minX, n.x); maxX = Math.max(maxX, n.x);
			minZ = Math.min(minZ, n.z); maxZ = Math.max(maxZ, n.z);
			maxY = Math.max(maxY, n.y);
			if (n.y < 0) { fail(sp + ' ' + seed + ' node below ground'); }
			if (n.kind === 'quarter' && !(n.rot >= 0 && n.rot <= 3)) { fail(sp + ' ' + seed + ' quarter rot ' + n.rot); }
			if ((n.kind === 'trunk' || n.kind === 'branch' || n.kind === 'twig') && [0, 4, 12].indexOf(n.rot) < 0) {
				fail(sp + ' ' + seed + ' grain rot ' + n.rot);
			}
		});
		if (maxX - minX + 1 > 16 || maxZ - minZ + 1 > 16) { fail(sp + ' ' + seed + ' wider than 16'); }
		if (maxY + 1 > 32) { fail(sp + ' ' + seed + ' higher than 32'); }
		// wood: one face-connected piece touching y = 0
		var wood = a.nodes.filter(function (n) { return WOOD[n.kind]; });
		var seen = {}, stack = [];
		wood.forEach(function (n) { if (n.y === 0) { seen[n.x + ',0,' + n.z] = true; stack.push(n); } });
		if (!stack.length) { fail(sp + ' ' + seed + ' no wood on the ground'); }
		while (stack.length) {
			var c = stack.pop();
			[[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]].forEach(function (d) {
				var k = (c.x + d[0]) + ',' + (c.y + d[1]) + ',' + (c.z + d[2]);
				var nb = map[k];
				if (nb && WOOD[nb.kind] && !seen[k]) { seen[k] = true; stack.push(nb); }
			});
		}
		if (Object.keys(seen).length !== wood.length) { fail(sp + ' ' + seed + ' wood in ' + 'more than one piece'); }
		// leaves within reach 3 of wood (cube search)
		a.nodes.forEach(function (n) {
			if (n.kind !== 'leaves') { return; }
			for (var dx = -3; dx <= 3; dx++) {
				for (var dy = -3; dy <= 3; dy++) {
					for (var dz = -3; dz <= 3; dz++) {
						var nb = map[(n.x + dx) + ',' + (n.y + dy) + ',' + (n.z + dz)];
						if (nb && WOOD[nb.kind]) { return; }
					}
				}
			}
			fail(sp + ' ' + seed + ' leaf out of decay reach');
		});
		agg.wood += a.wood; agg.leaves += a.count.leaves; agg.shapes += a.shapes; agg.height += a.height;
		agg.maxH = Math.max(agg.maxH, a.height); agg.minH = Math.min(agg.minH, a.height);
		agg.maxW = Math.max(agg.maxW, maxX - minX + 1, maxZ - minZ + 1);
	}
	summary.push(sp + ': mean wood ' + (agg.wood / N).toFixed(1) + ', leaves ' + (agg.leaves / N).toFixed(1) +
		', shape nodes ' + (agg.shapes / N).toFixed(1) + ', height ' + agg.minH + '-' + agg.maxH +
		' (mean ' + (agg.height / N).toFixed(1) + '), widest ' + agg.maxW);
});
summary.forEach(function (l) { console.log(l); });

// the page's inline scripts parse
var html = fs.readFileSync(path.join(__dirname, 'trees.html'), 'utf8');
var re = /<script>([\s\S]*?)<\/script>/g, m, count = 0;
while ((m = re.exec(html)) !== null) {
	try { new vm.Script(m[1]); count++; } catch (e) { fail('inline script ' + count + ' does not parse: ' + e.message); }
}
if (!/three@0\.147\.0\/build\/three\.min\.js/.test(html)) { fail('three.js is not pinned to 0.147.0'); }
console.log(count + ' inline scripts parse');
console.log(failures ? failures + ' FAILURES' : 'PASS (' + N + ' seeds x ' + G.ORDER.length + ' species)');
process.exit(failures ? 1 : 0);
