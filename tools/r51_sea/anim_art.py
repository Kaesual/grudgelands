#!/usr/bin/env python3
"""Original Round 51 FA pixel animation, GPT-6 Astra, CC0-1.0.

python3 -I tools/r51_sea/anim_art.py [--check]
Reads only our three CC0 seagrass sprites and our existing pixel lettering.
Writes only anim/: four strips, a contact sheet and five looping GIFs.
"""

import argparse
import math
import runpy
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
OUT = HERE / "anim"
CLEAR = (0, 0, 0, 0)
NEAREST = Image.Resampling.NEAREST
FRAMES = 8
FRAME_MS = 400
LOOP_SECONDS = FRAMES * FRAME_MS / 1000
NAMES = ("seagrass_1_anim", "seagrass_2_anim", "seagrass_3_anim", "kelp_anim")

# Reuse the original CC0 hand-lettered alphabet, without running its generator.
lettering = runpy.run_path(str(HERE / "sea_art.py"))
label = lettering["label"]
color = lettering["color"]


def pixels(im):
    return list(im.get_flattened_data())


def source_grass(number):
    with Image.open(HERE / f"seagrass_{number}.png") as im:
        assert im.mode == "RGBA" and im.size == (16, 16)
        return im.copy()


def kelp_drawing():
    """New sparse, alternating leaves; a two-pixel stem crosses both edges."""
    return lettering["sprite"]([
        ".......hm.......",
        ".......hm.......",
        "...ll..hm.......",
        "..lhlm.hm.......",
        "....lmshm.......",
        "......mhm.......",
        ".......hm..ll...",
        ".......hmslhlm..",
        ".......hmmlm....",
        ".......hmm......",
        "..ll...hm.......",
        "..lhlm.hm.......",
        "....lmshm.......",
        "......mhm.......",
        ".......hm.......",
        ".......hm.......",
    ], {"s": "4e5d36", "m": "6f7e43", "l": "929e55", "h": "acb46b"})


def displacement(name, x, y, frame):
    phase = math.tau * (frame % FRAMES) / FRAMES
    if name == "kelp_anim":
        # One travelling bend per node. Duplicate boundary samples give equal
        # first/last RGBA rows, with the same stem colours on either side.
        return round(1.3 * math.sin(math.tau * y / 15 - phase))
    number = int(name[9])
    height = min(1, max(0, (13 - y) / (10 - number))) ** 0.8
    # Fixed bottom three rows; delayed lower blades, slightly different tip
    # phases. All variants share one clock but have distinct authored phases.
    phase += (0, 2, 5)[number - 1] * math.tau / FRAMES
    lag = 1.5 * (1 - height) + 0.24 * (x - 7.5) / 7.5
    return round(1.3 * height * math.sin(phase - lag))


