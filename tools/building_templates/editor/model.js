// The template editor's document: one building template's cells, legend and
// points, the edit rules and the stamp's resolution, with no page code, so
// the browser test drives it directly (docs/technical/building-template-
// format.md; Round 56 rulings 25-31).
//
// - Cells are legend keys, "." (force air) or " " (leave unchanged), one per
//   cell whatever the file's cell width. Every edit is a change record
//   (cells and point positions before and after) for undo and redo.
// - Multi-cell objects (format doc §5): a door is its leaf and the
//   door_hidden above (the upper cell is locked: only the whole door is
//   removed, turned or picked there); a bed is its _bottom and the _top one
//   step along its facedir. They are placed only where their other cells are
//   free (force air or leave unchanged) and inside the box, and removed as a
//   whole (the other cells become force air).
// - Points are only moved (ruling 28); the box never changes (ruling 27).
// - resolveKey / resolvedCells follow format doc §3.2 and templates.py (the
//   viewer's reader); settlePanes is the port of parts.resolve_panes.

export const FACE_STEP = [[0, 1], [1, 0], [0, -1], [-1, 0]];
// Legend keys in the order the freeze exporter hands them out.
export const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" +
  "!$%&'()*+,-/:;<=>?@[\\]^_`{}~\"";
export const AIR = ".", UNCHANGED = " ";
// The order the rotate tool turns a wallmounted node in: the four walls
// around, then the floor and the ceiling.
const WALL_CYCLE = [2, 5, 3, 4, 1, 0];

// ------------------------------------------------------------- entries ---
// A legend entry's text as fields: {kind, name, variant, channel, o, else,
// choices}. o is [kind, value] or null.
export function parseEntry(text) {
  const words = text.trim().split(/\s+/);
  const e = { kind: words[0], name: null, variant: null, channel: null, o: null, else: null, choices: null };
  if (e.kind === "race") {
    e.choices = {};
    for (const w of words.slice(1)) { const [race, key] = w.split("="); e.choices[race] = key; }
    return e;
  }
  e.name = words[1];
  for (const w of words.slice(2)) {
    const i = w.indexOf("=");
    const k = w.slice(0, i), v = w.slice(i + 1);
    if (k === "o") { const [kind, n] = v.split(":"); e.o = [kind, +n]; }
    else if (k === "variant") e.variant = v;
    else if (k === "channel") e.channel = v;
    else if (k === "else") e.else = v;
  }
  return e;
}
// The canonical text of an entry (the exporter's attribute order).
export function entryText(e) {
  if (e.kind === "race")
    return "race " + Object.entries(e.choices).map(([r, k]) => `${r}=${k}`).join(" ");
  const out = [e.kind, e.name];
  if (e.kind === "role") {
    if (e.variant) out.push("variant=" + e.variant);
    if (e.channel) out.push("channel=" + e.channel);
  }
  if (e.o) out.push(`o=${e.o[0]}:${e.o[1]}`);
  if (e.kind === "role" && e.else) out.push("else=" + e.else);
  return out.join(" ");
}

