"""Original station geometry, in sixteenths of a node; front is -Z.

Python/Pillow art by GPT-6 Astra for Grudgelands, 2026-10-09.
Code: GPL-3.0-or-later. Generated original art: CC0-1.0.
Materials are authoring aids, baked into SIX shared node-coordinate tiles.
They are never per-box materials in the exported Lua or in the renderer.
"""

from dataclasses import dataclass, field


@dataclass
class Design:
    station: str
    variant: str
    title: str
    description: str
    parts: list = field(default_factory=list)

    def box(self, material, *bounds):
        assert len(bounds) == 6
        assert all(-8 <= v <= 8 for v in bounds)
        assert all(bounds[i] < bounds[i + 3] for i in range(3))
        self.parts.append((bounds, material))


def bench(d, top=0, depth=6, wood="oak"):
    d.box(wood, -7, top - 2, -depth, 7, top, depth)
    for x in (-6, 4):
        for z in (-depth + 1, depth - 3):
            d.box(wood, x, -8, z, x + 2, top - 2, z + 2)
    d.box(wood, -5, -6, 0, 5, -5, 2)


def spool(d, x, y, z, thread="thread"):
    d.box("oak", x, y, z, x + 3, y + 1, z + 3)
    d.box(thread, x + .5, y + 1, z + .5, x + 2.5, y + 3, z + 2.5)
    d.box("oak", x, y + 3, z, x + 3, y + 4, z + 3)
    d.box("iron", x + 1, y + 4, z + 1, x + 2, y + 5, z + 2)


def mallet(d, x, y, z):
    d.box("oak", x + 1, y, z, x + 2, y + 1, z + 5)
    d.box("endgrain", x, y, z, x + 3, y + 2, z + 2)


def chisel(d, x, y, z):
    d.box("walnut", x, y, z, x + 1, y + 1, z + 2)
    d.box("steel", x, y, z + 2, x + 1, y + .5, z + 5)


def gem(d, x, y, z, colour="gem_teal"):
    d.box(colour, x, y, z, x + 3, y + 1, z + 3)
    d.box(colour, x + 1, y + 1, z + 1, x + 2, y + 2, z + 2)


def bottle(d, x, y, z, colour="glass_teal", width=4, height=6):
    d.box(colour, x + 1, y, z, x + width - 1, y + 1, z + width)
    d.box(colour, x, y + 1, z, x + width, y + height - 2, z + width)
    d.box(colour, x + 1, y + height - 2, z + 1,
          x + width - 1, y + height - 1, z + width - 1)
    d.box("cork", x + 1, y + height - 1, z + 1,
          x + width - 1, y + height, z + width - 1)


def burner(d, x, y, z):
    d.box("iron", x, y, z, x + 4, y + 1, z + 4)
    d.box("copper", x + 1, y + 1, z + 1, x + 3, y + 2, z + 3)
    d.box("ember", x + 1, y + 2, z + 1, x + 3, y + 3, z + 3)


