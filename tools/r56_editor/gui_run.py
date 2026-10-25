#!/usr/bin/env python3
"""The template editor's GUI checklist path in a headless Chromium, on a
disposable clone (never the working tree), with screenshots.

    python3 tools/r56_editor/gui_run.py [SHOT_DIR]

Real clicks and keys through the DevTools protocol (cdp.py): the template
list, open a building, noclip through it, the edit rules of model.js on a
copy of the document (multi-cell placement and removal, the locked door
cell, turning, flipping, points), then on the grid: a bed and a door on
layer 1, the locked cell above the door on layer 2, a block on layer 3, undo,
reset, a walled-in entrance refused by Save, a valid edit saved and the file
on disk changed, a seat flipped with the Flip button and saved (a torch
refused),
the fixed-node flag and "used 2x" on the shared template, a draft
restored after a reload. Exits 1 on the first failure. Needs chromium and
network access to the pinned three.js on the CDN.
"""

import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import cdp  # noqa: E402
import common  # noqa: E402

TPL = "hearthpine_west_home"
SHARED = "dawnmere_tollhouse"
CHECKS = [0]


def check(cond, what):
    CHECKS[0] += 1
    if not cond:
        raise SystemExit("FAIL: %s" % what)


# The rules of model.js on a fresh copy of the open document; returns the
# failures (empty when every rule holds).
MODEL_CHECKS = r"""
(() => {
  const E = window.__editor, D = E.doc.constructor, fails = [];
  let count = 0;
  const ok = (c, what) => { count++; if (!c) fails.push(what); };
  const d = new D(E.tpl);
  const free = (x, y, z) => d.get(x, y, z) === "." || d.get(x, y, z) === " ";
  // an interior cell on layer 1 with free cells above it and to its north
  let spot = null;
  for (let x = 1; x < 8 && !spot; x++) for (let z = 1; z < 7 && !spot; z++)
    if (d.get(x, 1, z) === "." && d.get(x, 2, z) === "." && d.get(x, 1, z + 1) === "." && d.get(x, 2, z + 1) === ".") spot = [x, z];
  ok(spot, "a free spot exists");
  const [x, z] = spot;
  let rec = d.begin();
  ok(d.apply(rec, x, 1, z, { kind: "door", variant: "_a", o: 1 }).ok, "a door is placed");
  d.commit(rec);
  ok(d.partKind(x, 1, z) === "leaf" && d.partKind(x, 2, z) === "hidden", "the door takes its cell and the one above");
  ok(d.entry(d.get(x, 2, z)).o[1] === 1, "door_hidden faces as the leaf for _a");
  rec = d.begin();
  ok(!d.apply(rec, x, 2, z, { kind: "entry", text: "role wall" }).ok, "the cell above a door is locked");
  ok(d.partKind(x, 2, z) === "hidden", "a refused paint changes nothing");
  ok(d.apply(rec, x, 2, z, { kind: "air" }).ok && free(x, 1, z) && free(x, 2, z), "emptying the upper cell removes the whole door");
  d.commit(rec);
  d.undo();
  ok(d.partKind(x, 1, z) === "leaf" && d.partKind(x, 2, z) === "hidden", "undo brings the whole door back");
  rec = d.begin();
  ok(d.apply(rec, x, 1, z, { kind: "entry", text: "role wall" }).ok, "painting over the leaf");
  ok(d.entry(d.get(x, 1, z)).name === "wall" && d.get(x, 2, z) === ".", "replaces the leaf and empties the upper cell");
  d.commit(rec); d.undo();
  rec = d.begin();
  ok(!d.apply(rec, x, 0, z, { kind: "door", variant: "_b", o: 0 }).ok, "no door where the cell above is taken");
  ok(d.apply(rec, x, 1, z, { kind: "door", variant: "_b", o: 2 }).ok && d.entry(d.get(x, 2, z)).o[1] === 1, "_b: door_hidden at (o + 3) % 4");
  d.commit(rec); d.undo(); d.undo();
  ok(free(x, 1, z) && free(x, 2, z), "undo to the start");
  // a bed: two cells along its facing, placed only on free cells
  rec = d.begin();
  ok(d.apply(rec, x, 1, z, { kind: "bed", role: "bed", o: 0 }).ok, "a bed is placed");
  ok(d.partKind(x, 1, z) === "bottom" && d.partKind(x, 1, z + 1) === "top", "the bed takes two cells along facedir 0");
  ok(d.object(x, 1, z + 1).cells.length === 2, "the head knows its foot");
  const blocked = !free(x + 1, 1, z);
  const turn = d.rotate(rec, x, 1, z + 1, () => "facedir");
  d.commit(rec);
  if (blocked) ok(!turn.ok && d.partKind(x, 1, z + 1) === "top", "a bed does not turn onto a taken cell");
  else ok(turn.ok && d.facing(x, 1, z) === 1 && d.partKind(x + 1, 1, z) === "top" && free(x, 1, z + 1),
    "a turned bed moves its head along the new facing");
  rec = d.begin();
  ok(d.apply(rec, x, 1, z, { kind: "unchanged" }).ok, "emptying a bed");
  ok(d.get(x, 1, z) === " " && free(x, 1, z + 1) && free(x + 1, 1, z), "removes it as a whole");
  d.commit(rec);
  rec = d.begin();
  const wallKey = d.keyFor("role wall");
  d.put(rec, x, 1, z + 1, wallKey);
  ok(!d.apply(rec, x, 1, z, { kind: "bed", role: "bed", o: 0 }).ok, "no bed where its head cell is taken");
  ok(d.get(x, 1, z) === " ", "the refused bed changed nothing");
  d.commit(rec);
  rec = d.begin();
  d.put(rec, x, 1, z + 1, ".");
  ok(d.apply(rec, x, 1, z, { kind: "bed", role: "bed_fancy", o: 0 }).ok, "a fancy bed");
  const foot = d.entry(d.get(x, 1, z));
  ok(foot.name === "bed_fancy" && d.entry(foot.else).name === "bed", "a fancy bed falls back to the plain bed");
  d.commit(rec);
  // turning a plain cell follows its kind; a node without one does not turn
  rec = d.begin();
  d.put(rec, x, 2, z, d.keyFor("role seat o=facedir:3"));
  ok(d.rotate(rec, x, 2, z, () => "facedir").ok && d.entry(d.get(x, 2, z)).text === "role seat", "a facedir cell turns 3 -> 0, stored without o=");
  d.put(rec, x, 2, z, d.keyFor("role light_wall o=wallmounted:2"));
  ok(d.rotate(rec, x, 2, z, () => "wallmounted").ok && d.entry(d.get(x, 2, z)).o[1] === 5, "a wallmounted cell turns");
  d.put(rec, x, 2, z, d.keyFor("role light_wall o=wallmounted:4"));
  ok(d.rotate(rec, x, 2, z, () => "wallmounted").ok && d.entry(d.get(x, 2, z)).o[1] === 2, "a wall-mounted cell turns around the walls (4 -> 2)");
  for (const v of [0, 1]) {
    d.put(rec, x, 2, z, d.keyFor(`role light_wall o=wallmounted:${v}`));
    ok(!d.rotate(rec, x, 2, z, () => "wallmounted").ok && d.entry(d.get(x, 2, z)).o[1] === v, `wallmounted ${v} (floor or ceiling) is not turned`);
  }
  let w = d.keyFor("role light_wall o=wallmounted:2"), seen = [];
  d.put(rec, x, 2, z, w);
  for (let k = 0; k < 8; k++) { d.rotate(rec, x, 2, z, () => "wallmounted"); seen.push(d.entry(d.get(x, 2, z)).o[1]); }
  ok(seen.every(v => v >= 2 && v <= 5), "turning never reaches the floor or the ceiling: " + seen);
  d.put(rec, x, 2, z, wallKey);
  ok(!d.rotate(rec, x, 2, z, () => "none").ok, "a node without orientation does not turn");
  d.commit(rec);
  // flipping, with the page's own answers for the dwarf palette (seat: a
  // stair, table_top: a slab, roof_stair_outer: a corner, shelf: a facedir
  // node that is not shaped, light_wall and light_post: torches)
  const K = E.kindOf, S = E.shapeOf, at = () => d.entry(d.get(x, 2, z)), fd = () => at().o ? at().o[1] : 0;
  const flip = () => d.flip(rec, x, 2, z, K, S);
  const parse = t => d.entry(d.keyFor(t));
  ok(S(parse("role seat")) === "stair" && S(parse("role table_top")) === "stair" &&
    S(parse("role roof_stair_outer")) === "corner" && S(parse("role roof_stair_inner")) === "corner" &&
    S(parse("role shelf")) === null && S(parse("role light_wall")) === null && S(parse("role light_post")) === null &&
    S(parse("node grug_decor:cottages_wagon_wheel")) === "mount", "the shapes the page answers");
  rec = d.begin();
  for (const [role, pairs] of [["seat", [[0, 20], [1, 23], [2, 22], [3, 21]]], ["table_top", [[1, 23]]],
                               ["roof_stair_outer", [[0, 21], [1, 20], [2, 23], [3, 22]]]])
    for (const [a, b] of pairs) {
      d.put(rec, x, 2, z, d.keyFor(`role ${role} o=facedir:${a}`));
      ok(flip().ok && fd() === b, `${role}: flip ${a} -> ${b}: ${at().text}`);
      ok(flip().ok && fd() === a && (a > 0) === !!at().o, `${role}: flip ${b} -> ${a}: ${at().text}`);
    }
  d.put(rec, x, 2, z, d.keyFor("role seat"));
  ok(flip().ok && at().text === "role seat o=facedir:20", "a stair without o= (facedir 0) flips to 20");
  ok(flip().ok && at().text === "role seat", "and back to the entry without o=");
  // rotate after flip: an upside-down stair turns within 20-23, the same
  // way round as an upright one (its facing +Z -> +X -> -Z -> -X: 20, 23,
  // 22, 21), and flips back upright facing where it faced
  d.put(rec, x, 2, z, d.keyFor("role seat o=facedir:20"));
  const turns = [];
  for (let k = 0; k < 4; k++) { ok(d.rotate(rec, x, 2, z, K).ok, "an upside-down stair turns"); turns.push(fd()); }
  ok(turns.join() === "23,22,21,20", "turning keeps it upside down: " + turns);
  d.rotate(rec, x, 2, z, K);
  ok(flip().ok && fd() === 1, "a turned upside-down stair (23) flips upright to 1");
  const up = [];
  for (let k = 0; k < 4; k++) { d.rotate(rec, x, 2, z, K); up.push(fd()); }
  ok(up.join() === "2,3,0,1", "an upright stair turns 1 -> 2 -> 3 -> 0 -> 1: " + up);
  // wallmounted: wall -> floor -> ceiling -> the wall of wallmounted 2
  d.put(rec, x, 2, z, d.keyFor("node grug_decor:cottages_wagon_wheel o=wallmounted:3"));
  const walls = [];
  for (let k = 0; k < 3; k++) { ok(flip().ok, "a wagon wheel flips"); walls.push(at().o[1]); }
  ok(walls.join() === "1,0,2", "wall -> floor -> ceiling -> wall: " + walls);
  d.put(rec, x, 2, z, d.keyFor("node grug_decor:xdecor_candle o=wallmounted:1"));
  ok(flip().ok && at().text === "node grug_decor:xdecor_candle o=wallmounted:0", "a candle on the floor flips onto the ceiling");
  // refusals: each leaves the cell as it was
  for (const [text, why] of [["node grug_trees:apple_base o=facedir:4", "lying tree piece"],
                             ["node grug_trees:apple_base", "stair or a slab"],
                             ["role shelf o=facedir:1", "stair or a slab"],
                             ["role light_wall o=wallmounted:2", "torch"],
                             ["role light_post o=wallmounted:1", "torch"],
                             ["node default:torch_ceiling o=wallmounted:0", "torch"],
                             ["role wall", "does not flip"]]) {
    const key = d.keyFor(text);
    d.put(rec, x, 2, z, key);
    const r = flip();
    ok(!r.ok && r.message.includes(why) && d.get(x, 2, z) === key, `${text} is refused (${r.message})`);
  }
  d.commit(rec);
  rec = d.begin();
  d.put(rec, x, 2, z, ".");
  ok(d.apply(rec, x, 1, z, { kind: "door", variant: "_a", o: 0 }).ok, "a door to flip");
  ok(!d.flip(rec, x, 1, z, K, S).ok && !d.flip(rec, x, 2, z, K, S).ok && d.partKind(x, 1, z) === "leaf",
    "a door (either cell) does not flip");
  ok(d.apply(rec, x, 1, z, { kind: "air" }).ok && d.apply(rec, x, 1, z, { kind: "bed", role: "bed", o: 0 }).ok, "a bed to flip");
  const r = d.flip(rec, x, 1, z, K, S);
  ok(!r.ok && r.message.includes("bed") && d.partKind(x, 1, z) === "bottom", "a bed does not flip");
  d.apply(rec, x, 1, z, { kind: "air" });
  d.commit(rec);
  // undo, redo and the changed outline with a flipped cell
  const f = new D(E.tpl);
  let fx = null;
  for (let i = 0; i < f.cells.length && fx === null; i++) if (f.entry(f.cells[i])?.text === "role seat") fx = f.pos(i);
  ok(fx, "the template has an upright seat");
  rec = f.begin();
  ok(f.flip(rec, ...fx, K, S).ok, "flipping the seat");
  f.commit(rec);
  ok(f.entry(f.get(...fx)).text === "role seat o=facedir:20" && f.changedSinceHead().has(f.index(...fx)), "a flipped cell is changed since commit");
  f.undo();
  ok(f.entry(f.get(...fx)).text === "role seat" && f.changedSinceHead().size === 0, "undo takes the flip back");
  f.redo();
  ok(f.entry(f.get(...fx)).text === "role seat o=facedir:20", "redo flips it again");
  rec = f.begin();
  ok(f.flip(rec, ...fx, K, S).ok, "flipping it back");
  f.commit(rec);
  ok(f.entry(f.get(...fx)).text === "role seat" && f.changedSinceHead().size === 0, "a seat flipped back is no edit");
  // a cell stored with an explicit o=facedir:0 at HEAD turns back to that entry
  const g = new D(E.tpl);
  let wi = g.cells.findIndex(k => g.entry(k)?.text === "role window");
  ok(wi >= 0, "the template has a window");
  const wp = g.pos(wi), head0 = g.keyFor("role window o=facedir:0");
  g.head.cells[wi] = head0;
  g.head.entries.set(head0, g.entry(head0));
  rec = g.begin();
  g.put(rec, ...wp, head0);
  for (let k = 0; k < 4; k++) ok(g.rotate(rec, ...wp, K).ok && (k === 3 || g.get(...wp) !== head0), "a window turns");
  ok(g.get(...wp) === head0 && !g.changedSinceHead().has(wi), "four turns give the HEAD form o=facedir:0 back");
  // an optional role is stored with its fallback: the template's own entry
  // for the role, else else=air; never a second entry differing by else=
  const o1 = new D(E.tpl); o1.optional = E.doc.optional;
  rec = o1.begin();
  ok(o1.apply(rec, x, 2, z, { kind: "entry", text: "role flower" }).ok, "painting an optional role");
  ok(o1.entry(o1.get(x, 2, z)).text === "role flower else=air", "without an entry for it the role gets else=air: " + o1.entry(o1.get(x, 2, z)).text);
  const o2 = new D(E.tpl); o2.optional = E.doc.optional;
  const own = o2.keyFor("role flower else=unchanged");
  rec = o2.begin();
  o2.apply(rec, x, 2, z, { kind: "entry", text: "role flower" });
  o2.apply(rec, x + 1, 2, z, { kind: "entry", text: "role flower" });
  ok(o2.get(x, 2, z) === own && o2.get(x + 1, 2, z) === own, "the template's own entry for the role is reused");
  ok(o2.keys.filter(k => o2.entries.get(k).name === "flower").length === 1, "no second entry differing only by else=");
  ok(o2.withFallback("role wall") === "role wall", "a required role takes no else=");
  ok(o2.withFallback("role flower else=unchanged") === "role flower else=unchanged", "an explicit fallback stays");
  // points move and nothing else; the box stays
  const p0 = d.points[0], was = [p0.group, p0.face, p0.rest];
  rec = d.begin();
  ok(!d.movePoint(rec, 0, d.x0 + d.sx, 1, 0).ok, "a point stays in the box");
  ok(d.movePoint(rec, 0, x, 1, z).ok, "a point moves");
  d.commit(rec);
  const s = d.serialize();
  ok(s.points[0].join() === [x, 1, z].join() && s.points[0].length === 3, "only positions leave the page");
  ok(p0.group === was[0] && p0.face === was[1] && p0.rest === was[2], "group, face and attributes stay");
  ok(s.layers.length === d.sy && s.layers[0].length === d.sz && s.layers[0][0].length === d.sx * d.cellWidth, "the box stays");
  // the untouched document serializes to what the file holds
  const fresh = new D(E.tpl).serialize();
  ok(JSON.stringify(fresh.legend) === JSON.stringify(E.tpl.legend) && JSON.stringify(fresh.layers) === JSON.stringify(E.tpl.layers), "an unedited document is the file");
  ok(new D(E.tpl).changedSinceHead().size === 0, "nothing changed since commit before an edit");
  return { fails, count };
})()
"""

