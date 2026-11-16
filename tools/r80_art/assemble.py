#!/usr/bin/env python3
"""The six donor cloaks (Round 80 lane REWARDS): repaint the art drop and copy
the user's picks into the game.

  python3 tools/r80_art/assemble.py           write the cloak and wing textures
                                              into grug_achievements/textures
  python3 tools/r80_art/assemble.py --check   exit 1 when a shipped texture is
                                              missing or differs from what the
                                              painters and the picks give

src/drop-01/paint.py and src/drop-02/paint.py are the two drops' painters as
delivered (GPT-6 Astra, CC0). Drop 02 refines Drop 01: it imports Drop 01's
painting helpers and reads two files Drop 01's painter writes (its
catalog.json and one cloak), so both run, in order, on a copy in a temporary
directory laid out as the drops were (<tmp>/drop-0n/src/paint.py); each
writes its art/ next to its src/. Nothing is written into this folder.

picks.json names the drop and, per cloak id, the painted art id; the cloak's
cloak_<art id>.png and wings_<art id>.png become
grug_achievements_cloak_<id>.png and grug_achievements_cloak_<id>_wings.png.
Every reward cloak has wings (the user's ruling of 2026-11-16): a pick
without them fails. The check compares PNGs by mode, size and pixels (PNG
bytes differ between Pillow/zlib versions).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from io import BytesIO
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image  # noqa: E402

HERE = Path(__file__).resolve().parent
SRC = HERE / "src"
OUT = HERE.parents[1] / "mods/PLAYER/grug_achievements/textures"
PICKS = HERE / "picks.json"
DROPS = ("drop-01", "drop-02")
SIZES = {"cloak": (32, 32), "wings": (16, 32)}


def paint(work):
    """Run both painters on copies in `work`; -> {drop: its art directory}."""
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", PYTHONHASHSEED="0")
    for drop in DROPS:
        shutil.copytree(SRC / drop, work / drop / "src")
        r = subprocess.run([sys.executable, "-B", str(work / drop / "src" / "paint.py")],
                           cwd=work, env=env, capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"{SRC / drop / 'paint.py'}: exit {r.returncode}\n{r.stdout}{r.stderr}")
    return {drop: work / drop / "art" for drop in DROPS}


def assemble(art, picks):
    """-> {game texture path: PNG bytes} of every picked cloak and its wings."""
    files = {}
    for cid, art_id in sorted(picks["cloak"].items()):
        for kind, name in (("cloak", f"grug_achievements_cloak_{cid}.png"),
                           ("wings", f"grug_achievements_cloak_{cid}_wings.png")):
            path = art[picks["drop"]] / f"{kind}_{art_id}.png"
            if not path.exists():
                sys.exit(f"{cid}: the drop has no {path.name}")
            data = path.read_bytes()
            im = Image.open(BytesIO(data))
            if im.mode != "RGBA" or im.size != SIZES[kind] or \
                    im.getchannel("A").getextrema() != (255, 255):
                sys.exit(f"{path.name}: not a fully opaque RGBA {SIZES[kind]} sheet")
            files[OUT / name] = data
    return files


def pixels(data):
    im = Image.open(BytesIO(data))
    return im.mode, im.size, im.tobytes()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare with the game's textures instead of writing")
    a = ap.parse_args()
    picks = json.loads(PICKS.read_text())
    work = Path(tempfile.mkdtemp(prefix="r80_art."))
    try:
        files = assemble(paint(work), picks)
    finally:
        shutil.rmtree(work)
    if a.check:
        problems = []
        for path, data in sorted(files.items()):
            if not path.exists():
                problems.append(f"missing {path.name}")
            elif pixels(path.read_bytes()) != pixels(data):
                problems.append(f"differs {path.name}")
        for p in problems:
            print("FAIL", p)
        print(f"r80 art check: {'FAIL' if problems else 'ok'} ({len(files)} textures)")
        return 1 if problems else 0
    for path, data in sorted(files.items()):
        path.write_bytes(data)
    print(f"r80 art: {len(files)} textures -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
