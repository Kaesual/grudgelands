#!/usr/bin/env python3
"""Round 53 prep lane SKS: build the listening page for the skill cast cues.

python3 -I tools/r53_sks/build_page.py   (after cut.py; standard library only)

Round 2: candidates the user rejected are gone (rejected.md) and the re-cuts
(cut.py DERIVED) are not shown; the numbers #n are renumbered accordingly, the
keys (and so the stored ratings) are unchanged.

Writes page/index.html: page content only (title, style, markup, script; the
publisher wraps it), every candidate .ogg from out/ inlined as base64, so the
page needs no files beside it. Also writes page/local.html, the same page in a
document skeleton for file:// (gitignored, rebuilt on demand).

Ratings follow the Round 52 storage contract: collection `notes`, document id =
the candidate's key (the file stem; characters outside [A-Za-z0-9_.:@+-] would
be written as ~XX hex, none occur), fields {key, verdict, text, updatedAt},
verdict "pick" | "drop" | "".

The character line under each candidate is generated from cut.py's measurement
of the finished file (length, peak, RMS, spectral centroid and flatness, time
to the loudest 50 ms frame): it describes numbers, not listening.
"""

import base64
import html
import json
import re
import runpy
from pathlib import Path

HERE = Path(__file__).resolve().parent
CUT = runpy.run_path(str(HERE / "cut.py"))
ROWS, KEEP, EVENTS, source = CUT["ROWS"], CUT["KEEP"], CUT["EVENTS"], CUT["source"]
CUTS = json.loads((HERE / "cuts.json").read_text())
PAGE = HERE / "page"
LICENSE_MEDIA = CUT["SHIPPED"].parent / "LICENSE-media.md"

TREES = {  # tree -> German element word
    "Ember": "Feuer", "Rime": "Frost", "Bulwark": "Stahl", "Ruin": "Wut",
    "Mercy": "warmes Licht", "Reckoning": "Urteil", "Quarry": "Bogen, Natur", "Veil": "Schatten",
}
KIND = {"cast": "Wirken", "impact": "Einschlag", "launch": "Abschuss", "swing": "Schwung"}


def de(x, nd=1):
    return ("%.*f" % (nd, x)).replace(".", ",").replace("-", "−")


def shipped_sources():
    """Shipped file stem -> (source, author) from grug_sounds' licence table."""
    out = {}
    for line in LICENSE_MEDIA.read_text().splitlines():
        m = re.match(r"\| `sounds/(grug_sounds_[a-z_]+)\.ogg` \| [^|]+\| ([^|]+)\| \[([^\]]+)\]", line)
        if m:
            src = m.group(2).strip().strip("`")
            src = re.sub(r" \(Freesound (\d+), HQ preview, 128 kbit MP3\)", r" (Freesound \1)", src).replace('"', "")
            out[m.group(1)] = (src, m.group(3).replace(" (www.littlerobotsoundfactory.com)", ""))
    return out


def character(c):
    cen, fl = c["centroid"], c["flatness"]
    tone = ("sehr tief" if cen < 400 else "tief" if cen < 900 else "dunkel" if cen < 1800 else "mittig"
            if cen < 3500 else "hell" if cen < 6000 else "sehr hell")
    tex = "tonal" if fl < 0.05 else "überwiegend tonal" if fl < 0.15 else "gemischt" if fl < 0.3 else "rauschig"
    a, b = max(1, c["cen_first"]), max(1, c["cen_last"])
    trend = " · wird heller" if b > 1.4 * a else " · wird dunkler" if b < 0.7 * a else ""
    env = "sofort am lautesten" if c["to_peak"] <= 0.1 else "lauteste Stelle nach %s s" % de(c["to_peak"], 2)
    return "%s, %s (Schwerpunkt %s Hz)%s · %s" % (tone, tex, "{:,}".format(cen).replace(",", "."), trend, env)


