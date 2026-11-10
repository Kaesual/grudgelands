"""The Expedition template, in memory and on disk (Round 71 lane FRAME).

Format: docs/technical/expedition-template-format.md. A source in sources/ is a
Python file with `build()` returning a Template; build.py writes the files the game
reads. Cells stay plain bytearrays in VoxelManip order, so a whole box costs a
second at most.

The writers a source (or a shaping helper) calls, box-relative cells throughout:

  t = Template(name, (sx, sy, sz), fill)
  t.set(x, y, z, node, param2=0)            one cell
  t.box(x0, y0, z0, x1, y1, z1, node, param2=0)   every cell between two corners
  t.get(x, y, z)                            the node name in a cell
  t.dig(node)                               a node players may dig in a run
  t.place(name, x, y, z)                    a named cell (arrival, waystones, chest, ...)
  t.encounter(room, mob, count, tier, x, y, z)
                                            one marker; tier normal, elite, boss or
                                            critter (Round 73: no pack, no gate)
  t.trap_floor(group, pick, x, y, z)        a floor trap candidate (Round 72)
  t.trap_wall(group, pick, x, y, z, axis, period, offset)
                                            a wall trap candidate (Round 72)
  t.ambush(group, pick, room, x0, y, z0, x1, z1)
                                            an ambush candidate (Round 73): the zone
                                            from (x0, y, z0) to (x1, y, z1), y the feet's
                                            row; `room` names its markers, `normal` only
  t.particles(style, x0, y0, z0, x1, y1, z1, amount)
                                            a particle spawner in a box (Round 73);
                                            style one of PARTICLE_STYLES, amount the
                                            most live particles it keeps

Trap and ambush groups share one name space, and a group's lines agree on `pick`.
`problems(walkable)` refuses what the game's reader refuses (template.lua), and
more: build.py runs it before writing.
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
BALL = 0.4  # a fireball's radius, traps.lua's BALL
TIERS = ("normal", "elite", "boss", "critter")
# Round 73: template.lua's PARTICLE_STYLES and PARTICLE_BUDGET.
PARTICLE_STYLES = ("drip", "dust", "ash", "paper", "ember", "spark")
PARTICLE_BUDGET = 300


def check_pick(name, group, pick):
    """A pick is a whole number of at least 1, the reader's `%d+`."""
    if isinstance(pick, bool) or not isinstance(pick, int) or pick < 1:
        raise ValueError(f"{name}: trap group {group}: pick {pick!r} is no whole number of at least 1")


def check_whole(name, what, *values):
    """Coordinates and counts of a line are whole numbers: the head writes them with %d,
    which would drop a fraction silently (Round 73)."""
    for v in values:
        if isinstance(v, bool) or not isinstance(v, int):
            raise ValueError(f"{name}: {what}: {v!r} is no whole number")


