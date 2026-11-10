"""The walk grid of an Expedition template (Round 74 NAV; round74-plan.md section 3.2).

build.py writes it as the `grid` section of every `.exp`; the game reads it once per
template and walks every Expedition mob path over it (grug_expeditions/walkgrid.lua).

    import walkgrid
    grid = walkgrid.build(template, walkable)    # from the Template build.py just made
    grid.to_bytes()                              # the section's packed planes
    walkgrid.problems(template, grid)            # what --check refuses

The floor is the shared proof's height map (proofs.lua `map`, re-derived here from the
cells): the walking cells a player reaches from the arrival, the reward door read open and
the diggable ore read solid (a dug cell only offers a shortcut the grid ignores). One
walking cell per column, the proof's `surface` rule. Per column:

  height     the feet row of its walking cell, NONE (255) for no floor
  mask       the moves a mob makes from it (MOVES order): a straight move to a neighbour's
             walking cell at most one node up or down with the body's two rows free over
             both columns at the higher level; a diagonal only when both straight
             neighbours are such moves and each of them reaches the diagonal cell, so no
             corner is cut. A player's leap over open columns is no mob move.
  clearance  the Chebyshev distance to the nearest column a body standing here would hit
             (CLEAR_CAP at most): solid in the body's two rows, or a floor two or more
             nodes higher; open air beside the floor (a pit, the lake) is no wall
  flags      bit 0 a door cell (a reward door node in its body rows, read shut, passable
             only while the door is open); bits 1 to 4 a 2 x 2 block of free columns this
             cell is a corner of, towards QUADS[k]: room for a body up to two nodes wide

Why a mob walks what the grid says (the walk model against the engine): every Expedition
mob has stepheight 1.1 and a physics box at most 1.95 high (grug_obstacle PHYSICS_HEIGHT),
so a step of one node (the proof's relief rule makes it a stair, half a node at a time)
is walked and two free rows pass a body; the proof's free height gives three.
"""
import zlib

NONE = 255
CLEAR_CAP = 6
# Mask bits: the four straight moves, then the four diagonals.
MOVES = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
# The 2 x 2 blocks (flag bits 1..4): the cell and its neighbours towards (qx, qz).
QUADS = ((1, 1), (1, -1), (-1, 1), (-1, -1))
DOOR = "grug_expeditions:reward_door"


def node_facts(definition, name):
    """proofs.lua `facts`: what a node is to a body (air, liquid, open, climb, stair, flat,
    prop, full)."""
    if name == "air":
        return "air"
    if (definition.get("liquidtype") or "none") != "none":
        return "liquid"
    if definition.get("walkable", True) is False:
        return "climb" if definition.get("climbable") else "open"
    if name.startswith("stairs:stair_"):
        return "stair"

    def boxes(box):
        if not box or box.get("type") != "fixed" or not box.get("fixed"):
            return None
        fixed = box["fixed"]
        return [fixed] if isinstance(fixed[0], (int, float)) else fixed
    found = boxes(definition.get("collision_box")) or \
        (definition.get("drawtype") == "nodebox" and boxes(definition.get("node_box"))) or None
    if found:
        top = max(max(b[1], b[4]) for b in found)
        return "flat" if top <= -0.25 else "prop"
    if definition.get("drawtype") == "normal":
        return "full"
    return "prop" if name in PROPS else "full"


# proofs.lua P.FURNITURE and P.ALLOWED: a walkable mesh that is furniture, not a block.
PROPS = {"grug_expeditions:waystone", "grug_expeditions:reward_chest", "grug_expeditions:reward_door",
         "grug_decor:cottages_table", "grug_decor:cottages_bench", "grug_decor:cottages_barrel",
         "grug_mapgen:mine_cart"}
PASSES = ("air", "open", "climb")


