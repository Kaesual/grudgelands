// Round 51 lane VIEW: checks for the land viewer (land.html, land.js).
//
//   node tools/r47_sw/land_check.js [seeds]      (default 12)
//
// Page: content only (no doctype, html, head or body), a <title>, the
// <style> first, every inline script parses, three.js pinned to 0.147.0,
// under 16 MB. Data: every node a patch, kit or plant row uses has a
// definition, every texture it names is inlined, every item key is unique
// and a valid document id. Patches, per zone, biome, variant and seed: the
// same seed gives the same patch; nothing stands inside the ground or in
// another node's cell; a plant or prop stands on ground or on a node; a
// hanging liana hangs from leaves or another liana; today's patch holds no
// proposal item and a proposal item switched off places nothing; the
// skeleton set replaces the bone pile. Kit and plant rows build for every
// zone and every kit block names its drop.
'use strict';
var fs = require('fs');
var path = require('path');
var vm = require('vm');

var N = parseInt(process.argv[2] || '12', 10);
var failures = 0;
function fail(msg) { failures++; if (failures < 40) { console.log('FAIL ' + msg); } }

var html = fs.readFileSync(path.join(__dirname, 'land.html'), 'utf8');
if (/<!doctype|<html[\s>]|<head[\s>]|<body[\s>]/i.test(html)) { fail('land.html carries a document wrapper'); }
if (!/^<title>[^<]{3,40}<\/title>\s*<style>/.test(html)) { fail('land.html does not start with <title> and <style>'); }
if (!/three@0\.147\.0\/build\/three\.min\.js/.test(html)) { fail('three.js is not pinned to 0.147.0'); }
if (Buffer.byteLength(html) > 16 * 1024 * 1024) { fail('land.html is over 16 MB'); }
if (/\balert\(|\bconfirm\(|\bprompt\(|<iframe/.test(html)) { fail('land.html uses alert, confirm, prompt or an iframe'); }
var re = /<script>([\s\S]*?)<\/script>/g, m, scripts = 0;
while ((m = re.exec(html)) !== null) {
	try { new vm.Script(m[1]); scripts++; } catch (e) { fail('inline script ' + scripts + ' does not parse: ' + e.message); }
}
var sandbox = {};
vm.runInNewContext(/var TEXTURES = [\s\S]*?;\nvar LAND_DATA = [^\n]*;/.exec(html)[0] + '\nthis.T = TEXTURES; this.D = LAND_DATA;', sandbox);
var TEXTURES = sandbox.T;
var L = require('./land.js');
L.setData(sandbox.D);

function texturesOf(str) { return str.split('^').filter(function (t) { return t.charAt(0) !== '['; }); }
var checkedTex = {};
function checkTexture(str, where) {
	if (checkedTex[str]) { return; }
	checkedTex[str] = true;
	texturesOf(str).forEach(function (t) {
		if (TEXTURES[t.replace(/\.png$/, '')] === undefined) { fail(where + ': texture ' + t + ' is not inlined'); }
	});
}
var checkedNode = {};
function checkNode(name, where) {
	if (checkedNode[name]) { return; }
	checkedNode[name] = true;
	var def = L.def(name);
	if (!def) { fail(where + ': no definition for ' + name); return; }
	def.tiles.forEach(function (t) { checkTexture(t, name); });
	if (def.strand) { checkTexture(def.strand, name); }
	if (def.special) { checkTexture(def.special, name); }
	(def.boxes || []).forEach(function (b) {
		if (b.length !== 6 || b.some(function (v) { return v < -8 || v > 8; }) || b[0] >= b[3] || b[1] >= b[4] || b[2] >= b[5]) {
			fail(name + ': a box outside the node or inside out');
		}
	});
}
Object.keys(L.WOODS).forEach(function (sp) {
	var w = L.WOODS[sp];
	['bark', 'top', 'leaves', 'fruit', 'moss'].forEach(function (k) { if (w[k]) { checkTexture(w[k], 'wood ' + sp); } });
});
checkTexture('swamp/hanging_moss_strand.png', 'hanging moss');

// keys
var keys = {};
L.ITEMS.forEach(function (it) {
	if (keys[it.key]) { fail('duplicate key ' + it.key); }
	keys[it.key] = true;
	if (!/^[a-z0-9_]+(\.[a-z0-9_]+)+$/.test(it.key)) { fail('key ' + it.key + ' is not of the form zone.item'); }
	Object.keys(it.tex || {}).forEach(function (n) { it.tex[n].forEach(function (t) { checkTexture(t, it.key); }); });
	if (it.plant) { checkNode(it.plant, it.key); }
	if (it.piece && !L.propDef(it.piece)) { fail(it.key + ': no prop ' + it.piece); }
});
Object.keys(sandbox.D.props).forEach(function (id) { checkNode('prop:' + id, 'prop ' + id); });

// patches
var agg = {};
function onAll(zone, value) {
	var on = {};
	L.ITEMS.forEach(function (it) { if (it.zones.indexOf(zone) >= 0) { on[it.key] = value; } });
	return on;
}
L.ZONE_ORDER.forEach(function (zone) {
	L.ZONES[zone].biomes.forEach(function (biome) {
		for (var seed = 1; seed <= N; seed++) {
			['today', 'proposal', 'off'].forEach(function (v) {
				var opts = {seed: seed, biome: biome, variant: v === 'off' ? 'proposal' : v, on: v === 'off' ? onAll(zone, false) : {}, mult: {}};
				var p = L.generate(zone, opts);
				if (seed <= 3 && JSON.stringify(p) !== JSON.stringify(L.generate(zone, opts))) { fail(zone + ' ' + biome + ' ' + seed + ' not deterministic'); }
				var where = zone + '/' + biome + '/' + v + '/' + seed;
				checkPatch(p, where);
				var items = Object.keys(p.facts.items).filter(function (k) { return p.facts.items[k] > 0; });
				if (v !== 'proposal' && items.length) { fail(where + ': proposal items placed: ' + items.join(', ')); }
				if (v === 'proposal' && zone === 'undead' && p.nodes.some(function (n) { return n.name === 'grug_nodes:bone_pile'; })) {
					fail(where + ': a bone pile beside the skeleton set');
				}
				if (v === 'proposal') {
					var a = agg[zone] = agg[zone] || {};
					items.forEach(function (k) { a[k] = (a[k] || 0) + p.facts.items[k]; });
				}
			});
		}
	});
	var k = L.kit(zone, 1);
	checkPatch(k, zone + '/kit');
	k.blocks.forEach(function (b) { if (!b.drop) { fail(zone + '/kit: ' + b.name + ' names no drop'); } });
	k.list.forEach(function (e) {
		if (!k.nodes.some(function (n) { return n.item === e.item; }) && !k.trees.some(function (t) { return t.item === e.item; })) {
			fail(zone + '/kit: ' + e.label + ' built nothing');
		}
	});
	checkPatch(L.plants(zone), zone + '/plants');
});

function checkPatch(p, where) {
	var cell = {};
	p.nodes.forEach(function (n) { cell[n.x + ',' + n.y + ',' + n.z] = n; });
	p.trees.forEach(function (t) {
		t.nodes.forEach(function (n) { cell[(t.x + n.x) + ',' + (t.y + n.y) + ',' + (t.z + n.z)] = {name: 'tree:' + n.kind}; });
	});
	var used = {};
	p.nodes.forEach(function (n) {
		checkNode(n.name, where);
		var c = p.cols[n.x][n.z], k = n.x + ',' + n.y + ',' + n.z;
		if (used[k]) { fail(where + ': two nodes in ' + k); }
		used[k] = true;
		var def = L.def(n.name) || {};
		if (n.name === 'grug_nodes:mud_with_reeds') {
			if (n.y !== c.h || c.water === null) { fail(where + ': rooted reeds not in a pool bed'); }
			return;
		}
		if (n.y <= c.h) { fail(where + ': ' + n.name + ' inside the ground at ' + k); }
		if (c.water !== null && n.y <= c.water && def.draw !== 'lily') { fail(where + ': ' + n.name + ' in the water at ' + k); }
		var below = cell[n.x + ',' + (n.y - 1) + ',' + n.z];
		if (def.draw === 'hanging') {
			var above = cell[n.x + ',' + (n.y + 1) + ',' + n.z];
			if (!above || !(above.name === n.name || /leaves/.test(above.name))) { fail(where + ': a liana hangs from nothing at ' + k); }
		} else if (def.draw === 'plant' || def.draw === 'box' || def.draw === 'carpet') {
			var onGround = n.y === c.h + 1 || (def.draw === 'lily' && n.y === c.water + 1);
			if (!onGround && !below) { fail(where + ': ' + n.name + ' floats at ' + k); }
		}
	});
}

console.log(scripts + ' inline scripts parse; ' + Object.keys(TEXTURES).length + ' textures, ' + L.ITEMS.length + ' items, ' +
	Object.keys(sandbox.D.props).length + ' ARTL props');
L.ZONE_ORDER.forEach(function (zone) {
	var a = agg[zone] || {};
	var line = Object.keys(a).sort().map(function (k) { return k.replace(/^[a-z]+\./, '') + ' ' + (a[k] / N).toFixed(1); }).join(', ');
	console.log(zone + ' (per proposal patch, all its biomes): ' + (line || '-'));
});
console.log(failures ? failures + ' FAILURES' : 'PASS');
process.exit(failures ? 1 : 0);
