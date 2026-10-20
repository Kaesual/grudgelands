#!/usr/bin/env python3
"""0.52.1 lane UW: cut the underwater bed candidates.

python3 -I tools/r52_uw/cut.py [scan|build] [--only KEY ...] [--top N]

Python 3 standard library plus ffmpeg/ffprobe (libvorbis). The sources are the
Freesound HQ previews in ~/projects/grudgelands-orchestration/sound-r52u/dl
(fetched by fetch.py; only read). The cut follows the shipped beds and reuses
the Round 52 cut functions of tools/r52_snd/cut.py: mono Ogg Vorbis q1, a 30 s
loop closed by a 2 s equal-power crossfade (shorter sources loop nearly all of
themselves), 60 Hz high-pass, -20 LUFS integrated (peaks over -1 dBFS limited
seam-safe). No low-pass: the files stay as recorded unless the user asks.

Window choice by measurement (EBU R128 momentary loudness every 0.1 s): the
Round 52 score (loudest moment over the window median, anything loud in the two
crossfade zones, level jump at the loop point) plus two terms for a bed that
plays for minutes under water: the spread of the level (p90 - p10, a pumping
bed) and the loudest moment of the band above 2 kHz over its median (clicks,
handling noise, single bubbles that the full-band level hides).

Output in this folder: out/uw_<n>_<source>.ogg, windows.json, picks.md,
license-rows.md.
"""

import argparse
import json
import re
import runpy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
SRC = Path.home() / "projects/grudgelands-orchestration/sound-r52u"
SND = runpy.run_path(str(HERE.parent / "r52_snd" / "cut.py"))   # shared Round 52 cut functions
run, duration, momentary, score_window = SND["run"], SND["duration"], SND["momentary"], SND["score_window"]
decode, loop_close, level_bed, encode_true = SND["decode"], SND["loop_close"], SND["level_bed"], SND["encode_true"]
LOOP, XF, HP, SHORT, BED_LUFS = SND["LOOP"], SND["XF"], SND["HP"], SND["SHORT"], SND["BED_LUFS"]
INFO = json.loads((SRC / "info.json").read_text())

SPREAD_W = 0.5   # score weight of the level spread (dB)
HIGH_W = 0.5     # score weight of the loudest high-band moment over its median (dB)

# Candidates: key (file stem), Freesound id, German title, German note from the source page.
CANDS = [
    ("uw_1_fission9", "504641", "Tiefsee-Atmo (gestaltet)",
     "Kein echtes Unterwasser: verlangsamte Dosengeräusche und tiefpassgefilterte Wellen, als Tiefsee gedacht."),
    ("uw_2_dcsfx", "366159", "Unterwasser-Loop aus Tauchaufnahmen",
     "Mehrere Tauchgeräusche geschichtet, als loopbare Unterwasser-Kulisse gedacht."),
    ("uw_3_kinoton", "393819", "Unterwasser-Präsenz: Grollen und Blubbern",
     "Bearbeiteter Ausschnitt einer Flussufer-Aufnahme bei Nacht (Tonhöhe, EQ, Hall)."),
    ("uw_4_verberne", "482167", "Unterwasser-Loop für ein Spiel",
     "Hydrofon-Aufnahmen mit gefiltertem Rauschen geschichtet, für ein Spiel gebaut."),
    ("uw_5_merrick", "567347", "Unterwasser-Atmo",
     "Ohne nähere Angaben zur Herkunft."),
    ("uw_6_jhumbucker", "193822", "Tiefes Unterwasser-Grollen",
     "Tiefes Unterwasser-Geräusch, für eine Filmszene gedacht."),
    ("uw_7_cubicapocalypse", "195509", "Wässriges Grollen (Loop)",
     "Gestaltetes Grollen, als Loop gedacht."),
    ("uw_8_osiruswaltz", "530167", "Rauschen unter einem Wasserfall",
     "Strömung oder Wasserfall von unter Wasser gehört, aus einer Sturzflut-Aufnahme."),
]


def high_band(p):
    """Momentary loudness of the band above 2 kHz: [(t, LUFS)]."""
    err = run(["ffmpeg", "-nostats", "-hide_banner", "-v", "verbose", "-i", str(p), "-af",
               "aformat=channel_layouts=mono,highpass=f=2000,highpass=f=2000,ebur128=framelog=verbose",
               "-f", "null", "-"]).stderr.decode(errors="replace")
    return [(float(m.group(1)), float(m.group(2)))
            for m in re.finditer(r"t:\s*([\d.]+)\s+TARGET:\S+ LUFS\s+M:\s*(-?[\d.]+)", err)]


def src_path(fid):
    p = SRC / "dl" / ("fs_%s.mp3" % fid)
    if not p.is_file() or p.stat().st_size == 0:
        sys.exit("missing source %s" % p)
    return p


