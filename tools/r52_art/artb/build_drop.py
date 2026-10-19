#!/usr/bin/env python3
"""Package the generated ARTB samples and rebuild their offline review sheet.

Run with python3 -I; requires Pillow. No image generation or network access.
"""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DROP = HERE / "drop-01"
MANIFEST = DROP / "manifest.json"
KEYS = (
    "skill.fiery_spark", "skill.cold_spark", "skill.fireball", "skill.smite",
    "skill.bladecraft", "skill.arrowfall", "talent.f1", "talent.r10",
    "talent.b2", "talent.m7", "talent.rk1", "talent.q2",
)
LABELS = (
    "Fiery\nSpark", "Cold\nSpark", "Fireball", "Smite", "Bladecraft",
    "Arrowfall", "F1\nFire Mastery", "R10\nCold Shock", "B2\nIronbound",
    "M7\nPatient Care", "RK1\nSharpened Word", "Q2\nQuiver",
    "Shipped\nFireball", "Shipped\nSmite",
)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_manifest(data):
    MANIFEST.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                        encoding="utf-8")


def package(data):
    """Package only missing finals; originals remain in the tool's directory."""
    for entry in data["assets"]:
        if not entry["source"]:
            continue
        target = DROP / entry["path"]
        if target.exists():
            if entry.get("sha256") != sha256(target):
                raise ValueError(f"Existing final changed: {target}")
            continue
        source = Path(entry["source"])
        with Image.open(source) as original:
            original.load()
            if original.width != original.height:
                raise ValueError(f"Expected square source: {source}")
            if "A" in original.getbands():
                if original.getchannel("A").getextrema() != (255, 255):
                    raise ValueError(f"Unexpected transparent source: {source}")
            entry["source_sha256"] = sha256(source)
            entry["processing"] = {
                "tool": "Pillow", "version": pillow_version,
                "source_size": list(original.size), "source_mode": original.mode,
                "operations": ["convert RGB", "resize 64x64 with Image.Resampling.LANCZOS",
                               "save PNG, optimize=True, no source metadata"],
                "crop": None, "recolor": False, "composite": False,
                "output_size": [64, 64], "output_mode": "RGB",
            }
            final = original.convert("RGB").resize((64, 64), Image.Resampling.LANCZOS)
            final.info.clear()
            target.parent.mkdir(parents=True, exist_ok=True)
            final.save(target, format="PNG", optimize=True)
        entry["sha256"] = sha256(target)
        # Save each receipt immediately so an interrupted batch can resume.
        write_manifest(data)


def shipped(data):
    comparisons = []
    for skill in ("fireball", "smite"):
        path = Path("mods/PLAYER/grug_abilities/textures") / f"grug_abilities_skill_{skill}.png"
        comparisons.append({"key": f"shipped.{skill}", "path": path.as_posix(),
                            "sha256": sha256(ROOT / path), "license": "CC0-1.0",
                            "source_manifest": "tools/r18_art/manifest.json"})
    if "comparisons" in data and data["comparisons"] != comparisons:
        raise ValueError("Shipped comparison assets differ from the recorded versions")
    data["comparisons"] = comparisons


def validate(data):
    expected = {(style, key) for style in "ABC" for key in KEYS}
    actual = [(entry["style"], entry["key"]) for entry in data["assets"]]
    if len(actual) != 36 or set(actual) != expected:
        raise ValueError("Expected the exact 12-key sample for each of A, B and C")
    for entry in data["assets"]:
        if entry["path"] != f'{entry["style"]}/{entry["key"]}.png':
            raise ValueError(f"Unexpected asset path: {entry['path']}")
        path = DROP / entry["path"]
        with Image.open(path) as im:
            im.load()
            if im.format != "PNG" or im.mode != "RGB" or im.size != (64, 64):
                raise ValueError(f"Expected opaque 64x64 RGB PNG: {path}")
        if sha256(path) != entry["sha256"]:
            raise ValueError(f"SHA-256 mismatch: {path}")
        if not entry["prompt"] or not entry["processing"]:
            raise ValueError(f"Incomplete receipt: {path}")
    files = {p.relative_to(DROP).as_posix() for s in "ABC" for p in (DROP / s).glob("*.png")}
    if files != {entry["path"] for entry in data["assets"]}:
        raise ValueError("Unlisted or missing final images")
    shipped(data)


def font(size):
    return ImageFont.load_default(size=size)


