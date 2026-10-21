#!/usr/bin/env python3
"""The six spellbook icons, one per tier (Round 55 lane GAME,
docs/technical/offhand-format.md section 7).

Until Round 55 the six spellbooks shared `grug_gear_spellbook.png`, tinted
per bracket at registration with `[colorize:<grug_gear.BRACKET_TINT[n]>:48`.
They are now registered with one file per tier,
`grug_gear_spellbook_<grade>.png` with its mask `..._ench.png`, so the finish
step can drop in painted icons (tools/r55_offhand/bake.py). Until then this
script writes those twelve files so that they show exactly today's look:

  * the icon: the shared image with the tier's tint baked in by the engine's
    own `[colorize:color:ratio` (reference_projects/luanti,
    src/client/imagesource.cpp apply_colorize with a numeric ratio: every
    pixel with alpha > 0 becomes color.getInterpolated(pixel, ratio / 255.0f),
    irr/include/SColor.h; each channel round32(pixel * (1 - d) + color * d)
    in single precision, round32(x) = floorf(x + 0.5f), irrMath.h), every
    other pixel unchanged;
  * the mask: the shared mask, copied byte for byte (the tint moves no
    pixel, so the zones stay where they are).

    python3 tools/r55_game/book_icons.py            # write the twelve files
    python3 tools/r55_game/book_icons.py --check    # exit 1 if any differs
    python3 tools/r55_game/book_icons.py --selftest # the colorize model against
        a scalar IEEE single-precision emulation of the engine's arithmetic

The tints and grades are read from grug_gear/init.lua (BRACKET_TINT and
MATERIALS) and the ratio from the old registration string, which the script
keeps in RATIO; nothing else holds a copy. The files inherit the licence of
the shared book (grug_gear/LICENSE-media.md).
"""
import argparse
import io
import re
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GEAR = ROOT / "mods/ITEMS/grug_gear"
TEXTURES = GEAR / "textures"
SOURCE = "grug_gear_spellbook.png"
SOURCE_MASK = "grug_gear_spellbook_ench.png"
# The ratio of the registration before Round 55:
# `BOOK_IMAGE .. "^[colorize:" .. BRACKET_TINT[bracket] .. ":48"`.
RATIO = 48


def tints_and_grades():
    text = (GEAR / "init.lua").read_text()
    block = re.search(r"\ngrug_gear\.BRACKET_TINT = \{(.*?)\}", text, re.S)
    tints = re.findall(r'"#([0-9a-fA-F]{6})"', block.group(1))
    materials = re.search(r"\ngrug_gear\.MATERIALS = \{\n(.*?)\n\}\n", text, re.S)
    grades = re.findall(r'\bmetal = \{key = "([a-z0-9_]+)"', materials.group(1))
    assert len(tints) == 6 and len(grades) == 6, (tints, grades)
    return [tuple(int(t[i:i + 2], 16) for i in (0, 2, 4)) for t in tints], grades


def colorize(rgba, color, ratio):
    """[colorize:#rrggbb:ratio on an RGBA uint8 array, in single precision."""
    f32 = np.float32
    d = f32(ratio) / f32(255.0)
    d = min(max(d, f32(0.0)), f32(1.0))
    inv = f32(1.0) - d
    src = rgba.astype(np.float32)
    target = np.array(color + (255,), dtype=np.float32)
    mixed = np.floor(src * inv + target * d + f32(0.5)).astype(np.uint8)
    out = rgba.copy()
    lit = rgba[..., 3] > 0
    out[lit] = mixed[lit]
    return out


def f32(x):
    return struct.unpack("f", struct.pack("f", x))[0]


def colorize_scalar(value, target, ratio):
    """One channel, every step rounded to single precision as the engine does."""
    d = f32(f32(float(ratio)) / f32(255.0))
    inv = f32(1.0 - d)
    a = f32(float(value) * inv)
    b = f32(float(target) * d)
    s = f32(a + b)
    return int(f32(s + 0.5) // 1)


def selftest():
    tints, _ = tints_and_grades()
    targets = sorted({c for tint in tints for c in tint} | {0, 255})
    values = np.arange(256, dtype=np.uint8)
    failures = 0
    for target in targets:
        for ratio in (RATIO, 0, 1, 127, 128, 254):
            rgba = np.zeros((256, 1, 4), dtype=np.uint8)
            rgba[:, 0, 0] = values
            rgba[:, 0, 3] = 255
            got = colorize(rgba, (target, 0, 0), ratio)[:, 0, 0]
            want = [colorize_scalar(v, target, ratio) for v in range(256)]
            failures += int(np.sum(got != np.array(want, dtype=np.uint8)))
    # Alpha 0 stays untouched; an opaque pixel stays opaque.
    probe = np.array([[[10, 20, 30, 0], [10, 20, 30, 255]]], dtype=np.uint8)
    out = colorize(probe, (200, 100, 50), RATIO)
    failures += int(not np.array_equal(out[0, 0], probe[0, 0]))
    failures += int(out[0, 1, 3] != 255)
    print("BOOK ICONS SELFTEST %s (%d channel values x %d targets x 6 ratios)" % (
        "PASS" if failures == 0 else "FAIL %d" % failures, 256, len(targets)))
    return failures == 0


def build():
    """{file name: (kind, payload)}: the icons as RGBA arrays, the masks as bytes."""
    tints, grades = tints_and_grades()
    source = np.array(Image.open(TEXTURES / SOURCE).convert("RGBA"))
    mask = (TEXTURES / SOURCE_MASK).read_bytes()
    out = {}
    for tint, grade in zip(tints, grades):
        stem = "grug_gear_spellbook_%s" % grade
        out[stem + ".png"] = ("icon", colorize(source, tint, RATIO))
        out[stem + "_ench.png"] = ("mask", mask)
    return out


def png_bytes(rgba):
    buffer = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        return 0 if selftest() else 1
    failures = []
    for name, (kind, payload) in sorted(build().items()):
        path = TEXTURES / name
        if args.check:
            if not path.exists():
                failures.append(name + ": missing")
            elif kind == "mask" and path.read_bytes() != payload:
                failures.append(name + ": not the shared mask")
            elif kind == "icon" and not np.array_equal(
                    np.array(Image.open(path).convert("RGBA")), payload):
                failures.append(name + ": pixels differ from the tinted book")
            continue
        data = payload if kind == "mask" else png_bytes(payload)
        if not path.exists() or path.read_bytes() != data:
            path.write_bytes(data)
    for line in failures:
        print("FAIL " + line)
    if failures:
        print("BOOK ICONS FAIL %d of 12" % len(failures))
        return 1
    print("BOOK ICONS %s files=12" % ("PASS" if args.check else "WROTE"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