class Cells:
    """The template's cells as classes, the door read open or shut."""

    def __init__(self, template, definition, door_open):
        self.t = template
        self.sx, self.sy, self.sz = template.size
        self.classes = []
        for name in template.palette:
            if door_open and name == DOOR:
                self.classes.append("air")
            else:
                self.classes.append(node_facts(definition(name), name))
        self.door_id = template.ids.get(DOOR)

    def inside(self, x, y, z):
        return 0 <= x < self.sx and 0 <= y < self.sy and 0 <= z < self.sz

    def cls(self, x, y, z):
        if not self.inside(x, y, z):
            return "full"
        return self.classes[self.t.cells[self.t.index(x, y, z)]]

    def passes(self, x, y, z):
        return self.cls(x, y, z) in PASSES

    def feet(self, x, y, z):
        return self.passes(x, y, z) or self.cls(x, y, z) == "flat"

    def stands(self, x, y, z):
        here, below = self.cls(x, y, z), self.cls(x, y - 1, z)
        ground = below in ("full", "stair", "prop")
        return ((ground and here in PASSES) or (here == "flat" and below == "full")) and self.passes(x, y + 1, z)

    def on_floor(self, x, y, z):
        if not self.stands(x, y, z):
            return False
        return self.cls(x, y - 1, z) in ("full", "stair") or self.cls(x, y, z) == "flat"

    def is_door(self, x, y, z):
        return self.inside(x, y, z) and self.door_id is not None and \
            self.t.cells[self.t.index(x, y, z)] == self.door_id


def floor_walk(c, start):
    """proofs.lua P.floor_walk: the cells a player walks to from `start`, steps of one up
    only onto a stair, and the level leap over one or two open columns."""
    x, y, z = start
    seen = {}
    if not (c.inside(x, y, z) and c.on_floor(x, y, z)):
        return seen
    seen[(x, y, z)] = 0
    queue, head = [(x, y, z)], 0
    while head < len(queue):
        cx, cy, cz = queue[head]
        head += 1
        steps = seen[(cx, cy, cz)] + 1
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = cx + dx, cz + dz
            if not c.inside(nx, cy, nz):
                continue
            moved = False
            for dy in (0, -1, 1):
                ny = cy + dy
                if 1 <= ny < c.sy - 1 and c.on_floor(nx, ny, nz) and \
                        (dy < 1 or c.cls(nx, ny - 1, nz) == "stair") and \
                        (dy > -1 or c.passes(nx, cy + 1, nz)):
                    if (nx, ny, nz) not in seen:
                        seen[(nx, ny, nz)] = steps
                        queue.append((nx, ny, nz))
                    moved = True
            if not moved and c.passes(cx, cy + 2, cz):
                for k in (1, 2):
                    px, pz = cx + dx * k, cz + dz * k
                    clear = c.inside(px, cy, pz) and c.feet(px, cy, pz) and \
                        c.passes(px, cy + 1, pz) and c.passes(px, cy + 2, pz)
                    if not clear:
                        break
                    lx, lz = cx + dx * (k + 1), cz + dz * (k + 1)
                    if c.inside(lx, cy, lz) and c.on_floor(lx, cy, lz):
                        if (lx, cy, lz) not in seen:
                            seen[(lx, cy, lz)] = steps + k
                            queue.append((lx, cy, lz))
                        break
    return seen


def height_map(c, start):
    """{(x, z): [y...]} of the cells reached, lowest first (proofs.lua map: m.surfaces)."""
    columns = {}
    for (x, y, z) in floor_walk(c, start):
        columns.setdefault((x, z), []).append(y)
    for ys in columns.values():
        ys.sort()
    return columns


class Grid:
    def __init__(self, sx, sz):
        self.sx, self.sz = sx, sz
        self.height = bytearray([NONE]) * (sx * sz)
        self.mask = bytearray(sx * sz)
        self.clear = bytearray(sx * sz)
        self.flags = bytearray(sx * sz)

    def at(self, x, z):
        return z * self.sx + x

    def h(self, x, z):
        if not (0 <= x < self.sx and 0 <= z < self.sz):
            return None
        h = self.height[self.at(x, z)]
        return None if h == NONE else h

    def to_bytes(self):
        return zlib.compress(bytes(self.height) + bytes(self.mask) + bytes(self.clear) + bytes(self.flags), 9)

    @classmethod
    def from_bytes(cls, sx, sz, blob):
        raw = zlib.decompress(blob)
        n = sx * sz
        if len(raw) != 4 * n:
            raise ValueError("the grid does not fit the size")
        g = cls(sx, sz)
        g.height[:], g.mask[:], g.clear[:], g.flags[:] = raw[:n], raw[n:2 * n], raw[2 * n:3 * n], raw[3 * n:]
        return g


