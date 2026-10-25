// The building template editor page (served by serve.py): a template list,
// then one template with the 3D view (the shared renderer.js) and the layer
// grid side by side, the item list (roles first, in the previewed race's
// material, then the editor palette), the tools, undo/redo/reset, a draft in
// local storage, and Save through the server's validator. The edit rules
// live in model.js.
import * as THREE from "three";
import { createNodeView, cellData } from "/renderer.js";
import {
  Doc, AIR, UNCHANGED, FACE_STEP, parseEntry, entryText, turned, resolveKey, resolvedCells,
  entryKind, entryShape, entryNode,
} from "/model.js";

const $ = id => document.getElementById(id);
const titleCase = s => s.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
const RACES = ["human", "dwarf", "elf", "orc", "troll", "undead"];
const POINT_COLORS = { doors: "#e8a317", inside: "#3f7ee8", room_corner: "#9b59b6", sockets: "#2fa36b", lights: "#ffd23f" };
const DRAFT = "grudge-template-draft:";

let A = null;          // assets: types, textures, meshes, palettes, editor_palette, ...
let P = null;          // palettes data
let oneMount = null;   // wallmounted nodes drawn for one mount only (serve.one_mount)
let typeIndex = null;  // node name -> type index
let colors = [];       // type index -> [r, g, b, alpha] (top texture average)
let tpl = null, doc = null;
let bindings = [], binding = null, bindingKey = null;
let layer = 0, tool = "paint", brush = null, above = "ghost", showChanged = true;
let selectedCell = null, selectedPoint = null, hoverCell = null;
let changed = new Set(), findings = [], findingCells = new Map();
let savedState = "", acknowledgedFixed = new Set();
let view = null, marks = null, ghost = null, groundMesh = null, labels = [];

