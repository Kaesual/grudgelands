#!/usr/bin/env python3
"""Round 52 lane SND: cut the picked ambience sources into loop beds and calls.

python3 -I tools/r52_snd/cut.py [scan|build] [--only KEY ...]

Python 3 standard library plus the ffmpeg/ffprobe binaries (libvorbis). The
sources are the downloaded Freesound HQ previews in the orchestration folder;
they are only read, never moved, changed or deleted. Output (all in this folder):
out/<target>.ogg, windows.json (the measured windows), picks.md and
license-rows.md.

Shipped conventions (Round 34 plan §3, measured on the shipped beds): mono
Ogg Vorbis 44.1 kHz; beds about 30 s, the loop closed with a 2 s equal-power
crossfade (the excerpt is 2 s longer than the loop: its last 2 s fade out over
the first 2 s), 60 Hz high-pass, integrated loudness -20 LUFS, Vorbis q1
(60 kbit/s nominal, like the shipped beds); calls trimmed, 0.4 s fade-out,
60 Hz high-pass, sample peak -3 dBFS, Vorbis q3 (80 kbit/s, like the thunder).

`scan` prints, per bed, the best windows of the loudness scan; `build` writes
everything. The window is chosen by measurement (momentary loudness, EBU R128,
every 0.1 s): no bursts in the window, nothing loud in the two crossfade zones,
the same level at both ends of the loop, as close as possible to the excerpt the
user heard on the earlier listening page.
"""

import argparse
import json
import math
import os
import re
import subprocess
import sys
import urllib.parse
from array import array
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
ORCH = Path.home() / "projects/grudgelands-orchestration"
SRC_N = ORCH / "sound-r52/dl"       # n_ picks (read only)
SRC_C = ORCH / "r34/listen/dl"      # c_ picks (read only)
INFO = {**json.loads((ORCH / "r34/listen/info.json").read_text()),
        **json.loads((ORCH / "sound-r52/info.json").read_text())}

SR = 44100
LOOP = 30.0          # bed loop length (s)
XF = 2.0             # loop crossfade (s)
HP = 60              # high-pass corner (Hz)
BED_LUFS = -20.0
CALL_PEAK_DB = -3.0
PEAK_CEIL_DB = -1.0  # a bed whose sample peak would exceed this after levelling is reported
FADE_OUT = 0.4       # call fade-out (s)
DIST_DB_PER_S = 0.1  # window score: cost per second outside the excerpt the user heard (unheard
                     # material may hide voices or noise the scan cannot tell from the bed)
SHORT = 40.0         # a source shorter than this loops nearly all of itself

