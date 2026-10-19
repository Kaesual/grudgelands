#!/usr/bin/env python3
"""Round 52 ARTA pass 4: the 30 picked strips, shaded for alpha testing.

Run with python3 -I (Pillow). Read the actual drop-03 picks, retain their
pixel paths and phases, and replace alpha shading with authored RGB ramps.
Only staged media are written; no game files, earlier drops or Lua runs.
"""

import argparse
import json
import runpy
from pathlib import Path
from types import SimpleNamespace

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
# Reuse inspected geometry, exclusion maps and weapon/enchant preview inputs.
# run_path works with -I without changing sys.path or writing bytecode caches.
OLD_CODE = HERE / "arta_fx3.py"
OLD = SimpleNamespace(**runpy.run_path(str(OLD_CODE)))
SOURCE = HERE / "drop-03"
SOURCE_COMMIT = "94bbadbd"
PICKS = {
    "mage": {
        "ember": {"staff": 1, "wand": 1, "dagger": 1},
        "rime": {"staff": 1, "wand": 1, "dagger": 1},
    },
    "priest": {
        "mercy": {"staff": 2, "wand": 1, "dagger": 1},
        "reckoning": {"staff": 1, "wand": 2, "dagger": 2},
    },
    "warrior": {
        "bulwark": {"sword": 2, "dagger": 1, "greataxe": 1},
        "ruin": {"sword": 1, "dagger": 1, "greataxe": 1},
    },
    "scout": {
        "quarry": {"bow": 1, "sword": 1, "dagger": 1},
        "veil": {"bow": 1, "sword": 1, "dagger": 1},
    },
}
TIMING = {"ember": (8, 120), "rime": (12, 260), "bulwark": (12, 180),
          "ruin": (10, 160), "mercy": (12, 280), "reckoning": (12, 160),
          "quarry": (12, 260), "veil": (12, 280)}
PEAK = {"ember": 2, "rime": 5, "bulwark": 2, "ruin": 2,
        "mercy": 5, "reckoning": 2, "quarry": 5, "veil": 5}

# Keys are the selected source pixels' exact RGBA, values opaque RGB.
# Low-alpha shades become darker, less saturated colour, never alpha blend.
# Bright crests contrast with steel; dark shoulders keep them legible on pale
# materials. Veil retains violet shadow with a small separate silver edge.
PALETTES = {
    "ember": {
        (213, 57, 23, 176): (225, 65, 27),
        (239, 90, 25, 96): (158, 62, 39),
        (255, 132, 28, 176): (255, 151, 45),
        (255, 190, 62, 96): (177, 112, 54),
        (255, 190, 62, 176): (255, 198, 81),
        (255, 204, 87, 176): (255, 225, 135),
    },
    "rime": {
        (111, 159, 198, 96): (73, 108, 148),
        (128, 198, 230, 96): (68, 132, 164),
        (128, 198, 230, 176): (112, 201, 232),
        (225, 248, 255, 96): (92, 166, 197),
        (225, 248, 255, 176): (199, 241, 255),
        (225, 248, 255, 255): (244, 253, 255),
    },
    "bulwark": {
        (105, 148, 175, 96): (65, 102, 143),
        (125, 157, 180, 96): (82, 144, 191),
        (173, 203, 223, 176): (124, 184, 222),
        (213, 232, 244, 176): (145, 212, 246),
        (213, 232, 244, 255): (227, 247, 255),
        (242, 247, 249, 255): (250, 253, 255),
    },
    "ruin": {
        (167, 25, 34, 96): (116, 39, 49),
        (167, 25, 34, 176): (190, 42, 51),
        (167, 25, 34, 255): (238, 62, 53),
        (193, 33, 41, 96): (168, 62, 78),
        (193, 33, 41, 176): (220, 51, 54),
        (193, 33, 41, 255): (255, 80, 57),
        (234, 56, 43, 176): (247, 91, 58),
        (239, 74, 43, 96): (146, 66, 46),
        (239, 74, 43, 176): (255, 113, 57),
        (255, 94, 57, 176): (255, 125, 70),
        (255, 94, 57, 255): (255, 162, 85),
    },
    "mercy": {
        (230, 181, 95, 96): (125, 91, 49),
        (253, 230, 170, 96): (176, 143, 83),
        (253, 230, 170, 176): (255, 231, 176),
        (255, 237, 187, 96): (202, 166, 104),
        (255, 237, 187, 176): (255, 230, 162),
        (255, 247, 218, 176): (255, 251, 224),
    },
    "reckoning": {
        (185, 148, 62, 96): (225, 172, 91),
        (193, 32, 63, 176): (166, 49, 67),
        (193, 32, 63, 255): (212, 42, 67),
        (237, 188, 70, 176): (239, 181, 69),
        (255, 211, 83, 255): (255, 208, 70),
        (255, 250, 223, 255): (255, 250, 223),
    },
    "quarry": {
        (48, 132, 123, 96): (47, 102, 103),
        (56, 141, 112, 96): (62, 132, 117),
        (67, 152, 130, 96): (58, 120, 110),
        (67, 152, 130, 176): (95, 190, 159),
        (79, 192, 171, 96): (64, 139, 132),
        (79, 192, 171, 176): (101, 218, 185),
        (128, 187, 119, 96): (85, 140, 113),
        (128, 187, 119, 176): (150, 215, 144),
        (141, 185, 76, 96): (106, 143, 67),
        (141, 185, 76, 176): (179, 216, 101),
    },
    "veil": {
        (35, 25, 47, 96): (60, 45, 78),
        (38, 27, 53, 96): (73, 52, 96),
        (124, 83, 163, 96): (99, 77, 124),
        (124, 83, 163, 176): (163, 111, 208),
        (132, 131, 155, 96): (114, 107, 147),
        (181, 180, 204, 96): (166, 164, 205),
        (190, 185, 214, 96): (146, 136, 181),
        (190, 185, 214, 176): (210, 198, 235),
    },
}


