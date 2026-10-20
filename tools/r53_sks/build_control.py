#!/usr/bin/env python3
"""Round 53 prep lane SKS, round 2: the control page for the final assignments.

python3 -I tools/r53_sks/build_control.py   (after cut.py and assign.py; standard library only)

Writes page-control/index.html: page content only (the publisher wraps it),
the assigned sounds and the kept annotations inlined as base64 Ogg, so the
page needs no files beside it; page-control/local.html is the same page in a
document skeleton for file:// (gitignored).

Ratings follow the Round 52 storage contract: collection `notes`, fields
{key, verdict, text, updatedAt}, verdict "keep" | "redo" | "". Document ids:
`row:<row key>` for an assignment, `q:<question key>` for an open question;
characters outside [A-Za-z0-9_.:@+-] would be written as ~XX hex, none occur.
"""

import base64
import html
import json
import runpy
from pathlib import Path

HERE = Path(__file__).resolve().parent
BP = runpy.run_path(str(HERE / "build_page.py"))
STYLE, SCRIPT_RATINGS_SRC = BP["STYLE"], BP["SCRIPT"]
CUTS = json.loads((HERE / "cuts.json").read_text())
ASSIGN = json.loads((HERE / "assignments.json").read_text())
ASSIGN_PY = runpy.run_path(str(HERE / "assign.py"))
ROWS, HINTS = ASSIGN_PY["ROWS"], ASSIGN_PY["HINTS"]
RATINGS = ASSIGN_PY["RATINGS"]
REJECTED = json.loads((HERE / "rejected.json").read_text())
PAGE = HERE / "page-control"
TREES = BP["TREES"]
KIND = {"cast": "Wirken", "impact": "Einschlag", "projectile launch": "Abschuss", "swing (weapon)": "Schwung"}
BASIS = {"pick": "Favorit", "comment": "Kommentar", "default": "Standard"}
VERD = {"pick": "Favorit", "drop": "raus", "": "ohne Wahl"}


def de(x, nd=1):
    return ("%.*f" % (nd, x)).replace(".", ",").replace("-", "−")


def audio_key(a):
    """The out/ file that plays for an assignment (a shipped cue: the row's copied candidate 1)."""
    if a["choice"] == "silent":
        return None
    if a["choice"].startswith("shipped:"):
        return next(k for k, v in CUTS.items() if v["row"] == a["row"] and v.get("copied"))
    return a["choice"]


def label(a):
    if a["choice"] == "silent":
        return "stumm"
    if a["choice"].startswith("shipped:"):
        return "schon im Spiel: " + a["choice"].split(":", 1)[1]
    return a["title"]


def data():
    rows = []
    for a in ASSIGN["assignments"]:
        k = audio_key(a)
        c = CUTS.get(k, {}) if k else {}
        facts = ""
        if c:
            facts = "%s s · Spitze %s dBFS · RMS %s dBFS" % (de(c["dur"], 2), de(c["peak_db"]), de(c["rms_db"]))
        moved = a["basis"] == "comment" and not a["choice"].startswith(a["row"] + "_")
        note = ""
        if a["derived"]:
            note = "Neu geschnitten (gekürzt, Ausschnitt %s–%s s der Quelle), wie die Notiz es wünscht." % (
                de(c["cut_start"], 2), de(c["cut_start"] + c["cut_len"], 2))
        elif moved:
            note = "Stammt von einer anderen Zeile (%s), dort als Vorschlag gehört." % a["choice"]
        rows.append({"key": "row:" + a["row"], "row": a["row"], "name": a["name"], "kind": KIND[a["cue"]],
                     "cls": a["class"], "tree": a["tree"], "el": TREES[a["tree"]], "label": label(a),
                     "audio": k, "file": a["choice"], "basis": BASIS[a["basis"]], "quote": a["quote"],
                     "author": a["author"], "license": a["license"] if a["license"] != "as shipped" else "wie ausgeliefert",
                     "page": a["page"], "facts": facts, "note": note})
    qs = [{"key": "q:" + q["key"], "question": q["question"], "rec": q["recommendation"],
           "notes": [{"key": n, "verdict": VERD[v["verdict"]], "text": v["text"],
                      "audio": n if n in CUTS else None} for n, v in q["notes"].items()]} for q in ASSIGN["questions"]]
    anns = []
    for key, r in sorted(RATINGS.items()):
        if not r["text"]:
            continue
        anns.append({"key": key, "verdict": VERD[r["verdict"]], "text": r["text"], "hint": HINTS.get(key, ""),
                     "audio": key if key in CUTS else None})
    return rows, qs, anns


