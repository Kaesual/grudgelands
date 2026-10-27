#!/usr/bin/env python3
"""Export the review-only map icon draft; never writes into mods/.

Illustrative originals come from built-in image_gen (one call per motif).
Simple navigation, punctuation and target symbols are editable SVG artwork.
ImageMagick performs only mechanical rasterization, cropping and resizing.
Approved 32px illustrations are canonical; full-resolution art is optional.
Usage: python3 tools/map_icon_rework/build.py [--check | --from-originals]
"""
from pathlib import Path
import json
import argparse
import hashlib
import subprocess
from PIL import Image

HERE = Path(__file__).resolve().parent
DROP = HERE / "drop01"
INK = "#251e23"


def svg(body, gradient):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
<defs><linearGradient id="paint" x1="0" y1="0" x2=".8" y2="1" gradientUnits="objectBoundingBox">
<stop stop-color="{gradient[0]}"/><stop offset=".48" stop-color="{gradient[1]}"/><stop offset="1" stop-color="{gradient[2]}"/>
</linearGradient></defs>{body}</svg>'''


def raster(key, source):
    path = DROP / "svg" / f"{key}.svg"
    path.write_text(source)
    subprocess.run(["magick", "-background", "none", "-density", "384",
                    str(path), "-resize", "32x32", "-strip",
                    str(DROP / "icons" / f"{key}.png")], check=True)


def geometry():
    gold = ("#fff1bd", "#efbd55", "#a46427")
    cyan = ("#dcffff", "#64d8dd", "#277a9b")
    silver = ("#f5f4ed", "#b5c1c8", "#6d7c8e")
    grey = ("#c8c5c4", "#918d96", "#66616e")
    for kind, palette in (("heading_gold", gold), ("heading_cyan", cyan), ("rim_cyan", cyan)):
        for index in range(16):
            if kind == "rim_cyan":
                body = f'<path d="M7 20 L16 10 L25 20 L21 24 L16 18 L11 24 Z" fill="url(#paint)" stroke="{INK}" stroke-width="1.2" stroke-linejoin="round"/>'
            else:
                body = f'<path d="M16 3.5 L25 26.5 L16 22 L7 26.5 Z" fill="url(#paint)" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/><path d="M16 6 L16 21.8 L9 24 Z" fill="#fff5d3" opacity=".35"/>'
            # Headings follow engine yaw counterclockwise; rim bearings use
            # clockwise screen-space angles (minimap_view.lua V.rim).
            angle = index * 22.5 * (1 if kind == "rim_cyan" else -1)
            raster(f"{kind}_{index:02}", svg(f'<g transform="rotate({angle} 16 16)">{body}</g>', palette))
    # Broad filled punctuation; the contour follows the glyph, never a badge.
    question = "M10 10 C10 3 24 3 24 11 C24 15 18.5 16 18.5 20 L13.5 20 C13.5 13.5 19 13.5 19 10.5 C19 7.5 15 7.5 15 10.5 Z"
    exclamation = "M12 4.5 L21 4.5 L19.2 20 L13.8 20 Z"
    for story in (False, True):
        for status, palette in (("available", gold), ("ready", gold), ("active", silver), ("locked", grey)):
            path = question if status in ("ready", "active") else exclamation
            glyph = f'<path d="{path}" fill="url(#paint)" stroke="{INK}" stroke-width="1.25" stroke-linejoin="round"/><rect x="13.5" y="23" width="5.5" height="5.5" rx="1.2" fill="url(#paint)" stroke="{INK}" stroke-width="1.25"/>'
            if story:
                glyph += f'<path d="M6.5 3 L8 6.5 L11.5 8 L8 9.5 L6.5 13 L5 9.5 L1.5 8 L5 6.5 Z" fill="#c9a3ff" stroke="{INK}" stroke-width="1.1" stroke-linejoin="round"/><path d="M6.5 5 L6.5 10.5 L5.5 8 Z" fill="#f2dfff"/>'
            raster("quest_" + ("story_" if story else "") + status, svg(glyph, palette))
    brackets = "M11 4 H4 V11 M21 4 H28 V11 M28 21 V28 H21 M11 28 H4 V21"
    cross = f'<path d="{brackets}" fill="none" stroke="{INK}" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/><path d="{brackets}" fill="none" stroke="#ffca75" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M16 12 L20 16 L16 20 L12 16 Z" fill="#ed9d41" stroke="{INK}" stroke-width="1.1"/>'
    raster("crosshair", svg(cross, gold))
    # This outline is an actual quest area, not a frame behind a marker.
    ring = '<circle cx="16" cy="16" r="12.5" fill="none" stroke="#342620" stroke-width="2.6"/><circle cx="16" cy="16" r="12.5" fill="none" stroke="#ffbb60" stroke-width="1.3"/>'
    raster("ring", svg(ring, gold))


def illustrations():
    manifest = DROP / "generated.json"
    if not manifest.exists():
        return []
    rows = json.loads(manifest.read_text())
    for row in rows:
        source = HERE / "local-originals" / "sources" / (row["key"] + ".png")
        if not source.is_file():
            raise FileNotFoundError(f"Optional original unavailable: {source}")
        with Image.open(source) as image:
            assert image.mode == "RGBA", (source, image.mode)
            alpha = image.getchannel("A")
            assert alpha.getextrema()[0] == 0, f"No transparent background: {source}"
            # Ignore nearly invisible generated edge dust when measuring bounds.
            # The original alpha inside these bounds is preserved, not thresholded.
            bounds = alpha.point(lambda a: 255 if a >= 8 else 0).getbbox()
            assert bounds, source
            x0, y0, x1, y1 = bounds
        target = DROP / "icons" / (row["key"] + ".png")
        # The mug needs less visual weight: 24 instead of 28 pixels is ~15%
        # smaller, while its shared transparent canvas stays 32 by 32.
        extent = 24 if row["key"] == "innkeeper" else 28
        subprocess.run(["magick", str(source), "-crop", f"{x1-x0}x{y1-y0}+{x0}+{y0}",
                        "+repage", "-filter", "Lanczos", "-resize", f"{extent}x{extent}",
                        "-gravity", "center", "-background", "none", "-extent", "32x32",
                        "-strip", str(target)], check=True)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Verify accepted PNGs without writing")
    mode.add_argument("--from-originals", action="store_true",
                      help="Re-export illustrations from the optional local archive")
    args = parser.parse_args()
    if not args.check:
        if args.from_originals:
            illustrations()
        geometry()
    approved = json.loads((DROP / "approved-icons.json").read_text())
    paths = sorted((DROP / "icons").glob("*.png"))
    assert {p.name for p in paths} == set(approved), "Approved icon inventory differs"
    for path in paths:
        assert hashlib.sha256(path.read_bytes()).hexdigest() == approved[path.name], path
        with Image.open(path) as image:
            assert image.size == (32, 32), path
            alpha = image.convert("RGBA").getchannel("A")
            assert alpha.getextrema() == (0, 255), (path, alpha.getextrema())
    print(f"Verified {len(paths)} approved 32x32 PNGs, including alpha and exact hashes.")


if __name__ == "__main__":
    main()