def rows():
    ship = shipped_sources()
    out, n = [], 0
    for rkey, skill, kind, cls, tree, name, effect, why, reuse, _cands in ROWS:
        cands = []
        for key, c in sorted(((k, v) for k, v in CUTS.items() if v["row"] == rkey and not v.get("derived")),
                         key=lambda kv: kv[1]["n"]):
            n += 1
            if c["copied"]:
                ev = c["src"].split(":", 1)[1]
                src, who = ship[EVENTS[ev]]
                label = "schon im Spiel: %s" % ev
                cred = {"title": src, "author": who, "license": "wie ausgeliefert", "page": "", "license_url": ""}
            else:
                m = source(c["src"])
                label = m.get("fs_title") or m["file"]
                cred = {"title": label, "author": m["author"].replace(" (www.littlerobotsoundfactory.com)", ""),
                        "license": m["license"], "page": m["page"], "license_url": m["license_url"]}
                if "fs_id" in m:
                    cred["title"] = "Freesound %s" % m["fs_id"]
                cut = "Ausschnitt %s–%s s der Quelle" % (de(c["cut_start"], 2), de(c["cut_start"] + c["cut_len"], 2))
            facts = "%s s · Spitze %s dBFS · RMS %s dBFS" % (de(c["dur"], 2), de(c["peak_db"]), de(c["rms_db"]))
            if not c["copied"]:
                facts += " · " + cut
            cands.append({"n": n, "k": c["n"], "key": key, "label": label, "cred": cred,
                          "facts": facts, "char": character(c), "shipped": c["copied"], "dur": c["dur"]})
        out.append({"key": rkey, "skill": skill, "kind": KIND[kind], "cls": cls, "tree": tree, "el": TREES[tree],
                    "name": name, "effect": effect, "why": why, "cands": cands})
    return out


def groups(rs):
    """Class -> tree -> rows, in ROWS order, with the keep list per tree."""
    out = []
    for r in rs:
        if not out or out[-1]["cls"] != r["cls"]:
            out.append({"cls": r["cls"], "trees": []})
        trees = out[-1]["trees"]
        if not trees or trees[-1]["tree"] != r["tree"]:
            trees.append({"tree": r["tree"], "el": r["el"], "rows": [], "keep": []})
        trees[-1]["rows"].append(r)
    for cls, tree, name, sid, what, why in KEEP:
        g = next(g for g in out if g["cls"] == cls)
        t = next((t for t in g["trees"] if t["tree"] == tree), None)
        if t is None:
            t = {"tree": tree, "el": TREES[tree], "rows": [], "keep": []}
            g["trees"].append(t)
        t["keep"].append({"name": name, "id": sid, "what": what, "why": why})
    order = list(TREES)
    for g in out:
        g["trees"].sort(key=lambda t: order.index(t["tree"]))
    return out