// --------------------------------------------------------------- server ---
async function api(path, body) {
  const res = await fetch(path, body === undefined ? {} : {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({ error: `HTTP ${res.status}` }));
  return { ok: res.ok, status: res.status, data };
}

// ----------------------------------------------------------------- boot ---
async function boot() {
  const [assets, list] = await Promise.all([api("/api/assets"), api("/api/list")]);
  if (!assets.ok || !list.ok) { $("status").textContent = "The editor server did not answer."; return; }
  A = assets.data; P = A.palettes; oneMount = new Set(A.one_mount);
  typeIndex = new Map(A.types.map((t, i) => [t ? t.name : null, i]));
  for (const [alias, real] of Object.entries(A.aliases || {})) if (typeIndex.has(real)) typeIndex.set(alias, typeIndex.get(real));
  colors = await textureColors();
  renderHome(list.data);
  window.addEventListener("hashchange", route);
  await route();
  $("status").hidden = true;
}
async function route() {
  const q = new URLSearchParams(location.search);
  const name = (/^#tpl=([a-z0-9_]+)$/.exec(location.hash) || [])[1] || q.get("tpl");
  if (name && (!tpl || tpl.name !== name)) await open(name);
  else if (!name) showHome();
}
// The average colour of every node type's top texture, for the grid.
async function textureColors() {
  const avg = await Promise.all(A.textures.map(src => new Promise(resolve => {
    const img = new Image();
    img.onload = () => {
      const c = document.createElement("canvas"); c.width = c.height = 8;
      const g = c.getContext("2d"); g.drawImage(img, 0, 0, 8, 8);
      const d = g.getImageData(0, 0, 8, 8).data;
      let r = 0, gg = 0, b = 0, a = 0;
      for (let i = 0; i < d.length; i += 4) { const w = d[i + 3] / 255; r += d[i] * w; gg += d[i + 1] * w; b += d[i + 2] * w; a += w; }
      resolve(a ? [r / a, gg / a, b / a, a / 64] : [128, 128, 128, 0]);
    };
    img.onerror = () => resolve([200, 0, 200, 1]);
    img.src = src;
  })));
  return A.types.map(t => {
    if (!t) return [200, 0, 200, 1];
    const tex = t.tex && t.tex.length ? t.tex[0] : -1;
    return tex >= 0 ? avg[tex] : [200, 0, 200, 1];
  });
}

// ----------------------------------------------------------------- home ---
function renderHome(list) {
  const box = $("home-list");
  box.textContent = "";
  const groups = new Map();
  for (const [town, label] of list.towns) groups.set(town, { label, items: [] });
  for (const t of list.templates) {
    const key = t.town || "_none";
    if (!groups.has(key)) groups.set(key, { label: t.town ? titleCase(t.town) : "Not placed", items: [] });
    groups.get(key).items.push(t);
  }
  for (const g of groups.values()) {
    if (!g.items.length) continue;
    const h = document.createElement("h2"); h.textContent = `${g.label} · ${g.items.length}`; box.appendChild(h);
    const grid = document.createElement("div"); grid.className = "tpl-grid"; box.appendChild(grid);
    for (const t of g.items) {
      const b = document.createElement("button"); b.type = "button";
      b.innerHTML = "<span class=n></span><span class=u></span>";
      b.querySelector(".n").textContent = t.name;
      b.querySelector(".u").textContent = t.used_text;
      if (readDraft(t.name)) { const d = document.createElement("span"); d.className = "draft"; d.textContent = "draft kept in this browser"; b.appendChild(d); }
      b.onclick = () => { location.hash = "tpl=" + t.name; };
      b.dataset.name = t.name;
      grid.appendChild(b);
    }
  }
}
async function showHome() {
  if (tpl && dirty() && !(await ask("Leave this template?", "Your edits stay in this browser's draft until you save or reset them.", [["Stay", false], ["Leave", true, true]]))) {
    history.replaceState(null, "", "#tpl=" + tpl.name);
    return;
  }
  tpl = doc = null;
  $("editor").hidden = true; $("home").hidden = false; $("notice").hidden = true;
  const list = await api("/api/list");
  if (list.ok) renderHome(list.data);
}

// ------------------------------------------------------------- template ---
let openSeq = 0;
async function open(name, keepDraft) {
  const seq = ++openSeq;
  const res = await api("/api/template?name=" + encodeURIComponent(name));
  if (seq !== openSeq) return;  // a later open won
  if (!res.ok) { notice(`Cannot open ${name}: ${res.data.error}`); showHome(); return; }
  tpl = res.data;
  doc = new Doc(tpl);
  doc.optional = new Set([...P.optional, ...Object.keys(P.families).filter(f => !P.required.includes(f))]);
  savedState = JSON.stringify(doc.serialize());
  $("home").hidden = true; $("editor").hidden = false;
  $("name").textContent = tpl.name;
  $("used").textContent = `${tpl.used_text} · ${tpl.size.join(" × ")} · pivot ${tpl.pivot.join(" × ")} · ${tpl.path}`;
  bindings = [...tpl.bindings];
  for (const race of RACES) if (P.races[race]) bindings.push({ key: "race:" + race, label: titleCase(race) + " palette", binding: { main: { race, roles: P.races[race] } } });
  $("binding").textContent = "";
  for (const b of bindings) { const o = document.createElement("option"); o.value = b.key; o.textContent = b.label; $("binding").appendChild(o); }
  setBinding(bindings[0].key);
  layer = Math.max(doc.y0, Math.min(doc.y0 + doc.sy - 1, doc.points.find(p => p.group === "doors")?.y ?? 1));
  selectedCell = selectedPoint = null;
  findings = []; findingCells = new Map(); showFindings(null); message("Not checked yet.", "muted");
  acknowledgedFixed = new Set();
  if (!view) makeView();
  setGround();
  updateChanged();
  setTool("paint");
  setBrush(brushFor("role wall"), true);
  renderPoints();
  refreshAll();
  goOrbit();
  $("notice").hidden = true;
  if (!tpl.canonical)
    notice(`This file is not in the writer's canonical layout (${tpl.canonical_note}). It was not rewritten; a save writes it canonically.`);
  if (!keepDraft) offerDraft();
}
function placingBindings() {
  const placed = tpl.bindings.map(b => b.binding);
  if (placed.length) return placed;
  return tpl.races.filter(r => P.races[r]).map(race => ({ main: { race, roles: P.races[race] } }));
}
function setBinding(key) {
  bindingKey = key;
  binding = bindings.find(b => b.key === key).binding;
  $("binding").value = key;
  renderItems();
  refreshAll();
}
$("binding").onchange = () => setBinding($("binding").value);

// ------------------------------------------------------------ the items ---
// Brushes: {kind: "entry", text} | {kind: "door", variant, o} |
// {kind: "bed", role, o} | {kind: "air"} | {kind: "unchanged"}.
function brushFor(text) { return { kind: "entry", text: entryText(parseEntry(text)) }; }
function brushLabel(b) {
  if (b.kind === "door") return `door (${b.variant === "_a" ? "hinge a" : "hinge b"}) + door_hidden above, facedir ${b.o}`;
  if (b.kind === "bed") return `${b.role} (_bottom + _top), facedir ${b.o}`;
  return b.text;
}
function brushNode(b) {
  const text = b.kind === "door" ? `role door variant=${b.variant}` : b.kind === "bed" ? `role ${b.role} variant=_bottom` : b.text;
  const e = parseEntry(text);
  if (e.kind === "race") return null;
  const n = entryNode(e, binding, P);
  return n && !n.includes(" ") ? n : null;
}
function iconStyle(name) {
  const t = name ? A.types[typeIndex.get(name)] : null;
  if (!t || !t.tex) return "";
  const tex = t.tex[2] >= 0 ? t.tex[2] : t.tex[0];
  return tex >= 0 ? `background-image:url(${A.textures[tex]})` : "";
}
function roleAvailability(e) {
  // [disabled reason or null, note]
  const missing = [];
  for (const b of placingBindings()) {
    const n = entryNode(e, b, P);
    if (typeof n === "string" && n.includes(" ")) return [n, ""];
    if (n === null) missing.push(b.main.race);
  }
  const required = P.required.includes(e.name);
  const all = placingBindings().length;
  if (missing.length && (required || missing.length === all))
    return [`not bound for ${[...new Set(missing)].join(", ")}${required ? "" : " (no placing race has it)"}`, ""];
  return [null, missing.length ? `${[...new Set(missing)].join(", ")}: ${e.else ? "else=" + e.else : "falls back to the template's entry or air"}` : ""];
}
function renderItems() {
  const box = $("item-list");
  box.textContent = "";
  const q = $("search").value.trim().toLowerCase();
  const add = (title, items) => {
    const shown = items.filter(it => !q || it.search.toLowerCase().includes(q));
    if (!shown.length) return;
    const h = document.createElement("h3"); h.textContent = title; box.appendChild(h);
    for (const it of shown) {
      const b = document.createElement("button"); b.type = "button"; b.className = "item";
      b.innerHTML = `<span class="icon${it.role ? " role" : ""}" style="${iconStyle(it.node)}"></span><span class=t></span>`;
      b.querySelector(".t").textContent = it.label;
      if (it.tag) { const s = document.createElement("span"); s.className = "tag"; s.textContent = it.tag; b.querySelector(".t").append(document.createElement("br"), s); }
      b.title = it.title || it.label;
      if (it.disabled) { b.disabled = true; b.title = it.disabled; }
      b.onclick = () => { setBrush(it.brush); setTool("paint"); };
      b.dataset.brush = JSON.stringify(it.brush);
      if (brush && JSON.stringify(brush) === b.dataset.brush) b.classList.add("sel");
      box.appendChild(b);
    }
  };
  const palette = A.editor_palette;
  const roleGroup = palette.find(g => g[0] === "roles");
  const roleItems = [];
  const channels = new Map();
  for (const key of doc.keys) {
    const e = doc.entries.get(key);
    if (e.kind === "role" && e.channel) channels.set(e.name, [...new Set([...(channels.get(e.name) || []), e.channel])]);
  }
  for (const [, role] of roleGroup ? roleGroup[1] : []) {
    if (role === "door_hidden") continue;
    const variants = role === "door" ? [["_a", "door", { kind: "door", variant: "_a", o: 0 }], ["_b", "door, other hinge", { kind: "door", variant: "_b", o: 0 }]]
      : role === "bed" || role === "bed_fancy" ? [["_bottom", role + " (two cells)", { kind: "bed", role, o: 0 }]]
      : P.families[role] ? P.families[role].map(v => [v, `${role} ${v}`, brushFor(`role ${role} variant=${v}`)])
      : [[null, role, brushFor(`role ${role}`)], ...(channels.get(role) || []).map(c => [null, `${role} · ${c} palette`, brushFor(`role ${role} channel=${c}`)])];
    for (const [variant, label, b] of variants) {
      const e = parseEntry(b.kind === "entry" ? b.text : `role ${role}${variant ? " variant=" + variant : ""}`);
      const [disabled, note] = roleAvailability(e);
      const node = brushNode(b);
      roleItems.push({ label, brush: b, role: true, node, disabled, tag: note || (node ? node : "not in this palette"), search: `${label} ${node || ""}` });
    }
  }
  add(`Roles · ${bindings.find(b => b.key === bindingKey).label}`, roleItems);
  for (const [group, entries] of palette) {
    if (group === "roles") continue;
    add(group, entries.filter(([kind]) => kind === "node").map(([, name]) => {
      const over = A.overhang[name];
      return { label: name.replace(/^[^:]+:/, ""), node: name, brush: brushFor(`node ${name}`),
        tag: (A.descriptions[name] || "") + (over ? ` · reaches into the next cell (${over.join(", ")})` : ""),
        title: name, search: `${name} ${A.descriptions[name] || ""}` };
    }));
  }
}
$("search").oninput = renderItems;
async function setBrush(b, quiet) {
  if (b.kind === "entry" && parseEntry(b.text).kind === "node" && tpl.races.length > 1 && !acknowledgedFixed.has(b.text) && !quiet) {
    const ok = await ask("A fixed node in a shared template",
      `<p><b>${esc(parseEntry(b.text).name)}</b> is a fixed node: it is the same for every race. This template is placed by ${esc(tpl.races.join(" and "))}, so it would look the same in all of them.</p><p>Use a role where the races should differ. Paint the fixed node anyway?</p>`,
      [["Cancel", false], ["Use it", true, true]]);
    if (!ok) return false;
    acknowledgedFixed.add(b.text);
  }
  brush = b;
  const node = brushNode(b);
  const role = b.kind !== "entry" || parseEntry(b.text).kind === "role";
  $("brush").querySelector(".icon").className = "icon" + (role ? " role" : "");
  $("brush").querySelector(".icon").setAttribute("style", iconStyle(node));
  $("brush").querySelector(".lbl").textContent = brushLabel(b) + (node ? `  → ${node}` : "");
  $("turn-brush").disabled = !canTurnBrush();
  if (!inPalette(b)) message("This item is not in the editor palette: a cell painted with it is refused when saving.", "warn");
  for (const el of $("item-list").querySelectorAll(".item")) el.classList.toggle("sel", el.dataset.brush === JSON.stringify(b));
  return true;
}
// Is a brush's entry offered by the editor palette (format doc §7)? A picked
// cell may hold one that is not (river water, a station): it stays valid
// where it is, but the validator refuses it in an edited cell.
function inPalette(b) {
  if (b.kind !== "entry") return true;
  const e = parseEntry(b.text);
  const keys = e.kind === "race" ? Object.values(e.choices) : null;
  const entries = keys ? keys.map(k => doc.entry(k)).filter(Boolean) : [e];
  return entries.every(x => A.editor_palette.some(([, items]) => items.some(([kind, name]) => kind === x.kind && name === x.name)));
}
function canTurnBrush() {
  if (!brush) return false;
  if (brush.kind === "door" || brush.kind === "bed") return true;
  if (brush.kind !== "entry") return false;
  const e = parseEntry(brush.text);
  return e.kind !== "race" && !!turned(e, kindOf(e));
}
function turnBrush() {
  if (!canTurnBrush()) { message("This item does not turn.", "warn"); return; }
  if (brush.kind === "door" || brush.kind === "bed") setBrush({ ...brush, o: (brush.o + 1) % 4 }, true);
  else { const e = parseEntry(brush.text); setBrush(brushFor(turned(e, kindOf(e))), true); }
}
$("turn-brush").onclick = turnBrush;

// ----------------------------------------------------------------- tools ---
function setTool(t) {
  tool = t;
  for (const b of document.querySelectorAll("[data-tool]")) b.setAttribute("aria-pressed", String(b.dataset.tool === t));
  $("grid").style.cursor = t === "pick" ? "copy" : t === "point" ? "move" : "crosshair";
  if (t !== "point") { selectedPoint = null; renderPoints(); }
  drawGrid();
}
for (const b of document.querySelectorAll("[data-tool]")) b.onclick = () => setTool(b.dataset.tool);
// Turning follows the node's kind in every palette that places the template
// (the validator checks those, not the preview).
function kindOf(e) { return entryKind(e, placingBindings(), P); }
// Flipping upside down likewise: a shaped node of one shape in all of them.
// A torch (drawn for one mount only) does not flip in any of them.
function shapeOf(e) { return entryShape(e, placingBindings(), P, oneMount); }

// One tool use at a cell (grid or 3D). `rec` is the open stroke record.
function use(rec, x, y, z) {
  if (tool === "pick") { pickAt(x, y, z); return true; }
  if (tool === "rotate") return report(doc.rotate(rec, x, y, z, kindOf));
  if (tool === "flip") return report(doc.flip(rec, x, y, z, kindOf, shapeOf));
  if (tool === "point") { pointAt(x, y, z); return true; }
  const b = tool === "air" ? { kind: "air" } : tool === "unchanged" ? { kind: "unchanged" } : brush;
  return report(doc.apply(rec, x, y, z, b));
}
function report(r) { if (!r.ok) message(r.message, "warn"); return r.ok; }
function pickAt(x, y, z) {
  const v = doc.get(x, y, z);
  if (v === AIR) { setTool("air"); return; }
  if (v === UNCHANGED) { setTool("unchanged"); return; }
  const obj = doc.object(x, y, z);
  const e = doc.entry(obj ? doc.get(...obj.cells[0]) : v);
  let b;
  if (obj && obj.type === "door" && e.kind === "role" && e.name === "door") b = { kind: "door", variant: e.variant, o: e.o ? e.o[1] % 4 : 0 };
  else if (obj && obj.type === "bed" && e.kind === "role") b = { kind: "bed", role: e.name, o: e.o ? e.o[1] % 4 : 0 };
  else b = { kind: "entry", text: e.text };
  setBrush(b).then(ok => { if (ok) setTool("paint"); });
}
function pointAt(x, y, z) {
  const here = doc.points.map((p, i) => i).filter(i => doc.points[i].x === x && doc.points[i].y === y && doc.points[i].z === z);
  if (here.length) {
    const k = here.indexOf(selectedPoint);
    selectPoint(here[(k + 1) % here.length]);
    return;
  }
  if (selectedPoint === null) { message("Select a point first (click its marker, or pick it in the list under the grid).", "warn"); return; }
  const rec = doc.begin();
  if (report(doc.movePoint(rec, selectedPoint, x, y, z))) { doc.commit(rec); afterEdit(); }
}
function selectPoint(i) {
  selectedPoint = i;
  if (i !== null) { setTool("point"); selectedPoint = i; setLayer(doc.points[i].y); }
  renderPoints(); drawGrid(); refreshMarks();
}
function renderPoints() {
  if (!doc) return;
  const box = $("points-list");
  box.textContent = "";
  const moved = new Set(doc.movedSinceLoad());
  doc.points.forEach((p, i) => {
    const b = document.createElement("button"); b.type = "button";
    b.textContent = `${p.group}${p.id ? " " + p.id : ""} at ${p.x} ${p.y} ${p.z}${p.face !== null ? " face " + p.face : ""}`;
    b.classList.toggle("sel", i === selectedPoint);
    b.classList.toggle("moved", moved.has(i));
    b.onclick = () => selectPoint(i);
    box.appendChild(b);
  });
}

// ------------------------------------------------------------- edits ------
function afterEdit() {
  message(findings.length ? "Edited since the last check." : "Not checked yet.", "muted");
  updateChanged();
  renderPoints();
  refreshAll();
  scheduleDraft();
}
function dirty() { return doc && JSON.stringify(doc.serialize()) !== savedState; }
function updateChanged() {
  changed = doc.changedSinceHead();
  $("dirty").textContent = dirty() ? "unsaved edits" : "";
  $("undo").disabled = !doc.undoStack.length;
  $("redo").disabled = !doc.redoStack.length;
}
$("undo").onclick = () => { if (doc.undo()) afterEdit(); };
$("redo").onclick = () => { if (doc.redo()) afterEdit(); };
$("reset").onclick = async () => {
  if (dirty() && !(await ask("Reset to the saved file?", "Every edit since the last save is dropped, and the draft too.", [["Cancel", false], ["Reset", true, true]]))) return;
  dropDraft();
  await open(tpl.name, true);
  message("Back to the saved file.");
};

// -------------------------------------------------------------- drafts ----
function readDraft(name) { try { return JSON.parse(localStorage.getItem(DRAFT + name) || "null"); } catch { return null; } }
function dropDraft() { try { localStorage.removeItem(DRAFT + tpl.name); } catch { /* storage off */ } }
let draftTimer = 0;
function scheduleDraft() {
  clearTimeout(draftTimer);
  draftTimer = setTimeout(() => {
    if (!doc) return;
    try {
      if (dirty()) localStorage.setItem(DRAFT + tpl.name, JSON.stringify({ hash: tpl.hash, when: Date.now(), state: doc.serialize() }));
      else localStorage.removeItem(DRAFT + tpl.name);
    } catch { /* storage off: no draft */ }
  }, 300);
}
function offerDraft() {
  const d = readDraft(tpl.name);
  if (!d || JSON.stringify(d.state) === savedState) return;
  const when = new Date(d.when).toLocaleString();
  if (d.hash !== tpl.hash) {
    notice(`A draft from ${when} is kept in this browser, but the file changed since; it no longer applies.`, [["Discard draft", () => { dropDraft(); $("notice").hidden = true; }]]);
    return;
  }
  notice(`A draft from ${when} is kept in this browser (unsaved edits).`, [
    ["Restore", () => { doc.restore(d.state); afterEdit(); $("notice").hidden = true; message("Draft restored."); }],
    ["Discard", () => { dropDraft(); $("notice").hidden = true; }],
  ]);
}
window.addEventListener("beforeunload", e => { if (dirty()) { e.preventDefault(); e.returnValue = ""; } });

// ------------------------------------------------------- check and save ---
function payload(extra) { return { name: tpl.name, hash: tpl.hash, ...doc.serialize(), ...extra }; }
function showFindings(r) {
  const list = $("findings");
  list.textContent = "";
  findings = r ? [...r.errors.map(f => ({ ...f, level: "error" })), ...r.warnings.map(f => ({ ...f, level: "warn" })),
    ...r.elsewhere.map(f => ({ ...f, level: "error", message: "(another file) " + f.message }))] : [];
  findingCells = new Map();
  for (const f of findings) {
    if (f.pos && f.where === tpl.name) findingCells.set(f.pos.join(), f.level);
    const li = document.createElement("li"); li.className = f.level;
    const b = document.createElement("button"); b.type = "button";
    b.textContent = `${f.level === "error" ? "Error" : "Warning"} [${f.rule}]${f.pos ? ` at ${f.pos.join(" ")}` : ""}: ${f.message}`;
    if (f.pos) b.onclick = () => { setLayer(f.pos[1]); selectedCell = f.pos; drawGrid(); refreshMarks(); };
    li.appendChild(b); list.appendChild(li);
  }
  drawGrid(); refreshMarks(); renderLayers();
}
function message(text, level) { const m = $("message"); m.textContent = text; m.className = level || ""; }
// The validator builds every town and capital (a few seconds): the page
// is busy meanwhile and Check and Save wait.
function busy(on) {
  for (const id of ["check", "save"]) $(id).disabled = on;
  document.body.style.cursor = on ? "progress" : "";
}
async function runCheck() {
  message("Checking: the validator builds every town and capital (a few seconds)…", "muted");
  busy(true);
  const r = await api("/api/check", payload()).finally(() => busy(false));
  if (!r.ok) { message(r.data.error, "error"); return null; }
  showFindings(r.data);
  const d = r.data;
  message(d.errors.length ? `${d.errors.length} error(s): a save would be refused.` :
    d.warnings.length ? `No errors; ${d.warnings.length} warning(s) to confirm when saving.` :
    d.unchanged ? "No errors. The edit writes the file exactly as it is." : "No errors, no warnings.",
    d.errors.length ? "error" : d.warnings.length ? "warn" : "");
  return d;
}
$("check").onclick = runCheck;
$("save").onclick = save;
async function save() {
  const d = await runCheck();
  if (!d) return;
  if (d.errors.length) { message(`Save refused: ${d.errors.length} error(s), marked in the grid. Nothing was written.`, "error"); return; }
  if (d.unchanged && !d.stale) { message("Nothing to save: the file already holds this."); dropDraft(); return; }
  const shared = tpl.used > 1;
  const body = [`<p>Write <b>${esc(tpl.path)}</b>?</p>`,
    `<p>${shared ? "<b>" : ""}This template is ${esc(tpl.used_text)}${shared ? ": the change applies to every placement.</b>" : "."}</p>`];
  if (d.warnings.length) body.push(`<p>The validator has ${d.warnings.length} warning(s):</p><ul>${d.warnings.map(w => `<li>[${esc(w.rule)}]${w.pos ? " at " + w.pos.join(" ") : ""}: ${esc(w.message)}</li>`).join("")}</ul>`);
  body.push("<p class=muted>A template change changes what new worlds build: the release that ships it declares a map reset.</p>");
  const ok = await ask("Save the template", body.join(""), [["Cancel", false], [d.warnings.length ? "Save with the warnings" : "Save", true, true]]);
  if (!ok) return;
  message("Saving: the validator checks the edit once more (a few seconds)…", "muted");
  busy(true);
  const r = await api("/api/save", payload({ confirm: d.warnings.length > 0 })).finally(() => busy(false));
  if (!r.ok) {
    if (r.data.errors) showFindings(r.data);
    message("Not saved: " + r.data.error, "error");
    return;
  }
  dropDraft();
  const layerWas = layer, pose = view.pose(), mode = view.mode;
  await open(tpl.name, true);
  setLayer(layerWas);
  if (mode === "orbit") view.lookAt(pose.pos, pose.target);
  message(r.data.unchanged ? "Saved (the file was already this)." : `Saved ${tpl.path}.`);
}

// ------------------------------------------------------------- the grid ---
const grid = $("grid"), g2 = grid.getContext("2d");
let geo = null;  // {cs, left, top}
function setLayer(y) {
  layer = Math.max(doc.y0, Math.min(doc.y0 + doc.sy - 1, y));
  $("layer-label").textContent = `y ${layer}`;
  renderLayers();
  drawGrid();
  refresh3D();
}
$("layer-up").onclick = () => setLayer(layer + 1);
$("layer-down").onclick = () => setLayer(layer - 1);
function renderLayers() {
  if (!doc) return;
  const box = $("layers");
  box.textContent = "";
  const per = new Map();
  for (const i of changed) { const y = doc.pos(i)[1]; per.set(y, (per.get(y) || 0) | 1); }
  for (const k of findingCells.keys()) { const y = +k.split(",")[1]; per.set(y, (per.get(y) || 0) | 2); }
  for (let y = doc.y0 + doc.sy - 1; y >= doc.y0; y--) {
    const b = document.createElement("button"); b.type = "button"; b.textContent = y;
    b.setAttribute("aria-pressed", String(y === layer));
    if (per.get(y) & 1) b.classList.add("has-change");
    if (per.get(y) & 2) b.classList.add("has-error");
    b.onclick = () => setLayer(y);
    box.appendChild(b);
  }
}
function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }
let hatch = null;
function drawGrid() {
  if (!doc) return;
  const wrap = $("gridwrap");
  const cs = Math.max(14, Math.min(34, Math.floor((wrap.clientWidth - 52) / doc.sx), Math.floor((Math.max(wrap.clientHeight, 260) - 46) / doc.sz)));
  const left = 30, top = 18;
  const W = left + cs * doc.sx + 22, H = top + cs * doc.sz + 26;
  const dpr = window.devicePixelRatio || 1;
  grid.width = W * dpr; grid.height = H * dpr; grid.style.width = W + "px"; grid.style.height = H + "px";
  g2.setTransform(dpr, 0, 0, dpr, 0, 0);
  geo = { cs, left, top };
  const ink = css("--ink"), muted = css("--muted"), panel = css("--panel"), air = css("--air");
  g2.fillStyle = panel; g2.fillRect(0, 0, W, H);
  if (!hatch) {
    const c = document.createElement("canvas"); c.width = c.height = 8;
    const h = c.getContext("2d"); h.strokeStyle = "rgba(128,128,128,.55)"; h.lineWidth = 1.2;
    h.beginPath(); h.moveTo(0, 8); h.lineTo(8, 0); h.moveTo(-2, 2); h.lineTo(2, -2); h.moveTo(6, 10); h.lineTo(10, 6); h.stroke();
    hatch = g2.createPattern(c, "repeat");
    $("sw-unchanged").style.background = `url(${c.toDataURL()})`;
  }
  const z1 = doc.z0 + doc.sz - 1;
  const X = x => left + (x - doc.x0) * cs, Z = z => top + (z1 - z) * cs;
  const memo = new Map();
  g2.font = `600 ${Math.round(cs * 0.48)}px ${css("--font-data")}`;
  g2.textAlign = "center"; g2.textBaseline = "middle";
  for (let z = doc.z0; z <= z1; z++) for (let x = doc.x0; x < doc.x0 + doc.sx; x++) {
    const v = doc.get(x, layer, z), px = X(x), pz = Z(z);
    if (v === UNCHANGED) { g2.fillStyle = hatch; g2.fillRect(px, pz, cs, cs); continue; }
    g2.fillStyle = air; g2.fillRect(px, pz, cs, cs);
    if (v === AIR) { g2.fillStyle = muted; g2.fillRect(px + cs / 2 - 1, pz + cs / 2 - 1, 2, 2); continue; }
    if (!memo.has(v)) memo.set(v, resolveKey(doc, v, binding, P));
    const r = memo.get(v);
    const e = doc.entry(v);
    let lum = 1;
    if (Array.isArray(r) && !A.types[typeIndex.get(r[0])]) {
      // a node the renderer does not draw (doors:hidden is airlike)
      g2.fillStyle = muted; g2.fillRect(px + cs * 0.4, pz + cs * 0.4, cs * 0.2, cs * 0.2);
    } else if (Array.isArray(r)) {
      const ti = typeIndex.get(r[0]), t = A.types[ti], c = colors[ti] || [200, 0, 200, 1];
      const full = t && (t.dt === "normal" || t.dt.startsWith("allfaces") || t.dt.startsWith("glasslike"));
      g2.fillStyle = `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${Math.max(0.35, c[3])})`;
      const inset = full ? 0 : Math.round(cs * 0.18);
      g2.fillRect(px + inset, pz + inset, cs - 2 * inset, cs - 2 * inset);
      lum = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255;
    } else if (r === UNCHANGED) { g2.fillStyle = hatch; g2.fillRect(px, pz, cs, cs); }
    else if (r !== AIR) { g2.fillStyle = "#c62f38"; g2.fillRect(px + 2, pz + 2, cs - 4, cs - 4); }
    if (e && e.kind === "role") {
      g2.fillStyle = css("--role");
      g2.beginPath(); g2.moveTo(px, pz); g2.lineTo(px + cs * 0.38, pz); g2.lineTo(px, pz + cs * 0.38); g2.fill();
    }
    if (e && e.o && e.o[0] === "facedir") {
      const [dx, dz] = FACE_STEP[e.o[1] % 4];
      g2.strokeStyle = lum > 0.55 ? "rgba(0,0,0,.75)" : "rgba(255,255,255,.85)"; g2.lineWidth = 2;
      g2.beginPath(); g2.moveTo(px + cs / 2, pz + cs / 2); g2.lineTo(px + cs / 2 + dx * cs * 0.42, pz + cs / 2 - dz * cs * 0.42); g2.stroke();
    } else if (e && e.o && e.o[0] === "wallmounted" && e.o[1] >= 2) {
      const side = { 2: [-1, 0], 3: [1, 0], 4: [0, -1], 5: [0, 1] }[e.o[1]];
      g2.fillStyle = lum > 0.55 ? "rgba(0,0,0,.7)" : "rgba(255,255,255,.85)";
      const bx = px + cs / 2 + side[0] * cs * 0.38, bz = pz + cs / 2 - side[1] * cs * 0.38;
      g2.fillRect(bx - (side[0] ? 2 : cs * 0.3), bz - (side[1] ? 2 : cs * 0.3), side[0] ? 4 : cs * 0.6, side[1] ? 4 : cs * 0.6);
    }
    const part = doc.partKind(x, layer, z);
    if (part === "hidden") {
      // the locked upper cell of a door: a small padlock
      g2.fillStyle = "rgba(20,20,20,.75)";
      g2.fillRect(px + cs * 0.3, pz + cs * 0.45, cs * 0.4, cs * 0.32);
      g2.strokeStyle = "rgba(20,20,20,.75)"; g2.lineWidth = 2;
      g2.beginPath(); g2.arc(px + cs / 2, pz + cs * 0.45, cs * 0.13, Math.PI, 0); g2.stroke();
    } else if (cs >= 16) {
      g2.fillStyle = lum > 0.55 ? "rgba(0,0,0,.8)" : "rgba(255,255,255,.92)";
      g2.fillText(v, px + cs / 2, pz + cs / 2 + 1);
    }
  }
  // the box grid
  g2.strokeStyle = "rgba(128,128,128,.35)"; g2.lineWidth = 1;
  g2.beginPath();
  for (let x = 0; x <= doc.sx; x++) { g2.moveTo(left + x * cs + .5, top); g2.lineTo(left + x * cs + .5, top + doc.sz * cs); }
  for (let z = 0; z <= doc.sz; z++) { g2.moveTo(left, top + z * cs + .5); g2.lineTo(left + doc.sx * cs, top + z * cs + .5); }
  g2.stroke();
  // the footprint (pivot), dashed
  const [w, d] = tpl.pivot;
  g2.setLineDash([5, 4]); g2.strokeStyle = ink; g2.lineWidth = 1.5;
  g2.strokeRect(X(0), Z(d - 1), w * cs, d * cs);
  g2.setLineDash([]);
  // the street side and the entrance
  for (const s of streetSides()) {
    g2.strokeStyle = "#e8a317"; g2.lineWidth = 4;
    g2.beginPath();
    const [sx, sz] = s.dir;
    if (sz === -1) { g2.moveTo(X(0), Z(0) + cs + 3); g2.lineTo(X(w), Z(0) + cs + 3); }
    if (sz === 1) { g2.moveTo(X(0), Z(d - 1) - 3); g2.lineTo(X(w), Z(d - 1) - 3); }
    if (sx === -1) { g2.moveTo(X(0) - 3, Z(d - 1)); g2.lineTo(X(0) - 3, Z(0) + cs); }
    if (sx === 1) { g2.moveTo(X(w) + 3, Z(d - 1)); g2.lineTo(X(w) + 3, Z(0) + cs); }
    g2.stroke();
    const ax = X(s.p.x) + cs / 2, az = Z(s.p.z) + cs / 2;
    g2.fillStyle = "#e8a317";
    g2.beginPath();
    const tx = ax + sx * cs * 0.9, tz = az - sz * cs * 0.9;  // outside the door, pointing in
    g2.moveTo(ax + sx * cs * 0.35, az - sz * cs * 0.35);
    g2.lineTo(tx + sz * cs * 0.3, tz + sx * cs * 0.3);
    g2.lineTo(tx - sz * cs * 0.3, tz - sx * cs * 0.3);
    g2.fill();
  }
  // changed since commit, findings, selection
  const ring = (x, z, color, wdt) => { g2.strokeStyle = color; g2.lineWidth = wdt; g2.strokeRect(X(x) + wdt / 2 + 1, Z(z) + wdt / 2 + 1, cs - wdt - 2, cs - wdt - 2); };
  if (showChanged) for (const i of changed) { const [x, y, z] = doc.pos(i); if (y === layer) ring(x, z, css("--changed"), 2); }
  for (const [k, level] of findingCells) { const [x, y, z] = k.split(",").map(Number); if (y === layer) ring(x, z, level === "error" ? css("--error") : css("--warn"), 3); }
  // points on this layer
  doc.points.forEach((p, i) => {
    if (p.y !== layer) return;
    // a ring, so the cell's key stays readable
    const cx = X(p.x) + cs / 2, cz = Z(p.z) + cs / 2, r = cs * 0.4;
    g2.strokeStyle = "rgba(0,0,0,.55)"; g2.lineWidth = i === selectedPoint ? 6 : 4.5;
    g2.beginPath(); g2.arc(cx, cz, r, 0, Math.PI * 2); g2.stroke();
    g2.strokeStyle = POINT_COLORS[p.group] || "#e0464f"; g2.lineWidth = i === selectedPoint ? 4 : 2.5;
    g2.beginPath(); g2.arc(cx, cz, r, 0, Math.PI * 2); g2.stroke();
    if (p.face !== null) {
      const [dx, dz] = FACE_STEP[p.face];
      g2.beginPath(); g2.moveTo(cx, cz); g2.lineTo(cx + dx * cs * 0.5, cz - dz * cs * 0.5); g2.stroke();
    }
  });
  if (selectedCell && selectedCell[1] === layer) ring(selectedCell[0], selectedCell[2], ink, 3);
  if (hoverCell && hoverCell[1] === layer) ring(hoverCell[0], hoverCell[2], ink, 1);
  // axes: the template's own frame (the town turns it)
  g2.fillStyle = muted; g2.font = `11px ${css("--font-data")}`;
  for (let x = doc.x0; x < doc.x0 + doc.sx; x++) if (cs >= 18 || x % 2 === 0) g2.fillText(String(x), X(x) + cs / 2, top + doc.sz * cs + 9);
  g2.textAlign = "right";
  for (let z = doc.z0; z <= z1; z++) if (cs >= 18 || z % 2 === 0) g2.fillText(String(z), left - 4, Z(z) + cs / 2);
  g2.textAlign = "left";
  g2.fillText("z (north) ↑", left, 8);
  g2.fillText("x (east) →", left + doc.sx * cs - 64, top + doc.sz * cs + 20);
}
// The footprint sides the entrances open to: the street (a door point on
// the footprint edge or one step outside it, as the validator's entrance
// rule reads them); dir points out of the building.
function streetSides() {
  const [w, d] = tpl.pivot, out = [];
  for (const p of doc.points) {
    if (p.group !== "doors") continue;
    const onEdge = p.x >= -1 && p.x <= w && p.z >= -1 && p.z <= d && (p.x <= 0 || p.x >= w - 1 || p.z <= 0 || p.z >= d - 1);
    if (!onEdge) continue;
    let dir;
    if (p.face !== null) { const [dx, dz] = FACE_STEP[p.face]; dir = [-dx, -dz]; }
    else dir = p.z <= 0 ? [0, -1] : p.z >= d - 1 ? [0, 1] : p.x <= 0 ? [-1, 0] : [1, 0];
    out.push({ p, dir });
  }
  return out;
}
function cellAt(e) {
  if (!geo) return null;
  const r = grid.getBoundingClientRect();
  const cx = Math.floor((e.clientX - r.left - geo.left) / geo.cs), cz = Math.floor((e.clientY - r.top - geo.top) / geo.cs);
  if (cx < 0 || cz < 0 || cx >= doc.sx || cz >= doc.sz) return null;
  return [doc.x0 + cx, layer, doc.z0 + doc.sz - 1 - cz];
}
let stroke = null;
grid.addEventListener("pointerdown", e => {
  if (e.button !== 0) return;
  const c = cellAt(e);
  if (!c) return;
  selectedCell = c;
  if (e.altKey) { pickAt(...c); return; }
  const rec = doc.begin();
  const ok = use(rec, ...c);
  if (["paint", "air", "unchanged"].includes(tool) && !(brush && tool === "paint" && brush.kind !== "entry")) {
    stroke = { rec, last: c.join() };
    grid.setPointerCapture(e.pointerId);
  } else if (doc.commit(rec)) afterEdit();
  if (!stroke) { drawGrid(); refreshMarks(); }
  else if (ok) { drawGrid(); }
});
grid.addEventListener("pointermove", e => {
  const c = cellAt(e);
  hover(c);
  if (stroke && c && c.join() !== stroke.last) { stroke.last = c.join(); use(stroke.rec, ...c); drawGrid(); }
});
const endStroke = () => { if (!stroke) return; const rec = stroke.rec; stroke = null; if (doc.commit(rec)) afterEdit(); else drawGrid(); };
grid.addEventListener("pointerup", endStroke);
grid.addEventListener("pointercancel", endStroke);
grid.addEventListener("pointerleave", () => hover(null));
grid.addEventListener("wheel", e => { e.preventDefault(); setLayer(layer + (e.deltaY < 0 ? 1 : -1)); }, { passive: false });
function hover(c) {
  hoverCell = c;
  const box = $("hover");
  if (!c) { box.textContent = "Hover a cell."; box.className = "muted"; drawGrid(); return; }
  const v = doc.get(...c);
  const i = doc.index(...c);
  let text = `x ${c[0]}  y ${c[1]}  z ${c[2]}  ·  `;
  if (v === AIR) text += "force air (the building writes air)";
  else if (v === UNCHANGED) text += "leave unchanged (the building writes nothing)";
  else {
    const e = doc.entry(v), r = resolveKey(doc, v, binding, P);
    text += `key ${v}: ${e ? e.text : "?"}  →  ${Array.isArray(r) ? `${r[0]} param2 ${r[1]}` : r === AIR ? "air" : r === UNCHANGED ? "nothing" : r.error}`;
    const part = doc.partKind(...c);
    if (part) text += `  ·  ${{ leaf: "door (with the cell above)", hidden: "upper cell of a door (locked)", bottom: "bed foot", top: "bed head" }[part]}`;
  }
  if (changed.has(i)) text += "  ·  changed since commit";
  const f = findingCells.get(c.join());
  if (f) text += `  ·  ${f === "error" ? "validator error" : "validator warning"}`;
  const pts = doc.points.filter(p => p.x === c[0] && p.y === c[1] && p.z === c[2]);
  if (pts.length) text += "  ·  point " + pts.map(p => p.group + (p.id ? " " + p.id : "")).join(", ");
  box.textContent = text; box.className = "";
  drawGrid();
}
new ResizeObserver(() => drawGrid()).observe($("gridwrap"));

// ---------------------------------------------------------------- the 3D ---
function makeView() {
  const stage = $("stage");
  view = createNodeView({ stage, types: A.types, textures: A.textures, meshes: A.meshes,
    onPick: e => onPick(e), onFrame: () => placeLabels() });
  const fit = () => {
    const r = stage.getBoundingClientRect();
    if (!r.width || !r.height) return;
    view.renderer.setSize(r.width, r.height);
    view.camera.aspect = r.width / r.height;
    view.camera.updateProjectionMatrix();
  };
  new ResizeObserver(fit).observe(stage);
  window.addEventListener("resize", fit);
  fit();
  marks = new THREE.Group(); marks.renderOrder = 6;
  view.root.add(marks);
  for (const b of document.querySelectorAll("[data-mode]")) b.onclick = () => b.dataset.mode === "orbit" ? goOrbit() : b.dataset.mode === "walk" ? goWalk() : view.setMode("noclip");
  view.onMode(m => { for (const b of document.querySelectorAll("[data-mode]")) b.setAttribute("aria-pressed", String(b.dataset.mode === m)); hint(); });
  const pressAbove = () => { for (const b of document.querySelectorAll("[data-above]")) b.setAttribute("aria-pressed", String(b.dataset.above === above)); };
  for (const b of document.querySelectorAll("[data-above]")) b.onclick = () => { above = b.dataset.above; pressAbove(); refresh3D(); };
  pressAbove();
  $("show-changed").onclick = () => { showChanged = !showChanged; $("show-changed").setAttribute("aria-pressed", String(showChanged)); drawGrid(); refreshMarks(); };
  hint();
  view.start();
}
function hint() {
  const m = view.mode;
  $("viewhint").innerHTML = m === "orbit" ? "Drag to turn, right-drag to pan, scroll to zoom. A click applies the tool to the block under it."
    : m === "walk" ? "<kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> walk, drag to look, <kbd>Space</kbd> jump."
    : "Noclip: flies through walls. <kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd>, drag to look, <kbd>Space</kbd> up, <kbd>Shift</kbd> down, hold <kbd>E</kbd> faster.";
  for (const b of document.querySelectorAll("[data-mode]")) b.setAttribute("aria-pressed", String(b.dataset.mode === m));
}
function goOrbit() {
  const cx = doc.x0 + doc.sx / 2 - 0.5, cy = doc.y0 + doc.sy / 3, cz = doc.z0 + doc.sz / 2 - 0.5, r = Math.max(doc.sx, doc.sy, doc.sz, 6);
  view.lookAt([cx + r * 0.9, cy + r * 0.8, cz - r * 1.3], [cx, cy, cz]);
}
function goWalk() {
  const door = doc.points.find(p => p.group === "doors");
  if (!door) { view.setMode("walk"); return; }
  const [dx, dz] = FACE_STEP[door.face ?? 0];
  view.walkFrom([door.x - dx * 2, door.y, door.z - dz * 2], Math.atan2(-dx, dz));
}
function setGround() {
  if (groundMesh) { view.root.remove(groundMesh); groundMesh.geometry.dispose(); }
  const gy = doc.y0 <= 0 ? 0.5 : doc.y0 - 0.5;
  const g = new THREE.PlaneGeometry(doc.sx + 6, doc.sz + 6);
  g.rotateX(-Math.PI / 2);
  groundMesh = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ color: 0x8a9a6c, side: THREE.DoubleSide,
    polygonOffset: true, polygonOffsetFactor: 1, polygonOffsetUnits: 1 }));
  groundMesh.position.set(doc.x0 + doc.sx / 2 - 0.5, gy, doc.z0 + doc.sz / 2 - 0.5);
  view.root.add(groundMesh);
  view.groundLevel = gy;
}
function toData(list) {
  const n = list.length;
  const X = new Int16Array(n), Y = new Int16Array(n), Z = new Int16Array(n), T = new Uint16Array(n), P2 = new Uint8Array(n);
  list.forEach((c, k) => { X[k] = c.x; Y[k] = c.y; Z[k] = c.z; T[k] = c.t; P2[k] = c.p2; });
  return cellData(X, Y, Z, T, P2);
}
let refreshQueued = false;
function refreshAll() { drawGrid(); renderLayers(); $("layer-label").textContent = `y ${layer}`; refresh3D(); }
function refresh3D() {
  if (refreshQueued || !view) return;
  refreshQueued = true;
  requestAnimationFrame(() => { refreshQueued = false; rebuild3D(); });
}
function rebuild3D() {
  if (!doc) return;
  const { cells } = resolvedCells(doc, binding, P);
  const drawn = [];
  for (const c of cells) {
    if (c.name === "air") continue;
    const t = typeIndex.get(c.name);
    if (t !== undefined) drawn.push({ x: c.x, y: c.y, z: c.z, t, p2: c.p2 });
  }
  if (ghost) { view.root.remove(ghost); ghost.traverse(o => { o.geometry?.dispose(); o.material?.dispose?.(); }); ghost = null; }
  if (above === "ghost") {
    const up = drawn.filter(c => c.y > layer);
    if (up.length) {
      const before = new Set(view.root.children);
      view.filter.cut = Infinity;
      view.setData(toData(up));
      // The renderer disposes its own group on the next build, so the
      // ghost is a copy of it with see-through materials.
      const built = view.root.children.find(o => !before.has(o));
      if (built) {
        view.root.remove(built);
        ghost = new THREE.Group();
        built.traverse(o => {
          if (!o.isMesh) return;
          const m = new THREE.Mesh(o.geometry.clone(), o.material.clone());
          Object.assign(m.material, { transparent: true, opacity: 0.18, depthWrite: false });
          m.renderOrder = 3;
          ghost.add(m);
        });
      }
    }
  }
  view.filter.cut = above === "shown" ? Infinity : layer;
  view.setData(toData(drawn));
  if (ghost) view.root.add(ghost);
  if (groundMesh) groundMesh.visible = view.filter.cut >= groundMesh.position.y;
  refreshMarks();
}
function boxEdges(list, color, pad = 0.04) {
  const pos = [];
  const e = 0.5 + pad;
  const corners = [[-e,-e,-e],[e,-e,-e],[e,e,-e],[-e,e,-e],[-e,-e,e],[e,-e,e],[e,e,e],[-e,e,e]];
  const edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
  for (const [x, y, z] of list) for (const [a, b] of edges) pos.push(x + corners[a][0], y + corners[a][1], z + corners[a][2], x + corners[b][0], y + corners[b][1], z + corners[b][2]);
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  const l = new THREE.LineSegments(g, new THREE.LineBasicMaterial({ color, depthTest: false, transparent: true }));
  l.renderOrder = 7;
  return l;
}
function refreshMarks() {
  if (!marks || !doc) return;
  marks.traverse(o => { o.geometry?.dispose(); o.material?.dispose?.(); });
  marks.clear();
  const cut = above === "shown" ? Infinity : layer;
  // the current layer
  const slab = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(doc.sx, 1, doc.sz)),
    new THREE.LineBasicMaterial({ color: 0x2e6b52, depthTest: false, transparent: true, opacity: 0.8 }));
  slab.position.set(doc.x0 + doc.sx / 2 - 0.5, layer, doc.z0 + doc.sz / 2 - 0.5);
  slab.renderOrder = 7;
  marks.add(slab);
  // force air and leave unchanged on the current layer (ruling 25)
  const airPts = [], keepPts = [];
  for (let z = doc.z0; z < doc.z0 + doc.sz; z++) for (let x = doc.x0; x < doc.x0 + doc.sx; x++) {
    const v = doc.get(x, layer, z);
    if (v === AIR) airPts.push(x, layer, z); else if (v === UNCHANGED) keepPts.push(x, layer, z);
  }
  for (const [pts, color] of [[airPts, 0x3f7ee8], [keepPts, 0xd9a03a]]) {
    if (!pts.length) continue;
    const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pts, 3));
    const m = new THREE.Points(g, new THREE.PointsMaterial({ color, size: color === 0x3f7ee8 ? 0.16 : 0.22, sizeAttenuation: true, depthTest: true }));
    marks.add(m);
  }
  if (showChanged) {
    const list = [...changed].map(i => doc.pos(i)).filter(p => p[1] <= cut);
    if (list.length) marks.add(boxEdges(list, 0xe8a317));
  }
  const bad = [...findingCells.keys()].map(k => k.split(",").map(Number)).filter(p => p[1] <= cut);
  if (bad.length) marks.add(boxEdges(bad, 0xc62f38, 0.08));
  if (selectedCell) marks.add(boxEdges([selectedCell], 0xffd23f, 0.06));
  // points
  doc.points.forEach((p, i) => {
    if (p.y > cut) return;
    const m = new THREE.Mesh(new THREE.OctahedronGeometry(i === selectedPoint ? 0.3 : 0.2),
      new THREE.MeshBasicMaterial({ color: POINT_COLORS[p.group] || "#e0464f", depthTest: false, transparent: true }));
    m.renderOrder = 8; m.position.set(p.x, p.y, p.z);
    marks.add(m);
  });
  // the street side: an arrow from the street to each entrance
  const lab = [];
  for (const s of streetSides()) {
    const from = new THREE.Vector3(s.p.x + s.dir[0] * 3, s.p.y + 0.2, s.p.z + s.dir[1] * 3);
    const arrow = new THREE.ArrowHelper(new THREE.Vector3(-s.dir[0], 0, -s.dir[1]), from, 2.4, 0xe8a317, 0.7, 0.45);
    marks.add(arrow);
    lab.push({ text: "street side · entrance", cls: "street", pos: [from.x, from.y + 0.6, from.z] });
  }
  // the template frame's axes at the box corner (the town turns the template)
  const o = new THREE.Vector3(doc.x0 - 1, doc.y0 <= 0 ? 0.55 : doc.y0 - 0.45, doc.z0 - 1);
  marks.add(new THREE.ArrowHelper(new THREE.Vector3(1, 0, 0), o, 3, 0xc62f38, 0.5, 0.3));
  marks.add(new THREE.ArrowHelper(new THREE.Vector3(0, 0, 1), o, 3, 0x3f7ee8, 0.5, 0.3));
  lab.push({ text: "+x east", pos: [o.x + 3.3, o.y, o.z] }, { text: "+z north", pos: [o.x, o.y, o.z + 3.3] });
  if (selectedPoint !== null) { const p = doc.points[selectedPoint]; lab.push({ text: p.group + (p.id ? " " + p.id : ""), pos: [p.x, p.y + 0.5, p.z] }); }
  makeLabels(lab);
  view.select(null);
}
function makeLabels(items) {
  const layerEl = $("labels");
  layerEl.textContent = "";
  labels = items.map(it => {
    const el = document.createElement("div"); el.className = "label " + (it.cls || ""); el.textContent = it.text;
    layerEl.appendChild(el);
    return { el, pos: view.toThree(it.pos) };
  });
}
const tmp = new THREE.Vector3();
function placeLabels() {
  const r = $("stage").getBoundingClientRect();
  for (const l of labels) {
    tmp.copy(l.pos).project(view.camera);
    const ok = tmp.z < 1 && tmp.z > -1 && Math.abs(tmp.x) < 1.05 && Math.abs(tmp.y) < 1.05;
    l.el.hidden = !ok;
    if (ok) l.el.style.transform = `translate(${((tmp.x + 1) / 2 * r.width).toFixed(1)}px, ${((1 - tmp.y) / 2 * r.height).toFixed(1)}px) translate(-50%, -100%)`;
  }
}
function onPick(e) {
  if (!doc) return;
  const hit = view.pick(e.clientX, e.clientY);
  if (!hit || !doc.inBox(hit.x, hit.y, hit.z)) return;
  // A point moves onto the block clicked (the cell above it).
  const c = tool === "point" && doc.inBox(hit.x, hit.y + 1, hit.z) ? [hit.x, hit.y + 1, hit.z] : [hit.x, hit.y, hit.z];
  selectedCell = c;
  layer = c[1];
  const rec = doc.begin();
  use(rec, ...c);
  if (doc.commit(rec)) afterEdit();
  else { renderLayers(); $("layer-label").textContent = `y ${layer}`; drawGrid(); refresh3D(); }
}

