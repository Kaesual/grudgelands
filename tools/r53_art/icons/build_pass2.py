#!/usr/bin/env python3
"""Package the separate second redraw pass. Run with python3 -I."""
import argparse
import hashlib
import io
import json
import runpy
import struct
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps, __version__ as PILLOW_VERSION

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DROP = HERE / "drop-02"
SCRATCH = Path("/tmp/grudgelands-r53-icons-pass2")
PASS1 = runpy.run_path(str(HERE / "build_drop.py"))
ROWS = [
    ("skill:bellow", "Bulwark", "bellow"),
    ("skill:blink", "Rime", "blink"),
    ("skill:broadstroke", "Ruin", "broadstroke"),
    ("skill:charge", "Ruin", "charge"),
    ("skill:close_dance", "Veil", "close_dance"),
    ("skill:parry", "Veil", "parry"),
    ("talent:bulwark_halt", "Bulwark", "halt"),
    ("talent:ruin_finisher", "Ruin", "finisher"),
]
CURRENT = "a53abbf2"
OLD = "dea1d163"
digest = PASS1["digest"]
font = PASS1["font"]
git_bytes = PASS1["git_bytes"]


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def ref_record(path, revision=None):
    data = git_bytes(revision, path) if revision else (ROOT / path).read_bytes()
    assert data, path
    record = {
        "path": path, "sha256": digest(data),
        "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest(),
    }
    if revision:
        record["revision"] = subprocess.check_output(
            ["git", "rev-parse", revision], cwd=ROOT, text=True).strip()
    return record, data


def prepare():
    SCRATCH.mkdir(parents=True, exist_ok=True)
    briefs = json.loads((HERE / "briefs-pass2.json").read_text())
    jobs, comparisons = [], []
    assert set(briefs) == {r[0] for r in ROWS}
    for row in ROWS:
        key, tree, _ = row
        stem = key.replace(":", "__")
        path = PASS1["game_path"](row)
        current, _ = ref_record(path, CURRENT)
        comparison = {"key": key, "tree": tree, "current": current, "pass1": []}
        old = None
        if key in ("skill:blink", "skill:charge"):
            old, data = ref_record(path, OLD)
            comparison["old"] = old
            (SCRATCH / f"{stem}_old.png").write_bytes(data)
        for i in range(1, 4):
            ref, _ = ref_record(f"tools/r53_art/icons/drop-01/{stem}_v{i}.png")
            comparison["pass1"].append(ref)
        comparisons.append(comparison)
        for i, motif in enumerate(briefs[key], 1):
            reference, supplied = None, None
            if old:
                reference, supplied = [old], SCRATCH / f"{stem}_old.png"
            elif key == "skill:bellow":
                reference = [ref_record("tools/r53_art/icons/drop-01/skill__bellow_v3.png")[0]]
                supplied = ROOT / reference[0]["path"]
            elif key == "skill:close_dance":
                reference = [comparison["pass1"][i - 1]]
                supplied = ROOT / reference[0]["path"]
            elif key == "talent:bulwark_halt":
                reference, supplied = [current], ROOT / path
            frame = (
                "Talent framing: one plain circular bronze medallion 91% of square wide, "
                "simple rim 3 final pixels thick, outside corners dark charcoal. "
                "Motif fills 60-85% of interior, stays INSIDE the rim. "
                if key.startswith("talent:") else
                "Skill framing: full square artwork, NO border, frame or medallion. "
            )
            jobs.append({
                "key": key, "variant": f"v{i}", "tree": tree,
                "filename": f"{stem}_v{i}.png",
                "prompt": PASS1["BASE"] + frame + PASS1["PALETTES"][tree]
                + " Subject and composition: " + motif
                + " Output ONE square opaque painting for whole-image Lanczos reduction to 64x64 RGB.",
                "reference": reference,
                "supplied_paths": [str(supplied)] if supplied else [],
            })
    write_json(SCRATCH / "jobs.json", jobs)
    write_json(SCRATCH / "references.json", comparisons)
    print("Prepared 24 individual imagegen jobs and comparison provenance.")


def processed(receipt):
    entry = dict(receipt)
    entry.pop("filename", None)
    entry.pop("supplied_paths", None)
    history = entry.pop("previous_versions", [])
    source = Path(entry.pop("source_path"))
    data = source.read_bytes()
    with Image.open(io.BytesIO(data)) as image:
        assert image.width == image.height
        size = list(image.size)
        final = image.convert("RGB").resize((64, 64), Image.Resampling.LANCZOS)
    output = io.BytesIO()
    final.save(output, format="PNG", optimize=True)
    entry.update({
        "path": f"{entry['key'].replace(':', '__')}_{entry['variant']}.png",
        "sha256": digest(output.getvalue()),
        "source": {"path": str(source), "sha256": digest(data), "size": size},
        "processing": {
            "library": "Pillow", "version": PILLOW_VERSION, "convert": "RGB",
            "resize": [64, 64], "resampling": "Image.Resampling.LANCZOS",
            "crop": None, "recolour": False, "sharpen": False,
            "output": "PNG, 8-bit RGB, no alpha, optimize=True; source metadata omitted",
        },
        "previous_versions": [processed(prior)[0] for prior in history],
    })
    return entry, output.getvalue()


