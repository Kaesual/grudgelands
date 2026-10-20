#!/usr/bin/env python3
"""Package and audit the Round 53 icon proposals; run with python3 -I."""
import argparse
import hashlib
import io
import json
import struct
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps, __version__ as PILLOW_VERSION

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
DROP = HERE / "drop-01"
SCRATCH = Path("/tmp/grudgelands-r53-icons")
OLD = "dea1d163"
ROWS = [
    ("skill:strike", "neutral", "strike"),
    ("skill:charge", "Ruin", "charge"),
    ("skill:hold_ground", "Bulwark", "hold_ground"),
    ("skill:taunt", "Bulwark", "taunt"),
    ("skill:bellow", "Bulwark", "bellow"),
    ("skill:retort", "Bulwark", "retort"),
    ("talent:bulwark_halt", "Bulwark", "halt"),
    ("talent:bulwark_enduring_stand", "Bulwark", "enduring_stand"),
    ("skill:mighty_blow", "Ruin", "mighty_blow"),
    ("skill:broadstroke", "Ruin", "broadstroke"),
    ("skill:hamstring", "Ruin", "hamstring"),
    ("skill:ruination", "Ruin", "ruination"),
    ("talent:ruin_stoke", "Ruin", "stoke"),
    ("talent:ruin_finisher", "Ruin", "finisher"),
    ("talent:ruin_relentless", "Ruin", "relentless"),
    ("skill:blink", "Rime", "blink"),
    ("skill:heal", "Mercy", "heal"),
    ("skill:mend", "Mercy", "mend"),
    ("skill:shield_spell", "Mercy", "shield_spell"),
    ("talent:mercy_clear_conscience", "Mercy", "clear_conscience"),
    ("talent:mercy_lasting_haven", "Mercy", "lasting_haven"),
    ("skill:rebuke", "Reckoning", "rebuke"),
    ("skill:word_of_ruin", "Reckoning", "word_of_ruin"),
    ("skill:censure", "Reckoning", "censure"),
    ("talent:reckoning_long_reach", "Reckoning", "long_reach"),
    ("skill:loose", "Quarry", "loose"),
    ("skill:sidestep", "Quarry", "sidestep"),
    ("skill:sprint", "Quarry", "sprint"),
    ("skill:true_draw", "Quarry", "true_draw"),
    ("skill:split_shot", "Quarry", "split_shot"),
    ("skill:opening", "Veil", "opening"),
    ("skill:parry", "Veil", "parry"),
    ("skill:flourish", "Veil", "flourish"),
    ("skill:close_dance", "Veil", "close_dance"),
    ("talent:veil_shake_loose", "Veil", "shake_loose"),
    ("talent:veil_travel_worn", "Veil", "travel_worn"),
]
PALETTES = {
    "neutral": "Neutral steel: dark charcoal #171619 field, warm ivory/amber accent.",
    "Bulwark": "Bulwark: flat slate #171D26 field; steel #99A3AE, bronze #B08A4D accent.",
    "Ruin": "Ruin: flat near-black #140E15 field; crimson #B52F3B effect, pale hot edge only.",
    "Rime": "Rime: flat navy #0A1930 field; pale blue #A5D9F2 and cold white #F1FBFF effect.",
    "Mercy": "Mercy: flat warm brown #251B17 field; warm gold #E8BC5C and ivory #FFF0CE light.",
    "Reckoning": "Reckoning: flat umber-black #1E1615 field; hard gold #D5AD52 and white #FFF6DD light, restrained crimson #A32A32 accent.",
    "Quarry": "Quarry: flat forest #10251D field; green #91AA55 effect, natural brown #94603A wood/leather.",
    "Veil": "Veil: flat indigo-black #100F22 field; violet #8162B1 accent, natural silver #DFE4ED metal.",
}
BASE = (
    "Use case: stylized-concept. Create ONE square opaque MMO-inspired ability/talent icon. "
    "Style A / Painted embers, simplified: broad faceted painted masses, upper-left lighting, "
    "deep matte shadows, restrained glow, extremely simplified few LARGE shapes. "
    "Three value masses: dark field, mid object, light highlight/effect. "
    "The object must be immediately recognisable at 32 pixels and retain its shape and natural "
    "main colour as a 16-pixel blob. At final 64 pixels, meaningful edges and gaps at least 2 pixels, "
    "details at least 3 pixels except one highlight. Main subject occupies 60-85 percent of usable area. "
    "Natural object colours: silver-grey steel blades and armour, brown wooden shafts and leather, "
    "brass/bronze fittings, natural tan skin, ivory bone, iron-grey chains. "
    "Tree colours belong ONLY in field, motion, light or effect, NEVER tint an object. "
    "At most 2-3 main colours plus the stated accent; preserve strong greyscale contrast. "
    "Simple front/side view or a clear diagonal, no foreshortening or knots. "
    "No scenery, surface grain, dust, smoke, mist, engraving, rivets, fur, folds, fine scratches, "
    "tiny spark clouds, writing, lettering, numerals, punctuation, watermark, UI or multiple panels. "
    "Only the explicitly requested motif elements and meaningful symbols below are allowed. "
)