// ------------------------------------------------------------ document ---
export class Doc {
  // tpl: the server's template ({cell, legend, layers, points, origin, size,
  // pivot, races, ...}).
  constructor(tpl) {
    this.tpl = tpl;
    [this.x0, this.y0, this.z0] = tpl.origin;
    [this.sx, this.sy, this.sz] = tpl.size;
    this.cellWidth = tpl.cell;
    this.keys = [];
    this.entries = new Map();
    for (const [key, text] of tpl.legend) this.addEntry(key, text);
    this.cells = readLayers(tpl.layers, tpl.cell, this.sx);
    this.points = tpl.points.map(([group, x, y, z, rest]) => ({ group, x, y, z, rest,
      face: faceOf(rest), id: attr(rest, "id") }));
    this.undoStack = [];
    this.redoStack = [];
    this.head = null;
    if (tpl.head && tpl.head.size.join() === tpl.size.join() && tpl.head.origin.join() === tpl.origin.join()) {
      this.head = { cells: readLayers(tpl.head.layers, tpl.head.cell, this.sx), entries: new Map() };
      for (const [key, text] of tpl.head.legend) this.head.entries.set(key, parseEntry(text));
    }
  }
  addEntry(key, text) {
    this.keys.push(key);
    this.entries.set(key, Object.assign(parseEntry(text), { text }));
  }
  index(x, y, z) { return ((y - this.y0) * this.sz + (z - this.z0)) * this.sx + (x - this.x0); }
  pos(i) {
    const x = i % this.sx, z = Math.floor(i / this.sx) % this.sz, y = Math.floor(i / (this.sx * this.sz));
    return [x + this.x0, y + this.y0, z + this.z0];
  }
  inBox(x, y, z) {
    return x >= this.x0 && x < this.x0 + this.sx && y >= this.y0 && y < this.y0 + this.sy &&
      z >= this.z0 && z < this.z0 + this.sz;
  }
  get(x, y, z) { return this.inBox(x, y, z) ? this.cells[this.index(x, y, z)] : null; }
  entry(key) { return this.entries.get(key) || null; }
  free(x, y, z) { const v = this.get(x, y, z); return v === AIR || v === UNCHANGED; }

  // The key of an entry text, adding the entry under a new key when the
  // legend has none with that canonical text.
  keyFor(text) {
    const want = entryText(parseEntry(text));
    for (const key of this.keys) if (entryText(this.entries.get(key)) === want) return key;
    let key = this.freeKey();
    if (key === null) { this.widenKeys(); key = this.freeKey(); }
    this.addEntry(key, want);
    return key;
  }
  freeKey() {
    const used = new Set(this.keys);
    if (this.cellWidth === 1) {
      for (const c of ALPHABET) if (!used.has(c)) return c;
      return null;
    }
    for (const a of ALPHABET) for (const b of ALPHABET) if (!used.has(a + b)) return a + b;
    return null;
  }
  // More legend entries than single characters: two characters per cell
  // (format doc §3.3), every key renamed in legend order.
  widenKeys() {
    const rename = new Map(this.keys.map((k, i) =>
      [k, ALPHABET[Math.floor(i / ALPHABET.length)] + ALPHABET[i % ALPHABET.length]]));
    const old = this.entries;
    this.keys = []; this.entries = new Map();
    for (const [key, e] of old) {
      const copy = parseEntry(e.text);
      if (copy.kind === "race") for (const r in copy.choices) copy.choices[r] = rename.get(copy.choices[r]);
      else if (copy.else && rename.has(copy.else)) copy.else = rename.get(copy.else);
      this.addEntry(rename.get(key), entryText(copy));
    }
    this.cells = this.cells.map(v => rename.get(v) ?? v);
    for (const s of [...this.undoStack, ...this.redoStack])
      for (const c of s.cells) { c[1] = rename.get(c[1]) ?? c[1]; c[2] = rename.get(c[2]) ?? c[2]; }
    this.cellWidth = 2;
  }

