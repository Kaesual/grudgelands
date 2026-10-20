#!/usr/bin/env python3
"""Round 53 prep lane SKS: cut the cast-cue candidates for the new class skills.

python3 -I tools/r53_sks/cut.py [--only ROW ...]

Python 3 standard library plus ffmpeg/ffprobe (libvorbis). Reads ROWS below,
the sources through sources.py (orchestration folder, read only: ffmpeg reads,
never writes there) and pool.json from scan.py (each source's measured span).
Writes out/<key>.ogg, cuts.json (measured per candidate), picks.md and
license-rows.md.

Cut like the shipped cast cues (mods/CORE/grug_sounds/LICENSE-media.md):
mono Ogg Vorbis q3, 44.1 kHz, start silence trimmed (the window starts at the
sound's measured span unless a row names a start), a 5 ms fade-in against a
click, a short fade-out, sample peak -3 dBFS. Candidate 1 of each row is the
shipped cue the round plan (§8 Q2) proposes to reuse: its file is copied
unchanged from mods/CORE/grug_sounds/sounds/, so it is exactly what the game
plays. Every candidate ends with the same -3 dBFS peak, so the page compares
like for like; in game each cue's gain is set per event in grug_sounds.
"""

import argparse
import json
import math
import runpy
import shutil
import subprocess
import sys
import tempfile
from array import array
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = runpy.run_path(str(HERE / "sources.py"))
SCAN = runpy.run_path(str(HERE / "scan.py"))
source, SHIPPED, ORCH = SRC["source"], SRC["SHIPPED"], SRC["ORCH"]
OUT = HERE / "out"
POOL = json.loads((HERE / "pool.json").read_text())

PEAK_DB = -3.0
MAX_DUR = 2.5
SR = 44100

# Shipped grug_sounds events -> sound file stem (mods/CORE/grug_sounds/init.lua).
EVENTS = {
    "cast_cinderfall": "grug_sounds_cast_cinderfall", "cast_ice_nova": "grug_sounds_cast_ice_nova",
    "cast_frost_ward": "grug_sounds_cast_frost_ward", "cast_taunt": "grug_sounds_cast_taunt",
    "cast_guard": "grug_sounds_cast_guard", "cast_heal": "grug_sounds_cast_heal",
    "cast_holy": "grug_sounds_cast_holy", "cast_evade": "grug_sounds_cast_evade",
    "fireball_launch": "grug_sounds_fireball_launch", "fireball_hit": "grug_sounds_fireball_hit",
    "ice_break": "grug_sounds_ice_break", "swing": "grug_sounds_swing",
    "bow_shot": "grug_sounds_bow_shot", "arrow_hit": "grug_sounds_arrow_hit",
}


def fs(i):
    hits = [k for k in POOL if k.endswith("/fs_%s.mp3" % i)]
    if len(hits) != 1:
        sys.exit("Freesound %s: %d pool entries" % (i, len(hits)))
    return hits[0]


def pk(name):
    hits = [k for k in POOL if k.endswith("/" + name)]
    if len(hits) != 1:
        sys.exit("%s: %d pool entries" % (name, len(hits)))
    return hits[0]


def C(src, start=None, dur=None, fade=None):
    """A new candidate: source, window start and length in the source (s), fade-out (s)."""
    return {"src": src, "start": start, "dur": dur, "fade": fade}