def prepare():
    SCRATCH.mkdir(parents=True, exist_ok=True)
    briefs = json.loads((HERE / "briefs.json").read_text())
    jobs = []
    assert set(briefs) == {r[0] for r in ROWS}
    for row in ROWS:
        key, tree, _ = row
        for i, motif in enumerate(briefs[key], 1):
            frame = (
                "Talent framing: one simple circular BRONZE medallion, 91 percent of square wide, "
                "plain rim approximately 3 final pixels thick, outer corners flat dark charcoal. "
                "Motif fills 60-85 percent of the medallion INTERIOR and never overlaps the rim. "
                if key.startswith("talent:") else
                "Skill framing: artwork fills the square; NO frame, border or medallion. "
            )
            dependency = None
            if key == "skill:retort":
                dependency = f"skill__strike_v{i}.png"
            elif key == "skill:broadstroke":
                dependency = f"skill__mighty_blow_v{i}.png"
            elif key == "skill:bellow" and i == 1:
                dependency = "skill__taunt_v1.png"
            palette = PALETTES[tree]
            if key == "skill:word_of_ruin" and i == 2:
                palette = "Reckoning umber-black #1E1615 field; ivory bone; the explicitly permitted violet-magenta crack accent replaces gold/crimson for this one variant."
            jobs.append({
                "key": key, "variant": f"v{i}", "tree": tree,
                "filename": f"{key.replace(':', '__')}_v{i}.png",
                "prompt": BASE + frame + palette + " Subject and composition: " + motif +
                " Output one square painting, opaque background, for whole-image Lanczos reduction to 64 by 64 RGB.",
                "dependency": dependency,
            })
    assert len(jobs) == 108
    (SCRATCH / "jobs.json").write_text(json.dumps(jobs, indent=2) + "\n")
    print(f"Prepared {len(jobs)} individual prompts.")


