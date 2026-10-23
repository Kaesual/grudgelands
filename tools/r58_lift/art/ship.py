"""Round 58 lane LIFT: the picked guild art of drop 02, shipped as byte copies.

The user's picks of 2026-10-23 (guild-art/pick/picks.md): everything of drop
02 but the banners from proposal P1, by GPT-6 Astra, CC0-1.0, painted by the
drop's own script (no source images). The banners and emblems are lane
HALLS2's. picks.txt lists each file with its SHA-256 and its game path:
  the lift's six faces  -> mods/MAPGEN/grug_mapgen/textures/grug_mapgen_guild_lift_<face>.png
  the reputation icon   -> mods/PLAYER/grug_guild/textures/grug_guild_reputation.png
  the two map icons     -> mods/PLAYER/grug_map/textures/grug_map_<kind>.png
No painter copy: the files are copied unchanged and checked by hash (the
fixture tools/r58_lift/portable_test.lua checks the same hashes).

  python3 tools/r58_lift/art/ship.py --from DROP_02_P1_DIR   # copy, then check
  python3 tools/r58_lift/art/ship.py --check                 # check, write nothing
"""
import hashlib
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]


def picks():
    rows = []
    for line in (HERE / "picks.txt").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            digest, source, target = line.split()
            rows.append((digest, source, target))
    return rows


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(argv):
    rows = picks()
    if "--from" in argv:
        source_dir = Path(argv[argv.index("--from") + 1])
        for digest, source, target in rows:
            src = source_dir / source
            if sha256(src) != digest:
                print("NOT THE PICK", src)
                return 1
            shutil.copyfile(src, REPO / target)
    elif "--check" not in argv:
        print(__doc__)
        return 2
    bad = 0
    for digest, _, target in rows:
        path = REPO / target
        if not path.exists() or sha256(path) != digest:
            bad += 1
            print("DIFFERS", target)
    print(f"{len(rows)} textures checked, {bad} differ")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
