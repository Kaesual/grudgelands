#!/usr/bin/env python3
"""Round 52 lane SND: build the listening page for the staged cuts.

python3 -I tools/r52_snd/build_page.py   (after cut.py build; standard library only)

Writes page/index.html: page content only (title, style, markup, script; the
publisher wraps it), every staged .ogg from out/ inlined as base64, so the page
needs no files beside it. Also writes page/local.html, the same page wrapped in
a document skeleton for opening from file:// (gitignored, rebuilt on demand).

Ratings follow the Round 52 storage contract: collection `notes`, document id =
the candidate's key (the target file stem; characters outside [A-Za-z0-9_.:@+-]
would be written as ~XX hex, none occur), fields {key, verdict, text,
updatedAt}, verdict "keep" | "redo" | "".
"""

import base64
import html
import json
import runpy
from pathlib import Path

HERE = Path(__file__).resolve().parent
CUT = runpy.run_path(str(HERE / "cut.py"))
BEDS, CALLS, info_row = CUT["BEDS"], CUT["CALLS"], CUT["info_row"]
WINDOWS = json.loads((HERE / "windows.json").read_text())
PAGE = HERE / "page"

# Sound groups in page order: (group, German name, German note on how the game uses them).
GROUPS = [
    ("battlegrounds", "Schlachtfelder", "Eigenes Bett der vier Frontzonen, Tag und Nacht. Die Böen von früher wandern in den Höhenwind."),
    ("crags", "Felsen (Tag)", "Tagsüber eins der drei per Zufall, nachts still. Die zwei Vogel-Aufnahmen sind nur 36 s lang: ihr Loop nutzt fast die ganze Datei (33 und 34 s)."),
    ("crags_snowy", "Schneefelsen", "Tag und Nacht dasselbe Bett."),
    ("badlands", "Badlands", "Tagsüber eins von zwei per Zufall, nachts die Grillen."),
    ("swamp", "Sumpf", "Frösche Tag und Nacht; nachts im Zufallspool dazu der späte Abend und die tropische Nacht (steht unter Dschungel)."),
    ("jungle", "Dschungel bei Nacht", "Vier Betten im Zufallspool. Die tropische Nacht läuft auch nachts im Sumpf."),
    ("temperate", "Gemäßigt bei Nacht", "Kommen zu Waldnacht und Grillen in den nächtlichen Zufallspool von Wiese, Wald, Elfenwald und Kiefernhügeln."),
]
# Hints from the measurement, shown under a candidate (German).
HINTS = {
    "crags_birds": "Die Vögel singen vor allem in der ersten Hälfte, danach ist es ruhig; an der Naht setzen sie über die 2-s-Überblendung wieder ein.",
    "crags_birds_clear": "Kurze Aufnahme: der Loop ist 34 s lang und wiederholt sich deshalb hörbar öfter als die anderen.",
    "night_tropical": "Ein einzelner Ruf liegt etwa 12 dB über dem Bett (bei 0:06 im Loop); in dieser Aufnahme gibt es keine ruhigere Stelle.",
}
CALL_NOTE = "Einzelne Tierrufe, alle 90–240 s; das Spiel wählt eine der zwei Varianten. Hier einmal abgespielt, Spitze auf −3 dBFS wie der Donner."


def de(x, nd=1):
    return ("%.*f" % (nd, x)).replace(".", ",").replace("-", "−")


def candidates():
    out, n = [], 0
    for g, gname, gnote in GROUPS:
        items = []
        for key, pid, fid, *_rest in BEDS:
            if _rest[2] != g or key not in WINDOWS:
                continue
            n += 1
            items.append(entry(n, key, pid, fid, _rest[3], "bed"))
        out.append({"group": gname, "note": gnote, "items": items})
    items = []
    for key, pid, fid, start, length, title in CALLS:
        if key in WINDOWS:
            n += 1
            items.append(entry(n, key, pid, fid, title, "call"))
    out.append({"group": "Rufe", "note": CALL_NOTE, "items": items})
    return out


