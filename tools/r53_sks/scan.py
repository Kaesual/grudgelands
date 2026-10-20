#!/usr/bin/env python3
"""Round 53 prep lane SKS: measure the local source pool for cast-cue candidates.

python3 -I tools/r53_sks/scan.py [PATH_RELATIVE_TO_ORCH ...]

Python 3 standard library plus ffmpeg. Without arguments it measures every
audio file of the pool folders in sources.py (read only) and writes pool.json
next to this script; with arguments only those files, printed. Per file: the
raw length, the sound's own span (first to last 50 ms frame within 40 dB of
the loudest frame), sample peak and RMS over the span in dBFS, the time from
the span's start to its loudest frame, the energy-weighted spectral centroid
(Hz) over the span and in its first and last third, and the mean spectral
flatness (0 = tonal, 1 = noise). A long file is measured over its first
CAP seconds. These are measurements, not listening.
"""

import json
import math
import runpy
import subprocess
import sys
from array import array
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = runpy.run_path(str(HERE / "sources.py"))
ORCH, PACKS, FS_DIRS = SRC["ORCH"], SRC["PACKS"], SRC["FS_DIRS"]
SR = 22050
HOP = 1024          # aspectralstats hop at win_size 2048 (overlap 0.5)
EXT = {".ogg", ".wav", ".mp3"}
CAP = 20           # seconds measured at most (long ambiences: their start)


def pcm(path, extra=()):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-v", "error", "-t", str(CAP), "-i", str(path), *extra,
                        "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True)
    if r.returncode:
        raise RuntimeError(r.stderr.decode(errors="replace")[-400:])
    a = array("f")
    a.frombytes(r.stdout)
    return a


def spectral(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-v", "error", "-t", str(CAP), "-i", str(path), "-ac", "1",
                        "-ar", str(SR), "-af", "aspectralstats=win_size=2048:measure=centroid+flatness,ametadata=print:file=-",
                        "-f", "null", "-"], capture_output=True)
    cen, flat = [], []
    for line in r.stdout.decode(errors="replace").splitlines():
        if ".centroid=" in line:
            cen.append(float(line.split("=")[1]))
        elif ".flatness=" in line:
            flat.append(float(line.split("=")[1]))
    return cen, flat


def db(x):
    return 20 * math.log10(x) if x > 1e-9 else -180.0


def measure(path):
    a = pcm(path)
    n = len(a)
    if not n:
        return None
    fr = int(0.05 * SR)
    env = []
    for i in range(0, n, fr):
        seg = a[i:i + fr]
        env.append(math.sqrt(sum(v * v for v in seg) / len(seg)))
    top = max(env) or 1e-9
    thr = top * 10 ** (-40 / 20)
    on = [i for i, e in enumerate(env) if e >= thr]
    s, e = on[0], on[-1] + 1
    span = a[s * fr:min(n, e * fr)]
    peak = max(abs(v) for v in span)
    rms = math.sqrt(sum(v * v for v in span) / len(span))
    loud = max(range(s, e), key=lambda i: env[i])
    cen, flat = spectral(path)
    # Weight each spectral frame by its energy (frames are HOP samples apart).
    w = []
    for k in range(len(cen)):
        seg = a[k * HOP:k * HOP + 2048]
        w.append(sum(v * v for v in seg) if seg else 0.0)
    lo, hi = s * fr // HOP, max(s * fr // HOP + 1, e * fr // HOP)

    def wmean(vals, i0, i1):
        num = sum(vals[k] * w[k] for k in range(i0, min(i1, len(vals))))
        den = sum(w[k] for k in range(i0, min(i1, len(vals))))
        return num / den if den > 0 else 0.0
    third = max(1, (hi - lo) // 3)
    return {
        "raw": round(n / SR, 3),
        "start": round(s * fr / SR, 3),
        "span": round((e - s) * fr / SR, 3),
        "peak_db": round(db(peak), 1),
        "rms_db": round(db(rms), 1),
        "to_peak": round((loud - s) * fr / SR, 3),
        "centroid": round(wmean(cen, lo, hi)),
        "cen_first": round(wmean(cen, lo, lo + third)),
        "cen_last": round(wmean(cen, hi - third, hi)),
        "flatness": round(wmean(flat, lo, hi), 3),
    }


def pool():
    out = []
    for prefix, *_ in PACKS:
        for p in sorted((ORCH / prefix).rglob("*")):
            if p.suffix.lower() in EXT and "__MACOSX" not in p.parts and "/Mp3/" not in str(p):
                out.append(str(p.relative_to(ORCH)))
    for d, _rec in FS_DIRS:
        if (ORCH / d).is_dir():
            out += [str(p.relative_to(ORCH)) for p in sorted((ORCH / d).glob("fs_*.mp3"))]
    return out


def main():
    files = sys.argv[1:] or pool()
    res = {}
    for rel in files:
        try:
            m = measure(ORCH / rel)
        except Exception as ex:  # a broken file in a pack is reported, not fatal
            print("skip %s: %s" % (rel, ex), file=sys.stderr)
            continue
        if m:
            res[rel] = m
            if sys.argv[1:]:
                print(rel, json.dumps(m))
    if not sys.argv[1:]:
        (HERE / "pool.json").write_text(json.dumps(res, indent=0, sort_keys=True) + "\n")
        print("pool.json: %d files" % len(res))


if __name__ == "__main__":
    main()
