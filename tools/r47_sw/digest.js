// Round 47 lane SW: the eight approved species stay exactly as they were.
//
//   node tools/r47_sw/digest.js           # compare with species_digest.txt
//   node tools/r47_sw/digest.js --write   # record the digests (baseline)
//
// For each approved species and seeds 1..500: the full generate() result
// (nodes, counts, facts, roots) on flat ground and on the bumpy ground of
// check.js, hashed per species. Adding the swamp species to treegen.js must
// leave every line of species_digest.txt unchanged.
'use strict';
var crypto = require('crypto');
var fs = require('fs');
var path = require('path');
var G = require('../r46_tree/concept/treegen.js');

var APPROVED = ['apple', 'jungle', 'kapok', 'acacia', 'pine', 'aspen', 'silverwood', 'gravewood'];
var SEEDS = 500;
var FILE = path.join(__dirname, 'species_digest.txt');

var lines = APPROVED.map(function (sp) {
	var h = crypto.createHash('sha256');
	for (var seed = 1; seed <= SEEDS; seed++) {
		var top = function (x, z) { return ((x + 50) * 7919 + (z + 50) * 104729 + seed * 31) % 3 - 1; };
		var bumpy = function (x, y, z) { return y < top(x, z); };
		h.update(JSON.stringify(G.generate(sp, seed)));
		h.update(JSON.stringify(G.generate(sp, seed, bumpy)));
	}
	return sp + ' ' + SEEDS + ' ' + h.digest('hex');
});
var text = lines.join('\n') + '\n';
if (process.argv[2] === '--write') {
	fs.writeFileSync(FILE, text);
	console.log('wrote ' + path.relative(process.cwd(), FILE));
	process.stdout.write(text);
	process.exit(0);
}
var want = fs.readFileSync(FILE, 'utf8');
process.stdout.write(text);
if (want !== text) { console.log('FAIL: an approved species changed'); process.exit(1); }
console.log('PASS: the eight approved species are unchanged (' + SEEDS + ' seeds, flat and bumpy ground)');