def entry(n, key, pid, fid, title, kind):
    w = WINDOWS[key]
    _, user, page = info_row(fid)
    a, b = w["window"]
    if kind == "bed":
        cut = "Ausschnitt %s–%s s · Loop %s s · %s LUFS · Spitze %s dBFS" % (
            de(a), de(b), de(w["loop"], 0) if w["loop"] == int(w["loop"]) else de(w["loop"]), de(w["lufs"]), de(w["peak_db"]))
    else:
        cut = "Ausschnitt %s–%s s · %s s · Spitze %s dBFS" % (de(a, 2), de(b, 2), de(w["seconds"]), de(w["peak_db"]))
    return {"n": n, "key": key, "kind": kind, "title": title, "file": "grug_ambience_%s.ogg" % key,
            "user": user, "url": page, "cut": cut, "hint": HINTS.get(key, ""), "pid": pid,
            "dur": w["seconds"]}


STYLE = r"""
:root {
  --bg: #f3f4ef; --surface: #fbfcf8; --line: #d8dccf; --fg: #22271f; --muted: #5d6656;
  --accent: #3f6b3a; --accent-soft: #e2ecdc; --seam: #a0702a; --good: #2f7a3c; --bad: #a33b2f;
  --display: "Bricolage Grotesque", "Segoe UI", system-ui, sans-serif;
  --body: "Source Sans 3", "Segoe UI", system-ui, sans-serif;
  --mono: "JetBrains Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #161a15; --surface: #1d221b; --line: #343b30; --fg: #e4e8de; --muted: #9aa392;
    --accent: #8cc27f; --accent-soft: #263222; --seam: #dba85c; --good: #7cc98a; --bad: #ec8a7c; color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #161a15; --surface: #1d221b; --line: #343b30; --fg: #e4e8de; --muted: #9aa392;
  --accent: #8cc27f; --accent-soft: #263222; --seam: #dba85c; --good: #7cc98a; --bad: #ec8a7c; color-scheme: dark;
}
* { box-sizing: border-box; }
body { background: var(--bg); color: var(--fg); font: 16px/1.5 var(--body); margin: 0; }
.wrap { max-width: 1080px; margin: 0 auto; padding: 28px 16px 64px; display: grid; gap: 36px; }
.wrap > *, #groups > * { min-width: 0; }
#groups { display: grid; gap: 36px; }
h1, h2, h3 { font-family: var(--display); text-wrap: balance; margin: 0; line-height: 1.15; }
h1 { font-size: clamp(1.9rem, 4vw, 2.6rem); font-weight: 700; }
h2 { font-size: 1.4rem; font-weight: 700; }
h3 { font-size: 1.05rem; font-weight: 600; }
p { margin: 0; max-width: 70ch; }
.lede { color: var(--muted); }
header, section { display: grid; gap: 12px; }
.eyebrow { font: 500 0.75rem var(--mono); letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); }
.facts { display: flex; flex-wrap: wrap; gap: 6px 18px; font: 0.82rem var(--mono); color: var(--muted); }
.status { font: 0.82rem var(--mono); color: var(--muted); min-height: 1.2em; overflow-wrap: anywhere; }
.status.ok { color: var(--good); } .status.err { color: var(--bad); }
.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 330px), 1fr)); gap: 14px; }
.card { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 14px; display: grid; gap: 9px; align-content: start; min-width: 0; }
.head { display: flex; gap: 10px; align-items: flex-start; min-width: 0; }
.meta { min-width: 0; flex: 1; display: grid; gap: 2px; }
.num { font: 600 0.75rem var(--mono); color: var(--muted); }
.small { font: 0.72rem var(--mono); color: var(--muted); overflow-wrap: anywhere; }
.small a { color: inherit; }
.hint { font-size: 0.86rem; color: var(--muted); border-left: 3px solid var(--seam); padding-left: 8px; }
.play { flex: none; width: 40px; height: 40px; border-radius: 50%; border: 1.5px solid var(--accent); background: transparent; color: var(--accent); cursor: pointer; display: grid; place-items: center; }
.play:hover { background: var(--accent-soft); }
.play[aria-pressed="true"] { background: var(--accent); color: var(--surface); }
.play svg { width: 14px; height: 14px; fill: currentColor; }
button:focus-visible, textarea:focus-visible, a:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.track { display: flex; align-items: center; gap: 10px; }
.bar { position: relative; flex: 1; height: 8px; border-radius: 4px; background: var(--line); overflow: hidden; }
.bar i { position: absolute; inset: 0 auto 0 0; width: 0; background: var(--accent); }
.bar b { position: absolute; top: 0; bottom: 0; left: 50%; width: 2px; margin-left: -1px; background: var(--seam); display: none; }
.bar.seam b { display: block; }
.time { font: 0.72rem var(--mono); color: var(--muted); font-variant-numeric: tabular-nums; min-width: 9ch; text-align: right; }
.row { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
.chip { font: 0.82rem var(--body); border: 1px solid var(--line); background: transparent; color: var(--fg); border-radius: 999px; padding: 3px 12px; cursor: pointer; }
.chip:disabled, .btn:disabled { cursor: default; opacity: 0.6; }
.chip[aria-pressed="true"][data-v="keep"] { border-color: var(--good); color: var(--good); background: color-mix(in srgb, var(--good) 12%, transparent); }
.chip[aria-pressed="true"][data-v="redo"] { border-color: var(--bad); color: var(--bad); background: color-mix(in srgb, var(--bad) 12%, transparent); }
.btn { font: 600 0.8rem var(--body); border-radius: 8px; padding: 4px 12px; cursor: pointer; border: 1.5px solid var(--accent); background: transparent; color: var(--accent); }
textarea { width: 100%; font: 0.88rem var(--body); color: var(--fg); background: var(--bg); border: 1px solid var(--line); border-radius: 6px; padding: 6px 8px; resize: vertical; min-height: 36px; }
textarea[readonly] { opacity: 0.75; }
.ro { font-size: 0.86rem; color: var(--muted); }
"""