# Beds: key = target stem (file grug_ambience_<key>.ogg), page id, Freesound id,
# start of the excerpt the user heard and its length, sound group, German title.
BEDS = [
    ("battlegrounds_fields", "n_164272", "164272", 25.9, 30, "battlegrounds", "Dunkle Atmo: verlassene Felder"),
    ("crags_mountain", "n_393693", "393693", 195.2, 30, "crags", "Troodos-Gebirge, Zypern"),
    ("crags_birds", "n_733782", "733782", 2.9, 30, "crags", "Bergvögel über einem Sommerfeld"),
    ("crags_birds_clear", "n_855953", "855953", 3.5, 30, "crags", "Vögel, klar (Nordliecht 03)"),
    ("snow_afternoon", "c_dw2", "719852", 30.5, 16, "crags_snowy", "Verschneiter Nachmittag"),
    ("badlands_quiet", "n_352597", "352597", 53.1, 30, "badlands", "Stille Wüste, Vogelruf und Antwort"),
    ("badlands_crickets", "c_or3", "454361", 29.7, 16, "badlands", "Leichter Wüstenwind mit Grillen"),
    ("swamp_frogs", "c_un4", "503206", 28.0, 16, "swamp", "Seerosen und Frösche bei Nacht"),
    ("swamp_evening", "n_325501", "325501", 199.3, 30, "swamp", "King's Hut, später Abend"),
    ("night_tropical", "n_516157", "516157", 19.2, 30, "jungle", "Tropische Nacht (Ecuador)"),
    ("jungle_night_crickets", "n_450537", "450537", 57.3, 30, "jungle", "Amazonas-Nacht, Grillen"),
    ("jungle_night_hills", "n_635951", "635951", 298.4, 30, "jungle", "Dschungelnacht über Soufrière"),
    ("jungle_night_rainforest", "n_871624", "871624", 128.4, 30, "jungle", "Nacht im Regenwald, Nouragues"),
    ("night_insects", "n_328293", "328293", 75.2, 30, "temperate", "Waldnacht, Grillen, Zikaden"),
    ("night_owl_crickets", "c_ni4", "203598", 35.1, 16, "temperate", "Grillen und Waldkauz"),
]
# Calls: key, page id, Freesound id, excerpt start and length the user approved, German title.
CALLS = [
    ("call_crow.1", "c_ca_crow1", "75162", 0.0, 4.1, "Krähe"),
    ("call_crow.2", "c_ca_crow2", "56234", 0.0, 4.7, "Krähen"),
    ("call_hawk.1", "c_ca_hawk1", "39338", 0.0, 5.0, "Adler: Flügel und Schrei"),
    ("call_hawk.2", "c_ca_hawk2", "319619", 0.0, 6.0, "Falkenschrei"),
    ("call_owl.1", "c_ca_owl1", "465697", 0.0, 4.4, "Eule"),
    ("call_owl.2", "c_ca_owl2", "398734", 0.0, 4.0, "Eule (zweite)"),
    ("call_wolf.1", "c_ca_wolf1", "380156", 7.0, 8.0, "Wolfsheulen mit Echo"),
    ("call_wolf.2", "c_ca_wolf2", "503516", 0.0, 8.0, "Fernes Heulen"),
]


def src_path(page_id, fs_id):
    p = (SRC_N if page_id.startswith("n_") else SRC_C) / ("fs_%s.mp3" % fs_id)
    if not p.is_file() or p.stat().st_size == 0:
        sys.exit("missing source %s" % p)
    return p


def run(args, data=None):
    r = subprocess.run(args, input=data, capture_output=True)
    if r.returncode:
        sys.exit("command failed: %s\n%s" % (" ".join(map(str, args)), r.stderr.decode(errors="replace")[-2000:]))
    return r


def duration(p):
    return float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(p)]).stdout)


def momentary(p):
    """EBU R128 momentary loudness (400 ms window) of the mono downmix every 0.1 s: [(t, LUFS)]."""
    err = run(["ffmpeg", "-nostats", "-hide_banner", "-v", "verbose", "-i", str(p), "-af",
               "aformat=channel_layouts=mono,highpass=f=%d,ebur128=framelog=verbose" % HP,
               "-f", "null", "-"]).stderr.decode(errors="replace")
    return [(float(m.group(1)), float(m.group(2)))
            for m in re.finditer(r"t:\s*([\d.]+)\s+TARGET:\S+ LUFS\s+M:\s*(-?[\d.]+)", err)]


def pmean_db(vals):
    """Power mean of loudness values in dB."""
    return 10 * math.log10(sum(10 ** (v / 10) for v in vals) / len(vals)) if vals else -120.0