# Torches are drawn for one mount only: a role a placing race binds to a
# torch does not flip, whatever the other races bind (elf and undead bind
# light_wall to a candle).
MOUNT_CHECK = r"""
(async () => {
  const M = await import("/model.js"), A = await (await fetch("/api/assets")).json();
  const P = A.palettes, one = new Set(A.one_mount), fails = [];
  let count = 0;
  const ok = (c, what) => { count++; if (!c) fails.push(what); };
  ok(["default:torch", "default:torch_wall", "default:torch_ceiling"].every(n => one.has(n)) &&
    !["grug_decor:xdecor_candle", "grug_decor:cottages_wagon_wheel", "grug_decor:xdecor_ivy", "grug_mapgen:guild_banner_charter"].some(n => one.has(n)),
    "one mount: the torches, not the candle, wheel, ivy or banners: " + A.one_mount);
  const e = M.parseEntry("role light_wall o=wallmounted:2");
  const races = r => r.map(race => ({ main: { race, roles: P.races[race] } }));
  const candle = Object.keys(P.races).filter(r => P.races[r].light_wall === "grug_decor:xdecor_candle");
  const torch = Object.keys(P.races).filter(r => P.races[r].light_wall === "default:torch_wall");
  ok(candle.length && torch.length, "races with a candle and with a torch: " + candle + " / " + torch);
  ok(M.entryShape(e, races(candle), P, one) === "mount", "light_wall flips where every race binds a candle");
  ok(M.entryShape(e, races(torch), P, one) === null, "light_wall does not flip where a race binds a torch");
  ok(M.entryShape(e, races([candle[0], torch[0]]), P, one) === null, "nor where one of the placing races binds a torch");
  // a facedir 0 stored without o= builds as o=facedir:0 for every facedir node
  ok(Object.entries(P.nodes).every(([, n]) => n.kind !== "facedir" || n.place === 0), "place_param2 is 0 for every facedir node");
  return { fails, count };
})()
"""