BODY = r"""
<div class="wrap">
  <header>
    <div class="eyebrow">Runde 52 · Lane SND · Klangschnitte zur Freigabe · 2026-10-19</div>
    <h1>Neue Klangschnitte</h1>
    <p class="lede">Die fertigen Dateien für die Biom-Kulisse, genau so, wie sie ins Spiel kämen. Jedes Bett spielt <b>zweimal hintereinander</b>: die Marke in der Mitte des Balkens ist die Naht, an der der Loop von vorn beginnt. „Naht“ spielt nur die 4 s davor und danach. Rufe spielen einmal. Betten auf −20 LUFS gepegelt wie die Spiel-Betten, also untereinander und mit der letzten Seite vergleichbar; im Spiel laufen sie viel leiser.</p>
    <p class="lede">Bewerte jede Datei: <b>passt</b> (so ins Spiel) oder <b>neu schneiden</b>, gern mit Notiz (Stelle, Störgeräusch). Ein neuer Schnitt erscheint dann als weitere Nummer auf dieser Seite.</p>
    <div class="facts"><span>%COUNTS%</span><span>alle CC0 (Freesound)</span><span>Mono-Ogg wie im Spiel</span><span>Loop-Naht: 2 s Überblendung</span><span>60 Hz Hochpass</span></div>
    <div class="status" id="dbstatus" role="status">Speicher wird verbunden …</div>
  </header>
  <div id="groups"></div>
</div>
"""