def score_window(frames, s, loop, heard):
    """Lower is better. frames: [(t, M)]; the window is [s, s + loop + XF]."""
    w = s + loop + XF
    inside = [m for t, m in frames if s + 0.4 <= t <= w]
    if len(inside) < 10:
        return None
    srt = sorted(inside)
    med = srt[len(srt) // 2]
    burst = srt[-1] - med                               # one loud event over the bed
    t_max = max((m, t) for t, m in frames if s + 0.4 <= t <= w)[1] - s
    burst_at = t_max - loop if t_max >= loop else t_max # where it plays in the loop (s)
    zones = [m for t, m in frames if s + 0.4 <= t <= s + XF or s + loop + 0.4 <= t <= w]
    seam = max(0.0, max(zones) - med) if zones else 0.0  # an event cut by the crossfade
    head = [m for t, m in frames if s + 0.4 <= t <= s + 3.0]
    tail = [m for t, m in frames if w - 3.0 <= t <= w]
    mismatch = abs(pmean_db(head) - pmean_db(tail))     # level jump at the loop point
    c, n = heard   # no cost while the window covers the heard excerpt (or lies inside it)
    lo, hi = min(c, c + n - (w - s)), max(c, c + n - (w - s))
    dist = lo - s if s < lo else (s - hi if s > hi else 0.0)
    total = burst + seam + mismatch + DIST_DB_PER_S * dist
    return {"start": round(s, 1), "score": round(total, 2), "burst": round(burst, 1), "burst_at": round(burst_at, 1), "seam": round(seam, 1),
            "mismatch": round(mismatch, 1), "dist": round(dist, 1), "median": round(med, 1)}


def plan_bed(bed, top=1):
    key, pid, fid, clip, heard_len, _, _ = bed
    p = src_path(pid, fid)
    dur = duration(p)
    frames = momentary(p)
    head_margin, tail_margin = 0.4, 0.3   # skip the encoder delay and any edge fade of the preview
    usable = dur - head_margin - tail_margin
    loop = LOOP if dur >= SHORT else math.floor((usable - XF) * 10) / 10
    cands = []
    s = head_margin
    while s + loop + XF <= dur - tail_margin + 1e-6:
        r = score_window(frames, s, loop, (clip, heard_len))
        if r:
            cands.append(r)
        s += 0.5 if loop == LOOP else 0.1
    cands.sort(key=lambda r: r["score"])
    return {"key": key, "src": str(p), "duration": round(dur, 2), "loop": loop, "cands": cands[:top]}


def decode(p, start, length):
    raw = run(["ffmpeg", "-v", "error", "-ss", "%.3f" % start, "-t", "%.3f" % length, "-i", str(p),
               "-af", "aformat=channel_layouts=mono,aresample=%d,highpass=f=%d" % (SR, HP),
               "-f", "f32le", "-"]).stdout
    a = array("f")
    a.frombytes(raw)
    return a


def loop_close(x, loop):
    """Equal-power crossfade of the excerpt's last XF seconds over its first: a seamless loop of `loop` s."""
    n, k = int(round(loop * SR)), int(round(XF * SR))
    if len(x) < n + k:
        sys.exit("excerpt too short: %d < %d" % (len(x), n + k))
    y = array("f", x[:n])
    for i in range(k):
        a = (i + 0.5) / k * math.pi / 2
        y[i] = x[i] * math.sin(a) + x[n + i] * math.cos(a)
    return y


def loudness(x):
    """Integrated loudness (LUFS) of mono float samples."""
    err = run(["ffmpeg", "-nostats", "-hide_banner", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
               "-af", "ebur128", "-f", "null", "-"], data=x.tobytes()).stderr.decode(errors="replace")
    return float(re.findall(r"I:\s*(-?[\d.]+) LUFS", err)[-1])


def peak_db(x):
    m = max(max(x), -min(x))
    return 20 * math.log10(m) if m > 0 else -120.0


def encode(x, dst, quality):
    run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
         "-map_metadata", "-1", "-fflags", "+bitexact", "-c:a", "libvorbis", "-q:a", str(quality), str(dst)],
        data=x.tobytes())


def encode_true(x, dst, quality, key, target):
    """Encode, then correct the level once or twice for what the Vorbis encoder changed (at q1 it
    drops some of the high band, which K-weighted loudness counts): key 'lufs' or 'peak_db'."""
    for _ in range(3):
        encode(x, dst, quality)
        m = measure_file(dst)
        miss = target - m[key]
        if abs(miss) < 0.15:
            break
        x = scaled(x, miss)
        if key == "lufs" and peak_db(x) > PEAK_CEIL_DB:
            x = limit_periodic(x, PEAK_CEIL_DB - 0.3)
    return m


def measure_file(dst):
    x = array("f")
    x.frombytes(run(["ffmpeg", "-v", "error", "-i", str(dst), "-f", "f32le", "-"]).stdout)
    return {"seconds": round(len(x) / SR, 2), "lufs": round(loudness(x), 1), "peak_db": round(peak_db(x), 1),
            "bytes": dst.stat().st_size}