EXTRA_STYLE = r"""
.q { background: var(--surface); border: 1px solid var(--line); border-left: 3px solid var(--accent); border-radius: 10px; padding: 14px 16px; display: grid; gap: 8px; }
.quote { font-size: 0.9rem; border-left: 2px solid var(--line); padding-left: 8px; }
.rec { font-size: 0.92rem; }
.rec b { color: var(--accent); }
.basis { font: 600 0.72rem var(--mono); text-transform: uppercase; letter-spacing: 0.05em; color: var(--accent); }
.chip[aria-pressed="true"][data-v="keep"] { border-color: var(--good); color: var(--good); background: color-mix(in srgb, var(--good) 12%, transparent); }
.chip[aria-pressed="true"][data-v="redo"] { border-color: var(--bad); color: var(--bad); background: color-mix(in srgb, var(--bad) 12%, transparent); }
.anns { display: grid; gap: 8px; }
.ann { display: flex; gap: 10px; align-items: flex-start; font-size: 0.92rem; }
.ann .play { width: 30px; height: 30px; }
.ann .meta { gap: 0; }
"""

BODY = r"""
<div class="wrap">
  <header>
    <div class="eyebrow">Runde 53 · Vorbereitung · Lane SKS · Kontrolle · 2026-10-20</div>
    <h1>Skill-Sound-Kontrolle</h1>
    <p class="lede">So habe ich deine Bewertungen gelesen: je Zeile der Ton, der ins Spiel käme, mit dem Satz, der ihn begründet. Ein Favorit gilt für die Zeile, auf der er markiert ist; eine Notiz, die einen Ton für einen anderen Skill will, verlegt ihn dorthin. Was du „raus“ markiert hast, ist gelöscht.</p>
    <p class="lede">Bitte jede Zuweisung bestätigen (<b>passt</b>) oder ablehnen (<b>ändern</b>, gern mit Notiz). Bei den offenen Fragen heißt <b>passt</b>: wie empfohlen.</p>
    <div class="facts"><span>%COUNTS%</span></div>
    <div class="status" id="dbstatus" role="status">Speicher wird verbunden …</div>
  </header>
  <section aria-labelledby="hq"><h2 id="hq">Offene Fragen</h2><div id="questions" class="rows"></div></section>
  <section aria-labelledby="ha"><h2 id="ha">Zuweisungen</h2><div id="classes" class="rows"></div></section>
  <section aria-labelledby="hn"><h2 id="hn">Für später aufbewahrt</h2>
    <p class="lede">Deine Notizen zu Tönen, wörtlich (auch zu solchen, die schon zugewiesen sind). Die Dateien bleiben liegen; „raus“-Töne sind nicht dabei.</p>
    <div id="anns" class="anns"></div></section>
  <section aria-labelledby="hr"><h2 id="hr">Entfernt</h2><p id="removed" class="lede"></p></section>
</div>
"""

