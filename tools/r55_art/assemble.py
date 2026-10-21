#!/usr/bin/env python3
"""The picked offhand art (Round 55 lane FINISH): repaint the art drop and
assemble the user's picks into art/, the art directory
tools/r55_offhand/bake.py ships.

  python3 tools/r55_art/assemble.py           rewrite art/ from src/ + picks.json
                                              (and the cloak copies in the game)
  python3 tools/r55_art/assemble.py --check   exit 1 when art/ or a cloak copy
                                              differs from what the painter and
                                              the picks give

src/<drop>/paint.py is the painter of the drop the user picked from, as
delivered (GPT-6 Astra, CC0), with its src/<drop>/inputs.json (the contract
snapshot it reads). It writes both proposals p1 and p2 next to its own src/
folder, so it runs on a copy in a temporary directory (nothing is written
into this folder but art/).

picks.json names per item and tier the proposal of the paint ("art") and of
the icon ("icon"), and the proposal of each cloak. Both proposals use the same
palette names with different colours, so the assembled palettes carry the
proposal as a prefix (p1_bronze, p2_book_iron, ...). Per item and tier:
  - the sheets the paint proposal's tiers.json entry names, with its palette;
  - the icon the icon proposal's entry names; when that proposal is not the
    paint's, `icon_palette` is the icon proposal's palette for the tier, so
    the icon shows exactly as on the pick page (offhand-format.md section 6).
cloak_<id>.png and wings_<id>.png come from the cloak's proposal; they are
also copied into the game as grug_achievements_cloak_<id>.png and
grug_achievements_cloak_<id>_wings.png (grug_achievements/textures). The drop's
notes.md is not art and stays out. art/tiers.json records the picks under
"_source". Two picks that would write different files under one name fail.
The check compares PNGs by mode, size and pixels (PNG bytes differ between
Pillow/zlib versions) and the JSON files by content.
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
ART = HERE / "art"
# The cloaks are not baked: the game takes them as they are (format doc section 6).
CLOAKS_OUT = HERE.parents[1] / "mods/PLAYER/grug_achievements/textures"
PICKS = HERE / "picks.json"
ITEMS = ("shield", "book")
TIER_IDS = ("T1", "T2", "T3", "T4", "T5", "T6")
BOOK_BOXES = ("cover_f", "cover_b", "pages_f", "pages_b", "spine", "ribbon")


def paint(drop):
    """Run the drop's painter on a copy; -> the temporary drop directory
    (the caller removes its parent)."""
    work = Path(tempfile.mkdtemp(prefix="r55_art."))
    out = work / drop
    shutil.copytree(SRC / drop, out / "src")
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    r = subprocess.run([sys.executable, "-B", str(out / "src" / "paint.py")],
                       cwd=work, env=env, capture_output=True, text=True)
    if r.returncode:
        shutil.rmtree(work)
        sys.exit(f"{SRC / drop / 'paint.py'}: exit {r.returncode}\n{r.stdout}{r.stderr}")
    return out


def sheet_files(item, variant):
    """The art paths (relative) a tier entry's variant names."""
    if item == "shield":
        return [f"shield/{variant}.png"]
    if isinstance(variant, str):
        variant = {box: variant for box in BOOK_BOXES}
    return [f"book/{box}_{variant.get(box, 'a')}.png" for box in BOOK_BOXES]


def assemble(drop_dir, picks):
    """-> ({relative path: bytes} of every art file, tiers.json, palettes.json)."""
    props = {}
    for prop in ("p1", "p2"):
        d = drop_dir / prop
        props[prop] = (d, json.loads((d / "tiers.json").read_text()),
                       json.loads((d / "palettes.json").read_text())["palettes"])
    files, tiers, palettes = {}, {}, {}

    def take(prop, rel):
        data = (props[prop][0] / rel).read_bytes()
        if files.get(rel, data) != data:
            sys.exit(f"{rel}: two picked proposals write different files under the same name")
        files[rel] = data

    def palette(prop, name):
        key = f"{prop}_{name}"
        palettes[key] = props[prop][2][name]
        return key

    for item in ITEMS:
        tiers[item] = {}
        for tid in TIER_IDS:
            pick = picks[item][tid]
            art, icon = pick["art"], pick["icon"]
            T, I = props[art][1][item][tid], props[icon][1][item][tid]
            entry = {"palette": palette(art, T["palette"]), "variant": T["variant"], "icon": I["icon"]}
            if icon != art:
                entry["icon_palette"] = palette(icon, I["palette"])
            tiers[item][tid] = entry
            for rel in sheet_files(item, T["variant"]):
                take(art, rel)
            take(icon, f"icons/{item}_{I['icon']}.png")
    for cid, prop in sorted(picks.get("cloak", {}).items()):
        for rel in (f"cloak_{cid}.png", f"wings_{cid}.png"):
            take(prop, rel)
    tiers["_source"] = picks
    return files, tiers, {"palettes": dict(sorted(palettes.items()))}


def dump(obj):
    return json.dumps(obj, indent=1, ensure_ascii=False) + "\n"


def pixels(data):
    im = Image.open(BytesIO(data))
    return im.mode, im.size, im.tobytes()


def cloak_copies(files):
    """{game path: art bytes} of the cloak textures the game takes as they are."""
    out = {}
    for rel, data in files.items():
        if rel.startswith("cloak_"):
            out[CLOAKS_OUT / ("grug_achievements_" + rel)] = data
        elif rel.startswith("wings_"):
            out[CLOAKS_OUT / ("grug_achievements_cloak_%s_wings.png" % rel[len("wings_"):-len(".png")])] = data
    return out


def check(files, tiers, palettes):
    problems = []
    for path, data in sorted(cloak_copies(files).items()):
        if not path.exists() or pixels(path.read_bytes()) != pixels(data):
            problems.append(f"{'differs' if path.exists() else 'missing'} {path.relative_to(HERE.parents[1])}")
    have = {p.relative_to(ART).as_posix() for p in ART.rglob("*") if p.is_file()} if ART.exists() else set()
    have -= {"tiers.json", "palettes.json"}
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
    if ART.exists():
        shutil.rmtree(ART)
    for rel, data in sorted(files.items()):
        (ART / rel).parent.mkdir(parents=True, exist_ok=True)
        (ART / rel).write_bytes(data)
    (ART / "tiers.json").write_text(dump(tiers))
    (ART / "palettes.json").write_text(dump(palettes))
    for path, data in cloak_copies(files).items():
        path.write_bytes(data)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare with art/ (and the cloak copies) instead of writing")
    a = ap.parse_args()
    picks = json.loads(PICKS.read_text())
    drop_dir = paint(picks["drop"])
    try:
        files, tiers, palettes = assemble(drop_dir, picks)
    finally:
        shutil.rmtree(drop_dir.parent)
    if a.check:
        problems = check(files, tiers, palettes)
        for p in problems:
            print("FAIL", p)
        print(f"r55 art check: {'FAIL' if problems else 'ok'} ({len(files)} PNG files + 2 JSON)")
        return 1 if problems else 0
    write(files, tiers, palettes)
    print(f"r55 art: {len(files)} PNG files + tiers.json, palettes.json -> {ART}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