def limit_periodic(x, ceil_db):
    """Peak limiter that keeps the loop seamless: the loop is limited three times in a row and one
    period from the middle copy is kept, so the limiter state at the wrap matches the loop end."""
    n = len(x)
    raw = run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-af",
               "alimiter=limit=%.5f:attack=5:release=80:level=0" % (10 ** (ceil_db / 20)), "-f", "f32le", "-"],
              data=(x * 3).tobytes()).stdout
    y = array("f")
    y.frombytes(raw)
    return array("f", y[n:2 * n])


def scaled(x, gain_db):
    g = 10 ** (gain_db / 20)
    return array("f", (v * g for v in x))


def level_bed(x):
    """-20 LUFS; where that pushes the sample peak over PEAK_CEIL_DB the peaks are limited instead."""
    gain = BED_LUFS - loudness(x)
    y = scaled(x, gain)
    raw_peak = peak_db(y)
    if raw_peak <= PEAK_CEIL_DB:
        return y, gain, raw_peak, False
    for _ in range(4):   # limiting lowers the loudness a little: raise the drive until it holds
        y = limit_periodic(scaled(x, gain), PEAK_CEIL_DB - 0.3)
        miss = BED_LUFS - loudness(y)
        if abs(miss) < 0.1:
            break
        gain += miss
    return y, gain, raw_peak, True


def build_bed(bed):
    plan = plan_bed(bed)
    best = plan["cands"][0]
    p, loop, s = Path(plan["src"]), plan["loop"], best["start"]
    x, gain, raw_peak, limited = level_bed(loop_close(decode(p, s, loop + XF), loop))
    dst = OUT / ("grug_ambience_%s.ogg" % bed[0])
    m = encode_true(x, dst, 1, "lufs", BED_LUFS)
    return {"key": bed[0], "kind": "bed", "window": [s, round(s + loop + XF, 1)], "loop": loop,
            "gain_db": round(gain, 1), "unlimited_peak_db": round(raw_peak, 1), "limited": limited,
            "scan": best, **m}