SCRIPT = r"""
(() => {
  const DATA = JSON.parse(document.getElementById("cand-data").textContent);
  const AUDIO = JSON.parse(document.getElementById("audio-data").textContent);
  const PLAY = '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M2 1l7 4-7 4z"/></svg>';
  const STOP = '<svg viewBox="0 0 10 10" aria-hidden="true"><rect x="2" y="2" width="6" height="6"/></svg>';
  const SEAM_PAD = 4;
  const sid = key => key.replace(/[^A-Za-z0-9_-]/g, "-");
  // Document ids: the key itself; characters the db does not allow (none in our keys) and "~" become ~XX.
  const docId = key => key.replace(/[^A-Za-z0-9_.:@+-]/g, c => "~" + c.charCodeAt(0).toString(16).padStart(2, "0"));
  const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
  const fmt = s => { s = Math.max(0, Math.round(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); };

  // ---------- render ----------
  const ui = {};   // key -> {chips, note, save, status, bar, fill, time, play, seam}
  const root = document.getElementById("groups");
  DATA.forEach((g, gi) => {
    const sec = el("section"); sec.setAttribute("aria-labelledby", "g" + gi);
    const h = el("h2", null, g.group); h.id = "g" + gi;
    sec.append(h, el("p", "lede", g.note));
    const cards = el("div", "cards");
    g.items.forEach(c => cards.appendChild(card(c)));
    sec.appendChild(cards); root.appendChild(sec);
  });

  function card(c) {
    const s = sid(c.key);
    const art = el("article", "card");
    const head = el("div", "head");
    const play = el("button", "play"); play.type = "button"; play.id = "play-" + s; play.innerHTML = PLAY;
    play.setAttribute("aria-pressed", "false");
    play.setAttribute("aria-label", (c.kind === "bed" ? "Zweimal abspielen: " : "Abspielen: ") + c.title);
    play.addEventListener("click", () => toggle(c, "full"));
    const meta = el("div", "meta");
    const num = el("div", "num", "#" + c.n + " · " + c.key);
    const t = el("h3", null, c.title);
    const f = el("div", "small", c.file + " · ");
    const a = el("a", null, c.user + " (Freesound)"); a.href = c.url; a.target = "_blank"; a.rel = "noopener";
    f.appendChild(a);
    meta.append(num, t, f);
    head.append(play, meta);
    art.append(head, el("div", "small", c.cut));
    if (c.hint) art.appendChild(el("div", "hint", c.hint));
    const track = el("div", "track");
    const bar = el("div", "bar" + (c.kind === "bed" ? " seam" : "")); const fill = el("i"); bar.append(fill, el("b"));
    const time = el("span", "time", c.kind === "bed" ? "0:00 / " + fmt(2 * c.dur) : "0:00 / " + fmt(c.dur));
    track.append(bar, time);
    art.appendChild(track);
    const row = el("div", "row");
    let seamBtn = null;
    if (c.kind === "bed") {
      seamBtn = el("button", "btn", "Naht"); seamBtn.type = "button"; seamBtn.id = "seam-" + s;
      seamBtn.setAttribute("aria-label", "Nur die Naht abspielen: " + c.title);
      seamBtn.addEventListener("click", () => toggle(c, "seam"));
      row.appendChild(seamBtn);
    }
    const chips = [["keep", "passt"], ["redo", "neu schneiden"]].map(([v, label]) => {
      const b = el("button", "chip", label); b.type = "button"; b.dataset.v = v; b.id = v + "-" + s;
      b.setAttribute("aria-pressed", "false"); b.disabled = true;
      b.addEventListener("click", () => {
        const cur = local[c.key] || {verdict: "", text: ""};
        local[c.key] = {verdict: cur.verdict === v ? "" : v, text: note.value};
        paintVerdict(c.key); write(c.key);
      });
      row.appendChild(b); return b;
    });
    art.appendChild(row);
    const note = el("textarea"); note.id = "note-" + s; note.rows = 1; note.readOnly = true;
    note.placeholder = "Notiz (z. B. „Rauschen bei 0:12“)";
    note.setAttribute("aria-label", "Notiz zu #" + c.n);
    note.addEventListener("input", () => { local[c.key] = {verdict: (local[c.key] || {}).verdict || "", text: note.value}; dirty[c.key] = true; });
    note.addEventListener("blur", () => write(c.key));
    const save = el("button", "btn", "Speichern"); save.type = "button"; save.id = "save-" + s; save.disabled = true;
    save.addEventListener("click", () => write(c.key));
    const status = el("span", "status"); status.setAttribute("role", "status");
    const srow = el("div", "row"); srow.append(save, status);
    art.append(note, srow);
    ui[c.key] = {chips, note, save, status, bar, fill, time, play, seam: seamBtn, c};
    return art;
  }

  // ---------- playback (Web Audio: the loop restarts sample-exact, as in the game) ----------
  let ctx = null, cur = null;
  const buffers = {};
  function bytes(b64) { const s = atob(b64); const u = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i); return u.buffer; }
  function buffer(key) {
    if (!buffers[key]) buffers[key] = new Promise((res, rej) => ctx.decodeAudioData(bytes(AUDIO[key]), res, rej));
    return buffers[key];
  }
  function stop() {
    if (!cur) return;
    const u = ui[cur.key];
    try { cur.src.onended = null; cur.src.stop(); } catch (e) {}
    u.play.setAttribute("aria-pressed", "false"); u.play.innerHTML = PLAY;
    if (u.seam) u.seam.setAttribute("aria-pressed", "false");
    u.fill.style.width = "0";
    u.time.textContent = "0:00 / " + fmt(u.c.kind === "bed" ? 2 * u.c.dur : u.c.dur);
    cur = null;
  }
  async function toggle(c, mode) {
    const same = cur && cur.key === c.key && cur.mode === mode;
    stop();
    if (same) return;
    const u = ui[c.key];
    try {
      if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === "suspended") await ctx.resume();
      const buf = await buffer(c.key);
      const src = ctx.createBufferSource(); src.buffer = buf; src.connect(ctx.destination);
      const d = buf.duration;
      let offset = 0, total = d;
      if (c.kind === "bed") {
        src.loop = true;
        if (mode === "seam") { offset = d - SEAM_PAD; total = 2 * SEAM_PAD; } else total = 2 * d;
      }
      const t0 = ctx.currentTime + 0.05;
      src.start(t0, offset);
      src.stop(t0 + total);
      cur = {key: c.key, mode, src, t0, total};
      const me = cur;
      src.onended = () => { if (cur === me) stop(); };
      if (mode === "seam") u.seam.setAttribute("aria-pressed", "true");
      else { u.play.setAttribute("aria-pressed", "true"); u.play.innerHTML = STOP; }
      requestAnimationFrame(tick);
    } catch (e) {
      setStatus(u.status, "Wiedergabe nicht möglich: dieser Browser dekodiert kein Ogg Vorbis (Firefox oder Chrome nutzen).", "err");
    }
  }
  function tick() {
    if (!cur) return;
    const u = ui[cur.key];
    const pos = Math.min(cur.total, Math.max(0, ctx.currentTime - cur.t0));
    u.fill.style.width = (100 * pos / cur.total) + "%";
    u.time.textContent = fmt(pos) + " / " + fmt(cur.total);
    requestAnimationFrame(tick);
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
        stored[key] = {verdict: v.verdict === "keep" || v.verdict === "redo" ? v.verdict : "", text: typeof v.text === "string" ? v.text : ""};
      });
      Object.keys(stored).forEach(k => { if (!seen[k]) delete stored[k]; });
      Object.keys(ui).forEach(k => { if (!dirty[k] && !writing[k]) local[k] = Object.assign({verdict: "", text: ""}, stored[k]); });
      paintAll();
      const n = Object.values(stored).filter(s => s.verdict).length;
      setStatus(header, "Speicher verbunden · " + n + " von " + Object.keys(ui).length + " bewertet", "ok");
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
    groups = candidates()
    items = [c for g in groups for c in g["items"]]
    beds = sum(1 for c in items if c["kind"] == "bed")
    audio = {c["key"]: base64.b64encode((HERE / "out" / c["file"]).read_bytes()).decode() for c in items}
    js_json = lambda o: json.dumps(o, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    page = "\n".join([
        "<title>Klangschnitte Runde 52</title>",
        '<link rel="preconnect" href="https://fonts.googleapis.com">',
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700&family=Source+Sans+3:wght@400;600&family=JetBrains+Mono:wght@400;500;600&display=swap">',
        "<style>" + STYLE + "</style>",
        BODY.replace("%COUNTS%", html.escape("%d Betten · %d Rufe" % (beds, len(items) - beds))),
        '<script type="application/json" id="cand-data">' + js_json(groups) + "</script>",
        '<script type="application/json" id="audio-data">' + js_json(audio) + "</script>",
        "<script>" + SCRIPT + "</script>",
        "",
    ])
    PAGE.mkdir(exist_ok=True)
    (PAGE / "index.html").write_text(page)
    (PAGE / "local.html").write_text('<!doctype html>\n<html lang="de">\n<head>\n<meta charset="utf-8">\n'
                                     '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
                                     "</head>\n<body>\n" + page + "</body>\n</html>\n")
    print("page/index.html %.2f MB, %d candidates" % ((PAGE / "index.html").stat().st_size / 1e6, len(items)))


if __name__ == "__main__":
    main()