def package():
    DROP.mkdir(parents=True, exist_ok=True)
    entries = []
    for key, _, _ in ROWS:
        for i in range(1, 4):
            receipt = json.loads(
                (SCRATCH / f"receipt_{key.replace(':', '__')}_v{i}.json").read_text())
            entry, data = processed(receipt)
            (DROP / entry["path"]).write_bytes(data)
            entries.append(entry)
    manifest = {
        "schema": 1, "date": "2026-10-20", "author": "GPT-6 Astra",
        "tool": "built-in image_gen.imagegen; one prompt and call per image",
        "style": "A / Painted embers, simplified", "license": "CC0-1.0",
        "upgrade": "compatible", "status": "proposals, awaiting the user's selection",
        "pass": 2, "previous_drop": "../drop-01/manifest.json",
        "generation_calls": len(entries) + sum(len(e["previous_versions"]) for e in entries),
        "old_revision": OLD,
        "comparison_references": json.loads((SCRATCH / "references.json").read_text()),
        "assets": entries,
    }
    write_json(DROP / "manifest.json", manifest)
    print(f"Packaged {len(entries)} proposals.")


def ref_image(record):
    data = (git_bytes(record["revision"], record["path"])
            if "revision" in record else (ROOT / record["path"]).read_bytes())
    assert digest(data) == record["sha256"], record
    with Image.open(io.BytesIO(data)) as image:
        return image.convert("RGB")


def choices(manifest, row):
    entries = {e["variant"]: e for e in manifest["assets"] if e["key"] == row["key"]}
    images = [ref_image(row["current"]),
              ref_image(row["old"]) if "old" in row else None]
    images.extend(ref_image(record) for record in row["pass1"])
    for variant in ("v1", "v2", "v3"):
        with Image.open(DROP / entries[variant]["path"]) as image:
            images.append(image.convert("RGB"))
    return images


def cells(image):
    """Exact native-size pixels; only smaller views use Lanczos."""
    yield 0, 0, image
    yield 74, 16, image.resize((32, 32), Image.Resampling.LANCZOS)
    yield 116, 24, image.resize((16, 16), Image.Resampling.LANCZOS)
    yield 16, 72, ImageOps.grayscale(
        image.resize((32, 32), Image.Resampling.LANCZOS)).convert("RGB")


def preview():
    manifest = json.loads((DROP / "manifest.json").read_text())
    sheet = Image.new("RGB", (1550, 1144), "#15171c")
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 8), "Round 53 | Redraw pass 2 | native 64 / 32 / 16 px; greyscale 32 px below | view at 100%",
              font=font(15), fill="#eee8da")
    for x, end, title, colour in (
        (250, 550, "SHIPPED REFERENCES", "#81796b"),
        (566, 1024, "PASS 1 — REFERENCE ONLY", "#81796b"),
        (1040, 1538, "PASS 2 — NEW PROPOSALS", "#a4cfda"),
    ):
        draw.rectangle((x - 6, 34, end, 57), fill="#252c36")
        draw.text((x, 37), title, font=font(12), fill=colour)
    for j, label in enumerate(("Current", "0.51", "v1", "v2", "v3", "NEW v1", "NEW v2", "NEW v3")):
        draw.text((250 + j * 158, 66), label, font=font(12), fill="#ddd4c4")
    for i, row in enumerate(manifest["comparison_references"]):
        y = 90 + i * 132
        draw.line((10, y - 4, 1540, y - 4), fill="#353436")
        draw.text((10, y + 22), row["key"], font=font(13), fill="#eee8da")
        draw.text((10, y + 43), row["tree"], font=font(11), fill="#b5aa97")
        for j, image in enumerate(choices(manifest, row)):
            x = 250 + j * 158
            if image is None:
                draw.text((x, y + 20), "not applicable", font=font(10), fill="#746e68")
                continue
            for dx, dy, thumb in cells(image):
                sheet.paste(thumb, (x + dx, y + dy))
            draw.text((x + 58, y + 83), "grey 32", font=font(10), fill="#8d939c")
    sheet.save(DROP / "preview.png", optimize=True)
    manifest["previews"] = [{
        "path": "preview.png", "sha256": digest((DROP / "preview.png").read_bytes()),
        "size": list(sheet.size), "rows": [r[0] for r in ROWS],
        "sizes": [64, 32, 16], "greyscale_size": 32,
        "columns": ["current", "0.51 where requested", "pass1 v1", "pass1 v2",
                    "pass1 v3", "pass2 v1", "pass2 v2", "pass2 v3"],
    }]
    write_json(DROP / "manifest.json", manifest)
    print("Wrote one eight-row comparison sheet with native-size thumbnails.")


