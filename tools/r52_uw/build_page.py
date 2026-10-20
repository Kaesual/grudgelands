#!/usr/bin/env python3
"""0.52.1 lane UW: build the listening page for the underwater bed candidates.

python3 -I tools/r52_uw/build_page.py   (after cut.py build; standard library only)

Writes page/index.html: page content only (title, style, markup, script; the
publisher wraps it), every candidate .ogg from out/ inlined as base64, so the
page needs no files beside it. Also writes page/local.html, the same page
wrapped in a document skeleton for opening from file:// (gitignored).

Ratings follow the Round 52 storage contract with this page's verdicts:
collection `notes`, document id = the candidate's key (the file stem, e.g.
uw_3_kinoton; characters outside [A-Za-z0-9_.:@+-] would be written as ~XX hex,
none occur), fields {key, verdict, text, updatedAt}, verdict "pick" | "drop" | "".
The page declares the `db` capability when published.
"""

import base64
import html
import json
import runpy
from pathlib import Path

HERE = Path(__file__).resolve().parent
CUT = runpy.run_path(str(HERE / "cut.py"))
CANDS, info_row = CUT["CANDS"], CUT["info_row"]
WINDOWS = json.loads((HERE / "windows.json").read_text())
PAGE = HERE / "page"
MUFFLE_HZ = 700   # corner of the optional low-pass preview ("gedämpft"); the files stay unfiltered

# Hints from the measurement (cut.py scan, momentary loudness every 0.1 s), German; times are loop time.
HINTS = {
    "uw_1_fission9": "Schon auf der Hörseite von Runde 34 (B13.1), damals nicht gewählt. Einzelne helle Wellen- und Klickgeräusche "
                     "bis 12 dB über dem übrigen hellen Anteil (0:14, 0:18, 0:20), bei 0:19–0:20 das lauteste Anschwellen (+5 dB). "
                     "Spitzen leicht begrenzt (−1 dBFS).",
    "uw_2_dcsfx": "Gleichmäßiges tiefes Blubbern; kleine Anschwellungen bis +4 dB (0:13, 0:15, 0:28). Spitzen leicht begrenzt (−1 dBFS).",
    "uw_3_kinoton": "Das ruhigste der langen Betten (Pegel ±3 dB, kein Ereignis über +3 dB); kurz vor der Naht (0:28–0:29) etwas mehr helles Rauschen.",
    "uw_4_verberne": "Pegel sehr gleichmäßig; zwei Stellen mit hellerem Zischen oder Blasen (0:09 und 0:17–0:20).",
    "uw_5_merrick": "Schwankt am stärksten (5 dB zwischen leisen und lauten Stellen); Anschwellen bei 0:04 und 0:11.",
    "uw_6_jhumbucker": "Das tiefste und gleichmäßigste Grollen der Auswahl, kein Einzelereignis gemessen. Spitzen leicht begrenzt (−1 dBFS).",
    "uw_7_cubicapocalypse": "Kurze Quelle (25 s): Loop 22,5 s. Das Ende liegt 2 dB über dem Anfang; die Überblendung gleicht es aus, "
                            "an der Naht kann trotzdem ein leichtes Abschwellen hörbar sein.",
    "uw_8_osiruswaltz": "Kurze Quelle (16 s): Loop nur 13,4 s, wiederholt sich also mehr als doppelt so oft. "
                        "Hellstes Rauschen der Auswahl, eher Strömung oder Regen von unten als Stille.",
}


def de(x, nd=1):
    return ("%.*f" % (nd, x)).replace(".", ",").replace("-", "−")


def candidates():
    out = []
    for key, fid, title, note in CANDS:
        if key not in WINDOWS:
            continue
        w = WINDOWS[key]
        _, user, page = info_row(fid)
        a, b = w["window"]
        loop = de(w["loop"], 0) if w["loop"] == int(w["loop"]) else de(w["loop"])
        cut = "Ausschnitt %s–%s s von %s s · Loop %s s · %s LUFS · Spitze %s dBFS" % (
            de(a), de(b), de(w["source_seconds"], 0), loop, de(w["lufs"]), de(w["peak_db"]))
        out.append({"n": int(key.split("_")[1]), "key": key, "title": title, "note": note, "file": key + ".ogg",
                    "user": user, "url": page, "cut": cut, "hint": HINTS.get(key, ""), "dur": w["seconds"]})
    return out