def preview(data):
    """Actual-size strips and 48px mock hotbars; labels are outside the art."""
    width, block, top = 1496, 438, 110
    sheet = Image.new("RGB", (width, top + 3 * block + 48), "#11151c")
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "GRUDGELANDS / TALENT + SKILL ICONS", font=font(25), fill="#f0e7d6")
    draw.text((24, 51), "ROUND 52  /  ARTB  /  PASS 1  /  36 STYLE SAMPLES", font=font(15), fill="#b4a78e")
    draw.text((24, 78), "View at 100% for native pixels. Dark + light strips: each cell shows 32px then 64px. Last two columns: shipped art.",
              font=font(13), fill="#a6b0c0")
    lookup = {(e["style"], e["key"]): e for e in data["assets"]}
    for row, style in enumerate("ABC"):
        y = top + row * block
        title = data["styles"][style]["name"]
        draw.text((24, y), f"{style}  /  {title.upper()}", font=font(22), fill="#eee3ce")
        draw.text((24, y + 29), "6 SKILLS  /  unframed", font=font(13), fill="#b7c2d3")
        draw.text((652, y + 29), "6 TALENTS  /  framed emblems", font=font(13), fill="#b7c2d3")
        draw.text((1276, y + 29), "TODAY / comparison", font=font(13), fill="#b7c2d3")
        paths = [DROP / lookup[(style, key)]["path"] for key in KEYS]
        paths += [ROOT / c["path"] for c in data["comparisons"]]
        for strip, (bg, fg) in enumerate((("#202630", "#dfe6ed"), ("#dfd9cd", "#272c34"))):
            sy = y + 52 + strip * 143
            draw.rectangle((16, sy, width - 17, sy + 139), fill=bg)
            for col, (path, label) in enumerate(zip(paths, LABELS)):
                x = 24 + col * 104
                with Image.open(path) as im:
                    im = im.convert("RGB")
                    sheet.paste(im.resize((32, 32), Image.Resampling.LANCZOS), (x + 32, sy + 5))
                    sheet.paste(im, (x + 16, sy + 41))
                draw.multiline_text((x + 48, sy + 110), label, font=font(11), fill=fg, align="center", anchor="ma", spacing=1)
            for boundary in (6, 12):
                bx = 20 + boundary * 104
                draw.line((bx, sy + 4, bx, sy + 135), fill="#818488", width=1)
        hy = y + 345
        draw.text((24, hy + 3), "MOCK HOTBAR / 48px", font=font(14), fill="#ddd1b9")
        draw.text((24, hy + 25), "6 samples + 2 empty slots", font=font(12), fill="#98a5b7")
        draw.text((24, hy + 44), "Layout only; not a class build", font=font(11), fill="#98a5b7")
        for slot in range(8):
            x = 285 + slot * 62
            draw.rectangle((x, hy, x + 57, hy + 57), fill="#171a20", outline="#625e54", width=2)
            if slot < 6:
                with Image.open(paths[slot]) as im:
                    sheet.paste(im.resize((48, 48), Image.Resampling.LANCZOS), (x + 5, hy + 5))
            if slot == 2:
                draw.rectangle((x - 2, hy - 2, x + 59, hy + 59), outline="#dbb96e", width=2)
            draw.text((x + 27, hy + 62), str(slot + 1), font=font(11), fill="#9ca7b4", anchor="ma")
        draw.text((817, hy + 7), "Spark pair: same silhouette, different element", font=font(14), fill="#d8dfe7")
        draw.text((817, hy + 30), "Talent frame is part of the PNG; skill art has no frame.", font=font(12), fill="#a5b0bf")
        draw.line((24, y + block - 9, width - 25, y + block - 9), fill="#343c49")
    draw.text((24, top + 3 * block + 11), "Built-in image generation / Lanczos reduction / CC0-1.0 / 2026-10-19 / User selection pending / Offline mockup",
              font=font(13), fill="#a6b0c0")
    path = DROP / "preview.png"
    sheet.save(path, optimize=True)
    data["preview"] = {"path": "preview.png", "sha256": sha256(path), "size": list(sheet.size),
                       "processing": "Pillow composition of unchanged finals and shipped comparison art; 32/48px copies use Lanczos; 64px copies are pasted unchanged; default Pillow font; opaque RGB PNG"}
    write_manifest(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", action="store_true", help="Package missing icons from local tool outputs; incomplete batches are allowed")
    parser.add_argument("--check", action="store_true", help="Read-only file, format and hash audit; no fixtures")
    args = parser.parse_args()
    if args.package and args.check:
        parser.error("Choose --package or --check")
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if args.package:
        package(data)
        print(f"Packaged {sum('sha256' in e for e in data['assets'])}/36 icons")
        return
    validate(data)
    if args.check:
        if sha256(DROP / "preview.png") != data["preview"]["sha256"]:
            raise ValueError("Preview SHA-256 mismatch")
        print("36/36 icons: exact roster, opaque 64x64 RGB PNG, complete receipts and SHA-256; preview and shipped comparison hashes match")
    else:
        preview(data)
        print(f"Built {DROP / 'preview.png'}")


if __name__ == "__main__":
    main()