# Rows: key, skill id, kind, class, tree, skill name, one-line effect (German),
# why this row exists / how the cue is used (German), the plan's reuse (shipped
# event, candidate 1), then the new candidates (2-4).
ROWS = [
    # --- Mage, Ember (fire: crackle, whoosh)
    ("meteor", "meteor", "cast", "Magier", "Ember", "Meteor",
     "Bodenziel bis 20 m; nach 1,5 s Vorwarnung schlägt ein Meteor ein: 1,4 D im Radius 3 m.",
     "Ton beim Wirken. Der Plan nimmt den Ton von Cinderfall, der Fähigkeit, die Meteor ersetzt.",
     "cast_cinderfall",
     [C(fs(592572), 0.0, 2.0), C(fs(260555), 0.2, 2.0), C(fs(442872))]),
    ("meteor_impact", "meteor", "impact", "Magier", "Ember", "Meteor",
     "Der Einschlag 1,5 s nach dem Wirken, einmal am Zielpunkt.",
     "Einschlag-Ton. Der Plan sieht hier keinen eigenen Ton vor; Vorschlag 1 ist der Treffer-Ton des Feuerballs.",
     "fireball_hit",
     [C(pk("explode1.ogg"), 0.0, 2.4), C(fs(239569), 0.3, 2.2), C(fs(186932), 1.5, 2.2)]),
    ("fire_rain", "fire_rain", "cast", "Magier", "Ember", "Fire Rain",
     "Ultimate: Bodenziel bis 20 m; nach 1,5 s ein einziger Feuerschauer, ~2,5 D im Radius 5 m.",
     "Ton beim Wirken.",
     "cast_cinderfall",
     [C(fs(412558), 0.35, 2.0), C(fs(475879), 0.1, 1.3), C(pk("spell_fire_04.ogg"))]),
    ("fire_rain_impact", "fire_rain", "impact", "Magier", "Ember", "Fire Rain",
     "Der Feuerschauer 1,5 s nach dem Wirken, einmal am Zielpunkt.",
     "Einschlag-Ton. Der Plan merkt das knisternde Feuer der Kulissen-Hörseite (c_bg3) als Idee für Fire Rain vor: es ist Vorschlag 2.",
     "fireball_hit",
     [C(fs(182369), 0.5, 2.5, 0.6), C(fs(442677), 0.3, 2.2), C(fs(234555), 0.6, 2.4)]),
    # --- Mage, Rime (frost crystals)
    ("cold_spark", "cold_spark", "launch", "Magier", "Rime", "Cold Spark",
     "Verwandelt Fiery Spark: freies Frostgeschoss, D Schaden, 12 % Verlangsamung für 1,5 s.",
     "Abschuss-Ton des Geschosses. Eigentlich ein Geschoss mit dem gemeinsamen Geschoss-Ton; übernimmt es den Ton des Feuerballs, klingt der Frostfunke nach Feuer. Darum hier eine Zeile.",
     "fireball_launch",
     [C(fs(683180)), C(fs(160420)), C(fs(709888), 0.2, 1.6)]),
    ("ice_wave", "ice_wave", "cast", "Magier", "Rime", "Ice Wave",
     "Startfähigkeit: Eiswelle im 70°-Kegel bis 5 m, 0,25 D, 50 % Verlangsamung für 3 s.",
     "Ton beim Wirken.",
     "cast_ice_nova",
     [C(fs(691005)), C(fs(263915), 0.05, 1.9), C(fs(685253), 0.2, 2.2)]),
    ("rime_mantle", "rime_mantle", "cast", "Magier", "Rime", "Rime Mantle",
     "Selbstschutz: Rüstung +0,20 K und ein Schild von 12 % P für 6 s.",
     "Ton beim Wirken. Der Plan nimmt den Ton von Glacial Ward, das Rime Mantle ersetzt.",
     "cast_frost_ward",
     [C(fs(396447), 0.1, 2.4), C(fs(274542), 0.5, 2.0), C(fs(263913), 0.05, 1.9)]),
    ("winter_field", "winter_field", "cast", "Magier", "Rime", "Winter Field",
     "Ultimate: Bodenziel bis 15 m; nach 1 s ein Treffer ~1,0 D und 40 % Verlangsamung für 5 s im Radius 4 m.",
     "Ton beim Wirken.",
     "cast_ice_nova",
     [C(fs(569109), 0.6, 2.2), C(fs(381853), 0.3, 1.6), C(fs(844261), 0.5, 2.2)]),
    ("winter_field_impact", "winter_field", "impact", "Magier", "Rime", "Winter Field",
     "Das Gefrieren 1 s nach dem Wirken, einmal am Zielpunkt.",
     "Einschlag-Ton. Der Plan sieht hier keinen eigenen Ton vor; Vorschlag 1 ist das Eisbrechen der Frostrüstung.",
     "ice_break",
     [C(fs(422633)), C(fs(719973)), C(fs(262635))]),
    # --- Warrior, Bulwark (steel)
    ("bellow", "bellow", "cast", "Krieger", "Bulwark", "Bellow",
     "Verwandelt Taunt: Flächen-Spott um den Krieger, 6 m.",
     "Ton beim Wirken. Vorschlag 1 ist ein Kampfschrei (eine Stimme); die neuen Vorschläge kommen ohne Stimme aus.",
     "cast_taunt",
     [C(fs(539956), 0.0, 2.5, 0.6), C(fs(371353), 0.0, 2.0), C(fs(370203))]),
    ("unbroken", "unbroken", "cast", "Krieger", "Bulwark", "Unbroken",
     "Ultimate: 8 s lang Rüstung +0,50 K und ein Schild von 0,15 P; keine Unverwundbarkeit.",
     "Ton beim Wirken.",
     "cast_guard",
     [C(fs(209772), 0.2, 1.2), C(fs(523760)), C(fs(530486), 0.0, 1.7)]),
    # --- Warrior, Ruin (rage)
    ("broadstroke", "broadstroke", "swing", "Krieger", "Ruin", "Broadstroke",
     "Verwandelt Mighty Blow: derselbe Hieb, dazu bis zu 2 weitere Gegner im 100°-Bogen (3 m) mit 0,35 S.",
     "Ein Schwung-Proc wie Mighty Blow, der den Waffen-Sound nutzt. Als einziger Schwung trifft er einen ganzen Bogen; ein schwererer, breiterer Luftzug würde ihn vom gewöhnlichen Hieb unterscheiden. Darum hier eine Zeile; Vorschlag 1 ist der Waffen-Schwung von heute.",
     "swing",
     [C(fs(475135)), C(fs(234547), 0.15, 1.6), C(fs(171321), 0.6, 1.0)]),
    ("ruination", "ruination", "cast", "Krieger", "Ruin", "Ruination",
     "Ultimate: 8 s lang Schwungschaden +15 % und +2 Wut je Treffer.",
     "Ton beim Wirken.",
     "cast_guard",
     [C(fs(701308), 0.0, 2.5), C(fs(807976), 0.2, 1.5), C(pk("Spell_04.wav"), 0.2, 2.2)]),
    # --- Priest, Mercy (warm light)
    ("hearten", "hearten", "cast", "Priester", "Mercy", "Hearten",
     "Sofort-Heilung für sich und bis zu 3 Verbündete in 6 m, die mit den wenigsten LP zuerst, je ~15 % P.",
     "Ton beim Wirken.",
     "cast_heal",
     [C(fs(562292), 0.0, 1.2), C(fs(506939)), C(pk("blessing2.ogg"))]),
    ("haven", "haven", "cast", "Priester", "Mercy", "Haven",
     "Ultimate: Kreis von 8 m um den Priester, bis zu 5 Verbündete bekommen eine Heilung über Zeit (6 × ~7 % P).",
     "Ton beim Wirken.",
     "cast_heal",
     [C(fs(677773), 0.2, 2.4), C(fs(844398), 0.0, 2.4), C(pk("blessing.ogg"), 0.0, 2.5)]),
    # --- Priest, Reckoning (hard judgment gold)
    ("rebuke", "rebuke", "cast", "Priester", "Reckoning", "Rebuke",
     "Sofort-Treffer bis 20 m, 1,8 (W+I).",
     "Ton beim Wirken.",
     "cast_holy",
     [C(fs(406063), 0.1, 1.9), C(fs(641897)), C(fs(430769), 0.0, 2.3)]),
    ("censure", "censure", "cast", "Priester", "Reckoning", "Censure",
     "Bodenziel bis 16 m; nach ~0,75 s Vorwarnung ein Treffer 1,2 (W+I) im Radius 3 m, höchstens 4 Gegner.",
     "Ton beim Wirken.",
     "cast_holy",
     [C(fs(420676)), C(fs(249817), 0.4, 2.0), C(pk("Spell_01.wav"))]),
    ("censure_impact", "censure", "impact", "Priester", "Reckoning", "Censure",
     "Das Siegel schlägt ~0,75 s nach dem Wirken auf, einmal am Zielpunkt.",
     "Einschlag-Ton. Censure ist wie Meteor eine verzögerte Fläche, darum auch hier eine Einschlag-Zeile (der Auftrag nennt sie nicht ausdrücklich). Der Plan sieht keinen eigenen Ton vor; Vorschlag 1 ist der heilige Ton von heute.",
     "cast_holy",
     [C(fs(249814), 0.1, 1.6), C(fs(855910), 0.0, 2.5), C(fs(413224))]),
    ("final_word", "final_word", "cast", "Priester", "Reckoning", "Final Word",
     "Ultimate: Sofort-Treffer bis 20 m, 2,8 (W+I).",
     "Ton beim Wirken.",
     "cast_holy",
     [C(fs(871781), 0.4, 2.0), C(fs(592042), 0.0, 2.5), C(fs(802726), 0.25, 2.5)]),
    # --- Scout, Quarry (wild: nature, bow)
    ("arrowfall", "arrowfall", "cast", "Späher", "Quarry", "Arrowfall",
     "Ultimate: 4 Pfeile zugleich auf das Ziel im Fadenkreuz, je 1,4 R.",
     "Ton beim Loslassen. Die Pfeile nutzen den Geschoss-Ton; vier zugleich wären viermal der Bogenschuss. Vorschlag 1 ist der Bogenschuss von heute (einmal).",
     "bow_shot",
     [C(fs(394004), 1.9, 1.4), C(fs(574044)), C(fs(511490))]),
    ("arrowfall_impact", "arrowfall", "impact", "Späher", "Quarry", "Arrowfall",
     "Die vier Pfeile treffen; Iron Hail (Q13) ist nur ein Schadens-Talent darauf und hat keinen eigenen Ton.",
     "Einschlag-Ton, einmal am Ziel. Vorschlag 1 ist der Pfeiltreffer von heute.",
     "arrow_hit",
     [C(fs(205938)), C(fs(321129), 0.2, 2.0), C(fs(410751), 0.15, 1.6)]),
    # --- Scout, Veil (shadow)
    ("parry", "parry", "cast", "Späher", "Veil", "Parry",
     "Fängt 2 s lang ~10 % der max. LP ab und öffnet 3 s ein Fenster für Opening.",
     "Ton beim Wirken.",
     "cast_evade",
     [C(fs(275159)), C(fs(334169)), C(fs(439540))]),
    ("flourish", "flourish", "cast", "Späher", "Veil", "Flourish",
     "Sofort: 90°-Kegel bis 3 m, die 3 nächsten Gegner nehmen je 0,80 M.",
     "Ton beim Wirken. Flourish ist kein Schwung-Proc, sondern ein Zauber mit eigenem Ton; der Plan nimmt den Ausweich-Ton.",
     "cast_evade",
     [C(fs(60030)), C(fs(353708), 0.25, 1.5), C(fs(171255), 0.2, 1.5)]),
    ("close_dance", "close_dance", "cast", "Späher", "Veil", "Close Dance",
     "Ultimate: 6 s lang Klingenschwünge +0,35 M und ein Schild von ~15 % der max. LP.",
     "Ton beim Wirken.",
     "cast_evade",
     [C(fs(442825)), C(fs(523204)), C(fs(657541), 0.3, 2.2)]),
]