def ball_rows(v):
    """The rows of cells a ball centred at v touches on one coordinate."""
    return sorted({int(math.floor(v - BALL + 0.5)), int(math.floor(v + BALL + 0.5))})


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
        self.ambushes = []
        self.particle_boxes = []

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
        check_pick(self.name, group, pick)
        self.traps.append((group, pick, "floor", f"{x} {y} {z}"))

    def trap_wall(self, group, pick, x, y, z, axis, period, offset):
        """A wall trap candidate: its muzzle point in node coordinates (whole numbers are
        node centres), the axis it shoots along (+x, -x, +z, -z), its period and the
        first shot's offset after readiness, in seconds."""
        self.index(*(int(math.floor(v + 0.5)) for v in (x, y, z)))
        if axis not in AXES:
            raise ValueError(f"{self.name}: trap axis {axis}")
        check_pick(self.name, group, pick)
        if not period > 0 or not offset >= 0:
            raise ValueError(f"{self.name}: trap group {group}: period above 0, offset 0 or more")
        self.traps.append((group, pick, "wall",
                           f"{x:g} {y:g} {z:g} {axis} {period:g} {offset:g}", (x, y, z), axis))

    def ambush(self, group, pick, room, x0, y, z0, x1, z1):
        """An ambush candidate (Round 73): the zone from (x0, y, z0) to (x1, y, z1), both
        corners included, y the feet's row (the first air over the floor). `room` names
        its markers, `encounter` lines of tier `normal` that wait for the zone. A run
        arms `pick` of the group's candidates."""
        check_whole(self.name, f"ambush {group}", x0, y, z0, x1, z1)
        self.index(x0, y, z0)
        self.index(x1, y, z1)
        check_pick(self.name, group, pick)
        for word in (group, room):
            if not isinstance(word, str) or not word or len(word.split()) != 1:
                raise ValueError(f"{self.name}: ambush {group!r}: {word!r} is no single word")
        self.ambushes.append((group, pick, room, min(x0, x1), y, min(z0, z1), max(x0, x1), max(z0, z1)))

    def particles(self, style, x0, y0, z0, x1, y1, z1, amount):
        """A particle spawner in the box between two corners (Round 73), drawn by the game
        in `style` (PARTICLE_STYLES); `amount` is the most live particles it keeps."""
        check_whole(self.name, f"particles {style}", x0, y0, z0, x1, y1, z1)
        self.index(x0, y0, z0)
        self.index(x1, y1, z1)
        if style not in PARTICLE_STYLES:
            raise ValueError(f"{self.name}: particle style {style!r}")
        if isinstance(amount, bool) or not isinstance(amount, int) or amount < 1:
            raise ValueError(f"{self.name}: particles {style}: amount {amount!r} is no whole number of at least 1")
        self.particle_boxes.append((style, min(x0, x1), min(y0, y1), min(z0, z1),
                                    max(x0, x1), max(y0, y1), max(z0, z1), amount))

    def head(self, data_bytes):
        lines = [MAGIC, f"name {self.name}", f"size {self.sx} {self.sy} {self.sz}"]
        lines += [f"node {node}" for node in self.palette]
        lines += [f"dig {node}" for node in sorted(self.digs)]
        lines += [f"place {name} {x} {y} {z}" for name, (x, y, z) in sorted(self.places.items())]
        lines += ["encounter %s %s %d %s %d %d %d" % row for row in self.encounters]
        lines += [f"trap {row[0]} {row[1]} {row[2]} {row[3]}" for row in self.traps]
        lines += ["ambush %s %d %s %d %d %d %d %d" % row for row in self.ambushes]
        lines += ["particles %s %d %d %d %d %d %d %d" % row for row in self.particle_boxes]
        lines.append(f"data {data_bytes}")
        return ("\n".join(lines) + "\n").encode()

    def to_bytes(self, grid=None):
        """The file; `grid` (walkgrid.Grid) adds the walk grid section after the cells
        (Round 74), as build.py writes every template."""
        stream = zlib.compress(bytes(self.cells) + bytes(self.param2), 9)
        blob = self.head(len(stream)) + stream
        if grid is not None:
            packed = grid.to_bytes()
            blob += f"grid {len(packed)}\n".encode() + packed
        return blob

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
        found += self.line_problems()
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
        """Trap groups agree with themselves; a floor trap's cell is air (its mark goes
        there) on a walkable floor; every cell the ball's cross-section touches is open at
        the muzzle and one cell ahead (traps.lua's flight_range)."""
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
                if self.get(x, y, z) != "air" or not walkable(self.get(x, y - 1, z)):
                    found.append(f"floor trap {group} at {x},{y},{z}: no air cell on a floor")
            else:
                (x, y, z), (dx, dz) = row[4], AXES[row[5]]
                cells = [(int(math.floor(x + 0.5)) + dx * k, cy, cz)
                         for k in (0, 1) for cy in ball_rows(y)
                         for cz in ball_rows(z)] if dx else \
                        [(cx, cy, int(math.floor(z + 0.5)) + dz * k)
                         for k in (0, 1) for cy in ball_rows(y) for cx in ball_rows(x)]
                if any(walkable(self.get(*cell)) for cell in cells):
                    found.append(f"wall trap {group} at {x:g},{y:g},{z:g}: the muzzle is not open")
        # Ambush lines share the name space (Round 73): a group of both disagrees.
        for row in self.ambushes:
            seen = groups.setdefault(row[0], [("ambush", row[1]), 0])
            if seen[0] != ("ambush", row[1]):
                found.append(f"trap group {row[0]} disagrees with itself")
            seen[1] += 1
        for group, (key, count) in sorted(groups.items()):
            if key[1] < 1 or key[1] > count:
                found.append(f"trap group {group} picks {key[1]} of {count}")
        return found

    def line_problems(self):
        """The Round 73 rules between the lines, as the reader's (template.lua
        lines_problem): known tiers; an ambush's room holds markers, `normal` only, and
        no other ambush names it; a room with a critter holds critters only; the
        particles stay within the budget."""
        found, tiers = [], {}
        for room, _, _, tier, *_ in self.encounters:
            if tier not in TIERS:
                found.append(f"encounter {room}: tier {tier}")
            tiers.setdefault(room, set()).add(tier)
        named = set()
        for group, _, room, *_ in self.ambushes:
            if room in named:
                found.append(f"room {room} has two ambushes")
            named.add(room)
            if room not in tiers:
                found.append(f"ambush {group} names no markers")
            elif tiers[room] != {"normal"}:
                found.append(f"ambush room {room} holds a " + " and a ".join(sorted(tiers[room] - {"normal"})))
        for room, kinds in sorted(tiers.items()):
            if "critter" in kinds and len(kinds) > 1:
                found.append(f"room {room} mixes critters and a pack")
        total = sum(row[-1] for row in self.particle_boxes)
        if total > PARTICLE_BUDGET:
            found.append(f"particles {total} over the budget of {PARTICLE_BUDGET}")
        return found


def _data_end(blob):
    at = blob.index(b"\ndata ") + 1
    stop = blob.index(b"\n", at)
    return stop, stop + 1 + int(blob[at + 5:stop])


def read_back(blob):
    """(head lines, cells, param2) of a written file."""
    stop, end = _data_end(blob)
    head = blob[:stop].decode().split("\n")
    cells = zlib.decompress(blob[stop + 1:end])
    half = len(cells) // 2
    return head, cells[:half], cells[half:]


def read_grid(blob):
    """The packed walk grid section of a written file (Round 74), or None."""
    _, end = _data_end(blob)
    if end == len(blob):
        return None
    stop = blob.index(b"\n", end)
    word, size = blob[end:stop].decode().split(" ")
    if word != "grid" or stop + 1 + int(size) != len(blob):
        raise ValueError("a malformed grid section")
    return blob[stop + 1:]