def build(template, definition):
    """The grid of `template`; `definition(name)` the registry's node table."""
    c = Cells(template, definition, door_open=True)
    shut = Cells(template, definition, door_open=False)
    a = template.places["arrival"]
    columns = height_map(c, a)
    g = Grid(c.sx, c.sz)
    for (x, z), ys in columns.items():
        if ys[0] >= NONE:
            raise ValueError(f"{template.name}: a walking cell at {x},{z} above row {NONE - 1}")
        g.height[g.at(x, z)] = ys[0]

    def free(x, z, y):
        """A body's row at y over column (x, z): it passes (a rail in its own feet row)."""
        return c.passes(x, y, z) or (c.cls(x, y, z) == "flat" and g.h(x, z) == y)

    def straight(x, z, nx, nz):
        h, nh = g.h(x, z), g.h(nx, nz)
        if h is None or nh is None or abs(h - nh) > 1:
            return False
        top = max(h, nh)
        return all(free(px, pz, y) for px, pz in ((x, z), (nx, nz)) for y in (top, top + 1))

    for z in range(g.sz):
        for x in range(g.sx):
            if g.h(x, z) is None:
                continue
            mask = 0
            for bit, (dx, dz) in enumerate(MOVES[:4]):
                if straight(x, z, x + dx, z + dz):
                    mask |= 1 << bit
            for bit, (dx, dz) in enumerate(MOVES[4:], start=4):
                if straight(x, z, x + dx, z) and straight(x, z, x, z + dz) and \
                        straight(x + dx, z, x + dx, z + dz) and straight(x, z + dz, x + dx, z + dz) and \
                        abs(g.h(x, z) - g.h(x + dx, z + dz)) <= 1:
                    mask |= 1 << bit
            g.mask[g.at(x, z)] = mask

    def blocked(x, z, h, nx, nz):
        """Would a body standing at (x, h, z) hit column (nx, nz)?"""
        nh = g.h(nx, nz)
        if nh is not None:
            return nh >= h + 2
        return not (c.inside(nx, h, nz) and all(c.passes(nx, y, nz) for y in (h, h + 1)))

    for z in range(g.sz):
        for x in range(g.sx):
            h = g.h(x, z)
            if h is None:
                continue
            clear = CLEAR_CAP
            for d in range(1, CLEAR_CAP):
                ring = [(x + dx, z + dz) for dz in range(-d, d + 1) for dx in range(-d, d + 1)
                        if max(abs(dx), abs(dz)) == d]
                if any(blocked(x, z, h, nx, nz) for nx, nz in ring):
                    clear = d
                    break
            g.clear[g.at(x, z)] = clear
            flags = 0
            if any(shut.is_door(x, y, z) for y in (h, h + 1)):
                flags |= 1
            for k, (qx, qz) in enumerate(QUADS):
                if not any(blocked(x, z, h, nx, nz) for nx, nz in ((x + qx, z), (x, z + qz), (x + qx, z + qz))):
                    flags |= 2 << k
            g.flags[g.at(x, z)] = flags
    return g


def reach(g, start, door_open=True):
    """The columns a mob walks to over the masks from column `start`."""
    seen = {start}
    queue = [start]
    while queue:
        x, z = queue.pop()
        mask = g.mask[g.at(x, z)]
        for bit, (dx, dz) in enumerate(MOVES):
            n = (x + dx, z + dz)
            if mask & (1 << bit) and n not in seen and (door_open or not g.flags[g.at(*n)] & 1):
                seen.add(n)
                queue.append(n)
    return seen


