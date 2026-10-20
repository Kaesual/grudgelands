#!/usr/bin/env python3
"""0.52.1 lane UW: download Freesound HQ previews for the underwater bed.

python3 -I tools/r52_uw/fetch.py [--describe] <id> [<id> ...]   (always through r34/fs_run.sh)

The ids must appear in sound-r52u/fs/*.json (written by search.sh: the search
fetched each sound page and read licence, GenAI tag and preview URL from it).
Writes sound-r52u/dl/fs_<id>.mp3 and sound-r52u/info.json. An existing R32/R34/R52
download is copied, never moved. Refuses anything but CC0 1.0 without a GenAI tag.
"""
import glob
import html
import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.request

O = os.path.expanduser("~/projects/grudgelands-orchestration")
B = O + "/sound-r52u"
UA = {"User-Agent": "Mozilla/5.0"}


def get(u):
    for i in range(6):
        try:
            time.sleep(1.0)
            return urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=90).read()
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            time.sleep(20 * (i + 1))
    raise SystemExit("429 persists")


known = {}
for f in sorted(glob.glob(B + "/fs/*.json")):
    for r in json.load(open(f)):
        known[str(r["id"])] = r
infop = B + "/info.json"
info = json.load(open(infop)) if os.path.exists(infop) else {}
args = sys.argv[1:]
if args and args[0] == "--describe":
    for sid in args[1:]:
        p = get(info[sid]["page"]).decode("utf-8", "replace")
        d = re.search(r'<div[^>]*id="soundDescriptionSection"[^>]*>(.*?)</div>', p, re.S) \
            or re.search(r'<meta name="description" content="([^"]*)"', p)
        desc = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", d.group(1)))).strip() if d else ""
        tags = sorted(set(re.findall(r'href="/browse/tags/([^/"]+)/', p)))
        lic = re.search(r'creativecommons\.org/(publicdomain/zero/1\.0|licenses/[a-z-]+/[0-9.]+)', p)
        info[sid].update({"description": desc[:1500], "tags": tags,
                          "license_recheck": lic.group(1) if lic else "?",
                          "genai_recheck": bool(re.search(r"tags/genai|GenAI", p, re.I))})
        print(sid, info[sid]["license_recheck"], info[sid]["genai_recheck"], "|", desc[:300], "|", " ".join(tags), flush=True)
        json.dump(info, open(infop, "w"), indent=1)
    sys.exit(0)
for sid in args:
    r = known[sid]
    if r.get("license") != "publicdomain/zero/1.0" or r.get("genai_tag"):
        print(sid, "SKIP licence", r.get("license"), r.get("genai_tag"), flush=True)
        continue
    out = B + "/dl/fs_%s.mp3" % sid
    if not os.path.exists(out):
        old = [p for p in glob.glob(O + "/r32/r2-evidence/dl/freesound/fs_%s_*.mp3" % sid)
               + [O + "/r34/listen/dl/fs_%s.mp3" % sid, O + "/sound-r52/dl/fs_%s.mp3" % sid]
               if os.path.exists(p) and os.path.getsize(p) > 0]
        if old:
            shutil.copyfile(old[0], out)
        else:
            open(out, "wb").write(get(r["preview"]))
    info[sid] = {k: r.get(k) for k in ("id", "user", "title", "license", "genai_tag", "page", "duration", "preview")}
    print(sid, r["user"], r.get("license"), os.path.getsize(out), flush=True)
    json.dump(info, open(infop, "w"), indent=1)