STYLE = r"""
:root {
  --bg: #f4f2ee; --surface: #fcfbf8; --line: #ddd8ce; --fg: #26231e; --muted: #64604f;
  --accent: #6b4a2b; --accent-soft: #efe5d8; --ship: #7a6a3a; --good: #2f7a3c; --bad: #a33b2f;
  --display: "Bricolage Grotesque", "Segoe UI", system-ui, sans-serif;
  --body: "Source Sans 3", "Segoe UI", system-ui, sans-serif;
  --mono: "JetBrains Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #17150f; --surface: #1f1c16; --line: #3a352b; --fg: #ebe6db; --muted: #a39d8c;
    --accent: #d9a46b; --accent-soft: #2e261b; --ship: #c9b57a; --good: #7cc98a; --bad: #ec8a7c; color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #17150f; --surface: #1f1c16; --line: #3a352b; --fg: #ebe6db; --muted: #a39d8c;
  --accent: #d9a46b; --accent-soft: #2e261b; --ship: #c9b57a; --good: #7cc98a; --bad: #ec8a7c; color-scheme: dark;
}
* { box-sizing: border-box; }
body { background: var(--bg); color: var(--fg); font: 16px/1.5 var(--body); margin: 0; }
.wrap { max-width: 1080px; margin: 0 auto; padding: 28px 16px 64px; display: grid; gap: 40px; }
.wrap > *, #classes > *, .tree > *, .rows > * { min-width: 0; }
#classes { display: grid; gap: 48px; }
h1, h2, h3, h4 { font-family: var(--display); text-wrap: balance; margin: 0; line-height: 1.15; }
h1 { font-size: clamp(1.9rem, 4vw, 2.6rem); font-weight: 700; }
h2 { font-size: 1.55rem; font-weight: 700; }
h3 { font-size: 1.15rem; font-weight: 600; }
h4 { font-size: 1.05rem; font-weight: 600; }
p { margin: 0; max-width: 72ch; }
.lede { color: var(--muted); }
.default { font-weight: 600; border-left: 3px solid var(--accent); padding-left: 10px; }
header, section, .tree { display: grid; gap: 12px; }
.tree { gap: 14px; }
.eyebrow { font: 500 0.75rem var(--mono); letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); }
.facts { display: flex; flex-wrap: wrap; gap: 6px 18px; font: 0.82rem var(--mono); color: var(--muted); }
.status { font: 0.8rem var(--mono); color: var(--muted); min-height: 1.2em; overflow-wrap: anywhere; }
.status.ok { color: var(--good); } .status.err { color: var(--bad); }
.rows { display: grid; gap: 16px; }
.row { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 16px; display: grid; gap: 12px; }
.rowhead { display: flex; flex-wrap: wrap; gap: 8px 14px; align-items: baseline; justify-content: space-between; }
.badge { font: 500 0.72rem var(--mono); border: 1px solid var(--line); border-radius: 999px; padding: 1px 8px; color: var(--muted); }
.why { font-size: 0.88rem; color: var(--muted); }
.cands { display: grid; gap: 10px; }
.cand { border-top: 1px solid var(--line); padding-top: 10px; display: grid; gap: 6px; }
.cand.now { background: var(--accent-soft); border-radius: 6px; }
.chead { display: flex; gap: 10px; align-items: flex-start; min-width: 0; }
.meta { min-width: 0; flex: 1; display: grid; gap: 1px; }
.num { font: 600 0.72rem var(--mono); color: var(--muted); overflow-wrap: anywhere; }
.label { font-weight: 600; overflow-wrap: anywhere; }
.label.ship { color: var(--ship); }
.small { font: 0.72rem var(--mono); color: var(--muted); overflow-wrap: anywhere; }
.small a { color: inherit; }
.play { flex: none; width: 38px; height: 38px; border-radius: 50%; border: 1.5px solid var(--accent); background: transparent; color: var(--accent); cursor: pointer; display: grid; place-items: center; }
.play:hover { background: var(--accent-soft); }
.play[aria-pressed="true"] { background: var(--accent); color: var(--surface); }
.play svg { width: 13px; height: 13px; fill: currentColor; }
button:focus-visible, textarea:focus-visible, a:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.ctl { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
.chip { font: 0.82rem var(--body); border: 1px solid var(--line); background: transparent; color: var(--fg); border-radius: 999px; padding: 3px 12px; cursor: pointer; }
.chip:disabled, .btn:disabled { cursor: default; opacity: 0.6; }
.chip[aria-pressed="true"][data-v="pick"] { border-color: var(--good); color: var(--good); background: color-mix(in srgb, var(--good) 12%, transparent); }
.chip[aria-pressed="true"][data-v="drop"] { border-color: var(--bad); color: var(--bad); background: color-mix(in srgb, var(--bad) 12%, transparent); }
.btn { font: 600 0.8rem var(--body); border-radius: 8px; padding: 4px 12px; cursor: pointer; border: 1.5px solid var(--accent); background: transparent; color: var(--accent); }
.btn[aria-pressed="true"] { background: var(--accent); color: var(--surface); }
textarea { width: 100%; font: 0.88rem var(--body); color: var(--fg); background: var(--bg); border: 1px solid var(--line); border-radius: 6px; padding: 6px 8px; resize: vertical; min-height: 34px; }
textarea[readonly] { opacity: 0.75; }
.keep { display: grid; gap: 4px; font-size: 0.9rem; color: var(--muted); }
.keep b { color: var(--fg); font-weight: 600; }
"""

