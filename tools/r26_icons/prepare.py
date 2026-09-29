#!/usr/bin/env python3
"""Export generated originals, frames, hashes and a 64/32px contact sheet.

Requires Pillow. No generation API or network is called. The exact built-in
image_gen prompts and original local output paths are in manifest.json.
AI generation is not deterministic; retain originals at those paths for exact
export reproduction. Run `python3 tools/r26_icons/prepare.py` to rebuild from
originals, or append --check to validate the committed textures without them.
"""
import argparse
from collections import Counter, deque
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont, __version__ as PILLOW_VERSION
sys.dont_write_bytecode = True
from frames import COLORS, make_frame, main as write_frames

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "manifest.json"
PLATE = (21, 31, 45, 255)
STATUS_IDS = """food elixir_vigor elixir_focus elixir_precision elixir_stoneskin
elixir_deepwater alchemy_swiftness alchemy_cave mount_land mount_flight shield
move_immune talent_unbroken talent_ruination talent_whitehot talent_turn_aside
talent_last_word talent_untouchable poisoned slowed rooted stunned scorched
in_combat pvp_tagged pvp_contested warding_draught""".split()
CLASS_IDS = ["warrior", "mage", "priest", "scout"]
DEBUFFS = {"poisoned", "slowed", "rooted", "stunned", "scorched"}
NEUTRALS = {"in_combat", "pvp_tagged", "pvp_contested"}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize_plate(image):
    """Unify only border-connected near-background pixels, preserving dark art.

    The most frequent outer-edge color estimates the generated plate. A flood
    fill reaches only pixels within 24 RGB levels (max channel distance) of it.
    Distance <=12 becomes the sampled plate; 12..24 blends smoothly into art.
    Enclosed dark detail is untouched. This removes tiny background variation
    without tinting the motif or drawing a frame.
    """
    pixels = image.load()
    size = image.width
    border = [(x, y) for x in range(size) for y in range(size)
              if x in (0, size - 1) or y in (0, size - 1)]
    base = Counter(pixels[x, y][:3] for x, y in border).most_common(1)[0][0]
    seen = set(border)
    pending = deque(border)
    while pending:
        x, y = pending.popleft()
        color = pixels[x, y]
        distance = max(abs(color[i] - base[i]) for i in range(3))
        if distance > 24:
            continue
        amount = min(1.0, max(0.0, (distance - 12) / 12))
        pixels[x, y] = tuple(round(PLATE[i] * (1 - amount) + color[i] * amount)
                             for i in range(3)) + (255,)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < size and 0 <= ny < size and (nx, ny) not in seen:
                seen.add((nx, ny))
                pending.append((nx, ny))
    return image


def export_icon(asset):
    source = Path(asset["source"])
    image = Image.open(source).convert("RGBA")
    if image.width != image.height:
        raise ValueError(f"Non-square source for {asset['id']}")
    image = normalize_plate(image.resize((56, 56), Image.Resampling.LANCZOS))
    plate = Image.new("RGBA", (64, 64), PLATE)
    plate.alpha_composite(image, (4, 4))
    target = ROOT / asset["path"]
    target.parent.mkdir(parents=True, exist_ok=True)
    plate.save(target, optimize=True)
    asset["source_sha256"] = sha256(source)
    asset["sha256"] = sha256(target)
    asset["bytes"] = target.stat().st_size


