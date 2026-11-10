"""Passages as polylines (Round 73 TOOLS; concept §4.2).

For the wave 2 lanes. A passage follows its points with bends and a width that may
change along it; it gives cells and a height map for `relief`, never writes itself.

    import passages, relief
    p = passages.Passage([(32, 19.5), (38, 17.5), (44, 21.5), (48, 19.5)], width=6)
    p = passages.Passage(points, width=lambda s: 6 + 2 * (0.4 < s < 0.6))  # a widening
    nook = p.niche(0.35, side=1, depth=3, width=3)    # 35 % along, on the left, 3 deep
    heights = p.heights(FEET, profile=[(0, 0), (0.5, 0), (0.8, -2)])  # a stair run down
    floor = relief.merge(room_a, heights, room_b)
    mouths = p.mouth(0) + p.mouth(1)                   # relief.vary keep=, proof spec.mouths

`s` runs from 0 at the first point to 1 at the last, by length. `width` is the clear
width across, measured at right angles to the line: a centre line through node edges
(19.5) gives even widths, through node centres (20) odd ones. A `profile` is (s, dh)
pairs, linear between them; it may not climb more than one node per node of length
(the relief check refuses it). A niche is a dead end beside the passage (§4.2: never a
second way round), its floor at its mouth's height.

About one feature per 15-20 nodes of passage (§4.2): a niche, a widening, a stair run,
a lower ceiling; `length` tells how many a passage takes.
"""
import math


class Passage:
    def __init__(self, points, width):
        if len(points) < 2:
            raise ValueError("passages: two points at least")
        self.points = [(float(x), float(z)) for x, z in points]
        self.width = width if callable(width) else (lambda s, w=width: w)
        self.lengths = [math.dist(a, b) for a, b in zip(self.points, self.points[1:])]
        self.length = sum(self.lengths)
        self.niches = []
        self._cells = None

    def at(self, s):
        """The point and the unit direction at `s` along the line."""
        left = s * self.length
        for (a, b), part in zip(zip(self.points, self.points[1:]), self.lengths):
            if left <= part or b == self.points[-1]:
                t = 0 if part == 0 else min(1.0, left / part)
                d = ((b[0] - a[0]) / part, (b[1] - a[1]) / part) if part else (1.0, 0.0)
                return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), d
            left -= part
        raise AssertionError

    def nearest(self, x, z):
        """(distance to the line, s at the nearest point); the distance is infinite beyond
        the line's two ends (a passage ends square at its end points)."""
        best, best_s, done = math.inf, 0.0, 0.0
        last = len(self.lengths) - 1
        for i, ((a, b), part) in enumerate(zip(zip(self.points, self.points[1:]), self.lengths)):
            if part == 0:
                continue
            t = ((x - a[0]) * (b[0] - a[0]) + (z - a[1]) * (b[1] - a[1])) / (part * part)
            if (i == 0 and t < 0) or (i == last and t > 1):
                done += part
                continue
            t = min(1.0, max(0.0, t))
            px, pz = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            d = math.hypot(x - px, z - pz)
            if d < best:
                best, best_s = d, (done + t * part) / self.length
            done += part
        return best, best_s

    def body(self):
        """The passage's own cells: {(x, z): s}."""
        if self._cells is None:
            xs = [p[0] for p in self.points]
            zs = [p[1] for p in self.points]
            reach = 1 + max(self.width(i / 20) for i in range(21)) / 2
            cells = {}
            for z in range(math.floor(min(zs) - reach), math.ceil(max(zs) + reach) + 1):
                for x in range(math.floor(min(xs) - reach), math.ceil(max(xs) + reach) + 1):
                    d, s = self.nearest(x, z)
                    if d < self.width(s) / 2 - 1e-9:
                        cells[x, z] = s
            self._cells = cells
        return self._cells

    def niche(self, at, side, depth, width):
        """A dead-end recess `at` along the passage, on `side` (1: left of the line's way,
        -1: right), `depth` nodes beyond the passage's edge and `width` nodes along it.
        Returns its cells; they join `cells()` and `heights()` at their mouth's height."""
        (px, pz), (dx, dz) = self.at(at)
        nx, nz = -dz * side, dx * side  # the left normal times side
        half = self.width(at) / 2
        body = self.body()
        cells = set()
        for i in range(width):
            along = i - (width - 1) / 2
            for k in range(1, int(math.ceil(half)) + depth + 1):
                cx = round(px + dx * along + nx * (k - 0.5))
                cz = round(pz + dz * along + nz * (k - 0.5))
                if (cx, cz) not in body and k > half:
                    cells.add((cx, cz))
        self.niches.append((at, cells))
        return cells

    def cells(self):
        out = set(self.body())
        for _, cells in self.niches:
            out |= cells
        return out

    def mouth(self, end):
        """The cells of the passage's first (0) or last (1) cross-section: keep them at the
        rooms' height (relief.vary keep=) and give them to the proof as mouths."""
        body = self.body()
        return sorted(c for c, s in body.items() if (s if end == 0 else 1 - s) * self.length < 1)

    def heights(self, base, profile=None):
        """The height map: `base` plus the profile's dh at each cell's s, rounded down; a
        niche at its mouth's height."""
        def dh(s):
            if not profile:
                return 0
            pts = sorted(profile)
            if s <= pts[0][0]:
                return pts[0][1]
            for (s0, h0), (s1, h1) in zip(pts, pts[1:]):
                if s <= s1:
                    return h0 + (h1 - h0) * (s - s0) / (s1 - s0 or 1)
            return pts[-1][1]
        out = {cell: base + math.floor(dh(s) + 1e-9) for cell, s in self.body().items()}
        for at, cells in self.niches:
            h = base + math.floor(dh(at) + 1e-9)
            for cell in cells:
                out.setdefault(cell, h)
        return out