SCRIPT = r"""
(() => {
  const D = JSON.parse(document.getElementById("ctl-data").textContent);
  const AUDIO = JSON.parse(document.getElementById("audio-data").textContent);
  const PLAY = '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M2 1l7 4-7 4z"/></svg>';
  const STOP = '<svg viewBox="0 0 10 10" aria-hidden="true"><rect x="2" y="2" width="6" height="6"/></svg>';
  const sid = key => key.replace(/[^A-Za-z0-9_-]/g, "-");
  const docId = key => key.replace(/[^A-Za-z0-9_.:@+-]/g, c => "~" + c.charCodeAt(0).toString(16).padStart(2, "0"));
  const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
  const link = (text, href) => { const a = el("a", null, text); a.href = href; a.target = "_blank"; a.rel = "noopener"; return a; };

  // ---------- playback ----------
  let ctx = null, cur = null;
  const buffers = {}, players = {};
  function bytes(b64) { const s = atob(b64); const u = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i); return u.buffer; }
  function stop() {
    if (!cur) return;
    try { cur.src.onended = null; cur.src.stop(); } catch (e) {}
    (players[cur.id] || {}).btn && (players[cur.id].btn.setAttribute("aria-pressed", "false"), players[cur.id].btn.innerHTML = PLAY);
    cur = null;
  }
  async function play(id, key, statusNode) {
    const same = cur && cur.id === id; stop(); if (same) return;
    try {
      if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === "suspended") await ctx.resume();
      if (!buffers[key]) buffers[key] = new Promise((res, rej) => ctx.decodeAudioData(bytes(AUDIO[key]), res, rej));
      const buf = await buffers[key];
      const src = ctx.createBufferSource(); src.buffer = buf; src.connect(ctx.destination);
      const me = {id, src}; cur = me;
      src.onended = () => { if (cur === me) stop(); };
      players[id].btn.setAttribute("aria-pressed", "true"); players[id].btn.innerHTML = STOP;
      src.start();
    } catch (e) {
      if (statusNode) { statusNode.textContent = "Wiedergabe nicht möglich: dieser Browser dekodiert kein Ogg Vorbis (Firefox oder Chrome nutzen)."; statusNode.className = "status err"; }
      stop();
    }
  }
  function playBtn(id, key, label, statusNode) {
    const b = el("button", "play"); b.type = "button"; b.id = "play-" + sid(id); b.innerHTML = PLAY;
    b.setAttribute("aria-pressed", "false"); b.setAttribute("aria-label", "Abspielen: " + label);
    b.addEventListener("click", () => play(id, key, statusNode()));
    players[id] = {btn: b};
    return b;
  }

  // ---------- ratings controls ----------
  const ui = {};
  function rating(key, labels) {
    const s = sid(key);
    const wrap = el("div");
    const ctl = el("div", "ctl");
    const chips = [["keep", labels[0]], ["redo", labels[1]]].map(([v, lab]) => {
      const b = el("button", "chip", lab); b.type = "button"; b.dataset.v = v; b.id = v + "-" + s;
      b.setAttribute("aria-pressed", "false"); b.disabled = true;
      b.addEventListener("click", () => {
        const c = local[key] || {verdict: "", text: ""};
        local[key] = {verdict: c.verdict === v ? "" : v, text: note.value};
        paintVerdict(key); write(key);
      });
      ctl.appendChild(b); return b;
    });
    const save = el("button", "btn", "Speichern"); save.type = "button"; save.id = "save-" + s; save.disabled = true;
    save.addEventListener("click", () => write(key));
    const status = el("span", "status"); status.setAttribute("role", "status");
    ctl.append(save, status);
    const note = el("textarea"); note.id = "note-" + s; note.rows = 1; note.readOnly = true;
    note.placeholder = "Notiz"; note.setAttribute("aria-label", "Notiz zu " + key);
    note.addEventListener("input", () => { local[key] = {verdict: (local[key] || {}).verdict || "", text: note.value}; dirty[key] = true; });
    note.addEventListener("blur", () => write(key));
    wrap.append(ctl, note);
    ui[key] = {chips, note, save, status};
    return wrap;
  }

  // ---------- render ----------
  const qroot = document.getElementById("questions");
  D.questions.forEach((q, i) => {
    const box = el("article", "q");
    box.appendChild(el("div", "num", "Frage " + (i + 1) + " · " + q.key));
    box.appendChild(el("p", null, q.question));
    q.notes.forEach(n => {
      const line = el("div", "ann");
      if (n.audio) line.appendChild(playBtn(q.key + "/" + n.key, n.audio, n.key, () => ui[q.key].status));
      const m = el("div", "meta");
      m.append(el("div", "small", n.key + " · " + n.verdict), el("div", "quote", n.text ? "„" + n.text + "“" : "(keine Notiz)"));
      line.appendChild(m); box.appendChild(line);
    });
    const rec = el("p", "rec"); rec.append(el("b", null, "Empfehlung: "), document.createTextNode(q.rec));
    box.appendChild(rec);
    box.appendChild(rating(q.key, ["passt (wie empfohlen)", "nein, anders"]));
    qroot.appendChild(box);
  });

  const root = document.getElementById("classes");
  let lastCls = null, lastTree = null, list = null;
  D.rows.forEach(r => {
    if (r.cls !== lastCls) { root.appendChild(el("h3", null, r.cls)); lastCls = r.cls; lastTree = null; }
    if (r.tree !== lastTree) { root.appendChild(el("div", "eyebrow", r.tree + " · " + r.el)); lastTree = r.tree; }
    const art = el("article", "row"); art.id = "row-" + sid(r.row);
    const head = el("div", "rowhead");
    head.append(el("h4", null, r.name + (r.kind === "Wirken" ? "" : " · " + r.kind)), el("span", "badge", r.cls + " · " + r.tree + " · " + r.kind));
    art.appendChild(head);
    const c = el("div", "chead");
    if (r.audio) c.appendChild(playBtn(r.key, r.audio, r.name, () => ui[r.key].status));
    const m = el("div", "meta");
    m.appendChild(el("div", "num", r.file));
    m.appendChild(el("div", "label" + (r.file.startsWith("shipped:") ? " ship" : ""), r.label));
    if (r.author) { const cr = el("div", "small"); cr.append(r.page ? link(r.author, r.page) : document.createTextNode(r.author), document.createTextNode(" · " + r.license)); m.appendChild(cr); }
    else m.appendChild(el("div", "small", r.license));
    if (r.facts) m.appendChild(el("div", "small", r.facts));
    c.appendChild(m); art.appendChild(c);
    art.appendChild(el("div", "basis", r.basis));
    art.appendChild(el("p", "quote", r.quote));
    if (r.note) art.appendChild(el("p", "why", r.note));
    art.appendChild(rating(r.key, ["passt", "ändern"]));
    root.appendChild(art);
  });

  const aroot = document.getElementById("anns");
  D.anns.forEach(a => {
    const line = el("div", "ann");
    if (a.audio) line.appendChild(playBtn("ann/" + a.key, a.audio, a.key, () => document.getElementById("dbstatus")));
    const m = el("div", "meta");
    m.append(el("div", "small", a.key + " · " + a.verdict + (a.hint ? " · später: " + a.hint : "")), el("div", "quote", "„" + a.text + "“"));
    line.appendChild(m); aroot.appendChild(line);
  });
  document.getElementById("removed").textContent = D.removed;

%RATINGS%
})();
"""