def package():
    DROP.mkdir(parents=True, exist_ok=True)
    receipts = json.loads((SCRATCH / "receipts.json").read_text())
    references = json.loads((SCRATCH / "references.json").read_text())
    entries = []
    for receipt in receipts:
        entry = dict(receipt)
        source = Path(entry.pop("source_path"))
        source_bytes = source.read_bytes()
        with Image.open(io.BytesIO(source_bytes)) as original:
            assert original.width == original.height, source
            source_size = list(original.size)
            final = original.convert("RGB").resize((64, 64), Image.Resampling.LANCZOS)
        filename = f"{entry['key'].replace(':', '__')}_{entry['variant']}.png"
        final.save(DROP / filename, optimize=True)
        entry.update({
            "path": filename, "sha256": digest((DROP / filename).read_bytes()),
            "source": {"path": str(source), "sha256": digest(source_bytes), "size": source_size},
            "processing": {
                "library": "Pillow", "version": PILLOW_VERSION, "convert": "RGB", "resize": [64, 64],
                "resampling": "Image.Resampling.LANCZOS",
                "crop": None, "recolour": False, "sharpen": False,
                "output": "PNG, 8-bit RGB, no alpha, optimize=True; source metadata omitted",
            },
        })
        entries.append(entry)
    order = {row[0]: i for i, row in enumerate(ROWS)}
    entries.sort(key=lambda e: (order[e["key"]], e["variant"]))
    manifest = {
        "schema": 1, "date": "2026-10-20", "author": "GPT-6 Astra",
        "tool": "built-in image_gen.imagegen; one prompt and call per image",
        "style": "A / Painted embers, simplified", "license": "CC0-1.0",
        "upgrade": "compatible", "status": "proposals, awaiting the user's selection",
        "generation_calls": len(entries) + sum(len(e.get("previous_versions", [])) for e in entries),
        "old_revision": OLD,
        "comparison_references": [
            {key: ({k: v for k, v in value.items() if k != "scratch_path"}
                   if isinstance(value, dict) else value)
             for key, value in ref.items()} for ref in references
        ],
        "assets": entries,
    }
    (DROP / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Packaged {len(entries)}/108 proposals.")


def preview():
    manifest = json.loads((DROP / "manifest.json").read_text())
    by_key = {}
    for entry in manifest["assets"]:
        by_key.setdefault(entry["key"], {})[entry["variant"]] = entry
    manifest["previews"] = []
    for page in range(6):
        rows = manifest["comparison_references"][page * 6:(page + 1) * 6]
        sheet = Image.new("RGB", (1090, 72 + len(rows) * 122), "#15171c")
        draw = ImageDraw.Draw(sheet)
        draw.text((12, 10), f"Round 53 icon proposals | {page + 1}/6 | actual 64 / 32 / 16 px; greyscale 32 px below",
                  font=font(16), fill="#eee8da")
        for j, name in enumerate(("0.51", "Current", "v1", "v2", "v3")):
            draw.text((300 + j * 155, 44), name, font=font(), fill="#ddd4c4")
        for i, ref in enumerate(rows):
            y = 72 + i * 122
            draw.line((10, y - 4, 1080, y - 4), fill="#353436")
            draw.text((10, y + 21), ref["key"], font=font(), fill="#eee8da")
            draw.text((10, y + 43), ref["tree"], font=font(11), fill="#b5aa97")
            choices = []
            for label in ("old", "current"):
                data = git_bytes(ref[label]["revision"], ref[label]["path"]) if label in ref else None
                choices.append(Image.open(io.BytesIO(data)) if data else None)
            for variant in ("v1", "v2", "v3"):
                entry = by_key.get(ref["key"], {}).get(variant)
                choices.append(Image.open(DROP / entry["path"]) if entry else None)
            for j, im in enumerate(choices):
                x = 300 + j * 155
                if im is None:
                    draw.text((x, y + 20), "not present", font=font(11), fill="#746e68")
                    continue
                paste_sizes(sheet, im, x, y)
                grey = ImageOps.grayscale(im.convert("RGB").resize((32, 32), Image.Resampling.LANCZOS)).convert("RGB")
                sheet.paste(grey, (x + 22, y + 72))
        path = DROP / f"preview-{page + 1}.png"
        sheet.save(path, optimize=True)
        manifest["previews"].append({
            "path": path.name, "sha256": digest(path.read_bytes()),
            "size": list(sheet.size), "rows": [ref["key"] for ref in rows],
            "sizes": [64, 32, 16], "greyscale_size": 32,
        })
    (DROP / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("Wrote six comparison sheets.")


def context():
    """Create scratch sheets for comparison with the retained tree icons."""
    manifest = json.loads((DROP / "manifest.json").read_text())
    old_manifest = json.loads((ROOT / "tools/r52_art/artb/drop-02/manifest.json").read_text())
    excluded = {r["game_path"] for r in manifest["comparison_references"]}
    kept = {}
    for entry in old_manifest["assets"]:
        name = entry["key"].split(".")[-1]
        kind = entry["kind"]
        mod = "grug_abilities" if kind == "skill" else "grug_classes"
        path = f"mods/PLAYER/{mod}/textures/{mod}_{kind}_{name}.png"
        tree = entry.get("tree", "").lower()
        if path not in excluded and (ROOT / path).exists():
            kept.setdefault(tree, []).append(path)
    by_key = {}
    for entry in manifest["assets"]:
        by_key.setdefault(entry["key"], []).append(entry)
    SCRATCH.mkdir(parents=True, exist_ok=True)
    for page in range(3):
        rows = ROWS[page * 12:(page + 1) * 12]
        sheet = Image.new("RGB", (940, 75 + len(rows) * 54), "#15171c")
        draw = ImageDraw.Draw(sheet)
        draw.text((10, 10), "32 px context check: proposals beside retained icons of their tree",
                  font=font(17), fill="#eee8da")
        draw.text((300, 42), "v1     v2     v3", font=font(), fill="#ddd4c4")
        draw.text((455, 42), "Retained tree icons (read from current checkout)", font=font(), fill="#ddd4c4")
        for i, row in enumerate(rows):
            key, tree, _ = row
            y = 75 + i * 54
            draw.text((10, y + 8), key, font=font(), fill="#eee8da")
            for j, entry in enumerate(by_key[key]):
                with Image.open(DROP / entry["path"]) as im:
                    sheet.paste(im.convert("RGB").resize((32, 32), Image.Resampling.LANCZOS), (300 + j * 44, y))
            paths = kept.get(tree.lower(), [])[:10]
            if not paths:
                draw.text((455, y + 8), "Neutral Strike has no tree peers", font=font(11), fill="#a9a19a")
            for j, path in enumerate(paths):
                with Image.open(ROOT / path) as im:
                    sheet.paste(im.convert("RGB").resize((32, 32), Image.Resampling.LANCZOS), (455 + j * 44, y))
        sheet.save(SCRATCH / f"context-{page + 1}.png")
    print("Wrote three 32 px retained-tree context checks in scratch.")


def document():
    manifest = json.loads((DROP / "manifest.json").read_text())
    text = """# Round 53 ICONS — clarity redraw proposals

Prepared 2026-10-20 by GPT-6 Astra on `r53-icons`.
This drop contains **108 proposals: three variants for each of 26 skill icons
and 10 talent icons**. They await the user's selection.

Upgrade classification: **compatible**. This is staged media and its packaging.
No shipped assets, Lua or earlier drops change. No fixtures, engine runs,
subagents, merge or push are part of this lane.

The user's 2026-10-20 brief asks for the clarity of the project's 0.51 icons
inside style A / Painted embers: fewer, larger painted masses, natural object
colours, a quiet tree-coloured field and a separate effect accent.
Skills have no frame; talents retain the circular bronze medallion.

- [Manifest and exact prompts](drop-01/manifest.json): key, variant, tree,
  final path and SHA-256, exact individual prompt, processing, original tool
  output path/hash, supplied reference path/hash/git blob, and comparison
  provenance, including `previous_versions` for the 19 targeted refinements.
  Final paths resolve from `drop-01/`; project reference paths resolve from
  the repository root. Absolute reference paths identify unchanged original
  paintings at the tool's output location.
- [Preview 1](drop-01/preview-1.png), [2](drop-01/preview-2.png),
  [3](drop-01/preview-3.png), [4](drop-01/preview-4.png),
  [5](drop-01/preview-5.png), [6](drop-01/preview-6.png): one row per icon,
  showing 0.51 where present, the current snapshot and v1–v3, each at actual
  64, 32 and 16 px, with a 32 px greyscale check below. View at 100%.
- [Composition briefs](briefs.json) preserve the intended differences.
  [Packaging script](build_drop.py) runs with `python3 -I`.

Every proposal uses the **built-in `image_gen.imagegen` tool**, one separate
prompt and call per image. No third-party images were supplied. The 0.51
and current icons were inspected side by side before generation. Matching
Strike masters were supplied for Retort; matching Mighty Blow masters were
supplied for Broadstroke; Taunt v1 was supplied for Bellow v1. The latter
keeps the same helmet, shoulder armour and bust design while changing from
profile to near-frontal as the brief requests.
Nineteen additional focused edit calls simplify the initial renderings or
make the composition differences clearer; all earlier prompts, source
hashes and final-image receipts remain in `previous_versions`.

Pillow converts the entire square source to RGB and reduces it to 64 × 64
with `Image.Resampling.LANCZOS`, without cropping, recolouring, compositing
or sharpening. Final PNGs are opaque 8-bit RGB. Only comparison sheets
combine images and labels. Source paintings stay at their original tool
locations; their immutable receipts remain in the manifest.

Exactly one Heal proposal retains teal light (v2), one Mend proposal retains
natural green leaves (v1), and one Word of Ruin proposal retains a
violet-magenta crack (v2); the skull itself remains ivory. The specific
multi-part motifs requested in the brief (portal afterimage, splitting shot,
crossed blades, healing hands, paired boots) are treated as single action
emblems. Healing crosses, return arrows and simple target rings are the
explicitly requested semantic shapes; no lettering or decorative glyphs
are added.

All 108 final proposals were visually inspected at actual 64/32/16 px,
in greyscale at 32 px and beside retained icons of their tree.
The packaging audit passed: complete 36 × 3 roster, 108 unique final
hashes, 64 × 64 opaque 8-bit RGB PNGs, exact prompts, source/reference
hashes, six comparison sheets and 114 media rows. The current comparison
textures were also checked against `main` and matched.
The user makes the final selection; later integration owns desktop and
web runtime checks.

## Reproducing packaging

`python3 -I tools/r53_art/icons/build_drop.py check` audits committed
deliverables without regenerating art and also checks cached originals
when available. `preview` rebuilds comparison sheets
from the manifest and the recorded git revisions. `references` and `prepare`
create the original study inputs and generation jobs in
`/tmp/grudgelands-r53-icons`; `package` consumes generation receipts there.
The built-in generator is invoked separately, not by the Python script.
`context` creates scratch comparisons with retained tree icons at 32 px.
Do not rerun `references` to replace the recorded current snapshot after
the branch changes.

## Media

Paths are relative to this folder. **CC0-1.0** means the project dedicates
any rights it holds in these images to CC0-1.0, to the extent such rights
exist. Comparison sheets include this project's existing CC0 icons.

| File | Author | Date | Source / method | License |
|---|---|---|---|---|
"""
    for entry in manifest["assets"]:
        text += f"| `drop-01/{entry['path']}` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |\n"
    for i in range(1, 7):
        text += f"| `drop-01/preview-{i}.png` | GPT-6 Astra | 2026-10-20 | Pillow comparison of listed proposals and project-owned CC0 icons | **CC0-1.0** |\n"
    (HERE / "README.md").write_text(text)
    print("Wrote README and per-file media rows.")


def check():
    manifest = json.loads((DROP / "manifest.json").read_text())
    assets = manifest["assets"]
    expected = {(key, f"v{i}") for key, _, _ in ROWS for i in range(1, 4)}
    actual = [(entry["key"], entry["variant"]) for entry in assets]
    assert len(actual) == 108 and set(actual) == expected, "Missing or duplicate proposals"
    filenames = {f"{key.replace(':', '__')}_{variant}.png" for key, variant in expected}
    actual_pngs = {p.name for p in DROP.glob("*.png")}
    previews = {f"preview-{i}.png" for i in range(1, 7)}
    assert actual_pngs == filenames | previews, "Unexpected or missing PNG"
    assert len({entry["sha256"] for entry in assets}) == 108, "Duplicate final image"
    readme = (HERE / "README.md").read_text()
    for entry in assets:
        path = DROP / entry["path"]
        assert path.name in filenames and path.parent == DROP
        data = path.read_bytes()
        assert digest(data) == entry["sha256"], path
        assert data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR", path
        w, h, depth, colour, comp, filt, interlace = struct.unpack(">IIBBBBB", data[16:29])
        assert (w, h, depth, colour) == (64, 64, 8, 2), (path, w, h, depth, colour)
        with Image.open(path) as image:
            assert image.format == "PNG" and image.mode == "RGB" and image.size == (64, 64)
            assert "transparency" not in image.info
        assert entry["tree"] == dict((r[0], r[1]) for r in ROWS)[entry["key"]]
        assert entry["prompt"] and entry["processing"]["resampling"] == "Image.Resampling.LANCZOS"
        assert f"| `drop-01/{path.name}` | GPT-6 Astra | 2026-10-20 |" in readme, path
        source = Path(entry["source"]["path"])
        if source.exists():
            assert digest(source.read_bytes()) == entry["source"]["sha256"], source
        for ref in entry["reference"] or []:
            ref_path = ROOT / ref["path"]
            if not ref_path.exists() and Path(ref["path"]).is_absolute():
                assert len(ref["sha256"]) == 64 and len(ref["git_blob"]) == 40
                continue
            data = ref_path.read_bytes()
            assert digest(data) == ref["sha256"], ref
            blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            assert blob == ref["git_blob"], ref
    for ref in manifest["comparison_references"]:
        for kind in ("old", "current"):
            if kind in ref:
                record = ref[kind]
                data = git_bytes(record["revision"], record["path"])
                assert data and digest(data) == record["sha256"], record
                blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
                assert blob == record["git_blob"], record
    assert len(manifest["comparison_references"]) == 36
    assert len(manifest["previews"]) == 6
    assert {key for page in manifest["previews"] for key in page["rows"]} == {r[0] for r in ROWS}
    for page in manifest["previews"]:
        assert digest((DROP / page["path"]).read_bytes()) == page["sha256"]
    for name in previews:
        with Image.open(DROP / name) as image:
            assert image.size == (1090, 804) and image.mode == "RGB"
        assert f"| `drop-01/{name}` |" in readme
    print("PASS: 108 unique 64x64 opaque 8-bit RGB PNGs; 36 keys x v1-v3; SHA-256, references, six previews and 114 media rows.")


def game_path(row):
    key, _, name = row
    mod, kind = ("grug_abilities", "skill") if key.startswith("skill:") else ("grug_classes", "talent")
    return f"mods/PLAYER/{mod}/textures/{mod}_{kind}_{name}.png"


def git_bytes(rev, path):
    result = subprocess.run(["git", "show", f"{rev}:{path}"], cwd=ROOT, capture_output=True)
    return result.stdout if result.returncode == 0 else None


def digest(data):
    return hashlib.sha256(data).hexdigest()


def font(size=13):
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)


def paste_sizes(sheet, img, x, y, gray=False):
    for size in (64, 32, 16):
        thumb = img.convert("RGB") if size == 64 else img.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
        if gray:
            thumb = ImageOps.grayscale(thumb).convert("RGB")
        sheet.paste(thumb, (x, y + (64 - size) // 2))
        x += size + 10


def references():
    SCRATCH.mkdir(parents=True, exist_ok=True)
    records = []
    for row in ROWS:
        key, tree, _ = row
        path = game_path(row)
        entry = {"key": key, "tree": tree, "game_path": path}
        for label, rev in (("old", OLD), ("current", "HEAD")):
            data = git_bytes(rev, path)
            if data:
                out = SCRATCH / f"{key.replace(':', '__')}_{label}.png"
                out.write_bytes(data)
                entry[label] = {
                    "path": path,
                    "revision": subprocess.check_output(["git", "rev-parse", rev], cwd=ROOT, text=True).strip(),
                    "git_blob": subprocess.check_output(["git", "rev-parse", f"{rev}:{path}"], cwd=ROOT, text=True).strip(),
                    "sha256": digest(data),
                    "scratch_path": str(out),
                }
        records.append(entry)
    (SCRATCH / "references.json").write_text(json.dumps(records, indent=2) + "\n")
    for page in range(3):
        rows = records[page * 12:(page + 1) * 12]
        sheet = Image.new("RGB", (710, 72 + len(rows) * 84), "#15171c")
        draw = ImageDraw.Draw(sheet)
        draw.text((12, 12), "Reference study: 0.51 and current at 64 / 32 / 16 px", font=font(17), fill="#eee8da")
        draw.text((300, 43), "0.51", font=font(), fill="#ddd4c4")
        draw.text((490, 43), "Current", font=font(), fill="#ddd4c4")
        for i, entry in enumerate(rows):
            y = 72 + i * 84
            draw.text((10, y + 24), entry["key"], font=font(), fill="#eee8da")
            for label, x in (("old", 300), ("current", 490)):
                if label in entry:
                    paste_sizes(sheet, Image.open(entry[label]["scratch_path"]), x, y)
                else:
                    draw.text((x, y + 24), "not present", font=font(), fill="#746e68")
        sheet.save(SCRATCH / f"references-{page + 1}.png")
    print(f"Reference study: {len(records)} current, {sum('old' in r for r in records)} old icons; {SCRATCH}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["references", "prepare", "package", "preview", "context", "document", "check"])
    args = parser.parse_args()
    if args.command == "references":
        references()
    elif args.command == "prepare":
        prepare()
    elif args.command == "package":
        package()
    elif args.command == "preview":
        preview()
    elif args.command == "context":
        context()
    elif args.command == "document":
        document()
    elif args.command == "check":
        check()


if __name__ == "__main__":
    main()