BODY = r"""
<div class="wrap">
  <header>
    <div class="eyebrow">Runde 53 · Vorbereitung · Lane SKS · Hörproben · 2026-10-20</div>
    <h1>Töne für die neuen Skills</h1>
    <p class="default">Pro Skill einen Favoriten wählen; nichts gewählt = Vorschlag 1 (schon im Spiel) bleibt.</p>
    <p class="lede">Je Zeile ein Skill (oder sein Einschlag). Vorschlag 1 ist der Ton, den der Rundenplan wiederverwenden will, genau die Datei aus dem Spiel; 2 bis 4 sind neue Kandidaten. „Vergleich“ spielt alle Vorschläge einer Zeile nacheinander. Alle Dateien sind auf dieselbe Spitze (−3 dBFS) gepegelt wie die ausgelieferten Zaubertöne; im Spiel bekommt jeder Ton seine eigene Lautstärke.</p>
    <p class="lede">Bewerte jeden Vorschlag: <b>Favorit</b> oder <b>raus</b>, gern mit Notiz (zu lang, zu leise, passt eher zu …). Die Zeile unter jedem Vorschlag ist gemessen (Länge, Pegel, Klangschwerpunkt), nicht gehört.</p>
    <div class="facts"><span>%COUNTS%</span><span>Mono-Ogg q3 wie im Spiel</span><span>CC0, CC BY 3.0, CC BY-SA 3.0</span></div>
    <div class="status" id="dbstatus" role="status">Speicher wird verbunden …</div>
  </header>
  <div id="classes"></div>
</div>
"""

