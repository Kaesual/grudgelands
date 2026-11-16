#!/usr/bin/env python3
"""Render the quickbar's emote icons from the shipped player model (Round 80
lane EMOTE, round80-plan.md ruling 8, §4 EMOTE item 3).

One still per emote, the moment of the clip the user saw on the icon preview
page (the studies of 2026-11-16, framing A: the upper body), rendered from
mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d with the
repository's software renderer (tools/r55_offhand/render.py: the model
generator's parser and rig, Round 54's rasteriser) in the human's default
look (Round 54's skin, no armor, no cloak):

  * the camera looks from the front, a little from the character's left and
    above (direction (0.25, 0.1, 1)), 90 units away, at the chest;
  * a magenta key colour behind it becomes the transparent background (the
    2x supersampled coverage is the alpha, the colour the mean of the
    covered samples);
  * the figure's bounding box, its top 62 % (framing A), padded 6 % to a
    square and scaled to 64 px (the mounts' icon size in the same slots);
  * a dimmed copy `_off` (colour 15 %, brightness 55 %, alpha 80 %) for an
    emote greyed out while riding.

The frame of each still is the clip's first frame (grug_visuals.EMOTE_CLIPS
in apply.lua, held to the model by tools/r33_c3/gen_cloak_model.py --check)
plus the offset in FRAME below. Deterministic: no clock, no randomness.

    python3 tools/r80_emote/icons.py           # write the textures
    python3 tools/r80_emote/icons.py --check   # exit 1 if a texture differs

Writes mods/PLAYER/grug_quickbar/textures/grug_quickbar_emote_<id>.png and
grug_quickbar_emote_<id>_off.png. Python 3 with Pillow and numpy.
"""
import argparse
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools/r55_offhand"))
sys.path.insert(0, str(REPO / "tools/r33_c3"))

import numpy as np  # noqa: E402
from PIL import Image, ImageEnhance  # noqa: E402
import render as RD  # noqa: E402  (the model reader and the software renderer)
import gen_cloak_model as G  # noqa: E402  (registered_clips: EMOTE_CLIPS from apply.lua)

OUT = REPO / "mods/PLAYER/grug_quickbar/textures"
# Emote -> frames after the clip's first (the preview's moments): Wave's arm
# out at the side, Dance with one arm up, Cheer's V.
FRAME = {"wave": 15, "dance": 18, "cheer": 18}
KEY = (255, 0, 255)
DIRECTION = (0.25, 0.1, 1.0)
TARGET = (0.0, 20.0, 0.0)
DISTANCE = 90.0
RENDER = 320          # the render's side in pixels (before the supersampling)
UPPER = 0.62          # framing A: the top of the figure's bounding box
MARGIN = 0.06
SIZE = 64


def still(model, textures, frame):
    """The figure at `frame` on a transparent background, RENDER px square."""
    raw = RD.render_view(RD.triangles(model, frame, textures), DIRECTION, RENDER, RENDER,
                         TARGET, DISTANCE, bg=KEY, raw=True).astype(float)
    ss = raw.shape[0] // RENDER
    mask = ~np.all(np.abs(raw - KEY) < 0.6, axis=2)
    alpha = mask.reshape(RENDER, ss, RENDER, ss).mean(axis=(1, 3))
    rgb = (raw * mask[..., None]).reshape(RENDER, ss, RENDER, ss, 3).sum(axis=(1, 3))
    count = mask.reshape(RENDER, ss, RENDER, ss).sum(axis=(1, 3))[..., None]
    rgb = np.where(count > 0, rgb / np.maximum(count, 1), 0)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).clip(0, 255).astype(np.uint8), "RGBA")


def icon(img):
    left, top, right, bottom = img.getbbox()
    img = img.crop((left, top, right, top + int((bottom - top) * UPPER)))
    side = int(max(img.size) * (1 + 2 * MARGIN))
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return out.resize((SIZE, SIZE), Image.LANCZOS)


def dimmed(img):
    out = ImageEnhance.Brightness(ImageEnhance.Color(img).enhance(0.15)).enhance(0.55)
    out.putalpha(img.getchannel("A").point(lambda v: v * 0.8))
    return out


def build():
    """{file name: RGBA image} of every icon."""
    clips = G.registered_clips()["EMOTE_CLIPS"]
    if sorted(clips) != sorted(FRAME):
        raise SystemExit("icons: EMOTE_CLIPS has %s, FRAME %s" % (sorted(clips), sorted(FRAME)))
    model = RD.Model()
    textures = RD.Look(None, "human").textures()
    out = {}
    for emote in sorted(FRAME):
        ranges, _ = clips[emote]
        first = dict((base, x) for base, x, _ in ranges)["stand"]
        img = icon(still(model, textures, first + FRAME[emote]))
        out["grug_quickbar_emote_%s.png" % emote] = img
        out["grug_quickbar_emote_%s_off.png" % emote] = dimmed(img)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if a texture differs")
    args = parser.parse_args()
    icons = build()
    if args.check:
        stale = []
        for name, img in icons.items():
            path = OUT / name
            if not path.is_file() or Image.open(path).convert("RGBA").tobytes() != img.tobytes():
                stale.append(name)
        if stale:
            print("icons: stale or missing: %s; rerun tools/r80_emote/icons.py" % ", ".join(stale))
            return 1
        print("icons: %d textures current" % len(icons))
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for name, img in icons.items():
        img.save(OUT / name, optimize=True)
    print("icons: wrote %d textures to %s" % (len(icons), OUT.relative_to(REPO)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