def check_reference(record):
    path = Path(record["path"])
    if "revision" in record:
        data = git_bytes(record["revision"], record["path"])
    elif path.is_absolute() and not path.exists():
        assert len(record["sha256"]) == 64 and len(record["git_blob"]) == 40
        return
    else:
        data = (ROOT / path).read_bytes()
    assert digest(data) == record["sha256"], record
    assert hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == record["git_blob"]


def check_version(entry):
    assert entry["prompt"] and entry["processing"]["resampling"] == "Image.Resampling.LANCZOS"
    for reference in entry["reference"] or []:
        check_reference(reference)
    source = Path(entry["source"]["path"])
    if source.exists():
        data = source.read_bytes()
        assert digest(data) == entry["source"]["sha256"]
        with Image.open(io.BytesIO(data)) as image:
            assert list(image.size) == entry["source"]["size"]
            image = image.convert("RGB").resize((64, 64), Image.Resampling.LANCZOS)
        # Validate the reduction independently of PNG encoder/version differences.
        if (DROP / entry["path"]).exists() and digest((DROP / entry["path"]).read_bytes()) == entry["sha256"]:
            with Image.open(DROP / entry["path"]) as final:
                assert final.tobytes() == image.tobytes()
    for previous in entry["previous_versions"]:
        check_version(previous)


def check():
    manifest = json.loads((DROP / "manifest.json").read_text())
    assets = manifest["assets"]
    expected = {(key, f"v{i}") for key, _, _ in ROWS for i in range(1, 4)}
    actual = [(e["key"], e["variant"]) for e in assets]
    assert len(actual) == 24 and set(actual) == expected
    filenames = {f"{key.replace(':', '__')}_{variant}.png" for key, variant in expected}
    assert {p.name for p in DROP.glob("*.png")} == filenames | {"preview.png"}
    assert len({e["sha256"] for e in assets}) == 24
    readme = (HERE / "README.md").read_text()
    for entry in assets:
        assert entry["path"] == f"{entry['key'].replace(':', '__')}_{entry['variant']}.png"
        data = (DROP / entry["path"]).read_bytes()
        assert digest(data) == entry["sha256"]
        assert data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR"
        assert struct.unpack(">IIBB", data[16:26]) == (64, 64, 8, 2)
        with Image.open(io.BytesIO(data)) as image:
            assert image.format == "PNG" and image.mode == "RGB" and image.size == (64, 64)
            assert "transparency" not in image.info
        assert entry["tree"] == {r[0]: r[1] for r in ROWS}[entry["key"]]
        assert f"| `drop-02/{entry['path']}` | GPT-6 Astra | 2026-10-20 |" in readme
        check_version(entry)
    assert manifest["generation_calls"] == 24 + sum(len(e["previous_versions"]) for e in assets)
    assert [r["key"] for r in manifest["comparison_references"]] == [r[0] for r in ROWS]
    for row in manifest["comparison_references"]:
        check_reference(row["current"])
        assert ("old" in row) == (row["key"] in ("skill:blink", "skill:charge"))
        if "old" in row:
            check_reference(row["old"])
        assert len(row["pass1"]) == 3
        for ref in row["pass1"]:
            check_reference(ref)
    assert len(manifest["previews"]) == 1
    preview_data = (DROP / "preview.png").read_bytes()
    assert digest(preview_data) == manifest["previews"][0]["sha256"]
    with Image.open(io.BytesIO(preview_data)) as sheet:
        assert sheet.mode == "RGB" and sheet.size == (1550, 1144)
        for i, row in enumerate(manifest["comparison_references"]):
            for j, image in enumerate(choices(manifest, row)):
                if image is None:
                    continue
                for dx, dy, thumb in cells(image):
                    x, y = 250 + j * 158 + dx, 90 + i * 132 + dy
                    assert sheet.crop((x, y, x + thumb.width, y + thumb.height)).tobytes() == thumb.tobytes()
    assert "| `drop-02/preview.png` | GPT-6 Astra | 2026-10-20 |" in readme
    print("PASS: 24 unique 64x64 opaque 8-bit RGB PNGs, eight stems x v1-v3; "
          "exact hashes, source reductions, references, history, pixel-exact preview and 25 media rows.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "package", "preview", "check"])
    args = parser.parse_args()
    globals()[args.command]()
