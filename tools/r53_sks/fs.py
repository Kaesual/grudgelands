#!/usr/bin/env python3
"""Round 53 prep lane SKS: Freesound search and HQ-preview fetch (strictly serial).

Always run through the shared lock, one command at a time:
  ~/projects/grudgelands-orchestration/r34/fs_run.sh sks python3 -I tools/r53_sks/fs.py search SLUG "QUERY"
  ~/projects/grudgelands-orchestration/r34/fs_run.sh sks python3 -I tools/r53_sks/fs.py fetch USER/ID ...

`search` loads ONE search page (CC0 filter, 0.3-6 s, most downloaded first) and
keeps id, user, title, duration and downloads in OUT/search/SLUG.json. `fetch`
loads each sound's page (licence and GenAI tag checked there), downloads the
public HQ preview (128 kbit MP3) to OUT/dl/fs_ID.mp3 and records it in
OUT/info.json in the Round 34 format. No login, no originals, no API key.
Requests are 2 s apart; HTTP 429 backs off 20/40/60... s, then gives up.
OUT is ~/projects/grudgelands-orchestration/r53/sks-fs (outside the repo).
"""

import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

OUT = Path.home() / "projects/grudgelands-orchestration/r53/sks-fs"
UA = {"User-Agent": "Mozilla/5.0 (grudgelands sound lane; previews only)"}


def get(url, binary=False):
    for i in range(6):
        time.sleep(2.0)
        try:
            data = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
            return data if binary else data.decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            print("429, backing off", file=sys.stderr)
            time.sleep(20 * (i + 1))
    sys.exit("HTTP 429 persists; stopped")


def search(slug, query):
    f = 'license:"Creative Commons 0" duration:[0.3 TO 6]'
    url = "https://freesound.org/search/?" + urllib.parse.urlencode({"q": query, "f": f, "s": "Downloads (most first)"})
    page = get(url)
    res = []
    for block in page.split('data-sound-id="')[1:]:
        sid = block.split('"', 1)[0]

        def attr(name):
            m = re.search(r'data-%s="([^"]*)"' % name, block)
            return html.unescape(m.group(1)) if m else ""
        ogg = attr("ogg")
        if not ogg or any(r["id"] == sid for r in res):
            continue
        res.append({"id": sid, "user": attr("username"), "title": attr("title"),
                    "duration": round(float(attr("duration") or 0), 2), "downloads": attr("num-downloads"),
                    "preview": ogg.replace("-lq.ogg", "-hq.mp3")})
    (OUT / "search").mkdir(parents=True, exist_ok=True)
    (OUT / "search" / ("%s.json" % slug)).write_text(json.dumps({"query": query, "results": res}, indent=1))
    for r in res:
        print("%-8s %-22s %5.2fs %6s  %s" % (r["id"], r["user"][:22], r["duration"], r["downloads"], r["title"]))


def fetch(items):
    info_p = OUT / "info.json"
    info = json.loads(info_p.read_text()) if info_p.is_file() else {}
    (OUT / "dl").mkdir(parents=True, exist_ok=True)
    for it in items:
        user, sid = it.split("/")
        if sid in info and (OUT / "dl" / ("fs_%s.mp3" % sid)).is_file():
            continue
        page_url = "https://freesound.org/people/%s/sounds/%s/" % (urllib.parse.quote(user), sid)
        p = get(page_url)
        title = html.unescape((re.search(r"<title>(.*?)</title>", p, re.S) or [None, ""])[1]).strip()
        lic = re.search(r"creativecommons\.org/(publicdomain/zero/1\.0|licenses/[a-z-]+/[0-9.]+)", p)
        lic = lic.group(1).replace("licenses/", "") if lic else "?"
        genai = bool(re.search(r"tags/genai|GenAI", p, re.I))
        prev = re.search(r"https://cdn\.freesound\.org/previews/[^\"]+-hq\.mp3", p)
        if lic not in ("publicdomain/zero/1.0", "by/3.0") or genai or not prev:
            print("skip %s: licence %s, genai %s, preview %s" % (sid, lic, genai, bool(prev)))
            continue
        (OUT / "dl" / ("fs_%s.mp3" % sid)).write_bytes(get(prev.group(0), binary=True))
        info[sid] = {"id": sid, "user": user, "title": title, "license": lic, "genai_tag": genai, "page": page_url}
        info_p.write_text(json.dumps(info, indent=1))
        print("ok %s %s (%s)" % (sid, title, lic))


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "search":
        search(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 3 and sys.argv[1] == "fetch":
        fetch(sys.argv[2:])
    else:
        sys.exit(__doc__)