// ------------------------------------------------------------ keyboard ----
window.addEventListener("keydown", e => {
  if (!doc || $("editor").hidden || !$("modal").hidden) return;
  if (["INPUT", "SELECT", "TEXTAREA"].includes(document.activeElement?.tagName)) return;
  const k = e.key.toLowerCase();
  if ((e.ctrlKey || e.metaKey) && k === "z") { e.preventDefault(); (e.shiftKey ? $("redo") : $("undo")).click(); return; }
  if ((e.ctrlKey || e.metaKey) && k === "y") { e.preventDefault(); $("redo").click(); return; }
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  if (e.key === "PageUp") { e.preventDefault(); setLayer(layer + 1); }
  else if (e.key === "PageDown") { e.preventDefault(); setLayer(layer - 1); }
  else if (view.mode !== "orbit") return;
  else if (k === "r") turnBrush();
  else if (k.length === 1 && "123456".includes(k)) setTool(["paint", "pick", "air", "unchanged", "rotate", "point"][+k - 1]);
});

// ------------------------------------------------------------- dialogs ----
function esc(s) { return String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); }
function ask(title, html, buttons) {
  return new Promise(resolve => {
    $("modal-title").textContent = title;
    $("modal-body").innerHTML = html.startsWith("<") ? html : `<p>${esc(html)}</p>`;
    const box = $("modal-buttons"); box.textContent = "";
    for (const [label, value, primary] of buttons) {
      const b = document.createElement("button"); b.type = "button"; b.textContent = label;
      if (primary) b.className = "primary";
      b.onclick = () => { $("modal").hidden = true; resolve(value); };
      box.appendChild(b);
    }
    $("modal").hidden = false;
    box.lastChild.focus();
  });
}
function notice(text, actions = []) {
  const n = $("notice");
  n.textContent = "";
  const s = document.createElement("span"); s.textContent = text; n.appendChild(s);
  for (const [label, fn] of actions) { const b = document.createElement("button"); b.type = "button"; b.textContent = label; b.onclick = fn; n.appendChild(b); }
  const x = document.createElement("button"); x.type = "button"; x.textContent = "✕"; x.setAttribute("aria-label", "Close"); x.onclick = () => { n.hidden = true; };
  n.appendChild(x);
  n.hidden = false;
}
$("back").onclick = () => { location.hash = ""; };

// The browser test's handle (tools/r56_editor/gui_run.py).
window.__editor = {
  get doc() { return doc; }, get tpl() { return tpl; }, get view() { return view; },
  get layer() { return layer; }, get tool() { return tool; }, get brush() { return brush; },
  setLayer, setTool, setBrush, open, dirty, kindOf, shapeOf, findings: () => findings,
  // The page position of a grid cell's centre on the current layer.
  cellPoint(x, z) {
    const r = grid.getBoundingClientRect();
    return [r.left + geo.left + (x - doc.x0 + 0.5) * geo.cs, r.top + geo.top + (doc.z0 + doc.sz - 1 - z + 0.5) * geo.cs];
  },
  ready: false,
};
boot().then(() => { window.__editor.ready = true; }).catch(err => { $("status").hidden = false; $("status").textContent = "Error: " + err.message; console.error(err); });