def cutout(im):
    """The wield overlay rule, applied before layering onto the weapon."""
    out = Image.new("RGBA", im.size)
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if a >= 128:
                out.putpixel((x, y), (r, g, b, 255))
    return out


def occupied(im, threshold=1):
    return {(x, y) for y in range(im.height) for x in range(im.width)
            if im.getpixel((x, y))[3] >= threshold}


def rework(source, family, shape, variant):
    out = Image.new("RGBA", (16, 16))
    for point in sorted(occupied(source)):
        out.putpixel(point, (*PALETTES[family][source.getpixel(point)], 255))
    g = OLD.COMPOSITIONS[shape][variant - 1]
    supports = []
    if family == "ember" and shape in ("wand", "dagger"):
        supports = [(g["plume"][1], (158, 62, 39))]
    elif family == "rime":
        supports = [(g["mark"][1], (57, 105, 144))]
    elif family == "bulwark":
        supports = [(g["edge"][-2], (53, 100, 137))]
        if g["aux"]:
            supports.append((g["aux"][-1], (70, 123, 163)))
    elif family == "reckoning":
        supports = [(g["mark"][1], (126, 86, 49))]
    elif family == "quarry" and not shape.startswith("bow"):
        supports = [(g["edge"][1], (47, 102, 103))]
    elif family == "veil" and shape == "dagger":
        # The selected dagger's plume base overwrote its silver tip at (9, 5).
        # Separate that fixed silver point onto the adjacent blade pixel.
        supports = [(g["edge"][-2], (186, 180, 223))]
    # Fixed shoulders only fill empty pixels in the picked composition.
    # They never replace a travelling glint or move a particle.
    for point, rgb in supports:
        if not out.getpixel(point)[3]:
            out.putpixel(point, (*rgb, 255))
    return out


def composite(effect, weapon, scale=8):
    return OLD.composite(cutout(effect), cutout(weapon), scale)


def pair(canvas, xy, before, after, weapon, label):
    x, y = xy
    d = ImageDraw.Draw(canvas)
    d.fontmode = "1"
    d.text((x, y), label, fill=(213, 221, 230))
    d.text((x, y + 17), "OLD / alpha test", fill=(156, 166, 185))
    d.text((x + 140, y + 17), "NEW / opaque", fill=(177, 226, 195))
    canvas.paste(composite(before, weapon), (x, y + 34))
    canvas.paste(composite(after, weapon), (x + 140, y + 34))


