#!/usr/bin/env python3
"""Original, deterministic 16px element animation; no image-generation input.

python3 -I tools/r52_art/arta/arta_fx.py --out /tmp/arta-rebuild
PNG strips contain only original pixels (CC0); weapon composites retain
their source licences. Identical existing outputs are accepted, never replaced.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
FAMILIES = ("fire", "frost", "holy", "rage", "wild", "shadow")
FRAMES = 8
ALPHA = (0, 96, 176, 255)
PULSE = (96, 176, 176, 255, 255, 176, 176, 96)
SWAY = (0, 0, 1, 1, 0, 0, -1, -1)
HEIGHT = (2, 3, 3, 2, 2, 1, 1, 2)
LOOPS = {"fire": (0.80, 0.96), "frost": (1.12, 0.96),
         "holy": (1.12, 0.96), "rage": (0.80, 0.96),
         "wild": (0.96, 1.12), "shadow": (1.12, 0.96)}
TITLES = {"fire": ("Twin tongues", "Ember crown"),
          "frost": ("Rime needles", "Crystal breath"),
          "holy": ("Golden motes", "Quiet radiance"),
          "rage": ("Crimson edge", "Red heartbeat"),
          "wild": ("Teal slipstream", "Leaf drift"),
          "shadow": ("Violet curl", "Silver smoke")}
WEAPONS = (
    ("Iron sword", "mods/ITEMS/grug_gear/textures/grug_gear_item_sword_iron.png", "CC-BY-SA-3.0"),
    ("Iron staff", "mods/ITEMS/grug_gear/textures/grug_gear_item_staff_iron.png", "CC-BY-SA-3.0"),
    ("Bow", "mods/PLAYER/grug_abilities/textures/grug_abilities_bow_draw_0.png", "CC-BY-SA-4.0"),
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise SystemExit(f"Refusing to overwrite {path}; use a new drop/output directory")
    else:
        path.write_bytes(data)


def encoded(im, fmt="PNG", **kw):
    buf = io.BytesIO()
    im.save(buf, format=fmt, **kw)
    return buf.getvalue()


def record(path, out, key, variant, **extra):
    data = path.read_bytes()
    with Image.open(path) as im:
        size, mode = list(im.size), im.mode
    return dict(key=key, variant=variant, path=path.relative_to(out).as_posix(),
                size=size, bytes=len(data), sha256=sha(data), mode=mode, **extra)


def frame(family, variant, phase):
    """All paths and pulses are cyclic; phase 8 is exactly phase 0.

    Pixels are authored directly in shared weapon UV space, not extracted
    from a weapon. Whole lower half stays transparent, including the grip.
    """
    phase %= FRAMES
    im = Image.new("RGBA", (16, 16))

    def px(x, y, rgb, alpha=176):
        if not (7 <= x <= 15 and 0 <= y <= 8):
            raise ValueError(f"Effect outside the authored tip region: {(x, y)}")
        assert alpha in ALPHA
        # Explicit overwrite keeps the alpha palette exact; no antialiasing.
        im.putpixel((x, y), (*rgb, alpha) if alpha else (0, 0, 0, 0))

    if family == "fire":
        roots = ((10, 6), (13, 4)) if variant == 1 else ((9, 7), (11, 5), (13, 3))
        for i, (x, y) in enumerate(roots):
            p = (phase + i*3) % 8
            h = min(HEIGHT[p], y)
            px(x, y, (190, 43, 24), 96)
            px(x+1, y, (246, 77, 24), 96)
            for step in range(1, h+1):
                bend = SWAY[p] if step == h else 0
                px(x+bend, y-step, (255, 133, 35), 176)
            px(x+SWAY[p], y-h, (255, 206, 92), 176)
        # A single ember rises, fades at both ends, then restarts invisibly.
        p = (phase+2) % 8
        if 1 <= p <= 6:
            px(14, 4-p//2, (255, 177, 56), 96 if p in (1, 6) else 176)

    elif family == "frost":
        blue, white = (105, 193, 232), (212, 245, 255)
        for i in range(6):
            px(8+i, 7-i, blue, 96)
        if variant == 1:
            for i, (x, y) in enumerate(((9, 5), (11, 3), (13, 1))):
                p = (phase+i*2) % 8
                px(x, y, white, PULSE[p])
                if p in (2, 3, 4, 5):
                    px(x-1, y, blue, 96)
        else:
            for i, (x, y) in enumerate(((10, 4), (12, 2))):
                px(x, y, white, PULSE[(phase+i*4) % 8])
                px(x-1, y, blue, 96)
                px(x, y-1, blue, 96)
            px(14, 2+SWAY[phase], white, 176)
        px(11+SWAY[phase], 1, white, 96)

    elif family == "holy":
        gold, white = (244, 185, 66), (255, 244, 194)
        for x, y in ((10, 5), (11, 4), (12, 3), (13, 2)):
            px(x, y, gold, 96)
        # Motes breathe on staggered phases; only one is fully bright at once.
        route = ((11, 1), (12, 1), (13, 1), (14, 2), (14, 3), (13, 4), (12, 4), (11, 3))
        for offset in (0, 3, 6):
            x, y = route[(phase+offset) % 8]
            px(x, y, white if offset == 0 else gold, 176 if offset == 0 else 96)
        if variant == 2:
            for x, y in ((11, 2), (12, 2), (12, 3)):
                px(x, y, gold, 96)
            px(13, 1, white, PULSE[phase])
            px(9, 5, white, PULSE[(phase+4) % 8])
        else:
            px(10, 4, white, PULSE[phase])

    elif family == "rage":
        crimson, ember = (191, 23, 52), (255, 84, 93)
        for i in range(6):
            p = (phase+(i if variant == 1 else 0)) % 8
            px(8+i, 7-i, crimson, 96 if PULSE[p] == 96 else 176)
            if variant == 2 and i >= 3:
                px(8+i, 6-i, (108, 15, 37), 96)
        for offset in (0, 4):
            p = (phase+offset) % 8
            i = p//2
            px(10+i, 5-i, ember, 96 if p in (0, 7) else 176)
        if variant == 2:
            px(13, 1, (255, 108, 108), PULSE[phase])
            px(14, 2, crimson, PULSE[(phase+1) % 8])

    elif family == "wild":
        teal, green = (63, 181, 165), (146, 201, 100)
        # A short streak travels just above the upper blade edge.
        for offset in (0, 4):
            p = (phase+offset) % 8
            x, y = 9+p//2, 5-p//2
            px(x, y, teal, 96 if p in (0, 7) else 176)
            px(x-1, y+1, teal, 96)
        p = (phase+2) % 8
        x, y = 12+SWAY[p], 2+SWAY[(p+2) % 8]
        px(x, y, green, 176)
        px(x+1, y, (73, 141, 87), 96)
        if variant == 2:
            x, y = 10+SWAY[(p+4) % 8], 4+SWAY[(p+6) % 8]
            px(x, y, (182, 212, 116), 176)
            px(x, y+1, (82, 150, 86), 96)

    elif family == "shadow":
        violet, dark, silver = (119, 85, 164), (37, 29, 57), (182, 190, 211)
        route = ((10, 5), (10, 4), (11, 3), (12, 2), (13, 2), (14, 3), (13, 4), (12, 4))
        for offset in range(5 if variant == 1 else 7):
            x, y = route[(phase-offset) % 8]
            px(x, y, violet if offset < 2 else dark, 176 if offset < 2 else 96)
            if offset < 3:
                px(x, y-1, dark, 96)
        px(12, 3, dark, 96)
        px(13, 1, silver, 96 if phase in (0, 1, 6, 7) else 176)
        if variant == 2:
            px(9, 6, violet, 96)
            px(10+SWAY[phase], 5, violet, 96)
    else:
        raise ValueError(family)
    return im


def checker():
    im = Image.new("RGBA", (16, 16))
    im.putdata([(38, 42, 51, 255) if (x//4+y//4) % 2 else (51, 56, 65, 255)
                for y in range(16) for x in range(16)])
    return im


def composited(effect, weapon=None, scale=8):
    im = checker()
    if weapon is not None:
        im = Image.alpha_composite(im, weapon)
    im = Image.alpha_composite(im, effect)
    return im.convert("RGB").resize((16*scale, 16*scale), Image.Resampling.NEAREST)


def animated_preview(family, variant, frames, weapons):
    previews = []
    for effect in frames:
        canvas = Image.new("RGB", (448, 196), (23, 26, 34))
        d = ImageDraw.Draw(canvas)
        d.text((12, 10), f"fx.{family} / v{variant} / 8 frames / {LOOPS[family][variant-1]:.2f} s", fill=(235, 235, 241))
        for i, weapon in enumerate(weapons):
            x = 12+i*148
            d.text((x, 32), WEAPONS[i][0], fill=(206, 210, 219))
            canvas.paste(composited(effect, weapon), (x, 52))
        previews.append(canvas)
    # One palette for the whole loop avoids frame-dependent colour shifts.
    atlas = Image.new("RGB", (448, 196*len(previews)))
    for i, im in enumerate(previews):
        atlas.paste(im, (0, i*196))
    palette = atlas.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in previews]


def preview_sheet(all_frames, weapons):
    sheet = Image.new("RGB", (1240, 1730), (20, 23, 31))
    d = ImageDraw.Draw(sheet)
    d.text((12, 12), "ARTA / DROP 01 - upper: weapon composites at 8x; lower: all eight frames at 4x", fill=(230, 233, 240))
    for row, family in enumerate(FAMILIES):
        for col, variant in enumerate((1, 2)):
            x, y = 12+col*616, 42+row*280
            frames = all_frames[(family, variant)]
            d.text((x, y), f"fx.{family} / v{variant} - {TITLES[family][variant-1]} - {LOOPS[family][variant-1]:.2f} s", fill=(238, 235, 226))
            for i, weapon in enumerate([*weapons, None]):
                xx = x+i*148
                d.text((xx, y+20), WEAPONS[i][0] if i < 3 else "Overlay only", fill=(189, 195, 209))
                sheet.paste(composited(frames[3], weapon), (xx, y+38))
            for i, effect in enumerate(frames):
                xx = x+i*74
                d.text((xx, y+176), str(i+1), fill=(189, 195, 209))
                sheet.paste(composited(effect, scale=4), (xx, y+192))
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=HERE / "drop-01")
    args = parser.parse_args()
    out = args.out.resolve()
    generator = dict(path="tools/r52_art/arta/arta_fx.py", sha256=sha(Path(__file__).read_bytes()))
    weapons = [Image.open(REPO/path).convert("RGBA") for _, path, _ in WEAPONS]
    refs = [dict(path=path, sha256=sha((REPO/path).read_bytes()), license=license)
            for _, path, license in WEAPONS]
    entries, all_frames = [], {}
    for family in FAMILIES:
        for variant in (1, 2):
            frames = [frame(family, variant, i) for i in range(FRAMES)]
            all_frames[(family, variant)] = frames
            strip = Image.new("RGBA", (16, 16*FRAMES))
            for i, im in enumerate(frames):
                strip.paste(im, (0, 16*i))
            path = out / "fx" / f"{family}_v{variant}.png"
            write_new(path, encoded(strip, optimize=True))
            common = dict(frames=FRAMES, loop_s=LOOPS[family][variant-1], generator=generator,
                          date="2026-10-19", title=TITLES[family][variant-1])
            entries.append(record(path, out, f"fx.{family}", variant, **common,
                                  author="GPT-6 Astra (Grudgelands)", license="CC0-1.0", role="overlay",
                                  alpha_levels=sorted(set(strip.getchannel("A").tobytes())),
                                  method="Original explicit pixel coordinates and cyclic eight-phase paths; Python/Pillow; no weapon pixels copied",
                                  animation="vertical_frames", frame_size=[16, 16]))
            gif_frames = animated_preview(family, variant, frames, weapons)
            path = path.with_suffix(".gif")
            duration = round(common["loop_s"]*1000/FRAMES)
            gif_data = encoded(gif_frames[0], "GIF", save_all=True,
                               append_images=gif_frames[1:], duration=duration,
                               loop=0, disposal=2, optimize=False)
            write_new(path, gif_data)
            with Image.open(io.BytesIO(gif_data)) as gif:
                encoded_frames = gif.n_frames
            entries.append(record(path, out, f"fx.{family}", variant, **common,
                                  gif_encoded_frames=encoded_frames,
                                  role="preview", author="GPT-6 Astra (composite); weapon authors credited in README.md",
                                  license="CC-BY-SA-4.0", sources=refs,
                                  method="RGBA overlay composited over three weapon sprites; nearest-neighbour 8x; fixed global GIF palette"))
    path = out / "preview-fx.png"
    write_new(path, encoded(preview_sheet(all_frames, weapons), optimize=True))
    entries.append(record(path, out, "preview.fx", 1, generator=generator, sources=refs,
                          role="preview", date="2026-10-19", license="CC-BY-SA-4.0",
                          author="GPT-6 Astra (composite); weapon authors credited in README.md",
                          method="12 variants: phase 4 over three weapons at 8x and all raw phases at 4x"))
    manifest_path = out / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    kept = [e for e in manifest.get("assets", []) if not (e["key"].startswith("fx.") or e["key"] == "preview.fx")]
    manifest.update(schema=1, date="2026-10-19", lane="ARTA", classification="compatible",
                    paths_relative_to="manifest directory", assets=kept+entries)
    manifest_path.write_text(json.dumps(manifest, indent=2)+"\n")
    print("Overlays: 12 RGBA strips, 12 looping GIFs, preview-fx.png; 8 frames each")


if __name__ == "__main__":
    main()