# A legend that outgrows single characters becomes `cell 2`, every cell
# keeping its entry; the server takes the result.
WIDEN_CHECK = r"""
(async () => {
  const E = window.__editor, D = E.doc.constructor, fails = [];
  let count = 0;
  const ok = (c, what) => { count++; if (!c) fails.push(what); };
  const d = new D(E.tpl);
  const before = d.cells.map(k => d.identity(k));
  const names = [...document.querySelectorAll('#item-list .item')].map(e => JSON.parse(e.dataset.brush))
    .filter(b => b.kind === "entry" && b.text.startsWith("node ")).map(b => b.text);
  for (const t of names.slice(0, 100)) d.keyFor(t);
  ok(d.cellWidth === 2 && d.keys.every(k => k.length === 2), "the legend widened to two characters");
  ok(d.cells.every((k, i) => d.identity(k) === before[i]), "every cell keeps its entry");
  const s = d.serialize();
  ok(s.layers[0][0].length === d.sx * 2, "rows are two characters per cell");
  const r = await fetch("/api/check", { method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: E.tpl.name, hash: E.tpl.hash, ...s }) });
  const j = await r.json();
  ok(r.ok && j.errors.length === 0, "the server takes a cell 2 file: " + JSON.stringify(j).slice(0, 300));
  return { fails, count };
})()
"""


