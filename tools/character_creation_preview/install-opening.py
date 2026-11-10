#!/usr/bin/env python3
"""Install the approved opening render without changing the six race cameras."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
INTRO = HERE / "intro"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify the installed image")
    args = parser.parse_args()
    png = (INTRO / "renders/intro.png").read_bytes()
    receipt = json.loads((INTRO / "renders/intro.json").read_text())
    build = json.loads((INTRO / "scene-build.json").read_text())["intro"]
    assert png[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    assert struct.unpack(">II", png[16:24]) == (1920, 1080), "unexpected image aspect"
    assert (receipt["width"], receipt["height"]) == (1920, 1080)
    assert hashlib.sha256(png).hexdigest() == receipt["output"], "render changed"
    assert receipt["input"] == build["render_input"], "render predates the scene build"
    recipe = json.loads((INTRO / "scene.json").read_text())
    recipe_bytes = json.dumps(recipe, sort_keys=True, separators=(",", ":")).encode()
    assert hashlib.sha256(recipe_bytes).hexdigest() == build["recipe"], "scene changed"
    for source, digest in build["sources"].items():
        if source == "authored_fortifications":
            continue
        assert hashlib.sha256((ROOT / source).read_bytes()).hexdigest() == digest, f"source changed: {source}"
    target = ROOT / "mods/PLAYER/grug_classes/textures/grug_creation_intro.png"
    if args.check:
        assert target.read_bytes() == png, "installed image differs from the approved render"
    else:
        target.write_bytes(png)
    print("Opening asset verified:", receipt["output"])


if __name__ == "__main__":
    main()
