#!/usr/bin/env python3
"""Probe media for the hood's headless shots (Round 56 lane HOOD; test only,
never shipped): per cloth and leather tier a 128x64 layer with only the hood
painted (tools/r54_armor/test_art's placeholder hood, swapped into the tier's
shipped palette, at the hood's atlas place), and the bald human skin.

  python3 tools/r56_hood/shots.py OUT_DIR

The scene (tools/r56_hood/scene.lua) lays each layer over the shipped head
layer of its tier, so the shots show the shipped helm (with its chin strip)
and the placeholder hood. Run the capture as
  MODELS=OUT_DIR SCENE=tools/r56_hood/scene.lua XVFB=... \\
      tools/r54_model/capture.sh SHOTS_DIR
(the probe serves the files of models/ as media) through the shared Lua queue.
"""
import json
import shutil
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools/r54_armor"))
import armorlib as L  # noqa: E402
from PIL import Image  # noqa: E402

ART = REPO / "tools/r54_art/art"            # the shipped tier palettes
TEST = REPO / "tools/r54_armor/test_art"    # the placeholder hood


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    atlas = json.loads((L.DATA / "atlas.json").read_text())
    x, y = atlas["parts"]["hood"]["rect"][:2]
    pals, _, _ = L.load_palettes(ART)
    tiers = json.loads((ART / "tiers.json").read_text())
    n = 0
    for line in ("cloth", "leather"):
        for tid in L.TIER_IDS:
            sheet = L.apply_palette(L.load_rgba(TEST / line / "hood_a.png"),
                                    L.palette_map(pals, tiers[line][tid]["palette"]))
            layer = Image.new("RGBA", tuple(atlas["size"]), (0, 0, 0, 0))
            layer.paste(sheet, (x, y))
            layer.save(out / f"r56hood_{line}_{tid}.png")
            n += 1
    shutil.copyfile(L.DATA / "skins" / "human_bald.png", out / "r56hood_human_bald.png")
    print(f"r56 hood shots: {n} hood layers and the bald skin in {out}")


if __name__ == "__main__":
    main()