  // ----------------------------------------------- multi-cell objects ---
  // What a cell is as part of a multi-cell object: "leaf", "hidden",
  // "bottom", "top" or null.
  partKind(x, y, z) {
    const e = this.entry(this.get(x, y, z));
    if (!e) return null;
    if (e.kind === "role") {
      if (e.name === "door") return "leaf";
      if (e.name === "door_hidden") return "hidden";
      if ((e.name === "bed" || e.name === "bed_fancy") && e.variant === "_bottom") return "bottom";
      if ((e.name === "bed" || e.name === "bed_fancy") && e.variant === "_top") return "top";
    } else if (e.kind === "node") {
      if (/^(doors|xpanes):door_\w+_[ab]$/.test(e.name)) return "leaf";
      if (e.name === "doors:hidden") return "hidden";
      if (/^beds:\w+_bottom$/.test(e.name)) return "bottom";
      if (/^beds:\w+_top$/.test(e.name)) return "top";
    }
    return null;
  }
  facing(x, y, z) {
    const e = this.entry(this.get(x, y, z));
    return e && e.o && e.o[0] === "facedir" ? e.o[1] % 4 : 0;
  }
  // The cells of the object a cell belongs to ([[x, y, z], ...], the
  // anchor first), or null. Only partners that are really there count.
  object(x, y, z) {
    const kind = this.partKind(x, y, z);
    if (!kind) return null;
    if (kind === "leaf") {
      return this.partKind(x, y + 1, z) === "hidden" ? { type: "door", cells: [[x, y, z], [x, y + 1, z]] }
        : { type: "door", cells: [[x, y, z]] };
    }
    if (kind === "hidden") {
      return this.partKind(x, y - 1, z) === "leaf" ? { type: "door", cells: [[x, y - 1, z], [x, y, z]] }
        : { type: "door", cells: [[x, y, z]] };
    }
    if (kind === "bottom") {
      const [dx, dz] = FACE_STEP[this.facing(x, y, z)];
      return this.partKind(x + dx, y, z + dz) === "top" && this.facing(x + dx, y, z + dz) === this.facing(x, y, z)
        ? { type: "bed", cells: [[x, y, z], [x + dx, y, z + dz]] } : { type: "bed", cells: [[x, y, z]] };
    }
    const [dx, dz] = FACE_STEP[this.facing(x, y, z)];
    return this.partKind(x - dx, y, z - dz) === "bottom" && this.facing(x - dx, y, z - dz) === this.facing(x, y, z)
      ? { type: "bed", cells: [[x - dx, y, z - dz], [x, y, z]] } : { type: "bed", cells: [[x, y, z]] };
  }

  // ------------------------------------------------------------ edits ---
  // Low level: set cells inside an open record.
  put(rec, x, y, z, value) {
    const i = this.index(x, y, z);
    const before = this.cells[i];
    if (before === value) return;
    const seen = rec.cells.find(c => c[0] === i);
    if (seen) seen[2] = value; else rec.cells.push([i, before, value]);
    this.cells[i] = value;
  }
  begin() { return { cells: [], points: [] }; }
  // Close a record: drop no-op changes, push it for undo. Returns it, or
  // null when nothing changed.
  commit(rec) {
    rec.cells = rec.cells.filter(c => c[1] !== c[2]);
    rec.points = rec.points.filter(p => p[1].join() !== p[2].join());
    if (!rec.cells.length && !rec.points.length) return null;
    this.undoStack.push(rec);
    this.redoStack = [];
    return rec;
  }
  // Roll an open record back (a refused step of a stroke).
  rollback(rec, from = 0) {
    for (let k = rec.cells.length - 1; k >= from; k--) this.cells[rec.cells[k][0]] = rec.cells[k][1];
    rec.cells.length = from;
  }
  undo() {
    const rec = this.undoStack.pop();
    if (!rec) return null;
    for (let k = rec.cells.length - 1; k >= 0; k--) this.cells[rec.cells[k][0]] = rec.cells[k][1];
    for (const [i, before] of rec.points) Object.assign(this.points[i], { x: before[0], y: before[1], z: before[2] });
    this.redoStack.push(rec);
    return rec;
  }
  redo() {
    const rec = this.redoStack.pop();
    if (!rec) return null;
    for (const [i, , after] of rec.cells) this.cells[i] = after;
    for (const [i, , after] of rec.points) Object.assign(this.points[i], { x: after[0], y: after[1], z: after[2] });
    this.undoStack.push(rec);
    return rec;
  }