# Skills that keep the shared weapon or projectile sound (no row; German reason).
KEEP = [
    ("Magier", "Ember", "Fiery Spark", "fiery_spark", "Geschoss-Sound",
     "Startgeschoss, ersetzt Strike; der Abschuss- und Treffer-Ton des Feuerballs."),
    ("Magier", "Ember", "Flame Lance", "flame_lance", "Geschoss-Sound",
     "Schweres Feuergeschoss; Feuer-Geschosston wie der Feuerball."),
    ("Krieger", "Bulwark", "Retort", "retort", "Waffen-Sound",
     "Verwandelt Strike; ein gewöhnlicher Schwung mit Bonus, der Schwung-Ton bleibt."),
    ("Späher", "Quarry", "True Draw", "true_draw", "Geschoss-Sound",
     "Ein gezielter Pfeil: der Bogenschuss von heute."),
    ("Späher", "Quarry", "Split Shot", "split_shot", "Geschoss-Sound",
     "Ein Pfeil, der beim Treffer auf 2 Nachbarn überspringt: Bogenschuss und Pfeiltreffer."),
    ("Späher", "Veil", "Bladecraft", "bladecraft", "Waffen-Sound",
     "Verwandelt Loose: Klinge mit der linken, Schuss mit der rechten Maustaste; beide behalten ihre Töne."),
]


