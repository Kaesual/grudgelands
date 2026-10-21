#!/usr/bin/env python3
"""The picked armor art (Round 54 lane INTEG): repaint the three art drops and
assemble the user's picks into art/, the art directory bake.py ships.

  python3 tools/r54_art/assemble.py           rewrite art/ from src/ + picks.json
  python3 tools/r54_art/assemble.py --check   exit 1 when art/ differs from what
                                              the painters and the picks give

src/<drop>/paint.py are the painters of the drops the user picked from, as
delivered (GPT-6 Astra, CC0): each writes both proposals p1 and p2 of its drop
next to its own src/ folder, so they run on copies in a temporary directory
(nothing is written into this folder but art/). picks.json names per line and
tier the drop and proposal the user picked (2026-10-20: whole tiers). A tier
copies every file its tiers.json entry names from that proposal (the drops
give each tier its own variant letter, a..f = T1..T6, so no names collide);
art/tiers.json gets the picked tier entries (and the picks under "_source"),
art/palettes.json the picked tiers' palettes.

The icons were redrawn in Round 55 (lane ICONS): src/icons-<drop>/paint.py
paint only icons (reading the picked tiers.json, passed as --art), and
picks.json's "icons" section names per line, slot and tier the icon drop and
proposal (2026-10-21). Each picked icon is laid over the tier's icon file
after the tier copy, under the same name; nothing else changes, and the icon
picks stay out of tiers.json. The check compares PNGs by mode, size and
pixels (PNG bytes differ between Pillow/zlib versions) and the JSON files by
content.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "r54_armor"
sys.path.insert(0, str(TOOL))
from PIL import Image  # noqa: E402

import armorlib as L  # noqa: E402

SRC = HERE / "src"
ART = HERE / "art"
PICKS = HERE / "picks.json"


def paint(work, pattern, *args):
    """Run the painters src/<pattern>/paint.py on copies under `work`;
    -> {drop: drop dir}."""
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    drops = {}
    for painter in sorted(SRC.glob(f"{pattern}/paint.py")):
        drop = work / painter.parent.name
        (drop / "src").mkdir(parents=True)
        shutil.copyfile(painter, drop / "src" / "paint.py")
        r = subprocess.run([sys.executable, str(drop / "src" / "paint.py"), *map(str, args)],
                           cwd=work, env=env, capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"{painter}: exit {r.returncode}\n{r.stdout}{r.stderr}")
        drops[painter.parent.name] = drop
    return drops


def assemble(drops, picks):
    """-> ({relative path: bytes} of every art file, tiers.json, palettes.json)."""
    cat = L.load_catalog()
    files, tiers, palettes = {}, {}, {"palettes": {}}
    for line in L.LINES:
        tiers[line] = {}
        for tid in L.TIER_IDS:
            pick = picks[line][tid]
            src = drops[pick["drop"]] / pick["prop"]
            pals, _, perr = L.load_palettes(src)
            got, _, terr = L.load_tiers(cat, pals, src)
            if perr or terr:
                sys.exit(f"{pick}: {perr + terr}")
            T = got[line][tid]
            tiers[line][tid] = T
            palettes["palettes"][T["palette"]] = pals["palettes"][T["palette"]]
            for _, _, _, path in L.expected_files(cat, src, line, T):
                rel = path.relative_to(src).as_posix()
                data = path.read_bytes()
                if files.get(rel, data) != data:
                    sys.exit(f"{rel}: two picked proposals write different files under the same name")
                files[rel] = data
    tiers["_source"] = {line: picks[line] for line in L.LINES}
    return files, tiers, palettes


def lay_icons(files, tiers, drops, picks):
    """Lay each picked icon over the tier's icon file (same name) in `files`."""
    for line in L.LINES:
        for slot, by_tier in picks[line].items():
            for tid in L.TIER_IDS:
                pick = by_tier[tid]
                rel = f"{line}/icons/{slot}_{tiers[line][tid]['icon'][slot]}.png"
                if rel not in files:
                    sys.exit(f"{line} {slot} {tid}: the picked tier has no icon {rel}")
                files[rel] = (drops[pick["drop"]] / pick["prop"] / rel).read_bytes()


def dump(obj):
    return json.dumps(obj, indent=1, ensure_ascii=False) + "\n"


def pixels(data):
    from io import BytesIO
    im = Image.open(BytesIO(data))
    return im.mode, im.size, im.tobytes()


def check(files, tiers, palettes):
    problems = []
    have = {p.relative_to(ART).as_posix() for p in ART.rglob("*.png")}
    for rel in sorted(set(files) | have):
        if rel not in have:
            problems.append(f"missing art/{rel}")
        elif rel not in files:
            problems.append(f"extra art/{rel} (no pick writes it)")
        elif pixels(files[rel]) != pixels((ART / rel).read_bytes()):
            problems.append(f"differs art/{rel}")
    for name, want in (("tiers.json", tiers), ("palettes.json", palettes)):
        path = ART / name
        if not path.exists() or json.loads(path.read_text()) != json.loads(dump(want)):
            problems.append(f"differs art/{name}")
    return problems


def write(files, tiers, palettes):
    for line in L.LINES:
        if (ART / line).exists():
            shutil.rmtree(ART / line)
    for rel, data in sorted(files.items()):
        (ART / rel).parent.mkdir(parents=True, exist_ok=True)
        (ART / rel).write_bytes(data)
    (ART / "tiers.json").write_text(dump(tiers))
    (ART / "palettes.json").write_text(dump(palettes))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare with art/ instead of writing it")
    a = ap.parse_args()
    picks = json.loads(PICKS.read_text())
    with tempfile.TemporaryDirectory(prefix="r54_art.") as tmp:
        work = Path(tmp)
        files, tiers, palettes = assemble(paint(work, "drop-*", "--tool", TOOL), picks)
        (work / "picked").mkdir()
        (work / "picked" / "tiers.json").write_text(dump(tiers))
        lay_icons(files, tiers, paint(work, "icons-*", "--art", work / "picked"), picks["icons"])
    if a.check:
        problems = check(files, tiers, palettes)
        for p in problems:
            print("FAIL", p)
        print(f"r54 art check: {'FAIL' if problems else 'ok'} ({len(files)} PNG files + 2 JSON)")
        return 1 if problems else 0
    write(files, tiers, palettes)
    print(f"r54 art: {len(files)} PNG files + tiers.json, palettes.json -> {ART}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
