#!/usr/bin/env python3
"""Render a dependency-light contact sheet of generated material groups."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw


COLORS = ((151, 108, 67), (69, 163, 151), (242, 135, 48),
          (127, 107, 173), (190, 74, 82), (213, 195, 112))


def mesh(path: Path):
    vertices = []
    faces = []
    slot = 0
    for line in path.read_text().splitlines():
        match = re.match(r"g texture_slot_(\d+)$", line)
        if match:
            slot = int(match.group(1))
        elif line.startswith("v "):
            x, y, z = (float(value) for value in line.split()[1:4])
            # Match Luanti's OBJ handedness conversion, not the raw file.
            vertices.append((-x, y, z))
        elif line.startswith("f "):
            indices = [int(term.split("/")[0]) - 1 for term in line.split()[1:]]
            indices.reverse()
            faces.append((slot, indices))
    return vertices, faces


def project(vertex, center_x, center_y, scale):
    x, y, z = vertex
    return (center_x + (x - z) * scale,
            center_y + (-y + (x + z) * 0.32) * scale)


def render_one(draw, vertices, faces, box, title):
    left, top, right, bottom = box
    scale = min(right - left, bottom - top - 26) * 0.68
    center_x = (left + right) / 2
    center_y = (top + bottom) / 2 + 5
    ordered = []
    for slot, indices in faces:
        points_3d = [vertices[index] for index in indices]
        # Painter order for a camera at (+x,+y,-z).
        depth = sum(-x - y + z for x, y, z in points_3d) / len(points_3d)
        ordered.append((depth, slot, [project(vertex, center_x, center_y, scale)
                                      for vertex in points_3d]))
    for _, slot, points in sorted(ordered):
        color = COLORS[slot % len(COLORS)]
        draw.polygon(points, fill=color, outline=(45, 42, 38))
    draw.text((left + 6, bottom - 21), title, fill=(25, 25, 25))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    paths = sorted((args.repo / "mods/ITEMS/grug_decor/models").glob(
        "grug_decor_furnish_*.obj"))
    columns = 5
    tile_w, tile_h = 260, 230
    rows = math.ceil(len(paths) / columns)
    image = Image.new("RGB", (columns * tile_w, rows * tile_h), (237, 233, 222))
    draw = ImageDraw.Draw(image)
    for index, path in enumerate(paths):
        column, row = index % columns, index // columns
        box = (column * tile_w, row * tile_h,
               (column + 1) * tile_w, (row + 1) * tile_h)
        vertices, faces = mesh(path)
        title = path.stem.removeprefix("grug_decor_furnish_")
        render_one(draw, vertices, faces, box, title)
        draw.rectangle(box, outline=(185, 179, 165))
    image.save(args.output)
    print(f"R75 FURNISH PREVIEW {args.output} meshes={len(paths)}")


if __name__ == "__main__":
    main()