def run(args):
    r = subprocess.run(args, capture_output=True)
    if r.returncode:
        sys.exit("command failed: %s\n%s" % (" ".join(map(str, args)), r.stderr.decode(errors="replace")[-1500:]))
    return r


def tag(src):
    """Short source tag for the file name."""
    if src.startswith("shipped:"):
        return "shipped-" + src.split(":", 1)[1]
    m = source(src)
    if "fs_id" in m:
        return "fs%s" % m["fs_id"]
    pack = {"p0ss": "p0ss", "rubberduck": "rubberduck", "artisticdude": "artisticdude", "Kenney": "kenney"}
    who = pack.get(m["author"], "lrsf" if m["author"].startswith("Little Robot") else m["author"].split()[0].lower())
    return "%s-%s" % (who, Path(m["file"]).stem.replace(" ", "").replace("_", "-"))


def peak_db(path):
    """Sample peak in dBFS at the file's own 44.1 kHz (the scan decodes at 22.05 kHz)."""
    r = subprocess.run(["ffmpeg", "-hide_banner", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
                        "-f", "f32le", "-"], capture_output=True)
    a = array("f")
    a.frombytes(r.stdout)
    return 20 * math.log10(max(abs(v) for v in a) or 1e-9)


def measure(path):
    """Length, sample peak, RMS, spectral centroid/flatness of a finished cut (the scan's measure)."""
    m = SCAN["measure"](path)
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                       capture_output=True)
    m["dur"] = round(float(r.stdout), 2)
    m["peak_db"] = round(peak_db(path), 1)
    return m