  // Apply a brush at a cell inside an open record. Brushes:
  //   {kind: "air"} / {kind: "unchanged"}: empty the cell (a whole object);
  //   {kind: "entry", text}: one cell;
  //   {kind: "door", variant: "_a"|"_b", o: 0-3}: the leaf here, door_hidden above;
  //   {kind: "bed", role: "bed"|"bed_fancy", o: 0-3}: _bottom here, _top along o.
  // Returns {ok: true} or {ok: false, message}; a refused brush changes nothing.
  apply(rec, x, y, z, brush) {
    if (!this.inBox(x, y, z)) return { ok: false, message: "outside the box (the box never changes)" };
    const mark = rec.cells.length;
    const erase = brush.kind === "air" ? AIR : brush.kind === "unchanged" ? UNCHANGED : null;
    const part = this.partKind(x, y, z);
    if (part === "hidden" && erase === null)
      return { ok: false, message: "the cell above a door belongs to the door (locked); empty the door or paint its lower cell" };
    const obj = this.object(x, y, z);
    if (obj) for (const c of obj.cells) this.put(rec, c[0], c[1], c[2], erase ?? AIR);
    if (erase !== null) { this.put(rec, x, y, z, erase); return { ok: true }; }
    if (brush.kind === "entry") { this.put(rec, x, y, z, this.keyFor(brush.text)); return { ok: true }; }
    const o = brush.o ?? 0;
    if (brush.kind === "door") {
      if (!this.inBox(x, y + 1, z)) { this.rollback(rec, mark); return { ok: false, message: "a door needs the cell above it inside the box" }; }
      if (!this.free(x, y + 1, z)) { this.rollback(rec, mark); return { ok: false, message: "a door needs a free cell above it (force air or leave unchanged)" }; }
      this.put(rec, x, y, z, this.keyFor(doorLeaf(brush.variant, o)));
      this.put(rec, x, y + 1, z, this.keyFor(doorHidden(brush.variant, o)));
      return { ok: true };
    }
    if (brush.kind === "bed") {
      const [dx, dz] = FACE_STEP[o % 4];
      if (!this.inBox(x + dx, y, z + dz)) { this.rollback(rec, mark); return { ok: false, message: "a bed needs its second cell inside the box" }; }
      if (!this.free(x + dx, y, z + dz)) { this.rollback(rec, mark); return { ok: false, message: "a bed needs a free second cell along its facing (force air or leave unchanged)" }; }
      const [bottom, top] = bedTexts(this, brush.role, o);
      this.put(rec, x, y, z, bottom);
      this.put(rec, x + dx, y, z + dz, top);
      return { ok: true };
    }
    return { ok: false, message: "unknown brush" };
  }

  // Turn what stands at a cell by 90 degrees (a whole door or bed; another
  // cell when its kind allows it). kindOf(entry) answers "facedir",
  // "wallmounted" or "none" for the entry's nodes in every placing palette.
  rotate(rec, x, y, z, kindOf) {
    const obj = this.object(x, y, z);
    if (obj && obj.cells.length === 2) {
      const [ax, ay, az] = obj.cells[0];
      const e = this.entry(this.get(ax, ay, az));
      const o = ((e.o ? e.o[1] : 0) + 1) % 4;
      const mark = rec.cells.length;
      for (const c of obj.cells) this.put(rec, c[0], c[1], c[2], AIR);
      const brush = obj.type === "door" ? { kind: "door", variant: e.variant || (/_b$/.test(e.name) ? "_b" : "_a"), o }
        : { kind: "bed", role: e.name === "bed_fancy" ? "bed_fancy" : "bed", o };
      if (obj.type === "door" && e.kind === "node") return this.refuse(rec, mark, "a fixed-node door does not turn here");
      if (obj.type === "bed" && e.kind === "node") return this.refuse(rec, mark, "a fixed-node bed does not turn here");
      const r = this.apply(rec, ax, ay, az, brush);
      if (!r.ok) return this.refuse(rec, mark, r.message);
      return r;
    }
    const key = this.get(x, y, z);
    const e = this.entry(key);
    if (!e || e.kind === "race") return { ok: false, message: "nothing to turn here" };
    const next = turned(e, kindOf(e));
    if (!next) return { ok: false, message: "this node does not turn (its kind has no orientation in every placing palette)" };
    this.put(rec, x, y, z, this.keyFor(next));
    return { ok: true };
  }
  refuse(rec, mark, message) { this.rollback(rec, mark); return { ok: false, message }; }