STYLE = r"""
:root {
  --bg: #f1f4f5; --surface: #fafcfc; --line: #d3dcdf; --fg: #1f262a; --muted: #56656b;
  --accent: #2f5f7a; --accent-soft: #dce9f0; --seam: #a0702a; --good: #2f7a3c; --bad: #a33b2f;
  --display: "Bricolage Grotesque", "Segoe UI", system-ui, sans-serif;
  --body: "Source Sans 3", "Segoe UI", system-ui, sans-serif;
  --mono: "JetBrains Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #12181b; --surface: #182024; --line: #2e3a40; --fg: #e0e8eb; --muted: #93a3a9;
    --accent: #7fb6d2; --accent-soft: #1e2d35; --seam: #dba85c; --good: #7cc98a; --bad: #ec8a7c; color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #12181b; --surface: #182024; --line: #2e3a40; --fg: #e0e8eb; --muted: #93a3a9;
  --accent: #7fb6d2; --accent-soft: #1e2d35; --seam: #dba85c; --good: #7cc98a; --bad: #ec8a7c; color-scheme: dark;
}
* { box-sizing: border-box; }
body { background: var(--bg); color: var(--fg); font: 16px/1.5 var(--body); margin: 0; }
.wrap { max-width: 1080px; margin: 0 auto; padding: 28px 16px 64px; display: grid; gap: 36px; }
.wrap > * { min-width: 0; }
section { min-width: 0; }
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
.chip[aria-pressed="true"][data-v="pick"] { border-color: var(--good); color: var(--good); background: color-mix(in srgb, var(--good) 12%, transparent); }
.chip[aria-pressed="true"][data-v="drop"] { border-color: var(--bad); color: var(--bad); background: color-mix(in srgb, var(--bad) 12%, transparent); }
.btn { font: 600 0.8rem var(--body); border-radius: 8px; padding: 4px 12px; cursor: pointer; border: 1.5px solid var(--accent); background: transparent; color: var(--accent); }
textarea { width: 100%; font: 0.88rem var(--body); color: var(--fg); background: var(--bg); border: 1px solid var(--line); border-radius: 6px; padding: 6px 8px; resize: vertical; min-height: 36px; }
textarea[readonly] { opacity: 0.75; }
.ro { font-size: 0.86rem; color: var(--muted); }
.note { font-size: 0.86rem; color: var(--muted); }
.toggle { display: inline-flex; align-items: center; gap: 8px; font-size: 0.9rem; cursor: pointer; }
.toggle input { width: 18px; height: 18px; accent-color: var(--accent); margin: 0; }
input:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
"""

