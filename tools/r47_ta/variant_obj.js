// Round 47 lane TA, probe only: a variant of the trunk quarter mesh whose two
// axis-side faces stretch the end grain's CENTRE texel row (through the
// rings' middle) instead of the cap's edge row, for a side-by-side capture.
//   node tools/r47_ta/variant_obj.js
// writes tools/r47_ta/grug_probe_r47_ta/models/r47ta_quarter_centre_row.obj
// (never shipped; the game's mesh is shapes.js's).
'use strict';
var fs = require('fs'), path = require('path');
var S = require('../r46_tree/concept/shapes.js');
var EDGE = 1 - 1 / 32, CENTRE = 0.5 + 1 / 32;
var obj = S.toObj('oct').split('\n').map(function (line) {
	var m = /^vt (\S+) (\S+)$/.exec(line);
	if (!m) { return line; }
	var u = Number(m[1]), v = Number(m[2]);
	// only the axis-side faces carry the edge row as a constant coordinate
	if (Math.abs(u - EDGE) < 1e-3) { u = CENTRE; }
	if (Math.abs(v - EDGE) < 1e-3) { v = CENTRE; }
	return 'vt ' + (Math.round(u * 10000) / 10000) + ' ' + (Math.round(v * 10000) / 10000);
}).join('\n');
var out = path.join(__dirname, 'grug_probe_r47_ta', 'models', 'r47ta_quarter_centre_row.obj');
fs.writeFileSync(out, obj);
console.log('wrote ' + path.relative(process.cwd(), out));
