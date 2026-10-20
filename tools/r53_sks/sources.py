#!/usr/bin/env python3
"""Round 53 prep lane SKS: where the candidate sources live and who made them.

Imported by scan.py, cut.py and build_page.py (runpy). Python 3 standard
library only. Every source folder is in the orchestration folder and is only
read: the cut copies through ffmpeg, it never moves, rewrites or deletes.

`source(rel)` turns a path relative to ORCH into {path, file, title, author,
license, license_url, page}. Licences are the ones the Round 34 approval
accepted (tools/r34_s1b/approved.txt): CC0 1.0, CC BY 3.0 and CC BY-SA 3.0
(p0ss's pack, dual-licensed GPL, used under CC BY-SA 3.0).
"""

import json
from pathlib import Path

ORCH = Path.home() / "projects/grudgelands-orchestration"
REPO = Path(__file__).resolve().parents[2]
SHIPPED = REPO / "mods/CORE/grug_sounds/sounds"

LIC = {
    "CC0 1.0": "https://creativecommons.org/publicdomain/zero/1.0/",
    "CC BY 3.0": "https://creativecommons.org/licenses/by/3.0/",
    "CC BY-SA 3.0": "https://creativecommons.org/licenses/by-sa/3.0/",
}

# Pack folders under ORCH: (prefix, author, licence, pack page).
PACKS = [
    ("r32/r2-evidence/dl/oga_spells/", "p0ss", "CC BY-SA 3.0",
     "https://opengameart.org/content/spell-sounds-starter-pack"),
    ("r32/r2-evidence/dl/oga_Fantasy_Sound_Library/", "Little Robot Sound Factory (www.littlerobotsoundfactory.com)",
     "CC BY 3.0", "https://opengameart.org/content/fantasy-sound-effects-library"),
    ("r32/r2-evidence/dl/oga_80-CC0-RPG-SFX_0/", "rubberduck", "CC0 1.0",
     "https://opengameart.org/content/80-cc0-rpg-sfx"),
    ("r32/r2-evidence/dl/oga_sfx_100_v2/", "rubberduck", "CC0 1.0",
     "https://opengameart.org/content/100-cc0-sfx-2"),
    ("r32/r2-evidence/dl/oga_100-CC0-wood-metal-SFX/", "rubberduck", "CC0 1.0",
     "https://opengameart.org/content/100-cc0-metal-and-wood-sfx"),
    ("r32/r2-evidence/dl/oga_sfx_breaking_and_falling/", "rubberduck", "CC0 1.0",
     "https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx"),
    ("r32/r2-evidence/dl/oga_rpg_sound_pack/", "artisticdude", "CC0 1.0",
     "https://opengameart.org/content/rpg-sound-pack"),
    ("r32/r2-evidence/dl/kenney_rpg-audio/", "Kenney", "CC0 1.0", "https://kenney.nl/assets/rpg-audio"),
    ("r32/r2-evidence/dl/kenney_impact-sounds/", "Kenney", "CC0 1.0", "https://kenney.nl/assets/impact-sounds"),
]

# Freesound HQ previews already downloaded (Round 34), with their records.
FS_DIRS = [
    ("r34/previews/s1b/work/dl/", "r34/previews/s1b/work/info.json"),
    ("r34/listen/dl/", "r34/listen/info.json"),
    ("r53/sks-fs/dl/", "r53/sks-fs/info.json"),   # this lane's own downloads, if any
]

FS_LIC = {"publicdomain/zero/1.0": "CC0 1.0", "by/3.0": "CC BY 3.0", "by/4.0": "CC BY 4.0"}


def _fs_info():
    info = {}
    for d, rec in FS_DIRS:
        p = ORCH / rec
        if p.is_file():
            for k, v in json.loads(p.read_text()).items():
                info[(d, k)] = v
    return info


_INFO = None


def source(rel):
    """Metadata for a source path relative to ORCH, or a shipped cue 'shipped:<event>'."""
    global _INFO
    if rel.startswith("shipped:"):
        return None
    path = ORCH / rel
    for prefix, author, lic, page in PACKS:
        if rel.startswith(prefix):
            return {"path": path, "file": path.name, "title": path.stem, "author": author,
                    "license": lic, "license_url": LIC[lic], "page": page}
    if _INFO is None:
        _INFO = _fs_info()
    for d, _rec in FS_DIRS:
        if rel.startswith(d):
            fid = path.stem.split("_")[1]
            v = _INFO.get((d, fid))
            if not v:
                raise KeyError("no Freesound record for %s" % rel)
            lic = FS_LIC.get(v["license"].split("licenses/")[-1].strip("/"), v["license"])
            if lic not in LIC:
                raise ValueError("licence %s of %s is not on the accepted list" % (v["license"], rel))
            if v.get("genai_tag"):
                raise ValueError("%s carries the GenAI tag" % rel)
            title = v["title"].replace("Freesound - ", "")
            title = title.rsplit(" by ", 1)[0]
            return {"path": path, "file": path.name, "title": "%s (Freesound %s, HQ preview, 128 kbit MP3)" % (title, fid),
                    "author": v["user"].replace("%20", " "), "license": lic, "license_url": LIC[lic],
                    "page": v["page"], "fs_id": fid, "fs_title": title}
    raise KeyError("unknown source folder: %s" % rel)