SCRIPT = r"""
(() => {
  const DATA = JSON.parse(document.getElementById("row-data").textContent);
  const AUDIO = JSON.parse(document.getElementById("audio-data").textContent);
  const PLAY = '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M2 1l7 4-7 4z"/></svg>';
  const STOP = '<svg viewBox="0 0 10 10" aria-hidden="true"><rect x="2" y="2" width="6" height="6"/></svg>';
  const GAP = 0.6;   // seconds between candidates in "Vergleich"
  const sid = key => key.replace(/[^A-Za-z0-9_-]/g, "-");
  // Document ids: the key itself; characters the db does not allow (none in our keys) and "~" become ~XX.
  const docId = key => key.replace(/[^A-Za-z0-9_.:@+-]/g, c => "~" + c.charCodeAt(0).toString(16).padStart(2, "0"));
  const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
  const link = (text, href) => { const a = el("a", null, text); a.href = href; a.target = "_blank"; a.rel = "noopener"; return a; };

  // ---------- render ----------
  const ui = {};     // key -> {chips, note, save, status, play, box}
  const rowsUi = {}; // row key -> {btn, status, cands}
  const root = document.getElementById("classes");
  DATA.forEach((g, gi) => {
    const sec = el("section"); sec.setAttribute("aria-labelledby", "c" + gi);
    const h = el("h2", null, g.cls); h.id = "c" + gi; sec.appendChild(h);
    g.trees.forEach(t => {
      const tr = el("div", "tree");
      tr.appendChild(el("h3", null, t.tree + " · " + t.el));
      const rows = el("div", "rows");
      t.rows.forEach(r => rows.appendChild(row(g, t, r)));
      tr.appendChild(rows);
      if (t.keep.length) {
        const k = el("div", "keep");
        k.appendChild(el("div", "eyebrow", "Ohne eigene Zeile"));
        t.keep.forEach(x => {
          const p = el("p"); const b = el("b", null, x.name);
          p.append(b, document.createTextNode(" — bleibt " + x.what + ". " + x.why));
          k.appendChild(p);
        });
        tr.appendChild(k);
      }
      sec.appendChild(tr);
    });
    root.appendChild(sec);
  });

  function row(g, t, r) {
    const art = el("article", "row"); art.id = "row-" + sid(r.key);
    const head = el("div", "rowhead");
    const title = el("h4", null, r.name + (r.kind === "Einschlag" ? " · Einschlag" : r.kind === "Abschuss" ? " · Abschuss" : ""));
    const tags = el("div", "ctl");
    tags.append(el("span", "badge", g.cls + " · " + t.tree), el("span", "badge", r.kind));
    const cmp = el("button", "btn", "Vergleich"); cmp.type = "button"; cmp.id = "cmp-" + sid(r.key);
    cmp.setAttribute("aria-pressed", "false");
    cmp.setAttribute("aria-label", "Alle Vorschläge nacheinander: " + r.name + " (" + r.kind + ")");
    cmp.addEventListener("click", () => compare(r));
    tags.appendChild(cmp);
    head.append(title, tags);
    art.append(head, el("p", null, r.effect), el("p", "why", r.why));
    const list = el("div", "cands");
    r.cands.forEach(c => list.appendChild(cand(r, c)));
    art.appendChild(list);
    const st = el("span", "status"); st.setAttribute("role", "status");
    art.appendChild(st);
    rowsUi[r.key] = {btn: cmp, status: st, r};
    return art;
  }

  function cand(r, c) {
    const s = sid(c.key);
    const box = el("div", "cand");
    const head = el("div", "chead");
    const play = el("button", "play"); play.type = "button"; play.id = "play-" + s; play.innerHTML = PLAY;
    play.setAttribute("aria-pressed", "false");
    play.setAttribute("aria-label", "Abspielen: #" + c.n + " " + c.label);
    play.addEventListener("click", () => toggle(c.key));
    const meta = el("div", "meta");
    meta.appendChild(el("div", "num", "#" + c.n + " · Vorschlag " + c.k + " · " + c.key));
    meta.appendChild(el("div", "label" + (c.shipped ? " ship" : ""), c.label));
    const cr = el("div", "small");
    if (c.cred.page) cr.append(link(c.cred.title, c.cred.page), document.createTextNode(" · " + c.cred.author + " · "), link(c.cred.license, c.cred.license_url));
    else cr.textContent = "Quelle: " + c.cred.title + " · " + c.cred.author + " · " + c.cred.license;
    meta.append(cr, el("div", "small", c.facts), el("div", "small", "gemessen: " + c.char));
    head.append(play, meta);
    box.appendChild(head);
    const ctl = el("div", "ctl");
    const chips = [["pick", "Favorit"], ["drop", "raus"]].map(([v, label]) => {
      const b = el("button", "chip", label); b.type = "button"; b.dataset.v = v; b.id = v + "-" + s;
      b.setAttribute("aria-pressed", "false"); b.disabled = true;
      b.setAttribute("aria-label", label + ": #" + c.n);
      b.addEventListener("click", () => {
        const cur = local[c.key] || {verdict: "", text: ""};
        local[c.key] = {verdict: cur.verdict === v ? "" : v, text: note.value};
        paintVerdict(c.key); write(c.key);
      });
      ctl.appendChild(b); return b;
    });
    const save = el("button", "btn", "Speichern"); save.type = "button"; save.id = "save-" + s; save.disabled = true;
    save.addEventListener("click", () => write(c.key));
    const status = el("span", "status"); status.setAttribute("role", "status");
    ctl.append(save, status);
    const note = el("textarea"); note.id = "note-" + s; note.rows = 1; note.readOnly = true;
    note.placeholder = "Notiz zu #" + c.n;
    note.setAttribute("aria-label", "Notiz zu #" + c.n);
    note.addEventListener("input", () => { local[c.key] = {verdict: (local[c.key] || {}).verdict || "", text: note.value}; dirty[c.key] = true; });
    note.addEventListener("blur", () => write(c.key));
    box.append(ctl, note);
    ui[c.key] = {chips, note, save, status, play, box, row: r.key};
    return box;
  }

  // ---------- playback (Web Audio; one sound or one comparison at a time) ----------
  let ctx = null, cur = null;   // cur = {keys, i, src, row}
  const buffers = {};
  function bytes(b64) { const s = atob(b64); const u = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i); return u.buffer; }
  function buffer(key) {
    if (!buffers[key]) buffers[key] = new Promise((res, rej) => ctx.decodeAudioData(bytes(AUDIO[key]), res, rej));
    return buffers[key];
  }
  function mark(key, on) {
    const u = ui[key]; if (!u) return;
    u.play.setAttribute("aria-pressed", String(on)); u.play.innerHTML = on ? STOP : PLAY;
    u.box.classList.toggle("now", on);
  }
  function stop() {
    if (!cur) return;
    const c = cur; cur = null;
    try { if (c.src) { c.src.onended = null; c.src.stop(); } } catch (e) {}
    if (c.timer) clearTimeout(c.timer);
    c.keys.forEach(k => mark(k, false));
    if (c.row) rowsUi[c.row].btn.setAttribute("aria-pressed", "false");
  }
  async function start(keys, rowKey) {
    stop();
    const me = {keys, i: 0, src: null, row: rowKey, timer: null};
    cur = me;
    if (rowKey) rowsUi[rowKey].btn.setAttribute("aria-pressed", "true");
    try {
      if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === "suspended") await ctx.resume();
      await next(me);
    } catch (e) {
      const st = rowKey ? rowsUi[rowKey].status : ui[keys[0]].status;
      st.textContent = "Wiedergabe nicht möglich: dieser Browser dekodiert kein Ogg Vorbis (Firefox oder Chrome nutzen).";
      st.className = "status err";
      stop();
    }
  }
  async function next(me) {
    if (cur !== me) return;
    if (me.i >= me.keys.length) { stop(); return; }
    const key = me.keys[me.i];
    const buf = await buffer(key);
    if (cur !== me) return;
    const src = ctx.createBufferSource(); src.buffer = buf; src.connect(ctx.destination);
    me.src = src;
    me.keys.forEach(k => mark(k, k === key));
    src.onended = () => {
      if (cur !== me) return;
      mark(key, false);
      me.i += 1;
      me.timer = setTimeout(() => next(me).catch(() => stop()), me.keys.length > 1 ? GAP * 1000 : 0);
    };
    src.start();
  }
  function toggle(key) {
    if (cur && !cur.row && cur.keys[0] === key) { stop(); return; }
    start([key], null);
  }
  function compare(r) {
    if (cur && cur.row === r.key) { stop(); return; }
    start(r.cands.map(c => c.key), r.key);
  }

  // ---------- ratings (db capability: collection "notes") ----------
  let db = null, readOnly = true;
  const stored = {};   // key -> {verdict, text} as last seen in the store
  const local = {};    // key -> {verdict, text} as shown
  const dirty = {}, writing = {}, again = {};
  const header = document.getElementById("dbstatus");
  function setStatus(node, text, kind) { node.textContent = text; node.classList.toggle("ok", kind === "ok"); node.classList.toggle("err", kind === "err"); }
  function paintVerdict(key) {
    const v = (local[key] || {}).verdict || "";
    ui[key].chips.forEach(b => b.setAttribute("aria-pressed", String(b.dataset.v === v)));
  }
  function paintAll() {
    Object.keys(ui).forEach(key => {
      const u = ui[key];
      paintVerdict(key);
      if (!dirty[key] && document.activeElement !== u.note) u.note.value = (local[key] || {}).text || "";
      u.chips.forEach(b => (b.disabled = readOnly));
      u.note.readOnly = readOnly; u.save.disabled = readOnly;
    });
  }
  function goReadOnly(msg) {
    readOnly = true; paintAll();
    setStatus(header, msg || "Bewertungen sind hier nur lesbar; abgeben lassen sie sich auf der veröffentlichten Seite.", "err");
  }
  const MSG = {
    invalid_argument: "abgelehnt (keine Schreibrechte?)",
    resource_exhausted: "zu viele Anfragen, gleich noch einmal versuchen",
    quota_exceeded: "Speicher voll",
    unavailable: "Speicher gerade nicht erreichbar",
    revoked: "Zugriff entzogen",
  };
  async function write(key) {
    if (readOnly || !db) return;
    if (writing[key]) { again[key] = true; return; }
    const want = local[key] || {verdict: "", text: ""};
    const have = stored[key] || {verdict: "", text: ""};
    if (want.verdict === have.verdict && want.text === have.text) { dirty[key] = false; return; }
    const u = ui[key];
    writing[key] = true;
    setStatus(u.status, "speichert …");
    const ref = db.collection("notes").doc(docId(key));
    const attempt = () => (!want.verdict && !want.text)
      ? ref.delete()
      : ref.set({key, verdict: want.verdict, text: want.text, updatedAt: new Date().toISOString()});
    try {
      try { await attempt(); }
      catch (e) {
        if (!e || e.code !== "unavailable") throw e;
        await new Promise(r => setTimeout(r, 300 + Math.random() * 700));
        await attempt();
      }
      stored[key] = {verdict: want.verdict, text: want.text};
      if ((local[key] || {}).text === want.text) dirty[key] = false;
      setStatus(u.status, "Gespeichert", "ok");
    } catch (e) {
      const code = e && e.code || "unbekannt";
      setStatus(u.status, "Nicht gespeichert: " + (MSG[code] || "Fehler (" + code + ")"), "err");
      if (code === "invalid_argument" || code === "revoked") goReadOnly();
    } finally {
      writing[key] = false;
      if (again[key]) { again[key] = false; write(key); }
    }
  }
  function subscribe() {
    db.collection("notes").onSnapshot(snap => {
      const seen = {};
      snap.docs.forEach(d => {
        const v = d.data() || {};
        const key = typeof v.key === "string" ? v.key : d.id;
        if (!ui[key]) return;
        seen[key] = true;
        stored[key] = {verdict: v.verdict === "pick" || v.verdict === "drop" ? v.verdict : "", text: typeof v.text === "string" ? v.text : ""};
      });
      Object.keys(stored).forEach(k => { if (!seen[k]) delete stored[k]; });
      Object.keys(ui).forEach(k => { if (!dirty[k] && !writing[k]) local[k] = Object.assign({verdict: "", text: ""}, stored[k]); });
      paintAll();
      const picked = new Set(Object.keys(stored).filter(k => stored[k].verdict === "pick").map(k => ui[k].row));
      setStatus(header, "Speicher verbunden · Favorit in " + picked.size + " von " + Object.keys(rowsUi).length + " Zeilen", "ok");
    }, e => {
      const code = e && e.code || "unbekannt";
      if (code === "unavailable") { setTimeout(subscribe, 2000); return; }
      if (code === "revoked") { goReadOnly(); return; }
      setStatus(header, "Bewertungen konnten nicht geladen werden (" + (MSG[code] || code) + ")", "err");
    });
  }
  (async () => {
    const use = window.claude && typeof window.claude.use === "function" ? window.claude.use.bind(window.claude) : null;
    if (!use) { goReadOnly(); return; }
    try { db = await use("db"); } catch (e) { db = null; }
    if (!db) { goReadOnly(); return; }
    readOnly = false; paintAll();
    subscribe();
  })();
})();
"""


