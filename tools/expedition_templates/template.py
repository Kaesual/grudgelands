"""The Expedition template, in memory and on disk (Round 71 lane FRAME).

Format: docs/technical/expedition-template-format.md. A source in sources/ is a
Python file with `build()` returning a Template; build.py writes the files the game
reads. Cells stay plain bytearrays in VoxelManip order, so a whole box costs a
second at most.
"""
import math
import zlib

MAGIC = "grudgelands-expedition-template 1"
BOX = (128, 64, 128)
REQUIRED = ("arrival", "start_waystone", "end_waystone")
WAYSTONE = "grug_expeditions:waystone"
# The mod's own nodes, walkable all: the node registry does not list them.
OWN_NODES = (WAYSTONE, "grug_expeditions:reward_chest", "grug_expeditions:reward_door")
AXES = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}


class Template:
    def __init__(self, name, size, fill):
        self.name = name
        self.size = size
        self.palette = [fill]
        self.ids = {fill: 0}
        sx, sy, sz = size
        self.sx, self.sy, self.sz = sx, sy, sz
        self.cells = bytearray(sx * sy * sz)
        self.param2 = bytearray(sx * sy * sz)
        self.digs = set()
        self.places = {}
        self.encounters = []
        self.traps = []

    def node_id(self, node):
        if node not in self.ids:
            if len(self.palette) == 256:
                raise ValueError(f"{self.name}: more than 256 nodes")
            self.ids[node] = len(self.palette)
            self.palette.append(node)
        return self.ids[node]

    def index(self, x, y, z):
        if not (0 <= x < self.sx and 0 <= y < self.sy and 0 <= z < self.sz):
            raise ValueError(f"{self.name}: cell {x},{y},{z} lies outside")
        return z * self.sy * self.sx + y * self.sx + x

    def set(self, x, y, z, node, param2=0):
        at = self.index(x, y, z)
        self.cells[at] = self.node_id(node)
        self.param2[at] = param2

    def get(self, x, y, z):
        return self.palette[self.cells[self.index(x, y, z)]]

    def box(self, x0, y0, z0, x1, y1, z1, node, param2=0):
        """Fills the cells from corner to corner, both included."""
        for z in range(z0, z1 + 1):
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    self.set(x, y, z, node, param2)

    def dig(self, node):
        """Marks a node as meant to be dug: every cell of it, in a live run, by its players."""
        self.digs.add(node)

    def place(self, name, x, y, z):
        """Names a cell for the game: a waystone, the chest, the door, ..."""
        self.index(x, y, z)
        if name in self.places:
            raise ValueError(f"{self.name}: place {name} twice")
        self.places[name] = (x, y, z)

    def encounter(self, room, mob, count, tier, x, y, z):
        """One encounter marker. `room` and `tier` are single words."""
        self.index(x, y, z)
        self.encounters.append((room, mob, count, tier, x, y, z))

    def trap_floor(self, group, pick, x, y, z):
        """A floor trap candidate: the cell a player stands in over it (Round 72).
        A run arms `pick` of the group's candidates."""
        self.index(x, y, z)
        self.traps.append((group, pick, "floor", f"{x} {y} {z}"))

    def trap_wall(self, group, pick, x, y, z, axis, period, offset):
        """A wall trap candidate: its muzzle point in node coordinates (whole numbers are
        node centres), the axis it shoots along (+x, -x, +z, -z), its period and the
        first shot's offset after readiness, in seconds."""
        self.index(*(int(math.floor(v + 0.5)) for v in (x, y, z)))
        if axis not in AXES:
            raise ValueError(f"{self.name}: trap axis {axis}")
        self.traps.append((group, pick, "wall",
                           f"{x:g} {y:g} {z:g} {axis} {period:g} {offset:g}", (x, y, z), axis))

    def head(self, data_bytes):
        lines = [MAGIC, f"name {self.name}", f"size {self.sx} {self.sy} {self.sz}"]
        lines += [f"node {node}" for node in self.palette]
        lines += [f"dig {node}" for node in sorted(self.digs)]
        lines += [f"place {name} {x} {y} {z}" for name, (x, y, z) in sorted(self.places.items())]
        lines += ["encounter %s %s %d %s %d %d %d" % row for row in self.encounters]
        lines += [f"trap {row[0]} {row[1]} {row[2]} {row[3]}" for row in self.traps]
        lines.append(f"data {data_bytes}")
        return ("\n".join(lines) + "\n").encode()

    def to_bytes(self):
        stream = zlib.compress(bytes(self.cells) + bytes(self.param2), 9)
        return self.head(len(stream)) + stream

    def problems(self, walkable):
        """What keeps this template from a run. `walkable(node)` is the registry's answer."""
        found = []
        for axis, value, limit in zip("xyz", self.size, BOX):
            if value % 16 or value == 0 or value > limit:
                found.append(f"size {axis} {value}: a multiple of 16, at most {limit}")
        for name in REQUIRED:
            if name not in self.places:
                found.append(f"place {name} is missing")
        if found:
            return found
        for name in ("start_waystone", "end_waystone"):
            x, y, z = self.places[name]
            if self.get(x, y, z) != WAYSTONE:
                found.append(f"place {name} holds no {WAYSTONE}")
        x, y, z = self.places["arrival"]
        if not walkable(self.get(x, y - 1, z)):
            found.append("arrival: no floor below")
        for dy in (0, 1):
            if walkable(self.get(x, y + dy, z)):
                found.append("arrival: no head room")
        for node in sorted(self.digs):
            if node not in self.ids:
                found.append(f"dig {node}: not in the palette")
            elif not walkable(node):
                found.append(f"dig {node}: not a solid node")
        found += self.trap_problems(walkable)
        # Nothing open on the template's outer shell, and nothing there to dig open:
        # the world beyond is not ours.
        for z in range(self.sz):
            for y in range(self.sy):
                for x in range(self.sx):
                    edge = x in (0, self.sx - 1) or y in (0, self.sy - 1) or z in (0, self.sz - 1)
                    if edge and (not walkable(self.get(x, y, z)) or self.get(x, y, z) in self.digs):
                        found.append(f"open hull at {x},{y},{z}")
                        return found
        return found


    def trap_problems(self, walkable):
        """Trap groups agree with themselves; a floor trap stands on floor in an open
        cell, a muzzle sits in an open cell with an open cell ahead (traps.lua)."""
        found, groups = [], {}
        for row in self.traps:
            group, pick, kind = row[0], row[1], row[2]
            key = (kind, pick) if kind == "floor" else (kind, pick) + tuple(row[3].split()[4:])
            seen = groups.setdefault(group, [key, 0])
            if seen[0] != key:
                found.append(f"trap group {group} disagrees with itself")
            seen[1] += 1
            if kind == "floor":
                x, y, z = (int(v) for v in row[3].split())
                if walkable(self.get(x, y, z)) or not walkable(self.get(x, y - 1, z)):
                    found.append(f"floor trap {group} at {x},{y},{z}: no open cell on a floor")
            else:
                (x, y, z), (dx, dz) = row[4], AXES[row[5]]
                cx, cy, cz = (int(math.floor(v + 0.5)) for v in (x, y, z))
                if walkable(self.get(cx, cy, cz)) or walkable(self.get(cx + dx, cy, cz + dz)):
                    found.append(f"wall trap {group} at {x:g},{y:g},{z:g}: the muzzle is not open")
        for group, (key, count) in sorted(groups.items()):
            if key[1] < 1 or key[1] > count:
                found.append(f"trap group {group} picks {key[1]} of {count}")
        return found


def read_back(blob):
    """(head lines, cells, param2) of a written file."""
    at = blob.index(b"\ndata ") + 1
    stop = blob.index(b"\n", at)
    head = blob[:stop].decode().split("\n")
    cells = zlib.decompress(blob[stop + 1:])
    half = len(cells) // 2
    return head, cells[:half], cells[half:]
