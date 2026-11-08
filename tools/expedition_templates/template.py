"""The Expedition template, in memory and on disk (Round 71 lane FRAME).

Format: docs/technical/expedition-template-format.md. A source in sources/ is a
Python file with `build()` returning a Template; build.py writes the files the game
reads. Cells stay plain bytearrays in VoxelManip order, so a whole box costs a
second at most.
"""
import zlib

MAGIC = "grudgelands-expedition-template 1"
BOX = (128, 64, 128)
REQUIRED = ("arrival", "start_waystone", "end_waystone")
WAYSTONE = "grug_expeditions:waystone"
# The mod's own nodes, walkable all: the node registry does not list them.
OWN_NODES = (WAYSTONE, "grug_expeditions:reward_chest", "grug_expeditions:reward_door")


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

    def head(self, data_bytes):
        lines = [MAGIC, f"name {self.name}", f"size {self.sx} {self.sy} {self.sz}"]
        lines += [f"node {node}" for node in self.palette]
        lines += [f"dig {node}" for node in sorted(self.digs)]
        lines += [f"place {name} {x} {y} {z}" for name, (x, y, z) in sorted(self.places.items())]
        lines += ["encounter %s %s %d %s %d %d %d" % row for row in self.encounters]
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


def read_back(blob):
    """(head lines, cells, param2) of a written file."""
    at = blob.index(b"\ndata ") + 1
    stop = blob.index(b"\n", at)
    head = blob[:stop].decode().split("\n")
    cells = zlib.decompress(blob[stop + 1:])
    half = len(cells) // 2
    return head, cells[:half], cells[half:]
