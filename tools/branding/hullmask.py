#!/usr/bin/env python3
"""Combine two shield masks: `loose` (tight flood tolerance: rim intact, smoke attached)
and `clean` (smoke removed, rim notched). Below SPLIT the true outline is convex, so the
result there is loose AND convexhull(clean); above SPLIT it is clean unchanged."""
import sys, numpy as np
from PIL import Image, ImageDraw
clean_p, loose_p, out_p = sys.argv[1:4]
SPLIT = int(sys.argv[4]) if len(sys.argv) > 4 else 300
clean = np.array(Image.open(clean_p).convert("L")) > 127
loose = np.array(Image.open(loose_p).convert("L")) > 127
h, w = clean.shape
ys, xs = np.nonzero(clean)
pts = sorted(set(zip(xs.tolist(), ys.tolist())))
def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
lower, upper = [], []
for p in pts:
    while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
    lower.append(p)
for p in reversed(pts):
    while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
    upper.append(p)
hull = lower[:-1] + upper[:-1]
img = Image.new("L", (w, h), 0); ImageDraw.Draw(img).polygon(hull, fill=255)
hullm = np.array(img) > 127
final = clean.copy()
final[SPLIT:] = loose[SPLIT:] & hullm[SPLIT:]
Image.fromarray((final * 255).astype(np.uint8)).save(out_p)
print("hull vertices:", len(hull), "pixels added vs clean:", int((final & ~clean).sum()), "removed:", int((clean & ~final).sum()))
