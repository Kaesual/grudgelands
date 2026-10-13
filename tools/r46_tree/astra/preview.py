#!/usr/bin/env python3
"""Software geometry preview for visual inspection where WebGL cannot start.

This is not a browser screenshot or a lighting reference. It rasterizes the
same node boxes and original textures with a simple directional light.
Requires installed NumPy and Pillow; downloads nothing.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from build import HERE, ROOT, SHAPES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skeleton", action="store_true")
    args = parser.parse_args()
    nodes = json.loads((HERE / "apple-nodes.json").read_text())
    cell = {(n["x"], n["y"], n["z"]): n for n in nodes}
    wood = {"trunk", "quarter", "branch", "twig"}
    directions = {"top": (0, 1, 0), "bottom": (0, -1, 0), "front": (0, 0, -1),
                  "back": (0, 0, 1), "left": (-1, 0, 0), "right": (1, 0, 0)}
    files = {"bark": "tree", "end": "tree_top", "leaf": "leaves", "apple": "apple", "grass": "grass"}
    textures = {key: np.array(Image.open(ROOT / f"mods/BASE/default/textures/default_{file}.png").convert("RGBA"))
                for key, file in files.items()}
    width, height = 1050, 1000
    pixels = np.zeros((height, width, 3), dtype=np.uint8)
    pixels[:] = (231, 235, 222)
    depth = np.full((height, width), np.inf)
    target = np.array([.35, 4.15, .3])
    direction = np.array([1., .45, 1.4])
    eye = target + 21 * direction / np.linalg.norm(direction)
    forward = (target - eye) / np.linalg.norm(target - eye)
    right = np.cross(forward, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    light = np.array([-9., 18., 10.]); light /= np.linalg.norm(light)
    focal = .5 * height / math.tan(math.radians(39 / 2))

    def triangle(points, uv, texture, normal):
        p = np.array(points) - eye
        z = p @ forward
        if np.any(z <= .1):
            return
        q = np.column_stack([width / 2 + focal * (p @ right) / z,
                             height / 2 - focal * (p @ up) / z])
        x0, y0 = np.maximum([0, 0], np.floor(q.min(axis=0)).astype(int))
        x1, y1 = np.minimum([width - 1, height - 1], np.ceil(q.max(axis=0)).astype(int))
        if x0 > x1 or y0 > y1:
            return
        x, y = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
        den = (q[1, 1] - q[2, 1]) * (q[0, 0] - q[2, 0]) + (q[2, 0] - q[1, 0]) * (q[0, 1] - q[2, 1])
        if abs(den) < 1e-8:
            return
        a = ((q[1, 1] - q[2, 1]) * (x - q[2, 0]) + (q[2, 0] - q[1, 0]) * (y - q[2, 1])) / den
        b = ((q[2, 1] - q[0, 1]) * (x - q[2, 0]) + (q[0, 0] - q[2, 0]) * (y - q[2, 1])) / den
        c = 1 - a - b
        inv = a / z[0] + b / z[1] + c / z[2]
        with np.errstate(divide="ignore", invalid="ignore"):
            distance = 1 / inv
        old = depth[y0:y1 + 1, x0:x1 + 1]
        mask = (a >= 0) & (b >= 0) & (c >= 0) & (distance < old)
        if not mask.any():
            return
        uv = np.array(uv)
        u = (a * uv[0, 0] / z[0] + b * uv[1, 0] / z[1] + c * uv[2, 0] / z[2]) * distance
        v = (a * uv[0, 1] / z[0] + b * uv[1, 1] / z[1] + c * uv[2, 1] / z[2]) * distance
        tex = textures[texture]
        u = np.floor(np.nan_to_num(u) * 16).astype(int) % 16
        v = np.floor((1 - np.nan_to_num(v)) * 16).astype(int) % 16
        rgba = tex[v, u]
        mask &= rgba[:, :, 3] >= 128
        rgb = np.clip(rgba[:, :, :3] * (.76 + .35 * max(0, np.dot(normal, light))), 0, 255).astype(np.uint8)
        old[mask] = distance[mask]
        pixels[y0:y1 + 1, x0:x1 + 1][mask] = rgb[mask]

    def quad(points, uv, texture, normal, double=False):
        if not double and np.dot(normal, eye - np.mean(points, axis=0)) <= 0:
            return
        for indices in [(0, 1, 2), (0, 2, 3)]:
            triangle([points[i] for i in indices], [uv[i] for i in indices], texture, normal)

    def box(pos, bounds, axis="y", rot=0, leaf=False, trunk=False):
        x0, y0, z0, x1, y1, z1 = np.array(bounds) / 16
        faces = [([(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0)], (0,1,0), "y"),
                 ([(x0,y0,z1),(x0,y0,z0),(x1,y0,z0),(x1,y0,z1)], (0,-1,0), "y"),
                 ([(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)], (1,0,0), "x"),
                 ([(x0,y0,z1),(x0,y1,z1),(x0,y1,z0),(x0,y0,z0)], (-1,0,0), "x"),
                 ([(x1,y0,z1),(x1,y1,z1),(x0,y1,z1),(x0,y0,z1)], (0,0,1), "z"),
                 ([(x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0)], (0,0,-1), "z")]
        for points, normal, face_axis in faces:
            uv = []
            for x, y, z in points:
                nx, ny, nz = normal
                for _ in range(rot):
                    x, z, nx, nz = -z, x, -nz, nx
                if ny > 0: u, v = x + .5, z + .5
                elif ny < 0: u, v = x + .5, .5 - z
                elif nx > 0: u, v = z + .5, y + .5
                elif nx < 0: u, v = .5 - z, y + .5
                elif nz > 0: u, v = .5 - x, y + .5
                else: u, v = x + .5, y + .5
                if (axis == "x" and not nx) or (axis == "z" and nx):
                    u, v = 1 - v, u
                uv.append((u, v))
            quad(np.array(points) + pos, uv, "leaf" if leaf else "end" if trunk and face_axis == "y" else "bark", normal)

    # Tessellation keeps ground triangles in front of the camera without a
    # near-plane clipping implementation in this small inspection renderer.
    for x in range(-20, 20):
        for z in range(-20, 20):
            quad([(x,-.5,z),(x,-.5,z+1),(x+1,-.5,z+1),(x+1,-.5,z)],
                 [(0,0),(0,1),(1,1),(1,0)], "grass", (0,1,0))
    for n in nodes:
        kind = n["kind"]
        if args.skeleton and kind in {"leaves", "fruit"}:
            continue
        pos = np.array([n["x"], n["y"], n["z"]])
        joins = {side: cell.get(tuple(pos + d), {}).get("kind") in wood for side, d in directions.items()}
        axis = "y"
        if kind in {"branch", "twig"}:
            scores = {"y": joins["top"] + joins["bottom"], "x": joins["left"] + joins["right"], "z": joins["front"] + joins["back"]}
            axis = max(scores, key=scores.get)
            shape = SHAPES[kind]
            boxes = [shape["core"]] + [b for side, b in shape["arms"].items() if joins[side]]
        elif kind == "quarter":
            boxes = []
            for source in SHAPES[kind]["boxes"]:
                x0, y0, z0, x1, y1, z1 = source
                for _ in range(n["rot"]):
                    x0, z0, x1, z1 = z0, -x1, z1, -x0
                boxes.append([x0, y0, z0, x1, y1, z1])
        elif kind == "fruit":
            for degrees in [46, -44]:
                a = math.radians(degrees)
                points = [(x*math.cos(a), y, x*math.sin(a)) for x,y in [(-.5,.5),(.5,.5),(.5,-.5),(-.5,-.5)]]
                quad(np.array(points) + pos, [(0,1),(1,1),(1,0),(0,0)], "apple", (-math.sin(a),0,math.cos(a)), True)
            continue
        else:
            boxes = [[-8,-8,-8,8,8,8]]
        for b in boxes:
            box(pos, b, axis, n["rot"], kind == "leaves", kind in {"quarter", "trunk"})
    image = Image.fromarray(pixels)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width, 32), fill=(246, 245, 237))
    draw.text((15, 10), "ASTRA / SOFTWARE GEOMETRY PREVIEW / " + ("SKELETON" if args.skeleton else "APPLE TREE") + " / NOT A BROWSER SCREENSHOT", fill=(40, 60, 42))
    out = HERE / "evidence"
    out.mkdir(exist_ok=True)
    path = out / ("software-skeleton.png" if args.skeleton else "software-tree.png")
    image.save(path)
    print(path)


if __name__ == "__main__":
    main()
