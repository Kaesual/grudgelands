"""Round 58 lane CONSUME: the picked guild art of drop 01, rebuilt and shipped.

paint.py is the drop's own painter (GPT-6 Astra, CC0-1.0, copied unchanged
from the guild-art drop 01): every texel by hand, no source images. This
script paints both proposals into a temporary folder and copies the user's
picks (2026-10-23) to their game names:
  P2 consumable icons  -> mods/PLAYER/grug_guild/textures/grug_guild_<kind>_t<n>.png
  P2 status icons      -> mods/CORE/grug_core/textures/grug_status_<kind>.png
  P1 Remains overlay   -> mods/PLAYER/grug_guild/textures/grug_guild_miners_remains_overlay.png
(The P1 cloaks of the same drop ship with lane REP.)

  python3 tools/r58_consume/art/ship.py           # write the textures
  python3 tools/r58_consume/art/ship.py --check   # compare pixels, write nothing
"""
import sys
import tempfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
import paint  # noqa: E402

PICKS = []
for kind in ("ore_sense", "treasure_hunt"):
    for tier in range(1, 7):
        PICKS.append((2, f"{kind}_t{tier}.png", f"mods/PLAYER/grug_guild/textures/grug_guild_{kind}_t{tier}.png"))
    PICKS.append((2, f"status_{kind}.png", f"mods/CORE/grug_core/textures/grug_status_{kind}.png"))
PICKS.append((1, "miners_remains_overlay.png", "mods/PLAYER/grug_guild/textures/grug_guild_miners_remains_overlay.png"))


def main():
    check = "--check" in sys.argv[1:]
    with tempfile.TemporaryDirectory() as tmp:
        paint.ROOT = Path(tmp)
        paint.main()
        bad = 0
        for proposal, source, target in PICKS:
            painted = Image.open(Path(tmp) / f"p{proposal}" / source).convert("RGBA")
            path = REPO / target
            if check:
                same = path.exists() and Image.open(path).convert("RGBA").tobytes() == painted.tobytes() \
                    and Image.open(path).size == painted.size
                if not same:
                    bad += 1
                    print("DIFFERS", target)
            else:
                painted.save(path, optimize=True)
        print(f"{len(PICKS)} textures {'checked' if check else 'written'}, {bad} differ")
        return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
