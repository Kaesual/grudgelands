#!/usr/bin/env python3
"""The picked Miner's Guild cloaks (Round 58 lane REP): repaint the guild art
drop and copy the user's pick into the game.

  python3 tools/r58_rep/cloaks.py           write the four textures
  python3 tools/r58_rep/cloaks.py --check   exit 1 when a shipped texture
                                            differs from what the painter gives

src/drop-01/paint.py is the painter of the drop the user picked from, as
delivered (GPT-6 Astra, CC0; src/drop-01/LICENSE.txt). It writes both
proposals p1 and p2 next to its own src/ folder, so it runs on a copy in a
temporary directory. The pick (guild-art picks of 2026-10-23): the cloaks of
proposal p1, ranks 3, 6 and 10, rank 10 with its wings. They go into
mods/PLAYER/grug_achievements/textures under the mod's names
(grug_achievements_cloak_<id>.png, grug_achievements_cloak_<id>_wings.png;
the cloak ids miners_guild_1 .. _3 are the achievement's tiers, catalog.lua).
The check compares PNGs by mode, size and pixels (PNG bytes differ between
Pillow/zlib versions).
"""
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image  # noqa: E402

HERE = Path(__file__).resolve().parent
PAINTER = HERE / "src/drop-01/paint.py"
OUT = HERE.parents[1] / "mods/PLAYER/grug_achievements/textures"
PROPOSAL = "p1"
# drop file -> shipped file
PICKS = {
    "cloak_guild_3.png": "grug_achievements_cloak_miners_guild_1.png",
    "cloak_guild_6.png": "grug_achievements_cloak_miners_guild_2.png",
    "cloak_guild_10.png": "grug_achievements_cloak_miners_guild_3.png",
    "wings_guild_10.png": "grug_achievements_cloak_miners_guild_3_wings.png",
}


def paint(tmp):
    """Run the painter on a copy in `tmp`; -> the proposal's directory."""
    src = Path(tmp) / "drop/src"
    src.mkdir(parents=True)
    shutil.copy2(PAINTER, src / "paint.py")
    subprocess.run([sys.executable, "-I", "-B", str(src / "paint.py")], check=True,
                   cwd=tmp)
    return Path(tmp) / "drop" / PROPOSAL


def same(a, b):
    with Image.open(a) as x, Image.open(b) as y:
        return x.mode == y.mode and x.size == y.size and x.tobytes() == y.tobytes()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="compare, write nothing")
    args = ap.parse_args()
    problems = 0
    with tempfile.TemporaryDirectory(prefix="r58rep-cloaks-") as tmp:
        drop = paint(tmp)
        for name, shipped in PICKS.items():
            source, target = drop / name, OUT / shipped
            if args.check:
                if not target.exists() or not same(source, target):
                    print("DIFFERS %s (from %s/%s)" % (target, PROPOSAL, name))
                    problems += 1
            else:
                shutil.copyfile(source, target)
                print("wrote %s" % target)
    if args.check:
        print("cloaks: %d of %d differ" % (problems, len(PICKS)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