def modal_click(b, label):
    b.wait("!document.getElementById('modal').hidden", 20)
    b.js("[...document.querySelectorAll('#modal-buttons button')].find(x => x.textContent === %s).click()" % json.dumps(label))
    b.wait("document.getElementById('modal').hidden", 20)


def item(b, predicate):
    """Click the item whose brush matches a JS predicate on `br`."""
    found = b.js("""(() => { const el = [...document.querySelectorAll('#item-list .item')].find(e => { const br = JSON.parse(e.dataset.brush); return %s; });
      if (!el) return null; el.scrollIntoView({block: 'center'}); const r = el.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; })()""" % predicate)
    check(found, "the item list has %s" % predicate)
    b.click(*found)


def cell(b, x, y, z):
    b.js("window.__editor.setLayer(%d)" % y)
    time.sleep(0.15)
    px, py = b.js("window.__editor.cellPoint(%d, %d)" % (x, z))
    b.click(px, py)
    time.sleep(0.15)


def disk(root, name):
    with open(os.path.join(root, common.serve.BASE, "templates", name + ".tpl"), "rb") as fh:
        return fh.read()


def main(argv):
    shots = argv[0] if argv else os.path.expanduser("~/projects/grudgelands-orchestration/r56/shots/editor")
    os.makedirs(shots, exist_ok=True)
    tmp, root = common.scratch_root()
    srv = common.Running(root)
    original = disk(root, TPL)
    try:
        with cdp.Browser(1600, 1000) as b:
            shot = lambda n: b.shot(os.path.join(shots, n))
            b.go(srv.url + "/")
            b.wait("window.__editor && window.__editor.ready", 90)
            count = len([n for n in os.listdir(os.path.join(root, common.serve.BASE, "templates")) if n.endswith(".tpl")])
            check(b.js("document.querySelectorAll('#home-list button').length") == count, "the list shows every template (%d)" % count)
            shot("01-template-list.png")
            b.click_selector("#home-list button[data-name=%s]" % TPL)
            b.wait("window.__editor.doc && window.__editor.tpl.name === %s" % json.dumps(TPL), 30)
            time.sleep(1.5)
            shot("02-open.png")

            # noclip through the building
            b.click_selector("[data-mode=noclip]")
            check(b.js("window.__editor.view.mode") == "noclip", "noclip mode")
            b.js("window.__editor.view.walkFrom([4, 1.2, -4], 0, 'noclip')")
            b.key("KeyW", hold=0.9)
            time.sleep(0.3)
            pos = b.js("window.__editor.view.walker.z")
            check(pos > -2.5, "noclip flies forward through the wall (z %.2f)" % pos)
            shot("03-noclip-inside.png")
            b.click_selector("[data-mode=orbit]")

            # the edit rules on a copy of the document
            model = b.js(MODEL_CHECKS)
            check(model["fails"] == [], "model rules: %s" % model["fails"])
            CHECKS[0] += model["count"]
            model = b.js(MOUNT_CHECK)
            check(model["fails"] == [], "one-mount nodes: %s" % model["fails"])
            CHECKS[0] += model["count"]
            model = b.js(WIDEN_CHECK)
            check(model["fails"] == [], "widening the keys: %s" % model["fails"])
            CHECKS[0] += model["count"]

            # an optional role no placing race binds is disabled like an unbound required one
            unbound = b.js("""(() => { const E = window.__editor, P = null;
              return [...document.querySelectorAll('#item-list .item')].filter(e => { const br = JSON.parse(e.dataset.brush);
                return br.kind === 'entry' && br.text === 'role bale'; }).map(e => e.disabled); })()""")
            check(unbound == [True], "bale (optional, no dwarf binding) is disabled for the dwarf template: %s" % unbound)

            # layer 1: a bed and a door, by clicks on the grid
            spot = b.js("""(() => { const d = window.__editor.doc;
              for (let x = 4; x < 8; x++) for (let z = 5; z > 0; z--)
                if (d.get(x, 1, z) === '.' && d.get(x, 1, z + 1) === '.' && d.get(x, 2, z) === '.' && !d.points.some(p => p.x === x && p.z === z)) return [x, z];
              return null; })()""")
            check(spot, "a free spot for the bed")
            bx, bz = spot
            item(b, "br.kind === 'bed' && br.role === 'bed'")
            cell(b, bx, 1, bz)
            check(b.js("window.__editor.doc.partKind(%d, 1, %d) === 'bottom' && window.__editor.doc.partKind(%d, 1, %d) === 'top'" % (bx, bz, bx, bz + 1)),
                  "a click places a bed on two cells")
            door = b.js("""(() => { const d = window.__editor.doc;
              for (let x = 2; x < 8; x++) for (let z = 2; z < 8; z++)
                if (d.get(x, 1, z) === '.' && d.get(x, 2, z) === '.' && !d.points.some(p => p.x === x && p.z === z)) return [x, z];
              return null; })()""")
            dx, dz = door
            item(b, "br.kind === 'door' && br.variant === '_a'")
            cell(b, dx, 1, dz)
            check(b.js("window.__editor.doc.partKind(%d, 2, %d)" % (dx, dz)) == "hidden", "a click places a door and its upper cell")
            shot("04-layer1-bed-and-door.png")
            # layer 2: the cell above the door is locked
            item(b, "br.kind === 'entry' && br.text === 'role wall'")
            cell(b, dx, 2, dz)
            check(b.js("window.__editor.doc.partKind(%d, 2, %d)" % (dx, dz)) == "hidden", "painting the locked cell is refused")
            check("locked" in b.js("document.getElementById('message').textContent"), "the page says the cell is locked")
            shot("05-layer2-locked-door-cell.png")
            # layer 3: a block
            item(b, "br.kind === 'entry' && br.text === 'role wall_accent'")
            target = b.js("""(() => { const d = window.__editor.doc;
              for (let x = 2; x < 8; x++) for (let z = 2; z < 8; z++) if (d.get(x, 3, z) === '.') return [x, z]; return null; })()""")
            cell(b, target[0], 3, target[1])
            check(b.js("window.__editor.doc.entry(window.__editor.doc.get(%d, 3, %d)).name" % tuple(target)) == "wall_accent", "a block on layer 3")
            check(b.js("window.__editor.doc.changedSinceHead().size") >= 5, "the edits show as changed since commit")
            b.js("window.__editor.view.lookAt([14, 14, -10], [4, 2, 5])")
            time.sleep(1.0)
            shot("06-edits-on-two-layers.png")

            # undo, then reset
            b.click_selector("#undo")
            check(b.js("window.__editor.doc.get(%d, 3, %d)" % tuple(target)) == ".", "undo takes the block back")
            b.click_selector("#reset")
            modal_click(b, "Reset")
            b.wait("window.__editor.doc && !window.__editor.dirty()", 20)
            check(b.js("window.__editor.doc.changedSinceHead().size") == 0, "reset returns to the saved file")

            # an invalid edit: wall up the entrance door; Save refuses
            entrance = b.js("(() => { const p = window.__editor.doc.points.find(p => p.group === 'doors'); return [p.x, p.y, p.z]; })()")
            item(b, "br.kind === 'entry' && br.text === 'role wall'")
            cell(b, *entrance)
            b.click_selector("#save")
            b.wait("document.getElementById('message').textContent.startsWith('Save refused')", 30)
            check(b.js("window.__editor.findings().filter(f => f.level === 'error').length") > 0, "the refusal lists errors")
            check(disk(root, TPL) == original, "a refused save writes nothing")
            time.sleep(0.5)
            shot("07-invalid-save-refused.png")
            b.click_selector("#undo")

            # a valid edit: the bed and a moved point; Save writes the file
            item(b, "br.kind === 'bed' && br.role === 'bed'")
            cell(b, bx, 1, bz)
            b.click_selector("#save")
            b.wait("!document.getElementById('modal').hidden", 30)
            check("used 1" in b.js("document.getElementById('modal-body').textContent"), "the save names the template's uses")
            shot("08-save-confirm.png")
            modal_click(b, b.js("document.querySelector('#modal-buttons button.primary').textContent"))
            b.wait("document.getElementById('message').textContent.startsWith('Saved')", 30)
            after = disk(root, TPL)
            check(after != original, "the file on disk changed")
            diff = subprocess.run(["git", "diff", "--stat"], cwd=root, capture_output=True, text=True).stdout
            check(TPL in diff, "git diff in the clone shows the template: %s" % diff.strip())
            check(not any(n.endswith(".tmp") for n in os.listdir(os.path.join(root, common.serve.BASE, "templates"))), "no temp file left")
            time.sleep(0.8)
            shot("09-saved.png")
            print("saved edit (in the clone):\n" + subprocess.run(["git", "diff", "--stat"], cwd=root, capture_output=True, text=True).stdout)

            # Flip from the tool bar: a seat upside down, saved through the
            # validator and read back; a floor torch refused
            b.click_selector("[data-tool=flip]")
            check(b.js("window.__editor.tool") == "flip", "the Flip button selects the tool")
            flips = b.js("""(() => { const d = window.__editor.doc, out = {};
              for (let i = 0; i < d.cells.length; i++) { const t = d.entry(d.cells[i])?.text;
                if ((t === 'role seat' || t === 'role light_post o=wallmounted:1') && !out[t]) out[t] = d.pos(i); }
              return out; })()""")
            check(len(flips) == 2, "a seat and a floor torch to flip: %s" % flips)
            for pos in flips.values():
                cell(b, *pos)
                if pos == flips["role light_post o=wallmounted:1"]:
                    check("torch" in b.js("document.getElementById('message').textContent"), "the page says a torch does not flip")
            got = b.js("[%s].map(p => window.__editor.doc.entry(window.__editor.doc.get(...p)).text)"
                       % ",".join(json.dumps(p) for p in flips.values()))
            want = {"role seat": "role seat o=facedir:20", "role light_post o=wallmounted:1": "role light_post o=wallmounted:1"}
            check(got == [want[k] for k in flips], "clicks with Flip turn them over: %s" % got)
            check(b.js("[%s].map(p => window.__editor.doc.changedSinceHead().has(window.__editor.doc.index(...p)))"
                       % ",".join(json.dumps(p) for p in flips.values())) == [k == "role seat" for k in flips],
                  "the flipped seat shows as changed since commit, the refused torch does not")
            shot("09b-flipped.png")
            b.click_selector("#save")
            b.wait("!document.getElementById('modal').hidden || document.getElementById('message').textContent.startsWith('Save refused')", 30)
            check(not b.js("document.getElementById('message').textContent.startsWith('Save refused')"),
                  "the validator takes the flipped cells: %s" % b.js("document.getElementById('message').textContent"))
            modal_click(b, b.js("document.querySelector('#modal-buttons button.primary').textContent"))
            b.wait("document.getElementById('message').textContent.startsWith('Saved')", 30)
            text = disk(root, TPL).decode()
            check("role seat o=facedir:20" in text and "role light_post o=wallmounted:0" not in text, "the file holds the flipped seat")
            back = json.loads(b.js("""fetch('/api/template?name=%s').then(r => r.json()).then(t => {
              const d = new window.__editor.doc.constructor(t);
              return JSON.stringify([%s].map(p => d.entry(d.get(...p)).text)); })""" % (TPL, ",".join(json.dumps(p) for p in flips.values()))))
            check(back == got, "the saved file reads back the flipped cells: %s" % back)

            # a draft survives a reload
            item(b, "br.kind === 'entry' && br.text === 'role wall_accent'")
            cell(b, target[0], 3, target[1])
            time.sleep(0.6)
            b.events = []
            b.reload()
            time.sleep(0.5)
            b.wait("window.__editor && window.__editor.ready && window.__editor.doc", 60)
            b.wait("!document.getElementById('notice').hidden", 20)
            shot("10-draft-offered.png")
            b.js("[...document.querySelectorAll('#notice button')].find(x => x.textContent === 'Restore').click()")
            check(b.js("window.__editor.dirty()") and
                  b.js("window.__editor.doc.entry(window.__editor.doc.get(%d, 3, %d)).name" % tuple(target)) == "wall_accent",
                  "the draft restores the edit")
            b.click_selector("#reset")
            modal_click(b, "Reset")
            b.wait("window.__editor.doc && !window.__editor.dirty()", 20)

            # the shared template: the fixed-node flag, "used 2x" before saving
            b.go(srv.url + "/#tpl=" + SHARED)
            b.wait("window.__editor.doc && window.__editor.tpl.name === %s" % json.dumps(SHARED), 30)
            time.sleep(1)
            item(b, "br.kind === 'entry' && br.text === 'node default:glass'")
            b.wait("!document.getElementById('modal').hidden", 10)
            check("fixed node" in b.js("document.getElementById('modal-body').textContent"), "a fixed node in a shared template is flagged")
            shot("11-fixed-node-flag.png")
            modal_click(b, "Cancel")
            check(b.js("window.__editor.brush.text") != "node default:glass", "cancel keeps the old item")
            spot2 = b.js("""(() => { const d = window.__editor.doc;
              for (let y = 2; y < d.y0 + d.sy; y++) for (let x = d.x0; x < d.x0 + d.sx; x++) for (let z = d.z0; z < d.z0 + d.sz; z++)
                if (d.get(x, y, z) === '.' && d.get(x, y - 1, z) !== '.' && d.get(x, y - 1, z) !== ' ') return [x, y, z]; return null; })()""")
            item(b, "br.kind === 'entry' && br.text === 'role wall'")
            cell(b, *spot2)
            b.click_selector("#save")
            b.wait("!document.getElementById('modal').hidden || document.getElementById('message').textContent.startsWith('Save refused')", 30)
            body = b.js("document.getElementById('modal-body').textContent")
            check("used 2" in body and "every placement" in body, "a shared template shows 'used 2x in ...' before saving")
            shot("12-shared-save-confirm.png")
            modal_click(b, "Cancel")
            check(disk(root, SHARED) == open(os.path.join(common.REPO, common.serve.BASE, "templates", SHARED + ".tpl"), "rb").read(),
                  "a cancelled save writes nothing")
            errors = b.errors()
            check(not errors, "no page errors: %s" % errors)
    finally:
        srv.stop()
        shutil.rmtree(tmp, ignore_errors=True)
    print("gui_run: %d checks passed; shots in %s" % (CHECKS[0], shots))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