def cut(cand, key):
    out = OUT / (key + ".ogg")
    src = cand["src"]
    if src.startswith("shipped:"):
        shutil.copyfile(SHIPPED / (EVENTS[src.split(":", 1)[1]] + ".ogg"), out)
        return out, {"cut_start": 0.0, "cut_len": None, "fade": None, "gain_db": 0.0, "copied": True}
    meas = POOL[src]
    start = cand["start"] if cand["start"] is not None else max(0.0, meas["start"] - 0.01)
    dur = cand["dur"] if cand["dur"] is not None else min(MAX_DUR, meas["span"] + 0.05)
    dur = min(dur, MAX_DUR, meas["raw"] - start)
    fade = cand["fade"] if cand["fade"] is not None else round(min(0.4, max(0.08, dur * 0.3)), 2)
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "w.wav"
        run(["ffmpeg", "-hide_banner", "-v", "error", "-y", "-ss", "%.3f" % start, "-t", "%.3f" % dur,
             "-i", str(ORCH / src), "-ac", "1", "-ar", str(SR),
             "-af", "afade=t=in:d=0.005,afade=t=out:st=%.3f:d=%.3f" % (max(0.0, dur - fade), fade),
             "-c:a", "pcm_f32le", str(wav)])
        gain = PEAK_DB - peak_db(wav)
        # Vorbis moves the peak by up to about a dB: one corrective encode.
        for _ in range(2):
            run(["ffmpeg", "-hide_banner", "-v", "error", "-y", "-i", str(wav), "-af", "volume=%.2fdB" % gain,
                 "-c:a", "libvorbis", "-q:a", "3", "-ac", "1", str(out)])
            off = PEAK_DB - peak_db(out)
            if abs(off) <= 0.2:
                break
            gain += off
    return out, {"cut_start": round(start, 3), "cut_len": round(dur, 3), "fade": fade, "gain_db": round(gain, 1),
                 "copied": False}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    args = ap.parse_args()
    OUT.mkdir(exist_ok=True)
    old = json.loads((HERE / "cuts.json").read_text()) if (HERE / "cuts.json").is_file() else {}
    res = {}
    for row in ROWS:
        rkey, skill, kind, cls, tree, name, effect, why, reuse, cands = row
        for n, cand in enumerate([C("shipped:" + reuse)] + cands, 1):
            key = "%s_%d_%s" % (rkey, n, tag(cand["src"]))
            if args.only and rkey not in args.only and key in old:
                res[key] = old[key]
                continue
            path, how = cut(cand, key)
            m = measure(path)
            res[key] = {"row": rkey, "n": n, "src": cand["src"], **m, **how}
            print("%-44s %5.2fs peak %5.1f rms %5.1f cen %5d fl %.2f" % (key, m["dur"], m["peak_db"], m["rms_db"],
                                                                       m["centroid"], m["flatness"]))
    for f in OUT.glob("*.ogg"):
        if f.stem not in res:
            f.unlink()      # a renamed candidate's old cut (our own output only)
    (HERE / "cuts.json").write_text(json.dumps(res, indent=1, sort_keys=True) + "\n")
    write_docs(res)