  movePoint(rec, i, x, y, z) {
    if (!this.inBox(x, y, z)) return { ok: false, message: "points stay inside the box" };
    const p = this.points[i];
    rec.points.push([i, [p.x, p.y, p.z], [x, y, z]]);
    Object.assign(p, { x, y, z });
    return { ok: true };
  }

  // ------------------------------------------------------------ output ---
  // What the server takes: cells, legend entries and point positions.
  serialize() {
    const width = this.cellWidth;
    const layers = [];
    for (let y = 0; y < this.sy; y++) {
      const rows = [];
      for (let z = 0; z < this.sz; z++) {
        let row = "";
        for (let x = 0; x < this.sx; x++) {
          const v = this.cells[(y * this.sz + z) * this.sx + x];
          row += v === AIR || v === UNCHANGED ? v.repeat(width) : v;
        }
        rows.push(row);
      }
      layers.push(rows);
    }
    return { cell: width, legend: this.keys.map(k => [k, this.entries.get(k).text]), layers,
      points: this.points.map(p => [p.x, p.y, p.z]) };
  }
  // Load a serialized state (a draft) over this document.
  restore(state) {
    this.cellWidth = state.cell;
    this.keys = []; this.entries = new Map();
    for (const [key, text] of state.legend) this.addEntry(key, text);
    this.cells = readLayers(state.layers, state.cell, this.sx);
    state.points.forEach((p, i) => Object.assign(this.points[i], { x: p[0], y: p[1], z: p[2] }));
    this.undoStack = []; this.redoStack = [];
  }

  // A cell's legend entry as the validator compares it (check.py
  // entry_text: a renamed key is no edit).
  identity(key, entries = this.entries, depth = 0) {
    if (key === AIR) return "air";
    if (key === UNCHANGED || key === undefined) return "unchanged";
    const e = entries.get(key);
    if (!e || depth > 8) return "?";
    if (e.kind === "race")
      return "race " + Object.keys(e.choices).sort().map(r => `${r}=<${this.identity(e.choices[r], entries, depth + 1)}>`).join(" ");
    if (e.kind === "node") return `node ${e.name} o=${e.o ? e.o.join(":") : ""}`;
    let fb = e.else || "unchanged";
    if (!["air", "unchanged"].includes(fb)) fb = `<${this.identity(fb, entries, depth + 1)}>`;
    return `role ${e.name} variant=${e.variant || ""} channel=${e.channel || ""} o=${e.o ? e.o.join(":") : ""} else=${fb}`;
  }
  // Cell indices whose entry differs from the file at HEAD (all of them
  // when the template is not in HEAD).
  changedSinceHead() {
    const out = new Set();
    const memo = new Map(), headMemo = new Map();
    const id = (k, m, entries) => { if (!m.has(k)) m.set(k, this.identity(k, entries)); return m.get(k); };
    for (let i = 0; i < this.cells.length; i++) {
      if (!this.head) { out.add(i); continue; }
      if (id(this.cells[i], memo, this.entries) !== id(this.head.cells[i], headMemo, this.head.entries)) out.add(i);
    }
    return out;
  }
  // Points not where HEAD has them (indices).
  movedSinceLoad() {
    return this.points.map((p, i) => i).filter(i => {
      const [, x, y, z] = this.tpl.points[i];
      const p = this.points[i];
      return p.x !== x || p.y !== y || p.z !== z;
    });
  }
}

