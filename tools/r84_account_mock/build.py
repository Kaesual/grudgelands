#!/usr/bin/env python3
"""Build the offline pick page and every PNG. Run with Python 3.10+ and Pillow."""
import argparse
import base64
from io import BytesIO
import json
from pathlib import Path

from PIL import ImageChops

from drawing import Drawing, EXAMPLE, Fonts, HERE
from layouts import LAYOUTS, STATES, charter, village


def font_directory():
    roots = (HERE.parents[1] / "reference_projects/luanti/fonts",
             Path("/usr/share/luanti/fonts"), Path("/usr/share/minetest/fonts"),
             Path("/var/lib/flatpak/app/org.luanti.luanti/current/active/files/share/luanti/fonts"))
    return next((p for p in roots if (p / "Arimo-Regular.ttf").is_file()), None)


def inline_pixels(image):
    buffer = BytesIO()
    image.save(buffer, "WEBP", lossless=True, method=3)
    return "data:image/webp;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def build(directory):
    fonts = Fonts(directory)
    package = {"layouts": LAYOUTS, "states": {k: [s.title, s.note] for k, s in STATES.items()},
               "example": EXAMPLE, "views": {}, "bases": {}}
    (HERE / "renders").mkdir(exist_ok=True)
    for name, layout in (("charter", charter), ("village", village)):
        base = None
        for key, state in STATES.items():
            d = Drawing(fonts)
            layout(d, state)
            picture = d.image.convert("RGB")
            picture.save(HERE / "renders" / f"{name}-{key}.png")
            # The identical navigation and art pixels travel once per layout. Store
            # subsequent states as a lossless overlay of only their changed pixels.
            if base is None:
                base = picture
                package["bases"][name] = inline_pixels(base)
                patch = None
            else:
                delta = ImageChops.difference(picture, base)
                bounds = delta.getbbox()
                patch = None
                if bounds:
                    replacement = picture.crop(bounds).convert("RGBA")
                    channels = delta.crop(bounds).split()
                    mask = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
                    replacement.putalpha(mask.point(lambda v: 255 if v else 0))
                    patch = [*bounds, inline_pixels(replacement)]
            package["views"][name+"-"+key] = dict(patch=patch, elements=d.elements, actions=d.actions,
                                                  status=d.status, error=state.error)
    payload = json.dumps(package, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c")
    template = (HERE / "review.html.in").read_text()
    (HERE / "index.html").write_text(template.replace("__ACCOUNT_VIEWS__", payload))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fonts", type=Path, default=font_directory(),
                        help="directory containing Luanti's Arimo-Regular.ttf and Arimo-Bold.ttf")
    args = parser.parse_args()
    if args.fonts is None:
        parser.error("Pass --fonts pointing to the Arimo fonts from a Luanti installation.")
    build(args.fonts)