def row_title(rkey, name, kind):
    return name + (" (Einschlag)" if kind == "impact" else " (Abschuss)" if kind == "launch" else "")


def credit(src):
    if src.startswith("shipped:"):
        ev = src.split(":", 1)[1]
        return {"title": "%s.ogg (shipped event `%s`)" % (EVENTS[ev], ev), "author": "see grug_sounds/LICENSE-media.md",
                "license": "as shipped", "page": "", "license_url": ""}
    return source(src)


def write_docs(res):
    lines = ["# Round 53 prep SKS: cast-cue candidates", "",
             "Built by `cut.py` (measured values: length in s, sample peak in dBFS after encoding).",
             "Candidate 1 of each row is the shipped cue the round plan (§8 Q2) proposes to reuse.",
             "The verdict column is left for the coordinator.", "",
             "| Row | Candidate key | Source | Licence | Duration | Peak | Verdict |",
             "|---|---|---|---|---:|---:|---|"]
    lic = ["# Round 53 prep SKS: licence rows for the candidates", "",
           "Rows in the format of `mods/CORE/grug_sounds/LICENSE-media.md`, one per new candidate; the",
           "file name is the candidate's key. When a candidate is picked, its row moves into that file",
           "with the shipped name (`grug_sounds_cast_<skill>.ogg`) and its page reference. Freesound",
           "sources are the public HQ previews (128 kbit MP3); each page was checked for its licence and",
           "the GenAI tag when it was fetched (`fs.py`).", "",
           "Credit for any picked CC BY 3.0 file (the author's requested wording): sounds by Little Robot",
           "Sound Factory, www.littlerobotsoundfactory.com, from the \"Fantasy Sound Effects Library\"",
           "(https://opengameart.org/content/fantasy-sound-effects-library), licensed under CC BY 3.0. Any",
           "picked p0ss file is used under CC BY-SA 3.0 (the pack is dual-licensed GPL).", "",
           "| File | Page | Source | Author | License | Modification | SHA-256 (first 16) |",
           "|---|---|---|---|---|---|---|"]
    import hashlib
    for row in ROWS:
        rkey, skill, kind, cls, tree, name, *_ = row
        for key, c in sorted(((k, v) for k, v in res.items() if v["row"] == rkey), key=lambda kv: kv[1]["n"]):
            m = credit(c["src"])
            src = m["title"] if c["copied"] else "[%s](%s), %s" % (m["title"], m["page"], m["author"])
            lines.append("| %s | `%s` | %s | %s | %.2f | %.1f | |" % (
                row_title(rkey, name, kind), key, src, m["license"], c["dur"], c["peak_db"]))
            if c["copied"]:
                continue
            sha = hashlib.sha256((OUT / (key + ".ogg")).read_bytes()).hexdigest()[:16]
            mod = ("converted to mono Ogg Vorbis q3, cut %.2f-%.2f s, fade-out %.2f s, peak-normalised to -3 dBFS"
                   % (c["cut_start"], c["cut_start"] + c["cut_len"], c["fade"]))
            lic.append("| `%s.ogg` | R53 SKS %s.%d | %s | [%s](%s) | [%s](%s) | %s | `%s` |" % (
                key, rkey, c["n"], ("\"%s\"" % m["title"]) if "fs_id" in m else "`%s`" % m["file"],
                m["author"], m["page"], m["license"], m["license_url"], mod, sha))
    (HERE / "picks.md").write_text("\n".join(lines) + "\n")
    (HERE / "license-rows.md").write_text("\n".join(lic) + "\n")


if __name__ == "__main__":
    main()