def ratings_js():
    """The storage part of the first page's script (same contract), with verdicts keep/redo."""
    s = SCRIPT_RATINGS_SRC
    a = s.index("  // ---------- ratings (db capability")
    b = s.rindex("})();")
    js = s[a:b]
    js = js.replace('v.verdict === "pick" || v.verdict === "drop"', 'v.verdict === "keep" || v.verdict === "redo"')
    js = js.replace('''      const picked = new Set(Object.keys(stored).filter(k => stored[k].verdict === "pick").map(k => ui[k].row));
      setStatus(header, "Speicher verbunden · Favorit in " + picked.size + " von " + Object.keys(rowsUi).length + " Zeilen", "ok");''',
                    '''      const n = Object.values(stored).filter(s => s.verdict).length;
      setStatus(header, "Speicher verbunden · " + n + " von " + Object.keys(ui).length + " beantwortet", "ok");''')
    assert '"pick"' not in js and "rowsUi" not in js
    return js


def main():
    rows, qs, anns = data()
    keys = {r["audio"] for r in rows if r["audio"]} | {n["audio"] for q in qs for n in q["notes"] if n["audio"]} | \
        {a["audio"] for a in anns if a["audio"]}
    audio = {k: base64.b64encode((HERE / "out" / (k + ".ogg")).read_bytes()).decode() for k in sorted(keys)}
    removed = "%d Töne, die du „raus“ markiert hast, sind gelöscht und werden nie wieder vorgeschlagen (rejected.md): %s." % (
        len(REJECTED), ", ".join("%s (%s)" % (r["title"], r["key"]) for r in REJECTED))
    counts = "%d Zuweisungen · %d offene Fragen · %d Notizen aufbewahrt · %d Töne entfernt" % (
        len(rows), len(qs), len(anns), len(REJECTED))
    js_json = lambda o: json.dumps(o, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    page = "\n".join([
        "<title>Skill-Sound-Kontrolle</title>",
        '<link rel="preconnect" href="https://fonts.googleapis.com">',
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700&family=Source+Sans+3:wght@400;600&family=JetBrains+Mono:wght@400;500;600&display=swap">',
        "<style>" + STYLE + EXTRA_STYLE + "</style>",
        BODY.replace("%COUNTS%", html.escape(counts)),
        '<script type="application/json" id="ctl-data">' + js_json({"rows": rows, "questions": qs, "anns": anns,
                                                                    "removed": removed}) + "</script>",
        '<script type="application/json" id="audio-data">' + js_json(audio) + "</script>",
        "<script>" + SCRIPT.replace("%RATINGS%", ratings_js()) + "</script>",
        "",
    ])
    PAGE.mkdir(exist_ok=True)
    (PAGE / "index.html").write_text(page)
    (PAGE / "local.html").write_text('<!doctype html>\n<html lang="de">\n<head>\n<meta charset="utf-8">\n'
                                     '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
                                     "</head>\n<body>\n" + page + "</body>\n</html>\n")
    print("page-control/index.html %.2f MB, %d rows, %d questions, %d annotations, %d sounds" % (
        (PAGE / "index.html").stat().st_size / 1e6, len(rows), len(qs), len(anns), len(audio)))


if __name__ == "__main__":
    main()