function readLayers(layers, width, sx) {
  const cells = [];
  for (const rows of layers)
    for (const row of rows)
      for (let x = 0; x < sx; x++) {
        const v = row.slice(x * width, (x + 1) * width);
        cells.push(v === AIR.repeat(width) ? AIR : v === UNCHANGED.repeat(width) ? UNCHANGED : v);
      }
  return cells;
}
function attr(rest, name) {
  const m = new RegExp(`(?:^|\\s)${name}=("[^"]*"|\\S+)`).exec(rest || "");
  return m ? m[1].replace(/^"|"$/g, "") : null;
}
function faceOf(rest) { const f = attr(rest, "face"); return f === null ? null : +f; }

// The legend texts of a door with its leaf at facedir o (parts.door: the
// hidden cell faces o for _a and (o + 3) % 4 for _b). A facedir of 0 is the
// default write, so it is stored without o=, as the freeze wrote doors.
export function doorLeaf(variant, o) {
  return "role door variant=" + variant + (o ? ` o=facedir:${o}` : "");
}
export function doorHidden(variant, o) {
  const h = variant === "_b" ? (o + 3) % 4 : o;
  return "role door_hidden" + (h ? ` o=facedir:${h}` : "");
}
// A bed's two keys; a fancy bed falls back to the plain bed of the same
// facing for a race without one (as the freeze wrote them).
function bedTexts(doc, role, o) {
  const tail = o ? ` o=facedir:${o}` : "";
  const plain = ["_bottom", "_top"].map(v => doc.keyFor(`role bed variant=${v}${tail}`));
  if (role !== "bed_fancy") return plain;
  return ["_bottom", "_top"].map((v, i) => doc.keyFor(`role bed_fancy variant=${v}${tail} else=${plain[i]}`));
}
// The entry text turned by 90 degrees, or null when it does not turn.
export function turned(e, kind) {
  if (kind !== "facedir" && kind !== "wallmounted") return null;
  const copy = parseEntry(e.text || entryText(e));
  if (copy.o && copy.o[0] !== kind) return null;
  const v = copy.o ? copy.o[1] : (kind === "wallmounted" ? 1 : 0);
  if (kind === "facedir") {
    if (v >= 4 && v < 20) return null;  // a lying tree piece: not turned here
    copy.o = ["facedir", (v & ~3) | ((v + 1) & 3)];
  } else copy.o = ["wallmounted", WALL_CYCLE[(WALL_CYCLE.indexOf(v) + 1) % WALL_CYCLE.length]];
  return entryText(copy);
}