def window_extra(frames, hb, s, loop):
    w = s + loop + XF
    lv = sorted(m for t, m in frames if s + 0.4 <= t <= w)
    hv = sorted(m for t, m in hb if s + 0.4 <= t <= w)
    spread = lv[9 * len(lv) // 10] - lv[len(lv) // 10]
    high = hv[-1] - hv[len(hv) // 2]
    return round(spread, 1), round(high, 1)


def plan(cand, top=1):
    key, fid = cand[0], cand[1]
    p = src_path(fid)
    dur = duration(p)
    frames, hb = momentary(p), high_band(p)
    head_margin, tail_margin = 0.4, 0.3
    loop = LOOP if dur >= SHORT else int((dur - head_margin - tail_margin - XF) * 10) / 10
    cands, s = [], head_margin
    while s + loop + XF <= dur - tail_margin + 1e-6:
        r = score_window(frames, s, loop, (0.0, dur))   # no "heard" excerpt: every window is free
        if r:
            spread, high = window_extra(frames, hb, s, loop)
            r.update(spread=spread, high=high, score=round(r["score"] + SPREAD_W * spread + HIGH_W * high, 2))
            del r["dist"]
            cands.append(r)
        s += 0.5 if loop == LOOP else 0.1
    cands.sort(key=lambda r: r["score"])
    return {"key": key, "src": str(p), "duration": round(dur, 2), "loop": loop, "cands": cands[:top]}


def build(cand):
    pl = plan(cand)
    best = pl["cands"][0]
    p, loop, s = Path(pl["src"]), pl["loop"], best["start"]
    x, gain, raw_peak, limited = level_bed(loop_close(decode(p, s, loop + XF), loop))
    dst = OUT / ("%s.ogg" % cand[0])
    m = encode_true(x, dst, 1, "lufs", BED_LUFS)
    return {"key": cand[0], "fs": cand[1], "source_seconds": pl["duration"], "window": [s, round(s + loop + XF, 1)],
            "loop": loop, "gain_db": round(gain, 1), "unlimited_peak_db": round(raw_peak, 1), "limited": limited,
            "scan": best, **m}


def info_row(fid):
    i = INFO[fid]
    for k in ("license", "license_recheck"):
        if i.get(k) != "publicdomain/zero/1.0":
            sys.exit("licence check failed for %s: %s" % (fid, i))
    if i.get("genai_tag") or i.get("genai_recheck"):
        sys.exit("GenAI tag on %s" % fid)
    user = i["user"]
    title = re.sub(r"^Freesound - ", "", i["title"])
    title = re.sub(r" by %s$" % re.escape(user), "", title)
    return title, user, i["page"]


def write_docs(results):
    rows, picks = [], []
    lic = "[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)"
    for c in CANDS:
        r = results.get(c[0])
        if not r:
            continue
        title, user, page = info_row(c[1])
        a, b = r["window"]
        mod = ("HQ preview (MP3); excerpt %.1f-%.1f s, looped with a 2 s crossfade (%g s loop), 60 Hz high-pass, "
               "levelled to -20 LUFS%s, mono Ogg" % (a, b, r["loop"], ", peaks limited to -1 dBFS" if r["limited"] else ""))
        rows.append("## #%s `%s`\n\n| File | Title | Author | Source | License | Modifications |\n|---|---|---|---|---|---|\n"
                    "| `sounds/grug_ambience_underwater.ogg` | %s | %s | [%s](%s) | %s | %s |\n"
                    % (c[0].split("_")[1], c[0], title, user, page, page, lic, mod))
        sc = r["scan"]
        picks.append("| %s.ogg | %s (%s) | %.1f-%.1f s of %g s | %g s | %.1f LUFS, peak %.1f dBFS%s | burst %.1f, seam %.1f, "
                     "jump %.1f, spread %.1f, high %.1f dB | |"
                     % (c[0], c[1], user, a, b, r["source_seconds"], r["seconds"], r["lufs"], r["peak_db"],
                        " (limited)" if r["limited"] else "", sc["burst"], sc["seam"], sc["mismatch"], sc["spread"], sc["high"]))
    (HERE / "license-rows.md").write_text(
        "# 0.52.1 UW: licence rows (ready to paste)\n\n"
        "Rows in the format of `mods/CORE/grug_ambience/LICENSE-media.md`, one per candidate; only the picked\n"
        "candidate's row is pasted, as `sounds/grug_ambience_underwater.ogg`. Licence (CC0 1.0), no GenAI tag and\n"
        "author re-verified on the source page twice on 2026-10-20 (search page fetch and a second page read,\n"
        "stored in `sound-r52u/info.json`), written by `cut.py`. One section per candidate.\n\n"
        + "\n".join(rows))
    (HERE / "picks.md").write_text(
        "# 0.52.1 UW: underwater bed candidates\n\n"
        "Written by `cut.py`. Files in `out/`; the window is in seconds of the source preview (excerpt = loop +\n"
        "2 s crossfade). Scan columns (dB, lower is calmer): burst = loudest moment over the window median,\n"
        "seam = loudest moment in the crossfade zones over the median, jump = level difference of the loop's ends,\n"
        "spread = p90 - p10 of the level, high = loudest moment above 2 kHz over its median. The winner ships as\n"
        "`grug_ambience_underwater.ogg`. The coordinator fills the verdict column from the page.\n\n"
        "| File | Freesound id | Window | Loop | Measured | Scan | Verdict |\n|---|---|---|---|---|---|---|\n"
        + "\n".join(picks) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["scan", "build"])
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--top", type=int, default=5)
    a = ap.parse_args()
    want = lambda k: a.only is None or k in a.only
    if a.cmd == "scan":
        for c in CANDS:
            if want(c[0]):
                print(json.dumps(plan(c, a.top), ensure_ascii=False), flush=True)
        return
    OUT.mkdir(exist_ok=True)
    wpath = HERE / "windows.json"
    results = json.loads(wpath.read_text()) if wpath.exists() else {}
    for c in CANDS:
        if want(c[0]):
            results[c[0]] = build(c)
            print(json.dumps(results[c[0]]), flush=True)
    wpath.write_text(json.dumps({c[0]: results[c[0]] for c in CANDS if c[0] in results}, indent=1) + "\n")
    write_docs(results)


if __name__ == "__main__":
    main()