def animated_preview(family, shape, variant, before, after, samples):
    cols = min(4, len(samples))
    rows = (len(samples) + cols - 1) // cols
    width, height = 24 + cols * 290, 72 + rows * 182
    frames = []
    for phase, (old, new) in enumerate(zip(before, after)):
        im = Image.new("RGB", (width, height), (21, 25, 33))
        d = ImageDraw.Draw(im)
        d.fontmode = "1"
        d.text((12, 8), f"{family.upper()} / {shape} / picked v{variant}", fill=(240, 238, 229))
        d.text((12, 26), f"{OLD.clock_label(family)} | 8x nearest | alpha <128 dropped, >=128 opaque",
               fill=(180, 190, 202))
        for i, (label, base) in enumerate(samples):
            pair(im, (12 + i % cols * 290, 49 + i // cols * 182), old, new, base, label)
        # Keep every hold frame encoded with its exact duration.
        d.text((12, height - 18), f"FRAME {phase + 1:02}/{len(after)} | real speed | OLD {len(occupied(old, 128))} px -> NEW {len(occupied(new))} px",
               fill=(139, 155, 176))
        frames.append(im)
    # An exact shared palette: no dithering or approximated effect colours.
    colors = sorted({c for im in frames for _, c in im.getcolors(im.width * im.height)})
    assert len(colors) <= 256, (family, shape, len(colors))
    palette = [v for c in colors for v in c] + [0] * (768 - 3 * len(colors))
    indices = {c: i for i, c in enumerate(colors)}
    indexed = []
    for im in frames:
        local = im.quantize(256, dither=Image.Dither.NONE)
        rgb = local.getpalette()
        # Remap exact local indices; Pillow's nearest-colour palette lookup
        # caches nearby RGB values together even when both are in the palette.
        remap = [indices.get(tuple(rgb[i:i + 3]), 0) for i in range(0, len(rgb), 3)]
        shared = local.point(remap + [0] * (256 - len(remap)))
        shared.putpalette(palette)
        indexed.append(shared)
    assert all(a.tobytes() == b.convert("RGB").tobytes() for a, b in zip(frames, indexed))
    return indexed


def preview_sheet(assets, frames, samples):
    cell_w, sub_h = 588, 200
    width = 24 + 3 * cell_w
    height = 80 + sum(42 + 2 * (30 + sub_h * (4 if cls == "scout" else 1)) for cls in PICKS)
    sheet = Image.new("RGB", (width, height), (21, 25, 33))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    d.text((12, 10), "ARTA / DROP 04 - THE PICKED OVERLAYS, WITH OPAQUE PIXEL SHADING", fill=(240, 238, 229))
    d.text((12, 29), "Every pair: OLD pick left / NEW strip right. Both use the engine alpha test. Exactly 8x.", fill=(180, 190, 202))
    d.text((12, 48), "One band per class; all 30 strips. GIFs show all materials, quiet phases and the complete real-speed loop.", fill=(180, 190, 202))
    y = 80
    for cls, families in PICKS.items():
        d.rectangle((10, y, width - 12, y + 28), fill=(43, 51, 66))
        d.text((20, y + 8), cls.upper(), fill=(247, 238, 216))
        y += 42
        for family, weapons in families.items():
            phase = PEAK[family]
            d.text((12, y + 6), f"{family.upper()} | {OLD.clock_label(family)} | FRAME {phase + 1:02}", fill=(224, 215, 190))
            y += 30
            for col, weapon in enumerate(weapons):
                for stage, shape in enumerate(OLD.shapes_for(weapon)):
                    key = f"{family}_{shape}"
                    entry = assets[key]
                    old, new = frames[key]
                    x, yy = 12 + col * cell_w, y + stage * sub_h
                    d.text((x, yy), f"{key} / picked v{entry['source_pick']['variant']}", fill=(240, 238, 229))
                    refs = samples[shape]
                    if weapon != "bow":
                        refs = [next(s for s in refs if s[0] == "iron"), refs[-1]]
                    else:
                        refs = refs[:2] if shape == "bow" else refs[:1]
                    for i, (label, base) in enumerate(refs):
                        pair(sheet, (x + i * 282, yy + 18), old[phase], new[phase], base, label)
            y += sub_h * (4 if "bow" in weapons else 1)
    return sheet


def coverage(frames):
    counts = [len(occupied(f, 128)) for f in frames]
    return dict(total=sum(counts), per_frame=counts, empty_frames=counts.count(0))


def check_asset(out, entry, old, new, shape, gif_frames, samples):
    n, ms = TIMING[entry["family"]]
    strip = OLD.load(out / entry["file"])
    assert strip.size == (16, n * 16)
    assert set(strip.getchannel("A").tobytes()) == {0, 255}
    assert all(p[3] or p == (0, 0, 0, 0) for p in OLD.pixels(strip))
    assert OLD.sha((out / entry["file"]).read_bytes()) == entry["sha256"]
    footprint = set().union(*(occupied(f) for f in old))
    extra = {(8, 6)} if entry["family"] == "veil" and shape == "dagger" else set()
    forbidden = OLD.GRIPS[shape] | OLD.STRINGS.get(shape, set())
    for i, frame in enumerate(new):
        assert strip.crop((0, i * 16, 16, (i + 1) * 16)).tobytes() == frame.tobytes()
        assert not occupied(frame) & forbidden, (entry["file"], i)
        assert occupied(frame) <= footprint | extra, (entry["file"], "changed footprint")
        assert occupied(old[i]) <= occupied(frame), (entry["file"], "lost source motion")
        assert 2 <= len(occupied(frame)) <= 9, (entry["file"], i)
    assert new[-1].tobytes() == new[0].tobytes(), entry["file"]
    assert len({f.tobytes() for f in new}) >= 3
    assert entry["visible_pixels"]["new"]["empty_frames"] * 3 <= n
    # Report the weakest frame's strongest RGB contrast against each actual
    # material/enchant preview, on the same checker background, at 16 px.
    contrast = {}
    blank = Image.new("RGBA", (16, 16))
    for label, base in samples:
        bare = composite(blank, base, 1)
        strengths = []
        for effect in new:
            shown = composite(effect, base, 1)
            strengths.append(max(max(abs(a - b) for a, b in zip(shown.getpixel(p), bare.getpixel(p)))
                                 for p in occupied(effect)))
        contrast[label] = min(strengths)
        assert min(strengths) >= 48, (entry["file"], label, strengths)
    with Image.open(out / entry["gif"]["file"]) as gif:
        assert gif.n_frames == n and gif.info["loop"] == 0
        for i in range(n):
            gif.seek(i)
            assert gif.info["duration"] == ms
            assert gif.convert("RGB").tobytes() == gif_frames[i].convert("RGB").tobytes()
    return dict(file=entry["file"], alpha_levels=[0, 255], size=list(strip.size),
                visible_pixels=entry["visible_pixels"], grip_or_string_pixels=0,
                original_motion_pixels_retained=True,
                added_footprint_pixels=sorted(set().union(*(occupied(f) for f in new)) - footprint),
                seam_delta=0, distinct_frames=len({f.tobytes() for f in new}),
                minimum_peak_rgb_contrast_by_sample=contrast,
                gif_frames=n, gif_frame_ms=ms, gif_exact_rgb_roundtrip=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=HERE / "drop-04")
    args = parser.parse_args()
    out = args.out.resolve()
    for protected in [REPO / "mods", *(p for p in HERE.glob("drop-*") if p.name != "drop-04")]:
        protected = protected.resolve()
        if out == protected or protected in out.parents or out in protected.parents:
            raise SystemExit(f"Protected output location: {protected}")
    old_manifest = json.loads((SOURCE / "manifest.json").read_text())
    assert old_manifest["generator"]["sha256"] == OLD.sha(OLD_CODE.read_bytes())
    source_entries = {e["path"]: e for e in old_manifest["assets"]}
    assert TIMING == OLD.TIMING
    OLD.validate_paths()
    entries, checks, frame_pairs, all_samples = {}, [], {}, {}
    for cls, families in PICKS.items():
        for family, weapons in families.items():
            n, ms = TIMING[family]
            for weapon, variant in weapons.items():
                for shape in OLD.shapes_for(weapon):
                    key = f"{family}_{shape}"
                    pick = f"fx/{cls}/{key}_v{variant}.png"
                    src = source_entries[pick]
                    path = SOURCE / pick
                    assert src["sha256"] == OLD.sha(path.read_bytes())
                    assert (src["frames"], src["frame_ms"]) == (n, ms)
                    strip = OLD.load(path)
                    assert strip.size == (16, n * 16)
                    old = [strip.crop((0, i * 16, 16, (i + 1) * 16)) for i in range(n)]
                    new = [rework(f, family, shape, variant) for f in old]
                    frame_pairs[key] = old, new
                    filename = f"grug_abilities_fx_{key}.png"
                    revised = Image.new("RGBA", strip.size)
                    for i, frame in enumerate(new):
                        revised.paste(frame, (0, i * 16))
                    data = OLD.encoded(revised, optimize=True)
                    OLD.write_new(out / filename, data)
                    samples, paths = OLD.weapons(shape)
                    all_samples[shape] = samples
                    gif_frames = animated_preview(family, shape, variant, old, new, samples)
                    gif_data = OLD.encoded(gif_frames[0], "GIF", save_all=True, append_images=gif_frames[1:],
                                           duration=ms, loop=0, disposal=2, optimize=False)
                    gif_name = filename.replace(".png", ".gif")
                    OLD.write_new(out / gif_name, gif_data)
                    entry = dict(file=filename, **{"class": cls}, family=family, weapon=weapon,
                                 stage=src["stage"], frames=n, frame_s=ms / 1000,
                                 loop_s=n * ms / 1000, sha256=OLD.sha(data), license="CC0-1.0",
                                 source_pick=dict(file=path.relative_to(REPO).as_posix(),
                                                  variant=variant, commit=SOURCE_COMMIT, sha256=src["sha256"]),
                                 visible_pixels=dict(old=coverage(old), new=coverage(new)),
                                 gif=dict(file=gif_name, sha256=OLD.sha(gif_data), scale=8,
                                          frames=n, frame_s=ms / 1000, license=OLD.source_license(paths[0]),
                                          samples=[name for name, _ in samples],
                                          sources=[OLD.source_record(p) for p in paths],
                                          enchant_stats=OLD.enchant_stats(shape),
                                          enchant_rendering=src["gif"]["enchant_rendering"]))
                    entries[key] = entry
                    checks.append(check_asset(out, entry, old, new, shape, gif_frames, samples))
    assert len(entries) == 30 and len({e["sha256"] for e in entries.values()}) == 30
    sheet = OLD.encoded(preview_sheet(entries, frame_pairs, all_samples), optimize=True)
    OLD.write_new(out / "preview.png", sheet)
    summary = {}
    for family, (n, ms) in TIMING.items():
        selected = [e for e in entries.values() if e["family"] == family]
        assert {(e["frames"], e["frame_s"]) for e in selected} == {(n, ms / 1000)}
        summary[family] = dict(strips=len(selected), frames_per_strip=n, frame_s=ms / 1000,
                               frame_instances=n * len(selected),
                               visible_pixels={side: sum(e["visible_pixels"][side]["total"] for e in selected)
                                               for side in ("old", "new")},
                               empty_frames={side: sum(e["visible_pixels"][side]["empty_frames"] for e in selected)
                                             for side in ("old", "new")})
    inputs = [Path(__file__), OLD_CODE, SOURCE / "manifest.json", OLD.GEAR.parent / "enchant_colors.lua"]
    manifest = dict(schema=4, lane="ARTA", drop="04", date="2026-10-20", classification="compatible",
                    author="GPT-6 Astra (Grudgelands)",
                    paths_relative_to="manifest directory; source and code paths relative to repository",
                    count_note="24 picked family/weapon combinations plus 6 bow draw stages = 30 strips",
                    preview_rule="Threshold each overlay before layering: alpha < 128 drops, >= 128 becomes 255",
                    count_unit="Visible effect pixels summed across every frame of every strip; old uses the same threshold",
                    animation=dict(type="vertical_frames", frame_size=[16, 16], alpha_levels=[0, 255]),
                    families=summary, assets=list(entries.values()),
                    preview=dict(file="preview.png", sha256=OLD.sha(sheet), license="CC-BY-SA-4.0",
                                 frame_index_zero_based=PEAK),
                    generator=dict(file=Path(__file__).relative_to(REPO).as_posix(), license="GPL-3.0-or-later",
                                   inputs=[dict(file=p.relative_to(REPO).as_posix(), sha256=OLD.sha(p.read_bytes())) for p in inputs]))
    OLD.write_new(out / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())
    OLD.write_new(out / "checks.json", (json.dumps(dict(
        scope="Media checks only; no fixtures, Lua execution or engine runs",
        strip_count=30, gif_count=30, family_timing_unchanged=True,
        monotone_particle_paths=True, assets=checks), indent=2) + "\n").encode())
    assert {p.name for p in out.glob("*.png")} == {e["file"] for e in entries.values()} | {"preview.png"}
    assert {p.name for p in out.glob("*.gif")} == {e["gif"]["file"] for e in entries.values()}
    for family, row in summary.items():
        v, empty = row["visible_pixels"], row["empty_frames"]
        print(f"{family}: visible pixels {v['old']} -> {v['new']}; empty frames {empty['old']} -> {empty['new']} / {row['frame_instances']}")
    print("30 strips + 30 GIFs + preview.png; media checks PASS")


if __name__ == "__main__":
    main()