def main():
    rs = rows()
    data = groups(rs)
    cands = [c for r in rs for c in r["cands"]]
    audio = {c["key"]: base64.b64encode((HERE / "out" / (c["key"] + ".ogg")).read_bytes()).decode() for c in cands}
    js_json = lambda o: json.dumps(o, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    counts = "%d Zeilen · %d Vorschläge (%d neu) · %d Skills ohne eigene Zeile" % (
        len(rs), len(cands), sum(1 for c in cands if not c["shipped"]), len(KEEP))
    page = "\n".join([
        "<title>Skill-Töne Runde 53</title>",
        '<link rel="preconnect" href="https://fonts.googleapis.com">',
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700&family=Source+Sans+3:wght@400;600&family=JetBrains+Mono:wght@400;500;600&display=swap">',
        "<style>" + STYLE + "</style>",
        BODY.replace("%COUNTS%", html.escape(counts)),
        '<script type="application/json" id="row-data">' + js_json(data) + "</script>",
        '<script type="application/json" id="audio-data">' + js_json(audio) + "</script>",
        "<script>" + SCRIPT + "</script>",
        "",
    ])
    PAGE.mkdir(exist_ok=True)
    (PAGE / "index.html").write_text(page)
    (PAGE / "local.html").write_text('<!doctype html>\n<html lang="de">\n<head>\n<meta charset="utf-8">\n'
                                     '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
                                     "</head>\n<body>\n" + page + "</body>\n</html>\n")
    print("page/index.html %.2f MB, %d rows, %d candidates" % ((PAGE / "index.html").stat().st_size / 1e6,
                                                              len(rs), len(cands)))


if __name__ == "__main__":
    main()