def all_designs():
    result = []

    def new(station, variant, title, description):
        d = Design(station, variant, title, description)
        result.append(d)
        return d

    # LEATHER: vertical skin, horizontal stretching bed, paired narrow hides.
    d = new("tanning_rack", "A", "Laced hide",
            "A full hide laced into an open upright oak frame on long feet.")
    for x in (-7, 5):
        d.box("oak", x, -8, -5, x + 2, -6, 5)
        d.box("oak", x, -6, 0, x + 2, 8, 2)
    d.box("oak", -5, 6, 0, 5, 8, 2)
    d.box("oak", -5, -5, 0, 5, -3, 2)
    d.box("hide", -3, -3, .5, 3, 5, 1.5)
    d.box("hide", -5, 1, .5, 5, 4, 1.5)
    d.box("hide", -4, -3, .5, -2, -1, 1.5)
    d.box("hide", 2, -3, .5, 4, -1, 1.5)
    for x in (-3, 2):
        d.box("rope", x, 5, .5, x + 1, 6, 1.5)
    for y in (-2, 2, 4):
        for x in (-5, 3):
            d.box("rope", x, y, .5, x + 2, y + 1, 1.5)

    d = new("tanning_rack", "B", "Stretching trestle",
            "A low open stretching bed with a flat russet hide and a broad scraper.")
    for x in (-7, 5):
        d.box("oak", x, -8, -5, x + 2, 2, -3)
        d.box("oak", x, -8, 3, x + 2, 2, 5)
        d.box("oak", x, 0, -7, x + 2, 2, 7)
    for z in (-7, 5):
        d.box("oak", -5, 0, z, 5, 2, z + 2)
    d.box("russet", -3, .5, -4, 3, 1.5, 4)
    d.box("russet", -4, .5, -3, 4, 1.5, 2)
    for x in (-4, 3):
        d.box("russet", x, .5, 3, x + 1, 1.5, 5)
    for z in (-4, 0, 4):
        d.box("rope", -5, .5, z, -3, 1.5, z + 1)
        d.box("rope", 3, .5, z, 5, 1.5, z + 1)
    d.box("rope", -1, .5, -5, 0, 1.5, -4)
    d.box("steel", -2, 2, 4, 2, 3, 6)
    d.box("walnut", -3, 3, 5, 3, 4, 6)
    d.box("oak", -5, -5, -1, 5, -4, 1)

    d = new("tanning_rack", "C", "Twin drying rail",
            "Two narrow pale hides hang from a divided rail above a leather-working shelf.")
    for x in (-7, 5):
        d.box("walnut", x, -8, -4, x + 2, -6, 5)
        d.box("walnut", x, -6, 1, x + 2, 8, 3)
    d.box("walnut", -5, 6, 1, 5, 8, 3)
    d.box("walnut", -1, -3, 1, 1, 6, 3)
    d.box("oak", -7, -4, -4, 7, -3, 4)
    for x, material in ((-5, "hide"), (1, "pale_hide")):
        d.box(material, x, 0, 1.5, x + 4, 5, 2.5)
        d.box(material, x + 1, -2, 1.5, x + 3, 0, 2.5)
        d.box("rope", x + 1, 5, 1.5, x + 2, 6, 2.5)
        for y in (0, 3):
            d.box("rope", x - 1, y, 1.5, x, y + 1, 2.5)
    d.box("russet", -5, -3, -3, -1, -1, 0)
    chisel(d, 3, -3, -3)

    # TAILOR: open loom, draped cutting table, bolt-and-spindle cradle.
    d = new("tailor_bench", "A", "Open cloth loom",
            "An open oak loom shows ivory warp above teal cloth, with a spool at its foot.")
    for x in (-7, 5):
        d.box("oak", x, -8, -5, x + 2, -6, 5)
        d.box("oak", x, -6, 1, x + 2, 8, 3)
    d.box("oak", -5, 6, 1, 5, 8, 3)
    d.box("oak", -5, -3, 0, 5, -1, 3)
    for x in (-4, -2, 0, 2, 4):
        d.box("thread", x, 1, 1.5, x + .5, 6, 2.5)
    d.box("cloth", -5, -1, 1, 5, 2, 3)
    d.box("cloth", -5, -5, 0, 5, -1, 1)
    d.box("oak", -5, -6, -4, 5, -5, 4)
    spool(d, 1, -5, -4)
    d.box("endgrain", -4, -4, -1, -1, -3, 0)

    d = new("tailor_bench", "B", "Pattern table",
            "A broad cutting table carries folded plum cloth, shears and an upright thread spool.")
    bench(d, top=1)
    d.box("plum_cloth", -5, 1, -6, 1, 2, 5)
    d.box("plum_cloth", -5, -4, -7, 1, 2, -6)
    d.box("linen", -4, 2, -3, 0, 2.5, 2)
    spool(d, 3, 1, 2)
    # Open straight shear blades, squared finger loops in the texture.
    d.box("steel", 3, 1, -5, 4, 2, -1)
    d.box("steel", 5, 1, -5, 6, 2, -1)
    d.box("iron", 3, 1, -2, 6, 2, 0)
    d.box("thread", -3, -5, 2, 3, -3, 5)

    d = new("tailor_bench", "C", "Bolt and spindle",
            "A low cloth-roll cradle pairs a hanging teal bolt with a tall exposed spindle.")
    for x in (-7, 5):
        d.box("walnut", x, -8, -5, x + 2, -6, 5)
    d.box("oak", -5, -5, -3, 5, -3, 4)
    for x in (-6, 2):
        d.box("walnut", x, -6, 1, x + 2, 5, 3)
    d.box("oak", -6, 2, 1, 4, 4, 3)
    d.box("cloth", -4, 1, 0, 2, 5, 4)
    d.box("cloth", -3, 0, 1, 1, 6, 3)
    d.box("cloth", -4, -4, -1, 2, 2, 0)
    d.box("oak", 5, -6, -3, 7, 7, -1)
    d.box("thread", 4, 0, -4, 8, 4, 0)
    d.box("oak", 4, -1, -4, 8, 0, 0)
    d.box("oak", 4, 4, -4, 8, 5, 0)
    d.box("thread", -3, -3, 2, 1, -1, 4)

    # WOOD: vise bench, freestanding carving block, long shaving horse.
    d = new("carving_bench", "A", "Vise workbench",
            "A braced oak bench holds a clamped timber blank, a mallet and a steel chisel.")
    bench(d, top=1)
    d.box("endgrain", -4, 1, 1, 3, 3, 4)
    d.box("iron", 3, 1, 0, 5, 4, 5)
    d.box("steel", 4, 0, -2, 5, 1, 2)
    d.box("walnut", 3, -1, -3, 6, 0, -2)
    mallet(d, -5, 1, -5)
    chisel(d, 0, 1, -5)

    d = new("carving_bench", "B", "Sculptor's stump",
            "A bark-covered chopping stump supports a stepped wooden carving and two upright gouges.")
    d.box("bark", -5, -8, -6, 5, 0, 6)
    d.box("bark", -6, -8, -4, 6, 0, 4)
    d.box("endgrain", -5, 0, -6, 5, 1, 6)
    d.box("endgrain", -6, 0, -4, 6, 1, 4)
    d.box("freshwood", -2, 1, -2, 2, 3, 2)
    d.box("freshwood", -1, 3, -1, 1, 6, 1)
    d.box("freshwood", -2, 5, -1, 2, 7, 2)
    for z, y in ((-3, 2), (1, 3)):
        d.box("steel", 5, -3, z, 6, y, z + 1)
        d.box("walnut", 5, y, z, 7, y + 3, z + 2)
    mallet(d, -5, 1, -4)

    d = new("carving_bench", "C", "Shaving horse",
            "A narrow shaving horse grips a long timber under raised jaws, with its drawknife across the front.")
    d.box("oak", -7, -3, -3, 7, -1, 3)
    for x in (-6, 4):
        for z in (-4, 2):
            d.box("walnut", x, -8, z, x + 2, -3, z + 2)
    d.box("oak", 2, -6, -2, 4, 5, 2)
    d.box("walnut", 1, 3, -3, 5, 5, 3)
    d.box("freshwood", -6, 1, -1, 2, 3, 2)
    d.box("oak", -5, -1, -2, -3, 1, 3)
    d.box("steel", -5, -1, -3, -1, 0, -2)
    for x in (-6, -1):
        d.box("walnut", x, -1, -5, x + 1, 0, -2)
    d.box("oak", 0, -6, -4, 5, -5, 4)
    d.box("iron", 5, -1, -1, 6, 2, 1)

    # JEWELLER: notched bench, balance, lapidary wheel.
    d = new("jewellers_bench", "A", "Gem setter's bench",
            "A notched walnut bench presents a green work mat, bench peg, tiny hammer and bright cut gems.")
    for x in (-7, 5):
        for z in (-5, 3):
            d.box("walnut", x, -8, z, x + 2, -1, z + 2)
    d.box("walnut", -7, -1, -3, 7, 1, 6)
    d.box("walnut", -7, -1, -6, -2, 1, -3)
    d.box("walnut", 2, -1, -6, 7, 1, -3)
    d.box("felt", -5, 1, -2, 5, 1.5, 4)
    d.box("endgrain", -1, 0, -6, 1, 1, -2)
    gem(d, -4, 1.5, 0)
    gem(d, 1, 1.5, 1, "gem_ruby")
    chisel(d, 5, 1, -4)
    d.box("walnut", -6, 1, -5, -5, 2, -1)
    d.box("steel", -7, 1, -5, -4, 2, -4)
    d.box("walnut", -7, 1, 5, 7, 3, 6)

    d = new("jewellers_bench", "B", "Assayer's balance",
            "A brass balance with two suspended pans stands above a drawer, a cut gem and fine tools.")
    d.box("walnut", -6, -8, -4, 6, -2, 5)
    d.box("oak", -7, -2, -5, 7, 0, 6)
    d.box("brass", -1, 0, 1, 1, 7, 3)
    d.box("brass", -6, 6, 1, 6, 7, 3)
    for x in (-5, 4):
        d.box("brass", x, 2, 1, x + 1, 6, 2)
        d.box("brass", x - 1, 1, 0, x + 2, 2, 3)
    gem(d, -6, 2, 0, "gem_violet")
    d.box("steel", 4, 2, 0, 6, 3, 2)
    chisel(d, 3, 0, -5)
    d.box("walnut", -5, 0, -4, -4, 1, 0)
    d.box("steel", -6, 0, -4, -3, 1, -3)
    d.box("brass", -1, -5, -5, 1, -4, -4)

    d = new("jewellers_bench", "C", "Lapidary wheel",
            "An upright stepped grinding wheel rises over a low bench with a gem tray and copper tool rest.")
    bench(d, top=-1, wood="walnut")
    for z in (-1, 3):
        d.box("iron", -5, -1, z, -3, 4, z + 1)
    d.box("steel", -5, 3, -2, -3, 4, 5)
    d.box("grindstone", -7, 2, 0, -1, 5, 3)
    d.box("grindstone", -6, 1, 0, -2, 6, 3)
    d.box("grindstone", -5, 0, 0, -3, 7, 3)
    d.box("brass", -5, 3, -1, -3, 4, 0)
    d.box("copper", -6, 0, -4, -1, 1, -2)
    d.box("felt", 1, -1, -3, 6, 0, 4)
    gem(d, 2, 0, -2, "gem_teal")
    gem(d, 2, 0, 2, "gem_violet")
    chisel(d, 6, -1, -4)

    # ALCHEMY: copper still, shelf laboratory, suspended twin flasks.
    d = new("brewing_stand", "A", "Copper retort",
            "A copper still feeds a blue receiver through a squared swan-neck pipe above a small burner.")
    d.box("stone", -7, -8, -6, 7, -6, 6)
    burner(d, -5, -6, -2)
    for x in (-6, -1):
        d.box("iron", x, -6, -2, x + 1, 0, 2)
    d.box("copper", -6, -1, -3, 0, 3, 3)
    d.box("copper", -5, 3, -2, -1, 4, 2)
    d.box("brass", -4, 4, -1, -2, 7, 1)
    d.box("copper", -2, 6, -1, 5, 7, 1)
    d.box("copper", 4, 2, -1, 5, 6, 1)
    bottle(d, 2, -6, -2, width=4, height=8)

    d = new("brewing_stand", "B", "Apothecary bench",
            "A compact two-tier bottle shelf backs a working flask and warm copper burner.")
    bench(d, top=-3, depth=6, wood="walnut")
    for x in (-7, 5):
        d.box("walnut", x, -3, 4, x + 2, 8, 6)
    d.box("oak", -5, 2, 2, 5, 3, 6)
    bottle(d, -4, 3, 2, "glass_violet", width=3, height=5)
    bottle(d, 1, 3, 2, "glass_green", width=3, height=5)
    burner(d, -2, -3, -5)
    for x in (-3, 2):
        d.box("iron", x, -3, -4, x + 1, 2, -2)
    bottle(d, -2, 1, -5, width=4, height=6)
    d.box("linen", 4, -3, -4, 6, -2, 0)

    d = new("brewing_stand", "C", "Suspended flasks",
            "An iron gantry suspends teal and violet flasks above two burners on a stepped stone plinth.")
    d.box("stone", -7, -8, -5, 7, -6, 5)
    d.box("stone", -6, -6, -4, 6, -5, 4)
    for x in (-7, 6):
        d.box("iron", x, -6, 1, x + 1, 8, 3)
    d.box("iron", -6, 6, 1, 6, 8, 3)
    for x, colour in ((-5, "glass_teal"), (1, "glass_violet")):
        burner(d, x, -5, -2)
        bottle(d, x, -1, -2, colour, width=4, height=7)
        d.box("brass", x + 1, 5, -1, x + 3, 6, 3)
    return result
