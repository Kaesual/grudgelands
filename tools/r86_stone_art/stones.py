"""Claim Stone carvings, in sixteenths from the node's lower front-left corner.

The paint names below belong to the workshop. The game asset has six tiles
shared by every box. All home artwork is original to this study (CC0-1.0).
"""

from itertools import product

TITLES = {"roof": "Under One Roof", "lights": "Supper Lights", "pear": "The Pear Tree"}


class Carving:
    def __init__(self):
        self.parts = []

    def box(self, paint, x, y, z, end_x, end_y, end_z):
        bounds = (x, y, z, end_x, end_y, end_z)
        assert all(type(n) is int and 0 <= n <= 16 for n in bounds)
        assert x < end_x and y < end_y and z < end_z
        self.parts.append((bounds, paint))

    def chamfer(self, paint, x, y, z, end_x, end_y, end_z, cut=1):
        """Three boxes make a slab with four clipped corners."""
        self.box(paint, x + cut, y, z, end_x - cut, end_y, z + cut)
        self.box(paint, x, y, z + cut, end_x, end_y, end_z - cut)
        self.box(paint, x + cut, y, end_z - cut, end_x - cut, end_y, end_z)

    def cells(self):
        result = {}
        for (x, y, z, end_x, end_y, end_z), paint in self.parts:
            for cell in product(range(x, end_x), range(y, end_y), range(z, end_z)):
                assert cell not in result, cell
                result[cell] = paint
        return result


def roof(shared, empty):
    c = Carving()
    tile = "slate" if shared else "clay"
    c.box("sill", 0, 0, 1, 16, 2, 15)
    c.box("plaster", 1, 2, 3, 15, 8, 13)
    c.box("timber", 0, 8, 2, 16, 9, 14)
    if shared:
        for x in (0, 8):
            c.box(tile, x, 9, 2, x + 8, 10, 14)
            c.box(tile, x + 1, 10, 2, x + 7, 12, 14)
            c.box(tile, x + 2, 12, 2, x + 6, 14, 14)
            c.box("ridge_blue", x + 3, 14, 2, x + 5, 15, 14)
    else:
        for i in range(3):
            c.box(tile, 2 * i, 9 + 2 * i, 2, 16 - 2 * i, 11 + 2 * i, 14)
        c.box("ridge_red", 6, 15, 2, 10, 16, 14)
        c.box("chimney", 12, 13, 9, 14, 15, 12)
        c.box("chimney", 11, 15, 8, 15, 16, 13)
    return c


def lights(shared, empty):
    c = Carving()
    glaze = "sea_glaze" if shared else "ochre_glaze"
    if shared:
        c.chamfer("basalt", 1, 0, 2, 15, 2, 14, 2)
        c.chamfer(glaze, 0, 2, 1, 16, 4, 15, 2)
        positions = [(2, 5, 4, 9), (10, 6, 4, 8), (6, 10, 4, 11)]
    else:
        c.chamfer("basalt", 3, 0, 3, 13, 2, 13, 2)
        c.box("basalt", 5, 2, 5, 11, 4, 11)
        c.chamfer(glaze, 2, 4, 2, 14, 6, 14, 2)
        positions = [(5, 5, 6, 11)]
    for x, z, wide, top in positions:
        base = 4 if shared else 6
        if empty:
            top = base + (top - base) // 2
        c.chamfer("wax_cold" if empty else ("ivory" if shared else "beeswax"),
                  x, base, z, x + wide, top, z + wide)
        cx, cz = x + wide // 2, z + wide // 2
        if empty:
            c.box("wick", cx, top, cz, cx + 1, top + 1, cz + 1)
        else:
            c.box("wick", cx, top, cz, cx + 1, top + 1, cz + 1)
            c.box("flame", cx - 1, top + 1, cz - 1, cx + 2, top + 3, cz + 1)
            c.box("flame_tip", cx, top + 3, cz - 1, cx + 2, top + 4, cz + 1)
            c.box("flame_tip", cx + 1, top + 4, cz, cx + 2, top + 5, cz + 1)
    return c


def pear(shared, empty):
    c = Carving()
    pot = "blue_pot" if shared else "ochre_pot"
    c.chamfer(pot, 3, 0, 4, 13, 2, 12)
    c.chamfer(pot, 2, 2, 3, 14, 4, 13)
    c.chamfer(pot, 1, 4, 2, 15, 6, 14, 2)
    c.box("bark", 7, 6, 7, 10, 9, 10)
    leaf = "juniper" if shared else "olive"
    if shared:
        c.box("bark", 4, 8, 7, 7, 10, 10)
        c.box("bark", 3, 10, 7, 5, 13, 9)
        c.box("bark", 10, 8, 7, 13, 10, 10)
        c.box("bark", 12, 10, 7, 14, 12, 9)
        crowns = [(3, 13, 7), (12, 12, 8)]
    else:
        c.box("bark", 6, 9, 7, 9, 13, 10)
        c.box("bark", 9, 10, 8, 12, 11, 10)
        crowns = [(7, 13, 8)]
    for x, y, z in crowns:
        if empty:
            c.box("bark", x, y, z, x + 2, y + 2, z + 2)
            c.box("bark", x - 2, y, z, x, y + 1, z + 1)
            c.box("bark", x - 2, y + 1, z, x - 1, y + 2, z + 1)
            continue
        half = 3 if shared else 6
        c.chamfer(leaf, x - half, y, z - 4, x + half + 1, y + 1, z + 4, 2)
        c.chamfer(leaf, x - half + 1, y + 1, z - 3, x + half, y + 2, z + 3)
        c.box(leaf, x - half + 2, y + 2, z - 2, x + half - 1, y + 3, z + 2)
        c.box(leaf, x + 2, y - 2, z - 1, x + half + 1, y, z + 2)
        c.box(leaf, x - half, y - 1, z, x - 1, y, z + 3)
        # A taper at the stem and a wider, low belly give the fruit its pear shape.
        c.box("pear_neck", x - 1, y - 2, z - 4, x + 1, y, z - 2)
        c.box("pear_gold", x - 2, y - 4, z - 5, x + 2, y - 2, z - 2)
        c.box("pear_base", x - 1, y - 5, z - 4, x + 1, y - 4, z - 2)
    return c


BUILDERS = {"roof": roof, "lights": lights, "pear": pear}
