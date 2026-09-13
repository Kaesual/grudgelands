#!/usr/bin/env python3
"""Compare sampled authoritative height surfaces, not client-rendered terrain."""
import argparse
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LightSource, Normalize
import numpy as np

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("before", type=Path)
parser.add_argument("after", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)


def read(path):
    result = {}
    with path.open() as stream:
        for row in csv.DictReader(stream, delimiter="\t"):
            result.setdefault(row["site"], {})[(int(row["x"]), int(row["z"]))] = int(row["y"])
    return result


before, after = read(args.before), read(args.after)
assert before.keys() == after.keys()
fig, axes = plt.subplots(3, 2, figsize=(12, 15), constrained_layout=True)
lines, line_axes = plt.subplots(3, 1, figsize=(12, 9), constrained_layout=True)
receipts = ["site\tversion\tmin_y\tmax_y\tmax_sample_grade\tp95_sample_grade\n"]
light = LightSource(azdeg=315, altdeg=45)
for index, site in enumerate(before):
    assert before[site].keys() == after[site].keys()
    xs = sorted({x for x, _ in before[site]})
    zs = sorted({z for _, z in before[site]})
    assert len(xs) * len(zs) == len(before[site])
    grids = [np.array([[data[site][x, z] for x in xs] for z in zs], dtype=float)
             for data in (before, after)]
    low, high = min(g.min() for g in grids), max(g.max() for g in grids)
    norm = Normalize(low, high)
    for column, (version, grid) in enumerate(zip(("Before", "After"), grids)):
        axis = axes[index, column]
        rgb = light.shade(grid, cmap=plt.colormaps["terrain"], norm=norm,
                          vert_exag=1, dx=4, dy=4, blend_mode="soft")
        axis.imshow(rgb, origin="lower", extent=(xs[0], xs[-1], zs[0], zs[-1]))
        axis.set(title=f"{site.replace('_', ' ').title()} — {version}", xlabel="x (nodes)", ylabel="z (nodes)")
        grades = np.concatenate((np.abs(np.diff(grid, axis=0)).ravel(),
                                 np.abs(np.diff(grid, axis=1)).ravel())) / 4
        receipts.append(f"{site}\t{version.lower()}\t{int(grid.min())}\t{int(grid.max())}\t"
                        f"{grades.max():.3f}\t{np.percentile(grades, 95):.3f}\n")
        line_axes[index].plot(xs, grid[len(zs)//2], label=version, linewidth=1.2)
    fig.colorbar(plt.cm.ScalarMappable(norm=norm, cmap="terrain"), ax=axes[index], label="Height (nodes)", shrink=.7)
    line_axes[index].set(title=f"{site.replace('_', ' ').title()} at z={zs[len(zs)//2]}", xlabel="x (nodes)", ylabel="Height (nodes)")
    line_axes[index].legend()
    line_axes[index].grid(alpha=.25)
fig.suptitle("Grudgelands — authoritative terrain envelope\nSeed 13191094842853985814; 4-node samples; shared height scale per row", fontsize=14)
lines.suptitle("Terrain cross-sections — 4-node samples, same seed and coordinates", fontsize=14)
fig.savefig(args.output / "terrain-before-after.png", dpi=140)
lines.savefig(args.output / "terrain-cross-sections.png", dpi=140)
(args.output / "terrain-summary.tsv").write_text("".join(receipts))