// ---------------------------------------------------------- resolution ---
// P: the palettes data (palettes.lua: required, optional, families, races,
// nodes); binding: {main: {race, roles}, <channel>: {race, roles}}.
export function canonicalParam2(P, name, p2) {
  const n = P.nodes[name];
  if (n && n.pane && name.endsWith("_flat")) { if (p2 === 1) return 3; if (p2 === 2) return 0; }
  return p2;
}
// The node a role or node entry names, null for an unbound optional role,
// or an error string.
export function entryNode(e, binding, P) {
  if (e.kind === "node") return e.name;
  const pal = (e.channel && binding[e.channel]) || binding.main;
  if (P.families[e.name]) {
    if (!P.families[e.name].includes(e.variant)) return `${e.name} has no variant ${e.variant}`;
    const base = pal.roles[e.name];
    return base ? base + e.variant : null;
  }
  if (!P.required.includes(e.name) && !P.optional.includes(e.name)) return `role ${e.name} is not declared`;
  const name = pal.roles[e.name];
  if (name == null) return P.required.includes(e.name) ? `required role ${e.name} is unbound` : null;
  return name;
}
// [name, param2], "." (air), " " (nothing) or {error}.
export function resolveKey(doc, key, binding, P, depth = 0) {
  if (key === AIR || key === UNCHANGED) return key;
  const e = doc.entries.get(key);
  if (!e) return { error: `undefined key ${key}` };
  if (e.kind === "race") {
    const c = e.choices[binding.main.race] ?? e.choices["*"];
    if (c === undefined) return { error: `race switch ${key} covers no ${binding.main.race}` };
    return depth > 3 ? { error: "race switch chain" } : resolveKey(doc, c, binding, P, depth + 1);
  }
  const name = entryNode(e, binding, P);
  if (typeof name === "string" && name.includes(" ")) return { error: name };
  if (name === null) {
    const fb = e.else || "unchanged";
    if (fb === "unchanged") return UNCHANGED;
    if (fb === "air") return AIR;
    return depth > 3 ? { error: "else= chain" } : resolveKey(doc, fb, binding, P, depth + 1);
  }
  const n = P.nodes[name] || { kind: "none", place: 0 };
  if (n.kind === "none") return [name, 0];
  if (n.kind === "meshoptions") return [name, n.place];
  if (!e.o) return [name, canonicalParam2(P, name, n.place)];
  if (e.o[0] !== n.kind) return { error: `${name} is ${n.kind}, the legend stores ${e.o[0]}` };
  return [name, canonicalParam2(P, name, e.o[1])];
}
// The kind of orientation an entry's node has in every binding: "facedir",
// "wallmounted", or "none" (no orientation, or the bindings disagree).
export function entryKind(e, bindings, P) {
  const kinds = new Set();
  for (const b of bindings) {
    const name = entryNode(e, b, P);
    if (!name || name.includes(" ")) continue;
    const k = (P.nodes[name] || {}).kind || "none";
    if (k !== "none" && k !== "meshoptions") kinds.add(k);
  }
  return kinds.size === 1 ? [...kinds][0] : "none";
}
// Every cell the stamp writes for a binding: [{i, x, y, z, name, p2}]
// (force air as name "air"), panes settled; and the cells that do not
// resolve, [{i, error}].
export function resolvedCells(doc, binding, P) {
  const memo = new Map(), out = [], bad = [];
  for (let i = 0; i < doc.cells.length; i++) {
    const key = doc.cells[i];
    if (key === UNCHANGED) continue;
    let r = memo.get(key);
    if (r === undefined) { r = resolveKey(doc, key, binding, P); memo.set(key, r); }
    if (r === UNCHANGED) continue;
    const [x, y, z] = doc.pos(i);
    if (r === AIR) out.push({ i, x, y, z, name: "air", p2: 0 });
    else if (Array.isArray(r)) out.push({ i, x, y, z, name: r[0], p2: r[1] });
    else bad.push({ i, error: r.error });
  }
  settlePanes(out, P);
  return { cells: out, bad };
}
// parts.resolve_panes over the cells (templates.resolve_panes).
export function settlePanes(cells, P) {
  const at = new Map(cells.map(c => [`${c.x},${c.y},${c.z}`, c]));
  const panes = cells.filter(c => (P.nodes[c.name] || {}).pane)
    .map(c => ({ c, base: c.name.endsWith("_flat") ? c.name.slice(0, -5) : c.name, p2: c.p2 }));
  for (const { c, base, p2 } of panes) {
    let anyDir = p2, total = 0;
    const hit = [];
    for (let d = 0; d < 4; d++) {
      const [dx, dz] = FACE_STEP[d];
      const n = at.get(`${c.x + dx},${c.y},${c.z + dz}`);
      hit[d] = !!(n && (P.nodes[n.name] || {}).connects);
      if (hit[d]) { anyDir = d; total++; }
    }
    if (total === 0) { c.name = base + "_flat"; c.p2 = p2; }
    else if (total === 1 || (total === 2 && ((hit[0] && hit[2]) || (hit[1] && hit[3])))) {
      c.name = base + "_flat"; c.p2 = (anyDir + 1) % 4;
    } else { c.name = base; c.p2 = 0; }
  }
}