def animate(source, name, frame):
    """Move whole texels; repair stretched diagonals without filtering alpha."""
    out = Image.new("RGBA", (16, 16), CLEAR)
    mapped = {}
    for y in range(16):
        for x in range(16):
            p = source.getpixel((x, y))
            if p[3]:
                tx = x + displacement(name, x, y, frame)
                assert 0 <= tx < 16, (name, frame, "clipped pixel", x, y)
                mapped[x, y] = (tx, p)
    # A one-pixel diagonal must stay joined when neighbouring rows shear.
    # Draw the connecting texel first so the preserved source colours win.
    for (x, y), (tx, p) in mapped.items():
        for nx in range(x - 1, x + 2):
            neighbour = mapped.get((nx, y + 1))
            if neighbour and abs(neighbour[0] - tx) == 2:
                out.putpixel(((neighbour[0] + tx) // 2, y + 1), neighbour[1])
    for (x, y), (tx, p) in mapped.items():
        out.putpixel((tx, y), p)
    return out


def make_frames():
    sources = {f"seagrass_{n}_anim": source_grass(n) for n in range(1, 4)}
    sources["kelp_anim"] = kelp_drawing()
    frames = {name: [animate(src, name, f) for f in range(FRAMES)]
              for name, src in sources.items()}
    return sources, frames


def stack(frames):
    out = Image.new("RGBA", (16, 16 * len(frames)), CLEAR)
    for i, im in enumerate(frames):
        out.paste(im, (0, 16 * i))
    return out


def enlarged(im):
    return im.resize((im.width * 4, im.height * 4), NEAREST)


def checker(size):
    im = Image.new("RGBA", size, color("253a3d"))
    draw = ImageDraw.Draw(im)
    for y in range(0, im.height, 4):
        for x in range(0, im.width, 4):
            if (x // 4 + y // 4) % 2:
                draw.rectangle((x, y, x + 3, y + 3), fill=color("2c4446"))
    return im


def contact_sheet(frames):
    out = Image.new("RGBA", (888, 588), color("14282d"))
    label(out, 24, 20, "GRUDGELANDS / SLOW WATER", scale=3)
    label(out, 24, 51, "8 frames / 3.2 seconds / 4x nearest / CC0", scale=2)
    for f in range(FRAMES):
        label(out, 272 + f * 76, 81, f"{f + 1:02}", scale=2)
    for row, name in enumerate(NAMES):
        y = 106 + row * 112
        label(out, 24, y + 15, name + ".png", scale=2)
        label(out, 24, y + 36, "16x128 / 400ms per frame", scale=1)
        label(out, 24, y + 50, "3.2s loop", scale=2)
        for f, im in enumerate(frames[name]):
            tile = checker((16, 16))
            tile.alpha_composite(im)
            out.alpha_composite(enlarged(tile), (248 + f * 76, y))
    label(out, 24, 558, "Read left to right / 08 returns to 01 / kelp edges join in every frame", scale=2)
    return out


def individual_preview(name, frames):
    result = []
    for im in frames:
        tile = checker((16, 96 if name == "kelp_anim" else 16))
        for y in range(0, tile.height, 16):
            tile.alpha_composite(im, (0, y))
        result.append(enlarged(tile))
    return result


def tint(im, mix=22):
    """Own illustrative water colour, not an engine lighting simulation."""
    water = (40, 104, 115)
    out = im.copy()
    out.putdata([tuple((p[c] * (100 - mix) + water[c] * mix) // 100
                       for c in range(3)) + (p[3],) if p[3] else CLEAR
                 for p in pixels(im)])
    return out


def meadow(frames):
    # Original sand and water, drawn here: no default texture pixels or fonts.
    background = Image.new("RGBA", (160, 124), color("244951"))
    draw = ImageDraw.Draw(background)
    for y in range(108):
        band = y // 12
        draw.line((0, y, 159, y), fill=(43 - band, 83 - 2 * band, 90 - 2 * band, 255))
    draw.rectangle((0, 108, 159, 123), fill=color("a2a082"))
    for y in range(108, 124):
        for x in range(160):
            grain = (x * 17 + y * 23 + (x // 5) * 11) % 43
            if grain < 3:
                background.putpixel((x, y), color("b6b08e"))
            elif grain == 7:
                background.putpixel((x, y), color("8d927a"))
    background = tint(background, 13)
    result = []
    for f in range(FRAMES):
        scene = background.copy()
        # The two kelp stalks and every segment deliberately share frame f.
        for x, nodes in ((26, 6), (117, 5)):
            im = tint(frames["kelp_anim"][f])
            for y in range(108 - nodes * 16, 108, 16):
                scene.alpha_composite(im, (x, y))
        for x, n, base in ((4, 2, 108), (19, 1, 108), (36, 3, 108),
                           (52, 2, 108), (66, 3, 108), (82, 1, 108),
                           (96, 2, 108), (111, 3, 108), (129, 1, 108),
                           (143, 2, 108)):
            scene.alpha_composite(tint(frames[f"seagrass_{n}_anim"][f]), (x, base - 16))
        scene = enlarged(scene)
        label(scene, 16, 16, "SLOW WATER / 3.2s / 4x", scale=2)
        label(scene, 16, 474, "Original sand + water tint / art preview", scale=2)
        result.append(scene)
    return result


def png_bytes(im):
    stream = BytesIO()
    im.save(stream, format="PNG")
    return stream.getvalue()


def gif_bytes(frames):
    # One exact palette for the entire loop prevents palette flicker. The
    # previews are opaque and use fewer than 256 colours, so no quantization.
    colors = sorted({p[:3] for im in frames for p in pixels(im)})
    assert len(colors) <= 256, len(colors)
    indices = {p: i for i, p in enumerate(colors)}
    palette = [c for p in colors for c in p] + [0] * (768 - len(colors) * 3)
    indexed = []
    for im in frames:
        out = Image.new("P", im.size)
        out.putpalette(palette)
        out.putdata([indices[p[:3]] for p in pixels(im)])
        indexed.append(out)
    stream = BytesIO()
    indexed[0].save(stream, format="GIF", save_all=True, append_images=indexed[1:],
                    loop=0, duration=FRAME_MS, disposal=2, optimize=False)
    return stream.getvalue()


def validate_motion(sources, frames):
    for name, sequence in frames.items():
        source = sources[name]
        assert len({im.tobytes() for im in sequence}) == FRAMES, (name, "duplicate frames")
        assert animate(source, name, FRAMES).tobytes() == sequence[0].tobytes()
        diffs = []
        for f, im in enumerate(sequence):
            assert im.mode == "RGBA" and im.size == (16, 16)
            assert set(pixels(im)) <= set(pixels(source)), (name, "palette changed")
            assert all(p[3] in (0, 255) and (p[3] or p == CLEAR) for p in pixels(im))
            # Pixel-art diagonals count as connected. No blade or leaf may
            # turn into a detached fragment during the bend.
            remaining = {(x, y) for y in range(16) for x in range(16)
                         if im.getpixel((x, y))[3]}
            pending = [remaining.pop()]
            while pending:
                x, y = pending.pop()
                neighbours = {(x + dx, y + dy) for dx in (-1, 0, 1)
                              for dy in (-1, 0, 1)} & remaining
                remaining -= neighbours
                pending.extend(neighbours)
            assert not remaining, (name, f, "detached blade or leaf")
            following = sequence[(f + 1) % FRAMES]
            diffs.append(sum(a != b for a, b in zip(pixels(im), pixels(following))))
            for y in range(16):
                for x in range(16):
                    if source.getpixel((x, y))[3]:
                        assert abs(displacement(name, x, y, f + 1)
                                   - displacement(name, x, y, f)) <= 1
            if name.startswith("seagrass"):
                assert (im.crop((0, 13, 16, 16)).tobytes()
                        == source.crop((0, 13, 16, 16)).tobytes())
            else:
                assert (im.crop((0, 0, 16, 1)).tobytes()
                        == im.crop((0, 15, 16, 16)).tobytes())
                # A continuous overlapping two-pixel stem through every row,
                # including the join between any two of up to 15 repeats.
                last = None
                for y in range(16 * 15):
                    sy = y % 16
                    x = 7 + displacement(name, 7, sy, f)
                    assert im.getpixel((x, sy)) == color("acb46b")
                    assert im.getpixel((x + 1, sy)) == color("6f7e43")
                    assert last is None or abs(x - last) <= 1
                    last = x
        assert 0 < diffs[-1] <= max(diffs[:-1]), (name, "loop cut", diffs)
        print(f"{name}: 16x128 RGBA, 8 unique frames, binary alpha; "
              f"changed texels per step {diffs}; wrap <= interior max; source motion <= 1px")


def validate_gif(data, expected):
    with Image.open(BytesIO(data)) as gif:
        assert gif.n_frames == FRAMES and gif.info["loop"] == 0
        for f, im in enumerate(expected):
            gif.seek(f)
            assert gif.info["duration"] == FRAME_MS
            assert gif.size == im.size and gif.convert("RGBA").tobytes() == im.tobytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify committed files without writing")
    args = parser.parse_args()
    sources, frames = make_frames()
    validate_motion(sources, frames)
    artifacts = {name + ".png": png_bytes(stack(seq)) for name, seq in frames.items()}
    artifacts["preview.png"] = png_bytes(contact_sheet(frames))
    previews = {name + ".gif": individual_preview(name, seq) for name, seq in frames.items()}
    previews["meadow.gif"] = meadow(frames)
    for name, sequence in previews.items():
        artifacts[name] = gif_bytes(sequence)
        validate_gif(artifacts[name], sequence)
    if args.check:
        for name, data in artifacts.items():
            assert (OUT / name).read_bytes() == data, f"Stale asset: {name}"
    else:
        OUT.mkdir(exist_ok=True)
        for name, data in artifacts.items():
            (OUT / name).write_bytes(data)
    print(f"{'Checked' if args.check else 'Wrote'} {len(artifacts)} files; "
          f"all GIFs exact RGB, {FRAMES} x {FRAME_MS}ms = {LOOP_SECONDS}s, infinite loop.")


if __name__ == "__main__":
    main()