def problems(template, g, definition):
    """What build.py refuses of a grid: a height off the proof's own height map (re-derived
    from the cells), a mask that is not symmetric, a move the relief forbids, a diagonal
    that cuts a corner, an encounter or an ambush zone off the grid, a place with no walking
    cell in or beside it, and a room whose markers lie in two walk components."""
    found = []
    c = Cells(template, definition, door_open=True)
    columns = height_map(c, template.places["arrival"])
    for z in range(g.sz):
        for x in range(g.sx):
            ys = columns.get((x, z))
            if (ys[0] if ys else None) != g.h(x, z):
                found.append(f"grid height at {x},{z}: {g.h(x, z)}, the height map {ys}")
            if ys and len(ys) > 1:
                found.append(f"two walking cells at {x},{z}: {ys}")
            if g.h(x, z) is None:
                if g.mask[g.at(x, z)] or g.flags[g.at(x, z)] or g.clear[g.at(x, z)]:
                    found.append(f"a column without floor has moves at {x},{z}")
                continue
            mask = g.mask[g.at(x, z)]
            for bit, (dx, dz) in enumerate(MOVES):
                if not mask & (1 << bit):
                    continue
                nx, nz = x + dx, z + dz
                back = MOVES.index((-dx, -dz))
                nh = g.h(nx, nz)
                if nh is None or not g.mask[g.at(nx, nz)] & (1 << back):
                    found.append(f"move {x},{z} -> {nx},{nz} has no way back")
                elif abs(nh - g.h(x, z)) > 1:
                    found.append(f"move {x},{z} -> {nx},{nz}: a step of {nh - g.h(x, z)}")
                if bit >= 4 and not (mask & (1 << MOVES.index((dx, 0))) and mask & (1 << MOVES.index((0, dz)))):
                    found.append(f"diagonal {x},{z} -> {nx},{nz} cuts a corner")
        if len(found) > 20:
            return found
    # Reached: over the grid's moves from the arrival, the door open. A player's leap
    # (The Last Mint's lake) joins walk components no mob walks between: each component
    # stands for itself, and a room's markers share one, so a pack walks to every home.
    comp = components(g)
    for room in sorted({row[0] for row in template.encounters}):
        held = {comp.get((x, z)) for r, _, _, _, x, _, z in template.encounters if r == room}
        if len(held) > 1:
            found.append(f"room {room}: its markers lie in {len(held)} walk components")
    for room, mob, _, _, x, y, z in template.encounters:
        if g.h(x, z) != y:
            found.append(f"encounter {room} {mob} at {x},{y},{z}: not on a walking cell")
    for group, _, room, x0, y, z0, x1, z1 in template.ambushes:
        if not all(g.h(x, z) == y for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)):
            found.append(f"ambush {group} ({room}): a zone cell off the grid")

    def near(x, z, r):
        return any(g.h(x + dx, z + dz) is not None for dz in range(-r, r + 1) for dx in range(-r, r + 1))
    for name, (x, y, z) in sorted(template.places.items()):
        if name.startswith("boss_room_"):
            continue
        # A place is a cell a body stands in, or a node (a waystone, the chest, the door,
        # a sign) a body stands beside.
        if not near(x, z, 0 if g.h(x, z) == y else 1):
            found.append(f"place {name} at {x},{y},{z}: no walking cell in or beside it")
    return found


def components(g, door_open=True):
    """{(x, z): number} of the walk components over the grid's moves, 0 the largest."""
    left = {(i % g.sx, i // g.sx) for i, h in enumerate(g.height) if h != NONE}
    parts = []
    while left:
        part = reach(g, next(iter(left)), door_open)
        parts.append(part)
        left -= part
    parts.sort(key=lambda part: (-len(part), min(part)))
    return {cell: k for k, part in enumerate(parts) for cell in part}


def notes(g):
    """One line about a grid for build.py: cells, door cells, walk components."""
    cells = sum(1 for h in g.height if h != NONE)
    door = sum(1 for f in g.flags if f & 1)
    sizes = {}
    for k in components(g).values():
        sizes[k] = sizes.get(k, 0) + 1
    return f"{cells} cells, {door} door cells, walk components {[sizes[k] for k in sorted(sizes)]}"
