#!/usr/bin/env python3
"""Post-process independent imagegen outputs and build the background contact sheet.

python3 -I tools/r52_art/arta/arta_bg.py --out /tmp/arta-rebuild
Original output paths and complete prompts are in drop-01/sources.json.
Existing identical files are accepted; different bytes are never overwritten.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

HERE = Path(__file__).resolve().parent
TREES = ("ember", "rime", "bulwark", "ruin", "mercy", "reckoning", "quarry", "veil")
PROCESS = {
    "geometry": "ImageOps.fit 1040x440, centred, Lanczos; RGB opaque",
    "calm_centre": "Smooth horizontal mask: zero at outer 5%, full from 18% to 82%; Gaussian blur radius 2 px and brightness 0.72 inside mask",
    "encoding": "256-colour MEDIANCUT palette, no dithering, PNG optimize=True",
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise SystemExit(f"Refusing to overwrite {path}; use a new drop/output directory")
    else:
        path.write_bytes(data)


def png_bytes(im):
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def record(path, out, key, variant, **extra):
    data = path.read_bytes()
    with Image.open(path) as im:
        size = list(im.size)
        mode = im.mode
    return dict(key=key, variant=variant, path=path.relative_to(out).as_posix(),
                size=size, bytes=len(data), sha256=sha(data), mode=mode, **extra)


def process(source):
    im = ImageOps.fit(source.convert("RGB"), (1040, 440),
                      method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
    row = []
    for x in range(1040):
        distance = min(x, 1039 - x) / 1039
        t = max(0, min(1, (distance - 0.05) / 0.13))
        row.append(round(255 * t * t * (3 - 2 * t)))
    mask = Image.new("L", (1040, 1))
    mask.putdata(row)
    mask = mask.resize(im.size)
    calm = ImageEnhance.Brightness(im.filter(ImageFilter.GaussianBlur(2))).enhance(0.72)
    im = Image.composite(calm, im, mask)
    return im.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def mock_grid(im):
    """Preview only. Nothing from this mock grid enters a background PNG."""
    d = ImageDraw.Draw(im)
    xs = [round(104 + c * 208) for c in range(5)]
    ys = [25 + r * 65 for r in range(7)]
    # Several vertical branches and orthogonal elbows, behind the squares.
    for c in (0, 2, 4):
        d.line([(xs[c], ys[0]), (xs[c], ys[6])], fill=(136, 145, 160), width=2)
    for c, r in ((0, 1), (1, 3), (2, 2), (3, 4)):
        x1, x2, y1, y2 = xs[c], xs[c+1], ys[r], ys[r+1]
        mid = (y1+y2)//2
        d.line([(x1, y1), (x1, mid), (x2, mid), (x2, y2)],
               fill=(156, 157, 151), width=2)
    for x in xs:
        for y in ys:
            d.rectangle((x-13, y-13, x+13, y+13), fill=(89, 93, 103),
                        outline=(200, 202, 208), width=2)
            # A short pale label proxy, to judge text contrast.
            d.line((x-15, y+19, x+15, y+19), fill=(220, 220, 224), width=2)
    return im


def contact_sheet(out):
    sheet = Image.new("RGB", (1608, 2080), (20, 22, 29))
    d = ImageDraw.Draw(sheet)
    d.text((12, 12), "ARTA / DROP 01  -  24 backgrounds  -  50% scale  -  mock 7 x 5 grid", fill=(225, 227, 233))
    for row, tree in enumerate(TREES):
        for col, variant in enumerate((1, 2, 3)):
            x, y = 12 + col*532, 38 + row*254
            d.text((x, y), f"bg.{tree} / v{variant}", fill=(226, 226, 232))
            with Image.open(out / "bg" / f"{tree}_v{variant}.png") as raw:
                thumb = mock_grid(raw.convert("RGB")).resize((520, 220), Image.Resampling.LANCZOS)
            sheet.paste(thumb, (x, y+20))
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, default=HERE / "drop-01/sources.json")
    parser.add_argument("--out", type=Path, default=HERE / "drop-01")
    parser.add_argument("--source-root", type=Path, help="Directory containing copies of the original imagegen filenames")
    args = parser.parse_args()
    sources = json.loads(args.sources.read_text())
    out = args.out.resolve()
    entries = []
    generator = dict(path="tools/r52_art/arta/arta_bg.py", sha256=sha(Path(__file__).read_bytes()))
    for job in sources["images"]:
        source = Path(job["generation_output_path"])
        if args.source_root:
            source = args.source_root / source.name
        source_bytes = source.read_bytes()
        with Image.open(source) as original:
            source_size = list(original.size)
            im = process(original)
        path = out / "bg" / f'{job["tree"]}_v{job["variant"]}.png'
        write_new(path, png_bytes(im))
        entries.append(record(path, out, f'bg.{job["tree"]}', job["variant"],
                              title=job["title"], author="GPT-6 Astra (Grudgelands)",
                              date=sources["date"], license="CC0-1.0", role="background",
                              tool=sources["tool"], prompt=job["prompt"],
                              generation_output_path=job["generation_output_path"],
                              generation_size=source_size, generation_sha256=sha(source_bytes),
                              post_processing=PROCESS, generator=generator, alpha="opaque"))
    path = out / "preview-bg.png"
    write_new(path, png_bytes(contact_sheet(out)))
    entries.append(record(path, out, "preview.bg", 1, generator=generator,
                          role="preview", author="GPT-6 Astra (Grudgelands)",
                          date=sources["date"], license="CC0-1.0",
                          method="All 24 final PNGs at half size; mock grid added before reduction"))
    manifest_path = out / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    kept = [e for e in manifest.get("assets", []) if not (e["key"].startswith("bg.") or e["key"] == "preview.bg")]
    manifest.update(schema=1, date=sources["date"], lane="ARTA", classification="compatible",
                    paths_relative_to="manifest directory", assets=entries+kept)
    manifest_path.write_text(json.dumps(manifest, indent=2)+"\n")
    print(f"Backgrounds: {len(entries)-1}; bytes {sum(e['bytes'] for e in entries[:-1]):,}; preview {path}")


if __name__ == "__main__":
    main()
