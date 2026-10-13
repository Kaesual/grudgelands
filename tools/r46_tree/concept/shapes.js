// Round 46 lane TREE, step 3: the wood shapes of the tree concept, as data.
//
// Used by the viewer (inlined into trees.html) and by node:
//   node tools/r46_tree/concept/shapes.js        # writes models/*.obj
//
// Units are sixteenths of a node, centred on the node (-8..8), Luanti axes
// (x east, y up, z north). Four shapes per wood type:
//
//   quarter  MESH (drawtype "mesh", paramtype2 facedir 0..3): a quarter of
//            a chamfered trunk column. Its inner corner (the trunk axis) is
//            at +x +z for facedir 0. The outline seen from above runs from
//            the +x border to the +z border through PROFILES[name]. Caps
//            top and bottom; the two faces on the axis side (+x and +z for
//            facedir 0) are closed with the end grain (Round 47, the user:
//            a partly felled trunk shows cut wood, not a hollow shell).
//   branch   connected node box, 10/16 thick.
//   twig     connected node box, 6/16 thick; the only piece that also
//            connects to leaves (only to a leaf above it, see LEAF_SIDES)
//            and to the ground (only below it, see GROUND_SIDES).
//   base     connected node box, 12/16 thick: the first cell of a limb
//            that leaves a trunk sideways. Its four level arms reach 8/16
//            into the neighbour cell, so they meet a slanted trunk face
//            without a gap (the slant lies at most 8/16 inside the cell
//            border where the arm is) and, towards a branch, end half way
//            into it as a short sleeve (a taper 16 -> 12 -> 10); it also
//            joins the ground below it (roots, see GROUND_SIDES). Thicker
//            than the branch, so no face of it is coplanar with a branch
//            face. Node box extents up to +-1.0 node: inside the engine's
//            soft limit of +-1.45 (lua_api.md "Node boxes").
/* exported TreeShapes */
(function (root) {
	'use strict';

	// Outline points from the +x border (16, 0) to the +z border (0, 16),
	// measured outwards from the axis corner: (along x, along z).
	var PROFILES = {
		// octagon: half-width flat, one slant, half-width flat. The flats
		// are 7/16 so two quarters make a 14/16 face across their border;
		// the slant is 12.7/16 long: nearly a regular octagon.
		oct: [[16, 0], [16, 7], [7, 16], [0, 16]]
	};

	var BASE_HALF = 6, BASE_REACH = 16;     // arm ends 8/16 into the neighbour
	function connected(h, reach) {
		return {
			core: [-h, -h, -h, h, h, h],
			top: [-h, h, -h, h, 8, h], bottom: [-h, -8, -h, h, -h, h],
			front: [-h, -h, -reach, h, h, -h], back: [-h, -h, h, h, h, reach],
			left: [-reach, -h, -h, -h, h, h], right: [h, -h, -h, reach, h, h]
		};
	}
	var BOXES = {
		branch: connected(5, 8),
		twig: connected(3, 8),
		base: connected(BASE_HALF, BASE_REACH)
	};
	// Which neighbours each connected piece joins (the node's connects_to).
	var CONNECTS = {
		branch: {trunk: true, quarter: true, base: true, branch: true, twig: true},
		twig: {trunk: true, quarter: true, base: true, branch: true, twig: true, leaves: true},
		base: {trunk: true, quarter: true, base: true, branch: true, twig: true}
	};

	// Leaves get connect_sides = {"bottom"}; src/nodedef.cpp nodeboxConnects
	// then lets a twig join a leaf only through the twig's top: a twig end
	// reaches up into the foliage it carries, without arms into every leaf
	// around it.
	var LEAF_SIDES = {top: true};
	// Ground nodes (soil, sand, gravel, litter) get connect_sides = {"top"}
	// and the base and the twig list them in connects_to: they join the
	// ground only through their bottom. The branch does not, so a root lies
	// on the ground (base) or dives in (twig), never a stub under every cell.
	var GROUND_SIDES = {bottom: true};
	var GROUND_KINDS = {base: true, twig: true};

	// The quarter mesh at facedir 0 in node units (-0.5..0.5): side quads
	// and cap triangles, each vertex {p: [x, y, z], n: [x, y, z], uv: [u, v]}
	// with v = 0 at the bottom of the texture (OBJ convention). Bark: u runs
	// round the outline in node units (the texture repeats), v up the trunk,
	// so the grain runs along the trunk. Caps: planar, as a cube's top.
	function quarterMesh(name) {
		var pts = PROFILES[name];
		function cell(p) { return [(8 - p[0]) / 16, (8 - p[1]) / 16]; }
		var sides = [], caps = [];
		var s = 0;
		for (var i = 0; i + 1 < pts.length; i++) {
			var a = cell(pts[i]), b = cell(pts[i + 1]);
			var dx = pts[i + 1][0] - pts[i][0], dz = pts[i + 1][1] - pts[i][1];
			var len = Math.sqrt(dx * dx + dz * dz) / 16;
			// outward normal: away from the axis corner in outline coordinates,
			// then turned into cell coordinates (which run the other way)
			var ox = dz, oz = -dx;
			if (ox * (pts[i][0] + pts[i + 1][0]) + oz * (pts[i][1] + pts[i + 1][1]) < 0) { ox = -ox; oz = -oz; }
			var ol = Math.sqrt(ox * ox + oz * oz);
			var nx = -ox / ol, nz = -oz / ol;
			var n = [nx, 0, nz];
			sides.push([
				{p: [a[0], -0.5, a[1]], n: n, uv: [s, 0]},
				{p: [b[0], -0.5, b[1]], n: n, uv: [s + len, 0]},
				{p: [b[0], 0.5, b[1]], n: n, uv: [s + len, 1]},
				{p: [a[0], 0.5, a[1]], n: n, uv: [s, 1]}
			]);
			s = s + len;
		}
		// caps: a fan from the axis corner
		var axis = [0.5, 0.5];
		for (var c = 0; c + 1 < pts.length; c++) {
			var p1 = cell(pts[c]), p2 = cell(pts[c + 1]);
			[[0.5, 1], [-0.5, -1]].forEach(function (yy) {
				var y = yy[0], ny = yy[1];
				function v(q) { return {p: [q[0], y, q[1]], n: [0, ny, 0], uv: [q[0] + 0.5, q[1] + 0.5]}; }
				caps.push([v(axis), v(p1), v(p2)]);
			});
		}
		// The two axis-side faces, end grain (tile 1) like the caps: each
		// takes the top cap's texture coordinates along their shared top
		// edge, so the rings run on across that edge and down the face (the
		// face shows the end-grain picture standing up, hinged at the cap).
		var inner = [];
		// The +z face (x runs along it) and the +x face (z runs along it),
		// each the whole node side from the axis edge to the far border.
		[false, true].forEach(function (fixedX) {
			var quad = [];
			[[0.5, -0.5], [-0.5, -0.5], [-0.5, 0.5], [0.5, 0.5]].forEach(function (e) {
				var along = e[0], y = e[1];
				quad.push(fixedX ?
					{p: [0.5, y, along], n: [1, 0, 0], uv: [y + 0.5, along + 0.5]} :
					{p: [along, y, 0.5], n: [0, 0, 1], uv: [along + 0.5, y + 0.5]});
			});
			inner.push(quad);
		});
		return {sides: sides, caps: caps, inner: inner};
	}

	// A Wavefront OBJ for the engine: Luanti's loader negates x and flips v
	// (irr/src/COBJMeshFileLoader.cpp readVec3 / readUV, "change
	// handedness"), so x and v are written mirrored here. Two material
	// groups: caps and the two axis-side faces first (tile 1, *_tree_top),
	// sides second (tile 2, bark).
	function toObj(name) {
		var m = quarterMesh(name);
		var out = ['# Grudgelands R46 tree concept: trunk quarter piece "' + name + '"',
			'# facedir 0 = inner corner (trunk axis) at +x +z; 1 unit = 1 node',
			'# generated by tools/r46_tree/concept/shapes.js'];
		var vi = 0, lines = [];
		function fmt(x) { return (Math.round(x * 10000) / 10000).toString(); }
		function emit(poly, group) {
			var idx = [];
			poly.forEach(function (v) {
				out.push('v ' + fmt(-v.p[0]) + ' ' + fmt(v.p[1]) + ' ' + fmt(v.p[2]));
				out.push('vt ' + fmt(v.uv[0]) + ' ' + fmt(v.uv[1]));
				out.push('vn ' + fmt(-v.n[0]) + ' ' + fmt(v.n[1]) + ' ' + fmt(v.n[2]));
				vi = vi + 1;
				idx.push(vi + '/' + vi + '/' + vi);
			});
			group.push('f ' + idx.join(' '));
		}
		var caps = [], sides = [];
		m.caps.forEach(function (t) { emit(windOut(t), caps); });
		m.inner.forEach(function (q) { emit(windOut(q), caps); });
		m.sides.forEach(function (q) { emit(windOut(q), sides); });
		lines = out.concat(['g caps', 'usemtl caps'], caps, ['g bark', 'usemtl bark'], sides);
		return lines.join('\n') + '\n';
	}

	// Order a polygon counter-clockwise seen from its normal, in the OBJ's
	// mirrored (right-handed) frame.
	function windOut(poly) {
		var p = poly.map(function (v) { return [-v.p[0], v.p[1], v.p[2]]; });
		var n = [-poly[0].n[0], poly[0].n[1], poly[0].n[2]];
		var e1 = [p[1][0] - p[0][0], p[1][1] - p[0][1], p[1][2] - p[0][2]];
		var e2 = [p[2][0] - p[0][0], p[2][1] - p[0][1], p[2][2] - p[0][2]];
		var c = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
		if (c[0] * n[0] + c[1] * n[1] + c[2] * n[2] < 0) { return poly.slice().reverse(); }
		return poly;
	}

	var api = {PROFILES: PROFILES, BOXES: BOXES, CONNECTS: CONNECTS, LEAF_SIDES: LEAF_SIDES, GROUND_SIDES: GROUND_SIDES, GROUND_KINDS: GROUND_KINDS, quarterMesh: quarterMesh, toObj: toObj,
		BASE_HALF: BASE_HALF, BASE_REACH: BASE_REACH};
	if (typeof module !== 'undefined' && module.exports) {
		module.exports = api;
		if (require.main === module) {
			var fs = require('fs'), path = require('path');
			var dir = path.join(__dirname, 'models');
			if (!fs.existsSync(dir)) { fs.mkdirSync(dir); }
			Object.keys(PROFILES).forEach(function (name) {
				var file = path.join(dir, 'grug_tree_quarter_' + name + '.obj');
				fs.writeFileSync(file, toObj(name));
				console.log('wrote ' + path.relative(process.cwd(), file));
			});
		}
	}
	root.TreeShapes = api;
})(typeof window !== 'undefined' ? window : this);