def checker(size):
    image = Image.new("RGBA", (size, size), (47, 53, 61, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size, 8):
        for x in range(0, size, 8):
            if (x // 8 + y // 8) % 2:
                draw.rectangle((x, y, x + 7, y + 7), fill=(67, 74, 84, 255))
    return image


def contact_sheet(assets):
    columns, cell_w, cell_h = 6, 184, 112
    rows = (len(assets) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cell_w + 32, rows * cell_h + 92), "#101722")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=12)
    title = ImageFont.load_default(size=20)
    draw.text((16, 12), "GRUDGELANDS / STATUS & CLASS ICONS", fill="#eef2fa", font=title)
    draw.text((16, 40), "64 px + 32 px | green: buff | red: debuff | gold: neutral | classes: no frame",
              fill="#b2bfd1", font=font)
    for index, asset in enumerate(assets):
        x, y = 16 + index % columns * cell_w, 72 + index // columns * cell_h
        icon = Image.open(ROOT / asset["path"]).convert("RGBA")
        if asset["kind"] == "status":
            icon = Image.alpha_composite(icon, make_frame(asset["frame"]))
        elif asset["kind"] == "frame":
            icon = Image.alpha_composite(checker(64), icon)
        sheet.paste(icon.convert("RGB"), (x, y))
        small = icon.resize((32, 32), Image.Resampling.LANCZOS)
        sheet.paste(small.convert("RGB"), (x + 80, y + 16))
        label = ("class_" if asset["kind"] == "class" else "") + asset["id"]
        draw.text((x, y + 72), label, fill="#edf2f7", font=font)
    sheet.save(HERE / "contact_sheet.png", optimize=True)


def validate(manifest):
    assets = manifest["assets"]
    expected = ({f"mods/CORE/grug_core/textures/grug_status_{i}.png" for i in STATUS_IDS}
                | {f"mods/PLAYER/grug_classes/textures/grug_class_{i}.png" for i in CLASS_IDS}
                | {f"mods/CORE/grug_core/textures/grug_status_frame_{i}.png" for i in COLORS})
    actual = {a["path"] for a in assets}
    assert len(assets) == 34 and actual == expected, (len(assets), actual ^ expected)
    for asset in assets:
        path = ROOT / asset["path"]
        image = Image.open(path)
        assert image.size == (64, 64) and image.mode == "RGBA", path
        assert path.stat().st_size < 20_000, path
        assert sha256(path) == asset["sha256"], path
        if asset["kind"] == "frame":
            category = asset["id"].removeprefix("frame_")
            assert image.tobytes() == make_frame(category).tobytes(), path
        else:
            assert image.getchannel("A").getextrema() == (255, 255), path
            for x in range(64):
                for y in range(64):
                    if min(x, y, 63 - x, 63 - y) < 4:
                        assert image.getpixel((x, y)) == PLATE, (path, x, y)
            if asset["kind"] == "status":
                category = ("debuff" if asset["id"] in DEBUFFS else
                            "neutral" if asset["id"] in NEUTRALS else "buff")
                assert asset["frame"] == category, path
            else:
                assert asset["frame"] is None, path
    assert sha256(HERE / "contact_sheet.png") == manifest["contact_sheet"]["sha256"]
    print(f"PASS: 27 status + 3 frames + 4 class = {len(assets)} textures; "
          "64x64 RGBA, hashes, <20KB, opaque plates/transparent frames, frame mapping.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate without reading originals or writing files")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    if args.check:
        validate(manifest)
        return
    assets = [a for a in manifest["assets"] if a["kind"] != "frame"]
    for asset in assets:
        export_icon(asset)
    write_frames()
    for category, color in COLORS.items():
        file = f"grug_status_frame_{category}.png"
        path = f"mods/CORE/grug_core/textures/{file}"
        assets.append({"id": f"frame_{category}", "file": file, "path": path,
                       "kind": "frame", "source": "tools/r26_icons/frames.py",
                       "brief": f"64x64 RGBA, transparent center, exact 3px border {color}.",
                       "sha256": sha256(ROOT / path), "bytes": (ROOT / path).stat().st_size})
    manifest["assets"] = assets
    manifest["pillow_version"] = PILLOW_VERSION
    contact_sheet(assets)
    manifest["contact_sheet"] = {"path": "tools/r26_icons/contact_sheet.png",
                                 "sha256": sha256(HERE / "contact_sheet.png")}
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    validate(manifest)


if __name__ == "__main__":
    main()