def build_call(call):
    key, pid, fid, start, length, _ = call
    p = src_path(pid, fid)
    x = decode(p, start, length)
    pk = max(max(x), -min(x))
    # Trim silence: from 50 ms before the first sample within 30 dB of the peak, to 0.3 s after the
    # last sample within 40 dB of it (never past the approved excerpt).
    first = next(i for i, v in enumerate(x) if abs(v) >= pk * 10 ** (-30 / 20))
    last = max(i for i, v in enumerate(x) if abs(v) >= pk * 10 ** (-40 / 20))
    a = max(0, first - int(0.05 * SR))
    b = min(len(x), last + int(0.3 * SR))
    y = array("f", x[a:b])
    fi, fo = int(0.01 * SR), min(int(FADE_OUT * SR), len(y) // 2)
    if a > 0:
        for i in range(fi):
            y[i] *= i / fi
    for i in range(fo):
        y[len(y) - fo + i] *= 1 - (i + 1) / fo
    g = 10 ** ((CALL_PEAK_DB - peak_db(y)) / 20)
    y = array("f", (v * g for v in y))
    dst = OUT / ("grug_ambience_%s.ogg" % key)
    m = encode_true(y, dst, 3, "peak_db", CALL_PEAK_DB)
    return {"key": key, "kind": "call", "window": [round(start + a / SR, 2), round(start + b / SR, 2)], **m}


def info_row(fid):
    i = INFO[fid]
    if i.get("license") != "publicdomain/zero/1.0" or i.get("genai_tag"):
        sys.exit("licence check failed for %s: %s" % (fid, i))
    user = urllib.parse.unquote(i["user"])
    title = re.sub(r"^Freesound - ", "", i["title"])
    title = re.sub(r" by %s$" % re.escape(user), "", title)
    return title, user, i["page"]


def write_docs(results):
    rows, picks = [], []
    lic = "[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)"
    for bed in BEDS:
        r = results.get(bed[0])
        if not r:
            continue
        title, user, page = info_row(bed[2])
        a, b = r["window"]
        mod = ("HQ preview (MP3); excerpt %.1f-%.1f s, looped with a 2 s crossfade (%g s loop), 60 Hz high-pass, "
               "levelled to -20 LUFS, mono Ogg" % (a, b, r["loop"]))
        rows.append("| `sounds/grug_ambience_%s.ogg` | %s | %s | [%s](%s) | %s | %s |" % (bed[0], title, user, page, page, lic, mod))
        picks.append("| grug_ambience_%s.ogg | %s | %s | %.1f-%.1f s (heard: %.1f-%.1f s) | %g s | %.1f LUFS, peak %.1f dBFS | |"
                     % (bed[0], bed[1], bed[5], a, b, bed[3], bed[3] + bed[4], r["seconds"], r["lufs"], r["peak_db"]))
    for call in CALLS:
        r = results.get(call[0])
        if not r:
            continue
        title, user, page = info_row(call[2])
        a, b = r["window"]
        mod = ("HQ preview (MP3); excerpt %.2f-%.2f s, 0.4 s fade-out, 60 Hz high-pass, peak-normalised to -3 dBFS, "
               "mono Ogg" % (a, b))
        rows.append("| `sounds/grug_ambience_%s.ogg` | %s | %s | [%s](%s) | %s | %s |" % (call[0], title, user, page, page, lic, mod))
        picks.append("| grug_ambience_%s.ogg | %s | calls | %.2f-%.2f s (heard: %.1f-%.1f s) | %g s | %.1f LUFS, peak %.1f dBFS | |"
                     % (call[0], call[1], a, b, call[3], call[3] + call[4], r["seconds"], r["lufs"], r["peak_db"]))
    (HERE / "license-rows.md").write_text(
        "# Round 52 SND: licence rows (ready to paste)\n\n"
        "Rows in the format of `mods/CORE/grug_ambience/LICENSE-media.md`, one per staged file. Licence (CC0 1.0)\n"
        "and author re-verified from the stored source-page records (`sound-r52/info.json`,\n"
        "`r34/listen/info.json`: licence `publicdomain/zero/1.0`, `genai_tag` false), written by `cut.py`.\n"
        "AMB pastes only the rows of approved files.\n\n"
        "| File | Title | Author | Source | License | Modifications |\n|---|---|---|---|---|---|\n"
        + "\n".join(rows) + "\n")
    (HERE / "picks.md").write_text(
        "# Round 52 SND: staged files\n\n"
        "Written by `cut.py`. Files in `out/`; windows are seconds in the source preview (beds: excerpt =\n"
        "loop + 2 s crossfade). \"Heard\" is the excerpt the user rated on the earlier listening page.\n"
        "The coordinator fills the approved column from the ratings of the SND page.\n\n"
        "| File | Page id | Group | Window | Length | Measured | Approved |\n|---|---|---|---|---|---|---|\n"
        + "\n".join(picks) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["scan", "build"])
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--top", type=int, default=5)
    a = ap.parse_args()
    want = lambda k: a.only is None or k in a.only
    if a.cmd == "scan":
        for bed in BEDS:
            if want(bed[0]):
                print(json.dumps(plan_bed(bed, a.top), ensure_ascii=False))
        return
    OUT.mkdir(exist_ok=True)
    wpath = HERE / "windows.json"
    results = json.loads(wpath.read_text()) if wpath.exists() else {}
    for bed in BEDS:
        if want(bed[0]):
            results[bed[0]] = build_bed(bed)
            print(json.dumps(results[bed[0]]), flush=True)
    for call in CALLS:
        if want(call[0]):
            results[call[0]] = build_call(call)
            print(json.dumps(results[call[0]]), flush=True)
    order = [b[0] for b in BEDS] + [c[0] for c in CALLS]
    wpath.write_text(json.dumps({k: results[k] for k in order if k in results}, indent=1) + "\n")
    write_docs(results)


if __name__ == "__main__":
    main()