BODY = r"""
<div class="wrap">
  <header>
    <div class="eyebrow">0.52.1 · Lane UW · Unterwasser-Kulisse zur Auswahl · 2026-10-20</div>
    <h1>Unterwasser-Klang</h1>
    <p class="lede"><b>Der einzige Klang beim Tauchen:</b> wer taucht, hört keine Zonen-Kulisse mehr, nur dieses eine Bett, oft minutenlang. Bitte mit Kopfhörern oder guten Lautsprechern hören.</p>
    <p class="lede">Jeder Loop spielt <b>zweimal hintereinander</b>: die Marke in der Mitte des Balkens ist die Naht, an der er von vorn beginnt. „Naht“ spielt nur die 4 s davor und danach. Alle auf −20 LUFS gepegelt wie die Biom-Betten, also untereinander vergleichbar. Wähle <b>nehmen</b> für deinen Favoriten (gern zwei, um sie im Spiel zu vergleichen), <b>verwerfen</b> für alles, was nicht passt, gern mit Notiz.</p>
    <label class="toggle" for="muffle"><input type="checkbox" id="muffle"> Vorschau gedämpft (Tiefpass %MUFFLE% Hz, nur hier zum Probehören; die Datei bleibt ungefiltert)</label>
    <div class="facts"><span>%COUNTS%</span><span>alle CC0 (Freesound)</span><span>Mono-Ogg wie im Spiel</span><span>Loop-Naht: 2 s Überblendung</span><span>60 Hz Hochpass</span></div>
    <div class="status" id="dbstatus" role="status">Speicher wird verbunden …</div>
  </header>
  <section aria-label="Kandidaten"><div class="cards" id="cards"></div></section>
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
  const cardsRoot = document.getElementById("cards");
  DATA.forEach(c => cardsRoot.appendChild(card(c)));

  function card(c) {
    const s = sid(c.key);
    const art = el("article", "card");
    const head = el("div", "head");
    const play = el("button", "play"); play.type = "button"; play.id = "play-" + s; play.innerHTML = PLAY;
    play.setAttribute("aria-pressed", "false");
    play.setAttribute("aria-label", "Zweimal abspielen: " + c.title);
    play.addEventListener("click", () => toggle(c, "full"));
    const meta = el("div", "meta");
    const num = el("div", "num", "#" + c.n + " · " + c.key);
    const t = el("h3", null, c.title);
    const f = el("div", "small", c.file + " · ");
    const a = el("a", null, c.user + " (Freesound, CC0)"); a.href = c.url; a.target = "_blank"; a.rel = "noopener";
    f.appendChild(a);
    meta.append(num, t, f);
    head.append(play, meta);
    art.append(head, el("div", "note", c.note), el("div", "small", c.cut));
    if (c.hint) art.appendChild(el("div", "hint", c.hint));
    const track = el("div", "track");
    const bar = el("div", "bar seam"); const fill = el("i"); bar.append(fill, el("b"));
    const time = el("span", "time", "0:00 / " + fmt(2 * c.dur));
    track.append(bar, time);
    art.appendChild(track);
    const row = el("div", "row");
    const seamBtn = el("button", "btn", "Naht"); seamBtn.type = "button"; seamBtn.id = "seam-" + s;
    seamBtn.setAttribute("aria-label", "Nur die Naht abspielen: " + c.title);
    seamBtn.setAttribute("aria-pressed", "false");
    seamBtn.addEventListener("click", () => toggle(c, "seam"));
    row.appendChild(seamBtn);
    const chips = [["pick", "nehmen"], ["drop", "verwerfen"]].map(([v, label]) => {
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
    note.placeholder = "Notiz (z. B. „Klicken bei 0:12“, „zu hell“, „leiser“)";
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
    u.time.textContent = "0:00 / " + fmt(2 * u.c.dur);
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
      const src = ctx.createBufferSource(); src.buffer = buf; src.connect(filter());
      const d = buf.duration;
      src.loop = true;
      let offset = 0, total = 2 * d;
      if (mode === "seam") { offset = d - SEAM_PAD; total = 2 * SEAM_PAD; }
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
  // Optional "muffled" preview: one shared low-pass in front of the output, open when the box is off.
  const muffleBox = document.getElementById("muffle");
  let lp = null;
  const MUFFLE_HZ = %MUFFLE%;
  function setMuffle() {
    if (lp) lp.frequency.setTargetAtTime(muffleBox.checked ? MUFFLE_HZ : ctx.sampleRate / 2, ctx.currentTime, 0.05);
  }
  function filter() {
    if (!lp) {
      lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.Q.value = 0.7;
      lp.frequency.value = muffleBox.checked ? MUFFLE_HZ : ctx.sampleRate / 2;
      lp.connect(ctx.destination);
    }
    return lp;
  }
  muffleBox.addEventListener("change", setMuffle);

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
        stored[key] = {verdict: v.verdict === "pick" || v.verdict === "drop" ? v.verdict : "", text: typeof v.text === "string" ? v.text : ""};
      });
      Object.keys(stored).forEach(k => { if (!seen[k]) delete stored[k]; });
      Object.keys(ui).forEach(k => { if (!dirty[k] && !writing[k]) local[k] = Object.assign({verdict: "", text: ""}, stored[k]); });
      paintAll();
      const n = Object.values(stored).filter(s => s.verdict).length;
      const picked = Object.values(stored).filter(s => s.verdict === "pick").length;
      setStatus(header, "Speicher verbunden · " + n + " von " + Object.keys(ui).length + " bewertet · " + picked + " genommen", "ok");
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
    items = candidates()
    audio = {c["key"]: base64.b64encode((HERE / "out" / c["file"]).read_bytes()).decode() for c in items}
    js_json = lambda o: json.dumps(o, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    page = "\n".join([
        "<title>Unterwasser-Klang</title>",
        '<link rel="preconnect" href="https://fonts.googleapis.com">',
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700&family=Source+Sans+3:wght@400;600&family=JetBrains+Mono:wght@400;500;600&display=swap">',
        "<style>" + STYLE + "</style>",
        BODY.replace("%COUNTS%", html.escape("%d Kandidaten" % len(items))).replace("%MUFFLE%", str(MUFFLE_HZ)),
        '<script type="application/json" id="cand-data">' + js_json(items) + "</script>",
        '<script type="application/json" id="audio-data">' + js_json(audio) + "</script>",
        "<script>" + SCRIPT.replace("%MUFFLE%", str(MUFFLE_HZ)) + "</script>",
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
